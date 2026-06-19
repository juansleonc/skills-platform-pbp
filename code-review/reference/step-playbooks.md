# Code Review — Step Playbooks

Relocated verbatim code blocks for review Steps 7–10. The decision logic (what to check, MANDATORY gates) stays in `SKILL.md`; this file holds the good/bad example bodies. These largely duplicate canonical examples owned by `/graphql` and `/sidekiq` — defer to those skills for the deep treatment.

## Contents
- [Step 7 — API Backward Compatibility (GraphQL)](#step-7--api-backward-compatibility-graphql)
- [Step 8 — Sidekiq Job Patterns](#step-8--sidekiq-job-patterns)
- [Step 9 — Cross-Job Consistency (CORE-81 worked example)](#step-9--cross-job-consistency-core-81-worked-example)
- [Step 10 — GraphQL Patterns](#step-10--graphql-patterns)

---

## Step 7 — API Backward Compatibility (GraphQL)

For ANY GraphQL changes (defer to `/graphql` for full backward-compat analysis):

```ruby
# BAD - Removing field (breaks mobile)
- field :old_field, String

# BAD - Changing field type
- field :count, Integer
+ field :count, String

# BAD - Removing query/mutation
- field :old_query, resolver: OldQueryResolver

# GOOD - Deprecating
field :old_field, String, deprecation_reason: "Use new_field instead"

# GOOD - Adding new field (always safe)
+ field :new_field, String
```

---

## Step 8 — Sidekiq Job Patterns

For ANY job changes (defer to `/sidekiq` for full idempotency analysis):

```ruby
# BAD - Multiple arguments
def perform(user_id, facility_id, options)

# GOOD - Single hash argument (Ruby 3 compatibility)
def perform(args)
  args = args.deep_symbolize_keys
  return unless args.is_a?(Hash)
  # Initialize variables BEFORE try blocks
  user = nil
  begin
    user = User.find(args[:user_id])
  rescue => e
    # user is accessible here for logging
  end
end

# Payment jobs MUST be idempotent
def perform(args)
  args = args.deep_symbolize_keys
  idempotency_key = args[:idempotency_key]
  return if already_processed?(idempotency_key)
  # ... process
end
```

---

## Step 9 — Cross-Job Consistency (CORE-81 worked example)

```bash
# Find all job files being changed
changed_jobs=$(git diff develop --name-only | grep "app/jobs/.*_job\.rb")

# For each pattern, verify consistency:
echo "$changed_jobs" | while read job; do
  echo "=== $job ==="
  grep -n "rescue StandardError" "$job" || echo "⚠️ Missing rescue block"
  grep -n "sidekiq_throttle" "$job" || echo "ℹ️ No throttling"
  grep -n "JobsNotificationMailer\|ErrorService" "$job" || echo "⚠️ Missing error notification"
done
```

**Consistency Rules**:
- If 2+ jobs have `rescue StandardError`, ALL similar jobs should have it.
- If 2+ jobs have throttling, validate throttle keys are consistent.
- If 2+ jobs send notifications, validate notification methods match.

**Red Flag**: One job in a group has error handling, others don't = INCONSISTENCY BUG.

**Example from CORE-81**:
```ruby
# ✅ ClinicLessonReminderJob has:
rescue StandardError => e
  JobsNotificationMailer.new_error(...)
  ErrorService.new(e, ...).notify
end

# ✅ MembershipExpirationReminderJob has:
rescue StandardError => e
  JobsNotificationMailer.new_error(...)
  ErrorService.new(e, ...).notify
end

# ❌ MembershipReminderJob MISSING rescue block
# → This is a consistency bug! All 3 jobs should have same error handling.
```

---

## Step 10 — GraphQL Patterns

```ruby
# CHECK for deferred queries usage (performance)
field :heavy_data, resolver: HeavyResolver do
  extension GraphQL::Pro::Defer  # Should use this for heavy operations
end

# CHECK for custom auth in GraphqlController
# Authentication should be in controller, not resolvers

# CHECK for proper error handling
rescue_from ActiveRecord::RecordNotFound do |err|
  raise GraphQL::ExecutionError, "Not found"
end
```
