//! Behavioral mouse simulation engine.
//!
//! Architecture: Intent → Cognitive State → Attention Focus → Movement Plan → Execution
//!
//! CognitiveState is derived automatically from user idle time.
//! Movements use attention-biased target selection, cubic Bézier curves,
//! easeInOutCubic velocity profiles, Perlin-style micro-noise, and
//! optional overshoot/correction sequences.

use rand::{rngs::SmallRng, Rng};
use std::collections::VecDeque;
use std::f64::consts::PI;

// ── Core types ────────────────────────────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct Point {
    pub x: f64,
    pub y: f64,
}

// ── Cognitive state ───────────────────────────────────────────────────────────

/// Automatically inferred from idle time — never user-selectable.
#[derive(Debug, Clone, PartialEq)]
pub enum CognitiveState {
    MicroInteraction, // idle < 5 s  – tiny presence corrections
    NavigatingUI,     // idle 5–20 s – scanning / looking for something
    Reading,          // idle 20–60 s – drifting along content
    Thinking,         // idle 60–180 s – slow wandering with long pauses
    Idle,             // idle > 180 s – minimal keep-alive
}

impl CognitiveState {
    /// Probabilistic transition — ±2 s noise prevents hard threshold edges.
    pub fn from_idle_ms(idle_ms: u64, rng: &mut SmallRng) -> Self {
        let jitter = rng.gen_range(-2000i64..2000i64);
        let t = (idle_ms as i64 + jitter).max(0) as u64;
        match t {
            0..=4_999          => Self::MicroInteraction,
            5_000..=19_999     => Self::NavigatingUI,
            20_000..=59_999    => Self::Reading,
            60_000..=179_999   => Self::Thinking,
            _                  => Self::Idle,
        }
    }

    pub fn label(&self) -> &'static str {
        match self {
            Self::MicroInteraction => "Micro",
            Self::NavigatingUI     => "Navigating",
            Self::Reading          => "Reading",
            Self::Thinking         => "Thinking",
            Self::Idle             => "Idle",
        }
    }

    /// Movement amplitude range (pixels).
    fn amplitude(&self) -> (f64, f64) {
        match self {
            Self::MicroInteraction => (14.0,  55.0),
            Self::NavigatingUI     => (90.0, 300.0),
            Self::Reading          => (45.0, 160.0),
            Self::Thinking         => (30.0, 110.0),
            Self::Idle             => (10.0,  40.0),
        }
    }

    /// Waypoints along the Bézier curve.
    fn waypoints(&self) -> usize {
        match self {
            Self::MicroInteraction =>  8,
            Self::NavigatingUI     => 26,
            Self::Reading          => 18,
            Self::Thinking         => 14,
            Self::Idle             =>  8,
        }
    }

    /// Bowing factor (control-point offset relative to path length).
    fn curve_factor(&self) -> f64 {
        match self {
            Self::MicroInteraction => 0.10,
            Self::NavigatingUI     => 0.38,
            Self::Reading          => 0.28,
            Self::Thinking         => 0.22,
            Self::Idle             => 0.13,
        }
    }

    /// Micro-noise amplitude (pixels, perpendicular to path).
    fn noise_strength(&self) -> f64 {
        match self {
            Self::MicroInteraction => 1.2,
            Self::NavigatingUI     => 4.0,
            Self::Reading          => 2.8,
            Self::Thinking         => 2.0,
            Self::Idle             => 1.0,
        }
    }

    /// Per-waypoint hesitation probability.
    fn hesitation_prob(&self) -> f64 {
        match self {
            Self::MicroInteraction => 0.04,
            Self::NavigatingUI     => 0.07,
            Self::Reading          => 0.13,
            Self::Thinking         => 0.20,
            Self::Idle             => 0.10,
        }
    }

    /// Hesitation duration range (ms).
    fn hesitation_ms(&self) -> (u64, u64) {
        match self {
            Self::MicroInteraction => ( 40,  130),
            Self::NavigatingUI     => ( 80,  260),
            Self::Reading          => (120,  480),
            Self::Thinking         => (180,  700),
            Self::Idle             => (200,  900),
        }
    }

    /// Interval multiplier applied to the user's `move_every` setting.
    pub fn interval_factor(&self, rng: &mut SmallRng) -> f64 {
        match self {
            Self::MicroInteraction => rng.gen_range(0.08..0.28),
            Self::NavigatingUI     => rng.gen_range(0.25..0.60),
            Self::Reading          => rng.gen_range(0.50..1.10),
            Self::Thinking         => rng.gen_range(1.00..2.60),
            Self::Idle             => rng.gen_range(1.50..3.80),
        }
    }
}

