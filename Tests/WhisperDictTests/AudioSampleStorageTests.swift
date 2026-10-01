import XCTest
@testable import WhisperDict

final class AudioSampleStorageTests: XCTestCase {
    func testPreservesBufferOrderAndEmptiesAfterTake() {
        let storage = AudioSampleStorage()
        storage.append([0.1, 0.2])
        storage.append([0.3])
        XCTAssertEqual(storage.take(), [0.1, 0.2, 0.3])
        XCTAssertTrue(storage.take().isEmpty)
    }
}
