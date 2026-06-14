---
name: memberships
description: Use when touching membership models, services, jobs, or any code path that involves auto-renewal, cancellations, prorations, payment retry, state transitions, family memberships, or freeze/pause logic. Also use when validating membership-related code against business rules.
allowed-tools: [Bash, Read, Grep, Glob, Edit, mcp__clickhouse__run_query, mcp__clickhouse__list_tables, mcp__honeybadger__list_faults, mcp__honeybadger__get_fault]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## Shared References

> **📚 This skill uses shared documentation. See:**
> - [Memberships Domain](../../../docs/domains/memberships.md) - comprehensive domain guide
> - [Critical Rules](../shared/critical-rules.md) - timezone, transactions

# Memberships Domain Expert Skill

Expert skill for the complex memberships domain. Validates auto-renewal, cancellations, prorations, payment logic, state transitions, family memberships, and freeze/pause rules.

## Why This Matters

**Membership bugs = Money issues = Refunds + Support tickets**

Incorrect proration calculations, renewal timing, or state transitions directly impact revenue and customer experience.

## Domain Overview

### Membership Types

| Type | Duration | Auto-Renewal | Notes |
|------|----------|--------------|-------|
| Weekly | 7 days | Yes | High frequency renewal |
| Monthly | 30 days | Yes | Most common |
| Annual | 365 days | Optional | Often manual renewal |
| Trial | Variable | Converts to paid | Special handling |

### Key Models

> Schema verified: 2026-06-10 against `app/models/membership.rb` + `db/structure.sql`

```
Membership                           # NO facility_id, NO status, NO expires_at, NO interval columns
├── belongs_to :owner (User)         # NOT belongs_to :user
├── belongs_to :creator (User)
├── belongs_to :membership_plan_price
├── has_one :membership_plan, through: :membership_plan_price
├── has_many :facilities, through: :membership_plan  # facility reached via membership_plan.owner_facility
├── belongs_to :purchased_at_facility (optional, Facility)
├── belongs_to :automatic_payment_user (User, optional)
├── has_many :membership_payments    # NOT membership_transactions
├── has_many :payments, through: :membership_payments
└── has_many :membership_users

# delegate :owner_facility, to: :membership_plan
# Interval lives on MembershipPlanPrice (mpp.interval_unit, mpp.interval_number_per_billing)
# auto_renew flag does NOT exist — renewal is controlled by aasm_state + MembershipPlanPrice.automatic_renewal
```

**Key columns on `memberships` table:**

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| `aasm_state` | string | `"idle"` | State machine column — NOT `status` |
| `current_period_end_at` | datetime | nil | Current period end — NOT `expires_at` |
| `acquired_at` | datetime | nil | When membership started |
| `paused_at` | datetime | nil | Set when paused |
| `termination_date` | datetime | nil | Contract end date override |
| `trial_ends_at` | datetime | nil | Free trial end |
| `renewal_payment_method` | string | `"card"` | `"card"`, `"ach"` |
| `archived` | boolean | false | Archived memberships |
| `purchased_at_facility_id` | integer | nil | Sale location (optional) |

**There is NO `facility_id`, `status`, `expires_at`, `auto_renew`, or `interval` column on `memberships`.**

### Critical Business Rules

1. **Auto-renewal** runs via `AutomaticRenewalMembershipJob`
2. **Weekly memberships** must renew every 7 days
3. **Expired memberships** cannot be used for bookings
4. **Cancellations** may have proration
5. **Failed payments** trigger retry logic

## Membership Lifecycle

Real AASM states (from `app/models/membership.rb`): `idle` (default/initial), `active`, `paused`, `cancelled`, `failed`.
There is NO `pending_payment` state and NO `expired` state in the real model.

