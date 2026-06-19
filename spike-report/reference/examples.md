# Examples — Worked Spike Reports

Invocation grammar (`/spike-report …`) is shorthand for a manual request — see the Invocation
block in the body. It is NOT a registered slash command with a flag parser.

## Example 1: Architecture Spike (RBAC)

```bash
# Request
/spike-report rbac-permissions architecture

# Analysis Phase
- Branch: feature/CORE-141-spike-roles-and-user-management
- Commits: 15 (all RBAC-related)
- Files: 8 abilities, 3 migrations, 12 docs
- Entities: 8 roles, 25 permissions, 10 resources

# Generated Sections
1. 🏗️ Resource Hierarchy (org → facility → resources)
2. 🔄 Permission Flow (evaluation algorithm)
3. ⬇️ Role Inheritance (org roles → facility roles)
4. 🗃️ Database Schema (ERD with 6 tables)
5. 📊 Permission Matrix (8 roles × 12 permissions)
6. 🔍 Gap Analysis (current vs proposed)

# Output (investigations/spikes/ will be created if it doesn't exist yet)
✅ Generated: investigations/spikes/SPIKE_RBAC_Permissions_2026-02-10.html (1,234 lines)
📝 Summary: investigations/spikes/SPIKE_RBAC_Permissions_2026-02-10.md
📊 Preview: file:///Users/leon/workspace/pbp/platform/investigations/spikes/SPIKE_RBAC_Permissions_2026-02-10.html

Time: 28 minutes (vs 2.5 hours manual)
```

## Example 2: Feature Spike (Payment Gateway Consolidation)

```bash
# Request
/spike-report payment-gateway-consolidation feature --sections current,proposed,migration,risks

# Analysis Phase
- Files: 14 gateway implementations, PaymentService::Base
- Entities: 14 gateways, 1 unified interface (proposed)
- Gaps: Inconsistent error handling, duplicated code

# Generated Sections
1. 📍 Current State (14 separate implementations)
2. ✨ Proposed Design (unified interface diagram)
3. 🚚 Migration Strategy (3 phases, timeline)
4. ⚠️ Risks & Mitigations (breaking changes, rollback)

# Output
✅ Generated: investigations/spikes/SPIKE_Payment_Gateway_Consolidation_2026-02-10.html (856 lines)
```

## Example 3: Performance Spike (N+1 Query Fixes)

```bash
# Request
/spike-report n1-query-optimization performance

# Analysis Phase
- Found: 12 N+1 queries (Grep for "includes\(")
- Controllers: 6 affected (ReservationsController, PaymentsController, etc.)
- Current metrics: 250ms avg response time

# Generated Sections
1. 📊 Current Metrics (response times, query counts)
2. 🐢 Bottlenecks (12 N+1 queries identified)
3. ⚡ Proposed Fixes (includes/preload/joins usage)
4. 🏁 Benchmarks (before: 250ms, after: 80ms)

# Output
✅ Generated: investigations/spikes/SPIKE_N1_Query_Optimization_2026-02-10.html (645 lines)
```
