import SwiftUI
import Cocoa
import Carbon.HIToolbox
import LaunchAtLogin

struct SettingsView: View {
    @EnvironmentObject private var menuBarManager: MenuBarManager
    @EnvironmentObject private var recordingShortcutManager: RecordingShortcutManager
    @EnvironmentObject private var recorderUIManager: RecorderUIManager
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var widgetVariantStore = WidgetVariantStore.shared
    @AppStorage("restoreClipboardAfterPaste") private var restoreClipboardAfterPaste = true
    @AppStorage("clipboardRestoreDelay") private var clipboardRestoreDelay = 2.0
    @AppStorage("WaveformStyle") private var waveformStyle = 1
    @AppStorage("dashboardUserName") private var dashboardUserName = ""
    @AppStorage("dashboardAvatarInitials") private var dashboardAvatarInitials = ""
    @AppStorage("sonioxBalanceUSD") private var sonioxBalanceUSD = 0.0
    @AppStorage("sonioxBalanceSetDate") private var sonioxBalanceSetDate = 0.0
    @AppStorage("sonioxBalanceLabel") private var sonioxBalanceLabel = "Soniox"
    @AppStorage("dashboardChartLogStrength") private var dashboardChartLogStrength = 1.0
    @State private var sonioxBalanceText = ""
    @State private var isSonioxBalanceHighlighted = false
    @State private var showSonioxBalanceSaved = false
    @State private var hasCancelRecordingShortcut = ShortcutStore.shortcut(for: .cancelRecorder) != nil
    @State private var cancelRecordingShortcutRecorderResetID = 0

    @State private var isRestoreClipboardExpanded = false
    // Ordered, not a Set: the first element is the primary language (see
    // UserDefaults.preferredLanguageHints), which Soniox now leans on to resolve ambiguous
    // words, so selection order has to survive a round-trip.
    @State private var preferredLanguageCodes: [String] = UserDefaults.standard.preferredLanguageHints
    // Cmd+W hides the window via orderOut instead of closing it, so .onDisappear never
    // fires — this tracks that hide/show separately to stop the preview animations too.
    @State private var isSettingsVisible = true

