# Troubleshooting Guides Index

> **⚠️ Operations Guides**: These are for manual troubleshooting and production operations, **NOT** for code validation workflows.
>
> For code validation, see the `/skills` directory.

## Overview

This directory contains operational guides separated from validation skills to maintain **separation of concerns**:

- **Skills** (`/.claude/skills/`) → Focus on code validation workflows
- **Troubleshooting** (`/.claude/shared/troubleshooting/`) → Focus on manual operations and fixes
- **Location**: `.claude/` directory (NOT tracked by git - personal/local documentation)

## Available Guides

### Production Operations

| Guide | Purpose | Related Skills |
|-------|---------|----------------|
| [Rails Console Best Practices](rails-console-best-practices.md) | Ruby 3 syntax, nil handling, Docker testing, callback-safe operations | `/debug` |
| [Membership Payment Fixes](membership-payment-fixes.md) | Manual fixes for orphaned payments, direct SQL patterns | `/memberships`, `/debug` |

> **Note**: Project-specific troubleshooting documentation (like Ruby 3 migration history) may remain in `/docs/troubleshooting/` as project documentation. This directory contains **skill-specific** operational guides.

## When to Use These Guides

**Use troubleshooting guides when:**
- Fixing production data manually via Rails console
- Performing one-off operations outside normal workflows
- Debugging issues that require direct SQL or console access
- Following step-by-step procedures for known issues

**Use skills instead when:**
- Validating code changes before merging
- Running audits on new features
- Checking for patterns across the codebase
- Ensuring quality standards

## Contributing

When adding new troubleshooting guides:

1. **Separate concerns**: Operational procedures go here, not in skills
2. **Cross-reference**: Link to related skills in the guide
3. **Update this index**: Add your guide to the table above
4. **Format**: Use the template below

### Guide Template

```markdown
# [Feature] Manual Operations

> **⚠️ Operations Guide**: This is for manual troubleshooting, not code validation.
>
> For code validation, see `/skill-name` skill.

## When to Use

[When this guide applies]

## Investigation Steps

[How to investigate the issue]

## Fix Pattern

[Step-by-step fix procedures]

## ⚠️ Common Pitfalls

[Known gotchas and mistakes to avoid]

## See Also

- `/skill-name` skill - For code validation
- [Other Guide](other-guide.md) - Related operations
```

## Pattern: Embedded Operational Procedures

**Discovered**: 2026-01-26 via Kaizen
**Issue**: Skills were embedding 60+ lines of operational procedures

**Solution**: Extract to `/docs/troubleshooting/` and add reference in skill

**Benefits**:
- ✅ Skills stay focused on validation workflows
- ✅ Operational guides are findable and maintainable
- ✅ No redundancy between different skills
- ✅ Clear separation of concerns

**Skills improved**:
- `/memberships`: Extracted 75 lines → [membership-payment-fixes.md](membership-payment-fixes.md)
- `/debug`: Extracted 67 lines → [rails-console-best-practices.md](rails-console-best-practices.md)

**Location**: All guides in `.claude/shared/troubleshooting/` (personal, not tracked by git)

## Maintenance

This index is maintained by the `/kaizen` skill during ecosystem audits. When kaizen detects operational procedures embedded in skills, they are extracted here.

**Last updated**: 2026-01-26
**Guides count**: 2 (skill-specific operational guides)
**Skills cross-referenced**: 2 (debug, memberships)
**Location**: `.claude/shared/troubleshooting/` (NOT tracked by git)

<!-- Kaizen: 2026-01-26 - Location corrected: Moved from docs/ to .claude/shared/ -->
