---
name: create-tickets
description: Use when a followup-tickets-*-DRAFT.md exists and needs to be turned into real Jira issues one at a time, each with an explicit y/n approval gate before creation.
allowed-tools: [Read, Edit, AskUserQuestion, Skill, mcp__atlassian__jira_create_issue, mcp__atlassian__jira_create_issue_link, mcp__atlassian__jira_search, mcp__atlassian__jira_get_issue, mcp__atlassian__jira_add_issues_to_sprint, mcp__atlassian__jira_get_field_options, mcp__atlassian__jira_search_fields]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings. Memory feedback_draft_outward_comms: NEVER auto-post / auto-create. Every ticket needs explicit y/n from the user.

# Create Tickets — Convertir un DRAFT de tickets en issues de Jira

Convierte un documento Markdown de seguimiento (formato `followup-tickets-*-DRAFT.md`) en tickets de Jira reales, uno por uno, con gate de aprobación explícito antes de cada creación.

Honra la regla de proyecto "draft outward comms — never auto-post" (memory `[[feedback_draft_outward_comms]]`): la skill muestra los campos mapeados primero, pregunta `y/n`, y solo crea si el usuario aprueba.

---

## Constantes configurables (editar al inicio de la ejecución si es necesario)

```
PROJECT_KEY   = "CORE"                         # proyecto Jira destino
DEFAULT_ASSIGNEE = "juansleon@playbypoint.com"  # Preferir email; también acepta display name o accountid:…
                                               # NOTA: un bare username puede no resolver en la API de Jira
DEFAULT_LABELS   = ["spike-followup"]          # siempre incluidos; se agrega <spike-slug> (ej. "core-733")
```

---

## Formato de entrada (Input Contract)

El documento de entrada es un archivo Markdown con una sección por ticket. La forma canónica es `investigations/CORE-733/followup-tickets-PRODUCT-DRAFT.md`.

### Estructura esperada por sección

```markdown
## T<n> — <título libre>

- **Tipo**: <Bug | Decisión de producto | Tarea> · **Prioridad**: <Alta | Media | Baja> · **Esfuerzo**: <texto libre>

- **Problema (lenguaje de negocio)**: <descripción del problema>

- **Impacto (cuantificado)**: <cifras, métricas, usuarios afectados>

- **Valor de arreglarlo**: <justificación>

- **Criterios de aceptación (observables)**:
  - <observable 1>
  - <observable 2>

- **Decisión de producto requerida** (opcional): <pregunta o decisión pendiente>

- **Nota para ingeniería**: <contexto técnico, referencias de archivo>
```

**Ejemplo real**: `investigations/CORE-733/followup-tickets-PRODUCT-DRAFT.md` (T1, T3, T4, T5, T6).

Notas del ejemplo real que el parser debe manejar:
- El separador `·` (punto medio) en la línea de metadatos puede ir con o sin espacios.
- Algunos tickets incluyen `**Necesita decisión de Rafa**` u otras variantes en la línea de Tipo/Prioridad/Esfuerzo.
- La sección `**Decisión de producto requerida**` es opcional; no todos los tickets la tienen.
- El título del `## T<n>` puede contener cualquier carácter; el número `n` no es necesariamente consecutivo (T1, T3, T4, T5, T6 en el ejemplo).

---

## Argumentos

| Argumento | Requerido | Descripción |
|-----------|-----------|-------------|
| `path` | Sí | Ruta al archivo `.md` del draft (relativa o absoluta). |
| `spike_key` | No | Ticket padre/spike a linkear como "relates to" (ej. `CORE-733`). Si se omite, inferir del path (`investigations/CORE-733/…` → `CORE-733`). Si no se puede inferir, preguntar al usuario. |
| `sprint` | No | ID o nombre del sprint. Si se omite → BACKLOG (sin sprint). Ver C2. |

---

## Flujo (paso a paso)

### Paso 0 — Verificar herramientas Jira

Los MCP tools de Jira (`mcp__atlassian__*`) se cargan bajo demanda. Antes de usarlos, verificar que estén disponibles en la sesión. Si no están disponibles, detener y reportar al usuario con mensaje claro: "Jira MCP tools no disponibles en esta sesión. Verificar configuración `.mcp.json`."

### Paso 1 — Leer el draft

Usar `Read` para cargar el archivo en `path`. Si el archivo no existe, detener con error.

### Paso 2 — Resolver spike_key

Si `spike_key` fue provisto, usarlo. Si no, intentar extraer del `path` (regex `investigations/(CORE-\d+)/`). Si no se puede inferir, usar `AskUserQuestion` para pedirlo al usuario. Es requerido para el link "relates to" (C4).

