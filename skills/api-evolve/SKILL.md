---
name: api-evolve
description: "This skill should be used when the user wants to evolve, version, deprecate, or operate an existing API without surprising clients — e.g. \"add a field without breaking clients\", \"deprecate this endpoint\", \"version this API\", \"set up a schema-diff CI gate\", \"expand-and-contract migration\", \"add observability/SLOs/structured logging to this service\", \"design an event/webhook\", \"make consumers idempotent\", \"build a saga\", \"decide CP vs AP for this capability\", or \"stand up a reporting database / read model\". Covers the EVOLVE and OPERATE phases: compatibility, release and evolution, observability and operations, and async/event APIs."
---

<objective>
Change and run an API after it ships — without breaking the clients depending on it. This is the EVOLVE/OPERATE phase router for the api-architect plugin. It owns four manual sections: **Compatibility**, **Release and Evolution** (expand-and-contract, schema-diff CI gate, versioning, API registry), **Observability and Operations**, and **Async and Event APIs** (events, sagas, per-capability CAP, reporting database).

This SKILL.md is a router, not the knowledge. It selects a workflow and points into the manual. The manual at `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md` is the **source of truth**; if this skill and the manual ever disagree, **the manual wins**.
</objective>

<essential_principles>
These apply to every workflow below and cannot be skipped.

**1. The manual is authoritative; route, never paraphrase.**
Read the owned sections live from the manual at decision time. Do not answer compatibility, release, observability, or async questions from memory or from a summary baked into this file — APIs break on the exact rule, not the gist.

**2. Compatibility is the default contract.**
Names, payloads, fields, error codes, status codes, auth, pagination, and ordering are public contracts. Preserve them unless a breaking change is **explicitly requested**. Default to expansion changes (add, never remove/rename) and tolerant readers. When unsure whether a change is breaking, treat it as breaking until the manual's Compatibility section says otherwise — and remember **protobuf/gRPC is stricter than JSON**.

**3. Versioning is the last resort, not the first move.**
Exhaust expansion changes, tolerant readers, the schema-diff gate, and expand-and-contract **before** minting a new version. Version only when semantics genuinely break.

**4. A breaking change is a release decision, not just a code change.**
Deployment ≠ release. Any risky change needs a controlled-release path (flag, canary, blue-green, shadow, parallel run, consumer opt-in, deprecation window) and a rollback plan. Old/`beta` endpoints left running are attack surface: retirement means de-registration and route removal, not a "deprecated" label.

**5. Security is cross-cutting — it does not stop at ship.**
Evolution and operation create their own security surface: untracked old versions exposing removed fields, leaking sensitive data in logs/telemetry, event payloads carrying secrets or internal DB shape, reporting stores granting direct table access. Every workflow here treats the manual's **Security Manual** as required reading.

**6. Agent-native parity.**
For every user-facing evolution/operation action and every entity touched, name the tool/primitive that lets an agent achieve the same outcome (create/read/update/delete). No orphan UI actions. This is governed by the addendum (see step 1).
</essential_principles>

<intake>
**Ask the user (skip only if the request already names one clearly):**

What are you doing to this API?
1. **Change the contract** — add/remove/rename a field, change a type, tighten validation, change status codes or ordering. (Compatibility + Release and Evolution)
2. **Version, deprecate, or retire** — mint a new version, run expand-and-contract, set up the schema-diff CI gate, manage the deprecation window, de-register an endpoint. (Release and Evolution)
3. **Make it operable** — add structured logging, request/trace IDs, metrics, SLOs, health/readiness, graceful degradation. (Observability and Operations)
4. **Design async / events** — events, webhooks, idempotent consumers, sagas, per-capability CP-vs-AP, reporting database / read model. (Async and Event APIs)
5. Something else — clarify, then route.

**Wait for the response before proceeding.**
</intake>

<process>
**Step 1 — Load the source of truth (ALWAYS first, before any analysis).**
Read these live, now, before doing anything else:

1. From `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md`, read the **owned sections** relevant to the chosen route:
   - **Compatibility** (`## Request and Response Design → ### Compatibility`) — for routes 1, 2.
   - **Release and Evolution** (`## Release and Evolution`) — for routes 1, 2.
   - **Observability and Operations** (`## Observability and Operations`) — for route 3.
   - **Async and Event APIs** (`## Async and Event APIs`) — for route 4.
   - Plus always the framing sections: **Agent Contract**, **Clarify vs. Assume**, **Defaults Table**, and the **Security Manual** (`## Security Manual`).
2. Read `${CLAUDE_PLUGIN_ROOT}/references/agent-native-addendum.md` in full — it governs the parity/CRUD requirement in essential principle 6.

