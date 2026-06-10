---
name: coverage
description: Use after writing tests to verify 100% patch coverage across unit, integration, and system tests.
allowed-tools: [Bash, Read, Write, Edit, Grep, Glob, Task, mcp__ide__executeCode, mcp__ide__getDiagnostics]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## Shared References

> **📚 This skill uses shared documentation. See:**
> - [Factory Rules](../shared/factory-rules.md) - build vs create patterns
> - [Forbidden Patterns](../shared/forbidden-patterns.md) - patterns to avoid
> - [Testing Patterns](../shared/testing-patterns.md) - time, Redis, parallel safety
> - [Critical Rules](../shared/critical-rules.md) - project-wide rules (Rule #9: 100% Coverage)
> - [Code Simplifier Integration](../shared/code-simplifier-integration.md) - automatic spec optimization

# Coverage Improvement Skill

**CRITICAL: Both Codecov checks must pass. No exceptions.**

Codecov runs **TWO separate checks** on every PR:

| Check | What it measures | Requirement |
|-------|------------------|-------------|
| `codecov/patch` | Coverage on **modified lines only** | All changed lines must be covered |
| `codecov/project` | **Global project coverage** | Must not decrease from base branch |

> **Common Failure**: PR passes `codecov/patch` but fails `codecov/project` because adding new code
> without proportional tests reduces the global coverage percentage, even if new lines are covered.

## Project Coverage Workflow (When codecov/project Fails)

**Why `codecov/project` fails**: Adding ANY new lines of code without adding MORE test lines reduces
the overall coverage percentage. Even with 100% patch coverage, the global % drops.

### Understanding the Math

```
Before PR:  80,000 covered lines / 100,000 total lines = 80.00% coverage
After PR:   80,100 covered lines / 100,200 total lines = 79.92% coverage (FAIL: -0.08%)
```

Even though you covered all 100 new lines (100% patch), you only added 100 test hits.
The project now has 200 more lines but only 100 more covered hits → percentage drops.

### Step 1: Check Current Project Coverage Impact

```bash
# Get the coverage delta your PR will cause
docker compose exec -e SIMPLECOV_REPORT=true web bundle exec rspec

# Compare with develop baseline (if available)
git stash
git checkout develop
docker compose exec -e SIMPLECOV_REPORT=true web bundle exec rspec
# Note the total coverage percentage

git checkout -
git stash pop
docker compose exec -e SIMPLECOV_REPORT=true web bundle exec rspec
# Compare with your branch's percentage
```

### Step 2: Calculate Required Compensating Coverage

To maintain or increase project coverage when adding N new lines:

```
Required additional covered lines = N × (1 / current_coverage_ratio)

Example: Adding 200 new lines at 80% base coverage:
Required = 200 × (1 / 0.80) = 250 covered lines needed
You need 50 MORE test hits beyond just covering your new code
```

### Step 3: Find Low-Coverage Files to Improve

```bash
# Find files with lowest coverage (easy wins for compensating coverage)
docker compose exec web bundle exec rake 'coverage:local:uncovered[20]'

# Focus on files with:
# - High line count but low coverage (more impact per test)
# - Simple logic (quick to test)
# - Related to your changes (natural to include in PR)
```

### Step 4: Add Compensating Tests

**Strategy 1: Improve related files**
If your PR touches `membership.rb`, also improve coverage on:
- `membership_payment.rb`
- `membership_plan.rb`
- Related services in the same domain

**Strategy 2: Low-hanging fruit**
Target files with many uncovered lines but simple logic:
```bash
# Example: Find uncovered lines in a specific file
docker compose exec web bundle exec rake 'coverage:local:file[app/models/user.rb]'
```

**Strategy 3: Add edge case tests**
Look for uncovered branches in your modified files:
- Error handling paths (`rescue` blocks)
- Conditional branches (`elsif`, `else`)
- Guard clauses (`return if`, `return unless`)

### Step 5: Verify Project Coverage Impact

```bash
# Run full test suite with coverage
docker compose exec -e SIMPLECOV_REPORT=true web bundle exec rspec

# Check the total coverage percentage
# It should be >= develop branch baseline
```

### Project Coverage Checklist

Before pushing PR:
- [ ] `codecov/patch` will pass (all changed lines covered)
- [ ] `codecov/project` will pass (global % not decreased)
- [ ] If adding many new lines, added compensating tests
- [ ] Verified with full `rspec` run, not just affected specs

## Patch Coverage Workflow (PRIORITY)

**ALWAYS follow this workflow when working on PRs:**

### Step 1: Identify Changed Files
```bash
git diff develop...HEAD --name-only | grep '\.rb$' | grep -v '^spec/' | grep -v '^db/'
```

### Step 2: Get Changed Line Numbers for Each File
```bash
# Shows added/modified line numbers
git diff develop...HEAD --unified=0 -- app/models/membership.rb | grep "^@@" | \
  sed -E 's/@@ -[0-9,]+ \+([0-9]+)(,([0-9]+))? @@.*/\1 \3/' | \
  awk '{start=$1; count=$2?$2:1; for(i=0;i<count;i++) print start+i}'
```

### Step 3: Run Specs with SimpleCov
```bash
docker compose exec -e SIMPLECOV_REPORT=true web bundle exec rspec spec/models/membership_spec.rb
```

### Step 4: Check Coverage for Changed Lines
```bash
# View coverage data for specific file
docker compose exec web bundle exec rake 'coverage:local:file[app/models/membership.rb]'
```

### Step 5: Cross-Reference Uncovered Lines
Compare the changed line numbers (Step 2) with uncovered lines from SimpleCov.
**ALL changed lines must be covered before committing.**

## Available Rake Tasks

**All commands run in Docker web container:**

```bash
# See uncovered files (top N)
docker compose exec web bundle exec rake 'coverage:local:uncovered[10]'

# Validate spec quality before committing
docker compose exec web bundle exec rake 'coverage:validate:quick[spec/path_spec.rb]'

# Check coverage progress
docker compose exec web bundle exec rake 'coverage:local:delta'

# Check specific file coverage
docker compose exec web bundle exec rake 'coverage:local:file[app/models/user.rb]'

# Agent workflow tasks
docker compose exec web bundle exec rake 'coverage:agent:next'      # Get priority file
docker compose exec web bundle exec rake 'coverage:agent:analyze'   # Analyze file
docker compose exec web bundle exec rake 'coverage:agent:process'   # Full workflow
```

## Test Locations

| Type | Location | Command |
|------|----------|---------|
| Unit | `spec/models/`, `spec/services/` | `make test TEST_PATH=spec/...` |
| Integration | `spec/requests/`, `spec/graphql/` | `make test TEST_PATH=spec/...` |
| Package | `packs/**/spec/` | `make test TEST_PATH=packs/webhooks/spec/` |
| System | `system_specs/` (NOT spec/) | `bin/test_system` |

## Autonomous Workflow for PRs/Feature Branches

**IMPORTANT**: All commands execute in Docker web container.

### Step 1: Identify Changed Source Files

```bash
# List changed Ruby source files (excluding specs and migrations)
git diff develop...HEAD --name-only | grep '\.rb$' | grep -v '^spec/' | grep -v '^db/'
```

### Step 2: For Each File, Get Changed Line Numbers

```bash
# Example for membership.rb - get all added/modified line numbers
git diff develop...HEAD --unified=0 -- app/models/membership.rb
```

Parse the `@@` headers to find line numbers. Format: `@@ -old,count +NEW,COUNT @@`

### Step 3: Write Specs for Changed Lines

Follow project conventions:
- Use `build(:factory)` for validations/methods (DEFAULT)
- Use `build_stubbed(:factory)` when code needs `id`/`persisted?`
- Use `create(:factory)` ONLY for scopes, queries, uniqueness
- Use `create(:facility, :skip_callbacks)` for facilities

**Focus on testing the NEW code paths you added/modified.**

### Step 4: Optimize Specs (ALWAYS)

**ALWAYS run code-simplifier on generated specs:**

> **📖 See [Code Simplifier Integration Pattern](../shared/code-simplifier-integration.md)** for complete integration guide (Tier 1: ALWAYS).

```
Task tool with subagent_type: "code-simplifier"
prompt: "Review and optimize this spec file for performance and clarity:
  - Prefer build over create
  - Remove redundant test setup
  - Consolidate similar contexts
  - Ensure proper use of let vs let!
  - Remove unnecessary database operations
  File: spec/path/to/new_spec.rb"
```

The code-simplifier agent will:
- ✅ Identify slow patterns (unnecessary `create` calls)
- ✅ Suggest `build`/`build_stubbed` replacements
- ✅ Remove duplicate setup code
- ✅ Optimize factory usage
- ✅ Ensure tests are maintainable

**Benefits**:
- Faster test execution (build vs create = 50-500x speedup)
- Consistent patterns across all specs
- Automatic adherence to factory rules
- Reduced CI time

### Step 5: Validate Specs

```bash
docker compose exec web bundle exec rake 'coverage:validate:quick[spec/path_spec.rb]'
```

### Step 6: Run Specs with SimpleCov

```bash
docker compose exec -e SIMPLECOV_REPORT=true web bundle exec rspec spec/path_spec.rb
```

### Step 7: Verify Coverage on Changed Lines

```bash
# Check overall file coverage
docker compose exec web bundle exec rake 'coverage:local:file[app/models/membership.rb]'
```

Then manually verify that ALL lines from Step 2 are covered.

### Step 8: Iterate Until All Changed Lines Covered

If any changed lines are uncovered:
1. Re-run git diff to see which lines you modified
2. Check SimpleCov output for those specific line numbers
3. Add tests that execute those lines
4. Re-run until all changed lines are covered
5. **DO NOT commit until all changed lines are tested**

## Legacy Workflow (Total File Coverage)

For improving overall coverage (not PR-specific):

1. **Find uncovered files**
   ```bash
   docker compose exec web bundle exec rake 'coverage:local:uncovered[10]'
   ```

2. **Pick top priority file** and read it

3. **Write specs** and verify total coverage:
   ```bash
   docker compose exec web bundle exec rake 'coverage:local:file[app/path/to/file.rb]'
   ```

## Coverage Verification (MANDATORY)

### For PRs/Feature Branches (PATCH Coverage)

After writing tests, ALWAYS verify that ALL changed lines are covered:

```bash
# 1. Run tests with SimpleCov
docker compose exec -e SIMPLECOV_REPORT=true web bundle exec rspec spec/path_spec.rb

# 2. Get changed line numbers
git diff develop...HEAD --unified=0 -- app/models/membership.rb | grep "^@@"

# 3. Check file coverage
docker compose exec web bundle exec rake 'coverage:local:file[app/models/membership.rb]'

# 4. Read coverage/coverage.json for detailed line-by-line data
# Lines with 0 are uncovered, lines with null are non-executable
```

**Verification Checklist:**
- [ ] All added lines are covered (not showing 0 in SimpleCov)
- [ ] All modified lines are covered
- [ ] Edge cases and error paths are tested
- [ ] No new code without corresponding tests

**If changed lines are uncovered:**
1. Identify the uncovered line numbers from SimpleCov
2. Cross-reference with `git diff` output
3. Write tests that execute those specific lines
4. **DO NOT commit until ALL changed lines are covered**

### For Total File Coverage (Legacy)

```bash
# Check total coverage for a file
docker compose exec web bundle exec rake 'coverage:local:file[app/models/user.rb]'
```

## Forbidden Patterns

> 📖 **See [Forbidden Patterns](../shared/forbidden-patterns.md) for complete list.**

The validation will FAIL if specs contain:

| Pattern | Alternative |
|---------|-------------|
| `allow_any_instance_of` | Dependency injection |
| `expect_any_instance_of` | Explicit instances |
| `create(:user, id: 1)` | Let factory generate ID |
| `Time.now` / `Date.today` | `Time.current` / `Date.current` |
| `before(:all) { create }` | `before(:each)` |
| `date.to_s(:db)` | `strftime('%Y-%m-%d')` |

## Factory Rules (CRITICAL)

> 📖 **See [Factory Rules](../shared/factory-rules.md) for complete decision tree.**

```ruby
# DEFAULT - validations, methods, attributes
build(:user)

# When code needs ID or persisted?
build_stubbed(:user)

# ONLY for scopes, queries, DB operations
create(:user)

# Facility without 40+ associated records
create(:facility, :skip_callbacks)
```

## Time-Dependent Tests

> 📖 **See [Testing Patterns](../shared/testing-patterns.md) for complete patterns.**

**ALWAYS use Timecop with Time.current:**

```ruby
# ✅ CORRECT
Timecop.freeze(Time.current) do
  expect(build(:user).expires_at).to eq(30.days.from_now)
end

# ❌ WRONG - will fail randomly
expect(build(:user).expires_at).to eq(Time.now + 30.days)
```

## Redis Tests

> 📖 **See [Testing Patterns](../shared/testing-patterns.md) for Redis patterns.**

**Clear Redis for rate limiting/caching:**

```ruby
before { Redis.current.flushdb }
# Or: Rails.cache.clear
```

## Spec File Template

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClassName do
  describe '#method_name' do
    subject { instance.method_name }

    let(:instance) { build(:factory) }

    context 'when condition' do
      it 'expected behavior' do
        expect(subject).to eq(expected)
      end
    end

    context 'when error condition' do
      it 'handles error gracefully' do
        expect { subject }.to raise_error(ExpectedError)
      end
    end
  end
end
```

## System Test Coverage

**System tests (`system_specs/`) require separate setup:**

```bash
# Setup Playwright (version must match Gemfile.lock!)
npx --yes playwright@1.55.0 install chromium

# Run system tests
bin/test_system

# Parallel
PARALLEL_TEST_PROCESSORS=4 bin/test_system

# Visible browser for debugging
PLAYWRIGHT_HEADLESS=false bin/test_system
```

## Rules

- Write specs from a **correctness validation perspective**
- Specs should reflect expected behavior, not just replicate code
- Identify potential bugs, edge cases, and ambiguous behavior
- NEVER use `allow_any_instance_of`
- Always use `Time.current` with `Timecop.freeze` for time-dependent tests
- Clear Redis in tests using rate limiting/caching
- **100% coverage is non-negotiable**

## Example Session (PR Coverage)

```
User: /coverage

Claude:
1. Identifying changed files...
   $ git diff develop...HEAD --name-only | grep '\.rb$' | grep -v '^spec/'

   Changed files:
   - app/models/membership.rb
   - app/jobs/automatic_renewal_membership_job.rb

2. Getting changed lines for membership.rb...
   $ git diff develop...HEAD --unified=0 -- app/models/membership.rb | grep "^@@"

   Changed regions:
   @@ -148,0 +150,1 @@     (line 150, 1 line added)
   @@ -460,5 +462,10 @@   (lines 462-471, 10 lines changed)
   @@ -785,0 +788,20 @@   (lines 788-807, new method added)

3. Running specs with SimpleCov...
   $ docker compose exec -e SIMPLECOV_REPORT=true web bundle exec rspec spec/models/membership_spec.rb
   65 examples, 0 failures

4. Checking coverage for changed lines...
   $ docker compose exec web bundle exec rake 'coverage:local:file[app/models/membership.rb]'
   Coverage: 42% (155/367 lines)

   Cross-referencing with git diff:
   - Line 150: ✅ covered
   - Lines 462-471: ❌ lines 466-467 uncovered (find_pending_payment_for_current_period call)
   - Lines 788-807: ❌ lines 794-806 uncovered (new method body)

5. Writing additional specs for uncovered lines...
   Adding tests for:
   - describe '#find_pending_payment_for_current_period'
   - context 'when matching_payment exists'

6. Re-running specs...
   74 examples, 0 failures

7. Verifying all changed lines now covered...
   All lines from git diff are now showing coverage > 0 in SimpleCov ✅

8. Ready for commit.
```

## Common Patch Coverage Pitfalls

| Issue | Example | Solution |
|-------|---------|----------|
| Refactoring without tests | Moving code to `class << self` | Test the class methods directly |
| AASM callbacks | `after { MembershipMailer.paused(self) }` | Test state transitions trigger mailers |
| Format-only changes | Indentation, line breaks | These count as changes - may need tests |
| Complex conditionals | Multiple elsif branches | Test each branch explicitly |
| Error handling paths | `rescue => e` blocks | Test error scenarios |
| New method calls | `matching_payment = find_pending_payment_for_current_period` | Test the new method is called |
| Class methods | `def self.create_membership_payment` | Use `Membership.create_membership_payment(...)` |

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new coverage pattern or rake task
- A missing forbidden pattern
- A better factory usage example
- An edge case in coverage validation

**You MUST**:
1. Complete the current coverage task first
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements**:

<!-- Kaizen: 2026-01-22 -->
### Patch Coverage Workflow (Critical Fix)

**Problem**: PR #3989 failed Codecov with 61.05% patch coverage (target: 83.52%) because:
1. The skill only documented total file coverage verification
2. No guidance on identifying which CHANGED lines needed tests
3. Missing workflow for cross-referencing git diff with SimpleCov

**Root Cause Analysis**:
- Codecov measures **patch coverage** = coverage on NEW/MODIFIED lines only
- A file can have 40% total coverage but pass Codecov if all changed lines are covered
- The skill was checking total file coverage, missing the patch perspective

**Solution**: Updated skill documentation with:
1. Manual workflow using `git diff` to identify changed line numbers
2. Cross-reference process with SimpleCov data
3. Clear verification checklist before commit
4. Common pitfalls (AASM callbacks, class methods, format changes)

**Key Commands**:
```bash
# Get changed files
git diff develop...HEAD --name-only | grep '\.rb$' | grep -v '^spec/'

# Get changed line numbers for a file
git diff develop...HEAD --unified=0 -- app/models/membership.rb | grep "^@@"

# Check coverage
docker compose exec -e SIMPLECOV_REPORT=true web bundle exec rspec spec/...
docker compose exec web bundle exec rake 'coverage:local:file[app/models/membership.rb]'
```

**Target**: 83.52% patch coverage (Codecov default threshold)

<!-- Kaizen: 2026-01-22 -->
### Project Coverage Strategy (Critical Addition)

**Problem**: PR #3981 passed `codecov/patch` (100%) but failed `codecov/project` (-0.06%) because:
1. The skill only addressed patch coverage, not global coverage impact
2. No guidance on calculating compensating tests needed
3. No workflow to verify project coverage before pushing

**Root Cause Analysis**:
- `codecov/project` measures TOTAL codebase coverage, not just changed lines
- Adding new code without proportional test coverage ALWAYS reduces global %
- Even 100% patch coverage isn't enough if you add many new lines

**Solution**: Added comprehensive "Project Coverage Workflow" section with:
1. Math explanation of why project coverage drops
2. Formula to calculate required compensating tests
3. Strategies for finding low-coverage files to improve
4. Pre-push verification checklist

**Quick Reference - Both Checks Must Pass**:
```bash
# 1. Verify PATCH coverage (changed lines)
git diff develop...HEAD --name-only | grep '\.rb$' | grep -v '^spec/' | grep -v '^db/'
# For each file, ensure all changed lines are covered

# 2. Verify PROJECT coverage (global %)
docker compose exec -e SIMPLECOV_REPORT=true web bundle exec rspec
# Check total % is >= develop baseline

# 3. If project coverage drops, add compensating tests:
docker compose exec web bundle exec rake 'coverage:local:uncovered[10]'
# Pick related or easy-win files and add tests
```

**Pre-PR Checklist**:
- [ ] All changed lines covered (patch)
- [ ] Global coverage % not decreased (project)
- [ ] Ran full test suite, not just affected specs

<!-- Kaizen: 2026-01-23 -->
### Pre-Flight Checks (Critical Addition)

**Problem**: PRs fail in CI for reasons unrelated to coverage:
- PR #3989 had **flaky tests failing** (timezone issues) - coverage wasn't even evaluated
- Tests pass locally but fail in CI due to time-dependent assertions

**Root Cause Analysis**:
- Coverage verification assumes tests pass, but doesn't verify this first
- Flaky tests (timezone, ordering, race conditions) block the entire CI pipeline
- No guidance on detecting/fixing flaky tests before pushing

**Solution**: Added mandatory pre-flight checks:

```bash
# STEP 0: ALWAYS run tests first to ensure they pass
docker compose exec -e RAILS_ENV=test web bundle exec rspec spec/path_spec.rb

# If tests fail, FIX THEM before worrying about coverage
# Common flaky test issues:
# - Time.now instead of Time.current + Timecop.freeze
# - Order-dependent expectations (use match_array instead of eq for arrays)
# - Missing database cleanup between tests
```

**Flaky Test Patterns to Fix**:
| Pattern | Problem | Fix |
|---------|---------|-----|
| `expect(date).to eq(facility.current_time.to_date)` | Time zone drift | `Timecop.freeze { ... }` |
| `expect(results).to eq([a, b])` | Order not guaranteed | `expect(results).to match_array([a, b])` |
| `let!(:record)` without explicit ordering | Race condition | Add `.order(:id)` to queries |
| Tests that depend on day of week | Fails on specific days | Mock the day explicitly |

**Pre-Push Checklist (Updated)**:
1. [ ] **Tests pass locally** (run full affected spec files)
2. [ ] All changed lines covered (patch)
3. [ ] Global coverage % not decreased (project)
4. [ ] No flaky test patterns in new code

<!-- Kaizen: 2026-01-23 -->
### Using Codecov Report to Find Uncovered Lines

**Problem**: PR #3990 had 77.78% patch coverage with **6 specific lines** missing coverage.
The skill didn't explain how to find WHICH lines from Codecov report.

**Solution**: Parse Codecov bot comment to find exact uncovered lines:

```bash
# 1. Get Codecov comment from PR
gh api repos/PlaybyCourt/platform/issues/<PR_NUMBER>/comments \
  --jq '.[] | select(.user.login == "codecov[bot]") | .body'

# 2. Look for "Files with missing lines" section in the comment
# It lists exact files and line numbers that need coverage

# 3. Or check the Codecov web UI directly:
# https://app.codecov.io/gh/PlaybyCourt/platform/pull/<PR_NUMBER>
# Click on "Files changed" tab to see line-by-line coverage
```

**Alternative: Local verification with coverage.json**:
```bash
# After running specs with SimpleCov, parse coverage.json
docker compose exec web cat coverage/coverage.json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for fname, fdata in data['coverage'].items():
    if 'your_file.rb' in fname:
        lines = fdata.get('lines', [])
        for i, cov in enumerate(lines, 1):
            if cov == 0:  # 0 = uncovered, None = non-executable
                print(f'Line {i}: UNCOVERED')
"
```

<!-- Kaizen: 2026-01-23 -->
### Minimal Project Coverage Drops

**Problem**: PR #3947 passed patch (100%) but failed project by **-0.01%** (lost 1 hit, gained 4 misses).
This tiny drop is hard to compensate for without understanding why.

**Root Cause Analysis**:
- Sometimes CI runs different test subsets than local
- Parallel test execution can cause coverage variance
- A single uncovered line in an unrelated file can tip the balance

**Solution**: For minimal drops (-0.01% to -0.05%):

```bash
# 1. Check what changed in the coverage diff
gh api repos/PlaybyCourt/platform/issues/<PR_NUMBER>/comments \
  --jq '.[] | select(.user.login == "codecov[bot]") | .body' | grep -A20 "Coverage Diff"

# 2. Look at "Hits" and "Misses" changes
# - If Hits decreased: Something that was covered is now not running
# - If Misses increased: New uncovered code exists

# 3. For tiny drops, add 1-2 simple tests to ANY low-coverage file
docker compose exec web bundle exec rake 'coverage:local:uncovered[5]'
# Pick the top file and add a simple test for an uncovered line
```

**Quick Compensating Test Strategy**:
```ruby
# Find a simple uncovered method in a related file and test it
# Example: If your PR touches membership.rb, look at membership_plan.rb
# Add a test for an uncovered one-liner method

describe '#simple_method' do
  it 'returns expected value' do
    expect(build(:model).simple_method).to eq(expected)
  end
end
```

This adds coverage hits without significant effort, compensating for the tiny drop.

<!-- Kaizen: 2026-01-24 - Jupyter Notebook Integration -->
## 📓 Jupyter Notebook for Coverage Analysis (Optional)

Use JupyterLab for **interactive coverage analysis** when you need to:
- Visualize coverage trends over time
- Analyze coverage patterns across files
- Parse and explore coverage.json interactively
- Document coverage improvement efforts

### Launch Jupyter for Coverage Analysis

```bash
~/jupyter-env/bin/jupyter lab
```

### Example Coverage Analysis Notebook

```python
# Cell 1: Load coverage data
import json
import pandas as pd

with open('coverage/coverage.json', 'r') as f:
    coverage_data = json.load(f)

# Cell 2: Calculate per-file coverage
results = []
for filepath, filedata in coverage_data['coverage'].items():
    lines = filedata.get('lines', [])
    if not lines:
        continue

    total = len([l for l in lines if l is not None])
    covered = len([l for l in lines if l is not None and l > 0])
    uncovered = len([l for l in lines if l == 0])

    if total > 0:
        results.append({
            'file': filepath.replace('/app/', ''),
            'total_lines': total,
            'covered': covered,
            'uncovered': uncovered,
            'coverage_pct': round(covered / total * 100, 2)
        })

df = pd.DataFrame(results)

# Cell 3: Find files with lowest coverage
df_low = df.sort_values('coverage_pct').head(20)
print("Files with lowest coverage:")
print(df_low[['file', 'coverage_pct', 'uncovered']].to_string(index=False))

# Cell 4: Visualize coverage distribution
import matplotlib.pyplot as plt

plt.figure(figsize=(12, 6))
plt.hist(df['coverage_pct'], bins=20, edgecolor='black')
plt.xlabel('Coverage %')
plt.ylabel('Number of Files')
plt.title('Coverage Distribution Across Files')
plt.axvline(x=80, color='r', linestyle='--', label='Target (80%)')
plt.legend()

# Cell 5: Find uncovered lines in specific file
target_file = 'app/models/membership.rb'
for filepath, filedata in coverage_data['coverage'].items():
    if target_file in filepath:
        lines = filedata.get('lines', [])
        uncovered = [i+1 for i, cov in enumerate(lines) if cov == 0]
        print(f"Uncovered lines in {target_file}:")
        print(uncovered)
        break
```

### Patch Coverage Analysis

```python
# Analyze coverage on changed lines only
import subprocess

# Get changed line numbers
result = subprocess.run(
    ['git', 'diff', 'develop...HEAD', '--unified=0', '--', 'app/models/membership.rb'],
    capture_output=True, text=True
)

import re
changed_lines = []
for match in re.finditer(r'@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@', result.stdout):
    start = int(match.group(1))
    count = int(match.group(2)) if match.group(2) else 1
    changed_lines.extend(range(start, start + count))

print(f"Changed lines: {changed_lines}")

# Check which changed lines are uncovered
uncovered_changed = [l for l in changed_lines if l in uncovered]
print(f"Uncovered changed lines: {uncovered_changed}")
print(f"Patch coverage: {round((len(changed_lines) - len(uncovered_changed)) / len(changed_lines) * 100, 2)}%")
```

### MCP IDE Tools Available

- `mcp__ide__executeCode`: Execute Python in active Jupyter kernel
- `mcp__ide__getDiagnostics`: Get language diagnostics


<!-- Kaizen: 2026-01-31 - Code Simplifier Integration -->
## Kaizen Entry: Code Simplifier Auto-Optimization for Generated Specs

**What Changed:**
- Added `Task` to allowed-tools in frontmatter
- Added reference to code-simplifier-integration.md in Shared References
- Added Step 4: Optimize Specs (ALWAYS) in Autonomous Workflow
- Integrated Tier 1 pattern (ALWAYS runs, no approval needed)
- Renumbered subsequent steps (old Step 4-7 → new Step 5-8)

**Why:**
- /coverage generates many specs, often with suboptimal factory usage
- Users manually optimize after generation (time-consuming, inconsistent)
- code-simplifier can optimize automatically right after generation
- Consistent with /tdd which also optimizes specs automatically
- Completes the "generate → optimize → validate" workflow

**Impact:**
- Automatic factory optimization (create → build/build_stubbed)
- Faster test suites by default (50-500x speedup per test)
- Consistent patterns without manual intervention
- Reduced CI time for coverage-generated specs
- ROI: 2.0 (Medium-High impact - affects coverage work, Low effort - standard Tier 1 pattern)

**Example:**
```
Before: /coverage generates spec with create(:user) → user manually changes to build
After: /coverage generates + code-simplifier optimizes → ready to run
Time saved: ~2-5 minutes per spec file, more consistent patterns
```

<!-- Kaizen: 2026-02-01 - Critical Rules Reference -->
- Added: Reference to critical-rules.md in Shared References section
- Why: Rule #9 (100% Coverage) is directly relevant to this skill
- Impact: Users can now reference the project-wide critical rules including coverage requirements
- Completes: Full shared documentation integration (factory-rules, forbidden-patterns, testing-patterns, critical-rules, code-simplifier-integration all referenced)
