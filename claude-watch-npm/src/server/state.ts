import {
  type PendingAction,
  type SessionState,
  type ActionStatus,
  type WatchMessage,
  ActionStatus as ActionStatusEnum,
  SessionStatus,
  createDefaultSessionState,
  createPendingAction,
  type ActionType,
} from "../types/index.js";
import { CloudClient, getCloudClient } from "../cloud/client.js";

/**
 * Manages session state and action approval flows
 */
export class SessionStateManager {
  private state: SessionState;
  private cloudClient: CloudClient;
  private actionResolvers: Map<
    string,
    { resolve: (status: ActionStatus) => void; timeout: NodeJS.Timeout }
  > = new Map();

  constructor(cloudClient?: CloudClient) {
    this.state = createDefaultSessionState();
    this.cloudClient = cloudClient || getCloudClient();

    // Start listening for messages from watch
    if (this.cloudClient.isConfigured()) {
      this.cloudClient.startPolling(this.handleWatchMessage.bind(this));
    }
  }

  /**
   * Get current state
   */
  getState(): SessionState {
    return { ...this.state };
  }

  /**
   * Handle incoming message from watch
   */
  private handleWatchMessage(message: unknown): void {
    const msg = message as Record<string, unknown>;
    const type = msg.type as string;

    switch (type) {
      case "action_response":
        this.handleActionResponse(
          msg.action_id as string,
          msg.approved as boolean
        );
        break;

      case "toggle_yolo":
        this.state.yolo_mode = msg.enabled as boolean;
        // Auto-approve all pending if YOLO enabled
        if (this.state.yolo_mode) {
          for (const action of this.state.pending_actions) {
            this.handleActionResponse(action.id, true);
          }
        }
        break;

      case "approve_all":
        for (const action of this.state.pending_actions) {
          this.handleActionResponse(action.id, true);
        }
        break;
    }
  }

  /**
   * Handle action response from watch
   */
  private handleActionResponse(actionId: string, approved: boolean): void {
    const resolver = this.actionResolvers.get(actionId);
    if (resolver) {
      clearTimeout(resolver.timeout);
      resolver.resolve(
        approved ? ActionStatusEnum.APPROVED : ActionStatusEnum.REJECTED
      );
      this.actionResolvers.delete(actionId);

      // Update action status
      const action = this.state.pending_actions.find((a) => a.id === actionId);
      if (action) {
        action.status = approved
          ? ActionStatusEnum.APPROVED
          : ActionStatusEnum.REJECTED;
      }
    }
  }

  /**
   * Request approval from watch
   */
  async requestApproval(params: {
    type: ActionType;
    title: string;
    description: string;
    file_path?: string;
    command?: string;
    timeout?: number;
  }): Promise<{ approved: boolean; status: ActionStatus }> {
    // Check YOLO mode
    if (this.state.yolo_mode) {
      return { approved: true, status: ActionStatusEnum.APPROVED };
    }

    const action = createPendingAction({
      type: params.type,
      title: params.title,
      description: params.description,
      file_path: params.file_path,
      command: params.command,
    });

    // Add to pending actions
    this.state.pending_actions.push(action);
    this.state.status = SessionStatus.WAITING;

    // Broadcast to watch
    await this.cloudClient.sendMessage({
      type: "action_requested",
      action,
    });

    // Wait for response
    const timeoutMs = params.timeout || 300000; // 5 minutes default
    const status = await new Promise<ActionStatus>((resolve) => {
      const timeout = setTimeout(() => {
        this.actionResolvers.delete(action.id);
        resolve(ActionStatusEnum.TIMEOUT);
      }, timeoutMs);

      this.actionResolvers.set(action.id, { resolve, timeout });
    });

    // Cleanup
    this.state.pending_actions = this.state.pending_actions.filter(
      (a) => a.id !== action.id
    );
    if (this.state.pending_actions.length === 0) {
      this.state.status = SessionStatus.RUNNING;
    }

    return {
      approved: status === ActionStatusEnum.APPROVED,
      status,
    };
  }

  /**
   * Send notification to watch
   */
  async notify(title: string, message: string): Promise<boolean> {
    return this.cloudClient.sendMessage({
      type: "notification",
      title,
      message,
    });
  }

  /**
   * Update progress
   */
  async updateProgress(progress: number, taskName?: string): Promise<boolean> {
    this.state.progress = Math.max(0, Math.min(1, progress));
    if (taskName) {
      this.state.task_name = taskName;
    }

    return this.cloudClient.sendMessage({
      type: "progress_update",
      progress: this.state.progress,
      task_name: this.state.task_name,
    });
  }

  /**
   * Set current task
   */
  async setTask(name: string, description: string = ""): Promise<boolean> {
    this.state.task_name = name;
    this.state.task_description = description;
    this.state.progress = 0;
    this.state.status = SessionStatus.RUNNING;
    this.state.started_at = new Date().toISOString();

    return this.cloudClient.sendMessage({
      type: "task_started",
      task_name: name,
      task_description: description,
    });
  }

  /**
   * Complete current task
   */
  async completeTask(success: boolean = true): Promise<boolean> {
    this.state.status = success ? SessionStatus.COMPLETED : SessionStatus.FAILED;
    this.state.progress = success ? 1 : this.state.progress;

    return this.cloudClient.sendMessage({
      type: "task_completed",
      success,
      task_name: this.state.task_name,
    });
  }

  /**
   * Sync state to watch
   */
  async syncState(): Promise<boolean> {
    return this.cloudClient.syncState(this.state);
  }

  /**
   * Stop the state manager
   */
  stop(): void {
    this.cloudClient.stopPolling();
    // Clear all pending resolvers
    for (const [id, resolver] of this.actionResolvers) {
      clearTimeout(resolver.timeout);
      resolver.resolve(ActionStatusEnum.TIMEOUT);
    }
    this.actionResolvers.clear();
  }
}

// Singleton instance
let stateManager: SessionStateManager | null = null;

export function getStateManager(): SessionStateManager {
  if (!stateManager) {
    stateManager = new SessionStateManager();
  }
  return stateManager;
}

export function resetStateManager(): void {
  if (stateManager) {
    stateManager.stop();
    stateManager = null;
  }
}