### Paso 3 — Parsear secciones de tickets

Extraer cada sección `## T<n> — <título>` y sus campos. Por cada sección:
- Extraer: título, Tipo, Prioridad, Esfuerzo, Problema, Impacto, Valor, Criterios de aceptación, Decisión de producto (si existe), Nota para ingeniería.
- Si algún campo **requerido** (Tipo, Prioridad, título) está ausente o no parseable → registrar como ERROR y continuar con el siguiente ticket (C6). Reportar al final el ticket que no pudo procesarse y qué falta.

### Paso 4 — Detectar tickets ya creados (idempotencia)

Buscar en el draft anotaciones de la forma:

```
✅ Creado: <ISSUE-KEY> (<fecha>)
```

Si una sección ya tiene esta anotación, **saltarla** y mostrar al usuario: "T<n> ya creado como <ISSUE-KEY> — omitiendo." (C3)

### Paso 5 — Verificar campo de estimación (una vez, al inicio)

Usar `mcp__atlassian__jira_search_fields` o `mcp__atlassian__jira_get_field_options` para descubrir si existe un campo de story points / estimate configurable para el proyecto. Guardar el nombre del campo si existe. Si no existe o no es accesible, continuar sin él e incluir el texto de Esfuerzo en la descripción (C4).

### Paso 6 — Por cada ticket pendiente (loop)

Para cada ticket aún no creado, en orden:

#### 6a. Construir el preview de campos mapeados

Mostrar en texto claro (NO crear en Jira todavía):

```
──────────────────────────────────────────────
Ticket T<n>: <título>
──────────────────────────────────────────────
Proyecto    : CORE
Tipo        : <Bug | Task>  ← mapeado de "<Tipo original>"
Prioridad   : <High | Medium | Low>  ← mapeado de "<Prioridad original>"
Esfuerzo    : <texto original>  [campo story-points: <valor si disponible> / "incluido en descripción"]
Asignado a  : juansleonc
Etiquetas   : spike-followup, <spike-slug>
Sprint      : <nombre/id si provisto> / BACKLOG (no sprint)
Link        : "relates to" → <spike_key>

Título (summary):
  <título del ticket>

Descripción (preview):
  **Problema**
  <texto>

  **Impacto**
  <texto>

  **Valor**
  <texto>

  **Criterios de aceptación**
  - <observable 1>
  - ...

  **Decisión de producto requerida** (si aplica)
  <texto>

  **Nota para ingeniería**
  <texto>

  ---
  Investigación: <path al archivo draft>
──────────────────────────────────────────────
```

#### 6b. Solicitar aprobación explícita (C1 — GATE OBLIGATORIO)

Usar `AskUserQuestion` o mostrar prompt en el hilo principal:

```
¿Crear este ticket en Jira? (y/n/edit/skip/abort)
  y     → crear tal como está
  n     → saltar este ticket (no crearlo), continuar con el siguiente
  edit  → mostrar los campos y pedir al usuario qué cambiar antes de crear
  skip  → alias de n
  abort → detener la skill completamente (no crear ningún ticket más)
```

**NO avanzar sin respuesta del usuario.** Esto es un gate bloqueante.

#### 6c. Si el usuario responde `y`

1. Llamar `mcp__atlassian__jira_create_issue` con los siguientes parámetros **top-level**:
   - `project_key`: PROJECT_KEY  ← **string requerido**, patrón ^[A-Z][A-Z0-9_]+$ (ej. "CORE")
   - `issue_type`: mapeado de Tipo (ver tabla de mapeos)  ← **NOT** `issuetype`
   - `summary`: título del ticket
   - `assignee`: DEFAULT_ASSIGNEE (preferir email; ver constante configurable al inicio)
   - `description`: descripción formateada (Problema/Impacto/Valor/Criterios/Decisión/Nota + link a investigación); Markdown aceptado
   - `components`: si aplica (comma-separated string)
   - `additional_fields`: JSON string que agrupa priority, labels, parent/epic, y story-points. Ejemplo:
     ```
     '{"priority": {"name": "High"}, "labels": ["spike-followup", "core-733"]}'
     ```
     - `priority` → `{"priority": {"name": "<High|Medium|Low>"}}` (mapeado de Prioridad, ver tabla)
     - `labels`   → `{"labels": ["spike-followup", "<spike-slug>"]}` (DEFAULT_LABELS + slug del spike_key)
     - Si campo de estimación disponible (custom field descubierto en Paso 5):
       agregar `"customfield_XXXXX": <valor_numerico>` dentro del mismo JSON de `additional_fields`.
       **NOTA**: el nombre exacto del campo (`customfield_XXXXX`) debe obtenerse vía `jira_search_fields` —
       NO es un parámetro top-level. Si no se encuentra, incluir el texto de Esfuerzo en la descripción (C6).

