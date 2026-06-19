---
name: factory-check
description: Detects suboptimal factory usage patterns that slow down tests. Analyzes specs to suggest build vs create optimizations and estimates performance impact.
allowed-tools: [Bash, Read, Grep, Glob, Agent, Edit]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

# Factory Optimization Skill

Automatically detects slow factory patterns in test files and suggests performance optimizations.

## CRITICAL RULES

1. **`build(:factory)` is DEFAULT** - 10-100x faster than `create`
2. **`create` ONLY for DB operations** - scopes, queries, uniqueness, callbacks
3. **`build_stubbed` for IDs** - When code checks `id` or `persisted?`
4. **`create(:facility, :skip_callbacks)` for facilities** - Saves 40+ DB records

## Shared References

> **📚 This skill uses shared documentation. See:**
> - [Factory Rules](../shared/factory-rules.md) - Complete decision tree
> - [Forbidden Patterns](../shared/forbidden-patterns.md) - Patterns to avoid
> - [Testing Patterns](../shared/testing-patterns.md) - Best practices
> - [Code Simplifier Integration](../shared/code-simplifier-integration.md) - Auto-optimization with AI (Tier 3: OPTIONAL)

## Quick Decision Tree

```
┌─────────────────────────────────────────────────────┐
│ Does the test query the database?                  │
│  - .where, .find, .exists?, scopes                 │
└─────────────┬───────────────────────────────────────┘
              │
         NO ──┼── YES → use create(:factory)
              │
              ↓
┌─────────────────────────────────────────────────────┐
│ Does code check .id or .persisted?                 │
└─────────────┬───────────────────────────────────────┘
              │
         NO ──┼── YES → use build_stubbed(:factory)
              │
              ↓
        use build(:factory) ✅ FASTEST
```

## Workflow

### Step 1: Scan for Slow Patterns

```bash
# Run in Docker
bin/d ruby -e "
require './lib/factory_checker'
FactoryChecker.analyze('spec/models/user_spec.rb')
"

# Or scan all changed specs
git diff develop --name-only | grep _spec.rb | while read file; do
  bin/d ruby -e "
    require './lib/factory_checker'
    FactoryChecker.analyze('$file')
  "
done
```

### Step 2: Analyze Patterns

The checker detects these anti-patterns:

#### Pattern 1: create() for validations
```ruby
# ❌ SLOW - 50-100ms per create
it 'validates presence of name' do
  user = create(:user, name: nil)
  expect(user).not_to be_valid
end

# ✅ FAST - <1ms
it 'validates presence of name' do
  user = build(:user, name: nil)
  expect(user).not_to be_valid
end

# Impact: 50-100ms saved per test × 100 tests = 5-10 seconds
```

#### Pattern 2: create() for method calls
```ruby
# ❌ SLOW - Creates 40+ records for facility
it 'returns full name' do
  user = create(:user, first_name: 'John', last_name: 'Doe')
  expect(user.full_name).to eq('John Doe')
end

# ✅ FAST - No DB hit
it 'returns full name' do
  user = build(:user, first_name: 'John', last_name: 'Doe')
  expect(user.full_name).to eq('John Doe')
end

# Impact: 100-200ms saved per test
```

#### Pattern 3: create(:facility) without :skip_callbacks
```ruby
# ❌ VERY SLOW - Creates 40+ associated records!
let(:facility) { create(:facility) }

# ✅ MUCH FASTER - Skips unnecessary setup
let(:facility) { create(:facility, :skip_callbacks) }

# ✅ FASTEST - Only for tests not needing DB
let(:facility) { build(:facility) }

# Impact: 200-500ms saved per test
```

#### Pattern 4: create() in loops
```ruby
# ❌ DISASTER - 50ms × 10 = 500ms!
10.times { create(:user) }

# ✅ BETTER - Still slow if not needed
10.times { build(:user) }

# ✅ BEST - Only if testing DB queries
users = create_list(:user, 10)

# Impact: 400-500ms saved
```

#### Pattern 5: create() when build_stubbed works
```ruby
# ❌ SLOW - Unnecessary DB hit
it 'processes user with ID' do
  user = create(:user)
  expect(processor.call(user.id)).to be_truthy
end

# ✅ FAST - Has ID but no DB
it 'processes user with ID' do
  user = build_stubbed(:user)
  expect(processor.call(user.id)).to be_truthy
end

# Impact: 50-100ms saved per test
```

### Step 3: Calculate Performance Impact

```ruby
# Example output from FactoryChecker:

## Factory Optimization Report

### File: spec/models/user_spec.rb

| Line | Current | Suggested | Time Saved | Reason |
|------|---------|-----------|------------|--------|
| 12 | create(:user) | build(:user) | ~80ms | Testing validation, no DB needed |
| 25 | create(:facility) | create(:facility, :skip_callbacks) | ~300ms | Skip unnecessary callbacks |
| 38 | create(:user) | build_stubbed(:user) | ~70ms | Code only checks .id |

**Total Impact**: ~450ms saved per test run
**Suite Impact**: ~7.5 minutes saved on full suite (1000 tests)
```

