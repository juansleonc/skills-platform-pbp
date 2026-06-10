---
name: adversarial-review
description: Use when reviewing a code change, validating a fix, or before declaring any implementation correct — especially migrations, backfills, or bulk deletes.
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

# Adversarial Review

This is a multi-agent review. Run **Step 0** yourself first, then launch the agents IN PARALLEL using the Agent tool, passing each the diff and scope from Step 0. Aggregate their findings and present a unified verdict.

## Workflow (Step 0 — run BEFORE launching any agent)

These steps are not optional. They were learned the hard way (see Kaizen log) and are the difference between findings the author can act on and theory that wastes their time.

**0.1 — Map the change surface.** Run `git diff develop...HEAD --stat` and the full `git diff develop...HEAD`. Only behavior *introduced by this diff* is eligible for the verdict. Pre-existing behavior goes to NOTES, never the verdict. Paste the diff stat into every agent prompt so each knows the exact scope.

**0.2 — Detect destructive data operations.** Grep the diff for any of: files under `db/migrate/`, `delete_all` / `destroy_all` / `update_all`, raw `DELETE` / `UPDATE` / `TRUNCATE` SQL, `rake` tasks that mutate rows, bulk `touch` / reindex fanouts. **If any match → also launch Agent 4 (Destructive-Data Auditor)** alongside the three core agents. If none match, skip Agent 4.

**0.3 — Finding filter (hard gate before the verdict).** Every candidate finding must satisfy ALL three:
1. **Introduced by this diff** (Step 0.1), not pre-existing in `develop`.
2. **Reproducible WITHOUT runtime instrumentation** — no monkey-patch, no injected `raise`, no forced `rescue`, no stub on private methods of `allocate`d objects. Data setup (`update_columns`, fixtures) is allowed; runtime code modification is not.
3. **Reflects a state that exists in prod** — verify BEFORE fabricating with `mcp__clickhouse__run_query` (`SELECT count() … WHERE <condition>`) or a recurring Honeybadger fault on the same path. If 0 rows / 0 faults match, the state is impossible in prod → the finding is theoretical.

Any finding failing any of the three → demote to a NOTES section labeled `pre-existing` or `theoretical (no real repro)`. Final filter every verdict finding must pass: *"Does a real user, with real data, in a real client flow, observe this?"*

**0.4 — Real-request repro for HTTP-facing code.** For GraphQL resolvers, controllers, middlewares, and endpoint-triggered jobs, the default repro is a real request (Postman/curl/`graphql_post` integration spec) BEFORE any `rails runner` script. Runner + monkey-patch bypasses resolver order, middleware, auth, and per-request shared context — exactly where many real bugs live. Runner-only repro is acceptable only for purely internal services with no HTTP entry. For aliased-query findings, confirm a real client (mobile/web/external API) actually emits the alias (`grep -rn "<field>:" <client-repo>`) — a query you hand-craft to force a collision is construction, not observation.

## Launching the agents

- Launch each agent with `subagent_type: "Explore"` — read-only (no Edit/Write/NotebookEdit), which is what a review must be. Explore can still run `git diff`, grep for sibling write paths, read files, and run ClickHouse read queries.
- Give each agent a focused, single-responsibility role (its section below is the prompt). Paste the Step 0.1 diff stat + the relevant diff into each prompt template where it says `[PASTE DIFF OR CONTEXT HERE]`.
- The agents run independently and report back; you (the orchestrator) aggregate. They do not talk to each other. If a future review genuinely needs agents to challenge each other's findings or share state, *agent teams* are the documented next step — not needed here; independent agents + aggregation is simpler and sufficient.

## When to use (project-specific)

✅ **Use for**:
- Financial code paths (payments, memberships, AR, billing)
- State-machine / policy / permission changes (CanCanCan, Pundit, Action Policy)
- Refactors that *remove* protective code (guards, validations, scopes)
- Changes touching multiple write paths to the same data
- Destructive / large-scale data operations — migrations, backfills, bulk delete/update/reindex rake tasks (these additionally trigger Agent 4)
- Before declaring any fix complete on high-stakes branches (e.g. reservations, memberships)

❌ **Skip for**:
- Typos, copy, cosmetic/UI changes, docs, config
- Pure renames / dead-code removal
- Cases already fully covered by a domain validator (`/multi-tenancy`, `/timezone`, `/pci-compliance`, etc.)

