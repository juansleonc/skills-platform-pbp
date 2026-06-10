---
name: tdd
description: MANDATORY for all code changes — triggers when implementing features, fixing bugs, modifying existing behavior, adding guards, or changing any code that requires behavioral verification.
allowed-tools: [Bash, Read, Write, Edit, Grep, Glob, Agent, mcp__context7__resolve-library-id, mcp__context7__query-docs]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

# TDD Workflow - MANDATORY

## Shared References

> **📚 This skill uses shared documentation. See:**
> - [Factory Rules](../shared/factory-rules.md) - build vs create patterns
> - [Forbidden Patterns](../shared/forbidden-patterns.md) - patterns to avoid
> - [Testing Patterns](../shared/testing-patterns.md) - time, Redis, parallel safety
> - [Critical Rules](../shared/critical-rules.md) - project-wide rules
> - [Code Simplifier Integration](../shared/code-simplifier-integration.md) - automatic test optimization (Tier 1: ALWAYS)

## CRITICAL RULE

**NEVER write implementation code before tests exist.**

This is non-negotiable. Every code change MUST follow the TDD cycle:

### If Code Was Written Before Tests: Delete and Restart

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before the test? **Delete it. Start over.**

**No exceptions:**
- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Don't look at it
- Delete means delete

**Protocol when untested code already exists:**
1. Stash or delete the untested code (`git stash` or delete the file/method)
2. Write the failing test first (RED)
3. Reimplement from scratch driven by the test (GREEN)
4. The earlier code may inform the design — but never bypass the RED step

Implement fresh from tests. Period.

```
┌─────────────────────────────────────────────────────────┐
│  1. RED:      Write failing test FIRST                  │
│               ↓                                         │
│  2. GREEN:   Write MINIMAL code to pass                 │
│               ↓                                         │
│  3. REFACTOR: Improve while keeping tests green         │
│               ↓                                         │
│  4. COVERAGE: Verify 100% on changes                    │
│               ↓                                         │
│  (repeat for each behavior)                             │
└─────────────────────────────────────────────────────────┘
```

## PERFORMANCE IS CRITICAL

**This is a large project. Test execution time matters.**

> 📖 **See [Factory Rules](../shared/factory-rules.md) for complete decision tree.**

Quick reference:
1. Use `build` over `create` (10-100x faster)
2. Avoid unnecessary database operations
3. Mock external services
4. Use `build_stubbed` when you need `id`/`persisted?`

### Before Writing Tests: Consult Best Practices

**ALWAYS query Context7 for RSpec/testing best practices:**

```
# Resolve library ID first
mcp__context7__resolve-library-id:
  libraryName: "rspec"
  query: "best practices for fast unit tests"

# Then query documentation
mcp__context7__query-docs:
  libraryId: "/rspec/rspec"
  query: "factory patterns for fast tests, avoiding database hits"
```

**Query Context7 for specific patterns:**
- Factory optimization: `"FactoryBot build vs create performance"`
- Mocking patterns: `"RSpec mocking best practices"`
- Async testing: `"testing Sidekiq jobs efficiently"`
- GraphQL testing: `"graphql-ruby testing patterns"`

### After Writing Tests: Simplify with Agent

**ALWAYS run code-simplifier agent on new test files:**

```
Agent tool with subagent_type: "code-simplifier"
prompt: "Review and optimize this spec file for performance and clarity:
  - Prefer build over create
  - Remove redundant test setup
  - Consolidate similar contexts
  - Ensure proper use of let vs let!
  - Remove unnecessary database operations
  File: spec/path/to/new_spec.rb"
```

The code-simplifier agent will:
- Identify slow patterns (unnecessary `create` calls)
- Suggest `build`/`build_stubbed` replacements
- Remove duplicate setup code
- Optimize factory usage
- Ensure tests are maintainable

## Test Types

