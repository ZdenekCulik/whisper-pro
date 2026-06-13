import SwiftUI
import AppKit

struct RecentTranscriptRow: View {
    let transcription: Transcription

    @EnvironmentObject var theme: ThemeManager
    @State private var isHovered = false
    @State private var copied = false

    private var displayText: String {
        transcription.enhancedText ?? transcription.text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time column
            Text(transcription.timestamp, format: .dateTime.hour().minute())
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
                .frame(width: 70, alignment: .leading)
                .padding(.top, 1)

            // Transcript text
            Text(displayText)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(theme.resolvedPrimaryText)
                .lineSpacing(3)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Copy button — revealed on hover
            copyButton
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 2)
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(0.5)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var copyButton: some View {
        Button(action: copyToClipboard) {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                Text(copied ? "Copied" : "Copy")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(copied
                ? (theme.resolvedAccent ?? .accentColor)
                : theme.resolvedSecondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.resolvedSurface.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(theme.resolvedBorder.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .opacity(isHovered ? 1 : 0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(displayText, forType: .string)
        withAnimation(.easeInOut(duration: 0.15)) {
            copied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.15)) {
                copied = false
            }
        }
    }
}
