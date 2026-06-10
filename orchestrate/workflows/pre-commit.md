# Pre-Commit Validation Workflow

> ⚡ **Fast validation before committing - catches issues early**

## Command

```bash
/orchestrate pre-commit
```

## Overview

Lightweight, parallel validation workflow that runs only on changed files:
- Runs all checks in parallel (maximum speed)
- Validates only modified code (not entire codebase)
- Fast feedback (<10min typical)
- Catches issues before CI

**Time**: 5-10min average
**Coverage**: Changed files only (delta)
**Parallelism**: Maximum (all checks independent)

## Workflow Diagram

```
┌─ PARALLEL (All Checks - 6 concurrent) ───────────┐
│  ├── Tests: make test TEST_PATH=<changed_specs>  │
│  │    → Run only specs for changed files         │
│  │    → Fast failure if any test breaks          │
│  │                                                │
│  ├── coverage: Verify 100% delta                 │
│  │    → Check patch coverage only                │
│  │    → Project coverage not decreased           │
│  │                                                │
│  ├── pronto: Lint modified files                 │
│  │    → RuboCop on changed lines only            │
│  │    → Preserves legacy code style              │
│  │                                                │
│  ├── timezone: Check changed files               │
│  │    → Scan for Time.now violations             │
│  │    → Only in modified files                   │
│  │                                                │
│  ├── security: Quick Brakeman scan               │
│  │    → Scan changed files for vulnerabilities   │
│  │    → Fast mode (--fast flag)                  │
│  │                                                │
│  └── graphql: API compat (if GraphQL changes)    │
│       → Only if app/graphql/ modified            │
│       → Check backward compatibility             │
└───────────────────────────────────────────────────┘
                        ↓
┌─ GATE (All Must Pass) ────────────────────────────┐
│  IF all passed → ready to commit                  │
│  ELSE → report failures, STOP                     │
│                                                    │
│  NO commit creation - tell user to run /commit    │
└───────────────────────────────────────────────────┘
```

## Why Pre-Commit Validation?

**Catches issues early**:
- ❌ Without: Push → CI fails → Wait 20min → Fix → Repeat
- ✅ With pre-commit: Validate → Fix locally → Push → CI passes

**Faster than CI**:
- CI runs full test suite (20-30min)
- Pre-commit runs delta only (5-10min)
- 50-70% time savings

**Prevents broken builds**:
- 80% of CI failures caught by pre-commit
- Reduces noise in CI logs
- Team doesn't see broken builds

## Phase Details

### Parallel Checks (All Run Simultaneously)

#### 1. Tests (Changed Specs Only)

**Command**:
```bash
make test TEST_PATH=spec/models/user_spec.rb,spec/services/payment_service_spec.rb
```

**What it checks**:
- Only specs for files you changed
- Fast feedback (2-5min vs 20min full suite)

**Pass criteria**: 0 failures

**Time**: 2-5min

---

#### 2. Coverage (Patch Coverage 100%)

**Command**:
```bash
docker compose exec -e SIMPLECOV_REPORT=true web bundle exec rspec <changed_specs>  # bin/d rspec for plain run
bin/d rake 'coverage:local:delta'
```

**What it checks**:
- Every line you added/changed is covered
- Project coverage didn't decrease

**Pass criteria**:
- Patch coverage: 100%
- Project coverage: Not decreased

**Time**: 30s (reuses test run)

---

#### 3. Pronto (Lint Changed Lines)

**Command**:
```bash
bin/d pronto run -c develop
```

**What it checks**:
- RuboCop violations in changed lines only
- Legacy code not affected

**Pass criteria**: 0 new violations

**Time**: 5-10s

---

#### 4. Timezone (Time.now Check)

**Command**:
```bash
grep -rn "Time\.now" <changed_files>
```

**What it checks**:
- No Time.now in changed files
- Only Time.current allowed

**Pass criteria**: 0 violations

**Time**: 1-2s

---

#### 5. Security (Quick Brakeman)

**Command**:
```bash
bin/d brakeman --fast --only-files <changed_files>
```

