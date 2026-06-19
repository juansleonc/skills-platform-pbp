---
name: debug
description: Production debugging using Honeybadger, Sentry, ClickHouse, logs, and Rails console. Systematic approach to diagnose and fix production issues.
allowed-tools: [Bash, Read, Grep, Glob, Edit, mcp__github__*, mcp__clickhouse__run_query, mcp__clickhouse__list_tables, mcp__honeybadger__list_faults, mcp__honeybadger__get_fault, mcp__honeybadger__list_fault_notices, mcp__sentry__find_projects, mcp__sentry__search_issues, mcp__sentry__search_issue_events, mcp__sentry__get_sentry_resource, mcp__opensearch__*, mcp__rails__execute_ruby]
disable-model-invocation: false
---

## PRIMARY METHOD: Use MCP Tools

**ALWAYS use MCP tools FIRST.** Route by question, fall back only when the primary is unavailable.

| Priority | Tool | When to use | Fallback |
|----------|------|-------------|----------|
| 🥇 PRIMARY | MCP ClickHouse | **START HERE** — events, logs, patterns, duplicates, "did it happen in prod / at what scale" | OpenSearch / Docker logs |
| 🥇 PRIMARY | MCP Honeybadger | Rails backend error context, stack traces, affected users | Sentry |
| 🥇 PRIMARY | MCP Sentry | GraphQL, mobile, frontend errors | Honeybadger |
| 🥈 FALLBACK | Rails Console | Verify CURRENT DB state only — to confirm a ClickHouse hypothesis | — |
| 🥉 LAST RESORT | Docker logs | Only if MCP unavailable | — |

**⚡ Rule: ClickHouse First, Console Last.** Events/logs/patterns/duplicates → ClickHouse (seconds).
Current DB state → Rails console (fallback). Code flow → Read files (only after you understand the issue).

## Error Tracking Systems

| System | ID/Slug | Use case |
|--------|---------|----------|
| **Honeybadger** | Project ID (numeric) | First choice — Rails backend errors, detailed context |
| **Sentry** | `sentry/platform` | Sampled errors. GraphQL (`sentry/graphql_pro`), Mobile (`sentry/pbp-mobile`), Frontend (`sentry/platform-frontend-0j`) |

Detailed MCP calls + field tables → `reference/error-tracking.md`.

## Debugging Workflow

```
1. CLICKHOUSE FIRST — query events/logs (30 sec, not 30 min)
   - Find exact resource IDs (payment_id, user_id, etc)
   - Detect patterns (duplicates, timing, race conditions)
        ↓
2. ERROR TRACKING — context from Honeybadger/Sentry
   - Stack traces, affected users, occurrence count
   - ONLY if ClickHouse doesn't show the full picture
        ↓
3. RAILS CONSOLE — verify current state (if needed)
   - ONLY to confirm a hypothesis from ClickHouse
        ↓
4. CODE ANALYSIS — find root cause in code
   - Where events are published; race conditions, callbacks, jobs
        ↓
5. FIX — implement with tests (TDD)
        ↓
6. VERIFY — confirm fix addresses the issue
```

### Fix Iteration Circuit Breaker

**After 3 failed fix attempts: STOP. Question the architecture, not attempt fix #4.**

Signs of an architectural problem (not a fixable bug): each fix reveals new shared state/coupling
elsewhere; fixes require "massive refactoring"; each fix creates new symptoms.

When this happens, do NOT attempt fix #4. Instead:

1. Re-read `investigations/<TICKET>/understanding.md` and prior `findings.md` — the root-cause diagnosis may be wrong and the fixes have been treating symptoms.
2. Apply the no-suppositions rule: prove root cause with ≥2 independent sources (ClickHouse event data, Honeybadger fault context, a locally reproducible failing test) before the next hypothesis.
3. Ask explicitly: "Is this pattern fundamentally sound, or are we sticking with it through inertia?"
4. Bring "refactor the architecture vs. continue fixing symptoms?" to your human partner before proceeding.

**PBP precedent (CORE-624):** two wrong guesses (`user_affiliations`, then "server-side cache") before ClickHouse proved the real cause (duplicate `users_facilities_faves` rows) — exactly the failure this breaker prevents. See `memory/feedback_no_suppositions_prove_with_evidence.md`.

**Red flags you're past threshold:** "one more fix attempt" (when 2+ failed); each fix reveals a new problem elsewhere; you're unsure which change actually helped. **All mean: STOP, return to root-cause investigation.**

---

### Why ClickHouse First?

| Metric | ClickHouse | Rails Console | Honeybadger |
|--------|------------|---------------|-------------|
| Time to answer | 30 seconds | 30 minutes | 2-5 minutes |
| Precision | Milliseconds | Seconds (truncated) | Varies |
| Historical data | Years | Current state only | 90 days |
| Resource IDs | Exact IDs in logs | Manual queries | Limited |
| Pattern detection | Instant (SQL) | Manual analysis | Grouped errors |

> Footnote: real incident (payment_id=39204765, two events 67ms apart) took ClickHouse 30s vs Rails console 30min over 10+ queries to reach the same answer.

## Step 1: ClickHouse First (ALWAYS Start Here)

Query templates (logs-table event streams, duplicate/race detector, related-events, DB-table
integrity checks, timeline analysis, and the worked example) → `reference/clickhouse-queries.md`.

Decision: use a **logs-table** query for event streams; use a **`pbp_productionDB_optimized.*` table
query (FINAL required)** for state/record data. ReplacingMergeTree tables inflate plain `count()` ~20x.

## Step 2: Gather Error Context (Honeybadger + Sentry)

