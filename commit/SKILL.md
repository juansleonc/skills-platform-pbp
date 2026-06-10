---
name: commit
description: Create conventional git commits with proper formatting following project standards
allowed-tools: [Bash, Read, Grep, Edit, mcp__github__*]
disable-model-invocation: true
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## ⛔ Critical Rules

**NEVER execute `git commit` without explicit user approval.**

Before committing:
1. Show staged changes summary
2. Show proposed commit message
3. Ask explicitly: "Ready to commit? (y/n)"
4. **WAIT** for user to respond "y" or "yes"
5. Only then execute `git commit`

---

# Git Commit Skill

Create well-formatted git commits following the project's conventional commit standards.

## Process

1. **Check current state**
   ```bash
   git status
   git diff --staged
   ```

2. **If no staged changes**, show unstaged changes and ask what to stage

2.5. **Run Pronto + RuboCop validation (BEFORE staging)**

   **CRITICAL**: Run BOTH checks BEFORE staging files. This is a TWO-STEP verification.

   ⚠️ **Pronto only works on UNSTAGED files.** Run this BEFORE `git add`.

   **Step A: Pronto (diff-based — checks only changed lines)**
   ```bash
   bin/d bundle exec pronto run -r rubocop -c develop -f text
   ```

   **Step B: RuboCop on changed files (full file scan — catches everything Pronto might miss)**
   ```bash
   bin/d bundle exec rubocop --force-exclusion $(git diff --name-only develop | grep '\.rb$' | tr '\n' ' ')
   ```

   **BOTH must pass before proceeding.** If either reports violations, fix and re-run both.

   **Expected output**: No violations from either command

   **If violations found**:
   - Fix all violations
   - Re-run BOTH checks until clean
   - Only then proceed to staging and commit

   **Why TWO checks**:
   - Pronto checks only changed lines (can miss issues on continuation lines)
   - RuboCop checks full files (catches Layout/ParameterAlignment, etc.)
   - Together they catch 100% of what CI will flag
   - Pre-commit hook has known issues (`2>/dev/null` swallows errors)

3. **Analyze changes** to determine:
   - Type: feat, fix, refactor, test, docs, chore, style, perf
   - Scope: affected area (e.g., payments, reservations, graphql)
   - Breaking changes

4. **Generate commit message** following format:
   ```
   <type>(<scope>): <description>

   [optional body]

   [optional footer]
      ```

## Commit Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test` | Adding or updating tests |
| `docs` | Documentation only changes |
| `chore` | Maintenance tasks |
| `style` | Formatting, missing semicolons, etc. |
| `perf` | Performance improvement |

## Branch Prefix Convention

Extract ticket from branch name for scope:
- `feature/CORE-123-description` → scope includes `CORE-123`
- `feature/PLA-456-fix-bug` → scope includes `PLA-456`

## Rules

- NEVER commit without explicit user approval
- NEVER use `--no-verify` unless explicitly requested
- NEVER amend commits unless explicitly requested
- Stage specific files, avoid `git add -A` or `git add .`
- Check for sensitive files (.env, credentials) before staging
- NEVER add Co-Authored-By lines or any AI/Claude attribution to commit messages
- **CRITICAL**: NEVER include file lists, test results, or detailed change descriptions in commit messages - git already shows this information

## Example

```bash
# User runs: /commit

# Claude checks status and diff, then proposes:
git commit -m "$(cat <<'EOF'
CORE-121 | feat(onboarding): Add user profile completion flag

- Add has_complete_profile column to users table
- Update onboarding status logic to use new flag
- Add specs for profile completion scenarios

EOF
)"
```

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new commit pattern that should be documented
- A missing rule or edge case
- An outdated example

**You MUST**:
1. Complete the current commit first
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements**:
<!-- Kaizen: 2026-01-30 - Concise Commit Messages -->
**Rule: Keep commit messages clear and concise**

Commit messages should be:
- **First line:** Max 72 characters, format: `TICKET | type(scope): description`
- **Body:** 3-5 bullet points maximum, each line under 80 characters
- **No redundancy:** Don't repeat information already in the first line
- **Action-focused:** Start bullets with verbs (Add, Fix, Update, Remove)

