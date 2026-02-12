#!/usr/bin/env python3
import json
import sqlite3
import sys
import unicodedata
from pathlib import Path


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    text = text.lower().strip()
    cleaned = []
    for c in text:
        if c.isalnum() or c.isspace():
            cleaned.append(c)
        else:
            cleaned.append(" ")
    text = " ".join("".join(cleaned).split())
    for suffix in ("es", "s"):
        if text.endswith(suffix) and len(text) > len(suffix) + 2:
            text = text[: -len(suffix)]
            break
    return text


def build(source_path: Path, output_path: Path) -> None:
    rows = json.loads(source_path.read_text())
    if output_path.exists():
        output_path.unlink()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(output_path)
    cur = conn.cursor()

    cur.executescript(
        """
        PRAGMA journal_mode = OFF;
        PRAGMA synchronous = OFF;
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
    )

    for row in rows:
        cur.execute(
            "INSERT INTO ingredients(canonical_name, category, default_unit) VALUES(?, ?, ?)",
            (row["canonical_name"], row["category"], row.get("default_unit")),
        )
        ingredient_id = cur.lastrowid

        aliases = set(row.get("aliases") or [])
        aliases.add(row["canonical_name"])
        for alias in aliases:
            alias_normalized = normalize(alias)
            cur.execute(
                "INSERT OR IGNORE INTO ingredient_aliases(ingredient_id, alias_normalized, alias_display) VALUES(?, ?, ?)",
                (ingredient_id, alias_normalized, alias),
            )
            cur.execute(
                "INSERT INTO ingredient_search(canonical_name, alias_normalized, ingredient_id) VALUES(?, ?, ?)",
                (row["canonical_name"], alias_normalized, ingredient_id),
            )

    conn.commit()
    conn.close()


if __name__ == "__main__":
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("Sources/YesChefCore/Resources/ingredient_catalog_source.json")
    output = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("Sources/YesChefCore/Resources/ingredient_catalog.sqlite")
    build(source, output)
    print(f"Built {output} from {source}")
