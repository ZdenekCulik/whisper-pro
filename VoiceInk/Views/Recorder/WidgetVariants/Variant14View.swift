import SwiftUI

struct Variant14View: View {
    let context: WidgetVariantContext
    @State private var isPulsing = false

    private var combinedText: String {
        "\(context.committed) \(context.partial)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: 6) {
                indicator

                Text(combinedText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .animation(.easeInOut(duration: 0.15), value: combinedText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: 220, height: 32)
            .background(Color.black.opacity(0.75))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
        }
        .frame(width: 540, height: 430, alignment: .bottom)
    }

    @ViewBuilder
    private var indicator: some View {
        if context.isRecording {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing ? 1.4 : 1.0)
                .animation(
                    .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                    value: isPulsing
                )
                .onAppear {
                    isPulsing = true
                }
                .onDisappear {
                    isPulsing = false
                }
                .frame(width: 24, height: 16)
        } else {
            AudioVisualizer(
                audioMeter: context.audioMeter,
                color: .white,
                isActive: false
            )
            .frame(width: 24, height: 16)
            .clipped()
        }
    }
}
