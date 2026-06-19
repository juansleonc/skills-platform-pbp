# Orchestrate — Phase→Skill Tables & Parallel Execution Reference

Relocated from SKILL.md body (progressive disclosure). The body keeps the decision
core (Coordinator Contract, Delegation Protocol, Phase Gates); this file holds the
detailed phase→skill catalog and the parallel/sequential execution rules.

> **Single source of truth for *which* skill fires on *which* glob is the
> `CLAUDE.local.md` Auto-Invoke Table (Skill Router)** — `worker`/`validator` agents
> auto-load it. The tables here describe the orchestration *phasing & execution
> locus* (parallel vs serial, Explore vs worker vs validator), not the glob→skill
> routing, which is not duplicated.

## Table of Contents
- [Execution Locus Legend](#execution-locus-legend)
- [Available Skills by Phase](#available-skills-by-phase)
- [Parallel Execution Rules](#parallel-execution-rules)
- [Must Run Sequentially (Dependencies)](#must-run-sequentially-dependencies)
- [Context-Aware Skill Selection](#context-aware-skill-selection)

---

## Execution Locus Legend

How the coordinator runs each skill:

- 🟣 **coordinator-direct** via `Skill` (non-mutating, interactive) = `/grill-me`, `/brainstorm`, `/learning`.
- 🟢 **delegated-worker** via `Agent subagent_type="worker"` (edits code) = `/tdd`, `/coverage`, `/migration`, `/sidekiq`, `/architect`-produced changes, `/commit`, `/create-pr`.
- 🔵 **delegated-validator** via `Agent subagent_type="validator"` = `/adversarial-review`, `/code-review`.
- 🔎 **delegated-analyst** via `Agent subagent_type="Explore"` (read-only) = `/timezone`, `/packwerk`, `/security`, `/graphql`, `/multi-tenancy`, `/performance`, `/action-policy`, `/pci-compliance`, `/gateway-consistency`, `/resilience`, domain validators.

The coordinator itself never runs any of them in-thread except the 🟣 set.

**Split-locus skill** = `/receiving-code-review` (inbound PR/bot feedback): its **triage/gate** phase is 🟣 coordinator-direct (read-only + `AskUserQuestion` to clarify ambiguous feedback — a worker can't ask), and its **implement** phase is 🟢 delegated-worker via `/tdd` (the fix edits code). Never run the whole skill in one locus: gate in-thread, then dispatch the confirmed fixes to a worker. Same split pattern as grill-me 🟣 → tdd 🟢.

---

## Available Skills by Phase

### Phase 0 — Ideation (coordinator-direct 🟣)
| Skill | Purpose | Automatic |
|-------|---------|-----------|
| `/brainstorm` | Divergent: explore the solution space, decompose, generate 2-3+ approaches, pick a direction | ✅ Only when the spec is *unformed* (WHAT/HOW open) — before grill-me |

### Phase 0a — Requirements (coordinator-direct 🟣)
| Skill | Purpose | Automatic |
|-------|---------|-----------|
| `/grill-me` | Interrogate user until ambiguity=0; emit validation contracts | ✅ For fuzzy feature/refactor specs (before architect) |

> **`/brainstorm` vs `/grill-me`** — both are coordinator-direct (require `AskUserQuestion`; subagents can't call it). `/brainstorm` is the **divergent** front-end (open options, pick a direction) used only when the spec is *unformed*; its output feeds `/grill-me`, the **convergent** step (kill ambiguity → emit contracts). If the approach is already known, skip straight to `/grill-me`.

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
| `/migration` | Database migration safety | ✅ |
| `/pci-compliance` | PCI-DSS validation | ✅ For payment code |
| `/gateway-consistency` | Gateway divergence detection | ✅ For payment code |
| `/resilience` | External-call/HTTP/gateway/job error handling, timeouts, observability | ✅ For external/HTTP/gateway code |

### Debugging Skills
| Skill | Purpose | Automatic |
|-------|---------|-----------|
| `/debug` | Production debugging | ✅ |

### Quality Skills (Post-development)
| Skill | Purpose | Automatic |
|-------|---------|-----------|
| `/code-review` | Comprehensive code review | ✅ |
| `/qa-audit` | Skills quality audit | 🔵 Manual |
| `/kaizen` | Skill quality and improvement audit | 🔵 Manual only |

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

---

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

---

## Must Run Sequentially (Dependencies)
| First | Then | Reason |
|-------|------|--------|
| **brainstorm** | **grill-me** | Diverge + pick a direction before killing ambiguity (only when spec is unformed) |
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

---

## Context-Aware Skill Selection
| If task is... | Coordinator dispatches FIRST... |
|---------------|---------------------|
| **Idea unformed** (WHAT/HOW open; multiple approaches plausible; multi-subsystem request) | **brainstorm (coordinator-direct 🟣)** → then grill-me → architect |
| New feature request (fuzzy spec, approach known) | **grill-me (coordinator-direct)** → then architect |
| New feature request (clear spec) | architect (via Agent) |
| New pack/module | brainstorm (if approach open) → grill-me → architect |
| Major refactor | grill-me → architect |
| New integration | brainstorm (if approach open) → grill-me → architect |
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
| External service / HTTP / gateway calls | resilience |
| `app/policies/`, `authorized_controller*` | action-policy |
