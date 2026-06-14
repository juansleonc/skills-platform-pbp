---
name: query-analyzer
description: "Analyzes a SPECIFIC query: EXPLAIN plans, index validation, and ClickHouse volume context before it hits production. Distinct from /performance (broad N+1/index/memory code-pattern review across a diff)."
allowed-tools: [Bash, Read, Grep, Glob, Edit, mcp__clickhouse__run_query, mcp__clickhouse__list_tables]
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
6. **FINAL on ReplacingMergeTree tables** — Always add `FINAL` when querying application tables that use ReplacingMergeTree or SharedReplacingMergeTree (e.g., `memberships`, `membership_transactions`). Without `FINAL`, ClickHouse counts superseded row-versions, inflating results up to ~20×. Sanity-gate: compare `count()` vs `count() FINAL` before reporting any magnitude.

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

### Step 4: Analyze with ClickHouse Production Data (Volume Context)

> **NOTE on slow-query analysis**: ClickHouse does NOT log MySQL application queries. `system.query_log` is not accessible in this environment (the table is not visible to the readonly user — coordinator-verified 2026-06-10). Slow-query analysis happens via MySQL EXPLAIN in Docker (Step 2).

> ⚠️ **CRITICAL (FINAL rule)**: All application tables in `pbp_productionDB_optimized` use `SharedReplacingMergeTree`. Always add `FINAL` to prevent ~20× row-count inflation from superseded row-versions. Sanity-gate: compare `count()` vs `count() FINAL` before reporting any magnitude.

ClickHouse is useful for **volume context** — understanding data distribution in production to inform whether an optimization is worth pursuing. Use the `mcp__clickhouse__run_query` tool:

```sql
-- Row count for reservations in the last 30 days (volume context)
SELECT count() FROM pbp_productionDB_optimized.reservations FINAL
WHERE created_at >= today() - 30

-- Active memberships by state (volume context)
SELECT aasm_state, count() as total
FROM pbp_productionDB_optimized.memberships FINAL
WHERE deleted_at = toDateTime(0)
GROUP BY aasm_state
ORDER BY total DESC

-- Reservations per court (helps decide if court_id index is high-cardinality)
SELECT court_id, count() as total
FROM pbp_productionDB_optimized.reservations FINAL
WHERE created_at >= today() - 30
GROUP BY court_id
ORDER BY total DESC
LIMIT 20
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
# ❌ BAD - No index on status (reservations has court_id, not facility_id;
#          facility is reached via court.facility_id)
Reservation.where(status: 'confirmed')
# EXPLAIN shows: type: ALL, rows: 50000

# ✅ GOOD - Filter on indexed column
Reservation.where(court_id: court.id)
# EXPLAIN shows: type: ref, key: index_reservations_on_court_id, rows: ~50

# To scope by facility, join through courts:
Reservation.joins(:court).where(courts: { facility_id: facility.id })
# Ensure index exists on courts.facility_id (it does: index_courts_on_facility_id)
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

# Add to migration file (use real columns — reservations has court_id, not facility_id):
class AddIndexToReservations < ActiveRecord::Migration[6.1]
  def change
    # Index for status filtering (common query pattern)
    add_index :reservations, :status

    # Composite index for court + date queries (already exists as on_court_and_date,
    # but if adding a new one):
    add_index :reservations, [:court_id, :status]

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

> **Scope**: ClickHouse holds replicated copies of application tables (`pbp_productionDB_optimized`). Use it for **volume context** only (see Step 4 for the `system.query_log` caveat and FINAL rule).

### Runnable Volume Queries (via `mcp__clickhouse__run_query`)

Always add `FINAL` on `*ReplacingMergeTree` tables to avoid ~20× row-count inflation.

```sql
-- Total reservations created in the last 30 days
SELECT count() FROM pbp_productionDB_optimized.reservations FINAL
WHERE created_at >= today() - 30

-- Reservation volume by court (useful before adding a court_id composite index)
SELECT court_id, count() as total
FROM pbp_productionDB_optimized.reservations FINAL
WHERE created_at >= today() - 30
GROUP BY court_id
ORDER BY total DESC
LIMIT 20

-- Membership distribution by state (uses real column: aasm_state, not 'active')
SELECT aasm_state, count() as total
FROM pbp_productionDB_optimized.memberships FINAL
WHERE deleted_at = toDateTime(0)
GROUP BY aasm_state
ORDER BY total DESC
```

## Report Format

> **Template illustration** — fill in real EXPLAIN output and Benchmark.ms timings. ClickHouse provides row-count / cardinality context only; execution frequency and P95 latency fields are not available (`system.query_log` inaccessible — see Step 4). Omit or replace those fields with Benchmark.ms results from Docker.

```markdown
## Query Analysis Report

### Summary
- Files analyzed: N
- Queries analyzed: N
- Slow queries detected: N
- Missing indexes: N
- Complexity score: N/100

### Query Performance Issues

#### Issue 1: Full Table Scan on Reservations
**File**: `app/services/reservation_finder.rb:23`
**Query**:
```ruby
Reservation.where(status: 'confirmed')
```

**EXPLAIN Analysis**:
- Type: ALL (full table scan)
- Rows scanned: 45,000 (from EXPLAIN)
- Benchmark: 2.3s avg (Benchmark.ms in Docker — see Step 7)
- Complexity Score: 120 🚨 CRITICAL

**ClickHouse volume context**:
- Total reservations with status='confirmed': N (use FINAL)

**Fix**:
```ruby
# Add index
add_index :reservations, :status

# Optimized query (if need more columns)
Reservation.where(status: 'confirmed').select(:id, :user_id, :starts_at)
```

**Expected Impact**:
- Rows scanned: 45,000 → ~200 (from EXPLAIN after index)
- Benchmark: 2.3s → ~12ms
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

**Fix**:
```ruby
User.includes(:facility, :memberships).where(active: true)
```

**Expected Impact**:
- Queries: N+1 → 2-3
- Benchmark: measure before/after with Benchmark.ms

---

### Missing Indexes

| Table | Column(s) | Query Pattern | Benchmark Before |
|-------|-----------|---------------|-----------------|
| reservations | status | WHERE status = ? | measure |
| memberships | owner_id, aasm_state | WHERE owner_id = ? AND aasm_state = ? | measure |

Note: `memberships` has `owner_id` (not `user_id`) and `aasm_state` (not `active`). Both already have single-column indexes; a composite may be needed for combined filters.

### Recommendations

1. **Add indexes** (migration needed):
   ```ruby
   add_index :reservations, :status
   add_index :memberships, [:owner_id, :aasm_state]
   ```

2. **Optimize queries**:
   - Use `includes` for associations in GraphQL resolvers
   - Use `pluck` instead of loading full objects when only IDs needed
   - Batch large operations

3. **Before deployment**:
   - Run EXPLAIN on all new queries
   - Use ClickHouse volume queries (FINAL) for cardinality context
   - Benchmark before/after in Docker (Step 7)
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

> **Not implemented** — no `lib/query_analyzer.rb` exists in the codebase. Use the commands above (`bin/d rails console` + `puts query.explain`, `grep` on changed files) directly.

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover a new anti-pattern, a better EXPLAIN interpretation, or a useful ClickHouse query: complete the current analysis first, then run `/kaizen` to append to [kaizen_log.md](kaizen_log.md). Do not self-edit SKILL.md mid-execution.

> **History**: all past Kaizen entries are archived in [kaizen_log.md](kaizen_log.md) — all have been promoted into the active body above.