This skill complements `/code-review` — that one is grep/pattern-based, this one is reasoning-based failure construction. Run them in series when the stakes justify it.

## Shared Principles (apply to ALL agents)

### Inversion (Munger)
Do not ask "does this work?" Ask "how does this fail?" Correctness is better found by eliminating what is wrong than by confirming what seems right.

### Via Negativa (Taleb)
Improve by removing flaws, not by adding confidence. What you take away matters more than what you add.

### Map Is Not Territory (Korzybski/Munger)
Your mental model of the code is not the code. Your trace is not the execution. Verify against the territory, not your map of it.

### Signal vs Noise (Shannon)
Not all information is signal. Distinguish what matters for correctness from what merely looks relevant. High entropy means more uncertainty — high-entropy areas need more verification, not less.

### The Constraint Governs the System (Goldratt)
The system fails at its weakest point, not its average point. Find the constraint. Everything else is noise until the constraint is addressed.

### Second-Order Effects (Munger)
Every change has consequences beyond its intent. Ask: what does this change make possible that was previously impossible — both good and bad?

### Conservation (Physics)
Nothing is created or destroyed, only transformed. If something appears or disappears in the system (a state, a record, a side effect), trace where it came from or where it went. Unexplained appearances or disappearances are bugs.

### Entropy Increases (Thermodynamics)
Systems degrade toward disorder over time. Code that depends on everything going right is fragile. Reason about what happens as the system ages, accumulates edge cases, and drifts from initial assumptions.

---

## Agent 1: The Inverter

**Role**: For every claim of correctness, construct its negation. Your only job is to try to make things fail.

**Principles to apply**:

- **Proof by Contradiction (Mathematics)**: Assume the opposite of what is claimed and derive a consequence. If you reach an absurdity, the claim holds. If you reach a plausible failure, you have found a bug.
- **Pre-Mortem (Klein)**: The worst outcome has already happened. Work backwards to find the cause. Do not ask "could this happen?" — trace the path that made it happen.
- **Doubt-Avoidance Defense (Munger)**: Uncertainty is uncomfortable. The mind resolves it by concluding quickly, not correctly. When you feel "this is fine" — that is the moment to push harder.
- **Inconsistency-Avoidance Defense (Munger)**: Prior conclusions distort new evidence. If a previous analysis said "correct," that is reason to scrutinize more, not less.
- **Observer Effect (Physics)**: Your act of reviewing may change your perception of the system. The code you traced in your head is not the code that executes. Re-derive, don't recall.

**Prompt template for this agent**:
```
You are the Inverter. Your job is to BREAK this code, not confirm it.

For each claim of correctness in these changes, attempt to construct a concrete failure scenario step by step.
If you succeed: you found a bug. Describe the exact path.
If you fail: state which specific mechanism blocked you at which specific step.
"I cannot think of how it breaks" is NOT acceptable. Name the guard that prevents it.

Apply pre-mortem thinking: assume each category of failure has already occurred (duplicated operation, lost operation, wrong selection, corrupted state, silent failure). Trace backwards through the actual code to find or rule out the path.

[PASTE DIFF OR CONTEXT HERE]
```

**Platform priors** (where these failures actually live here — hints, not a checklist; still reason from first principles):
- **Write-path incompleteness**: a guard added on one path while a sibling path that writes the same data is left unguarded. Real case: `Mutations::MembershipPayPending` honored the rule but the REST `Memberships::ProcessPendingPaymentsService` and the auto-renewal job did not. When you see a new guard/validation, grep for every caller that writes the same column/record and confirm each is covered.
- **Wrong actor/owner**: an operation charged/attributed to `current_user` / `payment_details[:user]` instead of the field that governs it (e.g. `automatic_payment_user_id`). Ask: which record decides who is affected, and does the code read THAT field?

---

## Agent 2: The Boundary Prober

**Role**: Find the edges where behavior changes. Every conditional has a boundary. Reason AT the boundary, never in the comfortable middle.

**Principles to apply**:

