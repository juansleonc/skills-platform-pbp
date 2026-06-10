# Coverage Debug Workflow

> 🐛 **Resolve CI/local coverage discrepancies and achieve >90% push confidence**

## Command

```bash
/orchestrate coverage-debug
```

## Overview

Workflow for when CI coverage fails but local passes:
- Local verification (parallel checks)
- Codecov analysis (identify false positives)
- Decision matrix (trust local vs fix)
- Exhaustive pre-push validation
- Confidence scoring (90%+ to push)

**Time**: 20-30min average
**Risk**: LOW (validation only)
**Critical**: Don't push unless >90% confident

**Origin**: Based on lessons from PR #3998 (Codecov false positive, -30% project coverage bug)

## Workflow Diagram

```
┌─ PHASE 1: Local Verification (PARALLEL) ──────────┐
│  ├── Run specs: bundle exec rspec spec/...        │
│  │    → All specs must pass                       │
│  │    → 0 failures expected                       │
│  │                                                 │
│  ├── SimpleCov: Check patch coverage              │
│  │    → Line-by-line verification                 │
│  │    → 100% patch coverage required              │
│  │                                                 │
│  └── Line-by-line: Verify each changed line       │
│       → Manual inspection of coverage report      │
│       → Confirm all new/changed lines tested      │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PHASE 2: Codecov Analysis ───────────────────────┐
│  ├── Check Codecov report on PR                   │
│  │    → Compare with local SimpleCov              │
│  │    → Identify coverage discrepancies           │
│  │                                                 │
│  ├── Identify discrepancies with local            │
│  │    → Patch coverage: Local vs Codecov          │
│  │    → Project coverage: Change delta            │
│  │                                                 │
│  └── Determine if false positive                  │
│       → >10% project drop = almost always bug     │
│       → Patch mismatch = base commit issue        │
└───────────────────────────────────────────────────┘
                        ↓
┌─ DECISION MATRIX ─────────────────────────────────┐
│                                                    │
│  Local 100% + Codecov <100% patch                 │
│    → Trust local, push anyway                     │
│    → Codecov will recalculate on merge            │
│                                                    │
│  Local <100% + Codecov <100%                      │
│    → Fix coverage (both agree)                    │
│    → Add missing tests                            │
│                                                    │
│  Local 100% + Codecov -30%+ project drop          │
│    → Codecov bug (base commit mismatch)           │
│    → Trust local, push anyway                     │
│    → Document discrepancy in PR                   │
│                                                    │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PHASE 3: Exhaustive Pre-Push Validation ─────────┐
│  Run ALL validation checks before pushing:        │
│                                                    │
│  ├── Tests: ALL specs passing                     │
│  │    → docker compose exec web rspec             │
│  │    → Must: 0 failures                          │
│  │                                                 │
│  ├── Coverage: 100% patch verified                │
│  │    → SimpleCov line-by-line check              │
│  │    → Must: 100% on all changed lines           │
│  │                                                 │
│  ├── Lint: Pronto clean                           │
│  │    → docker compose exec web pronto            │
│  │    → Must: No new violations                   │
│  │                                                 │
│  ├── Security: Brakeman clean                     │
│  │    → docker compose exec web brakeman          │
│  │    → Must: No new vulnerabilities              │
│  │                                                 │
│  ├── Migration: Up/down/up cycle (if applicable)  │
│  │    → Test migration reversibility              │
│  │    → Must: Rollback works                      │
│  │                                                 │
│  └── Rake tasks: DRY_RUN test (if applicable)     │
│       → Test task syntax                          │
│       → Must: Runs without errors                 │
└───────────────────────────────────────────────────┘
                        ↓
┌─ OUTPUT: Confidence Report ───────────────────────┐
│  ## Push Confidence Score: X%                     │
│                                                    │
│  ### Validation Results                           │
│  Tests:      ✅ 206/206 passing (+30%)            │
│  Coverage:   ✅ 100% patch (+30%)                 │
│  Lint:       ✅ Clean (+10%)                      │
│  Security:   ✅ Clean (+10%)                      │
│  Migration:  ✅ Reversible (+10%)                 │
│  Tasks:      ✅ Syntax OK (+5%)                   │
│  Structure:  ✅ Clean diff (+5%)                  │
│                                                    │
│  **Total Confidence: 95%** → ✅ SAFE TO PUSH      │
│                                                    │
│  ### Codecov Discrepancy                          │
│  Local:  100% patch coverage                      │
│  Codecov: 95% patch (false positive)              │
│  Project: -32% (base commit mismatch bug)         │
│                                                    │
│  **Decision**: Trust local, push anyway           │
│  **Reason**: >10% project drop = Codecov bug      │
│                                                    │
│  ### Potential Risks                              │
│  - None identified                                │
│                                                    │
│  Ready to push with 95% confidence ✅             │
└───────────────────────────────────────────────────┘
```

