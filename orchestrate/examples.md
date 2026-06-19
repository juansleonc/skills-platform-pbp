# Orchestrate — Worked Examples

Relocated from SKILL.md body (progressive disclosure). Two worked examples:
1. **Status Tracking** — the per-phase dispatch/return report format.
2. **Example Session** — an end-to-end `/orchestrate feature` walkthrough.

---

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

---

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
[Agent subagent_type="architect" — design + code location, given C1–C3]
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
