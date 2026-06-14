---
name: packwerk
description: Validate Packwerk package boundaries, cross-package dependencies, and enforce table naming conventions
allowed-tools: [Bash, Read, Grep, Glob, Edit]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## Shared References

> **📚 This skill uses shared documentation. See:**
> - Use `Grep` for cross-package reference audits

## When to Use This Skill

Run this skill when:
- **Adding new packages** to `/packs` directory (validate structure and naming)
- **Creating cross-package dependencies** (ensure proper declaration in package.yml)
- **Before production deployment** of package changes (prevent boundary violations)
- **Reviewing PRs** that touch multiple packages (detect undeclared dependencies)
- **After package refactoring** (verify no new privacy/dependency violations)

# Packwerk Validation Skill

Validate package boundaries and dependencies in the modular architecture.

## Package Structure

The platform uses **18 Packwerk packages** in `/packs`:

| Package | Purpose | Notes |
|---------|---------|-------|
| `agents_cli` | CLI agent tooling | Internal tooling |
| `audit_logs` | Event tracking, audit trails | DynamoDB storage |
| `billing` | Subscription billing for plans & plugins | Facility- vs org-scoped entitlements; `Billing::BillableEntityResolver` |
| `book_a_pro` | Pro booking/scheduling | GraphQL, validators |
| `camera_integrations` | Playsight camera integration | External devices |
| `electronic_invoicing` | Read-only transactions report for e-invoicing mandates | Report-only (no models/migrations); country adapters (PSFE/PAC/OSE) |
| `feature_flag` | Feature flag management | DynamoDB-backed, lock/sync system |
| `game_match` | Game/match management | Match scoring, results |
| `internal_backend` | Internal admin API | Feature flag API, policies |
| `internal_frontend` | Internal admin UI | React admin interface |
| `marketing_kit` | Marketing materials | Facility marketing assets |
| `merchandise` | Product management | Newer package |
| `orgs` | Organizations/SSO backend | Clerk SSO, SAML |
| `orgs_frontend` | Organizations/SSO UI | React components |
| `page_builder` | CMS frontend | React, separate assets |
| `partners` | Partner integrations (OAuth-like verification code flow) | `partners_verification_codes`; e.g. Schoolyard Social |
| `raffle` | Raffle/giveaway system | Event raffles |
| `webhooks` | Webhook management | Most mature, encrypted credentials |

## Quick Validation Commands

**Fast package boundary violation detection** (run these first):

```bash
# 1. Find privacy violations - HIGH RISK
bin/d packwerk check | grep "Privacy violation"
```
**Expected**: 0 matches (accessing private package constants)

```bash
# 2. Find dependency violations - MEDIUM RISK
bin/d packwerk check | grep "Dependency violation"
```
**Expected**: 0 matches (using packages without declaring dependency)

```bash
# 3. Find unprefixed table names - CRITICAL
grep -r "create_table" packs/*/db/migrate/ | grep -v "packs/\w\+.*:\w\+_"
```
**Expected**: 0 matches (all package tables must be prefixed)

> Use `Grep` and `Glob` for symbol-level discovery.

```bash
# 4. Check package structure validity
bin/d packwerk validate
```
**Expected**: "Validation successful" (all package.yml files are valid)

```bash
# 5. Count total violations per package
for pack in packs/*/; do echo "$(basename $pack): $(bin/d packwerk check $pack 2>&1 | grep -c violation)"; done
```
**Expected**: All packages show "0" violations

## CLI Integration

**All commands run in Docker web container.**

### Core Commands

```bash
# Check all package boundaries (FIRST STEP)
bin/d packwerk check
```
**Expected**: "✅ No violations detected" or list of specific violations

```bash
# Check specific package
bin/d packwerk check packs/webhooks
```
**Expected**: Package-specific violations or "No violations"

```bash
# Update package todo (after fixing violations)
bin/d packwerk update-todo
```
**Expected**: Updates `package_todo.yml` files with remaining violations

