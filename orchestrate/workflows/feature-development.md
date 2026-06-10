# Feature Development Workflow

> 📖 **Full pipeline workflow for implementing new features with intelligence-driven validation**

## Command

```bash
/orchestrate feature
```

## Overview

The most comprehensive workflow that combines:
- Intelligent analysis (MCP tools predict optimal validation path)
- Static analysis (timezone, security, packwerk, graphql)
- Domain validation (memberships, pci, multi-tenancy)
- TDD implementation
- Quality verification

**Time**: 27min average (vs 42min full validation)
**Savings**: 36% faster due to data-driven validator selection

## Workflow Diagram

```
┌─ PHASE 0.1: MCP Health Check (AUTOMATIC) ───────────┐
│  Test MCP tool availability before workflow         │
│  ✅ workflow-intelligence: Required for optimization │
│  ✅ pattern-learning: Required for bug prediction    │
│  ✅ dependency-graph: Optional (impact analysis)     │
│  ✅ quality-metrics: Optional (complexity scoring)   │
│                                                      │
│  Result: OPTIMIZED (27min) or FALLBACK (42min)      │
│  Time: ~5-10 seconds                                 │
│                                                      │
│  See: ../mcp_health_check.md for details            │
└──────────────────────────────────────────────────────┘
                        ↓
┌─ PHASE 0: Intelligent Analysis (Data-Driven) ───────┐
│  1. dependency-graph: Analyze impact & select tests │
│     mcp__dependency_graph__analyze_impact            │
│       → Calculate direct + indirect dependencies    │
│       → Risk score (0-10) for changed files         │
│       → Validation recommendations                  │
│     mcp__dependency_graph__suggest_tests             │
│       → Suggest which tests to run (balanced)       │
│       → Parallel execution groups                   │
│       → Estimated execution time                    │
│                                                      │
│  2. workflow-intelligence: Optimize pipeline        │
│     mcp__workflow_intelligence__analyze_changes      │
│       → Detect changed areas (payments, graphql)    │
│       → Suggest relevant validators                 │
│       → Dependency resolution                       │
│     mcp__workflow_intelligence__optimize_pipeline    │
│       → Parallel execution plan                     │
│       → Critical path analysis                      │
│       → Time estimates per phase                    │
│                                                      │
│  3. pattern-learning: Predict bugs from history    │
│     mcp__pattern_learning__predict_bugs              │
│       → Historical bug patterns in changed files    │
│       → High-risk files identification              │
│       → Common anti-patterns detected              │
│     mcp__pattern_learning__suggest_refactorings      │
│       → ROI-based refactoring candidates            │
│       → Effort estimates                            │
│       → Priority recommendations                    │
│                                                      │
│  4. quality-metrics: Objective quality analysis     │
│     mcp__quality_metrics__analyze_file               │
│       → Complexity: cyclomatic, cognitive, nesting  │
│       → Maintainability index (0-100)               │
│       → Current quality score                       │
│     mcp__quality_metrics__suggest_improvements       │
│       → Prioritized suggestions with effort         │
│       → Potential quality score after improvements  │
│       → Expected ROI for each improvement           │
└──────────────────────────────────────────────────────┘
                        ↓
┌─ PHASE 0.5: Architecture (Conditional) ─────────────┐
│  IF new feature OR major refactor:                  │
│    architect: Context7 + ClickHouse analysis        │
│      → Where code lives (pack/app)                  │
│      → Patterns to use (Service/Interactor)         │
│      → Schema design                                │
│      → API design (GraphQL mutations)               │
│  ELSE: Skip (small fixes don't need architecture)   │
└─────────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Analysis - Data-Driven Selection) ───────┐
│  Run ONLY validators suggested by workflow-intel:   │
│  ├── timezone (if Time operations detected)         │
│  ├── packwerk (if cross-package changes)            │
│  ├── security (if payment/auth changes)             │
│  ├── graphql (if GraphQL schema changes)            │
│  ├── performance (if queries/associations changed)  │
│  └── multi-tenancy (if facility queries detected)   │
│                                                      │
│  Phase time: ~4-8min (vs ~15min running all)        │
└──────────────────────────────────────────────────────┘
                        ↓
┌─ CONTEXT (Domain Skills - Data-Driven) ─────────────┐
│  Run ONLY if pattern-learning flags risk areas:     │
│  ├── memberships: If membership logic touched       │
│  ├── migration: If schema changes detected          │
│  ├── sidekiq: If job files modified                 │
│  ├── pci-compliance: If payment code changed        │
│  └── gateway-consistency: If multiple gateways      │
└──────────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (TDD) ───────────────────────────────────┐
│  tdd: RED → GREEN → REFACTOR → 100% COVERAGE        │
└──────────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Quality - 3 skills) ──────────────────────┐
│  ├── coverage: Verify 100%                          │
│  ├── code-review: Context7 + ClickHouse             │
│  └── pronto: Lint changed lines only                │
└──────────────────────────────────────────────────────┘
                        ↓
┌─ STOP - Ready for User Commit ───────────────────────┐
│  🚫 orchestrate CANNOT create commits                │
│  ✅ Tell user: "All checks passed"                   │
│  📝 Tell user: "Run /commit when ready"              │
│  ⛔ NEVER proceed to git operations                  │
└──────────────────────────────────────────────────────┘
```

