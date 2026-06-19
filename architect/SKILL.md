---
name: architect
description: Use when designing a new feature, pack, service, schema, or integration before implementation begins.
allowed-tools: [Bash, Read, Grep, Glob, Agent, mcp__context7__resolve-library-id, mcp__context7__query-docs, mcp__clickhouse__run_query, mcp__clickhouse__list_tables, mcp__clickhouse__list_databases, mcp__honeybadger__list_faults, mcp__honeybadger__get_fault, mcp__opensearch__SearchIndexTool]
disable-model-invocation: false
---

# Software Architect Skill

Strategic design decisions BEFORE any code is written — bridges requirements and implementation. "Measure twice, cut once": bad architecture is expensive to fix.

**Run `/architect` before implementing:** new features, significant refactors, new integrations, schema changes, new packages/modules. It ensures (1) code lives in the right place, (2) patterns match the existing codebase, (3) scalability is considered upfront, (4) production data informs design.

## OpenSpec Integration (Experimental)

**FIRST DECISION: Should this use the OpenSpec spec-driven workflow?** Heavy features defer to `/opsx:new` (→ `/opsx:ff` → `/opsx:apply`) instead of continuing here. Decision rule + ≥2-of scoring + workflow: see CLAUDE.local.md → "OpenSpec — Spec-Driven Development". If an OpenSpec change already has a `design.md`, stop and use `/opsx:continue` / `/opsx:apply` rather than `/architect`.

## Architecture Decision Process

Ordered flow: **1. UNDERSTAND** the problem → **2. EXPLORE** how similar code works today → **3. ANALYZE** production volumes (ClickHouse) → **4. RESEARCH** best practices (Context7) → **5. DESIGN** with trade-offs → **6. VALIDATE** multi-tenancy, performance, security.

## Step 0: Check Investigations Folder (BEFORE ANYTHING ELSE)

**Always check for prior research before starting architecture work:**

```bash
# Replace CORE-189 with the actual ticket ID from branch/message
ls investigations/CORE-189/ 2>/dev/null || echo "No prior research found"
```

**If the folder exists**, read all files inside before proceeding — it may contain:
- Reference guides explaining domain behavior
- Prior findings about external API quirks
- Partially-completed design decisions
- Manual test scripts showing what was already validated

**Why**: In CORE-189, a complete Patch CRM reference guide existed in `investigations/CORE-189/`.
Starting architecture work without reading it would have duplicated 2+ hours of prior research.

---

## Step 1: Understand the Requirement

Before anything else, clarify:

| Question | Why |
|----------|-----|
| What is the user goal? | Avoid solving wrong problem |
| Who uses this? | Admin, member, public? |
| What data is involved? | Determines schema design |
| What's the expected volume? | Affects architecture choices |
| Are there similar features? | Reuse patterns |

## Step 2: Explore Existing Patterns

**Find similar implementations in codebase:**

```bash
# Find related services
grep -rn "class.*Service" app/services/ --include="*.rb" | grep -i "<keyword>"

# Find related models
ls app/models/ | grep -i "<keyword>"

# Check if package exists for this domain
ls packs/

# Find similar GraphQL mutations
grep -rn "class.*Mutation" app/graphql/mutations/ --include="*.rb"
```

> Use `Grep` and `Glob` for symbol-level discovery.

**Use Agent for deep exploration:**

```
Agent tool:
  subagent_type: "Explore"
  prompt: "Find all code related to <feature>. I need to understand:
    1. Where similar features live (models, services, jobs)
    2. What patterns they use (Interactor, ApplicationService)
    3. How they handle multi-tenancy
    4. GraphQL types/mutations if applicable"
```

## Step 3: Analyze Production Data (MANDATORY)

**Use MCP tools for production queries (PREFERRED over docker).** PRIMARY: `mcp__clickhouse__run_query` (also `list_databases`, `list_tables`); plus `mcp__honeybadger__list_faults` / `mcp__honeybadger__get_fault` (faults) and `mcp__opensearch__SearchIndexTool` (logs). FALLBACK ONLY if MCP unavailable: `docker compose exec clickhouse clickhouse-client --query "..."`.

```ruby
mcp__clickhouse__run_query:
  query: "SELECT count(*) as total_rows FROM pbp_productionDB_optimized.<table>"
```

**ALWAYS check production data before designing:**

