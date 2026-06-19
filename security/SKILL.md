---
name: security
description: Security audit using Brakeman, OWASP patterns, and project-specific checks. Validates credential handling, payment security, and common vulnerabilities.
allowed-tools: [Bash, Read, Grep, Glob, Edit, mcp__clickhouse__run_query, mcp__honeybadger__list_faults, mcp__honeybadger__get_fault]
disable-model-invocation: false
---

<!-- `allowed-tools` / `disable-model-invocation` are Claude-Code harness extensions; a portable
     SKILL spec needs only `name` + `description`. They are valid in this harness — keep them. -->

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both for current project conventions.

# Security Audit Skill

Comprehensive security audit using Brakeman, OWASP patterns, ClickHouse data verification, Honeybadger correlation, and project-specific requirements.

## When to Use This Skill

> **Skill boundary**: `/security` = general OWASP/Brakeman/auth/controller/credential audits. `/pci-compliance` = card-data and payment-specific PCI-DSS (gateways, card storage, Req 3/4/6/7/10). Both can run together; they don't duplicate — `/pci-compliance` is the deeper payment gate.

Run this skill: **before prod deploy** of payment/auth changes · **after modifying auth** (Devise, JWT, passwordless) · **PR review** of controllers/payments/credentials · **adding a payment gateway** (14, each needs validation) · **after security incidents / Honeybadger alerts**.

## Shared References

