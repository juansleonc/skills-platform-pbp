#!/usr/bin/env bash
set -euo pipefail

# validate_skill.sh — Kaizen validation commands.
# Invoked from kaizen/SKILL.md "Validation Commands" pointer.
# Run from the repo root: bash .claude/skills/kaizen/scripts/validate_skill.sh

echo "=== Validate YAML Frontmatter ==="
# Check each skill has valid YAML.
# (|| echo) handles skills that legitimately omit allowed-tools; || true keeps set -e happy.
for skill in .claude/skills/*/SKILL.md; do
  echo "Checking: $skill"
  head -10 "$skill" | grep -E "^(name|description|allowed-tools):" || echo "❌ Invalid YAML"
done || true

echo "=== Check for Outdated Patterns ==="
# Canonical scan (the full forbidden list lives in ../shared/forbidden-patterns.md).
# Forbidden patterns
grep -r "Time\.now" .claude/skills/*/SKILL.md || true
grep -r "allow_any_instance_of" .claude/skills/*/SKILL.md || true
grep -r "\.to_s(:db)" .claude/skills/*/SKILL.md || true

# Docker violations
grep -r "bundle exec" .claude/skills/*/SKILL.md | grep -v "docker\|make\|bin/d" || true

echo "=== Validate Shared References (comprehensive) ==="
# Expected: No output (all references valid).
# grep returns non-zero for skills with no ../shared/ refs — || true keeps set -e from aborting.
for skill in .claude/skills/*/SKILL.md; do
  skill_name=$(basename "$(dirname "$skill")")
  grep -n '](../shared/' "$skill" 2>/dev/null | while IFS=: read -r linenum line; do
    ref=$(echo "$line" | sed 's/.*](\.\.\/shared\///' | sed 's/).*//' | sed 's/#.*//')
    if [ -n "$ref" ] && [ ! -f ".claude/skills/shared/$ref" ]; then
      echo "❌ $skill_name:$linenum references missing: $ref"
    fi
  done || true
done

echo "=== Validate Shared References (quick — common docs exist) ==="
# Expected: All files show ✅
for doc in factory-rules.md forbidden-patterns.md testing-patterns.md critical-rules.md clickhouse-queries.md code-simplifier-integration.md; do
  if [ -f ".claude/skills/shared/$doc" ]; then
    echo "✅ $doc"
  else
    echo "❌ $doc MISSING"
  fi
done

echo "=== Check Tool References ==="
# Find all tool references; verify they exist against available MCPs.
grep -r "mcp__" .claude/skills/*/SKILL.md | cut -d: -f2 | sort -u || true
