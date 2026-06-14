# Brainstorm — Kaizen Log

Archived from SKILL.md (active body stays lean; history lives here).

<!-- Kaizen: 2026-06-13 - Created as the divergent counterpart to /grill-me -->
- Origin: ported from obra/superpowers' `brainstorming` skill
  (https://github.com/obra/superpowers, `skills/brainstorming/SKILL.md`), adapted to this
  repo's split flow. superpowers does diverge + converge + design-doc + handoff in ONE
  skill; here we keep the divergent front-end only and hand off to the existing
  `/grill-me` (converge) → `/architect` (design) chain to avoid overlap.
- Dropped from the port for v1: the **visual companion** (superpowers ships a local
  Node/websocket server for browser mockups). Deferred — if revived, use the
  Claude-in-Chrome MCP we already have rather than a maintained Node server. See memory
  `[[reference_ai_coding_multiagent_workflow]]`.
- Kept from superpowers: decompose-before-refine, one-question-at-a-time, 2-3 approaches
  with trade-offs + recommendation, YAGNI, the "too simple to need this" anti-pattern
  (here recast as "skip to /grill-me if you already know the approach").
