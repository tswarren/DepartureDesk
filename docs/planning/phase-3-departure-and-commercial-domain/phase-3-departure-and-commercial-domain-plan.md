# Phase 3 — Departure and commercial domain

## Status

Proposed implementation plan. This document becomes the Phase 3 authority after review and approval. Slice plans may add implementation detail but must not reopen the locked domain boundaries without amending this document explicitly.

---

## 1. Objective

Phase 3 establishes the dated departure as DepartureDesk's operational, commercial, capacity, and financial boundary.

After Phase 3, an authorized agency team can:

- Plan and govern a dated departure, optionally beneath a reusable travel program.
- Record what the agency offers clients without confusing it with what suppliers provide.
- Open client trips for one primary client and one or more travelers.
- Assign travelers, financial responsibility, capacity, and supplier fulfillment independently.
- Record supplier arrangements, reservations, resources, commitments, and final costs.
- Post and settle client and supplier financial events without rewriting history.
- Distinguish agency-controlled cash from supplier-collected client funds.
- Track commission from expectation through earning and receipt.
- Measure projected and reconciled departure performance.
- Operate, reconcile, and close a departure through explicit lifecycle commands.

Phase 3 is a domain program, not one feature branch. It is delivered through slices 3A–3G on an integration branch.

---

## 2. Authority and terminology

Phase 3 extends, and does not supersede:

- The Phase 1 agency, membership, office, authorization, audit, money, time, and lifecycle contracts.
- ADR 0004 for human-readable references and numbering.
- The shipped Phase 2 agency-owned Party model, client and supplier roles, relationships, contact information, lifecycle, search, and duplicate handling.
- The Phase 2E merge policy. Executable merge is not shipped when this plan is written; Phase 3 must not describe or depend on it as shipped behavior.
- `docs/terminology.md` for travel program, departure, client trip, service component, supplier arrangement, traveler assignment, responsibility allocation, and related vocabulary.
- `docs/ui/interface-contract.md` and the adopted design system for interface behavior.

Use **departure**, not `group`, for the primary application record. Industry-specific labels such as group contract, group leader, and group air remain valid when qualified.

`AGENTS.md` is the repository contract and now uses **client trip**, **service component**, **payer**, **responsible client**, **responsibility allocation**, and qualified **resource occupancy assignment** consistently with `docs/terminology.md`. Payer and responsibility are separate entries. Do not ship Phase 3 models that restore `ClientReservation` or `TravelComponent` names.

---

## 3. Locked domain boundaries

### 3.1 Departure is the operating boundary

- A travel program is an optional reusable concept or series.
- A departure is one dated occurrence of coordinated travel.
- Lifecycle, office ownership, client trips, supplier arrangements, capacity, operational reporting, departure financial reporting, reconciliation, and closeout belong to the departure.
- A program does not own operational balances, capacity, or settlement state.

### 3.2 Client trip has one primary client

- Every client trip has exactly one primary client Party with an active client role at creation.
- A client trip may serve multiple travelers.
- Additional responsible clients are represented by charge responsibility allocations.
- A payer is the source of a payment and need not be the primary client, a responsible client, or a traveler.
- Separate client trips may be linked as traveling companions and may share supplier resources without merging accounts or private records.

### 3.3 Packages are optional offers

- A package is a client-facing offer, not a supplier contract.
- A package component is a template; a service component is the instantiated client-trip service.
- A client trip may contain package-derived and standalone service components.
- Selection snapshots the applicable offer version, pricing, inclusions, exclusions, schedule, and client terms.
- Later offer edits do not rewrite an existing client trip.
- Packages are departure-owned. A travel program may own reusable package templates, but using a template copies or materializes a new departure-owned package; there is no live inheritance into a departure or accepted client trip.

### 3.4 Four independent allocation axes

For a service component, preserve independently:

1. Traveler assignment — who receives the service.
2. Responsibility allocation — who owes for the related charge.
3. Inventory allocation — which capacity is held.
4. Fulfillment allocation — which supplier reservation, resource, or agency service provides it.

No one relationship automatically implies another.

### 3.5 Supplier hierarchy remains explicit

- A supplier is the contracting commercial Party.
- A service provider is the operating property, vessel, carrier, venue, or entity when different.
- A supplier arrangement is the umbrella contract, block, reservation, policy, charter, or commitment.
- A supplier reservation is a specific requested or confirmed booking and may be a child of an arrangement.
- A supplier resource is a capacity-bearing or shareable unit.
- Fulfillment allocation is many-to-many and may be date-, segment-, or quantity-specific.

### 3.6 Capacity is not commitment

Track available, blocked or allotted, guaranteed, soft allocated, firm allocated, supplier-confirmed, waitlisted, released, and used quantities distinctly.

Capacity records operational availability. Supplier commitments and obligations record financial exposure. A capacity change does not create, remove, or revise a financial commitment unless an explicit command and applicable supplier term say it does.

### 3.7 DepartureDesk is an operational subledger

