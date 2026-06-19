# fix-issue — Kaizen Log

Historical improvement entries archived from SKILL.md (moved 2026-06-14 per skills-audit Wave 2).

---

<!-- Kaizen: 2026-06-15 — Corrected Sentry MCP tool names to custom self-hosted server schema -->
- Verified actual MCP server at `~/.claude/mcp-servers/sentry_selfhosted.py`: tools are `sentry_list_issues` (params: `org_slug`, `project_slug`, `query`, `limit`) and `sentry_get_issue` (param: `issue_id`). The body was using cloud-schema names (`search_issues`, `get_sentry_resource`) left over from a prior incorrect kaizen sweep.
- Updated body Sentry examples to correct tool names (`mcp__sentry__sentry_list_issues`, `mcp__sentry__sentry_get_issue`) and clarified they are the custom self-hosted server.
- APPLIED (follow-up): frontmatter `allowed-tools` now lists the self-hosted names (`mcp__sentry__sentry_list_projects`, `mcp__sentry__sentry_list_issues`, `mcp__sentry__sentry_get_issue`, `mcp__sentry__sentry_get_issue_events`), matching the body and the actual server's `@server.list_tools()` definitions. Body + frontmatter no longer contradict; `allowed-tools` is a hard capability gate, so the Sentry tools are now callable. Grounded against `sentry_selfhosted.py` lines 144-218.

<!-- Kaizen: 2026-06-10 — MCP tool-name + org sweep (Fable audit Tier 2') — ⚠️ RETRACTED by 2026-06-15 entry: the Sentry tool-name change below (sentry_list_issues → search_issues, sentry_get_issue → get_sentry_resource) was WRONG for this project's self-hosted server and has been reversed. The GitHub-org and gitmoji fixes remain valid. -->
- Updated stale MCP tool names to the current environment (Sentry sentry_list_issues → search_issues, sentry_get_issue → get_sentry_resource); removed mcp__github__list_issue_comments (nonexistent tool; replaced with `gh issue view --comments` note).
- Fixed GitHub org: playbypoint → PlaybyCourt (all occurrences in MCP block).
- Added gitmoji to commit message format template and example per CLAUDE.local.md rule #14 (`TICKET | EMOJI type(scope): Description`).
