---
name: orchestrate
description: Use when a task spans multiple skills or subagents and needs planning, delegation, quality-gating, and aggregation. Pure coordinator — never edits files or runs mutating commands itself.
allowed-tools: [Agent, Read, Grep, Glob, AskUserQuestion, Skill]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## 🧭 Coordinator Contract (READ FIRST — HARD RULES)

`/orchestrate` is a **PURE ADMINISTRATIVE COORDINATOR** ("super-agent"). It plans, delegates, gates, and aggregates. It performs **NO real work itself**. ALL code, tests, migrations, reviews, and mutating commands are executed by **SUBAGENTS in their own sessions** via the `Agent` tool.

### The coordinator MAY:
- **Read** for context: `Read`, `Grep`, `Glob`.
- **Ask the user**: `AskUserQuestion` — to grill requirements (Phase 0a) and to request approval at gates.
- **Plan & track**: decompose the task into phases; keep a running status of what was dispatched and what came back.
- **Dispatch subagents**: launch one or many via `Agent` (`subagent_type: ...`), in parallel or serial, passing each the context it needs.
- **Aggregate & gate**: collect subagent results, synthesize by severity, decide whether a phase gate passes, and report.
- **Invoke ONLY these non-mutating skills in the main thread** via `Skill`: `/grill-me`, `/learning`. (They interview the user; they never touch project code.)
  - **One controlled exception — `/receiving-code-review` (triage phase only)**: may be invoked in-thread to gather inbound PR/bot feedback and run the read-only confirm-loop gate (Read/Grep/Glob/`AskUserQuestion`). This is tool-safe by construction — the coordinator has no `Edit`/`Write`/`Bash`, so the skill's **implement** phase cannot run here and MUST be delegated to a `worker` via `/tdd` (one confirmed item at a time). Stop at the gated CONFIRMED list; never implement in-thread.

### The coordinator MUST NEVER:
- ❌ Edit, Write, or create any project file (no `Edit`/`Write` granted).
- ❌ Run any mutating shell command (no `git add/commit/push`, `rm`, `mv`, `mkdir`, `bundle`, `rspec`, `rake`, migrations, Docker runs). It has **no `Bash`** at all.
- ❌ Invoke an IMPLEMENTATION skill in the main thread via `Skill` (`/tdd`, `/coverage`, `/architect`, `/code-review`, `/performance`, `/migration`, `/security`, domain validators, etc.). Skills invoked via `Skill` run IN THIS conversation with THIS context and could edit files here — that violates the contract. **Delegate them through `Agent`** so the editing happens in the subagent's session.
- ❌ Apply its own Kaizen edits directly — it must delegate them to a `worker` (see Kaizen section).
- ❌ Commit or push without explicit user approval (see Critical Rules below).

### Why delegation, not main-thread skills
A `Skill` invocation runs in the **main thread** and inherits this session's tools and context. An `Agent` invocation runs in a **separate session** with its own tools and context window. Only the second guarantees "the coordinator never touches files": the worker subagent does the editing in its own session and returns a result. This is also the **creator/verifier separation** — the agent that writes code is never the agent that validates it.

> If you ever feel the urge to "just make this one edit" — STOP. Dispatch a worker.

---

## ⛔ Critical Rules

**NEVER execute `git commit` or `git push` without explicit user approval.**

Before ANY git operation that modifies history or remote:
1. Show a summary of what will be committed/pushed
2. Ask explicitly: "Ready to commit and push. Proceed? (y/n)"
3. **WAIT** for user to respond "y" or "yes"
4. Only then execute the git commands

This applies to ALL workflows, including automated pipelines like Phase 4: Publish.

---

## MCP Tools Philosophy

**Official MCP Tools (Manual Research Only)**

This orchestrator does NOT automate MCP tools. Official MCP servers (Context7, ClickHouse, Honeybadger) are **manual research aids**:

- **Context7**: Look up API documentation when encountering unfamiliar libraries/patterns
- **ClickHouse**: Query production data for debugging or validation (manual queries)
- **Honeybadger**: Investigate production errors and fault patterns

**Why Manual?**
- Custom automated MCP tools had -88% ROI and 86% false negative rate
- Manual review has +1,700% ROI with 0% false negatives
- Simple grep-based validation is instant and reliable
- Official MCP tools provide value as optional research aids, not required dependencies

**Usage Pattern:**
```
# ❌ DON'T: Automatic batch MCP analysis
results = SkillMcpIntegration.batch_analyze(files)  # NO LONGER EXISTS

# ✅ DO: Manual MCP usage when needed
# 1. Run grep-based validators (instant, reliable)
# 2. If stuck, manually query Context7 for docs
# 3. If debugging, manually query ClickHouse/Honeybadger
# 4. Continue with manual review
```

All skills work WITHOUT MCP tools. MCP is optional enrichment, never a dependency.

**Serena MCP** — removed 2026-06-02; backup at `investigations/serena-mcp-block.bak.json`.

**ast-grep (AST-Aware Structural Search — CLI, Optional)**

When `sg` (`brew install ast-grep`) is on PATH, skills can match Ruby AST patterns instead of text — eliminating the comment/string false positives that plague grep-based checks. ast-grep answers "find every real `Time.now` call / every `can :action, Model` rule / every `perform_async(payment.id)`" (structural layer). Invoked via `Bash` (`sg run --lang ruby --pattern '...'`), no MCP server.

Skills that benefit (multi-tenancy, timezone, code-review, action-policy, sidekiq, pci-compliance, gateway-consistency, security) reference `.claude/skills/shared/ast-grep-patterns.md` for when to prefer `sg` over `grep` and the graceful `command -v sg` fallback. ast-grep does NOT help with dynamic dispatch (`constantize`, `send`) — grep + manual reasoning there.

Adoption is per-developer (`brew install ast-grep`). The full spike (5/5 queries won) lives at `investigations/ast-grep-spike/results/conclusion.md`.

---

# Skill Orchestrator - Master Controller

The central coordinator that **dispatches** ALL skills to subagents for maximum efficiency. It runs independent tasks in parallel and manages the complete development lifecycle — **without ever writing code itself** (see Coordinator Contract above).

## Philosophy

> "Maximize parallelism, minimize wait time, ensure quality — by delegating, never doing"

This skill is the **default entry point** for any complex task. It intelligently selects skills and **dispatches them to subagents** (`Agent` tool) based on the task type. The coordinator reads, plans, gates, and aggregates; the subagents do the work.

## 🔴 Auto-Detection (Smart Mode)

**Orchestrate automatically suggests itself** when detecting feature/refactor requests.

### Detection Rules

```ruby
# ✅ AUTO-SUGGEST (ask user y/n) when message includes:
feature_keywords = [
  'implementa', 'agrega', 'crea', 'añade', 'add',
  'feature', 'functionality', 'nueva funcionalidad',
  'refactor', 'refactoriza', 'mejora',
  'migración', 'migration', 'migrate',
  'payment', 'membership', 'RBAC', 'permissions',
  'API', 'GraphQL', 'endpoint', 'mutation',
  'fix bug completo', 'arregla', 'soluciona'
]

# ✅ AUTO-EXECUTE (no ask) when message includes:
explicit_commands = [
  '/orchestrate',
  'orchestrate this',
  'run full workflow',
  'run orchestrate'
]

# ❌ SKIP (don't suggest) when message includes:
skip_keywords = [
  '¿', '?',                           # Questions
  'muestra', 'lee', 'read', 'show',   # Read-only
  'explica', 'explain', 'qué hace',   # Explanations
  'gracias', 'ok', 'bien', 'thanks',  # Confirmations
  'busca', 'search', 'encuentra'      # Search/explore
]
```

### Auto-Suggest Behavior

```bash
# Example 1: Feature detected
User: "Implementa validación RBAC en reservations"
→ Detects: "implementa" + "RBAC"
→ Response:
  🔧 Feature detected: RBAC validation
  This looks like a complete feature. Run /orchestrate? (y/n)

User: "y"
→ Executes full orchestrate workflow

# Example 2: Explicit command
User: "/orchestrate feature: Add auto-renewal"
→ Executes immediately (no confirmation needed)

# Example 3: Simple question
User: "¿Cómo funciona el membership renewal?"
→ No orchestrate suggestion (0s overhead)
→ Answers directly

# Example 4: Read request
User: "Muéstrame app/models/user.rb"
→ No orchestrate suggestion (0s overhead)
→ Shows file directly
```

### Smart Detection Logic

Before responding to ANY user message, check:

1. **Explicit command?** → Execute immediately
2. **Skip keyword?** → Skip orchestrate, respond directly
3. **Feature keyword?** → Suggest orchestrate (ask y/n)
4. **Default** → Skip orchestrate, respond directly

