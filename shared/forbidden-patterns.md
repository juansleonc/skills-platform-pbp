# Forbidden Patterns

Patterns that MUST be avoided in all code and tests. These patterns cause failures, performance issues, or maintenance problems.

## Test-Specific Forbidden Patterns

### 1. allow_any_instance_of / expect_any_instance_of

**Status**: ❌ FORBIDDEN (with documented exceptions)

```ruby
# ❌ FORBIDDEN - Brittle, couples to implementation
allow_any_instance_of(PaymentGateway).to receive(:charge)
expect_any_instance_of(User).to receive(:notify)

# ✅ CORRECT - Use dependency injection
let(:gateway) { instance_double(PaymentGateway) }
allow(gateway).to receive(:charge)

let(:user) { build(:user) }
allow(user).to receive(:notify)
```

**Why forbidden**:
- Couples tests to implementation details
- Difficult to debug when it fails
- Hides design problems (missing dependency injection)
- Can cause flaky tests in parallel execution

#### Legitimate Exceptions

**`allow_any_instance_of` is acceptable when ALL criteria met:**

1. ✅ **Framework limitation** prevents alternative (e.g., `dynamic_rule_query`, `has_secure_token`, Active Record callbacks)
2. ✅ **Alternative approaches attempted** and documented (show why they don't work)
3. ✅ **Surrounded by `rubocop:disable`** with justification comment
4. ✅ **Isolated to specific test**, not affecting other specs

**Example (Acceptable):**

```ruby
# rubocop:disable RSpec/AnyInstance
# Required: enable_memberships_notifications reads from Rules table via dynamic_rule_query
# Alternatives tried:
#   1. Direct membership_rules manipulation → doesn't work (uses RuleServices::Query)
#   2. Stubbing RuleServices::Query → too strict (breaks factory creation with other rules)
# No practical way to stub this without allow_any_instance_of
allow_any_instance_of(Facility).to receive(:enable_memberships_notifications).and_return(true)
# rubocop:enable RSpec/AnyInstance
```

**When to use exception:**
- Methods that read from polymorphic/dynamic sources (Rules table, encrypted attributes)
- Active Record callbacks that can't be easily bypassed
- Framework-generated methods (has_secure_token, acts_as_taggable, etc.)

**When NOT to use exception:**
- Lazy stubbing (just because it's easier)
- Can be solved with dependency injection
- Can be solved with factory traits
- Not in isolated test context

**Validation**: Pronto will accept with proper `rubocop:disable` + justification comment

---

### 2. Hardcoded IDs

**Status**: ❌ FORBIDDEN

```ruby
# ❌ FORBIDDEN - Breaks parallel tests
create(:user, id: 1)
create(:facility, id: 123)
User.find(1)

# ✅ CORRECT - Let factory generate IDs
let(:user) { create(:user) }
let(:facility) { create(:facility) }
User.find(user.id)
```

**Why forbidden**:
- Breaks parallel test execution (ID conflicts)
- Fragile (assumes database state)
- Not portable (different test databases)

---

### 3. before(:all) with create

**Status**: ❌ FORBIDDEN

```ruby
# ❌ FORBIDDEN - Creates shared state, causes flaky tests
before(:all) do
  @user = create(:user)
end

# ✅ CORRECT - Use before(:each) for isolation
before do
  @user = create(:user)
end

# ✅ EVEN BETTER - Use let for lazy loading
let(:user) { create(:user) }
```

**Why forbidden**:
- Shared state between tests (not isolated)
- Database rollback doesn't work
- Causes test interdependencies
- Debugging nightmares

---

## Code-Specific Forbidden Patterns

### 4. Time.now / Date.today / DateTime.now

**Status**: ❌ FORBIDDEN

```ruby
# ❌ FORBIDDEN - Not timezone-aware
Time.now
Date.today
DateTime.now
Time.new
Time.parse(str)

# ✅ CORRECT - Timezone-aware alternatives
Time.current
Date.current
Time.current
Time.zone.local(...)
Time.zone.parse(str)
```

**Why forbidden**:
- Ignores application timezone (configured in Rails)
- Breaks for users in different timezones
- Causes subtle bugs with DST transitions
- Multi-tenant app needs facility-specific timezones

**Related**: See [Critical Rules](./critical-rules.md#timezone-safety)

---

### 5. .to_s(:format) (Rails 7.0 Deprecated / Rails 7.1 Removed)

**Status**: ❌ FORBIDDEN (ActiveSupport deprecation — deprecated Rails 7.0, removed Rails 7.1)

```ruby
# ❌ FORBIDDEN - ActiveSupport extension removed in Rails 7.1; breaks on upgrade from 6.1→7.2
date.to_s(:db)              # "2024-01-15"
time.to_s(:db)              # "2024-01-15 10:30:00"
time.to_s(:short)           # "15 Jan 10:30"
time.to_s(:long)            # "January 15, 2024 10:30"

# ✅ CORRECT (Rails 6.1, safe today) - Use strftime
date.strftime('%Y-%m-%d')                # "2024-01-15"
time.strftime('%Y-%m-%d %H:%M:%S')       # "2024-01-15 10:30:00"
time.strftime('%d %b %H:%M')             # "15 Jan 10:30"
time.strftime('%B %d, %Y %H:%M')         # "January 15, 2024 10:30"

# ✅ ALSO CORRECT (Rails 7.0+ only) - to_fs is the direct ActiveSupport alias replacement
# ⚠️  NOT available on Rails 6.1 — use strftime for code that must run on 6.1
date.to_fs(:db)              # Rails 7.0+ only
time.to_fs(:db)              # Rails 7.0+ only
```

**Common Replacements**:

| Old Format | strftime Equivalent (Rails 6.1 safe) | Rails 7.0+ alias |
|------------|--------------------------------------|------------------|
| `:db` | `'%Y-%m-%d'` (date) / `'%Y-%m-%d %H:%M:%S'` (datetime) | `to_fs(:db)` |
| `:short` | `'%d %b %H:%M'` | `to_fs(:short)` |
| `:long` | `'%B %d, %Y %H:%M'` | `to_fs(:long)` |
| `:iso8601` | Use `.iso8601` method instead | `to_fs(:iso8601)` |

**Why forbidden**:
- This is an **ActiveSupport (Rails) deprecation** — NOT a Ruby deprecation
- `to_s(:format)` was deprecated in Rails 7.0 and **removed in Rails 7.1**
- This repo is on Rails 6.1 migrating to 7.2 — code using `.to_s(:db)` will **break on upgrade**
- Use `strftime` (works on all Rails versions); use `to_fs` only in code that won't run on 6.1

---

## Security Forbidden Patterns

### 6. Logging Sensitive Data

**Status**: ❌ FORBIDDEN (PCI-DSS violation)

```ruby
# ❌ FORBIDDEN - Logs sensitive data
Rails.logger.info("Charging card #{card_number}")
puts "CVV: #{cvv}"
logger.debug("API Token: #{api_token}")

# ✅ CORRECT - Log only safe identifiers
Rails.logger.info("Charging card ending in #{card_last_4}")
logger.debug("API request for facility #{facility_id}")
```

**Sensitive data** (NEVER log):
- Card numbers, CVVs, expiration dates
- Passwords, tokens, API keys
- Social security numbers
- Medical records
- Bank account numbers

---

### 7. Hardcoded Credentials

**Status**: ❌ FORBIDDEN

```ruby
# ❌ FORBIDDEN - Hardcoded secrets
API_KEY = "sk_live_abc123..."
PASSWORD = "secret123"
db_config = { password: "admin" }

# ✅ CORRECT - Use ENV variables or Rails credentials
API_KEY = ENV['STRIPE_API_KEY']
PASSWORD = Rails.application.credentials.db_password
db_config = { password: ENV.fetch('DB_PASSWORD') }
```

---

### 8. SQL Injection Vulnerabilities

**Status**: ❌ FORBIDDEN

```ruby
# ❌ FORBIDDEN - String interpolation in SQL
User.where("email = '#{params[:email]}'")
ActiveRecord::Base.connection.execute("DELETE FROM users WHERE id = #{id}")

# ✅ CORRECT - Use parameterized queries
User.where("email = ?", params[:email])
User.where(email: params[:email])
ActiveRecord::Base.connection.execute(
  "DELETE FROM users WHERE id = ?", id
)
```

---

## Performance Forbidden Patterns

### 9. Unnecessary create in Tests

**Status**: ⚠️ AVOID (performance)

```ruby
# ❌ SLOW - Unnecessary database hits
let(:user) { create(:user) }  # When testing validations/methods

# ✅ FAST - Use build for non-DB operations
let(:user) { build(:user) }   # 10-100x faster

# ✅ FAST - Use build_stubbed when you need id/persisted?
let(:user) { build_stubbed(:user) }
```

**Rule**: Only use `create` when you need:
- Database scopes/queries
- Uniqueness validations
- Database callbacks
- Associations that must persist

**Related**: See [Factory Rules](./factory-rules.md) for complete decision tree

---

### 10. create(:facility) without :skip_callbacks

**Status**: ⚠️ AVOID (performance)

```ruby
# ❌ SLOW - Creates 40+ associated records (courts, products, merchants)
let(:facility) { create(:facility) }

# ✅ FAST - Skip callbacks unless you need them
let(:facility) { create(:facility, :skip_callbacks) }

# ⚠️ ONLY use full facility if you need courts/products
let(:facility) { create(:facility) }  # When testing reservations
```

---

### 8b. Stubbing the Subject Under Test (SUT)

**Status**: ⚠️ AVOID

```ruby
# ❌ AVOID - Stubbing the object you're testing means you're testing your stubs
allow(user).to receive(:full_name).and_return('John Doe')
expect(user.full_name).to eq('John Doe')  # Always passes!

# ✅ CORRECT - Test real behavior
user = build(:user, first_name: 'John', last_name: 'Doe')
expect(user.full_name).to eq('John Doe')
```

**Why avoided**: Tests pass regardless of actual code behavior. Gives false confidence.

---

### 8c. rescue nil / Silent Error Swallowing

**Status**: ⚠️ AVOID

```ruby
# ❌ AVOID - Silently swallows ALL errors
value = something.method rescue nil
begin; risky_operation; rescue; end

# ✅ CORRECT - Rescue specific exceptions, log or notify
begin
  risky_operation
rescue ActiveRecord::RecordNotFound => e
  Rails.logger.warn("Record not found: #{e.message}")
  nil
end
```

**Why avoided**: Hides real errors. Makes debugging impossible. Can mask data corruption.

---

### 8d. Queries in Views

**Status**: ❌ FORBIDDEN

```erb
<%# ❌ FORBIDDEN - Database queries in views %>
<%= @user.reservations.where(status: 'confirmed').count %>
<%= Facility.find(facility_id).name %>

<%# ✅ CORRECT - Preload in controller, display in view %>
<%= @confirmed_count %>
<%= @facility_name %>
```

**Why forbidden**: Hides N+1 queries, violates MVC, makes performance debugging impossible.

---

## Rails-Specific Forbidden Patterns

### 11. permit!

**Status**: ❌ FORBIDDEN (security)

```ruby
# ❌ FORBIDDEN - Mass assignment vulnerability
params.permit!

# ✅ CORRECT - Explicitly permit attributes
params.require(:user).permit(:name, :email)
```

---

### 12. raw / html_safe without sanitization

**Status**: ❌ FORBIDDEN (XSS vulnerability)

```ruby
# ❌ FORBIDDEN - XSS vulnerability
content.html_safe
raw(user_input)

# ✅ CORRECT - Sanitize first
sanitize(content).html_safe
simple_format(content)  # Auto-sanitizes
```

---

## Validation

Skills that check for these patterns:
- `/tdd` - Validates test patterns (1-5, 8b)
- `/timezone` - Validates time patterns (4-5)
- `/security` - Validates security patterns (6-8, 11-12)
- `/resilience` - Validates error handling patterns (8c)
- `/performance` - Validates performance patterns (9-10)
- `/code-smells` - Validates structural patterns (8d)
- `/code-review` - Validates all patterns
- `/rails-audit` - Orchestrates all validation skills

---

## Summary Table

| Pattern | Status | Impact | Detected By |
|---------|--------|--------|-------------|
| allow_any_instance_of | ❌ FORBIDDEN | Brittle tests | /tdd, /coverage |
| Hardcoded IDs | ❌ FORBIDDEN | Parallel test failures | /tdd, /coverage |
| before(:all) with create | ❌ FORBIDDEN | Flaky tests | /tdd |
| Time.now | ❌ FORBIDDEN | Timezone bugs | /timezone, /tdd |
| .to_s(:db) | ❌ FORBIDDEN | Rails 7.0 deprecated / Rails 7.1 removed (ActiveSupport, not Ruby) | /timezone |
| Logging sensitive data | ❌ FORBIDDEN | PCI-DSS violation | /security, /pci-compliance |
| Hardcoded credentials | ❌ FORBIDDEN | Security breach | /security |
| SQL injection | ❌ FORBIDDEN | Security breach | /security |
| Stubbing SUT | ⚠️ AVOID | False test confidence | /tdd, /code-review |
| rescue nil / bare rescue | ⚠️ AVOID | Silent failures | /resilience, /security |
| Queries in views | ❌ FORBIDDEN | Hidden N+1, MVC violation | /code-smells, /performance |
| Unnecessary create | ⚠️ AVOID | Slow tests | /factory-check, /performance |
| permit! | ❌ FORBIDDEN | Mass assignment | /security |
| raw/html_safe | ❌ FORBIDDEN | XSS vulnerability | /security |

---

## Auto-Detection

Run these skills to detect forbidden patterns:

```bash
/timezone           # Detects Time.now, .to_s(:db)
/security           # Detects logging, credentials, injection
/tdd                # Validates test patterns
/code-review        # Full pattern check
```

---

## References

- [Factory Rules](./factory-rules.md) - build vs create decision tree
- [Testing Patterns](./testing-patterns.md) - Time, Redis, parallel safety
- [Critical Rules](./critical-rules.md) - Project-wide rules
- CLAUDE.md - Project conventions
- CLAUDE.local.md - Local development rules
