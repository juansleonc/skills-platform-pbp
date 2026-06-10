# Code Simplifier Agent Integration Pattern

> **Standard integration guide for all skills using the code-simplifier agent**

## Purpose

Provides standardized patterns for integrating the `code-simplifier` agent into skills, ensuring consistent optimization across the ecosystem.

## When to Integrate code-simplifier

### ✅ DO Integrate When Skill:
- Generates new code (specs, services, models, controllers)
- Detects issues but doesn't auto-fix (performance, factories, complexity)
- Works with performance-sensitive code
- Creates or modifies multiple files
- Reviews code for quality/patterns

### ❌ DON'T Integrate When Skill:
- Only reads/analyzes without making changes
- Handles single-line typo fixes
- Purely informational (metrics, reports)
- User-facing documentation only
- Configuration-only changes

## Integration Tiers (3 Tiers)

### Tier 1: ALWAYS (Automatic Execution)

**When**: Skills that generate NEW code
**User Approval**: Not needed (expected behavior)
**Timing**: Immediately after code generation

**Skills Using Tier 1**:
- `/tdd` - After writing new test files
- `/coverage` - After generating specs

**Pattern**:
```markdown
## Step N: Generate Code
[code generation logic]

## Step N+1: Optimize Code (ALWAYS)

**ALWAYS run code-simplifier on new code:**

Task tool with subagent_type: "code-simplifier"
prompt: "[tier 1 prompt - see below]"

## Step N+2: Validate
```

**User Expectation**: "When I use /tdd or /coverage, my code gets automatically optimized."

---

### Tier 2: MANDATORY (Part of Workflow)

**When**: Skills that review EXISTING code comprehensively
**User Approval**: Not needed (part of review)
**Timing**: Final step before validation/commit

**Skills Using Tier 2**:
- `/code-review` - Final quality check (Step 10)
- `/performance` - After detecting performance issues

**Pattern**:
```markdown
## Step N: Analysis/Detection
[analysis logic - detect issues]

## Step N+1: Code Optimization (MANDATORY)

**ALWAYS run code-simplifier for non-trivial changes:**

Task tool:
  subagent_type: "code-simplifier"
  prompt: "[tier 2 prompt - see below]"

**When to skip**:
- Single-line typo fixes
- Comment-only changes
- Configuration file changes

## Step N+2: Validate & Finalize
```

**User Expectation**: "When I use /code-review or /performance, optimization suggestions are included."

---

### Tier 3: OPTIONAL (User-Triggered)

**When**: Skills that detect issues but fix is optional
**User Approval**: REQUIRED before execution
**Timing**: After detection, only if user approves

**Skills Using Tier 3**:
- `/factory-check` - Optional auto-fix of factory patterns
- `/query-analyzer` - Optional query optimization (future)

**Pattern**:
```markdown
## Step N: Detect Issues
[detection logic - show opportunities]

## Step N+1: Auto-Optimize (OPTIONAL)

**Optionally apply optimizations automatically:**

Ask user: "Apply optimizations with code-simplifier? (y/n)"

If yes:
  Task tool:
    subagent_type: "code-simplifier"
    prompt: "[tier 3 prompt - see below]"

  ## Step N+2: Validate Changes
  [validation logic]

If no:
  User can apply fixes manually
```

**User Expectation**: "The skill detected issues. I choose whether to auto-fix or do it manually."

---

## Standard Prompts (By Use Case)

### For Test Files (Tier 1 - /tdd, /coverage)

```
Task tool with subagent_type: "code-simplifier"
prompt: "Review and optimize this spec file for performance and clarity:
  - Prefer build over create
  - Remove redundant test setup
  - Consolidate similar contexts
  - Ensure proper use of let vs let!
  - Remove unnecessary database operations
  File: <spec_file_path>"
```

**What it optimizes**:
- Factory usage (`create` → `build`/`build_stubbed`)
- Redundant setup code
- Slow test patterns
- Context consolidation
- `let` vs `let!` correctness

---

### For Production Code (Tier 2 - /code-review)

```
Task tool:
  subagent_type: "code-simplifier"
  prompt: |
    Review these files for performance and clarity:
    <list of changed files>

    Focus on:
    1. PERFORMANCE:
       - Unnecessary database queries
       - N+1 patterns
       - Inefficient loops
       - Memory bloat (large object creation in loops)

    2. SIMPLIFICATION:
       - Redundant code that can be extracted
       - Complex conditionals that can be simplified
       - Long methods that should be split
       - Unclear naming

    3. RAILS PATTERNS:
       - Use of scopes vs class methods
       - Proper use of callbacks
       - Service object patterns

    4. TEST EFFICIENCY (if spec files):
       - build vs create usage
       - Unnecessary setup
       - Slow test patterns
```

