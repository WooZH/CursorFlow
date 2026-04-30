//! Persistent JSON config, stored in the Tauri app-data directory.

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Config {
    pub timer_enabled: bool,
    pub timer_hour: u32,
    pub timer_minute: u32,
    pub silent_mode: bool,
    /// Milliseconds idle before first move (default 10000)
    pub start_after: u64,
    /// Base milliseconds between movements (default 10000)
    pub move_every: u64,
    pub click_button: String,
    pub click_position: Option<ClickPosition>,
    /// Milliseconds between auto-clicks (default 1000)
    pub click_interval: u64,
    pub battery_threshold: u8,
    pub movement_mode: String,
    pub simulation_level: String,
    pub theme: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClickPosition {
    pub x: f64,
    pub y: f64,
}

impl Default for Config {
    fn default() -> Self {
        Config {
            timer_enabled: false,
            timer_hour: 1,
            timer_minute: 0,
            silent_mode: false,
            start_after: 10000,
            move_every: 10000,
            click_button: "Left".into(),
            click_position: None,
            click_interval: 1000,
            battery_threshold: 5,
            movement_mode: "jitter".into(),
            simulation_level: "smart".into(),
            theme: "light".into(),
        }
    }
}

pub struct ConfigStore {
    pub config: Config,
    path: PathBuf,
}

impl ConfigStore {
    pub fn new(app_data_dir: PathBuf) -> Self {
        let path = app_data_dir.join("config.json");
        let config = Self::load(&path);
        ConfigStore { config, path }
    }

    fn load(path: &PathBuf) -> Config {
        if let Ok(raw) = fs::read_to_string(path) {
            if let Ok(c) = serde_json::from_str::<Config>(&raw) {
                return c;
            }
        }
        Config::default()
    }

    fn save(&self) {
        if let Ok(json) = serde_json::to_string_pretty(&self.config) {
            let _ = fs::create_dir_all(self.path.parent().unwrap());
            let _ = fs::write(&self.path, json);
        }
    }

    pub fn get_all(&self) -> Config { self.config.clone() }

    pub fn set_timer_enabled(&mut self, v: bool)   { self.config.timer_enabled = v; self.save(); }
    pub fn set_timer_hour(&mut self, v: u32)        { self.config.timer_hour = v;    self.save(); }
    pub fn set_timer_minute(&mut self, v: u32)      { self.config.timer_minute = v;  self.save(); }
    pub fn set_silent_mode(&mut self, v: bool)      { self.config.silent_mode = v;   self.save(); }
    pub fn set_start_after(&mut self, v: u64)       { self.config.start_after = v;   self.save(); }
    pub fn set_move_every(&mut self, v: u64)        { self.config.move_every = v;    self.save(); }
    pub fn set_click_button(&mut self, v: String)   { self.config.click_button = v;  self.save(); }
    pub fn set_click_interval(&mut self, v: u64)    { self.config.click_interval = v; self.save(); }
    pub fn set_click_position(&mut self, pos: Option<ClickPosition>) {
        self.config.click_position = pos; self.save();
    }
    pub fn set_battery_threshold(&mut self, v: u8)  { self.config.battery_threshold = v; self.save(); }
    pub fn set_movement_mode(&mut self, v: String)  { self.config.movement_mode = v; self.save(); }
    pub fn set_simulation_level(&mut self, v: String) { self.config.simulation_level = v; self.save(); }
    pub fn set_theme(&mut self, v: String)          { self.config.theme = v;         self.save(); }
}
