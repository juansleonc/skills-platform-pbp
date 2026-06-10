# Configuration Priority System

> **Used by ALL skills** - Explains how config files work together

## Priority Order (Highest to Lowest)

```
1. 🥇 CLAUDE.local.md    ← HIGHEST PRIORITY (personal, not committed)
2. 🥈 CLAUDE.md          ← Team-wide rules (committed to repo)
3. 🥉 Skill defaults     ← Built-in skill behavior
```

## Understanding the Files

### CLAUDE.md (Team-wide Rules)
- **For**: ALL developers
- **Committed**: ✅ Yes (git tracked)
- **Purpose**: Project standards everyone must follow
- **Examples**:
  - Tech stack versions
  - Critical rules (timezone, multi-tenancy)
  - Git workflow
  - Package architecture
  - Code standards

**NEVER override** critical project rules from CLAUDE.md like:
- Multi-tenancy (facility_id scoping)
- Timezone safety (Time.current)
- Financial transactions rules
- API compatibility
- PCI compliance

### CLAUDE.local.md (Personal Rules)
- **For**: YOU only
- **Committed**: ❌ No (in .gitignore)
- **Purpose**: Your personal workflow preferences
- **Examples**:
  - Docker vs local execution
  - Linting preferences (Pronto vs RuboCop)
  - TDD style preferences
  - Coverage targets
  - Factory preferences
  - Commit message style

**CAN override** from CLAUDE.md:
- Execution environment (Docker commands)
- Tool choices (linting, testing)
- Workflow preferences
- Personal code style

## How Skills Use This

Every skill includes this reminder at the top:

```markdown
> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.
```

## When Claude Reads Config

### Step 1: Check CLAUDE.local.md First
```
Does CLAUDE.local.md have rule for this?
├─ YES → Use that rule (DONE)
└─ NO  → Continue to Step 2
```

### Step 2: Check CLAUDE.md
```
Does CLAUDE.md have rule for this?
├─ YES → Use that rule (DONE)
└─ NO  → Use skill default
```

## Examples

### Example 1: Docker Execution

**CLAUDE.md says**:
```bash
# Run tests
bundle exec rspec spec/models/user_spec.rb
```

**CLAUDE.local.md says**:
```bash
# ✅ SIEMPRE usar Docker
docker compose exec web bundle exec rspec spec/models/user_spec.rb
# O usar: bin/d rspec spec/models/user_spec.rb
```

**Claude uses**: CLAUDE.local.md (Docker) ✅

### Example 2: Linting

**CLAUDE.md says**:
```bash
# Before committing
bundle exec rubocop -A
bundle exec pronto run -c develop
```

**CLAUDE.local.md says**:
```bash
# Archivos MODIFICADOS → Pronto
docker compose exec web bundle exec pronto run -c develop

# Archivos NUEVOS → RuboCop
docker compose exec web bundle exec rubocop -A new_file.rb
```

**Claude uses**: CLAUDE.local.md (modified files use Pronto) ✅

### Example 3: Critical Rule (No Override)

**CLAUDE.md says**:
```ruby
# CRITICAL: Never use Time.now
Time.current  # ✅ Always use this
```

**CLAUDE.local.md should NOT override** critical project rules.

**Claude uses**: CLAUDE.md (critical rule) ✅

## Conflict Resolution

### Scenario 1: Direct Conflict

**CLAUDE.md**: Use RuboCop on all files
**CLAUDE.local.md**: Use Pronto on modified files

**Resolution**: CLAUDE.local.md wins (personal preference) ✅

### Scenario 2: Critical Rule

**CLAUDE.md**: NEVER use Time.now (critical)
**CLAUDE.local.md**: (should not override this)

**Resolution**: CLAUDE.md wins (critical project rule) ✅

### Scenario 3: Not Specified in Either

**CLAUDE.md**: (doesn't mention)
**CLAUDE.local.md**: (doesn't mention)

**Resolution**: Use skill default behavior ✅

## Creating Your CLAUDE.local.md

If you don't have one, create it:

```bash
# Create file
touch CLAUDE.local.md

# Verify it's in .gitignore
grep CLAUDE.local.md .gitignore
# Should output: /CLAUDE.local.md
```

Template:
```markdown
# CLAUDE.local.md - Personal Development Rules

> **PRIORITY**: This file OVERRIDES CLAUDE.md for personal preferences

## Reglas Adicionales (Locales)

### 1. Execution Environment
**Todos los comandos en Docker.**

```bash
# Usar Docker siempre
bin/d rspec spec/...
bin/d rails c
```

### 2. Linting
- Archivos modificados → Pronto
- Archivos nuevos → RuboCop -A

### 3. TDD
- SIEMPRE TDD first
- 100% coverage en cambios

### 4. Factory Rules
- build > create (default)
- create solo para DB queries

### 5. Commit Style
- NUNCA mencionar Claude/AI en commits
```

## Validation

Skills should validate config priority:

```bash
# In any skill execution:
1. Read CLAUDE.local.md (if exists)
2. Read CLAUDE.md
3. Apply priority rules
4. Execute with correct config
```

## Best Practices

### For Developers

✅ **DO**:
- Put personal preferences in CLAUDE.local.md
- Keep CLAUDE.local.md in .gitignore
- Respect critical rules from CLAUDE.md
- Document your overrides clearly

❌ **DON'T**:
- Commit CLAUDE.local.md to repo
- Override critical project rules
- Ignore CLAUDE.md completely
- Put team rules in CLAUDE.local.md

### For Claude

✅ **ALWAYS**:
1. Check CLAUDE.local.md FIRST
2. Then check CLAUDE.md
3. Apply priority correctly
4. Respect critical rules
5. Mention which config was used (if ambiguous)

❌ **NEVER**:
- Ignore CLAUDE.local.md if it exists
- Override critical project rules with local preferences
- Assume CLAUDE.md is always correct
- Mix up the priority order

## Troubleshooting

### "Claude is not using my local preferences"

**Check**:
```bash
# 1. File exists?
ls -la CLAUDE.local.md

# 2. In gitignore?
grep CLAUDE.local.md .gitignore

# 3. Has content?
head -20 CLAUDE.local.md

# 4. Properly formatted?
# Should have clear sections and rules
```

### "Rules conflict between files"

**Resolution**:
1. Is it a critical project rule? → CLAUDE.md wins
2. Is it a personal preference? → CLAUDE.local.md wins
3. Still unclear? → Ask user for clarification

### "Not sure which file to update"

**Ask yourself**:
- Is this for ALL developers? → CLAUDE.md
- Is this just for me? → CLAUDE.local.md
- Is this critical for project? → CLAUDE.md
- Is this workflow preference? → CLAUDE.local.md

---

## Summary

```
┌─────────────────────────────────────────┐
│ Config Priority System                  │
│                                         │
│ 1. CLAUDE.local.md (personal, highest)  │
│    ↓ if not found                       │
│ 2. CLAUDE.md (team-wide)                │
│    ↓ if not found                       │
│ 3. Skill defaults                       │
└─────────────────────────────────────────┘

Key Rules:
✅ Local overrides team (for preferences)
✅ Team defines critical rules
✅ Always check BOTH files
❌ Never commit CLAUDE.local.md
❌ Never override critical rules locally
```
