# Code Review Workflow (Full)

> 📋 **Comprehensive code review using 6+ analysis skills + Context7 + ClickHouse**

## Command

```bash
/orchestrate code-review
```

## Overview

Full-spectrum code review workflow:
- Static analysis (6 skills in parallel)
- Domain-specific validation (3 skills in parallel)
- Deep review with Context7 documentation + ClickHouse production data
- Code simplification suggestions

**Time**: 30-40min average
**Risk**: LOW (read-only analysis)
**Critical**: Use before major releases, refactors, or security audits

## Workflow Diagram

```
┌─ PARALLEL (All Analysis - 6 skills) ──────────────┐
│  Run all static analyzers concurrently:           │
│                                                    │
│  ├── timezone: Audit for Time.now                 │
│  │    → Find Time.now, Date.today violations      │
│  │    → Suggest Time.current, Date.current        │
│  │    → Check .to_s(:db) deprecations             │
│  │                                                 │
│  ├── packwerk: Check package boundaries           │
│  │    → Validate cross-package dependencies       │
│  │    → Enforce table naming conventions          │
│  │    → Detect circular dependencies              │
│  │                                                 │
│  ├── security: Brakeman scan                      │
│  │    → OWASP Top 10 vulnerabilities              │
│  │    → SQL injection, XSS, CSRF                  │
│  │    → Mass assignment, command injection        │
│  │                                                 │
│  ├── graphql: API compatibility                   │
│  │    → Backward compatibility check              │
│  │    → Mobile mutations (108 critical)           │
│  │    → Deferred query usage                      │
│  │                                                 │
│  ├── performance: N+1, indexes                    │
│  │    → N+1 query detection                       │
│  │    → Missing includes/preload                  │
│  │    → Index requirements                        │
│  │                                                 │
│  └── multi-tenancy: Facility scoping              │
│       → All queries facility-scoped                │
│       → No cross-facility data leaks               │
│       → Context[:current_facility] usage           │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Domain Checks) ────────────────────────┐
│  Run domain-specific validators if applicable:    │
│                                                    │
│  ├── memberships: If membership code touched      │
│  │    → Business rules (auto-renewal, cancel)     │
│  │    → Payment idempotency                       │
│  │    → Weekly/monthly/annual logic               │
│  │                                                 │
│  ├── migration: If database changes               │
│  │    → Data loss prevention                      │
│  │    → Rollback safety                           │
│  │    → Lock duration estimates                   │
│  │                                                 │
│  └── sidekiq: If job files changed                │
│       → Idempotency patterns                      │
│       → Ruby 3 single-hash argument               │
│       → Error handling                            │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (Deep Review) ────────────────────────┐
│  code-review: Context7 + ClickHouse + simplifier  │
│    → Documentation lookup (best practices)        │
│    → Production data validation                   │
│    → Code simplification suggestions              │
│    → Pattern learning from git history            │
│    → Quality metrics analysis                     │
└───────────────────────────────────────────────────┘
                        ↓
┌─ OUTPUT: Comprehensive Review Report ─────────────┐
│  ## Code Review Report                            │
│                                                    │
│  ### Static Analysis (6 checks)                   │
│  ✅/❌ timezone, packwerk, security, graphql,      │
│       performance, multi-tenancy                  │
│                                                    │
│  ### Domain Validation (if applicable)            │
│  ✅/❌ memberships, migration, sidekiq             │
│                                                    │
│  ### Deep Review Findings                         │
│  - Code quality score: X/100                      │
│  - Complexity issues: Y                           │
│  - Simplification opportunities: Z                │
│  - Best practice violations: W                    │
│                                                    │
│  ### Recommendations                              │
│  [Prioritized list of improvements]              │
└───────────────────────────────────────────────────┘
```

## Why Full Code Review Workflow?

**Before Major Releases**:
- Catch issues before production
- Validate all quality dimensions
- Documentation for audit trail
- Team review preparation