```sql
-- Database: pbp_productionDB_optimized (via mcp__clickhouse__)

-- 1. Check if related table exists and its volume
SELECT count(*) as total_rows
FROM pbp_productionDB_optimized.<related_table>

-- 2. Check data distribution by facility (multi-tenancy)
SELECT
  facility_id,
  count(*) as records
FROM pbp_productionDB_optimized.<table>
GROUP BY facility_id
ORDER BY records DESC
LIMIT 20

-- 3. Check growth rate (affects scalability decisions)
SELECT
  toStartOfMonth(created_at) as month,
  count(*) as new_records
FROM pbp_productionDB_optimized.<table>
WHERE created_at > now() - INTERVAL 12 MONTH
GROUP BY month
ORDER BY month

-- 4. Check relationships and cardinality
SELECT
  count(DISTINCT user_id) as unique_users,
  count(*) as total_records,
  round(count(*) / count(DISTINCT user_id), 2) as avg_per_user
FROM pbp_productionDB_optimized.<table>

-- 5. Check for NULL patterns that affect schema design
SELECT
  countIf(<field> IS NULL) as nulls,
  countIf(<field> IS NOT NULL) as non_nulls,
  round(countIf(<field> IS NULL) / count(*) * 100, 2) as null_pct
FROM pbp_productionDB_optimized.<table>
```

**Volume thresholds for architecture decisions:**

| Records | Recommendation |
|---------|----------------|
| < 10k | Simple queries OK |
| 10k - 100k | Need indexes, consider pagination |
| 100k - 1M | Background jobs for bulk ops, caching |
| > 1M | Partitioning, read replicas, async processing |

## Step 4: Research Best Practices (Context7)

**MANDATORY for new gems/frameworks**: If the task introduces a gem not yet used in the codebase, ALWAYS query Context7 before designing. This catches naming conventions, recommended patterns, and common pitfalls early.

```
# Example: Adding action_policy authorization (this project uses action_policy, NOT Pundit)
mcp__context7__resolve-library-id:
  libraryName: "action_policy"
mcp__context7__query-docs:
  libraryId: "/palkan/action_policy"
  query: "setup best practices controller integration naming"
```

**Query Context7 for architecture patterns:**

```
# Rails architecture patterns
mcp__context7__resolve-library-id:
  libraryName: "rails"
  query: "service object patterns best practices"

mcp__context7__query-docs:
  libraryId: "/rails/rails"
  query: "ActiveRecord performance large tables pagination"

# Specific patterns
mcp__context7__query-docs:
  libraryId: "/rails/rails"
  query: "concerns vs modules code organization"

# GraphQL design
mcp__context7__resolve-library-id:
  libraryName: "graphql-ruby"
  query: "mutation design patterns connections"
```

**Common queries by feature type:**

| Feature Type | Context7 Query |
|--------------|----------------|
| CRUD operations | `"Rails scaffold alternatives service objects"` |
| Background jobs | `"Sidekiq job design patterns idempotency"` |
| API endpoints | `"GraphQL resolver design N+1 prevention"` |
| Notifications | `"Action Mailer async delivery patterns"` |
| File uploads | `"ActiveStorage direct upload patterns"` |
| Search | `"Elasticsearch Rails integration patterns"` |
| Caching | `"Rails caching strategies fragment caching"` |

## Step 5: Design Proposal

### 5.0 Naming Conventions (Rails)

| Type | Pattern | Example | Anti-pattern |
|------|---------|---------|-------------|
| Controllers | Adjective/noun form | `ApplicationController` | `AuthorizerController` |
| Services | Verb+noun | `CreateUserService` | `UserCreator` |
| Policies | `ModelPolicy` | `TestimonialPolicy` | `TestimonialAuth` |
| Concerns | Adjective/capability | `Authenticatable` | `Authenticator` |
| Jobs | Verb+noun+Job | `SyncContactJob` | `ContactSyncer` |

### 5.1 Code Location Decision

**Decision tree for where code lives:**

```
Is it a new domain with multiple models/services?
  └── YES → New pack in packs/
  └── NO → Continue...

Is it related to an existing pack?
  └── YES → Add to that pack
  └── NO → Continue...

Is it a cross-cutting concern?
  └── YES → app/services/ or app/concerns/
  └── NO → Continue...

Is it a single model with simple logic?
  └── YES → app/models/ with service if complex
  └── NO → app/services/
```

**Package structure (if new pack):**

```
packs/<feature_name>/
├── app/
│   ├── models/<feature_name>/
│   ├── services/<feature_name>/
│   ├── jobs/<feature_name>/
│   └── graphql/
│       ├── types/
│       └── mutations/
├── spec/
├── package.yml
└── README.md
```

