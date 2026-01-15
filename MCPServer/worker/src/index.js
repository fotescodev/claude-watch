/**
 * Claude Watch - Cloudflare Worker
 *
 * Relay between Claude Code and Apple Watch for approval requests.
 * Uses HTTP + APNs for simplicity.
 */

// Generate a 6-character pairing code
function generatePairingCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No confusing chars (0/O, 1/I)
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return code.slice(0, 3) + '-' + code.slice(3);
}

// Generate a unique request ID
function generateRequestId() {
  return crypto.randomUUID().slice(0, 8);
}

// Send APNs push notification
async function sendAPNs(env, deviceToken, payload) {
  if (!env.APNS_KEY_ID || !env.APNS_TEAM_ID || !env.APNS_PRIVATE_KEY) {
    console.log('APNs not configured, skipping push');
    return { success: false, error: 'APNs not configured' };
  }

  try {
    // Import the private key
    const privateKeyPem = atob(env.APNS_PRIVATE_KEY);
    const privateKey = await crypto.subtle.importKey(
      'pkcs8',
      pemToArrayBuffer(privateKeyPem),
      { name: 'ECDSA', namedCurve: 'P-256' },
      false,
      ['sign']
    );

    // Create JWT token
    const header = { alg: 'ES256', kid: env.APNS_KEY_ID };
    const claims = {
      iss: env.APNS_TEAM_ID,
      iat: Math.floor(Date.now() / 1000)
    };

    const token = await createJWT(header, claims, privateKey);

    // Send to APNs
    const response = await fetch(
      `https://api.push.apple.com/3/device/${deviceToken}`,
      {
        method: 'POST',
        headers: {
          'authorization': `bearer ${token}`,
          'apns-topic': env.APNS_BUNDLE_ID,
          'apns-push-type': 'alert',
          'apns-priority': '10'
        },
        body: JSON.stringify(payload)
      }
    );

    const responseBody = await response.text();

    if (response.ok) {
      return { success: true };
    }

    // Handle specific APNs errors
    const errorData = responseBody ? JSON.parse(responseBody) : {};
    const reason = errorData.reason || 'Unknown';

    if (reason === 'BadDeviceToken' || reason === 'Unregistered') {
      // Token is invalid - should clear from storage
      return { success: false, error: reason, shouldClearToken: true };
    }

    if (reason === 'TooManyRequests') {
      // Rate limited - caller should retry with backoff
      return { success: false, error: reason, retryAfter: response.headers.get('Retry-After') };
    }

    return { success: false, error: reason, status: response.status };
  } catch (error) {
    console.error('APNs error:', error);
    return { success: false, error: error.message };
  }
}

// Helper: Convert PEM to ArrayBuffer
function pemToArrayBuffer(pem) {
  const lines = pem.split('\n').filter(line =>
    !line.includes('-----BEGIN') && !line.includes('-----END')
  );
  const base64 = lines.join('');
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

// Helper: Create JWT
async function createJWT(header, claims, privateKey) {
  const encoder = new TextEncoder();

  const headerB64 = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const claimsB64 = btoa(JSON.stringify(claims)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  const data = encoder.encode(`${headerB64}.${claimsB64}`);
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    privateKey,
    data
  );

  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  return `${headerB64}.${claimsB64}.${signatureB64}`;
}

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

// JSON response helper
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders }
  });
}

