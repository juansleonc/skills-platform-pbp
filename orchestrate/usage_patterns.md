# Orchestrate Usage Patterns

> 📖 **Practical guide to choosing and using orchestrate workflows**

## Quick Decision Guide

```
What do you need to do?
│
├─ 🆕 New feature or functionality
│  └─ Use: /orchestrate feature (comprehensive pipeline)
│
├─ 🐛 Fix a bug
│  ├─ Production bug with error tracking
│  │  └─ Use: /orchestrate fix <issue-number>
│  └─ Simple local bug
│      └─ Fix directly + /orchestrate pre-commit
│
├─ 📋 About to commit changes
│  └─ Use: /orchestrate pre-commit (ALWAYS before committing)
│
├─ 💳 Working on memberships
│  └─ Use: /orchestrate membership
│
├─ 🗄️ Database changes
│  └─ Use: /orchestrate migration
│
├─ 🌐 GraphQL API changes
│  └─ Use: /orchestrate api
│
├─ 🔍 Production debugging
│  └─ Use: /orchestrate debug <error-description>
│
├─ 📊 Need full code review
│  └─ Use: /orchestrate code-review
│
├─ 🧪 Improving test coverage
│  └─ Use: /orchestrate coverage
│
├─ 🔄 Refactoring code
│  └─ Use: /orchestrate refactor
│
├─ 🔒 Security concerns
│  └─ Use: /orchestrate security-hardening
│
├─ ⚡ Performance issues
│  └─ Use: /orchestrate performance-optimize
│
└─ 🧮 CI coverage failing but local passes
   └─ Use: /orchestrate coverage-debug
```

## Common Workflows by Scenario

### Daily Development (Most Frequent)

#### 1. Starting a New Feature
```bash
# Full feature development pipeline
/orchestrate feature

# What it does:
# - Architect: Design approach (if new feature)
# - Analysis: timezone, packwerk, security, graphql (parallel)
# - Domain checks: membership, migration, pci (if applicable)
# - TDD: Write tests → implement → refactor
# - Quality: coverage, code-review, pronto (parallel)
# - Ready for commit (tells you to run /commit)

# Time: 25-30min
# When: Starting new functionality, major changes
```

#### 2. Before Every Commit
```bash
# Fast validation before committing
/orchestrate pre-commit

# What it does:
# - Tests: Run changed specs
# - Coverage: Verify 100% delta
# - Lint: Pronto on modified files
# - Quick checks: timezone, security, graphql (if applicable)

# Time: 5-10min
# When: ALWAYS before running /commit
```

#### 3. Fixing Production Bugs
```bash
# Systematic bug investigation + fix
/orchestrate fix <issue-number>

# What it does:
# - Debug: Honeybadger + ClickHouse analysis
# - Root cause: Identify source of issue
# - Context: Domain validation (membership, graphql, sidekiq)
# - TDD fix: Write failing test → fix → verify
# - Quality: coverage, code-review, pronto

# Time: 20-30min
# When: Production bugs, Honeybadger alerts, GitHub issues
```

### Weekly Workflows

#### 4. Membership Changes
```bash
# Membership-specific workflow
/orchestrate membership

# What it does:
# - Domain analysis: Business rules validation
# - Technical checks: sidekiq, performance, multi-tenancy (parallel)
# - TDD: Test all membership types (weekly/monthly/annual)
# - Quality: coverage, code-review

# Time: 20-25min
# When: Changes to memberships, payments, renewals, cancellations
```

#### 5. Database Migrations
```bash
# Migration safety workflow
/orchestrate migration

# What it does:
# - Safety check: Validate rollback, indexes, data loss prevention
# - Impact analysis: performance, packwerk, ClickHouse (parallel)
# - TDD: Test migration up/down

# Time: 15-20min
# When: Adding columns, indexes, tables, schema changes
```

#### 6. GraphQL API Changes
```bash
# API compatibility workflow
/orchestrate api

# What it does:
# - Compatibility: Check backward compatibility (108 mobile mutations)
# - Analysis: performance, security, multi-tenancy (parallel)
# - TDD: Request specs for mutations/queries
# - Quality: coverage, code-review

# Time: 20-25min
# When: GraphQL schema changes, new mutations/queries
```

### Monthly/As-Needed Workflows

#### 7. Production Debugging
```bash
# Deep production investigation
/orchestrate debug <error-description>

# What it does:
# - Gather context: Honeybadger + ClickHouse + code search (parallel)
# - Root cause: Analyze patterns across data sources
# - Reproduce: Create reproduction script
# - Report: Debug report with fix recommendations

# Time: 15-30min
# When: Complex production issues, investigating patterns
```

