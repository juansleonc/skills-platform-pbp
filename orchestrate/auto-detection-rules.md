# Orchestrate Auto-Detection Rules

> **Smart Mode**: Automatically suggest orchestrate for features/refactors

## Detection Algorithm

### Step 1: Check for Explicit Commands (AUTO-EXECUTE)

If user message contains ANY of these → **Execute immediately without asking**:

```ruby
EXPLICIT_COMMANDS = [
  '/orchestrate',
  'orchestrate this',
  'run full workflow',
  'run orchestrate',
  'ejecuta orchestrate'
]
```

**Action**: Execute `/orchestrate` immediately, no confirmation needed.

---

### Step 2: Check for Skip Keywords (SKIP)

If user message contains ANY of these → **Skip orchestrate, respond directly**:

```ruby
SKIP_KEYWORDS = [
  # Questions
  '¿', '?', 'cómo', 'qué', 'cuál', 'dónde', 'cuándo',
  'how', 'what', 'which', 'where', 'when',

  # Read-only requests
  'muestra', 'lee', 'read', 'show', 'ver',
  'display', 'print', 'cat',

  # Explanations
  'explica', 'explain', 'qué hace', 'what does',
  'describe', 'tell me about',

  # Confirmations/acknowledgments
  'gracias', 'ok', 'bien', 'perfecto',
  'thanks', 'okay', 'good', 'great',

  # Search/explore (read-only)
  'busca', 'search', 'encuentra', 'find',
  'investiga', 'investigate', 'explore'
]
```

**Action**: Respond directly to user (read file, explain, search, etc.). Zero overhead.

---

### Step 3: Check for Feature Keywords (AUTO-SUGGEST)

If user message contains ANY of these → **Suggest orchestrate (ask y/n)**:

```ruby
FEATURE_KEYWORDS = [
  # Implementation verbs
  'implementa', 'agrega', 'crea', 'añade',
  'implement', 'add', 'create',

  # Feature nouns
  'feature', 'funcionalidad', 'functionality',

  # Refactoring
  'refactor', 'refactoriza', 'mejora', 'optimize',
  'improve', 'cleanup',

  # Database
  'migración', 'migration', 'migrate',
  'schema change', 'add column', 'add table',

  # Domain-specific (high complexity)
  'payment', 'membership', 'RBAC', 'permissions',
  'gateway', 'subscription', 'auto-renewal',

  # API changes
  'API', 'GraphQL', 'endpoint', 'mutation',
  'query', 'resolver',

  # Bug fixes (complete)
  'fix bug completo', 'arregla el bug', 'soluciona',
  'fix the bug', 'resolve issue'
]
```

**Action**:
1. Acknowledge the request
2. Show detection message:
   ```
   🔧 Feature detected: [brief description]
   This looks like a complete feature/refactor. Run /orchestrate? (y/n)
   ```
3. Wait for user response
4. If "y" → Execute `/orchestrate`
5. If "n" → Proceed without orchestrate

---

### Step 4: Default (SKIP)

If none of the above → **Skip orchestrate, respond directly**

**Action**: Respond to user request directly (answer question, make small change, etc.).

---

## Detection Examples

### ✅ AUTO-EXECUTE (Explicit)

```bash
User: "/orchestrate feature: Add RBAC validation"
→ Executes immediately (explicit command)

User: "run orchestrate for this membership change"
→ Executes immediately (explicit command)
```

---

### 🔧 AUTO-SUGGEST (Feature Detected)

