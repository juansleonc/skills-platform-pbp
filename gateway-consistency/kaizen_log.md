# gateway-consistency — Kaizen Log (archived)

Full narrative history. The active skill only keeps the changelog table; verbose entries live here.

---

## 2026-06-14 — Skills audit fixes (audit-2026-06-13)

**Dead shared-doc link**: `../../docs/domains/payments.md` resolved to `.claude/docs/domains/payments.md` (does not exist). Fixed to `../../../docs/domains/payments.md` (project root `docs/domains/payments.md` — confirmed with `find`).

**Wrong webhook directory**: Check in Step 5 targeted `app/controllers/webhooks/` which contains only `pbp_rating_controller.rb` (not payment-related). Payment webhooks live in `packs/billing/app/controllers/billing/webhooks_controller.rb` (Stripe signature-verified, handles checkout/subscription/invoice events). Fixed path and grep target accordingly.

**Added `/pci-compliance` disambiguator**: description and scope-boundary note added to the frontmatter and header — gateway-consistency = cross-gateway divergence; pci-compliance = card-data protection (PCI-DSS Reqs 3, 4, 6, 7, 10).

**Kaizen self-edit anti-pattern**: replaced "append to this file using Edit tool" instruction with "run `/kaizen` after the audit" to avoid unreviewed mid-execution skill drift. Archived log to this sibling file. Canonical Pronto command updated to full form.

---

## 2026-06-10 — ClickHouse SQL run-test pass

- Removed `processing_time_ms` column from all ClickHouse queries (column does not exist in `pbp_productionDB_optimized.payments`); gateway latency analysis redirected to New Relic.
- Fixed FINAL placement: all three `payments` queries now use `FROM pbp_productionDB_optimized.payments FINAL`.
- `count(*)` → `count()` (ClickHouse idiom).
- Added per-gateway volume query as canonical example.
- Stamped "Columns verified 2026-06-10 against production ClickHouse" on section.
- Fixed ClickHouse tool name: `run_select_query` → `run_query`.

---

## 2026-06-10 — Fix broken paths + gateway list

- Fixed all audit-loop paths: `payment_service/${gw}/` → `payment_service/gateway/${gw}/` — previous paths produced 100% false negatives.
- Removed `app/adapters/${gateway}/` references — no per-gateway subdirs there.
- Regenerated gateway list from `ls`: removed `luka_pay` (lives in `payments/lukapay/`, separate pattern), added `xendit`.
- Lesson: every named path and list in a skill must be regenerated from the repo, never hand-maintained.

---

## 2026-06-10 — Add When to Use trigger

- Added "When to Use" section with auto-trigger criteria for payment/gateway file globs.
- Integration score was 2/5 before this fix; ensures the skill runs on every payment-path PR.
- Source: QA audit 2026-06-10.
