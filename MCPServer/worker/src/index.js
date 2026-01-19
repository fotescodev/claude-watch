/**
 * Claude Watch - Cloudflare Worker
 *
 * Relay between Claude Code and Apple Watch for approval requests.
 * Uses HTTP + APNs for simplicity.
 */

/**
 * Generates a random 6-character alphanumeric pairing code for device registration.
 * Uses alphanumeric characters excluding confusing pairs (0/O, 1/I).
 *
 * @returns {string} A pairing code in format XXX-XXX (e.g., "A2B-C3D")
 */
function generateAlphanumericCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No confusing chars (0/O, 1/I)
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return code.slice(0, 3) + '-' + code.slice(3);
}

/**
 * Generates a random 6-digit numeric pairing code for device registration.
 * Uses crypto.getRandomValues for secure randomness.
 * Preserves leading zeros (e.g., "012345" not "12345").
 *
 * @returns {string} A 6-digit numeric code (e.g., "123456" or "012345")
 */
function generateNumericCode() {
  const array = new Uint8Array(6);
  crypto.getRandomValues(array);
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += (array[i] % 10).toString();
  }
  return code;
}

/**
 * Rate limiting configuration for pairing attempts.
 * Numeric codes have reduced entropy (~20 bits vs ~30 bits for alphanumeric),
 * so rate limiting is required to prevent brute force attacks.
 */
const RATE_LIMIT = {
  maxAttempts: 5,        // Max attempts per pairing ID
  windowSeconds: 900     // 15 minutes
};

/**
 * Checks rate limit for a pairing attempt and increments the counter.
 * Returns whether the attempt is blocked and when to retry.
 *
 * @param {string} pairingId - The pairing ID being attempted
 * @param {object} env - Cloudflare Worker environment with KV bindings
 * @returns {Promise<{blocked: boolean, retryAfter?: number, attempts?: number}>}
 */
