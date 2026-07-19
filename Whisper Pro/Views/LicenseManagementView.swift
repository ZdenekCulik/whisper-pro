import SwiftUI

struct LicenseManagementView: View {
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    private let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

    var body: some View {
        ScrollView {
            aboutCard
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 600, minHeight: 500)
    }

    private var aboutCard: some View {
        VStack(spacing: 18) {
            LicenseProMark()

            VStack(spacing: 6) {
                Text("Whisper Pro")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))

                Text(String(format: String(localized: "Version %@ (%@)"), appVersion, appBuild))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(width: 160)

            VStack(spacing: 4) {
                Text("Made by Zdeněk Čulík")
                    .font(.system(size: 13, weight: .medium))

                Text("Open source, based on VoiceInk")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(AppMaterialCardBackground(cornerRadius: 14))
    }
}

/// Shared card used both here and in onboarding (`OnboardingLicenseCards.swift`)
/// to present an activated license key.
struct LicenseActiveSummaryCard<Actions: View>: View {
    let title: String
    let subtitle: String
    let licenseKey: String
    let didCopyLicenseKey: Bool
    let onCopyLicenseKey: () -> Void
    let actions: () -> Actions
    let showsActions: Bool

    init(
        title: String,
        subtitle: String,
        licenseKey: String,
        didCopyLicenseKey: Bool,
        onCopyLicenseKey: @escaping () -> Void,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.licenseKey = licenseKey
        self.didCopyLicenseKey = didCopyLicenseKey
        self.onCopyLicenseKey = onCopyLicenseKey
        self.actions = actions
        self.showsActions = true
    }

    init(
        title: String,
        subtitle: String,
        licenseKey: String,
        didCopyLicenseKey: Bool,
        onCopyLicenseKey: @escaping () -> Void
    ) where Actions == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.licenseKey = licenseKey
        self.didCopyLicenseKey = didCopyLicenseKey
        self.onCopyLicenseKey = onCopyLicenseKey
        self.actions = { EmptyView() }
        self.showsActions = false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 18) {
                LicenseProMark()

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 28, weight: .semibold))

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            Divider()

            licenseKeyControl

            if showsActions {
                Divider()

                actions()
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppMaterialCardBackground(cornerRadius: 14))
    }

    private var licenseKeyControl: some View {
        HStack(spacing: 10) {
            Text("License Key")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .frame(width: 82, alignment: .leading)

            Button(action: onCopyLicenseKey) {
                HStack(spacing: 10) {
                    Text(maskedLicenseKey)
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                        .foregroundStyle(.primary)

                    Spacer(minLength: 10)

                    if didCopyLicenseKey {
                        CopiedStatePill()
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 42)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(didCopyLicenseKey ? AppTheme.Surface.controlActive : AppTheme.Surface.control)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            didCopyLicenseKey ? AppTheme.Border.control : AppTheme.Border.subtle,
                            lineWidth: 1
                        )
                }
                .scaleEffect(didCopyLicenseKey ? 0.998 : 1)
                .animation(.smooth(duration: 0.18), value: didCopyLicenseKey)
            }
            .buttonStyle(.plain)
            .help(didCopyLicenseKey ? "Copied" : "Copy License Key")
        }
    }

    private var maskedLicenseKey: String {
        let key = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !key.isEmpty else {
            return "•••• •••• •••• ••••"
        }

        return "•••• •••• •••• \(key.suffix(4))"
    }
}

struct LicenseProMark: View {
    var body: some View {
        StickerAchievementBadge()
            .frame(width: 92, height: 116)
    }
}

private struct CopiedStatePill: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))

            Text("Copied")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(AppTheme.Surface.subtle))
        .overlay {
            Capsule()
                .stroke(AppTheme.Border.subtle, lineWidth: 1)
        }
    }
}
