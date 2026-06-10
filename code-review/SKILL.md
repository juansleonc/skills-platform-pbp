---
name: code-review
description: Use when reviewing a diff or branch for correctness, conventions, security, and performance before merge.
allowed-tools: [Bash, Read, Grep, Glob, Task, Edit, mcp__github__*, mcp__context7__resolve-library-id, mcp__context7__query-docs, mcp__clickhouse__run_select_query, mcp__clickhouse__list_tables, mcp__honeybadger__list_faults, mcp__honeybadger__get_fault, mcp__sentry__sentry_list_projects, mcp__sentry__sentry_list_issues, mcp__sentry__sentry_get_issue, mcp__sentry__sentry_get_issue_events, mcp__mermaid__*, mcp__opensearch__*, mcp__ide__executeCode, mcp__ide__getDiagnostics]
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

## MCP TOOLS FOR CODE REVIEW

**Code review works via grep-based analysis by default.** However, MCP tools provide valuable context:

| Priority | Tool Category | When to Use | Required |
|----------|---------------|-------------|----------|
| 🥇 **PRIMARY** | Context7 | Best practices from official docs | Recommended for unfamiliar patterns |
| 🥇 **PRIMARY** | ClickHouse | Verify against production data (10.4M users) | Recommended for data operations |
| 🥇 **PRIMARY** | code-simplifier agent | Code optimization & cleanup | Mandatory for non-trivial changes |
| 🥈 **OPTIONAL** | Honeybadger | Related production errors (Rails) | When debugging production issues |
| 🥈 **OPTIONAL** | Sentry | GraphQL, Mobile, Frontend errors | When debugging production issues |
| 🥈 **OPTIONAL** | Jupyter | Interactive data analysis | Complex queries, visualizations |

## ⚠️ PRODUCTION DATA VERIFICATION (Recommended)

**Consider checking ClickHouse production data when reviewing code that:**
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
# Timezone safety violations
grep -rn "Time\.now\|Date\.today\|DateTime\.now" <changed_files> --include="*.rb"

# Nil safety in string interpolations (edge cases)
grep -rn '&\.\w\+.*".*#{'  <changed_files> --include="*.rb"
# Check: Every .first&. or &. followed by string interpolation needs nil validation
# Example: body = "#{prefix} | #{var}" where var came from &.

# Edge case detection: Unsafe safe navigation
# Pattern: var = something&.method followed by string interpolation
grep -A5 '&\.\w\+' <changed_files> --include="*.rb" | grep -B1 '".*#{.*}' | head -20
# Review: Does interpolation handle nil from &.?

# Edge case detection: .first without nil check
grep -A3 '\.first[^_]' <changed_files> --include="*.rb" | grep -v 'if\|unless\|&\.\|try' | head -20
# Review: Is .first result validated before use?

# Multi-tenancy check - queries without facility_id
grep -rn "\.where\|\.find_by\|\.find\|scope" <changed_files> --include="*.rb" | grep -v "facility"

# Payment transactions check
grep -rn "PaymentService\|PaymentTransaction\|payment" <changed_files> --include="*.rb"
# Verify they're wrapped in: ActiveRecord::Base.transaction do

# API changes for mobile compatibility
git diff develop -- app/graphql/ | grep -E "^[-+].*field\s+:"

# Ticket IDs in comments (FORBIDDEN - use commit prefix instead)
grep -rn "#.*\(CORE-[0-9]\|PLA-[0-9]\|CLS-[0-9]\)" <changed_files> --include="*.rb" | grep -v "regression\|Regression"
# Expected: Empty (ticket numbers belong in commit messages, not code comments)
# Exception: Regression tests can reference original ticket for historical context

# Redundant comments (DISCOURAGED - code/git already documents WHAT)
# Look for comments that just repeat the code/method name without explaining WHY
# Examples to avoid:
#   "# Customer-friendly status fields" above field definitions
#   "# Add new fields" before adding fields
#   "# Update display status" before updating status
# Use comments only for non-obvious things: WHY, not WHAT
```

### Step 2.5: Method Refactoring Pattern Detection (MANDATORY - Two-Part Check)

**When git diff shows a method being moved/renamed, must verify TWO things:**
1. All callers updated to new signature
2. New method handles nil safely

---

#### Part 1: Verify All Callers Updated

```bash
# 1. Detect method refactoring (method removed from one class, added to another)
git diff develop | grep -E "^-.*def (method_name)"

# 2. Find ALL usages of old method signature
grep -rn "old_class\.method_name" app/ spec/ packs/

# Example from CORE-205:
# Method moved from MembershipPlanPrice to Membership
grep -rn "membership_plan_price\.in_pre_sale_period\?" app/ spec/
# Expected: Zero matches (all updated) OR only in historical files (migrations, changelogs)

# 3. Verify EACH usage was updated to new signature
# If grep finds matches → MUST verify each file updated to new signature
```

**Common refactoring patterns:**
- Model method moved: `membership_plan_price.method` → `membership.method`
- Service renamed: `OldService.calculate` → `NewService.calculate`
- Module relocated: `OldModule.method` → `NewModule.method`
- Helper moved: `old_helper_method` → `new_helper_method`

---

#### Part 2: Validate New Method Nil Safety (CRITICAL - Added after CORE-205)

```bash
# Extract new method body and check for nil crash patterns
git diff develop <file> | grep -A20 "^+.*def method_name"

# Check for direct attribute access without nil guards:
# Look for: object.attribute or object.method() where object might be nil

