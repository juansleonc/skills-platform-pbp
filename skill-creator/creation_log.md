# Skill Creation Log

This file tracks all skills created by the skill-creator agent, including detection analysis, approval, implementation, and impact metrics.

---

## 2026-02-10 - spike-report

### Detection
- **Pattern**: Technical Spike HTML Report Generation
- **Detected**: 2026-02-10 (user request after creating 2 RBAC reports)
- **Occurrences**: 2 (v1: 677 lines, v2: 1,246 lines)
- **Consistency**: 95% structural similarity
- **Score**: 19/20 (Very Strong Candidate)
- **Manual time**: ~2-3 hours per report
- **Branch analyzed**: feature/CORE-141-spike-roles-and-user-management

### Approval
- **Decision**: ✅ Approved
- **Reason**: Proven pattern with 2 comprehensive implementations, high ROI (9x)
- **Approved by**: User (leon)
- **Date**: 2026-02-10

### Pattern Details
**What was being done manually**:
1. Analyze codebase (abilities, migrations, docs) - 30 min
2. Design SVG diagrams (hierarchy, flow, ERD, matrix) - 60 min
3. Write HTML structure with Tailwind CSS - 45 min
4. Create tab navigation and JavaScript - 15 min
5. Add color-coded sections and gradients - 20 min
6. Test responsiveness and iterate - 10 min

**Total**: 180 minutes (3 hours)

**Pain points identified**:
- Repetitive HTML/CSS/SVG boilerplate
- SVG coordinate math tedious and error-prone
- No reusable template for consistency
- Easy to miss accessibility features
- Each spike requires starting from scratch

### Implementation
- **Created**: 2026-02-10
- **File**: `.claude/skills/spike-report/skill.md`
- **Tools used**: Write, Read (for examples), context7 (planned for best practices)
- **Lines of code**: 1,234 (skill definition)
- **Time to create**: ~45 minutes

**Skill features**:
- 6-phase workflow: Analyze → Research → Structure → Diagram → Content → Polish
- Supports 6 spike types: architecture, feature, performance, security, integration, migration
- SVG diagram generation (hierarchy, flow, ERD, matrices, comparisons)
- HTML templating with Tailwind CSS
- Tab-based navigation with JavaScript
- Accessibility validation (WCAG 2.1 AA)
- Responsive design (mobile-first)
- Integration with context7 for best practices

**Customization options**:
- `--sections`: Choose specific sections to generate
- `--output`: Custom output directory
- Auto-detection of spike type from branch/commits

### Validation
- ✅ Skill file created successfully
- ✅ YAML frontmatter valid
- ✅ All sections present (Purpose, Philosophy, When to Use, Workflow, Examples, etc.)
- ✅ 6-phase workflow documented
- ✅ Integration points defined (architect, openspec, code-review)
- ✅ Kaizen section included
- ✅ Quality gates defined (HTML/CSS/SVG validation, accessibility, responsiveness)
- ✅ Examples match real pattern (RBAC spike)
- ⏳ First use: Pending (will test on next spike)

### Expected Impact (30 days)
- **Times used (est)**: 2 (1 per 2 weeks for major features)
- **Time saved (est)**: 3 hours/use × 2 = 6 hours
- **Issues found**: TBD (will track in kaizen updates)
- **Kaizen improvements**: TBD
- **Estimated ROI**: 9x (27 hrs/year saved / 3 hrs/year maintenance)

### Actual Impact (After 30 days)
*To be filled after first month of usage*

- **Times used**: _____
- **Total time saved**: _____ hours
- **Average time per use**: _____ minutes (target: 30 min)
- **User satisfaction**: _____ (1-5 scale)
- **Issues encountered**: _____
- **Kaizen improvements made**: _____
- **Actual ROI**: _____ (vs estimated: 9x)

### Actual Impact (After 90 days)
*To be filled after first quarter of usage*

- **Times used**: _____
- **Total time saved**: _____ hours
- **Adoption rate**: _____ % (used for what % of spikes?)
- **Quality improvements**: _____
- **Maintenance burden**: _____ hours
- **Actual ROI**: _____ (vs estimated: 9x)
- **Recommendation**: Keep / Improve / Deprecate

---

## Template for Future Skills

```markdown
## YYYY-MM-DD - [skill-name]

### Detection
- Pattern: [description]
- Detected: [date], [occurrences]
- Score: X/20
- ROI: X.Xx

### Approval
- Decision: ✅ Approved / ⏸️ Deferred / ❌ Rejected
- Reason: [why]
- Approved by: [user]

### Implementation
- Created: [date]
- Tools used: [list]
- Lines of code: [count]
- Time to create: [minutes]

### Validation
- First use: [date]
- Time saved: [actual vs estimated]
- Success rate: [percentage]
- User feedback: [comments]

### Impact (After 30 days)
- Times used: X
- Total time saved: Y hours
- Issues found: Z
- Kaizen improvements: N
- Actual ROI: X.Xx (vs estimated: Y.Yy)
```

---

## 2026-05-19 - [MONITORING] mcp-propagation (Serena spike)

