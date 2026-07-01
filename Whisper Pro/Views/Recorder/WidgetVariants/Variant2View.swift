import SwiftUI
import AppKit

struct Variant2View: View {
    let context: WidgetVariantContext

    // Click the bottom waveform to cycle through the prototype designs.
    @AppStorage("WaveformStyle") private var waveformStyle: Int = 0

    private static let widthKey = "MiniWidgetVariant2Width"
    private static let minWidth: CGFloat = 240
    private static let maxWidth: CGFloat = 520
    private static let defaultWidth: CGFloat = 384
    private static let collapsedWidth: CGFloat = 138

    // Transcript grows with the text from a 2-row floor up to a 3-row cap, then scrolls.
    private static let fontSize: CGFloat = 13
    private static let lineSpacing: CGFloat = 3
    private static let lineHeight: CGFloat = fontSize + lineSpacing + 4
    private static let defaultLines: CGFloat = 2
    private static let maxLines: CGFloat = 3
    private static let textTopPadding: CGFloat = 16
    private static let textBottomPadding: CGFloat = 6

    private static var minTextHeight: CGFloat {
        lineHeight * defaultLines + textTopPadding + textBottomPadding
    }
    private static var maxTextHeight: CGFloat {
        lineHeight * maxLines + textTopPadding + textBottomPadding
    }

    @State private var widthOverride: CGFloat = {
        let saved = UserDefaults.standard.double(forKey: widthKey)
        guard saved >= minWidth && saved <= maxWidth else { return defaultWidth }
        return saved
    }()

    // Default to the expanded (taller) layout on every spawn; collapse is a manual,
    // session-only toggle, not a persisted preference.
    @State private var isCollapsed = false
    @State private var isHoveringPanel = false
    @State private var isHoveringToggle = false
    @State private var measuredTextHeight: CGFloat = Variant2View.minTextHeight

    private var cornerRadius: CGFloat { isCollapsed ? 22 : 18 }

