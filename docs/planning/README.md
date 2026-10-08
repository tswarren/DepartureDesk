# Planning

This page is the canonical index of current planning status and authorization. An accepted or shipped plan remains the authority for the scope and contract it established. This index says where that work stands and links to it. It does not restate the contract.

A milestone-folder `README.md` is a reading list. It does not establish status or implementation authority.

**Document statuses:** Draft, Accepted, Shipped, Superseded, Historical, Complete. Complete is only for a parent whose required plans have shipped.

**Index states:** **Not authorized** means no accepted plan exists, so the work must not be implemented. **Deferred** means a decision already postponed the work. Neither word belongs in a plan header.

## Planning names

Plans created after this reorganization use descriptive filenames within their milestone folder. Existing historical milestone and slice identifiers remain valid for existing documents, but new plans do not extend those identifier trees. Dependencies and sequencing are stated explicitly in plan metadata rather than encoded in filenames.

Milestone numbers such as M5 and M6 stay. A new plan must not be named `M4D.1 Slice 3B` or `3A.4`.

## Where we stand

M1, M2, and M3 are complete. M4 offers through M4D.0 are shipped. Cruise Supplier Composition through the workspace consolidation is shipped, except Cruise document storage, which is Deferred. Cruise contracted-rate readiness is Shipped. Cruise activation review is Shipped 2026-10-06. Cruise form clarity is Shipped 2026-10-07. Cruise summary presentation Slices 1 and 2 are Shipped 2026-10-07. Slices 3 and 4 have no implementation authority until separately accepted. Hotel persistence, foundations, stay and inventory, supplier rates, the Supplier complexity rebaseline, and Hotel Agreement are shipped. Hotel Review and Activation is Shipped. Hotel Lifecycle is Shipped 2026-10-02. The ABC Motorcoach Transportation walkthrough is Accepted 2026-10-02 and its fixture is Approved. The [ABC Motorcoach supplier compatibility gate](m4-offers-and-pricing/abc-motorcoach-supplier-compatibility.md) records which charter facts fit shipped Supplier commands. [Transportation Supplier Composition](m4-offers-and-pricing/transportation-supplier-composition.md) is Shipped 2026-10-02 and authorizes that Transportation Agreement workspace only. The [Island Sightseeing supplier compatibility pass](m4-offers-and-pricing/island-sightseeing-supplier-compatibility.md) is recorded 2026-10-02. The [Island Sightseeing Activity walkthrough](m4-offers-and-pricing/island-sightseeing-activity-staff-walkthrough.md) is Accepted 2026-10-02. [Activity Supplier Composition](m4-offers-and-pricing/island-sightseeing-activity-supplier-composition.md) is Shipped 2026-10-02 and authorizes that Activity Agreement workflow only. The Port Promotions fixture is Approved 2026-10-02. M4E and M5 are Not authorized.

## Milestones

| Milestone | State | Authority |
| --- | --- | --- |
| M0 — Agency identity | Complete | [Roadmap](roadmap.md) |
| M1 — Directories | Complete | [M1](m1-separate-directories/m1-client-and-supplier-directories.md) |
| M2 — Departure core | Complete | [M2](m2-departure-core/m2-departure-core.md) |
| M3 — Supplier planning | Complete | [M3](m3-supplier-planning/m3-supplier-planning.md) |
| M4 — Offers and pricing | Accepted; later standing is this index | [M4](m4-offers-and-pricing/m4-offers-and-pricing.md) |
| M5 — Client Trips and fulfillment | Not authorized | [Roadmap](roadmap.md) sequences it after M4 |
| M6A — Client subledger | Not authorized | [Roadmap](roadmap.md) |
| M6B — Supplier subledger | Not authorized | [Roadmap](roadmap.md) |
| M7 — Changes and operations | Not authorized | [Roadmap](roadmap.md) |
| M8 — Reconciliation and pilot readiness | Not authorized | [Roadmap](roadmap.md) |

Roadmap **Planned** means the milestone comes later. It does not authorize code.

## M4 — Offers

