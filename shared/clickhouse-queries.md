# ClickHouse Queries - Common Patterns

Common ClickHouse queries for production data verification, security audits, performance analysis, and debugging. All queries use the production database: `pbp_productionDB_optimized`.

## Database Connection

```sql
-- Database name (use in all queries)
pbp_productionDB_optimized

-- Common tables
- users
- facilities
- reservations
- payments
- memberships
- webhooks_urls
- audit_logs
- notifications
```

---

## Security Queries

### 1. Check for Unencrypted Sensitive Data

**Purpose**: Verify webhooks use `attr_encrypted` for auth tokens

```sql
SELECT
  id,
  name,
  CASE
    WHEN auth_token IS NOT NULL AND auth_token != '' THEN 'UNENCRYPTED!'
    ELSE 'OK'
  END as status
FROM pbp_productionDB_optimized.webhooks_urls
WHERE auth_token IS NOT NULL AND auth_token != ''
LIMIT 10;
```

**Expected**: 0 rows (all tokens should be encrypted)

---

### 2. Check for Exposed Card Data

**Purpose**: Verify payments use tokenization, not raw card numbers

```sql
SELECT
  count(*) as total,
  countIf(card_number IS NOT NULL AND length(card_number) > 4) as exposed_cards
FROM pbp_productionDB_optimized.payments;
```

**Expected**: `exposed_cards = 0` (only last 4 digits allowed)

---

### 3. Check for Sensitive Data in Logs

**Purpose**: Detect accidental logging of passwords, tokens, card numbers

```sql
SELECT
  count(*) as sensitive_logs,
  countIf(message LIKE '%password%') as password_logs,
  countIf(message LIKE '%token%') as token_logs,
  countIf(message LIKE '%card_number%') as card_logs
FROM pbp_productionDB_optimized.audit_logs
WHERE message LIKE '%password%'
   OR message LIKE '%token%'
   OR message LIKE '%secret%'
   OR message LIKE '%card_number%';
```

**Expected**: `sensitive_logs = 0` (no sensitive data in logs)

---

## Multi-Tenancy Queries

### 4. Check if Table Has facility_id

**Purpose**: Verify table has multi-tenancy column

```sql
SELECT column_name, data_type
FROM system.columns
WHERE database = 'pbp_productionDB_optimized'
AND table = '<table_name>'
AND column_name = 'facility_id';
```

**Expected**: 1 row with `facility_id` column

**Usage**: Replace `<table_name>` with actual table (e.g., `reservations`, `users`, `payments`)

---

### 5. Check for Orphaned Records (No facility_id)

**Purpose**: Find records missing facility_id (data leak risk)

```sql
SELECT count(*) as orphaned
FROM pbp_productionDB_optimized.<table>
WHERE facility_id IS NULL;
```

**Expected**: `orphaned = 0` (all records scoped to facility)

---

### 6. Verify Data Distribution Across Facilities

**Purpose**: Check data is properly distributed, detect anomalies

```sql
SELECT
  facility_id,
  count(*) as record_count,
  round(count(*) * 100.0 / sum(count(*)) OVER (), 2) as percentage
FROM pbp_productionDB_optimized.<table>
GROUP BY facility_id
ORDER BY record_count DESC
LIMIT 20;
```

**Interpretation**:
- Look for facilities with 0 records (might be test/inactive)
- Look for facilities with disproportionate data (might indicate leak)

---

### 7. Verify Facility Group Boundaries

**Purpose**: Ensure webhooks don't cross facility group boundaries

```sql
SELECT
  w.id as webhook_id,
  w.name as webhook_name,
  f1.id as source_facility,
  f1.franchise_id as source_group,
  f2.id as target_facility,
  f2.franchise_id as target_group
FROM pbp_productionDB_optimized.webhooks_urls w
JOIN pbp_productionDB_optimized.facilities f1 ON w.facility_id = f1.id
LEFT JOIN pbp_productionDB_optimized.facilities f2 ON w.target_facility_id = f2.id
WHERE f1.franchise_id != f2.franchise_id
  AND f2.franchise_id IS NOT NULL
LIMIT 20;
```

**Expected**: 0 rows (no cross-group webhooks)

---

## Performance Queries