- [Critical Rules](../shared/critical-rules.md) — security rules (the CRITICAL RULES below are the security-specific delta; do not re-list what's already there)
- [Forbidden Patterns](../shared/forbidden-patterns.md) — security anti-patterns
- [ClickHouse Queries](../shared/clickhouse-queries.md) — prod data verification (Step 5)
- [ast-grep Patterns](../shared/ast-grep-patterns.md) — AST-aware detection (no comment/string false positives)
- [OWASP examples](reference/owasp-examples.md) — vulnerable→safe code pairs for all checks below + the canonical webhook `as_json` case
- [Report template & example transcript](reference/report-and-example.md) — output format

## CRITICAL RULES (security delta — see shared/critical-rules.md for the rest)

1. Never log sensitive data (card numbers, CVVs, passwords, tokens)
2. Encrypt stored credentials with `attr_encrypted`
3. Parameterize queries; sanitize all input
4. HTTPS only for external API calls
5. Sandbox credentials in tests — never production
6. PCI-DSS for all payment handling (→ `/pci-compliance`)
7. Verify facility scoping prevents cross-tenant leakage

## Detection Commands

Run first. Prefer `sg` (ast-grep) over `grep` when available — it ignores matches inside strings/comments, removing the `grep -v` heuristics (see ast-grep-patterns.md). Vulnerable→safe code for every row is in [owasp-examples.md](reference/owasp-examples.md).

| Vuln class | Detection one-liner | Expected |
|---|---|---|
| SQL injection (CRIT) | `grep -rn 'where(".*\#{\|execute(".*\#{' app/ --include='*.rb'` | 0 |
| Hardcoded creds (CRIT) | `grep -rn 'api_key\|secret_key\|password.*=' app/ --include='*.rb' \| grep -v 'ENV\|Rails.application.credentials\|attr_encrypted\|params\|\[:password\]'` | 0 |
| Sensitive data in logs (HIGH/PCI) | `grep -rn 'logger\.\|Rails.logger\.' app/ --include='*.rb' \| grep -i 'card\|cvv\|password\|token'` | 0 |
| Mass assignment (HIGH) | `grep -rn 'permit!' app/controllers/ --include='*.rb'` | 0 |
| Unescaped output / XSS | `grep -rn 'raw\|html_safe' app/views/ --include='*.erb' \| grep -v 'sanitize'` | 0–3 (review each) |
| Open redirect (MED) | `grep -rn 'redirect_to params\[' app/controllers/ --include='*.rb'` | 0 |
| Command injection (CRIT) | `grep -rn 'system(.*\#{\|exec(.*\#{\|Open3\.\|IO\.popen' app/ --include='*.rb' \| grep '#{'` | 0 (use array form) |
| Path traversal (CRIT) | `grep -rn 'send_file.*params\|File\.\(read\|open\).*params\|File\.join.*params' app/ --include='*.rb'` | 0 (sanitize paths) |
| IDOR (HIGH) | `grep -rn '\.find(params\[' app/controllers/ --include='*.rb'` | All scoped (`current_facility.x.find`) or `authorize!` |
| Cookies w/o flags (MED) | `grep -rn 'cookies\[' app/controllers/ --include='*.rb' \| grep -v 'secure\|httponly\|encrypted'` | use `secure/httponly` or `cookies.encrypted` |
| Weak crypto (HIGH) | `grep -rn 'Digest::MD5\|Digest::SHA1' app/ --include='*.rb' \| grep -v 'etag\|cache_key\|fingerprint'` | 0 (SHA256+ for security) |
| Bare rescue (MED) | `grep -rn 'rescue\s*$\|rescue Exception' app/ --include='*.rb'` | 0 (rescue specific classes) |

## Audit Process

- [ ] **Brakeman** — `bin/d brakeman` (full scan), then filter the report to changed files.
      ⚠️ `--only-files <file>` is **not recommended for a primary workflow**: Brakeman analyzes
      whole-app data flow, so a per-file scan can be incomplete / non-functional. Prefer a full scan
      and filter, or `bin/d brakeman --compare baseline.json` against a committed `-f json -o` baseline.
- [ ] **Common vulnerabilities** — run the Detection Commands table above (covers SQL/XSS/mass-assignment/redirect/creds/log leakage).
- [ ] **Sensitive data handling** — rows "Hardcoded creds" + "Sensitive data in logs" above.
- [ ] **Encrypted credentials** — `grep -rn 'attr_encrypted' app/ packs/ --include='*.rb'` → expect matches (webhooks, payment creds). Verify each `as_json` excludes encrypted fields.
      ⚠️ Do NOT use `grep 'as_json' | grep -v 'except:'` as the gate — the real `Webhooks::Url`
      (`packs/webhooks/app/models/url.rb`) builds exclusions via a **computed** `clean_options[:except]`
      with no literal `except:` token on the line, so that heuristic FALSE-POSITIVES on correctly
      secured models and misses leaks elsewhere. Use an ast-grep pattern over models that declare
      `attr_encrypted`, or rely on ClickHouse Query #1 (Step below) which proves tokens are encrypted
      in prod. See the canonical case in [owasp-examples.md](reference/owasp-examples.md).
- [ ] **ClickHouse data exposure (CRIT)** — verify no sensitive data is exposed in prod. See [ClickHouse Queries](../shared/clickhouse-queries.md): Query #1 (unencrypted webhook tokens → 0 rows), #2 (exposed card data → 0), #3 (sensitive data in audit logs → 0), #6 (facility distribution / no orphans). MCP example:
      ```
      mcp__clickhouse__run_query:
        query: "SELECT id, uuid, url, CASE WHEN encrypted_auth_token IS NOT NULL AND encrypted_auth_token != '' THEN 'ENCRYPTED_OK' ELSE 'NO_TOKEN' END AS auth_token_status FROM pbp_productionDB_optimized.webhooks_urls LIMIT 10"
      ```
- [ ] **Honeybadger correlation** — `mcp__honeybadger__list_faults` with `q: "authentication OR authorization OR permission"` and `q: "SQL OR injection OR ActiveRecord"`; `get_fault` for detail. Monitor: `ActionController::InvalidAuthenticityToken`, `CanCan::AccessDenied`, `ActiveRecord::RecordNotFound` (possible IDOR probe), `OpenSSL::*`, `JWT::*`.

## OWASP Top 10

Detection lives in the table above; vulnerable→safe code pairs for every category (injection, broken auth, sensitive data exposure, XXE, broken access control, misconfiguration, XSS, insecure deserialization, command injection, path traversal, bare rescue) are in [owasp-examples.md](reference/owasp-examples.md). Per-category status goes in the report table (see report template).

## Payment-Specific Security

```ruby
# Tests: ❌ ENV['PRODUCTION_API_KEY']      ✅ { api_key: 'sandbox_test_key', environment: 'sandbox' }
# Tokens: ❌ redirect_to "...?token=#{t}"  ✅ headers: { 'Authorization' => "Bearer #{t}" }
```

Card-data / payment-gateway security (PCI-DSS Reqs 3/4/6/7/10 across all 14 gateways) → run `/pci-compliance`.

## Webhook Credential Security

The real model is `packs/webhooks/app/models/url.rb` — it encrypts four attrs (`auth_token`, `username`, `password`, `webhook_secret`) with `key: ENCRYPTION_KEY, mode: :per_attribute_iv, encode: true, encode_iv: true` (NOT `aes-256-gcm` / `Rails.application.credentials`), and its `as_json` excludes all encrypted attrs + `_iv` siblings + decrypted accessors via a computed `clean_options[:except]`. Full verified snippet + the false-positive grep caveat: [owasp-examples.md](reference/owasp-examples.md).

## Checklist

For each changed file: no SQL injection · no XSS (raw/html_safe guarded) · no command injection · no hardcoded credentials · no sensitive data logging · CSRF protection · authorization checks present · payment data handled · webhook credentials encrypted · API tokens in headers not URLs.

## Report Format

See [report-and-example.md](reference/report-and-example.md) for the markdown report template and a full example transcript.

---

## Related Skills

- **`/pci-compliance`** — PCI-DSS validation for payment code (14 gateways)
- **`/multi-tenancy`** — facility scoping vs data leakage (run together with security)
- **`/graphql`** — API security & authorization (JWT, CanCanCan)
- **`/code-review`** — comprehensive review includes security (Brakeman, OWASP)
- **`/gateway-consistency`** — payment gateway security patterns across 14 implementations

**Workflow**: `/orchestrate feature` includes security validation in Phase 2 (Validation).

---

## Kaizen: Continuous Improvement

> "Every day we must improve" — 改善

While executing this skill, if you find a new vulnerability pattern, a missing OWASP check, or a better Brakeman config: (1) finish the current audit, (2) append the improvement here with `<!-- Kaizen: YYYY-MM-DD -->`. Older entries are archived in [kaizen_log.md](kaizen_log.md).

<!-- Kaizen: 2026-06-15 — optimize-skill: 680→~190 lines. Relocated OWASP Top 10 code blocks + illustrative examples → reference/owasp-examples.md; report template + example transcript → reference/report-and-example.md. Collapsed Quick Validation + Additional Patterns into one Detection Commands table; Audit Process → checklist. Fixed: the `attr_encrypted` aes-256-gcm/credentials.dig block was fabricated (real model uses ENCRYPTION_KEY + per_attribute_iv + 4 encrypted attrs); the `as_json | grep -v 'except:'` heuristic false-positives on the real computed-`except` model; added Brakeman --only-files caveat (whole-app data-flow → per-file scans incomplete). -->
