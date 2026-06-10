---
name: debug
description: Production debugging using Honeybadger, Sentry, ClickHouse, logs, and Rails console. Systematic approach to diagnose and fix production issues.
allowed-tools: [Bash, Read, Grep, Glob, Edit, mcp__github__*, mcp__clickhouse__run_select_query, mcp__clickhouse__list_tables, mcp__honeybadger__list_faults, mcp__honeybadger__get_fault, mcp__honeybadger__list_fault_notices, mcp__sentry__sentry_list_projects, mcp__sentry__sentry_list_issues, mcp__sentry__sentry_get_issue, mcp__sentry__sentry_get_issue_events, mcp__opensearch__*, mcp__rails__*, mcp__ide__executeCode, mcp__ide__getDiagnostics]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## Shared References

> **📚 This skill uses MCP tools for production debugging.** See allowed-tools list above for available MCPs.

# Production Debugging Skill

Systematic approach to diagnose and fix production issues using Honeybadger, Sentry, ClickHouse, logs, and Rails patterns.

## PRIMARY METHOD: Use MCP Tools

**ALWAYS use MCP tools FIRST for production debugging:**

| Priority | Tool Category | When to Use |
|----------|---------------|-------------|
| 🥇 **PRIMARY** | MCP ClickHouse | **START HERE** - Events, logs, patterns, duplicates |
| 🥇 **PRIMARY** | MCP Honeybadger | Error context, stack traces, affected users |
| 🥇 **PRIMARY** | MCP Sentry | GraphQL, mobile, frontend errors |
| 🥇 **PRIMARY** | MCP OpenSearch | Search logs, analyze patterns |
| 🥈 **FALLBACK** | Rails Console | Only to verify current DB state |
| 🥉 **LAST RESORT** | Docker logs | Only if MCP unavailable |

**⚡ Critical Rule: ClickHouse First, Console Last**

- **Events/Logs** → ClickHouse (30 seconds)
- **Patterns/Duplicates** → ClickHouse (instant)
- **Current DB state** → Rails Console (fallback only)
- **Code flow** → Read files (only after understanding the issue)

## Error Tracking Systems

| System | Project ID/Slug | Use Case |
|--------|-----------------|----------|
| **Honeybadger** | Project ID (numeric) | Primary Rails errors, detailed context |
| **Sentry** | `sentry/platform` | Sampled errors, mobile/frontend errors |

**When to use which:**
- **Honeybadger**: First choice for Rails backend errors
- **Sentry**: GraphQL errors (`sentry/graphql_pro`), Mobile (`sentry/pbp-mobile`), Frontend (`sentry/platform-frontend-0j`)

## Debugging Workflow (UPDATED 2026-02-11)

```
┌─────────────────────────────────────────────────────────────────┐
│  1. CLICKHOUSE FIRST: Query events/logs (30 sec, not 30 min)   │
│     - Find exact resource IDs (payment_id, user_id, etc)       │
│     - Detect patterns (duplicates, timing, race conditions)    │
│     - See full event context with millisecond precision        │
│             ↓                                                   │
│  2. ERROR TRACKING: Get context from Honeybadger/Sentry        │
│     - Stack traces, affected users, occurrence count           │
│     - Use ONLY if ClickHouse doesn't show the full picture     │
│             ↓                                                   │
│  3. RAILS CONSOLE: Verify current state (if needed)            │
│     - Check DB records, associations, current data             │
│     - Use ONLY to confirm hypotheses from ClickHouse           │
│             ↓                                                   │
│  4. CODE ANALYSIS: Find root cause in code                     │
│     - Search for where events are published                    │
│     - Identify race conditions, callbacks, jobs                │
│             ↓                                                   │
│  5. FIX: Implement fix with tests (TDD)                        │
│             ↓                                                   │
│  6. VERIFY: Confirm fix addresses the issue                    │
└─────────────────────────────────────────────────────────────────┘
```

### Fix Iteration Circuit Breaker

**After 3 failed fix attempts: STOP. Question the architecture, not attempt fix #4.**

**Pattern indicating an architectural problem (not a fixable bug):**
- Each fix reveals new shared state, coupling, or problem in a different place
- Fixes require "massive refactoring" to implement correctly
- Each fix creates new symptoms elsewhere

**When this happens, do NOT attempt fix #4. Instead:**

1. Re-read `investigations/<TICKET>/understanding.md` and any prior `findings.md` — the root cause diagnosis in those docs may be wrong, and the fixes have been treating symptoms.
2. Apply the no-suppositions rule: prove root cause with ≥2 independent sources (ClickHouse event data, Honeybadger fault context, a locally reproducible failing test) before forming the next hypothesis.
3. Explicitly ask: "Is this pattern fundamentally sound? Are we sticking with it through sheer inertia?"
4. Bring the question to your human partner before proceeding — "should we refactor the architecture vs. continue fixing symptoms?"

