# Safe Script — Real-World Examples

> **WARNING — INCOMPLETE FOR COPY-PASTE**: These examples omit the `confirmed?` method
> for brevity. Without it, a `LIVE=true` run in a non-TTY context (e.g. `docker compose
> exec -T`, in-pod `rails runner`, piped stdin) will **hang** on `$stdin.gets` or
> **crash** on `nil.chomp`. Always copy the full `confirmed?` implementation from
> `scripts/template.rb` and call it at the start of `execute` — see the `unless
> confirmed?(dry_run)` guard in that template. These examples show business logic only.

Two worked scripts. Both default to dry-run (`LIVE=true` flips to live), wrap work in
a transaction, and skip callbacks via direct SQL / `update_column`.

## Example 1: Backfill Missing Associations

```ruby
#!/usr/bin/env rails runner
# Purpose: Backfill membership_payments for payments missing association
# JIRA: PLA-1234

class BackfillMembershipPayments
  def self.run(dry_run: true)
    new.execute(dry_run: dry_run)
  end

  def execute(dry_run:)
    log 'Finding payments missing membership_payments...'

    payments = Payment.where(payment_type: 'membership')
                      .where.not(id: MembershipPayment.select(:payment_id))

    log "Found #{payments.count} payments to fix"

    ActiveRecord::Base.transaction do
      payments.find_each { |payment| backfill_payment(payment, dry_run) }
      raise ActiveRecord::Rollback if dry_run
    end

    log "#{dry_run ? 'Would create' : 'Created'} #{payments.count} membership_payments"
  end

  private

  def backfill_payment(payment, dry_run)
    membership = Membership.find_by(user_id: payment.user_id, facility_id: payment.facility_id)

    unless membership
      log_error "No membership found for payment #{payment.id}"
      return
    end

    if dry_run
      log "Would create: payment_id=#{payment.id}, membership_id=#{membership.id}"
    else
      # Direct SQL to skip callbacks. #{payment.id}/#{membership.id} are AR integer
      # attributes — trusted integers, not external input. Heredoc is fine in a runner
      # file (not interactive `rails c`; see SKILL.md Critical Rules).
      sql = <<~SQL
        INSERT INTO membership_payments
        (payment_id, membership_id, created_at, updated_at)
        VALUES (#{payment.id}, #{membership.id}, NOW(), NOW())
      SQL
      ActiveRecord::Base.connection.execute(sql)
      log "Created: payment_id=#{payment.id}, membership_id=#{membership.id}"
    end
  end

  def log(msg) = puts("[#{Time.current.strftime('%H:%M:%S')}] #{msg}")
  def log_error(msg) = puts("[ERROR] #{msg}")
end

BackfillMembershipPayments.run(dry_run: ENV['LIVE'] != 'true')
```

## Example 2: Fix Incorrect Timestamps

```ruby
#!/usr/bin/env rails runner
# Purpose: Fix reservations with ends_at before starts_at
# JIRA: PLA-5678

class FixReservationTimestamps
  def self.run(dry_run: true)
    new.execute(dry_run: dry_run)
  end

  def execute(dry_run:)
    bad_reservations = Reservation.where('ends_at < starts_at')
    log "Found #{bad_reservations.count} reservations with invalid timestamps"

    ActiveRecord::Base.transaction do
      bad_reservations.find_each { |r| fix_reservation(r, dry_run) }
      raise ActiveRecord::Rollback if dry_run
    end
  end

  private

  def fix_reservation(reservation, dry_run)
    duration_minutes = reservation.court_reservation_type.duration_minutes
    correct_ends_at = reservation.starts_at + duration_minutes.minutes

    log "Reservation #{reservation.id}: #{reservation.starts_at} → #{reservation.ends_at} " \
        "(fixing to #{correct_ends_at})"

    # update_column skips validations/callbacks
    reservation.update_column(:ends_at, correct_ends_at) unless dry_run
  end

  def log(msg) = puts("[#{Time.current.strftime('%H:%M:%S')}] #{msg}")
end

FixReservationTimestamps.run(dry_run: ENV['LIVE'] != 'true')
```
