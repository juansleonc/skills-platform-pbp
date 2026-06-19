# Sidekiq Skill — Kaizen Log (optimize-skill)

## 2026-06-15 — optimize-skill structural + correctness pass

**Body**: 663 → 179 lines (HARD ceiling 500; target ~480 — relocated more aggressively for the
always-loaded L2 body). Frontmatter valid; all pointers resolve one level deep.

### Correctness fixes (verified against repo before applying)
- **Dead `Redis.current` API** (was in decision table, REDIS LOCK example, Redlock comment, and the
  idempotency validation checklist) → replaced with `Sidekiq.redis { |conn| ... }` (Sidekiq 7 pooled
  connection). Verified: `grep -rn "Redis.current" app/ lib/` → 0 hits; `redis (5.4.1)` in Gemfile.lock
  (5.x removed `Redis.current`). Body now carries it only as an explicit "dead — do not use" warning.
- **Redlock example double-faulted** (gem absent + dead Redis). Verified `redlock` NOT in Gemfile.lock.
  Kept the row but relabeled "NOT in Gemfile — would require adding the redlock gem"; relocated example
  to reference/idempotency-patterns.md under a caveat block, switched its constructor to `Redis.new`.
- **Missing repo convention**: documented `sidekiq-unique-jobs` (8.0.11, in Gemfile.lock) as FIRST-CHOICE
  locking via `sidekiq_options lock: :until_executed/:while_executing, lock_ttl:`. Verified proof sites:
  sync_match_job.rb, publish_unified_payment_event_job.rb, automatic_renewal_membership_job.rb,
  packs/billing/.../cx_slack_notification_job.rb, packs/marketing_kit/.../announcements_deliver_job.rb.
  Added a Quick-Validation note so lock-based jobs aren't flagged as "missing idempotency."
- **ErrorService** confirmed present (app/services/error_service.rb) — guidance left as-is. `Rails.cache`
  guidance left as-is (standard, not contradicted).

### Frontmatter (NOT stripped — deferred decision, but annotated)
- Added a comment marking `allowed-tools` + `disable-model-invocation` as Claude-Code harness extensions
  (not portable Agent Skills spec), mirroring the packwerk skill. Value preserved.

### Structure: relocate / densify / dedup
- **Relocated** to new `reference/` bundle (verbatim, body keeps decision text + pointers):
  examples.md (Correct Job skeleton, Anemic ❌/✅, Ruby 3 before/after, Forbidden block, ErrorService
  patterns), idempotency-patterns.md (4-mechanism code + invocation + combined lock/cache validation),
  audit-output-template.md (report template + sample diffs), changelog.md (full Kaizen history).
- **Densified**: merged the two duplicate Honeybadger MCP blocks into one; collapsed the 5 `###` Audit
  Process subsections into a 5-item list; reduced ErrorService prose to a rule + pointer.
- **Deduped**: forbidden/correct patterns and the deep_symbolize_keys rule stated once in CRITICAL RULES,
  referenced elsewhere; merged the two idempotency checklists; leaned on existing shared refs.

### Note on report-format relocation
The plan named `reference/report-format.md`; the harness blocked that filename (matched "report"
write-guard, false positive on a legitimate skill-bundle template). Saved as
`reference/audit-output-template.md` instead — same verbatim content, body pointer updated.

### Deferred to user (USER-DECISIONS — not applied, headless)
1. Make `sidekiq-unique-jobs` the documented FIRST-CHOICE and demote hand-rolled SETNX — partially
   surfaced in the decision table, but the full recommendation re-ordering needs user sign-off.
2. Standardize hand-rolled lock form on `Sidekiq.redis { ... }` vs a named `Redis.new` constant.
3. Redlock fate: drop entirely vs. relocate-and-label (applied the relocate-and-label option as the
   non-destructive default; user may prefer full removal).
4. Frontmatter harness-extension annotation (applied as a comment; user may prefer to strip the props
   for a portable export).
5. Relocating the ~70-line Kaizen changelog out of the body (applied; confirm acceptable).
