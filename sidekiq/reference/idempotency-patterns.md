# Idempotency Patterns — Mechanism Code

The decision table + one-line summary live in `../SKILL.md`. This file holds the full code per mechanism.

## Repo locking convention (verified 2026-06-15)

- **`sidekiq-unique-jobs` (8.0.11, in Gemfile.lock)** is the codebase's real concurrency-control
  mechanism. Used via `sidekiq_options lock: :until_executed, lock_ttl: <seconds>` (also
  `lock: :while_executing`). Proof sites: `app/jobs/sync_match_job.rb`,
  `app/jobs/publish_unified_payment_event_job.rb`, `app/jobs/automatic_renewal_membership_job.rb`,
  `packs/billing/app/jobs/billing/cx_slack_notification_job.rb`,
  `packs/marketing_kit/app/jobs/announcements_deliver_job.rb`.
- **`Redis.current` is DEAD** — removed in redis-rb 5.x; this repo runs redis 5.4.1 and uses
  `Redis.current` nowhere. Do NOT paste it; it raises `NoMethodError`.
- **For hand-rolled locks**, use the Sidekiq 7 pooled connection accessor `Sidekiq.redis { |conn| ... }`,
  or a dedicated named `Redis.new(...)` constant (the pattern used in
  `config/initializers/redis_web_sockets.rb` and `graphql_subscriptions_redis.rb`).

```ruby
# REPO CONVENTION (first choice): sidekiq-unique-jobs — declarative, no hand-rolled Redis.
class SyncMatchJob < ApplicationJob
  sidekiq_options lock: :until_executed, lock_ttl: 5.minutes.to_i
  # ...two enqueues with the same args collapse to one execution.
end
```

## Mechanism examples

```ruby
# STATE-BASED (batch jobs): filter + double-check against DB state
# – No Redis needed. Re-running is always safe.
def activate_memberships_for_facility(facility_id)
  facility = Facility.find_by(id: facility_id)
  return unless facility

  Membership.where(aasm_state: 'idle', facility_id: facility_id)
    .find_each do |membership|
      next if membership.aasm_state != 'idle'  # double-check (idempotent)
      membership.start!
    rescue StandardError => e
      ErrorService.new(e, context: { membership_id: membership.id, facility_id: facility_id }).notify
    end
end

# CACHE-BASED (external calls / email / webhooks): idempotency_key in args
# – Use when DB state alone can't tell if the side-effect already occurred.
def perform(args)
  args = args.deep_symbolize_keys
  return unless args.is_a?(Hash)

  key  = args[:idempotency_key] || "#{self.class.name}:#{args[:record_id]}"

  return if Rails.cache.exist?("processed:#{key}")

  result = yield_work(args)   # external call, mailer, webhook delivery…

  Rails.cache.write("processed:#{key}", true, expires_in: 24.hours)
rescue StandardError => e
  ErrorService.new(e, context: args).notify
  raise
end

# REDIS LOCK (concurrent-sensitive, finer-grained than sidekiq-unique-jobs):
# one worker at a time per record. Use the Sidekiq 7 pooled connection.
def perform(args)
  args     = args.deep_symbolize_keys
  return unless args.is_a?(Hash)

  lock_key = "lock:#{self.class.name}:#{args[:payment_id]}"

  acquired = Sidekiq.redis { |conn| conn.set(lock_key, 1, nx: true, ex: 300) }
  return unless acquired

  begin
    process_payment(args)
  ensure
    Sidekiq.redis { |conn| conn.del(lock_key) }
  end
end
```

## Redlock (NOT currently available — requires adding the gem)

> ⚠️ `redlock` is **NOT in Gemfile.lock**. The block below is unavailable in this repo as-is; it
> would require adding the `redlock` gem AND a live multi-node Redis topology. Prefer
> `sidekiq-unique-jobs` (already present) for distributed locking unless you have a proven need for
> Redlock's multi-node quorum guarantee.

```ruby
# REDLOCK (distributed / multi-node) — only after adding the redlock gem:
# lock_manager = Redlock::Client.new([Redis.new(url: ENV["REDIS_URL"])])
# lock_manager.lock(lock_key, 5_000) { |locked| return unless locked; process(args) }
```

## Invocation

```ruby
# perform_async (Sidekiq native)
ProcessPaymentJob.perform_async({ payment_id: payment.id, facility_id: facility.id,
                                  idempotency_key: SecureRandom.uuid })
# perform_later (ActiveJob wrapper)
SendEmailJob.perform_later(user_id: user.id, template: 'welcome')
```

## Idempotency validation pattern (combined lock + cache)

```ruby
def perform(args)
  args = args.deep_symbolize_keys
  key = args[:idempotency_key] || generate_idempotency_key(args)

  # 1. Check first
  return if already_processed?(key)

  # 2. Acquire lock (Sidekiq 7 pooled connection — NOT Redis.current)
  lock_key = "lock:#{self.class.name}:#{key}"
  return unless Sidekiq.redis { |conn| conn.set(lock_key, 1, nx: true, ex: 300) }

  begin
    ActiveRecord::Base.transaction do
      # 3. Process
      result = process_payment(args)

      # 4. Mark as processed (inside transaction)
      mark_as_processed(key) if result.success?
    end
  ensure
    Sidekiq.redis { |conn| conn.del(lock_key) }
  end
end
```
