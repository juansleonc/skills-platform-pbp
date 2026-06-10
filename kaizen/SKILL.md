---
name: kaizen
description: Continuous skill improvement meta-skill. Audits, refines, and enhances all skills in the ecosystem through ROI-prioritized iteration. Use when skills fail repeatedly, after major changes, or for periodic ecosystem health checks.
allowed-tools: [Bash, Read, Grep, Glob, Edit, Write]
disable-model-invocation: true
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

# Kaizen Skill - Continuous Skill Improvement (Consolidated Edition)

> "Sharpen the saw" - 改善 (Kaizen)

## Purpose

Systematically improve the quality, efficiency, and effectiveness of ALL skills in the ecosystem through analysis, testing, and refinement. This is the meta-skill that maintains peak effectiveness of all other skills.

## Philosophy

> "Skills are code. Code degrades. Therefore, skills must be continuously improved."
>
> **Continuous improvement is better than delayed perfection.**

Every skill should be:
- **Accurate**: Does what it promises
- **Efficient**: No wasted steps
- **Clear**: Easy to understand and use
- **Reliable**: Consistent results
- **Maintainable**: Easy to update

## Core Principles

1. **Self-Improvement**: Skills that don't evolve become obsolete
2. **Data-Driven**: Use actual usage patterns and failures to guide improvements
3. **Systematic**: Regular audits catch issues before they impact users
4. **Collaborative**: Learn from each skill's kaizen sections
5. **Measurable**: Track improvements over time
6. **ROI-Focused**: Prioritize high-impact, low-effort improvements

## When to Use

### Automatic Triggers
- **After 2+ skill failures** in same session (orchestrator queues for kaizen)
- **Every 10 skill executions** (periodic health check)
- **After major changes** (Rails upgrade, new patterns, MCP tools)
- **Weekly scheduled audit** (if enabled)

### Manual Triggers
```bash
/kaizen                    # Full ecosystem audit (all 25 skills)
/kaizen <skill-name>       # Improve specific skill
/kaizen report             # Generate improvement metrics
/kaizen suggest            # Suggest improvements based on recent sessions
/kaizen metrics            # Show skill usage and effectiveness metrics
```

## Kaizen Cycle (6 Phases)

