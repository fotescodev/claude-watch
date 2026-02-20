// ANSI color helpers — zero dependencies
// Respects NO_COLOR (https://no-color.org/) and non-TTY environments

function shouldColor(): boolean {
  if (process.env.NO_COLOR !== undefined) return false;
  if (!process.stdout.isTTY) return false;
  return true;
}

function wrap(code: number, text: string): string {
  if (!shouldColor()) return text;
  return `\x1b[${code}m${text}\x1b[0m`;
}

export function red(text: string): string {
  return wrap(31, text);
}

export function green(text: string): string {
  return wrap(32, text);
}

export function yellow(text: string): string {
  return wrap(33, text);
}

export function blue(text: string): string {
  return wrap(34, text);
}

export function cyan(text: string): string {
  return wrap(36, text);
}

export function white(text: string): string {
  return wrap(37, text);
}

export function dim(text: string): string {
  return wrap(2, text);
}

export function bold(text: string): string {
  return wrap(1, text);
}