**Zero overhead** for simple messages (questions, reading, explanations).

---

## 🗂️ Step 0: Check Investigations Folder (ALWAYS — Before Any Work)

**BEFORE starting any ticket work** (feature, bug fix, refactor), check if prior research exists:

```bash
# Extract ticket ID from branch or user message (e.g. CORE-189, PLA-234)
ls investigations/CORE-189/    # Replace with actual ticket ID
```

**If folder exists** → **READ EVERYTHING IN IT FIRST**:
```bash
ls investigations/CORE-189/
# Typical contents:
# - patch-integration-reference.md  ← domain reference guide
# - skill-qa-audit-YYYY-MM-DD.md    ← prior QA findings
# - tmp_test_*.rb                   ← manual test scripts already written
```

**Why this matters**: During CORE-189, a full reference guide, QA audit, and test scripts already existed.
Without checking, they would have been re-created from scratch — wasting 2+ hours.

**If folder is empty or doesn't exist** → the coordinator does NOT create it (no mutating commands). The first dispatched **worker** seeds it from the **RPI template** in its own session, then writes into the seeded files; the coordinator only reads them. RPI = Research / Plan / Implement ("No Vibes Allowed", Dex Horthy): produce legible intermediate artifacts and align on architecture **before** writing code.

```bash
# Worker's first action when investigations/<TICKET>/ is empty:
mkdir -p investigations/<TICKET>
cp investigations/_RPI-TEMPLATE.md investigations/<TICKET>/understanding.md
# → strip to Phase 1, work Research; split Phase 2 into <feature>-design.md; Phase 3 → findings.md
```

**RPI → phase mapping** (so the seeded artifacts feed the existing pipeline):

| RPI phase | Seeded artifact | Drives orchestrate phase |
|---|---|---|
| **Research** | `understanding.md` | Phase 0b `/architect` (+ `Explore`) — system map, write-paths, live-data grounding |
| **Plan** | `<feature>-design.md` (ADR) | Phase 0b `/architect` + `/migration` + `/performance` — files+lines, test strategy, alternatives |
| **Implement** | code + `seed_*.rb`/`verify_*.rb` + `findings.md` | Phase 2 `/tdd` → Gate 3.5 validator — RED/GREEN/REFACTOR, residual risk |

The **grill-me** contracts (Phase 0a) belong in `validation-contracts.md`; they map onto the Plan's "Test strategy" row. Heavier features (>1 day, customer-facing, compliance) → promote Plan into OpenSpec (`/opsx:new`) per the CLAUDE.local.md decision algorithm.

**Zero cost** if empty (one `cp`). **Huge save** if research already exists.

---

## Available Skills

