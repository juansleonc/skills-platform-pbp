---
name: resilience
description: Validates error handling and resilience patterns for external service calls, HTTP requests, payment gateways, and background jobs. Detects fire-and-forget calls, missing timeouts, and silent failures.
allowed-tools: [Bash, Read, Grep, Glob, Edit, mcp__honeybadger__list_faults, mcp__honeybadger__get_fault]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## When to Use This Skill

Run this skill when:
- **Adding/modifying HTTP client calls** (HTTParty, Faraday, Net::HTTP, RestClient)
- **Integrating new external services** (payment gateways, email providers, webhooks)
- **Reviewing adapter code** in `app/adapters/` or API clients in `app/services/`
- **After Honeybadger alerts** about timeout or connection errors
- **Adding new payment gateway** (14 gateways — each must handle failures gracefully)

## Shared References

> **📚 This skill uses shared documentation. See:**
> - [Forbidden Patterns](../shared/forbidden-patterns.md) - bare rescue patterns

# Resilience Audit Skill

Validates that external service calls, HTTP requests, and background jobs handle failures gracefully. Prevents silent failures, cascading timeouts, and data corruption.

## CRITICAL RULES

1. **Every HTTP call MUST have a timeout** — default timeouts are too long (60s+)
2. **Every HTTP call MUST have error handling** — network errors are guaranteed to happen
3. **Never use bare rescue** — always rescue specific exceptions
4. **Never swallow errors silently** — log, notify, or re-raise
5. **Payment operations MUST be idempotent** — retries are inevitable with 14 gateways
6. **Every NEW failure/degraded path must be observable** — a new rescue branch, error early-return, or graceful fallback must emit a diagnosable signal (Honeybadger/Sentry `notify`, a metric, or a structured log with context). Handling a failure ≠ hiding it: if it can't be seen in prod, it can't be debugged.

## Quick Validation Commands

**Run these first for a fast overview:**

```bash
# 1. HTTP calls without rescue blocks - CRITICAL
grep -rn "HTTParty\.\|Faraday\.\|Net::HTTP\.\|RestClient\.\|URI\.open\|open-uri" app/ --include="*.rb" | grep -v "spec\|test"
# Then check each match has a surrounding rescue block
```
**Expected**: Every HTTP call should be inside a begin/rescue block

```bash
# 2. HTTP calls without explicit timeout - HIGH RISK
grep -rn "HTTParty\.\(get\|post\|put\|delete\|patch\)" app/ --include="*.rb" | grep -v "timeout\|Timeout"
grep -rn "Faraday\.new\|Faraday\.\(get\|post\)" app/ --include="*.rb" | grep -v "timeout"
```
**Expected**: 0 NEW occurrences in changed lines. Legacy baseline (2026-06-10): 17 HTTParty matches, 21 Faraday matches — pre-existing, do not introduce more.

```bash
# 3. Silent error swallowing - HIGH RISK
grep -rn "rescue.*nil$\|rescue.*; end\|rescue.*=> e$" app/ --include="*.rb" -A1 | grep -v "log\|raise\|notify\|Honeybadger\|ErrorService"
```
**Expected**: 0 NEW occurrences in changed lines. Legacy baseline (2026-06-10): ~1060 pipeline-output lines (multi-file, noisy grep) — do not introduce new silent rescues.

```bash
# 4. Bare rescue / rescue Exception - MEDIUM RISK
grep -rn "rescue\s*$" app/ --include="*.rb"
grep -rn "rescue Exception" app/ --include="*.rb" | grep -v "# rubocop"
```
**Expected**: 0 NEW occurrences in changed lines. Legacy baseline (2026-06-10): 19 bare-rescue matches, 0 `rescue Exception` matches.

```bash
# 5. .save without bang or return value check - MEDIUM RISK
grep -rn "\.save$\|\.save " app/services/ app/jobs/ --include="*.rb" | grep -v "save!\|\.save(" | grep -v "#\|if\|unless\|&&\|\|\|"
```
**Expected**: Minimal matches. Use `.save!` or check return value: `if record.save`

