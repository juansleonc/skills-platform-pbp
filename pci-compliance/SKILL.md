---
name: pci-compliance
description: Validates PCI-DSS compliance for payment code across 14 gateways. Ensures card data protection, secure transmission, and proper credential handling.
allowed-tools: [Bash, Read, Grep, Glob, Edit, mcp__clickhouse__run_select_query, mcp__honeybadger__list_faults, mcp__stripe__*]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## Shared References

> **📚 This skill uses shared documentation. See:**
> - [Critical Rules](../shared/critical-rules.md) - payment idempotency
> - [ClickHouse Queries](../shared/clickhouse-queries.md) - data verification
> - [ast-grep Patterns](../shared/ast-grep-patterns.md) — AST-aware payment-call detection (`perform_async(payment.id)` idempotency surface)

# PCI Compliance Validation Skill

Validates PCI-DSS compliance for all payment-related code across the 14 supported payment gateways.

## Supported Gateways (14)

Source of truth: `ls app/services/payment_service/gateway/` (verified 2026-06-10). Never hand-maintain this list — regenerate from that directory.

| Gateway | Region | Primary Use |
|---------|--------|-------------|
| `card_connect` | US | Default gateway |
| `stripe` | Global | Primary for subscriptions |
| `pixel_pay` | Central America | Regional gateway |
| `azul_pay` | Dominican Republic | Regional gateway |
| `kushki_pay` | South America | Regional gateway |
| `xendit` | Indonesia / Philippines (default IDR) | Regional gateway |
| `icount` | Israel | Regional gateway |
| `dpo_pay` | Africa | Regional gateway |
| `mitec` (GetNet MEX) | Mexico | Regional gateway |
| `pay_fast` | South Africa | Regional gateway |
| `bac` | Central America | Regional gateway |
| `one_pay` | Vietnam | Regional gateway |
| `pay_code` | Asia | Regional gateway |
| `razor_pay` | India | Regional gateway |

> **Note**: `lukapay` is NOT in the gateway table above and NOT a gateway-pattern implementation. It lives at `app/services/payments/lukapay/` with its own service classes (`PaymentLinkGenerator`, `PaymentStatusChecker`, etc.). Do not add it to this list or the gateway loop — it has a separate audit path.

## PCI-DSS Requirements Mapping

### Requirement 3: Protect Stored Cardholder Data

**Validation Checks:**

```bash
# 1. No plaintext card numbers stored
grep -rn "card_number\|pan\|primary_account_number" app/ lib/ --include="*.rb" | grep -v "last_four\|last4\|masked"

# 2. No CVV/CVC stored anywhere
grep -rn "cvv\|cvc\|cv2\|security_code" app/ lib/ db/ --include="*.rb" --include="*.yml"

# 3. Card data should be tokenized
grep -rn "token\|payment_method_id" app/models/payment.rb
```

**ClickHouse Verification:**

```sql
-- Check no full card numbers in payments table
SELECT
  count(*) as total,
  countIf(length(card_number) > 4) as exposed_full_cards,
  countIf(card_number IS NOT NULL AND card_number NOT LIKE '%****%') as unmasked
FROM pbp_productionDB_optimized.payments
WHERE card_number IS NOT NULL;

-- Check for patterns that look like card numbers in any text field
SELECT count(*) as suspicious
FROM pbp_productionDB_optimized.payments
WHERE toString(notes) REGEXP '[0-9]{13,19}';
```

### Requirement 4: Encrypt Transmission

**Validation Checks:**

```bash
# 1. All payment API calls use HTTPS
grep -rn "http://" app/services/payment_service/ app/adapters/ --include="*.rb"

# 2. Gateway endpoints are HTTPS
grep -rn "api_url\|endpoint\|base_uri" app/adapters/ --include="*.rb" | grep -v "https"

# 3. No insecure SSL options
grep -rn "verify_ssl.*false\|ssl_verify.*false\|verify_peer.*false" app/ --include="*.rb"
```

### Requirement 6: Secure Development

**Validation Checks:**

```bash
# 1. Run Brakeman on payment code
docker compose exec web bundle exec brakeman --only-files app/services/payment_service/,app/adapters/,app/controllers/*payment*

# 2. Check for SQL injection in payment queries
grep -rn "where(\".*\#{" app/services/payment_service/ --include="*.rb"

# 3. Check for mass assignment issues
grep -rn "permit!" app/controllers/*payment* --include="*.rb"
```

