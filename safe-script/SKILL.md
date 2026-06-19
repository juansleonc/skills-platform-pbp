---
name: safe-script
description: Generates safe, idempotent runner scripts for manual database fixes and data migrations, with dry-run/rollback and SQL-injection checks. Use when writing a one-off Rails runner script to fix, backfill, migrate, or clean up production data outside a formal migration — manual data fixes, orphan cleanup, bulk value corrections.
allowed-tools: [Bash, Read, Write, Edit, Grep, Glob]
disable-model-invocation: false
---

# Safe Script Generator Skill

Creates production-safe runner scripts for manual data fixes with automatic
dry-run/rollback, idempotency, and SQL-injection safety.

## CRITICAL RULES

The project-wide rules this skill depends on live in single sources of truth — do not
restate them, follow the pointers:

- **SQL-direct over callbacks**, **no heredocs in `rails c`**, **Time.current/strftime
  + nil-safe dates** → CLAUDE.local.md Rules #8, #9, #11, #12 and
  [Critical Rules](../shared/critical-rules.md) / [Forbidden Patterns](../shared/forbidden-patterns.md).
  Note: the heredoc ban is for interactive `rails c` only — **runner script files may
  use `<<~SQL` heredocs** (they are files, not pasted input).

Skill-specific framing (what this skill adds on top of those rules):

1. **Default to dry-run; flip with `LIVE=true`.** Every script runs read-only until
   explicitly told otherwise.
2. **Add rollback logic** to every script (transaction + `raise ActiveRecord::Rollback`
   on dry-run).
3. **Make scripts idempotent** (safe to run multiple times).
4. **Test in Docker before production** (syntax check + dry-run).
5. **Log all changes** for an audit trail.

## When to Use This Skill

Use `/safe-script` to: fix data inconsistencies, backfill missing associations, update
incorrect values in bulk, migrate data between tables, or clean up orphaned records.

**DO NOT use** for:
- Regular schema/data migrations → `rails generate migration` (use `/migration`)
- Recurring/automated work → Sidekiq job (use `/sidekiq`)
- Business logic → a service object

## Bundled References

| Need | File |
|------|------|
| Full script template (+ copyable `scripts/template.rb`) | [references/script-template.md](references/script-template.md) |
| Pattern library (SQL-direct, idempotency, batching, dates, rollback, injection) | [references/patterns.md](references/patterns.md) |
| Two worked real-world scripts | [references/examples.md](references/examples.md) |
| Output run-summary format | [references/run-summary.md](references/run-summary.md) |

Start from `scripts/template.rb` — copy it to `scripts/fix_name.rb` and fill in
`process_records` / `fix_record`.

### Headless confirmation (correctness gate)

The prescribed run path (`bin/d runner ...`, in-pod `rails runner`) is often **non-TTY**.
A naive `$stdin.gets.chomp` live-mode prompt **hangs** (input never arrives) or **crashes**
(`nil.chomp`) under `docker compose exec -T` / piped stdin. The template therefore:
`return true if dry_run` → if NOT a TTY (`unless $stdin.tty?`) require `CONFIRM=yes` → else (TTY) prompt for `yes`.
This keeps the safety gate working headlessly instead of defeating it. Detail in
[references/script-template.md](references/script-template.md).

## Workflow (Docker → Production)

This is the decision flow to walk every time. `bin/d` targets the **local
docker-compose dev stack only** — it never reaches the production cluster. Real
production runs execute **inside the prod pod/runner** (`kubectl exec` / in-pod
`rails runner` in the deployed container), NOT via `bin/d`.

- [ ] **1. Scope it.** What data is wrong? How many records? Correct value? Could a
      real migration do it instead? Any dependencies?
- [ ] **2. Generate** from `scripts/template.rb`; record JIRA, purpose, affected count.
- [ ] **3. Syntax + dry-run in Docker:**
      `bin/d ruby -c scripts/fix_name.rb` then `bin/d runner scripts/fix_name.rb`.
      Output must show affected count, before/after, errors, and "DRY RUN - Rolling back".
- [ ] **4. Verify against test data:**
      `RAILS_ENV=test bin/d runner scripts/fix_name.rb`, then query to confirm the change.
- [ ] **5. Production (in-pod, after review):** dry-run first
      (`rails runner scripts/fix_name.rb`), review output, then live
      (`LIVE=true CONFIRM=yes rails runner scripts/fix_name.rb`). Monitor for errors.
      Never go straight to live — always dry-run in prod first.

## Safety Checklist (gate before production)

- [ ] Tested in Docker (syntax + dry-run)
- [ ] Dry-run output reviewed; affected record count confirmed
- [ ] Rollback logic tested; transaction boundaries correct
- [ ] No SQL-injection risk (see [patterns.md](references/patterns.md) Pattern 6)
- [ ] Idempotent (safe to re-run)
- [ ] Logs all changes; error handling present
- [ ] Code review completed; JIRA linked; backup/rollback plan defined
- [ ] **Scope respected** — a destructive step (DELETE/cleanup) is only a default if the
      ticket approved it. Out-of-scope tables stay opt-in (flag default OFF) pending
      separate sign-off (see kaizen_log.md CORE-624 entry).

## Integration with Other Skills

- `/debug` identifies the data issue → `/safe-script` generates the fix.
- `/orchestrate` can dispatch `/safe-script` after identifying inconsistencies.
- For the output summary you produce after a run, follow
  [references/run-summary.md](references/run-summary.md).

---

## Kaizen: Continuous Improvement

> Historical entries archived to [kaizen_log.md](kaizen_log.md). Append new findings
> there; promote proven rules into the active body above.

**While executing this skill**, if you discover a new safe pattern, a common mistake, or
a better workflow: append to `kaizen_log.md` with format
`<!-- Kaizen: YYYY-MM-DD --> ...`, then run `/kaizen` to promote if warranted.
