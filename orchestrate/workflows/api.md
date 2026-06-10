# GraphQL API Changes Workflow

> 📡 **Mobile-safe API evolution with backward compatibility validation**

## Command

```bash
/orchestrate api
```

## Overview

Specialized workflow for GraphQL API changes:
- Backward compatibility validation (CRITICAL for mobile apps)
- Security and auth pattern validation
- Performance optimization (N+1 prevention, deferred queries)
- Multi-tenancy enforcement
- Comprehensive request spec testing

**Time**: 18-25min average
**Risk**: HIGH (breaking changes brick mobile apps)
**Critical**: 108 mutations used by mobile - NEVER break them

## Workflow Diagram

```
┌─ SEQUENTIAL (Compatibility Check) ────────────────┐
│  graphql: Check backward compatibility            │
│    → Mobile app mutation analysis (108 mutations) │
│    → Breaking change detection                    │
│    → Deprecation warnings                         │
│    → Query complexity analysis                    │
│    → Deferred query validation                    │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Analysis) ─────────────────────────────┐
│  Run 3 independent validators concurrently:       │
│                                                    │
│  ├── performance: Check N+1 in resolvers          │
│  │    → Resolver batching                         │
│  │    → Lazy loading detection                    │
│  │    → Query count analysis                      │
│  │    → Deferred query usage                      │
│  │                                                 │
│  ├── security: Check auth patterns                │
│  │    → Resolver authorization                    │
│  │    → Field-level permissions                   │
│  │    → Rate limiting                             │
│  │    → Input validation                          │
│  │                                                 │
│  └── multi-tenancy: Verify facility scoping       │
│       → All queries facility-scoped               │
│       → No cross-facility data leaks              │
│       → Context[:current_facility] used           │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (TDD) ────────────────────────────────┐
│  tdd: Request specs for mutations/queries         │
│    → Test all input variations                    │
│    → Test error cases                             │
│    → Test auth/permissions                        │
│    → Test response structure                      │
│    → Test deferred queries                        │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Quality) ──────────────────────────────┐
│  ├── coverage: 100% on GraphQL changes            │
│  │    → All resolvers tested                      │
│  │    → All mutations tested                      │
│  │                                                 │
│  └── code-review: Verify deferred queries         │
│       → Deferred queries used for associations    │
│       → No N+1 queries                            │
│       → Resolver complexity reasonable            │
└───────────────────────────────────────────────────┘
                        ↓
┌─ STOP - Ready for User Commit ───────────────────┐
│  🚫 orchestrate CANNOT create commits             │
│  ✅ Tell user: "API changes validated"            │
│  📝 Tell user: "Run /commit when ready"           │
│  ⚠️ Critical: Test in staging with mobile app     │
│  ⚠️ If breaking: Coordinate mobile app release    │
└───────────────────────────────────────────────────┘
```

## Why API-Specific Workflow?

**Mobile App Dependency**:
- 108 mutations actively used by iOS/Android apps
- Breaking changes = app crashes for users
- Can't force users to update immediately
- Must maintain backward compatibility

**Performance Critical**:
- GraphQL can easily cause N+1 queries
- Mobile apps on slow networks need fast responses
- Deferred queries essential for performance

**Security Sensitive**:
- API exposed to internet
- Auth/permissions must be perfect
- Rate limiting required
- Input validation critical

## Phase Details

### Phase 1: Compatibility Check (Sequential)

**Goal**: Detect breaking changes BEFORE they reach production

**Skill Used**: `/graphql`

**What It Validates**:

#### 1.1 Breaking Changes (CRITICAL)
| Change Type | Breaking? | Mobile Impact |
|-------------|-----------|---------------|
| Remove field | ❌ YES | App crashes |
| Remove mutation | ❌ YES | Feature breaks |
| Change field type | ❌ YES | Parse error |
| Rename field | ❌ YES | App uses old name |
| Add required arg | ❌ YES | Missing arg error |
| Add optional field | ✅ NO | Safe (ignored if not used) |
| Add optional arg | ✅ NO | Safe (has default) |
| Deprecate field | ✅ NO | Warning only |

**Example Validation**:
```graphql
# ❌ BREAKING - Removes field used by mobile
type User {
  # email: String  # REMOVED - mobile app uses this!
  name: String
}

# ✅ SAFE - Deprecates but keeps
type User {
  email: String @deprecated(reason: "Use emailAddress instead")
  emailAddress: String
  name: String
}
```

---

#### 1.2 Mutation Analysis
```ruby
# Check if mutation used by mobile (108 critical mutations)
MOBILE_MUTATIONS = [
  'createReservation',
  'updateUser',
  'cancelMembership',
  # ... 105 more
]

# Validate:
# ✅ All mobile mutations still present
# ✅ No breaking arg changes
# ⚠️ Warn if deprecating mobile mutation
```