### Requirement 7: Restrict Access

**Validation Checks:**

```bash
# 1. Payment controllers require authentication
grep -rn "before_action.*authenticate\|skip_before_action.*authenticate" app/controllers/*payment* --include="*.rb"

# 2. Authorization checks present
grep -rn "authorize!\|can\?\|cannot\?" app/controllers/*payment* --include="*.rb"

# 3. Admin-only routes protected
grep -rn "namespace :admin" config/routes.rb -A 20 | grep -i payment
```

### Requirement 10: Track and Monitor

**Validation Checks:**

```bash
# 1. Payment actions are logged
grep -rn "Rails.logger\|AuditLog\|create_audit" app/services/payment_service/ --include="*.rb"

# 2. Sensitive data not in logs
grep -rn "Rails.logger.*card\|Rails.logger.*cvv\|Rails.logger.*password" app/ --include="*.rb"
```

## Gateway-Specific Checks

### Check Gateway Implementations

```bash
# Find all gateway adapters
ls -la app/adapters/

# Check each gateway for PCI patterns
for gateway in azul_pay bac card_connect dpo_pay icount kushki_pay mitec one_pay pay_code pay_fast pixel_pay razor_pay stripe xendit; do
  echo "=== Checking $gateway ==="

  # Check for sensitive data logging
  grep -rn "logger\|puts\|print" app/adapters/${gateway}* app/services/payment_service/${gateway}* 2>/dev/null | grep -i "card\|cvv\|token"

  # Check for HTTP (not HTTPS)
  grep -rn "http://" app/adapters/${gateway}* app/services/payment_service/${gateway}* 2>/dev/null
done
```

### Credentials Storage Check

```bash
# Credentials should be in merchants table, encrypted
grep -rn "attr_encrypted\|encrypted_" app/models/merchant*.rb

# No hardcoded credentials
grep -rn "api_key\s*=\s*['\"]" app/adapters/ app/services/payment_service/ --include="*.rb"
grep -rn "secret_key\s*=\s*['\"]" app/adapters/ app/services/payment_service/ --include="*.rb"
```

## Audit Process

### Step 1: Run Automated Checks

```bash
# Full PCI compliance scan
echo "=== PCI Compliance Scan ==="

echo "1. Checking for exposed card data..."
grep -rn "card_number\|cvv\|cvc" app/ lib/ --include="*.rb" | grep -v "last_four\|last4\|masked\|#"

echo "2. Checking for insecure HTTP..."
grep -rn "http://" app/services/payment_service/ app/adapters/ --include="*.rb"

echo "3. Checking for sensitive data logging..."
grep -rn "Rails.logger\|Honeybadger.context" app/ --include="*.rb" | grep -i "card\|cvv\|password\|token"

echo "4. Running Brakeman on payment code..."
docker compose exec web bundle exec brakeman --only-files app/services/payment_service/,app/adapters/ -q
```

### Step 2: ClickHouse Data Verification

```sql
-- Check payment data patterns
SELECT
  gateway,
  count(*) as total_payments,
  countIf(card_number IS NOT NULL) as with_card_number,
  countIf(token IS NOT NULL) as with_token
FROM pbp_productionDB_optimized.payments
GROUP BY gateway
ORDER BY total_payments DESC;

-- Check for any unmasked card data
SELECT id, gateway, card_number
FROM pbp_productionDB_optimized.payments
WHERE card_number IS NOT NULL
  AND length(card_number) > 4
  AND card_number NOT LIKE '****%'
LIMIT 10;
```

### Step 3: Review Test Coverage

```bash
# Payment tests must use sandbox credentials
grep -rn "sandbox\|test_\|staging" spec/services/payment_service/ spec/adapters/ --include="*.rb"

# No production credentials in tests
grep -rn "live_\|production_" spec/ --include="*.rb" | grep -i "key\|secret\|token"
```

## Checklist

### Data Protection
- [ ] No plaintext card numbers stored
- [ ] CVV/CVC never stored
- [ ] Card data tokenized
- [ ] Tokens properly secured