```bash
# Validate package structure
bin/d packwerk validate
```
**Expected**: "Validation successful" (all package.yml files are valid)

### Automated Workflow

```bash
# Full packwerk audit workflow
PACK_NAME="${1:-all}"

echo "=== Packwerk Audit ==="

# 1. Validate structure
bin/d packwerk validate
if [ $? -ne 0 ]; then
  echo "FAIL: Package structure invalid"
  exit 1
fi

# 2. Check for violations
if [ "$PACK_NAME" = "all" ]; then
  bin/d packwerk check
else
  bin/d packwerk check "packs/$PACK_NAME"
fi

# 3. List current todos
echo "=== Current TODOs ==="
find packs -name "package_todo.yml" -exec echo "File: {}" \; -exec cat {} \;
```

### Fixing Violations Automatically

```bash
# After fixing code, update the todo file
bin/d packwerk update-todo

# Check if todos were reduced (should show deletions)
git diff packs/*/package_todo.yml
```
**Expected**: Git diff shows removed violations (lines starting with `-`)

## Package Conventions

### Table Naming (MANDATORY)

All package tables MUST be prefixed with package name:

| Package | Table Example |
|---------|---------------|
| `webhooks` | `webhooks_urls`, `webhooks_deliveries` |
| `audit_logs` | `audit_logs_events` |
| `feature_flag` | `feature_flag_settings` |
| `game_match` | `game_match_waivers` |

**Validation:**
```bash
# Check for unprefixed tables in migrations
grep -r "create_table" packs/*/db/migrate/ | grep -v "packs/\w\+.*create_table :\w\+_"
```

### Asset Pipelines (CRITICAL)

Packages with frontend components have separate asset pipelines:

```bash
# After JS/CSS changes in webhooks
yarn --cwd packs/webhooks build

# After JS/CSS changes in page_builder
yarn --cwd packs/page_builder build

# After JS/CSS changes in orgs_frontend
yarn --cwd packs/orgs_frontend build
```

### Dependencies Declaration

Declare dependencies in `package.yml`:

```yaml
# packs/book_a_pro/package.yml
enforce_dependencies: true
enforce_privacy: true
dependencies:
  - packs/feature_flag
```

## Testing Packages

**Package specs live in their own spec directories:**

```bash
# Run package-specific tests
make test TEST_PATH=packs/webhooks/spec

# Run all package tests
make test TEST_PATH="packs/**/spec"

# Run specific package test
make test TEST_PATH=packs/audit_logs/spec/models/audit_log_spec.rb
```

## Package Health Scoring

Calculate a health score for each package:

| Metric | Weight | Scoring |
|--------|--------|---------|
| Privacy violations | 3x | 0 = 100pts, 1-5 = 50pts, 6+ = 0pts |
| Dependency violations | 2x | 0 = 100pts, 1-3 = 50pts, 4+ = 0pts |
| TODO items | 1x | 0 = 100pts, 1-10 = 75pts, 11+ = 50pts |
| Table naming | Pass/Fail | Pass = 100pts, Fail = 0pts |

**Health Grade:**
- A: 90-100 (Excellent)
- B: 75-89 (Good)
- C: 60-74 (Needs Work)
- D: Below 60 (Critical)

### Calculate Health Score

```bash
# Count violations per package
for pack in packs/*/; do
  name=$(basename "$pack")
  privacy=$(bin/d packwerk check "$pack" 2>&1 | grep -c "Privacy violation")
  dependency=$(bin/d packwerk check "$pack" 2>&1 | grep -c "Dependency violation")
  todo_count=$(cat "${pack}package_todo.yml" 2>/dev/null | grep -c "^  -" || echo 0)
  echo "$name: privacy=$privacy, deps=$dependency, todos=$todo_count"
done
```

## Process

1. **Run Packwerk check**
   ```bash
   bin/d packwerk check
   ```