DepartureDesk owns client, supplier, cash, commission, settlement, margin, and export provenance needed to operate and reconcile a departure. It does not become a complete general ledger, bank-reconciliation system, payroll system, tax-return system, or agency-wide ARC/BSP reconciliation system.

### 3.8 Historical integrity

- Draft and forecast facts may be edited, with version history where materially useful.
- Accepted terms and externally submitted facts are snapshotted.
- Posted financial events are immutable.
- Later changes use amendments, applications, adjustments, credits, or reversals.
- Cancellation preserves both the original sale and the independent supplier consequence.
- Party edits and any later executable merge do not rewrite historical snapshots or posted financial identities.

### 3.9 Internal team assignments and external Party roles are separate

- Departure-responsible advisors, group managers, or other internal assignees reference `AgencyMembership` through a dedicated internal-team assignment concept.
- Organizer, group leader, sponsor, and other external or contextual participants reference agency-owned `Party` records through a separate Party-role concept.
- Do not use one polymorphic row with nullable `agency_membership_id` and `party_id` to represent both systems.
- These assignments provide attribution and workflow ownership. They never grant posting, refund, close, or other authorization.
- `ClientAdvisorAssignment` remains the client's general advisor assignment. A departure or client-trip advisor is contextual. 3A does not read, copy, default from, update, or otherwise use `ClientAdvisorAssignment`. Slice 3C owns client-trip advisor defaulting and its relationship to client and departure advisors.

### 3.10 Office ownership does not partition Party identity

- A departure and its office-owned operational or financial records carry `agency_id`, `office_id`, and a tenant-safe composite office foreign key where applicable.
- Staff access is checked against the actor membership's current accessible offices after locking; `Current.office` is a default or navigation context, never an authorization grant.
- Directory and Party selectors remain `Current.agency` scoped and agency-wide. Do not filter clients, travelers, suppliers, organizers, payers, or service providers by the departure office.

### 3.11 Every Party foreign key declares lifecycle and merge participation

- Do not use a live state-bearing `party_status = 'active'` projection on historical trip or financial records.
- Commands revalidate that a Party and required active role are eligible when establishing a new operational relationship; the durable record keeps an ordinary same-agency Party foreign key plus any required historical snapshot.
- Every slice that adds a Party foreign key must register or specify its participation in `PartyDeactivationDependencies` and the Phase 2E fail-closed merge-participant contract before that slice is complete.
- If executable merge infrastructure has not shipped, amend the Phase 2E participant catalog and require merge to remain blocked for that reference until its participant exists. Do not guess, cascade, or silently repoint.
- Each reference must state whether it is historical, current operational state, or an active role dependency and whether deactivation blocks, requires disposition, or is permitted.

### 3.12 External operational identifiers are not directory identifiers

Supplier confirmation numbers, PNRs, ticket numbers, policy numbers, and similar arrangement/reservation identifiers belong to their operational owner with issuer and context provenance. They do not use or expand Phase 2C `ExternalIdentifier`, whose ownership remains Party/client-profile/supplier-profile and whose `office_id` remains blank.

### 3.13 Audit and snapshots have different jobs

- `AuditEvent` records an authorized action and its affected aggregate; it is not a document-version or snapshot store.
- Accepted offer versions, client terms, supplier terms, traveler submissions, confirmations, and financial posting evidence use typed or purpose-specific persistence.
- Every slice extends the closed `AuditEvent::ACTIONS` and `RecordAdministrativeAudit` subject catalogs in the same change that first writes a new supported action or subject.
- Do not make every capacity event, allocation, or snapshot row an administrative-audit subject. Audit the meaningful command aggregate and reference affected child identities in structured details when appropriate.
- If financial posting requires a domain event trail distinct from administrative audit, 3E must specify it explicitly rather than weakening the closed administrative catalog.

### 3.14 One amendment identity coordinates one business change

A client upgrade, downgrade, addition, removal, promotion, surcharge, concession, traveler change, resource move, or cancellation uses one `ClientTripAmendment` identity. The amendment may acquire operational, capacity, fulfillment, supplier, and financial consequences as later slices ship. Do not create separate operational and pricing amendment histories for the same business change.

### 3.15 Occupancy is a qualified resource assignment

Resource occupancy is a traveler-to-resource fact with applicable service dates or segments and status. It belongs within the traveler-assignment axis but is not inferred from a traveling-party or companion relationship. It never establishes household, insurance eligibility, client ownership, payer, or responsibility.

---

## 4. Aggregate map

```text
TravelProgram (optional)
├── PackageTemplate (optional reusable source)
└── Departure
    ├── DepartureTeamAssignment → AgencyMembership
    ├── DeparturePartyRoleAssignment → Party
    ├── Package / PackageVersion
    │   ├── PackageComponent
    │   └── PackageOption
    ├── ClientTrip
    │   ├── ClientTripTraveler
    │   ├── ServiceComponent
    │   │   ├── TravelerAssignment
    │   │   ├── InventoryAllocation
    │   │   └── FulfillmentAllocation
    │   ├── ClientTripAmendment
    │   └── Client financial records
    ├── TravelingParty
    ├── SupplierArrangement
    │   ├── SupplierReservation
    │   ├── SupplierResource
    │   ├── CapacityPosition / CapacityEvent
    │   ├── CostEstimate / Commitment
    │   └── Supplier financial records
    ├── OperationalDeadline / Task / Document
    └── Reconciliation / Closeout
```

