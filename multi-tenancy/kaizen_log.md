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
