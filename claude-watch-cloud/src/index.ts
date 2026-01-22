import { Hono } from 'hono';
import { cors } from 'hono/cors';

// Types for KV namespaces
interface Env {
  PAIRING_KV: KVNamespace;
  CONNECTIONS_KV: KVNamespace;
  MESSAGES_KV: KVNamespace;
}

// Types for data structures
interface PairingSession {
  code: string;
  sessionId: string;
  createdAt: string;
  paired: boolean;
  pairingId: string | null;
}

// Watch-initiated pairing session (new flow)
interface WatchPairingSession {
  code: string;
  watchId: string;
  deviceToken: string;
  createdAt: string;
  paired: boolean;
  pairingId: string | null;
  // E2E encryption keys (COMP3B)
  watchPublicKey?: string;  // Watch's public key (base64)
  cliPublicKey?: string;    // CLI's public key (base64)
}

interface Connection {
  pairingId: string;
  deviceToken: string;
  createdAt: string;
  lastSeen: string;
}

interface Message {
  id: string;
  type: string;
  payload: unknown;
  timestamp: string;
}

interface MessageQueue {
  messages: Message[];
}

// Question from AskUserQuestion tool
interface QuestionRequest {
  id: string;
  pairingId: string;
  question: string;
  header: string | null;
  options: Array<{ label: string; description: string | null }>;
  multiSelect: boolean;
  createdAt: string;
  status: 'pending' | 'answered' | 'skipped';
  selectedIndices: number[] | null;
}

// Session progress from TodoWrite hook
interface SessionProgress {
  pairingId: string;
  currentTask: string | null;
  currentActivity: string | null;
  progress: number;
  completedCount: number;
  totalCount: number;
  elapsedSeconds: number;
  tasks: Array<{
    content: string;
    status: string;
    activeForm: string | null;
  }>;
  updatedAt: string;
}

const app = new Hono<{ Bindings: Env }>();

// Enable CORS for all routes
app.use('*', cors());

// Health check
app.get('/health', (c) => c.json({ status: 'ok' }));

// Register pairing code (from npm package)
app.post('/api/pairing/register', async (c) => {
  const { code, sessionId } = await c.req.json<{ code: string; sessionId: string }>();

  const session: PairingSession = {
    code,
    sessionId,
    createdAt: new Date().toISOString(),
    paired: false,
    pairingId: null,
  };

  // Store by both code and sessionId for lookup
  await c.env.PAIRING_KV.put(`code:${code}`, JSON.stringify(session), { expirationTtl: 300 }); // 5 minutes
  await c.env.PAIRING_KV.put(`session:${sessionId}`, JSON.stringify(session), { expirationTtl: 300 });

  return c.json({ success: true });
});

// Check if pairing completed (polled by npm package)
app.get('/api/pairing/check', async (c) => {
  const sessionId = c.req.query('sessionId');

  if (!sessionId) {
    return c.json({ error: 'sessionId required' }, 400);
  }

  const session = await c.env.PAIRING_KV.get<PairingSession>(`session:${sessionId}`, 'json');

  if (!session) {
    return c.json({ paired: false });
  }

  return c.json({
    paired: session.paired,
    pairingId: session.pairingId,
  });
});

// Cleanup expired session (from npm package)
app.post('/api/pairing/cleanup', async (c) => {
  const { sessionId } = await c.req.json<{ sessionId: string }>();

  if (sessionId) {
    const session = await c.env.PAIRING_KV.get<PairingSession>(`session:${sessionId}`, 'json');
    if (session) {
      await c.env.PAIRING_KV.delete(`code:${session.code}`);
      await c.env.PAIRING_KV.delete(`session:${sessionId}`);
    }
  }

  return c.json({ success: true });
});

// ============================================
// NEW FLOW: Watch-initiated pairing endpoints
// ============================================

