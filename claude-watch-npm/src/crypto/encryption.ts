/**
 * E2E Encryption for Claude Watch
 *
 * Implements NaCl box encryption for secure communication between
 * CLI and Apple Watch. Uses x25519 key exchange with XSalsa20-Poly1305.
 *
 * Reference: happy-reference/sources/sync/encryption/
 */

import nacl from "tweetnacl";
import util from "tweetnacl-util";

const { encodeBase64, decodeBase64, encodeUTF8, decodeUTF8 } = util;

// =============================================================================
// Types
// =============================================================================

export interface KeyPair {
  publicKey: Uint8Array;
  secretKey: Uint8Array;
}

export interface SerializedKeyPair {
  publicKey: string; // Base64
  secretKey: string; // Base64
}

export interface EncryptedPayload {
  nonce: string; // Base64
  ciphertext: string; // Base64
}

// =============================================================================
// Key Generation
// =============================================================================

/**
 * Generate a new x25519 keypair for NaCl box encryption
 */
export function generateKeyPair(): KeyPair {
  return nacl.box.keyPair();
}

/**
 * Serialize a keypair to base64 strings for storage
 */
export function serializeKeyPair(keyPair: KeyPair): SerializedKeyPair {
  return {
    publicKey: encodeBase64(keyPair.publicKey),
    secretKey: encodeBase64(keyPair.secretKey),
  };
}

/**
 * Deserialize a keypair from base64 strings
 */
export function deserializeKeyPair(serialized: SerializedKeyPair): KeyPair {
  return {
    publicKey: decodeBase64(serialized.publicKey),
    secretKey: decodeBase64(serialized.secretKey),
  };
}

/**
 * Derive a shared secret from our secret key and peer's public key
 * This is the x25519 Diffie-Hellman shared secret
 */
export function deriveSharedKey(
  ourSecretKey: Uint8Array,
  theirPublicKey: Uint8Array
): Uint8Array {
  return nacl.box.before(theirPublicKey, ourSecretKey);
}

// =============================================================================
// Encryption / Decryption
// =============================================================================

/**
 * Generate a random 24-byte nonce for NaCl box
 */
export function generateNonce(): Uint8Array {
  return nacl.randomBytes(nacl.box.nonceLength);
}

/**
 * Encrypt a message using NaCl box (x25519 + XSalsa20-Poly1305)
 *
 * @param message - Plaintext message (string or bytes)
 * @param theirPublicKey - Recipient's public key
 * @param ourSecretKey - Our secret key
 * @returns Encrypted payload with nonce and ciphertext
 */
export function encrypt(
  message: string | Uint8Array,
  theirPublicKey: Uint8Array,
  ourSecretKey: Uint8Array
): EncryptedPayload {
  const nonce = generateNonce();
  const messageBytes =
    typeof message === "string" ? decodeUTF8(message) : message;

  const ciphertext = nacl.box(messageBytes, nonce, theirPublicKey, ourSecretKey);

  if (!ciphertext) {
    throw new Error("Encryption failed");
  }

  return {
    nonce: encodeBase64(nonce),
    ciphertext: encodeBase64(ciphertext),
  };
}

/**
 * Encrypt a message using a precomputed shared key (faster for multiple messages)
 */
export function encryptWithSharedKey(
  message: string | Uint8Array,
  sharedKey: Uint8Array
): EncryptedPayload {
  const nonce = generateNonce();
  const messageBytes =
    typeof message === "string" ? decodeUTF8(message) : message;

  const ciphertext = nacl.box.after(messageBytes, nonce, sharedKey);

  if (!ciphertext) {
    throw new Error("Encryption failed");
  }

  return {
    nonce: encodeBase64(nonce),
    ciphertext: encodeBase64(ciphertext),
  };
}

/**
 * Decrypt a message using NaCl box
 *
 * @param payload - Encrypted payload with nonce and ciphertext
 * @param theirPublicKey - Sender's public key
 * @param ourSecretKey - Our secret key
 * @returns Decrypted message as string
 * @throws Error if decryption fails (authentication failure)
 */
export function decrypt(
  payload: EncryptedPayload,
  theirPublicKey: Uint8Array,
  ourSecretKey: Uint8Array
): string {
  const nonce = decodeBase64(payload.nonce);
  const ciphertext = decodeBase64(payload.ciphertext);

  const plaintext = nacl.box.open(ciphertext, nonce, theirPublicKey, ourSecretKey);

  if (!plaintext) {
    throw new Error("Decryption failed - authentication error");
  }

  return encodeUTF8(plaintext);
}

/**
 * Decrypt a message using a precomputed shared key
 */
export function decryptWithSharedKey(
  payload: EncryptedPayload,
  sharedKey: Uint8Array
): string {
  const nonce = decodeBase64(payload.nonce);
  const ciphertext = decodeBase64(payload.ciphertext);

  const plaintext = nacl.box.open.after(ciphertext, nonce, sharedKey);

  if (!plaintext) {
    throw new Error("Decryption failed - authentication error");
  }

  return encodeUTF8(plaintext);
}

/**
 * Decrypt a message and return raw bytes
 */
export function decryptToBytes(
  payload: EncryptedPayload,
  theirPublicKey: Uint8Array,
  ourSecretKey: Uint8Array
): Uint8Array {
  const nonce = decodeBase64(payload.nonce);
  const ciphertext = decodeBase64(payload.ciphertext);

  const plaintext = nacl.box.open(ciphertext, nonce, theirPublicKey, ourSecretKey);

  if (!plaintext) {
    throw new Error("Decryption failed - authentication error");
  }

  return plaintext;
}

// =============================================================================
// JSON Encryption Helpers
// =============================================================================

/**
 * Encrypt a JSON object
 */
export function encryptJson<T>(
  data: T,
  theirPublicKey: Uint8Array,
  ourSecretKey: Uint8Array
): EncryptedPayload {
  const json = JSON.stringify(data);
  return encrypt(json, theirPublicKey, ourSecretKey);
}

/**
 * Decrypt a JSON object
 */
export function decryptJson<T>(
  payload: EncryptedPayload,
  theirPublicKey: Uint8Array,
  ourSecretKey: Uint8Array
): T {
  const json = decrypt(payload, theirPublicKey, ourSecretKey);
  return JSON.parse(json) as T;
}

// =============================================================================
// Utility Functions
// =============================================================================

/**
 * Encode bytes to base64 (re-export for convenience)
 */
export { encodeBase64, decodeBase64 };

/**
 * Verify that a public key is valid (correct length)
 */
export function isValidPublicKey(key: Uint8Array | string): boolean {
  const keyBytes = typeof key === "string" ? decodeBase64(key) : key;
  return keyBytes.length === nacl.box.publicKeyLength;
}

/**
 * Verify that a secret key is valid (correct length)
 */
export function isValidSecretKey(key: Uint8Array | string): boolean {
  const keyBytes = typeof key === "string" ? decodeBase64(key) : key;
  return keyBytes.length === nacl.box.secretKeyLength;
}

/**
 * Get key lengths for reference
 */
export const KEY_LENGTHS = {
  publicKey: nacl.box.publicKeyLength, // 32 bytes
  secretKey: nacl.box.secretKeyLength, // 32 bytes
  nonce: nacl.box.nonceLength, // 24 bytes
  overhead: nacl.box.overheadLength, // 16 bytes (MAC)
} as const;
