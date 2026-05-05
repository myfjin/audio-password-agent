import Foundation

/// Persisted alongside the WAV vault files.
/// Holds the master salt used to derive the encryption key from the password,
/// plus a verification token used to confirm the password is correct on unlock.
/// Losing this file makes all vault credentials unrecoverable.
struct VaultConfig: Codable {
    let version:       Int
    let masterSalt:    Data      // JSONEncoder encodes Data as base64 automatically
    let kdfIterations: Int
    let createdAt:     String
    /// Encrypted marker string. Decrypting this with the derived key proves
    /// the master password is correct. `nil` for legacy vaults (pre-2026-04).
    var verifier:      Data?

    static let filename       = "vault.config"
    static let currentVersion = 1
    /// The known plaintext encrypted into `verifier` at vault creation.
    static let verifierMarker = "AUDIO_PASSWORD_AGENT_VERIFIER_v1"

    // MARK: - Persistence

    static func load(from directory: URL) throws -> VaultConfig? {
        let url = directory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(VaultConfig.self, from: data)
        } catch {
            throw VaultError.corruptConfig(reason: error.localizedDescription)
        }
    }

    func save(to directory: URL) throws {
        let url = directory.appendingPathComponent(VaultConfig.filename)
        do {
            let data = try JSONEncoder().encode(self)
            try data.write(to: url, options: .atomic)
        } catch {
            throw VaultError.vaultDirectoryUnreadable(reason: error.localizedDescription)
        }
    }
}
