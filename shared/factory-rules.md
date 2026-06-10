# Factory Rules - Complete Decision Tree

> **Shared Reference**: Used by `/tdd`, `/factory-check`, `/coverage`, `/orchestrate`

This document contains the complete decision tree for choosing the right factory method.

## Quick Decision Tree

```
┌─────────────────────────────────────────────────────┐
│ Does the test query the database?                  │
│  - .where, .find, .exists?, scopes                 │
└─────────────┬───────────────────────────────────────┘
              │
         NO ──┼── YES → use create(:factory)
              │
              ↓
┌─────────────────────────────────────────────────────┐
│ Does code check .id or .persisted?                 │
└─────────────┬───────────────────────────────────────┘
              │
         NO ──┼── YES → use build_stubbed(:factory)
              │
              ↓
        use build(:factory) ✅ FASTEST
```

## Factory Methods Comparison

| Method | DB Hit? | Has ID? | Persisted? | Speed | Use When |
|--------|---------|---------|------------|-------|----------|
| `build(:factory)` | ❌ No | ❌ No | ❌ No | ⚡⚡⚡ Fast | Validations, methods, attributes |
| `build_stubbed(:factory)` | ❌ No | ✅ Yes | ✅ Yes | ⚡⚡ Fast | Code checks `.id` or `.persisted?` |
| `create(:factory)` | ✅ Yes | ✅ Yes | ✅ Yes | 🐌 Slow | Scopes, queries, callbacks, uniqueness |
| `create(:facility, :skip_callbacks)` | ✅ Yes | ✅ Yes | ✅ Yes | 🐢 Medium | Facility without 40+ associations |

## Performance Impact

### Real Measurements (Platform Project)

| Operation | Time | Notes |
|-----------|------|-------|
| `build(:user)` | <1ms | No DB hit |
| `build_stubbed(:user)` | ~2ms | Simulates DB attributes |
| `create(:user)` | 50-80ms | Single INSERT |
| `create(:facility)` | 400-600ms | 40+ associated records! |
| `create(:facility, :skip_callbacks)` | 150-200ms | Skips associations |
| `create_list(:user, 10)` | 500-800ms | 10 INSERTs |
| `build_stubbed_list(:user, 10)` | ~5ms | No DB |

### Suite-Level Impact

Based on actual test suite:
- **3000 specs** in suite
- **Average 5 factories per spec** = 15,000 factory calls
- **Wrong factory choice wastes**: 50ms × 15,000 = 12.5 minutes
- **With optimizations**: 2ms × 15,000 = 30 seconds
- **Savings**: 12 minutes per run → **2 hours daily in CI**

## Detailed Use Cases

### Use Case 1: Validations

```ruby
# ❌ SLOW - Unnecessary DB hit
it 'validates presence of name' do
  user = create(:user, name: nil)
  expect(user).not_to be_valid
end

# ✅ FAST - Validation doesn't need DB
it 'validates presence of name' do
  user = build(:user, name: nil)
  expect(user).not_to be_valid
end

# Impact: 70ms → <1ms (70x faster)
```

### Use Case 2: Method Calls

```ruby
# ❌ SLOW - Method doesn't need DB
it 'returns full name' do
  user = create(:user, first_name: 'John', last_name: 'Doe')
  expect(user.full_name).to eq('John Doe')
end

# ✅ FAST - Simple method call
it 'returns full name' do
  user = build(:user, first_name: 'John', last_name: 'Doe')
  expect(user.full_name).to eq('John Doe')
end

# Impact: 65ms → <1ms (65x faster)
```

### Use Case 3: Code Checking ID

```ruby
# ❌ SLOW - Only needs ID
it 'processes user by ID' do
  user = create(:user)
  expect(processor.call(user.id)).to be_truthy
end

# ✅ FAST - build_stubbed provides ID
it 'processes user by ID' do
  user = build_stubbed(:user)
  expect(processor.call(user.id)).to be_truthy
end

# Impact: 60ms → 2ms (30x faster)
```

### Use Case 4: Database Scopes

```ruby
# ✅ CORRECT - Scopes need DB
it 'finds active users' do
  active_user = create(:user, active: true)
  inactive_user = create(:user, active: false)

  expect(User.active).to include(active_user)
  expect(User.active).not_to include(inactive_user)
end

# ❌ WRONG - build doesn't persist
# User.active scope won't find built records
```

### Use Case 5: Uniqueness Validations

```ruby
# ✅ CORRECT - Uniqueness needs DB
it 'validates email uniqueness' do
  create(:user, email: 'test@example.com')
  duplicate = build(:user, email: 'test@example.com')

  expect(duplicate).not_to be_valid
  expect(duplicate.errors[:email]).to include('has already been taken')
end

# ❌ WRONG - build won't check DB uniqueness
```

