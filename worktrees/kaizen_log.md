# Kaizen Log — worktrees

_Archived from SKILL.md on 2026-06-14 (skills audit wave 3)._

---

**2026-06-10 — Created per superpowers-spike point 5.**

Pressure-test protocol applied BEFORE creation: a RED baseline run (fresh agent, no skill) was
executed. The agent produced a correct plan because the memory entries
(`project_run_other_branch_rake_via_worktree`, `project_worktree_review_read_from_worktree`) were
session-loaded. This skill does NOT close a behavior gap in memory-loaded sessions.

**Rationale for existing anyway:** canonical durable home for procedural knowledge. Memory was
truncating this week and is personal/non-extractable by other agents. Memory entries now point
here as the canonical reference. This was also the first real execution of the pressure-test
protocol — it correctly prevented overclaiming a gap (a skill that "solves a problem memory
already handles" is still worth having as a stable, addressable document, but the kaizen entry
must be honest about what it does and does not add).

**GREEN run (2026-06-10):** fresh agent WITH this skill, variant scenario (PR-branch review in
isolation + run its spec once). Followed the protocol fully AND exercised the edges memory
under-emphasizes: `git worktree list` hygiene pre-create, i18n-key check with two ref-pinned
sources anchored to the worktree (the ENG-582 false-positive trap), RAILS_ENV=test one-off spec
run with `db:test:prepare` fallback, guardrails recap (no stash/checkout, no compose up, no push,
cp-only secrets). Differential value of the skill over bare memory = edge precision + guardrails
recall. **Acceptance rule satisfied: 1 RED + 1 GREEN documented.** (Combined-pressure variant:
pending, run on next real use.)
