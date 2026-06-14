---
name: safe-script
description: Generates safe, idempotent scripts for manual database fixes and data migrations. Validates SQL injection risks, adds rollback capability, and tests in Docker before production.
allowed-tools: [Bash, Read, Write, Edit, Grep, Glob]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

# Safe Script Generator Skill

Creates production-safe scripts for manual data fixes with automatic rollback and testing.

## CRITICAL RULES

1. **Always use SQL direct** for manual fixes (skips callbacks that can fail)
2. **Never use heredocs in Rails console** (`rails c`) — they don't paste well interactively. Runner scripts (`rails runner script.rb`) may use `<<~SQL` heredocs since they are files, not pasted input.
3. **Always test in Docker** before running in production
4. **Add rollback logic** to every script
5. **Make scripts idempotent** (safe to run multiple times)
6. **Log all changes** for audit trail

## Shared References

> **📚 This skill uses shared documentation. See:**
> - [Critical Rules](../shared/critical-rules.md) - Project-wide rules
> - [Forbidden Patterns](../shared/forbidden-patterns.md) - Patterns to avoid

## When to Use This Skill

Use `/safe-script` when you need to:
- Fix data inconsistencies in production
- Backfill missing associations
- Update incorrect values in bulk
- Migrate data between tables
- Clean up orphaned records

**DO NOT use** for:
- Regular migrations (use `rails generate migration`)
- Automated jobs (use Sidekiq)
- Business logic (use services)

## Script Template

Every safe script follows this structure:

```ruby
#!/usr/bin/env rails runner
# frozen_string_literal: true

# Purpose: [Describe what this script does]
# JIRA: PLA-XXXX
# Date: YYYY-MM-DD
# Author: [Your name]
#
# Testing:
#   bin/d runner scripts/fix_name.rb
#
# Production:
#   RAILS_ENV=production bin/d runner scripts/fix_name.rb

class SafeScriptTemplate
  def self.run(dry_run: true)
    new.execute(dry_run: dry_run)
  end

  def initialize
    @changes = []
    @errors = []
    @start_time = Time.current
  end

  def execute(dry_run: true)
    log "Starting script: #{self.class.name}"
    log "Mode: #{dry_run ? 'DRY RUN' : 'LIVE'}"
    log "Environment: #{Rails.env}"

    # Safety check
    unless confirmed?(dry_run)
      log "Script cancelled by user"
      return
    end

    ActiveRecord::Base.transaction do
      process_records(dry_run)

      if dry_run
        log "\n⚠️  DRY RUN - Rolling back changes"
        raise ActiveRecord::Rollback
      else
        log "\n✅ Committing changes"
      end
    end

    print_summary
  rescue StandardError => e
    log_error "Script failed: #{e.message}"
    log_error e.backtrace.first(5).join("\n")
    raise
  end

  private

  def confirmed?(dry_run)
    return true if dry_run

    print "\n⚠️  LIVE MODE - This will modify production data!\n"
    print "Type 'yes' to continue: "
    response = $stdin.gets.chomp
    response.downcase == 'yes'
  end

  def process_records(dry_run)
    # Main logic goes here
    # Use find_each for large datasets
    # Use direct SQL for skipping callbacks
    # Log all changes to @changes array

    # Example:
    # Model.where(condition).find_each do |record|
    #   fix_record(record, dry_run)
    # end
  end

  def fix_record(record, dry_run)
    # Implement fix logic
    # Example:
    # old_value = record.attribute
    # new_value = calculate_new_value(old_value)
    #
    # if dry_run
    #   @changes << "Would update #{record.id}: #{old_value} → #{new_value}"
    # else
    #   # Use update_column to skip callbacks
    #   record.update_column(:attribute, new_value)
    #   @changes << "Updated #{record.id}: #{old_value} → #{new_value}"
    # end
  end

  def log(message)
    puts "[#{Time.current.strftime('%H:%M:%S')}] #{message}"
  end

  def log_error(message)
    @errors << message
    puts "[ERROR] #{message}"
  end

  def print_summary
    duration = (Time.current - @start_time).round(2)

    log "\n" + "=" * 80
    log "Script Summary"
    log "=" * 80
    log "Duration: #{duration}s"
    log "Changes: #{@changes.count}"
    log "Errors: #{@errors.count}"

    if @changes.any?
      log "\nChanges made:"
      @changes.first(10).each { |c| log "  - #{c}" }
      log "  ... and #{@changes.count - 10} more" if @changes.count > 10
    end

    if @errors.any?
      log "\n⚠️  Errors encountered:"
      @errors.each { |e| log "  - #{e}" }
    end

    log "=" * 80
  end
end

# Run script
# Default to dry_run unless LIVE=true env var set
dry_run = ENV['LIVE'] != 'true'
SafeScriptTemplate.run(dry_run: dry_run)
```

