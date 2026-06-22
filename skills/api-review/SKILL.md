---
name: api-review
description: This skill should be used when the user asks to "review an API change", "review this PR", "do a pre-merge review", "security review the API", "check API backward compatibility", "run the API review checklist", or is at the VALIDATE phase before merging API work. It runs the Pre-Merge Review Checklist adversarially and dispatches this plugin's bundled reviewer agents.
---

<objective>
Gate API changes before merge. This is the VALIDATE phase of the api-architect plugin: api-design (shape) → api-implement (build) → **api-review (gate)** → api-evolve (change over time).

The review is **adversarial by default**: assume the change is broken until evidence proves otherwise. A green CI run, a passing schema-diff, and a confident PR description are claims, not proof. Hunt for the missing negative test, the authorization check that trusts the gateway, the field the client must not be able to write, the breaking change hiding behind a "compatible" label.

This skill owns three manual sections — **Security Manual**, **Testing Matrix**, **Pre-Merge Review Checklist** — and dispatches three bundled reviewer agents (`api-contract-reviewer`, `api-security-reviewer`, `api-compatibility-reviewer`) that live in this plugin's `agents/` directory.
</objective>

<essential_principles>
**1. Verdicts trace to the manual.** Every verdict traces to a line in `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md`. Do not review from memory of API best practices — read the owned sections live, every time, because they carry specifics (confused-deputy, mass-assignment field lists, contract-vs-component distinction) that generic knowledge omits. (The umbrella api-architect skill states the manual's authority once for the whole plugin.)

**2. Adversarial, not confirmatory.** The reviewer's job is to find what is wrong, not to confirm what looks right. Default stance: the change has a defect somewhere; locate it. Treat the author's PR summary as the hypothesis to falsify. Absence of a negative test is itself a finding.

**3. Evidence over assertion.** "Authorization is enforced" is not a finding either way — point to the code path and the test that exercises the forbidden case. "Backward compatible" requires the schema-diff output or the field-by-field rule check, not a label. Every PASS and every BLOCK cites a concrete artifact: a file+line, a test name, a diff hunk, a checklist line.

**4. Security is cross-cutting, never optional.** The Security Manual is **required reading for every review**, even when the diff looks purely additive. Authorization, mass assignment, and validation defects routinely hide in "small" changes. A review that skips security is not a review.

**5. Block on the checklist, not on taste.** The bar is the **Pre-Merge Review Checklist** and the manual rules it points to — not personal style preferences. A finding is a BLOCK only if it violates a manual rule or leaves a checklist item unmet. Style nits are advisory, clearly separated from blocking findings.

**6. Agent-native parity is scoped, not universal.** A missing agent path / orphan UI action is a **BLOCK only when the API under review is agent-facing** (an LLM/MCP caller is a named consumer) **or backs a UI**. For a pure internal service-to-service or partner-webhook API with no agent consumer and no UI, a parity gap is **ADVISORY** — note it, do not block on it. Establish which case applies during scope (intake / Step 1) and state it in the verdict.
</essential_principles>

<intake>
**First, establish scope. Ask the user (skip only if already unambiguous from context):**

1. What is under review — a PR number/URL, a branch diff, or a set of changed files?
2. Is this a public/sensitive API, an internal service, or a shared/external contract? (Determines security and compatibility depth.)
3. Is the API **agent-facing** (an LLM/MCP caller is a named consumer) **or does it back a UI** — or is it a pure internal service-to-service / partner-webhook API? (Determines whether agent-native parity is a BLOCK or advisory — principle 6.)
4. Is there an existing contract (OpenAPI/protobuf) to diff against, and a prior published version?
5. Does the change touch **events, webhooks, message queues, or sagas**? (Determines whether to also dispatch `api-async-reviewer`.)

**Ask only what scope and risk class genuinely require, one point at a time; skip any the diff already answers.** Wait for response before proceeding unless the diff and its risk class are already obvious.
</intake>

<quick_start>
The non-negotiable first move: **read the owned manual sections live before touching code** — Security Manual, Testing Matrix, Pre-Merge Review Checklist in `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md`, plus `${CLAUDE_PLUGIN_ROOT}/references/agent-native-addendum.md`. Then dispatch the bundled reviewer agents (add `api-async-reviewer` if the change touches events/webhooks/sagas), run the checklist adversarially yourself, and write the PR summary. The full procedure is in `<process>` below.
</quick_start>

<process>
**Review workflow.** Copy this checklist and track it:

```
API Review Progress:
- [ ] Step 0: Read owned manual sections + addendum (REQUIRED FIRST)
- [ ] Step 1: Establish scope and risk class
- [ ] Step 2: Gather the diff and the contract
- [ ] Step 3: Dispatch the three reviewer agents (parallel)
- [ ] Step 4: Run the Pre-Merge Review Checklist adversarially
- [ ] Step 5: Adjudicate findings → PASS / BLOCK
- [ ] Step 6: Write the PR summary from the template
```

<step_0>
**Read the source of truth NOW — before looking at any code.** This is the first operational step and it is not skippable.

Read these sections of the manual live, every time — do not review from memory:

1. `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md` — **Security Manual** (threat model, authentication, authorization, write-path/mass-assignment, validation, abuse controls).
2. `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md` — **Testing Matrix** (test types, contract-vs-component, CDC, integration boundaries, minimum endpoint test set).
3. `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md` — **Pre-Merge Review Checklist** (the consolidated gate and its "Done when" bar).
4. `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md` — **Error Design**, **Compatibility**, and **Release and Evolution** (needed to judge contract and compatibility findings).
5. `${CLAUDE_PLUGIN_ROOT}/references/agent-native-addendum.md` — the agent-native parity + CRUD rules. **Apply per principle 6's scope:** when the API is agent-facing or UI-backing, confirm that every new user-facing action and entity has an agent-reachable path (tool/primitive with full create/read/update/delete) and that behavior lives in prompts/primitives, not choreographed code — an orphan UI action with no agent path is then a **BLOCK**. For a pure internal/partner-webhook API, a parity gap is **ADVISORY**.

Do not paraphrase these into the review from memory. Re-read them so the verdicts cite current rules.
</step_0>

<step_1>
**Establish scope and risk class.** From intake, fix: the change set, whether the API is public/sensitive/internal/shared, and the prior contract version. Risk class sets depth — public or sensitive APIs get the full Security Manual threat model and Load/Security rows of the Testing Matrix; internal single-service changes get a lighter but non-zero security pass.
</step_1>

<step_2>
**Gather the diff and the contract.** Obtain the actual changed lines (PR diff, `git diff`, or the file set) and the OpenAPI/protobuf contract plus its prior published version. Without the diff there is no review — do not review from the description alone.
</step_2>

<step_3>
**Dispatch this plugin's bundled reviewer agents — in parallel.** Use the Task tool to launch the three core agents at once (they are independent), plus `api-async-reviewer` when the change touches events/webhooks/queues/sagas (intake Q5). Reference them by name; they live in `${CLAUDE_PLUGIN_ROOT}/agents/`. Do not depend on any external plugin's reviewers.

| Agent | Lens | Owned concerns |
|-------|------|----------------|
| `api-contract-reviewer` | Contract correctness | Paths/methods/naming consistency; opaque IDs; explicit request/response/error schemas; status-code table adherence; pagination/filtering/field-mask semantics; docs/examples updated; **Testing Matrix** coverage incl. contract-vs-component and the minimum endpoint test set. |
| `api-security-reviewer` | Security (adversarial) | The full **Security Manual**: authn; per-resource authorization at the data owner; confused-deputy; mass-assignment field allow-listing; edge validation + unknown-field rejection; abuse controls; safe errors; secrets. |
| `api-compatibility-reviewer` | Backward compatibility | REST *and* protobuf compatibility rules; schema-diff gate; breaking-change detection behind "compatible" labels; rollout/rollback plan; deprecation lifecycle. |
| `api-async-reviewer` *(only if the change touches events/webhooks/queues/sagas)* | Async/event correctness | Event envelope (past-tense fact + id/timestamp/producer/schema-version/correlation); idempotent consumers; saga orchestration vs. choreography; per-capability CP-vs-AP; webhook delivery/retry/signing; reporting store as a versioned contract. |

Give each agent: the diff, the contract (+ prior version), the risk class, and an explicit instruction to read its owned manual sections live and to return findings as `BLOCK` / `ADVISORY` / `PASS` each citing a manual rule and a code/test artifact. Tell them to be adversarial — report the absence of a required negative test as a finding.
</step_3>

<step_4>
**Run the Pre-Merge Review Checklist adversarially yourself.** The agents are specialists; this step is the integrator's own pass over the manual's consolidated gate. Walk every checklist line and, for each, demand the artifact:

- Consumer/use case named; boundary defensible; coupling diagnosed.
- Paths/methods/names consistent; IDs opaque strings (large numbers/decimals as strings).
- Request/response/error schemas explicit; consistent error shape; status codes per the table.
- **Authn + authz enforced (per-resource ownership at the data owner; identity propagated via signed token); write paths allow-list fields (no mass assignment); sensitive fields protected; edge validation.**
- Pagination on lists (object-wrapped); bounded filtering/sorting; PATCH/field-mask merge semantics defined.
- Idempotency for mutations (client key + body fingerprint); timeouts + bulkheads + circuit breakers on outbound calls; bounded retries gated by method safety.
- Logs carry request IDs + safe error codes (nothing on the do-not-log list); latency/error metrics; readiness checks real dependencies.
- Tests cover success **and meaningful failures** (CDC for shared APIs, real deps for integration); contract/docs/examples updated.
- Compatibility impact stated (REST *and* protobuf); schema-diff gate passes; rollout/rollback plan for risky changes.
- **Agent-native parity (scoped — principle 6):** if the API is agent-facing or UI-backing, every new user action and entity has an agent-reachable CRUD path (addendum) and behavior is prompt/primitive-driven, not hard-coded workflow — a gap here is a BLOCK. For a pure internal/partner-webhook API, a parity gap is ADVISORY.

For any line you cannot tie to evidence, the default verdict is **not met** (a finding), not "probably fine".
</step_4>

<step_5>
**Adjudicate.** Merge agent findings with the checklist pass. Classify each:
- **BLOCK** — violates a manual rule or leaves a checklist item unmet. Must be fixed before merge.
- **ADVISORY** — style/clarity/non-blocking improvement; clearly separated.
- **PASS** — verified against the manual with cited evidence.

Overall verdict is **MERGE-READY only when every BLOCK is resolved and the manual's "Done when" bar is met**: implementation matches the documented contract; tests pass locally; negative tests cover likely client mistakes; security controls in place; observability sufficient to debug a prod incident; docs/OpenAPI updated; backward compatibility preserved or migration documented; change small enough to review.
</step_5>

<step_6>
**Write the PR summary.** Render `${CLAUDE_PLUGIN_ROOT}/skills/api-review/templates/pr-summary.md`, filling each section with cited findings and the overall verdict. Lead with the verdict; list BLOCKs first.
</step_6>
</process>

<quick_reference>
**Verdict vocabulary:**

- **BLOCK** — manual rule violated or checklist item unmet → cannot merge.
- **ADVISORY** — non-blocking improvement → may merge, note it.
- **PASS** — verified with cited evidence (file+line / test name / diff hunk).

The high-frequency BLOCK patterns (confused-deputy, mass-assignment, unsigned-identity-propagation, contract-test-as-behavior-coverage, broken-integration stubs, mislabeled breaking changes) are not restated here — read them live in the manual's **Security Manual** and **Testing Matrix**. Orphan-action parity gaps BLOCK only on agent-facing or UI-backing APIs (principle 6); read the **agent-native addendum** for the parity rule itself.
</quick_reference>

<security_checklist>
**Required security pass — every review, non-negotiable.** Read the **Security Manual** live (Step 0) and confirm the change against every one of its subsections — Threat Model, Authentication, Authorization, Write-Path Safety: Mass Assignment, Validation, Abuse Controls — plus safe errors and secrets. The manual carries the per-rule specifics (field lists, fail-open vs. fail-closed, do-not-log list); this skill does not restate them.

For each, cite code **and** test as evidence. A review that cannot cite evidence for authorization and mass-assignment handling is **incomplete** — do not issue a MERGE-READY verdict.
</security_checklist>

<reference_index>
- `${CLAUDE_PLUGIN_ROOT}/references/api-manual.md` — **owned by this skill:** Security Manual, Testing Matrix, Pre-Merge Review Checklist. **Also read for review:** Error Design, Compatibility, Release and Evolution.
- `${CLAUDE_PLUGIN_ROOT}/references/agent-native-addendum.md` — parity + CRUD rules; required reading every review.

**Bundled reviewer agents (this plugin's `agents/`):**

- `api-contract-reviewer` — contract correctness + Testing Matrix coverage.
- `api-security-reviewer` — full Security Manual, adversarial.
- `api-compatibility-reviewer` — REST + protobuf compatibility, schema-diff, rollout.
- `api-async-reviewer` — async/event correctness; dispatch only when the change touches events/webhooks/queues/sagas.

**Template:**

- `${CLAUDE_PLUGIN_ROOT}/skills/api-review/templates/pr-summary.md` — the review output.
</reference_index>

<success_criteria>
A well-executed api-review:
- Read the owned manual sections (Security Manual, Testing Matrix, Pre-Merge Review Checklist) and the agent-native addendum **live before** inspecting code.
- Dispatched the three core bundled reviewer agents — plus `api-async-reviewer` when the change touched events/webhooks/queues/sagas — and integrated their findings.
- Walked every Pre-Merge Review Checklist line adversarially, defaulting unproven items to "not met".
- Produced a security pass that cites code + test for authorization and mass-assignment, every time.
- Classified parity correctly by scope: a gap is a BLOCK on agent-facing/UI-backing APIs and ADVISORY on pure internal/partner-webhook APIs (principle 6).
- Classified each finding as BLOCK / ADVISORY / PASS with a manual rule reference and a concrete artifact.
- Issued a MERGE-READY verdict only when every BLOCK is resolved and the manual's "Done when" bar is met.
- Delivered the PR summary from the template, verdict first, BLOCKs listed first.
</success_criteria>
