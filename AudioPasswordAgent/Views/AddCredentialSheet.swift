import SwiftUI
import UniformTypeIdentifiers

struct AddCredentialSheet: View {
    @EnvironmentObject var vm: TimelineViewModel
    @Environment(\.dismiss) var dismiss

    @State private var service:           String          = ""
    @State private var username:          String          = ""
    @State private var password:          String          = ""
    @State private var showPassword:      Bool            = false
    @State private var trackName:         String          = ""
    @State private var carrierSelection:  CarrierSelection = .autoGenerate
    @State private var errorMessage:      String          = ""
    @State private var isSaving:          Bool            = false
    @State private var showFilePicker:    Bool            = false

    private var existingTracks: [String] { vm.tracks.map(\.name) }

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
        .frame(width: 420)
        .background(Color(hex: "1E1E22"))
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.audio, UTType(filenameExtension: "wav")!],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                carrierSelection = .custom(url)
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
                Button { showPassword.toggle() } label: {
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
            sectionLabel("Audio Carrier")
            HStack(spacing: 10) {
                // Current selection label
                HStack(spacing: 6) {
                    Image(systemName: selectionIcon)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.accent)
                    Text(carrierSelection.displayName)
                        .font(AppTheme.Font.label)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 7))

                Spacer()

                // Picker menu
                Menu {
                    Button {
                        carrierSelection = .autoGenerate
                    } label: {
                        Label("Auto-generate", systemImage: "wand.and.stars")
                    }

                    Divider()

                    ForEach(CarrierStyle.allCases, id: \.rawValue) { style in
                        Button {
                            carrierSelection = .builtIn(style)
                        } label: {
                            Label(style.displayName, systemImage: style.icon)
                        }
                    }

                    Divider()

                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Choose my own WAV…", systemImage: "folder")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Change")
                            .font(AppTheme.Font.label)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(Color.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            carrierHint
        }
    }

    @ViewBuilder
    private var carrierHint: some View {
        switch carrierSelection {
        case .autoGenerate:
            Text("A unique noise clip is generated automatically — no audio file needed.")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.3))
                .fixedSize(horizontal: false, vertical: true)
        case .builtIn(let style):
            Text("\(style.displayName) — a built-in synthetic audio clip.")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.3))
        case .custom:
            Text("Your file will be converted to PCM WAV and saved to the vault.")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.3))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectionIcon: String {
        switch carrierSelection {
        case .autoGenerate:       return "wand.and.stars"
        case .builtIn(let style): return style.icon
        case .custom:             return "waveform"
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
                        Text("Save").fontWeight(.semibold)
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
        !service.isEmpty && !username.isEmpty && !password.isEmpty
    }

    private func save() {
        errorMessage = ""
        isSaving = true

        Task {
            var tempURL: URL? = nil
            defer { tempURL.map { try? FileManager.default.removeItem(at: $0) } }

            do {
                let carrier: URL
                switch carrierSelection {
                case .autoGenerate:
                    let tmp = try CarrierLibrary.generateRandomWAV()
                    tempURL = tmp
                    carrier = tmp

                case .builtIn(let style):
                    carrier = try CarrierLibrary.wavURL(for: style)

                case .custom(let source):
                    let accessed = source.startAccessingSecurityScopedResource()
                    defer { if accessed { source.stopAccessingSecurityScopedResource() } }
                    let converted = try AudioConverter.convertToPCMWAV(from: source)
                    tempURL = converted
                    carrier = converted
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