// ── Intent (internal, not exposed) ───────────────────────────────────────────

enum Intent {
    MaintainPresence,
    SimulateReading,
    SimulateThinking,
    MoveToInteraction,
    MicroAdjust,
}

impl Intent {
    fn select(state: &CognitiveState, rng: &mut SmallRng) -> Self {
        let r: f64 = rng.gen();
        match state {
            CognitiveState::MicroInteraction => {
                if r < 0.72 { Self::MicroAdjust } else { Self::MaintainPresence }
            }
            CognitiveState::NavigatingUI => {
                if r < 0.48 { Self::MoveToInteraction }
                else if r < 0.78 { Self::SimulateReading }
                else { Self::MaintainPresence }
            }
            CognitiveState::Reading => {
                if r < 0.58 { Self::SimulateReading }
                else if r < 0.84 { Self::MaintainPresence }
                else { Self::MicroAdjust }
            }
            CognitiveState::Thinking => {
                if r < 0.52 { Self::SimulateThinking }
                else if r < 0.78 { Self::MaintainPresence }
                else { Self::MicroAdjust }
            }
            CognitiveState::Idle => Self::MaintainPresence,
        }
    }
}

// ── Attention zone weights (per spec) ─────────────────────────────────────────

const Z_CURSOR: f64 = 0.9;
const Z_CENTER: f64 = 0.7;
const Z_INPUTS: f64 = 0.8;
const Z_EDGES:  f64 = 0.2;
const Z_RANDOM: f64 = 0.1;
const Z_TOTAL:  f64 = Z_CURSOR + Z_CENTER + Z_INPUTS + Z_EDGES + Z_RANDOM;

// ── Movement history (anti-repetition) ───────────────────────────────────────

pub struct MovementHistory {
    positions:  VecDeque<Point>,
    directions: VecDeque<f64>,  // radians
}

impl MovementHistory {
    pub fn new() -> Self {
        Self { positions: VecDeque::with_capacity(10), directions: VecDeque::with_capacity(10) }
    }

    pub fn record(&mut self, from: &Point, to: &Point) {
        let angle = (to.y - from.y).atan2(to.x - from.x);
        if self.positions.len() >= 10 { self.positions.pop_front(); self.directions.pop_front(); }
        self.positions.push_back(to.clone());
        self.directions.push_back(angle);
    }

    /// Mean recent movement direction (used to bias away from oscillation).
    fn mean_direction(&self) -> Option<f64> {
        if self.directions.is_empty() { return None; }
        let n = self.directions.len() as f64;
        let sc: f64 = self.directions.iter().map(|a| a.sin()).sum::<f64>() / n;
        let cc: f64 = self.directions.iter().map(|a| a.cos()).sum::<f64>() / n;
        Some(sc.atan2(cc))
    }

    /// Average distance from centroid — detects if cursor is stuck in a small region.
    pub fn spatial_spread(&self) -> f64 {
        let n = self.positions.len();
        if n < 2 { return 9999.0; }
        let cx = self.positions.iter().map(|p| p.x).sum::<f64>() / n as f64;
        let cy = self.positions.iter().map(|p| p.y).sum::<f64>() / n as f64;
        self.positions.iter()
            .map(|p| ((p.x-cx).powi(2) + (p.y-cy).powi(2)).sqrt())
            .sum::<f64>() / n as f64
    }
}

// ── Target selection ──────────────────────────────────────────────────────────