**PBP precedent (CORE-624):** The first hypothesis was `user_affiliations` (guessed, wrong). Fix #2 diagnosed "server-side cache" (guessed, also wrong). Fix #3 finally proved the real cause via ClickHouse: duplicate `users_facilities_faves` rows. Two failed fix attempts before correct root cause — exactly the failure this circuit breaker prevents. See `memory/feedback_no_suppositions_prove_with_evidence.md`.

**Red flags that you're past the circuit-breaker threshold:**
- "One more fix attempt" (when 2+ have already failed)
- Each fix reveals a new problem in a different place
- You're unsure which of your changes actually helped

**ALL of these mean: STOP. Return to Phase 1 (Root Cause Investigation).**

---

### Why ClickHouse First?

| Metric | ClickHouse | Rails Console | Honeybadger |
|--------|------------|---------------|-------------|
| **Time to Answer** | 30 seconds | 30 minutes | 2-5 minutes |
| **Precision** | Milliseconds | Seconds (truncated) | Varies |
| **Historical Data** | Years | Current state only | 90 days |
| **Resource IDs** | Exact IDs in logs | Manual queries | Limited |
| **Pattern Detection** | Instant (SQL) | Manual analysis | Grouped errors |

**Real Example (2026-02-11):**
- User: "Two payment_completed events 67ms apart, race condition?"
- ClickHouse query (30 sec): Shows `payment_id=39204765` appears twice ✅
- Rails Console (30 min): Found same payment_id after 10+ manual queries ❌
- **Lesson**: Start with ClickHouse, save 29 minutes

## Step 1: ClickHouse First (ALWAYS Start Here)

### Query Template: Investigate Events/Logs

**Use this template for ANY event-based debugging:**

```sql
-- Template: Find events by pattern and extract IDs
SELECT
  timestamp,
  message,
  -- Extract resource IDs from logs (adjust regex to match your log format)
  extractAllGroups(message, 'payment_id[=:](\d+)')[1] as payment_id,
  extractAllGroups(message, 'user[=:](\d+)')[1] as user_id,
  extractAllGroups(message, 'facility[=:](\d+)')[1] as facility_id,
  extractAllGroups(message, '\[JobName ([a-f0-9]+)\]')[1] as job_id
FROM logs
WHERE
  message LIKE '%EVENT_PATTERN%'
  AND timestamp BETWEEN 'START_TIME' AND 'END_TIME'
ORDER BY timestamp ASC
```

**Replace:**
- `EVENT_PATTERN` → Event type (e.g., `payment_completed`, `UnifiedEventService`)
- `START_TIME` / `END_TIME` → Timestamp range from error report
- Regex patterns → Match your actual log format

**What you get:**
- ✅ Exact resource IDs (payment_id, user_id, etc)
- ✅ Millisecond-precision timestamps
- ✅ Full event sequence with context
- ✅ Pattern detection (duplicates, timing issues)

---

### Query Template: Detect Duplicate Events (Race Conditions)

```sql
-- Detect resources processed multiple times (race condition detector)
WITH events AS (
  SELECT
    timestamp,
    extractAllGroups(message, 'payment_id[=:](\d+)')[1] as payment_id,
    extractAllGroups(message, 'user[=:](\d+)')[1] as user_id
  FROM logs
  WHERE
    message LIKE '%UnifiedEventService: Published payment_completed%'
    AND timestamp >= now() - INTERVAL 1 DAY
)
SELECT
  payment_id,
  count(*) as event_count,
  groupArray(user_id) as user_ids,
  groupArray(timestamp) as timestamps,
  arrayDifference(groupArray(toUnixTimestamp64Milli(timestamp))) as time_diffs_ms
FROM events
GROUP BY payment_id
HAVING event_count > 1  -- Only duplicates
ORDER BY event_count DESC
LIMIT 100
```

**Interpretation:**
- `event_count > 1` → Resource processed multiple times
- `time_diffs_ms` → Time between duplicate events (67ms = retry, 5000ms = scheduled)
- Different `user_ids` for same `payment_id` → Bug in logging (context contamination)

**Example Output:**
```
payment_id | event_count | user_ids           | time_diffs_ms
39204765   | 2           | [2345633, 1479567] | [67]         ← Race condition!
39210123   | 2           | [1234567, 1234567] | [120]        ← Legitimate retry
```

---

### Query Template: Timeline Analysis

```sql
-- When did the issue start? (hourly breakdown)
SELECT
  toStartOfHour(timestamp) as hour,
  count(*) as event_count,
  uniq(extractAllGroups(message, 'payment_id[=:](\d+)')[1]) as unique_payments
FROM logs
WHERE
  message LIKE '%payment_completed%'
  AND timestamp >= now() - INTERVAL 7 DAY
GROUP BY hour
ORDER BY hour DESC
```

