# debug/kaizen_log.md — Archived Kaizen Entries

> Verbatim archive of heavy Kaizen entries removed from SKILL.md to reduce per-invocation context cost.
> Do not delete — referenced from SKILL.md Kaizen section.

---

<!-- Kaizen: 2026-01-24 - Jupyter Notebook Integration -->
## Jupyter Notebook Integration (Optional)

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
FROM payments FINAL
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

> **Note (Fable re-audit 2026-06-10)**: `mcp__ide__executeCode` and `mcp__ide__getDiagnostics` are NOT available in this project's MCP configuration. The Jupyter workflow above is for local manual use only (`~/jupyter-env/bin/jupyter lab`).

---

<!-- Kaizen: 2026-01-23 - Production Script Rules -->
## CRITICAL: Production Script Rules

When creating scripts for production Rails console, **ALWAYS** follow these rules:

### 1. Ruby 3 Syntax Compatibility

```ruby
# WRONG - Deprecated in Ruby 3
date.to_s(:db)
time.to_s(:db)

# CORRECT - Use strftime
date.strftime('%Y-%m-%d')
time.strftime('%Y-%m-%d %H:%M:%S')
```

### 2. Handle nil Values BEFORE Calling Methods

```ruby
# WRONG - Will crash if nil
starts = membership.acquired_at.strftime('%Y-%m-%d %H:%M:%S')

# CORRECT - Handle nil first
starts = membership.acquired_at ? membership.acquired_at.strftime('%Y-%m-%d %H:%M:%S') : Time.current.strftime('%Y-%m-%d %H:%M:%S')
```

### 3. Test Scripts in Docker BEFORE Sending to Production

```bash
# ALWAYS test locally first
bin/d rails runner "
  # Your script here
  puts 'Test output'
"
```

### 4. NEVER Use Heredocs in Rails Console

```ruby
# WRONG - Heredocs don't paste well in console
ActiveRecord::Base.connection.execute(<<-SQL)
  SELECT * FROM users
SQL

# CORRECT - Single line or concatenated strings
ActiveRecord::Base.connection.execute("SELECT * FROM users WHERE id = #{id}")
```

### 5. Skip Model Callbacks for Manual Data Fixes

```ruby
# WRONG - Triggers callbacks that may fail
MembershipPayment.create!(payment_id: 123, ...)

# CORRECT - Direct SQL for manual fixes
ActiveRecord::Base.connection.execute("INSERT INTO membership_payments (...) VALUES (...)")

# ALSO CORRECT - update_column skips callbacks
payment.update_column(:paid, true)
```

### 6. Provide Step-by-Step Commands

When giving commands for production, provide them **one at a time** so the user can:
- Copy/paste easily
- See the result of each step
- Abort if something goes wrong

---

<!-- Kaizen: 2026-06-14 - /optimize-skill progressive-disclosure pass -->
## Body slimmed 823 → 231 lines; six reference files extracted

Relocated heavy REFERENCE blocks out of SKILL.md into `reference/` (one level deep, body keeps the
decision rules + one-line pointers):
- `reference/clickhouse-queries.md` — Step 1 logs-table templates + Step 3 DB-table queries, with the
  two duplicate "Timeline Analysis" queries **merged** into one section with labeled sub-queries
  (a) logs table and (b) DB table (FINAL). Worked example (payment_id=39204765) moved here too.
- `reference/error-tracking.md` — Step 2 Honeybadger + Sentry MCP calls and field tables.
- `reference/error-service.md` — ErrorService patterns + anti-pattern.
- `reference/report-template.md` — Report layout + full worked session.
- `reference/mcp-integrations.md` — GitHub / OpenSearch / Rails MCP supplementary calls.

Correctness fixes applied: removed stale heading date ("Debugging Workflow (UPDATED 2026-02-11)" →
"Debugging Workflow"); deleted pre-H1 "Config Priority" + "Shared References" blockquotes (redundant
with CLAUDE.local.md / frontmatter); deleted the restated H1 "# Production Debugging Skill" + subtitle
(duplicated frontmatter `name`); merged the duplicate Timeline Analysis queries; densified the
PRIMARY METHOD table (added a `fallback` column, folded the critical-rule prose into one line) and the
Why-ClickHouse-First anecdote (→ one footnote line).

DEFERRED (left unchanged, need user decision): `disable-model-invocation: false` frontmatter key (may
be a local-harness extension, not in the published Anthropic spec); description "when to use" trigger
phrase (subjective improvement); Kaizen self-edit instruction wording (current behavior lets the agent
self-improve the body — redirecting all writes to kaizen_log.md only is a workflow change); Step 5
"Common Debugging Patterns" kept INLINE rather than relocated (it borders on decision content —
which snippet for which symptom).

---

<!-- Kaizen: 2026-06-14 - Schema-grounding fix for Step-5 console snippets -->
## Step-5 snippets rewritten against verified schema (2026-06-14)