> **Execution locus** (how the coordinator runs each): 🟣 **coordinator-direct** via `Skill` (non-mutating, interactive) = `/grill-me`, `/learning`. 🟢 **delegated-worker** via `Agent subagent_type="worker"` (edits code) = `/tdd`, `/coverage`, `/migration`, `/sidekiq`, `/architect`-produced changes, `/commit`, `/create-pr`. 🔵 **delegated-validator** via `Agent subagent_type="validator"` = `/adversarial-review`, `/code-review`. 🔎 **delegated-analyst** via `Agent subagent_type="Explore"` (read-only) = `/timezone`, `/packwerk`, `/security`, `/graphql`, `/multi-tenancy`, `/performance`, `/action-policy`, `/pci-compliance`, `/gateway-consistency`, domain validators. The coordinator itself never runs any of them in-thread except the 🟣 set.
>
> **Split-locus skill** = `/receiving-code-review` (inbound PR/bot feedback): its **triage/gate** phase is 🟣 coordinator-direct (read-only + `AskUserQuestion` to clarify ambiguous feedback — a worker can't ask), and its **implement** phase is 🟢 delegated-worker via `/tdd` (the fix edits code). Never run the whole skill in one locus: gate in-thread, then dispatch the confirmed fixes to a worker. Same split pattern as grill-me 🟣 → tdd 🟢.

### Phase 0a — Requirements (coordinator-direct 🟣)
| Skill | Purpose | Automatic |
|-------|---------|-----------|
| `/grill-me` | Interrogate user until ambiguity=0; emit validation contracts | ✅ For fuzzy feature/refactor specs (before architect) |

### Meta Skills (Skill maintenance)
| Skill | Purpose | Automatic |
|-------|---------|-----------|
| `/orchestrate` | Master coordinator (THIS SKILL) | ✅ **Smart auto-detect** |
| `/kaizen` | Continuous skill improvement | 🔵 Manual only |
| `/skill-creator` | Detect skill gaps, create new skills | 🔵 Manual only |
| `/learning` | Capture user corrections → memory + skills | ✅ Auto-suggest on correction signals |

### Architecture Skills (PHASE 0 - Before coding)
| Skill | Purpose | Automatic |
|-------|---------|-----------|
| `/architect` | System design, code location, patterns | ✅ For new features |

### Static Analysis Skills (PHASE 1A - Can run in parallel)
| Skill | Purpose | Automatic |
|-------|---------|-----------|
| `/timezone` | Find Time.now violations | ✅ |
| `/packwerk` | Package boundaries | ✅ |
| `/security` | Brakeman/OWASP audit | ✅ |
| `/graphql` | API backward compatibility | ✅ |

### Code Analysis Skills (PHASE 1B - After TDD)
| Skill | Purpose | Automatic |
|-------|---------|-----------|
| `/multi-tenancy` | Facility scoping | ✅ |
| `/performance` | N+1, indexes, memory | ✅ |
| `/action-policy` | Action Policy validation | ✅ For policies/AuthorizedController |

### Development Skills (Sequential)
| Skill | Purpose | Automatic |
|-------|---------|-----------|
| `/tdd` | Test-driven development | ✅ |
| `/coverage` | 100% coverage verification | ✅ |
| `/sidekiq` | Job pattern validation | ✅ |
| `/gateway-test` | Payment gateway tests | 🔵 Manual |

### Domain Skills (PARALLEL - Context-aware)
| Skill | Purpose | Automatic |
|-------|---------|-----------|
| `/memberships` | Membership domain expert | ✅ |
| `/memberships` | Membership domain expert + validation | ✅ |
| `/migration` | Database migration safety | ✅ |
| `/pci-compliance` | PCI-DSS validation | ✅ For payment code |
| `/gateway-consistency` | Gateway divergence detection | ✅ For payment code |

### Debugging Skills
| Skill | Purpose | Automatic |
|-------|---------|-----------|
| `/debug` | Production debugging | ✅ |

### Quality Skills (Post-development)
| Skill | Purpose | Automatic |
|-------|---------|-----------|
| `/code-review` | Comprehensive code review | ✅ |
| `/qa-audit` | Skills quality audit | 🔵 Manual |
| `/kaizen` | Skill quality and improvement audit | ✅ Periodic |

### Inbound Review Feedback (split-locus 🟣→🟢)
| Skill | Purpose | Automatic |
|-------|---------|-----------|
| `/receiving-code-review` | Gate + verify inbound PR/bot feedback (human reviewers, Bugbot, CodeRabbit, Greptile) before acting | ✅ When review feedback arrives on an open PR |

> **How the coordinator runs it** — two phases, two loci (never one):
> 1. **Triage/Gate** 🟣 *coordinator-direct*: the coordinator invokes `/receiving-code-review` in-thread (read-only) to gather the feedback, run the confirm-loop gate (real + in-scope `git diff develop...HEAD` + reproducible), discard false positives with a one-line reason, and use `AskUserQuestion` for anything ambiguous. Outputs a gated list of CONFIRMED items. No performative agreement.
> 2. **Implement** 🟢 *delegated-worker* via `/tdd`: for each confirmed item, dispatch an `Agent subagent_type="worker"` with "follow `/tdd`" — failing test first (rule #8), then the fix, one item at a time. GitHub thread replies stay at the user's action gate (draft, don't auto-post; per `feedback_draft_outward_comms`).

### Git Skills (User-triggered)
| Skill | Purpose | Automatic |
|-------|---------|-----------|
| `/commit` | Create git commit | 🔵 Manual |
| `/create-pr` | Create pull request | 🔵 Manual |
| `/fix-issue` | Fix GitHub issue | 🔵 Manual |

### Infrastructure
| Skill | Purpose | Automatic |
|-------|---------|-----------|
| `/docker-exec` | Docker execution guide | ✅ |

## Master Dependency Graph

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MASTER ORCHESTRATION MAP                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PHASE 0a: Grill (fuzzy specs)        [coordinator-direct: /grill-me]       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │   Interrogate user until ambiguity = 0 → emit VALIDATION CONTRACTS    │   │
│  │   (testable assertions C1..Cn that flow into architect/TDD/validator)│   │
│  └──────────────────────────────┬──────────────────────────────────────┘   │
│                                 ▼                                           │
│  PHASE 0: Architecture              [→ Agent: architect (opus) / "follow /architect"] │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                           architect                                  │   │
│  │    Research → Design → ADR (given the contracts)                     │   │
│  └──────────────────────────────┬──────────────────────────────────────┘   │
│                                 ▼                                           │
│  PHASE 1A: Static Analysis        [→ Agent: Explore ×N IN PARALLEL, read-only] │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐                       │
│  │ timezone │ │ packwerk │ │ security │ │ graphql  │                       │
│  │          │ │          │ │          │ │          │                       │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘                       │
│       └────────────┴────────────┴────────────┘                              │
│                                 ▼                                           │
│  PHASE 1B: Domain Skills          [→ Agent: Explore ×N IN PARALLEL, read-only] │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐               │
│  │memberships │ │  pci-      │ │  gateway-  │ │ migration  │               │
│  │            │ │ compliance │ │ consistency│ │            │               │
│  └─────┬──────┘ └─────┬──────┘ └─────┬──────┘ └─────┬──────┘               │
│        └──────────────┴──────────────┴──────────────┘                       │
│                                 ▼                                           │
│  PHASE 2: Implementation (SEQUENTIAL)     [→ Agent: worker / "follow /tdd"]  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │              TDD — worker implements in its OWN session              │   │
│  │         (RED → GREEN → REFACTOR → COVERAGE 100%); satisfy C1..Cn     │   │
│  └──────────────────────────────┬──────────────────────────────────────┘   │
│                                 ▼                                           │
│  ══════════════════════════════════════════════════════════════            │
│  ║  GATE 3.5 — VALIDATOR (BLOCKING)   [→ Agent: validator, DIFFERENT    ║   │
│  ║  session than worker]. Verifies every contract C1..Cn against the    ║   │
│  ║  diff. REQUEST CHANGES → loop back to a fresh worker.                 ║   │
│  ══════════════════════════════════════════════════════════════            │
│                                 ▼                                           │
│  PHASE 2.5: Validation            [→ Agent: Explore/worker IN PARALLEL]      │
│  ┌──────────┐ ┌──────────┐ ┌─────────────┐ ┌───────────────┐              │
│  │ sidekiq  │ │ perform- │ │multi-tenancy│ │ action-policy │              │
│  │(if jobs) │ │ ance     │ │(if queries) │ │(if policies)  │              │
│  └────┬─────┘ └────┬─────┘ └──────┬──────┘ └──────┬────────┘              │
│       └─────────────┴──────────────┴───────────────┘                       │
│                                 ▼                                           │
│  PHASE 3: Quality                 [→ Agent: worker/Explore IN PARALLEL]      │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                │
│  │  code-review   │  │    coverage    │  │     pronto     │                │
│  │   (Context7)   │  │  (verify 100%) │  │  (lint lines)  │                │
│  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘                │
│          └───────────────────┼───────────────────┘                         │
│                              ▼                                              │
│  ══════════════════════════════════════════════════════════════            │
│  ║       QUALITY GATE: all checks pass (validator gate already passed) ║   │
│  ══════════════════════════════════════════════════════════════            │
│                              ▼                                              │
│  PHASE 4: Publish (user approval FIRST → then delegate)                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Coordinator asks y/n. On approval → Agent: worker runs commit→PR.   │   │
│  │  Coordinator itself runs no git.                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Parallel Execution Rules

### Phase 1A: Static Analysis (ALL PARALLEL)
| Skills | Reason |
|--------|--------|
| timezone, packwerk, security, graphql | Different analysis domains, no dependencies |

### Phase 1B: Domain Skills (ALL PARALLEL - if applicable)
| Skills | Reason |
|--------|--------|
| memberships, pci-compliance, gateway-consistency, migration | Domain-specific, independent analysis |

### Phase 2.5: Code Validation (ALL PARALLEL - after TDD)
| Skills | Reason |
|--------|--------|
| sidekiq, performance, multi-tenancy, action-policy | Validate implementation details |

### Phase 3: Quality (ALL PARALLEL)
| Skills | Reason |
|--------|--------|
| code-review, coverage, pronto | Independent quality checks |

> **Parallel = multiple `Agent` calls in one batch** (like adversarial-review's "all agents IN PARALLEL"). Read-only analysis → `Explore`; implementation → `worker`; verification → `validator`. The coordinator only dispatches and aggregates.

### Must Run Sequentially (Dependencies)
| First | Then | Reason |
|-------|------|--------|
| **grill-me** | **architect** | Resolve requirement ambiguity + emit contracts before designing |
| architect | Phase 1A | Must design before analyzing |
| Phase 1A | Phase 1B | Static analysis informs domain checks |
| Phase 1B | TDD | Domain knowledge needed before implementing |
| TDD | **validator GATE** | Independent agent verifies contracts before anything else |
| **validator GATE** | Phase 2.5 / Phase 3 | Quality runs only after the gate passes |
| Phase 2.5 | Phase 3 | Validation before quality checks |
| Phase 3 | commit | Quality gate must pass |
| commit | create-pr | Must commit before PR |
| debug | fix-issue | Must understand issue before fixing |

### Context-Aware Skill Selection
| If task is... | Coordinator dispatches FIRST... |
|---------------|---------------------|
| New feature request (fuzzy spec) | **grill-me (coordinator-direct)** → then architect |
| New feature request (clear spec) | architect (via Agent) |
| New pack/module | grill-me → architect |
| Major refactor | grill-me → architect |
| New integration | grill-me → architect |
| Security fix | security-hardening workflow |
| Performance issue | performance-optimize workflow |
| **Review feedback arrives on a PR** (human, Bugbot, CodeRabbit, Greptile) | **receiving-code-review (coordinator-direct 🟣 triage/gate)** → then worker via `/tdd` 🟢 for each confirmed item |

> **Skill Router is canonical**: before composing ANY worker/analyst dispatch prompt, consult the **Auto-Invoke Table in `CLAUDE.local.md`** and name every mandatory skill that matches the globs/packs the subagent will touch (`app/graphql/**`→`/graphql`, `db/migrate/**`→`/migration`, `*payment*`→`/pci-compliance`+`/gateway-consistency`, etc.). This is how the pure coordinator preserves convention enforcement without running the checks itself.

| If changes include... | Automatically run... |
|----------------------|---------------------|
| `app/graphql/` | graphql |
| `db/migrate/` | migration |
| `app/jobs/` | sidekiq |
| `*membership*` | memberships |
| `*payment*`, `*gateway*` | pci-compliance, gateway-consistency |
| `app/models/`, `app/services/` | multi-tenancy, performance |
| `app/adapters/` | pci-compliance, gateway-consistency |
| `app/policies/`, `authorized_controller*` | action-policy |

## Delegation Protocol (HOW the coordinator dispatches)

Every phase is a subagent dispatch via the `Agent` tool. The coordinator composes the prompt, launches the agent(s), and gates on the returned result.

> **Tool naming**: the delegation primitive in this harness is the **`Agent`** tool with a `subagent_type` argument. Older skill docs say "Task tool" — same thing.
>
> **Subagents are one level deep**: a subagent cannot spawn another (no `Agent` tool inside it) and cannot use `AskUserQuestion`. Consequences encoded below: grill-me is coordinator-direct; `code-simplifier` is dispatched by the coordinator as its own phase (a worker can't call it).
>
> **Separate context windows**: each subagent runs in its OWN context — it does NOT see this conversation's history, and only its final result returns to the coordinator (intermediate work stays in its window). So every dispatch prompt must be **self-contained** (this is why the template names the skill + pastes the contracts + the Skill Router matches). Caveat that changes how much to spell out: **`worker`/`validator` auto-load `CLAUDE.md` + `CLAUDE.local.md`** (they already have the conventions + Auto-Invoke Table), but **`Explore`/`Plan` skip them** — so an `Explore` prompt must explicitly name the skill/convention to apply.

### Dispatch mode: foreground by default, background on-demand

**Default = foreground.** Dispatch every phase in the foreground. Foreground is already parallel — launch N independent agents as **multiple `Agent` calls in ONE message** and the harness runs them concurrently (e.g. the 4 read-only analysts of Phase 1A). Foreground agents show **inline** in the transcript (`ctrl+o` to expand) and return their result synchronously, which keeps every **gate trivial and reliable** — exactly what a dependency chain (grill → architect → impl → validator → quality) needs.

**Escalate to background** (`Agent` with `run_in_background: true`, or press `ctrl+b` on a running foreground agent) ONLY when:
1. **A worker is expected to be long** (implementing a large slice) — backgrounding frees the session and the job shows in the `~/.claude/jobs/` monitor.
2. **Fan-out across multiple independent surfaces** (the vertical-slice DAG) — several surface-workers in true parallel that you want to monitor on the dashboard.

Do NOT background the **serial gated phases** (architecture, the worker→validator gate loop, publish): their whole point is to block and gate on the result. Background makes gating async/event-driven (cache cold between wakeups, more fragile) without adding parallelism you don't already have in foreground.

> **Visibility note**: foreground subagents are NOT missing — they render inline in the running session (e.g. "Running 4 agents…"). They simply don't appear in the cross-session jobs dashboard unless backgrounded. `ctrl+b` promotes a foreground agent to background on demand.

### Phase → subagent_type

| Phase | What runs | `subagent_type` | Mode |
|-------|-----------|-----------------|------|
| 0a Grill (fuzzy spec) | `/grill-me` interview → validation contracts | **coordinator-direct** (`Skill` + `AskUserQuestion`) | serial, interactive |
| 0b Architecture | `/architect` design + code location | **`architect`** (opus — planning is the model-quality phase) | serial, **fg** |
| 1A/1B Analysis | timezone, packwerk, security, graphql, multi-tenancy, pci, gateway, migration | `Explore` (read-only) | **parallel fg** (batch of Agent calls) |
| 2 Implementation | `/tdd` RED→GREEN→REFACTOR | **`worker`** | serial, **fg** (→ bg only if long / multi-surface fan-out) |
| 3.5 Validator GATE | `/adversarial-review` or `/code-review` vs contracts | **`validator`** (≠ worker session) | serial, **blocking, fg** |
| 3 Quality | coverage, pronto, performance, code-simplifier | `worker` (edits) / `Explore` (read-only) | **parallel fg** |
| 4 Publish | commit → PR (`pbp-code-review:pr-create`) | **`worker`**, only after `y/n` | serial, **fg** |

**code-simplifier**: in this delegated model it is **a coordinator-dispatched phase** (`Agent subagent_type="code-simplifier"`) run after the worker / during Quality — NOT something the worker triggers (workers can't spawn subagents). This differs from `shared/code-simplifier-integration.md`, which assumed skills ran in the main thread. Optimize test files after TDD; optimize production code during Quality.

### Reusable dispatch template (model on adversarial-review)

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
```

> **Before composing any prompt**, consult the CLAUDE.local.md **Auto-Invoke Table (Skill Router)** and name every mandatory skill matching the globs/packs the subagent will touch.

<!-- /bitacora skill was removed — skill never existed in this repo; removed from orchestrate 2026-06-10 superpowers-spike pruning pass. -->

---

## Orchestration Workflows

> **All workflows run through the Delegation Protocol.** The diagrams below name *what* runs in each phase; the coordinator executes each phase as an `Agent` dispatch (read-only analysis → `Explore`; implementation → `worker`; verification → `validator`), never in-thread. For **code-producing** workflows (1 Feature, 2 Bug Fix, 3 Membership, 5 API, 10 Refactor, 11 Security, 12 Performance), two phases are implied even where a diagram predates them: **Phase 0a `/grill-me`** (if the spec is fuzzy → emit validation contracts) at the very start, and the blocking **Validator gate (3.5)** between implementation and quality — exactly as drawn in the Master Dependency Graph. Read-only workflows (6 Debug, 7 Code Review, 8 Pre-commit, 9 Coverage) skip the validator gate unless they produce a code change.

### 1. Feature Development (Full Pipeline)

```
/orchestrate feature

┌─ PHASE 0: Architecture (FIRST - Design decisions) ┐
│  architect: Manual research + design decisions     │
│    → Optional: Context7 for API docs lookup        │
│    → Optional: ClickHouse for production patterns  │
│    → Where code lives (pack/app)                   │
│    → Patterns to use (Service/Interactor)          │
│    → Schema design                                 │
│    → API design (GraphQL mutations)                │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Analysis - 6 skills) ──────────────────┐
│  ├── timezone: Check for Time.now                 │
│  ├── packwerk: Verify package boundaries          │
│  ├── security: Brakeman scan                      │
│  ├── graphql: API compatibility (if GraphQL)      │
│  ├── performance: N+1 detection                   │
│  └── multi-tenancy: Facility scoping              │
└───────────────────────────────────────────────────┘
                        ↓
┌─ CONTEXT (Domain Skills - if applicable) ─────────┐
│  ├── memberships: If touches membership logic     │
│  ├── migration: If includes migrations            │
│  └── sidekiq: If touches jobs                     │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (TDD) ────────────────────────────────┐
│  tdd: RED → GREEN → REFACTOR → 100% COVERAGE      │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Quality - 3 skills) ───────────────────┐
│  ├── coverage: Verify 100%                        │
│  ├── code-review: Manual deep review              │
│  └── pronto: Lint changed lines                   │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (Publish - User approval) ────────────┐
│  commit → create-pr                               │
└───────────────────────────────────────────────────┘
```

### 2. Bug Fix (Debug + Fix)

```
/orchestrate fix <issue-number>

┌─ SEQUENTIAL (Debug) ──────────────────────────────┐
│  debug: Honeybadger + ClickHouse investigation    │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (Analyze) ────────────────────────────┐
│  fix-issue: Analyze issue, identify root cause    │
└───────────────────────────────────────────────────┘
                        ↓
┌─ CONTEXT (Domain Skills) ─────────────────────────┐
│  ├── memberships: If membership-related bug       │
│  ├── graphql: If API-related bug                  │
│  └── sidekiq: If job-related bug                  │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (TDD Fix) ────────────────────────────┐
│  tdd: Write failing test → fix → verify           │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Quality) ──────────────────────────────┐
│  ├── coverage: Verify 100%                        │
│  ├── code-review: Manual review of fix            │
│  └── pronto: Lint changes                         │
└───────────────────────────────────────────────────┘
```

### 3. Membership Changes

```
/orchestrate membership

┌─ SEQUENTIAL (Domain Analysis) ────────────────────┐
│  memberships: Validate business rules             │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Technical Analysis) ───────────────────┐
│  ├── sidekiq: Check renewal job patterns          │
│  ├── performance: Check payment queries           │
│  └── multi-tenancy: Verify facility scoping       │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (TDD) ────────────────────────────────┐
│  tdd: Test all membership types (weekly/monthly)  │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Quality) ──────────────────────────────┐
│  ├── coverage: 100% on membership code            │
│  └── code-review: Manual review of idempotency    │
└───────────────────────────────────────────────────┘
```

### 4. Database Migration

```
/orchestrate migration

