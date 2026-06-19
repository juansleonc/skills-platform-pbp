# CLAUDE.local.md - Personal Development Rules

> **🔴 PRIORITY**: This file (personal, NOT committed — in `.gitignore`) **OVERRIDES** `CLAUDE.md`
> (team-wide, committed) for any conflicting rule. Always check both: start here, then `CLAUDE.md`.
> If conflict → CLAUDE.local.md wins.

Reglas personales que complementan (o sobrescriben) `CLAUDE.md`.

## Reglas Adicionales (Locales)

### 1. TDD Mandatory
**SIEMPRE escribir tests PRIMERO.** Ciclo: RED (test falla) → GREEN (código mínimo) → REFACTOR → COVERAGE 100% en cambios.

```bash
bin/d rspec spec/path_spec.rb          # con SIMPLECOV_REPORT=true para coverage
bin/d rake 'coverage:local:delta'
```

### 2. Docker Execution
**TODOS los comandos Ruby/Rails en Docker.** NUNCA `bundle exec …` directo. Wrapper preferido: `bin/d`.

```bash
bin/d rspec spec/models/user_spec.rb       # rspec
bin/d rake 'coverage:local:delta'          # rake
bin/d rails c                              # console
bin/d rubocop -A app/models/user.rb        # rubocop
bin/d pronto                               # pronto
bin/d sh                                   # shell
# Alternativas: make {test|console|migrate|web-bash|db-bash|containers-up}
#               docker compose exec web bundle exec …   (verboso)
```

### 3. Linting Rules (CRÍTICO)
**SIEMPRE Pronto ANTES de commit, para archivos MODIFICADOS** (solo líneas cambiadas, preserva legacy).
Archivos NUEVOS → `bin/d rubocop -A path/to/new_file.rb`. ⚠️ Pronto solo ve archivos NO commiteados → correr ANTES de `git add`.

```bash
bin/d bundle exec pronto run -r rubocop -c develop -f text
# Corregir → re-ejecutar hasta limpio → recién entonces git add/commit
```

### 4. Coverage 100%
Después de tests, verificar 100% en cambios: `bin/d rake 'coverage:local:file[app/models/user.rb]'` → debe mostrar `Coverage: 100%`.

### 5. Factory Rules (delta de CLAUDE.md)
`build` (DEFAULT: validaciones/métodos) > `build_stubbed` (necesita `id`/`persisted?`) > `create` (SOLO scopes/queries/DB). Facility: `create(:facility, :skip_callbacks)` salvo que necesites merchants/courts. Detalle: [factory-rules.md](.claude/skills/shared/factory-rules.md).

### 6. Forbidden Patterns (en tests)
`allow_any_instance_of` / `expect_any_instance_of` · IDs hardcodeados (`create(:user, id: 1)`) · `Time.now` / `Date.today` · `before(:all) { create(...) }`.

### 7. Time-Dependent Tests
`Timecop.freeze(Time.current) do … end` siempre con `Time.current` (nunca `Time.now`).

### 8. Ruby 3 Date Formatting
```ruby
# ❌ deprecated en Ruby 3:  date.to_s(:db) / time.to_s(:db)
# ✅ strftime:              date.strftime('%Y-%m-%d') / time.strftime('%Y-%m-%d %H:%M:%S')
```

### 9. Nil Safety en Fechas
Verificar nil ANTES de `strftime` (crashea si nil):
```ruby
starts = membership.acquired_at ? membership.acquired_at.strftime('%Y-%m-%d %H:%M:%S') : Time.current.strftime('%Y-%m-%d %H:%M:%S')
```

### 10. Test Before Production
SIEMPRE probar scripts en Docker antes de prod: `docker compose exec web ruby -c tmp/script.rb` (sintaxis) y `bundle exec rails runner` con datos simulados.

### 11. No Heredocs en Rails Console
SQL en una sola línea (los heredocs no se pegan bien en console):
```ruby
ActiveRecord::Base.connection.execute("SELECT * FROM users WHERE id = #{id}")
```

### 12. SQL Directo para Fixes Manuales
Para saltar callbacks que pueden fallar: `connection.execute("INSERT …")` o `record.update_column(:col, val)` — NO `Model.create!`.

### 13. NUNCA Agregar Co-Autor en Commits
Commits limpios, sin `Co-Authored-By: Claude/AI`. Solo del usuario.

