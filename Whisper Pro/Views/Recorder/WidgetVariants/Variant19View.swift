import SwiftUI

// Variant V19 — "Waveform Hero"
// Audio-first floating recorder. A large animated real-time waveform is the hero at
// the top; the transcript sits below it in smaller type (committed solid white, the
// still-revising tail dimmed). Recording state drives the hero (reactive bars while
// live, a calm processing strip while finalizing, flat bars at rest). Escape-to-cancel
// fades the whole panel out, matching the other variants' graceful degradation.
struct Variant19View: View {
    let context: WidgetVariantContext

    private let width: CGFloat = 320
    private let collapsedWidth: CGFloat = 200
    private let heroHeight: CGFloat = 64
    private let cornerRadius: CGFloat = 18
    private let transcriptFontSize: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            hero
            if context.hasText {
                transcript
                    .transition(.opacity)
            }
        }
        .frame(width: context.hasText ? width : collapsedWidth)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 6)
        // Escape-to-cancel: fade the whole panel away on the second press, same as V2.
        .opacity(context.isCanceling ? 0 : 1)
        .animation(.easeOut(duration: 0.3), value: context.isCanceling)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: context.hasText)
    }

    // MARK: - Hero waveform

    @ViewBuilder
    private var hero: some View {
        ZStack {
            switch context.recordingState {
            case .transcribing, .enhancing:
                // Finalizing: drop the reactive bars for a calm labelled strip so the
                // hero reads as "processing" rather than still listening.
                ProcessingStatusDisplay(
                    mode: context.recordingState == .enhancing ? .enhancing : .transcribing,
                    color: .white
                )
                .transition(.opacity)
            default:
                HeroWaveform(
                    audioMeter: context.audioMeter,
                    isActive: context.isRecording
                )
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: heroHeight)
        .animation(.easeInOut(duration: 0.22), value: context.recordingState)
    }

    // MARK: - Transcript (smaller type, below the hero)

    private var transcript: some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.12))
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    styledText
                        .font(.system(size: transcriptFontSize, design: ThemeManager.shared.fontDesign))
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .id("bottom")
                }
                .frame(height: 64)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.16),
                            .init(color: .black, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .onChange(of: context.committed) { proxy.scrollTo("bottom", anchor: .bottom) }
                .onChange(of: context.partial) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    // committed = solid white, partial (unconfirmed tail) = dimmed, same convention as
    // every other variant. No artificial separator — the provider embeds spacing.
    private var styledText: Text {
        let committedText = Text(context.committed).foregroundColor(.white)
        guard !context.partial.isEmpty else { return committedText }
        return committedText + Text(context.partial).foregroundColor(.white.opacity(0.4))
    }

    private var background: some View {
        Color.black
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.04), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

// MARK: - Hero waveform

/// A large, full-width mirrored waveform driven by the live audio meter. Bars rise
/// and fall around a center line so it reads as a real-time audio hero, not the thin
/// status strip the other variants use. When idle the bars settle to a flat resting
/// line so the panel still feels alive without implying it's listening.
private struct HeroWaveform: View {
    let audioMeter: AudioMeter
    let isActive: Bool

    private let barCount = 27
    private let barWidth: CGFloat = 3.5
    private let barSpacing: CGFloat = 3
    private let minHeight: CGFloat = 3

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { ctx in
            GeometryReader { geo in
                let maxHeight = geo.size.height - 12
                HStack(spacing: barSpacing) {
                    ForEach(0..<barCount, id: \.self) { index in
                        Capsule()
                            .fill(.white.opacity(isActive ? 0.92 : 0.4))
                            .frame(
                                width: barWidth,
                                height: barHeight(for: index, at: ctx.date, maxHeight: maxHeight)
                            )
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }

    private func barHeight(for index: Int, at date: Date, maxHeight: CGFloat) -> CGFloat {
        guard isActive else { return minHeight }

        let time = date.timeIntervalSince1970
        // Use whichever of average/peak is stronger so quiet/processed mic signals
        // still register; same level model as the shared AudioVisualizer.
        let level = max(audioMeter.averagePower, audioMeter.peakPower)
        let amplitude = max(0, min(1, pow(level, 0.55)))
        // Per-bar phase offset so bars don't oscillate in lockstep.
        let phase = Double(index) * 0.42
        let wave = sin(time * 9 + phase) * 0.5 + 0.5
        // Bell-shaped envelope so the hero peaks in the middle and tapers to the edges.
        let centerDistance = abs(Double(index) - Double(barCount - 1) / 2) / (Double(barCount - 1) / 2)
        let envelope = pow(1.0 - centerDistance, 0.85) * 0.6 + 0.4

        let h = minHeight + CGFloat(amplitude * wave * envelope) * (maxHeight - minHeight)
        return max(minHeight, min(maxHeight, h))
    }
}
