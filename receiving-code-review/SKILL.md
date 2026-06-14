---
name: receiving-code-review
description: Use when receiving code-review feedback (human PR reviewers, Bugbot, CodeRabbit, Greptile) before implementing any suggestion. Requires technical verification and confirm-loop gating, not performative agreement or blind implementation. Pairs with adversarial-review (findings I generate) — this skill is for findings OTHERS generate.
allowed-tools: [Read, Grep, Glob, Bash, Edit, AskUserQuestion]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage, branch safety). Always check both for current conventions.

# Receiving Code Review

Code review is **technical evaluation, not emotional performance**. External feedback (especially from bots: Bugbot, CodeRabbit, Greptile) is a set of *suggestions to verify*, not *orders to follow*.

**Core principle:** Verify before implementing. Gate before acting. Technical correctness over social comfort.

This is the inbound counterpart to [[adversarial-review]]: there I generate findings; here I *receive* them. Both run the same **Confirm-Loop** (gate: real + in-scope + reproducible — see below).

## The Response Pattern

```
WHEN review feedback arrives:
1. READ      — full feedback, no reacting
2. UNDERSTAND — restate each item in my own words (or ask if unclear)
3. GATE      — confirm-loop: real + in-scope + reproducible (see below)
4. EVALUATE  — technically sound for THIS codebase/stack?
5. RESPOND   — technical acknowledgment or reasoned push-back
6. IMPLEMENT — one item at a time, TDD per item, verify each
```

## Confirm-Loop gate (before implementing ANY item)

Keep only findings that are:
1. **Real** — a genuine defect/improvement, not a style nit the bot pattern-matched.
2. **In-scope** — introduced by `git diff develop...HEAD` (a bot flagging pre-existing legacy code is usually out-of-scope; say so, don't silently fix unrelated lines).
3. **Reproducible** — provable without runtime instrumentation; for prod-state claims, verify with ClickHouse (`FINAL` + lag guard) / Honeybadger — MCP as MANUAL aids, never oracles.

Route confirmation by type:
- code/logic → reproduce LOCALLY with a failing test first (rule #8 — real request, not runner+stub).
- API/library usage → Context7 (a negative docs result is low-confidence; verify against signature dump before asserting absence).
- "does this happen in prod / at what scale" → ClickHouse / Honeybadger.

**Discard theoretical / out-of-scope items with a one-line technical reason.** Don't amplify a false positive just because a bot said it.

## Forbidden responses

**NEVER:**
- "You're absolutely right!" / "Great point!" / "Excellent feedback!" — performative.
- "Thanks for catching that!" / ANY gratitude expression — actions speak; just state the fix.
- "Let me implement that now" — before the gate above.

**INSTEAD:** restate the technical requirement, ask if unclear, push back with reasoning if wrong, or just show the fix in the code.
> If I catch myself about to write "Thanks" / "You're right" → delete it, state the fix.

## Per-source handling

### Human PR reviewer (team — Erick/Rafa/etc.)
- Trusted, but still gate scope. No performative agreement. Skip to action or a technical acknowledgment.
- If feedback conflicts with a prior architectural decision (e.g. an intentional scope-out documented in `investigations/<ticket>/`): **stop and discuss**, don't silently comply.

### Bots (Bugbot / CodeRabbit / Greptile)
Before implementing, check:
1. Technically correct for THIS stack (Rails 6.1, Ruby 3.1, our gateways/packs)?
2. Does it break existing functionality or a mobile API contract (rule #4)?
3. Is there a reason for the current implementation (legacy/compat/intentional)?
4. Does the bot understand full multi-tenant / payment / timezone context?

If it seems wrong → push back with technical reasoning. If I can't verify → say so: "Can't verify without [X]; investigate / ask / proceed?". Bots have NO context on intentional scope-outs — treat their findings as the *lowest-trust* input and gate hardest.

### YAGNI check
If a reviewer says "implement this properly", `grep` for real usage first.
- Unused → "Nothing calls this; remove it (YAGNI)?" rather than building it out.
- Used → implement properly.

## Handling unclear feedback

If ANY item is unclear, **STOP** — don't implement the clear ones yet. Items may be related; partial understanding → wrong implementation. Ask for clarification on the unclear items first, then implement the batch in order:
1. Blocking (breaks, security, data-integrity, payment) →
2. Simple (typos, imports, naming) →
3. Complex (refactor, logic).
Test each fix individually (TDD: failing test → fix → green → full suite). No batching without per-item verification.

## When to push back

Push back when the suggestion: breaks existing functionality / a mobile contract · the reviewer lacks full context · violates YAGNI · is technically wrong for our stack · has a legacy/compat reason · conflicts with a documented architectural decision.

**How:** technical reasoning (not defensiveness), reference working tests/code/`investigations/` notes, involve the human if architectural. If I pushed back and was wrong: "Verified — you're correct, my reading of [X] was wrong because [reason]. Fixing." — factual, no long apology.

## Acknowledging correct feedback

```
✅ "Fixed — [what changed] in [location]."
✅ "Good catch — [specific issue]. Failing test added + fixed in [file:line]."
✅ [just fix it; the diff shows I heard it]
❌ "You're absolutely right!" / "Great point!" / "Thanks for catching that!"
```

## Replying on GitHub

Reply **in the inline comment thread**, not as a top-level PR comment:
```
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies -f body="..."
```
If the reply is substantive/outward-facing, draft it and confirm before posting — don't auto-post. Commits that resolve feedback follow gitmoji + ticket format (local rule #14); never put ticket refs in code/comments (they belong in commits/PRs only).

## Terminate

Stop the loop on: all gated items resolved + verified, or 2 clean re-review passes, or a hard cap. Autonomy ends at the action gate — commit/push/PR-reply stay user-approved.

## The bottom line

**External feedback = suggestions to gate, verify, and then act on — or push back.**
No performative agreement. Confirm-loop always. Evidence before the fix.

## Validation

Success:
- ✅ Every implemented item had its gate (real + in-scope + reproducible) pass first.
- ✅ Behavioral suggestions got a failing test BEFORE the fix (rule #8).
- ✅ Out-of-scope / false-positive bot findings were declined with a one-line technical reason, not silently fixed.
- ✅ Zero performative agreement / gratitude phrases in the response.

Failure indicators:
- ❌ Implemented a bot suggestion without reproducing it.
- ❌ "You're absolutely right" / "Thanks for catching that" slipped into a reply.
- ❌ Silently fixed pre-existing legacy code a bot flagged (scope creep).
- ❌ Posted a GitHub reply without drafting/confirming an outward-facing comment.

## Kaizen: Continuous Improvement

> "Every day we must improve" — 改善

If you discover a better gate, a missed bot-feedback failure mode, or a clearer push-back pattern: finish the task, then run `/kaizen` — do not self-edit this file mid-execution.

History: [kaizen_log.md](kaizen_log.md)

---

_Adapted from obra/superpowers `receiving-code-review` (MIT), grounded in PBP conventions + the confirm-loop._
