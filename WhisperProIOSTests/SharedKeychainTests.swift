import XCTest
@testable import Whisper_Pro_iOS

final class SharedKeychainTests: XCTestCase {
    private let key = "unitTestKey"

    override func tearDown() {
        _ = SharedKeychain.save("", forKey: key)
        super.tearDown()
    }

    func testSaveThenGetReturnsSameValue() {
        XCTAssertTrue(SharedKeychain.save("abc123", forKey: key))
        XCTAssertEqual(SharedKeychain.get(forKey: key), "abc123")
    }

    func testOverwriteReplacesValue() {
        XCTAssertTrue(SharedKeychain.save("first", forKey: key))
        XCTAssertTrue(SharedKeychain.save("second", forKey: key))
        XCTAssertEqual(SharedKeychain.get(forKey: key), "second")
    }

    func testMissingKeyReturnsNil() {
        XCTAssertNil(SharedKeychain.get(forKey: "keyThatWasNeverSaved"))
    }
}
