---
name: resilience
description: Validates error handling and resilience patterns for external service calls, HTTP requests, payment gateways, and background jobs. Detects fire-and-forget calls, missing timeouts, and silent failures.
allowed-tools: [Bash, Read, Grep, Glob, Edit, mcp__honeybadger__list_faults, mcp__honeybadger__get_fault]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## When to Use This Skill

Run this skill when:
- **Adding/modifying HTTP client calls** (HTTParty, Faraday, Net::HTTP, RestClient)
- **Integrating new external services** (payment gateways, email providers, webhooks)
- **Reviewing adapter code** in `app/adapters/` or API clients in `app/services/`
- **After Honeybadger alerts** about timeout or connection errors
- **Adding new payment gateway** (14 gateways — each must handle failures gracefully)

## Shared References

> **📚 This skill uses shared documentation. See:**
> - [Forbidden Patterns](../shared/forbidden-patterns.md) - bare rescue patterns

# Resilience Audit Skill

Validates that external service calls, HTTP requests, and background jobs handle failures gracefully. Prevents silent failures, cascading timeouts, and data corruption.

## CRITICAL RULES

1. **Every HTTP call MUST have a timeout** — default timeouts are too long (60s+)
2. **Every HTTP call MUST have error handling** — network errors are guaranteed to happen
3. **Never use bare rescue** — always rescue specific exceptions
4. **Never swallow errors silently** — log, notify, or re-raise
5. **Payment operations MUST be idempotent** — retries are inevitable with 14 gateways

## Quick Validation Commands

**Run these first for a fast overview:**

```bash
# 1. HTTP calls without rescue blocks - CRITICAL
grep -rn "HTTParty\.\|Faraday\.\|Net::HTTP\.\|RestClient\.\|URI\.open\|open-uri" app/ --include="*.rb" | grep -v "spec\|test"
# Then check each match has a surrounding rescue block
```
**Expected**: Every HTTP call should be inside a begin/rescue block

```bash
# 2. HTTP calls without explicit timeout - HIGH RISK
grep -rn "HTTParty\.\(get\|post\|put\|delete\|patch\)" app/ --include="*.rb" | grep -v "timeout\|Timeout"
grep -rn "Faraday\.new\|Faraday\.\(get\|post\)" app/ --include="*.rb" | grep -v "timeout"
```
**Expected**: 0 NEW occurrences in changed lines. Legacy baseline (2026-06-10): 17 HTTParty matches, 21 Faraday matches — pre-existing, do not introduce more.

```bash
# 3. Silent error swallowing - HIGH RISK
grep -rn "rescue.*nil$\|rescue.*; end\|rescue.*=> e$" app/ --include="*.rb" -A1 | grep -v "log\|raise\|notify\|Honeybadger\|ErrorService"
```
**Expected**: 0 NEW occurrences in changed lines. Legacy baseline (2026-06-10): ~1060 pipeline-output lines (multi-file, noisy grep) — do not introduce new silent rescues.

```bash
# 4. Bare rescue / rescue Exception - MEDIUM RISK
grep -rn "rescue\s*$" app/ --include="*.rb"
grep -rn "rescue Exception" app/ --include="*.rb" | grep -v "# rubocop"
```
**Expected**: 0 NEW occurrences in changed lines. Legacy baseline (2026-06-10): 19 bare-rescue matches, 0 `rescue Exception` matches.

```bash
# 5. .save without bang or return value check - MEDIUM RISK
grep -rn "\.save$\|\.save " app/services/ app/jobs/ --include="*.rb" | grep -v "save!\|\.save(" | grep -v "#\|if\|unless\|&&\|\|\|"
```
**Expected**: Minimal matches. Use `.save!` or check return value: `if record.save`

```bash
# 6. Fire-and-forget external calls in sync context - HIGH RISK
grep -rn "HTTParty\.\|Faraday\.\|RestClient\." app/controllers/ app/models/ --include="*.rb" | grep -v "rescue\|begin\|async\|job\|worker"
```
**Expected**: External calls in controllers/models should be in background jobs or have rescue blocks

## Detailed Patterns

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

