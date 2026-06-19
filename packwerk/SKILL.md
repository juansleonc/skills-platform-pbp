---
name: packwerk
description: Validate Packwerk package boundaries, declared cross-package dependencies, and table-naming conventions. Use when adding or refactoring a pack, creating a cross-package dependency, reviewing a PR that touches multiple packs, or before deploying package changes. (allowed-tools / disable-model-invocation below are Claude-Code harness extensions; a portable spec needs only name + description.)
allowed-tools: [Bash, Read, Grep, Glob, Edit]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting). Check both for current conventions.

# Packwerk Validation Skill

Validate package boundaries and dependencies in the modular architecture. All commands run in the Docker web container (`bin/d`).

## Stack reality (read first)

This repo runs **packwerk 3.2.2** with **no `packwerk-extensions` gem** in the Gemfile.

- **`enforce_privacy` was removed in Packwerk 3.0** and now lives in `packwerk-extensions` (not installed). So `bin/d packwerk check` **cannot emit "Privacy violation"** lines, and the `enforce_privacy` keys still present in a few `package.yml` files (`agents_cli`, `billing` = true; `internal_backend`, `internal_frontend` = false) are **inert vestiges** — do not grep for or score on privacy.
- The only violation class core packwerk enforces here is **Dependency violation**. Table-naming is a custom grep, not a packwerk check.
- Modern alternative to TODO-based suppression: set `enforce_dependencies: strict` in package.yml to block NEW violations (owner decision — see deferred items, not applied by this skill).

<details><summary>Packwerk 2.x → 3.x naming (old muscle memory)</summary>

`update-deprecations` → `update-todo`; `deprecated_references.yml` → `package_todo.yml`. No `deprecated_references.yml` files exist in this repo.
</details>

## When to Use

- Adding a new pack to `/packs` (validate structure + table naming)
- Creating a cross-package dependency (ensure it's declared in package.yml)
- Reviewing a PR that touches multiple packs (detect undeclared dependencies)
- Before deploying package changes

Pack inventory + asset-pipeline list → **[reference/packs.md](reference/packs.md)** (live source of truth: `ls -d packs/*/`; `CLAUDE.md` list is a stale summary).

## Commands

All run in Docker. "Expected" = 0 NEW in changed lines; state the legacy baseline if non-zero.

| # | Command | Checks | Expected |
|---|---------|--------|----------|
| 1 | `bin/d packwerk validate` | package.yml structure | `Validation successful` |
| 2 | `bin/d packwerk check` | dependency violations (all packs) | `No violations detected` or a list |
| 3 | `bin/d packwerk check packs/<name>` | one pack | same, scoped |
| 4 | `bin/d packwerk update-todo` | record remaining violations | updates `package_todo.yml` |
| 5 | `grep -r "create_table" packs/*/db/migrate/ \| grep -vE "create_table[( ]:?\w+_"` | unprefixed tables | 0 matches |

Per-pack violation counts:

```bash
for pack in packs/*/; do
  echo "$(basename "$pack"): $(bin/d packwerk check "$pack" 2>&1 | grep -c 'Dependency violation')"
done
```

After fixing code, `bin/d packwerk update-todo` then `git diff packs/*/package_todo.yml` — removed lines (`-`) confirm violations cleared. Use `Grep`/`Glob` for symbol-level discovery.

## Process / checklist

1. `bin/d packwerk validate` — structure valid? (halt if not)
2. `bin/d packwerk check` — list dependency violations
3. Verify table naming (command 5)
4. Review `package.yml` deps; review `package_todo.yml` entries
5. (Optional) compute health scores → **[reference/health-scoring.md](reference/health-scoring.md)**
6. Produce the analysis → **[reference/output-template.md](reference/output-template.md)**

## Conventions

### Table naming (MANDATORY)

Every package table MUST be prefixed with the package name — `webhooks_urls`, `audit_logs_events`, `feature_flag_settings`, `game_match_waivers`. Validate with command 5 above.

### Dependencies declaration

```yaml
# packs/book_a_pro/package.yml
enforce_dependencies: true
dependencies:
  - packs/feature_flag
```

Undeclared usage → Dependency violation. Fix by adding the pack to `dependencies:`, or `bin/d packwerk update-todo` to record it.

### Asset pipelines

Frontend packs (`webhooks`, `page_builder`, `orgs_frontend`) build their own JS/CSS — rebuild after changes (`yarn --cwd packs/<pack> build`). See [reference/packs.md](reference/packs.md).

## Testing packages

```bash
make test TEST_PATH=packs/webhooks/spec          # one pack
make test TEST_PATH="packs/**/spec"              # all packs
make test TEST_PATH=packs/audit_logs/spec/models/audit_log_spec.rb  # one file
```

## Examples & output

- Violation examples (dependency, table naming; privacy/circular are teaching-only) → **[reference/violation-examples.md](reference/violation-examples.md)**
- Analysis output template + example → **[reference/output-template.md](reference/output-template.md)**

---

## Related Skills

- **`/code-review`** — review includes package boundary checks
- **`/architect`** — design decisions affect package structure/dependencies
- **`/migration`** — migrations must follow table-naming (package prefix)
- **`/performance`** — cross-package N+1 (use `includes`)
- **`/multi-tenancy`** — package resolvers must scope by `facility_id`

**Workflow**: `/orchestrate feature` includes packwerk validation for package changes.

---

## Kaizen: Continuous Improvement

> "Every day we must improve" — 改善

If you discover a new package, missing convention, or better validation approach while running this skill, note it and run `/kaizen` after the validation completes — do NOT self-edit this file mid-execution. History → [`kaizen_log.md`](kaizen_log.md).
