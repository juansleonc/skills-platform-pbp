# Packwerk Output Template

> Canned analysis-output template + example. Pointer-only from SKILL.md.
> Privacy is intentionally absent: this repo's packwerk (3.2.2, no extensions) does
> not run privacy checks. Surface only **Dependency** + **Table naming** + **TODOs**.

## Analysis template

```markdown
## Packwerk Analysis

### Summary
- Packages checked: N (run `ls -d packs/*/ | wc -l` for current count)
- Dependency violations: X
- Table naming issues: Y
- TODO entries (package_todo.yml): Z

### Package Health
| Package | Deps | TODOs | Tables | Status |
|---------|------|-------|--------|--------|
| audit_logs | 0 | 0 | ✅ | Healthy |
| merchandise | 2 | 5 | ✅ | Needs work |

### Violations

#### packs/merchandise
- [ ] Dependency: Using `FeatureFlag::Setting` without declaration
  - File: <substitute real file:line from packwerk output>
  - Fix: Add `packs/feature_flag` to `dependencies:` in package.yml,
    or run `bin/d packwerk update-todo` to record it as a known TODO.

### Table Naming Issues
- [ ] `packs/new_pack/db/migrate/001_create_items.rb`
  - Should be: `create_table :new_pack_items`

### Recommendations
1. Add missing dependency declarations.
2. Fix table naming in migrations (package prefix).
3. Run `bin/d packwerk update-todo` after fixes.
4. Consider `enforce_dependencies: strict` to block NEW violations instead of
   suppressing them via package_todo.yml (owner decision).
```

## Appending a dependency non-interactively

```bash
# Interactive: bin/d sh, then edit package.yml. For non-interactive heredoc append:
docker compose exec web bash -c "cat >> packs/merchandise/package.yml << 'EOF'
dependencies:
  - packs/feature_flag
EOF"
```

## Example output (all healthy)

```
## Packwerk Analysis

### Summary
- Packages checked: 18
- Dependency violations: 0
- Table naming issues: 0

(all packages: Deps OK, Tables OK → Healthy)
No action needed.
```
