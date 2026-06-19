---
name: performance
description: "Detects N+1 queries, missing indexes, memory issues, and slow operations across a diff or code change. Distinct from /query-analyzer (EXPLAIN plans + ClickHouse historical analysis for a specific slow query)."
allowed-tools: [Bash, Read, Grep, Glob, Agent, Edit, mcp__clickhouse__run_query, mcp__clickhouse__list_tables, mcp__opensearch__SearchIndexTool, mcp__rails__execute_ruby]
disable-model-invocation: false
---

# Performance Optimization Skill

Detects and prevents performance issues: N+1 queries, missing indexes, memory bloat, and slow operations.

## When to Use This Skill

- **Modifying ActiveRecord queries** (models, services, controllers) with associations
- **Adding GraphQL resolvers** that return collections (prevent N+1)
- **Creating Sidekiq jobs** that process large datasets (10k+ records)
- **Before production deployment** of data-heavy features (reports, exports, analytics)
- **Investigating slow page loads** reported by New Relic/Skylight (>2s)

> **References** — MCP tools (ClickHouse, OpenSearch, Rails) for production data: see `allowed-tools` above. Code-simplifier integration: [../shared/code-simplifier-integration.md](../shared/code-simplifier-integration.md). Use `Grep`/`Glob` for symbol navigation in resolver / N+1 analysis.

## PRIMARY METHOD: MCP Tools for Production Data

Use MCP tools FIRST for performance analysis:

| Priority | Tool | When |
|----------|------|------|
| 🥇 PRIMARY | EXPLAIN + New Relic | Slow-query ID, real timings (Step 8) |
| 🥇 PRIMARY | MCP OpenSearch | Search query perf, cluster health |
| 🥇 PRIMARY | MCP Rails | Routes, model associations |
| 🥈 SECONDARY | MCP ClickHouse | Row-count / volume context only (NOT slow-query detection) |
| 🥈 FALLBACK | Grep analysis | Only if MCP unavailable |

## CRITICAL RULES

1. **Always use `includes`** to prevent N+1 queries
2. **Add indexes** for foreign keys and WHERE clause columns
3. **Use `pluck`** instead of `select` when you only need values
4. **Batch large operations** to prevent memory bloat
5. **Use deferred queries** for heavy GraphQL operations

## Detection Greps (consolidated)

Run these to triage a diff. Each detection appears once.

| # | Risk | What it finds | Grep |
|---|------|---------------|------|
| 1 | HIGH | N+1 (associations in loops) | `grep -rn "\.each\|\.map\|\.find_each" <files> --include="*.rb" -A5 \| grep -E "\.\w+\.\w+"` |
| 2 | MED | Queries without eager loading | `grep -rn "\.where.*\.each\|\.all.*\.each\|\.find.*\.each" app/ --include="*.rb" \| grep -v "includes\|preload"` |
| 3 | HIGH | FK assocs (cross-ref schema for index) | `grep -rEn "belongs_to\|has_many" app/models/*.rb \| grep -v "#"` then `grep "index.*facility_id\|index.*user_id" db/schema.rb` |
| 4 | MEM | Large ops without batching | `grep -rn "\.all\.each\|\.pluck(:id)\.each" app/jobs/ app/services/ --include="*.rb" \| grep -v "find_each\|in_batches"` |
| 5 | N+1 | GraphQL resolvers without eager loading | `grep -rn "def resolve" app/graphql/mutations/ app/graphql/types/ --include="*.rb" -A5 \| grep -v "includes\|preload\|dataloader"` |
| 6 | HIGH | Ruby filtering vs SQL WHERE | `grep -rn "\.all\.select\s*{\|\.to_a\.select" app/ --include="*.rb"` |
| 7 | MED | `.length` on assocs vs `.count` | `grep -rn "\.\w\+s\.length" app/ --include="*.rb" \| grep -v "string\|array\|\.to_s\|\.to_a"` |
| 8 | MED | `.where(...).present?` vs `.exists?` | `grep -rn "\.where(.*).present?\|\.where(.*).any?\|\.where(.*).blank?" app/ --include="*.rb"` |
| 9 | MED | Ruby aggregation vs SQL | `grep -rn "\.map.*\.sum\|\.pluck.*\.sum\|\.map.*\.max\|\.map.*\.min" app/ --include="*.rb"` |
| 10 | PERF | String `+=` in loops (O(n²)) | `grep -rn '+= "' app/ --include="*.rb"` then check for `each\|map\|loop\|while\|for` |

> Full ❌/✅ before/after code pairs for the antipattern greps in the table above: [reference/ruby-vs-sql-antipatterns.md](reference/ruby-vs-sql-antipatterns.md).

## Audit Checklist (per changed file)

Worked ❌/✅ code for steps 2,4,5,6,7: [reference/audit-steps.md](reference/audit-steps.md).

