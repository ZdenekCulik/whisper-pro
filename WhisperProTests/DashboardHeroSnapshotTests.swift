import Testing
import SwiftUI
import AppKit
@testable import WhisperPro

/// Renders the dashboard hero to a PNG in /tmp so the design can be reviewed
/// as an image without running the app.
@MainActor
struct DashboardHeroSnapshotTests {

    @Test func renderHero() throws {
        try render(to: "/tmp/dashboard-hero-v1.png")
    }

    /// Week + Month renders — the ranges whose x-axis carries weekday names.
    /// Flips the same UserDefaults key the card's @AppStorage reads, restoring
    /// the user's value afterwards.
    @Test func renderWeekAndMonth() throws {
        let defaults = UserDefaults.standard
        let savedRange = defaults.string(forKey: "dashboardWordsRange")
        defer {
            if let savedRange {
                defaults.set(savedRange, forKey: "dashboardWordsRange")
            } else {
                defaults.removeObject(forKey: "dashboardWordsRange")
            }
        }

        for range in ["week", "month"] {
            defaults.set(range, forKey: "dashboardWordsRange")
            try render(to: "/tmp/dashboard-hero-\(range).png")
        }
    }

    private func render(to path: String) throws {
        let hosted = DashboardHeroSection(stats: .sample, insightsData: .sample, animate: false)
            .environmentObject(ThemeManager())
            .environment(\.colorScheme, .dark)
            .frame(width: 900)
            .padding(28)
            .background(Color(red: 0.075, green: 0.08, blue: 0.09))
        let renderer = ImageRenderer(content: hosted)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "snapshot", code: 1)
        }
        try png.write(to: URL(fileURLWithPath: path))
    }
}
