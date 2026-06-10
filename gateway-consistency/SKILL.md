---
name: gateway-consistency
description: Detects divergence between payment gateway implementations. Ensures consistent patterns, error handling, and interfaces across all 14 gateways.
allowed-tools: [Bash, Read, Grep, Glob, Edit, mcp__clickhouse__run_select_query]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## Shared References

> **📚 This skill uses shared documentation. See:**
> - [Payments Domain](../../docs/domains/payments.md) - gateway patterns
> - [Critical Rules](../shared/critical-rules.md) - payment idempotency
> - [ast-grep Patterns](../shared/ast-grep-patterns.md) — AST-aware cross-gateway pattern divergence detection

# Gateway Consistency Validation Skill

Detects divergence between payment gateway implementations to ensure consistent behavior, error handling, and interfaces across all 14 supported gateways.

## Gateway Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    PaymentService::Base                          │
│              (Common interface, gateway routing)                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │   Stripe    │  │ CardConnect │  │  RazorPay   │  ... (14)    │
│  │   Adapter   │  │   Adapter   │  │   Adapter   │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
│                                                                  │
│  Required Methods:                                               │
│  - authorize       - void           - refund                     │
│  - capture         - tokenize       - create_customer            │
│  - charge          - verify         - webhooks                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Required Gateway Interface

Every gateway MUST implement these service objects:

| Service | Purpose | Required? |
|---------|---------|-----------|
| `Authorize` | Pre-authorize payment | ✅ |
| `Capture` | Capture authorized payment | ✅ |
| `Charge` / `ProcessTokenPayment` | Direct charge | ✅ |
| `Void` | Cancel authorization | ✅ |
| `Refund` | Refund payment | ✅ |
| `Tokenize` | Store payment method | ⚡ Gateway-dependent |
| `CreateCustomerUser` | Create customer profile | ⚡ Gateway-dependent |
| `Order` | Create payment intent/order | ⚡ Gateway-dependent |
| `Verify` | Verify payment method | ⚡ Optional |

## Consistency Checks

### 1. Interface Completeness

```bash
# Check which services each gateway implements
for gateway in stripe card_connect pixel_pay azul_pay kushki_pay luka_pay icount dpo_pay mitec pay_fast bac one_pay pay_code razor_pay; do
  echo "=== $gateway ==="
  ls -la app/services/payment_service/${gateway}/ 2>/dev/null || echo "No service directory"
  ls -la app/adapters/${gateway}/ 2>/dev/null || echo "No adapter directory"
done
```

### 2. Response Format Consistency

All gateways MUST return consistent response objects:

```ruby
# Expected response structure
{
  success: true/false,
  transaction_id: "gateway_txn_id",
  authorization_code: "auth_code",
  error_message: nil,  # or error description
  error_code: nil,     # or gateway error code
  raw_response: {}     # gateway's original response
}
```

**Validation:**

```bash
# Check response handling patterns
for gateway in stripe card_connect razor_pay; do
  echo "=== $gateway response patterns ==="
  grep -rn "success:\|transaction_id:\|error_message:" app/services/payment_service/${gateway}/ --include="*.rb"
done
```

### 3. Error Handling Consistency

```bash
# Check error handling patterns
for gateway in stripe card_connect razor_pay; do
  echo "=== $gateway error handling ==="
  grep -rn "rescue\|StandardError\|gateway_error" app/services/payment_service/${gateway}/ app/adapters/${gateway}/ --include="*.rb"
done

# Check for i18n usage (not hardcoded messages)
grep -rn "I18n.t\|t('" app/services/payment_service/ --include="*.rb" | head -20
grep -rn "Error\|error\|failed" app/services/payment_service/ --include="*.rb" | grep -v "I18n\|t('" | head -20
```

### 4. Idempotency Key Handling

```bash
# Check idempotency key usage
for gateway in stripe card_connect razor_pay; do
  echo "=== $gateway idempotency ==="
  grep -rn "idempotency_key\|idempotent" app/services/payment_service/${gateway}/ app/adapters/${gateway}/ --include="*.rb"
done
```

### 5. Webhook Handler Consistency

```bash
# Check webhook handling
ls -la app/controllers/webhooks/
grep -rn "def process\|def handle\|def verify" app/controllers/webhooks/ --include="*.rb"
```

## ClickHouse Gateway Analysis

```sql
-- Compare gateway success rates
SELECT
  gateway,
  count(*) as total,
  countIf(status = 'succeeded') as succeeded,
  countIf(status = 'failed') as failed,
  round(countIf(status = 'succeeded') / count(*) * 100, 2) as success_rate
FROM pbp_productionDB_optimized.payments
WHERE created_at > now() - INTERVAL 30 DAY
GROUP BY gateway
ORDER BY total DESC;

-- Check error distribution by gateway
SELECT
  gateway,
  error_code,
  count(*) as occurrences
FROM pbp_productionDB_optimized.payments
WHERE status = 'failed'
  AND created_at > now() - INTERVAL 30 DAY
GROUP BY gateway, error_code
ORDER BY gateway, occurrences DESC;

-- Check average processing time by gateway
SELECT
  gateway,
  avg(processing_time_ms) as avg_time,
  max(processing_time_ms) as max_time,
  min(processing_time_ms) as min_time
FROM pbp_productionDB_optimized.payments
WHERE created_at > now() - INTERVAL 7 DAY
GROUP BY gateway
ORDER BY avg_time DESC;
```

