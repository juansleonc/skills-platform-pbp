---
name: timezone
description: >
  Audit code for timezone safety. Fires when code introduces or modifies
  Time.now / Date.today / DateTime.now / Time.new / Time.parse usage, adds
  date-handling logic (scheduling, memberships, reservations, billing cycles),
  writes time-dependent specs without Timecop, or uses deprecated
  .to_s(:format) date formatting. Suggests Time.current / Date.current /
  facility-scoped timezone helpers and strftime replacements.
allowed-tools: [Bash, Read, Grep, Glob]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## When to Use This Skill

Run this skill when:
- **Modifying code** that uses date/time operations (Time, Date, DateTime)
- **Writing/reviewing specs** with time-dependent assertions
- **Before Rails 7.1+ upgrade** to find deprecated `.to_s(:format)` usage (removed in Rails 7.1)
- **Investigating flaky tests** that fail intermittently (likely time-related)
- **Adding features** with timezone-sensitive logic (scheduling, reservations, memberships)

## Shared References

> **📚 This skill uses shared documentation. See:**
> - [Critical Rules](../shared/critical-rules.md) - timezone safety rules
> - [Forbidden Patterns](../shared/forbidden-patterns.md) - patterns to avoid
> - [ast-grep Patterns](../shared/ast-grep-patterns.md) — AST-aware `Time.now`/`Date.today` detection (no `# BAD` filter heuristics)

# Timezone Safety Audit Skill

Audit code for timezone-unsafe patterns and suggest fixes.

## Critical Rules

**1. NEVER use `Time.now`** - Always use:
- `Time.current` - Current time in application timezone
- `Date.current` - Current date in application timezone
- Facility-specific timezone methods when available

**2. NEVER use deprecated `.to_s(:format)`** (Rails 7.1 removal — repo migrating to 7.2):
- Use `strftime` or `to_fs(:format)` instead of the symbol form

**3. Handle DST transitions** carefully

## Unsafe Patterns

| Pattern | Replacement | Reason |
|---------|-------------|--------|
| `Time.now` | `Time.current` | Not timezone-aware |
| `Date.today` | `Date.current` | Not timezone-aware |
| `DateTime.now` | `Time.current` | Not timezone-aware |
| `Time.new` | `Time.zone.local(...)` | Not timezone-aware |
| `Time.parse(str)` | `Time.zone.parse(str)` | Not timezone-aware |
| `Time.zone.now` | `Time.current` | Redundant (zone already set) |
| `.to_s(:db)` | `.strftime('%Y-%m-%d %H:%M:%S')` or `.to_fs(:db)` | Deprecated Rails 7.0, removed Rails 7.1 |
| `.to_s(:short)` | `.strftime('%d %b %H:%M')` or `.to_fs(:short)` | Deprecated Rails 7.0, removed Rails 7.1 |

## Date Formatting (Rails 7.1 removal)

**The `.to_s(:format)` syntax is a Rails deprecation — deprecated in Rails 7.0 and removed in Rails 7.1. This repo is on Rails 6.1.7 migrating to 7.2, so these patterns will break during the upgrade. Ruby version is irrelevant.**

```ruby
# ❌ Deprecated in Rails 7.0, removed in Rails 7.1 — will break on upgrade to 7.2
date.to_s(:db)              # "2024-01-15"
time.to_s(:db)              # "2024-01-15 10:30:00"
time.to_s(:short)           # "15 Jan 10:30"

# ✅ CORRECT — use strftime (works everywhere) or to_fs (Rails 7.0+ alias)
date.strftime('%Y-%m-%d')             # "2024-01-15"
time.strftime('%Y-%m-%d %H:%M:%S')    # "2024-01-15 10:30:00"
time.strftime('%d %b %H:%M')          # "15 Jan 10:30"
# or: date.to_fs(:db) / time.to_fs(:short)  (Rails 7.0+, not available on 6.1)
```

### Common Format Replacements

| Old Format | strftime Equivalent |
|------------|---------------------|
| `:db` | `'%Y-%m-%d'` (date) / `'%Y-%m-%d %H:%M:%S'` (datetime) |
| `:short` | `'%d %b %H:%M'` |
| `:long` | `'%B %d, %Y %H:%M'` |
| `:iso8601` | `.iso8601` method |

## Nil Safety in Date Formatting

**ALWAYS check for nil before formatting:**

```ruby
# ❌ WRONG - Will crash if nil
starts = membership.acquired_at.strftime('%Y-%m-%d %H:%M:%S')

# ✅ CORRECT - Nil-safe
starts = membership.acquired_at&.strftime('%Y-%m-%d %H:%M:%S')

# ✅ CORRECT - With fallback
starts = membership.acquired_at ?
  membership.acquired_at.strftime('%Y-%m-%d %H:%M:%S') :
  Time.current.strftime('%Y-%m-%d %H:%M:%S')
```

