# Performance Optimization Workflow

> ⚡ **Systematic performance optimization using N+1 detection + ClickHouse + Benchmarking**

## Command

```bash
/orchestrate performance-optimize
```

## Overview

Performance optimization workflow:
- Parallel analysis (N+1 + ClickHouse + Honeybadger)
- Bottleneck identification and prioritization
- TDD-based optimization (benchmark first)
- Verification of improvements

**Time**: 30-40min average
**Risk**: MEDIUM (changes can affect behavior)
**Critical**: ALWAYS benchmark before/after

## Workflow Diagram

```
┌─ PARALLEL (Performance Analysis) ─────────────────┐
│  ├── performance: N+1, indexes, memory            │
│  │    → N+1 query detection                       │
│  │    → Missing includes/preload                  │
│  │    → Index requirements                        │
│  │    → Memory usage analysis                     │
│  │                                                 │
│  ├── ClickHouse: Query production data patterns   │
│  │    → Slow query log analysis                   │
│  │    → Query execution times                     │
│  │    → Table sizes and growth                    │
│  │    → Lock duration analysis                    │
│  │                                                 │
│  └── Honeybadger: Check for timeout errors        │
│       → Timeout fault analysis                    │
│       → Frequency and patterns                    │
│       → Affected endpoints                        │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (Identify Bottlenecks) ───────────────┐
│  Prioritize by impact: queries, loops, memory     │
│    → Sort by: Execution time × frequency          │
│    → Calculate ROI: Performance gain / Effort     │
│    → Select top 3 bottlenecks                     │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (TDD Optimization) ───────────────────┐
│  tdd: Benchmark tests → optimize → verify         │
│    → RED: Write benchmark test (current speed)    │
│    → GREEN: Optimize code                         │
│    → REFACTOR: Verify speed improvement           │
│    → COVERAGE: Ensure 100% maintained             │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Verification) ─────────────────────────┐
│  ├── performance: Re-verify improvements          │
│  │    → Benchmark shows ≥50% improvement          │
│  │    → No new N+1 queries introduced             │
│  │                                                 │
│  ├── coverage: Verify 100%                        │
│  │    → Coverage maintained on optimized code     │
│  │                                                 │
│  └── code-review: Verify no regressions           │
│       → Behavior unchanged (tests pass)           │
│       → No new complexity introduced              │
└───────────────────────────────────────────────────┘
```

## Phase Details

### Phase 1: Performance Analysis (Parallel)

#### 1.1 N+1 Detection

**Skill**: `/performance`

**What It Checks**:
```ruby
# ❌ N+1 Query (1 + N queries)
users.each { |u| u.memberships.count }

# ✅ Optimized (2 queries)
users.includes(:memberships).each { |u| u.memberships.count }
```

**Time**: 3-4min

---

#### 1.2 ClickHouse Analysis

**Production Data Queries**:
```sql
-- Find slowest queries
SELECT
  query_pattern,
  AVG(execution_time_ms) as avg_time,
  COUNT(*) as executions
FROM query_logs
WHERE timestamp > NOW() - INTERVAL 7 DAY
GROUP BY query_pattern
HAVING AVG(execution_time_ms) > 1000
ORDER BY avg_time * executions DESC
LIMIT 10;

-- Check table sizes (for index planning)
SELECT
  table_name,
  formatReadableSize(sum(bytes)) as size,
  sum(rows) as row_count
FROM system.parts
WHERE database = 'pbp_productionDB_optimized'
GROUP BY table_name
ORDER BY sum(bytes) DESC
LIMIT 10;
```

**Time**: 3-4min

---

#### 1.3 Honeybadger Timeout Analysis

**Fault Query**:
```bash
mcp__honeybadger__list_faults:
  project_id: 12345
  order: "frequent"
  q: "timeout"

# Returns:
# - Timeout frequency
# - Affected endpoints
# - User impact
```

**Time**: 2-3min

---

### Phase 2: Identify Bottlenecks

**Prioritization Formula**:
```
Impact = (avg_time_ms × executions_per_day) / 1000
Effort = 1 (easy), 3 (medium), 5 (hard)
ROI = Impact / Effort

Priority = ROI (highest first)
```