# Example from CORE-205:
git diff develop app/models/membership.rb | grep -A15 "^+.*def in_pre_sale_period"
# Found: facility.current_time (CRASH if facility is nil!)
# Found: facility.current_time_zone (CRASH if facility is nil!)
# Question: Is 'facility' guaranteed non-nil?
# Fix: Add "return false if facility.blank?" BEFORE any facility.* calls
```

**Nil Safety Checklist for New/Refactored Methods:**

| Pattern | Example | Risk | Fix |
|---------|---------|------|-----|
| Direct dereference | `facility.current_time` | NoMethodError if nil | `return X if facility.blank?` |
| Chained calls | `user.profile.avatar` | Crashes on any nil | `user&.profile&.avatar` |
| String interpolation | `"#{user.name}"` | Empty if nil, crash if further call | Validate before interpolation |
| Array access | `items.first.price` | Crashes if nil | `items.first&.price` |
| Method expecting objects | `date.strftime('%Y')` | NoMethodError | Guard: `date ? date.strftime(...) : nil` |

**Validation Questions for Each Variable:**

For every variable used in new method, ask:
1. Can this be nil? (Check model associations, optional fields)
2. If yes, is there a nil guard BEFORE dereferencing?
3. Should check production data with ClickHouse (Step 8)

---

**Example Failure from CORE-205:**

```ruby
# ❌ BUGGY (what we committed - Part 1 passed, Part 2 failed):
def in_pre_sale_period?
  facility = membership_plan.owner_facility  # Can be nil!
  facility.current_time.to_date  # ← Crashes if facility is nil
  facility.current_time_zone     # ← Crashes if facility is nil
end

# ✅ FIXED (after bugbot caught it):
def in_pre_sale_period?
  facility = membership_plan.owner_facility
  return false if facility.blank?  # ← Added nil guard
  facility.current_time.to_date
end
```

**When to use:**
- ✅ ALWAYS when method removal + addition with same name in different classes
- ✅ ALWAYS when adding new methods that dereference variables
- ✅ ALWAYS when refactoring methods that call attributes/methods on objects
- ❌ Skip for purely internal private methods (only one caller)

**Production Validation (Step 8 integration):**

```sql
-- For CORE-205, should have checked:
SELECT countIf(owner_facility_id IS NULL) as null_count
FROM pbp_productionDB_optimized.membership_plans
-- If > 0, method MUST handle nil
```

### Step 2.7: Structural Quality Check

**Detect structural code smells in changed files:**

> **📖 See [Structural Thresholds](../shared/structural-thresholds.md) for warning/critical limits.**
>
> Use `Grep` and `Glob` for symbol-level discovery. (Serena removed 2026-06-02.)

```bash
# 1. Fat model detection (>200 lines = warning, >400 = critical)
git diff develop --name-only -- app/models/ | while read f; do
  lines=$(wc -l < "$f" 2>/dev/null)
  if [ "$lines" -gt 400 ]; then
    echo "🔴 CRITICAL: $f has $lines lines (>400)"
  elif [ "$lines" -gt 200 ]; then
    echo "🟡 WARNING: $f has $lines lines (>200)"
  fi
done

# 2. Fat controller detection (>150 lines = warning, >300 = critical)
git diff develop --name-only -- app/controllers/ | while read f; do
  lines=$(wc -l < "$f" 2>/dev/null)
  if [ "$lines" -gt 300 ]; then
    echo "🔴 CRITICAL: $f has $lines lines (>300)"
  elif [ "$lines" -gt 150 ]; then
    echo "🟡 WARNING: $f has $lines lines (>150)"
  fi
done

# 3. Long method detection (>15 lines in changed files)
git diff develop --name-only -- '*.rb' | while read f; do
  awk '/def [a-z]/{start=NR; name=$0} /^[[:space:]]*end$/{if(NR-start>15) print "🟡 " FILENAME ":" start " method too long (" NR-start " lines): " name}' "$f" 2>/dev/null
done

# 4. Callback overload (>5 callbacks per model)
git diff develop --name-only -- app/models/ | while read f; do
  count=$(grep -c "before_\|after_\|around_" "$f" 2>/dev/null)
  if [ "$count" -gt 5 ]; then
    echo "🟡 WARNING: $f has $count callbacks (>5)"
  fi
done

# 5. Law of Demeter violations (chains >3 levels in changed files)
git diff develop --name-only -- '*.rb' | xargs grep -n '\.\w\+\.\w\+\.\w\+\.\w\+' 2>/dev/null | grep -v "#\|spec/\|test/\|migration"
```

### Step 2.8: Specification Test (Layer Validation)

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

### Step 3: Multi-Tenancy Deep Check

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

### Step 4: API Backward Compatibility

For ANY GraphQL changes:

```ruby
# BAD - Removing field (breaks mobile)
- field :old_field, String

# BAD - Changing field type
- field :count, Integer
+ field :count, String

# BAD - Removing query/mutation
- field :old_query, resolver: OldQueryResolver

# GOOD - Deprecating
field :old_field, String, deprecation_reason: "Use new_field instead"

# GOOD - Adding new field (always safe)
+ field :new_field, String
```

### Step 5: Sidekiq Job Patterns

For ANY job changes:

```ruby
# BAD - Multiple arguments
def perform(user_id, facility_id, options)

# GOOD - Single hash argument (Ruby 3 compatibility)
def perform(args)
  args = args.deep_symbolize_keys
  return unless args.is_a?(Hash)
  # Initialize variables BEFORE try blocks
  user = nil
  begin
    user = User.find(args[:user_id])
  rescue => e
    # user is accessible here for logging
  end
end

# Payment jobs MUST be idempotent
def perform(args)
  args = args.deep_symbolize_keys
  idempotency_key = args[:idempotency_key]
  return if already_processed?(idempotency_key)
  # ... process
end
```

### Step 5.5: Cross-Job Consistency Validation

**When reviewing multiple similar jobs** (e.g., 3 new reminder jobs), check for PATTERN CONSISTENCY:

```bash
# Find all job files being changed
changed_jobs=$(git diff develop --name-only | grep "app/jobs/.*_job\.rb")

