# Testing Patterns

Best practices for writing reliable, fast, and maintainable tests in the PayByCourt platform.

## Time-Dependent Testing

### Pattern 1: Always Use Timecop with Time.current

**Problem**: Tests that depend on current time can be flaky or fail randomly.

```ruby
# ❌ BAD - Flaky, can fail due to execution time
it 'expires after 30 days' do
  user = create(:user)
  expect(user.expires_at).to eq(Time.current + 30.days)
  # Fails if test execution takes > 1 second
end

# ✅ GOOD - Frozen time is deterministic
it 'expires after 30 days' do
  Timecop.freeze(Time.current) do
    user = create(:user)
    expect(user.expires_at).to eq(30.days.from_now)
  end
end
```

### Pattern 2: Timecop in before/after Blocks

```ruby
# ✅ GOOD - Freeze time for entire context
describe 'membership renewal' do
  let(:frozen_time) { Time.zone.parse('2024-01-15 10:00:00') }

  before do
    Timecop.freeze(frozen_time)
  end

  after do
    Timecop.return  # Always cleanup!
  end

  it 'renews on correct date' do
    membership = create(:membership)
    expect(membership.next_renewal_date).to eq(frozen_time + 30.days)
  end
end
```

### Pattern 3: Testing Time Ranges

```ruby
# ✅ GOOD - Use be_within for timestamp comparisons
it 'sets created_at to current time' do
  Timecop.freeze(Time.current) do
    user = create(:user)
    expect(user.created_at).to be_within(1.second).of(Time.current)
  end
end
```

### Pattern 4: DST (Daylight Saving Time) Testing

**Critical**: Test DST transitions for time-sensitive features.

```ruby
describe 'DST transitions' do
  context 'during spring forward (2:00 AM doesn\'t exist)' do
    it 'handles non-existent time' do
      Timecop.freeze(Time.zone.parse('2024-03-10 01:30:00')) do
        # March 10, 2024: 1:59 AM → 3:00 AM (skips 2:00-2:59)
        time = 1.hour.from_now  # Should be 3:30 AM, not 2:30 AM
        expect(time.hour).to eq(3)  # Not 2!
      end
    end
  end

  context 'during fall back (2:00 AM happens twice)' do
    it 'handles duplicate time' do
      Timecop.freeze(Time.zone.parse('2024-11-03 01:30:00')) do
        # November 3, 2024: 2:00 AM → 1:00 AM (repeats 1:00-1:59)
        time = 1.hour.from_now
        # Ambiguous - could be either occurrence
        expect(time).to be_present
      end
    end
  end
end
```

### Pattern 5: Facility Timezone Testing

```ruby
# ✅ GOOD - Test with different facility timezones
describe 'local time' do
  let(:facility_eastern) { create(:facility, time_zone: 'Eastern Time (US & Canada)') }
  let(:facility_pacific) { create(:facility, time_zone: 'Pacific Time (US & Canada)') }

  it 'respects facility timezone' do
    Timecop.freeze(Time.zone.parse('2024-01-15 12:00:00 UTC')) do
      # 12:00 UTC = 07:00 EST, 04:00 PST
      expect(facility_eastern.local_time.hour).to eq(7)
      expect(facility_pacific.local_time.hour).to eq(4)
    end
  end
end
```

---

## Redis Testing Patterns

### Pattern 6: Clear Redis Before Tests

**Problem**: Tests can fail if Redis contains stale data from previous tests.

```ruby
# ✅ GOOD - Clear Redis before each test
before do
  Redis.current.flushdb
  # Or for specific namespace:
  Rails.cache.clear
end

# ✅ GOOD - Clear specific keys only
before do
  Redis.current.del("rate_limit:user:#{user.id}")
  Redis.current.del("cache:facility:#{facility.id}")
end
```

### Pattern 7: Rate Limiting Tests

```ruby
describe 'rate limiting' do
  before do
    Redis.current.flushdb  # CRITICAL: Clear rate limit counters
  end

  it 'blocks after 5 requests' do
    5.times { make_request }
    expect { make_request }.to raise_error(RateLimitExceeded)
  end
end
```

### Pattern 8: Cache Testing

```ruby
describe 'caching' do
  before do
    Rails.cache.clear  # CRITICAL: Clear cache
  end

  it 'caches expensive operation' do
    expect(ExpensiveService).to receive(:call).once
    2.times { CachedService.get_data }
  end
end
```

---

## Parallel Test Safety

### Pattern 9: Unique Emails with SecureRandom

**Problem**: Parallel tests can create users with duplicate emails, causing failures.

```ruby
# ❌ BAD - Email collision in parallel tests
let(:user) { create(:user, email: 'test@example.com') }

# ✅ GOOD - Unique emails for parallel safety
let(:user) { create(:user, email: "user_#{SecureRandom.hex(4)}@example.com") }

# ✅ GOOD - Let factory generate unique email
let(:user) { create(:user) }  # Uses sequence
```

