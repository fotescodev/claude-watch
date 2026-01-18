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

// Complete pairing (from watch)
app.post('/pair/complete', async (c) => {
  const { code, deviceToken } = await c.req.json<{ code: string; deviceToken: string }>();

  // Find pairing session by code
  const session = await c.env.PAIRING_KV.get<PairingSession>(`code:${code}`, 'json');

  if (!session) {
    return c.json({ error: 'Invalid or expired code' }, 404);
  }

  // Generate pairing ID
  const pairingId = crypto.randomUUID();

  // Update session as paired
  session.paired = true;
  session.pairingId = pairingId;
  await c.env.PAIRING_KV.put(`code:${code}`, JSON.stringify(session), { expirationTtl: 60 });
  await c.env.PAIRING_KV.put(`session:${session.sessionId}`, JSON.stringify(session), { expirationTtl: 60 });

  // Store connection
  const connection: Connection = {
    pairingId,
    deviceToken,
    createdAt: new Date().toISOString(),
    lastSeen: new Date().toISOString(),
  };
  await c.env.CONNECTIONS_KV.put(`pairing:${pairingId}`, JSON.stringify(connection), { expirationTtl: 86400 }); // 24 hours

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
  const existing = await c.env.MESSAGES_KV.get<MessageQueue>(`to_server:${pairingId}`, 'json') || { messages: [] };

  existing.messages.push({
    id: crypto.randomUUID(),
    type: 'action_response',
    payload: { action_id: requestId, approved },
    timestamp: new Date().toISOString(),
  });

  await c.env.MESSAGES_KV.put(`to_server:${pairingId}`, JSON.stringify(existing), { expirationTtl: 300 });

  return c.json({ success: true });
});

// Fetch pending requests (for watch polling)
app.get('/requests/:pairingId', async (c) => {
  const pairingId = c.req.param('pairingId');

  const data = await c.env.MESSAGES_KV.get<MessageQueue>(`to_watch:${pairingId}`, 'json') || { messages: [] };

  // Filter for action_requested messages only
  const requests = data.messages.filter(m => m.type === 'action_requested');

  return c.json({ requests });
});

export default app;
