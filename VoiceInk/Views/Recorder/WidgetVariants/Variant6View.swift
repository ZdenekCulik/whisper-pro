import SwiftUI

// MARK: - Variant 6 — "Tall Box"
// Same dark-pill aesthetic as the base widget but with a taller transcript area
// (~5 lines, 95pt) implemented via a custom scroll view to bypass LiveTranscriptView's
// hardcoded 56pt frame.

private struct TallTranscriptView: View {
    let committed: String
    let partial: String

    private var styledText: Text {
        let committedPart = Text(committed).foregroundColor(.white)
        guard !partial.isEmpty else { return committedPart }
        let spacer = committed.isEmpty ? Text("") : Text(" ")
        return committedPart + spacer + Text(partial).foregroundColor(.white.opacity(0.4))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                styledText
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .id("bottom")
            }
            .frame(height: 95)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.10),
                        .init(color: .black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .onChange(of: committed) { proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: partial)   { proxy.scrollTo("bottom", anchor: .bottom) }
        }
        .transaction { $0.disablesAnimations = true }
    }
}

struct Variant6View: View {
    let context: WidgetVariantContext

    var body: some View {
        VStack(spacing: 0) {
            if context.hasText {
                TallTranscriptView(
                    committed: context.committed,
                    partial: context.partial
                )

                Divider()
                    .background(Color.white.opacity(0.12))
            }

            RecorderStatusDisplay(
                currentState: context.recordingState,
                audioMeter: context.audioMeter
            )
            .frame(height: 40)
            .padding(.horizontal, 4)
        }
        .frame(width: 320)
        .background(Color.black)
        .clipShape(
            RoundedRectangle(
                cornerRadius: context.hasText ? 16 : 22,
                style: .continuous
            )
        )
        .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 8)
    }
}
