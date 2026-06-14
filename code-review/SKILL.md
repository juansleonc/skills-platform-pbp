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

### Step 3: Method Refactoring Pattern Detection (MANDATORY - Two-Part Check)

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
3. Should check production data with ClickHouse (Step 12)

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

**Production Validation (Step 12 integration):**

```sql
-- For CORE-205, should have checked:
SELECT countIf(owner_facility_id IS NULL) as null_count
FROM pbp_productionDB_optimized.membership_plans
-- If > 0, method MUST handle nil
```

### Step 4: Structural Quality Check

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

### Step 8: Sidekiq Job Patterns

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

### Step 9: Cross-Job Consistency Validation

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

### Step 10: GraphQL Patterns

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

### Step 11: Context7 Best Practices Lookup (Optional - Manual)

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

### Step 13: Production Error Context (Honeybadger + Sentry)

Check for related production errors in both systems:

**Honeybadger:**
```
mcp__honeybadger__list_faults: Search for faults related to changed files
mcp__honeybadger__get_fault: Get details if relevant errors exist
```

**Sentry (for GraphQL, Mobile, Frontend):**
```
mcp__sentry__search_issues:
  org_slug: "sentry"
  project_slug: "graphql_pro"  # or "platform", "pbp-mobile", etc.
  query: "is:unresolved <search_term>"

mcp__sentry__search_issue_events:
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

### Step 14: Code Simplifier Agent (MANDATORY)

**ALWAYS run code-simplifier for any non-trivial changes:**

```
Agent tool:
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
  owner: "PlaybyCourt"
  repo: "platform"
  pull_number: 123

# Get PR files changed
mcp__github__get_pull_request_files:
  owner: "PlaybyCourt"
  repo: "platform"
  pull_number: 123

# Submit review (also covers inline comments via the comments array)
mcp__github__create_pull_request_review:
  owner: "PlaybyCourt"
  repo: "platform"
  pull_number: 123
  event: "COMMENT"  # or "APPROVE" or "REQUEST_CHANGES"
  body: "## Code Review Summary\n..."
```

<!-- mcp__mermaid__* removed — server does not exist in this environment (Fable audit 2026-06-10). Use text-based diagrams instead. -->

### OpenSearch MCP

Use for checking search-related code:

```
# Verify index mappings
mcp__opensearch__IndexMappingTool:
  index: "users"

# Check search query performance
mcp__opensearch__SearchIndexTool:
  index: "users"
  explain: true
  query: { ... }
```

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover a new code pattern to check, a missing review criterion, or a better Context7/ClickHouse query: complete the current review first, then append to this skill using the Edit tool with format `<!-- Kaizen: YYYY-MM-DD --> New content`.

> **Full entry history** → [kaizen_log.md](kaizen_log.md)
