# Phase Details — Actions & Scaffolds

Per-phase scaffolds. The body lists each phase as a 1-2 line goal + pointer here.

- [Phase 1: ANALYZE](#phase-1-analyze-code-discovery)
- [Phase 2: RESEARCH](#phase-2-research-best-practices)
- [Phase 3: STRUCTURE](#phase-3-structure-content-planning)
- [Phase 4: DIAGRAM](#phase-4-diagram-svg-generation)
- [Phase 5: CONTENT](#phase-5-content-html-generation)
- [Phase 6: POLISH](#phase-6-polish-review--save)

> Phase 5 (CONTENT) scaffold lives in [`templates/report.html`](../templates/report.html); SVG building blocks in [`templates/svg-components.svg`](../templates/svg-components.svg).

---

## Phase 1: ANALYZE (Code Discovery)

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

## Phase 2: RESEARCH (Best Practices)

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

## Phase 3: STRUCTURE (Content Planning)

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

# User can override the section set per the Invocation reference in the body.
```

## Phase 4: DIAGRAM (SVG Generation)

**Goal**: Create beautiful, interactive SVG diagrams.

**SVG Components**: full snippet templates in [`templates/svg-components.svg`](../templates/svg-components.svg)
— gradient `<defs>` (7 color gradients + drop-shadow filter), node rect+text, connection
lines with arrowheads, flowchart diamonds, and ERD table groups. Compose these building
blocks inline inside the final `<svg>` output.

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

## Phase 5: CONTENT (HTML Generation)

**Goal**: Create the full HTML report with Tailwind CSS.

Full HTML report template: [`templates/report.html`](../templates/report.html) — complete page
skeleton with Tailwind CDN, tab navigation (`showTab` JS), per-section diagram containers, three
info-box variants (warnings/gaps/new-features), and the "Next Steps" two-column footer. Replace
all `{placeholder}` tokens with spike-specific values when generating the output file.

## Phase 6: POLISH (Review & Save)

**Goal**: Validate quality and save files.

**Quality Checks**:

```bash
# 1. Validate HTML — unclosed tags, malformed attributes,
#    missing required elements (<!DOCTYPE>, <meta charset>)
# 2. Validate CSS — invalid Tailwind classes, conflicting styles,
#    missing responsive breakpoints
# 3. Validate SVG — invalid viewBox, gradient references exist,
#    text doesn't overflow rect bounds
# 4. Accessibility — ARIA labels on diagrams, alt text, color
#    contrast (4.5:1 minimum), keyboard navigation (tab order)
# 5. Responsive design — test viewports: mobile 375px, tablet 768px, desktop 1280px
```

**Save Files**:

```bash
# 0. Ensure output directory exists (created lazily — not committed)
mkdir -p investigations/spikes

# 1. HTML report (gitignored via .git/info/exclude — personal artifact, NOT docs/)
Write: "investigations/spikes/SPIKE_{spike_name}_{date}.html"

# 2. Markdown summary (companion)
Write: "investigations/spikes/SPIKE_{spike_name}_{date}.md"
```

Markdown summary content scaffold:
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

```bash
# 3. Preview
output: "✅ Report generated: file:///path/to/investigations/spikes/SPIKE_{spike_name}_{date}.html"
```
