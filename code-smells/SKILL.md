---
name: code-smells
description: Detects structural code smells in Ruby/Rails code - fat models, god classes, long methods, feature envy, callback overload, and design pattern violations.
allowed-tools: [Bash, Read, Grep, Glob, Edit]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## When to Use This Skill

Run this skill when:
- **Reviewing PRs** with significant model/controller changes (>50 lines changed)
- **Before refactoring** to identify what needs improvement
- **After adding features** to validate structural quality hasn't degraded
- **Quarterly audits** to track codebase health trends
- **When `/rails-audit` runs** in code-quality mode

## Shared References

> **📚 This skill uses shared documentation. See:**
> - [Structural Thresholds](../shared/structural-thresholds.md) - warning/critical limits
> - [Forbidden Patterns](../shared/forbidden-patterns.md) - patterns to avoid

# Code Smells Detection Skill

Identifies structural code smells based on Ruby Science patterns. Covers models, controllers, views, and design pattern violations.

## Quick Validation Commands

**Run these first for a fast overview:**

```bash
# 1. Fat Models (>200 lines = warning, >400 = critical)
wc -l app/models/*.rb | sort -rn | head -20
```
**Expected**: Most models <200 lines. Review any >200.

```bash
# 2. Fat Controllers (>150 lines = warning, >300 = critical)
wc -l app/controllers/**/*.rb | sort -rn | head -20
```
**Expected**: Most controllers <150 lines. Review any >150.

```bash
# 3. Queries in Views (ALWAYS bad)
grep -rn "\.where\|\.find\|\.find_by\|\.count\|\.sum\|\.order" app/views/ --include="*.erb" --include="*.haml"
```
**Expected**: 0 matches (queries belong in controllers/services, not views)

```bash
# 4. Long parameter lists (methods with 4+ params)
grep -rn "def \w\+(.*,.*,.*,.*)" app/models/ app/services/ app/controllers/ --include="*.rb" | grep -v "spec\|test\|#"
```
**Expected**: Minimal matches. Methods with 4+ params should use keyword args or parameter objects.

```bash
# 5. Law of Demeter violations (chains 3+ levels)
grep -rn '\.\w\+\.\w\+\.\w\+\.\w\+' app/models/ app/services/ app/controllers/ --include="*.rb" | grep -v "#\|spec\|test\|Rails\.\|ActiveRecord\.\|logger\."
```
**Expected**: Minimal matches. Long chains indicate tight coupling.

```bash
# 6. Callback complexity (>5 callbacks per model)
for f in app/models/*.rb; do
  count=$(grep -c "before_\|after_\|around_" "$f" 2>/dev/null)
  if [ "$count" -gt 5 ]; then
    echo "⚠️ $f: $count callbacks"
  fi
done
```
**Expected**: 0 warnings. Models with >5 callbacks need refactoring.

```bash
# 7. Monolithic controllers (>7 actions)
for f in app/controllers/**/*.rb; do
  count=$(grep -c "def " "$f" 2>/dev/null)
  if [ "$count" -gt 7 ]; then
    echo "⚠️ $f: $count methods (>7 actions)"
  fi
done
```
**Expected**: Standard REST controllers have 7 actions. More suggests splitting.

```bash
# 8. Mixin abuse (>5 includes per model)
for f in app/models/*.rb; do
  count=$(grep -c "include \|extend " "$f" 2>/dev/null)
  if [ "$count" -gt 5 ]; then
    echo "⚠️ $f: $count includes/extends"
  fi
done
```
**Expected**: 0 warnings. Excessive includes hide complexity.

```bash
# 9. Business logic in controllers
grep -rn "\.save\|\.update\|\.create\|\.destroy\|\.where.*\.each\|transaction" app/controllers/ --include="*.rb" | grep -v "redirect\|render\|respond\|format\.\|params\.\|#"
```
**Expected**: Minimal matches. Business logic belongs in services/models.