| Capability | Status | Governing document |
| --- | --- | --- |
| Task-flow gate | Accepted | [M4.0](m4-offers-and-pricing/m40-task-flow-and-contract.md) |
| Service definitions | Shipped | [M4A](m4-offers-and-pricing/m4a-service-definitions-and-sources.md) |
| Unpublished Client pricing | Shipped | [M4B](m4-offers-and-pricing/m4b-client-pricing-and-anonymous-preview.md) |
| Packages, choices, and Client terms | Shipped | [M4C](m4-offers-and-pricing/m4c-packages-choices-and-client-terms.md) |
| Publication and live feasibility | Shipped | [M4D](m4-offers-and-pricing/m4d-publication-and-live-feasibility.md) |
| Narrow group departure builder | Shipped | [M4D.0](m4-offers-and-pricing/m4d0-narrow-group-departure-builder.md) |
| Builder interface remediation | Historical | [M4D.0R](m4-offers-and-pricing/m4d0r-builder-interface-remediation.md) |

## Supplier Composition

| Capability | Status | Governing document |
| --- | --- | --- |
| Composition workspace | Shipped | [Workspace foundation](m4-offers-and-pricing/m4d1-slice1-workspace-foundation.md), under the [M4D.1 parent](m4-offers-and-pricing/m4d1-departure-composition-workspace.md) |
| Non-Cruise adapter boundary | Accepted | [Slice 3R](m4-offers-and-pricing/m4d1-slice3r-non-cruise-adapter-boundary.md). Layer boundary and delivery order only. It authorizes no adapter code. |

### Cruise

| Capability | Status | Governing document |
| --- | --- | --- |
| Sailing and cabin inventory | Shipped | [Slice 2A.1](m4-offers-and-pricing/m4d1-slice2a1-cruise-sailing-and-cabin-inventory.md) |
| Supplier rates | Shipped | [Slice 2A.2](m4-offers-and-pricing/m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md), [rate matrix](m4-offers-and-pricing/m4d1-slice2a2r-cruise-supplier-rate-matrix.md), [matrix interaction](m4-offers-and-pricing/m4d1-slice2a2r2-cruise-rate-matrix-interaction.md), [rate-shape detector](m4-offers-and-pricing/m4d1-slice2a2r3-cruise-rate-shape-detector-remediation.md) |
| Deposits and deadlines | Shipped | [Slice 2B](m4-offers-and-pricing/m4d1-slice2b-cruise-deposits-deadlines-and-activation-safe-editing.md), [deposit semantics](m4-offers-and-pricing/m4d1-slice2br-cruise-deposit-semantics-amendment.md), [workspace remediation](m4-offers-and-pricing/m4d1-slice2bux-deposits-deadlines-workspace-remediation.md), [contributor replace](m4-offers-and-pricing/m4d1-slice2buxr-contributor-replace-and-closure.md) |
| Service connection | Shipped | [Slice 2C](m4-offers-and-pricing/m4d1-slice2c-cruise-service-connection.md) |
| Client terms and scenario review | Shipped | [Slice 2D](m4-offers-and-pricing/m4d1-slice2d-cruise-client-terms-and-scenario-review.md) |
| Ports and commercial benefits | Shipped | [Sailing ports and commercial benefits](m4-offers-and-pricing/m4d1-cruise-ports-and-commercial-benefits.md) |
| Cruise rework | Accepted | [Cruise rework](m4-offers-and-pricing/m4d1-cruise-rework.md). Slices 1–5 and 7 are implemented. |
| Cruise contracted-rate readiness | Shipped | [Cruise contracted-rate readiness](m4-offers-and-pricing/cruise-contracted-rate-readiness.md). Authorizes that activation review only. |
| Cruise activation review | Shipped 2026-10-06 | [Cruise activation review](m4-offers-and-pricing/cruise-activation-review.md). Authorizes confirming displayed inventory and contracted rates during Cruise activation. |
| Cruise form clarity | Shipped 2026-10-07 | [Cruise form clarity](m4-offers-and-pricing/cruise-form-clarity.md). Authorizes Cruise form presentation and the shared field styles named there. |
| Cruise summary presentation | Slices 1 and 2 Shipped 2026-10-07 | [Cruise summary presentation](m4-offers-and-pricing/cruise-summary-presentation.md). Slice 1 ships the category Supplier-rate read-only presentation and Agreement summaries. Slice 2 ships the operational overview, inventory, category-rate summary, governing terms, and activated shell action. Slices 3 and 4 have no implementation authority until separately accepted. |
| Cruise document storage | Deferred | — |
| Composition UX | Shipped | [Cruise Composition UX](m4-offers-and-pricing/m4d1-cruise-composition-ux.md) through [UX-7](m4-offers-and-pricing/m4d1-cruise-composition-ux7.md) |

