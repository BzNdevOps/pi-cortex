# Neo4j 5.x Cypher — Cheat Sheet for pi-cortex
> Sources: neo4j.com/docs/cypher-manual/current/
> Fetched: 2026-05-04

## Temporal functions — CRITICAL differences from Neo4j 4.x

### duration.between(from, to)
Returns a `DURATION` value. Both arguments must be **temporal instant types** (DATE, DATETIME, LOCAL DATETIME, etc.) — NOT Duration objects.

```cypher
// Days between two datetimes:
duration.between(datetime("2024-01-01T00:00:00"), datetime()).days
// → integer number of days

// With stored datetime property:
duration.between(k.updated_at, datetime()).days
// If k.updated_at is stored as ISO string (not Neo4j DateTime), parse first:
duration.between(datetime(k.updated_at), datetime()).days
```

### duration.inDays(from, to)
Returns a DURATION where the total is expressed only in days (smaller units discarded).

```cypher
duration.inDays(date("1984-10-11"), datetime("1984-10-12T21:40:32.142+0100"))
// → P1D  (1 day — hours are discarded)
```

### Accessing components
```cypher
duration.between(d1, d2).years   // integer
duration.between(d1, d2).months  // integer
duration.between(d1, d2).days    // integer  ← use this for ACO evaporation
duration.between(d1, d2).hours   // integer
duration.between(d1, d2).seconds // integer
```

## ACO evaporation Cypher (Mission 3)

```cypher
// CORRECT — Neo4j 5.x syntax:
MATCH (k:Knowledge)
WHERE k.updated_at IS NOT NULL
SET k.pheromone_weight =
  toFloat(coalesce(k.uses, 0))
  * exp(-toFloat(duration.between(datetime(k.updated_at), datetime()).days) / 30.0)
RETURN count(k) AS evaporated

// If updated_at is already stored as Neo4j DateTime (not string):
SET k.pheromone_weight =
  toFloat(coalesce(k.uses, 0))
  * exp(-toFloat(duration.between(k.updated_at, datetime()).days) / 30.0)
```

**WRONG — do NOT use (Neo4j 4.x syntax, broken in 5.x):**
```cypher
-- SET k.pheromone_weight = k.uses * exp(-(datetime() - k.updated_at).days / 30)
-- duration.inDays(k.updated_at, datetime())  ← wrong arg order
```

## FULLTEXT index — CREATE and QUERY

### Create (Neo4j 5.x syntax)
```cypher
CREATE FULLTEXT INDEX knowledge_search IF NOT EXISTS
  FOR (k:Knowledge) ON EACH [k.title, k.content]

// With options (English analyzer, async updates):
CREATE FULLTEXT INDEX knowledge_search IF NOT EXISTS
  FOR (k:Knowledge) ON EACH [k.title, k.content]
  OPTIONS {
    indexConfig: {
      `fulltext.analyzer`: 'english',
      `fulltext.eventually_consistent`: true
    }
  }
```

### Query
```cypher
// Basic search:
CALL db.index.fulltext.queryNodes("knowledge_search", $query)
YIELD node, score
RETURN node, score
ORDER BY score DESC
LIMIT $top_k

// Boolean operators (Lucene syntax):
CALL db.index.fulltext.queryNodes("knowledge_search", "nginx AND timeout")
YIELD node, score

// Phrase search:
CALL db.index.fulltext.queryNodes("knowledge_search", '"best practice"')
YIELD node, score
```

## Constraints and indexes (Neo4j 5.x syntax)

```cypher
-- Unique constraint:
CREATE CONSTRAINT knowledge_id_unique IF NOT EXISTS
  FOR (k:Knowledge) REQUIRE k.id IS UNIQUE;

-- Regular index:
CREATE INDEX knowledge_status IF NOT EXISTS
  FOR (k:Knowledge) ON (k.status);

-- Relationship property index:
CREATE INDEX rel_pheromone IF NOT EXISTS
  FOR ()-[r:RELATED_TO]-() ON (r.pheromone);
```

**WRONG — Neo4j 4.x syntax (breaks in 5.x):**
```cypher
-- CREATE INDEX ON :Knowledge(status)           ← 4.x, deprecated
-- CREATE CONSTRAINT ON (k:Knowledge) ASSERT ... ← 4.x, removed
```

## MERGE vs CREATE (Mission 11 — cross-reference)

Always use `MERGE` for idempotent operations (safe to run daily):

```cypher
// Create inverse relation if missing — safe to run multiple times:
MATCH (a:Knowledge)-[:RELATED_TO]->(b:Knowledge)
WHERE NOT (b)-[:RELATED_TO]->(a)
  AND a.id <> b.id
MERGE (b)-[r:RELATED_TO]->(a)
ON CREATE SET
  r.pheromone = 0.0,
  r.created_at = datetime(),
  r.source = "gardener-crossref"
RETURN count(r) AS created

// WRONG — creates duplicates on every run:
-- MATCH ... CREATE (b)-[:RELATED_TO]->(a)
```

## Useful utility Cypher

```cypher
-- Count nodes by label:
MATCH (k:Knowledge) RETURN count(k)

-- Super-node detection (Mission 15 — perf):
MATCH (k:Knowledge)-[r]-()
WITH k, count(r) AS degree
WHERE degree > 100
RETURN k.id, degree ORDER BY degree DESC

-- Check if DateTime or string:
MATCH (k:Knowledge) RETURN k.id, k.updated_at, type(k.updated_at) LIMIT 5
-- If type is "STRING", use datetime(k.updated_at) to parse
-- If type is "ZONED_DATE_TIME", use k.updated_at directly

-- Neo4j 5.x math functions available in Cypher:
-- exp(x), log(x), log10(x), sqrt(x), abs(x), ceil(x), floor(x), round(x)
```

## Running Cypher via driver (Node.js)

```typescript
const session = driver.session();
try {
  const result = await session.run(
    "MATCH (k:Knowledge) WHERE k.id = $id RETURN k",
    { id: "global/01-engineering-principles" }
  );
  return result.records.map(r => r.get("k").properties);
} finally {
  await session.close();
}
```

**NEVER concatenate strings in Cypher — always use `$param` placeholders.**
