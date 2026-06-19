# debug/reference/mcp-integrations.md — GitHub / OpenSearch / Rails MCP

> Relocated from SKILL.md. Supplementary MCP calls beyond the primary ClickHouse/Honeybadger/Sentry
> routing. Org is `PlaybyCourt`.

---

## GitHub MCP — find related issues/PRs

```
# Search for similar issues
mcp__github__search_issues:
  q: "repo:PlaybyCourt/platform is:issue label:bug membership renewal"

# Check if issue exists for this error
mcp__github__search_issues:
  q: "repo:PlaybyCourt/platform is:issue NoMethodError membership"

# Get issue timeline for context (mcp__github__list_issue_events not available; use gh CLI instead)
# gh issue view 456 --repo PlaybyCourt/platform --comments

# Create issue for discovered bug
mcp__github__create_issue:
  owner: "PlaybyCourt"
  repo: "platform"
  title: "[BUG] Weekly memberships not renewing"
  body: "## Description\n..."
  labels: ["bug", "memberships"]
```

## OpenSearch MCP — debug search issues

```
# Check index health
mcp__opensearch__ClusterHealthTool

# Debug search queries
mcp__opensearch__SearchIndexTool:
  index: "users"
  explain: true
  query: { "match": { "email": "test@example.com" } }
```

## Rails MCP — interactive debugging

```
# Query data in console
mcp__rails__execute_ruby:
  code: "Membership.weekly.renewable.count"

# Check model associations
mcp__rails__execute_ruby:
  code: "Membership.reflect_on_all_associations.map { |a| [a.name, a.macro] }"
```