Names in this map describe responsibilities, not final table names. Each slice plan must specify exact persistence and database guarantees.

---

## 5. Financial contract reserved by all slices

### 5.1 Subledgers

Phase 3 must preserve four distinct financial views:

1. Client accounts receivable — charges, credits, responsibility, receipts, supplier collections, refunds, applications, and unapplied funds.
2. Agency-controlled cash — actual agency receipts, refunds, supplier payments, supplier refunds, commission receipts, chargebacks, and attributable fees.
3. Supplier accounts payable and cost — obligations, adjustments, credits, payments, refunds, penalties, and final cost.
4. Commission and settlement — expected, earned, receivable, retained, received, adjusted, recalled, or written-off commission.

Planning estimates do not post balances.

### 5.2 Typed posting architecture

- Domain-specific typed financial records are authoritative. Design `ClientCharge`, `ClientReceipt`, `SupplierCollection`, `ClientRefund`, `SupplierObligation`, `SupplierPayment`, commission, reversal, and application persistence before introducing shared posting infrastructure.
- A shared append-only projection, posting index, or outbox is permitted only when 3E demonstrates a concrete need. It must be derived or rebuildable infrastructure, not the monetary source of truth.
- A shared structure must not use a type discriminator plus nullable domain columns to become the generic ledger this plan forbids.
- Use explicit application records to connect payments, credits, refunds, or collections to charges and obligations.
- Authoritative balances are derived from typed posted records and applications.
- Cached summaries must be rebuildable and must never become independent financial truth.
- Posting, numbering, and reversal commands are transactional and idempotent.
- Do not introduce one generic polymorphic `transactions` table with unrelated nullable fields.

### 5.3 Finalization and amendments

- Quotes do not create receivables.
- Client acceptance alone does not silently post a charge.
- An explicit agency command finalizes an accepted and complete charge.
- Posted economic fields cannot be edited.
- Upgrades, downgrades, promotions, surcharges, concessions, cancellations, and responsibility changes use the one linked `ClientTripAmendment` identity established in 3D.
- A genuine posting error uses reversal and corrected posting, not a business concession.

### 5.4 Principal and agent treatment

Each financially meaningful service or charge line identifies whether the agency acts as principal, agent, pass-through intermediary, or direct service provider.

Supplier-collected client money may satisfy a client balance but never increases agency-controlled cash. Gross client value, confirmed client sales, agency revenue, and cash received remain separate measures.

### 5.5 Currency

- ADR 0001 remains authoritative until amended. Agency `default_currency` is a data-entry and reporting default, not an implicit currency for stored facts.
- A departure has a default currency but does not overwrite transaction currencies.
- Before 3E persists functional-currency translations, amend ADR 0001 to define agency reporting/functional currency semantics, native and functional amounts, rate direction, precision and scale, effective date, source, rate type, rounding boundary and remainder allocation, posting immutability, settlement differences, and explicit conversion events.
- After that amendment, every posted foreign-currency fact preserves the approved native and functional values and exchange-rate provenance. Operational rows must not persist speculative functional amounts in 3A–3D.
- Applications normally require matching currency.
- Conversion is explicit; realized exchange differences are recorded separately.
- Periodic unrealized revaluation is deferred.

---

## 6. Delivery structure and branch policy

Use a Phase 3 integration branch:

```text
main
└── phase-3-departure-and-commercial-domain
    ├── phase-3a-departure-foundation
    ├── phase-3b-supplier-planning-capacity
    ├── phase-3c-offers-client-trips
    ├── phase-3d-assignments-fulfillment-amendments
    ├── phase-3e-client-financials
    ├── phase-3f-supplier-financials-profitability
    └── phase-3g-operations-reconciliation-closeout
```

- Create the integration branch from the current passing `main`.
- Slice PRs target the integration branch.
- Each slice must be independently reviewable and leave its own surface coherent.
- Merge the integration branch to `main` only after the Phase 3 exit gate.
- Rebase or merge forward between slices when a later slice depends on unmerged earlier work; do not duplicate domain models across branches.
- A slice plan must list any intentional temporary states and the exact later slice that removes them.

---

## 7. Slice 3A — Departure foundation

### Objective

Create the stable dated operating root that every later Phase 3 record references.

### Deliverables

