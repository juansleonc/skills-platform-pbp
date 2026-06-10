# Coverage Improvement Workflow

> 📊 **Autonomous test coverage improvement with 100% target**

## Command

```bash
/orchestrate coverage
```

## Overview

Autonomous workflow for improving test coverage:
- Find uncovered files automatically
- Write specs in parallel (up to 3 files simultaneously)
- Validate specs before running
- Verify 100% coverage achieved
- Loop autonomously until user stops

**Time**: Variable (5-10min per file)
**Risk**: LOW (only adds tests, no production code changes)
**Critical**: ALWAYS validate specs before running (prevents factory explosions)

## Workflow Diagram

```
┌─ SEQUENTIAL (Find Targets) ───────────────────────┐
│  coverage: Find uncovered files                   │
│    → Run rake 'coverage:local:uncovered[10]'      │
│    → Sort by: lines uncovered (highest first)     │
│    → Filter: Skip vendors, specs, migrations      │
│    → Select: Top 3 files for parallel processing  │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Write Specs - up to 3) ────────────────┐
│  For each uncovered file (process 3 at a time):   │
│                                                    │
│  ├── File 1: Write spec → validate → run          │
│  │    1. Read file, understand logic              │
│  │    2. Write comprehensive spec                 │
│  │    3. Validate: rake 'coverage:validate:quick' │
│  │    4. Run: bin/d rspec spec/...                │
│  │    5. Check delta: rake 'coverage:local:delta' │
│  │                                                 │
│  ├── File 2: Write spec → validate → run          │
│  │    [Same process as File 1]                    │
│  │                                                 │
│  └── File 3: Write spec → validate → run          │
│       [Same process as File 1]                    │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (Verify) ─────────────────────────────┐
│  coverage: Verify all at 100%                     │
│    → Run rake 'coverage:local:file[path]'         │
│    → Expect: "Coverage: 100%"                     │
│    → If <100%: Add missing tests                  │
│    → Re-run until 100%                            │
└───────────────────────────────────────────────────┘
                        ↓
┌─ LOOP: Continue or Stop ──────────────────────────┐
│  IF uncovered files remain:                       │
│    → Ask user: "Continue? (3 more files ready)"   │
│    → If yes: Loop to Find Targets                 │
│    → If no: STOP, show summary                    │
│  ELSE:                                            │
│    → ✅ All files covered!                        │
│    → Show final stats                             │
└───────────────────────────────────────────────────┘
```

## Why Coverage-Specific Workflow?

**Autonomous Loop**:
- Continues until user stops
- Processes 3 files at a time (parallel)
- No manual intervention needed
- Consistent quality (validation enforced)

**Factory Rules Enforcement**:
- Validation BEFORE running specs
- Prevents factory explosions (`create` vs `build`)
- Enforces best practices automatically
- Catches forbidden patterns early

**Efficiency**:
- Parallel processing (3 files = 3x faster)
- Prioritizes high-impact files (most uncovered lines)
- Skips vendors, specs, migrations
- Delta validation (only changed lines)

## Phase Details

### Phase 1: Find Targets (Sequential)

**Goal**: Identify top 3 uncovered files

**Commands**:
```bash
# Find uncovered files
bin/d rake 'coverage:local:uncovered[10]'

# Returns (sorted by uncovered lines):
# app/models/membership.rb: 45 lines uncovered
# app/services/payment_service.rb: 38 lines uncovered
# app/controllers/api/reservations_controller.rb: 32 lines uncovered
# ... (up to 10 files)
```

**Selection Logic**:
1. Sort by uncovered lines (descending)
2. Filter out:
   - `vendor/` (dependencies)
   - `spec/` (test files)
   - `db/migrate/` (migrations)
   - `config/` (configuration)
3. Select top 3 for parallel processing

**Time**: 30 seconds

---

### Phase 2: Write Specs (Parallel - up to 3 files)

Process 3 files simultaneously:

#### 2.1 Read & Understand

**For each file**:
```bash
# Read the file
Read: app/models/membership.rb

# Understand:
# - Class structure
# - Public methods
# - Validations
# - Associations
# - Callbacks
# - Business logic
```

**Time per file**: 1-2min

