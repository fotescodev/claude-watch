/**
 * Tests for hooks-config — hook installation and registration.
 *
 * Mocks the node:fs and node:os modules to avoid touching the real filesystem.
 */

import { describe, test, expect, mock, beforeEach } from "bun:test";

// ---------------------------------------------------------------------------
// Shared mock state
// ---------------------------------------------------------------------------

const mockFiles: Map<string, string> = new Map();
let mockHomedir = "/home/testuser";

// Track calls
const calls = {
  mkdirSync: [] as string[],
  writeFileSync: [] as Array<[string, string]>,
  copyFileSync: [] as Array<[string, string]>,
  chmodSync: [] as Array<[string, number]>,
  unlinkSync: [] as string[],
};

// ---------------------------------------------------------------------------
// Module mocks
// ---------------------------------------------------------------------------

// Note: bun mock.module() bleeds across files in the same test run.
// We must re-export everything from the real modules to avoid breaking
// other test files (like config.test.ts) that import from node:fs / node:os.
import * as realFs from "node:fs";
import * as realOs from "node:os";

mock.module("node:fs", () => ({
  ...realFs,
  existsSync: (path: string) => mockFiles.has(path),
  mkdirSync: (path: string, _opts?: unknown) => {
    calls.mkdirSync.push(path);
  },
  readFileSync: (path: string, _encoding?: string) => {
    const content = mockFiles.get(path);
    if (content === undefined) {
      throw new Error(`ENOENT: no such file or directory, open '${path}'`);
    }
    return content;
  },
  writeFileSync: (path: string, content: string) => {
    calls.writeFileSync.push([path, content]);
    mockFiles.set(path, content);
  },
  copyFileSync: (src: string, dest: string) => {
    calls.copyFileSync.push([src, dest]);
    mockFiles.set(dest, mockFiles.get(src) ?? "copied");
  },
  chmodSync: (path: string, mode: number) => {
    calls.chmodSync.push([path, mode]);
  },
  unlinkSync: (path: string) => {
    calls.unlinkSync.push(path);
    mockFiles.delete(path);
  },
}));

mock.module("node:os", () => ({
  ...realOs,
  homedir: () => mockHomedir,
}));

