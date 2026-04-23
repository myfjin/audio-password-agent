import Foundation

/// Persisted alongside the WAV vault files.
/// Holds the master salt used to derive the encryption key from the password.
/// Losing this file makes all vault credentials unrecoverable.
struct VaultConfig: Codable {
    let version:       Int
    let masterSalt:    Data      // JSONEncoder encodes Data as base64 automatically
    let kdfIterations: Int
    let createdAt:     String

    static let filename       = "vault.config"
    static let currentVersion = 1

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
