# Database Migration Workflow

> 🗄️ **Safe database schema changes with comprehensive validation**

## Command

```bash
/orchestrate migration
```

## Overview

Comprehensive workflow for database schema changes:
- Safety validation (rollback, data loss prevention)
- Index optimization analysis
- Table naming convention enforcement (Packwerk)
- Production impact assessment (ClickHouse)
- Migration testing (up/down cycles)

**Time**: 15-20min average
**Risk**: HIGH (can cause downtime or data loss if not validated)
**Critical**: ALWAYS test rollback before production

## Workflow Diagram

```
┌─ SEQUENTIAL (Safety Check) ───────────────────────┐
│  migration: Validate safety, indexes, rollback    │
│    → Data loss risk analysis                      │
│    → Rollback safety (reversible?)                │
│    → Index requirements                           │
│    → Lock duration estimate                       │
│    → Production impact assessment                 │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Impact Analysis) ──────────────────────┐
│  Run 3 independent validators concurrently:       │
│                                                    │
│  ├── performance: Check index requirements        │
│  │    → Missing indexes identified                │
│  │    → Index size estimates                      │
│  │    → Query performance impact                  │
│  │                                                 │
│  ├── packwerk: Verify table naming convention     │
│  │    → Package prefix required (e.g. webhooks_)  │
│  │    → Package boundary validation               │
│  │    → Cross-package references                  │
│  │                                                 │
│  └── ClickHouse: Check table sizes                │
│       → Current row counts                        │
│       → Estimated migration time                  │
│       → Downtime risk assessment                  │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (TDD) ────────────────────────────────┐
│  tdd: Test migration up/down                      │
│    → Run migration up                             │
│    → Verify schema changes                        │
│    → Run migration down                           │
│    → Verify rollback complete                     │
│    → Run migration up again                       │
│    → Test with data                               │
└───────────────────────────────────────────────────┘
                        ↓
┌─ STOP - Ready for User Commit ───────────────────┐
│  🚫 orchestrate CANNOT create commits             │
│  ✅ Tell user: "Migration validated and safe"     │
│  📝 Tell user: "Run /commit when ready"           │
│  ⚠️ Critical: Test in staging before production   │
│  ⚠️ Plan downtime if table lock > 5 seconds       │
└───────────────────────────────────────────────────┘
```

## Why Migration-Specific Workflow?

**High Risk**:
- Can cause production downtime
- Risk of data loss if not reversible
- Large table migrations can lock for minutes
- Bad indexes = slow queries forever

**Complex Validation**:
- Must verify rollback works (not all changes are reversible)
- Need production data size to estimate time
- Package naming conventions must be followed
- Index requirements depend on query patterns

**Production Impact**:
- Migrations on large tables (>1M rows) need careful planning
- Must estimate lock duration
- Need downtime window if lock > 5 seconds

## Phase Details

### Phase 1: Safety Check (Sequential)

**Goal**: Prevent data loss and ensure rollback safety

**Skill Used**: `/migration`

**What It Validates**:

#### 1.1 Data Loss Risk
| Change Type | Risk | Validation |
|-------------|------|------------|
| Add column | Low | Safe (nullable or with default) |
| Add index | Low | Safe (can take time on large tables) |
| Remove column | **HIGH** | ❌ Data lost if rollback |
| Rename column | Medium | Need data migration |
| Change type | **HIGH** | Need conversion logic |
| Add NOT NULL | Medium | Need default or backfill |

**Example Validation**:
```ruby
# ❌ UNSAFE - Data loss on rollback
def change
  remove_column :users, :legacy_email
end

# ✅ SAFE - Can rollback
def up
  add_column :users, :new_email, :string
end

def down
  remove_column :users, :new_email
end
```

---

#### 1.2 Rollback Safety
- ✅ REVERSIBLE: Migration has both `up` and `down`
- ✅ SAFE: `down` doesn't lose data
- ❌ IRREVERSIBLE: One-way migration (requires manual rollback plan)

---

#### 1.3 Index Requirements
```sql
-- Check if index needed for query patterns
-- Example: Adding user_id column
-- → Need index on user_id for lookups

-- Check if unique constraint appropriate
-- Example: email column
-- → Add unique index if emails must be unique
```

---

#### 1.4 Lock Duration Estimate
| Operation | Lock Type | Duration |
|-----------|-----------|----------|
| Add column (nullable) | Low | <1s |
| Add index | Medium | ~1s per 100K rows |
| Add foreign key | High | ~2s per 100K rows |
| Rename table | Very High | Instant but blocks all queries |