```bash
# 6. Fire-and-forget external calls in sync context - HIGH RISK
grep -rn "HTTParty\.\|Faraday\.\|RestClient\." app/controllers/ app/models/ --include="*.rb" | grep -v "rescue\|begin\|async\|job\|worker"
```
**Expected**: External calls in controllers/models should be in background jobs or have rescue blocks

```bash
# 7. New failure/degraded paths without an observable signal - HIGH RISK
# Scan diff for new rescue blocks, error early-returns, and fallback branches
git diff develop -- '*.rb' | grep -E "^\+" | grep -E "rescue |rescue$|\|\| return|\|\| next|return (false|nil) (if|unless)" | grep -v "^+++"
# For each match, confirm a diagnosable signal is present nearby (Honeybadger.notify / Sentry / Rails.logger.error / metric increment)
git diff develop -- '*.rb' | grep -E "^\+" | grep -E "Honeybadger\.notify|Sentry\.capture|Rails\.logger\.(error|warn)|ErrorService"
```
**Expected**: Every new rescue branch or graceful-degradation path in the diff has a corresponding notify/log line. Silent graceful-degradation (handled but unlogged) is invisible failure — it degrades the system without leaving any trace to debug from prod.

## Detailed Patterns

> **📖 Worked code patterns (HTTP timeout+rescue, payment-gateway resilience, .save return-value, background-job retry) → [reference/patterns.md](reference/patterns.md).**

## PBP-Specific: External Services to Audit

| Service | Location | Risk Level |
|---------|----------|------------|
| 14 Payment Gateways | `app/services/payment_service/` | CRITICAL |
| Patch API (contacts) | `app/adapters/patch_adapter/` | HIGH |
| Playsight cameras | `packs/camera_integrations/` | MEDIUM |
| Webhook deliveries | `packs/webhooks/` | HIGH |
| Email delivery | `app/mailers/` | MEDIUM |
| SMS consent/opt-in | `app/services/sms_consent_phone_change_invalidator.rb`, `app/graphql/features/sms/` | MEDIUM |
| OpenSearch indexing | `app/models/concerns/*_searchable.rb` (e.g. `user_searchable.rb`, `facility_searchable.rb`) | MEDIUM |

```bash
# Audit all adapters for resilience
grep -rn "HTTParty\.\|Faraday\.\|Net::HTTP\.\|RestClient\." app/adapters/ app/services/payment_service/ packs/webhooks/ packs/camera_integrations/ --include="*.rb"
# Then verify each has: timeout, rescue, logging
```

## Audit Process

**Step 1 — Find all external calls:**
```bash
grep -rln "HTTParty\|Faraday\|Net::HTTP\|RestClient\|URI\.open" app/ --include="*.rb" | grep -v spec
```

**Step 2 — Validate each file.** For every HTTP call, confirm all 5:
1. **Timeout configured?** (`open_timeout` / `read_timeout` preferred over generic `timeout`)
2. **Rescue block present?** (grep `rescue` in same method)
3. **Specific exceptions rescued?** (no bare `rescue` or `rescue Exception`)
4. **Error logged or notified?** (`Rails.logger`, `Honeybadger`, `ErrorService`)
5. **Return value handled?** (caller checks for failure)

**Step 3 — Check Honeybadger for recurring issues:**
```
mcp__honeybadger__list_faults:
  project_id: <project_id>
  q: "timeout OR connection OR Net::OpenTimeout OR Errno::ECONNREFUSED"
```

**Step 4 — Generate report:**
> **📄 Audit report template → [reference/report-template.md](reference/report-template.md).**

---

## Related Skills

This skill works with:
- **`/security`** - Bare rescue can hide security issues
- **`/performance`** - Missing timeouts cause cascading slowdowns
- **`/sidekiq`** - Job error handling and retry patterns
- **`/gateway-consistency`** - Payment gateway error handling across 14 implementations
- **`/rails-audit`** - Orchestrates resilience as part of full audit

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover a new pattern or heuristic, append it to [`kaizen_log.md`](kaizen_log.md) (sibling file). Promote durable rules into the active SKILL.md body. Log history is in that file — not inline here.
