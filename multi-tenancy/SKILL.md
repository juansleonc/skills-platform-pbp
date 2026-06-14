---
name: multi-tenancy
description: Validate multi-tenant data isolation. Ensures all queries are properly scoped by facility_id to prevent data leakage between tenants.
allowed-tools: [Bash, Read, Grep, Glob, Edit, mcp__clickhouse__run_query]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## When to Use This Skill

Run this skill when:
- **Adding/modifying database queries** in models, services, controllers, or GraphQL resolvers
- **Creating new features** that access facility-scoped data (reservations, users, payments, memberships)
- **Reviewing PRs** that touch data access patterns
- **Before production deployment** of features that query multi-tenant tables
- **Investigating data leakage bugs** reported by facilities

## Shared References

> **📚 This skill uses shared documentation. See:**
> - [Critical Rules](../shared/critical-rules.md) - multi-tenancy rules
> - [ClickHouse Queries](../shared/clickhouse-queries.md) - production verification
> - Use `Grep` and `Glob` for symbol-level discovery of facility-scoped queries
> - [ast-grep Patterns](../shared/ast-grep-patterns.md) — AST-aware detection of unscoped `find(params[:id])` (no comment/string false positives)

# Multi-Tenancy Validation Skill

Validates that all data access is properly scoped to ensure tenant isolation across three levels:
1. **Facility Level** - Primary tenant (facility_id)
2. **Facility Group Level** - Related facilities under same ownership
3. **Franchise Level** - Parent-child facility relationships

## CRITICAL RULES

**1. All queries MUST be scoped to the correct facility** via a direct `facility_id` column OR the canonical association path for that table (see Tenancy Map below). Not all tables carry `facility_id` directly — using the wrong pattern (e.g. `User.where(facility_id:)` when `users` has no such column) silently bypasses isolation or raises a column error. Unless explicitly accessing:
- Admin-level data (with query override)
- Global/system configurations
- Franchise/Group-level aggregations (documented)

**2. Cross-facility queries require documented justification**

**3. Facility groups require bidirectional scoping**

## Why This Matters

Data leakage between facilities is a **critical security vulnerability**. A user at Facility A should NEVER see data from Facility B.

## Multi-Tenancy Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                        FRANCHISE OWNER                           │
│         (Can access all facilities they own)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────┐    ┌─────────────────────┐             │
│  │  FACILITY GROUP A   │    │  FACILITY GROUP B   │             │
│  │  (Related venues)   │    │  (Related venues)   │             │
│  ├─────────────────────┤    ├─────────────────────┤             │
│  │ ┌───────┐ ┌───────┐ │    │ ┌───────┐ ┌───────┐ │             │
│  │ │Fac 1  │ │Fac 2  │ │    │ │Fac 3  │ │Fac 4  │ │             │
│  │ └───────┘ └───────┘ │    │ └───────┘ └───────┘ │             │
│  └─────────────────────┘    └─────────────────────┘             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Level 1: Facility Scoping (Primary)

```ruby
# REQUIRED - Basic tenant isolation
facility.reservations.where(status: 'active')
current_facility.users.find_by(email: email)
```

### Level 2: Facility Group Scoping

```ruby
# Facility groups share certain data (webhooks, settings)
class Webhooks::Url < ApplicationRecord
  # Group validation - can only belong to facilities in same group
  validate :same_facility_group

  private

  def same_facility_group
    return unless facilities.any?
    groups = facilities.map(&:facility_group_id).compact.uniq
    if groups.size > 1
      errors.add(:base, "All facilities must be in the same group")
    end
  end
end

# Query within group
Facility.where(facility_group_id: current_facility.facility_group_id)
```

### Level 3: Parent-Child Relationships