**Use to identify:**
- When errors started (deployment correlation)
- Peak error times (load-related issues)
- If error is ongoing or resolved

---

### Query Template: Find Related Events

```sql
-- Find all events for a specific resource
SELECT
  timestamp,
  extractAllGroups(message, 'event_key[=:](\w+)')[1] as event_type,
  message
FROM logs
WHERE
  message LIKE '%payment_id=39204765%'
  AND timestamp >= now() - INTERVAL 7 DAY
ORDER BY timestamp ASC
```

**Shows:**
- Full event lifecycle (created → completed → webhook sent)
- Job executions for the resource
- Any errors or retries

---

### Example: Real Debugging Session (2026-02-11)

**Issue**: Two `payment_completed` events 67ms apart for facility 1067

**❌ Old approach (30 min):**
```ruby
# Rails console - Multiple manual queries
Payment.where(facility_id: 1067, user_id: [2345633, 1479567], ...)
# Found only 1 payment
# Searched for 2nd user's payment
# Checked reservation
# Checked MembershipPayments
# Finally concluded: race condition
```

**✅ New approach (30 sec):**
```sql
-- ClickHouse - One query
SELECT
  timestamp,
  extractAllGroups(message, 'payment_id[=:](\d+)')[1] as payment_id,
  extractAllGroups(message, 'user[=:](\d+)')[1] as user_id
FROM logs
WHERE
  message LIKE '%payment_completed%'
  AND message LIKE '%facility%1067%'
  AND timestamp BETWEEN '2026-02-11 14:41:00' AND '2026-02-11 14:42:00'
```

**Result:**
```
timestamp               | payment_id | user_id
2026-02-11 14:41:49.877 | 39204765   | 2345633
2026-02-11 14:41:49.944 | 39204765   | 1479567  ← Same payment_id!
```

**Immediate conclusion**: Race condition (same payment processed twice, bug in user_id logging)

---

## Step 2: Gather Error Context (Honeybadger + Sentry)

### List Recent Faults

```
mcp__honeybadger__list_faults:
  project_id: <project_id>
  order: recent
  limit: 25
```

### Get Fault Details

```
mcp__honeybadger__get_fault:
  project_id: <project_id>
  fault_id: <fault_id>
```

### Get Error Notices

```
mcp__honeybadger__list_fault_notices:
  project_id: <project_id>
  fault_id: <fault_id>
  limit: 10
```

### Key Information to Extract

| Field | Purpose |
|-------|---------|
| `message` | Error description |
| `backtrace` | Stack trace to find code location |
| `context` | User, facility, request params |
| `environment` | Rails env, server |
| `tags` | Custom tags for filtering |
| `created_at` | When it started happening |
| `notices_count` | How often it occurs |

### Sentry Error Context

**List Available Projects:**
```
mcp__sentry__sentry_list_projects
```

**Key Projects:**
| Project | Slug | Use Case |
|---------|------|----------|
| Platform (Rails) | `sentry/platform` | Backend errors |
| GraphQL Pro | `sentry/graphql_pro` | GraphQL errors |
| Mobile | `sentry/pbp-mobile` | React Native errors |
| Frontend | `sentry/platform-frontend-0j` | JavaScript errors |
| Sidekiq | `sentry/sidekiq-platform` | Background job errors |

**List Issues in Project:**
```
mcp__sentry__sentry_list_issues:
  org_slug: "sentry"
  project_slug: "platform"
  query: "is:unresolved"
  limit: 25
```

**Get Issue Details (with stacktrace):**
```
mcp__sentry__sentry_get_issue:
  issue_id: "<issue_id>"
```

**Get Recent Events for Issue:**
```
mcp__sentry__sentry_get_issue_events:
  issue_id: "<issue_id>"
  limit: 5
```

### Key Information from Sentry

| Field | Purpose |
|-------|---------|
| `title` | Error type and message |
| `culprit` | File/function where error occurred |
| `firstSeen` | When error first appeared |
| `lastSeen` | Most recent occurrence |
| `count` | Total occurrences |
| `userCount` | Number of affected users |
| `tags` | Environment, browser, device info |
| `stacktrace` | Full stack trace (from get_issue) |

## Step 2: Analyze with ClickHouse

### Find Affected Records

```sql
-- Find affected facilities
SELECT
  facility_id,
  count(*) as error_count
FROM pbp_productionDB_optimized.payments
WHERE status = 'failed'
  AND created_at > now() - INTERVAL 7 DAY
GROUP BY facility_id
ORDER BY error_count DESC;

-- Find pattern in failed operations
SELECT
  user_id,
  facility_id,
  created_at,
  error_message
FROM pbp_productionDB_optimized.<table>
WHERE <condition>
  AND created_at BETWEEN '<start>' AND '<end>'
ORDER BY created_at DESC
LIMIT 100;
```

