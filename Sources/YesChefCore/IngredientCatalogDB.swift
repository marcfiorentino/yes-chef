import Foundation
import CSQLite

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct IngredientCatalogDB: @unchecked Sendable {
    private let db: OpaquePointer?
    private let fallbackIngredients: [Ingredient]
    private let fallbackRows: [CatalogRow]

    init() {
        fallbackIngredients = []
        fallbackRows = []

        guard
            let sourceURL = Bundle.module.url(forResource: "ingredient_catalog_source", withExtension: "json"),
            let destinationURL = try? Self.catalogDatabaseURL()
        else {
            db = nil
            return
        }

        do {
            try Self.ensureDatabaseExists(at: destinationURL, sourceJSONURL: sourceURL)
        } catch {
            db = nil
            return
        }

        var handle: OpaquePointer?
        if sqlite3_open_v2(destinationURL.path, &handle, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            sqlite3_close(handle)
            db = nil
            return
        }
        db = handle
    }

    private static func catalogDatabaseURL() throws -> URL {
        let fileManager = FileManager.default
        let baseDirectory: URL
        if let applicationSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            baseDirectory = applicationSupport.appendingPathComponent("YesChef", isDirectory: true)
        } else {
            baseDirectory = fileManager.temporaryDirectory.appendingPathComponent("YesChef", isDirectory: true)
        }

        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        return baseDirectory.appendingPathComponent("ingredient_catalog.sqlite")
    }

    private static func ensureDatabaseExists(at dbURL: URL, sourceJSONURL: URL) throws {
        guard !FileManager.default.fileExists(atPath: dbURL.path) else { return }

        let sourceData = try Data(contentsOf: sourceJSONURL)
        let sourceRows = try JSONDecoder().decode([IngredientSeedRow].self, from: sourceData)

        var handle: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK, let handle else {
            sqlite3_close(handle)
            throw IngredientCatalogError.databaseOpenFailed
        }
        defer { sqlite3_close(handle) }

        let schema = """
        CREATE TABLE ingredients(
            id INTEGER PRIMARY KEY,
            canonical_name TEXT NOT NULL,
            category TEXT NOT NULL,
            default_unit TEXT
        );

        CREATE TABLE ingredient_aliases(
            id INTEGER PRIMARY KEY,
            ingredient_id INTEGER NOT NULL,
            alias_normalized TEXT NOT NULL,
            alias_display TEXT NOT NULL,
            FOREIGN KEY(ingredient_id) REFERENCES ingredients(id)
        );

        CREATE UNIQUE INDEX idx_alias_unique ON ingredient_aliases(ingredient_id, alias_normalized);
        CREATE INDEX idx_alias_normalized ON ingredient_aliases(alias_normalized);

        CREATE VIRTUAL TABLE ingredient_search USING fts5(
            canonical_name,
            alias_normalized,
            ingredient_id UNINDEXED,
            tokenize='unicode61'
        );
        """

        guard sqlite3_exec(handle, schema, nil, nil, nil) == SQLITE_OK else {
            throw IngredientCatalogError.schemaCreationFailed
        }

        for row in sourceRows {
            let ingredientID = try insertIngredient(row, db: handle)
            let aliases = Set(row.aliases + [row.canonicalName])
            for alias in aliases {
                let normalized = normalizeInput(alias)
                try insertAlias(ingredientID: ingredientID, normalized: normalized, display: alias, canonicalName: row.canonicalName, db: handle)
            }
        }
    }

    private static func insertIngredient(_ row: IngredientSeedRow, db: OpaquePointer) throws -> Int {
        let sql = "INSERT INTO ingredients(canonical_name, category, default_unit) VALUES (?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw IngredientCatalogError.insertFailed
        }
        defer { sqlite3_finalize(stmt) }

        bindText(row.canonicalName, to: stmt, at: 1)
        bindText(row.category, to: stmt, at: 2)
        if let defaultUnit = row.defaultUnit {
            bindText(defaultUnit, to: stmt, at: 3)
        } else {
            sqlite3_bind_null(stmt, 3)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw IngredientCatalogError.insertFailed
        }
        return Int(sqlite3_last_insert_rowid(db))
    }

    private static func insertAlias(ingredientID: Int, normalized: String, display: String, canonicalName: String, db: OpaquePointer) throws {
        let aliasSQL = "INSERT OR IGNORE INTO ingredient_aliases(ingredient_id, alias_normalized, alias_display) VALUES (?, ?, ?)"
        var aliasStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, aliasSQL, -1, &aliasStmt, nil) == SQLITE_OK else {
            throw IngredientCatalogError.insertFailed
        }
        defer { sqlite3_finalize(aliasStmt) }

        sqlite3_bind_int(aliasStmt, 1, Int32(ingredientID))
        bindText(normalized, to: aliasStmt, at: 2)
        bindText(display, to: aliasStmt, at: 3)

        guard sqlite3_step(aliasStmt) == SQLITE_DONE else {
            throw IngredientCatalogError.insertFailed
        }

        let ftsSQL = "INSERT INTO ingredient_search(canonical_name, alias_normalized, ingredient_id) VALUES (?, ?, ?)"
        var ftsStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, ftsSQL, -1, &ftsStmt, nil) == SQLITE_OK else {
            throw IngredientCatalogError.insertFailed
        }
        defer { sqlite3_finalize(ftsStmt) }

        bindText(canonicalName, to: ftsStmt, at: 1)
        bindText(normalized, to: ftsStmt, at: 2)
        sqlite3_bind_int(ftsStmt, 3, Int32(ingredientID))

        guard sqlite3_step(ftsStmt) == SQLITE_DONE else {
            throw IngredientCatalogError.insertFailed
        }
    }

    var allIngredients: [Ingredient] {
        guard let db else { return fallbackIngredients }
        let sql = "SELECT id, canonical_name FROM ingredients ORDER BY canonical_name"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var items: [Ingredient] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let name = String(cString: sqlite3_column_text(stmt, 1))
            items.append(Ingredient(name: name))
        }
        return items
    }

    func matchIngredient(for phrase: String) -> IngredientMatch? {
        let normalized = Self.normalizeInput(phrase)
        guard !normalized.isEmpty else { return nil }

        if let exact = exactAliasMatch(normalized: normalized) {
            return scoredMatch(from: exact, score: 1.0)
        }

        let prefix = ftsPrefixCandidates(normalized: normalized)
        if let top = prefix.first {
            return scoredMatch(from: top, score: 0.9)
        }

        let fuzzyPool = prefix.isEmpty ? allCatalogRows(limit: 200) : prefix
        let fuzzy = fuzzyBestMatch(input: normalized, pool: fuzzyPool)
        guard let fuzzy, fuzzy.score >= 0.72 else { return nil }
        return scoredMatch(from: fuzzy.row, score: fuzzy.score)
    }

    func autocompleteSuggestions(for query: String) -> [Ingredient] {
        let normalized = Self.normalizeInput(query)
        guard !normalized.isEmpty else { return [] }

        let candidates = ftsPrefixCandidates(normalized: normalized)
        return candidates
            .prefix(5)
            .map { Ingredient(name: $0.canonicalName) }
    }

    private func scoredMatch(from row: CatalogRow, score: Double) -> IngredientMatch {
        let confidence: IngredientMatchConfidence
        if score >= 0.9 {
            confidence = .high
        } else if score >= 0.72 {
            confidence = .medium
        } else {
            confidence = .needsReview
        }

        return IngredientMatch(
            ingredient: Ingredient(name: row.canonicalName),
            ingredientID: row.ingredientID,
            score: score,
            confidence: confidence
        )
    }

    private func exactAliasMatch(normalized: String) -> CatalogRow? {
        guard let db else { return nil }
        let sql = """
        SELECT i.id, i.canonical_name, a.alias_normalized
        FROM ingredient_aliases a
        JOIN ingredients i ON i.id = a.ingredient_id
        WHERE a.alias_normalized = ?
        LIMIT 1
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        bindText(normalized, to: stmt, at: 1)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return catalogRow(stmt: stmt)
    }

    private func ftsPrefixCandidates(normalized: String) -> [CatalogRow] {
        guard let db else { return [] }
        let terms = normalized
            .split(separator: " ")
            .map { "\($0)*" }
            .joined(separator: " ")
        guard !terms.isEmpty else { return [] }

        let sql = """
        SELECT i.id, i.canonical_name, MIN(s.alias_normalized)
        FROM ingredient_search s
        JOIN ingredients i ON i.id = s.ingredient_id
        WHERE ingredient_search MATCH ?
        GROUP BY i.id
        ORDER BY bm25(ingredient_search)
        LIMIT 15
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        bindText(terms, to: stmt, at: 1)

        var rows: [CatalogRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(catalogRow(stmt: stmt))
        }
        return rows
    }

    private func allCatalogRows(limit: Int) -> [CatalogRow] {
        guard let db else { return fallbackRows }
        let sql = """
        SELECT i.id, i.canonical_name, a.alias_normalized
        FROM ingredient_aliases a
        JOIN ingredients i ON i.id = a.ingredient_id
        LIMIT ?
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(limit))

        var rows: [CatalogRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(catalogRow(stmt: stmt))
        }
        return rows
    }

    private func fuzzyBestMatch(input: String, pool: [CatalogRow]) -> (row: CatalogRow, score: Double)? {
        var best: (CatalogRow, Double)?
        for row in pool {
            let score = similarityScore(lhs: input, rhs: row.aliasNormalized)
            if best == nil || score > best!.1 {
                best = (row, score)
            }
        }
        return best
    }

    private func catalogRow(stmt: OpaquePointer?) -> CatalogRow {
        let ingredientID = Int(sqlite3_column_int(stmt, 0))
        let canonicalName = String(cString: sqlite3_column_text(stmt, 1))
        let aliasNormalized = String(cString: sqlite3_column_text(stmt, 2))
        return CatalogRow(ingredientID: ingredientID, canonicalName: canonicalName, aliasNormalized: aliasNormalized)
    }

    private static func normalizeInput(_ value: String) -> String {
        let folded = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return singularizeBasicPlural(folded)
    }

    private static func singularizeBasicPlural(_ value: String) -> String {
        guard value.count > 3 else { return value }
        if value.hasSuffix("es") {
            return String(value.dropLast(2))
        }
        if value.hasSuffix("s") {
            return String(value.dropLast())
        }
        return value
    }
}

private func bindText(_ value: String, to statement: OpaquePointer?, at index: Int32) {
    _ = value.withCString { pointer in
        sqlite3_bind_text(statement, index, pointer, -1, SQLITE_TRANSIENT)
    }
}

private struct IngredientSeedRow: Codable {
    let canonicalName: String
    let category: String
    let defaultUnit: String?
    let aliases: [String]

    enum CodingKeys: String, CodingKey {
        case canonicalName = "canonical_name"
        case category
        case defaultUnit = "default_unit"
        case aliases
    }
}

private enum IngredientCatalogError: Error {
    case databaseOpenFailed
    case schemaCreationFailed
    case insertFailed
}

private struct CatalogRow {
    let ingredientID: Int
    let canonicalName: String
    let aliasNormalized: String
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