## DST (Daylight Saving Time) Handling

**DST transitions can cause subtle bugs.** Test these scenarios:

```ruby
# DST "spring forward" - 2:00 AM doesn't exist
# March 10, 2024: 1:59 AM → 3:00 AM
Timecop.freeze(Time.zone.parse('2024-03-10 01:30:00')) do
  # Time calculations here
end

# DST "fall back" - 2:00 AM happens twice
# November 3, 2024: 2:00 AM → 1:00 AM
Timecop.freeze(Time.zone.parse('2024-11-03 01:30:00')) do
  # Time calculations here
end
```

### DST-Safe Patterns

```ruby
# ❌ DANGEROUS during DST
tomorrow = Time.current + 24.hours  # Could be 23 or 25 hours

# ✅ SAFE - Uses calendar day
tomorrow = Time.current.tomorrow.beginning_of_day
tomorrow = 1.day.from_now.beginning_of_day
```

### Facility Timezone Handling

```ruby
# Use facility's timezone for local time calculations
class Facility < ApplicationRecord
  def local_time
    Time.current.in_time_zone(time_zone)
  end

  def local_date
    Time.current.in_time_zone(time_zone).to_date
  end
end

# Usage
facility.local_time  # Respects facility timezone
```

## Quick Validation Commands

**Fast timezone violation detection** (run these first):

```bash
# 1. Find Time.now violations (CRITICAL)
grep -rn "Time\.now\|Date\.today\|DateTime\.now\|Time\.zone\.now" app/ lib/ --include="*.rb" | grep -v "# "
```
**Expected**: **0 new occurrences in changed lines**. Known legacy baseline (2026-06-10): ~22 `Time.now` + ~102 `Time.zone.now` in `app/` — do not report these as new findings; they are tracked debt. Focus on lines you introduced or modified.

> **📖 See [ast-grep Patterns](../shared/ast-grep-patterns.md)** when `sg` is installed: `sg run --lang ruby --pattern 'Time.now' app/ lib/` matches only real call expressions — no `grep -v "# "` heuristic needed (eliminates comment/string false positives). Otherwise this grep is the right tool.

```bash
# 2. Find deprecated .to_s(:format) — Rails 7.1 removal (CRITICAL before upgrade)
grep -rn "\.to_s(:db)\|\.to_s(:short)\|\.to_s(:long)" app/ lib/ spec/ --include="*.rb"
```
**Expected**: **0 NEW occurrences in changed lines**. Known baseline (2026-06-15): 3 in `spec/requests/api/v1/users_controller_spec.rb` (lines 1337, 1408, 1448 — raw SQL with `1.day.ago.to_s(:db)`) — tracked debt, not new findings.

```bash
# 3. Find specs without Timecop (HIGH RISK - flaky tests)
grep -rn "expect.*Time\.now\|expect.*Date\.today" spec/ --include="*.rb" | grep -v "Timecop"
```
**Expected**: 0 matches (time-dependent assertions need `Timecop.freeze`)

```bash
# 4. Find DST-sensitive calculations (MEDIUM RISK)
grep -rn "+ 24\.hours\|- 24\.hours" app/ --include="*.rb"
```
**Expected**: 0-3 matches (review each, prefer `.day` or `.tomorrow`)

## Audit Process

1. **Run Quick Validation Commands** (above) for instant detection

2. **Review each violation** and apply fixes from patterns table

3. **Verify nil-safety** on all strftime calls

4. **Check DST scenarios** for time-sensitive features

5. **Generate report** (format below)

## Report Format

```markdown
## Timezone Safety Audit

### Summary
- Files scanned: X
- Violations found: Y
- Deprecated .to_s(:format): Z
- Specs without Timecop: W

### Violations

#### Time.now / Date.today / DateTime.now
| Location | Current | Fix |
|----------|---------|-----|
| app/services/billing_service.rb:45 | `Time.now` | `Time.current` |
| app/services/billing_service.rb:78 | `Date.today` | `Date.current` |

#### Deprecated .to_s(:format) (Rails 7.1 removal)
| Location | Current | Fix |
|----------|---------|-----|
| app/models/user.rb:123 | `.to_s(:db)` | `.strftime('%Y-%m-%d %H:%M:%S')` |
| app/views/show.erb:45 | `.to_s(:short)` | `.strftime('%d %b %H:%M')` |

#### DST-Sensitive Calculations
| Location | Current | Fix |
|----------|---------|-----|
| app/jobs/reminder.rb:23 | `+ 24.hours` | `+ 1.day` or `.tomorrow` |

#### Specs without Timecop
| Location | Issue |
|----------|-------|
| spec/models/user_spec.rb:23 | Time-dependent assertion without freeze |

### Auto-fix Available
Run with `--fix` to automatically replace patterns.
```

