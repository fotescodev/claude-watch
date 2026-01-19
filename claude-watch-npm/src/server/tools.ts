import { z } from "zod";
import { ActionType } from "../types/index.js";
import { getStateManager } from "./state.js";

/**
 * MCP Tool definitions for Claude Watch
 */
export const tools = {
  watch_notify: {
    name: "watch_notify",
    description: "Send a notification to the connected Apple Watch",
    inputSchema: {
      type: "object" as const,
      properties: {
        title: {
          type: "string",
          description: "Notification title",
        },
        message: {
          type: "string",
          description: "Notification message",
        },
      },
      required: ["title", "message"],
    },
    handler: async (args: { title: string; message: string }) => {
      const manager = getStateManager();
      const success = await manager.notify(args.title, args.message);
      return { success };
    },
  },

  watch_request_approval: {
    name: "watch_request_approval",
    description:
      "Request approval from watch for an action. Blocks until approved/rejected.",
    inputSchema: {
      type: "object" as const,
      properties: {
        action_type: {
          type: "string",
          enum: [
            "file_edit",
            "file_create",
            "file_delete",
            "bash",
            "tool_use",
          ],
          description: "Type of action requiring approval",
        },
        title: {
          type: "string",
          description: "Short title for the action",
        },
        description: {
          type: "string",
          description: "Detailed description",
        },
        file_path: {
          type: "string",
          description: "File path if applicable",
        },
        command: {
          type: "string",
          description: "Command if bash action",
        },
      },
      required: ["action_type", "title", "description"],
    },
    handler: async (args: {
      action_type: string;
      title: string;
      description: string;
      file_path?: string;
      command?: string;
    }) => {
      const manager = getStateManager();
      const result = await manager.requestApproval({
        type: args.action_type as (typeof ActionType)[keyof typeof ActionType],
        title: args.title,
        description: args.description,
        file_path: args.file_path,
        command: args.command,
      });
      return result;
    },
  },

  watch_update_progress: {
    name: "watch_update_progress",
    description: "Update task progress shown on watch",
    inputSchema: {
      type: "object" as const,
      properties: {
        progress: {
          type: "number",
          minimum: 0,
          maximum: 1,
          description: "Progress value between 0 and 1",
        },
        task_name: {
          type: "string",
          description: "Optional task name to update",
        },
      },
      required: ["progress"],
    },
    handler: async (args: { progress: number; task_name?: string }) => {
      const manager = getStateManager();
      const success = await manager.updateProgress(args.progress, args.task_name);
      return { success };
    },
  },

  watch_set_task: {
    name: "watch_set_task",
    description: "Set the current task being worked on",
    inputSchema: {
      type: "object" as const,
      properties: {
        name: {
          type: "string",
          description: "Task name",
        },
        description: {
          type: "string",
          description: "Task description",
        },
      },
      required: ["name"],
    },
    handler: async (args: { name: string; description?: string }) => {
      const manager = getStateManager();
      const success = await manager.setTask(args.name, args.description || "");
      return { success };
    },
  },

  watch_complete_task: {
    name: "watch_complete_task",
    description: "Mark current task as complete",
    inputSchema: {
      type: "object" as const,
      properties: {
        success: {
          type: "boolean",
          default: true,
          description: "Whether the task completed successfully",
        },
      },
    },
    handler: async (args: { success?: boolean }) => {
      const manager = getStateManager();
      const result = await manager.completeTask(args.success ?? true);
      return { success: result };
    },
  },

  watch_get_state: {
    name: "watch_get_state",
    description: "Get current watch/session state",
    inputSchema: {
      type: "object" as const,
      properties: {},
    },
    handler: async () => {
      const manager = getStateManager();
      return manager.getState();
    },
  },
};

/**
 * Get all tools as an array for MCP tools/list
 */
export function getToolsList() {
  return Object.values(tools).map((tool) => ({
    name: tool.name,
    description: tool.description,
    inputSchema: tool.inputSchema,
  }));
}

/**
 * Call a tool by name
 */
export async function callTool(
  name: string,
  args: Record<string, unknown>
): Promise<unknown> {
  const tool = tools[name as keyof typeof tools];
  if (!tool) {
    throw new Error(`Unknown tool: ${name}`);
  }
  return tool.handler(args as never);
}