```ruby
# Parent facility with child locations
class Facility < ApplicationRecord
  belongs_to :parent_facility, class_name: 'Facility', optional: true
  has_many :child_facilities, class_name: 'Facility', foreign_key: 'parent_facility_id'

  def family_facilities
    if parent_facility.present?
      parent_facility.child_facilities.or(Facility.where(id: parent_facility.id))
    else
      child_facilities.or(Facility.where(id: id))
    end
  end
end

# Query across family (reservations has no facility_id — go through courts)
def franchise_reservations
  court_ids = current_facility.family_facilities.joins(:courts).pluck('courts.id')
  Reservation.where(court_id: court_ids)
end
```

## Tenancy Map — Per-Table Scoping Reference

Not all tables carry `facility_id` directly. Use the correct association path for each model.

| Table / Model | facility_id column? | Correct scoping pattern | Source |
|---|---|---|---|
| `courts` | YES (direct) | `Court.where(facility_id:)` or `facility.courts` | courts.facility_id direct FK |
| `payments` | YES (direct) | `Payment.where(facility_id:)` or `facility.payments` | facility.rb:275 `has_many :payments` |
| `users` | NO — global records, M2M via join tables | `facility.users` (through `facilities_users`) or `facility.users_who_linked` (through `facility_user_links`) | facility.rb:202 `has_many :users, through: :facilities_users` |
| `reservations` | NO — scoped via `court_id` | `facility.reservations` (through courts) | reservation.rb:138 `has_one :facility, through: :court`; facility.rb:183 `has_many :reservations, through: :courts` |
| `memberships` | NO — scoped via `membership_plan` chain | `facility.memberships` (through membership_plans) | membership.rb:147 `delegate :owner_facility, to: :membership_plan`; membership.rb:99 `belongs_to :purchased_at_facility` |

**Key rule**: never write `User.where(facility_id: ...)`, `Reservation.where(facility_id: ...)`, or `Membership.where(facility_id: ...)` — those columns do not exist. Always traverse the association path.

## Audit Process

### Step 1: Identify Data Access Points

```bash
# Find model queries
grep -rn "\.where\|\.find_by\|\.find\|\.first\|\.last" <changed_files> --include="*.rb"

# Find scope definitions
grep -rn "scope :" <changed_files> --include="*.rb"

# Find service data access
grep -rn "Model\.where\|Model\.find" <changed_files> --include="*.rb"
```

### Step 2: Verify Facility Scoping

For each data access, verify one of these patterns:

```ruby
# GOOD - Scoped through association (users/reservations/memberships have no facility_id column)
facility.users.find_by(email: email)           # users: scope via facilities_users join
facility.reservations.find_by(id: id)         # reservations: scope via courts
facility.memberships.where(aasm_state: 'active') # memberships: scope via membership_plans

# GOOD - Explicit facility_id (only valid for tables that have the column)
Payment.where(facility_id: facility.id)       # payments: direct facility_id column
Court.where(facility_id: facility.id)         # courts: direct facility_id column

# GOOD - Using current_facility helper
current_facility.courts.available
current_facility.payments.where(status: 'paid')
```

### Step 3: Identify Violations

**IMPORTANT**: The examples below are real pattern instances verified against the codebase (2026-06-10). Presence of the pattern does NOT automatically confirm a security violation — authorization may be enforced deeper in the call chain or via other mechanisms. Each instance needs intent verification before filing as a bug.

**PATTERN 1: Global Court lookup in GraphQL — no facility scope at lookup site**
```ruby
# app/graphql/types/query_type.rb:111-113 (verified 2026-06-10)
def court(**params)
  Court.find(params[:id])   # no facility scope at lookup site
end
# Note: courts.facility_id exists; a scope would be Court.where(facility_id: ...).find(params[:id])
# Verify intent: this is a public GraphQL field; check if auth enforced downstream.
```

**PATTERN 2: Global Reservation lookup in GraphQL mutation**
```ruby
# app/graphql/mutations/reservation_add_user.rb:19 (verified 2026-06-10)
reservation = Reservation.find(params[:reservation_id])
# Note: reservations has no facility_id; scope would be via facility.reservations.find(...)
# Delegates to Booking::Actions::AddUser with current_user — auth may live inside that action.
```

