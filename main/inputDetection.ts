import { screen } from 'electron';

export class InputDetection {
  private lastPos = { x: 0, y: 0 };
  private lastMoveTime = Date.now();
  private listeners: Array<(idle: boolean) => void> = [];
  private pollId: NodeJS.Timeout | null = null;

  start(pollInterval = 500) {
    const pos = screen.getCursorScreenPoint();
    this.lastPos = { ...pos };
    this.pollId = setInterval(() => this.poll(), pollInterval);
  }

  stop() {
    if (this.pollId) {
      clearInterval(this.pollId);
      this.pollId = null;
    }
  }

  private poll() {
    const pos = screen.getCursorScreenPoint();
    const moved =
      Math.abs(pos.x - this.lastPos.x) > 2 ||
      Math.abs(pos.y - this.lastPos.y) > 2;

    if (moved) {
      this.lastPos = { ...pos };
      this.lastMoveTime = Date.now();
      this.emit(false);
    }
  }

  getIdleTime(): number {
    return Date.now() - this.lastMoveTime;
  }

  onIdleChange(fn: (idle: boolean) => void) {
    this.listeners.push(fn);
  }

  private emit(idle: boolean) {
    this.listeners.forEach((fn) => fn(idle));
  }
}
