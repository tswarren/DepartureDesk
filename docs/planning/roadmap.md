# DepartureDesk roadmap

**Status:** Accepted sequencing guide

**Purpose:** Order implementation around demonstrable business capabilities without treating unbuilt product requirements as shipped behavior.

Each milestone requires an accepted slice plan before domain code. The Celebrity Beyond cruise and Vineyard Tour are recurring acceptance scenarios used to test generality.

| Milestone | Status | Outcome |
| --- | --- | --- |
| M0 — Agency identity baseline | Complete | Agency-scoped authentication, administration, Office context, audit, tenant isolation, and hardening. |
| M1 — Separate directories | Complete | Maintain Client and Supplier identities without restoring Party or prematurely creating Household/Traveler records. M1A–M1E are shipped: individual and organization Clients, Supplier core, Locations and Contacts, and directory proof/hardening. |
| M2 — Departure core | Complete | Create and govern dated Departures as the operational root. Travel Program is deferred. M2A–M2C are shipped. |
| M3 — Supplier planning | Planned | Represent arrangements, items, occurrences, resources, commitments, capacity, deadlines, and exposure. The [parent](m3-supplier-planning.md) is accepted. [M3A](m3a-draft-arrangement-structure.md) is shipped. Later M3 slices remain unimplemented until accepted. |
| M4 — Offers and pricing | Planned | Describe Packages and standalone services the Agency intends to sell. |
| M5 — Client Trips and fulfillment | Planned | Confirm a Client Trip, contextual Traveler Assignments and contacts, services, Holds, Allocations, Assignments, and Supplier fulfillment. |
| M6A — Client subledger | Planned | Introduce any required Client billing/credit/statement settings and explain Charges, Receipts, Applications, Credits, refunds, reversals, and responsibility. |
| M6B — Supplier subledger | Planned | Explain Supplier Obligations, invoices, Payments, Applications, deposits, Credits, and commission. |
| M7 — Changes and operations | Planned | Preserve amendments, substitutions, cancellations, documents, Communications, destination status, deadlines, and readiness. |
| M8 — Reconciliation and pilot readiness | Planned | Reconcile, close, report, export, resolve the directory-merge production policy, support, secure, and operate a pilot deployment. |

## Release checkpoints

- **Planning alpha after M3:** both scenarios can be represented from the Supplier side, including their different capacity and cost patterns.
- **Selling alpha after M4:** Packages, standalone services, required choices, occupancy pricing, and supply feasibility can be explained.
- **Booking beta after M5:** both scenarios work end to end operationally without financial posting.
- **Commercial beta after M7:** client and Supplier money, amendments, and cancellations preserve complete history.
- **Pilot-ready after M8:** reconciliation, closeout, security, support, and production operations are proven.

## Sequencing rules

1. Supplier planning precedes Packages and Client offers so sellable promises are grounded in supply, capacity, cost, and contractual terms.
2. Package is an optional offer container, not the center of the model.
3. Financial persistence starts only after posting, reversal, correction, idempotency, and concurrency contracts are accepted.
4. Duplicate warnings may arrive before executable merge. Record merging remains deferred until dependent-record participation is stable.
5. Human-readable references are introduced at the first consequential transition for each record type under ADR 0004 and the commercial register.
6. Platform support access and MFA stay outside early domain milestones but must be resolved before production use requires them.
7. Reference scenarios validate composition; they do not authorize cruise-, hotel-, or tour-specific subclasses.

## Immediate work

1. M1 is complete. [M1A](m1a-individual-client.md) through [M1E](m1e-directory-acceptance-and-hardening.md) are shipped.
2. M2 is complete. [M2A](m2a-departure-core.md) through [M2C](m2c-acceptance-and-hardening.md) are shipped.
3. [M3A](m3a-draft-arrangement-structure.md) is shipped. The [M3 parent](m3-supplier-planning.md) remains accepted and is not implementation authority for later slices. [ADR 0008](../adr/0008-supplier-arrangement-version-topology.md) and [ADR 0009](../adr/0009-supplier-contracting-and-service-provider-roles.md) remain accepted architecture. Do not implement Travel Program, Arrangement activation, capacity, costs, Reservations, commitments, Deadlines, exposure, or later M3 slices until an accepted slice names that work.

The [MVP specification](departure-desk-mvp.md) defines scope. The [commercial decision register](commercial-domain-decision-register.md) defines cross-cutting commercial rules. This roadmap controls sequence, not record-level implementation.
