# Refactor Workflow (Code Improvement)

> ♻️ **Systematic code refactoring with quality metrics and performance validation**

## Command

```bash
/orchestrate refactor
```

## Overview

Comprehensive workflow for code refactoring:
- Parallel analysis (code quality + performance + multi-tenancy)
- Architect-led refactoring plan
- TDD-based refactoring (add tests first, refactor, verify green)
- Quality gate verification

**Time**: 30-45min average
**Risk**: MEDIUM (changes existing code, but TDD ensures safety)
**Critical**: ALWAYS add tests BEFORE refactoring

## Workflow Diagram

```
┌─ PARALLEL (Analysis) ─────────────────────────────┐
│  Run 3 analysis skills concurrently:              │
│                                                    │
│  ├── code-review: Identify improvement areas      │
│  │    → Code complexity metrics                   │
│  │    → Quality metrics (maintainability)         │
│  │    → Pattern learning (bug history)            │
│  │    → Simplification suggestions                │
│  │                                                 │
│  ├── performance: Find N+1, slow queries          │
│  │    → N+1 query detection                       │
│  │    → Missing indexes                           │
│  │    → Memory issues                             │
│  │    → Slow loops/iterations                     │
│  │                                                 │
│  └── multi-tenancy: Verify scoping                │
│       → All queries facility-scoped                │
│       → No cross-facility leaks                    │
│       → Proper authorization                       │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (Plan) ───────────────────────────────┐
│  architect: Design refactoring approach           │
│    → Analyze findings from 3 skills               │
│    → Prioritize improvements (ROI-based)          │
│    → Design refactoring steps                     │
│    → Identify risks/side effects                  │
│    → Document expected outcomes                   │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (TDD Refactor) ───────────────────────┐
│  tdd: Add tests → refactor → verify green         │
│    1. RED: Write tests for current behavior       │
│    2. GREEN: Verify tests pass (baseline)         │
│    3. REFACTOR: Improve code                      │
│    4. GREEN: Verify tests still pass              │
│    5. COVERAGE: Verify 100% maintained            │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Quality Gate) ─────────────────────────┐
│  Verify improvements achieved:                    │
│                                                    │
│  ├── coverage: Verify 100%                        │
│  │    → Coverage maintained or improved           │
│  │    → No regression in test quality             │
│  │                                                 │
│  ├── performance: Verify improvements             │
│  │    → N+1 eliminated                            │
│  │    → Query count reduced                       │
│  │    → Memory usage improved                     │
│  │                                                 │
│  └── pronto: Lint changes                         │
│       → No new lint violations                    │
│       → Style guide compliance                    │
└───────────────────────────────────────────────────┘
                        ↓
┌─ OUTPUT: Refactoring Report ──────────────────────┐
│  ## Refactoring Report                            │
│                                                    │
│  ### Before Metrics                               │
│  - Complexity: X                                  │
│  - Maintainability: Y                             │
│  - Performance: Z queries                         │
│                                                    │
│  ### After Metrics                                │
│  - Complexity: X-N (improved)                     │
│  - Maintainability: Y+N (improved)                │
│  - Performance: Z-N queries (improved)            │
│                                                    │
│  ### Improvements                                 │
│  - [List of specific improvements]               │
│                                                    │
│  ### Tests                                        │
│  - X examples, 0 failures                         │
│  - Coverage: 100% maintained                      │
└───────────────────────────────────────────────────┘
```

## Why Refactor-Specific Workflow?

**Safety Through TDD**:
- Tests added BEFORE refactoring
- Ensures behavior unchanged
- Catches regressions immediately
- Safe to refactor with confidence

**Metrics-Driven**:
- Before/after measurements
- Quantifiable improvements
- ROI-based prioritization
- Objective success criteria

**Comprehensive Validation**:
- Code quality (complexity, maintainability)
- Performance (N+1, query count)
- Multi-tenancy (data isolation)
- Coverage (test quality)

## Phase Details

### Phase 1: Analysis (Parallel - 3 skills)

All 3 run simultaneously (~8-10min total):

#### 1.1 Code Review Analysis

**Skill**: `/code-review`

**What It Checks**:

**Complexity Metrics**:
```bash
# Cyclomatic complexity (decision points)
# Target: <10 (simple), 10-20 (moderate), >20 (complex)

# Cognitive complexity (mental effort to understand)
# Target: <15 (simple), 15-30 (moderate), >30 (complex)

# Nesting depth
# Target: <3 levels
```

**Quality Metrics**:
```bash
mcp__quality_metrics__analyze_file:
  file_path: "app/services/payment_service.rb"

# Returns:
# - Maintainability Index: 0-100 (higher = better)
# - Code Smells: Long methods, duplicate code, etc.
# - Suggestions: Specific improvements
```