    var body: some View {
        ScrollViewReader { scrollProxy in
        Form {
            Section {
                LabeledContent("Primary Shortcut") {
                    HStack(spacing: 8) {
                        Spacer()
                        shortcutModePicker(binding: $recordingShortcutManager.primaryRecordingShortcutMode)
                        ShortcutRecorder(action: .primaryRecording) {
                            recordingShortcutManager.primaryRecordingShortcut = .custom
                            recordingShortcutManager.updateShortcutStatus()
                        }
                        .controlSize(.small)
                    }
                }

                if recordingShortcutManager.secondaryRecordingShortcut != .none {
                    LabeledContent("Secondary Shortcut") {
                        HStack(spacing: 8) {
                            Spacer()
                            shortcutModePicker(binding: $recordingShortcutManager.secondaryRecordingShortcutMode)
                            ShortcutRecorder(action: .secondaryRecording) {
                                recordingShortcutManager.secondaryRecordingShortcut = .custom
                                recordingShortcutManager.updateShortcutStatus()
                            }
                            .controlSize(.small)
                            Button {
                                withAnimation { recordingShortcutManager.secondaryRecordingShortcut = .none }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if recordingShortcutManager.secondaryRecordingShortcut == .none {
                    Button("Add Second Shortcut") {
                        withAnimation { recordingShortcutManager.secondaryRecordingShortcut = .custom }
                    }
                }

                LabeledContent("Cancel Recording") {
                    HStack(spacing: 8) {
                        ShortcutRecorder(
                            action: .cancelRecorder,
                            defaultShortcut: Self.defaultCancelRecordingShortcut
                        ) {
                            hasCancelRecordingShortcut = true
                        }
                            .id(cancelRecordingShortcutRecorderResetID)
                            .controlSize(.small)

                        Button {
                            ShortcutStore.setShortcut(nil, for: .cancelRecorder)
                            hasCancelRecordingShortcut = false
                            cancelRecordingShortcutRecorderResetID += 1
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .buttonStyle(.plain)
                        .help("Reset to default")
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: ShortcutStore.shortcutDidChange)) { notification in
                    guard let action = notification.object as? ShortcutAction, action == .cancelRecorder else { return }
                    hasCancelRecordingShortcut = ShortcutStore.shortcut(for: .cancelRecorder) != nil
                }
            } header: {
                Text("Shortcuts")
            }

            Section("Pasting") {
                ExpandableSettingsRow(
                    isExpanded: $isRestoreClipboardExpanded,
                    isEnabled: $restoreClipboardAfterPaste,
                    label: "Keep Clipboard Content",
                    infoMessage: "Whisper Pro temporarily uses the clipboard to paste transcription. When enabled, it restores your previous clipboard content after the selected delay. When disabled, the pasted transcription stays on your clipboard."
                ) {
                    Picker("Restore Delay", selection: $clipboardRestoreDelay) {
                        Text("250ms").tag(0.25)
                        Text("500ms").tag(0.5)
                        Text("1s").tag(1.0)
                        Text("2s").tag(2.0)
                        Text("3s").tag(3.0)
                        Text("4s").tag(4.0)
                        Text("5s").tag(5.0)
                    }
                }
            }

            Section {
                // A wrapping flow, not a grid: LazyVGrid's adaptive column tracks (min
                // 120pt each) center every chip inside its own oversized track, which
                // read as a boxed-off area with big gaps between short chips and stranded
                // "+ Add another" on its own row. FlowLayout instead hugs each chip's
                // real width so this sits like a plain native settings row.
                FlowLayout(spacing: 8) {
                    ForEach(selectedLanguages) { language in
                        selectedLanguageChip(language)
                    }
                    addLanguageMenu
                }
                .padding(.vertical, 4)
            } header: {
                HStack(spacing: 4) {
                    Text("Languages")
                    InfoTip("Languages you dictate in. Whisper Pro auto-detects among these. At least one language must stay selected.")
                }
            }

            Section("Interface") {
                Picker("Appearance", selection: $themeManager.skin) {
                    ForEach(AppSkin.allCases) { skin in
                        Text(skin.displayName).tag(skin)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Recorder Style", selection: $recorderUIManager.recorderPanelStyle) {
                    ForEach(RecorderPanelStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Panel Look")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        ForEach(WidgetVariant.allCases) { variant in
                            PanelLookPreviewSlot(
                                variant: variant,
                                isSelected: widgetVariantStore.variant == variant,
                                isActive: isSettingsVisible
                            ) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    widgetVariantStore.variant = variant
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.vertical, 4)

                // The segmented picker was removed — the preview cards below are the
                // single control now (selection border + tap), same as Panel Look.
                VStack(alignment: .leading, spacing: 10) {
                    Text("Waveform")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        ForEach(WaveformStyleView.displayOrder, id: \.self) { i in
                            WaveformPreviewSlot(
                                style: i,
                                isSelected: waveformStyle == i,
                                // Only the selected card needs to keep animating while
                                // open; a non-selected one just sits on a static frame.
                                isActive: isSettingsVisible && waveformStyle == i
                            ) {
                                waveformStyle = i
                            }
                        }
                    }
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Activity Chart Scale")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(dashboardChartLogStrength < 0.05 ? "Linear" : (dashboardChartLogStrength > 0.95 ? "Logarithmic" : "Mixed"))
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    Slider(value: $dashboardChartLogStrength, in: 0...1)
                }
                .padding(.vertical, 4)
            }
            .onReceive(NotificationCenter.default.publisher(for: .mainWindowVisibilityChanged)) { note in
                let visible = (note.userInfo?["visible"] as? Bool) ?? true
                isSettingsVisible = visible
            }

            Section("General") {
                Toggle("Hide Dock Icon", isOn: $menuBarManager.isMenuBarOnly)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                LaunchAtLogin.Toggle("Launch at Login")
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            Section("Profile") {
                LabeledContent("Name") {
                    TextField("", text: $dashboardUserName, prompt: Text(defaultUserName))
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 200)
                }

                LabeledContent("Initials") {
                    TextField("", text: $dashboardAvatarInitials, prompt: Text(defaultInitials))
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .onChange(of: dashboardAvatarInitials) { _, newValue in
                            let capped = String(newValue.uppercased().prefix(3))
                            if capped != dashboardAvatarInitials { dashboardAvatarInitials = capped }
                        }
                }
                Text("Shown on the dashboard avatar. Leave blank to use initials from your name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent("Balance Label") {
                    TextField("", text: $sonioxBalanceLabel, prompt: Text("Soniox"))
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 200)
                }

                LabeledContent("\(sonioxBalanceLabelOrDefault) Balance") {
                    HStack(spacing: 8) {
                        if showSonioxBalanceSaved {
                            Label("Saved", systemImage: "checkmark")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .transition(.opacity)
                        } else if isSonioxBalanceTextDirty {
                            Button("Confirm", action: saveSonioxBalance)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $sonioxBalanceText)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onSubmit(saveSonioxBalance)
                    }
                }
                .id("sonioxBalanceField")
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(isSonioxBalanceHighlighted ? 0.15 : 0))
                )
                Text("Enter your current \(sonioxBalanceLabelOrDefault) balance, then confirm. Whisper Pro tracks spend since then to estimate what's left.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("English Coach") {
                EnglishCoachSettingsView()
            }

            Section("AI Enhancement") {
                AIEnhancementSettingsView()
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear {
            sonioxBalanceText = sonioxBalanceUSD > 0 ? String(format: "%.2f", sonioxBalanceUSD) : ""
        }
        .onReceive(NotificationCenter.default.publisher(for: .scrollToSonioxBalance)) { _ in
            withAnimation { scrollProxy.scrollTo("sonioxBalanceField", anchor: .center) }
            withAnimation(.easeIn(duration: 0.2)) { isSonioxBalanceHighlighted = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.4)) { isSonioxBalanceHighlighted = false }
            }
        }
        }
    }

    private var defaultUserName: String {
        let full = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        let first = full.split(separator: " ").first.map(String.init) ?? full
        return first.isEmpty ? "Zdeněk" : first
    }

    private var defaultInitials: String {
        let chars = dashboardUserName.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ").prefix(2).compactMap(\.first)
        let value = String(chars).uppercased()
        return value.isEmpty ? "Z" : value
    }

    private var sonioxBalanceLabelOrDefault: String {
        let trimmed = sonioxBalanceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Soniox" : trimmed
    }

    private var isSonioxBalanceTextDirty: Bool {
        let saved = sonioxBalanceUSD > 0 ? String(format: "%.2f", sonioxBalanceUSD) : ""
        return sonioxBalanceText != saved
    }

    private func saveSonioxBalance() {
        guard let value = Double(sonioxBalanceText.replacingOccurrences(of: ",", with: ".")), value >= 0 else {
            sonioxBalanceText = sonioxBalanceUSD > 0 ? String(format: "%.2f", sonioxBalanceUSD) : ""
            return
        }
        sonioxBalanceUSD = value
        sonioxBalanceSetDate = Date().timeIntervalSince1970
        withAnimation(.easeIn(duration: 0.15)) { showSonioxBalanceSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.4)) { showSonioxBalanceSaved = false }
        }
    }

    private static let defaultCancelRecordingShortcut = Shortcut.key(
        keyCode: UInt16(kVK_Escape),
        modifierFlags: []
    )

    @ViewBuilder
    private func shortcutModePicker(binding: Binding<RecordingShortcutManager.Mode>) -> some View {
        Picker("", selection: binding) {
            ForEach(RecordingShortcutManager.Mode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .labelsHidden()
        .fixedSize()
    }

    // MARK: - Languages

    private static let supportedDictationLanguages: [DictationLanguage] = [
        DictationLanguage(code: "en", englishName: "English", nativeName: "English"),
        DictationLanguage(code: "cs", englishName: "Czech", nativeName: "Čeština"),
        DictationLanguage(code: "sk", englishName: "Slovak", nativeName: "Slovenčina"),
        DictationLanguage(code: "de", englishName: "German", nativeName: "Deutsch"),
        DictationLanguage(code: "fr", englishName: "French", nativeName: "Français"),
        DictationLanguage(code: "es", englishName: "Spanish", nativeName: "Español"),
        DictationLanguage(code: "it", englishName: "Italian", nativeName: "Italiano"),
        DictationLanguage(code: "pl", englishName: "Polish", nativeName: "Polski"),
        DictationLanguage(code: "pt", englishName: "Portuguese", nativeName: "Português"),
        DictationLanguage(code: "nl", englishName: "Dutch", nativeName: "Nederlands"),
        DictationLanguage(code: "uk", englishName: "Ukrainian", nativeName: "Українська"),
        DictationLanguage(code: "ru", englishName: "Russian", nativeName: "Русский")
    ]

    private var selectedLanguages: [DictationLanguage] {
        // Ordered by selection (preferredLanguageCodes), not catalog order, so the primary
        // language (the first hint) renders first and reads as primary.
        preferredLanguageCodes.compactMap { code in
            Self.supportedDictationLanguages.first { $0.code == code }
        }
    }

    private var remainingLanguages: [DictationLanguage] {
        Self.supportedDictationLanguages.filter { !preferredLanguageCodes.contains($0.code) }
    }

    private func selectedLanguageChip(_ language: DictationLanguage) -> some View {
        let canRemove = preferredLanguageCodes.count > 1

        return HStack(spacing: 6) {
            Text(language.englishName)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(AppTheme.Text.primary)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    toggleLanguage(language.code)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppTheme.Text.secondary.opacity(canRemove ? 1 : 0.4))
            }
            .buttonStyle(.plain)
            .disabled(!canRemove)
            .help(canRemove ? "Remove" : "At least one language must stay selected")
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(AppTheme.Surface.quaternaryFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(AppTheme.Border.subtle, lineWidth: 1)
        )
    }

    private var addLanguageMenu: some View {
        Menu {
            ForEach(remainingLanguages) { language in
                Button(language.label) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        toggleLanguage(language.code)
                    }
                }
            }
        } label: {
            Text("Add another")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.Text.secondary)
                .padding(.horizontal, 10)
                .frame(height: 28)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .opacity(remainingLanguages.isEmpty ? 0.35 : 1)
        .disabled(remainingLanguages.isEmpty)
    }

    private func toggleLanguage(_ code: String) {
        var codes = preferredLanguageCodes
        if let index = codes.firstIndex(of: code) {
            codes.remove(at: index)
        } else {
            codes.append(code)
        }

        // Never allow an empty selection.
        guard !codes.isEmpty else { return }

        preferredLanguageCodes = codes
        UserDefaults.standard.preferredLanguageHints = codes
    }
}

/// Drives just this card's fake audio meter off a TimelineView clock (display-link render
/// path) instead of a @Published tick, so the level animates without re-evaluating all of
/// SettingsView.body. `paused: !isActive` schedules nothing while the window is hidden.
private struct PanelLookPreviewSlot: View {
    let variant: WidgetVariant
    let isSelected: Bool
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !isActive)) { context in
            PanelLookPreviewCard(
                variant: variant,
                isSelected: isSelected,
                audioMeter: FakeSpeechMeter.meter(at: context.date.timeIntervalSinceReferenceDate),
                isActive: isActive,
                action: action
            )
        }
    }
}

