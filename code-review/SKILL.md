---
name: code-review
description: Use when reviewing a diff or branch for correctness, conventions, security, and performance before merge.
allowed-tools: [Bash, Read, Grep, Glob, Agent, Edit, mcp__github__*, mcp__context7__resolve-library-id, mcp__context7__query-docs, mcp__clickhouse__run_query, mcp__clickhouse__list_tables, mcp__honeybadger__list_faults, mcp__honeybadger__get_fault, mcp__sentry__find_projects, mcp__sentry__search_issues, mcp__sentry__search_issue_events, mcp__sentry__get_sentry_resource, mcp__opensearch__*]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## Shared References

> **📚 This skill uses shared documentation. See:**
> - [Critical Rules](../shared/critical-rules.md) - all project-wide rules
> - [Forbidden Patterns](../shared/forbidden-patterns.md) - patterns to avoid
> - [ClickHouse Queries](../shared/clickhouse-queries.md) - common queries
> - [Code Simplifier Integration](../shared/code-simplifier-integration.md) - code optimization (Tier 2: MANDATORY)
> - Use `Grep` and `Glob` for symbol search, references, and large-file navigation (Serena removed 2026-06-02)
> - [ast-grep Patterns](../shared/ast-grep-patterns.md) — AST-aware structural pattern detection (polymorphic associations, DSL audits)

# Code Review Skill

Comprehensive code review enforcing all project critical rules using grep-based analysis. Optional manual research with Context7 (docs), ClickHouse (production data), and Honeybadger (errors) when additional context is needed.