## Spec Pattern for Time-Dependent Tests

```ruby
# CORRECT
describe '#expires_at' do
  it 'returns expiration time' do
    Timecop.freeze(Time.current) do
      user = build(:user)
      expect(user.expires_at).to eq(30.days.from_now)
    end
  end
end

# INCORRECT - will fail randomly
describe '#expires_at' do
  it 'returns expiration time' do
    user = build(:user)
    expect(user.expires_at).to eq(Time.now + 30.days) # BAD!
  end
end
```

### Illustrative examples (NOT from this codebase — do not cite as evidence)

These examples demonstrate common timezone-unsafe patterns. They are NOT sourced from real files or line numbers in this codebase.

### EXAMPLE 1: Membership expiration calculation (timezone-unaware)
```ruby
# ❌ BAD - Arithmetic on naive acquired_at ignores facility timezone
def expires_at
  acquired_at + duration.days if acquired_at.present?
end

# ✅ GOOD - Timezone-aware
def expires_at
  acquired_at&.in_time_zone(facility.time_zone)&.+(duration.days)
end
```

Note: `app/models/membership.rb:178` in this codebase contains `Time.zone.now` in a pause/resume transition — a different pattern. `app/services/reservation_notifier.rb` and `app/services/payment_service.rb` do not exist at HEAD.

### EXAMPLE 2: Deprecated `.to_s(:format)` on timestamps (Rails 7.1 removal)
```ruby
# ❌ BAD - Deprecated in Rails 7.0, removed in Rails 7.1
starts = reservation.starts_at.to_s(:db)

# ✅ GOOD - Works on all Rails versions
starts = reservation.starts_at.strftime('%Y-%m-%d %H:%M:%S')

# ✅ BETTER - Nil-safe
starts = reservation.starts_at&.strftime('%Y-%m-%d %H:%M:%S') || 'Not scheduled'
```

### EXAMPLE 3: Time.now on payment timestamp
```ruby
# ❌ BAD - Not timezone-aware
payment.update(processed_at: Time.now)

# ✅ GOOD - Timezone-aware
payment.update(processed_at: Time.current)
```

### EXAMPLE 4: Flaky spec — time assertion without Timecop
```ruby
# ❌ BAD - Non-deterministic (real clock may drift between membership.renew! and assertion)
it 'sets renewal date' do
  membership.renew!
  expect(membership.renewed_at).to be_within(1.second).of(Time.now)
end

# ✅ GOOD - Frozen time
it 'sets renewal date' do
  Timecop.freeze(Time.current) do
    membership.renew!
    expect(membership.renewed_at).to eq(Time.current)
  end
end
```

## Example

```
User: /timezone

Claude:
## Timezone Safety Audit

Scanning codebase...

### Summary
- Files scanned: 1,546
- Time.now violations: 2
- Deprecated .to_s(:format): 3
- Specs without Timecop: 2

### Violations

#### Time.now Violations

##### app/services/report_generator.rb:67
```ruby
# Current (unsafe)
report_date = Time.now.beginning_of_day

# Suggested fix
report_date = Time.current.beginning_of_day
```

#### Deprecated .to_s(:format) (Rails 7.1 removal)

##### app/models/membership.rb:145
```ruby
# Current (deprecated)
created_at.to_s(:db)

# Suggested fix
created_at.strftime('%Y-%m-%d %H:%M:%S')
```

##### app/views/reservations/_show.html.erb:23
```ruby
# Current (deprecated)
starts_at.to_s(:short)

# Suggested fix
starts_at.strftime('%d %b %H:%M')
```

#### Specs without Timecop

##### spec/models/subscription_spec.rb:145
```ruby
# Current (flaky test)
expect(subscription.renewed_at).to be_within(1.second).of(Time.now)

# Suggested fix
Timecop.freeze(Time.current) do
  expect(subscription.renewed_at).to eq(Time.current)
end
```

### Quick Fix
Apply all fixes? (y/n)
```

## Auto-Fix Mode

When invoked with `--fix`:
```
/timezone --fix
```

Will automatically replace safe patterns (with user confirmation).

---

## Related Skills

This skill works with:
- **`/code-review`** - Comprehensive review includes timezone safety checks
- **`/tdd`** - Test implementation validates Timecop usage in specs
- **`/performance`** - Time calculations can impact query performance
- **`/sidekiq`** - Job scheduling requires timezone-aware time handling

**Workflow**: `/orchestrate feature` automatically includes timezone validation in Phase 1A

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new timezone-unsafe pattern
- A missing edge case
- A better grep pattern for detection

**You MUST**:
1. Complete the current timezone audit first
2. Note the improvement and run `/kaizen` after the audit to persist it
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content` (goes in `kaizen_log.md`, not inline)

**Recent Improvements**: see [kaizen_log.md](kaizen_log.md) for full history.
