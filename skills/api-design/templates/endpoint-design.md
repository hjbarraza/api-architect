# <METHOD> <path>

> Adapted from the API manual's "Templates → Endpoint Design". The manual is the source of truth.
> Work through one operation here before writing it into the contract (OpenAPI/proto/AsyncAPI).

## Purpose
<the single job this operation does; the resource and its lifecycle>

## Auth
- **Authentication:** <required scheme>
- **Authorization:** <scope(s) + per-resource ownership/tenancy check; enforced in the data-owning service, not only the gateway>

## Idempotency
<GET is safe. State explicitly whether this is idempotent and how it is implemented.
For retryable POST: client-supplied idempotency key, body-fingerprint compare on hit, 409 on mismatch.
PATCH/PUT/DELETE: say how the service guarantees the effect, not just the method.>

## Request
- **Path/query params:** <validated; allowed filter fields + operators; sort fields + default order>
- **Body (writable fields allow-list):** <only fields a client may set, per endpoint — reject unknown fields; never bind directly to a persistence entity>
- **PATCH semantics:** <JSON Merge Patch default — omitted = unchanged, null = clear; or explicit field mask>
- **IDs:** <opaque strings; large ints / decimals / money as strings>
- **Content-type / size limits:** <…>

## Response
- **Success:** <status + body; list responses are an object wrapper { items, nextPageToken }, never a bare array>
- **Field rules:** <ISO-8601 UTC timestamps; units in names; positively-named booleans; no secrets/stack traces/SQL/internal hosts>
- **Field mask on GET:** <full resource unless a mask is given>

## Errors
<Use the repo's error shape, else { error: { code, message, details, requestId } }.
List the status codes this endpoint can return and when — e.g. 400 invalid, 401 unauth, 403 forbidden,
404 not found / hidden, 409 conflict, 412 failed If-Match, 429 rate limited.>

## Pagination / filtering
<pageSize + opaque pageToken (or repo convention); stable ordering; documented default & max page size;
explicit validated filters; no database syntax exposed>

## Side effects
<state transitions, events published, downstream calls, anything not obvious from the verb —
do not hide extra transitions inside a standard method>

## Timeout / retry behavior
<sync if within the request timeout, else 202 + operation resource with explicit `done` flag;
outbound calls: timeout + bounded retry + backoff with jitter; Retry-After on 429/503>

## Examples
<at least one worked request + response, including an error example>

## Tests (handed to IMPLEMENT/REVIEW)
<success; validation failure; not-found; unauthorized/forbidden; idempotent retry; compatibility risk>

## Agent-native parity
<which user action this serves, and confirmation the agent has create/read/update/delete coverage for the entity — no orphan UI action>
