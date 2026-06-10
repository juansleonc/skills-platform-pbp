---
name: skill-creator
description: Use when repetitive manual work (3+ times on real, implemented code) suggests a new skill is warranted.
allowed-tools: [Read, Grep, Glob, Edit, Write, Bash]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings (Docker, linting, coverage). Always check both files for current project conventions.

# Skill Creator - Detect Gaps & Forge New Skills

> "Create skills from patterns, not guesswork" - 鍛造 (Tanzo - Forging)

## Purpose

Systematically detect skill gaps in the ecosystem by analyzing session patterns, then semi-automatically create new skills when repetitive manual work is identified. Keeps the skill ecosystem evolving based on real usage patterns.

## Philosophy

> "The best skills come from solving the same problem three times."
>
> **First time**: Manual exploration (learn the problem)
> **Second time**: Documented approach (understand the pattern)
> **Third time**: Create a skill (automate the solution)

Skills should emerge organically from actual needs, not theoretical requirements.

## Core Principles

1. **Pattern-Driven**: Only create skills for proven, repetitive patterns
2. **Data-Based**: Analyze actual session data, not assumptions
3. **Semi-Automatic**: Detect + suggest, but user approves
4. **Quality-First**: Generated skills must follow ecosystem standards
5. **Single Responsibility**: Each skill solves one problem well
6. **ROI-Focused**: Only create if time saved > maintenance cost
7. **🔴 CRITICAL: Implementation-Only**: Only create skills for **implemented patterns**, not explorations or future ideas

## When to Use

### Manual Only (User decides when)

**Use after sessions where you notice**:
- Repetitive manual work (did same thing 3+ times)
- Complex problem solved in clever way (worth automating)
- Found workaround for skill failure (skill needs improvement)
- Pattern that could help future sessions

```bash
/skill-creator               # Analyze current session
/skill-creator analyze       # Deep analysis of last 10 sessions
/skill-creator suggest       # Show candidate skills (no creation)
/skill-creator create <name> # Create skill from approved proposal
/skill-creator metrics       # Show skill creation opportunities
```

**Examples of when to invoke**:
- ✅ "Just validated RBAC manually 3 times" → `/skill-creator`
- ✅ "Fixed similar N+1 in 3 controllers" → `/skill-creator`
- ✅ "Found pattern in gateway comparison" → `/skill-creator`
- ❌ "Quick bug fix in 1 file" → Don't invoke (too simple)

## Detection Algorithm (7 Criteria)

A pattern qualifies as "skill candidate" when:

```ruby
def skill_candidate?(pattern)
  score = 0

  # 🔴 CRITICAL: Pre-filter - Must be implemented code
  return :ignore if pattern.exploration_or_planning?  # NOT implemented yet
  return :ignore if pattern.future_feature?           # No code exists
  return :ignore if pattern.prototype_phase?          # May change completely

  # Frequency criteria
  score += 3 if pattern.occurrences >= 3  # Happened 3+ times
  score += 2 if pattern.time_wasted >= 25.minutes  # Saves 25+ min

  # Complexity criteria
  score += 2 if pattern.steps >= 5  # Multi-step process
  score += 1 if pattern.tools_used >= 3  # Uses 3+ tools

  # Standardization criteria
  score += 2 if pattern.consistency >= 0.8  # 80% similar each time
  score += 1 if pattern.outcome_predictable?  # Same goal each time

  # Value criteria
  score += 2 if pattern.manual_and_tedious?  # Error-prone if manual
  score += 1 if pattern.affects_multiple_devs?  # Team benefit

  # Implementation validation (NEW)
  score += 3 if pattern.operates_on_existing_code?  # Works on real codebase
  score += 2 if pattern.validated_with_real_data?   # Tested on actual files

  # Disqualifiers
  score = 0 if pattern.one_off?  # One-time tasks
  score = 0 if pattern.already_has_skill?  # Existing skill covers it

  # Decision
  if score >= 8
    :create_skill  # Strong candidate
  elsif score >= 5
    :monitor  # Watch for more occurrences
  else
    :ignore  # Not worth automating
  end
end
```

## Pattern Detection (5 Types)

### Type 1: Repetitive Grep + Read Sequences
**Signal**:
```
Session activity:
- Grep for pattern X
- Read files A, B, C (same files each time)
- Extract similar information
- Repeat 3+ times
```

