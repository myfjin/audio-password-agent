import SwiftUI
import Combine

@MainActor
final class TimelineViewModel: ObservableObject {
    @Published var tracks: [Track] = Track.sampleData
    @Published var selectedClip: TrackClip?  = nil
    @Published var selectedTrack: Track?     = nil
    @Published var isPlaying: Bool           = false
    @Published var sessionSeconds: Int       = 168    // 00:02:48 as in design
    @Published var isDarkMode: Bool          = true

    var colorScheme: ColorScheme { isDarkMode ? .dark : .light }

    private var timer: AnyCancellable?

    // MARK: - Selection
    func select(_ clip: TrackClip, in track: Track) {
        selectedClip  = clip
        selectedTrack = track
    }

    func closeEditor() {
        selectedClip  = nil
        selectedTrack = nil
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
        isPlaying = false
        timer = nil
        sessionSeconds = 0
    }

    // MARK: - Formatted timer  e.g. "00:02:48"
    var timerString: String {
        let h = sessionSeconds / 3600
        let m = (sessionSeconds % 3600) / 60
        let s = sessionSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    // MARK: - Total timeline width (for scroll content size)
    var timelineContentWidth: CGFloat {
        let maxEnd = tracks.flatMap(\.clips).map { $0.startUnit + $0.durationUnits }.max() ?? 8
        return (maxEnd + 2) * AppTheme.Layout.timeUnit
    }
}
