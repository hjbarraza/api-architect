# API Design and Development Manual for Coding Agents

This manual is for Codex/GPT-style and Claude/Opus-style coding agents designing, building, reviewing, or evolving APIs.

It is an operational guide synthesized from four books (see Appendix). It does not copy them. Use it to ask the right questions, make small choices explicit, design the contract first, verify behavior, and leave the system easier to operate.

When a fork has a default below, take the default unless the repo or org already has a convention — explicit local convention always wins. When current security, protocol, or framework guidance matters, verify against live official documentation before shipping public or high-risk APIs.

## Agent Contract

When asked to create or change an API, behave like a senior API engineer:

- State assumptions before implementing. If the consumer need, domain boundary, data ownership, or security model is unclear, ask when the choice is breaking or irreversible; otherwise assume-and-document and proceed.
- Prefer the smallest design that solves the user outcome.
- Treat names, payloads, error codes, status codes, auth, and pagination as public contracts.
- Design the contract before the implementation, and preserve compatibility unless a breaking change is explicitly requested.
- Add tests that prove behavior, not just coverage. Include operational basics: timeouts, logs, metrics, request IDs, safe errors.
- Do not invent architecture because it looks modern. Use microservices, gateways, meshes, queues, or events only when they solve a named problem.

A change is good when the API has a clear consumer and use case, a defensible boundary, an explicit documented contract, predictable failure modes, security designed in, tests matched to risk, and room to evolve without surprising clients.

## Clarify vs. Assume

This is the most consequential behavioral fork for an autonomous agent.

- **Ask the user** only when the missing fact is breaking or irreversible: the auth/tenancy model, who owns the data, a compatibility promise to existing clients, or a destructive operation's blast radius.
- **Assume and document** everything else, then proceed using the no-details defaults below. Record assumptions in the API Brief so a reviewer can correct them cheaply.

If the request is broad, narrow it to one first useful slice and build that.

## Default Operating Loop

1. **Clarify the job.** Identify consumer, goal, data, operation, expected volume, latency, auth model, compatibility requirements. Apply Clarify-vs-Assume.
2. **Choose the boundary.** Decide what owns the data and behavior. Do not split services unless independent deployment, ownership, or scale requires it (see Boundary Rules).
3. **Choose the API style.** REST/resource-oriented HTTP by default; see the Style Matrix.
4. **Draft the contract.** Paths, methods, IDs, request/response/error bodies, auth, pagination, filtering, idempotency, examples — in OpenAPI, protobuf, AsyncAPI, or the repo's format. Use the Endpoint Design template.
5. **Implement surgically** in the repo's existing layering (see Implementation Defaults). Validate at the edge; business rules in the service layer; storage and downstream calls behind adapters.
6. **Verify** with focused tests (see Testing Matrix): negative cases, auth failures, retries, idempotency, compatibility risk.
7. **Prepare release and operation:** docs, examples, observability, rollout/rollback notes, deprecation notes if needed.

## Intake Checklist

Answer these before coding; if you cannot from context, state the assumption or ask (per Clarify-vs-Assume).

- Who consumes this: browser, mobile, partner, internal service, batch job, operator, or agent?
- What job must the consumer get done? What resource or business capability is exposed? Who owns the data?
- What actions change state? Which calls must be idempotent?
- Expected read/write volume? Acceptable latency? What data is sensitive?
- What authn/authz model is required? What compatibility promise exists?
- Is there an existing API standard in the repo or org? What must be observable in production? How will this be tested and rolled back?

**No-details default:** one narrow use case, REST over HTTP, JSON, resource-oriented paths, OpenAPI docs, standard errors, request-ID propagation, input validation, auth hooks if the project has auth, and tests for success, validation failure, not-found, unauthorized/forbidden, and idempotent retry where relevant.

## Defaults Table

When a recurring fork has no repo convention, use these. Document the choice only when you override the default.

| Fork | Default | Override when |
| --- | --- | --- |
| Version mismatch status | `412` for a failed `If-Match`/ETag precondition | `409` for broader state conflicts not expressed as a request precondition |
| Invalid input status | `400` for malformed or invalid fields | `422` only if the repo already uses it for well-formed-but-semantically-invalid bodies |
| PATCH merge semantics | JSON Merge Patch: fields present are set (null clears a nullable field), absent fields unchanged | Field-mask semantics if the API defines an explicit mask |
| Unknown fields on write | Reject; bind only an explicit per-endpoint allow-list of writable fields | Ignore-and-pass-through only for a documented tolerant-reader policy |
| Hidden vs. forbidden | `403` when authenticated but not allowed | `404` only when the resource's existence is itself sensitive |
| Sync vs. async | Synchronous if work fits comfortably inside the framework's default request timeout | `202` + operation resource when work may exceed it; name a concrete budget (e.g. 5s) |
| Custom-action path | Match repo convention; absent one, `/{id}/<verb>` | Colon syntax `/{id}:<verb>` only if the API intentionally follows Google AIP / gRPC-transcoding style |
| List response shape | Always an object wrapper `{ "items": [...], "nextPageToken": "..." }` | Never a bare top-level array (forecloses adding pagination/metadata without a break) |

