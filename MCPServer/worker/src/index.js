/**
 * Claude Watch - Cloudflare Worker
 *
 * Relay between Claude Code and Apple Watch for approval requests.
 * Uses HTTP + APNs for simplicity.
 */

/**
 * Generates a random 6-character pairing code for device registration.
 * Uses alphanumeric characters excluding confusing pairs (0/O, 1/I).
 *
 * @returns {string} A pairing code in format XXX-XXX (e.g., "A2B-C3D")
 */
function generatePairingCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No confusing chars (0/O, 1/I)
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return code.slice(0, 3) + '-' + code.slice(3);
}

/**
 * Generates a unique 8-character identifier for approval requests.
 * Uses the first 8 characters of a UUID v4.
 *
 * @returns {string} An 8-character hexadecimal request ID (e.g., "a3b4c5d6")
 */
function generateRequestId() {
  return crypto.randomUUID().slice(0, 8);
}

/**
 * Sends an APNs (Apple Push Notification service) push notification to a device.
 * Authenticates using JWT with ES256, handles both sandbox and production environments,
 * and provides detailed error handling for token validation and rate limiting.
 *
 * @param {object} env - Cloudflare Worker environment bindings containing APNs configuration:
 *   - APNS_KEY_ID: APNs authentication key identifier
 *   - APNS_TEAM_ID: Apple Developer Team ID
 *   - APNS_PRIVATE_KEY: Base64-encoded PKCS8 ECDSA P-256 private key
 *   - APNS_SANDBOX: 'true' for sandbox environment, otherwise uses production
 *   - APNS_BUNDLE_ID: App bundle identifier (e.g., "com.example.app")
 * @param {string} deviceToken - Hexadecimal device token from APNs registration (64 characters)
 * @param {object} payload - APNs notification payload with structure:
 *   - aps: { alert, sound, badge, category, etc. }
 *   - Custom data fields (requestId, type, title, description, filePath, command, etc.)
 * @returns {Promise<object>} Result object with one of these structures:
 *   - Success: { success: true }
 *   - APNs not configured: { success: false, error: 'APNs not configured' }
 *   - Invalid token: { success: false, error: 'BadDeviceToken'|'Unregistered', shouldClearToken: true }
 *   - Rate limited: { success: false, error: 'TooManyRequests', retryAfter: string }
 *   - Other APNs error: { success: false, error: string, status: number }
 *   - Network/crypto error: { success: false, error: string }
 */
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

    // Send to APNs (sandbox for dev builds, production for App Store)
    const apnsHost = env.APNS_SANDBOX === 'true'
      ? 'api.sandbox.push.apple.com'
      : 'api.push.apple.com';
    const response = await fetch(
      `https://${apnsHost}/3/device/${deviceToken}`,
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

/**
 * Converts a PEM-formatted private key to an ArrayBuffer for cryptographic operations.
 * Strips PEM headers/footers and decodes the base64 content into binary data.
 *
 * @param {string} pem - The PEM-formatted private key string
 * @returns {ArrayBuffer} Binary representation of the key suitable for crypto.subtle.importKey
 */
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

/**
 * Creates a signed JWT token for APNs authentication using ES256 algorithm.
 * Encodes header and claims as base64url, signs with ECDSA-SHA256, and returns the complete token.
 *
 * @param {object} header - JWT header containing algorithm (alg) and key ID (kid)
 * @param {object} claims - JWT claims containing issuer (iss) and issued-at timestamp (iat)
 * @param {CryptoKey} privateKey - The imported ECDSA P-256 private key for signing
 * @returns {Promise<string>} The signed JWT token in format: header.payload.signature
 */
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

/**
 * Creates a standardized JSON response with CORS headers.
 * Serializes the provided data to JSON and sets appropriate content-type headers.
 *
 * @param {*} data - The data to serialize as JSON (can be any type)
 * @param {number} [status=200] - HTTP status code (default: 200)
 * @returns {Response} A Response object with JSON content-type and CORS headers
 */
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders }
  });
}

