import XCTest
@testable import WhisperDict

final class TextProcessorTests: XCTestCase {
    func testNormalizesWhitespaceArtifactsAndPunctuation() {
        XCTAssertEqual(TextProcessor.process("  hello   [BLANK_AUDIO] world "), "Hello world.")
    }
    func testCanRemoveFillers() {
        XCTAssertEqual(TextProcessor.process("um, this is uh fine", removeFillers: true), ", this is fine.")
    }
}
