#if os(iOS)
import SwiftUI

struct iOSContentView: View {
    @EnvironmentObject var vm: TimelineViewModel
    @Environment(\.colorScheme) var scheme

    var body: some View {
        Group {
            if vm.isLocked {
                UnlockView()
            } else {
                iOSTimelineView
            }
        }
        .onAppear { vm.autoUnlock() }
        .animation(.easeInOut(duration: 0.25), value: vm.isLocked)
    }

    // MARK: - Timeline

    private var iOSTimelineView: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg(scheme).ignoresSafeArea()

                if vm.tracks.isEmpty {
                    emptyVaultHint
                } else {
                    trackList
                }
            }
            .navigationTitle("Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { topBarButtons }
            .safeAreaInset(edge: .bottom) { transportBar }
            .sheet(isPresented: $vm.showingAddCredential) {
                AddCredentialSheet().environmentObject(vm)
            }
            .sheet(
                isPresented: .init(
                    get: { vm.selectedClip != nil },
                    set: { if !$0 { vm.closeEditor() } }
                )
            ) {
                editorSheet
            }
        }
    }

    // MARK: - Track list

    private var trackList: some View {
        List {
            ForEach(vm.tracks) { track in
                Section {
                    ForEach(track.clips) { clip in
                        iOSCredentialRow(clip: clip, track: track)
                            .contentShape(Rectangle())
                            .onTapGesture { vm.select(clip, in: track) }
                    }
                } header: {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(track.color)
                            .frame(width: 8, height: 8)
                        Text(track.name)
                            .font(AppTheme.Font.trackName)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Bottom transport bar

    private var transportBar: some View {
        HStack(spacing: 0) {
            Text(vm.timerString)
                .font(AppTheme.Font.timer)
                .foregroundStyle(AppTheme.textPrimary(scheme))
                .monospacedDigit()
                .frame(width: 80, alignment: .leading)
                .padding(.leading, 16)

            Spacer()

            Button { } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary(scheme))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Button { vm.togglePlayback() } label: {
                Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.accent)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)

            Button { } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary(scheme))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Spacer()

            Button { vm.showingAddCredential = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("Add")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(AppTheme.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
        }
        .frame(height: 60)
        .background(
            AppTheme.bgSecondary(scheme)
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: -2)
        )
    }

    // MARK: - Top bar buttons

    @ToolbarContentBuilder
    private var topBarButtons: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                Button {
                    withAnimation { vm.isDarkMode.toggle() }
                } label: {
                    Image(systemName: vm.isDarkMode ? "moon.fill" : "sun.max.fill")
                }

                Button { vm.lock() } label: {
                    Image(systemName: "lock.fill")
                }
            }
        }
    }

    // MARK: - Credential editor sheet

    private var editorSheet: some View {
        ScrollView {
            EditorPanelView()
                .environmentObject(vm)
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
        }
        .background(AppTheme.Dark.editorBg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Empty state

    private var emptyVaultHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.textSecondary(scheme))
            Text("No credentials yet")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary(scheme))
            Text("Tap Add to store your first credential.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary(scheme))
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Credential row

private struct iOSCredentialRow: View {
    let clip: TrackClip
    let track: Track
    @Environment(\.colorScheme) var scheme

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(track.color)
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(clip.service)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary(scheme))
                Text(clip.username)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary(scheme))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary(scheme).opacity(0.4))
        }
        .padding(.vertical, 4)
    }
}
#endif
