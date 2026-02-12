import Foundation

public struct IngredientCatalog {
    private static let db = IngredientCatalogDB()

    public static var seeded: [Ingredient] {
        db.allIngredients
    }

    public static func canonicalName(for value: String) -> String {
        if let match = matchIngredient(for: value) {
            return match.ingredient.name
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func canonicalIdentifier(for ingredientName: String) -> String {
        ingredientName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    public static func matchIngredient(for phrase: String) -> IngredientMatch? {
        db.matchIngredient(for: phrase)
    }

    public static func autocompleteSuggestions(for query: String) -> [Ingredient] {
        db.autocompleteSuggestions(for: query)
    }
}

public struct IngredientMatch: Hashable, Sendable {
    public let ingredient: Ingredient
    public let ingredientID: Int
    public let score: Double
    public let confidence: IngredientMatchConfidence

    public init(ingredient: Ingredient, ingredientID: Int, score: Double, confidence: IngredientMatchConfidence = .needsReview) {
        self.ingredient = ingredient
        self.ingredientID = ingredientID
        self.score = score
        self.confidence = confidence
    }
}
