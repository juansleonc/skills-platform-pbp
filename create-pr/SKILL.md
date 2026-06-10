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

* Feature can be deployed anytime / Feature needs communication before merging
* No blocking migrations / Includes migration (create/drop table)
* New rule `specific_rule` to enable X (if applicable)
* Worker/rake task notes (if applicable)

**Reference**

* [JIRA](https://paybycourt.atlassian.net/browse/TICKET)

**Test Plan**

- [x] Unit tests added/updated
- [x] GraphQL/API tests (if applicable)
- [ ] Manual testing in staging

<details>
  <summary>Screenshots (if applicable)</summary>

  Add screenshots here
</details>
```

## Commands

```bash
# Check if branch needs pushing
git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "not-pushed"

# Push if needed
git push -u origin $(git branch --show-current)

# Create PR
gh pr create --base develop --title "TICKET | Description" --body "$(cat <<'EOF'
## Summary
...
EOF
)"
```

## Rules

- Base branch is `develop` (not `master`)
- Title format: `TICKET | Short description`
- Extract ticket from branch name (e.g., `CORE-121`)
- NEVER push without user confirmation
- Include all commits in summary, not just the latest
- Run `bin/d pronto run -c develop` for modified files (preserves legacy)
- Run `bin/d rubocop -A` ONLY for new files

## Example

```bash
# User runs: /create-pr

# Claude gathers info, then:
gh pr create --base develop --title "CORE-121 | feat(onboarding): Move hasCompleteProfile to userOnboardingStatus" --body "$(cat <<'EOF'
**Background**

Mobile app needs to track user onboarding progress more efficiently. Currently, profile completion is computed on every request which impacts performance.

This PR moves the check to a dedicated database flag that's updated when profile fields change.

**Attention**

* Feature can be deployed anytime
* No blocking migrations

**Reference**

* [JIRA](https://paybycourt.atlassian.net/browse/CORE-121)

**Test Plan**

- [x] Unit tests added for User model
- [x] GraphQL query tests updated
- [ ] Manual testing in staging

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
  owner: "playbypoint"
  repo: "platform"
  title: "PLA-123 | Add feature X"
  body: "## Summary\n..."
  head: "feature/add-x"
  base: "develop"

# List existing PRs to avoid duplicates
mcp__github__list_pull_requests:
  owner: "playbypoint"
  repo: "platform"
  state: "open"
  head: "feature/add-x"

# Get PR review status
mcp__github__get_pull_request:
  owner: "playbypoint"
  repo: "platform"
  pull_number: 123

# Add reviewers
mcp__github__request_reviewers:
  owner: "playbypoint"
  repo: "platform"
  pull_number: 123
  reviewers: ["reviewer1", "reviewer2"]
```

**Use Cases:**
- Check for existing PRs before creating
- Auto-add reviewers based on changed files
- Get CI status of PR
- Link PR to issues automatically

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new PR template pattern
- A missing validation step
- An outdated gh CLI usage

**You MUST**:
1. Complete the current PR creation first
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements**:
<!-- Kaizen entries will be added here -->

<!-- Kaizen: 2026-05-12 - User correction -->
- Rule: Default every PR creation to `--assignee juansleonc --label "ready for review"`. Surface both fields in the pre-push confirmation block (alongside title/base/body), not only in the executed command.
- Why: Standard workflow — every PR needs an owner and a status. Omitting them forces the user to ask twice and re-edit the PR after creation.
- How to apply: When building the `gh pr create` invocation (and any MCP `create_pull_request` call), always include the assignee and `ready for review` label. Show them in the user-facing proposal. If the user explicitly opts out for a specific PR, respect that for that PR but keep the default for the next one.
- Source: User correction on 2026-05-12 during TRI-74 (PR #4836). See `memory/feedback_pr_defaults.md`.

<!-- Kaizen: 2026-05-14 - User correction -->
- Rule: When the source Jira ticket has visual repro artifacts (Loom, video, screenshots, GIFs), include each one as a separate bullet under **Reference** in the PR body — not just the JIRA link.
- Why: Reviewers should see the bug repro one click away from the PR. Forcing them to open the ticket to find the video adds friction and risks them reviewing code without seeing the actual user-visible behavior.
- How to apply: After reading the Jira ticket, scan description AND comments for `loom.com`, `youtube.com`, image attachments, and screenshot URLs. Add a bullet per artifact under **Reference** with a short descriptive label, e.g. `[Loom — bug repro](https://www.loom.com/share/...)`. Apply to every PR, not only bug fixes — feature PRs often have design mockups worth surfacing.
- Source: User correction on 2026-05-14 during TRI-79. See `memory/feedback_pr_include_repro_links.md`.
