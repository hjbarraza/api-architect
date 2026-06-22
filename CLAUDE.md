# api-architect — Claude notes

`references/api-manual.md` is the source of truth for this plugin. It defines the agent contract, the default operating loop, the defaults table, and every design/review/evolve decision fork.

Skills carry the routing logic, the operating stance, and a mandatory live read of the manual via `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md`. The manual holds the detailed rules — defaults table, decision forks, design/review/evolve specifics — and is the source of truth. To change plugin behavior, edit the manual, not the skills.

Explicit local convention (the target repo or org) always wins over a manual default. When current security, protocol, or framework guidance matters, verify against live official docs before shipping public or high-risk APIs.

As of v0.2 the plugin ships executable tooling, not just prompts: a manual-injection hook (`hooks/` — a `SessionStart` + `UserPromptSubmit` pair that injects the manual pointer and operating loop so the live read is on the record from turn one), helper scripts (`scripts/schema-diff.sh` for breaking-change detection, `scripts/smoke-verify.sh` for a live contract check), and a CI compatibility gate (`.github/workflows/api-compat.yml`, which runs `schema-diff.sh`). The tooling enforces and exercises the manual's rules; it does not replace the manual as the source of truth.
