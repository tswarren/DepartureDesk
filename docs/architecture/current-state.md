# Current application architecture

**Status:** Implemented baseline

**Scope:** Current application; later commercial domains are excluded

DepartureDesk ships agency identity, administration, the complete M1 Client and Supplier directories (M1A-M1E), M2A Departure draft, activation, reference issuance, return to draft, and search, M2B departed transitions, scheduled departed jobs, and schedule/currency/lifecycle corrections, M2C proof and hardening, M3A draft Supplier Arrangement structure under Departures, M3B draft Supplier capacity configuration plus the capacity event/projection/reconciliation engine, M3C draft Supplier cost terms plus derived forecasts, and M3D.0 guided workspace compression over M3A–M3C. M2 is complete. [M3D](../planning/m3d-activation-reservations-confirmations.md) is shipped. Arrangement activation, Staff-facing effective capacity controls, Reservations, confirmations, and confirmation-triggered commitment openings are shipped. [M3D.7](../planning/m3d7-activated-definition-immutability.md) freezes exact-version definition graphs in Rails and PostgreSQL once an Arrangement version leaves draft. [M3D.8](../planning/m3d8-activation-reservation-product-quality.md) remediates activation and Reservation product-quality (forms, error recovery, progressive disclosure, composers, bounded lists, table overflow). [M3D.9](../planning/m3d9-reservation-integrity.md) remediates Reservation integrity (confirmed quantity-basis fidelity, successor revision/request revalidation, Capacity Pool definition membership, and event↔outcome compatibility). [M3E](../planning/m3e-supplier-operational-control.md) and [ADR 0013](../adr/0013-supplier-operational-commitments-deadlines-exposure-and-ending.md) are shipped through M3E.7b (including M3E.5R and M3D remediations): source-shaped openings and dispositions, Deadlines, Deposit Requirements and planning milestones, qualified exposure, Needs attention, and Arrangement ending. M3E is fully shipped and production-ready. [M4A](../planning/m4a-service-definitions-and-sources.md) and [M4B](../planning/m4b-client-pricing-and-anonymous-preview.md) are shipped. [M4C](../planning/m4c-packages-choices-and-client-terms.md) is shipped. Later commercial records are not shipped. The MVP and commercial decision register describe future product behavior; they are not claims about current persistence or routes.

## Shipped records and authorization catalog