- **Boundary Value Analysis (Mathematics)**: Interesting behavior lives at edges, not centers. Zero, nil, negative, maximum, empty, exactly-equal — these are where bugs hide.
- **Pigeonhole Principle (Mathematics)**: If more items exist than containers, collision is guaranteed. When a query assumes uniqueness, multiplicity is the attack. When ordering assumes determinism, ties are the attack.
- **Redundancy and Error Correction (Shannon)**: A system without redundancy fails on any single error. Check whether each critical path has exactly one defense or multiple independent defenses.
- **Circle of Competence (Munger)**: If you are uncertain about the mechanics of a boundary (timezone coercion, float precision, nil propagation), say so. Uncertainty is information to surface, not a flaw to hide.
- **Contrast-Misreaction Defense (Munger)**: Do not compare the change to the old code. Compare it to the invariant. "Better than before" is not the standard. "Correct" is.

**Prompt template for this agent**:
```
You are the Boundary Prober. Your job is to find the edges where behavior changes and test them.

For every conditional, type comparison, query filter, and guard clause in these changes:
1. What is the boundary value? (zero, nil, negative, exactly-equal, empty collection, off-by-one)
2. What happens AT the boundary? Not near it — ON it.
3. What happens on each side of the boundary?
4. Is the boundary tested? If not, it is unverified.

For every query that selects a single record (.first, .find_by, .limit(1)):
5. What ordering is assumed? Is it explicit or implicit?
6. What happens when multiple records match? Which one wins and why?

For every type that crosses a boundary (Date vs DateTime, Integer vs Float, String vs nil):
7. What coercion happens? Is it the same on both sides of the comparison?

For every PREDICATE over a collection (`.all?`, `.none?`, `.any?`, `.include?`, `.min`, `.max`, `.sum`, `.first`, `.last`):
8. What does it evaluate to when the collection is EMPTY? `[].all? { }` and `[].none? { }` are **vacuously TRUE**; `[].any? { }` is FALSE; `[].min`/`.max`/`.first`/`.last` are nil; `[].sum` is 0. Does an empty collection flip a branch the WRONG way, or feed a nil into a downstream comparison/interpolation?
9. Is "empty" semantically distinct from "non-empty and all-match"? If a guard uses `.all?` to mean "every element satisfies X / fully covered", the empty set masquerades as "fully covered / nothing-left-to-check" — usually the opposite of intent. Require an explicit `.any?` (non-empty) gate before such a check, or handle empty as its own branch.

[PASTE DIFF OR CONTEXT HERE]
```

**Platform priors** (where these failures actually live here — hints, not a checklist):
- **Timezone boundary (facility-zone vs app-zone)**: parsing/building dates with `Time.zone` / `Time.current` (app default, often Eastern) where the facility's own zone is required. Real case: a bulk billing-date change parsed in app-zone charged Pacific facilities a full day early. The boundary is midnight: a date stored as `00:00` app-zone is the *previous day* in a western facility zone. The correct pattern uses `facility.current_time_zone.local(...)`.
- **Empty-collection widening**: `ids.presence || Model.ids` (or `where(...).presence || all`) silently turns an empty filter into "everything". Real case: `@facility_ids.presence || Facility.ids` broke the `[] = empty result` contract into `[] = all facilities` — both a tenancy leak and a backward-compat break for clients sending an empty array as a wildcard-off.
- **Vacuous truth on empty collections (`.all?`/`.none?`)**: a branch keyed on `collection.all? { … }` to mean "fully covered / every element holds" silently flips when the collection is empty, because `[].all?` is `true`. Real case (CORE-624): `resuming_from_backup?` used `to_delete_ids.all? { |id| backup.include?(id) }`; an empty delete-set (idempotent re-run after a completed chunk) was therefore misclassified as a backup resume, sourcing stale per-facility/family reports while `planned_delete_count` was 0. Fix: gate with `to_delete_ids.any? &&` before the `.all?` coverage check. Six prior safety-axis passes missed this — always evaluate every `.all?`/`.none?`/`.any?`/`.min`/`.max` at the empty boundary.
- **Single-record selection on ties**: `.first` / `.find_by` / `.limit(1)` without a deterministic `order` — when two rows match, which wins is undefined and can flip between environments.

---

## Agent 3: The Invariant Auditor

**Role**: Identify what must ALWAYS be true, then verify the change preserves it unconditionally — not just under the conditions imagined.

**Principles to apply**:

