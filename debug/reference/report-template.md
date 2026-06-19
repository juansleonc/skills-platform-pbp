# debug/reference/report-template.md — Debug Report Format + Worked Session

> Relocated from SKILL.md. Use this layout to write up a debug session.

---

## Report Layout

````markdown
## Debug Report: [Issue Title]

### Error Summary
- **Honeybadger Fault**: #12345
- **Sentry Issue**: PLATFORM-789 (if applicable)
- **First Seen**: 2024-01-20 14:30 UTC
- **Occurrences**: 156
- **Affected Facilities**: Daisy Hill, Alex Hills

### Error Details
```
NoMethodError: undefined method `expires_at' for nil:NilClass
  app/services/membership_service.rb:45:in `renew'
  app/jobs/automatic_renewal_job.rb:23:in `perform'
```

### ClickHouse Analysis
```sql
-- Found 234 memberships with NULL membership_plan
SELECT count(*) FROM pbp_productionDB_optimized.memberships FINAL WHERE membership_plan_id IS NULL;
```

### Root Cause
Memberships created via API without membership_plan validation.

### Reproduction
```ruby
membership = Membership.new(user: user, facility: facility)
membership.save(validate: false)  # This creates invalid record
membership.renew!  # Fails here
```

### Fix
1. Add validation for membership_plan_id
2. Backfill existing records
3. Add NOT NULL constraint after backfill

### Verification
- [ ] Test passes locally
- [ ] Deployed to staging
- [ ] Error rate decreased in Honeybadger
````

---

## Worked Example — Full Session

```
User reports: "Memberships not renewing"

## Debug Session

### Step 1: Honeybadger
mcp__honeybadger__list_faults: "membership renewal"

Found: Fault #8901 - "NoMethodError in AutomaticRenewalMembershipJob"
- 45 occurrences in last 24 hours
- Started: 2024-01-20 after deploy

### Step 2: ClickHouse Analysis

SELECT interval, count(*), countIf(auto_renew = 1) as should_renew
FROM pbp_productionDB_optimized.memberships FINAL
WHERE status = 'active' AND expires_at < now()
GROUP BY interval;

Result:
| interval | count | should_renew |
|----------|-------|--------------|
| weekly   | 234   | 234          |
| monthly  | 45    | 45           |

234 weekly memberships should have renewed but didn't!

### Step 3: Code Analysis

# AutomaticRenewalMembershipJob line 15
scope = Membership.renewable
                  .where(interval: ['monthly', 'annual'])

BUG FOUND: 'weekly' is not in the interval list!

### Step 4: Fix

scope = Membership.renewable
                  .where(interval: ['weekly', 'monthly', 'annual'])

### Step 5: Verification
- Added test for weekly renewals
- Deployed fix
- Manually triggered renewal for affected memberships
- Honeybadger shows 0 new occurrences

### Resolution: FIXED
```
