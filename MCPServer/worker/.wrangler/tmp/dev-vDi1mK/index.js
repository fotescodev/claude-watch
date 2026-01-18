var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// .wrangler/tmp/bundle-S7c6MD/checked-fetch.js
var urls = /* @__PURE__ */ new Set();
function checkURL(request, init) {
  const url = request instanceof URL ? request : new URL(
    (typeof request === "string" ? new Request(request, init) : request).url
  );
  if (url.port && url.port !== "443" && url.protocol === "https:") {
    if (!urls.has(url.toString())) {
      urls.add(url.toString());
      console.warn(
        `WARNING: known issue with \`fetch()\` requests to custom HTTPS ports in published Workers:
 - ${url.toString()} - the custom port will be ignored when the Worker is published using the \`wrangler deploy\` command.
`
      );
    }
  }
}
__name(checkURL, "checkURL");
globalThis.fetch = new Proxy(globalThis.fetch, {
  apply(target, thisArg, argArray) {
    const [request, init] = argArray;
    checkURL(request, init);
    return Reflect.apply(target, thisArg, argArray);
  }
});

// src/index.js
function generateAlphanumericCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code = "";
  for (let i = 0; i < 6; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return code.slice(0, 3) + "-" + code.slice(3);
}
__name(generateAlphanumericCode, "generateAlphanumericCode");
function generateNumericCode() {
  const array = new Uint8Array(6);
  crypto.getRandomValues(array);
  let code = "";
  for (let i = 0; i < 6; i++) {
    code += (array[i] % 10).toString();
  }
  return code;
}
__name(generateNumericCode, "generateNumericCode");
var RATE_LIMIT = {
  maxAttempts: 5,
  // Max attempts per pairing ID
  windowSeconds: 900
  // 15 minutes
};
async function checkRateLimit(pairingId, env) {
  const key = `rate:${pairingId}`;
  const data = await env.PAIRINGS.get(key);
  if (!data) {
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
  rateData.attempts += 1;
  await env.PAIRINGS.put(key, JSON.stringify(rateData), {
    expirationTtl: RATE_LIMIT.windowSeconds
  });
  return { blocked: false, attempts: rateData.attempts };
}
__name(checkRateLimit, "checkRateLimit");
function generateRequestId() {
  return crypto.randomUUID().slice(0, 8);
}
__name(generateRequestId, "generateRequestId");
async function sendAPNs(env, deviceToken, payload) {
  if (!env.APNS_KEY_ID || !env.APNS_TEAM_ID || !env.APNS_PRIVATE_KEY) {
    console.log("APNs not configured, skipping push");
    return { success: false, error: "APNs not configured" };
  }
  try {
    const privateKeyPem = atob(env.APNS_PRIVATE_KEY);
    const privateKey = await crypto.subtle.importKey(
      "pkcs8",
      pemToArrayBuffer(privateKeyPem),
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["sign"]
    );
    const header = { alg: "ES256", kid: env.APNS_KEY_ID };
    const claims = {
      iss: env.APNS_TEAM_ID,
      iat: Math.floor(Date.now() / 1e3)
    };
    const token = await createJWT(header, claims, privateKey);
    const apnsHost = env.APNS_SANDBOX === "true" ? "api.sandbox.push.apple.com" : "api.push.apple.com";
    const response = await fetch(
      `https://${apnsHost}/3/device/${deviceToken}`,
      {
        method: "POST",
        headers: {
          "authorization": `bearer ${token}`,
          "apns-topic": env.APNS_BUNDLE_ID,
          "apns-push-type": "alert",
          "apns-priority": "10"
        },
        body: JSON.stringify(payload)
      }
    );
    const responseBody = await response.text();
    if (response.ok) {
      return { success: true };
    }
    const errorData = responseBody ? JSON.parse(responseBody) : {};
    const reason = errorData.reason || "Unknown";
    if (reason === "BadDeviceToken" || reason === "Unregistered") {
      return { success: false, error: reason, shouldClearToken: true };
    }
    if (reason === "TooManyRequests") {
      return { success: false, error: reason, retryAfter: response.headers.get("Retry-After") };
    }
    return { success: false, error: reason, status: response.status };
  } catch (error) {
    console.error("APNs error:", error);
    return { success: false, error: error.message };
  }
}
__name(sendAPNs, "sendAPNs");
function pemToArrayBuffer(pem) {
  const lines = pem.split("\n").filter(
    (line) => !line.includes("-----BEGIN") && !line.includes("-----END")
  );
  const base64 = lines.join("");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}
__name(pemToArrayBuffer, "pemToArrayBuffer");
async function createJWT(header, claims, privateKey) {
  const encoder = new TextEncoder();
  const headerB64 = btoa(JSON.stringify(header)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const claimsB64 = btoa(JSON.stringify(claims)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const data = encoder.encode(`${headerB64}.${claimsB64}`);
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    privateKey,
    data
  );
  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature))).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  return `${headerB64}.${claimsB64}.${signatureB64}`;
}
__name(createJWT, "createJWT");
var corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization"
};
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders }
  });
}
__name(jsonResponse, "jsonResponse");
var src_default = {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }
    const url = new URL(request.url);
    const path = url.pathname;
    try {
      if (path === "/pair/initiate" && request.method === "POST") {
        const { deviceToken } = await request.json().catch(() => ({}));
        const code = generateNumericCode();
        const watchId = crypto.randomUUID();
        await env.PAIRINGS.put(`watch:${watchId}`, JSON.stringify({
          watchId,
          code,
          deviceToken: deviceToken || null,
          createdAt: Date.now(),
          status: "pending",
          pairingId: null
        }), { expirationTtl: 600 });
        await env.PAIRINGS.put(`watchcode:${code}`, watchId, { expirationTtl: 600 });
        return jsonResponse({
          code,
          watchId,
          expiresIn: 600
        });
      }
      if (path.startsWith("/pair/status/") && request.method === "GET") {
        const watchId = path.split("/")[3];
        const watchData = await env.PAIRINGS.get(`watch:${watchId}`);
        if (!watchData) {
          return jsonResponse({ error: "Session expired" }, 404);
        }
        const watch = JSON.parse(watchData);
        if (watch.status === "paired" && watch.pairingId) {
          return jsonResponse({
            status: "paired",
            paired: true,
            pairingId: watch.pairingId
          });
        }
        return jsonResponse({
          status: "pending",
          paired: false
        });
      }
      if (path === "/pair/complete-cli" && request.method === "POST") {
        const { code } = await request.json();
        if (!code) {
          return jsonResponse({ error: "Missing code" }, 400);
        }
        const normalizedCode = code.trim();
        const watchId = await env.PAIRINGS.get(`watchcode:${normalizedCode}`);
        if (!watchId) {
          return jsonResponse({ error: "Invalid or expired code" }, 404);
        }
        const watchData = await env.PAIRINGS.get(`watch:${watchId}`);
        if (!watchData) {
          return jsonResponse({ error: "Session expired" }, 404);
        }
        const watch = JSON.parse(watchData);
        const pairingId = crypto.randomUUID();
        watch.status = "paired";
        watch.pairingId = pairingId;
        watch.completedAt = Date.now();
        await env.PAIRINGS.put(`watch:${watchId}`, JSON.stringify(watch), { expirationTtl: 600 });
        await env.PAIRINGS.put(`pairing:${pairingId}`, JSON.stringify({
          pairingId,
          deviceToken: watch.deviceToken,
          status: "active",
          createdAt: watch.createdAt,
          completedAt: Date.now()
        }));
        await env.PAIRINGS.delete(`watchcode:${normalizedCode}`);
        return jsonResponse({
          success: true,
          pairingId,
          watchId
        });
      }
      if (path === "/pair" && request.method === "POST") {
        const format = url.searchParams.get("format");
        const isNumeric = format === "numeric";
        const code = isNumeric ? generateNumericCode() : generateAlphanumericCode();
        const pairingId = crypto.randomUUID();
        await env.PAIRINGS.put(`code:${code}`, JSON.stringify({
          pairingId,
          createdAt: Date.now(),
          status: "pending",
          format: isNumeric ? "numeric" : "alphanumeric"
        }), { expirationTtl: 600 });
        return jsonResponse({
          code,
          pairingId,
          expiresIn: 600,
          format: isNumeric ? "numeric" : "alphanumeric"
        });
      }
      if (path === "/pair/complete" && request.method === "POST") {
        const { code, deviceToken } = await request.json();
        if (!code || !deviceToken) {
          return jsonResponse({ error: "Missing code or deviceToken" }, 400);
        }
        const trimmedCode = code.trim();
        const isNumeric = /^\d{6}$/.test(trimmedCode);
        const normalizedCode = isNumeric ? trimmedCode : trimmedCode.toUpperCase();
        const pairingData = await env.PAIRINGS.get(`code:${normalizedCode}`);
        if (!pairingData) {
          return jsonResponse({ error: "Invalid or expired code" }, 404);
        }
        const pairing = JSON.parse(pairingData);
        const rateCheck = await checkRateLimit(pairing.pairingId, env);
        if (rateCheck.blocked) {
          return new Response(JSON.stringify({
            error: "Too many attempts. Please try again later.",
            retryAfter: rateCheck.retryAfter
          }), {
            status: 429,
            headers: {
              "Content-Type": "application/json",
              "Retry-After": String(rateCheck.retryAfter),
              ...corsHeaders
            }
          });
        }
        const completedPairing = {
          ...pairing,
          deviceToken,
          status: "active",
          completedAt: Date.now()
        };
        await env.PAIRINGS.put(`pairing:${pairing.pairingId}`, JSON.stringify(completedPairing));
        await env.PAIRINGS.delete(`code:${normalizedCode}`);
        await env.PAIRINGS.delete(`rate:${pairing.pairingId}`);
        return jsonResponse({
          success: true,
          pairingId: pairing.pairingId
        });
      }
      if (path.startsWith("/pair/") && path.endsWith("/status") && request.method === "GET") {
        const pairingId = path.split("/")[2];
        const pairingData = await env.PAIRINGS.get(`pairing:${pairingId}`);
        if (!pairingData) {
          return jsonResponse({ status: "pending" });
        }
        const pairing = JSON.parse(pairingData);
        return jsonResponse({
          status: pairing.status,
          completedAt: pairing.completedAt
        });
      }
      if (path === "/request" && request.method === "POST") {
        const { pairingId, type, title, description, filePath, command } = await request.json();
        if (!pairingId || !type || !title) {
          return jsonResponse({ error: "Missing required fields" }, 400);
        }
        const pairingData = await env.PAIRINGS.get(`pairing:${pairingId}`);
        if (!pairingData) {
          return jsonResponse({ error: "Invalid pairing" }, 404);
        }
        const pairing = JSON.parse(pairingData);
        if (pairing.status !== "active") {
          return jsonResponse({ error: "Pairing not active" }, 400);
        }
        const requestId = generateRequestId();
        const approvalRequest = {
          id: requestId,
          pairingId,
          type,
          title,
          description: description || "",
          filePath: filePath || null,
          command: command || null,
          status: "pending",
          createdAt: Date.now()
        };
        await env.REQUESTS.put(`request:${requestId}`, JSON.stringify(approvalRequest), {
          expirationTtl: 600
        });
        const pendingKey = `pending:${pairingId}`;
        const existingPending = await env.REQUESTS.get(pendingKey);
        const pendingList = existingPending ? JSON.parse(existingPending) : [];
        pendingList.push(requestId);
        await env.REQUESTS.put(pendingKey, JSON.stringify(pendingList), {
          expirationTtl: 600
        });
        const apnsPayload = {
          aps: {
            alert: {
              title: `Claude: ${type.replace("_", " ")}`,
              body: title,
              subtitle: description || void 0
            },
            sound: "default",
            category: "CLAUDE_ACTION",
            "mutable-content": 1
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
      if (path.startsWith("/request/") && request.method === "GET") {
        const requestId = path.split("/")[2];
        const requestData = await env.REQUESTS.get(`request:${requestId}`);
        if (!requestData) {
          return jsonResponse({ error: "Request not found or expired" }, 404);
        }
        const approvalRequest = JSON.parse(requestData);
        return jsonResponse({
          id: approvalRequest.id,
          status: approvalRequest.status,
          response: approvalRequest.response || null,
          respondedAt: approvalRequest.respondedAt || null
        });
      }
      if (path.startsWith("/requests/") && request.method === "GET") {
        const pairingId = path.split("/")[2];
        const pairingData = await env.PAIRINGS.get(`pairing:${pairingId}`);
        if (!pairingData) {
          return jsonResponse({ error: "Invalid pairing" }, 404);
        }
        const pendingKey = `pending:${pairingId}`;
        const pendingData = await env.REQUESTS.get(pendingKey);
        const pendingIds = pendingData ? JSON.parse(pendingData) : [];
        const requests = [];
        for (const requestId of pendingIds) {
          const requestData = await env.REQUESTS.get(`request:${requestId}`);
          if (requestData) {
            const req = JSON.parse(requestData);
            if (req.status === "pending") {
              requests.push(req);
            }
          }
        }
        return jsonResponse({ requests });
      }
      if (path.startsWith("/respond/") && request.method === "POST") {
        const requestId = path.split("/")[2];
        const { approved, pairingId } = await request.json();
        if (typeof approved !== "boolean") {
          return jsonResponse({ error: "Missing approved field" }, 400);
        }
        if (!pairingId) {
          return jsonResponse({ error: "Missing pairingId" }, 400);
        }
        const requestData = await env.REQUESTS.get(`request:${requestId}`);
        if (!requestData) {
          return jsonResponse({ error: "Request not found or expired" }, 404);
        }
        const approvalRequest = JSON.parse(requestData);
        if (approvalRequest.pairingId !== pairingId) {
          return jsonResponse({ error: "Unauthorized" }, 403);
        }
        approvalRequest.status = approved ? "approved" : "rejected";
        approvalRequest.response = approved;
        approvalRequest.respondedAt = Date.now();
        await env.REQUESTS.put(`request:${requestId}`, JSON.stringify(approvalRequest), {
          expirationTtl: 60
        });
        return jsonResponse({
          success: true,
          status: approvalRequest.status
        });
      }
      if (path === "/health") {
        return jsonResponse({ status: "ok", timestamp: Date.now() });
      }
      return jsonResponse({ error: "Not found" }, 404);
    } catch (error) {
      console.error("Error:", error);
      return jsonResponse({ error: error.message }, 500);
    }
  }
};

// ../../../../.npm/_npx/32026684e21afda6/node_modules/wrangler/templates/middleware/middleware-ensure-req-body-drained.ts
var drainBody = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } finally {
    try {
      if (request.body !== null && !request.bodyUsed) {
        const reader = request.body.getReader();
        while (!(await reader.read()).done) {
        }
      }
    } catch (e) {
      console.error("Failed to drain the unused request body.", e);
    }
  }
}, "drainBody");
var middleware_ensure_req_body_drained_default = drainBody;

