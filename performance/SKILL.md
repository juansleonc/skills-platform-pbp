---
name: performance
description: "Detects N+1 queries, missing indexes, memory issues, and slow operations across a diff or code change. Distinct from /query-analyzer (EXPLAIN plans + ClickHouse historical analysis for a specific slow query)."
allowed-tools: [Bash, Read, Grep, Glob, Agent, Edit, mcp__clickhouse__run_query, mcp__clickhouse__list_tables, mcp__opensearch__SearchIndexTool, mcp__rails__execute_ruby]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## When to Use This Skill

Run this skill when:
- **Modifying ActiveRecord queries** (models, services, controllers) with associations
- **Adding GraphQL resolvers** that return collections (prevent N+1 queries)
- **Creating Sidekiq jobs** that process large datasets (10k+ records)
- **Before production deployment** of data-heavy features (reports, exports, analytics)
- **Investigating slow page loads** reported by New Relic/Skylight (>2s response time)

## Shared References

> **📚 This skill uses MCP tools** (ClickHouse, OpenSearch) **for production data analysis.** See allowed-tools list above for available MCPs.
>
> **🤖 Code Simplifier Integration**: See [Code Simplifier Integration Pattern](../shared/code-simplifier-integration.md) for optimization best practices.
>
> **📚 Additional**: Use `Grep` and `Glob` for symbol navigation for resolver / N+1 analysis (Serena removed 2026-06-02)

# Performance Optimization Skill

Detects and prevents performance issues: N+1 queries, missing indexes, memory bloat, and slow operations.

## PRIMARY METHOD: Use MCP Tools for Production Data

**ALWAYS use MCP tools FIRST for performance analysis:**

| Priority | Tool Category | When to Use |
|----------|---------------|-------------|
| 🥇 **PRIMARY** | MCP ClickHouse | Query performance, slow queries, index usage |
| 🥇 **PRIMARY** | MCP OpenSearch | Search query performance, cluster health |
| 🥇 **PRIMARY** | MCP Rails | Routes analysis, model associations |
| 🥈 **FALLBACK** | Grep-based analysis | Only if MCP unavailable |


## CRITICAL RULES

1. **Always use `includes`** to prevent N+1 queries
2. **Add indexes** for foreign keys and WHERE clause columns
3. **Use `pluck`** instead of `select` when you only need values
4. **Batch large operations** to prevent memory bloat
5. **Use deferred queries** for heavy GraphQL operations

## Quick Validation Commands

**Fast N+1 and performance issue detection** (run these first):

```bash
# 1. Find potential N+1 patterns in loops - HIGH RISK
grep -rn "\.each\|\.map" app/ --include="*.rb" -A3 | grep -E "\.\w+\.\w+"
```
**Expected**: Review each match - associations accessed in loops need `includes`

```bash
# 2. Find queries without eager loading - MEDIUM RISK
grep -rn "\.where.*\.each\|\.all.*\.each\|\.find.*\.each" app/ --include="*.rb" | grep -v "includes\|preload"
```
**Expected**: 0-5 matches (all loops over queries should use `includes`)

```bash
# 3. Find models missing indexes on associations - HIGH RISK
for file in app/models/*.rb; do echo "$file"; grep -E "belongs_to|has_many" "$file" | head -3; done | grep -B1 "belongs_to"
```
**Expected**: Cross-reference with `db/schema.rb` - all foreign keys need indexes

```bash
# 4. Find large data operations without batching - MEMORY RISK
grep -rn "\.all\.each\|\.pluck(:id)\.each" app/jobs/ app/services/ --include="*.rb" | grep -v "find_each\|in_batches"
```
**Expected**: 0 matches (use `find_each` or `in_batches` for large datasets)

```bash
# 5. Find GraphQL resolvers without includes - N+1 RISK
grep -rn "def resolve" app/graphql/mutations/ app/graphql/types/ --include="*.rb" -A5 | grep -v "includes\|preload\|dataloader"
```
**Expected**: Review each - resolvers returning collections need eager loading

