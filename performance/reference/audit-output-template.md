# Performance Audit Output Template

Paste/fill this when emitting a performance audit. Sections:
Summary, N+1 Query Issues, Missing Indexes, Memory Concerns, Production Scale, Recommendations.

```markdown
## Performance Audit

### Summary
- Files analyzed: X
- N+1 issues: Y
- Missing indexes: Z
- Memory concerns: W

### N+1 Query Issues

| File | Line | Pattern | Fix |
|------|------|---------|-----|
| users_controller.rb | 45 | `user.facility` in loop | Add `includes(:facility)` |

### Missing Indexes

| Table | Column | Query Pattern |
|-------|--------|---------------|
| reservations | user_id | WHERE user_id = ? |

### Memory Concerns

| File | Issue | Impact |
|------|-------|--------|
| export_job.rb | Loads all users | OOM on 100k+ users |

### Production Scale (ClickHouse row-count context — NOT timings)

| Query Pattern | Row Volume | Recommendation |
|---------------|------------|----------------|
| reservations WHERE facility_id | 1.2M rows (FINAL) | Add composite index |

> Query timings come from New Relic / EXPLAIN, not ClickHouse (see Step 8).

### Recommendations
1. Add `includes(:facility, :memberships)` to UsersController#index
2. Add index on reservations(facility_id, status)
3. Use `find_each` in ExportJob
```