```bash
# 10. Helper complexity (>100 lines)
wc -l app/helpers/*.rb | sort -rn | head -10
```
**Expected**: Helpers <100 lines. Complex helpers → extract to presenters/decorators.

## Layer Analysis (Layered Design Patterns)

> Inspired by palkan's "Layered Design for Ruby on Rails Applications"

### Layer Violation Detection

Detect upward dependencies and leaking abstractions across layers:

```bash
# 11. Upward dependencies in models (models calling mailers/services/jobs)
grep -rn "Mailer\.\|Delivery\.\|deliver_later\|deliver_now" app/models/ --include="*.rb"
grep -rn "Service\.\|Service\.call\|Service\.new" app/models/ --include="*.rb" | grep -v "#\|spec"
grep -rn "perform_later\|perform_async\|perform_in" app/models/ --include="*.rb"
grep -rn "HTTParty\.\|Faraday\.\|Net::HTTP" app/models/ --include="*.rb"
```
**Expected**: 0 matches. Models should NOT call services, mailers, jobs, or HTTP clients — that's an upward dependency. Extract to a service object.

```bash
# 12. Current attributes in models (presentation/request leak)
grep -rn "Current\." app/models/ --include="*.rb"
```
**Expected**: 0 matches. `Current.*` belongs in controllers/views, not models. Models should receive needed data as method arguments.

```bash
# 13. Request/params in services (controller leak)
grep -rn "request\.\|params\[" app/services/ --include="*.rb"
```
**Expected**: 0 matches. Services should NOT reference request or params — they should receive explicit arguments from the controller.

### Callback Scoring System

Instead of just counting callbacks, score each by its appropriateness:

| Score | Type | Example | Action |
|-------|------|---------|--------|
| 5/5 | **Transformer** | `before_validation :normalize_email` | ✅ Keep — data normalization |
| 4/5 | **Maintainer** | `before_save :update_cached_count` | ✅ Keep — cache consistency |
| 3/5 | **Timestamp** | `before_create :set_published_at` | ⚠️ Acceptable if simple |
| 2/5 | **Background Trigger** | `after_commit :enqueue_indexing` | ⚠️ Consider extracting |
| 1/5 | **Operation** | `after_create :send_welcome_email` | ❌ Extract to service |

```bash
# 14. Detect Operation callbacks (score 1/5 — extract to service)
grep -rn "after_create\|after_save\|after_commit" app/models/ --include="*.rb" | grep -i "send_\|notify\|email\|mailer\|deliver\|sync_\|push_\|create_\|generate_"
```
**Expected**: Minimal matches. Operation callbacks (sending emails, syncing external data, creating related records) indicate the model is doing orchestration work that belongs in a service.

```bash
# 15. Detect callback control flags (extraction signal)
grep -rn "attr_accessor :skip_" app/models/ --include="*.rb"
grep -rn "unless: :skip_\|if: :skip_" app/models/ --include="*.rb"
```
**Expected**: 0 matches. `skip_*` flags indicate callbacks that are problematic enough to need bypassing — strong signal they should be extracted to a service instead.

### God Object Churn × Complexity

File size alone misses files that are both large AND frequently changed (most painful to work with):

```bash
# 16. Churn analysis (most changed files in 6 months)
git log --format=format: --name-only --since="6 months ago" -- app/models/ | sort | uniq -c | sort -rn | head -20
```

Combine with size to prioritize refactoring:

```bash
# 17. Churn × Complexity ranking
echo "CHANGES | LINES | FILE"
echo "--------|-------|-----"
git log --format=format: --name-only --since="6 months ago" -- app/models/ | grep -v "^$" | sort | uniq -c | sort -rn | head -20 | while read count file; do
  if [ -f "$file" ]; then
    lines=$(wc -l < "$file" | tr -d ' ')
    echo "$count | $lines | $file"
  fi
done
```
**Interpretation**: Files with high churn AND high line count are the best refactoring candidates (highest ROI).

### Concern Health Check

