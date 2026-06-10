# Bug Fix Workflow

> 🐛 **Debug production issues and implement fixes with comprehensive validation**

## Command

```bash
/orchestrate fix <issue-number>
```

## Overview

Systematic workflow for debugging and fixing production issues:
- Debug with Honeybadger + ClickHouse
- Analyze root cause with GitHub issue context
- Context-aware domain validation
- TDD-based fix implementation
- Quality verification

**Time**: 15-30min (depending on issue complexity)
**Success Rate**: High (systematic debugging reduces guesswork)

## Workflow Diagram

```
┌─ SEQUENTIAL (Debug) ──────────────────────────────┐
│  debug: Honeybadger + ClickHouse investigation    │
│    → Fault analysis (error patterns)              │
│    → Stack traces and occurrences                 │
│    → Production data queries                      │
│    → Context gathering                            │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (Analyze) ────────────────────────────┐
│  fix-issue: Analyze issue, identify root cause    │
│    → GitHub issue details                         │
│    → Related code search                          │
│    → Impact assessment                            │
│    → Root cause identification                    │
└───────────────────────────────────────────────────┘
                        ↓
┌─ CONTEXT (Domain Skills) ─────────────────────────┐
│  Run ONLY if issue is domain-specific:            │
│  ├── memberships: If membership-related bug       │
│  ├── graphql: If API-related bug                  │
│  ├── sidekiq: If job-related bug                  │
│  ├── multi-tenancy: If data isolation issue       │
│  └── performance: If performance regression       │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (TDD Fix) ────────────────────────────┐
│  tdd: Write failing test → fix → verify           │
│    → RED: Reproduce bug with test                 │
│    → GREEN: Implement minimal fix                 │
│    → REFACTOR: Clean up if needed                 │
│    → VERIFY: Test passes consistently             │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Quality) ──────────────────────────────┐
│  ├── coverage: Verify 100% on fix                │
│  ├── code-review: Verify fix is correct           │
│  └── pronto: Lint changes                         │
└───────────────────────────────────────────────────┘
                        ↓
┌─ STOP - Ready for User Commit ───────────────────┐
│  🚫 orchestrate CANNOT create commits             │
│  ✅ Tell user: "Bug fix ready, all checks passed" │
│  📝 Tell user: "Run /commit when ready"           │
│  🔗 Reference GitHub issue in commit message      │
└───────────────────────────────────────────────────┘
```

## Phase Details

### Phase 1: Debug (Systematic Investigation)

**Goal**: Understand the bug completely before touching code

**Tools Used**:
- Honeybadger: Error tracking, fault analysis
- ClickHouse: Production data queries
- GitHub: Issue context, reproduction steps

**Outputs**:
1. Error message and stack trace
2. Frequency and affected users
3. Code location (file + line)
4. Recent changes that might have caused it
5. Production data patterns

**Example**:
```markdown
## Debug Report

Error: NoMethodError: undefined method `strftime' for nil:NilClass
Location: app/services/membership_service.rb:45
Occurrences: 127 in last 24 hours
Affected: 12 facilities (all using weekly memberships)
Recent Change: Commit abc123def (2 days ago) - "Add weekly renewal logic"

