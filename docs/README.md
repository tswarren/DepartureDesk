# DepartureDesk documentation

This directory separates shipped architecture, accepted product decisions, implementation plans, operations, design guidance, scenarios, and historical material.

## Authority order

When documents conflict, use this order:

1. Accepted architecture decision records in [`adr/`](adr/README.md) for the decision they govern.
2. The accepted commercial contract in [`planning/commercial-domain-decision-register.md`](planning/commercial-domain-decision-register.md).
3. The current MVP scope in [`planning/departure-desk-mvp.md`](planning/departure-desk-mvp.md).
4. An accepted slice plan for the work it explicitly places in scope. An accepted milestone contract sets the rules; it does not authorize its slices.
5. Current operational and interface documentation.

`AGENTS.md` defines the shipped boundary and contributor rules. A broad product requirement or accepted milestone contract does not authorize implementation until an accepted slice plan places that work in scope.

## Document status

| Status | Meaning |
| --- | --- |
| Accepted | Governing decision or plan. Changes require an explicit amendment or superseding document. |
| Implemented | Accepted behavior verified in the current application. |
| Draft | Open for review and not implementation authority. |
| Superseded | Retained decision history; a named later authority controls. |
| Archived | Historical and non-normative. Do not implement from it. |

Every normative or planning document should state its status near the top. Historical documents under [`archive/`](archive/README.md) are archived regardless of an older status written inside them.

## Current map