### Check Data Integrity

```sql
-- Find orphaned records
SELECT count(*)
FROM pbp_productionDB_optimized.reservations r
LEFT JOIN pbp_productionDB_optimized.users u ON r.user_id = u.id
WHERE u.id IS NULL;

-- Find NULL values that shouldn't exist
SELECT *
FROM pbp_productionDB_optimized.<table>
WHERE <required_column> IS NULL
  AND created_at > now() - INTERVAL 30 DAY;

-- Check for duplicate records
SELECT
  <unique_columns>,
  count(*) as count
FROM pbp_productionDB_optimized.<table>
GROUP BY <unique_columns>
HAVING count > 1;
```

### Timeline Analysis

```sql
-- When did the issue start?
SELECT
  toStartOfHour(created_at) as hour,
  count(*) as count
FROM pbp_productionDB_optimized.<table>
WHERE <error_condition>
GROUP BY hour
ORDER BY hour;
```

## Step 3: Create Reproduction Script

```ruby
#!/usr/bin/env rails runner
# tmp/debug_issue.rb
#
# Purpose: Reproduce issue #XXX - [description]
# Usage: docker compose exec web bundle exec rails runner tmp/debug_issue.rb

# 1. Set up test data
facility = Facility.find(123)
user = facility.users.find(456)

# 2. Try to reproduce
begin
  # The operation that fails
  result = SomeService.new(facility: facility, user: user).call
  puts "SUCCESS: #{result.inspect}"
rescue => e
  puts "ERROR: #{e.class} - #{e.message}"
  puts e.backtrace.first(10).join("\n")
end

# 3. Clean up (if needed)
# Don't forget to clean up test data!
```

## Error Reporting with ErrorService

When implementing fixes, **ALWAYS use `ErrorService`** for error reporting:

```ruby
# Location: app/services/error_service.rb
ErrorService.new(exception, user: user, context: { ... }).notify
```

### Benefits
- Logs to `Rails.logger.error`
- Reports to Sentry with user context
- Reports to Honeybadger with sanitized context
- Automatic parameter filtering (passwords, secrets)

### Pattern: Real Exception

```ruby
rescue => e
  ErrorService.new(e, user: current_user, context: {
    facility_id: facility.id,
    operation: 'process_payment'
  }).notify
  raise
end
```

### Pattern: Error Condition Without Exception

```ruby
# When reporting an error state (not a caught exception)
if membership_payment.nil?
  ErrorService.new(
    StandardError.new("[ServiceName] Descriptive error message"),
    context: {
      membership_id: membership.id,
      current_state: membership.status
    }
  ).notify
  return
end
```

### ❌ AVOID: Separate Logger + Honeybadger

```ruby
# ❌ Old pattern - don't use
Rails.logger.error("Error occurred: #{error}")
Honeybadger.notify(error, context: { ... })

# ✅ Use ErrorService instead
ErrorService.new(error, context: { ... }).notify
```

## Step 4: Common Debugging Patterns

### Payment Issues

```ruby
# Find payment by trace ID
payment = Payment.find_by(trace_id: 'xxx')
payment.payment_transactions.order(:created_at)

# Check gateway response
payment.meta['gateway_response']

# Verify idempotency
PaymentTransaction.where(idempotency_key: 'xxx')
```

### Membership Issues

```ruby
# Check membership status
membership = Membership.find(123)
membership.slice(:status, :expires_at, :auto_renew, :cancelled_at)

# Check renewal history
membership.membership_transactions.renewal.order(:created_at)

# Find why renewal didn't happen
Membership.where(auto_renew: true)
          .where('expires_at < ?', Time.current)
          .where(status: 'active')
```

### Job Failures

```ruby
# Check Sidekiq queue
Sidekiq::Queue.new('default').size
Sidekiq::RetrySet.new.size

# Find failed jobs
Sidekiq::DeadSet.new.select { |job| job.klass == 'FailingJob' }

# Retry a specific job
Sidekiq::DeadSet.new.find { |j| j.jid == 'xxx' }&.retry
```

### N+1 / Slow Query

```ruby
# Enable query logging
ActiveRecord::Base.logger = Logger.new(STDOUT)

# Count queries
query_count = 0
ActiveSupport::Notifications.subscribe('sql.active_record') { query_count += 1 }

# Run the operation
result = SomeService.call

puts "Total queries: #{query_count}"
```

## Step 5: Log Analysis

### Rails Logs

