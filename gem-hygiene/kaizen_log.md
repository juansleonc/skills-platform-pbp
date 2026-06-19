# gem-hygiene — Kaizen Log

Historical improvement entries for the `gem-hygiene` skill. New entries go here (via `/kaizen`) rather than inline in `SKILL.md`.

| Date | Entry |
|------|-------|
| 2026-06-15 | Added an explicit "host-side file scan by design" comment above the unused-gem `grep` (check #3). It scans `app/ lib/ config/` outside `bin/d`; this is intentional (pure grep, no Ruby → rule #2 doesn't apply; host checkout = mounted source, so identical + faster). Comment prevents a future reviewer from "fixing" it to `bin/d`. Source: skills-audit Step-0 deferred-decision #4 (user-confirmed: keep + comment). |
