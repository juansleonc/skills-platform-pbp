#!/usr/bin/env rails runner
# frozen_string_literal: true

# Purpose: [Describe what this script does]
# JIRA: PLA-XXXX
# Date: YYYY-MM-DD
# Author: [Your name]
#
# Dry-run (Docker dev):   bin/d runner scripts/fix_name.rb
# Live (Docker dev):      LIVE=true bin/d runner scripts/fix_name.rb
#
# PRODUCTION: execute INSIDE the prod pod/runner (kubectl exec / rails runner in the
# deployed container), NOT via the local bin/d wrapper. bin/d targets the local
# docker-compose dev stack only — it never connects to the production cluster, and
# RAILS_ENV=production locally points at an absent/misconfigured prod DB config.
#   Dry-run in pod:  rails runner scripts/fix_name.rb
#   Live in pod:     LIVE=true rails runner scripts/fix_name.rb
#
# Headless confirmation: when LIVE=true and STDIN is not a TTY (e.g. `docker compose
# exec -T`, piped, or in-pod non-interactive), the script requires CONFIRM=yes instead
# of an interactive prompt. Without it, the live run aborts rather than hanging.

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

    unless confirmed?(dry_run)
      log 'Script cancelled (not confirmed)'
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

  # Headless-safe confirmation. Interactive TTY → prompt for 'yes'.
  # Non-TTY (Docker exec -T, piped, in-pod) → require CONFIRM=yes env var so the
  # run never hangs on $stdin.gets and never crashes on nil.chomp.
  def confirmed?(dry_run)
    return true if dry_run

    unless $stdin.tty?
      return ENV['CONFIRM'] == 'yes'
    end

    print "\n⚠️  LIVE MODE - This will modify production data!\n"
    print "Type 'yes' to continue: "
    $stdin.gets.to_s.chomp.downcase == 'yes'
  end

  def process_records(dry_run)
    # Main logic. Use find_each for large datasets; direct SQL to skip callbacks;
    # log every change to @changes.
    #
    # Model.where(condition).find_each(batch_size: 500) do |record|
    #   fix_record(record, dry_run)
    # end
  end

  def fix_record(record, dry_run)
    # old_value = record.attribute
    # new_value = calculate_new_value(old_value)
    # if dry_run
    #   @changes << "Would update #{record.id}: #{old_value} → #{new_value}"
    # else
    #   record.update_column(:attribute, new_value) # skip callbacks
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

    log "\n#{'=' * 80}"
    log 'Script Summary'
    log '=' * 80
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

    log '=' * 80
  end
end

# Default to dry_run unless LIVE=true env var set.
SafeScriptTemplate.run(dry_run: ENV['LIVE'] != 'true')