State plainly to yourself: the manual is the source of truth; if this skill and the manual disagree, the manual wins. Do not proceed on memory.

**Step 2 — Route.**
Use the table to pick the workflow lens, then apply the matching manual section(s) read in Step 1.

**Step 3 — Apply Clarify-vs-Assume.**
Ask the user only when the missing fact is breaking or irreversible: a compatibility promise to existing clients, who owns the data, the auth/tenancy model, or a destructive/irreversible release step (retirement, flag flip in prod). Assume-and-document everything else.

**Step 4 — Execute, verifying against the manual.**
Do the work the manual prescribes for the route. Surgical changes only. Then run the success criteria below before claiming done.
</process>

<routing>
| Response | Owned manual section(s) to apply | Lens |
|----------|----------------------------------|------|
| 1, "add field", "remove", "rename", "change type", "tighten validation", "status code", "ordering" | Compatibility; Release and Evolution; Defaults Table; Security Manual | Classify the change as compatible vs. breaking (REST **and** protobuf rules). If compatible: expansion change + tolerant readers. If breaking: stop, go to route 2. Confirm the schema-diff gate covers it. |
| 2, "version", "deprecate", "retire", "expand-and-contract", "schema-diff gate", "registry", "migration" | Release and Evolution; Compatibility; Security Manual | Versioning last; prefer expand-and-contract. Stand up / verify the schema-diff CI gate. Pick a controlled-release path + rollback. Registry: retirement = de-registration + route removal. |
| 3, "logging", "request id", "trace", "metrics", "SLO", "health", "readiness", "degradation", "observability" | Observability and Operations; Security Manual | Minimum telemetry set; safe log fields; honor the do-not-log list (the manual's single canonical list); SLO candidates; graceful degradation as a per-downstream business decision. |
| 4, "event", "webhook", "saga", "idempotent consumer", "CAP", "CP vs AP", "reporting database", "read model", "queue" | Async and Event APIs; Idempotency and Retries; Security Manual | Events = past-tense facts with id/timestamp/producer+schema-version/correlation; idempotent consumers; saga orchestration vs. choreography; CP-vs-AP per capability; reporting DB as a versioned contract, never direct table access. |
| 5, other | Clarify, then route | — |

**After selecting, follow the manual section exactly. The manual wins over this table.**
</routing>

<quick_start>
Fast orientation only — **the manual is authoritative; verify there before acting.** Do step 1 (load the manual + addendum) before relying on any of this.

- **Break-avoidance order (operating stance):** expansion change → tolerant reader → schema-diff CI gate → expand-and-contract → (only then) version.
- **Don't recall the rules — route.** The exact compatible-vs-breaking lists (REST and protobuf), the event envelope, per-capability CAP guidance, and the canonical do-not-log list all live in the manual's owned sections. Read them live there per the routing table; do not act on a memorized version.
</quick_start>

<reference_index>
All authoritative knowledge lives in the manual; this skill only routes into it.

- `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md` — source of truth. Owned sections: **Compatibility**, **Release and Evolution**, **Observability and Operations**, **Async and Event APIs**. Always also read: Agent Contract, Clarify vs. Assume, Defaults Table, Security Manual.
- `${CLAUDE_PLUGIN_ROOT}/references/agent-native-addendum.md` — parity/CRUD + outcomes-not-workflows requirements for every action and entity this phase touches.
</reference_index>

<success_criteria>
The evolution/operation is well-handled when:
- The relevant owned manual section(s) and the agent-native addendum were read **live** this session, not recalled.
- Every contract change is explicitly classified compatible vs. breaking under **both** the REST and protobuf rules; breaking changes are acknowledged as such and not shipped silently.
- Versioning was reached for only after expansion changes, tolerant readers, the schema-diff gate, and expand-and-contract were considered.
- A schema-diff compatibility gate exists (or its absence is flagged) for any contract change; risky changes have a controlled-release path and a rollback plan.
- Retired endpoints are de-registered and routes removed — not merely labeled deprecated.
- Operability work meets the minimum telemetry set and never logs anything on the do-not-log list; SLOs and graceful-degradation decisions are named.
- Async designs use past-tense events with the required envelope, idempotent consumers, an explicit per-capability CP-vs-AP choice, and a reporting store treated as a versioned contract (no direct table access).
- Security implications of the change (stale versions, telemetry leakage, event-payload secrets, read-store access) were checked against the Security Manual.
- Agent-native parity holds: every user-facing action and entity has a named agent primitive (create/read/update/delete).
</success_criteria>