**What it checks**:
- Security vulnerabilities in changes
- Fast mode (skips some checks for speed)

**Pass criteria**: 0 new warnings

**Time**: 10-30s

---

#### 6. GraphQL (Conditional - API Changes Only)

**When**: Only if `app/graphql/` files changed

**Command**:
```bash
# Checks backward compatibility of API changes
```

**What it checks**:
- No breaking changes to mobile APIs
- Deferred queries still work

**Pass criteria**: No breaking changes

**Time**: 5-10s (if applicable)

---

## When to Use

✅ **Use before every commit**:
- Feature implementation complete
- Bug fix ready
- Refactoring done
- About to run `/commit`

✅ **Especially important for**:
- Changes touching critical paths (payments, auth)
- API/GraphQL modifications
- Database schema changes
- Multi-file refactorings

❌ **Skip for**:
- Documentation-only changes
- Config-only updates
- Simple typo fixes

## Success Criteria

**ALL checks must pass**:
- ✅ Tests: 0 failures
- ✅ Coverage: 100% patch, project not decreased
- ✅ Pronto: 0 new violations
- ✅ Timezone: 0 Time.now violations
- ✅ Security: 0 new warnings
- ✅ GraphQL: No breaking changes (if applicable)

**If ANY fail**:
1. Review failure report
2. Fix issue locally
3. Re-run `/orchestrate pre-commit`
4. Repeat until all pass

**DO NOT commit with failures**

## Time Estimates

| Check | Duration | Notes |
|-------|----------|-------|
| Tests (delta) | 2-5min | Only changed specs |
| Coverage | 30s | Reuses test run |
| Pronto | 5-10s | Changed lines only |
| Timezone | 1-2s | Grep on changed files |
| Security | 10-30s | Brakeman --fast |
| GraphQL | 5-10s | If applicable |
| **Total** | **5-10min** | All parallel |

**vs Full CI**: 20-30min (50-70% faster)

## Example Session

```markdown
## Pre-Commit Validation

### Changed Files (3)
- app/models/user.rb
- app/services/payment_service.rb
- spec/services/payment_service_spec.rb

### Running Parallel Checks...

┌─ Tests (changed specs) ──────────────────┐
│  2 files, 8 examples                      │
│  ✅ 8 examples, 0 failures                │
│  Time: 3min 24s                           │
└───────────────────────────────────────────┘

┌─ Coverage (patch) ───────────────────────┐
│  Lines added: 45                          │
│  Lines covered: 45                        │
│  ✅ Patch coverage: 100%                  │
│  ✅ Project: 87.3% (not decreased)        │
│  Time: 28s                                │
└───────────────────────────────────────────┘

┌─ Pronto (lint) ──────────────────────────┐
│  Files checked: 2                         │
│  ✅ 0 new violations                      │
│  Time: 6s                                 │
└───────────────────────────────────────────┘

┌─ Timezone (Time.now check) ──────────────┐
│  Files scanned: 3                         │
│  ✅ 0 violations                          │
│  Time: 1s                                 │
└───────────────────────────────────────────┘

┌─ Security (Brakeman) ────────────────────┐
│  Files scanned: 2 (--fast mode)           │
│  ✅ 0 new warnings                        │
│  Time: 18s                                │
└───────────────────────────────────────────┘

┌─ GraphQL ────────────────────────────────┐
│  ⏭️ Skipped (no GraphQL changes)          │
└───────────────────────────────────────────┘

═══════════════════════════════════════════
✅ ALL CHECKS PASSED
═══════════════════════════════════════════

Total Time: 4min 17s

Ready to commit. Run /commit when ready.
```

## Output Format (Failure Case)

