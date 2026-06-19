# Architect Skill — Kaizen Log

> "Every day we must improve" — 改善
>
> Archived continuous-improvement history relocated out of `SKILL.md` to keep the
> live body under the 500-line ceiling (matches sibling convention:
> query-analyzer / multi-tenancy / memberships / debug all keep Kaizen here).

**While executing this skill**, if you discover a new architecture pattern, a missing
decision criterion, or a better ClickHouse query: (1) finish the current architecture
review first, (2) append an entry here in the format `<!-- Kaizen: YYYY-MM-DD --> …`.
Do NOT inline Kaizen entries back into `SKILL.md`.

---

<!-- Kaizen: 2026-01-31 - MCP Tools Integration -->
**Issue**: Step 3 didn't mention MCP tools for ClickHouse access, assumed docker-compose
**Root Cause**: Skill tried `docker compose exec clickhouse` first, failed, then remembered MCP exists
**Fix Applied**:
- Added MCP tools section at START of Step 3 (before SQL examples)
- Listed available MCP tools: clickhouse, honeybadger, opensearch
- Made MCP PRIMARY method, docker FALLBACK only
- Updated examples to show `mcp__clickhouse__run_query` usage

**Impact**: High (affects all /architect runs that need production data)
**Effort**: Low (5-minute documentation update)
**ROI**: 3.0 (Never fails to access ClickHouse, more reliable)

**Lesson Learned**: When MCP tools are available, they should be mentioned FIRST in any data access steps, not as fallback. Pattern applies to: /debug, /performance, /memberships, /code-review skills.

<!-- Kaizen: 2026-05-22 - User correction -->
- Rule: Respect approved scope before enforcing a destructive step (DELETE/cleanup) — never design one as a default/enforced behavior if the ticket marked it out-of-scope. Approval of X (e.g. links) ≠ approval to delete other tables.
- Why: In CORE-624 I nearly designed faves/user_stats deletion into the engine as an enforced default; the user caught that Erick had scoped those tables out — the exact scope creep (L3) I had criticized in TRIAGE-10.
- How to apply: When designing, re-read the approval record ("Out of scope / Pendiente / cleanup separado") before adding a destructive step as default/enforced. If out of scope: leave it out or strictly opt-in pending separate sign-off. Distinguish integrity consequences of an approved action (touch/reindex) from new destructive ops on other tables.
- Source: User correction on 2026-05-22. See `~/.claude/projects/-Users-leon-workspace-pbp-platform/memory/feedback_respect_approved_scope.md`.

<!-- Kaizen: 2026-05-25 - User correction -->
- Rule: When deciding "where code/docs live", classify team-shared vs personal FIRST. Personal/local files (linked from `CLAUDE.local.md`, workflow notes, ticket research) NEVER go in `docs/` (committed); they go to gitignored locations.
- Why: While extracting reference docs out of `CLAUDE.local.md`, I placed them in `docs/development/` (committed) — personal notes would have reached the team repo. User: "si son local no deben estar donde es la doc de todo el equipo".
- How to apply: For any file-location decision, run `git check-ignore <path>` to confirm intent. In this repo: `docs/` = team/committed; `investigations/` + `.claude/` = personal/excluded; add new excluded paths to `.git/info/exclude` (local), NOT `.gitignore` (team).
- Source: User correction on 2026-05-25. See `~/.claude/projects/-Users-leon-workspace-pbp-platform/memory/feedback_personal_files_excluded_location.md`.

<!-- Kaizen: 2026-06-05 - User correction -->
- Rule: When grounding a design in library/API docs, a NEGATIVE result ("the SDK has no X") is LOW-CONFIDENCE. Confirm against the authoritative structural source (Context7 dataclass/signature dump, or the reference/config page) before designing around the absence; an independent auditor contradicting a negative is high-signal.
- Why: A docs-research agent over-trusts the first page; a negative is unfalsifiable from one search. `max_budget_usd` was called non-existent (wrong SDK pages searched) but the Context7 dataclass showed it exists — nearly shipped a design that self-tracked cost instead of using the native cap.
- How to apply: For any design-affecting "X doesn't exist", run a targeted Context7 query for the exact type/dataclass/signature first; prefer a second independent check before committing the design.
- Source: User correction on 2026-06-05. See `~/.claude/projects/-Users-leon-workspace-pbp-platform/memory/feedback_negative_research_result_low_confidence.md`.

