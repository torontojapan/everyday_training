import XCTest
@testable import CerealExercise

@MainActor
final class FriendCodeValidatorTests: XCTestCase {

    func testGenerateProducesValidCode() {
        for _ in 0..<200 {
            let code = FriendCode.generate()
            XCTAssertEqual(code.count, FriendCode.length, "generated code must be exactly \(FriendCode.length) characters")
            XCTAssertTrue(FriendCodeValidator.isValid(code), "generated code '\(code)' failed validation")
            // No ambiguous chars sneak in
            for ch in "O0I1" {
                XCTAssertFalse(code.contains(ch), "generated code '\(code)' contained banned char '\(ch)'")
            }
        }
    }

    func testIsValidLengthBoundaries() {
        XCTAssertFalse(FriendCodeValidator.isValid(""))
        XCTAssertFalse(FriendCodeValidator.isValid("ABCDE"))    // 5
        XCTAssertTrue(FriendCodeValidator.isValid("ABCDEF"))    // 6
        XCTAssertFalse(FriendCodeValidator.isValid("ABCDEFG"))  // 7
    }

    func testIsValidRejectsAmbiguousChars() {
        XCTAssertFalse(FriendCodeValidator.isValid("ABCDE0"), "must reject digit 0")
        XCTAssertFalse(FriendCodeValidator.isValid("ABCDE1"), "must reject digit 1")
        XCTAssertFalse(FriendCodeValidator.isValid("ABCDEO"), "must reject letter O")
        XCTAssertFalse(FriendCodeValidator.isValid("ABCDEI"), "must reject letter I")
    }

    func testIsValidRejectsLowercase() {
        // FriendCode.alphabet is uppercase only; sanitize() uppercases before checking
        XCTAssertFalse(FriendCodeValidator.isValid("abcdef"))
    }

    func testIsValidRejectsSpecialChars() {
        XCTAssertFalse(FriendCodeValidator.isValid("ABC-EF"))
        XCTAssertFalse(FriendCodeValidator.isValid("ABC EF"))
        XCTAssertFalse(FriendCodeValidator.isValid("ABC@EF"))
    }

    func testSanitizeUppercases() {
        XCTAssertEqual(FriendCodeValidator.sanitize("abcdef"), "ABCDEF")
    }

    func testSanitizeStripsAmbiguousAndPunctuation() {
        // 0 / I / O / 1 / spaces / dashes all dropped
        XCTAssertEqual(FriendCodeValidator.sanitize("abc-d 0 e1OIf"), "ABCDEF")
    }

    func testSanitizeClipsToSixChars() {
        XCTAssertEqual(FriendCodeValidator.sanitize("ABCDEFGHJK"), "ABCDEF")
    }

    func testSanitizeEmptyStaysEmpty() {
        XCTAssertEqual(FriendCodeValidator.sanitize(""), "")
        XCTAssertEqual(FriendCodeValidator.sanitize("0011IIOO"), "", "all-banned input collapses to empty")
    }
}
