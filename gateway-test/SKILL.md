---
name: gateway-test
description: Generate idempotent payment gateway tests with sandbox credentials
allowed-tools: [Bash, Read, Write, Edit, Grep, Glob]
disable-model-invocation: true
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## When to Use

**Manual invocation** (`/gateway-test`) — run it when:
- Implementing a NEW payment gateway (mandatory — generates the full test suite)
- Writing or updating tests for an existing gateway's charge/refund/void flows
- A PR touches `app/services/payment_service/gateway/**` and has no spec changes

This skill generates idempotency-first test templates with sandbox credential safety and VCR cassette patterns for all 14 supported gateways.

Note: this skill is manual-only (`disable-model-invocation: true`); the Skill Router row for new gateways is a reminder to invoke it, not an auto-trigger.

# Payment Gateway Test Skill

Generate comprehensive, idempotent tests for payment gateway integrations.

## Supported Gateways

> **Gateway list — Last verified: 2026-06-10.** Never hand-maintain this list — regenerate from `ls app/services/payment_service/gateway/`.
> **Note:** `lukapay` is implemented separately in `app/services/payments/lukapay/` and does NOT follow the gateway pattern — exclude it from gateway-pattern audits.

| Gateway | Default | Notes |
|---------|---------|-------|
| `card_connect` | ✅ | Default gateway |
| `stripe` | | Popular choice |
| `pixel_pay` | | Latin America |
| `azul_pay` | | Dominican Republic |
| `kushki_pay` | | Latin America |
| `xendit` | | Southeast Asia |
| `icount` | | Israel |
| `dpo_pay` | | Africa |
| `mitec` (GetNet) | | Brazil |
| `pay_fast` | | South Africa |
| `bac` | | Central America |
| `one_pay` | | |
| `pay_code` | | |
| `razor_pay` | | India |

## Usage

```
/gateway-test <gateway_name> [method]
```

Examples:
```
/gateway-test stripe
/gateway-test stripe process_payment
/gateway-test card_connect refund
```

## Real Architecture — Read This First

The codebase uses **per-operation service objects**, not a monolithic gateway class.
Each gateway has a directory of operation classes, all inheriting from a `Base` class that itself
inherits from `PaymentService::Gateway::Base`. The Stripe namespace is:

```
app/services/payment_service/gateway/stripe/
  base.rb          # < PaymentService::Gateway::Base
  authorize.rb     # PaymentService::Gateway::Stripe::Authorize
  capture.rb
  card_info.rb
  customer_creation.rb
  refund.rb        # PaymentService::Gateway::Stripe::Refund
  sale.rb          # PaymentService::Gateway::Stripe::Sale
  tokenize.rb
  void.rb
  payment_method.rb
  register_oauth.rb
  notification/
  operations/
  payment_intent/
  terminal/
  webhook/
```

Each operation class `include`s `Interactor` (via the base) and exposes a single `#call` method.
Callers use `ClassName.call(context)` or `ClassName.new(context)` then `subject.call`.
The context (`Interactor::Context`) carries `facility`, `user`, `payment`, `user_token`, and
the operation writes its result back to `context.response` (or calls `context.fail!(error: ...)`)

**Before writing any test**, read the specific service object you are targeting:

```bash
ls app/services/payment_service/gateway/<gateway>/
cat app/services/payment_service/gateway/<gateway>/<operation>.rb
```

## Stubbing — VCR + webmock (not StripeMock)

`StripeMock` is **NOT in the Gemfile**. The installed stubbing tools are:

- `vcr` (= 6.3.1) — record/replay HTTP cassettes
- `webmock` (= 3.14.0) — block/stub outbound HTTP

**Stripe specs do not use VCR cassettes for the unit layer.** Instead they stub the Stripe Ruby
SDK classes directly (`allow(Stripe::Refund).to receive(:create).and_return(...)`) using two
modules:

