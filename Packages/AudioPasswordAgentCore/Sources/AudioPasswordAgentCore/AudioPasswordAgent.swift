import Foundation
import CryptoKit

/// The vault orchestrator — combines `CryptoManager` and `AudioSteganography`
/// to store and retrieve encrypted credentials inside WAV audio files.
///
/// **Security model:**
/// - The WAV file is the first layer of protection (steganography /
///   plausible deniability).
/// - The master password + vault salt derive the AES-256 key (PBKDF2-SHA256,
///   600 000 iterations) — this is the second layer.
/// - Service names and usernames are readable without the master password;
///   only the actual password field is encrypted.
///
/// **Vault layout on disk:**
/// ```
/// <vaultDirectory>/
/// ├── vault.config     ← master salt (JSON) — BACK THIS UP
/// └── *.wav            ← each file carries one encrypted credential
/// ```
public final class AudioPasswordAgent {

    private let masterKey:      SymmetricKey
    private let vaultDirectory: URL
    private let iso8601:        ISO8601DateFormatter = .init()
    private let encoder:        JSONEncoder = .init()
    private let decoder:        JSONDecoder = .init()

    // MARK: - Init

    /// Open (or create) a vault at `vaultDirectory` unlocked with `masterPassword`.
    ///
    /// - If the vault directory is new, a fresh salt is generated and
    ///   saved to `vault.config`.
    /// - If `vault.config` already exists its salt is loaded and the key
    ///   is derived — the same password will always produce the same key.
    public init(masterPassword: String, vaultDirectory: URL) throws {
        self.vaultDirectory = vaultDirectory

        try FileManager.default.createDirectory(
            at: vaultDirectory, withIntermediateDirectories: true
        )

        let config: VaultConfig
        if let existing = try VaultConfig.load(from: vaultDirectory) {
            config = existing
        } else {
            let salt = CryptoManager.generateSalt()
            config = VaultConfig(
                version:       VaultConfig.currentVersion,
                masterSalt:    salt,
                kdfIterations: CryptoManager.kdfIterations,
                createdAt:     ISO8601DateFormatter().string(from: Date())
            )
            try config.save(to: vaultDirectory)
        }

        self.masterKey = try CryptoManager.deriveKey(
            password: masterPassword,
            salt:     config.masterSalt
        )
    }

    // MARK: - Store

    /// Encrypt `password` and embed it into a copy of `source` WAV file,
    /// writing the result to `output`.
    ///
    /// - Returns: A `CredentialInfo` summary (no password field).
    @discardableResult
    public func storeCredential(
        service:         String,
        username:        String,
        password:        String,
        intoAudioAt source: URL,
        writingTo output:   URL,
        metadata:        [String: String] = [:]
    ) throws -> CredentialInfo {
        try AudioSteganography.validate(audioAt: source)

        let token   = try CryptoManager.encrypt(password, key: masterKey)
        let payload = CredentialPayload(
            version:        "1.0",
            service:        service,
            username:       username,
            encryptedToken: token.base64EncodedString(),
            storedAt:       iso8601.string(from: Date()),
            metadata:       metadata
        )

        let payloadData = try encoder.encode(payload)
        let required    = payloadData.count
        let available   = (try? AudioSteganography.capacity(ofAudioAt: source)) ?? 0
        guard available >= required else {
            throw AudioError.insufficientCapacity(
                requiredBits:  required * 8,
                availableBits: available * 8
            )
        }

        try AudioSteganography.embed(
            data:         payloadData,
            intoAudioAt:  source,
            writingTo:    output
        )

        return CredentialInfo(
            service:   service,
            username:  username,
            storedAt:  payload.storedAt,
            audioFile: output
        )
    }

    // MARK: - Retrieve

    /// Extract and decrypt the credential stored in `url`.
    ///
    /// Throws `VaultError.wrongMasterPassword` if the master password used
    /// to open this vault does not match the one used when the credential
    /// was stored.
    public func retrieveCredential(fromAudioAt url: URL) throws -> Credential {
        let raw     = try AudioSteganography.extract(fromAudioAt: url)
        let payload = try decodePayload(raw)

        guard let tokenData = Data(base64Encoded: payload.encryptedToken) else {
            throw VaultError.corruptCredential(reason: "encryptedToken is not valid base64")
        }

        let password: String
        do {
            password = try CryptoManager.decrypt(tokenData, key: masterKey)
        } catch {
            throw VaultError.wrongMasterPassword
        }

        return Credential(
            service:  payload.service,
            username: payload.username,
            password: password,
            storedAt: payload.storedAt,
            metadata: payload.metadata
        )
    }

    // MARK: - List

    /// Scan `directory` for WAV files that carry credentials and return
    /// their metadata (no decryption needed — only the service name and
    /// username are read).
    public func listCredentials(inDirectory directory: URL) throws -> [CredentialInfo] {
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension.lowercased() == "wav" }
        } catch {
            throw VaultError.vaultDirectoryUnreadable(reason: error.localizedDescription)
        }

        return urls.compactMap { url in
            guard
                let raw     = try? AudioSteganography.extract(fromAudioAt: url),
                let payload = try? decodePayload(raw)
            else { return nil }

            return CredentialInfo(
                service:   payload.service,
                username:  payload.username,
                storedAt:  payload.storedAt,
                audioFile: url
            )
        }.sorted { $0.service < $1.service }
    }

    // MARK: - Private

    private func decodePayload(_ data: Data) throws -> CredentialPayload {
        do {
            return try decoder.decode(CredentialPayload.self, from: data)
        } catch {
            throw VaultError.corruptCredential(reason: error.localizedDescription)
        }
    }
}
