# Resilience Audit — Report Template

```markdown
## Resilience Audit

### Summary
- External calls found: X
- Missing timeouts: Y
- Missing error handling: Z
- Silent failures: W

### Critical Issues (Must Fix)

| File | Line | Issue | Risk |
|------|------|-------|------|
| patch/contacts.rb | 45 | No timeout on API call | Cascading timeout |
| stripe_gateway.rb | 112 | Silent rescue nil | Lost payment data |

### Warning Issues (Should Fix)

| File | Line | Issue | Risk |
|------|------|-------|------|
| webhook_sender.rb | 67 | Bare rescue | Masks real errors |
| sms_service.rb | 34 | .save without check | Silent failures |

### Recommendations
1. Add 10s timeout to all HTTParty calls in app/adapters/
2. Replace rescue nil with proper error logging
3. Add idempotency keys to payment retry logic
```
