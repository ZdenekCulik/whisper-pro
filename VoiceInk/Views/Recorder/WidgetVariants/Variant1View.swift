import SwiftUI

// Variant V1 — "White Glass"
// A light translucent pill with strong blur, dark text, and dark waveform bars.
// Sits inside a 540×430 transparent host anchored bottom-center.
struct Variant1View: View {
    let context: WidgetVariantContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if context.hasText {
                transcriptArea
                Divider()
                    .background(Color.black.opacity(0.08))
            }
            waveformRow
        }
        .frame(width: context.hasText ? 300 : 200)
        .background(glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 1)
    }

    // MARK: - Background

    private var glassBackground: some View {
        ZStack {
            // White tint beneath the blur
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.55))
            // System blur material
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        }
    }

    // MARK: - Transcript

    private var transcriptArea: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                styledTranscript
                    .font(.system(size: 12, weight: .regular))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .id("bottom")
            }
            .frame(height: 56)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.15),
                        .init(color: .black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .onChange(of: context.committed) { proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: context.partial)   { proxy.scrollTo("bottom", anchor: .bottom) }
        }
        .transaction { $0.disablesAnimations = true }
    }

    // committed = solid black, partial = medium gray
    private var styledTranscript: Text {
        let base = Text(context.committed)
            .foregroundColor(Color.black)
        guard !context.partial.isEmpty else { return base }
        let spacer = context.committed.isEmpty ? Text("") : Text(" ")
        return base + spacer + Text(context.partial).foregroundColor(Color(white: 0.45))
    }

    // MARK: - Waveform Row

    private var waveformRow: some View {
        HStack(spacing: 0) {
            Spacer()
            if context.isRecording {
                AudioVisualizer(
                    audioMeter: context.audioMeter,
                    color: Color(white: 0.22),
                    isActive: true
                )
            } else {
                StaticVisualizer(color: Color(white: 0.30))
            }
            Spacer()
        }
        .frame(height: 44)
        .padding(.horizontal, 12)
    }
}
