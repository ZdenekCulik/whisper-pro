import SwiftUI

struct Variant9View: View {
    let context: WidgetVariantContext

    private var combinedText: String {
        let parts = [context.committed, context.partial].filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }

    var body: some View {
        HStack(spacing: 6) {
            AudioVisualizer(
                audioMeter: context.audioMeter,
                color: Color(white: 0.75),
                isActive: context.isRecording
            )
            .frame(width: 40, height: 16)
            .clipped()
            .scaleEffect(x: 1, y: 0.55, anchor: .center)

            if context.hasText {
                Text(combinedText)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(white: 0.82))
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(context.isRecording ? "listening…" : "ready")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(white: 0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 180, height: 28)
        .background(Color(white: 0.08))
        .clipShape(Capsule())
    }
}
