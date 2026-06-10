---
name: architect
description: Use when designing a new feature, pack, service, schema, or integration before implementation begins.
allowed-tools: [Bash, Read, Grep, Glob, Agent, mcp__context7__resolve-library-id, mcp__context7__query-docs, mcp__clickhouse__run_select_query, mcp__clickhouse__list_tables, mcp__clickhouse__list_databases, mcp__mermaid__*, mcp__ide__executeCode, mcp__ide__getDiagnostics]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

## Shared References

> **📚 This skill uses shared documentation. See:**
> - Use `Grep` and `Glob` for structural exploration before designing changes (Serena removed 2026-06-02)

# Software Architect Skill

Strategic design decisions BEFORE any code is written. This skill bridges the gap between requirements and implementation.

## When to Use

**ALWAYS run `/architect` before implementing:**
- New features
- Significant refactors
- New integrations
- Database schema changes
- New packages/modules

## Philosophy

> "Measure twice, cut once"

Bad architecture decisions are expensive to fix. This skill ensures:
1. Code lives in the right place
2. Patterns match existing codebase
3. Scalability is considered upfront
4. Production data informs design

## OpenSpec Integration (Experimental)

**FIRST DECISION: Should this use OpenSpec workflow?**

Before starting architecture design, evaluate if this feature warrants OpenSpec's structured approach:

### OpenSpec Scoring Algorithm

```ruby
score = 0

# Positive criteria
score += 3 if estimated_time > 1.day
score += 2 if customer_facing?      # Emails, UI, public API
score += 2 if multi_stakeholder?    # Needs PM/design approval
score += 2 if compliance_required?  # PCI, SOC2, audit trail
score += 1 if complex_decisions?    # Multiple architectural choices
score += 1 if needs_handoff?        # Between sessions/developers

# Negative criteria
score -= 2 if bug_fix?
score -= 2 if prototype?
score -= 1 if internal_only?

# Decision threshold
if score >= 5
  :use_openspec         # High-value: Use structured workflow
elsif score >= 3
  :ask_user            # Medium: Let user decide
else
  :use_architect       # Low: Traditional workflow sufficient
end
```

### When Score ≥ 5: Recommend OpenSpec

**Output to user**:
```
📋 OpenSpec Recommended (Score: X)

This feature meets OpenSpec criteria:
- [✓/✗] Large (> 1 day)
- [✓/✗] Customer-facing
- [✓/✗] Multi-stakeholder
- [✓/✗] Compliance required
- [✓/✗] Complex decisions
- [✓/✗] Needs handoff

Recommended workflow:
1. /opsx:new [feature-name]
2. /opsx:ff [feature-name]     # Generates: proposal, design, specs, tasks
3. Review artifacts
4. /opsx:apply                 # Implement

Alternatively, continue with /architect for traditional planning.
Your choice?
```

**If user chooses OpenSpec**:
- Guide them through `/opsx:new` + `/opsx:ff`
- Your role ends here (OpenSpec workflow takes over)
- Remind: "Run `/opsx:apply` when ready to implement"

**If user declines OpenSpec**:
- Continue with normal Architecture Decision Process below
- Document decision in output: "Proceeding with /architect (OpenSpec declined)"

### When Score 3-4: Ask User

```
🤔 OpenSpec Optional (Score: X)

This feature could benefit from OpenSpec but isn't required.

OpenSpec pros:
- Structured specs (testable scenarios)
- Design decisions documented (design.md)
- Clear implementation tasks (tasks.md)

OpenSpec cons:
- ~75 min overhead before coding
- Less flexible mid-implementation

Use OpenSpec? (y/n)
```

### When Score < 3: Skip OpenSpec

Silently proceed with traditional `/architect` workflow. No need to mention OpenSpec.

### Integration with OpenSpec Workflow

**If OpenSpec change exists** (check `openspec/changes/[feature-name]/`):

1. **Read existing artifacts**:
   ```bash
   ls openspec/changes/*/proposal.md 2>/dev/null
   ls openspec/changes/*/design.md 2>/dev/null
   ```

