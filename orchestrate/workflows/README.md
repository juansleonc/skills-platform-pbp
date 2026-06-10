# Orchestrate Workflows Index

> 📋 **Complete guide to all orchestration workflows**

## Workflow Standards

**Creating New Workflows?**
- 📝 Use [_template.md](./_template.md) as starting point
- 🛡️ Reference the "Quality Gate Pattern" section in `orchestrate/SKILL.md` for quality gate
- 🚫 Never embed quality gate - always reference the canonical pattern

## Quick Navigation

| Need to... | Workflow | Time | Complexity |
|------------|----------|------|------------|
| **Quick typo/doc fix** | [simple](simple.md) ⚡ | 1-2min | Very Low |
| **Implement new feature** | [feature-development](feature-development.md) | 27min | High |
| **Fix production bug** | [bug-fix](bug-fix.md) | 20min | Medium |
| **Validate before commit** | [pre-commit](pre-commit.md) | 7min | Low |
| Work on memberships | [membership](membership.md) | 22min | Medium |
| Add database migration | [migration](migration.md) | 17min | Medium |
| Change GraphQL API | [api](api.md) | 22min | Medium |
| Debug production issue | [debug](debug.md) | 20min | Medium |
| Full code review | [code-review](code-review.md) | 35min | High |
| Improve test coverage | [coverage](coverage.md) | Variable | Low |
| Refactor existing code | [refactor](refactor.md) | 47min | Medium |
| Harden security | [security-hardening](security-hardening.md) | 35min | Medium |
| Optimize performance | [performance-optimize](performance-optimize.md) | 37min | High |
| Debug coverage issues | [coverage-debug](coverage-debug.md) | 25min | Medium |

## Workflow Decision Tree

```
What are you doing?
│
├─ Tiny change (typo, doc, comment)
│  └─ Use: simple (1-2min) ⚡
│
├─ New feature/functionality
│  └─ Use: feature-development (most common)
│
├─ Fixing a bug
│  ├─ Production bug with Honeybadger alert
│  │  └─ Use: bug-fix
│  └─ Simple fix (obvious cause, < 50 lines)
│      ├─ Docs/comments only → Use: simple
│      └─ Code change → Use: pre-commit
│
├─ About to commit changes
│  └─ Use: pre-commit (always!)
│
├─ Working on memberships
│  └─ Use: membership workflow
│
├─ Database changes
│  └─ Use: migration workflow
│
├─ GraphQL API changes
│  └─ Use: api workflow
│
├─ Need full code review
│  └─ Use: code-review workflow
│
├─ Improving test coverage
│  └─ Use: coverage workflow
│
├─ Refactoring code
│  └─ Use: refactor workflow
│
├─ Security concerns
│  └─ Use: security-hardening workflow
│
├─ Performance issues
│  └─ Use: performance-optimize workflow
│
└─ CI coverage failing but local passes
   └─ Use: coverage-debug workflow
```

## Workflows by Frequency of Use

### 🔥 Very Frequent (Daily)
0. **simple** ⚡ - Quick fixes (typos, docs, comments) - 1-2min
1. **pre-commit** - Before every commit
2. **feature-development** - Most development work
3. **bug-fix** - Production issues

### ⚡ Frequent (Weekly)
4. **membership** - Membership features (common domain)
5. **migration** - Database changes
6. **api** - GraphQL updates
7. **coverage** - Improve test coverage

### 📊 Occasional (Monthly)
8. **code-review** - Full review before major releases
9. **refactor** - Code quality improvements
10. **performance-optimize** - Performance tuning
11. **security-hardening** - Security audits

### 🔧 Rare (As Needed)
12. **debug** - Complex production debugging
13. **coverage-debug** - CI/local coverage discrepancies

## Extracted Workflows (Detailed Documentation)

### ✅ [Simple Workflow](simple.md) ⚡
**Status**: Extracted ✓
**Command**: `/orchestrate simple`
**Time**: 1-2min avg
**Phases**: Quick Validation (Parallel) → Coverage Check → STOP
**Use for**: Typos, docs, comments, minor fixes (< 50 lines)

**Key Features**:
- Ultra-fast validation (syntax + affected tests + lint)
- Relaxed coverage threshold (≥95%)
- Skip unnecessary checks
- Perfect for trivial changes

---