Distinguish **behavioral concerns** (good — shared behavior) from **code-slicing concerns** (bad — just splitting a fat model into files):

```bash
# 18. Find single-model concerns (code-slicing smell)
for concern in app/models/concerns/*.rb; do
  name=$(ruby -e "puts ARGV[0].split('_').map(&:capitalize).join" "$(basename "$concern" .rb)")
  refs=$(grep -rln "include.*${name}" app/models/ --include="*.rb" 2>/dev/null | grep -v concerns/ | wc -l | tr -d ' ')
  if [ "$refs" -le 1 ]; then
    echo "⚠️ Single-model concern: $concern (used by $refs model)"
  fi
done
```
**Expected**: Minimal matches. A concern used by only 1 model is likely just code-slicing — the code still belongs in the model (or should be a service if too complex). Good concerns are included by 2+ models.

### Anemic Models Detection

Services that steal domain logic from models — the model becomes a dumb data holder:

```bash
# 19. Find services that may contain domain logic
# Services with model-specific method names suggest misplaced logic
grep -rn "def.*calculate_\|def.*apply_\|def.*validate_\|def.*compute_\|def.*determine_" app/services/ --include="*.rb"
```
**Signal**: If a service method only uses attributes from a single model, that logic likely belongs on the model. Services should orchestrate, not compute domain rules.

**PBP Note**: Payment gateway services (`PaymentService::*`, `*Gateway*`) are legitimate orchestrators spanning multiple models (Merchant, Facility, Payment). Methods like `calculate_tax` or `validate_gateway_response` in these services are NOT anemic-model signals — they coordinate across domain boundaries.

```ruby
# ❌ ANEMIC MODEL - Service computes what the model should know
class CalculateDiscountService < ApplicationService
  def call
    if @membership.plan == 'vip' && @membership.months_active > 12
      @membership.base_price * 0.8  # 20% discount
    else
      @membership.base_price
    end
  end
end

# ✅ RICH MODEL - Domain logic lives on the model
class Membership < ApplicationRecord
  def discounted_price
    if plan == 'vip' && months_active > 12
      base_price * 0.8
    else
      base_price
    end
  end
end
```

## Detailed Smell Categories

### Models & Database

#### Fat Model
A model with too many responsibilities. Signs: >200 lines, >10 public methods, mixes data access with business logic.

```ruby
# ❌ SMELL - God model doing everything
class User < ApplicationRecord
  # Authentication, authorization, billing, notifications, search, analytics...
  # 500+ lines
end

# ✅ BETTER - Extract concerns or service objects
class User < ApplicationRecord
  include Users::Authentication
  include Users::Searchable
  # Core model: validations, associations, scopes
end
```

#### Callback Overload
Too many callbacks make models unpredictable and hard to test.

```ruby
# ❌ SMELL - 8+ callbacks create invisible side effects
class Membership < ApplicationRecord
  before_create :set_defaults
  before_create :validate_plan
  after_create :send_notification
  after_create :sync_payment
  after_create :update_analytics
  after_save :invalidate_cache
  before_destroy :cancel_payments
  after_destroy :notify_admin
end

# ✅ BETTER - Use service object for orchestration
class CreateMembershipService < ApplicationService
  def call
    membership = Membership.create!(params)
    send_notification(membership)
    sync_payment(membership)
    update_analytics(membership)
  end
end
```

### Controllers

#### Fat Controller
Controller doing too much work — should delegate to services.

```ruby
# ❌ SMELL - Business logic in controller
def create
  @payment = Payment.new(payment_params)
  @payment.calculate_tax
  @payment.apply_discount(current_user.discount_code)
  if @payment.save
    PaymentGateway.charge(@payment)
    UserMailer.receipt(@payment).deliver_later
    Analytics.track('payment_completed', @payment.attributes)
    redirect_to @payment
  end
end

# ✅ BETTER - Delegate to service
def create
  result = CreatePaymentService.call(params: payment_params, user: current_user)
  if result.success?
    redirect_to result.payment
  else
    render :new, status: :unprocessable_entity
  end
end
```

