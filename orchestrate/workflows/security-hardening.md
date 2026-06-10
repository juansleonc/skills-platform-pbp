# Security Hardening Workflow

> 🔒 **Comprehensive security audit and hardening using Brakeman + PCI + Multi-tenancy**

## Command

```bash
/orchestrate security-hardening
```

## Overview

Full security hardening workflow:
- Parallel security analysis (Brakeman + PCI + Multi-tenancy)
- ClickHouse production data verification
- TDD-based security fixes
- Final verification

**Time**: 25-35min average
**Risk**: LOW (read-only analysis, then tested fixes)
**Critical**: ALWAYS verify no sensitive data exposure in production

## Workflow Diagram

```
┌─ PARALLEL (Security Analysis) ────────────────────┐
│  Run 3 security analyzers concurrently:           │
│                                                    │
│  ├── security: Brakeman + OWASP audit             │
│  │    → OWASP Top 10 vulnerabilities              │
│  │    → SQL injection, XSS, CSRF                  │
│  │    → Mass assignment, command injection        │
│  │    → Sensitive data exposure                   │
│  │    → Insecure deserialization                  │
│  │                                                 │
│  ├── pci-compliance: Payment security             │
│  │    → Card data protection                      │
│  │    → Secure transmission (SSL/TLS)             │
│  │    → Credential encryption                     │
│  │    → PCI-DSS requirements                      │
│  │                                                 │
│  └── multi-tenancy: Data isolation check          │
│       → All queries facility-scoped                │
│       → No cross-facility data leaks               │
│       → Authorization boundaries                   │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (ClickHouse Verification) ────────────┐
│  Verify no sensitive data exposure in production  │
│    → Check for card numbers in logs               │
│    → Verify PII encryption                        │
│    → Check API token exposure                     │
│    → Validate data retention policies             │
└───────────────────────────────────────────────────┘
                        ↓
┌─ SEQUENTIAL (Fix Issues) ─────────────────────────┐
│  tdd: Write security tests → fix → verify         │
│    → RED: Write test exposing vulnerability       │
│    → GREEN: Fix vulnerability                     │
│    → REFACTOR: Ensure fix is robust               │
│    → VERIFY: Run security scan again              │
└───────────────────────────────────────────────────┘
                        ↓
┌─ PARALLEL (Verification) ─────────────────────────┐
│  Verify all issues resolved:                      │
│                                                    │
│  ├── security: Re-run Brakeman                    │
│  │    → Expected: 0 new vulnerabilities           │
│  │    → Verify fixes effective                    │
│  │                                                 │
│  ├── coverage: Verify security tests              │
│  │    → 100% coverage on security-critical code   │
│  │    → Edge cases tested                         │
│  │                                                 │
│  └── code-review: Final security review           │
│       → Manual review of fixes                    │
│       → Verify no new attack vectors              │
└───────────────────────────────────────────────────┘
```

## Phase Details

### Phase 1: Security Analysis (Parallel - 3 analyzers)

#### 1.1 Brakeman + OWASP Audit

**Skill**: `/security`

**What It Checks**:
- SQL Injection
- Cross-Site Scripting (XSS)
- CSRF token validation
- Mass assignment vulnerabilities
- Command injection
- Unsafe redirects
- File access vulnerabilities
- Session fixation
- Insecure deserialization

**Time**: 3-5min

---

#### 1.2 PCI Compliance

**Skill**: `/pci-compliance`

**What It Checks**:
- Card data protection (never store CVV)
- Secure transmission (SSL/TLS required)
- Credential encryption (AES-256)
- PCI-DSS requirements compliance
- Gateway integration security

**Time**: 2-3min

---

#### 1.3 Multi-Tenancy

**Skill**: `/multi-tenancy`

**What It Checks**:
- All queries facility-scoped
- No cross-facility data leaks
- Authorization boundaries enforced

**Time**: 2-3min

---

### Phase 2: ClickHouse Verification

**Goal**: Verify no sensitive data in production logs/data