```
┌─────────────────────────────────────────────────────────────────────┐
│              MEMBERSHIP LIFECYCLE (real AASM states)                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────┐  start!   ┌──────────┐                                │
│  │   idle   │──────────▶│  active  │◀──────────┐                    │
│  └──────────┘           └────┬─────┘           │                    │
│       ▲                      │                 │                    │
│       │   fail! also from    │ pause!          │ resume! (from      │
│  fail!│   active/paused/     ▼                 │  cancelled)        │
│       │   cancelled     ┌──────────┐           │                    │
│  ┌────┴─────┐           │  paused  │           │                    │
│  │  failed  │           └────┬─────┘           │                    │
│  └──────────┘                │ continue!       │                    │
│       │                      └────────────────▶│                    │
│       │ recover!                               │                    │
│       └────────────────────────────────────────┘                    │
│                                                                      │
│  cancel! (from active)                         ┌───────────┐        │
│  cancel_immediately! (from idle/active/        │ cancelled │        │
│    cancelled/failed/paused)                    └───────────┘        │
│                                                      ▲              │
│  renew! (from idle/cancelled/failed) ──────▶ active  │              │
│  (also valid from cancelled for re-activation)        │              │
│                                                       │              │
│  Note: fail! transitions: active/paused/cancelled ───┘              │
│                           → failed                                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**AASM Events Summary:**

| Event | From | To | Notes |
|-------|------|----|-------|
| `start!` | `idle`, `failed` | `active` | |
| `pause!` | `active` | `paused` | Sets `paused_at` |
| `continue!` | `paused` | `active` | Extends `current_period_end_at` by pause duration |
| `resume!` | `cancelled` | `active` | |
| `cancel!` | `active` | `cancelled` | |
| `cancel_immediately!` | `idle`, `active`, `cancelled`, `failed`, `paused` | `cancelled` | Sets `current_period_end_at` to now |
| `renew!` | `idle`, `cancelled`, `failed` | `active` | Advances `current_period_end_at` |
| `recover!` | `failed` | `active` | |
| `fail!` | `active`, `paused`, `cancelled` | `failed` | |

## Validation Areas

### 1. State Machine Transitions

**Valid Transitions** (verified from real model — states: `idle`, `active`, `paused`, `cancelled`, `failed`):

| From | To | Trigger | Notes |
|------|-----|---------|-------|
| `idle`, `failed` | `active` | `start!` | |
| `active` | `paused` | `pause!` | Sets `paused_at` |
| `paused` | `active` | `continue!` | Extends `current_period_end_at` |
| `cancelled` | `active` | `resume!` | |
| `idle`, `cancelled`, `failed` | `active` | `renew!` | Advances `current_period_end_at` |
| `failed` | `active` | `recover!` | |
| `active` | `cancelled` | `cancel!` | |
| `idle/active/cancelled/failed/paused` | `cancelled` | `cancel_immediately!` | Sets end to now |
| `active/paused/cancelled` | `failed` | `fail!` | |

There is NO `pending_payment` state, NO `expired` state, and NO direct `active → active` renewal transition.

**Validation Code:**

```bash
# Check state machine definition
grep -rn "aasm\|state_machine" app/models/membership.rb -A 50

# Check for valid transitions
grep -rn "event\|transitions from:" app/models/membership.rb
```

### 2. Proration Calculations

**Critical Formula:**

```ruby
# Time-based proration for plan changes
days_used = (Date.current - current_period_start).to_i
days_in_period = (current_period_end - current_period_start).to_i
daily_rate_current = current_price / days_in_period
daily_rate_new = new_plan_price / new_plan_days_in_period

credit = (days_in_period - days_used) * daily_rate_current
charge = (days_in_period - days_used) * daily_rate_new
amount_due = charge - credit
```

**Validation Checks:**

```bash
# Find proration logic
grep -rn "prorate\|proration\|daily_rate" app/ --include="*.rb"

# Check for division by zero protection
grep -rn "days_in_period\|billing_period" app/ --include="*.rb" | grep -v "zero\|nil\|blank"
```

**Edge Cases to Test:**
- [ ] Plan change on first day of period
- [ ] Plan change on last day of period
- [ ] Upgrade vs downgrade
- [ ] Same-day cancellation
- [ ] Leap year calculations

### 3. Family Membership Rules

```bash
# Find family membership logic
grep -rn "family\|member_users\|max_members" app/ --include="*.rb"

