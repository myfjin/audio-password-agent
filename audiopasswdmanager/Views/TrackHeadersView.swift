import SwiftUI

struct TrackHeadersView: View {
    @EnvironmentObject var vm: TimelineViewModel
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(vm.tracks.enumerated()), id: \.element.id) { index, track in
                TrackHeaderRow(track: track, isAlternate: index.isMultiple(of: 2))
                Divider().background(AppTheme.border(scheme))
            }
            Spacer()
        }
        .background(AppTheme.bgSecondary(scheme))
    }
}

private struct TrackHeaderRow: View {
    let track: Track
    let isAlternate: Bool
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(track.name)
                .font(AppTheme.Font.trackName)
                .foregroundStyle(AppTheme.textPrimary(scheme))
                .lineLimit(1)

            HStack(spacing: 6) {
                miniButton(systemName: "speaker.slash.fill",
                           active: track.isMuted,
                           activeColor: AppTheme.accent)
                miniButton(systemName: "s.circle.fill",
                           active: track.isSolo,
                           activeColor: Color(hex: "F0C040"))
                miniButton(systemName: "record.circle",
                           active: false,
                           activeColor: Color(hex: "E03030"))
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: AppTheme.Layout.trackHeight)
        .background(
            isAlternate
                ? AppTheme.bgSecondary(scheme).opacity(0.6)
                : AppTheme.bgSecondary(scheme)
        )
    }

    @ViewBuilder
    private func miniButton(
        systemName: String,
        active: Bool,
        activeColor: Color
    ) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 9))
            .foregroundStyle(active ? activeColor : AppTheme.textSecondary(scheme))
    }
}