```
┌─────────────────────────────────────────────────────────┐
│                   KAIZEN IMPROVEMENT CYCLE              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Phase 1: OBSERVE (Data Collection)                    │
│  ┌──────────────────────────────────────────────┐      │
│  │ • Scan all skill files                       │      │
│  │ • Skill execution metrics (if available)     │      │
│  │ • User feedback patterns                     │      │
│  │ • Failed execution analysis                  │      │
│  │ • Dependency analysis                        │      │
│  │ • Parse kaizen sections (lessons learned)    │      │
│  │ • Recent skill execution failures            │      │
│  └──────────────────────────────────────────────┘      │
│                        ▼                                │
│  Phase 2: ANALYZE (Find Root Causes)                   │
│  ┌──────────────────────────────────────────────┐      │
│  │ • Read skill.md thoroughly                   │      │
│  │ • Check for outdated patterns                │      │
│  │ • Identify unclear instructions              │      │
│  │ • Find redundant steps                       │      │
│  │ • Detect missing validations                 │      │
│  │ • Analyze tool usage patterns                │      │
│  │ • Identify inconsistencies across skills     │      │
│  └──────────────────────────────────────────────┘      │
│                        ▼                                │
│  Phase 3: DESIGN (Plan Improvements)                   │
│  ┌──────────────────────────────────────────────┐      │
│  │ • Propose specific changes                   │      │
│  │ • Estimate impact (High/Med/Low = 3/2/1)     │      │
│  │ • Estimate effort (Low/Med/High = 3/2/1)     │      │
│  │ • Calculate ROI = Impact / Effort            │      │
│  │ • Prioritize by ROI (≥1.5 = Do Now)          │      │
│  │ • Consider side effects                      │      │
│  └──────────────────────────────────────────────┘      │
│                        ▼                                │
│  Phase 4: IMPLEMENT (Apply Changes)                    │
│  ┌──────────────────────────────────────────────┐      │
│  │ • Update skill.md with Edit tool             │      │
│  │ • Update outdated documentation              │      │
│  │ • Add missing examples                       │      │
│  │ • Consolidate duplicate patterns             │      │
│  │ • Cross-pollinate best practices             │      │
│  │ • Add Kaizen comment with date               │      │
│  │ • Update orchestrator dependencies           │      │
│  │ • Document changes in kaizen log             │      │
│  └──────────────────────────────────────────────┘      │
│                        ▼                                │
│  Phase 5: VALIDATE (Test Improvements)                 │
│  ┌──────────────────────────────────────────────┐      │
│  │ • Verify YAML frontmatter is valid           │      │
│  │ • Check all tool references exist            │      │
│  │ • Validate markdown structure                │      │
│  │ • Test examples for accuracy                 │      │
│  │ • Ensure no broken references                │      │
│  │ • Dry-run skill with test scenario           │      │
│  │ • Verify instructions are clearer            │      │
│  │ • Check for unintended consequences          │      │
│  │ • Get user confirmation if major change      │      │
│  └──────────────────────────────────────────────┘      │
│                        ▼                                │
│  Phase 6: REFLECT (Document Learnings)                 │
│  ┌──────────────────────────────────────────────┐      │
│  │ • Log improvements made                      │      │
│  │ • Update kaizen_log.md                       │      │
│  │ • Update metrics (skill health report)       │      │
│  │ • Record before/after metrics                │      │
│  │ • Note lessons learned                       │      │
│  │ • Suggest ecosystem-wide patterns            │      │
│  │ • Create improvement report                  │      │
│  │ • Add kaizen entry to improved skills        │      │
│  └──────────────────────────────────────────────┘      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Audit Checklist (For Each Skill)

### Critical Priority (Must Pass)
- [ ] YAML frontmatter is valid
- [ ] All tools in allowed-tools exist
- [ ] No broken tool references in content
- [ ] All shared doc references resolve (no missing ../shared/*.md files)

### High Priority (Should Pass)
- [ ] Has clear description in frontmatter
- [ ] description: states triggers only — no workflow/phase/step summary (cross-ref skill-creator's CSO Rule)
- [ ] Purpose is well-defined
- [ ] No outdated patterns (Time.now, allow_any_instance_of, .to_s(:db))
- [ ] Examples use correct factory patterns (build > build_stubbed > create)
- [ ] Docker commands follow CLAUDE.local.md (make/bin/d, not bundle exec)
- [ ] Consistent with CLAUDE.md rules
- [ ] Skill achieves its stated purpose
- [ ] Instructions are actionable

### Medium Priority (Nice to Have)
- [ ] When to use section exists
- [ ] Examples are present and accurate
- [ ] References to shared docs are correct
- [ ] No duplicate content across skills
- [ ] Clear dependency relationships
- [ ] Workflow is efficient
- [ ] No unnecessary complexity

### Low Priority (Optional)
- [ ] Recent kaizen entries exist
- [ ] Related skills section present

## Behavior-Test Eval (When Auditing an Existing Skill)

Text audits (reading, checklist, dry-run) catch syntax and structural issues but cannot tell you whether the skill actually changes subagent behavior. After any audit that finds a defect — or when a skill repeatedly fails or produces incorrect output — run the pressure-test protocol from `skill-creator/SKILL.md` ("Pressure-Test Before Ship") against the skill being audited. Canonical protocol lives there; this section is the kaizen integration point only.

**Quick eval loop:**

1. **RED baseline**: dispatch a fresh subagent (Agent tool) on a scenario the skill governs, WITHOUT providing the skill. If the agent already complies without the skill, the section is a **redundant-section candidate** (see below).
2. **GREEN check**: re-run the same scenario WITH the skill present. If the agent still fails, the skill text is not landing — **rewrite the section, do not append more text**.
3. **Pressure variant**: rerun GREEN under combined pressures (time + sunk cost + authority). A skill that only works without pressure is not proven.

Document results in the skill's Kaizen entry. An audit without a behavior test only proves the skill READS correctly, not that it WORKS.

### Prune Counterpart

Kaizen entries historically only add content — the natural direction is growth. The eval step above is the deletion mechanism. Apply it when:

- A section fails the RED baseline (agent complied without the skill) → the section is redundant bloat; candidate for pruning or consolidation.
- A section fails GREEN despite being present → rewrite from scratch, not append; appending redundant counters grows the file without fixing the root cause.

Before pruning, verify: re-run RED with the section removed. If behavior is unchanged, remove it. If behavior regresses, keep and rewrite.

---

## Improvement Categories (5 Types)

### 1. Clarity Issues
**What**: Vague instructions, missing examples, unclear expectations
**Fix**: Add specific commands, expected output, concrete examples

```markdown
❌ BAD: "Check the code for issues"
✅ GOOD: "Run Brakeman to detect OWASP Top 10 vulnerabilities:
         docker compose exec web bundle exec brakeman
         Expected: Exit code 0, no new vulnerabilities"
