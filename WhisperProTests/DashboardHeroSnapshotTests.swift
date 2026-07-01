import Testing
import SwiftUI
import AppKit
@testable import WhisperPro

/// Renders the dashboard hero to a PNG in /tmp so the design can be reviewed
/// as an image without running the app.
@MainActor
struct DashboardHeroSnapshotTests {

    @Test func renderHero() throws {
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
        try png.write(to: URL(fileURLWithPath: "/tmp/dashboard-hero-v1.png"))
    }
}