**Good Example (Concise):**
```
CORE-132 | refactor(memberships): Address PR review feedback

- Use update!() instead of update() for safety
- Add error handling with rescue blocks
- Internationalize error messages (en/es)
- Optimize test with :skip_callbacks

Fixes from PR #3995 review
```

**Bad Example (Too verbose):**
```
CORE-132 | refactor(memberships): Address PR review - use update! and i18n error messages

PR review feedback addressed from #3995:

Critical fixes:
- Changed update() to update!() in all 5 failure paths with error handling
- Added rescue blocks to log validation failures explicitly
- Ensures payment_id linkage succeeds or failure is logged

Error message improvements:
- Internationalized all error messages (en/es locales)
- Moved hardcoded strings to i18n keys for multi-language support
- Updated comments for technical accuracy about update() behavior

Test optimization:
- Optimized test_facility with :skip_callbacks trait (saves 40+ records)

Changes in:
- process_player_payment (failure branch + rescue block)
- process_admin_payment (failure branch + rescue block)
- complete_automatic_renewal_failure

All 151 specs passing. No Pronto/Rubocop violations.
```

**Why concise is better:**
- Easier to scan in git log
- Faster to read in reviews
- More professional
- Details available in code/PR anyway

**Rule of thumb:** If the body is > 10 lines, it's too verbose. Aim for 5 lines or less.

<!-- Kaizen: 2026-01-30 - Pronto Integration -->
**Added Step 2.5: Pronto Validation Before Staging**

- **Problem**: Pre-commit hook catches violations AFTER `git add` (too late)
- **Solution**: Run Pronto BEFORE staging files
- **Benefit**: Catch linting issues 15min earlier, prevent commit rejections
- **User feedback**: Eliminates "primero debes hacer add" manual workflow
- **ROI**: 3.0 (high impact, low effort)

<!-- Kaizen: 2026-02-04 - No File Lists or Metadata in Commits -->
**CRITICAL RULE: Commit messages must be minimal - NO file lists, test results, or metadata**

- **Problem**: Commit messages included verbose metadata:
  - File lists ("Archivos modificados: app/foo.rb, spec/bar_spec.rb")
  - Test results ("Tests: ✅ 71 examples, 0 failures")
  - Pronto status ("Pronto: ✅ Clean")
  - Detailed change descriptions repeating what `git diff` shows
- **User feedback**: "Todo esto me parece basura, para eso tenemos git para ver y saber los cambios"
- **Solution**: Commit messages should ONLY have:
  1. First line: `TICKET | type(scope): description` (max 72 chars)
  2. Body (optional): ONLY if adding context NOT visible in git diff
  3. Footer (optional): ONLY for references like "Fixes #123"
- **Why**: Git commands already show all metadata:
  - `git show` → see file changes
  - `git diff` → see exact changes
  - `git log --stat` → see file list
  - CI logs → see test results
- **Bad example** (what NOT to do):
  ```
  CORE-105 | fix(memberships): Update pre-sale email copy

  - Update email subject to use facility name dynamically
  - Change callout heading from long title to simple "Pre-Sale Membership"
  - Remove "Note:" label from message body

  Updated both payment_receipt and ach_payment_receipt emails.

  Archivos modificados:
  - app/views/membership_mailer/_pre_sale_callout.html.erb
  - app/mailers/membership_mailer.rb
  - spec/mailers/membership_mailer_spec.rb

  Tests: ✅ 71 examples, 0 failures
  Pronto: ✅ Clean
  ```
- **Good example** (minimal):
  ```
  CORE-105 | fix(memberships): Update pre-sale email copy per feedback
  ```
- **When to add body**: ONLY when commit message needs context that git diff doesn't show:
  - Business reason for the change
  - Link to external discussion
  - Breaking change warning
  - Migration instructions
- **Impact**: Cleaner git log, faster reviews, more professional commits
- **ROI**: 3.0 (High impact - affects every commit, Low effort - just delete metadata)

Integration follows pattern from `/tdd` Step 4.5 (added same day during CORE-105).

