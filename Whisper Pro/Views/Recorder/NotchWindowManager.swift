import SwiftUI
import AppKit

@MainActor
class NotchWindowManager {
    private var windowController: NSWindowController?
    private var panel: NotchRecorderPanel?
    private var hostingController: NotchRecorderHostingController<AnyView>?
    private var contentAttached = false

    private let makeView: () -> AnyView

    init(
        engine: WhisperProEngine,
        recorder: Recorder,
        assistantSession: AssistantSession,
        onRecordButtonTapped: @escaping () -> Void,
        onCloseTapped: @escaping () -> Void,
        onAssistantFollowUp: @escaping (String) -> Void
    ) {
        self.makeView = {
            AnyView(
                NotchRecorderView(
                    stateProvider: engine,
                    recorder: recorder,
                    assistantSession: assistantSession,
                    onRecordButtonTapped: onRecordButtonTapped,
                    onCloseTapped: onCloseTapped,
                    onAssistantFollowUp: onAssistantFollowUp
                )
            )
        }
    }

    func show() {
        if panel == nil { initializeWindow() }
        attachContent()
        panel?.show()
    }

    func hide() {
        panel?.orderOut(nil)
        detachContent()
    }

    func destroyWindow() {
        deinitializeWindow()
    }

    private func initializeWindow() {
        deinitializeWindow()
        let metrics = NotchRecorderPanel.calculateWindowMetrics()
        let newPanel = NotchRecorderPanel(contentRect: metrics.frame)
        let hostingController = NotchRecorderHostingController<AnyView>(rootView: AnyView(EmptyView()))
        newPanel.contentView = hostingController.view
        self.hostingController = hostingController
        panel = newPanel
        windowController = NSWindowController(window: newPanel)
    }

    /// Mount the live SwiftUI tree only while the panel is on screen; swap in EmptyView
    /// once hidden so no per-frame animation runs behind an ordered-out window.
    private func attachContent() {
        guard !contentAttached else { return }
        hostingController?.rootView = makeView()
        contentAttached = true
    }

    private func detachContent() {
        hostingController?.rootView = AnyView(EmptyView())
        contentAttached = false
    }

    private func deinitializeWindow() {
        panel?.orderOut(nil)
        windowController?.close()
        windowController = nil
        hostingController = nil
        contentAttached = false
        panel = nil
    }

}
