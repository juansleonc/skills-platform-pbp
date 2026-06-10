# Production Debugging Workflow

> 🔍 **Systematic debugging for production issues using Honeybadger + ClickHouse + Code Search**

## Command

```bash
/orchestrate debug <error-description>
```

## Overview

Comprehensive workflow for debugging production issues:
- Parallel context gathering (Honeybadger + ClickHouse + Code)
- Root cause analysis from production data
- Reproduction script creation
- Debug report with fix recommendations

**Time**: 15-30min average
**Risk**: MEDIUM (read-only analysis, no code changes)
**Critical**: Always reproduce locally before fixing

## Workflow Diagram

```
┌─ PARALLEL (Gather Context) ───────────────────────┐
│  ├── debug: Honeybadger fault analysis            │
│  │    → Fault details, stack traces               │
│  │    → Error patterns, frequency                 │
│  │    → Affected users, environments              │
│  │                                                 │
│  ├── ClickHouse: Query production patterns        │
│  │    → Production data analysis                  │
│  │    → Query patterns causing issues             │
│  │    → Performance metrics                       │
│  │                                                 │
│  └── code search: Find relevant code              │
│       → Grep for error messages                   │
│       → Find related files                        │
│       → Check recent changes                      │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (Root Cause) ─────────────────────────┐
│  Analyze patterns → Identify root cause           │
│    → Correlate Honeybadger + ClickHouse           │
│    → Find common denominators                     │
│    → Identify triggering conditions               │
│    → Pinpoint exact code location                 │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (Reproduce) ──────────────────────────┐
│  Create reproduction script → Verify locally      │
│    → Write minimal reproduction                   │
│    → Test in development                          │
│    → Confirm error matches production             │
│    → Document reproduction steps                  │
└───────────────────────────────────────────────────┘
                        ↓
┌─ OUTPUT: Debug Report ────────────────────────────┐
│  ## Debug Report                                  │
│                                                    │
│  ### Issue                                        │
│  - Error: [error message]                         │
│  - Frequency: X occurrences in Y hours            │
│  - Impact: Z users affected                       │
│                                                    │
│  ### Root Cause                                   │
│  - Location: file.rb:line                         │
│  - Reason: [explanation]                          │
│  - Trigger: [conditions]                          │
│                                                    │
│  ### Reproduction                                 │
│  ```ruby                                          │
│  # Reproduction script                            │
│  ```                                              │
│                                                    │
│  ### Recommended Fix                              │
│  - Approach: [solution]                           │
│  - Risk: Low/Medium/High                          │
│  - Estimated effort: [time]                       │
│                                                    │
│  ### Next Steps                                   │
│  1. Run /orchestrate fix <issue-number>           │
│  2. Test fix in staging                           │
│  3. Monitor after deployment                      │
└───────────────────────────────────────────────────┘
```

## Why Debug-Specific Workflow?

**Complex Production Issues**:
- Multiple data sources (Honeybadger, ClickHouse, code)
- Need correlation across systems
- Production-only issues (load, data volume, race conditions)
- Can't reproduce from error message alone

**Systematic Approach Required**:
- Gather all context before analyzing
- Avoid jumping to conclusions
- Document findings for future reference
- Create reproducible test case

**Time Savings**:
- Parallel context gathering saves 50% time
- ClickHouse reveals patterns not visible in logs
- Systematic approach finds root cause faster
- Reproduction prevents "fix attempt without understanding"

## Phase Details

### Phase 1: Gather Context (Parallel - 3 sources)

All 3 run simultaneously:

#### 1.1 Honeybadger Fault Analysis

**Skill**: `/debug`

**What It Checks**:
- Fault details and stack traces
- Error frequency and patterns
- Affected users and environments
- Recent deployments correlation

**Example**:
```bash
# Get fault details
mcp__honeybadger__get_fault:
  project_id: 12345
  fault_id: 67890

# Returns:
# - Error message
# - Stack trace
# - Environment (production/staging)
# - First seen / Last seen
# - Occurrences count
# - Affected users count
```

**Time**: 2-3min

---

#### 1.2 ClickHouse Production Data

**Tool**: ClickHouse queries

**What It Checks**:
- Production query patterns
- Data distribution issues
- Performance metrics
- Temporal patterns

