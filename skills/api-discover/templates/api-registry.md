# API Registry / Catalog: <surface or org name>

> Adapted from the API manual's "Release and Evolution → Maintain a registry/catalog of every deployed API and version". The manual is the source of truth.
> This is the artifact the EVOLVE phase reads before any change. **Maintain it**: discovery builds/updates it; retirement (de-registration + route removal) is recorded here when EVOLVE acts.
> Discovery is read-mostly — building this catalog must not mutate the API surface.

## Scope of this scan
- **Environments / deployments inventoried:** <prod | prod + staging | …> (record what counts as "the surface")
- **Sources reconciled:** <spec/OpenAPI | code routes | gateway/mesh/ingress | access logs/metrics> (an endpoint is real if it appears in any source that serves traffic, not only the spec)
- **Date / commit scanned:** <date — repo commit or deploy ref>
- **Lifecycle states used:** planned → preview/beta → live → deprecated → retired

## Endpoint catalog
One row per endpoint **per version**. `Spec?` = appears in the documented contract. `Agent CRUD` = does an agent-reachable path exist (see addendum); use C/R/U/D letters present, or `none`. `Flag` = ✋ if attack surface / needs attention (see flagged section), else blank.

| Method + path (or service/method) | Version | Lifecycle | Owner | Known consumers | Spec? | Agent CRUD | Flag |
|------------------------------------|---------|-----------|-------|-----------------|-------|------------|------|
| `<GET /v1/...>` | v1 | live | `<team/service>` | `<callers>` | yes | R | |
| `<POST /v1/...>` | v1 | live | `<team/service>` | `<callers>` | yes | C | |
| `<GET /beta/...>` | beta | preview/beta | `UNKNOWN` | `<unknown>` | no | none | ✋ |
| `<DELETE /v0/...>` | v0 | deprecated | `<team>` | `<legacy caller>` | no | D | ✋ |

## Flagged — attack surface & gaps (security spine of discovery)
Per the manual: untracked old/`beta` endpoints are an attack surface (they may still expose fields newer versions removed). List every flagged row and why; recommend the EVOLVE action. Discovery flags — it does not retire.

| Endpoint + version | Why flagged | Recommended EVOLVE action |
|--------------------|-------------|---------------------------|
| `<GET /beta/...>` | Undocumented; serves live traffic; no owner | Attribute owner, then de-register + remove route, or promote to versioned + spec'd |
| `<DELETE /v0/...>` | Stale version still live; may expose removed fields | Track usage, publish migration notes, then de-register + remove route |
| `<endpoint>` | No agent-reachable path for a user-facing action/entity | Add agent primitive (DESIGN) or document the gap |

## Reconciliation / drift notes
Record mismatches across sources so EVOLVE and DESIGN can close them.
- **In code/deploy/traffic but NOT in spec (undocumented):** <list — each is flagged above>
- **In spec but NOT wired/deployed (ghost contract):** <list>
- **Owner = UNKNOWN (attribution gap):** <list — never leave the owner column blank>
- **Boundary smells observed (per Boundary Rules / Coupling Diagnosis):** <shared schema, pass-through hops, content coupling, internal IDs/table shapes exposed>

## Assumptions made (Clarify-vs-Assume)
- <assumption + the manual default it follows, so a reviewer can correct it cheaply — e.g. "scoped to prod only; staging routes not inventoried">

## Open questions (asked only because breaking/irreversible/unknowable from repo)
- <question — which environments count as the surface, where deployed gateway config + traffic logs live, whether an unattributed endpoint is orphaned or owned outside this repo>
