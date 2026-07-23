import UIKit
import SwiftUI
import Combine

final class KeyboardViewController: UIInputViewController {
    private let session = DictationSession()
    private var cancellables = Set<AnyCancellable>()

    /// What this keyboard has already typed into the document for the current partial.
    private var insertedPartial = ""

    /// Tells iOS this keyboard is dictation-capable. Without this, the system does
    /// not grant the microphone to the extension and starting the audio engine fails
    /// on a real device with CoreAudio 2003329396. Per Apple DTS guidance this
    /// override is required (alongside Full Access) for keyboard audio capture.
    override var hasDictationKey: Bool {
        get { true }
        set {}
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let panel = DictationPanelView(
            session: session,
            onToggle: { [weak self] in self?.toggle() },
            onNextKeyboard: { [weak self] in self?.advanceToNextInputMode() }
        )

        let host = UIHostingController(rootView: panel)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            view.heightAnchor.constraint(equalToConstant: 260)
        ])
        host.didMove(toParent: self)

        session.$partialText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in self?.render(text) }
            .store(in: &cancellables)

        session.$committedText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in self?.commit(text) }
            .store(in: &cancellables)
    }

    private func toggle() {
        Task { @MainActor in
            if session.state == .listening || session.state == .connecting {
                await session.stop()
            } else {
                await session.start()
            }
        }
    }

    /// Rewrites the in-progress text using the smallest possible edit.
    private func render(_ text: String) {
        let edit = TranscriptEdit.edit(from: insertedPartial, to: text)
        for _ in 0..<edit.deleteCount {
            textDocumentProxy.deleteBackward()
        }
        if !edit.insert.isEmpty {
            textDocumentProxy.insertText(edit.insert)
        }
        insertedPartial = text
    }

    /// A committed segment is final: make sure the document matches it, then
    /// forget it so the next partial starts from an empty baseline.
    private func commit(_ text: String) {
        guard !text.isEmpty else { return }
        render(text)
        textDocumentProxy.insertText(" ")
        insertedPartial = ""
    }
}
