# Learning Skill — Kaizen Log

Historical improvement entries. Promoted content is already reflected in the active SKILL.md body. New entries go here first; promote to SKILL.md body if they change operational behavior.

---

<!-- Kaizen: 2026-06-13 — conflicts: edge in Phase 4c (knowledge-lint C2/C4 linter integration) -->
- Extended Phase 4c: added `conflicts:` as a 4th typed-edge type for the case where a learning CONTRADICTS an existing node but NEITHER supersedes nor corrects it (both remain active, resolution deferred to human). Shape: symmetric list of bare stems. Decision gate added (ask user when ambiguous which of superseded_by / corrects / conflicts applies). Symmetry required — both files must list each other; C4 linter enforces. `conflicts:` peers are co-equal and contradictory; they do NOT supersede each other (that is the key distinction from `superseded_by:`).
- `conflicts:` stems list: `[peer_stem_1, peer_stem_2, ...]` — symmetric, top-level YAML key, same format as existing `superseded_by:`.

<!-- Kaizen: 2026-06-13 — Typed frontmatter edges (knowledge-graph ADR item 3) -->
- Added Phase 4c: when a learning expresses a supersession / correction / ticket relation, write the corresponding `superseded_by:` / `corrects:` / `ticket:` frontmatter key in the topic file(s), in addition to the MEMORY.md prose entry. Rule: "prose AND typed frontmatter — never just one." Closes the gap where supersession chains only existed in English prose and were invisible to a linter or graph tool.

<!-- Kaizen: 2026-06-10 — Casing fix (Fable re-audit hygiene pass) -->
- Fixed: two occurrences of `.claude/skills/<name>/skill.md` changed to `SKILL.md` (Purpose section and Phase 4b propagation instruction). Lowercase form silently empty on Linux.

<!-- Kaizen: 2026-05-09 - Initial creation -->
- Created: `/learning` skill with hybrid trigger (detection + confirmation)
- Storage: dual — auto-memory (feedback_*.md) + skill kaizen sections
- Mechanism: relies on `CLAUDE.local.md` rule #15 to instruct model to invoke this skill on detected corrections (no real auto-trigger; ~90% reliable)
- Skill mapping: 16 categories of correction topics mapped to relevant skills
- Conflict resolution: 4 actions (replace/keep-both/merge/cancel)
- False positive cooldown: 3 consecutive `n` → disable auto-suggest this session
- Why: prior to this skill, every correction had to be manually transcribed into a feedback_*.md file; many were lost
- ROI: 3.0 (high value preventing repeats, low effort reusing existing memory infrastructure)

<!-- Kaizen: 2026-06-14 — Skills audit Wave 2 cleanup -->
- Fixed Phase 4 ordering: was 4a → 4c → checklist → 4b; corrected to 4a → 4b → 4c → checklist (logical execution order matches numbering).
- Fixed Conflict Resolution `r` action: clarified it maps to `superseded_by:` typed edge, not raw deletion. `k` now explicitly cross-references `conflicts:` typed-edge pathway from Phase 4c.
- Fixed short-form `memory/` paths to canonical absolute path `~/.claude/projects/-Users-leon-workspace-pbp-platform/memory/` in: Phase 4a slug-rules, Phase 4b kaizen entry template, Phase 5 confirmation output, Templates section kaizen entry.
- Archived Kaizen entries to sibling `kaizen_log.md` (this file); SKILL.md body now references the archive.
