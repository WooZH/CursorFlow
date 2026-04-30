const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  getConfig:            () => ipcRenderer.invoke('get-config'),
  setConfig:            (key: string, value: any) => ipcRenderer.invoke('set-config', key, value),
  toggleMovement:       (active: boolean) => ipcRenderer.invoke('toggle-movement', active),
  toggleClick:          (active: boolean) => ipcRenderer.invoke('toggle-click', active),
  startPositionCapture: () => ipcRenderer.invoke('start-position-capture'),
  capturePosition:      (x: number, y: number) => ipcRenderer.invoke('capture-position', x, y),
  cancelCapture:        () => ipcRenderer.invoke('cancel-capture'),
  getCursorPosition:    () => ipcRenderer.invoke('get-cursor-position'),
  quit:                 () => ipcRenderer.invoke('quit-app'),
  hideWindow:           () => ipcRenderer.invoke('hide-window'),
  engineStatus:         () => ipcRenderer.invoke('engine-status'),
  activatePro:          (code: string) => ipcRenderer.invoke('activate-pro', code),
  getBattery:           () => ipcRenderer.invoke('get-battery'),
  testMovement:         () => ipcRenderer.invoke('test-movement'),

  // Push events from main → renderer
  onAutoStopped:        (cb: (reason: string) => void) =>
    ipcRenderer.on('engine-auto-stopped', (_e: any, reason: string) => cb(reason)),
  onMovementChanged:    (cb: (active: boolean) => void) =>
    ipcRenderer.on('movement-state-changed', (_e: any, active: boolean) => cb(active)),
  onClickChanged:       (cb: (active: boolean) => void) =>
    ipcRenderer.on('click-state-changed', (_e: any, active: boolean) => cb(active)),
  onConfigChanged:      (cb: (key: string, value: any) => void) =>
    ipcRenderer.on('config-changed', (_e: any, key: string, value: any) => cb(key, value)),
  onCaptureDone:        (cb: (pos: {x: number, y: number}) => void) =>
    ipcRenderer.on('capture-done', (_e: any, pos: {x: number, y: number}) => cb(pos)),
  onCaptureCancelled:   (cb: () => void) =>
    ipcRenderer.on('capture-cancelled', (_e: any) => cb()),
});
