import SwiftUI

struct TransportBarView: View {
    @EnvironmentObject var vm: TimelineViewModel
    @Environment(\.colorScheme) var scheme

    var body: some View {
        HStack(spacing: 0) {
            // Record pill button
            Capsule()
                .fill(Color(hex: "E03030"))
                .frame(width: 36, height: 20)
                .padding(.leading, 12)

            Spacer().frame(width: 12)

            // Playback controls
            transportButton(systemName: "backward.fill")
            transportButton(systemName: "backward.frame.fill")
            transportButton(
                systemName: vm.isPlaying ? "pause.fill" : "play.fill",
                tint: AppTheme.accent
            ) {
                vm.togglePlayback()
            }
            transportButton(systemName: "forward.frame.fill")
            transportButton(systemName: "forward.fill")

            Spacer().frame(width: 8)

            // Loop / metronome toggles
            transportButton(systemName: "repeat")
            transportButton(systemName: "metronome")

            Spacer()

            // Session timer
            Text(vm.timerString)
                .font(AppTheme.Font.timer)
                .foregroundStyle(AppTheme.textPrimary(scheme))
                .monospacedDigit()

            Spacer()

            // Right-side action buttons
            accentRoundButton(systemName: "waveform.circle.fill")
            accentRoundButton(systemName: "clock.arrow.circlepath")
            accentRoundButton(systemName: "bolt.circle.fill")

            Spacer().frame(width: 8)

            // Theme toggle
            Button {
                withAnimation { vm.isDarkMode.toggle() }
            } label: {
                Image(systemName: vm.isDarkMode ? "moon.fill" : "sun.max.fill")
                    .foregroundStyle(AppTheme.textSecondary(scheme))
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)

            // Speaker icon
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(AppTheme.textSecondary(scheme))
                .font(.system(size: 13))
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.bg(scheme))
    }

    @ViewBuilder
    private func transportButton(
        systemName: String,
        tint: Color? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        Button { action?() } label: {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint ?? AppTheme.textSecondary(scheme))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func accentRoundButton(systemName: String) -> some View {
        Button {} label: {
            Image(systemName: systemName)
                .font(.system(size: 22))
                .foregroundStyle(AppTheme.accent)
        }
        .buttonStyle(.plain)
        .padding(.leading, 6)
    }
}