**Queries**:
```sql
-- Check for card numbers in logs (should be 0)
SELECT COUNT(*) FROM api_logs
WHERE request_body LIKE '%4[0-9]{15}%'  -- Visa pattern
   OR request_body LIKE '%5[0-9]{15}%'; -- Mastercard

-- Check for SSN patterns (should be 0)
SELECT COUNT(*) FROM user_data
WHERE notes LIKE '%[0-9]{3}-[0-9]{2}-[0-9]{4}%';

-- Verify encryption on sensitive fields
SELECT
  COUNT(*) as total,
  COUNT(CASE WHEN encrypted_credentials IS NULL THEN 1 END) as unencrypted
FROM merchant_credentials;
```

**Time**: 3-5min

---

### Phase 3: Fix Issues

**TDD Pattern**: Write test → Fix → Verify

**Example**:
```ruby
# Test exposing SQL injection vulnerability
describe 'SQL injection protection' do
  it 'sanitizes user input in search' do
    # Attempt SQL injection
    malicious_input = "'; DROP TABLE users; --"

    expect {
      User.search(malicious_input)
    }.not_to change(User, :count)

    expect(User.search(malicious_input)).to be_empty
  end
end

# Fix
def search(query)
  # ❌ BEFORE (vulnerable)
  where("name LIKE '%#{query}%'")

  # ✅ AFTER (safe)
  where("name LIKE ?", "%#{query}%")
end
```

**Time**: 10-15min (per vulnerability)

---

### Phase 4: Verification

Re-run all security checks to verify fixes:
- Brakeman: 0 new vulnerabilities
- Coverage: 100% on security code
- Code review: Manual verification

**Time**: 5-8min

---

## Success Criteria

**ALL checks must pass**:
- ✅ No critical vulnerabilities (Brakeman)
- ✅ PCI compliance verified
- ✅ Multi-tenancy enforced
- ✅ No sensitive data in production logs
- ✅ 100% coverage on security-critical code

## Time Estimates

| Phase | Duration | Notes |
|-------|----------|-------|
| Security Analysis (parallel) | 8-12min | 3 analyzers |
| ClickHouse Verification | 3-5min | Production data check |
| Fix Issues | 10-20min | Variable (depends on issues) |
| Verification (parallel) | 5-8min | Re-run checks |
| **Total** | **25-45min** | Avg 35min |

## Common Security Issues

### 1. SQL Injection

**Pattern**:
```ruby
# ❌ VULNERABLE
User.where("email = '#{params[:email]}'")

# ✅ SAFE
User.where("email = ?", params[:email])
# OR
User.where(email: params[:email])
```

---

### 2. Mass Assignment

**Pattern**:
```ruby
# ❌ VULNERABLE
User.update(params[:user])

# ✅ SAFE
User.update(user_params)

private
def user_params
  params.require(:user).permit(:name, :email)
end
```

---

### 3. XSS (Cross-Site Scripting)

**Pattern**:
```erb
<%# ❌ VULNERABLE %>
<%= raw user.bio %>

<%# ✅ SAFE %>
<%= user.bio %>  # Auto-escaped by Rails
```

---

### 4. Card Data Exposure

**Pattern**:
```ruby
# ❌ NEVER store CVV
Payment.create(cvv: params[:cvv])

# ✅ SAFE - Only store last 4 digits
Payment.create(last_four: params[:card_number][-4..-1])
```

---

## Best Practices

**DO** ✅:
- Run security scan before every release
- Fix critical vulnerabilities immediately
- Encrypt all sensitive data (AES-256)
- Use parameterized queries (prevent SQL injection)
- Validate ALL user input
- Test security fixes thoroughly

**DON'T** ❌:
- Ignore security warnings (even "low" severity)
- Store card CVV codes (PCI violation)
- Log sensitive data (card numbers, SSN, passwords)
- Trust user input (always validate)
- Skip ClickHouse verification (production data matters)

## Related Workflows

- **After hardening**: `/orchestrate pre-commit` (final validation)
- **For code review**: `/orchestrate code-review` (comprehensive check)
- **For payments**: `/pci-compliance` skill (deep payment audit)

---

**Back to**: [orchestrate skill](../SKILL.md) | [quick reference](../quick_reference.md) | [workflows index](README.md)