# For each pattern, verify consistency:
echo "$changed_jobs" | while read job; do
  echo "=== $job ==="

  # 1. Error handling pattern
  grep -n "rescue StandardError" "$job" || echo "⚠️ Missing rescue block"

  # 2. Throttling pattern
  grep -n "sidekiq_throttle" "$job" || echo "ℹ️ No throttling"

  # 3. Error notification pattern
  grep -n "JobsNotificationMailer\|ErrorService" "$job" || echo "⚠️ Missing error notification"
done
```

**Consistency Rules**:
- If 2+ jobs have `rescue StandardError`, ALL similar jobs should have it
- If 2+ jobs have throttling, validate throttle keys are consistent
- If 2+ jobs send notifications, validate notification methods match

**Red Flag**: One job in a group has error handling, others don't = INCONSISTENCY BUG

**Example from CORE-81**:
```ruby
# ✅ ClinicLessonReminderJob has:
rescue StandardError => e
  JobsNotificationMailer.new_error(...)
  ErrorService.new(e, ...).notify
end

# ✅ MembershipExpirationReminderJob has:
rescue StandardError => e
  JobsNotificationMailer.new_error(...)
  ErrorService.new(e, ...).notify
end

# ❌ MembershipReminderJob MISSING rescue block
# → This is a consistency bug! All 3 jobs should have same error handling.
```

### Step 6: GraphQL Patterns

```ruby
# CHECK for deferred queries usage (performance)
field :heavy_data, resolver: HeavyResolver do
  extension GraphQL::Pro::Defer  # Should use this for heavy operations
end

# CHECK for custom auth in GraphqlController
# Authentication should be in controller, not resolvers

# CHECK for proper error handling
rescue_from ActiveRecord::RecordNotFound do |err|
  raise GraphQL::ExecutionError, "Not found"
end
```

### Step 7: Context7 Best Practices Lookup (Optional - Manual)

**When encountering unfamiliar patterns, manually query Context7:**

```
# 1. Resolve library ID first
mcp__context7__resolve-library-id:
  libraryName: "rails"
  query: "performance best practices ActiveRecord queries"

# 2. Query specific patterns
mcp__context7__query-docs:
  libraryId: "/rails/rails"
  query: "N+1 prevention includes preload eager_load"
```

**Required Context7 queries by code type:**

| Code Type | Query |
|-----------|-------|
| ActiveRecord | `"ActiveRecord performance includes vs joins vs preload"` |
| Sidekiq | `"Sidekiq best practices job design patterns"` |
| GraphQL | `"graphql-ruby performance deferred execution"` |
| RSpec | `"RSpec best practices fast tests factory patterns"` |
| Redis | `"Redis Rails caching patterns memory optimization"` |
| Payments | `"Stripe idempotency keys payment processing"` |

**Performance-specific queries:**
```
mcp__context7__query-docs:
  libraryId: "/rails/rails"
  query: "database query optimization avoiding N+1 bullet gem"

mcp__context7__query-docs:
  libraryId: "/rspec/rspec"
  query: "fast test suite factory build vs create"
```

### Step 8: ClickHouse Production Data Verification (MANDATORY for Data Operations)

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

When needed, manually query ClickHouse to verify code changes against production data:

```sql
-- Database: pbp_productionDB_optimized

-- 1. Table structure verification
SELECT column_name, data_type, is_nullable
FROM system.columns
WHERE database = 'pbp_productionDB_optimized'
AND table = '<table_name>'

-- 2. Data volume (affects query performance)
SELECT count(*) as row_count
FROM pbp_productionDB_optimized.<table>

-- 3. NULL patterns (critical for .try, &., safe navigation)
SELECT
  '<field>' as field,
  count(*) as total,
  countIf(<field> IS NULL) as nulls,
  round(countIf(<field> IS NULL) / count(*) * 100, 2) as pct
FROM pbp_productionDB_optimized.<table>

-- 4. Field cardinality (affects index usefulness)
SELECT uniqExact(<field>) as unique_values
FROM pbp_productionDB_optimized.<table>

-- 5. Query that code will generate (estimate performance)
EXPLAIN
SELECT <fields>
FROM pbp_productionDB_optimized.<table>
WHERE <conditions>
```

**Performance red flags to check:**

| Pattern | ClickHouse Query | Action |
|---------|------------------|--------|
| Iterating all records | `SELECT count(*) FROM table` | If > 10k, need pagination |
| Filtering by non-indexed field | Check cardinality | Add index or change approach |
| NULL handling | Check NULL percentage | Add explicit NULL checks |
| N+1 in loops | Check related table size | Use includes/preload |

```sql
-- Example: Check if membership query will be slow
SELECT
  count(*) as total_memberships,
  countIf(status = 'active') as active,
  countIf(expires_at < now()) as expired
FROM pbp_productionDB_optimized.memberships

-- If > 100k, the code needs pagination or background job
```

### Step 9: Production Error Context (Honeybadger + Sentry)

Check for related production errors in both systems:

**Honeybadger:**
```
mcp__honeybadger__list_faults: Search for faults related to changed files
mcp__honeybadger__get_fault: Get details if relevant errors exist
```

**Sentry (for GraphQL, Mobile, Frontend):**
```
mcp__sentry__sentry_list_issues:
  org_slug: "sentry"
  project_slug: "graphql_pro"  # or "platform", "pbp-mobile", etc.
  query: "is:unresolved <search_term>"

mcp__sentry__sentry_get_issue:
  issue_id: "<issue_id>"
