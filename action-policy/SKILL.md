---
name: action-policy
description: Validates Action Policy implementations for correctness, naming conventions, and coexistence with CanCanCan. Use when creating policies, migrating controllers, or reviewing authorization code.
allowed-tools: [Bash, Read, Grep, Glob, Edit]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## When to Use This Skill

Run this skill when:
- **Creating new Action Policy policies** (validate structure, deny-all defaults, relation_scope)
- **Migrating a controller** from CanCanCan to AuthorizedController (verify authorization calls, context, verification hooks)
- **Reviewing PRs** that touch `app/policies/`, `authorized_controller.rb`, or controllers inheriting from `AuthorizedController`
- **Adding authorization context** to controllers or policies (validate optional/required context keys)
- **Writing policy or controller specs** (validate correct error classes, matchers, test patterns)

## Shared References

> - [Authorization Architecture](docs/architecture/authorization-pundit.md) - comprehensive guide
> - [Critical Rules](../shared/critical-rules.md) - security rules
> - [Forbidden Patterns](../shared/forbidden-patterns.md) - patterns to avoid
> - Use `Grep` and `Glob` for policy hierarchy and reference lookup (Serena removed 2026-06-02)
> - [ast-grep Patterns](../shared/ast-grep-patterns.md) — structured `can :action, Model` rule extraction with captures

# Action Policy Validation Skill

Validates Action Policy implementations follow project conventions, ensure correct coexistence with CanCanCan, and match the patterns established in the Orgs authorization slice.

## Architecture Overview

```
ApplicationController
|  rescue_from CanCan::AccessDenied          <- CanCanCan error handling
|  NO ActionPolicy::Controller               <- CRITICAL: not included here
|
+-- CanCanCan controllers (86+)              <- Unchanged, use Ability/ApiAbility
|   +-- load_and_authorize_resource
|   +-- authorize! / can?
|
+-- AuthorizedController                     <- Action Policy base controller
|   |  include ActionPolicy::Controller
|   |  authorize :user, through: :current_user
|   |  verify_authorized except: :index
|   |  verify_authorized_scoped only: :index
|   |  rescue_from ActionPolicy::Unauthorized
|   |
|   +-- Action Policy controllers            <- Inherit from AuthorizedController
|       +-- authorize! @record               <- Per-action authorization
|       +-- authorized_scope(Model.all)      <- Scoped queries
|
+-- Api::V1::ApiMainController               <- Uses ApiAbility, unaffected
|   +-- ~93 API controllers
|
+-- GraphqlController                        <- Custom token auth, no CanCanCan/ActionPolicy
```

## Validation Checklist

### 1. Policy Structure

```bash
# Grep for correct base class
grep -rn "< ApplicationPolicy" app/policies/
# ApplicationPolicy MUST extend ActionPolicy::Base
grep -n "< ActionPolicy::Base" app/policies/application_policy.rb
```

> Use `Grep` and `Glob` for symbol-level discovery. (Serena removed 2026-06-02.)
>
> **📖 See [ast-grep Patterns](../shared/ast-grep-patterns.md)** when `sg` is installed: `sg run --lang ruby --pattern 'can $ACTION, $MODEL' --json=stream` extracts every CanCanCan rule with structured `ACTION`/`MODEL` captures (catches multi-line `can [...]` blocks grep misses). Otherwise this grep is the right tool.

**CORRECT patterns**:
```ruby
# app/policies/application_policy.rb
class ApplicationPolicy < ActionPolicy::Base
  # CRITICAL: allow_nil so unauthenticated requests get redirect/403, not 500
  authorize :user, allow_nil: true

  authorize :organization, optional: true
  authorize :membership, optional: true

  # Action Policy only aliases new? -> create? by default.
  # edit? -> update? must be declared explicitly.
  alias_rule :edit?, to: :update?

  def index? = false
  def show? = false
  def create? = false
  def update? = false
  def destroy? = false
end

# app/policies/orgs/organization_policy.rb
module Orgs
  class OrganizationPolicy < ApplicationPolicy
    relation_scope do |relation|
      Authorization::ScopeResolver.organizations(user: user, scope: relation)
    end

    def show?
      allowed?(action: :show, role: organization_role)
    end

    private

    def allowed?(action:, role:)
      Authorization::PermissionMatrix.allowed?(resource: :organization, action: action, role: role)
    end

    def role_resolver
      @role_resolver ||= Authorization::RoleResolver.new(user: user)
    end
  end
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

# WRONG: Plain Ruby class (not ActionPolicy::Base)
class ApplicationPolicy
  attr_reader :user, :record
end
```

