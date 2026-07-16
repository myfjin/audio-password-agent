import SwiftUI
import AppKit

struct AddCredentialView: View {
    @EnvironmentObject var vm: TimelineViewModel
    @Environment(\.dismiss) var dismiss

    @State private var service:  String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var confirm:  String = ""
    @State private var folder:   String = ""
    @State private var sourceWAV: URL?  = nil
    @State private var isStoring: Bool  = false
    @State private var errorMessage: String? = nil
    @State private var showPassword: Bool = false

    private var vaultFolders: [String] {
        let fm    = FileManager.default
        let vault = VaultManager.vaultDirectory
        let items = (try? fm.contentsOfDirectory(
            at: vault, includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []
        let dirs = items
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map(\.lastPathComponent)
            .sorted()
        return dirs.isEmpty ? ["General"] : dirs
    }

    private var canStore: Bool {
        !service.isEmpty && !username.isEmpty && !password.isEmpty
            && password == confirm && sourceWAV != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.1))
            ScrollView {
                formContent
            }
            Divider().background(Color.white.opacity(0.1))
            footer
        }
        .frame(width: 400)
        .background(AppTheme.Dark.editorBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 12)
        .onAppear {
            if folder.isEmpty, let first = vaultFolders.first { folder = first }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.accent)
            Text("Store Credential")
                .font(AppTheme.Font.editorTitle)
                .foregroundStyle(.white)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Form

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Credential")
            field(label: "Service", placeholder: "GitHub", text: $service)
            field(label: "Username", placeholder: "me@example.com", text: $username)

            // Password row with eye toggle
            VStack(alignment: .leading, spacing: 4) {
                Text("Password")
                    .font(AppTheme.Font.label)
                    .foregroundStyle(Color.white.opacity(0.45))
                HStack {
                    Group {
                        if showPassword {
                            TextField("", text: $password)
                        } else {
                            SecureField("", text: $password)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(AppTheme.Font.label)
                    .foregroundStyle(.white)

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Confirm password
            VStack(alignment: .leading, spacing: 4) {
                Text("Confirm")
                    .font(AppTheme.Font.label)
                    .foregroundStyle(Color.white.opacity(0.45))
                SecureField("", text: $confirm)
                    .textFieldStyle(.plain)
                    .font(AppTheme.Font.label)
                    .foregroundStyle(confirm.isEmpty || confirm == password ? Color.white : Color(hex: "E03030"))
                    .padding(8)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Divider().background(Color.white.opacity(0.08))
            sectionLabel("Audio Carrier")

            // Source WAV picker
            VStack(alignment: .leading, spacing: 4) {
                Text("WAV file")
                    .font(AppTheme.Font.label)
                    .foregroundStyle(Color.white.opacity(0.45))
                Button {
                    pickSourceWAV()
                } label: {
                    HStack {
                        Image(systemName: "waveform")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.accent)
                        Text(sourceWAV?.lastPathComponent ?? "Choose carrier WAV…")
                            .font(AppTheme.Font.label)
                            .foregroundStyle(sourceWAV != nil ? Color.white : Color.white.opacity(0.35))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            // Vault folder picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Track folder")
                    .font(AppTheme.Font.label)
                    .foregroundStyle(Color.white.opacity(0.45))
                folderPicker
            }

            if let err = errorMessage {
                Text(err)
                    .font(AppTheme.Font.label)
                    .foregroundStyle(Color(hex: "E03030"))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "E03030").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var folderPicker: some View {
        let folders = vaultFolders
        Menu {
            ForEach(folders, id: \.self) { name in
                Button(name) { folder = name }
            }
            Divider()
            Button("New folder…") { promptNewFolder() }
        } label: {
            HStack {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.accent)
                Text(folder.isEmpty ? "Select folder" : folder)
                    .font(AppTheme.Font.label)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(8)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.3))
            .tracking(1.5)
    }

    @ViewBuilder
    private func field(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppTheme.Font.label)
                .foregroundStyle(Color.white.opacity(0.45))
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(AppTheme.Font.label)
                .foregroundStyle(.white)
                .padding(8)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .font(AppTheme.Font.label)
                .foregroundStyle(Color.white.opacity(0.45))

            Spacer()

            Button {
                storeCredential()
            } label: {
                HStack(spacing: 6) {
                    if isStoring {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.white)
                    }
                    Text("Store in WAV")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(canStore ? AppTheme.accent : Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .disabled(!canStore || isStoring)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func pickSourceWAV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.wav]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a carrier WAV file (credentials will be embedded inside it)"
        panel.prompt = "Choose"
        if panel.runModal() == .OK {
            sourceWAV = panel.url
        }
    }

    private func promptNewFolder() {
        let alert = NSAlert()
        alert.messageText = "New Track Folder"
        alert.informativeText = "Enter a name for the new vault subfolder:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = tf
        alert.window.initialFirstResponder = tf
        if alert.runModal() == .alertFirstButtonReturn {
            let name = tf.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            let newDir = VaultManager.vaultDirectory.appendingPathComponent(name)
            try? FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: true)
            folder = name
        }
    }

    private func storeCredential() {
        guard let source = sourceWAV else { return }
        errorMessage = nil
        isStoring    = true

        let targetFolder: URL
        if folder.isEmpty || folder == "General" {
            targetFolder = VaultManager.vaultDirectory
        } else {
            targetFolder = VaultManager.vaultDirectory.appendingPathComponent(folder)
        }

        let outputName = "\(service.lowercased().replacingOccurrences(of: " ", with: "-")).wav"
        let output = targetFolder.appendingPathComponent(outputName)

        do {
            try vm.storeCredential(
                service:  service,
                username: username,
                password: password,
                source:   source,
                output:   output
            )
            vm.reloadTracks()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isStoring    = false
        }
    }
}
