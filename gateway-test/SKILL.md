---
name: gateway-test
description: Generate idempotent payment gateway tests with sandbox credentials
allowed-tools: [Bash, Read, Write, Edit, Grep, Glob, mcp__stripe__*]
disable-model-invocation: true
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

# Payment Gateway Test Skill

Generate comprehensive, idempotent tests for payment gateway integrations.

## Supported Gateways

| Gateway | Default | Notes |
|---------|---------|-------|
| `card_connect` | ✅ | Default gateway |
| `stripe` | | Popular choice |
| `pixel_pay` | | Latin America |
| `azul_pay` | | Dominican Republic |
| `kushki_pay` | | Latin America |
| `luka_pay` | | |
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

## Test Requirements

### Idempotency
All payment operations MUST be idempotent:
```ruby
# Good - Idempotent
it 'processes payment idempotently' do
  idempotency_key = SecureRandom.uuid

  result1 = service.process_payment(amount: 100, idempotency_key: idempotency_key)
  result2 = service.process_payment(amount: 100, idempotency_key: idempotency_key)

  expect(result1.transaction_id).to eq(result2.transaction_id)
end
```

### Database Transactions
All payment operations MUST use database transactions:
```ruby
it 'uses database transaction' do
  expect {
    service.process_payment(amount: 100)
  }.to change(PaymentTransaction, :count).by(1)

  # On failure, should rollback
  expect {
    service.process_payment(amount: -1)
  }.not_to change(PaymentTransaction, :count)
end
```

### Sandbox Credentials
NEVER use production credentials in tests:
```ruby
let(:gateway_config) do
  {
    api_key: 'sandbox_test_key',
    merchant_id: 'test_merchant',
    environment: 'sandbox'
  }
end
```

## Test Template

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentService::<GatewayName> do
  subject(:service) { described_class.new(facility: facility) }

  let(:facility) { create(:facility, :skip_callbacks) }
  let(:merchant) { create(:merchant, facility: facility, gateway: '<gateway_name>') }

  describe '#process_payment' do
    let(:payment_params) do
      {
        amount: 1000, # in cents
        currency: 'USD',
        customer_id: 'cust_123',
        idempotency_key: SecureRandom.uuid
      }
    end

    context 'when payment succeeds' do
      before do
        stub_gateway_request(:success)
      end

      it 'returns successful result' do
        result = service.process_payment(payment_params)

        expect(result).to be_success
        expect(result.transaction_id).to be_present
      end

      it 'creates payment transaction record' do
        expect {
          service.process_payment(payment_params)
        }.to change(PaymentTransaction, :count).by(1)
      end

      it 'is idempotent' do
        result1 = service.process_payment(payment_params)
        result2 = service.process_payment(payment_params)

        expect(result1.transaction_id).to eq(result2.transaction_id)
      end
    end

    context 'when payment fails' do
      before do
        stub_gateway_request(:failure, error: 'insufficient_funds')
      end

      it 'returns failure result' do
        result = service.process_payment(payment_params)

        expect(result).to be_failure
        expect(result.error_code).to eq('insufficient_funds')
      end

      it 'does not create transaction record' do
        expect {
          service.process_payment(payment_params)
        }.not_to change(PaymentTransaction, :count)
      end
    end

    context 'when gateway times out' do
      before do
        stub_gateway_request(:timeout)
      end

      it 'handles timeout gracefully' do
        result = service.process_payment(payment_params)

        expect(result).to be_failure
        expect(result.error_code).to eq('gateway_timeout')
      end
    end
  end

  describe '#refund' do
    let(:original_transaction) { create(:payment_transaction, facility: facility) }
    let(:refund_params) do
      {
        transaction_id: original_transaction.gateway_transaction_id,
        amount: 500,
        reason: 'customer_request'
      }
    end

    context 'when refund succeeds' do
      before do
        stub_gateway_request(:refund_success)
      end

      it 'returns successful result' do
        result = service.refund(refund_params)

        expect(result).to be_success
      end

      it 'creates refund record linked to original transaction' do
        result = service.refund(refund_params)

        expect(result.refund_transaction.parent_transaction).to eq(original_transaction)
      end
    end
  end

  private

  def stub_gateway_request(type, error: nil)
    # Gateway-specific stubbing
    case type
    when :success
      # Stub successful response
    when :failure
      # Stub failure response with error
    when :timeout
      # Stub timeout
    when :refund_success
      # Stub successful refund
    end
  end
end
```

## Gateway-Specific Patterns

### Stripe
```ruby
before do
  StripeMock.start
end

after do
  StripeMock.stop
end
```

### CardConnect
```ruby
# Use VCR for recording real sandbox responses
VCR.use_cassette('card_connect/process_payment') do
  service.process_payment(params)
end
```

## Docker Environment

**All tests run in Docker web container:**

```bash
# Run gateway tests (preferred: bin/d)
bin/d rspec spec/services/payment_service/stripe_spec.rb

# Run all payment tests
bin/d rspec spec/services/payment_service/

# With VCR recording (env-var requires docker compose explicit -e)
docker compose exec -e VCR_RECORD=new_episodes web bundle exec rspec spec/services/payment_service/
```

## Checklist

- [ ] Idempotency tested
- [ ] Database transactions verified
- [ ] Sandbox credentials only
- [ ] Error handling covered
- [ ] Timeout handling covered
- [ ] Refund flow tested
- [ ] Webhook handling tested (if applicable)
- [ ] VCR cassettes recorded (for external calls)

## Example

```
User: /gateway-test stripe process_payment

Claude:
## Generating Stripe Payment Tests

### Analyzing existing implementation...
File: app/services/payment_service/stripe.rb

### Creating spec file...
spec/services/payment_service/stripe_spec.rb

### Test cases:
1. ✅ Successful payment processing
2. ✅ Idempotency verification
3. ✅ Database transaction rollback on failure
4. ✅ Insufficient funds handling
5. ✅ Card declined handling
6. ✅ Gateway timeout handling
7. ✅ Invalid card number handling

### Running tests...
7 examples, 0 failures

### Coverage report:
PaymentService::Stripe#process_payment: 95% covered

Tests generated successfully!
```

---

## MCP Integrations

### Stripe MCP

Use the Stripe MCP for direct API validation and sandbox testing:

```
# Verify Stripe webhook signatures
mcp__stripe__webhooks_list

# Check payment intents in sandbox
mcp__stripe__payment_intents_list:
  limit: 10

# Retrieve specific payment for debugging
mcp__stripe__payment_intents_retrieve:
  id: "pi_xxx"

# Validate customer setup
mcp__stripe__customers_list:
  email: "test@example.com"
```

**Use Cases:**
- Verify sandbox credentials are correct
- Debug failed payments by checking Stripe directly
- Validate webhook configuration
- Cross-reference local test data with Stripe sandbox

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new gateway integration pattern
- A missing test case for payment flows
- A better VCR/stubbing approach

**You MUST**:
1. Complete the current gateway test generation first
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements**:
<!-- Kaizen entries will be added here -->
