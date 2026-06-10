# Orchestrate - Quick Reference

> 🚀 **Start here** for fast access to orchestrate skill patterns

## Core Principles

1. **Maximize Parallelism**: Run independent tasks simultaneously
2. **Fail Fast**: Stop at first critical failure
3. **Quality Gate**: All checks must pass before commit
4. **No Git Operations**: orchestrate CANNOT create commits (use `/commit`)

## Decision Tree

```
User Request → Is it complex?
              ↓
         YES → Use /orchestrate
              ↓
         What type?
              ├─ New feature → /orchestrate feature
              ├─ Bug fix → /orchestrate fix <issue>
              ├─ Migration → /orchestrate migration
              ├─ API change → /orchestrate api
              ├─ Membership → /orchestrate membership
              ├─ Refactor → /orchestrate refactor
              ├─ Security → /orchestrate security-hardening
              ├─ Performance → /orchestrate performance-optimize
              ├─ Coverage → /orchestrate coverage
              ├─ Pre-commit → /orchestrate pre-commit
              └─ Full review → /orchestrate code-review
```

## Common Workflows

### 1. Feature Development (Most Common)
```bash
/orchestrate feature

# Phases:
# 0. Intelligent Analysis (workflow-intelligence + pattern-learning)
# 1A. Static Analysis (timezone, packwerk, security, graphql) - PARALLEL
# 1B. Domain Skills (if applicable) - PARALLEL
# 2. TDD (RED → GREEN → REFACTOR)
# 2.5. Validation (sidekiq, performance, multi-tenancy) - PARALLEL
# 3. Quality (coverage, code-review, pronto) - PARALLEL
# 4. STOP → Tell user to run /commit
```

### 2. Bug Fix
```bash
/orchestrate fix <issue-number>

# Sequential: debug → fix-issue → TDD → quality checks
```

### 3. Pre-Commit Validation (Fast)
```bash
/orchestrate pre-commit

# PARALLEL: tests + coverage + pronto + security
# Time: ~5-10min (only changed files)
```

## Parallel Execution Rules

| Phase | Skills | Why Parallel? |
|-------|--------|---------------|
| 1A | timezone, packwerk, security, graphql | Different domains, no dependencies |
| 1B | memberships, pci-compliance, gateway-consistency | Domain-specific, independent |
| 2.5 | sidekiq, performance, multi-tenancy | Validate implementation details |
| 3 | code-review, coverage, pronto | Independent quality checks |

## Must Run Sequentially

| First | Then | Why |
|-------|------|-----|
| architect | Phase 1A | Must design before analyzing |
| Phase 1A | Phase 1B | Static analysis informs domain checks |
| Phase 1B | TDD | Domain knowledge needed first |
| TDD | Phase 2.5 | Must have code before validating |
| Phase 2.5 | Phase 3 | Validation before quality |
| Phase 3 | STOP | Quality gate, then user commits |

## Context-Aware Selection

orchestrate automatically runs relevant skills based on changes:

| If changes include... | Auto-run... |
|----------------------|-------------|
| `app/graphql/` | graphql |
| `db/migrate/` | migration |
| `app/jobs/` | sidekiq |
| `*membership*` | memberships |
| `*payment*`, `*gateway*` | pci-compliance, gateway-consistency |
| `app/models/`, `app/services/` | multi-tenancy, performance |

## Quality Gate (All Workflows)

Before STOP, verify:
- ✅ Tests passing (0 failures)
- ✅ Coverage 100% on changed lines
- ✅ Pronto clean (no lint violations)
- ✅ Brakeman clean (no security warnings)
- ✅ Domain skills passed

**If ANY fail**: Report, suggest fixes, re-run, DO NOT proceed

**If ALL pass**: Stop and tell user to run `/commit`

## Status Tracking Template

```markdown
## Orchestration: Feature X

### Phase 1A: Static Analysis
| Task | Status | Duration | Notes |
|------|--------|----------|-------|
| timezone | ✅ | 2s | Clean |
| packwerk | ✅ | 3s | Clean |
| security | ✅ | 15s | Clean |

### Phase 2: TDD
| Task | Status | Duration | Notes |
|------|--------|----------|-------|
| write tests | ✅ | 5min | 12 examples |
| implement | ✅ | 10min | Minimal |

### Phase 3: Quality
| Task | Status | Duration | Notes |
|------|--------|----------|-------|
| coverage | ✅ | 30s | 100% |
| review | ✅ | 2min | Clean |
| pronto | ✅ | 5s | Clean |

✅ All checks passed. Ready for commit.
Total Time: 18min 59s
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Running /commit from orchestrate | ❌ orchestrate CANNOT commit. Tell user to run /commit |
| Not using Agent tool for parallel skills | Use Agent tool with multiple parallel invocations |
| Running all validators on small fixes | Use workflow-intelligence to select relevant validators |
| Proceeding after quality gate failure | STOP, report failures, wait for fixes |

## Quick Commands

```bash
# Launch orchestrate skill
/orchestrate <workflow-name>

# Check what workflows are available
/orchestrate --help   # (lists 13 workflows)

# Check skill status
make mcp-status       # See which MCP tools are running
```

## Intelligent Features (Phase 0)

Before starting validation, orchestrate uses MCP tools to optimize:

1. **workflow-intelligence**: Suggests which validators to run based on changes
2. **pattern-learning**: Predicts bugs from git history
3. **quality-metrics**: Analyzes code complexity
4. **dependency-graph**: Suggests which tests to run

**Result**: 36% faster pipelines (27min vs 42min), same quality

## Related Files

- Main documentation: `SKILL.md` (full orchestration guide)
- **Usage Patterns**: `usage_patterns.md` ⭐ **Practical guide** to choosing workflows
- Workflows directory: `workflows/` (detailed workflow docs)
  - [Workflows Index](workflows/README.md) - All 13 workflows indexed
  - [Feature Development](workflows/feature-development.md) - Most common
  - [Bug Fix](workflows/bug-fix.md) - Debug and fix
  - [Pre-Commit](workflows/pre-commit.md) - Fast validation
- Kaizen log: See `SKILL.md` (improvement history)

## Need Help?

- **Detailed workflow**: See `workflows/<workflow-name>.md`
- **Full guide**: See `skill.md`
- **Improve this skill**: Run `/kaizen orchestrate`
- **Report issue**: Create task or ask user

---

**Remember**: orchestrate coordinates, but NEVER commits. Quality checks → STOP → User runs `/commit`