### Use Case 6: Associations in Tests

```ruby
# ❌ SLOW - Creates all associations
it 'shows user info' do
  facility = create(:facility)
  user = create(:user, facility: facility)

  expect(user.facility.name).to eq(facility.name)
end

# ✅ FAST - No DB needed for attribute access
it 'shows user info' do
  facility = build_stubbed(:facility, name: 'Test Facility')
  user = build(:user, facility: facility)

  expect(user.facility.name).to eq('Test Facility')
end

# Impact: 550ms → 3ms (183x faster)
```

### Use Case 7: Facility Special Case

```ruby
# ❌ VERY SLOW - Creates merchants, courts, products, etc.
let(:facility) { create(:facility) }
# Creates: 40+ associated records = 500ms

# ✅ BETTER - Skips associations
let(:facility) { create(:facility, :skip_callbacks) }
# Creates: Just facility = 180ms

# ✅ BEST - No DB if not needed
let(:facility) { build_stubbed(:facility) }
# No DB = 2ms

# Decision:
# - Need to query? → create(:facility, :skip_callbacks)
# - Just association? → build_stubbed(:facility)
# - Just attributes? → build(:facility)
```

### Use Case 8: Lists of Records

```ruby
# ❌ SLOW - Creates 10 DB records
let(:users) { create_list(:user, 10) }
# 10 × 60ms = 600ms

# ✅ FAST - Stubbed records with IDs
let(:users) { build_stubbed_list(:user, 10) }
# 10 × 0.5ms = 5ms

# ✅ CORRECT - Only if testing queries
it 'finds users by status' do
  active_users = create_list(:user, 5, active: true)
  expect(User.where(active: true).count).to eq(5)
end
```

## Common Mistakes

### Mistake 1: create() for everything

```ruby
# ❌ WASTEFUL
describe User do
  let(:user) { create(:user) }           # 60ms
  let(:facility) { create(:facility) }   # 500ms
  let(:membership) { create(:membership) } # 80ms

  it 'validates email format' do
    user.email = 'invalid'
    expect(user).not_to be_valid
  end
end
# Total: 640ms for a simple validation test!

# ✅ OPTIMIZED
describe User do
  subject(:user) { build(:user) }  # <1ms

  it 'validates email format' do
    user.email = 'invalid'
    expect(user).not_to be_valid
  end
end
# Total: <1ms
```

### Mistake 2: create() in before blocks

```ruby
# ❌ SLOW - Runs before EVERY test
before(:each) do
  @facility = create(:facility)
  @users = create_list(:user, 5)
end
# If 10 tests: 10 × 800ms = 8 seconds!

# ✅ FAST - Only if needed
let(:facility) { build_stubbed(:facility) }
let(:users) { build_stubbed_list(:user, 5) }
# If 10 tests: 10 × 7ms = 70ms
```

### Mistake 3: Not using :skip_callbacks for facility

```ruby
# ❌ VERY SLOW
let(:facility) { create(:facility) }

# ✅ MUCH BETTER
let(:facility) { create(:facility, :skip_callbacks) }

# Impact: 500ms → 180ms per test
# On 100 tests with facility: 32 seconds saved
```

## Auto-Optimization Patterns

These patterns can be auto-fixed by `/factory-check`:

1. ✅ `create(:user)` → `build(:user)` when testing validations
2. ✅ `create(:facility)` → `create(:facility, :skip_callbacks)`
3. ✅ `create(:user)` → `build_stubbed(:user)` when only `.id` used
4. ⚠️ `create_list` → `build_stubbed_list` (needs human review)

## Integration Tests vs Unit Tests

### Unit Tests (Models, Services)
```ruby
# Prefer build/build_stubbed
describe UserService do
  let(:user) { build_stubbed(:user) }
  let(:facility) { build(:facility) }
end
```

### Integration Tests (Controllers, GraphQL)
```ruby
# Need create for DB queries
describe UsersController do
  let(:user) { create(:user) }

  it 'lists users' do
    get :index
    expect(response.body).to include(user.email)
  end
end
```

### System Tests (Playwright)
```ruby
# Always create - testing full stack
let(:admin_user) do
  create(:user, :admin, email: "admin_#{SecureRandom.hex(4)}@example.com")
end
```

## Checklist

Before writing spec, ask:

- [ ] Does test query database? → `create`
- [ ] Does code check `.id`? → `build_stubbed`
- [ ] Testing validations only? → `build`
- [ ] Testing methods only? → `build`
- [ ] Using facility? → Consider `:skip_callbacks`
- [ ] Creating list? → Consider `build_stubbed_list`

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**If you discover**:
- New factory patterns
- Better performance optimizations
- Edge cases in decision tree

**Update this file** using Edit tool with format:
`<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements**:
<!-- Kaizen entries will be added here -->
