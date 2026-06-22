# api-architect

A Claude Code plugin for designing, implementing, reviewing, and evolving APIs the way a senior API engineer would: contract-first, smallest design that solves the outcome, behavior proven by tests, and the system left easier to operate.

Every skill is **manual-driven** — it reads a single source of truth, `references/api-manual.md`, live at runtime. Change the manual, change the behavior. No prompt forking, no stale copies.

## What it does

The plugin turns the API manual into operational behavior across the full lifecycle: clarify the job, choose the boundary, draft the contract, implement surgically, verify with focused tests, and prepare release and operation.

## Skills

- **`api-architect`** — umbrella skill. Routes an API task to the right phase (design / implement / review / evolve) and runs the manual's default operating loop end to end.
- **`api-design`** — turn a consumer need into a contract: paths, methods, IDs, request/response/error bodies, auth, pagination, idempotency, examples. Includes design templates.
- **`api-implement`** — build the drafted contract surgically inside the repo's existing layering: validate at the edge, business rules in the service layer, storage and downstream calls behind adapters.
- **`api-review`** — review an API (or a diff) against the manual: naming, status codes, error shapes, auth, compatibility risk, and operability. Includes review templates.
- **`api-evolve`** — change an existing API without surprising clients: compatibility rules, versioning, deprecation, migration notes.

## Agents

Bundled reviewer agents specialize the review phase — invoked by `api-review` (or directly) to scrutinize a contract or diff against the manual and report defensible findings tied to consumer impact, contract stability, security, and operability.

## How it stays grounded

Skills consult `references/api-manual.md` live via `${CLAUDE_PLUGIN_ROOT}`:

```
${CLAUDE_PLUGIN_ROOT}/references/api-manual.md
```

`${CLAUDE_PLUGIN_ROOT}` resolves to wherever the plugin is installed, so the path is portable across machines and install methods. The manual is the only source of conventions, defaults, and decision forks — see `CLAUDE.md`.

## Install

```
/plugin marketplace add /path/to/api-architect
/plugin install api-architect@api-architect
```

The first command registers this directory as a local single-plugin marketplace; the second installs the plugin from it. After install, the skills activate automatically when you ask Claude Code to design, build, review, or evolve an API.

## Layout

```
api-architect/
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest
│   └── marketplace.json     # local single-plugin marketplace
├── skills/
│   ├── api-architect/       # umbrella / router
│   ├── api-design/          # contract design (+ templates)
│   ├── api-implement/       # surgical implementation
│   ├── api-review/          # review (+ templates)
│   └── api-evolve/          # compatible evolution
├── agents/                  # reviewer agents
├── references/
│   └── api-manual.md        # source of truth (read live)
└── CLAUDE.md
```
