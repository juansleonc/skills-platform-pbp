# Orchestrate — Master Dependency Graph

Relocated from SKILL.md body (progressive disclosure). The full visual phase map of
the orchestration pipeline — ideation → grill → architect → analysis → TDD → validator
gate → validation → quality → publish — with the subagent type and model pinned per
phase. The body's Phase Gates checklist and Delegation Protocol are the authoritative
text; this ASCII map is the at-a-glance picture.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MASTER ORCHESTRATION MAP                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PHASE 0: Ideation (unformed specs)   [coordinator-direct: /brainstorm]     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │   Diverge: decompose → generate 2-3+ approaches → pick a DIRECTION    │   │
│  │   (only when WHAT/HOW is open; skip straight to 0a if approach known) │   │
│  └──────────────────────────────┬──────────────────────────────────────┘   │
│                                 ▼                                           │
│  PHASE 0a: Grill (fuzzy specs)        [coordinator-direct: /grill-me]       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │   Interrogate user until ambiguity = 0 → emit VALIDATION CONTRACTS    │   │
│  │   (testable assertions C1..Cn that flow into architect/TDD/validator)│   │
│  └──────────────────────────────┬──────────────────────────────────────┘   │
│                                 ▼                                           │
│  PHASE 0: Architecture              [→ Agent: architect (opus) / "follow /architect"] │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                           architect                                  │   │
│  │    Research → Design → ADR (given the contracts)                     │   │
│  └──────────────────────────────┬──────────────────────────────────────┘   │
│                                 ▼                                           │
│  PHASE 1A: Static Analysis        [→ Agent: Explore ×N IN PARALLEL, read-only] │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐                       │
│  │ timezone │ │ packwerk │ │ security │ │ graphql  │                       │
│  │          │ │          │ │          │ │          │                       │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘                       │
│       └────────────┴────────────┴────────────┘                              │
│                                 ▼                                           │
│  PHASE 1B: Domain Skills          [→ Agent: Explore ×N IN PARALLEL, read-only] │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐               │
│  │memberships │ │  pci-      │ │  gateway-  │ │ migration  │               │
│  │            │ │ compliance │ │ consistency│ │            │               │
│  └─────┬──────┘ └─────┬──────┘ └─────┬──────┘ └─────┬──────┘               │
│        └──────────────┴──────────────┴──────────────┘                       │
│                                 ▼                                           │
│  PHASE 2: Implementation (SEQUENTIAL)     [→ Agent: worker / "follow /tdd"]  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │              TDD — worker implements in its OWN session              │   │
│  │         (RED → GREEN → REFACTOR → COVERAGE 100%); satisfy C1..Cn     │   │
│  └──────────────────────────────┬──────────────────────────────────────┘   │
│                                 ▼                                           │
│  ══════════════════════════════════════════════════════════════            │
│  ║  GATE 3.5 — VALIDATOR (BLOCKING)   [→ Agent: validator, DIFFERENT    ║   │
│  ║  session than worker]. Verifies every contract C1..Cn against the    ║   │
│  ║  diff. REQUEST CHANGES → loop back to a fresh worker.                 ║   │
│  ══════════════════════════════════════════════════════════════            │
│                                 ▼                                           │
│  PHASE 2.5: Validation            [→ Agent: Explore/worker IN PARALLEL]      │
│  ┌──────────┐ ┌──────────┐ ┌─────────────┐ ┌───────────────┐              │
│  │ sidekiq  │ │ perform- │ │multi-tenancy│ │ action-policy │              │
│  │(if jobs) │ │ ance     │ │(if queries) │ │(if policies)  │              │
│  └────┬─────┘ └────┬─────┘ └──────┬──────┘ └──────┬────────┘              │
│       └─────────────┴──────────────┴───────────────┘                       │
│                                 ▼                                           │
│  PHASE 3: Quality                 [→ Agent: worker/Explore IN PARALLEL]      │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                │
│  │  code-review   │  │    coverage    │  │     pronto     │                │
│  │   (Context7)   │  │  (verify 100%) │  │  (lint lines)  │                │
│  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘                │
│          └───────────────────┼───────────────────┘                         │
│                              ▼                                              │
│  ══════════════════════════════════════════════════════════════            │
│  ║       QUALITY GATE: all checks pass (validator gate already passed) ║   │
│  ══════════════════════════════════════════════════════════════            │
│                              ▼                                              │
│  PHASE 4: Publish (user approval FIRST → then delegate)                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Coordinator asks y/n. On approval → Agent: worker runs commit→PR.   │   │
│  │  Coordinator itself runs no git.                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```
