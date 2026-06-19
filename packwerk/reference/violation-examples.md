# Packwerk Violation Examples

> Illustrative patterns — NOT all sourced from real files/line numbers at HEAD.
> File:line citations must be verified against HEAD before being cited as evidence.
>
> **Scope note:** This repo runs **packwerk 3.2.2** with no `packwerk-extensions` gem,
> so the ONLY violation class the installed tool emits is **Dependency violation**.
> Privacy violations cannot be produced here (see SKILL.md "Stack reality"). The
> privacy/circular examples below are kept for teaching only and do not correspond to
> checks this repo runs.

## Dependency violation — using a package without declaring it

```ruby
# ❌ BAD - Using FeatureFlag without declared dependency
def discounts_enabled?
  FeatureFlag::Setting.enabled?(:product_discounts, facility_id)
end

# ✅ GOOD - Declare dependency in package.yml
# packs/merchandise/package.yml:
dependencies:
  - packs/feature_flag
```

Note: `packs/merchandise/package.yml` at HEAD has `enforce_dependencies: true` but no
`dependencies` key — a real pattern to check. The `product.rb:23` citation is illustrative.

## Table naming violation — unprefixed table

```ruby
# ❌ BAD - Missing package prefix
create_table :waivers do |t|
  t.references :facility
  t.string :waiver_type
end

# ✅ GOOD - Prefix with package name
create_table :game_match_waivers do |t|
  t.references :facility
  t.string :waiver_type
end
```

Note: illustrative. Real game_match migrations (2026-era) already follow the
`game_match_` prefix.

## Circular dependency (teaching pattern)

```yaml
# ❌ BAD - Circular dependency between packages
# packs/pack_a/package.yml
dependencies:
  - packs/pack_b
# packs/pack_b/package.yml
dependencies:
  - packs/pack_a  # Circular!

# ✅ GOOD - Extract a shared interface to a third package both depend on
```

## Privacy (NOT enforced in this repo — teaching only)

Privacy enforcement (`enforce_privacy`) was **removed in Packwerk 3.0** and requires the
`packwerk-extensions` gem, which is NOT installed. The `enforce_privacy` keys present in a
few `package.yml` files (`agents_cli`, `billing` = true; `internal_*` = false) are **inert
vestiges**. To restore privacy checking you would first add `packwerk-extensions` to the
Gemfile — only then would adding `enforce_privacy: true` to a package.yml have any effect.

```ruby
# Pattern (would-be) violation: reaching into another pack's private constant
# ❌ Webhooks::Internal::Encryptor.encrypt(data)
# ✅ Webhooks::Url.encrypt_credentials(data)   # use the public API
```
