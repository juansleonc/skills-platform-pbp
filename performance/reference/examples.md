# Performance Skill — Worked & Illustrative Examples

> **Reference (L3)** for `../SKILL.md`. These are teaching examples only.
> **NOT sourced from real files or line numbers in this codebase.** Any file paths
> shown are placeholders; metrics (timings, memory figures) are hypothetical to
> illustrate the pattern, NOT measured production data. Do not cite as evidence.

---

## Illustrative anti-pattern catalog

### EXAMPLE 1: N+1 query in admin dashboard

```ruby
# ❌ BAD - Eager loading missing
def index
  @facilities = Facility.where(active: true)
end
# View iterates and calls facility.owner / facility.courts.count — N+1 queries

# ✅ GOOD - Eager load associations
def index
  @facilities = Facility.where(active: true)
                       .includes(:owner, :courts, :memberships)
end
```

Note: `app/controllers/admin/facilities_controller.rb` does not exist at HEAD
(only `organizations_controller.rb` and `sso_approvals_controller.rb` are in
`app/controllers/admin/`).

### EXAMPLE 2: Missing index on a frequently-queried foreign key

```ruby
# ❌ BAD - No index on a high-cardinality FK
create_table "some_table" do |t|
  t.integer "facility_id"
  t.string "status"
  # NO INDEX on facility_id
end

# ✅ GOOD - Composite index matches common query
add_index :some_table, [:facility_id, :status]
```

Note on `reservations`: The actual `reservations` table uses `court_id` (not
`facility_id`) — facility is reached via court. Any index recommendation must
match the actual schema column.

### EXAMPLE 3: Memory bloat in export job

```ruby
# ❌ BAD - Loads all records into memory at once
def perform(args)
  users = Facility.find(args[:facility_id]).users.all.to_a
  # 100k users → OOM risk
end

# ✅ GOOD - Batch with find_each
def perform(args)
  Facility.find(args[:facility_id]).users.find_each(batch_size: 1000) do |user|
    # At most 1000 objects in memory
  end
end
```

Note: `app/jobs/export_users_job.rb` does not exist at HEAD.

### EXAMPLE 4: GraphQL N+1 in mobile app

```ruby
# ❌ BAD - Loads courts per-facility without eager loading
def courts
  object.courts
end

# ✅ GOOD - Use dataloader or preloaded includes
def courts
  dataloader.with(Sources::Courts).load(object.id)
end
```

Note: `app/graphql/types/facility_type.rb` does not exist at HEAD (the
`app/graphql/types/` directory contains only base classes and scalar types;
domain types are located elsewhere in the codebase).

### EXAMPLE 5: Ruby-side count instead of SQL COUNT

```ruby
# ❌ BAD - Loads all records just to count them
facility.memberships.where(status: 'active').to_a.count

# ✅ GOOD - Let the database count
facility.memberships.where(status: 'active').count  # SELECT COUNT(*)
```

Note: `app/services/dashboard_service.rb` does not exist at HEAD (there is
`packs/internal_backend/app/services/internal/reports/dashboard_service.rb`).

---

## Worked example: N+1 in a controller

This is an end-to-end walkthrough of how the audit reads. The file path is a
placeholder; no fabricated production timings are included.

```
Claude detects model/service changes:

## Performance Audit

### Scanning: app/controllers/admin/example_controller.rb
(placeholder path — illustrative only, not a real file at HEAD)

### N+1 Query Detected!

```ruby
# Line 23
def index
  @users = User.where(active: true)
end

# Line in view: users/_user.html.erb
<%= user.facility.name %>
<%= user.memberships.count %>
```

This will cause N+1 queries for:
- `facility` association (1 query per user)
- `memberships` association (1 query per user)

With 100 users = 201 queries instead of 3!

### Fix

```ruby
def index
  @users = User.where(active: true)
              .includes(:facility, :memberships)
end
```

### Result: PERFORMANCE FIX NEEDED
```

> For production row-count / volume context to size the impact, use the
> ClickHouse FINAL row-count queries in `../SKILL.md` Step 8. For real endpoint
> timings, use New Relic — do NOT invent before/after millisecond figures.