async function checkRateLimit(pairingId, env) {
  const key = `rate:${pairingId}`;
  const data = await env.PAIRINGS.get(key);

  if (!data) {
    // First attempt - create rate limit entry
    await env.PAIRINGS.put(key, JSON.stringify({ attempts: 1 }), {
      expirationTtl: RATE_LIMIT.windowSeconds
    });
    return { blocked: false, attempts: 1 };
  }

  const rateData = JSON.parse(data);

  if (rateData.attempts >= RATE_LIMIT.maxAttempts) {
    return {
      blocked: true,
      retryAfter: RATE_LIMIT.windowSeconds
    };
  }

  // Increment attempts
  rateData.attempts += 1;
  await env.PAIRINGS.put(key, JSON.stringify(rateData), {
    expirationTtl: RATE_LIMIT.windowSeconds
  });

  return { blocked: false, attempts: rateData.attempts };
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
 *   Query params:
 *     - format: 'numeric' for 6-digit code, omit for alphanumeric (default)
 *   Request: No body required
 *   Response: {
 *     code: string,          // Pairing code (e.g., "A2B-C3D" or "123456")
 *     pairingId: string,     // UUID for this pairing session
 *     expiresIn: number,     // Expiration time in seconds (600)
 *     format: string         // 'numeric' or 'alphanumeric'
 *   }
 *
 * POST /pair/complete
 *   Description: Complete pairing by submitting code and device token from Watch
 *   Request: {
 *     code: string,          // Pairing code entered on Watch (alphanumeric or numeric)
 *     deviceToken: string    // APNs device token (64-character hex)
 *   }
 *   Response: {
 *     success: boolean,
 *     pairingId: string      // UUID for the completed pairing
 *   }
 *   Errors: 400 (missing fields), 404 (invalid/expired code), 429 (rate limited)
 *   Rate limiting: Max 5 attempts per pairing ID per 15 minutes
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
      // POST /pair/initiate - Watch initiates pairing and gets code to display
      // NEW FLOW: Watch shows code → CLI enters code
      if (path === '/pair/initiate' && request.method === 'POST') {
        const { deviceToken } = await request.json().catch(() => ({}));

        // Generate a 6-digit numeric code for easy entry
        const code = generateNumericCode();
        const watchId = crypto.randomUUID();

        // Store watch session (expires in 10 minutes)
        await env.PAIRINGS.put(`watch:${watchId}`, JSON.stringify({
          watchId,
          code,
          deviceToken: deviceToken || null,
          createdAt: Date.now(),
          status: 'pending',
          pairingId: null
        }), { expirationTtl: 600 });

        // Also index by code for CLI lookup
        await env.PAIRINGS.put(`watchcode:${code}`, watchId, { expirationTtl: 600 });

        return jsonResponse({
          code,
          watchId,
          expiresIn: 600
        });
      }

      // GET /pair/status/:watchId - Watch polls to check if CLI completed pairing
      if (path.startsWith('/pair/status/') && request.method === 'GET') {
        const watchId = path.split('/')[3];

        const watchData = await env.PAIRINGS.get(`watch:${watchId}`);
        if (!watchData) {
          return jsonResponse({ error: 'Session expired' }, 404);
        }

        const watch = JSON.parse(watchData);

        if (watch.status === 'paired' && watch.pairingId) {
          return jsonResponse({
            status: 'paired',
            paired: true,
            pairingId: watch.pairingId
          });
        }

        return jsonResponse({
          status: 'pending',
          paired: false
        });
      }

      // POST /pair/complete-cli - CLI completes pairing by entering code from watch
      // NEW FLOW: CLI enters the code displayed on watch
      if (path === '/pair/complete-cli' && request.method === 'POST') {
        const { code } = await request.json();

        if (!code) {
          return jsonResponse({ error: 'Missing code' }, 400);
        }

        const normalizedCode = code.trim();

        // Look up watchId by code
        const watchId = await env.PAIRINGS.get(`watchcode:${normalizedCode}`);
        if (!watchId) {
          return jsonResponse({ error: 'Invalid or expired code' }, 404);
        }

        // Get watch session
        const watchData = await env.PAIRINGS.get(`watch:${watchId}`);
        if (!watchData) {
          return jsonResponse({ error: 'Session expired' }, 404);
        }

        const watch = JSON.parse(watchData);
        const pairingId = crypto.randomUUID();

        // Update watch session as paired
        watch.status = 'paired';
        watch.pairingId = pairingId;
        watch.completedAt = Date.now();
        await env.PAIRINGS.put(`watch:${watchId}`, JSON.stringify(watch), { expirationTtl: 600 });

        // Create active pairing record
        await env.PAIRINGS.put(`pairing:${pairingId}`, JSON.stringify({
          pairingId,
          deviceToken: watch.deviceToken,
          status: 'active',
          createdAt: watch.createdAt,
          completedAt: Date.now()
        }));

        // Clean up code index
        await env.PAIRINGS.delete(`watchcode:${normalizedCode}`);

        return jsonResponse({
          success: true,
          pairingId,
          watchId
        });
      }

      // POST /pair - Generate pairing code for Claude Code (LEGACY - CLI shows code)
      // Accepts optional ?format=numeric query param for 6-digit numeric codes
      if (path === '/pair' && request.method === 'POST') {
        const format = url.searchParams.get('format');
        const isNumeric = format === 'numeric';

        // Generate code based on requested format
        const code = isNumeric ? generateNumericCode() : generateAlphanumericCode();
        const pairingId = crypto.randomUUID();

        // Store pairing with code (expires in 10 minutes)
        // Include format to help with lookup normalization
        await env.PAIRINGS.put(`code:${code}`, JSON.stringify({
          pairingId,
          createdAt: Date.now(),
          status: 'pending',
          format: isNumeric ? 'numeric' : 'alphanumeric'
        }), { expirationTtl: 600 });

        return jsonResponse({
          code,
          pairingId,
          expiresIn: 600,
          format: isNumeric ? 'numeric' : 'alphanumeric'
        });
      }

      // POST /pair/complete - Complete pairing with code
      // Supports TWO flows:
      // 1. OLD: Watch sends code + deviceToken (CLI showed code, watch enters it)
      // 2. NEW: CLI sends code only (Watch showed code, CLI enters it)
      if (path === '/pair/complete' && request.method === 'POST') {
        const { code, deviceToken } = await request.json();

        if (!code) {
          return jsonResponse({ error: 'Missing code' }, 400);
        }

        const normalizedCode = code.trim();

        // NEW FLOW: Check if this is a watch-initiated pairing (CLI entering code)
        const watchId = await env.PAIRINGS.get(`watchcode:${normalizedCode}`);
        if (watchId) {
          // CLI is completing a watch-initiated pairing
          const watchData = await env.PAIRINGS.get(`watch:${watchId}`);
          if (!watchData) {
            return jsonResponse({ error: 'Session expired' }, 404);
          }

          const watch = JSON.parse(watchData);
          const pairingId = crypto.randomUUID();

          // Update watch session as paired
          watch.status = 'paired';
          watch.pairingId = pairingId;
          watch.completedAt = Date.now();
          await env.PAIRINGS.put(`watch:${watchId}`, JSON.stringify(watch), { expirationTtl: 600 });

          // Create active pairing record
          await env.PAIRINGS.put(`pairing:${pairingId}`, JSON.stringify({
            pairingId,
            deviceToken: watch.deviceToken,
            status: 'active',
            createdAt: watch.createdAt,
            completedAt: Date.now()
          }));

          // Clean up code index
          await env.PAIRINGS.delete(`watchcode:${normalizedCode}`);

          return jsonResponse({
            success: true,
            pairingId,
            watchId
          });
        }

        // OLD FLOW: Watch entering code from CLI (requires deviceToken)
        if (!deviceToken) {
          return jsonResponse({ error: 'Invalid or expired code' }, 404);
        }

        // Normalize code based on format:
        // - Numeric: trim only (preserve leading zeros like "012345")
        // - Alphanumeric: uppercase and trim (e.g., "abc-123" -> "ABC-123")
        const trimmedCode = code.trim();
        const isNumeric = /^\d{6}$/.test(trimmedCode);
        const oldFlowCode = isNumeric ? trimmedCode : trimmedCode.toUpperCase();

        // Look up the pairing by code
        const pairingData = await env.PAIRINGS.get(`code:${oldFlowCode}`);
        if (!pairingData) {
          return jsonResponse({ error: 'Invalid or expired code' }, 404);
        }

        const pairing = JSON.parse(pairingData);

        // Check rate limit for this pairing ID
        const rateCheck = await checkRateLimit(pairing.pairingId, env);
        if (rateCheck.blocked) {
          return new Response(JSON.stringify({
            error: 'Too many attempts. Please try again later.',
            retryAfter: rateCheck.retryAfter
          }), {
            status: 429,
            headers: {
              'Content-Type': 'application/json',
              'Retry-After': String(rateCheck.retryAfter),
              ...corsHeaders
            }
          });
        }

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
        await env.PAIRINGS.delete(`code:${oldFlowCode}`);

        // Clear rate limit on successful pairing
        await env.PAIRINGS.delete(`rate:${pairing.pairingId}`);

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

        // Check if session was ended from watch
        const sessionEnded = await env.PAIRINGS.get(`session-ended:${pairingId}`);
        if (sessionEnded) {
          return jsonResponse({ error: 'Session ended', sessionEnded: true }, 400);
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

        // Get pending count for badge
        const pendingCount = pendingList.length;

        // Send push notification with badge count
        // If multiple pending, show count instead of individual action
        const alertTitle = pendingCount > 1
          ? `Claude: ${pendingCount} actions pending`
          : `Claude: ${type.replace('_', ' ')}`;
        const alertBody = pendingCount > 1
          ? `Latest: ${title}`
          : title;

        const apnsPayload = {
          aps: {
            alert: {
              title: alertTitle,
              body: alertBody,
              subtitle: pendingCount === 1 ? (description || undefined) : undefined
            },
            sound: 'default',
            category: 'CLAUDE_ACTION',
            badge: pendingCount,
            'mutable-content': 1
          },
          requestId,
          type,
          title,
          description,
          filePath,
          command,
          pendingCount
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

      // POST /session-progress - Receive session progress from Claude Code hook
      if (path === '/session-progress' && request.method === 'POST') {
        const { pairingId, tasks, currentTask, currentActivity, progress, completedCount, totalCount, elapsedSeconds } = await request.json();

        if (!pairingId) {
          return jsonResponse({ error: 'Missing pairingId' }, 400);
        }

        // Get pairing to find device token
        const pairingData = await env.PAIRINGS.get(`pairing:${pairingId}`);
        if (!pairingData) {
          return jsonResponse({ error: 'Invalid pairing' }, 404);
        }

        const pairing = JSON.parse(pairingData);

        // Store progress in KV (expires in 1 hour)
        await env.PAIRINGS.put(`progress:${pairingId}`, JSON.stringify({
          tasks: tasks || [],
          currentTask: currentTask || null,
          currentActivity: currentActivity || null,
          progress: progress || 0,
          completedCount: completedCount || 0,
          totalCount: totalCount || 0,
          elapsedSeconds: elapsedSeconds || 0,
          updatedAt: Date.now()
        }), { expirationTtl: 3600 });

        // Send silent push notification to watch
        let apnsResult = { success: false };
        if (pairing.deviceToken) {
          const apnsPayload = {
            aps: {
              'content-available': 1
            },
            type: 'progress',
            tasks: tasks || [],
            currentTask: currentTask || null,
            currentActivity: currentActivity || null,
            progress: progress || 0,
            completedCount: completedCount || 0,
            totalCount: totalCount || 0,
            elapsedSeconds: elapsedSeconds || 0
          };
          apnsResult = await sendAPNs(env, pairing.deviceToken, apnsPayload);
        }

        return jsonResponse({
          success: true,
          apnsSent: apnsResult.success
        });
      }

      // GET /session-progress/:pairingId - Poll for session progress (fallback)
      if (path.startsWith('/session-progress/') && request.method === 'GET') {
        const pairingId = path.split('/')[2];

        // Verify pairing exists
        const pairingData = await env.PAIRINGS.get(`pairing:${pairingId}`);
        if (!pairingData) {
          return jsonResponse({ error: 'Invalid pairing' }, 404);
        }

        // Get stored progress
        const progressData = await env.PAIRINGS.get(`progress:${pairingId}`);
        if (!progressData) {
          return jsonResponse({
            currentTask: null,
            currentActivity: null,
            progress: 0,
            completedCount: 0,
            totalCount: 0,
            elapsedSeconds: 0,
            tasks: []
          });
        }

        return jsonResponse(JSON.parse(progressData));
      }

      // POST /session-end - Watch signals session should end
      // This allows the watch to disconnect and signal Mac to stop watch mode
      if (path === '/session-end' && request.method === 'POST') {
        const { pairingId } = await request.json();

        if (!pairingId) {
          return jsonResponse({ error: 'Missing pairingId' }, 400);
        }

        // Mark session as ended (expires in 1 hour - enough time for hooks to detect)
        await env.PAIRINGS.put(`session-ended:${pairingId}`, JSON.stringify({
          ended: true,
          endedAt: Date.now()
        }), { expirationTtl: 3600 });

        // Cancel all pending requests for this pairing
        const pendingKey = `pending:${pairingId}`;
        const pendingData = await env.REQUESTS.get(pendingKey);
        if (pendingData) {
          const pendingIds = JSON.parse(pendingData);
          for (const requestId of pendingIds) {
            const requestData = await env.REQUESTS.get(`request:${requestId}`);
            if (requestData) {
              const req = JSON.parse(requestData);
              req.status = 'session_ended';
              req.respondedAt = Date.now();
              await env.REQUESTS.put(`request:${requestId}`, JSON.stringify(req), {
                expirationTtl: 60
              });
            }
          }
          // Clear pending list
          await env.REQUESTS.delete(pendingKey);
        }

        // Clear progress data
        await env.PAIRINGS.delete(`progress:${pairingId}`);

        return jsonResponse({
          success: true,
          message: 'Session ended'
        });
      }

      // GET /session-status/:pairingId - Check if session has been ended from watch
      if (path.startsWith('/session-status/') && request.method === 'GET') {
        const pairingId = path.split('/')[2];

        const endedData = await env.PAIRINGS.get(`session-ended:${pairingId}`);
        if (endedData) {
          const ended = JSON.parse(endedData);
          return jsonResponse({
            sessionActive: false,
            endedAt: ended.endedAt
          });
        }

        return jsonResponse({
          sessionActive: true
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