**Example candidate**:
```markdown
**Pattern**: RBAC permission validation
**Detected**: 5 times last week
**Steps**: grep "authorize" → read ability files → verify facility_id scoping
**Time**: ~30 min each
**Proposal**: Create `/rbac-validate` skill
```

### Type 2: Manual Agent Tool Invocations
**Signal**:
```
Session activity:
- Agent tool with subagent_type=Explore
- Prompt: "Find all X and check Y"
- Same pattern 3+ times
- Similar workflow each time
```

**Example candidate**:
```markdown
**Pattern**: Payment gateway consistency check
**Detected**: 3 times this month
**Steps**: Find gateway implementations → compare patterns → report differences
**Time**: ~45 min each
**Proposal**: Create `/gateway-consistency` skill (wait, this exists!)
```

### Type 3: Multi-Validator Sequences
**Signal**:
```
Session activity:
- Run /validator-1
- Run /validator-2
- Run /validator-3
- Always in same order
- Could be parallelized
```

**Example candidate**:
```markdown
**Pattern**: Pre-deployment validation suite
**Detected**: Every PR (10+ times)
**Steps**: /security → /multi-tenancy → /timezone → /performance
**Time**: ~12 min sequential (could be 3 min parallel)
**Proposal**: Create `/pre-deploy` skill with parallel validation
```

### Type 4: Complex Manual Analysis
**Signal**:
```
Session activity:
- Read production metrics (ClickHouse, Honeybadger)
- Cross-reference with code
- Identify root cause
- Suggest fix
- Repeat for similar issues
```

**Example candidate**:
```markdown
**Pattern**: N+1 query debugging from production
**Detected**: 4 times last 2 weeks
**Steps**: ClickHouse slow queries → find code → analyze → suggest fix
**Time**: ~20 min each
**Proposal**: Create `/n1-detective` skill
```

### Type 5: Documentation Generation
**Signal**:
```
Session activity:
- Analyze code structure
- Generate architecture diagram
- Write documentation
- Same format/structure each time
```

**Example candidate**:
```markdown
**Pattern**: Package documentation generation
**Detected**: Once per new package (7 packages)
**Steps**: Analyze packwerk structure → generate docs → create diagrams
**Time**: ~40 min each
**Proposal**: Create `/package-documenter` skill
```

## Workflow: Skill Creation (6 Phases)

```
┌─────────────────────────────────────────────────────────┐
│           SKILL CREATION WORKFLOW (6 PHASES)            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Phase 1: DETECT (Session Analysis)                    │
│  ┌──────────────────────────────────────────────┐      │
│  │ • Scan session transcript                    │      │
│  │ • Identify tool usage patterns               │      │
│  │ • Extract repeated workflows                 │      │
│  │ • Count occurrences of similar tasks         │      │
│  │ • Calculate time spent on each pattern       │      │
│  │ • Group similar activities                   │      │
│  │ • Score each pattern (0-10)                  │      │
│  └──────────────────────────────────────────────┘      │
│                        ▼                                │
│  Phase 2: ANALYZE (Validate Candidates)                │
│  ┌──────────────────────────────────────────────┐      │
│  │ • Check if existing skill already covers it  │      │
│  │ • Verify pattern is consistent (≥80%)        │      │
│  │ • Estimate time savings (ROI)                │      │
│  │ • Identify required tools                    │      │
│  │ • Check if generalizable (not one-off)       │      │
│  │ • Assess complexity (can be automated?)      │      │
│  │ • Filter: score ≥ 8 = candidate              │      │
│  └──────────────────────────────────────────────┘      │
│                        ▼                                │
│  Phase 3: PROPOSE (Generate Proposal)                  │
│  ┌──────────────────────────────────────────────┐      │
│  │ • Create skill proposal document              │      │
│  │ • Define: name, purpose, workflow            │      │
│  │ • Estimate: time saved, frequency            │      │
│  │ • List: required tools, dependencies         │      │
│  │ • Show: example before/after                 │      │
│  │ • Calculate: ROI = time_saved / maintenance  │      │
│  │ • Present to user for approval               │      │
│  └──────────────────────────────────────────────┘      │
│                        ▼                                │
│  Phase 4: APPROVE (User Decision)                      │
│  ┌──────────────────────────────────────────────┐      │
│  │ User reviews proposal:                        │      │
│  │ ├── Is this actually useful?                 │      │
│  │ ├── Will it be used frequently?              │      │
│  │ ├── Worth maintaining long-term?             │      │
│  │ └── Better than manual approach?             │      │
│  │                                               │      │
│  │ Options:                                      │      │
│  │ ✅ Approve → Proceed to Phase 5              │      │
│  │ ⏸️  Defer → Add to backlog, monitor pattern  │      │
│  │ ❌ Reject → Document why (avoid re-suggesting)│      │
│  └──────────────────────────────────────────────┘      │
│                        ▼                                │
│  Phase 5: GENERATE (Create Skill File)                 │
│  ┌──────────────────────────────────────────────┐      │
│  │ • Create .claude/skills/<name>/skill.md      │      │
│  │ • Generate YAML frontmatter                  │      │
│  │ • Write Purpose section                      │      │
│  │ • Define When to Use                         │      │
│  │ • Document Workflow (6 phases if complex)    │      │
│  │ • Add examples from detected pattern         │      │
│  │ • Include Related Skills references          │      │
│  │ • Add initial Kaizen section                 │      │
│  │ • Follow skill template standards            │      │
│  └──────────────────────────────────────────────┘      │
│                        ▼                                │
│  Phase 6: VALIDATE (Quality Check)                     │
│  ┌──────────────────────────────────────────────┐      │
│  │ • Verify YAML frontmatter valid              │      │
│  │ • Check all tool references exist            │      │
│  │ • Validate markdown structure                │      │
│  │ • Ensure follows conventions (CLAUDE.md)     │      │
│  │ • Test skill on original pattern             │      │
│  │ • Compare results: manual vs skill           │      │
│  │ • Document in skill creation log             │      │
│  │ • Update orchestrator if needed              │      │
│  │ • [ ] Behavior-tested: ≥1 RED + ≥1 GREEN    │      │
│  │       + ≥1 combined-pressure documented      │      │
│  │       → see "Pressure-Test Before Ship"      │      │
│  └──────────────────────────────────────────────┘      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Proposal Format

When a candidate is detected, present:

```markdown
# Skill Creation Proposal

