# TDD Skill — Kaizen History

Archived from SKILL.md inline log. Entries are verbatim and in chronological order.

---

<!-- Kaizen: 2026-01-22 -->
- Added: Context7 integration for RSpec/testing best practices lookup
- Added: code-simplifier agent workflow for test optimization
- Added: "PERFORMANCE IS CRITICAL" section emphasizing test speed
- Enhanced: Factory Rules with decision tree and performance impact examples
- Added: Test profiling commands to measure slow tests
- Added: mcp__context7__* tools to allowed-tools

<!-- Kaizen: 2026-05-12 - User correction -->
- Added: For TDD on HTTP-facing code (GraphQL resolvers, controllers, middlewares, endpoint-triggered jobs), the failing test in the RED step should be an INTEGRATION spec that exercises the real entry point (e.g. `graphql_post(query, token, params)` for GraphQL), not a unit spec that stubs the framework or calls private methods on an `allocate`d object.
- Why: Stubbed/private-method tests pass under conditions that don't hold in production. The aliased-`eventsNearby` context-collision bug was only catchable via a request-level spec — a unit test would have hidden it.
- How to apply: When writing the RED test, ask "would this test still fail if I ran the actual HTTP request through the real stack?" If no, escalate to integration. Unit-level stubs are acceptable for genuinely internal services with no HTTP entry.
- Promoted to Step 1 + Step 2 of the workflow in the 2026-06-13 density refactor.

<!-- Kaizen: 2026-06-09 — RED must actually fail + self-review + evidence gate (adapted from obra/superpowers, MIT) -->
- RED phase: made "watch it fail" explicit — run `bin/d rspec` and READ the output; confirm the failure is "feature missing", not a load error. "Assume it fails" is not allowed.
- Self-review checkpoint (Step 5.5, before handoff): 5-axis pass (Completeness / Quality / YAGNI / Testing / Escalation); fixes what it finds; reports what it fixed. Early filter only — the independent validator gate is still mandatory.
- Evidence gate (Step 5 addendum): two net-new items before declaring done — (i) `git diff HEAD` confirms claimed changes exist; (ii) contract reconciliation traces each C1..Cn to a passing spec line. Tests/lint/coverage checks already enforced by the TDD cycle + `/coverage` + Pronto.

<!-- Kaizen: 2026-06-10 — Mechanism grafts from obra/superpowers (MIT, commit 6fd4507) -->
- Added: Iron Law / delete-code protocol (§ "If Code Was Written Before Tests") — verbatim from superpowers `skills/test-driven-development/SKILL.md` lines 31-45. The local skill already forbade writing implementation first but prescribed nothing when it had already happened. Protocol: stash/delete untested code → write failing test → reimplement. "Delete means delete."
- Added: Rationalization/excuse table + Red Flags self-check block immediately after the RED run command — from superpowers lines 256-288. Distinct from the evidence/claim gate at Step 5 (which gates AFTER work) and from the regression proof ritual (which validates a specific guard): this table intercepts rationalizations BEFORE the test step is skipped. PBP adaptation: command references use `bin/d rspec` per CLAUDE.local.md rule #2.
- Source: `/tmp/superpowers-20260610/skills/test-driven-development/SKILL.md` (MIT license)

<!-- Kaizen: 2026-06-10 — Empty section + Kaizen note (Fable re-audit hygiene pass) -->
- Deleted: dangling empty "## MCP Integrations" section header (residue from a prior purge; had no content).
- Added: one-line supersession note to the 2026-02-01 Kaizen entry that still praised `make test-all` (target does not exist in Makefile).

<!-- Kaizen: 2026-06-10 — Fix make test-all + parallel spec command (Fable audit Tier 3) -->
- Replaced `make test-all` (PREFERRED, but non-existent Makefile target) with `bin/d rails parallel:spec` throughout the Docker Environment section. Verified: Makefile has exactly 11 targets; `test-all` is not one of them. `make test TEST_PATH=...` is real (uses TEST_PATH variable) and kept where appropriate.

<!-- Kaizen: 2026-06-10 — Purge stale tool references (superpowers-spike 2026-06-10 drift findings) -->
- Removed: `mcp__playwright__*` from frontmatter allowed-tools — the Playwright MCP server is not configured in this project; its presence caused dispatch confusion. Playwright system tests via `bin/test_system` and `system_specs/` are real and fully documented in the System Tests section above.
- Removed: "Playwright MCP" subsection (~lines 540-561) that referenced the unconfigured MCP server tools.
- Fixed: frontmatter description rewritten from workflow summary ("Always write tests FIRST before any implementation. Covers unit, integration, and system tests") to trigger conditions only — CSO rule: description = when to invoke, never the process; agents that read the description instead of the body follow an incomplete workflow.
- Lesson: stale allowed-tools in frontmatter are loaded at session start and pollute the tool namespace with non-functional tools; check on every superpowers-spike pass.

<!-- Kaizen: 2026-06-13 — Density refactor + B1-B6 techniques -->
- Density refactor: 657 → 398 lines. Extracted full "Test Structure Template" + RED inline template → ../shared/test-templates.md. Extracted full "System Tests (Playwright)" section (~95 lines) → ../shared/system-test-guide.md. SKILL.md now points to both.
- Deleted: stale 2026-02-01 inline praise of `make test-all` (already superseded); removed duplicate factory inline table ("Factory Rules (CRITICAL for Performance)") — single pointer to factory-rules.md retained. Removed verbose Time-Dependent/Redis blocks — pointer to testing-patterns.md. Removed long code-simplifier agent prompt — delegated to /factory-check + factory-rules.md.
- Added B1: Assertion-Depth gate table (coverage-theater vs behavioral assertions; 100% line coverage ≠ behavioral coverage).
- Added B2: HTTP-facing classification promoted to Step 1 + Step 2 (was Kaizen-log-only); no new ticket refs in body; Kaizen entry shortened to "promoted".
- Added B3: Anti-over-mocking rule (mock only dependencies, never described_class itself).
- Added B4: Flaky-test triage with spike-validated command forms: `--bisect --seed`, `--profile 5`, `rspec-retry` enabled via docker compose exec (NOT bin/d, requires spec_helper uncomment), `FPROF=1` factory-prof (NOT FACTORY_PROF).
- Added B5: Characterization tests for untested legacy >~200 lines; cross-reference /code-smells.
- Added B5 (Flaky-Test Triage / B4 addendum): test-prof factory-prof pointer with spike-validated `FPROF=1` form (embedded in B4 section, not standalone).
- Added B6: Mutation testing note-only (mutant/mutest absent from Gemfile; out of scope; NOT mandatory).
- Coverage step: replaced duplicated rake walkthrough with pointer to /coverage skill (load-bearing claim-vs-evidence table and contract reconciliation retained inline).