- **Invariant Preservation (Computer Science)**: A correct system maintains its invariants across ALL state transitions. If an invariant can be violated by any path — even an unlikely one — it is not an invariant, it is a hope.
- **State Machine Completeness (Computer Science)**: Every state must have defined behavior for every possible input. Undefined transitions are bugs, not edge cases.
- **Conservation Laws (Physics)**: If a value enters the system, it must be accounted for. If a record is created, its lifecycle must be defined. Unexplained creation or disappearance signals a defect.
- **Local vs Global Optimum (Goldratt)**: A change that improves one subsystem may degrade the whole. Verify that local correctness does not violate global invariants.
- **Excessive Self-Regard Defense (Munger)**: Confidence scales with familiarity, not accuracy. The more you have looked at something, the more certain you feel, the less likely you are to see what you missed.
- **Social Proof Defense (Munger)**: "It has always worked this way" is survivorship, not evidence. The absence of detected failure is not the presence of verified safety.

**Prompt template for this agent**:
```
You are the Invariant Auditor. Your job is to identify what must ALWAYS be true and verify this change preserves it.

1. List the invariants this code must maintain (domain invariants, data integrity, state consistency, ordering guarantees).
2. For each invariant, trace whether the change preserves it under ALL conditions — not just the happy path.
3. For each write operation, verify atomicity: can a partial write leave the system inconsistent?
4. For each state transition, verify completeness: is every possible prior state handled?
5. For any removed code, verify: what invariant was the removed code protecting? Is that protection still provided by another mechanism?
6. **Output/report consistency is an invariant.** If this code emits operator-facing numbers, summaries, per-group breakdowns, or warnings, are those fields MUTUALLY consistent and faithful to what actually happened? Can two fields contradict (e.g. `planned == 0` yet a per-group breakdown is populated; a sum-of-parts ≠ the total; a warning fires with zero underlying cause, or stays silent when the cause exists)? Operators make go/no-go decisions on these numbers — an internally inconsistent or misleading report is a real defect even when no data is corrupted.
7. **Re-run output idempotency.** If the task/op can be run more than once (dry-run twice, execute-then-rerun, restore twice, resume after a chunk already completed), are the REPORTED numbers correct and non-contradictory on the SECOND run — not just the data effects? A benign no-op re-run must not emit misleading output (the empty/already-done case is the usual trap — see Boundary Prober's vacuous-truth lens).

If an invariant is not preserved unconditionally, state the specific condition under which it breaks.

[PASTE DIFF OR CONTEXT HERE]
```

