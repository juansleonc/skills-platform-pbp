---
name: spike-report
description: Generate beautiful interactive HTML reports for technical spikes with SVG diagrams, permission matrices, and gap analysis
version: 1.0.0
author: skill-creator
created: 2026-02-10
tags: [documentation, visualization, spikes, architecture, reporting]
dependencies: [context7]
triggers:
  manual:
    - /spike-report
    - /spike-report [name] [type]
    - /spike-report --sections [sections]
related_skills: [architect, opsx:new, code-review]
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

# Spike Report Generator - Visual Documentation for Technical Proposals

> "A picture is worth a thousand words, an interactive diagram is worth ten thousand." - 視覚化 (Shikakuka - Visualization)

## Purpose

Automatically generate beautiful, interactive HTML reports for technical spikes and proposals with embedded SVG diagrams, permission matrices, gap analysis, and architectural visualizations. Transforms code analysis into shareable, stakeholder-friendly documentation.

## Philosophy

> "Great documentation doesn't just explain what exists—it visualizes relationships, flows, and evolution."
>
> **Good code tells you what it does. Great documentation shows you why it matters and how it works together.**

Technical spikes deserve more than markdown files. They need:
- **Visual hierarchy** - See organizational structure at a glance
- **Flow diagrams** - Understand permission evaluation, data flow
- **Interactive exploration** - Tab through sections, hover for details
- **Gap analysis** - Highlight what exists vs what's needed
- **Stakeholder-ready** - Beautiful enough to share with PM, design, leadership

This skill bridges the gap between technical depth and communication clarity.

## When to Use

### Automatic Triggers
None. This skill requires manual invocation to generate reports.

### Manual Triggers

```bash
# Analyze current branch and generate report
/spike-report

# Specify spike name and type
/spike-report rbac-permissions architecture
/spike-report payment-gateway-consolidation feature
/spike-report n1-query-optimization performance

# Include specific sections
/spike-report --sections hierarchy,flow,migration
/spike-report api-versioning --sections comparison,erd,migration,risks

# Generate for specific branch
/spike-report feature/CORE-141-rbac
```

**When to invoke**:
- ✅ After completing technical spike research
- ✅ Before presenting proposal to stakeholders
- ✅ When documenting architectural decisions
- ✅ For complex feature proposals needing visualization
- ✅ When comparing current vs proposed architectures
- ✅ For audit/compliance documentation (PCI, SOC2)

**When NOT to invoke**:
- ❌ Quick bug fixes (overkill)
- ❌ Mid-spike (wait until analysis complete)
- ❌ Simple features with no architecture changes
- ❌ Internal refactors (no external communication need)

## Spike Types Supported

| Type | Sections Generated | Example |
|------|-------------------|---------|
| **architecture** | Hierarchy, Flow, ERD, Migration | RBAC redesign, service extraction |
| **feature** | Before/After, Flow, Migration, Risks | New booking flow, payment methods |
| **performance** | Metrics, Bottlenecks, Improvements, Benchmarks | N+1 fixes, caching strategy |
| **security** | Threat model, Flow, Mitigations, Compliance | PCI compliance, OWASP fixes |
| **integration** | Architecture, API contracts, Error handling | Payment gateway, webhook system |
| **migration** | Current/Proposed, Phases, Rollback, Risks | Rails 7 upgrade, database migration |

## Workflow (6 Phases)

