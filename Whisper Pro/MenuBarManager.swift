import SwiftUI
import SwiftData
import AppKit
import OSLog

class MenuBarManager: ObservableObject {
    private let logger = Logger(subsystem: "com.prakashjoshipax.whisperpro", category: "MenuBarManager")
    @Published var isMenuBarOnly: Bool {
        didSet {
            UserDefaults.standard.set(isMenuBarOnly, forKey: "IsMenuBarOnly")
            updateAppActivationPolicy()
        }
    }

    private var modelContainer: ModelContainer?
    private var engine: WhisperProEngine?
    // Bumped on every explicit toggle so the delayed `windowDidClose` check below can
    // tell whether a fresh toggle already decided the policy since it was scheduled —
    // see windowDidClose for the race this closes.
    private var activationGeneration = 0

    init() {
        self.isMenuBarOnly = UserDefaults.standard.bool(forKey: "IsMenuBarOnly")
        updateAppActivationPolicy()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidClose),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func windowDidClose(_ notification: Notification) {
        guard isMenuBarOnly else { return }
        let generationAtSchedule = activationGeneration

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            // A fresh toggle (either direction) since this closure was scheduled
            // already decided the policy — applying this stale check on top of it is
            // exactly the race that made "Hide Dock Icon" flaky. Re-check both the
            // generation and the current setting before touching the policy.
            guard self.activationGeneration == generationAtSchedule, self.isMenuBarOnly else { return }

            let hasVisibleWindows = NSApplication.shared.windows.contains {
                $0.isVisible && $0.level == .normal && !$0.styleMask.contains(.nonactivatingPanel)
            }
            if !hasVisibleWindows && NSApplication.shared.activationPolicy() != .accessory {
                self.logger.notice("windowDidClose: no visible windows, switching to .accessory policy")
                NSApplication.shared.setActivationPolicy(.accessory)
            }
        }
    }

    func configure(modelContainer: ModelContainer, engine: WhisperProEngine) {
        self.modelContainer = modelContainer
        self.engine = engine
    }
    
    func toggleMenuBarOnly() {
        isMenuBarOnly.toggle()
    }
    
    func applyActivationPolicy() {
        updateAppActivationPolicy()
    }
    
    func focusMainWindow() {
        NSApplication.shared.setActivationPolicy(.regular)
        logger.notice("focusMainWindow: activation policy set to .regular")
        if WindowManager.shared.showMainWindow() == nil {
            logger.error("focusMainWindow: showMainWindow returned nil")
        }
    }
    
    private func updateAppActivationPolicy() {
        let applyPolicy = { [weak self] in
            guard let self else { return }
            self.activationGeneration &+= 1
            let application = NSApplication.shared
            if self.isMenuBarOnly {
                self.logger.notice("updateAppActivationPolicy: switching to .accessory (dock icon hidden)")
                application.setActivationPolicy(.accessory)
                WindowManager.shared.hideMainWindow()
            } else {
                self.logger.notice("updateAppActivationPolicy: switching to .regular (dock icon visible)")
                // Order matters: activationPolicy must flip to .regular before activate(),
                // and activate() must run even if there's currently no main window to
                // show — otherwise the dock icon can reappear without the app actually
                // becoming frontmost/focusable, which read as "the toggle doesn't work".
                application.setActivationPolicy(.regular)
                application.activate(ignoringOtherApps: true)
                if WindowManager.shared.showMainWindow() == nil {
                    self.logger.error("updateAppActivationPolicy: no main window available to show")
                }
            }
        }

        if Thread.isMainThread {
            applyPolicy()
        } else {
            DispatchQueue.main.async(execute: applyPolicy)
        }
    }
    
    func openMainWindowAndNavigate(to destination: String) {
        logger.notice("openMainWindowAndNavigate: requested destination=\(destination, privacy: .public), isMenuBarOnly=\(self.isMenuBarOnly, privacy: .public)")

        NSApplication.shared.setActivationPolicy(.regular)
        logger.notice("openMainWindowAndNavigate: activation policy set to .regular")

        guard WindowManager.shared.showMainWindow() != nil else {
            logger.error("openMainWindowAndNavigate: showMainWindow returned nil — cannot navigate to \(destination, privacy: .public)")
            return
        }

        logger.notice("openMainWindowAndNavigate: window shown, posting navigation notification for \(destination, privacy: .public)")

        // Post a notification to navigate to the desired destination
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            NotificationCenter.default.post(
                name: .navigateToDestination,
                object: nil,
                userInfo: ["destination": destination]
            )
            self?.logger.notice("openMainWindowAndNavigate: navigation notification posted for \(destination, privacy: .public)")
        }
    }

    func openHistoryWindow() {
        guard let modelContainer = modelContainer,
              let engine = engine else {
            logger.error("openHistoryWindow: dependencies not configured (modelContainer=\(self.modelContainer != nil, privacy: .public), engine=\(self.engine != nil, privacy: .public))")
            return
        }
        logger.notice("openHistoryWindow: opening history window")
        NSApplication.shared.setActivationPolicy(.regular)
        logger.notice("openHistoryWindow: activation policy set to .regular")
        HistoryWindowController.shared.showHistoryWindow(
            modelContainer: modelContainer,
            engine: engine
        )
    }
}
