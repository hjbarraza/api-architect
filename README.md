# api-architect

A Claude Code plugin for designing, implementing, testing, reviewing, documenting, evolving, and discovering APIs the way a senior API engineer would: contract-first, smallest design that solves the outcome, behavior proven by tests, and the system left easier to operate.

Every skill is **manual-driven** — it reads a single source of truth, `references/api-manual.md`, live at runtime. Change the manual, change the behavior. No prompt forking, no stale copies.

## What it does

The plugin turns the API manual into operational behavior across the full lifecycle: clarify the job, choose the boundary, draft the contract, implement surgically, verify with focused tests, document the surface, prepare release and operation, and discover an existing API when there is no spec.

## Skills

- **`api-architect`** — umbrella skill. Routes an API task to the right phase (design / implement / test / review / document / evolve / discover) and runs the manual's default operating loop end to end.
- **`api-design`** — turn a consumer need into a contract: paths, methods, IDs, request/response/error bodies, auth, pagination, idempotency, examples. Includes design templates.
- **`api-implement`** — build the drafted contract surgically inside the repo's existing layering: validate at the edge, business rules in the service layer, storage and downstream calls behind adapters.
- **`api-test`** — prove behavior with focused tests: contract conformance, error paths, auth/tenancy boundaries, idempotency, and pagination edges. Pairs with the `smoke-verify.sh` script for a live check.
- **`api-review`** — review an API (or a diff) against the manual: naming, status codes, error shapes, auth, compatibility risk, and operability. Includes review templates and dispatches the reviewer agents.
- **`api-document`** — produce consumer-facing docs from the contract: endpoint reference, examples, error catalog, auth and pagination notes, changelog.
- **`api-evolve`** — change an existing API without surprising clients: compatibility rules, versioning, deprecation, migration notes. Pairs with the `schema-diff.sh` script and the compatibility Action.
- **`api-discover`** — reverse-engineer an undocumented API: map the surface from code and traffic, infer the contract, and surface the gaps.

## Agents

Bundled reviewer agents specialize the review phase — invoked by `api-review` (or directly) to scrutinize a contract or diff against the manual and report defensible findings tied to consumer impact, contract stability, security, and operability.

- **`api-contract-reviewer`** — HTTP/REST surface design: resource modeling, naming, ID exposure, pagination, error shape, status codes, idempotency, PATCH/field-mask semantics, backward compatibility.
- **`api-security-reviewer`** — security posture: threat model, authn/authz at the data owner, mass-assignment, the confused-deputy problem, abuse controls, the do-not-log list. Thinks like an attacker.
- **`api-compatibility-reviewer`** — breaking-change detection between versions: REST/JSON and protobuf rules, expand-and-contract migration, the CI schema-diff gate, versioning discipline. Compares old vs. new.
- **`api-async-reviewer`** — event/async, webhook, and saga design: event-contract shape, webhook signature/replay security, and saga compensation correctness.

## Commands

Seven slash commands map one-to-one onto the lifecycle skills, for when you want to invoke a phase explicitly:

`/api-design` · `/api-implement` · `/api-test` · `/api-review` · `/api-document` · `/api-evolve` · `/api-discover`

## Tooling

The plugin ships executable tooling, not just prompts:

- **Manual-injection hook** (`hooks/`) — a `SessionStart` hook injects the manual's location and the operating loop from turn one, and a `PreToolUse` hook re-injects the same pointer the instant API-shaped file or shell work begins (editing OpenAPI/proto specs or route/handler files, or running the server / curl / a schema-diff). It never blocks — it allows the tool and attaches the reminder as context, which is the strongest guaranteed-injection path available to command hooks.
- **`scripts/schema-diff.sh`** — compares two contract versions (OpenAPI / protobuf) and reports breaking vs. compatible changes; the backing tool for the compatibility gate.
- **`scripts/smoke-verify.sh`** — runs a focused live check against a running API to confirm the contract behaves as drafted.
- **Compatibility Action** (`.github/workflows/api-compat.yml`) — runs `schema-diff.sh` in CI to gate pull requests that introduce breaking API changes.

## How it stays grounded

Skills consult `references/api-manual.md` live via `${CLAUDE_PLUGIN_ROOT}`:

```
${CLAUDE_PLUGIN_ROOT}/references/api-manual.md
```

`${CLAUDE_PLUGIN_ROOT}` resolves to wherever the plugin is installed, so the path is portable across machines and install methods. The manual is the only source of conventions, defaults, and decision forks — see `CLAUDE.md`. The manual-injection hook keeps that read on the record rather than leaving it to voluntary recall.

## Install

```
/plugin marketplace add /path/to/api-architect
/plugin install api-architect@api-architect
```

Replace `/path/to/api-architect` with the directory where you cloned this repo. The first command registers that directory as a local single-plugin marketplace; the second installs the plugin from it. After install, the skills activate automatically when you ask Claude Code to design, build, test, review, document, evolve, or discover an API, and the manual-injection hook arms on the next session start.

## Layout

```
api-architect/
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest (v0.2.0)
│   └── marketplace.json     # local single-plugin marketplace
├── skills/
│   ├── api-architect/       # umbrella / router
│   ├── api-design/          # contract design (+ templates)
│   ├── api-implement/       # surgical implementation
│   ├── api-test/            # behavior tests
│   ├── api-review/          # review (+ templates)
│   ├── api-document/        # consumer-facing docs
│   ├── api-evolve/          # compatible evolution
│   └── api-discover/        # reverse-engineer an undocumented API
├── agents/                  # reviewer agents (contract / security / compatibility / async)
├── commands/                # 7 slash commands, one per lifecycle phase
├── hooks/
│   ├── hooks.json           # SessionStart + PreToolUse manual injection
│   └── inject-manual.sh     # injection script
├── scripts/
│   ├── schema-diff.sh       # breaking-change detector
│   └── smoke-verify.sh      # live contract check
├── .github/
│   └── workflows/
│       └── api-compat.yml   # CI compatibility gate (runs schema-diff)
├── references/
│   ├── api-manual.md        # source of truth (read live)
│   └── agent-native-addendum.md
└── CLAUDE.md
```