```
┌─────────────────────────────────────────────────────────┐
│          SPIKE REPORT GENERATION WORKFLOW               │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Phase 1: ANALYZE (Code Discovery) [5 min]             │
│  ┌──────────────────────────────────────────────┐      │
│  │ • Read git log (last 20 commits on branch)   │      │
│  │ • Identify spike scope from commit messages  │      │
│  │ • Find relevant files (abilities, models,    │      │
│  │   migrations, services, policies, configs)   │      │
│  │ • Extract entities (roles, permissions,      │      │
│  │   resources, gateways, etc.)                 │      │
│  │ • Read existing docs (docs/architecture/)    │      │
│  │ • Analyze branch file changes                │      │
│  └──────────────────────────────────────────────┘      │
│                        ▼                                │
│  Phase 2: RESEARCH (Best Practices) [3 min]            │
│  ┌──────────────────────────────────────────────┐      │
│  │ • Use context7 MCP tool:                     │      │
│  │   - SVG best practices (MDN Web Docs)        │      │
│  │   - Tailwind CSS patterns (official docs)    │      │
│  │   - Accessibility (ARIA, semantic HTML)      │      │
│  │   - Interactive diagrams (D3.js concepts)    │      │
│  │ • Research similar patterns in codebase      │      │
│  │ • Check existing spike reports for style     │      │
│  └──────────────────────────────────────────────┘      │
│                        ▼                                │
│  Phase 3: STRUCTURE (Content Planning) [2 min]         │
│  ┌──────────────────────────────────────────────┐      │
│  │ • Determine report sections based on type:   │      │
│  │   - Architecture: hierarchy, flow, ERD       │      │
│  │   - Feature: before/after, migration         │      │
│  │   - Performance: metrics, benchmarks         │      │
│  │ • Plan tab structure and navigation          │      │
│  │ • Identify info boxes (warnings, gaps, new)  │      │
│  │ • Determine color scheme (match spike theme) │      │
│  └──────────────────────────────────────────────┘      │
│                        ▼                                │
│  Phase 4: DIAGRAM (SVG Generation) [8 min]             │
│  ┌──────────────────────────────────────────────┐      │
│  │ • Generate SVG diagrams:                     │      │
│  │   ✓ Hierarchy/org charts                    │      │
│  │   ✓ Flow diagrams (permissions, data flow)   │      │
│  │   ✓ ERDs (database schema)                   │      │
│  │   ✓ State machines                           │      │
│  │   ✓ Comparison (current vs proposed)         │      │
│  │ • Apply consistent color scheme:             │      │
│  │   - Gradients for depth                      │      │
│  │   - Color-coded entities                     │      │
│  │   - Hover effects (brightness)               │      │
│  │ • Add interactive elements                   │      │
│  │ • Calculate SVG coordinates (auto-layout)    │      │
│  └──────────────────────────────────────────────┘      │
│                        ▼                                │
│  Phase 5: CONTENT (HTML Generation) [10 min]           │
│  ┌──────────────────────────────────────────────┐      │
│  │ • Create HTML structure:                     │      │
│  │   - Header (title, subtitle, status badge)   │      │
│  │   - Tab navigation (responsive)              │      │
│  │   - Tab content sections                     │      │
│  │   - Info boxes (warnings, gaps, features)    │      │
│  │   - Permission matrices (if applicable)      │      │
│  │   - Related documents section                │      │
│  │   - Next steps checklist                     │      │
│  │ • Apply Tailwind CSS:                        │      │
│  │   - Responsive grid/flex layouts             │      │
│  │   - Gradient backgrounds                     │      │
│  │   - Shadow/border utilities                  │      │
│  │ • Add JavaScript for tab switching           │      │
│  │ • Embed SVG diagrams inline                  │      │
│  └──────────────────────────────────────────────┘      │
│                        ▼                                │
│  Phase 6: POLISH (Review & Save) [2 min]               │
│  ┌──────────────────────────────────────────────┐      │
│  │ • Validate HTML/CSS/SVG syntax               │      │
│  │ • Check accessibility (ARIA labels)          │      │
│  │ • Ensure responsive design (mobile test)     │      │
│  │ • Save to investigations/spikes/SPIKE_[name]_[date].html│  │
│  │ • Generate markdown summary (.md companion)  │      │
│  │ • Present preview file:// URL                │      │
│  └──────────────────────────────────────────────┘      │
│                                                         │
└─────────────────────────────────────────────────────────┘

Total time: ~30 minutes (vs 2-3 hours manual)
```

## Phase Details

### Phase 1: ANALYZE (Code Discovery)

**Goal**: Understand the spike scope and gather all relevant code/docs.