- [ ] **Step 1 — Scope**: `git diff develop --name-only | grep -E "(models|services|jobs|controllers|graphql)"`, then grep `\.where\|\.find\|\.joins\|\.includes` in changed files.
- [ ] **Step 2 — N+1**: grep #1. Associations accessed in loops need `includes`. GraphQL N+1 → Step 6.
- [ ] **Step 3 — Missing indexes**: grep #3 (FKs) cross-referenced against `db/schema.rb`. Profile with `bin/d rails runner "puts Model.where(facility_id: 1).explain"`. Volume context + slow-query notes → Step 8 (canonical).
- [ ] **Step 4 — Memory**: grep #4. Use `find_each` / `in_batches`, not `.all.to_a` / large `pluck` arrays.
- [ ] **Step 5 — Query efficiency**: `pluck` only needed columns; DB `count`/`size`, not loaded-record count. Existence → grep #8 / `.exists?`.
- [ ] **Step 6 — GraphQL**: resolvers returning collections use `dataloader`; heavy fields use `GraphQL::Pro::Defer`.
- [ ] **Step 7 — Sidekiq**: batch into smaller jobs (`in_batches` → `perform_async` per id), never `.all.each` in one job.
- [ ] **Step 8 — Verify scale (ClickHouse, volume only)**: see below.
- [ ] **Step 9 — Optimize**: code-simplifier (see below).

### Illustrative examples

> Five worked anti-pattern examples (N+1 dashboard, missing FK index, export-job memory bloat, GraphQL N+1, Ruby-side count): [reference/examples.md](reference/examples.md). NOT from this codebase — paths are placeholders, metrics hypothetical.

### Step 8: Verify with ClickHouse (volume / row-count context only) — canonical

> MCP tool names are in `allowed-tools` (top of file). `system.query_log` is NOT accessible in this ClickHouse Cloud environment and logs ClickHouse-internal queries — not MySQL/Rails. Step 3 defers here for all slow-query / volume notes.

**Slow MySQL query ID** → EXPLAIN in Docker or New Relic timings:

```bash
bin/d rails runner "puts Reservation.where(facility_id: 1, status: 'active').explain"
bin/d rails runner "puts Membership.where(aasm_state: 'active').joins(:membership_plan).explain"
```

**Production row-count / volume** (replicated app tables — FINAL required, deduplicates SharedReplacingMergeTree versions):

```sql
SELECT count() FROM pbp_productionDB_optimized.reservations FINAL
WHERE facility_id = <facility_id>;

SELECT count() FROM pbp_productionDB_optimized.memberships FINAL
WHERE facility_id = <facility_id> AND status = 'active';
```

**Production query timings** → New Relic (CLAUDE.md monitoring stack); captures real Rails/MySQL response times per endpoint.

### Step 9: Code Optimization (RECOMMENDED)

After detecting issues, run code-simplifier (Tier 2: RECOMMENDED) on the flagged files for N+1 fixes, index optimization, memory batching, and query efficiency.

> Prompt template, rationale, and example output: [../shared/code-simplifier-integration.md](../shared/code-simplifier-integration.md).

**Skip code-simplifier when**: no issues detected · config-only changes · pure index migration (no code) · single-line typo fixes.

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

> Fill the template in [reference/audit-output-template.md](reference/audit-output-template.md). Sections: Summary, N+1 Query Issues, Missing Indexes, Memory Concerns, Production Scale (ClickHouse row-count, NOT timings), Recommendations.

## Example

See [Worked example: N+1 in controller](reference/examples.md) for an end-to-end audit walkthrough (placeholder path, no fabricated metrics).

---

## Related Skills

- **`/code-review`** — comprehensive review includes performance checks (N+1 detection)
- **`/graphql`** — resolvers need deferred queries and dataloaders
- **`/multi-tenancy`** — facility scoping with `includes` prevents N+1
- **`/sidekiq`** — job batching prevents memory bloat
- **`/query-analyzer`** — deep dive into specific slow queries with EXPLAIN plans

**Workflow**: `/orchestrate feature` includes performance validation for data-heavy features.

---

## Kaizen Log

> Full history archived in [kaizen_log.md](kaizen_log.md). Add new entries there and run `/kaizen` to promote lessons into the active body — do NOT self-edit SKILL.md mid-execution.

**Recent entries** (2 most recent):

<!-- Kaizen: 2026-06-10 — Fabrication purge / honest baselines -->
- Deleted/relabeled 4 fabricated "Real PBP Violations" (files do not exist at HEAD). Section relabeled "Illustrative examples (NOT from this codebase)". Invented New Relic metrics removed. Schema claim corrected: `reservations` has `court_id`, not `facility_id`. MCP tool names corrected throughout.

<!-- Kaizen: 2026-06-10 — ClickHouse SQL run-test pass -->
- Removed all queries against `system.query_log` (inaccessible in this ClickHouse Cloud environment; logs CH-internal queries, not MySQL/Rails). Replaced with: MySQL EXPLAIN via `bin/d rails runner`, replicated app tables with FINAL for row-count context, New Relic for production timings. Removed dead `mcp__ide__*` tools from frontmatter.
