import Foundation

public struct IngredientCatalog {
    public static let seeded: [Ingredient] = [
        Ingredient(name: "Egg", synonyms: ["eggs"]),
        Ingredient(name: "Milk", synonyms: ["whole milk", "skim milk"]),
        Ingredient(name: "Butter", synonyms: ["unsalted butter", "salted butter"]),
        Ingredient(name: "Olive Oil", synonyms: ["evoo", "extra virgin olive oil"]),
        Ingredient(name: "Chicken Breast", synonyms: ["chicken", "boneless chicken breast"]),
        Ingredient(name: "Garlic", synonyms: ["garlic clove", "garlic cloves"]),
        Ingredient(name: "Onion", synonyms: ["yellow onion", "white onion", "red onion"]),
        Ingredient(name: "Tomato", synonyms: ["roma tomato", "cherry tomatoes"]),
        Ingredient(name: "Pasta", synonyms: ["spaghetti", "penne"]),
        Ingredient(name: "Rice", synonyms: ["white rice", "brown rice"]),
        Ingredient(name: "Black Beans", synonyms: ["beans", "canned black beans"]),
        Ingredient(name: "Cheddar", synonyms: ["cheddar cheese", "shredded cheddar"]),
        Ingredient(name: "Spinach", synonyms: ["baby spinach"]),
        Ingredient(name: "Lemon", synonyms: ["lemon juice"]),
        Ingredient(name: "Salt", synonyms: ["kosher salt"]),
        Ingredient(name: "Black Pepper", synonyms: ["pepper", "ground black pepper"])
    ]

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
        let lowered = phrase.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lowered.isEmpty else { return nil }

        var best: IngredientMatch?
        for ingredient in seeded {
            let names = [ingredient.name] + ingredient.synonyms
            for name in names {
                let score = similarityScore(lhs: lowered, rhs: name.lowercased())
                if best == nil || score > best!.score {
                    best = IngredientMatch(ingredient: ingredient, score: score)
                }
            }
        }

        guard let best else { return nil }
        if best.score >= 0.9 {
            return IngredientMatch(ingredient: best.ingredient, score: best.score, confidence: .high)
        }
        if best.score >= 0.72 {
            return IngredientMatch(ingredient: best.ingredient, score: best.score, confidence: .medium)
        }
        return nil
    }

    public static func autocompleteSuggestions(for query: String) -> [Ingredient] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lowered = trimmed.lowercased()
        return seeded.filter {
            $0.name.lowercased().contains(lowered) || $0.synonyms.contains(where: { $0.lowercased().contains(lowered) })
        }
    }
}

public struct IngredientMatch: Hashable, Sendable {
    public let ingredient: Ingredient
    public let score: Double
    public let confidence: IngredientMatchConfidence

    public init(ingredient: Ingredient, score: Double, confidence: IngredientMatchConfidence = .needsReview) {
        self.ingredient = ingredient
        self.score = score
        self.confidence = confidence
    }
}

private func similarityScore(lhs: String, rhs: String) -> Double {
    if lhs == rhs { return 1 }
    if lhs.contains(rhs) || rhs.contains(lhs) { return 0.88 }

    let lhsTokens = Set(lhs.split(separator: " ").map(String.init))
    let rhsTokens = Set(rhs.split(separator: " ").map(String.init))
    let overlap = Double(lhsTokens.intersection(rhsTokens).count)
    let union = Double(max(1, lhsTokens.union(rhsTokens).count))
    let jaccard = overlap / union

    let edit = normalizedEditSimilarity(lhs: lhs, rhs: rhs)
    return max(jaccard, edit)
}

private func normalizedEditSimilarity(lhs: String, rhs: String) -> Double {
    let distance = levenshtein(Array(lhs), Array(rhs))
    let maxLength = max(lhs.count, rhs.count)
    guard maxLength > 0 else { return 1 }
    return 1 - (Double(distance) / Double(maxLength))
}

private func levenshtein(_ lhs: [Character], _ rhs: [Character]) -> Int {
    if lhs.isEmpty { return rhs.count }
    if rhs.isEmpty { return lhs.count }

    var previous = Array(0...rhs.count)
    for (i, lhsChar) in lhs.enumerated() {
        var current = [i + 1]
        for (j, rhsChar) in rhs.enumerated() {
            let cost = lhsChar == rhsChar ? 0 : 1
            current.append(min(
                current[j] + 1,
                previous[j + 1] + 1,
                previous[j] + cost
            ))
        }
        previous = current
    }
    return previous[rhs.count]
}
