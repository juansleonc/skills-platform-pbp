# Kaizen Log — audit-logs

> Archived from SKILL.md to reduce per-invocation context cost. Operational rules promoted to SKILL.md body; log entries preserved here for history.

## Changelog

| Date | Entry |
|------|-------|
| 2026-06-15 | /optimize-skill correctness fixes: (1) YAML example now shows mandatory top-level `events:` wrapper + 2-space indent — missing it meant the event key would NOT be read by `EventConfiguration` (`yaml_data["events"]`); (2) rejection attribution corrected from `EventTracker` to `EventConfiguration#validate_event_type!` (raises `ArgumentError`) + `Event#event_description_matches_configuration` validation. |
| 2026-06-14 | Tracker count corrected: 41 total files − 2 bases = **39 real trackers**; YAML events = **38**. Self-edit-via-Edit replaced with `/kaizen`. Log archived here. |
| 2026-06-10 | Event catalog replaced with dynamic commands: static count was stale (claimed 28; real 39 trackers / 38 YAML events including missing `booking_*` category). |
| 2026-06-10 | Step 2.5 YAML example regenerated from real `event_actions.yml`: `display_value_handler` is CamelCase class name (`PaymentMethodHandler`), not snake_case string; `expected_target_type` added. |
| 2026-03-13 | Initial skill creation from CORE-124 PR learnings (SegundoRP). Rules established: error handling in BaseTracker.call; metadata for UI display, IDs in related_objects; DisplayValueGenerator for formatting. 39 trackers / 38 YAML events documented. |
