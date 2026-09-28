# Planning

This page is the slice-level status index. A slice's own header remains the authority for that slice.

**Status words:** Draft, Accepted, Shipped, Superseded, Historical, Complete. Complete is only for a parent whose required slices have shipped.

## Where we stand

M1, M2, and M3 are complete. M4 is accepted and shipped through M4D.0. The Cruise vertical of M4D.1 is shipped through Slice 2D. [Sailing ports and commercial benefits](m4d1-cruise-ports-and-commercial-benefits.md) shipped in PR #162. [Slice 3R](m4d1-slice3r-non-cruise-adapter-boundary.md) is accepted for the layer boundary and delivery order only.

## Now

[Sailing ports and commercial benefits](m4d1-cruise-ports-and-commercial-benefits.md) shipped in PR #162. The [Cruise rework](m4d1-cruise-rework.md) is Accepted 2026-09-27. Its contracted-rate, agreement-confirmation, deposit and deadline, later-capacity, and Offer Design slices are implemented. Slice 6 document storage stays deferred. The [Cruise Composition UX](m4d1-cruise-composition-ux.md) plan is Accepted 2026-09-28. UX-1, the read-only overview, and UX-2, establish supply, are accepted. UX-3, establish economics, is the authorized Cruise presentation slice. UX-4 through UX-7 are specified and not authorized. The [Hotel Staff walkthrough](m4d1-hilton-hotel-staff-walkthrough.md) is Accepted 2026-09-27, and the [Hilton fixture](fixtures/hilton-fort-lauderdale-marina-2027-canonical-scenario-draft.md) is Approved. The next unauthorized non-Cruise boundary is a Slice 3A implementation plan. Hotel implementation remains prohibited until that plan is accepted. Supplier Composition fixtures are indexed in [fixtures/README.md](fixtures/README.md). Unmerged branch `m4d1-slice3-hotel-transport-activity` and PR #156 are prototype evidence and are not an implementation source.

## Milestones

| Milestone | State | Authority |
| --- | --- | --- |
| M0 — Agency identity | Complete | [Roadmap](roadmap.md) |
| M1 — Directories | Complete | [M1](m1-client-and-supplier-directories.md) |
| M2 — Departure core | Complete | [M2](m2-departure-core.md) |
| M3 — Supplier planning | Complete | [M3](m3-supplier-planning.md) |
| M4 — Offers and pricing | Accepted; shipped through M4D.0; M4D.1 in progress | [M4](m4-offers-and-pricing.md) |
| M5 — Client Trips and fulfillment | Planned | [Roadmap](roadmap.md) |
| M6A — Client subledger | Planned | [Roadmap](roadmap.md) |
| M6B — Supplier subledger | Planned | [Roadmap](roadmap.md) |
| M7 — Changes and operations | Planned | [Roadmap](roadmap.md) |
| M8 — Reconciliation and pilot readiness | Planned | [Roadmap](roadmap.md) |

## M4D.1

Parent: [M4D.1 — Departure Composition Workspace](m4d1-departure-composition-workspace.md) (Accepted).

- **Slice 1 — Shipped.** [Workspace foundation](m4d1-slice1-workspace-foundation.md).
- **Slice 2A — Shipped.** [Sailing and cabin inventory](m4d1-slice2a1-cruise-sailing-and-cabin-inventory.md), [Supplier rates and occupancy totals](m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md), [rate matrix](m4d1-slice2a2r-cruise-supplier-rate-matrix.md), [matrix interaction](m4d1-slice2a2r2-cruise-rate-matrix-interaction.md), and [rate-shape detector](m4d1-slice2a2r3-cruise-rate-shape-detector-remediation.md).
- **Slice 2B — Shipped.** [Deposits, deadlines, and activation-safe editing](m4d1-slice2b-cruise-deposits-deadlines-and-activation-safe-editing.md), [deposit semantics](m4d1-slice2br-cruise-deposit-semantics-amendment.md), [workspace remediation](m4d1-slice2bux-deposits-deadlines-workspace-remediation.md), and [contributor replace](m4d1-slice2buxr-contributor-replace-and-closure.md).
- **Slice 2C — Shipped.** [Cruise service connection](m4d1-slice2c-cruise-service-connection.md).
- **Slice 2D — Shipped.** [Cruise Client terms and scenario review](m4d1-slice2d-cruise-client-terms-and-scenario-review.md).
- **Ports and commercial benefits — Shipped.** [Sailing ports and commercial benefits](m4d1-cruise-ports-and-commercial-benefits.md). Optional ports, itinerary notes, and versioned tour-conductor and GAP terms only.
- **Slice 3R — Accepted.** [Non-Cruise adapter boundary](m4d1-slice3r-non-cruise-adapter-boundary.md). Layer boundary and delivery order only.
- **Cruise rework — Accepted 2026-09-27, slices 1–5 and 7 implemented.** [Supplier agreement, contracted rates, deposits, and amendments](m4d1-cruise-rework.md). Slice 6 document storage stays deferred. Not Hotel code.
- **Cruise Composition UX — Accepted 2026-09-28.** [Overview and later presentation slices](m4d1-cruise-composition-ux.md). UX-1 and UX-2 are accepted. UX-3, establish economics, is the authorized slice. UX-4 through UX-7 are not authorized. Not Hotel code.
- **Hotel Staff walkthrough — Accepted 2026-09-27.** [Hilton journey](m4d1-hilton-hotel-staff-walkthrough.md), with the Approved [Hilton fixture](fixtures/hilton-fort-lauderdale-marina-2027-canonical-scenario-draft.md). Authorizes a Slice 3A plan, not Hotel code.

## Product authority

- [MVP](departure-desk-mvp.md) — product scope.
- [Commercial decision register](commercial-domain-decision-register.md) — commercial and financial rules.
- [Roadmap](roadmap.md) — milestone sequence and gates.

## Drafts

Unfinished exploration lives in [drafts](drafts/README.md). Those files are not implementation authority.