---

#### 1.3 Query Complexity
```ruby
# Detect complex queries that could DoS
query {
  users {            # 1000 users
    reservations {   # 100 reservations each = 100K queries
      court {        # N+1 on courts
        facility {   # N+1 on facilities
        }
      }
    }
  }
}

# Validation:
# ⚠️ Query complexity: 100K+ database queries
# ✅ Suggestion: Use deferred queries for associations
```

---

#### 1.4 Deferred Query Validation
```ruby
# ✅ GOOD - Uses deferred queries for associations
field :reservations, [Types::ReservationType], null: false, defer: true

# ❌ BAD - Lazy loading (causes N+1)
field :reservations, [Types::ReservationType], null: false
def reservations
  object.reservations # N+1 query
end
```

---

**Time**: 5-7min

**Pass Criteria**:
- Zero breaking changes (or coordinated mobile release)
- Query complexity acceptable (<1000 queries)
- Deferred queries used for associations

---

### Phase 2: Analysis (Parallel - 3 Validators)

All 3 run simultaneously:

#### 2.1 Performance Validation

**Skill**: `/performance`

**What It Checks**:
- N+1 queries in resolvers
- Batch loading patterns
- Deferred query usage
- Query count per request

**Example Violations**:
```ruby
# ❌ N+1 Query in resolver
def user
  User.find(object.user_id) # N+1 if called for multiple objects
end

# ✅ Fixed with batch loading
def user
  BatchLoader.for(object.user_id).batch do |ids, loader|
    User.where(id: ids).each { |u| loader.call(u.id, u) }
  end
end
```

**Test**:
```ruby
# Measure query count
expect {
  post graphql_path, params: { query: query }
}.to make_database_queries(count: 3) # Not 1000
```

**Time**: 3-4min

---

#### 2.2 Security Validation

**Skill**: `/security`

**What It Checks**:

**2.2.1 Resolver Authorization**
```ruby
# ❌ BAD - No auth check
def sensitive_data
  object.sensitive_data # Anyone can access
end

# ✅ GOOD - Auth check
def sensitive_data
  raise GraphQL::ExecutionError, 'Unauthorized' unless context[:current_user]
  object.sensitive_data
end
```

**2.2.2 Field-Level Permissions**
```ruby
# ✅ GOOD - Field-level permission
field :admin_notes, String, null: true do
  authorize :admin # Only admins can query
end
```

**2.2.3 Input Validation**
```ruby
# ❌ BAD - No validation
argument :email, String, required: true

# ✅ GOOD - Validated
argument :email, String, required: true do
  validate :email_format
end
```

**Time**: 2-3min

---

#### 2.3 Multi-Tenancy Validation

**Skill**: `/multi-tenancy`

**What It Checks**:
- All queries use `context[:current_facility]`
- No cross-facility data leaks
- Proper facility scoping

**Example Violations**:
```ruby
# ❌ BAD - Global query
def users
  User.all # Returns ALL users from ALL facilities
end

# ✅ GOOD - Facility-scoped
def users
  context[:current_facility].users
end
```

**Time**: 2-3min

---

**Total Phase 2 Time**: ~4-6min (parallel)

---

### Phase 3: TDD (Sequential - Request Specs)

**Goal**: Comprehensive GraphQL request specs

**Critical Test Cases**:

#### 3.1 Mutation Tests
```ruby
# spec/graphql/mutations/create_reservation_spec.rb
describe Mutations::CreateReservation do
  let(:mutation) do
    <<~GQL
      mutation($input: CreateReservationInput!) {
        createReservation(input: $input) {
          reservation {
            id
            status
          }
          errors
        }
      }
    GQL
  end

  context 'with valid input' do
    it 'creates reservation' do
      expect {
        post graphql_path, params: { query: mutation, variables: variables }
      }.to change(Reservation, :count).by(1)
    end

    it 'returns reservation data' do
      post graphql_path, params: { query: mutation, variables: variables }
      expect(json_response[:data][:createReservation][:reservation]).to include(
        status: 'pending'
      )
    end
  end

  context 'with invalid input' do
    let(:variables) { { input: { courtId: nil } } }

    it 'returns errors' do
      post graphql_path, params: { query: mutation, variables: variables }
      expect(json_response[:data][:createReservation][:errors]).to be_present
    end

    it 'does not create reservation' do
      expect {
        post graphql_path, params: { query: mutation, variables: variables }
      }.not_to change(Reservation, :count)
    end
  end

  context 'without authentication' do
    before { sign_out }

    it 'returns unauthorized error' do
      post graphql_path, params: { query: mutation, variables: variables }
      expect(json_response[:errors].first[:message]).to include('Unauthorized')
    end
  end

  context 'with wrong facility' do
    let(:other_facility) { create(:facility) }

    it 'does not access other facility data' do
      # Attempt to create reservation for court in other facility
      expect {
        post graphql_path, params: { query: mutation, variables: invalid_variables }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
```