## Pattern Library

### Pattern 1: Direct SQL for Callback-Skipping

```ruby
# ❌ DANGEROUS - Triggers callbacks that can fail
MembershipPayment.create!(payment_id: 123, membership_id: 456)

# ✅ SAFE - Direct SQL skips callbacks
# NOTE: #{payment_id} and #{membership_id} are trusted integer AR attributes (model.id).
# Interpolating guaranteed-integer values from AR models into SQL is acceptable in scripts
# (see CLAUDE.local.md Rule #11). For external/user-supplied values, see Pattern 6.
ActiveRecord::Base.connection.execute(
  "INSERT INTO membership_payments (payment_id, membership_id, created_at, updated_at) " \
  "VALUES (#{payment_id}, #{membership_id}, NOW(), NOW())"
)

# ✅ ALSO SAFE - update_column skips callbacks
payment.update_column(:paid, true)
```

### Pattern 2: Idempotent Operations

```ruby
# ❌ BAD - Fails if run twice
User.create!(email: 'new@example.com')

# ✅ GOOD - Safe to run multiple times
User.find_or_create_by!(email: 'new@example.com')

# ❌ BAD - Adds duplicate associations
user.facilities << facility

# ✅ GOOD - Only adds if not present
user.facilities << facility unless user.facilities.include?(facility)
```

### Pattern 3: Batch Processing

```ruby
# ❌ BAD - Loads all records into memory
users = User.all
users.each { |u| fix_user(u) }

# ✅ GOOD - Processes in batches
User.find_each(batch_size: 500) do |user|
  fix_user(user)
end

# ✅ BETTER - With progress tracking
total = User.count
processed = 0

User.find_each(batch_size: 500) do |user|
  fix_user(user)
  processed += 1
  log "Progress: #{processed}/#{total}" if processed % 100 == 0
end
```

### Pattern 4: Safe Date Handling

```ruby
# ❌ NEVER - Ruby 3 deprecated
starts = membership.acquired_at.to_s(:db)

# ✅ ALWAYS - Use strftime
starts = membership.acquired_at.strftime('%Y-%m-%d %H:%M:%S')

# ✅ BETTER - Handle nil
starts = membership.acquired_at&.strftime('%Y-%m-%d %H:%M:%S') ||
         Time.current.strftime('%Y-%m-%d %H:%M:%S')
```

### Pattern 5: Transaction with Explicit Rollback

```ruby
# ✅ GOOD - Automatic rollback in dry run
ActiveRecord::Base.transaction do
  # Make changes
  update_records

  if dry_run
    log "DRY RUN - Rolling back"
    raise ActiveRecord::Rollback
  end
end

# ✅ BETTER - With savepoint for nested transactions
ActiveRecord::Base.transaction(requires_new: true) do
  update_records
  raise ActiveRecord::Rollback if dry_run
end
```

### Pattern 6: SQL Injection Prevention

