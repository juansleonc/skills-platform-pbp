---
name: worktrees
description: >
  Use when running another branch's code/rake against the shared dev DB without disturbing WIP,
  when reviewing a PR branch in isolation, or when an agent needs an isolated checkout
  (EnterWorktree / isolation: worktree).
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
---

# Worktrees — PBP Dockerized Workflow

## When to Use

- Run a **different branch's rake/service** against the running dev DB without touching the main checkout.
- Review a **PR branch** in full isolation (no checkout pollution, no false positives from reading the wrong files).
- Agent needs an isolated checkout: use `EnterWorktree` / `isolation: "worktree"` in the harness first; fall back to this manual protocol only when compose wiring matters (e.g., you need the dev DB, gems volume, or pbc-network).

---

## Core Protocol (Manual — Dev DB Workflow)

### Step 1 — Create a detached worktree OUTSIDE the repo

```bash
# Always --detach: no tracking branch → no accidental push (branch-safety rule #16)
git worktree add --detach ../platform-<slug> origin/<branch>
# e.g.:
git worktree add --detach ../platform-core624 origin/feature/CORE-624-fix-links
```

Place it OUTSIDE `/workspace` so the running web container's file watcher is not disturbed.

Verify the main checkout is still on your feature branch:

```bash
git rev-parse --abbrev-ref HEAD   # must be your branch, NOT develop
git worktree list                 # confirm both entries
```

### Step 2 — Copy gitignored runtime files (never print/cat secrets)

```bash
WT=../platform-<slug>

cp .env                              "$WT/"
cp .graphql_pro_auth                 "$WT/"
cp config/database.yml               "$WT/config/"
cp config/env_vars.yml               "$WT/config/"
cp config/sidekiq.yml                "$WT/config/"
# If the task needs extra data files (e.g. a CHUNK_IDS file):
cp tmp/my_data_file.txt              "$WT/tmp/"
```

`cp` only — never `cat`, `echo`, `head`, `tail`, or any command that prints secrets to the terminal (CLAUDE.md rule #11).

### Step 3 — Run via one-off container (NEVER `docker compose up`)

```bash
cd "$WT"
docker compose -p platform run --rm --no-deps web bundle exec rake <task> [ARGS...]
# Interactive console or shell:
docker compose -p platform run --rm --no-deps web bundle exec rails c
docker compose -p platform run --rm --no-deps web bash
```

**Why `-p platform` is critical:**
- Reuses `platform_platform-gems` volume (no gem reinstall)
- Connects to the external `pbc-network`
- Hits the SAME `db` service (your seeded dev DB `paybycourtDB`)

### Step 4 — Verify from the main checkout

Use `bin/d` from the main checkout to inspect DB state. The same DB is shared.

```bash
# Back in main checkout:
bin/d rails c   # verify rows, counts, state
```

### Step 5 — Cleanup (always)

```bash
# --force is required: copied .env etc. make the worktree dirty
git worktree remove --force ../platform-<slug>
git worktree prune
```

`--force` also ensures the copied secrets files are deleted with the directory.

---

## HARD WARNINGS

> **NEVER `docker compose up` from a worktree.**
> The stack uses fixed `container_name` values (`web`, `db`, `opensearch`, etc.). A second `up`
> from the worktree collides with the running stack and corrupts both. The only safe compose verb
> from a worktree is `run --rm --no-deps`.

> **Always detached (`--detach`).**
> A detached HEAD has no tracking branch, so `git push` has no default target. This is the
> mechanical enforcement of branch-safety rule #16. Never create a worktree on a named branch
> unless you explicitly need to commit from it (you almost never do in this pattern).

> **Review-from-worktree: anchor reads to the worktree path.**
> When reviewing a PR in a worktree, every file read MUST be from the worktree directory or via
> `git show origin/<branch>:path`. Reading the main checkout (on a different branch) produces
> false positives — in ENG-582 / PR #4991 this nearly generated a HIGH "missing i18n key" finding
> that did not exist in the PR branch. Treat any "missing key / missing code" finding as suspect
> until re-verified from the correct ref.
>
> First action in any worktree review: confirm `git rev-parse --abbrev-ref HEAD` from inside the
> worktree is the PR branch, then anchor all subsequent reads there.

---

## Harness-Managed Isolation (Prefer When Available)

When working inside a Claude Code agent session, the harness supports automatic isolation:

- `EnterWorktree` tool — creates, enters, and auto-cleans an isolated worktree
- `isolation: "worktree"` in agent task config — same lifecycle management

**Prefer these for agent isolation.** The manual protocol above is for the human/dev-DB workflow
where compose network wiring, the gems volume, and the live dev DB must be shared.

---

## Hygiene (from obra/superpowers using-git-worktrees, MIT)

- Run `git worktree list` before creating a new one — confirm you are not already inside a linked worktree.
- Placement: always outside the repo root (use `../platform-<slug>`) to avoid polluting the git index and the running container's file watcher.
- Name with a short ticket/purpose slug (`platform-core624`, `platform-eng582-review`) for easy identification.
- After cleanup, `git worktree prune` removes stale administrative files from `.git/worktrees/`.

---

## Quick Reference

| Situation | Action |
|-----------|--------|
| Run branch B's rake against dev DB | This skill's manual protocol |
| Review PR branch in isolation | This skill + anchor reads to worktree path |
| Agent needs isolated checkout (no compose) | `EnterWorktree` / `isolation: worktree` (prefer) |
| Already in a linked worktree | Skip creation; verify HEAD is correct branch |
| After task completes | `git worktree remove --force` + `git worktree prune` |
| `docker compose up` from worktree | NEVER — use `run --rm --no-deps` |

---

## Kaizen

History archived → [`kaizen_log.md`](kaizen_log.md).
