---
name: memberships
description: Use when touching membership models, services, jobs, or any code path that involves auto-renewal, cancellations, prorations, payment retry, state transitions, family memberships, or freeze/pause logic. Also use when validating membership-related code against business rules.
allowed-tools: [Bash, Read, Grep, Glob, Edit, mcp__clickhouse__run_query, mcp__clickhouse__list_tables, mcp__honeybadger__list_faults, mcp__honeybadger__get_fault]
disable-model-invocation: false
---

# Memberships Domain Expert Skill

Validates auto-renewal, cancellations, prorations, payment logic, state transitions, family memberships, and freeze/pause rules.

**Why it matters:** membership bugs = money issues (refunds, double-charges, support tickets) — incorrect proration, renewal timing, or state transitions directly hit revenue.

> Conventions: `CLAUDE.local.md` overrides `CLAUDE.md` (Docker, linting, coverage); timezone/transaction rules in [../shared/critical-rules.md](../shared/critical-rules.md); full domain guide in [../../../docs/domains/memberships.md](../../../docs/domains/memberships.md).

## Domain Overview

| Type | Duration | Auto-Renewal | Notes |
|------|----------|--------------|-------|
| Daily | 1 day | Yes | `interval_unit: day` (enum `day: 0`) |
| Weekly | 7 days | Yes | High frequency renewal |
| Monthly | 30 days | Yes | Most common |
| Annual | 365 days | Optional | Often manual renewal |
| Trial | Variable | Converts to paid | Special handling |

**Business rules:** auto-renewal runs via `AutomaticRenewalMembershipJob`; weekly memberships renew every 7 days; expired (period-ended) memberships cannot be used for bookings; cancellations may prorate; failed payments trigger retry logic.

### Key Models

> Schema verified 2026-06-10 against `app/models/membership.rb` + `db/structure.sql`.

```
Membership                           # NO facility_id, status, expires_at, auto_renew, interval columns
├── belongs_to :owner (User)         # NOT belongs_to :user
├── belongs_to :creator (User)
├── belongs_to :membership_plan_price
├── has_one :membership_plan, through: :membership_plan_price
├── has_many :facilities, through: :membership_plan   # facility via membership_plan.owner_facility
├── belongs_to :purchased_at_facility (optional, Facility)
├── belongs_to :automatic_payment_user (User, optional)
├── has_many :membership_payments    # NOT membership_transactions
├── has_many :payments, through: :membership_payments
└── has_many :membership_users
# delegate :owner_facility, to: :membership_plan
# Interval lives on MembershipPlanPrice (mpp): mpp.interval_unit, mpp.interval_number_per_billing
# No auto_renew flag — renewal is gated by aasm_state + MembershipPlanPrice.automatic_renewal
```

Key `memberships` columns: `aasm_state` (string, default `"idle"`), `current_period_end_at` (datetime), `acquired_at`, `paused_at`, `termination_date`, `trial_ends_at`, `renewal_payment_method` (`"card"`/`"ach"`), `archived` (bool), `purchased_at_facility_id`.

**Wrong-vs-right column map (these fabricated columns do NOT exist — single source of truth):**

| ❌ Does NOT exist | ✅ Use instead |
|-------------------|----------------|
| `membership.status` | `membership.aasm_state` (`idle`/`active`/`paused`/`cancelled`/`failed`) |
| `membership.expires_at` | `membership.current_period_end_at` |
| `membership.auto_renew` | `mpp.automatic_renewal` (on `MembershipPlanPrice`) |
| `membership.facility_id` / `membership.facility` | `membership.membership_plan.owner_facility` |
| `membership.interval` | `mpp.interval_unit` + `mpp.interval_number_per_billing` |
| `membership.current_period_start` | (none — only `current_period_end_at` + `acquired_at` exist) |
| `membership.cancelled_at` | state transition via `aasm_state` (no timestamp column) |
| `membership_transactions` | `membership_payments` |

## Membership Lifecycle (AASM)

Real states: `idle` (default/initial), `active`, `paused`, `cancelled`, `failed`. There is NO `pending_payment` and NO `expired` state, and NO direct `active → active` renewal transition. Source: `app/models/membership.rb`. Visual diagram: [reference/lifecycle.md](reference/lifecycle.md).

