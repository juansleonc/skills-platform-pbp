---
name: docker-exec
description: Reference for Docker execution. All scripts, runners, rspec, rake tasks, and Ruby commands MUST run in the Docker web container.
allowed-tools: [Bash, Edit]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

# Docker Execution Environment - MANDATORY

## CRITICAL RULE

**ALL Ruby/Rails commands MUST run in the Docker web container.**

Never run directly on host:
- ❌ `bundle exec rspec`
- ❌ `bundle exec rake`
- ❌ `bundle exec rails`
- ❌ `ruby script.rb`

Always use Docker (3 options, from shortest to most verbose):

```bash
# Option 1: bin/d wrapper (RECOMMENDED - shortest syntax)
bin/d rspec spec/models/user_spec.rb
bin/d rake 'task[args]'
bin/d rails console
bin/d rubocop -A file.rb

# Option 2: make targets
make test TEST_PATH=spec/models/user_spec.rb
make console
make rubocop FILE=file.rb

# Option 3: docker compose (most verbose)
docker compose exec web bundle exec rspec spec/...
docker compose exec web bundle exec rake 'task[args]'
docker compose exec web bundle exec rails console
```

## bin/d Quick Reference

| Command | Description |
|---------|-------------|
| `bin/d rspec <path>` | Run tests |
| `bin/d rails c` | Rails console |
| `bin/d rake '<task>'` | Run rake task |
| `bin/d rubocop -A <file>` | Lint file |
| `bin/d pronto` | Run pronto vs develop |
| `bin/d migrate` | Run migrations |
| `bin/d rollback [n]` | Rollback migrations |
| `bin/d sh` | Shell in container |
| `bin/d coverage` | Coverage delta |
| `bin/d coverage <file>` | Coverage for file |
| `bin/d status` | Service health check |
| `bin/d help` | Show all commands |

## Makefile Quick Reference

| Command | Description |
|---------|-------------|
| `make up` | Start all containers |
| `make down` | Stop all containers |
| `make status` | Check service health |
| `make logs-f` | Follow all logs |
| `make shell` | Bash in web container |
| `make console` | Rails console |
| `make test TEST_PATH=...` | Run tests |
| `make test-parallel` | Run all tests parallel |
| `make rubocop FILE=...` | Lint file |
| `make pronto` | Pronto vs develop |
| `make migrate` | Run migrations |
| `make coverage` | Coverage delta |
| `make help` | Show all targets |

## Detailed Reference

### Testing

```bash
# Single spec file (3 equivalent ways)
bin/d rspec spec/models/user_spec.rb
make test TEST_PATH=spec/models/user_spec.rb
docker compose exec -e RAILS_ENV=test web bundle exec rspec spec/models/user_spec.rb

# Multiple files
bin/d rspec spec/models/ spec/services/
make test TEST_PATH="spec/models/ spec/services/"

# Parallel tests (full suite)
bin/d parallel
make test-parallel

# Specific test line
bin/d rspec spec/models/user_spec.rb:45
make test TEST_PATH=spec/models/user_spec.rb:45

# With coverage report
make test-coverage TEST_PATH=spec/models/user_spec.rb
```

### Rake Tasks

```bash
# Coverage tasks
bin/d rake 'coverage:local:uncovered[10]'
bin/d rake 'coverage:validate:quick[spec/path_spec.rb]'
bin/d coverage              # Shortcut for coverage:local:delta
bin/d coverage app/models/user.rb  # Coverage for specific file

# Database tasks
bin/d migrate               # Or: make migrate
bin/d rollback              # Rollback 1 migration
bin/d rollback 3            # Rollback 3 migrations
bin/d seed                  # Or: make seed

# Custom tasks
bin/d rake 'task_name[args]'
```

### Rails Commands

```bash
# Console
bin/d rails c               # Or: bin/d c, make console

# Generators
bin/d rails generate model User
bin/d rails generate migration AddFieldToUsers

# Routes
bin/d routes                # Or: make routes
make routes GREP=users      # Filter routes
```

### Code Quality

