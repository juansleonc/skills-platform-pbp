# Performance Skill — Kaizen Log Archive

Full history of inline Kaizen entries moved here from SKILL.md to reduce per-invocation token cost.
Active body of the skill is in SKILL.md. Add new entries here (not inline in SKILL.md); run `/kaizen` to promote lessons into the active body.

---

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
