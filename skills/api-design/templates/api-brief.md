# API Brief: <name>

> Adapted from the API manual's "Templates → API Brief". The manual is the source of truth.
> Fill this first. It anchors the whole surface and records the Clarify-vs-Assume decisions.

## Context
- **Consumer:** <browser | mobile | partner | internal service | batch job | operator | agent>
- **Outcome (job to be done):** <what the consumer must accomplish>
- **Resource or capability exposed:** <the thing with identity, lifecycle, permissions>
- **Owner:** <team/service that owns this data and behavior>

## Shape
- **API style:** <REST/HTTP+JSON (default) | gRPC | GraphQL (BFF/reads) | events | operation resource> — justify any non-default or any second style (per Style Decision Matrix)
- **Boundary decision:** <modular monolith | service boundary | events | facade> — name the coupling created (domain / temporal / pass-through / common / content)

## Security (designed now, per Security Manual)
- **Authn:** <scheme; e.g. OAuth2/OIDC + PKCE, mTLS, client credentials, signed webhooks>
- **Authz:** <per-endpoint and per-resource model; where ownership/tenancy is enforced — must be the data-owning service>
- **Sensitive data fields:** <list; how protected; never leaked in responses>
- **Abuse controls:** <rate limit / load shed; fail-open vs fail-closed for edge components>

## Contract promises
- **Compatibility promise:** <existing clients? versioning? what is breaking vs compatible>
- **Expected volume / latency:** <read & write volume; acceptable latency>
- **Observability needs:** <request-ID propagation; what must be visible in prod>
- **Rollout risk:** <new surface vs change to live surface; rollback story>

## Endpoints
- `<METHOD> <path>` — <purpose>
- `<METHOD> <path>` — <purpose>

## Capability map (agent-native parity — required)
Every user-facing action and every entity must have an agent path with full CRUD. No orphan UI actions.

| User action / entity | Agent achieves it via | C | R | U | D |
|----------------------|-----------------------|---|---|---|---|
| <entity> | <endpoint(s) / tool> | ☐ | ☐ | ☐ | ☐ |
| <user action> | <endpoint(s) / tool> | — | — | — | — |

## Assumptions made (Clarify-vs-Assume)
- <assumption + the manual default it follows, so a reviewer can correct it cheaply>

## Open questions (asked only because breaking/irreversible)
- <question — auth/tenancy, data ownership, compatibility promise, or destructive blast radius>