    // Single morphing pill: width, height, corner radius and content all animate on
    // the same view identity, so collapse/expand is one smooth shape change instead of
    // two separate views swapping in and out.
    var body: some View {
        pill
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.18)) { isHoveringPanel = hovering }
            }
            // Room below the pill so the drop shadow isn't clipped by the panel edge.
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            // Second Escape: the text dissolves into Invisible Ink (in cancelContent),
            // then — without resizing the box — the whole panel just fades away.
            .opacity(context.isCanceling ? 0 : 1)
            .animation(.easeOut(duration: 0.3).delay(0.55), value: context.isCanceling)
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isCollapsed)
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: measuredTextHeight)
            .onChange(of: context.recordingState) { _, newState in
                // A fresh recording (CMD spawn) always opens expanded.
                if newState == .recording { isCollapsed = false }
            }
    }

    private var isCanceling: Bool { context.isCancelConfirming || context.isCanceling }

    private var pill: some View {
        ZStack {
            if isCanceling {
                cancelContent
                    .transition(.opacity)
            } else {
                normalContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: context.isCancelConfirming)
        .frame(width: isCollapsed && !isCanceling ? Variant2View.collapsedWidth : widthOverride)
        .background(pillBackground(cornerRadius: cornerRadius))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(pillBorder(cornerRadius: cornerRadius))
        .overlay(alignment: isCollapsed ? .trailing : .bottomTrailing) {
            if !isCanceling { toggleIcon }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.9), value: context.isCancelConfirming)
        .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 6)
    }

    private var normalContent: some View {
        VStack(spacing: 0) {
            if !isCollapsed {
                transcriptArea
            }

            HStack(spacing: 0) {
                // Collapsed: symmetric margins so the fixed-width waveform sits centered,
                // mirroring the right-side space the hover icon lives in onto the left.
                Spacer(minLength: isCollapsed ? 8 : 16)

                // After the mic stops (finalizing), drop the "transcribing…" label and
                // processing dots and keep a calm static waveform — progress is conveyed
                // by the shimmer over the text block instead. While still live (mic on,
                // even in the .transcribing streaming state) keep the reactive waveform.
                if !context.isRecording
                    && (context.recordingState == .enhancing || context.recordingState == .transcribing) {
                    StaticVisualizer(color: .white)
                        .frame(height: 40)
                } else if context.isRecording && !isCollapsed {
                    waveformCycler
                } else {
                    RecorderStatusDisplay(
                        currentState: context.recordingState,
                        audioMeter: context.audioMeter
                    )
                    .frame(height: 40)
                }

                Spacer(minLength: isCollapsed ? 8 : 16)
            }
        }
    }

    private var normalizedWaveformStyle: Int {
        min(max(waveformStyle, 0), WaveformStyleView.styleCount - 1)
    }

    // Clickable live waveform: each click advances to the next approved design; the
    // cursor becomes a pointing hand on hover.
    private var waveformCycler: some View {
        Button(action: { waveformStyle = (normalizedWaveformStyle + 1) % WaveformStyleView.styleCount }) {
            WaveformStyleView(style: normalizedWaveformStyle, audioMeter: context.audioMeter, isActive: true)
                .frame(height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    // MARK: - Escape-to-cancel confirm + dissolve

    // First Escape: the just-dictated text shown centered with a "Esc again to cancel"
    // prompt. Second Escape: the text dissolves into Invisible Ink, then the pill closes.
    private var cancelText: String {
        [context.committed, context.partial].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private var cancelContent: some View {
        ZStack {
            // The just-dictated text stays in its normal place (top, left-aligned, padded).
            // While confirming it's lightly blurred + dimmed to 40%; on the second Escape
            // it becomes solid Invisible Ink that scatters into dust.
            InvisibleInkText(
                text: cancelText,
                fontSize: Variant2View.fontSize,
                isDissolving: context.isCanceling
            )
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 16)
            .padding(.top, Variant2View.textTopPadding)
            .blur(radius: context.isCanceling ? 0 : 9)
            .opacity(context.isCanceling ? 1 : 0.4)

            if context.isCancelConfirming {
                (Text("Esc").foregroundColor(.white).fontWeight(.semibold)
                    + Text(" again to cancel").foregroundColor(.white.opacity(0.45)))
                    .font(.system(size: 13))
                    .frame(maxWidth: 800)
                    .shadow(color: .black, radius: 16, x: 0, y: 0)
                    .transition(.opacity)
            }
        }
        // Keep the panel exactly the height it had before Escape (default or expanded);
        // Escape never resizes it.
        .frame(width: widthOverride, height: transcriptDisplayHeight + 40)
        .animation(.easeOut(duration: 0.5), value: context.isCanceling)
    }

    private var transcriptDisplayHeight: CGFloat {
        min(Variant2View.maxTextHeight, max(Variant2View.minTextHeight, measuredTextHeight))
    }

    private func pillBackground(cornerRadius: CGFloat) -> some View {
        Color.black
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.04), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private func pillBorder(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6)
    }

    // MARK: - Transcript

    private var transcriptArea: some View {
        let height = min(
            Variant2View.maxTextHeight,
            max(Variant2View.minTextHeight, measuredTextHeight)
        )
        // Only fade once the content is actually taller than the viewport (scrolling).
        // Below that, a mask would clip the top/bottom lines in the default state.
        let isScrolling = measuredTextHeight > Variant2View.maxTextHeight + 1

        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                styledText
                    .font(.system(size: Variant2View.fontSize))
                    .lineSpacing(Variant2View.lineSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, Variant2View.textTopPadding)
                    .padding(.bottom, Variant2View.textBottomPadding)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: TranscriptHeightKey.self, value: geo.size.height)
                        }
                    )
                    .id("bottom")
            }
            .frame(height: height)
            .onPreferenceChange(TranscriptHeightKey.self) { measuredTextHeight = $0 }
            .mask(scrollMask(isScrolling: isScrolling))
            .onChange(of: context.committed) { keepPinnedToBottom(proxy) }
            .onChange(of: context.partial) { keepPinnedToBottom(proxy) }
        }
    }

    // Smoothly follow the newest text instead of hard-jumping. Only scrolls once the
    // content actually overflows the cap, so short transcripts don't twitch.
    private func keepPinnedToBottom(_ proxy: ScrollViewProxy) {
        guard measuredTextHeight > Variant2View.maxTextHeight + 1 else { return }
        withAnimation(.easeOut(duration: 0.22)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    // Soft fade in/out at the very edges while scrolling; full opacity when it fits.
    @ViewBuilder
    private func scrollMask(isScrolling: Bool) -> some View {
        if isScrolling {
            // Stronger, taller fade at the top so scrolled-up lines dissolve clearly;
            // softer trim at the bottom.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: Color.black.opacity(0.5), location: 0.08),
                    .init(color: .black, location: 0.20),
                    .init(color: .black, location: 0.94),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            Color.black
        }
    }

    // committed = solid white, partial (unconfirmed tail) settles from gray to white.
    // A shimmer sweep over the live text gives the fill a smooth, animated feel
    // instead of words snapping from 0.4 to full opacity.
    private var styledText: some View {
        // After the mic stops (Enter/close), sweep a strong shimmer across the whole
        // block while it's being finalized and polished — both the transcribing and
        // enhancing phases.
        let isFinalizing = !context.isRecording
            && (context.recordingState == .transcribing || context.recordingState == .enhancing)
        return ShimmerTranscriptText(
            committed: context.committed,
            partial: context.partial,
            isLive: context.isRecording,
            isEnhancing: isFinalizing
        )
    }

    // MARK: - Expand / Collapse toggle icon

    // One adaptive icon: collapsed → bigger circular expand glyph on the right edge;
    // expanded → circular collapse glyph in the bottom-right corner. Both get the same
    // white hover circle behind the arrows.
    private var toggleIcon: some View {
        Button(action: toggleCollapsed) {
            toggleGlyph(
                size: isCollapsed ? 24 : 22,
                bgOpacity: 0.12,
                circular: true
            )
        }
        .buttonStyle(.plain)
        // Collapsed: flush to the right edge with the same 8px inset it has top/bottom
        // (24px glyph centered in the 40px-tall pill). Expanded: off the corner.
        .padding(.trailing, isCollapsed ? 8 : 12)
        .padding(.bottom, isCollapsed ? 0 : 11)
        .opacity(isHoveringPanel ? 1 : 0)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHoveringToggle = hovering }
        }
        .animation(.easeOut(duration: 0.18), value: isHoveringPanel)
    }

    @ViewBuilder
    private func toggleGlyph(size: CGFloat = 18, bgOpacity: Double = 0.04, cornerRadius: CGFloat = 5, circular: Bool = false) -> some View {
        Image(systemName: isCollapsed
              ? "arrow.up.left.and.arrow.down.right"
              : "arrow.down.right.and.arrow.up.left")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white.opacity(isHoveringToggle ? 1.0 : 0.8))
            .frame(width: size, height: size)
            .background(
                Group {
                    if circular {
                        Circle().fill(Color.white.opacity(isHoveringToggle ? bgOpacity : 0))
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(isHoveringToggle ? bgOpacity : 0))
                    }
                }
            )
    }

    private func toggleCollapsed() {
        isCollapsed.toggle()
    }
}

