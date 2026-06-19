# optimize-skill — Kaizen History

---

<!-- Kaizen: 2026-06-15 — correctness-only optimization pass -->
- Fixed: Line 60 (Step-4 validator checklist) required `allowed-tools` + `disable-model-invocation` as
  mandatory frontmatter fields. Corrected to require only `name` + `description` (the two mandatory
  fields per the portable Agent Skills spec); `allowed-tools` / `disable-model-invocation` are now
  labelled as optional Claude Code extensions. Aligns the checklist with line 37 of the same file and
  current Anthropic docs.
- Fixed: Source URLs on lines 87-88 pointed to `docs.anthropic.com/en/docs/agents-and-tools/...`
  which returns HTTP 301 → `platform.claude.com/docs/en/docs/agents-and-tools/...`. Updated to the
  canonical host to avoid eventual link rot. Engineering blog URL left unchanged (not verified in this
  pass).
  - Follow-up (validator-caught precision gap): the host fix still left a double `/docs/en/docs/`
    segment that carries an intra-domain HTTP 307. Corrected to the truly canonical single-segment path
    `platform.claude.com/docs/en/agents-and-tools/agent-skills/{best-practices,overview}` (verified 200
    via curl; matches the URLs already stored in the auto-memory reference).
- No structural changes (body was 89 lines, well under the 500-line ceiling; no relocate/densify/dedup
  warranted per the plan analysis).
- Deferred (user decision needed): whether "HARD CEILING" on line 23 should be softened to
  "target/strong guideline" to match upstream Anthropic wording ("ideal", "not a hard limit enforced
  by validation"). Kept as-is per local convention
  (`reference_skill_optimization_progressive_disclosure`).
- Deferred: Line 38 says reference files >100 lines get a ToC; skill-creator docs say >300 lines.
  Upstream Anthropic guidance is internally inconsistent across pages. No change; flagged for future
  reconciliation.