**Actions**:
```bash
# 1. Git analysis
git log --oneline -20  # Recent commits
git diff develop...HEAD --name-only  # Changed files

# 2. Find relevant files based on spike type
# Architecture spike:
Glob: "app/abilities/**/*.rb"
Glob: "app/policies/**/*.rb"
Glob: "db/migrate/*permissions*.rb"
Glob: "docs/architecture/**/*.md"

# Feature spike:
Glob: "app/services/**/*[feature_name]*.rb"
Glob: "app/controllers/**/*[feature_name]*.rb"
Glob: "spec/**/*[feature_name]*_spec.rb"

# Performance spike:
Grep: "includes\(|joins\(" --output_mode content
Grep: "N\+1" --output_mode files_with_matches

# 3. Extract entities
Read: ability.rb → extract roles list
Read: db/structure.sql → extract tables
Read: docs/*.md → extract existing architecture notes

# 4. Build context object
context = {
  branch: "feature/CORE-141-rbac",
  commits: 15,
  files_changed: ["app/abilities/ability.rb", ...],
  entities: {
    roles: ["owner", "admin", "billing_manager", ...],
    resources: ["Booking", "Payment", "User", ...],
    permissions: ["manage_bookings", "view_payments", ...]
  },
  existing_docs: ["docs/architecture/rbac/README.md", ...]
}
```

### Phase 2: RESEARCH (Best Practices)

**Goal**: Get authoritative guidance on visualization and styling.

**Actions**:
```bash
# Use context7 MCP tool for best practices
ToolSearch: "select:mcp__context7__query-docs"

# Query for each technology
1. SVG best practices:
   mcp__context7__query-docs: "SVG accessibility ARIA labels"
   mcp__context7__query-docs: "SVG gradients and filters"
   mcp__context7__query-docs: "SVG coordinate systems viewBox"

2. Tailwind CSS:
   mcp__context7__query-docs: "Tailwind CSS responsive grid layouts"
   mcp__context7__query-docs: "Tailwind CSS gradient backgrounds"

3. HTML5 semantics:
   mcp__context7__query-docs: "HTML5 semantic elements nav header"

4. Accessibility:
   mcp__context7__query-docs: "WCAG 2.1 color contrast ratios"
   mcp__context7__query-docs: "ARIA roles and labels"

# Extract key patterns
best_practices = {
  svg: "Use viewBox for responsive scaling, add ARIA labels for screen readers",
  tailwind: "Use utility classes, avoid custom CSS",
  colors: "Ensure 4.5:1 contrast ratio for text",
  interaction: "Add keyboard navigation for tabs"
}
```

### Phase 3: STRUCTURE (Content Planning)

**Goal**: Determine what sections to include based on spike type.

**Section Templates**:

```ruby
SPIKE_SECTIONS = {
  architecture: [
    { id: "hierarchy", title: "Resource Hierarchy", icon: "🏗️" },
    { id: "flow", title: "Permission Flow", icon: "🔄" },
    { id: "inheritance", title: "Role Inheritance", icon: "⬇️" },
    { id: "erd", title: "Database Schema", icon: "🗃️" },
    { id: "matrix", title: "Permission Matrix", icon: "📊" },
    { id: "gap", title: "Gap Analysis", icon: "🔍" }
  ],
  feature: [
    { id: "current", title: "Current State", icon: "📍" },
    { id: "proposed", title: "Proposed Design", icon: "✨" },
    { id: "flow", title: "User Flow", icon: "🔄" },
    { id: "migration", title: "Migration Strategy", icon: "🚚" },
    { id: "risks", title: "Risks & Mitigations", icon: "⚠️" }
  ],
  performance: [
    { id: "metrics", title: "Current Metrics", icon: "📊" },
    { id: "bottlenecks", title: "Bottlenecks", icon: "🐢" },
    { id: "improvements", title: "Proposed Fixes", icon: "⚡" },
    { id: "benchmarks", title: "Benchmarks", icon: "🏁" }
  ]
}

# User can override with --sections flag
# /spike-report --sections hierarchy,flow,matrix
```

### Phase 4: DIAGRAM (SVG Generation)

**Goal**: Create beautiful, interactive SVG diagrams.

**SVG Components**:

```xml
<!-- 1. Gradient Definitions (reusable) -->
<defs>
  <linearGradient id="redGrad" x1="0%" y1="0%" x2="0%" y2="100%">
    <stop offset="0%" style="stop-color:#EF4444"/>
    <stop offset="100%" style="stop-color:#DC2626"/>
  </linearGradient>
  <linearGradient id="purpleGrad">...</linearGradient>
  <linearGradient id="blueGrad">...</linearGradient>
  <linearGradient id="greenGrad">...</linearGradient>
  <linearGradient id="orangeGrad">...</linearGradient>
  <linearGradient id="tealGrad">...</linearGradient>
  <linearGradient id="grayGrad">...</linearGradient>

  <!-- Drop shadow filter -->
  <filter id="shadow" x="-10%" y="-10%" width="120%" height="130%">
    <feDropShadow dx="1" dy="2" stdDeviation="2" flood-opacity="0.2"/>
  </filter>
</defs>

<!-- 2. Node Template (with hover) -->
<g class="node" filter="url(#shadow)">
  <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="url(#{gradId})"/>
  <text x="{cx}" y="{cy}" text-anchor="middle" fill="white" font-weight="bold">
    {emoji} {label}
  </text>
</g>

<!-- 3. Connection Lines -->
<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}"
      stroke="#6B7280" stroke-width="2"
      marker-end="url(#arrowhead)"/>

<!-- 4. Flowchart Decision Diamonds -->
<polygon points="{x},{y-h} {x+w},{y} {x},{y+h} {x-w},{y}"
         fill="{color}"/>

<!-- 5. ERD Tables -->
<g class="node">
  <rect x="{x}" y="{y}" width="200" height="130" rx="8" fill="#EFF6FF" stroke="#3B82F6"/>
  <rect x="{x}" y="{y}" width="200" height="30" rx="8" fill="#3B82F6"/>
  <text x="{x+100}" y="{y+20}" text-anchor="middle" fill="white" font-weight="bold">
    {emoji} {TABLE_NAME}
  </text>
  <!-- Field rows -->
  <text x="{x+10}" y="{y+50}" fill="#1E40AF">id</text>
  <text x="{x+180}" y="{y+50}" text-anchor="end" fill="#6B7280">PK bigint</text>
  <!-- ... more fields -->
</g>
```

**Layout Algorithms**:

```ruby
# Hierarchy (tree layout)
def calculate_hierarchy_layout(nodes, parent_id: nil, x: 480, y: 20, level: 0)
  nodes_at_level = nodes.select { |n| n[:parent_id] == parent_id }
  width_per_node = 800 / [nodes_at_level.size, 1].max

  nodes_at_level.each_with_index do |node, i|
    node[:x] = x - (width_per_node * nodes_at_level.size / 2) + (width_per_node * i)
    node[:y] = y + (level * 120)

    # Recurse for children
    calculate_hierarchy_layout(nodes, parent_id: node[:id], x: node[:x], y: node[:y], level: level + 1)
  end
end

# Flow (sequential layout)
def calculate_flow_layout(steps)
  x = 400
  steps.each_with_index do |step, i|
    step[:x] = x
    step[:y] = 50 + (i * 100)
  end
end

# ERD (grid layout)
def calculate_erd_layout(tables)
  cols = Math.sqrt(tables.size).ceil
  tables.each_with_index do |table, i|
    table[:x] = 50 + (i % cols) * 250
    table[:y] = 50 + (i / cols) * 200
  end
end
```

### Phase 5: CONTENT (HTML Generation)

**Goal**: Create the full HTML report with Tailwind CSS.

**HTML Template Structure**:

```html
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SPIKE: {spike_name}</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    .tab-content { display: none; }
    .tab-content.active { display: block; }
    .nav-tab.active { background: #3B82F6; color: white; }
    .diagram-container {
      background: #f9fafb;
      padding: 20px;
      border-radius: 12px;
      overflow-x: auto;
    }
    .node { cursor: pointer; transition: all 0.2s; }
    .node:hover { filter: brightness(1.1); }
  </style>
</head>
<body class="bg-gradient-to-br from-blue-50 to-indigo-100 min-h-screen">
  <div class="max-w-7xl mx-auto p-4 md:p-8">

    <!-- Header -->
    <header class="text-center mb-8">
      <h1 class="text-4xl font-bold text-gray-800 mb-2">
        {emoji} SPIKE: {spike_name}
      </h1>
      <p class="text-xl text-gray-600">{subtitle}</p>
      <div class="mt-4 inline-flex items-center gap-2 bg-{status_color}-100 text-{status_color}-800 px-4 py-2 rounded-full">
        <span class="font-semibold">{status_badge}</span>
      </div>
    </header>

    <!-- Tab Navigation -->
    <nav class="flex flex-wrap gap-2 mb-8 justify-center">
      {for each section}
      <button class="nav-tab {active_class} px-4 py-2 rounded-lg font-semibold bg-gray-200 hover:bg-gray-300 transition"
              onclick="showTab('{section_id}')">
        {section_icon} {section_title}
      </button>
      {end}
    </nav>

    <!-- Tab Contents -->
    {for each section}
    <div id="{section_id}" class="tab-content {active_class}">
      <div class="bg-white rounded-xl shadow-lg p-6 mb-8">
        <h2 class="text-2xl font-bold text-gray-800 mb-6">
          {section_icon} {section_title}
        </h2>

        <!-- Diagram Container -->
        <div class="diagram-container">
          <svg viewBox="0 0 {width} {height}" class="w-full max-w-4xl mx-auto">
            {svg_content}
          </svg>
        </div>

        <!-- Info Boxes -->
        {if has_warnings}
        <div class="mt-6 p-4 bg-yellow-50 border border-yellow-300 rounded-lg">
          <h4 class="font-bold text-yellow-800 mb-2">💡 {warning_title}</h4>
          <p class="text-yellow-700">{warning_text}</p>
        </div>
        {end}

        {if has_gaps}
        <div class="mt-6 p-4 bg-red-50 border border-red-300 rounded-lg">
          <h4 class="font-bold text-red-800 mb-2">🔍 {gap_title}</h4>
          <ul class="list-disc list-inside text-red-700">
            {for each gap}
            <li>{gap_description}</li>
            {end}
          </ul>
        </div>
        {end}

        {if has_new_features}
        <div class="mt-6 p-4 bg-blue-50 border border-blue-300 rounded-lg">
          <h4 class="font-bold text-blue-800 mb-2">✨ {feature_title}</h4>
          <ul class="list-disc list-inside text-blue-700">
            {for each feature}
            <li>{feature_description}</li>
            {end}
          </ul>
        </div>
        {end}
      </div>
    </div>
    {end}

    <!-- Footer: Related Documents & Next Steps -->
    <div class="bg-gradient-to-r from-blue-600 to-indigo-600 rounded-xl shadow-lg p-6 text-white mt-8">
      <h2 class="text-2xl font-bold mb-4">📌 Next Steps</h2>
      <div class="grid md:grid-cols-2 gap-6">
        <div>
          <h3 class="font-bold mb-2">📄 Related Documents:</h3>
          <ul class="text-blue-100 space-y-1">
            {for each doc}
            <li>• {doc_path}</li>
            {end}
          </ul>
        </div>
        <div>
          <h3 class="font-bold mb-2">🎯 Action Items:</h3>
          <ol class="list-decimal list-inside text-blue-100 space-y-1">
            {for each action}
            <li>{action_description}</li>
            {end}
          </ol>
        </div>
      </div>
    </div>
  </div>

  <!-- JavaScript -->
  <script>
    function showTab(tabId) {
      document.querySelectorAll('.tab-content').forEach(tab =>
        tab.classList.remove('active')
      );
      document.querySelectorAll('.nav-tab').forEach(btn =>
        btn.classList.remove('active')
      );
      document.getElementById(tabId).classList.add('active');
      event.target.classList.add('active');
    }
  </script>
</body>
</html>
```

### Phase 6: POLISH (Review & Save)

**Goal**: Validate quality and save files.

**Quality Checks**:

```bash
# 1. Validate HTML
# Check for:
# - Unclosed tags
# - Malformed attributes
# - Missing required elements (<!DOCTYPE>, <meta charset>)

# 2. Validate CSS
# Check for:
# - Invalid Tailwind classes
# - Conflicting styles
# - Missing responsive breakpoints

# 3. Validate SVG
# Check for:
# - Invalid viewBox
# - Gradient references exist
# - Text doesn't overflow rect bounds

# 4. Accessibility
# Check for:
# - ARIA labels on diagrams
# - Alt text (if images used)
# - Color contrast ratios (4.5:1 minimum)
# - Keyboard navigation (tab order)

# 5. Responsive design
# Test viewports:
# - Mobile: 375px
# - Tablet: 768px
# - Desktop: 1280px
```

**Save Files**:

```bash
# 1. HTML report (gitignored via .git/info/exclude — personal artifact, NOT docs/)
Write: "investigations/spikes/SPIKE_{spike_name}_{date}.html"

# 2. Markdown summary (companion)
Write: "investigations/spikes/SPIKE_{spike_name}_{date}.md"
Content:
```markdown
# SPIKE: {spike_name}

**Date**: {date}
**Branch**: {branch}
**Type**: {type}
**Author**: {author}

## Summary
{1-2 paragraph summary}

