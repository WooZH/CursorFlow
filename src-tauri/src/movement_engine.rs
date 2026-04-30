//! Behavioral movement engine — single loop architecture.
//!
//! One thread runs the full Intent→State→Plan→Execute cycle.
//! Cognitive state is derived automatically from user idle time.
//! Per-waypoint delays implement the easeInOutCubic velocity profile
//! and hesitation pauses from the simulation model.

use crate::config_store::Config;
use crate::input_detection::InputMonitor;
use crate::macos_mouse;
use crate::simulation_model::{self, CognitiveState, MovementHistory, Point};

use std::collections::VecDeque;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};
use tauri::{AppHandle, Emitter};

// ── Engine state (internal) ───────────────────────────────────────────────────

struct EngineState {
    queue:    VecDeque<(Point, u64)>, // (waypoint, step_delay_ms)
    last_pos: Point,
    screen_w: f64,
    screen_h: f64,
}

impl Default for EngineState {
    fn default() -> Self {
        let (x, y) = macos_mouse::get_cursor_pos();
        eprintln!("[engine] initial cursor pos=({x:.1},{y:.1})");
        EngineState {
            queue:    VecDeque::new(),
            last_pos: Point { x, y },
            screen_w: 1440.0,
            screen_h: 900.0,
        }
    }
}

// ── Public engine handle ──────────────────────────────────────────────────────

pub struct MovementEngine {
    pub movement_enabled: Arc<AtomicBool>,
    pub click_enabled:    Arc<AtomicBool>,
    /// Current cognitive state label — readable via engine_status IPC.
    pub cognitive_state:  Arc<Mutex<String>>,
    /// Total auto-clicks fired since engine start.
    pub click_count:      Arc<std::sync::atomic::AtomicU64>,
    config:  Arc<Mutex<Config>>,
    state:   Arc<Mutex<EngineState>>,
    monitor: InputMonitor,
    app:     AppHandle,
}

impl MovementEngine {
    pub fn new(config: Config, monitor: InputMonitor, app: AppHandle) -> Self {
        MovementEngine {
            movement_enabled: Arc::new(AtomicBool::new(false)),
            click_enabled:    Arc::new(AtomicBool::new(false)),
            cognitive_state:  Arc::new(Mutex::new("Idle".into())),
            click_count:      Arc::new(std::sync::atomic::AtomicU64::new(0)),
            config:  Arc::new(Mutex::new(config)),
            state:   Arc::new(Mutex::new(EngineState::default())),
            monitor,
            app,
        }
    }

    pub fn update_config(&self, cfg: Config) {
        if let Ok(mut c) = self.config.lock() { *c = cfg; }
    }

    /// Spawn the single behavior thread.
    pub fn start_threads(&self) {
        eprintln!("[engine] starting behavior thread");
        let movement_enabled = Arc::clone(&self.movement_enabled);
        let click_enabled    = Arc::clone(&self.click_enabled);
        let cognitive_state  = Arc::clone(&self.cognitive_state);
        let click_count      = Arc::clone(&self.click_count);
        let config  = Arc::clone(&self.config);
        let state   = Arc::clone(&self.state);
        let monitor = self.monitor.clone();
        let app     = self.app.clone();
        thread::spawn(move || {
            behavior_loop(movement_enabled, click_enabled, config, state, monitor, app, cognitive_state, click_count)
        });
    }
}

// ── Behavior loop ─────────────────────────────────────────────────────────────