// Generate 6-digit numeric code
function generateCode(): string {
  const chars = '0123456789';
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

// Watch initiates pairing - requests a code to display
app.post('/pair/initiate', async (c) => {
  const { deviceToken, publicKey } = await c.req.json<{ deviceToken?: string; publicKey?: string }>();

  // Generate unique code and watchId
  const code = generateCode();
  const watchId = crypto.randomUUID();

  const session: WatchPairingSession = {
    code,
    watchId,
    deviceToken: deviceToken || 'unknown',
    createdAt: new Date().toISOString(),
    paired: false,
    pairingId: null,
    // E2E encryption: store watch's public key
    watchPublicKey: publicKey,
  };

  // Store by both code and watchId for lookup (5 min TTL)
  await c.env.PAIRING_KV.put(`watch_code:${code}`, JSON.stringify(session), { expirationTtl: 300 });
  await c.env.PAIRING_KV.put(`watch:${watchId}`, JSON.stringify(session), { expirationTtl: 300 });

  return c.json({ code, watchId });
});

// Watch polls for pairing completion
app.get('/pair/status/:watchId', async (c) => {
  const watchId = c.req.param('watchId');

  const session = await c.env.PAIRING_KV.get<WatchPairingSession>(`watch:${watchId}`, 'json');

  if (!session) {
    return c.json({ error: 'Session expired or not found' }, 404);
  }

  return c.json({
    paired: session.paired,
    pairingId: session.pairingId,
    // E2E encryption: return CLI's public key for watch to use
    cliPublicKey: session.cliPublicKey,
  });
});

// CLI completes pairing by entering the code shown on watch
app.post('/pair/complete', async (c) => {
  const body = await c.req.json<{ code: string; deviceToken?: string; publicKey?: string }>();
  const { code, deviceToken, publicKey } = body;

  // First try new watch-initiated flow
  let watchSession = await c.env.PAIRING_KV.get<WatchPairingSession>(`watch_code:${code}`, 'json');

  if (watchSession) {
    // New flow: CLI completing watch-initiated pairing
    const pairingId = crypto.randomUUID();

    // Update session as paired
    watchSession.paired = true;
    watchSession.pairingId = pairingId;
    // E2E encryption: store CLI's public key
    watchSession.cliPublicKey = publicKey;
    await c.env.PAIRING_KV.put(`watch_code:${code}`, JSON.stringify(watchSession), { expirationTtl: 60 });
    await c.env.PAIRING_KV.put(`watch:${watchSession.watchId}`, JSON.stringify(watchSession), { expirationTtl: 60 });

    // Store connection with encryption keys
    const connection: Connection = {
      pairingId,
      deviceToken: watchSession.deviceToken,
      createdAt: new Date().toISOString(),
      lastSeen: new Date().toISOString(),
    };
    await c.env.CONNECTIONS_KV.put(`pairing:${pairingId}`, JSON.stringify(connection), { expirationTtl: 86400 });

    // E2E encryption: return watch's public key to CLI
    return c.json({
      pairingId,
      watchPublicKey: watchSession.watchPublicKey,
    });
  }

  // Fallback: Try legacy CLI-initiated flow (for backwards compatibility)
  const session = await c.env.PAIRING_KV.get<PairingSession>(`code:${code}`, 'json');

  if (!session) {
    return c.json({ error: 'Invalid or expired code' }, 404);
  }

  // Legacy flow: Watch completing CLI-initiated pairing
  const pairingId = crypto.randomUUID();

  session.paired = true;
  session.pairingId = pairingId;
  await c.env.PAIRING_KV.put(`code:${code}`, JSON.stringify(session), { expirationTtl: 60 });
  await c.env.PAIRING_KV.put(`session:${session.sessionId}`, JSON.stringify(session), { expirationTtl: 60 });

  // Store connection
  const connection: Connection = {
    pairingId,
    deviceToken: deviceToken || 'unknown',
    createdAt: new Date().toISOString(),
    lastSeen: new Date().toISOString(),
  };
  await c.env.CONNECTIONS_KV.put(`pairing:${pairingId}`, JSON.stringify(connection), { expirationTtl: 86400 });

  return c.json({ pairingId });
});

// Send message (from npm MCP server to watch)
app.post('/api/message', async (c) => {
  const { pairingId, type, payload } = await c.req.json<{ pairingId: string; type: string; payload: unknown }>();

  // Get existing messages
  const existing = await c.env.MESSAGES_KV.get<MessageQueue>(`to_watch:${pairingId}`, 'json') || { messages: [] };

  existing.messages.push({
    id: crypto.randomUUID(),
    type,
    payload,
    timestamp: new Date().toISOString(),
  });

  // Keep last 50 messages
  if (existing.messages.length > 50) {
    existing.messages = existing.messages.slice(-50);
  }

  await c.env.MESSAGES_KV.put(`to_watch:${pairingId}`, JSON.stringify(existing), { expirationTtl: 300 });

  return c.json({ success: true });
});

// Poll messages (from watch or server)
app.get('/api/messages', async (c) => {
  const pairingId = c.req.query('pairingId');
  const direction = c.req.query('direction') || 'to_watch';

  if (!pairingId) {
    return c.json({ error: 'pairingId required' }, 400);
  }

  const key = `${direction}:${pairingId}`;
  const data = await c.env.MESSAGES_KV.get<MessageQueue>(key, 'json') || { messages: [] };

  // Clear messages after reading
  await c.env.MESSAGES_KV.delete(key);

  return c.json(data);
});

// Respond to approval (from watch)
app.post('/respond/:requestId', async (c) => {
  const requestId = c.req.param('requestId');
  const { approved, pairingId } = await c.req.json<{ approved: boolean; pairingId: string }>();

  // Store response for MCP server to poll
  // Include 'type' in payload since MCP server looks for it there
  const existing = await c.env.MESSAGES_KV.get<MessageQueue>(`to_server:${pairingId}`, 'json') || { messages: [] };

  existing.messages.push({
    id: crypto.randomUUID(),
    type: 'action_response',
    payload: { type: 'action_response', action_id: requestId, approved },
    timestamp: new Date().toISOString(),
  });

  await c.env.MESSAGES_KV.put(`to_server:${pairingId}`, JSON.stringify(existing), { expirationTtl: 300 });

  return c.json({ success: true });
});

// Approval request stored in queue
interface ApprovalRequest {
  id: string;
  type: string;
  title: string;
  description?: string;
  filePath?: string;
  command?: string;
  createdAt: string;
  status: 'pending' | 'approved' | 'rejected';
}

// Approval queue for a pairing
interface ApprovalQueue {
  requests: ApprovalRequest[];
}

// Add approval request to queue (from hook)
app.post('/approval', async (c) => {
  const body = await c.req.json<{
    pairingId: string;
    id: string;
    type: string;
    title: string;
    description?: string;
    filePath?: string;
    command?: string;
  }>();

  const request: ApprovalRequest = {
    id: body.id,
    type: body.type,
    title: body.title,
    description: body.description,
    filePath: body.filePath,
    command: body.command,
    createdAt: new Date().toISOString(),
    status: 'pending',
  };

  // Get existing queue or create new
  const queue = await c.env.MESSAGES_KV.get<ApprovalQueue>(`approval_queue:${body.pairingId}`, 'json') || { requests: [] };

  // Check for duplicate
  if (!queue.requests.find(r => r.id === body.id)) {
    queue.requests.push(request);
    // Keep last 50 requests
    if (queue.requests.length > 50) {
      queue.requests = queue.requests.slice(-50);
    }
    await c.env.MESSAGES_KV.put(`approval_queue:${body.pairingId}`, JSON.stringify(queue), { expirationTtl: 300 });
  }

  return c.json({ success: true, requestId: body.id });
});

// Fetch approval queue (for watch polling) - does NOT clear, returns all pending
app.get('/approval-queue/:pairingId', async (c) => {
  const pairingId = c.req.param('pairingId');

  const queue = await c.env.MESSAGES_KV.get<ApprovalQueue>(`approval_queue:${pairingId}`, 'json') || { requests: [] };

  // Return only pending requests
  const pending = queue.requests.filter(r => r.status === 'pending');

  return c.json({ requests: pending, totalCount: queue.requests.length });
});

// Update approval status (from watch or respond endpoint)
app.post('/approval/:requestId', async (c) => {
  const requestId = c.req.param('requestId');
  const { pairingId, approved } = await c.req.json<{ pairingId: string; approved: boolean }>();

  const queue = await c.env.MESSAGES_KV.get<ApprovalQueue>(`approval_queue:${pairingId}`, 'json');
  if (!queue) {
    return c.json({ error: 'Queue not found' }, 404);
  }

  // Update request status
  const request = queue.requests.find(r => r.id === requestId);
  if (request) {
    request.status = approved ? 'approved' : 'rejected';
    await c.env.MESSAGES_KV.put(`approval_queue:${pairingId}`, JSON.stringify(queue), { expirationTtl: 300 });
  }

  // Also store response for hook to poll
  const existing = await c.env.MESSAGES_KV.get<MessageQueue>(`to_server:${pairingId}`, 'json') || { messages: [] };
  existing.messages.push({
    id: crypto.randomUUID(),
    type: 'action_response',
    payload: { type: 'action_response', action_id: requestId, approved },
    timestamp: new Date().toISOString(),
  });
  await c.env.MESSAGES_KV.put(`to_server:${pairingId}`, JSON.stringify(existing), { expirationTtl: 300 });

  return c.json({ success: true });
});

// Get individual request status (for hook polling)
app.get('/approval/:pairingId/:requestId', async (c) => {
  const pairingId = c.req.param('pairingId');
  const requestId = c.req.param('requestId');

  const queue = await c.env.MESSAGES_KV.get<ApprovalQueue>(`approval_queue:${pairingId}`, 'json');
  if (!queue) {
    return c.json({ error: 'Queue not found', status: 'not_found' }, 404);
  }

  const request = queue.requests.find(r => r.id === requestId);
  if (!request) {
    return c.json({ error: 'Request not found', status: 'not_found' }, 404);
  }

  return c.json({
    id: request.id,
    status: request.status,
    type: request.type,
    title: request.title,
  });
});

// Clear approval queue (when session ends or watch disconnects)
app.delete('/approval-queue/:pairingId', async (c) => {
  const pairingId = c.req.param('pairingId');
  await c.env.MESSAGES_KV.delete(`approval_queue:${pairingId}`);
  return c.json({ success: true });
});

// Legacy: Fetch pending requests (for backwards compatibility)
app.get('/requests/:pairingId', async (c) => {
  const pairingId = c.req.param('pairingId');

  // Try new approval queue first
  const queue = await c.env.MESSAGES_KV.get<ApprovalQueue>(`approval_queue:${pairingId}`, 'json');
  if (queue) {
    const pending = queue.requests.filter(r => r.status === 'pending');
    return c.json({ requests: pending.map(r => ({
      id: r.id,
      type: r.type,
      title: r.title,
      description: r.description,
      filePath: r.filePath,
      command: r.command,
      timestamp: r.createdAt,
    }))});
  }

  // Fallback to old message queue
  const data = await c.env.MESSAGES_KV.get<MessageQueue>(`to_watch:${pairingId}`, 'json') || { messages: [] };
  const requests = data.messages.filter(m => m.type === 'action_requested');

  if (requests.length > 0) {
    await c.env.MESSAGES_KV.delete(`to_watch:${pairingId}`);
  }

  return c.json({ requests });
});

// ============================================
// Question endpoints for AskUserQuestion flow
// ============================================

// Create question request (from hook)
app.post('/question', async (c) => {
  const body = await c.req.json<{
    pairingId: string;
    question: string;
    header: string | null;
    options: Array<{ label: string; description: string | null }>;
    multiSelect: boolean;
  }>();

  const questionId = crypto.randomUUID();

  const questionRequest: QuestionRequest = {
    id: questionId,
    pairingId: body.pairingId,
    question: body.question,
    header: body.header,
    options: body.options,
    multiSelect: body.multiSelect,
    createdAt: new Date().toISOString(),
    status: 'pending',
    selectedIndices: null,
  };

  // Store question request (5 min TTL)
  await c.env.MESSAGES_KV.put(`question:${questionId}`, JSON.stringify(questionRequest), { expirationTtl: 300 });

  // Also add to watch's pending questions list
  const existing = await c.env.MESSAGES_KV.get<MessageQueue>(`questions:${body.pairingId}`, 'json') || { messages: [] };
  existing.messages.push({
    id: questionId,
    type: 'question_asked',
    payload: questionRequest,
    timestamp: new Date().toISOString(),
  });

  await c.env.MESSAGES_KV.put(`questions:${body.pairingId}`, JSON.stringify(existing), { expirationTtl: 300 });

  return c.json({ questionId });
});

// Poll for question answer (from hook)
app.get('/question/:questionId', async (c) => {
  const questionId = c.req.param('questionId');

  const question = await c.env.MESSAGES_KV.get<QuestionRequest>(`question:${questionId}`, 'json');

  if (!question) {
    return c.json({ error: 'Question not found or expired' }, 404);
  }

  return c.json({
    status: question.status,
    selectedIndices: question.selectedIndices,
  });
});

// Submit answer (from watch)
app.post('/question/:questionId/answer', async (c) => {
  const questionId = c.req.param('questionId');
  const { selectedIndices, skipped } = await c.req.json<{
    selectedIndices?: number[];
    skipped?: boolean;
  }>();

  const question = await c.env.MESSAGES_KV.get<QuestionRequest>(`question:${questionId}`, 'json');

  if (!question) {
    return c.json({ error: 'Question not found or expired' }, 404);
  }

  // Update question status
  question.status = skipped ? 'skipped' : 'answered';
  question.selectedIndices = selectedIndices || null;

  await c.env.MESSAGES_KV.put(`question:${questionId}`, JSON.stringify(question), { expirationTtl: 60 });

  // Clear from pending questions list
  const existing = await c.env.MESSAGES_KV.get<MessageQueue>(`questions:${question.pairingId}`, 'json') || { messages: [] };
  existing.messages = existing.messages.filter(m => m.id !== questionId);
  await c.env.MESSAGES_KV.put(`questions:${question.pairingId}`, JSON.stringify(existing), { expirationTtl: 300 });

  return c.json({ success: true });
});

// Fetch pending questions (for watch polling)
app.get('/questions/:pairingId', async (c) => {
  const pairingId = c.req.param('pairingId');

  const data = await c.env.MESSAGES_KV.get<MessageQueue>(`questions:${pairingId}`, 'json') || { messages: [] };

  return c.json({ questions: data.messages });
});

// ============================================
// Session progress endpoints for TodoWrite
// ============================================

// Update session progress (from hook)
app.post('/session-progress', async (c) => {
  const body = await c.req.json<SessionProgress>();

  // Store progress with 5 min TTL
  await c.env.MESSAGES_KV.put(
    `progress:${body.pairingId}`,
    JSON.stringify({ ...body, updatedAt: new Date().toISOString() }),
    { expirationTtl: 300 }
  );

  return c.json({ success: true });
});

// Get session progress (for watch polling)
app.get('/session-progress/:pairingId', async (c) => {
  const pairingId = c.req.param('pairingId');

  const progress = await c.env.MESSAGES_KV.get<SessionProgress>(`progress:${pairingId}`, 'json');

  if (!progress) {
    return c.json({ progress: null });
  }

  return c.json({ progress });
});

// ============================================
// Session control endpoints
// ============================================

// Session state stored in KV
interface SessionState {
  pairingId: string;
  active: boolean;
  interrupted: boolean;
  interruptAction: 'stop' | 'resume' | 'clear' | null;
  updatedAt: string;
}

// End session (from watch) - signals hook to stop waiting for approval
app.post('/session-end', async (c) => {
  const { pairingId } = await c.req.json<{ pairingId: string }>();

  if (!pairingId) {
    return c.json({ error: 'pairingId required' }, 400);
  }

  // Mark session as ended
  const sessionState: SessionState = {
    pairingId,
    active: false,
    interrupted: false,
    interruptAction: null,
    updatedAt: new Date().toISOString(),
  };
  await c.env.MESSAGES_KV.put(`session:${pairingId}`, JSON.stringify(sessionState), { expirationTtl: 300 });

  // Clear approval queue
  await c.env.MESSAGES_KV.delete(`approval_queue:${pairingId}`);

  // Clear progress
  await c.env.MESSAGES_KV.delete(`progress:${pairingId}`);

  return c.json({ success: true });
});

// Check session status (for hook polling)
app.get('/session-status/:pairingId', async (c) => {
  const pairingId = c.req.param('pairingId');

  const sessionState = await c.env.MESSAGES_KV.get<SessionState>(`session:${pairingId}`, 'json');

  // If no session state, assume active (backwards compatibility)
  if (!sessionState) {
    return c.json({ sessionActive: true });
  }

  return c.json({ sessionActive: sessionState.active });
});

// Set session interrupt state (from watch) - pause/resume Claude
app.post('/session-interrupt', async (c) => {
  const { pairingId, action } = await c.req.json<{ pairingId: string; action: 'stop' | 'resume' | 'clear' }>();

  if (!pairingId || !action) {
    return c.json({ error: 'pairingId and action required' }, 400);
  }

  // Get current state or create new
  let sessionState = await c.env.MESSAGES_KV.get<SessionState>(`session:${pairingId}`, 'json');

  if (!sessionState) {
    sessionState = {
      pairingId,
      active: true,
      interrupted: false,
      interruptAction: null,
      updatedAt: new Date().toISOString(),
    };
  }

  // Update interrupt state based on action
  if (action === 'stop') {
    sessionState.interrupted = true;
    sessionState.interruptAction = 'stop';
  } else if (action === 'resume') {
    sessionState.interrupted = false;
    sessionState.interruptAction = 'resume';
  } else if (action === 'clear') {
    sessionState.interrupted = false;
    sessionState.interruptAction = null;
  }

  sessionState.updatedAt = new Date().toISOString();
  await c.env.MESSAGES_KV.put(`session:${pairingId}`, JSON.stringify(sessionState), { expirationTtl: 300 });

  return c.json({
    success: true,
    interrupted: sessionState.interrupted,
    action: sessionState.interruptAction,
  });
});

// Check session interrupt state (for hook polling)
app.get('/session-interrupt/:pairingId', async (c) => {
  const pairingId = c.req.param('pairingId');

  const sessionState = await c.env.MESSAGES_KV.get<SessionState>(`session:${pairingId}`, 'json');

  // If no session state, assume not interrupted
  if (!sessionState) {
    return c.json({ interrupted: false, action: null });
  }

  return c.json({
    interrupted: sessionState.interrupted,
    action: sessionState.interruptAction,
  });
});

export default app;
