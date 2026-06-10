# Membership Changes Workflow

> 💳 **Domain-specific workflow for membership features - validates business rules and payment logic**

## Command

```bash
/orchestrate membership
```

## Overview

Specialized workflow for implementing membership-related features:
- Domain validation with membership business rules expert
- Technical validation (Sidekiq jobs, payment queries, multi-tenancy)
- Comprehensive testing for all membership types
- Idempotency verification for payment operations

**Time**: 20-25min average
**Domain**: Memberships (weekly, monthly, annual plans + auto-renewal)
**Critical**: Payment processing requires extra validation

## Workflow Diagram

```
┌─ SEQUENTIAL (Domain Analysis) ────────────────────┐
│  memberships: Validate business rules             │
│    → Membership types (weekly, monthly, annual)   │
│    → Auto-renewal logic                           │
│    → Cancellation policies                        │
│    → Proration rules                              │
│    → Payment retry patterns                       │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Technical Analysis) ───────────────────┐
│  Run 3 independent validators concurrently:       │
│                                                    │
│  ├── sidekiq: Check renewal job patterns          │
│  │    → Job idempotency                           │
│  │    → Retry logic                               │
│  │    → Ruby 3 compatibility                      │
│  │                                                 │
│  ├── performance: Check payment queries           │
│  │    → N+1 in payment lookups                    │
│  │    → Index requirements                        │
│  │    → Batch processing                          │
│  │                                                 │
│  └── multi-tenancy: Verify facility scoping       │
│       → Membership facility_id scope              │
│       → Payment facility isolation                │
│       → No cross-facility data leaks              │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (TDD) ────────────────────────────────┐
│  tdd: Test all membership types                   │
│    → Weekly membership tests                      │
│    → Monthly membership tests                     │
│    → Annual membership tests                      │
│    → Auto-renewal scenarios                       │
│    → Cancellation edge cases                      │
│    → Payment failure handling                     │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Quality) ──────────────────────────────┐
│  ├── coverage: 100% on membership code            │
│  │    → All membership service methods            │
│  │    → All payment paths covered                 │
│  │                                                 │
│  └── code-review: Verify idempotency              │
│       → Payment operations idempotent             │
│       → No duplicate charges risk                 │
│       → Rollback safety verified                  │
└───────────────────────────────────────────────────┘
                        ↓
┌─ STOP - Ready for User Commit ───────────────────┐
│  🚫 orchestrate CANNOT create commits             │
│  ✅ Tell user: "Membership code ready"            │
│  📝 Tell user: "Run /commit when ready"           │
│  ⚠️ Remind: Test in sandbox before production     │
└───────────────────────────────────────────────────┘
```

## Why Membership-Specific Workflow?

**Complex Business Rules**:
- Weekly vs monthly vs annual plans have different logic
- Auto-renewal timing varies by type
- Proration calculations are tricky
- Payment retry policies differ

**Financial Risk**:
- Bugs can cause duplicate charges ($$$ customer impact)
- Failed renewals = lost revenue
- Cancellation bugs = angry customers + refunds

**Domain Expert Needed**:
- `/memberships` skill has deep business knowledge
- Validates against actual membership rules
- Catches edge cases (e.g., weekly with nil acquired_at)

## Phase Details

### Phase 1: Domain Analysis (Sequential)

**Goal**: Validate against membership business rules BEFORE coding

**Skill Used**: `/memberships`

**What It Validates**:

| Business Rule | Validation |
|--------------|------------|
| Membership types | Weekly, monthly, annual properly handled |
| Auto-renewal | Correct timing for each type (7d, 30d, 365d) |
| Cancellation | Immediate vs end-of-period |
| Proration | Refund calculations correct |
| Payment retry | Follows retry schedule (3 attempts, 24h apart) |
| Gateway routing | Correct gateway per facility |

**Example Output**:
```markdown
## Membership Business Rules Validation

✅ Weekly memberships: Auto-renew every 7 days
✅ Monthly memberships: Auto-renew on same day each month
✅ Cancellation: Immediate (no proration)
⚠️ WARNING: New code doesn't handle nil acquired_at for weekly
❌ VIOLATION: Payment retry uses 2 attempts (should be 3)
```

**Time**: 3-5min

**Pass Criteria**: No critical violations

