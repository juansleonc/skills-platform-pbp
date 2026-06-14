---
name: migration
description: Validates database migrations for safety, rollback capability, index optimization, and production impact. Prevents data loss and downtime.
allowed-tools: [Bash, Read, Grep, Glob, Edit, mcp__clickhouse__run_query, mcp__clickhouse__list_tables]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

# Database Migration Safety Skill

Validates migrations for safety with **1029+ existing migrations** (935 main + 94 packs). Prevents data loss, downtime, and production issues.

## CRITICAL RULES

1. **ALWAYS reversible** - Must have `down` method or use `change`
2. **NEVER drop columns without backup** - Data loss is permanent
3. **ALWAYS add indexes** for foreign keys and frequently queried columns
4. **MySQL 8.0/InnoDB (this codebase):** `ADD INDEX` is online by default (ALGORITHM=INPLACE, LOCK=NONE) — plain `add_index` is non-blocking for reads/writes in most cases. The real locking danger is ALGORITHM=COPY operations: changing column type, charset/collation, or reordering columns on large tables. Use `pt-online-schema-change`/`gh-ost` or coordinate a maintenance window for those.
5. **ALWAYS set defaults** for NOT NULL columns

## Audit Process

### Step 1: Find New Migrations

```bash
# Find new migration files
git diff develop --name-only -- db/migrate/

# Show migration content
git diff develop -- db/migrate/
```

### Step 2: Check Reversibility

```ruby
# ✅ GOOD - Reversible with change
class AddEmailToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :email, :string
  end
end

# ✅ GOOD - Explicit up/down
class ComplexMigration < ActiveRecord::Migration[6.1]
  def up
    add_column :users, :status, :integer, default: 0
  end

  def down
    remove_column :users, :status
  end
end

# ❌ BAD - Irreversible without down
class DropUsersTable < ActiveRecord::Migration[6.1]
  def up
    drop_table :users
  end
  # Missing down method!
end
```

```bash
# Find potentially irreversible migrations
grep -rn "drop_table\|remove_column\|execute" db/migrate/*.rb | grep -v "def down"
```

### Step 3: Check Index Safety

**MySQL 8.0/InnoDB (this codebase):** `ADD INDEX` runs online by default (ALGORITHM=INPLACE, LOCK=NONE), meaning it does NOT block reads or writes for standard `add_index` calls. The PostgreSQL-specific options `algorithm: :concurrently` and `disable_ddl_transaction!` are **not valid on MySQL** — they raise `ArgumentError` and must never be used here.

```ruby
# ✅ GOOD - Plain add_index is online/non-blocking on MySQL 8.0 InnoDB
class AddIndexToUsers < ActiveRecord::Migration[6.1]
  def change
    add_index :users, :email
  end
end

# ❌ BAD - PostgreSQL-only; raises ArgumentError on MySQL (mysql2 gem)
class AddIndexToUsers < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!  # NO-OP at best, error at worst on MySQL

  def change
    add_index :users, :email, algorithm: :concurrently  # ArgumentError on MySQL!
  end
end
```

**Real locking risks on MySQL 8.0 InnoDB (ALGORITHM=COPY — needs care on large tables):**
- Changing a column's data type (e.g. `change_column :t, :c, :text` → `:mediumtext`)
- Changing charset or collation on a column or table
- Reordering columns
- Adding a column with a non-metadata-only default on older MySQL versions