## Key Findings
- {finding 1}
- {finding 2}
- {finding 3}

## Recommendations
1. {recommendation 1}
2. {recommendation 2}
3. {recommendation 3}

## Visual Report
See interactive HTML report: `SPIKE_{spike_name}_{date}.html`

## Related Documents
- {doc 1}
- {doc 2}
```

# 3. Preview
output: "✅ Report generated: file:///path/to/investigations/spikes/SPIKE_{spike_name}_{date}.html"
```

## Examples

### Example 1: Architecture Spike (RBAC)

```bash
# Command
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

# Output
✅ Generated: investigations/spikes/SPIKE_RBAC_Permissions_2026-02-10.html (1,234 lines)
📝 Summary: investigations/spikes/SPIKE_RBAC_Permissions_2026-02-10.md
📊 Preview: file:///Users/leon/workspace/pbp/platform/investigations/spikes/SPIKE_RBAC_Permissions_2026-02-10.html

Time: 28 minutes (vs 2.5 hours manual)
```

### Example 2: Feature Spike (Payment Gateway Consolidation)

```bash
# Command
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

### Example 3: Performance Spike (N+1 Query Fixes)

```bash
# Command
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

## Customization Options

### Sections Flag

```bash
# Only generate specific sections
/spike-report --sections hierarchy,flow

# Available sections by type:
architecture: hierarchy, flow, inheritance, erd, matrix, gap, packages
feature: current, proposed, flow, migration, risks, testing
performance: metrics, bottlenecks, improvements, benchmarks, comparison
security: threats, flow, mitigations, compliance, audit
```

### Color Schemes

```bash
# Default: blue/indigo gradient
# Can be customized per spike type:

architecture → blue/purple (structure, authority)
feature → green/teal (growth, new)
performance → orange/red (speed, urgency)
security → red/purple (protection, vigilance)
integration → teal/blue (connection, flow)
```

### Output Location

```bash
# Default: investigations/spikes/  (gitignored via .git/info/exclude — NOT docs/)
# Can be customized:
/spike-report --output investigations/proposals/
/spike-report --output tmp/reports/  # For quick drafts
```

## Integration with Other Skills

### With /architect
```bash
# Plan architecture first, then visualize
/architect feature-name
# ... architect provides recommendations ...
/spike-report feature-name architecture
# ... report includes architect's decisions ...
```

### With /opsx:new
```bash
# Create OpenSpec change, then generate report for stakeholders
/opsx:new rbac-redesign
/opsx:ff rbac-redesign
# ... OpenSpec creates artifacts ...
/spike-report rbac-redesign architecture
# ... report complements OpenSpec docs ...
```

### With /code-review
```bash
# Review code, identify issues, then document in spike report
/code-review app/abilities/
# ... code review finds gaps ...
/spike-report --sections gap,migration
# ... report includes code review findings ...
```

## Related Skills

| Skill | Relationship |
|-------|--------------|
| `/architect` | Architect defines structure → spike-report visualizes it |
| `/opsx:new` | OpenSpec creates specs → spike-report creates stakeholder docs |
| `/code-review` | Code review finds issues → spike-report documents solutions |
| `/tdd` | TDD ensures correctness → spike-report documents behavior |
| `/debug` | Debug finds root causes → spike-report documents fix strategy |

## Validation

Success criteria:
- ✅ HTML validates (no syntax errors)
- ✅ SVG renders correctly in Chrome/Firefox/Safari
- ✅ Responsive design works on mobile (375px+)
- ✅ Tabs switch smoothly (JavaScript works)
- ✅ Color contrast meets WCAG 2.1 AA (4.5:1)
- ✅ File size < 2MB (reasonable for email/Slack)
- ✅ Loads in < 2 seconds (no external dependencies beyond Tailwind CDN)

Failure indicators:
- ❌ SVG diagrams don't render (broken gradients, invalid viewBox)
- ❌ Tabs don't work (JavaScript error)
- ❌ Text unreadable (low contrast)
- ❌ Layout breaks on mobile (not responsive)
- ❌ Missing sections (analysis incomplete)

## Tips & Best Practices

