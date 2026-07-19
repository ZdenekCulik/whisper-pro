import SwiftUI
import AppKit

struct OnboardingSonioxSetupScreen: View {
    let contentMaxWidth: CGFloat
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkipConfirmed: () -> Void
    let onAppear: () -> Void

    @State private var isConnected = false
    @State private var isShowingSkipWarning = false

    var body: some View {
        OnboardingStepScreen(
            stage: .model,
            contentMaxWidth: contentMaxWidth
        ) {
            VStack(alignment: .leading, spacing: 12) {
                SonioxSetupLinkStepRow(
                    number: 1,
                    title: "Create a Soniox account",
                    description: "Sign up for a free Soniox account to get an API key.",
                    buttonTitle: "Open Soniox",
                    url: URL(string: "https://console.soniox.com")!
                )

                SonioxSetupLinkStepRow(
                    number: 2,
                    title: "Add credit",
                    description: "Top up $5 in Billing — that covers roughly 2+ months of daily dictation.",
                    buttonTitle: "Open Billing",
                    url: URL(string: "https://console.soniox.com/billing")!
                )

                SonioxConnectStepRow(isConnected: $isConnected)
            }
        } bottomBar: {
            OnboardingBottomBar(
                leadingTitle: "Back",
                primaryTitle: isConnected ? "Continue" : "Skip for now",
                isPrimaryEnabled: true,
                onLeading: onBack,
                onPrimary: {
                    if isConnected {
                        onContinue()
                    } else {
                        isShowingSkipWarning = true
                    }
                }
            )
        }
        .alert("Skip Soniox setup?", isPresented: $isShowingSkipWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Skip for now", role: .destructive) {
                onSkipConfirmed()
            }
        } message: {
            Text("Dictation won't work until you connect a transcription provider. You can set this up anytime from Settings.")
        }
        .onAppear {
            isConnected = APIKeyManager.shared.hasAPIKey(forProvider: sonioxProviderKey)
            onAppear()
        }
    }

    private var sonioxProviderKey: String {
        CloudProviderRegistry.provider(for: .soniox)?.providerKey ?? "Soniox"
    }
}

private struct SonioxNumberBadge: View {
    let number: Int

    var body: some View {
        Text("\(number)")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.Text.primary)
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(AppTheme.Surface.controlActive)
            )
    }
}

private struct SonioxOpenLinkButton: View {
    let title: String
    let url: URL

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 5) {
                Text(title)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(AppTheme.Text.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(AppTheme.Surface.controlActive))
        }
        .buttonStyle(.plain)
    }
}

private struct SonioxSetupLinkStepRow: View {
    let number: Int
    let title: String
    let description: String
    let buttonTitle: String
    let url: URL

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SonioxNumberBadge(number: number)

            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Text.primary)

                Text(LocalizedStringKey(description))
                    .font(.system(size: 12.5))
                    .foregroundColor(AppTheme.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SonioxOpenLinkButton(title: buttonTitle, url: url)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(AppMaterialCardBackground(cornerRadius: 12))
    }
}

private struct SonioxConnectStepRow: View {
    @EnvironmentObject var transcriptionModelManager: TranscriptionModelManager
    @Binding var isConnected: Bool

    @State private var apiKey = ""
    @State private var isVerifying = false
    @State private var errorMessage: String?
    @State private var errorDetail: String?

    private var trimmedKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canConnect: Bool {
        !trimmedKey.isEmpty && !isVerifying
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SonioxNumberBadge(number: 3)

            VStack(alignment: .leading, spacing: 6) {
                Text("Connect your API key")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Text.primary)

                Text("Paste your key below to connect Whisper Pro to Soniox.")
                    .font(.system(size: 12.5))
                    .foregroundColor(AppTheme.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SonioxOpenLinkButton(
                    title: "Open API Keys",
                    url: URL(string: "https://console.soniox.com/api-keys")!
                )
                .padding(.top, 2)

                if isConnected {
                    connectedSummary
                        .padding(.top, 10)
                } else {
                    connectField
                        .padding(.top, 10)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(AppMaterialCardBackground(cornerRadius: 12))
    }

    private var connectField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField("Paste Soniox API key", text: $apiKey)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(AppTheme.Surface.control)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(AppTheme.Border.control.opacity(0.45), lineWidth: 1)
                )
                .onChange(of: apiKey) { _, _ in
                    errorMessage = nil
                    errorDetail = nil
                }

            HStack(alignment: .top, spacing: 12) {
                statusLine

                Spacer(minLength: 12)

                Button(action: connect) {
                    HStack(spacing: 6) {
                        if isVerifying {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(isVerifying ? LocalizedStringKey("Connecting...") : LocalizedStringKey("Connect"))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(canConnect ? AppTheme.Action.primaryForeground : AppTheme.Action.disabledForeground)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(canConnect ? AppTheme.Action.primaryFill : AppTheme.Action.disabledFill)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canConnect)
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if let errorMessage {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.Status.error)
                        .padding(.top, 1)

                    Text(errorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Status.error)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let errorDetail {
                    Text(errorDetail)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Status.error.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 19)
                }
            }
        } else {
            Text("Connect to continue.")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Text.secondary)
        }
    }

    private var connectedSummary: some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Status.positive)

            Text("Connected")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.Text.primary)
        }
    }

    private func connect() {
        let key = trimmedKey
        guard !key.isEmpty, let provider = CloudProviderRegistry.provider(for: .soniox) else { return }

        isVerifying = true
        errorMessage = nil
        errorDetail = nil

        Task {
            let result = await provider.verifyAPIKey(key)

            await MainActor.run {
                isVerifying = false

                guard result.isValid else {
                    errorMessage = String(localized: "Could not verify this API key. Check the key and try again.")
                    errorDetail = result.errorMessage
                    return
                }

                guard APIKeyManager.shared.saveAPIKey(key, forProvider: provider.providerKey) else {
                    errorMessage = String(localized: "The key worked, but Whisper Pro could not save it securely.")
                    errorDetail = nil
                    return
                }

                transcriptionModelManager.refreshAllAvailableModels()

                let sonioxModel = transcriptionModelManager.allAvailableModels.first {
                    $0.provider == .soniox && $0.name == "stt-async-v5"
                } ?? TranscriptionModelRegistry.models.first {
                    $0.provider == .soniox && $0.name == "stt-async-v5"
                }

                if let sonioxModel {
                    transcriptionModelManager.setDefaultTranscriptionModel(sonioxModel)
                }

                apiKey = ""
                isConnected = true
            }
        }
    }
}