#### 8. Comprehensive Code Review
```bash
# Full static analysis + deep review
/orchestrate code-review

# What it does:
# - All analysis: timezone, packwerk, security, graphql, performance, multi-tenancy (parallel)
# - Domain checks: membership, migration, sidekiq (if applicable)
# - Deep review: Context7 + ClickHouse + quality metrics

# Time: 30-40min
# When: Pre-release review, major refactors, security audits
```

#### 9. Coverage Improvement
```bash
# Autonomous coverage improvement loop
/orchestrate coverage

# What it does:
# - Find targets: Identify uncovered files
# - Write specs: Process 3 files at a time (parallel)
# - Verify: Check 100% coverage
# - Loop: Continue until user stops

# Time: 20-30min per 3 files
# When: Improving codebase coverage, autonomous testing
```

#### 10. Code Refactoring
```bash
# Systematic refactoring workflow
/orchestrate refactor

# What it does:
# - Analysis: code-review, performance, multi-tenancy (parallel)
# - Plan: architect designs refactoring approach
# - TDD refactor: Add tests → refactor → verify green
# - Quality gate: coverage, performance, pronto

# Time: 40-50min
# When: Code quality improvements, complexity reduction
```

#### 11. Security Hardening
```bash
# Comprehensive security audit
/orchestrate security-hardening

# What it does:
# - Security analysis: Brakeman, PCI, multi-tenancy (parallel)
# - ClickHouse verify: Check production data for leaks
# - Fix issues: TDD-based security fixes
# - Verification: Re-run all security checks

# Time: 25-35min
# When: Security audits, PCI compliance, vulnerability fixes
```

#### 12. Performance Optimization
```bash
# Systematic performance improvement
/orchestrate performance-optimize

# What it does:
# - Analysis: N+1 detection, ClickHouse, Honeybadger (parallel)
# - Bottlenecks: Prioritize by ROI (Impact/Effort)
# - TDD optimization: Benchmark → optimize → verify
# - Verification: Re-check performance improvements

# Time: 30-40min
# When: N+1 elimination, slow query fixes, memory optimization
```

#### 13. Coverage Debugging
```bash
# Resolve CI/local coverage discrepancies
/orchestrate coverage-debug

# What it does:
# - Local verify: Run specs, SimpleCov, line-by-line check
# - Codecov analyze: Identify discrepancies, detect false positives
# - Decision matrix: Trust local vs fix coverage
# - Exhaustive validation: All checks (tests, coverage, lint, security)
# - Confidence report: 90%+ required to push

# Time: 20-30min
# When: CI coverage fails but local passes, Codecov false positives
```

## Workflow Combinations

### Full Feature Development (Start to Finish)
```bash
/orchestrate feature    # Development pipeline (25-30min)
# ... make changes ...
/orchestrate pre-commit # Pre-commit validation (5-10min)
/commit                 # User creates commit (manual)
/create-pr              # User creates PR (manual)
/orchestrate code-review # Final PR review (30-40min)
```

### Bug Fix Flow
```bash
/orchestrate fix 123     # Investigate + fix (20-30min)
/orchestrate pre-commit  # Validate before commit (5-10min)
/commit                  # User creates commit (manual)
```

### Coverage Improvement Sprint
```bash
/orchestrate coverage    # Autonomous loop (20-30min/batch)
# ... continues processing files ...
# User stops when satisfied
/orchestrate pre-commit  # Final validation (5-10min)
/commit                  # User creates commit (manual)
```

## Time Management

### Expected Times by Workflow

| Workflow | Minimum | Average | Maximum | Parallelization |
|----------|---------|---------|---------|-----------------|
| feature | 20min | 27min | 35min | High (4-6 parallel tasks) |
| pre-commit | 5min | 7min | 10min | Very High (all parallel) |
| fix | 15min | 20min | 30min | Medium (2-3 parallel tasks) |
| membership | 18min | 22min | 28min | Medium (3-4 parallel tasks) |
| migration | 12min | 17min | 25min | Medium (2-3 parallel tasks) |
| api | 18min | 22min | 30min | Medium (3-4 parallel tasks) |
| debug | 10min | 20min | 40min | High (3-4 parallel tasks) |
| code-review | 25min | 35min | 50min | Very High (6+ parallel tasks) |
| coverage | 15min | 25min | 40min | High (3 files at a time) |
| refactor | 35min | 47min | 60min | Medium (2-3 parallel tasks) |
| security-hardening | 20min | 35min | 50min | High (3+ parallel tasks) |
| performance-optimize | 25min | 37min | 50min | Medium (2-3 parallel tasks) |
| coverage-debug | 15min | 25min | 40min | Medium (2-3 parallel tasks) |

