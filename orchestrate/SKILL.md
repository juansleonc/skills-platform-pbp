---
name: orchestrate
description: Use when a task spans multiple skills or subagents and needs planning, delegation, quality-gating, and aggregation across a multi-phase pipeline (feature, bug fix, migration, refactor, security/perf hardening). Pure coordinator — never edits files or runs mutating commands itself; dispatches all work to subagents.
allowed-tools: [Agent, Read, Grep, Glob, AskUserQuestion, Skill, Workflow]
disable-model-invocation: false
---

> **Config priority**: `CLAUDE.local.md` overrides `CLAUDE.md`. Check both for current conventions (Docker, linting, coverage).

> **Bundled references** (read on demand — ~0 tokens until opened):
> - Per-phase skill catalog + parallel/sequential rules + context-aware selection → `reference/workflows.md`
> - Visual pipeline (ASCII phase map, subagent + model per phase) → `reference/dependency-graph.md`
> - Status-tracking format + end-to-end example session → `examples.md`
> - Smart-Mode keyword lists + auto-suggest trigger examples → `auto-detection-rules.md`
> - Glob→skill routing (canonical, single source of truth) → **CLAUDE.local.md Auto-Invoke Table (Skill Router)** (`worker`/`validator` auto-load it)

---

## 🧭 Coordinator Contract (READ FIRST — HARD RULES)

`/orchestrate` is a **PURE ADMINISTRATIVE COORDINATOR**. It plans, delegates, gates, and aggregates. It performs **NO real work itself** — ALL code, tests, migrations, reviews, and mutating commands run in **SUBAGENT sessions** via `Agent` (or `Workflow`).

**MAY:**
- **Read** for context: `Read`, `Grep`, `Glob`.
- **Ask the user**: `AskUserQuestion` — grill requirements (Phase 0a), request gate approval.
- **Plan & track**: decompose into phases; keep running status of dispatched vs returned.
- **Dispatch subagents**: `Agent` (`subagent_type: …`), parallel or serial, each passed self-contained context.
- **Delegate stateless fan-out to `Workflow`**: deterministic multi-agent pipelines for headless/stateless phases (Phase 1A/1B analysts, Phase 3 quality, adversarial find→verify). A `Workflow` call is VALID delegation — its agents run in their own sessions and do the editing/analysis there, exactly like `Agent`. The coordinator never touches files regardless.
- **Invoke ONLY these non-mutating skills in-thread** via `Skill`: `/grill-me`, `/brainstorm`, `/learning` (they interview the user; never touch project code).
  - **One controlled exception — `/receiving-code-review` (triage phase only)**: in-thread to gather inbound PR/bot feedback and run the read-only confirm-loop gate (Read/Grep/Glob/`AskUserQuestion`). Tool-safe by construction (no `Edit`/`Write`/`Bash` here), so the skill's **implement** phase MUST be delegated to a `worker` via `/tdd`, one confirmed item at a time. Stop at the gated CONFIRMED list; never implement in-thread.

**MUST NEVER:**
- ❌ Edit, Write, or create any project file (no `Edit`/`Write` granted).
- ❌ Run any mutating shell command — no `git add/commit/push`, `rm`, `mv`, `mkdir`, `bundle`, `rspec`, `rake`, migrations, Docker runs. It has **no `Bash`** at all.
- ❌ Invoke an IMPLEMENTATION skill in-thread via `Skill` (`/tdd`, `/coverage`, `/architect`, `/code-review`, `/performance`, `/migration`, `/security`, domain validators). `Skill` runs in THIS conversation with THIS context and could edit files here — that violates the contract. **Delegate them through `Agent`.**
- ❌ Apply its own Kaizen edits directly — delegate to a `worker` (see Kaizen section).
- ❌ Commit or push without explicit user approval (see Critical Rules).
- ❌ Put INTERACTIVE phases (grill-me, validator Gate 3.5, publish y/n) inside a `Workflow` call — `Workflow` runs HEADLESS (no `AskUserQuestion`, cannot gate on human input mid-run). The interactive/gated SPINE always stays in the coordinator's foreground.

