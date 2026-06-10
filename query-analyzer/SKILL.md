---
name: query-analyzer
description: Analyzes database query performance using EXPLAIN plans, index usage validation, and ClickHouse historical data. Prevents slow queries before they hit production.
allowed-tools: [Bash, Read, Grep, Glob, Edit, mcp__clickhouse__run_select_query, mcp__clickhouse__list_tables]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

# Query Analyzer Skill

Validates query performance using MySQL EXPLAIN plans and ClickHouse production metrics.

## CRITICAL RULES

1. **Always use EXPLAIN** before deploying new queries
2. **Index all foreign keys** used in WHERE/JOIN clauses
3. **Avoid SELECT *** when you only need specific columns
4. **Batch large queries** to prevent timeout/memory issues
5. **Check production patterns** in ClickHouse before optimizing

## Shared References

> **📚 This skill uses shared documentation. See:**
> - [Critical Rules](../shared/critical-rules.md) - Project-wide rules
> - [Testing Patterns](../shared/testing-patterns.md) - Database testing

## Workflow

### Step 1: Identify Queries to Analyze

```bash
# Find new queries in changed files
git diff develop --name-only | xargs grep -l "\.where\|\.joins\|\.includes" 2>/dev/null

# Extract actual queries
grep -rn "\.where\|\.joins\|\.includes" app/models/ app/services/ app/controllers/ \
  --include="*.rb" -A2 -B2
```

### Step 2: Run EXPLAIN Analysis (MySQL)

```bash
# In Docker Rails console
bin/d rails console

# Get EXPLAIN for a query
query = User.joins(:facility).where(active: true, facility_id: 123)
puts query.explain

# Or use ClickHouse MCP for production patterns
```

**EXPLAIN Output to Watch For:**

```
| type  | possible_keys | key  | rows | Extra           |
|-------|---------------|------|------|-----------------|
| ALL   | NULL          | NULL | 1000 | Using filesort  | ❌ SLOW - Full table scan
| index | facility_id   | NULL | 1000 | Using index     | ⚠️  MEDIUM - Index scan
| ref   | facility_id   | idx  | 10   | Using where     | ✅ FAST - Index lookup
```

**Red Flags**:
- ❌ `type: ALL` - Full table scan
- ❌ `Using filesort` - Expensive sort operation
- ❌ `Using temporary` - Creates temp table
- ❌ `rows: 10000+` - Scans too many rows
- ❌ `key: NULL` - No index used

### Step 3: Check Index Usage

```bash
# Check existing indexes
bin/d rails runner "
  conn = ActiveRecord::Base.connection
  puts conn.indexes('users').map { |i| [i.name, i.columns].join(': ') }
"

# Or check schema.rb
grep "add_index.*users" db/schema.rb
```

### Step 4: Analyze with ClickHouse Production Data

Use MCP tool to query production patterns:

```ruby
# Find slow queries on specific table
mcp__clickhouse__run_select_query:
  query: "
    SELECT
      query,
      count() as query_count,
      avg(query_duration_ms) as avg_duration,
      max(query_duration_ms) as max_duration,
      sum(read_rows) as total_rows_read
    FROM system.query_log
    WHERE query LIKE '%users%'
      AND query_duration_ms > 500
      AND event_date >= today() - 7
    GROUP BY query
    ORDER BY avg_duration DESC
    LIMIT 20
  "

# Check index effectiveness
mcp__clickhouse__run_select_query:
  query: "
    SELECT
      table,
      sum(read_rows) as rows_scanned,
      count() as query_count,
      avg(query_duration_ms) as avg_time
    FROM system.query_log
    WHERE type = 'QueryFinish'
      AND event_date >= today() - 7
      AND table IN ('users', 'reservations', 'facilities')
    GROUP BY table
    ORDER BY avg_time DESC
  "
```

### Step 5: Validate Query Patterns

#### Pattern 1: N+1 Queries
```ruby
# ❌ BAD - N+1 query
users = User.where(active: true)
users.each { |u| puts u.facility.name }  # 1 + N queries

# ✅ GOOD - Eager loading
users = User.includes(:facility).where(active: true)
users.each { |u| puts u.facility.name }  # 2 queries total
```

#### Pattern 2: Missing Indexes
```ruby
# ❌ BAD - No index on facility_id
Reservation.where(facility_id: facility.id)
# EXPLAIN shows: type: ALL, rows: 50000

# ✅ GOOD - Add index
add_index :reservations, :facility_id
# EXPLAIN shows: type: ref, rows: 100
```

#### Pattern 3: Over-selecting Columns
```ruby
# ❌ BAD - Selects all columns
User.where(active: true).map(&:email)
# Loads: id, email, first_name, last_name, created_at, ...

# ✅ GOOD - Only needed columns
User.where(active: true).pluck(:email)
# Loads: email only (5-10x faster)
```