---

### Phase 2: Technical Analysis (Parallel - 3 Skills)

All 3 run simultaneously:

#### 2.1 Sidekiq Job Patterns

**Skill**: `/sidekiq`

**What It Checks**:
- Renewal jobs are idempotent (safe to retry)
- Ruby 3 single-hash argument pattern
- Proper error handling
- Retry configuration correct

**Example**:
```ruby
# ✅ GOOD - Idempotent
def perform(args)
  membership = Membership.find(args[:membership_id])
  return if membership.renewed_at == args[:expected_date] # Idempotency check
  membership.renew!
end

# ❌ BAD - Not idempotent
def perform(args)
  membership = Membership.find(args[:membership_id])
  membership.renew! # Could renew twice if retried
end
```

**Time**: 2-3min

---

#### 2.2 Performance Validation

**Skill**: `/performance`

**What It Checks**:
- N+1 queries in payment lookups
- Proper indexing on membership queries
- Batch processing for renewals (not one-by-one)

**Example Violations**:
```ruby
# ❌ N+1 Query
memberships.each do |m|
  m.user.email # N+1 on user lookups
end

# ✅ Fixed
memberships.includes(:user).each do |m|
  m.user.email
end
```

**Time**: 2-3min

---

#### 2.3 Multi-Tenancy Validation

**Skill**: `/multi-tenancy`

**What It Checks**:
- All membership queries scoped by facility_id
- Payment lookups facility-scoped
- No cross-facility data leakage

**Example Violations**:
```ruby
# ❌ Global query
Membership.where(user_id: user.id)

# ✅ Facility-scoped
current_facility.memberships.where(user_id: user.id)
```

**Time**: 2-3min

---

**Total Phase 2 Time**: ~3-5min (parallel)

---

### Phase 3: TDD (Sequential)

**Goal**: Comprehensive tests for all membership scenarios

**Critical Test Cases**:

#### 3.1 Membership Type Tests
```ruby
describe MembershipService do
  context 'weekly memberships' do
    it 'renews after 7 days'
    it 'handles nil acquired_at'
    it 'calculates correct renewal date'
  end

  context 'monthly memberships' do
    it 'renews on same day next month'
    it 'handles month-end dates (Jan 31 → Feb 28)'
    it 'respects timezone'
  end

  context 'annual memberships' do
    it 'renews after 365 days'
    it 'handles leap years'
  end
end
```

#### 3.2 Auto-Renewal Tests
```ruby
describe 'auto-renewal' do
  it 'charges payment method on renewal date'
  it 'retries failed payments (3 attempts, 24h apart)'
  it 'cancels after 3 failed attempts'
  it 'sends notification emails at each step'
  it 'is idempotent (safe to run multiple times)'
end
```

#### 3.3 Cancellation Tests
```ruby
describe 'cancellation' do
  it 'cancels immediately (no proration)'
  it 'stops auto-renewal job'
  it 'sends confirmation email'
  it 'does not charge on next renewal date'
end
```

#### 3.4 Edge Cases
```ruby
describe 'edge cases' do
  it 'handles nil acquired_at for weekly'
  it 'handles timezone changes (DST)'
  it 'handles expired payment methods'
  it 'handles facility changes mid-membership'
  it 'handles concurrent renewal attempts'
end
```

**Time**: 10-15min

**Pass Criteria**: All tests green, 100% coverage on membership code

---

### Phase 4: Quality (Parallel)

#### 4.1 Coverage Verification
- 100% on membership service methods
- 100% on payment paths
- Edge cases covered

**Time**: 30s

---

#### 4.2 Code Review (Idempotency Focus)

**Critical Checks**:
- ✅ Payment operations idempotent
- ✅ No duplicate charge risk
- ✅ Safe to retry on failure
- ✅ Rollback mechanism exists
- ✅ Transaction boundaries correct

**Time**: 2-3min

---

**Total Phase 4 Time**: ~3min (parallel)

---

## When to Use

✅ **Use this workflow for**:
- New membership features
- Changes to auto-renewal logic
- Payment processing updates
- Cancellation flow changes
- Proration rule modifications
- Membership plan changes

❌ **Don't use for**:
- Non-membership features (use `/orchestrate feature`)
- Simple membership display changes (skip domain validation)
- Documentation updates

