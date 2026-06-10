# Kaizen Quick Reference

## Commands

```bash
/kaizen                  # Full ecosystem audit (all 25 skills)
/kaizen <skill-name>     # Improve specific skill
/kaizen report           # Generate improvement metrics
```

## When to Use

### 🔴 High Priority (Run Now)
- Skill failed 2+ times in same session
- Skill hasn't been improved in 60+ days
- User reports confusion about skill instructions
- Skill takes significantly longer than expected

### 🟡 Medium Priority (Run Soon)
- Skill hasn't been improved in 30+ days
- Occasional failures (1-2 times per month)
- New patterns discovered that could improve skill
- Dependencies changed (e.g., new MCP tools available)

### 🟢 Low Priority (Run When Time Permits)
- Skill works well but could be slightly better
- Minor clarity improvements possible
- Recent improvement but small optimizations found

## Quick Checklist

Before running kaizen, ask yourself:

1. **What's wrong?** (Specific issue, not "it could be better")
2. **How often?** (One-time bug vs systematic problem)
3. **Impact?** (High/Med/Low - affects many users?)
4. **Effort?** (Quick fix vs major rewrite?)
5. **ROI?** (Impact/Effort ratio > 1.0?)

If ROI < 1.0, consider if improvement is worth it.

## Kaizen Types

### 🎯 Clarity Kaizen
**Problem**: Instructions vague, users ask questions
**Fix**: Add specific commands, expected output, examples
**Time**: 5-10 min
**Example**: "Verify coverage" → "Run: ... Expected: Coverage: 100%"

### ⚡ Efficiency Kaizen
**Problem**: Skill takes too long, redundant steps
**Fix**: Parallelize tasks, cache results, optimize workflow
**Time**: 10-20 min
**Example**: 5 sequential tasks → 3 parallel + 2 sequential

### 🛡️ Reliability Kaizen
**Problem**: Skill fails unpredictably, missing error handling
**Fix**: Add validations, handle edge cases, provide fallbacks
**Time**: 15-30 min
**Example**: Assume file exists → Check exists, handle missing

### ✅ Validation Kaizen
**Problem**: Success assumed, not verified
**Fix**: Parse output, verify exact conditions, explicit criteria
**Time**: 10-15 min
**Example**: "Run tests" → Parse output, count failures, verify 0

### 🔧 Maintainability Kaizen
**Problem**: Hardcoded values, unclear dependencies
**Fix**: Reference conventions, document choices, link docs
**Time**: 5-10 min
**Example**: Hardcoded path → Use CLAUDE.md convention

## Example Scenarios

### Scenario 1: TDD Skill Slow
```
Issue: TDD skill takes 15 min, users complain
Analysis: Runs coverage after each file (redundant)
Solution: Run coverage once at end
Impact: 15 min → 10 min (-33%)
Type: Efficiency Kaizen
Effort: Low (5 min)
ROI: High (6.6)
```

### Scenario 2: Security Skill Fails
```
Issue: Brakeman timeouts on large codebases
Analysis: No timeout handling, no --fast fallback
Solution: Add timeout, retry with --fast, parse errors
Impact: 5% failure → 1% failure
Type: Reliability Kaizen
Effort: Medium (20 min)
ROI: Medium (2.5)
```

### Scenario 3: Coverage Skill Confusing
```
Issue: Users don't understand what "verify coverage" means
Analysis: Vague instructions, no expected output
Solution: Add exact command, expected output format, examples
Impact: 10 questions/week → 2 questions/week
Type: Clarity Kaizen
Effort: Low (5 min)
ROI: High (8.0)
```

## ROI Calculation

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

Examples:
  High/Low   = 3/3 = 1.0 (Break even)
  High/Med   = 3/2 = 1.5 (Good)
  High/High  = 3/1 = 3.0 (Excellent)
  Med/Low    = 2/3 = 0.67 (Skip)
  Low/High   = 1/1 = 1.0 (Break even)