**Linting Rules:**
- **Modified files** → Use **Pronto** (only checks changed lines, doesn't touch legacy)
- **New files** → Use **RuboCop** (full file analysis is OK for new code)

```bash
# Pronto - for MODIFIED files (only checks changed lines)
bin/d pronto                # Default: compare vs develop
make pronto                 # Same as above
make pronto PRONTO_COMMIT=main  # Compare vs different branch

# RuboCop - ONLY for NEW files
bin/d rubocop -A path/to/new_file.rb
make rubocop FILE=path/to/new_file.rb

# Brakeman (security)
bin/d brakeman
make brakeman

# All linters
make lint                   # rubocop + pronto
make ci                     # Full CI checks
```

**Why this distinction:**
- Legacy code should NOT be modified by linting
- New files can be fully linted since there's no legacy to preserve
- Pronto matches CI/CD pipeline behavior for PRs

### Interactive Debugging

```bash
# Open bash in container
bin/d sh                    # Or: bin/d bash, make shell
make web-bash

# ONLY INSIDE THE CONTAINER, you can run:
# bundle exec rspec spec/models/user_spec.rb
# bundle exec rails console
#
# ⚠️ NEVER run raw `bundle exec` from host machine - always use docker compose exec
```

### Database Access

```bash
# MySQL shell
bin/d db                    # Or: bin/d console-db
make db-shell

# Redis CLI
make redis-cli
```

## Container Management

```bash
# Start all containers
make up                     # Creates network if needed

# Stop containers
make down

# Restart web container
make restart                # Or: bin/d restart

# Restart Puma (faster than container restart)
make touch                  # Touches tmp/restart.txt

# Check service health
bin/d status
make status

# View logs
make logs-f                 # Follow all logs
make logs-web               # Web container only
make logs-sidekiq           # Sidekiq container

# First-time setup
make setup                  # network + build + up + db-setup
```

## Environment Variables

```bash
# Pass environment variables
docker compose exec -e RAILS_ENV=test web bundle exec rspec
docker compose exec -e DEBUG=true web bundle exec rails console

# bin/d automatically sets RAILS_ENV=test for rspec commands
```

## Why Docker?

1. **Consistency** - Same environment as CI/CD
2. **Dependencies** - All gems and services available
3. **Database** - MySQL runs in container
4. **Redis** - Redis runs in container
5. **Isolation** - No conflicts with host system

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new Docker command or Makefile target
- A missing environment variable pattern
- A better container workflow

**You MUST**:
1. Complete the current task first
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements**:

<!-- Kaizen: 2026-01-24 - bin/d wrapper and expanded Makefile -->
- Added `bin/d` wrapper script for short Docker commands
- Expanded Makefile with 50+ targets
- Updated docker-compose.yml with health checks and profiles
- Added `.env.example` for new developers
- Network auto-created (no longer external)
- Added mailcatcher service (profile: mail)
- Sidekiq now optional (profile: sidekiq or full)

<!-- Kaizen: 2026-01-23 - Test Production Scripts Locally -->
## ⚠️ MANDATORY: Test Production Scripts Before Sending

**ALWAYS test scripts in Docker container BEFORE sending to production.**

### Testing Pattern

```bash
# 1. Test Ruby syntax
docker compose exec web ruby -c tmp/script.rb

# 2. Test with simulated data (no DB)
docker compose exec web bundle exec rails runner "
  # Simulate production data
  class FakeMembership
    def id; 123; end
    def acquired_at; Time.parse('2026-01-19 05:00:00'); end
    def current_period_end_at; nil; end  # Test nil case!
  end

  membership = FakeMembership.new

  # Test the actual code
  now = Time.current.strftime('%Y-%m-%d %H:%M:%S')
  starts = membership.acquired_at ? membership.acquired_at.strftime('%Y-%m-%d %H:%M:%S') : now
  ends_at = membership.current_period_end_at ? membership.current_period_end_at.strftime('%Y-%m-%d %H:%M:%S') : (Time.current + 1.year).strftime('%Y-%m-%d %H:%M:%S')

  puts 'now: ' + now
  puts 'starts: ' + starts
  puts 'ends_at: ' + ends_at

  # Generate SQL for verification
  sql = \"INSERT INTO table (a, b, c) VALUES (1, '#{starts}', '#{ends_at}')\"
  puts 'SQL: ' + sql
"
```

### Checklist Before Sending to Production

- [ ] Syntax checked with `ruby -c`
- [ ] Nil values handled for all date/time fields
- [ ] Uses `strftime` instead of `to_s(:db)` (Ruby 3 compatible)
- [ ] No heredocs (use single-line strings)
- [ ] SQL generated and verified
- [ ] Commands provided step-by-step (not all at once)
