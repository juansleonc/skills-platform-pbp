# Safe Script Pattern Library

Copy-ready patterns for safe runner scripts. Also folds in the "common mistakes"
that recur — each is the inverse of a pattern below.

## Pattern 1: Direct SQL for Callback-Skipping

Manual fixes should skip ActiveRecord callbacks/validations (they may themselves be
buggy or have side effects). Use `connection.execute` or `update_column`.

```ruby
# ❌ DANGEROUS - triggers callbacks that can fail
MembershipPayment.create!(payment_id: 123, membership_id: 456)
payment.update!(paid: true)   # runs validations + callbacks

# ✅ SAFE - direct SQL skips callbacks.
# #{payment_id}/#{membership_id} are trusted integer AR attributes (model.id).
# Interpolating guaranteed-integer AR values is acceptable in scripts (CLAUDE.local.md
# Rule #12). For external/user-supplied values, see Pattern 6.
ActiveRecord::Base.connection.execute(
  "INSERT INTO membership_payments (payment_id, membership_id, created_at, updated_at) " \
  "VALUES (#{payment_id}, #{membership_id}, NOW(), NOW())"
)

# ✅ SAFE - update_column skips callbacks/validations
payment.update_column(:paid, true)
```

## Pattern 2: Idempotent Operations

Scripts must be safe to run multiple times (retries, partial failures).

```ruby
# ❌ BAD - fails / duplicates if run twice
User.create!(email: 'new@example.com')
user.facilities << facility

# ✅ GOOD - idempotent
User.find_or_create_by!(email: 'new@example.com')
user.facilities << facility unless user.facilities.include?(facility)
```

## Pattern 3: Batch Processing

Never load large tables into memory; `find_each` batches (default 1000, tune with
`batch_size:`). Inverse mistake: `Model.all.each` → memory crash on 100k+ rows.

```ruby
# ❌ BAD - loads everything into memory
User.all.each { |u| fix_user(u) }

# ✅ GOOD - batched with progress
total = User.count
processed = 0
User.find_each(batch_size: 500) do |user|
  fix_user(user)
  processed += 1
  log "Progress: #{processed}/#{total}" if (processed % 100).zero?
end
```

## Pattern 4: Safe Date Handling

Defers to CLAUDE.local.md Rules #8 (Ruby-3 date formatting) and #9 (nil safety).
Single source of truth — do not restate the rationale here.

```ruby
# ❌ NEVER - Ruby 3 deprecated, and crashes if acquired_at is nil
starts = membership.acquired_at.to_s(:db)

# ✅ ALWAYS - strftime + nil guard (Rules #8/#9)
starts = membership.acquired_at&.strftime('%Y-%m-%d %H:%M:%S') ||
         Time.current.strftime('%Y-%m-%d %H:%M:%S')
```

## Pattern 5: Transaction with Explicit Rollback

Dry-run = make changes inside a transaction, then `raise ActiveRecord::Rollback`.

```ruby
ActiveRecord::Base.transaction do
  update_records
  raise ActiveRecord::Rollback if dry_run
end
```

`requires_new: true` does NOT unconditionally add a savepoint. It yields a real
`SAVEPOINT` **only when nested inside an existing (outer) transaction**; at the
outermost level it behaves as an ordinary transaction. Reach for it only when you
genuinely have nested transactions and want the inner one to roll back independently.

```ruby
# Only meaningful when already inside an outer transaction:
ActiveRecord::Base.transaction do          # outer
  ActiveRecord::Base.transaction(requires_new: true) do  # SAVEPOINT here
    update_records
    raise ActiveRecord::Rollback if dry_run   # rolls back to savepoint only
  end
end
```

## Pattern 6: SQL Injection Prevention

**The single coherent rule:**
- **Trusted integers** (AR model `.id`, `Integer()` cast on ARGV/CSV input, numeric
  literals) → `#{}` interpolation is **acceptable** in script context (CLAUDE.local.md
  Rule #12).
- **External/uncast strings** (ARGV without cast, CSV-parsed strings, ENV values, any
  user-supplied text) → **always use bind params or AR methods**. Never interpolate.

```ruby
# ❌ DANGEROUS - external string interpolated directly into SQL
user_id = ARGV[0]                  # String from command line, unvalidated
ActiveRecord::Base.connection.execute(
  "UPDATE users SET active = true WHERE id = #{user_id}"
)
# Risk: ARGV[0] = "1 OR 1=1" → full-table update

# ✅ SAFE - cast to Integer first (raises on non-integer, prevents injection)
user_id = Integer(ARGV[0])
ActiveRecord::Base.connection.execute(
  "UPDATE users SET active = true WHERE id = #{user_id}"
)

# ✅ SAFE - parameterized (always correct regardless of source)
ActiveRecord::Base.connection.execute(
  ActiveRecord::Base.sanitize_sql(['UPDATE users SET active = true WHERE id = ?', ARGV[0]])
)

# ✅ SAFEST - ActiveRecord methods, no raw SQL
User.where(id: ARGV[0]).update_all(active: true)
```
