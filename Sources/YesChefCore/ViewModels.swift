import Foundation

public final class PantryViewModel {
    public private(set) var pantryItems: [PantryItem]
    public private(set) var pendingIngredientName: String?
    public private(set) var suggestions: [Ingredient] = []

    public init(pantryItems: [PantryItem] = []) {
        self.pantryItems = pantryItems
    }

    public func updateEntryText(_ text: String) {
        pendingIngredientName = text
        suggestions = IngredientCatalog.autocompleteSuggestions(for: text)
    }

    public func chooseSuggestion(_ ingredient: Ingredient) {
        pendingIngredientName = ingredient.name
        suggestions = []
    }

    @discardableResult
    public func confirmSave(quantity: String) -> PantryItem? {
        guard let pendingIngredientName, !pendingIngredientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let canonicalName = IngredientCatalog.canonicalName(for: pendingIngredientName)
        let item = PantryItem(ingredientName: canonicalName, quantity: quantity)
        pantryItems.insert(item, at: 0)
        self.pendingIngredientName = nil
        suggestions = []
        return item
    }
}

public final class ShopViewModel {
    public private(set) var shoppingList: [RecipeIngredient]

    public init(shoppingList: [RecipeIngredient] = []) {
        self.shoppingList = shoppingList
    }

    public func addMissing(_ ingredients: [RecipeIngredient]) {
        for ingredient in ingredients {
            if !shoppingList.contains(where: { IngredientCatalog.canonicalName(for: $0.ingredientName).lowercased() == IngredientCatalog.canonicalName(for: ingredient.ingredientName).lowercased() }) {
                shoppingList.append(ingredient)
            }
        }
    }
}

public struct RecipesViewState {
    public var cookNow: [RecipeMatchResult]
    public var almostThere: [RecipeMatchResult]

    public init(cookNow: [RecipeMatchResult] = [], almostThere: [RecipeMatchResult] = []) {
        self.cookNow = cookNow
        self.almostThere = almostThere
    }
}

public final class RecipesViewModel {
    private let matcher: RecipeMatchingService
    public private(set) var recipes: [Recipe]
    public private(set) var state: RecipesViewState

    public init(recipes: [Recipe] = [], matcher: RecipeMatchingService = RecipeMatchingService()) {
        self.recipes = recipes
        self.matcher = matcher
        self.state = RecipesViewState()
    }

    public func reloadRecipes(_ recipes: [Recipe]) {
        self.recipes = recipes
    }

    public func updateMatches(pantryItems: [PantryItem]) {
        state.cookNow = matcher.cookNow(recipes: recipes, pantryItems: pantryItems)
        state.almostThere = matcher.almostThere(recipes: recipes, pantryItems: pantryItems)
    }
}
