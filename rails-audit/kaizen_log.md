# rails-audit Kaizen Log

Archived from `SKILL.md` to reduce context load on invocation.

| Date | Entry |
|------|-------|
| 2026-06-10 | ClickHouse MCP tool name: `run_select_query` → `run_query` (residue cleanup, Fable audit Tier 2') |
| 2026-06-14 | Removed 4 unused MCP tools from allowed-tools (ClickHouse, Honeybadger — never called in body); added TIMEZONE to category table (was missing); added TESTING/GEM-HYGIENE/API Phase 1 stubs; added `/pci-compliance` dispatch for payment code; archived Kaizen to sibling log; fixed Pronto to canonical form; `bin/d` for bash commands. |
| 2026-06-15 | optimize-skill pass: fixed Phase 1 framing (line 57) — grep/bash scans are host-side, NOT Docker; only Phase 2 Ruby/Rails commands need `bin/d`. Deferred: (a) `disable-model-invocation: false` portability note vs. drop (user decision); (b) optional structural wins — relocate Report Format template, collapse Category-Specific Invocation, dedup Related Skills vs Audit Categories table (none required at 306 lines). |