**Comprehensive Coverage**:
- 6 static analyzers (automated checks)
- 3 domain validators (business logic)
- Deep review (patterns, best practices)
- Production data validation

**Time Investment**:
- 30-40min for full review
- Catches 95% of issues before deploy
- Prevents hours of debugging later
- Reduces production incidents

## Phase Details

### Phase 1: All Analysis (Parallel - 6 skills)

All 6 run simultaneously (~8-12min total):

#### 1.1 Timezone Safety

**Skill**: `/timezone`

**What It Checks**:
- `Time.now` → Should be `Time.current`
- `Date.today` → Should be `Date.current`
- `.to_s(:db)` → Use `strftime('%Y-%m-%d')`
- Facility timezone awareness

**Why**: Production operates across multiple timezones. `Time.now` uses server timezone, not user's.

**Time**: 1-2min

---

#### 1.2 Package Boundaries

**Skill**: `/packwerk`

**What It Checks**:
- Cross-package dependencies documented
- Table naming conventions (e.g., `webhooks_urls`)
- No circular dependencies
- Privacy boundaries respected

**Why**: Packwerk enforces modularity. Violations create technical debt.

**Time**: 1-2min

---

#### 1.3 Security Scan

**Skill**: `/security`

**What It Checks**:
- OWASP Top 10 vulnerabilities
- SQL injection risks
- XSS (Cross-Site Scripting)
- CSRF token validation
- Mass assignment vulnerabilities
- Command injection
- Sensitive data exposure

**Why**: Security issues in production = data breaches, compliance violations.

**Time**: 2-3min

---

#### 1.4 GraphQL Compatibility

**Skill**: `/graphql`

**What It Checks**:
- Backward compatibility (108 mobile mutations)
- Breaking changes detection
- Deferred query usage (N+1 prevention)
- Field deprecation (not removal)

**Why**: Mobile apps can't be force-updated. Breaking changes = app crashes.

**Time**: 2-3min

---

#### 1.5 Performance

**Skill**: `/performance`

**What It Checks**:
- N+1 query detection
- Missing `includes`/`preload`
- Index requirements
- Memory issues (large arrays)
- Slow loops

**Why**: Performance issues compound at scale. N+1 with 1000 users = 1000 queries.

**Time**: 2-3min

---

#### 1.6 Multi-Tenancy

**Skill**: `/multi-tenancy`

**What It Checks**:
- All queries scope by `facility_id`
- No cross-facility data leaks
- `context[:current_facility]` usage
- Proper authorization

**Why**: Multi-tenancy violation = facility sees another's data (critical bug).

**Time**: 1-2min

---

**Total Phase 1 Time**: ~8-12min (parallel)

---

### Phase 2: Domain Checks (Parallel - conditional)

Run ONLY if applicable (~5-8min total):

#### 2.1 Memberships

**Skill**: `/memberships`

**When**: If membership-related code changed

**What It Checks**:
- Auto-renewal logic correct
- Cancellation policies followed
- Proration calculations accurate
- Payment idempotency verified

**Time**: 3-4min

---

#### 2.2 Migration

**Skill**: `/migration`

**When**: If database migration added

**What It Checks**:
- Data loss prevention
- Rollback safety (up/down/up cycle)
- Lock duration acceptable
- Index requirements

**Time**: 2-3min

---

#### 2.3 Sidekiq

**Skill**: `/sidekiq`

**When**: If job files changed

**What It Checks**:
- Idempotency patterns
- Ruby 3 single-hash argument
- Error handling
- Retry configuration

**Time**: 2-3min

---

**Total Phase 2 Time**: ~5-8min (parallel, conditional)

---

### Phase 3: Deep Review (Sequential)

**Skill**: `/code-review`

**What It Does**:

#### 3.1 Context7 Documentation Lookup

```bash
# For each library used in changes
mcp__context7__resolve_library_id:
  libraryName: "sidekiq"
  query: "idempotency patterns"

mcp__context7__query_docs:
  libraryId: "/sidekiq/sidekiq"
  query: "How to make jobs idempotent?"

# Returns: Official documentation + code examples
```

