---
name: tdd
description: MANDATORY for all code changes — triggers when implementing features, fixing bugs, modifying existing behavior, adding guards, or changing any code that requires behavioral verification.
allowed-tools: [Bash, Read, Write, Edit, Grep, Glob, Agent, mcp__context7__resolve-library-id, mcp__context7__query-docs]
disable-model-invocation: false
---

> **Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

# TDD Workflow - MANDATORY

## Shared References

> **This skill uses shared documentation. See:**
> - [Factory Rules](../shared/factory-rules.md) - build vs create decision tree
> - [Forbidden Patterns](../shared/forbidden-patterns.md) - patterns to avoid
> - [Testing Patterns](../shared/testing-patterns.md) - time, Redis, parallel safety
> - [Test Templates](../shared/test-templates.md) - unit/integration/RED/HTTP-facing templates
> - [System Test Guide](../shared/system-test-guide.md) - Playwright setup, helpers, templates

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

## Docker Environment (MANDATORY)

All tests run in Docker web container:

```bash
bin/d rspec spec/models/user_spec.rb         # single file
make test TEST_PATH=spec/models/user_spec.rb  # via Makefile (accepts TEST_PATH variable)
bin/d rails parallel:spec                     # full suite (parallel) — PREFERRED
# Note: make test-all does NOT exist in the Makefile
```

## Workflow

### Step 1: Understand the Requirement

Before writing anything:
1. Identify the expected behavior
2. Define inputs and outputs
3. List edge cases and error conditions

**HTTP-facing classification (mandatory):** Ask — "Is this code reached via HTTP?" (GraphQL resolver / controller / middleware / webhook / endpoint-triggered job). If **yes**, the RED test in Step 2 MUST exercise the real entry point — not a unit test that stubs the framework or calls private methods on an `.allocate`d object. See [../shared/test-templates.md](../shared/test-templates.md) for the HTTP-facing integration template.

### Before Writing Tests: Consult Best Practices

**ALWAYS query Context7 for RSpec/testing best practices** before writing tests. Use `mcp__context7__resolve-library-id` to find the library ID for "rspec", then call `mcp__context7__query-docs` with that ID to look up patterns relevant to your test. Useful queries:

- Factory optimization: `"FactoryBot build vs create performance"`
- Mocking patterns: `"RSpec mocking best practices"`
- Async testing: `"testing Sidekiq jobs efficiently"`
- GraphQL testing: `"graphql-ruby testing patterns"`

### Step 2: Write the Test (RED)

See [../shared/test-templates.md](../shared/test-templates.md) for unit, integration, and RED templates.

Run the test — it MUST fail. **Do not assume it fails. Run it and READ the full output.**
```bash
bin/d rspec spec/path_spec.rb
# Expected: RED — confirm the failure message says the FEATURE IS MISSING,
# not a load error, typo, or misconfigured factory. A load error is not a RED test.
```

#### Assertion-Depth gate (anti coverage-theater)

For every assertion ask: "Does this prove the BEHAVIOR or just that the code ran?"

| Weak (coverage-theater) | Strong (behavioral) |
|-------------------------|---------------------|
| `expect { x }.not_to raise_error` as the SOLE assertion | `expect(result).to eq(expected_value)` |
| `expect(record.destroy).to be_truthy` | `expect { record.destroy }.to change(Model, :count).by(-1)` |
| Verifies call happened | Verifies side-effect: `expect(record.reload).to be_destroyed` |

**100% line coverage ≠ behavioral coverage.** Lines executed without assertions about their output are untested.

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

After refactoring tests, use `/factory-check` and [../shared/factory-rules.md](../shared/factory-rules.md) to optimize factory usage (build > build_stubbed > create).

### Step 4.5: Lint Changed Files (BEFORE git add)

**CRITICAL**: Run Pronto BEFORE staging files to catch issues early.

Pronto only works on UNSTAGED files. Run this BEFORE `git add`.

```bash
bin/d bundle exec pronto run -r rubocop -c develop -f text
```

**Expected output**: No violations (empty output). Fix all violations, re-run until clean.

**Common violations caught**: `Layout/ArgumentAlignment`, `Rails/Delegate`, `Naming/PredicatePrefix`, `Style/InvertibleUnlessCondition`.

### Step 5: Verify Coverage (MANDATORY)

100% coverage on changed lines is required. See `/coverage` skill for full rake walkthrough.

**Evidence gate before declaring done:**

