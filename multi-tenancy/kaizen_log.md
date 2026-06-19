# Multi-Tenancy Skill — Kaizen Log

Archived from SKILL.md on 2026-06-14. Active body is in SKILL.md.

---

<!-- Kaizen: 2026-02-01 --> ~~RETRACTED 2026-06-10 — see correction entry below~~
**~~Major clarity and validation improvements:~~**

~~1. **Added "When to Use" section** (ROI: 2.0)~~
~~2. **Added Quick Validation Commands** (ROI: 2.5)~~
~~3. **Replaced generic examples with real PBP violations** (ROI: 3.0)~~
   ~~- 5 concrete violations from actual codebase~~
   ~~- Specific file locations (checkout_service.rb, reservations_controller.rb, etc.)~~
   **RETRACTED**: `checkout_service.rb`, `app/controllers/api/reservations_controller.rb`, `app/services/payment_service.rb` at those line numbers do not exist in the codebase. The tenancy model was also wrong: `users`, `reservations`, and `memberships` do NOT have a `facility_id` column. ClickHouse queries against `users.facility_id` and `reservations.facility_id` are schema-invalid.
~~4. **Added expected results to ClickHouse queries** (ROI: 2.0)~~
~~5. **Added Related Skills section** (ROI: 1.0)~~

~~**Impact:** Violation detection 40% faster / Examples 80% clearer~~
**RETRACTED**: these metrics were based on fabricated examples and an incorrect schema model.

---

<!-- Kaizen: 2026-06-10 -->
**Correction: fabricated citations and wrong tenancy model replaced with verified facts**

**What was wrong:**
1. Step 3 "Violations Found" cited five file:line pairs that do not exist (`checkout_service.rb:45`, `api/reservations_controller.rb:23`, `payment_service.rb:67`, `membership.rb:89`). These were fabricated — never verified against the repo.
2. Step 2 "GOOD - Explicit facility_id" showed `User.where(facility_id:)` and `Reservation.where(facility_id:)` — both columns do not exist; those calls would raise `ActiveRecord::StatementInvalid`.
3. ClickHouse queries checked `users.facility_id` and grouped `reservations` by `facility_id` — schema-invalid.
4. The Example transcript referenced `app/services/checkout_service.rb` — file does not exist.

**What was corrected:**
- Added Tenancy Map table with per-model scoping paths and real file:line citations (all verified 2026-06-10).
- Step 2 examples now use schema-valid patterns only (`facility.users.find_by(...)`, `Payment.where(facility_id:)`, etc.).
- Step 3 now shows three real pattern instances (all verified 2026-06-10) with explicit caveat that pattern presence ≠ confirmed violation.
- ClickHouse queries now use `courts.facility_id` and a `JOIN courts` for reservation distribution.
- Example transcript marked HYPOTHETICAL.
- CRITICAL RULES note added: "using the wrong pattern silently bypasses isolation or raises a column error."

**Lesson**: never cite file:line without reading the actual file first. Prefer association-path scoping rules over a blanket "all tables have facility_id" assumption. Run `grep facility_id db/structure.sql` to check column existence before writing examples.
- Step 5 ClickHouse query: `webhooks_url_facilities` (validator catch) → corrected to real table `webhooks_facility_urls` (verified via `db/structure.sql:5259`).

<!-- Kaizen: 2026-06-10 — ClickHouse MCP tool name: run_select_query → run_query (residue cleanup, Fable audit Tier 2') -->

<!-- Kaizen: 2026-06-10 — Lateral propagation fix: default_scope example replaced Reservation (no facility_id) with Court (verified facility_id in db/structure.sql); Exception 4 fixed MembershipPlan.where(facility:) → where(owner_facility:) matching real belongs_to :owner_facility association (verified app/models/membership_plan.rb:64). Fable re-audit: lateral propagation. -->

---

<!-- Kaizen: 2026-06-14 — /optimize-skill pass -->
**Optimize-skill: line-ref drift fixes + relocation/densify/dedup (body 539 → 356 lines)**

**Correctness (verified against live repo 2026-06-14):**
- Tenancy Map source refs corrected for +1 drift: `facility.rb:275→276` (`has_many :payments`), `202→203` (`has_many :users, through: :facilities_users`), `183→184` (`has_many :reservations, through: :courts`). reservation.rb:138 and membership.rb:147/99 were already accurate.
- Step 3 PATTERN 1 re-anchored `query_type.rb:111-113 → 115-116` (`def court`).
- Step 3 PATTERN 3 (`downloads_controller.rb`) now shows the live `Payment.exists?(id:)` guard at line 35-36 (still no facility scope — the verify-intent caveat stands).

**Relocate (capability preserved, one-level-deep pointers):**
- ASCII hierarchy diagram → `reference/hierarchy.md`.
- Step 4/5 ClickHouse SQL → kept 2 canonical examples inline; unique schema-aware queries (reservation-via-courts distribution §7b, parent-child consistency §7c) appended to `../shared/clickhouse-queries.md`; rest already covered by shared §4–7.
- Report Format + worked Example transcript → `reference/output-templates.md`.

**Densify / dedup:**
- Four near-identical Exception class wrappers collapsed into one table (kind | scope rule | example).
- CRITICAL RULES restatement replaced with pointer to `../shared/critical-rules.md` + the table-unique wrong-column rule; "Why This Matters" folded into one imperative line.
- Quick Validation grep block deduped to a single 4-command set.

**Deferred (USER-DECISION, not applied):** keep exact line refs vs symbol-name refs in Tenancy Map (drift-recurrence vs jump-speed); whether to strip ALL inline ClickHouse SQL in favor of the shared doc; whether `disable-model-invocation` should flip to `true`. Left as-is.

**Lesson**: exact `file:line` anchors rot on every insertion above them — they need re-verification each audit. Symbol-name refs (`facility.rb \`has_many :payments\``) would stop the recurring +N drift but that's a convention change for the user to approve.
