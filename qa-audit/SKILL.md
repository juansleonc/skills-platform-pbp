---
name: qa-audit
description: Run weekly, after adding/removing/renaming a skill, or after major CLAUDE.md updates to keep all skill files aligned with project conventions.
allowed-tools: [Bash, Read, Grep, Glob, Edit]
disable-model-invocation: true
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions. Skills should prioritize `CLAUDE.local.md` when there are discrepancies.

# QA Audit Skill - Kaizen Quality Gate

Continuous improvement audit for all Claude Code skills. Validates alignment with project requirements and identifies opportunities for enhancement.

## CRITICAL RULE

**NEVER modify `CLAUDE.md`** - it is a shared, versioned file.

When discrepancies are found between `CLAUDE.md` and reality:
1. **Report** the discrepancy in the audit
2. **DO NOT auto-fix** CLAUDE.md
3. **Skills can be updated** to match current project state
4. **Notify user** to update CLAUDE.md manually if needed

The `packwerk/SKILL.md` should be the source of truth for package information since it can be updated by skills.

## Philosophy

> "Every day we must improve" - Kaizen

This skill ensures all other skills remain aligned with:
- CLAUDE.md critical rules
- Project conventions
- Best practices
- Documentation accuracy

## Audit Process

### Step 1: Enumerate Skills

```bash
# List all installed skills.
# NOTE: the canonical skill filename is UPPERCASE `SKILL.md` (convention is consistent:
# run `find .claude/skills -iname 'skill.md' | wc -l` for the live count; there are 0 lowercase `skill.md` files).
# Using `-iname` is fine for portability (Linux CI) but is NOT needed to handle mixed casing —
# mixed casing was fixed; the flag is kept as a defensive cross-platform measure only.
find .claude/skills -maxdepth 2 -iname "skill.md"

# Count skills (dynamic — do not hardcode the number)
find .claude/skills -iname "skill.md" | wc -l
```

### Step 2: Read CLAUDE.md for Current Requirements

```bash
# Get critical rules section
grep -A 20 "## Critical Rules" CLAUDE.md

# Get tech stack
grep -A 30 "## Tech Stack" CLAUDE.md

# Get package count
ls -la packs/
```

### Step 3: Validate Each Skill

For each skill, verify:

| Check | How | Pass Criteria |
|-------|-----|---------------|
| Docker execution | Grep for raw `bundle exec` | No raw commands outside docker |
| Pronto vs RuboCop | Check linting section | Modified=Pronto, New=RuboCop |
| Factory rules | Check test patterns | build > build_stubbed > create |
| Forbidden patterns | Check for violations | None present |
| Package count | Check packwerk skill | Matches `ls -d packs/*/ \| wc -l` (dynamic — do not hardcode) |
| Coverage requirement | Check for 100% | Explicitly stated |
| Time safety | Check for Time.now | Only Time.current |
| Claude mentions | Check commits/PRs | No AI references |
| Frontmatter description | Read `description:` line | states triggers only (no workflow summary) — CSO Rule: `description:` must say WHEN to invoke, never summarize the skill's steps (defined in `skill-creator/SKILL.md`) |

### Step 4: Cross-Reference Validation

```bash
# Check for Claude/AI mentions (FORBIDDEN)
grep -rn "Claude\|Anthropic\|Co-Authored-By" .claude/skills/ --include="*.md"

# Check for Time.now in examples (FORBIDDEN)
grep -rn "Time\.now" .claude/skills/ --include="*.md" | grep -v "# BAD\|# WRONG\|❌"

# Check for raw bundle exec without docker
grep -rn "bundle exec" .claude/skills/ --include="*.md" | grep -v "docker compose exec\|make test"

# Verify 100% coverage is mandatory
# Use the skillfile() resolver (defined in the automated script below) for case-safe lookup.
# During a manual audit run these directly:
grep -rn "100%" "$(find .claude/skills/coverage -maxdepth 1 -iname 'skill.md' | head -1)"
grep -rn "100%" "$(find .claude/skills/tdd      -maxdepth 1 -iname 'skill.md' | head -1)"
```

### Step 5: Validate Against CLAUDE.md

| CLAUDE.md Rule | Skill That Should Enforce | Verified |
|----------------|---------------------------|----------|
| Timezone Safety | timezone, code-review, tdd | |
| Multi-tenancy | code-review | |
| Financial Transactions | code-review, gateway-test | |
| API Compatibility | code-review | |
| Payment Idempotency | gateway-test, code-review | |
| Docker Commands | docker-exec (global) | |
| No AI Mentions | commit, create-pr, fix-issue | |

> **Overlap note**: `/rails-audit` covers a similar pre-release checklist (security, perf, DB, timezone). This skill audits the *skill files themselves*; `/rails-audit` audits *application code*. They are complementary, not duplicates — run `/rails-audit` on the codebase, `/qa-audit` on the skills directory.

