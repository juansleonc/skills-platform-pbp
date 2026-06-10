---
name: memberships
description: Use when touching membership models, services, jobs, or any code path that involves auto-renewal, cancellations, prorations, payment retry, state transitions, family memberships, or freeze/pause logic. Also use when validating membership-related code against business rules.
allowed-tools: [Bash, Read, Grep, Glob, Edit, mcp__clickhouse__run_select_query, mcp__clickhouse__list_tables, mcp__honeybadger__list_faults, mcp__honeybadger__get_fault]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## Shared References

> **📚 This skill uses shared documentation. See:**
> - [Memberships Domain](../../docs/domains/memberships.md) - comprehensive domain guide
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

```
Membership
├── belongs_to :user
├── belongs_to :facility
├── belongs_to :membership_plan
├── has_many :payments
└── has_many :membership_transactions
```

### Critical Business Rules

1. **Auto-renewal** runs via `AutomaticRenewalMembershipJob`
2. **Weekly memberships** must renew every 7 days
3. **Expired memberships** cannot be used for bookings
4. **Cancellations** may have proration
5. **Failed payments** trigger retry logic

## Membership Lifecycle

```
┌─────────────────────────────────────────────────────────────────┐
│                    MEMBERSHIP LIFECYCLE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐                                               │
│  │pending_payment│─────────────────────────────────┐            │
│  └───────┬──────┘                                  │            │
│          │ payment_success                         │ timeout    │
│          ▼                                         ▼            │
│  ┌──────────────┐    pause!    ┌──────────────┐  ┌──────────┐  │
│  │    active    │─────────────▶│    paused    │  │ cancelled │  │
│  └───────┬──────┘              └───────┬──────┘  └──────────┘  │
│          │                             │                        │
│          │ cancel!                     │ resume!                │
│          ▼                             │                        │
│  ┌──────────────┐                      │                        │
│  │  cancelled   │◀─────────────────────┘                        │
│  └──────────────┘                                               │
│                                                                  │
│  payment_failed (after grace): active/paused ──────────────┐   │
│                                                             ▼   │
│                                                  ┌──────────────┐│
│                                                  │   expired    ││
│                                                  └──────────────┘│
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Validation Areas

### 1. State Machine Transitions

**Valid Transitions:**

| From | To | Trigger |
|------|-----|---------|
| `pending_payment` | `active` | Payment success |
| `active` | `paused` | User request + validation |
| `active` | `cancelled` | User request |
| `paused` | `active` | Resume request |
| `paused` | `cancelled` | User request |
| `active` | `expired` | Payment failed after grace |
| `paused` | `expired` | Payment failed after grace |

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

```ruby
# ✅ CORRECT - Check expiration AND auto_renew flag
scope :renewable, -> {
  where(auto_renew: true)
    .where('expires_at <= ?', Time.current + 1.day)
    .where(status: 'active')
}

# ❌ WRONG - Missing auto_renew check
scope :renewable, -> {
  where('expires_at <= ?', Time.current + 1.day)  # Will renew ALL expiring!
}

# ❌ WRONG - Wrong date comparison
scope :renewable, -> {
  where(auto_renew: true)
    .where('expires_at = ?', Time.current.to_date)  # Misses if job runs late!
}
```

### Step 3: Validate Expiration Calculations

```ruby
# ✅ CORRECT - Weekly membership expiration
def calculate_next_expiration
  case membership_plan.interval
  when 'weekly'
    expires_at + 7.days
  when 'monthly'
    expires_at + 1.month
  when 'annual'
    expires_at + 1.year
  end
end

# ❌ WRONG - Hardcoded intervals
def calculate_next_expiration
  expires_at + 30.days  # Wrong for weekly/annual!
end
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
# ✅ CORRECT - Proration calculation
def calculate_proration
  return 0 unless eligible_for_proration?

  total_days = (original_expires_at - started_at).to_i
  remaining_days = (original_expires_at - Time.current).to_i

  (amount_paid * remaining_days / total_days).round(2)
end

# ✅ CORRECT - Cancel with refund
def cancel_with_refund
  ActiveRecord::Base.transaction do
    update!(
      status: 'cancelled',
      cancelled_at: Time.current,
      auto_renew: false
    )

    if proration_amount > 0
      create_refund!(amount: proration_amount)
    end
  end
