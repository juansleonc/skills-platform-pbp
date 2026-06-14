---
name: learning
description: Capture user corrections, extract the lesson, persist to auto-memory and propagate to affected skills. Hybrid trigger - detection plus user confirmation. Use whenever the user corrects, redirects, or signals dissatisfaction with prior assistant output.
allowed-tools: [Read, Edit, Write, Bash, Grep, Glob]
disable-model-invocation: false
---

> **📋 Config Priority**: `CLAUDE.local.md` overrides `CLAUDE.md` for local settings. Always check both files for current project conventions.

# Learning Skill - Capture Corrections, Never Repeat

> "El que no aprende de sus errores, está condenado a repetirlos."

## Purpose

Capture user corrections in real time, extract the underlying lesson, and persist it across two surfaces:

1. **Auto-memory** — `~/.claude/projects/-Users-leon-workspace-pbp-platform/memory/feedback_*.md` survives across conversations.
2. **Skill kaizen sections** — `.claude/skills/<name>/SKILL.md` changes behavior in future skill runs.

Corrections are the highest-signal training data available. Every correction missed is a future repeat.

## Philosophy

> "If you only correct me once and I repeat the mistake, the system is broken — not you."

1. **Trust signals over politeness** — when the user says "no", "stop", "mejor X", "incorrect", treat it as a correction event, not conversational noise.
2. **Storage on both axes** — memory persists across sessions; skill kaizen entries change behavior in workflows. Both matter.
3. **Confirmation prevents noise** — detection is automatic, but persistence requires explicit `y/n`. False positives must not pollute memory.

---

## When to Use

### Hybrid Trigger (Detection + Confirmation)

**Auto-suggest when the user message after substantial assistant output contains correction signals**:

| Category | Spanish | English |
|----------|---------|---------|
| Negation | `no`, `mal`, `incorrecto` | `no`, `wrong`, `incorrect`, `don't` |
| Halt | `stop`, `para`, `detente`, `espera` | `stop`, `wait`, `halt` |
| Better way | `mejor X`, `usa X`, `debería ser X` | `should be X`, `use X instead` |
| Forbidden | `no hagas`, `prohibido`, `nunca` | `never`, `don't ever`, `forbidden` |
| Style preference | `prefiero X`, `mantén X` | `I prefer X`, `keep X` |
| Surprise | `por qué hiciste`, `quién te dijo` | `why did you`, `who told you` |
| Direct | `te equivocaste`, `ese no es` | `you're wrong`, `that's not` |

### Detection Algorithm

```ruby
def correction_detected?(user_message, prior_assistant_message)
  return false if user_message.nil? || prior_assistant_message.nil?
  return false if prior_assistant_message.length < 100  # ignore tiny outputs
  return false if responding_to_my_question?(prior_assistant_message)

  signals = CORRECTION_KEYWORDS.any? { |kw| user_message.downcase.include?(kw) }
  imperative = user_message.match?(/^(no|stop|para|wait|don't|never)\b/i)
  references_prior = user_message.length < 200 && substantive(prior_assistant_message)

  signals || imperative || references_prior
end
```

### Skip if

- Prior assistant message was a question via `AskUserQuestion` (user is answering, not correcting)
- Message is a confirmation: `gracias`, `ok`, `bien`, `thanks`
- User is requesting a new task, not redirecting prior output
- Detection sensitivity downgraded after 3 consecutive `n` rejections in this session

### Manual Invocation

```bash
/learning                       # Capture last correction in this session
/learning "<lesson text>"       # Save explicit lesson with no detection
/learning review                # Show recent feedback memories
/learning propagate <skill>     # Push existing memory into a specific skill
/learning conflict <slug>       # Check if a new memory contradicts existing
```

---

## Workflow

### Phase 1: Detect

Scan user message for correction signals against the prior assistant message. If matched, proceed to extraction.

### Phase 2: Extract Lesson

From the correction, derive 4 fields:

| Field | How |
|-------|-----|
| **Rule** | Imperative: "Always X", "Never Y", "Prefer X over Y" |
| **Why** | Reason user gave (or inferred from context) |
| **How to apply** | When/where this rule kicks in (file types, workflows, scenarios) |
| **Affected skills** | Map keywords → skills (see Skill Mapping below) |