**Validates**:
- Following library best practices
- Using recommended patterns
- Avoiding deprecated APIs
- Implementing correctly

**Time**: 3-5min

---

#### 3.2 ClickHouse Production Data Validation

```sql
-- Validate assumptions with production data
SELECT
  COUNT(*) as total,
  COUNT(DISTINCT user_id) as unique_users,
  AVG(processing_time_ms) as avg_time
FROM background_jobs
WHERE job_class = 'MembershipRenewalJob'
  AND created_at > NOW() - INTERVAL 7 DAY;

-- Check if new query pattern exists in production
SELECT query_pattern, COUNT(*) as occurrences
FROM query_logs
WHERE query_pattern LIKE '%new_column%'
LIMIT 10;
```

**Validates**:
- Assumptions match reality
- Performance impact reasonable
- Edge cases exist in production
- Data patterns considered

**Time**: 3-5min

---

#### 3.3 Pattern Learning

```bash
# Analyze git history for patterns
mcp__pattern_learning__predict_bugs:
  files: [changed_files]
  lookback: "6_months"

# Returns:
# - Historical bug patterns
# - High-risk files
# - Common anti-patterns
```

**Identifies**:
- Files with bug history
- Patterns that caused issues before
- Suggested refactorings
- Risk areas

**Time**: 2-3min

---

#### 3.4 Quality Metrics

```bash
# Analyze code complexity
mcp__quality_metrics__analyze_file:
  file_path: "app/services/payment_service.rb"

# Returns:
# - Cyclomatic complexity
# - Cognitive complexity
# - Maintainability index
# - Code smells
```

**Scores**:
- Complexity (1-100, higher = worse)
- Maintainability (1-100, higher = better)
- Overall quality score

**Time**: 2-3min

---

#### 3.5 Code Simplification

```bash
# Get simplification suggestions
# Analyzes:
# - Nested conditionals
# - Long methods
# - Duplicate code
# - Complex expressions
```

**Suggests**:
- Extract method refactorings
- Simplify conditionals
- Reduce nesting
- DRY opportunities

**Time**: 3-5min

---

**Total Phase 3 Time**: ~15-20min

---

## Quality Gate

Before approving code, verify:

```markdown
## Code Review Checklist

### Static Analysis (ALL must pass)
- [ ] ✅ Timezone: No Time.now violations
- [ ] ✅ Packwerk: No boundary violations
- [ ] ✅ Security: No vulnerabilities
- [ ] ✅ GraphQL: No breaking changes
- [ ] ✅ Performance: No N+1 queries
- [ ] ✅ Multi-tenancy: All queries facility-scoped

### Domain Validation (if applicable)
- [ ] ✅ Memberships: Business rules correct
- [ ] ✅ Migration: Rollback safe
- [ ] ✅ Sidekiq: Jobs idempotent

### Deep Review
- [ ] ✅ Quality score: >70/100
- [ ] ✅ Complexity: Acceptable
- [ ] ✅ Best practices: Followed
- [ ] ✅ Production data: Validated

### Overall
- [ ] ✅ All critical issues resolved
- [ ] ✅ Medium issues documented (optional fixes)
- [ ] ✅ Low issues noted (future improvements)
```

**If ANY critical check fails**: STOP, fix issues, re-run review

---

## When to Use

✅ **Use this workflow for**:
- Before major releases (production deploy)
- Large refactorings (>500 lines changed)
- Security-sensitive changes (auth, payments)
- New features (significant functionality)
- Code freeze preparation (stabilization)
- Audit requirements (compliance)

❌ **Don't use for**:
- Small fixes (<50 lines, obvious)
- Documentation-only changes
- Emergency hotfixes (too slow)
- Draft code (use pre-commit instead)

## Success Criteria

**ALL checks must pass** (or issues documented):

