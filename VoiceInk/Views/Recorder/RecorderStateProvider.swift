import Foundation

// Protocol for objects that provide live recorder state to the UI.
@MainActor
protocol RecorderStateProvider: AnyObject {
    var recordingState: RecordingState { get }
    var partialTranscript: String { get }
    // Stable committed text vs the revising tail, for jump-free live rendering.
    var committedTranscript: String { get }
    var partialTail: String { get }
}
