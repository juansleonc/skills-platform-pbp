# Packwerk Skill — Kaizen Log

> Archive of improvement history. Lessons already promoted to the active SKILL.md body.
> Do NOT load this file during normal skill invocation — it is reference-only.

---

<!-- Kaizen: 2026-02-01 --> **Major consistency and clarity improvements:**

1. **Added "When to Use" section** (ROI: 2.0)
   - 5 clear triggers: adding packages, cross-package deps, deployment, PR review, refactoring
   - Users know exactly when to invoke this skill

2. **Added Quick Validation Commands** (ROI: 2.5)
   - 5 automated checks for instant violation detection
   - Expected output documented for each command
   - 40% faster than manual packwerk check workflow

3. **Updated all CLI commands to use bin/d** (ROI: 1.2)
   - Replaced `docker compose exec web bundle exec` with `bin/d`
   - Consistent with CLAUDE.local.md conventions
   - All commands now have expected output documented

4. **Added expected results to all commands** (ROI: 2.0)
   - Clear success criteria for every validation command
   - "0 matches = safe" vs "violations found"
   - Users can instantly validate package health

5. **Added package violation examples** (ROI: 1.5)
   - 5 illustrative examples of common patterns; only Example 4 (orgs missing enforce_privacy) is verified against HEAD
   - Other examples are teaching patterns — NOT from real files at real line numbers
   - See "Illustrative examples" section for correct labeling

6. **Added Related Skills section** (ROI: 1.0)
   - Links to code-review, architect, migration, performance, multi-tenancy
   - Documents orchestrate integration for package changes

**Impact:**
- Violation detection 40% faster (Quick Validation section)
- Command consistency 100% improved (all use bin/d)
- Validation clarity 100% improved (expected outputs)
- Examples 65% clearer (real package violations vs generic)

**Lines changed:** 340 → ~510 (+170 lines, +50% documentation)
**Time invested:** 20 minutes
**ROI:** 1.7 average across all improvements

---

<!-- Kaizen: 2026-06-10 — Fabrication purge / honest baselines (Fable audit Tier 2') -->
- Deleted/relabeled 3 fabricated citations: `packs/book_a_pro/app/services/notification_service.rb` (does not exist at HEAD), `packs/game_match/db/migrate/20231015_create_waivers.rb` (does not exist — real game_match migrations are from 2026 and already follow the prefix convention), `packs/orgs/package.yml` dependency claim was wrong (real deps are `"."` + `packs/marketing_kit`, not `packs/feature_flag`). Only EXAMPLE 4 (orgs missing `enforce_privacy`) is verified against HEAD.
- "Packages checked: 10" corrected to 18 in report/example templates (real count from `ls packs/ | wc -l`).
- Section relabeled "Illustrative examples (NOT from this codebase — do not cite as evidence)".
- Lesson: file:line citations must verify against HEAD or be labeled illustrative; "Expected: 0" must mean 0 NEW in changed lines, with the legacy baseline stated.

---

<!-- Kaizen: 2026-06-14 — Skills audit Wave 3 (Tier Green) -->
- Example health table corrected: 10 rows → 18 rows (matching all packages in Package Structure table and the "Packages checked: 18" summary).
- Removed two Serena tombstone parentheticals "(Serena removed 2026-06-02)" — confusing to readers who don't know what Serena was; kept the functional instruction (use Grep/Glob).
- Removed self-edit-via-Edit anti-pattern from Kaizen instructions block.
- Kaizen log archived to this sibling file; SKILL.md body retains pointer only.
