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
| [`planning/m3-supplier-planning.md`](planning/m3-supplier-planning.md) | Accepted M3 parent, amended through M3D authority. M3A–M3D, M3D.0, M3D.7, and M3D.8 shipped. Not implementation authority for M3E–M3F. |
| [`planning/m3a-draft-arrangement-structure.md`](planning/m3a-draft-arrangement-structure.md) | Shipped M3A draft Arrangement structure slice. |
| [`planning/m3b-supplier-capacity.md`](planning/m3b-supplier-capacity.md) | Shipped M3B Supplier capacity slice. Draft configuration and the capacity engine are shipped; Arrangement activation and Staff event UI ship with M3D. |
| [`planning/m3c-cost-terms-and-forecasts.md`](planning/m3c-cost-terms-and-forecasts.md) | Shipped M3C Supplier cost terms and forecasts slice. Draft cost sources, definitions, components, assumptions, and derived forecasts are shipped; Arrangement activation and effective contracted terms ship with M3D. |
| [`planning/m3d0-planning-workspace-compression.md`](planning/m3d0-planning-workspace-compression.md) | Shipped M3D.0 Supplier-planning workspace compression over M3A–M3C workflows. No Arrangement activation or other M3D domain records. |
| [`planning/m3d-activation-reservations-confirmations.md`](planning/m3d-activation-reservations-confirmations.md) | Shipped M3D Arrangement activation, Reservations, and confirmations slice. |
| [`planning/m3d7-activated-definition-immutability.md`](planning/m3d7-activated-definition-immutability.md) | Shipped M3D.7 post-ship remediation: freeze exact-version definition graphs after leaving draft (Rails and PostgreSQL). |
| [`planning/m3d8-activation-reservation-product-quality.md`](planning/m3d8-activation-reservation-product-quality.md) | Shipped M3D.8 post-ship remediation: canonical forms, error recovery, progressive disclosure, exclusive composers, bounded Reservation lists/histories, and table overflow. |
| [`planning/drafts/README.md`](planning/drafts/README.md) | Short index of active planning drafts. Currently empty after M3D promotion. |
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