### Time Optimization Tips

1. **Use pre-commit frequently**: Catches 80% of issues in 7min vs 27min full pipeline
2. **Run workflows in background**: Start workflow, continue coding, check back later
3. **Parallel execution**: Workflows automatically parallelize independent tasks
4. **Skip unnecessary checks**: Domain-specific workflows only run relevant validators

## Common Mistakes to Avoid

### ❌ Don't Do This

1. **Skipping pre-commit before /commit**
   ```bash
   # ❌ BAD: Commit without validation
   /commit

   # ✅ GOOD: Always validate first
   /orchestrate pre-commit
   /commit
   ```

2. **Using wrong workflow for task**
   ```bash
   # ❌ BAD: Using feature workflow for bug fix
   /orchestrate feature  # When you should use fix

   # ✅ GOOD: Use specialized workflow
   /orchestrate fix 123
   ```

3. **Ignoring workflow recommendations**
   ```bash
   # ❌ BAD: Ignoring security issues flagged by workflow
   # (fixing later, skipping checks)

   # ✅ GOOD: Fix issues before proceeding
   # Workflows block on critical failures
   ```

4. **Running full workflow for small changes**
   ```bash
   # ❌ BAD: Full feature workflow for typo fix
   /orchestrate feature  # 27min for 1-line change

   # ✅ GOOD: Just pre-commit for small fixes
   /orchestrate pre-commit  # 7min
   /commit
   ```

5. **Not reading workflow output**
   ```bash
   # ❌ BAD: Skipping to commit without checking results

   # ✅ GOOD: Review workflow findings
   # Each phase shows what it found, fix issues before proceeding
   ```

## Best Practices

### ✅ Do This

1. **Start with architecture for new features**
   ```bash
   # Let architect design approach first
   /orchestrate feature
   # Architecture phase runs automatically for new features
   ```

2. **Use domain-specific workflows**
   ```bash
   # When working on memberships
   /orchestrate membership  # 22min with membership validation

   # vs generic
   /orchestrate feature     # 27min without membership expertise
   ```

3. **Combine workflows strategically**
   ```bash
   # After major refactor
   /orchestrate refactor            # Refactoring workflow
   /orchestrate security-hardening   # Security audit
   /orchestrate performance-optimize # Performance check
   /orchestrate pre-commit          # Final validation
   ```

4. **Use coverage workflow autonomously**
   ```bash
   # Let it run in background while you do other work
   /orchestrate coverage
   # Processes files continuously until you stop
   ```

5. **Debug before fixing**
   ```bash
   # For complex production issues
   /orchestrate debug <description>  # Understand first
   # ... review debug report ...
   /orchestrate fix <issue-number>   # Then fix
   ```

## Workflow Selection Matrix

| If you need to... | And... | Use... | Time |
|-------------------|--------|--------|------|
| Add new feature | It's substantial | `/orchestrate feature` | 27min |
| Add new feature | It's tiny (<10 lines) | Make change + `/orchestrate pre-commit` | 7min |
| Fix bug | Production error | `/orchestrate fix` | 20min |
| Fix bug | Local bug, obvious cause | Fix + `/orchestrate pre-commit` | 7min |
| Commit changes | Any changes | `/orchestrate pre-commit` (ALWAYS) | 7min |
| Work on memberships | Any membership code | `/orchestrate membership` | 22min |
| Change database | Any schema change | `/orchestrate migration` | 17min |
| Change GraphQL | Any API change | `/orchestrate api` | 22min |
| Debug production | Complex issue | `/orchestrate debug` | 20min |
| Code review | Before release | `/orchestrate code-review` | 35min |
| Improve coverage | Multiple files | `/orchestrate coverage` | 25min/batch |
| Refactor code | Reduce complexity | `/orchestrate refactor` | 47min |
| Security audit | Before release | `/orchestrate security-hardening` | 35min |
| Fix performance | Slow queries, N+1 | `/orchestrate performance-optimize` | 37min |
| CI coverage fails | Local passes | `/orchestrate coverage-debug` | 25min |

## Success Indicators

### How to Know It Worked

**All workflows end with clear status:**

