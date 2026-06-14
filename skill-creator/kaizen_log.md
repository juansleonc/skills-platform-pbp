# skill-creator Kaizen Log

Archived from SKILL.md Meta-Kaizen section (2026-06-14). Verbatim copy.

---

<!-- Kaizen: 2026-01-31 - Initial Creation -->
Created skill-creator to:
- Detect skill gaps from session patterns
- Semi-automatically propose new skills
- Maintain single responsibility (separate from /kaizen)
- Execute at end of session via /orchestrate
- Prevent skill bloat through quality gates
- Track actual ROI after creation

Next improvements needed:
- Add cross-session pattern aggregation
- Implement weekly skill opportunity reports
- Create skill template validator
- Add automatic orchestrator integration detection

<!-- Kaizen: 2026-06-09 — CSO description-lint rule (adapted from obra/superpowers, MIT) -->
Added the "Frontmatter Lint: description: Must State Triggers Only (CSO Rule)" section.
- Rule: a skill's description: must state ONLY when-to-use, never summarize the workflow/steps.
- Why: a workflow-summary description trains the agent to follow the description and skip the skill body (observed: a "code review between tasks" description caused ONE review where the body required TWO).
- Source: 4-agent blind re-harvest of obra/superpowers (MIT); verdict unchanged (don't adopt wholesale); grafted 3 net-new mechanisms (CSO here; evidence-table + regression-revert ritual into /tdd).

<!-- Kaizen: 2026-06-10 — Casing fix + frontmatter template (Fable re-audit hygiene pass) -->
- Fixed: Phase 5 workflow box changed `.claude/skills/<name>/skill.md` to `SKILL.md`.
- Added: YAML frontmatter block (name, CSO-compliant description, allowed-tools, disable-model-invocation) to the "Skill Template Generation" section so generated skills follow the ecosystem schema from creation.

<!-- Kaizen: 2026-06-10 — Pressure-Test Before Ship (TDD for Skills) -->
Added "Pressure-Test Before Ship" section (RED baseline → GREEN with-skill → pressure variants → acceptance rule).
- Source: obra/superpowers writing-skills + testing-skills-with-subagents.md (MIT, commit 6fd4507).
- Trigger: spike (investigations/superpowers-spike/findings.md, 2026-06-10) found 50/50 local skills never behavior-tested; real defects shipped (fabricated file:line citations in multi-tenancy/SKILL.md; CSO violation in tdd frontmatter). Deferred-until-observed trigger condition fired.
- What was added: Iron Law quote; RED (fresh subagent baseline without skill); GREEN (with skill); 7 pressure types table (verbatim from testing-skills-with-subagents.md); PBP-flavored $10k/min payment-incident pressure scenario; acceptance rule (≥1 RED + ≥1 GREEN + ≥1 pressure-combo documented).
- What was NOT ported: EXTREMELY_IMPORTANT wrappers, persuasion-principles/Cialdini framing, SessionStart hook, superpowers CLI test harness (tests/claude-code/) — these conflict with documented low-friction philosophy (memory: feedback_no_redundant_verification_hooks). The test bench here is Agent-tool subagent dispatch only.
- Canonical protocol lives here; kaizen/SKILL.md cross-references rather than duplicates.

<!-- Kaizen: 2026-06-14 — Skills audit fixes (audit-2026-06-13.md) -->
Three confirmed findings fixed:
1. "Integration with Orchestrator" end_of_session_hook / weekly_skill_report blocks labelled NOT IMPLEMENTED (aspirational only; orchestrate marks skill-creator manual-only).
2. Sweep-lint sentence corrected: adversarial-review description is COMPLIANT (trigger-condition language, not workflow-summary). False claim removed.
3. Meta-Kaizen log archived here (verbatim); SKILL.md replaced with pointer.