> Use `Grep` and `Glob` for symbol-level discovery. (Serena removed 2026-06-02.)

## Ruby vs SQL Antipatterns

**Common patterns where Ruby is used instead of SQL, causing major performance issues:**

### 1. Ruby Filtering Instead of SQL WHERE

```bash
# Find Ruby filtering on AR collections - HIGH RISK
grep -rn "\.all\.select\s*{\|\.all\.map\s*{\|\.all\.reject\s*{" app/ --include="*.rb"
grep -rn "\.to_a\.select\|\.to_a\.map\|\.to_a\.reject" app/ --include="*.rb"
```
**Expected**: 0 matches (use `.where()` instead)

```ruby
# ❌ BAD - Loads ALL records, filters in Ruby (O(n) memory)
User.all.select { |u| u.active? }
facility.memberships.to_a.select { |m| m.status == 'active' }

# ✅ GOOD - SQL does the filtering (O(1) memory)
User.where(active: true)
facility.memberships.where(status: 'active')
```

### 2. .length on Associations Instead of .count

```bash
# Find .length on associations - MEDIUM RISK
grep -rn "\.members\.length\|\.users\.length\|\.reservations\.length\|\.memberships\.length" app/ --include="*.rb"
grep -rn "\.\w\+s\.length" app/ --include="*.rb" | grep -v "string\|array\|\.to_s\|\.to_a"
```
**Expected**: 0 matches (use `.count` or `.size`)

```ruby
# ❌ BAD - Loads all records just to count them
facility.users.length      # SELECT * FROM users → Array#length
facility.reservations.length

# ✅ GOOD - SQL count
facility.users.count       # SELECT COUNT(*) FROM users
facility.reservations.size # Uses count if not loaded, length if loaded
```

### 3. .where(...).present? Instead of .exists?

```bash
# Find .present? on queries - MEDIUM RISK
grep -rn "\.where(.*).present?\|\.where(.*).any?\|\.where(.*).blank?" app/ --include="*.rb"
```
**Expected**: 0 matches (use `.exists?` for existence checks)

```ruby
# ❌ BAD - Loads record(s) just to check existence
User.where(email: email).present?   # SELECT * FROM users WHERE email = ...
User.where(email: email).any?       # Same problem

# ✅ GOOD - Only checks existence (SELECT 1 ... LIMIT 1)
User.exists?(email: email)
User.where(email: email).exists?
```

### 4. Ruby Aggregation Instead of SQL

```bash
# Find Ruby .sum/.max/.min on collections - MEDIUM RISK
grep -rn "\.map.*\.sum\|\.pluck.*\.sum\|\.map.*\.max\|\.map.*\.min" app/ --include="*.rb"
```
**Expected**: Review each - most can use `Model.sum(:column)` instead

```ruby
# ❌ BAD - Loads all records, aggregates in Ruby
facility.payments.map(&:amount).sum    # Loads all payment objects
facility.memberships.pluck(:price).sum # Better, but still loads array

# ✅ GOOD - SQL aggregation
facility.payments.sum(:amount)          # SELECT SUM(amount) FROM payments
facility.memberships.maximum(:price)    # SELECT MAX(price)
```

### 5. String Concatenation in Loops

```bash
# Find string += in loops - PERFORMANCE RISK
grep -rn '+= "' app/ --include="*.rb"
grep -B5 '+= "' app/ --include="*.rb" | grep "each\|map\|loop\|while\|for"
```
**Expected**: 0 matches in loops (use `Array#join` or `StringIO`)

```ruby
# ❌ BAD - String concatenation is O(n²) in loops
result = ""
users.each { |u| result += "#{u.name}\n" }

# ✅ GOOD - Array#join is O(n)
result = users.map { |u| u.name }.join("\n")
```

## Audit Process

### Step 1: Identify Performance-Sensitive Changes