| Type | Location | When to Use |
|------|----------|-------------|
| Unit | `spec/models/`, `spec/services/` | Models, services, isolated logic |
| Integration | `spec/requests/`, `spec/graphql/` | API endpoints, GraphQL |
| System | `system_specs/` (NOT spec/) | Browser interactions (Playwright) |

## Docker Environment (MANDATORY)

**All tests run in Docker web container:**

```bash
# Unit/Integration tests (PREFERRED)
make test TEST_PATH=spec/models/user_spec.rb
# OR: bin/d rspec spec/models/user_spec.rb

# Multiple files
make test TEST_PATH="spec/models/user_spec.rb spec/services/"

# All specs (parallel) - PREFERRED
make test-all
# OR: bin/d rails parallel:spec
```

## Workflow

### Step 1: Understand the Requirement

Before writing anything:
1. Identify the expected behavior
2. Define inputs and outputs
3. List edge cases and error conditions

### Step 2: Write the Test (RED)

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NewFeature do
  describe '#expected_behavior' do
    subject(:result) { described_class.call(input) }

    context 'when happy path' do
      let(:input) { valid_input }

      it 'returns expected output' do
        expect(result).to eq(expected_output)
      end
    end

    context 'when edge case' do
      let(:input) { edge_case_input }

      it 'handles edge case correctly' do
        expect(result).to handle_edge_case
      end
    end

    context 'when error condition' do
      let(:input) { invalid_input }

      it 'raises appropriate error' do
        expect { result }.to raise_error(ExpectedError)
      end
    end
  end
end
```

Run the test — it MUST fail. **Do not assume it fails. Run it and READ the full output.**
```bash
bin/d rspec spec/path_spec.rb
# Expected: RED — confirm the failure message says the FEATURE IS MISSING,
# not a load error, typo, or misconfigured factory. A load error is not a RED test.
```

#### Common Rationalizations — Intercept Before Skipping the Test

Thinking about skipping the RED step? Match your thought against this table first.

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Tests after achieve same goals" | Tests-after = "what does this do?" Tests-first = "what should this do?" |
| "Already manually tested" | Ad-hoc ≠ systematic. No record, can't re-run. |
| "Deleting X hours is wasteful" | Sunk cost fallacy. Keeping unverified code is technical debt. |
| "Keep as reference, write tests first" | You'll adapt it. That's testing after. Delete means delete. |
| "Need to explore first" | Fine. Throw away exploration, start with TDD. |
| "Test hard = design unclear" | Listen to test. Hard to test = hard to use. |
| "TDD will slow me down" | TDD faster than debugging. Pragmatic = test-first. |
| "Manual test faster" | Manual doesn't prove edge cases. You'll re-test every change. |
| "Existing code has no tests" | You're improving it. Add tests for existing code. |

**Red Flags — STOP and Start Over:**
- Code before test
- Test after implementation
- Test passes immediately without seeing it fail
- Can't explain why test failed
- Tests added "later"
- Rationalizing "just this once"
- "I already manually tested it"
- "Keep as reference" or "adapt existing code"
- "Already spent X hours, deleting is wasteful"
- "TDD is dogmatic, I'm being pragmatic"
- "This is different because..."

**All of these mean: Delete code. Start over with TDD.**

#### Regression proof ritual (for bug-fix tests)

When writing a test to guard a specific bug, passing once is not enough — you must prove the test actually catches the regression:

```
1. Write the test
2. Run with fix in place → must PASS (GREEN)
3. REVERT the fix (comment out / remove the guard)
4. Run again → test MUST now FAIL (RED)
5. Restore the fix
6. Run again → PASS (GREEN)
```

A regression test that was never observed to fail with the fix removed is not proven to guard anything — it may be vacuously passing (wrong assertion, wrong code path, coincidental data). This is especially critical for financial/membership fixes where a vacuously-green regression test gives false confidence while leaving the bug live.

### Step 3: Implement Minimal Code (GREEN)

Write ONLY enough code to make the test pass:
- No optimization
- No extra features
- No "nice to have" code

```bash
make test TEST_PATH=spec/path_spec.rb
# Expected: GREEN (all pass)
```

### Step 4: Refactor

Improve the code while keeping tests green:
- Remove duplication
- Improve naming
- Optimize if needed

```bash
make test TEST_PATH=spec/path_spec.rb
# Must stay GREEN after each change
```

### Step 4.5: Lint Changed Files (BEFORE git add)

**CRITICAL**: Run Pronto BEFORE staging files to catch issues early.

⚠️ **Pronto only works on UNSTAGED files.** Run this BEFORE `git add`.

```bash
# Run Pronto on unstaged changes
bin/d bundle exec pronto run -r rubocop -c develop -f text
```

**Expected output**: No violations (empty output)

**If violations found**:
1. Fix all violations (Layout, Style, Rails cops)
2. Re-run Pronto until clean
3. Only then proceed to coverage/commit

**Why this step**:
- Pre-commit hook catches issues AFTER `git add` (too late)
- Pronto catches issues BEFORE staging (prevents rejection)
- Saves 15min per PR by catching early

**Common violations caught**:
- `Layout/ArgumentAlignment` - Fix indentation
- `Rails/Delegate` - Use `delegate` instead of wrapper methods
- `Naming/PredicatePrefix` - Rename `is_foo` to `foo`
- `Style/InvertibleUnlessCondition` - Use `if x.blank?` instead of `unless x.present?`

### Step 5: Verify Coverage (MANDATORY)

**100% coverage on changed lines is required:**

```bash
# Run with SimpleCov
docker compose exec -e SIMPLECOV_REPORT=true web bundle exec rspec spec/path_spec.rb  # bin/d rspec for plain run