pub fn select_target(
    from:     &Point,
    screen_w: f64,
    screen_h: f64,
    state:    &CognitiveState,
    history:  &MovementHistory,
    rng:      &mut SmallRng,
) -> Point {
    let intent = Intent::select(state, rng);
    let (amp_lo, amp_hi) = state.amplitude();

    // Spread boost: if cursor has barely moved recently, push it further
    let spread = history.spatial_spread();
    let boost  = if spread < 35.0 { 2.0 } else { 1.0 };
    let amp_lo = amp_lo * boost;
    let amp_hi = amp_hi * boost;

    let angle  = pick_angle(history.mean_direction(), &intent, rng);
    let roll   = rng.gen::<f64>() * Z_TOTAL;

    if roll < Z_CURSOR {
        let amp = rng.gen_range(amp_lo * 0.25 .. amp_lo);
        cp(from.x + angle.cos()*amp, from.y + angle.sin()*amp, screen_w, screen_h)

    } else if roll < Z_CURSOR + Z_CENTER {
        let cx  = screen_w * rng.gen_range(0.28..0.72);
        let cy  = screen_h * rng.gen_range(0.22..0.68);
        let amp = rng.gen_range(amp_lo..amp_hi) * 0.38;
        cp(cx + angle.cos()*amp, cy + angle.sin()*amp, screen_w, screen_h)

    } else if roll < Z_CURSOR + Z_CENTER + Z_INPUTS {
        let base_y = screen_h * rng.gen_range(0.48..0.88);
        let amp    = rng.gen_range(amp_lo..amp_hi);
        cp(from.x + angle.cos()*amp, base_y + angle.sin()*amp*0.22, screen_w, screen_h)

    } else if roll < Z_CURSOR + Z_CENTER + Z_INPUTS + Z_EDGES {
        let base_y = if rng.gen_bool(0.68) { screen_h * 0.03 } else { screen_h * 0.95 };
        let amp    = rng.gen_range(amp_lo*0.4..amp_hi*0.4);
        cp(from.x + angle.cos()*amp, base_y + angle.sin()*amp*0.07, screen_w, screen_h)

    } else {
        let amp = rng.gen_range(amp_lo .. amp_hi * 1.5);
        cp(from.x + angle.cos()*amp, from.y + angle.sin()*amp, screen_w, screen_h)
    }
}

/// Choose movement angle, biased by intent and away from the recent mean direction.
fn pick_angle(forbidden: Option<f64>, intent: &Intent, rng: &mut SmallRng) -> f64 {
    let base: f64 = match intent {
        Intent::SimulateReading => rng.gen_range(-0.4..0.9) + PI * 0.5, // bias downward
        _                       => rng.gen_range(0.0..2.0 * PI),
    };
    if let Some(fb) = forbidden {
        let reverse = (fb + PI) % (2.0 * PI);
        let diff = (base - reverse).abs() % (2.0 * PI);
        let diff = diff.min(2.0 * PI - diff);
        if diff < PI * 0.30 {
            return reverse + PI * 0.38 * if rng.gen_bool(0.5) { 1.0 } else { -1.0 };
        }
    }
    base
}

#[inline]
fn cp(x: f64, y: f64, w: f64, h: f64) -> Point {
    Point { x: x.clamp(20.0, w-20.0), y: y.clamp(20.0, h-20.0) }
}

// ── Path generation ───────────────────────────────────────────────────────────

/// easeInOutCubic — slow start, fast middle, slow end.
#[inline]
fn ease(t: f64) -> f64 {
    if t < 0.5 { 4.0 * t * t * t }
    else       { 1.0 - (-2.0 * t + 2.0_f64).powi(3) / 2.0 }
}

/// Deterministic smooth noise for micro-variations.
fn snoise(x: f64) -> f64 {
    let xi = x.floor() as i64;
    let xf = x - x.floor();
    let u  = xf * xf * (3.0 - 2.0 * xf);
    fn h(n: i64) -> f64 {
        let n = n.wrapping_mul(1619).wrapping_add(31337);
        let n = n ^ (n >> 8);
        let n = n.wrapping_mul(1_000_003);
        (n & 0x7FFF_FFFF) as f64 / 0x7FFF_FFFF_u64 as f64
    }
    h(xi) + (h(xi+1) - h(xi)) * u
}

