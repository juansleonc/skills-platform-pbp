# Kaizen Log — create-tickets

> Archivo de historial. Solo lectura durante la ejecución de la skill. Actualizar aquí, no en SKILL.md.

<!-- Kaizen: 2026-06-12 — Creación inicial -->
- Creado a partir de la necesidad real en CORE-733 (5 tickets pendientes de crear en Jira).
- Input contract derivado del análisis directo de `investigations/CORE-733/followup-tickets-PRODUCT-DRAFT.md`.
- C1–C6 diseñados para satisfacer el workflow de "draft → gate → create → annotate".
- Jira MCP tools referenciados como carga bajo demanda (Paso 0) siguiendo el patrón de chrome tools del proyecto.

<!-- Kaizen: 2026-06-12 — Alineado con el schema real de jira_create_issue/_link (verified) -->
- `project_key` (NOT `project`) y `issue_type` (NOT `issuetype`) son los parámetros top-level correctos.
- `priority` y `labels` NO son parámetros top-level; van dentro de `additional_fields` como JSON string.
- Story points (estimación) van como `"customfield_XXXXX"` dentro de `additional_fields`; el nombre exacto se descubre con `jira_search_fields` — nunca es top-level.
- `jira_create_issue_link` usa `link_type: 'Relates to'` (string exacto), `inward_issue_key` / `outward_issue_key` (NOT `inwardIssue`/`outwardIssue`).
- `DEFAULT_ASSIGNEE` cambiado a email (ej. `<assignee-email>`); un bare username (`<gh-user>`) puede no resolver en la API.

<!-- Kaizen: 2026-06-12 - User correction -->
- Rule: La descripción de cada ticket debe ser AUTOCONTENIDA — nunca usar shorthand interno de investigación/spike (T1/T3/T4, nombres de surface, slugs de `investigations/`). Describir el mecanismo en lenguaje claro (ej. "links creados por fan-out de membresía a facilities sin compra" en vez de "T4"). Una referencia a un ticket REAL (ej. CORE-733) sí es válida.
- Why: la audiencia (Rafa/equipo) no tiene mi contexto de investigación; "T4" no le dice nada. Usuario: "la referencia a t4 no va, nadie va a saber que es, debe ser claro" (revisando CORE-762).
- How to apply: antes de construir el preview y el `description` de cada ticket (Paso 6a/6c), barrer el texto del draft por `T<n>`, nombres de surface y slugs de `investigations/`, y reemplazarlos por el mecanismo. Conservar referencias a tickets reales.
- Source: User correction on 2026-06-12. See `memory/feedback_outward_no_internal_shorthand.md`.

<!-- Kaizen: 2026-06-14 — Skills audit cleanup (opportunity 22) -->
- Hardcoded personal email (`<assignee-email>`) replaced with `<assignee-email>` placeholder in configurable constants + preview block. Users must set DEFAULT_ASSIGNEE at runtime.
- Kaizen entries archived here (−29 lines from SKILL.md hot path).
