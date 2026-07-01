import SwiftUI
import SwiftData
import Foundation
import os

private struct DashboardStatsSummary: Equatable, Sendable {
    var totalCount: Int = 0
    var totalWords: Int = 0
    var totalDuration: TimeInterval = 0
    var wordsToday: Int = 0
}

private final class DashboardStatsCache: @unchecked Sendable {
    static let shared = DashboardStatsCache()

    private let lock = NSLock()
    private var summary: DashboardStatsSummary?

    private init() {}

    func currentSummary() -> DashboardStatsSummary? {
        lock.lock()
        defer { lock.unlock() }
        return summary
    }

    func update(_ summary: DashboardStatsSummary) {
        lock.lock()
        self.summary = summary
        lock.unlock()
    }
}

private enum DashboardStatsLoader {
    static func load(from modelContainer: ModelContainer) async throws -> DashboardStatsSummary {
        let task = Task.detached(priority: .utility) {
            try Task.checkCancellation()

            let backgroundContext = ModelContext(modelContainer)
            let count = try backgroundContext.fetchCount(FetchDescriptor<SessionMetric>())

            try Task.checkCancellation()

            var words = 0
            var duration: TimeInterval = 0
            var wordsToday = 0
            let last24hCutoff = Date().addingTimeInterval(-24 * 60 * 60)
            let batchSize = 500
            var offset = 0

            while offset < count {
                try Task.checkCancellation()

                var descriptor = FetchDescriptor<SessionMetric>()
                descriptor.fetchLimit = batchSize
                descriptor.fetchOffset = offset

                let records = try backgroundContext.fetch(descriptor)
                if records.isEmpty {
                    break
                }

                for metric in records {
                    words += metric.wordCount
                    duration += metric.audioDuration
                    if metric.timestamp >= last24hCutoff {
                        wordsToday += metric.wordCount
                    }
                }

                offset += records.count
            }

            try Task.checkCancellation()

            return DashboardStatsSummary(
                totalCount: count,
                totalWords: words,
                totalDuration: duration,
                wordsToday: wordsToday
            )
        }

        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}

struct DashboardContent: View {
    private let logger = Logger(subsystem: "com.prakashjoshipax.whisperpro", category: "DashboardContent")
    let modelContext: ModelContext
    let licenseState: LicenseViewModel.LicenseState
    let onAddLicenseKey: () -> Void

    @State private var totalCount: Int = 0
    @State private var totalWords: Int = 0
    @State private var totalDuration: TimeInterval = 0
    @State private var wordsToday: Int = 0
    @State private var hasLoadedStatsSnapshot: Bool = false
    @State private var insightsData: InsightsData?
    @State private var dashboardStatsTask: Task<Void, Never>?
    @State private var insightsTask: Task<Void, Never>?
    @State private var isModelStatsPanelPresented = false
    @State private var isAccessibilityEnabled = AXIsProcessTrusted()
    @State private var isSystemInfoCopied = false
    @AppStorage("dashboardHeroVariant") private var heroVariant: DashboardHeroVariant = .overview
    @EnvironmentObject private var themeManager: ThemeManager

    init(
        modelContext: ModelContext,
        licenseState: LicenseViewModel.LicenseState,
        onAddLicenseKey: @escaping () -> Void
    ) {
        self.modelContext = modelContext
        self.licenseState = licenseState
        self.onAddLicenseKey = onAddLicenseKey

        let cachedSummary = DashboardStatsCache.shared.currentSummary()
        _totalCount = State(initialValue: cachedSummary?.totalCount ?? 0)
        _totalWords = State(initialValue: cachedSummary?.totalWords ?? 0)
        _totalDuration = State(initialValue: cachedSummary?.totalDuration ?? 0)
        _wordsToday = State(initialValue: cachedSummary?.wordsToday ?? 0)
        _hasLoadedStatsSnapshot = State(initialValue: cachedSummary != nil)
    }

    private func openModelStatsPanel() {
        isModelStatsPanelPresented = true
    }

    private func closeModelStatsPanel() {
        isModelStatsPanelPresented = false
    }