```markdown
## Pre-Commit Validation

### ❌ FAILURES FOUND (2)

┌─ Tests (FAILED) ─────────────────────────┐
│  8 examples, 2 failures                   │
│                                           │
│  Failure 1:                               │
│  spec/services/payment_service_spec.rb:45 │
│  Expected nil to be present              │
│                                           │
│  Failure 2:                               │
│  spec/services/payment_service_spec.rb:67 │
│  NoMethodError: undefined method 'id'    │
│                                           │
│  Time: 3min 12s                           │
└───────────────────────────────────────────┘

┌─ Coverage (FAILED) ──────────────────────┐
│  Lines added: 45                          │
│  Lines covered: 43                        │
│  ❌ Patch coverage: 95.6% (need 100%)     │
│                                           │
│  Uncovered lines:                         │
│  - payment_service.rb:23                  │
│  - payment_service.rb:67                  │
│                                           │
│  Time: 31s                                │
└───────────────────────────────────────────┘

┌─ Pronto (OK) ────────────────────────────┐
│  ✅ 0 new violations                      │
└───────────────────────────────────────────┘

┌─ Timezone (OK) ──────────────────────────┐
│  ✅ 0 violations                          │
└───────────────────────────────────────────┘

┌─ Security (OK) ──────────────────────────┐
│  ✅ 0 new warnings                        │
└───────────────────────────────────────────┘

═══════════════════════════════════════════
❌ PRE-COMMIT VALIDATION FAILED
═══════════════════════════════════════════

Fix required:
1. Fix 2 failing tests in payment_service_spec.rb
2. Add coverage for lines 23, 67 in payment_service.rb

DO NOT commit until all checks pass.
Re-run /orchestrate pre-commit after fixes.
```

## Integration with Git Hooks

**Optional**: Install pre-commit hook to run automatically

```bash
# Install hook
./scripts/install_pre_commit_hook.sh

# Now runs automatically on `git commit`
# Can skip with: git commit --no-verify (not recommended)
```

**Hook runs**:
1. Detects changed files
2. Runs pre-commit workflow
3. Blocks commit if failures
4. Shows report

## Common Issues

### Issue: Tests pass locally but fail in pre-commit
**Cause**: Environment differences (Redis, DB state)
**Solution**: Clear Redis, reset DB, ensure clean state

### Issue: Coverage check fails but SimpleCov shows 100%
**Cause**: Different coverage calculation (patch vs file)
**Solution**: Run `rake 'coverage:local:delta'` to see patch coverage

### Issue: Pronto shows violations that were already there
**Cause**: Base branch changed, need to rebase
**Solution**: `git rebase develop`, then re-run

### Issue: Pre-commit takes too long (>15min)
**Cause**: Too many changed files
**Solution**: Break changes into smaller commits

### Issue: Brakeman timeout in security check
**Cause**: Large codebase, even with --fast
**Solution**: Skip security check for this commit, run full scan separately

## Best Practices

**DO** ✅:
- Run pre-commit before every `/commit`
- Fix all failures before committing
- Keep changes small (<300 lines) for fast validation
- Use pre-commit hook for automatic checks

**DON'T** ❌:
- Skip pre-commit to "save time" (wastes more time in CI)
- Commit with known failures (breaks CI for team)
- Run full test suite (use pre-commit's delta approach)
- Ignore pronto warnings (fix or document why ignored)

## Related Workflows

- **After pre-commit**: `/commit` (create the actual commit)
- **Full validation**: `/orchestrate feature` (comprehensive checks)
- **Bug fixing**: `/orchestrate fix` (includes debugging)

## Efficiency Tips

### 1. Run in Background
```bash
# Start pre-commit in tmux/screen
/orchestrate pre-commit &
# Continue working while it runs
```

### 2. Incremental Commits
- Commit frequently with small changes
- Faster pre-commit (fewer files)
- Easier to fix failures

### 3. Parallel Test Execution
```bash
# If many specs changed, run in parallel
PARALLEL_TEST_PROCESSORS=4 make test TEST_PATH=spec/...
```

### 4. Skip Unnecessary Checks
```bash
# If you know GraphQL not changed
/orchestrate pre-commit --skip-graphql
# (Not yet implemented, but planned)
```

---

**Back to**: [orchestrate skill](../SKILL.md) | [quick reference](../quick_reference.md) | [workflows index](./README.md)