**Example**:
```sql
-- Find pattern in production data
SELECT
  DATE_TRUNC('hour', timestamp) as hour,
  COUNT(*) as error_count,
  COUNT(DISTINCT user_id) as affected_users
FROM error_logs
WHERE error_message LIKE '%NilClass%'
  AND timestamp > NOW() - INTERVAL 24 HOUR
GROUP BY hour
ORDER BY error_count DESC;

-- Identify common characteristics
SELECT
  facility_id,
  membership_type,
  COUNT(*) as occurrences
FROM membership_errors
WHERE error_class = 'NoMethodError'
GROUP BY facility_id, membership_type
HAVING COUNT(*) > 10
ORDER BY occurrences DESC;
```

**Time**: 2-3min

---

#### 1.3 Code Search

**Tools**: Grep, Glob, Read

**What It Checks**:
- Files containing error message
- Related code sections
- Recent changes (git log)
- Similar patterns in codebase

**Example**:
```bash
# Find error message in code
Grep: pattern="renewal_date.*NilClass"
  → app/models/membership.rb:45
  → app/services/membership_renewal_service.rb:123

# Check recent changes
Bash: git log --oneline --since="1 week ago" -- app/models/membership.rb
  → 3 commits in last week

# Read relevant files
Read: app/models/membership.rb
Read: app/services/membership_renewal_service.rb
```

**Time**: 2-3min

---

**Total Phase 1 Time**: ~3-5min (parallel)

---

### Phase 2: Root Cause Analysis (Sequential)

**Goal**: Correlate findings from all 3 sources to identify exact cause

**Analysis Steps**:

1. **Pattern Correlation**:
   ```
   Honeybadger: NoMethodError on `renewal_date`
   ClickHouse: Only weekly memberships affected
   Code: membership.rb:45 calls `acquired_at.strftime`

   → Conclusion: Weekly memberships missing acquired_at
   ```

2. **Triggering Conditions**:
   ```
   When: After signup, before first payment
   Who: Weekly plans only
   Why: Signup flow doesn't set acquired_at for weekly
   ```

3. **Code Location**:
   ```ruby
   # app/models/membership.rb:45
   def renewal_date
     acquired_at.strftime('%Y-%m-%d')  # Crashes if nil
   end
   ```

4. **Impact Assessment**:
   ```
   Severity: HIGH (blocks renewals)
   Frequency: 50 errors/day
   Users: ~200 weekly members affected
   ```

**Time**: 3-5min

**Output**: Clear root cause statement with evidence

---

### Phase 3: Reproduce (Sequential)

**Goal**: Create minimal script that reproduces the issue

**Reproduction Pattern**:

```ruby
#!/usr/bin/env rails runner
# tmp/debug_weekly_renewal.rb

# Setup
facility = Facility.first
user = User.first

# Create membership WITHOUT acquired_at (reproduces production)
membership = Membership.new(
  user: user,
  facility: facility,
  membership_plan_price: MembershipPlanPrice.weekly.first
)
membership.save(validate: false)  # Skip validations

# Trigger error
begin
  puts "Testing renewal_date..."
  date = membership.renewal_date  # Should crash
  puts "ERROR: Expected crash but got: #{date}"
rescue NoMethodError => e
  puts "✅ Reproduced: #{e.message}"
  puts "   Stack trace: #{e.backtrace.first}"
end

# Cleanup
membership.destroy
```

**Verification**:
```bash
bin/d rails runner tmp/debug_weekly_renewal.rb

# Expected output:
# Testing renewal_date...
# ✅ Reproduced: undefined method `strftime' for nil:NilClass
#    Stack trace: app/models/membership.rb:45:in `renewal_date'
```

**Time**: 3-5min

---

### Phase 4: Debug Report (Output)

**Goal**: Document findings and recommend fix

**Report Template**:

```markdown
## Debug Report: Weekly Membership Renewal Crash

**Date**: 2026-01-27
**Issue**: NoMethodError on weekly membership renewals
**Honeybadger**: Fault #67890
**GitHub Issue**: #1234 (if exists)

---

### Issue Summary

**Error**: `undefined method 'strftime' for nil:NilClass`
**Location**: `app/models/membership.rb:45` in `renewal_date` method
**Frequency**: 50 occurrences/day (increasing)
**Impact**: 200+ weekly members cannot renew