2. Guardar la `ISSUE-KEY` retornada (ej. `CORE-812`).

3. Llamar `mcp__atlassian__jira_create_issue_link`:
   - `link_type`: `'Relates to'`  ← string exacto; NO `"Relates"` ni `"relates to"` con minúscula
   - `inward_issue_key`: ISSUE-KEY nuevo  ← **NOT** `inwardIssue`
   - `outward_issue_key`: spike_key  ← **NOT** `outwardIssue`

4. Si `sprint` fue provisto: llamar `mcp__atlassian__jira_add_issues_to_sprint` con el sprint_id y el ISSUE-KEY. Si NO fue provisto: **no llamar este método** — el ticket queda en BACKLOG (C2).

5. Anotar el draft file (C3). Usar `Edit` para agregar en la línea inmediatamente después del heading de esa sección:

   ```
   > ✅ Creado: CORE-812 (2026-06-12)
   ```

   O bien como última línea antes del separador `---` de esa sección, lo que quede más legible.

6. Confirmar al usuario: "Creado: <ISSUE-KEY> — <link a Jira> | Anotado en el draft."

#### 6d. Si el usuario responde `n` / `skip`

Mostrar: "T<n> omitido. Continuando con el siguiente." Pasar al siguiente ticket.

#### 6e. Si el usuario responde `edit`

Mostrar todos los campos del preview y preguntar qué desea cambiar (usar `AskUserQuestion`). Aplicar los cambios al preview y volver al paso 6b con los campos actualizados.

#### 6f. Si el usuario responde `abort`

Detener la skill. Mostrar resumen de lo creado hasta ese punto y lo que quedó pendiente.

### Paso 7 — Resumen final

Al terminar todos los tickets, mostrar:

```
──────────────────────────────────────────────
Resumen de create-tickets
──────────────────────────────────────────────
Creados  : <lista de ISSUE-KEY con link>
Omitidos : <lista de T<n> omitidos por el usuario>
Errores  : <lista de T<n> con campos faltantes>
Ya existían : <lista de T<n> ya anotados>
──────────────────────────────────────────────
```

---

## Contratos de validación (C1–C6)

### C1 — Gate y/n por ticket (NUNCA auto-crear)

> "NEVER create a Jira issue without an explicit per-ticket y/n approval from the user."

Implementado en **Paso 6b**: `AskUserQuestion` es obligatorio antes de cada `mcp__atlassian__jira_create_issue`. El preview de campos se muestra ANTES de la pregunta. Honra memoria `[[feedback_draft_outward_comms]]`.

### C2 — BACKLOG por defecto; sprint solo si se especifica explícitamente

> "Default target is the BACKLOG. Sprint assigned ONLY if `sprint` argument explicitly provided."

Implementado en **Paso 6c** paso 4: `mcp__atlassian__jira_add_issues_to_sprint` se llama ÚNICAMENTE cuando `sprint != nil`. Esta regla es PROMINENTE: si el usuario no pasa `sprint`, el ticket va al backlog siempre, sin excepción.

**ANTI-PATRÓN**: No inferir un sprint a partir del nombre del ticket, título, o contexto. Solo el argumento explícito activa el sprint.

### C3 — Idempotencia: anotar el draft, saltar ya-creados

> "After creation, annotate the draft in place: `✅ Creado: <ISSUE-KEY> (<fecha>)`. On re-run, tickets already annotated are SKIPPED."

Implementado en **Paso 4** (detección) y **Paso 6c paso 5** (anotación vía `Edit`). El archivo draft es gitignored (`investigations/` vía `.git/info/exclude`) — está bien editarlo.

### C4 — Mapeo de campos

> Implementado en la tabla de mapeos más abajo y en el Paso 6c.

Parámetros **top-level** de `mcp__atlassian__jira_create_issue`:
- `project_key` = PROJECT_KEY (configurable, default `"CORE"`)  ← **NOT** `project`
- `issue_type` ← Tipo: "Bug" → `"Bug"`; cualquier otra cosa → `"Task"`  ← **NOT** `issuetype`
- `summary` = título del ticket
- `assignee` = DEFAULT_ASSIGNEE (preferir email; también acepta display name o `accountid:…`)
- `description` = framing de producto (Problema/Impacto/Valor/Criterios + Decisión si existe) + Nota para ingeniería + link a `path`
- `components` = si aplica (string comma-separated)

