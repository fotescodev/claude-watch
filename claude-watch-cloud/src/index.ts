import { Hono } from 'hono';
import { cors } from 'hono/cors';

// Types for KV namespaces
interface Env {
  PAIRING_KV: KVNamespace;
  CONNECTIONS_KV: KVNamespace;
  MESSAGES_KV: KVNamespace;
}

// Types for data structures
// Watch-initiated pairing session
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

// TTL constants
const PAIRING_TTL = 300;       // 5 min — pairing codes are short-lived
const SESSION_TTL = 3600;      // 1 hour — session data must survive long tool calls
const CONNECTION_TTL = 86400;  // 24 hours — persists across sessions

const app = new Hono<{ Bindings: Env }>();

// Enable CORS for all routes
app.use('*', cors());

// Health check
app.get('/health', (c) => c.json({ status: 'ok' }));

// ============================================
// Watch-initiated pairing endpoints
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

  // Store by both code and watchId for lookup
  await c.env.PAIRING_KV.put(`watch_code:${code}`, JSON.stringify(session), { expirationTtl: PAIRING_TTL });
  await c.env.PAIRING_KV.put(`watch:${watchId}`, JSON.stringify(session), { expirationTtl: PAIRING_TTL });

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

  const watchSession = await c.env.PAIRING_KV.get<WatchPairingSession>(`watch_code:${code}`, 'json');

  if (!watchSession) {
    return c.json({ error: 'Invalid or expired code' }, 404);
  }

  const pairingId = crypto.randomUUID();

  // Update session as paired
  watchSession.paired = true;
  watchSession.pairingId = pairingId;
  // E2E encryption: store CLI's public key
  watchSession.cliPublicKey = publicKey;
  await c.env.PAIRING_KV.put(`watch_code:${code}`, JSON.stringify(watchSession), { expirationTtl: PAIRING_TTL });
  await c.env.PAIRING_KV.put(`watch:${watchSession.watchId}`, JSON.stringify(watchSession), { expirationTtl: PAIRING_TTL });

  // Store connection with encryption keys
  const connection: Connection = {
    pairingId,
    deviceToken: watchSession.deviceToken,
    createdAt: new Date().toISOString(),
    lastSeen: new Date().toISOString(),
  };
  await c.env.CONNECTIONS_KV.put(`pairing:${pairingId}`, JSON.stringify(connection), { expirationTtl: CONNECTION_TTL });

  // E2E encryption: return watch's public key to CLI
  return c.json({
    pairingId,
    watchPublicKey: watchSession.watchPublicKey,
  });
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
    await c.env.MESSAGES_KV.put(`approval_queue:${body.pairingId}`, JSON.stringify(queue), { expirationTtl: SESSION_TTL });
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
    await c.env.MESSAGES_KV.put(`approval_queue:${pairingId}`, JSON.stringify(queue), { expirationTtl: SESSION_TTL });
  }

  // Also store response for hook to poll
  const existing = await c.env.MESSAGES_KV.get<MessageQueue>(`to_server:${pairingId}`, 'json') || { messages: [] };
  existing.messages.push({
    id: crypto.randomUUID(),
    type: 'action_response',
    payload: { type: 'action_response', action_id: requestId, approved },
    timestamp: new Date().toISOString(),
  });
  await c.env.MESSAGES_KV.put(`to_server:${pairingId}`, JSON.stringify(existing), { expirationTtl: SESSION_TTL });

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

// ============================================
// Question endpoints (for multi-select/single-select questions)
// ============================================

// Question option
interface QuestionOption {
  label: string;
  description?: string;
}

// Question request stored in queue
interface QuestionRequest {
  questionId: string;
  question: string;
  header?: string;
  options: QuestionOption[];
  multiSelect: boolean;
  recommendedAnswer?: string;
  createdAt: string;
  status: 'pending' | 'answered';
  answer?: string | string[];
}

// Question queue for a pairing
interface QuestionQueue {
  questions: QuestionRequest[];
}