### 2. Controller Authorization Calls

```bash
# Check for correct authorize! usage (Action Policy)
grep -rn "authorize!" app/controllers/ packs/*/app/controllers/
# Check for WRONG authorize usage (Pundit style)
grep -rn "^\s*authorize[^!_]" app/controllers/ packs/*/app/controllers/ | grep -v "authorize_"
```

**CORRECT**:
```ruby
# Action Policy: authorize! with bang
authorize! @organization, to: :show?, with: Orgs::OrganizationPolicy

# Implicit rule from action name
authorize! @organization, with: Orgs::OrganizationPolicy

# Scoped collection
@orgs = authorized_scope(Orgs::Organization.all, type: :active_record_relation, with: Orgs::OrganizationPolicy)

# Permission check (no exception)
allowed_to?(:update?, @organization, with: Orgs::OrganizationPolicy)
```

**FORBIDDEN**:
```ruby
# WRONG: Pundit-style authorize (no bang)
authorize @organization, :show?, policy_class: Orgs::OrganizationPolicy

# WRONG: Pundit-style policy_scope
policy_scope(Orgs::Organization)

# WRONG: Pundit-style policy helper
policy(@organization).show?
```

### 3. Controller Setup

```bash
# Verify ActionPolicy::Controller only in AuthorizedController
grep -rn "ActionPolicy::Controller" app/controllers/
# Should ONLY appear in authorized_controller.rb
```

**CORRECT**:
```ruby
# app/controllers/authorized_controller.rb
class AuthorizedController < ApplicationController
  include ActionPolicy::Controller
  authorize :user, through: :current_user
  verify_authorized except: :index
  verify_authorized_scoped only: :index
  rescue_from ActionPolicy::Unauthorized, with: :user_not_authorized
end

# Orgs API overrides scoped verification (uses ScopeResolver instead)
class Orgs::Api::V1::BaseController < AuthorizedController
  authorize :organization, through: :current_organization
  authorize :membership, through: :current_membership
  skip_verify_authorized_scoped
  verify_authorized  # all actions, including index
end
```

**FORBIDDEN**:
```ruby
# WRONG: Including in ApplicationController
class ApplicationController < ActionController::Base
  include ActionPolicy::Controller  # NO! This breaks CanCanCan isolation
end

# WRONG: Pundit include
class AuthorizedController < ApplicationController
  include Pundit::Authorization  # NO! We use Action Policy now
end
```

### 4. Authorization Context

```bash
# Check context declarations
grep -rn "authorize :" app/policies/ app/controllers/ packs/*/app/controllers/ | grep -v "authorize!"
```

**Rules**:
- `user` is declared in `AuthorizedController` via `authorize :user, through: :current_user`
- `organization` and `membership` are optional in `ApplicationPolicy`
- Controllers that have org/membership context must declare `authorize :organization, through: :method`
- Contexts that can be nil MUST use `optional: true` in the policy

**CORRECT**:
```ruby
# In policy (optional context)
class ApplicationPolicy < ActionPolicy::Base
  authorize :organization, optional: true
  authorize :membership, optional: true
end

# In controller (providing context)
class Orgs::Api::V1::BaseController < AuthorizedController
  authorize :organization, through: :current_organization
  authorize :membership, through: :current_membership

  private

  def current_organization
    @organization
  end

  def current_membership
    @membership
  end
end
```

### 5. Error Handling

```bash
# Verify correct error class
grep -rn "ActionPolicy::Unauthorized" app/controllers/
grep -rn "Pundit::NotAuthorizedError" app/controllers/  # Should find NOTHING
```