## Key Learnings (PR #3998)

### 1. Codecov False Positives are Real

**Problem**: Massive project coverage drops (>10%) are almost always bugs

**Causes**:
- Base commit mismatch (Codecov comparing wrong commits)
- Merge confusion (branch not up to date)
- Timing issues (Codecov processing old data)

**Solution**: Trust local SimpleCov, push anyway, Codecov recalculates correctly after merge

---

### 2. Validation Phases Must Be Exhaustive

**Problem**: Tests alone (or coverage alone) aren't enough

**Solution**: Validate ALL dimensions:
- Tests (100%)
- Coverage (100% patch)
- Lint (clean)
- Security (clean)
- Migration (reversible if applicable)
- Rake tasks (syntax if applicable)

**Impact**: 15-20 min pre-push validation saves hours of CI wait + fixes

---

### 3. Memory Optimization in Batch Processing

**Problem**: `pluck` loads all IDs into memory (bad for >10k records)

**Rule**:
```ruby
# ❌ BAD for >10k records
ids = Membership.pluck(:id)
ids.each { |id| process(id) }

# ✅ GOOD for any size
Membership.find_in_batches(batch_size: 1000) do |batch|
  batch.each { |m| process(m.id) }
end
```

---

### 4. Structure.sql Manual Review

**Problem**: `rails db:migrate` generates 649-line diffs

**Solution**: Manual cleanup
```bash
# Reset structure.sql to develop
git checkout origin/develop -- db/structure.sql

# Add only YOUR changes
# - Your new column/index
# - Migration timestamp

# Prevents massive diffs that obscure actual changes
```

---

### 5. Pre-Push Confidence Threshold

**Rule**: Don't push unless >90% confident it will pass CI

**Key Metrics**:
- Tests: 100% (required)
- Coverage: 100% patch (required)
- Lint: Clean (required)
- Security: Clean (required)

**If <90%**: Investigate more before pushing

---

## Validation Checklist

### MANDATORY Checks

```bash
# 1. Tests (MANDATORY) +30%
docker compose exec -e RAILS_ENV=test web bundle exec rspec spec/...
# Must: 0 failures

# 2. Coverage (MANDATORY) +30%
docker compose exec -e SIMPLECOV_REPORT=true web bundle exec rspec spec/...
# Must: 100% patch coverage verified line-by-line

# 3. Lint (MANDATORY for modified files) +10%
bin/d pronto run -c develop
# Must: Clean

# 4. Security (MANDATORY for models/services/controllers) +10%
bin/d brakeman --only-files app/...
# Must: No new vulnerabilities
```

### CONDITIONAL Checks

```bash
# 5. Migration (if db/migrate/) +10%
docker compose exec -e RAILS_ENV=test web bundle exec rails db:migrate:down VERSION=...
docker compose exec -e RAILS_ENV=test web bundle exec rails db:migrate:up VERSION=...
# Must: Reversible

# 6. Rake Tasks (if lib/tasks/) +5%
docker compose exec -e RAILS_ENV=test web bundle exec rake task:name DRY_RUN=1
# Must: Syntax OK, runs without errors

# 7. Structure.sql (if db/structure.sql changed) +5%
git diff develop...HEAD db/structure.sql | wc -l
# Should: <10 lines changed (only your migration)
```

---

## Confidence Scoring

```
Confidence Score = Sum of passed checks

Tests passing:        +30%
Coverage 100% patch:  +30%
Lint clean:           +10%
Security clean:       +10%
Migration reversible: +10% (if applicable)
Rake tasks work:      +5% (if applicable)
Structure.sql clean:  +5% (if applicable)
─────────────────────────
Maximum:              100%

Minimum to push:      90%

Decision:
  ≥90% → ✅ SAFE TO PUSH
  <90% → ⚠️ FIX ISSUES FIRST
```