| Record | Current responsibility |
| --- | --- |
| `Agency` | Tenant, workspace-code identity, lifecycle, locale defaults, and ownership root. |
| `Office` | Agency-owned operating and reporting context. It grants no permission. |
| `AgencyUser` | One agency-scoped login account with independent credentials, lifecycle, and access role. |
| `Session` | Authentication root and optional current-Office preference. It derives Agency through AgencyUser. |
| `AuditEvent` | Append-only evidence for supported Agency, AgencyUser, Office, ClientPerson, Client, ClientOrganization, Supplier, SupplierLocation, SupplierContact, Departure, SupplierArrangement, SupplierReservation, ServiceOffer, and Package commands. |
| `ClientPerson` | Agency-scoped person known to the directory. Not a Client, AgencyUser, or Traveler. |
| `ClientOrganization` | Agency-scoped organization known to the directory. Not a Supplier. |
| `Client` | Explicit commercial identity for exactly one Client Person or Client Organization, with an immutable `CL-` reference. |
| `ClientPersonEmailAddress`, `ClientPersonPhoneNumber`, `ClientPersonPostalAddress` | Person-owned contact points. They are not Agency User credentials. |
| `ClientOrganizationEmailAddress`, `ClientOrganizationPhoneNumber`, `ClientOrganizationPostalAddress`, `ClientOrganizationWebsite` | Organization-owned contact points. |
| `ClientOrganizationContact` | Effective-dated assignment of a Client Person to a Client Organization. Current means `ends_on IS NULL`. |
| `Supplier` | Agency-scoped organization or individual contracting identity, with an immutable `SUP-` reference and fixed category assignments. |
| `SupplierCategoryAssignment` | Required category membership for a Supplier. At least one category; `other_label` only for `other`. |
| `SupplierEmailAddress`, `SupplierPhoneNumber`, `SupplierPostalAddress`, `SupplierWebsite` | Supplier-owned contact points. |
| `SupplierLocation` | Supplier-owned operational place with optional structured address, timezone, and one location-level phone. |
| `SupplierContact` | Named person in one Supplier work context. Not a Client Person or AgencyUser. |
| `SupplierContactEmailAddress`, `SupplierContactPhoneNumber` | Contact-owned destinations. |
| `Departure` | Agency-owned dated operational root. M2A implements draft, activation, `D-` issuance, return to draft, and search. M2B adds departed, scheduled departed jobs, and corrections. M2C proves search, isolation, jobs, and accessibility. Travel Program is not implemented. |
| `SupplierArrangement`, `SupplierArrangementVersion` | M3A draft Supplier planning root under one Departure, with a stable Arrangement identity and initial draft version. Versions are not activated yet. |
| `ArrangementItem`, `ArrangementItemDefinition` | Stable Item identity plus draft-version definition for name, category, description, default service provider, ordering, and M3B `capacity_management` applicability. |
| `ArrangementItemSetupResult` | Narrow M3D.0 idempotency association from one guided Item setup key to its exact Item and optional first Occurrence and Resource; composite ownership foreign keys constrain both children to that Item and Agency. |
| `ServiceOccurrence`, `ServiceOccurrenceDefinition` | Stable planned Occurrence identity plus draft-version definition for date range, optional local times, time zone, description, and optional service provider. |
| `SupplierResource`, `SupplierResourceDefinition` | Stable Resource identity plus draft-version definition for name, description, and item-local ordering. |
| `CapacityPairDefinition` | Exact-version Occurrence–Resource classification as `pooled` or `not_applicable` for a managed Item. |
| `CapacityPool`, `CapacityPoolDefinition` | Stable Pool identity plus draft-version label, evidence, proposed opening quantity, inventory mode, measurement basis, and supplying Supplier. |
| `CapacityEvent` | Append-only Supplier-side capacity ledger facts. Proven in services/tests; Staff UI ships with M3D. |
| `CapacityProjection` | Rebuildable **Current Supplier capacity** projection for numeric Pools. |
| `CapacityReconciliation`, `CapacityReconciliationResolution` | Observed quantity versus ledger comparison and append-only resolution. Staff surfaces ship with M3D. |
| `SupplierCostSource` | Exact-version economic identity for one Supplier cost, Arrangement-wide or Item-scoped, with an explicit charging Supplier. |
| `SupplierCostDefinition` | Editable estimate or contracted definition (`working` / `forecast_ready`) with currency equal to Departure `operating_currency`. First ADR 0001 monetary-table pattern. |
| `SupplierCostComponent`, `SupplierCostComponentBase` | Ordered typed components with economic role separate from calculation kind, plus explicit percentage-base links. |
| `SupplierCostParticipantCategory` | Exact-version Item-scoped planning labels used by components and occupancy profiles. |
| `SupplierCostUsageAssumption` | Lightweight exact Item-context planning quantities. Not Client demand. |
| `SupplierCostOccupancyProfile`, `SupplierCostOccupancyProfilePosition` | Anonymous occupancy profiles and category positions for occupancy-shaped components. |
| `AgencyCommandIdempotencyKey` | Agency-scoped replay guard for idempotent M3A create commands, M3B Pool create / capacity event / reconciliation commands, M3C cost create commands, M4A Service Offer create/binding commands, M4B price-definition create commands, and M4C Package create/inline/adopt/price commands, keyed by command name, client idempotency key, and payload digest. |
| `ServiceOffer`, `ServiceOfferVersion` | M4A unpublished Client-offer identity under one Departure, with numbered versions. M4A uses `draft` and `abandoned`; `published`/`superseded`/`retired` are reserved for M4D. No generated reference and no identity-level sellability flag. |
| `ServiceOfferDefinition` | Version-owned Client title, description, and fulfillment basis (`m3_backed`, `on_request`, `agency_fulfilled`, `externally_fulfilled`). Mutable only while the offer version is draft. |
| `ServiceOfferSourceBinding` | Exact M3 source pin (Arrangement/Item plus optional Occurrence, Resource, and Pool) with required/alternative/`choice_gated` topology, dependency flags, and Client-text provenance. |
| `ServiceOfferPriceDefinition` | Version-owned unpublished Client price (`calculated` or `zero_price`) in Departure `operating_currency`. One definition per offer version. |
| `ServiceOfferPriceComponent`, `ServiceOfferPriceComponentBase` | Ordered typed Client price components plus explicit percentage-base links to earlier rounded components in the same definition. |
| `Package`, `PackageVersion` | M4C unpublished Package identity under one Departure, with numbered versions. M4C uses `draft` and `abandoned`; `published`/`superseded`/`retired` are reserved for M4D. Package-only ownership is `owning_package_version_id` on a Service Offer version. |
| `PackageInclusion` | Exact Service Offer version pin with `included`/`optional` placement and origin `inline_create` / `adopted_draft` / `published_reusable`. |
| `PackagePriceDefinition`, `PackagePriceComponent`, `PackagePriceComponentBase` | Version-owned unpublished Package price (`bundled` or `service_sum`) in Departure `operating_currency`. Bundled `P` is an unscoped per-person graph; optional `s` is a one-person supplement. |
| `ServiceOfferChoiceGroup`, `ServiceOfferChoiceOption`, `ServiceOfferChoiceOptionSourceActivation` | Version-owned Client choice templates and same-version source activations. |
| `PackageClientPaymentSchedule`, `PackageClientCancellationPolicy`, `PackageClientStatedCondition`, `PackageClientTermResolution` | Named Client term records on a Package version. Preview discloses them; they do not invoice. |
| `ReferenceSequence` | Agency-scoped `client`, `supplier`, and `departure` reference counters. Issuance does not create a missing row. |
| `AccessPermission` module | Closed permission catalog mapping administrator, staff, and viewer roles to capabilities. It is application code, not a persisted record. |

Invitation and password-reset token facts are stored on `AgencyUser`; they are not separate identity records.

