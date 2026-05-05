import SwiftUI

// MARK: - Container

struct TrackHeadersView: View {
    @EnvironmentObject var vm: TimelineViewModel
    @Environment(\.colorScheme) var scheme

    /// Which clip's password is currently decrypted and visible.
    @State private var revealedPasswords: [UUID: String] = [:]
    /// Which clip was most-recently copied (drives the ✓ icon feedback).
    @State private var copiedClipID: UUID? = nil
    /// Clip queued for editing.
    @State private var editingClip: TrackClip? = nil
    /// Clip queued for deletion.
    @State private var deletingClip: TrackClip? = nil

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(vm.tracks) { track in
                    TrackSectionHeader(track: track)
                    ForEach(track.clips) { clip in
                        CredentialRow(
                            clip:             clip,
                            track:            track,
                            revealedPassword: revealedPasswords[clip.id],
                            isCopied:         copiedClipID == clip.id,
                            onReveal:         { toggleReveal(clip) },
                            onCopy:           { copyPassword(clip) },
                            onEdit:           { editingClip = clip },
                            onDelete:         { deletingClip = clip }
                        )
                        Divider()
                            .background(AppTheme.border(scheme).opacity(0.5))
                            .padding(.leading, 28)
                    }
                }
                Spacer()
            }
        }
        .background(AppTheme.bgSecondary(scheme))
        // Edit sheet
        .sheet(item: $editingClip) { clip in
            EditCredentialSheet(clip: clip).environmentObject(vm)
        }
        // Delete confirmation
        .confirmationDialog(
            "Delete \"\(deletingClip?.service ?? "")\"?",
            isPresented: Binding(
                get: { deletingClip != nil },
                set: { if !$0 { deletingClip = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let path = deletingClip?.wavFile {
                    vm.deleteCredential(wavPath: path)
                    revealedPasswords[deletingClip!.id] = nil
                }
                deletingClip = nil
            }
        } message: {
            Text("The credential and its WAV file will be permanently removed from the vault.")
        }
    }

    // MARK: - Actions

    private func toggleReveal(_ clip: TrackClip) {
        if revealedPasswords[clip.id] != nil {
            revealedPasswords[clip.id] = nil
        } else {
            let pwd = try? vm.currentPassword(for: clip)
            revealedPasswords[clip.id] = pwd
        }
    }

    private func copyPassword(_ clip: TrackClip) {
        // Use already-revealed password if available, otherwise decrypt on demand.
        let pwd: String?
        if let cached = revealedPasswords[clip.id] {
            pwd = cached
        } else {
            pwd = try? vm.currentPassword(for: clip)
        }
        guard let password = pwd else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(password, forType: .string)

        withAnimation(.easeInOut(duration: 0.15)) { copiedClipID = clip.id }

        // Hide ✓ icon after 2 s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { if copiedClipID == clip.id { copiedClipID = nil } }
        }
        // Security: clear clipboard after 30 s
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            NSPasteboard.general.clearContents()
        }
    }
}

// MARK: - Section header (one per track/folder)

private struct TrackSectionHeader: View {
    let track: Track
    @Environment(\.colorScheme) var scheme

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(track.color)
                .frame(width: 3, height: 14)
            Text(track.name.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary(scheme))
                .tracking(0.8)
                .lineLimit(1)
            Spacer()
            Text("\(track.clips.count)")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary(scheme).opacity(0.5))
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(AppTheme.bgSecondary(scheme))
    }
}

// MARK: - Individual credential row

private struct CredentialRow: View {
    let clip:             TrackClip
    let track:            Track
    let revealedPassword: String?
    let isCopied:         Bool
    let onReveal:         () -> Void
    let onCopy:           () -> Void
    let onEdit:           () -> Void
    let onDelete:         () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Row 1: service name + edit/delete
            HStack(spacing: 0) {
                Circle()
                    .fill(track.color)
                    .frame(width: 6, height: 6)
                    .padding(.trailing, 6)

                Text(clip.service)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary(scheme))
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Edit / Delete — always present, fade in on hover
                HStack(spacing: 2) {
                    iconButton(systemName: "pencil", color: AppTheme.textSecondary(scheme)) { onEdit() }
                    iconButton(systemName: "trash",  color: Color(hex: "FF5C5C"))            { onDelete() }
                }
                .opacity(isHovered ? 1 : 0)
                .animation(.easeInOut(duration: 0.12), value: isHovered)
            }

            // Row 2: username
            Text(clip.username.isEmpty ? "—" : clip.username)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textSecondary(scheme))
                .lineLimit(1)
                .padding(.leading, 12)

            // Row 3: masked password + eye + copy
            HStack(spacing: 6) {
                Text(revealedPassword ?? "••••••••••")
                    .font(.system(size: 10, design: revealedPassword == nil ? .default : .monospaced))
                    .foregroundStyle(revealedPassword != nil
                        ? AppTheme.textPrimary(scheme)
                        : AppTheme.textSecondary(scheme).opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 12)

                Spacer(minLength: 2)

                // Eye toggle
                iconButton(
                    systemName: revealedPassword == nil ? "eye" : "eye.slash",
                    color: AppTheme.accent
                ) { onReveal() }

                // Copy
                iconButton(
                    systemName: isCopied ? "checkmark" : "doc.on.doc",
                    color: isCopied ? Color(hex: "3DC870") : AppTheme.textSecondary(scheme)
                ) { onCopy() }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            isHovered
                ? AppTheme.bg(scheme).opacity(0.5)
                : Color.clear
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { /* tap row = select clip in timeline */ }
    }

    @ViewBuilder
    private func iconButton(systemName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
    }
}