Parámetros que van **dentro de `additional_fields`** (JSON string):
- `priority` ← Prioridad: Alta→`{"name":"High"}`, Media→`{"name":"Medium"}`, Baja→`{"name":"Low"}`
- `labels` = `["spike-followup", "<spike-slug>"]` donde spike-slug es el spike_key en lowercase (ej. `"core-733"`)
- `estimate` (story points) ← si el campo existe, va como `"customfield_XXXXX": <n>` dentro de `additional_fields`; el nombre exacto se obtiene con `jira_search_fields` — **NO** es un parámetro top-level; si no se encuentra, incluir el texto de Esfuerzo en la descripción

Parámetros de `mcp__atlassian__jira_create_issue_link`:
- `link_type` = `'Relates to'`  ← string exacto (NOT `"Relates"`)
- `inward_issue_key` = nuevo ISSUE-KEY  ← **NOT** `inwardIssue`
- `outward_issue_key` = spike_key  ← **NOT** `outwardIssue`

### C5 — Sin hardcoding de CORE-733

> "Generic: NO hardcoded CORE-733; everything derives from arguments + the draft."

El `spike_key` se recibe como argumento o se infiere del `path`. `PROJECT_KEY` es una constante configurable, no hardcodeada en la lógica. Funciona con cualquier `followup-tickets-*-DRAFT.md` de cualquier ticket.

### C6 — Campos faltantes: detener ese ticket, reportar, continuar

> "If a required field is missing or unparseable, STOP on that ticket and report — never guess/fabricate. Other tickets may proceed."

Implementado en **Paso 3**: si Tipo, Prioridad, o título no pueden parsearse, el ticket se marca como ERROR con mensaje explícito de qué falta, y se continúa con el siguiente. Nunca inventar valores.

---

## Tabla de mapeos

### Tipo → `issue_type` (parámetro top-level)

| Valor en draft | issue_type en Jira |
|----------------|--------------------|
| `Bug` | `Bug` |
| `Bug / Seguridad` | `Bug` |
| `Decisión de producto` | `Task` |
| `Tarea` | `Task` |
| cualquier otro valor | `Task` |

### Prioridad → `priority` (dentro de `additional_fields`)

| Valor en draft | valor en additional_fields |
|----------------|---------------------------|
| `Alta` | `{"priority": {"name": "High"}}` |
| `Media` | `{"priority": {"name": "Medium"}}` |
| `Baja` | `{"priority": {"name": "Low"}}` |
| cualquier otro valor | `{"priority": {"name": "Medium"}}` (y notarlo) |

### Esfuerzo → story points (heurística, solo si campo disponible)

El Esfuerzo en el draft es texto libre. Si el campo de estimación existe en el proyecto, aplicar esta heurística:

| Texto de Esfuerzo | Story points sugeridos |
|-------------------|------------------------|
| `Medio día`, `~2–4 h`, `0.5–1 día` | 1 |
| `~1 día`, `1 día` | 2 |
| `2–3 días` | 3 |
| `> 3 días`, `1 semana` | 5 |

Si el texto no encaja en ninguna categoría, **incluir el texto en la descripción** y no setear el campo numérico (C6: no fabricar).

---

## Anti-patrones

- **NUNCA auto-crear** sin y/n explícito (C1). No importa cuántos tickets tenga el draft.
- **NUNCA asignar sprint por defecto** — backlog siempre a menos que `sprint` sea argumento explícito (C2).
- **NUNCA inventar campos** faltantes (C6) — detener ese ticket y reportar.
- **NUNCA re-crear** un ticket que ya tiene anotación `✅ Creado:` (C3).
- **NUNCA hardcodear** valores específicos de CORE-733 — la skill es genérica (C5).
- **NUNCA postear** comentarios en Jira al ticket padre/spike sin aprobación adicional del usuario.
- **NUNCA asumir** que el spike_key es el mismo que el PROJECT_KEY. Son distintos: PROJECT_KEY es el proyecto Jira; spike_key es el issue padre (ej. `CORE-733`).

---

## Kaizen

> Historial completo en [kaizen_log.md](kaizen_log.md). Si descubres durante la ejecución un campo no mapeado, un parser que falla, o una opción que los usuarios piden frecuentemente → documenta ahí, no aquí.

| Fecha | Cambio |
|-------|--------|
| 2026-06-12 | Creación inicial (CORE-733); C1–C6 diseñados para "draft → gate → create → annotate" |
| 2026-06-12 | Schema Jira verificado: `project_key`/`issue_type` top-level; `priority`/`labels` en `additional_fields` |
| 2026-06-12 | Regla: descripción AUTOCONTENIDA — sin shorthand interno (T1/T3, surface names, slugs); solo tickets reales (ej. CORE-733) |
| 2026-06-14 | Skills audit: email hardcodeado → placeholder `<assignee-email>` en constante + preview; Kaizen archivado |
