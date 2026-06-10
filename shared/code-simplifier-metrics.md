# Code Simplifier Metrics & Impact Tracking

> **📊 Framework for measuring code-simplifier effectiveness across the skills ecosystem**

## Purpose

This document defines how to track and measure the impact of code-simplifier integration across all skills, enabling data-driven decisions about optimization strategies.

## Metrics Categories (3 Categories)

### 1. Adoption Metrics (Usage)
Track how often code-simplifier is used across skills.

### 2. Performance Metrics (Speed)
Measure time savings from optimizations.

### 3. Quality Metrics (Effectiveness)
Evaluate optimization accuracy and value.

---

## 1. Adoption Metrics

### Tier 1 (ALWAYS) - Expected: 100% Usage

**Skills**: `/tdd`, `/coverage`

**Metrics to Track**:
```markdown
| Metric | How to Measure | Target |
|--------|----------------|--------|
| Execution rate | # of times skill runs with code-simplifier / # total skill runs | 100% |
| Files optimized | Total test files optimized per week | Baseline TBD |
| User awareness | Developers know optimization happens automatically | Survey |
```

**Tracking Method**:
```bash
# Count skill executions (manual tracking for now)
grep -r "code-simplifier" /tmp/claude/session-logs/*.md | grep "tdd\|coverage" | wc -l
```

**Baseline (Week 1)**:
- `/tdd` executions: TBD
- `/coverage` executions: TBD
- Total files optimized: TBD

---

### Tier 2 (MANDATORY) - Expected: 100% Inclusion

**Skills**: `/code-review`, `/performance`

**Metrics to Track**:
```markdown
| Metric | How to Measure | Target |
|--------|----------------|--------|
| Inclusion rate | # reviews with code-simplifier / # total reviews | 100% |
| Issues found | Avg issues detected per code-simplifier run | Baseline TBD |
| User satisfaction | Developers find suggestions valuable | Survey |
```

**Tracking Method**:
```bash
# Count code-review sessions
grep -r "Step 10.*code-simplifier" /tmp/claude/session-logs/*.md | wc -l

# Count performance sessions
grep -r "Step 9.*code-simplifier" /tmp/claude/session-logs/*.md | wc -l
```

**Baseline (Week 1)**:
- `/code-review` with code-simplifier: TBD
- `/performance` with code-simplifier: TBD

---

### Tier 3 (OPTIONAL) - Expected: 30-70% Acceptance

**Skills**: `/factory-check`

**Metrics to Track**:
```markdown
| Metric | How to Measure | Target |
|--------|----------------|--------|
| Acceptance rate | # times user chooses code-simplifier / # total offers | 50% |
| User reasoning | Why users choose AI vs FactoryChecker | Survey |
| Spec complexity | Correlation between complexity and AI choice | Analysis |
```

**Tracking Method**:
```bash
# Count offers
grep -r "Apply optimizations with code-simplifier?" /tmp/claude/session-logs/*.md | wc -l

# Count acceptances
grep -r "yes.*code-simplifier" /tmp/claude/session-logs/*.md | wc -l
```

**Baseline (Week 1)**:
- Offers made: TBD
- Acceptances: TBD
- Acceptance rate: TBD

---

## 2. Performance Metrics

### Test Suite Speed (Primary KPI)

**Hypothesis**: code-simplifier optimizations make test suites 30-50% faster.

**Metrics**:
```markdown
| Metric | How to Measure | Target |
|--------|----------------|--------|
| Suite time (before) | Baseline test suite duration | Record once |
| Suite time (after) | Test suite duration after optimizations | -30% minimum |
| Time per optimization | Time saved per factory swap (create → build) | 50-100ms |
| CI time reduction | Total CI time reduction per day | -20% minimum |
```

**Tracking Method**:

#### Before Optimization
```bash
# Run suite and record time
time bin/d rspec --tag ~system

# Example output:
# Finished in 25 minutes 30 seconds
# 1500 examples, 0 failures
```

