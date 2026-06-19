# factory-check — Kaizen Log

> Archived from SKILL.md on 2026-06-14 per skills-audit cleanup.
> Active body is in SKILL.md. Add new entries here.

---

<!-- Kaizen: 2026-01-31 - Code Simplifier Integration (Tier 3: OPTIONAL) -->
## 2026-01-31 — AI-Powered Optimization Option

**What Changed:**
- Added `Agent` to allowed-tools in frontmatter (dispatch via `subagent_type: "code-simplifier"`)
- Added reference to code-simplifier-integration.md in Shared References
- Added Step 4: Auto-Optimize with AI (OPTIONAL) using Tier 3 pattern
- Renamed old Step 4 → Step 5, old Step 5 → Step 6
- Added comparison table: code-simplifier vs FactoryChecker
- User explicitly chooses optimization approach

**Why:**
- FactoryChecker is fast but rule-based (regex + AST)
- code-simplifier is slower but more intelligent (understands semantics)
- Some specs need comprehensive optimization (setup, contexts, let/let!)
- Users want choice: speed (FactoryChecker) vs intelligence (code-simplifier)
- Tier 3 pattern (OPTIONAL) perfect for "choose your tool" scenarios

**Impact:**
- Users have 2 optimization approaches:
  - **FactoryChecker** (Step 5): Fast (~1s), simple factory swaps
  - **code-simplifier** (Step 4): Slower (~10s), comprehensive optimization
- Complex specs can use code-simplifier for deeper optimization
- Simple specs can skip to FactoryChecker for quick fixes
- ROI: 1.0 (Medium impact - adds flexibility, Medium effort - user approval flow)

**Example:**
```
Complex spec with setup issues:
  User: "yes" to code-simplifier
  Result: Factories + setup + contexts optimized

Simple spec, just 3 factory swaps:
  User: "no" to code-simplifier
  Uses: FactoryChecker (faster, focused)
```

---

<!-- Kaizen: 2026-06-14 - Skills audit reconciliation -->
## 2026-06-14 — Allowed-tools / Task discrepancy reconciled

**Finding:** Kaizen entry above originally claimed "Added `Task` to allowed-tools in frontmatter."
This was incorrect. The integration dispatches via the `Agent` tool (`subagent_type: "code-simplifier"`),
not via the `Task` tool. `Agent` was the correct tool to add, and it was always present in the
frontmatter (`[Bash, Read, Grep, Glob, Agent, Edit]`). `Task` was never added and is not needed.

**Action taken:** Corrected the claim in the archived entry above (Task → Agent) and replaced the
inline Kaizen block in SKILL.md with a pointer to this log file.

---

<!-- Kaizen: 2026-06-15 - optimize-skill correctness + densify pass -->
## 2026-06-15 — Correctness fix + densify (optimize-skill pass)

**What Changed:**
- Replaced stale Implementation Notes stub (16 lines with placeholder class + "Create this helper file" instruction) with a 1-line verified pointer to `lib/factory_checker.rb`. File exists (9461 bytes, 14 methods) and is fully functional — no setup needed.
- Collapsed Step 4 (code-simplifier) from 40 lines re-listing benefits into a 4-line trigger that delegates to `code-simplifier-integration.md` (the single source of truth).
- Consolidated "Metrics" + "Report Format" sections (30 lines, near-duplicate of Example Run) into a 1-line note pointing back to the Example Run.

**Why:**
- `lib/factory_checker.rb` already existed and was fully implemented; the old "Create this file" instruction was misleading and could cause confusion.
- Step 4's benefit list was duplicating `code-simplifier-integration.md` (drifted copy risk).
- The Report Format block was a slightly-different-file-count clone of Example Run; maintaining two was wasteful.

**Impact:**
- Body: 410 → 318 lines (~22% smaller, no capability lost).
- All decision logic (CRITICAL RULES, Quick Decision Tree, Detection Patterns, Auto-Fix Safety) preserved in body.
- All worked examples (Patterns 1-5) preserved in body (body still under 500-line ceiling; relocation deferred per plan).
- Frontmatter and all 4 shared references verified intact.