- Phase 3 authority documents and the required `AGENTS.md` terminology/invariant amendment before domain models are named.
- `TravelProgram` with agency ownership and lifecycle appropriate to a reusable concept.
- `Departure` with agency, owning office, optional program, default transaction-entry currency, dates, destination, description, sales window, and lifecycle. Do not persist functional-currency amounts in 3A.
- Separate internal departure team assignments to `AgencyMembership` and contextual departure Party-role assignments to `Party`.
- 3A does not use `ClientAdvisorAssignment`. Slice 3C owns the relationship among client, departure, and client-trip advisors. No duplicate advisor identity.
- Explicit lifecycle commands. Persist only `draft`, `planning`, and `cancelled` until later slices add statuses.
- State-bearing owning-office projection on nonterminal departures.
- Staff-visible program-linked departure data filtered by office access.
- Human-readable `departure_reference` decision under ADR 0004.
- Agency tenancy and office-owned departure authorization; agency-wide Party lookup remains unchanged.
- Departure index, create, detail, edit, and lifecycle surfaces using the adopted interface contract.
- Audit coverage, optimistic locking, and tenant-safe composite foreign keys.

### Required decisions in the slice plan

Resolved in `phase-3a-departure-foundation.md`:

- Departure reference scope, format, issuance event, reuse rule, and concurrency strategy.
- One-day departures use required start and end dates with `end_date >= start_date`.
- 3A fields remain editable while `draft` or `planning`; later slices freeze fields once sale, operation, or posted children exist.
- A program cannot become inactive while it has a nonterminal departure.
- Merge/deactivation participation for organizer, group leader, and sponsor, including the 2E catalog registration for `departure_party_role_assignments.party_id`.
- Command lock-order appendix for ordinary Phase 3A commands. Existing membership and office lifecycle commands retain their shipped outer lock orders and use non-locking departure dependency helpers.

### Exclusions

- Packages, client trips, supplier arrangements, capacity, charges, receipts, and profitability.
- Generic configurable reference engines.
- Automatic recurrence generation.

### Gate

An authorized user can create and operate a dated departure root without using ambiguous group ownership or bypassing office access rules.

---

## 8. Slice 3B — Supplier planning, capacity, and commitments

Slice plan: [`phase-3b-supplier-planning-capacity.md`](phase-3b-supplier-planning-capacity.md) (**Shipped through 3B.6**). That document locks arrangement vs reservation, typed cost-term tables, economic-item precedence, deposit-as-requirement, dimensional capacity events with rebuildable positions, agency-provided-service deferral, and the office-transfer freeze rule.

### Objective

Represent what the agency requests, holds, guarantees, or purchases from suppliers before client fulfillment is added.

### Deliverables

- Supplier arrangements with supplier and optional distinct service provider.
- Parent/child arrangement hierarchy with cycle prevention.
- Supplier reservations and resources.
- Arrangement- or reservation-owned confirmation records or qualified fields with issuer/context provenance; do not reuse Phase 2C `ExternalIdentifier`.
- Service dates and date/segment-aware resource availability.
- Cost estimates, contracted terms, commitments, deposits, deadlines, guarantees, releases, attrition, and cancellation terms.
- Capacity events or equivalent rebuildable positions.
- Fixed, per-resource, per-person, per-night, minimum-guarantee, tiered, stepped-capacity, percentage, complimentary-ratio, pass-through, and manual-estimate term shapes without forcing every service into one formula.
- Supplier planning, arrangement detail, capacity, deadline, and exposure surfaces.
- Forecast cost and exposure projections; no posted supplier payable yet.
- Merge/deactivation participation for supplier, service-provider, and contact Party references.
- Freeze `TransferDepartureOffice` once any supplier arrangement has ever existed on the departure (concrete rule in the 3B slice plan). Aggregate-wide ownership transfer remains deferred.
- Audit catalog additions and a 3B command lock-order appendix.

### Required invariants

- Arrangement supplier belongs to the departure agency and has an active supplier profile when selected.
- Parent and child arrangements share agency and departure.
- Capacity never becomes negative through ordinary commands.
- Released capacity is not available unless release terms and supplier state permit it.
- Estimates, commitments, and final costs are never added together for the same economic item.
- External supplier identifiers remain separate from DepartureDesk references.
- Supplier confirmation records do not violate the ownership or `office_id` contract of directory `ExternalIdentifier`.

### Gate

The Napa scenario can model a 30-seat fixed-cost coach with a second stepped resource, and the Smith scenario can model a cruise agreement, guaranteed cabins, hotel block nights, and on-request extensions without creating client trips.

---

## 9. Slice 3C — Offers, client trips, and service components

### Objective

Represent what the agency offers and sells to a primary client without yet posting money.

### Deliverables

- Optional program-level package templates and explicit copy/materialization into new departure-owned package versions. Templates never become live parents of departure packages or accepted services.
- Packages, package versions, package components, and package options.
- Per-person, per-resource, per-household, occupancy/category, and flat client pricing structures.
- Sales dates, eligibility, capacity limits, deposit/final-payment schedule templates, inclusions, exclusions, and client terms.
- Client trips with one primary client and departure-scoped reference.
- Client-trip travelers referencing person Parties.
- Traveling parties and coordination/share purposes without financial-account merging.
- Service components created from accepted package versions or added independently.
- Quote/version and acceptance evidence sufficient for later financial finalization.
- Client-facing price and terms snapshots.
- Purpose-specific snapshot records; do not store accepted pricing or terms only in `AuditEvent#details`.
- Merge/deactivation participation for primary client, travelers, coordinators, and every other Party reference.
- Audit catalog additions and a 3C command lock-order appendix.
- Client-trip, offer, roster, and service-component surfaces.

