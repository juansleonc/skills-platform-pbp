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

> **📖 See [Code Simplifier Integration Pattern](../shared/code-simplifier-integration.md)** for complete integration guide (Tier 3: OPTIONAL).

**Ask user**: "Apply factory optimizations with code-simplifier? (y/n)"

**Benefits of code-simplifier**:
- ✅ More comprehensive (also optimizes setup, contexts, let vs let!)
- ✅ Learns from project patterns
- ✅ Understands code context (not just regex)
- ✅ Handles edge cases gracefully

**If user says YES:**

```
Agent tool:
  subagent_type: "code-simplifier"
  prompt: |
    Apply these factory optimizations:
    <paste detected opportunities from Step 3>

    Rules:
    - create → build (when object not persisted)
    - create → build_stubbed (when code needs id/persisted?)
    - create(:facility) → create(:facility, :skip_callbacks) (saves 40+ records)
    - Keep create ONLY for scopes, queries, DB operations
    - Preserve all test functionality
    - Add comments if optimization is non-obvious

    File: <spec_file_path>
```

**Benefits**:
- Smarter optimization (understands code semantics)
- Also fixes redundant setup, contexts consolidation
- One-step application vs manual editing

**When to use code-simplifier vs FactoryChecker**:

| Tool | Best For | Speed | Intelligence |
|------|----------|-------|--------------|
| **code-simplifier** (Step 4) | Complex specs with multiple issues | Slower (~10s) | High (AI-powered) |
| **FactoryChecker** (Step 5) | Simple factory swaps only | Fast (~1s) | Medium (rule-based) |

**If user says NO**, skip to Step 5 for manual or FactoryChecker-based fixes.

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

Track performance improvements:

```bash
# Before optimization
$ time bin/d rspec spec/models/
real    2m30s

# After factory-check optimization
$ time bin/d rspec spec/models/
real    1m45s

# Result: 45 seconds saved (30% improvement)
```

## Report Format

```markdown
## Factory Optimization Report

### Files Analyzed: 3
- spec/models/user_spec.rb
- spec/models/facility_spec.rb
- spec/services/payment_service_spec.rb

### Performance Impact
- create() calls optimized: 24
- Time saved per run: ~1.8 seconds
- Full suite impact: ~30 minutes
- CI cost savings: ~$150/month

### High-Impact Changes
1. facility_spec.rb:12 - Add :skip_callbacks (saves 300ms)
2. user_spec.rb:45 - Use build instead of create (saves 80ms)
3. payment_service_spec.rb:67 - Use build_stubbed (saves 70ms)

### Auto-Applied: 18 changes
### Manual Review Needed: 6 changes

### Next Steps
1. Run specs to verify changes
2. Check coverage maintained
3. Commit optimized specs
```

## Implementation Notes

The `/factory-check` skill uses a Ruby helper script at `lib/factory_checker.rb`:

```ruby
# lib/factory_checker.rb
class FactoryChecker
  def self.analyze(file_path)
    # AST parsing + pattern detection
  end

  def self.fix(file_path, auto_apply: false)
    # Apply safe optimizations
  end
end
```

Create this helper file when first using the skill.

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new slow factory pattern
- A missing optimization opportunity
- A better detection heuristic

**You MUST**:
1. Complete the current analysis first
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

<!-- Kaizen: 2026-01-31 - Code Simplifier Integration (Tier 3: OPTIONAL) -->
## Kaizen Entry: AI-Powered Optimization Option

**What Changed:**
- Added `Task` to allowed-tools in frontmatter
- Added reference to code-simplifier-integration.md in Shared References
- Added Step 4: Auto-Optimize with AI (OPTIONAL) using Tier 3 pattern
- Renamed old Step 4 → Step 5, old Step 5 → Step 6
- Added comparison table: code-simplifier vs FactoryChecker
- User explicitly chooses optimization approach

**Why:**
- FactoryChecker is fast but rule-based (regex + AST)
- code-simplifier is slower but more intelligent (understands semantics)
- Some specs need comprehensive optimization (setup, contexts, let/let!)
- Users want choice: speed (FactoryChecker) vs intelligence (code-simplifier)
- Tier 3 pattern (OPTIONAL) perfect for "choose your tool" scenarios

**Impact:**
- Users have 2 optimization approaches:
  - **FactoryChecker** (Step 5): Fast (~1s), simple factory swaps
  - **code-simplifier** (Step 4): Slower (~10s), comprehensive optimization
- Complex specs can use code-simplifier for deeper optimization
- Simple specs can skip to FactoryChecker for quick fixes
- ROI: 1.0 (Medium impact - adds flexibility, Medium effort - user approval flow)

**Example:**
\`\`\`
Complex spec with setup issues:
  User: "yes" to code-simplifier
  Result: Factories + setup + contexts optimized

Simple spec, just 3 factory swaps:
  User: "no" to code-simplifier
  Uses: FactoryChecker (faster, focused)
\`\`\`

<!-- Kaizen entries will be added here -->