### Pattern 10: Unique Subdomains

```ruby
# ✅ GOOD - Unique subdomains for facilities
let(:facility) do
  create(:facility,
    :skip_callbacks,
    subdomain: "facility_#{SecureRandom.hex(4)}"
  )
end
```

### Pattern 11: Avoid Shared State

```ruby
# ❌ BAD - Shared state between tests
before(:all) do
  @facility = create(:facility)
end

# ✅ GOOD - Isolated state per test
let(:facility) { create(:facility, :skip_callbacks) }

# ✅ GOOD - Use before(:each) if needed
before do
  @facility = create(:facility, :skip_callbacks)
end
```

---

## Database Transaction Safety

### Pattern 12: Use Database Cleaner Strategy

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.use_transactional_fixtures = true

  # For tests that need transaction: false
  config.around(:each, :no_transaction) do |example|
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.cleaning do
      example.run
    end
    DatabaseCleaner.strategy = :transaction
  end
end

# Usage
it 'tests background job', :no_transaction do
  # Job runs outside transaction
end
```

---

## Async/Background Job Testing

### Pattern 13: Sidekiq Testing Modes

```ruby
# Test inline (synchronous)
describe 'job execution' do
  it 'performs job inline' do
    Sidekiq::Testing.inline! do
      MyJob.perform_async(args)
      expect(result).to be_present
    end
  end
end

# Test job enqueued (async)
describe 'job scheduling' do
  it 'enqueues job' do
    Sidekiq::Testing.fake! do
      expect {
        MyJob.perform_async(args)
      }.to change(MyJob.jobs, :size).by(1)
    end
  end
end
```

### Pattern 14: Clear Sidekiq Queue

```ruby
before do
  Sidekiq::Worker.clear_all  # Clear all queued jobs
end
```

---

## System Test Patterns (Playwright)

### Pattern 15: Wait for AJAX/Fetch

```ruby
# ✅ GOOD - Wait for loading to disappear
def wait_for_ajax
  expect(page).to have_no_css('.loading', wait: 5)
end

# ✅ GOOD - Wait for specific element
def wait_for_search_results
  expect(page).to have_css('#results-table tbody tr', wait: 10)
end
```

### Pattern 16: Multi-Tenant Subdomain Testing

```ruby
# ✅ GOOD - Use visit_as_tenant helper
def login_as(user, subdomain:)
  visit_as_tenant('/users/sign_in', subdomain: subdomain)
  fill_in 'Email', with: user.email
  fill_in 'Password', with: password
  click_button 'Sign in'
end
```

### Pattern 17: OpenSearch Indexing for System Tests

```ruby
before do
  # Index users for search (bypasses default_scope)
  [active_user, inactive_user].each do |u|
    User.__opensearch__.client.index(
      index: User.index_name,
      id: u.id,
      body: u.__opensearch__.as_indexed_json
    )
  end
  User.__opensearch__.refresh_index!
rescue StandardError => e
  Rails.logger.warn("OpenSearch not available: #{e.message}")
end
```

---

## Mocking and Stubbing

### Pattern 18: Mock External APIs

```ruby
# ✅ GOOD - Stub external HTTP calls
before do
  stub_request(:post, "https://api.stripe.com/v1/charges")
    .to_return(status: 200, body: { id: 'ch_123' }.to_json)
end
```

### Pattern 19: Dependency Injection over any_instance_of

```ruby
# ❌ BAD - Brittle, couples to implementation
allow_any_instance_of(PaymentGateway).to receive(:charge)

# ✅ GOOD - Inject dependency
let(:gateway) { instance_double(PaymentGateway) }
let(:service) { PaymentService.new(gateway: gateway) }

before do
  allow(gateway).to receive(:charge).and_return(success: true)
end
```

---

## Nil Safety in Tests

### Pattern 20: Safe Navigation in Assertions

```ruby
# ✅ GOOD - Handle nil gracefully
expect(user.profile&.bio).to eq('Test bio')

# ✅ GOOD - Test nil explicitly
expect(user.profile).to be_nil
expect { user.profile.bio }.to raise_error(NoMethodError)
```

---

## Test Data Cleanup

### Pattern 21: Clean Up After Tests

```ruby
after do
  Timecop.return           # Always return from frozen time
  Redis.current.flushdb    # Clear Redis if used
  Rails.cache.clear        # Clear cache if used
  Sidekiq::Worker.clear_all # Clear job queue if used
end
```

---

## Performance Patterns

### Pattern 22: Build Over Create

```ruby
# ✅ GOOD - Use build for validations/methods (10-100x faster)
describe '#full_name' do
  let(:user) { build(:user, first_name: 'John', last_name: 'Doe') }

  it 'combines first and last name' do
    expect(user.full_name).to eq('John Doe')
  end