# Check coverage for specific file
bin/d rake 'coverage:local:file[app/path/to/file.rb]'

# Verify delta
bin/d rake 'coverage:local:delta'
```

**Evidence gate before declaring done (two net-new items — tests/lint/coverage are already covered above):**

1. **VCS diff check** — run `git diff HEAD` and confirm the claimed changes are actually present in the diff. Do not declare a file changed if it does not appear.
2. **Contract reconciliation** — go through the validation contracts (C1..Cn) one by one and confirm each has a passing test. Don't assume — trace each contract to its spec line.

Everything else (tests pass, lint clean, coverage 100%) is already enforced by the steps above and `/coverage` + Pronto.

**No completion claim without fresh verification evidence.** You cannot use success/satisfaction wording unless the verifying command was actually run in this message:

| Claim | Required evidence | NOT sufficient |
|-------|-------------------|----------------|
| "Tests pass" | `bin/d rspec` output showing 0 failures | "Should pass", previous run, code looks right |
| "Coverage met" | `coverage:local:delta` output | "I covered all branches" |
| "Agent/worker completed" | VCS diff shows the changes | Worker's self-report of success |
| "Linter clean" | Pronto output (empty = clean) | "I fixed all the violations" |
| "Bug is fixed" | Test exercising original symptom passes | Code changed, assumed fixed |
| "Regression test guards the bug" | Red-green cycle verified (see regression proof above, in the RED phase) | Test was written and passes once |

Red flags — STOP before claiming done:
- Using "should", "probably", "seems to"
- Expressing satisfaction ("Done!", "Perfect!", "Should work") before running the command
- Trusting a subagent/worker's success report without checking the diff

## Factory Rules (CRITICAL for Performance)

> 📖 **See [Factory Rules](../shared/factory-rules.md) for complete decision tree and examples.**

**⚠️ WRONG factory choice = slow test suite = wasted CI time**

| Method | When to Use | Speed |
|--------|-------------|-------|
| `build(:factory)` | **DEFAULT** - validations, methods, attributes | Fast |
| `build_stubbed(:factory)` | When code checks `id` or `persisted?` | Fast |
| `create(:factory)` | **ONLY** scopes, queries, uniqueness | Slow |
| `create(:facility, :skip_callbacks)` | Facility without associations | Medium |

**Quick Rule**: If you're testing a method or validation, use `build`. Only use `create` when you need database operations.

## Forbidden Patterns

> 📖 **See [Forbidden Patterns](../shared/forbidden-patterns.md) for complete list.**

These will cause validation failures:

```ruby
# ❌ FORBIDDEN - These WILL fail validation
allow_any_instance_of(Class)    # Use dependency injection
expect_any_instance_of(Class)   # Use explicit instances
create(:user, id: 1)            # Let factory generate ID
Time.now / Date.today           # Use Time.current / Date.current
before(:all) { create(...) }    # Use before(:each)
date.to_s(:db)                  # Use strftime (Ruby 3)
```

## Time-Dependent Tests

> 📖 **See [Testing Patterns](../shared/testing-patterns.md) for complete patterns.**

**ALWAYS use Timecop with Time.current:**

```ruby
# ✅ CORRECT
Timecop.freeze(Time.current) do
  user = build(:user)
  expect(user.expires_at).to eq(30.days.from_now)