### DO ✅
- Start with `/spike-report` (no args) to auto-detect spike type
- Use meaningful emojis for visual scanning (🔐 for security, 💰 for payments)
- Keep SVG diagrams focused (max 15 nodes per diagram)
- Add info boxes to highlight key insights
- Include "Next Steps" checklist for actionable items
- Test in mobile viewport (many stakeholders read on phone)
- Use gradients sparingly (too many = overwhelming)
- Link to related docs (don't duplicate content)

### DON'T ❌
- Don't generate mid-spike (wait until analysis complete)
- Don't hardcode specific IDs/values (use variables)
- Don't create massive diagrams (split into multiple tabs)
- Don't skip accessibility (ARIA labels are critical)
- Don't use custom fonts (stick with system fonts)
- Don't embed large images (SVG only, or external links)
- Don't forget to update markdown summary

## Performance Expectations

| Phase | Time (Skill) | Time (Manual) | Savings |
|-------|--------------|---------------|---------|
| Analyze | 5 min | 30 min | 25 min |
| Research | 3 min | 20 min | 17 min |
| Structure | 2 min | 10 min | 8 min |
| Diagram | 8 min | 60 min | 52 min |
| Content | 10 min | 45 min | 35 min |
| Polish | 2 min | 15 min | 13 min |
| **Total** | **30 min** | **180 min** | **150 min (2.5 hrs)** |

**ROI**: 6x per use (150 min saved / 25 min spent)

## Troubleshooting

### Issue: SVG doesn't render
**Cause**: Invalid viewBox or gradient reference
**Fix**: Check SVG syntax, ensure all gradient IDs exist in `<defs>`

### Issue: Tabs don't switch
**Cause**: JavaScript error or missing onclick handlers
**Fix**: Check browser console, ensure `showTab()` function defined

### Issue: Layout breaks on mobile
**Cause**: Missing responsive classes
**Fix**: Add Tailwind breakpoints (`md:`, `lg:`)

### Issue: Text too small to read
**Cause**: Fixed font sizes don't scale
**Fix**: Use Tailwind responsive text classes (`text-sm md:text-base`)

### Issue: Report takes too long to generate
**Cause**: Too many files analyzed or complex diagrams
**Fix**: Reduce scope with `--sections` flag

## Kaizen: Continuous Improvement

> "Every report teaches us how to make the next one better" - 改善

**While executing this skill**, if you discover:
- Better SVG layout algorithm
- More intuitive diagram type
- Faster analysis pattern
- Accessibility improvement
- New spike type to support

**You MUST**:
1. Complete current report generation
2. Use Edit tool to update this skill.md
3. Format: `<!-- Kaizen: YYYY-MM-DD - [improvement] -->`
4. Document in "Recent Improvements" section below

**Recent Improvements**:

<!-- Kaizen: 2026-02-10 - Initial creation -->
Created `/spike-report` skill from proven pattern:
- Based on 2 real RBAC spike reports (v1: 677 lines, v2: 1,246 lines)
- Automates HTML/CSS/SVG generation (saves 2.5 hours per spike)
- Supports 6 spike types: architecture, feature, performance, security, integration, migration
- Integrates with context7 for best practices
- Expected ROI: 9x (27 hours/year saved vs 3 hours maintenance)

Next improvements needed:
- [ ] Add D3.js integration for more complex interactive diagrams
- [ ] Support Mermaid diagram conversion (markdown → SVG)
- [ ] Add PDF export option (for offline sharing)
- [ ] Create gallery of example reports (investigations/spikes/examples/)
- [ ] Add real-time preview server (live reload during generation)
- [ ] Support custom themes (dark mode, company branding)

---

## Meta: Skill Creation Log

**Created by**: skill-creator agent
**Date**: 2026-02-10
**Triggered by**: User request after creating 2 RBAC spike reports
**Pattern detected**: Manual HTML/SVG/CSS report generation (2-3 hours per spike)
**Score**: 19/20 (Very Strong Candidate)
**ROI estimate**: 9x
**Approval**: User approved immediately

**Implementation notes**:
- Skill generates HTML with embedded SVG (no external dependencies beyond Tailwind CDN)
- Uses context7 for best practices research (SVG, Tailwind, accessibility)
- Supports 6 spike types with customizable sections
- Template-based generation with variable substitution
- Validates output for syntax, accessibility, responsiveness

**Success metrics to track**:
- Time to first report: < 5 minutes
- User satisfaction: Positive feedback on clarity/beauty
- Reuse rate: ≥ 80% of major spikes use this skill
- Maintenance burden: < 3 hours/year for updates
