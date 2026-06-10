# Kaizen: Continuous Learning System

> "Every day we must improve" - 改善

Este documento explica cómo el sistema Kaizen aprende automáticamente en cada ejecución de skills.

## Filosofía

**Kaizen** (改善) = Mejora continua incremental

Cada vez que ejecutas un skill y encuentras:
- Un nuevo pattern útil
- Un anti-pattern que debería evitarse
- Una mejor forma de hacer algo
- Un edge case no documentado
- Una herramienta que funciona mejor en cierto contexto

**El skill debe aprender automáticamente** agregando el conocimiento para futuras sesiones.

## Cómo Funciona

### 1. Durante la Ejecución del Skill

Cuando Claude ejecuta un skill y descubre algo nuevo:

```
┌──────────────────────────────────────────────┐
│ Claude ejecuta /factory-check                │
│                                              │
│ Descubre: create_list en before(:all)       │
│ es 10x más lento que let con build_stubbed  │
└──────────────────┬───────────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────────┐
│ Claude DEBE:                                 │
│ 1. Completar el task actual                 │
│ 2. Usar Edit tool en el skill file          │
│ 3. Agregar hallazgo en sección Kaizen       │
└──────────────────────────────────────────────┘
```

### 2. Formato de Kaizen Entry

```markdown
## Kaizen: Continuous Improvement

> "Every day we must improve" - 改善

**While executing this skill**, if you discover:
- [List of things to watch for]

**You MUST**:
1. Complete the current task first
2. Then append improvements to this skill file using Edit tool
3. Format: `<!-- Kaizen: YYYY-MM-DD --> New content`

**Recent Improvements**:

<!-- Kaizen: 2026-01-28 - Pattern: create_list Performance -->
### Anti-Pattern: create_list in before(:all)

**Problem**:
```ruby
before(:all) do
  @users = create_list(:user, 10)  # Creates 10 DB records
end
```

Creates records once for entire describe block, but:
- Not cleaned up properly
- Causes random failures in parallel tests
- Still hits database 10 times

**Solution**:
```ruby
let(:users) { build_stubbed_list(:user, 10) }  # No DB hit
```

**Impact**: 450ms saved per describe block
**Learned from**: Real issue in spec/models/user_analytics_spec.rb
```

### 3. Shared References

Algunos aprendizajes benefician **múltiples skills**:

```bash
.claude/skills/shared/
├── factory-rules.md       # /tdd, /factory-check, /coverage
├── forbidden-patterns.md  # /tdd, /code-review, /security
├── testing-patterns.md    # /tdd, /coverage, /orchestrate
└── critical-rules.md      # ALL skills
```

**Regla**: Si el aprendizaje aplica a 2+ skills, agrégalo a shared/.

### 4. Cross-Skill Learning

```
/factory-check descubre pattern
         ↓
Actualiza shared/factory-rules.md
         ↓
Automáticamente beneficia:
- /tdd (usa factory-rules.md)
- /coverage (usa factory-rules.md)
- /orchestrate (usa factory-rules.md)
```

## Ejemplos Reales

### Ejemplo 1: Factory Performance

**Contexto**: `/factory-check` analiza spec lento

```ruby
# Original en spec/models/membership_spec.rb
describe 'subscription logic' do
  let(:facility) { create(:facility) }  # Takes 400ms!

  it 'validates subscription' do
    membership = build(:membership, facility: facility)
    expect(membership).to be_valid
  end
end
```

**Claude descubre**:
- `create(:facility)` crea 40+ registros asociados
- Test solo necesita facility object para validación
- No necesita DB

**Claude automáticamente**:
1. ✅ Completa análisis actual
2. ✅ Usa Edit tool en `/factory-check/SKILL.md`:

```markdown
<!-- Kaizen: 2026-01-28 -->
### Pattern: create(:facility) in let blocks

When facility is only needed as association (not queried from DB):

```ruby
# ❌ VERY SLOW - Creates 40+ records
let(:facility) { create(:facility) }

# ✅ FAST - No DB, has ID for associations
let(:facility) { build_stubbed(:facility) }

# ⚠️ MEDIUM - Only if you need merchants/courts/products
let(:facility) { create(:facility, :skip_callbacks) }
```

**Impact**: 350ms saved per test
**Detection**: Look for facility in let block + no DB queries in test
**Learned from**: spec/models/membership_spec.rb:23
```

3. ✅ También actualiza `shared/factory-rules.md` para que otros skills aprendan

### Ejemplo 2: Query Optimization

**Contexto**: `/query-analyzer` detecta query lento en producción

```ruby
# ClickHouse muestra:
# Query: User.where(active: true).to_a
# Avg duration: 2.3s
# Executions: 1200/day
# Total wasted: 46 minutes/day
```

**Claude descubre**:
- Falta índice en `active` column
- Query se llama desde 3 controllers diferentes
- EXPLAIN muestra: type=ALL (full table scan)

**Claude automáticamente agrega a `/query-analyzer/SKILL.md`**:

```markdown
<!-- Kaizen: 2026-01-28 - Boolean Index Pattern -->
### Pattern: Boolean Column Without Index

**Common mistake**: Not indexing boolean flags used in WHERE clauses.

**Detection in ClickHouse**:
```sql
SELECT table, column, count(*) as queries, avg(duration_ms)
FROM system.query_log
WHERE query LIKE '%WHERE active = %'
  AND type = 'ALL'  -- Full table scan