```

## Priority Matrix

```
           │ Low Effort │ Med Effort │ High Effort
───────────┼────────────┼────────────┼─────────────
High Impact│ 🔴 Do Now  │ 🔴 Do Now  │ 🟡 Schedule
Med Impact │ 🟡 Do Soon │ 🟡 Do Soon │ 🟢 Consider
Low Impact │ 🟢 Maybe   │ ⚪ Skip    │ ⚪ Skip
```

## Kaizen Session Template

```markdown
# Kaizen: <skill-name> - YYYY-MM-DD

## 1. Observe (5 min)
- Read skill.md completely
- Check kaizen_log.md for history
- Review user feedback (if any)

## 2. Analyze (10 min)
- [ ] Clarity issues?
- [ ] Efficiency problems?
- [ ] Reliability gaps?
- [ ] Validation missing?
- [ ] Maintainability concerns?

## 3. Design (5 min)
Issues found:
1. **Type**: Description (Impact: X, Effort: Y, ROI: Z)
2. **Type**: Description (Impact: X, Effort: Y, ROI: Z)

Sorted by ROI:
1. Issue #X (ROI: Z)
2. Issue #Y (ROI: Z)

## 4. Implement (varies)
- [ ] Edit skill.md
- [ ] Add Kaizen comment
- [ ] Update orchestrator if needed
- [ ] Update kaizen_log.md

## 5. Validate (5 min)
- [ ] Dry-run skill (if possible)
- [ ] Instructions clearer?
- [ ] No side effects?
- [ ] Improvements effective?

## 6. Reflect (5 min)
Before/After:
- Metric 1: X → Y (change%)
- Metric 2: X → Y (change%)

Lessons learned:
- Key takeaway 1
- Key takeaway 2
```

## Common Mistakes

### ❌ Don't Do
- Kaizen everything at once → Focus on ROI > 1.5
- Change without understanding → Read skill.md first
- Skip validation → Always test improvements
- Forget to document → Update kaizen_log.md
- Ignore user feedback → Users know pain points best

### ✅ Do Do
- Prioritize by ROI → High impact, low effort first
- Get user approval for major changes → Avoid surprises
- Validate with dry-run → Catch regressions early
- Document before/after → Track improvements
- Consider side effects → Check dependent skills

## Success Indicators

A skill is "sharp" when:

1. **Users understand** - No questions about what to do
2. **Execution is fast** - No wasted steps or redundancy
3. **Results reliable** - Consistent outcomes, handled errors
4. **Validation clear** - Explicit success/failure criteria
5. **Maintenance easy** - Clear docs, no magic values

## Maintenance Schedule

### Proactive Kaizen (Recommended)
```
Monthly:  Run /kaizen report (check ecosystem health)
Quarterly: Improve top 3 skills from priority matrix
Yearly:   Full audit of all 25 skills
```

### Reactive Kaizen (As Needed)
```
Immediately: If skill fails 2+ times in session
Within 1 week: If user reports confusion
Within 1 month: If skill not improved in 90+ days
```

## Kaizen Metrics to Track

```markdown
## Skill Health Dashboard

| Skill | Usage | Fail Rate | Last Kaizen | Priority |
|-------|-------|-----------|-------------|----------|
| tdd | High | 2% | 30d | 🔴 27 |
| coverage | High | 1% | 15d | 🟡 18 |
| security | Med | 5% | 60d | 🔴 36 |

Legend:
- Usage: High (daily), Med (weekly), Low (monthly)
- Fail Rate: % of executions that fail
- Last Kaizen: Days since last improvement
- Priority: (Usage × Complexity × Days) / 100
```

---

**Remember**: Kaizen is continuous improvement, not perfection.
**Goal**: Make each skill 1% better each time.
**Result**: Compound improvements over time → Sharp saw, effortless cutting.
