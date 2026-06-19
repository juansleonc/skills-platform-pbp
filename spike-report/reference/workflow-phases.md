# Workflow — 6 Phases (full diagram)

Total time: ~30 minutes (vs 2-3 hours manual). Body keeps a 6-bullet summary; this is the full ASCII workflow box.

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
