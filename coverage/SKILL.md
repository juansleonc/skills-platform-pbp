---
name: coverage
description: Use after writing tests to verify 100% patch coverage across unit, integration, and system tests.
allowed-tools: [Bash, Read, Write, Edit, Grep, Glob, Agent]
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
bin/d rspec  # set SIMPLECOV_REPORT=true for coverage output
```

To compare against the develop baseline **without leaving your feature branch** (required — see
CLAUDE.local.md rule #16: NEVER `git checkout develop` from a feature branch):

```bash
# Option A (preferred): isolated worktree — see /worktrees skill for the full pattern
git worktree add --detach /tmp/cov-baseline origin/develop
# Then in a separate shell or compose one-off run against that worktree:
# docker compose -f docker-compose.yml run --rm --no-deps \
#   -e SIMPLECOV_REPORT=true -e BUNDLE_PATH=/usr/local/bundle \
#   -v /tmp/cov-baseline:/app web bundle exec rspec
# Note the total coverage percentage, then clean up:
git worktree remove /tmp/cov-baseline

# Option B (simpler for most cases): skip the develop baseline comparison entirely.
# Use patch-coverage on changed lines instead — it is Codecov's primary check:
bin/d rake 'coverage:local:delta'
```

> **Rule #16 Safety**: NEVER run `git stash && git checkout develop && ...` to measure a baseline.
> That mutates your working tree and risks pushing to a protected branch (TRI-74 incident class).
> Use a worktree or rely on patch-coverage alone.

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
bin/d rake 'coverage:local:uncovered[20]'

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
bin/d rake 'coverage:local:file[app/models/user.rb]'
```

**Strategy 3: Add edge case tests**
Look for uncovered branches in your modified files:
- Error handling paths (`rescue` blocks)
- Conditional branches (`elsif`, `else`)
- Guard clauses (`return if`, `return unless`)

### Step 5: Verify Project Coverage Impact

```bash
# Run full test suite with coverage
bin/d rspec  # set SIMPLECOV_REPORT=true

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
bin/d rspec spec/models/membership_spec.rb  # set SIMPLECOV_REPORT=true
```

### Step 4: Check Coverage for Changed Lines
```bash
# View coverage data for specific file
bin/d rake 'coverage:local:file[app/models/membership.rb]'
```

### Step 5: Cross-Reference Uncovered Lines
Compare the changed line numbers (Step 2) with uncovered lines from SimpleCov.
**ALL changed lines must be covered before committing.**

## Available Rake Tasks

**All commands run via `bin/d` (preferred wrapper):**

```bash
# See uncovered files (top N)
bin/d rake 'coverage:local:uncovered[10]'

# Validate spec quality before committing
bin/d rake 'coverage:validate:quick[spec/path_spec.rb]'

# Check coverage progress
bin/d rake 'coverage:local:delta'

# Check specific file coverage
bin/d rake 'coverage:local:file[app/models/user.rb]'

# Agent workflow tasks
bin/d rake 'coverage:agent:next'      # Get priority file
bin/d rake 'coverage:agent:analyze'   # Analyze file
bin/d rake 'coverage:agent:process'   # Full workflow
```

## Test Locations

| Type | Location | Command |
|------|----------|---------|
| Unit | `spec/models/`, `spec/services/` | `bin/d rspec spec/...` |
| Integration | `spec/requests/`, `spec/graphql/` | `bin/d rspec spec/...` |
| Package | `packs/**/spec/` | `bin/d rspec packs/webhooks/spec/` |
| System | `system_specs/` (NOT spec/) | `bin/test_system` |

## Autonomous Workflow for PRs/Feature Branches

> The TDD RED-GREEN-REFACTOR loop (Step 1-4) lives in `/tdd` — see Step 5 there for the coverage gate.
> This skill owns the verification steps below. Use the Patch Coverage Workflow above for the commands.

Follow factory conventions when writing specs (see Factory Rules section below).

**After writing specs, optimize with code-simplifier (Tier 1 — ALWAYS):**

> **See [Code Simplifier Integration Pattern](../shared/code-simplifier-integration.md)** for the full integration guide.

```
Agent tool with subagent_type: "code-simplifier"
prompt: "Review and optimize this spec file for performance and clarity:
  - Prefer build over create
  - Remove redundant test setup
  - Consolidate similar contexts
  - Ensure proper use of let vs let!
  - Remove unnecessary database operations
  File: spec/path/to/new_spec.rb"
```

**Then validate and verify:**

```bash
bin/d rake 'coverage:validate:quick[spec/path_spec.rb]'
bin/d rspec spec/path_spec.rb  # set SIMPLECOV_REPORT=true
bin/d rake 'coverage:local:file[app/models/membership.rb]'
```

**DO NOT commit until ALL changed lines are covered.**

## Legacy Workflow (Total File Coverage)

For improving overall coverage (not PR-specific):

1. **Find uncovered files**
   ```bash
   bin/d rake 'coverage:local:uncovered[10]'
   ```

2. **Pick top priority file** and read it

3. **Write specs** and verify total coverage:
   ```bash
   bin/d rake 'coverage:local:file[app/path/to/file.rb]'
   ```

## Coverage Verification (MANDATORY)

### For PRs/Feature Branches (PATCH Coverage)

After writing tests, ALWAYS verify that ALL changed lines are covered:

```bash
# 1. Run tests with SimpleCov
bin/d rspec spec/path_spec.rb  # set SIMPLECOV_REPORT=true

# 2. Get changed line numbers
git diff develop...HEAD --unified=0 -- app/models/membership.rb | grep "^@@"

# 3. Check file coverage
bin/d rake 'coverage:local:file[app/models/membership.rb]'

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
bin/d rake 'coverage:local:file[app/models/user.rb]'
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
   $ bin/d rspec spec/models/membership_spec.rb  # with SIMPLECOV_REPORT=true
   65 examples, 0 failures

4. Checking coverage for changed lines...
   $ bin/d rake 'coverage:local:file[app/models/membership.rb]'
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

## Kaizen Log

> Full history archived in [kaizen_log.md](./kaizen_log.md). Run `/kaizen` to add new entries — do NOT self-edit this file with the Edit tool during skill execution.

**Recent entries (2026-01-31, 2026-02-01)**:
- Code Simplifier Integration: Added Tier 1 auto-optimization pattern after spec generation (see Autonomous Workflow above).
- Critical Rules Reference: Added `critical-rules.md` to Shared References (Rule #9 — 100% Coverage).