Root Cause Hypothesis:
Weekly memberships don't have acquired_at date set, causing nil error.
```

### Phase 2: Analyze (Root Cause Identification)

**Goal**: Identify exact root cause, not just symptoms

**Questions to Answer**:
1. What triggered the error?
2. Why did it start happening now?
3. What edge case was missed?
4. Is this a regression or new code issue?
5. Are there similar issues elsewhere?

**Tools**:
- GitHub issue tracker
- Git blame and history
- Code search across codebase
- Pattern Learning MCP (historical bugs)

**Output**: Clear root cause statement

### Phase 3: Context (Domain Validation)

**Conditional - Only run relevant domain skills**:

| Issue Type | Domain Skill | Purpose |
|------------|--------------|---------|
| Membership bug | `/memberships` | Validate business rules |
| API error | `/graphql` | Check backward compatibility |
| Job failure | `/sidekiq` | Validate job patterns |
| Data leak | `/multi-tenancy` | Verify facility scoping |
| Slow query | `/performance` | Check N+1, indexes |

**Why Conditional**: Saves 5-10min by skipping irrelevant checks

### Phase 4: TDD Fix (Test-Driven Bug Fix)

**Critical Pattern**: RED → GREEN → REFACTOR

1. **RED**: Write test that reproduces the bug
   ```ruby
   it 'handles nil acquired_at for weekly memberships' do
     membership = create(:membership, :weekly, acquired_at: nil)
     expect { MembershipService.new(membership).renewal_date }
       .not_to raise_error
   end
   ```

2. **GREEN**: Implement minimal fix
   ```ruby
   def renewal_date
     return Time.current if acquired_at.nil?
     acquired_at + 7.days
   end
   ```

3. **REFACTOR**: Clean up if needed
   ```ruby
   def renewal_date
     (acquired_at || Time.current) + renewal_period
   end
   ```

4. **VERIFY**: Run test multiple times to ensure consistency

**Why TDD for Bugs**: Prevents regression, documents the fix

### Phase 5: Quality (Parallel Verification)

All quality checks run in parallel:

| Check | Purpose | Pass Criteria |
|-------|---------|---------------|
| coverage | Verify fix is tested | 100% on changed lines |
| code-review | Verify fix is correct | No logic errors |
| pronto | Verify style | Clean (no violations) |

**Time**: ~2-3min (parallel execution)

## When to Use

✅ **Use this workflow for**:
- Production bugs (Honeybadger alerts)
- GitHub issues with error reports
- User-reported bugs
- Regression issues
- Performance problems

❌ **Don't use for**:
- Feature requests (use `/orchestrate feature`)
- Refactoring (use `/orchestrate refactor`)
- Simple typos (fix directly)

## Success Criteria

All must pass:
- ✅ Root cause identified and documented
- ✅ Bug reproduced with failing test
- ✅ Fix implemented and test passes
- ✅ Coverage 100% on fix
- ✅ Code review passed
- ✅ No new lint violations

If ANY fail: Fix and re-run

## Time Estimates

| Phase | Duration | Notes |
|-------|----------|-------|
| Debug | 5-10min | Honeybadger + ClickHouse |
| Analyze | 3-5min | Root cause identification |
| Context | 2-5min | Only if domain-specific |
| TDD Fix | 5-15min | Depends on complexity |
| Quality | 2-3min | Parallel checks |
| **Total** | **15-30min** | Avg 20min for typical bug |

## Example Session

```markdown
## Bug Fix: Membership Renewal Error

### Phase 1: Debug
✅ Honeybadger: NoMethodError at membership_service.rb:45
✅ ClickHouse: 127 occurrences, 12 facilities affected
✅ Pattern: Only weekly memberships, all missing acquired_at

### Phase 2: Analyze
✅ Root cause: Weekly memberships created without acquired_at date
✅ Introduced: Commit abc123def (2 days ago)
✅ Edge case: Signup flow doesn't set acquired_at for weekly plans

### Phase 3: Context
✅ memberships: Validated renewal business rules
⏭️ sidekiq: Skipped (not job-related)

### Phase 4: TDD Fix
✅ RED: Test reproduces nil error (5min)
✅ GREEN: Added nil check + fallback (3min)
✅ REFACTOR: Simplified logic (2min)

### Phase 5: Quality
✅ coverage: 100% (30s)
✅ code-review: Fix validated (1min)
✅ pronto: Clean (5s)

✅ Bug fix ready. All checks passed.
📝 Run /commit when ready
🔗 Closes #1234

Total Time: 18min
```

## Output Format

```markdown
## Bug Fix Report

### Issue
GitHub #1234: Membership renewal crashes for weekly plans

### Root Cause
Weekly memberships don't have `acquired_at` set during signup,
causing nil error when calculating renewal_date.

### Fix Applied
Added nil check with fallback to Time.current:
```ruby
def renewal_date
  (acquired_at || Time.current) + renewal_period
end
```

### Tests Added
- spec/services/membership_service_spec.rb:45-52
- Covers nil acquired_at edge case
- Verified with weekly membership factory

### Quality Checks
✅ Tests: 1 new example, 0 failures
✅ Coverage: 100% on membership_service.rb
✅ Code Review: No issues
✅ Pronto: Clean

### Impact
- Fixes: 127 errors/day
- Affects: 12 facilities
- Prevents: Future weekly membership errors

Ready for commit. Closes #1234
```

## Common Pitfalls

| Pitfall | Impact | Solution |
|---------|--------|----------|
| Fixing without test | Regression risk | Always write failing test first |
| Fixing symptoms not cause | Bug returns | Complete debug phase |
| Skipping domain validation | Related bugs missed | Run context-aware skills |
| Not checking production data | Incomplete fix | Always query ClickHouse |

## Troubleshooting

### Issue: Can't reproduce bug locally
**Solution**: Use ClickHouse to get production data patterns, create factory with same attributes

### Issue: Fix works but test flaky
**Solution**: Use `Timecop.freeze`, clear Redis, check for race conditions

### Issue: Multiple possible root causes
**Solution**: Fix one at a time, verify each with test, deploy incrementally

### Issue: Fix too complex
**Solution**: Break into smaller fixes, each with own test and PR

## Related Workflows

- **Simpler**: Direct fix (no orchestration needed for obvious bugs)
- **More Complex**: `/orchestrate refactor` (if bug reveals design issue)
- **Prevention**: `/orchestrate code-review` (catch bugs before production)

---

**Back to**: [orchestrate skill](../SKILL.md) | [quick reference](../quick_reference.md) | [workflows index](./README.md)