---

#### 2.2 Write Comprehensive Spec

**Test Categories**:

1. **Validations**:
```ruby
describe 'validations' do
  it { should validate_presence_of(:user) }
  it { should validate_presence_of(:facility) }

  it 'requires acquired_at for weekly plans' do
    membership = build(:membership, :weekly, acquired_at: nil)
    expect(membership).not_to be_valid
    expect(membership.errors[:acquired_at]).to include("can't be blank")
  end
end
```

2. **Associations**:
```ruby
describe 'associations' do
  it { should belong_to(:user) }
  it { should belong_to(:facility) }
  it { should have_many(:membership_payments) }
end
```

3. **Methods**:
```ruby
describe '#renewal_date' do
  context 'with weekly plan' do
    let(:membership) { create(:membership, :weekly, acquired_at: Time.current) }

    it 'returns date 7 days from acquired_at' do
      Timecop.freeze(Time.current) do
        expect(membership.renewal_date).to eq((Time.current + 7.days).strftime('%Y-%m-%d'))
      end
    end
  end

  context 'without acquired_at' do
    let(:membership) { build(:membership, :weekly, acquired_at: nil) }

    it 'returns nil' do
      expect(membership.renewal_date).to be_nil
    end
  end
end
```

4. **Scopes**:
```ruby
describe 'scopes' do
  describe '.active' do
    let!(:active_membership) { create(:membership, status: 'active') }
    let!(:inactive_membership) { create(:membership, status: 'cancelled') }

    it 'returns only active memberships' do
      expect(Membership.active).to include(active_membership)
      expect(Membership.active).not_to include(inactive_membership)
    end
  end
end
```

**Time per file**: 5-8min

---

#### 2.3 Validate Spec (MANDATORY)

**CRITICAL**: Always validate BEFORE running:

```bash
# Validate spec for factory rules
bin/d rake 'coverage:validate:quick[spec/models/membership_spec.rb]'

# Checks for:
# ❌ allow_any_instance_of (FORBIDDEN)
# ❌ expect_any_instance_of (FORBIDDEN)
# ❌ create(:factory, id: 1) (hardcoded IDs)
# ❌ Time.now (use Time.current)
# ❌ before(:all) with create (use before(:each))
# ✅ Proper factory usage (build > build_stubbed > create)
```

**If validation fails**:
1. Fix violations immediately
2. Re-validate
3. Do NOT run specs until validation passes

**Why**: Prevents factory explosions (1 test creating 40+ records = slow CI)

**Time per file**: 30 seconds

---

#### 2.4 Run Spec

```bash
# Run the spec
bin/d rspec spec/models/membership_spec.rb

# Expected output:
# 15 examples, 0 failures
```

**If failures**:
1. Read failure messages
2. Fix spec logic
3. Re-run until green

**Time per file**: 1-2min

---

#### 2.5 Check Delta Coverage

```bash
# Verify coverage improved
bin/d rake 'coverage:local:delta'

# Returns:
# Files with coverage changes:
# + app/models/membership.rb: 0% → 100% (+100%)
```

**Expected**: 100% coverage on the file

**If <100%**:
1. Identify uncovered lines
2. Add missing tests
3. Re-run until 100%

**Time per file**: 30 seconds

---

**Total Phase 2 Time**: ~15-25min (for 3 files in parallel)

---

### Phase 3: Verify (Sequential)

**Goal**: Confirm 100% coverage on all modified files

**Command**:
```bash
# Verify specific file
bin/d rake 'coverage:local:file[app/models/membership.rb]'

# Expected output:
# Coverage: 100% (45/45 lines)
```

**If <100%**:
1. Show uncovered line numbers
2. Add tests for missing lines
3. Re-run verification

**Time**: 1-2min

---

### Phase 4: Loop or Stop

**Decision Point**:

```
IF uncovered files remain:
  "✅ Completed 3 files. 7 files still need coverage.
   Continue with next 3? (y/n)"

  IF user says yes:
    → Loop back to Phase 1: Find Targets

  IF user says no:
    → Show summary and STOP

ELSE:
  "🎉 All files covered! Project coverage: 98.5%"
  → STOP
```

