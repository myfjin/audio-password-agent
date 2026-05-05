import SwiftUI

struct EditCredentialSheet: View {
    @EnvironmentObject var vm: TimelineViewModel
    @Environment(\.dismiss) var dismiss

    let clip: TrackClip

    @State private var service:      String
    @State private var username:     String
    @State private var password:     String = ""
    @State private var showPassword: Bool   = false
    @State private var errorMessage: String = ""
    @State private var isSaving:     Bool   = false

    init(clip: TrackClip) {
        self.clip = clip
        _service  = State(initialValue: clip.service)
        _username = State(initialValue: clip.username)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.1))
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    fields
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
        #if os(macOS)
        .frame(width: 380)
        #endif
        .background(Color(hex: "1E1E22"))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Edit Credential")
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

    private var fields: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Credential")
            field(placeholder: "Service", text: $service)
            field(placeholder: "Username / email", text: $username)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if showPassword {
                        field(placeholder: "New password", text: $password)
                    } else {
                        SecureField("New password", text: $password)
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
                Text("Leave blank to keep current password")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.3))
            }
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(EditOutlineButtonStyle())
            Button(action: save) {
                Group {
                    if isSaving {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Text("Update")
                            .fontWeight(.semibold)
                    }
                }
                .frame(width: 72, height: 28)
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

    private var canSave: Bool { !service.isEmpty && !username.isEmpty }

    private func save() {
        guard let wavPath = clip.wavFile else { return }
        errorMessage = ""
        isSaving = true

        Task {
            do {
                let newPassword = password.isEmpty
                    ? (try? vm.currentPassword(for: clip)) ?? ""
                    : password
                try vm.updateCredential(
                    wavPath: wavPath,
                    service: service,
                    username: username,
                    password: newPassword
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

private struct EditOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11))
            .foregroundStyle(Color.white.opacity(configuration.isPressed ? 0.5 : 0.7))
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