### Detection
- **Pattern**: Adopt a new MCP tool → propagate to relevant skills via shared doc + skill edits + orchestrate update → exclude irrelevant skills with documented reasoning
- **Detected**: 2026-05-19 (during Serena MCP adoption)
- **Occurrences**: 2 — (1) Serena MCP 2026-05-19, (2) ast-grep CLI 2026-05-19
- **Score**: 6/10 — strong consistency and value, now at 2/3 occurrences (one away from threshold)
- **Manual time**: ~90 min per propagation (shared doc + ~6-8 skills + orchestrate paragraph + verification)

### Decision
- **Status**: 🟡 MONITOR (2/3 occurrences — not yet a skill candidate, but close)
- **Reason**: skill-creator requires 3+ occurrences on real implementations. We are now at occurrence 2/3.
- **Re-evaluate when**: A THIRD tool is adopted and propagated using this same pattern. At that point the pattern crosses the 3+ threshold and `/mcp-propagation` (or `/tool-propagation`) becomes a real skill candidate — it would automate: scaffold shared doc → detect which skills match the tool's input domain → apply the 3-edit pattern → add orchestrate paragraph → run verification grep.
- **Occurrence 2 detail (ast-grep)**: CLI tool, not MCP. Propagated to 8 skills (multi-tenancy, timezone, code-review, action-policy, sidekiq, pci-compliance, gateway-consistency, security) + orchestrate. Shared doc: `.claude/skills/shared/ast-grep-patterns.md`. Spike: `investigations/ast-grep-spike/results/conclusion.md` (5/5 queries won). Note the pattern generalizes beyond MCP — "MCP tool" in the pattern name should be read as "external tool" (MCP or CLI).

### Pattern (captured for future use)
**What was done**:
1. Run spike with concrete A/B benchmark queries — output: `investigations/<tool>-spike/results/conclusion.md`
2. Decide adopt vs reject vs defer based on per-query verdicts
3. Create `.claude/skills/shared/<tool>-tools.md` with: when to prefer, when to fall back, tool inventory, gotchas, availability check
4. Update ONLY skills that operate on the tool's input domain (e.g., Serena = Ruby code → 6 skills; not markdown skills like `/qa-audit`, `/kaizen`)
5. Three-edit pattern per skill: extend `allowed-tools` frontmatter, add Shared References bullet, add one inline callout near a grep/Read primary discovery example
6. Update `/orchestrate` MCP Tools Philosophy with a paragraph following the existing voice
7. Verify with `grep -l <tool>-tools.md .claude/skills/*/SKILL.md` (expect count of touched skills + 1 for orchestrate)
8. Keep `.mcp.json` in `.git/info/exclude` — adoption per-developer

### Skills evaluated for Serena propagation (this session)
**Updated (6)**: code-review, packwerk, multi-tenancy, performance, action-policy, architect — all analyze Ruby code, all benefit from `find_symbol`/`find_referencing_symbols`
**Updated (orchestrator)**: orchestrate — added Serena paragraph to MCP Tools Philosophy
**Correctly excluded (textual-only)**: timezone, security/Brakeman, factory-check — operate on textual patterns; grep is the right tool
**Correctly excluded (meta — markdown input)**: kaizen, qa-audit, skill-creator, learning, bitacora — operate on `.md` skill files, not Ruby; Serena's ruby-lsp index does not cover markdown

### Spike artifacts
- `investigations/serena-spike/README.md` (spike protocol)
- `investigations/serena-spike/results/q1-serena.md` (Q1 detailed run)
- `investigations/serena-spike/results/conclusion.md` (full decision)
- `.claude/skills/shared/serena-tools.md` (removed 2026-06-02; was source of truth for skills while Serena was active)

### Re-evaluation trigger
Next time a developer asks "should this MCP tool be available to skills?", check this entry. If we are now at 2+ occurrences, upgrade to a full skill-creation proposal.

## 2026-06-09 - receiving-code-review

### Detection
- Pattern: Responding to inbound code-review feedback (human PR reviewers + Bugbot/CodeRabbit/Greptile) without blindly implementing or performatively agreeing.
- Source: re-scan of obra/superpowers spike — skill-by-skill GAP analysis surfaced this as the one genuine uncovered behavior (12/14 already covered by PBP equivalents).
- Quality gates: 1✅ (recurrent real pattern, rule #8) 2✅ (bots on ~every PR) 3✅ (unique — adversarial-review is outbound, this is inbound) 4⚠️ (judgment-heavy discipline skill, like grill-me) 5✅ 6✅.

### Approval
- Decision: ✅ Approved (user chose "Portar receiving-code-review (Recomendado)").
- Adapted from obra/superpowers `receiving-code-review` (MIT) → PBP conventions.

### Implementation
- Created: .claude/skills/receiving-code-review/SKILL.md (gitignored, personal).
- Frontmatter: name/description/allowed-tools/disable-model-invocation. Prose style (house convention, not kanji template). Validation + Kaizen sections added.
- Wired into Skill Router (CLAUDE.local.md, Fase del trabajo table): trigger "llega feedback de review".

### Notes
- Discipline/judgment-heavy skill — skill-creator nominally discourages judgment-heavy for *automation* skills, but PBP accepts discipline skills (grill-me, adversarial-review are precedent).
- Deferred (not created): verification-before-completion — overlaps bg-job "sanity check before result:" + `verify` builtin; low marginal value.