### Required decisions in the slice plan

- Client-trip reference specification under ADR 0004.
- Quote versioning, expiration, acceptance evidence, and agency approval states.
- Minimum facts required before a service component can be accepted.
- Whether a package selection remains linked to its source version after instantiation; prefer retain immutable provenance plus copied effective terms.

### Required invariants

- Primary client belongs to the agency and has an active client profile at creation.
- Travelers are person Parties in the same agency.
- Package and client trip belong to the same departure.
- Accepted services retain their price, currency, and terms even if the offer changes later.
- A traveler is not automatically a payer or responsible client.

### Gate

Both worked scenarios can represent package and standalone services, multiple travelers, separate client trips sharing travel arrangements, and accepted client pricing without supplier or financial shortcuts.

---

## 10. Slice 3D — Assignments, fulfillment, and amendments

### Objective

Connect client-facing services to travelers, capacity, and supplier fulfillment while preserving independent meanings.

### Deliverables

- Traveler assignments to service components and qualified resource-occupancy assignments to supplier resources for applicable dates or segments.
- Soft and firm inventory allocations with expiry, confirmation, release, and waitlist behavior.
- Many-to-many fulfillment allocations between service components and supplier reservations/resources.
- Date-, night-, segment-, and quantity-scoped fulfillment.
- Requested, quoted, awaiting-approval, submitted, confirmed, declined, unable-to-confirm, cancelled, and delivered outcomes as appropriate to the owning record.
- One `ClientTripAmendment` framework for upgrades, downgrades, additions, removals, promotions, surcharges, concessions, traveler changes, resource moves, and cancellations. It is the durable identity to which later financial consequences attach.
- Atomic commands that coordinate service, assignment, capacity, and fulfillment consequences.
- Confirmation snapshots and audit history.
- Purpose-specific confirmation snapshot persistence; audit details may reference but may not replace it.
- Merge/deactivation participation for every Party reference and audit catalog additions.
- A 3D command lock-order appendix, including atomic amendment commands spanning Party, client trip, service, capacity, supplier fulfillment, and snapshot records.

### Required invariants

- Assignment does not create responsibility.
- Fulfillment does not establish client price.
- Client cancellation does not silently cancel supplier fulfillment or remove supplier exposure.
- Internal capacity release and supplier-accepted release are distinct facts.
- One supplier resource may serve travelers from multiple client trips.
- One client service may be fulfilled by multiple supplier records.
- Traveling-party membership does not create or imply resource occupancy; occupancy does not imply household, insurance, payer, or responsibility.

### Gate

The Smith scenario can place travelers from separate client trips in one cabin, preserve separate insurance-household eligibility, and split a hotel stay across blocked and on-request nights. The Napa scenario can warn before a confirmed allocation activates a second coach.

---

## 11. Slice 3E — Client financial subledger

### Objective

Post what responsible clients owe and record how agency or supplier collections satisfy those balances.

### Deliverables

- A physical-design decision record proving that typed financial tables are authoritative. Any optional shared posting projection, index, or outbox is rebuildable and cannot own monetary meaning.
- Departure-scoped client accounts by responsible client and currency.
- Client charges and charge lines.
- Line-level responsibility allocations with whole-charge convenience behavior.
- Explicit finalization command and client charge reference decision.
- Payment schedules and installments that do not themselves create receivables.
- Agency receipts, receipt numbers, receipt applications, and unapplied funds.
- Supplier collections and applications that reduce client balances without entering agency cash.
- Client credits, refunds, chargebacks, transfers, write-offs, reversals, and correction workflow.
- Financial effects attached to the existing `ClientTripAmendment` for upgrade, downgrade, promotion, surcharge, goodwill, cancellation, and supplier-penalty recovery; do not introduce a second pricing-amendment aggregate.
- One receipt per agency, receiving office, payer, departure, and currency; applications may span eligible client trips within that departure.
- ADR 0001 amendment before functional-currency posting, followed by foreign-currency posting snapshots and the explicit conversion boundary it authorizes.
- Statements, balances, aging/due views, receipt documents, and posting previews.
- Merge/deactivation participation for responsible clients, payers, refund recipients, and every other Party reference. Historical posted records keep ordinary same-agency Party FKs and identity snapshots; they do not hold live active-role projections.
- Purpose-specific financial snapshots rather than audit-detail JSON storage.
- Audit/event catalog design appropriate to financial postings and a 3E command lock-order appendix.

### Required invariants

- A quote or payment schedule is never a receivable.
- Responsibility allocations equal the finalized charge amount.
- Applications plus unapplied amount equal the posted receipt or supplier collection.
- Applications cannot exceed source availability or target balance.
- Supplier collections never increase agency-controlled cash.
- Posted financial events are not edited or deleted.
- A reversal references and neutralizes a posted event without erasing it.
- Posting and reference issuance are atomic and idempotent.
- Any shared financial projection can be rebuilt from typed postings and applications and cannot replace them as authority.