### 14. Gitmoji en Commits y PRs
**SIEMPRE gitmoji** ([gitmoji.dev](https://gitmoji.dev/)). Formato commit y título PR: `TICKET | EMOJI type(scope): Description`.

```bash
git commit -m "CORE-189 | ✨ feat(payments): Add retry with contact pre-sync"
git commit -m "CORE-189 | 🐛 fix(patch): Fix contact lookup using find_or_create_by"
# ❌ sin emoji (incompleto): "CORE-189 | fix: Fix contact lookup"
```

| Emoji | Tipo | Uso | | Emoji | Tipo | Uso |
|-------|------|-----|-|-------|------|-----|
| ✨ | `feat` | Nueva feature | | 🔧 | `chore` | Configuración |
| 🐛 | `fix` | Bug fix | | 🚩 | `feat` | Feature flags |
| 🚑️ | `fix` | Hotfix crítico | | 🔒️ | `security` | Fix de seguridad |
| 🩹 | `fix` | Fix simple/no crítico | | 💥 | `feat!` | Breaking change |
| ♻️ | `refactor` | Refactor de código | | ⬆️ | `chore` | Upgrade dependencias |
| ✅ | `test` | Agregar/actualizar tests | | 🔥 | `chore` | Eliminar código/archivos |
| 📝 | `docs` | Documentación | | 👔 | `feat` | Business logic |
| 🎨 | `style` | Formato/estructura | | 🛂 | `feat` | Auth / permisos / roles |
| ⚡️ | `perf` | Performance | | 🌱 | `chore` | Seeds |
| 🗃️ | `db` | DB / migraciones | | 🏗️ | `refactor` | Arquitectura |

### 15. Auto-Learning de Correcciones
Cuando el usuario te corrige (después de output sustancial mío):

**Señales**: negación (`no`, `stop`, `para`, `wait`, `don't`) · imperativo correctivo (`mejor X`, `usa X`, `should be X`) · prohibición (`nunca`, `never`, `no hagas`) · sorpresa (`por qué hiciste`, `why did you`) · directo (`te equivocaste`, `wrong`, `ese no es`).

**Acción**: NO ignorar — tratar como aprendizaje de alta señal → invocar `/learning` (Rule + Why + How to apply + Affected skills) → esperar confirmación (`y`/`n`/`edit`/`m`) antes de persistir.

**NO invocar si**: es respuesta a mi `AskUserQuestion` · confirmación corta (`ok`, `gracias`, `thanks`) · pide nueva tarea (no corrige) · ya rechazaste 3 sugerencias esta sesión.

> Persiste en `memory/feedback_<slug>.md` + propaga a skills vía Kaizen. Detalle: `.claude/skills/learning/SKILL.md`.

### 16. Branch Safety — NUNCA tocar branches protegidas directamente

**Protegidas**: `develop`, `master`, `main`, `production`, `staging`.

**Origen** (incidente TRI-74): commits terminaron en `origin/develop` sin PR. `git checkout -b NAME origin/develop` hace que `NAME` trackee `origin/develop`; un `git push` sin args antes del `push -u origin NAME` se escapa a develop.

**Reglas absolutas**:
1. **NUNCA `git checkout develop`** (ni master/main/staging/production) en una feature branch. Ver develop sin checkout: `git log origin/develop`, `git diff origin/develop...HEAD`, `git show origin/develop:path`.
2. **NUNCA `git push` sin branch explícita.** Siempre `git push origin <feature-branch>` (o `-u` la 1ª vez). Prohibido: `git push`, `git push origin`, `git push -u`.
3. **NUNCA `git push origin develop`** (ni protegidas). Caso legítimo (revert/hotfix) → pedir confirmación Y mostrar el comando antes.
4. **Al crear feature branch** `git checkout -b NAME origin/develop` → inmediatamente `git push -u origin NAME` para fijar tracking. Si no pusheo ya, verificar: `git rev-parse --abbrev-ref --symbolic-full-name @{u}` debe ser `origin/<NAME>`, NO `origin/develop`.
5. **NUNCA `git pull` en develop** con feature en curso.
6. **NUNCA `--force`/`--force-with-lease`** contra protegidas sin confirmación explícita + comando mostrado + `y`.
7. **Verificar branch** antes de toda op destructiva: `git rev-parse --abbrev-ref HEAD` (debe ser feature, NUNCA develop).

**Si ya estoy en develop**: PARAR, avisar, NO `push`/`commit`/`pull` hasta indicación del usuario. Volver a la feature branch.

**Defensa en profundidad**: GitHub branch protection (server) · pre-push hook en `.git/hooks/pre-push` (client) · `push.default = simple` + `push.autoSetupRemote = false`. Si alguna falla, la regla #16 sigue obligando.

### 17. Tech-Debt Tagging (Convención Personal)

Marker nativo para marcar **atajos deliberados** (adoptado del spike `ponytail` 2026-06-15 — SOLO esta idea; el decision-ladder y los carve-outs "never simplify" se rechazaron por redundancia con `/tdd`, `/architect` y los Critical Rules de CLAUDE.md).

Formato canónico, ligado a ticket:
```ruby
# DEBT(CORE-123): <qué se simplificó/omitió>. ceiling: <límite/condición donde se rompe>. upgrade: <gatillo concreto que obliga a revisitarlo>.
```

- `ceiling` y `upgrade` **OBLIGATORIOS**. Un marker sin `upgrade` trigger = máximo riesgo de rot → inválido (agregá ambos o arreglá el código en vez de taguearlo).
- Cosechar (sin rake): `git grep -nE 'DEBT\(' -- '*.rb'`. Los que no tengan `upgrade:` son los primeros a revisitar.
- `DEBT(...)` es la **forma fuerte** (exige ticket + ceiling + upgrade). `TODO`/`FIXME` siguen para recordatorios triviales.
- **NUNCA** taguear como `DEBT(...)`: un bug real, un guard faltante, ni una violación de Critical Rules / forbidden-patterns (timezone, facility scoping, transacciones/idempotencia de pagos, TDD-first, no-secrets). Eso no es deuda — se arregla.

## 🔀 Auto-Invoke Table (Skill Router)

> **Patrón Prowler/midudev** (JSCONF2026): las skills son **prerequisitos de conocimiento OBLIGATORIOS, no referencias opcionales.** Esta tabla vive acá (push, always-on) → se consulta en **TODA** tarea, no solo cuando corro `/orchestrate`. Es enforcement soft-pero-documentado: no es un hook duro (ver `[[feedback_no_redundant_verification_hooks]]`), pero me obliga a invocar la skill ANTES de la acción. Ver memoria `[[reference_ai_coding_multiagent_workflow]]`.

**Regla de uso**: antes de actuar sobre un trigger, invocar la(s) skill(s) de la fila. Si una fila dice "GATE", es bloqueante: no avanzar sin pasarla.

### Fase del trabajo (orden del flujo)

| Trigger | Skill OBLIGATORIA (primero) | Por qué |
|---------|------------------------------|---------|
| Idea **sin formar** (el QUÉ o el CÓMO abierto; varios enfoques plausibles; request multi-subsistema) | `/brainstorm` → diverger, generar 2-3+ enfoques, elegir dirección → luego `/grill-me` | Divergente antes de converger; abre el espacio de solución antes de matar ambigüedad |
| Feature/refactor nuevo con spec **difusa** (ya sabes el enfoque) | `/grill-me` → emitir validation contracts (aserciones testables) | Ambigüedad = 0 antes de diseñar; el contrato alimenta TDD y el validator |
| Feature nuevo / nuevo pack / refactor mayor / nueva integración | `/architect` | Diseño y ubicación antes de codear |
| **Cualquier cambio de comportamiento** (feature, fix, guard) | `/tdd` — test que falla PRIMERO (regla #8/#1) | TDD obligatorio, sin excepciones |
| **Después de implementar** (toda feature/fix) — **GATE** | `/adversarial-review` verificando las aserciones del contrato (complementa, no reemplaza, `/code-review`) | Validator independiente basado en razonamiento (patrón creator-verifier de Factory) — OBLIGATORIO, no opcional |
| **Llega feedback de review** (PR humano, Bugbot, CodeRabbit, Greptile) | `/receiving-code-review` — gatear antes de implementar | Inbound: verificar real+in-scope+reproducible (confirm-loop), sin agreement performativo; bots = input de menor confianza |
| Antes de commit — **GATE** | `bin/d bundle exec pronto ...` (regla #3) + `pbp-code-review:pre-commit` | Lint de líneas cambiadas |
| **Crear commit** (usuario dio ok explícito) | `/commit` — gitmoji + formato TICKET\|EMOJI (regla #14) | Commit limpio; nunca co-autor AI (regla #13); nunca sin permiso (regla #7) |
| **Crear PR** | `/create-pr` (skill personal — NUNCA `pbp-code-review:pr-create`) | PR con Background/Attention/Reference (JIRA+Honeybadger); assignee + label "ready for review"; título con gitmoji; base = develop |

### Por archivo / glob

| Cambio toca... | Skill OBLIGATORIA | Regla/razón |
|----------------|-------------------|-------------|
| `app/graphql/**`, `packs/*/app/graphql/**` | `/graphql` | Backward-compat mobile + greenfield (regla #4) |
| `db/migrate/**` | `/migration` | Safety, rollback, timestamps (regla #13) |
| `app/jobs/**`, `*_job.rb` | `/sidekiq` | Idempotencia, Ruby 3 (regla #5) |
| `*membership*`, `app/services/memberships/**` | `/memberships` | Auto-renewal, prorations, cross-payer |
| `*payment*`, `*gateway*`, `app/services/payment_service/**`, `app/adapters/**` | `/pci-compliance` + `/gateway-consistency` + `/gateway-test` (nuevo gateway) | 14 gateways, PCI, dinero (regla #3/#5); `/gateway-test` genera tests al implementar gateway nuevo |
| `app/models/**`, `app/services/**` con queries | `/multi-tenancy` + `/performance` | facility scoping (regla #2) + N+1 |
| `app/policies/**`, `packs/*/app/policies/**` | `/action-policy` | Authorization parity (regla #12) |
| `packs/**` (cualquier cambio de paquete) | `/packwerk` | Boundaries + prefijo de tablas |
| `packs/audit_logs/**`, trackers | `audit-logs` | Trackers de DynamoDB |
| Llamadas a servicios externos / HTTP / gateways | `resilience` | Timeouts, fire-and-forget, fallos silenciosos |
| Specs nuevos/modificados | `factory-check` | build > build_stubbed > create (regla #5) |
| Después de escribir/modificar tests | `/coverage` | 100% patch coverage en cambios (regla #1/#4) |
| Existe `followup-tickets-*-DRAFT.md` | `/create-tickets` | Convertir DRAFT en issues Jira, 1×1 con gate y/n |
| Query nueva o potencialmente lenta | `/query-analyzer` | EXPLAIN + ClickHouse antes de prod |
| `Time.now` / `Date.today` / fechas | `/timezone` | Time.current (regla #1/#7/#8 local) |
| Fix manual de datos / SQL directo | `/safe-script` | Idempotencia + rollback (regla #12 local) |
| Correr código/rake de otra branch · PR review aislado · agentes paralelos que mutan | `/worktrees` | Aislamiento sin tocar el checkout principal; nunca `docker compose up` desde un worktree |
| Debug de producción / error | `/debug` + Honeybadger MCP | Root cause sistemático |
| Ejecutar comando puntual en contenedor (one-off, fuera de `bin/d`) | `/docker-exec` | Wrapper seguro; nunca `bundle exec` directo (regla #2) |
| `Gemfile`, `Gemfile.lock` | `/gem-hygiene` | Vulnerabilidades, gems sin uso, versiones desactualizadas |
| Refactor estructural / god class / fat model | `/code-smells` | Smells estructurales antes de refactorizar |
| Código auth / controllers / datos sensibles | `/security` | Brakeman/OWASP además de `/action-policy` |

### Por pack de dominio (invariantes co-localizadas — patrón AGENTS.md jerárquico)

| Pack | Invariante a recordar antes de tocarlo |
|------|----------------------------------------|
| `webhooks` | `attr_encrypted` en credenciales; nunca exponer PKs (solo UUIDs/slugs); validación de grupo de facility |
| `billing` | Entitlements facility-scoped vs org-scoped; payer vía `Billing::BillableEntityResolver` |
| `orgs` / `orgs_frontend` | Clerk SSO / SAML |
| `feature_flag` | DynamoDB-backed, sistema lock/sync |
| `partners` | Flujo OAuth-like verification code (`partners_verification_codes`) |
| `electronic_invoicing` | Report-only (sin modelos/migraciones); adapters por país |

> **Mantenimiento**: cuando agregue/renombre una skill o un pack, actualizar esta tabla. Es el "router" — si una skill no está acá, en la práctica no se dispara sola.

## Ecosistema PlaybyCourt (repos relacionados)

Otros repos viven en `/Users/leon/workspace/pbp/`. Consultarlos cuando una tarea cruce límites de `platform`. Los más frecuentes:

| Repo | Path (`…/pbp/`) | Consultar cuando… |
|------|-----------------|-------------------|
| `playbypoint-mobile` | `playbypoint-mobile` | Cambios GraphQL (validar backward-compat), push, deep links, pagos móviles |
| `greenfield` | `greenfield` | Cambios GraphQL desde el rewrite web (Apollo); deferred queries `@defer`/`@stream` |
| `pbp_ratings` | `pbp_ratings` | Lógica de ratings, sync de matches/resultados, tournaments/leagues |
| `card_connect` | `card_connect` | Gateway de pago default (gem propio); bug/bump CardConnect |
| `pbp-claude-plugins` | `pbp-claude-plugins` | Crear/editar skills/plugins del equipo (`pbp-*`) |

> **Catálogo completo (~20 repos: gems del Gemfile, design system, apps standalone, tooling) → [investigations/claude-local-docs/ecosystem-repos.md](investigations/claude-local-docs/ecosystem-repos.md)** _(local, gitignored)_

## Workflow

**Smart Auto-Orchestrate**: detecto features/refactors → sugiero `/orchestrate` (user confirma y/n); ejecución directa si comando explícito; skip en preguntas/lectura (zero overhead).

**RPI scaffold (Research → Plan → Implement)** — al empezar un ticket, si `investigations/<TICKET>/` está vacío, sembrar desde `investigations/_RPI-TEMPLATE.md` (gitignored). Mapeo a artefactos + skills:

| Fase RPI | Artefacto | Skills que lo conducen |
|---|---|---|
| **Research** | `understanding.md` | `/architect`, `Explore`, Context7 — mecanismo + write-paths + grounding en prod |
| **Plan** | `<feature>-design.md` (ADR) | `/architect`, `/migration`, `/performance`, `/query-analyzer` — files+líneas, alternativas, test strategy |
| **Implement** | código + `seed_*.rb`/`verify_*.rb` + `findings.md` | `/tdd`, `/factory-check`, `/code-review`, `/adversarial-review` |

> Contratos de `/grill-me` → `validation-contracts.md` (alimentan la fila Plan/test strategy). Feature pesada (>1 día / customer-facing / compliance) → promover Plan a OpenSpec (`/opsx:new`). Entre fases: **compactar** (sesión nueva sembrada solo con el doc de esa fase). Detalle: el propio `_RPI-TEMPLATE.md`.

**Workflow típico**:
RPI Research (`understanding.md`) → `/architect` Plan (`<feature>-design.md`) → `/tdd` (RED/GREEN/REFACTOR) + `/factory-check` → implementación + `findings.md` → `/query-analyzer` → `/code-review` + validadores (`/multi-tenancy`, `/timezone`, `/performance`) → **Pronto (regla #3)** → `/commit` → `/create-pr`.

> Solo commitear/PR si Pronto está limpio. Skills disponibles via `/skill-name` (catálogo completo en el tool Skill). El **Skill Router** de arriba es la fuente canónica de qué skill disparar.

### Meta-Skills (Manual Only — Zero Overhead, sin triggers automáticos)
- **`/skill-creator`** — trabajo manual repetitivo (3+ veces sobre **código real**), solución compleja que vale automatizar. ❌ no para exploración/planning/prototipos.
- **`/kaizen`** — skill que falla repetidamente, podría ser más eficiente, o documentación poco clara.

### Investigaciones por Ticket (Local Only)
`investigations/CORE-[id]/` — excluida vía `.git/info/exclude` (no `.gitignore`), no compartida. Para notas de investigación, bugs en testing manual, evidencia, decisiones locales, scripts de diagnóstico. **No usar `docs/features/`** (ese folder es team, commiteado).

### Documentación Personal
- [Kaizen Guide](.claude/skills/shared/kaizen-guide.md) — sistema de aprendizaje
- [Factory Rules](.claude/skills/shared/factory-rules.md) — decision tree completo

## OpenSpec — Spec-Driven Development (Experimental)

Framework de spec-driven development (genera docs persistentes antes de codificar). **Usar solo para el ~20% de features que lo justifican** — cuando se cumplen **≥2**: feature > 1 día · customer-facing · múltiples stakeholders · compliance/audit (PCI, SOC2) · handoff entre sesiones · decisiones técnicas complejas. **NO** para bug fixes, refactors internos, perf, admin UI, prototipos, scripts one-off.

```bash
/opsx:new [feature]   # crear cambio
/opsx:ff  [feature]   # fast-forward: genera proposal+design+specs+tasks
/opsx:apply           # implementar tasks   (luego /opsx:verify → /opsx:archive)
```

> Guía completa (artefactos, workflow híbrido, métricas, algoritmo de decisión, troubleshooting) → **[investigations/claude-local-docs/openspec-guide.md](investigations/claude-local-docs/openspec-guide.md)** _(local, gitignored)_
