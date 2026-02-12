/**
 * Core type definitions for remmy-watch CLI.
 */

/** Persisted configuration at ~/.remmy/config.json */
export interface RemmyConfig {
  pairingId: string;
  cloudUrl: string;
  createdAt: string; // ISO 8601
  watchId?: string; // Set when watch completes pairing
}
