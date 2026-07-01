import SwiftUI
import AppKit

/// The little correction card shown after an English dictation:
///   (handwritten) why it's like that
///   said   →   corrected (green)
struct CoachCardView: View {
    let suggestion: CoachSuggestion
    let onDismiss: () -> Void

    private let green = Color(red: 0.30, green: 0.85, blue: 0.46)

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if !suggestion.why.isEmpty {
                Text(suggestion.why)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(white: 0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(suggestion.said)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(white: 0.62))

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(white: 0.55))
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 1, y: 1)

                Text(suggestion.corrected)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(green)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.45), radius: 18, y: 7)
        .padding(12)
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
    }
}

/// Owns a lightweight floating panel that shows the coach card on
/// `.englishCoachCorrectionReady`, decoupled from the recorder so it can never
/// affect recording. Auto-dismisses after a few seconds or on tap.
@MainActor
final class CoachCardPresenter {
    static let shared = CoachCardPresenter()

    private var panel: NSPanel?
    private var windowController: NSWindowController?
    private var dismissTask: Task<Void, Never>?
    private var currentSuggestionID: UUID?
    private var observers: [NSObjectProtocol] = []

    private let cardWidth: CGFloat = 380
    private let cardHeight: CGFloat = 130
    private let autoDismissSeconds: UInt64 = 9

    private init() {}

    func start() {
        guard observers.isEmpty else { return }
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .englishCoachCorrectionReady, object: nil, queue: .main
            ) { [weak self] note in
                guard let suggestion = note.object as? CoachSuggestion else { return }
                Task { @MainActor in self?.show(suggestion) }
            }
        )
    }

    func show(_ suggestion: CoachSuggestion) {
        guard currentSuggestionID != suggestion.id else { return }

        dismiss(resetCurrentSuggestion: false)
        currentSuggestionID = suggestion.id

        let view = CoachCardView(suggestion: suggestion) { [weak self] in
            Task { @MainActor in self?.dismiss(resetCurrentSuggestion: true) }
        }
        let host = NSHostingController(rootView: view)
        let size = NSSize(width: cardWidth, height: cardHeight)
        host.view.frame = NSRect(origin: .zero, size: size)
        host.view.layoutSubtreeIfNeeded()

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.contentView = host.view

        position(panel)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil as Any?)
        panel.orderFrontRegardless()

        self.panel = panel
        self.windowController = NSWindowController(window: panel)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: (self?.autoDismissSeconds ?? 9) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.dismiss(resetCurrentSuggestion: true)
        }
    }

    private func dismiss(resetCurrentSuggestion: Bool) {
        dismissTask?.cancel()
        dismissTask = nil
        if resetCurrentSuggestion {
            currentSuggestionID = nil
        }

        guard let panel else {
            windowController = nil
            return
        }

        self.panel = nil
        windowController = nil

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.close()
        })
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSApp.keyWindow?.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(
            NSPoint(
                x: visible.midX - panel.frame.width / 2,
                y: visible.minY + 160
            )
        )
    }
}