Honeybadger first for Rails backend; Sentry for GraphQL/mobile/frontend. Use ONLY if ClickHouse
doesn't show the full picture. MCP call shapes + field tables → `reference/error-tracking.md`.

## Step 3: Analyze with ClickHouse

Find affected records, check data integrity (orphans, unexpected NULLs, duplicates), and timeline
analysis — all in `reference/clickhouse-queries.md` (sections B and C). FINAL is required on DB tables.

## Step 4: Create Reproduction Script

Repro skeleton (`tmp/debug_issue.rb`, run with `bin/d rails runner`) is in Step 5 below.
Repro rules (ENG-544): drive with a real request before runner+stubs; confirm the bug is in-scope
(`git diff`); confirm prod state exists before fabricating it.

## Error Reporting with ErrorService

ALWAYS report errors via `ErrorService` (`app/services/error_service.rb`) — never raw
`Rails.logger.error` + `Honeybadger.notify`. It logs, reports to Sentry + Honeybadger with sanitized
context, and filters secrets. Patterns (real exception, error-condition-without-exception) and the
anti-pattern → `reference/error-service.md`.

## Step 5: Common Debugging Patterns

Quick-reference console snippets (run in Docker: `bin/d rails c` / `bin/d rails runner`).

### Payment Issues

```ruby
# Note: payment_trace_id lives in logs/ClickHouse (X-Payment-Trace-Id header / Current.payment_trace_id),
# NOT a DB column. Use transaction_id or id to look up in the DB.
payment = Payment.find_by(transaction_id: 'xxx')   # or Payment.find(id)
payment.status                                     # payment status (column)
payment.gateway                                    # gateway used (column)
payment.meta['gateway_response']                   # gateway response (meta mediumtext)
payment.meta_json                                  # structured gateway data (JSON column)
```

### Membership Issues

```ruby
membership = Membership.find(123)
membership.slice(:aasm_state, :current_period_end_at, :paused_at, :termination_date, :renewal_payment_method)
membership.membership_payments.order(:created_at)  # renewal/payment history (MembershipPayment model)
# Why didn't renewal happen? (adjust aasm_state set to investigate as needed — confirm with team)
Membership.where.not(aasm_state: 'cancelled')
           .where('current_period_end_at < ?', Time.current)
```

### Job Failures

```ruby
Sidekiq::Queue.new('default').size
Sidekiq::RetrySet.new.size
Sidekiq::DeadSet.new.select { |job| job.klass == 'FailingJob' }
Sidekiq::DeadSet.new.find { |j| j.jid == 'xxx' }&.retry
```

### N+1 / Slow Query

```ruby
query_count = 0
ActiveSupport::Notifications.subscribe('sql.active_record') { query_count += 1 }
result = SomeService.call
puts "Total queries: #{query_count}"
```

### Reproduction Script Skeleton

```ruby
#!/usr/bin/env rails runner
# tmp/debug_issue.rb — Reproduce issue #XXX. Usage: bin/d rails runner tmp/debug_issue.rb
facility = Facility.find(123)
user = facility.users.find(456)
begin
  result = SomeService.new(facility: facility, user: user).call
  puts "SUCCESS: #{result.inspect}"
rescue => e
  puts "ERROR: #{e.class} - #{e.message}"
  puts e.backtrace.first(10).join("\n")
end
# Clean up test data if needed.
```

## Step 6: Log Analysis

### Rails Logs

```bash
bin/d sh -c 'tail -f log/development.log | grep -i "error\|exception"'
grep "request_id=abc123" log/production.log   # filter by request ID
grep "SLOW QUERY" log/production.log          # slow queries
```

### Sidekiq Logs

```bash
bin/d sh -c 'tail -f log/sidekiq.log | grep -i "fail\|error"'
grep "AutomaticRenewalMembershipJob" log/sidekiq.log
```

## Step 7: Debugging Checklist

- [ ] Error message and stack trace collected
- [ ] Affected records identified (facility, user, etc.)
- [ ] Timeline established (when it started)
- [ ] Pattern identified (always fails, intermittent, specific conditions)
- [ ] Reproduction script created
- [ ] Root cause identified
- [ ] Fix implemented with tests
- [ ] Fix verified in staging

## Report Format

Debug report layout + a full worked session (membership renewal bug) → `reference/report-template.md`.

## MCP Integrations (GitHub / OpenSearch / Rails)

Supplementary MCP calls (GitHub issue search/create, OpenSearch index health/search debug, Rails
`execute_ruby`) → `reference/mcp-integrations.md`. Org is `PlaybyCourt`.

---

## Kaizen: Continuous Improvement

> "Every day we must improve" — 改善

While executing this skill, if you discover a new debugging pattern, a useful ClickHouse query, or a
better Honeybadger workflow: finish the current session first, then append the improvement to
`kaizen_log.md` (verbatim archive). Keep the SKILL.md body lean — heavy detail lives in `reference/`
and `kaizen_log.md`, not in this file.

**Archived entries** (full text in `kaizen_log.md`): Jupyter Notebook integration (2026-01-24,
local-only); Production Script Rules (2026-01-23: strftime not `to_s(:db)`, nil-check before strftime,
`bin/d rails runner` local test, no heredocs in console, `update_column` to skip callbacks).

**Recent in-body promotions:** MCP tools → PRIMARY METHOD table (2026-01-31); ClickHouse-First
methodology → Step 1 + workflow + templates (2026-02-11, now in `reference/clickhouse-queries.md`);
Fix Iteration Circuit Breaker (2026-06-10, obra/superpowers MIT); confirm-loop + multi-source
perspectives (2026-06-05, `memory/feedback_confirm_loop_adversarial_findings.md`); ENG-544 repro
rules → Steps 4/5 + circuit breaker (2026-05-12).
