# <EventName> (past tense, e.g. OrderPlaced)

> Adapted from the API manual's "Async and Event APIs". The manual is the source of truth.
> Work through one event here before writing it into the contract (AsyncAPI/schema registry).
> An event is a published contract — every current and future consumer depends on it.

## Purpose
<the single fact that happened, in the producer's domain language. An event is a past-tense
fact (OrderPlaced, InvoicePaid), never a command or a future intent. If you are requesting work
from a known worker, this is a command/queue message, not an event — say so and stop here.>

## Producer
- **Owning service / team:** <who emits this; the producer must not know who consumes it>
- **Topic / channel:** <name, following the repo convention>
- **Schema version:** <semver or registry version; how it travels in the envelope (see below)>

## Envelope (required fields on every event)
- **event ID:** <unique per event; consumers dedupe on it>
- **occurred timestamp:** <ISO-8601 UTC, when the fact happened — not when it was published>
- **producer name + schema version:** <so consumers route and validate>
- **correlation / causation ID:** <ties this event to the request/saga that caused it>

## Payload
- **Fields:** <the stable, minimal facts a consumer needs — domain language, not column names>
- **NEVER the database shape:** <do not serialize the internal entity/table row as the wire format;
  the payload is a contract decoupled from your store>
- **IDs:** <opaque strings; large ints / decimals / money as strings>
- **Field rules:** <ISO-8601 UTC timestamps; units in names; no secrets/internal hosts>

## Consumer idempotency
<the same event delivered twice MUST NOT double-apply. State the dedupe key (usually event ID)
and where the consumer records "already processed". Assume at-least-once delivery.>

## Ordering
<what ordering guarantee exists (per-key? none?) and how a consumer copes when it has none —
do not assume global ordering unless the transport guarantees it.>

## Retention & replay
- **Retention:** <how long events are kept>
- **Replay:** <can a consumer replay from a point; how; what a replay must be safe against
  (idempotency above is what makes replay safe)>

## Compatibility
<additive changes only without a version bump; renaming an event, removing or retyping an
envelope/payload field, or narrowing retention is a breaking change to existing consumers —
note migration. Keep the payload stable.>

## Consistency (if this event drives a state change)
<per-capability choice, not system-wide: a catalog can be eventually consistent (AP);
a money/stock debit should be strongly consistent (CP). State which and why.>

## Examples
<at least one worked envelope + payload as it appears on the wire.>

## Tests (handed to IMPLEMENT/REVIEW)
<schema validates; consumer is idempotent under duplicate delivery; replay is safe;
out-of-order handling; compatibility risk for existing consumers.>

## Agent-native parity
<which user-facing outcome this event supports, and confirmation an agent can observe/consume
the fact through a primitive — no orphan event with no read path.>
