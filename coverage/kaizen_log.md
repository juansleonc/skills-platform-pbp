## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new coverage pattern or rake task
- A missing forbidden pattern
- A better factory usage example
- An edge case in coverage validation

**You MUST**:
1. Complete the current coverage task first
2. Run `/kaizen` separately to persist the improvement (do NOT self-edit with the Edit tool mid-execution)
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
bin/d rspec -e SIMPLECOV_REPORT=true spec/...
bin/d rake 'coverage:local:file[app/models/membership.rb]'
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
bin/d rspec -e SIMPLECOV_REPORT=true
# Check total % is >= develop baseline

# 3. If project coverage drops, add compensating tests:
bin/d rake 'coverage:local:uncovered[10]'
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
bin/d rspec spec/path_spec.rb

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
bin/d sh -c "cat coverage/coverage.json | python3 -c \"
import json, sys
data = json.load(sys.stdin)
for fname, fdata in data['coverage'].items():
    if 'your_file.rb' in fname:
        lines = fdata.get('lines', [])
        for i, cov in enumerate(lines, 1):
            if cov == 0:  # 0 = uncovered, None = non-executable
                print(f'Line {i}: UNCOVERED')
\""
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
bin/d rake 'coverage:local:uncovered[5]'
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
## Jupyter Notebook for Coverage Analysis (Optional)

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

Note: `mcp__ide__executeCode` / `mcp__ide__getDiagnostics` are not available in automation; run Jupyter locally only.

<!-- Kaizen: 2026-01-31 - Code Simplifier Integration -->
## Kaizen Entry: Code Simplifier Auto-Optimization for Generated Specs

**What Changed:**
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