- **`StripeMockHelper`** (`spec/support/stripe_mock_helper.rb`) — globally auto-included in every
  spec via `config.include(StripeMockHelper)` (no type filter). Provides the `mock_*` factory
  methods:
  - `mock_refund(...)`, `mock_payment_intent(...)`, `mock_customer(...)`, `mock_payment_method(...)`
  - `mock_card_error(...)`, `mock_invalid_request_error(...)`, `mock_api_connection_error(...)`

- **`StripeTestHelper`** (`spec/support/stripe_test_helper.rb`) — auto-included for
  `type: :service` specs under `spec/services/payment_service/gateway/stripe` AND for
  `stripe: true`-tagged specs (via `config.include(StripeTestHelper, ...)` in the support file).
  For stripe gateway specs in that path the `include StripeTestHelper` in the template is
  harmless but redundant. Include it explicitly only for stripe specs **outside** that path.
  Provides realistic Stripe-object builders:
  - `stripe_payment_intent(...)`, `stripe_payment_method(:visa, ...)`, `stripe_customer(...)`
  - `stripe_charge(...)`, `three_ds_next_action(...)`, `stripe_webhook_event(...)`

Because `StripeMockHelper` is globally auto-included, you do NOT need to `include StripeMockHelper`
in your spec. For stripe gateway specs under `spec/services/payment_service/gateway/stripe`,
`StripeTestHelper` is also auto-included — the explicit `include` in the template matches the
real spec and is kept for clarity, but is not strictly required there.

**VCR is used only in opt-in integration blocks** gated on `ENV['STRIPE_TEST_KEY'].present?`:

```ruby
describe 'VCR integration tests', vcr: { record: :new_episodes } do
  context 'when STRIPE_TEST_KEY is set', if: ENV['STRIPE_TEST_KEY'].present? do
    before do
      allow(Rails.application.secrets).to receive(:stripe_secret_key)
        .and_return(ENV['STRIPE_TEST_KEY'])
    end

    it 'refunds a real card payment' do
      VCR.use_cassette('stripe/refund/card_partial_refund') do
        # ... real Stripe call ...
      end
    end
  end
end
```

For non-Stripe gateways that make HTTP calls through their own client library (e.g. CardConnect via
`CardConnectTools`), stub the client object directly with `allow(...).to receive(...)` — see the
card_connect authorize spec for the pattern.

## Sandbox Credentials Safety

NEVER hardcode or read real credentials. For Stripe, the service reads
`Rails.application.secrets.stripe_secret_key` for the API key and reaches the connected-account id
via `context.payment&.facility&.stripe_user_id` — facility is accessed **through the payment**,
not as a separate top-level context key. In tests:

```ruby
# Facility: build_stubbed, pass stripe_user_id as a fake connected-account string
let(:facility) { build_stubbed(:facility, :skip_callbacks, stripe_user_id: 'acct_test_123') }

# The service reads Rails.application.secrets.stripe_secret_key at call time.
# Stub it only in VCR/integration blocks that need a real key:
allow(Rails.application.secrets).to receive(:stripe_secret_key).and_return(ENV['STRIPE_TEST_KEY'])

# For other gateways, credentials live in the merchants table.
# Use build_stubbed(:merchant, ...) — do NOT create(:merchant) unless testing DB queries.
```

## Test Template (Stripe Refund — real pattern)

This template is modeled on `spec/services/payment_service/gateway/stripe/refund_spec.rb`.
Adapt the class name and context keys for the operation you are testing.

