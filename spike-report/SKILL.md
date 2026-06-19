---
name: spike-report
description: Use when presenting completed spike research to stakeholders as an interactive HTML report — after the spike investigation is done, before the stakeholder review. (allowed-tools / disable-model-invocation below are Claude-Code harness extensions, not in the portable Agent Skills frontmatter spec, which needs only name + description.)
allowed-tools: [Write, Read, Bash, Glob, Grep, mcp__context7__query-docs, mcp__context7__resolve-library-id]
disable-model-invocation: true
---
<!-- Preserved from original frontmatter: created 2026-02-10 by skill-creator; related skills: architect, opsx:new, code-review; supports architecture/feature/performance/security/integration/migration spike types. -->

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

# Spike Report Generator - Visual Documentation for Technical Proposals

## Purpose

Generate interactive HTML reports for technical spikes — embedded SVG diagrams, permission matrices, gap analysis, architectural visualizations. Invoked manually after a spike investigation is complete; turns code analysis into shareable, stakeholder-friendly documentation (visual hierarchy, flow diagrams, current-vs-needed gaps) that goes beyond a markdown file.

## Invocation

This is a **manual-only Skill** (`disable-model-invocation: true`) — it is NOT a registered slash
command. The `/spike-report …` grammar below is shorthand for a natural-language request; the
`--flags` describe intent the agent interprets, not a parsed CLI. There is no flag parser.

```bash
/spike-report                                          # auto-detect from current branch
/spike-report <name> <type>                            # e.g. rbac-permissions architecture
/spike-report <name> --sections hierarchy,flow,erd     # subset of sections (see table below)
/spike-report <name> --output investigations/proposals/  # override output dir (default: investigations/spikes/)
/spike-report feature/CORE-141-rbac                    # target a specific branch
```

**When to invoke**: after spike research is complete · before a stakeholder/PM/leadership review ·
documenting architectural decisions · comparing current vs proposed · audit/compliance docs (PCI, SOC2).
**When NOT to**: quick bug fixes (overkill) · mid-spike (wait for complete analysis) · simple features
with no architecture change · internal refactors with no external-communication need.

## Spike Types & Sections (canonical)

| Type | Default sections | `--sections` extras | Color scheme |
|------|------------------|---------------------|--------------|
| **architecture** | hierarchy, flow, inheritance, erd, matrix, gap | + packages | blue/purple (structure, authority) |
| **feature** | current, proposed, flow, migration, risks | + testing | green/teal (growth, new) |
| **performance** | metrics, bottlenecks, improvements, benchmarks | + comparison | orange/red (speed, urgency) |
| **security** | threats, flow, mitigations, compliance | + audit | red/purple (protection, vigilance) |
| **integration** | architecture, api-contracts, error-handling | — | teal/blue (connection, flow) |
| **migration** | current/proposed, phases, rollback, risks | — | blue/indigo (default) |

## Workflow (6 phases, ~30 min vs 2-3 hrs manual)

Full ASCII workflow diagram → [`reference/workflow-phases.md`](reference/workflow-phases.md).
Per-phase scaffolds (git/Glob/Grep, context7 queries, `SPIKE_SECTIONS`, layout algorithms,
quality checks, save) → [`reference/phase-details.md`](reference/phase-details.md).

1. **ANALYZE** [5m] — git log + diff, find files by spike type, extract entities (roles/resources/permissions), read existing docs.
2. **RESEARCH** [3m] — context7 for SVG/Tailwind/accessibility best practices; check prior reports for style.
3. **STRUCTURE** [2m] — pick sections by type (table above), plan tabs/info-boxes/color scheme.
4. **DIAGRAM** [8m] — generate SVG (hierarchy/flow/ERD/state/comparison) from [`templates/svg-components.svg`](templates/svg-components.svg); auto-layout coordinates.
5. **CONTENT** [10m] — build HTML from [`templates/report.html`](templates/report.html) (Tailwind CDN, `showTab` JS, info boxes, Next Steps); embed SVG inline.
6. **POLISH** [2m] — validate HTML/CSS/SVG + accessibility + responsive; save to `investigations/spikes/` (gitignored via `.git/info/exclude` — NOT `docs/`); write `.md` companion; present `file://` URL.

> Output dir is created lazily and is gitignored — it is a personal artifact, never `docs/`.
> Markdown summary companion scaffold is in [`reference/phase-details.md`](reference/phase-details.md) (Phase 6).

## Examples

Three worked runs — RBAC architecture, payment-gateway feature, N+1 performance —
→ [`reference/examples.md`](reference/examples.md).

## Related Skills

| Skill | Relationship |
|-------|--------------|
| `/architect` | Architect defines structure → spike-report visualizes it |
| `/opsx:new` | OpenSpec creates specs → spike-report creates stakeholder docs |
| `/code-review` | Code review finds issues → spike-report documents solutions |
| `/tdd` | TDD ensures correctness → spike-report documents behavior |
| `/debug` | Debug finds root causes → spike-report documents fix strategy |

## Validation

Success criteria:
- ✅ HTML validates (no syntax errors)
- ✅ SVG renders correctly in Chrome/Firefox/Safari
- ✅ Responsive design works on mobile (375px+)
- ✅ Tabs switch smoothly (JavaScript works)
- ✅ Color contrast meets WCAG 2.1 AA (4.5:1)
- ✅ File size < 2MB (reasonable for email/Slack)
- ✅ Loads in < 2 seconds (no external dependencies beyond Tailwind CDN)

Failure indicators:
- ❌ SVG diagrams don't render (broken gradients, invalid viewBox)
- ❌ Tabs don't work (JavaScript error)
- ❌ Text unreadable (low contrast)
- ❌ Layout breaks on mobile (not responsive)
- ❌ Missing sections (analysis incomplete)

## Tips & Best Practices

- **DO**: auto-detect with bare `/spike-report` · meaningful emojis (🔐 security, 💰 payments) · keep SVG focused (≤15 nodes/diagram) · info boxes for key insights · "Next Steps" checklist · test mobile viewport · gradients sparingly · link related docs instead of duplicating.
- **DON'T**: generate mid-spike (wait for complete analysis) · hardcode IDs/values (use variables) · build massive diagrams (split into tabs) · skip ARIA labels · use custom fonts (system only) · embed large raster images (SVG/external links only) · forget the `.md` summary.

> Performance/ROI table (6x per use) and Troubleshooting (SVG/tabs/mobile/font/slow) →
> [`reference/troubleshooting.md`](reference/troubleshooting.md).

## Kaizen

If you discover a better SVG layout, diagram type, analysis pattern, or new spike type to support — complete the current report first, then run `/kaizen` to document and promote the improvement.

Full history and meta notes: [kaizen_log.md](kaizen_log.md)
