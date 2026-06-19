import SwiftUI

// Variant V24 — "Vertical Ticker"
// Minimal chrome. The transcript is split into words that stack as a vertical
// ticker: the newest word sits at the bottom, older words rise upward and fade
// out as they near the top edge. A quiet, calm column of speech rather than a
// horizontal paragraph. The live (still-revising) tail is the dimmest, lowest
// row; once a word is committed it settles to full strength as it climbs.
struct Variant24View: View {
    let context: WidgetVariantContext

    private let width: CGFloat = 220
    private let tickerHeight: CGFloat = 132
    private let cornerRadius: CGFloat = 20
    private let rowFont: CGFloat = 15
    private let waveformHeight: CGFloat = 30
    // How many recent words the column shows at once.
    private let visibleRows = 6

    var body: some View {
        VStack(spacing: 0) {
            tickerColumn
                .frame(width: width, height: tickerHeight)
            footer
        }
        .frame(width: width)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
        )
        .opacity(context.isCanceling ? 0 : 1)
        .animation(.easeOut(duration: 0.3), value: context.isCanceling)
    }

    // MARK: - Background

    private var background: some View {
        Color.black.overlay(
            LinearGradient(
                colors: [Color.white.opacity(0.05), Color.clear],
                startPoint: .bottom,
                endPoint: .top
            )
        )
    }

    // MARK: - Ticker column

    // Newest word anchored to the bottom; older words stack above and fade up.
    private var tickerColumn: some View {
        VStack(alignment: .center, spacing: 4) {
            Spacer(minLength: 0)
            ForEach(rows) { row in
                Text(row.word)
                    .font(.system(size: rowFont, weight: row.isLatest ? .semibold : .regular,
                                  design: ThemeManager.shared.fontDesign))
                    .foregroundColor(.white.opacity(row.opacity))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .id(row.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        // Fade the rising words out toward the top of the column.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black, location: 0.42),
                    .init(color: .black, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: rows)
        .overlay(emptyPrompt)
    }

    // Placeholder shown only when there is nothing to display yet.
    @ViewBuilder
    private var emptyPrompt: some View {
        if !context.hasText {
            Text(context.isRecording ? "listening" : "ready")
                .font(.system(size: 13, weight: .regular, design: ThemeManager.shared.fontDesign))
                .foregroundColor(.white.opacity(0.28))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 12)
        }
    }

    // MARK: - Footer (status / waveform)

    private var footer: some View {
        RecorderStatusDisplay(
            currentState: context.recordingState,
            audioMeter: context.audioMeter
        )
        .frame(height: waveformHeight)
        .padding(.vertical, 6)
    }

    // MARK: - Row model

    private struct TickerRow: Identifiable, Equatable {
        let id: Int       // stable index from the end of the stream
        let word: String
        let opacity: Double
        let isLatest: Bool
    }

    // Build the visible rows: split committed+partial into words, take the most
    // recent `visibleRows`, and assign opacity so older (higher) words are
    // fainter. The very last word — the live tail — is the brightest anchor.
    private var rows: [TickerRow] {
        let committedWords = context.committed
            .split(whereSeparator: { $0 == " " || $0 == "\n" })
            .map(String.init)
        let partialWords = context.partial
            .split(whereSeparator: { $0 == " " || $0 == "\n" })
            .map(String.init)
        let all = committedWords + partialWords
        guard !all.isEmpty else { return [] }

        let recent = Array(all.suffix(visibleRows))
        let count = recent.count
        return recent.enumerated().map { offset, word in
            // offset 0 = oldest visible (top), offset count-1 = newest (bottom).
            let depthFromBottom = count - 1 - offset
            let fade = 1.0 - (Double(depthFromBottom) / Double(max(visibleRows, 1))) * 0.78
            // Stable id keyed to distance from the end so words keep identity as
            // they climb, letting the move/fade transition animate per word.
            let id = all.count - (count - offset)
            return TickerRow(
                id: id,
                word: word,
                opacity: max(0.18, min(1.0, fade)),
                isLatest: offset == count - 1
            )
        }
    }
}
