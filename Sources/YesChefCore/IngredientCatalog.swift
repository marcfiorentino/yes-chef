import Foundation

public struct IngredientCatalog {
    public enum Status: Equatable {
        case loading
        case ready(ingredientCount: Int)
        case fallback
    }

    private static let lock = NSLock()
    private static var db: IngredientCatalogDB?
    private static var statusValue: Status = .loading
    private static var bootstrapTask: Task<Void, Never>?

    public static var status: Status {
        lock.withLock { statusValue }
    }

    public static func seedAtStartup() async {
        let task: Task<Void, Never> = lock.withLock {
            if let bootstrapTask {
                return bootstrapTask
            }

            let task = Task.detached(priority: .userInitiated) {
                let seededDB = IngredientCatalogDB()
                let seeded = seededDB.allIngredients
                lock.withLock {
                    db = seededDB
                    statusValue = seededDB.isFallbackMode ? .fallback : .ready(ingredientCount: seeded.count)
                }
            }
            bootstrapTask = task
            return task
        }

        await task.value
    }

    private static func activeDB() -> IngredientCatalogDB {
        lock.withLock {
            if let db {
                return db
            }
            let seededDB = IngredientCatalogDB()
            self.db = seededDB
            let seeded = seededDB.allIngredients
            statusValue = seededDB.isFallbackMode ? .fallback : .ready(ingredientCount: seeded.count)
            return seededDB
        }
    }

    public static var seeded: [Ingredient] {
        activeDB().allIngredients
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
        activeDB().matchIngredient(for: phrase)
    }

    public static func autocompleteSuggestions(for query: String) -> [Ingredient] {
        activeDB().autocompleteSuggestions(for: query)
    }

    public static func hasExactMatch(for phrase: String) -> Bool {
        activeDB().hasExactMatch(for: phrase)
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
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
