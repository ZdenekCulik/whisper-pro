import XCTest
@testable import Whisper_Pro_iOS

final class TranscriptEditTests: XCTestCase {
    func testAppendOnlyInsertsSuffix() {
        let edit = TranscriptEdit.edit(from: "ahoj", to: "ahoj sve")
        XCTAssertEqual(edit.deleteCount, 0)
        XCTAssertEqual(edit.insert, " sve")
    }

    func testRewrittenTailDeletesOnlyDivergentPart() {
        let edit = TranscriptEdit.edit(from: "ahoj sve", to: "ahoj svete")
        XCTAssertEqual(edit.deleteCount, 0)
        XCTAssertEqual(edit.insert, "te")
    }

    func testChangedWordDeletesBackToCommonPrefix() {
        let edit = TranscriptEdit.edit(from: "ahoj svete", to: "ahoj lidi")
        XCTAssertEqual(edit.deleteCount, 5)
        XCTAssertEqual(edit.insert, "lidi")
    }

    func testIdenticalTextProducesNoEdit() {
        let edit = TranscriptEdit.edit(from: "ahoj", to: "ahoj")
        XCTAssertEqual(edit.deleteCount, 0)
        XCTAssertEqual(edit.insert, "")
    }

    func testEmptyTargetDeletesEverything() {
        let edit = TranscriptEdit.edit(from: "ahoj", to: "")
        XCTAssertEqual(edit.deleteCount, 4)
        XCTAssertEqual(edit.insert, "")
    }

    func testAccentedCharactersCountAsSingleCharacters() {
        let edit = TranscriptEdit.edit(from: "prislo", to: "prislozitost")
        XCTAssertEqual(edit.deleteCount, 0)
        XCTAssertEqual(edit.insert, "zitost")
    }
}
