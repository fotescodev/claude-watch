import { existsSync, mkdirSync, readFileSync, writeFileSync } from "fs";
import { homedir } from "os";
import { join } from "path";
import type { MCPConfig, MCPServerConfig } from "../types/index.js";

const CLAUDE_DIR = join(homedir(), ".claude");
const MCP_CONFIG_PATH = join(CLAUDE_DIR, ".mcp.json");

/**
 * Ensure the ~/.claude directory exists
 */
function ensureClaudeDir(): void {
  if (!existsSync(CLAUDE_DIR)) {
    mkdirSync(CLAUDE_DIR, { recursive: true });
  }
}

/**
 * Read the current MCP config file
 */
export function readMCPConfig(): MCPConfig {
  ensureClaudeDir();

  if (!existsSync(MCP_CONFIG_PATH)) {
    return { mcpServers: {} };
  }

  try {
    const content = readFileSync(MCP_CONFIG_PATH, "utf-8");
    const config = JSON.parse(content);
    return {
      mcpServers: config.mcpServers || {},
    };
  } catch (error) {
    // If file is corrupted, start fresh
    return { mcpServers: {} };
  }
}

/**
 * Write the MCP config file
 */
export function writeMCPConfig(config: MCPConfig): void {
  ensureClaudeDir();
  writeFileSync(MCP_CONFIG_PATH, JSON.stringify(config, null, 2) + "\n");
}

/**
 * Add claude-watch server to MCP config
 */
export function addClaudeWatchServer(): void {
  const config = readMCPConfig();

  // Use npx to run the package
  // This works whether installed globally or via npx
  const serverConfig: MCPServerConfig = {
    command: "npx",
    args: ["claude-watch", "serve"],
  };

  config.mcpServers["claude-watch"] = serverConfig;
  writeMCPConfig(config);
}

/**
 * Remove claude-watch server from MCP config
 */
export function removeClaudeWatchServer(): void {
  const config = readMCPConfig();
  delete config.mcpServers["claude-watch"];
  writeMCPConfig(config);
}

/**
 * Check if claude-watch server is configured
 */
export function isClaudeWatchConfigured(): boolean {
  const config = readMCPConfig();
  return "claude-watch" in config.mcpServers;
}

/**
 * Get the MCP config file path
 */
export function getMCPConfigPath(): string {
  return MCP_CONFIG_PATH;
}
