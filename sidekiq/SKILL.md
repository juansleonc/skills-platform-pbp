---
name: sidekiq
description: Validates Sidekiq job patterns for Ruby 3 compatibility, idempotency, and error handling. Ensures jobs follow project conventions.
allowed-tools: [Bash, Read, Grep, Glob, Edit]
disable-model-invocation: false
---

<!-- `allowed-tools` + `disable-model-invocation` are Claude-Code harness extensions, NOT part of the
     portable Agent Skills spec (which needs only name + description). Kept because they are valid in
     this harness; a portable export would drop them. -->

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## When to Use This Skill

Run this skill when:
- **Creating new Sidekiq jobs** (validate Ruby 3 pattern compliance)
- **Modifying payment jobs** (verify idempotency requirements)
- **Debugging job failures** in production (check error handling patterns)
- **Before Ruby 3 upgrade** (find jobs with multiple arguments)
- **Code review of background jobs** (validate all patterns)

## Shared References

> **📚 This skill uses shared documentation. See:**
> - [Critical Rules](../shared/critical-rules.md) — payment idempotency
> - [Forbidden Patterns](../shared/forbidden-patterns.md) — patterns to avoid
> - [ast-grep Patterns](../shared/ast-grep-patterns.md) — AST-aware `perform_async` argument-shape matching (idempotency audits)
>
> **📦 Bundled code (relocated to keep this body lean):**
> - [reference/examples.md](reference/examples.md) — Correct Job skeleton · Anemic ❌/✅ · Ruby 3 before/after · Forbidden block · ErrorService patterns
> - [reference/idempotency-patterns.md](reference/idempotency-patterns.md) — full code per locking/idempotency mechanism
> - [reference/audit-output-template.md](reference/audit-output-template.md) — audit report template + sample violation diffs
> - [reference/changelog.md](reference/changelog.md) — Kaizen history

# Sidekiq Job Patterns Skill

Validates Sidekiq jobs follow Ruby 3 compatibility patterns, idempotency requirements, and proper error handling.

## CRITICAL RULES

1. **Single Hash Argument (NEW JOBS)** — New jobs must use one hash argument (`def perform(args)`) for Ruby 3 compatibility. When MODIFYING legacy jobs, follow the existing positional-arg pattern — do not rewrite the signature unless it is a full job rewrite.
2. **Deep Symbolize Keys** — Always call `args.deep_symbolize_keys` first on hash-arg jobs, then `return unless args.is_a?(Hash)`.
3. **Initialize Before Try** — Variables must be initialized before try/rescue blocks (so they are accessible in `rescue`).
4. **Payment Jobs MUST be Idempotent** — Same input always produces same result. Check BEFORE processing, mark AFTER success (in transaction).
5. **Use ErrorService** — Centralized error reporting; never separate `Rails.logger.error` + `Honeybadger.notify`.
6. **Locking** — Prevent concurrent execution of the same job (see Idempotency Patterns below).

> Canonical correct/forbidden code lives once in [reference/examples.md](reference/examples.md); other sections point here rather than restating it. Payment-idempotency and forbidden-pattern context is also in the shared refs above.

## Idempotency Patterns

### Decision Table

| Pattern | Use When | Mechanism | Redis? |
|---------|----------|-----------|--------|
| **`sidekiq-unique-jobs`** (FIRST CHOICE, gem 8.0.11 already in Gemfile.lock) | Any job where duplicate enqueues should collapse to one execution | `sidekiq_options lock: :until_executed` / `:while_executing`, `lock_ttl: <sec>` | Yes (gem-managed) |
| **State-based** | Batch jobs with state-machine transitions (activate/deactivate) | Filter by current state; double-check before mutating | No — DB is source of truth |
| **Cache-based** | External API calls, email, webhooks, third-party integrations | `Rails.cache.exist?` key before acting; write key after success | Yes (via cache store) |
| **Redis lock** (finer-grained than the gem) | Single-record jobs where concurrent execution causes duplicates | `Sidekiq.redis { |c| c.set(key, 1, nx: true, ex: TTL) }` → release in `ensure` | Yes |
| **Redlock** (NOT in Gemfile — would require adding the gem) | Multi-node distributed locks needing quorum guarantees | `Redlock::Client.lock(key, ttl_ms)` | Yes (multiple nodes) |