```

**When to check which:**
| Changed Code | Check |
|--------------|-------|
| GraphQL mutations/queries | `sentry/graphql_pro` |
| Mobile-facing APIs | `sentry/pbp-mobile` |
| Frontend/JS | `sentry/platform-frontend-0j` |
| Sidekiq jobs | `sentry/sidekiq-platform` |
| General Rails | Honeybadger + `sentry/platform` |

### Step 10: Code Simplifier Agent (MANDATORY)

**ALWAYS run code-simplifier for any non-trivial changes:**

```
Task tool:
  subagent_type: "code-simplifier"
  prompt: |
    Review these files for performance and clarity:
    <list of changed files>

    Focus on:
    1. PERFORMANCE:
       - Unnecessary database queries
       - N+1 patterns
       - Inefficient loops
       - Memory bloat (large object creation in loops)

    2. SIMPLIFICATION:
       - Redundant code that can be extracted
       - Complex conditionals that can be simplified
       - Long methods that should be split
       - Unclear naming

    3. RAILS PATTERNS:
       - Use of scopes vs class methods
       - Proper use of callbacks
       - Service object patterns

    4. TEST EFFICIENCY:
       - build vs create usage
       - Unnecessary setup
       - Slow test patterns
```

**When to skip code-simplifier:**
- Single-line typo fixes
- Comment-only changes
- Configuration file changes

### Step 11: Run Automated Checks (Docker)

**Linting Rules:**
- **Modified files** → Pronto (only changed lines, preserves legacy)
- **New files** → RuboCop -A (full lint OK for new code)

```bash
# Pronto - for modified files
docker compose exec web bundle exec pronto run -c develop

# RuboCop - ONLY for new files
docker compose exec web bundle exec rubocop -A path/to/new_file.rb

# Brakeman for security
docker compose exec web bundle exec brakeman --only-files <files>
```

## Review Dimensions

### 1. Critical Rules (BLOCKING)
- [ ] No `Time.now` usage (use `Time.current`)
- [ ] Multi-tenancy: All queries scoped by `facility_id`
- [ ] Payment operations use database transactions
- [ ] No breaking API changes for mobile
- [ ] Payment jobs are idempotent
- [ ] No AI/Claude mentions in code or commits

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

```markdown
## Code Review: <branch-name>

### Critical Rules Check
| Rule | Status | Notes |
|------|--------|-------|
| Timezone Safety | OK / FAIL | |
| Multi-tenancy | OK / FAIL | |
| Financial Transactions | OK / FAIL / N/A | |
| API Compatibility | OK / FAIL | |
| Payment Idempotency | OK / FAIL / N/A | |

### Context7 References
- Rails: <relevant documentation patterns>
- RSpec: <relevant testing patterns>

### ClickHouse Production Verification
- Data patterns: <findings from pbp_productionDB_optimized>
- Edge cases: <potential NULL/empty handling issues>
- Query performance: <optimization suggestions>

### Production Error Context (Honeybadger + Sentry)
- Honeybadger faults: <any related faults>
- Sentry issues: <any related issues in graphql_pro, platform, etc.>

### Architecture
- OK / WARN / FAIL Finding with explanation

### Security
- OK / WARN / FAIL Finding with explanation

### Performance
- OK / WARN / FAIL Finding with explanation

### Code Simplification (via code-simplifier)
- <simplification opportunities>

### Recommendations
1. <actionable recommendation>
2. <actionable recommendation>
```

## Project-Specific Checklists

### Payment Code
- [ ] Uses `ActiveRecord::Base.transaction`
- [ ] Idempotent operations with idempotency key
- [ ] Sandbox credentials only in tests
- [ ] No hardcoded API keys
- [ ] Uses `PaymentService::Base` for gateway routing
- [ ] Checks `merchants` table for facility settings

### GraphQL
- [ ] Uses deferred queries for heavy operations
- [ ] Custom auth in GraphqlController (not resolvers)
- [ ] Backward compatible changes only
- [ ] Proper error handling with GraphQL::ExecutionError

### Sidekiq Jobs
- [ ] Single hash argument: `def perform(args)`
- [ ] `args.deep_symbolize_keys` at start
- [ ] Variables initialized before try blocks
- [ ] Idempotent for payment operations
- [ ] Proper error handling for Honeybadger

### Models
- [ ] Scoped by `facility_id` where needed
- [ ] Uses `Time.current` not `Time.now`
- [ ] Proper associations and validations
- [ ] Admin override for cross-facility access documented

### Webhooks
- [ ] Uses `attr_encrypted` for credentials
- [ ] Excludes encrypted fields from JSON by default
- [ ] `include_decrypted: true` only when explicitly needed
- [ ] Event builders in `app/services/webhook_event_builders/`

### Tests
- [ ] No `allow_any_instance_of`
- [ ] No hardcoded IDs
- [ ] Uses appropriate factory method
- [ ] Time-dependent tests use `Timecop.freeze(Time.current)`
- [ ] Redis cleared for rate limiting tests
- [ ] 100% coverage on changes

---

## MCP Integrations

### GitHub MCP

Use for PR-based code review:

```
# Get PR details and diff
mcp__github__get_pull_request:
  owner: "playbypoint"
  repo: "platform"
  pull_number: 123

# Get PR files changed
mcp__github__list_pull_request_files:
  owner: "playbypoint"
  repo: "platform"
  pull_number: 123

# Add review comment
mcp__github__create_review_comment:
  owner: "playbypoint"
  repo: "platform"
  pull_number: 123
  body: "Consider using `includes` here to avoid N+1"
  path: "app/models/user.rb"
  line: 45

# Submit review
mcp__github__create_review:
  owner: "playbypoint"
  repo: "platform"
  pull_number: 123
  event: "COMMENT"  # or "APPROVE" or "REQUEST_CHANGES"
  body: "## Code Review Summary\n..."
```

### Mermaid MCP

Use for visualizing code structure:

```
# Generate dependency diagram
mcp__mermaid__render:
  diagram: |
    graph TD
    A[Controller] --> B[Service]
    B --> C[Model]
    B --> D[Gateway]
