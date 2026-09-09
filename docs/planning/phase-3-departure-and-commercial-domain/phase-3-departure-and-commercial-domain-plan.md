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
- The Phase 2 agency-owned Party model, client and supplier roles, relationships, contact information, lifecycle, duplicate handling, and merge semantics.
- `docs/terminology.md` for travel program, departure, client trip, service component, supplier arrangement, traveler assignment, responsibility allocation, and related vocabulary.
- `docs/ui/interface-contract.md` and the adopted design system for interface behavior.

Use **departure**, not `group`, for the primary application record. Industry-specific labels such as group contract, group leader, and group air remain valid when qualified.

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
- Party edits and merges do not rewrite historical snapshots or posted financial identities.

---

## 4. Aggregate map

```text
TravelProgram (optional)
└── Departure
    ├── DeparturePartyRole
    ├── Package / PackageVersion
    │   ├── PackageComponent
    │   └── PackageOption
    ├── ClientTrip
    │   ├── ClientTripTraveler
    │   ├── ServiceComponent
    │   │   ├── TravelerAssignment
    │   │   ├── InventoryAllocation
    │   │   └── FulfillmentAllocation
    │   ├── Amendment
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

### 5.2 Shared posting architecture

- Use domain-specific financial records backed by a shared immutable financial-event registry.
- Use explicit application records to connect payments, credits, refunds, or collections to charges and obligations.
- Authoritative balances are derived from posted events and applications.
- Cached summaries must be rebuildable and must never become independent financial truth.
- Posting, numbering, and reversal commands are transactional and idempotent.
- Do not introduce one generic polymorphic `transactions` table with unrelated nullable fields.

### 5.3 Finalization and amendments

- Quotes do not create receivables.
- Client acceptance alone does not silently post a charge.
- An explicit agency command finalizes an accepted and complete charge.
- Posted economic fields cannot be edited.
- Upgrades, downgrades, promotions, surcharges, concessions, cancellations, and responsibility changes use linked amendments.
- A genuine posting error uses reversal and corrected posting, not a business concession.

### 5.4 Principal and agent treatment

Each financially meaningful service or charge line identifies whether the agency acts as principal, agent, pass-through intermediary, or direct service provider.

Supplier-collected client money may satisfy a client balance but never increases agency-controlled cash. Gross client value, confirmed client sales, agency revenue, and cash received remain separate measures.

### 5.5 Currency

- Agency functional currency remains authoritative for agency reporting.
- A departure has a default currency but does not overwrite transaction currencies.
- Every posted foreign-currency event preserves native amount and currency, functional amount and currency, locked exchange rate, rate direction, effective date, source, rate type, and rounding result.
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

- Phase 3 authority documents and ADR amendments.
- `TravelProgram` with agency ownership and lifecycle appropriate to a reusable concept.
- `Departure` with agency, owning office, optional program, functional/default currency context, dates, destination, description, sales window, and lifecycle.
- Departure team/party roles for responsible advisor, group manager, organizer, and group leader without duplicating Party identity.
- Explicit lifecycle commands and transition policy.
- Human-readable `departure_reference` decision under ADR 0004.
- Agency- and office-scoped authorization.
- Departure index, create, detail, edit, and lifecycle surfaces using the adopted interface contract.
- Audit coverage, optimistic locking, and tenant-safe composite foreign keys.

### Required decisions in the slice plan

- Departure reference scope, format, issuance event, reuse rule, and concurrency strategy.
- Whether one-day departures use the same start/end date or permit a null end date; prefer required start and end dates with `end_date >= start_date`.
- Which fields remain editable after sales open and after operation begins.
- Whether a program may be deactivated while it has active departures; prefer restrict with dependency explanation.

### Exclusions

- Packages, client trips, supplier arrangements, capacity, charges, receipts, and profitability.
- Generic configurable reference engines.
- Automatic recurrence generation.

### Gate

An authorized user can create and operate a dated departure root without using ambiguous group ownership or bypassing office access rules.

---

## 8. Slice 3B — Supplier planning, capacity, and commitments

### Objective

Represent what the agency requests, holds, guarantees, or purchases from suppliers before client fulfillment is added.

### Deliverables

- Supplier arrangements with supplier and optional distinct service provider.
- Parent/child arrangement hierarchy with cycle prevention.
- Supplier reservations and resources.
- External confirmation identifiers with issuer/context provenance.
- Service dates and date/segment-aware resource availability.
- Cost estimates, contracted terms, commitments, deposits, deadlines, guarantees, releases, attrition, and cancellation terms.
- Capacity events or equivalent rebuildable positions.
- Fixed, per-resource, per-person, per-night, minimum-guarantee, tiered, stepped-capacity, percentage, complimentary-ratio, pass-through, and manual-estimate term shapes without forcing every service into one formula.
- Supplier planning, arrangement detail, capacity, deadline, and exposure surfaces.
- Forecast cost and exposure projections; no posted supplier payable yet.

### Required invariants

- Arrangement supplier belongs to the departure agency and has an active supplier profile when selected.
- Parent and child arrangements share agency and departure.
- Capacity never becomes negative through ordinary commands.
- Released capacity is not available unless release terms and supplier state permit it.
- Estimates, commitments, and final costs are never added together for the same economic item.
- External supplier identifiers remain separate from DepartureDesk references.

### Gate

The Napa scenario can model a 30-seat fixed-cost coach with a second stepped resource, and the Smith scenario can model a cruise agreement, guaranteed cabins, hotel block nights, and on-request extensions without creating client trips.

---

## 9. Slice 3C — Offers, client trips, and service components

### Objective

Represent what the agency offers and sells to a primary client without yet posting money.

### Deliverables

- Packages, package versions, package components, and package options.
- Per-person, per-resource, per-household, occupancy/category, and flat client pricing structures.
- Sales dates, eligibility, capacity limits, deposit/final-payment schedule templates, inclusions, exclusions, and client terms.
- Client trips with one primary client and departure-scoped reference.
- Client-trip travelers referencing person Parties.
- Traveling parties and coordination/share purposes without financial-account merging.
- Service components created from accepted package versions or added independently.
- Quote/version and acceptance evidence sufficient for later financial finalization.
- Client-facing price and terms snapshots.
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

- Traveler assignments to service components and supplier resources.
- Soft and firm inventory allocations with expiry, confirmation, release, and waitlist behavior.
- Many-to-many fulfillment allocations between service components and supplier reservations/resources.
- Date-, night-, segment-, and quantity-scoped fulfillment.
- Requested, quoted, awaiting-approval, submitted, confirmed, declined, unable-to-confirm, cancelled, and delivered outcomes as appropriate to the owning record.
- Operational amendment framework for upgrades, downgrades, additions, removals, traveler changes, resource moves, and cancellations.
- Atomic commands that coordinate service, assignment, capacity, and fulfillment consequences.
- Confirmation snapshots and audit history.

### Required invariants

- Assignment does not create responsibility.
- Fulfillment does not establish client price.
- Client cancellation does not silently cancel supplier fulfillment or remove supplier exposure.
- Internal capacity release and supplier-accepted release are distinct facts.
- One supplier resource may serve travelers from multiple client trips.
- One client service may be fulfilled by multiple supplier records.

### Gate

The Smith scenario can place travelers from separate client trips in one cabin, preserve separate insurance-household eligibility, and split a hotel stay across blocked and on-request nights. The Napa scenario can warn before a confirmed allocation activates a second coach.

---

## 11. Slice 3E — Client financial subledger

### Objective

Post what responsible clients owe and record how agency or supplier collections satisfy those balances.

### Deliverables

- Shared immutable financial-event registry.
- Departure-scoped client accounts by responsible client and currency.
- Client charges and charge lines.
- Line-level responsibility allocations with whole-charge convenience behavior.
- Explicit finalization command and client charge reference decision.
- Payment schedules and installments that do not themselves create receivables.
- Agency receipts, receipt numbers, receipt applications, and unapplied funds.
- Supplier collections and applications that reduce client balances without entering agency cash.
- Client credits, refunds, chargebacks, transfers, write-offs, reversals, and correction workflow.
- Client pricing amendments for upgrade, downgrade, promotion, surcharge, goodwill, cancellation, and supplier-penalty recovery.
- One receipt per agency, receiving office, payer, departure, and currency; applications may span eligible client trips within that departure.
- Foreign-currency posting snapshots and explicit conversion boundary.
- Statements, balances, aging/due views, receipt documents, and posting previews.

### Required invariants

- A quote or payment schedule is never a receivable.
- Responsibility allocations equal the finalized charge amount.
- Applications plus unapplied amount equal the posted receipt or supplier collection.
- Applications cannot exceed source availability or target balance.
- Supplier collections never increase agency-controlled cash.
- Posted financial events are not edited or deleted.
- A reversal references and neutralizes a posted event without erasing it.
- Posting and reference issuance are atomic and idempotent.

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
- Document requirements and attachment relationships without duplicating Party identity.
- Manifest, rooming, assignment, final-count, and exception views from authoritative records.
- Service delivery, unused, no-show, disruption, and final-disposition commands.
- Reconciliation workspace for client, supplier, commission, capacity, and cost exceptions.
- Closeout blocker and warning evaluation.
- `completed`, `reconciliation`, and `closed` boundaries.
- Authorized close, reopen, correction, and re-close commands.
- Final closeout report and audit evidence.

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
- Office-scope authorization independent of references.
- UUIDv7 internal identity.
- Integer minor-unit monetary storage; no floating-point money.
- `timestamptz` timestamps and explicit business/effective dates.
- Optimistic locking for mutable records.
- Transactional command objects for consequential state changes.
- Stable actor membership, subject, agency, source, before/after or event payload, and reason in audit events.
- Idempotency for posting, payment, reference issuance, imports, and retryable external callbacks.
- Database enforcement of same-agency and same-departure relationships wherever practical.
- No silent profile, package, supplier-term, price, cost, assignment, or financial-history rewrite.
- Accessible server-rendered workflows with Turbo/Stimulus enhancement rather than JavaScript-only correctness.
- Clear empty, loading, conflict, stale-write, authorization, and validation states.

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

### Command/service tests

- Every consequential command succeeds atomically or leaves no partial effects.
- Retrying an idempotent command returns the existing result.
- Amendments create all required operational and financial consequences together.
- Cancellation keeps client and supplier consequences independent.
- Estimate, commitment, final cost, and payment do not double-count.
- Supplier collection satisfies the correct client balance without affecting agency cash.

### Authorization and request tests

- Agency and office access for every new route and command.
- Cross-agency UUID and human-reference access returns no disclosure.
- Unauthorized posting, refund, payment, concession, reversal, close, and reopen are rejected.
- Stale and invalid transitions return useful domain errors rather than generic failures.

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

- Phase 3 aggregate and relationship map.
- Lifecycle and command-transition matrix.
- Financial event and classification catalog.
- Capacity versus commitment glossary.
- Snapshot and retention matrix.
- Principal/agent and money-custody decision record.
- Foreign-currency posting decision record.
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

---

## 20. Planning gate before Phase 3A

Before coding 3A, reviewers must approve:

- This parent plan and its non-goals.
- Departure and travel-program lifecycle vocabulary.
- The aggregate map and independent allocation axes.
- Departure reference scope and issuance proposal.
- Phase 3 branch policy.
- The Smith and Napa scenario facts used as acceptance fixtures.
- The rule that later slice plans may add detail but may not collapse or bypass the reserved financial and fulfillment architecture.

Once this gate is met, 3A may proceed without blocking on detailed supplier formulas, accounting mappings, air schemas, insurance rules, or final closeout implementation.
