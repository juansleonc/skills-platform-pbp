# [Workflow Name] Workflow

> 📖 **[One-line description of what this workflow does]**

## Command

```bash
/orchestrate [workflow-name]
```

## Overview

[2-3 sentences describing the workflow]

**Use this workflow when:**
- [Condition 1]
- [Condition 2]
- [Condition 3]

**Time**: [X]min average
**Key benefit**: [Main advantage]

## Workflow Diagram

```
┌─ PHASE 0: [Phase Name] ──────────────────────────┐
│  [Description of what happens in this phase]     │
│  ├── [Tool/Skill 1]: [What it does]              │
│  ├── [Tool/Skill 2]: [What it does]              │
│  └── [Tool/Skill 3]: [What it does]              │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PHASE 1: [Phase Name] ──────────────────────────┐
│  [PARALLEL/SEQUENTIAL]                            │
│  ├── [Skill 1]: [What it validates]              │
│  ├── [Skill 2]: [What it validates]              │
│  └── [Skill 3]: [What it validates]              │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PHASE 2: [Phase Name] ──────────────────────────┐
│  [Description]                                    │
│  [Implementation details]                         │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PHASE 3: Quality Gate ───────────────────────────┐
│  See: orchestrate/SKILL.md → Quality Gate Pattern │
│                                                   │
│  ✅ Tests passing                                 │
│  ✅ Coverage 100% patch                           │
│  ✅ Lint clean                                    │
│  ✅ Security clean                                │
│  ✅ Domain checks passed                          │
└───────────────────────────────────────────────────┘
                        ↓
┌─ STOP - Ready for User Commit ────────────────────┐
│  🚫 orchestrate CANNOT create commits             │
│  ✅ Tell user: "All checks passed"                │
│  📝 Tell user: "Run /commit when ready"           │
│  ⛔ NEVER proceed to git operations               │
└───────────────────────────────────────────────────┘
```

## When to Use This Workflow

Use `/orchestrate [workflow-name]` when:

1. **[Primary use case]**
   - Example: [Specific scenario]
   - Result: [Expected outcome]

2. **[Secondary use case]**
   - Example: [Specific scenario]
   - Result: [Expected outcome]

3. **[Additional use case]**
   - Example: [Specific scenario]
   - Result: [Expected outcome]

**Don't use this workflow when:**
- [Condition where different workflow is better]
- [Condition where manual approach is better]

## Success Criteria

This workflow succeeds when:

- ✅ [Criterion 1]: [Measurable outcome]
- ✅ [Criterion 2]: [Measurable outcome]
- ✅ [Criterion 3]: [Measurable outcome]
- ✅ Quality Gate: All checks passed (see "Quality Gate Pattern" section in `orchestrate/SKILL.md`)
- ✅ Output: Clear summary of what was done

## Example Execution

```
User: /orchestrate [workflow-name]

Claude:
## [Workflow Name]

### Phase 0: [Phase Name]
[Running analysis...]
✓ [Result 1]
✓ [Result 2]

### Phase 1: [Phase Name] (Parallel)
Launching 3 parallel tasks...

[Task 1: skill-name] [Result]
[Task 2: skill-name] [Result]
[Task 3: skill-name] [Result]

Results:
✓ [Summary of phase 1]

### Phase 2: [Phase Name]
[Sequential work...]
✓ [Result]

### Phase 3: Quality Gate
Running quality checks in parallel...

[Task 1: coverage] ✓ 100% (45/45 lines)
[Task 2: pronto] ✓ Clean
[Task 3: brakeman] ✓ No warnings

Results:
✓ All quality checks passed

## ✅ Workflow Complete

All checks passed. Code ready for commit.
Run /commit when you're ready to create the commit.
```

## Phase Details

### Phase 0: [Phase Name]

**Purpose**: [What this phase achieves]

**Skills/Tools**:
- `[skill-name]`: [What it does]
- `[skill-name]`: [What it does]

**Success Criteria**:
- [Measurable outcome]
- [Measurable outcome]

**Time**: ~[X]min

---

### Phase 1: [Phase Name]

**Purpose**: [What this phase achieves]

**Execution**: PARALLEL (all tasks run simultaneously)

**Skills**:
- `[skill-name]`: [What it validates]
- `[skill-name]`: [What it validates]
- `[skill-name]`: [What it validates]

**Success Criteria**:
- [Measurable outcome for each skill]

**Time**: ~[X]min

---

### Phase 2: [Phase Name]

**Purpose**: [What this phase achieves]

**Execution**: SEQUENTIAL (must complete before Phase 3)

**Implementation**:
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Success Criteria**:
- [Measurable outcome]

**Time**: ~[X]min

---

### Phase 3: Quality Gate

**Purpose**: Verify all quality standards before stopping

**See**: "Quality Gate Pattern" section in `orchestrate/SKILL.md` for full details

**Required Checks**:
- Tests: All passing
- Coverage: 100% patch
- Lint: No violations
- Security: No warnings
- Domain: All relevant checks passed

**Time**: ~[X]min

**After Pass**: Stop and tell user to run /commit

---

## Troubleshooting

### [Common Issue 1]

**Problem**: [Description]

**Symptoms**:
- [Symptom 1]
- [Symptom 2]

**Solution**:
```bash
[Command to fix]
```

---

### [Common Issue 2]

**Problem**: [Description]

**Solution**:
- [Step 1]
- [Step 2]

---

## Metrics

| Metric | Target | Typical |
|--------|--------|---------|
| Total time | [X]min | [Y]min |
| Phase 0 | [X]min | [Y]min |
| Phase 1 | [X]min | [Y]min |
| Phase 2 | [X]min | [Y]min |
| Phase 3 | [X]min | [Y]min |

## Related Workflows

- [Other Workflow 1](./other-workflow.md) - Use when [condition]
- [Other Workflow 2](./other-workflow.md) - Use when [condition]

## Related Skills

- `/[skill-name]` - [What it does]
- `/[skill-name]` - [What it does]

---

**Back to**: [Workflows Index](./README.md) | [Quick Reference](../quick_reference.md) | [Main Skill](../skill.md)
