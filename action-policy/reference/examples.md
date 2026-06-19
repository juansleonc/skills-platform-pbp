# action-policy — Verbatim Examples (Bundled Reference)

> Progressive-disclosure overflow from `SKILL.md`. Read only when you need the full
> verbatim form. Decision logic, grep commands, and runnable validation stay in `SKILL.md`.

## Table of Contents

1. [Controller Inheritance Tree (full ASCII)](#1-controller-inheritance-tree-full-ascii)
2. [Testing Patterns (full code)](#2-testing-patterns-full-code)

---

## 1. Controller Inheritance Tree (full ASCII)

The repo uses `action_policy = 0.7.6` (confirmed: `Gemfile` line 104). Action Policy is
**not** wired into `ApplicationController` — it lives exclusively in two pack base controllers.
Compact table in `SKILL.md` → Architecture Overview; full tree here:

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

---

## 2. Testing Patterns (full code)

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