end
```

### Step 6: Check Scheduler Configuration

```yaml
# config/scheduler.yml
automatic_renewal_membership_job:
  cron: "0 */4 * * *"  # Every 4 hours
  class: AutomaticRenewalMembershipJob
  queue: memberships
```

```bash
# Verify scheduler config
grep -A5 "renewal\|membership" config/scheduler.yml
```

### Step 7: Production Data Verification (ClickHouse)

```sql
-- Check membership type distribution
SELECT
  membership_plan_id,
  interval,
  count(*) as count,
  countIf(auto_renew = 1) as auto_renew_count
FROM pbp_productionDB_optimized.memberships
GROUP BY membership_plan_id, interval
ORDER BY count DESC;

-- Find memberships that should have renewed but didn't
SELECT
  id,
  facility_id,
  user_id,
  expires_at,
  auto_renew,
  status
FROM pbp_productionDB_optimized.memberships
WHERE auto_renew = 1
  AND status = 'active'
  AND expires_at < now() - INTERVAL 1 DAY
LIMIT 100;

-- Check renewal success rate by type
SELECT
  interval,
  count(*) as total_renewals,
  countIf(status = 'success') as successful,
  countIf(status = 'failed') as failed
FROM pbp_productionDB_optimized.membership_transactions
WHERE transaction_type = 'renewal'
  AND created_at > now() - INTERVAL 7 DAY
GROUP BY interval;

-- Check membership status distribution
SELECT
  status,
  count(*) as total,
  round(count(*) * 100.0 / sum(count(*)) OVER (), 2) as pct
FROM pbp_productionDB_optimized.memberships
GROUP BY status
ORDER BY total DESC;

-- Find memberships with potential issues (active past end date)
SELECT count(*) as problematic
FROM pbp_productionDB_optimized.memberships
WHERE status = 'active'
  AND current_period_end < now();

-- Check renewal patterns
SELECT
  toDate(next_payment_date) as renewal_date,
  count(*) as memberships
FROM pbp_productionDB_optimized.memberships
WHERE status = 'active'
GROUP BY renewal_date
ORDER BY renewal_date
LIMIT 30;

-- Check proration history
SELECT
  plan_change_type,
  count(*) as changes,
  avg(proration_amount) as avg_proration
FROM pbp_productionDB_optimized.membership_plan_changes
WHERE created_at > now() - INTERVAL 30 DAY
GROUP BY plan_change_type;

-- Check failed renewals by facility
SELECT
  facility_id,
  count(*) as failed_renewals,
  countIf(retry_count > 2) as exhausted_retries
FROM pbp_productionDB_optimized.membership_payments
WHERE status = 'failed'
  AND created_at > now() - INTERVAL 30 DAY
GROUP BY facility_id
ORDER BY failed_renewals DESC
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
# BUG: Interval comparison wrong
if membership_plan.interval == 'month'  # 'monthly' != 'month'

# BUG: Date comparison off by timezone
where('expires_at::date = ?', Date.today)  # Use Time.current!
```

### 2. Double Charging
```ruby
# BUG: No idempotency key
PaymentService.charge(membership)  # Could run twice!
```

### 3. Wrong Expiration Extension
```ruby
# BUG: Extends from today instead of current expiration
new_expires_at = Time.current + 7.days  # Should be expires_at + 7.days!
```

### 4. Cancellation Race Condition
```ruby
# BUG: No transaction
membership.update!(status: 'cancelled')
payment.refund!  # If this fails, membership is cancelled without refund!
```

## Checklist

### Core Logic
- [ ] Auto-renewal checks `auto_renew` flag
- [ ] Expiration calculation uses correct interval
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
# Line 15 - Current code
scope = Membership.where(auto_renew: true)
                  .where('interval IN (?)', ['monthly', 'annual'])
```

Weekly memberships are NOT included in the renewal scope!

### Production Impact (ClickHouse)

Weekly memberships affected:
- Daisy Hill: 45 active weekly memberships
- Alex Hills: 32 active weekly memberships
- Total at risk: 234 weekly memberships

### Suggested Fix

```ruby
scope = Membership.where(auto_renew: true)
                  .where('interval IN (?)', ['weekly', 'monthly', 'annual'])
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
## Manual MembershipPayment Fix (Orphaned Payments)

When a Payment exists but the MembershipPayment was deleted or never created:

### Investigation Steps

```sql
-- 1. Find the membership for the user at the facility
SELECT membership_id, user_id, facility_id, aasm_state
FROM pbp_core_prod.memberships_historic
WHERE user_id = <user_id> AND facility_id = <facility_id>
  AND _peerdb_is_deleted = 0;

