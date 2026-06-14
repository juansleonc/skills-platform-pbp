# Kaizen Log — create-pr

Archived from SKILL.md on 2026-06-14 per skills audit (reduce per-invocation token cost).

<!-- Kaizen: 2026-05-12 - User correction -->
- Rule: Default every PR creation to `--assignee juansleonc --label "ready for review"`. Surface both fields in the pre-push confirmation block (alongside title/base/body), not only in the executed command.
- Why: Standard workflow — every PR needs an owner and a status. Omitting them forces the user to ask twice and re-edit the PR after creation.
- How to apply: When building the `gh pr create` invocation (and any MCP `create_pull_request` call), always include the assignee and `ready for review` label. Show them in the user-facing proposal. If the user explicitly opts out for a specific PR, respect that for that PR but keep the default for the next one.
- Source: User correction on 2026-05-12 during TRI-74 (PR #4836). See `/Users/leon/.claude/projects/-Users-leon-workspace-pbp-platform/memory/feedback_pr_defaults.md`.

<!-- Kaizen: 2026-05-14 - User correction -->
- Rule: When the source Jira ticket has visual repro artifacts (Loom, video, screenshots, GIFs), include each one as a separate bullet under **Reference** in the PR body — not just the JIRA link.
- Why: Reviewers should see the bug repro one click away from the PR. Forcing them to open the ticket to find the video adds friction and risks them reviewing code without seeing the actual user-visible behavior.
- How to apply: After reading the Jira ticket, scan description AND comments for `loom.com`, `youtube.com`, image attachments, and screenshot URLs. Add a bullet per artifact under **Reference** with a short descriptive label, e.g. `[Loom — bug repro](https://www.loom.com/share/...)`. Apply to every PR, not only bug fixes — feature PRs often have design mockups worth surfacing.
- Source: User correction on 2026-05-14 during TRI-79. See `/Users/leon/.claude/projects/-Users-leon-workspace-pbp-platform/memory/feedback_pr_include_repro_links.md`.

<!-- Kaizen: 2026-06-10 — MCP tool-name + org sweep (Fable audit Tier 2') -->
- Updated stale MCP tool names: no ClickHouse/Sentry/OpenSearch/Rails hits in this file.
- Fixed GitHub org: playbypoint → PlaybyCourt (all 4 occurrences in MCP block).
- Removed mcp__github__request_reviewers (nonexistent tool); replaced with `gh pr edit --add-reviewer` note.

<!-- Kaizen: 2026-06-10 — Add gitmoji + PR defaults (QA audit Tier 1 fix) -->
- Added gitmoji to title format and example (CLAUDE.local.md rule #14).
- Added `--assignee juansleonc --label "ready for review"` defaults to all gh pr create commands (see `/Users/leon/.claude/projects/-Users-leon-workspace-pbp-platform/memory/feedback_pr_defaults.md`).
- Source: QA audit 2026-06-10.
