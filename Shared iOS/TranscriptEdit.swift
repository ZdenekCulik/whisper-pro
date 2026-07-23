import Foundation

/// Computes the minimal edit needed to turn the text already inserted in the
/// text field into the newest transcript, so live updates do not flicker.
enum TranscriptEdit {
    static func edit(from current: String, to target: String) -> (deleteCount: Int, insert: String) {
        let currentChars = Array(current)
        let targetChars = Array(target)

        var shared = 0
        while shared < currentChars.count,
              shared < targetChars.count,
              currentChars[shared] == targetChars[shared] {
            shared += 1
        }

        return (
            deleteCount: currentChars.count - shared,
            insert: String(targetChars[shared...])
        )
    }
}