#### After Optimization
```bash
# Run same suite
time bin/d rspec --tag ~system

# Example output:
# Finished in 17 minutes 45 seconds (30% faster!)
# 1500 examples, 0 failures
```

**Impact Calculation**:
```ruby
before_time = 25.5 # minutes
after_time = 17.75 # minutes
improvement = ((before_time - after_time) / before_time) * 100
# => 30.4% faster

time_saved_per_run = before_time - after_time
# => 7.75 minutes

runs_per_day = 50 # team of 10
total_saved_per_day = time_saved_per_run * runs_per_day
# => 387.5 minutes = 6.5 hours/day
```

---

### Individual File Speed

**Track time savings per optimized file**:

```bash
# Before optimization
time bin/d rspec spec/models/user_spec.rb
# Finished in 5.2 seconds

# After code-simplifier optimization
time bin/d rspec spec/models/user_spec.rb
# Finished in 2.8 seconds (46% faster)

# Time saved: 2.4 seconds per run
```

**Create tracking log**:
```markdown
## Performance Log

| File | Before (s) | After (s) | Improvement (%) | Optimizations Applied |
|------|------------|-----------|-----------------|----------------------|
| spec/models/user_spec.rb | 5.2 | 2.8 | 46% | 8 create → build |
| spec/services/payment_spec.rb | 12.5 | 4.3 | 66% | 15 create → build, 2 facility :skip_callbacks |
| spec/controllers/reservations_spec.rb | 8.1 | 5.2 | 36% | 5 create → build_stubbed |

**Total**: 25.8s → 12.3s (52% faster)
```

---

### CI Performance

**Track CI impact over time**:

```markdown
## CI Performance Tracking

| Week | Avg CI Duration | Change from Baseline | Files Optimized |
|------|-----------------|---------------------|-----------------|
| Week 0 (Baseline) | 28 min | - | 0 |
| Week 1 | 26 min | -7% | 50 |
| Week 2 | 24 min | -14% | 120 |
| Week 3 | 22 min | -21% | 180 |
| Week 4 | 20 min | -29% | 250 |

**Target**: <20 minutes by Week 6
```

---

## 3. Quality Metrics

### Optimization Accuracy

**Track how often code-simplifier suggestions are correct**:

```markdown
| Metric | How to Measure | Target |
|--------|----------------|--------|
| Correct optimizations | Suggestions that pass tests / Total suggestions | >95% |
| False positives | Suggestions that break tests / Total suggestions | <5% |
| Missed opportunities | Manual fixes needed after code-simplifier / Files reviewed | <10% |
```

**Tracking Method**:

After code-simplifier optimizes a file:
```bash
# Run tests
bin/d rspec spec/optimized_file_spec.rb

# If tests pass → Correct optimization ✅
# If tests fail → False positive ❌ (log and analyze)
```

**Create quality log**:
```markdown
## Quality Log

| Date | File | Tests Pass? | Issues | Notes |
|------|------|-------------|--------|-------|
| 2026-01-31 | user_spec.rb | ✅ | None | Perfect optimization |
| 2026-02-01 | payment_spec.rb | ❌ | 2 failures | create→build broke scope test (needs create) |
| 2026-02-01 | payment_spec.rb | ✅ | None | Reverted 2 suggestions, rest correct |

**Accuracy**: 98% (49/50 suggestions correct)
```

---

### Issue Detection Rate

**Track how many issues code-simplifier catches**:

```markdown
| Issue Type | Count | Examples |
|------------|-------|----------|
| Slow factories (create → build) | 250 | Most common |
| Missing build_stubbed | 45 | When id needed but not persisted |
| Redundant setup | 30 | Duplicate let blocks |
| Context consolidation | 15 | Similar contexts merged |
| let vs let! | 20 | Improper usage |

**Total Issues**: 360
**Avg per file**: 7.2 issues
```

---

### User Satisfaction

**Survey questions** (run monthly):