```bash
# Find model/service/job changes
git diff develop --name-only | grep -E "(models|services|jobs|controllers|graphql)"
```
**Expected**: List of files with database queries or data processing

```bash
# Find queries in changed files
grep -rn "\.where\|\.find\|\.joins\|\.includes" <changed_files> --include="*.rb"
```
**Expected**: All query locations - review each for N+1 potential

### Step 2: Detect N+1 Queries

```ruby
# ❌ N+1 - Loading associations in loop
users = User.all
users.each do |user|
  puts user.facility.name  # N+1! Queries facility for each user
end

# ✅ FIXED - Eager loading
users = User.includes(:facility).all
users.each do |user|
  puts user.facility.name  # No additional queries
end

# ❌ N+1 in GraphQL resolver
class UsersResolver < BaseResolver
  def resolve
    User.all  # N+1 when client requests associations!
  end
end

# ✅ FIXED - Preload associations
class UsersResolver < BaseResolver
  def resolve
    User.includes(:facility, :memberships).all
  end
end
```

```bash
# Find potential N+1 patterns
grep -rn "\.each\|\.map\|\.find_each" <changed_files> --include="*.rb" -A5 | grep -E "\.\w+\.\w+"
```
**Expected**: Review associations accessed in loops - need `includes` for each

### Illustrative examples (NOT from this codebase — do not cite as evidence)

These examples demonstrate common performance anti-patterns. They are NOT sourced from real files or line numbers in this codebase. Metrics (timings, memory figures) are hypothetical to illustrate the pattern.

**EXAMPLE 1: N+1 query in admin dashboard**
```ruby
# ❌ BAD - Eager loading missing
def index
  @facilities = Facility.where(active: true)
end
# View iterates and calls facility.owner / facility.courts.count — N+1 queries

# ✅ GOOD - Eager load associations
def index
  @facilities = Facility.where(active: true)
                       .includes(:owner, :courts, :memberships)
end
```

Note: `app/controllers/admin/facilities_controller.rb` does not exist at HEAD (only `organizations_controller.rb` and `sso_approvals_controller.rb` are in `app/controllers/admin/`).

**EXAMPLE 2: Missing index on a frequently-queried foreign key**
```ruby
# ❌ BAD - No index on a high-cardinality FK
create_table "some_table" do |t|
  t.integer "facility_id"
  t.string "status"
  # NO INDEX on facility_id
end

# ✅ GOOD - Composite index matches common query
add_index :some_table, [:facility_id, :status]
```

Note on `reservations`: The actual `reservations` table uses `court_id` (not `facility_id`) — facility is reached via court. Any index recommendation must match the actual schema column.

**EXAMPLE 3: Memory bloat in export job**
```ruby
# ❌ BAD - Loads all records into memory at once
def perform(args)
  users = Facility.find(args[:facility_id]).users.all.to_a
  # 100k users → OOM risk
end

# ✅ GOOD - Batch with find_each
def perform(args)
  Facility.find(args[:facility_id]).users.find_each(batch_size: 1000) do |user|
    # At most 1000 objects in memory
  end
end
```

Note: `app/jobs/export_users_job.rb` does not exist at HEAD.

**EXAMPLE 4: GraphQL N+1 in mobile app**
```ruby
# ❌ BAD - Loads courts per-facility without eager loading
def courts
  object.courts
end

# ✅ GOOD - Use dataloader or preloaded includes
def courts
  dataloader.with(Sources::Courts).load(object.id)
end
```

Note: `app/graphql/types/facility_type.rb` does not exist at HEAD (the `app/graphql/types/` directory contains only base classes and scalar types; domain types are located elsewhere in the codebase).

**EXAMPLE 5: Ruby-side count instead of SQL COUNT**
```ruby
# ❌ BAD - Loads all records just to count them
facility.memberships.where(status: 'active').to_a.count

# ✅ GOOD - Let the database count
facility.memberships.where(status: 'active').count  # SELECT COUNT(*)
```

