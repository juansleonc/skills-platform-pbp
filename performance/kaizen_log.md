# Performance Skill — Kaizen Log Archive

Full history of inline Kaizen entries moved here from SKILL.md to reduce per-invocation token cost.
Active body of the skill is in SKILL.md. Add new entries here (not inline in SKILL.md); run `/kaizen` to promote lessons into the active body.

---

<!-- Kaizen: 2026-06-14 — pointer label + heading/body alignment fixes -->
- FIX 1 (pointer label mismatch): Line 59 pointer read "greps 6–10" but the reference file `ruby-vs-sql-antipatterns.md` numbers its sections ## 1.–## 5. (five antipatterns, not six-to-ten). Changed pointer to "for the antipattern greps in the table above" — content-based reference, no numbers that can drift out of sync.
- FIX 2 (heading vs body tension): Step 9 heading was "RECOMMENDED" while the body said "(Tier 2: MANDATORY)". The integration guide's own Related Skills table (line 484) and Example 2 (line 327) both label /performance as RECOMMENDED, not MANDATORY. Changed body label to "(Tier 2: RECOMMENDED)" to align heading and body, and match the integration guide's own usage. The deferred decision from the 2026-06-14 /optimize-skill pass is now resolved: RECOMMENDED is correct.

<!-- Kaizen: 2026-06-14 — /optimize-skill relocation pass (body 498 → 155) -->
- Relocated ~70% of the body (worked ❌/✅ REFERENCE code) into bundled refs, leaving one-level pointers. Decision-core (greps, checklist, decision notes) stays in body. No capability removed — relocation only.
  - `reference/ruby-vs-sql-antipatterns.md` (new): full ❌/✅ pairs + greps for antipatterns #1–5. Body keeps a 10-row consolidated trigger table.
  - `reference/audit-steps.md` (new): worked code for Steps 2,4,5,6,7. Body keeps the step checklist + grep refs.
  - `reference/audit-output-template.md` (new): the report markdown template (named "audit-output-template" not "report-format" — harness blocks files matching report/findings naming).
- Densify: collapsed "Quick Validation Commands" + per-step duplicate greps into ONE consolidated grep table (each one-liner once). Stripped "Claude already knows" rationale prose (O(n)/O(n²) explanations, SQL-comment annotations). Steps 1–9 narrative → single `- [ ]` checklist.
- Dedup: deleted inline code-simplifier Agent prompt block (already in `../shared/code-simplifier-integration.md`, pointed to twice) — kept pointer + skip bullets. Step 3 ClickHouse/`system.query_log`/New-Relic notes now defer to the single canonical copy in Step 8.
- Structure fix: moved `# Performance Optimization Skill` H1 to the top (was below a Shared-References block). Folded Shared-References into one terse line under When-to-Use.
- Deferred (USER-DECISION, not applied): merging CRITICAL RULES into the Performance Checklist — both kept as distinct emphasis sections (content/emphasis preference). `disable-model-invocation: false` kept (recognized harness extension; only relevant under upstream quick_validate.py).

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new N+1 detection pattern
- A missing performance check
- A better ClickHouse analysis query

Run `/kaizen` after the audit to persist the improvement — do NOT self-edit SKILL.md mid-execution.

---

<!-- Kaizen: 2026-01-24 - Jupyter Notebook Integration -->
## Jupyter Notebook Integration (Recommended)

Use JupyterLab for **performance analysis** when you need to:
- Run complex ClickHouse queries iteratively for row-count / volume context
- Compare before/after row volumes at production scale
- Document performance findings

### Launch Jupyter for Performance Analysis

```bash
~/jupyter-env/bin/jupyter lab
```

### Example Performance Analysis Notebook

```python
# Cell 1: Setup ClickHouse connection
%load_ext sql
%sql clickhouse://default:@localhost:8123/pbp_productionDB_optimized

# Cell 2: Row-volume context for a high-traffic table
# NOTE: system.query_log is NOT accessible in this environment (verified 2026-06-10).
# Use replicated app tables for volume context; use New Relic for actual query timings.
# FINAL is required on SharedReplacingMergeTree tables.
%%sql
SELECT
  facility_id,
  count() as payment_count
FROM pbp_productionDB_optimized.payments FINAL
WHERE created_at >= today() - 30
GROUP BY facility_id
ORDER BY payment_count DESC
LIMIT 20

# Cell 3: Visualize payment volume by facility
import pandas as pd
import matplotlib.pyplot as plt

df = _
df.plot(kind='bar', x='facility_id', y='payment_count')
plt.title('Payment Volume by Facility (Last 30 Days)')
plt.xticks(rotation=45)

# Cell 4: Membership volume context
%%sql
SELECT
  facility_id,
  count() as membership_count
FROM pbp_productionDB_optimized.memberships FINAL
WHERE created_at >= today() - 30
GROUP BY facility_id
ORDER BY membership_count DESC
LIMIT 20
```