```bash
# Search for specific error in logs
docker compose exec web tail -f log/development.log | grep -i "error\|exception"

# Filter by request ID
grep "request_id=abc123" log/production.log

# Find slow queries
grep "SLOW QUERY" log/production.log
```

### Sidekiq Logs

```bash
# Check job failures
docker compose exec web tail -f log/sidekiq.log | grep -i "fail\|error"

# Find specific job
grep "AutomaticRenewalMembershipJob" log/sidekiq.log
```

## Step 6: Debugging Checklist

For each issue:

- [ ] Error message and stack trace collected
- [ ] Affected records identified (facility, user, etc.)
- [ ] Timeline established (when it started)
- [ ] Pattern identified (always fails, intermittent, specific conditions)
- [ ] Reproduction script created
- [ ] Root cause identified
- [ ] Fix implemented with tests
- [ ] Fix verified in staging

## Report Format

```markdown
## Debug Report: [Issue Title]

### Error Summary
- **Honeybadger Fault**: #12345
- **Sentry Issue**: PLATFORM-789 (if applicable)
- **First Seen**: 2024-01-20 14:30 UTC
- **Occurrences**: 156
- **Affected Facilities**: Daisy Hill, Alex Hills

### Error Details
```
NoMethodError: undefined method `expires_at' for nil:NilClass
  app/services/membership_service.rb:45:in `renew'
  app/jobs/automatic_renewal_job.rb:23:in `perform'
```

### ClickHouse Analysis
```sql
-- Found 234 memberships with NULL membership_plan
SELECT count(*) FROM memberships WHERE membership_plan_id IS NULL;
```

### Root Cause
Memberships created via API without membership_plan validation.

### Reproduction
```ruby
membership = Membership.new(user: user, facility: facility)
membership.save(validate: false)  # This creates invalid record
membership.renew!  # Fails here
```

### Fix
1. Add validation for membership_plan_id
2. Backfill existing records
3. Add NOT NULL constraint after backfill

### Verification
- [ ] Test passes locally
- [ ] Deployed to staging
- [ ] Error rate decreased in Honeybadger
```

## Example

```
User reports: "Memberships not renewing"

## Debug Session

### Step 1: Honeybadger
mcp__honeybadger__list_faults: "membership renewal"

Found: Fault #8901 - "NoMethodError in AutomaticRenewalMembershipJob"
- 45 occurrences in last 24 hours
- Started: 2024-01-20 after deploy

### Step 2: ClickHouse Analysis

```sql
SELECT interval, count(*), countIf(auto_renew = 1) as should_renew
FROM pbp_productionDB_optimized.memberships
WHERE status = 'active' AND expires_at < now()
GROUP BY interval;
```

Result:
| interval | count | should_renew |
|----------|-------|--------------|
| weekly   | 234   | 234          |
| monthly  | 45    | 45           |

234 weekly memberships should have renewed but didn't!

### Step 3: Code Analysis

```ruby
# AutomaticRenewalMembershipJob line 15
scope = Membership.renewable
                  .where(interval: ['monthly', 'annual'])
```

BUG FOUND: 'weekly' is not in the interval list!

### Step 4: Fix

```ruby
scope = Membership.renewable
                  .where(interval: ['weekly', 'monthly', 'annual'])
```

### Step 5: Verification
- Added test for weekly renewals
- Deployed fix
- Manually triggered renewal for affected memberships
- Honeybadger shows 0 new occurrences

### Resolution: FIXED
```

---

## MCP Integrations

### GitHub MCP

Use for finding related issues and PRs:

```
# Search for similar issues
mcp__github__search_issues:
  q: "repo:playbypoint/platform is:issue label:bug membership renewal"

# Check if issue exists for this error
mcp__github__search_issues:
  q: "repo:playbypoint/platform is:issue NoMethodError membership"

# Get issue timeline for context
mcp__github__list_issue_events:
  owner: "playbypoint"
  repo: "platform"
  issue_number: 456

# Create issue for discovered bug
mcp__github__create_issue:
  owner: "playbypoint"
  repo: "platform"
  title: "[BUG] Weekly memberships not renewing"
  body: "## Description\n..."
  labels: ["bug", "memberships"]
```

### OpenSearch MCP

Use for debugging search issues:

```
# Check index health
mcp__opensearch__cluster_health

# Debug search queries
mcp__opensearch__search:
  index: "users"
  explain: true
  query: { "match": { "email": "test@example.com" } }
```

### Rails MCP

Use for interactive debugging:

```
# Query data in console
mcp__rails__console:
  command: "Membership.weekly.renewable.count"

# Check model associations
mcp__rails__console:
  command: "Membership.reflect_on_all_associations.map { |a| [a.name, a.macro] }"
