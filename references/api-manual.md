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
| Bulk import/export | Dedicated `:import`/`:export` op (LRO) wiring the API straight to an external store | Different semantics from CRUD; not backup/restore — see Import and Export |

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

**Cancel, pause, resume.** Once you expose an operation resource, expose the verbs that interact with it — but only the ones that make sense for that job.

- **Cancel** (`POST /operations/{id}:cancel`): an explicit `cancel` custom method, not a `DELETE`. It must block until the operation is fully aborted, then return the operation with `done: true` (`done` was chosen precisely because it does not imply success). Best-effort clean up any intermediate output; when you cannot, record references to the orphaned artifacts in `metadata` so the caller can clean up. Not every operation can be cancelled (you can't un-launch a rocket) — only add it where it benefits the user.
- **Pause/resume** (`:pause`/`:resume`): optional, and a *different* status from `done` (a paused operation is not done). Do not add a top-level `paused` flag to every operation — signal pausability by a `paused` boolean in that operation's `metadata` type, so operations that can't be paused don't advertise a field that lies. Support these only where pausing the underlying work is both meaningful and implementable.
- **Idempotency of all three.** `cancel`/`pause`/`resume` are state transitions on the operation — define what a repeat call does (cancelling an already-cancelled op, resuming a running op). Default: treat the terminal/declarative state as success or return `412` if you must distinguish "this call caused it" from "it was already so" (same imperative-vs-declarative rule as `DELETE`).

### Soft Deletion

An API recycle bin: mark a resource deleted instead of erasing it, so a mistaken `DELETE` is recoverable. Adopt it when accidental loss is costly and not when regulation demands true erasure (then prefer real backups). **Whether soft delete is even safe to add later is itself a compatibility decision** — changing `DELETE` from "gone now" to "gone in 30 days" can break callers' assumptions; treat it as potentially breaking and bump the major version.

- **State.** Add an output-only `deleted` boolean (or a `deleted` value in an existing state enum — but a Boolean is cleaner because an enum can't say what state an *undelete* restores to). Output-only: attempts to set it via `PATCH` are silently ignored; only `DELETE`/`undelete` flip it.
- **Standard-method changes.** `DELETE` becomes a marker (return the resource, not `204`); re-deleting an already-deleted resource returns `412` (imperative vs. declarative). `GET` still returns the resource (no `404`) — knowing the id is enough. `List` **excludes** deleted resources by default; add a `?showDeleted=true` (a.k.a. `includeDeleted`) flag to widen the set — keep this separate from `filter` (`filter` narrows, `showDeleted` widens; to see *only* deleted, pass both). Batch delete inherits the soft-delete behavior.
- **Custom methods.** `:undelete` restores (errors `412` if not currently deleted). `:expunge` permanently removes — a separate method, not `DELETE ?expunge=true`, because a query param must not silently change a verb's meaning and method-level permissions are easier to grant than param-conditional ones. Expunge should work whether or not the resource was soft-deleted first.
- **Expiration default.** Set an `expireTime` when soft-deleting (e.g. now + 30 days), computed at delete time so policy changes only affect future deletions; reset to null on undelete. Expired resources are then expunged automatically.
- **Referential integrity is unchanged.** Whatever rule the hard `DELETE` enforced (restrict / cascade / dangling reference) carries over verbatim to soft delete — don't invent new reference behavior just because the row still exists.

### Resource Revisions

Snapshots of a resource as it changes over time, for history, diffing, and rollback (contracts, documents, campaigns). Costly in storage and complexity — **avoid unless a firm requirement** (e.g. legal records). It is not the same as import/export or backup.

- **Shape.** No separate interface — add `revisionId` + `revisionCreateTime` to the resource. Multiple records share one `id`; each has a distinct `revisionId`. Use a random opaque revision id (not an incrementing number — gaps after deletion leak that a revision was removed; not a timestamp — collisions), shorter than a resource id is fine, keep a checksum char.
- **Latest is an alias.** `GET /resources/{id}` returns the newest revision (max `revisionCreateTime`) with `revisionId` populated. Address a specific revision with an `@` separator: `GET /resources/{id}@{revisionId}`. Invariant: *you get back exactly the id you asked for* — ask without `@`, the returned `id` has no `@`; ask with it, the returned `id` includes it.
- **Implicit vs. explicit.** Implicit = a new revision on every modification (safest, most history; what Google Docs / GitHub issues do). Explicit = `:createRevision` on demand. Pick **one strategy and apply it across all revisable resources** — mixing surprises callers. Either way, a revision must exist from creation.
- **Operations.** `:listRevisions` (paginated) and `:deleteRevision` use custom methods, not the standard list/delete — overloading `DELETE` risks confusing "delete one revision" with "delete the resource and all its revisions." Deleting the *current* revision is rejected (`412`). Revisions are hard-deleted only (so you can purge leaked secrets); they are not themselves soft-deletable.
- **Restore = rollback by copy-forward.** `:restoreRevision` reads an old revision and writes it as a *new* latest revision — it never moves an old revision to the front or rewrites history, so the timeline stays honest. Provide it as an atomic method rather than making clients do get-then-update (which races).
- **Children.** Default to revisioning a single resource's own fields, not its child hierarchy — hierarchy-aware revisions are far more expensive; reach for export instead unless truly required.

### Relationships and Collective Operations

When data doesn't fit one flat resource, these patterns model the relationship without contorting CRUD. Each carries a named tradeoff — pick by what you need to store and how you'll query it.

- **Many-to-many: association resource vs. add/remove.** A join needs a home. Model it as a first-class **association resource** (e.g. `Membership` joining `User` and `Group`) when you must store *metadata about the relationship* (joined-at, role) or address a single link directly — it gets full CRUD and optional alias sub-collections (`/groups/{id}/users`, `/users/{id}/groups`). When the relationship is a bare fact with no metadata, prefer lightweight **`:add`/`:remove` custom methods** on a chosen *managing* resource — simpler, but you give up relationship metadata and must pick one side as managing (non-reciprocal). Adding a duplicate link → `409`; removing a missing one → `412`.
- **Polymorphic resource: a type discriminator, not parallel resources.** When variants share lifecycle and you want to list them together (text/photo/video `Message`), use one resource with a `type` **string** field (not an enum) and a superset of fields (or one field whose meaning depends on `type`) — `ListMessages` beats interleaving `ListTextMessages` + `ListPhotoMessages`. Use independent resources instead when access patterns genuinely diverge (a broadcast vs. a chat room). Treat `type` as effectively immutable — morphing a resource's type silently breaks references that assumed the old type. Avoid polymorphic *methods*; keep the polymorphism in the resource.
- **Singleton sub-resource: split off a part for size / security / volatility.** Move a component to a singleton child (`drivers/{id}/location`) when it's much larger than its parent, has stricter access control, or is written far more often (write contention). It's a hybrid: supports `GET`/`PATCH` like a resource but is **never created or deleted** — it exists because its parent exists and is cascade-deleted with it (no `List`). The tradeoff: you lose atomic create of parent+child; offer a `:reset` to restore defaults. If a cascading delete would surprise callers, the pattern doesn't fit.
- **Anonymous writes for time-series.** When data points are aggregated, never individually addressed (log entries, metrics), use a `:write` custom method on the *collection* (`/chatRooms/{id}/statEntries:write`) that takes an `entry` (not `resource`), returns `void`, and assigns no id. It may be eventually consistent — return `202` rather than an LRO (you can't track an unidentified point through a pipeline, and per-point operations defeat the point of aggregating). Dedup with the request-dedup pattern if double-writes worry you.
- **Rerunnable jobs vs. one-shot LROs.** When configurable work runs repeatedly or on a schedule, split config from execution: a `Job` resource (full CRUD, often update-omitted/immutable) holds the parameters, and a parameterless `:run` returns an LRO. This lets you (a) version config in one place, (b) separate "who may configure" from "who may run" as distinct permissions, (c) hand scheduling to the service. A plain custom-method-returning-an-LRO is fine for true one-shots.
- **Copy/move identifier policy.** Renaming or reparenting is discouraged (referential-integrity cost), but when needed use `:copy`/`:move` custom methods, never `PUT`. **Identifier rule:** `:copy` behaves like create — honor a `destinationId` only if the API allows user-chosen ids, else server-generated (no loophole); a taken id → `409`. `:move` always knows the final id — a single `destinationId` that, without user-chosen ids, may change only the parent segment and keep the rest. Both must carry child resources along and fix up references (internal cascades, and external references are simply broken — a known cost of moving).

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

**Cursor stability — opaque is not enough; encrypt.** A page token leaks implementation if a client can read it. Base64 is not opacity — **encrypt the token contents** so its structure (offset, last-seen key, snapshot id) is meaningless to the consumer. The moment a client can decode and hand-craft a token, the token format is part of your contract and you can no longer change how you paginate.

- **Page size is a maximum, never exact.** A full page does not mean more data; an *empty page with a non-empty `nextPageToken`* is valid ("searched up to my time budget, found nothing, resume here"). **Termination is an empty `nextPageToken`, not a short page.**
- **Token lifetime.** Tokens generally need no hard expiry (paging is idempotent — an expired token just means retry), but document a lifetime to set expectations; minutes-to-an-hour is generous. Don't promise tokens are valid forever.
- **The smear vs. the snapshot — pick one and document it.** Data mutates while a client pages. Two honest options: (1) if the store supports point-in-time snapshots (Spanner, CockroachDB), encode the snapshot in the token for strongly-consistent pages; (2) otherwise, **document that pages are a "smear"** — concurrently added/removed rows may be seen twice or missed. Either way, use the *last-seen result* as the cursor, never a numeric offset — offsets re-show page 1 when rows are inserted at the head.

### Filtering and Sorting

Filtering must be explicit, validated, and resource-local. Define allowed filter fields and operators; validate input; never expose database syntax. Make sorting fields explicit and define a default ordering.

```http
GET /orders?status=open&createdAfter=2026-01-01T00:00:00Z   # good
GET /orders?filter=<anything the database accepts>          # risky
```

### Batch and Bulk Operations

Use batch endpoints only when they reduce real client/network pain. Preserve request order in responses; set a max batch size; keep idempotency clear. Default mutating batches to all-or-nothing; return per-item errors only when partial success is an explicit requirement.

**Bulk delete by filter is the single most dangerous operation.** An empty/unset filter matches everything; a typo deletes everything. Such endpoints must default to preview/validate-only and require an explicit `force` flag to execute; design the default so a missing filter or flag deletes *nothing*. Return a never-under-reported match count plus a sample of matching IDs to spot-check.

### Import and Export

Move data **directly between the API and an external store** (S3, Samba, GCS), cutting out a client that round-trips every byte. `:import`/`:export` are per-resource custom methods returning LROs. **Import/export is not backup/restore** — it makes no snapshot, consistency, or full-replacement guarantee; re-importing the same data creates duplicates by design.

- **Two orthogonal config objects, by design.** Separate *transport* from *transformation*: a polymorphic `DataSource`/`DataDestination` (how to reach the store — discriminated by a `type` field: `S3DataSource`, `SambaDataSource`) and an `InputConfig`/`OutputConfig` (how to (de)serialize — `contentType` json/csv, `compressionFormat` zip/bz2, file-splitting). Do **not** flatten these into one struct with reused fields (`password` for both an S3 secret and a Samba login) — that breeds confusion and couples unrelated stores. Keep `filter` *next to* (not inside) `OutputConfig` — it selects rows before serialization runs.
- **Source globs, destination prefixes.** A source reads many files (a glob, `archive-*.gz`); a destination writes under a path prefix / filename template. They overlap but are not identical — keep them separate interfaces so each evolves independently.
- **Identifiers.** If the API doesn't allow user-chosen ids, **ignore the `id` on import** (it behaves like batch-create). Keep ids *on export* so you can trace provenance.
- **Retry with `importRequestId`.** Export retry is safe (independent attempt; leave partial output for the owner to judge — you can't know what fraction is "enough"). Import retry is not: a failed run may have created rows, so a naive retry duplicates them. Wrap in a transaction where the store supports it; otherwise stamp each record with a client-supplied `importRequestId` the service caches and dedups against (see Idempotency).
- **One resource type, no filtering on the way in.** Import/export operate on a single resource type with no children — wanting parent+child is the signal you actually want backup/restore. Filter on *export* (it's just a `List`); do **not** filter on *import* (it forces ingress data through business logic and breaks on service-computed fields — let the user pre-filter).

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

### Caching and Conditional Requests

The same `ETag` has a **second, distinct use**: cutting read cost. Concurrency uses `If-Match` → `412` to *guard a write*; caching uses `If-None-Match` → `304` to *skip regenerating a read*. Don't conflate them.

- **Conditional GET.** Client sends back the last `ETag` as `If-None-Match`; if unchanged the server returns `304 Not Modified` with no body. This still costs a round trip — its payoff is **avoiding expensive regeneration** (heavy queries) and bandwidth, not avoiding the network. Worth it when building the response is costly.
- **TTL hints.** Let the origin tell clients how long data is fresh via `Cache-Control: max-age=...` (or `Expires` for an absolute timestamp). A single one-size-fits-all TTL per resource type is the sane default; per-response tuning (shorter TTL for volatile rows) is an optimization, not a starting point.
- **Invalidation menu — pick by tolerance for staleness.** **TTL**: simplest, but you serve stale data for up to the whole window after an origin change. **Notification-based** (events evict entries): smallest stale window, but needs a broker and a heartbeat to detect a dead notification path. **Write-through** (update cache and origin together): near-zero stale window, practical mainly server-side. Default to TTL; escalate only when staleness actually hurts.
- **Cache the fewest places possible** (ideal: zero). Stacked caches (client + server + CDN + browser) compound staleness and make freshness impossible to reason about.
- **Gotcha — a broken deploy can poison caches forever.** If a release bug stops your code from setting cache headers and a downstream emits `Expires: Never`, that response sticks in browser/CDN/ISP caches you don't control — fixing the code and clearing your own cache is *not enough*. The only recovery is changing the URL. Never let a canary/release path silently fall through its cache-header logic; treat cache headers as part of the contract a release must not break.

## Security Manual

Security starts in API design. Edge/gateway validation is defense-in-depth, not the authority — **every service independently validates and authorizes regardless of edge checks** ("trust, but verify").

### Threat Model

For any sensitive or public API: identify assets → actors (users, admins, services, partners, attackers) → trust boundaries → entry points → sensitive data fields → abuse cases → controls → verify controls with tests.

**Use named frameworks; don't freestyle.** Drive the exercise from a data-flow diagram and apply **STRIDE per element** — walk every process and data flow and ask which of Spoofing, Tampering, Repudiation, Information disclosure, Denial of service, Elevation of privilege applies there (per element, not once for the whole system). Anchor the *objective* in the **OWASP API Security Top 10** (broken object-level / function-level authorization, broken authentication, mass assignment, excessive data exposure, etc.) — verify your design mitigates each. Then prioritize with **DREAD scoring**: rate each threat 1–10 on Damage, Reproducibility, Exploitability, Affected users, Discoverability and rank by the average — define what each score means up front so ratings are consistent (and consider dropping Discoverability → DREAD-D, since relying on obscurity is not a control). Validate after mitigations; re-review on change.

Minimum controls: authentication; authorization per endpoint *and* per resource; input validation; output encoding where relevant; rate limits/quotas for abuse-prone endpoints; request size limits; TLS (decide where it terminates and whether internal hops need mTLS); safe error responses; audit logs for sensitive actions; secrets outside code, rotated, revocable, short-lived where practical.

### Authentication

Use the platform standard. If choosing: browser/mobile users → OAuth2/OIDC authorization code + PKCE; service-to-service → mTLS, workload identity, signed tokens, or OAuth2 client credentials; partners → client credentials or signed requests with key rotation; webhooks → signature verification, timestamp tolerance, replay protection.

**Never use ID tokens as access tokens** — ID tokens convey user identity to the client, not authorization to call resources.

**Request signing — three tiers, by what you need to prove.** When a bearer token isn't enough (partner/server callers, message integrity, non-repudiation), choose:

- **OAuth2 bearer tokens** — default for most callers. Proves the bearer *holds a token*; the token itself is the secret, so anyone who captures it can replay. Lean on TLS and short lifetimes.
- **HMAC (shared secret)** — sign a request fingerprint with a secret both sides hold. Proves origin *and* integrity (tampering invalidates the signature) and is fine for the majority of partner cases. But it's **symmetric**: the verifier holds the same key that signs, so it cannot prove to a *third party* that the client (not the server) produced the request — no non-repudiation.
- **Digital signature / HTTP request fingerprinting** — client signs with a *private* key; server verifies with the registered *public* key. Asymmetric, so it adds **non-repudiation** (only the client could have signed) on top of origin + integrity. Sign a canonical fingerprint — `(request-target)` (method + path), `host`, `date`, and a `digest` (hash of the body, so you don't sign the whole payload) — not the raw serialized body, whose byte form varies (key order, encoding) and breaks verification. The client generates the keypair (the private key must never reach the server, or non-repudiation is lost). Reserve this for when a disinterested party must later verify the sender; it's heavier than HMAC.

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

Synthesized offline from four books. These pointers are for a maintainer reopening the sources — they are not needed by an agent operating from this manual alone.

- `GDP` — Geewax, *API Design Patterns* (Manning 2021): resource design, naming, IDs, standard/custom methods, field masks, pagination (cursor stability/opaque-encrypted tokens), filtering, batch, import/export, versioning, idempotency/request-dedup, LROs (cancel/pause/resume), purge/validateOnly, soft deletion, revisions, singleton sub-resources, association vs add/remove, polymorphism, anonymous writes, rerunnable jobs, copy/move, request authentication (digital signatures).
- `MAA` — Gough/Bryant/Auburn, *Mastering API Architecture* (O'Reilly 2022): contracts/OpenAPI, REST vs gRPC, traffic patterns, ADRs, gateways/mesh and their anti-patterns, contract/component testing, release, observability, threat modeling (STRIDE-per-element, OWASP API Top 10, DREAD), OAuth2/OIDC, mass assignment, evolution, zero trust.
- `BM` — Newman, *Building Microservices* 2e (O'Reilly 2021): boundaries, coupling taxonomy, communication, sagas, CAP per-capability, cascading failure/bulkheads, confused deputy, CDC, migration patterns, breaking-change avoidance, caching/conditional requests/invalidation.
- `BMN` — Kapexhiu, *Building Microservices with Node.js* (Packt 2024): Node implementation, event loop, graceful shutdown, health checks, Joi validation, security headers, circuit breakers in code, observability.