```

### 2. Efficiency Issues
**What**: Redundant steps, sequential independent tasks, repeated operations
**Fix**: Parallelize, cache results, optimize workflow

```markdown
❌ BAD: Run 5 sequential commands that could be parallel
✅ GOOD: Mark independent tasks for parallel execution with Task tool
```

### 3. Reliability Issues
**What**: Missing error handling, unvalidated assumptions, no fallbacks
**Fix**: Add validations, handle edge cases, provide recovery steps

```markdown
❌ BAD: Assume file exists, read it directly
✅ GOOD: Check if file exists first, handle missing case gracefully
```

### 4. Validation Issues
**What**: Success assumed not verified, vague criteria, no failure detection
**Fix**: Parse output, verify exact conditions, explicit expectations

```markdown
❌ BAD: "Verify coverage"
✅ GOOD: "Run: docker compose exec web bundle exec rake 'coverage:local:file[app/models/user.rb]'
         Expected output: 'Coverage: 100%'"
```

### 5. Maintainability Issues
**What**: Hardcoded values, undocumented choices, duplicate content
**Fix**: Reference conventions, explain decisions, link to shared docs

```markdown
❌ BAD: Hardcoded path, magic numbers
✅ GOOD: Use CLAUDE.md conventions, reference shared docs, explain constants
```

## Improvement Patterns (5 Patterns)

### Pattern 1: Cross-Pollinate Best Practices
When one skill discovers a useful pattern, propagate it:

```markdown
Example: /tdd discovers factory optimization pattern
→ Check if /coverage, /code-review need same pattern
→ Add to shared/factory-rules.md
→ Reference from all relevant skills
```

### Pattern 2: Consolidate Duplicates
Multiple skills with similar content should reference shared docs:

```markdown
Before:
- /tdd has factory rules (50 lines)
- /coverage has factory rules (45 lines, slightly different)
- /code-review has factory rules (60 lines, different again)

After:
- shared/factory-rules.md (single source of truth)
- All skills reference: "See [Factory Rules](../shared/factory-rules.md)"
- Each skill has 2-3 key points only
```

### Pattern 3: Update Examples
Code examples become stale. Verify and update:

```bash
# Find potentially outdated examples
grep -r "Time\.now" .claude/skills/*/skill.md
grep -r "\.to_s(:db)" .claude/skills/*/skill.md
grep -r "allow_any_instance_of" .claude/skills/*/skill.md
grep -r "bundle exec" .claude/skills/*/skill.md | grep -v "docker\|make\|bin/d"
```

### Pattern 4: Add Integration Points
Skills should reference related skills:

```markdown
## Related Skills
- Use `/memberships` for domain knowledge
- Use `/tdd` for test implementation
- Use `/coverage` to verify 100% coverage
- Part of `/orchestrate membership` workflow
```

### Pattern 5: Improve Workflow Efficiency
Look for opportunities to parallelize or skip unnecessary steps:

```markdown
Example: Can analysis skills run in parallel?
- /timezone, /packwerk, /security are independent
- Can use Task tool with parallel: true
- Update /orchestrate workflow map
```

## ROI Prioritization System

### ROI Calculation
```
Impact Score:
  High = 3 (affects all users, frequent use, critical path)
  Med  = 2 (affects some users, occasional use)
  Low  = 1 (affects few users, rare use, nice-to-have)

Effort Score:
  Low  = 3 (< 10 min, simple change)
  Med  = 2 (10-30 min, moderate complexity)
  High = 1 (> 30 min, major rewrite)

ROI = Impact / Effort

Priority Decision:
  ROI ≥ 1.5 → 🔴 Do Now
  ROI ≥ 1.0 → 🟡 Do Soon
  ROI < 1.0 → 🟢 Consider/Skip
```

### Priority Matrix
```
           │ Low Effort │ Med Effort │ High Effort
───────────┼────────────┼────────────┼─────────────
High Impact│ 🔴 Do Now  │ 🔴 Do Now  │ 🟡 Schedule
Med Impact │ 🟡 Do Soon │ 🟡 Do Soon │ 🟢 Consider
Low Impact │ 🟢 Maybe   │ ⚪ Skip    │ ⚪ Skip
```

### Ecosystem Priority Formula
For full ecosystem audits, prioritize skills by:

```
Priority = (Usage × Complexity × Days_Since_Kaizen) / 100