1. **VCS diff check** — run `git diff HEAD` and confirm the claimed changes are actually present in the diff. Do not declare a file changed if it does not appear.
2. **Contract reconciliation** — go through the validation contracts (C1..Cn) one by one and confirm each has a passing test. Don't assume — trace each contract to its spec line.

**No completion claim without fresh verification evidence.** You cannot use success/satisfaction wording unless the verifying command was actually run in this message:

| Claim | Required evidence | NOT sufficient |
|-------|-------------------|----------------|
| "Tests pass" | `bin/d rspec` output showing 0 failures | "Should pass", previous run, code looks right |
| "Coverage met" | `coverage:local:delta` output | "I covered all branches" |
| "Agent/worker completed" | VCS diff shows the changes | Worker's self-report of success |
| "Linter clean" | Pronto output (empty = clean) | "I fixed all the violations" |
| "Bug is fixed" | Test exercising original symptom passes | Code changed, assumed fixed |
| "Regression test guards the bug" | Red-green cycle verified (see regression proof above) | Test was written and passes once |

Red flags — STOP before claiming done:
- Using "should", "probably", "seems to"
- Expressing satisfaction ("Done!", "Perfect!", "Should work") before running the command
- Trusting a subagent/worker's success report without checking the diff

## Anti-Patterns

### Anti-over-mocking

Mock only DEPENDENCIES, never the unit under test. If you're stubbing a method on `described_class` or its own instance, that is a smell — inject the dependency or test at integration level.

This is sharper than the `allow_any_instance_of` ban (see [../shared/forbidden-patterns.md](../shared/forbidden-patterns.md)): even `allow_any_instance_of` on a collaborator is wrong; stubbing the subject itself is doubly wrong.

### Flaky-Test Triage

RED is not proven if the test is flaky. Quick decision tree:

- Passes 10x locally but fails in parallel? → `before(:each)` not `before(:all)`, `SecureRandom` uniqueness
- Time-of-day failures? → `Timecop.freeze(Time.current)`
- Redis state leaking? → `Redis.current.flushdb` in `before` — see [../shared/testing-patterns.md](../shared/testing-patterns.md)
- Order-dependent failures?

```bash
bin/d rspec <spec> --bisect --seed <failing-seed>
# bisect only does work when a failure is present
```

- Slowest examples:

```bash
bin/d rspec <spec> --profile 5
```

- CI flake quarantine: `rspec-retry` is INSTALLED but DISABLED — requires uncommenting `require 'rspec/retry'` and `config.default_retry_count` in `spec_helper.rb`. The env var is NOT forwarded by `bin/d`, so run as:

```bash
docker compose exec -e RAILS_ENV=test -e RSPEC_RETRY_COUNT=3 web bundle exec rspec <spec>
```

Document as "requires enabling config first" — it is NOT a one-liner drop-in.

- Factory overuse slowing tests?

```bash
docker compose exec -e RAILS_ENV=test -e FPROF=1 web bundle exec rspec <spec>
# FPROF=flamegraph for a visual call-graph
# Note: bin/d does not forward env vars; use docker compose exec directly
```

### Characterization Tests for Untested Legacy

When the delete-and-reimplement protocol is too risky (payment/state-machine code with >~200 lines and no tests), write tests that CAPTURE current behavior first (not asserting it's correct), then refactor green, then correct. Trigger `/code-smells` before attempting a large legacy refactor.

### Mutation Testing (note only)

`mutant`/`mutest` are NOT in the Gemfile. Mutation testing would prove tests catch bugs beyond coverage %, but adding the gem is out of scope and needs a separate sign-off. Do NOT treat mutation testing as mandatory while the gem is absent.

## Test Types

Unit (`spec/models/`, `spec/services/`), Integration (`spec/requests/`, `spec/graphql/`), System (`system_specs/` — Playwright). See [../shared/test-templates.md](../shared/test-templates.md) and [../shared/system-test-guide.md](../shared/system-test-guide.md).

## System Tests (Playwright)

System tests live in `system_specs/` (NOT `spec/`). Full guide: [../shared/system-test-guide.md](../shared/system-test-guide.md).

Quick summary: version-match gem vs CLI (`grep capybara-playwright-driver Gemfile.lock`), run via `bin/test_system`, use `SecureRandom.hex(4)` in emails, prefer Capybara's built-in `wait:` over `sleep`, auto-screenshots on failure in `tmp/screenshots/playwright/`.

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

<!-- Kaizen history archived to kaizen_log.md -->
