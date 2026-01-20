import { z } from "zod";

// =============================================================================
// Enums (matching Python server.py)
// =============================================================================

export const ActionType = {
  FILE_EDIT: "file_edit",
  FILE_CREATE: "file_create",
  FILE_DELETE: "file_delete",
  BASH: "bash",
  TOOL_USE: "tool_use",
  APPROVAL: "approval",
} as const;
export type ActionType = (typeof ActionType)[keyof typeof ActionType];

export const ActionStatus = {
  PENDING: "pending",
  APPROVED: "approved",
  REJECTED: "rejected",
  TIMEOUT: "timeout",
} as const;
export type ActionStatus = (typeof ActionStatus)[keyof typeof ActionStatus];

export const SessionStatus = {
  IDLE: "idle",
  RUNNING: "running",
  WAITING: "waiting",
  COMPLETED: "completed",
  FAILED: "failed",
} as const;
export type SessionStatus = (typeof SessionStatus)[keyof typeof SessionStatus];

// =============================================================================
// Schemas
// =============================================================================

export const PendingActionSchema = z.object({
  id: z.string(),
  type: z.enum([
    ActionType.FILE_EDIT,
    ActionType.FILE_CREATE,
    ActionType.FILE_DELETE,
    ActionType.BASH,
    ActionType.TOOL_USE,
    ActionType.APPROVAL,
  ]),
  title: z.string(),
  description: z.string(),
  file_path: z.string().nullable().optional(),
  command: z.string().nullable().optional(),
  timestamp: z.string(),
  status: z.enum([
    ActionStatus.PENDING,
    ActionStatus.APPROVED,
    ActionStatus.REJECTED,
    ActionStatus.TIMEOUT,
  ]),
});

export const SessionStateSchema = z.object({
  task_name: z.string(),
  task_description: z.string(),
  progress: z.number().min(0).max(1),
  status: z.enum([
    SessionStatus.IDLE,
    SessionStatus.RUNNING,
    SessionStatus.WAITING,
    SessionStatus.COMPLETED,
    SessionStatus.FAILED,
  ]),
  pending_actions: z.array(PendingActionSchema),
  model: z.string(),
  yolo_mode: z.boolean(),
  started_at: z.string().nullable(),
});

// =============================================================================
// Types
// =============================================================================

export type PendingAction = z.infer<typeof PendingActionSchema>;
export type SessionState = z.infer<typeof SessionStateSchema>;

// =============================================================================
// Config Types
// =============================================================================

export interface PairingConfig {
  pairingId: string;
  cloudUrl: string;
  createdAt: string;
  watchId?: string;
  // E2E Encryption keys (COMP3)
  encryption?: {
    publicKey: string; // Our public key (base64)
    secretKey: string; // Our secret key (base64) - stored securely
    watchPublicKey?: string; // Watch's public key (base64) - received during pairing
  };
}

export interface MCPServerConfig {
  command: string;
  args?: string[];
  env?: Record<string, string>;
}

export interface MCPConfig {
  mcpServers: Record<string, MCPServerConfig>;
}

// =============================================================================
// Cloud API Types
// =============================================================================

export interface CloudMessage {
  type: string;
  pairingId: string;
  payload: unknown;
  timestamp: string;
}

export interface PairingRequest {
  pairingCode: string;
  deviceInfo?: {
    model?: string;
    os?: string;
  };
}

export interface PairingResponse {
  success: boolean;
  pairingId?: string;
  error?: string;
}

// =============================================================================
// WebSocket Message Types
// =============================================================================

export type WatchMessage =
  | { type: "state_sync"; state: SessionState }
  | { type: "action_requested"; action: PendingAction }
  | { type: "progress_update"; progress: number; task_name: string }
  | { type: "task_started"; task_name: string; task_description: string }
  | { type: "task_completed"; success: boolean; task_name: string }
  | { type: "notification"; title: string; message: string }
  | { type: "yolo_changed"; enabled: boolean }
  | { type: "prompt_received"; text: string }
  | { type: "pong" };

export type WatchRequest =
  | { type: "action_response"; action_id: string; approved: boolean }
  | { type: "prompt"; text: string }
  | { type: "toggle_yolo"; enabled: boolean }
  | { type: "approve_all" }
  | { type: "register_push_token"; token: string }
  | { type: "ping" };

// =============================================================================
// Factory Functions
// =============================================================================

export function createDefaultSessionState(): SessionState {
  return {
    task_name: "",
    task_description: "",
    progress: 0,
    status: SessionStatus.IDLE,
    pending_actions: [],
    model: "opus",
    yolo_mode: false,
    started_at: null,
  };
}

export function createPendingAction(
  params: Omit<PendingAction, "id" | "timestamp" | "status">
): PendingAction {
  return {
    ...params,
    id: crypto.randomUUID().slice(0, 8),
    timestamp: new Date().toISOString(),
    status: ActionStatus.PENDING,
  };
}
