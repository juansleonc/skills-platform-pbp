# Audit Steps — worked ❌/✅ code

The SKILL.md body keeps the step checklist + grep commands + decision notes.
The worked before/after code for each step lives here (verbatim).

## Step 2: Detect N+1 Queries

```ruby
# ❌ N+1 - Loading associations in loop
users = User.all
users.each do |user|
  puts user.facility.name  # N+1! Queries facility for each user
end

# ✅ FIXED - Eager loading
users = User.includes(:facility).all
users.each do |user|
  puts user.facility.name  # No additional queries
end
```

> N+1 in GraphQL resolvers (preload / dataloader): see Step 6 (GraphQL Performance).

## Step 4: Detect Memory Issues

```ruby
# ❌ BAD - Loads all records into memory
users = User.all.to_a
users.each { |u| process(u) }  # 100k users = 100k objects in memory!

# ✅ GOOD - Batched processing
User.find_each(batch_size: 1000) do |user|
  process(user)  # Only 1000 objects at a time
end

# ❌ BAD - Large array in memory
ids = User.pluck(:id)  # 100k IDs in array

# ✅ GOOD - Iterator
User.in_batches(of: 1000).each_record do |user|
  # Process
end
```

> String building in loops: see Ruby vs SQL Antipatterns #5 (String Concatenation).

## Step 5: Check Query Efficiency

```ruby
# ❌ BAD - Select all columns
User.where(active: true).each { |u| puts u.email }

# ✅ GOOD - Pluck only needed columns
User.where(active: true).pluck(:email).each { |email| puts email }

# ❌ BAD - Count with loaded records
users = User.all
users.count  # Loads ALL records just to count!

# ✅ GOOD - Database count
User.count  # SELECT COUNT(*) FROM users
```

> Existence checks: see Ruby vs SQL Antipatterns #3 (.exists?).

## Step 6: GraphQL Performance

```ruby
# ❌ BAD - No lookahead for associations
class UserType < Types::BaseObject
  field :reservations, [ReservationType], null: false

  def reservations
    object.reservations  # N+1 if multiple users requested!
  end
end

# ✅ GOOD - Use dataloader
class UserType < Types::BaseObject
  field :reservations, [ReservationType], null: false

  def reservations
    dataloader.with(Sources::Reservations).load(object.id)
  end
end

# ✅ GOOD - Deferred for heavy operations
field :analytics_data, resolver: AnalyticsResolver do
  extension GraphQL::Pro::Defer
end
```

## Step 7: Sidekiq Job Performance

```ruby
# ❌ BAD - Processing all in one job
def perform(args)
  User.all.each do |user|  # Huge memory, timeout risk!
    process_user(user)
  end
end

# ✅ GOOD - Batch into smaller jobs
def perform(args)
  User.in_batches(of: 100).each do |batch|
    batch.pluck(:id).each do |user_id|
      ProcessUserJob.perform_async({ user_id: user_id })
    end
  end
end
```
