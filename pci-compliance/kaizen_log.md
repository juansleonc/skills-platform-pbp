# PCI Compliance Skill — Kaizen Log

> Archived from SKILL.md on 2026-06-14. Active lessons have been promoted into the skill body.
> New improvements: append here with `<!-- Kaizen: YYYY-MM-DD -->` format, then promote to SKILL.md body when stable.

<!-- Kaizen: 2026-06-10 — MCP tool-name + org sweep (Fable audit Tier 2') -->
- Updated stale MCP tool names: ClickHouse run_select_query → run_query.
- Removed nonexistent server: mcp__stripe__* (no Stripe MCP server in this environment).
- Fixed ClickHouse verification SQL: replaced `REGEXP` with `match()` (ClickHouse RE2 syntax); added `FINAL` to all count() queries on the `payments` table (ReplacingMergeTree — plain count() inflates results ~20×); added caveat: "Verify column names against db/structure.sql before running — do not assume card_number/gateway/notes/token exist."

<!-- Kaizen: 2026-06-10 -->
**Correction: gateway table had wrong entries; loop was misaligned**

**What was wrong:**
1. `luka_pay` listed as a gateway — it is NOT. It is a separate implementation at `app/services/payments/lukapay/` that does not follow the gateway pattern. Listing it causes audit loops to look for `app/services/payment_service/gateway/luka_pay/` which does not exist.
2. `xendit` was missing from the table despite having a full gateway implementation at `app/services/payment_service/gateway/xendit/` (default currency IDR, supports PHP/THB/VND/MYR/USD per xendit/base.rb).
3. `mitec` region was listed as "Brazil" — it is a Mexican processor (GetNet MEX). Endpoint domains are `mitec.com.mx`; error messages say "GetNet (MEX)".
4. The gateway loop included `luka_pay` (non-existent directory) and omitted `xendit`.

**What was corrected:**
- Gateway table now lists exactly the 14 directories found in `app/services/payment_service/gateway/`.
- Added note about `lukapay` being a separate non-gateway implementation at `app/services/payments/lukapay/`.
- `xendit` added with correct region (Indonesia/Philippines, default IDR per xendit/base.rb:41).
- `mitec` region corrected to Mexico.
- Gateway loop updated to match real directory names (alphabetical order).

**Lesson**: the gateway list must be generated from `ls app/services/payment_service/gateway/` — never hand-maintained. Any discrepancy between the table and that directory means either a new gateway was added without updating the skill, or an entry was fabricated.

<!-- Kaizen: 2026-06-10 — ClickHouse SQL run-test pass (Fable re-audit theme: CH SQL was never executed) -->
- Removed queries on `card_number`, `notes`, and `token` columns (verified absent in production ClickHouse); replaced with `meta` + `match()` for free-text PAN scan and `last_four_card_digits`/`card_connect_token`/`stripe_token_id` for tokenization coverage.
- Fixed FINAL placement: removed `count(*) FINAL` in SELECT list; FINAL now appears after the table reference — `FROM pbp_productionDB_optimized.payments FINAL`.
- Replaced "Verify column names against db/structure.sql" caveat with verified column list stamped 2026-06-10.
- Fixed all `app/adapters/` grep paths to `app/services/payment_service/gateway/` — `app/adapters/` contains only patch/ultra/utm adapters, no per-gateway payment code.
- Ground truth: payments columns + table list verified against production ClickHouse by the coordinator on 2026-06-10; `system.query_log` is not accessible in this environment.
