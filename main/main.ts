import { app, BrowserWindow, ipcMain, Tray, Menu, nativeImage, screen, globalShortcut } from 'electron';
import * as path from 'path';
import { execSync } from 'child_process';
import { MovementEngine } from './movementEngine';
import { ConfigStore } from './configStore';

let mainWindow: BrowserWindow | null = null;
let tray: Tray | null = null;
let movementEngine: MovementEngine | null = null;
let configStore: ConfigStore;
let batteryCheckId: NodeJS.Timeout | null = null;
let activityCheckId: NodeJS.Timeout | null = null;

// Capture mode: waiting for user to click to set auto-click position
let capturingPosition = false;
let captureWindow: BrowserWindow | null = null;

// ── Battery ──────────────────────────────────────────────────────────────────
function getBatteryInfo(): { level: number; onBattery: boolean } {
  try {
    if (process.platform === 'darwin') {
      const out = execSync('pmset -g batt 2>/dev/null', { timeout: 3000 }).toString();
      const match = out.match(/(\d+)%/);
      return { level: match ? parseInt(match[1]) : 100, onBattery: out.includes('Battery Power') };
    } else if (process.platform === 'win32') {
      const out = execSync(
        'powershell -Command "(Get-WmiObject Win32_Battery | Select EstimatedChargeRemaining,BatteryStatus | ConvertTo-Json)"',
        { windowsHide: true, timeout: 3000 }
      ).toString().trim();
      const d = JSON.parse(out);
      return { level: d.EstimatedChargeRemaining ?? 100, onBattery: d.BatteryStatus === 1 };
    } else {
      const level = parseInt(execSync('cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100', { timeout: 2000 }).toString().trim());
      const status = execSync('cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo Charging', { timeout: 2000 }).toString().trim();
      return { level, onBattery: status === 'Discharging' };
    }
  } catch { return { level: 100, onBattery: false }; }
}

function startBatteryMonitor() {
  if (batteryCheckId) clearInterval(batteryCheckId);
  batteryCheckId = setInterval(() => {
    if (!movementEngine?.movementEnabled && !movementEngine?.clickEnabled) return;
    const threshold = configStore.get('batteryThreshold') as number ?? 5;
    if (threshold === 0) return;
    const { level, onBattery } = getBatteryInfo();
    if (onBattery && level <= threshold) {
      disableAll();
      mainWindow?.webContents.send('engine-auto-stopped', 'battery');
    }
  }, 30000);
}

function startActivityMonitor() {
  if (activityCheckId) clearInterval(activityCheckId);
  activityCheckId = setInterval(() => {
    movementEngine?.updateUserActivity();
  }, 500);
}

// ── Engine control ────────────────────────────────────────────────────────────
function enableMovement() {
  if (!movementEngine) return;
  movementEngine.movementEnabled = true;
  if (!movementEngine.isRunning()) movementEngine.start();
  updateTrayState();
  mainWindow?.webContents.send('movement-state-changed', true);
}

function disableMovement() {
  if (!movementEngine) return;
  movementEngine.movementEnabled = false;
  if (!movementEngine.clickEnabled) movementEngine.stop();
  updateTrayState();
  mainWindow?.webContents.send('movement-state-changed', false);
}

function enableClick() {
  if (!movementEngine) return;
  movementEngine.clickEnabled = true;
  if (!movementEngine.isRunning()) movementEngine.start();
  updateTrayState();
  mainWindow?.webContents.send('click-state-changed', true);
}

function disableClick() {
  if (!movementEngine) return;
  movementEngine.clickEnabled = false;
  if (!movementEngine.movementEnabled) movementEngine.stop();
  updateTrayState();
  mainWindow?.webContents.send('click-state-changed', false);
}

function disableAll() {
  if (!movementEngine) return;
  movementEngine.movementEnabled = false;
  movementEngine.clickEnabled = false;
  movementEngine.stop();
  updateTrayState();
  mainWindow?.webContents.send('movement-state-changed', false);
  mainWindow?.webContents.send('click-state-changed', false);
}

function updateTrayState() {
  if (!tray || !movementEngine) return;
  const anyActive = movementEngine.movementEnabled || movementEngine.clickEnabled;

  const iconName = anyActive ? 'tray-icon-active.png' : 'tray-icon.png';
  const iconPath = path.join(__dirname, '..', 'assets', iconName);
  try {
    const icon = nativeImage.createFromPath(iconPath);
    icon.setTemplateImage(true);
    tray.setImage(icon);
  } catch {}

  tray.setTitle(anyActive ? ' ●' : '');
}

