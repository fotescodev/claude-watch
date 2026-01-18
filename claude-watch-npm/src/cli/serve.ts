import { runMCPServer } from "../server/index.js";

/**
 * Start the MCP server
 * This is called by Claude Code via the MCP configuration
 */
export async function runServe(): Promise<void> {
  await runMCPServer();
}
