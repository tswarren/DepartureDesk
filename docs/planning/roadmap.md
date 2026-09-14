# DepartureDesk roadmap

**Status:** Accepted sequencing guide

**Purpose:** Order implementation around demonstrable business capabilities without treating unbuilt product requirements as shipped behavior.

Each milestone requires an accepted slice plan before domain code. The Celebrity Beyond cruise and Vineyard Tour are recurring acceptance scenarios used to test generality.

| Milestone | Status | Outcome |
| --- | --- | --- |
| M0 — Agency identity baseline | Complete | Agency-scoped authentication, administration, Office context, audit, tenant isolation, and hardening. |
| M1 — Separate directories | Accepted plan; M1A shipped; M1B implemented on branch | Maintain Client and Supplier identities without restoring Party or prematurely creating Household/Traveler records. M1A shipped individual Clients. M1B implements Client Organizations and expanded Client search on this branch; treat as shipped when merged. Suppliers remain unbuilt. |
| M2 — Departure core | Planned | Create and govern reusable Travel Programs and dated Departures. |
| M3 — Supplier planning | Planned | Represent arrangements, items, occurrences, resources, commitments, capacity, deadlines, and exposure. |
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

1. The M1 directory plan is accepted. It does not authorize slice code by itself.
2. The [M1A individual-Client slice plan](m1a-individual-client.md) is implemented and merged to main.
3. The [M1B Client Organization slice plan](m1b-client-organizations.md) is implemented on this branch. Client Organization, organization-backed Client, organization contact points, organization-contact history, and expanded Client search ship when the branch merges. Suppliers are not.
4. Add Supplier, Supplier Location, and Supplier Contact in reviewable follow-up slices. Do not introduce Household or standalone Traveler persistence.
5. Validate M1 against the explicit fictional directory-fixture set mapped to both reference scenario shapes before beginning M2.

The [MVP specification](departure-desk-mvp.md) defines scope. The [commercial decision register](commercial-domain-decision-register.md) defines cross-cutting commercial rules. This roadmap controls sequence, not record-level implementation.
