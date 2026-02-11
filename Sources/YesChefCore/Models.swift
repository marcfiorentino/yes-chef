import Foundation

public struct Ingredient: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let synonyms: [String]

    public init(id: UUID = UUID(), name: String, synonyms: [String] = []) {
        self.id = id
        self.name = name
        self.synonyms = synonyms
    }
}

public struct PantryItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let ingredientName: String
    public let quantity: String
    public let dateAdded: Date

    public init(id: UUID = UUID(), ingredientName: String, quantity: String, dateAdded: Date = Date()) {
        self.id = id
        self.ingredientName = ingredientName
        self.quantity = quantity
        self.dateAdded = dateAdded
    }
}

public struct RecipeIngredient: Codable, Hashable, Sendable {
    public let ingredientName: String
    public let quantity: String

    public init(ingredientName: String, quantity: String) {
        self.ingredientName = ingredientName
        self.quantity = quantity
    }
}

public struct Recipe: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let prepMinutes: Int
    public let cookMinutes: Int
    public let macroSummary: String
    public let ingredients: [RecipeIngredient]
    public let instructions: [String]

    public var totalMinutes: Int { prepMinutes + cookMinutes }

    public init(
        id: UUID = UUID(),
        name: String,
        prepMinutes: Int,
        cookMinutes: Int,
        macroSummary: String,
        ingredients: [RecipeIngredient],
        instructions: [String]
    ) {
        self.id = id
        self.name = name
        self.prepMinutes = prepMinutes
        self.cookMinutes = cookMinutes
        self.macroSummary = macroSummary
        self.ingredients = ingredients
        self.instructions = instructions
    }
}

public struct UserPrefs: Codable, Hashable, Sendable {
    public var displayName: String
    public var dietaryStyle: String
    public var showMacroPlaceholders: Bool

    public init(displayName: String = "Chef", dietaryStyle: String = "Balanced", showMacroPlaceholders: Bool = true) {
        self.displayName = displayName
        self.dietaryStyle = dietaryStyle
        self.showMacroPlaceholders = showMacroPlaceholders
    }
}

public struct RecipeMatchResult: Identifiable, Hashable, Sendable {
    public let recipe: Recipe
    public let missingIngredients: [RecipeIngredient]

    public var id: UUID { recipe.id }
    public var missingCount: Int { missingIngredients.count }
    public var availableCount: Int { recipe.ingredients.count - missingCount }
    public var isCookNow: Bool { missingCount == 0 }
    public var isAlmostThere: Bool { missingCount <= 2 }
}
