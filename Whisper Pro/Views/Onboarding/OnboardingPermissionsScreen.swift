import SwiftUI

struct OnboardingPermissionsScreen: View {
    let contentMaxWidth: CGFloat
    let isComplete: Bool
    let activePermission: OnboardingPermissionKind
    let hasRequestedScreenRecording: Bool
    let hasRequestedAccessibility: Bool
    let stepNumber: (OnboardingPermissionKind) -> Int
    let status: (OnboardingPermissionKind) -> OnboardingPermissionStatus
    let isLocked: (OnboardingPermissionKind) -> Bool
    let actionTitle: (OnboardingPermissionKind) -> String
    let onSelect: (OnboardingPermissionKind) -> Void
    let onAction: (OnboardingPermissionKind) -> Void
    let onQuit: () -> Void
    let onRecheck: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingStepScreen(
            stage: .permissions,
            contentMaxWidth: contentMaxWidth
        ) {
            permissionList
        } bottomBar: {
            OnboardingBottomBar(
                leadingTitle: "Recheck",
                primaryTitle: "Continue",
                isPrimaryEnabled: isComplete,
                onLeading: onRecheck,
                onPrimary: onContinue
            )
        }
    }

    /// Shown once the user has asked for a permission that macOS still reports as
    /// missing. For Accessibility that almost always means a stale entry in the
    /// list: the toggle is on, but it points at an older copy of the app, so
    /// flipping it does nothing until the entry is removed and re-added.
    private func hint(for permission: OnboardingPermissionKind) -> PermissionStepHint? {
        guard !status(permission).isGranted else { return nil }

        switch permission {
        case .accessibility where hasRequestedAccessibility:
            return PermissionStepHint(
                text: String(localized: "Toggle already on but nothing happens? Select Whisper Pro in the list, remove it with the minus button, then click Allow again."),
                showsQuitAction: false
            )
        case .screenRecording where hasRequestedScreenRecording:
            return PermissionStepHint(
                text: String(localized: "Restart Whisper Pro after enabling Screen Recording."),
                showsQuitAction: true
            )
        default:
            return nil
        }
    }

    private var permissionList: some View {
        VStack(spacing: 10) {
            ForEach(OnboardingPermissionKind.allCases) { permission in
                PermissionStepRow(
                    stepNumber: stepNumber(permission),
                    descriptor: permission.descriptor,
                    status: status(permission),
                    isActive: !isComplete && activePermission == permission,
                    isLocked: isLocked(permission),
                    hint: hint(for: permission),
                    actionTitle: actionTitle(permission),
                    onSelect: {
                        guard !isLocked(permission) else { return }
                        onSelect(permission)
                    },
                    onAction: {
                        onAction(permission)
                    },
                    onQuit: onQuit
                )
            }
        }
    }
}
