# ADR: <decision>

> Adapted from the API manual's "Templates → ADR". The manual is the source of truth.
> Write one per consequential design fork (style, boundary, status codes, pagination, idempotency,
> error shape, auth model). Skip routine choices covered by the Defaults Table — document only overrides.

- **Status:** <proposed | accepted | superseded by ADR-NNN>
- **Date:** <YYYY-MM-DD>

## Context
<the forces: consumer, constraints, compatibility promise, security/tenancy, expected volume/latency,
existing repo standard. What makes this a real fork rather than a default?>

## Decision
<the choice, stated plainly. If it overrides a manual default, name the default and why the override.>

## Alternatives considered
- <option> — <why not>
- <option> — <why not>

## Consequences
<what becomes easy, what becomes hard, what coupling is created (name it: domain / temporal /
pass-through / common / content), what future change this forecloses or enables>

## Verification
<how this decision is proven correct — the focused tests or runtime observation that would catch a regression>

## Rollback or migration
<if this proves wrong: is it reversible? compatible rollout? deprecation path? blast radius?>
