# Sidekiq Audit — Output Template

Use this template to present the result of a Sidekiq job audit.

````markdown
## Sidekiq Job Audit

### Jobs Analyzed
- ProcessPaymentJob
- SendEmailJob
- SyncMembershipJob

### Results

| Job | Hash Arg | Symbolize | Init Before Try | Idempotent | Status |
|-----|----------|-----------|-----------------|------------|--------|
| ProcessPaymentJob | ✅ | ✅ | ✅ | ✅ | OK |
| SendEmailJob | ✅ | ✅ | ❌ | N/A | FAIL |
| SyncMembershipJob | ❌ | ❌ | ❌ | N/A | FAIL |

### Violations

#### SendEmailJob:23 - Variable not initialized before try
```ruby
# Current
begin
  user = User.find(user_id)
rescue
  log(user.email)  # user undefined!
end

# Fix
user = nil
begin
  user = User.find(user_id)
rescue
  log("User #{user_id} not found")
end
```

#### SyncMembershipJob:5 - Multiple arguments
```ruby
# Current
def perform(user_id, membership_id)

# Fix
def perform(args)
  args = args.deep_symbolize_keys
  user_id = args[:user_id]
  membership_id = args[:membership_id]
```
````
