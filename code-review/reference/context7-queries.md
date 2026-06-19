# Code Review — Context7 Query Catalog (Step 11)

Optional, manual. When you hit an unfamiliar pattern, query Context7 for official-docs best practices.

```
# 1. Resolve library ID first
mcp__context7__resolve-library-id:
  libraryName: "rails"
  query: "performance best practices ActiveRecord queries"

# 2. Query specific patterns
mcp__context7__query-docs:
  libraryId: "/rails/rails"
  query: "N+1 prevention includes preload eager_load"
```

## Queries by code type

| Code Type | Query |
|-----------|-------|
| ActiveRecord | `"ActiveRecord performance includes vs joins vs preload"` |
| Sidekiq | `"Sidekiq best practices job design patterns"` |
| GraphQL | `"graphql-ruby performance deferred execution"` |
| RSpec | `"RSpec best practices fast tests factory patterns"` |
| Redis | `"Redis Rails caching patterns memory optimization"` |
| Payments | `"Stripe idempotency keys payment processing"` |

## Performance-specific queries

```
mcp__context7__query-docs:
  libraryId: "/rails/rails"
  query: "database query optimization avoiding N+1 bullet gem"

mcp__context7__query-docs:
  libraryId: "/rspec/rspec"
  query: "fast test suite factory build vs create"
```