end

# ⚠️ ONLY use create when testing scopes/queries
describe '.active' do
  let!(:active_user) { create(:user, active: true) }
  let!(:inactive_user) { create(:user, active: false) }

  it 'returns only active users' do
    expect(User.active).to eq([active_user])
  end
end
```

**Related**: See [Factory Rules](./factory-rules.md) for complete decision tree

---

## Testing Antipatterns (Structural)

### Anti-Pattern: Mystery Guest

Test depends on setup that's invisible — reader can't understand the test without reading other files or contexts.

```ruby
# ❌ MYSTERY GUEST - Where does this data come from? What's in the factory?
it 'calculates total' do
  expect(order.total).to eq(150.0)
  # Reader has no idea what items, prices, or discounts are set up
end

# ✅ EXPLICIT - All relevant data visible in the test
it 'calculates total from line items' do
  order = build(:order)
  order.line_items = [
    build(:line_item, price: 100.0),
    build(:line_item, price: 50.0)
  ]
  expect(order.total).to eq(150.0)
end
```

### Anti-Pattern: Stubbing the Subject Under Test (SUT)

Never stub methods on the object you're testing — you're testing your stubs, not the code.

```ruby
# ❌ STUBBING SUT - Testing the stub, not the actual code
it 'returns formatted name' do
  allow(user).to receive(:full_name).and_return('John Doe')
  expect(user.full_name).to eq('John Doe')  # Always passes!
end

# ✅ TEST THE REAL THING
it 'returns formatted name' do
  user = build(:user, first_name: 'John', last_name: 'Doe')
  expect(user.full_name).to eq('John Doe')
end
```

### Anti-Pattern: False Positives (Overly Broad Assertions)

```ruby
# ❌ FALSE POSITIVE - Passes even if wrong data
it 'creates a payment' do
  result = service.call
  expect(result).to be_truthy  # {} is truthy, nil is falsy — too broad
end

# ✅ SPECIFIC ASSERTION
it 'creates a payment with correct amount' do
  result = service.call
  expect(result).to be_a(Payment)
  expect(result.amount).to eq(100.0)
  expect(result.status).to eq('completed')
end
```

### Anti-Pattern: Bloated Factories

Factories with unnecessary attributes slow down tests and obscure what matters.

```ruby
# ❌ BLOATED - Factory has 15 attributes, test only cares about 2
let(:user) { create(:user) }  # Creates profile, avatar, preferences, settings...

# ✅ MINIMAL - Only what's needed
let(:user) { build(:user, first_name: 'John', email: 'john@test.com') }
```

### Anti-Pattern: Excessive let/before Setup

More than 5 `let` statements per context makes tests hard to follow.

```ruby
# ❌ TOO MANY LETS - Reader loses track
let(:facility) { create(:facility, :skip_callbacks) }
let(:user) { create(:user) }
let(:membership) { create(:membership, user: user) }
let(:plan) { create(:membership_plan) }
let(:price) { create(:membership_plan_price, plan: plan) }
let(:payment) { create(:payment, user: user) }
let(:invoice) { create(:invoice, payment: payment) }
let(:discount) { create(:discount) }
# 8 lets — reader can't hold all of this in mind

# ✅ BETTER - Extract to helper method or reduce scope
let(:facility) { create(:facility, :skip_callbacks) }
let(:membership_context) { create_membership_with_payment(facility) }

# Or split into smaller focused contexts with fewer lets each
```

---

## Testing Wrong Layer (Layered Design)

> Inspired by palkan's "Layered Design for Ruby on Rails Applications"

### Anti-Pattern: Business Logic in Controller Tests

Controller specs should only verify HTTP concerns (auth, params, response codes). Domain logic assertions belong in model/service specs.

```ruby
# ❌ TESTING WRONG LAYER — Controller test verifies business logic
describe OrdersController do
  it "applies VIP discount" do
    post :create, params: { items: [...], customer_id: vip.id }
    expect(Order.last.total).to eq(90)  # Domain logic in controller test!
  end
end

# ✅ TEST AT RIGHT LAYER — Business logic in model spec
describe Order do
  it "applies VIP discount" do
    order = build(:order, customer: vip_customer, items: [build(:item, price: 100)])
    expect(order.total).to eq(90)
  end
end

# ✅ CONTROLLER SPEC — Only tests HTTP behavior
describe OrdersController do
  it "creates order and redirects" do
    post :create, params: valid_params
    expect(response).to redirect_to(Order.last)
  end
