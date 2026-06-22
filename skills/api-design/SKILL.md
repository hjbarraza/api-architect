---
name: api-design
description: "This skill should be used when the user wants to \"design an API\", \"draft an API contract\", \"create an OpenAPI/proto/AsyncAPI spec\", \"add an endpoint\", \"model a resource\", \"choose between REST/gRPC/GraphQL/events\", \"decide service vs monolith boundaries\", \"design request/response/error shapes\", \"pick status codes / pagination / idempotency\", or starts any new API surface before implementation. The DESIGN phase: clarify, choose boundary and style, and produce a contract-first OpenAPI/proto draft."
---

<objective>
Drive the DESIGN phase of an API: turn a request into a clarified scope, a chosen boundary, a chosen style, and a contract-first OpenAPI/proto/AsyncAPI draft plus an API Brief and per-endpoint design notes. Security is designed in here, not bolted on later. This skill routes into the manual; it never restates it.
</objective>

<authority>
This SKILL.md is a router and a checklist — all design rules, tables, and rationale live in the manual and the addendum. Do not design from memory; read the relevant manual sections live each time. (The umbrella api-architect skill states the manual's authority once for the whole plugin; it is not repeated here.)

Two reference files (read live, never paraphrase from here):
- `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md` — the API Design and Development Manual.
- `${CLAUDE_PLUGIN_ROOT}/references/agent-native-addendum.md` — the agent-native parity + CRUD rules layered on top of the manual.
</authority>

<essential_principles>
These apply to every design task and cannot be skipped:

1. **Clarify vs. Assume — gate, not questionnaire.** Ask the user only when the missing fact is breaking or irreversible — auth/tenancy model, data ownership, a compatibility promise to existing clients, or a destructive operation's blast radius. **One question per message; wait for the answer before the next.** Assume and document everything else, then proceed on the manual's no-details defaults. Record every assumption in the API Brief. (Manual: "Clarify vs. Assume", "Intake Checklist", "Defaults Table".)
2. **Offer approaches before committing.** For any non-trivial surface, present 2-3 approaches (e.g. boundary or style options) with trade-offs and lead with a recommendation; let the user pick before drafting the contract. Skip only for a single-answer focused decision.
3. **Confirm the Brief before building.** Self-review the API Brief (placeholder scan, internal consistency, scope, ambiguity) then ask the user to confirm it before producing the contract draft. No contract is built on an unconfirmed Brief.
4. **No placeholders.** The Brief, the contract, and the endpoint-design notes ship complete — never `TODO`, `TBD`, stub schemas, or "fill in later". An undecided point is an explicit open question for the user, not a silent gap.
5. **Contract first.** Produce or update the spec (OpenAPI / protobuf / AsyncAPI / the repo's format) before any implementation. The contract is the deliverable of this phase. (Manual: "Default Operating Loop" step 4, "Templates".)
6. **Smallest correct boundary, smallest correct style.** Do not split services without a named reason; default to REST/resource-oriented HTTP + JSON and add a second style only for a named separable need. Name the coupling you create. (Manual: "Boundary Rules", "Coupling Diagnosis", "API Style Decision Matrix".)
7. **Security starts in design.** Auth model, per-endpoint and per-resource authorization, write-path field allow-listing, validation, and abuse controls are designed now — the gateway is defense-in-depth, never the authority. (Manual: "Security Manual" — required reading for every design task.)
8. **Agent-native parity — scoped.** A capability map (every user-facing action and every entity has an agent-reachable path with full create/read/update/delete; no orphan UI actions) is **REQUIRED** when the API is **agent-facing** (an LLM/MCP caller is a named consumer) **or backs a UI**. For a pure internal service-to-service or partner-webhook API with no agent consumer and no UI, parity is **ADVISORY** — note where a future agent path would go, but do not block the design on it. (Addendum.)
</essential_principles>

<quick_start>
Before anything else, read the relevant manual sections AND the addendum live:

1. From `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md`, read the sections this skill owns (see `<manual_sections_owned>`). Always read the **Security Manual** section — security is cross-cutting and starts at design.
2. Then read `${CLAUDE_PLUGIN_ROOT}/references/agent-native-addendum.md` — parity + CRUD shape every agent-facing or UI-backing design (see principle 8 for scope).

Read the workflow-specific sections named in `<routing>` for the chosen task. Do not proceed on memory of the manual.
</quick_start>

<intake>
Run a gated intake — fix the task, offer the optional grounding gate, then clarify only breaking unknowns one at a time, then offer approaches.

**Step 1 — fix the task. Ask:**

What is the design task?
1. New API surface from scratch (clarify → boundary → style → full contract draft)
2. Add or revise endpoints / resources on an existing API
3. A focused decision only (style choice, boundary, status codes, pagination, idempotency, error shape)

**Step 2 — offer the OPTIONAL grounding gate (auto-detect, then ask ONE question at start).** Reading the existing code/contracts is OPTIONAL and skippable — never forced. First auto-detect signals of existing code/contracts in the working dir: a repo (`.git`; `src`/`app`/`lib` dirs), API specs (`openapi*.{yaml,yml,json}`, `*.proto`, `asyncapi*`), package manifests (`package.json`, `go.mod`, `pyproject.toml`, `Cargo.toml`, `pom.xml`). Then ask one question:
- **Signals detected** → "Found existing code/contracts — ground the design by reading them (recommended), or design greenfield?"
- **None detected** → "Greenfield, or point me to external contracts (deps/partners/upstream specs) to read?"

Only if the user opts in, run the grounding read: LOCAL (data models/schema, existing routes/handlers, services, callers, repo conventions = error shape, auth, pagination, naming) + EXTERNAL (dependency/partner/upstream OpenAPI/proto/AsyncAPI). Output: an **existing-surface map** + the **GAP** (which resources/endpoints to develop and how they fit) that feeds the contract-first design. You may delegate the read mechanics to the **api-discover** skill (its grounding-read job). If the user declines, proceed greenfield — no grounding read. Either way continue to Step 3.

**Step 3 — clarify the gate, not the questionnaire.** Run the Intake Checklist (manual) and apply Clarify-vs-Assume: ask **only** on breaking/irreversible unknowns (auth/tenancy, data ownership, compatibility promise, destructive blast radius) — **one question per message, wait for each answer**. Assume-and-document the rest in the API Brief. One of the facts to establish here: **is the API agent-facing or UI-backing?** — it sets whether parity is required or advisory (principle 8).

**Step 4 — offer approaches.** For options 1-2, present 2-3 approaches (boundary/style/shape) with trade-offs and a recommendation; let the user pick. For option 3, just make the decision with its trade-off.

**Step 5 — write the Brief, self-review it, and get user confirmation before drafting any contract.**
</intake>

<routing>
| Response | Read these manual sections (live), then design | Deliverables |
|----------|-----------------------------------------------|--------------|
| 1, "new API", "from scratch", "design an API" | Clarify-vs-Assume; Intake Checklist; Boundary Rules + Coupling Diagnosis; API Style Decision Matrix; Resource-Oriented API Rules; Request and Response Design; Defaults Table; **Security Manual** + addendum | `api-brief.md`, OpenAPI/proto draft, `endpoint-design.md` per endpoint, capability map, `adr.md` for each consequential fork |
| 2, "add endpoint", "new resource", "revise" | Resource-Oriented API Rules; Request and Response Design; Defaults Table; Compatibility (under Request/Response); **Security Manual** + addendum | Updated spec, `endpoint-design.md` for the new/changed endpoints, capability-map delta, `adr.md` if a fork is consequential |
| 3, "which style", "boundary", "status code", "pagination", "idempotency", "error shape" | The matching section(s): API Style Decision Matrix / Boundary Rules + Coupling Diagnosis / Defaults Table / Request and Response Design; **Security Manual** if the decision touches auth, tenancy, or write paths | `adr.md` capturing the decision, alternatives, consequences, and how it is verified |

**After reading, follow the manual exactly. Apply the Defaults Table to any unresolved fork and document only overrides.**
</routing>

<contract_first>
The phase is not done until a contract draft exists:

- **Format:** OpenAPI 3.1 (YAML) for REST/HTTP; protobuf for gRPC; AsyncAPI for event APIs. If the repo already has a contract format or API standard, match it.
- **Must include:** paths/methods (or services/methods/messages), opaque string IDs, request/response/error schemas, auth scheme, pagination on every list, explicit validated filters/sorts, idempotency rules for retryable writes, PATCH/field-mask semantics, and at least one worked example per operation.
- **List responses** are always an object wrapper, never a bare array (Defaults Table).
- Use `templates/endpoint-design.md` to think through each operation before writing it into the spec; use `templates/api-brief.md` to anchor the whole surface; use `templates/adr.md` for each consequential decision.
</contract_first>

<manual_sections_owned>
This skill (DESIGN phase) owns these manual sections — read them live from `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md`:

- Clarify vs. Assume
- Intake Checklist
- Boundary Rules + Coupling Diagnosis
- API Style Decision Matrix
- Resource-Oriented API Rules (Resource Design, Naming, Hierarchy and IDs, Standard Methods, Field Masks and Partial Updates, Custom Methods, Long-Running Operations)
- Request and Response Design (Field Rules, Compatibility, Pagination, Filtering and Sorting, Batch and Bulk Operations)
- Error Design (contract-time error shapes and status-code decisions)
- Idempotency and Retries (idempotency keys and retry-safe write semantics decided at contract time)
- Defaults Table
- **Security Manual** (required reading — security starts at design)

Error Design and Idempotency and Retries are decided at contract time here, then exercised again in IMPLEMENT. Adjacent phases own the rest: Concurrency and Preconditions, Testing Matrix, Release and Evolution, Pre-Merge Review belong to IMPLEMENT/REVIEW/EVOLVE skills.
</manual_sections_owned>

<security_checklist>
Security is designed in this phase, not deferred. Before the contract is "done", confirm against the manual's Security Manual:

- Authentication scheme chosen per the manual (never an ID token as an access token).
- Authorization defined per endpoint **and** per resource; ownership/tenancy checks land in the data-owning service, not only the gateway (confused-deputy).
- Write paths bind an explicit per-endpoint allow-list of writable fields; reject unknown fields (mass-assignment).
- Edge validation defined for path/query/headers/body/content-type/size; every service still validates independently.
- Abuse controls named for abuse-prone endpoints (rate limit vs. load shed; fail-open vs. fail-closed stated for edge components).
- No secrets, tokens, stack traces, SQL, or internal hostnames in any response schema.
- Bulk delete by filter defaults to preview/validate-only and requires an explicit `force` flag (a missing filter/flag deletes nothing).
</security_checklist>

<templates_index>
In `templates/` (copied/adapted from the manual's Templates section):

| Template | Use |
|----------|-----|
| `api-brief.md` | Anchor the whole surface: consumer, outcome, owner, style, authz, sensitive data, compatibility promise, endpoints, assumptions, open questions |
| `endpoint-design.md` | Think through one operation before writing it into the spec: purpose, auth, idempotency, request/response/errors, pagination/filtering, side effects, timeout/retry, examples, tests, agent-native parity |
| `adr.md` | Record each consequential design fork: context, decision, alternatives, consequences, verification, rollback/migration |
</templates_index>

<success_criteria>
The DESIGN phase is complete when:
- [ ] The relevant manual sections and the addendum were read live this session (not from memory).
- [ ] Optional grounding gate offered at start: signals auto-detected, the user asked once whether to ground (or go greenfield); if opted in, an existing-surface map + gap were produced (read done here or via api-discover) and fed the contract; if declined, greenfield proceeded. The gate was offered, never forced.
- [ ] Intake Checklist answered; Clarify-vs-Assume applied as a gate (only breaking unknowns asked, one at a time); assumptions and open questions recorded in the API Brief.
- [ ] For non-trivial surfaces, 2-3 approaches were offered with a recommendation before the contract was drafted.
- [ ] The API Brief was self-reviewed and user-confirmed before the contract draft was produced.
- [ ] No placeholders: the Brief, contract, and endpoint-design notes are complete; any undecided point is an explicit open question, not a silent gap.
- [ ] Boundary chosen with the coupling named; style chosen via the Decision Matrix with any second style justified.
- [ ] A contract-first OpenAPI/proto/AsyncAPI draft exists, with list wrappers, validated filters, pagination, idempotency rules, PATCH/field-mask semantics, and worked examples.
- [ ] Security checklist satisfied: auth, per-endpoint + per-resource authz, write-path allow-listing, validation, abuse controls, safe error/response shapes.
- [ ] Agent-native parity handled per scope: a capability map (every user action + entity has an agent CRUD path; no orphan UI actions) is present when the API is agent-facing or UI-backing; for a pure internal/partner-webhook API it is advisory and its absence is acknowledged, not a gap.
- [ ] Every consequential fork has an ADR; every default override is documented.
</success_criteria>
