import SwiftUI
import AppKit

class MiniRecorderPanel: NSPanel {
    // Never become the key/main window: the recorder pops up over whatever the user
    // was typing in (a chat box, etc.). Stealing key status drops their text field's
    // focus, so Enter after dictation wouldn't land there. Buttons inside a
    // nonactivating panel still receive clicks, and the global CGEvent tap
    // (ShortcutMonitor) catches Escape / mode digits without needing key status.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        configurePanel()
    }
    
    private func configurePanel() {
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovable = true
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        standardWindowButton(.closeButton)?.isHidden = true
    }
    
    static func calculateWindowMetrics() -> NSRect {
        let width: CGFloat = 540
        let height: CGFloat = 430

        guard let screen = NSScreen.main else {
            return NSRect(x: 0, y: 0, width: width, height: height)
        }

        // Host stays large enough for assistant output; SwiftUI controls the visible mini width.
        let padding: CGFloat = 24

        let visibleFrame = screen.visibleFrame
        let centerX = visibleFrame.midX
        let xPosition = centerX - (width / 2)
        let yPosition = visibleFrame.minY + padding

        return NSRect(
            x: xPosition,
            y: yPosition,
            width: width,
            height: height
        )
    }

    func show() {
        let metrics = MiniRecorderPanel.calculateWindowMetrics()
        setFrame(metrics, display: true)
        // orderFrontRegardless (not makeKeyAndOrderFront) so the panel shows without
        // taking focus away from the user's current text field.
        orderFrontRegardless()
    }
    
} 
