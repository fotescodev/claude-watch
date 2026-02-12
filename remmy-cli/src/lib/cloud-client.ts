/**
 * Cloud Client — communicates with the Remmy cloud relay.
 *
 * Zero runtime dependencies: uses native fetch() and AbortSignal.timeout().
 */

export const DEFAULT_CLOUD_URL = "https://remmy.watch";

/**
 * Returns the cloud URL from the REMMY_CLOUD_URL env var,
 * falling back to DEFAULT_CLOUD_URL.
 */
export function getCloudUrl(): string {
  return process.env.REMMY_CLOUD_URL || DEFAULT_CLOUD_URL;
}

export interface ConnectivityResult {
  connected: boolean;
  latency?: number;
  error?: string;
}

/**
 * Check connectivity to the cloud relay by hitting GET /health.
 * Uses a 5-second timeout via AbortSignal.timeout().
 */
export async function checkConnectivity(
  cloudUrl?: string,
): Promise<ConnectivityResult> {
  const url = cloudUrl ?? getCloudUrl();
  const start = performance.now();

  try {
    const response = await fetch(`${url}/health`, {
      method: "GET",
      signal: AbortSignal.timeout(5000),
    });

    const latency = Math.round(performance.now() - start);

    if (response.ok) {
      return { connected: true, latency };
    }

    return {
      connected: false,
      error: `HTTP ${response.status}`,
    };
  } catch (error) {
    return {
      connected: false,
      error: error instanceof Error ? error.message : "Unknown error",
    };
  }
}

/**
 * Complete the pairing flow by submitting the code displayed on the watch.
 *
 * POST {cloudUrl}/pair/complete  body: { code }
 * Returns the pairingId on success (200).
 * Throws on 404 (invalid/expired code) or other failures.
 */
export async function completePairing(
  code: string,
  cloudUrl?: string,
): Promise<string> {
  const url = cloudUrl ?? getCloudUrl();

  const response = await fetch(`${url}/pair/complete`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ code }),
  });

  if (response.ok) {
    const data = (await response.json()) as { pairingId: string };
    return data.pairingId;
  }

  if (response.status === 404) {
    throw new Error("Invalid or expired code");
  }

  const text = await response.text().catch(() => `HTTP ${response.status}`);
  throw new Error(text);
}
