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
