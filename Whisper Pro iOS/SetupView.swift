import SwiftUI

struct SetupView: View {
    @State private var apiKey = ""
    @State private var savedKeyExists = SharedKeychain.get(forKey: SharedKeychain.sonioxKey) != nil
    @State private var microphoneGranted = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Soniox API key") {
                    SecureField("Paste your key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Save key") {
                        if SharedKeychain.save(apiKey, forKey: SharedKeychain.sonioxKey) {
                            savedKeyExists = true
                            apiKey = ""
                        }
                    }
                    .disabled(apiKey.isEmpty)

                    if savedKeyExists {
                        Label("Key saved", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                }

                Section("Microphone") {
                    Button("Allow microphone") {
                        Task { microphoneGranted = await IOSAudioRecorder.requestPermission() }
                    }
                    if microphoneGranted {
                        Label("Microphone allowed", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                }

                Section("Turn on the keyboard") {
                    Text("1. Open Settings, General, Keyboard, Keyboards.")
                    Text("2. Add New Keyboard and pick Whisper Pro.")
                    Text("3. Tap Whisper Pro and turn on Allow Full Access. The keyboard needs it to reach Soniox.")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            .navigationTitle("Whisper Pro")
        }
    }
}
