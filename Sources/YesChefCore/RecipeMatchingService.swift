import Foundation

public struct RecipeMatchingService {
    public init() {}

    public func match(recipes: [Recipe], pantryItems: [PantryItem], userPrefs: UserPrefs = UserPrefs()) -> [RecipeMatchResult] {
        let pantrySet = Set(pantryItems.map { IngredientCatalog.canonicalName(for: $0.ingredientName).lowercased() })
        let filteredRecipes = filter(recipes: recipes, prefs: userPrefs)

        return filteredRecipes.map { recipe in
            let missing = recipe.ingredients.filter { ingredient in
                let canonical = IngredientCatalog.canonicalName(for: ingredient.ingredientName).lowercased()
                return !pantrySet.contains(canonical)
            }
            let matchPercentage = recipe.ingredients.isEmpty ? 0 : Double(recipe.ingredients.count - missing.count) / Double(recipe.ingredients.count)
            let dietCompatibilityScore = Set(recipe.dietTags).intersection(userPrefs.enabledDiets).count
            return RecipeMatchResult(
                recipe: recipe,
                missingIngredients: missing,
                pantryMatchPercentage: matchPercentage,
                dietCompatibilityScore: dietCompatibilityScore
            )
        }
        .sorted {
            rank(lhs: $0, rhs: $1, prefs: userPrefs)
        }
    }

    public func cookNow(recipes: [Recipe], pantryItems: [PantryItem], userPrefs: UserPrefs = UserPrefs()) -> [RecipeMatchResult] {
        match(recipes: recipes, pantryItems: pantryItems, userPrefs: userPrefs).filter(\.isCookNow)
    }

    public func almostThere(recipes: [Recipe], pantryItems: [PantryItem], userPrefs: UserPrefs = UserPrefs()) -> [RecipeMatchResult] {
        match(recipes: recipes, pantryItems: pantryItems, userPrefs: userPrefs).filter(\.isAlmostThere)
    }

    public func topUnlockSuggestions(recipes: [Recipe], pantryItems: [PantryItem], limit: Int = 3, userPrefs: UserPrefs = UserPrefs()) -> [UnlockSuggestion] {
        let matches = match(recipes: recipes, pantryItems: pantryItems, userPrefs: userPrefs)
        var unlockScores: [String: Int] = [:]
        var recipeUnlockMap: [String: Set<String>] = [:]

        for match in matches where match.missingCount > 0 {
            for ingredient in match.missingIngredients {
                let canonical = IngredientCatalog.canonicalName(for: ingredient.ingredientName)
                unlockScores[canonical, default: 0] += 1
                recipeUnlockMap[canonical, default: []].insert(match.recipe.name)
            }
        }

        return unlockScores
            .sorted {
                if $0.value == $1.value {
                    return $0.key < $1.key
                }
                return $0.value > $1.value
            }
            .prefix(limit)
            .map { name, count in
                let seeded = IngredientCatalog.seeded.first(where: { $0.name == name }) ?? Ingredient(name: name)
                let recipeNames = recipeUnlockMap[name, default: []].sorted()
                return UnlockSuggestion(ingredient: seeded, unlockCount: count, recipeNames: recipeNames)
            }
    }

    private func filter(recipes: [Recipe], prefs: UserPrefs) -> [Recipe] {
        recipes.filter { recipe in
            isDietCompatible(recipe: recipe, prefs: prefs) && !containsFilteredAllergen(recipe: recipe, prefs: prefs)
        }
    }

    private func rank(lhs: RecipeMatchResult, rhs: RecipeMatchResult, prefs: UserPrefs) -> Bool {
        if lhs.pantryMatchPercentage != rhs.pantryMatchPercentage {
            return lhs.pantryMatchPercentage > rhs.pantryMatchPercentage
        }

        if lhs.missingCount != rhs.missingCount {
            return lhs.missingCount < rhs.missingCount
        }

        if lhs.dietCompatibilityScore != rhs.dietCompatibilityScore {
            return lhs.dietCompatibilityScore > rhs.dietCompatibilityScore
        }

        if lhs.recipe.totalMinutes != rhs.recipe.totalMinutes {
            return lhs.recipe.totalMinutes < rhs.recipe.totalMinutes
        }

        if let lhsDistance = proteinDistance(for: lhs.recipe, prefs: prefs),
           let rhsDistance = proteinDistance(for: rhs.recipe, prefs: prefs),
           lhsDistance != rhsDistance {
            return lhsDistance < rhsDistance
        }

        return lhs.recipe.name < rhs.recipe.name
    }

    private func proteinDistance(for recipe: Recipe, prefs: UserPrefs) -> Int? {
        guard let targetProtein = prefs.targetProtein else { return nil }
        return abs(targetProtein - recipe.nutrition.protein)
    }

    private func isDietCompatible(recipe: Recipe, prefs: UserPrefs) -> Bool {
        guard !prefs.enabledDiets.isEmpty else { return true }
        return !prefs.enabledDiets.isDisjoint(with: Set(recipe.dietTags))
    }

    private func containsFilteredAllergen(recipe: Recipe, prefs: UserPrefs) -> Bool {
        guard !prefs.allergens.isEmpty else { return false }
        for ingredient in recipe.ingredients {
            let allergens = allergensForIngredient(named: ingredient.ingredientName)
            if !prefs.allergens.isDisjoint(with: allergens) {
                return true
            }
        }
        return false
    }

    private func allergensForIngredient(named name: String) -> Set<Allergen> {
        let canonical = IngredientCatalog.canonicalName(for: name).lowercased()
        if ["milk", "butter", "cheddar"].contains(where: canonical.contains) {
            return [.dairy]
        }
        if ["pasta"].contains(where: canonical.contains) {
            return [.gluten]
        }
        if ["egg"].contains(where: canonical.contains) {
            return [.eggs]
        }
        if ["almond", "peanut", "walnut", "cashew", "pecan"].contains(where: canonical.contains) {
            return [.nuts]
        }
        return []
    }
}
