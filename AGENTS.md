# AGENTS.md

This file is the repository contract for coding agents and automated contributors working on DepartureDesk. It applies to the entire repository unless a more specific `AGENTS.md` exists in a subdirectory.

## Mission

DepartureDesk helps travel agencies operate and account for group travel. It must preserve the real distinctions among supplier commitments, client sales, travelers, shared accommodations, payment responsibility, receipts, and supplier settlement.

The application should feel operationally calm, financially trustworthy, and travel-oriented without becoming recreational or decorative.

## Current boundary

**M4D.1 Slice authority:** [M4D.1 Slice 1](docs/planning/m4d1-slice1-workspace-foundation.md) is **shipped** (Composition workspace foundation). Composition is the primary Staff chrome for draft/active Departures with `manage_departures`. [M4D.0R](docs/planning/m4d0r-builder-interface-remediation.md) is historical interim presentation. [M4D.1 Slice 2A.1](docs/planning/m4d1-slice2a1-cruise-sailing-and-cabin-inventory.md) is **shipped** (typed Cruise sailing and cabin inventory over generic M3). [M4D.1 Slice 2A.2](docs/planning/m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md) is **shipped** (typed Cruise Supplier rates and occupancy totals over generic M3C). [M4D.1 Slice 2A.2R](docs/planning/m4d1-slice2a2r-cruise-supplier-rate-matrix.md) is **shipped** (Cruise Supplier rate-matrix remediation over generic M3C). [M4D.1 Slice 2A.2R2](docs/planning/m4d1-slice2a2r2-cruise-rate-matrix-interaction.md) is **shipped** (interactive Cruise Supplier rate-matrix builder remediation). [M4D.1 Slice 2B-R](docs/planning/m4d1-slice2br-cruise-deposit-semantics-amendment.md) is **shipped** (M3E capacity-sourced deposit quantities and source-aware cumulative targets). [M4D.1 Slice 2A.2R3](docs/planning/m4d1-slice2a2r3-cruise-rate-shape-detector-remediation.md) is **shipped** (rate-shape detector remediation). [M4D.1 Slice 2B](docs/planning/m4d1-slice2b-cruise-deposits-deadlines-and-activation-safe-editing.md) is **shipped** (typed Stop D; **2B-A/2B-B/2B-C delivered**). [M4D.1 Slice 2B-UX](docs/planning/m4d1-slice2bux-deposits-deadlines-workspace-remediation.md) is **shipped** (Stop D workspace remediation). [M4D.1 Slice 2B-UX-R](docs/planning/m4d1-slice2buxr-contributor-replace-and-closure.md) is **shipped** (contributor-replace collision closure). [M4D.1 Slice 2C](docs/planning/m4d1-slice2c-cruise-service-connection.md) is **shipped** (Stop E Cruise service connection; merge `b35a4f6`). [M4D.1 Slice 2D](docs/planning/m4d1-slice2d-cruise-client-terms-and-scenario-review.md) is **shipped** (Stops F–G Cruise Client terms and scenario review; merge `dc272a3`, PR #154). Do not implement Slice 3, later M4D.1 slices, M4E, or M5 until their accepted plans name that work. Unmerged branch `m4d1-slice3-hotel-transport-activity` and PR #156 are prototype evidence and are not an implementation source.
The shipped domain is agency identity, the complete M1 Client and Supplier directories, [M2A](docs/planning/m2a-departure-core.md) Departure draft/activation/`D-` issuance/return to draft/search, [M2B](docs/planning/m2b-departed-lifecycle.md) departed transitions, scheduled lifecycle jobs, and schedule/currency/lifecycle corrections, [M2C](docs/planning/m2c-acceptance-and-hardening.md) proof and hardening, [M3A](docs/planning/m3a-draft-arrangement-structure.md) draft Supplier Arrangement structure, [M3B](docs/planning/m3b-supplier-capacity.md) draft Supplier capacity configuration plus the capacity event/projection/reconciliation engine, [M3C](docs/planning/m3c-cost-terms-and-forecasts.md) draft Supplier cost terms and derived forecasts, [M3D.0](docs/planning/m3d0-planning-workspace-compression.md) guided workspace compression over M3A–M3C, [M3D](docs/planning/m3d-activation-reservations-confirmations.md) Arrangement activation, Reservations, confirmations, effective capacity, and confirmation-triggered commitment openings, [M3D.7](docs/planning/m3d7-activated-definition-immutability.md) activated exact-version definition immutability in Rails and PostgreSQL, [M3D.8](docs/planning/m3d8-activation-reservation-product-quality.md) activation/Reservation product-quality remediation, and [M3D.9](docs/planning/m3d9-reservation-integrity.md) Reservation integrity remediation. M2 is complete. The [M3 parent](docs/planning/m3-supplier-planning.md) is accepted and amended through M3E authority. [M3D](docs/planning/m3d-activation-reservations-confirmations.md) and [ADR 0012](docs/adr/0012-arrangement-activation-reservations-and-confirmations.md) are shipped. Arrangement activation, Reservations, confirmations, effective-capacity controls, and confirmation-triggered commitment openings are shipped M3D vocabulary. Travel Program, remittance, and FX remain unimplemented until an accepted slice plan names that work. [M3E](docs/planning/m3e-supplier-operational-control.md) and [ADR 0013](docs/adr/0013-supplier-operational-commitments-deadlines-exposure-and-ending.md) are shipped through M3E.7b (including M3E.5R and M3D remediations); [M3E.0](docs/planning/m3e0-m3d-closure-gate.md) is satisfied with pinned QC-green base `344ab86`. M3E.1 ships source-shaped `confirmation_trigger` openings, append-only dispositions/reopen, multi-member evidence coverage with exact-member disqualification and whole revocation, and ordinary Supplier inactivation that blocks only current open commitments. M3E.2 ships Deadline definitions (`one_shared` cardinality; `per_source` deferred), immutable occurrences, activation materialization with elapsed acknowledgment, successor reconciliation, due/overdue/warning projection catch-up (no time-created domain events), and `deadline_requirement` openings. M3E.3 ships Deposit Requirement definitions and immutable tranches, `deposit_requirement` openings, external-handled attestation (`handled_externally`, never labeled paid), Staff planning milestones (`names_assigned_to_supplier`), earlier-of Deadline replacement without duplicate commitments, and M3D.7 freeze for deposit definition families. M3E.4 ships qualified exposure projections (`guaranteed`/`contingent`/`forecast`), Arrangement rebuild, required-deposit measure, explicit contingent-to-guaranteed qualification, and repair. M3E.5 ships the closed Needs-attention detector catalog, Agency warning timing with definition override, action-grouped Arrangement findings, and Departure supplier-planning rollup. M3E.5R ships integrity and recovery; M3D remediations ship Reservation partial-response disclosure; M3E.6a–M3E.6b ship Arrangement ending preview and atomic end; M3E.7a–M3E.7b ship operational UI recovery and the scenario/release gate. Arrangement ending is shipped. M3E is fully shipped and production-ready. [M3F](docs/planning/m3f-acceptance-and-hardening.md) is shipped (M3F.0–M3F.4): task-flow backlog, integrated Celebrity/Vineyard acceptance, finding-driven hardening, and milestone closure. **M3 is complete.** Celebrity deposits/milestones remain Arrangement-wide. Client demand, Travelers, Obligations, and Payments remain unimplemented. The [M4 parent](docs/planning/m4-offers-and-pricing.md), [ADR 0014](docs/adr/0014-client-offers-publication-and-supply-compatibility.md), and [M4.0](docs/planning/m40-task-flow-and-contract.md) are accepted and are not implementation authority for later slices. [M4A](docs/planning/m4a-service-definitions-and-sources.md) is shipped (unpublished Service Offer drafts, exact M3 source bindings, and the narrow compatibility evaluator). [M4B](docs/planning/m4b-client-pricing-and-anonymous-preview.md) is shipped (unpublished Client prices, anonymous calculator, optional indicative scenario economics). [M4C](docs/planning/m4c-packages-choices-and-client-terms.md) is shipped (unpublished Package drafts, package-only version ownership, choice templates, and Client terms). [M4D](docs/planning/m4d-publication-and-live-feasibility.md) is shipped (publication, Sales enabled, live feasibility, and M3 disclosure previews). [M4D.0](docs/planning/m4d0-narrow-group-departure-builder.md) and [M4D.0R](docs/planning/m4d0r-builder-interface-remediation.md) are shipped (M4D.0R is historical interim Staff builder UI). [M4D.1](docs/planning/m4d1-departure-composition-workspace.md) is Accepted; [M4D.1 Slice 1](docs/planning/m4d1-slice1-workspace-foundation.md) is shipped (Composition shell, Service Map, `/builder` redirect). [M4D.1 Slice 2A.1](docs/planning/m4d1-slice2a1-cruise-sailing-and-cabin-inventory.md) is shipped (typed Cruise sailing and cabin inventory). [M4D.1 Slice 2A.2](docs/planning/m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md) is shipped (typed Cruise Supplier rates and occupancy totals). [M4D.1 Slice 2A.2R](docs/planning/m4d1-slice2a2r-cruise-supplier-rate-matrix.md) is shipped. [M4D.1 Slice 2A.2R2](docs/planning/m4d1-slice2a2r2-cruise-rate-matrix-interaction.md) is shipped (interactive matrix builder remediation). [M4D.1 Slice 2B-R](docs/planning/m4d1-slice2br-cruise-deposit-semantics-amendment.md) is shipped (deposit `capacity_pool_units` and source-aware cumulative contributors). [M4D.1 Slice 2B](docs/planning/m4d1-slice2b-cruise-deposits-deadlines-and-activation-safe-editing.md) is shipped (**2B-A/2B-B/2B-C delivered**). [M4D.1 Slice 2B-UX](docs/planning/m4d1-slice2bux-deposits-deadlines-workspace-remediation.md) is shipped (workspace remediation). [M4D.1 Slice 2B-UX-R](docs/planning/m4d1-slice2buxr-contributor-replace-and-closure.md) is shipped (contributor-replace collision closure). [M4D.1 Slice 2C](docs/planning/m4d1-slice2c-cruise-service-connection.md) is shipped (Stop E Cruise service connection; merge `b35a4f6`). [M4D.1 Slice 2D](docs/planning/m4d1-slice2d-cruise-client-terms-and-scenario-review.md) is shipped (Stops F–G Cruise Client terms and scenario review; merge `dc272a3`, PR #154). Do not implement Slice 3, later M4D.1 slices, M4E, or M5 until their accepted plans name that work. Unmerged branch `m4d1-slice3-hotel-transport-activity` and PR #156 are prototype evidence and are not an implementation source.
Documentation authority and status are indexed in [docs/README.md](docs/README.md). Product authority is [docs/planning/departure-desk-mvp.md](docs/planning/departure-desk-mvp.md) and [docs/planning/commercial-domain-decision-register.md](docs/planning/commercial-domain-decision-register.md). Do not implement MFA, platform support, a workforce-role taxonomy, Travel Program, or later commercial records from those documents until an accepted slice plan names that work. An accepted milestone contract is not enough. [M1A](docs/planning/m1a-individual-client.md), [M1B](docs/planning/m1b-client-organizations.md), [M1C](docs/planning/m1c-supplier-core.md), [M1D](docs/planning/m1d-supplier-locations-and-contacts.md), [M1E](docs/planning/m1e-directory-acceptance-and-hardening.md), [M2A](docs/planning/m2a-departure-core.md), [M2B](docs/planning/m2b-departed-lifecycle.md), [M2C](docs/planning/m2c-acceptance-and-hardening.md), [M3A](docs/planning/m3a-draft-arrangement-structure.md), [M3B](docs/planning/m3b-supplier-capacity.md), [M3C](docs/planning/m3c-cost-terms-and-forecasts.md), [M3D.0](docs/planning/m3d0-planning-workspace-compression.md), [M3D](docs/planning/m3d-activation-reservations-confirmations.md), [M3D.7](docs/planning/m3d7-activated-definition-immutability.md), [M3D.8](docs/planning/m3d8-activation-reservation-product-quality.md), [M3D.9](docs/planning/m3d9-reservation-integrity.md), [M3E](docs/planning/m3e-supplier-operational-control.md) (M3E.1–M3E.7b), and [M3F](docs/planning/m3f-acceptance-and-hardening.md) (M3F.0–M3F.4), [M4A](docs/planning/m4a-service-definitions-and-sources.md), [M4B](docs/planning/m4b-client-pricing-and-anonymous-preview.md), and [M4C](docs/planning/m4c-packages-choices-and-client-terms.md) are shipped. M2 and M3 are complete. The [M4 parent](docs/planning/m4-offers-and-pricing.md), [ADR 0014](docs/adr/0014-client-offers-publication-and-supply-compatibility.md), and [M4.0](docs/planning/m40-task-flow-and-contract.md) are accepted and are not implementation authority for later slices. [M4A](docs/planning/m4a-service-definitions-and-sources.md) is shipped (unpublished Service Offer drafts, exact M3 source bindings, and the narrow compatibility evaluator). [M4B](docs/planning/m4b-client-pricing-and-anonymous-preview.md) is shipped (unpublished Client prices, anonymous calculator, optional indicative scenario economics). [M4C](docs/planning/m4c-packages-choices-and-client-terms.md) is shipped (unpublished Package drafts, package-only version ownership, choice templates, and Client terms). [M4D](docs/planning/m4d-publication-and-live-feasibility.md) is shipped (publication, Sales enabled, live feasibility, and M3 disclosure previews). [M4D.0](docs/planning/m4d0-narrow-group-departure-builder.md) and [M4D.0R](docs/planning/m4d0r-builder-interface-remediation.md) are shipped (M4D.0R historical interim). [M4D.1](docs/planning/m4d1-departure-composition-workspace.md) is Accepted; [Slice 1](docs/planning/m4d1-slice1-workspace-foundation.md) is shipped. [Slice 2A.1](docs/planning/m4d1-slice2a1-cruise-sailing-and-cabin-inventory.md) is shipped. [Slice 2A.2](docs/planning/m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md) is shipped. [Slice 2A.2R](docs/planning/m4d1-slice2a2r-cruise-supplier-rate-matrix.md) is shipped. [Slice 2A.2R2](docs/planning/m4d1-slice2a2r2-cruise-rate-matrix-interaction.md) is shipped. [Slice 2B-R](docs/planning/m4d1-slice2br-cruise-deposit-semantics-amendment.md) is shipped. [Slice 2A.2R3](docs/planning/m4d1-slice2a2r3-cruise-rate-shape-detector-remediation.md) is shipped. [Slice 2B](docs/planning/m4d1-slice2b-cruise-deposits-deadlines-and-activation-safe-editing.md) is shipped (**2B-A/2B-B/2B-C delivered**). [Slice 2B-UX](docs/planning/m4d1-slice2bux-deposits-deadlines-workspace-remediation.md) is shipped. [Slice 2B-UX-R](docs/planning/m4d1-slice2buxr-contributor-replace-and-closure.md) is shipped. [Slice 2C](docs/planning/m4d1-slice2c-cruise-service-connection.md) is shipped (Stop E; merge `b35a4f6`). [Slice 2D](docs/planning/m4d1-slice2d-cruise-client-terms-and-scenario-review.md) is shipped (Stops F–G; merge `dc272a3`, PR #154). Do not implement Slice 3 or later M4D.1 slices until named. Unmerged branch `m4d1-slice3-hotel-transport-activity` and PR #156 are prototype evidence and are not an implementation source. Do not implement M4E until that slice's accepted plan names the work. [docs/terminology.md](docs/terminology.md) is the current vocabulary; Party-era terminology is archived.

There is no migration path from the Party and membership schema. Do not add a compatibility layer, dual-schema period, or upgrade of a Party database.

## Architecture decisions

Accepted ADRs under `docs/adr` are authoritative. Read the relevant ADR before designing or changing its domain.

- [ADR 0001: Money and currency representation](docs/adr/0001-money-and-currency.md) accepts `money-rails`, `bigint` minor-unit persistence, explicit currencies, strict parsing, and explicit historical conversion facts. The gem is installed. [M3C](docs/planning/m3c-cost-terms-and-forecasts.md) shipped the first draft Supplier cost monetary tables; posted client/supplier ledgers, Obligations, and Payments are not shipped. Do not persist functional-currency translations. The MVP commercial contract later limits each Departure to one operating currency and excludes FX.
- [ADR 0005: Agency identity](docs/adr/0005-agency-identity.md) is the tenancy, invitation, session, permission, and office-context contract. Implement it. Do not invent alternatives.
- [ADR 0006: Separate identity domains](docs/adr/0006-separate-identity-domains.md) rejects a universal Party identity and separates AgencyUser, Client, Supplier, and Traveler contexts. It is an accepted future-domain boundary, not permission to implement those records before an accepted slice.
- [ADR 0007: Departure as operational root](docs/adr/0007-departure-operational-root.md) accepts Departure as the dated operational root and defers Travel Program. Do not add a Travel Program table, route, model, or foreign key until a later accepted slice names that work.
- [ADR 0008: Supplier Arrangement version topology](docs/adr/0008-supplier-arrangement-version-topology.md) accepts stable Arrangement and child identities with per-version definitions. M3A draft topology is implemented; activation and successor behavior are shipped with M3D; [M3D.7](docs/planning/m3d7-activated-definition-immutability.md) freezes exact-version definition graphs after leaving draft.
- [ADR 0009: Supplier contracting and service-provider roles](docs/adr/0009-supplier-contracting-and-service-provider-roles.md) accepts contracting Supplier, computed Service Provider, Arrangement contact, and inactivation-dependency meanings. M3A Supplier-role behavior is implemented; later dependency extensions are deferred.
- [ADR 0010: Supplier capacity ledger and projection](docs/adr/0010-supplier-capacity-ledger-and-projection.md) accepts stable Capacity Pool identity, immutable capacity events, scheduled effectiveness, reconciliation, and rebuildable projections. [M3B](docs/planning/m3b-supplier-capacity.md) shipped the implementing persistence and engine; Arrangement activation and Staff event UI are shipped with M3D.
- [ADR 0011: Supplier cost definitions and forecast evaluation](docs/adr/0011-supplier-cost-definitions-and-forecast-evaluation.md) accepts exact-version cost sources, staged definitions, constrained components, planning assumptions, and derived forecasts. [M3C](docs/planning/m3c-cost-terms-and-forecasts.md) shipped the implementing slice; Arrangement activation and effective contracted terms are shipped with M3D.
- [ADR 0012: Arrangement activation, Reservations, and confirmations](docs/adr/0012-arrangement-activation-reservations-and-confirmations.md) accepts activation manifests, successor copying, Reservation history, confirmation evidence, and the M3D confirmation-triggered commitment core. [M3D](docs/planning/m3d-activation-reservations-confirmations.md) ships the implementing slice after shipped [M3D.0](docs/planning/m3d0-planning-workspace-compression.md). A 2026-09-18 supersession note records that [ADR 0013](docs/adr/0013-supplier-operational-commitments-deadlines-exposure-and-ending.md) supersedes “manual opening” and every-row inactivation wording for post-M3E behavior.
- [ADR 0013: Supplier operational commitments, Deadlines, exposure, and Arrangement ending](docs/adr/0013-supplier-operational-commitments-deadlines-exposure-and-ending.md) accepts source-shaped commitment openings and dispositions, Deposit Requirements, Deadlines, planning milestones, exposure, Needs attention, and Arrangement ending. [M3E](docs/planning/m3e-supplier-operational-control.md) is the shipped implementing slice (M3E.1–M3E.7b).
- [ADR 0014: Client offers, publication, and Supplier-source compatibility](docs/adr/0014-client-offers-publication-and-supply-compatibility.md) accepts Service Offer and Package identity, publication, activated-only M3 pins, Sales enabled versus computed eligibility, and the M5 Charge-posting handoff. [M4A](docs/planning/m4a-service-definitions-and-sources.md) ships unpublished drafts and source compatibility. [M4B](docs/planning/m4b-client-pricing-and-anonymous-preview.md) ships unpublished Client prices, the anonymous calculator, and optional indicative scenario economics. They are not implementation authority for later slices. [M4.0](docs/planning/m40-task-flow-and-contract.md) is the accepted task-flow gate. [M4C](docs/planning/m4c-packages-choices-and-client-terms.md) is shipped (unpublished Package drafts, package-only version ownership, choice templates, and Client terms). [M4D](docs/planning/m4d-publication-and-live-feasibility.md) is shipped (publication, Sales enabled, live feasibility, and M3 disclosure previews). [M4D.0](docs/planning/m4d0-narrow-group-departure-builder.md) and [M4D.0R](docs/planning/m4d0r-builder-interface-remediation.md) are shipped (M4D.0R interim UI). [M4D.1](docs/planning/m4d1-departure-composition-workspace.md) is Accepted; [Slice 1](docs/planning/m4d1-slice1-workspace-foundation.md) is shipped. [Slice 2A.1](docs/planning/m4d1-slice2a1-cruise-sailing-and-cabin-inventory.md) is shipped. [Slice 2A.2](docs/planning/m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md) is shipped. [Slice 2A.2R](docs/planning/m4d1-slice2a2r-cruise-supplier-rate-matrix.md) is shipped. Later sub-slices may amend this ADR for choice-rate linkage or Client price provenance—this ADR is not implementation authority for those until amended with the implementing slice. Do not implement M4E until that slice's accepted plan names the work.
- [ADR 0002](docs/adr/0002-agency-tenancy-and-membership.md) and [ADR 0003](docs/adr/0003-membership-lifecycle-and-invitations.md) are **Superseded by ADR 0005**. Do not implement them.

## Canonical domain language

Use these terms consistently in code, migrations, UI labels, tests, and documentation.

| Term | Contract |
| --- | --- |
| Agency | The travel agency using DepartureDesk and owning operational records. Agency is the tenant. Status is `active`, `suspended`, or `closed`. |
| Workspace code | The immutable, globally unique sign-in key for an agency. Stored already normalized. Request `agency_id` never establishes tenancy. |
| Office | An agency-owned operating location. It is operational context and metadata, not an authorization grant and not a tenant. Do not use `Branch`. |
| Agency user | An account that belongs to exactly one agency. The same email in two agencies is two accounts. Roles are exactly `administrator`, `staff`, or `viewer`. |
| Relationship | A descriptive string on an agency user. It does not grant access. |
| Session | Authentication root. It derives its agency through the agency user and does not store `agency_id`. |
| Current office | A session preference, then the user's default office, then nil. Changing it changes no permission. |

Client Person, Client Organization, Client (person-backed or organization-backed), person-owned and organization-owned contact points, organization-contact assignments, Supplier, Supplier categories, Supplier-owned contact points, Supplier Location, Supplier Contact, and Supplier Contact-owned email and phone destinations are shipped vocabulary. Departure draft, activation, reference issuance, return to draft, departed, and schedule/currency/lifecycle correction are shipped vocabulary. Supplier Arrangement, Arrangement version, Arrangement Item, Service Occurrence, and Supplier Resource draft vocabulary is shipped with M3A. Capacity Pool, pair classification, capacity events, projections, and reconciliations are shipped with M3B as draft configuration plus the engine for later M3D use. Supplier cost source, cost definition, cost component, charging Supplier, usage assumption, occupancy profile, and forecast readiness are shipped M3C vocabulary for draft planning; effective contracted terms remain M3D. Guided Item setup, bulk capacity decisions, contextual planning quantities, readiness review, and reorder mode are shipped M3D.0 interaction vocabulary. Arrangement activation, Supplier Reservation, confirmation, committed Supplier, and confirmation-triggered commitment opening are shipped M3D vocabulary. Source-shaped commitment openings, dispositions, reopenings, multi-member evidence coverage, exact-member disqualification, whole-coverage revocation, and open-state inactivation are shipped M3E.1 vocabulary. Deadline definitions, occurrences, activation materialization, projection catch-up, and `deadline_requirement` openings are shipped M3E.2 vocabulary. Deposit Requirement definitions, immutable tranches, `deposit_requirement` openings, external-handled attestation, and Staff planning milestones (`names_assigned_to_supplier`) are shipped M3E.3 vocabulary. Qualified exposure components and summaries (`guaranteed`/`contingent`/`forecast`), required-deposit measure, and explicit contingent qualification are shipped M3E.4 vocabulary. Needs-attention findings, Agency warning timing, and Departure attention rollup are shipped M3E.5 vocabulary. Arrangement ending (preview, atomic end, safe cascades) is shipped M3E.6 vocabulary. Traveler, Travel Program, Receipt, and Obligation terms remain planned. **Service Offer** unpublished draft identity, version-owned Client definition, exact M3 source bindings, and the narrow `equivalent`/`material`/`unknown` compatibility evaluator are shipped [M4A](docs/planning/m4a-service-definitions-and-sources.md) vocabulary. Version-owned **Client price**, anonymous scenario preview, and optional **indicative scenario economics** are shipped [M4B](docs/planning/m4b-client-pricing-and-anonymous-preview.md) vocabulary. Versioned **Package**, unpublished Package price, choice templates, and Client terms are shipped [M4C](docs/planning/m4c-packages-choices-and-client-terms.md) vocabulary. **Sales enabled**, computed **Selectable now** / **On request** / **Unavailable**, publication manifests, and Publish UI are shipped [M4D](docs/planning/m4d-publication-and-live-feasibility.md) vocabulary. **Group departure builder** domain (target/Client timing text, draft-only **undecided** fulfillment) is shipped [M4D.0](docs/planning/m4d0-narrow-group-departure-builder.md) vocabulary; [M4D.0R](docs/planning/m4d0r-builder-interface-remediation.md) is historical interim presentation. **Departure Composition Workspace**, five-area shell, **Service Map**, preparation outcomes, and derived area summaries are shipped [M4D.1 Slice 1](docs/planning/m4d1-slice1-workspace-foundation.md) vocabulary. Typed Cruise sailing and cabin inventory (Stops A–B) are shipped [M4D.1 Slice 2A.1](docs/planning/m4d1-slice2a1-cruise-sailing-and-cabin-inventory.md) vocabulary. Cruise Supplier rate schedule and occupancy totals (Stop C) are shipped [M4D.1 Slice 2A.2](docs/planning/m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md) vocabulary. Cruise Supplier rate matrix remediation is shipped [M4D.1 Slice 2A.2R](docs/planning/m4d1-slice2a2r-cruise-supplier-rate-matrix.md) vocabulary. Interactive Cruise Supplier rate-matrix builder remediation is shipped [M4D.1 Slice 2A.2R2](docs/planning/m4d1-slice2a2r2-cruise-rate-matrix-interaction.md) vocabulary. Collision-safe percentage↔profile rate-shape detection is shipped [M4D.1 Slice 2A.2R3](docs/planning/m4d1-slice2a2r3-cruise-rate-shape-detector-remediation.md) vocabulary. Typed Cruise Deposits and deadlines workspace (Stop D) is shipped [M4D.1 Slice 2B](docs/planning/m4d1-slice2b-cruise-deposits-deadlines-and-activation-safe-editing.md) vocabulary (**2B-A/2B-B/2B-C delivered**). Workspace remediation is shipped [M4D.1 Slice 2B-UX](docs/planning/m4d1-slice2bux-deposits-deadlines-workspace-remediation.md). Contributor-replace collision closure is shipped [M4D.1 Slice 2B-UX-R](docs/planning/m4d1-slice2buxr-contributor-replace-and-closure.md). Deposit `capacity_pool_units`, quantity-derived cumulative targets with explicit contributor links, and Path B Celebrity proof updates are shipped [M4D.1 Slice 2B-R](docs/planning/m4d1-slice2br-cruise-deposit-semantics-amendment.md) vocabulary. Cruise service connection is shipped [M4D.1 Slice 2C](docs/planning/m4d1-slice2c-cruise-service-connection.md) vocabulary. Cruise Client terms and scenario review are shipped [M4D.1 Slice 2D](docs/planning/m4d1-slice2d-cruise-client-terms-and-scenario-review.md) vocabulary (merge `dc272a3`, PR #154). Later M4D.1 slices remain unauthorized until named. Do not implement M4E until that slice's accepted plan names the work.

## Invariants agents must preserve

1. Sign-in looks up the agency by normalized workspace code before email or password lookup.
2. Missing workspace, unknown email, bad password, and inactive user or agency return the same generic failure.
3. Sign-in and password-reset rate limits use client IP plus normalized workspace code plus normalized email, not IP alone.
4. An agency user belongs to exactly one agency. Passwords and sessions are not shared across agencies.
5. Application code checks the permission catalog, not role names.
6. Viewer has no mutations except those in the catalog (`view_workspace`, `select_office_context`). Staff cannot manage users, roles, offices, or the agency profile.
7. Only an active administrator counts. Suspend, close, and demotion of the last active administrator are rejected after locking the agency, then the user, then rechecking the count.
8. Suspending or closing an agency or agency user destroys affected session rows. A stale cookie is rejected and cleared only when that browser presents it.
9. Invitation and password-reset tokens are stored as digests. Replacement and revocation invalidate the previous invitation token. Password change or reset bumps the credential version and destroys that user's sessions. A password-reset token cannot be used unless the agency is active.
10. An agency may have zero active offices. `Current.office` is then nil. Commands must not require a later active office. `ProvisionAgency` still creates the first office.
11. Office selection writes only the session preference. A query parameter never authorizes and never selects an office on GET.
12. Load tenant records through `Current.agency`. An identifier from another agency returns not found, not forbidden.
13. Tenant records that carry `agency_id` must prove same-agency foreign keys. Default office uses a composite foreign key `(default_office_id, agency_id)`. Database triggers reject changes to `Agency.workspace_code`, `AgencyUser.agency_id`, `Office.agency_id`, and `Office.code`. Stored email must equal `lower(btrim(email_address))`.
14. `ProvisionAgency` and agency lifecycle changes are privileged. They require an actor identifier, invent no platform user, and never return or log a plaintext password or token.
15. Audit successful administrative commands in the same transaction. Subjects are `Agency`, `AgencyUser`, `Office`, `ClientPerson`, `Client`, `ClientOrganization`, `Supplier`, `SupplierLocation`, `SupplierContact`, `Departure`, `SupplierArrangement`, `SupplierReservation`, `ServiceOffer`, and `Package` only. Do not audit expected failures.
16. Do not infer household, payer, occupancy, or payment state. Those records do not exist yet.

## Development environment

Development is Docker-only. Do not instruct contributors to install or run host Ruby, Rails, Bundler, PostgreSQL, or Tailwind.

Primary commands:

```bash
docker compose up --build
./dev/rails-docker bin/rails test
./dev/rails-docker bin/rails console
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails tailwindcss:build
```

Services:

- `web`: Rails server.
- `css`: Tailwind watcher; must run for styled development pages.
- `jobs`: Solid Queue worker.
- `db`: PostgreSQL 18.

When diagnosing a container failure, identify the first application error. Do not treat Docker Desktop suggestions such as Gordon as part of the Rails failure.

After checking out this identity baseline, recreate the primary development and test databases. Do not migrate a Party or membership database forward.

## Rails conventions

- Follow Rails 8.1 conventions and prefer framework capabilities already present.
- Use Active Record associations and validations for developer ergonomics, plus database constraints for durable invariants.
- Keep controllers focused on HTTP concerns.
- Put multi-record business workflows in clearly named service or command objects once controller/model callbacks would obscure transaction boundaries.
- Use transactions when an operation must update multiple durable facts atomically.
- Avoid callbacks for financial posting, payment application, or supplier commitment workflows.
- Normalize values at explicit boundaries. Do not use presentation formatting as normalization.
- Prevent N+1 queries on operational lists and dashboards.
- Use optimistic locking on mutable operational aggregates where concurrent edits matter.
- Prefer explicit enums or constrained string states whose values remain readable in SQL.
- Do not add gems when Rails or an existing dependency reasonably handles the need.
- `money-rails` is an explicitly accepted exception governed by ADR 0001; do not substitute a different money library without superseding that ADR.
- Do not use the countries gem as a currency authority.

## PostgreSQL and Active Record

- PostgreSQL 18 is authoritative. Do not reduce the design to cross-database compatibility.
- `config.active_record.schema_format` is `:sql`; commit updated `db/structure.sql` after migrations.
- The identity baseline does not enable `citext` or `pg_trgm`. Enforce workspace-code and email uniqueness on normalized text columns. `btree_gist` is enabled on the primary database only for the named Client Organization contact-history exclusion `client_org_contacts_no_overlapping_history`. Do not add other `btree_gist` uses, and do not enable that extension in the queue database. Do not enable `citext` or `pg_trgm` for directory work.
- Application-owned durable tables use UUID primary keys with database defaults of `uuidv7()`.
- When an ID is needed before persistence, assign UUIDv7 in Rails and retain the database default as a safety net.
- Every UUID foreign key must declare `type: :uuid` in its migration.
- Framework-owned tables such as Solid Queue internals may retain bigint identifiers. Active Storage is unused; do not add its tables.
- Rails operates timestamps in UTC; domain timestamps use PostgreSQL `timestamptz`.
- Store an agency’s display/business timezone as a recognized IANA timezone.
- Currency codes are uppercase three-character values.
- Store money in `bigint` integer minor-unit columns using the `_minor_units` suffix, with an explicit currency for every independently meaningful monetary fact.
- Never use floating-point columns for money, rates that post money, or allocations.
- Use decimal/numeric values only where fractional quantities or exchange rates require them, with explicit precision and scale.
- Add `null`, foreign-key, unique, check, and exclusion constraints as appropriate. Model validation alone is insufficient.
- Name important constraints and indexes so failures are diagnosable.

### Multiple databases

The application database and Solid Queue database are separate.

- Development primary: `departure_desk_development`.
- Development queue: `departure_desk_development_queue`.
- Production uses `DATABASE_URL` and `QUEUE_DATABASE_URL`.
- Development must configure `config.solid_queue.connects_to = { database: { writing: :queue } }`.
- Do not put a single shared `DATABASE_URL` into the default development database anchor; that can redirect both named connections to one database.
- Queue structure belongs in `db/queue_structure.sql`.

Do not “fix” missing queue tables by adding Solid Queue tables to the primary domain schema. Confirm the active connection and initialize the queue database instead.

## Identifier policy

Application domain models currently inherit Rails-side UUIDv7 preassignment from `ApplicationRecord`. Before introducing or retaining any application-owned bigint model, resolve that mismatch explicitly. Never let a UUID default write into a bigint primary key.

For migrations:

```ruby
create_table :example_records,
 id: :uuid,
 default: -> { "uuidv7()" } do |table|
 # ...
end
```

For references:

```ruby
table.references :agency,
 null: false,
 type: :uuid,
 foreign_key: true
```

## Migration policy

- Inspect both migrations and `db/structure.sql` before changing persistence.
- Prefer a new forward migration once a migration has been shared or run outside a disposable local environment.
- The agency-identity baseline replaced the Party migrations. Do not stack drop-table migrations on that old schema.
- Never drop, reset, or recreate a database without stating exactly which database and data will be lost.
- Never edit generated structure SQL by hand to work around a migration problem.
- Verify migrations against both development and test databases.
- Preserve unrelated user data and existing worktree changes.

## Financial design

No posted money ledger exists in the shipped application. [M3C](docs/planning/m3c-cost-terms-and-forecasts.md) ships draft Supplier cost definitions with `bigint` minor-unit amounts and derived forecasts only. When later slices add client charges and supplier obligations, keep those facts distinct, store integer minor units, and do not persist functional-currency translations until ADR 0001 is amended. `money-rails` is a value-object layer only.

## Authentication and tenancy

- Authentication uses `AgencyUser`, `Session`, bcrypt, and a signed permanent session cookie.
- Tenant context is the session's agency user. `Current.session` is the authentication root. `Current.agency` comes from that user. Never establish tenancy from `params[:agency_id]`, headers, or extra cookies.
- `Current.office` is subordinate context. It is resolved, without writing the session, from a valid stored `office_id`, else the user's active default office, else nil. Never authorize from `params[:office_id]`, and do not persist or clear a session office selection on GET.
- Login and every authenticated request fail closed when the user or agency is not active. Do not reveal whether the workspace, email, password, user, or agency failed.
- Successful authentication redirects through the named root route; keep `root_url` available unless authentication behavior is intentionally changed.
- Do not expose whether an email address exists during password-reset flows.
- Never log plaintext passwords, tokens, payment credentials, or other sensitive information.
- The current seed credential is development-only and must not be printed.
- Administrator capabilities are permission checks on the agency user, not a property on a global user.
- Tenant administrators may edit the current agency profile, offices, and agency users. They may not create agencies or change agency lifecycle status from a tenant route.
- Invitation acceptance is the documented invitee exception: the invitee is the audit actor and is not yet an administrator until acceptance commits.
- Last-administrator mutations lock agency, then the affected user, then recheck.
- Agency provisioning and lifecycle are privileged commands (`ProvisionAgency`, `ChangeAgencyStatus`), not tenant-facing routes. System audit events require `actor_identifier` and must not invent a platform user. Command output may print identifiers only—never passwords or invitation tokens.
- Audit subjects are narrowly typed: an `Agency` subject must equal the event agency; an `AgencyUser`, `Office`, `Departure`, `SupplierArrangement`, `SupplierReservation`, `ServiceOffer`, or `Package` subject must belong to it. Unknown subject types raise.
- An office belongs to exactly one agency. Office access is not a role. Do not create affiliation rows. Human-readable office codes never authorize.
- Later office-owned records must carry a direct `agency_id` and enforce matching `(office_id, agency_id)` with a composite foreign key. Do not infer tenant ownership only through `office_id`.
- `AuditEvent::ACTIONS` and subject types are closed catalogs. Extend both in the same change that first writes a new supported action or subject. `AuditEvent#details` is not a document-version or snapshot store.
- Administrative mutations write append-only `AuditEvent` records in the same transaction. Audit events reject update and destroy in the application and in PostgreSQL.
- Business records must be loaded through `Current.agency`. Do not use a tenant `default_scope`.
- Action Cable identifies `current_agency_user` and `current_agency` from the session. It must not copy request `Current` onto a long-lived connection and must not persist `Current.office` on the connection.
- Jobs that need office scope accept an office identifier, reload the office through the agency, and re-check that it is an active office of that agency. Office context is not authorization.

## Tests

Every behavior change requires focused automated coverage at the lowest useful level and integration coverage for important workflows.

Run:

```bash
./dev/rails-docker bin/rails test
```

Also run system tests for browser-visible workflows when a browser is available. They run in GitHub CI. The local Docker image does not include Chrome, so `bin/ci` skips that step there. CI system tests remain required and blocking. `bin/rails tailwindcss:build` is a blocking step in the GitHub `test` and `system-test` jobs and in `bin/ci`.

Testing rules:

- Test database constraints as well as model validations for important invariants.
- Test cross-agency authorization whenever agency-scoped records are introduced. Other-agency identifiers return not found, not forbidden.
- Test successful, invalid, duplicate, and concurrent paths for identity workflows, including last-administrator protection.
- Fixtures must satisfy column limits and database constraints. Because Rails may load all fixtures before every test, one invalid fixture can break unrelated tests before assertions run.
- Avoid assertions tied only to CSS implementation details; assert accessible roles, labels, visible states, and outcomes.
- Do not weaken or delete a regression test merely to make a change pass.

## UI and design system

The canonical theme lives in `app/assets/tailwind/application.css`.

Brand meanings:

- Navy: structure and authority.
- Teal: movement, action, active, and selected states.
- Amber: waypoints, deadlines, focus, and guaranteed exposure.
- Red: destructive, invalid, cancelled, or overdue states.

Rules:

- Reuse `dd-` component classes and design tokens before creating one-off colors or spacing.
- Keep amber text dark; never use small white text on the logo amber.
- Amber is not the destructive color and is not the default active-navigation color.
- Never communicate status by color alone. Pair color with text and, when useful, an icon.
- Use visible horizontal separators in dense operational tables; avoid excessive vertical grid lines.
- Keep inputs neutral until interaction. Use teal for active interaction and amber for the keyboard focus ring.
- Maintain WCAG-conscious contrast and complete keyboard access.
- Keep the skip link and meaningful focus indicators functional.
- Disabled navigation placeholders must become real links only when corresponding authorized routes exist. Show Dashboard, Clients for `view_client_directory`, Suppliers for `view_supplier_directory`, Departures for `view_departures`, and Administration for administrators. Do not show Directory, Travelers, or Accounting navigation.
- Do not introduce an external font, icon library, or JavaScript UI framework without an explicit product decision.
- Administration page, panel, button, and field anatomy is defined in [docs/ui/interface-contract.md](docs/ui/interface-contract.md). Reuse that contract before adding presentation classes.

## Background jobs

- Use Active Job with Solid Queue.
- Jobs must be idempotent or guarded by durable idempotency keys when duplicate execution would cause harm.
- Pass record identifiers, not full Active Record objects or sensitive payloads.
- Re-load and authorize/scoped records inside the job. Never depend on `Current`.
- Define retry/discard behavior intentionally for supplier APIs, mail delivery, and financial workflows.
- Never rely on an in-memory job adapter for behavior that must survive a process restart.
- The first scheduled domain job is the M2B departed sweep. It reads the primary database and enqueues into the separate queue database with no spanning transaction. Delivery is at least once. Child jobs call `MarkDepartureDeparted` with `actor_kind: :system` and identifier `departures.mark_departed` only. Retry deadlock, serialization failure, and lock wait timeout at most five times, then fail visibly. Do not write a domain `AuditEvent` for job infrastructure failures. Queue name: `departures`.
- M3B scheduled capacity projection refresh uses queue name: `capacity`. Jobs pass Pool identifiers, reload through the Agency, and must not depend on `Current`.
- M3E.2 scheduled Deadline projection catch-up uses queue name: `deadlines`. Jobs pass occurrence identifiers, reload through the Agency, refresh derived due/overdue/warning only, and must not open commitments or invent domain events from elapsed time.

## Seeds and sample data

- Seeds must be idempotent.
- Development-only credentials and illustrative data must be guarded by `Rails.env.development?`.
- Never seed real traveler, client, payment, or supplier credential data.
- Do not reset a production password or mutate production financial facts from general-purpose seeds.
- Print identifiers and safe status information only; never print plaintext secrets.

## Change workflow

Before editing:

1. Read the relevant model, migration, schema, route, controller/view/job, and tests.
2. State whether the change affects current behavior or planned requirements.
3. Identify affected agency, office, agency-user, and later commercial boundaries.

While editing:

1. Keep changes narrowly scoped.
2. Preserve established terminology and design tokens.
3. Add database constraints and tests alongside domain persistence.
4. Avoid unrelated formatting churn.
5. Update documentation when commands, architecture, terminology, or shipped scope changes.

Before handing off:

1. Run targeted tests, then the full test suite.
2. Run the Tailwind build for CSS/view changes.
3. Confirm migrations and committed structure dumps agree.
4. Check worker boot for job/database changes.
5. Report what changed, what was verified, and any remaining risk or manual check.

## Prohibited shortcuts

Do not:

- Restore `User`, `AgencyMembership`, `Party`, or office assignment as access control.
- Treat office selection as authorization.
- Add Owner, Advisor, or external-collaborator roles.
- Reveal that a workspace or email exists in a generic authentication failure.
- Print a bootstrap password or activation token.
- Use `citext` for workspace or email uniqueness.
- Use floating point for money.
- Use `_cents` as the general persistence suffix; DepartureDesk uses `_minor_units` because supported currencies do not all have cents.
- Enable automatic currency conversion or use a current exchange-rate bank as historical accounting authority.
- Put Solid Queue domain tables in the primary database to mask a connection error.
- Add unused Active Storage tables.
- Commit generated Tailwind output, `.env` files, secrets, or real personal data.
- Run destructive database or Git commands without explicit authorization and a precise target.

When domain requirements conflict or a proposed shortcut changes financial meaning, stop and request a product decision rather than silently choosing a lossy model.