| Event | From | To | Notes |
|-------|------|----|-------|
| `start!` | `idle`, `failed` | `active` | |
| `pause!` | `active` | `paused` | Sets `paused_at` |
| `continue!` | `paused` | `active` | Extends `current_period_end_at` by pause duration |
| `resume!` | `cancelled` | `active` | |
| `cancel!` | `active` | `cancelled` | End-of-period |
| `cancel_immediately!` | `idle`, `active`, `cancelled`, `failed`, `paused` | `cancelled` | Sets `current_period_end_at` to now |
| `renew!` | `idle`, `cancelled`, `failed` | `active` | Advances `current_period_end_at` |
| `recover!` | `failed` | `active` | |
| `fail!` | `active`, `paused`, `cancelled` | `failed` | |

## Validation Areas — grep recipes

| Area | Grep |
|------|------|
| State machine def | `grep -rn "aasm\|state_machine" app/models/membership.rb -A 50` |
| Valid transitions | `grep -rn "event\|transitions from:" app/models/membership.rb` |
| Proration logic | `grep -rn "prorate\|proration\|daily_rate" app/ --include="*.rb"` |
| Div-by-zero guards | `grep -rn "days_in_period\|billing_period" app/ --include="*.rb" \| grep -v "zero\|nil\|blank"` |
| Family logic | `grep -rn "family\|member_users\|max_members" app/ --include="*.rb"` |
| Family capacity | `grep -rn "max_members\|capacity" app/models/membership*.rb app/services/*membership*` |
| Freeze/pause | `grep -rn "freeze\|pause" app/services/*membership* app/models/membership*.rb` |
| Freeze limits | `grep -rn "min_freeze\|max_freeze\|allow_freeze" app/ --include="*.rb"` |

**Proration** (full reference: [reference/proration.md](reference/proration.md)): the real path is `MembershipPlanPrice#prorated_price_by_date` — facility-timezone aware (`facility.current_time`), monthly-only (`return amount unless month?`), decimal math. `Membership` has NO `calculate_proration` method and NO `current_period_start` column. Edge cases: first/last day of period, upgrade vs downgrade, same-day cancellation, leap year, division-by-zero.

**Family rules:** max members per plan enforced; primary member cannot be removed; access cascades to family members; cancellation removes all family access.

**Freeze/pause rules:** min and max freeze period enforced; freeze count per year tracked; period extended after freeze.

## Audit Process

### Step 1 — Identify changes
```bash
git diff develop --name-only | grep -i membership
grep -rn "membership\|Membership" --include="*.rb" <changed_files>
```

### Step 2 — Auto-renewal logic
No `auto_renew` column. Renewal is gated by `mpp.automatic_renewal` (on the price), `aasm_state != 'cancelled'` (`non_cancelled` scope), and `current_period_end_at` nearing expiry.

```ruby
# ✅ Real scopes on Membership
scope :valid_memberships,   -> { where("current_period_end_at >= ? AND aasm_state != 'paused'", Time.current) }
scope :invalid_memberships, -> { where("current_period_end_at < ?  OR  aasm_state = 'paused'", Time.current) }
scope :non_cancelled,       -> { where.not(aasm_state: "cancelled") }
```

See the wrong-vs-right column map above for forbidden columns.

### Step 3 — Period extension
Interval lives on `mpp` (`MembershipPlanPrice`), not on `Membership`.

```ruby
# ✅ Period extension uses the mpp interval
def next_current_period_end_at
  if is_valid?
    next_billing_by_last_period(current_period_end_at)                       # extend from current end
  else
    next_billing_by_last_period(membership_plan.owner_facility.current_time)
  end
end

# Interval is on mpp (MembershipPlanPrice):
mpp.interval_unit                # enum { day: 0, week: 1, month: 2, year: 3 }
mpp.interval_number_per_billing  # e.g. 1 for monthly
mpp.month?                       # true if monthly billing

# ❌ WRONG: expires_at + 30.days — 'expires_at' doesn't exist; must advance from current_period_end_at
```

### Step 4 — Payment logic (idempotent)
```ruby
# ✅ Idempotent payment
def process_renewal_payment
  idempotency_key = "membership:#{id}:renewal:#{Date.current}"
  return if PaymentTransaction.exists?(idempotency_key: idempotency_key)

  ActiveRecord::Base.transaction do
    payment = create_payment(idempotency_key: idempotency_key)
    result  = PaymentService::Base.process(payment)
    result.success? ? extend_membership! : mark_payment_failed!
  end
end
# ❌ WRONG: create_payment without an idempotency key — could double-charge.
```

