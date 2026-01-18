import { getCloudUrl } from "../config/pairing-store.js";

/**
 * Generate a 6-digit pairing code
 */
export function generatePairingCode(): string {
  const digits = [];
  for (let i = 0; i < 6; i++) {
    digits.push(Math.floor(Math.random() * 10));
  }
  return digits.join("");
}

/**
 * Format pairing code for display (e.g., "4 7 2 9 1 3")
 */
export function formatPairingCode(code: string): string {
  return code.split("").join(" ");
}

/**
 * Pairing session that waits for watch to pair
 */
export class PairingSession {
  private code: string;
  private cloudUrl: string;
  private sessionId: string;
  private pollInterval: number = 1000;
  private maxAttempts: number = 300; // 5 minutes at 1 second interval
  private isActive: boolean = false;

  constructor(cloudUrl?: string) {
    this.code = generatePairingCode();
    this.cloudUrl = cloudUrl || getCloudUrl();
    this.sessionId = crypto.randomUUID();
  }

  /**
   * Get the pairing code
   */
  getCode(): string {
    return this.code;
  }

  /**
   * Get the formatted pairing code for display
   */
  getFormattedCode(): string {
    return formatPairingCode(this.code);
  }

  /**
   * Register the pairing code with the cloud
   */
  async register(): Promise<boolean> {
    try {
      const response = await fetch(`${this.cloudUrl}/api/pairing/register`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          code: this.code,
          sessionId: this.sessionId,
          timestamp: new Date().toISOString(),
        }),
      });

      return response.ok;
    } catch (error) {
      console.error("Failed to register pairing code:", error);
      return false;
    }
  }

  /**
   * Wait for the watch to pair using the code
   * Returns the pairing ID when successful, or null on timeout/cancel
   */
  async waitForPairing(
    onProgress?: (attempt: number, maxAttempts: number) => void
  ): Promise<string | null> {
    this.isActive = true;
    let attempts = 0;

    while (this.isActive && attempts < this.maxAttempts) {
      attempts++;
      if (onProgress) {
        onProgress(attempts, this.maxAttempts);
      }

      try {
        const response = await fetch(
          `${this.cloudUrl}/api/pairing/check?sessionId=${this.sessionId}`
        );

        if (response.ok) {
          const data = await response.json();
          if (data.paired && data.pairingId) {
            this.isActive = false;
            return data.pairingId;
          }
        }
      } catch (error) {
        // Ignore polling errors and continue
      }

      await new Promise((resolve) => setTimeout(resolve, this.pollInterval));
    }

    this.isActive = false;
    return null;
  }

  /**
   * Cancel the pairing session
   */
  cancel(): void {
    this.isActive = false;
  }

  /**
   * Cleanup the pairing session on the server
   */
  async cleanup(): Promise<void> {
    try {
      await fetch(`${this.cloudUrl}/api/pairing/cleanup`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          sessionId: this.sessionId,
        }),
      });
    } catch {
      // Ignore cleanup errors
    }
  }
}

/**
 * Simulate local-only pairing (for testing or local mode)
 * In this mode, we generate a pairing ID immediately
 */
export function createLocalPairing(): string {
  return crypto.randomUUID();
}
