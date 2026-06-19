# Architect Skill — Worked Examples

Relocated from `SKILL.md` to keep the live body under the 500-line ceiling.

---

## Example 1: Push Notifications Feature

```
/architect push notifications system

## ADR: Push Notifications

### Context
Need to send push notifications to mobile users for reservations,
membership renewals, and promotions.

### Production Data Analysis (ClickHouse)
- Users table: 450k records
- Active users (last 30 days): 52k
- Facilities: 180
- Avg users per facility: 2,500

### Decision
**Location:** `packs/push_notifications/`
**Pattern:**
  - `PushNotifications::SendService` (Interactor) for sending
  - `PushNotifications::TokenManager` for device tokens
  - Sidekiq job for bulk sends

**Schema:**
```ruby
create_table :push_notification_tokens do |t|
  t.references :facility, null: false
  t.references :user, null: false
  t.string :device_token, null: false
  t.string :platform, null: false  # ios, android
  t.boolean :active, default: true
  t.timestamps
end
add_index :push_notification_tokens, [:facility_id, :user_id]
add_index :push_notification_tokens, [:device_token], unique: true
```

**API:**
- `registerPushToken` mutation
- `unregisterPushToken` mutation

### Implementation Plan
1. Create pack structure
2. Add migration for tokens table
3. Implement TokenManager service
4. Add GraphQL mutations
5. Implement SendService with Firebase integration
6. Add Sidekiq job for bulk notifications
```
