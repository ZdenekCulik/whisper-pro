import SwiftUI
import AppKit

/// Shows the real macOS icon for an app (looked up by bundle id via NSWorkspace).
/// Falls back to an SF Symbol when the app isn't installed or no bundle id is known.
struct AppIconImage: View {
    let bundleId: String?
    let fallbackSymbol: String
    var size: CGFloat = 20

    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        if let icon = Self.icon(for: bundleId) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            Image(systemName: fallbackSymbol)
                .font(.system(size: size * 0.7, weight: .semibold))
                .foregroundColor(theme.resolvedSecondaryText)
                .frame(width: size, height: size)
        }
    }

    /// macOS resolves the bundle id to the installed app and hands back its icon.
    private static func icon(for bundleId: String?) -> NSImage? {
        guard let bundleId,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