-- 2. Check if MembershipPayment exists for that membership
SELECT id, payment_id, membership_id, state, created_at
FROM pbp_productionDB_optimized.membership_payments
WHERE membership_id = <membership_id>
  AND _peerdb_is_deleted = 0;

-- 3. Check if MembershipPayment exists in MySQL (may be deleted)
-- In Rails console:
MembershipPayment.unscoped.find_by(id: <id>)
ActiveRecord::Base.connection.execute("SELECT * FROM membership_payments WHERE id = <id>").to_a
```

### Fix Pattern (Direct SQL - Skips Callbacks)

**IMPORTANT**: MembershipPayment has callbacks that call `process_payment` which will fail.
ALWAYS use direct SQL for manual fixes.

```ruby
# Step 1: Load references
payment = Payment.find(<payment_id>)
membership = Membership.find(<membership_id>)

# Step 2: Verify state
puts "Payment paid: #{payment.paid}"
puts "MPs count: #{membership.membership_payments.count}"

# Step 3: Prepare dates (handle nil!)
now = Time.current.strftime('%Y-%m-%d %H:%M:%S')
starts = membership.acquired_at ? membership.acquired_at.strftime('%Y-%m-%d %H:%M:%S') : now
ends_at = membership.current_period_end_at ? membership.current_period_end_at.strftime('%Y-%m-%d %H:%M:%S') : (Time.current + 1.year).strftime('%Y-%m-%d %H:%M:%S')

# Step 4: INSERT (direct SQL, no callbacks)
ActiveRecord::Base.connection.execute("INSERT INTO membership_payments (payment_id, membership_id, state, starts_at, ends_at, origin, payment_required, created_at, updated_at) VALUES (#{payment.id}, #{membership.id}, 'payment_success', '#{starts}', '#{ends_at}', 'manual_fix', 0, '#{now}', '#{now}')")

# Step 5: Get created ID
mp_id = ActiveRecord::Base.connection.execute("SELECT LAST_INSERT_ID()").first[0]
puts "MembershipPayment creado: #{mp_id}"

# Step 6: UPDATE payment (direct SQL, no callbacks)
ActiveRecord::Base.connection.execute("UPDATE payments SET paid = 1 WHERE id = #{payment.id}")

# Step 7: UPDATE membership (CRITICAL - required for refunds to work!)
mp = MembershipPayment.find(mp_id)
membership.update_column(:current_period_end_at, mp.ends_at)
membership.update_column(:aasm_state, 'active') if membership.aasm_state == 'idle'

# Step 8: Verify
puts "Payment paid: #{Payment.find(payment.id).paid}"
puts "MPs count: #{MembershipPayment.where(membership_id: membership.id).count}"
puts "Membership current_period_end_at: #{membership.reload.current_period_end_at}"
puts "Membership aasm_state: #{membership.aasm_state}"
```

### ⚠️ Common Pitfalls

1. **`to_s(:db)` is deprecated** - Use `strftime('%Y-%m-%d %H:%M:%S')`
2. **`current_period_end_at` may be nil** - Always check before calling strftime
3. **Heredocs don't work in console** - Use single-line SQL strings
4. **`create!` triggers callbacks** - Use direct SQL for MembershipPayment fixes
5. **Membership must be updated too** - `current_period_end_at` and `aasm_state` must match the MembershipPayment, otherwise refunds will fail with "Error while processing total refund"

<!-- Kaizen: 2026-06-10 — Merged membership-validate into memberships (superpowers-spike pruning pass) -->
Merged all unique content from the `/membership-validate` skill into this canonical `/memberships` skill. Sections added: Membership Lifecycle diagram, Validation Areas (State Machine Transitions, Proration Calculations with formula, Family Membership Rules, Freeze/Pause Rules), extended ClickHouse queries, and extended checklist sections. The `membership-validate` skill directory was deleted. The Skill Router in `CLAUDE.local.md` was updated from `/memberships + /membership-validate` to just `/memberships`. References in `orchestrate/SKILL.md` updated. Trigger: superpowers-spike 2026-06-10 pruning pass — duplicate skill with byte-identical description and overlapping content.
