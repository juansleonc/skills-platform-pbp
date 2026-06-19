# Membership Audit — Output Template & Worked Example (L3 reference)

> Output templates for the skill (not decision logic). The skill renders these
> when producing a membership domain audit.

## Output Format

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

### Recommendations
1. Add idempotency key to renewal payment
2. Fix weekly interval comparison
```

## Worked Example

```
Claude detects membership changes:

## Membership Domain Audit

### Scanning: app/jobs/automatic_renewal_membership_job.rb

### Issue Found!

⚠️ CRITICAL: Weekly memberships excluded from renewal

# Line 15 — Current code (hypothetical; interval lives on mpp, NOT Membership)
scope = Membership.joins(membership_plan_price: :membership_plan)
                  .where(membership_plan_prices: { automatic_renewal: true })
                  .where("membership_plan_prices.interval_unit IN (?)",
                         [MembershipPlanPrice.interval_units[:month]])
# Missing: week interval_unit value → weekly memberships NOT included.

### Production Impact (ClickHouse — always FINAL)
SELECT count() FROM pbp_productionDB_optimized.memberships FINAL
WHERE aasm_state = 'active' AND deleted_at IS NULL;
-- Breakdown by interval_unit requires joining membership_plan_prices.
-- Weekly memberships affected: ~234 at risk (example figures)

### Suggested Fix (no auto_renew/interval column on Membership; interval is on mpp)
scope = Membership.joins(membership_plan_price: :membership_plan)
                  .where(membership_plan_prices: { automatic_renewal: true })
                  .where.not(aasm_state: 'cancelled')
# Filter by interval_unit on membership_plan_prices for type-specific scoping.

### Result: CRITICAL FIX NEEDED
```
