---
name: skill-creator
description: Detects skill gaps in the ecosystem and semi-automatically forges new skills from proven, repetitive manual work on real code. Use after a session where you did the same multi-step task 3+ times on implemented code (not exploration/planning/prototypes) and want to automate it.
allowed-tools: [Read, Grep, Glob, Edit, Write]
disable-model-invocation: false
---

# Skill Creator - Detect Gaps & Forge New Skills

> "Create skills from patterns, not guesswork" - 鍛造 (Tanzo - Forging)

## Purpose

Systematically detect skill gaps by analyzing session patterns, then semi-automatically create new skills when repetitive manual work on real, implemented code is identified. Keeps the skill ecosystem evolving from actual usage, not theoretical requirements.

## Philosophy

> "The best skills come from solving the same problem three times."

**1st time**: manual exploration (learn the problem). **2nd time**: documented approach (understand the pattern). **3rd time**: create a skill (automate the solution). Skills emerge organically from real needs.

## Core Principles

1. **Pattern-Driven** — only proven, repetitive patterns
2. **Data-Based** — analyze actual session data, not assumptions
3. **Semi-Automatic** — detect + suggest, but user approves
4. **Quality-First** — generated skills follow ecosystem standards
5. **Single Responsibility** — each skill solves one problem
6. **ROI-Focused** — create only if time saved > maintenance cost
7. **🔴 Implementation-Only** — only **implemented** patterns, never explorations or future ideas

## When to Use

**Manual only — user decides.** Invoke after a session where you notice: repetitive manual work (same thing 3+ times); a clever solution worth automating; a workaround for a skill failure; or a pattern that could help future sessions.

```bash
/skill-creator               # Analyze current session
/skill-creator analyze       # Deep analysis of last 10 sessions
/skill-creator suggest       # Show candidate skills (no creation)
/skill-creator create <name> # Create skill from approved proposal
/skill-creator metrics       # Show skill creation opportunities
```

- ✅ "Validated RBAC manually 3 times" → invoke
- ✅ "Fixed similar N+1 in 3 controllers" → invoke
- ✅ "Found pattern in gateway comparison" → invoke
- ❌ "Quick bug fix in 1 file" → don't (too simple)

## Detection Algorithm (Scoring)

Pre-filter: **implemented code only** — `:ignore` exploration/planning, future features, prototypes. Then score frequency + complexity + standardization + value + implementation. Thresholds:

- **≥ 8** → `:create_skill` (strong candidate)
- **5–7** → `:monitor` (watch for more occurrences)
- **< 5** → `:ignore` (not worth automating)

→ Full Ruby `skill_candidate?` scoring block: [reference/scoring-algorithm.md](reference/scoring-algorithm.md)

## Pattern Detection (5 Types)

| Type | Signal |
|------|--------|
| 1. Repetitive Grep + Read | Same grep → read same files → extract info, repeated 3+ times |
| 2. Manual Agent invocations | Same `Explore` "find all X, check Y" prompt 3+ times |
| 3. Multi-Validator sequences | Same ordered `/v1 → /v2 → /v3` run repeatedly (could parallelize) |
| 4. Complex Manual Analysis | Prod metrics → cross-ref code → root cause → fix, repeated |
| 5. Documentation Generation | Analyze structure → diagram → docs, same format each time |

→ Signals + example candidates per type: [reference/pattern-types.md](reference/pattern-types.md)

## Workflow: Skill Creation (6 Phases)

1. **Detect** — scan transcript, extract repeated workflows, count occurrences, score (0–10)
2. **Analyze** — check existing-skill overlap, verify ≥80% consistency, estimate ROI, filter score ≥ 8
3. **Propose** — generate proposal doc (name, workflow, ROI, before/after), present to user
4. **Approve** — user decides: ✅ approve / ⏸️ defer (backlog) / ❌ reject (document why)
5. **Generate** — create `.claude/skills/<name>/SKILL.md` from template, seed `kaizen_log.md`
6. **Validate** — frontmatter valid, tools exist, conventions met, **behavior-tested** (≥1 RED + ≥1 GREEN + ≥1 combined-pressure)