// MARK: - Shimmer transcript text

/// Renders committed (solid white) + partial (settling) text. While live, a soft
/// highlight sweep travels across the partial tail so freshly recognized words
/// fade up smoothly rather than snapping from gray to white.
private struct ShimmerTranscriptText: View {
    let committed: String
    let partial: String
    let isLive: Bool
    var isEnhancing: Bool = false

    private var base: Text {
        let committedText = Text(committed).foregroundColor(.white)
        guard !partial.isEmpty else { return committedText }

        // Trust the provider's own spacing. The live tail is often the unfinished rest
        // of the current word (e.g. committed "kdy" + tail "ž" → "když"), so inserting
        // an artificial space here would split words mid-stream. Soniox already emits a
        // leading space on the tail when it starts a new word.
        return committedText + Text(partial).foregroundColor(.white.opacity(0.45))
    }

    var body: some View {
        if committed.isEmpty && partial.isEmpty {
            // Empty default state: a faint prompt so the panel isn't blank on spawn.
            Text("Start speaking...")
                .foregroundColor(.white.opacity(0.3))
        } else if isEnhancing {
            // While the text is being polished, sweep a bright highlight across the
            // whole block so it reads as one shimmering "being refined" state instead
            // of a separate loading spinner. Dim base + strong wide sweep = clearly
            // visible gradient travelling across every word.
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let phase = (t.truncatingRemainder(dividingBy: 0.9)) / 0.9  // 0…1 loop
                // Strongly dim the base and run a bright, tight band so the highlight
                // reads as a very pronounced sweep crossing the whole block.
                base.foregroundColor(.white.opacity(0.22))
                    .overlay(sweep(phase: phase, intensity: 1.0, band: 0.22))
            }
        } else {
            base
        }
    }

    private func sweep(phase: Double, intensity: Double, band: Double) -> some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: max(0, phase - band)),
                .init(color: Color.white.opacity(intensity), location: phase),
                .init(color: .clear, location: min(1, phase + band))
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .blendMode(.plusLighter)
        .mask(base)
    }
}

private struct TranscriptHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