```

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new debugging pattern
- A useful ClickHouse query
- A better Honeybadger workflow

**You MUST**:
1. Complete the current debugging session first
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements**:

<!-- Kaizen: 2026-01-24 - Jupyter Notebook Integration -->
## 📓 Jupyter Notebook Integration (Optional)

Use JupyterLab for **interactive debugging sessions** when you need to:
- Explore data patterns iteratively
- Document your debugging process with markdown
- Keep a persistent record of queries and findings

### Launch Jupyter for Debugging

```bash
~/jupyter-env/bin/jupyter lab
```

### Example Notebook for Debugging

```python
# Cell 1: Setup
%load_ext sql
%sql clickhouse://default:@localhost:8123/pbp_productionDB_optimized

# Cell 2: Find error patterns
%%sql
SELECT
  toStartOfHour(created_at) as hour,
  count(*) as error_count
FROM payments
WHERE status = 'failed'
  AND created_at > now() - INTERVAL 7 DAY
GROUP BY hour
ORDER BY hour

# Cell 3: Visualize trends
import pandas as pd
import matplotlib.pyplot as plt

df = _  # Last query result
df.plot(x='hour', y='error_count', kind='line')
plt.title('Failed Payments Over Time')
```

### When to Use Jupyter vs CLI

| Scenario | Tool |
|----------|------|
| Quick error lookup | CLI (mcp__clickhouse) |
| Iterative data exploration | Jupyter |
| Documenting a debug session | Jupyter |
| Simple fault check | Honeybadger MCP |
| Complex pattern analysis | Jupyter |

### MCP IDE Tools Available

- `mcp__ide__executeCode`: Execute Python in active Jupyter kernel
- `mcp__ide__getDiagnostics`: Get language diagnostics from VS Code

<!-- Kaizen: 2026-01-31 - MCP Tools Integration -->
## Kaizen Entry: MCP Tools as Primary Method

**What Changed:**
- Added reference to shared MCP tools guide at top of skill
- Updated documentation to position MCP tools as PRIMARY method for debugging
- Added priority table showing MCP tools (Honeybadger, ClickHouse, Sentry, OpenSearch) as 🥇 PRIMARY
- Positioned Docker logs as 🥈 FALLBACK only

**Why:**
- Previous version didn't emphasize MCP tools strongly enough
- Developers were falling back to Docker unnecessarily
- MCP tools provide better production data access (10.4M users, 1.8K facilities)
- Prevents repeating root cause: overlooking available tooling

**Impact:**
- Faster debugging (direct production data access)
- Better error context (Honeybadger + Sentry integration)
- Consistent patterns across all skills
- ROI: 3.0 (High impact, Low effort)

<!-- Kaizen: 2026-01-23 - Production Script Rules -->
## ⚠️ CRITICAL: Production Script Rules

When creating scripts for production Rails console, **ALWAYS** follow these rules:

### 1. Ruby 3 Syntax Compatibility

```ruby
# ❌ WRONG - Deprecated in Ruby 3
date.to_s(:db)
time.to_s(:db)

# ✅ CORRECT - Use strftime
date.strftime('%Y-%m-%d')
time.strftime('%Y-%m-%d %H:%M:%S')
```

### 2. Handle nil Values BEFORE Calling Methods

```ruby
# ❌ WRONG - Will crash if nil
starts = membership.acquired_at.strftime('%Y-%m-%d %H:%M:%S')

# ✅ CORRECT - Handle nil first
starts = membership.acquired_at ? membership.acquired_at.strftime('%Y-%m-%d %H:%M:%S') : Time.current.strftime('%Y-%m-%d %H:%M:%S')
```

### 3. Test Scripts in Docker BEFORE Sending to Production

```bash
# ALWAYS test locally first
docker compose exec web bundle exec rails runner "
  # Your script here
  puts 'Test output'
"
```

### 4. NEVER Use Heredocs in Rails Console

```ruby
# ❌ WRONG - Heredocs don't paste well in console
ActiveRecord::Base.connection.execute(<<-SQL)
  SELECT * FROM users
SQL

# ✅ CORRECT - Single line or concatenated strings
ActiveRecord::Base.connection.execute("SELECT * FROM users WHERE id = #{id}")
```

### 5. Skip Model Callbacks for Manual Data Fixes

```ruby
# ❌ WRONG - Triggers callbacks that may fail
MembershipPayment.create!(payment_id: 123, ...)

# ✅ CORRECT - Direct SQL for manual fixes
ActiveRecord::Base.connection.execute("INSERT INTO membership_payments (...) VALUES (...)")

