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

## When to Use

Run `/commit` manually whenever you are about to execute `git commit`. It is a **hard gate** — do not commit without:
1. Pronto clean on changed files (CLAUDE.local.md rule #3)
2. Gitmoji + ticket in the commit message (CLAUDE.local.md rule #14)
3. Explicit user `y` approval (CLAUDE.md Critical Rules)

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

4. **Generate commit message** following format (CLAUDE.local.md rule #14):
   ```
   TICKET | EMOJI type(scope): description

   [optional body — 3–5 bullets max, action verbs]

   [optional footer]
   ```

5. **After commit: verify with `git show --stat HEAD`** — confirm only the intended files appear in the output. If any staged file is missing, it was silently dropped by the pre-commit hook; stage it again and create a NEW commit.

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
CORE-121 | ✨ feat(onboarding): Add user profile completion flag

- Add has_complete_profile column to users table
- Update onboarding status logic to use new flag
- Add specs for profile completion scenarios

EOF
)"
```

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

Full history → [`kaizen_log.md`](kaizen_log.md)

To add a new entry: append to `kaizen_log.md` and, if the lesson changes active behaviour, promote it into the Process steps above.

| Date | Change |
|------|--------|
| 2026-01-30 | Concise commit messages rule (max 72 chars first line, 3–5 bullet body) |
| 2026-01-30 | Added Step 2.5 — Pronto validation before staging |
| 2026-02-04 | No file lists / test results / metadata in commit messages |
| 2026-02-09 | Dual lint check: Pronto (diff) + RuboCop (full file), both required |
| 2026-02-18 | Wrapped bare `bundle exec` with `bin/d` (Docker compliance) |
| 2026-02-19 | Added Step 5 — verify committed files with `git show --stat HEAD` |
| 2026-05-12 | PR defaults note: `/create-pr` should include `--assignee juansleonc --label "ready for review"` |
| 2026-06-10 | Promoted Step 5 to body; removed stale auto-invoke parenthetical |
| 2026-06-10 | Added gitmoji + "When to Use" section (QA audit fix) |
| 2026-06-14 | Fixed dead `memory/` path → absolute canonical path; archived Kaizen log to `kaizen_log.md` |