**CORRECT**:
```ruby
rescue_from ActionPolicy::Unauthorized, with: :user_not_authorized

def user_not_authorized(exception)
  log_authorization_failure(exception)
  # exception.policy  -> policy instance
  # exception.rule    -> the rule that failed (e.g., :show?)
  # exception.record  -> the record being authorized
end
```

**Error classes reference**:
| Error | When | Equivalent Pundit |
|-------|------|-------------------|
| `ActionPolicy::Unauthorized` | `authorize!` denies access | `Pundit::NotAuthorizedError` |
| `ActionPolicy::UnauthorizedAction` | `verify_authorized` fails (forgot `authorize!`) | `Pundit::AuthorizationNotPerformedError` |
| `ActionPolicy::UnscopedAction` | `verify_authorized_scoped` fails (forgot `authorized_scope`) | `Pundit::PolicyScopingNotPerformedError` |
| `ActionPolicy::AuthorizationContextMissing` | Required context not provided | N/A |

### 6. Verification Hooks

**CORRECT**:
```ruby
# Standard: index uses scope, others use authorize!
verify_authorized except: :index
verify_authorized_scoped only: :index

# API controllers that use ScopeResolver instead of authorized_scope
skip_verify_authorized_scoped
verify_authorized  # for ALL actions including index

# Skip for specific actions
skip_verify_authorized only: :health_check

# Skip dynamically within an action
def public_page
  skip_verify_authorized!
  # ...
end
```

### 7. Relation Scopes

**CORRECT** (Action Policy pattern):
```ruby
class OrganizationPolicy < ApplicationPolicy
  # Default relation scope
  relation_scope do |relation|
    Authorization::ScopeResolver.organizations(user: user, scope: relation)
  end

  # Named scope (if needed)
  scope_for :relation, :own do |relation|
    relation.where(owner: user)
  end
end

# In controller
@orgs = authorized_scope(Orgs::Organization.all, type: :active_record_relation, with: Orgs::OrganizationPolicy)
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

**Policy specs**:
```ruby
RSpec.describe Orgs::OrganizationPolicy do
  let(:user) { build_stubbed(:user) }
  let(:organization) { build_stubbed(:organization) }
  let(:policy) { described_class.new(record: organization, user: user) }

  describe '#show?' do
    context 'when platform admin' do
      let(:user) { build_stubbed(:user, :admin) }
      it { expect(policy).to be_show }
    end

    context 'when no user' do
      let(:user) { nil }
      it { expect(policy).not_to be_show }
    end
  end

  describe 'relation_scope' do
    let(:scope) { Orgs::Organization.all }
    # Test via ScopeResolver specs, not policy scope directly
  end
end
```

**Controller authorization specs**:
```ruby
RSpec.describe AuthorizedController, type: :controller do
  # Test ActionPolicy::UnauthorizedAction when authorize! not called
  it 'raises when authorize! is not called' do
    expect { post :create }.to raise_error(ActionPolicy::UnauthorizedAction)
  end

  # Test ActionPolicy::Unauthorized rescue
  it 'returns 404 for signed-in unauthorized users' do
    expect { get :show, params: { id: 1 } }.to raise_error(ActionController::RoutingError)
  end
end
```

**Coexistence specs**:
```ruby
RSpec.describe 'CanCanCan and Action Policy coexistence' do
  describe 'ApplicationController' do
    it 'does NOT include ActionPolicy::Controller' do
      expect(ApplicationController.ancestors).not_to include(ActionPolicy::Controller)
    end

    it 'handles CanCan::AccessDenied' do
      handlers = ApplicationController.rescue_handlers.map(&:first)
      expect(handlers).to include('CanCan::AccessDenied')
    end
  end

  describe 'AuthorizedController' do
    it 'includes ActionPolicy::Controller' do
      expect(AuthorizedController.ancestors).to include(ActionPolicy::Controller)
    end

    it 'handles ActionPolicy::Unauthorized' do
      handlers = AuthorizedController.rescue_handlers.map(&:first)
      expect(handlers).to include('ActionPolicy::Unauthorized')
    end
  end