**PATTERN 3: Global Payment lookup in downloads controller**
```ruby
# app/controllers/downloads_controller.rb:36 (verified 2026-06-10)
@payment = Payment.find(params[:id])
# Note: payments.facility_id exists; a scope would be current_facility.payments.find(params[:id])
# Controller uses token-based auth (before_action :verify_auth_with_token) — verify if that scopes.
```

**Counter-example (global-by-design — NOT a violation)**
```ruby
# app/graphql/mutations/generate_magic_link.rb:11 (verified 2026-06-10)
user = User.find_by(email: email)
# Users are GLOBAL records (no facility_id column). Cross-facility lookup at login is correct
# by design. This is an example of intentional global access, not a missing scope.
```

### Step 4: Verify in Production Data

> 📖 **See [ClickHouse Queries](../shared/clickhouse-queries.md) for more queries.**
> **Schema note**: `users` and `reservations` have NO `facility_id` column. Use `courts` or `payments` for facility-distribution checks. Use JOIN through `courts` for reservation distribution.

Use ClickHouse to verify data isolation patterns:

```sql
-- Check if a table that SHOULD have facility_id actually has it (e.g. courts, payments)
SELECT column_name, data_type
FROM system.columns
WHERE database = 'pbp_productionDB_optimized'
AND table = 'courts'
AND column_name = 'facility_id';
```
**Expected**: `1 row: facility_id | Int64`
**If 0 rows**: ❌ CRITICAL — Table missing facility_id (data leakage risk)

```sql
-- Check for orphaned court records (no facility_id)
SELECT count(*) as orphaned
FROM pbp_productionDB_optimized.courts
WHERE facility_id IS NULL OR facility_id = 0;
```
**Expected**: `0 rows` (all courts must have facility_id)
**If >0**: ❌ Data integrity issue — orphaned court records found

```sql
-- Verify reservation distribution across facilities (via courts join — reservations has no facility_id)
SELECT c.facility_id, count(*) as record_count
FROM pbp_productionDB_optimized.reservations r
JOIN pbp_productionDB_optimized.courts c ON r.court_id = c.id
GROUP BY c.facility_id
ORDER BY record_count DESC
LIMIT 20;
```
**Expected**: Multiple facilities with reasonable distribution
**If 1 facility has 90%+**: ⚠️ Possible data leak or test data contamination

```sql
-- Verify payment distribution across facilities (payments has direct facility_id)
SELECT facility_id, count(*) as record_count
FROM pbp_productionDB_optimized.payments
GROUP BY facility_id
ORDER BY record_count DESC
LIMIT 20;
```

### Step 5: Verify Facility Group Boundaries

```sql
-- Check webhooks crossing group boundaries (VIOLATION)
SELECT
  wu.id as webhook_id,
  wu.name,
  count(DISTINCT f.facility_group_id) as group_count
FROM pbp_productionDB_optimized.webhooks_urls wu
JOIN pbp_productionDB_optimized.webhooks_facility_urls wuf ON wuf.webhooks_url_id = wu.id
JOIN pbp_productionDB_optimized.facilities f ON f.id = wuf.facility_id
GROUP BY wu.id, wu.name
HAVING group_count > 1;

-- Check parent-child consistency
SELECT
  f.id,
  f.name,
  f.parent_facility_id,
  pf.name as parent_name
FROM pbp_productionDB_optimized.facilities f
LEFT JOIN pbp_productionDB_optimized.facilities pf ON f.parent_facility_id = pf.id
WHERE f.parent_facility_id IS NOT NULL
  AND pf.id IS NULL;  -- Orphaned parent references
```

## Quick Validation Commands

**Fast violation detection** (run these first):

