---
name: rails-audit
description: Use when running a full-application health check or pre-release audit across security, performance, code smells, resilience, database, testing, multi-tenancy, gem hygiene, API compatibility, and timezone safety.
allowed-tools: [Bash, Read, Grep, Glob, Edit]
disable-model-invocation: true
---

> **Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## When to Use This Skill

Run this skill when:
- **Before major releases** — comprehensive pre-deployment audit
- **Quarterly health checks** — track codebase health over time
- **After significant feature work** — validate no regressions introduced
- **New team member onboarding** — understand codebase health baseline
- **Tech debt planning** — identify highest-impact improvements

## Usage Variants

```
/rails-audit              # Full audit (all 10 categories)
/rails-audit security     # Security only
/rails-audit performance  # Performance only
/rails-audit code-quality # Code smells + structural quality
/rails-audit resilience   # Error handling + external service resilience
/rails-audit database     # Migrations + indexes + query patterns
/rails-audit testing      # Test quality + factory patterns
/rails-audit gems         # Gem hygiene + vulnerabilities
/rails-audit api          # GraphQL backward compatibility
/rails-audit timezone     # Time.now / Date.today usage
```

# Rails Audit Orchestrator

Comprehensive Rails application audit covering 10 categories, inspired by thoughtbot's rails-audit methodology and adapted for PBP's multi-tenant, multi-gateway architecture.

## Audit Categories

| # | Category | Skill | Focus |
|---|----------|-------|-------|
| 1 | **Security** | `/security` | OWASP, injection, IDOR, credentials |
| 2 | **Performance** | `/performance` | N+1, indexes, memory, Ruby vs SQL |
| 3 | **Code Smells** | `/code-smells` | Fat models/controllers, design patterns |
| 4 | **Resilience** | `/resilience` | Timeouts, error handling, silent failures |
| 5 | **Database** | `/migration` | Migration safety, indexes, schema |
| 6 | **Testing** | `/tdd` + `/factory-check` | Coverage, patterns, factory optimization |
| 7 | **Multi-tenancy** | `/multi-tenancy` | Facility scoping, data isolation |
| 8 | **Gem Hygiene** | `/gem-hygiene` | Vulnerabilities, unused, outdated |
| 9 | **API Compatibility** | `/graphql` | Backward compatibility, mobile safety |
| 10 | **Timezone Safety** | `/timezone` | Time.now / Date.today / DateTime.now |

## Execution Strategy

### Phase 1: Fast Automated Checks (Parallel)

These checks run via grep/bash on the **host working tree** (no Docker needed — they are static file scans). Only Ruby/Rails commands (Phase 2 skill audits and the Pronto lint below) must run via `bin/d`.