### Transmission Security
- [ ] All API calls use HTTPS
- [ ] SSL verification enabled
- [ ] No insecure cipher suites

### Access Control
- [ ] Authentication required for payment endpoints
- [ ] Authorization checks present
- [ ] Admin routes properly protected

### Logging & Monitoring
- [ ] Payment actions logged
- [ ] No sensitive data in logs
- [ ] Audit trail complete

### Gateway-Specific
- [ ] Each gateway follows common patterns
- [ ] Credentials properly encrypted
- [ ] Idempotency keys used

## Report Format

```markdown
## PCI Compliance Audit

### Summary
- Gateways checked: 14
- Violations: X
- Warnings: Y

### Requirement Status

| Req | Description | Status |
|-----|-------------|--------|
| 3 | Protect Stored Data | ✅ PASS / ❌ FAIL |
| 4 | Encrypt Transmission | ✅ PASS / ❌ FAIL |
| 6 | Secure Development | ✅ PASS / ❌ FAIL |
| 7 | Restrict Access | ✅ PASS / ❌ FAIL |
| 10 | Track & Monitor | ✅ PASS / ❌ FAIL |

### Gateway Status

| Gateway | Data Protection | HTTPS | Auth | Status |
|---------|-----------------|-------|------|--------|
| stripe | ✅ | ✅ | ✅ | PASS |
| card_connect | ✅ | ✅ | ✅ | PASS |
| razor_pay | ⚠️ | ✅ | ✅ | WARN |

### Violations

#### CRITICAL: [Location]
Description of violation
Fix: [How to fix]

### Recommendations
1. Specific recommendation
2. Specific recommendation
```

## Example

```
User: /pci-compliance

Claude:
## PCI Compliance Audit

### Running automated checks...

1. Checking for exposed card data...
   ✅ No exposed card data found

2. Checking for insecure HTTP...
   ✅ All payment endpoints use HTTPS

3. Checking for sensitive data logging...
   ⚠️ Found 1 potential issue:
   app/services/payment_service/base.rb:45 - logs payment_method_id

4. Running Brakeman...
   ✅ No security warnings

### ClickHouse Verification...

Payment data patterns:
- stripe: 45,230 payments, all tokenized ✅
- card_connect: 12,450 payments, all tokenized ✅
- razor_pay: 3,200 payments, all tokenized ✅

### Summary
- Violations: 0
- Warnings: 1

### Recommendations
1. Review logging at payment_service/base.rb:45
   - payment_method_id is not sensitive, but verify no card data leaks

OVERALL: ✅ PCI COMPLIANT
```

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new PCI requirement pattern
- A missing gateway check
- A better validation approach

**You MUST**:
1. Complete the current PCI audit first
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements**:

<!-- Kaizen: 2026-06-10 -->
**Correction: gateway table had wrong entries; loop was misaligned**

**What was wrong:**
1. `luka_pay` listed as a gateway — it is NOT. It is a separate implementation at `app/services/payments/lukapay/` that does not follow the gateway pattern. Listing it causes audit loops to look for `app/services/payment_service/gateway/luka_pay/` which does not exist.
2. `xendit` was missing from the table despite having a full gateway implementation at `app/services/payment_service/gateway/xendit/` (default currency IDR, supports PHP/THB/VND/MYR/USD per xendit/base.rb).
3. `mitec` region was listed as "Brazil" — it is a Mexican processor (GetNet MEX). Endpoint domains are `mitec.com.mx`; error messages say "GetNet (MEX)".
4. The gateway loop included `luka_pay` (non-existent directory) and omitted `xendit`.

**What was corrected:**
- Gateway table now lists exactly the 14 directories found in `app/services/payment_service/gateway/`.
- Added note about `lukapay` being a separate non-gateway implementation at `app/services/payments/lukapay/`.
- `xendit` added with correct region (Indonesia/Philippines, default IDR per xendit/base.rb:41).
- `mitec` region corrected to Mexico.
- Gateway loop updated to match real directory names (alphabetical order).

**Lesson**: the gateway list must be generated from `ls app/services/payment_service/gateway/` — never hand-maintained. Any discrepancy between the table and that directory means either a new gateway was added without updating the skill, or an entry was fabricated.