```bash
# Find unscoped queries (HIGH RISK)
grep -rn "User\.find\|User\.where\|User\.find_by" app/ --include="*.rb" | grep -v "facility\|current_facility"

# Find global model queries (MEDIUM RISK)
grep -rn "Reservation\.find\|Payment\.find\|Membership\.find" app/ --include="*.rb" | grep -v "facility"

# Find params[:id] usage without facility scope (HIGH RISK)
grep -rn "\.find(params\[:id\])" app/ --include="*.rb"

# Find .all without scoping (MEDIUM RISK)
grep -rn "\.all\b" app/ --include="*.rb" | grep -v "facility\|admin"
```

**Expected**: Zero matches (all queries should include facility scoping)

> Use `Grep` and `Glob` for symbol-level discovery.
>
> **📖 See [ast-grep Patterns](../shared/ast-grep-patterns.md)** when `sg` is installed: `sg run --lang ruby --pattern '$M.find(params[:id])' app/ packs/` matches only real `.find(params[:id])` call expressions — avoids both the comment/string false positives AND the false negatives caused by the fragile `grep -v facility` filter (which kills correctly scoped `@facility.x.find(params[:id])` lines). Otherwise this grep is the right tool.

## Patterns

### Model Scoping

```ruby
# GOOD - Default scope (use cautiously — only on models WITH a facility_id column)
class Court < ApplicationRecord
  # courts.facility_id exists (verified db/structure.sql)
  default_scope { where(facility_id: Current.facility&.id) if Current.facility }
end

# BETTER - Explicit scoping via association
class Facility < ApplicationRecord
  has_many :courts                          # courts.facility_id direct FK
  has_many :reservations, through: :courts  # reservations has NO facility_id — go through courts
  has_many :users, through: :facilities_users
end

# Query through facility
facility.courts.where(active: true)
facility.reservations.where(status: 'confirmed')  # scoped via courts join
```

### Controller Pattern

```ruby
# GOOD - Always scope through current_facility
class ReservationsController < ApplicationController
  def index
    @reservations = current_facility.reservations.includes(:user)
  end

  def show
    @reservation = current_facility.reservations.find(params[:id])
    # This will raise RecordNotFound if ID belongs to another facility
  end
end
```

### Service Pattern

```ruby
# GOOD - Require facility in constructor
class ReservationService
  def initialize(facility:)
    @facility = facility
  end

  def available_slots(date)
    @facility.courts.available_on(date)
  end
end

# Usage
service = ReservationService.new(facility: current_facility)
```

### GraphQL Pattern

```ruby
# GOOD - Scope in resolver
class ReservationsResolver < BaseResolver
  def resolve
    context[:current_facility].reservations.active
  end
end
```

## Exceptions (MUST BE DOCUMENTED)

### Exception 1: Admin Query Override

```ruby
# Admin users can access cross-facility data
# MUST be explicitly documented and audited
class AdminUsersController < AdminController
  def index
    # ADMIN OVERRIDE: Cross-facility access for support
    @users = User.all.includes(:facilities)
  end
end
```

### Exception 2: Franchise Aggregation

```ruby
# Franchise-level reporting (documented exception)
# FRANCHISE OVERRIDE: Aggregate across owned facilities
class FranchiseReportsController < FranchiseController
  def revenue
    @revenue = current_franchise.facilities.sum(:monthly_revenue)
  end
end
```

### Exception 3: Facility Group Shared Resources

```ruby
# Webhooks can be shared within a facility group
# GROUP OVERRIDE: Same facility_group_id only
class WebhookService
  def facilities_for_webhook(webhook)
    # Only facilities in same group can share webhook
    webhook.facilities.where(facility_group_id: primary_facility.facility_group_id)
  end
end
```

### Exception 4: Parent-Child Cross-Access