**Summary Output**:
```markdown
## Coverage Improvement Summary

**Session Duration**: 45 minutes
**Files Processed**: 9 files
**Specs Created**: 9 files
**Tests Added**: 127 examples
**Coverage Gained**: +12.3% (86.2% → 98.5%)

### Files Covered
1. ✅ app/models/membership.rb (0% → 100%)
2. ✅ app/services/payment_service.rb (0% → 100%)
3. ✅ app/controllers/api/reservations_controller.rb (0% → 100%)
4. ✅ app/models/notification.rb (45% → 100%)
5. ✅ app/services/membership_renewal_service.rb (0% → 100%)
6. ✅ app/models/clinic_lesson.rb (0% → 100%)
7. ✅ app/models/rule.rb (30% → 100%)
8. ✅ app/models/reservation.rb (75% → 100%)
9. ✅ app/workers/clean_file_exports_worker.rb (0% → 100%)

### Remaining Uncovered (3 files)
- app/adapters/utm_conversions_adapter.rb (23 lines)
- packs/orgs/app/services/sso/saml_metadata_parser.rb (18 lines)
- app/controllers/api/v1/accounts_receivables_controller.rb (15 lines)

**Next Session**: Run `/orchestrate coverage` again to finish remaining files
```

---

## Factory Rules (MANDATORY)

### Rule 1: build > build_stubbed > create

| Method | Use When | Speed |
|--------|----------|-------|
| `build(:factory)` | DEFAULT - validations, methods, attributes | Fast |
| `build_stubbed(:factory)` | When code needs `id` or `persisted?` | Fast |
| `create(:factory)` | ONLY for scopes, queries, DB operations | Slow |

**Example**:
```ruby
# ✅ GOOD - Testing validation
it 'validates presence of name' do
  user = build(:user, name: nil)  # build, not create
  expect(user).not_to be_valid
end

# ✅ GOOD - Testing scope (needs DB)
it 'returns active users' do
  active = create(:user, active: true)  # create for scope
  inactive = create(:user, active: false)
  expect(User.active).to eq([active])
end

# ❌ BAD - Unnecessary create
it 'returns full name' do
  user = create(:user, first_name: 'John')  # Should use build
  expect(user.full_name).to eq('John Doe')
end
```

### Rule 2: Facility with :skip_callbacks

```ruby
# ❌ BAD - Creates 40+ records
let(:facility) { create(:facility) }

# ✅ GOOD - Skips merchants, courts, products
let(:facility) { create(:facility, :skip_callbacks) }
```

**Unless**: You specifically need merchants/courts/products for the test

### Rule 3: Forbidden Patterns

```ruby
# ❌ NEVER use
allow_any_instance_of(User)
expect_any_instance_of(User)
create(:user, id: 1)  # Hardcoded ID
Time.now  # Use Time.current
Date.today  # Use Date.current
before(:all) { create(:user) }  # Use before(:each)
```

### Rule 4: Time-Dependent Tests

```ruby
# ✅ ALWAYS use Timecop with Time.current
Timecop.freeze(Time.current) do
  membership = create(:membership, acquired_at: Time.current)
  expect(membership.renewal_date).to eq((Time.current + 7.days).strftime('%Y-%m-%d'))
end
```

---

## When to Use

✅ **Use this workflow for**:
- Improving project coverage systematically
- Adding tests to legacy code
- Reaching 100% coverage target
- Autonomous test generation (minimal supervision)

❌ **Don't use for**:
- New feature development (use `/orchestrate feature` instead)
- Bug fixes (use `/orchestrate fix` instead)
- Single file coverage (use `/coverage` skill directly)

## Success Criteria

**ALL files must reach**:
- ✅ 100% line coverage
- ✅ Specs validated (factory rules)
- ✅ All tests green
- ✅ No forbidden patterns

**If ANY fail**: Fix and re-run until passing

## Time Estimates

| Phase | Duration | Notes |
|-------|----------|-------|
| Find Targets | 30s | Top 3 uncovered files |
| Write Specs (parallel) | 15-25min | 3 files × 5-8min each |
| Verify | 1-2min | Check 100% achieved |
| **Per Iteration** | **20-30min** | 3 files per iteration |

