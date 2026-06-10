---
name: gem-hygiene
description: Audits gem dependencies for vulnerabilities, unused gems, outdated versions, and duplicate functionality. Ensures clean, secure, and maintainable Gemfile.
allowed-tools: [Bash, Read, Grep, Glob, Edit]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## When to Use This Skill

Run this skill when:
- **Quarterly audits** to keep dependencies healthy
- **Adding a new gem** (check for duplicates and existing solutions)
- **Upgrading Ruby/Rails** (identify incompatible or deprecated gems)
- **After security advisories** (check for vulnerable gems)
- **When `/rails-audit` runs** in gem-hygiene mode

# Gem Hygiene Skill

Audits gem dependencies for security vulnerabilities, unused gems, outdated versions, and duplicate functionality.

## CRITICAL RULES

1. **Run `bundle-audit` before every release** — known vulnerabilities must be addressed
2. **Never add gems without checking for existing solutions** — avoid duplication
3. **Pin gem versions in Gemfile** — avoid surprise breaking changes
4. **Remove unused gems** — they add attack surface and slow boot time

## Quick Validation Commands

### 1. Security Vulnerabilities (CRITICAL)

```bash
# Check for known CVEs in dependencies
bin/d bundle exec bundle-audit check --update
```
**Expected**: No vulnerabilities found. Any found must be addressed before release.

### 2. Outdated Gems

```bash
# Show outdated direct dependencies (not transitive)
bin/d bundle outdated --only-explicit --parseable
```
**Expected**: Review each. Major version bumps need careful evaluation.

```bash
# Show just security-relevant outdated gems
bin/d bundle outdated --only-explicit | grep -i "rails\|devise\|rack\|nokogiri\|openssl\|jwt"
```
**Expected**: Security gems should be on latest patch version.

### 3. Potentially Unused Gems

```bash
# Find gems that may not be referenced in code
# Extract gem names from Gemfile (excluding groups, comments, ruby version)
grep "^gem " Gemfile | sed "s/gem '\([^']*\)'.*/\1/" | while read gem_name; do
  # Search for gem usage in app/, lib/, config/ (excluding Gemfile itself)
  refs=$(grep -rl "$gem_name" app/ lib/ config/ --include="*.rb" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$refs" = "0" ]; then
    echo "⚠️ No references found: $gem_name"
  fi
done
```
**Expected**: Review each flagged gem. Some gems work via Railtie/middleware without explicit references.

**False positives to ignore:**
- `rails`, `sprockets`, `sass-rails` — framework gems loaded automatically
- `puma`, `sidekiq` — server/worker gems
- `rspec-rails`, `factory_bot_rails` — test gems (only used in spec/)
- `rubocop-*` — linter gems
- Database adapters (`mysql2`, `redis`)

### 4. Duplicate Functionality

```bash
# Check for overlapping gems
echo "=== HTTP Clients ==="
grep -E "gem '(httparty|faraday|rest-client|http|typhoeus|excon)'" Gemfile

echo "=== JSON Parsers ==="
grep -E "gem '(oj|yajl|multi_json|json)'" Gemfile

echo "=== Background Jobs ==="
grep -E "gem '(sidekiq|delayed_job|resque|good_job|solid_queue)'" Gemfile

echo "=== Search ==="
grep -E "gem '(elasticsearch|opensearch|searchkick|chewy|thinking-sphinx)'" Gemfile

echo "=== Auth ==="
grep -E "gem '(devise|sorcery|clearance|rodauth|authlogic)'" Gemfile

echo "=== File Upload ==="
grep -E "gem '(carrierwave|active_storage|shrine|paperclip|dragonfly)'" Gemfile

echo "=== Pagination ==="
grep -E "gem '(kaminari|will_paginate|pagy)'" Gemfile

echo "=== State Machine ==="
grep -E "gem '(aasm|state_machines|workflow|statesman)'" Gemfile
```
**Expected**: At most one gem per category (with documented exceptions).

## Audit Process

### Step 1: Security Scan

```bash
bin/d bundle exec bundle-audit check --update
```

For each vulnerability:
- **CRITICAL/HIGH**: Must fix before next release
- **MEDIUM**: Plan fix within current sprint
- **LOW**: Track and fix when convenient

### Step 2: Version Health

```bash
# Count how many gems are significantly behind
bin/d bundle outdated --only-explicit 2>/dev/null | wc -l
```

**Triage rules:**
- **Patch updates** (1.2.3 → 1.2.4): Usually safe to update
- **Minor updates** (1.2.3 → 1.3.0): Review changelog
- **Major updates** (1.2.3 → 2.0.0): Plan dedicated upgrade task

### Step 3: Gemfile Review

```bash
# Check for unpinned gems (no version constraint)
grep "^gem " Gemfile | grep -v "~>\|>=\|=" | grep -v "github:\|git:\|path:"
```
**Expected**: All gems should have version constraints (`~>` preferred)

```bash
# Check for gems pinned to exact versions (too strict)
grep "^gem " Gemfile | grep -E "', '[0-9]+\.[0-9]+\.[0-9]+'$"
```
**Expected**: Prefer `~>` over exact pins unless there's a specific reason

### Step 4: Boot Time Impact

```bash
# Measure Rails boot time (slow boot often = too many gems)
time bin/d rails runner "puts 'loaded'"
```
**Expected**: <15s boot time. If >30s, consider removing unused gems.

## Report Format

```markdown
## Gem Hygiene Report

### Security
- Vulnerabilities: X (Y critical, Z medium)
- Action items: [list]

### Outdated Gems
- Total outdated: X
- Major updates available: Y
- Security gems outdated: Z

### Potentially Unused
| Gem | Last Used | Recommendation |
|-----|-----------|----------------|
| gem_name | No references | Investigate removal |

### Duplicate Functionality
| Category | Gems | Recommendation |
|----------|------|----------------|
| HTTP | httparty, faraday | Standardize on one |

### Recommendations
1. Update [gem] to fix CVE-XXXX
2. Remove [unused_gem] to reduce boot time
3. Consolidate HTTP clients to [chosen_gem]
```

---

## Related Skills

This skill works with:
- **`/security`** - Vulnerable gems are security issues
- **`/performance`** - Unused gems slow boot time
- **`/rails-audit`** - Orchestrates gem-hygiene as part of full audit

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new duplicate functionality category
- A better unused gem detection pattern
- Common false positives to document

**You MUST**:
1. Complete the current gem audit first
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements**:
<!-- Kaizen entries will be added here -->