**First choice in this repo is `sidekiq-unique-jobs`** — declarative, no hand-rolled Redis (proof: `app/jobs/sync_match_job.rb` uses `sidekiq_options lock: :until_executed, lock_ttl: 5.minutes.to_i`; also `publish_unified_payment_event_job.rb`, `automatic_renewal_membership_job.rb`). Hand-rolled SETNX is for when you need finer-grained control. **`Redis.current` is dead in redis-rb 5.x** (this repo runs 5.4.1, uses it nowhere) — use `Sidekiq.redis { |conn| ... }` or a named `Redis.new(...)` constant.

> **Full code per mechanism** (state-based, cache-based, Redis lock, Redlock-with-caveat, invocation, combined lock+cache validation pattern) → [reference/idempotency-patterns.md](reference/idempotency-patterns.md).

## Quick Validation Commands

**Fast Sidekiq job pattern detection** (run these first):

```bash
# 1. Find NEW jobs with multiple arguments - Ruby 3 VIOLATION (CRITICAL)
# Scope to changed files only:
git diff develop --name-only -- app/jobs/ | xargs grep -n "def perform(" 2>/dev/null | grep -v "def perform(args)\|def perform()\|def perform$"
```
**Expected**: **0 new violations in changed/added jobs**. Known legacy baseline (2026-06-10): ~77 of 92 `perform` definitions in `app/jobs/` use positional args — per CLAUDE.md, follow existing patterns when MODIFYING legacy jobs; the hash pattern is required for **NEW jobs only**. Do not report the ~77 legacy jobs as new findings.

```bash
# 2. Find new jobs missing deep_symbolize_keys (HIGH RISK)
git diff develop --name-only -- app/jobs/ | xargs grep -L "deep_symbolize_keys" 2>/dev/null
```
**Expected**: 0 new hash-pattern jobs missing symbolize_keys.

```bash
# 3. Find payment jobs missing idempotency (CRITICAL)
grep -rn "payment\|Payment" app/jobs/ --include="*.rb" | grep -v "idempotency"
```
**Expected**: 0 new payment jobs without idempotency checks (review against `git diff develop` for new/modified only). **If found**: risk of duplicate charges. Note: a job using `sidekiq_options lock:` (sidekiq-unique-jobs) IS idempotency-protected — do not flag it.

> **📖 See [ast-grep Patterns](../shared/ast-grep-patterns.md)** when `sg` is installed: `sg run --lang ruby --pattern '$JOB.perform_async($ARG)' --json=stream` yields structured `JOB`/`ARG` captures, so you can audit the exact argument shape (e.g. `payment.id`) rather than text-matching "payment".

```bash
# 4. Find jobs using separate logger + Honeybadger (DEPRECATED → use ErrorService)
grep -rn "Rails\.logger\.error.*Honeybadger\.notify\|Honeybadger\.notify.*Rails\.logger" app/jobs/ --include="*.rb"
```
**Expected**: 0 matches. **If found**: replace with `ErrorService.new(...).notify`.

## Anemic Job Detection

> Inspired by palkan's "Layered Design for Ruby on Rails Applications"

**Anemic jobs** are jobs whose `perform` is a single-line delegation — they add infrastructure complexity without value.

```bash
# 5. Find potentially anemic jobs (single-line perform methods)
for f in app/jobs/*.rb; do
  body=$(awk '/def perform/,/^[[:space:]]*end/' "$f" 2>/dev/null | grep -v "def perform\|^[[:space:]]*end" | sed '/^[[:space:]]*$/d')
  line_count=$(echo "$body" | wc -l | tr -d ' ')
  if [ "$line_count" -le 1 ] && [ -n "$body" ]; then
    echo "⚠️ Anemic job: $f"
    echo "   Body: $(echo $body | tr -s ' ')"
  fi
done
```

