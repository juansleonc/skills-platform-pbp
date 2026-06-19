# debug/reference/clickhouse-queries.md — ClickHouse Query Templates

> Relocated from SKILL.md (Step 1 + Step 3). Body keeps the decision rule "ClickHouse first";
> this file holds the copy-paste templates. ReplacingMergeTree DB tables REQUIRE `FINAL` before
> counting (plain `count()` inflates ~20x); the `logs` table does not.

---

## A. Logs-Table Queries (event streams)

### Investigate Events/Logs (extract IDs)

```sql
-- Template: Find events by pattern and extract IDs
SELECT
  timestamp,
  message,
  -- Extract resource IDs from logs (adjust regex to match your log format)
  extractAllGroups(message, 'payment_id[=:](\d+)')[1] as payment_id,
  extractAllGroups(message, 'user[=:](\d+)')[1] as user_id,
  extractAllGroups(message, 'facility[=:](\d+)')[1] as facility_id,
  extractAllGroups(message, '\[JobName ([a-f0-9]+)\]')[1] as job_id
FROM logs
WHERE
  message LIKE '%EVENT_PATTERN%'
  AND timestamp BETWEEN 'START_TIME' AND 'END_TIME'
ORDER BY timestamp ASC
```

Replace: `EVENT_PATTERN` (e.g. `payment_completed`, `UnifiedEventService`), `START_TIME`/`END_TIME`
(range from error report), regex (match your log format). You get: exact resource IDs,
millisecond-precision timestamps, full event sequence, pattern detection.

### Detect Duplicate Events (race conditions)

```sql
-- Detect resources processed multiple times (race condition detector)
WITH events AS (
  SELECT
    timestamp,
    extractAllGroups(message, 'payment_id[=:](\d+)')[1] as payment_id,
    extractAllGroups(message, 'user[=:](\d+)')[1] as user_id
  FROM logs
  WHERE
    message LIKE '%UnifiedEventService: Published payment_completed%'
    AND timestamp >= now() - INTERVAL 1 DAY
)
SELECT
  payment_id,
  count(*) as event_count,
  groupArray(user_id) as user_ids,
  groupArray(timestamp) as timestamps,
  arrayDifference(groupArray(toUnixTimestamp64Milli(timestamp))) as time_diffs_ms
FROM events
GROUP BY payment_id
HAVING event_count > 1  -- Only duplicates
ORDER BY event_count DESC
LIMIT 100
```

Interpretation: `event_count > 1` → processed multiple times; `time_diffs_ms` (67ms = retry,
5000ms = scheduled); different `user_ids` for same `payment_id` → logging context contamination.

```
payment_id | event_count | user_ids           | time_diffs_ms
39204765   | 2           | [2345633, 1479567] | [67]         ← Race condition!
39210123   | 2           | [1234567, 1234567] | [120]        ← Legitimate retry
```

### Find Related Events (one resource's lifecycle)

```sql
-- Find all events for a specific resource
SELECT
  timestamp,
  extractAllGroups(message, 'event_key[=:](\w+)')[1] as event_type,
  message
FROM logs
WHERE
  message LIKE '%payment_id=39204765%'
  AND timestamp >= now() - INTERVAL 7 DAY
ORDER BY timestamp ASC
```

Shows full lifecycle (created → completed → webhook sent), job executions, errors/retries.

---

## B. DB-Table Queries (state/records — `pbp_productionDB_optimized`, FINAL required)

### Find Affected Records

```sql
-- Find affected facilities
SELECT facility_id, count(*) as error_count
FROM pbp_productionDB_optimized.payments FINAL
WHERE status = 'failed' AND created_at > now() - INTERVAL 7 DAY
GROUP BY facility_id
ORDER BY error_count DESC;

-- Find pattern in failed operations
SELECT user_id, facility_id, created_at, error_message
FROM pbp_productionDB_optimized.<table> FINAL
WHERE <condition> AND created_at BETWEEN '<start>' AND '<end>'
ORDER BY created_at DESC
LIMIT 100;
```

### Check Data Integrity

```sql
-- Find orphaned records
SELECT count(*)
FROM pbp_productionDB_optimized.reservations FINAL r
LEFT JOIN pbp_productionDB_optimized.users FINAL u ON r.user_id = u.id
WHERE u.id IS NULL;

-- Find NULL values that shouldn't exist
SELECT *
FROM pbp_productionDB_optimized.<table> FINAL
WHERE <required_column> IS NULL AND created_at > now() - INTERVAL 30 DAY;

-- Check for duplicate records
SELECT <unique_columns>, count(*) as count
FROM pbp_productionDB_optimized.<table> FINAL
GROUP BY <unique_columns>
HAVING count > 1;
```

---

## C. Timeline Analysis (when did it start?)

Two complementary sub-queries — pick by data source.

### (a) Logs table (for event streams)

```sql
-- Hourly breakdown of an event pattern
SELECT
  toStartOfHour(timestamp) as hour,
  count(*) as event_count,
  uniq(extractAllGroups(message, 'payment_id[=:](\d+)')[1]) as unique_payments
FROM logs
WHERE message LIKE '%payment_completed%'
  AND timestamp >= now() - INTERVAL 7 DAY
GROUP BY hour
ORDER BY hour DESC
```

### (b) DB table (for state/record data — FINAL required)

```sql
-- When did the issue start?
SELECT toStartOfHour(created_at) as hour, count(*) as count
FROM pbp_productionDB_optimized.<table> FINAL
WHERE <error_condition>
GROUP BY hour
ORDER BY hour;
```

Use either to identify: when errors started (deployment correlation), peak times (load), and
whether the error is ongoing or resolved.

---

## D. Worked Example — Real Debugging Session (payment_id=39204765)

Issue: two `payment_completed` events 67ms apart for facility 1067.

ClickHouse (one query, ~30 sec):

```sql
SELECT
  timestamp,
  extractAllGroups(message, 'payment_id[=:](\d+)')[1] as payment_id,
  extractAllGroups(message, 'user[=:](\d+)')[1] as user_id
FROM logs
WHERE message LIKE '%payment_completed%'
  AND message LIKE '%facility%1067%'
  AND timestamp BETWEEN '2026-02-11 14:41:00' AND '2026-02-11 14:42:00'
```

```
timestamp               | payment_id | user_id
2026-02-11 14:41:49.877 | 39204765   | 2345633
2026-02-11 14:41:49.944 | 39204765   | 1479567  ← Same payment_id!
```

Conclusion: race condition (same payment processed twice; bug in user_id logging). The Rails-console
path took 30 min and 10+ manual queries to reach the same answer — start with ClickHouse.