**Pattern Learning**:
```bash
# Historical bug patterns
mcp__pattern_learning__predict_bugs:
  files: ["app/services/payment_service.rb"]

# Returns:
# - Bug-prone sections
# - Similar patterns that caused issues
# - Recommended refactorings
```

**Time**: 3-4min

---

#### 1.2 Performance Analysis

**Skill**: `/performance`

**What It Checks**:

**N+1 Queries**:
```ruby
# ❌ BEFORE (N+1)
users.each do |user|
  user.memberships.count  # Query per user
end

# ✅ AFTER (optimized)
users.includes(:memberships).each do |user|
  user.memberships.count  # Single query
end
```

**Missing Indexes**:
```sql
-- Check if index needed
EXPLAIN SELECT * FROM reservations WHERE user_id = 123;
-- If "Using filesort" or "Using temporary" → needs index
```

**Memory Issues**:
```ruby
# ❌ BEFORE (loads all into memory)
Membership.all.map(&:user_id)

# ✅ AFTER (batch processing)
Membership.pluck(:user_id)
```

**Time**: 2-3min

---

#### 1.3 Multi-Tenancy Validation

**Skill**: `/multi-tenancy`

**What It Checks**:

```ruby
# ❌ BEFORE (global query)
def user_reservations
  Reservation.where(user_id: current_user.id)
end

# ✅ AFTER (facility-scoped)
def user_reservations
  current_facility.reservations.where(user_id: current_user.id)
end
```

**Time**: 2-3min

---

**Total Phase 1 Time**: ~8-10min (parallel)

---

### Phase 2: Plan (Sequential)

**Skill**: `/architect`

**Goal**: Design systematic refactoring approach

**Planning Steps**:

#### 2.1 Prioritize Improvements

**ROI Calculation**:
```
Impact Score (1-10):
  - Complexity reduction: How much simpler?
  - Performance gain: How much faster?
  - Bug risk reduction: How much safer?

Effort Score (1-10):
  - Lines changed: How many?
  - Risk of breakage: How dangerous?
  - Test coverage needed: How much?

ROI = Impact / Effort

Priority:
  ROI >2.0 → HIGH (do now)
  ROI 1.0-2.0 → MEDIUM (do soon)
  ROI <1.0 → LOW (skip or later)
```

**Example**:
```markdown
## Refactoring Opportunities (Sorted by ROI)

### HIGH Priority (ROI ≥2.0)
1. Extract method: `process_payment` (ROI: 3.5)
   - Impact: 9 (reduces complexity from 35 to 12)
   - Effort: 2.5 (simple extraction, low risk)
   - Time: 15 minutes

2. Add includes: `users.includes(:memberships)` (ROI: 3.0)
   - Impact: 9 (eliminates N+1, 1000x faster)
   - Effort: 3 (find all locations, test)
   - Time: 20 minutes

### MEDIUM Priority (ROI 1.0-2.0)
3. Replace loop with pluck (ROI: 1.5)
   - Impact: 6 (reduces memory by 80%)
   - Effort: 4 (need to verify all usages)
   - Time: 30 minutes

### LOW Priority (ROI <1.0)
4. Rename variables (ROI: 0.5)
   - Impact: 2 (slightly clearer)
   - Effort: 4 (many references to update)
   - Time: 30 minutes (skip for now)
```

#### 2.2 Design Refactoring Steps

**For each HIGH priority improvement**:

```markdown
## Refactoring Plan: Extract `process_payment` Method

### Current State
```ruby
def create_membership
  # ... 50 lines of payment processing
  # ... mixed with membership logic
end
```

### Target State
```ruby
def create_membership
  membership = build_membership
  process_payment(membership)
  finalize_membership(membership)
end

private

def process_payment(membership)
  # ... extracted payment logic (15 lines)
end
```

### Steps
1. Add tests for current `create_membership` behavior
2. Extract payment logic to `process_payment`
3. Verify tests still pass
4. Extract membership finalization to `finalize_membership`
5. Verify tests still pass
6. Refactor extracted methods for clarity
7. Final test verification

### Risks
- Payment logic tightly coupled to membership state
- Multiple exit points (need to handle)
- Transaction boundaries (need to maintain)

### Success Criteria
- Tests pass (0 failures)
- Complexity: 35 → 12 (reduction of 23)
- Coverage: 100% maintained
- No behavior changes
```

**Time**: 5-7min

---

### Phase 3: TDD Refactor (Sequential)

**Skill**: `/tdd`

**Critical Pattern**: Tests FIRST, Refactor SECOND

#### 3.1 RED: Write Tests for Current Behavior

