import XCTest
@testable import YesChefCore

final class PantryInputProcessingTests: XCTestCase {
    func testParseTranscriptPhrasesSplitsCommaNewlineAndAndSpaces() {
        let transcript = "eggs, milk and garlic\nonion basil parsley"

        let phrases = PantryInputProcessor.parseTranscriptPhrases(transcript)

        XCTAssertEqual(phrases, ["eggs", "milk", "garlic", "onion", "basil", "parsley"])
    }

    func testParseTranscriptPhrasesSplitsAmpersand() {
        let transcript = "milk & eggs & basil"

        let phrases = PantryInputProcessor.parseTranscriptPhrases(transcript)

        XCTAssertEqual(phrases, ["milk", "eggs", "basil"])
    }

    func testParseTranscriptPhrasesDedupesCaseInsensitively() {
        let transcript = "Eggs, eggs, EGGS and milk"

        let phrases = PantryInputProcessor.parseTranscriptPhrases(transcript)

        XCTAssertEqual(phrases, ["Eggs", "milk"])
    }

    func testParseTranscriptTokensExcludesTrailingTokenDuringLiveCapture() {
        let transcript = "eggs butter basi"

        let phrases = PantryInputProcessor.parseTranscriptTokens(transcript, includeTrailingToken: false)

        XCTAssertEqual(phrases, ["eggs", "butter"])
    }

    func testDetectEntriesMatchesSeededSynonyms() {
        let entries = PantryInputProcessor.detectEntries(from: "evoo, chicken pepper")

        XCTAssertEqual(entries.map(\.matchedIngredientName), ["Olive Oil", "Chicken Breast", "Black Pepper"])
        XCTAssertEqual(entries[0].confidence, .high)
        XCTAssertEqual(entries[1].confidence, .high)
        XCTAssertEqual(entries[2].confidence, .high)
        XCTAssertEqual(entries[0].quantity, "1")
        XCTAssertTrue(entries[0].isIncluded)
    }

    func testDetectEntriesMarksUnknownTokenForReview() {
        let entries = PantryInputProcessor.detectEntries(from: "dragonfruit")

        XCTAssertEqual(entries.first?.matchedIngredientName, "dragonfruit")
        XCTAssertEqual(entries.first?.confidence, .needsReview)
    }
}
