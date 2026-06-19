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

<!-- Kaizen: 2026-06-14 - /optimize-skill pass -->
- Correctness: confirmed? prompt was `$stdin.gets.chomp`, which HANGS or raises nil.chomp under non-TTY (`docker compose exec -T`, in-pod, piped) — the skill's own safety gate failed in its own prescribed run env. Fixed in scripts/template.rb + references/script-template.md: `return true if dry_run` → TTY prompt → else require `CONFIRM=yes`. Also `$stdin.gets.to_s.chomp` for nil-safety.
- Correctness: clarified bin/d is LOCAL docker-compose dev only; `RAILS_ENV=production bin/d runner ...` examples were misleading (bin/d never reaches the prod cluster; RAILS_ENV=production locally points at absent/misconfigured prod DB config). Prod runs now documented as in-pod `rails runner` (kubectl exec), not bin/d.
- Correctness: Pattern 5 `requires_new: true` re-described — yields a real SAVEPOINT only when nested inside an outer transaction; at top level it is an ordinary transaction (was implied to always add a savepoint).
- Correctness: description rewritten to state the trigger context (WHEN), not just WHAT — improves auto-invocation under disable-model-invocation:false.
- Structure: body 635 → ~110 lines. Relocated Script Template, Pattern Library, Real-World Examples, and Report Format to references/ (script-template.md, patterns.md, examples.md, run-summary.md) + copyable scripts/template.rb. Folded "Common Mistakes" into patterns.md (they were inverses of Patterns 1/3/4 + Step-5 guidance). Deduped restated CRITICAL RULES into pointers to shared/critical-rules.md, shared/forbidden-patterns.md, and CLAUDE.local.md #8/#9/#11/#12. Removed the Config Priority banner (already in shared docs).
- Deferred (USER-DECISION, not applied): (1) keep vs remove/relocate `disable-model-invocation: false` (harness extension, not in upstream Anthropic skill frontmatter spec); (2) confirmed? strategy — drop entirely for LIVE-only vs the tty+CONFIRM guard applied; (3) whether prod examples should show the real in-pod runbook path vs illustrative. Applied the headless-safe guard as the conservative correctness fix; the UX/spec-conformance calls remain the user's.
- Source: /optimize-skill worker pass 2026-06-14.

<!-- Kaizen: 2026-06-14 - Safety/accuracy patch on two missed copies -->
- Safety: examples.md had two worked scripts (BackfillMembershipPayments, FixReservationTimestamps) that silently omitted the headless-safe `confirmed?` method. A practitioner copying from these examples would get the OLD hanging pattern under `docker compose exec -T` / non-TTY — the exact failure the /optimize-skill pass fixed in template.rb. Added a prominent WARNING callout at the top of examples.md: "INCOMPLETE FOR COPY-PASTE — always copy `confirmed?` from scripts/template.rb". Chose callout over inlining full method bodies because examples are intentionally concise business-logic illustrations, not copy-paste starters; the template.rb is the canonical copy-paste source.
- Accuracy: SKILL.md line 61 prose described the `confirmed?` branching order as "if $stdin.tty? prompt → else require CONFIRM=yes", which is the INVERSE of the actual code (`return true if dry_run` → `unless $stdin.tty?` require CONFIRM → else prompt). Fixed to: "if NOT a TTY (unless $stdin.tty?) require CONFIRM=yes → else (TTY) prompt for yes". Code is the source of truth; prose must match exactly or the mental model inverts the safety gate.
- Source: Correctness audit 2026-06-14 — two copies missed by /optimize-skill pass.