→ Full ASCII workflow box with per-phase detail: [reference/workflow-phases.md](reference/workflow-phases.md)

## Templates

→ All copy-paste templates live in [reference/templates.md](reference/templates.md):
- **Proposal Format** — what to present when a candidate is detected
- **Skill Template Generation** — the `SKILL.md` scaffold the generator emits (frontmatter spec notes + optional epigraph/Philosophy + `kaizen_log.md` pointer)
- **Creation-Log Template** — entry shape for `creation_log.md`
- **Deferred Backlog Format** — monitoring / deferred / rejected tracking
- **Output / Detection-Report Format** — the session opportunities report

## Integration with Orchestrator

> **NOT IMPLEMENTED** — skill-creator is **manual-only**, with zero automatic triggers. No session hook or cron fires it.

→ Aspirational end-of-session / weekly-aggregation pseudocode (reference only): [reference/aspirational-integration.md](reference/aspirational-integration.md)

## Metrics & Tracking

Record every detection/decision in [`creation_log.md`](creation_log.md) (entry shape in the Creation-Log Template within [reference/templates.md](reference/templates.md)).

## Frontmatter Rule: `description:` States What + When (not a Step Sequence)

When authoring or editing a skill's YAML frontmatter:

**Rule**: `description:` must state, in third person, **WHAT the skill does AND WHEN to use it** (concrete triggering conditions). This aligns with the Anthropic Agent Skills spec, where `description` is the field that tells the agent both the capability and when to apply it.

**Real failure-mode to avoid**: do **not** encode a step/phase **SEQUENCE** in the description that an agent could follow in lieu of reading the body. When the description spells out an ordered workflow, the agent may follow the description verbatim and skip the body. A description that summarized "code review between tasks" caused ONE review where the body's flowchart required TWO; removing the workflow summary made the agent read the flowchart and comply. State the what+when; keep the *how* (ordered steps/phases) in the body only.

```yaml
# ❌ BAD: encodes an ordered sequence — agent follows this, skips the body
description: Use when repetitive work detected — scan sessions, score patterns, propose, get approval, generate

# ✅ GOOD: states what it does AND when to use it, no followable step sequence
description: Detects skill gaps and forges new skills from repetitive manual work on real code. Use after doing the same multi-step task 3+ times on implemented code.
```

**Frontmatter spec note**: the Anthropic spec only REQUIRES `name` + `description`. `allowed-tools` is optional; `disable-model-invocation` is a Claude-Code harness extension (not in the Anthropic Skills spec). Keep using them here (valid in this harness) — just don't present them as universally required.

**Checklist addition** — before Phase 6 (Validate), confirm:
- [ ] `description:` states WHAT the skill does AND WHEN to use it (third person)
- [ ] `description:` contains NO followable step/phase SEQUENCE (no ordered workflow)
- [ ] The ordered workflow/steps live exclusively in the skill body

## Pressure-Test Before Ship (TDD for Skills)

