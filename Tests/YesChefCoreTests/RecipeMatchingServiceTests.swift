import XCTest
@testable import YesChefCore

final class RecipeMatchingServiceTests: XCTestCase {
    private let matcher = RecipeMatchingService()

    func testCookNowReturnsOnlyZeroMissingRecipes() {
        let recipes = makeRecipes()
        let pantry = [
            PantryItem(ingredientName: "eggs", quantity: "3"),
            PantryItem(ingredientName: "spinach", quantity: "1 cup"),
            PantryItem(ingredientName: "butter", quantity: "1 tsp"),
            PantryItem(ingredientName: "salt", quantity: "pinch"),
            PantryItem(ingredientName: "rice", quantity: "1 cup")
        ]

        let cookNow = matcher.cookNow(recipes: recipes, pantryItems: pantry)

        XCTAssertEqual(cookNow.count, 1)
        XCTAssertEqual(cookNow.first?.recipe.name, "Spinach Omelet")
        XCTAssertEqual(cookNow.first?.missingCount, 0)
    }

    func testAlmostThereAllowsUpToTwoMissingIngredients() throws {
        let recipes = makeRecipes()
        let pantry = [
            PantryItem(ingredientName: "black beans", quantity: "1 can"),
            PantryItem(ingredientName: "cheddar cheese", quantity: "1 cup"),
            PantryItem(ingredientName: "olive oil", quantity: "1 tbsp")
        ]

        let almostThere = matcher.almostThere(recipes: recipes, pantryItems: pantry)

        let skillet = try XCTUnwrap(almostThere.first(where: { $0.recipe.name == "Bean & Cheddar Skillet" }))
        XCTAssertEqual(skillet.missingCount, 2)
        XCTAssertTrue(skillet.isAlmostThere)
    }

    func testSynonymsAreCanonicalizedForMatching() throws {
        let recipes = makeRecipes()
        let pantry = [
            PantryItem(ingredientName: "spaghetti", quantity: "8 oz"),
            PantryItem(ingredientName: "salted butter", quantity: "2 tbsp"),
            PantryItem(ingredientName: "garlic cloves", quantity: "3"),
            PantryItem(ingredientName: "kosher salt", quantity: "1 tsp"),
            PantryItem(ingredientName: "pepper", quantity: "1/2 tsp")
        ]

        let matches = matcher.match(recipes: recipes, pantryItems: pantry)
        let pasta = try XCTUnwrap(matches.first(where: { $0.recipe.name == "Garlic Butter Pasta" }))

        XCTAssertEqual(pasta.missingCount, 0)
    }

    private func makeRecipes() -> [Recipe] {
        [
            Recipe(
                id: UUID(uuidString: "CFFBD8E8-E40A-4045-A8A8-BDCC7F5F4EFF")!,
                name: "Spinach Omelet",
                prepMinutes: 5,
                cookMinutes: 7,
                macroSummary: "Placeholder",
                ingredients: [
                    RecipeIngredient(ingredientName: "Egg", quantity: "3"),
                    RecipeIngredient(ingredientName: "Spinach", quantity: "1 cup"),
                    RecipeIngredient(ingredientName: "Butter", quantity: "1 tsp"),
                    RecipeIngredient(ingredientName: "Salt", quantity: "pinch")
                ],
                instructions: []
            ),
            Recipe(
                id: UUID(uuidString: "7E73024B-E73D-44EA-95B9-2F6BA6B48014")!,
                name: "Bean & Cheddar Skillet",
                prepMinutes: 8,
                cookMinutes: 12,
                macroSummary: "Placeholder",
                ingredients: [
                    RecipeIngredient(ingredientName: "Black Beans", quantity: "1 can"),
                    RecipeIngredient(ingredientName: "Cheddar", quantity: "1 cup"),
                    RecipeIngredient(ingredientName: "Onion", quantity: "1/2"),
                    RecipeIngredient(ingredientName: "Tomato", quantity: "1"),
                    RecipeIngredient(ingredientName: "Olive Oil", quantity: "1 tbsp")
                ],
                instructions: []
            ),
            Recipe(
                id: UUID(uuidString: "A6B5B97F-DA77-4A85-98B2-5165A6A39D91")!,
                name: "Garlic Butter Pasta",
                prepMinutes: 10,
                cookMinutes: 15,
                macroSummary: "Placeholder",
                ingredients: [
                    RecipeIngredient(ingredientName: "Pasta", quantity: "8 oz"),
                    RecipeIngredient(ingredientName: "Butter", quantity: "2 tbsp"),
                    RecipeIngredient(ingredientName: "Garlic", quantity: "3 cloves"),
                    RecipeIngredient(ingredientName: "Salt", quantity: "1 tsp"),
                    RecipeIngredient(ingredientName: "Black Pepper", quantity: "1/2 tsp")
                ],
                instructions: []
            )
        ]
    }
}
