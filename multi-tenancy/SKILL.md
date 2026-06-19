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

> Base multi-tenancy rules live in [Critical Rules](../shared/critical-rules.md). The rule **unique to
> this skill**: scope via the *correct column or association path per table* — not every table has a
> `facility_id` column (see Tenancy Map). Using the wrong pattern (e.g. `User.where(facility_id:)` when
> `users` has none) silently bypasses isolation or raises a column error. Data leakage between
> facilities is a critical security vulnerability: a user at Facility A must NEVER see Facility B data.

Scope-bypass is allowed ONLY for documented exceptions: admin overrides, global/system config, and
franchise/group aggregations. Cross-facility queries need written justification; facility groups need
bidirectional scoping.

## Multi-Tenancy Hierarchy

> ASCII hierarchy diagram (Franchise → Group → Facility): [reference/hierarchy.md](reference/hierarchy.md).

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
| `payments` | YES (direct) | `Payment.where(facility_id:)` or `facility.payments` | facility.rb:276 `has_many :payments` |
| `users` | NO — global records, M2M via join tables | `facility.users` (through `facilities_users`) or `facility.users_who_linked` (through `facility_user_links`) | facility.rb:203 `has_many :users, through: :facilities_users` |
| `reservations` | NO — scoped via `court_id` | `facility.reservations` (through courts) | reservation.rb:138 `has_one :facility, through: :court`; facility.rb:184 `has_many :reservations, through: :courts` |
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
# app/graphql/types/query_type.rb:115-116 (verified 2026-06-14)
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
# app/controllers/downloads_controller.rb:35-36 (verified 2026-06-14)
@payment = Payment.find(params[:id]) if Payment.exists?(id: params[:id])
# Note: the live code guards with Payment.exists?(id:) before find — but still no facility scope.
# payments.facility_id exists; a scope would be current_facility.payments.find(params[:id]).
# Controller uses token-based auth (before_action :verify_auth_with_token) — verify if that scopes.
```

**Counter-example (global-by-design — NOT a violation)**
```ruby
# app/graphql/mutations/generate_magic_link.rb:11 (verified 2026-06-10)
user = User.find_by(email: email)
# Users are GLOBAL records (no facility_id column). Cross-facility lookup at login is correct
# by design. This is an example of intentional global access, not a missing scope.
```

### Step 4: Verify in Production Data (ClickHouse)

> 📖 Full query set — column check, orphaned records, distribution, group boundaries, reservation
> distribution (courts join), parent-child consistency — in
> [ClickHouse Queries](../shared/clickhouse-queries.md) §4–7c.
> **Schema note**: `users` and `reservations` have NO `facility_id`. Use `courts`/`payments` for
> distribution checks; JOIN through `courts` for reservation distribution.

Two canonical checks (rest in the shared doc):

```sql
-- 1. Does a table that SHOULD carry facility_id actually have it? (e.g. courts, payments)
SELECT column_name, data_type
FROM system.columns
WHERE database = 'pbp_productionDB_optimized'
  AND table = 'courts' AND column_name = 'facility_id';
-- Expected 1 row (facility_id | Int64). 0 rows = CRITICAL: missing column, leakage risk.

-- 2. Webhooks crossing facility-group boundaries (VIOLATION if any rows)
SELECT wu.id, wu.name, count(DISTINCT f.facility_group_id) AS group_count
FROM pbp_productionDB_optimized.webhooks_urls wu
JOIN pbp_productionDB_optimized.webhooks_facility_urls wuf ON wuf.webhooks_url_id = wu.id
JOIN pbp_productionDB_optimized.facilities f ON f.id = wuf.facility_id
GROUP BY wu.id, wu.name HAVING group_count > 1;
-- Expected 0 rows.
```

## Quick Validation Commands

**Fast violation detection** (HIGH unless noted). Zero matches expected:

```bash
grep -rn "User\.find\|User\.where\|User\.find_by" app/ --include="*.rb" | grep -v "facility\|current_facility"  # unscoped User
grep -rn "Reservation\.find\|Payment\.find\|Membership\.find" app/ --include="*.rb" | grep -v "facility"        # global model lookups (MEDIUM)
grep -rn "\.find(params\[:id\])" app/ --include="*.rb"                                                          # unscoped params[:id]
grep -rn "\.all\b" app/ --include="*.rb" | grep -v "facility\|admin"                                           # unscoped .all (MEDIUM)
```

> **📖 Prefer [ast-grep Patterns](../shared/ast-grep-patterns.md)** when `sg` is installed:
> `sg run --lang ruby --pattern '$M.find(params[:id])' app/ packs/` matches only real call expressions
> — avoids comment/string false positives AND the false negatives of `grep -v facility` (which kills
> correctly scoped `@facility.x.find(params[:id])`). Otherwise the grep above is the right tool.

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

## Exceptions (MUST BE DOCUMENTED + AUDITED)

Each scope-bypass below is legitimate ONLY with an inline `# <KIND> OVERRIDE:` comment explaining why.

| Override kind | Scope rule | Canonical example |
|---|---|---|
| Admin | Cross-facility, support/admin context only | `User.all.includes(:facilities)` in an `AdminController` |
| Franchise aggregation | Aggregate across owned facilities | `current_franchise.facilities.sum(:monthly_revenue)` |
| Facility group shared | Same `facility_group_id` only | `webhook.facilities.where(facility_group_id: primary_facility.facility_group_id)` |
| Parent-child | Documented family relationship | `MembershipPlan.where(owner_facility: current_facility.family_facilities)` — note: `MembershipPlan` uses `owner_facility_id`, NOT `facility_id` |

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

## Output Format & Worked Example

> Audit-output template + a full worked transcript (all HYPOTHETICAL paths — real instances are in
> Step 3 above): [reference/output-templates.md](reference/output-templates.md).

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
