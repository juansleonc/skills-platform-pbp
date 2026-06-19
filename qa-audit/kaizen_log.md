# qa-audit Kaizen Log

Archived from `SKILL.md` body — moved here to keep the active skill lean.
See `SKILL.md` → "Kaizen: Continuous Improvement" for the current improvement cycle.

---

<!-- Kaizen: 2026-06-15 — Correctness pass: fix broken package-count check + stale literal -->
- **Fixed (SKILL.md Step 1 comment)**: Removed stale literal "counts all 42". Live count is 43
  (`find .claude/skills -iname 'skill.md' | wc -l`). Changed to point at the live command only,
  matching the file's own "do not hardcode" convention used elsewhere.
- **Fixed (SKILL.md Step 6 + qa_audit.sh Check 3)**: The package-count-accuracy check was
  permanently broken: `grep -oiE "[0-9]+ Packwerk packages" .claude/skills/packwerk/skill.md`
  matched nothing — packwerk's skill file moved its pack inventory to `reference/packs.md` and
  contains no "N Packwerk packages" phrase. This produced a permanent false-positive
  "packwerk declares ? packages but reality is 18" on every run. Fixed both SKILL.md (Step 6
  prose now explains the doc move) and qa_audit.sh (Check 3 now verifies that
  `reference/packs.md` exists as the canonical inventory doc, and reports the live count
  without a false-positive comparison).
- **Verified correct, not changed**: Step 4 cross-ref greps, Step 6 Makefile targets, all
  skill references (commit, create-pr, coverage, tdd, etc.), frontmatter, Config Priority banner.

---

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
  ⚠️ NOTE (2026-06-14): These counts were stale at time of archival. Real count at archival:
  42 SKILL.md files (`find .claude/skills -iname 'skill.md' | wc -l`), 0 openspec-* directories.
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

<!-- Kaizen: 2026-06-10 — Body↔changelog reconciliation (Fable re-audit; was graded C for self-contradiction) -->
- Removed the stale "lowercase skill.md is canonical" comment in the automated script (reality: ~40 SKILL.md, 0 lowercase); `skillfile()` now documented as a portability measure, not a mixed-casing workaround.
- Package criterion in Step 3 is now dynamic (`ls -d packs/*/ | wc -l`) instead of the hardcoded "Matches reality (10 packages)".
- Step 1 comment updated: no longer claims mixed casing is "REAL"; states canonical = UPPERCASE `SKILL.md` and `-iname` is kept for Linux CI portability only.
- Steps 4/5 `review` → `code-review` throughout (the `review` skill does not exist; the correct skill is `code-review`).
- Step 4 manual grep paths for coverage/tdd changed from bare lowercase `skill.md` to use `-iname` inline (matching the automated script's resolver pattern).
- Example session updated: removed stale "12 skills from 2025" list and hardcoded counts; list is now illustrative + points to the live command; `review` replaced with `code-review` in the cross-reference table.
- Lesson: when a Kaizen entry corrects a defect, the body sections that contain the defect must be updated in the SAME pass — append-only changelogs without body integration create self-contradiction.
