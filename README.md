<div align="center">

<img src="assets/cover.png" alt="API Architect" width="100%" />

<h1>API&nbsp;Architect</h1>

<p><strong>Design, build, and evolve APIs the way a senior engineer would.</strong><br/>
A manual-driven Claude Code plugin — contract-first, agent-native, grounded in a single source of truth.</p>

<sub>8 skills&nbsp;&nbsp;·&nbsp;&nbsp;4 reviewer agents&nbsp;&nbsp;·&nbsp;&nbsp;7 commands&nbsp;&nbsp;·&nbsp;&nbsp;executable gates&nbsp;&nbsp;·&nbsp;&nbsp;v0.2.0</sub>

</div>

---

API Architect turns a senior-grade API design manual into operational behavior across the whole lifecycle: clarify the job, choose the boundary, draft the contract, implement surgically, prove it with tests, document the surface, evolve it without surprising clients — and reverse-engineer an undocumented API when there is no spec.

Every skill is **manual-driven**: it reads one source of truth, [`references/api-manual.md`](references/api-manual.md), live at runtime. Change the manual, change the behavior — no prompt forks, no stale copies. The manual is synthesized from four standard works (Geewax, *API Design Patterns*; Gough/Bryant/Auburn, *Mastering API Architecture*; Newman, *Building Microservices*; Kapexhiu, *Building Microservices with Node.js*).

## Install

```sh
/plugin marketplace add hjbarraza/api-architect
/plugin install api-architect@api-architect
```

The first command registers the repo as a single-plugin marketplace; the second installs it. Skills then activate automatically whenever you ask Claude Code to design, build, test, review, document, evolve, or discover an API — and a hook arms the manual on the next session.

## The lifecycle

One umbrella skill routes any API task through the phases below and runs the manual's default operating loop end to end:

```
            ┌─────────────────────  api-architect (router)  ─────────────────────┐
            │                                                                     │
  discover ─▶  design ─▶  implement ─▶  test ─▶  review ─▶  document ─▶  evolve
            │                                                                     │
            └───────  clarify-before-build · contract-first · grounded in code  ──┘
```

Before designing, it can **optionally** ground itself in your code — it auto-detects an existing repo/spec/contracts and asks whether to read them (local models, routes, conventions) plus external dependency/partner specs, then designs from reality, not a blank page. Never forced.

## Skills

| Skill | Phase | What it does |
|---|---|---|
| **`api-architect`** | route | Umbrella router — sends a task to the right phase and runs the operating loop. |
| **`api-design`** | design | Turn a consumer need into a contract: resources, methods, IDs, request/response/error bodies, auth, pagination, idempotency, examples. Contract-first, with templates. |
| **`api-implement`** | build | Build the drafted contract surgically in the repo's layering: validate at the edge, rules in the service layer, storage and downstream calls behind adapters. |
| **`api-test`** | test | Prove behavior — contract conformance, error paths, auth/tenancy boundaries, idempotency, pagination, CDC/Pact, Testcontainers. |
| **`api-review`** | review | Adversarial pre-merge review against the manual; dispatches the reviewer agents and runs the checklist. |
| **`api-document`** | document | Consumer-facing docs and SDKs from the contract: reference, worked examples, error catalog, auth/pagination notes, portal outline. |
| **`api-evolve`** | evolve | Change an API without breaking clients: compatibility rules, expand-and-contract, versioning, deprecation, observability, async/events. |
| **`api-discover`** | discover | Reverse-engineer an undocumented API — map the surface from code and contracts, infer the spec, surface the gaps. |

## Reviewer agents

Specialized, adversarial lenses invoked by `api-review` (or directly). Each grounds every finding in the manual and ties it to consumer impact.

| Agent | Lens |
|---|---|
| **`api-contract-reviewer`** | Resource design, naming, opaque IDs, pagination, error shape, status codes, idempotency, field-mask/PATCH semantics, compatibility (incl. a GraphQL lens). |
| **`api-security-reviewer`** | Threat model, authz at the data owner, mass assignment, confused-deputy, abuse controls, the do-not-log list. Thinks like an attacker. |
| **`api-compatibility-reviewer`** | Breaking-change detection (REST + protobuf), expand-and-contract, the schema-diff gate, versioning discipline. |
| **`api-async-reviewer`** | Event/async contracts, webhook signature & replay, saga compensation correctness. |

## Commands

Seven slash commands map one-to-one onto the lifecycle, for when you want a phase explicitly:

`/api-design` · `/api-implement` · `/api-test` · `/api-review` · `/api-document` · `/api-evolve` · `/api-discover`

## Executable tooling

The plugin ships gates, not just prose:

- **Manual-injection hook** (`hooks/`) — a `SessionStart` hook surfaces the manual and the operating loop from turn one; a `UserPromptSubmit` hook re-surfaces it (once per session) when an API-shaped request appears. It only attaches context — it never blocks.
- **`scripts/schema-diff.sh`** — compares two contract versions (OpenAPI / protobuf) and exits non-zero on a breaking change.
- **`scripts/smoke-verify.sh`** — hits a running endpoint and validates the **captured response** against the OpenAPI response schema (honest skip when tooling is absent — never a false pass).
- **Compatibility Action** (`.github/workflows/api-compat.yml`) — runs `schema-diff.sh` in CI to fail PRs that introduce breaking changes.

## One source of truth

Skills read the manual live via `${CLAUDE_PLUGIN_ROOT}`, which resolves to wherever the plugin is installed:

```
${CLAUDE_PLUGIN_ROOT}/references/api-manual.md
```

The manual holds every convention, default, and decision fork; the skills route into it rather than restating it (see [`CLAUDE.md`](CLAUDE.md)). To change behavior, edit the manual — not the skills. A generic [agent-native addendum](references/agent-native-addendum.md) extends it for APIs whose primary caller is an agent (atomic idempotent primitives, lean responses, MCP, confused-deputy hardening).

## How it thinks

- **Clarify before build** — ask only on breaking/irreversible unknowns; assume-and-document the rest into an API Brief, then proceed.
- **Smallest design that solves the outcome** — no architecture invented because it looks modern; microservices, gateways, queues only for a named problem.
- **Defaults with overrides** — every recurring fork has a default and an explicit "override when"; local convention always wins.
- **Contracts are the product** — names, payloads, status codes, errors, pagination, and auth are public contracts; compatibility is preserved unless a break is requested.
- **Verify, don't claim** — green gates are necessary, not sufficient; findings cite a runtime observation.

## Layout

```
api-architect/
├── assets/cover.png            # this hero image
├── .claude-plugin/
│   ├── plugin.json             # manifest (v0.2.0)
│   └── marketplace.json        # local single-plugin marketplace
├── skills/                     # architect · design · implement · test · review · document · evolve · discover
├── agents/                     # contract · security · compatibility · async reviewers
├── commands/                   # 7 slash commands, one per phase
├── hooks/                      # SessionStart + UserPromptSubmit manual injection
├── scripts/                    # schema-diff.sh · smoke-verify.sh
├── .github/workflows/          # api-compat.yml — CI compatibility gate
├── references/
│   ├── api-manual.md           # the source of truth (read live)
│   └── agent-native-addendum.md
└── CLAUDE.md
```

---

<div align="center"><sub>Built by <a href="https://yuno.to">Yuno</a> — AI development — for Claude&nbsp;Code · manual-driven · contract-first · agent-native</sub></div>
