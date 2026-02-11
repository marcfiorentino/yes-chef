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
            return RecipeMatchResult(recipe: recipe, missingIngredients: missing)
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

        for match in matches where match.missingCount > 0 {
            for ingredient in match.missingIngredients {
                let canonical = IngredientCatalog.canonicalName(for: ingredient.ingredientName)
                unlockScores[canonical, default: 0] += 1
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
                return UnlockSuggestion(ingredient: seeded, unlockCount: count)
            }
    }

    private func filter(recipes: [Recipe], prefs: UserPrefs) -> [Recipe] {
        guard !prefs.enabledDiets.isEmpty else { return recipes }
        return recipes.filter { recipe in
            !prefs.enabledDiets.isDisjoint(with: Set(recipe.dietTags))
        }
    }

    private func rank(lhs: RecipeMatchResult, rhs: RecipeMatchResult, prefs: UserPrefs) -> Bool {
        if lhs.missingCount != rhs.missingCount {
            return lhs.missingCount < rhs.missingCount
        }

        if let lhsDistance = macroDistance(for: lhs.recipe, prefs: prefs),
           let rhsDistance = macroDistance(for: rhs.recipe, prefs: prefs),
           lhsDistance != rhsDistance {
            return lhsDistance < rhsDistance
        }

        return lhs.recipe.totalMinutes < rhs.recipe.totalMinutes
    }

    private func macroDistance(for recipe: Recipe, prefs: UserPrefs) -> Int? {
        guard prefs.targetProtein != nil || prefs.targetCarbs != nil || prefs.targetFat != nil else {
            return nil
        }
        let proteinDelta = abs((prefs.targetProtein ?? recipe.nutrition.protein) - recipe.nutrition.protein)
        let carbsDelta = abs((prefs.targetCarbs ?? recipe.nutrition.carbs) - recipe.nutrition.carbs)
        let fatDelta = abs((prefs.targetFat ?? recipe.nutrition.fat) - recipe.nutrition.fat)
        return proteinDelta + carbsDelta + fatDelta
    }
}
