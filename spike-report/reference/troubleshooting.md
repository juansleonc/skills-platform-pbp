# Performance Expectations & Troubleshooting

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

| Issue | Cause | Fix |
|-------|-------|-----|
| SVG doesn't render | Invalid viewBox or gradient reference | Check SVG syntax; ensure all gradient IDs exist in `<defs>` |
| Tabs don't switch | JavaScript error or missing onclick handlers | Check browser console; ensure `showTab()` is defined |
| Layout breaks on mobile | Missing responsive classes | Add Tailwind breakpoints (`md:`, `lg:`) |
| Text too small to read | Fixed font sizes don't scale | Use Tailwind responsive text classes (`text-sm md:text-base`) |
| Report takes too long to generate | Too many files analyzed or complex diagrams | Reduce scope with the `--sections` intent (see Invocation) |