/// One selectable preview card for the "Panel Look" setting. Renders the REAL
/// `Variant2View` / `Variant16View` (same code path the floating panel uses) — not a
/// hand-drawn stand-in. Each variant is laid out at its own known, fixed natural size
/// (`classicNaturalSize` / `minimalNaturalSize`) and shrunk with a constant
/// `scaleEffect`; there's no runtime GeometryReader measurement (these views report the
/// proposed size, not an intrinsic one, so there's nothing reliable to measure), and the
/// short static demo text in `previewContext` never re-flows, so the natural size never
/// changes either. A bundled macOS wallpaper stands in for the desktop behind the panel,
/// the same trick System Settings' own Appearance thumbnails use. Tapping selects it;
/// the selected card gets an accent border.
private struct PanelLookPreviewCard: View {
    let variant: WidgetVariant
    let isSelected: Bool
    let audioMeter: AudioMeter
    let isActive: Bool
    let action: () -> Void

    // fileprivate (not private): reused by WaveformPreviewSlot so the Waveform demo
    // cards sit on the exact same stage as these Panel Look cards.
    fileprivate static let cardWidth: CGFloat = 210
    fileprivate static let cardHeight: CGFloat = 110

    // Single constant scale applied to both variants so their real relative
    // proportions to each other (Classic 384pt vs Minimal's fixed 420pt) carry over
    // into the miniature instead of both being force-fit to the same width.
    private static let previewScale: CGFloat = 0.42
    // Variant2View's own default expanded width (see Variant2View.defaultWidth) and a
    // fixed height comfortably taller than the 2-line demo text + waveform row + its
    // own bottom padding (~128pt), so nothing clips inside this container before the
    // scaleEffect below.
    private static let classicNaturalSize = CGSize(width: 384, height: 150)
    // Variant16View's capsule is a fixed, non-resizable width (Variant16View.maxTextWidth);
    // height covers the capsule plus its own bottom padding.
    private static let minimalNaturalSize = CGSize(width: 420, height: 80)

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Self.stage
                    mockup
                }
                .frame(width: Self.cardWidth, height: Self.cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Color.white : AppTheme.Border.subtle, lineWidth: isSelected ? 2 : 1)
                )

                Text(variant.displayName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : AppTheme.Text.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // The desktop backdrop behind the floating panel: the user's OWN current wallpaper,
    // asked from macOS at runtime — so the preview always matches their real desktop and
    // no Apple imagery ships inside the repo. Dynamic/aerial wallpapers can hand back a
    // URL that isn't a loadable image, so fall back to the bundled-with-macOS Sonoma
    // picture, then to the synthetic gradient.
    private static let systemWallpaper: NSImage? = {
        // 1) A custom stage image dropped into the app's Application Support folder wins
        //    (lets the author use a specific wallpaper without shipping it in the repo).
        let custom = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("com.prakashjoshipax.WhisperPro/PanelPreviewWallpaper.jpg")
        if let custom, let image = NSImage(contentsOf: custom), image.isValid {
            return image
        }
        // 2) The user's own desktop wallpaper.
        if let screen = NSScreen.main,
           let url = NSWorkspace.shared.desktopImageURL(for: screen),
           let image = NSImage(contentsOf: url), image.isValid {
            return image
        }
        // 3) The Sonoma picture every macOS ships with.
        return NSImage(contentsOfFile: "/System/Library/Desktop Pictures/Sonoma.heic")
    }()

    fileprivate static var stage: some View {
        ZStack {
            if let wallpaper = systemWallpaper {
                Image(nsImage: wallpaper)
                    .resizable()
                    .scaledToFill()
            } else {
                syntheticStage
            }
        }
        .clipped()
    }

    private static var syntheticStage: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0x1a / 255, green: 0x21 / 255, blue: 0x51 / 255),
                    Color(red: 0x4a / 255, green: 0x3f / 255, blue: 0x78 / 255),
                    Color(red: 0x2d / 255, green: 0x6a / 255, blue: 0x8a / 255),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 0x4a / 255, green: 0x3f / 255, blue: 0x78 / 255), .clear],
                    center: .center, startRadius: 0, endRadius: 110
                ))
                .frame(width: 170, height: 170)
                .blur(radius: 28)
                .offset(x: -65, y: -35)
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 0x2d / 255, green: 0x6a / 255, blue: 0x8a / 255), .clear],
                    center: .center, startRadius: 0, endRadius: 95
                ))
                .frame(width: 150, height: 150)
                .blur(radius: 28)
                .offset(x: 75, y: 25)
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 0x1a / 255, green: 0x21 / 255, blue: 0x51 / 255).opacity(0.85), .clear],
                    center: .center, startRadius: 0, endRadius: 85
                ))
                .frame(width: 130, height: 130)
                .blur(radius: 24)
                .offset(x: 15, y: 45)
        }
        .clipped()
    }

    @ViewBuilder
    private var mockup: some View {
        // While inactive (settings window hidden), don't even construct the real
        // Variant2View/Variant16View subtree — both embed their own always-on
        // TimelineView clocks that an `isActive` flag passed into them wouldn't pause.
        if isActive {
            switch variant {
            case .v2:  classicMockup
            case .v16: minimalMockup
            }
        }
    }

    // Short, static demo content shared by both variants — it never changes, so the
    // fixed natural-size containers above always render at the same size.
    private var previewContext: WidgetVariantContext {
        WidgetVariantContext(
            committed: "Testing this out",
            partial: "",
            audioMeter: audioMeter,
            recordingState: .recording
        )
    }

    // Classic (V2): the REAL Variant2View, laid out at its own natural expanded size
    // and shrunk to card scale.
    private var classicMockup: some View {
        Variant2View(context: previewContext)
            .frame(width: Self.classicNaturalSize.width, height: Self.classicNaturalSize.height)
            .scaleEffect(Self.previewScale)
            .frame(
                width: Self.classicNaturalSize.width * Self.previewScale,
                height: Self.classicNaturalSize.height * Self.previewScale
            )
            .allowsHitTesting(false)
            .clipped()
    }

    // Minimal (V16): the REAL Variant16View, same treatment.
    private var minimalMockup: some View {
        Variant16View(context: previewContext)
            .frame(width: Self.minimalNaturalSize.width, height: Self.minimalNaturalSize.height)
            .scaleEffect(Self.previewScale)
            .frame(
                width: Self.minimalNaturalSize.width * Self.previewScale,
                height: Self.minimalNaturalSize.height * Self.previewScale
            )
            .allowsHitTesting(false)
            .clipped()
    }
}

