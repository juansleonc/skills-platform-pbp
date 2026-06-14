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
