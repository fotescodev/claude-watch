/**
 * Bridge launcher — spawns and manages the Python bridge server process.
 *
 * The bridge server connects the Claude CLI (via WebSocket/NDJSON) to the
 * cloud relay (via HTTP), enabling watch-based approval flow.
 *
 * Zero runtime dependencies: uses node:child_process and native fetch().
 */

import { spawn, execSync } from "node:child_process";
import type { ChildProcess } from "node:child_process";
import { existsSync } from "node:fs";
import { join, dirname } from "node:path";

export interface BridgeOptions {
  pairingId: string;
  port?: number; // Default 8787
  verbose?: boolean;
  pythonPath?: string; // Override python binary (for testing)
  cloudUrl?: string; // Cloud worker URL for relay sync
}

export interface BridgeProcess {
  process: ChildProcess;
  port: number;
  httpPort: number; // port + 1
  pairingId: string;
}

const DEFAULT_PORT = 8787;
const MAX_PORT_ATTEMPTS = 5; // Try ports 8787-8791
const HEALTH_POLL_INTERVAL_MS = 200;
const HEALTH_TIMEOUT_MS = 10_000;
const STOP_TIMEOUT_MS = 3_000;

/**
 * Find a working Python 3 binary on the system.
 * Tries `python3` first, then `python`.
 * Returns the binary name that works, or null if neither is found.
 */
export function findPython(): string | null {
  for (const candidate of ["python3", "python"]) {
    try {
      const output = execSync(`${candidate} --version`, {
        stdio: ["pipe", "pipe", "pipe"],
        timeout: 5_000,
      }).toString();
      // Ensure it's Python 3.x
      if (output.includes("Python 3")) {
        return candidate;
      }
    } catch {
      // candidate not found or failed, try next
    }
  }
  return null;
}

/**
 * Poll the bridge HTTP health endpoint until it returns 200 or timeout.
 * Returns true if healthy, false on timeout.
 */
export async function waitForHealth(
  httpPort: number,
  timeoutMs: number = HEALTH_TIMEOUT_MS,
): Promise<boolean> {
  const deadline = Date.now() + timeoutMs;
  const url = `http://localhost:${httpPort}/health`;

  while (Date.now() < deadline) {
    try {
      const response = await fetch(url, {
        method: "GET",
        signal: AbortSignal.timeout(1_000),
      });
      if (response.ok) {
        return true;
      }
    } catch {
      // Server not up yet, keep polling
    }
    await sleep(HEALTH_POLL_INTERVAL_MS);
  }
  return false;
}

/**
 * Resolve the repo root containing `MCPServer/bridge/`.
 * Walks up from the remmy-cli package directory.
 */
function findRepoRoot(): string | null {
  // Start from this file's directory and walk up
  let dir = typeof import.meta.dirname === "string"
    ? import.meta.dirname
    : dirname(new URL(import.meta.url).pathname);

  // Walk up at most 10 levels to find the repo root
  for (let i = 0; i < 10; i++) {
    const bridgePath = join(dir, "MCPServer", "bridge", "__main__.py");
    if (existsSync(bridgePath)) {
      return dir;
    }
    const parent = dirname(dir);
    if (parent === dir) {
      break; // Reached filesystem root
    }
    dir = parent;
  }
  return null;
}

/**
 * Check if a port is likely in use by attempting to fetch from it.
 * Returns true if something responds (port is busy).
 */
async function isPortBusy(port: number): Promise<boolean> {
  try {
    await fetch(`http://localhost:${port}`, {
      method: "GET",
      signal: AbortSignal.timeout(300),
    });
    return true; // Got a response — port is in use
  } catch (error: unknown) {
    // Connection refused = port is free.
    // Other errors (timeout, DNS) also treated as free — conservative approach.
    if (error instanceof TypeError || error instanceof DOMException) {
      // fetch throws TypeError for connection refused in most runtimes
      const msg = (error as Error).message.toLowerCase();
      if (msg.includes("refused") || msg.includes("econnrefused") || msg.includes("fetch failed")) {
        return false;
      }
    }
    return false;
  }
}

/**
 * Launch the Python bridge server.
 *
 * 1. Finds Python 3 binary (or uses opts.pythonPath)
 * 2. Locates MCPServer/bridge relative to the repo root
 * 3. Finds an available port (tries DEFAULT_PORT through DEFAULT_PORT + 4)
 * 4. Spawns the process with correct PYTHONPATH
 * 5. Waits for the HTTP health endpoint to respond
 */
