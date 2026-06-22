---
name: api-document
description: "This skill should be used when the user wants to document an API or generate developer-facing artifacts from a contract — e.g. \"generate reference docs from the OpenAPI/proto\", \"write API docs\", \"generate an SDK / client library\", \"add worked examples to the spec\", \"write a getting-started / quickstart guide\", \"outline a developer portal\", \"document errors / pagination / auth for consumers\", \"add stability labels / deprecation notices to the docs\", or \"turn the contract into a published reference\". The DOCUMENT phase: turn the OpenAPI/proto/AsyncAPI contract into reference docs, SDKs, worked examples that are part of the contract, and a developer-portal outline."
---

<objective>
Drive the DOCUMENT phase of an API: turn the existing OpenAPI/proto/AsyncAPI contract into developer-facing artifacts — generated reference docs, generated SDKs/client libraries, worked examples that are themselves part of the contract, and a developer-portal outline. This is the lifecycle step the manual calls "prepare release and operation: docs, examples" (Default Operating Loop step 7) and the "explicit documented contract" the Agent Contract demands.

This SKILL.md is a router and a checklist. **The manual is the source of truth; if this skill and the manual disagree, the manual wins.** It never restates the manual — it points into the exact sections and enforces that they are read live before any doc, SDK, or example is generated.
</objective>

<authority>
Two reference files are authoritative. Read them live, every time — never paraphrase from this file:

- `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md` — the API Design and Development Manual.
- `${CLAUDE_PLUGIN_ROOT}/references/agent-native-addendum.md` — the agent-native parity + CRUD rules layered on top.