**What it optimizes**:
- All performance issues
- Code clarity and simplicity
- Rails best practices
- Test efficiency (if applicable)

---

### For Performance Issues (Tier 2 - /performance)

```
Task tool:
  subagent_type: "code-simplifier"
  prompt: |
    Review these files for performance optimization:
    <list of files with detected issues>

    Focus on:
    1. N+1 QUERY FIXES:
       - Add missing includes/preload
       - Batch queries
       - Cache repeated queries

    2. INDEX OPTIMIZATION:
       - Identify missing indexes
       - Suggest composite indexes
       - Remove unused indexes

    3. MEMORY OPTIMIZATION:
       - Replace loops with batch operations
       - Use pluck instead of select
       - Optimize large data processing

    4. QUERY EFFICIENCY:
       - Simplify complex joins
       - Use exists? instead of count
       - Optimize scopes
```

**What it optimizes**:
- Detected N+1 queries
- Missing indexes
- Memory-heavy operations
- Inefficient queries

---

### For Issue Fixes (Tier 3 - /factory-check)

```
Task tool:
  subagent_type: "code-simplifier"
  prompt: |
    Apply these factory optimizations:
    <list of detected opportunities from factory-check>

    Rules:
    - create → build (when object not persisted)
    - create → build_stubbed (when code needs id/persisted?)
    - Keep create ONLY for scopes, queries, DB operations
    - Preserve all test functionality
    - Add comments if optimization is non-obvious

    File: <spec_file_path>
```

**What it optimizes**:
- Specific issues detected by the skill
- Applies skill-detected patterns automatically
- Follows project conventions

---

## Integration Checklist

When adding code-simplifier to a skill:

### Before Integration
- [ ] Skill generates or reviews code
- [ ] Integration adds value (not just for the sake of it)
- [ ] Correct tier identified (1, 2, or 3)
- [ ] Standard prompt selected or customized
- [ ] Integration point identified in workflow

### During Integration
- [ ] Add code-simplifier to `allowed-tools` in frontmatter
- [ ] Use appropriate tier pattern
- [ ] Customize prompt for skill's specific needs
- [ ] Add "When to skip" section (if Tier 2)
- [ ] Add user approval flow (if Tier 3)
- [ ] Place at correct workflow position

### After Integration
- [ ] Add kaizen entry documenting integration
- [ ] Update skill's "Related Skills" section
- [ ] Test with sample scenario
- [ ] Document in `/orchestrate` if part of workflow
- [ ] Add example output showing code-simplifier suggestions

---

## Examples by Tier

### Example 1: Tier 1 Integration (/tdd)

```markdown
## Step 3: Write Tests (RED Phase)

[... test writing logic ...]

## Step 4: Optimize Tests (ALWAYS)

**ALWAYS run code-simplifier on new test files:**

Task tool with subagent_type: "code-simplifier"
prompt: "Review and optimize this spec file for performance and clarity:
  - Prefer build over create
  - Remove redundant test setup
  - Consolidate similar contexts
  - Ensure proper use of let vs let!
  - Remove unnecessary database operations
  File: spec/models/user_spec.rb"

The code-simplifier agent will:
- ✅ Identify slow patterns (unnecessary `create` calls)
- ✅ Suggest `build`/`build_stubbed` replacements
- ✅ Remove duplicate setup code
- ✅ Optimize factory usage
- ✅ Ensure tests are maintainable

## Step 5: Run Tests (GREEN Phase)
```

---

### Example 2: Tier 2 Integration (/performance)

```markdown
## Step 3: Detect N+1 Queries

[... detection logic ...]

## Step 4: Code Optimization (RECOMMENDED)

**After detecting performance issues, use code-simplifier to suggest fixes:**

Task tool:
  subagent_type: "code-simplifier"
  prompt: |
    Review these files for performance optimization:
    app/services/reservation_service.rb
    app/controllers/reservations_controller.rb

    Focus on:
    1. N+1 QUERY FIXES:
       - Add missing includes/preload (detected 3 N+1 patterns)
       - Batch queries
       - Cache repeated queries

    2. MEMORY OPTIMIZATION:
       - Replace loops with batch operations
       - Use pluck instead of select

**When to skip**:
- No performance issues detected
- Only configuration changes
- Pure index additions (no code changes)

## Step 5: Apply Fixes & Validate
```

---

### Example 3: Tier 3 Integration (/factory-check)

