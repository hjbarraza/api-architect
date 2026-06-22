---
name: api-implement
description: This skill should be used when the user asks to "implement an API", "build the endpoint", "wire up handlers/services/repositories", "add middleware", "make an API idempotent", "add idempotency keys", "handle retries", "add a circuit breaker / timeout / bulkhead", "add optimistic concurrency / ETag / If-Match", "design error responses / status codes", "build a Node API (Fastify/Express)", or otherwise turn an approved API design into running server code. It is the IMPLEMENT phase of the api-architect lifecycle (design → implement → review → evolve).
---

<objective>
Turn an approved API design into correct, resilient server code: layered structure, ordered middleware, idempotent mutations, retry-and-failure handling on every outbound call, optimistic concurrency, and a stable error contract. This is the IMPLEMENT phase — design decisions are assumed settled (route them back to api-design if not).

The manual is the source of truth. **If this skill and the manual disagree, the manual wins.** This router never restates manual content — it points into the exact sections and enforces that they are read before code is written.
</objective>

<quick_start>
**FIRST OPERATIONAL STEP — do this before writing or editing any code.**

Read the owned manual sections live (do not work from memory):

1. Open `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md` and read, in full:
   - **Implementation Defaults** — Layering, Middleware Order, Outbound Calls and Cascading Failure, Remote vs. In-Process APIs, Data Access
   - **Node.js API Defaults** (read even for non-Node stacks — the event-loop / graceful-shutdown / health-check principles generalize; apply the analogue)
   - **Idempotency and Retries**
   - **Concurrency and Preconditions**
   - **Error Design**
   - **Security Manual** — required reading for every implementation, with **Validation** and **Write-Path Safety: Mass Assignment** mandatory (mass-assignment and input validation are enforced in the service, not the gateway)

2. Open `${CLAUDE_PLUGIN_ROOT}/references/agent-native-addendum.md` and read it. Implementation must satisfy the agent-as-consumer rules: tools/endpoints are **idempotent** (safe to retry), responses are **lean** (return only what a caller needs to act, not the whole object graph), and errors are machine-actionable (retryable vs. terminal).

Treat the manual sections as the spec. This skill is the index and the order of operations; the manual holds the rules.
</quick_start>

<essential_principles>
Operating stance for every implementation below. The detailed rules live in the manual — read them live (see `<quick_start>` and `<routing>`); do not work from the summary here.

**1. Follow the repo, then the manual.** Use the repo's existing layering, error shape, validation library, and test tools before introducing new ones; the manual's defaults fill gaps, they do not override a working convention.

**2. Thin handlers, fat services.** Place each change in the right layer; handlers translate HTTP ↔ service and nothing more. Detail: manual → Implementation Defaults (Layering).

**3. Make writes safe and retries safe.** Idempotency is built by the service, not conferred by the method; mass-assignment, validation, and per-resource authorization are enforced in the service, not the gateway. Detail: manual → Idempotency and Retries; Security Manual (Validation, Write-Path Safety: Mass Assignment, Authorization).

**4. Make outbound calls resilient.** A slow downstream is more dangerous than a dead one. Detail: manual → Implementation Defaults (Outbound Calls and Cascading Failure).

**5. The error contract is part of the API.** Use the repo's error shape or the manual's; never leak internals. Detail: manual → Error Design.
</essential_principles>

<intake>
**Ask the user (skip only if the request already names one unambiguously):**

What does this implementation task need?
1. **Scaffold / structure** — lay out layering and middleware order for a new service or endpoint
2. **Endpoint + handler/service/repository** — implement a route end to end
3. **Idempotency & retries** — make a mutation safe to retry; add idempotency keys; set retry/backoff policy
4. **Concurrency & preconditions** — add optimistic concurrency (ETag / If-Match / version)
5. **Outbound resilience** — timeouts, bulkheads, circuit breakers on a downstream client
6. **Error design** — status codes and the error response contract
7. **Node.js specifics** — Fastify/Express defaults, event loop, graceful shutdown, health checks
8. Something else — clarify, then route

**Wait for the response before proceeding.**
</intake>

<routing>
Read `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md` sections per row, plus the always-required Security Manual (Validation + Mass Assignment) and the agent-native addendum. A task often spans rows — read every section it touches.

