---
name: confirm-loop-gate
description: Canonical confirm-loop gate shared by /adversarial-review (findings I generate) and /receiving-code-review (findings others generate). Gate each finding before acting — real + in-scope + reproducible — and terminate on 2 clean passes, never blind.
---

# Confirm-Loop Gate

> One authoritative copy. Both `/adversarial-review` (findings I generate) and
> `/receiving-code-review` (findings others — humans/Bugbot/CodeRabbit/Greptile — generate)
> run THIS loop. Each skill adds its own framing on top; the gate mechanics below are shared.

Iterate to resolution as a **GATED loop, never blind**:

1. **Gate each finding before acting** — keep only findings that satisfy ALL three:
   1. **Real** — a genuine defect/improvement, not a style nit pattern-matched (especially by a bot).
   2. **In-scope** — introduced by `git diff develop...HEAD`. Pre-existing legacy code a finding flags is usually out-of-scope; say so, don't silently fix unrelated lines.
   3. **Reproducible** — provable WITHOUT runtime instrumentation (no monkey-patch, no injected `raise`/`rescue`, no stub on private methods). Data setup (`update_columns`, fixtures) is allowed; runtime code modification is not.

   Discard theoretical / out-of-scope items with a one-line technical reason. Don't amplify a false positive just because a bot (or my own lens) raised it.

2. **Confirm by finding type** — route corroboration to the right oracle:
   - **code/logic** → reproduce LOCALLY with a failing test first (rule #8 — real request, not runner+stub).
   - **API/library usage** → Context7 (a negative docs result is low-confidence; verify against a signature dump before asserting absence).
   - **prod-state / "does this happen, at what scale"** → ClickHouse (apply `FINAL` on ReplacingMergeTree + mind replica lag) or Honeybadger.

   MCP tools = MANUAL corroboration aids, never automated oracles. Use ≥2 independent sources on load-bearing claims.

3. **Document each CONFIRMED case** in `investigations/<ticket>/findings.md` (gitignored).

4. **Terminate on 2 consecutive clean passes** or a hard cap — not infinite.

5. **Autonomy ends at the action gate**: auto up to confirmed + documented + fix-proposed; commit / push / destructive / outward-facing actions stay manually approved.
