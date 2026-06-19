# Code Review — Production Error Context (Step 13)

Check for related production errors in Honeybadger (Rails) and Sentry (GraphQL/Mobile/Frontend) for the changed files.

## Honeybadger

```
mcp__honeybadger__list_faults: Search for faults related to changed files
mcp__honeybadger__get_fault: Get details if relevant errors exist
```

## Sentry (GraphQL, Mobile, Frontend)

```
mcp__sentry__search_issues:
  org_slug: "sentry"
  project_slug: "graphql_pro"  # or "platform", "pbp-mobile", etc.
  query: "is:unresolved <search_term>"

mcp__sentry__search_issue_events:
  issue_id: "<issue_id>"
```

## When to check which

| Changed Code | Check |
|--------------|-------|
| GraphQL mutations/queries | `sentry/graphql_pro` |
| Mobile-facing APIs | `sentry/pbp-mobile` |
| Frontend/JS | `sentry/platform-frontend-0j` |
| Sidekiq jobs | `sentry/sidekiq-platform` |
| General Rails | Honeybadger + `sentry/platform` |