| Response | Manual sections to read, then apply |
|----------|--------------------------------------|
| 1, "scaffold", "structure", "layering", "middleware order" | Implementation Defaults → Layering, Middleware Order |
| 2, "endpoint", "handler", "service", "repository", "route" | Implementation Defaults → Layering, Data Access; Error Design; Security Manual → Validation, Mass Assignment |
| 3, "idempotent", "idempotency key", "retry", "dedup", "backoff" | Idempotency and Retries; Error Design (status codes for key conflicts) |
| 4, "concurrency", "ETag", "If-Match", "version", "precondition", "412" | Concurrency and Preconditions; Error Design (`409`/`412`) |
| 5, "outbound", "downstream", "timeout", "bulkhead", "circuit breaker", "cascading failure" | Implementation Defaults → Outbound Calls and Cascading Failure, Remote vs. In-Process APIs |
| 6, "error", "status code", "error shape", "error response" | Error Design |
| 7, "node", "fastify", "express", "event loop", "graceful shutdown", "health check" | Node.js API Defaults; Implementation Defaults (all); Security Manual → Validation |
| 8, other | Clarify intent, then pick the matching row(s) |

**After reading the section(s), implement against them exactly. Do not paraphrase the rules into code from memory — keep the manual open.**
</routing>

<process>
Apply this order regardless of which row routed the task:

**Step 1 — Read.** Complete the first operational step and the routed manual sections above. Confirm the design is approved; if a design decision is open, hand back to api-design rather than inventing one here.

**Step 2 — Place the code in the right layer.** Map each change to routes / schemas / handlers / services / repositories / clients / middleware / observability. Keep handlers thin.

**Step 3 — Make writes safe.** For any mutation: allow-list writable fields per endpoint (never bind the body to a persistence entity); validate at the edge with the repo's schema library; decide and implement idempotency before retries are possible.

**Step 4 — Make outbound calls resilient.** For any synchronous downstream call: config base URL, timeout, bounded jittered retry, bulkhead pool, circuit breaker, trace/request-ID propagation, safe error mapping, and metrics.

**Step 5 — Make responses agent-actionable.** Per the addendum: lean response bodies, idempotent tools, errors that distinguish retryable from terminal. Emit `Retry-After` on `429`/`503`.

**Step 6 — Verify against the manual's bar, not just green gates.** `tsc`/lint/build/tests passing is necessary, not sufficient. Confirm a concrete runtime observation where feasible (a response body, an idempotent-replay returning the cached result, a `412` on a stale `If-Match`). If runtime verification is not possible, say so plainly.
</process>

<security_checklist>
Before any write-path implementation is done, confirm it against the manual's **Security Manual** — read live, not from memory. The owned sections to satisfy: Write-Path Safety: Mass Assignment, Validation, Authorization (per-endpoint *and* per-resource at the data owner), plus safe errors and data-access rules. The manual carries the field lists and specifics; this skill only routes you to them.
</security_checklist>

<reference_index>
**Manual (source of truth):** `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md`
Owned sections: Implementation Defaults (Layering, Middleware Order, Outbound Calls and Cascading Failure, Remote vs. In-Process APIs, Data Access); Node.js API Defaults; Idempotency and Retries; Concurrency and Preconditions; Error Design. Required cross-cutting: Security Manual (Validation, Write-Path Safety: Mass Assignment).

**Agent-native addendum:** `${CLAUDE_PLUGIN_ROOT}/references/agent-native-addendum.md`
Agent-as-consumer rules: idempotent tools, lean responses, machine-actionable errors.
</reference_index>

<lifecycle_handoff>
This is the IMPLEMENT phase. Hand off when the task is actually a different phase:
- Open design decisions, style choice, resource modeling → **api-design**.
- Pre-merge review, checklist, conformance audit → **api-review**.
- Versioning, deprecation, backward-compatible change → **api-evolve**.
</lifecycle_handoff>

<success_criteria>
The implementation is complete when:
- The owned manual sections and the agent-native addendum were read live before coding (not recalled from memory).
- Code sits in the correct layer; handlers are thin; middleware is in the manual's order.
- Every mutation is either safe-by-design or deduped via an idempotency key; retry policy is bounded with jittered backoff; non-idempotent mutations are never blindly retried.
- Shared-resource updates use optimistic concurrency and return `412`/`409` correctly.
- Every synchronous outbound call has a timeout, bulkhead, and circuit breaker.
- The error contract matches the repo/manual shape; responses are lean and errors are machine-actionable; `Retry-After` is emitted where required.
- The security checklist passes (mass-assignment allow-list, edge validation, per-resource authorization, no leaked internals).
- A concrete runtime observation backs any "works" claim — or the absence of one is stated explicitly.
</success_criteria>
