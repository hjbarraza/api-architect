# API Documentation & Developer-Portal Outline: <api name>

> Adapted from the API manual's "Agent Contract", "Default Operating Loop" (step 7: docs + examples),
> "Resource-Oriented API Rules → Naming", and "Request and Response Design → Compatibility".
> **The manual is the source of truth.** The **contract** (OpenAPI/proto/AsyncAPI) is the second source of truth
> for this phase: everything below is *generated from and validated against* the contract — never written beside it.
> If docs and the contract disagree, the contract wins (fix the contract, or hand back to api-design).

## Source of generation
- **Contract file(s):** <path(s) to OpenAPI/proto/AsyncAPI — the single input>
- **Generator / toolchain:** <repo's existing doc + SDK generator; reuse before introducing a new one>
- **Regeneration trigger:** <docs + SDKs re-derive on every contract change; not hand-edited downstream>

---

## 1. Overview (landing)
- **What this API does / who consumes it:** <browser | mobile | partner | internal service | batch | operator | agent>
- **Base URL(s) / environments:** <prod, sandbox>
- **Versioning & stability policy (consumer-facing):** <how stable/beta/deprecated are signalled; mirrors Compatibility>

## 2. Authentication (from Security Manual)
- **Scheme:** <OAuth2/OIDC + PKCE | client credentials | mTLS | signed webhooks — the real scheme>
- **Scopes / permissions:** <list>
- **Token handling:** <secure path only — never an ID token used as an access token; never a real secret in an example>

## 3. Conventions (document once, link everywhere)
- **Naming:** <surface the contract's names verbatim — units in names, no implementation terms; do not re-coin>
- **Pagination:** <object-wrapped lists `{ items, nextPageToken }`; opaque `pageToken`; documented default & max page size>
- **Idempotency & retries:** <idempotency-key usage for retryable writes; `Retry-After` on 429/503; client retry/backoff guidance>
- **Errors (consumer-facing table):**

  | Status | When | Retryable? | Body shape |
  |--------|------|-----------|------------|
  | 400 | <invalid input> | no | `{ error: { code, message, details, requestId } }` |
  | 401 / 403 | <unauth / forbidden> | no | … |
  | 404 | <not found / hidden> | no | … |
  | 409 / 412 | <conflict / failed If-Match> | no | … |
  | 429 / 503 | <rate limited / unavailable> | yes (honor `Retry-After`) | … |

  > No stack traces, SQL, internal IDs/hosts, or implementation terms in any documented error body.

## 4. Reference (generated from the contract — one block per operation)
For each operation, generated verbatim from the contract:

```
### <METHOD> <path>   (or <Service.Method> for gRPC)
Stability: <stable | beta | deprecated — and sunset date + migration path if deprecated>
Purpose:   <the single job; from the contract description>
Auth:      <scheme + scopes; per-resource check noted>
Request:   <path/query params, writable-field allow-list, PATCH/field-mask semantics — from schema>
Response:  <status + schema; lean shape; object-wrapped lists>
Errors:    <status codes this operation returns, linking the table above>
Examples:  <link to the worked example(s) embedded in the contract — see §5>
```

## 5. Worked examples (part of the contract)
- Location: <spec `examples` / proto comments / AsyncAPI payload examples — versioned with the contract>
- Per operation: **≥1 worked request + response** and **≥1 error example**.
- Every example **validates against its schema** and is **runnable**.
- **All secrets/tokens/PII/internal hosts redacted or placeholdered.**

## 6. SDKs / client libraries
- **Target language(s):** <…>
- **Generation:** <generator config / outline — names carry from the contract verbatim>
- **Must document/implement:** idempotency-key support, retry + `Retry-After` handling, typed error model, auth flow.
- **Usage snippet:** <redacted; shows the secure auth path>

## 7. Guides
- **Quickstart:** <first successful call, end to end>
- **Auth setup:** <obtain credentials → first authenticated call>
- **Pagination & error handling:** <iterate pages; handle retryable vs. terminal errors>
- **Common tasks:** <task-oriented how-tos that link generated reference — never re-describe endpoints in prose>

## 8. Changelog & deprecations (the human-readable compatibility surface)
- **Changelog:** <added/changed per release; compatible vs. breaking, per Compatibility rules>
- **Deprecations:** <endpoint/field, deprecation date, **sunset date**, **migration path**>
- > The schema-diff CI gate, versioning mechanics, registry, and actual route retirement belong to **api-evolve**.
  > This page is the notice; EVOLVE executes the retirement.

## 9. Support
- <status page, contact, rate-limit policy, SLA/SLO surface consumers can rely on>

---

## Agent-native parity map (required — from the addendum)
The docs must let an **agent** consumer (not only a human) succeed. Every entity exposes a discoverable
create/read/update/delete path; errors are documented as retryable vs. terminal; lean response shapes are shown.

| Entity / user action | Documented agent path (operation/tool) | C | R | U | D | Errors doc'd retryable vs terminal? |
|----------------------|----------------------------------------|---|---|---|---|--------------------------------------|
| <entity> | <op(s)> | ☐ | ☐ | ☐ | ☐ | ☐ |
| <user action> | <op(s)> | — | — | — | — | ☐ |

> No documented user action without a documented agent path.

## Generation checklist
- [ ] Every artifact generated from the contract and validates against it (no drift-prone hand transcription).
- [ ] Names in docs/SDKs are the contract's names (units, casing) — none re-coined.
- [ ] Error table, pagination, idempotency, and auth documented for consumers.
- [ ] ≥1 success + ≥1 error example per operation, embedded in the contract, runnable, redacted.
- [ ] Stability labels + deprecation notices (sunset + migration) present; mechanics deferred to api-evolve.
- [ ] Security checklist passed (no leaked secrets/PII/internals; secure auth path).
- [ ] Agent-native parity map complete.