┌─ SEQUENTIAL (Safety Check) ───────────────────────┐
│  migration: Validate safety, indexes, rollback    │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Impact Analysis) ──────────────────────┐
│  ├── performance: Check index requirements        │
│  ├── packwerk: Verify table naming convention     │
│  └── Optional: ClickHouse manual query for sizes  │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (TDD) ────────────────────────────────┐
│  tdd: Test migration up/down                      │
└───────────────────────────────────────────────────┘
```

### 5. GraphQL API Changes

```
/orchestrate api

┌─ SEQUENTIAL (Compatibility Check) ────────────────┐
│  graphql: Check backward compatibility            │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Analysis) ─────────────────────────────┐
│  ├── performance: Check N+1 in resolvers          │
│  ├── security: Check auth patterns                │
│  └── multi-tenancy: Verify facility scoping       │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (TDD) ────────────────────────────────┐
│  tdd: Request specs for mutations/queries         │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Quality) ──────────────────────────────┐
│  ├── coverage: 100% on GraphQL changes            │
│  └── code-review: Manual review of deferred       │
└───────────────────────────────────────────────────┘
```

### 6. Production Debugging

```
/orchestrate debug <error-description>

┌─ PARALLEL (Gather Context) ───────────────────────┐
│  ├── debug: Manual Honeybadger investigation      │
│  ├── Optional: ClickHouse production data query   │
│  └── code search: Find relevant code              │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (Root Cause) ─────────────────────────┐
│  Analyze patterns → Identify root cause           │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (Reproduce) ──────────────────────────┐
│  Create reproduction script → Verify locally      │
└───────────────────────────────────────────────────┘
                        ↓
┌─ OUTPUT ──────────────────────────────────────────┐
│  Debug report with fix recommendation             │
└───────────────────────────────────────────────────┘
```

### 7. Code Review (Full)

```
/orchestrate code-review

┌─ PARALLEL (All Analysis - 6 skills) ──────────────┐
│  ├── timezone: Audit for Time.now                 │
│  ├── packwerk: Check package boundaries           │
│  ├── security: Brakeman scan                      │
│  ├── graphql: API compatibility                   │
│  ├── performance: N+1, indexes                    │
│  └── multi-tenancy: Facility scoping              │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Domain Checks) ────────────────────────┐
│  ├── memberships: If applicable                   │
│  ├── migration: If applicable                     │
│  └── sidekiq: If applicable                       │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (Deep Review) ────────────────────────┐
│  code-review: Manual deep review + simplifier     │
│    Optional: Use Context7/ClickHouse for research │
└───────────────────────────────────────────────────┘
```

### 8. Pre-Commit Validation

```
/orchestrate pre-commit

