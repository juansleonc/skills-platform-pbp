# action-policy — Kaizen Log

> Archived from SKILL.md to reduce per-invocation context load. Lessons promoted into active body.

## 2026-06-10 — Add When to Use trigger (QA audit Tier 1 fix)

- Added "When to Use" section with auto-trigger criteria from CLAUDE.local.md Skill Router.
- Integration score was 2/5; this surfaces the skill in the correct contexts.
- Source: QA audit 2026-06-10.

## 2026-06-10 — Rewrite against the real Action Policy implementation (Fable audit Tier 1')

- The skill described a fictional architecture (AuthorizedController, ApplicationPolicy in app/policies/, Authorization::PermissionMatrix/ScopeResolver/RoleResolver) — zero hits repo-wide. Agents following it grepped empty directories.
- Rewrote Architecture + validation commands against the real slices: Orgs::BasePolicy (packs/orgs/app/policies/), Internal::BasePolicy (packs/internal_backend/app/policies/internal/), ActionPolicy::Controller wiring in packs/orgs + packs/internal_backend.
- Quarantined the unimplemented design under "Proposed target architecture (NOT implemented)".
- Merged the duplicate When to Use sections.
- Lesson: architecture sections must be regenerated from the repo, not from an aspirational design doc.

## 2026-06-14 — Token efficiency pass (Skills Audit Wave 3 / Tier Low)

- Replaced two full base-policy class listings (~100 lines, Orgs::BasePolicy + Internal::BasePolicy) with annotated snippets showing only non-obvious parts (pre_check declarations, default_rule, permitted? helper) + grep pointer to live classes (~40 lines saved).
- Fixed stale controller count: `~93 API controllers` → `~110` (verified: `find app/controllers/api/v1 -name '*.rb' | wc -l` = 110).
- Collapsed "Proposed target architecture (NOT implemented)" 15-line section to a 2-line note (~13 lines saved).
- Archived this Kaizen section to sibling kaizen_log.md (~12 lines saved from hot path).
- Net: 587 → ~522 lines (−65 lines, −11%).

## 2026-06-15 — Clear <500 hard ceiling via progressive disclosure (/optimize-skill)

- Body was 514 lines — 14 over the repo's HARD <500 ceiling (the only hard violation; all content verified accurate).
- Relocated the two largest verbatim blocks to a new bundled `reference/examples.md` (one level deep, TOC since >100 lines), each replaced by a one-line resolving pointer:
  - Architecture ASCII inheritance tree (~37 lines) → densified to a 6-row capability table in body + full tree in examples.md §1.
  - §8 Testing Patterns full code (~70 lines) → 4 bullet key-rules in body + full scaffolds in examples.md §2.
- Net: 514 → 424 lines (−90, −17.5%); 76 lines of margin under the ceiling. Zero capability removed — OPTIMIZE ≠ DELETE.
- Deferred (HEADLESS, user-decision): (1) stale Skill Router glob `*authorized_controller*` at `.claude/skills/CLAUDE.local.md` L161 → should become the two real `base_controller.rb` paths so /action-policy auto-fires (edits user config, not skill); (2) optional alignment of the `org_permission_resolver` ternary to the live if/else form (cosmetic, semantically equivalent).
- Left Anti-Pattern Detection Commands + Quick Validation Workflow both intact: ceiling already cleared with margin, and the two serve distinct purposes (granular 7-grep checklist vs. single runnable spec-executing block) — removing either would lose capability.