// ── Position Capture ──────────────────────────────────────────────────────────
function startPositionCapture() {
  if (capturingPosition) return;
  capturingPosition = true;

  // Hide main window during capture
  mainWindow?.hide();

  // Create a transparent fullscreen overlay that captures next click
  const primaryDisplay = screen.getPrimaryDisplay();
  const { x, y, width, height } = primaryDisplay.bounds;

  captureWindow = new BrowserWindow({
    x, y, width, height,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    resizable: false,
    movable: false,
    focusable: true,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
    },
  });

  const countdownHtml = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    width: 100vw; height: 100vh;
    background: rgba(0,0,0,0.25);
    display: flex; flex-direction: column;
    align-items: center; justify-content: center;
    cursor: crosshair;
    user-select: none;
    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif;
  }
  .card {
    background: rgba(30,30,30,0.92);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border-radius: 16px;
    border: 1px solid rgba(255,255,255,0.12);
    padding: 32px 48px;
    text-align: center;
    color: white;
    pointer-events: none;
  }
  .icon { font-size: 40px; margin-bottom: 12px; }
  .title { font-size: 18px; font-weight: 600; margin-bottom: 8px; }
  .subtitle { font-size: 14px; color: rgba(255,255,255,0.55); }
  .hint { margin-top: 16px; font-size: 13px; color: rgba(255,255,255,0.35); }
</style>
</head>
<body>
  <div class="card">
    <div class="icon">🎯</div>
    <div class="title">Click to Set Auto-Click Position</div>
    <div class="subtitle">Click anywhere on screen to set the target</div>
    <div class="hint">Press Escape to cancel</div>
  </div>
  <script>
    document.addEventListener('click', (e) => {
      window.api && window.api.capturePosition(e.screenX, e.screenY);
    });
  </script>
