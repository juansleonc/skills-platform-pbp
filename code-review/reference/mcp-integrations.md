# Code Review — MCP Integrations (GitHub + OpenSearch)

## GitHub MCP

Use for PR-based code review:

```
# Get PR details and diff
mcp__github__get_pull_request:
  owner: "PlaybyCourt"
  repo: "platform"
  pull_number: 123

# Get PR files changed
mcp__github__get_pull_request_files:
  owner: "PlaybyCourt"
  repo: "platform"
  pull_number: 123

# Submit review (also covers inline comments via the comments array)
mcp__github__create_pull_request_review:
  owner: "PlaybyCourt"
  repo: "platform"
  pull_number: 123
  event: "COMMENT"  # or "APPROVE" or "REQUEST_CHANGES"
  body: "## Code Review Summary\n..."
```

<!-- mcp__mermaid__* removed — server does not exist in this environment (Fable audit 2026-06-10). Use text-based diagrams instead. -->

## OpenSearch MCP

Use for checking search-related code:

```
# Verify index mappings
mcp__opensearch__IndexMappingTool:
  index: "users"

# Check search query performance
mcp__opensearch__SearchIndexTool:
  index: "users"
  explain: true
  query: { ... }
```
