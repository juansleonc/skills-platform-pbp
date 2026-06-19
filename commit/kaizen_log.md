# commit/SKILL.md — Kaizen History

Archived from SKILL.md on 2026-06-14 (skills audit). All lessons that changed the active body are promoted; narrative entries are preserved here for reference only.

---

## 2026-01-30 — Concise Commit Messages

**Rule: Keep commit messages clear and concise**

Commit messages should be:
- **First line:** Max 72 characters, format: `TICKET | type(scope): description`
- **Body:** 3-5 bullet points maximum, each line under 80 characters
- **No redundancy:** Don't repeat information already in the first line
- **Action-focused:** Start bullets with verbs (Add, Fix, Update, Remove)

**Good Example (Concise):**
```
CORE-132 | ♻️ refactor(memberships): Address PR review feedback

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

---

## 2026-01-30 — Pronto Integration

**Added Step 2.5: Pronto Validation Before Staging**

- **Problem**: Pre-commit hook catches violations AFTER `git add` (too late)
- **Solution**: Run Pronto BEFORE staging files
- **Benefit**: Catch linting issues 15min earlier, prevent commit rejections
- **User feedback**: Eliminates "primero debes hacer add" manual workflow
- **ROI**: 3.0 (high impact, low effort)

---

## 2026-02-04 — No File Lists or Metadata in Commits

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

---

## 2026-02-09 — Mandatory Dual Lint Check (Pronto + RuboCop)

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

---

## 2026-02-18 — Docker Compliance

**Fixed: Bare `bundle exec` commands wrapped with `bin/d` per CLAUDE.local.md Rule #2**

- Fixed: lines 45, 50 — `bundle exec pronto` and `bundle exec rubocop` now prefixed with `bin/d`
- Scope: Lines 274-275 left unchanged — they are historical record in lessons-learned section
- ROI: 3.0 (prevents copy-paste violations by any developer reading the skill)

---

## 2026-02-19 — Verify Commit Contents After Pre-commit Hook (CORE-189)

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

---

## 2026-05-12 — PR Defaults (commit→PR flow)

- Rule: When the commit flow chains into PR creation (`/create-pr` immediately after `/commit`), default the PR to `--assignee <gh-user> --label "ready for review"` and surface both in the pre-push confirmation.
- Why: Standard workflow — every PR needs an owner and a status. Omitting them forces the user to ask twice and edit the PR after creation.
- How to apply: This skill itself does not create PRs, but when proposing the follow-up `/create-pr` step (or running it directly), include the defaults. Cross-link: `create-pr/SKILL.md` carries the primary rule.
- Source: User correction on 2026-05-12 during TRI-74 (PR #4836). See `/Users/leon/.claude/projects/-Users-leon-workspace-pbp-platform/memory/feedback_pr_defaults.md`.

---

## 2026-06-10 — Process Step + When-to-Use Fix (Fable re-audit hygiene pass)

- Promoted 2026-02-19 Kaizen finding to Process body: added Step 5 "After commit: verify with `git show --stat HEAD`" so the hook-silenced-file risk is caught on every commit, not only when a developer re-reads the Kaizen section.
- Removed "(or this skill is invoked automatically)" from "When to Use" — frontmatter has `disable-model-invocation: true`; the parenthetical contradicted it.

---

## 2026-06-10 — Add Gitmoji + When To Use (QA audit fix)

- Updated format template and examples to include gitmoji (CLAUDE.local.md rule #14 was missing from skill).
- Added "When to Use" section (Integration=1 → fixes the missing trigger).
- Source: QA audit 2026-06-10, Tier 1 fix.

---

## 2026-06-14 — Skills Audit Fixes

- Fixed dead memory path: `memory/feedback_pr_defaults.md` → absolute canonical path `/Users/leon/.claude/projects/-Users-leon-workspace-pbp-platform/memory/feedback_pr_defaults.md`.
- Archived Kaizen log to `kaizen_log.md` (this file); replaced inline entries with compact changelog table in SKILL.md.
- Pronto command already correct (`bin/d bundle exec pronto run -r rubocop -c develop -f text`) — no change needed.
- Source: Skills audit 2026-06-13, commit skill (Opportunity 52).