# ✅ GOOD - Timeout + specific rescue + logging + notification
def sync_data
  response = HTTParty.post(
    "https://api.external.com/sync",
    body: data.to_json,
    headers: { 'Content-Type' => 'application/json' },
    timeout: 10  # 10 second timeout
  )

  unless response.success?
    Rails.logger.error("Sync failed: #{response.code} - #{response.body}")
    return false
  end

  process_response(response)
rescue Net::OpenTimeout, Net::ReadTimeout => e
  Rails.logger.error("Sync timeout: #{e.message}")
  Honeybadger.notify(e, context: { url: url })
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

```ruby
# ❌ BAD - Job fails silently, no retry strategy
class SyncContactsJob < ApplicationJob
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
end
```

## PBP-Specific: External Services to Audit

| Service | Location | Risk Level |
|---------|----------|------------|
| 14 Payment Gateways | `app/services/payment_service/` | CRITICAL |
| Patch API (contacts) | `app/adapters/patch_adapter/` | HIGH |
| Playsight cameras | `packs/camera_integrations/` | MEDIUM |
| Webhook deliveries | `packs/webhooks/` | HIGH |
| Email delivery | `app/mailers/` | MEDIUM |
| SMS consent/opt-in | `app/services/sms_consent_phone_change_invalidator.rb`, `app/graphql/features/sms/` | MEDIUM |
| OpenSearch indexing | `app/models/concerns/*_searchable.rb` (e.g. `user_searchable.rb`, `facility_searchable.rb`) | MEDIUM |

```bash
# Audit all adapters for resilience
grep -rn "HTTParty\.\|Faraday\.\|Net::HTTP\.\|RestClient\." app/adapters/ app/services/payment_service/ packs/webhooks/ packs/camera_integrations/ --include="*.rb"
# Then verify each has: timeout, rescue, logging
```

## Audit Process

### Step 1: Find All External Calls

```bash
# List all files with HTTP calls
grep -rln "HTTParty\|Faraday\|Net::HTTP\|RestClient\|URI\.open" app/ --include="*.rb" | grep -v spec
```

### Step 2: Validate Each External Call

For each file found, check:

1. **Timeout configured?** — grep for `timeout` near HTTP call
2. **Rescue block present?** — grep for `rescue` in same method
3. **Specific exceptions rescued?** — not bare `rescue` or `rescue Exception`
4. **Error logged or notified?** — grep for `logger`, `Honeybadger`, `ErrorService`
5. **Return value handled?** — caller checks for failure

### Step 3: Check Honeybadger for Recurring Issues

```
mcp__honeybadger__list_faults:
  project_id: <project_id>
  q: "timeout OR connection OR Net::OpenTimeout OR Errno::ECONNREFUSED"
```

### Step 4: Generate Report

## Report Format

```markdown
## Resilience Audit

### Summary
- External calls found: X
- Missing timeouts: Y
- Missing error handling: Z
- Silent failures: W

### Critical Issues (Must Fix)

| File | Line | Issue | Risk |
|------|------|-------|------|
| patch/contacts.rb | 45 | No timeout on API call | Cascading timeout |
| stripe_gateway.rb | 112 | Silent rescue nil | Lost payment data |

### Warning Issues (Should Fix)

| File | Line | Issue | Risk |
|------|------|-------|------|
| webhook_sender.rb | 67 | Bare rescue | Masks real errors |
| sms_service.rb | 34 | .save without check | Silent failures |

### Recommendations
1. Add 10s timeout to all HTTParty calls in app/adapters/
2. Replace rescue nil with proper error logging
3. Add idempotency keys to payment retry logic
```

---

## Related Skills

This skill works with:
- **`/security`** - Bare rescue can hide security issues
- **`/performance`** - Missing timeouts cause cascading slowdowns
- **`/sidekiq`** - Job error handling and retry patterns
- **`/gateway-consistency`** - Payment gateway error handling across 14 implementations
- **`/rails-audit`** - Orchestrates resilience as part of full audit

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover a new pattern or heuristic, append it to [`kaizen_log.md`](kaizen_log.md) (sibling file). Promote durable rules into the active SKILL.md body. Log history is in that file — not inline here.