**Critical** (must fix):
- ✅ No security vulnerabilities
- ✅ No breaking API changes (mobile apps)
- ✅ No multi-tenancy violations
- ✅ No data loss risks

**High** (should fix):
- ✅ No N+1 queries
- ✅ No timezone violations
- ✅ Package boundaries respected
- ✅ Idempotency verified (jobs/payments)

**Medium** (document if not fixing):
- ⚠️ Code complexity >20
- ⚠️ Maintainability <50
- ⚠️ Best practice deviations

**Low** (optional improvements):
- 💡 Simplification opportunities
- 💡 Refactoring suggestions
- 💡 Performance optimizations

---

## Time Estimates

| Phase | Duration | Notes |
|-------|----------|-------|
| All Analysis (parallel) | 8-12min | 6 skills concurrently |
| Domain Checks (parallel) | 5-8min | Conditional, if applicable |
| Deep Review | 15-20min | Context7 + ClickHouse + metrics |
| **Total** | **30-40min** | Avg 35min |

## Example Review Report

```markdown
## Code Review Report - PR #456

**Date**: 2026-01-27
**PR**: #456 - Add annual membership plans
**Author**: @developer
**Files Changed**: 12 files, +450 lines, -23 lines

---

### Static Analysis (6 checks)

| Check | Status | Issues | Notes |
|-------|--------|--------|-------|
| timezone | ✅ Pass | 0 | Clean |
| packwerk | ✅ Pass | 0 | Clean |
| security | ✅ Pass | 0 | No vulnerabilities |
| graphql | ✅ Pass | 0 | Backward compatible |
| performance | ⚠️ Warning | 1 | N+1 in admin dashboard |
| multi-tenancy | ✅ Pass | 0 | All queries scoped |

**Performance Issue**:
```ruby
# app/controllers/admin/memberships_controller.rb:23
memberships.each do |m|
  m.user.email  # N+1 query
end

# Fix: Add includes
memberships.includes(:user).each do |m|
  m.user.email
end
```

---

### Domain Validation (2 applicable)

| Check | Status | Issues | Notes |
|-------|--------|--------|-------|
| memberships | ✅ Pass | 0 | Business rules correct |
| sidekiq | ✅ Pass | 0 | Jobs idempotent |

**Memberships**:
- ✅ Annual renewal logic: 365 days confirmed
- ✅ Leap year handling: Tested
- ✅ Payment retry: 3 attempts, correct

---

### Deep Review

**Quality Metrics**:
- Complexity: 12 (Good - target <20)
- Maintainability: 78/100 (Good - target >70)
- Overall Score: 85/100 (Excellent)

**Context7 Validation**:
- ✅ Sidekiq idempotency: Follows official pattern
- ✅ ActiveRecord callbacks: Using recommended `after_commit`
- ✅ Time handling: Using `Time.current` correctly

**ClickHouse Validation**:
```sql
SELECT COUNT(*) FROM memberships
WHERE plan_type = 'annual';
-- Result: 0 (new feature)

SELECT AVG(renewal_duration_ms)
FROM membership_renewals
WHERE created_at > NOW() - INTERVAL 7 DAY;
-- Result: 145ms (acceptable, <500ms target)
```

**Simplification Suggestions**:
1. Extract method: `annual_renewal_date` (5 occurrences)
2. Reduce nesting: `MembershipService#process_renewal` (4 levels → 2)

---

### Recommendations

**Must Fix (1 issue)**:
1. ❌ N+1 query in admin dashboard
   - File: `app/controllers/admin/memberships_controller.rb:23`
   - Fix: Add `.includes(:user)`
   - Effort: 1 minute

**Should Fix (0 issues)**:
None

**Nice to Have (2 suggestions)**:
1. 💡 Extract `annual_renewal_date` method (DRY)
2. 💡 Reduce nesting in `process_renewal` (readability)

---

### Summary

**Overall**: ⚠️ APPROVE WITH CHANGES

