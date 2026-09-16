# ADR 0007: Departure as operational root; Travel Program deferred

- Status: Accepted
- Date: 2026-09-16
- Decision owners: DepartureDesk maintainers

## Context

The MVP vocabulary describes Travel Program as an optional reusable or recurring concept and Departure as a dated occurrence. Parent [M2 — Departure core](../planning/m2-departure-core.md) must establish which record is the operational ownership root before later planning, offers, Client Trips, fulfillment, capacity, financial, cancellation, reporting, and closeout records attach.

Neither accepted reference scenario currently demonstrates a durable shared record above Departure:

- Celebrity Beyond currently represents one dated sailing.
- Vineyard Tour currently represents one dated tour.
- Neither scenario requires shared state across multiple Departures.
- No currently accepted behavior depends on a Travel Program.

“Travel Program” also remains semantically ambiguous. It could mean a recurring client or affinity-group series, a reusable itinerary, a product or offer template, a collection of scheduled departures, a reporting category, or a continuing initiative such as an annual reunion. Those concepts do not have the same ownership, inheritance, lifecycle, or change semantics.

Implementing a generic Travel Program now would risk creating a decorative parent or, worse, a live inheritance hierarchy through which later Supplier arrangements, Packages, terms, dates, or prices silently affect several Departures.

## Decision

`Departure` is the dated operational root. Travel Program is deferred.

1. `Departure` is independently usable and is the only M2 aggregate.
2. No M2 record requires a parent above Departure.
3. M3–M8 operational and commercial records belong directly to Departure.
4. No live inheritance from a reusable concept is authorized.
5. A future accepted slice may introduce a nullable relationship from Departure to a clearly defined series, template, or program record.
6. That future slice must demonstrate at least two real Departures that need the shared identity and must define exactly what is shared, copied, inherited, versioned, and independently mutable.
7. Deferral creates no meaningful migration obstacle because an optional parent association can be added later without changing Departure identity.

This ADR does not authorize Travel Program tables, routes, models, fixtures, or foreign keys. Entire-Departure cancellation remains orthogonal to operational lifecycle (`draft`, `active`, `departed`) and is not introduced here.

## Consequences

### Positive

- Later commercial records have a single ownership root.
- M2 can ship dated Departures without inventing a decorative parent.
- A future series or template record can be added without rewriting Departure identity.

### Costs

- Agencies that already think in “programs” must use one Departure per dated occurrence until a later slice defines the shared record.
- MVP and roadmap language must not treat Travel Program as an M2 deliverable.

## Alternatives rejected

### Implement Travel Program in M2 as an optional parent

Rejected. The accepted scenarios do not demonstrate shared state, and the term is still ambiguous.

### Make Office or AgencyUser the operational root

Rejected. Those records are attribution and reporting context. They do not own later commercial facts.
