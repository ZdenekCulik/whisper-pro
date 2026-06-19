import SwiftUI

// Variant V20 — "Dynamic Island"
// Mimics the iPhone Dynamic Island / MacBook notch: a small, very-rounded black
// capsule that floats near the top and morphs open when there is content.
//
// Compact (no text): tight black pill —
//   left  = pulsing recording indicator (red when live, calm gray otherwise)
//   right = compact live level dots driven by audioMeter
//   center = short status word ("listening" / "transcribing" / "ready")
//
// Expanded (has text): the same capsule grows wider + taller, the status row
// stays pinned along the top, and the live transcript fills the body —
// committed text solid white, the still-revising tail dimmed.
//
// Plugs into the switcher exactly like every other variant: Variant20View(context:).
struct Variant20View: View {
    let context: WidgetVariantContext

    // MARK: Tunables

    private let compactWidth: CGFloat = 196
    private let expandedWidth: CGFloat = 320
    private let compactHeight: CGFloat = 40
    private let transcriptMaxHeight: CGFloat = 132
    private let compactCorner: CGFloat = 20      // ~ half height → true capsule
    private let expandedCorner: CGFloat = 26     // very rounded, island-like

    private var fontDesign: Font.Design { ThemeManager.shared.fontDesign }

    // The island opens only when there is actual transcript to show.
    private var isOpen: Bool { context.hasText }

    private var width: CGFloat { isOpen ? expandedWidth : compactWidth }
    private var corner: CGFloat { isOpen ? expandedCorner : compactCorner }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            statusRow
                .frame(height: compactHeight)
                .padding(.horizontal, 14)

            if isOpen {
                transcriptBody
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: width)
        .background(islandBackground)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.55), radius: 18, x: 0, y: 8)
        // Float near the top, like the notch / Dynamic Island.
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Second Escape: fade the whole island away without resizing.
        .opacity(context.isCanceling ? 0 : 1)
        .animation(.spring(response: 0.40, dampingFraction: 0.82), value: isOpen)
        .animation(.easeOut(duration: 0.3), value: context.isCanceling)
    }

    // MARK: Status row (left dot · center label · right meter)

    private var statusRow: some View {
        HStack(spacing: 10) {
            PulsingDot(isLive: context.isRecording, color: dotColor)
                .frame(width: 10, height: 10)

            Group {
                if context.isCancelConfirming {
                    Text("Esc again to cancel")
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text(statusLabel)
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .font(.system(size: 12, weight: .medium, design: fontDesign))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: isOpen ? .leading : .center)

            rightMeter
                .frame(width: 34, height: 18)
        }
    }

    private var statusLabel: String {
        switch context.recordingState {
        case .recording:    return "Listening"
        case .transcribing: return "Transcribing"
        case .enhancing:    return "Enhancing"
        case .starting:     return "Starting"
        case .busy:         return "Busy"
        case .idle:         return context.hasText ? "Done" : "Ready"
        }
    }

    private var dotColor: Color {
        context.isRecording ? AppTheme.Status.error : Color.white.opacity(0.4)
    }

    // Right side compact level: live dots while recording, a quiet spinner-ish
    // static while finalizing, flat dots otherwise — graceful degradation.
    @ViewBuilder
    private var rightMeter: some View {
        switch context.recordingState {
        case .recording:
            CompactLevelMeter(audioMeter: context.audioMeter)
        case .transcribing, .enhancing:
            ProcessingIndicator(color: .white.opacity(0.7))
                .frame(width: 14, height: 14)
        default:
            CompactLevelMeter(audioMeter: AudioMeter(averagePower: 0, peakPower: 0))
        }
    }

    // MARK: Transcript body

    private var transcriptBody: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.10))
                .padding(.horizontal, 14)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    styledText
                        .font(.system(size: 13, design: fontDesign))
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 12)
                        .id("bottom")
                }
                .frame(maxHeight: transcriptMaxHeight)
                .fixedSize(horizontal: false, vertical: true)
                .mask(topFadeMask)
                .onChange(of: context.committed) { proxy.scrollTo("bottom", anchor: .bottom) }
                .onChange(of: context.partial) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    // committed = solid white, partial tail = dimmed. Trust provider spacing
    // (no artificial separator, which would split the last live word).
    private var styledText: Text {
        let committedText = Text(context.committed).foregroundColor(.white)
        guard !context.partial.isEmpty else { return committedText }
        return committedText + Text(context.partial).foregroundColor(.white.opacity(0.4))
    }

    private var topFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black, location: 0.14),
                .init(color: .black, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: Background

    private var islandBackground: some View {
        Color.black
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

// MARK: - Pulsing recording dot

/// Left-side indicator: a solid dot that softly pulses an expanding ring while
/// recording, and sits still (dim) when not.
private struct PulsingDot: View {
    let isLive: Bool
    let color: Color

    var body: some View {
        ZStack {
            if isLive {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let phase = (t.truncatingRemainder(dividingBy: 1.4)) / 1.4 // 0…1
                    Circle()
                        .stroke(color, lineWidth: 1.4)
                        .scaleEffect(1.0 + phase * 1.4)
                        .opacity(1.0 - phase)
                }
            }
            Circle().fill(color)
        }
    }
}

// MARK: - Compact level meter

/// Right-side three-bar level readout driven by the live audio meter. Mirrors
/// the app's AudioVisualizer amplitude math (avg/peak max, gentle gamma) but in a
/// tiny island-sized footprint.
private struct CompactLevelMeter: View {
    let audioMeter: AudioMeter

    private let barCount = 3
    private let barWidth: CGFloat = 3
    private let spacing: CGFloat = 3
    private let minH: CGFloat = 3
    private let maxH: CGFloat = 16

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: barWidth / 2, style: .continuous)
                        .fill(Color.white.opacity(0.85))
                        .frame(width: barWidth, height: height(index, timeline.date))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private func height(_ index: Int, _ date: Date) -> CGFloat {
        let level = max(0, min(1, max(audioMeter.averagePower, audioMeter.peakPower)))
        let amp = max(0, min(1, pow(level, 0.7)))
        let t = date.timeIntervalSince1970
        let wave = sin(t * 7 + Double(index) * 0.9) * 0.5 + 0.5
        return max(minH, minH + CGFloat(amp * wave) * (maxH - minH))
    }
}
