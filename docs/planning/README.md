# Planning

This page is the slice-level status index. A slice's own header remains the authority for that slice.

**Status words:** Draft, Accepted, Shipped, Superseded, Historical, Complete. Complete is only for a parent whose required slices have shipped.

## Where we stand

M1, M2, and M3 are complete. M4 is accepted and shipped through M4D.0. The Cruise vertical of M4D.1 is shipped through Slice 2D. [Slice 3R](m4d1-slice3r-non-cruise-adapter-boundary.md) is accepted for the layer boundary and delivery order only.

## Now

The next document is the Hotel walkthrough. It has not been started. Accepting that walkthrough still does not authorize code. Hotel implementation remains prohibited until the walkthrough and a separate Slice 3A implementation plan are accepted. Unmerged branch `m4d1-slice3-hotel-transport-activity` and PR #156 are prototype evidence and are not an implementation source.

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
- **Slice 3R — Accepted.** [Non-Cruise adapter boundary](m4d1-slice3r-non-cruise-adapter-boundary.md). Authorizes the Hotel walkthrough only.

## Product authority

- [MVP](departure-desk-mvp.md) — product scope.
- [Commercial decision register](commercial-domain-decision-register.md) — commercial and financial rules.
- [Roadmap](roadmap.md) — milestone sequence and gates.

## Drafts

Unfinished exploration lives in [drafts](drafts/README.md). Those files are not implementation authority.