---

## Decision Matrix

| Local Coverage | Codecov Patch | Codecov Project | Decision |
|----------------|---------------|-----------------|----------|
| 100% | <100% | Normal | Trust local, push |
| <100% | <100% | Normal | Fix coverage |
| 100% | <100% | -30%+ drop | Codecov bug, push |
| 100% | 100% | -30%+ drop | Codecov bug, push |

---

## When to Use

✅ **Use this workflow for**:
- CI coverage fails but local passes
- Codecov shows massive project drop (>10%)
- Uncertain if coverage is actually OK
- Before pushing to avoid CI failures
- High-confidence validation needed

❌ **Don't use for**:
- Both local and CI agree coverage is bad (just fix it)
- Simple fixes (<50 lines)
- Draft PRs (not ready for CI yet)

---

## Time Estimates

| Phase | Duration | Notes |
|-------|----------|-------|
| Local Verification | 3-5min | Parallel checks |
| Codecov Analysis | 2-3min | Compare reports |
| Decision | 1min | Apply matrix |
| Exhaustive Validation | 15-20min | All checks |
| **Total** | **20-30min** | Avg 25min |

---

## Example Session

```markdown
## Coverage Debug Session - PR #3998

### Phase 1: Local Verification (4min)

**Tests**: ✅ 206 examples, 0 failures
**Coverage**: ✅ 100% patch (12/12 lines)
**Line-by-line**: ✅ All changed lines covered

### Phase 2: Codecov Analysis (2min)

**Codecov Patch**: 95% (claims 1 uncovered line)
**Codecov Project**: -32% drop (BUG!)
**Comparison**: Local 100% vs Codecov 95%

**Analysis**: >10% project drop = Codecov bug (base commit mismatch)

### Decision Matrix

Local 100% + Codecov -32% project → **Codecov bug, trust local, push**

### Phase 3: Exhaustive Validation (18min)

| Check | Result | Confidence |
|-------|--------|------------|
| Tests | ✅ 206/206 | +30% |
| Coverage | ✅ 100% patch | +30% |
| Lint | ✅ Clean | +10% |
| Security | ✅ Clean | +10% |
| Migration | ✅ Reversible | +10% |
| Structure | ✅ <10 lines | +5% |

**Total Confidence**: 95%

### Confidence Report

✅ **SAFE TO PUSH** (95% confidence)

**Codecov Discrepancy**: False positive (base commit bug)
**Risks**: None identified
**Recommendation**: Push, Codecov will recalculate on merge

**Total Time**: 24 minutes

Result: Pushed, CI passed, Codecov recalculated to 100% ✅
```

---

## Best Practices

**DO** ✅:
- Trust local SimpleCov over Codecov (if >90% confident)
- Run exhaustive validation before pushing
- Document Codecov discrepancies in PR
- Check all validation dimensions (not just tests)
- Use confidence scoring (>90% to push)

**DON'T** ❌:
- Push without exhaustive validation (<90% confidence)
- Ignore massive Codecov project drops (investigate first)
- Trust Codecov blindly (false positives happen)
- Skip migration reversibility tests
- Push structure.sql with 649-line diffs

---

## Troubleshooting

### Issue: Codecov shows -30% project drop

**Solution**: Almost always a Codecov bug (base commit mismatch)
**Action**: Trust local if 100%, push anyway, Codecov recalculates

---

### Issue: Local and Codecov both show <100%

**Solution**: Coverage actually incomplete
**Action**: Fix coverage (add missing tests)

---

### Issue: Confidence <90%

**Solution**: Don't push, fix failing checks first
**Action**: Investigate and resolve issues

---

## Related Workflows

- **Before debug**: `/orchestrate pre-commit` (fast validation)
- **For coverage**: `/orchestrate coverage` (improve systematically)
- **After push**: Monitor CI, verify Codecov recalculates correctly

---

**Back to**: [orchestrate skill](../SKILL.md) | [quick reference](../quick_reference.md) | [workflows index](README.md)
