---
name: debug
description: Production debugging using Honeybadger, Sentry, ClickHouse, logs, and Rails console. Systematic approach to diagnose and fix production issues.
allowed-tools: [Bash, Read, Grep, Glob, Edit, mcp__github__*, mcp__clickhouse__run_query, mcp__clickhouse__list_tables, mcp__honeybadger__list_faults, mcp__honeybadger__get_fault, mcp__honeybadger__list_fault_notices, mcp__sentry__find_projects, mcp__sentry__search_issues, mcp__sentry__search_issue_events, mcp__sentry__get_sentry_resource, mcp__opensearch__*, mcp__rails__execute_ruby]
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
mcp__sentry__find_projects
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
mcp__sentry__search_issues:
  org_slug: "sentry"
  project_slug: "platform"
  query: "is:unresolved"
  limit: 25
```

**Get Issue Details (with stacktrace):**
```
mcp__sentry__get_sentry_resource:
  issue_id: "<issue_id>"
```

**Get Recent Events for Issue:**
```
mcp__sentry__search_issue_events:
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

## Step 3: Analyze with ClickHouse

### Find Affected Records

```sql
-- Find affected facilities
SELECT
  facility_id,
  count(*) as error_count
FROM pbp_productionDB_optimized.payments FINAL
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
FROM pbp_productionDB_optimized.<table> FINAL
WHERE <condition>
  AND created_at BETWEEN '<start>' AND '<end>'
ORDER BY created_at DESC
LIMIT 100;
```

### Check Data Integrity

```sql
-- Find orphaned records
SELECT count(*)
FROM pbp_productionDB_optimized.reservations FINAL r
LEFT JOIN pbp_productionDB_optimized.users FINAL u ON r.user_id = u.id
WHERE u.id IS NULL;

-- Find NULL values that shouldn't exist
SELECT *
FROM pbp_productionDB_optimized.<table> FINAL
WHERE <required_column> IS NULL
  AND created_at > now() - INTERVAL 30 DAY;

-- Check for duplicate records
SELECT
  <unique_columns>,
  count(*) as count
FROM pbp_productionDB_optimized.<table> FINAL
GROUP BY <unique_columns>
HAVING count > 1;
```

### Timeline Analysis

```sql
-- When did the issue start?
SELECT
  toStartOfHour(created_at) as hour,
  count(*) as count
FROM pbp_productionDB_optimized.<table> FINAL
WHERE <error_condition>
GROUP BY hour
ORDER BY hour;
```

## Step 4: Create Reproduction Script

```ruby
#!/usr/bin/env rails runner
# tmp/debug_issue.rb
#
# Purpose: Reproduce issue #XXX - [description]
# Usage: bin/d rails runner tmp/debug_issue.rb

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

## Step 5: Common Debugging Patterns

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

## Step 6: Log Analysis

### Rails Logs

```bash
# Search for specific error in logs
bin/d sh -c 'tail -f log/development.log | grep -i "error\|exception"'

# Filter by request ID
grep "request_id=abc123" log/production.log

# Find slow queries
grep "SLOW QUERY" log/production.log
```

### Sidekiq Logs

```bash
# Check job failures
bin/d sh -c 'tail -f log/sidekiq.log | grep -i "fail\|error"'

# Find specific job
grep "AutomaticRenewalMembershipJob" log/sidekiq.log
```

## Step 7: Debugging Checklist

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
SELECT count(*) FROM pbp_productionDB_optimized.memberships FINAL WHERE membership_plan_id IS NULL;
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
FROM pbp_productionDB_optimized.memberships FINAL
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
  q: "repo:PlaybyCourt/platform is:issue label:bug membership renewal"

# Check if issue exists for this error
mcp__github__search_issues:
  q: "repo:PlaybyCourt/platform is:issue NoMethodError membership"

# Get issue timeline for context (mcp__github__list_issue_events not available; use gh CLI instead)
# gh issue view 456 --repo PlaybyCourt/platform --comments

# Create issue for discovered bug
mcp__github__create_issue:
  owner: "PlaybyCourt"
  repo: "platform"
  title: "[BUG] Weekly memberships not renewing"
  body: "## Description\n..."
  labels: ["bug", "memberships"]
```

### OpenSearch MCP

Use for debugging search issues:

```
# Check index health
mcp__opensearch__ClusterHealthTool

# Debug search queries
mcp__opensearch__SearchIndexTool:
  index: "users"
  explain: true
  query: { "match": { "email": "test@example.com" } }
```

### Rails MCP

Use for interactive debugging:

```
# Query data in console
mcp__rails__execute_ruby:
  code: "Membership.weekly.renewable.count"

# Check model associations
mcp__rails__execute_ruby:
  code: "Membership.reflect_on_all_associations.map { |a| [a.name, a.macro] }"
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

<!-- Kaizen: 2026-01-24 - Jupyter Notebook Integration — archived to kaizen_log.md. Local-only; ~/jupyter-env/bin/jupyter lab; mcp__ide tools NOT available. -->
<!-- Kaizen: 2026-01-31 - MCP Tools Integration — Promoted to PRIMARY METHOD table. ROI: 3.0. Content in body. -->
<!-- Kaizen: 2026-01-23 - Production Script Rules — archived to kaizen_log.md. Key rules: strftime not to_s(:db); nil-check before strftime; bin/d rails runner for local test; no heredocs in console; update_column to skip callbacks. -->
<!-- Kaizen: 2026-02-11 - ClickHouse First Methodology — Promoted to body (Step 1, workflow diagram, priority table, query templates, real example). ROI: 5.0. -->
- Real incident: payment_id=39204765 duplicate events 67ms apart — ClickHouse 30s vs Rails console 30min. Full content in Step 1 body.

<!-- Kaizen: 2026-05-12 - User corrections (ENG-544) — rules promoted to Step 4 (repro script) and circuit-breaker section. -->
- Real-request repro before runner stubs; bug must be in-scope (git diff); prod state must exist before fabricating. Sources: `memory/feedback_validate_bugs_via_real_request.md`, `memory/feedback_review_scope_and_real_repro.md`.

<!-- Kaizen: 2026-06-10 — Step renumber + stale tool + Kaizen dedup (Fable re-audit hygiene pass) -->
- Fixed: duplicate "Step 2" (Gather Error Context vs Analyze with ClickHouse). Renumbered: Step 2=Gather Error, Step 3=Analyze w/ ClickHouse, Step 4=Repro Script, Step 5=Common Patterns, Step 6=Log Analysis, Step 7=Checklist.
- Replaced: nonexistent `mcp__github__list_issue_events` with `gh issue view` CLI fallback note.
- Removed: `mcp__ide__executeCode` and `mcp__ide__getDiagnostics` from frontmatter; caveated Jupyter section.
- Compressed Kaizen entries: 2026-01-31 (MCP priority table — in body), 2026-02-11 ClickHouse ROI essay (full content in Step 1 body — incident detail preserved), three 2026-05-12 (ENG-544 rules — in Steps 4/circuit-breaker).

<!-- Kaizen: 2026-06-10 — MCP tool-name + org sweep (Fable audit Tier 2') -->
- Updated stale MCP tool names to the current environment (ClickHouse run_select_query → run_query; Sentry sentry_list_projects → find_projects, sentry_list_issues → search_issues, sentry_get_issue → get_sentry_resource, sentry_get_issue_events → search_issue_events; Rails console → execute_ruby; OpenSearch cluster_health → ClusterHealthTool, search → SearchIndexTool).
- Fixed GitHub org: playbypoint → PlaybyCourt (search_issues q strings and list_issue_events/create_issue owners).

<!-- Kaizen: 2026-06-10 — Fix iteration circuit breaker (obra/superpowers MIT, commit 6fd4507) -->
- Added: "Fix Iteration Circuit Breaker" section placed immediately before "Why ClickHouse First?" — within the main debugging workflow, before the tool-routing deep-dives. Source: superpowers `skills/systematic-debugging/SKILL.md` lines 192-213 (Phase 4, steps 4-5: after 3 failed fix attempts STOP and question the architecture/diagnosis). PBP adaptation: (1) "re-read `investigations/<TICKET>/`" replaces the generic "question fundamentals" directive; (2) no-suppositions rule (≥2 independent sources) is woven in as the proof standard; (3) CORE-624 cited as the concrete precedent (guessed user_affiliations, then "server-side cache", both wrong — exactly this failure). Human-partner signal detection (source lines 234-243) and debug rationalization table (lines 245-256) omitted: the PBP debug skill's Phase 1 and "prove root cause" rules already cover that surface; lean graft only.
- Source: `/tmp/superpowers-20260610/skills/systematic-debugging/SKILL.md` (MIT license)

<!-- Kaizen: 2026-06-05 - User direction (confirm-loop + multi-source perspectives) -->
- Rule: Confirm findings/hypotheses by routing to the right perspective, then loop until clean (capped). code/logic → reproduce LOCALLY with a failing test (not runner+stub); API/library behavior → Context7; "does it happen in prod / at what scale" → ClickHouse (MUST use `FINAL` on ReplacingMergeTree tables; mind that CH is a lagging replica) or Honeybadger. Use MCP as MANUAL corroboration, never an automated oracle; require ≥2 independent sources before treating a claim as confirmed. Document each CONFIRMED case in `investigations/<ticket>/findings.md` (gitignored) so the thread survives loop iterations and compaction. Don't act on unconfirmed/out-of-scope findings.
- Why: gives the best panorama without waiting for manual checks, while ClickHouse staleness/version-dup and false positives (which burned us before) are guarded.
- Source: User direction on 2026-06-05. See `memory/feedback_confirm_loop_adversarial_findings.md`.