```ruby
# frozen_string_literal: true

require 'rails_helper'

# Replace ::Refund with the real operation class name you found in the source.
RSpec.describe PaymentService::Gateway::Stripe::Refund do
  # StripeMockHelper is globally auto-included (no explicit include needed).
  # Include StripeTestHelper only if you need stripe_payment_intent/stripe_payment_method/etc.
  include StripeTestHelper      # stripe_payment_intent, stripe_payment_method, stripe_charge, etc.
  include InteractorTestHelper  # with_interactor_failure, with_interactor_success

  # build_stubbed: no DB hit; :skip_callbacks avoids merchant/court creation
  let(:facility) { build_stubbed(:facility, :skip_callbacks, stripe_user_id: 'acct_test_123') }
  let(:user)     { build_stubbed(:user) }

  # Build a minimal payment object for the operation under test.
  # Check the real service's #call and private methods to know which attributes are read.
  let(:payment) do
    payment = build_stubbed(:payment,
      facility: facility,
      user:     user,
      reference: 'ch_card_123',
      payment_method: 'card',
      user_token: build_stubbed(:user_token, user: user, token: 'tok_visa', gateway: 'stripe'))
    payment.amount_to_partial_refund = 50.00
    payment
  end

  # The service reads context keys, not constructor args.
  let(:base_context) { { facility: facility, payment: payment } }
  let(:context)      { Interactor::Context.new(base_context) }

  # Instantiate with context, call subject.call (not described_class.call — that raises on failure)
  subject { described_class.new(context) }

  # ── IDEMPOTENCY FIRST ──────────────────────────────────────────────────────
  # Test that a duplicate call does not double-charge / double-refund.
  # For Stripe this means the same charge param is passed both times;
  # for stateful operations, verify the idempotency_key or lock mechanism.
  describe 'idempotency' do
    it 'sends the same charge reference on repeated calls' do
      refund = mock_refund(id: 're_idem_123', charge: 'ch_card_123', status: 'succeeded')
      allow(Stripe::Refund).to receive(:create).and_return(refund)

      subject.call
      subject.call  # second call with the same context

      expect(Stripe::Refund).to have_received(:create)
        .with(hash_including(charge: 'ch_card_123'), anything).twice
    end
  end

  # ── HAPPY PATH ─────────────────────────────────────────────────────────────
  describe '#call' do
    context 'successful refund' do
      it 'creates a partial refund and stores the response in context' do
        refund = mock_refund(id: 're_123', amount: 5_000, charge: 'ch_card_123', status: 'succeeded')

        expect(Stripe::Refund).to receive(:create)
          .with(
            { charge: 'ch_card_123', amount: 5_000 },
            { api_key: Rails.application.secrets.stripe_secret_key,
              stripe_account: 'acct_test_123' }
          )
          .and_return(refund)

        subject.call

        expect(context.success?).to be true
        expect(context.response).to eq(refund)
      end

      it 'passes nil stripe_account when facility has no stripe_user_id' do
        facility.stripe_user_id = nil
        allow(Stripe::Refund).to receive(:create).and_return(mock_refund(charge: 'ch_card_123'))

        subject.call

        expect(Stripe::Refund).to have_received(:create)
          .with(anything, hash_including(stripe_account: nil))
      end
    end

    # ── ERROR PATHS ────────────────────────────────────────────────────────────
    context 'error handling' do
      it 'fails context on already-refunded error' do
        error = mock_invalid_request_error(
          message: 'Charge ch_card_123 has already been refunded.',
          param: 'charge'
        )
        allow(Stripe::Refund).to receive(:create).and_raise(error)

        failed_context = with_interactor_failure { subject.call }

        expect(failed_context.error).to eq('Charge ch_card_123 has already been refunded.')
      end

      it 'fails context on network error' do
        allow(Stripe::Refund).to receive(:create)
          .and_raise(mock_api_connection_error(message: 'Network connection failed'))

        failed_context = with_interactor_failure { subject.call }

        expect(failed_context.error).to eq('Network connection failed')
      end
    end

    # ── VCR INTEGRATION (opt-in, requires STRIPE_TEST_KEY env var) ─────────────
    describe 'VCR integration', vcr: { record: :new_episodes } do
      context 'when STRIPE_TEST_KEY is set', if: ENV['STRIPE_TEST_KEY'].present? do
        before do
          allow(Rails.application.secrets).to receive(:stripe_secret_key)
            .and_return(ENV['STRIPE_TEST_KEY'])
        end

        it 'refunds a real charge against the Stripe sandbox' do
          VCR.use_cassette('stripe/refund/card_partial_refund') do
            charge = Stripe::Charge.create({ amount: 5_000, currency: 'usd', source: 'tok_visa' })
            payment.reference = charge.id

            subject.call

            expect(context.success?).to be true
          end
        end
      end
    end
  end
end
```

## Per-Operation Notes

