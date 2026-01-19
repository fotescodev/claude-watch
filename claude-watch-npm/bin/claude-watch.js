#!/usr/bin/env node

// Use tsx to run TypeScript directly
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const srcPath = join(__dirname, "..", "src", "index.ts");

// Run with tsx
const result = spawnSync(
  "npx",
  ["tsx", srcPath, ...process.argv.slice(2)],
  {
    stdio: "inherit",
    cwd: process.cwd(),
  }
);

process.exit(result.status ?? 1);