┌─ PARALLEL (All Checks — each dispatched) ─────────┐
│  [Agent worker]   Tests: bin/d rspec <changed>    │
│  [Agent worker]   coverage: verify 100% delta     │
│  [Agent worker]   pronto: lint modified files     │
│  [Agent Explore]  timezone: check changed files   │
│  [Agent Explore]  security: quick Brakeman scan   │
│  [Agent Explore]  graphql: API compat (if GraphQL)│
└───────────────────────────────────────────────────┘
                        ↓
┌─ GATE (All Must Pass) ────────────────────────────┐
│  IF all passed → ask y/n → dispatch worker: commit│
│  ELSE → report failures, STOP (no commit)         │
└───────────────────────────────────────────────────┘
```

### 9. Coverage Improvement

```
/orchestrate coverage

┌─ SEQUENTIAL (Find Targets) ───────────────────────┐
│  coverage: Find uncovered files                   │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Write Specs - up to 3) ────────────────┐
│  For each uncovered file:                         │
│  ├── File 1: Write spec → validate → run          │
│  ├── File 2: Write spec → validate → run          │
│  └── File 3: Write spec → validate → run          │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (Verify) ─────────────────────────────┐
│  coverage: Verify all at 100%                     │
└───────────────────────────────────────────────────┘
```

### 10. Refactor (Code Improvement)

```
/orchestrate refactor

┌─ PARALLEL (Analysis) ─────────────────────────────┐
│  ├── code-review: Identify improvement areas      │
│  ├── performance: Find N+1, slow queries          │
│  └── multi-tenancy: Verify scoping                │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (Plan) ───────────────────────────────┐
│  architect: Design refactoring approach           │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (TDD Refactor) ───────────────────────┐
│  tdd: Add tests → refactor → verify green         │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Quality Gate) ─────────────────────────┐
│  ├── coverage: Verify 100%                        │
│  ├── performance: Verify improvements             │
│  └── pronto: Lint changes                         │
└───────────────────────────────────────────────────┘
```

### 11. Security Hardening

```
/orchestrate security-hardening

┌─ PARALLEL (Security Analysis) ────────────────────┐
│  ├── security: Brakeman + OWASP audit             │
│  ├── pci-compliance: Payment security (if payment)│
│  └── multi-tenancy: Data isolation check          │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (Production Verification) ────────────┐
│  Optional: Manual ClickHouse query for data check │
│  Verify no sensitive data exposure                │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (Fix Issues) ─────────────────────────┐
│  tdd: Write security tests → fix → verify         │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Verification) ─────────────────────────┐
│  ├── security: Re-run Brakeman                    │
│  ├── coverage: Verify security tests              │
│  └── code-review: Manual final security review    │
└───────────────────────────────────────────────────┘
```

### 12. Performance Optimization

```
/orchestrate performance-optimize

┌─ PARALLEL (Performance Analysis) ─────────────────┐
│  ├── performance: N+1, indexes, memory            │
│  ├── Optional: ClickHouse production data query   │
│  └── Optional: Honeybadger timeout investigation  │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (Identify Bottlenecks) ───────────────┐
│  Prioritize by impact: queries, loops, memory     │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (TDD Optimization) ───────────────────┐
│  tdd: Benchmark tests → optimize → verify         │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Verification) ─────────────────────────┐
│  ├── performance: Re-verify improvements          │
│  ├── coverage: Verify 100%                        │
│  └── code-review: Manual review for regressions   │
└───────────────────────────────────────────────────┘
```

### 13. Skill Improvement (Kaizen)

```
/orchestrate kaizen

┌─ PHASE 1: Analyze (Scan all skills) ──────────┐
│  kaizen: Audit all skill files                   │
│    → Parse kaizen sections                       │
│    → Check for outdated patterns                 │
│    → Identify inconsistencies                    │
│    → Review recent execution failures            │
└───────────────────────────────────────────────┘
                        ↓
┌─ PHASE 2: Evaluate (Assess quality) ──────────┐
│  For each skill:                                 │
│  ├── Validate YAML frontmatter                   │
│  ├── Check documentation completeness            │
│  ├── Verify tool permissions                     │
│  ├── Ensure examples are current                 │
│  └── Check consistency with CLAUDE.md            │
└───────────────────────────────────────────────┘
                        ↓
┌─ PHASE 3: Improve (Make changes) ─────────────┐
│  ├── Update outdated documentation               │
│  ├── Add missing examples                        │
│  ├── Consolidate duplicate patterns              │
│  ├── Cross-pollinate best practices              │
│  └── Fix broken references                       │
└───────────────────────────────────────────────┘
                        ↓
┌─ PHASE 4: Validate (Ensure quality) ──────────┐
│  ├── Test YAML parsing                           │
│  ├── Verify all tool references                  │
│  ├── Check markdown structure                    │
│  └── Validate examples                           │
└───────────────────────────────────────────────┘
                        ↓
┌─ PHASE 5: Document (Track progress) ──────────┐
│  ├── Generate improvement report                 │
│  ├── Update skill kaizen sections                │
│  ├── Log metrics                                 │
│  └── Schedule next audit                         │
└───────────────────────────────────────────────┘
```

**Kaizen Triggers:**
- **Automatic**: After every 10 skill executions
- **Automatic**: When any skill fails 2+ times consecutively
- **Manual**: `/orchestrate kaizen` or `/kaizen`
- **Scheduled**: Weekly (if enabled)

## Parallel Task Execution

Launch multiple `Agent` calls **in a single batch** (one message, multiple tool uses) so they run concurrently — see the Delegation Protocol for the dispatch template.

```
# Example: 3 read-only analysts in parallel (one batch)
Agent subagent_type="Explore"  → "follow /timezone; scan changed files for Time.now"
Agent subagent_type="Explore"  → "follow /packwerk; check package boundaries"
Agent subagent_type="Explore"  → "follow /security; Brakeman + OWASP on the diff"
# Coordinator waits for all three, aggregates findings, then gates.
```

## Phase Gates

### Gate 0a: Grill (Phase 0a — fuzzy specs only)
The coordinator ran `/grill-me` to resolution.
- **Pass**: ambiguity = 0 AND explicit validation contracts (C1..Cn) emitted and confirmed by the user.
- **Fail**: keep grilling; do NOT dispatch architect/worker with unresolved branches.

### Gate 1: Static Analysis (Phase 1A)
All static analysis analysts (Explore) returned.
- **Pass**: No critical violations (timezone, security, graphql, packwerk)
- **Fail**: Stop and report violations

### Gate 2: Domain Analysis (Phase 1B)
Domain-specific analysts returned.
- **Pass**: Domain rules validated
- **Fail**: Stop if domain violations (e.g., PCI compliance failure)

### Gate 3: TDD Phase (Phase 2)
The `worker` reported implementation complete.
- **Pass**: Tests green, code implemented in the worker's session
- **Fail**: Re-dispatch worker with the failure

### Gate 3.5: VALIDATOR (Phase 3.5 — BLOCKING, independent agent)
A `validator` subagent (a DIFFERENT session than the worker) verified the diff against the contracts.
- **Pass**: every contract C1..Cn → PASS with evidence; verdict APPROVE / APPROVE WITH NOTES.
- **Fail (REQUEST CHANGES)**: loop back to a **fresh** `worker` with the validator's findings, then re-run a **fresh** `validator`. Never let the worker self-verify. Quality phase does not start until this passes.

### Gate 4: Code Validation (Phase 2.5)
Implementation-detail analysts returned.
- **Pass**: Patterns correct (sidekiq, performance, multi-tenancy)
- **Fail**: Re-dispatch worker to fix; re-run validator if behavior changed

### Gate 5: Quality Phase (Phase 3)
All quality checks pass.
- **Pass**: 100% coverage, review passed, lint clean
- **Fail**: Report failures, re-dispatch worker

### Gate 6: Publish Phase (Phase 4)
Only after all gates pass AND the user approved `y/n`.
- **Pass**: worker created commit + PR; returns SHA + PR URL
- **Fail**: N/A (shouldn't reach here without passing gates)

## Quality Gate Pattern (Common)

**Precondition**: the **Validator gate (Gate 3.5)** must have passed — an independent `validator` agent verified every contract — before this quality gate runs.

All workflows use this quality gate before publishing:

```
┌─ QUALITY GATE ──────────────────────────────────────┐
│                                                      │
│  PRECONDITION: Validator gate (3.5) passed           │
│                                                      │
│  REQUIRED CHECKS (each = a dispatched subagent):     │
│  ├── Tests: All specs passing                        │
│  ├── Coverage: 100% on changed lines (patch)         │
│  ├── Coverage: Global % not decreased (project)      │
│  ├── Pronto: No lint violations on changes           │
│  ├── Brakeman: No security warnings                  │
│  └── Domain: Relevant domain analysts passed         │
│                                                      │
│  IF ANY FAIL:                                        │
│  1. Report all failures clearly                      │
│  2. Re-dispatch a worker to fix                      │
│  3. Re-run failed checks (and validator if behavior  │
│     changed)                                         │
│  4. DO NOT proceed to publish                        │
│                                                      │
│  IF ALL PASS:                                        │
│  1. Ask user: "Ready to commit and push? (y/n)"      │
│  2. Wait for explicit approval                       │
│  3. Dispatch a worker to run commit→PR (coordinator  │
│     runs no git itself)                              │
│                                                      │
└──────────────────────────────────────────────────────┘
```

## Status Tracking

The coordinator reports what it **dispatched** and what each subagent **returned** (it does none of the work itself). Add a "Dispatched to" column:

```markdown
## Orchestration Status: Feature X