Note: `app/services/dashboard_service.rb` does not exist at HEAD (there is `packs/internal_backend/app/services/internal/reports/dashboard_service.rb`).

### Step 3: Check Missing Indexes

```bash
# Find foreign keys without indexes
grep -rn "belongs_to\|has_many" app/models/ --include="*.rb" | grep -v "#"

# Check if index exists in schema
grep "index.*facility_id\|index.*user_id" db/schema.rb
```

```bash
# PRIMARY: Use MySQL EXPLAIN in Docker to profile slow ActiveRecord queries
bin/d rails runner "puts Model.where(facility_id: 1).explain"

# For row-count / volume context, query the replicated ClickHouse table (FINAL required)
# Example: check reservation volume that might explain a slow query
# mcp__clickhouse__run_query:
#   query: "SELECT count() FROM pbp_productionDB_optimized.reservations FINAL WHERE facility_id = <id>"
#
# For production query timings, use New Relic (named in CLAUDE.md monitoring stack) —
# system.query_log is NOT accessible in this ClickHouse Cloud environment.
```
> **Note**: `system.query_log` logs ClickHouse-internal queries, not MySQL/Rails queries, and is not accessible in this environment (verified count=0 in system.tables). For MySQL slow queries: enable `slow_query_log` locally, or use `EXPLAIN` via `bin/d rails runner`.

### Step 4: Detect Memory Issues

```ruby
# ❌ BAD - Loads all records into memory
users = User.all.to_a
users.each { |u| process(u) }  # 100k users = 100k objects in memory!

# ✅ GOOD - Batched processing
User.find_each(batch_size: 1000) do |user|
  process(user)  # Only 1000 objects at a time
end

# ❌ BAD - Large array in memory
ids = User.pluck(:id)  # 100k IDs in array

# ✅ GOOD - Iterator
User.in_batches(of: 1000).each_record do |user|
  # Process
end

# ❌ BAD - Building large strings
result = ""
users.each { |u| result += u.to_json }  # String concatenation is O(n²)!

# ✅ GOOD - Array join
result = users.map(&:to_json).join(",")
```

### Step 5: Check Query Efficiency

```ruby
# ❌ BAD - Select all columns
User.where(active: true).each { |u| puts u.email }

# ✅ GOOD - Pluck only needed columns
User.where(active: true).pluck(:email).each { |email| puts email }

# ❌ BAD - Count with loaded records
users = User.all
users.count  # Loads ALL records just to count!

# ✅ GOOD - Database count
User.count  # SELECT COUNT(*) FROM users

# ❌ BAD - Multiple queries for existence
User.where(email: email).first.present?

# ✅ GOOD - Single existence check
User.exists?(email: email)
```

### Step 6: GraphQL Performance

```ruby
# ❌ BAD - No lookahead for associations
class UserType < Types::BaseObject
  field :reservations, [ReservationType], null: false

  def reservations
    object.reservations  # N+1 if multiple users requested!
  end
end

# ✅ GOOD - Use dataloader
class UserType < Types::BaseObject
  field :reservations, [ReservationType], null: false

  def reservations
    dataloader.with(Sources::Reservations).load(object.id)
  end
end

# ✅ GOOD - Deferred for heavy operations
field :analytics_data, resolver: AnalyticsResolver do
  extension GraphQL::Pro::Defer
end
```

### Step 7: Sidekiq Job Performance

```ruby
# ❌ BAD - Processing all in one job
def perform(args)
  User.all.each do |user|  # Huge memory, timeout risk!
    process_user(user)
  end
end

# ✅ GOOD - Batch into smaller jobs
def perform(args)
  User.in_batches(of: 100).each do |batch|
    batch.pluck(:id).each do |user_id|
      ProcessUserJob.perform_async({ user_id: user_id })
    end
  end
end
```

### Step 8: Verify with ClickHouse (volume/row-count context only)

