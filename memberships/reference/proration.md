# Proration — Reference (L3)

> The real proration path lives on `MembershipPlanPrice`, NOT on `Membership`.
> `Membership` has NO `calculate_proration` method and NO `current_period_start`
> column. Only `current_period_end_at` + `acquired_at` exist for date math.

## Real proration method (grounded)

`MembershipPlanPrice#prorated_price_by_date(current_date = Date.today)`
(`app/models/membership_plan_price.rb` ~lines 86-102):

> **Advisory:** the `current_date` parameter is silently overwritten on line 4 of the method body
> (`current_date = facility.current_time`). Any value you pass in is discarded; the method always
> uses facility-local time. Do not pass a date expecting it to take effect.

```ruby
def prorated_price_by_date(current_date = Date.today)
  return amount unless prorated_intervals
  return amount unless month?                       # only monthly plans prorate

  facility = membership_plan.owner_facility
  return amount unless facility.present?

  current_date = facility.current_time              # ⚠️ overwrites the parameter — caller's value is ignored
  return amount if current_date.to_date == current_date.end_of_month.to_date &&
                   interval_number_per_billing.to_i == 1

  start_of_cicle = current_date.beginning_of_month
  end_of_cicle   = start_of_cicle + interval_number_per_billing.try(interval_unit)
  days_passed    = current_date.day
  total_days     = (end_of_cicle.to_date - start_of_cicle.to_date).days.in_days

  (amount.to_d * (total_days.to_d - days_passed.to_d)) / total_days.to_d
end
```

`amount_or_prorated_price` is an alias of `prorated_price_by_date`.
`free_days` (~lines 109-121) computes the free-day count under the same guards.

Key invariants:
- Proration is **facility-timezone aware** (`facility.current_time`), not UTC.
- Only **monthly** plans prorate (`return amount unless month?`).
- Decimal math via `to_d` — never float.

## ILLUSTRATIVE time-based formula (NOT a real method)

The generic credit/charge math below is pseudo-code for understanding a plan-change
proration. It is NOT implemented on any model — do not copy column names from it.
`current_period_start` does NOT exist on `memberships`.

```ruby
# ILLUSTRATIVE ONLY — not a real method, columns may not exist
days_used      = (Date.current - period_start).to_i
days_in_period = (period_end - period_start).to_i
daily_rate_current = current_price / days_in_period
daily_rate_new     = new_plan_price / new_plan_days_in_period

credit = (days_in_period - days_used) * daily_rate_current
charge = (days_in_period - days_used) * daily_rate_new
amount_due = charge - credit
```

When grounding a cancellation refund against real columns, use
`current_period_end_at` and `acquired_at` (the only date columns that exist):

```ruby
# ILLUSTRATIVE shape using REAL column names
total_days     = (current_period_end_at - acquired_at).to_i   # NOT expires_at / started_at
remaining_days = (current_period_end_at - Time.current).to_i
(amount_paid * remaining_days / total_days).round(2)
```

## Edge cases to test
- Plan change on first day of period
- Plan change on last day of period (end-of-month guard above)
- Upgrade vs downgrade
- Same-day cancellation
- Leap year / month-length variation
- Division-by-zero guard when `total_days == 0`