end

# ❌ INCORRECT - will fail randomly
expect(user.expires_at).to eq(Time.now + 30.days)
```

## Redis in Tests

**Clear Redis for rate limiting/caching tests:**

```ruby
before do
  Redis.current.flushdb
  # Or for specific keys:
  Rails.cache.clear
end
```

## Test Structure Template

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClassName do
  # Subject first
  subject(:result) { described_class.new(args).method_name }

  # Then lets (dependencies)
  let(:facility) { create(:facility, :skip_callbacks) }
  let(:dependency) { build(:factory) }
  let(:args) { { key: value } }

  # Then contexts with examples
  describe '#method_name' do
    context 'when condition A' do
      it 'behaves as expected' do
        expect(result).to eq(expected)
      end
    end

    context 'when condition B' do
      let(:args) { { key: different_value } }

      it 'behaves differently' do
        expect(result).to eq(different_expected)
      end
    end
  end
end
```

---

## System Tests (Playwright)

**System tests live in `system_specs/` (NOT `spec/`).**

### Playwright Version (CRITICAL)

**Version MUST match between gem and CLI:**

```bash
# Check current Playwright version in Gemfile.lock
grep "capybara-playwright-driver" Gemfile.lock

# Install matching CLI version
npx --yes playwright@1.55.0 install chromium
```

### Running System Tests

```bash
# Setup Playwright (version must match!)
npx --yes playwright@1.55.0 install chromium

# Run all system tests
bin/test_system

# Parallel execution
PARALLEL_TEST_PROCESSORS=4 bin/test_system

# Visible browser (debugging)
PLAYWRIGHT_HEADLESS=false bin/test_system

# Single test
bin/d rspec system_specs/features/admin_login_spec.rb
```

### System Test File Structure

```ruby
# frozen_string_literal: true
require_relative '../system_rails_helper'

RSpec.describe 'Feature Name', type: :system, playwright: true do
  # Test content
end
```

### Multi-Tenant Setup

```ruby
# Always create unique emails with SecureRandom
let(:admin_user) do
  FactoryBot.create(
    :user,
    :admin,
    email: "admin_#{SecureRandom.hex(4)}@example.com",
    password: password,
    confirmed_at: Time.current
  ).tap do |u|
    FacilitiesUser.create!(user: u, facility: facility, role: 'court_manager', approval: true)
    u.facilities_linked << facility
  end
end

# Use visit_as_tenant for subdomain routing
def login_user(user, subdomain:)
  visit_as_tenant('/users/sign_in', subdomain: subdomain)
  fill_in('Email', with: user.email)
  fill_in('Password', with: password)
  click_button('Sign in')
  expect(page).to have_current_path(%r{/admin|/facilities}, wait: 10)
end
```

### Available System Test Helpers

