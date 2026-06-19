import SwiftUI

// Variant V23 — "Neumorphic Soft"
//
// A soft, tactile neumorphic recorder. Instead of the usual dark glass pill,
// this is a light pastel surface that looks gently extruded from the desktop:
// two opposing soft shadows (a light highlight from the top-left, a darker
// shadow to the bottom-right) give it a pillowy, raised feel. The waveform and
// the mic dot sit in carved-in (inset / pressed) wells, so the live audio reads
// as light pooling inside a soft groove. Calm, rounded, neutral.
//
// Distinct from every dark-pill variant: light theme, no hard borders, dual
// soft shadows, inset wells, dark-on-light transcript text.
struct Variant23View: View {
    let context: WidgetVariantContext

    // Neutral pastel palette — warm light gray so the dual shadows read as soft.
    private let surface       = Color(hex: "ECEFF4")
    private let surfaceTop    = Color(hex: "F4F6FB") // highlight side of the bevel
    private let surfaceBottom = Color(hex: "DDE2EC") // shadow side of the bevel
    private let wellFill      = Color(hex: "E4E8F0") // carved-in groove base
    private let ink           = Color(hex: "3A3F4B") // committed transcript
    private let inkDim        = Color(hex: "8A909E") // unconfirmed tail / hints

    private let cornerRadius: CGFloat = 24
    private let waveformHeight: CGFloat = 44

    private var width: CGFloat { context.hasText ? 320 : 200 }

    var body: some View {
        VStack(spacing: 0) {
            if context.hasText {
                transcriptWell
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 10)
            }
            statusWell
                .padding(.horizontal, 16)
                .padding(.top, context.hasText ? 0 : 16)
                .padding(.bottom, 16)
        }
        .frame(width: width)
        .background(softSurface)
        // Second Escape: gently fade the whole soft panel away.
        .opacity(context.isCanceling ? 0 : 1)
        .scaleEffect(context.isCanceling ? 0.96 : 1)
        .animation(.easeOut(duration: 0.35), value: context.isCanceling)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: context.hasText)
        // Breathing room so the bottom-right soft shadow isn't clipped.
        .padding(20)
    }

    // MARK: - Soft extruded surface (dual shadow + bevel gradient)

    private var softSurface: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [surfaceTop, surface, surfaceBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            // Dark soft shadow toward bottom-right.
            .shadow(color: Color.black.opacity(0.18), radius: 14, x: 8, y: 10)
            // Light highlight toward top-left — the other half of neumorphism.
            .shadow(color: Color.white.opacity(0.9), radius: 12, x: -7, y: -8)
            // A whisper-thin inner highlight along the top edge for the soft bevel.
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                    .blendMode(.overlay)
            )
    }

    // MARK: - Transcript carved into a soft inset well

    private var transcriptWell: some View {
        NeumorphicTranscript(
            committed: context.committed,
            partial: context.partial,
            ink: ink,
            inkDim: inkDim,
            isCanceling: context.isCancelConfirming || context.isCanceling
        )
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(insetWell(cornerRadius: 16))
    }

    // MARK: - Status / waveform carved into a soft inset well

    private var statusWell: some View {
        HStack(spacing: 12) {
            stateDot
            SoftWaveform(
                level: liveLevel,
                isActive: context.isRecording,
                isProcessing: isProcessing,
                tint: ink.opacity(0.55)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 18)
            statusLabel
        }
        .frame(height: waveformHeight)
        .padding(.horizontal, 14)
        .background(insetWell(cornerRadius: 16))
    }

    // Soft pressed-in groove: inverted shadows so the inside looks recessed.
    private func insetWell(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(wellFill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.10),
                                Color.white.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .overlay(
                // Soft inner top shadow → the "carved in" cue.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.06), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .allowsHitTesting(false)
            )
    }

    // MARK: - Live audio level (normalized 0…1 from AudioMeter)

    private var liveLevel: Double {
        max(0, min(1, context.audioMeter.averagePower))
    }

    private var isProcessing: Bool {
        context.recordingState == .transcribing || context.recordingState == .enhancing
    }

    // MARK: - State dot (soft glowing pill that reflects recording state)

    private var stateDot: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 10, height: 10)
            .shadow(color: dotColor.opacity(0.6), radius: context.isRecording ? 5 : 0)
            .overlay(
                Circle().stroke(Color.white.opacity(0.7), lineWidth: 0.5)
            )
            .scaleEffect(context.isRecording ? pulse : 1)
            .animation(
                context.isRecording
                    ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                    : .default,
                value: pulse
            )
            .onAppear { pulse = 1.25 }
    }

    @State private var pulse: CGFloat = 1.0

    private var dotColor: Color {
        switch context.recordingState {
        case .recording:    return Color(hex: "E5707E") // soft coral
        case .transcribing: return Color(hex: "E0A45C") // soft amber
        case .enhancing:    return Color(hex: "7FB37A") // soft sage
        case .starting, .busy: return inkDim
        case .idle:         return inkDim.opacity(0.6)
        }
    }

    // MARK: - Status label (graceful degrade across all states)

    @ViewBuilder
    private var statusLabel: some View {
        if let label = labelText {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(inkDim)
                .fixedSize()
                .transition(.opacity)
        }
    }

    private var labelText: String? {
        switch context.recordingState {
        case .starting:     return "Listening"
        case .transcribing: return "Transcribing"
        case .enhancing:    return "Polishing"
        case .busy:         return "Busy"
        case .recording:    return nil // waveform speaks for itself
        case .idle:         return context.hasText ? nil : "Ready"
        }
    }
}

