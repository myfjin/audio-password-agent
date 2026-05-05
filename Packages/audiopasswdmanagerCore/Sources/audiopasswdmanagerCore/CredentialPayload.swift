import Foundation

/// JSON structure embedded inside every credential WAV file.
///
/// The plaintext password is NOT stored here — only the AES-GCM token
/// (base64-encoded) that can be decrypted with the vault's master key.
struct CredentialPayload: Codable {
    let version:        String
    let service:        String
    let username:       String
    let encryptedToken: String              // base64(AES-GCM token)
    let storedAt:       String              // ISO 8601
    let metadata:       [String: String]
}