---

### Root Cause

Weekly memberships created during signup don't have `acquired_at` set.

**Evidence**:
1. **Honeybadger**: 100% of errors are weekly plans
2. **ClickHouse**:
   ```sql
   SELECT COUNT(*) FROM memberships
   WHERE plan_type = 'weekly' AND acquired_at IS NULL;
   -- Result: 237 memberships
   ```
3. **Code**: `renewal_date` assumes `acquired_at` is always present

**Trigger**: Signup flow for weekly plans doesn't set `acquired_at`

---

### Reproduction

**Script**: `tmp/debug_weekly_renewal.rb`

```ruby
membership = Membership.new(
  membership_plan_price: MembershipPlanPrice.weekly.first
)
membership.save(validate: false)
membership.renewal_date  # Crashes
```

**Confirmed**: ✅ Reproduces in development

---

### Recommended Fix

**Approach**: Add nil check in `renewal_date` method

```ruby
# app/models/membership.rb:45
def renewal_date
  return nil unless acquired_at  # Guard clause
  acquired_at.strftime('%Y-%m-%d')
end

# OR use safe navigation
def renewal_date
  acquired_at&.strftime('%Y-%m-%d')
end

# OR default to Time.current
def renewal_date
  (acquired_at || Time.current).strftime('%Y-%m-%d')
end
```

**Risk**: LOW (defensive code, no behavior change for valid data)
**Effort**: 5 minutes (1 line change + test)

---

### Data Fix (Optional)

**Backfill missing acquired_at**:
```ruby
Membership.where(acquired_at: nil, plan_type: 'weekly').find_each do |m|
  m.update_column(:acquired_at, m.created_at)
end
```

**Risk**: MEDIUM (updates production data)
**Should**: Test in staging first

---

### Next Steps

1. ✅ Run `/orchestrate fix 1234` to implement fix with tests
2. ⏳ Deploy to staging and verify
3. ⏳ Monitor Honeybadger after production deploy
4. ⏳ Consider data backfill (separate PR)

---

### Lessons Learned

- Weekly memberships have different lifecycle than monthly/annual
- Signup flow needs validation for required timestamps
- Add validation: `validates :acquired_at, presence: true`
- Consider factory trait: `:invalid_weekly` for testing edge cases
```

**Time**: 5-7min

**Total Workflow Time**: ~15-25min

---

## When to Use

✅ **Use this workflow for**:
- Production errors from Honeybadger
- Complex issues needing data analysis
- Intermittent or pattern-based bugs
- Issues affecting specific user segments
- Performance degradation investigation

❌ **Don't use for**:
- Simple bugs with obvious cause (use `/orchestrate fix` directly)
- Development-only issues
- Already understood issues (skip to fix)

## Success Criteria

**ALL steps must complete**:
- ✅ Root cause identified with evidence
- ✅ Reproduction script works locally
- ✅ Debug report documents findings
- ✅ Fix approach recommended with risk assessment

**If ANY fail**: Continue investigation, gather more data

## Time Estimates

| Phase | Duration | Notes |
|-------|----------|-------|
| Gather Context (parallel) | 3-5min | Honeybadger + ClickHouse + Code |
| Root Cause Analysis | 3-5min | Correlate findings |
| Reproduce | 3-5min | Create minimal script |
| Debug Report | 5-7min | Document everything |
| **Total** | **15-25min** | Avg 20min |

## Common Debugging Patterns

### 1. Nil Errors

**Pattern**: NoMethodError on nil
**Investigation**:
1. ClickHouse: Find records with nil value
2. Code: Check default values, validations
3. Reproduce: Create record without value

**Example**:
```sql
SELECT COUNT(*), facility_id
FROM memberships
WHERE acquired_at IS NULL
GROUP BY facility_id;
```

---

### 2. Race Conditions

**Pattern**: Intermittent errors, timing-dependent
**Investigation**:
1. Honeybadger: Check occurrence times
2. ClickHouse: Look for concurrent operations
3. Code: Find shared state mutations

**Example**:
```sql
SELECT
  user_id,
  COUNT(*) as concurrent_renewals