/// Drives just this card's fake audio meter off a TimelineView clock (display-link render
/// path) instead of a @Published tick, so the level animates without re-evaluating all of
/// SettingsView.body. `paused: !isActive` schedules nothing while the window is hidden.
private struct WaveformPreviewSlot: View {
    let style: Int
    let isSelected: Bool
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !isActive)) { context in
            content(audioMeter: FakeSpeechMeter.meter(at: context.date.timeIntervalSinceReferenceDate))
        }
    }

    private func content(audioMeter: AudioMeter) -> some View {
        VStack(spacing: 8) {
            ZStack {
                // Same dimmed-desktop stage as the Panel Look cards above, so the two
                // preview rows read as one consistent system instead of one sitting on
                // plain black and the other on the gradient.
                PanelLookPreviewCard.stage

                // Pass the real measured width, not WaveformStyleView's fixed 132pt
                // default — this is exactly what the live pill's waveformCycler does, and
                // it's what makes "claude" actually span edge-to-edge here instead of
                // sitting in a narrow canvas centered inside the card ("bars" still centers
                // itself within whatever width it's given, so both stay faithful).
                GeometryReader { geo in
                    WaveformStyleView(
                        style: style,
                        audioMeter: audioMeter,
                        isActive: isActive,
                        width: geo.size.width
                    )
                }
                .frame(width: 150, height: 28)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                // Dark tint stands in for the pill's own near-black chrome, so it still
                // reads clearly against the lighter stage behind it — glass just adds
                // the refraction texture on macOS 26+.
                .glassSurface(cornerRadius: 10, tint: GlassSurface.darkChromeTint) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black)
                }
            }
            .frame(width: PanelLookPreviewCard.cardWidth, height: PanelLookPreviewCard.cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.white : AppTheme.Border.subtle, lineWidth: isSelected ? 2 : 1)
            )

            Text(WaveformStyleView.styleNames[style].capitalized)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : AppTheme.Text.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}

/// Drives Settings' preview cards (Panel Look + Waveform) with a fake but natural-looking
/// "someone is speaking" audio envelope, so those previews animate continuously instead
/// of sitting on a static level or (worse) static swapped-in text. A pure function of time
/// (no per-tick state), evaluated straight from the TimelineView clock in each slot.
private enum FakeSpeechMeter {
    static func meter(at t: TimeInterval) -> AudioMeter {
        // Layer a slow phrase-level rise/fall with a faster syllable-level wobble so
        // the level reads as speech (bursts of louder words, brief dips) rather than a
        // steady tone or a single sine wave.
        let phrase = sin(t * 0.6) * 0.5 + 0.5
        let syllable = sin(t * 5.2) * 0.5 + 0.5
        let envelope = max(0, phrase * 0.7 + syllable * 0.3 - 0.15)
        return AudioMeter(averagePower: min(1, envelope * 0.75), peakPower: min(1, envelope))
    }
}

private struct DictationLanguage: Identifiable {
    let code: String
    let englishName: String
    let nativeName: String

    var id: String { code }

    var label: String {
        englishName == nativeName ? englishName : "\(englishName) (\(nativeName))"
    }
}

extension Text {
    func settingsDescription() -> some View {
        self
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
