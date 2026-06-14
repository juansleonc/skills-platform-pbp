# fix-issue — Kaizen Log

Historical improvement entries archived from SKILL.md (moved 2026-06-14 per skills-audit Wave 2).

---

<!-- Kaizen: 2026-06-10 — MCP tool-name + org sweep (Fable audit Tier 2') -->
- Updated stale MCP tool names to the current environment (Sentry sentry_list_issues → search_issues, sentry_get_issue → get_sentry_resource); removed mcp__github__list_issue_comments (nonexistent tool; replaced with `gh issue view --comments` note).
- Fixed GitHub org: playbypoint → PlaybyCourt (all occurrences in MCP block).
- Added gitmoji to commit message format template and example per CLAUDE.local.md rule #14 (`TICKET | EMOJI type(scope): Description`).