/**
 * Main Cloudflare Worker fetch handler for Claude Watch API.
 * Handles device pairing, approval requests, and responses between Claude Code and Apple Watch.
 *
 * @param {Request} request - Incoming HTTP request object
 * @param {object} env - Cloudflare Worker environment bindings:
 *   - PAIRINGS: KV namespace for device pairing data
 *   - REQUESTS: KV namespace for approval request data
 *   - APNS_KEY_ID: APNs authentication key identifier
 *   - APNS_TEAM_ID: Apple Developer Team ID
 *   - APNS_PRIVATE_KEY: Base64-encoded PKCS8 ECDSA P-256 private key
 *   - APNS_SANDBOX: 'true' for sandbox environment, otherwise uses production
 *   - APNS_BUNDLE_ID: App bundle identifier (e.g., "com.example.claudewatch")
 * @param {object} ctx - Cloudflare Worker execution context for waitUntil and passThroughOnException
 * @returns {Promise<Response>} JSON response with CORS headers
 *
 * @apiEndpoints
 *
 * POST /pair
 *   Description: Generate a pairing code for Claude Code to display
 *   Request: No body required
 *   Response: {
 *     code: string,          // 6-character pairing code (e.g., "A2B-C3D")
 *     pairingId: string,     // UUID for this pairing session
 *     expiresIn: number      // Expiration time in seconds (600)
 *   }
 *
 * POST /pair/complete
 *   Description: Complete pairing by submitting code and device token from Watch
 *   Request: {
 *     code: string,          // Pairing code entered on Watch
 *     deviceToken: string    // APNs device token (64-character hex)
 *   }
 *   Response: {
 *     success: boolean,
 *     pairingId: string      // UUID for the completed pairing
 *   }
 *   Errors: 400 (missing fields), 404 (invalid/expired code)
 *
 * GET /pair/:pairingId/status
 *   Description: Check if a pairing has been completed (for polling from Claude Code)
 *   Request: No body required
 *   Response: {
 *     status: string,        // "pending" or "active"
 *     completedAt?: number   // Unix timestamp (ms) when pairing completed
 *   }
 *
 * POST /request
 *   Description: Submit an approval request from Claude Code
 *   Request: {
 *     pairingId: string,     // UUID from pairing
 *     type: string,          // Request type (e.g., "file_edit", "command_run")
 *     title: string,         // Short description
 *     description?: string,  // Detailed explanation
 *     filePath?: string,     // File path for file operations
 *     command?: string       // Command string for command operations
 *   }
 *   Response: {
 *     requestId: string,     // 8-character unique request ID
 *     apnsSent: boolean      // Whether push notification was sent successfully
 *   }
 *   Errors: 400 (missing fields, pairing not active), 404 (invalid pairing)
 *
 * GET /request/:id
 *   Description: Poll for approval response from Watch
 *   Request: No body required
 *   Response: {
 *     id: string,            // Request ID
 *     status: string,        // "pending", "approved", or "rejected"
 *     response: boolean|null,// true (approved), false (rejected), or null (pending)
 *     respondedAt: number|null // Unix timestamp (ms) when response was submitted
 *   }
 *   Errors: 404 (request not found or expired)
 *
 * GET /requests/:pairingId
 *   Description: List all pending requests for a pairing (for Watch polling)
 *   Request: No body required
 *   Response: {
 *     requests: Array<{
 *       id: string,
 *       pairingId: string,
 *       type: string,
 *       title: string,
 *       description: string,
 *       filePath: string|null,
 *       command: string|null,
 *       status: string,
 *       createdAt: number
 *     }>
 *   }
 *   Errors: 404 (invalid pairing)
 *
 * POST /respond/:id
 *   Description: Submit approval response from Watch
 *   Request: {
 *     approved: boolean,     // true for approve, false for reject
 *     pairingId: string      // UUID for authorization
 *   }
 *   Response: {
 *     success: boolean,
 *     status: string         // "approved" or "rejected"
 *   }
 *   Errors: 400 (missing fields), 403 (unauthorized), 404 (request not found)
 *
 * GET /health
 *   Description: Health check endpoint
 *   Request: No body required
 *   Response: {
 *     status: string,        // "ok"
 *     timestamp: number      // Current Unix timestamp (ms)
 *   }
 */
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

        // Normalize code to uppercase for lookup
        const normalizedCode = code.toUpperCase().trim();

        // Look up the pairing by code
        const pairingData = await env.PAIRINGS.get(`code:${normalizedCode}`);
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
