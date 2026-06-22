# API Test Plan: <API / service name>

**Scope:** <PR # / branch / files / contract under test>
**Risk class:** public | sensitive | internal | shared/external · **Prior version:** <vN or none>
**Authored against:** api-manual.md (Testing Matrix) + agent-native-addendum.md

> The manual is the source of truth. This plan exists to make coverage **provable**: every endpoint maps to a concrete required test, and every Testing-Matrix row is either applied or explicitly marked N/A with a reason. An untested failure mode is a gap, not a pass.

---

## 1. Matrix applicability (whole-API)

One line per Testing-Matrix row. Mark `REQUIRED` / `N/A`. `N/A` needs a reason the manual would accept.

| Test type | Status | Reason / scope |
| --- | --- | --- |
| Unit | | <which business rules / pure logic> |
| Handler/API | REQUIRED | every endpoint (see §2) |
| Contract | | shared/external API? CDC (producer CI) vs producer-defined |
| Component | | complex service boundaries with mocked external deps |
| Integration | | real deps via Testcontainers at prod version (DB/queue/cache) |
| End-to-end | | the few high-value journeys (list them) |
| Load | | public/high-volume/SLO-bound? target latency/throughput |
| Security | | sensitive/public? authz, injection, data-leak cases |
| Smoke | REQUIRED | deployable → basic prod-readiness check |

---

## 2. Endpoint → required tests

One block per endpoint. The **minimum endpoint test set** (manual) is the floor; add rows where state matters. Drop a row only with `N/A: <reason>` (e.g. unauthenticated public endpoint → no auth/forbidden rows).

### `<METHOD> <path>`  — <one-line purpose>

| Case | Type | Expected | Test name / status |
| --- | --- | --- | --- |
| Success (happy path) | Handler | <2xx + response shape> | |
| Invalid input | Handler | 400 + error shape | |
| Missing auth | Handler | 401 | <N/A if public> |
| Forbidden (authz ≠ authn) | Handler/Security | 403, not 404-leak | <N/A if no per-resource authz> |
| Not found | Handler | 404 | |
| Conflict / precondition | Handler | 409 / 412 | <only where state matters> |
| Idempotent retry | Integration | replay returns cached result, no double-write | <only if mutation is retryable> |
| Pagination / filtering | Handler | object-wrapped page; bounded filter | <lists only> |
| Mass-assignment guard | Security | non-allow-listed field ignored/rejected | <write paths> |
| Authz at data owner | Security/Integration | other-tenant resource denied | <multi-tenant> |

_(repeat the block for each endpoint)_

---

## 3. Contract (CDC / Pact) plan

Fill only if Contract is REQUIRED.

- **Direction:** producer-defined | consumer-driven (CDC). Same-org consumer → prefer CDC.
- **Consumer(s):** <names>
- **Pact files / location:** <path>; broker: <url or N/A>
- **Where it runs:** the consumer's expectations run in the **producer's** CI so a breaking change fails the producer build pre-deploy.
- **Stub source:** contract-generated stub / recording (NOT hand-rolled — those drift green).
- **Boundary it guards:** request/response **shape** only. Behavior is proven by component/integration tests, not the contract (green contract ≠ correct behavior).

---

## 4. Integration (Testcontainers) plan

Fill only if Integration is REQUIRED.

- **Real dependencies (prod version, not in-memory substitutes):**
  | Dependency | Image\:tag (prod version) | What it proves |
  | --- | --- | --- |
  | <postgres> | `postgres:<ver>` | state/constraint behavior, real SQL |
  | <queue/cache> | `<image>:<ver>` | downstream adapter behavior |
- **Container lifecycle:** start per suite (or reuse) → migrate schema → seed → run → teardown.
- **Cases that REQUIRE a real dep:** <unique-constraint conflict → 409, idempotent-replay no double-write, transaction rollback, queue redelivery>.

---

## 5. Security & load (if risk class demands)

- **Security cases:** authz-denied at the data owner, mass-assignment, injection, data-leak in error/response, abuse-control trip. → mapped in §2 rows + dedicated tests.
- **Load profile:** target latency (p50/p95/p99), throughput, SLO; tool (k6/Artillery); ramp + bottleneck to probe. `N/A` if not SLO-bound.

---

## 6. Agent-native coverage (addendum)

- [ ] Each agent-reachable primitive/tool has the same negative-path coverage as its HTTP twin (idempotent replay, dry-run/preview returns effect without committing, retryable-vs-terminal error distinction).
- [ ] Destructive/irreversible primitives have a test proving the **default action changes nothing** without explicit confirmation (dry-run-then-commit / server-verified confirmation).

---

## 7. Coverage gaps (must close or justify)

List any matrix row or endpoint case left untested and why. A gap with no accepted reason blocks "tests complete".

- <gap> — <reason / owner / follow-up>

---

## Done when

- [ ] Every endpoint in §2 has the minimum test set (less only with `N/A: <reason>`).
- [ ] Every REQUIRED matrix row is implemented; every N/A has a manual-acceptable reason.
- [ ] Contract tests verify shape only; behavior is proven by component/integration.
- [ ] Integration tests run the **real** dependency at prod version (no in-memory fakes, no hand-rolled stubs).
- [ ] Negative paths (invalid, unauth, forbidden, not-found, conflict) are tested, not just happy paths.
- [ ] Agent-native primitives carry equivalent coverage.
- [ ] Tests pass locally with a concrete observed run (not just "should pass").
