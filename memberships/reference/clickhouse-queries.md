# Membership ClickHouse Query Catalog (L3 reference)

> ⚠️ `memberships` and `membership_payments` replicate as `*ReplacingMergeTree` —
> ALWAYS use `FINAL` (or counts inflate ~20×). See /query-analyzer CRITICAL rule #6.
> CH replica column names match MySQL: `aasm_state`, `current_period_end_at`,
> `membership_payments` (NOT `status`/`expires_at`/`membership_transactions`).
> Tool: `mcp__clickhouse__run_query`.

```sql
-- State distribution (aasm_state, NOT status)
SELECT
  aasm_state,
  count() as total,
  round(count() * 100.0 / sum(count()) OVER (), 2) as pct
FROM pbp_productionDB_optimized.memberships FINAL
GROUP BY aasm_state
ORDER BY total DESC;

-- Active memberships past their period end (should have renewed but didn't)
-- No auto_renew / facility_id / status column — join membership_plan_prices for automatic_renewal
SELECT m.id, m.owner_id, m.aasm_state, m.current_period_end_at
FROM pbp_productionDB_optimized.memberships FINAL AS m
WHERE m.aasm_state = 'active'
  AND m.current_period_end_at < now() - INTERVAL 1 DAY
  AND m.deleted_at IS NULL
LIMIT 100;

-- Renewal success rate (membership_payments, not membership_transactions)
SELECT state, count() as total_renewals
FROM pbp_productionDB_optimized.membership_payments FINAL
WHERE origin = 'automatic_generation'
  AND created_at > now() - INTERVAL 7 DAY
GROUP BY state
ORDER BY total_renewals DESC;

-- Count of problematic active-past-period-end memberships
SELECT count() as problematic
FROM pbp_productionDB_optimized.memberships FINAL
WHERE aasm_state = 'active'
  AND current_period_end_at < now()
  AND deleted_at IS NULL;

-- Upcoming renewals by current_period_end_at (NOT next_payment_date)
SELECT toDate(current_period_end_at) as renewal_date, count() as memberships
FROM pbp_productionDB_optimized.memberships FINAL
WHERE aasm_state = 'active'
  AND deleted_at IS NULL
GROUP BY renewal_date
ORDER BY renewal_date
LIMIT 30;

-- Failed membership payments (membership_payments has no direct facility_id —
-- join to memberships/plans if facility breakdown is needed)
SELECT mp.state, count() as count
FROM pbp_productionDB_optimized.membership_payments FINAL AS mp
WHERE mp.state IN ('payment_failed', 'failed')
  AND mp.created_at > now() - INTERVAL 30 DAY
GROUP BY mp.state
ORDER BY count DESC
LIMIT 20;
```

## Honeybadger (related errors)
- `mcp__honeybadger__list_faults` — search for "membership" or "renewal"
- `mcp__honeybadger__get_fault` — details of a specific membership/renewal fault
