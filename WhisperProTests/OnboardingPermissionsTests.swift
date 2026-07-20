import Testing
import SwiftUI
import AppKit
@testable import WhisperPro

/// Covers the stuck-permissions state from the friend's first run: Accessibility
/// switched on in System Settings, but macOS still reporting it as missing, so
/// the flow dead-ended with a disabled Continue and a granted step labelled
/// "Locked".
@Suite(.serialized)
@MainActor
struct OnboardingPermissionsTests {

    private func makeController() -> OnboardingPermissionController {
        OnboardingCoordinator(defaults: UserDefaults(suiteName: "OnboardingPermissionsTests")!).permissions
    }

    @Test func grantedPermissionIsNeverLocked() {
        let controller = makeController()
        let statuses: [OnboardingPermissionKind: OnboardingPermissionStatus] = [
            .microphone: .granted,
            .accessibility: .needsAccess,
            .screenRecording: .granted
        ]

        // Accessibility is still missing, but Screen Recording is already granted:
        // it must not read as locked behind the step the user is stuck on.
        #expect(controller.isLocked(.screenRecording, statuses: statuses) == false)
    }

    @Test func pendingPermissionStaysLockedBehindMissingRequiredStep() {
        let controller = makeController()
        let statuses: [OnboardingPermissionKind: OnboardingPermissionStatus] = [
            .microphone: .needsAccess,
            .accessibility: .needsAccess,
            .screenRecording: .needsAccess
        ]

        #expect(controller.isLocked(.microphone, statuses: statuses) == false)
        #expect(controller.isLocked(.accessibility, statuses: statuses) == true)
        #expect(controller.isLocked(.screenRecording, statuses: statuses) == true)
    }

    /// Renders the exact state from the bug report plus the recovered state, so
    /// the rows can be reviewed as images without walking the whole flow.
    @Test func renderStuckAndRecoveredStates() throws {
        try render(
            accessibility: .needsAccess,
            screenRecording: .granted,
            to: "/tmp/onboarding-permissions-stuck.png"
        )

        try render(
            accessibility: .granted,
            screenRecording: .granted,
            to: "/tmp/onboarding-permissions-recovered.png"
        )
    }

    /// The final screen now spells out the dictation hotkey, which used to live
    /// only in Settings.
    @Test func renderTrustScreenWithShortcut() throws {
        let screen = OnboardingTrustScreen(contentMaxWidth: 720, onBack: {}, onContinue: {})
            .environmentObject(ThemeManager())
            .environment(\.colorScheme, .dark)
            .frame(width: 860, height: 720)
            .background(Color(red: 0.075, green: 0.08, blue: 0.09))

        let renderer = ImageRenderer(content: screen)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "snapshot", code: 1)
        }
        try png.write(to: URL(fileURLWithPath: "/tmp/onboarding-trust.png"))
    }

    private func render(
        accessibility: OnboardingPermissionStatus,
        screenRecording: OnboardingPermissionStatus,
        to path: String
    ) throws {
        let statuses: [OnboardingPermissionKind: OnboardingPermissionStatus] = [
            .microphone: .granted,
            .accessibility: accessibility,
            .screenRecording: screenRecording
        ]
        let controller = makeController()
        let isComplete = OnboardingPermissionKind.required.allSatisfy { statuses[$0]?.isGranted == true }

        let screen = OnboardingPermissionsScreen(
            contentMaxWidth: 520,
            isComplete: isComplete,
            activePermission: isComplete ? .screenRecording : .accessibility,
            hasRequestedScreenRecording: false,
            hasRequestedAccessibility: true,
            stepNumber: { controller.stepNumber(for: $0) },
            status: { statuses[$0] ?? .needsAccess },
            isLocked: { controller.isLocked($0, statuses: statuses) },
            actionTitle: { _ in "Allow" },
            onSelect: { _ in },
            onAction: { _ in },
            onQuit: {},
            onRepairAccessibility: {},
            onRecheck: {},
            onContinue: {}
        )
            .environmentObject(ThemeManager())
            .environment(\.colorScheme, .dark)
            .frame(width: 720, height: 520)
            .background(Color(red: 0.075, green: 0.08, blue: 0.09))

        let renderer = ImageRenderer(content: screen)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "snapshot", code: 1)
        }
        try png.write(to: URL(fileURLWithPath: path))
    }
}
