import SwiftUI

struct TimelineTracksView: View {
    @EnvironmentObject var vm: TimelineViewModel
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(vm.tracks.enumerated()), id: \.element.id) { index, track in
                TrackLane(track: track, isAlternate: index.isMultiple(of: 2))
                Divider().background(AppTheme.border(scheme))
            }
            Spacer()
        }
    }
}

private struct TrackLane: View {
    let track: Track
    let isAlternate: Bool
    @EnvironmentObject var vm: TimelineViewModel
    @Environment(\.colorScheme) var scheme

    var body: some View {
        ZStack(alignment: .leading) {
            // Lane background with subtle alternating tint
            (isAlternate
                ? AppTheme.bg(scheme)
                : AppTheme.bg(scheme).opacity(0.85))
                .frame(maxWidth: .infinity)

            // Clips positioned by startUnit
            ForEach(track.clips) { clip in
                ClipView(clip: clip, color: track.color)
                    .frame(
                        width: max(32, clip.durationUnits * AppTheme.Layout.timeUnit
                               - AppTheme.Layout.clipGap)
                    )
                    .offset(x: clip.startUnit * AppTheme.Layout.timeUnit)
                    .onTapGesture { vm.select(clip, in: track) }
            }
        }
        .frame(height: AppTheme.Layout.trackHeight)
        .clipped()
    }
}