The Iron Law (from obra/superpowers writing-skills, MIT): **NO SKILL WITHOUT A FAILING TEST FIRST.** Applies to new skills AND edits. A skill written without a baseline test is deployed untested code (analogous to CLAUDE.md rule #8: failing spec before fix).

- **RED — baseline (without skill)**: dispatch a fresh subagent (`subagent_type: general-purpose`) with a realistic scenario where the skill SHOULD change behavior, but do NOT mention the skill. Document verbatim: choices made, rationalizations, which pressures triggered the violation.
- **GREEN — with skill**: re-run the same scenario WITH the skill content available. The agent must now behave per the skill. If it still fails, revise and re-test.
- **Pressure variants**: re-run GREEN under combined pressures (time, sunk cost, authority, economic, exhaustion, social, pragmatic). Best tests combine 3+.

**Acceptance rule** — a skill is NOT done until: ≥1 RED documented + ≥1 GREEN documented + GREEN holds under ≥1 combined-pressure scenario. Document in the skill's `kaizen_log.md` or `investigations/`. Undocumented = untested = not done. **No exceptions** (not for "simple additions", not for "just adding a section"). The bench is Agent-tool subagent dispatch — no external CLI harness needed.

→ Pressure-variant table + worked PBP $10k/min example: [reference/pressure-testing.md](reference/pressure-testing.md)

## Quality Gates (7 Checks)

Before creating a skill, verify:

1. ✅ **🔴 IMPLEMENTED** — pattern operates on **existing code**, not ideas/exploration
2. ✅ **Necessity** — occurred 3+ times **on real codebase**
3. ✅ **Uniqueness** — no existing skill covers it
4. ✅ **Automatable** — can be automated (not pure judgment)
5. ✅ **Maintainable** — worth long-term maintenance
6. ✅ **ROI** — time saved ≥ 10x maintenance cost
7. ✅ **Behavior-tested** — ≥1 RED + ≥1 GREEN + ≥1 combined-pressure documented (see Pressure-Test Before Ship)

If any fails → reject or defer.

**Gate 1 (Implementation Check) questions**: Does the code exist (not planned)? Was the pattern run on real files (not theoretical)? Did we make actual changes (not just explore)? Is it about validating existing logic (not designing new)?

→ Worked ❌ REJECT / ✅ APPROVE Gate-1 examples: [reference/examples.md](reference/examples.md)

## Common Rejection Reasons

1. **🔴 NOT IMPLEMENTED** (most common) — exploration/planning, no code yet
2. **Prototype phase** — logic may change, wait until stable
3. **One-off tasks** — exploration, won't repeat
4. **Existing skill** — already covered (e.g. `/code-review`)
5. **Too specific** — only this exact file
6. **Low frequency** — once per quarter
7. **Judgment-heavy** — requires human decision-making
8. **Low ROI** — saves little, complex to maintain
9. **Better alternatives** — simpler to just document the steps

→ Worked NOT-IMPLEMENTED (auto-reject) vs IMPLEMENTED (consider) scenarios: [reference/examples.md](reference/examples.md)

## Success Criteria

A successfully created skill should: 1. **Solve a real problem** (actual pattern, not theory); 2. ⚡ **Save time** (≥25 min/use, measurable); 3. 🔄 **Be used regularly** (≥2x/month); 4. 📈 **Positive ROI** (≥5x within 90 days); 5. 🔧 **Maintainable** (easy to update, clear docs).

## Best Practices

**DO** ✅ — analyze the FULL session before suggesting · require 3+ occurrences · show concrete examples from real sessions · calculate realistic (not optimistic) ROI · get approval BEFORE creating · test the generated skill on the original pattern · document why · follow existing conventions · track actual ROI at 30/90 days.

**DON'T** ❌ — create for theoretical needs · suggest after 1–2 occurrences · auto-create without approval · overestimate savings · skip validation · ignore existing skills · create overlapping/too-specific skills · forget the creation log · create-and-forget (monitor usage).

## Deferred Backlog

Track deferred candidates (Monitoring / Deferred / Rejected) — format in [reference/templates.md](reference/templates.md#deferred-backlog-format).

## Related Skills

| Skill | Relationship |
|-------|--------------|
| `/kaizen` | Improves existing skills (complementary) |
| `/orchestrate` | Complementary manual meta-skill — lists skill-creator as a Meta-Skill with **no automatic trigger** (invoke manually) |
| `/architect` | Both use systematic analysis patterns |
| `/qa-audit` | Both validate quality systematically |

## Remember

> "Skills should emerge from patterns, not predictions." **Wait for proof (3+ occurrences). Get approval. Create quality. Track ROI.**

Don't create skills prematurely. Let patterns prove themselves. Semi-automation prevents skill bloat while ensuring real needs are met.

---

## Meta-Kaizen

> Changelog archived to [`kaizen_log.md`](kaizen_log.md).
