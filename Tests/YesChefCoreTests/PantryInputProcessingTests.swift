import XCTest
@testable import YesChefCore

final class PantryInputProcessingTests: XCTestCase {
    func testParseTranscriptPhrasesSplitsCommaAndNewlineAndAnd() {
        let transcript = "eggs, milk and garlic\nonion"

        let phrases = PantryInputProcessor.parseTranscriptPhrases(transcript)

        XCTAssertEqual(phrases, ["eggs", "milk", "garlic", "onion"])
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

    func testDetectEntriesMatchesSeededSynonyms() {
        let entries = PantryInputProcessor.detectEntries(from: "evoo, boneless chicken breast, pepper")

        XCTAssertEqual(entries.map(\.matchedIngredientName), ["Olive Oil", "Chicken Breast", "Black Pepper"])
        XCTAssertEqual(entries[0].confidence, .high)
        XCTAssertEqual(entries[1].confidence, .high)
        XCTAssertEqual(entries[2].confidence, .high)
        XCTAssertEqual(entries[0].quantity, "1")
        XCTAssertTrue(entries[0].isIncluded)
    }

    func testDetectEntriesMarksUnknownPhraseForReview() {
        let entries = PantryInputProcessor.detectEntries(from: "dragon fruit")

        XCTAssertEqual(entries.first?.matchedIngredientName, "dragon fruit")
        XCTAssertEqual(entries.first?.confidence, .needsReview)
    }
}
