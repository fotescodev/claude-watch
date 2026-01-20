/**
 * Tests for E2E encryption module
 */

import { test, describe } from "node:test";
import assert from "node:assert";
import {
  generateKeyPair,
  serializeKeyPair,
  deserializeKeyPair,
  encrypt,
  decrypt,
  encryptJson,
  decryptJson,
  deriveSharedKey,
  encryptWithSharedKey,
  decryptWithSharedKey,
  isValidPublicKey,
  isValidSecretKey,
  KEY_LENGTHS,
  encodeBase64,
  decodeBase64,
} from "../crypto/encryption.js";

describe("Key Generation", () => {
  test("generateKeyPair creates valid keypair", () => {
    const keyPair = generateKeyPair();

    assert.strictEqual(keyPair.publicKey.length, KEY_LENGTHS.publicKey);
    assert.strictEqual(keyPair.secretKey.length, KEY_LENGTHS.secretKey);
    assert.ok(keyPair.publicKey instanceof Uint8Array);
    assert.ok(keyPair.secretKey instanceof Uint8Array);
  });

  test("each keypair is unique", () => {
    const kp1 = generateKeyPair();
    const kp2 = generateKeyPair();

    assert.notDeepStrictEqual(kp1.publicKey, kp2.publicKey);
    assert.notDeepStrictEqual(kp1.secretKey, kp2.secretKey);
  });

  test("serializeKeyPair and deserializeKeyPair roundtrip", () => {
    const original = generateKeyPair();
    const serialized = serializeKeyPair(original);
    const restored = deserializeKeyPair(serialized);

    assert.deepStrictEqual(restored.publicKey, original.publicKey);
    assert.deepStrictEqual(restored.secretKey, original.secretKey);
  });

  test("serialized keys are base64 strings", () => {
    const keyPair = generateKeyPair();
    const serialized = serializeKeyPair(keyPair);

    assert.strictEqual(typeof serialized.publicKey, "string");
    assert.strictEqual(typeof serialized.secretKey, "string");
    // Base64 of 32 bytes = 44 characters (with padding)
    assert.strictEqual(serialized.publicKey.length, 44);
    assert.strictEqual(serialized.secretKey.length, 44);
  });
});

describe("Key Validation", () => {
  test("isValidPublicKey validates correct key", () => {
    const keyPair = generateKeyPair();
    assert.ok(isValidPublicKey(keyPair.publicKey));
  });

  test("isValidPublicKey validates base64 string", () => {
    const keyPair = generateKeyPair();
    const serialized = serializeKeyPair(keyPair);
    assert.ok(isValidPublicKey(serialized.publicKey));
  });

  test("isValidPublicKey rejects wrong length", () => {
    const wrongLength = new Uint8Array(16);
    assert.ok(!isValidPublicKey(wrongLength));
  });

  test("isValidSecretKey validates correct key", () => {
    const keyPair = generateKeyPair();
    assert.ok(isValidSecretKey(keyPair.secretKey));
  });
});

describe("Basic Encryption", () => {
  test("encrypt returns nonce and ciphertext", () => {
    const alice = generateKeyPair();
    const bob = generateKeyPair();

    const payload = encrypt("Hello, World!", bob.publicKey, alice.secretKey);

    assert.ok(payload.nonce);
    assert.ok(payload.ciphertext);
    assert.strictEqual(typeof payload.nonce, "string");
    assert.strictEqual(typeof payload.ciphertext, "string");
  });

  test("encrypt-decrypt roundtrip with string", () => {
    const alice = generateKeyPair();
    const bob = generateKeyPair();
    const message = "Hello, World!";

    const encrypted = encrypt(message, bob.publicKey, alice.secretKey);
    const decrypted = decrypt(encrypted, alice.publicKey, bob.secretKey);

    assert.strictEqual(decrypted, message);
  });

  test("encrypt-decrypt roundtrip with unicode", () => {
    const alice = generateKeyPair();
    const bob = generateKeyPair();
    const message = "Hello, World!";

    const encrypted = encrypt(message, bob.publicKey, alice.secretKey);
    const decrypted = decrypt(encrypted, alice.publicKey, bob.secretKey);

    assert.strictEqual(decrypted, message);
  });

  test("encrypt-decrypt with empty string", () => {
    const alice = generateKeyPair();
    const bob = generateKeyPair();
    const message = "";

    const encrypted = encrypt(message, bob.publicKey, alice.secretKey);
    const decrypted = decrypt(encrypted, alice.publicKey, bob.secretKey);

    assert.strictEqual(decrypted, message);
  });

  test("encrypt-decrypt with long message", () => {
    const alice = generateKeyPair();
    const bob = generateKeyPair();
    const message = "A".repeat(10000);

    const encrypted = encrypt(message, bob.publicKey, alice.secretKey);
    const decrypted = decrypt(encrypted, alice.publicKey, bob.secretKey);

    assert.strictEqual(decrypted, message);
  });

  test("decrypt fails with wrong key", () => {
    const alice = generateKeyPair();
    const bob = generateKeyPair();
    const eve = generateKeyPair();

    const encrypted = encrypt("secret message", bob.publicKey, alice.secretKey);

    assert.throws(() => {
      decrypt(encrypted, alice.publicKey, eve.secretKey);
    }, /Decryption failed/);
  });

  test("decrypt fails with tampered ciphertext", () => {
    const alice = generateKeyPair();
    const bob = generateKeyPair();

    const encrypted = encrypt("secret message", bob.publicKey, alice.secretKey);
    // Tamper with the ciphertext
    const tampered = {
      ...encrypted,
      ciphertext: encodeBase64(new Uint8Array(decodeBase64(encrypted.ciphertext).map(b => b ^ 0xff))),
    };

    assert.throws(() => {
      decrypt(tampered, alice.publicKey, bob.secretKey);
    }, /Decryption failed/);
  });
});

