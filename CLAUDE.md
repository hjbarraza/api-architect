# api-architect — Claude notes

`references/api-manual.md` is the source of truth for this plugin. It defines the agent contract, the default operating loop, the defaults table, and every design/review/evolve decision fork.

Skills carry the routing logic, the operating stance, and a mandatory live read of the manual via `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md`. The manual holds the detailed rules — defaults table, decision forks, design/review/evolve specifics — and is the source of truth. To change plugin behavior, edit the manual, not the skills.

Explicit local convention (the target repo or org) always wins over a manual default. When current security, protocol, or framework guidance matters, verify against live official docs before shipping public or high-risk APIs.