### Step 4: Auto-Optimize with AI (OPTIONAL)

**Optionally use code-simplifier for intelligent optimization:**

> **📖 See [Code Simplifier Integration Pattern](../shared/code-simplifier-integration.md)** for complete integration guide, benefits, and comparison table (Tier 3: OPTIONAL).

**Ask user**: "Apply factory optimizations with code-simplifier? (y/n)"

**If user says YES**, dispatch via Agent tool (`subagent_type: "code-simplifier"`) with the detected opportunities from Step 3, the factory rules above, and the target `<spec_file_path>`.

**If user says NO**, skip to Step 5 for FactoryChecker-based fixes.

### Step 5: Apply Fixes with FactoryChecker

```bash
# Auto-apply safe fixes (validates this is a test file first)
bin/d ruby -e "
require './lib/factory_checker'
FactoryChecker.fix('spec/models/user_spec.rb', auto_apply: true)
"

# Or manually review and apply
bin/d ruby -e "
require './lib/factory_checker'
FactoryChecker.fix('spec/models/user_spec.rb', auto_apply: false)
"
```

**Note**: FactoryChecker is faster but less intelligent than code-simplifier. Use for simple factory swaps.

### Step 6: Verify Performance

```bash
# Run specs and measure time
time bin/d rspec spec/models/user_spec.rb

# Expected: 30-50% faster after optimization
```

## Detection Patterns

The checker uses grep + AST analysis to find:

```bash
# Pattern 1: create() in validations
grep -n "create(:" spec_file.rb | grep -E "be_valid|validates|errors"

# Pattern 2: create(:facility) without :skip_callbacks
grep -n "create(:facility)" spec_file.rb | grep -v ":skip_callbacks"

# Pattern 3: create() in let blocks
grep -n "let.*{ create(" spec_file.rb

# Pattern 4: create() for method-only tests
grep -n "create(:" spec_file.rb -A5 | grep -E "\.full_name|\.display_|\.to_s"

# Pattern 5: build_stubbed opportunities
grep -n "create(:" spec_file.rb -A3 | grep "\.id\|\.persisted?"
```

## Auto-Fix Safety

Auto-apply ONLY changes these patterns (100% safe):

1. ✅ `create(:user)` → `build(:user)` when testing validations
2. ✅ `create(:facility)` → `create(:facility, :skip_callbacks)`
3. ✅ `create(:user)` → `build_stubbed(:user)` when only `.id` used

Auto-apply SKIPS these patterns (need human review):

1. ⚠️ Tests with scopes/queries (might need DB)
2. ⚠️ Tests with associations (might need eager loading)
3. ⚠️ Integration tests (often need real DB state)

## Example Run

```bash
$ bin/d ruby -e "
  require './lib/factory_checker'
  FactoryChecker.analyze('spec/models/membership_spec.rb')
"

## Factory Optimization Report

### File: spec/models/membership_spec.rb

**Summary**:
- Total create() calls: 15
- Safe to optimize: 9 (60%)
- Estimated time saved: ~620ms per run
- Annual CI savings: ~45 hours

**Detailed Analysis**:

| Line | Pattern | Impact | Fix |
|------|---------|--------|-----|
| 23 | create(:user) in validation test | HIGH | build(:user) |
| 34 | create(:facility) without :skip_callbacks | CRITICAL | add :skip_callbacks |
| 45 | create(:membership) for .duration method | MEDIUM | build(:membership) |
| 56 | create(:user) when only .id used | MEDIUM | build_stubbed(:user) |
| 78 | create(:facility) | CRITICAL | add :skip_callbacks |

**Auto-fix available**: Yes (5 safe changes)
**Manual review needed**: 4 patterns

Run with auto_apply: true to apply safe fixes automatically.
```

## Integration with Other Skills

### With /tdd
```bash
# After writing new specs
/factory-check spec/models/new_feature_spec.rb

# Optimize before committing
```

### With /coverage
```bash
# After coverage run, optimize slow tests
/factory-check spec/models/**/*_spec.rb --slow-only
```

### With /orchestrate
```bash
# Orchestrate includes factory-check for all spec changes
# Automatically runs in Phase 2 (Testing)
```

## Metrics

After Step 6, verify with `time bin/d rspec <path>` — expect 30-50% runtime reduction on optimized files. The `FactoryChecker.analyze` output (see Example Run above) is the canonical report format; multi-file runs emit one report block per file.

## Implementation Notes

Helper implemented in `lib/factory_checker.rb` (`FactoryChecker.analyze` / `.fix`). The file exists and is fully functional — no setup needed.

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

New discoveries (patterns, heuristics, optimizations) → append to [kaizen_log.md](kaizen_log.md).
Do NOT inline Kaizen entries in this file.
