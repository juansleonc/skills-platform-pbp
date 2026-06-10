---
name: grill-me
description: Before building a feature/refactor, the agent interviews YOU until every branch of the decision tree is resolved (ambiguity = 0). The interview transcript becomes the implementation context. Use when requirements are fuzzy, before /architect and /tdd. Inspired by Matt Pocock's /grill-me.
allowed-tools: [AskUserQuestion, Read, Grep, Glob, Bash]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

# Grill Me — Interrogate the human until ambiguity is zero

The agent interviews **you** about a feature/design until every branch of the
decision tree is resolved. The goal is **not a document** — it's a genuine shared
mental model (Brooks' "conceptual integrity") before any code or schema is touched.
The conversation history itself becomes the implementation context for `/architect`
and `/tdd`, so nothing needs to be re-explained downstream.

## When to Use

- Before implementing a feature or non-trivial refactor whose requirements are fuzzy.
- When a Jira ticket leaves edge cases, ownership, or scope under-specified.
- As **Phase 0, before `/architect`** in an `/orchestrate` run.
- Whenever you catch yourself about to make 3+ silent assumptions to start coding.

**Do NOT use for**: read-only questions, trivial one-line fixes, or tasks where the
spec is already unambiguous.

## Why this exists (and how it differs from /architect)

| Skill | Question it answers |
|-------|---------------------|
| `/grill-me` | *What exactly are we building, and what are the edge cases?* (removes ambiguity from the **requirement**) |
| `/architect` | *Where does the code live and which patterns do we use?* (designs the **solution**) |

`/grill-me` runs first. Its output feeds `/architect`. This is the sharper,
proactive form of CLAUDE.md rule #10 ("Interview the Code") — applied to the human
*before* writing, not just to the code after.

## Step 0: Check Investigations Folder (ALWAYS)

```bash
# Extract ticket ID from branch or message (e.g. CORE-624)
ls investigations/CORE-624/ 2>/dev/null
```

If prior research exists, **read it first** — don't ask questions already answered
there. Cite what you already know so the human only fills genuine gaps.

## Workflow

### 1. Build the decision tree (silently, first)

Read the ticket / request and the relevant code. Enumerate every dimension that
could change the implementation. Cover at least:

- **Scope boundary**: what is explicitly in vs. out? (Re-read the ticket's
  "Out of scope" — see memory `[[feedback_respect_approved_scope]]`.)
- **Data model**: new tables/columns? migrations? multi-tenancy scoping (`facility_id`)?
- **Write paths**: every code path that mutates the affected data (CLAUDE.md rule #10).
- **Edge cases**: nil/empty, duplicates, concurrency, wrong-record selection, partial failure.
- **Money/idempotency**: if payments/memberships touched — transactions, retries, who pays.
- **API surface**: GraphQL/REST changes? mobile backward-compat (CLAUDE.md rule #4)?
- **Auth**: who can do this? authorization parity across UI/API/jobs/channels (rule #12).
- **Failure/observability**: what happens when the external call fails? what gets logged?
- **Done definition**: what proves it works? which tests, which manual QA?

### 2. Interrogate — in batches, until resolved

Ask focused questions, batched by theme, using `AskUserQuestion` (offer concrete
options when you can — never make the human author free text you could propose).

Rules of the grill:
- **Do not proceed while any branch is unresolved.** Keep going until you can
  predict the human's answer to every remaining question.
- One theme at a time; don't dump 40 questions at once. Iterate.
- When an answer opens a new branch, add it to the tree and keep grilling.
- Surface assumptions explicitly: "I'm assuming X — confirm or correct."
- It's normal for this to take many rounds (Pocock cites 40–100 questions for a
  real feature). Depth here is cheaper than rework later.

### 3. Reflect the resolved model back

Once ambiguity is zero, restate the shared understanding compactly:
- One-paragraph statement of what's being built.
- Bullet list of resolved decisions (the answers).
- Explicit **in-scope / out-of-scope** lines.
- Open risks the human accepted.

Ask: "Is this the shared model? Anything I got wrong?" Wait for confirmation.

### 4. Persist only the brief (optional, local)

The *conversation* is the primary context — don't re-summarize for the agent.
If the work spans sessions, save just the resolved brief to:

```
investigations/CORE-624/grill-me-brief.md
```

(Local only — `investigations/` is in `.git/info/exclude`. Never `docs/`.)

### 5. Hand off

Proceed to `/architect` (design) → `/tdd` (red-green-refactor). The grill transcript
is already in context, so neither needs the requirement re-explained.

## Anti-patterns

- ❌ Asking one vague "any other requirements?" and calling it grilled.
- ❌ Writing a long PRD instead of building shared understanding (the doc is a
  byproduct, not the goal).
- ❌ Starting to code with unresolved branches "to keep momentum" — that's exactly
  the rework this skill prevents.
- ❌ Re-asking what `investigations/CORE-XXX/` already answers.

## Kaizen

> "Every day we must improve" — 改善

If you discover a recurring class of question worth always asking (e.g. a domain
keeps needing a specific edge case probed), append it to the Step 1 checklist.
Format: `<!-- Kaizen: YYYY-MM-DD --> ...`

<!-- Kaizen: 2026-05-25 - Created from Matt Pocock's "Workflow for AI Coding" talk -->
- Origin: https://www.youtube.com/watch?v=-QFHIoCo-Ko (the /grill-me concept).
- See memory `[[reference_ai_coding_multiagent_workflow]]` for the broader takeaways
  (smart-zone context limit, clear-don't-compact, vertical-slice DAG, push/pull rules vs skills,
  orchestrator/worker/validator).

<!-- Kaizen: 2026-05-25 - Factory multi-agent talk: emit validation contracts -->
- Per Luke Alvoeiro (Factory), the orchestrator should define **validation contracts**
  (testable assertions) BEFORE implementation, and a validator checks against them.
- So Step 3 ("reflect the resolved model back") should also emit an explicit list of
  **testable assertions** — these become the contract `/tdd` writes tests for and the
  validator (`adversarial-review`/`code-review`) verifies. Don't stop at prose; produce
  the assertions.
