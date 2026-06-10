# Rails Console Best Practices for Production

> **⚠️ Operations Guide**: This is for production console operations, not debugging workflow.
>
> For debugging workflow, see `/debug` skill.

## When to Use

When creating scripts for production Rails console to fix data, run migrations, or perform manual operations.

## ⚠️ CRITICAL Rules

When creating scripts for production Rails console, **ALWAYS** follow these rules:

### 1. Ruby 3 Syntax Compatibility

```ruby
# ❌ WRONG - Deprecated in Ruby 3
date.to_s(:db)
time.to_s(:db)

# ✅ CORRECT - Use strftime
date.strftime('%Y-%m-%d')
time.strftime('%Y-%m-%d %H:%M:%S')
```

### 2. Handle nil Values BEFORE Calling Methods

```ruby
# ❌ WRONG - Will crash if nil
starts = membership.acquired_at.strftime('%Y-%m-%d %H:%M:%S')

# ✅ CORRECT - Handle nil first
starts = membership.acquired_at ? membership.acquired_at.strftime('%Y-%m-%d %H:%M:%S') : Time.current.strftime('%Y-%m-%d %H:%M:%S')
```

### 3. Test Scripts in Docker BEFORE Sending to Production

```bash
# ALWAYS test locally first
docker compose exec web bundle exec rails runner "
  # Your script here
  puts 'Test output'
"
```

### 4. NEVER Use Heredocs in Rails Console

```ruby
# ❌ WRONG - Heredocs don't paste well in console
ActiveRecord::Base.connection.execute(<<-SQL)
  SELECT * FROM users
SQL

# ✅ CORRECT - Single line or concatenated strings
ActiveRecord::Base.connection.execute("SELECT * FROM users WHERE id = #{id}")
```

### 5. Skip Model Callbacks for Manual Data Fixes

```ruby
# ❌ WRONG - Triggers callbacks that may fail
MembershipPayment.create!(payment_id: 123, ...)

# ✅ CORRECT - Direct SQL for manual fixes
ActiveRecord::Base.connection.execute("INSERT INTO membership_payments (...) VALUES (...)")

# ✅ ALSO CORRECT - update_column skips callbacks
payment.update_column(:paid, true)
```

### 6. Provide Step-by-Step Commands

When giving commands for production, provide them **one at a time** so the user can:
- Copy/paste easily
- See the result of each step
- Abort if something goes wrong

## Common Patterns

### Safe Data Fix Pattern

```ruby
# 1. Load record
record = Model.find(id)

# 2. Verify current state
puts "Current state: #{record.attribute}"

# 3. Update (skip callbacks for manual fixes)
record.update_column(:attribute, new_value)

# 4. Verify change
puts "New state: #{record.reload.attribute}"
```

### Transaction-Safe Updates

```ruby
ActiveRecord::Base.transaction do
  # Multiple updates that must succeed together
  record1.update_column(:status, 'active')
  record2.update_column(:paid, true)

  # If any fails, all rollback
end
```

### Direct SQL for Bulk Operations

```ruby
# Faster than ActiveRecord for large batches
ActiveRecord::Base.connection.execute(
  "UPDATE users SET active = 1 WHERE created_at < '2024-01-01'"
)
```

## See Also

- `/debug` skill - For production debugging workflow
- [Membership Payment Fixes](membership-payment-fixes.md) - Domain-specific manual fixes