**Total Session**: Variable (depends on uncovered files remaining)
- 10 files = ~3 iterations = ~60-90min
- 3 files = 1 iteration = ~20-30min

## Example Session

```markdown
## Coverage Session - 2026-01-27

### Iteration 1 (3 files - 22min)

**Find Targets (30s)**:
1. app/models/membership.rb (45 lines uncovered)
2. app/services/payment_service.rb (38 lines)
3. app/controllers/api/reservations_controller.rb (32 lines)

**Write Specs (parallel - 18min)**:
- ✅ membership_spec.rb: 15 examples, 0 failures (100% coverage)
- ✅ payment_service_spec.rb: 22 examples, 0 failures (100% coverage)
- ✅ api/reservations_controller_spec.rb: 18 examples, 0 failures (100% coverage)

**Verify (1min)**:
- ✅ All 3 files at 100%

**Coverage Gain**: +8.5% (89.7% → 98.2%)

---

### Continue? (y/n)

User: y

---

### Iteration 2 (3 files - 25min)

**Find Targets (30s)**:
1. app/models/notification.rb (28 lines)
2. app/services/membership_renewal_service.rb (24 lines)
3. app/models/clinic_lesson.rb (22 lines)

**Write Specs (parallel - 21min)**:
- ✅ notification_spec.rb: 12 examples, 0 failures (100%)
- ✅ membership_renewal_service_spec.rb: 18 examples, 0 failures (100%)
- ✅ clinic_lesson_spec.rb: 14 examples, 0 failures (100%)

**Verify (1min)**:
- ✅ All 3 files at 100%

**Coverage Gain**: +3.8% (98.2% → 102.0% - wait, that's impossible)
**Actual**: 98.2% → 99.1%

---

### Summary

**Total Time**: 47 minutes
**Files Covered**: 6 files
**Tests Added**: 99 examples
**Coverage Gain**: +9.4% (89.7% → 99.1%)

✅ Excellent progress! Only 2 files remaining.
```

## Troubleshooting

### Issue: Validation fails (factory explosion)

**Error**:
```bash
❌ VIOLATION: Using create(:facility) without :skip_callbacks
   Line 12: let(:facility) { create(:facility) }
```

**Solution**:
```ruby
# Change to:
let(:facility) { create(:facility, :skip_callbacks) }

# OR if you need merchants/courts:
let(:facility) { create(:facility) }  # OK if intentional
```

### Issue: Coverage not reaching 100%

**Problem**: SimpleCov shows 95%, but uncovered lines not visible

**Solution**:
```bash
# Run with detailed report
docker compose exec -e SIMPLECOV_REPORT=true web bundle exec rspec spec/path_spec.rb  # bin/d rspec for plain run

# Check tmp/coverage/index.html in browser
# Shows exact uncovered line numbers
```

### Issue: Tests slow (>10s per file)

**Problem**: Too many `create` calls

**Solution**:
1. Check validation output for create violations
2. Replace with `build` where possible
3. Use `:skip_callbacks` for facilities

### Issue: Time-dependent tests intermittent

**Problem**: Tests pass sometimes, fail other times

**Solution**:
```ruby
# Always freeze time
Timecop.freeze(Time.current) do
  # test code here
end
```

## Best Practices

**DO** ✅:
- Validate specs before running (prevents factory explosions)
- Use `build` by default, `create` only when necessary
- Always `Timecop.freeze` for time-dependent tests
- Test all public methods, validations, scopes
- Process files in parallel (3 at a time)
- Loop autonomously until user stops

**DON'T** ❌:
- Skip validation (catches forbidden patterns)
- Use `create` for validation tests (use `build`)
- Hardcode time values (use `Time.current`)
- Test private methods (test public interface)
- Process one file at a time (slow)

## Related Workflows

- **Before coverage**: `/orchestrate feature` (adds coverage as part of TDD)
- **After coverage**: `/orchestrate pre-commit` (verify overall quality)
- **For single file**: Use `/coverage` skill directly (faster)

---

**Back to**: [orchestrate skill](../SKILL.md) | [quick reference](../quick_reference.md) | [workflows index](README.md)
