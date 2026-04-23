import SwiftUI

struct UnlockView: View {
    @EnvironmentObject var vm: TimelineViewModel

    @State private var password:        String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage:    String = ""
    @State private var isLoading:       Bool   = false

    private var isFirstLaunch: Bool { VaultManager.isFirstLaunch }

    var body: some View {
        ZStack {
            Color(hex: "18181C").ignoresSafeArea()

            VStack(spacing: 24) {
                // Icon
                Image(systemName: "waveform.badge.mic")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.accent)

                Text(isFirstLaunch ? "Create Vault Password" : "Unlock Vault")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                VStack(spacing: 12) {
                    SecureField("Master password", text: $password)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                        .onSubmit { submit() }

                    if isFirstLaunch {
                        SecureField("Confirm password", text: $confirmPassword)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.white)
                            .onSubmit { submit() }
                    }
                }
                .frame(width: 280)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Color(hex: "FF5C5C"))
                }

                Button(action: submit) {
                    Group {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Text(isFirstLaunch ? "Create Vault" : "Unlock")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(width: 280, height: 36)
                }
                .buttonStyle(.plain)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.white)
                .disabled(password.isEmpty || isLoading)
            }
            .padding(48)
        }
    }

    private func submit() {
        errorMessage = ""
        guard !password.isEmpty else { return }

        if isFirstLaunch && password != confirmPassword {
            errorMessage = "Passwords don't match."
            return
        }

        isLoading = true
        Task {
            do {
                try vm.unlock(password: password)
            } catch {
                errorMessage = "Could not unlock vault: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