### Step 5 — Cancellation
Cancel via AASM events, never direct column writes. Proration shape in [reference/proration.md](reference/proration.md) (uses `current_period_end_at` + `acquired_at` — no `current_period_start`).

```ruby
# ✅ Cancel via AASM event, wrapped in a transaction
def cancel_with_refund
  ActiveRecord::Base.transaction do
    cancel_immediately!  # sets current_period_end_at to now + transitions aasm_state to 'cancelled'
    # OR cancel!  for end-of-period (only from active)
    create_refund!(amount: proration_amount) if proration_amount.positive?
  end
end
# ❌ WRONG: update!(status: 'cancelled') / update!(auto_renew: false) / update!(cancelled_at: ...)
#   — none of those columns exist; cancellation is an aasm_state transition.
```

### Step 6 — Scheduler config
```yaml
# config/scheduler.yml
timezone_aware_memberships_charge_due_to_date_job:
  cron: '0 * * * *'  # Every hour
  class: TimezoneAwareJobCoordinator
  queue: default
  args: ['MembershipsChargeDueToDateJob', 7]
  description: "Charge expired memberships at 7:00 AM local time per facility timezone"
```
Verify: `grep -A5 "renewal\|membership" config/scheduler.yml`

### Step 7 — Production verification (ClickHouse)
> ⚠️ `memberships` and `membership_payments` replicate as `*ReplacingMergeTree` — ALWAYS use `FINAL` or counts inflate ~20× (see /query-analyzer rule #6). Column names match MySQL (`aasm_state`, `current_period_end_at`).

```sql
SELECT aasm_state, count() AS total
FROM pbp_productionDB_optimized.memberships FINAL
GROUP BY aasm_state ORDER BY total DESC;
```
Full query catalog (renewal success rate, problematic active-past-end, upcoming renewals, failed payments) + Honeybadger pointers: [reference/clickhouse-queries.md](reference/clickhouse-queries.md).

## Common Bugs

```ruby
# 1. Weekly not renewing — interval is on mpp (integer enum), not the plan
if membership.membership_plan.interval == 'month'  # ❌ no interval on plan
if membership.mpp.month?                           # ✅
where('current_period_end_at::date = ?', Date.today)        # ❌ Date.today + wrong shape
where("current_period_end_at < ?", Time.current + 1.day)    # ✅

# 2. Double charging — missing idempotency key (see Step 4)
# 3. Wrong period extension — extends from today, not current period end
new_end = Time.current + 7.days                  # ❌
new_end = membership.next_current_period_end_at   # ✅ advances from current_period_end_at

# 4. Cancellation race / wrong column + no transaction
membership.update!(status: 'cancelled'); payment.refund!   # ❌ 'status' missing; bypasses AASM; no txn
ActiveRecord::Base.transaction do                          # ✅
  membership.cancel_immediately!
  payment.refund!
end
```

## Checklist (highest-signal asserts)

- [ ] Auto-renewal reads `mpp.automatic_renewal` (NOT a `membership.auto_renew` column)
- [ ] Period end uses `current_period_end_at` (NOT `expires_at`); period advances from it via `next_current_period_end_at` (NOT from today)
- [ ] State uses `aasm_state` (NOT `status`); transitions via AASM events only — no direct state assignment
- [ ] Facility via `membership_plan.owner_facility`; interval via `mpp.interval_unit` + `interval_number_per_billing`
- [ ] Payment is idempotent (idempotency_key) and wrapped in a DB transaction; no double-charge
- [ ] Cancellation uses `cancel!`/`cancel_immediately!`, handles proration + refund atomically
- [ ] Time comparisons use `Time.current`; renewal runs in facility timezone
- [ ] Proration: handles division-by-zero, rounds to 2 dp, works for upgrade AND downgrade
- [ ] Family: enforces max members, protects primary, cascades + removes access correctly
- [ ] Freeze/pause: validates min/max, tracks count, extends period
- [ ] Tests cover all membership types (weekly, monthly, annual) and use `Timecop.freeze`
- [ ] ClickHouse checks use `FINAL` on every ReplacingMergeTree table

## Output & References

- Audit output template + worked example: [reference/audit-template.md](reference/audit-template.md)
- Kaizen change-log: [kaizen_log.md](kaizen_log.md)
- When you discover a new business rule / validation pattern / better query while running this skill: finish the audit first, then append a dated entry to `kaizen_log.md`.