| Area | Purpose |
| --- | --- |
| [`architecture/current-state.md`](architecture/current-state.md) | What exists in the application now. |
| [`adr/`](adr/README.md) | Durable architectural decisions, including superseded history. |
| [`planning/departure-desk-mvp.md`](planning/departure-desk-mvp.md) | MVP product scope and acceptance requirements. |
| [`planning/commercial-domain-decision-register.md`](planning/commercial-domain-decision-register.md) | Detailed commercial and financial rules. |
| [`planning/roadmap.md`](planning/roadmap.md) | Milestone order and entry/exit gates. |
| [`planning/m1-client-and-supplier-directories.md`](planning/m1-client-and-supplier-directories.md) | Complete M1 directory contract. M1A–M1E are shipped. |
| [`planning/m1a-individual-client.md`](planning/m1a-individual-client.md) | Implemented individual-Client slice, merged to main. |
| [`planning/m1b-client-organizations.md`](planning/m1b-client-organizations.md) | Shipped Client Organization slice. |
| [`planning/m1c-supplier-core.md`](planning/m1c-supplier-core.md) | Shipped Supplier-core slice. |
| [`planning/m1d-supplier-locations-and-contacts.md`](planning/m1d-supplier-locations-and-contacts.md) | Shipped Supplier Locations and Contacts slice. |
| [`planning/m1e-directory-acceptance-and-hardening.md`](planning/m1e-directory-acceptance-and-hardening.md) | Shipped directory proof and hardening slice. |
| [`planning/m2-departure-core.md`](planning/m2-departure-core.md) | Complete M2 parent. M2A–M2C are shipped. Not implementation authority for M3. |
| [`planning/m2a-departure-core.md`](planning/m2a-departure-core.md) | Shipped M2A slice. |
| [`planning/m2b-departed-lifecycle.md`](planning/m2b-departed-lifecycle.md) | Shipped M2B slice. |
| [`planning/m2c-acceptance-and-hardening.md`](planning/m2c-acceptance-and-hardening.md) | Shipped M2C proof and hardening slice. |
| [`planning/m3-supplier-planning.md`](planning/m3-supplier-planning.md) | Accepted M3 parent. M3A–M3F shipped; **M3 complete.** |
| [`planning/m3a-draft-arrangement-structure.md`](planning/m3a-draft-arrangement-structure.md) | Shipped M3A draft Arrangement structure slice. |
| [`planning/m3b-supplier-capacity.md`](planning/m3b-supplier-capacity.md) | Shipped M3B Supplier capacity slice. Draft configuration and the capacity engine are shipped; Arrangement activation and Staff event UI ship with M3D. |
| [`planning/m3c-cost-terms-and-forecasts.md`](planning/m3c-cost-terms-and-forecasts.md) | Shipped M3C Supplier cost terms and forecasts slice. Draft cost sources, definitions, components, assumptions, and derived forecasts are shipped; Arrangement activation and effective contracted terms ship with M3D. |
| [`planning/m3d0-planning-workspace-compression.md`](planning/m3d0-planning-workspace-compression.md) | Shipped M3D.0 Supplier-planning workspace compression over M3A–M3C workflows. No Arrangement activation or other M3D domain records. |
| [`planning/m3d-activation-reservations-confirmations.md`](planning/m3d-activation-reservations-confirmations.md) | Shipped M3D Arrangement activation, Reservations, and confirmations slice. |
| [`planning/m3d7-activated-definition-immutability.md`](planning/m3d7-activated-definition-immutability.md) | Shipped M3D.7 post-ship remediation: freeze exact-version definition graphs after leaving draft (Rails and PostgreSQL). |
| [`planning/m3d8-activation-reservation-product-quality.md`](planning/m3d8-activation-reservation-product-quality.md) | Shipped M3D.8 post-ship remediation: canonical forms, error recovery, progressive disclosure, exclusive composers, bounded Reservation lists/histories, and table overflow. |
| [`planning/m3d9-reservation-integrity.md`](planning/m3d9-reservation-integrity.md) | Shipped M3D.9 post-ship remediation: confirmed quantity-basis fidelity, successor revision/request revalidation, and event↔outcome compatibility. |
| [`planning/m3e-supplier-operational-control.md`](planning/m3e-supplier-operational-control.md) | Shipped M3E Supplier operational-control slice. M3E.1–M3E.7b (including M3E.5R and M3D remediations) are shipped. M3E is fully shipped. Milestone-wide acceptance closed by shipped [M3F](planning/m3f-acceptance-and-hardening.md). |
| [`planning/m3e7b-release-gate-evidence.md`](planning/m3e7b-release-gate-evidence.md) | M3E.7b release-gate evidence index: named scenario builders, race/replay/catch-up matrix, query/`EXPLAIN`, and documentation reconciliation. |
| [`planning/m3e0-m3d-closure-gate.md`](planning/m3e0-m3d-closure-gate.md) | Satisfied M3E.0 M3D closure gate: pinned QC-green implementation base. |
| [`planning/m3f-acceptance-and-hardening.md`](planning/m3f-acceptance-and-hardening.md) | Shipped M3F milestone acceptance and hardening (M3F.0–M3F.4). See [M3F.4 closure](planning/m3f4-milestone-closure.md). |
| [`planning/m3f3-finding-log.md`](planning/m3f3-finding-log.md) | M3F.3 finding log and hardening evidence. |
| [`planning/m3f4-milestone-closure.md`](planning/m3f4-milestone-closure.md) | M3F.4 parent exit criteria 1–15 evidence map; marks M3 complete. |
| [`planning/m3e-decision-register.md`](planning/m3e-decision-register.md) | Accepted M3E decision register. |
| [`adr/0013-supplier-operational-commitments-deadlines-exposure-and-ending.md`](adr/0013-supplier-operational-commitments-deadlines-exposure-and-ending.md) | Accepted ADR 0013; implemented by shipped M3E for commitments, Deadlines, deposits, exposure, Needs attention, and Arrangement ending. |
| [`planning/m4-offers-and-pricing.md`](planning/m4-offers-and-pricing.md) | Accepted M4 parent. Not implementation authority for later slices. M4A–M4D.0 (+R) shipped; M4D.1 Slice 1 shipped; Slice 2A.1–2A.2R shipped; Slice 2A.2R2 Accepted; later M4D.1 slices and M4E unimplemented. |
| [`planning/m40-task-flow-and-contract.md`](planning/m40-task-flow-and-contract.md) | Accepted M4.0 task-flow and contract gate. Documentation only; no M4 domain records of its own. |
| [`planning/m4a-service-definitions-and-sources.md`](planning/m4a-service-definitions-and-sources.md) | Accepted and shipped M4A unpublished Service Offer drafts, exact M3 source bindings, and narrow compatibility evaluator. |
| [`planning/m4b-client-pricing-and-anonymous-preview.md`](planning/m4b-client-pricing-and-anonymous-preview.md) | Accepted and shipped M4B unpublished Client prices, anonymous calculator, and optional indicative scenario economics. |
| [`planning/m4c-packages-choices-and-client-terms.md`](planning/m4c-packages-choices-and-client-terms.md) | Accepted and shipped M4C unpublished Package drafts, package-only version ownership, choice templates, Client terms, and Package-owned prices. Publication is not shipped. |
| [`planning/m4d-publication-and-live-feasibility.md`](planning/m4d-publication-and-live-feasibility.md) | Shipped M4D publication, freeze, Sales enabled, live feasibility, and M3 disclosure previews. |
| [`planning/m4d0-narrow-group-departure-builder.md`](planning/m4d0-narrow-group-departure-builder.md) | M4D.0 shipped domain; M4D.0R historical interim UI. Composition primary chrome is M4D.1 Slice 1. M4E remains unimplemented. |
| [`planning/m4d0r-builder-interface-remediation.md`](planning/m4d0r-builder-interface-remediation.md) | Historical interim M4D.0R Staff builder presentation. Primary chrome superseded by M4D.1 Slice 1 Composition. |
| [`planning/m4d1-departure-composition-workspace.md`](planning/m4d1-departure-composition-workspace.md) | Accepted M4D.1 Departure Composition Workspace. Slice 1 and Slice 2A.1–2A.2R shipped; Slice 2A.2R2 Accepted; later slices remain unauthorized until named. |
| [`planning/m4d1-slice1-workspace-foundation.md`](planning/m4d1-slice1-workspace-foundation.md) | Shipped M4D.1 Slice 1 workspace foundation (Composition shell, Service Map, `/builder` redirect). Does not authorize typed Supplier adapters or later M4D.1 slices. |
| [`planning/m4d1-slice2a1-cruise-sailing-and-cabin-inventory.md`](planning/m4d1-slice2a1-cruise-sailing-and-cabin-inventory.md) | Shipped M4D.1 Slice 2A.1 typed Cruise sailing and cabin inventory (Stops A–B) over generic M3. |
| [`planning/m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md`](planning/m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md) | Shipped M4D.1 Slice 2A.2 typed Cruise Supplier rates and occupancy totals (Stop C) over generic M3C. Historical fixed-form baseline; superseded for new typed-rate work by Accepted 2A.2R. |
| [`planning/m4d1-slice2a2r-cruise-supplier-rate-matrix.md`](planning/m4d1-slice2a2r-cruise-supplier-rate-matrix.md) | Shipped M4D.1 Slice 2A.2R Cruise Supplier Rate Matrix remediation (sole shipped matrix compilation authority). |
| [`planning/m4d1-slice2a2r2-cruise-rate-matrix-interaction.md`](planning/m4d1-slice2a2r2-cruise-rate-matrix-interaction.md) | Accepted M4D.1 Slice 2A.2R2 Cruise Supplier Rate Matrix Interaction (interactive builder remediation; not yet shipped). |
| [`adr/0014-client-offers-publication-and-supply-compatibility.md`](adr/0014-client-offers-publication-and-supply-compatibility.md) | Accepted ADR 0014; M4 identity, publication, source compatibility, and M5 Charge-posting handoff. M4A–M4D.0 shipped; M4D.1 Accepted. Not implementation authority for M4E or unamended M4D.1 provenance/choice-rate work. |
| [`planning/drafts/README.md`](planning/drafts/README.md) | Draft staging area. M3E promoted 2026-09-18. M4 parent, ADR 0014, and M4.0 promoted 2026-09-20. M4A–M4D.0 (+R) shipped 2026-09-20/21. M4D.1 Accepted 2026-09-21. M4D.1 Slice 1 and Slice 2A.1 shipped 2026-09-22. Slice 2A.2 shipped 2026-09-22. Slice 2A.2R shipped 2026-09-22. Slice 2A.2R2 Accepted 2026-09-22. |
| [`operations/`](operations/) | Executable operational and production guidance. |
| [`ui/`](ui/) | Current visual and interaction contracts. |
| [`palette.md`](palette.md) | Harbor & Waypoint brand palette. |
| [`terminology.md`](terminology.md) | Current canonical product vocabulary. |
| [`scenarios/`](scenarios/) | Representative departures used to test model generality. |
| [`licenses/`](licenses/) | Notices for bundled fonts and icons. |
| [`archive/`](archive/README.md) | Non-normative v0.02 and earlier material. |

## Maintenance rules

- Keep shipped behavior distinct from planned behavior.
- Link to a governing document instead of copying it into another file.
- Preserve superseded ADRs in `adr/`; archive obsolete implementation plans elsewhere.
- Update `AGENTS.md`, `README.md`, and this index when an authority moves or the shipped boundary changes.
- Do not place secrets, real traveler data, or production credentials in documentation or scenarios.
