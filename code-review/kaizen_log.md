# Code Review Skill — Kaizen Log

Archived from SKILL.md during skills audit 2026-06-14. Full entry history preserved verbatim.

---

<!-- Kaizen: 2026-01-23 -->
- Added: No ticket IDs in code comments rule (use commit message prefix instead)

<!-- Kaizen: 2026-01-24 - Jupyter Notebook Integration -->
## 📓 Jupyter Notebook for Code Review (Optional)

Use JupyterLab for **interactive production data verification** when you need to:
- Run complex verification queries iteratively
- Compare data patterns before/after code changes
- Document findings with visualizations
- Share analysis with the team

### Launch Jupyter for Code Review

```bash
~/jupyter-env/bin/jupyter lab
```

### Example Code Review Notebook

```python
# Cell 1: Setup
%load_ext sql
%sql clickhouse://default:@localhost:8123/pbp_productionDB_optimized

# Cell 2: Verify NULL handling in changed code
%%sql
SELECT
  count(*) as total,
  countIf(expires_at IS NULL) as null_expires,
  round(countIf(expires_at IS NULL) / count(*) * 100, 2) as null_pct
FROM memberships

# Cell 3: Check edge cases the code must handle
%%sql
SELECT
  status,
  count(*) as cnt,
  round(count(*) * 100.0 / sum(count(*)) OVER (), 2) as pct
FROM memberships
GROUP BY status
ORDER BY cnt DESC

# Cell 4: Verify multi-tenancy patterns
%%sql
SELECT
  facility_id,
  count(*) as records
FROM reservations
WHERE facility_id IS NULL  -- Should be 0!
```

### When to Use Jupyter vs MCP Tools

| Scenario | Recommended Tool |
|----------|------------------|
| Quick NULL check | `mcp__clickhouse__run_query` |
| Complex data analysis | Jupyter |
| Iterative query refinement | Jupyter |
| Documenting verification | Jupyter |
| Single verification query | MCP tool |

### MCP IDE Tools

> **Note (Fable re-audit 2026-06-10)**: `mcp__ide__executeCode` and `mcp__ide__getDiagnostics` are NOT available in this project's MCP configuration and have been removed from frontmatter allowed-tools. The Jupyter workflow below is for local manual use only (launch `~/jupyter-env/bin/jupyter lab` directly); do not reference these tools in code review automation.

<!-- Kaizen: 2026-01-31 - MCP Tools Integration — Promoted to MCP TOOLS table — see body. -->
- Made code-simplifier MANDATORY; priority tiers (🥇/🥈) in MCP tools table. ROI: 2.5.

<!-- Kaizen: 2026-01-22 -->
- Added: MANDATORY INTEGRATIONS table at top for visibility
- Added: "PRODUCTION DATA VERIFICATION (MANDATORY)" section with ClickHouse queries
- Enhanced: Step 7 Context7 with required queries by code type
- Enhanced: Step 8 ClickHouse with performance red flags table
- Enhanced: Step 10 code-simplifier with detailed prompt template
- Emphasis: Production data checks are MANDATORY before approving any data-related code

<!-- Kaizen: 2026-02-03 - PR #4046 Lessons Learned -->
**What Happened:**
- Code review missed 2/5 bugs found by cursor[bot] in PR #4046
- Issue #4 (Low): Teacher notification body incomplete when lesson has no attendances
- Issue #5 (Med): MembershipReminderJob missing error handling that other 2 jobs have

**Root Causes:**
1. **Edge Case Detection Gap**: No automated check for `.first&.` followed by string interpolation
2. **Cross-Job Consistency Gap**: No validation that similar jobs have consistent error handling patterns
3. **NULL Checks Not Mandatory**: Step 8 ClickHouse checks were "Recommended" not "MANDATORY"

**Improvements Applied:**
1. ✅ Added nil-safety grep patterns in Step 2 (detects `.first&.` + interpolation)
2. ✅ Added Step 5.5: Cross-Job Consistency Validation (compares error handling across similar jobs)
3. ✅ Made Step 8 ClickHouse checks MANDATORY for data operations
4. ✅ Added automated grep for unsafe safe navigation patterns

**Impact:**
- These 4 changes would have caught BOTH missed bugs automatically
- Edge case detection: grep pattern detects nil risk in string interpolations
- Consistency validation: cross-job comparison detects missing error handling
- ROI: 2.5 (High impact - prevents production bugs, Low-Med effort - automated checks)

**Lessons for Future Reviews:**
- When reviewing multiple similar files (e.g., 3 new jobs), ALWAYS check for pattern consistency
- ALWAYS grep for `.first`, `.last`, `&.` and validate nil handling in string interpolations
- Make production data validation MANDATORY, not optional