### Step 6: Documentation Accuracy

Verify skills match actual project state:

```bash
# Package count — report live count; packwerk/SKILL.md no longer embeds a declared count
# (its inventory moved to reference/packs.md, which also defers to the filesystem).
# Cross-check: the number below should match the pack table in reference/packs.md.
ls -d packs/*/ | wc -l

# Verify Makefile targets exist
grep -E "^(test|console|migrate|web-bash):" Makefile

# Verify rake tasks exist
bin/d rake -T coverage
```

## Audit Report Format

```markdown
## Skills QA Audit - [Date]

### Summary
- Skills audited: X
- Issues found: Y
- Improvements suggested: Z

### Critical Issues (BLOCKING)

| Skill | Issue | Severity | Fix Required |
|-------|-------|----------|--------------|
| commit | Contains "Co-Authored-By: Claude" | CRITICAL | Remove AI mention |

### Inconsistencies

| Skill | Finding | Impact |
|-------|---------|--------|
| packwerk | Lists 11 packages, reality is 10 | Medium |

### Missing Coverage

| CLAUDE.md Rule | Not Covered By Any Skill |
|----------------|--------------------------|
| GraphQL deferred queries | No dedicated check |

### Improvement Opportunities

| Skill | Suggestion | Priority |
|-------|------------|----------|
| code-review | Add Honeybadger integration | Medium |
| tdd | Add system test section | High |

### Actions Taken
- [ ] Fixed: ...
- [ ] Updated: ...
- [ ] Created: ...

### Next Audit
Schedule: Weekly or after major changes
```

## Automated Checks

Run the audit script from the project root:

```bash
bash .claude/skills/qa-audit/qa_audit.sh
```

> Full check logic (AI-mention scan, Docker-usage lint, package-count accuracy, coverage requirement, forbidden-pattern docs) lives in [`qa_audit.sh`](qa_audit.sh). Edit that file to add or change checks.

## Kaizen Improvement Cycle

```
┌─────────────────────────────────────────────────────────┐
│  1. AUDIT: Run QA checks on all skills                  │
│            ↓                                            │
│  2. IDENTIFY: Find gaps, inconsistencies, violations    │
│            ↓                                            │
│  3. FIX: Correct critical issues immediately            │
│            ↓                                            │
│  4. ENHANCE: Add missing coverage, improve docs         │
│            ↓                                            │
│  5. VERIFY: Re-run audit to confirm fixes               │
│            ↓                                            │
│  (repeat weekly or after major changes)                 │
└─────────────────────────────────────────────────────────┘
```

## Example Audit Session

```
User: /qa-audit

Claude:
## Skills QA Audit - [run date]

### Scanning skills directory...
Found N skills (run `find .claude/skills -iname 'skill.md' | wc -l` for live count):
- action-policy, adversarial-review, architect, audit-logs, code-review
- code-smells, commit, coverage, create-pr, debug
- docker-exec, factory-check, fix-issue, gateway-consistency, gateway-test
- gem-hygiene, graphql, grill-me, kaizen, learning
- memberships, migration, multi-tenancy, orchestrate, packwerk
- pci-compliance, performance, qa-audit, query-analyzer, rails-audit
- receiving-code-review, resilience, safe-script, security, sidekiq
- skill-creator, spike-report, tdd, timezone, worktrees
(list illustrative — run the find command for the current canonical set)

### Running automated checks...

✓ No AI mentions in commit messages
✓ Docker execution enforced
✓ Package count accurate (run `ls -d packs/*/ | wc -l` for current count)
✓ 100% coverage required
✓ Forbidden patterns documented
✓ Time safety patterns correct

### Cross-referencing with CLAUDE.md...

| Rule | Coverage | Status |
|------|----------|--------|
| Timezone Safety | timezone, code-review, tdd | OK |
| Multi-tenancy | code-review | OK |
| Financial Transactions | code-review, gateway-test | OK |
| API Compatibility | code-review | OK |
| Payment Idempotency | gateway-test | OK |
| Docker Commands | docker-exec | OK |
| No AI Mentions | commit, create-pr | OK |

### Result: ALL CHECKS PASSED

No critical issues found. Skills are aligned with project requirements.

Next suggested improvements:
1. Add GraphQL-specific patterns to code-review skill
2. Consider adding Sidekiq job validation skill
```

## Scheduling

Run QA audit:
- Weekly (recommended)
- After major CLAUDE.md updates
- After adding/modifying skills
- Before major releases

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new check that should be added
- A missing validation pattern
- A better audit workflow

**You MUST**:
1. Complete the current QA audit first
2. Then invoke `/kaizen` to log improvements — do NOT self-edit this file inline

**Changelog**: see [`kaizen_log.md`](kaizen_log.md) (archived from inline; counts there reflect the session they were written and may be stale — always run `find .claude/skills -iname 'skill.md' | wc -l` for the live count).
