# Critical Rules

Project-wide rules that MUST be followed in all code. Violations cause bugs, security issues, or production failures.

## 1. Timezone Safety

**Rule**: NEVER use `Time.now`, `Date.today`, or `DateTime.now`

**Why**: PayByCourt is a multi-tenant application with facilities in different timezones. Using `Time.now` ignores the application timezone and causes bugs.

### Always Use

```ruby
# ✅ CORRECT - Timezone-aware
Time.current          # Current time in application timezone
Date.current          # Current date in application timezone
Time.zone.parse(str)  # Parse with timezone
Time.zone.local(...)  # Create with timezone

# ✅ CORRECT - Facility-specific
facility.local_time   # Current time in facility's timezone
facility.local_date   # Current date in facility's timezone
```

### Never Use

```ruby
# ❌ FORBIDDEN - Ignores timezone
Time.now
Date.today
DateTime.now
Time.new
Time.parse(str)       # Parses without timezone context
```

**Impact**:
- Wrong times displayed to users
- Incorrect reservation calculations
- Billing errors (charging wrong dates)
- Failed integrations (timezone-sensitive APIs)

**Detection**: Run `/timezone` skill to audit codebase

**Related**:
- [Forbidden Patterns](./forbidden-patterns.md#4-timenow--datetoday--datetimenow)
- [Testing Patterns](./testing-patterns.md#time-dependent-testing)
- CLAUDE.md "Critical Rules #1"

---

## 2. Multi-Tenancy (Facility Scoping)

**Rule**: ALWAYS scope queries by `facility_id` unless explicitly needing global/franchise scope

**Why**: Data leakage between facilities is a critical security violation. One facility's users should NEVER see another facility's data.

### Always Scope

```ruby
# ✅ CORRECT - Scoped to facility
@reservations = current_facility.reservations
User.where(facility_id: facility.id)
Membership.where(facility_id: current_facility.id)

# ✅ CORRECT - Admin users (override default scope)
User.unscoped.where(email: params[:email])  # When you NEED cross-facility
```

### Never Use

```ruby
# ❌ FORBIDDEN - Unscoped query (data leak!)
@reservations = Reservation.all
@users = User.all
@memberships = Membership.where(active: true)
```

**Impact**:
- **Security breach**: Facility A sees Facility B's data
- **Privacy violation**: PII exposed across tenants
- **Revenue loss**: Incorrect billing/reporting
- **Compliance failure**: GDPR, PCI-DSS violations

**Detection**: Run `/multi-tenancy` skill to audit queries

**Special Cases**:
- Admin dashboards: Use `.unscoped` explicitly
- Franchise reporting: Use `franchise_id` scope
- Background jobs: ALWAYS pass `facility_id` as argument

**Related**:
- CLAUDE.md "Critical Rules #2"
- docs/architecture/multi-tenancy.md

---

## 3. Financial Operations (Transactions)

**Rule**: ALWAYS use database transactions for payment/billing operations

**Why**: Payment operations must be atomic. Partial updates cause billing errors, lost revenue, or duplicate charges.

### Always Wrap

```ruby
# ✅ CORRECT - Atomic payment
ActiveRecord::Base.transaction do
  payment = Payment.create!(amount: 100, user: user)
  membership.update!(status: 'active', payment: payment)
  AuditLog.create!(action: 'payment_success', payment: payment)
end

# ✅ CORRECT - Rollback on failure
ActiveRecord::Base.transaction do
  charge = gateway.charge(amount)
  payment = Payment.create!(external_id: charge.id)
  send_receipt(payment)
rescue PaymentError => e
  # Transaction rolls back automatically
  notify_admin(e)
  raise
end
```

### Never Use

```ruby
# ❌ FORBIDDEN - Not atomic
payment = Payment.create!(amount: 100)
membership.update!(status: 'active')  # Could fail, leaving orphaned payment
AuditLog.create!(action: 'payment_success')  # Could fail, no audit trail
```

**Impact**:
- Orphaned payments (charged but no membership)
- Lost revenue (membership activated without payment)
- Audit failures (no trail of what happened)
- Refund nightmares (can't determine state)

**Detection**: Run `/code-review` or `/pci-compliance` on payment code

**Related**:
- CLAUDE.md "Critical Rules #3"
- packs/webhooks/ - Event builders use transactions
- docs/domains/payments.md

---

## 4. API Backward Compatibility

**Rule**: NEVER break backward compatibility for mobile apps

**Why**: Mobile apps can't be force-updated. Breaking changes strand users on old app versions.

### Safe Changes

```ruby
# ✅ SAFE - Add new field (optional)
field :new_field, String, null: true

# ✅ SAFE - Add new mutation
field :new_mutation, mutation: Mutations::NewMutation

# ✅ SAFE - Deprecate with warning
field :old_field, String, deprecation_reason: 'Use new_field instead'
```

### Breaking Changes

```ruby
# ❌ BREAKING - Remove field
# field :old_field, String  # Commented out = breaks old apps

# ❌ BREAKING - Change field type
field :amount, Int  # Was String, now Int = breaks parsing

# ❌ BREAKING - Make field required
field :required_field, String, null: false  # Was null: true

# ❌ BREAKING - Change mutation signature
field :update_user, mutation: Mutations::UpdateUser do
  argument :new_required_arg, String, required: true  # Breaks old calls
end
```

**Impact**:
- App crashes for users on old versions
- Support tickets flood in
- App store ratings drop
- Emergency hotfix required

**Detection**: Run `/graphql` skill before deploying API changes

**Deprecation Process**:
1. Add new field/mutation (mobile uses it in next release)
2. Mark old field as deprecated (warning in logs)
3. Wait 3 months (ensure 95%+ adoption)
4. Remove old field in next major version

**Related**:
- CLAUDE.md "Critical Rules #4"
- docs/api/graphql-compatibility.md

---

## 5. Payment Idempotency

**Rule**: All payment jobs MUST be idempotent

**Why**: Jobs can be retried (network failures, server restarts). Non-idempotent jobs cause duplicate charges.

### Idempotent Patterns

```ruby
# ✅ CORRECT - Check if already processed
class ChargeUserJob < ApplicationJob
  def perform(args)
    args = args.deep_symbolize_keys
    payment_id = args[:payment_id]

    payment = Payment.find(payment_id)
    return if payment.charged?  # Already processed

    gateway.charge(payment)
    payment.update!(charged: true, charged_at: Time.current)
  end
end
```

```ruby
# ✅ CORRECT - Use external_id for deduplication
class WebhookJob < ApplicationJob
  def perform(args)
    event_id = args[:event_id]

    # Skip if already processed
    return if ProcessedEvent.exists?(external_id: event_id)

    process_webhook(args)
    ProcessedEvent.create!(external_id: event_id, processed_at: Time.current)
  end
end
```

### Non-Idempotent (Dangerous)

```ruby
# ❌ DANGEROUS - Can charge twice
class ChargeUserJob < ApplicationJob
  def perform(args)
    user = User.find(args[:user_id])
    gateway.charge(user, amount: 100)  # No duplicate check!
  end
end
```

**Impact**:
- Double charges (refund nightmares)
- Customer complaints
- Chargeback risk
- PCI compliance failures

**Detection**: Run `/sidekiq` skill to validate job patterns

**Strategies**:
1. **Check state before acting** (payment.charged?)
2. **Use idempotency keys** (gateway supports it)
3. **Track processed events** (ProcessedEvent table)
4. **Make operations naturally idempotent** (update vs increment)

**Related**:
- CLAUDE.md "Critical Rules #5"
- docs/domains/payments.md
- app/jobs/ - See existing payment jobs for patterns

---

## 6. Command Execution (Docker)

**Rule**: All Ruby/Rails commands MUST run in Docker web container

**Why**: Dependencies, database, and environment only exist in Docker. Running locally causes version mismatches.

### Always Use

```bash
# ✅ CORRECT - Docker execution
bin/d rspec spec/models/user_spec.rb
make test TEST_PATH=spec/...
bin/d rails c

# ✅ CORRECT - For multiple commands
docker compose exec web bash
> bundle exec rails c
> bundle exec rake db:migrate
```

### Never Use

```bash
# ❌ FORBIDDEN - Direct execution (missing dependencies)
bundle exec rspec spec/...
rails console
rake db:migrate
```

**Impact**:
- "Cannot connect to database" errors
- Missing gems (different bundle)
- Wrong Ruby version
- Environment variable mismatches

**Detection**: Documented in CLAUDE.local.md

**Exceptions**:
- Git commands (run locally)
- Editor commands (run locally)
- Docker commands themselves (run locally)

**Related**:
- CLAUDE.local.md "Docker Execution"
- /docker-exec skill

---

## 7. Git Operations (No Auto-Commit)

**Rule**: NEVER commit or push without explicit user permission

**Why**: Commits should be intentional. Auto-commits bypass review and break git workflow.

### Always Ask

```ruby
# ✅ CORRECT - Get permission first
puts "Ready to commit changes:"
puts "  - app/models/user.rb (modified)"
puts "  - spec/models/user_spec.rb (new)"
puts ""
puts "Commit message: 'PLA-123 | Add user validation'"
puts ""
puts "Proceed with commit? (y/n)"
# Wait for user approval
```

### Never Auto-Execute

```ruby
# ❌ FORBIDDEN - No permission
system("git add .")
system("git commit -m 'Changes'")
system("git push origin feature-branch")
```

**Impact**:
- Unexpected commits in git history
- Breaks user's git workflow
- Commits without proper message format
- Pushes to wrong branch

**Detection**: Git operations require user approval

**Related**:
- CLAUDE.md "Critical Rules #7"
- /commit skill (asks permission)
- /create-pr skill (asks permission)

---

## 8. Commit Messages (No AI Attribution)

**Rule**: NEVER mention Claude, AI, or any AI tool in commit messages or PR descriptions

**Why**: Commits should be clean and professional. AI attribution is unnecessary and clutters history.

### Correct Format

```bash
# ✅ CORRECT - Clean commit message with gitmoji
git commit -m "PLA-123 | 🐛 fix: Handle nil case in payment validation"
git commit -m "CORE-456 | ✨ feat: Add GraphQL mutation for user update"
```

### Forbidden Patterns

```bash
# ❌ FORBIDDEN - Mentions AI
git commit -m "PLA-123 | fix payment (with Claude assistance)"
git commit -m "CORE-456 | feat: Add mutation
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

**Impact**:
- Unprofessional git history
- Confusing for team members
- No value added (who wrote it doesn't matter)

**Detection**: Pre-commit hook should catch this

**Related**:
- CLAUDE.local.md "NUNCA Agregar Co-Autor en Commits"
- /commit skill (ensures clean messages)

---

## 9. Test Coverage (100% Patch)

**Rule**: 100% coverage on changed lines is REQUIRED

**Why**: Untested code breaks in production. New code must have tests.

### Verify Before Commit

```bash
# ✅ CORRECT - Verify coverage
bin/d rake 'coverage:local:file[app/models/user.rb]'
# Expected output: "Coverage: 100%"

bin/d rake 'coverage:local:delta'
# Expected: "Patch coverage: 100%"
```

### Never Skip

```bash
# ❌ FORBIDDEN - Commit without coverage check
git add app/models/user.rb
git commit -m "Add new method"  # No coverage verification!
```

**Impact**:
- Untested code in production
- Bugs discovered by users (not tests)
- Technical debt accumulates
- CI failures on master

**Detection**: Run `/coverage` skill

**Exceptions**: NONE. All code changes must have tests.

**Related**:
- CLAUDE.local.md "Coverage 100%"
- /tdd skill (mandatory)
- /coverage skill (autonomous improvement)

---

## 10. Factory Performance (build > create)

**Rule**: Use `build` over `create` unless database operations required

**Why**: `create` hits database (slow). `build` is in-memory (10-100x faster). Slow tests waste CI time.

### Decision Tree

```ruby
# ✅ FAST - Testing validations, methods, attributes
let(:user) { build(:user, email: 'test@example.com') }

# ✅ FAST - Need id/persisted?
let(:user) { build_stubbed(:user) }

# ⚠️ SLOW - Only when testing scopes, queries, associations
let!(:user) { create(:user) }

# ✅ MEDIUM - Facility without 40+ associations
let(:facility) { create(:facility, :skip_callbacks) }
```

**Impact**:
- Slow: Test suite takes 15 min instead of 5 min
- Cost: CI minutes wasted ($$)
- Developer: Slow feedback loop

**Detection**: Run `/factory-check` skill

**Related**:
- [Factory Rules](./factory-rules.md) - Complete decision tree
- CLAUDE.local.md "Factory Rules"
- /tdd skill

---

## Summary Table

| Rule | Detection Skill | Impact if Violated |
|------|-----------------|-------------------|
| Timezone Safety | /timezone | Wrong times, billing errors |
| Multi-Tenancy | /multi-tenancy | Security breach, data leak |
| Financial Transactions | /code-review, /pci-compliance | Revenue loss, orphaned payments |
| API Compatibility | /graphql | App crashes for old versions |
| Payment Idempotency | /sidekiq | Duplicate charges |
| Docker Execution | Manual | Cannot run commands |
| No Auto-Commit | Manual | Unwanted git commits |
| No AI Attribution | Manual | Unprofessional git history |
| 100% Coverage | /coverage | Untested code in production |
| Factory Performance | /factory-check | Slow test suite |

---

## Enforcement

**Automatic** (CI/hooks):
- Brakeman (security)
- RuboCop (style, some patterns)
- Pre-commit hook (Pronto)
- Parallel test suite (coverage)

**Manual** (Skills):
- Run `/timezone` before commit
- Run `/multi-tenancy` on queries
- Run `/coverage` to verify 100%
- Run `/code-review` for comprehensive check

**Review** (PR):
- Team review catches missed violations
- CI checks enforce coverage/tests
- Pronto comments on changed lines

---

## References

- CLAUDE.md - Critical Rules section
- CLAUDE.local.md - Local enforcement
- [Forbidden Patterns](./forbidden-patterns.md)
- [Testing Patterns](./testing-patterns.md)
- [Factory Rules](./factory-rules.md)
- docs/development/spec-best-practices.md
