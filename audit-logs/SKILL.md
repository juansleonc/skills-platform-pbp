---
name: audit-logs
description: Validates audit log tracker implementations for correctness, completeness, and adherence to project conventions. Use when creating new trackers, modifying existing ones, or reviewing audit log code.
allowed-tools: [Bash, Read, Write, Edit, Grep, Glob, Agent]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

# Audit Logs Validator

Validates audit log tracker implementations against project conventions and the documented event catalog.

## When to Use

- Creating a new audit event tracker
- Modifying an existing tracker
- Reviewing PR code that touches `packs/audit_logs/`
- Adding `EventTrackable` to a controller
- Verifying tracker coverage against Confluence documentation

## Architecture Quick Reference

```
Controller (include AuditLogs::EventTrackable)
  → track_event(:event_type, target:, **params)
    → EventTrackable resolves tracker class by convention
      → AuditLogs::Trackers::{EventType}Tracker
        → BaseTracker.call(**params)
          → new(**params).execute(event_tracker:)
            → AuditLogs::EventTracker.track(...)
              → LogWriterJob (async → DynamoDB)
```

**Key files:**
- Concern: `packs/audit_logs/app/services/event_trackable.rb`
- Base: `packs/audit_logs/app/services/trackers/base_tracker.rb`
- EventTracker: `packs/audit_logs/app/services/event_tracker.rb`
- Trackers: `packs/audit_logs/app/services/trackers/*.rb`
- Specs: `packs/audit_logs/spec/services/trackers/*.rb`
- Event config: `packs/audit_logs/config/event_actions.yml`
- Display handlers: `packs/audit_logs/app/services/display_value_generators/*.rb`

**Auto-resolution priority:** `@current_facility` > `@facility` for facility; `current_user` for actor.

## Naming Convention

Event type → Tracker class (automatic resolution):

| Event Type (symbol) | Tracker Class |
|---------------------|---------------|
| `:waitlist_created` | `WaitlistCreatedTracker` |
| `:rating_linked` | `RatingLinkedTracker` |
| `:payment_method_added` | `PaymentMethodAddedTracker` |

**Rule**: `event_type.to_s.camelize + 'Tracker'` → must exist in `AuditLogs::Trackers::` namespace.

---

## Validation Checklist

### Step 1: Verify Tracker Structure

Every tracker MUST:

```ruby
# frozen_string_literal: true

module AuditLogs
  module Trackers
    class MyEventTracker < BaseTracker
      # Custom initialization (if needed)
      def initialize(custom_param:, **base_args)
        super(**base_args)
        @custom_param = custom_param
      end

      private

      attr_reader :custom_param

      # REQUIRED: Event type string
      def event_type
        'my_event'
      end

      # REQUIRED: What changed (before/after values)
      def change_data
        {
          'field_name' => { 'after' => custom_param.value }
        }
      end

      # OPTIONAL: Contextual info for UI display
      # ⚠️ NEVER put IDs here — use related_objects instead
      def metadata
        { display_label: 'human readable value' }
      end

      # OPTIONAL: References to domain objects
      def related_objects
        [{ 'type' => 'ModelName', 'id' => custom_param.id.to_i }]
      end

      # OPTIONAL: Conditional tracking
      def should_track?
        change_data.present?
      end
    end
  end
end
```

### Step 2: Validate change_data Patterns

| Action | Pattern | Example |
|--------|---------|---------|
| Creation | `{field: {after: value}}` | `{'date' => {'after' => waitlist.date}}` |
| Deletion | `{field: {before: value}}` | `{'date' => {'before' => waitlist_data[:date]}}` |
| Update | `{field: {before: old, after: new}}` | `{'status' => {'before' => 'Active', 'after' => 'Deleted'}}` |

**Rules:**
- Keys MUST be strings (not symbols) — `'field_name'`, not `:field_name`
- Values can be any serializable type
- Passwords → `'[FILTERED]'` always
- HTML content → strip tags before storing
- Large content (>10KB) → EventTracker auto-compresses with gzip + base64
- **Note**: `metadata.compact` is called automatically by BaseTracker — nil values are stripped

### Step 2.5: Register in event_actions.yml

Every new event MUST be registered in `packs/audit_logs/config/event_actions.yml`.
The real file format uses a **class-name handler** (not a snake_case string) and an
optional `expected_target_type`. Copy the structure below (taken verbatim from the file):

