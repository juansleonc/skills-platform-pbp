# Query Analyzer — Kaizen Log

> Archived from SKILL.md to keep the active skill lean. Lessons promoted into SKILL.md body are noted inline.

<!-- Kaizen: 2026-06-02 - User correction -->
- Rule: ALWAYS use `FINAL` (or `argMax(col, updated_at)` dedup) on ANY ClickHouse `*ReplacingMergeTree` table before `count()`/`GROUP BY`. Verify the engine first: `SELECT engine FROM system.tables WHERE database=… AND name=…`. Apply `FINAL` to EVERY joined ReplacingMergeTree table whose columns you filter on (syntax: `FROM db.table AS alias FINAL`).
- Why: Without `FINAL`, an UPDATEd row's superseded versions are still physically present and get counted — inflating results (CORE-639 sweep: 122,776 vs deduped-truth 5,831, ~20×, with 0h replica lag → pure version-duplication, not staleness). Nearly drove a wrong operational decision (~266 facilities vs real ~43).
- How to apply: Sanity-gate `count()` vs `count() FINAL` — if they differ materially you MUST use FINAL. Any CH-derived "what remains / how many pending" magnitude must be reconciled against the authoritative live source (rake DRY_RUN / MySQL) before being reported. CH = screen; rake/MySQL = truth.
- Source: User correction on 2026-06-02. See `memory/feedback_clickhouse_final_dedup.md`.
- Status: **PROMOTED** — CRITICAL rule #6 in SKILL.md + FINAL on all SQL examples + Step 4 warning.

<!-- Kaizen: 2026-06-10 — Add FINAL rule for ReplacingMergeTree tables -->
- Added CRITICAL rule #6: all ClickHouse queries on application *ReplacingMergeTree tables require `FINAL`. Without it, count() inflates up to ~20× due to superseded row-versions.
- Added a Step 4 warning block to surface the rule at the point of use.
- Source: memory/feedback_clickhouse_final_dedup.md + QA audit finding (2026-06-10).
- Status: **PROMOTED** — already live in SKILL.md.

<!-- Kaizen: 2026-06-10 — ClickHouse MCP tool name: run_select_query → run_query (residue cleanup, Fable audit Tier 2') -->
- Status: **PROMOTED** — allowed-tools and body use `mcp__clickhouse__run_query`.

<!-- Kaizen: 2026-06-10 — Regenerate examples vs real schema + remove unrunnable ClickHouse queries (Fable re-audit) -->
- Fixed Pattern 2 / report examples: reservations has court_id (no facility_id); memberships has owner_id/aasm_state (no user_id/active). Verified vs db/structure.sql.
- Deleted all system.query_log queries — the table is not accessible in this ClickHouse Cloud environment (coordinator-verified 2026-06-10) and would log CH queries, not MySQL. ClickHouse usage scoped to replicated app tables with FINAL for volume context.
- Lesson: every SQL block in a skill must be runnable against the real environment, not copied from generic ClickHouse docs.
- Status: **PROMOTED** — real schema columns + NOTE blocks in SKILL.md.