> **Skill scope**: Use `/code-review` for convention/correctness/performance review of a diff (the "is this code right?" gate). Use `/adversarial-review` when you need a reasoning-based gate that actively tries to BREAK a fix or claim (the "can this fail?" gate).
>
> **Delegation / pairing (don't duplicate depth here)** — `/code-review` does the broad spot-check; hand off the deep analysis so this skill stays lean:
> - **ClickHouse / query verification** (EXPLAIN plans, index validation, production volume on a specific query) → defer to **`/query-analyzer`**. Steps 12 here are a spot-check, not the deep dive.
> - **Deep N+1 / index / memory analysis** across the diff → defer to **`/performance`** (broad code-pattern review). The Performance checklist below flags candidates; `/performance` confirms them.
> - **Adversarial failure-construction** (actively building inputs/races that BREAK a fix) → pair with **`/adversarial-review`**; it complements, not replaces, this skill's correctness pass.

## MCP TOOLS FOR CODE REVIEW

**Code review works via grep-based analysis by default.** However, MCP tools provide valuable context:

| Priority | Tool Category | When to Use | Required |
|----------|---------------|-------------|----------|
| 🥇 **PRIMARY** | Context7 | Best practices from official docs | Recommended for unfamiliar patterns |
| 🥇 **PRIMARY** | ClickHouse | Verify against production data (10.4M users) | MANDATORY for payment/financial/data-integrity; recommended otherwise |
| 🥇 **PRIMARY** | code-simplifier agent | Code optimization & cleanup | Mandatory for non-trivial changes |
| 🥈 **OPTIONAL** | Honeybadger | Related production errors (Rails) | When debugging production issues |
| 🥈 **OPTIONAL** | Sentry | GraphQL, Mobile, Frontend errors | When debugging production issues |
| 🥈 **OPTIONAL** | Jupyter (local only) | Interactive data analysis — requires local JupyterLab; `mcp__ide__*` not available in this env | Complex queries, visualizations |

## ⚠️ PRODUCTION DATA VERIFICATION

**MANDATORY for payment/financial/data-integrity changes; recommended otherwise.**

Consider checking ClickHouse production data when reviewing code that:
- Queries database tables
- Handles NULL values
- Iterates over collections
- Processes user data

This prevents bugs from hitting production where data patterns differ from development.

```sql
-- Database: pbp_productionDB_optimized

-- ALWAYS run these checks for any model/table changes:

-- 1. Check actual NULL patterns (dev data lies!)
SELECT
  count(*) as total,
  countIf(<field> IS NULL) as nulls,
  round(countIf(<field> IS NULL) / count(*) * 100, 2) as null_percentage
FROM pbp_productionDB_optimized.<table>

-- 2. Check data distribution for edge cases
SELECT <field>, count(*) as cnt
FROM pbp_productionDB_optimized.<table>
GROUP BY <field>
ORDER BY cnt DESC
LIMIT 20

-- 3. Check max/min values for validation bounds
SELECT
  min(<field>) as min_val,
  max(<field>) as max_val,
  avg(<field>) as avg_val
FROM pbp_productionDB_optimized.<table>
WHERE <field> IS NOT NULL

-- 4. Check for orphaned records (foreign key violations)
SELECT count(*) as orphans
FROM pbp_productionDB_optimized.<child_table> c
LEFT JOIN pbp_productionDB_optimized.<parent_table> p ON c.<foreign_key> = p.id
WHERE p.id IS NULL
```

## Critical Rules Enforcement (MANDATORY)

**Every review MUST verify these project rules:**

| Rule | How to Check |
|------|--------------|
| Timezone Safety | No `Time.now`, `Date.today`, `DateTime.now` |
| Multi-tenancy | All queries scoped by `facility_id` |
| Financial Transactions | Payment ops wrapped in `ActiveRecord::Base.transaction` |
| API Compatibility | No breaking changes for mobile apps |
| Payment Idempotency | Payment jobs use idempotency keys |
| No AI Mentions | No Claude/AI references in commits |
| No Ticket IDs in Comments | Use commit prefix `TICKET-123 \|` instead of `# TICKET-123: comment` |

## Review Process

### Step 1: Identify Changes

```bash
git diff develop --name-only
git diff develop --stat
```

### Step 2: Critical Rules Check (FIRST PRIORITY)

Before any other review, verify critical rules:

```bash
# Timezone safety
grep -rn "Time\.now\|Date\.today\|DateTime\.now" <changed_files> --include="*.rb"

# Nil safety: &. result fed into string interpolation (needs nil validation)
grep -rn '&\.\w\+.*".*#{'  <changed_files> --include="*.rb"
grep -A5 '&\.\w\+' <changed_files> --include="*.rb" | grep -B1 '".*#{.*}' | head -20

# Nil safety: .first result used without validation
grep -A3 '\.first[^_]' <changed_files> --include="*.rb" | grep -v 'if\|unless\|&\.\|try' | head -20

# Multi-tenancy: queries not scoped by facility_id
grep -rn "\.where\|\.find_by\|\.find\|scope" <changed_files> --include="*.rb" | grep -v "facility"

# Payment ops — verify wrapped in ActiveRecord::Base.transaction
grep -rn "PaymentService\|PaymentTransaction\|payment" <changed_files> --include="*.rb"

# API/mobile compat — field changes in GraphQL
git diff develop -- app/graphql/ | grep -E "^[-+].*field\s+:"

# Ticket IDs in comments (FORBIDDEN — belong in commit prefix; regression tests exempt)
grep -rn "#.*\(CORE-[0-9]\|PLA-[0-9]\|CLS-[0-9]\)" <changed_files> --include="*.rb" | grep -v "regression\|Regression"
```

> Also flag **redundant comments** that restate WHAT the code does (`# Add new fields`, `# Update display status`) — comments are for non-obvious WHY only.

### Step 3: Method Refactoring Pattern Detection (MANDATORY - Two-Part Check)

**When git diff shows a method being moved/renamed, must verify TWO things:**

1. **Part 1 — All callers updated to new signature.** Detect with `git diff develop | grep -E "^-.*def (method_name)"`, then `grep -rn "old_class\.method_name" app/ spec/ packs/` — expect zero matches (or historical files only). Common patterns: model method moved, service renamed, module relocated, helper moved.
2. **Part 2 — New method handles nil safely.** Extract the new body (`git diff develop <file> | grep -A20 "^+.*def method_name"`) and check for direct dereferences (`object.attribute`) where `object` might be nil. Add a `return X if object.blank?` guard BEFORE any `.` call.

**Nil Safety Checklist for New/Refactored Methods:**

| Pattern | Example | Risk | Fix |
|---------|---------|------|-----|
| Direct dereference | `facility.current_time` | NoMethodError if nil | `return X if facility.blank?` |
| Chained calls | `user.profile.avatar` | Crashes on any nil | `user&.profile&.avatar` |
| String interpolation | `"#{user.name}"` | Empty if nil, crash if further call | Validate before interpolation |
| Array access | `items.first.price` | Crashes if nil | `items.first&.price` |
| Method expecting objects | `date.strftime('%Y')` | NoMethodError | Guard: `date ? date.strftime(...) : nil` |

**For every variable used in a new method, ask:** Can this be nil? If yes, is there a nil guard BEFORE dereferencing? Should I check production data with ClickHouse (Step 12)?

**When to use:** ✅ method removal + addition with same name in different classes · ✅ new methods that dereference variables · ✅ refactoring methods that call attributes on objects. ❌ Skip for purely internal private methods (one caller).

> **📖 Full worked walkthrough (Part 1/Part 2 bash commands, the CORE-205 buggy-vs-fixed example, and the `owner_facility_id` production-validation SQL): see [Code Review Examples → Example A](../shared/code-review-examples.md#example-a-method-refactoring-pattern-detection-two-part-check).**

### Step 4: Structural Quality Check

**Detect structural code smells in changed files:**

> **📖 Warning/critical limits + the full detection-command set (fat controller, long method, callback overload, Demeter, associations/scopes/public-methods per model) → [Structural Thresholds](../shared/structural-thresholds.md).**
>
> Use `Grep` and `Glob` for symbol-level discovery. (Serena removed 2026-06-02.)

Representative check (fat model: >200 warning, >400 critical) on changed files; run the rest from the shared file scoped to `git diff develop --name-only`:

```bash
git diff develop --name-only -- app/models/ | while read f; do
  lines=$(wc -l < "$f" 2>/dev/null)
  if [ "$lines" -gt 400 ]; then echo "🔴 CRITICAL: $f has $lines lines (>400)"
  elif [ "$lines" -gt 200 ]; then echo "🟡 WARNING: $f has $lines lines (>200)"; fi
done

# Law of Demeter (chains >3 levels) in changed Ruby files
git diff develop --name-only -- '*.rb' | xargs grep -n '\.\w\+\.\w\+\.\w\+\.\w\+' 2>/dev/null | grep -v "#\|spec/\|test/\|migration"
```

**LLM-slop / dead-abstraction check (codegen-era):** beyond structural smells, flag code that is *plausible but pointless* — the fastest-growing defect class with AI-assisted authoring. In changed files look for:
- Speculative abstraction with a single caller (a wrapper/indirection that adds no behavior) → inline it.
- Defensive cruft for impossible states (nil-guard on a value the type guarantees; rescue around code that cannot raise).
- Dead params, unused yields, options no caller ever exercises.
- "Belt-and-suspenders" duplication: the same guard re-checked at multiple layers within this diff.

Bar: *does this token earn its place?* If removing it changes no behavior and loses no WHY → slop; route to `/simplify`.

### Step 5: Specification Test (Layer Validation)

> **📖 See [Testing Wrong Layer](../shared/testing-patterns.md) for detailed anti-patterns and examples.**

> Inspired by palkan's "Layered Design for Ruby on Rails Applications"

**Mental exercise**: For each changed file, imagine the test skeleton you'd need. If the tests reveal wrong-layer dependencies, flag them.

**Red flags in imagined test skeletons:**

| If you see this in tests... | It means... | Action |
|-----------------------------|-------------|--------|
| `context 'when HTTP response fails'` in a **model** spec | Model calls external APIs directly | Extract HTTP calls to a service |
| `expect(UserMailer).to receive(:welcome)` in a **model** spec | Model sends emails directly | Extract to service/callback removal |
| `expect(order.total).to eq(90)` in a **controller** spec | Business logic tested at wrong layer | Move assertion to model spec |
| Heavy mocking of external services in **model** specs | Model has too many external dependencies | Model should not know about external services |
| `stub_request(:post, ...)` in a **model** spec | Model makes HTTP calls | Extract to service |

```bash
# Detect tests at wrong layer
# Controller tests verifying business logic (should be in model specs)
grep -rn "expect.*\.total\|expect.*\.calculate\|expect.*\.price\|expect.*\.discount" spec/controllers/ spec/requests/ --include="*.rb" 2>/dev/null | head -10

# Model specs stubbing external services (model shouldn't know about them)
grep -rn "stub_request\|WebMock\|VCR" spec/models/ --include="*.rb" 2>/dev/null | head -10

# Model specs expecting mailer/job calls (upward dependency)
grep -rn "expect.*Mailer\|expect.*Job\|expect.*perform_later\|expect.*deliver" spec/models/ --include="*.rb" 2>/dev/null | head -10
```

**Layer responsibility checklist for changed files:**
- [ ] **Controllers** only test: auth, params parsing, HTTP response codes, redirects
- [ ] **Services** only test: orchestration flow, delegation to models
- [ ] **Models** test: validations, scopes, associations, business rules (no external deps)
- [ ] **Jobs** test: argument handling, idempotency, error recovery (delegate business logic)

### Step 6: Multi-Tenancy Deep Check

For ANY model/service that accesses data:

```ruby
# BAD - Missing facility scope
User.where(email: email)
Reservation.find_by(id: id)

# GOOD - Properly scoped
facility.users.where(email: email)
facility.reservations.find_by(id: id)
current_facility.members.where(...)
```

**Exception:** Admin users with explicit query overrides for cross-facility access.

### Step 7: API Backward Compatibility

For ANY GraphQL changes: removing a field, changing a field type, or removing a query/mutation BREAKS mobile — deprecate instead (`deprecation_reason:`); adding a field is always safe. Defer to **`/graphql`** for the full backward-compat pass.

> **📖 Good/bad examples → [step-playbooks.md → Step 7](reference/step-playbooks.md#step-7--api-backward-compatibility-graphql).**

### Step 8: Sidekiq Job Patterns

For ANY job changes: single hash argument (`def perform(args)` + `deep_symbolize_keys`), variables initialized BEFORE try blocks, payment jobs idempotent via an idempotency key. Defer to **`/sidekiq`** for full validation.

> **📖 Good/bad examples → [step-playbooks.md → Step 8](reference/step-playbooks.md#step-8--sidekiq-job-patterns).**

### Step 9: Cross-Job Consistency Validation

**When reviewing multiple similar jobs** (e.g., 3 new reminder jobs), check for PATTERN CONSISTENCY across error handling (`rescue StandardError`), throttling (`sidekiq_throttle`), and error notification (`JobsNotificationMailer`/`ErrorService`).

**Red Flag**: one job in a group has a guard the others lack = INCONSISTENCY BUG. If 2+ jobs share a pattern, ALL similar jobs should.

> **📖 Consistency-grep script + the CORE-81 `MembershipReminderJob` missing-rescue example → [step-playbooks.md → Step 9](reference/step-playbooks.md#step-9--cross-job-consistency-core-81-worked-example).**

### Step 10: GraphQL Patterns

Check: deferred queries (`GraphQL::Pro::Defer`) for heavy operations · auth in `GraphqlController` not resolvers · `rescue_from ActiveRecord::RecordNotFound` → `GraphQL::ExecutionError`.

> **📖 Code examples → [step-playbooks.md → Step 10](reference/step-playbooks.md#step-10--graphql-patterns).**

### Step 11: Context7 Best Practices Lookup (Optional - Manual)

When you hit an unfamiliar pattern, manually query Context7 (`resolve-library-id` → `query-docs`) for official-docs best practices on ActiveRecord, Sidekiq, GraphQL, RSpec, Redis, or payment idempotency.

> **📖 Query catalog (by code type + performance-specific queries) → [context7-queries.md](reference/context7-queries.md).**

### Step 12: ClickHouse Production Data Verification (MANDATORY for Data Operations)

**CRITICAL**: Production data patterns ALWAYS differ from development. MANDATORY checks for any code that:
- Calls `.first`, `.last`, `.find_by`, or `[]` on collections
- Uses `&.` safe navigation
- Iterates with `.each`, `.map`, `.find_each`
- Processes user-provided data

**Quick NULL validation** (run this FIRST):
```bash
# Find all .first, .last, .try, &. calls in changed files
grep -rn '\.first\|\.last\|\.try\|&\.' <changed_files> --include="*.rb"

# For EACH match, verify:
# 1. Is result used in string interpolation? → Check for nil
# 2. Is result passed to method expecting non-nil? → Add validation
# 3. Is result iterated? → Check for empty collection
```

When needed, manually query ClickHouse (database `pbp_productionDB_optimized`) to verify code against production data. The five-query template covers: (1) table structure, (2) row volume, (3) NULL patterns, (4) field cardinality, (5) `EXPLAIN` of the generated query.

**Performance red flags to check:**

| Pattern | ClickHouse Query | Action |
|---------|------------------|--------|
| Iterating all records | `SELECT count(*) FROM table` | If > 10k, need pagination |
| Filtering by non-indexed field | Check cardinality | Add index or change approach |
| NULL handling | Check NULL percentage | Add explicit NULL checks |
| N+1 in loops | Check related table size | Use includes/preload |

> **📖 Full SQL template (the 5 verification queries + the memberships slow-query example): see [Code Review Examples → Example B](../shared/code-review-examples.md#example-b-clickhouse-production-data-verification-template-step-12).**
>
> **Delegation:** for EXPLAIN-plan + index validation + ClickHouse volume context on a *specific* slow query, defer to **`/query-analyzer`** (this step is the broad in-review spot-check; `/query-analyzer` is the deep dive).

### Step 13: Production Error Context (Honeybadger + Sentry)

Check for related production errors in both systems for the changed files: Honeybadger (Rails) via `list_faults`/`get_fault`; Sentry (GraphQL/Mobile/Frontend) via `search_issues`. Route by changed code — GraphQL → `sentry/graphql_pro`, mobile → `sentry/pbp-mobile`, frontend → `sentry/platform-frontend-0j`, Sidekiq → `sentry/sidekiq-platform`, general Rails → Honeybadger + `sentry/platform`.

> **📖 Invocation snippets + full project-slug routing table → [error-context-mcp.md](reference/error-context-mcp.md).**

### Step 14: Code Simplifier Agent (MANDATORY)

**ALWAYS run code-simplifier for any non-trivial changes** (Tier 2: MANDATORY). Skip ONLY for single-line typo fixes, comment-only changes, or config-file changes.

Invoke the `code-simplifier` Agent on the changed files, focusing on: PERFORMANCE (queries, N+1, loops, memory bloat), SIMPLIFICATION (redundancy, complex conditionals, long methods, naming), RAILS PATTERNS (scopes vs class methods, callbacks, service objects), and TEST EFFICIENCY (build vs create, setup, slow patterns).

> **📖 Full agent prompt + integration details → [../shared/code-simplifier-integration.md](../shared/code-simplifier-integration.md).**

### Step 15: Run Automated Checks (Docker)

**Linting Rules:**
- **Modified files** → Pronto (only changed lines, preserves legacy)
- **New files** → RuboCop -A (full lint OK for new code)

```bash
# Pronto - for modified files
bin/d pronto run -c develop

# RuboCop - ONLY for new files
bin/d rubocop -A path/to/new_file.rb

# Brakeman for security
bin/d brakeman --only-files <files>
```

## Review Dimensions

### 1. Critical Rules (BLOCKING)
See the **Critical Rules Enforcement** table near the top of this skill (timezone, multi-tenancy, financial transactions, API compat, idempotency, no-AI-mentions, no-ticket-IDs) + [../shared/critical-rules.md](../shared/critical-rules.md). Do not re-list here — that table is the single canonical BLOCKING checklist.

### 2. Architecture Review
- [ ] Package boundaries (Packwerk compliance)
- [ ] Service layer patterns (ApplicationService vs Interactor)
- [ ] Multi-tenancy proper scoping
- [ ] API backward compatibility

### 3. Security Review (Context7: OWASP, Brakeman)
- [ ] SQL injection vulnerabilities
- [ ] XSS in views
- [ ] CSRF protection
- [ ] Sensitive data exposure
- [ ] Payment data handling (never log card numbers)
- [ ] Authentication/authorization gaps
- [ ] Webhook credential encryption

### 4. Performance Review (Context7: Rails Performance)
- [ ] N+1 queries (missing `includes`)
- [ ] Missing database indexes
- [ ] GraphQL deferred queries for heavy operations
- [ ] Redis/cache usage patterns
- [ ] Sidekiq job efficiency

### 5. Code Quality (via code-simplifier agent)
- [ ] Unnecessary complexity
- [ ] Code duplication
- [ ] Naming clarity
- [ ] Method length
- [ ] Class responsibilities
- [ ] No ticket IDs in code comments (use commit message prefix instead)

### 6. Test Quality
- [ ] No `allow_any_instance_of` / `expect_any_instance_of`
- [ ] No hardcoded IDs: `create(:user, id: 1)`
- [ ] Factory usage: `build` > `build_stubbed` > `create`
- [ ] Time tests use `Timecop.freeze(Time.current)`
- [ ] Redis cleared in rate limiting tests
- [ ] 100% coverage on changes

## Report Format

> **📖 Full output template (Critical Rules table, Context7/ClickHouse/error sections, Architecture/Security/Performance findings, Recommendations) → [output-format.md](reference/output-format.md).**

## Project-Specific Checklists

Apply the relevant per-domain block based on what the diff touches — Payment, GraphQL, Sidekiq Jobs, Models, Webhooks, Tests. (Project-wide BLOCKING rules are in the Critical Rules Check above + [../shared/critical-rules.md](../shared/critical-rules.md); these are the per-domain residuals.)

> **📖 Per-domain checklists → [domain-checklists.md](reference/domain-checklists.md).**

---

## MCP Integrations

- **GitHub MCP** — PR-based review (`get_pull_request`, `get_pull_request_files`, `create_pull_request_review`).
- **OpenSearch MCP** — search-related code (`IndexMappingTool`, `SearchIndexTool` with `explain: true`).

> **📖 Invocation snippets → [mcp-integrations.md](reference/mcp-integrations.md).** (`mcp__mermaid__*` removed — server absent in this env; use text diagrams.)

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover a new code pattern to check, a missing review criterion, or a better Context7/ClickHouse query: complete the current review first, then append to this skill using the Edit tool with format `<!-- Kaizen: YYYY-MM-DD --> New content`.

> **Full entry history** → [kaizen_log.md](kaizen_log.md)
