# Sidekiq Job — Code Examples

Verbatim skeletons and before/after pairs. The decision logic lives in `../SKILL.md`; this file holds the long code blocks only.

## Correct Job Pattern (canonical basic-job skeleton)

```ruby
class ProcessPaymentJob < ApplicationJob
  queue_as :payments

  def perform(args)
    # 1. Deep symbolize keys first
    args = args.deep_symbolize_keys
    return unless args.is_a?(Hash)

    # 2. Extract and validate required params
    facility_id = args[:facility_id]
    payment_id = args[:payment_id]
    idempotency_key = args[:idempotency_key]

    return if facility_id.blank? || payment_id.blank?

    # 3. Check idempotency BEFORE processing
    return if already_processed?(idempotency_key)

    # 4. Initialize variables BEFORE try block
    facility = nil
    payment = nil
    result = nil

    begin
      facility = Facility.find(facility_id)
      payment = facility.payments.find(payment_id)

      # Process with transaction
      ActiveRecord::Base.transaction do
        result = PaymentService::Base.process(payment)
        mark_as_processed(idempotency_key)
      end
    rescue ActiveRecord::RecordNotFound => e
      # Variables accessible here for logging
      Rails.logger.error("Payment job failed: facility=#{facility_id}, payment=#{payment_id}")
      ErrorService.new(e, context: { facility_id: facility_id, payment_id: payment_id }).notify
    rescue => e
      ErrorService.new(e, context: args).notify
      raise # Re-raise for Sidekiq retry
    end
  end

  private

  def already_processed?(key)
    return false if key.blank?
    Rails.cache.exist?("payment:processed:#{key}")
  end

  def mark_as_processed(key)
    return if key.blank?
    Rails.cache.write("payment:processed:#{key}", true, expires_in: 24.hours)
  end
end
```

## Anemic Job — ❌ / ✅ pair

```ruby
# ❌ ANEMIC JOB — adds nothing
class ActivateUserJob < ApplicationJob
  def perform(args)
    args = args.deep_symbolize_keys
    User.find(args[:user_id]).activate!
  end
end

# ✅ JUSTIFIED JOB — adds retry, error handling, idempotency
class ActivateUserJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3

  def perform(args)
    args = args.deep_symbolize_keys
    user_id = args[:user_id]
    idempotency_key = args[:idempotency_key] || "activate:#{user_id}"

    return if already_processed?(idempotency_key)

    user = nil
    begin
      user = User.find(user_id)
      user.activate!
      mark_as_processed(idempotency_key)
    rescue ActiveRecord::RecordNotFound
      Rails.logger.warn("ActivateUserJob: User #{user_id} not found")
    rescue => e
      ErrorService.new(e, context: { user_id: user_id }).notify
      raise
    end
  end
end
```

## Ruby 3 Migration — Before / After

### Before: Multiple Arguments (Ruby 2.x)
```ruby
class ProcessPaymentJob < ApplicationJob
  def perform(payment_id, facility_id, user_id)
    # Old pattern - breaks in Ruby 3
  end
end

# Invocation
ProcessPaymentJob.perform_async(payment.id, facility.id, user.id)
```

### After: Single Hash Argument (Ruby 3)
```ruby
class ProcessPaymentJob < ApplicationJob
  def perform(args)
    args = args.deep_symbolize_keys
    return unless args.is_a?(Hash)

    payment_id = args[:payment_id]
    facility_id = args[:facility_id]
    user_id = args[:user_id]

    # Process with hash pattern
  end
end

# Invocation
ProcessPaymentJob.perform_async({
  payment_id: payment.id,
  facility_id: facility.id,
  user_id: user.id
})
```

**Migration steps**:
1. Change `def perform(arg1, arg2, ...)` → `def perform(args)`
2. Add `args = args.deep_symbolize_keys` first line
3. Extract values: `arg1 = args[:arg1]`
4. Update all invocations to pass hash: `perform_async({ key: value })`

## Forbidden Patterns (full annotated block)

```ruby
# ❌ FORBIDDEN: Multiple arguments
def perform(user_id, facility_id, options)
end

# ❌ FORBIDDEN: Missing deep_symbolize_keys
def perform(args)
  user_id = args[:user_id]  # May fail with string keys
end

# ❌ FORBIDDEN: Variables not initialized before try
def perform(args)
  begin
    user = User.find(args[:user_id])
  rescue => e
    # user is undefined here!
    Rails.logger.error("Failed for #{user.email}")  # ERROR!
  end
end

# ❌ FORBIDDEN: Payment without idempotency
def perform(args)
  args = args.deep_symbolize_keys
  payment = Payment.find(args[:payment_id])
  PaymentService.process(payment)  # Could double-charge!
end
```

## Error Reporting with ErrorService — patterns

**ALWAYS use `ErrorService` instead of separate `Rails.logger.error` + `Honeybadger.notify`.** It provides centralized Rails.logger logging, Sentry integration with user context, Honeybadger notification with sanitized context, and automatic parameter filtering (secrets, passwords).

### Pattern: Real Exception
```ruby
rescue => e
  ErrorService.new(e, user: user, context: { facility_id: facility_id }).notify
  raise # Re-raise for Sidekiq retry
end
```

### Pattern: Error Condition Without Exception
```ruby
# When you need to report an error state (not a caught exception)
if payment.nil?
  ErrorService.new(
    StandardError.new("[JobName] Descriptive error message"),
    context: { record_id: record_id, relevant_state: some_value }
  ).notify
  return
end
```

### ❌ FORBIDDEN: Separate Logger + Honeybadger
```ruby
# ❌ DON'T DO THIS
Rails.logger.error("Error message")
Honeybadger.notify("Error", context: { ... })

# ✅ DO THIS INSTEAD
ErrorService.new(StandardError.new("Error message"), context: { ... }).notify
```

### Context-rich error reporting (debugging)
```ruby
rescue => e
  ErrorService.new(e,
    user: user,
    context: {
      job_class: self.class.name,
      args: args.except(:sensitive_data),
      attempt: retry_count + 1,
      facility_id: facility_id
    }
  ).notify
  raise
end
```
