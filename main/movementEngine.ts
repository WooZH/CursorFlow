import { screen } from 'electron';
import { execFileSync, spawn } from 'child_process';
import type { ChildProcessWithoutNullStreams } from 'child_process';
import * as fs from 'fs';
import * as os from 'os';
import * as pathMod from 'path';
import { ConfigStore } from './configStore';

type MovementMode = 'jitter' | 'drift' | 'circle';

// ─────────────────────────────────────────────────────────────────────────────
// Persistent daemon: started once, receives "move X Y\n" on stdin.
// Must use python3 -u (unbuffered) so readline() returns immediately
// instead of waiting for a 4KB block-buffer to fill.
// CGWarpMouseCursorPosition requires NO Accessibility permission.
// ─────────────────────────────────────────────────────────────────────────────
const DAEMON_PATH = pathMod.join(os.tmpdir(), 'cursorflow_daemon.py');
const CLICK_PATH  = pathMod.join(os.tmpdir(), 'cursorflow_click.py');

const DAEMON_SCRIPT = `import sys, ctypes, ctypes.util

lib = ctypes.CDLL(ctypes.util.find_library('CoreGraphics'))

class CGPoint(ctypes.Structure):
    _fields_ = [('x', ctypes.c_double), ('y', ctypes.c_double)]

lib.CGWarpMouseCursorPosition.argtypes = [CGPoint]
lib.CGWarpMouseCursorPosition.restype  = ctypes.c_int32

sys.stdout.write('ready\\n')
sys.stdout.flush()

while True:
    line = sys.stdin.readline()
    if not line:
        break
    parts = line.split()
    if len(parts) == 3 and parts[0] == 'move':
        lib.CGWarpMouseCursorPosition(CGPoint(float(parts[1]), float(parts[2])))
`;

const CLICK_SCRIPT = `import sys, ctypes, ctypes.util, time

lib = ctypes.CDLL(ctypes.util.find_library('CoreGraphics'))

class CGPoint(ctypes.Structure):
    _fields_ = [('x', ctypes.c_double), ('y', ctypes.c_double)]

lib.CGEventCreateMouseEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint32, CGPoint, ctypes.c_uint32]
lib.CGEventCreateMouseEvent.restype  = ctypes.c_void_p
lib.CGEventPost.argtypes = [ctypes.c_uint32, ctypes.c_void_p]
lib.CGEventPost.restype  = None
lib.CFRelease.argtypes   = [ctypes.c_void_p]

kCGHIDEventTap = 0
cmd = sys.argv[1]; x = float(sys.argv[2]); y = float(sys.argv[3])
pt  = CGPoint(x, y)
isRight = cmd == 'right'
btnDown = 3 if isRight else 1; btnUp = 4 if isRight else 2; btnId = 1 if isRight else 0
ev1 = lib.CGEventCreateMouseEvent(None, btnDown, pt, btnId)
lib.CGEventPost(kCGHIDEventTap, ev1); lib.CFRelease(ev1)
time.sleep(0.05)
ev2 = lib.CGEventCreateMouseEvent(None, btnUp, pt, btnId)
lib.CGEventPost(kCGHIDEventTap, ev2); lib.CFRelease(ev2)
`;

function writeHelpers() {
  try {
    fs.writeFileSync(DAEMON_PATH, DAEMON_SCRIPT, { mode: 0o755 });
    fs.writeFileSync(CLICK_PATH,  CLICK_SCRIPT,  { mode: 0o755 });
  } catch (e) {
    console.error('[ME] Could not write helpers:', e);
  }
}

function clamp(v: number, lo: number, hi: number) {
  return Math.max(lo, Math.min(hi, v));
}

function easeInOut(t: number) {
  return t < 0.5 ? 4*t*t*t : 1 - Math.pow(-2*t + 2, 3) / 2;
}

// ─────────────────────────────────────────────────────────────────────────────
export class MovementEngine {

  private running      = false;
  private tickId:      NodeJS.Timeout | null = null;
  private smoothId:    NodeJS.Timeout | null = null;
  private autoStopId:  NodeJS.Timeout | null = null;

