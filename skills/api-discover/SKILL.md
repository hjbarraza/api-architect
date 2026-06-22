---
name: api-discover
description: "This skill should be used when the user wants to inventory, catalog, or take stock of an existing API surface before changing it — e.g. \"what endpoints do we have\", \"build/update the API registry/catalog\", \"inventory this API surface\", \"find all our routes/versions\", \"who consumes this API\", \"which endpoints are deprecated/beta/undocumented\", \"map our API ownership\", \"audit for shadow/untracked endpoints\", or \"find attack surface from stale versions\". Also the mechanic that performs the OPTIONAL grounding read for api-design: read existing LOCAL code (models/routes/services/conventions) and EXTERNAL contracts (dependency/partner/upstream OpenAPI/proto/AsyncAPI) to produce an existing-surface map plus the gap to develop. The DISCOVER/CATALOG phase: enumerate endpoints, versions, owners, consumers, and lifecycle state; build/update the registry the evolve phase relies on; flag untracked/beta routes as attack surface."
---

<objective>
Inventory an existing API surface and turn it into a maintained registry/catalog — the single source of truth the EVOLVE phase depends on. This is the DISCOVER/CATALOG phase router for the api-architect plugin. It enumerates every endpoint, version, owner, consumer, and lifecycle state across the surface, then records them in the registry so evolution, deprecation, and de-registration have something authoritative to act on. Discovery is also a security activity: untracked, undocumented, `beta`, and stale-version routes are attack surface, and the deliverable explicitly flags them.

This skill is also the GROUNDING-READ mechanic for api-design. When DESIGN (or the umbrella) offers the optional grounding gate and the user opts in, this skill performs the read of existing code and contracts and produces the artifacts DESIGN consumes — an existing-surface map and the gap (which resources/endpoints remain to develop and how they fit). The read spans LOCAL code (data models/schema, routes/handlers, services, callers, repo conventions = error shape, auth, pagination, naming) AND EXTERNAL contracts (dependency/partner/upstream OpenAPI/proto/AsyncAPI). This is the same enumerate-and-reconcile machinery; only the deliverable differs (a grounding map + gap for DESIGN, vs. a registry for EVOLVE). The registry/catalog purpose is unchanged.

This SKILL.md is a router, not the knowledge. It selects a workflow and points into the manual. The manual at `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md` is the **source of truth**; if this skill and the manual ever disagree, **the manual wins**.
</objective>

<essential_principles>
These apply to every workflow below and cannot be skipped.

**1. The manual is authoritative; route, never paraphrase.**
Read the owned sections live from the manual at decision time. Do not catalog from a summary baked into this file. The registry/catalog requirement, the lifecycle states, and the attack-surface framing all live in the manual's **Release and Evolution** section — read it there.

