# Safe-Script Kaizen Log

Historical improvement entries archived from SKILL.md.
Active lessons promoted into the skill body; entries here are for record only.

---

<!-- Kaizen: 2026-05-22 - User correction -->
- Rule: Respect approved scope before a script makes a destructive step (DELETE/cleanup) a default/enforced action — never institutionalize a step the ticket marked out-of-scope. Approval of X (e.g. links) ≠ approval to delete other tables.
- Why: In CORE-624 nearly baked faves/user_stats deletion into the cleanup as an enforced default; the user caught that Erick had scoped those tables out — the exact scope creep (L3) that TRIAGE-10's prod script committed (deleted 200K faves the runbook marked out-of-scope).
- How to apply: Before a script deletes from a table by default, re-read the approval record ("Out of scope / Pendiente / cleanup separado"). If out of scope: leave it out or make it strictly opt-in (flag default OFF) pending separate sign-off. Distinguish integrity consequences of an approved action (touch/reindex) from new destructive ops on other tables.
- Source: User correction on 2026-05-22. See `memory/feedback_respect_approved_scope.md`.

<!-- Kaizen: 2026-06-14 - Skills audit fix -->
- Contradiction resolved: Pattern 1 (#{}  on AR integers) vs Pattern 6 (#{} on external strings) now use a single coherent rule. Pattern 6's danger example changed from `params[:id]` (controller context, unavailable in runner) to `ARGV[0]` (realistic script context). Added Integer() cast as acceptable intermediate. CRITICAL RULE #2 clarified: heredoc ban applies to interactive `rails c`, NOT `rails runner` script files.
- Source: Skills audit 2026-06-13 confirmed finding.