**Critical Issues**: 0
**High Issues**: 1 (N+1 query - easy fix)
**Medium Issues**: 0
**Low Issues**: 2 (optional improvements)

**Quality Score**: 85/100 (Excellent)

**Next Steps**:
1. Fix N+1 query in admin controller
2. Re-run `/orchestrate pre-commit` to verify
3. Merge after fix confirmed

**Estimated Fix Time**: 2 minutes
```

---

## Common Review Findings

### 1. N+1 Queries (Most Common)

**Pattern**:
```ruby
# ❌ N+1 query
users.each { |u| u.memberships.count }

# ✅ Fixed
users.includes(:memberships).each { |u| u.memberships.count }
```

**Impact**: HIGH (performance)

---

### 2. Timezone Violations

**Pattern**:
```ruby
# ❌ Server timezone
Time.now
Date.today

# ✅ User timezone
Time.current
Date.current
```

**Impact**: MEDIUM (correctness)

---

### 3. Security: Mass Assignment

**Pattern**:
```ruby
# ❌ Vulnerable
User.create(params[:user])

# ✅ Safe
User.create(user_params)

private
def user_params
  params.require(:user).permit(:name, :email)
end
```

**Impact**: CRITICAL (security)

---

### 4. Breaking API Changes

**Pattern**:
```graphql
# ❌ BREAKING - Removes field
type User {
  # email: String  # Mobile app uses this!
  name: String
}

# ✅ SAFE - Deprecates
type User {
  email: String @deprecated(reason: "Use emailAddress")
  emailAddress: String
  name: String
}
```

**Impact**: CRITICAL (mobile apps crash)

---

### 5. Multi-Tenancy Leaks

**Pattern**:
```ruby
# ❌ Global query
Membership.where(user_id: user.id)

# ✅ Facility-scoped
current_facility.memberships.where(user_id: user.id)
```

**Impact**: CRITICAL (data breach)

---

## MCP Tools Used

| Tool | Purpose | Phase |
|------|---------|-------|
| `mcp__rails__execute_tool` | Static analysis automation | Analysis |
| `mcp__context7__query_docs` | Documentation lookup | Deep Review |
| `mcp__clickhouse__run_select_query` | Production data validation | Deep Review |
| `mcp__pattern_learning__predict_bugs` | Historical pattern analysis | Deep Review |
| `mcp__quality_metrics__analyze_file` | Code quality scoring | Deep Review |

## Best Practices

**DO** ✅:
- Run full review before major releases
- Fix critical issues before merging
- Document medium/low issues for future
- Validate with production data (ClickHouse)
- Check library documentation (Context7)
- Review quality metrics trends

**DON'T** ❌:
- Skip review for "urgent" changes (run pre-commit at minimum)
- Ignore medium issues indefinitely
- Deploy with critical violations
- Review without running analyzers first
- Merge without addressing security findings

## Troubleshooting

### Issue: Review takes too long (>40min)

**Solution**:
1. Use `/orchestrate pre-commit` first (faster, delta only)
2. Focus on changed files only
3. Skip optional domain checks if not applicable

### Issue: Too many false positives

**Solution**:
1. Configure analyzers (e.g., Brakeman ignore file)
2. Document known false positives
3. Focus on high/critical issues only

### Issue: Quality score low (<50)

**Solution**:
1. Check code complexity (refactor long methods)
2. Review simplification suggestions
3. May need significant refactoring (separate task)

### Issue: Production data validation fails

**Solution**:
1. Verify ClickHouse connection
2. Check if queries match production schema
3. May need to adjust assumptions

## Related Workflows

- **Before code-review**: `/orchestrate pre-commit` (quick validation)
- **After code-review**: `/orchestrate fix` (address findings)
- **For refactoring**: `/orchestrate refactor` (systematic improvement)

---

**Back to**: [orchestrate skill](../SKILL.md) | [quick reference](../quick_reference.md) | [workflows index](README.md)