```ruby
# spec/services/membership_service_spec.rb
describe MembershipService do
  describe '#create_membership' do
    let(:user) { create(:user) }
    let(:plan) { create(:membership_plan_price, :weekly) }

    context 'with valid payment' do
      it 'creates membership' do
        expect {
          service.create_membership(user: user, plan: plan)
        }.to change(Membership, :count).by(1)
      end

      it 'processes payment' do
        expect {
          service.create_membership(user: user, plan: plan)
        }.to change(Payment, :count).by(1)
      end

      it 'returns success status' do
        result = service.create_membership(user: user, plan: plan)
        expect(result.success?).to be true
      end
    end

    context 'with failed payment' do
      before { allow(PaymentGateway).to receive(:charge).and_raise(PaymentError) }

      it 'does not create membership' do
        expect {
          service.create_membership(user: user, plan: plan) rescue nil
        }.not_to change(Membership, :count)
      end

      it 'returns error status' do
        result = service.create_membership(user: user, plan: plan)
        expect(result.failure?).to be true
      end
    end
  end
end
```

**Time**: 5-8min

---

#### 3.2 GREEN: Verify Tests Pass (Baseline)

```bash
bin/d rspec spec/services/membership_service_spec.rb

# Expected: All tests pass (baseline behavior)
# 8 examples, 0 failures
```