**Platform priors** (where these failures actually live here — hints, not a checklist):
- **Multi-tenancy isolation**: every query on tenant data must be scoped by `facility_id` unless franchise/global scope is explicitly intended. The invariant "a facility sees only its own data" must hold across collection paths, single-record lookups, AND peer resolvers/controllers that share the same surface.
- **Sibling enumeration ("interview the code")**: when a guard is added to one branch, the invariant is only preserved if EVERY sibling branch enforces it. Real case: three sibling endpoints in one controller called `ensure_public_facility_visible!` but `book_a_lesson` was missed. Enumerate all branches and state coverage explicitly — do not assume the one you read is the only one.
- **Job idempotency & resume**: a job that retries must re-check preconditions before acting (period not already advanced, lock still held, fingerprint still matches) so a stale/duplicate run does not double-charge or double-write. After a crash mid-operation, a same-input re-run must resume from a checkpoint, not restart destructively.
- **Report consistency & re-run output (the operator's eyes)**: the numbers a rake/job prints are an invariant — they must agree with each other and with reality on the first run, on a resume, AND on a benign re-run. Real case (CORE-624): an idempotent re-run of a completed chunk reported `planned=0`/`deleted=0` while `per_facility` and `family_inconsistencies` were sourced from a stale backup, and a spurious family warning fired. Cross-check every emitted field against the others (planned vs deleted vs backed-up vs per-group sum vs kept vs warnings) and verify the report holds on re-run, not just the data. Static diff-level bots (e.g. Bugbot) catch this class well — treat their findings as complementary signal, not noise.

---

## Agent 4: The Destructive-Data Auditor (conditional)

**Launch this agent ONLY when Step 0.2 matched** — the diff touches migrations, backfills, bulk `delete_all`/`destroy_all`/`update_all`, raw `DELETE`/`UPDATE`/`TRUNCATE`, row-mutating rake tasks, or bulk reindex fanouts. The other three agents reason about *incorrect logic*; this one reasons about the failure mode they under-weight: **irreversible data loss or corruption at production scale.**

**Role**: Assume this operation will run once, against the full production dataset, and will be interrupted partway through. Find what is lost, double-applied, or unrecoverable.

**Principles to apply**:

- **Reversibility (Via Negativa)**: A destructive op without a path back is a one-way door. Is there a backup taken BEFORE the destroy, in a location that survives (e.g. a separate `data_playground`-style schema, not the same table being mutated)? Is the migration's `down` real and tested, or a no-op/`raise`?
- **Idempotency & Resume (Conservation)**: Running the op twice must not delete twice or corrupt. After a crash at row N, does a same-input re-run resume from a checkpoint, or does it restart, double-delete, or wedge on a half-written artifact (e.g. a partially populated backup table with the same label)?
- **Atomicity / Partial Failure (Invariant Preservation)**: Where is the transaction boundary? If the process dies between "deleted from A" and "inserted into B", what state remains, and is it self-healing or permanently inconsistent?
- **Blast Radius at Prod Scale (The Constraint Governs)**: Estimate affected rows and lock duration BEFORE approving — query `mcp__clickhouse__run_query` (`SELECT count() … WHERE <the op's WHERE clause>`). A long `update_all`/`delete_all` on a hot table holds locks and causes downtime; the dev-data row count is not the prod row count.
- **Selection Correctness (Boundary + Pigeonhole)**: Does the `WHERE` select EXACTLY the intended rows — no more, no fewer? How are `NULL`s handled? Real case: `NULL user_id` rows collapsed to a synthetic `user 0` and were silently swept into the operation. Off-by-one on a range, an unanchored `LIKE`, or a join that fans out are all here.
- **Approved Scope (governs whether the op should run at all)**: A destructive step is only legitimate if the ticket approved THAT destruction. Integrity consequences of an *already-approved* action (e.g. `touch`/reindex after an approved link change) are fine. New destructive ops on *other* tables, or a cleanup the ticket marked "out of scope / cleanup separado", require their own sign-off — flag them, do not bless them as a default step.

**Prompt template for this agent**:
```
You are the Destructive-Data Auditor. This change deletes, overwrites, or bulk-mutates data. Assume it runs ONCE against full production data and is interrupted partway through.

1. Reversibility: Is there a backup BEFORE the destroy, in a location that survives the operation? Is the migration `down`/rollback real and tested — or a no-op? If the data is gone, can it be recovered, and from where?
2. Idempotency & resume: If this runs twice, or crashes at row N and is re-run with the same input, does it double-delete, corrupt, or wedge? Is there a checkpoint/resume guard, or does it restart from zero?
3. Atomicity: Where is the transaction boundary? If it dies mid-operation, what state remains and is it self-healing or permanently inconsistent?
4. Blast radius: What is the prod row count and lock duration for this WHERE clause? (State the ClickHouse/SQL count query to run before approving.) Could it cause downtime on a hot table?
5. Selection correctness: Does the WHERE select EXACTLY the intended rows? How are NULLs, ranges, LIKEs, and joins handled — any over- or under-selection?
6. Approved scope: Is each destructive step covered by the ticket's approval, or is some of it out-of-scope cleanup that needs separate sign-off? Distinguish integrity consequences of an approved action from new destructive ops.

For each risk, give the concrete scenario and the specific row(s)/state lost. If a safeguard exists, name it and the exact step it protects.

[PASTE DIFF OR CONTEXT HERE]
```

---

## Aggregation

**Reviewer stance — do NOT trust the worker's self-reported summary.**

When verifying an implementer's work, read the actual diff line by line and confirm each claim independently. A worker that finished suspiciously fast, skipped a contract, or silently narrowed scope will often say "done" in honest good faith — the summary is not a lie, it is an incomplete map. This sharpens the creator/verifier separation: the verifier's job is to form its own verdict from the territory (the diff, the tests, the contracts), not to audit the worker's self-description of it.

This complements the `receiving-code-review` confirm-loop (same skepticism applied to inbound human/bot feedback) and the "feed reviewers raw evidence, not your summary" rule (same principle, applied here from the reviewer side).

After all agents complete (the three core agents, plus Agent 4 when Step 0.2 triggered it), synthesize:

0. **Apply the Step 0.3 gate FIRST**: run every candidate finding through the three-part filter (introduced by this diff? real repro without runtime instrumentation? state exists in prod?) and the final filter ("real user, real data, real client flow?"). Anything that fails moves to a NOTES section labeled `pre-existing` or `theoretical (no real repro)` — it does NOT enter the verdict. This is the difference between an actionable review and noise.
1. **Findings by severity**: BUG (constructed failure path) > RISK (plausible but unconfirmed) > NOTE (observation). Each verdict-level BUG gets a **Repro** block with concrete commands the author can run unchanged.
2. **Cross-agent agreement**: Findings confirmed by multiple agents are higher confidence
3. **What was ruled out and WHY**: For each concern investigated and dismissed, state the specific mechanism that prevents it
4. **What remains uncertain**: Declare what is unknown. Uncertainty is the output, not a failure of the process
5. **Verdict**: APPROVE / APPROVE WITH NOTES / REQUEST CHANGES — with one-line rationale

---

## Recent Improvements (Kaizen)

<!-- Kaizen: 2026-05-12 - User correction -->
- Rule: When reproducing a bug found by this skill in HTTP-facing code (GraphQL resolvers, controllers, middlewares, endpoint-triggered jobs), prefer end-to-end reproduction via Postman/curl/`graphql_post` integration spec BEFORE writing a `rails runner` script that monkey-patches internals.
- Why: Runner + monkey-patch bypasses graphql-ruby resolver execution order, middleware, auth, and per-request shared context — exactly the layers where many real bugs live (e.g. the aliased-`eventsNearby` context-collision bug in ENG-544 only manifests under real GraphQL execution order). Real-request repro is also far stronger evidence in PR review.
- How to apply: After identifying a bug in the verdict, default sequence is (1) reproduce via real request → confirm bug → (2) write failing integration spec → (3) optional runner only for fast iteration during the fix. Runner-only repro is acceptable for purely internal services with no HTTP entry.
- Source: User correction on 2026-05-12 during ENG-544 review. See `memory/feedback_validate_bugs_via_real_request.md`.

<!-- Kaizen: 2026-05-12 - User correction (scope + repro discipline) -->
- Rule: Every finding in the verdict MUST satisfy two conditions: (1) introduced by `git diff develop...HEAD` (not pre-existing in develop), and (2) demonstrable with a real repro (Rails console, Postman/curl, or integration spec) WITHOUT arbitrary code instrumentation (no monkey-patch, no injected raise, no forced rescue, no stub on private methods of `allocate`d types). If a candidate finding fails either condition, demote to a separate NOTES section labeled `pre-existing` or `theoretical (no real repro)` — never include in the main verdict.
- Why: Pre-existing or theoretical findings dilute the real ones and waste the author's time verifying things outside their PR. The review's signal is exactly what THIS branch breaks. Mixing scopes also erodes trust in future reviews.
- How to apply: Step 1 of the workflow (before any agent prompt) is `git diff develop...HEAD` to map the actual change surface. Include the diff stat in every agent's prompt so they know the scope. After agents return, before writing the verdict, run each finding through the two-question filter ("introduced by this diff?" + "real repro without runtime instrumentation?"). Each accepted finding gets a "Repro" subsection with concrete commands the author can run unchanged. Data manipulation (e.g. `facility.update_columns(time_zone: nil)`) is acceptable; runtime code modification is not.
- Source: User correction on 2026-05-12 during ENG-544 review. The "anonymous + schedule" bug I reported was pre-existing in develop — the branch only added a cache-check around the same crash path. Mixing it into the verdict obscured what the branch actually breaks. See `memory/feedback_review_scope_and_real_repro.md`.

<!-- Kaizen: 2026-05-12 - User correction (refinement: prod-state verification) -->
- Refinement to the scope+repro rule: real-data setup (`update_columns`, `destroy_all`, fixture insertion) only counts as a real repro when the fabricated state EXISTS in production. Verify BEFORE fabricating with `mcp__clickhouse__run_query` (`SELECT count() WHERE <condition>`) or by searching Honeybadger for a recurring fault with the same code path. If 0 rows / 0 faults match, the state is impossible in prod and the data manipulation is functionally equivalent to injecting the raise — theoretical, not a finding.
- Companion rule for GraphQL aliased-query findings: only valid if a known client (mobile, web admin, external API) actually emits aliased queries on that field — verify with `grep -rn "<field>:" /Users/leon/workspace/pbp/<client-repo>` for alias syntax (`a: <field>(...)`). A query the reviewer hand-crafts in Postman to force the collision is construction, not observation.
- Final filter every finding must pass: "Does a real user, with real data, in a real client flow, observe this behavior?" — if no, it goes to NOTES at most, never to the verdict.
- Why: Without prod-state verification, the previous "data manipulation IS allowed" wording recreated the same theoretical-finding problem the original rule was designed to prevent. ENG-544 review surfaced 3 findings that all collapsed under this stricter filter.
- Source: User correction on 2026-05-12 during ENG-544 review. See `memory/feedback_review_scope_and_real_repro.md` (updated 2026-05-12).

<!-- Kaizen: 2026-05-25 - Structural improvement (Context7 + platform-needs review) -->
- What changed: (1) Agents now launch as `subagent_type: "Explore"` — read-only, per Context7's official Claude Code subagent guidance ("limit tool access for analysis subagents"); a review must not be able to Edit/Write. (2) The three 2026-05-12 discipline rules (diff-scoping, real-repro without runtime instrumentation, prod-state verification) were elevated from this buried Kaizen log into an operational `## Workflow (Step 0)` that runs before any agent — they are enforcement rules, not history, and were too easy to skip at the bottom. (3) Each of the 3 core agents gained a short **Platform priors** block anchoring it to real incident families (write-path incompleteness/wrong-payer; timezone facility-zone & empty-collection widening; multi-tenancy & sibling enumeration & job idempotency) — hints for *where to look*, kept as a hybrid so the first-principles engine still drives the reasoning. (4) Added a conditional **Agent 4: Destructive-Data Auditor**, launched only when the diff touches migrations/backfills/bulk delete-update/reindex, covering the one failure mode the other three under-weight: irreversible loss/corruption at prod scale (reversibility, resume, atomicity, blast radius, selection correctness, approved scope).
- Why: A review skill with Edit/Write access is a footgun; the discipline rules were proven (ENG-544) but unenforced because of placement; platform's recurring high-stakes bugs (TRI-73, CITYVIEW, CORE-459, CORE-624) are entry-point-agnostic for the 3 agents EXCEPT destructive data ops, which is a distinct class and exactly the kind of change on the branch this review was designed during.
- How to apply: Always run Step 0 first; pass the diff into each agent; launch Agent 4 only on a Step 0.2 match; gate every finding through Step 0.3 before the verdict.
- Source: Self-improvement during a `/orchestrate` skill-review session on 2026-05-25, combining Context7 subagent best practices with the platform failure-mode inventory in auto-memory (`feedback_review_scope_and_real_repro.md`, `feedback_validate_bugs_via_real_request.md`, `feedback_respect_approved_scope.md`, `feedback_interview_the_code.md`, `feedback_visibility_axis_filter.md`).

<!-- Kaizen: 2026-05-26 - User correction (3 missing lenses: empty-boundary, report-consistency, re-run output) -->
- What changed: added three lenses the skill structurally under-tested, folded into the existing agents (no new agent):
  1. **Empty / vacuous-truth boundary** → Boundary Prober prompt items 8-9 + a platform prior. For every collection predicate (`.all?`/`.none?`/`.any?`/`.min`/`.max`/`.sum`), evaluate the EMPTY case explicitly: `[].all?`/`[].none?` are vacuously TRUE, `[].any?` FALSE, `[].min/.max/.first/.last` nil. A guard using `.all?` to mean "fully covered" lets the empty set masquerade as covered — require an `.any?` gate first.
  2. **Report/output consistency as an invariant** → Invariant Auditor prompt item 6 + prior. Operator-facing numbers/summaries/warnings must be mutually consistent and faithful; a contradictory report (planned=0 but per-group populated; spurious warning) is a real defect even with zero data corruption.
  3. **Re-run output idempotency** → Invariant Auditor prompt item 7 + prior. A second run (dry-run twice, execute-then-rerun, restore twice, resume of a completed chunk) must emit correct, non-contradictory numbers — not just idempotent data effects.
- Why: in CORE-624 (PR #4982) three Serena-backed adversarial iterations MISSED Cursor Bugbot's "empty delete set misclassified resume" bug — `resuming_from_backup?` used `to_delete_ids.all?{…}`, vacuously true on `[]`. The passes were framed on the data-SAFETY axis and anchored on "6 prior passes + green e2e" (confirmation/anchoring bias). The gap was the FRAMING, not the iteration count: a 4th safety-axis pass would have missed it again. A static diff-level bot is strong exactly at vacuous-truth/report patterns — complementary to reasoning agents, not redundant.
- How to apply: run all three lenses on every review. After fixing ANY bug, run ONE more targeted pass hunting SIBLINGS of that class across the whole diff (CORE-624 iter4 audited 43+ collection call-sites + 15 report fields + 8 re-run paths → confirmed no siblings before closing). Treat "all green + N prior passes" as a reason to look HARDER at fundamentals, not to relax.
- Source: User correction on 2026-05-26 during CORE-624 PR #4982 review ("por qué si realizaste 3 iteraciones no viste esto, falta un adversarial?"). See `memory/feedback_adversarial_review_missing_lenses.md`.

<!-- Kaizen: 2026-06-05 - User correction -->
- Rule: When dispatching the lenses to review a conclusion, feed each agent the RAW EVIDENCE (original inputs/files/research), not just your distilled summary — plus the attack framing. Seeing the conclusion is fine (creator-verifier design + adversarial framing neutralizes anchoring); the bias that actually leaks is SHARED-PREMISE: with only your summary, reviewers inherit your reading of the facts and can contest only your thesis, not your reading.
- Why: In the obra/superpowers spike, all 3 lenses got the synthesized conclusion but not the two raw research reports → only Boundary Prober partially caught that the conclusion answered a narrower question. The user asked "¿pasarle contexto genera sesgo?"; correct instinct, but the locus was summary-vs-raw, not conclusion-visibility.
- How to apply: Invariant/fact-checker lens → pass explicit claims (objective ground-truth blinds anchoring). Inverter/reasoning lens → conclusion + attack framing + raw inputs. For a load-bearing decision, add a BLIND independent pass (fresh agent concludes from raw inputs without seeing yours) then reconcile.
- Source: User correction on 2026-06-05. See `memory/feedback_review_raw_evidence_not_summary.md`.

<!-- Kaizen: 2026-06-05 - User direction (confirm-loop on findings) -->
- Rule: When this review yields findings, iterate to resolution as a GATED loop, never blind. (1) Gate each finding before acting: real + in-scope (`git diff develop...HEAD`) + reproducible; discard theoretical/out-of-scope. (2) Confirm by finding type — code/logic → reproduce LOCALLY with a failing test; API/lib usage → Context7 (negative result = low-confidence); prod-state/scale → ClickHouse (apply `FINAL` on ReplacingMergeTree + mind replica lag) or Honeybadger. MCP = MANUAL corroboration aids, never automated oracles. ≥2 independent sources on load-bearing claims. (3) Document each CONFIRMED case in `investigations/<ticket>/findings.md` (gitignored). (4) Terminate on 2 consecutive clean passes or a hard cap — not infinite. (5) Autonomy ends at the action gate: auto up to confirmed+documented+fix-proposed; commit/push/destructive/outward stay manually approved.
- Why: a blind "loop until no findings" amplifies false positives (Inverter overshoot; fabricated findings in prior reviews) and can never terminate. The gate + termination + document-confirmed make the loop safe and resumable across compaction.
- Source: User direction on 2026-06-05. See `memory/feedback_confirm_loop_adversarial_findings.md`.

<!-- Kaizen: 2026-06-09 — "Don't trust the report" reviewer stance (adapted from obra/superpowers, MIT) -->
- Added a framing block at the top of the Aggregation section: when verifying a worker's output, read the diff line by line and confirm each claim independently — never defer to the worker's self-reported summary. The worker's summary is an incomplete map; the diff is the territory.
- Why: in prior sessions workers finished "suspiciously fast" or silently narrowed scope and still filed a DONE summary in honest good faith. Without this stance the verifier becomes a rubber stamp on the worker's self-description. Sharpens creator/verifier separation.
- Companion to `feedback_review_raw_evidence_not_summary.md` (reviewer receives raw evidence, not coordinator summary) and the `receiving-code-review` confirm-loop (same skepticism applied inbound).
