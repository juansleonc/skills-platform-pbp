# Resilience — Worked Code Patterns

## Table of Contents
- [Pattern 1: HTTP Calls Must Have Timeouts and Error Handling](#pattern-1-http-calls-must-have-timeouts-and-error-handling)
- [Pattern 2: Payment Gateway Resilience (PBP-Specific)](#pattern-2-payment-gateway-resilience-pbp-specific)
- [Pattern 3: .save Without Checking Return Value](#pattern-3-save-without-checking-return-value)
- [Pattern 4: Background Job Resilience](#pattern-4-background-job-resilience)

---

### Pattern 1: HTTP Calls Must Have Timeouts and Error Handling

```ruby
# ❌ BAD - No timeout, no error handling (fire-and-forget)
def sync_data
  response = HTTParty.post("https://api.external.com/sync", body: data.to_json)
  process_response(response)
end

# ❌ BAD - Has rescue but swallows error silently
def sync_data
  HTTParty.post("https://api.external.com/sync", body: data.to_json)
rescue StandardError
  nil  # Silent failure — nobody knows it failed
end

# ✅ GOOD - Distinct open/read timeouts + specific rescue + logging + notification
# HTTParty (and Faraday / Net::HTTP) support open_timeout and read_timeout per-request.
# A generic `timeout:` covers both but distinct open/read is preferred — connection
# establishment should be tight (5s); response body may need more time (10s+).
def sync_data
  response = HTTParty.post(
    "https://api.external.com/sync",
    body: data.to_json,
    headers: { 'Content-Type' => 'application/json' },
    open_timeout: 5,   # connection establishment
    read_timeout: 10   # response body
  )

  unless response.success?
    Rails.logger.error("Sync failed: #{response.code} - #{response.body}")
    return false
  end

  process_response(response)
rescue Net::OpenTimeout, Net::ReadTimeout => e
  Rails.logger.error("Sync timeout: #{e.message}")
  Honeybadger.notify(e, context: { endpoint: "/sync" })
  false
rescue StandardError => e
  Rails.logger.error("Sync error: #{e.message}")
  Honeybadger.notify(e)
  false
end
```

### Pattern 2: Payment Gateway Resilience (PBP-Specific)

With 14 payment gateways, each can fail differently:

```ruby
# ❌ BAD - Generic rescue for payment operations
def charge(amount)
  gateway.charge(amount)
rescue => e
  # Which gateway? What kind of error? Was the charge applied?
  nil
end

# ✅ GOOD - Gateway-specific error handling with idempotency
def charge(amount)
  return if already_charged?(idempotency_key)

  result = gateway.charge(amount, idempotency_key: idempotency_key)
  record_charge(result)
  result
rescue gateway_timeout_error => e
  Rails.logger.error("Gateway timeout: #{gateway_name} - #{e.message}")
  Honeybadger.notify(e, context: { gateway: gateway_name, amount: amount })
  # DON'T retry automatically — charge may have gone through
  PaymentReconciliationJob.perform_in(5.minutes, { payment_id: payment.id })
  false
rescue gateway_declined_error => e
  record_decline(e)
  false
end
```

### Pattern 3: .save Without Checking Return Value

```ruby
# ❌ BAD - .save returns false on failure, but nobody checks
def update_membership
  membership.status = 'active'
  membership.save  # Silently fails if validation fails
end

# ✅ GOOD - Use bang or check return value
def update_membership
  membership.status = 'active'
  membership.save!  # Raises on failure
end

# ✅ ALSO GOOD - Check return value
def update_membership
  membership.status = 'active'
  unless membership.save
    Rails.logger.error("Failed to activate: #{membership.errors.full_messages}")
    return false
  end
  true
end
```

### Pattern 4: Background Job Resilience

> **Repo-specific (non-obvious — keep this):** `< ApplicationJob` (= `ActiveJob::Base`) CAN call `sidekiq_options` / `sidekiq_retries_exhausted` directly. Sidekiq 7.3.9's `sidekiq/rails.rb` does `include ::Sidekiq::Job::Options unless respond_to?(:sidekiq_options)` on `ActiveJob::Base` at boot — so no `include Sidekiq::Worker` is needed. Proof: `app/jobs/sync_match_job.rb` + ~18 other jobs run this in production. For broader ApplicationJob-vs-Worker mechanics, retry/throttle options, and the Ruby-3 hash-arg pattern, see `/sidekiq`.

```ruby
# ❌ BAD - Job fails silently, no retry strategy
class SyncContactsJob
  include Sidekiq::Worker

  def perform(args)
    args = args.deep_symbolize_keys
    contacts = ExternalApi.fetch_contacts(args[:facility_id])
    contacts.each { |c| Contact.create!(c) }
  end
end

# ✅ GOOD - Error handling, retry strategy, idempotency
class SyncContactsJob < ApplicationJob
  sidekiq_options retry: 3

  def perform(args)
    args = args.deep_symbolize_keys
    facility_id = args[:facility_id]

    contacts = ExternalApi.fetch_contacts(facility_id)
    contacts.each do |c|
      Contact.find_or_create_by!(external_id: c[:id]) do |contact|
        contact.assign_attributes(c.slice(:name, :email))
      end
    end
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("Sync timeout for facility #{facility_id}: #{e.message}")
    raise  # Let Sidekiq retry
  rescue StandardError => e
    ErrorService.new(e, context: { facility_id: facility_id }).notify
    raise  # Let Sidekiq retry
  end

  # Graceful degradation when all retries are exhausted (CRITICAL RULE #6 — must be observable)
  sidekiq_retries_exhausted do |job, ex|
    facility_id = job['args'].first&.dig('facility_id')
    Rails.logger.error("SyncContactsJob permanently failed for facility #{facility_id}: #{ex.message}")
    Honeybadger.notify(ex, context: { facility_id: facility_id, job: job['jid'] })
    # Optionally: enqueue a reconciliation job or page on-call
  end
end
```