<!-- Kaizen: 2026-02-11 - PR #4109 Method Refactoring Lesson (CORE-205) — Promoted to Step 2.5 on 2026-02-11 — see body. -->
- Source: Bugbot caught missing caller update (membership_mailer.rb) for `in_pre_sale_period?` refactored from MembershipPlanPrice → Membership. Root cause: no automated grep for ALL callers of old signature. Fix = Step 2.5 Part 1 (caller consistency grep).

<!-- Kaizen: 2026-02-19 - External API Behavior Assumptions (CORE-189) — rule promoted to Step 2 "Critical Rules Check" for adapters. Incident: Patch::Contacts email filter silently ignored; Patch::Products.find returned error hash instead of raising. ROI: 3.0. -->
- Unique incident: CORE-189 Patch SDK silent-filter + error-hash (not in body text). See above entry for details.

<!-- Kaizen: 2026-02-11 - PR #4109 Nil Safety in Refactored Methods (CORE-205 Part 2) — Promoted to Step 2.5 Part 2 on 2026-02-11 — see body. -->
- Source: Same PR #4109; bugbot caught `facility.current_time` crash when `owner_facility` is nil. Root cause: Step 2.5 only verified callers, not nil-safety of the new method itself. Fix = Step 2.5 Part 2 (nil guard validation).

<!-- Kaizen: 2026-05-12 - User corrections (ENG-544) — rules promoted to Step 2 + Step 8. See body. -->
- Real-request repro before runner stubs. Findings must be in-scope (git diff) + real repro. Data manipulation repro only valid when state exists in prod (ClickHouse verify first). "Real user, real data, real client flow?" Final filter. Sources: `memory/feedback_validate_bugs_via_real_request.md`, `memory/feedback_review_scope_and_real_repro.md`.

<!-- Kaizen: 2026-05-22 - User correction — Promoted to Review Dimensions §5 (Code Quality). -->
- Destructive-op scope: approval of X ≠ approval to delete other tables. Source: `memory/feedback_respect_approved_scope.md`.

<!-- Kaizen: 2026-05-25 - User correction — Promoted to Review Dimensions §5 (Code Quality). -->
- Personal files check: newly-added files under `docs/` must be team-shared; personal = gitignored. Source: `memory/feedback_personal_files_excluded_location.md`.

<!-- Kaizen: 2026-06-05 - User correction — Promoted to Step 7 (Context7 lookup). -->
- Negative research result is LOW-CONFIDENCE; verify via Context7 dataclass dump. Incident: `max_budget_usd` falsely declared absent. Source: `memory/feedback_negative_research_result_low_confidence.md`.

<!-- Kaizen: 2026-06-10 — IDE tools removal + Kaizen dedup (Fable re-audit hygiene pass) -->
- Removed: `mcp__ide__executeCode` and `mcp__ide__getDiagnostics` from frontmatter allowed-tools (not configured in this project). Jupyter table row caveated "local only"; IDE tools section replaced with explicit unavailability note.
- Compressed Kaizen entries: 2026-01-31 (MCP priority table — in body), 2026-02-19 (External API rule — in Step 2), three 2026-05-12 (ENG-544 rules — in Steps 2/8), 2026-05-22 and 2026-05-25 (scope/personal-files — in §5), two 2026-06-05 (negative-research / review-input-bias — in Steps 7/body). Incident-unique details retained as one-liners.

<!-- Kaizen: 2026-06-10 — MCP tool-name + org sweep (Fable audit Tier 2') -->
- Updated stale MCP tool names to the current environment (ClickHouse run_select_query → run_query; Sentry sentry_list_projects → find_projects, sentry_list_issues → search_issues, sentry_get_issue → search_issue_events/get_sentry_resource; OpenSearch get_mapping → IndexMappingTool, search → SearchIndexTool; GitHub list_pull_request_files → get_pull_request_files, create_review_comment/create_review → create_pull_request_review); removed mcp__mermaid__* (nonexistent server).
- Fixed GitHub org: playbypoint → PlaybyCourt.
- Resolved internal contradiction: "Recommended" label on production data verification section vs "MANDATORY" in Step 8 — standardized to "MANDATORY for payment/financial/data-integrity changes; recommended otherwise" in both the section heading and the MCP tools priority table.
- Compressed two verbatim-duplicate Kaizen entries (CORE-205 Part 1 + Part 2, 2026-02-11) to one-line references since the full content lives in Step 2.5.

<!-- Kaizen: 2026-06-05 - User correction (review-input bias) — Promoted to Review Process. -->
- Feed reviewers raw evidence not summary (shared-premise bias). Source: `memory/feedback_review_raw_evidence_not_summary.md`.
