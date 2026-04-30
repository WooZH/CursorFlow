//! CursorFlow – Tauri v2 app entry point.
//! Wires up: AppState, Tray, IPC commands, window management.

mod config_store;
mod input_detection;
mod macos_mouse;
mod movement_engine;
mod simulation_model;

use config_store::{ClickPosition, ConfigStore};
use input_detection::InputMonitor;
use movement_engine::MovementEngine;

use std::sync::{Arc, Mutex, RwLock};
use tauri::{
    image::Image,
    menu::{Menu, MenuItem, PredefinedMenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, Emitter, Manager, State, WebviewUrl, WebviewWindowBuilder,
};

// ── App state ─────────────────────────────────────────────────────────────────

pub struct AppState {
    pub config: Arc<RwLock<ConfigStore>>,
    pub engine: Arc<MovementEngine>,
    /// Active fullscreen capture window label (if any)
    pub capture_window: Mutex<Option<String>>,
}

// ── Tauri commands ────────────────────────────────────────────────────────────

#[tauri::command]
fn get_config(state: State<'_, Arc<AppState>>) -> serde_json::Value {
    let cfg = state.config.read().unwrap().get_all();
    serde_json::to_value(cfg).unwrap_or_default()
}

#[tauri::command]
fn set_config(
    key: String,
    value: serde_json::Value,
    state: State<'_, Arc<AppState>>,
    app: AppHandle,
) {
    {
        let mut store = state.config.write().unwrap();
        match key.as_str() {
            "timerEnabled" => {
                if let Some(v) = value.as_bool() {
                    store.set_timer_enabled(v);
                }
            }
            "timerHour" => {
                if let Some(v) = value.as_u64() {
                    store.set_timer_hour(v as u32);
                }
            }
            "timerMinute" => {
                if let Some(v) = value.as_u64() {
                    store.set_timer_minute(v as u32);
                }
            }
            "silentMode" => {
                if let Some(v) = value.as_bool() {
                    store.set_silent_mode(v);
                }
            }
            "startAfter" => {
                if let Some(v) = value.as_u64() {
                    store.set_start_after(v);
                }
            }
            "moveEvery" => {
                if let Some(v) = value.as_u64() {
                    store.set_move_every(v);
                }
            }
            "clickButton" => {
                if let Some(v) = value.as_str() {
                    store.set_click_button(v.to_string());
                }
            }
            "clickInterval" => {
                if let Some(v) = value.as_u64() {
                    store.set_click_interval(v);
                }
            }
            "batteryThreshold" => {
                if let Some(v) = value.as_u64() {
                    store.set_battery_threshold(v as u8);
                }
            }
            "theme" => {
                if let Some(v) = value.as_str() {
                    store.set_theme(v.to_string());
                }
            }
            _ => {}
        }
    }
    // Push updated config to engine
    let cfg = state.config.read().unwrap().get_all();
    state.engine.update_config(cfg.clone());
    // Notify renderer
    let _ = app.emit("config-changed", serde_json::json!({ "key": key, "value": value }));
}

#[tauri::command]
fn toggle_movement(
    active: bool,
    state: State<'_, Arc<AppState>>,
    app: AppHandle,
) {
    eprintln!("[IPC] toggle_movement active={active}");
    state
        .engine
        .movement_enabled
        .store(active, std::sync::atomic::Ordering::Relaxed);
    let now = state.engine.movement_enabled.load(std::sync::atomic::Ordering::Relaxed);
    eprintln!("[IPC] toggle_movement → stored, reading back={now}");
    let click_now = state.engine.click_enabled.load(std::sync::atomic::Ordering::Relaxed);
    update_tray_icon(&app, active, click_now);
    let _ = app.emit("movement-state-changed", active);
}

#[tauri::command]
fn toggle_click(active: bool, state: State<'_, Arc<AppState>>, app: AppHandle) {
    state
        .engine
        .click_enabled
        .store(active, std::sync::atomic::Ordering::Relaxed);
    let mov_now = state.engine.movement_enabled.load(std::sync::atomic::Ordering::Relaxed);
    update_tray_icon(&app, mov_now, active);
    let _ = app.emit("click-state-changed", active);
}

#[tauri::command]
fn get_cursor_position() -> serde_json::Value {
    let (x, y) = macos_mouse::get_cursor_pos();
    serde_json::json!({ "x": x, "y": y })
}

#[tauri::command]
fn start_position_capture(state: State<'_, Arc<AppState>>, app: AppHandle) {
    // Create fullscreen transparent overlay window
    let label = "capture";
    if let Ok(w) = WebviewWindowBuilder::new(
        &app,
        label,
        WebviewUrl::App("capture.html".into()),
    )
    .title("CursorFlow Capture")
    .fullscreen(true)
    .transparent(true)
    .decorations(false)
    .shadow(false)
    .always_on_top(true)
    .skip_taskbar(true)
    .build()
    {
        w.set_focus().ok();
        *state.capture_window.lock().unwrap() = Some(label.to_string());
    }
}

#[tauri::command]
fn capture_position(
    x: f64,
    y: f64,
    state: State<'_, Arc<AppState>>,
    app: AppHandle,
) {
    {
        let mut store = state.config.write().unwrap();
        store.set_click_position(Some(ClickPosition { x, y }));
    }
    close_capture(&state, &app);
    let _ = app.emit("capture-done", serde_json::json!({ "x": x, "y": y }));
    // Show main window
    if let Some(win) = app.get_webview_window("main") {
        win.show().ok();
        win.set_focus().ok();
    }
}

#[tauri::command]
fn cancel_capture(state: State<'_, Arc<AppState>>, app: AppHandle) {
    close_capture(&state, &app);
    let _ = app.emit("capture-cancelled", ());
    if let Some(win) = app.get_webview_window("main") {
        win.show().ok();
        win.set_focus().ok();
    }
}

#[tauri::command]
fn engine_status(state: State<'_, Arc<AppState>>) -> serde_json::Value {
    let mov = state.engine.movement_enabled.load(std::sync::atomic::Ordering::Relaxed);
    let clk = state.engine.click_enabled.load(std::sync::atomic::Ordering::Relaxed);
    let acc = macos_mouse::is_trusted();
    let cog = state.engine.cognitive_state.lock().unwrap().clone();
    let cnt = state.engine.click_count.load(std::sync::atomic::Ordering::Relaxed);
    serde_json::json!({
        "movementEnabled": mov,
        "clickEnabled": clk,
        "accessibilityGranted": acc,
        "cognitiveState": cog,
        "clickCount": cnt
    })
}

#[tauri::command]
fn test_movement(app: AppHandle) {
    // Sweep cursor 80px right then back — called from IPC thread, same as before.
    // The engine now uses run_on_main_thread; test_movement keeps the sync path
    // so it still works as a direct confirmation that CGWarp/CGEventPost operates.
    std::thread::spawn(move || {
        let (x, y) = macos_mouse::get_cursor_pos();
        for i in 1..=8_i32 {
            let nx = x + (i as f64) * 10.0;
            let _ = app.run_on_main_thread(move || macos_mouse::warp_cursor(nx, y));
            std::thread::sleep(std::time::Duration::from_millis(40));
        }
        std::thread::sleep(std::time::Duration::from_millis(150));
        for i in (0..=8_i32).rev() {
            let nx = x + (i as f64) * 10.0;
            let _ = app.run_on_main_thread(move || macos_mouse::warp_cursor(nx, y));
            std::thread::sleep(std::time::Duration::from_millis(40));
        }
    });
}

#[tauri::command]
fn reset_click_count(state: State<'_, Arc<AppState>>) {
    state.engine.click_count.store(0, std::sync::atomic::Ordering::Relaxed);
}

#[tauri::command]
fn request_accessibility() {
    let _ = std::process::Command::new("open")
        .arg("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        .spawn();
}

#[tauri::command]
fn quit_app(app: AppHandle) {
    app.exit(0);
}

#[tauri::command]
fn hide_window(app: AppHandle) {
    if let Some(win) = app.get_webview_window("main") {
        win.hide().ok();
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

fn close_capture(state: &State<'_, Arc<AppState>>, app: &AppHandle) {
    let label = state.capture_window.lock().unwrap().take();
    if let Some(lbl) = label {
        if let Some(win) = app.get_webview_window(&lbl) {
            win.close().ok();
        }
    }
}

pub(crate) fn update_tray_icon(app: &AppHandle, movement: bool, click: bool) {
    let icon_bytes: &[u8] = match (movement, click) {
        (false, false) => include_bytes!("../icons/tray-inactive.png"),
        (true,  false) => include_bytes!("../icons/tray-movement.png"),
        (false, true)  => include_bytes!("../icons/tray-click.png"),
        (true,  true)  => include_bytes!("../icons/tray-both.png"),
    };
    if let Ok(img) = Image::from_bytes(icon_bytes) {
        if let Some(tray) = app.tray_by_id("main-tray") {
            let _ = tray.set_icon(Some(img));
            let _ = tray.set_icon_as_template(true);
        }
    }
}

// ── App bootstrap ─────────────────────────────────────────────────────────────

pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            // Config store
            let data_dir = app
                .path()
                .app_data_dir()
                .unwrap_or_else(|_| std::path::PathBuf::from("."));
            let config_store = ConfigStore::new(data_dir);
            let initial_config = config_store.get_all();

            // Input monitor
            let monitor = InputMonitor::new();
            monitor.start_polling();

            // Movement engine — pass app handle so warps run on the main thread
            let engine = MovementEngine::new(initial_config.clone(), monitor, app.handle().clone());
            engine.start_threads();

            let app_state = Arc::new(AppState {
                config: Arc::new(RwLock::new(config_store)),
                engine: Arc::new(engine),
                capture_window: Mutex::new(None),
            });
            app.manage(app_state.clone());

            // Build tray
            let inactive_icon = Image::from_bytes(include_bytes!(
                "../icons/tray-inactive.png"
            ))?;

            let show_item = MenuItem::with_id(app, "show", "Open CursorFlow", true, None::<&str>)?;
            let sep = PredefinedMenuItem::separator(app)?;
            let quit_item = MenuItem::with_id(app, "quit", "Quit", true, None::<&str>)?;

            let menu = Menu::with_items(app, &[&show_item, &sep, &quit_item])?;

            let _tray = TrayIconBuilder::with_id("main-tray")
                .icon(inactive_icon)
                .icon_as_template(true)
                .tooltip("CursorFlow")
                .menu(&menu)
                .show_menu_on_left_click(false)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "show" => {
                        if let Some(win) = app.get_webview_window("main") {
                            win.show().ok();
                            win.set_focus().ok();
                        }
                    }
                    "quit" => app.exit(0),
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        position,
                        ..
                    } = event
                    {
                        let app = tray.app_handle();
                        if let Some(win) = app.get_webview_window("main") {
                            let visible = win.is_visible().unwrap_or(false);
                            if visible {
                                win.hide().ok();
                            } else {
                                // Position window below tray icon
                                let win_w = 380.0_f64;
                                let win_h = 575.0_f64;
                                let x = (position.x - win_w / 2.0).max(8.0);
                                let y = position.y + 8.0;
                                win.set_position(tauri::PhysicalPosition::new(x, y)).ok();
                                win.show().ok();
                                win.set_focus().ok();
                            }
                        }
                    }
                })
                .build(app)?;

            // Hide dock icon
            #[cfg(target_os = "macos")]
            {
                use tauri::ActivationPolicy;
                app.set_activation_policy(ActivationPolicy::Accessory);
            }

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            get_config,
            set_config,
            toggle_movement,
            toggle_click,
            get_cursor_position,
            start_position_capture,
            capture_position,
            cancel_capture,
            engine_status,
            reset_click_count,
            test_movement,
            request_accessibility,
            quit_app,
            hide_window,
        ])
        .run(tauri::generate_context!())
        .expect("error while running CursorFlow");
}