**Example**:

```
User said: "no, nunca pongas tickets en comentarios de código"
Prior: assistant wrote `# CORE-189: validate contact` in a ruby file

Extracted:
  Rule:    Never reference ticket IDs in inline code comments
  Why:     Comments must explain invariants, not work history
  Apply:   When writing comments in any code file (.rb, .js, .ts, .py)
  Skills:  code-review, tdd, coverage
```

### Phase 3: Confirm

Show extraction to user, wait for response:

```
🎓 Aprendizaje propuesto:

  Rule:   Never reference ticket IDs in inline code comments
  Why:    Comments must explain invariants, not work history
  Apply:  When writing comments in any code file
  Skills: code-review, tdd, coverage

Acciones:
  y    → guardar en memoria + propagar a skills afectadas
  n    → cancelar (falso positivo)
  edit → modificar antes de guardar
  m    → solo memoria, no propagar a skills
```

### Phase 4: Persist

#### 4a. Auto-memory (always on `y` or `m`)

Write `~/.claude/projects/-Users-leon-workspace-pbp-platform/memory/feedback_<slug>.md`:

```markdown
---
name: <Short title in imperative>
description: <One-line description for relevance matching by future Claude>
type: feedback
---

<Rule statement in imperative form, 1-3 lines>

**Why:** <Reason from user or inferred from context>

**How to apply:** <When/where rule applies. Be specific about file types, workflows, or scenarios>

**Source:** Correction on <YYYY-MM-DD> during <brief context — e.g. "PR review of CORE-189">.
```

**Slug rules**:
- `feedback_<topic>.md`, lowercase, snake_case, ≤ 5 words
- Check existing memories first via `ls ~/.claude/projects/-Users-leon-workspace-pbp-platform/memory/feedback_*.md`
- If similar exists, prefer **update** over create (use Edit, append `**Update <date>:**` line)

Then update `MEMORY.md` index — append under the appropriate `### Heading` (or create new heading if topic is new):

```markdown
### <Category Heading>
- [<Short Title>](<feedback_slug.md>) — <one-line hook, ~150 chars max>
```

#### 4b. Skill kaizen propagation (only on `y`)

For each skill in the `Affected skills` list, append to its `SKILL.md`:

```markdown
<!-- Kaizen: YYYY-MM-DD - User correction -->
- Rule: <Rule statement>
- Why: <Reason>
- How to apply: <When/where>
- Source: User correction on <date>. See `~/.claude/projects/-Users-leon-workspace-pbp-platform/memory/feedback_<slug>.md`.
```

Place at the end of the skill's "Recent Improvements" / "Kaizen" section. If no such section exists, create one at the end of the file.

#### 4c. Typed frontmatter edges in topic files (always on `y` or `m`, when a relation is expressed)

**Rule: prose entry in MEMORY.md AND typed frontmatter key in the topic file — never just one.**

Why: machine-readable edges let a future linter or graph follow supersession chains instead of parsing English prose (per the knowledge-graph ADR, decision item 3).

When the learning being persisted expresses one of these relationships to another memory file, write the corresponding frontmatter key directly in the affected topic file(s):

| Relationship | Old file gets | New file gets (optional) |
|---|---|---|
| This learning supersedes an older one | `superseded_by: <new-file-stem>` + `status: superseded` | `supersedes: <old-file-stem>` |
| This learning corrects an older one | `corrects: <other-file-stem>` on the correcting file | — |
| This learning belongs to a ticket lineage | `ticket: CORE-XXX` on the new file | — |
| This learning CONTRADICTS an existing node (both remain valid, unresolved) | `conflicts: [<new-file-stem>]` appended to peer file's list (symmetric — peer lists new, new lists peer) | `conflicts: [<peer-file-stem>]` on the new file |

