# Code Review — Worked Examples

> Extracted from `code-review/SKILL.md` to keep the skill body lean. These are the long, fully-worked
> reference examples. The skill body keeps the checklists and pointers; come here for the full walkthroughs.

---

## Example A: Method Refactoring Pattern Detection (Two-Part Check)

**When git diff shows a method being moved/renamed, must verify TWO things:**
1. All callers updated to new signature
2. New method handles nil safely

---

### Part 1: Verify All Callers Updated

```bash
# 1. Detect method refactoring (method removed from one class, added to another)
git diff develop | grep -E "^-.*def (method_name)"

# 2. Find ALL usages of old method signature
grep -rn "old_class\.method_name" app/ spec/ packs/

# Example from CORE-205:
# Method moved from MembershipPlanPrice to Membership
grep -rn "membership_plan_price\.in_pre_sale_period\?" app/ spec/
# Expected: Zero matches (all updated) OR only in historical files (migrations, changelogs)

# 3. Verify EACH usage was updated to new signature
# If grep finds matches → MUST verify each file updated to new signature
```

**Common refactoring patterns:**
- Model method moved: `membership_plan_price.method` → `membership.method`
- Service renamed: `OldService.calculate` → `NewService.calculate`
- Module relocated: `OldModule.method` → `NewModule.method`
- Helper moved: `old_helper_method` → `new_helper_method`

---

### Part 2: Validate New Method Nil Safety (CRITICAL - Added after CORE-205)

```bash
# Extract new method body and check for nil crash patterns
git diff develop <file> | grep -A20 "^+.*def method_name"

# Check for direct attribute access without nil guards:
# Look for: object.attribute or object.method() where object might be nil

# Example from CORE-205:
git diff develop app/models/membership.rb | grep -A15 "^+.*def in_pre_sale_period"
# Found: facility.current_time (CRASH if facility is nil!)
# Found: facility.current_time_zone (CRASH if facility is nil!)
# Question: Is 'facility' guaranteed non-nil?
# Fix: Add "return false if facility.blank?" BEFORE any facility.* calls
```

**Nil Safety Checklist for New/Refactored Methods:**

| Pattern | Example | Risk | Fix |
|---------|---------|------|-----|
| Direct dereference | `facility.current_time` | NoMethodError if nil | `return X if facility.blank?` |
| Chained calls | `user.profile.avatar` | Crashes on any nil | `user&.profile&.avatar` |
| String interpolation | `"#{user.name}"` | Empty if nil, crash if further call | Validate before interpolation |
| Array access | `items.first.price` | Crashes if nil | `items.first&.price` |
| Method expecting objects | `date.strftime('%Y')` | NoMethodError | Guard: `date ? date.strftime(...) : nil` |

**Validation Questions for Each Variable:**

For every variable used in new method, ask:
1. Can this be nil? (Check model associations, optional fields)
2. If yes, is there a nil guard BEFORE dereferencing?
3. Should check production data with ClickHouse (Step 12)

---

**Example Failure from CORE-205:**

```ruby
# ❌ BUGGY (what we committed - Part 1 passed, Part 2 failed):
def in_pre_sale_period?
  facility = membership_plan.owner_facility  # Can be nil!
  facility.current_time.to_date  # ← Crashes if facility is nil
  facility.current_time_zone     # ← Crashes if facility is nil
end

# ✅ FIXED (after bugbot caught it):
def in_pre_sale_period?
  facility = membership_plan.owner_facility
  return false if facility.blank?  # ← Added nil guard
  facility.current_time.to_date
end
```

**When to use:**
- ✅ ALWAYS when method removal + addition with same name in different classes
- ✅ ALWAYS when adding new methods that dereference variables
- ✅ ALWAYS when refactoring methods that call attributes/methods on objects
- ❌ Skip for purely internal private methods (only one caller)

**Production Validation (Step 12 integration):**

```sql
-- For CORE-205, should have checked:
SELECT countIf(owner_facility_id IS NULL) as null_count
FROM pbp_productionDB_optimized.membership_plans
-- If > 0, method MUST handle nil
```

---

## Example B: ClickHouse Production Data Verification Template (Step 12)

When needed, manually query ClickHouse to verify code changes against production data:

```sql
-- Database: pbp_productionDB_optimized

-- 1. Table structure verification
SELECT column_name, data_type, is_nullable
FROM system.columns
WHERE database = 'pbp_productionDB_optimized'
AND table = '<table_name>'

-- 2. Data volume (affects query performance)
SELECT count(*) as row_count
FROM pbp_productionDB_optimized.<table>

-- 3. NULL patterns (critical for .try, &., safe navigation)
SELECT
  '<field>' as field,
  count(*) as total,
  countIf(<field> IS NULL) as nulls,
  round(countIf(<field> IS NULL) / count(*) * 100, 2) as pct
FROM pbp_productionDB_optimized.<table>

-- 4. Field cardinality (affects index usefulness)
SELECT uniqExact(<field>) as unique_values
FROM pbp_productionDB_optimized.<table>

-- 5. Query that code will generate (estimate performance)
EXPLAIN
SELECT <fields>
FROM pbp_productionDB_optimized.<table>
WHERE <conditions>
```

**Performance red flags to check:**

| Pattern | ClickHouse Query | Action |
|---------|------------------|--------|
| Iterating all records | `SELECT count(*) FROM table` | If > 10k, need pagination |
| Filtering by non-indexed field | Check cardinality | Add index or change approach |
| NULL handling | Check NULL percentage | Add explicit NULL checks |
| N+1 in loops | Check related table size | Use includes/preload |

```sql
-- Example: Check if membership query will be slow
SELECT
  count(*) as total_memberships,
  countIf(status = 'active') as active,
  countIf(expires_at < now()) as expired
FROM pbp_productionDB_optimized.memberships

-- If > 100k, the code needs pagination or background job
```