# Check capacity validation
grep -rn "max_members\|capacity" app/models/membership*.rb app/services/*membership* --include="*.rb"
```

**Rules to Validate:**
- [ ] Max members per plan enforced
- [ ] Primary member cannot be removed
- [ ] Access cascades to family members
- [ ] Cancellation removes all family access

### 4. Freeze/Pause Rules

```bash
# Find freeze logic
grep -rn "freeze\|pause" app/services/*membership* app/models/membership*.rb --include="*.rb"

# Check validation rules
grep -rn "min_freeze\|max_freeze\|allow_freeze" app/ --include="*.rb"
```

**Rules to Validate:**
- [ ] Minimum freeze period enforced
- [ ] Maximum freeze period enforced
- [ ] Freeze count per year tracked
- [ ] Period extended after freeze

## Audit Process

### Step 1: Identify Membership Changes

```bash
# Find membership-related changes
git diff develop --name-only | grep -i membership

# Find files touching membership logic
grep -rn "membership\|Membership" --include="*.rb" <changed_files>
```

### Step 2: Validate Auto-Renewal Logic

There is NO `auto_renew` column on `memberships`. Renewal is gated by:
- `MembershipPlanPrice#automatic_renewal` (boolean on the price, NOT the membership)
- `aasm_state` not being `cancelled` (verified via `non_cancelled` scope)
- `current_period_end_at` nearing expiry (NOT `expires_at`)

```ruby
# ✅ CORRECT - Real scopes on Membership (from model)
scope :valid_memberships, -> {
  where("current_period_end_at >= ? AND aasm_state != 'paused'", Time.current)
}
scope :invalid_memberships, -> {
  where("current_period_end_at < ? OR aasm_state = 'paused'", Time.current)
}
scope :non_cancelled, -> { where.not(aasm_state: "cancelled") }

# ✅ CORRECT - Check period end, not expires_at
membership.current_period_end_at  # period end date
membership.aasm_state             # "idle", "active", "paused", "cancelled", "failed"

# ❌ WRONG - These columns do NOT exist:
# membership.expires_at        → use current_period_end_at
# membership.status            → use aasm_state
# membership.auto_renew        → check mpp.automatic_renewal instead
# membership.facility_id       → use membership.membership_plan.owner_facility
```

### Step 3: Validate Period Extension Calculations

Interval lives on `MembershipPlanPrice` (the `mpp`), not on `Membership`.

```ruby
# ✅ CORRECT - Period extension uses mpp (MembershipPlanPrice) interval
def next_current_period_end_at
  if is_valid?
    next_billing_by_last_period(current_period_end_at)  # extend from current end
  else
    next_billing_by_last_period(membership_plan.owner_facility.current_time)
  end
end

# The interval is on mpp (MembershipPlanPrice):
mpp.interval_unit                # enum: week/month/year (verify)
mpp.interval_number_per_billing  # e.g. 1 for monthly, 7 for weekly via days
mpp.month?                       # true if monthly billing

# ❌ WRONG - Hardcoded intervals or using wrong column
expires_at + 30.days   # 1. 'expires_at' doesn't exist  2. period end must advance from current_period_end_at
```

### Step 4: Validate Payment Logic

```ruby
# ✅ CORRECT - Idempotent payment
def process_renewal_payment
  idempotency_key = "membership:#{id}:renewal:#{Date.current}"
  return if PaymentTransaction.exists?(idempotency_key: idempotency_key)

  ActiveRecord::Base.transaction do
    payment = create_payment(idempotency_key: idempotency_key)
    result = PaymentService::Base.process(payment)

    if result.success?
      extend_membership!
    else
      mark_payment_failed!
    end
  end
end

# ❌ WRONG - Not idempotent
def process_renewal_payment
  payment = create_payment  # Could double-charge!
  PaymentService::Base.process(payment)
end
```

### Step 5: Validate Cancellation Logic

```ruby
# ✅ CORRECT - Proration calculation (use real column names)
def calculate_proration
  return 0 unless eligible_for_proration?

  total_days = (current_period_end_at - acquired_at).to_i  # NOT expires_at / started_at
  remaining_days = (current_period_end_at - Time.current).to_i

  (amount_paid * remaining_days / total_days).round(2)
end

# ✅ CORRECT - Cancel via AASM event (real model)
def cancel_with_refund
  ActiveRecord::Base.transaction do
    cancel_immediately!  # sets current_period_end_at to now + transitions aasm_state to 'cancelled'
    # OR: cancel!  if only transitioning from active (end-of-period)

    if proration_amount > 0
      create_refund!(amount: proration_amount)
    end
  end
end

# ❌ WRONG - These columns do NOT exist on memberships:
# update!(status: 'cancelled')    → use cancel! / cancel_immediately! AASM events
# update!(auto_renew: false)      → no auto_renew column
# update!(cancelled_at: ...)      → no cancelled_at column (state transition is via aasm_state)
```

### Step 6: Check Scheduler Configuration

```yaml
# config/scheduler.yml
timezone_aware_memberships_charge_due_to_date_job:
  cron: '0 * * * *'  # Every hour
  class: TimezoneAwareJobCoordinator
  queue: default
  args: ['MembershipsChargeDueToDateJob', 7]
  description: "Scheduled task to charge expired memberships at 7:00 AM local time for each facility timezone"
```

```bash
# Verify scheduler config
grep -A5 "renewal\|membership" config/scheduler.yml
```

### Step 7: Production Data Verification (ClickHouse)

> ⚠️ `memberships` replicates to ClickHouse as *ReplacingMergeTree — always use `FINAL` or counts inflate ~20× (see /query-analyzer CRITICAL rule #6).

```sql
-- Check membership state distribution (aasm_state, NOT status)
-- Column names in CH replica match MySQL: aasm_state, current_period_end_at, NOT status/expires_at
SELECT
  aasm_state,
  count() as total,
  round(count() * 100.0 / sum(count()) OVER (), 2) as pct
FROM pbp_productionDB_optimized.memberships FINAL
GROUP BY aasm_state
ORDER BY total DESC;

-- Find memberships that should have renewed but didn't
-- NOTE: no auto_renew column, no facility_id column, no status column on memberships
-- Join to membership_plan_prices for automatic_renewal flag
SELECT
  m.id,
  m.owner_id,
  m.aasm_state,
  m.current_period_end_at
FROM pbp_productionDB_optimized.memberships FINAL AS m
WHERE m.aasm_state = 'active'
  AND m.current_period_end_at < now() - INTERVAL 1 DAY
  AND m.deleted_at IS NULL
LIMIT 100;

-- Check renewal success rate (membership_payments, not membership_transactions)
-- ⚠️ membership_payments is also *ReplacingMergeTree — use FINAL
SELECT
  state,
  count() as total_renewals
FROM pbp_productionDB_optimized.membership_payments FINAL
WHERE origin = 'automatic_generation'
  AND created_at > now() - INTERVAL 7 DAY
GROUP BY state
ORDER BY total_renewals DESC;

-- Find memberships with potential issues (active past period end)
SELECT count() as problematic
FROM pbp_productionDB_optimized.memberships FINAL
WHERE aasm_state = 'active'
  AND current_period_end_at < now()
  AND deleted_at IS NULL;

-- Check upcoming renewals (by current_period_end_at, NOT next_payment_date)
SELECT
  toDate(current_period_end_at) as renewal_date,
  count() as memberships
FROM pbp_productionDB_optimized.memberships FINAL
WHERE aasm_state = 'active'
  AND deleted_at IS NULL
GROUP BY renewal_date
ORDER BY renewal_date
LIMIT 30;

-- Check failed membership payments by facility (via membership_plan join)
-- membership_payments has no direct facility_id — join to memberships/plans
SELECT
  mp.state,
  count() as count
FROM pbp_productionDB_optimized.membership_payments FINAL AS mp
WHERE mp.state IN ('payment_failed', 'failed')
  AND mp.created_at > now() - INTERVAL 30 DAY
GROUP BY mp.state
ORDER BY count DESC
LIMIT 20;
```

### Step 8: Check Honeybadger for Related Errors

```
mcp__honeybadger__list_faults: Search for "membership" or "renewal" errors
mcp__honeybadger__get_fault: Get details of membership-related errors
```

## Common Bugs to Watch For

### 1. Weekly Membership Not Renewing
```ruby
# BUG: Interval lives on MembershipPlanPrice (mpp), not Membership
# mpp.interval_unit is an integer enum, not a string — use mpp.month?, mpp.week?, etc.
if membership.membership_plan.interval == 'month'  # WRONG: interval is on mpp, not plan
# ✅ Use:
if membership.mpp.month?

# BUG: Date comparison off by timezone — use facility timezone
where('current_period_end_at::date = ?', Date.today)  # ❌ Date.today + wrong column
# ✅ Use:
where("current_period_end_at < ?", Time.current + 1.day)
```

### 2. Double Charging
```ruby
# BUG: No idempotency key
PaymentService.charge(membership)  # Could run twice!
```

### 3. Wrong Period Extension
```ruby
# BUG: Extends from today instead of current period end
new_end = Time.current + 7.days  # Should be current_period_end_at + interval!
# ✅ Use:
new_end = membership.next_current_period_end_at  # uses current_period_end_at
```

### 4. Cancellation Race Condition
```ruby
# BUG: No transaction, and wrong column + method
membership.update!(status: 'cancelled')  # WRONG: 'status' doesn't exist; bypass AASM
payment.refund!  # If this fails, membership is cancelled without refund!

# ✅ CORRECT:
ActiveRecord::Base.transaction do
  membership.cancel_immediately!  # AASM event — transitions aasm_state correctly
  payment.refund!
end
```

## Checklist

### Core Logic
- [ ] Auto-renewal reads `mpp.automatic_renewal` (on `MembershipPlanPrice`, NOT a `auto_renew` column on `Membership`)
- [ ] Period end uses `current_period_end_at` (NOT `expires_at`)
- [ ] State uses `aasm_state` (NOT `status`); valid values: `idle`, `active`, `paused`, `cancelled`, `failed`
- [ ] Facility reached via `membership_plan.owner_facility` (NOT `membership.facility`)
- [ ] Period extension uses `mpp.interval_unit` + `mpp.interval_number_per_billing` (NOT a `membership.interval` column)
- [ ] Payment is idempotent (uses idempotency_key)
- [ ] Database transaction wraps related operations
- [ ] Cancellation handles proration correctly
- [ ] Time comparisons use `Time.current`
- [ ] Job is scheduled at correct frequency
- [ ] Tests cover all membership types (weekly, monthly, annual)

### State Machine
- [ ] All transitions are valid per lifecycle diagram
- [ ] No direct state assignment (must use events)
- [ ] Callbacks trigger appropriate notifications
- [ ] AASM guards prevent invalid transitions

### Proration
- [ ] Uses correct formula (time-based)
- [ ] Handles division by zero
- [ ] Rounds to 2 decimal places
- [ ] Works for upgrades AND downgrades
- [ ] Handles edge cases (first/last day)

### Renewal
- [ ] Runs in facility timezone
- [ ] Has idempotency protection
- [ ] Updates period dates correctly
- [ ] Handles failed payment grace period
- [ ] Sends appropriate notifications

### Family Membership
- [ ] Enforces max members
- [ ] Validates primary member
- [ ] Cascades access correctly
- [ ] Handles removal properly

### Freeze/Pause
- [ ] Validates min/max periods
- [ ] Tracks freeze count
- [ ] Extends period correctly
- [ ] Schedules reactivation

### Financial Accuracy
- [ ] Uses database transactions
- [ ] Creates audit records
- [ ] Handles refunds correctly
- [ ] No double-charging

## Report Format

```markdown
## Membership Domain Audit

### Summary
- Files analyzed: X
- Issues found: Y
- Membership types affected: Z

### Critical Issues (BLOCKING)

| File | Issue | Risk | Impact |
|------|-------|------|--------|
| renewal_job.rb | Missing weekly interval | HIGH | Weekly members won't renew |

### Business Logic Check

| Rule | Status | Notes |
|------|--------|-------|
| Auto-renewal flag checked | ✅ | |
| Idempotent payments | ❌ | Missing idempotency key |
| Proration calculation | ✅ | |
| Transaction safety | ✅ | |

### Production Data Check

| Membership Type | Active | Should Renew | Actually Renewed |
|-----------------|--------|--------------|------------------|
| Weekly | 1,234 | 456 | 450 (98.7%) |
| Monthly | 15,678 | 2,345 | 2,340 (99.8%) |

### Honeybadger Errors
- 12 errors related to "membership renewal" in last 7 days
- Most common: "Payment failed for membership #12345"

### Recommendations
1. Add idempotency key to renewal payment
2. Fix weekly interval comparison
```

## Example

```
Claude detects membership changes:

## Membership Domain Audit

### Scanning: app/jobs/automatic_renewal_membership_job.rb

### Issue Found!

⚠️ CRITICAL: Weekly memberships excluded from renewal

```ruby
# Line 15 - Current code (hypothetical — note: interval lives on mpp, NOT Membership)
scope = Membership.joins(membership_plan_price: :membership_plan)
                  .where(membership_plan_prices: { automatic_renewal: true })
                  .where("membership_plan_prices.interval_unit IN (?)", [MembershipPlanPrice.interval_units[:month]])
# Missing: week interval_unit value
```

Weekly memberships are NOT included in the renewal scope!

### Production Impact (ClickHouse)

> ⚠️ Always use FINAL on memberships/*ReplacingMergeTree tables.

```sql
SELECT count() FROM pbp_productionDB_optimized.memberships FINAL
WHERE aasm_state = 'active' AND deleted_at IS NULL;
-- Breakdown by interval_unit would require joining to membership_plan_prices
```

Weekly memberships affected: ~234 at risk (example figures)

### Suggested Fix

```ruby
# ✅ Correct — no auto_renew or interval column on Membership; interval is on mpp
scope = Membership.joins(membership_plan_price: :membership_plan)
                  .where(membership_plan_prices: { automatic_renewal: true })
                  .where.not(aasm_state: 'cancelled')
# Filter by interval_unit on membership_plan_prices for type-specific scoping
```

### Result: CRITICAL FIX NEEDED
```

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new membership business rule
- A missing validation pattern
- A better ClickHouse query for analysis

**You MUST**:
1. Complete the current membership audit first
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements**:

<!-- Kaizen: 2026-01-23 - Manual MembershipPayment Fix Pattern -->
> **Manual fix procedures moved to shared reference.** See [shared/troubleshooting/membership-payment-fixes.md](../shared/troubleshooting/membership-payment-fixes.md) for the full orphaned-payment fix pattern (investigation SQL, direct-SQL INSERT, common pitfalls).

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