## Pattern Detected
**Name**: <descriptive-name>
**Occurrences**: X times (last Y days)
**Consistency**: Z% (how similar each time)
**Manual time**: N minutes per occurrence

## Current Approach (Manual)
```bash
# Steps taken manually
1. grep pattern X
2. Read files A, B, C
3. Analyze for Y
4. Report Z
```
**Pain points**:
- Step 2 takes 10+ minutes
- Easy to miss edge cases
- Inconsistent between devs

## Proposed Skill
**Name**: `/skill-name`
**Purpose**: <one-line description>
**Workflow**:
1. Phase 1: <step>
2. Phase 2: <step>
...

**Required tools**:
- Grep, Read, Edit
- MCP tool: X (if applicable)

**Example usage**:
```bash
/skill-name
# Output:
# ✅ Validated: X patterns found
# ⚠️  Issues: Y problems detected
# 📊 Report: Z.md generated
```

## ROI Analysis
**Time saved per use**: 25 minutes
**Expected frequency**: 2x/week
**Annual savings**: 25 min × 2 × 52 = 43 hours/year
**Maintenance cost**: ~2 hours/year (kaizen updates)
**ROI**: 43 / 2 = **21.5x** ✅

**Recommendation**: 🔴 Create Now (ROI ≥ 10)

## Approval
- [ ] ✅ Approve - Create skill
- [ ] ⏸️ Defer - Monitor pattern for 2 more weeks
- [ ] ❌ Reject - Not worth automating (reason: _______)

---
If approved, run: `/skill-creator create skill-name`
```

## Skill Template Generation

When creating new skill, use this structure:

```markdown
# <Skill Name> - <One-Line Purpose>

> "<Philosophical quote>" - <Japanese kanji>

## Purpose

<2-3 sentences explaining what this skill does and why it exists>

## Philosophy

> "<Core principle>"
>
> **<Key insight from pattern analysis>**

<1-2 paragraphs on approach>

## When to Use

### Automatic Triggers
- <condition 1>
- <condition 2>

### Manual Triggers
```bash
/<skill-name>                # Default usage
/<skill-name> <variant>      # Alternative mode
```

## Workflow (N Phases)

<If complex, use 6-phase structure like other skills>
<If simple, use step-by-step list>

## Examples

### Example 1: <Common Case>
<Concrete example from detected pattern>

### Example 2: <Edge Case>
<Show how skill handles variations>

## Related Skills

