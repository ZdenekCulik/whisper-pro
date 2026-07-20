import AVFoundation
import AppKit
import ApplicationServices

@MainActor
final class OnboardingPermissionController {
    private unowned let coordinator: OnboardingCoordinator

    // When this session asked for Accessibility (nil = not requested in this launch). In-memory
    // only: the persisted coordinator.hasRequestedAccessibility covers prior launches.
    private var accessibilityRequestedAt: Date?

    init(coordinator: OnboardingCoordinator) {
        self.coordinator = coordinator
    }

    func stepNumber(for permission: OnboardingPermissionKind) -> Int {
        guard let index = OnboardingPermissionKind.allCases.firstIndex(of: permission) else {
            return 1
        }

        return index + 1
    }

    func status(for permission: OnboardingPermissionKind) -> OnboardingPermissionStatus {
        coordinator.permissionStatuses[permission] ?? diagnose(permission)
    }

    func setActivePermission(_ permission: OnboardingPermissionKind) {
        coordinator.storedActivePermission = permission.rawValue
    }

    func refreshPermissionStatuses() {
        let diagnosedStatuses = Dictionary(
            uniqueKeysWithValues: OnboardingPermissionKind.allCases.map { permission in
                (permission, diagnose(permission))
            }
        )

        coordinator.permissionStatuses = diagnosedStatuses
        reconcileActivePermission(with: diagnosedStatuses)
    }

    func reconcileActivePermission(with statuses: [OnboardingPermissionKind: OnboardingPermissionStatus]) {
        if let storedPermission = OnboardingPermissionKind(rawValue: coordinator.storedActivePermission),
           !isLocked(storedPermission, statuses: statuses),
           !storedPermission.isRequired || !(statuses[storedPermission] ?? diagnose(storedPermission)).isGranted {
            return
        }

        if let firstMissingRequired = OnboardingPermissionKind.required.first(where: {
            !(statuses[$0] ?? diagnose($0)).isGranted
        }) {
            setActivePermission(firstMissingRequired)
            return
        }

        if let lastPermission = OnboardingPermissionKind.allCases.last {
            setActivePermission(lastPermission)
        }
    }

    func isLocked(_ permission: OnboardingPermissionKind) -> Bool {
        isLocked(permission, statuses: coordinator.permissionStatuses)
    }

    func isLocked(
        _ permission: OnboardingPermissionKind,
        statuses: [OnboardingPermissionKind: OnboardingPermissionStatus]
    ) -> Bool {
        // A permission the user already granted is never locked, otherwise the row
        // reads "Locked" next to its own green checkmark.
        if (statuses[permission] ?? diagnose(permission)).isGranted {
            return false
        }

        guard let index = OnboardingPermissionKind.allCases.firstIndex(of: permission) else {
            return false
        }

        let priorRequiredPermissions = OnboardingPermissionKind.allCases[..<index].filter(\.isRequired)
        return priorRequiredPermissions.contains { !(statuses[$0] ?? diagnose($0)).isGranted }
    }

    func actionTitle(for permission: OnboardingPermissionKind) -> String {
        let permissionStatus = status(for: permission)

        if permissionStatus.isGranted {
            return String(localized: "Done")
        }

        switch permission {
        case .microphone:
            return permissionStatus.requiresSettings ? String(localized: "Open Settings") : String(localized: "Allow")
        case .accessibility, .screenRecording:
            return String(localized: "Allow")
        }
    }

    func performAction(for permission: OnboardingPermissionKind) {
        guard !isLocked(permission) else { return }

        setActivePermission(permission)

        if status(for: permission).isGranted {
            advanceFrom(permission)
            return
        }

        switch permission {
        case .microphone:
            handleMicrophoneAction()
        case .accessibility:
            requestAccessibility()
        case .screenRecording:
            requestScreenRecording()
        }
    }

    func cancelRefreshTask() {
        coordinator.refreshTask?.cancel()
        coordinator.refreshTask = nil
    }