```

**Fix**:
```ruby
# Migration
add_index :users, :active
```

**Impact**: 2.3s → 15ms (153x faster)
**ROI**: Saves 45 minutes/day of query time
**Learned from**: Production ClickHouse analysis 2026-01-28
```

### Ejemplo 3: Safe Script Pattern

**Contexto**: `/safe-script` genera fix para data corruption

```ruby
# Script falla en producción:
# Error: PG::UniqueViolation: duplicate key value
```

**Claude descubre**:
- Script no era idempotent
- Rerun causó duplicates
- Faltaba check antes de INSERT

**Claude automáticamente mejora `/safe-script/SKILL.md`**:

```markdown
<!-- Kaizen: 2026-01-28 - Idempotency Check Pattern -->
### Critical: Always Check Before Insert

**Anti-Pattern**:
```ruby
# ❌ FAILS on rerun
MembershipPayment.create!(payment_id: payment.id, membership_id: membership.id)
```

**Safe Pattern**:
```ruby
# ✅ Idempotent - safe to rerun
unless MembershipPayment.exists?(payment_id: payment.id)
  MembershipPayment.create!(payment_id: payment.id, membership_id: membership.id)
end

# ✅ BETTER - Single query
MembershipPayment.find_or_create_by!(payment_id: payment.id) do |mp|
  mp.membership_id = membership.id
end
```

**Lesson**: ALWAYS assume script will be run multiple times
**Learned from**: Production incident PLA-1234 (2026-01-28)
```

## Métricas de Aprendizaje

Track aprendizajes por skill:

```bash
# Contar Kaizen entries por skill
find .claude/skills -name "SKILL.md" -exec grep -c "<!-- Kaizen:" {} \; | \
  paste -d: <(find .claude/skills -name "SKILL.md") -

# Output ejemplo:
# .claude/skills/factory-check/SKILL.md:5
# .claude/skills/query-analyzer/SKILL.md:8
# .claude/skills/safe-script/SKILL.md:3
```

**Goal**: Cada skill debe tener 2+ Kaizen entries por mes.

## Guías para Claude

### Cuándo Agregar Kaizen Entry

✅ **SÍ agregar** cuando:
- Descubres pattern nuevo (no documentado en skill)
- Encuentras anti-pattern que causó bug real
- Optimización da mejora medible (>10% performance)
- Tool funciona mejor que lo documentado
- Edge case no cubierto causó problema

❌ **NO agregar** cuando:
- Ya está documentado en skill
- Cambio es específico de un caso (no generalizable)
- Conocimiento es temporal (ej: bug de versión específica)

### Formato Consistente

Cada Kaizen entry debe tener:

1. **Fecha**: `<!-- Kaizen: YYYY-MM-DD -->`
2. **Título descriptivo**: Qué se aprendió
3. **Context**: Por qué es importante
4. **Ejemplo**: Código before/after
5. **Impact**: Mejora medible (tiempo, errores, etc.)
6. **Source**: Dónde se aprendió (file, issue, production)

### Testing de Aprendizajes

Antes de agregar Kaizen entry, validar:

```bash
# 1. El pattern realmente aplica generalmente
grep -r "pattern_to_check" app/ spec/ | wc -l
# Si aparece 3+ veces, es generalizable

# 2. El impacto es medible
# Run before/after benchmark

# 3. No contradice aprendizajes previos
grep "Kaizen.*related_topic" .claude/skills/**/*.md
```

## Maintenance

### Monthly Review

Una vez al mes, revisar Kaizen entries:

```bash
# Ver todos los aprendizajes del mes
grep -r "<!-- Kaizen: 2026-01" .claude/skills/

# Identificar patterns repetidos
# → Mover a shared/ si aplica a 2+ skills

# Identificar obsoletos
# → Remover si ya no aplica
```

### Consolidation

Si un skill tiene 10+ Kaizen entries similares:

```markdown
<!-- Consolidated: 2026-02-01 -->
## Factory Performance Patterns

Based on 8 Kaizen entries from Jan 2026, key learnings:

1. Always prefer build over create (unless DB needed)
2. Use :skip_callbacks for facility
3. build_stubbed when only ID needed
4. Never create_list in before(:all)

See shared/factory-rules.md for complete decision tree.
```

## ROI del Sistema Kaizen

**Estimado**:
- Cada Kaizen entry previene: 1-2 bugs futuras
- Cada bug prevenida ahorra: 2-4 horas debugging
- Con 5 entries/mes: 10-20 horas ahorradas
- **ROI anual**: ~120-240 horas ($12-24K value)

**Plus**: Conocimiento permanente cross-sessions.

---

## Meta-Kaizen

Este documento también mejora con Kaizen:

<!-- Kaizen: 2026-01-28 - Initial version -->
Created comprehensive Kaizen guide covering:
- Philosophy and workflow
- Real examples from factory-check, query-analyzer, safe-script
- Guidelines for when/how to add entries
- Maintenance and consolidation process
- ROI tracking

Next improvements needed:
- Add automated Kaizen metrics dashboard
- Create skill-to-skill learning graph
- Implement Kaizen entry validation checks