end
```

### Anti-Pattern: External Service Stubs in Model Specs

If your model spec needs `stub_request` or `WebMock`, the model has an upward dependency on an external service.

```ruby
# ❌ WRONG LAYER — Model spec mocks HTTP (model shouldn't make HTTP calls)
describe User, '#sync_to_crm' do
  before do
    stub_request(:post, "https://api.crm.com/contacts")
      .to_return(status: 200)
  end

  it "syncs user to CRM" do
    user = build(:user)
    expect(user.sync_to_crm).to be_truthy
  end
end

# ✅ RIGHT LAYER — Extract HTTP to service, test model logic separately
describe User do
  it "provides CRM-ready attributes" do
    user = build(:user, first_name: 'John', email: 'john@test.com')
    expect(user.crm_attributes).to include(name: 'John', email: 'john@test.com')
  end
end

describe CrmSyncService do
  it "sends user data to CRM" do
    stub_request(:post, "https://api.crm.com/contacts")
    service = CrmSyncService.new(user: build_stubbed(:user))
    expect(service.call).to be_success
  end
end
```

### Anti-Pattern: Mailer/Job Expectations in Model Specs

If your model spec asserts that a mailer was called or a job was enqueued, the model has orchestration responsibilities that belong in a service.

```ruby
# ❌ WRONG LAYER — Model spec expects mailer
describe Membership, '#activate!' do
  it "sends welcome email" do
    membership = create(:membership)
    expect(MembershipMailer).to receive(:welcome).and_call_original
    membership.activate!  # Model is sending email!
  end
end

# ✅ RIGHT LAYER — Service orchestrates, model just transitions state
describe Membership, '#activate!' do
  it "transitions to active state" do
    membership = build(:membership, aasm_state: 'idle')
    membership.activate!
    expect(membership.aasm_state).to eq('active')
  end
end

describe ActivateMembershipService do
  it "activates and sends welcome email" do
    membership = create(:membership)
    expect(MembershipMailer).to receive(:welcome)
    ActivateMembershipService.call(membership: membership)
  end
end
```

### Quick Detection Commands

```bash
# Find controller tests with business logic assertions
grep -rn "expect.*\.total\|expect.*\.calculate\|expect.*\.price\|expect.*\.discount\|expect.*\.amount" spec/controllers/ spec/requests/ --include="*.rb" 2>/dev/null

# Find model specs with HTTP stubs (layer violation)
grep -rn "stub_request\|WebMock\.stub\|VCR\.use_cassette" spec/models/ --include="*.rb" 2>/dev/null

# Find model specs with mailer/job expectations (layer violation)
grep -rn "expect.*Mailer\|expect.*Job\.\|expect.*perform_later\|expect.*deliver" spec/models/ --include="*.rb" 2>/dev/null
```

---

## Common Anti-Patterns (Avoid)

### Anti-Pattern 1: sleep in Tests

```ruby
# ❌ BAD - Slow and flaky
it 'waits for job' do
  MyJob.perform_async
  sleep 2  # Slow and unreliable
  expect(result).to be_present
end

# ✅ GOOD - Use Sidekiq inline mode
it 'performs job' do
  Sidekiq::Testing.inline! do
    MyJob.perform_async
    expect(result).to be_present
  end
end
```

### Anti-Pattern 2: Hardcoded Dates

```ruby
# ❌ BAD - Will fail in the future
it 'checks expiration' do
  user = create(:user, expires_at: Time.zone.parse('2024-12-31'))
  expect(user).to be_expired
end

# ✅ GOOD - Relative dates
it 'checks expiration' do
  Timecop.freeze(Time.current) do
    user = create(:user, expires_at: 30.days.ago)
    expect(user).to be_expired
  end
end
```

### Anti-Pattern 3: Testing Implementation, Not Behavior

```ruby
# ❌ BAD - Tests internal implementation
it 'calls private method' do
  expect(service).to receive(:private_helper)
  service.public_method
end

# ✅ GOOD - Tests public behavior
it 'performs expected action' do
  result = service.public_method
  expect(result).to eq(expected_outcome)
end
```

---

## Validation Checklist

Before committing tests, verify:
- [ ] Time-dependent tests use Timecop + Time.current
- [ ] Redis cleared if testing rate limits/caching
- [ ] Unique emails/subdomains with SecureRandom
- [ ] No hardcoded IDs
- [ ] No allow_any_instance_of
- [ ] No before(:all) with create
- [ ] Factories use build over create when possible
- [ ] External APIs stubbed (no real HTTP calls)
- [ ] Tests are isolated (no shared state)
- [ ] Cleanup in after blocks (Timecop.return, etc.)

---

## References

- [Factory Rules](./factory-rules.md) - build vs create decision tree
- [Forbidden Patterns](./forbidden-patterns.md) - patterns to avoid
- [Critical Rules](./critical-rules.md) - project-wide rules
- CLAUDE.md - Testing section
- docs/development/spec-best-practices.md
- docs/development/claude-testing-guide.md
