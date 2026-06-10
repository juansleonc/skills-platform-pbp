# Simple Workflow

> ⚡ **Fast-track workflow for small, straightforward changes**

## Command

```bash
/orchestrate simple
```

## Overview

Streamlined workflow for:
- Small bug fixes (< 50 lines)
- Documentation updates
- Minor refactors
- Configuration changes
- Typo fixes
- Comment updates

**Time**: 3-5min average
**Risk**: VERY LOW (minimal changes)
**Critical**: Quick validation, no over-engineering

**NOT for**:
- New features (use `/orchestrate feature`)
- Production bugs (use `/orchestrate fix`)
- Database changes (use `/orchestrate migration`)
- GraphQL changes (use `/orchestrate api`)
- Payment code (use `/orchestrate membership`)
- Security issues (use `/orchestrate security-hardening`)

## Workflow Diagram

```
┌─ PHASE 1: Quick Validation (PARALLEL) ───────────┐
│  ├── Syntax: Verify code syntax                  │
│  │    → Ruby -c check                            │
│  │    → No parse errors                          │
│  │                                                │
│  ├── Tests: Run affected specs only              │
│  │    → Find related test file                   │
│  │    → Run single spec or small suite           │
│  │    → Expected: < 1min                         │
│  │                                                │
│  └── Lint: Pronto on changed lines only          │
│       → Docker: bin/d pronto                     │
│       → Only modified files                      │
│       → Expected: < 5s                           │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PHASE 2: Coverage Check (QUICK) ────────────────┐
│  IF code change (not docs/comments):             │
│    → Run SimpleCov on changed file               │
│    → Verify ≥95% coverage (relaxed for simple)   │
│    → Expected: < 30s                             │
│  ELSE:                                           │
│    → Skip (docs don't need coverage)             │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PHASE 3: STOP - Ready for Commit ───────────────┐
│  🚫 orchestrate CANNOT create commits            │
│  ✅ Tell user: \"All checks passed\"              │
│  📝 Tell user: \"Run /commit when ready\"         │
│  ⛔ NEVER proceed to git operations              │
└───────────────────────────────────────────────────┘
```

## When to Use

### ✅ USE Simple Workflow For:

**Documentation**:
- README updates
- Code comments
- JSDoc/YARD documentation
- Markdown files

**Small Fixes**:
- Typo corrections
- Variable renaming (< 5 occurrences)
- Log message updates
- Error message improvements

**Minor Refactors**:
- Extract single method (< 10 lines)
- Simplify conditional (< 5 lines)
- Remove dead code (< 20 lines)

**Configuration**:
- Environment variable updates
- Config file tweaks
- Linter rule adjustments

**Cosmetic Changes**:
- Formatting fixes
- Whitespace cleanup
- Comment alignment

### ❌ DON'T Use Simple Workflow For:

**Anything that affects behavior**:
- Logic changes
- Algorithm updates
- Data transformations
- API responses

**Anything with dependencies**:
- Multi-file changes (> 3 files)
- Schema changes
- Gateway updates
- GraphQL modifications

**Anything requiring domain expertise**:
- Membership logic
- Payment processing
- Multi-tenancy
- Security-sensitive code

**When uncertain**: Use `/orchestrate feature` instead (better safe than sorry)

## Phase Details

### Phase 1: Quick Validation (Parallel - 3 checks)

#### 1.1 Syntax Check
```bash
# Ruby syntax validation
bin/d ruby -c app/models/user.rb

# Expected output: "Syntax OK"
```

**Time**: < 1s

---

#### 1.2 Tests (Affected Only)
```bash
# Find related spec
# app/models/user.rb → spec/models/user_spec.rb

# Run single spec
bin/d rspec spec/models/user_spec.rb

# Expected: < 1min for small spec
```

**Time**: 10-60s (depending on spec size)

**Skip if**:
- No related spec exists (docs, configs)
- Change is comment-only

---

#### 1.3 Lint (Changed Lines Only)
```bash
# Pronto on modified files only
bin/d pronto run -c develop

# Expected: Clean or minor style fixes
```

**Time**: < 5s

**Auto-fix allowed**: `rubocop -A` on changed lines (simple workflow allows this)