describe("Shared Key Encryption", () => {
  test("shared key derivation is symmetric", () => {
    const alice = generateKeyPair();
    const bob = generateKeyPair();

    const aliceShared = deriveSharedKey(alice.secretKey, bob.publicKey);
    const bobShared = deriveSharedKey(bob.secretKey, alice.publicKey);

    assert.deepStrictEqual(aliceShared, bobShared);
  });

  test("encryptWithSharedKey-decryptWithSharedKey roundtrip", () => {
    const alice = generateKeyPair();
    const bob = generateKeyPair();
    const message = "Hello with shared key!";

    const sharedKey = deriveSharedKey(alice.secretKey, bob.publicKey);

    const encrypted = encryptWithSharedKey(message, sharedKey);
    const decrypted = decryptWithSharedKey(encrypted, sharedKey);

    assert.strictEqual(decrypted, message);
  });
});

describe("JSON Encryption", () => {
  test("encryptJson-decryptJson roundtrip", () => {
    const alice = generateKeyPair();
    const bob = generateKeyPair();
    const data = {
      type: "approval_request",
      id: "abc123",
      title: "Edit file.ts",
      nested: {
        value: 42,
        array: [1, 2, 3],
      },
    };

    const encrypted = encryptJson(data, bob.publicKey, alice.secretKey);
    const decrypted = decryptJson(encrypted, alice.publicKey, bob.secretKey);

    assert.deepStrictEqual(decrypted, data);
  });

  test("encryptJson handles arrays", () => {
    const alice = generateKeyPair();
    const bob = generateKeyPair();
    const data = [1, 2, "three", { four: 4 }];

    const encrypted = encryptJson(data, bob.publicKey, alice.secretKey);
    const decrypted = decryptJson(encrypted, alice.publicKey, bob.secretKey);

    assert.deepStrictEqual(decrypted, data);
  });
});

describe("Cross-party Communication Simulation", () => {
  test("CLI encrypts, Watch decrypts (realistic scenario)", () => {
    // CLI generates its keypair during pairing
    const cliKeyPair = generateKeyPair();

    // Watch generates its keypair during pairing
    const watchKeyPair = generateKeyPair();

    // Both exchange public keys during pairing
    // CLI has: cliKeyPair.secretKey, watchKeyPair.publicKey
    // Watch has: watchKeyPair.secretKey, cliKeyPair.publicKey

    // CLI encrypts an approval request for Watch
    const approvalRequest = {
      id: "req-001",
      type: "file_edit",
      title: "Edit config.ts",
      description: "Update database connection string",
    };

    const encryptedRequest = encryptJson(
      approvalRequest,
      watchKeyPair.publicKey,
      cliKeyPair.secretKey
    );

    // Watch decrypts the request
    const decryptedRequest = decryptJson(
      encryptedRequest,
      cliKeyPair.publicKey,
      watchKeyPair.secretKey
    );

    assert.deepStrictEqual(decryptedRequest, approvalRequest);

    // Watch encrypts response for CLI
    const approvalResponse = {
      id: "req-001",
      approved: true,
      timestamp: new Date().toISOString(),
    };

    const encryptedResponse = encryptJson(
      approvalResponse,
      cliKeyPair.publicKey,
      watchKeyPair.secretKey
    );

    // CLI decrypts the response
    const decryptedResponse = decryptJson(
      encryptedResponse,
      watchKeyPair.publicKey,
      cliKeyPair.secretKey
    );

    assert.deepStrictEqual(decryptedResponse, approvalResponse);
  });
});
