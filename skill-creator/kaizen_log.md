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

<!-- Kaizen: 2026-06-14 — Progressive-disclosure optimization (/optimize-skill, Context7-grounded) -->
Optimized SKILL.md 881 → 201 lines via Anthropic progressive disclosure (L2 body = decision core + ToC; detail relocated VERBATIM to reference/, every pointer one level deep). No capability lost.
- RELOCATED to new reference/ files: scoring-algorithm.md (skill_candidate? Ruby block), pattern-types.md (5 detection types + examples), workflow-phases.md (6-phase ASCII box), templates.md (Proposal + Skill-Template + creation-log + Deferred-Backlog + Detection-Report, with ToC), aspirational-integration.md (orchestrator pseudocode), pressure-testing.md (variant table + PBP example), examples.md (Gate-1 ❌/✅ + NOT-IMPLEMENTED scenarios).
- DENSIFIED in body: Purpose/Philosophy/Core Principles/When-to-Use/Best Practices/Success Criteria.
- DE-DUPLICATED: dropped Config-Priority banner (duplicates CLAUDE.local.md); Metrics section → one-line pointer to existing creation_log.md.
- Decision logic KEPT inline: Core Principles, When-to-Use, scoring thresholds, CSO/description rule (softened), Pressure-Test rule + acceptance, 7 Quality Gates, 9 rejection reasons, Success Criteria.
- Context7-grounded CORRECTNESS fixes (not relocations):
  1. Related-Skills `/orchestrate` row no longer claims "triggers skill-creator at session end" — now states complementary manual meta-skill, no automatic trigger (matches manual-only statements elsewhere).
  2. Frontmatter teaching now notes Anthropic spec REQUIRES only name+description; allowed-tools optional; disable-model-invocation is a Claude-Code harness extension (still emitted — just not "universally required").
  3. CSO rule SOFTENED to Anthropic alignment: description must state WHAT + WHEN (third person); kept the real failure-mode warning (no followable step/phase SEQUENCE in description). Checklist + ✅/❌ examples updated to match.
  4. This skill's own description rewritten to what+when form (was trigger-only).
- TEMPLATE aesthetic (middle ground) applied to the GENERATED template only: per-skill in-body `## Kaizen` changelog → bundled `kaizen_log.md` pointer; epigraph quote/kanji + `## Philosophy` made OPTIONAL/documented. Existing skills' aesthetics untouched.

<!-- Kaizen: 2026-06-14 — Harness-extension clarification note (verification pass) -->
Verified that the clarifying note about `disable-model-invocation` and `allowed-tools` being Claude Code harness extensions (not part of the portable Agent Skills spec) is already present in BOTH locations:
- SKILL.md § "Frontmatter Rule" (line ~117): inline spec note in the `description:` teaching block.
- reference/templates.md § "Skill Template Generation" (lines ~83-84): **Frontmatter spec note** bold paragraph above the YAML scaffold.
Both notes state: spec requires only `name` + `description`; `allowed-tools` is optional; `disable-model-invocation` is a Claude-Code harness extension; keep using them in this repo but mark as Claude-Code-specific when authoring portable/published skills.
No file changes made — note already present from 2026-06-14 optimization pass.
