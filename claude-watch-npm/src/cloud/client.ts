import type { CloudMessage, SessionState, WatchMessage } from "../types/index.js";
import { getCloudUrl, getPairingId } from "../config/pairing-store.js";

/**
 * Cloud Relay Client
 *
 * Communicates with the cloud relay server to bridge messages
 * between the MCP server and the Apple Watch.
 */
export class CloudClient {
  private cloudUrl: string;
  private pairingId: string | null;
  private pollInterval: number = 1000; // 1 second
  private isPolling: boolean = false;
  private messageHandler: ((message: WatchMessage) => void) | null = null;

  constructor(cloudUrl?: string, pairingId?: string) {
    this.cloudUrl = cloudUrl || getCloudUrl();
    this.pairingId = pairingId || getPairingId();
  }

  /**
   * Check if the client is configured
   */
  isConfigured(): boolean {
    return !!this.pairingId;
  }

  /**
   * Send a message to the watch via cloud relay
   */
  async sendMessage(message: WatchMessage): Promise<boolean> {
    if (!this.pairingId) {
      console.error("No pairing ID configured");
      return false;
    }

    try {
      const response = await fetch(`${this.cloudUrl}/api/message`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          pairingId: this.pairingId,
          type: "to_watch",
          payload: message,
          timestamp: new Date().toISOString(),
        }),
      });

      return response.ok;
    } catch (error) {
      console.error("Failed to send message to cloud:", error);
      return false;
    }
  }

  /**
   * Poll for messages from the watch
   */
  async pollMessages(): Promise<CloudMessage[]> {
    if (!this.pairingId) {
      return [];
    }

    try {
      const response = await fetch(
        `${this.cloudUrl}/api/messages?pairingId=${this.pairingId}&direction=to_server`
      );

      if (!response.ok) {
        return [];
      }

      const data = await response.json();
      return data.messages || [];
    } catch (error) {
      console.error("Failed to poll messages:", error);
      return [];
    }
  }

  /**
   * Broadcast state sync to watch
   */
  async syncState(state: SessionState): Promise<boolean> {
    return this.sendMessage({
      type: "state_sync",
      state,
    });
  }

  /**
   * Start polling for messages
   */
  startPolling(handler: (message: WatchMessage) => void): void {
    if (this.isPolling) return;

    this.isPolling = true;
    this.messageHandler = handler;

    const poll = async () => {
      if (!this.isPolling) return;

      const messages = await this.pollMessages();
      for (const msg of messages) {
        if (this.messageHandler && msg.payload) {
          this.messageHandler(msg.payload as WatchMessage);
        }
      }

      setTimeout(poll, this.pollInterval);
    };

    poll();
  }

  /**
   * Stop polling for messages
   */
  stopPolling(): void {
    this.isPolling = false;
    this.messageHandler = null;
  }

  /**
   * Check cloud connectivity
   */
  async checkConnectivity(): Promise<{
    connected: boolean;
    latency?: number;
    error?: string;
  }> {
    const start = Date.now();

    try {
      const response = await fetch(`${this.cloudUrl}/health`, {
        method: "GET",
        signal: AbortSignal.timeout(5000),
      });

      const latency = Date.now() - start;

      if (response.ok) {
        return { connected: true, latency };
      } else {
        return {
          connected: false,
          error: `HTTP ${response.status}`,
        };
      }
    } catch (error) {
      return {
        connected: false,
        error: error instanceof Error ? error.message : "Unknown error",
      };
    }
  }

  /**
   * Get the cloud URL
   */
  getCloudUrl(): string {
    return this.cloudUrl;
  }

  /**
   * Get the pairing ID
   */
  getPairingId(): string | null {
    return this.pairingId;
  }
}

/**
 * Create a singleton cloud client
 */
let clientInstance: CloudClient | null = null;

export function getCloudClient(): CloudClient {
  if (!clientInstance) {
    clientInstance = new CloudClient();
  }
  return clientInstance;
}

export function resetCloudClient(): void {
  if (clientInstance) {
    clientInstance.stopPolling();
    clientInstance = null;
  }
}
