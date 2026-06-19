---
name: docker-exec
description: Reference for Docker execution. All scripts, runners, rspec, rake tasks, and Ruby commands MUST run in the Docker web container.
allowed-tools: [Bash, Edit]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## When to Use

Invoke this skill whenever any Ruby/Rails command is about to run on the host machine. CLAUDE.local.md rule #2 is absolute: **ALL Ruby/Rails commands go through Docker — no exceptions.** `bin/d` is the canonical wrapper. The Makefile targets listed below are a secondary option for commands they cover.

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

# Option 2: make targets (only 11 real targets — use bin/d for everything else)
make test TEST_PATH=spec/models/user_spec.rb
make console
# Note: make rubocop does NOT exist — use bin/d rubocop -A file.rb

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
| `bin/d bundle exec pronto run -r rubocop -c develop -f text` | Run pronto (canonical per CLAUDE.local.md §3; shorthand: `bin/d pronto -r rubocop -c develop -f text`) |
| `bin/d migrate` | Run migrations |
| `bin/d rollback [n]` | Rollback migrations |
| `bin/d sh` | Shell in container |
| `bin/d coverage` | Coverage delta |
| `bin/d coverage <file>` | Coverage for file |
| `bin/d status` | Service health check |
| `bin/d up` | Start all containers (detached) |
| `bin/d down` | Stop and remove containers |
| `bin/d restart` | Restart the web container |
| `bin/d help` | Show all commands |

## Makefile Quick Reference

The Makefile has **11 real targets** (verified against `Makefile` 2026-06-10). Use `bin/d` for everything else.

| Command | Description |
|---------|-------------|
| `make build` | Build Docker image for development |
| `make build-no-cache` | Build Docker image without cache |
| `make containers-up` | Start all containers (detached-capable) |
| `make web-start` | Start containers and attach to web container |
| `make web-bash` | Open bash shell in web container |
| `make db-bash` | Open bash shell in database container |
| `make console` | Rails console in web container |
| `make migrate` | Run database migrations |
| `make test [TEST_PATH=...]` | Run rspec (default path: `spec`); accepts TEST_PATH variable |
| `make assets-precompile` | Precompile assets in web container |
| `make help` | Show all Makefile targets |

**Fictional targets that do NOT exist** (previously listed in error): `up`, `down`, `status`, `logs-f`, `shell`, `test-parallel`, `rubocop`, `pronto`, `setup`, `touch`, `db-shell`, `redis-cli`, `lint`, `ci`, `coverage`, `seed`, `routes`, `restart`, `brakeman`, `logs-web`, `logs-sidekiq`. Use `bin/d` equivalents for these operations.

## Detailed Reference

### Testing

```bash
# Single spec file
bin/d rspec spec/models/user_spec.rb
# OR via Makefile (TEST_PATH variable accepted):
make test TEST_PATH=spec/models/user_spec.rb
# OR verbose:
docker compose exec -e RAILS_ENV=test web bundle exec rspec spec/models/user_spec.rb

# Multiple files
bin/d rspec spec/models/ spec/services/
make test TEST_PATH="spec/models/ spec/services/"

# Parallel tests (full suite) — no Makefile target; use bin/d directly
bin/d rails parallel:spec

# Specific test line
bin/d rspec spec/models/user_spec.rb:45
make test TEST_PATH=spec/models/user_spec.rb:45

# With coverage report
docker compose exec -e SIMPLECOV_REPORT=true -e RAILS_ENV=test web bundle exec rspec spec/models/user_spec.rb
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
bin/d seed                  # Note: make seed does NOT exist in Makefile — use bin/d seed

# Custom tasks
bin/d rake 'task_name[args]'
```

### Rails Commands

```bash
# Console
bin/d rails c               # Or: bin/d c
make console                # Real Makefile target (checks container is running first)

# Generators
bin/d rails generate model User
bin/d rails generate migration AddFieldToUsers

# Routes
bin/d routes
# Note: make routes does NOT exist in Makefile — use bin/d routes
```

### Code Quality

**Linting Rules:**
- **Modified files** → Use **Pronto** (only checks changed lines, doesn't touch legacy)
- **New files** → Use **RuboCop** (full file analysis is OK for new code)

```bash
# Pronto - for MODIFIED files (only checks changed lines)
# PRIMARY form (authoritative per CLAUDE.local.md §3):
bin/d bundle exec pronto run -r rubocop -c develop -f text
# Shorthand alias (bin/d passes args through to `pronto run`):
# bin/d pronto -r rubocop -c develop -f text
# Note: make pronto does NOT exist in Makefile — use bin/d

# RuboCop - ONLY for NEW files
bin/d rubocop -A path/to/new_file.rb
# Note: make rubocop does NOT exist in Makefile — use bin/d

# Brakeman (security)
bin/d brakeman
# Note: make brakeman does NOT exist in Makefile — use bin/d

# Note: make lint and make ci do NOT exist — use bin/d commands individually
```

**Why this distinction:**
- Legacy code should NOT be modified by linting
- New files can be fully linted since there's no legacy to preserve
- Pronto matches CI/CD pipeline behavior for PRs

### Interactive Debugging

```bash
# Open bash in container
bin/d sh                    # Or: bin/d bash
make web-bash               # Real Makefile target

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
make db-bash                # Real Makefile target (opens bash in DB container)
# Note: make db-shell does NOT exist in Makefile — use bin/d db or make db-bash

# Redis CLI
# Note: make redis-cli does NOT exist in Makefile — use: bin/d sh + redis-cli inside container
```

## Container Management

```bash
# Start all containers
bin/d up                    # Start all containers (detached) — bin/d native
make containers-up          # Real Makefile target (same effect)
make web-start              # Start and attach to web container
# Note: make up does NOT exist in Makefile — use bin/d up

# Stop containers
bin/d down                  # Stop and remove containers — bin/d native
# Note: make down does NOT exist in Makefile — use bin/d down

# Restart web container
bin/d restart               # Restart the web container (docker compose restart web)
# Note: make restart does NOT exist in Makefile — use bin/d restart

# Restart Puma (faster than container restart — no docker stop/start)
touch tmp/restart.txt       # From host: signal Puma to reload
# Or: bin/d sh then touch tmp/restart.txt inside container
# Note: make touch does NOT exist — use touch tmp/restart.txt directly

# Check service health
bin/d status
# Note: make status does NOT exist in Makefile — use bin/d status or docker compose ps

# View logs
# Note: make logs-f / make logs-web / make logs-sidekiq do NOT exist in Makefile
# Use: docker compose logs -f web   OR   docker compose logs -f sidekiq

# Build image
make build                  # Build Docker image (use after Dockerfile changes)
make build-no-cache         # Build without cache
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
2. Then run `/kaizen` to propose the improvement — do NOT self-edit this skill file mid-execution

**Full changelog:** See [`kaizen_log.md`](.claude/skills/docker-exec/kaizen_log.md) in this directory.