2. **Analyze violations**
   - Privacy violations (accessing private constants)
   - Dependency violations (undeclared dependencies)

3. **Calculate health scores** (see above)

4. **Review package.yml files**
   ```bash
   cat packs/*/package.yml
   ```

5. **Verify table naming conventions**
   ```bash
   grep -r "create_table" packs/*/db/migrate/ | grep -v "$(basename $pack)_"
   ```

6. **Check package TODOs**
   ```bash
   cat packs/*/package_todo.yml
   ```

7. **Generate report**

## Violation Types

### Privacy Violation
Accessing a constant that isn't in the package's public API:
```ruby
# BAD - Accessing private constant
Webhooks::Internal::Encryptor.encrypt(data)

# GOOD - Use public API
Webhooks::Url.encrypt_credentials(data)
```

### Dependency Violation
Using a package without declaring the dependency:
```yaml
# Fix: Add to package.yml
dependencies:
  - packs/feature_flag
```

### Illustrative examples (NOT from this codebase — do not cite as evidence)

These examples demonstrate common Packwerk violation patterns. They are NOT all sourced from real files or line numbers in this codebase — see notes per example.

**EXAMPLE 1: Privacy violation — accessing internal package encryptor**
```ruby
# ❌ BAD - Accessing private constant from another package
credentials = Webhooks::Internal::Encryptor.encrypt(api_key)

# ✅ GOOD - Use public API
credentials = Webhooks::Url.encrypt_credentials(api_key)

# Fix in package.yml:
dependencies:
  - packs/webhooks
```

Note: `packs/book_a_pro/app/services/notification_service.rb` does not exist at HEAD. This is an illustrative example of the pattern.

**EXAMPLE 2: Dependency violation — using a package without declaring it**
```ruby
# ❌ BAD - Using FeatureFlag without declared dependency
def discounts_enabled?
  FeatureFlag::Setting.enabled?(:product_discounts, facility_id)
end

# ✅ GOOD - Declare dependency in package.yml
# packs/merchandise/package.yml:
dependencies:
  - packs/feature_flag
```

Note: `packs/merchandise/package.yml` at HEAD has `enforce_dependencies: true` but no `dependencies` key — this is a real pattern to check but the specific `product.rb:23` citation is illustrative.

**EXAMPLE 3: Table naming violation — unprefixed table**
```ruby
# ❌ BAD - Missing package prefix
create_table :waivers do |t|
  t.references :facility
  t.string :waiver_type
end

# ✅ GOOD - Prefix with package name
create_table :game_match_waivers do |t|
  t.references :facility
  t.string :waiver_type
end
```

Note: Migration `packs/game_match/db/migrate/20231015_create_waivers.rb` does not exist at HEAD. The real game_match migrations (2026-era) follow the correct `game_match_` prefix. This is an illustrative example of what the violation looks like.

**EXAMPLE 4: Missing enforce_privacy flag**

This example is VERIFIED: `packs/orgs/package.yml` at HEAD has `enforce_dependencies: true` but no `enforce_privacy` key.

```yaml
# ❌ Current packs/orgs/package.yml (verified 2026-06-10)
enforce_dependencies: true
# No enforce_privacy — privacy violations go undetected
dependencies:
  - "."
  - packs/marketing_kit

# ✅ GOOD - Enable privacy enforcement
enforce_dependencies: true
enforce_privacy: true
dependencies:
  - "."
  - packs/marketing_kit
```

**EXAMPLE 5: Circular dependency**
```yaml
# ❌ BAD - Circular dependency between packages
# packs/pack_a/package.yml
dependencies:
  - packs/pack_b

# packs/pack_b/package.yml
dependencies:
  - packs/pack_a  # Circular!

# ✅ GOOD - Extract shared interface to a third package
# Create packs/shared_interface
# Both pack_a and pack_b depend on shared_interface
```

## Report Format

