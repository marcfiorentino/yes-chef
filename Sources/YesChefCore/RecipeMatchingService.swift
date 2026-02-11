import Foundation

public struct RecipeMatchingService {
    public init() {}

    public func match(recipes: [Recipe], pantryItems: [PantryItem]) -> [RecipeMatchResult] {
        let pantrySet = Set(pantryItems.map { IngredientCatalog.canonicalName(for: $0.ingredientName).lowercased() })

        return recipes.map { recipe in
            let missing = recipe.ingredients.filter { ingredient in
                let canonical = IngredientCatalog.canonicalName(for: ingredient.ingredientName).lowercased()
                return !pantrySet.contains(canonical)
            }
            return RecipeMatchResult(recipe: recipe, missingIngredients: missing)
        }
        .sorted {
            if $0.missingCount == $1.missingCount {
                return $0.recipe.totalMinutes < $1.recipe.totalMinutes
            }
            return $0.missingCount < $1.missingCount
        }
    }

    public func cookNow(recipes: [Recipe], pantryItems: [PantryItem]) -> [RecipeMatchResult] {
        match(recipes: recipes, pantryItems: pantryItems).filter(\.isCookNow)
    }

    public func almostThere(recipes: [Recipe], pantryItems: [PantryItem]) -> [RecipeMatchResult] {
        match(recipes: recipes, pantryItems: pantryItems).filter(\.isAlmostThere)
    }
}
