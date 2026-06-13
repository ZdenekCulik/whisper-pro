import SwiftUI

// Variant V7 — "Full Text"
// The transcript area grows with content up to a 300pt cap, then scrolls.
// Width 320pt, anchored bottom-center. Black rounded background, subtle top fade.
struct Variant7View: View {
    let context: WidgetVariantContext

    private let maxTextHeight: CGFloat = 300
    private let minTextHeight: CGFloat = 0
    private let waveformHeight: CGFloat = 40
    private let cornerRadius: CGFloat = 16
    private let width: CGFloat = 320

    var body: some View {
        VStack(spacing: 0) {
            if context.hasText {
                textArea
                Divider()
                    .background(Color.white.opacity(0.12))
            }
            waveformRow
        }
        .frame(width: width)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Text area

    private var textArea: some View {
        GeometryReader { geo in
            ExpandingTranscriptView(
                committed: context.committed,
                partial: context.partial,
                maxHeight: maxTextHeight
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        // cap so GeometryReader doesn't grow unbounded
        .frame(maxHeight: maxTextHeight)
    }

    // MARK: - Waveform row

    private var waveformRow: some View {
        RecorderStatusDisplay(
            currentState: context.recordingState,
            audioMeter: context.audioMeter
        )
        .frame(height: waveformHeight)
        .padding(.horizontal, 8)
    }
}

// MARK: - ExpandingTranscriptView

/// Measures the natural height of the text, then either shows it at its real
/// height (up to maxHeight) or puts it in a ScrollView once it overflows.
private struct ExpandingTranscriptView: View {
    let committed: String
    let partial: String
    let maxHeight: CGFloat

    @State private var measuredHeight: CGFloat = 0

    private var styledText: Text {
        let c = Text(committed).foregroundColor(.white)
        guard !partial.isEmpty else { return c }
        let spacer = committed.isEmpty ? Text("") : Text(" ")
        return c + spacer + Text(partial).foregroundColor(.white.opacity(0.4))
    }

    var body: some View {
        let clamped = min(measuredHeight, maxHeight)
        let needsScroll = measuredHeight > maxHeight

        ZStack(alignment: .bottom) {
            // Hidden measuring pass — unconstrained height
            styledText
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .fixedSize(horizontal: false, vertical: true)
                .hidden()
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: HeightPreferenceKey.self,
                                        value: geo.size.height)
                    }
                )
                .onPreferenceChange(HeightPreferenceKey.self) { h in
                    measuredHeight = h
                }

            // Visible content
            if needsScroll {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        styledText
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .id("bottom")
                    }
                    .frame(height: maxHeight)
                    .onChange(of: committed) { proxy.scrollTo("bottom", anchor: .bottom) }
                    .onChange(of: partial)   { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .mask(topFadeMask)
            } else {
                styledText
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .mask(topFadeMask)
            }
        }
        .frame(height: max(clamped, 0), alignment: .bottom)
        .clipped()
        .animation(.easeInOut(duration: 0.18), value: clamped)
    }

    // Subtle gradient that fades the top edge so new lines emerging feel natural
    private var topFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black, location: 0.10),
                .init(color: .black, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - HeightPreferenceKey

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
