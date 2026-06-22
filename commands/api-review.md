---
description: Adversarially gate an API change before merge
argument-hint: [PR or change to review]
---

Use the `api-review` skill to run the VALIDATE phase for the following change: $ARGUMENTS

If no target is given, review the current pending change/PR. Run the Pre-Merge Review Checklist adversarially — assume the change is broken until evidence proves otherwise — and dispatch the bundled reviewer agents (`api-contract-reviewer`, `api-security-reviewer`, `api-compatibility-reviewer`, and `api-async-reviewer` for events/webhooks/queues/sagas/LROs). Green CI is a claim, not proof.
