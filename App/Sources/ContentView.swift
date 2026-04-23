import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: TimelineViewModel
    @Environment(\.colorScheme) var scheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            AppTheme.bg(scheme).ignoresSafeArea()

            VStack(spacing: 0) {
                TransportBarView()
                    .frame(height: AppTheme.Layout.transportHeight)

                Divider()
                    .background(AppTheme.border(scheme))

                HStack(spacing: 0) {
                    // Fixed left column — track names
                    TrackHeadersView()
                        .frame(width: AppTheme.Layout.trackHeaderWidth)

                    Divider()
                        .background(AppTheme.border(scheme))

                    // Horizontally scrollable clip canvas
                    ScrollView(.horizontal, showsIndicators: false) {
                        TimelineTracksView()
                            .frame(width: vm.timelineContentWidth)
                    }
                }
            }

            // Editor panel overlay
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
        }
        .animation(.easeInOut(duration: 0.2), value: vm.selectedClip != nil)
    }
}