```

### OpenSearch MCP

Use for checking search-related code:

```
# Verify index mappings
mcp__opensearch__get_mapping:
  index: "users"

# Check search query performance
mcp__opensearch__search:
  index: "users"
  explain: true
  query: { ... }
```

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new code pattern to check
- A missing review criterion
- A better Context7/ClickHouse query

**You MUST**:
1. Complete the current code review first
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements**:
<!-- Kaizen: 2026-01-23 -->
- Added: No ticket IDs in code comments rule (use commit message prefix instead)

<!-- Kaizen: 2026-01-24 - Jupyter Notebook Integration -->
## 📓 Jupyter Notebook for Code Review (Optional)

Use JupyterLab for **interactive production data verification** when you need to:
- Run complex verification queries iteratively
- Compare data patterns before/after code changes
- Document findings with visualizations
- Share analysis with the team

### Launch Jupyter for Code Review

```bash
~/jupyter-env/bin/jupyter lab
```

### Example Code Review Notebook

```python
# Cell 1: Setup
%load_ext sql
%sql clickhouse://default:@localhost:8123/pbp_productionDB_optimized

# Cell 2: Verify NULL handling in changed code
%%sql
SELECT
  count(*) as total,
  countIf(expires_at IS NULL) as null_expires,
  round(countIf(expires_at IS NULL) / count(*) * 100, 2) as null_pct
FROM memberships

# Cell 3: Check edge cases the code must handle
%%sql
SELECT
  status,
  count(*) as cnt,
  round(count(*) * 100.0 / sum(count(*)) OVER (), 2) as pct
FROM memberships
GROUP BY status
ORDER BY cnt DESC

# Cell 4: Verify multi-tenancy patterns
%%sql
SELECT
  facility_id,
  count(*) as records
FROM reservations
WHERE facility_id IS NULL  -- Should be 0!
```

### When to Use Jupyter vs MCP Tools

| Scenario | Recommended Tool |
|----------|------------------|
| Quick NULL check | `mcp__clickhouse__run_select_query` |
| Complex data analysis | Jupyter |
| Iterative query refinement | Jupyter |
| Documenting verification | Jupyter |
| Single verification query | MCP tool |

### MCP IDE Tools Available

- `mcp__ide__executeCode`: Execute Python in active Jupyter kernel
- `mcp__ide__getDiagnostics`: Get language diagnostics

<!-- Kaizen: 2026-01-31 - MCP Tools Integration -->
## Kaizen Entry: MCP Tools Reference in Code Review

**What Changed:**
- Added reference to shared MCP tools guide in Shared References section
- Updated MCP tools table to show priority levels (🥇 PRIMARY vs 🥈 OPTIONAL)
- Emphasized Context7, ClickHouse, and code-simplifier as PRIMARY tools
- Made code-simplifier MANDATORY for non-trivial changes (was just "Optional")

**Why:**
- Previous version didn't differentiate between primary and optional MCP tools
- Code reviews benefit most from Context7 (best practices) and ClickHouse (production data)
- Consistent with other skills (debug, architect, performance)
- code-simplifier agent should be standard for all non-trivial reviews

**Impact:**
- Clearer guidance on when to use which MCP tool
- Production data verification becomes standard practice
- Better code quality through systematic simplification
- Consistent patterns across all code review workflows
- ROI: 2.5 (High impact, Medium effort)

<!-- Kaizen: 2026-01-22 -->
- Added: MANDATORY INTEGRATIONS table at top for visibility
- Added: "PRODUCTION DATA VERIFICATION (MANDATORY)" section with ClickHouse queries
- Enhanced: Step 7 Context7 with required queries by code type
- Enhanced: Step 8 ClickHouse with performance red flags table
- Enhanced: Step 10 code-simplifier with detailed prompt template
- Emphasis: Production data checks are MANDATORY before approving any data-related code

<!-- Kaizen: 2026-02-03 - PR #4046 Lessons Learned -->
**What Happened:**
- Code review missed 2/5 bugs found by cursor[bot] in PR #4046
- Issue #4 (Low): Teacher notification body incomplete when lesson has no attendances
- Issue #5 (Med): MembershipReminderJob missing error handling that other 2 jobs have

**Root Causes:**
1. **Edge Case Detection Gap**: No automated check for `.first&.` followed by string interpolation
2. **Cross-Job Consistency Gap**: No validation that similar jobs have consistent error handling patterns
3. **NULL Checks Not Mandatory**: Step 8 ClickHouse checks were "Recommended" not "MANDATORY"

**Improvements Applied:**
1. ✅ Added nil-safety grep patterns in Step 2 (detects `.first&.` + interpolation)
2. ✅ Added Step 5.5: Cross-Job Consistency Validation (compares error handling across similar jobs)
3. ✅ Made Step 8 ClickHouse checks MANDATORY for data operations
4. ✅ Added automated grep for unsafe safe navigation patterns

**Impact:**
- These 4 changes would have caught BOTH missed bugs automatically
- Edge case detection: grep pattern detects nil risk in string interpolations
- Consistency validation: cross-job comparison detects missing error handling
- ROI: 2.5 (High impact - prevents production bugs, Low-Med effort - automated checks)

**Lessons for Future Reviews:**
- When reviewing multiple similar files (e.g., 3 new jobs), ALWAYS check for pattern consistency
- ALWAYS grep for `.first`, `.last`, `&.` and validate nil handling in string interpolations
- Make production data validation MANDATORY, not optional

<!-- Kaizen: 2026-02-11 - PR #4109 Method Refactoring Lesson (CORE-205) -->
**What Happened:**
- Refactored `in_pre_sale_period?` method from MembershipPlanPrice to Membership model
- Updated most callers (views, GraphQL) but MISSED one: `membership_receipt_subject` in mailer
- Bugbot caught the inconsistency AFTER commit b9a5e90cf4, requiring follow-up commit a3959ae39b
- User frustrated: "debe buscar todos estas cosas que pueden estar afectadas, estamos haciendo cambios enviando al PR y quedando mal, quedamos mal los dos" (we keep looking bad)

**Root Cause:**
- **No automated check for method refactoring completeness** - when a method is moved/renamed from one class to another, we didn't grep for ALL usages of the old method signature
- Assumed visual inspection would catch all callers - it didn't

**The Pattern:**
Method refactoring requires checking TWO locations:
1. **Old location**: `membership_plan_price.in_pre_sale_period?` (removed from MembershipPlanPrice)
2. **New location**: `membership.in_pre_sale_period?` (added to Membership)
3. **ALL callers**: Must be updated from old → new signature

**Solution: Add Step 2.5 - Method Refactoring Detection**

Insert new step between Step 2 and Step 3:

```bash
### Step 2.5: Method Refactoring Pattern Detection (MANDATORY)

