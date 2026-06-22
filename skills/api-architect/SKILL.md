---
name: api-architect
description: This skill should be used when the user wants to design, build, implement, review, evolve, version, scale, test, document, or discover an API (REST/HTTP, gRPC, GraphQL, events/async, webhooks) — e.g. "design an API for X", "add an endpoint", "review this API/PR for API issues", "make this a breaking/non-breaking change", "version this API", "split this into a service", "write tests for this API", "document this API", "map an undocumented API", or any task that creates or changes an API contract. It is the single entry point that routes to the api-design, api-implement, api-test, api-review, api-evolve, api-document, and api-discover phase skills.
---

<objective>
This is the umbrella router and single entry point for all API work. It encodes the manual's non-negotiable operating stance — the Agent Contract, Clarify-vs-Assume, and the Default Operating Loop — then routes to the phase skills based on the API job at hand.

The loop is iterative, not linear: phases overlap and you will revisit them (a review finds a contract gap → back to design; an evolution requires re-implementing → implement). **Security is cross-cutting** — it is designed in during design, enforced during implement, audited during review, and re-checked on every evolution; no phase skips it.

**The manual is the source of truth. If this skill and the manual disagree, the manual wins.** (Stated once here for the whole plugin — the phase skills do not repeat it.)
</objective>

<essential_principles>
The operating stance for all API work — at a high level here; the detailed rules are owned by the manual. Read them live (see `<quick_start>`); do not run the loop from this summary.

- **Behave like a senior API engineer (Agent Contract).** State assumptions, design the contract before the implementation, treat the public surface as a contract, and do not invent architecture without a named problem. Detail: manual → **Agent Contract**.
- **Clarify-vs-Assume — the most consequential fork.** Ask the user only on breaking/irreversible unknowns (auth/tenancy, data ownership, compatibility promises, destructive blast radius); assume-and-document the rest in an API Brief. Detail: manual → **Clarify vs. Assume**.
- **Offer approaches before committing.** For any non-trivial job, present 2-3 approaches with trade-offs and a recommendation; let the user pick before the phase skill builds anything.
- **Confirm the Brief before building.** The API Brief is self-reviewed then user-confirmed before any contract or code is produced.
- **No placeholders.** Never ship `TODO`, `TBD`, stub handlers, or "fill in later" in a deliverable — the contract, code, and Brief must be complete or explicitly marked as an open question for the user.
- **Run the iterative loop:** clarify → boundary → style → contract → implement → verify → release. Phases overlap; re-enter as the work demands. Detail: manual → **Default Operating Loop**.
- **Local convention always wins** over a manual default; document a choice only when overriding one.
</essential_principles>

<quick_start>
**Step 1 — read the source of truth, live, before doing anything else.**

Read these now from the bundled references (do not work from memory; the manual reflects current guidance and the addendum adds agent-native parity rules):

1. `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md` — at minimum the **Agent Contract**, **Clarify vs. Assume**, **Default Operating Loop**, **Intake Checklist**, and **Defaults Table** sections.
2. `${CLAUDE_PLUGIN_ROOT}/references/agent-native-addendum.md` — the agent-native parity + CRUD rules that overlay every phase.

**Step 2 — gated intake (one question at a time).** First fix the phase. Ask (skip only if the message already makes the phase unambiguous):

> Which phase is this, and what's the API job? Are you **designing** a new API/contract, **implementing** a contract, **reviewing** an API or PR, **evolving** an existing API (versioning, deprecation, breaking change), **testing** a contract, **documenting** an API, or **discovering** an undocumented/existing API?

Most jobs touch several phases — name the dominant one to enter, then loop through the others as needed.

Then offer the **OPTIONAL grounding gate at workflow start, regardless of entry phase.** Grounding the work in existing code/contracts is OPTIONAL and skippable — never forced. Auto-detect signals of existing code/contracts in the working dir: a repo (`.git`; `src`/`app`/`lib` dirs), API specs (`openapi*.{yaml,yml,json}`, `*.proto`, `asyncapi*`), package manifests (`package.json`, `go.mod`, `pyproject.toml`, `Cargo.toml`, `pom.xml`). Then ask one question — **signals detected**: "Found existing code/contracts — ground the work by reading them (recommended), or proceed greenfield?"; **none detected**: "Greenfield, or point me to external contracts (deps/partners/upstream specs) to read?" If the user opts in, route the actual read to the phase skill — **api-design** owns the grounding gate and **api-discover** is the read mechanic (LOCAL code + EXTERNAL contracts → existing-surface map + gap). If the user declines, proceed greenfield. (DISCOVER and EVOLVE entries already read the surface as their core job — for them, the read is the work, not a separate gate.)

Then apply **Clarify-vs-Assume as a gate, not a questionnaire.** Ask **only** on a fact that is breaking or irreversible if guessed wrong — auth/tenancy model, data ownership, a compatibility promise to existing clients, or a destructive operation's blast radius. **One question per message; wait for the answer before the next.** Assume-and-document everything else in the API Brief and move on. Do not interrogate the user for facts you can safely default.

**Step 3 — offer approaches before committing (non-trivial jobs).** Once the breaking unknowns are resolved, present **2-3 approaches** with trade-offs and lead with your recommendation. Let the user pick. Skip only for a single-answer focused decision.