The contract (OpenAPI / protobuf / AsyncAPI / the repo's format) is the second source of truth for this phase: docs, SDKs, and examples are **generated from and validated against** it. Documentation never invents behavior the contract does not promise; if the docs and the contract disagree, the contract wins and the contract is fixed (or the work is handed back to api-design).
</authority>

<essential_principles>
These apply to every documentation task and cannot be skipped:

1. **Docs are generated from the contract, not written beside it.** Reference docs and SDKs derive from the OpenAPI/proto/AsyncAPI contract so they cannot drift. Hand-written prose is the connective tissue (concepts, guides, quickstart) around generated reference — never a parallel re-description of endpoints that can rot. If the contract lacks something the docs need (a description, an example, an error), fix the contract. (Manual: Agent Contract "explicit documented contract"; Default Operating Loop step 7.)
2. **Worked examples are part of the contract.** Every operation gets at least one worked request + response and at least one error example, carried in the spec (`examples`/`x-` fields or proto comments) so they are versioned, reviewed, and testable — not pasted into a wiki. Examples must be runnable and must validate against the schemas they illustrate. (Manual: Endpoint Design template "Examples"; Request and Response Design.)
3. **Names in docs are the contract's names.** Generated reference and SDKs carry the exact resource/field/method names, units, and casing from the contract. Do not rename, abbreviate, or "clarify" a name in docs — that creates a second, conflicting contract. Surface the manual's Naming rules as documentation (units in names, no implementation terms) rather than re-coining them. (Manual: Resource-Oriented API Rules → Naming.)
4. **Docs reflect the compatibility promise.** Stability labels (stable/beta/deprecated), deprecation notices with a sunset date and migration path, and a consumer-facing changelog all mirror the manual's Compatibility rules. Documenting a field/endpoint as stable is a compatibility commitment; documenting a deprecation is the human-readable half of the retirement EVOLVE will execute. (Manual: Request and Response Design → Compatibility.)
5. **Docs are a security surface.** Examples and SDKs must never embed real secrets, tokens, internal hostnames, customer PII, or stack traces; auth docs must not teach an insecure pattern (e.g. an ID token used as an access token). Redact every example; document the real auth scheme, scopes, and rate-limit/`Retry-After` behavior consumers must handle. (Manual: Security Manual.)
6. **Agent-native parity in the docs.** The documentation must let an agent consumer — not just a human — succeed: every entity's full create/read/update/delete path is discoverable, errors are documented as retryable vs. terminal, and lean response shapes are shown. No documented user action without a documented agent path. (Addendum.)
</essential_principles>

<quick_start>
**FIRST OPERATIONAL STEP — do this before generating any doc, SDK, or example.**

Read the owned manual sections live (do not work from memory):

1. From `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md`, read the sections this skill owns (see `<manual_sections_owned>`): the **Agent Contract** and **Default Operating Loop step 7** (docs/examples as the release deliverable), **Resource-Oriented API Rules → Naming**, **Request and Response Design → Compatibility**, the **Endpoint Design** and **PR Summary** templates, plus the **Security Manual** (cross-cutting — examples/SDKs/auth docs are a security surface).
2. Read `${CLAUDE_PLUGIN_ROOT}/references/agent-native-addendum.md` in full — the agent-as-consumer rules shape what the docs must expose.

Then locate the contract to generate from. Do not document an API that has no contract — if there is no OpenAPI/proto/AsyncAPI, hand back to **api-design**; documentation is generated from a contract, never reverse-engineered from running code.
</quick_start>

<intake>
**Ask the user (skip only if the request already names one unambiguously):**

What documentation artifact is needed?
1. **Reference docs** — generate human reference (endpoints/messages, schemas, errors, auth, pagination) from the contract
2. **SDK / client library** — generate or outline a client in a target language from the contract
3. **Worked examples** — add request/response + error examples into the contract so they are versioned and testable
4. **Guides / quickstart** — getting-started, auth setup, pagination/error-handling, common-task guides around the generated reference
5. **Developer-portal outline** — the information architecture that ties reference + SDKs + guides + changelog together
6. Something else — clarify, then route

**Wait for the response, then confirm the contract exists and is current before generating.**
</intake>

<routing>
Read `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md` sections per row, plus the always-required Security Manual and the agent-native addendum. A task often spans rows — read every section it touches.

| Response | Read these manual sections (live), then generate | Deliverables |
|----------|--------------------------------------------------|--------------|
| 1, "reference docs", "API docs", "document endpoints" | Naming; Compatibility (stability labels); Error Design (consumer-facing error table); Request and Response Design (pagination/field rules to document); Security Manual (auth/abuse docs) | Generated reference (from the contract), error/status-code table, auth + pagination sections, stability labels per operation |
| 2, "SDK", "client library", "generate a client" | Naming (names carry into the SDK verbatim); Compatibility; Idempotency and Retries (retry/backoff the client must implement); Error Design (typed errors); Security Manual | Generated SDK (or generator config + outline), idempotency-key + retry/`Retry-After` handling, typed error model, redacted usage snippet |
| 3, "worked examples", "add examples", "example requests" | Endpoint Design template (Examples); Request and Response Design; Error Design; Security Manual (redaction) | At least one worked request+response and one error example per operation, embedded in the contract, validated against the schemas, secrets redacted |
| 4, "guide", "quickstart", "getting started", "how-to" | Agent Contract + Default Operating Loop step 7; Security Manual (auth setup); Idempotency and Retries; Compatibility | Quickstart, auth-setup guide, pagination/error-handling guide, common-task guides — all linking generated reference, no parallel endpoint re-description |
| 5, "developer portal", "portal outline", "docs site", "information architecture" | Default Operating Loop step 7; Compatibility (changelog/deprecation surface); Naming; Security Manual | Portal outline (use the template): landing, quickstart, auth, reference, SDKs, errors, pagination, changelog/deprecations, support — with the agent-native parity map |
| 6, other | Clarify, then pick the matching row(s) | — |

**After reading the section(s), generate against the contract exactly. Do not hand-describe behavior the contract does not promise; fix the contract or hand back to api-design.**
</routing>

<contract_to_docs>
The phase is not done until the artifacts are generated from, and consistent with, the contract:

- **Generate, don't transcribe.** Drive reference docs and SDKs from the OpenAPI/proto/AsyncAPI source via a generator (or, if generating by hand, treat the contract as the single input and re-derive on every change). Reuse the repo's existing doc/SDK toolchain before introducing a new one.
- **Examples live in the contract.** Put worked examples in the spec's `examples` (OpenAPI) / message comments (proto) / payload examples (AsyncAPI), so review and the schema-diff gate cover them. Each example must validate against its schema and must be runnable.
- **Document the consumer contract surface**, drawn from the manual: the error/status-code table, pagination convention (object-wrapped lists, opaque `pageToken`), idempotency-key usage for retryable writes, auth scheme + scopes, and `Retry-After` on `429`/`503`.
- **Carry stability + deprecation forward.** Label each operation/field stable/beta/deprecated; deprecations state a sunset date and migration path. This mirrors the compatibility promise; the schema-diff CI gate, versioning, and route retirement themselves belong to **api-evolve**.
- Use `templates/api-doc-outline.md` to structure the reference + portal and to verify every required consumer-facing section and the agent-native parity map are present.
</contract_to_docs>

<manual_sections_owned>
This skill (DOCUMENT phase) owns the docs/examples-as-contract thread — read these live from `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md`:

- **Agent Contract** + **Default Operating Loop step 7** — "explicit documented contract"; docs + examples as the release deliverable. (Primary ownership.)
- **Resource-Oriented API Rules → Naming** — names in docs/SDKs are the contract's names; surface the rules as documentation, do not re-coin them. (Grounding.)
- **Request and Response Design → Compatibility** — stability labels, deprecation notices, and the consumer changelog are the human-readable half of the compatibility promise. (Grounding — the doc surface only.)
- **Endpoint Design template** (Examples) and **PR Summary template** (the `Docs:` line) — examples are part of the contract; the docs line is a merge gate.
- **Security Manual** — required cross-cutting reading: examples/SDKs/auth docs must not leak secrets or teach insecure patterns.

Adjacent phases own the mechanics this phase only reflects: the **schema-diff CI gate, versioning, registry, and route retirement** belong to **api-evolve**; the contract's shape (endpoints, error shapes, pagination decisions) is decided in **api-design**. This phase documents those decisions; it does not make or change them.
</manual_sections_owned>

<security_checklist>
Before any documentation artifact is "done", confirm against the manual's Security Manual — read live, not from memory:

- No example, SDK snippet, or fixture embeds a real secret, API key, bearer token, customer PII, internal hostname, SQL, or stack trace — all redacted/placeholdered.
- Auth docs describe the real scheme and scopes and never teach an insecure pattern (e.g. an ID token used as an access token); token handling shown is the secure path.
- Error documentation does not reveal internal structure (no stack traces, internal IDs, or implementation terms in the documented error bodies).
- Abuse-control behavior consumers must handle is documented: rate limits, `429`/`503`, and `Retry-After`.
- Deprecation/stability labels do not advertise an unsupported or insecure endpoint as usable.
</security_checklist>

<templates_index>
In `templates/`:

| Template | Use |
|----------|-----|
| `api-doc-outline.md` | Structure the generated reference and the developer-portal outline: required consumer-facing sections (overview, auth, reference, errors, pagination, examples, SDKs, changelog/deprecations), per-operation reference shape, and the agent-native parity map — all derived from and pointing back to the contract |
</templates_index>

<reference_index>
**Manual (source of truth):** `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md`
Owned: Agent Contract + Default Operating Loop step 7 (docs/examples as deliverable); Naming; Compatibility (doc surface); Endpoint Design + PR Summary templates. Required cross-cutting: Security Manual.

**Agent-native addendum:** `${CLAUDE_PLUGIN_ROOT}/references/agent-native-addendum.md`
Agent-as-consumer rules: discoverable CRUD per entity, machine-actionable (retryable vs. terminal) errors, lean response shapes — documentation must expose these.
</reference_index>

<lifecycle_handoff>
This is the DOCUMENT phase (design → implement → review → **document** → evolve). Hand off when the task is actually a different phase:
- The contract is missing, wrong, or a new endpoint/resource is needed → **api-design** (docs are generated from a contract, not invented).
- The doc reveals an implementation gap (handler doesn't match the documented contract) → **api-implement**.
- Pre-merge gate, conformance audit, adversarial review → **api-review**.
- The schema-diff CI gate, versioning, deprecation/retirement mechanics, registry → **api-evolve** (this phase writes the human-readable deprecation notice; EVOLVE executes the retirement).
</lifecycle_handoff>

<success_criteria>
The DOCUMENT phase is complete when:
- [ ] The owned manual sections and the agent-native addendum were read live this session (not from memory).
- [ ] A current contract (OpenAPI/proto/AsyncAPI) exists and every artifact was generated from it and validates against it — no hand-transcribed endpoint descriptions that can drift.
- [ ] Reference docs cover every operation with the contract's exact names, plus the consumer-facing error/status-code table, pagination convention, idempotency usage, and auth scheme.
- [ ] Worked examples (≥1 success + ≥1 error per operation) live in the contract, are runnable, and validate against their schemas.
- [ ] SDK (or generator config + outline) carries the contract's names and documents idempotency-key, retry/`Retry-After`, and typed errors.
- [ ] Stability labels and any deprecation notices (sunset date + migration path) reflect the compatibility promise; the schema-diff/versioning/retirement mechanics are deferred to api-evolve.
- [ ] A developer-portal outline ties reference + SDKs + guides + changelog together.
- [ ] Security checklist satisfied: no leaked secrets/PII/internals in examples or SDKs; auth docs teach the secure path; abuse-control behavior documented.
- [ ] Agent-native parity holds: every entity's CRUD path is discoverable in the docs and errors are documented as retryable vs. terminal; no documented user action lacks a documented agent path.
</success_criteria>