```ruby
# Child facility accessing parent resources
# PARENT-CHILD OVERRIDE: Documented family relationship
class FamilyMembershipService
  def shared_plans
    # Child can see parent's membership plans
    # MembershipPlan uses owner_facility_id (belongs_to :owner_facility) — NOT facility_id
    MembershipPlan.where(owner_facility: current_facility.family_facilities)
  end
end
```

## Checklist

For each data access in changed code:

### Basic Scoping
- [ ] Query includes `facility_id` scope OR
- [ ] Query goes through facility association OR
- [ ] Query uses `current_facility` helper

### Group/Franchise Scoping (if applicable)
- [ ] Group queries validate `facility_group_id` consistency
- [ ] Parent-child queries use `family_facilities` scope
- [ ] Cross-facility webhooks are same group only

### Exceptions (if applicable)
- [ ] Query is documented admin override OR
- [ ] Query is documented franchise aggregation OR
- [ ] Query is documented group-level shared resource

## Report Format

> **Note**: The paths below are HYPOTHETICAL placeholders — they do not correspond to real files in the codebase.

```markdown
## Multi-Tenancy Audit

### Files Analyzed
- app/services/example_service.rb
- app/controllers/api/example_controller.rb

### Data Access Points Found: 5

### Properly Scoped: 4
| Location | Pattern | Status |
|----------|---------|--------|
| example_service.rb:23 | facility.reservations | ✅ |
| api/example_controller.rb:15 | current_facility.reservations | ✅ |

### Violations Found: 1
| Location | Code | Risk | Fix |
|----------|------|------|-----|
| example_service.rb:45 | `User.find(user_id)` | HIGH | Use `facility.users.find(user_id)` |

### Recommendations
1. Fix violation at example_service.rb:45
2. Add facility scope to User lookup
```

## Example

> **Note**: The paths below are HYPOTHETICAL for illustration purposes — they do not correspond to real files in the codebase. For real instances verified against the repo see Step 3 above.

```
User: /multi-tenancy

Claude:
## Multi-Tenancy Audit

### Scanning changed files...
Files: app/services/hypothetical_booking_service.rb  # <-- HYPOTHETICAL PATH

### Data Access Points
Line 23: facility.memberships.active              ✅ Properly scoped (via membership_plans chain)
Line 45: User.find_by(email: params[:email])      ⚠️ CHECK INTENT — users are global; OK for login/magic-link, NOT OK for facility-scoped lookups
Line 67: current_facility.payments.create         ✅ Properly scoped (payments has facility_id)
Line 89: Reservation.find(params[:id])            ❌ UNSCOPED — reservations has no facility_id; scope via facility.reservations.find(...)

### Patterns Requiring Review: 2

#### Line 45 — User lookup (check intent)
```ruby
# Global lookup — correct for cross-facility auth flows (magic link, login)
user = User.find_by(email: params[:email])

# If this is a facility-scoped lookup (e.g. "does this user belong to MY facility"):
user = facility.users.find_by(email: params[:email])
```

#### Line 89 — Reservation without facility scope
```ruby
# UNSCOPED
reservation = Reservation.find(params[:id])

# SCOPED (reservations has no facility_id; go through facility association)
reservation = current_facility.reservations.find(params[:id])
```

### Action Required
Verify intent on User lookup; fix Reservation scope.
```

---

## Related Skills

This skill works with:
- **`/security`** - Validates authorization patterns, use together for comprehensive security audit
- **`/performance`** - Checks N+1 queries on facility associations (run after this)
- **`/code-review`** - Comprehensive review includes multi-tenancy checks
- **`/graphql`** - Validates GraphQL resolver scoping (run for API changes)

**Workflow**: `/orchestrate feature` automatically includes multi-tenancy validation in Phase 1B

---

## Kaizen

When you discover a new scoping pattern, missing violation pattern, or better ClickHouse query during an audit, run `/kaizen` separately after completing the audit. Do not self-edit this file mid-execution.

> Full improvement history: [kaizen_log.md](kaizen_log.md)
