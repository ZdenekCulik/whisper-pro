import XCTest
@testable import Whisper_Pro_iOS

@MainActor
final class DictationSessionTests: XCTestCase {
    func testStartsIdle() {
        let session = DictationSession()
        XCTAssertEqual(session.state, .idle)
        XCTAssertEqual(session.partialText, "")
        XCTAssertEqual(session.committedText, "")
    }

    func testMissingAPIKeyFailsWithMessage() async {
        let session = DictationSession(apiKeyProvider: { nil })
        await session.start()
        XCTAssertEqual(session.state, .failed("Add your Soniox API key in the Whisper Pro app."))
    }

    func testPartialEventUpdatesPartialText() {
        let session = DictationSession()
        session.apply(.partial(text: "ahoj sve"))
        XCTAssertEqual(session.partialText, "ahoj sve")
        XCTAssertEqual(session.committedText, "")
    }

    func testCommittedEventMovesTextToCommittedAndClearsPartial() {
        let session = DictationSession()
        session.apply(.partial(text: "ahoj svete"))
        session.apply(.committed(text: "ahoj svete"))
        XCTAssertEqual(session.committedText, "ahoj svete")
        XCTAssertEqual(session.partialText, "")
    }

    func testErrorEventSetsFailedState() {
        let session = DictationSession()
        session.apply(.error("socket closed"))
        XCTAssertEqual(session.state, .failed("socket closed"))
    }
}