  // Daemon process (macOS only)
  private daemon: ChildProcessWithoutNullStreams | null = null;
  private daemonReady = false;

  // Idle tracking (updated by main's 500 ms poll)
  private lastUserPos      = { x: -9999, y: -9999 };
  private lastUserMoveTime = 0;

  // Jitter: pre-computed Bezier waypoints, drained by smoothStep
  private jitterQueue: Array<{ x: number; y: number }> = [];

  // Drift state (used directly in smoothStep for continuous motion)
  private driftAngle = Math.random() * Math.PI * 2;
  private driftTurn  = 0;

  // Circle state
  private circleOrigin = { x: 0, y: 0 };
  private circleAngle  = 0;

  // Smart motion
  private smartTick    = 0;
  private smartMode:   MovementMode | null = null;

  public movementEnabled = false;
  public clickEnabled    = false;
  public onAutoStop: ((reason: string) => void) | null = null;

  constructor(private cfg: ConfigStore) {
    if (process.platform === 'darwin') {
      writeHelpers();
      this.spawnDaemon();
    }
  }

  // ── Daemon ──────────────────────────────────────────────────────────────────

  private spawnDaemon() {
    try {
      // -u = unbuffered stdin/stdout; critical for immediate readline() response
      this.daemon = spawn('python3', ['-u', DAEMON_PATH]) as ChildProcessWithoutNullStreams;
      this.daemonReady = false;
      this.daemon.stdout.on('data', (d: Buffer) => {
        if (d.toString().includes('ready')) {
          this.daemonReady = true;
          console.log('[ME] Daemon ready');
        }
      });
      this.daemon.stderr.on('data', (d: Buffer) =>
        console.error('[ME daemon]', d.toString().trim()));
      this.daemon.on('exit', () => {
        console.warn('[ME] Daemon exited');
        this.daemon = null;
        this.daemonReady = false;
        if (this.running) setTimeout(() => this.spawnDaemon(), 500);
      });
    } catch (e) {
      console.error('[ME] spawnDaemon failed:', e);
    }
  }

  // ── Move primitives ─────────────────────────────────────────────────────────

  private moveTo(x: number, y: number) {
    if (process.platform === 'darwin') {
      if (this.daemonReady && this.daemon?.stdin?.writable) {
        this.daemon.stdin.write(`move ${x} ${y}\n`);
      }
    } else if (process.platform === 'win32') {
      try {
        execFileSync('powershell', ['-Command',
          `Add-Type -AssemblyName System.Windows.Forms;` +
          `[System.Windows.Forms.Cursor]::Position=New-Object System.Drawing.Point(${x},${y})`
        ], { windowsHide: true, timeout: 200 });
      } catch {}
    } else {
      try { execFileSync('xdotool', ['mousemove', String(x), String(y)], { timeout: 200 }); } catch {}
    }
  }

