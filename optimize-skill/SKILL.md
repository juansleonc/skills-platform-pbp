---
name: optimize-skill
description: Optimize an existing SKILL.md for token efficiency via Anthropic progressive disclosure — relocate detail to bundled files, densify prose, de-duplicate against single sources of truth, never deleting capability. Use when a skill's body exceeds ~500 lines / ~5k tokens or carries worked-examples, large tables, or content duplicated from elsewhere.
allowed-tools: [Read, Grep, Glob, Edit, Write, Bash]
disable-model-invocation: true
---

# Optimize Skill — Progressive Disclosure Without Capability Loss

## Core Principle

> **OPTIMIZE ≠ DELETE.** Move content to a lower load-level or densify it; never remove capability.
> The target is what loads at **Level-2 (the body)**, not what the skill *knows*.

## The 3-Level Progressive-Disclosure Model

| Level | What | Loads when | Budget |
|-------|------|-----------|--------|
| **L1** metadata | `name` + `description` | always (boot) | ~100 tok |
| **L2** instructions | the SKILL.md body | when skill triggers | **<5k tok / <500 lines** |
| **L3** resources | `reference/*.md`, `examples.md`, `scripts/` (run via bash) | only when Read/executed | ~0 tok until touched |

**HARD CEILING: body < 500 lines.** SKILL.md is a table-of-contents + decision core, not the full manual.

## The 3 Techniques (none deletes)

| Technique | What moves | How |
|-----------|-----------|-----|
| **RELOCATE** | worked examples, long tables, diagrams, templates | → bundled `reference/*.md` / `examples.md` + a one-line pointer in body |
| **DENSIFY** | "Claude already knows" rationale, prose walls | strip rationale; rules as terse imperatives; fragile sequential steps → `- [ ]` checklists |
| **DE-DUPLICATE** | content restated from CLAUDE.md / another skill / a shared doc | link to the single source of truth instead of restating |

## Rules (from the docs)

- **Pointers ONE level deep**: body → file. Never body → A → B. No nested redirection.
- **Description**: third person, states *what* AND *when* (concrete triggers). No workflow summary.
- **Frontmatter**: the portable Agent Skills spec requires only `name` + `description`; `allowed-tools` / `disable-model-invocation` are Claude Code harness extensions — valid here, but mark as Claude-Code-specific when authoring portable skills.
- **Reference files > 100 lines** get their own table-of-contents at the top.
- **Offload deterministic work to `scripts/`** (run via bash) instead of narrating steps in prose.
- **Collapse legacy** into a `<details>` "Old patterns" block — don't delete it.

## Step-by-Step Procedure

0. **Ground in current docs (MANDATORY).** Before optimizing, query **Context7** (`resolve-library-id` → `query-docs`; fall back to web search if Context7 lacks the library) for BOTH:
   1. **Agent Skills authoring/optimization** best practices (so the restructure follows current guidance), AND
   2. **the subject domain of the skill being optimized** — e.g. optimizing a `graphql` skill → pull current GraphQL docs; a `migration` skill → Rails migration docs; a `sidekiq` skill → Sidekiq docs.

   Use this to (a) inform the restructure and (b) **flag any stale or incorrect domain guidance in the skill's content** — outdated content is a correctness fix to surface/correct, NOT something to silently relocate. Record which docs were consulted.

1. **Map** sections + line ranges: `grep -nE '^#{2,3} ' SKILL.md` and `wc -l SKILL.md`.
2. **Classify** each block:
   - **DECISION** (logic the agent branches on) → keep in body
   - **REFERENCE** (examples, big tables, templates) → relocate to L3
   - **REDUNDANT** (restated from a source of truth) → dedup → pointer
3. **Apply** relocate / densify / dedup:
   - Relocate content **VERBATIM** into its destination file (no paraphrase that loses detail).
   - Every pointer stays **one level deep** and **resolves**.
4. **Validate — INDEPENDENT pass** (different agent/session than the one that edited; creator/verifier separation):
   - [ ] body < 500 lines
   - [ ] frontmatter valid (opening `---`, required `name` + `description` present and well-formed; `allowed-tools` / `disable-model-invocation` optional Claude Code extensions; closing `---`)
   - [ ] every decision-logic anchor still present in body
   - [ ] every pointer resolves to a real file
   - [ ] each relocated block is present in its destination
   - [ ] no capability lost (the skill still answers everything it did before)

## Orchestration

When run under `/orchestrate`, split roles — **never let the editor self-verify**:

| Role | Subagent | Does |
|------|----------|------|
| Analyst (read-only) | Explore | run Step-0 Context7/web queries; map sections + classify each block |
| Worker | general | apply relocate/densify/dedup, create bundle files |
| Validator (different session) | independent | run the Step-4 checklist; confirm no capability lost |

## Anti-patterns

- ❌ Delete capability to hit the line budget.
- ❌ Nest pointers (body → file → another file).
- ❌ Leave a relocated block missing from BOTH body and destination (vaporized content).
- ❌ Duplicate the same content in body AND bundle (defeats the dedup).
- ❌ Optimizing a skill without first grounding its domain content against current Context7/official docs (you may relocate stale guidance instead of fixing it).

---

**Source**: auto-memory `reference_skill_optimization_progressive_disclosure` · Anthropic docs:
- Best practices: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- Overview: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
- Engineering blog: https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