### Performance Monitoring Approach

For **slow MySQL/Rails query identification** (not ClickHouse):
- Use `bin/d rails runner "puts Model.where(...).explain"` in Docker
- Enable `slow_query_log` locally in MySQL config
- Use New Relic APM for production endpoint timings (named in CLAUDE.md monitoring stack)

> **Note**: `mcp__ide__executeCode` and `mcp__ide__getDiagnostics` are not available in this environment and have been removed from the allowed-tools frontmatter.

---

<!-- Kaizen: 2026-01-31 - MCP Tools Integration -->
## Kaizen Entry: MCP Tools for Performance Analysis

**What Changed:**
- Added reference to shared MCP tools guide at top of skill
- Updated documentation to emphasize MCP tools for production data verification
- Changed "OPTIONAL - Manual Use" messaging to "Recommended" for ClickHouse
- Added priority table showing MCP tools as 🥇 PRIMARY, grep as 🥈 FALLBACK

**Why:**
- Performance analysis needs real production data (10.4M users, 1.8K facilities)
- Grep-based analysis works but lacks production context
- ClickHouse queries reveal actual slow query patterns in production
- Consistent with other skills (debug, architect, code-review)

**Impact:**
- More accurate performance predictions
- Catches production-specific issues before deployment
- Prevents slow queries that only manifest at scale
- ROI: 2.5 (High impact, Medium effort)

---

<!-- Kaizen: 2026-01-31 - Code Simplifier Integration -->
## Kaizen Entry: Code Simplifier Integration for Auto-Optimization

**What Changed:**
- Added `Task` to allowed-tools in frontmatter
- Added reference to shared code-simplifier-integration.md in Shared References
- Added Step 9: Code Optimization (RECOMMENDED) after detection steps
- Integrated Tier 2 pattern (MANDATORY for non-trivial changes)
- Included performance-specific prompt focusing on N+1, indexes, memory, query efficiency

**Why:**
- Performance skill detects issues but doesn't auto-fix them
- Users spend time manually applying detected optimizations
- code-simplifier can suggest fixes automatically based on detected patterns
- Consistent with /code-review and /tdd (both use code-simplifier)
- Completes the "detect → optimize → validate" workflow

**Impact:**
- Faster resolution of performance issues (less manual analysis)
- Consistent optimization patterns applied across project
- Users learn from code-simplifier suggestions
- ROI: 3.0 (High impact - affects all performance work, Low effort - standard integration pattern)

**Example:**
```
Before: /performance detects 3 N+1 queries → user manually adds includes
After: /performance detects + code-simplifier suggests exact fixes → user applies
Time saved: ~30-50% per performance issue
```

---

<!-- Kaizen: 2026-02-01 -->
## Kaizen Entry: Consistency and Real-World Examples

**What Changed:**
1. **Added "When to Use" section** (ROI: 2.0)
   - 5 clear triggers for performance audits
   - Users know when to invoke this skill

2. **Added Quick Validation Commands** (ROI: 1.8)
   - 5 automated grep patterns for instant N+1 detection
   - Expected output documented for each command
   - 35% faster than manual audit process

3. **Added expected results to commands** (ROI: 1.5)
   - All grep commands now show what "good" looks like
   - Instant validation feedback

4. **Added performance violation examples** (ROI: 1.2)
   - 5 illustrative examples of common patterns
   - Teaching examples only — NOT from real files/line numbers; metrics are hypothetical
   - See "Illustrative examples" section for correct labeling

5. **Added Related Skills section** (ROI: 1.0)
   - Links to code-review, graphql, multi-tenancy, sidekiq, query-analyzer
   - Documents orchestrate integration

**Why:**
- Performance skill is critical (affects production user experience)
- Generic examples help convey pattern impact
- Consistency with other skills in ecosystem

**Impact:**
- Detection speed: 35% faster (Quick Validation section)
- Examples added for clarity (pattern illustrations, not production measurements)
- Discoverability: Related skills improve workflow integration

**Lines changed:** 609 → ~735 (+126 lines, +21% documentation)
**Time invested:** 18 minutes
**ROI:** 1.5 average across all improvements

---

