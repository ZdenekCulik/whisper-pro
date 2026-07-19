import SwiftUI

struct AudioSetupView: View {
    @ObservedObject private var audioDeviceManager = AudioDeviceManager.shared
    @ObservedObject private var mediaController = MediaController.shared
    @ObservedObject private var playbackController = PlaybackController.shared
    @State private var refreshIconRotation = 0.0

    var body: some View {
        Form {
            Section {
                inputSettingsRows
            } header: {
                Text("Audio Input")
            }

            Section {
                CustomSoundSettingsView()
            } header: {
                Text("Recording Sounds")
            }

            Section {
                Toggle("Mute Audio While Recording", isOn: $mediaController.isSystemMuteEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Toggle("Pause Media While Recording", isOn: $playbackController.isPauseMediaEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            } header: {
                Text("Recording Behavior")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear {
            pinToSingleMicrophoneMode()
        }
    }

    @ViewBuilder
    private var inputSettingsRows: some View {
        Picker("Microphone", selection: microphoneSourceSelection) {
            Text(systemDefaultSourceTitle).tag(MicrophoneSourceSelection.systemDefault)

            ForEach(audioDeviceManager.availableDevices, id: \.uid) { device in
                Text(device.name).tag(MicrophoneSourceSelection.device(device.uid))
            }
        }
        .pickerStyle(.menu)

        Button {
            refreshMicrophones()
        } label: {
            Label {
                Text("Refresh Microphones")
            } icon: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(refreshIconRotation))
            }
        }
        .buttonStyle(.borderless)
        .help("Refresh Microphones")
    }

    private var microphoneSourceSelection: Binding<MicrophoneSourceSelection> {
        Binding(
            get: { currentMicrophoneSource },
            set: { selection in selectMicrophoneSource(selection) }
        )
    }

    private var currentMicrophoneSource: MicrophoneSourceSelection {
        switch audioDeviceManager.inputMode {
        case .systemDefault:
            return .systemDefault
        case .custom:
            if let selectedDeviceUID {
                return .device(selectedDeviceUID)
            }
            return .systemDefault
        case .prioritized:
            return .systemDefault
        }
    }

    private func selectMicrophoneSource(_ selection: MicrophoneSourceSelection) {
        switch selection {
        case .systemDefault:
            audioDeviceManager.selectInputMode(.systemDefault)
        case .device(let uid):
            guard let device = audioDeviceManager.availableDevices.first(where: { $0.uid == uid }) else {
                audioDeviceManager.selectInputMode(.systemDefault)
                return
            }
            audioDeviceManager.selectDeviceAndSwitchToCustomMode(id: device.id)
        }
    }

    /// Legacy installs may still have `.prioritized` persisted from before the
    /// Priority Order UI was removed — pin back to the simple selected-microphone mode.
    private func pinToSingleMicrophoneMode() {
        guard audioDeviceManager.inputMode == .prioritized else { return }
        audioDeviceManager.selectInputMode(.systemDefault)
    }

    private var selectedDeviceUID: String? {
        guard let selectedDeviceID = audioDeviceManager.selectedDeviceID else { return nil }
        return audioDeviceManager.availableDevices.first { $0.id == selectedDeviceID }?.uid
    }

    private var systemDefaultSourceTitle: String {
        guard let name = audioDeviceManager.getSystemDefaultDeviceName() else {
            return String(localized: "System Default")
        }
        return String(format: String(localized: "System Default (%@)"), name)
    }

    private func refreshMicrophones() {
        withAnimation(.easeInOut(duration: 0.35)) {
            refreshIconRotation += 360
        }
        audioDeviceManager.loadAvailableDevices()
    }
}

private enum MicrophoneSourceSelection: Hashable {
    case systemDefault
    case device(String)
}
