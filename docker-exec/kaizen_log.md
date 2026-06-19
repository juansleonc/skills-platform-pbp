# docker-exec Kaizen Log

Archived changelog entries. Active skill body is in `SKILL.md`.

---

<!-- Kaizen: 2026-01-24 - bin/d wrapper and expanded Makefile -->
- Added `bin/d` wrapper script for short Docker commands
- Expanded Makefile with 50+ targets
- Updated docker-compose.yml with health checks and profiles
- Added `.env.example` for new developers
- Network auto-created (no longer external)
- Added mailcatcher service (profile: mail)
- Sidekiq now optional (profile: sidekiq or full)

**RETRACTION 2026-06-10 (Fable audit Tier 3):** "50+ targets" was inaccurate. Makefile audit on 2026-06-10 found exactly 11 real targets: build, build-no-cache, containers-up, web-start, web-bash, db-bash, console, migrate, test, assets-precompile, help. The previous Makefile Quick Reference table listed ~15 fictional targets (up, down, status, logs-f, shell, test-parallel, rubocop, pronto, setup, touch, db-shell, redis-cli, lint, ci, coverage). All fictional targets corrected in the "Makefile Quick Reference" section above and throughout the Detailed Reference.

---

<!-- Kaizen: 2026-01-23 - Test Production Scripts Locally -->

Added "Test Production Scripts Before Sending" guidance — always test scripts in Docker with syntax check (`ruby -c`) and simulated data before sending to production. Added checklist (nil safety, strftime, no heredocs).

---

<!-- Kaizen: 2026-06-10 — Makefile audit + When to Use section (Fable audit Tier 3) -->
- Added "## When to Use" section: trigger = any Ruby/Rails command about to run on host (CLAUDE.local.md rule #2). `bin/d` is canonical; Makefile is secondary.
- Rewrote "Makefile Quick Reference": now lists only the 11 verified real targets (confirmed via `grep -E '^[a-zA-Z_-]+:' Makefile` + full Makefile read). Deleted ~15 fictional targets (up, down, status, logs-f, shell, test-parallel, rubocop, pronto, setup, touch, db-shell, redis-cli, lint, ci, coverage, routes, restart, brakeman, logs-web, logs-sidekiq).
- Fixed Detailed Reference sections (Testing, Rails Commands, Interactive Debugging, Database Access, Container Management): replaced fictional `make` invocations with `bin/d` equivalents or inline notes marking each missing target.
- Added dated RETRACTION note under Kaizen 2026-01-24 entry ("Expanded Makefile with 50+ targets" — actual count is 11).

---

<!-- Kaizen: 2026-06-15 — correctness fixes (optimize-skill Wave 3) -->
- Fixed stale "if supported" hedge on `bin/d restart`: bin/d line 300 confirms the `restart)` branch exists. Updated Container Management to definitive: `bin/d restart` (restarts web container via docker compose restart).
- Added `bin/d up` and `bin/d down` to Quick Reference table and Container Management section. Both branches verified in bin/d (lines 324, 330). The skill previously steered users to verbose `docker compose down`/`up` while omitting the bin/d shortcuts, contradicting the "bin/d is canonical" framing.
- **RETRACTION (Fix 3 — pronto canonical form):** The "Standardized Pronto invocation" change in this entry was INCORRECT. It promoted `bin/d pronto -r rubocop -c develop -f text` as "canonical native form (preferred)" and demoted `bin/d bundle exec pronto run -r rubocop -c develop -f text` to a commented-out equivalent. This CONTRADICTS CLAUDE.local.md §3, which is the authoritative source and designates the `bin/d bundle exec pronto run -r rubocop -c develop -f text` form as PRIMARY. While `bin/d pronto ...` is a valid passthrough shorthand (bin/d lines 221-228), it must NOT be promoted above the CLAUDE.local.md §3 form. Corrected in the 2026-06-15 Correction entry below.

<!-- Kaizen: 2026-06-15 — CORRECTION of Fix 3 contradiction with CLAUDE.local.md §3 -->
- Reverted the incorrect pronto promotion from the Wave 3 entry above.
- SKILL.md Code Quality section now shows `bin/d bundle exec pronto run -r rubocop -c develop -f text` as the PRIMARY/canonical command (labelled "authoritative per CLAUDE.local.md §3").
- `bin/d pronto -r rubocop -c develop -f text` is mentioned only as a "shorthand alias" in a comment line below the primary.
- Quick Reference table row updated: removed bare `bin/d pronto` entry, now shows the full canonical form with a note about the shorthand.
- Root cause: previous worker reasoned from bin/d internals ("native form") without checking CLAUDE.local.md §3, which is the explicit override authority. CLAUDE.local.md always wins over implementation convenience on naming conventions.

---

<!-- Kaizen: 2026-06-14 — skills-audit fixes (Wave 2) -->
- Replaced abbreviated `bin/d pronto` with canonical form `bin/d bundle exec pronto run -r rubocop -c develop -f text` in Code Quality section (cross-cutting finding #3).
- Replaced self-edit-via-Edit instruction with "run /kaizen after task" (cross-cutting finding #1).
- Archived Kaizen log entries to this sibling file; active body now shows pointer only.