# ✅ ALSO CORRECT - update_column skips callbacks
payment.update_column(:paid, true)
```

### 6. Provide Step-by-Step Commands

When giving commands for production, provide them **one at a time** so the user can:
- Copy/paste easily
- See the result of each step
- Abort if something goes wrong

<!-- Kaizen: 2026-02-11 - ClickHouse First Methodology -->
## Kaizen Entry: ClickHouse First, Console Last

**What Changed:**
- Reordered debugging workflow to put ClickHouse as PHASE 1 (was PHASE 2)
- Added priority ranking: ClickHouse 🥇 > Honeybadger 🥇 > Rails Console 🥈 > Docker logs 🥉
- Added comprehensive ClickHouse query templates section
- Added real debugging example showing 30 sec vs 30 min difference
- Created query templates for: events investigation, duplicate detection, timeline analysis, related events

**Why:**
- Real debugging session (2026-02-11) showed massive time savings:
  - ClickHouse query: 30 seconds → Found `payment_id=39204765` duplicated
  - Rails Console: 30 minutes → 10+ manual queries to reach same conclusion
- ClickHouse provides:
  - Exact resource IDs from logs (payment_id, user_id, job_id)
  - Millisecond precision timestamps (MySQL truncates to seconds)
  - Historical data (years) vs current state only (Rails console)
  - Instant pattern detection (duplicates, race conditions)
  - No manual queries required
- Rails Console is slow, requires multiple queries, and only shows current DB state
- Previous workflow buried ClickHouse power under "optional" Step 2

**Impact:**
- **Time savings: 29 minutes per debugging session** (96% reduction)
- Immediate duplicate/race condition detection (was manual analysis)
- Better resource ID extraction (regex from logs vs manual DB queries)
- Reduces cognitive load (one ClickHouse query vs 10+ Rails queries)
- Prevents going down wrong paths (see data BEFORE hypothesizing)

**ROI: 5.0 (CRITICAL)**
- **Effort**: Medium (documentation update, workflow reorder)
- **Value**: CRITICAL (saves hours per debugging session, prevents wrong conclusions)
- **Applicability**: Every event-based debugging session
- **Knowledge Transfer**: High (templates are reusable, teach ClickHouse patterns)

**Lessons Learned:**
1. **Always start with the data source that has the most context** (logs > DB state)
2. **Precision matters** - 67ms difference only visible in ClickHouse (MySQL truncates)
3. **Pattern detection is instant in SQL** - Detecting duplicates manually takes 10+ queries
4. **Resource IDs in logs are gold** - Extract payment_id from logs, not from DB queries
5. **"Query first, hypothesize second"** - See what actually happened before guessing

**Real Example:**
- **Issue**: Two payment_completed events 67ms apart, user suspects race condition
- **ClickHouse (30s)**: Shows `payment_id=39204765` published twice with different user_ids
- **Immediate diagnosis**: Race condition confirmed, bug in user_id logging
- **Rails Console (30m)**: Would need: Payment.where(...), check users, check reservation, check MembershipPayments, analyze timestamps manually
- **Conclusion**: ClickHouse saved 29 minutes and provided definitive answer instantly

**Query Template Added:**
```sql
-- Detect duplicate events (race conditions)
SELECT
  payment_id,
  count(*) as event_count,
  groupArray(user_id) as user_ids,
  arrayDifference(groupArray(toUnixTimestamp64Milli(timestamp))) as time_diffs_ms