**`conflicts:` decision gate** (apply before writing — mirrors §2 of `DESIGN-knowledge-lint.md`):
```
correction vs existing node:
  fully replaces it         → superseded_by  (row 1 above)
  fixes one wrong token     → corrects        (row 2 above)
  contradicts, unresolved   → conflicts       (row 4 above — NEW)
  ambiguous which applies   → ASK USER before writing any edge
```
Do NOT pick a winner — the whole point of `conflicts:` vs `superseded_by:` is that resolution is deferred to a human. Emit the edge and STOP. Never guess `superseded_by` when the correct edge is `conflicts`.

**Symmetry requirement** (enforced by C4 linter): when writing `conflicts:`, BOTH files must list each other. If the peer already has a `conflicts:` list, append to it (dedup). If no list exists, create it. Also add a one-line note in MEMORY.md under BOTH entries: `(conflicts with [[<other>]] — unresolved, see frontmatter)`.

**`conflicts:` list shape** (YAML, top-level, list of bare stems):
```yaml
conflicts:
  - peer_file_stem_here
```

**Stems in `conflicts:` use** the same bare-stem format as `superseded_by:` (filename without `.md`); normalization-aware (`-`≡`_`, case-insensitive per the linter).

**How to add the frontmatter key**: open the affected topic file; if it already has a `---` frontmatter block, insert the new key as a sibling of `name`/`description`/`type` (before the closing `---`). If no frontmatter block exists, prepend one. Example — marking an old file as superseded:

```markdown
---
name: Old finding title
description: One-line description
status: superseded
superseded_by: project_core639_spec_date_rot
metadata:
  type: project
---
```

