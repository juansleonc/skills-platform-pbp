# code-smells Kaizen Log

> Archived from SKILL.md. Active skill body is in SKILL.md. Add new entries here; promote to skill body if the lesson changes the detection logic or thresholds.

---

<!-- Kaizen: 2026-06-10 — Add When to Use trigger (QA audit Tier 1 fix) -->
- Added "When to Use" section with auto-trigger criteria (>200 lines, high churn, pre-refactor).
- Integration score was 2/5; this surfaces the skill before refactors begin.
- Source: QA audit 2026-06-10.

<!-- Kaizen: 2026-06-14 — Fix bare ruby -e → bin/d ruby -e (skills audit finding) -->
- Line 203 ran `ruby -e` outside Docker, violating CLAUDE.local.md Rule #2.
- Fixed to `bin/d ruby -e` (same pattern used by factory-check/SKILL.md).
- Source: skills-audit/audit-2026-06-13.md, code-smells finding.

<!-- Kaizen: 2026-06-15 — Fix globstar blind spot in controller checks (Step-0 grounding) -->
- Checks #2 (Fat Controllers) and #7 (Monolithic controllers) used `app/controllers/**/*.rb` but the
  skill never sets `shopt -s globstar`, so `**` collapsed to `*` → only the 56 top-level controllers
  were scanned, missing all 136 nested ones (`admin/`, `api/v1/`, `devise/`, `webhooks/`, ...).
- The largest fat controllers (`api/v1/reservations_controller.rb` 1358 lines, `facilities` 1135,
  `users` 1037) live exactly in those nested dirs — the detector was blind to its top targets.
- Fixed both to `find app/controllers -name '*.rb'` (robust, shell-option-independent): #2 pipes to
  `xargs wc -l`, #7 pipes to a `while read -r f` loop. Verified: 56 → 192 files scanned.
- Source: skills-audit Step-0 deferred-decision #3 (user-confirmed: migrate to find).
