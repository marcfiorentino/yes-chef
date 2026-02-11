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
    public let nutrition: NutritionSummary
    public let dietTags: [DietTag]
    public let ingredients: [RecipeIngredient]
    public let instructions: [String]

    public var totalMinutes: Int { prepMinutes + cookMinutes }

    public init(
        id: UUID = UUID(),
        name: String,
        prepMinutes: Int,
        cookMinutes: Int,
        nutrition: NutritionSummary,
        dietTags: [DietTag] = [],
        ingredients: [RecipeIngredient],
        instructions: [String]
    ) {
        self.id = id
        self.name = name
        self.prepMinutes = prepMinutes
        self.cookMinutes = cookMinutes
        self.nutrition = nutrition
        self.dietTags = dietTags
        self.ingredients = ingredients
        self.instructions = instructions
    }
}

public struct NutritionSummary: Codable, Hashable, Sendable {
    public let calories: Int
    public let protein: Int
    public let carbs: Int
    public let fat: Int

    public init(calories: Int, protein: Int, carbs: Int, fat: Int) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }

    public var totalMacroGrams: Int { max(1, protein + carbs + fat) }
}

public enum DietTag: String, Codable, Hashable, CaseIterable, Sendable {
    case highProtein = "High Protein"
    case keto = "Keto"
    case vegetarian = "Vegetarian"
}

public struct UserPrefs: Codable, Hashable, Sendable {
    public var displayName: String
    public var enabledDiets: Set<DietTag>
    public var targetProtein: Int?
    public var targetCarbs: Int?
    public var targetFat: Int?

    public init(
        displayName: String = "Chef",
        enabledDiets: Set<DietTag> = [],
        targetProtein: Int? = nil,
        targetCarbs: Int? = nil,
        targetFat: Int? = nil
    ) {
        self.displayName = displayName
        self.enabledDiets = enabledDiets
        self.targetProtein = targetProtein
        self.targetCarbs = targetCarbs
        self.targetFat = targetFat
    }
}

public struct UnlockSuggestion: Identifiable, Hashable, Sendable {
    public let ingredient: Ingredient
    public let unlockCount: Int

    public var id: UUID { ingredient.id }

    public init(ingredient: Ingredient, unlockCount: Int) {
        self.ingredient = ingredient
        self.unlockCount = unlockCount
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