// ../../../../.npm/_npx/32026684e21afda6/node_modules/wrangler/templates/middleware/middleware-miniflare3-json-error.ts
function reduceError(e) {
  return {
    name: e?.name,
    message: e?.message ?? String(e),
    stack: e?.stack,
    cause: e?.cause === void 0 ? void 0 : reduceError(e.cause)
  };
}
__name(reduceError, "reduceError");
var jsonError = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } catch (e) {
    const error = reduceError(e);
    return Response.json(error, {
      status: 500,
      headers: { "MF-Experimental-Error-Stack": "true" }
    });
  }
}, "jsonError");
var middleware_miniflare3_json_error_default = jsonError;

// .wrangler/tmp/bundle-S7c6MD/middleware-insertion-facade.js
var __INTERNAL_WRANGLER_MIDDLEWARE__ = [
  middleware_ensure_req_body_drained_default,
  middleware_miniflare3_json_error_default
];
var middleware_insertion_facade_default = src_default;

// ../../../../.npm/_npx/32026684e21afda6/node_modules/wrangler/templates/middleware/common.ts
var __facade_middleware__ = [];
function __facade_register__(...args) {
  __facade_middleware__.push(...args.flat());
}
__name(__facade_register__, "__facade_register__");
function __facade_invokeChain__(request, env, ctx, dispatch, middlewareChain) {
  const [head, ...tail] = middlewareChain;
  const middlewareCtx = {
    dispatch,
    next(newRequest, newEnv) {
      return __facade_invokeChain__(newRequest, newEnv, ctx, dispatch, tail);
    }
  };
  return head(request, env, ctx, middlewareCtx);
}
__name(__facade_invokeChain__, "__facade_invokeChain__");
function __facade_invoke__(request, env, ctx, dispatch, finalMiddleware) {
  return __facade_invokeChain__(request, env, ctx, dispatch, [
    ...__facade_middleware__,
    finalMiddleware
  ]);
}
__name(__facade_invoke__, "__facade_invoke__");

