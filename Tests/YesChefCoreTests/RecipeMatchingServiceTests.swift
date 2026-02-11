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

    func testUnlockSuggestionsRankByUnlockCount() {
        let recipes = makeRecipes()
        let pantry = [
            PantryItem(ingredientName: "butter", quantity: "1"),
            PantryItem(ingredientName: "salt", quantity: "1")
        ]

        let suggestions = matcher.topUnlockSuggestions(recipes: recipes, pantryItems: pantry, limit: 3)

        XCTAssertEqual(suggestions.first?.ingredient.name, "Olive Oil")
        XCTAssertEqual(suggestions.first?.unlockCount, 2)
        XCTAssertEqual(suggestions.count, 3)
    }

    func testDietFilteringKeepsOnlyEnabledTags() {
        let recipes = makeRecipes()
        let prefs = UserPrefs(enabledDiets: [.keto])

        let matches = matcher.match(recipes: recipes, pantryItems: [], userPrefs: prefs)

        XCTAssertEqual(matches.map(\.recipe.name), ["Spinach Omelet"])
    }

    private func makeRecipes() -> [Recipe] {
        [
            Recipe(
                id: UUID(uuidString: "CFFBD8E8-E40A-4045-A8A8-BDCC7F5F4EFF")!,
                name: "Spinach Omelet",
                prepMinutes: 5,
                cookMinutes: 7,
                nutrition: NutritionSummary(calories: 290, protein: 20, carbs: 4, fat: 15),
                dietTags: [.keto, .vegetarian, .highProtein],
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
                nutrition: NutritionSummary(calories: 420, protein: 21, carbs: 30, fat: 14),
                dietTags: [.vegetarian],
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
                nutrition: NutritionSummary(calories: 470, protein: 24, carbs: 58, fat: 16),
                dietTags: [.vegetarian],
                ingredients: [
                    RecipeIngredient(ingredientName: "Pasta", quantity: "8 oz"),
                    RecipeIngredient(ingredientName: "Butter", quantity: "2 tbsp"),
                    RecipeIngredient(ingredientName: "Garlic", quantity: "3 cloves"),
                    RecipeIngredient(ingredientName: "Salt", quantity: "1 tsp"),
                    RecipeIngredient(ingredientName: "Black Pepper", quantity: "1/2 tsp")
                ],
                instructions: []
            ),
            Recipe(
                id: UUID(uuidString: "8BBD9A0A-B1C6-4EB4-80BA-D4E9F7C36FD2")!,
                name: "Lemon Chicken Rice Bowl",
                prepMinutes: 12,
                cookMinutes: 20,
                nutrition: NutritionSummary(calories: 510, protein: 35, carbs: 45, fat: 12),
                dietTags: [.highProtein],
                ingredients: [
                    RecipeIngredient(ingredientName: "Chicken Breast", quantity: "1 lb"),
                    RecipeIngredient(ingredientName: "Rice", quantity: "1 cup"),
                    RecipeIngredient(ingredientName: "Lemon", quantity: "1"),
                    RecipeIngredient(ingredientName: "Olive Oil", quantity: "1 tbsp"),
                    RecipeIngredient(ingredientName: "Salt", quantity: "1 tsp")
                ],
                instructions: []
            )
        ]
    }
}