### 8. Find Slow Queries (from ClickHouse logs)

**Purpose**: Identify expensive queries causing performance issues

```sql
SELECT
  query_duration_ms,
  query,
  user,
  query_start_time
FROM system.query_log
WHERE query_duration_ms > 5000  -- Queries slower than 5 seconds
  AND type = 'QueryFinish'
  AND event_date = today()
ORDER BY query_duration_ms DESC
LIMIT 20;
```

**Interpretation**:
- Look for queries without indexes (full table scans)
- Look for missing `facility_id` filters
- Look for N+1 query patterns

---

### 9. Table Size Analysis

**Purpose**: Find largest tables (candidates for optimization)

```sql
SELECT
  table,
  formatReadableSize(sum(bytes)) as size,
  sum(rows) as rows,
  round(sum(bytes) / sum(rows), 2) as bytes_per_row
FROM system.parts
WHERE database = 'pbp_productionDB_optimized'
  AND active = 1
GROUP BY table
ORDER BY sum(bytes) DESC
LIMIT 20;
```

**Usage**: Identify tables to optimize, archive, or partition

---

### 10. Check for N+1 Query Patterns

**Purpose**: Detect repeated similar queries (N+1 problem)

```sql
WITH query_patterns AS (
  SELECT
    replaceRegexpAll(query, '[0-9]+', 'N') as pattern,
    count(*) as occurrences
  FROM system.query_log
  WHERE event_date = today()
    AND type = 'QueryFinish'
    AND query NOT LIKE '%system.%'
  GROUP BY pattern
  HAVING occurrences > 100
)
SELECT
  pattern,
  occurrences,
  round(occurrences * 100.0 / sum(occurrences) OVER (), 2) as percentage
FROM query_patterns
ORDER BY occurrences DESC
LIMIT 20;
```

**Interpretation**: High `occurrences` (>1000) suggests N+1 problem

---

## Debugging Queries

### 11. Find Recent Errors by Facility

**Purpose**: Debug production errors for specific facility

```sql
SELECT
  facility_id,
  error_class,
  count(*) as error_count,
  max(occurred_at) as last_occurrence
FROM pbp_productionDB_optimized.errors
WHERE occurred_at >= now() - INTERVAL 24 HOUR
  AND facility_id = <facility_id>
GROUP BY facility_id, error_class
ORDER BY error_count DESC
LIMIT 20;
```

**Usage**: Replace `<facility_id>` with actual facility ID

---

### 12. Payment Failure Analysis

**Purpose**: Investigate payment failures by gateway

```sql
SELECT
  gateway_name,
  status,
  count(*) as payment_count,
  round(avg(amount), 2) as avg_amount,
  sum(amount) as total_amount
FROM pbp_productionDB_optimized.payments
WHERE created_at >= now() - INTERVAL 7 DAY
  AND status != 'succeeded'
GROUP BY gateway_name, status
ORDER BY payment_count DESC
LIMIT 20;
```

**Interpretation**: High failure counts by gateway suggest gateway issues

---

### 13. User Activity Timeline

**Purpose**: Debug user-specific issues (reservations, payments, memberships)

```sql
SELECT
  'reservation' as event_type,
  created_at as event_time,
  status,
  id
FROM pbp_productionDB_optimized.reservations
WHERE user_id = <user_id>

UNION ALL

SELECT
  'payment' as event_type,
  created_at as event_time,
  status,
  id
FROM pbp_productionDB_optimized.payments
WHERE user_id = <user_id>

UNION ALL

SELECT
  'membership' as event_type,
  created_at as event_time,
  status,
  id
FROM pbp_productionDB_optimized.memberships
WHERE user_id = <user_id>

ORDER BY event_time DESC
LIMIT 50;
```

**Usage**: Replace `<user_id>` with actual user ID

---

## Data Verification Queries

### 14. Check Data Consistency (Foreign Keys)

**Purpose**: Find orphaned records (referencing deleted records)