```bash
# === 1. SECURITY ===
echo "=== 1. SECURITY ==="

# SQL Injection
echo "SQL Injection:"
grep -rn 'where(".*\#{' app/ --include="*.rb" | wc -l

# Command Injection
echo "Command Injection:"
grep -rn 'system(.*\#{\|exec(.*\#{' app/ --include="*.rb" | wc -l

# IDOR (unscoped find)
echo "IDOR (unscoped find in controllers):"
grep -rn '\.find(params\[' app/controllers/ --include="*.rb" | wc -l

# Hardcoded credentials
echo "Hardcoded credentials:"
grep -rn "api_key\|secret_key" app/ --include="*.rb" | grep -v "ENV\|credentials\|attr_encrypted\|params" | wc -l

# Mass assignment
echo "Mass assignment (permit!):"
grep -rn "permit!" app/controllers/ --include="*.rb" | wc -l

# === 2. PERFORMANCE ===
echo ""
echo "=== 2. PERFORMANCE ==="

# Ruby vs SQL antipatterns
echo "Ruby filtering (.all.select{}):"
grep -rn '\.all\.select\s*{\|\.all\.map\s*{' app/ --include="*.rb" | wc -l

echo ".present? instead of .exists?:"
grep -rn '\.where(.*).present?' app/ --include="*.rb" | wc -l

echo ".length instead of .count:"
grep -rn '\.\w\+s\.length' app/ --include="*.rb" | grep -v "string\|to_s\|to_a\|spec" | wc -l

# === 3. CODE SMELLS ===
echo ""
echo "=== 3. CODE SMELLS ==="

echo "Fat models (>200 lines):"
wc -l app/models/*.rb 2>/dev/null | sort -rn | awk '$1 > 200 {print}' | head -10

echo "Fat controllers (>150 lines):"
find app/controllers -name "*.rb" -exec wc -l {} + 2>/dev/null | sort -rn | awk '$1 > 150 {print}' | head -10

echo "Queries in views:"
grep -rn '\.where\|\.find\|\.find_by' app/views/ --include="*.erb" 2>/dev/null | wc -l

# === 4. RESILIENCE ===
echo ""
echo "=== 4. RESILIENCE ==="

echo "HTTP calls without rescue:"
grep -rln "HTTParty\.\|Faraday\.\|Net::HTTP\." app/ --include="*.rb" | grep -v spec | wc -l

echo "Bare rescue:"
grep -rn 'rescue\s*$' app/ --include="*.rb" | wc -l

echo "rescue Exception:"
grep -rn 'rescue Exception' app/ --include="*.rb" | wc -l

echo "Silent rescue nil:"
grep -rn 'rescue.*nil$' app/ --include="*.rb" | wc -l

# === 5. DATABASE ===
echo ""
echo "=== 5. DATABASE ==="

echo "Model references in migrations:"
grep -rn 'User\.\|Facility\.\|Membership\.' db/migrate/ --include="*.rb" | grep -v "#\|class\|def\|end" | wc -l

# === 6. TESTING ===
echo ""
echo "=== 6. TESTING ==="
# No fast grep phase — invoke /tdd + /factory-check in Phase 2 (Step 6).

# === 7. MULTI-TENANCY ===
echo ""
echo "=== 7. MULTI-TENANCY ==="

echo "Unscoped queries in controllers:"
grep -rn '\.where\|\.find_by\|\.find(' app/controllers/ --include="*.rb" | grep -v "facility\|current_user\|current_facility" | wc -l

# === 8. GEM HYGIENE ===
echo ""
echo "=== 8. GEM HYGIENE ==="
# No fast grep phase — invoke /gem-hygiene in Phase 2 (Step 8).

# === 9. API COMPATIBILITY ===
echo ""
echo "=== 9. API COMPATIBILITY ==="
# No fast grep phase — invoke /graphql in Phase 2 (Step 9).

# === 10. TIMEZONE SAFETY ===
echo ""
echo "=== 10. TIMEZONE SAFETY ==="

echo "Time.now usage:"
grep -rn 'Time\.now\|Date\.today\|DateTime\.now' app/ --include="*.rb" | wc -l
```

### Phase 2: Deep Analysis (Sequential, Per Category)

For each category with findings from Phase 1, run the corresponding skill for detailed analysis:

1. If security findings > 0 → Run `/security` detailed audit
2. If performance findings > 0 → Run `/performance` detailed audit
3. If code smells > thresholds → Run `/code-smells` detailed audit
4. If resilience findings > 0 → Run `/resilience` detailed audit
5. If database findings > 0 → Run `/migration` detailed audit
6. Run `/tdd` + `/factory-check` on recently changed specs
7. If multi-tenancy findings > 0 → Run `/multi-tenancy` detailed audit
8. Run `/gem-hygiene` for dependency health
9. If GraphQL changed → Run `/graphql` compatibility check
10. If timezone findings > 0 → Run `/timezone` detailed audit
11. **If any payment/gateway code is in scope → Run `/pci-compliance`** (do not rely on `/security` alone; `/pci-compliance` covers PCI DSS requirements that `/security` does not check)

### Phase 3: Report Generation

## Report Format

