import XCTest
@testable import YesChefCore

final class PantryViewModelTests: XCTestCase {
    func testAddDetectedEntriesRespectsInclusionAndQuantity() {
        let viewModel = PantryViewModel()
        let entries = [
            DetectedPantryEntry(rawText: "eggs", matchedIngredientName: "Egg", matchedIngredientID: "egg", confidence: .high, quantity: "2", isIncluded: true),
            DetectedPantryEntry(rawText: "milk", matchedIngredientName: "Milk", matchedIngredientID: "milk", confidence: .high, quantity: "1", isIncluded: false)
        ]

        let added = viewModel.addDetectedEntries(entries, source: .spoken, rawInput: "eggs, milk")

        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.ingredientName, "Egg")
        XCTAssertEqual(added.first?.quantity, "2")
    }

    func testAddDetectedEntriesDedupesAgainstExistingPantryItems() {
        let existing = PantryItem(
            ingredientName: "Egg",
            quantity: "1",
            source: .typed,
            canonicalIngredientID: "egg",
            canonicalIngredientName: "Egg"
        )
        let viewModel = PantryViewModel(pantryItems: [existing])
        let entries = [
            DetectedPantryEntry(rawText: "eggs", matchedIngredientName: "Egg", matchedIngredientID: "egg", confidence: .high),
            DetectedPantryEntry(rawText: "whole milk", matchedIngredientName: "Milk", matchedIngredientID: "milk", confidence: .high)
        ]

        let added = viewModel.addDetectedEntries(entries, source: .spoken)

        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.ingredientName, "Milk")
        XCTAssertEqual(viewModel.pantryItems.count, 2)
    }

    func testUpdateEntryTextProvidesAutocompleteSuggestionsForPartialInput() {
        let viewModel = PantryViewModel()

        viewModel.updateEntryText("sp")

        XCTAssertTrue(viewModel.suggestions.contains(where: { $0.name == "Spinach" }))
    }

    func testChooseSuggestionClearsSuggestionsAndSetsPendingName() {
        let viewModel = PantryViewModel()
        viewModel.updateEntryText("sp")
        guard let suggestion = viewModel.suggestions.first(where: { $0.name == "Spinach" }) else {
            XCTFail("Expected Spinach suggestion")
            return
        }

        viewModel.chooseSuggestion(suggestion)

        XCTAssertEqual(viewModel.pendingIngredientName, "Spinach")
        XCTAssertTrue(viewModel.suggestions.isEmpty)
    }

    func testConfirmSaveRequiresSuggestionSelectionWhenConfigured() {
        let viewModel = PantryViewModel()

        viewModel.updateEntryText("pep")

        XCTAssertNil(viewModel.confirmSave(quantity: "1", requireSuggestionSelection: true))
        XCTAssertTrue(viewModel.pantryItems.isEmpty)
    }

    func testConfirmSaveAllowsExactMatchWithoutExplicitSelection() {
        let viewModel = PantryViewModel()

        viewModel.updateEntryText("Black pepper")

        let saved = viewModel.confirmSave(quantity: "1", requireSuggestionSelection: true)
        XCTAssertEqual(saved?.ingredientName, "Black pepper")
    }

    func testConfirmSaveSucceedsAfterChoosingSuggestionWhenSelectionRequired() {
        let viewModel = PantryViewModel()
        viewModel.updateEntryText("pep")
        guard let suggestion = viewModel.suggestions.first(where: { $0.name == "Black pepper" }) else {
            XCTFail("Expected Black pepper suggestion")
            return
        }

        viewModel.chooseSuggestion(suggestion)
        let saved = viewModel.confirmSave(quantity: "1", requireSuggestionSelection: true)

        XCTAssertEqual(saved?.ingredientName, "Black pepper")
        XCTAssertEqual(viewModel.pantryItems.first?.ingredientName, "Black pepper")
    }

    func testPepDoesNotAddUnlessSuggestionSelectedOrExactlyTyped() {
        let viewModel = PantryViewModel()

        viewModel.updateEntryText("pep")
        XCTAssertNil(viewModel.confirmSave(quantity: "1", requireSuggestionSelection: true))
        XCTAssertTrue(viewModel.pantryItems.isEmpty)

        viewModel.updateEntryText("Black pepper")
        XCTAssertNotNil(viewModel.confirmSave(quantity: "1", requireSuggestionSelection: true))
        XCTAssertEqual(viewModel.pantryItems.first?.ingredientName, "Black pepper")
    }

}