✅ **Success Output:**
```markdown
## Orchestration Complete ✅

All checks passed:
- Tests: 206 examples, 0 failures
- Coverage: 100% patch (45/45 lines)
- Lint: Clean
- Security: No vulnerabilities
- Domain: All rules validated

✅ Ready for commit
📝 Run /commit when ready
```

⚠️ **Issues Found:**
```markdown
## Issues Found ⚠️

Phase 2: TDD
- Tests failing: 3 examples
- Fix: spec/models/user_spec.rb:45

Phase 3: Quality
- Coverage: 85% (need 100%)
- Missing: app/services/payment_service.rb:78-82

🔴 NOT ready for commit
Fix issues above and re-run workflow
```

## Emergency Patterns

### When Things Go Wrong

**Workflow taking too long:**
```bash
# Stop current workflow (Ctrl+C)
# Use faster alternative:
/orchestrate pre-commit  # Much faster for quick checks
```

**CI failing but can't figure out why:**
```bash
# Use coverage-debug workflow
/orchestrate coverage-debug
# Provides exhaustive validation + confidence scoring
```

**Production down:**
```bash
# Skip orchestrate, fix directly
# Make hotfix
/orchestrate pre-commit  # Quick validation only
/commit
# Deploy immediately
```

## Learning Path

### For New Users

1. **Week 1: Learn pre-commit**
   ```bash
   /orchestrate pre-commit  # Before every commit
   # Get comfortable with 7min validation
   ```

2. **Week 2: Try feature workflow**
   ```bash
   /orchestrate feature     # For next feature
   # See full pipeline in action
   ```

3. **Week 3: Explore domain workflows**
   ```bash
   /orchestrate membership  # If working on memberships
   /orchestrate api         # If working on GraphQL
   # Learn specialized workflows
   ```

4. **Week 4: Advanced workflows**
   ```bash
   /orchestrate refactor            # Code improvement
   /orchestrate performance-optimize # Speed optimization
   /orchestrate coverage            # Autonomous testing
   ```

### For Experienced Users

**Optimize your workflow:**

1. Identify most common tasks (feature, pre-commit, fix)
2. Learn keyboard shortcuts / aliases for these
3. Combine workflows for complex changes
4. Use background execution for long-running workflows
5. Trust the quality gate - it catches real issues

## Measuring Impact

### Metrics to Track

**Before orchestrate:**
- CI failures: ~30% of PRs
- Time to merge: 2-3 days (waiting for fixes)
- Production bugs: 2-3/month

**After orchestrate:**
- CI failures: ~5% of PRs (mostly Codecov false positives)
- Time to merge: Same day (issues caught pre-commit)
- Production bugs: 0-1/month

### ROI Calculation

**Time investment:**
- Pre-commit: 7min/commit × 50 commits/month = 350min/month
- Feature workflows: 27min × 10 features/month = 270min/month
- Total: ~620min/month = 10.3 hours/month

**Time savings:**
- CI wait time eliminated: 15min/failure × 15 failures/month = 225min saved
- Production bugs: 2 bugs/month × 4 hours/bug = 480min saved
- Code review time: Automated checks save 30min/PR × 50 PRs = 1500min saved
- Total: ~2205min/month = 36.75 hours/month

**Net savings: 26.45 hours/month** (3.5× ROI)

**Quality improvements:**
- Fewer production bugs (85% reduction)
- Better code quality (automated analysis)
- Faster feedback loop (pre-commit vs CI)
- Consistent validation (no skipped checks)

---

## Quick Reference Card

```
Daily:
  /orchestrate pre-commit    # Before every commit (7min)

Weekly:
  /orchestrate feature       # New features (27min)
  /orchestrate fix <issue>   # Bug fixes (20min)
  /orchestrate membership    # Membership code (22min)
  /orchestrate api           # GraphQL changes (22min)
  /orchestrate migration     # DB changes (17min)

Monthly:
  /orchestrate code-review           # Full review (35min)
  /orchestrate coverage              # Improve tests (25min/batch)
  /orchestrate refactor              # Code quality (47min)
  /orchestrate security-hardening    # Security audit (35min)
  /orchestrate performance-optimize  # Speed up code (37min)

As Needed:
  /orchestrate debug <desc>      # Production issues (20min)
  /orchestrate coverage-debug    # CI coverage bugs (25min)

Golden Rule:
  ALWAYS run /orchestrate pre-commit before /commit
  orchestrate workflows STOP before git operations
  User must run /commit manually
```

---

**Back to**: [orchestrate skill](SKILL.md) | [workflows index](workflows/README.md)