// Add question to queue (from hook)
app.post('/question', async (c) => {
  const body = await c.req.json<{
    pairingId: string;
    questionId: string;
    question: string;
    header?: string;
    options: QuestionOption[];
    multiSelect?: boolean;
    recommendedAnswer?: string;
  }>();

  if (!body.pairingId || !body.questionId || !body.question || !body.options) {
    return c.json({ error: 'pairingId, questionId, question, and options are required' }, 400);
  }

  const request: QuestionRequest = {
    questionId: body.questionId,
    question: body.question,
    header: body.header,
    options: body.options,
    multiSelect: body.multiSelect || false,
    recommendedAnswer: body.recommendedAnswer,
    createdAt: new Date().toISOString(),
    status: 'pending',
  };

  // Get existing queue or create new
  const queue = await c.env.MESSAGES_KV.get<QuestionQueue>(`question_queue:${body.pairingId}`, 'json') || { questions: [] };

  // Check for duplicate
  if (!queue.questions.find(q => q.questionId === body.questionId)) {
    queue.questions.push(request);
    // Keep last 50 questions
    if (queue.questions.length > 50) {
      queue.questions = queue.questions.slice(-50);
    }
    await c.env.MESSAGES_KV.put(`question_queue:${body.pairingId}`, JSON.stringify(queue), { expirationTtl: SESSION_TTL });
  }

  return c.json({ questionId: body.questionId, success: true });
});

// Fetch question queue (for watch polling) - returns all pending questions
app.get('/question-queue/:pairingId', async (c) => {
  const pairingId = c.req.param('pairingId');

  const queue = await c.env.MESSAGES_KV.get<QuestionQueue>(`question_queue:${pairingId}`, 'json') || { questions: [] };

  // Return only pending questions
  const pending = queue.questions.filter(q => q.status === 'pending');

  return c.json({ questions: pending, totalCount: queue.questions.length });
});

// Answer a question (from watch)
app.post('/question/:questionId', async (c) => {
  const questionId = c.req.param('questionId');
  const { pairingId, answer } = await c.req.json<{ pairingId: string; answer: string | string[] }>();

  const queue = await c.env.MESSAGES_KV.get<QuestionQueue>(`question_queue:${pairingId}`, 'json');
  if (!queue) {
    return c.json({ error: 'Queue not found' }, 404);
  }

  // Update question status
  const question = queue.questions.find(q => q.questionId === questionId);
  if (question) {
    question.status = 'answered';
    question.answer = answer;
    await c.env.MESSAGES_KV.put(`question_queue:${pairingId}`, JSON.stringify(queue), { expirationTtl: SESSION_TTL });
  }

  // Also store response for hook to poll
  const existing = await c.env.MESSAGES_KV.get<MessageQueue>(`to_server:${pairingId}`, 'json') || { messages: [] };
  existing.messages.push({
    id: crypto.randomUUID(),
    type: 'question_response',
    payload: { type: 'question_response', question_id: questionId, answer },
    timestamp: new Date().toISOString(),
  });
  await c.env.MESSAGES_KV.put(`to_server:${pairingId}`, JSON.stringify(existing), { expirationTtl: SESSION_TTL });

  return c.json({ success: true });
});

// Get individual question status (for hook polling)
app.get('/question/:pairingId/:questionId', async (c) => {
  const pairingId = c.req.param('pairingId');
  const questionId = c.req.param('questionId');

  const queue = await c.env.MESSAGES_KV.get<QuestionQueue>(`question_queue:${pairingId}`, 'json');
  if (!queue) {
    return c.json({ error: 'Queue not found', status: 'not_found' }, 404);
  }

  const question = queue.questions.find(q => q.questionId === questionId);
  if (!question) {
    return c.json({ error: 'Question not found', status: 'not_found' }, 404);
  }

  return c.json({
    questionId: question.questionId,
    status: question.status,
    question: question.question,
    answer: question.answer,
  });
});

// Clear question queue (when session ends)
app.delete('/question-queue/:pairingId', async (c) => {
  const pairingId = c.req.param('pairingId');
  await c.env.MESSAGES_KV.delete(`question_queue:${pairingId}`);
  return c.json({ success: true });
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
    { expirationTtl: SESSION_TTL }
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
  await c.env.MESSAGES_KV.put(`session:${pairingId}`, JSON.stringify(sessionState), { expirationTtl: SESSION_TTL });

  // Clear approval queue
  await c.env.MESSAGES_KV.delete(`approval_queue:${pairingId}`);

  // Clear question queue
  await c.env.MESSAGES_KV.delete(`question_queue:${pairingId}`);

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
  await c.env.MESSAGES_KV.put(`session:${pairingId}`, JSON.stringify(sessionState), { expirationTtl: SESSION_TTL });

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