**ClickHouse Query**:
```sql
-- Get table size for lock estimate
SELECT
  table,
  formatReadableSize(sum(bytes)) as size,
  sum(rows) as row_count
FROM system.parts
WHERE database = 'pbp_productionDB_optimized'
  AND table = 'reservations'
GROUP BY table;
```

**Example**:
- Table has 500K rows
- Adding index = ~5 seconds lock
- **Action**: Schedule during low-traffic window

---

**Time**: 5-7min

**Pass Criteria**:
- No data loss risk OR documented migration plan
- Rollback tested and works
- Indexes appropriate

---

### Phase 2: Impact Analysis (Parallel - 3 Validators)

All 3 run simultaneously:

#### 2.1 Performance Analysis

**Skill**: `/performance`

**What It Checks**:
- Missing indexes on foreign keys
- Index size estimates
- Query performance impact

**Example**:
```ruby
# Migration adds user_id column
add_column :reservations, :user_id, :bigint

# Performance validator suggests:
# ⚠️ MISSING: Index on reservations(user_id)
# Add this:
add_index :reservations, :user_id
```

**Time**: 2-3min

---

#### 2.2 Packwerk Table Naming

**Skill**: `/packwerk`

**What It Validates**:
- Package tables have package prefix
- Example: `webhooks_urls` (NOT `urls`)
- Cross-package references documented

**Example Violations**:
```ruby
# ❌ BAD - Webhooks package table without prefix
create_table :event_logs do |t|
  # ...
end

# ✅ GOOD - Proper package prefix
create_table :webhooks_event_logs do |t|
  # ...
end
```

**Pass Criteria**:
- App tables: No prefix required
- Pack tables: Package prefix mandatory

**Time**: 1-2min

---

#### 2.3 ClickHouse Production Data

**Skill**: ClickHouse queries

**What It Checks**:
- Current table size (row count, disk size)
- Estimated migration time
- Downtime risk assessment

**Example Query**:
```sql
-- Get table stats
SELECT
  count(*) as rows,
  formatReadableSize(sum(bytes)) as size
FROM pbp_productionDB_optimized.reservations;

-- Result: 2.5M rows, 8.2 GB
-- Estimated: Adding index = ~25 seconds lock
-- Recommendation: Schedule maintenance window
```

**Time**: 2-3min

---

**Total Phase 2 Time**: ~3-5min (parallel)

---

### Phase 3: TDD (Sequential - Migration Testing)

**Goal**: Verify migration works AND rollback works

**Critical Pattern**: UP → DOWN → UP

```bash
# Step 1: Run migration up
docker compose exec -e RAILS_ENV=test web bundle exec rails db:migrate

# Step 2: Verify schema changes
docker compose exec -e RAILS_ENV=test web bundle exec rails db:schema:dump
# Check db/structure.sql has new column/index

# Step 3: Run migration down (rollback)
docker compose exec -e RAILS_ENV=test web bundle exec rails db:migrate:down VERSION=20260126123456

# Step 4: Verify rollback complete
docker compose exec -e RAILS_ENV=test web bundle exec rails db:schema:dump
# Check db/structure.sql reverted

# Step 5: Run migration up again
docker compose exec -e RAILS_ENV=test web bundle exec rails db:migrate

# Step 6: Test with data
docker compose exec -e RAILS_ENV=test web bundle exec rails runner "
  User.create!(name: 'Test', email: 'test@example.com')
  # Verify new column accessible
"
```

**Test Cases**:
```ruby
# spec/db/migrate/add_email_to_users_spec.rb
describe 'AddEmailToUsers migration' do
  it 'adds email column' do
    migrate(:up)
    expect(User.column_names).to include('email')
  end

  it 'removes email column on rollback' do
    migrate(:up)
    migrate(:down)
    expect(User.column_names).not_to include('email')
  end

  it 'can run up again after rollback' do
    migrate(:up)
    migrate(:down)
    expect { migrate(:up) }.not_to raise_error
  end

  it 'preserves data on rollback (if applicable)' do
    migrate(:up)
    user = User.create!(email: 'test@example.com')
    migrate(:down)
    migrate(:up)
    # Verify user still exists (if migration preserves data)
  end
end
```

**Time**: 5-8min

**Pass Criteria**:
- ✅ Migration up succeeds
- ✅ Schema changes present
- ✅ Migration down succeeds
- ✅ Schema reverted
- ✅ Migration up again succeeds
- ✅ Data operations work

---

## When to Use

✅ **Use this workflow for**:
- Adding/removing columns
- Adding/removing indexes
- Creating/dropping tables
- Changing column types
- Adding foreign keys
- Renaming columns/tables

❌ **Don't use for**:
- Data-only changes (use rake task, not migration)
- Config changes
- Seed data

## Success Criteria

