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
        let lowered = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for ingredient in seeded {
            if ingredient.name.lowercased() == lowered || ingredient.synonyms.contains(where: { $0.lowercased() == lowered }) {
                return ingredient.name
            }
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
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