```ruby
include SystemTestHelpers::MultiTenant  # visit_as_tenant, sign_in_user
include SystemTestHelpers::Waiting      # wait_for_element, wait_for_text, wait_for_ajax
include SystemTestHelpers::Screenshots  # take_screenshot (auto on failure)
include SystemTestHelpers::FormHelpers  # fill_in_date_field, select_from_dropdown
```

### Waiting for Dynamic Content

```ruby
# Prefer Capybara's built-in waiting
expect(page).to have_css('selector', wait: 10)
expect(page).to have_content('text', wait: 10)

# For AJAX/fetch updates
def wait_for_search_results
  expect(page).to have_no_css('.loading', wait: 5)
  expect(page).to have_css('#results-table tbody tr', wait: 10)
end
```

### System Test Template

```ruby
# frozen_string_literal: true
require_relative '../system_rails_helper'

RSpec.describe 'Admin Login', type: :system, playwright: true do
  let(:password) { 'password123!' }
  let(:facility) { FactoryBot.create(:facility, :skip_callbacks) }
  let(:admin_user) do
    FactoryBot.create(
      :user,
      :admin,
      email: "admin_#{SecureRandom.hex(4)}@example.com",
      password: password,
      confirmed_at: Time.current
    ).tap do |u|
      FacilitiesUser.create!(user: u, facility: facility, role: 'court_manager', approval: true)
    end
  end

  it 'allows admin to login' do
    visit_as_tenant('/users/sign_in', subdomain: facility.subdomain)

    fill_in 'Email', with: admin_user.email
    fill_in 'Password', with: password
    click_button 'Sign in'

    expect(page).to have_current_path(%r{/admin}, wait: 10)
    expect(page).to have_content('Dashboard')
  end
end
```

---

## Remember

> "If you can't write a test for it, you don't understand the requirement well enough."

**Tests are not optional. Tests come FIRST. Always.**

| Checklist | Status |
|-----------|--------|
| Test written BEFORE implementation | Required |
| 100% coverage on changed lines | Required |
| No forbidden patterns | Required |
| Factories optimized (build > create) | Required |
| Time tests use Timecop + Time.current | Required |
| System tests use SecureRandom in emails | Required |

### Self-review before handoff (early filter — NOT a replacement for the validator gate)

Before reporting DONE, run a quick self-review across five axes and fix what you find:

1. **Completeness** — does the diff satisfy every validation contract (C1..Cn)? If a contract is unaddressed, fix it or return NEEDS_CONTEXT.
2. **Quality** — are tests asserting real behavior (not mocking the thing under test)? Are they readable?
3. **Discipline (YAGNI)** — did you add anything beyond what the contracts require? Remove it.
4. **Testing** — run the full spec file one more time; confirm it's green with no pending/skipped examples you didn't intend.
5. **Escalation** — is there something genuinely unresolvable (missing context, ambiguous contract, external dependency)? Return NEEDS_CONTEXT now rather than guessing.

Report what you fixed and what (if anything) you escalated. This is the worker's last pass before the independent validator gate.

---

## MCP Integrations

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new pattern that should be documented
- A missing edge case or forbidden pattern
- An outdated example or command
- A better way to accomplish something

**You MUST**:
1. Complete the current task first
2. Then append improvements to this skill file using Edit tool
3. Add to the appropriate section (or create new subsection)
4. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements**:
<!-- Kaizen: 2026-01-22 -->
- Added: Context7 integration for RSpec/testing best practices lookup
- Added: code-simplifier agent workflow for test optimization
- Added: "PERFORMANCE IS CRITICAL" section emphasizing test speed
- Enhanced: Factory Rules with decision tree and performance impact examples
- Added: Test profiling commands to measure slow tests
- Added: mcp__context7__* tools to allowed-tools