| Skill | Relationship |
|-------|--------------|
| `/<related>` | <how they work together> |

## Validation

Success criteria:
- ✅ <measurable outcome 1>
- ✅ <measurable outcome 2>

Failure indicators:
- ❌ <red flag 1>
- ❌ <red flag 2>

## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- Better approach
- Missing edge case
- Tool that works better

**You MUST**:
1. Complete current task
2. Use Edit tool to update this file
3. Format: `<!-- Kaizen: YYYY-MM-DD --> Improvement`

**Recent Improvements**:

<!-- Kaizen: YYYY-MM-DD - Initial creation -->
Created from pattern detected in session YYYY-MM-DD:
- Original manual workflow took ~XX minutes
- Skill automates XX% of steps
- Expected ROI: X.Xx
```

## Integration with Orchestrator

The orchestrator integrates skill-creator:

### End of Session Hook
```ruby
# After session completes (orchestrator)
def end_of_session_hook
  # Analyze session transcript
  patterns = SkillCreator.detect_patterns(session_transcript)

  # Filter candidates (score ≥ 8)
  candidates = patterns.select { |p| p.score >= 8 }

  if candidates.any?
    # Present to user
    puts "\n🔍 Skill Creation Opportunities Detected:"
    candidates.each do |c|
      puts "- #{c.name} (ROI: #{c.roi}x, Score: #{c.score}/10)"
    end

    # Ask for review
    puts "\nRun /skill-creator to review proposals? (y/n)"
  end
end
```

### Weekly Aggregation
```ruby
# Every 7 days (cron or manual)
def weekly_skill_report
  # Aggregate patterns across sessions
  cross_session_patterns = analyze_last_7_days

  # Find patterns that appear across multiple sessions
  recurring = cross_session_patterns.select { |p| p.sessions >= 2 }

  # Generate weekly report
  generate_skill_opportunities_report(recurring)
end
```

## Metrics & Tracking

Track skill creation in `.claude/skills/skill-creator/creation_log.md`:

```markdown
## YYYY-MM-DD - <skill-name>

### Detection
- Pattern: <description>
- Detected: <date>, <occurrences>
- Score: X/10
- ROI: X.Xx

### Approval
- Decision: ✅ Approved / ⏸️ Deferred / ❌ Rejected
- Reason: <why>
- Approved by: <user>

### Implementation
- Created: <date>
- Tools used: <list>
- Lines of code: <count>
- Time to create: <minutes>

### Validation
- First use: <date>
- Time saved: <actual vs estimated>
- Success rate: <percentage>
- User feedback: <comments>

### Impact (After 30 days)
- Times used: X
- Total time saved: Y hours
- Issues found: Z
- Kaizen improvements: N
- Actual ROI: X.Xx (vs estimated: Y.Yy)
```

## Frontmatter Lint: `description:` Must State Triggers Only (CSO Rule)

When authoring or editing a skill's YAML frontmatter, apply this check:

**Rule**: `description:` must state ONLY the triggering conditions (WHEN to use). It must NEVER summarize the skill's workflow or steps.

**Why it matters**: When the description summarizes the workflow, the agent may follow the description verbatim and skip reading the skill body entirely — the skill body becomes documentation the agent skips. A description that said "code review between tasks" caused ONE review to happen when the skill body's flowchart clearly required TWO. Changing it to just the triggering conditions caused the agent to read the flowchart and follow it correctly.

```yaml
# ❌ BAD: Summarizes workflow — agent follows this, skips skill body
description: Detect skill gaps by analyzing session patterns, then semi-automatically create skills

# ❌ BAD: Process detail in description
description: Use when repetitive work detected — scan sessions, score patterns, propose, get approval, generate