```yaml
# Real structure from packs/audit_logs/config/event_actions.yml (note top-level `events:` wrapper):
events:
  payment_method_added:
    description: "Adding a new Credit Card"
    category: player_profile
    display_value_handler: PaymentMethodHandler
    expected_target_type: Payment
```

All events live under a single top-level `events:` key; `EventConfiguration` reads `yaml_data["events"]` (event_configuration.rb:61).

Key differences from older incorrect examples:
- `display_value_handler` is a **CamelCase class name** (`PaymentMethodHandler`), not a snake_case string.
- `expected_target_type` is a class name (e.g. `Payment`, `User`, `MembershipPlan`, `Facility`).
- `category` has no quotes in the real file; use one of: `player_profile`, `reservation_pricing`,
  `membership_plan`, `calendar_actions`.

Without this entry, `EventConfiguration` raises `ArgumentError` ("Invalid event_type") and the `Event`
model fails `event_description_matches_configuration` validation — the event will not be persisted.
Also create the corresponding display value handler in
`packs/audit_logs/app/services/display_value_generators/`.

### Step 3: Validate metadata (Critical)

**metadata goes directly to the UI.** Follow these rules strictly:

| DO | DON'T |
|----|-------|
| Human-readable labels | Internal IDs |
| Formatted amounts (`'10.50'`) | Raw integers |
| Email addresses (contextual) | Database primary keys |
| Counts/totals | Redundant data from change_data |
| Status strings | Data already in related_objects |

```ruby
# ✅ CORRECT metadata
def metadata
  { payment_method: 'Visa ending 4242', total_changes: 3 }
end

# ❌ WRONG — IDs go in related_objects, not metadata
def metadata
  { waitlist_id: 42, user_id: 100 }
end
```

### Step 4: Validate related_objects

```ruby
# Format: Array of {type: String, id: Integer}
def related_objects
  [
    { 'type' => 'Waitlist', 'id' => waitlist.id.to_i },
    { 'type' => 'User', 'id' => user.id.to_i }
  ]
end
```

**Rules:**
- `type` → ActiveRecord class name (string)
- `id` → integer (use `.to_i` for safety)
- Include ALL domain objects affected by the event
- Enables UI navigation to related records

### Step 5: Validate Controller Integration

```ruby
# ✅ CORRECT — minimal, non-intrusive
class MyController < ApplicationController
  include AuditLogs::EventTrackable

  def create
    if @record.save
      track_event(:record_created, target: @record.user, record: @record)
      # ... render response
    end
  end
end
```

**Rules:**
- `include AuditLogs::EventTrackable` — one line
- Call `track_event` directly — NEVER wrap in `safe_track_event` or rescue blocks
- Error handling is centralized in `BaseTracker.call` (rescues StandardError, logs, returns false)
- Audit failures NEVER break the main request flow
- `facility:` and `actor:` auto-resolve from `@facility`/`@current_facility` and `current_user`

### Step 6: Validate Specs

**Tracker spec pattern:**
```ruby
RSpec.describe AuditLogs::Trackers::MyEventTracker do
  let(:facility) { instance_double(Facility) }
  let(:actor) { instance_double(User) }
  let(:target) { instance_double(User) }

  describe '.call' do
    before { allow(AuditLogs::EventTracker).to receive(:track).and_return(true) }

    it 'tracks event with correct parameters' do
      described_class.call(
        facility: facility, actor: actor, target: target,
        custom_param: custom_value
      )

      expect(AuditLogs::EventTracker).to have_received(:track).with(
        event_type: 'my_event',
        facility: facility,
        actor: actor,
        target: target,
        change_data: expected_change_data,
        metadata: {},                        # or expected metadata
        related_objects: expected_objects
      )
    end
  end
end
```

**Controller spec pattern (resilience test):**
```ruby
it 'returns success when audit tracking fails' do
  allow(AuditLogs::EventTracker).to receive(:track)
    .and_raise(StandardError, 'boom')

  post endpoint, params: valid_params.to_json, headers: headers

  expect(response).to have_http_status(:success)
end
```

---

## Event Catalog (dynamic — regenerate from source)

