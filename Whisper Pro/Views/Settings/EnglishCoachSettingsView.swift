import SwiftUI

/// Settings rows for the Ambient English Coach (toggle + native language).
struct EnglishCoachSettingsView: View {
    @AppStorage("englishCoachEnabled") private var enabled = false
    @AppStorage("englishCoachNativeLanguage") private var nativeLanguage = "cs"

    private let languages: [(code: String, name: String)] = [
        ("cs", "Czech"), ("sk", "Slovak"), ("de", "German"),
        ("pl", "Polish"), ("es", "Spanish"), ("fr", "French"),
        ("it", "Italian"), ("pt", "Portuguese"), ("uk", "Ukrainian")
    ]

    var body: some View {
        Toggle(isOn: $enabled) {
            HStack(spacing: 4) {
                Text("English Coach")
                InfoTip("After each English dictation, Whisper Pro points out one phrase you could say more naturally — so you pick up the language as you work.")
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)

        if enabled {
            Picker("My native language", selection: $nativeLanguage) {
                ForEach(languages, id: \.code) { language in
                    Text(language.name).tag(language.code)
                }
            }
            .pickerStyle(.menu)
        }
    }
}