export async function launchBridge(opts: BridgeOptions): Promise<BridgeProcess> {
  // 1. Find Python
  const pythonBin = opts.pythonPath ?? findPython();
  if (!pythonBin) {
    throw new Error(
      "Python 3 not found. Install Python 3.8+ and ensure `python3` or `python` is on your PATH.",
    );
  }

  // 2. Find repo root with MCPServer/bridge
  const repoRoot = findRepoRoot();
  if (!repoRoot) {
    throw new Error(
      "Could not find MCPServer/bridge/ module. Ensure you are running from within the claude-watch repository.",
    );
  }

  // 3. Find available port
  const basePort = opts.port ?? DEFAULT_PORT;
  let port = basePort;
  let foundPort = false;

  for (let attempt = 0; attempt < MAX_PORT_ATTEMPTS; attempt++) {
    const candidate = basePort + attempt;
    const busy = await isPortBusy(candidate);
    if (!busy) {
      port = candidate;
      foundPort = true;
      break;
    }
  }

  if (!foundPort) {
    throw new Error(
      `All ports ${basePort}-${basePort + MAX_PORT_ATTEMPTS - 1} are in use. ` +
        "Stop other services or specify a different port.",
    );
  }

  const httpPort = port + 1;

  // 4. Build spawn args
  const args = [
    "-m",
    "MCPServer.bridge",
    "--port",
    String(port),
    "--pairing-id",
    opts.pairingId,
  ];

  if (opts.cloudUrl) {
    args.push("--cloud-url", opts.cloudUrl);
  }

  if (opts.verbose) {
    args.push("--verbose");
  }

  // 5. Spawn process with PYTHONPATH set to repo root
  const stderrChunks: Buffer[] = [];

  const child = spawn(pythonBin, args, {
    cwd: repoRoot,
    env: {
      ...process.env,
      PYTHONPATH: repoRoot,
    },
    stdio: ["ignore", "ignore", "pipe"], // ignore stdin/stdout, capture stderr
  });

  // Capture stderr for error reporting
  child.stderr?.on("data", (chunk: Buffer) => {
    stderrChunks.push(chunk);
  });

  // Handle immediate spawn failure
  const spawnError = await new Promise<Error | null>((resolve) => {
    child.on("error", (err) => resolve(err));
    // Give it a moment to fail or succeed spawning
    setTimeout(() => resolve(null), 200);
  });

  if (spawnError) {
    throw new Error(`Failed to spawn bridge process: ${spawnError.message}`);
  }

  // 6. Wait for health check
  const healthy = await waitForHealth(httpPort);

  if (!healthy) {
    // Collect stderr for diagnostics
    const stderr = Buffer.concat(stderrChunks).toString("utf-8").trim();
    // Kill the unhealthy process
    child.kill("SIGKILL");

    const detail = stderr ? `\nBridge stderr:\n${stderr}` : "";
    throw new Error(
      `Bridge server failed to start within ${HEALTH_TIMEOUT_MS / 1000}s on port ${port}.${detail}`,
    );
  }

  return {
    process: child,
    port,
    httpPort,
    pairingId: opts.pairingId,
  };
}

/**
 * Stop a running bridge process gracefully.
 * Sends SIGTERM, waits up to 3s, then SIGKILL if still running.
 */
export async function stopBridge(bp: BridgeProcess): Promise<void> {
  const child = bp.process;

  // Already exited
  if (child.exitCode !== null || child.killed) {
    return;
  }

  return new Promise<void>((resolve) => {
    let resolved = false;

    const onExit = () => {
      if (!resolved) {
        resolved = true;
        clearTimeout(killTimer);
        resolve();
      }
    };

    child.once("exit", onExit);
    child.once("close", onExit);

    // Send SIGTERM for graceful shutdown
    child.kill("SIGTERM");

    // After timeout, force kill
    const killTimer = setTimeout(() => {
      if (!resolved) {
        child.kill("SIGKILL");
        // Resolve after SIGKILL — don't wait indefinitely
        resolved = true;
        resolve();
      }
    }, STOP_TIMEOUT_MS);
  });
}

/** Promise-based sleep utility. */
function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