## Audit Process

### Step 1: Map Gateway Implementations

```bash
# Generate implementation matrix
echo "| Gateway | Authorize | Capture | Charge | Void | Refund | Tokenize |"
echo "|---------|-----------|---------|--------|------|--------|----------|"

for gateway in stripe card_connect pixel_pay azul_pay kushki_pay luka_pay icount dpo_pay mitec pay_fast bac one_pay pay_code razor_pay; do
  auth=$(ls app/services/payment_service/${gateway}/authorize* 2>/dev/null && echo "✅" || echo "❌")
  capture=$(ls app/services/payment_service/${gateway}/capture* 2>/dev/null && echo "✅" || echo "❌")
  charge=$(ls app/services/payment_service/${gateway}/*payment* 2>/dev/null && echo "✅" || echo "❌")
  void=$(ls app/services/payment_service/${gateway}/void* 2>/dev/null && echo "✅" || echo "❌")
  refund=$(ls app/services/payment_service/${gateway}/refund* 2>/dev/null && echo "✅" || echo "❌")
  tokenize=$(ls app/services/payment_service/${gateway}/tokenize* 2>/dev/null && echo "✅" || echo "❌")
  echo "| $gateway | $auth | $capture | $charge | $void | $refund | $tokenize |"
done
```

### Step 2: Check Pattern Consistency

```bash
# Interactor pattern usage
echo "Checking Interactor pattern usage..."
for gateway in stripe card_connect razor_pay; do
  echo "=== $gateway ==="
  grep -rn "include Interactor\|class.*< ApplicationService" app/services/payment_service/${gateway}/ --include="*.rb" | head -5
done
```

### Step 3: Verify Error Handling

```bash
# Check for consistent error handling
echo "Checking error handling consistency..."
grep -rn "def call\|def process\|def execute" app/services/payment_service/*/authorize*.rb | while read line; do
  file=$(echo "$line" | cut -d: -f1)
  # Check if file has proper error handling
  if ! grep -q "rescue" "$file"; then
    echo "WARNING: $file may be missing error handling"
  fi
done
```

### Step 4: Compare with Production Data

Run ClickHouse queries (see above) to identify:
- Gateways with abnormally high failure rates
- Inconsistent error codes
- Performance outliers

## Checklist

### Interface Consistency
- [ ] All required services implemented
- [ ] Response format matches expected structure
- [ ] Error messages use i18n

### Pattern Consistency
- [ ] Uses Interactor or ApplicationService
- [ ] Follows project naming conventions
- [ ] Has proper error handling

### Idempotency
- [ ] Supports idempotency keys
- [ ] Handles duplicate requests gracefully

### Production Behavior
- [ ] Success rate within expected range (>95%)
- [ ] Processing time within expected range
- [ ] Error codes are documented

## Report Format

```markdown
## Gateway Consistency Audit

### Implementation Matrix

| Gateway | Auth | Capture | Charge | Void | Refund | Token | Score |
|---------|------|---------|--------|------|--------|-------|-------|
| stripe | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 100% |
| card_connect | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 100% |
| razor_pay | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | 83% |

### Pattern Divergence

| Issue | Gateways Affected | Impact |
|-------|-------------------|--------|
| Missing void service | razor_pay | Manual cancellation required |
| Hardcoded error messages | pixel_pay | No i18n support |
| Missing idempotency | luka_pay | Duplicate charge risk |

### Production Performance

| Gateway | Success Rate | Avg Time | Status |
|---------|--------------|----------|--------|
| stripe | 98.5% | 850ms | ✅ |
| card_connect | 97.2% | 1200ms | ✅ |
| razor_pay | 94.1% | 2100ms | ⚠️ |

### Recommendations
1. Implement void service for razor_pay
2. Add i18n to pixel_pay error messages
3. Add idempotency key support to luka_pay
```

## Example

```
User: /gateway-consistency

Claude:
## Gateway Consistency Audit

### Scanning 14 gateway implementations...

### Implementation Matrix

| Gateway | Auth | Capture | Charge | Void | Refund | Score |
|---------|------|---------|--------|------|--------|-------|
| stripe | ✅ | ✅ | ✅ | ✅ | ✅ | 100% |
| card_connect | ✅ | ✅ | ✅ | ✅ | ✅ | 100% |
| razor_pay | ✅ | ✅ | ✅ | ✅ | ✅ | 100% |
| pixel_pay | ✅ | ❌ | ✅ | ❌ | ✅ | 60% |

### Pattern Analysis

✅ All gateways use Interactor pattern
✅ Response format consistent
⚠️ 2 gateways have hardcoded error messages

### Production Data (Last 30 days)

| Gateway | Transactions | Success Rate |
|---------|-------------|--------------|
| stripe | 45,230 | 98.5% |
| card_connect | 12,450 | 97.2% |
| razor_pay | 3,200 | 95.1% |

### Divergences Found: 2

1. **pixel_pay** - Missing capture service
   - Impact: Cannot do auth+capture flow
   - Fix: Implement capture service

2. **pixel_pay, luka_pay** - Hardcoded error messages
   - Impact: No i18n support
   - Fix: Use I18n.t('payments.errors...')

### OVERALL: ⚠️ MINOR DIVERGENCES
```

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new gateway added to the project
- A new consistency pattern to check
- A production issue related to gateway divergence

**You MUST**:
1. Complete the current audit first
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements**:
<!-- Kaizen entries will be added here -->
