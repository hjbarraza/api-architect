---
name: api-test
description: 'This skill should be used when the user asks to "write tests for this API", "author the test suite", "add endpoint/handler tests", "set up contract tests / Pact / CDC", "stand up integration tests with Testcontainers", "test against a real database/queue", "add load/security/smoke tests", "cover the failure cases", "build a test plan for these endpoints", or otherwise needs the test suite for an API designed or implemented in this plugin. It is the TEST phase of the api-architect lifecycle (design → implement → test → review → evolve) and owns the manual''s Testing Matrix.'
---

<objective>
Author the test suite for an API so coverage is **provable**, not assumed. This is the TEST phase: it turns the manual's Testing Matrix into actual tests — unit, handler/API, contract (CDC/Pact), component, integration (Testcontainers against real deps at prod version), end-to-end, load, security, and smoke — each chosen by the matrix's "Use when" rules, not by habit.

This skill **owns the Testing Matrix**. It authors tests; it does not gate merges. (api-review reads the matrix to *audit* coverage adversarially; api-test *creates* the coverage api-review will check.) The two are complementary: build the suite here, prove it elsewhere.

The manual is the source of truth. **If this skill and the manual disagree, the manual wins.** This router never restates matrix content — it points into the exact section and enforces that it is read live before tests are written.
</objective>

<essential_principles>
Operating stance for every test below. The detailed rules live in the manual's Testing Matrix — read it live (see `<quick_start>`); do not work from this summary.

**1. The matrix decides what to write, not habit.** Each test type has a "Use when" trigger. Apply the trigger to *this* API's risk class; skip a type only with a reason the matrix would accept. Detail: manual → Testing Matrix.

**2. Contract proves shape; behavior proves correctness.** A green contract test does not prove the endpoint behaves. Pair every contract test with a component/integration test for the behavior (right status, empty-set vs. 404, authz-denied path, side effects). This distinction is load-bearing. Detail: manual → Testing Matrix (contract-vs-component).

**3. Test failures, not just success.** The minimum endpoint test set is the floor: success, invalid input, missing auth, forbidden, not found, conflict/precondition, idempotent retry, pagination/filtering. An untested negative path is a gap. Detail: manual → Testing Matrix (minimum endpoint test set).

**4. Integration uses the real dependency.** Hand-rolled stubs drift and go green against broken integrations. For DB/queue/cache, run the *real* dependency at the prod version via Testcontainers; for contracts use generated stubs/recordings. Detail: manual → Testing Matrix (integration boundaries).

**5. Follow the repo's toolchain first.** Use the test runner, assertion style, and HTTP-inject API already in the repo before introducing a new tool; the matrix's toolchain note fills gaps, it does not override a working convention.
</essential_principles>

<quick_start>
**FIRST OPERATIONAL STEP — do this before writing or editing any test.**

Read the owned section live (do not work from memory):

1. Open `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md` and read, in full, the **Testing Matrix** section — the test-type table and its "Use when" column, the **contract-vs-component** distinction, **consumer-driven contracts (CDC)**, **integration boundaries** (Testcontainers, real deps at prod version), and the **minimum endpoint test set**. Also read the toolchain note that precedes it.

2. Open `${CLAUDE_PLUGIN_ROOT}/references/agent-native-addendum.md` and read it. Tests must cover the agent-as-consumer surface to the same depth as the HTTP surface: idempotent tools (replay returns the cached result, no double-write), dry-run/preview primitives (return the effect without committing), and machine-actionable errors (retryable vs. terminal). A destructive primitive needs a test proving the default action changes nothing without explicit confirmation.

Treat the Testing Matrix as the spec for *what* to test. This skill is the index and the order of operations; the manual holds the rules.
</quick_start>

<intake>
**Ask the user (skip only if the request already names the answers):**

1. What is under test — a specific endpoint/handler, a whole service, or a shared/external contract?
2. Risk class: public, sensitive, internal, or shared/external? (Sets which matrix rows apply — Load and Security are triggered by public/sensitive/SLO-bound APIs.)
3. What real dependencies does it touch (DB, queue, cache, downstream services), and at what prod versions?
4. Is there a contract (OpenAPI/protobuf) and named consumer(s)? Same-org consumer → CDC is in scope.

**Wait for the response before proceeding** unless the scope and risk class are already unambiguous.
</intake>

<process>
**Test-authoring workflow.** Copy this checklist and track it:

```
API Test Progress:
- [ ] Step 0: Read the Testing Matrix + addendum live (REQUIRED FIRST)
- [ ] Step 1: Establish scope, risk class, real deps, contract/consumers
- [ ] Step 2: Build the test plan (endpoints → required tests) from the template
- [ ] Step 3: Author per-type tests the matrix marks REQUIRED
- [ ] Step 4: Scaffold CDC/Pact + contract-generated stub (if Contract applies)
- [ ] Step 5: Stand up Testcontainers integration tests (real deps, prod version)
- [ ] Step 6: Cover the agent-native surface (addendum parity)
- [ ] Step 7: Run the suite; record a concrete observed result; list any gaps
```

<step_0>
**Read the source of truth NOW — before writing any test.** Complete the `<quick_start>` first operational step: the manual's **Testing Matrix** and the **agent-native addendum**, live. Do not author from memory of "typical" test suites — the matrix carries the contract-vs-component distinction, the CDC direction rule, and the minimum endpoint test set that generic knowledge omits.
</step_0>

<step_1>
**Establish scope and applicability.** From intake fix: the change set, risk class, real dependencies (+ prod versions), and contract/consumers. Risk class drives matrix applicability — internal single-service work may skip Load and heavy Security; public/sensitive/SLO-bound work does not.
</step_1>

