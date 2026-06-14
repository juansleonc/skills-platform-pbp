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

<!-- Kaizen: 2026-06-14 — skills-audit fixes (Wave 2) -->
- Replaced abbreviated `bin/d pronto` with canonical form `bin/d bundle exec pronto run -r rubocop -c develop -f text` in Code Quality section (cross-cutting finding #3).
- Replaced self-edit-via-Edit instruction with "run /kaizen after task" (cross-cutting finding #1).
- Archived Kaizen log entries to this sibling file; active body now shows pointer only.
