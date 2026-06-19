# Package Health Scoring (optional)

> Heuristic rubric — NOT grounded in packwerk docs or a repo convention. It is a
> convenience for reporting, not decision logic the agent must branch on. Recomputed
> **without the privacy weight** (privacy checks do not run in this repo — see SKILL.md
> "Stack reality"). Owner may drop this entirely.

| Metric | Weight | Scoring |
|--------|--------|---------|
| Dependency violations | 2x | 0 = 100pts, 1-3 = 50pts, 4+ = 0pts |
| TODO items (package_todo.yml) | 1x | 0 = 100pts, 1-10 = 75pts, 11+ = 50pts |
| Table naming | Pass/Fail | Pass = 100pts, Fail = 0pts |

Weighted average → grade:

- **A**: 90-100 (Excellent)
- **B**: 75-89 (Good)
- **C**: 60-74 (Needs Work)
- **D**: below 60 (Critical)

## Compute counts per package

```bash
for pack in packs/*/; do
  name=$(basename "$pack")
  dependency=$(bin/d packwerk check "$pack" 2>&1 | grep -c "Dependency violation")
  todo_count=$(grep -c "^  -" "${pack}package_todo.yml" 2>/dev/null || echo 0)
  echo "$name: deps=$dependency, todos=$todo_count"
done
```