#### Pattern 4: Inefficient Joins
```ruby
# ❌ BAD - Multiple joins without indexes
User.joins(:facility, :memberships, :reservations)
    .where('reservations.status = ?', 'confirmed')
# Slow if missing composite indexes

# ✅ GOOD - Targeted query with proper indexes
# Add: add_index :reservations, [:user_id, :status]
User.joins(:reservations)
    .where(reservations: { status: 'confirmed' })
    .select('users.*')
```

#### Pattern 5: Large IN Clauses
```ruby
# ❌ BAD - Large IN clause
ids = (1..10000).to_a
User.where(id: ids)
# MySQL IN clause has limits, slow for 1000+ items

# ✅ GOOD - Batch into smaller chunks
ids.each_slice(500) do |batch|
  User.where(id: batch).find_each { |u| process(u) }
end
```

### Step 6: Generate Migration if Needed

```ruby
# If missing indexes detected, generate migration
bin/d rails generate migration AddIndexToReservations

# Add to migration file:
class AddIndexToReservations < ActiveRecord::Migration[6.1]
  def change
    # Single column index
    add_index :reservations, :facility_id

    # Composite index for common query pattern
    add_index :reservations, [:facility_id, :status]

    # Unique index
    add_index :users, :email, unique: true
  end
end
```

### Step 7: Benchmark Before/After

```bash
# Benchmark in Rails console
require 'benchmark'

# Before optimization
Benchmark.ms do
  1000.times { User.where(active: true).to_a }
end
# => 3500.0 ms

# After adding index + using pluck
Benchmark.ms do
  1000.times { User.where(active: true).pluck(:id) }
end
# => 180.0 ms

# Result: 19x faster
```

## Query Complexity Scoring

Assign complexity score to queries:

| Factor | Points | Example |
|--------|--------|---------|
| Full table scan (type: ALL) | +100 | No WHERE clause |
| Using filesort | +50 | ORDER BY unindexed column |
| Using temporary | +50 | Complex GROUP BY |
| Rows scanned > 1000 | +20 | Large result set |
| No index used | +30 | Missing key in EXPLAIN |
| 3+ table joins | +20 | Complex query |
| Subquery | +10 | Nested SELECT |

**Scoring**:
- **0-20**: ✅ Optimal
- **21-50**: ⚠️ Review recommended
- **51-100**: ❌ Optimization required
- **100+**: 🚨 Critical - blocks deployment

## Integration with ClickHouse MCP

### Query 1: Find Tables Needing Indexes

```sql
-- Run via mcp__clickhouse__run_select_query
SELECT
  table,
  count() as queries_without_index,
  avg(query_duration_ms) as avg_duration,
  sum(read_rows) as total_rows_scanned
FROM system.query_log
WHERE type = 'QueryFinish'
  AND has(arrayFilter(x -> x.type = 'ALL', query_plan.steps), 1)
  AND event_date >= today() - 7
GROUP BY table
HAVING queries_without_index > 100
ORDER BY avg_duration DESC
LIMIT 20;
```

### Query 2: Identify Slow Query Patterns

```sql
SELECT
  normalized_query_hash,
  any(query) as example_query,
  count() as occurrences,
  avg(query_duration_ms) as avg_time,
  max(query_duration_ms) as max_time,
  sum(read_rows) as total_rows
FROM system.query_log
WHERE type = 'QueryFinish'
  AND query_duration_ms > 500
  AND event_date >= today() - 7
  AND query NOT LIKE '%system.%'
GROUP BY normalized_query_hash
ORDER BY occurrences DESC
LIMIT 30;
```

### Query 3: Index Hit Rate

```sql
SELECT
  table,
  countIf(key IS NOT NULL) as queries_with_index,
  countIf(key IS NULL) as queries_without_index,
  round(queries_with_index / (queries_with_index + queries_without_index) * 100, 2) as index_hit_rate
FROM (
  SELECT
    table,
    JSONExtractString(extra, 'key') as key
  FROM system.query_log
  WHERE type = 'QueryFinish'
    AND event_date >= today() - 7
)
GROUP BY table
ORDER BY index_hit_rate ASC
LIMIT 20;
```

## Report Format

```markdown
## Query Analysis Report

### Summary
- Files analyzed: 3
- Queries analyzed: 12
- Slow queries detected: 4
- Missing indexes: 2
- Complexity score: 78/100 ⚠️

### Query Performance Issues

#### Issue 1: Full Table Scan on Reservations
**File**: `app/services/reservation_finder.rb:23`
**Query**:
```ruby
Reservation.where(status: 'confirmed')
```

**EXPLAIN Analysis**:
- Type: ALL (full table scan)
- Rows scanned: 45,000
- Duration: 2.3s avg (from ClickHouse)
- Complexity Score: 120 🚨 CRITICAL

**Production Impact** (ClickHouse):
- Executes: 1,200 times/day
- Total time wasted: 46 minutes/day
- P95 latency: 3.8s

**Fix**:
```ruby
# Add index
add_index :reservations, :status