For these operations on large tables (millions of rows), consider:
- `pt-online-schema-change` (Percona) or `gh-ost` (GitHub) for zero-downtime ALTERs
- Coordinating a low-traffic maintenance window
- Check `ALGORITHM=INPLACE` compatibility in the [MySQL 8.0 online DDL docs](https://dev.mysql.com/doc/refman/8.0/en/innodb-online-ddl-operations.html) before running

```bash
# Find column type or charset changes that may trigger ALGORITHM=COPY
grep -rn "change_column\|change_column_default" db/migrate/*.rb
```

### Step 4: Check NULL Safety

```ruby
# ✅ GOOD - Default for NOT NULL
add_column :users, :active, :boolean, null: false, default: true

# ✅ GOOD - Backfill then add constraint
def up
  add_column :users, :active, :boolean
  User.update_all(active: true)
  change_column_null :users, :active, false
end

# ❌ BAD - NOT NULL without default on existing table
add_column :users, :active, :boolean, null: false  # Fails if table has data!
```

### Step 5: Check Foreign Keys

```ruby
# ✅ GOOD - Foreign key with index
add_reference :reservations, :facility, foreign_key: true, index: true

# ✅ GOOD - Manual FK with index
add_column :reservations, :facility_id, :bigint
add_index :reservations, :facility_id
add_foreign_key :reservations, :facilities

# ❌ BAD - FK without index (slow joins)
add_column :reservations, :facility_id, :bigint
add_foreign_key :reservations, :facilities
# Missing index!
```

### Step 6: Check Large Table Operations

For tables with millions of rows:

```ruby
# ✅ GOOD - Batched backfill
def up
  User.in_batches(of: 1000) do |batch|
    batch.update_all(status: 'active')
  end
end

# ❌ BAD - Full table update (locks, memory)
def up
  User.update_all(status: 'active')  # Dangerous on large tables!
end
```

### Step 7: Verify in ClickHouse (Production Data)

```sql
-- Check table size before migration
SELECT
  table,
  formatReadableSize(sum(bytes_on_disk)) as size,
  sum(rows) as row_count
FROM system.parts
WHERE database = 'pbp_productionDB_optimized'
  AND table = '<table_name>'
GROUP BY table;

-- Check if column exists
SELECT column_name, data_type
FROM system.columns
WHERE database = 'pbp_productionDB_optimized'
AND table = '<table_name>'
AND column_name = '<column_name>';

-- Check NULL values before adding NOT NULL
SELECT count(*) as null_count
FROM pbp_productionDB_optimized.<table>
WHERE <column> IS NULL;
```

## Package Table Naming (CRITICAL)

All package tables MUST be prefixed:

| Package | Table Prefix |
|---------|--------------|
| webhooks | `webhooks_` |
| audit_logs | `audit_logs_` |
| feature_flag | `feature_flag_` |
| game_match | `game_match_` |
| book_a_pro | `book_a_pro_` |
| orgs | `orgs_` |

```bash
# Verify package table naming
grep -rn "create_table" packs/*/db/migrate/ | grep -v "create_table :\w\+_"
```

### Step 8: Check for Model References in Migrations (Anti-Pattern)

Using ActiveRecord models directly in migrations is dangerous — the model may change after the migration is written, causing failures when running old migrations.

```bash
# Find model references in migrations - ANTI-PATTERN
grep -rn "User\.\|Facility\.\|Membership\.\|Reservation\.\|Payment\.\|Court\." db/migrate/ --include="*.rb" | grep -v "#\|class\|def\|end"
```
**Expected**: 0 matches (use raw SQL or define minimal model class inside migration)

```ruby
# ❌ BAD - Model reference in migration (will break if model changes)
class BackfillUserStatus < ActiveRecord::Migration[6.1]
  def up
    User.where(status: nil).update_all(status: 'active')
    # Breaks if User model adds validation/callback later
  end
end

# ✅ GOOD - Raw SQL (stable regardless of model changes)
class BackfillUserStatus < ActiveRecord::Migration[6.1]
  def up
    execute "UPDATE users SET status = 'active' WHERE status IS NULL"
  end
end

# ✅ GOOD - Define minimal class inside migration
class BackfillUserStatus < ActiveRecord::Migration[6.1]
  class User < ApplicationRecord
    self.table_name = 'users'
  end

  def up
    User.where(status: nil).update_all(status: 'active')
  end
end
```

### Step 9: Check for Modified Committed Migrations

```bash
# Find migrations that were modified after being committed
git diff develop --name-only -- db/migrate/ | while read f; do
  if git log develop --oneline -- "$f" | head -1 | grep -q .; then
    echo "⚠️ MODIFIED COMMITTED MIGRATION: $f"
  fi
done
```
**Expected**: 0 matches (never modify a migration that's been committed — create a new one)

### Step 10: Check for Missing reset_column_information

When a migration adds a column and then uses it in the same migration, `reset_column_information` is needed.

```bash
# Find add_column followed by model use without reset_column_information
grep -l "add_column" db/migrate/*.rb | xargs grep -L "reset_column_information" | while read f; do
  if grep -q "update_all\|find_each\|where\|update(" "$f"; then
    echo "⚠️ MISSING reset_column_information: $f"
  fi
done
```
**Expected**: 0 matches (always call `Model.reset_column_information` between DDL and DML)

```ruby
# ❌ BAD - Column not visible to model yet
def up
  add_column :users, :verified, :boolean, default: false
  User.where(role: 'admin').update_all(verified: true)
  # May silently fail — ActiveRecord doesn't know about 'verified' yet
end

# ✅ GOOD - Reset column info between DDL and DML
def up
  add_column :users, :verified, :boolean, default: false
  User.reset_column_information
  User.where(role: 'admin').update_all(verified: true)
end
```

## Migration Checklist

- [ ] Reversible (has down method or uses change)
- [ ] Indexes added for foreign keys
- [ ] MySQL 8.0/InnoDB: plain `add_index` is online — no `algorithm: :concurrently` needed (raises ArgumentError on MySQL)
- [ ] Column type/charset/collation changes on large tables use `pt-online-schema-change`/`gh-ost` or maintenance window (ALGORITHM=COPY risk)
- [ ] NOT NULL columns have default values
- [ ] Large table updates use batching
- [ ] Package tables use correct prefix
- [ ] No data loss operations without backup

## Report Format

```markdown
## Migration Safety Audit

### Summary
- Migrations analyzed: X
- Safety issues: Y
- Recommendations: Z

### Safety Issues (BLOCKING)

| Migration | Issue | Risk | Fix |
|-----------|-------|------|-----|
| 20240120_add_status.rb | NOT NULL without default | HIGH | Add default value |
| 20240121_change_column.rb | Column type change on large table (ALGORITHM=COPY) | MEDIUM | Use pt-online-schema-change or maintenance window |

### Table Impact Analysis

| Table | Rows (prod) | Size | Lock Risk |
|-------|-------------|------|-----------|
| users | 2.5M | 1.2GB | HIGH |
| reservations | 15M | 8GB | CRITICAL |

### Index Recommendations

| Table | Column | Reason |
|-------|--------|--------|
| reservations | facility_id | FK without index |

### Rollback Plan
1. Migration X: `remove_column :users, :new_column`
2. Migration Y: `drop_index :users, :email`
```

## Example

```
Claude detects new migration:

## Migration Safety Audit

### Analyzing: 20240122_add_verified_to_users.rb

```ruby
class AddVerifiedToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :verified, :boolean, null: false, default: false
    add_index :users, :verified
  end
end
```

### ClickHouse Check
Users table: 2.5M rows, 1.2GB

### Issues Found

✅ NOTE: Index creation on 2.5M-row table
- MySQL 8.0/InnoDB: `add_index` runs ALGORITHM=INPLACE, LOCK=NONE by default — non-blocking for reads/writes.
- No changes needed for index creation specifically.
- The `algorithm: :concurrently` + `disable_ddl_transaction!` pattern is **PostgreSQL-only** and raises `ArgumentError` on this MySQL codebase — do NOT apply it.

### Verified Safe (MySQL 8.0/InnoDB)

```ruby
# ✅ Correct for this MySQL 8.0 codebase — online DDL, no table lock
class AddVerifiedToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :verified, :boolean, null: false, default: false
    add_index :users, :verified
  end
end
```

### Result: SAFE to merge (MySQL 8.0/InnoDB online DDL confirmed)
```

---

## Continuous Improvement

If you discover a new migration safety pattern, missing check, or better ClickHouse query while executing this skill: complete the audit first, then run `/kaizen`. Do NOT self-edit this file mid-execution.

> Improvement log: [kaizen_log.md](kaizen_log.md)