**Why delegation, not main-thread skills**: a `Skill` invocation runs in the **main thread** (inherits this session's tools/context); an `Agent` (or `Workflow`-spawned agent) runs in a **separate session** with its own tools/context. All delegation modes guarantee "coordinator never touches files" — the worker does the editing in its own session and returns a result. This is also the **creator/verifier separation**: the agent that writes code is never the agent that validates it.

> If you ever feel the urge to "just make this one edit" — STOP. Dispatch a worker.

---

## ⛔ Critical Rules

**NEVER execute `git commit` or `git push` without explicit user approval.** Before ANY git op that modifies history/remote:
1. Show a summary of what will be committed/pushed.
2. Ask explicitly: "Ready to commit and push. Proceed? (y/n)"
3. **WAIT** for "y"/"yes".
4. Only then dispatch a worker to run the git commands.

Applies to ALL workflows, including Phase 4: Publish.

---

## MCP Tools & ast-grep (Manual Research Only — never automated)

**Binding rule**: this orchestrator does NOT automate MCP. Official MCP servers (Context7 docs, ClickHouse production data, Honeybadger faults) are **optional manual research aids** — every skill works WITHOUT them. Never wire them into an automated batch step. (Rationale: automated MCP analysis measured -88% ROI / 86% false negatives; manual grep-based validation is instant and reliable.) Serena MCP removed 2026-06-02 (backup: `investigations/serena-mcp-block.bak.json`).

**ast-grep** (`brew install ast-grep`, optional, per-developer): when `sg` is on PATH, AST-pattern matching beats grep for real `Time.now` / `can :action, Model` / `perform_async(payment.id)` (no comment/string false positives). Used via `Bash` inside subagents (`sg run --lang ruby --pattern '…'`), with a `command -v sg` fallback; does NOT help dynamic dispatch (`constantize`/`send`). Detail: `.claude/skills/shared/ast-grep-patterns.md`.

---

## Philosophy

> "Maximize parallelism, minimize wait time, ensure quality — by delegating, never doing."

This skill is the **default entry point** for any complex task. It intelligently selects skills and **dispatches them to subagents** based on task type. The coordinator reads, plans, gates, aggregates; the subagents do the work.

## 🔴 Auto-Detection (Smart Mode)

Orchestrate auto-suggests itself on feature/refactor requests. Before responding to ANY message, check in order:
1. **Explicit command** (`/orchestrate`, "orchestrate this", "run full workflow") → execute immediately.
2. **Skip keyword** (question `¿`/`?`, read/show/lee, explain/explica, thanks/ok, search/busca) → respond directly, zero overhead.
3. **Feature keyword** (implementa/agrega/crea/add/feature, refactor/mejora, migration, payment/membership/RBAC/permissions, API/GraphQL/endpoint/mutation, fix bug completo/arregla) → suggest orchestrate, ask `y/n`.
4. **Default** → respond directly.

Detail (full keyword lists + worked auto-suggest examples): `auto-detection-rules.md`.

---

## 📓 Orchestration Thread Log (ALWAYS — keep the thread)

The coordinator keeps a running, append-only ledger at `investigations/<TICKET>/orchestration-log.md` — so the thread survives compaction and any fresh session can resume without re-deriving. COMPLEMENTS the RPI artifacts (`understanding.md` / `<feature>-design.md` / `findings.md`); does not replace them.

**The coordinator never writes it itself** (no `Edit`/`Write` — see `memory/feedback_coordinator_delegates_all_work`). It is written by subagents:
- **Phases with a writing subagent** (a `worker` doing seed/TDD/quality): the worker appends its own structured entry as the LAST step of its task (the dispatch template's RETURN instructs this).
- **Boundaries with no writing subagent** (read-only `Explore` analysis phases; every GATE decision incl. the read-only `validator` gate): the coordinator dispatches a brief **micro-worker** ("append this entry verbatim to `orchestration-log.md`: …"). `Explore`/`validator` are read-only and cannot append.

**Cadence**: one entry per PHASE boundary and per GATE — never per micro-action, never a raw tool dump.

**Content bar — clear + concise, nothing key lost.** Each entry records: the decision(s) + one-line WHY; the validation contracts when emitted (C1..Cn); per subagent, the LOAD-BEARING result only; the gate verdict + reason; open risks / NEEDS_CONTEXT / next phase. Omit tool dumps, prompt restatement, play-by-play. **Test:** *could a brand-new session read only this log and pick up exactly where we are?*

**Entry template** (append-only):
```markdown
### <Phase / Gate> — <one-line outcome>   (<phase id: 0a / 0b / 1A / 2 / 3.5 / 3 / 4>)
- Dispatched: <subagent_type + skill> ×N
- Key results: <load-bearing facts / decisions + one-line why>
- Gate: PASS | FAIL — <reason>   (omit line if this boundary is not a gate)
- Open / next: <pending risk · NEEDS_CONTEXT · next phase>
```

The seeded log opens with a header (ticket, one-line task, validation contracts C1..Cn, empty ledger) that entries append under.

### Checkpoint + Clear

When the log contains ≥5 THREAD LOG entries, MUST checkpoint:
1. Dispatch a micro-worker: "Append to orchestration-log.md: `### CHECKPOINT — context reset (phase count N)\n- Done: …\n- Next phase: …\n- Open risks: …`"
2. Inform the user: "Context pressure reached. Starting fresh session from log."
3. The next session: read orchestration-log.md first, then continue from the last Open/next entry.

The log IS the tattoo. Clearing the conversation context is safe as long as the log is current.

---

## 🗂️ Step 0: Check Investigations Folder (ALWAYS — Before Any Work)

BEFORE any ticket work (feature, fix, refactor), check for prior research: extract the ticket ID (branch or message, e.g. `CORE-189`) and `ls investigations/<TICKET>/`.

**If folder exists** → **READ EVERYTHING IN IT FIRST** (typical: `patch-integration-reference.md` domain guide, `skill-qa-audit-*.md` prior findings, `tmp_test_*.rb` scripts). Why: during CORE-189 a full reference guide, QA audit, and test scripts already existed — re-creating them would have wasted 2+ hours.

**If folder is empty/missing** → the coordinator does NOT create it (no mutating commands). The first dispatched **worker** seeds it from the **RPI template** in its own session, then writes into the seeded files; the coordinator only reads them. RPI = Research / Plan / Implement ("No Vibes Allowed", Dex Horthy): legible intermediate artifacts, align on architecture **before** code. Worker's first action when empty:
```bash
mkdir -p investigations/<TICKET>
cp investigations/_RPI-TEMPLATE.md investigations/<TICKET>/understanding.md
# STATUS: ACTIVE is pre-set at line 1; update to CLOSED when ticket is merged or parked.
# also seed orchestration-log.md with a header (ticket, task, contracts, empty ledger)
# strip to Phase 1 (Research); split Phase 2 → <feature>-design.md; Phase 3 → findings.md
```

**RPI → phase mapping** (seeded artifacts feed the pipeline):

| RPI phase | Seeded artifact | Drives orchestrate phase |
|---|---|---|
| **Research** | `understanding.md` | Phase 0b `/architect` (+ `Explore`) — system map, write-paths, live-data grounding |
| **Plan** | `<feature>-design.md` (ADR) | Phase 0b `/architect` + `/migration` + `/performance` — files+lines, test strategy, alternatives |
| **Implement** | code + `seed_*.rb`/`verify_*.rb` + `findings.md` | Phase 2 `/tdd` → Gate 3.5 validator — RED/GREEN/REFACTOR, residual risk |

The **grill-me** contracts (Phase 0a) belong in `validation-contracts.md` (→ the Plan's "Test strategy" row). Heavier features (>1 day, customer-facing, compliance) → promote Plan into OpenSpec (`/opsx:new`) per the CLAUDE.local.md decision algorithm. **Zero cost** if empty (one `cp`); **huge save** if research exists.

---

## Available Skills & Execution Rules

> The full per-phase skill catalog, the parallel-execution rules, the sequential-dependency table, and the context-aware selection tables live in **`reference/workflows.md`**.
> The visual pipeline (ASCII map of every phase + subagent type + pinned model) lives in **`reference/dependency-graph.md`**.
> **Glob→skill routing is canonical in the CLAUDE.local.md Auto-Invoke Table (Skill Router)** — `worker`/`validator` agents auto-load it; the coordinator must consult it when composing every dispatch prompt. Not duplicated here.

**Execution-locus shorthand** (which agent runs a skill): 🟣 coordinator-direct = `/grill-me`, `/brainstorm`, `/learning` · 🟢 worker (edits) = `/tdd`, `/coverage`, `/migration`, `/sidekiq`, `/commit` · 🔵 validator = `/adversarial-review`, `/code-review` · 🔎 Explore (read-only) = `/timezone`, `/packwerk`, `/security`, `/graphql`, `/multi-tenancy`, `/performance`, domain validators. Split-locus = `/receiving-code-review` (🟣 triage → 🟢 worker via `/tdd`).

---

## Delegation Protocol (HOW the coordinator dispatches)

Every phase is a subagent dispatch via `Agent`. The coordinator composes the prompt, launches the agent(s), gates on the returned result.

> **Tool naming**: the primitive is the **`Agent`** tool with a `subagent_type` arg. Older docs say "Task tool" — same thing.
> **Effectively one level deep here**: nesting subagents IS supported by the harness (when an agent is granted the `Agent` tool, up to depth 5), but our dispatched agents (worker/validator/architect/Explore) are NOT granted `Agent`, so in this setup they cannot spawn further subagents; and `AskUserQuestion` is never available inside any subagent (harness restriction). Consequences: grill-me is coordinator-direct; `code-simplifier` is a coordinator-dispatched phase (a worker can't call it).
> **Separate context windows**: each subagent runs in its OWN context (it does NOT see this conversation; only its final result returns). Every dispatch prompt must be **self-contained**. Caveat: **`worker`/`validator` auto-load `CLAUDE.md` + `CLAUDE.local.md`** (conventions + Auto-Invoke Table already present), but **`Explore`/`Plan` skip them** — so an `Explore` prompt must explicitly name the skill/convention to apply.

### Dispatch mode: three primitives

**Default = foreground `Agent`.** Dispatch every phase in the foreground. Foreground is already parallel — launch N independent agents as **multiple `Agent` calls in ONE message** (e.g. the 4 read-only analysts of Phase 1A). Foreground agents render inline (`ctrl+o` to expand) and return synchronously, keeping every **gate trivial and reliable** — exactly what the dependency chain (grill → architect → impl → validator → quality) needs.

**Escalate to background `Agent`** (`run_in_background: true`, or `ctrl+b` on a running one) ONLY when: (1) a worker is expected to be **long** (large slice), or (2) **fan-out across multiple independent surfaces** (vertical-slice DAG) you want on the dashboard.

**Use `Workflow` for STATELESS FAN-OUT** phases — entirely headless + stateless (parallel read-only analysis 1A/1B, parallel quality 3, adversarial find→verify). It provides deterministic execution, journaled crash-resume, schema-validated structured output, and a concurrency cap. NOT mandatory — use `Agent` when fan-out is small or you want inline visibility; use `Workflow` when fan-out is large enough that journaling + structured output pay off.

**NEVER put the interactive/gated SPINE into a `Workflow`** (grill-me, validator Gate 3.5, publish y/n). It runs headless with no `AskUserQuestion` — that would silently skip the human check.

> Foreground subagents are NOT missing — they render inline ("Running 4 agents…"); they just don't show in the cross-session jobs dashboard unless backgrounded.

### Phase → subagent_type

| Phase | What runs | `subagent_type` | Model | Mode | Workflow-eligible? |
|-------|-----------|-----------------|-------|------|--------------------|
| 0 Ideation (unformed) | `/brainstorm` diverge → pick direction | **coordinator-direct** (`Skill` + `AskUserQuestion`) | session model | serial, interactive | ❌ needs `AskUserQuestion` |
| 0a Grill (fuzzy) | `/grill-me` → contracts | **coordinator-direct** (`Skill` + `AskUserQuestion`) | session model | serial, interactive | ❌ needs `AskUserQuestion` |
| 0b Architecture | `/architect` design + location | **`architect`** | opus (pinned — planning is the quality phase) | serial, **fg** | ❌ serial, gated |
| 1A/1B Analysis | timezone, packwerk, security, graphql, multi-tenancy, pci, gateway, migration | `Explore` (read-only) | `model: "sonnet"` (pattern-scan) | **parallel fg** | ✅ delegate to `Workflow` when fan-out ≥ 4 + journaled output worthwhile |
| 2 Implementation | `/tdd` RED→GREEN→REFACTOR | **`worker`** | sonnet (pinned); **escalate to `opus`** after 2 validator REQUEST CHANGES on same contract | serial, **fg** (→ bg if long / multi-surface) | ❌ serial, gated by 3.5 |
| 3.5 Validator GATE | `/adversarial-review` or `/code-review` vs contracts | **`validator`** (≠ worker session) | opus (pinned — adversarial verification = highest-leverage spend) | serial, **blocking, fg** | ❌ blocking gate |
| 3 Quality | coverage, pronto, performance, code-simplifier | `worker` (edits) / `Explore` (read-only) | sonnet | **parallel fg** | ✅ structured aggregation + journaled resume |
| 4 Publish | commit → PR (`/create-pr` — personal skill) | **`worker`**, only after `y/n` | sonnet | serial, **fg** | ❌ gated on user `y/n` |

> **Adversarial find→verify pipeline**: each `/adversarial-review` lens is stateless + headless → ✅ Workflow-eligible; the coordinator still reads the aggregated verdict before gating.
> **Skill Router coupling inside Workflow agents**: per-agent prompts written into a workflow script MUST still name the mandatory skills from the CLAUDE.local.md Auto-Invoke Table matching the globs/packs they touch — same rule as plain `Agent` dispatch.
> **Model routing — model follows the TASK NATURE, not the subagent_type.** Pattern-scan (timezone/packwerk/factory-check) → sonnet. Reasoning-heavy (design, adversarial failure construction, contract verification) → opus. Same `Explore` type runs sonnet for 1A scans but opus for `/adversarial-review` lenses. Worker escalation: validator REQUEST CHANGES twice on one contract → re-dispatch worker with `model: "opus"`.

**code-simplifier**: a coordinator-dispatched phase (`Agent subagent_type="code-simplifier"`) after the worker / during Quality — NOT worker-triggered (workers can't spawn subagents). Optimize test files after TDD; production code during Quality.

### Reusable dispatch template

```
Agent — subagent_type: "<architect | worker | validator | Explore | Plan>"
prompt:
  ROLE: <Worker | Validator | Analyst> for <phase>.
  TASK: <one-sentence goal>.
  SKILL TO FOLLOW: follow `/<skill>` end to end (read its SKILL.md first).
    Apply CLAUDE.local.md conventions (bin/d Docker, TDD, timezone, multi-tenancy, factories).
  CONTEXT:
    - Ticket / scope: …
    - Validation contracts (MUST hold): C1…Cn  (paste grill-me assertions)
    - Relevant files / globs: …    - Prior research: investigations/<TICKET>/ (read first)
    - Diff scope (review): git diff develop...HEAD
  CONSTRAINTS:
    - Worker: implement only what the contracts require; tests FIRST (RED→GREEN).
    - Validator: you did NOT write this code; try to BREAK it; per contract → PASS/FAIL + evidence.
  RETURN (structured): what you did/found by file · per-contract PASS/FAIL · test/lint/coverage · open risks · STATUS: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT.
    - NEEDS_CONTEXT: subagent hit genuine ambiguity it CANNOT resolve alone (no AskUserQuestion inside a subagent — one level deep). Coordinator answers and re-dispatches rather than the worker guessing.
    - THREAD LOG: as your FINAL step, append your structured entry (Phase/Gate · dispatched · key results · gate verdict · open/next) to investigations/<TICKET>/orchestration-log.md — clear + concise, load-bearing facts only, no tool dumps. (Read-only Explore/validator agents cannot write; the coordinator dispatches a micro-worker for those boundaries.)
```

> **Before composing any prompt**, consult the CLAUDE.local.md **Auto-Invoke Table (Skill Router)** and name every mandatory skill matching the globs/packs the subagent will touch.

---

## Agent vs Workflow: HARD RULE

Two delegation primitives. The interactive/gated SPINE always uses `Agent` (foreground); stateless fan-out phases may use either, with `Workflow` preferable as fan-out grows.

| Dimension | Model-driven `Agent` | Deterministic `Workflow` |
|-----------|----------------------|--------------------------|
| Execution | Free-form reasoning | JS script: `phase()`, `agent()`, `parallel()`, loops |
| Output | Free-text (coordinator parses) | Schema-validated structured |
| Resume on crash | None — re-dispatch | Journaled — resumes from last phase |
| Human input mid-run | Via `AskUserQuestion` | ❌ IMPOSSIBLE — headless |
| Concurrency cap | Manual batch size | Built-in |
| Best for | Any phase; esp. interactive/gated | Stateless fan-out, many parallel agents |

### HARD RULE — the interactive spine NEVER runs inside a Workflow

These MUST stay in the coordinator's foreground as plain `Agent`/`Skill` calls — never a `Workflow`:
- **Phase 0a `/grill-me`** — needs `AskUserQuestion` to interrogate until ambiguity = 0; headless would silently skip the interview.
- **Gate 3.5 Validator** — the coordinator must read the PASS/FAIL verdict synchronously before looping or advancing; a headless pipeline can't gate on coordinator judgment.
- **Phase 4 Publish y/n** — needs explicit user approval before any git op; a headless background Workflow could never wait for it.

Violating this silently drops human-oversight checks — the most dangerous failure mode for a pure coordinator.

**Delegate to `Workflow` only when ALL hold**: (1) **stateless** (no `AskUserQuestion` within the run), (2) **headless** (read-only analysts or quality workers, no human decision to block on), (3) **fan-out benefit** (≥ 4 independent parallel agents AND structured/journaled output clearly pays off). If any fails, keep the phase as a batch of foreground `Agent` calls. Eligible phases: 1A/1B Analysis, 3 Quality, adversarial find→verify. (Skill Router coupling inside the workflow script is unchanged — per-agent prompts still name every mandatory skill.)

---

## Orchestration Workflows

> All workflows run through the Delegation Protocol — the bullets name *what* runs per phase; the coordinator executes each as an `Agent` dispatch (read-only → `Explore`; implementation → `worker`; verification → `validator`), never in-thread. **Code-producing** workflows (1 Feature, 2 Bug Fix, 3 Membership, 5 API, 10 Refactor, 11 Security, 12 Performance) imply two phases: **Phase 0a `/grill-me`** if the spec is fuzzy, and the blocking **Validator gate (3.5)** between implementation and quality. Read-only workflows (6 Debug, 7 Code Review, 8 Pre-commit, 9 Coverage) skip the validator gate unless they produce a code change.

Each workflow is a **named entry point** selecting a starting subset of phases from the dependency graph (`reference/dependency-graph.md`); per-phase subagent/model detail is in `reference/workflows.md`. One line per workflow:

- **1. Feature** (`/orchestrate feature`) — grill-me → architect → 1A/1B → TDD → **validator gate** → quality → publish (full pipeline).
- **2. Bug Fix** (`/orchestrate fix <issue>`) — **debug → fix-issue** (root-cause first) → domain checks → TDD (failing test reproducing the bug first) → **validator gate** → quality.
- **3. Membership** (`/orchestrate membership`) — `/memberships` analysis → parallel sidekiq/performance/multi-tenancy → TDD (cover every type: weekly/monthly) → **validator gate** → quality.
- **4. Migration** (`/orchestrate migration`) — `/migration` safety/rollback/index → parallel performance + packwerk (table-naming) → TDD up/down. No publish implied; gate if it produces code.
- **5. API** (`/orchestrate api`) — `/graphql` backward-compat → parallel performance/security/multi-tenancy → TDD (request specs) → **validator gate** → quality.
- **6. Debug** (`/orchestrate debug <error>`) — parallel context-gather (Honeybadger/ClickHouse/code search) → root-cause → reproduction script → report. **Read-only: no validator gate** unless it produces a fix.
- **7. Code Review** (`/orchestrate code-review`) — parallel 1A → parallel 1B → deep `/code-review` + code-simplifier. **Read-only: no validator gate.**
- **8. Pre-Commit** (`/orchestrate pre-commit`) — parallel checks (rspec/coverage/pronto via worker; timezone/security/graphql via Explore) → **GATE: all-pass → y/n → worker commits; any fail → STOP.**
- **9. Coverage** (`/orchestrate coverage`) — `/coverage` finds uncovered → up to 3 parallel spec-writing workers (write→validate→run per file) → verify 100%. **No validator gate.**
- **10. Refactor** (`/orchestrate refactor`) — parallel code-review/performance/multi-tenancy → architect plans → TDD (add tests → refactor → stay green) → **validator gate** → quality.
- **11. Security Hardening** (`/orchestrate security-hardening`) — parallel security/pci-compliance/multi-tenancy → production verification (manual ClickHouse data-exposure check) → TDD security tests → **validator gate** → re-run security + final review.
- **12. Performance** (`/orchestrate performance-optimize`) — parallel performance + optional ClickHouse/Honeybadger → prioritize by impact → TDD benchmark tests → **validator gate** → re-verify.
- **13. Kaizen** (`/orchestrate kaizen` or `/kaizen`) — 5-phase skill-maintenance loop: Analyze → Evaluate → Improve → Validate → Document. Manual only; coordinator delegates the actual edits to a worker (see Kaizen section).

> **Parallel = multiple `Agent` calls in one batch** (one message, multiple tool uses) so they run concurrently. See the dispatch template above.

---

## Phase Gates (CHECKLIST — pass criteria are blocking)

Run each gate in order. A gate's **Fail** branch is mandatory — do not advance until **Pass**.

- [ ] **Gate 0 — Ideation** (Phase 0, unformed specs only; ran `/brainstorm`).
  - **Pass**: a single direction chosen (rejected alternatives + why noted); any multi-subsystem request decomposed.
  - **Fail**: keep diverging/decomposing — do NOT dispatch grill-me with the option space open.
  - **Skip**: approach already known → go to Gate 0a.
- [ ] **Gate 0a — Grill** (Phase 0a, fuzzy specs only; ran `/grill-me`).
  - **Pass**: ambiguity = 0 AND validation contracts C1..Cn emitted and confirmed by the user.
  - **Fail**: keep grilling — do NOT dispatch architect/worker with unresolved branches.
- [ ] **Gate 1 — Static Analysis** (Phase 1A; all Explore analysts returned).
  - **Pass**: no critical violations (timezone, security, graphql, packwerk).
  - **Fail**: STOP and report violations.
- [ ] **Gate 2 — Domain Analysis** (Phase 1B; domain analysts returned).
  - **Pass**: domain rules validated.
  - **Fail**: STOP on domain violations (e.g. PCI failure).
- [ ] **Gate 3 — TDD** (Phase 2; `worker` reported complete).
  - **Pass**: tests green, code implemented in the worker's session.
  - **Fail**: re-dispatch worker with the failure.
- [ ] **Gate 3.5 — VALIDATOR** (Phase 3.5 — **BLOCKING, independent agent ≠ worker**; verified the diff vs contracts).
  - **Pass**: every contract C1..Cn → PASS with evidence; verdict APPROVE / APPROVE WITH NOTES.
  - **Fail (REQUEST CHANGES)**: loop back to a **fresh** `worker` with the findings, then re-run a **fresh** `validator`. Never let the worker self-verify. Quality does not start until this passes.
- [ ] **Gate 4 — Code Validation** (Phase 2.5; implementation-detail analysts returned).
  - **Pass**: patterns correct (sidekiq, performance, multi-tenancy, action-policy).
  - **Fail**: re-dispatch worker to fix; re-run validator if behavior changed.
- [ ] **Gate 5 — Quality** (Phase 3; **precondition: Gate 3.5 passed**). REQUIRED CHECKS, each a dispatched subagent:
  - Tests: all specs passing · Coverage: 100% on changed lines (patch) · Coverage: global % not decreased · Pronto: no lint violations on changes · Brakeman: no security warnings · Domain: relevant analysts passed.
  - **Fail (any)**: report all failures → re-dispatch a worker to fix → re-run failed checks (and validator if behavior changed) → DO NOT proceed to publish.
  - **Pass (all)**: ask the user "Ready to commit and push? (y/n)" → wait for explicit approval → dispatch a worker to run commit→PR (coordinator runs no git).
- [ ] **Gate 6 — Publish** (Phase 4; only after all gates pass AND user approved `y/n`).
  - **Pass**: worker created commit + PR; returns SHA + PR URL.

> **Status-tracking report format + an end-to-end example session** → `examples.md`.

---

## Best Practices

1. **Never do the work — dispatch it**: read, plan, gate, aggregate. Edits/tests/commits happen in subagent sessions only.
2. **Separate creator from verifier**: the `validator` is always a different session than the `worker`. On a re-loop, both are fresh sessions.
3. **Maximize parallelism**: launch independent analysts as one batch of `Agent` calls.
4. **Fail fast**: stop at the first critical gate failure; re-dispatch a worker rather than patching in-thread.
5. **Clear dependencies**: never parallelize dependent phases (grill → architect → impl → validator → quality).
6. **Name the skills**: every dispatch prompt names the skill(s) + the validation contracts + the Skill Router matches.
7. **Report clearly**: summarize what was dispatched and what each subagent returned at each phase.

---

## Meta-Skills (Manual Only)

`/kaizen` and `/skill-creator` are **manual only** — no automatic triggers. Use `/skill-creator` on repeated manual work (3+ times same pattern on real code) worth automating; use `/kaizen <skill-name>` (or `/kaizen` for a full audit) when a skill fails repeatedly, could be more efficient, or has unclear docs. No overhead — the user decides when to analyze. (Glob→skill routing remains canonical in the CLAUDE.local.md Auto-Invoke Table.)

---

## Kaizen: Continuous Improvement

> "Every day we must improve" — 改善

**While executing this skill**, if you discover a new parallel-execution opportunity, a missing dependency, or a better workflow — **you MUST** (the coordinator cannot edit files; it delegates its own Kaizen edits):
1. Complete the current orchestration first.
2. Draft the Kaizen entry text (format: `<!-- Kaizen: YYYY-MM-DD --> …`).
3. Dispatch a worker: `Agent subagent_type="worker"`, prompt: "Append this Kaizen entry verbatim to the end of `.claude/skills/orchestrate/SKILL.md` (do not modify anything else):\n<entry>".
4. Confirm the worker reported success.

**Recent Improvements:**

<!-- Older Kaizen history archived to kaizen_log.md -->

<!-- Kaizen: 2026-06-14 - Progressive-disclosure optimization (Anthropic Agent Skills best-practices) -->
- What: Restructured SKILL.md into a lean "table of contents + decision core" (body 889 → <500 lines) per Anthropic's official Agent Skills progressive-disclosure guidance. RELOCATED (verbatim, ~0-token-until-read) to bundled files: the Status-Tracking example + Example Session → `examples.md`; the per-phase "Available Skills" tables + Parallel Execution Rules + Context-Aware Selection → `reference/workflows.md` (with a ToC); the Master Dependency Graph ASCII map → `reference/dependency-graph.md`. DE-DUPLICATED: the "Available Skills" / "Parallel Execution Rules" / "Meta-Skills" sections no longer restate the glob→skill router — they point to the canonical CLAUDE.local.md Auto-Invoke Table (Skill Router) that `worker`/`validator` already auto-load. DENSIFIED in place: "MCP Tools Philosophy" (46 lines → the binding rule + brief ast-grep note), the Coordinator Contract (kept every MAY/MUST-NEVER/file-touch/Workflow-spine rule as terse imperatives, trimmed rationale prose), Auto-Detection (the -overhead detail moved to `auto-detection-rules.md`). Folded the "Quality Gate Pattern" ASCII box INTO the Phase Gates section. Converted Phase Gates (0..6) into a blocking CHECKLIST.
- Why: orchestrate is the most-frequently-loaded skill in the repo; every token in its Level-2 body is paid on every load. Anthropic's guidance: "challenge every token; Claude already knows X" and keep the body under ~500 lines, relocating reference/example material to bundled Level-3 files that cost nothing until read. Zero capability or information was removed — content was relocated, densified, or de-duplicated to a single source of truth.
- How to apply: edit the decision core (Coordinator Contract, Delegation Protocol, Phase Gates, Thread Log, HARD RULE) in the body; edit the catalog/parallel rules in `reference/workflows.md`; edit the visual map in `reference/dependency-graph.md`; edit examples in `examples.md`. Keep references ONE level deep (keep every bundled file linked directly from the body).

<!-- Kaizen: 2026-06-13 - Adopt the Workflow tool (hybrid) -->
- What: Adopted the `Workflow` tool in a HYBRID model alongside the existing `Agent`-based delegation. Added `Workflow` to `allowed-tools`. Added the "Agent vs Workflow" section (comparison table, HARD RULE on the interactive spine, 3-condition delegation criterion). Added a "Workflow-eligible?" column to the Phase → subagent_type table. Named all three dispatch primitives: foreground Agent (spine + small fan-out), background Agent (long workers / multi-surface), Workflow (stateless fan-out). Added Workflow clarifications to the Coordinator Contract (MAY list + a MUST-NEVER bullet for the interactive spine) and the Skill Router coupling note inside Workflow scripts.
- Why: the harness now ships a `Workflow` tool — deterministic JS-script orchestration with `phase()`/`agent()`/`parallel()`, schema-validated output, journaled resume. For the stateless fan-out phases (1A/1B analysts, 3 quality, adversarial lens pipeline) it offers structured aggregation + crash-resume the manual batch lacks. The interactive/gated spine stays foreground Agent because Workflow runs headless — silently dropping human-input gates is the most dangerous failure for a pure coordinator.

<!-- Kaizen: 2026-06-13 - Add /brainstorm as divergent Phase 0 (ported from obra/superpowers) -->
- What: Added `/brainstorm` (`.claude/skills/brainstorm/`) as the **divergent** counterpart to `/grill-me`, wired as optional **Phase 0 — Ideation** (coordinator-direct, before Phase 0a). Flow: brainstorm (diverge → pick a direction) → grill-me (converge → contracts) → architect (design) → tdd.
- Why: the ecosystem had only convergent front-ends. Nothing generated genuinely distinct options when the WHAT/HOW was still open. /brainstorm fills that gap (decompose multi-subsystem requests, generate 2-3+ approaches, compare trade-offs, choose).
- How to apply: use `/brainstorm` ONLY when the spec is *unformed*; if the approach is known, skip to `/grill-me`. Coordinator-direct (requires AskUserQuestion).

<!-- Kaizen: 2026-06-13 - User direction (orchestration thread log) -->
- Rule: the coordinator keeps a running append-only ledger at `investigations/<TICKET>/orchestration-log.md`, updated at every phase boundary and gate (not micro-actions). Complements the RPI artifacts. Clear + concise but enough that a compacted/fresh session resumes from the log alone (resume-from-log test).
- Mechanism: each phase-worker appends its own structured entry; for read-only Explore phases and gate decisions (incl. the read-only validator), the coordinator dispatches a micro-worker to append. Coordinator never writes it (see `memory/feedback_coordinator_delegates_all_work`).
- Added: "📓 Orchestration Thread Log" section + entry template; Step 0 seeds the log; the dispatch-template RETURN tells workers to append their entry.
- Source: User direction on 2026-06-13. See `memory/feedback_orchestrator_thread_log.md`.

<!-- Kaizen: 2026-06-15 - User correction (personal adoptions go in CLAUDE.local.md) -->
- Rule: when a `/orchestrate` run ADOPTS something from a personal spike/experiment (a convention, rule, or doc), it defaults to `CLAUDE.local.md` (or other gitignored locations: `investigations/`, `.claude/`) — NEVER committed team files. The committed surface is not only `docs/`: **`CLAUDE.md` itself is team-committed too.** Promote to `CLAUDE.md`/`docs/` ONLY when it is an agreed team standard.
- Why: writing a personal experiment into committed team config imposes it on the whole team prematurely and pollutes shared config; `CLAUDE.local.md` is the personal override surface (gitignored).
- How to apply: before composing the dispatch prompt for any "persist/adopt" step, classify team-shared vs personal and run `git check-ignore <path>`; for personal adoptions point the worker at `CLAUDE.local.md`, not `CLAUDE.md`/`docs/`. 2nd occurrence of this mistake (also 2026-05-25) → systemic, check every time.
- Source: User correction on 2026-06-15 (ponytail spike adoption). See `memory/feedback_personal_files_excluded_location.md`.

<!-- Kaizen: 2026-06-19 - User correction (use personal /create-pr, not pbp) -->
- Rule: Phase 4 Publish and any "Crear PR" step MUST dispatch the worker pointing at the personal `/create-pr` skill, NEVER `pbp-code-review:pr-create`. Prefer the personal skill over the pbp equivalent when both cover the same phase.
- Why: `/create-pr` encodes the user's PR conventions (Background/Attention/Reference template, `--assignee` + `--label "ready for review"`, base develop). Routing through pbp produced the wrong body format and dropped assignee/label.
- How to apply: in the Publish dispatch prompt, name `/create-pr` as the skill to follow. Root cause was the CLAUDE.local.md Auto-Invoke Table "Crear PR" row listing pbp first (now fixed).
- Source: User correction on 2026-06-19 (CORE-815 / PR #5235). See `~/.claude/projects/-Users-leon-workspace-pbp-platform/memory/feedback_use_personal_create_pr_skill.md`.