  private clickAt(x: number, y: number, button: string) {
    try {
      if (process.platform === 'darwin') {
        execFileSync('python3', ['-u', CLICK_PATH,
          button === 'Right' ? 'right' : 'left', String(x), String(y)],
          { timeout: 3000 });
      } else if (process.platform === 'win32') {
        const b = button === 'Right' ? '2' : '1';
        execFileSync('powershell', ['-Command',
          `Add-Type -AssemblyName System.Windows.Forms;` +
          `[System.Windows.Forms.Cursor]::Position=New-Object System.Drawing.Point(${x},${y});` +
          `Start-Sleep -Milliseconds 50;` +
          `$s='[DllImport("user32.dll")] public static extern void mouse_event(int f,int x,int y,int d,int e);';` +
          `$t=Add-Type -MemberDefinition $s -Name U -Namespace W -PassThru;` +
          `$t::mouse_event(${b==='1'?6:24},0,0,0,0)`
        ], { windowsHide: true, timeout: 3000 });
      } else {
        execFileSync('xdotool',
          ['mousemove', String(x), String(y), 'click', button==='Right'?'3':'1'],
          { timeout: 3000 });
      }
    } catch (e) {
      console.error('[ME] click failed:', (e as Error).message);
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  start() {
    if (this.running) return;
    this.running      = true;
    this.jitterQueue  = [];

    const pos = screen.getCursorScreenPoint();
    this.lastUserPos      = { ...pos };
    this.circleOrigin     = { ...pos };
    this.lastUserMoveTime = 0;

    const moveEvery = (this.cfg.get('moveEvery') as number) ?? 10000;

    // tick: computes jitter paths + handles auto-stop timer
    this.tickId   = setInterval(() => this.tick(), moveEvery);
    // smoothStep: runs every 40 ms; does the actual cursor moves
    this.smoothId = setInterval(() => this.smoothStep(), 40);

    // Auto-stop (PRO)
    if (this.cfg.get('timerEnabled') as boolean) {
      const h  = (this.cfg.get('timerHour')   as number) ?? 1;
      const m  = (this.cfg.get('timerMinute') as number) ?? 0;
      const ms = (h * 60 + m) * 60 * 1000;
      if (ms > 0) {
        this.autoStopId = setTimeout(() => {
          this.stop();
          this.onAutoStop?.('timer');
        }, ms);
      }
    }
  }

  stop() {
    this.running     = false;
    this.jitterQueue = [];
    if (this.tickId)     { clearInterval(this.tickId);    this.tickId     = null; }
    if (this.smoothId)   { clearInterval(this.smoothId);  this.smoothId   = null; }
    if (this.autoStopId) { clearTimeout(this.autoStopId); this.autoStopId = null; }
  }

  isRunning() { return this.running; }

  /** Called from main's 500 ms interval to detect real user activity. */
  updateUserActivity() {
    if (!this.running) return;
    const pos = screen.getCursorScreenPoint();
    const moved =
      Math.abs(pos.x - this.lastUserPos.x) > 4 ||
      Math.abs(pos.y - this.lastUserPos.y) > 4;
    if (moved) {
      this.lastUserPos      = { ...pos };
      this.lastUserMoveTime = Date.now();
      this.circleOrigin     = { ...pos };
      this.jitterQueue      = [];    // discard our pending path
    }
  }

  restartTick() {
    if (!this.running) return;
    if (this.tickId) { clearInterval(this.tickId); this.tickId = null; }
    const moveEvery = (this.cfg.get('moveEvery') as number) ?? 10000;
    this.tickId = setInterval(() => this.tick(), moveEvery);
  }

  testMovement(): boolean {
    try {
      const { x, y } = screen.getCursorScreenPoint();
      this.moveTo(x + 12, y);
      setTimeout(() => this.moveTo(x, y), 350);
      return true;
    } catch { return false; }
  }

  // ── Private ─────────────────────────────────────────────────────────────────

  /**
   * Runs every moveEvery ms.
   * - Handles clicks (independent of movement).
   * - For JITTER: checks idle, builds a Bezier waypoint path.
   * - Drift/Circle paths are generated live in smoothStep instead.
   */
  private tick() {
    if (!this.running) return;

    // Click is independent — fire every tick regardless of idle
    if (this.clickEnabled) {
      const cp  = this.cfg.get('clickPosition') as { x: number; y: number } | null;
      const btn = (this.cfg.get('clickButton') as string) ?? 'Left';
      if (cp) this.clickAt(cp.x, cp.y, btn);
    }

    if (!this.movementEnabled) return;

    // Smart motion: rotate mode every 20 ticks
    if (this.cfg.get('smartMotion') as boolean) {
      this.smartTick++;
      if (this.smartTick % 20 === 0) {
        const modes: MovementMode[] = ['jitter', 'drift', 'circle'];
        this.smartMode = modes[Math.floor(Math.random() * modes.length)];
      }
    }

    const mode = this.currentMode();
    if (mode !== 'jitter') return; // drift/circle handled in smoothStep

    const startAfter = (this.cfg.get('startAfter') as number) ?? 5000;
    if (Date.now() - this.lastUserMoveTime < startAfter) return;

    // Build Bezier path to a random point 120–220 px away
    const { width, height } = screen.getPrimaryDisplay().workAreaSize;
    const pos   = screen.getCursorScreenPoint();
    const angle = Math.random() * Math.PI * 2;
    const dist  = 120 + Math.random() * 100;
    const tx    = clamp(pos.x + Math.cos(angle) * dist, 20, width  - 20);
    const ty    = clamp(pos.y + Math.sin(angle) * dist, 20, height - 20);

    // Organic mid-point wobble
    const mx = (pos.x + tx) / 2 + (Math.random() - 0.5) * 50;
    const my = (pos.y + ty) / 2 + (Math.random() - 0.5) * 50;

    const STEPS = 35; // 35 × 40 ms = 1.4 s travel
    this.jitterQueue = [];
    for (let i = 1; i <= STEPS; i++) {
      const t  = i / STEPS;
      const e  = easeInOut(t);
      const bx = (1-e)*(1-e)*pos.x + 2*(1-e)*e*mx + e*e*tx;
      const by = (1-e)*(1-e)*pos.y + 2*(1-e)*e*my + e*e*ty;
      this.jitterQueue.push({
        x: Math.round(clamp(bx, 0, width  - 1)),
        y: Math.round(clamp(by, 0, height - 1)),
      });
    }
  }

  /**
   * Runs every 40 ms.
   * - Jitter:  drains the pre-computed waypoint queue.
   * - Drift:   generates the next step in real-time (continuous).
   * - Circle:  generates the next step in real-time (continuous).
   */
  private smoothStep() {
    if (!this.running || !this.movementEnabled) return;

    const startAfter = (this.cfg.get('startAfter') as number) ?? 5000;
    const idle = Date.now() - this.lastUserMoveTime >= startAfter;
    if (!idle) return;

    const { width, height } = screen.getPrimaryDisplay().workAreaSize;
    const mode = this.currentMode();

    if (mode === 'jitter') {
      const pt = this.jitterQueue.shift();
      if (!pt) return;
      this.moveTo(pt.x, pt.y);
      this.lastUserPos = pt;

    } else if (mode === 'drift') {
      // Gently vary turn rate each step
      this.driftTurn += (Math.random() - 0.5) * 0.06;
      this.driftTurn  = clamp(this.driftTurn, -0.18, 0.18);
      this.driftAngle += this.driftTurn;

      const SPEED = 3.5; // px per 40 ms ≈ 87 px/s
      let nx = this.lastUserPos.x + Math.cos(this.driftAngle) * SPEED;
      let ny = this.lastUserPos.y + Math.sin(this.driftAngle) * SPEED;

      // Soft bounce off edges
      if (nx < 30 || nx > width  - 30) { this.driftAngle = Math.PI - this.driftAngle; nx = clamp(nx, 30, width  - 30); }
      if (ny < 30 || ny > height - 30) { this.driftAngle = -this.driftAngle;           ny = clamp(ny, 30, height - 30); }

      const pt = { x: Math.round(nx), y: Math.round(ny) };
      this.moveTo(pt.x, pt.y);
      this.lastUserPos = pt;

    } else {
      // circle: 5° per step → full revolution in 72 steps × 40 ms = 2.88 s
      this.circleAngle += (5 * Math.PI) / 180;
      const RADIUS = 65;
      const pt = {
        x: Math.round(clamp(this.circleOrigin.x + Math.cos(this.circleAngle) * RADIUS, 0, width  - 1)),
        y: Math.round(clamp(this.circleOrigin.y + Math.sin(this.circleAngle) * RADIUS, 0, height - 1)),
      };
      this.moveTo(pt.x, pt.y);
      this.lastUserPos = pt;
    }
  }

  private currentMode(): MovementMode {
    if (this.cfg.get('smartMotion') && this.smartMode) return this.smartMode;
    return (this.cfg.get('movementMode') as MovementMode) ?? 'jitter';
  }
}
