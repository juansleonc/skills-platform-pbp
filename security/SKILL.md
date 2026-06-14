---
name: security
description: Security audit using Brakeman, OWASP patterns, and project-specific checks. Validates credential handling, payment security, and common vulnerabilities.
allowed-tools: [Bash, Read, Grep, Glob, Edit, mcp__clickhouse__run_query, mcp__honeybadger__list_faults, mcp__honeybadger__get_fault]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## When to Use This Skill

> **Skill boundary**: `/security` = general OWASP/Brakeman/auth/controller/credential audits. `/pci-compliance` = card-data and payment-specific PCI-DSS requirements (use when touching payment gateways, card storage, or PCI Req 3/4/6). Both can run together; they don't duplicate — `/pci-compliance` is the deeper payment gate.

Run this skill when:
- **Before production deployment** of payment/auth changes (prevent vulnerabilities)
- **After modifying authentication** logic (Devise, JWT, passwordless flows)
- **Reviewing PRs** that touch controllers, payments, or credentials
- **Adding new payment gateway** (14 gateways, each needs security validation)
- **After security incidents** or Honeybadger alerts (investigate and prevent)

## Shared References

> **📚 This skill uses shared documentation. See:**
> - [Critical Rules](../shared/critical-rules.md) - security rules
> - [Forbidden Patterns](../shared/forbidden-patterns.md) - security patterns
> - [ClickHouse Queries](../shared/clickhouse-queries.md) - data verification
> - [ast-grep Patterns](../shared/ast-grep-patterns.md) — AST-aware security pattern detection (no comment/string false positives)

# Security Audit Skill

Comprehensive security audit using Brakeman, OWASP patterns, ClickHouse data verification, Honeybadger correlation, and project-specific security requirements.

## CRITICAL RULES

1. **Never log sensitive data** - Card numbers, CVVs, passwords, tokens
2. **Always encrypt credentials** - Use `attr_encrypted` for stored secrets
3. **Validate all input** - Sanitize user input, parameterize queries
4. **Use HTTPS only** - No HTTP for external API calls
5. **Payment sandbox in tests** - Never use production credentials in tests
6. **PCI Compliance** - Follow PCI-DSS for all payment handling
7. **Multi-tenancy** - Verify facility scoping prevents data leakage

## Quick Validation Commands

**Fast security violation detection** (run these first):

```bash
# 1. Find SQL injection vulnerabilities - CRITICAL
grep -rn "where(\".*\#{" app/ --include="*.rb"
grep -rn "execute(\".*\#{" app/ --include="*.rb"
```
**Expected**: 0 matches (all queries should be parameterized)

```bash
# 2. Find hardcoded credentials - CRITICAL
grep -rn "api_key\|secret_key\|password.*=" app/ --include="*.rb" | grep -v "ENV\|Rails.application.credentials\|attr_encrypted\|params\|\[:password\]"
```
**Expected**: 0 matches (all credentials should use ENV or Rails credentials)

```bash
# 3. Find sensitive data in logs - HIGH RISK (PCI violation)
grep -rn "logger\.\|Rails.logger\." app/ --include="*.rb" | grep -i "card\|cvv\|password\|token"
```
**Expected**: 0 matches (no sensitive data should be logged)

```bash
# 4. Find mass assignment vulnerabilities - HIGH RISK
grep -rn "permit!" app/controllers/ --include="*.rb"
```
**Expected**: 0 matches (use explicit permit with field list)

```bash
# 5. Find unescaped output - XSS RISK
grep -rn "raw\|html_safe" app/views/ --include="*.erb" | grep -v "sanitize"
```
**Expected**: 0-3 matches (review each, should have sanitize nearby)

```bash
# 6. Find open redirect vulnerabilities - MEDIUM RISK
grep -rn "redirect_to params\[" app/controllers/ --include="*.rb"
```
**Expected**: 0 matches (validate/whitelist redirect URLs)

## Additional Security Patterns

### Command Injection (CRITICAL)

