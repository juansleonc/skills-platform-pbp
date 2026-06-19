#!/usr/bin/env bash
set -euo pipefail
# qa-audit.sh - Run all automated checks

echo "=== QA Audit Starting ==="

# Check 1: No Claude/AI mentions
echo "Checking for forbidden AI mentions..."
if grep -rn "Co-Authored-By: Claude\|Generated with.*Claude" .claude/skills/ --include="*.md"; then
  echo "❌ FAIL: Found AI mentions in skills"
  exit 1
fi
echo "✓ No AI mentions"

# Check 2: All commands use Docker
# NOTE: canonical skill filename is UPPERCASE `SKILL.md` (~40 files; 0 lowercase).
# skillfile() uses -iname for cross-platform portability (Linux CI), not to handle
# mixed casing — mixed casing was fixed. We skip whole "Before/After" example blocks
# (awk drops lines from `<!-- Before` until the next `<!-- After` or blank line) so
# intentional bad examples don't false-positive. `docker-exec` is the canonical
# "raw bundle exec inside the container" reference, so it's excluded by design.
skillfile() { find ".claude/skills/$1" -maxdepth 1 -iname "skill.md" | head -1; }

echo "Checking Docker usage..."
# Iterate all skills case-insensitively; skip docker-exec (canonical raw-command reference)
# and PRODUCTION runner examples (`RAILS_ENV=production ... runner`, which run on prod, not
# locally in Docker). The awk also drops `<!-- Before -->` example blocks.
BAD_COMMANDS=$(for f in $(find .claude/skills -iname 'skill.md' | grep -v "/docker-exec/"); do
  awk -v F="$f" '
    /<!-- Before/      { skip=1 }
    /<!-- After/       { skip=0 }
    /^[[:space:]]*$/   { skip=0 }
    /bundle exec/ && !skip {
      if ($0 !~ /docker compose exec|make |bin\/d|# *BAD|❌|RAILS_ENV=production/) print F":"FNR": "$0
    }' "$f"
done)
if [ -n "$BAD_COMMANDS" ]; then
  echo "⚠️ WARNING: Found non-Docker commands:"
  echo "$BAD_COMMANDS"
else
  echo "✓ No unwrapped bundle exec commands"
fi

# Check 3: Package count (DYNAMIC — never hardcode the count)
# packwerk/SKILL.md no longer embeds a "N Packwerk packages" declaration — its inventory
# moved to reference/packs.md, which also defers to the filesystem as source of truth.
# We report the live count and check that reference/packs.md exists (the canonical inventory).
echo "Checking package count..."
ACTUAL_PACKAGES=$(ls -d packs/*/ 2>/dev/null | wc -l | tr -d ' ')
PACKS_REF=$(find .claude/skills/packwerk/reference -maxdepth 1 -name "packs.md" | head -1)
if [ -z "$PACKS_REF" ]; then
  echo "⚠️ WARNING: packwerk reference/packs.md not found — pack inventory doc is missing"
else
  echo "✓ Package count: $ACTUAL_PACKAGES packs (cross-check against $PACKS_REF)"
fi

# Check 4: 100% coverage requirement
echo "Checking coverage requirements..."
if ! grep -q "100%" "$(skillfile coverage)"; then
  echo "❌ FAIL: Coverage skill doesn't mention 100% requirement"
else
  echo "✓ Coverage requirement present"
fi

# Check 5: Forbidden patterns documented
echo "Checking forbidden patterns..."
if ! grep -q "allow_any_instance_of" "$(skillfile tdd)"; then
  echo "⚠️ WARNING: TDD skill missing forbidden pattern documentation"
fi

echo "=== QA Audit Complete ==="
