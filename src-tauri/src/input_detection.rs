//! Tracks cursor position to distinguish user movement from engine movement.
//! Also detects manual mouse clicks to cancel auto-click.
//!
//! Strategy:
//!   - Engine sets `engine_last_pos` every time it warps the cursor.
//!   - A background polling thread checks the real cursor position every 50 ms.
//!   - If the position differs from `engine_last_pos` by more than THRESHOLD,
//!     a user move is detected and `last_user_move_time` is updated.
//!   - Mouse button state is polled via NSEvent.pressedMouseButtons.
//!     A click that occurs more than ENGINE_CLICK_GUARD_MS after the last
//!     engine-generated click is flagged as a user click.

use std::sync::atomic::{AtomicBool, AtomicI64, AtomicU64, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use crate::macos_mouse;

const MOVE_THRESHOLD: f64    = 12.0; // pixels
const POLL_MS:        u64    = 50;   // finer granularity for click detection
/// Clicks within this window after an engine click are ignored
const ENGINE_CLICK_GUARD_MS: u64 = 400;

fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64
}

/// Shared state between engine and detection thread.
#[derive(Clone)]
pub struct InputMonitor {
    engine_pos_x:         Arc<AtomicI64>,
    engine_pos_y:         Arc<AtomicI64>,
    /// Unix-ms timestamp of last detected user movement (0 = never)
    last_user_move_time:  Arc<AtomicU64>,
    /// Set to true when a manual user click is detected; cleared by take_user_click()
    user_click_detected:  Arc<AtomicBool>,
    /// Timestamp of the last engine-generated click (used to filter engine clicks)
    last_engine_click_ms: Arc<AtomicU64>,
}

impl InputMonitor {
    pub fn new() -> Self {
        InputMonitor {
            engine_pos_x:         Arc::new(AtomicI64::new(-99999)),
            engine_pos_y:         Arc::new(AtomicI64::new(-99999)),
            last_user_move_time:  Arc::new(AtomicU64::new(0)),
            user_click_detected:  Arc::new(AtomicBool::new(false)),
            last_engine_click_ms: Arc::new(AtomicU64::new(0)),
        }
    }

    /// Call this after every engine warp so the monitor knows the expected position.
    pub fn record_engine_move(&self, x: f64, y: f64) {
        self.engine_pos_x.store((x * 10.0) as i64, Ordering::Relaxed);
        self.engine_pos_y.store((y * 10.0) as i64, Ordering::Relaxed);
    }

    /// Call this immediately after the engine fires a click.
    pub fn record_engine_click(&self) {
        self.last_engine_click_ms.store(now_ms(), Ordering::Relaxed);
    }

    /// Returns true (and clears the flag) if a user manual click was detected.
    pub fn take_user_click(&self) -> bool {
        self.user_click_detected.swap(false, Ordering::Relaxed)
    }

    /// Returns true if user has moved the cursor more recently than `start_after` ms ago.
    pub fn user_moved_recently(&self, start_after_ms: u64) -> bool {
        if start_after_ms == 0 { return false; }
        let t = self.last_user_move_time.load(Ordering::Relaxed);
        if t == 0 { return false; }
        now_ms().saturating_sub(t) < start_after_ms
    }

    /// Milliseconds since last user movement (u64::MAX if never moved).
    pub fn ms_since_user_move(&self) -> u64 {
        let t = self.last_user_move_time.load(Ordering::Relaxed);
        if t == 0 { return u64::MAX; }
        now_ms().saturating_sub(t)
    }

    /// Spawn the background polling thread.
    pub fn start_polling(&self) -> thread::JoinHandle<()> {
        let monitor = self.clone();
        thread::spawn(move || {
            let mut prev_buttons: usize = 0;

            loop {
                thread::sleep(Duration::from_millis(POLL_MS));

                // ── Cursor movement detection ────────────────────────────────
                let (cx, cy) = macos_mouse::get_cursor_pos();
                let ex = monitor.engine_pos_x.load(Ordering::Relaxed) as f64 / 10.0;
                let ey = monitor.engine_pos_y.load(Ordering::Relaxed) as f64 / 10.0;
                let dist = ((cx - ex).powi(2) + (cy - ey).powi(2)).sqrt();
                if dist > MOVE_THRESHOLD {
                    monitor.last_user_move_time.store(now_ms(), Ordering::Relaxed);
                    monitor.engine_pos_x.store((cx * 10.0) as i64, Ordering::Relaxed);
                    monitor.engine_pos_y.store((cy * 10.0) as i64, Ordering::Relaxed);
                }

                // ── Mouse click detection (macOS only) ───────────────────────
                #[cfg(target_os = "macos")]
                {
                    use objc::{class, msg_send, sel, sel_impl};
                    // pressedMouseButtons: bit 0 = left, bit 1 = right
                    let cur_buttons: usize =
                        unsafe { msg_send![class!(NSEvent), pressedMouseButtons] };

                    // Rising edge: button was up, now down → new click started
                    let new_down = cur_buttons & !prev_buttons;
                    if new_down & 0b11 != 0 {
                        // Only flag as user click if not within guard window of engine click
                        let engine_ms = monitor.last_engine_click_ms.load(Ordering::Relaxed);
                        if now_ms().saturating_sub(engine_ms) > ENGINE_CLICK_GUARD_MS {
                            monitor.user_click_detected.store(true, Ordering::Relaxed);
                            eprintln!("[input] user click detected");
                        }
                    }
                    prev_buttons = cur_buttons;
                }
            }
        })
    }
}