---

### Phase 2: Coverage Check (Quick)

**IF code change**:
```bash
# Check coverage on changed file
bin/d rake 'coverage:local:file[app/models/user.rb]'

# Expected: ≥95% (relaxed for simple changes)
```

**Time**: < 30s

**IF docs/comments only**:
- Skip coverage (no code to cover)

---

### Phase 3: STOP

**Output**:
```markdown
## Simple Workflow Complete ✅

Validation Results:
- ✅ Syntax: OK
- ✅ Tests: 12 examples, 0 failures
- ✅ Lint: Clean
- ✅ Coverage: 98% (target: ≥95%)

Total Time: 1min 23s

✅ Ready for commit
📝 Run /commit when ready
```

**NEVER**:
- Create git commit (user must run `/commit`)
- Run full test suite (only affected specs)
- Run all static analyzers (too slow)
- Run domain validators (not needed for simple changes)

---

## Examples

### Example 1: Typo Fix in README

**Change**: Fix spelling error in README.md

**Workflow**:
```
┌─ PHASE 1 (Parallel) ──────────────────────────────┐
│  ✅ Syntax: N/A (markdown)                        │
│  ✅ Tests: N/A (no test for README)               │
│  ✅ Lint: pronto (markdown linting)               │
│     → Time: 1s                                    │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PHASE 2 ─────────────────────────────────────────┐
│  ⏭️ Coverage: Skipped (docs don't need coverage)  │
└───────────────────────────────────────────────────┘
                        ↓
✅ Ready for commit (total: 2s)
```

---

### Example 2: Update Log Message

**Change**: Improve log message in `app/services/payment_service.rb:45`

```ruby
# Before
Rails.logger.info "Payment processed"

# After
Rails.logger.info "Payment processed successfully for user #{user_id}"
```

**Workflow**:
```
┌─ PHASE 1 (Parallel) ──────────────────────────────┐
│  ✅ Syntax: ruby -c payment_service.rb (OK)       │
│  ✅ Tests: rspec spec/services/payment_service_spec.rb │
│     → 45 examples, 0 failures (32s)               │
│  ✅ Lint: pronto (clean)                          │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PHASE 2 ─────────────────────────────────────────┐
│  ✅ Coverage: 100% (no new code, just message)    │
│     → Time: 5s                                    │
└───────────────────────────────────────────────────┘
                        ↓
✅ Ready for commit (total: 42s)
```

---

### Example 3: Extract Small Method

**Change**: Extract 5-line helper method from controller

```ruby
# Before
def index
  @users = User.where(active: true)
               .where("created_at > ?", 30.days.ago)
               .order(created_at: :desc)
  render json: @users
end

# After
def index
  @users = recent_active_users
  render json: @users
end

private

def recent_active_users
  User.where(active: true)
      .where("created_at > ?", 30.days.ago)
      .order(created_at: :desc)
end
```

**Workflow**:
```
┌─ PHASE 1 (Parallel) ──────────────────────────────┐
│  ✅ Syntax: ruby -c users_controller.rb (OK)      │
│  ✅ Tests: rspec spec/controllers/users_controller_spec.rb │
│     → 8 examples, 0 failures (15s)                │
│  ✅ Lint: pronto (clean)                          │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PHASE 2 ─────────────────────────────────────────┐
│  ✅ Coverage: 100% (method already covered)       │
│     → Time: 8s                                    │
└───────────────────────────────────────────────────┘
                        ↓
✅ Ready for commit (total: 28s)
```

---

## Success Criteria

**ALL must pass**:
- ✅ Syntax valid (no parse errors)
- ✅ Affected tests passing (0 failures)
- ✅ Lint clean (or auto-fixed)
- ✅ Coverage ≥95% if code changed (relaxed threshold)

**IF ANY fail**: Fix and re-run simple workflow

---

## Time Estimates

| Component | Duration | Notes |
|-----------|----------|-------|
| Syntax check | < 1s | Instant validation |
| Affected tests | 10-60s | Depends on spec size |
| Lint (pronto) | < 5s | Only changed lines |
| Coverage check | 5-30s | Single file check |
| **Total** | **1-2min** | Avg 90s |