```sql
-- Example: Payments without user
SELECT count(*) as orphaned_payments
FROM pbp_productionDB_optimized.payments p
LEFT JOIN pbp_productionDB_optimized.users u ON p.user_id = u.id
WHERE p.user_id IS NOT NULL
  AND u.id IS NULL;

-- Example: Reservations without facility
SELECT count(*) as orphaned_reservations
FROM pbp_productionDB_optimized.reservations r
LEFT JOIN pbp_productionDB_optimized.facilities f ON r.facility_id = f.id
WHERE r.facility_id IS NOT NULL
  AND f.id IS NULL;
```

**Expected**: 0 orphaned records

---

### 15. Duplicate Detection

**Purpose**: Find duplicate records (should be unique)

```sql
-- Example: Duplicate emails
SELECT
  email,
  count(*) as duplicate_count
FROM pbp_productionDB_optimized.users
GROUP BY email
HAVING count(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;

-- Example: Duplicate facility subdomains
SELECT
  subdomain,
  count(*) as duplicate_count
FROM pbp_productionDB_optimized.facilities
GROUP BY subdomain
HAVING count(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;
```

**Expected**: 0 rows (no duplicates)

---

## Time-Based Analysis

### 16. Activity by Hour (Peak Usage)

**Purpose**: Identify peak usage times for capacity planning

```sql
SELECT
  toHour(created_at) as hour,
  count(*) as reservations
FROM pbp_productionDB_optimized.reservations
WHERE created_at >= now() - INTERVAL 7 DAY
GROUP BY hour
ORDER BY hour;
```

**Usage**: Identify when to schedule maintenance (low traffic hours)

---

### 17. Growth Analysis (Weekly/Monthly)

**Purpose**: Track platform growth over time

```sql
SELECT
  toStartOfWeek(created_at) as week,
  count(*) as new_users,
  sum(count(*)) OVER (ORDER BY toStartOfWeek(created_at)) as cumulative_users
FROM pbp_productionDB_optimized.users
WHERE created_at >= now() - INTERVAL 90 DAY
GROUP BY week
ORDER BY week;
```

---

## Best Practices

### Query Tips

1. **Always filter by facility_id** when querying multi-tenant tables
2. **Limit results** with `LIMIT` to avoid overwhelming output
3. **Use date ranges** to reduce data scanned (`created_at >= now() - INTERVAL 7 DAY`)
4. **Check execution time** - queries > 10 seconds need optimization
5. **Use table aliases** for readability in joins

### Safety

1. **Read-only queries** - Never run UPDATE/DELETE in production
2. **Verify database** - Always use `pbp_productionDB_optimized` (not staging)
3. **Sample data** - Use `LIMIT` when exploring unknown tables
4. **Explain first** - Use `EXPLAIN` to check query plan before running expensive queries

### Performance

1. **Use PREWHERE** instead of WHERE for large tables (ClickHouse optimization)
2. **Avoid SELECT *** - Specify columns to reduce data transfer
3. **Use materialized views** for frequently-run aggregations
4. **Partition by date** for time-series data (if table supports it)

---

## MCP Usage

**ClickHouse MCP Tool**: `mcp__clickhouse__run_select_query`

```
mcp__clickhouse__run_select_query:
  query: "SELECT count(*) FROM pbp_productionDB_optimized.users WHERE facility_id = 123"
```

**Skills that use this MCP**:
- `/security` - Data exposure detection
- `/multi-tenancy` - Facility scoping verification
- `/performance` - Slow query analysis
- `/debug` - Production debugging
- `/code-review` - Data verification (optional)

---

## Common Patterns by Use Case

| Use Case | Query Numbers | Skills |
|----------|---------------|--------|
| Security Audit | 1, 2, 3 | /security, /pci-compliance |
| Multi-Tenancy Check | 4, 5, 6, 7 | /multi-tenancy |
| Performance Debug | 8, 9, 10 | /performance |
| Production Debug | 11, 12, 13 | /debug |
| Data Verification | 14, 15 | /code-review, /migration |
| Analytics | 16, 17 | /architect (capacity planning) |

---

## References

- [Security Skill](../security/skill.md) - Security-specific queries
- [Multi-Tenancy Skill](../multi-tenancy/skill.md) - Facility scoping patterns
- [Performance Skill](../performance/skill.md) - Performance analysis
- [Debug Skill](../debug/skill.md) - Production debugging
- CLAUDE.md - ClickHouse section (if exists)