```markdown
## Rails Audit Report

**Date**: YYYY-MM-DD
**Scope**: Full / [Category]
**Branch**: [branch-name]

### Executive Summary

| Category | Status | Issues | Critical |
|----------|--------|--------|----------|
| Security | 🟢/🟡/🔴 | X | Y |
| Performance | 🟢/🟡/🔴 | X | Y |
| Code Smells | 🟢/🟡/🔴 | X | Y |
| Resilience | 🟢/🟡/🔴 | X | Y |
| Database | 🟢/🟡/🔴 | X | Y |
| Testing | 🟢/🟡/🔴 | X | Y |
| Multi-tenancy | 🟢/🟡/🔴 | X | Y |
| Gem Hygiene | 🟢/🟡/🔴 | X | Y |
| API Compat | 🟢/🟡/🔴 | X | Y |
| Timezone Safety | 🟢/🟡/🔴 | X | Y |

**Overall Health**: 🟢 Good / 🟡 Needs Attention / 🔴 Action Required

### Status Legend
- 🟢 **Good**: No critical issues, minor warnings acceptable
- 🟡 **Needs Attention**: Has warnings or non-critical issues
- 🔴 **Action Required**: Has critical issues that must be fixed

### Critical Findings (Must Fix)

| # | Category | Issue | File | Line | Severity |
|---|----------|-------|------|------|----------|
| 1 | Security | SQL injection | file.rb | 45 | CRITICAL |
| 2 | Resilience | No timeout | adapter.rb | 67 | HIGH |

### Warnings (Should Fix)

| # | Category | Issue | File | Impact |
|---|----------|-------|------|--------|
| 1 | Code Smells | Fat model | user.rb | Maintenance |
| 2 | Performance | .present? vs .exists? | service.rb | Query waste |

### Recommendations (Priority Order)

1. **[CRITICAL]** Fix SQL injection in X (security)
2. **[HIGH]** Add timeouts to payment gateway calls (resilience)
3. **[MEDIUM]** Refactor User model — 450 lines (code smells)
4. **[LOW]** Update 3 outdated gems (gem hygiene)

### Trends (vs Previous Audit)

| Metric | Previous | Current | Trend |
|--------|----------|---------|-------|
| Fat models (>200 lines) | 12 | 14 | ⬆️ +2 |
| Missing indexes | 3 | 1 | ⬇️ -2 |
| Time.now usage | 5 | 2 | ⬇️ -3 |
```

## Category-Specific Invocation

When called with a specific category argument:

### `/rails-audit security`
Run only Phase 1 security checks + full `/security` skill audit. If payment code is involved, also run `/pci-compliance`.

### `/rails-audit performance`
Run only Phase 1 performance checks + full `/performance` skill audit.

### `/rails-audit code-quality`
Run only Phase 1 code smells checks + full `/code-smells` skill audit.

### `/rails-audit resilience`
Run only Phase 1 resilience checks + full `/resilience` skill audit.

### `/rails-audit database`
Run only Phase 1 database checks + full `/migration` skill audit.

### `/rails-audit testing`
Run `/factory-check` on recent specs + validate test patterns.

### `/rails-audit gems`
Run full `/gem-hygiene` skill audit.

### `/rails-audit api`
Run full `/graphql` skill audit on GraphQL changes.

### `/rails-audit timezone`
Run only Phase 1 timezone checks + full `/timezone` skill audit.

---

## Linting After Findings

If this audit surfaces code changes, run Pronto before committing (modified files only):

```bash
bin/d bundle exec pronto run -r rubocop -c develop -f text
```

---

## Related Skills

This skill orchestrates:
- **`/security`** — OWASP, Brakeman, injection, IDOR
- **`/pci-compliance`** — PCI DSS requirements for payment code (dispatched separately from `/security`)
- **`/performance`** — N+1, indexes, memory, Ruby vs SQL
- **`/code-smells`** — Structural quality, design patterns
- **`/resilience`** — Error handling, timeouts, external services
- **`/migration`** — Migration safety, schema quality
- **`/tdd`** + **`/factory-check`** — Test quality
- **`/multi-tenancy`** — Facility scoping, data isolation
- **`/gem-hygiene`** — Dependency health
- **`/graphql`** — API compatibility
- **`/timezone`** — Time.now / Date.today / DateTime.now safety

**Integration**: `/orchestrate` can call `/rails-audit` as part of pre-release validation.

---

## Kaizen Log

Archived to [`kaizen_log.md`](kaizen_log.md) in this directory. To record a new improvement, append a row there — do not self-edit this file during an audit run.
