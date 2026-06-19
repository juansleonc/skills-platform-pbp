# Safe Script Template

Copyable starting point for a safe runner script. The canonical, ready-to-copy
version lives at [`scripts/template.rb`](../scripts/template.rb) — copy that file
into `scripts/fix_name.rb` and fill in `process_records` / `fix_record`.

## Structure every safe script follows

- Class with `.run(dry_run:)` → `#execute(dry_run:)`.
- `execute` logs mode/env, calls `confirmed?`, wraps work in a single
  `ActiveRecord::Base.transaction`, raises `ActiveRecord::Rollback` when `dry_run`.
- `rescue StandardError` logs message + first 5 backtrace lines and re-raises.
- Defaults to dry-run; `LIVE=true` env var flips to live.

## Headless-safe confirmation (correctness)

The prescribed run path is `bin/d runner ...` (docker compose exec) and, in prod,
in-pod `rails runner`. Both can be **non-TTY**. A naive `$stdin.gets.chomp` either
hangs forever (waiting on input that never arrives) or raises `NoMethodError`
(`nil.chomp`) under `docker compose exec -T` / piped stdin.

The template guards for this:

```ruby
def confirmed?(dry_run)
  return true if dry_run

  # Non-TTY (docker exec -T, piped, in-pod): require explicit env confirmation
  # instead of a prompt that would hang or crash on nil stdin.
  return ENV['CONFIRM'] == 'yes' unless $stdin.tty?

  print "\n⚠️  LIVE MODE - This will modify production data!\n"
  print "Type 'yes' to continue: "
  $stdin.gets.to_s.chomp.downcase == 'yes'
end
```

- Interactive TTY → still prompts for `yes`.
- Non-TTY live run → requires `CONFIRM=yes`; otherwise aborts safely (never hangs).
- `$stdin.gets.to_s` makes the chomp nil-safe even on the TTY path.

## Invocation

```bash
# Docker dev — dry-run (default)
bin/d runner scripts/fix_name.rb

# Docker dev — live (TTY prompt) / headless live
LIVE=true bin/d runner scripts/fix_name.rb
LIVE=true CONFIRM=yes docker compose exec -T web rails runner scripts/fix_name.rb

# Production — INSIDE the prod pod/runner, NOT bin/d (see SKILL.md workflow note)
rails runner scripts/fix_name.rb                 # dry-run
LIVE=true CONFIRM=yes rails runner scripts/fix_name.rb   # live
```
