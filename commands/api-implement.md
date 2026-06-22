---
description: Implement an approved API design into resilient server code
argument-hint: [what to implement]
---

Use the `api-implement` skill to run the IMPLEMENT phase for the following request: $ARGUMENTS

If no request is given, ask the user which approved design to build. Follow the skill's router into the manual — layered structure, ordered middleware, idempotent mutations, retry/failure handling, optimistic concurrency, and a stable error contract. If any design decision is unsettled, route back to `api-design`.