</body>
</html>`;

  const dataUrl = `data:text/html;charset=utf-8,${encodeURIComponent(countdownHtml)}`;
  captureWindow.loadURL(dataUrl);
  captureWindow.show();
  captureWindow.focus();

  // Escape to cancel
  globalShortcut.register('Escape', () => {
    cancelCapture();
  });

  captureWindow.on('closed', () => {
    captureWindow = null;
    capturingPosition = false;
    globalShortcut.unregister('Escape');
  });
}

function cancelCapture() {
  capturingPosition = false;
  globalShortcut.unregister('Escape');
  captureWindow?.close();
  captureWindow = null;
  mainWindow?.webContents.send('capture-cancelled');
  showWindow();
}

function finishCapture(x: number, y: number) {
  capturingPosition = false;
  globalShortcut.unregister('Escape');
  captureWindow?.close();
  captureWindow = null;
  configStore.set('clickPosition', { x, y });
  mainWindow?.webContents.send('capture-done', { x, y });
  showWindow();
}

// ── Context menu ─────────────────────────────────────────────────────────────
function buildContextMenu(): Menu {
  const mode = (configStore.get('movementMode') as string) || 'jitter';
  const moveEvery = (configStore.get('moveEvery') as number) || 10000;
  const movActive = movementEngine?.movementEnabled ?? false;
  const clkActive = movementEngine?.clickEnabled ?? false;

  const modeLabel: Record<string, string> = { jitter: 'Jitter', drift: 'Drift', circle: 'Circle' };
  const intervalLabel: Record<number, string> = { 3000: '3 sec', 5000: '5 sec', 10000: '10 sec', 30000: '30 sec', 60000: '1 min' };

  return Menu.buildFromTemplate([
    { label: 'CursorFlow', enabled: false },
    { type: 'separator' },
    {
      label: movActive ? '● Movement ON' : '○ Movement OFF',
      click: () => { if (movActive) disableMovement(); else enableMovement(); },
    },
    {
      label: clkActive ? '● Auto Click ON' : '○ Auto Click OFF',
      click: () => { if (clkActive) disableClick(); else enableClick(); },
    },
    { type: 'separator' },
    {
      label: `Mode: ${modeLabel[mode] || 'Jitter'}`,
      submenu: [
        { label: 'Jitter',  type: 'radio', checked: mode === 'jitter',  click: () => setMode('jitter') },
        { label: 'Drift',   type: 'radio', checked: mode === 'drift',   click: () => setMode('drift') },
        { label: 'Circle',  type: 'radio', checked: mode === 'circle',  click: () => setMode('circle') },
      ],
    },
    {
      label: `Interval: ${intervalLabel[moveEvery] || '10 sec'}`,
      submenu: [
        { label: '3 sec',  type: 'radio', checked: moveEvery === 3000,  click: () => setMoveEvery(3000) },
        { label: '5 sec',  type: 'radio', checked: moveEvery === 5000,  click: () => setMoveEvery(5000) },
        { label: '10 sec', type: 'radio', checked: moveEvery === 10000, click: () => setMoveEvery(10000) },
        { label: '30 sec', type: 'radio', checked: moveEvery === 30000, click: () => setMoveEvery(30000) },
        { label: '1 min',  type: 'radio', checked: moveEvery === 60000, click: () => setMoveEvery(60000) },
      ],
    },
    { type: 'separator' },
    { label: 'Settings…', click: () => showWindow() },
    { type: 'separator' },
    {
      label: 'Quit CursorFlow',
      click: () => { movementEngine?.stop(); app.exit(0); },
    },
  ]);
}

function setMode(mode: string) {
  configStore.set('movementMode', mode);
  tray?.setContextMenu(buildContextMenu());
  mainWindow?.webContents.send('config-changed', 'movementMode', mode);
}

function setMoveEvery(ms: number) {
  configStore.set('moveEvery', ms);
  movementEngine?.restartTick();
  tray?.setContextMenu(buildContextMenu());
  mainWindow?.webContents.send('config-changed', 'moveEvery', ms);
}

// ── Window management ─────────────────────────────────────────────────────────
function showWindow() {
  if (!mainWindow) return;
  positionWindowNearTray();
  mainWindow.show();
  mainWindow.focus();
}

function positionWindowNearTray() {
  if (!tray || !mainWindow) return;
  const trayBounds = tray.getBounds();
  const winBounds = mainWindow.getBounds();
  const display = screen.getDisplayNearestPoint({ x: trayBounds.x, y: trayBounds.y });
  const db = display.workArea;

  let x = Math.round(trayBounds.x + trayBounds.width / 2 - winBounds.width / 2);
  let y = Math.round(trayBounds.y + trayBounds.height + 6);

  x = Math.max(db.x + 4, Math.min(x, db.x + db.width - winBounds.width - 4));
  y = Math.max(db.y + 4, Math.min(y, db.y + db.height - winBounds.height - 4));

  mainWindow.setPosition(x, y, false);
}

// ── Create window ─────────────────────────────────────────────────────────────
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 380,
    height: 780,
    resizable: false,
    frame: false,
    transparent: true,
    backgroundColor: '#00000000',  // fully transparent fallback
    vibrancy: 'under-window',
    visualEffectState: 'active',
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
    },
    titleBarStyle: 'hidden',
    trafficLightPosition: { x: 12, y: 14 },
    hasShadow: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    show: false,
  });

  const indexPath = path.join(__dirname, '..', 'renderer', 'index.html');
  mainWindow.loadFile(indexPath);

  mainWindow.on('close', (e) => {
    e.preventDefault();
    mainWindow?.hide();
  });

  mainWindow.on('blur', () => {
    if (!capturingPosition) mainWindow?.hide();
  });

  mainWindow.on('closed', () => { mainWindow = null; });
}

// ── Create tray ───────────────────────────────────────────────────────────────
function createTray() {
  const iconPath = path.join(__dirname, '..', 'assets', 'tray-icon.png');
  let icon = nativeImage.createFromPath(iconPath);
  if (icon.isEmpty()) icon = nativeImage.createEmpty();
  icon.setTemplateImage(true);

  tray = new Tray(icon);
  tray.setToolTip('CursorFlow');

  tray.on('click', () => {
    if (capturingPosition) return;
    if (mainWindow?.isVisible()) {
      mainWindow.hide();
    } else {
      showWindow();
    }
  });

  tray.on('right-click', () => {
    tray?.popUpContextMenu(buildContextMenu());
  });
}

// ── App lifecycle ─────────────────────────────────────────────────────────────
app.whenReady().then(() => {
  if (process.platform === 'darwin') app.dock?.hide();

  configStore = new ConfigStore();
  movementEngine = new MovementEngine(configStore);

  // Auto-stop callback
  movementEngine.onAutoStop = (reason: string) => {
    disableAll();
    mainWindow?.webContents.send('engine-auto-stopped', reason);
  };

  createWindow();
  createTray();
  startBatteryMonitor();
  startActivityMonitor();
  setupIPC();
});

app.on('window-all-closed', () => { /* keep running */ });

// ── IPC ───────────────────────────────────────────────────────────────────────
function setupIPC() {
  ipcMain.handle('get-config', () => configStore.getAll());

  ipcMain.handle('set-config', (_e, key: string, value: any) => {
    configStore.set(key, value);
    return true;
  });

  // Movement toggle
  ipcMain.handle('toggle-movement', (_e, active: boolean) => {
    if (active) enableMovement(); else disableMovement();
    return active;
  });

  // Click toggle
  ipcMain.handle('toggle-click', (_e, active: boolean) => {
    if (active) enableClick(); else disableClick();
    return active;
  });

  // Start position capture flow
  ipcMain.handle('start-position-capture', () => {
    startPositionCapture();
    return true;
  });

  // Called from the capture overlay when user clicks
  ipcMain.handle('capture-position', (_e, x: number, y: number) => {
    finishCapture(x, y);
    return true;
  });

  // Cancel capture
  ipcMain.handle('cancel-capture', () => {
    cancelCapture();
    return true;
  });

  ipcMain.handle('get-cursor-position', () => screen.getCursorScreenPoint());

  ipcMain.handle('quit-app', () => {
    movementEngine?.stop();
    app.exit(0);
  });

  ipcMain.handle('engine-status', () => ({
    movementEnabled: movementEngine?.movementEnabled ?? false,
    clickEnabled: movementEngine?.clickEnabled ?? false,
  }));

  ipcMain.handle('activate-pro', (_e, code: string) => {
    if (code.trim().toUpperCase() === 'SHEEP') {
      configStore.set('isPro', true);
      return { success: true };
    }
    return { success: false, error: 'Invalid activation code' };
  });

  ipcMain.handle('get-battery', () => getBatteryInfo());

  ipcMain.handle('hide-window', () => {
    mainWindow?.hide();
  });

  ipcMain.handle('test-movement', () => {
    return movementEngine?.testMovement() ?? false;
  });
}