<!-- Kaizen: 2026-06-10 — MCP tool-name + org sweep (Fable audit Tier 2') -->
- Updated stale MCP tool names to the current environment (ClickHouse run_select_query → run_query).
- Removed references to nonexistent server: mcp__mermaid__* (replaced with text note in MCP Integrations section).
- Fixed authorization guidance: replaced Pundit with the actual gem (`action_policy`), updated example to resolve `action_policy`, corrected policy location to `packs/orgs/app/policies/` (`Orgs::BasePolicy`) and noted `app/policies/` is nearly empty.

<!-- Kaizen: 2026-06-10 — Lateral propagation fix: AuthorizedController (fictional) replaced with ApplicationController (real, verified ls app/controllers/); migration count instruction de-hardcoded to "run ls db/migrate | wc -l" (live count 935 as of 2026-06-15); internal_backend slice added to policy guidance: packs/internal_backend/app/policies/internal/ (verified ls). Fable re-audit: lateral propagation. -->

<!-- kaizen 2026-06-09: "implement the plan" = classify by executor first -->
When the user says "implement the plan / do it" over a plan, run a CLASSIFICATION pass before any coding: tag each item {me-now / user-interactive-action / external-sign-off-gated / no-op}. Adoption/meta/strategy plans often have little-to-no code-for-me — do only the me-now subset (gitignored prep), hand the user their commands, DRAFT (never auto-send/commit) gated items, and name no-ops as done-by-decision. Do not fabricate busywork or cross a sign-off/commit/destructive gate. See memory feedback_implement_plan_classify_by_executor.

<!-- Kaizen: 2026-06-13 - User correction (coordinator delegates investigation) -->
- Rule: When `/architect` runs under an `/orchestrate` coordinator, the coordinator does NOT do the research/investigation itself — it dispatches it (architect as a worker/analyst, or `Agent(Explore)` for searches). The coordinator only reads trivially to plan the dispatch.
- Why: pure-coordinator contract — the coordinator orchestrates, never does real work (no Bash/edits/investigation in-thread).
- Source: User correction on 2026-06-13. See `~/.claude/projects/-Users-leon-workspace-pbp-platform/memory/feedback_coordinator_delegates_all_work.md`.

<!-- Kaizen: 2026-06-15 — /optimize-skill pass (Fable worker) -->
- Relocated the inline Kaizen history (was SKILL.md L475-537) + the "Examples → Example 1: Push Notifications" worked example (was L414-465) out of the body into this file and `reference/examples.md`. Body dropped from 537 → under the 500 ceiling.
- Corrected the stale 2026-01-31 entry: `mcp__clickhouse__run_select_query` → `run_query` (the tool was renamed 2026-06-10; the stale string survived only inside the older Kaizen block, a self-contradiction). `run_select_query` no longer appears anywhere in the live body.
- Densified body: dropped the duplicated Config-Priority banner (project-wide rule stated globally), collapsed the 6-box ASCII decision-process flow to a one-line ordered list, condensed When-to-Use / Philosophy prose, and collapsed the duplicated MCP tool list (already in allowed-tools frontmatter) + the OpenSpec ≥2 scoring list (already in CLAUDE.local.md) to pointers.
- Kept IN the body (decision logic, not history): "Plan Self-Check: Placeholder Anti-Patterns".

<!-- Kaizen: 2026-06-15 — Fix allowed-tools / body mismatch -->
- **Issue**: Body (line 88) mentioned `mcp__honeybadger__*` and `mcp__opensearch__*` for production grounding queries, but neither server was listed in the frontmatter `allowed-tools`. The skill would fail to invoke those tools at runtime.
- **Root Cause**: The 2026-06-15 optimize-skill pass densified the body correctly but did not reconcile the frontmatter grant list, leaving a dangling body reference.
- **Fix Applied**: Added `mcp__honeybadger__list_faults`, `mcp__honeybadger__get_fault`, and `mcp__opensearch__SearchIndexTool` to `allowed-tools`. Specific tool names used (not wildcards) matching the pattern from `memberships/SKILL.md` (honeybadger) and `performance/SKILL.md` (opensearch). Canonical names verified via grep across sibling skills.
- **Invariant enforced**: Every MCP tool NAME in the body must appear in `allowed-tools`. Body mentions ⊆ frontmatter grants. Remove body mention OR add grant — no dangling references.
- **Impact**: Medium (architect runs that needed error/log context were silently ungranted).
- **Effort**: Low (one-line frontmatter edit + this log entry).

<!-- Kaizen: 2026-06-15 - User correction (personal adoptions go in CLAUDE.local.md, not committed team files) -->
- Rule: when an architecture/plan ADOPTS something from a personal spike/experiment (a convention, rule, or reference doc), default its location to `CLAUDE.local.md` or other gitignored places (`investigations/`, `.claude/`) — NEVER committed team files. The committed surface is not only `docs/`: **`CLAUDE.md` itself is team-committed too.**
- Why: writing a personal experiment into committed team config imposes it on the whole team prematurely and pollutes shared config; `CLAUDE.local.md` is the personal override surface (gitignored).
- How to apply: when the design proposes WHERE an adopted artifact lives, classify team-shared vs personal and run `git check-ignore <path>` before committing to a location; personal → `CLAUDE.local.md`. Promote to `CLAUDE.md`/`docs/` only when it is an agreed team standard. 2nd occurrence (also 2026-05-25) → systemic.
- Source: User correction on 2026-06-15 (ponytail spike adoption). See `memory/feedback_personal_files_excluded_location.md`.
