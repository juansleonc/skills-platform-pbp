# Safe Script Run Summary (output format)

When a safe script finishes, summarize the run so a reviewer can confirm it was safe.
This is the OUTPUT the skill produces for the user — not a file to commit. Include
these sections in plain markdown:

- Heading: script filename + JIRA ticket + one-line purpose.
- Docker dry-run line: records affected, error count, duration, and "changes rolled back".
- Docker test-env line: records affected, error count, duration, "committed", plus a
  one-line verification result.
- Production block (NOTE: prod runs execute in-pod via `rails runner`, never `bin/d`):
  - prod dry-run line (records, errors, duration, "output reviewed");
  - prod live line invoked as `LIVE=true CONFIRM=yes rails runner ...`
    (records, errors, duration, "SUCCESS").
- Verification queries: 1-2 SQL counts that MUST return 0 (no unfixed rows, no orphans).
- Rollback plan: a targeted DELETE/UPDATE scoped to the execution window
  (e.g. `WHERE created_at > '<run-start>' AND updated_at = created_at`).
- Lessons learned: 2-3 bullets (direct SQL speed, batching threshold, subset-first).

Keep numbers concrete (actual counts/durations from the run), not placeholders.
