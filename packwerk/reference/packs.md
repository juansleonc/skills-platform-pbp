# Packwerk Package Inventory

> **Source of truth for the live pack list is the filesystem** — `ls -d packs/*/` (18 at
> time of writing). `CLAUDE.md`'s "Package Architecture" table is a **non-authoritative
> summary** (lists 15; billing, electronic_invoicing, and partners are missing). Trust the
> filesystem count; consult `CLAUDE.local.md`'s per-pack invariants table for domain notes.
> This file restates the inventory for the packwerk skill — run `ls -d packs/*/ | wc -l`
> to verify the current count before using it.

| Package | Purpose | Notes |
|---------|---------|-------|
| `agents_cli` | CLI agent tooling | Internal tooling |
| `audit_logs` | Event tracking, audit trails | DynamoDB storage |
| `billing` | Subscription billing for plans & plugins | Facility- vs org-scoped entitlements; `Billing::BillableEntityResolver` |
| `book_a_pro` | Pro booking/scheduling | GraphQL, validators |
| `camera_integrations` | Playsight camera integration | External devices |
| `electronic_invoicing` | Read-only transactions report for e-invoicing mandates | Report-only (no models/migrations); country adapters (PSFE/PAC/OSE) |
| `feature_flag` | Feature flag management | DynamoDB-backed, lock/sync system |
| `game_match` | Game/match management | Match scoring, results |
| `internal_backend` | Internal admin API | Feature flag API, policies |
| `internal_frontend` | Internal admin UI | React admin interface |
| `marketing_kit` | Marketing materials | Facility marketing assets |
| `merchandise` | Product management | Newer package |
| `orgs` | Organizations/SSO backend | Clerk SSO, SAML |
| `orgs_frontend` | Organizations/SSO UI | React components |
| `page_builder` | CMS frontend | React, separate assets |
| `partners` | Partner integrations (OAuth-like verification code flow) | `partners_verification_codes`; e.g. Schoolyard Social |
| `raffle` | Raffle/giveaway system | Event raffles |
| `webhooks` | Webhook management | Most mature, encrypted credentials |

## Packs with separate asset pipelines

Frontend packs build their own JS/CSS — rebuild after changes:

```bash
yarn --cwd packs/webhooks build
yarn --cwd packs/page_builder build
yarn --cwd packs/orgs_frontend build
```