# When git diff shows a method being moved/renamed between classes, MUST verify ALL callers updated

# 1. Detect method refactoring (method removed from one class, added to another)
git diff develop | grep -E "^-.*def (in_pre_sale_period\?|method_name)"

# If method was removed from a class:
# 2. Find ALL usages of old method signature
grep -rn "membership_plan_price\.in_pre_sale_period\?" app/ spec/ packs/
# Or generically: grep -rn "old_class\.method_name" app/ spec/ packs/

# 3. Verify EACH usage was updated to new signature
# Expected: Zero matches (all updated) or only in migration/changelog files

# Common method refactoring patterns that NEED this check:
# - Model method moved to another model: membership_plan_price.method → membership.method
# - Service method renamed: old_calculate → calculate
# - Module method relocated: OldModule.method → NewModule.method
# - Helper method moved to different helper: old_helper_method → new_helper_method
```

**Example from CORE-205:**
```bash
# Step 1: Detect refactoring in diff
git diff develop app/models/membership.rb app/models/membership_plan_price.rb
# Shows: + def in_pre_sale_period? (in Membership)
#        - def in_pre_sale_period? (in MembershipPlanPrice - removed via delegation)

# Step 2: Search for old usage pattern
grep -rn "membership_plan_price\.in_pre_sale_period\?" app/ spec/
# Found: app/mailers/membership_mailer.rb:332
# Found: spec/models/membership_spec.rb:15 (old test, can ignore)

# Step 3: Verify file was updated
# Result: mailer was NOT updated → BUG DETECTED → would have prevented commit issue
```

**Files Updated in CORE-205:**
- ✅ app/views/membership_mailer/_membership_details.html.erb:39
- ✅ app/views/membership_mailer/_pre_sale_callout.html.erb:1
- ✅ app/graphql/features/membership/membership_type.rb:93
- ❌ app/mailers/membership_mailer.rb:332 ← MISSED (caught by bugbot)

**Grep patterns for common refactorings:**
```bash
# Model method moved
grep -rn "old_model\.method_name" app/ spec/ packs/

# Service renamed
grep -rn "OldService\.\|OldService\.new" app/ spec/ packs/

# Constant renamed
grep -rn "OLD_CONSTANT" app/ spec/ packs/