### Gate

The system can produce a reproducible statement and balance for each responsible client, including split responsibility, third-party payment, supplier collection, upgrade, downgrade, promotion, cancellation fee, supplier-penalty recovery, refund, and unapplied funds.

---

## 12. Slice 3F — Supplier financials, commission, and profitability

### Objective

Post supplier obligations and settlements, track agency earnings, and calculate departure cash and margin without double-counting.

### Deliverables

- Supplier accounts by supplier, departure, and currency.
- Supplier obligations generated only by explicit contractual or operational events.
- Obligation adjustments, final-invoice reconciliation, supplier credits, penalties, and refunds.
- Supplier payments, references, applications, unapplied amounts, and reversals.
- Expected, earned, receivable, retained, received, reversed, and written-off commission states/events.
- Contract-configurable commission earning triggers.
- Principal, agent, pass-through, and agency-service classifications at the financial line level.
- Processor fees and other attributable departure expenses as separate events.
- Estimated, committed, and final cost precedence.
- Gross client value, confirmed client sales, agency revenue, cash received, supplier-collected amount, supplier cost, commission, cash position, exposure, projected margin, confirmed margin, and reconciled departure margin.
- Event-level accounting export provenance and an initial summarized export contract; no vendor-specific integration required.
- Merge/deactivation participation for suppliers, service providers, commission counterparties, payment recipients, and every other Party reference.
- Audit/event catalog additions and a 3F command lock-order appendix.

### Required invariants

- A final invoice reconciles an existing obligation; it is not added again as a second cost.
- Supplier payments settle obligations but do not create additional cost.
- Expected commission is not earned commission.
- Earned commission is not commission received.
- Supplier-collected gross value is not agency-controlled cash.
- Principal/agent treatment controls reporting classification without rewriting source events.
- Accounting exports can be reproduced and reversed from immutable source events.

### Gate

Both worked scenarios reconcile from current operational facts to explainable client sales, agency cash, supplier balances, commission receivables, exposure, and margin without manual spreadsheet adjustments.

---

## 13. Slice 3G — Operations, reconciliation, and closeout

### Objective

Complete the operational workflow and establish an auditable departure-close boundary.

### Deliverables

- Operational deadlines attached to departure, arrangement, client trip, traveler, or service component.
- Required and optional tasks with ownership and completion evidence.
- Operational document requirements and ordinary attachment relationships without duplicating Party identity. Phase 3G does not store passport images, visas, payment credentials, medical records, or other sensitive identity documents without a separate approved access, encryption, audit, retention, and deletion contract.
- Manifest, rooming, assignment, final-count, and exception views from authoritative records.
- Service delivery, unused, no-show, disruption, and final-disposition commands.
- Reconciliation workspace for client, supplier, commission, capacity, and cost exceptions.
- Closeout blocker and warning evaluation.
- `completed`, `reconciliation`, and `closed` boundaries.
- Authorized close, reopen, correction, and re-close commands.
- Final closeout report and audit evidence.
- Merge/deactivation participation for task owners, operational contacts, and every other Party reference; audit catalog additions; and a 3G command lock-order appendix.

### Close blockers

At minimum, closing is blocked by:

- Unbalanced responsibility allocations.
- Draft financial changes awaiting disposition.
- Unapplied client funds or unresolved refunds/chargebacks.
- Client balances without an approved write-off, transfer, or exception disposition.
- Unapplied supplier payments or credits.
- Unreconciled supplier obligations, invoices, credits, or refunds.
- Cost items still using estimates where final cost is required.
- Supplier reservations, capacity commitments, or guaranteed inventory without final disposition.
- Required operational tasks or documents still unresolved.
- Active/requested/waitlisted services lacking final disposition.

Expected future commission may remain a warning. Earned commission receivable must be settled, written off, or transferred to an agency-level follow-up queue before close.

### Gate

An authorized manager can move a completed departure through reconciliation, understand every blocker and warning, close it with an auditable certification, and later reopen it only through a controlled reasoned command.

---

## 14. Cross-cutting implementation requirements

Every slice must include, as applicable:

- Explicit agency ownership on persisted tenant records.
- Tenant-safe composite foreign keys and named database constraints.
- No reliance on tenant `default_scope` or controller-supplied agency IDs.
- Office-owned operational authorization independent of references or `Current.office`; staff access is revalidated against current membership office access.
- Agency-wide `Current.agency` Party lookup. Office ownership never partitions the Directory or Party selectors.
- A Party-reference matrix listing each new Party FK, its same-agency enforcement, required snapshot, eligibility check at establishment, merge participation, and deactivation dependency behavior.
- Registration with `PartyDeactivationDependencies` and the Phase 2E fail-closed merge-participant contract for every applicable Party FK; an unregistered reference blocks merge rather than being silently repointed.
- UUIDv7 internal identity.
- Integer minor-unit monetary storage; no floating-point money.
- `timestamptz` timestamps and explicit business/effective dates.
- Optimistic locking for mutable records.
- Transactional command objects for consequential state changes.
- Stable actor membership, subject, agency, source, before/after or event payload, and reason in audit events. Extend the closed `AuditEvent::ACTIONS` and `RecordAdministrativeAudit` subject catalogs in the same change that first writes each supported action or subject.
- Purpose-specific version and snapshot storage. Audit `details` may identify or summarize a snapshot but is never its authoritative store.
- Idempotency for posting, payment, reference issuance, imports, and retryable external callbacks.
- Database enforcement of same-agency and same-departure relationships wherever practical.
- No silent profile, package, supplier-term, price, cost, assignment, or financial-history rewrite.
- Accessible server-rendered workflows with Turbo/Stimulus enhancement rather than JavaScript-only correctness.
- Clear empty, loading, conflict, stale-write, authorization, and validation states.

### 14.1 Required command lock-order appendix

Every slice plan must include a lock-order appendix that:

- Lists the canonical order for every multi-record command.
- Identifies the outer command that owns the transaction and locks.
- Provides explicitly named locked primitives for nested work where needed.
- Revalidates agency, office access, Party eligibility, role state, lifecycle, and last-known state after locks are acquired.
- Locks unordered collections in stable UUID order.
- Prevents nested public commands from reacquiring earlier locks or using a conflicting order.
- Preserves existing command-specific contracts, including membership/activation and directory/role-profile lock orders, rather than inventing one universal Phase 3 order.
- Includes concurrency tests for commands that mix Party, membership, office, operational, allocation, and financial records.

A slice may refine a predecessor's documented order only through an explicit reviewed amendment and corresponding concurrency tests.

---

## 15. Testing contract

### Model and database tests

- Tenant and typed-party foreign keys.
- Same-departure relationship constraints.
- Lifecycle consistency and transition rejection.
- Hierarchy cycle prevention.
- Capacity non-negativity and allocation bounds.
- Monetary currency matching and integer-minor-unit behavior.
- Immutable posting and reversal linkage.
- Allocation/application balancing.
- Reference uniqueness, issuance, retry, and cross-agency reuse.
- Optimistic-lock conflicts.
- Party merge/deactivation registration and fail-closed behavior for every new Party FK.
- Historical Party references survive later Party or role deactivation without a live state-bearing projection.
- Operational confirmation identifiers remain separate from directory external identifiers.

### Command/service tests

- Every consequential command succeeds atomically or leaves no partial effects.
- Retrying an idempotent command returns the existing result.
- Amendments create all required operational and financial consequences together.
- Cancellation keeps client and supplier consequences independent.
- Estimate, commitment, final cost, and payment do not double-count.
- Supplier collection satisfies the correct client balance without affecting agency cash.
- Concurrent commands follow the slice lock-order appendix and do not partially apply nested work.

### Authorization and request tests

- Agency and office access for every new route and command.
- Cross-agency UUID and human-reference access returns no disclosure.
- Unauthorized posting, refund, payment, concession, reversal, close, and reopen are rejected.
- Stale and invalid transitions return useful domain errors rather than generic failures.
- Party selectors remain agency-wide while departure-owned records enforce current office access.

### System tests

- Keyboard and focus behavior for core create, confirmation, amendment, payment, and reconciliation workflows.
- Display-first detail surfaces and explicit edit modes.
- Responsive tables and disclosures for dense operational records.
- Money, currency, status, warning, and destructive-action presentation.
- Confirmation previews show operational, client, supplier, capacity, cash, and margin consequences before posting.

### Scenario tests

Maintain two named end-to-end fixtures or builders throughout the program:

1. **Smith Family Reunion Cruise — July 12, 2027**
   - Shared cabin across separate client trips.
   - Household-scoped insurance.
   - Guaranteed hotel block plus on-request extension nights.
   - Agency- and supplier-collected money.
   - Upgrade, cancellation, supplier penalty, agency fee, and commission.

2. **Napa Wine Country Tour — October 10, 2027**
   - One fixed-cost 30-seat motorcoach and stepped second-coach threshold.
   - Per-person vineyard cost.
   - Packaged client price.
   - Enrollment-driven break-even and effective cost.
   - Final count, supplier reconciliation, and closeout.

Each slice gate must demonstrate its part of both scenarios rather than introducing unrelated toy fixtures as the only integration proof.

---

## 16. Migration and rollout policy

- Prefer additive migrations and staged constraint validation.
- Add columns nullable only when needed for backfill; enforce the final invariant before the slice is complete.
- Do not ship normal application states that depend on future backfills unless the slice plan identifies and tests the temporary state.
- New financial tables must be correct from their first production write; do not plan to reinterpret posted events later.
- Do not generate synthetic historical financial postings from operational rows without an explicit migration and reconciliation policy.
- Seed/demo data may exercise the two worked scenarios but must not weaken production constraints.
- Feature flags may hide incomplete interfaces, but persisted domain invariants cannot depend on a flag.

---

## 17. Explicit Phase 3 non-goals

