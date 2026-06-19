# Code Review — Domain-Specific Checklists

Apply the relevant block(s) based on what the diff touches. The project-wide BLOCKING rules live in `SKILL.md` and `../shared/critical-rules.md`; these are the per-domain residuals.

## Contents
- [Payment Code](#payment-code)
- [GraphQL](#graphql)
- [Sidekiq Jobs](#sidekiq-jobs)
- [Models](#models)
- [Webhooks](#webhooks)
- [Tests](#tests)

---

## Payment Code
- [ ] Uses `ActiveRecord::Base.transaction`
- [ ] Idempotent operations with idempotency key
- [ ] Sandbox credentials only in tests
- [ ] No hardcoded API keys
- [ ] Uses `PaymentService::Base` for gateway routing
- [ ] Checks `merchants` table for facility settings

## GraphQL
- [ ] Uses deferred queries for heavy operations
- [ ] Custom auth in GraphqlController (not resolvers)
- [ ] Backward compatible changes only
- [ ] Proper error handling with GraphQL::ExecutionError

## Sidekiq Jobs
- [ ] Single hash argument: `def perform(args)`
- [ ] `args.deep_symbolize_keys` at start
- [ ] Variables initialized before try blocks
- [ ] Idempotent for payment operations
- [ ] Proper error handling for Honeybadger

## Models
- [ ] Scoped by `facility_id` where needed
- [ ] Uses `Time.current` not `Time.now`
- [ ] Proper associations and validations
- [ ] Admin override for cross-facility access documented

## Webhooks
- [ ] Uses `attr_encrypted` for credentials
- [ ] Excludes encrypted fields from JSON by default
- [ ] `include_decrypted: true` only when explicitly needed
- [ ] Event builders in `app/services/webhook_event_builders/`

## Tests
- [ ] No `allow_any_instance_of`
- [ ] No hardcoded IDs
- [ ] Uses appropriate factory method (`build` > `build_stubbed` > `create`)
- [ ] Time-dependent tests use `Timecop.freeze(Time.current)`
- [ ] Redis cleared for rate limiting tests
- [ ] 100% coverage on changes