The static catalog was stale (claimed 28 events; real count as of 2026-06-14: **39 trackers**, **38 events** in YAML,
with a `calendar_actions` / `booking_*` category not represented in the old table).
Note: 41 files total in `trackers/`; subtract `base_tracker.rb` and `booking_base_tracker.rb` → 39 real trackers.

**Always regenerate current counts before quoting numbers:**

```bash
# Count tracker files (excludes base_tracker.rb and booking_base_tracker.rb)
ls packs/audit_logs/app/services/trackers/ | grep -v '^base_tracker\|^booking_base_tracker' | wc -l

# Full list of registered events and their categories:
cat packs/audit_logs/config/event_actions.yml
```

The authoritative source for registered events is
`packs/audit_logs/config/event_actions.yml` (one key per event, with
`category`, `description`, `display_value_handler`, and optional
`expected_target_type`).

**Sample entries — regenerate from the commands above for current truth:**

| Event key | Category | Tracker |
|-----------|----------|---------|
| `payment_method_added` | `player_profile` | `PaymentMethodAddedTracker` |
| `booking_player_cancelled` | `calendar_actions` | `BookingPlayerCancelledTracker` |
| `membership_plan_updated` | `membership_plan` | `MembershipPlanUpdatedTracker` |
| `waitlist_created` | `calendar_actions` | `WaitlistCreatedTracker` |

---

## Common Mistakes (from PR reviews)

### 1. Wrapping track_event in controller error handling
```ruby
# ❌ WRONG — error handling is in BaseTracker.call
def safe_track_event(event_type, **args)
  track_event(event_type, **args)
rescue StandardError => e
  Rails.logger.error("...")
end

# ✅ CORRECT — call directly
track_event(:event_created, target: user, record: record)
```

### 2. Putting IDs in metadata
```ruby
# ❌ WRONG — metadata goes to UI
def metadata
  { waitlist_id: waitlist.id }
end

# ✅ CORRECT — IDs in related_objects
def related_objects
  [{ 'type' => 'Waitlist', 'id' => waitlist.id.to_i }]
end
```

### 3. Not handling display value formatting
```ruby
# ⚠️ Trackers store RAW values in change_data
# Titleizing/formatting happens in DisplayValueGenerators, NOT in the tracker
'surface' => { 'after' => waitlist.surface }  # ← This is CORRECT in the tracker

# The DisplayValueGenerator handler (e.g., WaitlistHandler) is responsible for
# formatting: surface.to_s.titleize for UI display
# See: packs/audit_logs/app/services/display_value_generators/

# ❌ WRONG — don't titleize in the tracker itself
'surface' => { 'after' => waitlist.surface&.titleize }

# ✅ CORRECT — store raw, let DisplayValueGenerator format
'surface' => { 'after' => waitlist.surface }
```

### 4. Forgetting should_track? for update trackers
```ruby
# ❌ Tracks even when nothing changed
class MyUpdateTracker < BaseTracker
  def change_data
    # might return empty hash
  end
end

# ✅ Skip tracking if no actual changes
def should_track?
  change_data.present?
end
```

### 5. Not handling destroyed records
```ruby
# ❌ Record already destroyed — can't access associations
track_event(:record_deleted, target: @record.user)

# ✅ Capture data BEFORE destroy
user = @record.user
record_data = @record.attributes.symbolize_keys.slice(:id, :field1, :field2)
@record.destroy
track_event(:record_deleted, target: user, record_data: record_data)
```

---

## New Tracker Template

Use this when creating a new tracker:

```ruby
# frozen_string_literal: true

module AuditLogs
  module Trackers
    class NewEventTracker < BaseTracker
      def initialize(custom_param:, **base_args)
        super(**base_args)
        @custom_param = custom_param
      end

      private

      attr_reader :custom_param

      def event_type
        'new_event'
      end

      def change_data
        {
          'field' => { 'after' => custom_param.field }
        }
      end

      def related_objects
        [{ 'type' => 'ModelName', 'id' => custom_param.id.to_i }]
      end
    end
  end
end
```

---

## Continuous Improvement

If you discover a new pattern, missing convention, or event catalog drift while executing this skill:
1. Complete the current validation first.
2. Run `/kaizen` with the finding — do NOT self-edit this file inline.

History: see [`kaizen_log.md`](kaizen_log.md).