```markdown
## Code Simplifier Satisfaction Survey

1. **Awareness** (Tier 1)
   - [ ] I know code-simplifier runs automatically in /tdd and /coverage
   - [ ] I was surprised when my code changed automatically
   - [ ] I understand why optimizations happen

2. **Value** (All Tiers)
   - Rate 1-5: How valuable are code-simplifier suggestions?
   - Rate 1-5: How much time does code-simplifier save you?
   - Rate 1-5: Would you want code-simplifier in more skills?

3. **Accuracy** (All Tiers)
   - How often do you need to revert code-simplifier changes?
     - [ ] Never (0%)
     - [ ] Rarely (<10%)
     - [ ] Sometimes (10-30%)
     - [ ] Often (>30%)

4. **Choice** (Tier 3)
   - When /factory-check asks, which do you choose more often?
     - [ ] code-simplifier (comprehensive, slower)
     - [ ] FactoryChecker (fast, focused)
     - [ ] Depends on complexity
```

**Target Scores**:
- Value: >4.0/5.0
- Time savings: >4.0/5.0
- Want in more skills: >3.5/5.0
- Revert rate: <10%

---

## Tracking Dashboard (Conceptual)

### Weekly Summary

```markdown
## Code Simplifier Impact - Week of 2026-02-03

### Adoption
- **Tier 1** (ALWAYS): 145 files optimized
  - /tdd: 95 files
  - /coverage: 50 files
  - Execution rate: 100% ✅

- **Tier 2** (MANDATORY): 25 sessions
  - /code-review: 15 sessions
  - /performance: 10 sessions
  - Inclusion rate: 100% ✅

- **Tier 3** (OPTIONAL): 12 offers, 7 acceptances
  - Acceptance rate: 58% (target: 50%) ✅

### Performance
- **Test Suite**: 28 min → 22 min (-21%)
- **CI Runs**: 350 runs/week
- **Time Saved**: 35 hours team-wide this week
- **Cost Savings**: $3,500 (@ $100/hour)

### Quality
- **Accuracy**: 97% (340/350 suggestions correct)
- **Issues Found**: 2,450 total
  - Factory optimizations: 1,800
  - Setup improvements: 350
  - Context consolidation: 200
  - let/let! fixes: 100
- **Avg per file**: 7.0 issues

### Satisfaction (Last survey: 2026-02-01)
- Value: 4.3/5.0 ✅
- Time savings: 4.5/5.0 ✅
- Want more: 4.1/5.0 ✅
- Revert rate: 8% ✅
```

---

## Data Collection Methods

### Manual Tracking (Current)

**Create tracking log file**: `/tmp/claude/code-simplifier-metrics.md`

```bash
# After each code-simplifier session, log:
echo "$(date +%Y-%m-%d) | /tdd | user_spec.rb | 8 optimizations | 5.2s → 2.8s" >> /tmp/claude/code-simplifier-metrics.md
```

**Weekly aggregation**:
```bash
# Count this week's optimizations
grep "$(date +%Y-%m)" /tmp/claude/code-simplifier-metrics.md | wc -l
```

---

### Automated Tracking (Future)

**Proposed: code-simplifier could log to file automatically**

```ruby
# Hypothetical: After code-simplifier runs
File.append('/tmp/claude/code-simplifier-metrics.csv',
  "#{Time.now},#{skill_name},#{file_path},#{optimizations_count},#{before_time},#{after_time}\n"
)
```

**Analysis script**:
```bash
# Calculate total time saved this month
awk -F',' '{sum += ($6 - $5)} END {print sum " seconds saved"}' /tmp/claude/code-simplifier-metrics.csv
```

---

## Benchmark Targets (6-Week Plan)

### Week 1-2: Baseline
- ✅ Integrate code-simplifier into all 5 skills
- ✅ Create metrics framework
- ⏳ Collect baseline performance data
- ⏳ Run initial satisfaction survey