# Module method moved
grep -rn "OldModule::method" app/ spec/ packs/
```

**When to use this check:**
- ✅ ALWAYS when git diff shows method removal + addition with same name in different classes
- ✅ ALWAYS when renaming methods that are called from multiple files
- ✅ ALWAYS when moving helper methods between modules
- ❌ Skip for purely internal private methods (only one caller)

**Impact:**
- Would have caught the mailer bug before commit (saved embarrassment and rework)
- Prevents bugbot comments after PR submission
- Ensures complete refactoring in one commit
- ROI: 3.0 (High impact - prevents embarrassment, Low effort - one grep command)

**Integration into existing workflow:**
Add this check to Step 2 (Critical Rules Check) as a MANDATORY grep pattern when method refactoring is detected in the diff.

<!-- Kaizen: 2026-02-19 - External API Behavior Assumptions (CORE-189) -->
**RULE: When reviewing integration/adapter code, verify ACTUAL external API behavior — do not assume**

- **What happened in CORE-189**:
  - Bug A: `Patch::Contacts.all` accepts an `email:` filter parameter in code, but the API silently ignores it and returns all contacts. The filter appeared correct but had zero effect.
  - Bug B: `Patch::Products.find` was expected to raise an exception on 404, but the API returns an error hash (`{ "success" => false, "error" => "..." }`). Code that rescued exceptions missed this entirely.
- **Root cause**: Integration code was written based on assumed/guessed API contracts. The actual SDK/API behavior was never verified with a real call.
- **New checklist item** — when reviewing adapter/API client code, add to "Things to verify":
  - [ ] Filters/params: Does the API actually honor them, or does it silently ignore them?
  - [ ] Error handling: Does the API raise exceptions or return error hashes for 4xx/5xx responses?
  - [ ] Return shape: Does the response match what the code destructures? (array vs hash, key names)
  - [ ] Pagination: If listing resources, does the code handle multi-page responses?
- **How to verify**: Make a real API call in a dev/staging environment. Use `tmp/test_issue.rb` or `investigations/CORE-[id]/` scratch scripts. Do not rely on SDK docs alone — test it.
- **Location**: Add to Step 2 "Critical Rules Check" for any file under `app/adapters/`, `app/services/*_client*`, or external API wrappers.
- **ROI**: 3.0 (External API surprises are high-severity bugs; one real call prevents them)

<!-- Kaizen: 2026-02-11 - PR #4109 Nil Safety in Refactored Methods (CORE-205 Part 2) -->
**What Happened (IMMEDIATELY AFTER previous Kaizen):**
- Fixed method refactoring detection issue (Step 2.5 added)
- But SAME PR #4109, SAME method, bugbot STILL caught another issue
- The refactored `in_pre_sale_period?` method calls `facility.current_time` without nil guard
- Would crash with NoMethodError if `owner_facility` is nil (legacy memberships exist)
- Again caught by bugbot AFTER commit, not during code review

**Root Cause:**
- **Step 2.5 only checks caller updates, NOT new code safety** - we validated all callers were updated, but didn't validate the NEW method itself for nil safety
- When refactoring a method, must check BOTH:
  1. ✅ All callers updated (Step 2.5 added)
  2. ❌ New method handles nil safely (MISSING - this failure)

**The Double-Failure Pattern:**
When refactoring methods, TWO types of bugs can occur:
1. **Caller inconsistency** (Step 2.5 catches) - old callers not updated
2. **New method nil safety** (NOT caught) - new method dereferences without guards

**Solution: Enhance Step 2.5 with Nil Safety Check**

Add to Step 2.5 after caller verification:

```bash
### Step 2.5: Method Refactoring Pattern Detection (ENHANCED)

# PART 1: Verify all callers updated (existing)
grep -rn "old_class\.method_name" app/ spec/ packs/

# PART 2: Validate NEW method for nil safety (NEW - added after CORE-205)
# When a method is refactored/added, check for nil dereferencing

# Extract the new method body from diff
git diff develop app/models/membership.rb | grep -A20 "^+.*def in_pre_sale_period"

# Check for common nil crash patterns in NEW code:
# 1. Direct attribute access without guard
grep -A20 "^+.*def method_name" <file> | grep -E "^\+.*\w+\.\w+" | grep -v "&\.\|\.try\|\.presence\|if.*\.blank\?"

# Example from CORE-205:
# Found: facility.current_time (line 391)
# Found: facility.current_time_zone (lines 399, 400)
# Question: Is 'facility' guaranteed non-nil?
# Answer: NO - membership_plan.owner_facility can be nil (legacy memberships)
# Fix needed: return false if facility.blank?

# 2. Specific nil guards needed in CORE-205 fix:
git diff develop app/models/membership.rb | grep -A15 "^+.*def in_pre_sale_period" | grep "facility\."
# Shows: facility.current_time, facility.current_time_zone
# Must verify: Is there a nil guard for 'facility' BEFORE these calls?
```

**Nil Safety Checklist for Refactored Methods:**

When reviewing a refactored/new method, check for these crash patterns:

| Pattern | Example | Fix |
|---------|---------|-----|
| Direct attribute dereference | `facility.current_time` | Add `return false if facility.blank?` |
| Chained calls | `user.profile.avatar` | Use `user&.profile&.avatar` or guard |
| String interpolation | `"Name: #{user.name}"` | Use `user&.name` or validate first |
| Array access | `items.first.price` | Use `items.first&.price` or validate |
| Method calls expecting objects | `date.strftime('%Y')` | Guard with `date ? date.strftime(...) : nil` |

**Example from CORE-205 (the actual bug):**

```ruby
# ❌ BUGGY (what we committed):
def in_pre_sale_period?
  facility = membership_plan.owner_facility
  facility.current_time.to_date  # ← Crashes if facility is nil!
end

# ✅ FIXED (after bugbot comment):
def in_pre_sale_period?
  facility = membership_plan.owner_facility
  return false if facility.blank?  # ← Added guard
  facility.current_time.to_date
end
```

**Production Data Validation (Should have been done):**

```sql
-- Query we SHOULD have run before committing:
SELECT count(*) as total,
       countIf(owner_facility_id IS NULL) as null_facilities,
       round(countIf(owner_facility_id IS NULL) / count(*) * 100, 2) as pct
FROM pbp_productionDB_optimized.membership_plans

-- If any NULL facilities exist → method MUST handle nil
```

**Test Coverage (what we added):**

```ruby
context 'when owner_facility is nil (legacy memberships)' do
  let(:membership) { build(:membership, membership_plan_price: plan_price) }
  let(:plan_without_facility) { create(:membership_plan, owner_facility: nil) }

  it 'returns false (gracefully handles nil facility)' do
    expect(membership.in_pre_sale_period?).to be false
  end
end
```

**Impact:**
- Would have prevented NoMethodError crashes in production
- Would have caught bug during code review instead of in CI
- Saves embarrassment from multiple bugbot comments on same PR
- ROI: 3.0 (High impact - prevents production crashes, Low effort - automated grep + manual validation)

**Lesson:**
Method refactoring requires THREE checks:
1. ✅ Step 2.5 Part 1: All callers updated
2. ✅ Step 2.5 Part 2: New method nil-safe (NOW ADDED)
3. ✅ Step 8: Production data validation for nil patterns (already exists, should have been used)

**Integration:**
Merge this into Step 2.5 as a two-part check: (1) Caller consistency, (2) New method nil safety.

<!-- Kaizen: 2026-05-12 - User correction -->
## Kaizen Entry: Validate HTTP-Facing Bugs via Real Request, Not Runner Stubs
- Rule: When this skill flags a bug in HTTP-facing code (GraphQL resolvers, controllers, middlewares, endpoint-triggered jobs), the validation step MUST reproduce via real request (Postman/curl) or integration spec (`graphql_post`) BEFORE any `rails runner` script that monkey-patches internals.
- Why: Stubs that replace `Service.new` and call private methods on `allocate`d types bypass graphql-ruby's resolver execution order, middleware stack, auth, and per-request shared context — which is where many real bugs live. The reviewer evaluating the finding has to trust the stubbed scenario actually mirrors production; real HTTP reproduction removes that doubt.
- How to apply: In the bug-confirmation step, prefer `graphql_post(query, token, params)` in `spec/graphql/queries/...` (see existing examples). Use a runner only for purely internal services with no HTTP entry, or as a fast-iteration aid during fix development AFTER the real-request repro is on file.
- Source: User correction on 2026-05-12 during ENG-544 adversarial review. See `memory/feedback_validate_bugs_via_real_request.md`.

<!-- Kaizen: 2026-05-12 - User correction (scope + repro discipline) -->
## Kaizen Entry: Findings Must Be In-Scope AND Have Real Repro
- Rule: Every code-review finding MUST satisfy two conditions: (1) introduced by `git diff develop...HEAD` (not pre-existing in develop), and (2) demonstrable with a real repro (Rails console, Postman/curl, or integration spec) WITHOUT arbitrary code instrumentation. If either condition fails, demote to a NOTES section labeled `pre-existing` or `theoretical` — never mix into the main verdict.
- Why: Pre-existing/theoretical findings dilute real ones and force the author to verify things outside their scope. The review's signal is exactly what THIS branch breaks.
- How to apply: First step of the review is `git diff develop...HEAD` to map the actual change surface. For each candidate finding, run the two-question filter: "introduced by this diff?" + "real repro without runtime instrumentation?". Each accepted finding gets a "Repro" subsection with concrete commands. Data manipulation (e.g. `facility.update_columns(time_zone: nil)`) is acceptable; runtime code modification is not.
- Source: User correction on 2026-05-12 during ENG-544 adversarial review. See `memory/feedback_review_scope_and_real_repro.md`.

<!-- Kaizen: 2026-05-12 - User correction (refinement: prod-state verification) -->
## Kaizen Entry: Data Manipulation Counts Only If The State Exists In Prod
- Refinement to the scope+repro rule: `update_columns` / `destroy_all` / fixture-style data manipulation only counts as a real repro when the fabricated state EXISTS in production. Verify BEFORE fabricating with `mcp__clickhouse__run_query` or Honeybadger fault search. If 0 rows / 0 faults match, the state is impossible in prod and the data manipulation = injection.
- Aliased-query findings (multi-alias of same GraphQL field with different args) only count if a known client emits aliased queries on that field — verify via `grep -rn "<field>:" <client-repo>`. Hand-crafted aliases by the reviewer don't count.
- Final filter: "Real user, real data, real client flow?" If no → NOTES at most, never the verdict.
- Why: My ENG-544 review surfaced 3 findings that all collapsed under this filter — all were theoretical scenarios I had constructed.
- Source: User correction on 2026-05-12 during ENG-544 adversarial review. See `memory/feedback_review_scope_and_real_repro.md` (updated 2026-05-12).

<!-- Kaizen: 2026-05-22 - User correction -->
- Rule: Flag any change that makes a destructive step (DELETE/cleanup) a default/enforced behavior without checking the ticket's approval scope. Approval of X (e.g. links) ≠ approval to delete other tables.
- Why: In CORE-624 I nearly enforced faves/user_stats deletion in the engine; the user caught that Erick had scoped those tables out — the exact scope creep (L3) the TRIAGE-10 lessons doc flags.
- How to apply: When reviewing a diff that adds/enables a destructive op, confirm the ticket approved THAT op on THOSE tables (read "Out of scope / Pendiente / cleanup separado"). Integrity consequences of an approved action (touch/reindex) are fine; new destructive ops on other tables are a finding unless separately approved.
- Source: User correction on 2026-05-22. See `memory/feedback_respect_approved_scope.md`.

<!-- Kaizen: 2026-05-25 - User correction -->
- Rule: Flag any new file added under `docs/` (or other committed paths) that is actually personal/local content. Personal files belong in gitignored locations, never the team docs tree.
- Why: A `CLAUDE.local.md` optimization added personal reference docs to `docs/development/` (committed). User: "si son local no deben estar donde es la doc de todo el equipo".
- How to apply: In review, for every newly-added file ask "team-shared or personal?". If it's linked from `CLAUDE.local.md` / is workflow/ticket notes, it must be gitignored (`git check-ignore` should match). `docs/` = team/committed; `investigations/` + `.claude/` = personal/excluded.
- Source: User correction on 2026-05-25. See `memory/feedback_personal_files_excluded_location.md`.

<!-- Kaizen: 2026-06-05 - User correction -->
- Rule: A NEGATIVE docs/API-research result ("option/field/method does not exist") is LOW-CONFIDENCE. Verify against the authoritative structural source (Context7 dataclass/signature dump, or the reference/config page) before asserting absence; treat an independent auditor's contradiction of a negative as high-signal.
- Why: A research agent over-trusts the first page it reads; a negative is unfalsifiable from one search. `max_budget_usd` was declared "does not exist" after searching the wrong SDK pages, but the Context7 `ClaudeAgentOptions` dataclass dump showed it exists (caught by Codex audit + targeted Context7 query).
- How to apply: For any high-stakes "X doesn't exist", run a targeted Context7 query for the exact type/dataclass/signature before stating it; prefer a second independent check for negatives that drive a decision.
- Source: User correction on 2026-06-05. See `memory/feedback_negative_research_result_low_confidence.md`.

<!-- Kaizen: 2026-06-05 - User correction (review-input bias) -->
- Rule: When handing a diff/conclusion to a review agent, give it the RAW evidence (code, diff, original sources), not just your summary of what it contains. Showing the conclusion with an adversarial framing does not bias; passing only your summary creates shared-premise bias (reviewer inherits your reading). High-value calls → blind independent pass, then reconcile.
- Why: obra/superpowers spike — 3 review lenses fed the summary not the raw reports; they could only contest the thesis, not the reading.
- How to apply: fact-checker → explicit claims; reasoning reviewer → conclusion + attack framing + raw inputs; critical decision → blind pass tie-breaker.
- Source: User correction on 2026-06-05. See `memory/feedback_review_raw_evidence_not_summary.md`.
