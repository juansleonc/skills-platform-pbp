# ast-grep Patterns — AST-Aware Search for Ruby

> **Optional enrichment, never a dependency.** `ast-grep` (`sg` CLI) is a single-binary tool that matches structural Ruby AST patterns instead of text. Skills must work *with or without* `sg` installed. When available, prefer it for the operations below; otherwise fall back to `grep` cleanly.

## Availability check

`ast-grep` is enabled when `which sg` (or `which ast-grep`) returns a path. Both binaries ship together via `brew install ast-grep`.

```bash
which sg >/dev/null 2>&1 && sg --version | grep -q "^ast-grep" && echo "ast-grep available"
```

If absent, **do not call `sg`** — fall back to `grep`. A skill must never block on ast-grep being installed.

## When to prefer ast-grep over grep

| Task | Tool | Why |
|---|---|---|
| Find a real method call (not in a string / comment / heredoc) | `sg run --lang ruby --pattern '<call>'` | Grep matches text inside strings and comments; sg matches only AST `call_expression` nodes |
| Find a DSL declaration (`has_many :foo, as: :bar`, `belongs_to`, `can :action, Model`) with structured captures | `sg run --pattern '<dsl_pat>' --json=stream` | Returns file + line + named captures (`$NAME`, `$ARG`, `$ACTION`, `$MODEL`) instead of raw text |
| Audit Sidekiq calls with specific argument shape (`*.perform_async(payment.id)`) | `sg run --pattern '$JOB.perform_async($ARG)' --json=stream` then filter | Structural argument matching impossible with regex |
| Eliminate `grep -v "# BAD"` heuristics | `sg` with the call pattern | sg ignores comments by AST kind — no heuristic filter needed |
| Polymorphic association inventory (`has_many ..., as: :x`) | `sg run --pattern 'has_many $NAME, as: $ASSOC'` | No false positives from message strings or hash literals |

## When grep is still the right tool

- **Plain text search** — feature flag keys, translation keys, configuration strings, log messages — grep is faster and simpler.
- **String literals** — searching for a known string value across the codebase. ast-grep treats strings as opaque nodes.
- **Comments by intent** — sometimes you *want* to find every comment mentioning "TODO" or "HACK" — grep is correct.
- **File globs / paths** — `grep -rl` to enumerate files matching a pattern. ast-grep doesn't replace file enumeration.
- **Non-Ruby files** — Markdown, YAML, JSON, ERB views, etc. (ast-grep supports many languages but this codebase's Ruby concentration is what matters.)
- **Dynamic dispatch** — `.constantize`, `send`, `method_missing`. Same limit as the Serena spike's G4 — no static tool can resolve these. Stay with grep + manual reasoning.

## Pattern syntax (brief)

```ruby
# Exact match
sg run --lang ruby --pattern 'Time.now' .

# Metavariable (captures any single AST node)
sg run --lang ruby --pattern '$M.find(params[:id])' .

# Multi-node "rest" (zero or more siblings)
sg run --lang ruby --pattern 'can $ACTION, $MODEL do |$X| $$$BODY end' .

# Structured output
sg run --lang ruby --pattern '...' --json=stream .
```

For complex predicates (e.g. "match X only when surrounded by scope Y"), write a YAML rule file and invoke with `sg scan -r rule.yml`.

Full reference: https://ast-grep.github.io/guide/pattern-syntax.html

## Gotchas (observed during the spike — 2026-05-19)

### G1 — Line-anchored output inflates raw counts

A multi-line `can [\n :a, :b\n], Model do … end` returns multiple output lines for one AST match. Counting `grep -cE "^[^:]+\.rb:"` overcounts. Use `--json=stream | wc -l` for true match count.

### G2 — Complex predicates need YAML rule files

A one-liner pattern matches a single AST shape. "Find X where the surrounding method scope does NOT reference Y" needs a YAML rule with `inside` / `has` / `not` constraints. Inline patterns get you 80 %; rule files get the remaining 20 %.

### G3 — Shell quoting on `$$$` rest-captures

The `$$$` rest-capture syntax is shell-special. Always single-quote the entire pattern. For complex patterns with embedded quotes, write to a YAML rule file instead.

### G4 — Tree-sitter Ruby is solid but not complete

Same caveat as Serena's G5 / F4: pure static parsing cannot resolve `.constantize`, `send`, `method_missing`, or polymorphic runtime dispatch. ast-grep helps with everything *up to* the dynamic-dispatch boundary, then stops.

### G5 — `sg` parses on demand (no index)

No cache to manage, but every query re-parses the target files. Typical query on `app/ + packs/` takes ~1 s. For skills running 10+ patterns sequentially, use `sg scan -r rules.yml` to run many rules in one pass.

## Mandatory behaviour when ast-grep IS available

For Ruby pattern-detection in code (not text):

1. **For "find every real call to X"** — prefer `sg run --pattern 'X'` over `grep "X"`. AST matching eliminates comment/string false positives.
2. **For DSL declarations** — prefer `sg` with metavariable captures over grep. The structured output unlocks downstream automation.
3. **For audit reports** — pipe `sg --json=stream` to a parser. This is impossible with grep alone.
4. **For dynamic dispatch / interpolated calls** — fall back to grep + manual reasoning. ast-grep cannot help.

## Mandatory behaviour when ast-grep is NOT available

1. Use `grep` as the existing skills already do. Existing patterns are still correct, just lossier.
2. Do not block, error, or warn — absence is the default state on most machines.
3. Do not install `ast-grep` from a skill. Adoption is a per-developer decision (`brew install ast-grep`).

## Skill integration pattern

When invoking `sg` from a skill body, gate on availability:

```bash
if command -v sg >/dev/null 2>&1; then
  # AST-aware path
  sg run --lang ruby --pattern '$M.find(params[:id])' app/ packs/
else
  # Grep fallback
  grep -rn "\.find(params\[:id\])" app/ packs/ --include="*.rb"
fi
```

## Spike reference

The full A/B benchmark (5 platform-specific queries, all 5 won by ast-grep), friction inventory, and adoption decision live at `investigations/ast-grep-spike/results/conclusion.md`. Read that before proposing structural changes to this document.