**The single coherent rule:**
- **Trusted integers** (AR model `.id`, `Integer()` cast on ARGV/CSV input, numeric literals) → `#{}` interpolation is **acceptable** in script context (CLAUDE.local.md Rule #11).
- **External/uncast strings** (ARGV without cast, CSV-parsed strings, ENV values, any user-supplied text) → **always use bind params or AR methods**. Never interpolate.

```ruby
# ❌ DANGEROUS - external string value interpolated directly into SQL
user_id = ARGV[0]                  # String from command line, unvalidated
sql = "UPDATE users SET active = true WHERE id = #{user_id}"
ActiveRecord::Base.connection.execute(sql)
# Risk: ARGV[0] = "1 OR 1=1" → full-table update

# ✅ SAFE - cast to Integer first (raises on non-integer, prevents injection)
user_id = Integer(ARGV[0])
sql = "UPDATE users SET active = true WHERE id = #{user_id}"
ActiveRecord::Base.connection.execute(sql)

# ✅ SAFE - Parameterized query (always correct regardless of source)
user_id = ARGV[0]
sql = "UPDATE users SET active = true WHERE id = ?"
ActiveRecord::Base.connection.execute(
  ActiveRecord::Base.sanitize_sql([sql, user_id])
)

# ✅ SAFEST - Use ActiveRecord methods (no raw SQL needed)
user_id = ARGV[0]
User.where(id: user_id).update_all(active: true)
```

## Workflow

### Step 1: Understand the Problem

```
Questions to answer:
1. What data is incorrect?
2. How many records affected?
3. What should the correct value be?
4. Can this be done with a migration?
5. Are there any dependencies?
```

### Step 2: Generate Script

```bash
# Use this skill to generate script
/safe-script

# Provide context:
# - JIRA ticket
# - Problem description
# - Affected records count
# - Desired outcome
```

### Step 3: Test in Docker

```bash
# First, check syntax
bin/d ruby -c scripts/fix_membership_payments.rb

# Run in dry-run mode (default)
bin/d runner scripts/fix_membership_payments.rb

# Check output - should show:
# - Number of records to change
# - Before/after values
# - Any errors
# - "DRY RUN - Rolling back"
```

### Step 4: Verify in Test Database

```bash
# Run against test data
RAILS_ENV=test bin/d runner scripts/fix_membership_payments.rb

# Verify changes
bin/d runner "puts MembershipPayment.where(payment_id: 123).inspect"
```

### Step 5: Run in Production

```bash
# ONLY after testing in Docker + review

# Dry run first (production env, still dry-run by default)
RAILS_ENV=production bin/d runner scripts/fix_membership_payments.rb

# Review output carefully

# If all looks good, run live
RAILS_ENV=production LIVE=true bin/d runner scripts/fix_membership_payments.rb

# Monitor output for errors
```

## Real-World Examples

### Example 1: Backfill Missing Associations

```ruby
#!/usr/bin/env rails runner
# Purpose: Backfill membership_payments for payments missing association
# JIRA: PLA-1234

class BackfillMembershipPayments
  def self.run(dry_run: true)
    new.execute(dry_run: dry_run)
  end

  def execute(dry_run:)
    log "Finding payments missing membership_payments..."

    # Find payments that should have membership_payments
    payments = Payment.where(payment_type: 'membership')
                     .where.not(id: MembershipPayment.select(:payment_id))

    log "Found #{payments.count} payments to fix"

    ActiveRecord::Base.transaction do
      payments.find_each do |payment|
        backfill_payment(payment, dry_run)
      end

      raise ActiveRecord::Rollback if dry_run
    end

    log "#{dry_run ? 'Would create' : 'Created'} #{payments.count} membership_payments"
  end

  private

  def backfill_payment(payment, dry_run)
    # Find associated membership
    membership = Membership.find_by(user_id: payment.user_id, facility_id: payment.facility_id)

    unless membership
      log_error "No membership found for payment #{payment.id}"
      return
    end

    if dry_run
      log "Would create: payment_id=#{payment.id}, membership_id=#{membership.id}"
    else
      # Direct SQL to skip callbacks.
      # #{payment.id} and #{membership.id} are AR integer attributes — trusted integers,
      # not external input. Heredoc is fine here (runner script, not interactive console).
      sql = <<~SQL
        INSERT INTO membership_payments
        (payment_id, membership_id, created_at, updated_at)
        VALUES (#{payment.id}, #{membership.id}, NOW(), NOW())
      SQL

      ActiveRecord::Base.connection.execute(sql)
      log "Created: payment_id=#{payment.id}, membership_id=#{membership.id}"
    end
  end
end

BackfillMembershipPayments.run(dry_run: ENV['LIVE'] != 'true')
```

### Example 2: Fix Incorrect Timestamps

```ruby
#!/usr/bin/env rails runner
# Purpose: Fix reservations with ends_at before starts_at
# JIRA: PLA-5678

class FixReservationTimestamps
  def self.run(dry_run: true)
    new.execute(dry_run: dry_run)
  end

  def execute(dry_run:)
    # Find problematic reservations
    bad_reservations = Reservation.where('ends_at < starts_at')

    log "Found #{bad_reservations.count} reservations with invalid timestamps"

    ActiveRecord::Base.transaction do
      bad_reservations.find_each do |reservation|
        fix_reservation(reservation, dry_run)
      end

      raise ActiveRecord::Rollback if dry_run
    end
  end

  private

  def fix_reservation(reservation, dry_run)
    # Calculate correct ends_at (starts_at + duration)
    duration_minutes = reservation.court_reservation_type.duration_minutes
    correct_ends_at = reservation.starts_at + duration_minutes.minutes

    log "Reservation #{reservation.id}:"
    log "  Current: #{reservation.starts_at} → #{reservation.ends_at}"
    log "  Fixed:   #{reservation.starts_at} → #{correct_ends_at}"

    unless dry_run
      # Use update_column to skip validations/callbacks
      reservation.update_column(:ends_at, correct_ends_at)
    end
  end
end

FixReservationTimestamps.run(dry_run: ENV['LIVE'] != 'true')
```

## Safety Checklist

Before running in production:

- [ ] Script tested in Docker
- [ ] Dry run output reviewed
- [ ] Affected record count confirmed
- [ ] Rollback logic tested
- [ ] No SQL injection risks
- [ ] Idempotent (safe to run multiple times)
- [ ] Logs all changes
- [ ] Error handling implemented
- [ ] Transaction boundaries correct
- [ ] Code review completed
- [ ] JIRA ticket linked
- [ ] Backup plan defined

## Integration with Other Skills

### With /debug
```bash
# Debug skill identifies data issue
# Safe-script skill generates fix
/debug → /safe-script
```

### With /orchestrate
```bash
# Orchestrate can trigger safe-script for data fixes
# After identifying inconsistencies
```

## Common Mistakes to Avoid

### Mistake 1: Using ActiveRecord callbacks in fixes
```ruby
# ❌ BAD - Can fail if callbacks have bugs
payment.update!(paid: true)

# ✅ GOOD - Skips callbacks
payment.update_column(:paid, true)
```

### Mistake 2: Not handling nil dates
```ruby
# ❌ CRASHES - if acquired_at is nil
starts = membership.acquired_at.strftime('%Y-%m-%d')

# ✅ SAFE - handles nil
starts = membership.acquired_at&.strftime('%Y-%m-%d') || '2024-01-01'
```

### Mistake 3: Loading too many records
```ruby
# ❌ MEMORY CRASH - on 100k+ records
Membership.all.each { |m| fix(m) }

# ✅ SAFE - batched
Membership.find_each(batch_size: 500) { |m| fix(m) }
```

### Mistake 4: Not testing dry run
```bash
# ❌ DANGEROUS - Run live immediately
RAILS_ENV=production LIVE=true bin/d runner script.rb

# ✅ SAFE - Test dry run first
RAILS_ENV=production bin/d runner script.rb  # See what would change
# Review output
RAILS_ENV=production LIVE=true bin/d runner script.rb  # Then run live
```

## Report Format

```markdown
## Safe Script Report

### Script: fix_membership_payments.rb
**JIRA**: PLA-1234
**Purpose**: Backfill missing membership_payments associations

### Testing Results (Docker)

**Dry Run**:
- Records affected: 47
- Errors: 0
- Duration: 1.2s
- Changes rolled back: ✅

**Test Environment**:
- Records affected: 47
- Errors: 0
- Duration: 1.4s
- Changes committed: ✅
- Verification: All 47 records correctly updated

### Production Run

**Dry Run** (2024-01-28 10:15 AM):
- Records affected: 1,243
- Errors: 0
- Duration: 8.3s
- Output reviewed: ✅

**Live Run** (2024-01-28 10:30 AM):
- Records affected: 1,243
- Errors: 0
- Duration: 9.1s
- Status: ✅ SUCCESS

### Verification Queries

```sql
-- Check all payments have membership_payments
SELECT COUNT(*)
FROM payments
WHERE payment_type = 'membership'
  AND id NOT IN (SELECT payment_id FROM membership_payments);
-- Result: 0 (all fixed)

-- Verify data integrity
SELECT COUNT(*) FROM membership_payments WHERE payment_id IS NULL;
-- Result: 0 (no orphans)
```

### Rollback Plan

If issues detected:
```sql
-- Delete created records (within 1 hour of execution)
DELETE FROM membership_payments
WHERE created_at > '2024-01-28 10:30:00'
  AND updated_at = created_at;
```

### Lessons Learned

- Use direct SQL for bulk inserts (10x faster than ActiveRecord)
- Batch processing essential for 1000+ records
- Always test on subset first (we tested on 50 records before full run)
```

---

## Kaizen: Continuous Improvement

> Historical entries archived to [kaizen_log.md](kaizen_log.md). Append new findings there; promote proven rules into the active body above.

**While executing this skill**, if you discover a new safe pattern, a common mistake, or a better workflow: append to `kaizen_log.md` with format `<!-- Kaizen: YYYY-MM-DD --> ...`, then run `/kaizen` to promote if warranted.
