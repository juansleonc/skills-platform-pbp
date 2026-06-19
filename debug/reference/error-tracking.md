# debug/reference/error-tracking.md — Honeybadger + Sentry

> Relocated from SKILL.md Step 2. Body keeps the routing rule (Honeybadger = Rails backend first;
> Sentry = GraphQL/mobile/frontend); this file holds the MCP call shapes and field tables.

---

## Honeybadger

### List Recent Faults

```
mcp__honeybadger__list_faults:
  project_id: <project_id>
  order: recent
  limit: 25
```

### Get Fault Details

```
mcp__honeybadger__get_fault:
  project_id: <project_id>
  fault_id: <fault_id>
```

### Get Error Notices

```
mcp__honeybadger__list_fault_notices:
  project_id: <project_id>
  fault_id: <fault_id>
  limit: 10
```

### Key Information to Extract

| Field | Purpose |
|-------|---------|
| `message` | Error description |
| `backtrace` | Stack trace to find code location |
| `context` | User, facility, request params |
| `environment` | Rails env, server |
| `tags` | Custom tags for filtering |
| `created_at` | When it started happening |
| `notices_count` | How often it occurs |

---

## Sentry

### List Available Projects

```
mcp__sentry__find_projects
```

### Key Projects

| Project | Slug | Use Case |
|---------|------|----------|
| Platform (Rails) | `sentry/platform` | Backend errors |
| GraphQL Pro | `sentry/graphql_pro` | GraphQL errors |
| Mobile | `sentry/pbp-mobile` | React Native errors |
| Frontend | `sentry/platform-frontend-0j` | JavaScript errors |
| Sidekiq | `sentry/sidekiq-platform` | Background job errors |

### List Issues in Project

```
mcp__sentry__search_issues:
  org_slug: "sentry"
  project_slug: "platform"
  query: "is:unresolved"
  limit: 25
```

### Get Issue Details (with stacktrace)

```
mcp__sentry__get_sentry_resource:
  issue_id: "<issue_id>"
```

### Get Recent Events for Issue

```
mcp__sentry__search_issue_events:
  issue_id: "<issue_id>"
  limit: 5
```

### Key Information from Sentry

| Field | Purpose |
|-------|---------|
| `title` | Error type and message |
| `culprit` | File/function where error occurred |
| `firstSeen` | When error first appeared |
| `lastSeen` | Most recent occurrence |
| `count` | Total occurrences |
| `userCount` | Number of affected users |
| `tags` | Environment, browser, device info |
| `stacktrace` | Full stack trace (from get_sentry_resource) |