```markdown
## Step 3: Report Findings

Found 12 optimization opportunities:
- Line 15: create(:user) → build_stubbed(:user)
- Line 23: create(:facility) → create(:facility, :skip_callbacks)
- Estimated speedup: 3.2x

## Step 4: Auto-Optimize (OPTIONAL)

**Optionally apply optimizations automatically:**

Ask user: "Apply factory optimizations with code-simplifier? (y/n)"

If yes:
  Task tool:
    subagent_type: "code-simplifier"
    prompt: |
      Apply these factory optimizations:
      - Line 15: create(:user) → build_stubbed(:user) (needs id but not persisted)
      - Line 23: create(:facility) → create(:facility, :skip_callbacks) (saves 35 queries)

      Rules:
      - Preserve all test functionality
      - Add comments if optimization is non-obvious

      File: spec/services/reservation_service_spec.rb

  Wait for code-simplifier to complete

  ## Step 5: Validate Optimizations
  Run: bin/d rspec spec/services/reservation_service_spec.rb
  Expected: All tests pass, 3.2x faster

If no:
  User can apply suggested optimizations manually
  Provide line numbers and specific change recommendations
```

---

## Benefits of Integration

### For Users
- ✅ **Consistent optimization**: Same patterns applied everywhere
- ✅ **Learning tool**: See best practices in suggestions
- ✅ **Time savings**: Automated optimization vs manual analysis
- ✅ **Fewer iterations**: Right patterns from the start

### For Skills
- ✅ **Quality improvement**: Code output is optimized by default
- ✅ **Pattern enforcement**: Project conventions applied automatically
- ✅ **Reduced manual work**: Detection + fix in one workflow
- ✅ **Better user experience**: More complete solutions

### For Ecosystem
- ✅ **Standardization**: All skills use same optimization patterns
- ✅ **Cross-pollination**: Patterns from one skill benefit others
- ✅ **Continuous improvement**: code-simplifier learns and improves
- ✅ **Measurable impact**: Track optimization effectiveness

---

## Metrics to Track

After integrating code-simplifier into a skill:

### Effectiveness Metrics
- **Optimization adoption rate**: % of suggestions applied by users
- **Time saved**: Before vs after integration (user feedback)
- **Issue prevention**: Fewer performance/quality issues in reviews

### Usage Metrics
- **Execution frequency**: How often code-simplifier runs
- **Tier distribution**: ALWAYS vs MANDATORY vs OPTIONAL usage
- **Skill adoption**: More skills integrating over time

### Quality Metrics
- **Test suite performance**: Faster tests after /tdd optimization
- **Code review quality**: Fewer issues after /code-review optimization
- **Performance improvements**: Faster code after /performance optimization

---

## Troubleshooting

### code-simplifier Not Available

**Symptom**: "Tool code-simplifier not found"

**Fix**:
1. Check skill's `allowed-tools` includes `code-simplifier` (it's a subagent, not a tool)
2. Verify Task tool is available
3. Use correct syntax: `subagent_type: "code-simplifier"`

### Suggestions Too Generic

**Symptom**: code-simplifier gives generic advice, not specific fixes

**Fix**:
1. Make prompt more specific
2. Include context (e.g., "detected 3 N+1 patterns at lines X, Y, Z")
3. Provide file paths, not just file names
4. Reference specific issues from skill's detection

### User Confused by Automatic Execution

**Symptom**: User asks "Why did my code change?"

**Fix**:
1. Document in skill's "What This Skill Does" section
2. Use Tier 1 only for code GENERATION (expected optimization)
3. Consider moving to Tier 3 (user approval) if unexpected
4. Show code-simplifier output so user sees what changed

---

## Related Skills

| Skill | Tier | Integration Status |
|-------|------|-------------------|
| `/tdd` | Tier 1 (ALWAYS) | ✅ Integrated |
| `/code-review` | Tier 2 (MANDATORY) | ✅ Integrated |
| `/coverage` | Tier 1 (ALWAYS) | ✅ Integrated (2026-01-31) |
| `/performance` | Tier 2 (RECOMMENDED) | ✅ Integrated (2026-01-31) |
| `/factory-check` | Tier 3 (OPTIONAL) | 🟡 Planned |
| `/query-analyzer` | Tier 3 (OPTIONAL) | 🟡 Planned |

---

## Kaizen

<!-- Kaizen: 2026-01-31 - Initial Creation -->
- Created: Shared integration pattern for code-simplifier across all skills
- Purpose: Standardize how skills integrate code-simplifier agent
- Defined: 3 integration tiers (ALWAYS, MANDATORY, OPTIONAL)
- Provided: Standard prompts for test files, production code, performance, issue fixes
- Included: Examples, checklist, troubleshooting, metrics
- Impact: Enables consistent code-simplifier integration across 17+ skills
- ROI: 9.0 (Critical foundation for ecosystem optimization, minimal ongoing effort)
- Next: Propagate to /performance, /coverage, /factory-check