2. **If proposal.md exists**:
   - Read it to understand motivation
   - Reference it in architecture recommendations
   - Note: "OpenSpec proposal exists, building on top of it"

3. **If design.md exists**:
   - STOP: OpenSpec already did design
   - Output: "Design.md already exists in OpenSpec change. Use `/opsx:continue` or `/opsx:apply` instead of /architect."

4. **If neither exists**:
   - Normal `/architect` workflow
   - Suggest: "Consider creating OpenSpec change first with `/opsx:new`" (if score ≥ 3)

## Architecture Decision Process

```
┌─────────────────────────────────────────────────────────────────┐
│  1. UNDERSTAND: What problem are we solving?                    │
│              ↓                                                  │
│  2. EXPLORE: How does similar code work today?                  │
│              ↓                                                  │
│  3. ANALYZE: Check production data volumes (ClickHouse)         │
│              ↓                                                  │
│  4. RESEARCH: Best practices from Context7                      │
│              ↓                                                  │
│  5. DESIGN: Propose architecture with trade-offs                │
│              ↓                                                  │
│  6. VALIDATE: Ensure multi-tenancy, performance, security       │
└─────────────────────────────────────────────────────────────────┘
```

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

> Use `Grep` and `Glob` for symbol-level discovery. (Serena removed 2026-06-02.)

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

**Use MCP tools for production queries (PREFERRED):**

```ruby
# ✅ PRIMARY METHOD: Use MCP ClickHouse tool
mcp__clickhouse__run_select_query:
  query: "SELECT count(*) as total_rows FROM pbp_productionDB_optimized.<table>"

# Available MCP Data Tools:
# - mcp__clickhouse__run_select_query - Execute production queries
# - mcp__clickhouse__list_databases - List available databases
# - mcp__clickhouse__list_tables - List tables with schema
# - mcp__honeybadger__* - Error tracking and fault analysis
# - mcp__opensearch__* - Search logs and patterns

# ❌ FALLBACK ONLY: Docker (if MCP unavailable)
# docker compose exec clickhouse clickhouse-client --query "..."
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
# Example: Adding Pundit authorization
mcp__context7__resolve-library-id:
  libraryName: "pundit"
mcp__context7__query-docs:
  libraryId: "/varvet/pundit"
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
| Controllers | Adjective/noun form | `AuthorizedController` | `AuthorizerController` |
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

## Examples

### Example 1: Push Notifications Feature

```
/architect push notifications system

## ADR: Push Notifications

### Context
Need to send push notifications to mobile users for reservations,
membership renewals, and promotions.

### Production Data Analysis (ClickHouse)
- Users table: 450k records
- Active users (last 30 days): 52k
- Facilities: 180
- Avg users per facility: 2,500

### Decision
**Location:** `packs/push_notifications/`
**Pattern:**
  - `PushNotifications::SendService` (Interactor) for sending
  - `PushNotifications::TokenManager` for device tokens
  - Sidekiq job for bulk sends

**Schema:**
```ruby
create_table :push_notification_tokens do |t|
  t.references :facility, null: false
  t.references :user, null: false
  t.string :device_token, null: false
  t.string :platform, null: false  # ios, android
  t.boolean :active, default: true
  t.timestamps
end
add_index :push_notification_tokens, [:facility_id, :user_id]
add_index :push_notification_tokens, [:device_token], unique: true
```

**API:**
- `registerPushToken` mutation
- `unregisterPushToken` mutation

### Implementation Plan
1. Create pack structure
2. Add migration for tokens table
3. Implement TokenManager service
4. Add GraphQL mutations
5. Implement SendService with Firebase integration
6. Add Sidekiq job for bulk notifications
```

---

## MCP Integrations

### Mermaid MCP

Use for generating architecture diagrams:

```
# Generate class diagram
mcp__mermaid__render:
  diagram: |
    classDiagram
    PushNotifications --> TokenManager
    PushNotifications --> SendService
    SendService --> FirebaseAdapter
    SendService --> Sidekiq