## Tenancy and authentication

- `Agency` is the sole tenant boundary.
- Sign-in resolves normalized workspace code before the agency-scoped normalized email.
- The same email in two agencies represents two independent AgencyUsers with separate passwords and sessions.
- `Current.session` is the authentication root; `Current.agency` comes only from its AgencyUser.
- Request parameters never establish Agency tenancy.
- A foreign-Agency identifier returns not found through an Agency-scoped lookup.
- Every authenticated request rechecks that both Agency and AgencyUser are active.

## Office context

Office is operational context, not authorization. `Current.office` resolves from an active same-Agency Office stored on the Session, then the AgencyUser's active default Office, then `nil`. Changing Office changes no permission. An Agency may have no active Offices.

## Current permissions

| Permission | Administrator | Staff | Viewer |
| --- | ---: | ---: | ---: |
| View workspace | Yes | Yes | Yes |
| Select current Office | Yes | Yes | Yes |
| Manage Agency profile | Yes | No | No |
| Manage Offices | Yes | No | No |
| Manage AgencyUsers | Yes | No | No |
| View Client directory | Yes | Yes | Yes |
| View Client contact details | Yes | Yes | No |
| Manage Client directory | Yes | Yes | No |
| View Supplier directory | Yes | Yes | Yes |
| View Supplier contact details | Yes | Yes | No |
| Manage Supplier directory | Yes | Yes | No |
| View Departures | Yes | Yes | Yes |
| Manage Departures | Yes | Yes | No |
| Force inactivate Supplier with dependencies | Yes | No | No |
| Override Supplier planning terms | Yes | No | No |

Application code checks named permissions, not role strings.

## Persistence and command boundaries

- Application records use PostgreSQL 18 UUIDv7 identifiers and `timestamptz` timestamps.
- The primary database and Solid Queue database are separate. The M2B departed sweep reads the primary database and enqueues child jobs into the queue database with no spanning transaction. Delivery is at least once. Queue name: `departures`. M3B scheduled capacity projection refresh uses queue name: `capacity`.
- Database constraints and triggers protect normalized identity values, same-Agency references, append-only audits, and immutable tenant identifiers.
- `btree_gist` is enabled on the primary database only for `client_org_contacts_no_overlapping_history`.
- Consequential multi-record changes use explicit commands, transactions, lock ordering, and same-transaction audit events.
- M3A create commands, M3B Pool create / capacity event / reconciliation commands, M3C cost create commands, M3D.0 composite Item setup, bulk capacity, classify-with-Pool, and initial-cost setup commands, M4A Service Offer create/binding commands, M4B price-definition create commands, and M4C Package create/inline/adopt/price commands use `AgencyCommandIdempotencyKey` plus transaction-scoped advisory locks so duplicate submissions replay the original result instead of creating duplicate records.
- Last-active-administrator protection locks Agency, then AgencyUser, then rechecks current state.

## Not shipped

The current application has no Traveler, Household, Travel Program, Client Trip, posted financial ledger, document, platform-support, or MFA records. Directory tables do not store `office_id`. No universal `Party`, global `User`, `AgencyMembership`, or Office-based authorization layer may be restored. Shipped M3A records are draft planning structure only. Shipped M3B capacity includes draft configuration UI and the engine; effective Supplier capacity and Staff event/reconciliation surfaces ship with M3D. Shipped M3C cost includes draft sources, definitions, components, assumptions, and derived forecasts; effective contracted terms begin at Arrangement activation under shipped M3D. Forecast totals are not persisted. Shipped M3D.0 compresses those existing draft workflows and introduces no M3D domain record. Shipped M3E.1–M3E.7b add source-shaped commitments and dispositions, Deadlines, deposits/milestones, qualified exposure, Needs attention, and Arrangement ending. M3E is fully shipped. Shipped M3F closes milestone acceptance and hardening; **M3 is complete.** Client demand, Obligations, Payments, remittance, and FX remain unimplemented. Celebrity deposits/milestones remain Arrangement-wide; `per_source` Deadlines remain deferred. The [M4 parent](../planning/m4-offers-and-pricing.md), [ADR 0014](../adr/0014-client-offers-publication-and-supply-compatibility.md), and [M4.0](../planning/m40-task-flow-and-contract.md) are accepted and are not implementation authority for later slices. [M4A](../planning/m4a-service-definitions-and-sources.md) ships unpublished Service Offer drafts, exact M3 source bindings, and the narrow compatibility evaluator. [M4B](../planning/m4b-client-pricing-and-anonymous-preview.md) ships unpublished Client prices, the anonymous calculator, and optional indicative scenario economics. [M4C](../planning/m4c-packages-choices-and-client-terms.md) ships unpublished Package drafts, package-only version ownership, choices, Client terms, and Package-owned prices. [M4D](../planning/m4d-publication-and-live-feasibility.md) is Accepted (publication, Sales enabled, and live feasibility) and is not shipped. The current application has no published offer or M5 records. M4E remains unimplemented.

See [ADR 0005](../adr/0005-agency-identity.md) for the complete implemented identity contract and [the roadmap](../planning/roadmap.md) for planned sequencing.