end
```

## Anti-Pattern Detection Commands

Run these to validate any Action Policy implementation:

```bash
# 1. No Pundit references in new/migrated code
grep -rn "Pundit" app/policies/ packs/*/app/policies/ --include="*.rb" | grep -v "_spec.rb"

# 2. No policy_scope usage (Pundit)
grep -rn "policy_scope" app/controllers/ packs/*/app/controllers/ --include="*.rb"

# 3. No authorize without bang (Pundit style) - exclude authorize_access! etc.
grep -rn "^\s*authorize " app/controllers/ packs/*/app/controllers/ --include="*.rb" | grep -v "authorize!" | grep -v "authorize_" | grep -v "authorize :"

# 4. No inner Scope classes (Pundit pattern)
grep -rn "class Scope" app/policies/ --include="*.rb"

# 5. ActionPolicy::Controller only in AuthorizedController
grep -rn "ActionPolicy::Controller" app/controllers/ packs/*/app/controllers/ --include="*.rb"

# 6. No Pundit gem reference (after migration)
grep -n "pundit" Gemfile | grep -v "#"

# 7. Verify all policies inherit from ApplicationPolicy
grep -rn "< ApplicationPolicy\|< ActionPolicy::Base" app/policies/ --include="*.rb"
```

## Quick Validation Workflow

```bash
# Run all checks at once
echo "=== Checking for Pundit leftovers ==="
grep -rn "Pundit\|policy_scope\|pundit_user" app/policies/ app/controllers/ packs/*/app/policies/ packs/*/app/controllers/ --include="*.rb" | grep -v "_spec.rb" | grep -v "# " || echo "OK: No Pundit references"

echo "=== Checking Action Policy isolation ==="
grep -rn "ActionPolicy::Controller" app/controllers/ packs/*/app/controllers/ --include="*.rb" | grep -v "authorized_controller.rb" && echo "WARNING: ActionPolicy::Controller found outside AuthorizedController" || echo "OK: Properly isolated"

echo "=== Checking policy inheritance ==="
grep -rn "class.*Policy" app/policies/ --include="*.rb" | grep -v "< ApplicationPolicy\|< ActionPolicy::Base\|module\|# " && echo "WARNING: Policy not inheriting from ApplicationPolicy" || echo "OK: All policies inherit correctly"

echo "=== Running specs ==="
bin/d rspec spec/policies/ spec/controllers/authorized_controller_spec.rb spec/controllers/cancancan_coexistence_spec.rb
```

## PermissionMatrix Pattern

All org-hierarchy policies delegate authorization decisions to `Authorization::PermissionMatrix`:

```ruby
# Pattern used in all org policies
private

def allowed?(action:, role:)
  Authorization::PermissionMatrix.allowed?(resource: :resource_name, action: action, role: role)
end

def organization_role
  return :none unless user
  role_resolver.organization_role(record_organization)
end

def role_resolver
  @role_resolver ||= Authorization::RoleResolver.new(user: user)
end
```

This keeps business rules centralized in `PermissionMatrix` and avoids duplicating role logic in each policy.

## Migration Checklist: CanCanCan Controller to Action Policy

1. Create `app/policies/<model>_policy.rb` inheriting from `ApplicationPolicy`
2. Define rules using `PermissionMatrix` delegation pattern
3. Add `relation_scope` block if controller has `index` action
4. Change controller parent: `< ApplicationController` -> `< AuthorizedController`
5. Replace `load_and_authorize_resource` with explicit `authorize!` calls
6. Replace `accessible_by(current_ability)` with `authorized_scope(Model.all, type: :active_record_relation)`
7. Replace view `can?(:action, record)` with `allowed_to?(:action?, record)`
8. Declare authorization contexts if needed: `authorize :organization, through: :method`
9. Remove corresponding rules from Ability class
10. Write policy specs + update controller specs
11. Run `bin/d rspec` for affected files
12. Run `bin/d bundle exec pronto run -r rubocop -c develop -f text`
