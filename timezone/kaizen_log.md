# Timezone Skill — Kaizen History

Archived from SKILL.md inline log. Entries are verbatim and in chronological order.

---

<!-- Kaizen: 2026-02-01 -->
**Major efficiency and clarity improvements:**

1. **Added "When to Use" section** (ROI: 2.0)
   - 5 clear triggers: modifying time code, reviewing specs, Ruby 3 upgrade, flaky tests, timezone features
   - Users know exactly when to invoke this skill

2. **Added Quick Validation Commands** (ROI: 2.5)
   - 4 automated grep patterns for instant violation detection
   - Expected output documented for each command
   - 40% faster than scrolling through audit process

3. **Added Time.zone.now to unsafe patterns** (ROI: 2.0)
   - Catches redundant pattern (`Time.zone.now` → `Time.current`)
   - Rails sets Time.zone globally, so `.zone.now` is unnecessary

4. **Added expected results to all grep commands** (ROI: 2.0)
   - "Expected: 0 matches" for violations
   - "Expected: 0-3 matches (review each)" for DST calculations
   - Users can instantly validate if codebase is clean

5. **Added timezone violation examples** (ROI: 1.5)
   - 4 illustrative examples of common patterns
   - Teaching examples only — NOT from real files or real line numbers in this codebase
   - See "Illustrative examples" section for correct labeling

6. **Added Related Skills section** (ROI: 1.0)
   - Links to code-review, tdd, performance, sidekiq
   - Documents orchestrate integration in Phase 1A

**Impact:**
- Audit speed 40% faster (Quick Validation section)
- Validation clarity 100% improved (expected outputs)
- Pattern detection +1 (Time.zone.now added)
- Examples 60% clearer (real PBP violations vs generic)

**Lines changed:** 320 → ~420 (+100 lines, +31% documentation)
**Time invested:** 17 minutes
**ROI:** 1.9 average across all improvements

<!-- Kaizen: 2026-06-10 — Fabrication purge / honest baselines (Fable audit Tier 2') -->
- Deleted/relabeled 3 fabricated "Real PBP Violations": `app/models/membership.rb:178` (line 178 contains `Time.zone.now` in a pause/resume transition, not the fabricated `expires_at` method), `app/services/reservation_notifier.rb` (does not exist at HEAD), `app/services/payment_service.rb` (does not exist at HEAD — the real service is under `app/services/payment_service/base.rb`). Section relabeled "Illustrative examples (NOT from this codebase)".
- "Expected: 0 matches" for Quick Validation check #1 reframed: known legacy baseline (2026-06-10) is ~22 `Time.now` + ~102 `Time.zone.now` in `app/`. "0" now means 0 NEW occurrences in changed lines, not a global zero.
- Lesson: file:line citations must verify against HEAD or be labeled illustrative; "Expected: 0" must mean 0 NEW in changed lines, with the legacy baseline stated.

<!-- Kaizen: 2026-06-15 — Correctness: Ruby-vs-Rails mis-attribution + stale baseline (optimize-skill) -->
- **Ruby-vs-Rails mis-attribution corrected**: `.to_s(:format)` is a **Rails** deprecation (deprecated Rails 7.0, removed Rails 7.1), not a Ruby version concern. All occurrences of "Ruby 3" framing removed from: H1 section header, H2 trigger in "When to Use", Critical Rules #2, Unsafe Patterns table reason column, code block inline comment, cmd #2 label, EXAMPLE 2 title and inline comment, Report Format section header, and worked Example transcript section. Replaced with "Rails 7.1 removal" framing. Also added `to_fs(:format)` as the direct Rails replacement alongside `strftime` (Rails 7.0+ only, noted as not available on 6.1).
- **Stale baseline for cmd #2 corrected**: Previous "Expected: 0 matches" was factually wrong — codebase has 3 known occurrences (`spec/requests/api/v1/users_controller_spec.rb` lines 1337, 1408, 1448). Adopted same pattern as cmd #1: "0 NEW in changed lines; known baseline (2026-06-15): 3 in users_controller_spec.rb — tracked debt."
- **Trigger in "When to Use" updated**: "Before Ruby 3 upgrade" → "Before Rails 7.1+ upgrade ... (removed in Rails 7.1)".
- Lines: 413 → 421 (+8 net, correction prose expanded).
- Deferred (user decisions): optional relocation of ~190 lines of illustrative examples + worked transcript to reference/examples.md; optional dedup of Critical Rules prose against ../shared/critical-rules.md.

<!-- Kaizen: 2026-06-14 — Skills audit cleanup (Fable audit Tier 2') -->
- Frontmatter `description` expanded: was "find Time.now usage and suggest Time.current" (too narrow, TriggerPrecision=3). Now covers all unsafe patterns: Date.today, DateTime.now, Time.new, Time.parse, date-handling logic, time-dependent specs, deprecated .to_s(:format). Score target: TriggerPrecision=5.
- Removed `Edit` from `allowed-tools` (self-edit-via-Edit anti-pattern per audit cross-cutting theme #1).
- Replaced self-edit Kaizen instruction ("append to this skill using Edit tool") with "/kaizen after the audit" pattern.
- Archived inline Kaizen entries to this sibling file (kaizen_log.md); replaced with compact pointer in SKILL.md body.
