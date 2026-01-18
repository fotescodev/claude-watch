import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { getToolsList, callTool } from "./tools.js";
import { getStateManager, resetStateManager } from "./state.js";

/**
 * Create and configure the MCP server
 */
export function createMCPServer(): Server {
  const server = new Server(
    {
      name: "claude-watch",
      version: "1.0.0",
    },
    {
      capabilities: {
        tools: {},
      },
    }
  );

  // Handle tools/list
  server.setRequestHandler(ListToolsRequestSchema, async () => {
    return {
      tools: getToolsList(),
    };
  });

  // Handle tools/call
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;

    try {
      const result = await callTool(name, args || {});
      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify(result),
          },
        ],
      };
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : "Unknown error";
      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify({ error: errorMessage }),
          },
        ],
        isError: true,
      };
    }
  });

  return server;
}

/**
 * Run the MCP server over stdio
 */
export async function runMCPServer(): Promise<void> {
  const server = createMCPServer();
  const transport = new StdioServerTransport();

  // Initialize state manager (starts cloud polling if configured)
  getStateManager();

  // Handle shutdown
  process.on("SIGINT", () => {
    resetStateManager();
    process.exit(0);
  });

  process.on("SIGTERM", () => {
    resetStateManager();
    process.exit(0);
  });

  await server.connect(transport);
}

export { getStateManager, resetStateManager } from "./state.js";
export { tools, getToolsList, callTool } from "./tools.js";