### Phase 0a: Grill (coordinator-direct)
Contracts emitted: C1 (no double-charge), C2 (facility-scoped), C3 (idempotent retry)

### Phase 1: Analysis
| Skill | Dispatched to | Status | Result |
|-------|---------------|--------|--------|
| timezone | Agent(Explore) | ✅ | No violations |
| packwerk | Agent(Explore) | ✅ | Boundaries OK |
| security | Agent(Explore) | ✅ | No issues |

### Phase 2: Implementation
| Skill | Dispatched to | Status | Result |
|-------|---------------|--------|--------|
| tdd | Agent(worker) | ✅ | 12 examples green; C1–C3 satisfied |

### Gate 3.5: Validator (independent)
| Skill | Dispatched to | Status | Result |
|-------|---------------|--------|--------|
| adversarial-review | Agent(validator) | ✅ | C1✓ C2✓ C3✓ → APPROVE |

### Phase 3: Quality
| Skill | Dispatched to | Status | Result |
|-------|---------------|--------|--------|
| coverage | Agent(worker) | ✅ | 100% (45/45) |
| pronto | Agent(worker) | ✅ | Clean |

### Phase 4: Publish (after y/n)
| Skill | Dispatched to | Status | Result |
|-------|---------------|--------|--------|
| commit → PR | Agent(worker) | ✅ | PR #456 |
```

## Example Session

```
User: /orchestrate feature: add weekly auto-renewal grace period

Claude (coordinator):
## Orchestrating — I dispatch all work to subagents; I touch no files.

### Phase 0a: Grill (requirements fuzzy) — coordinator-direct
[Skill /grill-me + AskUserQuestion — I interview you]
→ Ambiguity = 0. Validation contracts:
   C1: a renewal within the grace window does NOT double-charge.
   C2: grace period is facility-scoped (no cross-tenant leakage).
   C3: the expiry job is idempotent on retry.

### Phase 0b: Architecture
[Agent subagent_type="Plan" — design + code location, given C1–C3]
→ packs/memberships; Service + Sidekiq job. (No files written.)

### Phase 1A: Static analysis — 4 parallel Agents (Explore, read-only)
[timezone] [packwerk] [security] [graphql] → all clean.

### Phase 2: Implementation — worker in its OWN session
[Agent subagent_type="worker", "follow /tdd; satisfy C1–C3; consult Skill Router"]
→ Worker writes failing tests, implements, refactors. Returns diff + green suite.
   I wrote no code — the worker did, in its own session.