```bash
# Find shell command execution with string interpolation - CRITICAL
grep -rn 'system(.*\#{\|exec(.*\#{' app/ --include="*.rb"
grep -rn '`[^`]*\#{' app/ --include="*.rb"
grep -rn "Open3\.\|IO\.popen\|Kernel\.system" app/ --include="*.rb" | grep '#{'
```
**Expected**: 0 matches (all system calls must use array form or sanitize input)

```ruby
# ❌ VULNERABLE - Command injection via interpolation
system("convert #{params[:filename]}")
`ls #{user_input}`

# ✅ SAFE - Array form prevents injection
system("convert", sanitized_filename)
Open3.capture3("convert", sanitized_filename)
```

### Path Traversal (CRITICAL)

```bash
# Find file operations using user input directly - CRITICAL
grep -rn "send_file.*params\|File\.read.*params\|File\.open.*params" app/ --include="*.rb"
grep -rn "Pathname\.new.*params\|File\.join.*params" app/ --include="*.rb"
```
**Expected**: 0 matches (validate/sanitize all file paths from user input)

```ruby
# ❌ VULNERABLE - Path traversal
send_file params[:path]                    # ../../etc/passwd
File.read("uploads/#{params[:filename]}")  # ../../../config/secrets.yml

# ✅ SAFE - Validate path
basename = File.basename(params[:filename])
send_file Rails.root.join("uploads", basename)
```

### IDOR - Insecure Direct Object Reference (HIGH)

```bash
# Find unscoped .find(params[:id]) in controllers - HIGH RISK
grep -rn "\.find(params\[" app/controllers/ --include="*.rb"
```
**Expected**: All matches should use scoped queries (e.g., `current_facility.payments.find(...)`)

```ruby
# ❌ VULNERABLE - IDOR (any user can access any record)
@payment = Payment.find(params[:id])
@reservation = Reservation.find(params[:id])

# ✅ SAFE - Scoped to facility/user
@payment = current_facility.payments.find(params[:id])
@reservation = current_user.reservations.find(params[:id])

# ✅ SAFE - Authorization check
@payment = Payment.find(params[:id])
authorize! :read, @payment
```

### Session Security (MEDIUM)

```bash
# Find cookie usage without secure flags
grep -rn "cookies\[" app/controllers/ --include="*.rb" | grep -v "secure\|httponly\|encrypted"
```
**Expected**: All cookies should use `secure: true, httponly: true` or use `cookies.encrypted`

### Weak Cryptography (HIGH)

```bash
# Find usage of weak hashing algorithms
grep -rn "Digest::MD5\|Digest::SHA1" app/ --include="*.rb" | grep -v "etag\|cache_key\|fingerprint"
```
**Expected**: 0 matches outside of cache/etag use (use SHA256+ for security purposes)

### Bare Rescue (MEDIUM)

```bash
# Find bare rescue that swallows all exceptions
grep -rn "rescue\s*$" app/ --include="*.rb"
grep -rn "rescue\s*=>" app/ --include="*.rb" | grep -v "StandardError\|specific"
grep -rn "rescue Exception" app/ --include="*.rb"
```
**Expected**: 0 matches (always rescue specific exception classes)

```ruby
# ❌ DANGEROUS - Swallows all errors including SystemExit, SignalException
rescue Exception => e
rescue => e  # Catches StandardError but hides intent

# ✅ SAFE - Explicit about what you catch
rescue ActiveRecord::RecordNotFound => e
rescue Stripe::CardError, Stripe::InvalidRequestError => e
rescue StandardError => e  # Acceptable when you need broad catch
```

## Audit Process

### Step 1: Run Brakeman

```bash
# Full scan
bin/d brakeman

# Scan specific files
bin/d brakeman --only-files app/controllers/payments_controller.rb

# Output to JSON for processing
bin/d brakeman -f json -o tmp/brakeman.json
```

### Step 2: Check for Common Vulnerabilities

> Run the grep patterns from the **Quick Validation Commands** block above (SQL injection, XSS, mass assignment, open redirect, credentials, sensitive-data logging). All expected results are documented there.

### Step 3: Check Sensitive Data Handling

> Covered by items 2 and 3 in the **Quick Validation Commands** block above (hardcoded credentials and sensitive data in logs).

### Step 4: Webhook Security Check

```bash
# Verify attr_encrypted usage
grep -rn "attr_encrypted" app/models/ --include="*.rb"
```
**Expected**: 3+ matches (webhooks_urls, payment credentials should use attr_encrypted)

```bash
# Check JSON serialization excludes encrypted fields
grep -rn "as_json\|to_json" app/models/ --include="*.rb" | grep -v "except:"
```
**Expected**: 0 matches (all JSON serialization should exclude encrypted fields with `except:`)

### Step 5: ClickHouse Data Exposure Detection (CRITICAL)

Verify no sensitive data is exposed in production:

> **📖 See [ClickHouse Queries](../shared/clickhouse-queries.md) for complete query patterns.**
>
> **Security-specific queries**:
> - Query #1: Check for Unencrypted Sensitive Data (webhooks)
> - Query #2: Check for Exposed Card Data (payments)
> - Query #3: Check for Sensitive Data in Logs (audit_logs)
> - Query #6: Verify Data Distribution Across Facilities (multi-tenancy)

**Use MCP tool**:
```
mcp__clickhouse__run_query:
  query: "SELECT id, name, CASE WHEN auth_token IS NOT NULL AND auth_token != '' THEN 'UNENCRYPTED!' ELSE 'OK' END as status FROM pbp_productionDB_optimized.webhooks_urls WHERE auth_token IS NOT NULL AND auth_token != '' LIMIT 10"
```

**Expected results**:
- Query #1: 0 rows (all tokens encrypted)
- Query #2: exposed_cards = 0 (only last 4 digits)
- Query #3: sensitive_logs = 0 (no sensitive data in logs)
- Query #6: All facilities have data, no orphans

### Step 6: Honeybadger Security Correlation

Check for security-related errors in production:

```
# Search for auth-related faults
mcp__honeybadger__list_faults:
  project_id: <project_id>
  q: "authentication OR authorization OR permission"

# Search for SQL-related errors
mcp__honeybadger__list_faults:
  project_id: <project_id>
  q: "SQL OR injection OR ActiveRecord"

# Check specific fault
mcp__honeybadger__get_fault:
  project_id: <project_id>
  fault_id: <fault_id>
```

**Security-related fault patterns to monitor:**
- `ActionController::InvalidAuthenticityToken`
- `CanCan::AccessDenied`
- `ActiveRecord::RecordNotFound` (could indicate IDOR attempt)
- `OpenSSL::` errors (encryption issues)
- `JWT::` errors (token validation issues)

## OWASP Top 10 Checks

### 1. Injection (SQL, Command)

```ruby
# ❌ VULNERABLE - SQL Injection
User.where("email = '#{params[:email]}'")
User.where("name LIKE '%#{search}%'")

# ✅ SAFE - Parameterized
User.where(email: params[:email])
User.where("name LIKE ?", "%#{search}%")
User.where("name LIKE :search", search: "%#{search}%")

# ❌ VULNERABLE - Command Injection
system("convert #{params[:filename]}")

# ✅ SAFE - Escaped/Validated
system("convert", validated_filename)
```

### 2. Broken Authentication

```ruby
# ❌ VULNERABLE - Timing attack on password
if user.password == params[:password]

# ✅ SAFE - Constant time comparison
if ActiveSupport::SecurityUtils.secure_compare(user.password, params[:password])

# ✅ SAFE - Use Devise/bcrypt
if user.valid_password?(params[:password])
```

### 3. Sensitive Data Exposure

```ruby
# ❌ VULNERABLE - Logging sensitive data
Rails.logger.info("Processing payment: #{card_number}")
Rails.logger.debug("User password: #{password}")

# ✅ SAFE - Masked logging
Rails.logger.info("Processing payment: ****#{card_number.last(4)}")
Rails.logger.info("Processing payment for user: #{user.id}")

# ❌ VULNERABLE - Exposing in JSON
def as_json(options = {})
  super  # Includes encrypted_auth_token!
end

# ✅ SAFE - Exclude sensitive fields
def as_json(options = {})
  super(options.merge(except: [:encrypted_auth_token, :encrypted_auth_token_iv]))
end
```

### 4. XML External Entities (XXE)

```ruby
# ❌ VULNERABLE
Nokogiri::XML(user_input)

# ✅ SAFE - Disable external entities
Nokogiri::XML(user_input) { |config| config.nonet.noent }
```

### 5. Broken Access Control

```ruby
# ❌ VULNERABLE - No authorization
def show
  @payment = Payment.find(params[:id])
end

# ✅ SAFE - Scoped to facility
def show
  @payment = current_facility.payments.find(params[:id])
end

# ✅ SAFE - CanCanCan authorization
def show
  @payment = Payment.find(params[:id])
  authorize! :read, @payment
end
```

### 6. Security Misconfiguration

```ruby
# ❌ VULNERABLE - Debug info in production
config.consider_all_requests_local = true  # in production.rb

# ✅ SAFE
config.consider_all_requests_local = false

# ❌ VULNERABLE - Missing CSRF
skip_before_action :verify_authenticity_token

# ✅ SAFE - CSRF protected with API token
protect_from_forgery with: :exception
skip_before_action :verify_authenticity_token, if: :valid_api_token?
```

### 7. Cross-Site Scripting (XSS)

```erb
<%# ❌ VULNERABLE - Unescaped output %>
<%= raw user.bio %>
<%= user.bio.html_safe %>

<%# ✅ SAFE - Escaped by default %>
<%= user.bio %>

<%# ✅ SAFE - Sanitized %>
<%= sanitize user.bio, tags: %w[b i u] %>
```

### 8. Insecure Deserialization

```ruby
# ❌ VULNERABLE - YAML.load with user input
data = YAML.load(params[:data])

# ✅ SAFE - Use safe_load
data = YAML.safe_load(params[:data], permitted_classes: [Symbol, Date])

# ❌ VULNERABLE - Marshal.load with user input
obj = Marshal.load(params[:serialized])

# ✅ SAFE - Use JSON
obj = JSON.parse(params[:data])
```

### Illustrative examples (NOT from this codebase — do not cite as evidence)

These examples demonstrate common vulnerability patterns. They are NOT sourced from real files or line numbers in this codebase — they are teaching examples only.

**EXAMPLE 1: Hardcoded API credentials**
```ruby
# ❌ BAD - Hardcoded production key
class PaymentService::SomeGateway
  API_KEY = 'sk_live_abc123xyz'
end

# ✅ GOOD - Use Rails credentials
class PaymentService::SomeGateway
  def api_key
    Rails.application.credentials.dig(:stripe, :api_key)
  end
end
```

**EXAMPLE 2: SQL injection in search**
```ruby
# ❌ BAD - String interpolation in WHERE clause
def search
  @facilities = Facility.where("name LIKE '%#{params[:query]}%'")
end

# ✅ GOOD - Parameterized query
def search
  @facilities = Facility.where("name LIKE ?", "%#{params[:query]}%")
end
```

**EXAMPLE 3: Sensitive data logged**
```ruby
# ❌ BAD - PCI-DSS violation: card data in logs
def process_payment(card_data)
  Rails.logger.info("Processing payment with card: #{card_data[:number]}")
end

# ✅ GOOD - Log only metadata
def process_payment(card_data)
  Rails.logger.info("Processing payment for user: #{current_user.id}")
end
```

**EXAMPLE 4: Missing facility scoping (IDOR)**
```ruby
# ❌ BAD - Unscoped find allows cross-facility access
def show
  @reservation = Reservation.find(params[:id])
end

# ✅ GOOD - Scoped to current facility
def show
  @reservation = current_facility.reservations.find(params[:id])
end
```

**EXAMPLE 5: Webhook credentials exposed in JSON**

Note: The real webhook model is at `packs/webhooks/app/models/url.rb` (not `app/models/webhooks/url.rb`).

```ruby
# ❌ BAD - as_json includes encrypted fields and their IVs
def as_json(options = {})
  super
end

# ✅ GOOD - Exclude encrypted fields
def as_json(options = {})
  super(options.merge(except: [:encrypted_auth_token, :encrypted_auth_token_iv]))
end
```

**EXAMPLE 6: XSS in user-generated content**
```erb
<%# ❌ BAD - Unescaped raw output %>
<div class="notes">
  <%= raw @record.notes %>
</div>

<%# ✅ GOOD - Sanitize HTML %>
<div class="notes">
  <%= sanitize @record.notes, tags: %w[b i u p br] %>
</div>
```

## PCI Compliance Quick Reference

> **📖 See `/pci-compliance` skill for comprehensive PCI validation.**

### PCI-DSS Requirements Summary

| Requirement | What to Check |
|-------------|---------------|
| Req 3: Protect stored data | No plaintext card data stored |
| Req 4: Encrypt transmission | HTTPS only for all payment APIs |
| Req 6: Secure development | Brakeman clean, no injection |
| Req 7: Restrict access | CanCanCan authorization present |
| Req 8: Unique IDs | User authentication required |
| Req 10: Track access | Audit logging enabled |

### Quick PCI Check

```bash
# 1. No card data in logs
grep -rn "card_number\|cvv\|cvc" app/ --include="*.rb" | grep -i "log\|puts\|print"
```
**Expected**: 0 matches (PCI violation - never log card data)

```bash
# 2. No card data in error contexts
grep -rn "Honeybadger.context\|ErrorService" app/ --include="*.rb" | grep -i "card"
```
**Expected**: 0 matches (PCI violation - never send card data to error tracking)

```bash
# 3. All payment endpoints use HTTPS
grep -rn "http://" app/ --include="*.rb" | grep -i "payment\|stripe\|gateway"
```
**Expected**: 0 matches (all payment APIs must use HTTPS)

```bash
# 4. Payment actions require authentication
grep -rn "before_action.*authenticate" app/controllers/ --include="*payment*.rb"
```
**Expected**: 1+ matches per payment controller (all payment actions must authenticate)

## Payment-Specific Security

### Never Log Card Data

```ruby
# ❌ FORBIDDEN
Rails.logger.info("Card: #{card_number}, CVV: #{cvv}")
Honeybadger.context(card_number: card_number)

# ✅ SAFE
Rails.logger.info("Payment attempt for user: #{user.id}")
Honeybadger.context(user_id: user.id, amount: amount)
```

### Sandbox Credentials in Tests

```ruby
# ❌ FORBIDDEN in tests
let(:gateway_config) do
  {
    api_key: ENV['PRODUCTION_API_KEY'],  # NEVER!
  }
end

# ✅ SAFE
let(:gateway_config) do
  {
    api_key: 'sandbox_test_key',
    environment: 'sandbox'
  }
end
```

### Token Handling

```ruby
# ❌ VULNERABLE - Token in URL
redirect_to "https://api.example.com?token=#{token}"

# ✅ SAFE - Token in header
response = HTTParty.get(
  "https://api.example.com",
  headers: { 'Authorization' => "Bearer #{token}" }
)
```

## Webhook Credential Security

```ruby
# Model with encrypted credentials
class Webhooks::Url < ApplicationRecord
  attr_encrypted :auth_token,
    key: Rails.application.credentials.dig(:webhooks, :encryption_key),
    algorithm: 'aes-256-gcm'

  # CRITICAL: Exclude encrypted fields from JSON
  def as_json(options = {})
    options[:except] ||= []
    options[:except] += [:encrypted_auth_token, :encrypted_auth_token_iv]
    super(options)
  end

  # Only include decrypted when explicitly requested
  def to_json_with_credentials
    as_json.merge(auth_token: auth_token)
  end
end
```

## Checklist

For each changed file:

- [ ] No SQL injection vulnerabilities
- [ ] No XSS vulnerabilities (raw/html_safe properly used)
- [ ] No command injection
- [ ] No hardcoded credentials
- [ ] No sensitive data logging
- [ ] CSRF protection in place
- [ ] Authorization checks present
- [ ] Payment data properly handled
- [ ] Webhook credentials encrypted
- [ ] API tokens in headers, not URLs

## Report Format

```markdown
## Security Audit

### Brakeman Results
- High: 0
- Medium: 1
- Low: 2

### OWASP Checks
| Category | Status | Notes |
|----------|--------|-------|
| SQL Injection | ✅ OK | All queries parameterized |
| XSS | ⚠️ WARN | 1 raw usage needs review |
| Auth | ✅ OK | Devise/CanCanCan properly used |
| Access Control | ✅ OK | Multi-tenant scoping present |

### Sensitive Data
- [ ] No card numbers in logs ✅
- [ ] No passwords in logs ✅
- [ ] Webhook credentials encrypted ✅

### Findings

#### Medium: Potential XSS in user bio
Location: app/views/profiles/show.html.erb:45
```erb
<%= raw @user.bio %>
```
Recommendation: Use `sanitize` helper

### Recommendations
1. Replace `raw` with `sanitize` in profile view
2. Add CSP headers for additional XSS protection
```

## Example

```
User: /security

Claude:
## Security Audit

### Running Brakeman...
bin/d brakeman --only-files <changed_files>

Results:
- High: 0
- Medium: 0
- Low: 0

### Checking OWASP patterns...

✅ SQL Injection: No interpolated queries found
✅ XSS: All output properly escaped
✅ CSRF: Protection enabled
✅ Access Control: Facility scoping present

### Checking sensitive data handling...

✅ No card numbers in logs
✅ No hardcoded credentials
✅ Webhook credentials properly encrypted

### Payment security...

✅ Sandbox credentials in tests
✅ No CVV/card logging
✅ Tokens in headers, not URLs

### Result: ALL CHECKS PASSED

No security vulnerabilities found.
```

---

## Related Skills

This skill works with:
- **`/pci-compliance`** - Comprehensive PCI-DSS validation for payment code (14 gateways)
- **`/multi-tenancy`** - Validates facility scoping prevents data leakage (run together with security)
- **`/graphql`** - API security and authorization patterns (JWT, CanCanCan)
- **`/code-review`** - Comprehensive review includes security checks (Brakeman, OWASP)
- **`/gateway-consistency`** - Payment gateway security patterns across 14 implementations

**Workflow**: `/orchestrate feature` automatically includes security validation in Phase 2 (Validation)

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new security vulnerability pattern
- A missing OWASP check
- A better Brakeman configuration

**You MUST**:
1. Complete the current security audit first
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements** (full log: [kaizen_log.md](kaizen_log.md)):

<!-- Kaizen: 2026-06-10 — Fabrication purge / honest baselines (Fable audit Tier 2') -->
- Deleted/relabeled 6 fabricated "Real PBP Violations": `admin/facilities_controller.rb` (does not exist — only `organizations_controller.rb` and `sso_approvals_controller.rb` are in `app/controllers/admin/`), `reservations_controller.rb:89` (file is 73 lines — line 89 does not exist), `payment_service/base.rb:234` (file is 44 lines), `app/models/webhooks/url.rb` (real path is `packs/webhooks/app/models/url.rb`), `app/views/memberships/show.html.erb` (does not exist). Section relabeled "Illustrative examples (NOT from this codebase — do not cite as evidence)" and fake file:line citations stripped.
- The webhooks/url.rb example was kept but corrected to reflect the real pack path.
- Lesson: file:line citations must verify against HEAD or be labeled illustrative; boasting about "real files, real line numbers" in Kaizen is only valid when the citations have been verified.

<!-- Kaizen: 2026-06-10 — ClickHouse MCP tool name: run_select_query → run_query (residue cleanup, Fable audit Tier 2') -->
