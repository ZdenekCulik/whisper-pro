import SwiftUI

struct Variant11View: View {
    let context: WidgetVariantContext

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear

            VStack(alignment: .leading, spacing: context.hasText ? 10 : 0) {
                if context.hasText {
                    transcriptView
                }

                waveformView
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: widgetWidth)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.36), radius: 22, x: 0, y: 10)
            .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
        }
        .frame(width: 540, height: 430, alignment: .bottom)
    }

    private var transcriptView: some View {
        WordFlowLayout(horizontalSpacing: 5, verticalSpacing: 5) {
            ForEach(words) { word in
                Text(word.text)
                    .font(.system(size: word.isHighlighted ? 14 : 13, weight: word.isHighlighted ? .semibold : .regular))
                    .foregroundStyle(.white)
                    .opacity(word.isHighlighted ? 1.0 : 0.45)
                    .scaleEffect(word.isHighlighted ? 1.05 : 1.0)
                    .lineLimit(1)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(maxHeight: 320, alignment: .bottom)
        .clipped()
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: wordAnimationKey)
    }

    private var waveformView: some View {
        HStack {
            Spacer(minLength: 0)
            AudioVisualizer(
                audioMeter: context.audioMeter,
                color: .white,
                isActive: context.isRecording
            )
            .frame(height: 28)
            Spacer(minLength: 0)
        }
        .frame(height: 28)
    }

    private var widgetWidth: CGFloat {
        guard context.hasText else { return 200 }

        let characterCount = combinedText.count
        let expandedWidth = 220 + CGFloat(max(0, characterCount - 18)) * 3.2
        return min(520, max(220, expandedWidth))
    }

    private var wordAnimationKey: String {
        words.map(\.id).joined(separator: "|")
    }

    private var words: [KaraokeWord] {
        let committed = splitWords(context.committed)
        let partial = splitWords(context.partial)
        let committedHighlightStart = max(0, committed.count - min(2, committed.count))

        let committedWords = committed.enumerated().map { index, word in
            KaraokeWord(
                id: "committed-\(index)-\(word)",
                text: word,
                isHighlighted: index >= committedHighlightStart
            )
        }

        let partialWords = partial.enumerated().map { index, word in
            KaraokeWord(
                id: "partial-\(index)-\(word)",
                text: word,
                isHighlighted: true
            )
        }

        return committedWords + partialWords
    }

    private var combinedText: String {
        [context.committed, context.partial]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func splitWords(_ text: String) -> [String] {
        text.split(separator: " ").map(String.init)
    }

    private struct KaraokeWord: Identifiable {
        let id: String
        let text: String
        let isHighlighted: Bool
    }

    private struct WordFlowLayout: Layout {
        var horizontalSpacing: CGFloat
        var verticalSpacing: CGFloat

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let result = layout(in: proposal.width ?? 0, subviews: subviews)
            return result.size
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let result = layout(in: bounds.width, subviews: subviews)

            for (index, position) in result.positions.enumerated() {
                subviews[index].place(
                    at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                    proposal: .unspecified
                )
            }
        }

        private func layout(in proposedWidth: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
            let maxWidth = proposedWidth > 0 ? proposedWidth : 520
            var positions: [CGPoint] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var rowHeight: CGFloat = 0
            var widestRow: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX > 0, currentX + size.width > maxWidth {
                    widestRow = max(widestRow, currentX - horizontalSpacing)
                    currentX = 0
                    currentY += rowHeight + verticalSpacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + horizontalSpacing
                rowHeight = max(rowHeight, size.height)
            }

            widestRow = max(widestRow, max(0, currentX - horizontalSpacing))
            return (CGSize(width: min(maxWidth, widestRow), height: currentY + rowHeight), positions)
        }
    }
}