**If failures**: Fix tests until green (don't refactor yet!)

**Time**: 1-2min

---

#### 3.3 REFACTOR: Improve Code

**Example Refactoring**:

```ruby
# BEFORE (complex, 50 lines)
class MembershipService
  def create_membership(user:, plan:)
    membership = Membership.new(
      user: user,
      membership_plan_price: plan,
      facility: current_facility
    )

    # Payment processing (15 lines)
    payment_method = user.default_payment_method
    raise PaymentError, 'No payment method' unless payment_method

    gateway = PaymentGatewayFactory.for_facility(current_facility)
    result = gateway.charge(
      amount: plan.price,
      payment_method: payment_method
    )

    if result.success?
      payment = Payment.create!(
        user: user,
        amount: plan.price,
        gateway_response: result.response
      )
      membership.payment = payment
    else
      raise PaymentError, result.error_message
    end

    # Membership finalization (10 lines)
    membership.status = 'active'
    membership.acquired_at = Time.current
    membership.expires_at = Time.current + plan.duration

    if membership.save
      MembershipMailer.welcome(membership).deliver_later
      Interactor::Context.new(success: true, membership: membership)
    else
      raise MembershipError, membership.errors.full_messages
    end
  end
end

# AFTER (refactored, clear separation)
class MembershipService
  def create_membership(user:, plan:)
    membership = build_membership(user, plan)
    process_payment(membership)
    finalize_membership(membership)
    Interactor::Context.new(success: true, membership: membership)
  rescue PaymentError, MembershipError => e
    Interactor::Context.new(failure: true, error: e.message)
  end

  private

  def build_membership(user, plan)
    Membership.new(
      user: user,
      membership_plan_price: plan,
      facility: current_facility
    )
  end

  def process_payment(membership)
    payment_method = membership.user.default_payment_method
    raise PaymentError, 'No payment method' unless payment_method

    gateway = PaymentGatewayFactory.for_facility(current_facility)
    result = gateway.charge(
      amount: membership.membership_plan_price.price,
      payment_method: payment_method
    )

    raise PaymentError, result.error_message unless result.success?

    membership.payment = create_payment_record(membership, result)
  end

  def create_payment_record(membership, gateway_result)
    Payment.create!(
      user: membership.user,
      amount: membership.membership_plan_price.price,
      gateway_response: gateway_result.response
    )
  end

  def finalize_membership(membership)
    membership.status = 'active'
    membership.acquired_at = Time.current
    membership.expires_at = Time.current + membership.membership_plan_price.duration

    raise MembershipError, membership.errors.full_messages unless membership.save

    MembershipMailer.welcome(membership).deliver_later
  end
end
```

**Improvements**:
- Complexity: 35 → 12 (65% reduction)
- Maintainability: 45 → 78 (73% improvement)
- Testability: Each method testable independently
- Readability: Clear responsibilities

**Time**: 10-15min

---

#### 3.4 GREEN: Verify Tests Still Pass

```bash
bin/d rspec spec/services/membership_service_spec.rb

# Expected: All tests still pass
# 8 examples, 0 failures

# If failures → refactoring broke behavior → rollback and fix
```

**Time**: 1-2min

---

#### 3.5 COVERAGE: Verify 100% Maintained

```bash
bin/d rake 'coverage:local:file[app/services/membership_service.rb]'

# Expected: Coverage: 100% (50/50 lines)
```

**Time**: 30s

---

**Total Phase 3 Time**: ~20-30min

---

### Phase 4: Quality Gate (Parallel)

Verify improvements achieved (~5-7min total):

#### 4.1 Coverage Verification

```bash
bin/d rake 'coverage:local:delta'

# Expected: No coverage regression
# Ideally: Coverage improved (if refactoring uncovered edge cases)
```

**Time**: 1-2min

---

#### 4.2 Performance Verification

```bash
# Before refactoring:
# Query count: 1,053 queries

# After refactoring:
# Query count: 3 queries

# Improvement: 99.7% reduction ✅
```

**Time**: 2-3min

---

#### 4.3 Lint Verification

```bash
bin/d pronto run -c develop

# Expected: No new violations
# Ideally: Violations reduced (if refactoring fixed style issues)
```

**Time**: 1-2min

---

**Total Phase 4 Time**: ~5-7min (parallel)

---

## When to Use

✅ **Use this workflow for**:
- Complex code (cyclomatic complexity >20)
- Low maintainability (<50 score)
- Performance issues (N+1, slow queries)
- Code duplication (DRY violations)
- Before major features (clean foundation)
- Technical debt paydown

❌ **Don't use for**:
- New code (write well first time)
- Emergency fixes (too slow)
- Simple renaming (use IDE refactoring)
- Code that works fine (if it ain't broke...)

## Success Criteria

**ALL checks must pass**:
- ✅ Tests pass (0 failures)
- ✅ Coverage maintained (100%)
- ✅ Complexity reduced (measurable improvement)
- ✅ Performance improved (or maintained)
- ✅ Lint clean (no new violations)

**Quantifiable Improvements**:
- Complexity: Reduced by ≥30%
- Maintainability: Improved by ≥20 points
- Performance: Query count reduced by ≥50% (if N+1 existed)

**If ANY fail**: Fix or rollback refactoring

## Time Estimates

| Phase | Duration | Notes |
|-------|----------|-------|
| Analysis (parallel) | 8-10min | Code quality + performance + multi-tenancy |
| Plan | 5-7min | Architect-led design |
| TDD Refactor | 20-30min | Tests + refactor + verify |
| Quality Gate (parallel) | 5-7min | Coverage + performance + lint |
| **Total** | **40-55min** | Avg 47min |

## Example Session

```markdown
## Refactoring Session: MembershipService

### Phase 1: Analysis (Parallel - 9min)

**code-review** (4min):
- Complexity: 35 (very high)
- Maintainability: 45/100 (poor)
- Suggestions: Extract 3 methods

**performance** (3min):
- N+1 detected: `user.memberships` (1000 queries)
- Missing index: `memberships(user_id)`

**multi-tenancy** (2min):
- ✅ Clean (all queries facility-scoped)

### Phase 2: Plan (6min)

**ROI Prioritization**:
1. Extract `process_payment` (ROI: 3.5) - HIGH
2. Add `includes(:memberships)` (ROI: 3.0) - HIGH
3. Extract `finalize_membership` (ROI: 2.5) - HIGH

**Refactoring Steps**: Defined for each

### Phase 3: TDD Refactor (25min)

**Tests** (7min): 8 examples, 0 failures (baseline)
**Refactor** (15min): Extracted 3 methods
**Verify** (3min): 8 examples, 0 failures ✅

### Phase 4: Quality Gate (6min)

**coverage** (2min): 100% maintained ✅
**performance** (2min): 1053 → 3 queries (-99.7%) ✅
**pronto** (2min): Clean ✅

### Results

**Before**:
- Complexity: 35
- Maintainability: 45/100
- Queries: 1,053

**After**:
- Complexity: 12 (-66%)
- Maintainability: 78/100 (+73%)
- Queries: 3 (-99.7%)

**Total Time**: 46min

✅ Refactoring successful!
```

## Best Practices

**DO** ✅:
- Add tests BEFORE refactoring (TDD)
- Prioritize by ROI (Impact/Effort)
- Measure before/after metrics
- Refactor in small steps (verify often)
- Keep tests passing (green always)
- Document expected improvements

**DON'T** ❌:
- Refactor without tests (dangerous)
- Change behavior (tests should pass unchanged)
- Skip metrics (how else to measure success?)
- Refactor everything at once (too risky)
- Ignore performance impact

## Troubleshooting

### Issue: Tests fail after refactoring

**Solution**:
1. Rollback refactoring (git checkout)
2. Identify what changed behavior
3. Fix refactoring to maintain behavior
4. Re-verify tests

### Issue: Complexity not reduced enough

**Solution**:
1. Extract more methods (break down further)
2. Simplify conditionals (reduce branches)
3. Remove duplicate code (DRY)

### Issue: Performance regression

**Solution**:
1. Check if N+1 introduced
2. Verify includes/preload still present
3. Run query count comparison before/after

## Related Workflows

- **Before refactor**: `/orchestrate code-review` (identify issues)
- **After refactor**: `/orchestrate pre-commit` (final validation)
- **For performance**: `/orchestrate performance-optimize` (specific focus)

---

**Back to**: [orchestrate skill](../SKILL.md) | [quick reference](../quick_reference.md) | [workflows index](README.md)
