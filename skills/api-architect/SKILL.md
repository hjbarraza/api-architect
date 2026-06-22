---
name: api-architect
description: This skill should be used when the user wants to design, build, implement, review, evolve, version, or scale an API (REST/HTTP, gRPC, GraphQL, events/async, webhooks) — e.g. "design an API for X", "add an endpoint", "review this API/PR for API issues", "make this a breaking/non-breaking change", "version this API", "split this into a service", or any task that creates or changes an API contract. It is the single entry point that routes to the api-design, api-implement, api-review, and api-evolve phase skills.
---

<objective>
This is the umbrella router and single entry point for all API work. It encodes the manual's non-negotiable operating stance — the Agent Contract, Clarify-vs-Assume, and the Default Operating Loop — then routes to the four phase skills (api-design, api-implement, api-review, api-evolve) based on the API job at hand.

The loop is iterative, not linear: phases overlap and you will revisit them (a review finds a contract gap → back to design; an evolution requires re-implementing → implement). **Security is cross-cutting** — it is designed in during design, enforced during implement, audited during review, and re-checked on every evolution; no phase skips it.

The manual is the source of truth. If this skill and the manual disagree, the manual wins.
</objective>

<essential_principles>
The operating stance for all API work — at a high level here; the detailed rules are owned by the manual. Read them live (see `<quick_start>`); do not run the loop from this summary.

- **Behave like a senior API engineer (Agent Contract).** State assumptions, design the contract before the implementation, treat the public surface as a contract, and do not invent architecture without a named problem. Detail: manual → **Agent Contract**.
- **Clarify-vs-Assume — the most consequential fork.** Ask the user only on breaking/irreversible unknowns (auth/tenancy, data ownership, compatibility promises, destructive blast radius); assume-and-document the rest in an API Brief. Detail: manual → **Clarify vs. Assume**.
- **Run the iterative loop:** clarify → boundary → style → contract → implement → verify → release. Phases overlap; re-enter as the work demands. Detail: manual → **Default Operating Loop**.
- **Local convention always wins** over a manual default; document a choice only when overriding one.
</essential_principles>

<quick_start>
**Step 1 — read the source of truth, live, before doing anything else.**

Read these now from the bundled references (do not work from memory; the manual reflects current guidance and the addendum adds agent-native parity rules):

1. `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md` — at minimum the **Agent Contract**, **Clarify vs. Assume**, **Default Operating Loop**, **Intake Checklist**, and **Defaults Table** sections.
2. `${CLAUDE_PLUGIN_ROOT}/references/agent-native-addendum.md` — the agent-native parity + CRUD rules that overlay every phase.

The manual is the source of truth. If this skill and the manual disagree, the manual wins.

**Step 2 — intake.** Ask the user (skip only if the message already makes the phase unambiguous):

> Which phase is this, and what's the API job? Are you **designing** a new API/contract, **implementing** an existing or just-drafted contract, **reviewing** an API or PR, or **evolving** an existing API (versioning, deprecation, breaking-vs-non-breaking change)?

Most jobs touch several phases — name the dominant one to enter, then loop through the others as needed.

**Step 3 — route** to the phase skill (table below), read its SKILL.md, and follow it. The phase skill will route you into the specific manual sections it needs.
</quick_start>

<routing>
Match the user's intent to the entry phase. The phase skills live in sibling directories under `skills/`.

| User wants to… (keywords) | Entry phase skill |
| --- | --- |
| Design a new API, draft/shape a contract, choose boundary or API style, model resources, "design an API for X", greenfield | `skills/api-design/SKILL.md` |
| Build/implement an endpoint or service from a contract, wire routes/handlers/validation/auth, "add an endpoint", "make this work" | `skills/api-implement/SKILL.md` |
| Review an API, PR, or existing surface for contract/security/compatibility issues; "is this API good", pre-merge gate | `skills/api-review/SKILL.md` |
| Evolve/version an existing API, deprecate, assess breaking-vs-non-breaking, expand-and-contract, migration | `skills/api-evolve/SKILL.md` |
| Unclear / spans many | Clarify with the intake question, then pick the dominant phase |

**Iterate, don't silo.** Entering one phase does not lock you in — a design that uncovers a compatibility promise loops to evolve; a review that finds a missing contract loops to design; an implementation that hits a boundary problem loops back to design. Re-enter phases as the work demands.

**Security spans all phases.** The api-design, api-implement, and api-review skills each list the manual's **Security Manual** as required reading. Do not treat security as a single phase — it is threat-modeled in design, enforced in implement, and audited in review.

After reading the chosen phase skill, follow it exactly.
</routing>

<reference_index>
All domain knowledge lives in `${CLAUDE_PLUGIN_ROOT}/references/`:

- **api-manual.md** — the source of truth. Synthesized operational guide: Agent Contract, Clarify-vs-Assume, Operating Loop, Intake Checklist, Defaults Table, Boundary Rules, Style Matrix, Resource Rules, Request/Response Design, Error Design, Idempotency, Concurrency, **Security Manual**, Gateway/Mesh, Implementation Defaults, Node.js Defaults, Testing Matrix, Release/Evolution, Observability, Async/Event APIs, Pre-Merge Review Checklist, Templates (API Brief, Endpoint Design, ADR, PR Summary), Agent Prompt.
- **agent-native-addendum.md** — agent-native parity + CRUD overlay: every user-facing action and entity must have an agent-reachable path (full create/read/update/delete); outcomes composed from atomic primitives, not choreographed code.

The phase skills point into the specific manual sections each one needs; do not duplicate manual content into any skill.
</reference_index>

<workflows_index>
The four phase skills, each a focused entry point under `skills/`:

| Phase skill | Purpose |
| --- | --- |
| api-design | Clarify the job, choose boundary + style, draft the contract (Brief + Endpoint Design); design security in. |
| api-implement | Build the contract surgically in the repo's layering; edge validation, field allow-listing, auth at the data owner, idempotency, observability. |
| api-review | Audit an API/PR against the Pre-Merge Review Checklist + Security Manual; compatibility and contract conformance. |
| api-evolve | Version, deprecate, assess breaking-vs-non-breaking, expand-and-contract, migration notes, registry/de-registration. |
</workflows_index>

<success_criteria>
A well-run entry through this router:
- Read api-manual.md (Agent Contract, Clarify-vs-Assume, Operating Loop, Defaults Table) and agent-native-addendum.md live before any API work.
- Applied Clarify-vs-Assume correctly — asked only on breaking/irreversible unknowns; assumed-and-documented the rest in an API Brief.
- Routed to the correct dominant phase skill and followed it, re-entering other phases as the work demanded.
- Treated security as cross-cutting, not a single phase.
- Took manual defaults except where a documented local convention or explicit override applied.
</success_criteria>
