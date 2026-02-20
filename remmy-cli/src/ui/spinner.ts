// CLI spinner — zero dependencies
// Uses braille animation frames at 80ms interval

const FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"] as const;
const INTERVAL_MS = 80;

const HIDE_CURSOR = "\x1b[?25l";
const SHOW_CURSOR = "\x1b[?25h";
const CLEAR_LINE = "\r\x1b[K";

export class Spinner {
  private timer: ReturnType<typeof setInterval> | null = null;
  private frameIndex = 0;

  start(message: string): void {
    this.stop();
    this.frameIndex = 0;
    process.stdout.write(HIDE_CURSOR);
    this.timer = setInterval(() => {
      const frame = FRAMES[this.frameIndex % FRAMES.length]!;
      process.stdout.write(`${CLEAR_LINE}${frame} ${message}`);
      this.frameIndex++;
    }, INTERVAL_MS);
  }

  succeed(message: string): void {
    this.clearTimer();
    process.stdout.write(`${CLEAR_LINE}\x1b[32m✓\x1b[0m ${message}\n`);
    process.stdout.write(SHOW_CURSOR);
  }

  fail(message: string): void {
    this.clearTimer();
    process.stdout.write(`${CLEAR_LINE}\x1b[31m✗\x1b[0m ${message}\n`);
    process.stdout.write(SHOW_CURSOR);
  }

  stop(): void {
    this.clearTimer();
    process.stdout.write(CLEAR_LINE);
    process.stdout.write(SHOW_CURSOR);
  }

  private clearTimer(): void {
    if (this.timer !== null) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }
}