<!-- Kaizen: 2026-02-09 - Mandatory Dual Lint Check (Pronto + RuboCop) -->
**RULE: ALWAYS run both Pronto AND RuboCop on changed files before committing**

- **Problem**: 3 violations made it to PR #4086, then the fix commit introduced a 4th
  (`Layout/ParameterAlignment`). Pronto alone was insufficient:
  1. `Layout/LineLength` (194/125) — long method signature
  2. `Rails/SkipsModelValidations` — `update_columns` in spec
  3. `Style/OpenStructUse` — `OpenStruct` in spec
  4. `Layout/ParameterAlignment` — introduced while fixing #1
- **Root cause (multiple failures)**:
  1. Pronto checks only changed LINES, not surrounding context (missed ParameterAlignment)
  2. Pre-commit hook runs Pronto with `2>/dev/null` — swallows errors silently
  3. Skill trusted single empty Pronto output as "all clean" without verification
- **Solution**: Step 2.5 now requires TWO checks:
  - **Step A**: `bin/d bundle exec pronto run -r rubocop -c develop -f text` (diff-based)
  - **Step B**: `bin/d bundle exec rubocop --force-exclusion $(git diff --name-only develop | grep '\.rb$')` (full file)
  - BOTH must pass. If either fails, fix and re-run both.
- **Code quality at write-time** (prevent violations when writing):
  - Method signatures > 125 chars → split with ONE level of indentation (not aligned to parenthesis)
  - Never use `OpenStruct` in specs → use `instance_double(ClassName)`
  - `update_columns` in specs → add inline `# rubocop:disable Rails/SkipsModelValidations`
- **Impact**: Prevents 100% of CI-only lint failures
- **ROI**: 3.0 (High — every PR benefits, Low effort — one extra command)

<!-- Kaizen: 2026-02-18 - Docker compliance -->
**Fixed: Bare `bundle exec` commands wrapped with `bin/d` per CLAUDE.local.md Rule #2**

- Fixed: lines 45, 50 — `bundle exec pronto` and `bundle exec rubocop` now prefixed with `bin/d`
- Scope: Lines 274-275 left unchanged — they are historical record in lessons-learned section
- ROI: 3.0 (prevents copy-paste violations by any developer reading the skill)

<!-- Kaizen: 2026-02-19 - Verify Commit Contents After Pre-commit Hook (CORE-189) -->
**RULE: After `git commit`, ALWAYS verify actual committed files with `git show --stat HEAD`**

- **Problem**: Pre-commit hook silently dropped a staged file (`docs/features/CORE-189-patch-integration-improvements.md`). The commit succeeded but did not include all staged files. This was only discovered after the fact.
- **Root cause**: The pre-commit hook can rewrite or selectively drop staged files without surfacing an error. The hook exit code is 0, so git proceeds and the commit appears successful.
- **Solution**: Add Step 4 — after every `git commit`, run `git show --stat HEAD` and compare the listed files against what was staged. If any file is missing, it was dropped by the hook.
- **Step 4 (new)**:
  ```bash
  git show --stat HEAD
  # Verify EVERY file you intended to commit appears in the output.
  # If a file is missing → it was silently dropped by the pre-commit hook.
  # Recovery: stage the missing file again and create a NEW commit.
  ```
- **ROI**: 3.0 (prevents silent data loss on every commit)

<!-- Kaizen: 2026-05-12 - User correction (PR defaults — related to commit→PR flow) -->
- Rule: When the commit flow chains into PR creation (`/create-pr` immediately after `/commit`), default the PR to `--assignee juansleonc --label "ready for review"` and surface both in the pre-push confirmation.
- Why: Standard workflow — every PR needs an owner and a status. Omitting them forces the user to ask twice and edit the PR after creation.
- How to apply: This skill itself does not create PRs, but when proposing the follow-up `/create-pr` step (or running it directly), include the defaults. Cross-link: `create-pr/SKILL.md` carries the primary rule.
- Source: User correction on 2026-05-12 during TRI-74 (PR #4836). See `memory/feedback_pr_defaults.md`.