// MARK: - Neumorphic transcript

/// Dark-on-light transcript that fits the soft theme. Committed text is solid
/// ink; the still-revising tail is dimmed. Auto-scrolls to the newest words.
private struct NeumorphicTranscript: View {
    let committed: String
    let partial: String
    let ink: Color
    let inkDim: Color
    let isCanceling: Bool

    private var styledText: Text {
        let c = Text(committed).foregroundColor(ink)
        guard !partial.isEmpty else { return c }
        return c + Text(partial).foregroundColor(inkDim)
    }

    var body: some View {
        Group {
            if committed.isEmpty && partial.isEmpty {
                Text("Start speaking…")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(inkDim.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        styledText
                            .font(.system(size: 13, design: .rounded))
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("bottom")
                    }
                    .frame(maxHeight: .infinity)
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
                    .onChange(of: committed) { proxy.scrollTo("bottom", anchor: .bottom) }
                    .onChange(of: partial) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
        // First Escape: soften the text to hint it's about to be discarded.
        .opacity(isCanceling ? 0.4 : 1)
        .blur(radius: isCanceling ? 1.5 : 0)
        .animation(.easeOut(duration: 0.25), value: isCanceling)
    }
}

// MARK: - Soft waveform

/// A row of soft, rounded bars that gently rise with the live level. When idle
/// they rest as a flat soft line; while processing they breathe in a calm wave.
private struct SoftWaveform: View {
    let level: Double      // 0…1 live audio
    let isActive: Bool     // recording
    let isProcessing: Bool // transcribing / enhancing
    let tint: Color

    private let barCount = 18

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !(isActive || isProcessing))) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let spacing: CGFloat = 4
                let barWidth = max(2, (geo.size.width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount))
                HStack(spacing: spacing) {
                    ForEach(0..<barCount, id: \.self) { i in
                        Capsule(style: .continuous)
                            .fill(tint)
                            .frame(width: barWidth, height: barHeight(i, t: t, maxH: geo.size.height))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private func barHeight(_ i: Int, t: TimeInterval, maxH: CGFloat) -> CGFloat {
        let minH: CGFloat = 3
        if isActive {
            // Live: center bars react more strongly; a soft wobble keeps it organic.
            let center = Double(barCount - 1) / 2
            let dist = abs(Double(i) - center) / center // 0 at center, 1 at edges
            let falloff = 1 - dist * 0.65
            let wobble = (sin(t * 6 + Double(i) * 0.7) + 1) / 2 * 0.25
            let h = (level * falloff + wobble) * Double(maxH)
            return max(minH, CGFloat(h))
        } else if isProcessing {
            // Calm traveling wave while finalizing.
            let wave = (sin(t * 3 + Double(i) * 0.5) + 1) / 2
            return minH + CGFloat(wave) * (maxH * 0.45)
        } else {
            // Idle: flat soft baseline.
            return minH
        }
    }
}