**Example**:
```markdown
## Bottlenecks (Sorted by ROI)

1. **User.search N+1** (ROI: 150)
   - Impact: 450 (3000ms × 150 calls/day)
   - Effort: 3 (add includes)
   - Expected: 3000ms → 50ms (98% faster)

2. **Reservation index missing** (ROI: 80)
   - Impact: 400 (2000ms × 200 calls/day)
   - Effort: 5 (migration + deploy)
   - Expected: 2000ms → 10ms (99.5% faster)

3. **Payment gateway timeout** (ROI: 30)
   - Impact: 90 (6000ms × 15 calls/day)
   - Effort: 3 (add retry logic)
   - Expected: Reduce timeouts by 80%
```

**Time**: 3-5min

---

### Phase 3: TDD Optimization

**Benchmark Pattern**:
```ruby
# spec/performance/user_search_spec.rb
require 'benchmark'

describe 'User search performance' do
  let!(:users) { create_list(:user, 100) }

  it 'completes search in <100ms' do
    time = Benchmark.realtime do
      User.search('john')
    end

    expect(time).to be < 0.1  # 100ms
  end

  it 'executes ≤5 queries' do
    expect {
      User.search('john')
    }.to make_database_queries(count: 5, maximum: true)
  end
end
```

**Optimization**:
```ruby
# BEFORE (N+1)
def self.search(query)
  where("name LIKE ?", "%#{query}%")
end

# After includes added but still called without includes
users = User.search('john')
users.each { |u| u.memberships.count }  # N+1

# AFTER (optimized)
def self.search(query)
  includes(:memberships)
    .where("name LIKE ?", "%#{query}%")
end

# Now no N+1
users = User.search('john')
users.each { |u| u.memberships.count }  # No extra queries
```

**Time**: 15-20min

---

### Phase 4: Verification

Re-run benchmarks:
```ruby
# Before: 3000ms, 153 queries
# After: 50ms, 3 queries
# Improvement: 98% faster, 98% fewer queries ✅
```

**Time**: 5-8min

---

## Common Optimizations

### 1. N+1 Queries

**Fix**:
```ruby
# ❌ BEFORE
users.each { |u| u.memberships.count }

# ✅ AFTER
users.includes(:memberships).each { |u| u.memberships.count }
```

---

### 2. Missing Indexes

**Fix**:
```ruby
# Migration
add_index :reservations, :user_id
add_index :reservations, [:facility_id, :status]
```

---

### 3. Large Array Loading

**Fix**:
```ruby
# ❌ BEFORE
Membership.all.map(&:user_id)  # Loads all into memory

# ✅ AFTER
Membership.pluck(:user_id)  # Database-level operation
```

---

### 4. Batch Processing

**Fix**:
```ruby
# ❌ BEFORE
User.all.each { |u| process(u) }  # Memory explosion

# ✅ AFTER
User.find_in_batches(batch_size: 1000) do |batch|
  batch.each { |u| process(u) }
end
```

---

## Success Criteria

**ALL must pass**:
- ✅ Benchmark improvement ≥50%
- ✅ Query count reduced significantly
- ✅ Tests still pass (behavior unchanged)
- ✅ Coverage maintained (100%)
- ✅ No new N+1 introduced

## Time Estimates

| Phase | Duration | Notes |
|-------|----------|-------|
| Analysis (parallel) | 8-12min | N+1 + ClickHouse + Honeybadger |
| Bottlenecks | 3-5min | Prioritize top 3 |
| Optimization | 15-20min | TDD with benchmarks |
| Verification (parallel) | 5-8min | Re-run checks |
| **Total** | **30-45min** | Avg 37min |

## Best Practices

**DO** ✅:
- Benchmark before/after (prove improvement)
- Use ClickHouse for production patterns
- Fix highest ROI bottlenecks first
- Maintain test coverage
- Verify no regressions

**DON'T** ❌:
- Optimize without benchmarking
- Introduce N+1 in fix attempts
- Skip test coverage verification
- Optimize everything (diminishing returns)

## Related Workflows

- **Before optimization**: `/orchestrate code-review` (identify issues)
- **After optimization**: `/orchestrate pre-commit` (final check)
- **For refactoring**: `/orchestrate refactor` (code structure)

---

**Back to**: [orchestrate skill](../SKILL.md) | [quick reference](../quick_reference.md) | [workflows index](README.md)
