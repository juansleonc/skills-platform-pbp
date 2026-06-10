# Membership Payment Manual Fixes

> **⚠️ Operations Guide**: This is for manual troubleshooting, not code validation.
>
> For code validation, see `/memberships` skill.

## When to Use

When a Payment exists but the MembershipPayment was deleted or never created.

## Investigation Steps

```sql
-- 1. Find the membership for the user at the facility
SELECT membership_id, user_id, facility_id, aasm_state
FROM pbp_core_prod.memberships_historic
WHERE user_id = <user_id> AND facility_id = <facility_id>
  AND _peerdb_is_deleted = 0;

-- 2. Check if MembershipPayment exists for that membership
SELECT id, payment_id, membership_id, state, created_at
FROM pbp_productionDB_optimized.membership_payments
WHERE membership_id = <membership_id>
  AND _peerdb_is_deleted = 0;

-- 3. Check if MembershipPayment exists in MySQL (may be deleted)
-- In Rails console:
MembershipPayment.unscoped.find_by(id: <id>)
ActiveRecord::Base.connection.execute("SELECT * FROM membership_payments WHERE id = <id>").to_a
```

## Fix Pattern (Direct SQL - Skips Callbacks)

**IMPORTANT**: MembershipPayment has callbacks that call `process_payment` which will fail.
ALWAYS use direct SQL for manual fixes.

```ruby
# Step 1: Load references
payment = Payment.find(<payment_id>)
membership = Membership.find(<membership_id>)

# Step 2: Verify state
puts "Payment paid: #{payment.paid}"
puts "MPs count: #{membership.membership_payments.count}"

# Step 3: Prepare dates (handle nil!)
now = Time.current.strftime('%Y-%m-%d %H:%M:%S')
starts = membership.acquired_at ? membership.acquired_at.strftime('%Y-%m-%d %H:%M:%S') : now
ends_at = membership.current_period_end_at ? membership.current_period_end_at.strftime('%Y-%m-%d %H:%M:%S') : (Time.current + 1.year).strftime('%Y-%m-%d %H:%M:%S')

# Step 4: INSERT (direct SQL, no callbacks)
ActiveRecord::Base.connection.execute("INSERT INTO membership_payments (payment_id, membership_id, state, starts_at, ends_at, origin, payment_required, created_at, updated_at) VALUES (#{payment.id}, #{membership.id}, 'payment_success', '#{starts}', '#{ends_at}', 'manual_fix', 0, '#{now}', '#{now}')")

# Step 5: Get created ID
mp_id = ActiveRecord::Base.connection.execute("SELECT LAST_INSERT_ID()").first[0]
puts "MembershipPayment creado: #{mp_id}"

# Step 6: UPDATE payment (direct SQL, no callbacks)
ActiveRecord::Base.connection.execute("UPDATE payments SET paid = 1 WHERE id = #{payment.id}")

# Step 7: UPDATE membership (CRITICAL - required for refunds to work!)
mp = MembershipPayment.find(mp_id)
membership.update_column(:current_period_end_at, mp.ends_at)
membership.update_column(:aasm_state, 'active') if membership.aasm_state == 'idle'

# Step 8: Verify
puts "Payment paid: #{Payment.find(payment.id).paid}"
puts "MPs count: #{MembershipPayment.where(membership_id: membership.id).count}"
puts "Membership current_period_end_at: #{membership.reload.current_period_end_at}"
puts "Membership aasm_state: #{membership.aasm_state}"
```

## ⚠️ Common Pitfalls

1. **`to_s(:db)` is deprecated** - Use `strftime('%Y-%m-%d %H:%M:%S')`
2. **`current_period_end_at` may be nil** - Always check before calling strftime
3. **Heredocs don't work in console** - Use single-line SQL strings
4. **`create!` triggers callbacks** - Use direct SQL for MembershipPayment fixes
5. **Membership must be updated too** - `current_period_end_at` and `aasm_state` must match the MembershipPayment, otherwise refunds will fail with "Error while processing total refund"

## See Also

- `/memberships` skill - For code validation
- `/debug` skill - For production debugging workflow