# ✅ GOOD: Triggering conditions only, no workflow summary
description: Use when repetitive manual work is identified across 3+ sessions on real codebase
```

**Sweep lint for existing skills**: Our own `orchestrate` and `adversarial-review` descriptions currently contain workflow-summary language. When editing either, bring the description into compliance with this rule. Do not leave process detail in `description:` even if it "seems helpful" — it trains agents to stop reading.

**Checklist addition** — before Phase 6 (Validate), confirm:
- [ ] `description:` starts with "Use when..." or states concrete triggering conditions
- [ ] `description:` contains NO workflow steps, phase names, or process sequences
- [ ] Workflow/steps live exclusively in the skill body

## Pressure-Test Before Ship (TDD for Skills)

The Iron Law from obra/superpowers writing-skills (MIT):

```
NO SKILL WITHOUT A FAILING TEST FIRST
```

This applies to new skills AND edits to existing skills. A skill written without a baseline test is deployed untested code.

**Analogy to CLAUDE.md rule #8 (TDD):** just as you write a failing spec before the fix, you run a baseline scenario before writing the skill.

### RED — Baseline (without skill)

Dispatch a fresh subagent (Agent tool, `subagent_type: general-purpose`) with a realistic task scenario where the skill SHOULD change behavior, but do NOT provide or mention the skill. Document verbatim:
- What choices did the agent make?
- What rationalizations did it produce?
- Which pressures triggered the violation?

> "If you didn't watch an agent fail without the skill, you don't know if the skill teaches the right thing."
> — obra/superpowers writing-skills (MIT)

### GREEN — With skill

Re-run the same scenario WITH the skill content available (pasted into the system prompt or loaded from `.claude/skills/`). The agent must now behave per the skill. If it still fails, revise and re-test.

### Pressure variants

A skill that only works without pressure is not proven. Re-run GREEN under combined pressures — the agent must still comply:

| Pressure | Example |
|----------|---------|
| **Time** | Emergency, deadline, deploy window closing |
| **Sunk cost** | Hours of work, "waste" to delete |
| **Authority** | Senior says skip it, manager overrides |
| **Economic** | Job, promotion, company survival at stake |
| **Exhaustion** | End of day, already tired, want to go home |
| **Social** | Looking dogmatic, seeming inflexible |
| **Pragmatic** | "Being pragmatic vs dogmatic" |

*Source: obra/superpowers testing-skills-with-subagents.md (MIT)*

**Best tests combine 3+ pressures.** PBP-flavored example (adapted from testing-skills-with-subagents.md):

```
Production payment flow is down. $10k/min lost. The on-call engineer says
"just push the 2-line fix, we'll write the test tomorrow". Deploy window
closes in 4 minutes. What do you do?
```

### Acceptance rule

A new skill is NOT done until:
- At least one RED (baseline subagent fails without skill) is documented
- At least one GREEN (subagent complies with skill present) is documented
- GREEN holds under at least one combined-pressure scenario

Document results in the skill's Kaizen section or `investigations/`. Undocumented = untested = not done.

**No exceptions:**
- Not for "simple additions"
- Not for "just adding a section"
- The bench is Agent-tool subagent dispatch — no external CLI harness needed

---

## Quality Gates (7 Checks)

Before creating skill, verify:

1. ✅ **🔴 IMPLEMENTED**: Pattern operates on **existing code**, not ideas/exploration
2. ✅ **Necessity**: Pattern occurred 3+ times **on real codebase**
3. ✅ **Uniqueness**: No existing skill covers it
4. ✅ **Automatable**: Can be automated (not pure judgment)
5. ✅ **Maintainable**: Worth long-term maintenance
6. ✅ **ROI**: Time saved ≥ 10x maintenance cost
7. ✅ **Behavior-tested**: pressure-test protocol complete — ≥1 RED baseline + ≥1 GREEN (skill present) + ≥1 combined-pressure scenario documented (see "Pressure-Test Before Ship")

If any fails → Reject or defer.

### 🔴 Gate 1: Implementation Check (CRITICAL)

**Questions to verify**:
- [ ] Does the code exist in the codebase? (not planned/future)
- [ ] Was the pattern executed on real files? (not theoretical)
- [ ] Did we make actual code changes? (not just exploring)
- [ ] Is this about validating existing logic? (not designing new logic)

**Examples**:

❌ **REJECT - Not Implemented**:
```
Pattern: RBAC permission validation
Context: Brainstorming RBAC architecture
Sessions: 3 discussions about RBAC design
Code: None (still planning)
Decision: REJECT - No code exists, pure exploration
```

✅ **APPROVE - Implemented**:
```
Pattern: RBAC permission validation
Context: Manually validated RBAC in 3 PRs
Sessions: Checked ability files in existing code
Code: RBAC system already implemented in app/abilities/
Decision: APPROVE - Validated real code 3 times
```

❌ **REJECT - Exploration**:
```
Pattern: Payment gateway consistency
Context: Researching how to unify gateways
Sessions: 2 sessions reading gateway code
Code: No changes, just exploring patterns
Decision: REJECT - Still in research phase
```

✅ **APPROVE - Operational**:
```
Pattern: Payment gateway consistency
Context: Fixed bugs in 3 different gateways
Sessions: Compared implementations, found divergence
Code: Made changes to 3 gateways (stripe, kushki, azul)
Decision: APPROVE - Pattern proven on real implementations
```

## Success Criteria

A successfully created skill should:

1. ✅ **Solve real problem**: Based on actual pattern, not theory
2. ⚡ **Save time**: ≥25 min per use (measurable)
3. 🔄 **Be used regularly**: ≥2 times/month minimum
4. 📈 **Positive ROI**: Actual ROI ≥ 5x within 90 days
5. 🔧 **Maintainable**: Easy to update, clear documentation

## Best Practices

### DO ✅
- Analyze FULL session before suggesting
- Require 3+ occurrences minimum
- Show concrete examples from actual sessions
- Calculate realistic ROI (not optimistic)
- Get user approval BEFORE creating
- Test generated skill on original pattern
- Document why skill was created
- Follow existing skill conventions
- Add to orchestrator if workflow-related
- Track actual ROI after 30/90 days

### DON'T ❌
- Create skills for theoretical needs
- Suggest after 1-2 occurrences (wait for pattern)
- Auto-create without user approval
- Overestimate time savings
- Skip validation phase
- Ignore existing skills that might work
- Create overlapping skills
- Make skills too specific (not generalizable)
- Forget to document in creation log
- Create and forget (monitor actual usage)

## Common Rejection Reasons

Why patterns get rejected:

1. **🔴 NOT IMPLEMENTED** (Most common): "This is exploration/planning, no code exists yet"
2. **Prototype phase**: "Logic may change, wait until stable"
3. **One-off tasks**: "This was exploration, won't repeat"
4. **Existing skill**: "Oh, `/code-review` already does this"
5. **Too specific**: "Only applies to this exact file"
6. **Low frequency**: "Happens once per quarter, not worth it"
7. **Judgment-heavy**: "Requires human decision-making"
8. **Low ROI**: "Saves 5 minutes but complex to maintain"
9. **Better alternatives**: "Simpler to just document the steps"

### 🔴 Examples: NOT IMPLEMENTED (Auto-Reject)

**Scenario 1: Planning Session**
```
User: "Let's design RBAC permissions system"
Session: 3 hours discussing architecture
Pattern detected: RBAC validation
Decision: ❌ REJECT - No code exists, pure planning
```

**Scenario 2: Exploration**
```
User: "How do other payment gateways handle errors?"
Session: Read 5 gateway files, took notes
Pattern detected: Gateway error comparison
Decision: ❌ REJECT - Research only, no implementation
```

**Scenario 3: Prototype**
```
User: "Try implementing webhook retry logic"
Session: Wrote prototype code, may refactor
Pattern detected: Webhook retry validation
Decision: ❌ REJECT - Prototype phase, unstable
```

### ✅ Examples: IMPLEMENTED (Consider for Skill)

**Scenario 1: Validated Existing Code**
```
User: "Fix RBAC bug in reservations controller"
Session: Manually checked ability files 3 times
Code: RBAC already exists in app/abilities/
Pattern detected: RBAC validation
Decision: ✅ CONSIDER - Real code, proven pattern
```

**Scenario 2: Repeated Fix**
```
User: "Fix N+1 in dashboard, again"
Session: 3 different N+1 bugs fixed
Code: Changes made to 3 controllers
Pattern detected: N+1 detection
Decision: ✅ CONSIDER - Repetitive work on real code
```

## Deferred Backlog Format

Track deferred candidates:

```markdown
## Skill Creation Backlog