When writing a spec for a different operation (`Sale`, `Authorize`, `Capture`, `Void`, etc.):

1. Read the source first: `cat app/services/payment_service/gateway/stripe/<operation>.rb`
2. Check what the context hash must contain (look at `context.<field>` reads in the source)
3. Check what Stripe SDK class and method is called (`Stripe::PaymentIntent.create`, etc.)
4. Model your stubs on that — do not guess method names or response shapes

Real specs to reference:
- Sale: `spec/services/payment_service/gateway/stripe/sale_spec.rb`
- Authorize: `spec/services/payment_service/gateway/stripe/authorize_spec.rb`
- Capture: `spec/services/payment_service/gateway/stripe/capture_spec.rb`
- Void: `spec/services/payment_service/gateway/stripe/void_spec.rb`

## Other Gateways

For the other 13 gateways, **do not fabricate stub patterns from memory**. Find the real spec first:

```bash
find spec -path '*<gateway_name>*' -name '*_spec.rb'
# e.g. find spec -path '*card_connect*' -name '*_spec.rb'
```

Read one spec and one source file before writing any test. Each gateway has its own client library
and response shape. CardConnect, for example, stubs `CardConnectTools.authorize_charge` directly
(no VCR at the unit layer). RazorPay, Xendit, and others may use webmock stubs or their own
mock helpers — confirm from the existing spec before writing new ones.

## Docker Environment

**All tests run in Docker web container:**

```bash
# Run a single gateway operation spec (preferred)
bin/d rspec spec/services/payment_service/gateway/stripe/refund_spec.rb

# Run all stripe gateway specs
bin/d rspec spec/services/payment_service/gateway/stripe/

# Run all payment service specs
bin/d rspec spec/services/payment_service/

# VCR recording against real Stripe sandbox (inject key via -e, never hardcode)
docker compose exec -e STRIPE_TEST_KEY="$STRIPE_TEST_KEY" -e VCR_RECORD=new_episodes \
  web bundle exec rspec spec/services/payment_service/gateway/stripe/refund_spec.rb
```

## Checklist

- [ ] Read the real service object source before writing any test
- [ ] Used `build_stubbed` for facility/user/payment (not `create` unless testing DB queries)
- [ ] Idempotency tested first (before happy path)
- [ ] Stubbed the real SDK/client method (verified from source, not guessed)
- [ ] Sandbox credentials only — no real keys hardcoded anywhere
- [ ] Error paths covered (at least: already-processed, network error, invalid params)
- [ ] VCR integration block is opt-in (`if: ENV['...'].present?`)
- [ ] Webhook handling tested (if the operation triggers webhooks)
- [ ] `bin/d rspec <spec_path>` passes before declaring done

## Example Invocation

```
User: /gateway-test stripe refund

Claude:
1. Read app/services/payment_service/gateway/stripe/refund.rb
   → Class: PaymentService::Gateway::Stripe::Refund
   → Context keys: facility, payment
   → SDK call: Stripe::Refund.create(refund_params, { api_key:, stripe_account: })

2. Read spec/services/payment_service/gateway/stripe/refund_spec.rb for existing pattern
   → Helpers: StripeMockHelper (global auto-include), StripeTestHelper (explicit, for stripe_* builders), InteractorTestHelper
   → Stubbing: allow(Stripe::Refund).to receive(:create).and_return(mock_refund(...))  # mock_refund from StripeMockHelper
   → VCR block: gated on ENV['STRIPE_TEST_KEY'].present?

3. Generate spec at spec/services/payment_service/gateway/stripe/refund_spec.rb
   using the template above, adapting to the specific operation's context keys and SDK call.

4. Run: bin/d rspec spec/services/payment_service/gateway/stripe/refund_spec.rb
```

---

## MCP Integrations

For Stripe API documentation, query Context7 (`mcp__context7__query-docs`); there is no Stripe MCP server in this setup.

---

## Kaizen: Continuous Improvement

If you discover a better pattern while using this skill, run `/kaizen` after completing the task.
Do NOT self-edit this file mid-execution.

Full changelog: [`kaizen_log.md`](kaizen_log.md)
