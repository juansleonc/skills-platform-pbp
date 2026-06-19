---
name: create-pr
description: Create pull requests with proper formatting using gh CLI
allowed-tools: [Bash, Read, Grep, Glob, Edit, mcp__github__*]
disable-model-invocation: true
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## ⛔ Critical Rules

**NEVER execute `git push` or `gh pr create` without explicit user approval.**

Before pushing or creating PR:
1. Show branch status and commits summary
2. Show proposed PR title and description
3. Ask explicitly: "Ready to push and create PR? (y/n)"
4. **WAIT** for user to respond "y" or "yes"
5. Only then execute git push and gh pr create

---

# Create Pull Request Skill

Create well-formatted pull requests following project standards.

## Process

1. **Gather context**
   ```bash
   git status
   git log develop..HEAD --oneline
   git diff develop...HEAD --stat
   ```

2. **Check branch status**
   - Verify branch is pushed to remote
   - If not, push with `-u` flag

3. **Analyze all commits** in the branch (not just the latest)

4. **Create PR** using `gh pr create` with proper template

## PR Template Format

Use the project's `PULL_REQUEST_TEMPLATE.md` format. Include only relevant sections:

```markdown
**Background**

<1-2 paragraphs explaining business context. A new team member should understand what the PR is about.>

<Optional: Technical context if needed>

**Attention**

* Feature needs to be communicated to staff before merging/Feature can be deployed anytime
* Includes (blocking) migration (create / drop table)
* New to enable `specific_rule` to do something
* `SomeWorker` or rake task used to do something
* Before/after deploy, run on console `rake update_stuff`

**Reference**

* [JIRA](https://paybycourt.atlassian.net/browse/TICKET)
* [Honey Badger]()
* [Design Doc]()

**Technical Diagrams (Mermaid) &/or Screenshots**

<details>
  <summary>Screenshot description</summary>

  Collapsible and repeatable section for multiple screenshots
</details>
```

## Commands

```bash
# Check if branch needs pushing
git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "not-pushed"

# Push if needed
git push -u origin $(git branch --show-current)

# Create PR (derive assignee from gh CLI — no hardcoded username)
gh pr create --base develop \
  --title "TICKET | EMOJI type(scope): Description" \
  --assignee "$(gh api user --jq '.login')" \
  --label "ready for review" \
  --body "$(cat <<'EOF'
## Summary
...
EOF
)"
```

## Rules

- Base branch is `develop` (not `master`)
- Title format: `TICKET | EMOJI type(scope): Short description` (gitmoji required — CLAUDE.local.md rule #14)
- Extract ticket from branch name (e.g., `CORE-121`)
- NEVER push without user confirmation
- Include all commits in summary, not just the latest
- Run `bin/d bundle exec pronto run -r rubocop -c develop -f text` for modified files (preserves legacy)
- Run `bin/d rubocop -A` ONLY for new files

## Example

```bash
# User runs: /create-pr

# Claude gathers info, then:
gh pr create --base develop \
  --title "CORE-121 | ✨ feat(onboarding): Move hasCompleteProfile to userOnboardingStatus" \
  --assignee "$(gh api user --jq '.login')" \
  --label "ready for review" \
  --body "$(cat <<'EOF'
**Background**

Mobile app needs to track user onboarding progress more efficiently. Currently, profile completion is computed on every request which impacts performance.

This PR moves the check to a dedicated database flag that's updated when profile fields change.

**Attention**

* Feature can be deployed anytime
* No blocking migrations

**Reference**

* [JIRA](https://paybycourt.atlassian.net/browse/CORE-121)
* [Honey Badger]()
* [Design Doc]()

**Technical Diagrams (Mermaid) &/or Screenshots**

<details>
  <summary>Screenshot description</summary>

  Collapsible and repeatable section for multiple screenshots
</details>

EOF
)"
```

---

## MCP Integrations

### GitHub MCP

Use for enhanced PR operations:

```
# Create PR via MCP (alternative to gh CLI)
mcp__github__create_pull_request:
  owner: "PlaybyCourt"
  repo: "platform"
  title: "CORE-123 | ✨ feat(scope): Add feature X"
  body: "## Summary\n..."
  head: "feature/CORE-123-add-feature-x"
  base: "develop"

# List existing PRs to avoid duplicates
mcp__github__list_pull_requests:
  owner: "PlaybyCourt"
  repo: "platform"
  state: "open"
  head: "feature/CORE-123-add-feature-x"

# Get PR review status
mcp__github__get_pull_request:
  owner: "PlaybyCourt"
  repo: "platform"
  pull_number: 123

# Add reviewers — mcp__github__request_reviewers does not exist; use gh CLI instead:
# gh pr edit <number> --add-reviewer reviewer1,reviewer2
```

**Use Cases:**
- Check for existing PRs before creating
- Auto-add reviewers based on changed files
- Get CI status of PR
- Link PR to issues automatically

---

## Kaizen: Continuous Improvement

> Improvements log archived to [`kaizen_log.md`](kaizen_log.md) (2026-06-14) to reduce per-invocation token cost.

When you discover a new PR pattern, missing validation step, or outdated gh CLI usage: complete the current PR first, then run `/kaizen` to record the improvement.