### Week 3-4: Optimization
- ⏳ Optimize 200+ test files
- ⏳ Target: 20% CI time reduction
- ⏳ Track accuracy and false positives
- ⏳ Refine prompts based on feedback

### Week 5-6: Validation
- ⏳ Target: 30% CI time reduction
- ⏳ 500+ files optimized
- ⏳ User satisfaction >4.0/5.0
- ⏳ Accuracy >95%
- ⏳ Decide: Expand to more skills?

---

## Success Criteria

### Must Achieve (Critical)
- ✅ All 5 skills integrated with code-simplifier
- ⏳ CI time reduced by >20% (baseline: 28 min → target: <22 min)
- ⏳ Accuracy >95% (suggestions don't break tests)
- ⏳ User satisfaction >4.0/5.0

### Should Achieve (Important)
- ⏳ 300+ files optimized in first month
- ⏳ Team-wide time savings >50 hours/month
- ⏳ Tier 3 acceptance rate 40-60%
- ⏳ Revert rate <10%

### Could Achieve (Aspirational)
- ⏳ CI time reduced by >30%
- ⏳ User satisfaction >4.5/5.0
- ⏳ Accuracy >98%
- ⏳ 500+ files optimized in first month
- ⏳ Expand to 3 more skills

---

## Red Flags (When to Pause/Adjust)

### Stop Using code-simplifier if:
- ❌ Accuracy <85% (too many false positives)
- ❌ User satisfaction <3.0/5.0 (not valuable)
- ❌ Revert rate >25% (suggestions wrong too often)
- ❌ No measurable CI time improvement after 4 weeks

### Adjust Strategy if:
- ⚠️ Tier 1 execution rate <90% (integration broken?)
- ⚠️ Tier 3 acceptance rate <20% (users prefer FactoryChecker - why?)
- ⚠️ CI time improvement <10% after 4 weeks (optimizations not significant?)
- ⚠️ User satisfaction 3.0-4.0 (valuable but needs improvement)

### Scale Up if:
- ✅ All success criteria met
- ✅ User satisfaction >4.5/5.0
- ✅ Accuracy >98%
- ✅ Team requests expansion to more skills

---

## Reporting Schedule

### Weekly (Every Monday)
- Adoption metrics (executions, files optimized)
- Performance snapshot (CI time, time saved)
- Quality issues (false positives this week)

### Monthly (First Monday)
- Full dashboard with all metrics
- User satisfaction survey
- ROI calculation
- Recommendations for next month

### Quarterly (Every 3 months)
- Comprehensive impact report
- Decision: Expand, maintain, or reduce usage
- Skill-by-skill effectiveness analysis
- Future roadmap

---

## Current Status (2026-01-31)

### Integration Complete ✅
- 5 skills integrated
- Shared guide created
- Orchestrate documented
- Kaizen entries added

### Metrics Framework ✅
- This document created
- Tracking methods defined
- Benchmark targets set
- Success criteria established

### Next Steps ⏳
1. Collect Week 1 baseline data
2. Run initial satisfaction survey
3. Begin tracking in `/tmp/claude/code-simplifier-metrics.md`
4. Review after 2 weeks

---

## Related Documentation

- [Code Simplifier Integration Pattern](./code-simplifier-integration.md) - Integration guide
- [Factory Rules](./factory-rules.md) - Optimization rules
- [Kaizen Log](../kaizen/kaizen_log.md) - Improvement history
- [Orchestrate Skill](../orchestrate/SKILL.md) - Workflow integration

---

## Contact & Feedback

**Report issues with code-simplifier**:
- Accuracy problems: Log in quality tracking
- Performance concerns: Measure and document
- Integration bugs: File kaizen entry in affected skill

**Request new integrations**:
- Use `/kaizen` skill to analyze opportunity
- Calculate ROI (impact / effort)
- Propose in team discussion

**Monthly review**:
- Review metrics with team
- Decide on adjustments
- Update this framework as needed
