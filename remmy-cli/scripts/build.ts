#!/usr/bin/env bun

/**
 * Build script for remmy-watch CLI.
 *
 * Produces a Node-compatible ESM bundle at dist/cli.mjs with a
 * #!/usr/bin/env node shebang so `npx remmy-watch` works without Bun.
 */

import { $ } from "bun";
import { existsSync, mkdirSync, cpSync } from "node:fs";

// Ensure dist/ exists
if (!existsSync("dist")) {
  mkdirSync("dist");
}

// Bundle for Node compatibility
await $`bun build src/cli.ts --target node --outfile dist/cli.mjs --minify`;

// Prepend shebang if missing
const file = Bun.file("dist/cli.mjs");
const content = await file.text();
if (!content.startsWith("#!")) {
  await Bun.write("dist/cli.mjs", `#!/usr/bin/env node\n${content}`);
}

// Copy hooks/ into dist/hooks/ so getBundledHookPath() works from built output
cpSync("hooks", "dist/hooks", { recursive: true });

// Make executable
await $`chmod +x dist/cli.mjs`;

console.log("Build complete: dist/cli.mjs");