### Hotel

| Capability | Status | Governing document |
| --- | --- | --- |
| Persistence compatibility | Shipped | [3A.0 result](m4-offers-and-pricing/m4d1-slice3a-hotel-supplier-composition.md#3a0-result) in the Hotel parent |
| Supplier foundations | Shipped | [Slice 3A.1](m4-offers-and-pricing/m4d1-slice3a1-hotel-supplier-term-persistence.md) |
| Stay and inventory | Shipped | [Slice 3A.2](m4-offers-and-pricing/m4d1-slice3a2-hotel-stay-and-nightly-inventory.md) |
| Supplier rates | Shipped | [Slice 3A.3](m4-offers-and-pricing/m4d1-slice3a3-hotel-supplier-rates.md) |
| Supplier complexity rebaseline | Shipped | [Supplier complexity rebaseline](m4-offers-and-pricing/supplier-complexity-rebaseline.md) |
| Hilton staff walkthrough | Accepted | [Walkthrough](m4-offers-and-pricing/m4d1-hilton-hotel-staff-walkthrough.md) and the Approved [Hilton fixture](fixtures/hilton-fort-lauderdale-marina-2027-canonical-scenario-draft.md) |
| Hotel Agreement | Shipped | [Hotel Agreement](m4-offers-and-pricing/hotel-agreement.md), then [workspace read mode](m4-offers-and-pricing/hotel-agreement-workspace-read-mode.md) and [term authoring](m4-offers-and-pricing/hotel-agreement-term-authoring.md) |
| Hotel Review and Activation | Shipped | [Hotel Review and Activation](m4-offers-and-pricing/hotel-review-and-activation.md) |
| Hotel Lifecycle | Shipped 2026-10-02 | [Hotel Lifecycle](m4-offers-and-pricing/hotel-lifecycle.md) |

### Other

| Capability | Status | Governing document |
| --- | --- | --- |
| ABC Motorcoach staff walkthrough | Accepted 2026-10-02 | [Walkthrough](m4-offers-and-pricing/abc-motorcoach-transportation-staff-walkthrough.md) and the Approved [ABC fixture](fixtures/abc-motorcoach-2027-canonical-transportation-scenario-draft.md) |
| ABC Motorcoach supplier compatibility | Recorded 2026-10-02 | [Compatibility gate](m4-offers-and-pricing/abc-motorcoach-supplier-compatibility.md) |
| Transportation Supplier Composition | Shipped 2026-10-02 | [Transportation Supplier Composition](m4-offers-and-pricing/transportation-supplier-composition.md). Authorizes that Transportation Agreement workspace only |
| Island Sightseeing supplier compatibility | Recorded 2026-10-02 | [Compatibility pass](m4-offers-and-pricing/island-sightseeing-supplier-compatibility.md). Persistence evidence. Authorizes no Activity code |
| Island Sightseeing Activity walkthrough | Accepted 2026-10-02 | [Walkthrough](m4-offers-and-pricing/island-sightseeing-activity-staff-walkthrough.md) and the Approved [Port Promotions fixture](fixtures/port-promotions-island-sightseeing-2027-canonical-scenario.md) |
| Island Sightseeing Activity Supplier Composition | Shipped 2026-10-02 | [Activity Supplier Composition](m4-offers-and-pricing/island-sightseeing-activity-supplier-composition.md). Authorizes that Activity Agreement workflow only |
| M4E — acceptance and hardening | Not authorized | — |

Unmerged branch `m4d1-slice3-hotel-transport-activity` and PR #156 are prototype evidence and are not an implementation source. Supplier Composition fixtures are indexed in [fixtures/README.md](fixtures/README.md).

## Product authority

- [MVP](departure-desk-mvp.md) — product scope.
- [Commercial decision register](commercial-domain-decision-register.md) — commercial and financial rules.
- [Roadmap](roadmap.md) — milestone sequence. It does not authorize a plan.

## Drafts

Unfinished exploration lives in [drafts](drafts/README.md). Those files are not implementation authority.