// Import AFTER mocking
const {
  installHookScript,
  registerHook,
  unregisterHook,
  isHookConfigured,
  setupHook,
  removeHook,
  getInstalledHookPath,
} = await import("./hooks-config.ts");

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("hooks-config", () => {
  beforeEach(() => {
    mockFiles.clear();
    mockHomedir = "/home/testuser";

    // Reset call trackers
    calls.mkdirSync = [];
    calls.writeFileSync = [];
    calls.copyFileSync = [];
    calls.chmodSync = [];
    calls.unlinkSync = [];
  });

  describe("getInstalledHookPath", () => {
    test("returns path under ~/.claude/hooks/", () => {
      const path = getInstalledHookPath();
      expect(path).toContain(".claude/hooks/watch-approval-cloud.py");
    });
  });

  describe("installHookScript", () => {
    test("copies bundled script to ~/.claude/hooks/ when available from CWD", () => {
      // Simulate the hook existing in CWD/hooks/
      const cwdHookPath = `${process.cwd()}/hooks/watch-approval-cloud.py`;
      mockFiles.set(cwdHookPath, "#!/usr/bin/env python3\n# hook script");

      const result = installHookScript();

      expect(result).toBe(true);
      expect(calls.copyFileSync.length).toBeGreaterThanOrEqual(1);
      expect(calls.chmodSync.length).toBeGreaterThanOrEqual(1);
      // Should set executable permissions (0o755)
      expect(calls.chmodSync[0]![1]).toBe(0o755);
    });

    test("copies from dist/hooks/ when src/lib/ path does not exist", () => {
      // Simulate running from dist/ — only dist/hooks/ path exists
      // import.meta.dirname in test context points to src/lib/,
      // so the ../../hooks/ path is the "src" path. We skip that
      // and instead set up the dist-relative path (currentDir + /hooks/)
      const currentDir = import.meta.dirname ?? process.cwd();
      const distHookPath = `${currentDir}/hooks/watch-approval-cloud.py`;
      mockFiles.set(distHookPath, "#!/usr/bin/env python3\n# dist hook");

      const result = installHookScript();

      expect(result).toBe(true);
      expect(calls.copyFileSync.length).toBeGreaterThanOrEqual(1);
    });

    test("returns false when no hook script found anywhere", () => {
      // No hook files exist
      const result = installHookScript();
      expect(result).toBe(false);
    });
  });

  describe("registerHook", () => {
    test("creates settings.json with PreToolUse entry when no settings exist", () => {
      registerHook();

      expect(calls.writeFileSync).toHaveLength(1);
      const [path, content] = calls.writeFileSync[0]!;
      expect(path).toContain("settings.json");

      const settings = JSON.parse(content);
      expect(settings.hooks.PreToolUse).toHaveLength(1);
      expect(settings.hooks.PreToolUse[0].matcher).toBe("");
      expect(settings.hooks.PreToolUse[0].hooks[0].command).toContain(
        "watch-approval-cloud.py",
      );
    });

    test("adds entry to existing settings without clobbering", () => {
      // Pre-existing settings with other hooks
      const existingSettings = {
        permissions: { allow: ["Read"] },
        hooks: {
          PreToolUse: [
            { matcher: "Bash", hooks: [{ type: "command", command: "other-hook.sh" }] },
          ],
        },
      };
      mockFiles.set(
        "/home/testuser/.claude/settings.json",
        JSON.stringify(existingSettings),
      );

      registerHook();

      expect(calls.writeFileSync).toHaveLength(1);
      const settings = JSON.parse(calls.writeFileSync[0]![1]!);
      // Should have both: existing + new
      expect(settings.hooks.PreToolUse).toHaveLength(2);
      expect(settings.permissions.allow).toEqual(["Read"]);
    });

    test("updates existing watch-approval entry (idempotent)", () => {
      // Pre-existing settings with our hook already registered
      const existingSettings = {
        hooks: {
          PreToolUse: [
            {
              matcher: "",
              hooks: [
                { type: "command", command: "/old/path/watch-approval-cloud.py" },
              ],
            },
          ],
        },
      };
      mockFiles.set(
        "/home/testuser/.claude/settings.json",
        JSON.stringify(existingSettings),
      );

      registerHook();

      expect(calls.writeFileSync).toHaveLength(1);
      const settings = JSON.parse(calls.writeFileSync[0]![1]!);
      // Should still have just 1 entry (updated, not duplicated)
      expect(settings.hooks.PreToolUse).toHaveLength(1);
      // Path should be the new path
      expect(settings.hooks.PreToolUse[0].hooks[0].command).toContain(
        "/home/testuser/.claude/hooks/watch-approval-cloud.py",
      );
    });
  });

  describe("unregisterHook", () => {
    test("removes watch-approval entry from settings", () => {
      const existingSettings = {
        hooks: {
          PreToolUse: [
            { matcher: "Bash", hooks: [{ type: "command", command: "other.sh" }] },
            {
              matcher: "",
              hooks: [
                { type: "command", command: "/path/watch-approval-cloud.py" },
              ],
            },
          ],
        },
      };
      mockFiles.set(
        "/home/testuser/.claude/settings.json",
        JSON.stringify(existingSettings),
      );

      unregisterHook();

      expect(calls.writeFileSync).toHaveLength(1);
      const settings = JSON.parse(calls.writeFileSync[0]![1]!);
      expect(settings.hooks.PreToolUse).toHaveLength(1);
      expect(settings.hooks.PreToolUse[0].hooks[0].command).toBe("other.sh");
    });

    test("succeeds when no PreToolUse exists", () => {
      const result = unregisterHook();
      expect(result).toBe(true);
    });
  });

  describe("isHookConfigured", () => {
    test("returns true when script exists AND registered in settings", () => {
      const hookPath = getInstalledHookPath();
      mockFiles.set(hookPath, "# hook");
      mockFiles.set(
        "/home/testuser/.claude/settings.json",
        JSON.stringify({
          hooks: {
            PreToolUse: [
              {
                matcher: "",
                hooks: [{ type: "command", command: hookPath }],
              },
            ],
          },
        }),
      );

      expect(isHookConfigured()).toBe(true);
    });

    test("returns false when script does not exist", () => {
      // Settings exist but no script file
      mockFiles.set(
        "/home/testuser/.claude/settings.json",
        JSON.stringify({
          hooks: {
            PreToolUse: [
              {
                matcher: "",
                hooks: [
                  { type: "command", command: "/path/watch-approval-cloud.py" },
                ],
              },
            ],
          },
        }),
      );

      expect(isHookConfigured()).toBe(false);
    });

    test("returns false when not registered in settings", () => {
      const hookPath = getInstalledHookPath();
      mockFiles.set(hookPath, "# hook");
      // No settings file
      expect(isHookConfigured()).toBe(false);
    });
  });

  describe("setupHook", () => {
    test("installs and registers in one call", () => {
      // Make the CWD hook available
      const cwdHookPath = `${process.cwd()}/hooks/watch-approval-cloud.py`;
      mockFiles.set(cwdHookPath, "# hook");

      const result = setupHook();

      expect(result.installed).toBe(true);
      expect(result.registered).toBe(true);
    });

    test("returns installed=false, registered=false when no hook script found", () => {
      const result = setupHook();

      expect(result.installed).toBe(false);
      expect(result.registered).toBe(false);
    });
  });

  describe("removeHook", () => {
    test("unregisters and deletes script file", () => {
      const hookPath = getInstalledHookPath();
      mockFiles.set(hookPath, "# hook");
      mockFiles.set(
        "/home/testuser/.claude/settings.json",
        JSON.stringify({
          hooks: {
            PreToolUse: [
              {
                matcher: "",
                hooks: [{ type: "command", command: hookPath }],
              },
            ],
          },
        }),
      );

      removeHook();

      // Should unregister from settings
      const settings = JSON.parse(calls.writeFileSync[0]![1]!);
      expect(settings.hooks.PreToolUse).toHaveLength(0);

      // Should delete script file
      expect(calls.unlinkSync).toContain(hookPath);
    });
  });
});
