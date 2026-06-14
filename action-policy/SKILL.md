---
name: action-policy
description: Validates Action Policy implementations for correctness, naming conventions, and coexistence with CanCanCan. Use when creating policies, migrating controllers, or reviewing authorization code.
allowed-tools: [Bash, Read, Grep, Glob, Edit]
disable-model-invocation: false
---

> **Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## When to Use

**Auto-trigger** (CLAUDE.local.md Skill Router): run this skill whenever:
- Adding or modifying files under `app/policies/**` or `packs/*/app/policies/**`
- Touching policy-related files in `packs/orgs`, `packs/internal_backend`, or `packs/billing`
- Creating a new API endpoint, WebSocket channel, or Sidekiq job that exposes admin/internal functionality (authorization parity — CLAUDE.md rule #12)
- Reviewing a PR that changes permission logic

> Note: the glob `*authorized_controller*` in the Skill Router no longer matches any real file.
> The real controller surfaces are `packs/orgs/app/controllers/api/v1/base_controller.rb` and
> `packs/internal_backend/app/controllers/internal/base_controller.rb`. Treat any change to those
> files as a trigger for this skill.

**Gate**: If authorization checks in a new endpoint are weaker than the UI that calls it, this is a blocker — do not merge.

## Shared References

> - [Critical Rules](../shared/critical-rules.md) - security rules
> - [Forbidden Patterns](../shared/forbidden-patterns.md) - patterns to avoid
> - Use `Grep` and `Glob` for policy hierarchy and reference lookup (Serena removed 2026-06-02)
> - [ast-grep Patterns](../shared/ast-grep-patterns.md) — structured `can :action, Model` rule extraction with captures

# Action Policy Validation Skill

Validates Action Policy implementations follow project conventions, ensure correct coexistence with CanCanCan, and match the patterns established in the two real authorization slices: `packs/orgs` (Org-member API) and `packs/internal_backend` (internal admin).

## Architecture Overview

The repo uses `action_policy = 0.7.6` (confirmed: `Gemfile` line 104). Action Policy is **not** wired into `ApplicationController` — it lives exclusively in two pack base controllers:

```
ApplicationController
|  rescue_from CanCan::AccessDenied          <- CanCanCan error handling
|  NO ActionPolicy::Controller               <- CRITICAL: not included here
|
+-- CanCanCan controllers (app/controllers, most packs)
|   +-- load_and_authorize_resource
|   +-- authorize! / can?
|
+-- packs/orgs/app/controllers/api/v1/base_controller.rb  (Orgs::Api::V1::BaseController)
|   |  include ActionPolicy::Controller
|   |  authorize :user, through: :current_user
|   |  authorize :permission_resolver, through: :org_permission_resolver
|   |  rescue_from ActionPolicy::Unauthorized, with: :forbidden
|   |  # permission_resolver built from membership's OrgRole
|   |
|   +-- Orgs API controllers
|       +-- authorize!(Resource, with: Orgs::XxxPolicy)
|       +-- authorized_scope(Model.all, with: Orgs::XxxPolicy)
|
+-- packs/internal_backend/app/controllers/internal/base_controller.rb  (Internal::BaseController)
|   |  include ActionPolicy::Controller
|   |  authorize :user, through: :current_user
|   |  authorize :permission_resolver, through: :permission_resolver
|   |  verify_authorized                    <- every action must call authorize!
|   |  rescue_from ActionPolicy::Unauthorized, with: :handle_unauthorized
|   |  # permission_resolver built from InternalPolicyAssignment + InternalRole
|   |
|   +-- Internal admin controllers
|       +-- authorize!(Resource, with: Internal::XxxPolicy)
|       +-- authorized_scope(Model.all, with: Internal::XxxPolicy)
|
+-- Api::V1::ApiMainController               <- Uses ApiAbility, unaffected
|   +-- ~110 API controllers
|
+-- GraphqlController                        <- Custom token auth, no CanCanCan/ActionPolicy
```

### Real Policy Locations

| Slice | Base policy | Domain policies | PermissionResolver |
|-------|------------|----------------|--------------------|
| Orgs API | `packs/orgs/app/policies/base_policy.rb` (`Orgs::BasePolicy`) | `packs/orgs/app/policies/` | `packs/orgs/app/services/permission_resolver.rb` (`Orgs::PermissionResolver`) |
| Internal admin | `packs/internal_backend/app/policies/internal/base_policy.rb` (`Internal::BasePolicy`) | `packs/internal_backend/app/policies/internal/` | `packs/internal_backend/app/services/internal/permission_resolver.rb` (`Internal::PermissionResolver`) |
| Billing | `packs/billing/app/policies/billing/` and `packs/billing/app/policies/internal/` | — | (`Billing::FacilityBillingPolicy` is a plain Ruby object, not `ActionPolicy::Base`) |

> `app/policies/` in the main app contains only `user_password_update_policy.rb` (a thin, unrelated file). There is no `ApplicationPolicy < ActionPolicy::Base` in the main app — do not grep there for base classes.

## Validation Checklist

### 1. Policy Structure

```bash
# Find all ActionPolicy base class policies
grep -rn "< ActionPolicy::Base" packs/orgs/app/policies/ packs/internal_backend/app/policies/

# Find all domain policies in both slices
ls packs/orgs/app/policies/
ls packs/internal_backend/app/policies/internal/

# Find all policies across packs (excludes node_modules)
grep -rn "class.*Policy" packs/*/app/policies/ --include="*.rb" | grep -v node_modules
```

**CORRECT patterns (Orgs slice)** — non-obvious parts only; `grep -n '' packs/orgs/app/policies/base_policy.rb` for the full class:
```ruby
# packs/orgs/app/policies/base_policy.rb  (key declarations)
class BasePolicy < ActionPolicy::Base
  include ActionPolicy::Policy::CachedApply
  authorize :user
  authorize :permission_resolver

  pre_check :allow_platform_admin!   # short-circuit for app_admin?
  pre_check :allow_wildcard!         # short-circuit for wildcard OrgRole

  default_rule :default?             # fallback: deny!(:no_permission)

  # Helper used by all domain policies — the ONLY way to check permissions
  def permitted?(permission)
    permission_resolver.can?(permission) || deny!(:insufficient_permission)
  end

  def permitted_any?(*permissions)
    permissions.any? { |p| permission_resolver.can?(p) } || deny!(:insufficient_permission)
  end
end

# Domain policy example:
class FacilityPolicy < BasePolicy
  def view? = permitted?('facilities.view')
  alias_rule :index?, :show?, to: :view?
end
```

**CORRECT patterns (Internal slice)** — non-obvious parts only; `grep -n '' packs/internal_backend/app/policies/internal/base_policy.rb` for the full class:
```ruby
# packs/internal_backend/app/policies/internal/base_policy.rb  (key declarations)
class BasePolicy < ActionPolicy::Base
  authorize :permission_resolver      # no :user authorization declared here

  pre_check :allow_platform_admins   # short-circuit for wildcard InternalRole

  default_rule :manage?              # fallback: deny!(:no_permission)

  def permitted?(permission)
    return true if permission_resolver.can?(permission)
    deny!(:insufficient_permission)
  end
end

# Domain policy example (one-liner syntax):
class FacilityPolicy < BasePolicy
  alias_rule :index?, :show?, to: :view?
  def view?    = permitted?('facilities.list')
  def create?  = permitted?('facilities.create')
end
```

**FORBIDDEN patterns** (Pundit leftovers):
```ruby
# WRONG: Pundit-style initialization
def initialize(user, record)
  @user = user
  @record = record
end

# WRONG: Pundit inner Scope class
class Scope < ApplicationPolicy::Scope
  def resolve
    scope.where(...)
  end
end
```

### 2. Controller Authorization Calls

```bash
# Check for correct authorize! usage in both pack controller trees
grep -rn "authorize!" packs/orgs/app/controllers/ packs/internal_backend/app/controllers/

# Check for WRONG Pundit-style authorize (no bang) — should find nothing
grep -rn "^\s*authorize[^!_:]" packs/*/app/controllers/ --include="*.rb" | grep -v "authorize_"
```

**CORRECT**:
```ruby
# Explicit policy class — preferred in this codebase
authorize!(Facility, with: Orgs::FacilityPolicy)
authorize!(@role, with: Orgs::RolePolicy)

# Explicit rule override
authorize!(:job, to: :index?, with: Internal::JobPolicy)

# Scoped collection
logs = authorized_scope(InternalAuditLog.all, with: Internal::AuditLogPolicy)
```

**FORBIDDEN**:
```ruby
# WRONG: Pundit-style authorize (no bang)
authorize @organization, :show?, policy_class: Orgs::OrganizationPolicy

# WRONG: Pundit-style policy_scope
policy_scope(Orgs::Organization)
```

### 3. Controller Setup

```bash
# Verify ActionPolicy::Controller only in the two pack base controllers
grep -rn "ActionPolicy::Controller" packs/*/app/controllers/ --include="*.rb"
# Expected: only base_controller.rb in packs/orgs and packs/internal_backend

# Verify ApplicationController does NOT include ActionPolicy::Controller
grep -n "ActionPolicy" app/controllers/application_controller.rb
```

**CORRECT (Orgs)**:
```ruby
# packs/orgs/app/controllers/api/v1/base_controller.rb
module Orgs::Api::V1
  class BaseController < ApplicationController
    include ActionPolicy::Controller

    authorize :user, through: :current_user
    authorize :permission_resolver, through: :org_permission_resolver

    rescue_from ActionPolicy::Unauthorized, with: :forbidden

    private

    def org_permission_resolver
      @org_permission_resolver ||= Orgs::PermissionResolver.new(@membership&.org_role ? @membership : nil)
    end
  end
end
```

**CORRECT (Internal)**:
```ruby
# packs/internal_backend/app/controllers/internal/base_controller.rb
module Internal
  class BaseController < ApplicationController
    include ActionPolicy::Controller

    authorize :user, through: :current_user
    authorize :permission_resolver, through: :permission_resolver

    verify_authorized   # every action must call authorize!

    rescue_from ActionPolicy::Unauthorized, with: :handle_unauthorized

    private

    def permission_resolver
      @permission_resolver ||= Internal::PermissionResolver.new(admin_user)
    end
  end
end
```

**FORBIDDEN**:
```ruby
# WRONG: Including in ApplicationController
class ApplicationController < ActionController::Base
  include ActionPolicy::Controller  # NO! This breaks CanCanCan isolation
end
```

### 4. Authorization Context

```bash
# Check context declarations in pack controllers and policies
grep -rn "authorize :" packs/orgs/app/policies/ packs/orgs/app/controllers/ --include="*.rb" | grep -v "authorize!"
grep -rn "authorize :" packs/internal_backend/app/policies/ packs/internal_backend/app/controllers/ --include="*.rb" | grep -v "authorize!"
```

**Rules for Orgs slice**:
- `user` — declared via `authorize :user` in `Orgs::BasePolicy`; provided via `current_user` in `BaseController`
- `permission_resolver` — declared via `authorize :permission_resolver` in `Orgs::BasePolicy`; provided via `org_permission_resolver` (builds `Orgs::PermissionResolver` from current membership's `OrgRole`)

**Rules for Internal slice**:
- `permission_resolver` — declared via `authorize :permission_resolver` in `Internal::BasePolicy`; provided via `Internal::PermissionResolver.new(admin_user)` (resolves from `InternalPolicyAssignment` + `InternalRole`)
- `user` — provided via `current_user` (passed as context but not declared in the base policy directly — resolved through the controller's `authorize :user, through: :current_user`)

### 5. Error Handling

```bash
# Verify correct error class in pack controllers
grep -rn "ActionPolicy::Unauthorized" packs/*/app/controllers/ --include="*.rb"
grep -rn "Pundit::NotAuthorizedError" packs/*/app/controllers/ --include="*.rb"  # Should find NOTHING
```

**CORRECT**:
```ruby
# Orgs slice
rescue_from ActionPolicy::Unauthorized, with: :forbidden

def forbidden
  render json: { error: 'Access denied' }, status: :forbidden
end

# Internal slice (with denial reasons)
rescue_from ActionPolicy::Unauthorized, with: :handle_unauthorized

def handle_unauthorized(exception)
  details = exception.result.reasons.to_h.flat_map { |_, v| v }.uniq
  render(json: {
    error: 'You do not have permission to perform this action',
    details: details
  }, status: :forbidden)
end
```

**Error classes reference**:
| Error | When |
|-------|------|
| `ActionPolicy::Unauthorized` | `authorize!` denies access |
| `ActionPolicy::UnauthorizedAction` | `verify_authorized` fails (forgot `authorize!`) |
| `ActionPolicy::UnscopedAction` | `verify_authorized_scoped` fails (forgot `authorized_scope`) |
| `ActionPolicy::AuthorizationContextMissing` | Required context not provided |

### 6. PermissionResolver Pattern

Both slices use a `PermissionResolver` service object (not an Action Policy built-in) to decouple permission lookup from policy logic. The resolver is built in the controller and injected as authorization context.

**Orgs::PermissionResolver** (`packs/orgs/app/services/permission_resolver.rb`):
- Initialized with an `Orgs::Membership`
- Resolves permissions from `membership.org_role.permissions`
- Wildcard role (`role.wildcard?`) → `['*']` → bypasses all checks via `allow_wildcard!` pre-check
- Also resolves facility scope (`scoped_facility_ids`) for data isolation

**Internal::PermissionResolver** (`packs/internal_backend/app/services/internal/permission_resolver.rb`):
- Initialized with a user
- Resolves permissions from `InternalPolicyAssignment` + `InternalRole` (single DB query, cached)
- Wildcard internal role → `['*']` → bypasses via `allow_platform_admins` pre-check

```ruby
# Both resolvers expose the same interface:
resolver.can?('resource.action')   # => true/false
resolver.permissions               # => ['resource.action', ...] or ['*']
```

### 7. Relation Scopes

```ruby
# In Orgs::BasePolicy (default: all records visible to org members)
scope_for :active_record_relation, &:all

# Override in domain policy for filtered scopes:
scope_for :active_record_relation do |relation|
  relation.where(organization: permission_resolver.scoped_facility_ids)
end

# In controller
@records = authorized_scope(Model.all, with: Orgs::XxxPolicy)
```

**FORBIDDEN** (Pundit pattern):
```ruby
# WRONG: Pundit inner Scope class
class Scope < ApplicationPolicy::Scope
  def resolve
    scope.where(...)
  end
end

# WRONG: Pundit policy_scope call
@orgs = policy_scope(Orgs::Organization)
```

### 8. Testing Patterns

**Orgs policy specs** (use `OrgPolicyHelpers`):
```ruby
# packs/orgs/spec/policies/facility_policy_spec.rb pattern
require_relative 'support/org_policy_helpers'

RSpec.describe Orgs::FacilityPolicy do
  include OrgPolicyHelpers

  let(:plain_user)     { build(:user) }
  let(:platform_admin) { build(:user, :admin) }
  let(:record)         { build(:organization) }

  def policy(permissions, user: plain_user)
    resolver = build_resolver(permissions)
    described_class.new(record, user: user, permission_resolver: resolver)
  end

  describe '#view?' do
    it 'allows with facilities.view' do
      expect(policy(['facilities.view']).apply(:view?)).to be(true)
    end

    it 'denies without facilities.view' do
      expect(policy(['org.view']).apply(:view?)).to be(false)
    end

    it 'allows platform admin' do
      expect(policy([], user: platform_admin).apply(:view?)).to be(true)
    end
  end
end
```

**IMPORTANT**: Always use `policy.apply(:rule?)`, not `policy.rule?` directly. The direct call
uses Action Policy's throw/catch control flow and will raise outside the policy's execution context.

**Internal policy specs** (use `describe_rule` / `succeed` / `failed` DSL):
```ruby
RSpec.describe Internal::FacilityPolicy, type: :policy do
  let(:record) { build_stubbed(:facility) }

  describe_rule :view? do
    succeed 'with facilities.list permission' do
      let(:context) { internal_policy_context(create_internal_admin(:operations)) }
    end

    failed 'without facilities.list permission' do
      let(:context) { internal_policy_context(create_internal_admin(:finance)) }
    end
  end
end
```

**Coexistence validation**:
```ruby
describe 'ActionPolicy isolation' do
  it 'ApplicationController does NOT include ActionPolicy::Controller' do
    expect(ApplicationController.ancestors).not_to include(ActionPolicy::Controller)
  end

  it 'Orgs::Api::V1::BaseController includes ActionPolicy::Controller' do
    expect(Orgs::Api::V1::BaseController.ancestors).to include(ActionPolicy::Controller)
  end

  it 'Internal::BaseController includes ActionPolicy::Controller' do
    expect(Internal::BaseController.ancestors).to include(ActionPolicy::Controller)
  end
end
```

## Anti-Pattern Detection Commands

Run these to validate any Action Policy implementation:

```bash
# 1. No Pundit references in new/migrated code
grep -rn "Pundit" packs/*/app/policies/ packs/*/app/controllers/ --include="*.rb" | grep -v "_spec.rb" | grep -v node_modules

# 2. No policy_scope usage (Pundit)
grep -rn "policy_scope" packs/*/app/controllers/ --include="*.rb"

# 3. No authorize without bang (Pundit style)
grep -rn "^\s*authorize " packs/*/app/controllers/ --include="*.rb" | grep -v "authorize!" | grep -v "authorize_" | grep -v "authorize :"

# 4. No inner Scope classes (Pundit pattern)
grep -rn "class Scope" packs/*/app/policies/ --include="*.rb"

# 5. ActionPolicy::Controller only in the two pack base controllers
grep -rn "ActionPolicy::Controller" packs/*/app/controllers/ --include="*.rb"
# Expected: packs/orgs/.../base_controller.rb and packs/internal_backend/.../base_controller.rb

# 6. No Pundit gem reference
grep -n "pundit" Gemfile | grep -v "#"

# 7. Verify policies inherit from the correct base class
grep -rn "< ActionPolicy::Base\|< BasePolicy\|< Orgs::BasePolicy\|< Internal::BasePolicy" packs/*/app/policies/ --include="*.rb" | grep -v node_modules
```

## Quick Validation Workflow

```bash
# Run all checks at once
echo "=== Checking for Pundit leftovers ==="
grep -rn "Pundit\|policy_scope\|pundit_user" packs/*/app/policies/ packs/*/app/controllers/ --include="*.rb" | grep -v "_spec.rb" | grep -v node_modules || echo "OK: No Pundit references"

echo "=== Checking Action Policy isolation ==="
grep -rn "ActionPolicy::Controller" packs/*/app/controllers/ --include="*.rb" | grep -v node_modules

echo "=== Checking policy inheritance ==="
grep -rn "class.*Policy" packs/*/app/policies/ --include="*.rb" | grep -v "< ActionPolicy::Base\|< BasePolicy\|module\|# " | grep -v node_modules && echo "WARNING: Policy not inheriting from correct base" || echo "OK"

echo "=== Running Orgs policy specs ==="
bin/d rspec packs/orgs/spec/policies/

echo "=== Running Internal policy specs ==="
bin/d rspec packs/internal_backend/spec/policies/
```

## Migration Checklist: CanCanCan Controller to Action Policy

1. Identify which pack the controller belongs to (Orgs API or Internal admin)
2. Create `packs/<pack>/app/policies/<namespace>/<model>_policy.rb` inheriting from the correct base
3. Define rules using `permitted?('resource.action')` delegation pattern
4. Add `scope_for :active_record_relation` block if controller has `index` action
5. Ensure controller inherits from the pack's `BaseController` (which already has `include ActionPolicy::Controller`)
6. Replace `load_and_authorize_resource` with explicit `authorize!(record, with: XxxPolicy)` calls
7. Replace `accessible_by(current_ability)` with `authorized_scope(Model.all, with: XxxPolicy)`
8. Replace view `can?(:action, record)` with `allowed_to?(:action?, record, with: XxxPolicy)`
9. Remove corresponding rules from Ability/ApiAbility class
10. Write policy specs using the pack's test helpers (`OrgPolicyHelpers` for Orgs, `internal_policy_context` for Internal)
11. Run `bin/d rspec packs/<pack>/spec/policies/` and `bin/d rspec packs/<pack>/spec/controllers/`
12. Run `bin/d bundle exec pronto run -r rubocop -c develop -f text`

---

## Unimplemented design stubs (do not grep)

> `AuthorizedController`, `ApplicationPolicy`, `Authorization::PermissionMatrix/ScopeResolver/RoleResolver` — zero repo hits; aspirational only. If introduced, update Architecture Overview and remove this note.

---

> See [kaizen_log.md](kaizen_log.md) for change history.