**ALL checks must pass**:
- ✅ No data loss risk (or documented plan)
- ✅ Rollback tested and works
- ✅ Indexes appropriate (no missing, no unnecessary)
- ✅ Package naming conventions followed
- ✅ Production impact assessed
- ✅ Up/down/up cycle passes

**If ANY fail**: Fix migration before committing

## Time Estimates

| Phase | Duration | Notes |
|-------|----------|-------|
| Safety Check | 5-7min | Data loss + rollback analysis |
| Impact (parallel) | 3-5min | Performance + Packwerk + ClickHouse |
| TDD Testing | 5-8min | Up/down/up cycle + data tests |
| **Total** | **15-20min** | Avg 17min |

## Common Migration Issues

### 1. Irreversible Operations

**Problem**:
```ruby
def change
  remove_column :users, :legacy_id # Data lost on rollback
end
```

**Solution**:
```ruby
def up
  # Document that rollback loses data
  remove_column :users, :legacy_id
end

def down
  # Best effort: Re-add column (but data gone)
  add_column :users, :legacy_id, :integer
  # Note: Original data not recoverable
end
```

---

### 2. Missing Indexes

**Problem**:
```ruby
add_column :reservations, :user_id, :bigint
# Missing: Index on user_id (slow lookups)
```

**Solution**:
```ruby
add_column :reservations, :user_id, :bigint
add_index :reservations, :user_id # Add index
```

---

### 3. Long Table Locks

**Problem**:
- Adding index to 5M row table
- Lock duration: ~50 seconds
- Production queries blocked

**Solution**:
```ruby
# Use concurrent index (PostgreSQL/MySQL 8+)
add_index :reservations, :user_id, algorithm: :concurrently
# Note: Requires separate migration, can't use in transaction
```

OR schedule maintenance window

---

### 4. Package Naming Violations

**Problem**:
```ruby
# In webhooks pack
create_table :event_types do |t|
  # Missing package prefix
end
```

**Solution**:
```ruby
create_table :webhooks_event_types do |t|
  # Proper package prefix
end
```

---

### 5. NOT NULL Without Default

**Problem**:
```ruby
add_column :users, :role, :string, null: false
# Fails on existing users (role is NULL)
```

**Solution**:
```ruby
# Step 1: Add nullable column with default
add_column :users, :role, :string, default: 'member'

# Step 2 (separate migration): Backfill data
User.where(role: nil).update_all(role: 'member')

# Step 3 (separate migration): Add NOT NULL
change_column_null :users, :role, false
```

---

## Best Practices

**DO** ✅:
- Always test rollback (down) before production
- Add indexes on foreign keys
- Use separate migrations for data changes
- Check production table sizes before index operations
- Follow Packwerk naming for pack tables
- Document irreversible migrations
- Use `change_column_null` for NOT NULL constraints

**DON'T** ❌:
- Remove columns without testing rollback
- Skip index on foreign keys (causes slow queries)
- Mix schema + data changes in one migration
- Add NOT NULL without default/backfill
- Rename tables without downtime plan
- Ignore lock duration on large tables

## Example Session

```markdown
## Migration Workflow: Add user_id to reservations

### Phase 1: Safety Check
✅ No data loss (adding column only)
✅ Rollback safe (can remove column)
⚠️ SUGGESTION: Add index on user_id
✅ Lock duration: <1s (add nullable column)

### Phase 2: Impact Analysis (Parallel)
✅ performance: Suggests index on user_id
✅ packwerk: App table (no prefix required)
✅ ClickHouse: 500K rows, ~1s lock estimate

### Phase 3: TDD Testing
✅ Migration up: Column added
✅ Schema dump: user_id present
✅ Migration down: Column removed
✅ Migration up again: Successful
✅ Data test: Can set user_id

✅ Migration validated and safe
📝 Ready to commit
⚠️ Reminder: Test in staging first

Total Time: 16min
```

## Production Deployment Checklist

Before deploying migration to production:

- [ ] Tested in development (up/down/up)
- [ ] Tested in staging with production-like data size
- [ ] Reviewed ClickHouse table sizes
- [ ] Estimated lock duration acceptable (<5s) OR maintenance window scheduled
- [ ] Indexes added for all foreign keys
- [ ] Rollback plan documented
- [ ] Team notified if downtime expected
- [ ] Monitoring dashboard ready (watch for slow queries)

## Related Workflows

- **After migration**: `/orchestrate pre-commit` (validate changes)
- **If complex**: `/orchestrate architect` (design first)
- **If slow**: `/orchestrate performance-optimize` (optimize queries)

---

**Back to**: [orchestrate skill](../SKILL.md) | [quick reference](../quick_reference.md) | [workflows index](README.md)
