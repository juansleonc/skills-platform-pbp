# Security Audit — Report Template & Example Transcript

> **Reference bundle for `/security`.** Output templates only — no decision/branch logic lives here.

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
| SQL Injection | OK | All queries parameterized |
| XSS | WARN | 1 raw usage needs review |
| Auth | OK | Devise/CanCanCan properly used |
| Access Control | OK | Multi-tenant scoping present |

### Sensitive Data
- [ ] No card numbers in logs
- [ ] No passwords in logs
- [ ] Webhook credentials encrypted

### Findings

#### Medium: Potential XSS in user bio
Location: app/views/profiles/show.html.erb:45
\`\`\`erb
<%= raw @user.bio %>
\`\`\`
Recommendation: Use \`sanitize\` helper

### Recommendations
1. Replace \`raw\` with \`sanitize\` in profile view
2. Add CSP headers for additional XSS protection
```

## Example Transcript

```
User: /security

Claude:
## Security Audit

### Running Brakeman...
bin/d brakeman            # full scan; filter to changed files in the report

Results:
- High: 0
- Medium: 0
- Low: 0

### Checking OWASP patterns...

OK SQL Injection: No interpolated queries found
OK XSS: All output properly escaped
OK CSRF: Protection enabled
OK Access Control: Facility scoping present

### Checking sensitive data handling...

OK No card numbers in logs
OK No hardcoded credentials
OK Webhook credentials properly encrypted

### Payment security...

OK Sandbox credentials in tests
OK No CVV/card logging
OK Tokens in headers, not URLs

### Result: ALL CHECKS PASSED

No security vulnerabilities found.
```
