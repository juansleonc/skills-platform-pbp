---
name: fix-issue
description: Analyze GitHub issues and implement solutions with tests
allowed-tools: [Bash, Read, Write, Edit, Grep, Glob, mcp__github__*, mcp__honeybadger__list_faults, mcp__honeybadger__get_fault, mcp__sentry__sentry_list_projects, mcp__sentry__sentry_list_issues, mcp__sentry__sentry_get_issue, mcp__sentry__sentry_get_issue_events]
disable-model-invocation: true
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

# Fix GitHub Issue Skill

Analyze a GitHub issue, implement the solution, and create tests.

## Usage

```
/fix-issue <issue-number>
```

## Process

1. **Fetch issue details**
   ```bash
   gh issue view <number> --json title,body,labels,comments
   ```

2. **Check production errors** (if issue relates to runtime errors)

   **Honeybadger:**
   ```
   mcp__honeybadger__list_faults: project_id, q: "<search_term>"
   mcp__honeybadger__get_fault: project_id, fault_id
   ```

   **Sentry:**
   ```
   mcp__sentry__sentry_list_issues:
     org_slug: "sentry"
     project_slug: "platform"  # or graphql_pro, pbp-mobile, etc.
     query: "is:unresolved <search_term>"

   mcp__sentry__sentry_get_issue:
     issue_id: "<issue_id>"
   ```

   **Choose based on issue type:**
   | Issue Type | Check First |
   |------------|-------------|
   | Rails/Backend | Honeybadger |
   | GraphQL | Sentry `graphql_pro` |
   | Mobile | Sentry `pbp-mobile` |
   | Frontend | Sentry `platform-frontend-0j` |

3. **Analyze the issue**
   - Understand the problem
   - Identify affected files
   - Determine scope of fix

4. **Search codebase** for relevant code

5. **Create a plan**
   - Files to modify
   - Tests to add
   - Potential side effects

6. **Implement fix**
   - Write tests first (TDD)
   - Implement minimal fix
   - Run tests

7. **Validate** (all commands in Docker web container)
   ```bash
   # Run tests WITH coverage
   docker compose exec -e SIMPLECOV_REPORT=true web bundle exec rspec <affected_specs>  # bin/d rspec for plain run

   # For MODIFIED files - Pronto (preserves legacy code)
   bin/d pronto run -c develop

   # For NEW files only - RuboCop full lint
   bin/d rubocop -A <new_files>
   ```

8. **Verify 100% coverage on changes** (MANDATORY)
   ```bash
   bin/d rake 'coverage:local:file[<changed_file>]'
   # Must show 100% coverage on the changed file
   ```

9. **Create commit** (with user approval)

## Issue Analysis Template

```markdown
## Issue #<number>: <title>

### Problem
<description of the issue>

### Root Cause
<identified cause>

### Affected Files
- `app/models/user.rb` - Line 45
- `app/services/payment_service.rb` - Line 123

### Solution
<proposed fix>

### Test Plan
- [ ] Add unit test for edge case
- [ ] Verify existing tests pass
- [ ] Manual verification steps

### Risks
- <potential side effects>
```

## Commit Message Format

```
TICKET | fix(<scope>): <description>

Fixes #<issue-number>

- <change 1>
- <change 2>

```

## Example

```
User: /fix-issue 456

Claude:
## Issue #456: Users can't complete checkout when membership is expired

### Fetching issue details...
gh issue view 456 --json title,body,labels,comments

### Problem
Users with expired memberships are seeing a 500 error during checkout
instead of a friendly error message.

### Root Cause
`PaymentService::Checkout#validate_membership` raises an unhandled
exception when membership.expires_at is nil.

File: app/services/payment_service/checkout.rb:89
```ruby
def validate_membership
  raise MembershipExpiredError if membership.expires_at < Time.current
  #                                           ^^^^^^^^^ nil error
end
```

### Solution
Add nil check before comparison:
```ruby
def validate_membership
  return if membership.expires_at.nil?
  raise MembershipExpiredError if membership.expires_at < Time.current
end
```

### Test Plan
1. Add spec for nil expires_at case
2. Add spec for expired membership
3. Verify checkout flow handles error gracefully

### Implementation

Creating test first...
[writes spec]

Running test (should fail)...
❌ 1 example, 1 failure

Implementing fix...
[edits checkout.rb]

Running test...
✅ 1 example, 0 failures

Running full spec suite for affected files...
✅ 15 examples, 0 failures

### Ready to commit?
Proposed commit:
```
PLA-456 | fix(checkout): Handle nil membership expiration date

Fixes #456

- Add nil check in validate_membership
- Add spec for edge case

```

Create commit? (y/n)
```

---

## MCP Integrations

### GitHub MCP

Use for direct GitHub API access:

```
# Get issue details with comments
mcp__github__get_issue:
  owner: "playbypoint"
  repo: "platform"
  issue_number: 456

# List issue comments
mcp__github__list_issue_comments:
  owner: "playbypoint"
  repo: "platform"
  issue_number: 456

# Search for related issues
mcp__github__search_issues:
  q: "repo:playbypoint/platform is:issue membership"

# Get linked PR if exists
mcp__github__list_pull_requests:
  owner: "playbypoint"
  repo: "platform"
  state: "all"
  head: "fix/issue-456"
```

**Use Cases:**
- Get full issue context including comments
- Find related issues by searching
- Check if issue already has a linked PR
- Get issue labels and assignees

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new debugging pattern
- A missing analysis step
- A better issue template format

**You MUST**:
1. Complete the current issue fix first
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements**:
<!-- Kaizen entries will be added here -->
