import Foundation

public enum RecipeLoader {
    public static func loadSeededRecipes() throws -> [Recipe] {
        try loadSeededRecipes(from: .module)
    }

    public static func loadSeededRecipes(from bundle: Bundle) throws -> [Recipe] {
        let url = bundle.url(forResource: "seeded_recipes", withExtension: "json")
        guard let url else {
            throw NSError(domain: "RecipeLoader", code: 404, userInfo: [NSLocalizedDescriptionKey: "seeded_recipes.json not found"])
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode([Recipe].self, from: data)
    }
}
