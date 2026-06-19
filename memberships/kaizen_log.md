# Memberships — Kaizen Log

> Archived from SKILL.md to keep the active skill lean. Lessons promoted into the
> SKILL.md body are noted inline. Format: `<!-- Kaizen: YYYY-MM-DD --> note`.

<!-- Kaizen: 2026-01-23 - Manual MembershipPayment Fix Pattern -->
> Manual fix procedures moved to shared reference. See
> [shared/troubleshooting/membership-payment-fixes.md](../shared/troubleshooting/membership-payment-fixes.md)
> for the full orphaned-payment fix pattern (investigation SQL, direct-SQL INSERT, common pitfalls).

<!-- Kaizen: 2026-06-10 — Merged membership-validate into memberships (superpowers-spike pruning pass) -->
Merged all unique content from the `/membership-validate` skill into this canonical `/memberships` skill. Sections added: Membership Lifecycle diagram, Validation Areas (State Machine Transitions, Proration Calculations with formula, Family Membership Rules, Freeze/Pause Rules), extended ClickHouse queries, and extended checklist sections. The `membership-validate` skill directory was deleted. The Skill Router in `CLAUDE.local.md` was updated from `/memberships + /membership-validate` to just `/memberships`. References in `orchestrate/SKILL.md` updated. Trigger: superpowers-spike 2026-06-10 pruning pass — duplicate skill with byte-identical description and overlapping content.

<!-- Kaizen: 2026-06-10 — Rewrite body against the real schema (Fable audit Tier 1') -->
- Replaced fabricated columns (`status`/`expires_at`/`belongs_to :facility`/`auto_renew`/`interval`) with the real ones (`aasm_state` with default `'idle'`, `current_period_end_at`, facility via `membership_plan.owner_facility`, `mpp.automatic_renewal` + `mpp.interval_unit`) — the body contradicted both the real model and this skill's own 2026-01-23 Kaizen entry.
- Rewrote the Key Models section with the actual associations (`belongs_to :owner`, `belongs_to :membership_plan_price`, `has_one :membership_plan through:`, `has_many :facilities through:`, `delegate :owner_facility, to: :membership_plan`) and added a verified column table.
- Rewrote the Membership Lifecycle diagram with the five real AASM states: `idle` (initial/default), `active`, `paused`, `cancelled`, `failed`. Removed fabricated `pending_payment` and `expired` states.
- Added AASM Events Summary table with all real transitions (start!/pause!/continue!/resume!/cancel!/cancel_immediately!/renew!/recover!/fail!).
- Corrected Step 2 (auto-renewal) to use `mpp.automatic_renewal` instead of fabricated `membership.auto_renew`; `current_period_end_at` instead of `expires_at`; `aasm_state` instead of `status`.
- Corrected Step 3 (period extension) to use `current_period_end_at` and explain that interval lives on `mpp` (MembershipPlanPrice), not Membership.
- Corrected Step 5 (cancellation) to use AASM events (`cancel!`/`cancel_immediately!`) instead of `update!(status: 'cancelled', auto_renew: false)`.
- Corrected Common Bugs section to use real column/method names.
- Corrected Core Logic checklist to remove `auto_renew` and add guidance on real column names.
- Added `FINAL` to all ClickHouse queries on `memberships` and `membership_payments` + the ReplacingMergeTree warning ("counts inflate ~20×").
- Replaced ClickHouse queries that used fabricated columns (`status`, `expires_at`, `facility_id`, `auto_renew`, `interval`, `next_payment_date`) with real column names from the verified schema.
- Lesson: when a skill's Kaizen appendix and body disagree, the verified one wins; regenerate schema claims from the model/structure.sql, never from memory.

<!-- Kaizen: 2026-06-10 — ClickHouse MCP tool name: run_select_query → run_query (residue cleanup, Fable audit Tier 2') -->
- Status: PROMOTED — `allowed-tools` and body use `mcp__clickhouse__run_query`.

<!-- Kaizen: 2026-06-14 — /optimize-skill restructure pass (body 668 → <500) -->
- Relocated L3 material to bundled `reference/*` files with one-line body pointers (OPTIMIZE ≠ DELETE — no capability removed):
  - ASCII lifecycle diagram → `reference/lifecycle.md` (canonical transitions stay in the body's AASM Events Summary table).
  - Full ClickHouse query catalog (Step 7) → `reference/clickhouse-queries.md` (kept the FINAL/ReplacingMergeTree warning + 1 canonical query in the body).
  - Proration formula + cancellation pseudo-code → `reference/proration.md`, now GROUNDED against the real `MembershipPlanPrice#prorated_price_by_date` and the illustrative generic formula explicitly labelled ILLUSTRATIVE (flagged that `current_period_start` does NOT exist on memberships).
  - Output/report template + worked example → `reference/audit-template.md`.
  - Kaizen change-log → this `kaizen_log.md` (sibling-file convention, matching query-analyzer/code-review).
- Dedup: collapsed THREE copies of the state transitions to ONE (AASM Events Summary table); deleted the redundant Validation-Areas §1 transitions table and the in-body ASCII diagram. Collapsed Config Priority + Shared References banners to a single pointer line. Consolidated the repeated "wrong-vs-right column" lists into one table near Key Models.
- Densify: collapsed the 7-section end-of-skill checklist to the highest-signal asserts; converted the per-Validation-Area grep recipes into a single grep table; trimmed "Why This Matters" to one line.
- Correctness fix: `MembershipPlanPrice#interval_unit` documented as `week/month/year (verify)` was wrong — verified live enum is `{ day: 0, week: 1, month: 2, year: 3 }` (app/models/membership_plan_price.rb:62). Dropped the `(verify)` hedge and added the missing `day` value.
- Preserved verbatim (NOT defects): all AASM states/events, scopes (`valid_memberships`/`invalid_memberships`/`non_cancelled`), the `mpp` alias, `next_current_period_end_at`, `MembershipPlanPrice.automatic_renewal`, the scheduler key/description, and the `mcp__clickhouse__run_query` tool name. The 2026-06-10 schema rewrite was kept intact.

<!-- Kaizen: 2026-06-14 — Post-optimize correctness patch (3 targeted fixes) -->
- **FIX 1 — lifecycle diagram arrowhead (reference/lifecycle.md):** `▲` on the vertical connector between the `idle` and `failed` boxes pointed upward toward `idle`, implying a nonexistent `failed → idle` transition. No such AASM event exists. Changed `▲` to `│` (plain pipe). The surrounding text (`fail! also from active/paused/cancelled`) already conveys directionality via labels; the arrowhead was purely misleading. Verdict: real defect, fixed.
- **FIX 2 — Domain Overview table missing Daily plan type (SKILL.md):** The table listed Weekly/Monthly/Annual/Trial but omitted Daily, despite `interval_unit` enum including `day: 0` (confirmed in 2026-06-14 optimize pass). Added `Daily | 1 day | Yes | interval_unit: day (enum day: 0)` as the first row. Verdict: real gap, fixed.
- **FIX 3 — dead `current_date` parameter advisory (reference/proration.md):** `MembershipPlanPrice#prorated_price_by_date(current_date = Date.today)` silently overwrites the caller-supplied argument with `facility.current_time` on the first line of the body. Added a blockquote advisory above the code snippet and annotated the overwrite line with `⚠️ overwrites the parameter`. Verdict: real footgun, documented.
