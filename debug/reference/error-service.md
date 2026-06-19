# debug/reference/error-service.md — ErrorService Usage

> Relocated from SKILL.md. Body keeps the rule "always report via ErrorService, never raw
> Logger + Honeybadger"; this file holds the patterns and the anti-pattern.

When implementing fixes, ALWAYS use `ErrorService` for error reporting.

```ruby
# Location: app/services/error_service.rb
ErrorService.new(exception, user: user, context: { ... }).notify
```

Benefits: logs to `Rails.logger.error`; reports to Sentry with user context; reports to Honeybadger
with sanitized context; automatic parameter filtering (passwords, secrets).

## Pattern: Real Exception

```ruby
rescue => e
  ErrorService.new(e, user: current_user, context: {
    facility_id: facility.id,
    operation: 'process_payment'
  }).notify
  raise
end
```

## Pattern: Error Condition Without Exception

```ruby
# When reporting an error state (not a caught exception)
if membership_payment.nil?
  ErrorService.new(
    StandardError.new("[ServiceName] Descriptive error message"),
    context: {
      membership_id: membership.id,
      current_state: membership.status
    }
  ).notify
  return
end
```

## ❌ AVOID: Separate Logger + Honeybadger

```ruby
# ❌ Old pattern - don't use
Rails.logger.error("Error occurred: #{error}")
Honeybadger.notify(error, context: { ... })

# ✅ Use ErrorService instead
ErrorService.new(error, context: { ... }).notify
```