**OK when**: job adds queue routing (`queue_as :critical`), provides needed Sidekiq retry semantics, or serves as the sync→async boundary.
**Smell when**: wraps a model method (`User.find(id).activate!` — just call it), wraps a service with no added value (`MyService.call(args)` — caller can call it), or has no error handling / idempotency / retry config.

> ❌/✅ Anemic-vs-justified code pair → [reference/examples.md](reference/examples.md).

## Audit Process

1. Run Quick Validation Commands (above) for instant detection.
2. Review each violation; apply fixes from [reference/examples.md](reference/examples.md).
3. Verify idempotency for payment jobs (checklist below).
4. Check error handling uses ErrorService (rule: never `logger.error` + `Honeybadger.notify` separately — use `ErrorService.new(e, context: {...}).notify`; patterns in [reference/examples.md](reference/examples.md)).
5. Present results using [reference/audit-output-template.md](reference/audit-output-template.md).

## Honeybadger Integration for Jobs

**Optional**: use Honeybadger MCP when debugging production job errors, filtered by job class:

```
mcp__honeybadger__list_faults: { project_id: <project_id>, q: "JobClassName" }
mcp__honeybadger__get_fault:   { project_id: <project_id>, fault_id: <fault_id> }
```

> **Note**: there is no `sidekiq_errors` (or any `*error*`) table in `pbp_productionDB_optimized` — Sidekiq errors are NOT replicated to ClickHouse (verified 2026-06-10). Use Honeybadger or the Sidekiq retry/dead sets:

```bash
# Inspect retry/dead sets via Rails console in Docker:
bin/d rails runner "puts Sidekiq::RetrySet.new.select { |j| j.klass == 'MyJob' }.count"
bin/d rails runner "puts Sidekiq::DeadSet.new.select { |j| j.klass == 'MyJob' }.first&.error_message"
```

## Idempotency Validation Checklist (Payment Jobs)

Before approving a payment job, verify:

1. **Idempotency key exists**: `args[:idempotency_key]`.
2. **Check BEFORE processing**: `return if already_processed?(key)`.
3. **Mark AFTER success**: inside the transaction, after success.
4. **Key expiration**: 24-48 hours (covers retry window).
5. **Lock acquisition**: prevent concurrent execution — prefer `sidekiq_options lock:` (sidekiq-unique-jobs); for hand-rolled, `Sidekiq.redis { |conn| conn.set(lock_key, 1, nx: true, ex: 300) }` and release in `ensure` (NOT `Redis.current` — dead in redis-rb 5.x).

> Combined lock + cache reference implementation → [reference/idempotency-patterns.md](reference/idempotency-patterns.md).

## Checklist

For each job in changed code:

**Basic** — [ ] `def perform(args)` (new jobs) · [ ] `args.deep_symbolize_keys` first · [ ] returns early unless `args.is_a?(Hash)` · [ ] variables initialized before try/rescue.
**Idempotency (payment jobs)** — [ ] accepts `idempotency_key` (or uses `sidekiq_options lock:`) · [ ] checks BEFORE processing · [ ] marks processed AFTER success (in transaction) · [ ] lock prevents concurrent execution.
**Error handling** — [ ] uses ErrorService (not separate logger + Honeybadger) · [ ] DB transactions for consistency · [ ] re-raises unexpected errors for Sidekiq retry · [ ] includes relevant context.

---

## Related Skills

- **`/timezone`** — job scheduling requires timezone-aware time handling
- **`/pci-compliance`** — payment job validation ensures PCI-DSS compliance
- **`/performance`** — job patterns impact background processing performance
- **`/code-review`** — comprehensive review includes Sidekiq pattern validation

**Workflow**: `/orchestrate feature` automatically includes sidekiq validation in Phase 2.5 (if jobs present).

## Kaizen

While executing this skill, if you discover a new job pattern, a missing validation, or a better idempotency approach: complete the current audit first, then append it to [reference/changelog.md](reference/changelog.md) (format: `<!-- Kaizen: YYYY-MM-DD --> New content`). History lives there to keep this body lean.