```bash
User: "Implementa validación RBAC en reservations controller"
→ Detects: "implementa" + "RBAC"
→ Suggests:
  🔧 Feature detected: RBAC validation in reservations
  This looks like a complete feature. Run /orchestrate? (y/n)

User: "Agrega auto-renewal para memberships"
→ Detects: "agrega" + "auto-renewal" + "memberships"
→ Suggests:
  🔧 Feature detected: Auto-renewal for memberships
  This looks like a complete feature. Run /orchestrate? (y/n)

User: "Refactoriza el payment service para usar Interactor"
→ Detects: "refactoriza" + "payment"
→ Suggests:
  🔧 Refactor detected: Payment service
  This looks like a significant refactor. Run /orchestrate? (y/n)

User: "Crea migración para agregar webhook_url a facilities"
→ Detects: "crea" + "migración"
→ Suggests:
  🔧 Migration detected: Add webhook_url column
  This looks like a database change. Run /orchestrate? (y/n)

User: "Add GraphQL mutation for canceling memberships"
→ Detects: "add" + "GraphQL" + "mutation" + "memberships"
→ Suggests:
  🔧 Feature detected: GraphQL mutation for membership cancellation
  This looks like a complete feature. Run /orchestrate? (y/n)
```

---

### ❌ SKIP (Simple Requests)

```bash
User: "¿Cómo funciona el membership renewal?"
→ Detects: "¿" (question)
→ Responds directly (no orchestrate suggestion)

User: "Muéstrame app/models/user.rb"
→ Detects: "muéstrame" (read-only)
→ Shows file directly (no orchestrate suggestion)

User: "Explica qué hace este método"
→ Detects: "explica" (explanation)
→ Explains directly (no orchestrate suggestion)

User: "Busca todos los archivos que usan Time.now"
→ Detects: "busca" (search)
→ Searches directly (no orchestrate suggestion)

User: "Gracias, perfecto"
→ Detects: "gracias" (acknowledgment)
→ Responds directly (no orchestrate suggestion)

User: "Cambia Time.now a Time.current en línea 45"
→ No feature keywords detected (simple fix)
→ Makes change directly (no orchestrate suggestion)
```

---

## Edge Cases

### Case 1: Question + Feature Keyword
```bash
User: "¿Deberíamos implementar RBAC?"
→ Detects: "¿" (question) - takes priority
→ Skip orchestrate (answer the question)
```

**Rule**: Skip keywords take priority over feature keywords.

### Case 2: Multiple Feature Keywords
```bash
User: "Implementa payment gateway con RBAC y migración"
→ Detects: "implementa" + "payment" + "RBAC" + "migración"
→ Suggests:
  🔧 Feature detected: Payment gateway with RBAC and migration
  This looks like a complex feature. Run /orchestrate? (y/n)
```

**Rule**: More keywords = stronger signal for orchestrate.

### Case 3: Unclear Intent
```bash
User: "Hay un problema con el membership renewal"
→ No clear keywords detected
→ Skip orchestrate (investigate first)
```

**Rule**: When unclear, skip orchestrate and respond. User can invoke manually if needed.

---

## Priority Order

1. **EXPLICIT_COMMANDS** (highest priority) → Execute immediately
2. **SKIP_KEYWORDS** → Skip orchestrate
3. **FEATURE_KEYWORDS** → Suggest orchestrate (y/n)
4. **DEFAULT** → Skip orchestrate

---

## Performance Impact

| Scenario | Detection Time | Total Overhead |
|----------|---------------|----------------|
| Simple question | ~0.1s | **0s** (skip) |
| Read request | ~0.1s | **0s** (skip) |
| Feature detected | ~0.1s | **0s** until user confirms |
| Explicit command | ~0.1s | **0s** (direct execution) |

**Result**: Zero overhead for ~80% of messages (questions, reads, explanations).

---

## Maintenance

Update keywords when:
- New domain areas added (e.g., "inventory", "booking")
- Common patterns emerge in user requests
- False positives/negatives detected

**Kaizen entry format**:
```markdown
<!-- Kaizen: YYYY-MM-DD - Detection Update -->
- Added keyword: "inventory" (new domain)
- Removed keyword: "X" (too many false positives)
- Adjusted priority: Skip takes precedence over feature
```

---

## Testing Detection

```bash
# Test explicit
"/orchestrate" → Should execute immediately ✅

# Test feature
"implementa RBAC" → Should suggest (y/n) ✅

# Test skip
"¿cómo funciona?" → Should skip, answer directly ✅

# Test default
"hay un bug" → Should skip, investigate ✅
```