# Optimized query (if need more columns)
Reservation.where(status: 'confirmed').select(:id, :user_id, :starts_at)
```

**Expected Impact**:
- Rows scanned: 45,000 → 200
- Duration: 2.3s → 12ms (192x faster)
- Complexity Score: 120 → 15 ✅

---

#### Issue 2: N+1 Query in GraphQL Resolver
**File**: `app/graphql/resolvers/users_resolver.rb:15`
**Pattern**: Missing eager loading

**Current**:
```ruby
User.where(active: true)
# Then each user queries facility (N+1)
```

**ClickHouse shows**:
- 180 facility queries for single users request
- Avg: 15ms each = 2.7s total

**Fix**:
```ruby
User.includes(:facility, :memberships).where(active: true)
```

**Expected Impact**:
- Queries: 181 → 3
- Duration: 2.7s → 80ms (33x faster)

---

### Missing Indexes

| Table | Column(s) | Query Pattern | Impact |
|-------|-----------|---------------|--------|
| reservations | status | WHERE status = ? | 2.3s → 12ms |
| memberships | user_id, active | WHERE user_id = ? AND active = true | 450ms → 8ms |

### Recommendations

1. **Add indexes** (migration needed):
   ```ruby
   add_index :reservations, :status
   add_index :memberships, [:user_id, :active]
   ```

2. **Optimize queries**:
   - Use `includes` for associations in GraphQL resolvers
   - Use `pluck` instead of loading full objects when only IDs needed
   - Batch large operations

3. **Before deployment**:
   - Run EXPLAIN on all new queries
   - Verify ClickHouse patterns for similar queries
   - Benchmark before/after

### Performance Metrics

**Before Optimization**:
- Avg query time: 1.2s
- Total daily query time: 48 minutes
- Queries > 1s: 24%

**After Optimization** (projected):
- Avg query time: 65ms
- Total daily query time: 2.6 minutes
- Queries > 1s: 0%

**ROI**: Saves 45 minutes/day of database time
```

## Example Usage

```bash
# Analyze queries in changed files
/query-analyzer

# Output:
# 1. Scans git diff for query changes
# 2. Runs EXPLAIN on each query
# 3. Checks ClickHouse for production patterns
# 4. Scores complexity
# 5. Suggests indexes/optimizations
# 6. Generates migration if needed

# Then creates report and optionally generates migration:
# db/migrate/20260128_add_performance_indexes.rb
```

## Integration with Other Skills

### With /tdd
```bash
# Before writing query tests, validate performance
/query-analyzer app/services/new_service.rb
```

### With /performance
```bash
# Query-analyzer focuses on SQL-level optimization
# Performance skill focuses on N+1 detection
# Use together for complete analysis
```

### With /orchestrate
```bash
# Orchestrate runs query-analyzer in Phase 3 (Database Validation)
# Automatically checks all model/service changes
```

## Helper Script

Create `lib/query_analyzer.rb`:

```ruby
# lib/query_analyzer.rb
class QueryAnalyzer
  def self.analyze(file_path)
    # Extract queries from file
    # Run EXPLAIN
    # Calculate complexity
    # Query ClickHouse for production data
  end

  def self.score_query(explain_output)
    # Calculate complexity score
  end
end
```

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new query anti-pattern
- A better EXPLAIN interpretation
- A useful ClickHouse analysis query

**You MUST**:
1. Complete the current analysis first
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

<!-- Kaizen entries will be added here -->

<!-- Kaizen: 2026-06-02 - User correction -->
- Rule: ALWAYS use `FINAL` (or `argMax(col, updated_at)` dedup) on ANY ClickHouse `*ReplacingMergeTree` table before `count()`/`GROUP BY`. Verify the engine first: `SELECT engine FROM system.tables WHERE database=… AND name=…`. Apply `FINAL` to EVERY joined ReplacingMergeTree table whose columns you filter on (syntax: `FROM db.table AS alias FINAL`).
- Why: Without `FINAL`, an UPDATEd row's superseded versions are still physically present and get counted — inflating results (CORE-639 sweep: 122,776 vs deduped-truth 5,831, ~20×, with 0h replica lag → pure version-duplication, not staleness). Nearly drove a wrong operational decision (~266 facilities vs real ~43).
- How to apply: Sanity-gate `count()` vs `count() FINAL` — if they differ materially you MUST use FINAL. Any CH-derived "what remains / how many pending" magnitude must be reconciled against the authoritative live source (rake DRY_RUN / MySQL) before being reported. CH = screen; rake/MySQL = truth.
- Source: User correction on 2026-06-02. See `memory/feedback_clickhouse_final_dedup.md`.
