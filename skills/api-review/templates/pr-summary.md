# API Review: <PR title / change name>

**Verdict:** `MERGE-READY` | `BLOCKED` — <one line: why>
**Scope:** <PR # / branch / files> · **Risk class:** public | sensitive | internal | shared/external
**Reviewed against:** api-manual.md (Security Manual, Testing Matrix, Pre-Merge Review Checklist) + agent-native-addendum.md

> The manual is the source of truth. Every verdict below cites a manual rule and a concrete artifact (file+line / test name / diff hunk). Unproven checklist items default to *not met*.

---

## Blocking findings (must fix before merge)

List BLOCKs first. Omit this section only if there are none.

- **[BLOCK] <short title>** — <what is wrong>.
  - Manual rule: <section + rule, e.g. Security Manual → Authorization / confused-deputy>.
  - Evidence: <file:line or diff hunk; or "no test exists for <case>">.
  - Fix: <concrete change required>.

## Advisory findings (non-blocking)

- **[ADVISORY] <short title>** — <improvement>. Evidence: <artifact>.

---

## Checklist verdicts

One line per area. `PASS` requires cited evidence; `BLOCK`/`N/A` as applicable.

- **Added / changed:** <what the API change does>
- **Contract:** paths/methods/naming consistent; opaque IDs; explicit request/response/error schemas; status codes per table; pagination/filter/field-mask semantics — `PASS|BLOCK` <evidence>
- **Security:** authn standard; per-resource authz at the data owner; signed-token identity propagation; field allow-list (no mass assignment); edge validation; safe errors; abuse controls — `PASS|BLOCK` <evidence: code + test>
- **Tests:** success + meaningful failures; contract-vs-component distinction honored; CDC for shared APIs; real deps for integration; minimum endpoint test set — `PASS|BLOCK` <evidence: test names>
- **Compatibility:** REST *and* protobuf rules; schema-diff gate; breaking changes surfaced — `PASS|BLOCK|N/A` <evidence: diff output>
- **Observability:** request IDs + safe error codes; latency/error metrics; readiness checks real deps — `PASS|BLOCK` <evidence>
- **Idempotency / resilience:** mutation idempotency key + body fingerprint; timeouts + bulkheads + circuit breakers; bounded retries gated by method safety — `PASS|BLOCK|N/A` <evidence>
- **Agent-native parity:** every new user action + entity has an agent-reachable CRUD path; behavior is prompt/primitive-driven — `PASS|BLOCK` <evidence>
- **Docs:** contract / OpenAPI / examples updated — `PASS|BLOCK` <evidence>
- **Rollout:** rollout/rollback plan for risky changes; deprecation lifecycle if applicable — `PASS|BLOCK|N/A` <evidence>

---

## Reviewer agent summaries

- **api-contract-reviewer:** <one-line verdict + key finding>
- **api-security-reviewer:** <one-line verdict + key finding>
- **api-compatibility-reviewer:** <one-line verdict + key finding>

---

## "Done when" gate

MERGE-READY only when all are true (manual's Pre-Merge "Done when"):

- [ ] Implementation matches the documented contract
- [ ] Tests pass locally; negative tests cover likely client mistakes
- [ ] Security controls in place (authz + mass-assignment evidenced)
- [ ] Observability sufficient to debug a production incident
- [ ] Docs / OpenAPI updated
- [ ] Backward compatibility preserved, or migration documented
- [ ] Change is small enough to review
