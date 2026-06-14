---
name: qa-audit
description: Quality Assurance and continuous improvement audit for all Claude Code skills. Validates skills against project requirements and identifies improvement opportunities.
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
# `find -name 'SKILL.md'` counts all 42 (run `find .claude/skills -iname 'skill.md' | wc -l` for live count; there are 0 lowercase `skill.md` files).
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
| Frontmatter description | Read `description:` line | states triggers only (no workflow summary) — see skill-creator CSO Rule |

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
# Package count — compare reality vs what packwerk/skill.md declares (do not hardcode)
ls -d packs/*/ | wc -l
grep -oiE "[0-9]+ Packwerk packages" .claude/skills/packwerk/skill.md

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

```bash
#!/bin/bash
# qa-audit.sh - Run all automated checks

echo "=== QA Audit Starting ==="

# Check 1: No Claude/AI mentions
echo "Checking for forbidden AI mentions..."
if grep -rn "Co-Authored-By: Claude\|Generated with.*Claude" .claude/skills/ --include="*.md"; then
  echo "❌ FAIL: Found AI mentions in skills"
  exit 1
fi
echo "✓ No AI mentions"

# Check 2: All commands use Docker
# NOTE: canonical skill filename is UPPERCASE `SKILL.md` (~40 files; 0 lowercase).
# skillfile() uses -iname for cross-platform portability (Linux CI), not to handle
# mixed casing — mixed casing was fixed. We skip whole "Before/After" example blocks
# (awk drops lines from `<!-- Before` until the next `<!-- After` or blank line) so
# intentional bad examples don't false-positive. `docker-exec` is the canonical
# "raw bundle exec inside the container" reference, so it's excluded by design.
skillfile() { find ".claude/skills/$1" -maxdepth 1 -iname "skill.md" | head -1; }

echo "Checking Docker usage..."
# Iterate all skills case-insensitively; skip docker-exec (canonical raw-command reference)
# and PRODUCTION runner examples (`RAILS_ENV=production ... runner`, which run on prod, not
# locally in Docker). The awk also drops `<!-- Before -->` example blocks.
BAD_COMMANDS=$(for f in $(find .claude/skills -iname 'skill.md' | grep -v "/docker-exec/"); do
  awk -v F="$f" '
    /<!-- Before/      { skip=1 }
    /<!-- After/       { skip=0 }
    /^[[:space:]]*$/   { skip=0 }
    /bundle exec/ && !skip {
      if ($0 !~ /docker compose exec|make |bin\/d|# *BAD|❌|RAILS_ENV=production/) print F":"FNR": "$0
    }' "$f"
done)
if [ -n "$BAD_COMMANDS" ]; then
  echo "⚠️ WARNING: Found non-Docker commands:"
  echo "$BAD_COMMANDS"
else
  echo "✓ No unwrapped bundle exec commands"
fi

# Check 3: Package count accuracy (DYNAMIC — never hardcode the count)
# Compare the real pack count against the number declared in packwerk's skill file.
echo "Checking package count..."
ACTUAL_PACKAGES=$(ls -d packs/*/ 2>/dev/null | wc -l | tr -d ' ')
DECLARED_PACKAGES=$(grep -oiE "[0-9]+ Packwerk packages" "$(skillfile packwerk)" | grep -oE "[0-9]+" | head -1)
if [ "$ACTUAL_PACKAGES" != "$DECLARED_PACKAGES" ]; then
  echo "⚠️ WARNING: packwerk declares ${DECLARED_PACKAGES:-?} packages but reality is $ACTUAL_PACKAGES"
  echo "   → Update packwerk's skill file (source of truth). Report CLAUDE.md drift; do NOT edit CLAUDE.md."
else
  echo "✓ Package count accurate ($ACTUAL_PACKAGES)"
fi

# Check 4: 100% coverage requirement
echo "Checking coverage requirements..."
if ! grep -q "100%" "$(skillfile coverage)"; then
  echo "❌ FAIL: Coverage skill doesn't mention 100% requirement"
fi
echo "✓ Coverage requirement present"

# Check 5: Forbidden patterns documented
echo "Checking forbidden patterns..."
if ! grep -q "allow_any_instance_of" "$(skillfile tdd)"; then
  echo "⚠️ WARNING: TDD skill missing forbidden pattern documentation"
fi

echo "=== QA Audit Complete ==="
```

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
