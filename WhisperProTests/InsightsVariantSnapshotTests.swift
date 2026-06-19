import Testing
import SwiftUI
import AppKit
@testable import WhisperPro

@MainActor
struct InsightsVariantSnapshotTests {

    private func write(_ view: some View, width: CGFloat = 1040, to path: String) throws {
        let hosted = view
            .environmentObject(ThemeManager())
            .environment(\.colorScheme, .light)
            .frame(width: width)
            .padding(28)
            .background(Color(white: 0.965))
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

    // Small card wrapper so isolated components read like panels.
    private func panel<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.black.opacity(0.08)))
    }

    @Test func renderV1FlowClone() throws {
        try write(InsightsVariantFlowClone(data: .sample, stats: .sample, animate: false), to: "/tmp/insights-v1.png")
    }

    @Test func renderV2DenseAnalytics() throws {
        try write(InsightsVariantDenseAnalytics(data: .sample, stats: .sample, animate: false), to: "/tmp/insights-v2.png")
    }

    @Test func renderV3EditorialHero() throws {
        try write(InsightsVariantEditorialHero(data: .sample, stats: .sample, animate: false), to: "/tmp/insights-v3.png")
    }

    @Test func renderV1Refined() throws {
        try write(InsightsV1Refined(data: .sample, stats: .sample, animate: false), to: "/tmp/insights-v1-refined.png")
    }

    @Test func renderWpmAB() throws {
        let view = HStack(alignment: .top, spacing: 18) {
            panel("WPM — A · comparison bars") {
                WpmComparison(wpm: 96, accent: .blue)
            }
            panel("WPM — B · speedometer") {
                WpmComparisonB(wpm: 96, accent: .blue)
            }
        }
        try write(view, width: 760, to: "/tmp/insights-wpm-ab.png")
    }

    @Test func renderModeTimeOfDay() throws {
        let view = panel("Mode panel — when you dictate") {
            InsightTimeOfDay(hours: InsightsData.sample.hourBuckets, accent: .blue)
        }
        try write(view, width: 520, to: "/tmp/insights-mode-time.png")
    }

    @Test func renderModeTopApps() throws {
        let view = panel("Mode panel — top apps") {
            InsightModeBars(modes: InsightsData.sample.topApps, accent: .blue, animate: false)
        }
        try write(view, width: 520, to: "/tmp/insights-mode-apps.png")
    }
}