- Full general-ledger accounting or financial-statement preparation.
- Bank-account reconciliation.
- Agency-wide accounts payable unrelated to departures.
- Payroll and advisor commission payroll.
- Tax-return preparation or a general jurisdictional tax engine.
- Full ARC/BSP settlement-period reconciliation.
- Automated supplier contracting or legal interpretation of cancellation terms.
- Automatic client or supplier cancellation consequences without review.
- Automatic package repricing of accepted client trips.
- Implicit cross-currency applications.
- Automatic merging of client trips, households, traveling parties, or financial accounts.
- Rewriting historical snapshots after Party merge.
- Complete passport, visa, medical, or sensitive-travel-document management unless separately authorized and designed.
- Vendor-specific accounting, GDS, cruise, hotel, insurance, or payment-processor integrations.

Air reservations, tickets, insurance-policy specialization, detailed hotel-night operations, and integration adapters should be built as vertical extensions after their common Phase 3 foundations exist. Phase 3 must preserve the required extension points and exercise representative records, but must not bury service-specific schemas inside the generic core.

---

## 18. Documentation deliverables

Before or alongside implementation, maintain:

- Keep `AGENTS.md` aligned with this plan's canonical language and invariants.
- Phase 3 aggregate and relationship map.
- Lifecycle and command-transition matrix.
- Typed financial-record, application, reversal, projection/outbox, and classification decision record.
- Capacity versus commitment glossary.
- Snapshot and retention matrix.
- Party-reference merge/deactivation participation matrix.
- Internal membership-assignment versus external Party-role matrix.
- Per-slice audit action/subject catalog changes.
- Per-slice command lock-order appendix.
- Principal/agent and money-custody decision record.
- ADR 0001 amendment before functional-currency posting.
- Human-readable reference specifications introduced by each slice.
- Authorization matrix.
- Closeout blocker/warning matrix.
- Worked Smith and Napa scenario ledgers from quote through close.

When code and an approved Phase 3 contract disagree, stop and amend the authority deliberately; do not let incidental implementation become the new contract.

---

## 19. Phase 3 exit criteria

Phase 3 is complete only when:

1. The dated departure is the stable operating root across all Phase 3 domains.
2. Programs, departures, client trips, supplier arrangements, reservations, resources, packages, and service components retain their distinct meanings.
3. Traveler, responsibility, inventory, and fulfillment allocations operate independently.
4. Accepted prices and terms remain historically reproducible.
5. Client and supplier balances rebuild from immutable posted events and applications.
6. Supplier-collected funds never appear as agency cash.
7. Estimates, commitments, final costs, obligations, payments, and commission stages do not double-count.
8. Upgrades, downgrades, promotions, cancellations, penalties, concessions, refunds, and corrections preserve the original history.
9. Projected and reconciled cash, exposure, and margin are explainable from source records.
10. Office access, agency tenancy, references, audit, lifecycle, currency, and optimistic concurrency conform to Foundation authority.
11. Both named worked scenarios pass end-to-end operational and financial tests.
12. A departure can be reconciled, closed, reopened, corrected, and re-closed through authorized, auditable commands.
13. The full automated test suite and CI pass on the canonical Ruby and PostgreSQL versions.
14. Internal team assignments reference memberships, contextual participant roles reference Parties, and neither grants authorization.
15. Every Phase 3 Party FK has documented and tested same-agency, snapshot, merge, and deactivation behavior.
16. Typed domain financial records remain authoritative; any shared projection, index, or outbox is rebuildable and does not become a discriminator-based generic ledger.
17. One client-trip amendment identity connects each business change to all resulting operational and financial consequences.
18. Resource occupancy is explicit and never inferred from traveling-party, household, insurance, payer, or responsibility relationships.

---

## 20. Planning gate before Phase 3A

Before coding 3A, reviewers must approve:

- This parent plan and its non-goals.
- Confirmation that `AGENTS.md` uses client-trip / service-component language and splits payer from responsibility.
- Departure and travel-program lifecycle vocabulary.
- The aggregate map and independent allocation axes.
- The separation of internal membership assignments from contextual Party roles, with both remaining non-authorizing.
- The agency-wide Directory rule alongside office-owned departure authorization.
- The Phase 2E status correction and the required fail-closed merge/deactivation participation process for every new Party FK.
- Departure reference scope and issuance proposal.
- Phase 3 branch policy.
- The Smith and Napa scenario facts used as acceptance fixtures.
- The rule that later slice plans may add detail but may not collapse or bypass the reserved financial and fulfillment architecture.

Before 3E coding, reviewers must additionally approve:

- The typed financial source-of-truth physical design and any narrowly justified projection or outbox.
- The single amendment identity's operational-to-financial extension.
- The ADR 0001 amendment authorizing functional-currency posting and exchange-rate provenance.
- Financial audit/event boundaries and the 3E lock-order appendix.

Once the Phase 3A gate is met, 3A may proceed without blocking on detailed supplier formulas, accounting mappings, air schemas, insurance rules, the later 3E approvals, or final closeout implementation.
