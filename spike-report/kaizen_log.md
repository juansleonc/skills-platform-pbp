# spike-report — Kaizen Log (archived)

> Archived from SKILL.md on 2026-06-14 per skills-audit Wave 3.
> Active instructions live in SKILL.md. Add new entries here; promote lessons into SKILL.md body.

---

## Recent Improvements

<!-- Kaizen: 2026-06-15 - /optimize-skill pass: body 656 -> 108 lines (HARD ceiling 500). Relocated verbatim to reference/: workflow ASCII box (workflow-phases.md), Phase 1-6 scaffolds + SPIKE_SECTIONS + layout algos + save/markdown scaffold (phase-details.md), 3 worked Examples (examples.md), Performance/ROI table + Troubleshooting (troubleshooting.md). Densified: dropped Shikakuka/"picture is worth" epigraphs + Philosophy block; merged Spike-Types table with sections-by-type + color-schemes into ONE canonical table; merged Integration prose into the Related Skills table; DO/DON'T -> 2 bullets. Deduped: 6 repeated /spike-report flag blocks -> ONE Invocation block. Correctness: (1) frontmatter now annotates allowed-tools/disable-model-invocation as Claude-Code harness extensions inside description (mirrors packwerk), (2) added explicit line that /spike-report is NOT a registered slash command — it's manual-only shorthand, --flags = interpreted intent not a parsed CLI (verified: no .claude/commands/spike-report). Verified investigations/ gitignored (.git/info/exclude:35, git check-ignore IGNORED). DEFERRED (user-decision, headless): description lead-with-capability rewrite; full reframe of /spike-report grammar to pure natural-language; removing epigraphs entirely vs keeping; final aggressiveness of phase-details split. -->

<!-- Kaizen: 2026-06-14 - skills-audit Wave 3: archived self-edit Kaizen block to this file; removed "Use Edit tool" anti-pattern (Edit not in allowed-tools); replaced with /kaizen pointer. -->

<!-- Kaizen: 2026-06-10 - Frontmatter normalized to ecosystem schema: replaced version/author/tags/triggers/dependencies with name/description(CSO-style)/allowed-tools/disable-model-invocation; preserved legacy info as body comment. -->

<!-- Kaizen: 2026-06-10 - Output dir created lazily: added `mkdir -p investigations/spikes` as Phase 6 step 0; softened example output lines to note the dir will be created if absent (verified: investigations/spikes/ does not exist). -->

<!-- Kaizen: 2026-02-10 - Initial creation -->
Created `/spike-report` skill from proven pattern:
- Based on 2 real RBAC spike reports (v1: 677 lines, v2: 1,246 lines)
- Automates HTML/CSS/SVG generation (saves 2.5 hours per spike)
- Supports 6 spike types: architecture, feature, performance, security, integration, migration
- Integrates with context7 for best practices
- Expected ROI: 9x (27 hours/year saved vs 3 hours maintenance)

Next improvements needed:
- [ ] Add D3.js integration for more complex interactive diagrams
- [ ] Support Mermaid diagram conversion (markdown → SVG)
- [ ] Add PDF export option (for offline sharing)
- [ ] Create gallery of example reports (investigations/spikes/examples/)
- [ ] Add real-time preview server (live reload during generation)
- [ ] Support custom themes (dark mode, company branding)

---

## Meta: Skill Creation Log

**Created by**: skill-creator agent
**Date**: 2026-02-10
**Triggered by**: User request after creating 2 RBAC spike reports
**Pattern detected**: Manual HTML/SVG/CSS report generation (2-3 hours per spike)
**Score**: 19/20 (Very Strong Candidate)
**ROI estimate**: 9x
**Approval**: User approved immediately

**Implementation notes**:
- Skill generates HTML with embedded SVG (no external dependencies beyond Tailwind CDN)
- Uses context7 for best practices research (SVG, Tailwind, accessibility)
- Supports 6 spike types with customizable sections
- Template-based generation with variable substitution
- Validates output for syntax, accessibility, responsiveness

**Success metrics to track**:
- Time to first report: < 5 minutes
- User satisfaction: Positive feedback on clarity/beauty
- Reuse rate: ≥ 80% of major spikes use this skill
- Maintenance burden: < 3 hours/year for updates