FROM membership_renewals
WHERE created_at > NOW() - INTERVAL 1 HOUR
GROUP BY user_id, DATE_TRUNC('second', created_at)
HAVING COUNT(*) > 1;
```

---

### 3. Data Corruption

**Pattern**: Invalid state in production
**Investigation**:
1. ClickHouse: Find invalid records
2. Code: Check how state transitions
3. Reproduce: Replicate state machine

**Example**:
```sql
SELECT * FROM memberships
WHERE status = 'active'
  AND expires_at < NOW()
LIMIT 10;
```

---

### 4. Performance Degradation

**Pattern**: Slow queries, timeouts
**Investigation**:
1. Honeybadger: Timeout errors
2. ClickHouse: Query execution times
3. Code: N+1, missing indexes

**Example**:
```sql
SELECT
  query_hash,
  AVG(query_duration_ms) as avg_ms,
  COUNT(*) as executions
FROM query_logs
WHERE timestamp > NOW() - INTERVAL 1 HOUR
GROUP BY query_hash
HAVING AVG(query_duration_ms) > 1000
ORDER BY avg_ms DESC;
```

---

## MCP Tools Used

| Tool | Purpose | Phase |
|------|---------|-------|
| `mcp__honeybadger__get_fault` | Get fault details | Context |
| `mcp__honeybadger__list_faults` | List recent faults | Context |
| `mcp__clickhouse__run_select_query` | Production data analysis | Context |
| `Grep` | Search code for patterns | Context |
| `Read` | Read relevant files | Context |
| `Bash` | Run reproduction scripts | Reproduce |

## Best Practices

**DO** ✅:
- Gather ALL context before analyzing (don't jump to conclusions)
- Use ClickHouse to validate hypotheses
- Create minimal reproduction (not full production scenario)
- Document every finding in debug report
- Test reproduction in development first
- Include evidence (queries, stack traces, data samples)

**DON'T** ❌:
- Skip reproduction (even if cause seems obvious)
- Fix without understanding root cause
- Ignore ClickHouse patterns (data reveals truth)
- Modify production data during debugging
- Rush to fix without documenting

## Example Session

```markdown
## Debug Session: Membership Renewal Crash

### Phase 1: Gather Context (Parallel - 5min)

**Honeybadger (2min)**:
- Fault #67890: NoMethodError 'strftime' for nil:NilClass
- Location: app/models/membership.rb:45
- Frequency: 50/day (increasing)
- Users: 200+ affected

**ClickHouse (2min)**:
```sql
SELECT plan_type, COUNT(*)
FROM memberships
WHERE acquired_at IS NULL;

-- Result: 237 weekly, 0 monthly, 0 annual
```

**Code Search (1min)**:
- Found: app/models/membership.rb:45
- Method: `renewal_date`
- Recent changes: None in 3 months

### Phase 2: Root Cause (3min)

**Analysis**:
- Only weekly plans affected
- acquired_at is nil
- Code calls strftime without nil check

**Conclusion**: Weekly signup doesn't set acquired_at

### Phase 3: Reproduce (4min)

**Script**: Created tmp/debug_weekly_renewal.rb
**Result**: ✅ Reproduced locally

### Phase 4: Report (5min)

**Recommendation**: Add nil guard in renewal_date
**Risk**: LOW
**Effort**: 5 minutes

**Total Time**: 17min

✅ Ready to run /orchestrate fix 1234
```

## Troubleshooting

### Issue: Can't reproduce locally

**Solution**:
1. Check if production data needed
2. Use ClickHouse to get actual data samples
3. May need specific facility/plan configuration

### Issue: Root cause unclear from Honeybadger alone

**Solution**:
1. Query ClickHouse for patterns
2. Check recent deployments
3. Look for common factors in affected users

### Issue: Too many possible causes

**Solution**:
1. Eliminate causes systematically
2. Use ClickHouse to test hypotheses
3. Create reproduction for each theory

### Issue: Honeybadger/ClickHouse unavailable

**Solution**:
1. Use logs as fallback
2. Check Sentry (if available)
3. May need to debug without production data

## Related Workflows

- **After debug**: `/orchestrate fix <issue-number>` (implement fix)
- **For simple bugs**: `/orchestrate fix` (skip debug phase)
- **For performance**: `/orchestrate performance-optimize`

---

**Back to**: [orchestrate skill](../SKILL.md) | [quick reference](../quick_reference.md) | [workflows index](README.md)