### 5.2 Pattern Selection

| Pattern | When to Use | Example |
|---------|-------------|---------|
| `ApplicationService` | Simple single-purpose operations | `Users::ActivateService` |
| `Interactor` | Complex workflows with multiple steps | `PaymentService::ProcessPayment` |
| `Query Object` | Complex database queries | `Users::SearchQuery` |
| `Form Object` | Complex form validation | `Reservations::BookingForm` |
| `Presenter` | View-specific logic | `MembershipPresenter` |
| `Policy` | Authorization rules | `ReservationPolicy` |

### 5.3 Database Schema Design

**Mandatory fields for all tables:**

```ruby
create_table :<table_name> do |t|
  # ALWAYS include for multi-tenancy
  t.references :facility, null: false, foreign_key: true, index: true

  # Business fields
  t.string :name
  # ...

  # Standard timestamps
  t.timestamps

  # Soft delete if needed
  t.datetime :deleted_at, index: true
end

# ALWAYS add composite indexes for common queries
add_index :<table_name>, [:facility_id, :status]
add_index :<table_name>, [:facility_id, :created_at]
```

### 5.4 GraphQL Design

```ruby
# Type naming: <Model>Type
module Types
  class FeatureType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    # Use connections for lists (pagination)
    field :items, Types::ItemType.connection_type, null: false
  end
end

# Mutation naming: <Action><Model>
module Mutations
  class CreateFeature < BaseMutation
    # Input type for complex inputs
    argument :input, Types::FeatureInputType, required: true

    # Return type
    field :feature, Types::FeatureType, null: true
    field :errors, [String], null: false
  end
end
```

## Step 6: Validate Design

**Checklist before proceeding:**

| Check | How | Status |
|-------|-----|--------|
| Multi-tenancy | All queries scoped by `facility_id` | |
| Scalability | ClickHouse shows volume is manageable | |
| Pattern consistency | Matches existing codebase patterns | |
| Package boundaries | No circular dependencies | |
| API compatibility | No breaking changes to mobile | |
| Security | No data leakage between tenants | |
| Performance | Indexes planned, N+1 prevented | |

## Architecture Decision Record (ADR) Format

```markdown
## ADR: <Feature Name>

### Context
<What is the problem/requirement?>

### Production Data Analysis
- Table: <table_name>
- Current volume: <X records>
- Growth rate: <Y records/month>
- Key patterns: <NULL handling, cardinality>

### Decision
**Location:** <packs/X or app/services/X>
**Pattern:** <ApplicationService, Interactor, etc.>
**Schema:** <New tables, fields>
**API:** <GraphQL mutations/queries>

### Alternatives Considered
1. <Option A> - Rejected because...
2. <Option B> - Rejected because...

### Consequences
- Good: <benefits>
- Bad: <trade-offs>

### Implementation Plan
1. <Step 1>
2. <Step 2>
3. <Step 3>
```

<!-- Kaizen: 2026-06-09 - Placeholder anti-pattern catalog (adapted from obra/superpowers, MIT) -->
## Plan Self-Check: Placeholder Anti-Patterns

Before handing off a design proposal or ADR, grep your own plan for these signals. If found, the plan is not ready to implement:

- **"TBD" / "TODO" / "implement later"** — a plan with a hole is not a plan; fill it or cut the step.
- **"Add appropriate error handling" / "handle edge cases"** — name the specific cases (nil owner, missing facility, duplicate call) and show the handling; vague directives generate vague code.
- **"Similar to Task N" / "same as above"** — repeat the concrete steps inline; the implementer cannot act on a pointer to another step.
- **Steps that say WHAT without showing HOW** — each step must name the file, the method/change, and how it is verified (test name or assertion); a step missing any of the three is incomplete.

---

## Examples & MCP Integrations

- Worked ADR example (Push Notifications feature): see [reference/examples.md](reference/examples.md).
- Architecture diagrams: `mcp__mermaid__*` does not exist in this environment — use text-based diagrams in ADRs.

---

## Kaizen

Continuous-improvement history lives in [kaizen_log.md](kaizen_log.md) (sibling-skill convention). When you discover a new pattern, missing criterion, or better ClickHouse query: finish the current review first, then append an entry there (`<!-- Kaizen: YYYY-MM-DD --> …`). Do NOT inline Kaizen entries back into this file.
