import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: TimelineViewModel
    @Environment(\.colorScheme) var scheme

    var body: some View {
        Group {
            if vm.isLocked {
                UnlockView()
            } else {
                timelineView
            }
        }
        .onAppear { vm.autoUnlock() }
        .animation(.easeInOut(duration: 0.25), value: vm.isLocked)
    }

    // MARK: - Timeline

    private var timelineView: some View {
        ZStack(alignment: .topLeading) {
            AppTheme.bg(scheme).ignoresSafeArea()

            VStack(spacing: 0) {
                TransportBarView()
                    .frame(height: AppTheme.Layout.transportHeight)

                Divider()
                    .background(AppTheme.border(scheme))

                HStack(spacing: 0) {
                    TrackHeadersView()
                        .frame(width: AppTheme.Layout.trackHeaderWidth)

                    Divider()
                        .background(AppTheme.border(scheme))

                    ScrollView(.horizontal, showsIndicators: false) {
                        TimelineTracksView()
                            .frame(width: vm.timelineContentWidth)
                    }
                }
            }

            // Editor overlay
            if vm.selectedClip != nil {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { vm.closeEditor() }

                EditorPanelView()
                    .offset(
                        x: AppTheme.Layout.trackHeaderWidth + 16,
                        y: AppTheme.Layout.transportHeight + 16
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            // Empty vault hint
            if vm.tracks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.textSecondary(scheme))
                    Text("Drop WAV files into subfolders inside your vault directory.")
                        .font(AppTheme.Font.trackName)
                        .foregroundStyle(AppTheme.textSecondary(scheme))
                    Text(VaultManager.vaultDirectory.path)
                        .font(AppTheme.Font.label)
                        .foregroundStyle(AppTheme.textSecondary(scheme).opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, AppTheme.Layout.transportHeight)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.selectedClip != nil)
    }
}