fn behavior_loop(
    movement_enabled: Arc<AtomicBool>,
    click_enabled:    Arc<AtomicBool>,
    config:           Arc<Mutex<Config>>,
    state:            Arc<Mutex<EngineState>>,
    monitor:          InputMonitor,
    app:              AppHandle,
    cog_state_label:  Arc<Mutex<String>>,
    click_count:      Arc<std::sync::atomic::AtomicU64>,
) {
    use rand::{rngs::SmallRng, SeedableRng};
    let mut rng = SmallRng::from_entropy();

    let mut last_movement = Instant::now();
    let mut last_click    = Instant::now();
    let mut history       = MovementHistory::new();
    let mut log_ticker: u64 = 0;

    loop {
        let mov_en   = movement_enabled.load(Ordering::Relaxed);
        let click_en = click_enabled.load(Ordering::Relaxed);

        let (start_after, move_every, click_btn, click_pos, click_interval_ms) = {
            let c = config.lock().unwrap();
            (c.start_after, c.move_every, c.click_button.clone(), c.click_position.clone(), c.click_interval)
        };

        // ── Auto-click (independent of movement state) ──────────────────────
        if click_en {
            // User manually clicked → cancel auto-click
            if monitor.take_user_click() {
                click_enabled.store(false, Ordering::Relaxed);
                let mov = movement_enabled.load(Ordering::Relaxed);
                crate::update_tray_icon(&app, mov, false);
                let _ = app.emit("click-state-changed", false);
                eprintln!("[click] user manual click — auto-click cancelled");
                continue;
            }

            if !monitor.user_moved_recently(start_after) {
                if last_click.elapsed() >= Duration::from_millis(click_interval_ms) {
                    if let Some(pos) = &click_pos {
                        macos_mouse::post_click(pos.x, pos.y, &click_btn);
                        monitor.record_engine_click();
                        click_count.fetch_add(1, Ordering::Relaxed);
                        eprintln!("[click] fired at ({:.0},{:.0})  total={}", pos.x, pos.y,
                            click_count.load(Ordering::Relaxed));
                    }
                    last_click = Instant::now();
                }
            }
        }

        // ── Guard: movement disabled or user active ──────────────────────────
        if !mov_en || monitor.user_moved_recently(start_after) {
            // Flush any in-progress path if user took over
            if monitor.user_moved_recently(start_after) {
                let mut s = state.lock().unwrap();
                if !s.queue.is_empty() {
                    s.queue.clear();
                    eprintln!("[behavior] user active — path flushed");
                }
            }
            thread::sleep(Duration::from_millis(40));
            continue;
        }

        // ── Derive cognitive state ───────────────────────────────────────────
        let idle_ms = monitor.ms_since_user_move();
        let cog     = CognitiveState::from_idle_ms(idle_ms, &mut rng);

        // Update shared label (only write on change to avoid lock contention)
        {
            let label = cog.label();
            let mut cs = cog_state_label.lock().unwrap();
            if cs.as_str() != label { *cs = label.to_string(); }
        }

        // Periodic log
        if log_ticker % 125 == 0 {
            let trusted = macos_mouse::is_trusted();
            eprintln!("[behavior] #{log_ticker} state={} idle={idle_ms}ms acc={trusted}",
                cog.label());
        }
        log_ticker += 1;

        // ── Execute next waypoint if queued ──────────────────────────────────
        let next = { let mut s = state.lock().unwrap(); s.queue.pop_front() };

        if let Some((pt, delay)) = next {
            monitor.record_engine_move(pt.x, pt.y);
            { let mut s = state.lock().unwrap(); s.last_pos = pt.clone(); }
            dispatch_warp(&app, pt.x, pt.y);
            thread::sleep(Duration::from_millis(delay));

        } else {
            // ── Queue empty — check if it is time to plan a new movement ─────
            let interval = simulation_model::next_interval_ms(move_every, &cog, &mut rng);
            if last_movement.elapsed() >= Duration::from_millis(interval) {
                let (from, sw, sh) = {
                    let s = state.lock().unwrap();
                    (s.last_pos.clone(), s.screen_w, s.screen_h)
                };
                let to   = simulation_model::select_target(&from, sw, sh, &cog, &history, &mut rng);
                let path = simulation_model::generate_path(&from, &to, &cog, &mut rng);
                history.record(&from, &to);

                eprintln!("[behavior] {} → {:.0},{:.0}  pts={} interval={}ms",
                    cog.label(), to.x, to.y, path.len(), interval);

                { let mut s = state.lock().unwrap(); for wp in path { s.queue.push_back(wp); } }
                last_movement = Instant::now();
            } else {
                thread::sleep(Duration::from_millis(40));
            }
        }
    }
}

// ── Dispatch ──────────────────────────────────────────────────────────────────

fn dispatch_warp(app: &AppHandle, x: f64, y: f64) {
    let _ = app.run_on_main_thread(move || macos_mouse::warp_cursor(x, y));
}