```markdown
## Packwerk Analysis

### Summary
- Packages checked: 18 (run `ls packs/ | wc -l` for current count)
- Privacy violations: X
- Dependency violations: Y
- Table naming issues: Z
- Average health score: XX/100

### Package Health Scores

| Package | Privacy | Deps | TODOs | Tables | Grade |
|---------|---------|------|-------|--------|-------|
| audit_logs | 0 | 0 | 0 | ✅ | A |
| book_a_pro | 1 | 0 | 3 | ✅ | B |
| webhooks | 0 | 0 | 0 | ✅ | A |
| merchandise | 0 | 2 | 5 | ✅ | C |

### Violations

#### packs/book_a_pro
- [ ] Privacy: Accessing `Webhooks::Url` (private constant)
  - File: packs/book_a_pro/app/services/some_service.rb:45  _(example path — substitute real file from packwerk output)_
  - Fix: Add to public API or use public interface

**CLI Fix:**
```bash
# Option 1: Declare dependency
echo "dependencies:\n  - packs/webhooks" >> packs/book_a_pro/package.yml

# Option 2: Update todo
bin/d packwerk update-todo
```

#### packs/merchandise
- [ ] Dependency: Using `FeatureFlag::Setting` without declaration
  - Fix: Add to package.yml dependencies

**CLI Fix** (bin/d sh for interactive shell; bash -c for heredoc append requires direct docker compose):
```bash
# Preferred for interactive: bin/d sh
# For non-interactive heredoc append:
docker compose exec web bash -c "cat >> packs/merchandise/package.yml << 'EOF'
dependencies:
  - packs/feature_flag
EOF"
```

### Table Naming Issues
- [ ] `packs/new_pack/db/migrate/001_create_items.rb`
  - Should be: `create_table :new_pack_items`

### Recommendations
1. Add missing dependency declarations
2. Extract shared interfaces to public API
3. Fix table naming in migrations
4. Run `packwerk update-todo` after fixes
```

## Example

```
User: /packwerk

Claude:
## Packwerk Analysis

Running packwerk check...

### Summary
- Packages checked: 18 (run `ls packs/ | wc -l` for current count)
- Privacy violations: 0
- Dependency violations: 0

### Package Health
| Package | Deps | Privacy | Tables | Status |
|---------|------|---------|--------|--------|
| agents_cli | OK | OK | OK | Healthy |
| audit_logs | OK | OK | OK | Healthy |
| billing | OK | OK | OK | Healthy |
| book_a_pro | OK | OK | OK | Healthy |
| camera_integrations | OK | OK | OK | Healthy |
| electronic_invoicing | OK | OK | OK | Healthy |
| feature_flag | OK | OK | OK | Healthy |
| game_match | OK | OK | OK | Healthy |
| internal_backend | OK | OK | OK | Healthy |
| internal_frontend | OK | OK | OK | Healthy |
| marketing_kit | OK | OK | OK | Healthy |
| merchandise | OK | OK | OK | Healthy |
| orgs | OK | OK | OK | Healthy |
| orgs_frontend | OK | OK | OK | Healthy |
| page_builder | OK | OK | OK | Healthy |
| partners | OK | OK | OK | Healthy |
| raffle | OK | OK | OK | Healthy |
| webhooks | OK | OK | OK | Healthy |

No action needed.
```

---

## Related Skills

This skill works with:
- **`/code-review`** - Comprehensive review includes package boundary checks
- **`/architect`** - System design decisions affect package structure and dependencies
- **`/migration`** - Database migrations must follow table naming conventions (package prefix)
- **`/performance`** - Cross-package N+1 queries need attention (use `includes`)
- **`/multi-tenancy`** - Package resolvers must scope by facility_id

**Workflow**: `/orchestrate feature` includes packwerk validation for package changes

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

If you discover a new package, missing convention, or better validation approach while running this skill, note it and run `/kaizen` after the validation is complete — do NOT self-edit this file mid-execution.

> Improvement history archived in [`kaizen_log.md`](kaizen_log.md).