> **Important**: `system.query_log` is NOT accessible in this ClickHouse Cloud environment and logs ClickHouse-internal queries — not MySQL/Rails queries. Use the approaches below instead.

**For slow MySQL query identification**: use EXPLAIN in Docker or New Relic production timings.

```bash
# EXPLAIN a specific Rails query in Docker
bin/d rails runner "puts Reservation.where(facility_id: 1, status: 'active').explain"
bin/d rails runner "puts Membership.where(aasm_state: 'active').joins(:membership_plan).explain"
```

**For production row-count / volume context** (replicated app tables — FINAL required):

```sql
-- Row volume for a table (to assess index impact at scale)
-- FINAL required: SharedReplacingMergeTree deduplicates row versions
SELECT count() FROM pbp_productionDB_optimized.reservations FINAL
WHERE facility_id = <facility_id>;

SELECT count() FROM pbp_productionDB_optimized.memberships FINAL
WHERE facility_id = <facility_id> AND status = 'active';
```

**For production query timings**: consult New Relic (named in CLAUDE.md monitoring stack) — it captures real Rails/MySQL response times per endpoint.

### Step 9: Code Optimization (RECOMMENDED)

**After detecting performance issues, use code-simplifier to suggest fixes:**

> **📖 See [Code Simplifier Integration Pattern](../shared/code-simplifier-integration.md)** for complete integration guide (Tier 2: MANDATORY).

```
Agent tool:
  subagent_type: "code-simplifier"
  prompt: |
    Review these files for performance optimization:
    <list of files with detected issues>

    Focus on:
    1. N+1 QUERY FIXES:
       - Add missing includes/preload
       - Batch queries
       - Cache repeated queries

    2. INDEX OPTIMIZATION:
       - Identify missing indexes
       - Suggest composite indexes
       - Remove unused indexes

    3. MEMORY OPTIMIZATION:
       - Replace loops with batch operations
       - Use pluck instead of select
       - Optimize large data processing

    4. QUERY EFFICIENCY:
       - Simplify complex joins
       - Use exists? instead of count
       - Optimize scopes
```

**When to skip code-simplifier**:
- No performance issues detected
- Only configuration changes (no code)
- Pure index additions (migration only, no code changes)
- Single-line typo fixes

**Benefits**:
- ✅ Automatic fix suggestions for detected issues
- ✅ Consistent optimization patterns applied
- ✅ Learns from project conventions
- ✅ Reduces manual analysis time

**Example output**:
```ruby
# code-simplifier suggestion for detected N+1:

# Before (detected N+1 at line 45):
users = User.all
users.each { |u| puts u.facility.name }

# After (code-simplifier optimized):
users = User.includes(:facility).all  # Prevents N+1
users.each { |u| puts u.facility.name }
```

## Performance Checklist

For each changed file:

- [ ] No N+1 queries (associations use `includes`)
- [ ] Foreign keys have indexes
- [ ] Large collections use batching (`find_each`, `in_batches`)
- [ ] Only needed columns selected (`pluck` vs `select`)
- [ ] Existence checks use `exists?` not `present?`
- [ ] GraphQL heavy fields use deferred queries
- [ ] Sidekiq jobs process in batches
- [ ] No string concatenation in loops

## Report Format

```markdown
## Performance Audit

### Summary
- Files analyzed: X
- N+1 issues: Y
- Missing indexes: Z
- Memory concerns: W

### N+1 Query Issues

| File | Line | Pattern | Fix |
|------|------|---------|-----|
| users_controller.rb | 45 | `user.facility` in loop | Add `includes(:facility)` |

### Missing Indexes

| Table | Column | Query Pattern |
|-------|--------|---------------|
| reservations | user_id | WHERE user_id = ? |

### Memory Concerns

| File | Issue | Impact |
|------|-------|--------|
| export_job.rb | Loads all users | OOM on 100k+ users |

### ClickHouse Analysis

| Query Pattern | Avg Time | Recommendation |
|---------------|----------|----------------|
| SELECT * FROM reservations WHERE facility_id | 2.5s | Add composite index |

### Recommendations
1. Add `includes(:facility, :memberships)` to UsersController#index
2. Add index on reservations(facility_id, status)
3. Use `find_each` in ExportJob
```