# Generate sequence diagram
mcp__mermaid__render:
  diagram: |
    sequenceDiagram
    participant App
    participant API
    participant Service
    participant Firebase
    App->>API: registerPushToken
    API->>Service: store_token
    Service-->>API: success
```

**Use Cases:**
- Generate architecture diagrams for ADRs
- Visualize service dependencies
- Document data flow patterns
- Create sequence diagrams for complex workflows

---

## Gradual Layerification (Refactoring Roadmap)

> Inspired by palkan's "Layered Design for Ruby on Rails Applications"

When proposing refactoring of existing code, use a **gradual adoption** approach instead of big-bang rewrites. Evaluate the current style and create a phased roadmap with escape hatches.

### Step 1: Assess Current Style

| Style | Description | Signs |
|-------|-------------|-------|
| **DHH/Majestic Monolith** | Fat models/controllers, minimal services | All logic in models, few `app/services/` files |
| **Partially Layered** | Some services, but inconsistent | Mix of fat models and service objects |
| **Fully Layered** | Clear separation: models, services, policies, presenters | Consistent service layer, thin models/controllers |

```bash
# Quick assessment
echo "=== Service count ==="
find app/services -name "*.rb" 2>/dev/null | wc -l

echo "=== Average model size ==="
wc -l app/models/*.rb | sort -rn | head -5

echo "=== Existing patterns ==="
grep -rl "< ApplicationService\|include Interactor\|class.*Policy" app/ --include="*.rb" | head -10
```

### Step 2: Match Existing Patterns

**CRITICAL**: Before introducing new patterns, find what's already used in the codebase:

```bash
# What service pattern does this project use?
grep -rn "< ApplicationService" app/services/ --include="*.rb" | head -5
grep -rn "include Interactor" app/services/ --include="*.rb" | head -5

# Are there existing policy objects?
ls app/policies/ 2>/dev/null

# Are there existing form objects?
find app -name "*form*" -o -name "*contract*" | grep -v spec | grep -v node_modules

# Are there existing query objects?
find app -name "*query*" -o -name "*finder*" | grep -v spec | grep -v node_modules
```

**Rule**: Follow existing patterns. If the project uses `ApplicationService`, don't introduce `Interactor`. If there are no policy objects, don't add them for one feature.

### Step 3: Create Phased Roadmap

**Phase 1: Extract Operations (Highest ROI)**
- Move callback operations (score 1-2) to service objects
- Target: `after_create` callbacks that send emails, sync external data
- **Stop here if**: Team velocity is good and codebase is manageable

**Phase 2: Extract Query Objects (Medium ROI)**
- Move complex scopes (>3 lines) to query objects
- Target: Scopes with joins, subqueries, or conditional logic
- **Stop here if**: Models have <20 scopes each

**Phase 3: Add Policy Layer (When Needed)**
- Extract authorization logic from controllers/models
- Target: Complex permission rules, multi-role access
- **Stop here if**: CanCanCan abilities are simple and maintainable

**Phase 4: Add Presenter/Form Objects (Low ROI Unless Pain)**
- Extract view logic to presenters
- Extract complex form validations to form objects
- **Stop here if**: Views are simple, forms map 1:1 to models

### Phase Escape Hatches

Each phase should include a "stop here" evaluation:

```markdown
## Refactoring Checkpoint: Phase N Complete

### Value Delivered
- [List improvements achieved]

### Remaining Pain Points
- [List remaining issues]

### Stop Here If:
- [ ] Remaining issues don't justify the effort
- [ ] Team is unfamiliar with the new patterns
- [ ] Feature velocity would decrease with more abstraction

### Continue If:
- [ ] Multiple developers hit the same pain points
- [ ] Bug rate in affected area is high
- [ ] New features require touching 5+ files (shotgun surgery)
```

### PBP-Specific Guidance

Given PBP's current state (852+ migrations, 14 gateways, mix of ApplicationService and Interactor):

1. **Don't introduce new patterns** — PBP already has `ApplicationService` and `Interactor`. Use what exists.
2. **Focus Phase 1 on payment models** — Most callback violations are in payment/membership models.
3. **Phase 2 query objects are low priority** — PBP uses scopes effectively.
4. **Phase 3 underway** — Pundit policies exist in `app/policies/`. Follow that pattern for authorization.
5. **Phase 4 is not needed** — ERB views are simple enough. No ViewComponent/presenter needed.

---

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- A new architecture pattern to document
- A missing decision criteria
- A better ClickHouse query for analysis

**You MUST**:
1. Complete the current architecture review first
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements**:

<!-- Kaizen: 2026-01-24 - Jupyter Notebook Integration -->
## 📓 Jupyter Notebook Integration (Recommended)

Use JupyterLab for **architecture data analysis** when you need to:
- Analyze production data volumes and patterns
- Prototype data models with real data
- Create visual representations of data relationships
- Document architecture decisions with data evidence

### Launch Jupyter for Architecture Analysis

```bash
~/jupyter-env/bin/jupyter lab
```

### Example Architecture Analysis Notebook

```python
# Cell 1: Setup
%load_ext sql
%sql clickhouse://default:@localhost:8123/pbp_productionDB_optimized

# Cell 2: Analyze data volumes for capacity planning
%%sql
SELECT
  'users' as table_name, count(*) as rows FROM users
UNION ALL
SELECT 'reservations', count(*) FROM reservations
UNION ALL
SELECT 'memberships', count(*) FROM memberships
UNION ALL
SELECT 'payments', count(*) FROM payments
ORDER BY rows DESC

# Cell 3: Analyze growth trends
%%sql
SELECT
  toStartOfMonth(created_at) as month,
  count(*) as new_records
FROM reservations
WHERE created_at > now() - INTERVAL 12 MONTH
GROUP BY month
ORDER BY month

# Cell 4: Visualize growth
import pandas as pd
import matplotlib.pyplot as plt

df = _
df['month'] = pd.to_datetime(df['month'])
df.plot(x='month', y='new_records', kind='line', marker='o')
plt.title('Reservations Growth Rate')
plt.ylabel('New Records per Month')

# Cell 5: Check cardinality for schema design
%%sql
SELECT
  'facility_id' as field,
  uniqExact(facility_id) as unique_values,
  count(*) as total_rows,
  round(count(*) / uniqExact(facility_id), 2) as avg_per_value
FROM reservations
UNION ALL
SELECT 'user_id', uniqExact(user_id), count(*), round(count(*) / uniqExact(user_id), 2)
FROM reservations
UNION ALL
SELECT 'status', uniqExact(status), count(*), round(count(*) / uniqExact(status), 2)
FROM reservations
```

### Schema Design Analysis

```python
# Check NULL patterns for schema decisions
%%sql
SELECT
  'acquired_at' as field,
  countIf(acquired_at IS NULL) as nulls,
  countIf(acquired_at IS NOT NULL) as non_nulls,
  round(countIf(acquired_at IS NULL) / count(*) * 100, 2) as null_pct
FROM memberships
UNION ALL
SELECT 'expires_at', countIf(expires_at IS NULL), countIf(expires_at IS NOT NULL),
       round(countIf(expires_at IS NULL) / count(*) * 100, 2)
FROM memberships

# Relationship analysis
%%sql
SELECT
  count(DISTINCT m.user_id) as users_with_memberships,
  (SELECT count(*) FROM users) as total_users,
  round(count(DISTINCT m.user_id) / (SELECT count(*) FROM users) * 100, 2) as pct
FROM memberships m
```

### MCP IDE Tools Available

- `mcp__ide__executeCode`: Execute Python in active Jupyter kernel
- `mcp__ide__getDiagnostics`: Get language diagnostics

<!-- Kaizen entries will be added here -->

<!-- Kaizen: 2026-01-31 - MCP Tools Integration -->
**Issue**: Step 3 didn't mention MCP tools for ClickHouse access, assumed docker-compose
**Root Cause**: Skill tried `docker compose exec clickhouse` first, failed, then remembered MCP exists
**Fix Applied**:
- Added MCP tools section at START of Step 3 (before SQL examples)
- Listed available MCP tools: clickhouse, honeybadger, opensearch
- Made MCP PRIMARY method, docker FALLBACK only
- Updated examples to show `mcp__clickhouse__run_select_query` usage

**Impact**: High (affects all /architect runs that need production data)
**Effort**: Low (5-minute documentation update)
**ROI**: 3.0 (Never fails to access ClickHouse, more reliable)

**Lesson Learned**: When MCP tools are available, they should be mentioned FIRST in any data access steps, not as fallback. Pattern applies to: /debug, /performance, /memberships, /code-review skills.

<!-- Kaizen: 2026-05-22 - User correction -->
- Rule: Respect approved scope before enforcing a destructive step (DELETE/cleanup) — never design one as a default/enforced behavior if the ticket marked it out-of-scope. Approval of X (e.g. links) ≠ approval to delete other tables.
- Why: In CORE-624 I nearly designed faves/user_stats deletion into the engine as an enforced default; the user caught that Erick had scoped those tables out — the exact scope creep (L3) I had criticized in TRIAGE-10.
- How to apply: When designing, re-read the approval record ("Out of scope / Pendiente / cleanup separado") before adding a destructive step as default/enforced. If out of scope: leave it out or strictly opt-in pending separate sign-off. Distinguish integrity consequences of an approved action (touch/reindex) from new destructive ops on other tables.
- Source: User correction on 2026-05-22. See `memory/feedback_respect_approved_scope.md`.

<!-- Kaizen: 2026-05-25 - User correction -->
- Rule: When deciding "where code/docs live", classify team-shared vs personal FIRST. Personal/local files (linked from `CLAUDE.local.md`, workflow notes, ticket research) NEVER go in `docs/` (committed); they go to gitignored locations.
- Why: While extracting reference docs out of `CLAUDE.local.md`, I placed them in `docs/development/` (committed) — personal notes would have reached the team repo. User: "si son local no deben estar donde es la doc de todo el equipo".
- How to apply: For any file-location decision, run `git check-ignore <path>` to confirm intent. In this repo: `docs/` = team/committed; `investigations/` + `.claude/` = personal/excluded; add new excluded paths to `.git/info/exclude` (local), NOT `.gitignore` (team).
- Source: User correction on 2026-05-25. See `memory/feedback_personal_files_excluded_location.md`.

<!-- Kaizen: 2026-06-05 - User correction -->
- Rule: When grounding a design in library/API docs, a NEGATIVE result ("the SDK has no X") is LOW-CONFIDENCE. Confirm against the authoritative structural source (Context7 dataclass/signature dump, or the reference/config page) before designing around the absence; an independent auditor contradicting a negative is high-signal.
- Why: A docs-research agent over-trusts the first page; a negative is unfalsifiable from one search. `max_budget_usd` was called non-existent (wrong SDK pages searched) but the Context7 dataclass showed it exists — nearly shipped a design that self-tracked cost instead of using the native cap.
- How to apply: For any design-affecting "X doesn't exist", run a targeted Context7 query for the exact type/dataclass/signature first; prefer a second independent check before committing the design.
- Source: User correction on 2026-06-05. See `memory/feedback_negative_research_result_low_confidence.md`.

<!-- kaizen 2026-06-09: "implement the plan" = classify by executor first -->
When the user says "implement the plan / do it" over a plan, run a CLASSIFICATION pass before any coding: tag each item {me-now / user-interactive-action / external-sign-off-gated / no-op}. Adoption/meta/strategy plans often have little-to-no code-for-me — do only the me-now subset (gitignored prep), hand the user their commands, DRAFT (never auto-send/commit) gated items, and name no-ops as done-by-decision. Do not fabricate busywork or cross a sign-off/commit/destructive gate. See memory feedback_implement_plan_classify_by_executor.