<step_2>
**Build the test plan.** Render `${CLAUDE_PLUGIN_ROOT}/skills/api-test/templates/test-plan.md`. Mark each Testing-Matrix row REQUIRED or N/A-with-reason, then map every endpoint to its minimum test set. The plan is the coverage contract the rest of the steps fulfill — an endpoint or matrix row left off the plan is a gap, not an omission.
</step_2>

<step_3>
**Author the per-type tests the matrix marks REQUIRED.** Use the repo's toolchain. For each endpoint, write the minimum set: success; invalid input; missing auth (if protected); forbidden (if authz differs from authn); not found; conflict/precondition where state matters; idempotent retry where the mutation is retryable; pagination/filtering for lists. Write **component** tests for behavior at complex service boundaries (mocked external deps) and **unit** tests for non-trivial pure logic. Do not treat OpenAPI validity as behavior coverage.
</step_3>

<step_4>
**Scaffold CDC/Pact + a contract stub (only if Contract is REQUIRED).** For shared/external APIs: producer-defined contracts by default; for same-org consumers prefer **consumer-driven contracts** — the consumer publishes expectations that run in the **producer's** CI so a breaking change fails the producer build pre-deploy. Generate the consumer stub from the contract or a recording (never hand-roll a stub — it drifts green). The contract test verifies request/response **shape**; pair it with the §3-behavior test so a green contract is not mistaken for correct behavior.
</step_4>

<step_5>
**Stand up Testcontainers integration tests (only if Integration is REQUIRED).** For DB/queue/cache and downstream adapters, run the **real** dependency at the **prod version** in a container — not an in-memory substitute. Lifecycle: start container → migrate schema → seed → exercise the path → teardown. Target the cases that only a real dependency proves: unique-constraint conflict → 409, idempotent-replay with no double-write, transaction rollback, queue redelivery.
</step_5>

<step_6>
**Cover the agent-native surface.** Per the addendum: every agent-reachable primitive/tool gets the same negative-path depth as its HTTP twin — idempotent replay returns the cached result, dry-run/preview returns the would-change effect without committing, errors are testably retryable-vs-terminal. For destructive/irreversible primitives, add a test proving the default action changes nothing absent explicit (server-verified) confirmation.
</step_6>

<step_7>
**Run and verify — green is necessary, not sufficient.** Execute the suite and record a concrete observed result (the runner output, a failing-then-passing negative test, a container-backed conflict returning 409). Confirm negative paths actually fail the right way, not that they merely exist. List remaining coverage gaps in the plan's §7 with a reason or follow-up. If the suite cannot be run here, say so plainly.
</step_7>
</process>

<quick_reference>
**Test-type selection (apply the matrix's "Use when", read live):**

- **Unit** — non-trivial pure logic / business rules.
- **Handler/API** — every endpoint (the minimum test set lives here).
- **Contract** — shared or external APIs; same-org consumer → CDC in the producer's CI.
- **Component** — complex service boundaries, external deps mocked, *behavior* asserted.
- **Integration** — DB/queue/downstream; real dep at prod version via Testcontainers.
- **End-to-end** — a few high-value user journeys only.
- **Load** — public/high-volume/SLO-bound.
- **Security** — sensitive or public surfaces.
- **Smoke** — every deployable API.

The load-bearing rules (contract proves shape not behavior; CDC runs in the producer's CI; real deps over hand-rolled stubs; the minimum endpoint test set) are not restated here — read them live in the manual's **Testing Matrix**.
</quick_reference>

<lifecycle_handoff>
This is the TEST phase. Hand off when the task is actually a different phase:
- Open design decisions, contract shape, resource modeling → **api-design**.
- Server code to build before it can be tested → **api-implement**.
- Pre-merge gate / adversarial audit of existing coverage → **api-review** (it reads the matrix to *check*; this skill *authors* it).
- Versioning, deprecation, compatibility tests for a change → **api-evolve**.
</lifecycle_handoff>

<reference_index>
**Manual (source of truth):** `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md`
Owned section: **Testing Matrix** (test-type table + "Use when"; contract-vs-component; consumer-driven contracts; integration boundaries / Testcontainers; minimum endpoint test set; toolchain note). If this skill and the manual disagree, the manual wins.

**Agent-native addendum:** `${CLAUDE_PLUGIN_ROOT}/references/agent-native-addendum.md`
Agent-as-consumer coverage: idempotent tools, dry-run/preview primitives, machine-actionable errors, default-changes-nothing for destructive primitives.

**Template:**
- `${CLAUDE_PLUGIN_ROOT}/skills/api-test/templates/test-plan.md` — maps every endpoint to its required tests and every matrix row to REQUIRED / N/A; the coverage contract for the suite.
</reference_index>

<success_criteria>
A well-executed api-test:
- Read the owned Testing Matrix and the agent-native addendum **live before** writing any test.
- Produced a test plan from the template mapping every endpoint to its minimum test set and every matrix row to REQUIRED / N/A-with-reason.
- Authored the per-type tests the matrix marks REQUIRED using the repo's toolchain, covering negative paths, not just happy paths.
- Scaffolded CDC/Pact with a contract-generated stub where shared/external, keeping contract (shape) separate from behavior coverage.
- Stood up Testcontainers integration tests running the real dependency at prod version — no in-memory fakes, no hand-rolled stubs.
- Covered the agent-native surface to the same depth as the HTTP surface (idempotent replay, dry-run, retryable-vs-terminal errors, destructive default-changes-nothing).
- Ran the suite and backed completion with a concrete observed result — or stated explicitly that it could not be run — and recorded any gaps.
</success_criteria>