### Views & Presenters

#### Queries in Views
Views should never make database queries — this hides N+1 problems and violates MVC.

```erb
<%# ❌ SMELL - Query in view %>
<%= @user.reservations.where(status: 'confirmed').count %>
<%= Facility.find(@user.facility_id).name %>

<%# ✅ BETTER - Preload in controller %>
<%= @confirmed_count %>
<%= @facility_name %>
```

#### Complex View Logic
Business logic in views should move to presenters/decorators.

```erb
<%# ❌ SMELL - Logic in view %>
<% if @membership.expires_at && @membership.expires_at < Time.current && !@membership.auto_renew? %>
  <span class="expired">Expired</span>
<% end %>

<%# ✅ BETTER - Use presenter method %>
<%= @membership.display_status %>
```

### Design Patterns

#### Feature Envy
A method that uses more features of another class than its own.

```ruby
# ❌ SMELL - This method belongs on Facility, not User
class User
  def facility_summary
    "#{facility.name} (#{facility.city}, #{facility.state}) - #{facility.courts.count} courts"
  end
end

# ✅ BETTER - Move to where the data lives
class Facility
  def summary
    "#{name} (#{city}, #{state}) - #{courts.count} courts"
  end
end
```

#### Shotgun Surgery
One change requires modifications in many different files — suggests missing abstraction.

```bash
# Detect: If a simple change touches 5+ files, consider extracting a shared abstraction
git diff develop --stat | tail -1
# "15 files changed" for a simple feature = potential shotgun surgery
```

## Analysis Process

### Step 1: Scope Analysis

```bash
# Analyze changed files
git diff develop --name-only -- '*.rb' | head -30

# Count lines in changed models/controllers
git diff develop --name-only -- app/models/ app/controllers/ | while read f; do
  echo "$(wc -l < "$f") $f"
done | sort -rn
```

### Step 2: Run Quick Validation Commands (above)

### Step 3: Deep Analysis on Flagged Files

For each file flagged in Step 2:

```bash
# Count public methods (indicates too many responsibilities)
grep -c "def " <file>

# Check method length distribution
awk '/def [a-z]/{start=NR; name=$2} /^[[:space:]]*end$/{len=NR-start; if(len>10) print len " lines: " name}' <file> | sort -rn

# Check coupling (references to other models)
grep -c "\.\(find\|where\|create\|new\)" <file>
```

### Step 4: Generate Report

## Report Format

```markdown
## Code Smells Report

### Summary
- Files analyzed: X
- Smells found: Y (Z critical)

### Critical Smells (Must Fix)

| File | Smell | Lines/Count | Recommendation |
|------|-------|-------------|----------------|
| user.rb | Fat Model | 450 lines | Extract concerns |
| admin_controller.rb | Fat Controller | 320 lines | Extract to services |

### Warning Smells (Should Fix)

| File | Smell | Lines/Count | Recommendation |
|------|-------|-------------|----------------|
| membership.rb | Callback Overload | 7 callbacks | Use service object |
| facility.rb | Long Methods | 3 methods >15 lines | Extract helper methods |

### Info (Monitor)

| File | Smell | Lines/Count | Note |
|------|-------|-------------|------|
| reservation.rb | 5 includes | At threshold | Watch for growth |
```

---

## Related Skills

This skill works with:
- **`/code-review`** - Includes structural quality check (Step 2.7) and layer validation (Step 2.8)
- **`/performance`** - Fat models often have N+1 queries
- **`/rails-audit`** - Orchestrates code-smells as part of full audit
- **`/architect`** - Design guidance for refactoring flagged smells (see Gradual Layerification)
- **`/sidekiq`** - Anemic job detection complements anemic models detection here

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new code smell pattern specific to PBP
- A better detection heuristic
- A missing threshold

**You MUST**:
1. Complete the current code smells audit first
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements**:
<!-- Kaizen entries will be added here -->
