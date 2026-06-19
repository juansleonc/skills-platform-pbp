# Code Review — Output Format

Markdown template for a completed `/code-review` run.

```markdown
## Code Review: <branch-name>

### Critical Rules Check
| Rule | Status | Notes |
|------|--------|-------|
| Timezone Safety | OK / FAIL | |
| Multi-tenancy | OK / FAIL | |
| Financial Transactions | OK / FAIL / N/A | |
| API Compatibility | OK / FAIL | |
| Payment Idempotency | OK / FAIL / N/A | |

### Context7 References
- Rails: <relevant documentation patterns>
- RSpec: <relevant testing patterns>

### ClickHouse Production Verification
- Data patterns: <findings from pbp_productionDB_optimized>
- Edge cases: <potential NULL/empty handling issues>
- Query performance: <optimization suggestions>

### Production Error Context (Honeybadger + Sentry)
- Honeybadger faults: <any related faults>
- Sentry issues: <any related issues in graphql_pro, platform, etc.>

### Architecture
- OK / WARN / FAIL Finding with explanation

### Security
- OK / WARN / FAIL Finding with explanation

### Performance
- OK / WARN / FAIL Finding with explanation

### Code Simplification (via code-simplifier)
- <simplification opportunities>

### Recommendations
1. <actionable recommendation>
2. <actionable recommendation>
```