**Step 4 — confirm the Brief, then route.** The chosen phase skill produces or updates the API Brief. Self-review it (placeholder scan, internal consistency, scope, ambiguity) then ask the user to confirm before any contract or code is built. Then route to the phase skill (table below), read its SKILL.md, and follow it — it routes you into the specific manual sections it needs.

**No placeholders in any deliverable** — see `<essential_principles>`.
</quick_start>

<routing>
Match the user's intent to the entry phase. The phase skills live in sibling directories under `skills/`.

| User wants to… (keywords) | Entry phase skill |
| --- | --- |
| Design a new API, draft/shape a contract, choose boundary or API style, model resources, "design an API for X", greenfield | `skills/api-design/SKILL.md` |
| Build/implement an endpoint or service from a contract, wire routes/handlers/validation/auth, "add an endpoint", "make this work" | `skills/api-implement/SKILL.md` |
| Review an API, PR, or existing surface for contract/security/compatibility issues; "is this API good", pre-merge gate | `skills/api-review/SKILL.md` |
| Evolve/version an existing API, deprecate, assess breaking-vs-non-breaking, expand-and-contract, migration | `skills/api-evolve/SKILL.md` |
| Test an API/contract — write contract/component/integration/CDC tests, the minimum endpoint test set, negative tests, smoke-verify a live endpoint | `skills/api-test/SKILL.md` |
| Document an API — author/generate reference docs, examples, changelog, an OpenAPI-driven portal, an agent/MCP-facing tool catalog | `skills/api-document/SKILL.md` |
| Discover/reverse-engineer an existing or undocumented API — map an unknown surface, infer the contract from traffic/code, produce a spec from what exists | `skills/api-discover/SKILL.md` |
| Unclear / spans many | Clarify with the intake question, then pick the dominant phase |

**Iterate, don't silo.** Entering one phase does not lock you in — a design that uncovers a compatibility promise loops to evolve; a review that finds a missing contract loops to design; an implementation that hits a boundary problem loops back to design; a discovery feeds design or review. Re-enter phases as the work demands.

**Security spans all phases.** The phase skills list the manual's **Security Manual** as required reading where it applies. Do not treat security as a single phase — it is threat-modeled in design, enforced in implement, audited in review, and re-checked on every evolution.

After reading the chosen phase skill, follow it exactly.
</routing>

<reference_index>
All domain knowledge lives in `${CLAUDE_PLUGIN_ROOT}/references/`:

- **api-manual.md** — the source of truth. Synthesized operational guide: Agent Contract, Clarify-vs-Assume, Operating Loop, Intake Checklist, Defaults Table, Boundary Rules, Style Matrix, Resource Rules, Request/Response Design, Error Design, Idempotency, Concurrency, **Security Manual**, Gateway/Mesh, Implementation Defaults, Node.js Defaults, Testing Matrix, Release/Evolution, Observability, Async/Event APIs, Pre-Merge Review Checklist, Templates (API Brief, Endpoint Design, ADR, PR Summary), Agent Prompt.
- **agent-native-addendum.md** — agent-native parity + CRUD overlay: every user-facing action and entity must have an agent-reachable path (full create/read/update/delete); outcomes composed from atomic primitives, not choreographed code.

The phase skills point into the specific manual sections each one needs; they do not duplicate manual content.
</reference_index>

<workflows_index>
The phase skills, each a focused entry point under `skills/`:

| Phase skill | Purpose |
| --- | --- |
| api-design | Clarify the job, choose boundary + style, draft the contract (Brief + Endpoint Design); design security in. |
| api-implement | Build the contract surgically in the repo's layering; edge validation, field allow-listing, auth at the data owner, idempotency, observability. |
| api-review | Audit an API/PR against the Pre-Merge Review Checklist + Security Manual; compatibility and contract conformance. |
| api-evolve | Version, deprecate, assess breaking-vs-non-breaking, expand-and-contract, migration notes, registry/de-registration. |
| api-test | Write the manual's Testing Matrix coverage — contract/component/integration/CDC, the minimum endpoint test set, negative tests; smoke-verify live. |
| api-document | Author/generate reference docs, examples, changelog, OpenAPI-driven portal, agent/MCP tool catalog. |
| api-discover | Map an unknown/undocumented API surface and reconstruct its contract from code, traffic, or behavior. |
</workflows_index>

<success_criteria>
A well-run entry through this router:
- Read api-manual.md (Agent Contract, Clarify-vs-Assume, Operating Loop, Defaults Table) and agent-native-addendum.md live before any API work.
- Offered the optional grounding gate at workflow start (auto-detected signals, asked once whether to ground or go greenfield) and routed any opted-in read to api-design/api-discover — never forced it.
- Ran the gate, not a questionnaire — asked only on breaking/irreversible unknowns, one question at a time; assumed-and-documented the rest in an API Brief.
- Offered 2-3 approaches with a recommendation before committing on any non-trivial job.
- Self-reviewed the API Brief and got user confirmation before any contract or code was built.
- Produced no placeholders / TODO stubs — every deliverable is complete or marked as an explicit open question.
- Routed to the correct dominant phase skill and followed it, re-entering other phases as the work demanded.
- Treated security as cross-cutting, not a single phase.
- Took manual defaults except where a documented local convention or explicit override applied.
</success_criteria>