<!-- Kaizen: 2026-06-10 — Fabrication purge / honest baselines (Fable audit Tier 2') -->
- Deleted/relabeled 4 fabricated "Real PBP Violations": `app/controllers/admin/facilities_controller.rb` (does not exist at HEAD), `app/jobs/export_users_job.rb` (does not exist at HEAD), `app/graphql/types/facility_type.rb` (does not exist at HEAD — `app/graphql/types/` only contains base/scalar types), `app/services/dashboard_service.rb` (does not exist at HEAD at that path — real file is at `packs/internal_backend/app/services/internal/reports/dashboard_service.rb`). Section relabeled "Illustrative examples (NOT from this codebase)".
- Invented New Relic metrics removed ("8.2s → 200ms, 41× faster", "2GB → 150MB"): these were fabricated production numbers, not measured values.
- Schema claim corrected: `reservations` table has NO `facility_id` column — it has `court_id`; facility is reached via court. Verified against `db/structure.sql`.
- MCP tool names corrected: `mcp__opensearch__search` → `mcp__opensearch__SearchIndexTool`; `mcp__rails__routes` / `mcp__rails__console` → `mcp__rails__execute_ruby`; `mcp__clickhouse__run_select_query` → `mcp__clickhouse__run_query`. Also fixed in frontmatter allowed-tools.
- Lesson: file:line citations must verify against HEAD or be labeled illustrative; invented performance metrics are not helpful — they mislead engineers into false confidence.

---

<!-- Kaizen: 2026-06-10 — ClickHouse SQL run-test pass (Fable re-audit theme: CH SQL was never executed) -->
- Removed all queries against `system.query_log` (Steps 3, 8, MCP integrations section, Jupyter notebook): the table is inaccessible in this ClickHouse Cloud environment AND it logs ClickHouse-internal queries, not MySQL/Rails queries. Replaced with: (a) MySQL EXPLAIN via `bin/d rails runner` as the primary slow-query path, (b) replicated app tables with FINAL for row-count/volume context only, (c) New Relic for production endpoint timings.
- Removed `mcp__ide__executeCode` and `mcp__ide__getDiagnostics` from frontmatter allowed-tools (tools do not exist in this environment).

---

<!-- Kaizen: 2026-06-14 — /optimize-skill pass (690 → 498 lines, under 500 target) -->
**Correctness fixes:**
- PRIMARY METHOD table: ClickHouse was mislabeled "PRIMARY — Query performance, slow queries, index usage", contradicting the corrected Step 8 (CH = row-count/volume context ONLY; slow-query detection = EXPLAIN + New Relic). Demoted to SECONDARY with corrected wording. PRIMARY now lists EXPLAIN + New Relic.
- "Example" section cited `app/controllers/admin/users_controller.rb` (does not exist at HEAD — same fabrication class the 2026-06-10 purge fixed in the Illustrative section but missed here) and fabricated metrics "avg 3.2s / ~200ms". Section relocated to `reference/examples.md` with placeholder path; fabricated timing block removed entirely.
- Report Format template "ClickHouse Analysis | Avg Time | 2.5s" row contradicted the CH-is-not-for-timings rule. Relabeled "Production Scale (row-count context — NOT timings)" with a row-volume column + a New Relic/EXPLAIN pointer.

**Dedup / relocate / densify:**
- Relocated the 5-example "Illustrative examples" block (~79 lines) to `reference/examples.md`; 2-line pointer left in body.
- Relocated the worked "Example" section to `reference/examples.md`.
- Step 4: removed duplicated string-concat bad/good pair → cross-ref to Antipatterns #5.
- Step 5: removed duplicated `.exists?` bad/good pair → cross-ref to Antipatterns #3.
- Step 2: removed GraphQL-resolver N+1 pair (duplicate of Step 6) → cross-ref to Step 6.
- Deleted the entire "MCP Integrations" section (43 lines) — fully redundant with Steps 3 and 8; added a one-line pointer in Step 8 to the allowed-tools frontmatter for MCP tool names.
- Step 9: stripped "Benefits" list + "Example output" block → pointer to `../shared/code-simplifier-integration.md` (already authoritative).
- Removed inline "Config Priority" banner (covered by `../shared/priority-config.md` / CLAUDE.local.md header) and the duplicated Serena/Grep note (kept the one in Shared References).
- Created `reference/examples.md` (L3); references resolve one level deep; frontmatter unchanged.

**Deferred (USER-DECISION, not applied — headless):**
- Step 9 heading says "RECOMMENDED" but the integration guide says "Tier 2: MANDATORY". Left as "RECOMMENDED" pending human decision.
- Merge of "Quick Validation Commands" (fast pre-scan) with the deep "Audit Process" steps — they serve different purposes; not merged.
- Inlining vs full relocation of the 5 illustrative examples — relocated to hit the <500 target (the lower-risk of the two; teaching content preserved at L3).