Where:
- Usage: High=3, Med=2, Low=1 (how often skill is used)
- Complexity: High=3, Med=2, Low=1 (how complex the skill is)
- Days: Actual days since last kaizen improvement

Example:
- tdd (High usage, High complexity, 30 days)
  = (3 × 3 × 30) / 100 = 2.7 → Priority: HIGH

- docker-exec (Med usage, Low complexity, 10 days)
  = (2 × 1 × 10) / 100 = 0.2 → Priority: LOW
```

## Validation Commands

### Validate YAML Frontmatter
```bash
# Check each skill has valid YAML
for skill in .claude/skills/*/skill.md; do
  echo "Checking: $skill"
  head -10 "$skill" | grep -E "^(name|description|allowed-tools):" || echo "❌ Invalid YAML"
done
```

### Check for Outdated Patterns
```bash
# Forbidden patterns
grep -r "Time\.now" .claude/skills/*/skill.md
grep -r "allow_any_instance_of" .claude/skills/*/skill.md
grep -r "\.to_s(:db)" .claude/skills/*/skill.md

# Docker violations
grep -r "bundle exec" .claude/skills/*/skill.md | grep -v "docker\|make\|bin/d"
```

### Validate Shared References

**Comprehensive validation** - checks all skills for broken references:

```bash
# Check for broken shared doc references
for skill in .claude/skills/*/skill.md; do
  skill_name=$(basename $(dirname "$skill"))
  grep -n '](../shared/' "$skill" 2>/dev/null | while IFS=: read linenum line; do
    ref=$(echo "$line" | sed 's/.*](\.\.\/\.\.\/shared\///' | sed 's/).*//' | sed 's/#.*//')
    if [ -n "$ref" ] && [ ! -f ".claude/skills/shared/$ref" ]; then
      echo "❌ $skill_name:$linenum references missing: $ref"
    fi
  done
done
```

**Expected**: No output (all references valid)

**Quick check** - verify common shared docs exist:

```bash
for doc in factory-rules.md forbidden-patterns.md testing-patterns.md critical-rules.md clickhouse-queries.md code-simplifier-integration.md; do
  if [ -f ".claude/skills/shared/$doc" ]; then
    echo "✅ $doc"
  else
    echo "❌ $doc MISSING"
  fi
