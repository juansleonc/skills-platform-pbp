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
# IMPORTANT: the skill filename casing is MIXED in this repo (most are `SKILL.md`,
# a few newer ones are `skill.md`). macOS FS is case-insensitive so a glob hides this,
# but `find -name` is case-SENSITIVE and would undercount. Always use `-iname`.
find .claude/skills -maxdepth 2 -iname "skill.md"

# Count skills
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
| Package count | Check packwerk skill | Matches reality (10 packages) |
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
grep -rn "100%" .claude/skills/coverage/skill.md
grep -rn "100%" .claude/skills/tdd/skill.md
```

### Step 5: Validate Against CLAUDE.md

| CLAUDE.md Rule | Skill That Should Enforce | Verified |
|----------------|---------------------------|----------|
| Timezone Safety | timezone, review, tdd | |
| Multi-tenancy | review | |
| Financial Transactions | review, gateway-test | |
| API Compatibility | review | |
| Payment Idempotency | gateway-test, review | |
| Docker Commands | docker-exec (global) | |
| No AI Mentions | commit, create-pr, fix-issue | |

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
| review | Add Honeybadger integration | Medium |
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
# NOTE: canonical skill filename is lowercase `skill.md`. We skip whole "Before/After"
# example blocks (awk drops lines from `<!-- Before` until the next `<!-- After` or blank
# line) so intentional bad examples don't false-positive. `docker-exec` is the canonical
# "raw bundle exec inside the container" reference, so it's excluded by design.
# Resolve a skill file case-insensitively (handles mixed SKILL.md / skill.md).
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
## Skills QA Audit - 2025-01-21

### Scanning skills directory...
Found 12 skills:
- commit, coverage, create-pr, docker-exec, fix-issue
- gateway-test, orchestrate, packwerk, qa-audit, review
- tdd, timezone

### Running automated checks...

✓ No AI mentions in commit messages
✓ Docker execution enforced
✓ Package count accurate (10)
✓ 100% coverage required
✓ Forbidden patterns documented
✓ Time safety patterns correct

### Cross-referencing with CLAUDE.md...

| Rule | Coverage | Status |
|------|----------|--------|
| Timezone Safety | timezone, review, tdd | OK |
| Multi-tenancy | review | OK |
| Financial Transactions | review, gateway-test | OK |
| API Compatibility | review | OK |
| Payment Idempotency | gateway-test | OK |
| Docker Commands | docker-exec | OK |
| No AI Mentions | commit, create-pr | OK |

### Result: ALL CHECKS PASSED

No critical issues found. Skills are aligned with project requirements.

Next suggested improvements:
1. Add GraphQL-specific patterns to review skill
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
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements**:
<!-- Kaizen: 2026-05-25 - Audit run: package drift + skill ecosystem grown to 49 -->
- Fixed: `packwerk/skill.md` package count 15 → **18** (added `billing`, `electronic_invoicing`, `partners`). This skill is the sanctioned source of truth; updated it.
- Reported (NOT fixed — never modify CLAUDE.md): CLAUDE.md still says "Fifteen domain packages" and its table lists 15. User must update manually.
- Fixed in THIS skill (the checks were themselves buggy):
  - **Mixed filename casing is REAL**: 44 skills are `SKILL.md`, 5 are `skill.md` (grill-me, kaizen,
    learning, skill-creator, spike-report). macOS FS is case-insensitive so a glob hides it, but
    `find -name` / `grep --include` are case-SENSITIVE. The old checks used `--include="*.md"` then
    later a lowercase literal — both undercounted. Now ALL file lookups use `find -iname 'skill.md'`
    + a `skillfile()` resolver, so checks scan all 49 regardless of casing and stay portable to Linux CI.
    (Earlier same-session note wrongly called lowercase "canonical" — it is NOT; uppercase is the majority
    and the documented Claude Code convention.)
  - **Dynamic package count**: replaced hardcoded "10 packages" with `ls -d packs/*/ | wc -l` vs the
    number declared in packwerk's skill file. (Reality is now 18.)
  - **Before/After false-positive**: awk now drops `<!-- Before -->` example blocks; `RAILS_ENV=production
    … runner` is excluded (prod scripts legitimately aren't Docker-wrapped).
- REAL finding fixed: `commit/SKILL.md` Step A/B showed raw `bundle exec pronto`/`rubocop` →
  wrapped with `bin/d` (CLAUDE.local #3). The old grep missed this because `--include="skill.md"`
  only matched the 5 lowercase files.
- Verified clean (thorough, all 49 via `-iname`): no real `Co-Authored-By`/AI attribution
  (only rule statements + the audit's own check descriptions); no unflagged `Time.now`;
  coverage states 100% (9×); all skills have YAML frontmatter.
- Noted (not violations): `.claude/skills` is **gitignored** (personal, not the shared repo);
  10 `openspec-*` skills lack the Config Priority banner (external/experimental, not user-authored).
  Ecosystem is 49 skills + `shared/`.
- Session skills validated: `/grill-me` compliant (frontmatter, banner, scoped tools) but is one of
  the 5 lowercase outliers — consider renaming to `SKILL.md` for convention consistency. Old
  `[[reference_ai_coding_workflow_pocock]]` memory ref cleaned after consolidation into
  `[[reference_ai_coding_multiagent_workflow]]`.

<!-- Kaizen: 2026-01-24 - MCP Integration -->
- Integrated: 7 new MCPs across 10 skills:
  - `github` → fix-issue, create-pr, commit, code-review, debug (issues, PRs, reviews)
  - `opensearch` → performance, debug, code-review (search query analysis)
  - `rails` → performance, debug (console, routes, generators)
  - `playwright` → tdd (system test debugging)
  - `mermaid` → architect, code-review (diagram generation)
  - `stripe` → gateway-test, pci-compliance (API validation)
- Added: MCP usage documentation sections to integrated skills
- Total MCPs available: 14 (clickhouse, context7, honeybadger, sentry, github, opensearch, rails, playwright, mermaid, stripe, filesystem, figma, terraform, kubernetes)

<!-- Kaizen: 2026-01-24 - Shared Documentation -->
- Created: `.claude/shared/` directory with 5 consolidated docs (factory-rules, forbidden-patterns, clickhouse-queries, testing-patterns, critical-rules)
- Created: 3 new domain skills: `/pci-compliance`, `/gateway-consistency`, `/membership-validate`
- Updated: 8 skills to reference shared documentation (tdd, coverage, multi-tenancy, timezone, sidekiq, packwerk, security, code-review)
- Updated: `/orchestrate` with Phase 1A/1B split, PARALLEL domain skills, 3 new workflows
- Updated: Skills count now 24 (was 21)
- Fixed: `/code-review` missing shared references
- Verified: All skills have proper YAML frontmatter and Config Priority banner
- Verified: All `bundle exec` commands properly wrapped with `docker compose exec web`

<!-- Kaizen: 2026-01-23 -->
- Added: `⛔ Critical Rules` section to `commit/SKILL.md` - explicit user approval before git commit
- Added: `⛔ Critical Rules` section to `create-pr/SKILL.md` - explicit user approval before git push/pr create
- Added: `⛔ Critical Rules` section to `orchestrate/SKILL.md` - explicit user approval for Phase 4: Publish
- Fixed: `docker-exec/SKILL.md` - clarified that raw `bundle exec` is ONLY for inside container
- Updated: Skills count now 21 (was 20)
- Added: New audit check for git operation approval requirements

<!-- Kaizen: 2026-01-22 -->
- Fixed: `create-pr/SKILL.md` lines 90-91 - wrapped pronto/rubocop with `docker compose exec web`
- Fixed: `tdd/SKILL.md` line 276 - wrapped system test command with `docker compose exec`
- Added: CRITICAL RULE - NEVER modify CLAUDE.md (shared versioned file)
- Noted: CLAUDE.md lists 7 packages but reality is 10 (user must update manually)
- Verified: 20 skills installed, all have Config Priority banner
- Verified: All CLAUDE.md critical rules have skill coverage
