import Foundation

public final class PantryViewModel {
    public private(set) var pantryItems: [PantryItem]
    public private(set) var pendingIngredientName: String?
    public private(set) var suggestions: [Ingredient] = []
    private var hasSelectedSuggestion = false

    public init(pantryItems: [PantryItem] = []) {
        self.pantryItems = pantryItems
    }

    public func replaceItems(_ items: [PantryItem]) {
        pantryItems = items
    }

    public func updateEntryText(_ text: String) {
        pendingIngredientName = text
        hasSelectedSuggestion = false
        suggestions = IngredientCatalog.autocompleteSuggestions(for: text)
            .prefix(5)
            .map { $0 }
    }

    public func chooseSuggestion(_ ingredient: Ingredient) {
        pendingIngredientName = ingredient.name
        hasSelectedSuggestion = true
        suggestions = []
    }

    @discardableResult
    public func confirmSave(quantity: String, requireSuggestionSelection: Bool = false) -> PantryItem? {
        guard let pendingIngredientName, !pendingIngredientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        guard !requireSuggestionSelection || hasSelectedSuggestion else {
            return nil
        }

        let canonicalName = IngredientCatalog.canonicalName(for: pendingIngredientName)
        let item = PantryItem(
            ingredientName: canonicalName,
            quantity: quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : quantity,
            source: .typed,
            rawInput: pendingIngredientName,
            canonicalIngredientID: IngredientCatalog.canonicalIdentifier(for: canonicalName),
            canonicalIngredientName: canonicalName
        )
        pantryItems.insert(item, at: 0)
        self.pendingIngredientName = nil
        hasSelectedSuggestion = false
        suggestions = []
        return item
    }



    @discardableResult
    public func addDetectedEntries(_ entries: [DetectedPantryEntry], source: PantryEntrySource, rawInput: String? = nil) -> [PantryItem] {
        var seenKeys = Set(pantryItems.map { dedupeKey(for: $0.canonicalIngredientID, name: $0.canonicalIngredientName ?? $0.ingredientName) })
        var added: [PantryItem] = []

        for entry in entries where entry.isIncluded {
            let canonicalName = IngredientCatalog.canonicalName(for: entry.matchedIngredientName)
            let canonicalID = entry.matchedIngredientID ?? IngredientCatalog.canonicalIdentifier(for: canonicalName)
            let key = dedupeKey(for: canonicalID, name: canonicalName)
            guard seenKeys.insert(key).inserted else { continue }

            let quantity = entry.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
            added.append(PantryItem(
                ingredientName: canonicalName,
                quantity: quantity.isEmpty ? "1" : quantity,
                source: source,
                rawInput: rawInput ?? entry.rawText,
                canonicalIngredientID: canonicalID,
                canonicalIngredientName: canonicalName,
                barcode: entry.barcode
            ))
        }

        pantryItems.insert(contentsOf: added.reversed(), at: 0)
        return added
    }

    private func dedupeKey(for canonicalID: String?, name: String) -> String {
        if let canonicalID, !canonicalID.isEmpty {
            return "id:\(canonicalID.lowercased())"
        }
        return "name:\(IngredientCatalog.canonicalName(for: name).lowercased())"
    }

    public func removeItems(at offsets: IndexSet) {
        for offset in offsets.sorted(by: >) {
            pantryItems.remove(at: offset)
        }
    }
}

public final class ShopViewModel {
    public private(set) var shoppingList: [RecipeIngredient]

    public init(shoppingList: [RecipeIngredient] = []) {
        self.shoppingList = shoppingList
    }

    public func replaceItems(_ items: [RecipeIngredient]) {
        self.shoppingList = deduped(items)
    }

    public func addMissing(_ ingredients: [RecipeIngredient]) {
        shoppingList = deduped(shoppingList + ingredients)
    }

    public func addIngredient(name: String) {
        addMissing([RecipeIngredient(ingredientName: name, quantity: "1")])
    }

    private func deduped(_ items: [RecipeIngredient]) -> [RecipeIngredient] {
        var seen: Set<String> = []
        var result: [RecipeIngredient] = []
        for ingredient in items {
            let canonical = IngredientCatalog.canonicalName(for: ingredient.ingredientName).lowercased()
            if seen.insert(canonical).inserted {
                result.append(RecipeIngredient(ingredientName: IngredientCatalog.canonicalName(for: ingredient.ingredientName), quantity: ingredient.quantity))
            }
        }
        return result
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

    public func updateMatches(pantryItems: [PantryItem], prefs: UserPrefs = UserPrefs()) {
        state.cookNow = matcher.cookNow(recipes: recipes, pantryItems: pantryItems, userPrefs: prefs)
        state.almostThere = matcher.almostThere(recipes: recipes, pantryItems: pantryItems, userPrefs: prefs).filter { !$0.isCookNow }
    }

    public func unlockSuggestions(pantryItems: [PantryItem], prefs: UserPrefs = UserPrefs()) -> [UnlockSuggestion] {
        matcher.topUnlockSuggestions(recipes: recipes, pantryItems: pantryItems, userPrefs: prefs)
    }
}
