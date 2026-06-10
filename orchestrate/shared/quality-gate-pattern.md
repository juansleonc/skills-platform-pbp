# Quality Gate Pattern

This is the standard quality gate used by all orchestrate workflows before stopping for user commit.

## Standard Quality Gate

All workflows must pass this quality gate before proceeding to STOP phase:

```
┌─ QUALITY GATE ──────────────────────────────────────┐
│                                                      │
│  REQUIRED CHECKS:                                    │
│  ├── Tests: All specs passing                        │
│  ├── Coverage: 100% on changed lines (patch)         │
│  ├── Coverage: Global % not decreased (project)      │
│  ├── Pronto: No lint violations on changes           │
│  ├── Brakeman: No security warnings                  │
│  └── Domain: Relevant domain skills passed           │
│                                                      │
│  IF ANY FAIL:                                        │
│  1. Report all failures clearly                      │
│  2. Suggest fixes for each                           │
│  3. Wait for fixes                                   │
│  4. Re-run failed checks                             │
│  5. DO NOT proceed to STOP                           │
│                                                      │
│  IF ALL PASS:                                        │
│  1. Output: "✅ All quality checks passed"           │
│  2. Output: "Code ready for commit"                  │
│  3. Output: "Run /commit when ready"                 │
│  4. STOP (do not create commits)                     │
│                                                      │
└──────────────────────────────────────────────────────┘
```

## Implementation Guidelines

### Phase 3: Quality Checks (Parallel)

Run these checks in parallel:

```bash
# 1. Tests (if not already run in Phase 2)
bin/d rspec spec/path/to/changed_specs.rb

# 2. Coverage verification
bin/d rake 'coverage:local:delta'
# Must show: 100% patch coverage

# 3. Lint changed lines only
bin/d pronto run -c develop
# Must show: No violations

# 4. Security scan (if models/services/controllers changed)
bin/d brakeman --only-files app/models/... app/services/...
# Must show: No new warnings
```

### Success Criteria

Quality gate passes when ALL of these are true:

- ✅ All tests pass (0 failures)
- ✅ Coverage: 100% on patch (changed lines)
- ✅ Coverage: Project percentage not decreased
- ✅ Pronto: No lint violations on changed lines
- ✅ Brakeman: No new security warnings
- ✅ Domain skills: All relevant domain checks passed

### Failure Handling

When quality gate fails:

1. **Identify failing check**: "❌ Coverage: 95% (target: 100%)"
2. **Suggest fix**: "Add tests for lines 45-52 in user.rb"
3. **Wait for user to fix**
4. **Re-run ONLY failed check** (not entire gate)
5. **Repeat until all pass**

### After Quality Gate Passes

```
✅ All quality checks passed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Tests:     ✅ 45 examples, 0 failures
Coverage:  ✅ 100% patch (235/235 lines)
Lint:      ✅ No violations
Security:  ✅ No warnings
Domain:    ✅ All checks passed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Code is ready for commit.
Run /commit when you're ready to create the commit.

🚫 orchestrate cannot create commits (CLAUDE.md rules)
```

## Variations by Workflow

Some workflows may have additional checks:

### Migration Workflow
- Additional: Migration reversibility check (up/down/up cycle)

### API Workflow
- Additional: GraphQL backward compatibility check

### Membership Workflow
- Additional: Membership business rules validation

### Security Workflow
- Additional: PCI compliance validation (if payment code)

## Anti-Patterns

**❌ DON'T:**
- Skip quality gate checks
- Proceed to commit without all checks passing
- Create commits from orchestrate (violates CLAUDE.md rule #7)
- Add "Co-Authored-By: Claude" to commits (violates CLAUDE.md rule #8)

**✅ DO:**
- Run all checks in parallel when possible
- Report clear failure messages with suggested fixes
- Stop at quality gate and tell user to run /commit
- Let /commit skill handle git operations

## Related Files

- [Workflows](../workflows/) - All 13 workflows that use this pattern
- [Quick Reference](../quick_reference.md) - Quick guide to orchestrate
- [skill.md](../skill.md) - Main orchestrator documentation
