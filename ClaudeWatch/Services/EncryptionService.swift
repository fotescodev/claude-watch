import Foundation
import CryptoKit
import os

private let logger = Logger(subsystem: "com.edgeoftrust.remmy", category: "Encryption")

/// E2E Encryption Service for secure communication with CLI
/// Uses Curve25519 key exchange + ChaChaPoly symmetric encryption
/// Implements COMP3C: Watch-side encryption using native CryptoKit
final class EncryptionService {
    static let shared = EncryptionService()

    private var privateKey: Curve25519.KeyAgreement.PrivateKey?
    private var peerPublicKey: Curve25519.KeyAgreement.PublicKey?
    private var sharedSecret: SharedSecret?

    // Storage keys
    private let privateKeyStorageKey = "com.remmy.encryption.privateKey"
    private let peerPublicKeyStorageKey = "com.remmy.encryption.peerPublicKey"

    private init() {
        loadKeys()
    }

    // MARK: - Public Interface

    /// Whether we have a key pair generated
    var hasKeyPair: Bool {
        privateKey != nil
    }

    /// Our public key as base64 string (for key exchange)
    var publicKey: String? {
        guard let privateKey = privateKey else { return nil }
        return privateKey.publicKey.rawRepresentation.base64EncodedString()
    }

    /// Generate a new key pair
    func generateKeyPair() {
        privateKey = Curve25519.KeyAgreement.PrivateKey()
        savePrivateKey()
        logger.info("Generated new key pair")
    }

    /// Set the CLI's public key for key exchange
    func setPeerPublicKey(_ base64Key: String) throws {
        guard let keyData = Data(base64Encoded: base64Key) else {
            throw EncryptionError.invalidKeyFormat
        }

        peerPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: keyData)
        savePeerPublicKey(base64Key)

        // Derive shared secret
        if let privateKey = privateKey, let peerPublicKey = peerPublicKey {
            sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)
            logger.info("Derived shared secret")
        }
    }

    /// Decrypt data from CLI using shared secret
    func decrypt(_ encryptedBase64: String) throws -> Data {
        guard let sharedSecret = sharedSecret else {
            throw EncryptionError.noSharedSecret
        }

        guard let encryptedData = Data(base64Encoded: encryptedBase64) else {
            throw EncryptionError.invalidCiphertext
        }

        // Derive symmetric key from shared secret
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: "claude-watch-e2e".data(using: .utf8)!,
            outputByteCount: 32
        )

        // First 24 bytes = nonce, rest = ciphertext + tag
        guard encryptedData.count > 24 else {
            throw EncryptionError.invalidCiphertext
        }

        let nonce = encryptedData.prefix(24)
        let ciphertextAndTag = encryptedData.dropFirst(24)

        let sealedBox = try ChaChaPoly.SealedBox(
            nonce: ChaChaPoly.Nonce(data: nonce),
            ciphertext: ciphertextAndTag.dropLast(16),
            tag: ciphertextAndTag.suffix(16)
        )

        return try ChaChaPoly.open(sealedBox, using: symmetricKey)
    }

    /// Encrypt data for CLI using shared secret
    func encrypt(_ data: Data) throws -> String {
        guard let sharedSecret = sharedSecret else {
            throw EncryptionError.noSharedSecret
        }

        // Derive symmetric key
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: "claude-watch-e2e".data(using: .utf8)!,
            outputByteCount: 32
        )

        // Encrypt with ChaChaPoly
        let sealedBox = try ChaChaPoly.seal(data, using: symmetricKey)

        // Combine nonce + ciphertext + tag
        var combined = Data()
        combined.append(contentsOf: sealedBox.nonce)
        combined.append(sealedBox.ciphertext)
        combined.append(sealedBox.tag)

        return combined.base64EncodedString()
    }

    /// Clear all keys (for unpairing)
    func clearKeys() {
        privateKey = nil
        peerPublicKey = nil
        sharedSecret = nil

        UserDefaults.standard.removeObject(forKey: privateKeyStorageKey)
        UserDefaults.standard.removeObject(forKey: peerPublicKeyStorageKey)

        logger.info("Cleared all keys")
    }

    // MARK: - Persistence

    private func loadKeys() {
        // Load private key
        if let privateKeyBase64 = UserDefaults.standard.string(forKey: privateKeyStorageKey),
           let privateKeyData = Data(base64Encoded: privateKeyBase64) {
            privateKey = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData)
        }

        // Load peer public key
        if let peerKeyBase64 = UserDefaults.standard.string(forKey: peerPublicKeyStorageKey),
           let peerKeyData = Data(base64Encoded: peerKeyBase64) {
            peerPublicKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerKeyData)

            // Re-derive shared secret
            if let privateKey = privateKey, let peerPublicKey = peerPublicKey {
                sharedSecret = try? privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)
            }
        }
    }

    private func savePrivateKey() {
        guard let privateKey = privateKey else { return }
        let base64 = privateKey.rawRepresentation.base64EncodedString()
        UserDefaults.standard.set(base64, forKey: privateKeyStorageKey)
    }

    private func savePeerPublicKey(_ base64: String) {
        UserDefaults.standard.set(base64, forKey: peerPublicKeyStorageKey)
    }
}

// MARK: - Errors

enum EncryptionError: LocalizedError {
    case invalidKeyFormat
    case noSharedSecret
    case invalidCiphertext
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .invalidKeyFormat:
            return "Invalid key format"
        case .noSharedSecret:
            return "No shared secret established"
        case .invalidCiphertext:
            return "Invalid ciphertext format"
        case .decryptionFailed:
            return "Decryption failed"
        }
    }
}