<!-- Kaizen: 2026-02-01 - Docker Command Preferences -->
- Improved: Docker Environment section to emphasize preferred commands
- Added: `make test-all` as preferred alternative for parallel specs
- Added: `bin/d` as alternative to `make test` for single files
- Why: CLAUDE.local.md prefers `make`/`bin/d` over direct `docker compose exec`
- Impact: Clearer guidance for developers, consistent with project conventions

<!-- Kaizen: 2026-05-12 - User correction -->
- Added: For TDD on HTTP-facing code (GraphQL resolvers, controllers, middlewares, endpoint-triggered jobs), the failing test in the RED step should be an INTEGRATION spec that exercises the real entry point (e.g. `graphql_post(query, token, params)` for GraphQL), not a unit spec that stubs the framework or calls private methods on an `allocate`d object.
- Why: Stubbed/private-method tests pass under conditions that don't hold in production. The aliased-`eventsNearby` context-collision bug in ENG-544 was only catchable via a request-level spec — a unit test on `filter_bookable_for_marketplace` would have hidden it.
- How to apply: When writing the RED test, ask "would this test still fail if I ran the actual HTTP request through the real stack?" If no, escalate to integration. Unit-level stubs are acceptable for genuinely internal services with no HTTP entry.
- Source: User correction on 2026-05-12 during ENG-544 adversarial review. See `memory/feedback_validate_bugs_via_real_request.md`.

<!-- Kaizen: 2026-06-09 — RED must actually fail + self-review + evidence gate (adapted from obra/superpowers, MIT) -->
- RED phase: made "watch it fail" explicit — run `bin/d rspec` and READ the output; confirm the failure is "feature missing", not a load error. "Assume it fails" is not allowed.
- Self-review checkpoint (Step 5.5, before handoff): 5-axis pass (Completeness / Quality / YAGNI / Testing / Escalation); fixes what it finds; reports what it fixed. Early filter only — the independent validator gate is still mandatory.
- Evidence gate (Step 5 addendum): two net-new items before declaring done — (i) `git diff HEAD` confirms claimed changes exist; (ii) contract reconciliation traces each C1..Cn to a passing spec line. Tests/lint/coverage checks already enforced by the TDD cycle + `/coverage` + Pronto.

<!-- Kaizen: 2026-06-10 — Mechanism grafts from obra/superpowers (MIT, commit 6fd4507) -->
- Added: Iron Law / delete-code protocol (§ "If Code Was Written Before Tests") — verbatim from superpowers `skills/test-driven-development/SKILL.md` lines 31-45. The local skill already forbade writing implementation first but prescribed nothing when it had already happened. Protocol: stash/delete untested code → write failing test → reimplement. "Delete means delete."
- Added: Rationalization/excuse table + Red Flags self-check block immediately after the RED run command — from superpowers lines 256-288. Distinct from the evidence/claim gate at Step 5 (which gates AFTER work) and from the regression proof ritual (which validates a specific guard): this table intercepts rationalizations BEFORE the test step is skipped. PBP adaptation: command references use `bin/d rspec` per CLAUDE.local.md rule #2.
- Source: `/tmp/superpowers-20260610/skills/test-driven-development/SKILL.md` (MIT license)

<!-- Kaizen: 2026-06-10 — Purge stale tool references (superpowers-spike 2026-06-10 drift findings) -->
- Removed: `mcp__playwright__*` from frontmatter allowed-tools — the Playwright MCP server is not configured in this project; its presence caused dispatch confusion. Playwright system tests via `bin/test_system` and `system_specs/` are real and fully documented in the System Tests section above.
- Removed: "Playwright MCP" subsection (~lines 540-561) that referenced the unconfigured MCP server tools.
- Fixed: frontmatter description rewritten from workflow summary ("Always write tests FIRST before any implementation. Covers unit, integration, and system tests") to trigger conditions only — CSO rule: description = when to invoke, never the process; agents that read the description instead of the body follow an incomplete workflow.
- Lesson: stale allowed-tools in frontmatter are loaded at session start and pollute the tool namespace with non-functional tools; check on every superpowers-spike pass.