FROM (
  SELECT timestamp,
    extractAllGroups(message, 'payment_id[=:](\d+)')[1] as payment_id,
    extractAllGroups(message, 'user[=:](\d+)')[1] as user_id
  FROM logs
  WHERE message LIKE '%payment_completed%'
)
GROUP BY payment_id
HAVING event_count > 1
```

**New Debugging Philosophy:**
> "ClickHouse First, Console Last"
> - Events/Logs → ClickHouse (30 seconds)
> - Current DB state → Rails Console (fallback only)
> - Code flow → Read files (only after understanding the issue)

**Applicability:**
- Event debugging (payment_completed, webhooks, jobs)
- Duplicate detection (race conditions, retries)
- Timeline analysis (when did it start?)
- Performance debugging (slow queries, N+1)
- Any debugging where logs contain resource IDs

**Future Improvements:**
- [ ] Add more query templates for common debugging patterns
- [ ] Create ClickHouse cheat sheet for regex patterns
- [ ] Add templates for webhook debugging
- [ ] Add templates for job retry analysis
- [ ] Document log format patterns for easier regex writing

<!-- Kaizen: 2026-05-12 - User correction -->
## Kaizen Entry: Reproduce HTTP-Facing Bugs via Real Request, Not Runner Stubs
- Rule: For bugs in HTTP-facing code (GraphQL, controllers, middlewares, endpoint-triggered jobs), the local reproduction step should hit the real endpoint (Postman/curl/`graphql_post` spec) BEFORE writing a `rails runner` script that monkey-patches internals.
- Why: Runner + monkey-patch bypasses request middleware, auth, and per-request shared context (e.g. graphql-ruby's resolver execution order, which surfaces aliased-query bugs only at request level). Stubs can confirm a hypothesis but fail to convince reviewers and can mask the real failure mode.
- How to apply: After narrowing the bug via Honeybadger/ClickHouse, default to real request reproduction. Runner is appropriate (a) as a fast sanity check, (b) for purely internal services with no HTTP entry, or (c) for fast iteration during fix development after the real-request repro is on file.
- Source: User correction on 2026-05-12 during ENG-544 adversarial review. See `memory/feedback_validate_bugs_via_real_request.md`.

<!-- Kaizen: 2026-05-12 - User correction (scope + repro discipline) -->
## Kaizen Entry: Bug Reports Must Be In-Scope AND Have Real Repro
- Rule: When debugging a reported bug or hypothesizing a fix, the bug must (1) be reproducible against the current branch (not a pre-existing condition unrelated to the work in flight), and (2) have a real repro path — Honeybadger fault id, ClickHouse query, Rails console snippet, or HTTP request — NOT a thought experiment that only manifests under hand-injected raises or stubs.
- Why: Time spent debugging pre-existing or theoretical bugs is time stolen from real ones. Stakeholders also lose trust when "bugs" turn out to be unreachable or out-of-scope.
- How to apply: Before opening a debug investigation, check `git log -- <files>` and `git diff develop...HEAD` to confirm the bug is in scope. Then anchor every hypothesis to a concrete repro (fault id with notice count, query result, request that returns the bad response). Reject hypotheses that require monkey-patching to manifest.
- Source: User correction on 2026-05-12 during ENG-544 adversarial review. See `memory/feedback_review_scope_and_real_repro.md`.

<!-- Kaizen: 2026-05-12 - User correction (refinement: prod-state verification) -->
## Kaizen Entry: Verify Bug State Exists In Prod Before Hypothesizing
- When investigating a bug or proposing a debugging hypothesis, verify the precondition exists in prod data BEFORE fabricating it locally with `update_columns` / `destroy_all` / etc. Use `mcp__clickhouse__run_query` to count rows matching the condition; check Honeybadger for recurring faults at the same code path. If the condition has 0 occurrences in prod, the bug is theoretical — debugging time is better spent elsewhere.
- Final filter when triaging: "Does a real user, with real data, in a real client flow, observe this behavior?" — if no, drop the hypothesis.
- Why: Without this check, debugging investigations chase ghosts and burn time on bugs no user will ever hit. Time spent on theoretical bugs is time stolen from real ones.
- Source: User correction on 2026-05-12 during ENG-544 adversarial review. See `memory/feedback_review_scope_and_real_repro.md` (updated 2026-05-12).

<!-- Kaizen: 2026-06-10 — Fix iteration circuit breaker (obra/superpowers MIT, commit 6fd4507) -->
- Added: "Fix Iteration Circuit Breaker" section placed immediately before "Why ClickHouse First?" — within the main debugging workflow, before the tool-routing deep-dives. Source: superpowers `skills/systematic-debugging/SKILL.md` lines 192-213 (Phase 4, steps 4-5: after 3 failed fix attempts STOP and question the architecture/diagnosis). PBP adaptation: (1) "re-read `investigations/<TICKET>/`" replaces the generic "question fundamentals" directive; (2) no-suppositions rule (≥2 independent sources) is woven in as the proof standard; (3) CORE-624 cited as the concrete precedent (guessed user_affiliations, then "server-side cache", both wrong — exactly this failure). Human-partner signal detection (source lines 234-243) and debug rationalization table (lines 245-256) omitted: the PBP debug skill's Phase 1 and "prove root cause" rules already cover that surface; lean graft only.
- Source: `/tmp/superpowers-20260610/skills/systematic-debugging/SKILL.md` (MIT license)

<!-- Kaizen: 2026-06-05 - User direction (confirm-loop + multi-source perspectives) -->
- Rule: Confirm findings/hypotheses by routing to the right perspective, then loop until clean (capped). code/logic → reproduce LOCALLY with a failing test (not runner+stub); API/library behavior → Context7; "does it happen in prod / at what scale" → ClickHouse (MUST use `FINAL` on ReplacingMergeTree tables; mind that CH is a lagging replica) or Honeybadger. Use MCP as MANUAL corroboration, never an automated oracle; require ≥2 independent sources before treating a claim as confirmed. Document each CONFIRMED case in `investigations/<ticket>/findings.md` (gitignored) so the thread survives loop iterations and compaction. Don't act on unconfirmed/out-of-scope findings.
- Why: gives the best panorama without waiting for manual checks, while ClickHouse staleness/version-dup and false positives (which burned us before) are guarded.
- Source: User direction on 2026-06-05. See `memory/feedback_confirm_loop_adversarial_findings.md`.