---

#### 3.2 Query Tests
```ruby
# spec/graphql/queries/users_spec.rb
describe Queries::Users do
  let(:query) do
    <<~GQL
      query {
        users {
          id
          name
          email
        }
      }
    GQL
  end

  it 'returns users for current facility only' do
    facility_user = create(:user, facility: current_facility)
    other_user = create(:user, facility: other_facility)

    post graphql_path, params: { query: query }

    user_ids = json_response[:data][:users].map { |u| u[:id] }
    expect(user_ids).to include(facility_user.id.to_s)
    expect(user_ids).not_to include(other_user.id.to_s)
  end

  it 'does not cause N+1 queries' do
    create_list(:user, 10, facility: current_facility)

    expect {
      post graphql_path, params: { query: query }
    }.to make_database_queries(count: 2) # 1 for users, 1 for facility
  end
end
```

---

#### 3.3 Deferred Query Tests
```ruby
describe 'deferred queries' do
  let(:query) do
    <<~GQL
      query {
        users {
          id
          reservations {
            id
            court {
              name
            }
          }
        }
      }
    GQL
  end

  it 'uses deferred queries for associations' do
    create_list(:user, 5, :with_reservations, facility: current_facility)

    # Should batch load: users, reservations, courts
    expect {
      post graphql_path, params: { query: query }
    }.to make_database_queries(count: 3) # Not 5N+1
  end
end
```

---

**Time**: 8-12min

**Pass Criteria**:
- All mutations tested (happy + error + auth paths)
- All queries tested (data + auth + facility scoping)
- No N+1 queries
- 100% coverage on GraphQL code

---

### Phase 4: Quality (Parallel)

#### 4.1 Coverage
- 100% on resolver methods
- 100% on mutations
- All error paths tested

**Time**: 30s

---

#### 4.2 Code Review (Deferred Query Focus)
- ✅ Associations use deferred queries
- ✅ No N+1 detected
- ✅ Query complexity acceptable
- ✅ Auth patterns correct

**Time**: 2-3min

---

**Total Phase 4 Time**: ~3min (parallel)

---

## When to Use

✅ **Use this workflow for**:
- New GraphQL mutations
- New GraphQL queries
- Changes to existing API fields
- Adding/removing arguments
- Deprecating fields
- Performance optimization

❌ **Don't use for**:
- Internal API changes (REST)
- Non-API features
- Documentation updates

## Success Criteria

**ALL checks must pass**:
- ✅ No breaking changes (or coordinated release)
- ✅ Deferred queries used for associations
- ✅ No N+1 queries detected
- ✅ Auth/permissions correct
- ✅ Multi-tenancy enforced
- ✅ 100% test coverage
- ✅ Request specs for all mutations/queries

**If ANY fail**: Fix before committing

## Time Estimates

| Phase | Duration | Notes |
|-------|----------|-------|
| Compatibility | 5-7min | Breaking change detection |
| Analysis (parallel) | 4-6min | Performance + Security + Multi-tenancy |
| TDD (Request Specs) | 8-12min | Comprehensive API testing |
| Quality (parallel) | 3min | Coverage + Review |
| **Total** | **20-25min** | Avg 22min |

## Common API Issues

### 1. Breaking Changes (Mobile App Crashes)
**Problem**: Field removed, mobile app expects it
**Solution**: Deprecate field, keep for 6 months, coordinate mobile release

### 2. N+1 Queries
**Problem**: Lazy loading in resolvers
**Solution**: Use deferred queries or batch loaders

### 3. Missing Auth
**Problem**: Resolver doesn't check permissions
**Solution**: Add `authorize :permission` or manual check

### 4. Cross-Facility Leaks
**Problem**: Query doesn't scope by facility
**Solution**: Always use `context[:current_facility]`

## Best Practices

**DO** ✅:
- Use deferred queries for all associations
- Add request specs for every mutation/query
- Test auth/permissions explicitly
- Deprecate instead of remove
- Coordinate mobile releases for breaking changes
- Test with mobile app in staging

**DON'T** ❌:
- Remove fields without deprecation period
- Skip N+1 testing
- Assume mobile app updated (can't force users)
- Lazy load associations (causes N+1)
- Skip multi-tenancy validation

## Related Workflows

- **After API changes**: `/orchestrate pre-commit` (validate)
- **Performance**: `/orchestrate performance-optimize` (if slow)
- **Breaking change**: Coordinate with mobile team first

---

**Back to**: [orchestrate skill](../SKILL.md) | [quick reference](../quick_reference.md) | [workflows index](README.md)