## Boundary Rules

Use business-capability boundaries before technical boundaries.

Good boundaries own a clear capability, keep related behavior and data together, hide storage details, expose contracts not tables, can deploy independently, have a clear owner, and change for one business reason. Bad boundaries split by technical layer (controller/validation/database service), are created just because "microservices" were requested, force many services to change for one feature, share a database schema, add pass-through hops with no ownership, or expose internal IDs/flags/table shapes.

| Situation | Better default |
| --- | --- |
| Small product, one team, unclear domain | Modular monolith |
| Independent team ownership and deploy cadence | Service boundary |
| One service owns state, others need it | Publish domain events |
| Multiple services need the same transaction | Reconsider the boundary |
| Reporting needs broad data | Reporting database / data product (see Async section) |
| One stable facade over legacy systems | API facade or strangler layer |

### Coupling Diagnosis

Name the coupling you are creating; the name tells you whether a change forces a lockstep multi-service rollout. Ordered loose → tight:

- **Domain** — service A calls B because the business genuinely needs it. Acceptable.
- **Temporal** — A blocks on B being up right now. Prefer async to remove it.
- **Pass-through** — A forwards data only because downstream C needs it. Fix: have the intermediary own/construct the payload, or treat it as an opaque blob A doesn't parse.
- **Common** — multiple services read/write the same shared data. Fix: make one service the source of truth and expose a state machine.
- **Content (pathological)** — a service reaches into another's database/internals. Never: it makes your schema part of their contract. This is the worst kind.

## API Style Decision Matrix

Rows are not exclusive; a real task may hit several. Default to REST and add a second style only for a named, separable need (e.g. REST surface + events for decoupling). Avoid mixing styles without a reason — a REST API with random RPC paths and inconsistent status codes is worse than either clean style.

| Need | Choose | Why |
| --- | --- | --- |
| Broad public or partner API | REST/HTTP + JSON | Familiar, cacheable, inspectable, documentable |
| Browser/mobile CRUD | REST/HTTP + JSON | Best default for resource operations |
| High-volume internal calls | gRPC | Strong schema, efficient transport, generated clients |
| Producer must not know consumers | Events | Reduces direct coupling |
| Long-running work | Operation/job resource | Avoids request timeouts and ambiguous completion |
| Read aggregation across many services / BFF | GraphQL | Field selection + aggregation; can give one version over many APIs and a legacy facade |
| Workflow across services | Saga | Keeps local transactions local |
| Bulk import/export | Dedicated operation | Different semantics from CRUD |

**GraphQL caveats** (do not pick it blindly): its sweet spot is the perimeter/BFF for *reads*. It fits writes poorly, can generate hard-to-trace server-side load (N+1 from client queries), and tempts an "API on a database" anti-pattern that re-couples the schema to your store. Avoid it for internal high-volume or write-heavy service-to-service calls, and never let the GraphQL schema mirror your database.

**REST maturity:** target Richardson Level 2 (proper resources + correct HTTP verbs). Full HATEOAS (Level 3) is rarely worth it for service-to-service APIs — publish a complete spec up front instead.

## Resource-Oriented API Rules

Use resource-oriented design unless the operation is clearly not resource-like.

### Resource Design

A resource is a thing with identity, lifecycle, permissions, and useful operations. Good: `users`, `orders`, `invoices`, `payment_methods`, `deployments`, `reports`, `jobs`. Weak: `validators`, `processors`, `managers`, `helpers`, `actions`, `requests` when no persistent request exists. Do not create a resource for every nested object — some data is just fields on a resource.

### Naming

Names are API behavior; they shape how clients think.

- Same word for the same concept everywhere; different words for different concepts.
- Nouns for resources, verbs only for custom methods. Plural collections: `/users`, `/orders`.
- Include units when ambiguous: `timeoutSeconds`, `sizeBytes`, `priceCents`.
- Avoid abbreviations unless domain-standard. Avoid implementation terms: table, row, shard, Kafka, Redis, ORM, DTO.
- Keep casing consistent with the repo or API standard.

### Hierarchy and IDs