**Comparison**:
- Simple workflow: 1-2min
- Pre-commit workflow: 5-10min (all checks)
- Feature workflow: 27min (full pipeline)

**Use simple when**: Change is tiny, obvious, low-risk

---

## Comparison with Other Workflows

| Workflow | Time | Use For | Checks |
|----------|------|---------|--------|
| **simple** | 1-2min | Typos, docs, minor fixes | Syntax + affected tests + lint |
| pre-commit | 5-10min | Before every commit | Tests + coverage + lint + quick scans |
| feature | 27min | New features, major changes | Full pipeline with all validators |
| fix | 20min | Production bugs | Debug + fix + full validation |

**Golden Rule**: If uncertain, use pre-commit or feature (not simple)

---

## Workflow Decision Tree

```
Is change < 50 lines?
│
├─ NO → Use /orchestrate feature (or appropriate workflow)
│
└─ YES → Is it one of these?
         │
         ├─ Docs, comments, README → /orchestrate simple ✅
         ├─ Typo fix, log message → /orchestrate simple ✅
         ├─ Config update (no logic) → /orchestrate simple ✅
         ├─ Extract tiny method (< 10 lines) → /orchestrate simple ✅
         │
         └─ Logic change, algorithm, API → /orchestrate feature
            Multi-file change → /orchestrate feature
            Payment/membership code → /orchestrate membership
            Database change → /orchestrate migration
            GraphQL change → /orchestrate api
```

---

## Best Practices

### DO ✅:
- Use for truly simple changes only
- Run affected tests (not full suite)
- Auto-fix lint issues with `rubocop -A`
- Skip coverage for docs/comments
- Trust your judgment on "simple"

### DON'T ❌:
- Use for logic changes (use feature workflow)
- Use for multi-file changes (> 3 files)
- Use for payment/membership code (use domain workflows)
- Use for security-sensitive code (use security-hardening)
- Skip tests "because it's simple" (always run affected tests)
- Ignore lint violations (fix or use pre-commit workflow)

---

## Common Mistakes

### ❌ Mistake #1: Using Simple for Feature Addition
```
User: "Add new user validation (just one line)"
❌ Wrong: /orchestrate simple
✅ Right: /orchestrate feature
Reason: Validation affects behavior, needs full validation
```

### ❌ Mistake #2: Skipping Tests
```
User: "It's just a comment, no need to run tests"
❌ Wrong: Skip tests
✅ Right: Run tests (ensure no syntax errors broke anything)
```

### ❌ Mistake #3: Simple for Multi-File
```
User: "Rename variable across 5 files"
❌ Wrong: /orchestrate simple
✅ Right: /orchestrate refactor
Reason: Multi-file changes need full validation
```

---

## Troubleshooting

### Issue: Tests Failing

**Problem**: Affected tests have failures
**Solution**:
1. Fix the test failures
2. Re-run simple workflow
3. If complex, switch to `/orchestrate feature`

### Issue: Coverage Below 95%

**Problem**: Coverage check fails
**Solution**:
1. Add missing tests
2. OR switch to `/orchestrate feature` for full TDD
3. Don't ignore coverage (even for simple changes)

### Issue: Lint Violations

**Problem**: Pronto reports style issues
**Solution**:
1. Run `bin/d rubocop -A` on changed files
2. Manual fixes if auto-fix doesn't work
3. Re-run simple workflow

---

## Related Workflows

- **Pre-commit**: Use instead if change affects behavior
- **Feature**: Use for anything > 50 lines or multi-file
- **Refactor**: Use for code restructuring (even if small)

---

## Quick Reference

```bash
# Simple workflow checklist
[ ] Change < 50 lines?
[ ] Docs, comments, or typo?
[ ] No logic changes?
[ ] Single file (or ≤ 3 files)?
[ ] Not payment/membership/security?

If ALL YES → /orchestrate simple ✅
If ANY NO → Use appropriate workflow instead
```

**Time**: 1-2min average
**When**: Truly simple, obvious, low-risk changes only
**Safety**: Still validates syntax, tests, lint, coverage

---

**Back to**: [orchestrate skill](../SKILL.md) | [quick reference](../quick_reference.md) | [workflows index](README.md)