**2. The registry is the deliverable, and it must be the source of truth.**
A discovery that does not produce or update a registry/catalog has not happened. The manual mandates maintaining a registry/catalog of every deployed API and version. The output of this phase is `api-registry.md` (or the repo's existing catalog), and it is what EVOLVE reads before any change.

**3. Catalog what *runs*, not just what is documented.**
The dangerous endpoints are the ones nobody wrote down. Reconcile the contract/spec (OpenAPI/proto/AsyncAPI) against the routing table actually wired in code, against deployed gateway/mesh routes, and against logs/metrics of real traffic. Every endpoint that serves a request belongs in the registry — including the ones the spec omits.

**4. Untracked, undocumented, `beta`, and stale-version routes are attack surface.**
This is the security spine of discovery. The manual is explicit: untracked old/`beta` endpoints may still expose fields newer versions removed. Every such route is flagged in the registry, not silently listed. Discovery feeds retirement: retirement means de-registration **and** route removal, never just a "deprecated" label.

**5. Every endpoint has an owner, a lifecycle state, and known consumers — or a flag saying it doesn't.**
An endpoint with no named owner is an operational and security gap; record it as `owner: UNKNOWN` and flag it, never leave the field blank. Map each route to its lifecycle state (planned → preview/beta → live → deprecated → retired) and to its known consumers, because EVOLVE cannot safely deprecate what it cannot attribute.

**6. Discovery is read-mostly; do not mutate the surface.**
Cataloging inventories the surface — it does not change routes, flip flags, or retire anything. Removal/de-registration is an EVOLVE action that *consumes* this registry. Keep discovery non-destructive; the only thing it writes is the catalog.

**7. Agent-native parity.**
The registry records, per entity and user-facing action, whether an agent-reachable CRUD path exists. A surfaced endpoint with no agent path is an incomplete surface and is flagged. This is governed by the addendum (see step 1).
</essential_principles>

<intake>
**Ask the user (skip only if the request already names one clearly):**

What is the discovery job?
1. **Full inventory from scratch** — no registry exists yet; enumerate the whole surface (spec + code routes + deployed/gateway routes + traffic) and build `api-registry.md`.
2. **Update / reconcile an existing registry** — a catalog exists; re-scan the surface, diff against it, add new routes, mark drift, and refresh lifecycle/owner/consumer data.
3. **Targeted audit** — hunt specifically for untracked/shadow/`beta`/deprecated/undocumented endpoints and report them as attack surface (registry-flag delta only).
4. **Grounding read for DESIGN** — the user opted into api-design's optional grounding gate. Read existing LOCAL code (data models/schema, routes/handlers, services, callers, repo conventions = error shape, auth, pagination, naming) AND EXTERNAL contracts (dependency/partner/upstream OpenAPI/proto/AsyncAPI). Produce an existing-surface map plus the GAP (which resources/endpoints to develop and how they fit), and hand both back to DESIGN. Read-only; no registry is required unless the user also wants one.
5. Something else — clarify, then route.

**Wait for the response before proceeding.** (When invoked by DESIGN/umbrella as the grounding mechanic, the job is already 4 — skip the question and proceed.)
</intake>

<process>
**Step 1 — Load the source of truth (ALWAYS first, before any scanning).**
Read these live, now, before doing anything else:

1. From `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md`, read the **owned sections**:
   - **Release and Evolution** (`## Release and Evolution`) — the registry/catalog mandate, the lifecycle states (planned → preview/beta → live → deprecated → retired), and the attack-surface / de-registration framing. **Primary owned section.**
   - **Boundary Rules** (`## Boundary Rules`, incl. **Coupling Diagnosis**) — to attribute each endpoint to a capability/owner and to recognize bad boundaries (shared schemas, pass-through hops, content coupling) that discovery exposes.
   - Plus always the framing sections: **Agent Contract**, **Clarify vs. Assume**, **Defaults Table**, and the **Security Manual** (`## Security Manual`) — the attack-surface judgment leans on the threat model.
2. Read `${CLAUDE_PLUGIN_ROOT}/references/agent-native-addendum.md` in full — it governs the parity/CRUD column in the registry (essential principle 7).

State plainly to yourself: the manual is the source of truth; if this skill and the manual disagree, the manual wins. Do not proceed on memory.

**Step 2 — Route.**
Use the table to pick the workflow lens, then apply the matching manual section(s) read in Step 1.

**Step 3 — Apply Clarify-vs-Assume.**
Ask the user only when the missing fact is breaking, irreversible, or unknowable from the repo: which environments/deployments count as "the surface" (prod only, or staging too), where the deployed gateway/mesh config and traffic logs live, and whether an unattributed endpoint is truly orphaned vs. owned by a team outside the repo. Assume-and-document everything else, and record assumptions in the registry's notes.

**Step 4 — Enumerate from every source, then reconcile (the core of discovery).**
Build the endpoint set by union of these sources, then reconcile per essential principle 3:
- **Contract/spec** — OpenAPI/proto/AsyncAPI files in the repo (the *documented* surface).
- **Code routes** — the routing table actually wired (route definitions, decorators, gateway route configs, handler registrations).
- **Deployed routes** — gateway/mesh/ingress config exposing routes in the running environment(s).
- **Live traffic** — access logs/metrics showing endpoints that actually serve requests.

For each endpoint capture: method + path (or service/method), version, lifecycle state, owner (or `UNKNOWN`), known consumers, whether it appears in the spec, and the agent-CRUD parity status. Use `templates/api-registry.md` as the catalog format. Cross-check sources: a route in code/deploy/traffic but **not** in the spec is undocumented → flag; a `beta` or old-version route still serving traffic → flag as attack surface; an endpoint with no owner → flag.

**Grounding-read variant (job 4 — read for DESIGN).** Same enumerate-and-reconcile machinery, two source classes, a different deliverable:
- **LOCAL** — data models/schema, existing routes/handlers, services and their callers, and the repo conventions DESIGN must conform to: error/response shape, auth model, pagination style, naming. (Use Boundary Rules + Coupling Diagnosis to attribute each piece and spot bad boundaries.)
- **EXTERNAL** — contracts the new surface must interoperate with: dependency, partner, and upstream OpenAPI/proto/AsyncAPI specs.
Reconcile into an **existing-surface map**, then derive the **GAP**: which resources/endpoints remain to be developed and how they fit the conventions and external contracts above. Hand the map + gap back to DESIGN as the grounding input to its contract-first design. Stay read-only; do not produce a registry unless the user also asked for one.

**Step 5 — Write/update the registry, then run the success criteria.**
Produce or update `api-registry.md` (or the repo's existing catalog format — local convention wins). Surgical changes only when updating. Do not mutate the API surface itself. Then verify against the success criteria below before claiming done, and hand the registry to EVOLVE for any retirement/de-registration decisions.
</process>

<routing>
| Response | Owned manual section(s) to apply | Lens |
|----------|----------------------------------|------|
| 1, "full inventory", "from scratch", "what endpoints do we have", "build the registry", "catalog the API" | Release and Evolution; Boundary Rules; Defaults Table; Security Manual | Union all four sources (spec + code + deploy + traffic), reconcile, attribute owner/consumer/lifecycle per endpoint, write `api-registry.md`. Flag every undocumented/`beta`/stale/unowned route. |
| 2, "update the registry", "reconcile", "re-scan", "what changed", "registry drift" | Release and Evolution; Boundary Rules; Security Manual | Re-scan sources, diff against the existing catalog, add new routes, mark drift (spec↔code↔deploy mismatch), refresh lifecycle/owner/consumer, re-flag attack surface. Surgical edits to the catalog only. |
| 3, "find shadow endpoints", "untracked", "beta", "deprecated", "undocumented", "attack surface audit" | Release and Evolution; Security Manual; Boundary Rules | Targeted hunt: routes in code/deploy/traffic absent from spec or registry; `beta`/old-version routes still live; unowned routes. Report each as attack surface with the manual's reasoning (may expose fields newer versions removed). Output a flag delta, recommend de-registration handoff to EVOLVE. |
| 4, "grounding read for DESIGN", "ground the design", invoked by api-design/umbrella | Boundary Rules + Coupling Diagnosis; Intake Checklist; Defaults Table; Security Manual | Read LOCAL code (models/schema, routes/handlers, services, callers, conventions = error shape/auth/pagination/naming) + EXTERNAL contracts (dep/partner/upstream OpenAPI/proto/AsyncAPI). Reconcile into an existing-surface map; derive the GAP (resources/endpoints to develop and how they fit existing conventions). Hand both back to DESIGN. Read-only; registry optional. |
| 5, other | Clarify, then route | — |

**After selecting, follow the manual section exactly. The manual wins over this table.**
</routing>

<quick_start>
Fast orientation only — **the manual is authoritative; verify there before acting.** Do step 1 (load the manual + addendum) before relying on any of this.

- **Discovery order:** enumerate from all four sources (spec → code routes → deployed/gateway routes → live traffic) → reconcile → attribute (owner / lifecycle / consumers / agent-CRUD) → flag attack surface → write the registry.
- **The catalog is the point.** The phase is not done until `api-registry.md` exists or is updated; an inventory living only in chat is not a registry.
- **Don't recall the rules — route.** The registry/catalog mandate, the exact lifecycle states, and the attack-surface / de-registration rule live in the manual's **Release and Evolution** section. Read them live there; do not act on a memorized version.
- **Discovery does not retire anything.** Flag and hand off; de-registration + route removal is an EVOLVE action.
</quick_start>

<templates_index>
In `templates/` (the catalog format, derived from the manual's Release and Evolution registry/catalog mandate):

| Template | Use |
|----------|-----|
| `api-registry.md` | The registry/catalog: one row per endpoint/version with method+path, version, lifecycle state, owner, known consumers, spec-documented?, agent-CRUD parity, and an attack-surface flag — plus a flagged-routes section and reconciliation notes. This is the artifact EVOLVE reads. |
</templates_index>

<reference_index>
All authoritative knowledge lives in the manual; this skill only routes into it.

- `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md` — source of truth. Owned sections: **Release and Evolution** (registry/catalog, lifecycle, attack-surface/de-registration), **Boundary Rules** (capability/owner attribution + Coupling Diagnosis). Always also read: Agent Contract, Clarify vs. Assume, Defaults Table, Security Manual.
- `${CLAUDE_PLUGIN_ROOT}/references/agent-native-addendum.md` — parity/CRUD rules that govern the agent-CRUD column in the registry.
</reference_index>

<success_criteria>
The discovery/catalog is well-handled when:
- The owned manual sections (Release and Evolution; Boundary Rules) and the agent-native addendum were read **live** this session, not recalled.
- A registry/catalog (`api-registry.md` or the repo's existing format) exists or was updated, and is stated to be the source of truth EVOLVE reads.
- The endpoint set is the reconciled union of spec, code routes, deployed/gateway routes, and live traffic — not the spec alone.
- Every endpoint has a method/path, version, lifecycle state (planned → preview/beta → live → deprecated → retired), an owner (or explicit `UNKNOWN`), and its known consumers.
- Every undocumented, `beta`, stale-version, or unowned route is **flagged as attack surface** with the manual's reasoning (may still expose fields newer versions removed); none are listed silently.
- Discovery did not mutate the surface; retirement is handed to EVOLVE as de-registration + route removal, never a "deprecated" label applied here.
- Agent-native parity is recorded per entity/action (agent-CRUD column); surfaced endpoints with no agent path are flagged.
- Spec↔code↔deploy↔traffic drift is recorded so EVOLVE and DESIGN can close it.
- When run as the grounding mechanic (job 4): LOCAL code (models/routes/services/conventions) and EXTERNAL contracts (dep/partner/upstream) were read live; an existing-surface map and the GAP (resources/endpoints to develop and how they fit) were produced and handed to DESIGN; the surface was not mutated.
</success_criteria>