Both Step-5 debugging snippets in SKILL.md were referencing non-existent DB columns/models.
Fixed by rewriting against `db/structure.sql` + `app/models` ground truth:

**Payment Issues (was broken, now fixed):**
- Removed `Payment.find_by(trace_id:)` — `trace_id` is not a column; it lives as
  `Current.payment_trace_id` / `X-Payment-Trace-Id` header / log+ClickHouse field only.
  Replaced with `Payment.find_by(transaction_id:)` (indexed column, line 3520/3552 of structure.sql).
- Removed `payment.payment_transactions.order(:created_at)` — `PaymentTransaction` model does not
  exist; there is no `payment_transactions` table.
- Removed `PaymentTransaction.where(idempotency_key:)` — same, model does not exist.
- Kept `payment.meta['gateway_response']` (valid: `meta` is mediumtext, line 3490).
- Added `payment.status` and `payment.gateway` (real columns, lines 3495/3534).
- Added `payment.meta_json` (real JSON column, line 3535).

**Membership Issues (was broken, now fixed):**
- Removed `.slice(:status, :expires_at, :auto_renew, :cancelled_at)` — none of these columns exist.
  Replaced with `.slice(:aasm_state, :current_period_end_at, :paused_at, :termination_date,
  :renewal_payment_method)` (all real columns, lines 2814-2820 of structure.sql).
- Removed `membership.membership_transactions.renewal.order(:created_at)` — `MembershipTransaction`
  does not exist; association is `has_many :membership_payments` (model `MembershipPayment`, table
  `membership_payments` confirmed at line 2613). Replaced with
  `membership.membership_payments.order(:created_at)`.
- Replaced renewal-eligibility query `Membership.where(auto_renew: true)...where(status: 'active')`
  (zero valid columns) with `Membership.where.not(aasm_state: 'cancelled').where('current_period_end_at < ?', Time.current)`.
  Added comment noting the exact aasm_state set to investigate may vary — confirm with team.

---

<!-- Kaizen: 2026-06-14 - /optimize-skill correctness audit (headless, no structural change) -->
## Schema audit of Step-5 console snippets — 2 wrong against live schema; deferred (need user input)

Body unchanged at 231/500 lines (well under ceiling; all 5 reference pointers resolve one level deep,
no orphans). No relocate needed. The audit found two Step-5 snippets that reference schema that does
NOT exist (verified against `db/structure.sql` + `app/models`):

- **Membership Issues snippet** (lines 132-138): uses `membership.slice(:status, :expires_at,
  :auto_renew, :cancelled_at)`, `membership.membership_transactions.renewal`, and
  `Membership.where(auto_renew: true).where('expires_at < ?', ...).where(status: 'active')`. VERIFIED:
  `memberships` table has none of `status` / `expires_at` / `auto_renew` / `cancelled_at`. It has
  `aasm_state` (default 'idle'), `current_period_end_at`, `paused_at`, `termination_date`,
  `renewal_payment_method`. The association is `has_many :membership_payments` (model
  `MembershipPayment`) — there is NO `membership_transactions` association/table and NO `.renewal`
  scope. Model scopes: `invalid_memberships` = `where("current_period_end_at < ? OR aasm_state =
  'paused'", Time.current)`; `non_cancelled` = `where.not(aasm_state: "cancelled")`. Every line of the
  current snippet would raise. DEFERRED — fix is aasm-state-driven (no `auto_renew` boolean, no
  `.renewal` scope), so the exact renewal-eligibility filter is a USER decision, not a mechanical
  rename.
- **Payment Issues snippet** (lines 123-128): uses `Payment.find_by(trace_id: 'xxx')`,
  `payment.payment_transactions.order(:created_at)`, `PaymentTransaction.where(idempotency_key:)`.
  VERIFIED: `payments` table has NO `trace_id` column (trace lives as `Current.payment_trace_id` /
  `X-Payment-Trace-Id` header / log+ClickHouse field, not a DB column); it has `transaction_id`, `meta`,
  `meta_json`, `status`, `gateway`. There is NO `payment_transactions` table and NO `PaymentTransaction`
  model. `payment.meta['gateway_response']` is the only valid line (`meta` mediumtext confirmed).
  DEFERRED — the real model/association for payment attempts + idempotency must be confirmed with the
  user before substituting (do not invent a model name); trace lookup is via logs/ClickHouse on
  `payment_trace_id`, not a DB lookup.

Also DEFERRED (leanness, user's call): the "ClickHouse first, console last" ordering is restated 4x
(PRIMARY METHOD table + bolded rule + Debugging Workflow ASCII + "Why ClickHouse First?" table) — could
collapse to one canonical statement, but the redundancy may be intentional emphasis. Body is under
budget so not forced.

Frontmatter note (no change): `disable-model-invocation: false` is a PBP-harness extension consumed by
this repo (sibling skills use it), NOT part of the published Anthropic frontmatter spec
{name, description, license, allowed-tools, metadata, compatibility}. Flagged for awareness; do not
strip.
