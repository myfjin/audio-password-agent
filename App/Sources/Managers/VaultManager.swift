import Foundation
import SwiftUI
import AudioPasswordAgentCore

/// Bridges AudioPasswordAgentCore with the SwiftUI model layer.
///
/// Vault layout on disk:
/// ```
/// ~/Library/Application Support/AudioPasswordAgent/vault/
/// ├── vault.config          ← master salt — keep this safe
/// ├── Work/                 ← one subfolder = one timeline track
/// │   ├── github.wav
/// │   └── aws.wav
/// └── Social/
///     └── twitter.wav
/// ```
/// Drop carrier WAV files into subfolders to organise them into tracks.
/// Files at the vault root land in a "General" track.
@MainActor
final class VaultManager {

    private var agent: AudioPasswordAgent?

    // MARK: - Paths

    static var vaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AudioPasswordAgent/vault", isDirectory: true)
    }

    static var isFirstLaunch: Bool {
        !FileManager.default.fileExists(
            atPath: vaultDirectory.appendingPathComponent("vault.config").path
        )
    }

    // MARK: - Setup

    func setup(password: String) throws {
        agent = try AudioPasswordAgent(
            masterPassword: password,
            vaultDirectory: Self.vaultDirectory
        )
    }

    // MARK: - Load tracks from vault subdirectory structure

    func loadTracks() -> [Track] {
        guard let agent else { return [] }
        let fm    = FileManager.default
        let vault = Self.vaultDirectory

        guard fm.fileExists(atPath: vault.path) else { return [] }

        // Subfolders → track names. Files at root → "General".
        let dirs: [URL] = ((try? fm.contentsOfDirectory(
            at: vault,
            includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? [])
        .filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        .sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }

        var scanDirs: [(name: String, url: URL)] = dirs.map { ($0.lastPathComponent, $0) }
        if scanDirs.isEmpty {
            scanDirs = [("General", vault)]
        } else {
            // Also check vault root for loose WAV files → "General"
            let rootWAVs = ((try? fm.contentsOfDirectory(at: vault, includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.pathExtension.lowercased() == "wav" }
            if !rootWAVs.isEmpty {
                scanDirs.insert(("General", vault), at: 0)
            }
        }

        return scanDirs.enumerated().compactMap { idx, entry in
            let credentials = (try? agent.listCredentials(inDirectory: entry.url)) ?? []
            guard !credentials.isEmpty else { return nil }

            let clips: [TrackClip] = credentials.enumerated().map { clipIdx, info in
                TrackClip(
                    service:       info.service,
                    username:      info.username,
                    wavFile:       info.audioFile.path,
                    startUnit:     CGFloat(clipIdx) * 1.4,
                    durationUnits: 1.2
                )
            }
            return Track(name: entry.name, colorIndex: idx, clips: clips)
        }
    }

    // MARK: - Credential operations

    func storeCredential(
        service:  String,
        username: String,
        password: String,
        source:   URL,
        output:   URL
    ) throws {
        try agent?.storeCredential(
            service: service, username: username, password: password,
            intoAudioAt: source, writingTo: output
        )
    }

    func retrievePassword(fromAudioAt url: URL) throws -> String {
        guard let agent else { return "" }
        return try agent.retrieveCredential(fromAudioAt: url).password
    }
}
