# Membership Lifecycle — AASM State Diagram (L3 reference)

> Canonical machine-readable transitions live in SKILL.md ("AASM Events Summary" table).
> This file is the visual companion. Source of truth: `app/models/membership.rb`.

Real AASM states: `idle` (default/initial), `active`, `paused`, `cancelled`, `failed`.
There is NO `pending_payment` state and NO `expired` state in the real model.

```
┌─────────────────────────────────────────────────────────────────────┐
│              MEMBERSHIP LIFECYCLE (real AASM states)                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────┐  start!   ┌──────────┐                                │
│  │   idle   │──────────▶│  active  │◀──────────┐                    │
│  └──────────┘           └────┬─────┘           │                    │
│       │                      │                 │                    │
│       │   fail! also from    │ pause!          │ resume! (from      │
│  fail!│   active/paused/     ▼                 │  cancelled)        │
│       │   cancelled     ┌──────────┐           │                    │
│  ┌────┴─────┐           │  paused  │           │                    │
│  │  failed  │           └────┬─────┘           │                    │
│  └──────────┘                │ continue!       │                    │
│       │                      └────────────────▶│                    │
│       │ recover!                               │                    │
│       └────────────────────────────────────────┘                    │
│                                                                      │
│  cancel! (from active)                         ┌───────────┐        │
│  cancel_immediately! (from idle/active/        │ cancelled │        │
│    cancelled/failed/paused)                    └───────────┘        │
│                                                      ▲              │
│  renew! (from idle/cancelled/failed) ──────▶ active  │              │
│  (also valid from cancelled for re-activation)        │              │
│                                                       │              │
│  Note: fail! transitions: active/paused/cancelled ───┘              │
│                           → failed                                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

There is NO direct `active → active` renewal transition. Renewal goes through
`renew!` from `idle`/`cancelled`/`failed`, or period extension happens in place
via `next_current_period_end_at` on a membership that is already `active`.