## Example

```
Claude detects model/service changes:

## Performance Audit

### Scanning: app/controllers/admin/users_controller.rb

### N+1 Query Detected!

```ruby
# Line 23
def index
  @users = User.where(active: true)
end

# Line in view: users/_user.html.erb
<%= user.facility.name %>
<%= user.memberships.count %>
```

This will cause N+1 queries for:
- `facility` association (1 query per user)
- `memberships` association (1 query per user)

With 100 users = 201 queries instead of 3!

### Fix

```ruby
def index
  @users = User.where(active: true)
              .includes(:facility, :memberships)
end
```

### ClickHouse Verification
Current avg query time for users index: 3.2s
Expected after fix: ~200ms

### Result: PERFORMANCE FIX NEEDED
```

---

## Related Skills

This skill works with:
- **`/code-review`** - Comprehensive review includes performance checks (N+1 detection)
- **`/graphql`** - GraphQL resolvers need deferred queries and dataloaders
- **`/multi-tenancy`** - Facility scoping with `includes` prevents N+1
- **`/sidekiq`** - Job batching patterns prevent memory bloat
- **`/query-analyzer`** - Deep dive into specific slow queries with EXPLAIN plans

**Workflow**: `/orchestrate feature` includes performance validation for data-heavy features

---

## MCP Integrations

**Performance skill works via grep-based analysis by default.** However, MCP tools provide valuable production data context:

### ClickHouse MCP (Recommended)

Use for row-count / volume context against production replicated tables (FINAL required).
**Do NOT use `system.query_log`** — it is not accessible in this ClickHouse Cloud environment and only logs ClickHouse-internal queries, not MySQL/Rails queries.

```
# Row-count context: how many rows does this query touch at production scale?
mcp__clickhouse__run_query:
  query: |
    SELECT count() FROM pbp_productionDB_optimized.payments FINAL
    WHERE facility_id = <facility_id>
      AND created_at >= today() - 30
```

### OpenSearch MCP (Optional)

Use for analyzing search query performance:

```
# Check slow search queries
mcp__opensearch__SearchIndexTool:
  index: users
  query: { "match_all": {} }
  explain: true
```

### Rails MCP (Optional)

Use for interactive debugging when needed:

```
# Query model associations
mcp__rails__execute_ruby:
  command: "User.reflect_on_all_associations.map(&:name)"
```


---

## Kaizen Log

> Full history archived in [kaizen_log.md](kaizen_log.md). Add new entries there and run `/kaizen` to promote lessons into the active body — do NOT self-edit SKILL.md mid-execution.

**Recent entries** (2 most recent):

<!-- Kaizen: 2026-06-10 — Fabrication purge / honest baselines -->
- Deleted/relabeled 4 fabricated "Real PBP Violations" (files do not exist at HEAD). Section relabeled "Illustrative examples (NOT from this codebase)". Invented New Relic metrics removed. Schema claim corrected: `reservations` has `court_id`, not `facility_id`. MCP tool names corrected throughout.

<!-- Kaizen: 2026-06-10 — ClickHouse SQL run-test pass -->
- Removed all queries against `system.query_log` (inaccessible in this ClickHouse Cloud environment; logs CH-internal queries, not MySQL/Rails). Replaced with: MySQL EXPLAIN via `bin/d rails runner`, replicated app tables with FINAL for row-count context, New Relic for production timings. Removed dead `mcp__ide__*` tools from frontmatter.
- Ground truth: payments columns + table list verified against production ClickHouse by the coordinator on 2026-06-10; `system.query_log` is not accessible in this environment.
