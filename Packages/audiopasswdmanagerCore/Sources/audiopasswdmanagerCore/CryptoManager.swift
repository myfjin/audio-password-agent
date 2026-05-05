import Foundation
import CryptoKit
import CommonCrypto

/// Modern authenticated-encryption stack for the vault.
///
/// - Key derivation: **PBKDF2-SHA256**, 600 000 iterations (OWASP 2023).
/// - Encryption:     **AES-256-GCM** (authenticated, via CryptoKit).
///
/// Token layout on disk:
/// ```
/// ┌─────────┬─────────────────┬──────────────────────────────┐
/// │ version │ nonce (12 B)    │ ciphertext + auth tag (16 B) │
/// │ 1 byte  │                 │                              │
/// └─────────┴─────────────────┴──────────────────────────────┘
/// ```
///
/// `version` exists so we can evolve the format later without breaking
/// existing vault files.
public enum CryptoManager {

    // MARK: - Constants
    public static let tokenVersion: UInt8 = 1
    public static let saltLength          = 16
    public static let nonceLength         = 12
    public static let keyLength           = 32          // AES-256
    public static let gcmTagLength        = 16
    public static let kdfIterations       = 600_000

    // MARK: - Random helpers

    /// Generate a cryptographically secure random salt for key derivation.
    public static func generateSalt() -> Data {
        randomBytes(count: saltLength)
    }

    private static func randomBytes(count: Int) -> Data {
        var bytes = Data(count: count)
        let status = bytes.withUnsafeMutableBytes { buf -> Int32 in
            guard let addr = buf.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, count, addr)
        }
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed: \(status)")
        return bytes
    }

    // MARK: - Key derivation (PBKDF2-SHA256)

    /// Derive a 32-byte AES key from a password + salt using PBKDF2-SHA256.
    public static func deriveKey(password: String, salt: Data) throws -> SymmetricKey {
        let passwordBytes = Array(password.utf8)
        let saltBytes = Array(salt)
        var derived = [UInt8](repeating: 0, count: keyLength)

        let status = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            passwordBytes, passwordBytes.count,
            saltBytes,     saltBytes.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            UInt32(kdfIterations),
            &derived, keyLength
        )

        guard status == kCCSuccess else {
            throw CryptoError.keyDerivationFailed
        }
        return SymmetricKey(data: Data(derived))
    }

    // MARK: - Encrypt / Decrypt

    /// Encrypt UTF-8 plaintext under the given key.
    ///
    /// A fresh random nonce is generated for every call, so encrypting the
    /// same plaintext twice produces two different tokens.
    public static func encrypt(_ plaintext: String, key: SymmetricKey) throws -> Data {
        let plainBytes = Data(plaintext.utf8)
        let nonce = try AES.GCM.Nonce(data: randomBytes(count: nonceLength))

        let sealed: AES.GCM.SealedBox
        do {
            sealed = try AES.GCM.seal(plainBytes, using: key, nonce: nonce)
        } catch {
            throw CryptoError.encryptionFailed
        }

        var token = Data(capacity: 1 + nonceLength + sealed.ciphertext.count + gcmTagLength)
        token.append(tokenVersion)
        token.append(contentsOf: sealed.nonce)
        token.append(sealed.ciphertext)
        token.append(sealed.tag)
        return token
    }

    /// Decrypt a token produced by ``encrypt(_:key:)`` and return the UTF-8
    /// plaintext.
    public static func decrypt(_ token: Data, key: SymmetricKey) throws -> String {
        let minLength = 1 + nonceLength + gcmTagLength
        guard token.count > minLength else {
            throw CryptoError.invalidToken(reason: "token too short (\(token.count) bytes)")
        }
        guard token[token.startIndex] == tokenVersion else {
            throw CryptoError.invalidToken(reason: "unknown version \(token[token.startIndex])")
        }

        let base     = token.startIndex
        let nonceEnd = base + 1 + nonceLength
        let tagStart = token.endIndex - gcmTagLength

        let nonceData  = token[(base + 1) ..< nonceEnd]
        let ciphertext = token[nonceEnd ..< tagStart]
        let tag        = token[tagStart ..< token.endIndex]

        do {
            let nonce  = try AES.GCM.Nonce(data: nonceData)
            let sealed = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            let plain  = try AES.GCM.open(sealed, using: key)
            guard let str = String(data: plain, encoding: .utf8) else {
                throw CryptoError.decryptionFailed
            }
            return str
        } catch is CryptoError {
            throw CryptoError.decryptionFailed
        } catch {
            throw CryptoError.decryptionFailed
        }
    }
}

// MARK: - SymmetricKey → Data helper (for tests)
extension SymmetricKey {
    public var rawBytes: Data {
        withUnsafeBytes { Data($0) }
    }
}
