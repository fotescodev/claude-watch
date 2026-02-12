import { describe, test, expect, mock, beforeEach, afterEach } from "bun:test";
import {
  DEFAULT_CLOUD_URL,
  getCloudUrl,
  checkConnectivity,
  completePairing,
} from "./cloud-client.ts";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const originalFetch = globalThis.fetch;

function mockFetch(impl: (...args: Parameters<typeof fetch>) => Promise<Response>) {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  globalThis.fetch = mock(impl) as any;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type MockFn = ReturnType<typeof mock<any>>;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function textResponse(body: string, status: number): Response {
  return new Response(body, { status });
}

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

const originalEnv = process.env.REMMY_CLOUD_URL;

beforeEach(() => {
  delete process.env.REMMY_CLOUD_URL;
});

afterEach(() => {
  globalThis.fetch = originalFetch;
  if (originalEnv !== undefined) {
    process.env.REMMY_CLOUD_URL = originalEnv;
  } else {
    delete process.env.REMMY_CLOUD_URL;
  }
});

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("cloud-client", () => {
  // R4.T6
  test("DEFAULT_CLOUD_URL is 'https://remmy.watch'", () => {
    expect(DEFAULT_CLOUD_URL).toBe("https://remmy.watch");
  });

  // R4.T7
  test("getCloudUrl returns env var when REMMY_CLOUD_URL is set", () => {
    process.env.REMMY_CLOUD_URL = "https://custom.example.com";
    expect(getCloudUrl()).toBe("https://custom.example.com");
  });

  test("getCloudUrl returns DEFAULT_CLOUD_URL when env var is not set", () => {
    delete process.env.REMMY_CLOUD_URL;
    expect(getCloudUrl()).toBe(DEFAULT_CLOUD_URL);
  });

  // R4.T1
  test("checkConnectivity returns connected=true with latency on 200", async () => {
    mockFetch(async () => jsonResponse({ status: "ok" }));

    const result = await checkConnectivity("https://test.example.com");

    expect(result.connected).toBe(true);
    expect(typeof result.latency).toBe("number");
    expect(result.latency).toBeGreaterThanOrEqual(0);
    expect(result.error).toBeUndefined();

    // Verify correct URL was called
    const fetchMock = globalThis.fetch as unknown as MockFn;
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const callArgs = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(callArgs[0]).toBe("https://test.example.com/health");
  });

  // R4.T2
  test("checkConnectivity returns connected=false on fetch error", async () => {
    mockFetch(async () => {
      throw new Error("Network unreachable");
    });

    const result = await checkConnectivity("https://test.example.com");

    expect(result.connected).toBe(false);
    expect(result.error).toBe("Network unreachable");
    expect(result.latency).toBeUndefined();
  });

  // R4.T3
  test("checkConnectivity returns connected=false on timeout", async () => {
    mockFetch(async (_url, init) => {
      // Simulate a timeout by listening for the abort signal
      const signal = init?.signal;
      return new Promise<Response>((_resolve, reject) => {
        if (signal) {
          signal.addEventListener("abort", () => {
            reject(signal.reason ?? new DOMException("The operation was aborted.", "AbortError"));
          });
        }
        // Never resolve — the abort signal will fire first
      });
    });

    // Use a very short timeout override by replacing the function temporarily
    // Instead, we rely on the abort signal being triggered by the test harness.
    // For this test, we directly simulate the abort scenario:
    mockFetch(async () => {
      throw new DOMException("The operation was aborted.", "TimeoutError");
    });

    const result = await checkConnectivity("https://test.example.com");

    expect(result.connected).toBe(false);
    expect(result.error).toBe("The operation was aborted.");
    expect(result.latency).toBeUndefined();
  });

  test("checkConnectivity returns connected=false on non-200 status", async () => {
    mockFetch(async () => textResponse("Service Unavailable", 503));

    const result = await checkConnectivity("https://test.example.com");

    expect(result.connected).toBe(false);
    expect(result.error).toBe("HTTP 503");
    expect(result.latency).toBeUndefined();
  });

  test("checkConnectivity uses getCloudUrl() when no url provided", async () => {
    process.env.REMMY_CLOUD_URL = "https://env.example.com";
    mockFetch(async () => jsonResponse({ status: "ok" }));

    await checkConnectivity();

    const fetchMock = globalThis.fetch as unknown as MockFn;
    const callArgs = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(callArgs[0]).toBe("https://env.example.com/health");
  });

  // R4.T4
  test("completePairing returns pairingId on 200", async () => {
    mockFetch(async () => jsonResponse({ pairingId: "pair-abc-123" }));

    const pairingId = await completePairing("ABC-123", "https://test.example.com");

    expect(pairingId).toBe("pair-abc-123");

    // Verify request shape
    const fetchMock = globalThis.fetch as unknown as MockFn;
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const callArgs = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(callArgs[0]).toBe("https://test.example.com/pair/complete");
    expect(callArgs[1].method).toBe("POST");
    expect(callArgs[1].headers).toEqual({ "Content-Type": "application/json" });
    expect(JSON.parse(callArgs[1].body as string)).toEqual({ code: "ABC-123" });
  });

  // R4.T5
  test("completePairing throws on 404 (expired code)", async () => {
    mockFetch(async () => textResponse("Not Found", 404));

    await expect(
      completePairing("EXPIRED-CODE", "https://test.example.com"),
    ).rejects.toThrow("Invalid or expired code");
  });

  test("completePairing throws with response text on other failures", async () => {
    mockFetch(async () => textResponse("Internal Server Error", 500));

    await expect(
      completePairing("ABC-123", "https://test.example.com"),
    ).rejects.toThrow("Internal Server Error");
  });

  test("completePairing uses getCloudUrl() when no url provided", async () => {
    process.env.REMMY_CLOUD_URL = "https://env.example.com";
    mockFetch(async () => jsonResponse({ pairingId: "pair-xyz" }));

    const pairingId = await completePairing("XYZ-789");

    expect(pairingId).toBe("pair-xyz");

    const fetchMock = globalThis.fetch as unknown as MockFn;
    const callArgs = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(callArgs[0]).toBe("https://env.example.com/pair/complete");
  });
});
