# Structural Thresholds

Shared thresholds used by `/code-smells`, `/code-review`, and `/rails-audit` for consistent structural quality assessment.

## Thresholds Table

| Metric | Warning | Critical | Applies To |
|--------|---------|----------|------------|
| Model lines | >200 | >400 | `app/models/*.rb` |
| Controller lines | >150 | >300 | `app/controllers/**/*.rb` |
| Method lines | >10 | >20 | All Ruby files |
| Controller actions | >7 | >10 | Controllers (public methods) |
| Method parameters | >3 | >5 | All Ruby methods |
| Callbacks per model | >5 | >8 | `before_*`, `after_*`, `around_*` |
| Demeter chain depth | >3 | >5 | `a.b.c.d` chains |
| Includes per model | >5 | >8 | `include` / `extend` statements |
| Queries in views | >0 | >0 | `.where`, `.find`, `.find_by` in views |
| Associations per model | >10 | >20 | `has_many`, `has_one`, `belongs_to` |
| Scopes per model | >10 | >20 | `scope :name` declarations |
| Public methods per model | >20 | >40 | `def method_name` (non-private) |

## Severity Indicators

- **Warning** (🟡): Track and plan improvement. Acceptable in legacy code.
- **Critical** (🔴): Must address before adding more code. Block in code review for new files.

## Context-Specific Adjustments

### Legacy Code
For files that existed before 2025, apply relaxed thresholds:
- Model lines: Warning at >300, Critical at >500
- Controller lines: Warning at >200, Critical at >400

### New Code
For files created in current branch, apply strict thresholds (table values above).

## Detection Commands

```bash
# Fat models
wc -l app/models/*.rb | sort -rn | awk '$1 > 200 {print "WARNING:", $0} $1 > 400 {print "CRITICAL:", $0}'

# Fat controllers
find app/controllers -name "*.rb" -exec wc -l {} + | sort -rn | awk '$1 > 150 && !/total/ {print}'

# Long methods
awk '/def [a-z]/{start=NR; name=$2} /^[[:space:]]*end$/{len=NR-start; if(len>15) print FILENAME ":" start ": " name " (" len " lines)"}' <file>

# Callback count per model
for f in app/models/*.rb; do
  count=$(grep -c "before_\|after_\|around_" "$f" 2>/dev/null)
  [ "$count" -gt 5 ] && echo "$f: $count callbacks"
done

# Demeter violations
grep -rn '\.\w\+\.\w\+\.\w\+\.\w\+' app/ --include="*.rb" | grep -v "#\|spec\|test\|Rails\.\|ActiveRecord\."
```

## Layer Health Metrics

> Inspired by palkan's "Layered Design for Ruby on Rails Applications"

| Metric | Healthy | Warning | Detection |
|--------|---------|---------|-----------|
| Upward deps in models | 0 | >0 | Models calling Mailers/Services/Jobs |
| Single-model concerns | <20% | >50% | Concerns used by only 1 model |
| Callback score avg | >3.5 | <2.5 | Manual assessment per `/code-smells` scoring rubric |
| Anemic jobs | <10% | >30% | Heuristic via `/sidekiq` check #5 |
| Controller business logic | 0 | >0 | `.save`/`.update`/`.transaction` in controllers |

### Detection Commands (Thresholds Table Metrics)

```bash
# Associations per model
for f in app/models/*.rb; do
  count=$(grep -c "has_many\|has_one\|belongs_to\|has_and_belongs_to_many" "$f" 2>/dev/null)
  if [ "$count" -gt 10 ]; then
    echo "⚠️ $f: $count associations"
  fi
done

# Scopes per model
for f in app/models/*.rb; do
  count=$(grep -c "^[[:space:]]*scope :" "$f" 2>/dev/null)
  if [ "$count" -gt 10 ]; then
    echo "⚠️ $f: $count scopes"
  fi
done

# Public methods per model (before first private/protected)
for f in app/models/*.rb; do
  count=$(awk '/^[[:space:]]*(private|protected)/{exit} /def [a-z]/{c++} END{print c+0}' "$f")
  if [ "$count" -gt 20 ]; then
    echo "⚠️ $f: $count public methods"
  fi
done
```

## Used By

- [Code Smells Skill](../code-smells/SKILL.md)
- [Code Review Skill](../code-review/SKILL.md) — Step 2.7
- [Rails Audit Skill](../rails-audit/SKILL.md) — Phase 1
