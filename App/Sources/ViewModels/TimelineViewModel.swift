import SwiftUI
import Combine

@MainActor
final class TimelineViewModel: ObservableObject {
    @Published var tracks: [Track]          = []
    @Published var selectedClip: TrackClip? = nil
    @Published var selectedTrack: Track?    = nil
    @Published var revealedPassword: String? = nil
    @Published var isPlaying: Bool          = false
    @Published var sessionSeconds: Int      = 0
    @Published var isDarkMode: Bool         = true
    @Published var isLocked: Bool           = true

    var colorScheme: ColorScheme { isDarkMode ? .dark : .light }

    private var vaultManager: VaultManager?
    private var timer: AnyCancellable?

    // MARK: - Vault unlock / lock

    func unlock(password: String) throws {
        let manager = VaultManager()
        try manager.setup(password: password)
        vaultManager = manager
        KeychainManager.save(password: password)
        isLocked = false
        reloadTracks()
    }

    /// Called on launch — silently unlocks if password is in Keychain.
    func autoUnlock() {
        guard isLocked, let saved = KeychainManager.load() else { return }
        try? unlock(password: saved)
    }

    func lock() {
        KeychainManager.delete()
        vaultManager   = nil
        tracks         = []
        selectedClip   = nil
        selectedTrack  = nil
        revealedPassword = nil
        isLocked       = true
    }

    func reloadTracks() {
        tracks = vaultManager?.loadTracks() ?? []
    }

    // MARK: - Credential reveal

    func revealPassword(for clip: TrackClip) {
        guard let path = clip.wavFile,
              let manager = vaultManager else { return }
        let url = URL(fileURLWithPath: path)
        revealedPassword = try? manager.retrievePassword(fromAudioAt: url)
    }

    func closeEditor() {
        selectedClip     = nil
        selectedTrack    = nil
        revealedPassword = nil
    }

    // MARK: - Selection

    func select(_ clip: TrackClip, in track: Track) {
        revealedPassword = nil
        selectedClip     = clip
        selectedTrack    = track
    }

    // MARK: - Transport

    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            timer = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in self?.sessionSeconds += 1 }
        } else {
            timer = nil
        }
    }

    func resetTimer() {
        isPlaying     = false
        timer         = nil
        sessionSeconds = 0
    }

    var timerString: String {
        let h = sessionSeconds / 3600
        let m = (sessionSeconds % 3600) / 60
        let s = sessionSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var timelineContentWidth: CGFloat {
        let maxEnd = tracks.flatMap(\.clips).map { $0.startUnit + $0.durationUnits }.max() ?? 8
        return (maxEnd + 2) * AppTheme.Layout.timeUnit
    }
}