export default {
  async fetch(request, env, ctx) {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      // POST /pair - Generate pairing code for Claude Code
      if (path === '/pair' && request.method === 'POST') {
        const code = generatePairingCode();
        const pairingId = crypto.randomUUID();

        // Store pairing with code (expires in 10 minutes)
        await env.PAIRINGS.put(`code:${code}`, JSON.stringify({
          pairingId,
          createdAt: Date.now(),
          status: 'pending'
        }), { expirationTtl: 600 });

        return jsonResponse({
          code,
          pairingId,
          expiresIn: 600
        });
      }

      // POST /pair/complete - Watch completes pairing with code and device token
      if (path === '/pair/complete' && request.method === 'POST') {
        const { code, deviceToken } = await request.json();

        if (!code || !deviceToken) {
          return jsonResponse({ error: 'Missing code or deviceToken' }, 400);
        }

        // Look up the pairing by code
        const pairingData = await env.PAIRINGS.get(`code:${code}`);
        if (!pairingData) {
          return jsonResponse({ error: 'Invalid or expired code' }, 404);
        }

        const pairing = JSON.parse(pairingData);

        // Update pairing with device token
        const completedPairing = {
          ...pairing,
          deviceToken,
          status: 'active',
          completedAt: Date.now()
        };

        // Store by pairingId (permanent)
        await env.PAIRINGS.put(`pairing:${pairing.pairingId}`, JSON.stringify(completedPairing));

        // Delete the code entry
        await env.PAIRINGS.delete(`code:${code}`);

        return jsonResponse({
          success: true,
          pairingId: pairing.pairingId
        });
      }

      // GET /pair/:pairingId/status - Check if pairing is complete
      if (path.startsWith('/pair/') && path.endsWith('/status') && request.method === 'GET') {
        const pairingId = path.split('/')[2];

        const pairingData = await env.PAIRINGS.get(`pairing:${pairingId}`);
        if (!pairingData) {
          // Check if code is still pending
          return jsonResponse({ status: 'pending' });
        }

        const pairing = JSON.parse(pairingData);
        return jsonResponse({
          status: pairing.status,
          completedAt: pairing.completedAt
        });
      }

      // POST /request - Claude Code sends approval request
      if (path === '/request' && request.method === 'POST') {
        const { pairingId, type, title, description, filePath, command } = await request.json();

        if (!pairingId || !type || !title) {
          return jsonResponse({ error: 'Missing required fields' }, 400);
        }

        // Get pairing to find device token
        const pairingData = await env.PAIRINGS.get(`pairing:${pairingId}`);
        if (!pairingData) {
          return jsonResponse({ error: 'Invalid pairing' }, 404);
        }

        const pairing = JSON.parse(pairingData);
        if (pairing.status !== 'active') {
          return jsonResponse({ error: 'Pairing not active' }, 400);
        }

        // Create request
        const requestId = generateRequestId();
        const approvalRequest = {
          id: requestId,
          pairingId,
          type,
          title,
          description: description || '',
          filePath: filePath || null,
          command: command || null,
          status: 'pending',
          createdAt: Date.now()
        };

        // Store request (expires in 10 minutes)
        await env.REQUESTS.put(`request:${requestId}`, JSON.stringify(approvalRequest), {
          expirationTtl: 600
        });

        // Also index by pairingId for polling
        const pendingKey = `pending:${pairingId}`;
        const existingPending = await env.REQUESTS.get(pendingKey);
        const pendingList = existingPending ? JSON.parse(existingPending) : [];
        pendingList.push(requestId);
        await env.REQUESTS.put(pendingKey, JSON.stringify(pendingList), {
          expirationTtl: 600
        });

        // Send push notification
        const apnsPayload = {
          aps: {
            alert: {
              title: `Claude: ${type.replace('_', ' ')}`,
              body: title,
              subtitle: description || undefined
            },
            sound: 'default',
            category: 'CLAUDE_ACTION',
            'mutable-content': 1
          },
          requestId,
          type,
          title,
          description,
          filePath,
          command
        };

        const apnsResult = await sendAPNs(env, pairing.deviceToken, apnsPayload);

        return jsonResponse({
          requestId,
          apnsSent: apnsResult.success
        });
      }

      // GET /request/:id - Poll for response
      if (path.startsWith('/request/') && request.method === 'GET') {
        const requestId = path.split('/')[2];

        const requestData = await env.REQUESTS.get(`request:${requestId}`);
        if (!requestData) {
          return jsonResponse({ error: 'Request not found or expired' }, 404);
        }

        const approvalRequest = JSON.parse(requestData);
        return jsonResponse({
          id: approvalRequest.id,
          status: approvalRequest.status,
          response: approvalRequest.response || null,
          respondedAt: approvalRequest.respondedAt || null
        });
      }

      // GET /requests/:pairingId - List pending requests for watch polling
      if (path.startsWith('/requests/') && request.method === 'GET') {
        const pairingId = path.split('/')[2];

        // Verify pairing exists
        const pairingData = await env.PAIRINGS.get(`pairing:${pairingId}`);
        if (!pairingData) {
          return jsonResponse({ error: 'Invalid pairing' }, 404);
        }

        // Get pending request IDs
        const pendingKey = `pending:${pairingId}`;
        const pendingData = await env.REQUESTS.get(pendingKey);
        const pendingIds = pendingData ? JSON.parse(pendingData) : [];

        // Fetch all pending requests
        const requests = [];
        for (const requestId of pendingIds) {
          const requestData = await env.REQUESTS.get(`request:${requestId}`);
          if (requestData) {
            const req = JSON.parse(requestData);
            if (req.status === 'pending') {
              requests.push(req);
            }
          }
        }

        return jsonResponse({ requests });
      }

      // POST /respond/:id - Watch sends response
      if (path.startsWith('/respond/') && request.method === 'POST') {
        const requestId = path.split('/')[2];
        const { approved, pairingId } = await request.json();

        if (typeof approved !== 'boolean') {
          return jsonResponse({ error: 'Missing approved field' }, 400);
        }

        // Verify pairingId is provided
        if (!pairingId) {
          return jsonResponse({ error: 'Missing pairingId' }, 400);
        }

        const requestData = await env.REQUESTS.get(`request:${requestId}`);
        if (!requestData) {
          return jsonResponse({ error: 'Request not found or expired' }, 404);
        }

        const approvalRequest = JSON.parse(requestData);

        // Verify the responder owns this request
        if (approvalRequest.pairingId !== pairingId) {
          return jsonResponse({ error: 'Unauthorized' }, 403);
        }

        // Update request with response
        approvalRequest.status = approved ? 'approved' : 'rejected';
        approvalRequest.response = approved;
        approvalRequest.respondedAt = Date.now();

        // Store updated request (keep for 1 minute for polling)
        await env.REQUESTS.put(`request:${requestId}`, JSON.stringify(approvalRequest), {
          expirationTtl: 60
        });

        return jsonResponse({
          success: true,
          status: approvalRequest.status
        });
      }

      // Health check
      if (path === '/health') {
        return jsonResponse({ status: 'ok', timestamp: Date.now() });
      }

      return jsonResponse({ error: 'Not found' }, 404);

    } catch (error) {
      console.error('Error:', error);
      return jsonResponse({ error: error.message }, 500);
    }
  }
};