### ✅ [Feature Development](feature-development.md)
**Status**: Extracted ✓
**Command**: `/orchestrate feature`
**Time**: 27min avg
**Phases**: Intelligence → Analysis → TDD → Quality
**Use for**: New features, major changes

**Key Features**:
- Data-driven validator selection (36% faster)
- MCP intelligence (pattern-learning, workflow-intelligence)
- Parallel execution optimized
- Comprehensive quality gate

---

### ✅ [Bug Fix](bug-fix.md)
**Status**: Extracted ✓
**Command**: `/orchestrate fix <issue-number>`
**Time**: 20min avg
**Phases**: Debug → Analyze → Context → TDD Fix → Quality
**Use for**: Production bugs, Honeybadger alerts

**Key Features**:
- Systematic debugging (Honeybadger + ClickHouse)
- Root cause analysis
- Context-aware domain validation
- TDD-based fix with regression prevention

---

### ✅ [Pre-Commit Validation](pre-commit.md)
**Status**: Extracted ✓
**Command**: `/orchestrate pre-commit`
**Time**: 7min avg
**Phases**: All checks in parallel → Gate
**Use for**: Before every commit

**Key Features**:
- Ultra-fast (delta validation only)
- All checks parallel (6 concurrent)
- Catches 80% of CI failures early
- 50-70% faster than full CI

---

### ✅ [Membership Changes](membership.md)
**Status**: Extracted ✓
**Command**: `/orchestrate membership`
**Time**: 22min avg
**Phases**: Domain Analysis → Technical (parallel) → TDD → Quality
**Use for**: Membership features (weekly, monthly, annual plans)

**Key Features**:
- Business rules validation (auto-renewal, cancellations, prorations)
- Payment idempotency verification
- Sidekiq job pattern validation
- Multi-tenancy enforcement

---

### ✅ [Database Migration](migration.md)
**Status**: Extracted ✓
**Command**: `/orchestrate migration`
**Time**: 17min avg
**Phases**: Safety Check → Impact Analysis (parallel) → TDD (up/down/up)
**Use for**: Schema changes, adding columns/indexes

**Key Features**:
- Data loss prevention
- Rollback safety verification
- Lock duration analysis (ClickHouse)
- Packwerk naming conventions

---

### ✅ [GraphQL API Changes](api.md)
**Status**: Extracted ✓
**Command**: `/orchestrate api`
**Time**: 22min avg
**Phases**: Compatibility Check → Analysis (parallel) → TDD → Quality
**Use for**: GraphQL mutations/queries, API changes

**Key Features**:
- Backward compatibility for 108 mobile mutations
- Breaking change detection
- N+1 prevention (deferred queries)
- Security & multi-tenancy validation

---

### ✅ [Production Debugging](debug.md)
**Status**: Extracted ✓
**Command**: `/orchestrate debug <error-description>`
**Time**: 20min avg
**Phases**: Gather Context (parallel) → Root Cause → Reproduce → Report
**Use for**: Production bugs, Honeybadger alerts, complex debugging

**Key Features**:
- Systematic debugging (Honeybadger + ClickHouse + Code)
- Root cause analysis from multiple sources
- Reproduction script creation
- Debug report with fix recommendations

---

### ✅ [Code Review (Full)](code-review.md)
**Status**: Extracted ✓
**Command**: `/orchestrate code-review`
**Time**: 35min avg
**Phases**: All Analysis (6 skills parallel) → Domain Checks → Deep Review
**Use for**: Pre-release review, major refactors, security audits

**Key Features**:
- 6 static analyzers in parallel
- Context7 documentation validation
- ClickHouse production data checks
- Quality metrics analysis

---

### ✅ [Coverage Improvement](coverage.md)
**Status**: Extracted ✓
**Command**: `/orchestrate coverage`
**Time**: Variable (20-30min per 3 files)
**Phases**: Find Targets → Write Specs (parallel) → Verify → Loop
**Use for**: Autonomous coverage improvement

**Key Features**:
- Autonomous loop (processes until user stops)
- Parallel spec writing (3 files at a time)
- Factory rules validation (mandatory)
- 100% coverage target

---

### ✅ [Refactor](refactor.md)
**Status**: Extracted ✓
**Command**: `/orchestrate refactor`
**Time**: 47min avg
**Phases**: Analysis (parallel) → Plan → TDD Refactor → Quality Gate
**Use for**: Code quality improvements, complexity reduction