## Example Execution

### Step 0.1: MCP Health Check (automatic)

```
Testing MCP tool availability...

✅ REQUIRED MCPs (4/4 available):
  ✅ workflow-intelligence: Available (2ms)
  ✅ pattern-learning: Available (3ms)
  ✅ dependency-graph: Available (2ms)
  ✅ quality-metrics: Available (4ms)

✅ MCP STATUS: OPTIMIZED
Proceeding with data-driven validator selection.
Estimated time: 27min (36% faster)
```

### Step 1: Analyze Changes (workflow-intelligence)

```json
{
  "changed_areas": {
    "payments": 3,
    "multi-tenancy": 1
  },
  "suggested_validators": [
    "security",
    "pci-compliance",
    "multi-tenancy",
    "performance"
  ],
  "parallel_phases": [
    ["security", "multi-tenancy"],     // Phase 1: 4min
    ["performance", "pci-compliance"]  // Phase 2: 5min
  ],
  "estimated_duration": "9 minutes",
  "confidence": 0.92
}
```

### Step 2: Predict Bugs (pattern-learning)

```json
{
  "high_risk_files": [
    {
      "file": "app/services/payment_service.rb",
      "risk_score": 8.5,
      "reasons": [
        "Complex logic (15 branches)",
        "Payment-critical",
        "3 bugs in last 6 months"
      ]
    }
  ],
  "suggested_validations": [
    "Add edge case tests for nil payment_method",
    "Test idempotency with concurrent requests"
  ]
}
```

### Step 3: Execute Optimal Plan

Result: **9min** (vs 42min full pipeline)
Savings: **36% faster**, same quality coverage

Only runs validators suggested by workflow-intelligence:
- security (4min)
- multi-tenancy (4min)
- performance (5min)
- pci-compliance (5min)

Skips unnecessary validators:
- ~~timezone~~ (no Time operations)
- ~~packwerk~~ (no cross-package changes)
- ~~graphql~~ (no API changes)

## When to Use

✅ **Use this workflow when**:
- Implementing new features
- Adding new endpoints/APIs
- Major code changes (>100 lines)
- Touching critical paths (payments, auth, multi-tenancy)
- Unsure which validators to run

❌ **Don't use for**:
- Typo fixes (use `/orchestrate pre-commit`)
- Documentation updates
- Config-only changes
- Simple bug fixes (use `/orchestrate fix`)

## Success Criteria

All of these must pass:
- ✅ Tests: 0 failures
- ✅ Coverage: 100% on changed lines
- ✅ Pronto: Clean (no lint violations)
- ✅ Brakeman: No security warnings
- ✅ Domain validators: All passed (if applicable)

If ANY fail:
1. Report all failures
2. Suggest fixes
3. Wait for user to fix
4. Re-run failed checks
5. DO NOT proceed to STOP

## Time Estimates

| Phase | Duration | Notes |
|-------|----------|-------|
| Phase 0 | 1-2min | MCP intelligent analysis |
| Phase 0.5 | 5-10min | Only if new feature (architect) |
| Phase 1A | 4-8min | Parallel static analysis |
| Phase 1B | 3-5min | Parallel domain validation |
| Phase 2 | 10-20min | TDD implementation |
| Phase 2.5 | 2-4min | Parallel code validation |
| Phase 3 | 3-5min | Parallel quality checks |
| **Total** | **27-42min** | Avg 27min with intelligence |

## Output Format

```markdown
## Orchestration: Feature X

### Phase 0.1: MCP Health Check
✅ workflow-intelligence: Available
✅ pattern-learning: Available
✅ dependency-graph: Available
✅ quality-metrics: Available
→ MCP STATUS: OPTIMIZED (27min estimated)

### Phase 0: Intelligent Analysis
✅ workflow-intelligence: Suggested 4 validators (9min estimated)
✅ pattern-learning: Identified 1 high-risk file
✅ quality-metrics: Current score 68/100

### Phase 1A: Static Analysis (Parallel)
✅ security: 15s - Clean
✅ multi-tenancy: 3s - Clean
⏭️ timezone: Skipped (no Time operations)

### Phase 1B: Domain (Parallel)
✅ pci-compliance: 5s - Clean
✅ performance: 10s - Clean

### Phase 2: TDD
✅ write tests: 8min - 15 examples
✅ implement: 12min - Minimal code
✅ refactor: 3min - Extract service

### Phase 3: Quality (Parallel)
✅ coverage: 30s - 100%
✅ code-review: 2min - No issues
✅ pronto: 5s - Clean

✅ All checks passed. Code ready for commit.
📝 Run /commit when ready
Total Time: 26min 48s (36% faster than full validation)
```

## Related Workflows

- **Simpler**: `/orchestrate pre-commit` (fast validation only)
- **Debugging**: `/orchestrate debug` (production issue investigation)
- **Refactoring**: `/orchestrate refactor` (improve existing code)

## Troubleshooting

### Issue: MCP tools not available
**Solution**: Falls back to full validator suite (42min)

### Issue: workflow-intelligence suggests wrong validators
**Solution**: Override with manual validator selection in orchestrate skill

### Issue: Phase 0 takes too long (>5min)
**Solution**: Skip intelligence, run full suite (less optimal but still works)

---

**Back to**: [orchestrate skill](../skill.md) | [quick reference](../quick_reference.md)
