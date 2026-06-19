# gateway-test Kaizen Log

Archived from SKILL.md on 2026-06-14. Operational lessons that have already been promoted into the SKILL.md body.

---

<!-- Kaizen: 2026-06-10 — Add When to Use trigger (QA audit Tier 1 fix) -->
- Added "When to Use" section with auto-trigger criteria (new gateways, gateway spec changes).
- Integration score was 2/5; this ensures test templates are generated for every new gateway.
- Source: QA audit 2026-06-10.

<!-- Kaizen: 2026-06-10 — Remove stale Stripe MCP + fix gateway list + trigger consistency (Fable audit) -->
- Removed mcp__stripe__* from allowed-tools and the Stripe MCP usage section — no such server exists (.mcp.json verified); Context7 is the docs path.
- Fixed gateway table: removed luka_pay (separate pattern in payments/lukapay/), added xendit.
- Reworded "Auto-trigger" → "Manual invocation" to match disable-model-invocation: true.

<!-- Kaizen: 2026-06-10 — Template rewritten against the real per-operation architecture (Fable re-audit) -->
- Old template targeted a monolithic `PaymentService::Stripe#process_payment` (class does not exist) and `StripeMock.start/stop` (gem is NOT in the Gemfile — only `vcr` and `webmock` are installed).
- New template copies the real service-object namespace (`PaymentService::Gateway::Stripe::Refund`) and call pattern (`described_class.new(context)` + `subject.call`) directly from `app/services/payment_service/gateway/stripe/refund.rb` and `spec/services/payment_service/gateway/stripe/refund_spec.rb`.
- Stubbing approach: `allow(Stripe::Refund).to receive(:create).and_return(mock_refund(...))` using `StripeMockHelper` (globally auto-included). VCR is opt-in for integration blocks gated on `ENV['STRIPE_TEST_KEY'].present?`.
- Added "Real Architecture" section explaining the per-operation namespace and Interactor context pattern so new gateway specs always start from the correct shape.
- Replaced fabricated per-gateway code snippets with a "find the real spec first" directive to prevent future drift.
- Lesson: code templates rot invisibly because nobody executes them during doc sweeps — regenerate templates from a real spec, never from memory.

<!-- Kaizen: 2026-06-14 — Fix module attribution (skills audit 2026-06-13 confirmed finding) -->
- `mock_refund`/`mock_payment_intent`/`mock_customer`/`mock_card_error`/`mock_api_connection_error`
  were incorrectly attributed to `StripeTestHelper`. They are actually defined in `StripeMockHelper`
  (`spec/support/stripe_mock_helper.rb`), which is globally auto-included via `config.include(StripeMockHelper)`
  with no type filter.
- `StripeTestHelper` (`spec/support/stripe_test_helper.rb`) provides the `stripe_*` object builders
  (`stripe_payment_intent`, `stripe_payment_method`, etc.) and is explicitly included only when needed.
- The real refund spec only `include`s `StripeTestHelper` and gets `mock_*` methods via the global auto-include.
- Promoted corrected attribution into the Stubbing section and template comments in SKILL.md.
- Self-edit-via-Edit Kaizen anti-pattern removed; use `/kaizen` instead of Edit in this file.

<!-- Kaizen: 2026-06-15 — Fix StripeTestHelper auto-include scope + stripe_user_id access path (optimize-skill correctness pass) -->
- `StripeTestHelper` is auto-included by RSpec config for `type: :service` specs under
  `spec/services/payment_service/gateway/stripe` AND for `stripe: true`-tagged specs
  (verified in `spec/support/stripe_test_helper.rb` lines 407-409). Prose previously stated
  "included explicitly when needed" without acknowledging the auto-include path — updated
  to clarify that the `include StripeTestHelper` in the template is redundant for stripe gateway
  specs in that path (matches the real refund_spec.rb:6 which also includes it redundantly).
- `stripe_user_id` access path corrected: the service reads it via
  `context.payment&.facility&.stripe_user_id` (verified in `refund.rb:7`), not from a
  top-level `facility` context key. Updated Sandbox Credentials prose to reflect the exact
  access chain. The template behavior was already correct; only the description was imprecise.