**Checklist before closing Phase 4**:
- [ ] MEMORY.md prose entry written (4a)
- [ ] `updated: YYYY-MM-DD` frontmatter key written/refreshed in the topic file (today's date — enables hot-set recency ranking in MEMORY.md; match `updated: "2026-06-14"` quoted-string format)
- [ ] Skill kaizen propagation done if `y` (4b)
- [ ] If a supersession/correction/ticket/conflict relation was expressed: typed frontmatter edge written in the topic file(s) (4c)

### Phase 5: Confirm to User

```
✅ Guardado:
  📝 ~/.claude/projects/-Users-leon-workspace-pbp-platform/memory/feedback_<slug>.md (nuevo)
  🔄 MEMORY.md actualizado (sección "Lessons Learned")
  🧠 Propagado a: code-review, tdd, coverage

Próximas conversaciones aplicarán esta regla automáticamente.
```

---

## Skill Mapping (Correction Topic → Skills)

Use this map to decide which skills receive kaizen entries. When unclear, default to `code-review` only.

| Correction topic | Affected skills |
|------------------|-----------------|
| Comments / docs style | `code-review`, `tdd`, `coverage`, `architect` |
| Naming conventions | `code-review`, `architect`, `tdd` |
| Test patterns | `tdd`, `coverage`, `factory-check` |
| Pronto / lint workflow | `commit`, `create-pr`, `code-review` |
| Git / branch / commit | `commit`, `create-pr` |
| Pack boundaries | `packwerk`, `architect` |
| GraphQL conventions | `graphql`, `code-review` |
| Multi-tenancy / scoping | `multi-tenancy`, `code-review` |
| Time / timezone | `timezone`, `code-review`, `tdd` |
| Payment / gateway | `pci-compliance`, `gateway-consistency`, `code-review` |
| Sidekiq / jobs | `sidekiq`, `code-review` |
| Performance / queries | `performance`, `code-review` |
| Migration safety | `migration`, `code-review` |
| Action Policy / auth | `action-policy`, `security`, `code-review` |
| Investigation workflow | `architect`, `orchestrate` |
| Docker / commands | `docker-exec`, `commit` |
| **Cross-cutting / unclear** | `code-review` only (default) |

---

## Conflict Resolution

If a new correction contradicts an existing memory:

```
⚠️ Conflicto detectado:

Existing: feedback_xxx.md says "<old rule>"
New:      "<new rule>"

Acciones:
  r → reemplazar (new fully supersedes old → write superseded_by: edge in old file)
  k → conservar ambos sin resolución (contradición genuina → write conflicts: edge in BOTH files per Phase 4c)
  m → fusionar (combine into one entry, mark old as superseded)
  c → cancelar
```

Default: ask user. Never auto-resolve. Note: `k` maps to the `conflicts:` typed-edge pathway in Phase 4c — both files must list each other symmetrically.

---

## False Positive Handling

If user says `n` (don't save) **3 times in a row this session**:
- Stop auto-suggesting in this session
- Wait for explicit `/learning` invocation
- Note for kaizen review: detection threshold may need tuning

This prevents the skill from becoming annoying.

---

## Templates

### Feedback memory file

Path: `~/.claude/projects/-Users-leon-workspace-pbp-platform/memory/feedback_<slug>.md`

```markdown
---
name: <Short title>
description: <One-line description used by future Claude to decide relevance>
type: feedback
---

<Rule in imperative form>

**Why:** <Reason>

**How to apply:** <When and where>

**Source:** Correction on <YYYY-MM-DD> during <context>.
```

### MEMORY.md index entry

Append under existing or new `### Heading`:

```markdown
- [<Title>](feedback_<slug>.md) — <one-line hook ~150 chars>
```

### Skill kaizen entry

Append at end of target skill:

```markdown
<!-- Kaizen: YYYY-MM-DD - User correction -->
- Rule: <Rule>
- Why: <Reason>
- How to apply: <When/where>
- Source: User correction on <date>. See `~/.claude/projects/-Users-leon-workspace-pbp-platform/memory/feedback_<slug>.md`.
```

---

## Examples

### Example 1: Style correction

```
Assistant wrote a 6-line rdoc comment block above a Ruby method.

User: "no, comentarios cortos máximo 1 línea, los detalles van en /docs"

Detected → Extract:
  Rule:   Inline comments max 1-3 lines; detailed docs go in /docs folder
  Why:    Code stays lean; rationale belongs in commit/PR/docs
  Apply:  When writing rdoc, comment blocks, or method documentation
  Skills: code-review, tdd, architect

User confirms: y

Saved:
  📝 ~/.claude/.../memory/feedback_lean_comments.md (already exists → updated with new example)
  🔄 MEMORY.md (entry already present, no change)
  🧠 Propagado a: code-review, tdd, architect (kaizen entries added)
```

### Example 2: Workflow correction

```
Assistant ran `git commit` without running Pronto first.

User: "stop, siempre Pronto antes de commit"

Detected → Extract:
  Rule:   Always run Pronto before git commit, even for cherry-picks/squashes
  Why:    PR feedback flagged lint issues that Pronto would have caught
  Apply:  Before any `git commit` invocation
  Skills: commit, create-pr, code-review

User confirms: y

Saved:
  📝 ~/.claude/.../memory/feedback_pronto_before_commit.md (already exists → reinforced)
  🧠 Propagado a: commit, create-pr, code-review
```

### Example 3: Naming correction (new memory)

```
Assistant named a controller `ReservationCancelerController`.

User: "no, en Rails los controllers son adjetivos: AuthorizedController no AuthorizerController"

Detected → Extract:
  Rule:   Rails controllers use adjective form (Authorized, not Authorizer)
  Why:    Rails convention; no verbs as class names — classes are categories
  Apply:  When naming any controller class
  Skills: code-review, architect

User confirms: y

Saved:
  📝 ~/.claude/.../memory/feedback_controller_naming.md (NEW)
  🔄 MEMORY.md → new entry under "### Rails Naming Conventions"
  🧠 Propagado a: code-review, architect
```

---

## Integration with `/kaizen`

The `/kaizen` skill periodically audits all skills for outdated patterns. Entries written by `/learning` use the standard `<!-- Kaizen: YYYY-MM-DD - User correction -->` marker so kaizen audits can:
- Detect duplicate corrections across skills
- Identify high-frequency correction topics (signal for systemic issue)
- Verify that skill behavior actually changed (not just docs updated)

When `/kaizen` runs, it should report stats on corrections captured by `/learning` since last audit.

---

## Recent Improvements (Kaizen)

> Full history archived in [`kaizen_log.md`](kaizen_log.md). Add new entries there; promote to the active body only if they change operational behavior.