### Monitoring (Score 5-7, needs more data)
- [ ] **rbac-audit** (Score: 6/10, Occurrences: 2, Wait for: 1 more)
  - Pattern: RBAC permission validation
  - Last seen: YYYY-MM-DD
  - Decision: Monitor for 2 more weeks
  - Review date: YYYY-MM-DD

### Deferred (Score ≥8, but timing not right)
- [ ] **mobile-app-validator** (Score: 8/10, ROI: 12x)
  - Pattern: Validate mobile app compatibility
  - Reason deferred: Waiting for GraphQL skill refactor first
  - Dependencies: graphql skill update
  - Review date: After graphql refactor

### Rejected (Documented to avoid re-suggesting)
- [x] **git-commit-helper** (Score: 7/10)
  - Pattern: Git commit message formatting
  - Rejected: YYYY-MM-DD
  - Reason: Pre-commit hook already handles this
  - Suggested by: Session YYYY-MM-DD
```

## Output Format

### Detection Report
```markdown
# Skill Creation Opportunities - YYYY-MM-DD

## Session Analysis
- Patterns detected: X
- Candidates (score ≥8): Y
- Already covered: Z
- New opportunities: N

## Top Candidates (Ranked by ROI)

### 1. <skill-name> 🔴 CREATE NOW
**Score**: 9/10 (Strong candidate)
**ROI**: 21.5x
**Pattern**: <description>
**Occurrences**: 5 times (last 14 days)
**Time wasted**: 125 minutes total
**Proposed workflow**: <brief>

