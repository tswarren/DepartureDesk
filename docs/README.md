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
| [`planning/m3-supplier-planning.md`](planning/m3-supplier-planning.md) | Accepted M3 parent, amended through M3E authority. M3A–M3D, M3D.0, M3D.7, M3D.8, and M3D.9 shipped. [M3E](planning/m3e-supplier-operational-control.md) shipped through M3E.7b (including M3E.5R and M3D remediations). Arrangement ending is shipped. M3E is fully shipped. Not implementation authority for M3F. |
| [`planning/m3a-draft-arrangement-structure.md`](planning/m3a-draft-arrangement-structure.md) | Shipped M3A draft Arrangement structure slice. |
| [`planning/m3b-supplier-capacity.md`](planning/m3b-supplier-capacity.md) | Shipped M3B Supplier capacity slice. Draft configuration and the capacity engine are shipped; Arrangement activation and Staff event UI ship with M3D. |
| [`planning/m3c-cost-terms-and-forecasts.md`](planning/m3c-cost-terms-and-forecasts.md) | Shipped M3C Supplier cost terms and forecasts slice. Draft cost sources, definitions, components, assumptions, and derived forecasts are shipped; Arrangement activation and effective contracted terms ship with M3D. |
| [`planning/m3d0-planning-workspace-compression.md`](planning/m3d0-planning-workspace-compression.md) | Shipped M3D.0 Supplier-planning workspace compression over M3A–M3C workflows. No Arrangement activation or other M3D domain records. |
| [`planning/m3d-activation-reservations-confirmations.md`](planning/m3d-activation-reservations-confirmations.md) | Shipped M3D Arrangement activation, Reservations, and confirmations slice. |
| [`planning/m3d7-activated-definition-immutability.md`](planning/m3d7-activated-definition-immutability.md) | Shipped M3D.7 post-ship remediation: freeze exact-version definition graphs after leaving draft (Rails and PostgreSQL). |
| [`planning/m3d8-activation-reservation-product-quality.md`](planning/m3d8-activation-reservation-product-quality.md) | Shipped M3D.8 post-ship remediation: canonical forms, error recovery, progressive disclosure, exclusive composers, bounded Reservation lists/histories, and table overflow. |
| [`planning/m3d9-reservation-integrity.md`](planning/m3d9-reservation-integrity.md) | Shipped M3D.9 post-ship remediation: confirmed quantity-basis fidelity, successor revision/request revalidation, and event↔outcome compatibility. |
| [`planning/m3e-supplier-operational-control.md`](planning/m3e-supplier-operational-control.md) | Shipped M3E Supplier operational-control slice. M3E.1–M3E.7b (including M3E.5R and M3D remediations) are shipped: openings/dispositions/evidence/open-state inactivation, Deadline definitions/occurrences/projection catch-up, Deposit Requirements/planning milestones, qualified exposure, Needs-attention catalog/Departure rollup, Arrangement ending, operational UI recovery, and scenario/release gate. M3E is fully shipped and production-ready. M3F still owns milestone-wide M3A–M3E acceptance. |
| [`planning/m3e7b-release-gate-evidence.md`](planning/m3e7b-release-gate-evidence.md) | M3E.7b release-gate evidence index: named scenario builders, race/replay/catch-up matrix, query/`EXPLAIN`, and documentation reconciliation. |
| [`planning/m3e0-m3d-closure-gate.md`](planning/m3e0-m3d-closure-gate.md) | Satisfied M3E.0 M3D closure gate: pinned QC-green implementation base. |
| [`planning/m3e-decision-register.md`](planning/m3e-decision-register.md) | Accepted M3E decision register. |
| [`adr/0013-supplier-operational-commitments-deadlines-exposure-and-ending.md`](adr/0013-supplier-operational-commitments-deadlines-exposure-and-ending.md) | Accepted ADR 0013; implemented by shipped M3E for commitments, Deadlines, deposits, exposure, Needs attention, and Arrangement ending. |
| [`planning/drafts/README.md`](planning/drafts/README.md) | Draft staging area. M3E promoted 2026-09-18. |
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
