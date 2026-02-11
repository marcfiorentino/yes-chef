import Foundation

public enum PantryInputProcessor {
    public static func parseTranscriptPhrases(_ transcript: String) -> [String] {
        let normalized = transcript
            .replacingOccurrences(of: "\\band\\b|&|\\n", with: ",", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        var seen: Set<String> = []
        var results: [String] = []

        for part in normalized.split(separator: ",") {
            let cleaned = String(part).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }
            let key = cleaned.lowercased()
            if seen.insert(key).inserted {
                results.append(cleaned)
            }
        }

        return results
    }

    public static func detectEntries(from transcript: String) -> [DetectedPantryEntry] {
        parseTranscriptPhrases(transcript).map { phrase in
            if let match = IngredientCatalog.matchIngredient(for: phrase) {
                return DetectedPantryEntry(
                    rawText: phrase,
                    matchedIngredientName: match.ingredient.name,
                    matchedIngredientID: IngredientCatalog.canonicalIdentifier(for: match.ingredient.name),
                    confidence: match.confidence
                )
            }

            return DetectedPantryEntry(
                rawText: phrase,
                matchedIngredientName: phrase,
                matchedIngredientID: nil,
                confidence: .needsReview
            )
        }
    }

    public static func detectBarcodeEntry(productName: String?, barcode: String) -> DetectedPantryEntry {
        let raw = productName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = raw?.isEmpty == false ? raw! : "Unknown item"

        if let match = IngredientCatalog.matchIngredient(for: fallback) {
            return DetectedPantryEntry(
                rawText: fallback,
                matchedIngredientName: match.ingredient.name,
                matchedIngredientID: IngredientCatalog.canonicalIdentifier(for: match.ingredient.name),
                confidence: match.confidence,
                barcode: barcode
            )
        }

        return DetectedPantryEntry(
            rawText: fallback,
            matchedIngredientName: fallback,
            matchedIngredientID: nil,
            confidence: .needsReview,
            barcode: barcode
        )
    }
}