done
```

**Expected**: All files show ✅

### Check Tool References
```bash
# Find all tool references
grep -r "mcp__" .claude/skills/*/skill.md | cut -d: -f2 | sort -u

# Verify tools exist (check against available MCPs)
```

## Kaizen Workflows

### Workflow 1: Full Ecosystem Audit

```
/kaizen

┌─ PHASE 1: Inventory (ALL skills) ─────────────────┐
│  List all 25 skills with:                         │
│  ├── Last modified date                           │
│  ├── Lines of content                             │
│  ├── Number of kaizen entries                     │
│  ├── Number of dependencies                       │
│  └── Known issues count                           │
└───────────────────────────────────────────────────┘
                        ▼
┌─ PHASE 2: Priority Matrix ────────────────────────┐
│  Score each skill by:                             │
│  ├── Usage frequency (High/Med/Low)               │
│  ├── Complexity (High/Med/Low)                    │
│  ├── Last improvement date (days ago)             │
│  └── Known issues count                           │
│                                                    │
│  Priority = (Usage × Complexity × Days) / 100     │
│  Sort by priority (highest first)                 │
└───────────────────────────────────────────────────┘
                        ▼
┌─ PHASE 3: Audit Top 5 ────────────────────────────┐
│  For each of top 5 priority skills:               │
│  ├── Read skill.md thoroughly                     │
│  ├── Run audit checklist                          │
│  ├── Identify improvement opportunities           │
│  ├── Calculate ROI for each improvement           │
│  └── Propose changes sorted by ROI                │
└───────────────────────────────────────────────────┘
                        ▼
┌─ PHASE 4: User Review ────────────────────────────┐
│  Present findings:                                │
│  ├── Top 5 skills needing improvement             │
│  ├── Issues found (Critical/High/Medium/Low)      │
│  ├── Proposed changes with ROI scores             │
│  └── Recommended order of improvements            │
│                                                    │
│  Ask: "Which skill should I improve first?"       │
└───────────────────────────────────────────────────┘
                        ▼
┌─ PHASE 5: Implement (One skill at a time) ────────┐
│  For selected skill:                              │
│  ├── Apply improvements to skill.md               │
│  ├── Update dependencies in orchestrator          │
│  ├── Validate with dry-run                        │
│  ├── Document in kaizen_log.md                    │
│  └── Generate improvement report                  │
└───────────────────────────────────────────────────┘
                        ▼
┌─ PHASE 6: Report ─────────────────────────────────┐
│  Generate improvement summary:                    │
│  ├── Changes made                                 │
│  ├── Expected benefits                            │
│  ├── Before/after metrics                         │
│  ├── Remaining opportunities                      │
│  └── Next recommended skill                       │
└───────────────────────────────────────────────────┘
```

### Workflow 2: Single Skill Improvement

```
/kaizen <skill-name>

┌─ PHASE 1: Observe & Read ─────────────────────────┐
│  ├── Read skill.md completely                     │
│  ├── Understand purpose and workflow              │
│  ├── Note dependencies                            │
│  ├── Review kaizen history                        │
│  └── Check recent failure patterns                │
└───────────────────────────────────────────────────┘
                        ▼
┌─ PHASE 2: Analyze (Run Checklist) ────────────────┐
│  ✓ Critical: YAML valid, tools exist              │
│  ✓ High: Clear purpose, no outdated patterns      │
│  ✓ Medium: Examples present, workflow efficient   │
│  ✓ Low: Kaizen entries, related skills            │
│                                                    │
│  Find issues in 5 categories:                     │
│  ├── Clarity issues                               │
│  ├── Efficiency problems                          │
│  ├── Reliability gaps                             │
│  ├── Validation missing                           │
│  └── Maintainability concerns                     │
└───────────────────────────────────────────────────┘
                        ▼
┌─ PHASE 3: Design (Prioritize by ROI) ─────────────┐
│  For each issue found:                            │
│  ├── Estimate Impact (High=3, Med=2, Low=1)       │
│  ├── Estimate Effort (Low=3, Med=2, High=1)       │
│  ├── Calculate ROI = Impact / Effort              │
│  └── Sort by ROI (highest first)                  │
│                                                    │
│  Recommend: Apply improvements with ROI ≥ 1.0     │
└───────────────────────────────────────────────────┘
                        ▼
┌─ PHASE 4: Implement (Get Approval) ───────────────┐
│  Show proposed changes (top 5 by ROI)             │
│  For each:                                        │
│  ├── Current state (quote from skill.md)          │
│  ├── Problem description                          │
│  ├── Proposed solution                            │
│  ├── Expected benefit                             │
│  └── ROI score                                    │
│                                                    │
│  Ask: "Approve these improvements? (y/n)"         │
│  If approved → Apply changes with Edit tool       │
└───────────────────────────────────────────────────┘
                        ▼
┌─ PHASE 5: Validate ───────────────────────────────┐
│  ├── Validate YAML frontmatter                    │
│  ├── Check tool references                        │
│  ├── Verify markdown structure                    │
│  ├── Dry-run skill (if possible)                  │
│  ├── Verify instructions clearer                  │
│  └── Check no unintended side effects             │
└───────────────────────────────────────────────────┘
                        ▼
┌─ PHASE 6: Reflect & Document ─────────────────────┐
│  ├── Update kaizen_log.md with session            │
│  ├── Add kaizen entry to skill.md                 │
│  ├── Update skill health metrics                  │
│  ├── Generate before/after comparison             │
│  └── Suggest next skill for improvement           │
└───────────────────────────────────────────────────┘
                        ▼
┌─ OUTPUT: Improvement Report ──────────────────────┐
│  ## Kaizen Report: <skill-name> - YYYY-MM-DD      │
│                                                    │
│  ### Summary                                      │
│  - Issues found: X                                │
│  - Changes applied: Y (ROI ≥ 1.0)                 │
│  - Skipped: Z (ROI < 1.0)                         │
│                                                    │
│  ### Before/After Metrics                         │
│  | Metric | Before | After | Change |             │
│  |--------|--------|-------|--------|             │
│  | ...    | ...    | ...   | ...    |             │
│                                                    │
│  ### Changes Applied                              │
│  1. ✅ Type: Description (ROI: X)                 │
│     - Before: ...                                 │
│     - After: ...                                  │
│     - Benefit: ...                                │
│                                                    │
│  ### Lessons Learned                              │
│  - Key takeaway 1                                 │
│  - Key takeaway 2                                 │
└───────────────────────────────────────────────────┘
```

### Workflow 3: Generate Metrics Report

```
/kaizen metrics

┌─ PHASE 1: Gather Stats ───────────────────────────┐
│  For all 25 skills:                               │
│  ├── Count total kaizen improvements              │
│  ├── Find most/least improved skills              │
│  ├── Calculate avg improvement frequency          │
│  ├── Identify skills needing attention            │
│  └── Track failure rates (if available)           │
└───────────────────────────────────────────────────┘
                        ▼
┌─ PHASE 2: Analyze Trends ─────────────────────────┐
│  ├── Which improvement types most common?         │
│  ├── Which skills improved most?                  │
│  ├── What patterns emerge?                        │
│  ├── Which skills haven't been touched?           │
│  └── Are improvements effective?                  │
└───────────────────────────────────────────────────┘
                        ▼
┌─ PHASE 3: Generate Report ────────────────────────┐
│  ## Skill Health Report - YYYY-MM-DD              │
│                                                    │
│  ### Overall Stats                                │
│  - Total skills: 25                               │
│  - Total improvements: XX                         │
│  - Avg improvements per skill: X.X                │
│  - Last 30 days: XX improvements                  │
│                                                    │
│  ### Skills by Health Status                      │
│  | Skill | Last Kaizen | Issues | Status |        │
│  |-------|-------------|--------|--------|        │
│  | tdd | 15d | 0 | ✅ Healthy |                   │
│  | coverage | 45d | 1 | ⚠️ Review |               │
│  | timezone | 90d | 2 | 🔴 Action Required |      │
│                                                    │
│  ### Top Improved Skills                          │
│  1. security (5 improvements, -80% failures)      │
│  2. tdd (4 improvements, -33% time)               │
│                                                    │
│  ### Skills Needing Attention                     │
│  1. timezone (last improved: 90 days ago)         │
│  2. gateway-test (never improved)                 │
│                                                    │
│  ### Common Improvement Types                     │
│  - Clarity: 35%                                   │
│  - Efficiency: 25%                                │
│  - Reliability: 20%                               │
│  - Validation: 15%                                │
│  - Maintainability: 5%                            │
│                                                    │
│  ### Recommendations                              │
│  - Next 3 skills to improve: ...                  │
│  - Patterns to propagate: ...                     │
│  - Shared docs to create: ...                     │
└───────────────────────────────────────────────────┘
```

### Workflow 4: Suggest Improvements

```
/kaizen suggest

┌─ PHASE 1: Analyze Recent Sessions ────────────────┐
│  ├── Review last 10 skill executions              │
│  ├── Identify patterns in failures                │
│  ├── Note repeated issues                         │
│  └── Find skills used together                    │
└───────────────────────────────────────────────────┘
                        ▼
┌─ PHASE 2: Cross-Reference Patterns ───────────────┐
│  ├── Compare with kaizen_log.md                   │
│  ├── Find similar issues in other skills          │
│  ├── Identify ecosystem-wide patterns             │
│  └── Check for missed opportunities               │
└───────────────────────────────────────────────────┘
                        ▼
┌─ PHASE 3: Generate Suggestions ───────────────────┐
│  ## Kaizen Suggestions - YYYY-MM-DD               │
│                                                    │
│  Based on recent usage, I suggest:                │
│                                                    │
│  ### High Priority (Do Now)                       │
│  1. **security**: Failed 3 times this week        │
│     - Issue: Timeout on large codebases           │
│     - Fix: Add timeout handling + --fast fallback │
│     - Estimated ROI: 3.0 (High impact, low effort)│
│                                                    │
│  ### Medium Priority (This Week)                  │
│  2. **coverage**: Confusing output format         │
│     - Issue: Users ask "what does 95% mean?"      │
│     - Fix: Show uncovered lines explicitly        │
│     - Estimated ROI: 2.0                          │
│                                                    │
│  ### Ecosystem-Wide Pattern                       │
│  3. **All skills**: Docker command inconsistency  │
│     - Pattern: Some use make, some use bin/d      │
│     - Fix: Standardize on bin/d in examples       │
│     - Skills affected: 8                          │
│                                                    │
│  Would you like me to run /kaizen security?       │
└───────────────────────────────────────────────────┘
```

## Integration with Orchestrator

The orchestrator integrates kaizen in these ways:

### 1. After Skill Failures
```
If skill X fails 2+ times in session:
  1. Complete current task with alternative approach
  2. Queue skill X for kaizen analysis
  3. At end of session, notify user:
     "⚠️ Skill X failed multiple times. Run /kaizen X to improve?"
```

### 2. Periodic Reviews
```
Every 10 skill executions:
  1. Generate /kaizen suggest automatically
  2. Show top 3 improvement opportunities
  3. Ask: "Run kaizen on any of these skills?"
```

### 3. After Successful Workflows
```
After successful workflow completion:
  1. Log success pattern
  2. Note any improvements discovered during execution
  3. Update relevant skill kaizen sections with learnings
```

## Kaizen Log Format

All improvements tracked in `.claude/skills/kaizen/kaizen_log.md`:

```markdown
## YYYY-MM-DD - skill-name

### Issues Found
1. **Type**: Description (Impact: X, Effort: Y, ROI: Z)

### Changes Made
```diff
- Old approach
+ New approach
```

### Impact
- Metric: before → after (change%)
- Example: Failure rate: 5% → 1% (-80%)

### Lessons Learned
- Key takeaway that applies to other skills
- Pattern that could be propagated
```

## Kaizen Backlog

Track future improvements:

```markdown
## Kaizen Backlog

### High Priority
- [ ] Create shared/skill-writing-guide.md template
- [ ] Add automated YAML validation to CI
- [ ] Consolidate Docker command examples across all skills

### Medium Priority
- [ ] Add skill usage metrics tracking
- [ ] Create skill dependency graph visualization
- [ ] Document skill execution patterns

### Low Priority
- [ ] Add skill effectiveness scoring system
- [ ] Create skill changelog automation
- [ ] Build skill search/discovery tool
```

## Success Criteria

A skill is "sharp" when:

1. ✅ **Clarity**: 0 user questions about what to do
2. ⚡ **Efficiency**: No redundant steps, optimal tool usage
3. 🛡️ **Reliability**: >95% success rate, handled edge cases
4. ✅ **Validation**: Explicit success/failure criteria
5. 🔧 **Maintainability**: Easy to update, clear documentation

## Best Practices

### DO ✅
- Read skill.md completely before suggesting changes
- Prioritize by ROI (Impact/Effort)
- Get user approval for major changes
- Validate with dry-run after changes
- Document before/after metrics
- Update kaizen_log.md
- Consider side effects on dependent skills
- Small, frequent improvements over large overhauls
- Cross-pollinate patterns across skills
- Test examples still work after updates

### DON'T ❌
- Make changes without understanding context
- Improve everything at once (focus on high ROI)
- Skip validation phase
- Forget to update orchestrator dependencies
- Ignore user feedback
- Change for the sake of change
- Break dependent skills
- Wait for perfection (iterate instead)

## Common Improvements (Quick Patterns)

### 1. Add Shared Reference
```markdown
<!-- Before -->
## Factory Rules
[50 lines of factory documentation]

<!-- After -->
## Factory Rules
> 📖 **See [Factory Rules](../shared/factory-rules.md) for complete patterns.**

Quick reference:
- build(:factory) - DEFAULT for validations, methods
- create(:factory) - ONLY for scopes, queries, DB ops
```

### 2. Update Docker Commands
```markdown
<!-- Before -->
bundle exec rspec spec/models/user_spec.rb

<!-- After -->
bin/d rspec spec/models/user_spec.rb
# OR
make test TEST_PATH=spec/models/user_spec.rb
```

### 3. Add Integration Points
```markdown
## Related Skills
- Use `/tdd` for test implementation
- Use `/coverage` to verify 100% coverage
- Part of `/orchestrate feature` workflow
```

### 4. Add Kaizen Entry
```markdown
<!-- Kaizen: 2026-01-26 -->
- Added: Shared reference to factory-rules.md (removed 50 lines duplication)
- Updated: All Docker commands to use bin/d
- Added: Related Skills section
- Fixed: Broken MCP tool reference
```

## Maintenance Schedule

### Proactive (Recommended)
```
Every 10 executions: /kaizen suggest (automatic)
Monthly:             /kaizen report (ecosystem health check)
Quarterly:           Improve top 3 priority skills
Yearly:              Full audit of all 25 skills
```

### Reactive (As Needed)
```
Immediately:      Skill fails 2+ times in session
Within 1 week:    User reports confusion
Within 1 month:   Skill not improved in 90+ days
```

## Output Format

```markdown
# Kaizen Report: <Skill Name> - YYYY-MM-DD

## Summary
- Issues found: X
- Changes applied: Y (ROI ≥ 1.0)
- Skipped: Z (ROI < 1.0)
- Estimated impact: High/Med/Low

## Before/After Metrics
| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Clarity score (1-10) | 6 | 9 | +50% |
| Avg execution time | 5min | 3min | -40% |
| Success rate | 80% | 95% | +19% |
| Steps count | 12 | 8 | -33% |

## Changes Applied

1. ✅ **Type**: Description (ROI: X.X)
   - Before: Quote from old skill.md
   - After: New approach
   - Benefit: Specific improvement

[Repeat for each change]

## Skipped Improvements

1. ⏭️ **Type**: Description (ROI: X.X)
   - Reason: Why skipped (low impact, etc.)
   - Deferred: When to reconsider

## Lessons Learned
- Key takeaway 1 (ecosystem-wide)
- Pattern that could propagate to other skills
- Technical insight discovered

## Next Steps
- Remaining opportunities: X
- Recommended next skill: Y (Priority: Z)
```

## Related Skills

| Skill | Relationship |
|-------|--------------|
| `/orchestrate` | Coordinates kaizen checks, triggers after failures |
| `/qa-audit` | Validates skill quality (complementary) |
| `/code-review` | Uses similar analysis patterns |
| `/architect` | Applies similar systematic thinking |

## Remember

> "Continuous improvement is better than delayed perfection."
>
> **Don't wait. Improve incrementally. Document progress. Share learnings.**

Skills are living documentation. They must evolve with the project, patterns, and tools. Kaizen ensures they stay sharp, relevant, and effective.

---

## Meta-Kaizen

> "Even the kaizen skill must practice kaizen."

<!-- Kaizen: 2026-01-26 - Consolidated Edition -->
- Created: Consolidated version combining platform and platform2
- Combined: 6-phase process + audit checklist + 5 improvement patterns
- Added: ROI calculation + priority formulas + validation commands
- Integrated: All workflows (audit, improve, metrics, suggest)
- Documentation: Merged quick_reference, implementation, examples into main skill
- Purpose: Single comprehensive kaizen skill for both platforms
- Next: Apply to both platform and platform2

<!-- Kaizen: 2026-02-01 - Shared Documentation Validation -->
- Added: "All shared doc references resolve" to Critical Priority checklist
- Improved: "Validate Shared References" section with comprehensive validation script
- Why: 7 broken references to mcp-tools-guide.md (removed), preventing ecosystem trust
- Impact: Future kaizen sessions will catch broken references early
- Validation: Automated script checks all skills for broken ../shared/*.md links
- ROI: 1.8 (High impact - prevents broken refs, Low effort - automated check)

<!-- Kaizen: 2026-06-09 - CSO description-lint added to audit checklist -->
- Added (High Priority checklist): "description: states triggers only — no workflow/phase/step summary" (cross-refs skill-creator's CSO Rule section).
- Why: the CSO rule lived only in skill-creator, firing only when authoring NEW skills; the existing corpus (orchestrate, adversarial-review, architect, code-review) was never linted against it. Putting it in the kaizen audit makes it enforceable ecosystem-wide.
- ROI: 3.0 (High impact; Low effort — one checklist line).

<!-- Kaizen: 2026-06-10 — Behavior-Test Eval + Prune Counterpart -->
Added "Behavior-Test Eval" section and "Prune Counterpart" note to the audit/improvement workflow.
- Source: obra/superpowers writing-skills + testing-skills-with-subagents.md (MIT, commit 6fd4507).
- Trigger: spike (investigations/superpowers-spike/findings.md, 2026-06-10) found 50/50 local skills never behavior-tested; real defects shipped (fabricated file:line citations in multi-tenancy/SKILL.md; CSO violation in tdd frontmatter). Deferred-until-observed trigger condition fired.
- What was added: RED/GREEN/pressure eval loop for existing skills (Agent-tool dispatch); explicit rule that if agent complies WITHOUT the skill, the section is redundant; prune counterpart (deletion mechanism for growth ratchet); cross-reference to skill-creator's canonical protocol (no duplication).
- What was NOT ported: persuasion-principles/Cialdini framing, EXTREMELY_IMPORTANT wrappers, SessionStart hook, CLI harness — conflicts with low-friction philosophy (memory: feedback_no_redundant_verification_hooks).
- ROI: 3.0 (High impact — catches behavior-invisible defects; Low effort — eval is Agent dispatch, ~5 min per section).
