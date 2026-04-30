//! CoreGraphics + ApplicationServices FFI.

use std::ffi::c_void;

// ── CoreGraphics types ────────────────────────────────────────────────────────

#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct CGPoint {
    pub x: f64,
    pub y: f64,
}

type CGEventRef        = *mut c_void;
type CGEventSourceRef  = *mut c_void;

#[allow(non_camel_case_types)] type CGEventTapLocation = u32;
const K_CG_HID_EVENT_TAP: CGEventTapLocation = 0;

#[allow(non_camel_case_types)] type CGEventType = u32;
const K_CG_EVENT_MOUSE_MOVED:      CGEventType = 5;
const K_CG_EVENT_LEFT_MOUSE_DOWN:  CGEventType = 1;
const K_CG_EVENT_LEFT_MOUSE_UP:    CGEventType = 2;
const K_CG_EVENT_RIGHT_MOUSE_DOWN: CGEventType = 3;
const K_CG_EVENT_RIGHT_MOUSE_UP:   CGEventType = 4;

// ── Framework links ───────────────────────────────────────────────────────────

#[link(name = "CoreGraphics", kind = "framework")]
extern "C" {
    fn CGWarpMouseCursorPosition(p: CGPoint) -> i32;
    fn CGEventCreateMouseEvent(
        source: CGEventSourceRef,
        mouse_type: CGEventType,
        mouse_cursor_position: CGPoint,
        mouse_button: i32,
    ) -> CGEventRef;
    fn CGEventPost(tap: CGEventTapLocation, event: CGEventRef);
    fn CFRelease(cf: CGEventRef);
    fn CGEventCreate(source: CGEventSourceRef) -> CGEventRef;
    fn CGEventGetLocation(event: CGEventRef) -> CGPoint;
}

#[link(name = "ApplicationServices", kind = "framework")]
extern "C" {
    fn AXIsProcessTrusted() -> bool;
}

// ── Public API ────────────────────────────────────────────────────────────────

static WARP_LOG_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);

/// Move the cursor to (x, y).
pub fn warp_cursor(x: f64, y: f64) {
    let trusted = is_trusted();
    let count = WARP_LOG_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    // Log every 25 calls (~1 second at 40ms steps) to avoid flooding
    if count % 25 == 0 {
        eprintln!("[warp] #{count} → ({x:.1}, {y:.1})  accessibility={trusted}");
    }

    let pt = CGPoint { x, y };
    unsafe {
        let ev = CGEventCreateMouseEvent(
            std::ptr::null_mut(),
            K_CG_EVENT_MOUSE_MOVED,
            pt,
            0,
        );
        if !ev.is_null() {
            CGEventPost(K_CG_HID_EVENT_TAP, ev);
            CFRelease(ev);
            if count % 25 == 0 {
                eprintln!("[warp]   CGEventPost fired (trusted={trusted})");
            }
        } else if count % 25 == 0 {
            eprintln!("[warp]   CGEventCreateMouseEvent returned NULL");
        }
        let rc = CGWarpMouseCursorPosition(pt);
        if count % 25 == 0 {
            eprintln!("[warp]   CGWarpMouseCursorPosition rc={rc}");
        }
    }
}

/// Read the current cursor position.
pub fn get_cursor_pos() -> (f64, f64) {
    unsafe {
        let ev = CGEventCreate(std::ptr::null_mut());
        if ev.is_null() { return (0.0, 0.0); }
        let pt = CGEventGetLocation(ev);
        CFRelease(ev);
        (pt.x, pt.y)
    }
}

/// Perform a left or right click. Requires Accessibility.
pub fn post_click(x: f64, y: f64, button: &str) -> bool {
    if !is_trusted() { return false; }
    let pt = CGPoint { x, y };
    let (down_type, up_type, btn_num) = if button == "Right" {
        (K_CG_EVENT_RIGHT_MOUSE_DOWN, K_CG_EVENT_RIGHT_MOUSE_UP, 1)
    } else {
        (K_CG_EVENT_LEFT_MOUSE_DOWN, K_CG_EVENT_LEFT_MOUSE_UP, 0)
    };
    unsafe {
        let down = CGEventCreateMouseEvent(std::ptr::null_mut(), down_type, pt, btn_num);
        if !down.is_null() { CGEventPost(K_CG_HID_EVENT_TAP, down); CFRelease(down); }
        let up   = CGEventCreateMouseEvent(std::ptr::null_mut(), up_type,   pt, btn_num);
        if !up.is_null()   { CGEventPost(K_CG_HID_EVENT_TAP, up);   CFRelease(up);   }
    }
    true
}

/// Returns true if Accessibility permission has been granted.
pub fn is_trusted() -> bool {
    unsafe { AXIsProcessTrusted() }
}
