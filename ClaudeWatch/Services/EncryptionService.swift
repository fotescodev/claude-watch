import Foundation
import CryptoKit

/// E2E Encryption Service for Claude Watch (COMP3C)
/// Uses Curve25519 for key exchange and ChaChaPoly for encryption
final class EncryptionService {
    static let shared = EncryptionService()

    private var privateKey: Curve25519.KeyAgreement.PrivateKey?
    private var peerPublicKey: Curve25519.KeyAgreement.PublicKey?

    private init() {
        // Load existing keypair from Keychain if available
        loadKeyPair()
    }

    // MARK: - Public API

    /// Whether we have a local keypair
    var hasKeyPair: Bool {
        return privateKey != nil
    }

    /// Our public key as base64 string (for sharing with CLI)
    var publicKey: String? {
        guard let privateKey = privateKey else { return nil }
        return privateKey.publicKey.rawRepresentation.base64EncodedString()
    }

    /// Generate a new keypair
    func generateKeyPair() {
        privateKey = Curve25519.KeyAgreement.PrivateKey()
        saveKeyPair()
        print("[Encryption] Generated new keypair")
    }

    /// Set the peer's public key (from CLI)
    func setPeerPublicKey(_ base64Key: String) throws {
        guard let keyData = Data(base64Encoded: base64Key) else {
            throw EncryptionError.invalidKey
        }
        peerPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: keyData)
        print("[Encryption] Peer public key set")
    }

    /// Whether we can encrypt (have both keys)
    var canEncrypt: Bool {
        return privateKey != nil && peerPublicKey != nil
    }

    /// Decrypt data from CLI
    func decrypt(_ encryptedBase64: String) throws -> Data {
        guard let privateKey = privateKey,
              let peerPublicKey = peerPublicKey else {
            throw EncryptionError.notConfigured
        }

        guard let combined = Data(base64Encoded: encryptedBase64) else {
            throw EncryptionError.invalidData
        }

        // Format: nonce (12 bytes) + ciphertext + tag (16 bytes)
        guard combined.count > 28 else {
            throw EncryptionError.invalidData
        }

        let nonce = combined.prefix(12)
        let ciphertextAndTag = combined.dropFirst(12)

        // Derive shared secret
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("claude-watch-e2e".utf8),
            outputByteCount: 32
        )

        // Decrypt
        let sealedBox = try ChaChaPoly.SealedBox(
            nonce: ChaChaPoly.Nonce(data: nonce),
            ciphertext: ciphertextAndTag.dropLast(16),
            tag: ciphertextAndTag.suffix(16)
        )

        return try ChaChaPoly.open(sealedBox, using: symmetricKey)
    }

    // MARK: - Keychain Storage

    private let keychainService = "com.claudewatch.encryption"
    private let keychainAccount = "privateKey"

    private func saveKeyPair() {
        guard let privateKey = privateKey else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: privateKey.rawRepresentation
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadKeyPair() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            privateKey = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
            if privateKey != nil {
                print("[Encryption] Loaded existing keypair from Keychain")
            }
        }
    }
}

// MARK: - Errors

enum EncryptionError: Error {
    case notConfigured
    case invalidKey
    case invalidData
    case decryptionFailed
}
