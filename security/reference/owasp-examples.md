# OWASP Top 10 — Vulnerable / Safe Code Examples

> **Reference bundle for `/security`.** Pure teaching examples (vulnerable → safe pairs).
> **None of these are sourced from real files or line numbers in this codebase** — do not cite as
> evidence. The decision logic (when to run which check, expected counts) stays in `SKILL.md`; this
> file is the demonstration appendix.

## 1. Injection (SQL, Command)

```ruby
# ❌ VULNERABLE - SQL Injection
User.where("email = '#{params[:email]}'")
User.where("name LIKE '%#{search}%'")

# ✅ SAFE - Parameterized
User.where(email: params[:email])
User.where("name LIKE ?", "%#{search}%")
User.where("name LIKE :search", search: "%#{search}%")

# ❌ VULNERABLE - Command Injection via interpolation
system("convert #{params[:filename]}")
`ls #{user_input}`

# ✅ SAFE - Array form prevents injection
system("convert", sanitized_filename)
Open3.capture3("convert", sanitized_filename)
```

## 2. Broken Authentication

```ruby
# ❌ VULNERABLE - Timing attack on password
if user.password == params[:password]

# ✅ SAFE - Constant time comparison
if ActiveSupport::SecurityUtils.secure_compare(user.password, params[:password])

# ✅ SAFE - Use Devise/bcrypt
if user.valid_password?(params[:password])
```

## 3. Sensitive Data Exposure

```ruby
# ❌ VULNERABLE - Logging sensitive data
Rails.logger.info("Processing payment: #{card_number}")
Rails.logger.debug("User password: #{password}")

# ✅ SAFE - Masked / metadata-only logging
Rails.logger.info("Processing payment: ****#{card_number.last(4)}")
Rails.logger.info("Processing payment for user: #{user.id}")

# ❌ VULNERABLE - Exposing encrypted fields in JSON
def as_json(options = {})
  super  # Includes encrypted_auth_token!
end

# ✅ SAFE - Exclude sensitive fields
def as_json(options = {})
  super(options.merge(except: [:encrypted_auth_token, :encrypted_auth_token_iv]))
end
```

## 4. XML External Entities (XXE)

```ruby
# ❌ VULNERABLE
Nokogiri::XML(user_input)

# ✅ SAFE - Disable external entities
Nokogiri::XML(user_input) { |config| config.nonet.noent }
```

## 5. Broken Access Control (IDOR)

```ruby
# ❌ VULNERABLE - No authorization (any user can access any record)
@payment = Payment.find(params[:id])
@reservation = Reservation.find(params[:id])

# ✅ SAFE - Scoped to facility / user
@payment = current_facility.payments.find(params[:id])
@reservation = current_user.reservations.find(params[:id])

# ✅ SAFE - CanCanCan authorization
@payment = Payment.find(params[:id])
authorize! :read, @payment
```

## 6. Security Misconfiguration

```ruby
# ❌ VULNERABLE - Debug info in production (production.rb)
config.consider_all_requests_local = true

# ✅ SAFE
config.consider_all_requests_local = false

# ❌ VULNERABLE - Missing CSRF
skip_before_action :verify_authenticity_token

# ✅ SAFE - CSRF protected, scoped skip for API tokens
protect_from_forgery with: :exception
skip_before_action :verify_authenticity_token, if: :valid_api_token?
```

## 7. Cross-Site Scripting (XSS)

```erb
<%# ❌ VULNERABLE - Unescaped output %>
<%= raw user.bio %>
<%= user.bio.html_safe %>

<%# ✅ SAFE - Escaped by default %>
<%= user.bio %>

<%# ✅ SAFE - Sanitized %>
<%= sanitize user.bio, tags: %w[b i u] %>
```

## 8. Insecure Deserialization

```ruby
# ❌ VULNERABLE - YAML.load / Marshal.load with user input
data = YAML.load(params[:data])
obj  = Marshal.load(params[:serialized])

# ✅ SAFE - safe_load / JSON
data = YAML.safe_load(params[:data], permitted_classes: [Symbol, Date])
obj  = JSON.parse(params[:data])
```

## 9. Command Injection (detail)

```ruby
# ❌ VULNERABLE
system("convert #{params[:filename]}")
`ls #{user_input}`

# ✅ SAFE - Array form
system("convert", sanitized_filename)
Open3.capture3("convert", sanitized_filename)
```

## 10. Path Traversal

```ruby
# ❌ VULNERABLE - Path traversal
send_file params[:path]                    # ../../etc/passwd
File.read("uploads/#{params[:filename]}")  # ../../../config/secrets.yml

# ✅ SAFE - Validate path
basename = File.basename(params[:filename])
send_file Rails.root.join("uploads", basename)
```

## 11. Bare Rescue

```ruby
# ❌ DANGEROUS - Swallows all errors including SystemExit, SignalException
rescue Exception => e
rescue => e  # Catches StandardError but hides intent

# ✅ SAFE - Explicit about what you catch
rescue ActiveRecord::RecordNotFound => e
rescue Stripe::CardError, Stripe::InvalidRequestError => e
rescue StandardError => e  # Acceptable when you need a broad catch
```

---

## Webhook credentials in JSON (the canonical PBP case)

The **real** webhook model lives at `packs/webhooks/app/models/url.rb` (NOT `app/models/webhooks/url.rb`).
It does NOT use `aes-256-gcm` or `Rails.application.credentials`. The real configuration:

```ruby
# packs/webhooks/app/models/url.rb (real, verified against HEAD)
ENCRYPTION_KEY = Rails.application.secrets.secret_key_base.first(32) # (with fallbacks)

attr_encrypted :auth_token,     key: ENCRYPTION_KEY, mode: :per_attribute_iv, encode: true, encode_iv: true
attr_encrypted :username,       key: ENCRYPTION_KEY, mode: :per_attribute_iv, encode: true, encode_iv: true
attr_encrypted :password,       key: ENCRYPTION_KEY, mode: :per_attribute_iv, encode: true, encode_iv: true
attr_encrypted :webhook_secret, key: ENCRYPTION_KEY, mode: :per_attribute_iv, encode: true, encode_iv: true
```

Its `as_json` excludes ALL encrypted fields (and their `_iv` siblings) plus the decrypted accessors,
via a **computed** `clean_options[:except]` — there is no literal `except:` token on the `as_json` line.
So a grep for `as_json | grep -v 'except:'` will FALSE-POSITIVE on this correctly-secured model:

```ruby
# Simplified shape of the real exclusion (see the real file for the full begin/rescue cipher guards)
excluded_attrs = %i[
  encrypted_auth_token encrypted_auth_token_iv
  encrypted_username   encrypted_username_iv
  encrypted_password   encrypted_password_iv
  encrypted_webhook_secret encrypted_webhook_secret_iv
]
excluded_attrs += %i[username password auth_token] unless include_decrypted
clean_options[:except] = (clean_options[:except] || []) + excluded_attrs
```