### Gate 3.5: VALIDATOR — DIFFERENT agent (creator/verifier separation)
[Agent subagent_type="validator", "follow /adversarial-review; you did NOT write
 this; verify C1–C3 against git diff develop...HEAD"]
→ C1 PASS, C2 PASS, C3 REQUEST CHANGES (retry path not idempotent). GATE FAILED.
   → loop: fresh Agent(worker) fixes C3 → fresh Agent(validator) → all PASS.

### Phase 3: Quality — parallel Agents
[coverage → worker] [pronto → worker] [performance → Explore] → 100%, clean, no N+1.

### Phase 4: Publish
All gates passed. Ready to commit and create PR. Proceed? (y/n)
   ← I will NOT run git until you approve; then a worker runs commit→PR.
```

## Best Practices

1. **Never do the work — dispatch it**: the coordinator reads, plans, gates, aggregates. Edits/tests/commits happen in subagent sessions only.
2. **Separate creator from verifier**: the `validator` is always a different session than the `worker`. On a re-loop, both are fresh sessions.
3. **Maximize Parallelism**: launch independent analysts as one batch of `Agent` calls.
4. **Fail Fast**: stop at first critical gate failure; re-dispatch a worker rather than patching in-thread.
5. **Clear Dependencies**: never parallelize dependent phases (grill → architect → impl → validator → quality).
6. **Name the skills**: every dispatch prompt names the skill(s) to follow + the validation contracts + the Skill Router matches.
7. **Report Clearly**: summarize what was dispatched and what each subagent returned at each phase.

---

## Meta-Skills (Manual Only)

Meta-skills (`/kaizen`, `/skill-creator`) are **manual only** - no automatic triggers.

### When to Use Meta-Skills

**Use `/skill-creator` when you notice**:
- Repeated manual work (3+ times same pattern)
- Complex solution worth automating
- Pattern that could help future sessions

**Use `/kaizen` when you notice**:
- Skill failed multiple times
- Skill could be more efficient
- Skill documentation unclear

```bash
# After noticing pattern:
/skill-creator               # Detect skill gaps from session

# After skill issues:
/kaizen <skill-name>         # Improve specific skill
/kaizen                      # Full ecosystem audit
```

**No overhead** - User decides when to analyze.

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new parallel execution opportunity
- A missing dependency relationship
- A better orchestration workflow

**You MUST** (the coordinator cannot edit files — it delegates its own Kaizen edits):
1. Complete the current orchestration first.
2. Draft the Kaizen entry text (format: `<!-- Kaizen: YYYY-MM-DD --> ...`).
3. Dispatch a worker to apply it:
   `Agent subagent_type="worker"`, prompt: "Append this Kaizen entry verbatim to the end of `.claude/skills/orchestrate/SKILL.md` (do not modify anything else):\n<entry>".
4. Confirm the worker reported success.

**Recent Improvements**:
<!-- Kaizen: 2026-05-25 - Pure-coordinator refactor -->
- **`/orchestrate` is now a PURE administrative coordinator.** It never edits files or runs mutating commands; ALL work is delegated to subagents via the `Agent` tool (separate sessions). Added the **Coordinator Contract** (MAY/MUST-NEVER) and **Delegation Protocol** (phase→subagent_type + dispatch template) sections.
- Frontmatter `allowed-tools` stripped of `Bash`/`Edit`/`Task` and the `mcp__serena__*` write wildcard → `[Agent, Read, Grep, Glob, AskUserQuestion, Skill, mcp__serena__(read-only)]`. `Skill` is contract-limited to non-mutating skills (`/grill-me`, `/bitacora`, `/learning`).
- Created dedicated subagents `.claude/agents/worker.md` (sonnet; Edit/Write/Bash/Skill; follows the named skill + contracts) and `.claude/agents/validator.md` (opus; read-only; adversarial creator/verifier).
- Wired the two structural additions: **Phase 0a `/grill-me`** (emit validation contracts, coordinator-direct) before architect, and **Gate 3.5 Validator** (blocking, independent agent verifies every contract) between TDD and Quality. Updated Master Dependency Graph, Parallel Execution Rules, Phase Gates, Quality Gate, Example Session, Status Tracking, Best Practices.
- Runtime facts honored: subagents can't spawn subagents (so `code-simplifier` is a coordinator-dispatched phase, not worker-triggered) and can't use `AskUserQuestion` (so grill-me stays coordinator-direct). `.claude/agents/*` load at session start — restart to pick up new agents.
- **Dispatch mode decided: foreground by default, background on-demand.** Foreground is already parallel (batch of `Agent` calls) and returns synchronously → gates stay simple/reliable for the dependency chain. Escalate to `run_in_background`/`ctrl+b` only for long workers or multi-surface fan-out (then visible in the `~/.claude/jobs/` dashboard). Never background the serial gated phases. Added a "Dispatch mode" subsection to the Delegation Protocol.
- ROI: makes "the coordinator never touches code" enforceable by construction (separate sessions) and bakes creator/verifier separation into the flow.

<!-- Kaizen: 2026-01-24 - MCP Integration Update -->
- Integrated: 7 new MCPs across 10 skills:
  - `github` → fix-issue, create-pr, commit, code-review, debug
  - `opensearch` → performance, debug, code-review
  - `rails` → performance, debug
  - `playwright` → tdd
  - `mermaid` → architect, code-review
  - `stripe` → gateway-test, pci-compliance
- Added: MCP usage documentation to each integrated skill
- Total MCPs available: 14 (clickhouse, context7, honeybadger, sentry, github, opensearch, rails, playwright, mermaid, stripe, filesystem, figma, terraform, kubernetes)

<!-- Kaizen: 2026-01-24 - Major Skills Ecosystem Update -->
- Added: 3 new skills (`/pci-compliance`, `/gateway-consistency`, `/membership-validate`)
- Updated: Skills count from 21 to 24
- Split: Phase 1 into Phase 1A (static analysis) and Phase 1B (domain skills)
- Changed: Domain skills now run in PARALLEL (not sequential)
- Added: Phase 2.5 for code validation (sidekiq, performance, multi-tenancy)
- Added: 3 new workflows: `/orchestrate refactor`, `/orchestrate security-hardening`, `/orchestrate performance-optimize`
- Added: Quality Gate Pattern (common pattern across all workflows)
- Updated: Context-aware skill selection for payment code
- Updated: Master Dependency Graph with new phases

<!-- Kaizen: 2026-01-22 -->
- Added: `/architect` skill as PHASE 0 (before analysis)
- Updated: Skills count from 20 to 21
- Updated: Master Dependency Graph with architect phase
- Updated: Feature Development workflow with architect step
- Added: Context-aware selection for when to run architect automatically

<!-- Kaizen: 2026-01-26 - Meta-Skill Integration -->
- Added: `/kaizen` meta-skill for continuous improvement
- Purpose: Systematic skill quality assurance and enhancement
- Created: New "Meta Skills" category in skill list
- Added: Workflow 13 - Skill Improvement (Kaizen)
- Triggers: Automatic (every 10 executions, after failures), manual, scheduled
- Philosophy: "Sharpen the saw" - skills must evolve with the codebase
- Updated: Skills count from 24 to 25
- Integration: kaizen checks can be invoked by orchestrate workflows
- Next: Implement automatic kaizen triggers in orchestration logic

<!-- Kaizen: 2026-01-28 - MCP Integration Lessons & Stability Focus -->
**Critical Lessons Learned from MCP Experiment:**
- **Lesson 1: Prefer Simple Over Complex** - Grep-based validation (instant) > Custom AST tools (timeouts, false negatives)
- **Lesson 2: Manual Review > Unreliable Automation** - 14% detection rate proved custom MCP tools generated negative ROI (-88%)
- **Lesson 3: Official MCP Tools are Manual Aids** - Context7, ClickHouse, Honeybadger are MANUAL research tools, not automatic validators
- **Lesson 4: Never Delete Without Backup** - Catastrophic loss of 160 hours work taught us: always verify understanding before destructive operations
- **Lesson 5: Validate Before Executing** - rm commands, git operations, and destructive actions require explicit confirmation

**Skills Restored to Stable State:**
- Removed: All SkillMcpIntegration.rb dependencies (broken custom tools)
- Removed: lib/skill_mcp_integration.rb, lib/mcp_client_helper.rb (negative ROI)
- Removed: mcp-tools/ directory (8 custom tools with 86% false negative rate)
- Restored: Clean skills from `.claude/skills copy/` backup (795 lines vs 1027 broken)
- Strategy: Use official MCP (Context7, ClickHouse, Honeybadger) MANUALLY for context/research only

**Official MCP Usage (Manual Only):**
- Context7: Manual docs lookup when encountering unfamiliar APIs/patterns
- ClickHouse: Manual production data queries for debugging/validation
- Honeybadger: Manual error investigation for production issues
- **NEVER**: Automatic batch analysis, automatic validators, or skill dependencies on MCP tools

**New Stability Rules:**
1. All validators use grep/direct file analysis (instant, reliable)
2. All skills must work WITHOUT MCP tools (fallback gracefully)
3. MCP tools are optional research aids, NEVER required dependencies
4. Before rm/git commands: verify understanding, confirm with user
5. Complex integrations require backup/commit before changes

**ROI Reality Check:**
- Custom MCP Tools: -88% ROI (eliminated)
- Manual Review: +1,700% ROI (baseline strategy)
- Official MCP (manual): ∞ ROI (free, on-demand, no maintenance)


<!-- Kaizen: 2026-01-31 - Code Simplifier Integration Documentation -->
**What Changed:**
- Added "Code Simplifier Integration Points" section before Orchestration Workflows
- Documented 3 integration tiers (ALWAYS, MANDATORY, OPTIONAL)
- Mapped code-simplifier usage in Feature Development, Bug Fix, and Coverage workflows
- Added performance impact analysis per tier
- Created "When code-simplifier Runs" summary table

**Why:**
- code-simplifier now integrated in 5 skills (tdd, coverage, code-review, performance, factory-check)
- Orchestrate coordinates workflows → users need to understand when optimization happens
- Prevent confusion: "Why did my code change?" → Document automatic vs user-triggered
- Enable informed decisions: Users can choose workflows based on optimization preferences

**Impact:**
- Workflow transparency: Users know code-simplifier runs 4x in feature workflow, 2x in bugfix
- Performance expectations: 30-60s overhead, hours saved in test execution
- Clear tier documentation: ALWAYS (automatic), MANDATORY (included), OPTIONAL (user choice)
- Integration map shows exactly where in each workflow optimization occurs

**Lessons Learned:**
- When agents/tools run automatically, MUST document in orchestrate
- Integration tiers eliminate confusion about automation
- Workflow diagrams should show optimization points inline
- Performance impact analysis helps users decide if overhead is worth it

**ROI**: 2.0 (High clarity benefit for users, Medium effort - comprehensive documentation)

<!-- Kaizen: 2026-02-02 - Bitácora Integration -->
**What Changed:**
- Added `/bitacora` skill to Meta Skills table
- Added `/bitacora`, `/log` to explicit_commands for auto-execution
- Created "Bitácora Integration" section with:
  - Automatic triggers during workflows (decisions, blockers, learnings)
  - Integration points in orchestration phases
  - Manual commands reference
  - Example entry from workflow

**Why:**
- Developer traceability: Track technical decisions and their rationale
- Knowledge capture: Document blockers and how they were resolved
- Learning retention: Capture insights for future sessions
- Session continuity: Easy handoff between sessions with documented context

**Integration Points:**
- PHASE 0 (Architecture): Record DECISION entries for design choices
- PHASE 1-2 (Analysis + TDD): Record BLOCKER on failures, LEARNING on discoveries
- PHASE 3 (Quality): Record LEARNING for significant review insights
- END OF SESSION: Optional daily summary prompt

**Skill Locations:**
- Skill: `~/.cursor/skills/bitacora/SKILL.md`
- Entries: `~/.cursor/bitacora/YYYY-MM-DD.md`

**ROI**: 2.5 (High traceability value, personal knowledge base, low overhead)

<!-- Kaizen: 2026-02-19 - investigations/ Folder Convention (CORE-189) -->
**New convention: `investigations/CORE-[id]/` for local ticket research notes**

- **What**: Each ticket may generate research notes, API exploration scripts, and scratch findings. These live in `investigations/CORE-[id]/` at the repo root.
- **Exclusion mechanism**: Use `.git/info/exclude` (NOT `.gitignore`).
  - `.gitignore` is team-wide and committed — don't pollute it with personal folders.
  - `.git/info/exclude` is local-only (never committed), equivalent to a personal `.gitignore`.
  - Add entry: `investigations/` to `.git/info/exclude`.
- **End-of-session prompt**: When wrapping up a feature session, suggest moving any temporary investigation files (e.g., `tmp/test_issue.rb`, API exploration notes) into `investigations/CORE-[id]/` before closing.
- **Example structure**:
  ```
  investigations/
  └── CORE-189/
      ├── api_exploration.md      # Manual API call results
      ├── patch_contacts_notes.md # Findings on Contacts.all filter bug
      └── tmp_test.rb             # Scratch script used during debugging
  ```
- **ROI**: 2.0 (Keeps research findable across sessions without polluting the repo)

<!-- Kaizen: 2026-02-19 - Check investigations/ BEFORE starting work (CORE-189 lesson) -->
**Critical lesson: Always read `investigations/CORE-[id]/` BEFORE doing ANY research or investigation.**

- **What happened**: CORE-189 session generated a complete Patch CRM reference guide
  (`patch-integration-reference.md`), QA audit report, and manual test scripts in
  `investigations/CORE-189/`. Without the habit of checking this folder first, a future
  session working on Patch would re-research all of it from scratch (2+ hours wasted).
- **Rule added**: `🗂️ Step 0: Check Investigations Folder` added to orchestrate Smart Detection
  section — runs before any ticket work starts.
- **Rule added**: Same step added to `/architect` as "Step 0" before "Step 1: Understand
  the Requirement".
- **Command**: `ls investigations/CORE-189/` — zero overhead if empty, huge save if populated.
- **End-of-session habit**: After completing a ticket, move scratch scripts and notes into
  `investigations/CORE-[id]/` so the next session finds them immediately.
- **ROI**: 3.0 (High — prevents hours of re-work, Low effort — one ls command)

<!-- Kaizen: 2026-05-09 - Learning Skill Added -->
- Added: `/learning` skill — hybrid trigger captures user corrections to auto-memory + skill kaizen sections
- Why: Each correction was being lost; user had to manually create feedback_*.md files
- Mechanism: Skill + CLAUDE.local.md rule #15 (no real auto-trigger; depends on model discipline reading CLAUDE.local.md)
- Limitation: ~90% reliable (vs 100% if hooks were available)
- Integration: Reads existing memory format (feedback_<topic>.md), writes kaizen entries in standard format
- Skill mapping: 16 categories of correction topics → relevant skills (default: code-review)
- ROI: 3.0 (High value — prevents repeat mistakes, Low effort — reuses existing memory infrastructure)

<!-- Kaizen: 2026-05-22 - User correction -->
- Rule: Respect approved scope before enforcing a destructive step (DELETE/cleanup) — never make one a default/enforced behavior if the ticket marked it out-of-scope. Approval of X (e.g. links) ≠ approval to delete other tables.
- Why: In CORE-624 I nearly baked faves/user_stats deletion into the engine as an enforced default; the user caught that Erick had scoped those tables out — the exact scope creep (L3) I had criticized in TRIAGE-10.
- How to apply: Before adding a destructive step as default/enforced, re-read the approval record ("Out of scope / Pendiente / cleanup separado"). If out of scope: leave it out or strictly opt-in pending separate sign-off. Distinguish integrity consequences of an approved action (touch/reindex) from new destructive ops on other tables.
- Source: User correction on 2026-05-22. See `memory/feedback_respect_approved_scope.md`.

<!-- Kaizen: 2026-05-25 - User correction -->
- Rule: When a dispatched worker creates extracted/spillover files, they MUST land in a gitignored location if the source was personal/local. NEVER put personal files in `docs/` (committed team docs).
- Why: Optimizing `CLAUDE.local.md` (gitignored), I had files extracted into `docs/development/` — which is committed. Personal workflow notes would have shipped to the team repo. User: "si son local no deben estar donde es la doc de todo el equipo".
- How to apply: Before dispatching a worker to create files derived from a personal/local source, instruct it to verify the destination with `git check-ignore <path>`. In this repo: `docs/` = team/committed; `investigations/` and `.claude/` = personal/excluded (`.git/info/exclude`).
- Source: User correction on 2026-05-25. See `memory/feedback_personal_files_excluded_location.md`.

<!-- Kaizen: 2026-05-26 - Wire RPI template into Step 0 -->
- **What**: `investigations/_RPI-TEMPLATE.md` (RPI = Research/Plan/Implement, "No Vibes Allowed"/Dex Horthy) existed but was referenced nowhere — used only when remembered. Wired it into **Step 0**: when `investigations/<TICKET>/` is empty, the first worker seeds `understanding.md` from the template (`cp`), and the seeded artifacts map onto existing phases (Research→`/architect`, Plan→`<feature>-design.md`, Implement→`findings.md`). grill-me contracts → `validation-contracts.md`. Also added the RPI scaffold to the CLAUDE.local.md Workflow section (always-on).
- **Why**: Recent tickets (CORE-526/CORE-220) already used RPI artifacts ad-hoc, but with naming drift (CORE-639 used `root-cause`/`backfill-design` instead of `understanding`/`findings`). No enforcement = inconsistent. User chose "cablear en orchestrate Step 0".
- **How to apply**: Step 0 worker seeds from template before any code; coordinator only reads. Honors pure-coordinator contract (worker does the `cp`/writes) and the "no personal files in docs/" rule (`investigations/` is gitignored).
- ROI: 2.0 (consistency + cross-session legibility, near-zero overhead — one `cp`).

<!-- Kaizen: 2026-06-05 - User correction (validator dispatch evidence) -->
- Rule: When dispatching a `validator`/adversarial agent to verify a conclusion or diff, pass it the RAW evidence (files, diff, original research), not just the coordinator's distilled summary — with attack framing. Conclusion-visibility is fine (creator-verifier design); summary-only injects shared-premise bias so the validator can only contest the thesis, never the coordinator's reading of the facts. For load-bearing decisions, run a BLIND independent pass (fresh agent forms its own verdict from raw inputs, unaware of the coordinator's) as a clean tie-breaker, then reconcile.
- Why: obra/superpowers spike — 3 adversarial lenses dispatched with the synthesized conclusion but not the two raw research reports; only one partially flagged the narrowed scope. User: "¿deberías pasarle contexto o eso genera sesgo?".
- How to apply: invariant/fact-checker dispatch → explicit claims (ground-truth blinds anchoring); reasoning/Inverter dispatch → conclusion + attack framing + raw inputs; high-value gate → add a blind-pass tie-breaker agent.
- Source: User correction on 2026-06-05. See `memory/feedback_review_raw_evidence_not_summary.md`.

<!-- Kaizen: 2026-06-05 - User direction (confirm-loop protocol) -->
- Rule: When a dispatched validator/adversarial pass returns findings, run a GATED confirm-loop, not a blind one. Per finding: (1) gate on real + in-scope (`git diff develop...HEAD`) + reproducible; (2) route confirmation by type — code→worker reproduces LOCALLY with a failing test; API/lib→Context7; "does it happen in prod / what scale"→ClickHouse (`FINAL` on ReplacingMergeTree + replica-lag guard) or Honeybadger; MCP stays a MANUAL research aid (automated MCP had −88% ROI), ≥2 sources on load-bearing claims; (3) document each CONFIRMED finding in `investigations/<ticket>/findings.md` (gitignored) so the loop survives compaction; (4) terminate on 2 consecutive clean passes or a cap; (5) coordinator autonomy ends at the action gate — commit/push, destructive ops, and outward comms still require explicit user `y/n`.
- Why: a blind loop amplifies false positives and never terminates; gating + termination + document-confirmed give the "best panorama without waiting for manual" that the user wants, safely.
- Source: User direction on 2026-06-05. See `memory/feedback_confirm_loop_adversarial_findings.md`.

<!-- kaizen 2026-06-09: "implement the plan" = classify by executor first -->
When the user says "implement the plan / do it" over a plan, run a CLASSIFICATION pass before any coding: tag each item {me-now / user-interactive-action / external-sign-off-gated / no-op}. Adoption/meta/strategy plans often have little-to-no code-for-me — do only the me-now subset (gitignored prep), hand the user their commands, DRAFT (never auto-send/commit) gated items, and name no-ops as done-by-decision. Do not fabricate busywork or cross a sign-off/commit/destructive gate. See memory feedback_implement_plan_classify_by_executor.

<!-- Kaizen: 2026-06-09 — Worker STATUS enum + NEEDS_CONTEXT handling (adapted from obra/superpowers, MIT) -->
- Added STATUS enum (`DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT`) to the reusable dispatch template RETURN line.
- Rule: a subagent that hits genuine ambiguity returns NEEDS_CONTEXT — it CANNOT call AskUserQuestion (one level deep). The coordinator fields the question and re-dispatches with the answer rather than letting the worker guess.
- Why: without a typed status the coordinator had to parse free-text prose to detect stalls; NEEDS_CONTEXT makes the escalation path explicit and prevents workers from making up answers to unresolvable ambiguity.

<!-- Kaizen: 2026-06-10 — Purge stale tool/skill references (superpowers-spike 2026-06-10 drift findings) -->
- Removed: `/bitacora` from allowed skills (Coordinator Contract, explicit_commands, execution locus note, Meta Skills table) — skill never existed in this repo; the entire "Bitácora Integration" section collapsed to a one-line tombstone note. Historical Kaizen log entries preserved.
- Reduced: "Serena MCP" subsection from a 7-line "currently available" description to a one-liner tombstone noting removal date and backup path. Removed Serena references from the ast-grep paragraph.
- Updated: `/membership-validate` → `/memberships` in Domain Skills table, Phase 1B diagram, parallel rules table, context-aware selection table (skill was merged into `/memberships` 2026-06-10).
- Lesson: stale tool/skill references in the coordinator prompt mislead dispatch decisions — a skill listed as "available" that doesn't exist causes wasted agent cycles on a false dependency. Prune on every superpowers-spike pass.
