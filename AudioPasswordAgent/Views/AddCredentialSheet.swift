import SwiftUI
import UniformTypeIdentifiers

struct AddCredentialSheet: View {
    @EnvironmentObject var vm: TimelineViewModel
    @Environment(\.dismiss) var dismiss

    @State private var service:        String = ""
    @State private var username:       String = ""
    @State private var password:       String = ""
    @State private var showPassword:   Bool   = false
    @State private var trackName:      String = ""
    @State private var carrierURL:     URL?   = nil
    @State private var errorMessage:   String = ""
    @State private var isSaving:       Bool   = false
    @State private var showFilePicker: Bool   = false

    private var existingTracks: [String] {
        vm.tracks.map(\.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.1))
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    credentialFields
                    trackField
                    carrierField
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color(hex: "FF5C5C"))
                    }
                }
                .padding(20)
            }
            Divider().background(Color.white.opacity(0.1))
            actionBar
        }
        .frame(width: 400)
        .background(Color(hex: "1E1E22"))
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.audio, UTType(filenameExtension: "wav")!],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result {
                carrierURL = urls.first
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Add Credential")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Fields

    private var credentialFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Credential")
            field(placeholder: "Service  (e.g. GitHub)", text: $service)
            field(placeholder: "Username / email", text: $username)
            HStack(spacing: 8) {
                if showPassword {
                    field(placeholder: "Password", text: $password)
                } else {
                    SecureField("Password", text: $password)
                        .textFieldStyle(.plain)
                        .padding(9)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .foregroundStyle(.white)
                }
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var trackField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Track / Folder")
            HStack(spacing: 8) {
                field(placeholder: "Track name (e.g. Work)", text: $trackName)
                if !existingTracks.isEmpty {
                    Menu {
                        ForEach(existingTracks, id: \.self) { name in
                            Button(name) { trackName = name }
                        }
                    } label: {
                        Image(systemName: "chevron.down.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            Text("Leave blank to use General track")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.3))
        }
    }

    private var carrierField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Carrier WAV")
            HStack(spacing: 10) {
                if let url = carrierURL {
                    Text(url.lastPathComponent)
                        .font(AppTheme.Font.label)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("No file selected")
                        .font(AppTheme.Font.label)
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                Spacer()
                Button("Choose…") { showFilePicker = true }
                    .buttonStyle(OutlineButtonStyle())
            }
            Text("A copy of this WAV will be saved to the vault with your credential embedded.")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.3))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(OutlineButtonStyle())
            Button(action: save) {
                Group {
                    if isSaving {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .frame(width: 64, height: 28)
            }
            .buttonStyle(.plain)
            .background(canSave ? AppTheme.accent : Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .foregroundStyle(.white)
            .disabled(!canSave || isSaving)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !service.isEmpty && !username.isEmpty && !password.isEmpty && carrierURL != nil
    }

    private func save() {
        guard let source = carrierURL else { return }
        errorMessage = ""
        isSaving = true

        Task {
            // fileImporter returns a security-scoped URL — must unlock before reading
            let accessed = source.startAccessingSecurityScopedResource()
            defer { if accessed { source.stopAccessingSecurityScopedResource() } }

            var tempURL: URL? = nil
            defer { tempURL.map { try? FileManager.default.removeItem(at: $0) } }

            do {
                // Convert to PCM WAV if needed (handles CAF, AIFF, compressed WAV, etc.)
                let carrier: URL
                do {
                    carrier = try AudioConverter.convertToPCMWAV(from: source)
                    tempURL = carrier
                } catch {
                    errorMessage = "Could not convert audio: \(error.localizedDescription)"
                    isSaving = false
                    return
                }

                let folder = trackName.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "General"
                    : trackName.trimmingCharacters(in: .whitespaces)
                try vm.addCredential(
                    service: service,
                    username: username,
                    password: password,
                    carrierURL: carrier,
                    folderName: folder
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    @ViewBuilder
    private func field(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .padding(9)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .foregroundStyle(.white)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.4))
            .tracking(1)
    }
}

// MARK: - Outline button style

private struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Font.label)
            .foregroundStyle(Color.white.opacity(configuration.isPressed ? 0.5 : 0.7))
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
