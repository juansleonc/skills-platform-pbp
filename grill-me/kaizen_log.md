# Grill-Me Kaizen Log

Archived from SKILL.md body. Operational lessons are promoted into the skill; this file is history only.

<!-- Kaizen: 2026-05-25 - Created from Matt Pocock's "Workflow for AI Coding" talk -->
- Origin: https://www.youtube.com/watch?v=-QFHIoCo-Ko (the /grill-me concept).
- See memory `[[reference_ai_coding_multiagent_workflow]]` for the broader takeaways
  (smart-zone context limit, clear-don't-compact, vertical-slice DAG, push/pull rules vs skills,
  orchestrator/worker/validator).

<!-- Kaizen: 2026-05-25 - Factory multi-agent talk: emit validation contracts -->
- Per Luke Alvoeiro (Factory), the orchestrator should define **validation contracts**
  (testable assertions) BEFORE implementation, and a validator checks against them.
- So Step 3 ("reflect the resolved model back") should also emit an explicit list of
  **testable assertions** — these become the contract `/tdd` writes tests for and the
  validator (`adversarial-review`/`code-review`) verifies. Don't stop at prose; produce
  the assertions.