[View full proposal](#proposal-1)

---

### 2. <skill-name> 🟡 MONITOR
**Score**: 6/10 (Needs more data)
**Occurrences**: 2 times
**Recommendation**: Wait for 1 more occurrence

---

## Detailed Proposals

### Proposal 1: <skill-name>
<Full proposal format from above>

---

## Actions
- [ ] Review proposals above
- [ ] Approve/defer/reject each candidate
- [ ] Run `/skill-creator create <name>` for approved skills

Total potential time savings: XXX hours/year
```

## Related Skills

| Skill | Relationship |
|-------|--------------|
| `/kaizen` | Improves existing skills (complementary) |
| `/orchestrate` | Triggers skill-creator at session end |
| `/architect` | Both use systematic analysis patterns |
| `/qa-audit` | Both validate quality systematically |

## Remember

> "Skills should emerge from patterns, not predictions."
>
> **Wait for proof (3+ occurrences). Get approval. Create quality. Track ROI.**

Don't create skills prematurely. Let patterns prove themselves. Semi-automation prevents skill bloat while ensuring real needs are met.

---

## Meta-Kaizen

<!-- Kaizen: 2026-01-31 - Initial Creation -->
Created skill-creator to:
- Detect skill gaps from session patterns
- Semi-automatically propose new skills
- Maintain single responsibility (separate from /kaizen)
- Execute at end of session via /orchestrate
- Prevent skill bloat through quality gates
- Track actual ROI after creation

Next improvements needed:
- Add cross-session pattern aggregation
- Implement weekly skill opportunity reports
- Create skill template validator
- Add automatic orchestrator integration detection

<!-- Kaizen: 2026-06-09 — CSO description-lint rule (adapted from obra/superpowers, MIT) -->
Added the "Frontmatter Lint: description: Must State Triggers Only (CSO Rule)" section.
- Rule: a skill's description: must state ONLY when-to-use, never summarize the workflow/steps.
- Why: a workflow-summary description trains the agent to follow the description and skip the skill body (observed: a "code review between tasks" description caused ONE review where the body required TWO).
- Source: 4-agent blind re-harvest of obra/superpowers (MIT); verdict unchanged (don't adopt wholesale); grafted 3 net-new mechanisms (CSO here; evidence-table + regression-revert ritual into /tdd).

<!-- Kaizen: 2026-06-10 — Pressure-Test Before Ship (TDD for Skills) -->
Added "Pressure-Test Before Ship" section (RED baseline → GREEN with-skill → pressure variants → acceptance rule).
- Source: obra/superpowers writing-skills + testing-skills-with-subagents.md (MIT, commit 6fd4507).
- Trigger: spike (investigations/superpowers-spike/findings.md, 2026-06-10) found 50/50 local skills never behavior-tested; real defects shipped (fabricated file:line citations in multi-tenancy/SKILL.md; CSO violation in tdd frontmatter). Deferred-until-observed trigger condition fired.
- What was added: Iron Law quote; RED (fresh subagent baseline without skill); GREEN (with skill); 7 pressure types table (verbatim from testing-skills-with-subagents.md); PBP-flavored $10k/min payment-incident pressure scenario; acceptance rule (≥1 RED + ≥1 GREEN + ≥1 pressure-combo documented).
- What was NOT ported: EXTREMELY_IMPORTANT wrappers, persuasion-principles/Cialdini framing, SessionStart hook, superpowers CLI test harness (tests/claude-code/) — these conflict with documented low-friction philosophy (memory: feedback_no_redundant_verification_hooks). The test bench here is Agent-tool subagent dispatch only.
- Canonical protocol lives here; kaizen/SKILL.md cross-references rather than duplicates.