**Key Features**:
- Metrics-driven (complexity, maintainability)
- ROI-based prioritization
- TDD-safe refactoring
- Before/after measurements

---

### ✅ [Security Hardening](security-hardening.md)
**Status**: Extracted ✓
**Command**: `/orchestrate security-hardening`
**Time**: 35min avg
**Phases**: Security Analysis (parallel) → ClickHouse Verify → Fix → Verification
**Use for**: Security audits, PCI compliance, vulnerability fixes

**Key Features**:
- Brakeman + PCI + Multi-tenancy
- Production data verification
- TDD-based security fixes
- OWASP Top 10 coverage

---

### ✅ [Performance Optimization](performance-optimize.md)
**Status**: Extracted ✓
**Command**: `/orchestrate performance-optimize`
**Time**: 37min avg
**Phases**: Analysis (parallel) → Bottlenecks → TDD Optimization → Verification
**Use for**: N+1 elimination, slow query fixes, memory optimization

**Key Features**:
- N+1 detection + ClickHouse + Honeybadger
- ROI-based bottleneck prioritization
- Benchmark-driven optimization
- Before/after performance metrics

---

### ✅ [Coverage Debug](coverage-debug.md)
**Status**: Extracted ✓
**Command**: `/orchestrate coverage-debug`
**Time**: 25min avg
**Phases**: Local Verify → Codecov Analyze → Decision Matrix → Exhaustive Validation
**Use for**: CI/local coverage discrepancies, Codecov false positives

**Key Features**:
- Codecov bug detection
- Confidence scoring (>90% to push)
- Exhaustive pre-push validation
- Decision matrix (trust local vs fix)

---

## Extraction Progress

**Completed**: 14/14 (100%) ✅
**Status**: All workflows extracted and documented
**Total Documentation**: ~7,500 lines across 14 workflow files

---

## Usage Tips

### First Time Using Orchestrate?
Start here:
1. Read [Quick Reference](../quick_reference.md) (5min)
2. Try [pre-commit](pre-commit.md) workflow (safest, fastest)
3. When ready for features, read [feature-development](feature-development.md)

### Finding the Right Workflow
1. Check Decision Tree above
2. If unsure, start with feature-development (most comprehensive)
3. For bugs, always use bug-fix (systematic approach)
4. **Always** run pre-commit before `/commit`

### Learning Workflows
- Each workflow doc has: Overview, Phases, Examples, Troubleshooting
- Start with "When to Use" section to verify it's right workflow
- Check "Time Estimates" to plan your work
- Read "Common Pitfalls" to avoid mistakes

### Customizing Workflows
- Workflows are guidelines, not rigid rules
- Skip irrelevant domain checks to save time
- Use MCP intelligence to optimize validator selection
- Break large changes into multiple smaller workflows

---

## Workflow Relationships

```
┌─────────────────────────────────────────────────┐
│                 ORCHESTRATE                      │
│           (Master Coordinator)                   │
├─────────────────────────────────────────────────┤
│                                                  │
│  Development Cycle:                              │
│  feature-development → pre-commit → /commit      │
│                                                  │
│  Bug Fixing:                                     │
│  bug-fix → pre-commit → /commit                  │
│                                                  │
│  Domain Specific:                                │
│  membership → pre-commit → /commit               │
│  migration → pre-commit → /commit                │
│  api → pre-commit → /commit                      │
│                                                  │
│  Quality Improvements:                           │
│  coverage → pre-commit → /commit                 │
│  refactor → pre-commit → /commit                 │
│  performance-optimize → pre-commit → /commit     │
│                                                  │
│  Security:                                       │
│  security-hardening → pre-commit → /commit       │
│                                                  │
│  ⚠️ CRITICAL: orchestrate NEVER calls /commit    │
│     User must run /commit manually               │
│                                                  │
└─────────────────────────────────────────────────┘
```

## Contributing

When adding new workflows:
1. Follow `feature-development.md` template structure
2. Include: Overview, Diagram, Phases, Examples, Troubleshooting
3. Add to this index with decision tree update
4. Update main [orchestrate skill](../SKILL.md) with reference
5. Test workflow end-to-end before documenting

---

**Back to**: [orchestrate skill](../SKILL.md) | [quick reference](../quick_reference.md)
