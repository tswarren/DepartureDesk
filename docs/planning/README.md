# Planning

This page is the canonical index of current planning status and authorization. An accepted or shipped plan remains the authority for the scope and contract it established. This index says where that work stands and links to it. It does not restate the contract.

A milestone-folder `README.md` is a reading list. It does not establish status or implementation authority.

**Document statuses:** Draft, Accepted, Shipped, Superseded, Historical, Complete. Complete is only for a parent whose required plans have shipped.

**Index states:** **Not authorized** means no accepted plan exists, so the work must not be implemented. **Deferred** means a decision already postponed the work. Neither word belongs in a plan header.

## Planning names

Plans created after this reorganization use descriptive filenames within their milestone folder. Existing historical milestone and slice identifiers remain valid for existing documents, but new plans do not extend those identifier trees. Dependencies and sequencing are stated explicitly in plan metadata rather than encoded in filenames.

Work after M4 is organized in slices named by the [first-slice charter](first-slice/first-slice-charter.md) (Slice 1, Slice 1b, Slice 2, and so on), not milestones. A new plan must not be named `M5`, `M4D.1 Slice 3B` or `3A.4`.

## Where we stand

The [first-slice charter](first-slice/first-slice-charter.md) is Accepted 2026-10-31 (D-64), amended 2026-11-01 (D-66), and is the only active work. Phase 0 (Decide) closed 2026-11-03: every blocking decision and the specification review items R1–R11 are logged (D-61 to D-87), and the [Slice 1 data model](first-slice/slice-1-data-model.md) and [screen inventory](first-slice/slice-1-screens.md) were reviewed against D1–D17. Phase 1 (Prepare) closed 2026-11-04, and Slice 1 is active. R12–R14 remain in the [pending entries](../spec/pending-decision-log-entries.md#specification-review) for later slices.

Agency identity, M1 (directories) and M2 (Departures) are kept and built on. The shipped M3 and M4 layers, including Cruise, Hotel, Transportation and Activity Supplier Composition, were deleted in charter Phase 1 on 2026-11-04 ([inventory](first-slice/phase-1-m3-m4-deletion-inventory.md)). Tag `pre-m3-m4-deletion` holds them; Slice 1 step 3 restores only the capacity replay and projection code the spike chose to adapt. M4E and M5–M8 are Superseded by the charter and must not be implemented. Cruise document storage and the M4D.1 Cruise summary presentation Slice 4 are not authorized.

## First slice

| Phase | State | Checkpoint |
| --- | --- | --- |
| 0. Decide | Closed 2026-11-03; see the [Phase 0 decision brief](first-slice/phase-0-decision-brief.md) | Data-model decisions logged; data model and screens reviewed |
| 1. Prepare | Closed 2026-11-04: spike done 2026-11-03 (adapt; ADR 0018 amended); M3 and M4 deleted (#243); injectable clock, pending tests D1 to D17 and the Alpha seed script added (#244); CI passes | Spike decides adapt or replace for capacity; M3 and M4 layers deleted; remaining tests pass |
| 2. Slice 1 | Active from 2026-11-04; step 1 (foundation changes) merged; step 2 (Departure statuses and Ready to sell) merged; step 3a (arrangements, inventory and rate table, D1) merged; step 3b (deadlines and tasks, D12) merged; step 4 (supplier cost, schedule lines and amounts due, D2) merged; step 5 (package, prices and client terms) merged; step 6 (travelers, Client Trips and bookings) in three pull requests (D-94): 6a (clients, travelers and Client Trips) merged; 6b (bookings and holds, D6 and D16) merged; 6c (acceptance and confirmation, D4 and D5) merged, so step 6 is done; the [staff walkthrough after step 6](first-slice/slice-1-step-6-staff-walkthrough.md) passed 2026-11-08, with its findings fixed in #262 to #266; step 7 (supplier reservations, D8) merged; step 8 is [planned](first-slice/slice-1-step-8-plan.md) as two pull requests (D-96): 8a (client money, D9) merged; 8b (supplier money, D10) merged, so step 8 is done; the [UX consolidation pass](first-slice/ux-consolidation-audit.md) (D-98) merged 2026-11-10; step 9 is [planned](first-slice/slice-1-step-9-plan.md) as two pull requests (D-99): 9a (the staff side) merged 2026-11-10; 9b (the reseller path, D15) merged 2026-11-10, so step 9 is done; step 10 (confirmation, invoice and receipt PDFs, D13) is [planned](first-slice/slice-1-step-10-plan.md), with D-100 logged, and in review | Staff walkthrough after step 6; final walkthrough by a staff user and a reseller user who did not build it |
| 3. Slice 1b | Not authorized | All demonstration cases pass |

Record a phase change here, with its date. The charter stays the authority for scope.

## Milestones

| Milestone | State | Authority |
| --- | --- | --- |
| M0 — Agency identity | Complete | [Roadmap](roadmap.md) |
| M1 — Directories | Complete | [M1](m1-separate-directories/m1-client-and-supplier-directories.md) |
| M2 — Departure core | Complete | [M2](m2-departure-core/m2-departure-core.md) |
| M3 — Supplier planning | Code deleted in charter Phase 1 (D-66); tag `pre-m3-m4-deletion` | [M3](m3-supplier-planning/m3-supplier-planning.md) |
| M4 — Offers and pricing | Code deleted in charter Phase 1 (D-66); tag `pre-m3-m4-deletion` | [M4](m4-offers-and-pricing/m4-offers-and-pricing.md) |
| M5 — Client Trips and fulfillment | Superseded | [First-slice charter](first-slice/first-slice-charter.md) |
| M6A — Client subledger | Superseded | [First-slice charter](first-slice/first-slice-charter.md) |
| M6B — Supplier subledger | Superseded | [First-slice charter](first-slice/first-slice-charter.md) |
| M7 — Changes and operations | Superseded | [First-slice charter](first-slice/first-slice-charter.md) |
| M8 — Reconciliation and pilot readiness | Superseded | [First-slice charter](first-slice/first-slice-charter.md) |

The milestone and capability tables below record shipped history. "Authorizes" in them describes what each plan allowed at the time; none of it authorizes new work.

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
| Cruise summary presentation | Slices 1 and 2 Shipped 2026-10-07. Slice 3 Shipped 2026-10-08 | [Cruise summary presentation](m4-offers-and-pricing/cruise-summary-presentation.md). Slice 1 ships the category Supplier-rate read-only presentation and Agreement summaries. Slice 2 ships the operational overview, inventory, category-rate summary, governing terms, and activated shell action. Slice 3 ships the activation review, operational schedules, and the five named icons. Slice 4 has no implementation authority until separately accepted. |
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
| M4E — acceptance and hardening | Superseded | [First-slice charter](first-slice/first-slice-charter.md) |

Unmerged branch `m4d1-slice3-hotel-transport-activity` and PR #156 are prototype evidence and are not an implementation source. Supplier Composition fixtures are indexed in [fixtures/README.md](fixtures/README.md).

## Product authority

- [Product Specification](../spec/README.md): every product rule, and the decision log. The master copy is a Google Doc.
- [First-slice charter](first-slice/first-slice-charter.md): what is in scope now.
- [MVP](departure-desk-mvp.md), [Commercial decision register](commercial-domain-decision-register.md) and [Roadmap](roadmap.md): Superseded 2026-11-01, kept for history.

## Drafts

Unfinished exploration lives in [drafts](drafts/README.md). Those files are not implementation authority.
