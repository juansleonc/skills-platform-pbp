# Multi-Tenancy Hierarchy (ASCII)

```
┌─────────────────────────────────────────────────────────────────┐
│                        FRANCHISE OWNER                           │
│         (Can access all facilities they own)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────┐    ┌─────────────────────┐             │
│  │  FACILITY GROUP A   │    │  FACILITY GROUP B   │             │
│  │  (Related venues)   │    │  (Related venues)   │             │
│  ├─────────────────────┤    ├─────────────────────┤             │
│  │ ┌───────┐ ┌───────┐ │    │ ┌───────┐ ┌───────┐ │             │
│  │ │Fac 1  │ │Fac 2  │ │    │ │Fac 3  │ │Fac 4  │ │             │
│  │ └───────┘ └───────┘ │    │ └───────┘ └───────┘ │             │
│  └─────────────────────┘    └─────────────────────┘             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

Three isolation levels:
1. **Facility** — primary tenant (`facility_id` or canonical association path).
2. **Facility Group** — related venues under same ownership; bidirectional scoping.
3. **Franchise / Parent-Child** — parent facility with child locations; cross-access documented.
