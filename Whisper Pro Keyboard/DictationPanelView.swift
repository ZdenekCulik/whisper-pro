import SwiftUI

struct DictationPanelView: View {
    @ObservedObject var session: DictationSession
    let onToggle: () -> Void
    let onNextKeyboard: () -> Void

    private var isListening: Bool { session.state == .listening || session.state == .connecting }

    var body: some View {
        VStack(spacing: 12) {
            statusLine

            Button(action: onToggle) {
                Image(systemName: isListening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 96, height: 96)
                    .background(isListening ? Color.red : Color.accentColor, in: Circle())
            }
            .accessibilityLabel(isListening ? "Stop dictation" : "Start dictation")

            Button("Switch keyboard", action: onNextKeyboard)
                .font(.footnote)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch session.state {
        case .idle:
            Text("Tap to dictate").font(.footnote).foregroundStyle(.secondary)
        case .connecting:
            Text("Connecting").font(.footnote).foregroundStyle(.secondary)
        case .listening:
            Text("Listening").font(.footnote).foregroundStyle(.secondary)
        case .failed(let message):
            Text(message).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
        }
    }
}