Nest paths only when the parent controls lifecycle, ownership, permissions, or scoping — and only for true ownership with cascade semantics. Model movable associations (a book that can move between shelves) as mutable reference fields, not path segments. Deep paths usually signal confused ownership; prefer references, filters, or top-level resources when the child can exist independently.

```http
GET /accounts/{accountId}/invoices/{invoiceId}   # good: account owns the invoice
```

IDs should be opaque, stable, unique within scope, non-guessable when sensitive, server-generated unless the domain needs client IDs, and treated as **strings** in the contract. Avoid numeric sequential IDs in public APIs when enumeration is a risk. For format, a readable case-insensitive encoding (e.g. Crockford Base32) or UUID is fine; an optional checksum character lets you distinguish an invalid/typo'd ID from a genuinely missing one.

### Standard Methods

Keep standard methods boring.

| Operation | HTTP |
| --- | --- |
| Create | `POST /resources` |
| Get | `GET /resources/{id}` |
| List | `GET /resources` |
| Update partial | `PATCH /resources/{id}` |
| Replace full | `PUT /resources/{id}` |
| Delete | `DELETE /resources/{id}` |

- `GET` must not change state.
- `POST` creates or triggers work. Add an idempotency key for retryable creation.
- `PATCH` updates selected fields — default to JSON Merge Patch semantics (see Defaults Table) and state how null vs. omitted behave.
- `PUT` replaces the **whole** resource. Warning: a client running an older schema that does `PUT` will silently erase fields it doesn't know about (e.g. fields added in a newer version) and can clobber concurrent writes. Prefer `PATCH` for routine writes; reserve `PUT` for true full-replacement, guarded by a freshness check.
- `DELETE`: HTTP defines the method as idempotent in the *effect* sense, but the protocol guarantees nothing — the service must implement it so. In resource-oriented APIs, deleting an already-missing resource typically returns `404` (the *response* differs even though the *effect* is settled). Auto-retry `DELETE` only with a dedup key or documented declarative-delete semantics.
- Do not hide extra state transitions inside standard methods.

### Field Masks and Partial Updates

This is the mechanism behind safe partial reads and writes, and the answer to the PUT-clobber/lost-update problem above.

- On `PATCH`, update only the fields present in the body (an implicit field mask). Distinguish **omitted** (leave unchanged) from **null** (set to null) per field.
- Support an explicit field mask (e.g. repeated `?fieldMask=` query params) to remove a field or to fetch a subset of a large resource.
- `GET` returns all fields unless a mask is given.

### Custom Methods

Use custom methods for a domain action, state transition, or calculation that does not fit CRUD.

```http
POST /invoices/{invoiceId}/send
POST /orders/{orderId}/cancel
POST /reports/generate
POST /tokens/exchange
```

Name the action clearly, define idempotency, define preconditions/conflicts, and return the updated resource, the result, or an operation resource. Avoid custom methods for simple CRUD. (The colon form `:send` is Google AIP house style; default to `/{id}/<verb>` or repo convention — see Defaults Table.)

### Long-Running Operations

If work may exceed the framework's default request timeout, return `202 Accepted` with an operation resource and let clients poll.

```http
POST /exports → 202 Accepted
{ "id": "exp_123", "done": false, "status": "queued", "createdAt": "2026-06-21T10:00:00Z" }

GET /operations/exp_123
```

Expose an explicit `done` flag (do not infer completion from the result), a `result` that is either the output or a structured `error`, optional `progress` metadata, timestamps, and an expiration for temporary artifacts. Prefer a single top-level `/operations` collection so jobs are listable and discoverable, rather than scattering them under each parent. Statuses: `queued`, `running`, `succeeded`, `failed`, `cancelled`.

For expensive or destructive calls, consider a `validateOnly`/dry-run flag so clients can preview effects without executing.

## Request and Response Design

### Field Rules

