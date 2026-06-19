# Migration Skill — Kaizen Log

Archived from SKILL.md inline Kaizen block. Run `/kaizen` to add new entries here; do NOT self-edit SKILL.md mid-execution.

---

<!-- Kaizen: 2026-05-22 - User correction -->
**Rule: Respect approved scope before a migration/data change makes a destructive step a default action.**
- Why: In CORE-624 I nearly enforced faves/user_stats deletion alongside the link cleanup; the user caught that Erick had scoped those tables out — the exact scope creep (L3) the TRIAGE-10 lessons doc flags.
- How to apply: Before a data migration deletes from a table by default, re-read the approval record ("Out of scope / Pendiente / cleanup separado"). If out of scope: leave it out or make it strictly opt-in pending separate sign-off. Distinguish integrity consequences of an approved action (touch/reindex) from new destructive ops on other tables.
- Source: User correction on 2026-05-22. See `memory/feedback_respect_approved_scope.md`.

---

<!-- Kaizen: 2026-06-10 — Replace PostgreSQL-only index advice with MySQL/InnoDB online DDL (Fable audit Tier 1') -->
- Removed `algorithm: :concurrently` + `disable_ddl_transaction!` guidance — PostgreSQL-only; raises ArgumentError on this MySQL 8.0 codebase (mysql2 gem verified in Gemfile line 258).
- Replaced with InnoDB online-DDL guidance: ADD INDEX is INPLACE/LOCK=NONE by default; real risks are ALGORITHM=COPY ops (column type/charset changes) on large tables → pt-online-schema-change/gh-ost or maintenance window.
- Lesson: load-bearing commands must be validated against THIS stack, not copied from generic Rails guides.

---

<!-- Kaizen: 2026-06-10 — ClickHouse MCP tool name: run_select_query → run_query (residue cleanup, Fable audit Tier 2') -->
- Updated ClickHouse MCP tool name from `mcp__clickhouse__run_select_query` to `mcp__clickhouse__run_query` in frontmatter allowed-tools.
- Lesson: verify MCP tool names against the system-reminder tool list, not from memory.

---

<!-- Kaizen: 2026-06-15 — Correctness fix: disable_ddl_transaction! comment + broken pointer (post-optimize cleanup) -->
- FIX 1 (line ~146): Inline comment read "Required when mixing DDL + long-running DML" but the GOOD example beneath it has zero DDL — only batched `update_all`. A reader doing a pure-DML batched backfill could conclude the directive is irrelevant and omit it, wrapping all batched writes in one implicit transaction (long-held write locks). Fixed comment to "Prevents Rails from wrapping the ENTIRE migration in one transaction — required for batched DML backfills (avoids long-held write locks across batches), not just when mixing DDL". Also broadened the follow-on prose paragraph from "DDL + batched DML OR ALGORITHM=INPLACE" to include **any** migration that must not run in a single transaction.
- FIX 2 (line ~206): Pointer said "For the full canonical list see docs/development/package-conventions.md or the packwerk skill." Verified: neither file contains a per-pack prefix table (no org_/orgs_ mapping). The pointer was misleading — readers following it find general naming conventions, not the prefix table. Fixed to label THIS table as the primary source and rescope the pointer to "general naming conventions".
- Lesson: pointer claims ("full canonical list") must be verified at target before shipping; prose comments inside code blocks must match the actual code example, not a generalized pattern.

<!-- Kaizen: 2026-06-15 — Correctness fixes (optimize-skill plan) -->
- Fixed orgs pack table prefix: `orgs_` → `org_` (zero `orgs_` tables in live repo; all use `org_` prefix e.g. org_roles, org_audit_logs). Labeled the table non-exhaustive with pointer to package-conventions.md.
- Added `strong_migrations` absence note to preamble: manual safety emphasis is deliberate, not an omission.
- Augmented Step 6 batched backfill with `disable_ddl_transaction!` + `sleep` throttle — matching the repo's own pattern (6 real usages) and preventing replication lag on large tables.
- Added `algorithm: :copy` footgun to CRITICAL RULE 4: unlike `:concurrently` (ArgumentError), `:copy` silently forces ALGORITHM=COPY blocking all writes.
- Fixed Step 3 and Example: removed incorrect claim that `disable_ddl_transaction!` is "not valid on MySQL" — it IS valid and used in this repo; only `:concurrently` is invalid.
- Source: skills-audit optimize-skill plan 2026-06-15.

<!-- Kaizen: 2026-06-14 — Audit cleanup (skills-audit/audit-2026-06-13.md) -->
- Updated migration count from stale "852+" to "1029+" (935 main + 94 packs, verified by find).
- Archived inline Kaizen log to this sibling file; removed self-edit-via-Edit instruction from SKILL.md body (anti-pattern per audit cross-cutting theme #1).