    private func diagnose(_ permission: OnboardingPermissionKind) -> OnboardingPermissionStatus {
        switch permission {
        case .microphone:
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                return .granted
            case .denied:
                return .denied
            case .restricted:
                return .restricted
            case .notDetermined:
                return .needsAccess
            @unknown default:
                return .unknown
            }

        case .accessibility:
            return AXIsProcessTrusted() ? .granted : .needsAccess

        case .screenRecording:
            return CGPreflightScreenCaptureAccess() ? .granted : .needsAccess
        }
    }

    private func handleMicrophoneAction() {
        if status(for: .microphone).requiresSettings {
            openPrivacySettings(.microphone)
            startPollingPermissionStatus()
            return
        }

        AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshPermissionStatuses()
                self?.startPollingPermissionStatus()
            }
        }
    }

    /// macOS keeps the Accessibility grant tied to the exact code signature it saw
    /// when the entry was created. Rebuilding or replacing the app changes that
    /// signature, so the switch in System Settings stays on while the running app
    /// is not actually trusted, and no amount of toggling fixes it. Dropping our
    /// own entry lets the next prompt re-create it against the current signature.
    func repairAccessibility() {
        AccessibilityRepair.resetAndReprompt { [weak self] in
            guard let self else { return }
            self.refreshPermissionStatuses()
            self.requestAccessibility()
        }
    }

    /// Whether to surface the "stale Accessibility entry, reset it" repair hint. Gated so it
    /// never appears the instant the user clicks Allow (which would let them wipe a grant they
    /// just made) — only once the request is genuinely stuck.
    var shouldShowAccessibilityRepairHint: Bool {
        Self.shouldShowAccessibilityRepairHint(
            hasRequested: coordinator.hasRequestedAccessibility,
            isGranted: status(for: .accessibility).isGranted,
            requestedThisSessionAt: accessibilityRequestedAt,
            now: Date()
        )
    }

    /// Pure decision behind `shouldShowAccessibilityRepairHint`, split out for unit testing.
    static func shouldShowAccessibilityRepairHint(
        hasRequested: Bool,
        isGranted: Bool,
        requestedThisSessionAt: Date?,
        now: Date,
        staleAfter: TimeInterval = 15
    ) -> Bool {
        guard hasRequested, !isGranted else { return false }
        guard let requestedAt = requestedThisSessionAt else {
            // Persisted flag but no request this session = the request happened on a previous
            // launch (classic stale-signature case), so surface the repair right away.
            return true
        }
        // Requested this session: only once it is clearly stuck, not on the first click.
        return now.timeIntervalSince(requestedAt) >= staleAfter
    }

    private func requestAccessibility() {
        coordinator.hasRequestedAccessibility = true
        accessibilityRequestedAt = Date()
        AccessibilityRepair.prompt()
        openPrivacySettings(.accessibility)
        startPollingPermissionStatus()
    }

    private func requestScreenRecording() {
        coordinator.hasRequestedScreenRecording = true
        startPollingPermissionStatus()

        Task { @MainActor [weak self] in
            guard let self else { return }

            let isGranted = await ScreenCaptureService.requestScreenCapturePermissionRegistration()
            refreshPermissionStatuses()

            if !isGranted {
                openPrivacySettings(.screenRecording)
            }
        }
    }

    private func advanceFrom(_ permission: OnboardingPermissionKind) {
        guard let currentIndex = OnboardingPermissionKind.allCases.firstIndex(of: permission) else {
            refreshPermissionStatuses()
            return
        }

        let nextPermissions = OnboardingPermissionKind.allCases.dropFirst(currentIndex + 1)
        if let nextRequired = nextPermissions.first(where: { $0.isRequired && !status(for: $0).isGranted }) {
            setActivePermission(nextRequired)
            return
        }

        refreshPermissionStatuses()
    }

    private func startPollingPermissionStatus() {
        cancelRefreshTask()
        coordinator.refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for _ in 0..<60 {
                guard !Task.isCancelled else { return }
                refreshPermissionStatuses()

                if coordinator.requiredPermissionsGranted {
                    return
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func openPrivacySettings(_ pane: PrivacySettingsPane) {
        guard let url = URL(string: pane.urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