/// Generate a human-like curved path.
/// Returns `Vec<(waypoint, step_delay_ms)>`.
pub fn generate_path(
    from:  &Point,
    to:    &Point,
    state: &CognitiveState,
    rng:   &mut SmallRng,
) -> Vec<(Point, u64)> {
    let n     = state.waypoints();
    let cf    = state.curve_factor();
    let ns    = state.noise_strength();
    let hp    = state.hesitation_prob();
    let (hlo, hhi) = state.hesitation_ms();

    let dx  = to.x - from.x;
    let dy  = to.y - from.y;
    let len = (dx*dx + dy*dy).sqrt().max(1.0);

    // Perpendicular unit vector for bowing and noise
    let px = -dy / len;
    let py =  dx / len;

    // S-curve: two control points bow in opposite directions
    let sign: f64 = if rng.gen_bool(0.5) { 1.0 } else { -1.0 };
    let b1 = len * cf * rng.gen_range(0.55..1.45) *  sign;
    let b2 = len * cf * rng.gen_range(0.55..1.45) * -sign;
    let c1 = Point { x: from.x + dx*0.28 + px*b1, y: from.y + dy*0.28 + py*b1 };
    let c2 = Point { x: from.x + dx*0.72 + px*b2, y: from.y + dy*0.72 + py*b2 };

    // Optional overshoot (~28% chance)
    let (ex, ey, overshoot) = if rng.gen_bool(0.28) {
        let os = rng.gen_range(4.0..12.0);
        let nx = dx / len; let ny = dy / len;
        (to.x + nx*os, to.y + ny*os, true)
    } else {
        (to.x, to.y, false)
    };

    let seed: f64 = rng.gen_range(0.0..600.0);
    let mut result = Vec::with_capacity(n + 5);

    for i in 1..=n {
        let t_raw = i as f64 / n as f64;
        let t  = ease(t_raw);
        let mt = 1.0 - t;

        // Cubic Bézier position
        let bx = mt*mt*mt*from.x + 3.0*mt*mt*t*c1.x + 3.0*mt*t*t*c2.x + t*t*t*ex;
        let by = mt*mt*mt*from.y + 3.0*mt*mt*t*c1.y + 3.0*mt*t*t*c2.y + t*t*t*ey;

        // Perpendicular noise (peaks at midpoint, zero at ends)
        let env = (t_raw * PI).sin();
        let nx  = (snoise(seed + t_raw * 9.5) * 2.0 - 1.0) * ns * env;
        let ny  = (snoise(seed + 300.0 + t_raw * 9.5) * 2.0 - 1.0) * ns * env;

        // Velocity-shaped step delay: fast in middle, slow at ends
        // env ≈ 0 at endpoints, ≈ 1 at midpoint → speed ∝ (0.32 + 0.68*env)
        let spd = 0.32 + 0.68 * env;
        let base_delay = (58.0 / spd).round() as u64;

        let delay = if i > 1 && i < n && rng.gen_bool(hp) {
            rng.gen_range(hlo..hhi)      // hesitation pause
        } else {
            base_delay.clamp(18, 95)
        };

        result.push((
            Point { x: bx + px*nx, y: by + py*ny },
            delay,
        ));
    }

    // Micro-correction back from overshoot to exact target
    if overshoot {
        let last = result.last().map(|(p,_)| p.clone()).unwrap();
        let nc = rng.gen_range(2usize..6usize);
        for j in 1..=nc {
            let t = j as f64 / nc as f64;
            result.push((
                Point { x: last.x + (to.x - last.x)*t, y: last.y + (to.y - last.y)*t },
                rng.gen_range(25u64..75),
            ));
        }
    }

    result
}

/// Next movement interval in ms, scaled from user's `move_every` setting.
pub fn next_interval_ms(base_ms: u64, state: &CognitiveState, rng: &mut SmallRng) -> u64 {
    (base_ms as f64 * state.interval_factor(rng)).round() as u64
}