- Consistent field names and casing; treat fields as contract. Prefer explicit fields over overloaded generic maps.
- Strings for IDs. **Serialize integers beyond ~2^53 and all decimal/monetary values as strings** and parse with arbitrary-precision — JSON numbers corrupt large ints and decimals silently (`0.1 + 0.2 != 0.3`). Reserve JSON numbers for small bounded integers.
- ISO 8601 timestamps in UTC.
- Model enumerable fields as validated **strings** (validate server-side so new values don't break old clients), not numeric enums.
- Treat array fields as **atomic** — replace the whole list; never address or update by index. Bound list length and map key/value sizes.
- Include units in field names. Name booleans positively so the zero value is the desired default.
- Distinguish omitted, null, empty, and zero where behavior differs. Avoid null unless it has defined meaning.
- Never leak secrets, tokens, credentials, stack traces, SQL, internal hostnames, or config in responses.

### Compatibility

**Usually compatible:** add optional response fields; add optional request fields with defaults; add enum values *if clients are tolerant readers*; add new endpoints; relax validation carefully.

**Usually breaking:** remove/rename a field; change a field's meaning or type; make an optional field required; tighten validation; change pagination/ordering semantics; change auth requirements without rollout; change status codes clients depend on; reuse an enum value with new meaning.

**gRPC/protobuf is stricter than JSON.** Field order and unknown-field tolerance will *not* save you. Never change or reuse a field number; reserve numbers of removed fields; never rename or retype a field (a rename breaks source/JSON-transcoding even when the binary wire survives); never make a newly added field mandatory. Adding a new service/method/optional field is compatible.

### Pagination

Paginate list endpoints by default. Always wrap the response in an object from day one (a bare array forecloses adding pagination later without a break).

```http
GET /orders?pageSize=50&pageToken=abc
{ "items": [], "nextPageToken": "def" }
```

Use opaque page tokens; keep ordering stable; document default and max page size; avoid offset pagination for changing datasets; do not return exact total counts unless cheap and correct enough. (`pageSize`/`pageToken` are one convention — match the repo's field names if it has them.)

### Filtering and Sorting

Filtering must be explicit, validated, and resource-local. Define allowed filter fields and operators; validate input; never expose database syntax. Make sorting fields explicit and define a default ordering.

```http
GET /orders?status=open&createdAfter=2026-01-01T00:00:00Z   # good
GET /orders?filter=<anything the database accepts>          # risky
```

### Batch and Bulk Operations

Use batch endpoints only when they reduce real client/network pain. Preserve request order in responses; set a max batch size; keep idempotency clear. Default mutating batches to all-or-nothing; return per-item errors only when partial success is an explicit requirement.

**Bulk delete by filter is the single most dangerous operation.** An empty/unset filter matches everything; a typo deletes everything. Such endpoints must default to preview/validate-only and require an explicit `force` flag to execute; design the default so a missing filter or flag deletes *nothing*. Return a never-under-reported match count plus a sample of matching IDs to spot-check.

## Error Design

Errors are part of the API. Use the repo's existing error shape; otherwise:

```json
{ "error": { "code": "resource_not_found", "message": "Resource not found.", "details": {}, "requestId": "req_123" } }
```

`message` is client-safe; `code` is stable and machine-readable; `details` is structured and safe; `requestId` links reports to logs. Never expose stack traces or internal exception names. Validation errors should identify field paths and reasons.

| Code | Use |
| --- | --- |
| `200` | Success with body |
| `201` | Created |
| `202` | Accepted for async processing |
| `204` | Success with no body |
| `400` | Invalid syntax or fields (default for invalid input) |
| `401` | Missing/invalid authentication (send a `WWW-Authenticate` header) |
| `403` | Authenticated but not authorized |
| `404` | Not found, or hidden when existence is sensitive |
| `405` | Method not allowed |
| `409` | State conflict |
| `412` | Failed `If-Match`/ETag precondition (optimistic concurrency) |
| `415` | Unsupported media type |
| `422` | Well-formed but semantically invalid (only if the repo uses it) |
| `429` | Rate limited (send `Retry-After`) |
| `500` | Unexpected server error |
| `502`/`504` | Upstream failure / timeout — these are gateway/proxy roles; an application API should rarely emit them directly (prefer `503`/`500`) |
| `503` | Temporarily unavailable (send `Retry-After`) |

For sensitive resources, returning `404` instead of `403` avoids disclosing that a resource exists — use it when existence itself is the secret (see Defaults Table).

## Idempotency and Retries

Every retryable API must define its retry behavior. **Method choice does not confer idempotency — the service must implement it.**

- `GET` is safe. `PUT`/`DELETE` are idempotent only if implemented so.
- `PATCH` is retryable only if designed idempotent. `POST` is retryable only with an idempotency key or dedup token.

**Dedup mechanics:** idempotency keys must be client-supplied and opt-in. On a key hit, compare a fingerprint (hash) of the request body and return the cached response only if it matches; otherwise return `409 Conflict`. Cache the full response with a short TTL. A database uniqueness constraint on the key *alone* lets two clients that collide on a poor key receive each other's responses.

**Retry rules:** timeouts on every outbound call; bounded retries; exponential backoff with jitter; never retry forever; never retry an unsafe mutation without idempotency. On `429`/`503`, emit a `Retry-After` header (prefer a seconds duration over an absolute timestamp to avoid clock skew); clients should honor it over their own backoff.

**Retryable statuses:** `408`, `421`, `425`, `429`, `500`, `502`, `503`, `504`. A status being retryable says nothing about whether *your* request is safe to resend. The gate is the method, not the code: **retry a non-idempotent mutation only when it is deduped (idempotency key) or the response proves it was not applied — on any status.** Two of these are conditional even for safe requests: `425 Too Early` → retry only by resending *without* TLS early data; `421 Misdirected Request` → retry only on a *new* connection.

## Concurrency and Preconditions

Use optimistic concurrency when clients update shared resources: `ETag` + `If-Match`, or a resource `version` field. (A last-modified timestamp is a weak fallback — HTTP-date resolution is one second, so rapid concurrent writes can pass the check; don't use it for high-contention resources.)

On mismatch, default to `412 Precondition Failed` for a failed `If-Match`/ETag precondition; use `409 Conflict` for broader state conflicts (see Defaults Table).

## Security Manual

Security starts in API design. Edge/gateway validation is defense-in-depth, not the authority — **every service independently validates and authorizes regardless of edge checks** ("trust, but verify").

### Threat Model

For any sensitive or public API: identify assets → actors (users, admins, services, partners, attackers) → trust boundaries → entry points → sensitive data fields → abuse cases → controls → verify controls with tests.

Minimum controls: authentication; authorization per endpoint *and* per resource; input validation; output encoding where relevant; rate limits/quotas for abuse-prone endpoints; request size limits; TLS (decide where it terminates and whether internal hops need mTLS); safe error responses; audit logs for sensitive actions; secrets outside code, rotated, revocable, short-lived where practical.

### Authentication

Use the platform standard. If choosing: browser/mobile users → OAuth2/OIDC authorization code + PKCE; service-to-service → mTLS, workload identity, signed tokens, or OAuth2 client credentials; partners → client credentials or signed requests with key rotation; webhooks → signature verification, timestamp tolerance, replay protection.

**Never use ID tokens as access tokens** — ID tokens convey user identity to the client, not authorization to call resources.

### Authorization

Authentication is "who are you"; authorization is "can you do this." Check authorization at every protected endpoint; check resource ownership/tenancy; prefer least-privilege scopes; enforce server-side even if the UI hides actions; never trust internal network location alone; for multi-tenant APIs add tenant-boundary tests.

**Confused-deputy problem:** a trusted intermediary (gateway/BFF) that fetches data on the caller's behalf can be tricked into returning another user's data via guessed IDs. Perform resource-ownership authorization in the service that *owns the data*, not only at the gateway. Propagate the caller's identity downstream in a **signed token (JWT), never an unsigned header**, and manage signing-key rotation and token expiry.

### Write-Path Safety: Mass Assignment

Never bind a request body directly to a persistence entity. **Allow-list the fields a client may set, per endpoint.** The danger is not unknown fields — it is *recognized* fields the client must not write (`role`, `isAdmin`, internal IDs, `devices`) that an ORM will happily persist. This must be enforced in the service; a gateway cannot fix it.

### Validation

Validate at the edge: path params, query params, headers, body fields, content type, request size, file type/size for uploads. Use schema validation. Reject unknown fields on write paths by default and bind only the allow-list above.

### Abuse Controls

Distinguish **rate limiting** (reject by requester identity/IP/region — fixed-window, sliding-window, token-bucket, or leaky-bucket) from **load shedding** (reject by system saturation: DB or thread-pool exhaustion, independent of who is calling). Apply rate limiting to internal calls too, to prevent circular-dependency "friendly-fire" DoS. For edge security components decide **fail-open vs. fail-closed** explicitly: fail-closed for financial/regulated paths, fail-open only where availability outranks security.

## Gateway, Mesh, and Platform Choices

Default to adopting an established gateway/mesh — a custom build almost always underestimates total cost of ownership and yields no competitive advantage.

### API Gateway

Use a gateway for north-south traffic when you need TLS termination, auth enforcement, rate limiting, WAF/abuse controls, request logging, correlation IDs, routing, API lifecycle management, or a developer portal. **As a threshold, reach for a gateway when the API is publicly exposed or fronts multiple services — not for a single internal service.**

Do not put core business logic in the gateway, or use it as an enterprise service bus. Do not route on the request *payload* (it leaks domain schema and is costly to parse). Do not route internal service-to-service calls back out through the public gateway (**loopback** — it adds egress cost, latency, a security hole, and a single point of failure); use internal service discovery. Avoid stacking multiple gateways ("turtles all the way down").

### Service Mesh

A mesh's main draw is simplifying mTLS and certificate distribution across services; it also offers service identity, traffic splitting, consistent telemetry, and policy. Adopt one only when internal traffic is complex enough to justify it — for small systems, framework libraries and platform primitives are simpler. Even with a mesh, you still own correct timeout/retry/circuit-breaker behavior on synchronous calls; the mesh provides primitives, not a free pass.

## Implementation Defaults

### Layering

Use the repo's structure. Absent one:

```text
src/{ app, routes, middleware, schemas, handlers, services, repositories, clients, observability, tests }
openapi.*
```

- `routes`: method/path wiring. `schemas`: request/response validation. `handlers`: translate HTTP ↔ service (keep thin). `services`: business rules and transactions. `repositories`: persistence. `clients`: downstream calls. `middleware`: auth, request IDs, logging, rate limits, errors. `observability`: metrics, tracing, log setup.

Business logic in handlers is hard to test and reuse.

### Middleware Order

1. Request/correlation ID → 2. Structured request-logging setup → 3. Security headers → 4. Body size + content-type checks → 5. Authentication → 6. Authorization context → 7. Rate limit/quota → 8. Request validation → 9. Handler → 10. Centralized error handling.

### Outbound Calls and Cascading Failure

Every outbound client needs: base URL from config, timeout, bounded retry policy, request-ID/trace propagation, safe error mapping, latency/status/failure metrics, and tests with stubbed responses.

**A slow downstream is more dangerous than a dead one** — it exhausts shared resources (connection pool, threads) and takes the whole system down. So: use a per-downstream connection pool (a **bulkhead**) rather than one shared pool; set an overall operation time-out *budget* and pass the remaining time downstream; and treat a **circuit breaker as mandatory** on every synchronous downstream call (open after a failure threshold, fast-fail or serve a fallback, half-open to probe recovery). When no mesh provides the breaker, implement it in code.

### Remote vs. In-Process APIs

A network API is not an in-process API. Prefer coarser-grained operations (avoid chatty round-trips), be conscious of payload/serialization size, and give errors a rich, machine-actionable vocabulary that distinguishes retryable (transient) from terminal failures so callers can compensate correctly.

### Data Access

Use parameterized queries or safe ORM APIs. Keep transactions local to one service/module; do not let another service write directly to this service's tables. Use migrations. Make uniqueness and idempotency constraints real database constraints where possible. Bound the connection pool per instance to avoid exhausting shared DB connections. Never expose database errors directly.

## Node.js API Defaults

Prefer Fastify or Express by repo convention. Modules mirror the layering above, plus `config`, `errors` (typed app errors → HTTP), `logger`, `metrics`.

- Validate config at startup. Structured JSON logs in production. Set request body limits. Handle async errors centrally. Use connection pooling with limits.
- **Never block the event loop** — offload CPU-bound work (crypto, large JSON, compression, tight loops) to worker threads or a queue; one synchronous call stalls *all* concurrent requests and fails health checks.
- **Graceful shutdown on SIGTERM:** stop accepting new connections, drain in-flight requests within a deadline, then close DB pools, broker channels, and the HTTP server — otherwise every rollout drops live requests and leaks connections.
- **Health checks:** `/readiness` must verify critical dependencies (DB, broker, required downstreams) so the orchestrator stops routing to a broken pod; keep liveness shallow so a slow dependency doesn't trigger restarts.
- **Edge validation** with a schema library (Joi, Zod, or Fastify JSON Schema); sanitize HTML with a library like DOMPurify; always use parameterized queries.
- **Security headers** for browser-facing APIs (CSP, HSTS, X-Content-Type-Options) via a middleware like helmet; configure CORS explicitly, not allow-all.
- Load connection strings/secrets from env or a vault, never hardcoded. Do not expose the Node inspector in production; do not return raw stack traces.

Toolchain (use the repo's actual tools before adding new ones): unit — Jest/Vitest/Mocha; HTTP integration — Supertest, Nock/Sinon, framework inject APIs; contract — Pact or generated; E2E — Playwright/Cypress; load — k6/Artillery/JMeter; security — ZAP/Burp/Semgrep, dependency audit. Note: intro-level example code often logs `err.stack` and full request objects — strip these (see Observability "Do not log").

## Testing Matrix

| Test type | Purpose | Use when |
| --- | --- | --- |
| Unit | Business rules, pure logic | Always for non-trivial logic |
| Handler/API | Status codes, validation, response shape | Every endpoint |
| Contract | Producer/consumer compatibility (shape only) | Shared or external APIs |
| Component | Service behavior with mocked external deps | Complex service boundaries |
| Integration | DB, queues, downstream adapters | State/dependency behavior matters |
| End-to-end | Critical user journey | Few, high-value flows |
| Load | Latency, throughput, bottlenecks | Public/high-volume/SLO-bound APIs |
| Security | Authz, injection, data leaks | Sensitive or public APIs |
| Smoke | Basic production readiness | Every deployable API |

**Contract vs. component** is load-bearing: a contract test verifies the request/response *shape*; a component test verifies *behavior* (correct status code, empty-set vs. 404, authz-denied path, side effects like a DB call or `Location` header). A green contract test does not prove correct behavior.

**Consumer-driven contracts (CDC):** for shared/external APIs default to producer-defined contracts (thousands of consumers cannot mutate your contract). When producer and consumer live in the *same org*, prefer CDC — the consumer publishes expectations that run in the **producer's** CI, so a breaking change fails the producer's build before deploy (Pact / Pact Broker). Prefer this over end-to-end suites as the cross-service safety net.

**Integration boundaries:** hand-rolled stubs drift out of sync and produce green tests against broken integrations — prefer contract-generated stubs or recordings, and for DB/queue/cache run the *real* dependency at the prod version via containers (Testcontainers), not in-memory substitutes.

Minimum endpoint test set: success; invalid input; missing auth (if protected); forbidden (if authz differs from authn); not found; conflict/precondition failure where state matters; idempotent retry where mutation is retryable; pagination/filtering for lists. Do not rely on OpenAPI alone as behavior coverage — a schema can be valid while the API is wrong.

## Release and Evolution

Deployment puts code in an environment; release exposes behavior to users. Use controlled release for risky changes: feature flags (named, owned, with expiry — avoid stale flags and don't make a flag permanent architecture), canary, blue-green, traffic shadowing, parallel run, consumer opt-in, deprecation window. Lifecycle: planned → preview/beta → live → deprecated → retired.

**Avoid breaking changes before reaching for versioning:**

1. Make **expansion changes** only (add, never remove/rename).
2. Write consumers as **tolerant readers** (Postel's law — ignore fields you don't recognize).
3. Run a **schema-diff compatibility gate in CI** (openapi-diff / Protolock / Confluent Schema Registry) that fails the build on a breaking change.
4. When a break is unavoidable, prefer **expand-and-contract** (run old + new interfaces inside the same service, retire the old once consumers migrate) over coexisting whole service versions or lockstep deploys.

Version only when semantics genuinely break; support old versions long enough to migrate; track usage before removing; publish migration notes. **Maintain a registry/catalog of every deployed API and version** — untracked old/`beta` endpoints are an attack surface (they may still expose fields newer versions removed), so retirement means de-registration and route removal, not just a "deprecated" label.

## Observability and Operations

Minimum telemetry: structured logs; request/correlation ID; metrics for request count, latency, errors, saturation; dependency metrics; health/readiness endpoint; traces for distributed systems. (These exist to answer: is it up, fast enough, correct enough; who is affected; which dependency is failing; which deploy changed behavior.)

Log fields: timestamp, level, service, environment, version, requestId, traceId, userId/tenantId (only if safe), method, path *template* (not raw sensitive paths), status, durationMs, error code.

**Do not log:** passwords, tokens, cookies, authorization headers, private keys, full card numbers, sensitive personal data, or raw request bodies unless explicitly safe and sampled. (This is the single canonical do-not-log list for the whole manual.)

SLO candidates: availability, P95/P99 latency, error rate, successful-business-operation rate, queue lag, dependency failure rate.

**Graceful degradation is a business decision.** Stability patterns (timeouts/retries/breakers) cover only *expected* failures. For each downstream, decide what the product does when it is down ("sell anyway with stale stock," "hide the cart," "show a phone number") — not just a technical fallback.

## Async and Event APIs

Use events when the producer should not know who reacts. Event rules: represent facts that happened; name in past tense (`OrderPlaced`, `InvoicePaid`); include event ID, occurred timestamp, producer name + schema version, and a correlation/causation ID; keep payload stable; make consumers idempotent; define ordering, retention, and replay; never expose the internal database shape as the payload. Use commands/queues when requesting work from a known worker.

**Sagas** (workflows across services):

- A saga recovers from **business** failures (insufficient funds); **technical** failures (timeout, 500) belong to the resilience layer (retries/breakers), not compensations.
- Choose **orchestration** (central coordinator, request/response, easier to see) when *one team* owns the whole workflow; prefer **choreography** (events, looser coupling) when *multiple teams* are involved, and build a correlation-ID-driven view to track state. Watch for logic centralizing into the orchestrator and leaving services anemic.
- Per step, choose backward recovery (compensate) or forward recovery (retry from the failure point). Reorder steps so failure-prone ones run early, minimizing compensations. Compensations are *semantic*, not true rollbacks (you can't unsend an email).
- Keep each local transaction local; persist saga state; make retries idempotent; expose status.

**Consistency under partition is a per-capability choice**, not system-wide: a catalog can be eventually consistent (AP); a money/stock debit should be strongly consistent (CP), accepting reduced availability. Never hand-roll a distributed consistent store — use one that provides the guarantee.

**Reporting database / data product:** when reporting needs broad cross-service data, the owning service pushes a curated, minimal subset to a dedicated read store with its own schema, treated as a versioned contract — never grant other services direct access to source tables.

## Pre-Merge Review Checklist

One consolidated gate. Before merging API work, confirm:

- Consumer and use case named; resource/service boundary clear and defensible; coupling diagnosed.
- Paths and methods consistent; names consistent and unit-aware; IDs opaque strings (large numbers/decimals serialized as strings).
- Request/response/error schemas explicit; error shape consistent; status codes follow the table and Defaults.
- Authn and authz enforced (per-resource ownership at the data owner; identity propagated via signed token); write paths allow-list fields (no mass assignment); sensitive fields protected; validation at the edge.
- Pagination on list endpoints (object-wrapped); filtering/sorting bounded; field-mask/PATCH merge semantics defined.
- Idempotency defined for mutations (client key + body fingerprint); timeouts + bulkheads + circuit breakers on outbound calls; retries bounded and gated by method safety, not status.
- Logs carry request IDs and safe error codes (nothing on the do-not-log list); metrics for latency and errors; readiness checks real dependencies.
- Tests cover success and meaningful failures (CDC for shared APIs, real deps for integration); contract/docs/examples updated.
- Compatibility impact stated (REST *and* protobuf rules); schema-diff gate passes; rollout/rollback plan exists for risky changes.

**Done when:** implementation matches the documented contract; tests pass locally; negative tests cover likely client mistakes; security controls are in place; observability is enough to debug a production incident; docs/OpenAPI updated; backward compatibility preserved or migration documented; and the change is small enough to review.

## Templates

### API Brief

```markdown
# API Brief: <name>
Consumer / Outcome / Resource or capability / Owner / API style / Authn-authz /
Sensitive data / Compatibility promise / Expected volume-latency / Observability needs / Rollout risk
Endpoints:
- <method> <path> — <purpose>
Assumptions made (Clarify-vs-Assume):
Open questions:
```

### Endpoint Design

```markdown
## <METHOD> <path>
Purpose / Auth / Idempotency / Request / Response / Errors /
Pagination-filtering / Side effects / Timeout-retry behavior / Examples / Tests
```

### ADR

```markdown
# ADR: <decision>
Status / Date / Context / Decision / Alternatives considered / Consequences / Verification / Rollback or migration
```

### PR Summary

```markdown
## API Change
- Added/changed: / Compatibility: / Security: / Tests: / Docs: / Rollout:
```

## Agent Prompt

```text
Design and implement this API using API_DESIGN_DEVELOPMENT_MANUAL_FOR_AGENTS.

Start by stating assumptions and missing information (ask only on breaking/irreversible unknowns; otherwise assume-and-document). Prefer the smallest resource-oriented design unless another style is clearly justified. Draft or update the contract first, then implement surgically in the repo's existing style. Include edge validation with field allow-listing, safe errors, auth enforced at the data owner, idempotency rules, field-mask/PATCH semantics, pagination for lists, timeouts + bulkheads + circuit breakers for outbound calls, and observability. Apply the Defaults Table for any unresolved fork. Verify with focused tests and summarize compatibility, security, and rollout impact.
```

## Appendix: Sources (for human maintainers)

Synthesized from four converted books in this folder. These pointers are for a maintainer reopening the sources — they are not needed by an agent operating from this manual alone.

- `GDP` — Geewax, *API Design Patterns* (Manning 2021): resource design, naming, IDs, standard/custom methods, field masks, pagination, filtering, batch, import/export, versioning, idempotency/request-dedup, LROs, purge/validateOnly, revisions.
- `MAA` — Gough/Bryant/Auburn, *Mastering API Architecture* (O'Reilly 2022): contracts/OpenAPI, REST vs gRPC, traffic patterns, ADRs, gateways/mesh and their anti-patterns, contract/component testing, release, observability, threat modeling, OAuth2/OIDC, mass assignment, evolution, zero trust.
- `BM` — Newman, *Building Microservices* 2e (O'Reilly 2021): boundaries, coupling taxonomy, communication, sagas, CAP per-capability, cascading failure/bulkheads, confused deputy, CDC, migration patterns, breaking-change avoidance.
- `BMN` — Kapexhiu, *Building Microservices with Node.js* (Packt 2024): Node implementation, event loop, graceful shutdown, health checks, Joi validation, security headers, circuit breakers in code, observability.