    var body: some View {
        Group {
            if totalCount == 0 && hasLoadedStatsSnapshot {
                emptyStateView
            } else {
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 24) {
                            dashboardHeader

                            heroSection

                            if shouldShowAccessibilityReminder {
                                accessibilityReminder
                            }

                            RecentTranscriptsSection()

                            Spacer(minLength: 20)

                            HStack {
                                Spacer()
                                footerActionsView
                            }
                        }
                        .frame(minHeight: geometry.size.height - 56)
                        .padding(.vertical, 28)
                        .padding(.horizontal, 24)
                    }
                }
            }
        }
        .task {
            await loadDashboardStatsEfficiently()
            await loadInsights()
            // Refresh the gray "Napsáno" line from the Claude + Codex logs here rather
            // than at launch: this only runs while the Dashboard is on screen, so it
            // never steals CPU / SwiftData from dictation. Incremental + detached, and
            // it posts .typedMetricsDidChange to redraw the line when done.
            await TypedLogIngestor.ingestIfNeeded(modelContainer: modelContext.container)
        }
        .onAppear(perform: refreshAccessibilityStatus)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAccessibilityStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionMetricsDidChange)) { _ in
            dashboardStatsTask?.cancel()
            dashboardStatsTask = Task {
                await loadDashboardStatsEfficiently()
            }
            insightsTask?.cancel()
            insightsTask = Task {
                await loadInsights()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .typedMetricsDidChange)) { _ in
            // Typed-words aggregates changed — refresh only the insights (the
            // gray line). Headline totals / TIME SAVED are dictation-only.
            insightsTask?.cancel()
            insightsTask = Task {
                await loadInsights()
            }
        }
        .onDisappear {
            dashboardStatsTask?.cancel()
            insightsTask?.cancel()
        }
        .sidePanel(isPresented: .init(
            get: { isModelStatsPanelPresented },
            set: { newValue in
                if !newValue { closeModelStatsPanel() }
            }
        )) {
            ModelPerformancePanel(onClose: closeModelStatsPanel)
        }
    }

    private func refreshAccessibilityStatus() {
        isAccessibilityEnabled = AXIsProcessTrusted()
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func loadDashboardStatsEfficiently() async {
        do {
            let summary = try await DashboardStatsLoader.load(from: modelContext.container)

            guard !Task.isCancelled else {
                return
            }

            let shouldAcceptSummary = summary.totalCount > 0 || !SessionMetricMigrationService.shared.isRunning

            await MainActor.run {
                guard shouldAcceptSummary else {
                    return
                }

                self.totalCount = summary.totalCount
                self.totalWords = summary.totalWords
                self.totalDuration = summary.totalDuration
                self.wordsToday = summary.wordsToday
                DashboardStatsCache.shared.update(summary)
                self.hasLoadedStatsSnapshot = true
            }
        } catch is CancellationError {
        } catch {
            logger.error("Error loading dashboard stats: \(error, privacy: .public)")
        }
    }

    private func loadInsights() async {
        do {
            let data = try await InsightsLoader.load(from: modelContext.container)
            guard !Task.isCancelled else { return }
            await MainActor.run { self.insightsData = data }
        } catch is CancellationError {
        } catch {
            logger.error("Error loading insights: \(error, privacy: .public)")
        }
    }

    private var emptyStateView: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 20) {
                        emptyStateStickerPreview

                        Text("No Recorder Sessions Yet")
                            .font(.title3.weight(.semibold))
                        Text("Start your first recording to unlock value insights.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 48)
                    .frame(minHeight: geometry.size.height - 56)

                    if shouldShowAccessibilityReminder {
                        accessibilityReminder
                    }
                }
                .padding(.vertical, 28)
                .padding(.horizontal, 24)
            }
        }
    }
    
    // MARK: - Sections

    @ViewBuilder
    private var emptyStateStickerPreview: some View {
        StickerAchievementBadge()
            .frame(width: 136, height: 136)
    }

    private var shouldShowAccessibilityReminder: Bool {
        #if LOCAL_BUILD
        false
        #else
        !isAccessibilityEnabled
        #endif
    }

    private var accessibilityReminder: some View {
        DashboardAccessibilityReminder(onOpenSettings: openAccessibilitySettings)
    }

    @ViewBuilder
    private var licenseStatusMessage: some View {
        switch licenseState {
        case .unlicensed:
            TrialMessageView(
                message: Text("Activate a license to continue using Whisper Pro."),
                type: .licenseRequired,
                onAddLicenseKey: onAddLicenseKey
            )
        case .trial(let daysRemaining):
            TrialMessageView(
                message: Text(String(localized: "You have \(daysRemaining) days left in your trial")),
                type: daysRemaining <= 2 ? .warning : .info,
                onAddLicenseKey: onAddLicenseKey
            )
        case .trialExpired:
            TrialMessageView(
                message: Text("Your trial has expired. Upgrade to continue using Whisper Pro"),
                type: .expired,
                onAddLicenseKey: onAddLicenseKey
            )
        case .licensed:
            EmptyView()
        }
    }
    
    // MARK: - Hero

    /// Pre-formatted stats handed to the selected layout variant.
    /// Each variant renders the time-saved headline plus these four stats exactly once.
    private var dashboardStats: DashboardStats {
        DashboardStats(
            timeSaved: hasLoadedStatsSnapshot ? formattedTimeSaved : String(localized: "Whisper Pro Insights"),
            timeSavedSeconds: timeSaved,
            sessions: hasLoadedStatsSnapshot ? Formatters.formattedNumber(totalCount) : "–",
            words: hasLoadedStatsSnapshot ? Formatters.formattedNumber(totalWords) : "–",
            wordsPerMinute: hasLoadedStatsSnapshot && averageWordsPerMinute > 0
                ? String(format: "%.0f", averageWordsPerMinute) : "–",
            keystrokes: hasLoadedStatsSnapshot ? Formatters.formattedNumber(totalKeystrokesSaved) : "–",
            wordsToday: hasLoadedStatsSnapshot ? Formatters.formattedNumber(wordsToday) : "–",
            hasLoaded: hasLoadedStatsSnapshot
        )
    }

    private var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            DashboardGreeting()

            Text("Here's how dictation is saving you time.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Renders the layout chosen in Settings → Interface. Kept for existing previews/settings variants.
    @ViewBuilder
    private var heroSection: some View {
        switch heroVariant {
        case .overview:
            DashboardOverviewSection(
                stats: dashboardStats,
                insightsData: insightsData
            )
        case .achievement, .compact:
            CompactClaudeView(stats: dashboardStats)
        case .spotlight, .milestone:
            SpotlightClaudeView(stats: dashboardStats)
        case .passport:
            ProductivityPassportOverviewView(stats: dashboardStats)
        case .logo, .quiet, .image:
            DreamOverviewView(stats: dashboardStats)
        case .commandCenter:
            DashboardCommandCenterLayout(stats: dashboardStats)
        case .calmEditorial:
            DashboardCalmEditorialLayout(stats: dashboardStats)
        }
    }

    private var footerActionsView: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: openModelStatsPanel) {
                footerActionLabel(icon: "gauge", title: "Model Performance", color: AppTheme.Sidebar.models)
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: true)
            .help("View transcription and enhancement model performance")

            Button(action: copySystemInfo) {
                footerActionLabel(
                    icon: isSystemInfoCopied ? "checkmark" : "doc.on.doc",
                    title: isSystemInfoCopied ? "Copied!" : "Copy System Info",
                    color: isSystemInfoCopied ? AppTheme.Sidebar.license : AppTheme.Sidebar.fallback
                )
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: true)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSystemInfoCopied)
        }
    }

    @ViewBuilder
    private func footerActionLabel(icon: String, title: LocalizedStringKey, color: Color) -> some View {
        HStack(alignment: .center, spacing: 8) {
            DashboardIconGlyph(systemName: icon, color: color, size: 13, frameSize: 16)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .frame(width: nil, height: 36, alignment: .center)
        .background(AppCardBackground(cornerRadius: 18))
    }

    private func copySystemInfo() {
        SystemInfoService.shared.copySystemInfoToClipboard()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isSystemInfoCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isSystemInfoCopied = false
            }
        }
    }
    
    private var formattedTimeSaved: String {
        let formatted = Formatters.formattedDuration(timeSaved, style: .abbreviated, fallback: "Time savings coming soon")
        return formatted
    }
    
    // MARK: - Computed Metrics

    private var estimatedTypingTime: TimeInterval {
        let averageTypingSpeed: Double = 35 // words per minute
        let estimatedTypingTimeInMinutes = Double(totalWords) / averageTypingSpeed
        return estimatedTypingTimeInMinutes * 60
    }

    private var timeSaved: TimeInterval {
        max(estimatedTypingTime - totalDuration, 0)
    }

    private var averageWordsPerMinute: Double {
        guard totalDuration > 0 else { return 0 }
        return Double(totalWords) / (totalDuration / 60.0)
    }

    private var totalKeystrokesSaved: Int {
        Int(Double(totalWords) * 5.0)
    }
    
}

private struct DashboardAccessibilityReminder: View {
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.Accent.fill)

                Image(systemName: "hand.raised")
                    .font(.system(size: 15, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppTheme.Accent.primary)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text("Enable Accessibility Access")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("Required for Whisper Pro shortcuts and app-wide controls to work properly.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Button("Open Settings", action: onOpenSettings)
                .controlSize(.small)
                .help("Open Accessibility settings")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppCardBackground(cornerRadius: 16))
    }
}

private enum Formatters {
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter
    }()
    
    static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.maximumUnitCount = 2
        return formatter
    }()
    
    static func formattedNumber(_ value: Int) -> String {
        return numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    static func formattedDuration(_ interval: TimeInterval, style: DateComponentsFormatter.UnitsStyle, fallback: String = "–") -> String {
        guard interval > 0 else { return fallback }
        durationFormatter.unitsStyle = style
        durationFormatter.allowedUnits = interval >= 3600 ? [.hour, .minute] : [.minute, .second]
        return durationFormatter.string(from: interval) ?? fallback
    }
}