// .wrangler/tmp/bundle-S7c6MD/middleware-loader.entry.ts
var __Facade_ScheduledController__ = class ___Facade_ScheduledController__ {
  constructor(scheduledTime, cron, noRetry) {
    this.scheduledTime = scheduledTime;
    this.cron = cron;
    this.#noRetry = noRetry;
  }
  static {
    __name(this, "__Facade_ScheduledController__");
  }
  #noRetry;
  noRetry() {
    if (!(this instanceof ___Facade_ScheduledController__)) {
      throw new TypeError("Illegal invocation");
    }
    this.#noRetry();
  }
};
function wrapExportedHandler(worker) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return worker;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  const fetchDispatcher = /* @__PURE__ */ __name(function(request, env, ctx) {
    if (worker.fetch === void 0) {
      throw new Error("Handler does not export a fetch() function.");
    }
    return worker.fetch(request, env, ctx);
  }, "fetchDispatcher");
  return {
    ...worker,
    fetch(request, env, ctx) {
      const dispatcher = /* @__PURE__ */ __name(function(type, init) {
        if (type === "scheduled" && worker.scheduled !== void 0) {
          const controller = new __Facade_ScheduledController__(
            Date.now(),
            init.cron ?? "",
            () => {
            }
          );
          return worker.scheduled(controller, env, ctx);
        }
      }, "dispatcher");
      return __facade_invoke__(request, env, ctx, dispatcher, fetchDispatcher);
    }
  };
}
__name(wrapExportedHandler, "wrapExportedHandler");
function wrapWorkerEntrypoint(klass) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return klass;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  return class extends klass {
    #fetchDispatcher = /* @__PURE__ */ __name((request, env, ctx) => {
      this.env = env;
      this.ctx = ctx;
      if (super.fetch === void 0) {
        throw new Error("Entrypoint class does not define a fetch() function.");
      }
      return super.fetch(request);
    }, "#fetchDispatcher");
    #dispatcher = /* @__PURE__ */ __name((type, init) => {
      if (type === "scheduled" && super.scheduled !== void 0) {
        const controller = new __Facade_ScheduledController__(
          Date.now(),
          init.cron ?? "",
          () => {
          }
        );
        return super.scheduled(controller);
      }
    }, "#dispatcher");
    fetch(request) {
      return __facade_invoke__(
        request,
        this.env,
        this.ctx,
        this.#dispatcher,
        this.#fetchDispatcher
      );
    }
  };
}
__name(wrapWorkerEntrypoint, "wrapWorkerEntrypoint");
var WRAPPED_ENTRY;
if (typeof middleware_insertion_facade_default === "object") {
  WRAPPED_ENTRY = wrapExportedHandler(middleware_insertion_facade_default);
} else if (typeof middleware_insertion_facade_default === "function") {
  WRAPPED_ENTRY = wrapWorkerEntrypoint(middleware_insertion_facade_default);
}
var middleware_loader_entry_default = WRAPPED_ENTRY;
export {
  __INTERNAL_WRANGLER_MIDDLEWARE__,
  middleware_loader_entry_default as default
};
//# sourceMappingURL=index.js.map