## Success Criteria

**ALL checks must pass**:
- ✅ Membership business rules validated (no violations)
- ✅ Sidekiq jobs idempotent
- ✅ Performance: No N+1, proper indexes
- ✅ Multi-tenancy: All queries facility-scoped
- ✅ Tests: 100% coverage on membership code
- ✅ Code review: Idempotency verified

**If ANY fail**: Fix and re-run workflow

## Time Estimates

| Phase | Duration | Notes |
|-------|----------|-------|
| Domain Analysis | 3-5min | Membership business rules |
| Technical (parallel) | 3-5min | Sidekiq + Performance + Multi-tenancy |
| TDD | 10-15min | All membership types + edge cases |
| Quality (parallel) | 3min | Coverage + Code review |
| **Total** | **20-25min** | Avg 22min |

## Common Membership Bugs (Historical)

**Caught by this workflow**:

1. **Nil acquired_at for weekly** (caught by domain analysis)
   - Weekly memberships created without acquired_at
   - Caused nil error in renewal_date calculation

2. **Non-idempotent renewal jobs** (caught by sidekiq validation)
   - Jobs could charge twice if retried
   - Fixed with idempotency checks

3. **Month-end date handling** (caught by TDD edge cases)
   - Jan 31 → Feb 28/29 not handled
   - Caused renewal date calculation errors

4. **Cross-facility membership leak** (caught by multi-tenancy)
   - Global query returned other facilities' memberships
   - Data privacy violation

5. **N+1 in renewal batch** (caught by performance)
   - Processing 1000 renewals = 1000 separate queries
   - Fixed with batch loading

## Example Session

```markdown
## Membership Workflow: Add Annual Plans

### Phase 1: Domain Analysis
✅ memberships: Annual plan business rules validated
✅ Auto-renewal: 365 days confirmed
✅ Payment retry: 3 attempts, 24h apart (correct)
⚠️ WARNING: Need to handle leap years

### Phase 2: Technical Analysis (Parallel)
✅ sidekiq: Renewal job idempotent
✅ performance: No N+1, indexes OK
✅ multi-tenancy: All queries facility-scoped

### Phase 3: TDD
✅ Annual membership tests (8 examples)
✅ Leap year handling (2 examples)
✅ Auto-renewal tests (5 examples)
✅ Edge cases (4 examples)
Total: 19 examples, 0 failures

### Phase 4: Quality (Parallel)
✅ coverage: 100% (45/45 lines)
✅ code-review: Idempotency verified

✅ Annual membership feature complete
📝 Ready to commit

Total Time: 21min
```

## Troubleshooting

### Issue: Domain validation fails with business rule violation
**Solution**: Consult with product team, fix business logic to match requirements

### Issue: Sidekiq job not idempotent
**Solution**: Add check at start: `return if already_processed?`

### Issue: N+1 in payment lookups
**Solution**: Use `includes(:payment_method, :facility)` in queries

### Issue: Tests fail intermittently (Timecop issues)
**Solution**: Always `Timecop.freeze` in membership tests, clear after each

### Issue: ClickHouse shows duplicate renewals
**Solution**: Add unique constraint, implement idempotency key

## Best Practices

**DO** ✅:
- Test all membership types (weekly, monthly, annual)
- Always check idempotency for payment operations
- Use Timecop.freeze for time-dependent tests
- Validate business rules before coding
- Test edge cases (nil dates, leap years, timezones)

**DON'T** ❌:
- Skip domain validation (catches critical business logic errors)
- Assume payment operations are safe to retry (verify idempotency)
- Test only happy path (edge cases cause most bugs)
- Ignore performance in batch renewals (scales to 10k+ memberships)

## Related Workflows

- **Simpler**: Use `/memberships` skill standalone for consultation
- **More Complex**: `/orchestrate payment-gateway` (if adding gateway support)
- **Related**: `/orchestrate api` (if adding membership GraphQL endpoints)

## Domain Resources

- **Membership Expert**: `/memberships` skill (business rules + validation)
- **Documentation**: `docs/domains/memberships.md`
- **Schema**: `app/models/membership.rb`

---

**Back to**: [orchestrate skill](../SKILL.md) | [quick reference](../quick_reference.md) | [workflows index](README.md)
