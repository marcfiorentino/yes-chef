import Foundation

public enum PantryInputProcessor {
    public static func parseTranscriptPhrases(_ transcript: String) -> [String] {
        parseTranscriptTokens(transcript, includeTrailingToken: true)
    }

    public static func parseTranscriptTokens(_ transcript: String, includeTrailingToken: Bool = true) -> [String] {
        let normalized = transcript
            .replacingOccurrences(of: "\\band\\b|&", with: ",", options: .regularExpression)
            .replacingOccurrences(of: "\\n", with: ",")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " ", with: ",")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        var seen: Set<String> = []
        var results: [String] = []

        let endedWithSeparator = transcript.range(of: #"[\s,\n]$"#, options: .regularExpression) != nil
        let parts = normalized.split(separator: ",", omittingEmptySubsequences: true)
        let upperBound = includeTrailingToken || endedWithSeparator ? parts.count : max(0, parts.count - 1)

        for part in parts.prefix(upperBound) {
            let cleaned = String(part).trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleaned.count >= 2 else { continue }
            let key = cleaned.lowercased()
            if seen.insert(key).inserted {
                results.append(cleaned)
            }
        }

        return results
    }

    public static func detectEntries(from transcript: String) -> [DetectedPantryEntry] {
        parseTranscriptPhrases(transcript).map { phrase in
            detectEntry(from: phrase)
        }
    }

    public static func detectEntry(from token: String) -> DetectedPantryEntry {
        if let match = IngredientCatalog.matchIngredient(for: token) {
            return DetectedPantryEntry(
                rawText: token,
                matchedIngredientName: match.ingredient.name,
                matchedIngredientID: IngredientCatalog.canonicalIdentifier(for: match.ingredient.name),
                confidence: match.confidence
            )
        }

        return DetectedPantryEntry(
            rawText: token,
            matchedIngredientName: token,
            matchedIngredientID: nil,
            confidence: .needsReview
        )
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
