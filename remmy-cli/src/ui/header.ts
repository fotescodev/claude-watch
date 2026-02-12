// CLI header display — zero dependencies

import { cyan, bold, dim } from "./colors.ts";

export function showHeader(version?: string): void {
  process.stdout.write(`\n  ${bold(cyan("remmy"))}\n`);
  if (version) {
    process.stdout.write(`  ${dim(`v${version}`)}\n`);
  }
  process.stdout.write("\n");
}
