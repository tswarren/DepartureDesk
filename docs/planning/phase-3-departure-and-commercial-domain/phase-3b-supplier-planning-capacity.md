# Phase 3B — Supplier planning, capacity, and commitments

## Status

**Shipped through 3B.6.** This revision incorporates the pre-acceptance remediation (term/commitment split, capacity transition matrix, capacity dimensions, parent-cancellation rule, authorization matrix, and related tightenings). Slices 3B.1–3B.6 are implemented, including the supplier-planning workspace, Smith/Napa scenario gates, and the §18 exit gate.

This plan is subordinate to:

- `AGENTS.md`
- `docs/adr/0001-money-and-currency.md`
- `docs/adr/0002-agency-tenancy-and-membership.md`
- `docs/adr/0004-human-readable-references.md`
- `docs/terminology.md`
- `docs/ui/interface-contract.md`
- `docs/planning/phase-3-departure-and-commercial-domain/phase-3-departure-and-commercial-domain-plan.md`
- `docs/planning/phase-3-departure-and-commercial-domain/phase-3a-departure-foundation.md`
- `docs/planning/phase-2-party-and-supplier-directory/phase-2e-party-merge.md`

The parent Phase 3 plan controls if this slice plan becomes stale. Do not silently change the parent contract through implementation convenience.

---

## 1. Objective

Represent what the agency requests, holds, guarantees, or purchases from suppliers before client fulfillment is added.

After 3B:

- An authorized user can create supplier arrangements under a nonterminal departure, with optional parent/child commercial hierarchy.
- Supplier reservations and resources exist as distinct records under arrangements.
- Confirmation identifiers belong to arrangements or reservations with issuer/context provenance (not Phase 2C `ExternalIdentifier`).
- Cost terms cover the full parent shape catalog through a shared envelope and typed shape tables.
- Commitments are separate commercial records from cost terms.
- Deposits and deadlines are supplier **requirements**, not payments or settlement state.
- Capacity changes are immutable typed events with a command-maintained, rebuildable position projection defined by a locked transition matrix.
- Forecast cost and guarantee exposure are explainable per currency without posting supplier payables.
- Creating the first arrangement permanently freezes simple office transfer for that departure.
- Party deactivation and Phase 2E merge participation fail closed for every new Party FK.

3B does not create packages, client trips, service components, inventory/fulfillment allocations, traveler occupancy, agency-provided services, posted supplier obligations or payments, final billed costs, functional-currency amounts, or aggregate office transfer.

---

## 2. Locked 3B decisions

### 2.1 Process

- Contract-first: this document must be Accepted before 3B domain code.
- Implementation ships as reviewable slices **3B.1–3B.6** in the dependency order in section 16. Do not deliver the entire 3B roadmap in one PR.

### 2.2 Arrangement, reservation, and resource

| Concept | Contract |
| --- | --- |
| `SupplierArrangement` | Commercial envelope: contract, group block, allotment, charter, policy program, or on-request purchasing relationship. |
| `SupplierReservation` | Supplier-facing request or confirmation made **under** an arrangement. |
| `SupplierResource` | Capacity-bearing or shareable unit (cabin category, room type, coach seats, etc.). |
| Parent/child arrangements | Nested **commercial** agreements only—not individual fulfillment bookings. |
| Same booking twice | Forbidden: never represent one supplier booking as both a child arrangement and a reservation. |

Examples:

| Scenario | Arrangement | Reservation | Resource |
| --- | --- | --- | --- |
| Cruise | Group cruise agreement | Cabin booking | Cabin/category inventory |
| Hotel | Room-block agreement | Individual room booking | Room/night inventory |
| Coach | Coach contract | Vehicle confirmation, if separately issued | Coach/seat capacity |
| Insurance | Supplier/product agreement | Household policy | Usually no reserved capacity |

A reservation may reference one or more resources. A reservation is not itself a resource.

### 2.3 Agency-provided services

- Exclude agency-provided services from `SupplierArrangement` in 3B.
- Defer them to a later agency-service model.
- Do not represent the operating agency as a Party with a supplier profile for this purpose.
- Do not allow a nullable supplier or `agency_provided` arrangement type that weakens the active-supplier invariant.

### 2.4 Office ownership and transfer freeze

- Every 3B office-owned child carries direct `agency_id` and `office_id`.
- `departures` exposes a unique key on `(id, agency_id, office_id)`.
- Every arrangement FK to its departure uses `(departure_id, agency_id, office_id)`.
- Arrangement, reservation, resource, confirmation, cost-term, deposit-requirement, deadline, commitment, capacity-event, and capacity-position rows that are office-owned repeat `(agency_id, office_id)` and use composite FKs that prove they share the departure’s office.
- A same-agency departure FK plus an independent office FK is insufficient.

`TransferDepartureOffice` (3A) remains available only while **no** `supplier_arrangements` row has ever existed for the departure.

| Departure state | Office transfer |
| --- | --- |
| No supplier arrangements have ever existed | Allowed under existing 3A rules |
| At least one arrangement exists or existed | Prohibited |
| Future need to reorganize ownership | Separate explicit aggregate-transfer design (not 3B) |

- Creating the first arrangement permanently freezes transfer—even if every arrangement is later cancelled or released—because children and audit retain original office ownership.
- Shared lock boundary for `CreateSupplierArrangement` (first child) and `TransferDepartureOffice`:

```text
agency → old/new offices by UUID → departure → arrangement dependencies
```

- After locks and reload: create establishes the child under the departure’s current office; transfer rejects if **any** arrangement row exists (not merely active).
- A concurrency test proves simultaneous transfer and first-arrangement creation cannot produce mixed ownership.
- UI may hide or disable transfer once supplier planning exists; the command remains authoritative.
- Aggregate-wide ownership transfer is deferred. Posted financial records must never be moved by changing office IDs.

### 2.5 Party eligibility and historical FKs

- Contracting supplier Party must belong to the departure agency and have an **active** supplier profile at establishment.
- Service-provider Party, when present, must be an **active** same-agency Party at establishment; it is not a second identity type.
- Confirmation issuer must be an eligible same-agency Party when the confirmation is recorded; the issuer may become inactive later without invalidating historical confirmations.
- Supplier contacts and guarantors must be **active** same-agency Parties when assigned.
- No live `party_status = 'active'` projection on historical arrangement, reservation, confirmation, or term Party FKs.
- Establishment commands revalidate eligibility; durable rows keep ordinary same-agency Party FKs plus required snapshots.
- **Current operational dependency** for deactivation includes every nonterminal arrangement status, including `draft`. Draft arrangements that reference a Party block that Party’s deactivation.

### 2.6 Capacity is not commitment

- Capacity records operational availability.
- Commitments and guarantee exposure record financial/commercial exposure.
- Recording a cancellation, release, or attrition **clause** does not itself change capacity or commitments.
- A command applies a clause, previews consequences, and explicitly creates resulting capacity events and/or commitment records.
- Capacity changes do not silently create, remove, or revise financial commitments.

### 2.7 Cost terms vs commitments (no shared `committed` stage)

Cost terms and commitments are separate authorities.

| Concern | Cost term | Commitment |
| --- | --- | --- |
| Purpose | Pricing / evaluation basis for an economic item | Explicit commercial control of exposure |
| Basis | `estimate` or `contracted` only | References a governing active term evaluation |
| Lifecycle | `draft`, `active`, `superseded`, `void` | `open`, `released`, `satisfied`, `superseded`, `cancelled` |
| Mutability | Draft editable; active immutable; changes supersede | Immutable after open except via explicit lifecycle commands / superseding commitment |

An estimate becoming contracted creates a **new term version**; it does not mutate the existing term’s basis in place.

Reporting precedence (one controlling valuation per economic item; never sum stages):

1. Active **estimate** evaluation when no active contracted term exists for the item.
2. Active **contracted** term evaluation when no open commitment controls the item.
3. Explicit **commitment** valuation when a commitment controls exposure.
4. **Final cost** in 3F supersedes forecast stages for actual-cost reporting.

Do **not** persist final cost or supplier payable records in 3B. Do **not** use `committed` as a cost-term basis or stage.

### 2.8 Economic-item identity

Every term, evaluation, and commitment carries or derives a stable economic-item identity from:

- Arrangement
- Reservation or resource scope (nullable only when the item is arrangement-wide)
- Service occurrence (night slice or typed service segment) when the item is occurrence-scoped
- Cost category
- Quantity basis
- Currency
- Applicable term version / effective period

Prefer a **derived canonical key** from those dimensions. Persist a durable opaque economic-item UUID when supersession chains need a stable surrogate; do not use a free-form string that can drift from the dimensions.

### 2.9 Deposits are requirements

In 3B a deposit is a supplier **requirement**, not a payment.

Persist on the requirement: required amount or calculation rule, due rule, refundability, application to final balance, trigger/commitment condition, currency, supplier-term provenance.

Do not persist `paid`, `refunded`, cash account, or settlement state. Those are 3F supplier financial events.

Completing or waiving a related deadline does **not** mark a deposit paid.

### 2.10 Deadlines reference their source

- The deposit requirement or commercial clause owns the commercial due rule.
- `SupplierDeadline` is an occurrence that **references** its source requirement or clause.
- Rescheduling produces explicit history on the deadline occurrence.
- Do not independently store the same due date as authoritative facts on both the requirement and the deadline without a source link.

### 2.11 Currency and money

- All monetary facts use `bigint` `*_minor_units` plus an explicit currency per ADR 0001.
- No functional-currency persistence in 3B.
- No implicit currency conversion.
- Agency or departure default currency may seed entry; it does not interpret stored facts.
- Forecast cost and exposure totals are **grouped by transaction currency**. USD and EUR must never render as one numeric total. Cross-currency departure totals remain unavailable until the ADR 0001 amendment and 3E functional-currency work ship. Per-currency subtotals are allowed.

### 2.12 Independent state dimensions

Booking/arrangement state, confirmation state, capacity state, and commitment state are independent. Do not collapse them into one arrangement status.

### 2.13 Parent and resource cancellation / deactivation

- Cancelling an arrangement is **rejected** while it has any nonterminal child arrangement or nonterminal reservation.
- The operator must explicitly cancel, reparent, or otherwise dispose of each child first.
- **No cascading cancellation.**
- Cancellation terms and resulting capacity/commitment consequences still require preview and explicit application commands; cancelling the arrangement row is not itself those consequences.
- Once all descendants are terminal, the parent may be cancelled.
- Deactivating a resource is **rejected** while it has active (non-zero actionable) capacity positions needing disposition or nonterminal reservations linked to it. Explicit capacity release/consume/cancel paths must clear those dependencies first.

### 2.14 Reservation `confirmed` evidence

Moving a reservation to `confirmed` requires either:

1. At least one **effective** `SupplierConfirmation` on that reservation, or
2. An explicit “supplier confirmed without identifier” reason plus provenance (actor, timestamp, optional document/channel reference).

A reservation must not become `confirmed` with neither evidence path.

### 2.15 Per-person terms before client trips

Per-person shapes evaluate against an explicit **planning quantity** or contractual **guaranteed quantity** stored on the term evaluation inputs. They must not imply that actual traveler counts exist. Slice 3D may produce new evaluations from fulfillment quantities without rewriting the original planning inputs.

---

## 3. Aggregate map

```text
Departure
└── SupplierArrangement (office-owned)
    ├── child SupplierArrangement (optional commercial nest)
    ├── SupplierReservation
    │   └── reservation↔resource links
    ├── SupplierResource
    │   ├── SupplierServiceOccurrence (night slice or typed segment)
    │   ├── CapacityEvent (authoritative)
    │   └── CapacityPosition (rebuildable projection)
    ├── SupplierConfirmation (arrangement- or reservation-owned)
    ├── SupplierCostTerm (versioned envelope + shape details)
    ├── SupplierCommitment (references governing term)
    ├── SupplierDepositRequirement
    ├── SupplierDeadline (references source requirement/clause)
    └── Guarantee / release / attrition / cancellation clause records
```

Table names use the `supplier_` prefix. Column spellings may vary in migrations only if the locked relationships, uniqueness, and semantics above remain unchanged.

---

## 4. Persistence design

All application-owned tables use UUIDv7 primary keys with `uuidv7()` defaults unless this plan defines a natural key. Every tenant-owned table carries direct `agency_id` and tenant-safe composite foreign keys. Office-owned rows carry `office_id` with composite FKs as specified in §2.4.

### 4.1 Prerequisite on `departures`

Add unique index/constraint on `departures (id, agency_id, office_id)` so children can reference it. Retain existing unique `(id, agency_id)` and other 3A keys.

### 4.2 `supplier_arrangements`

| Column | Contract |
| --- | --- |
| `id` | UUIDv7 PK |
| `agency_id` | Required |
| `office_id` | Required; matches departure office |
| `departure_id` | Required |
| `parent_arrangement_id` | Optional same-departure parent |
| `supplier_party_id` | Required contracting Party |
| `service_provider_party_id` | Optional distinct operating Party |
| `name` | Required |
| `description`, `client_facing_description` | Optional |
| `status` | `draft`, `active`, or `cancelled` (§10) |
| Snapshots | Supplier and service-provider display-name snapshots at establishment |
| `lock_version` | Optimistic lock |
| timestamps | `timestamptz` |

Constraints:

- Composite FK `(departure_id, agency_id, office_id)` → `departures (id, agency_id, office_id)`.
- Parent FK same agency, departure, and office; `parent_arrangement_id <> id`.
- Database-backed cycle prevention (constraint trigger or equivalent) plus command validation.
- Concurrent reparenting locks ancestry consistently.
- Supplier and optional service-provider Party same-agency FKs; no live active-party projection.

### 4.3 `supplier_reservations`

| Column | Contract |
| --- | --- |
| `id` | UUIDv7 PK |
| `agency_id`, `office_id`, `departure_id`, `arrangement_id` | Required; office matches departure via composite FKs |
| `status` | Reservation lifecycle (§10) |
| Service occurrence links | Via reservation↔resource and occurrence associations |
| `confirmed_without_identifier_reason` | Required when confirmed without a confirmation row; otherwise null |
| Snapshots / notes | Optional operational text |
| `lock_version`, timestamps | Required |

Composite FKs to arrangement and departure include agency and office. A reservation cannot move across departures.

### 4.4 `supplier_resources`

| Column | Contract |
| --- | --- |
| `id` | UUIDv7 PK |
| Ownership FKs | Office-owned under arrangement and departure |
| `capacity_unit` | Explicit unit (`seat`, `room`, `cabin`, …)—not `room_night` as the resource unit when nights are modeled as occurrences |
| Resource kind / label | Required operational identity |
| `status` | `active` or `inactive` |
| `lock_version`, timestamps | Required |

Reservation–resource associations are explicit join rows. 3B does not create traveler occupancy.

### 4.5 `supplier_service_occurrences`

Concrete capacity slice identity. Date and segment are **not** mutually nullable alternatives on the position row.

| Kind | Contract |
| --- | --- |
| Night slice | One calendar service date for hotel/cruise night inventory under a resource |
| Typed segment | Explicit supplier service segment record (transport/tour segment), not a free-form label |

For multi-night hotel inventory, each night has its own occurrence unless an explicit same-capacity range is modeled as multiple identical night slices. Positions reference `(resource_id, service_occurrence_id, capacity_unit)`.

### 4.6 `supplier_confirmations`

| Column | Contract |
| --- | --- |
| Owner | Exactly one of arrangement or reservation (check-enforced) |
| `issuer_party_id` | Required |
| Identifier type / context | Required qualified type |
| `raw_value`, `normalized_value` | Required |
| `issued_on`, `received_on` | Optional dates |
| Effective / superseded state | Required |
| Source channel or document reference | Optional typed fields |
| `entered_by_membership_id` | Required |
| Display snapshot | Optional |
| Ownership FKs | Agency + office + departure |

Uniqueness: `(agency_id, issuer_party_id, identifier_type, context, normalized_value)` scoped so the same value may exist across different issuers. Do not reuse Phase 2C `ExternalIdentifier`.

### 4.7 `supplier_cost_terms` (shared envelope)

Draft term versions may be edited. Once activated as an estimate or contracted term, a term version is **immutable**. Corrections and commercial changes create a superseding version. Nothing is financially posted in 3B.

| Column / concern | Contract |
| --- | --- |
| Ownership | Arrangement required; optional reservation/resource/occurrence scope |
| Economic-item key / id | Derived canonical key; opaque UUID when supersession needs it |
| `shape` | One of the locked catalog values |
| `basis` | `estimate` or `contracted` only |
| `status` | `draft`, `active`, `superseded`, or `void` |
| Currency | Required uppercase ISO code |
| Quantity basis and unit | Required |
| Planning / guaranteed person quantity | Required for per-person shapes in 3B |
| Covered occurrences | Required when occurrence-scoped |
| Effective period / version | Required |
| Rounding method | Required explicit enum |
| Mins / maxes / thresholds | Nullable per shape |
| Tax/fee treatment | Included, excluded, or separate |
| Supplier-term provenance + snapshot | Required |
| `supersedes_term_id` | Optional prior version |
| Evaluation inputs snapshot | Explainable inputs (JSON **only** as evidence/inputs, never as the contractual formula) |
| Shape amounts | In typed detail tables as `_minor_units` |
| `lock_version` | On draft rows; active rows are not updated in place |

**No** arbitrary JSON formula as the authoritative contract. **No** one mega-table of mostly nullable columns for every shape.

### 4.8 Shape-detail ownership matrix

| Shape | Detail ownership |
| --- | --- |
| Fixed | Envelope + fixed amount minor units |
| Per-resource | Envelope + unit amount; quantity from resource count basis |
| Per-person | Envelope + unit amount; **planning or guaranteed person quantity** on the term |
| Per-night | Envelope + unit amount; quantity from occurrence (night) count basis |
| Minimum guarantee | Envelope + minimum quantity and/or minimum amount |
| Tiered | Child `supplier_cost_term_tiers` (threshold → selected rate) |
| Stepped | Child `supplier_cost_term_steps` (band from/to → rate) |
| Percentage | Envelope + rate + explicit base economic-item / amount reference |
| Complimentary ratio | Child ratio rules (paid units, earn units, rounding) |
| Pass-through | Envelope + referenced supplier amount provenance; no assumed markup |
| Manual estimate | Envelope + explicit forecast amount and reason |

All shapes feed one evaluation interface and produce explainable calculation results.

### 4.9 `supplier_commitments`

Separate immutable/versioned commercial record.

| Column / concern | Contract |
| --- | --- |
| Ownership | Arrangement required; optional reservation/resource/occurrence scope |
| Economic-item identity | Same dimensions as §2.8 |
| `governing_term_id` | Required active term whose evaluation the commitment references |
| Valuation snapshot | Explainable amount(s) and inputs at commitment time |
| Currency | Required; matches governing evaluation currency |
| `status` | `open`, `released`, `satisfied`, `superseded`, or `cancelled` |
| Provenance / reason | Required on establish and status changes |
| Snapshots | Governing term identity and display facts |

Commitments are not cost-term rows and not payables.

### 4.10 Deposit requirements and deadlines

`supplier_deposit_requirements` own the commercial due rule (amount/calculation, due rule, refundability, application, trigger, currency, provenance).

`supplier_deadlines` are occurrences that **must** reference `source_deposit_requirement_id` or `source_clause_id` (exactly one). Reschedule history is on the deadline. Completing or waiving a deadline never sets deposit payment state.

### 4.11 Capacity events and positions

#### Events (authoritative)

Immutable typed events:

`initial_hold`, `request`, `confirm_request`, `increase`, `reduction`, `release`, `reinstatement`, `consumption`, `restoration`, `correction`, `expiration`.

Events contain signed quantities for reconstruction, but commands expose business verbs; users do not enter arbitrary deltas.

Each event records: resource, service occurrence, capacity unit, command time, effective date, actor membership, reason, idempotency key, causation/correction relationship, and optional supplier-approval provenance for reinstatement/confirm paths.

#### Positions (projection)

Unique key:

```text
(resource_id, service_occurrence_id, capacity_unit)
```

Stored bucket columns (non-negative): `agency_held`, `pending_request`, `guaranteed`, `consumed`, `released_current`.

Derived:

- `available = agency_held - consumed`
- `released_cumulative` = sum of release quantities from events (historical); **not** the same field as `released_current`

`released_current` is the quantity still eligible for reinstatement. Reinstatement decreases `released_current` and increases `agency_held`; it does **not** rewrite cumulative released history.

Optional supplier-reported total inventory (if ever stored) is **not** part of this position key and must not enter `available`.

The position table is never edited independently. Each mutating command: locks the position → validates proposed result against §5 → appends event → updates stored buckets in one transaction.

Positions rebuild solely from ordered events using §5. Missing or unreconciled positions fail closed for mutations (not treated as zero). Reconciliation detects disagreement; repair replaces the projection from events and writes an administrative audit event; it does not rewrite capacity events.

### 4.12 Guarantee, release, attrition, and cancellation clauses

Persist as clause records with provenance and effective periods. Application is always through explicit commands that emit capacity events and/or commitment changes per §6.4.

---

## 5. Capacity contract

### 5.1 Buckets

| Bucket | Kind | Meaning |
| --- | --- | --- |
| Agency-held | Stored | Capacity currently controlled by the agency |
| Pending request | Stored | Requested but not yet supplier-confirmed |
| Guaranteed | Stored | Capacity included in agency guarantee exposure |
| Consumed | Stored | Capacity used via supplier reservation (3B) |
| Released current | Stored | Returned to supplier and still eligible for reinstatement |
| Released cumulative | Derived from events | Historical total released; not reduced by reinstatement |
| Available | Derived | `agency_held - consumed` |
| Supplier-reported total | Optional external fact | Not derivable from agency-held; never implies availability |

DepartureDesk usually does **not** know the supplier’s full inventory. Supplier-reported totals are optional supplier-provided information. They must not enter availability unless the supplier explicitly confirms an on-request reservation (via `confirm_request` / confirmation path).

### 5.2 Event-to-position transition matrix

This accepted plan defines the transition matrix and reconstruction formulas; implementation must reproduce them exactly.

| Event | agency_held | pending_request | consumed | released_current | guaranteed |
| --- | ---: | ---: | ---: | ---: | ---: |
| `initial_hold` | +Q | — | — | — | +Q only when the command explicitly records guarantee |
| `request` | — | +Q | — | — | — |
| `confirm_request` | +Q | −Q | — | — | +Q only when explicitly recorded |
| `increase` | +Q | — | — | — | explicit if applicable |
| `reduction` | −Q | — | — | — | explicit consequence if guarantee shrinks |
| `consume` | — | — | +Q | — | — |
| `restore` | — | — | −Q | — | — |
| `release` | −Q | — | — | +Q | explicit guarantee consequence required when guarantee is affected |
| `reinstate` | +Q | — | — | −Q | explicit if applicable; requires supplier-approved provenance |
| `expiration` | −Q | −Q (if pending expires) | — | +Q to released_current **or** separate expired history event that does not reinstate | explicit if applicable |
| `correction` | Explicit compensating signed effects only; must leave all stored buckets ≥ 0 | | | | |

Rules:

- Users never enter arbitrary signed deltas; commands choose the event type and Q.
- `available` is always recomputed as `agency_held - consumed` after applying stored-bucket updates.
- `release` does not increase `available` except insofar as held decreases and consumed is unchanged—released inventory is not available for new consumption until reinstate.
- Ordinary commands must not produce negative stored buckets.
- Guaranteed may overlap held; exposure reporting must not invent double liability (§7).

### 5.3 3B consumption scope

- 3B `consumption` events reference supplier-side reservations consuming held resources on a service occurrence.
- Do not fabricate client trips, inventory allocations, or fulfillment rows.
- Slice 3D owns client-fulfillment-driven capacity events.

### 5.4 Idempotency

Every capacity-mutating command requires an idempotency key so retries cannot apply capacity twice.

---

## 6. Term, commitment, deposit, and clause contracts

### 6.1 Shape meanings

| Shape | Required meaning |
| --- | --- |
| Fixed | One amount for the covered item or period |
| Per-resource | Amount × rooms, cabins, vehicles, seats, or other resource units |
| Per-person | Amount × explicit planning or guaranteed person quantity |
| Per-night | Amount × qualifying night occurrences (basis explicit) |
| Minimum guarantee | Minimum quantity or amount owed regardless of actual use |
| Tiered | One rate selected from final qualifying quantity |
| Stepped | Different quantity bands at different rates |
| Percentage | Percentage of an explicitly identified base amount |
| Complimentary ratio | Complimentary units from paid-unit ratio + rounding rule |
| Pass-through | Supplier amount passed through without assumed markup |
| Manual estimate | Explicit forecast when no deterministic formula applies |

### 6.2 Required envelope declarations

Each term declares: currency; quantity basis and unit; covered occurrences when scoped; basis (`estimate` or `contracted`); status; effective period and version; rounding method; minimums/maximums/thresholds/bands; percentage base for percentage shapes; tax/fee treatment; supplier-term provenance and snapshot; which previous term it supersedes; evaluation inputs (including planning/guaranteed person quantity for per-person) and resulting forecast amount.

### 6.3 Commitments

A commitment is an explicit commercial control on exposure for an economic item—not a posted payable and not a cost-term status. It references a governing active term evaluation. Ending, releasing, satisfying, cancelling, or superseding a commitment is command-driven and audited.

### 6.4 Applying clauses

Release, attrition, and cancellation clauses are inert until an apply command:

1. Loads clause + current capacity/commitment state under locks.
2. Previews capacity and exposure consequences.
3. Emits explicit capacity events and/or commitment changes.
4. Audits the **successful** command aggregate with referenced child IDs.

---

## 7. Forecast cost and exposure

### 7.1 Forecast cost

For each economic item, forecast cost is the evaluation of the **controlling** precedence step in §2.7. Do not sum estimate, contracted, and commitment valuations. Do not include 3F final costs. Render and aggregate **per currency only**.

### 7.2 Exposure

3B exposure is the agency’s commercial risk from guarantees and related open commitments that may remain even if capacity is unsold—distinct from held capacity and from posted payables.

Exposure reporting must:

- Identify guarantee quantity/amount and currency.
- Relate unsold guaranteed capacity to forecast financial exposure when terms define it.
- Remain rebuildable from terms, commitments, and capacity positions.
- Group monetary exposure **by currency**; never a single cross-currency total.
- Never treat supplier-collected client money or agency cash as part of 3B exposure.

---

## 8. Party deactivation and Phase 2E merge participation

Register every new Party FK in `PartyDeactivationDependencies` and the Phase 2E fail-closed catalog in the same change that introduces it. Merge remains blocked for unsupported participants.

| Reference | Establishment | Snapshot | Deactivation | Merge (future) |
| --- | --- | --- | --- | --- |
| Contracting supplier | Active supplier profile, same agency | Display name at establish/change | Block while any nonterminal arrangement (including `draft`) depends on it | Fail closed until participant ships; preserve snapshots |
| Service provider | Active same-agency Party | Display name | Block while any nonterminal arrangement depends on it | Same |
| Confirmation issuer | Eligible same-agency Party when recorded | As recorded | Historical confirmations do not require live issuer | Fail closed; preserve confirmation values |
| Supplier contact | Active same-agency Party when assigned | As recorded | Block while current assignment depends on it | Fail closed |
| Guarantor / contracting contact | Active same-agency Party when assigned | As recorded | Block while current | Fail closed |

Do not guess, cascade, or silently repoint.

---

## 9. Office and membership integration

### 9.1 Transfer freeze (amends 3A §6.3)

Replace the open “freeze or replace” requirement with the concrete rule in §2.4. Update `TransferDepartureOffice` to reject when any arrangement exists for the departure, using the shared lock boundary and race test with first arrangement create. Expected rejection is returned as a command error; it does **not** write a successful-domain administrative audit event.

### 9.2 Office deactivation

Nonterminal departures already project owning-office status. 3B children inherit office ownership; office deactivation continues to block while nonterminal departures exist. Do not rewrite child `office_id` as a side effect.

### 9.3 Membership suspension / office-access revocation

Retain 3A departure team-assignment dependencies. 3B does not add membership-as-assignee capacity ownership. Confirmation `entered_by` is historical attribution only.

---

## 10. Commands and lifecycles

Controllers remain thin. Commands own transactions, locks, revalidation, audit, and side effects.

### 10.1 Arrangement statuses

```text
draft → active → cancelled
draft → cancelled
```

- `cancelled` is terminal for mutation of commercial structure; historical rows remain.
- Parent cancel is rejected while nonterminal children exist (§2.13). No cascade.

### 10.2 Reservation statuses

```text
requested → submitted → confirmed → cancelled
requested → cancelled
submitted → declined | unable_to_confirm | cancelled
confirmed → cancelled
```

`confirmed` requires confirmation evidence per §2.14. Confirmation identifier rows remain a separate state dimension (`effective` / `superseded`).

### 10.3 Resource statuses

```text
active → inactive
```

Inactive resources reject new capacity increases and new consumption. Deactivation is rejected while actionable capacity or nonterminal reservation links remain (§2.13).

### 10.4 Confirmation statuses

```text
effective → superseded
```

Supersession is explicit; values are not deleted.

### 10.5 Cost-term basis and lifecycle

```text
basis: estimate | contracted
status: draft → active → superseded
draft → void
active → void   # only via explicit void command with reason; prefer supersession for commercial replacement
```

Estimate→contracted is a new version (new row), not an in-place basis change.

### 10.6 Commitment statuses

```text
open → released | satisfied | superseded | cancelled
```

### 10.7 Deadline statuses

```text
open → completed | waived | cancelled
```

### 10.8 Capacity position reconciliation

```text
consistent → divergent → repaired
```

Repair is an explicit administrator or privileged-recovery command that rebuilds from events and audits success.

### 10.9 Representative commands

| Command | Role |
| --- | --- |
| `CreateSupplierArrangement` | First child freezes office transfer |
| `UpdateSupplierArrangement` | Draft/active field updates under auth matrix |
| `CancelSupplierArrangement` | Rejects if nonterminal children remain |
| `ReparentSupplierArrangement` | Cycle-safe reparent |
| `CreateSupplierReservation` / update / cancel / confirm | Reservation lifecycle; confirm enforces §2.14 |
| `CreateSupplierResource` / update / deactivate | Resource lifecycle |
| `RecordSupplierConfirmation` / supersede | Confirmation provenance |
| `CreateSupplierCostTerm` / activate / supersede / void | Versioned terms |
| `CreateSupplierCommitment` / release / satisfy / supersede / cancel | Separate commitment authority |
| `CreateSupplierDepositRequirement` / update | Requirement only |
| `CreateSupplierDeadline` / reschedule / complete / waive | Deadline occurrence linked to source |
| Capacity verbs (`Hold`, `Request`, `ConfirmRequest`, `Increase`, `Reduce`, `Release`, `Reinstate`, `Consume`, `Restore`, `Correct`, `Expire`) | Per §5 matrix |
| `ApplyReleaseTerm` / `ApplyAttritionTerm` / `ApplyCancellationTerm` | Preview + explicit consequences |
| `ReconcileCapacityPosition` | Repair projection |
| `TransferDepartureOffice` | Reject when any arrangement exists (error, not success audit) |

---

## 11. Command lock-order appendix

### 11.1 Principles

- Preserve existing membership/activation and directory/role-profile lock orders.
- Preserve 3A departure lock order for departure-scoped work.
- Nested public commands must not reacquire earlier locks.
- Do not invent one universal Phase 3 lock order.

### 11.2 Canonical 3B order (new work)

```text
agency
→ offices by UUID (when office ownership or transfer is in scope)
→ departure
→ arrangements by UUID (parents before children when both touched)
→ reservations / resources / occurrences / terms / commitments / positions by UUID
→ memberships / parties by UUID when establishing references
```

### 11.3 Transfer ↔ first arrangement

```text
agency → offices (old/new by UUID) → departure → arrangement dependency check / insert
```

Both commands take this boundary when racing. After reload, transfer fails if any arrangement exists; create inserts under current office.

### 11.4 Capacity mutation

```text
agency → office → departure → arrangement → resource → service_occurrence → capacity_position → append event
```

### 11.5 Revalidation

After locks, reload and recheck: agency active; office active for mutations; departure nonterminal for commercial creates; Party/supplier eligibility; lock versions; idempotency keys; capacity non-negativity; child-terminal rules for cancel/deactivate.

---

## 12. Authorization

This matrix is a deliberate operating-policy decision. It is **not** an extension of 3A team-assignment rows into a permission table. The group-manager check remains a command predicate plus office access.

| Action | Authorization |
| --- | --- |
| Read supplier planning | Staff with owning-office access; administrators per 3A active-office / historical rules |
| Create/update draft arrangements, reservations, resources, confirmations, and deadlines | Staff with owning-office access |
| Submit or confirm reservations (with §2.14 evidence) | Staff with owning-office access |
| Activate/supersede contracted terms; activate estimate terms that will drive exposure reporting | Administrator or current group manager with office access |
| Establish/release/satisfy/cancel commitments or guarantees | Administrator or current group manager with office access |
| Apply cancellation, release, or attrition consequences | Administrator or current group manager with office access |
| Cancel an arrangement | Administrator or current group manager with office access |
| Capacity correction / reconciliation repair | Administrator or privileged recovery |
| Office transfer | Administrator only, subject to permanent freeze |
| Party/supplier selectors | Agency-wide Directory rules; never filtered by departure office |

`Current.office` never authorizes. Arrangement Party roles never grant application authority.

---

## 13. Audit contract

Extend closed `AuditEvent::ACTIONS` and `RecordAdministrativeAudit` subject types in the same change that first writes them.

Audit **successful command aggregates** (arrangement created, term activated/superseded, commitment opened, capacity hold applied, clause applied, position repaired). Do **not** make every capacity event an administrative-audit subject.

Failed or rejected commands (including transfer rejected because arrangements exist) roll back and return domain errors. They do **not** create administrative audit events that resemble successful domain activity. Observability/logging may record failures; a persistent failure-audit trail is out of scope unless the repository later adopts an explicit failure-audit contract.

Capacity events themselves record actor, reason, idempotency, and causation. Administrative audit details reference created capacity-event IDs and other child identities.

`AuditEvent#details` is not the term snapshot store or capacity ledger.

---

## 14. User interface

- Supplier planning lives under the departure workspace (subnav or equivalent).
- Surfaces: arrangement index/detail, reservation/resource/occurrence panels, confirmation entry, term/commitment/deposit/deadline editors, capacity positions with event history, per-currency deadline and exposure summaries.
- No fabricated client balances, cash, margin, or cross-currency totals.
- Office transfer control hidden/disabled when any arrangement exists; server remains authoritative.
- Preview step for apply-clause commands when consequences touch capacity or commitments.
- Conform to `docs/ui/interface-contract.md`; keyboard and no-JavaScript paths for forms and filters.
- Party/supplier pickers reuse agency-wide searchable selectors.
- Do **not** render navigation, tabs, counts, or controls for later domains (client trips, packages, accounting, etc.) until the corresponding records and workflows ship.
- Slices 3B.1–3B.5 may expose routes for tests and operators without adding primary-navigation entries; 3B.6 owns primary navigation integration.

---

## 15. Test plan

### 15.1 Database and model

- Composite office FKs; cross-agency and cross-office rejection.
- Arrangement hierarchy cycle prevention and self-parent rejection under concurrency.
- Confirmation uniqueness by issuer/context.
- Term envelope + shape tables; reject authoritative JSON-only formulas; no `committed` term basis.
- Commitment rows reference governing terms; independent lifecycles.
- Capacity position uniqueness on `(resource, occurrence, unit)`; transition matrix and non-negativity; fail closed on missing position; released_current vs cumulative.
- Deposit requirement has no payment columns; deadlines reference sources.

### 15.2 Commands and races

- First arrangement freezes transfer; cancelled arrangements still freeze; rejection is error without success audit.
- Simultaneous transfer and first arrangement cannot mix offices.
- Parent cancel rejected with nonterminal children; no cascade.
- Capacity idempotency; compensating corrections; rebuild matches projection and matrix.
- Clause apply does not mutate capacity until explicit consequence events.
- Economic-item precedence: estimate / contracted / commitment never summed; per-currency reporting.
- Reservation confirm rejected without confirmation evidence or without-identifier reason.

### 15.3 Party lifecycle

- Deactivation blockers for each named Party reference class, including draft arrangements.
- Phase 2E catalog registration for each new Party FK.

### 15.4 Authorization and UI

- Staff may perform routine draft/confirm work; manager/admin required for contracted activation, commitments, clause apply, arrangement cancel.
- Staff office filtering; admin historical read rules.
- Transfer UI disabled when arrangements exist; command still rejects.
- No later-domain nav affordances.
- System coverage for core flows where Chrome/CI available.

### 15.5 Scenario gates

**Napa:** 30-seat fixed-cost coach; second stepped resource; forecast and exposure without client trips; per-currency totals.

**Smith:** cruise agreement; guaranteed cabins; hotel block nights as per-occurrence capacity; on-request extensions; no client trips.

---

## 16. Implementation order

1. **3B.1 — Arrangements and ownership**  
   Arrangement/reservation/resource/occurrence persistence; Party rules; hierarchy/cycles; confirmations; office-transfer freeze; lifecycles; authorization matrix; audit; Party dependencies; parent-cancel rules.

2. **3B.2 — Core cost and commitment terms**  
   Fixed, per-resource, per-person (planning quantity), per-night, minimum guarantee, manual estimate; economic-item identity and forecast precedence; separate commitments; deposits and deadlines as requirements with source links.

3. **3B.3 — Capacity events and projections**  
   Occurrence dimensions; transition matrix; idempotency; negative protection; rebuild; reconciliation; reservation consumption; supplier-approved release/reinstatement; released_current vs cumulative.

4. **3B.4 — Advanced terms**  
   Tiered, stepped, percentage, complimentary ratio, pass-through.

5. **3B.5 — Guarantees and consequence evaluation**  
   Release, attrition, cancellation, deposit, and guarantee previews; per-currency forecast cost and exposure reporting.

6. **3B.6 — UI and scenario completion**  
   Supplier-planning workspace and primary navigation; Smith/Napa proofs; complete authorization, concurrency, system, and exit-gate coverage.

Do not start a later slice’s persistence until prior slice gates needed for its dependencies are green.

---

## 17. Explicit exclusions

- Packages, client trips, service components, traveling parties.
- Traveler assignment, inventory allocation, fulfillment allocation, resource occupancy for travelers.
- Agency-provided services model.
- Aggregate office transfer.
- Posted supplier obligations, payments, refunds, or final billed costs (3F).
- Functional-currency translations and cross-currency totals (ADR 0001 / 3E).
- Client-driven capacity consumption (3D).
- Phase 2C `ExternalIdentifier` reuse for confirmations.
- Capacity events as `AuditEvent` subjects.
- Successful-domain audit events for rejected/failed commands.
- Executable party merge.
- Generic polymorphic financial `transactions` table.
- Automatic legal interpretation of supplier contracts without review commands.
- Deriving availability from assumed supplier-wide inventory.

Do not create placeholder tables or statuses with side effects for later domains. Do not render navigation, tabs, counts, or controls for later domains until the corresponding records and workflows ship.

---

## 18. 3B exit gate

3B is complete only when:

1. Arrangements, reservations, and resources are distinct; hierarchy is cycle-safe; confirmations use issuer/context provenance; confirmed reservations satisfy §2.14.
2. Every office-owned child matches departure `(id, agency_id, office_id)`.
3. First arrangement freezes `TransferDepartureOffice` permanently for that departure; race-tested; rejection is not a success audit.
4. Full term-shape catalog is implemented with envelope + typed details; evaluation is explainable; term basis is only estimate/contracted.
5. Commitments are separate records; economic-item precedence prevents summing estimate/contracted/commitment/final; no final cost rows exist.
6. Deposits and deadlines are requirements with source-linked deadline occurrences and without payment state.
7. Capacity events are authoritative; positions use `(resource, occurrence, unit)`; transition matrix holds; released_current ≠ cumulative; negatives forbidden; 3B consumption is reservation-scoped only.
8. Parent cancel and resource deactivate reject nonterminal children / actionable capacity; no cascades.
9. Clause application previews and emits explicit consequences; clauses alone do not mutate capacity/commitments.
10. Forecast cost and guarantee exposure are reportable **per currency** for Smith and Napa without client trips.
11. Authorization matches §12 (staff routine vs manager/admin commercial).
12. Party deactivation and Phase 2E catalog cover every new Party FK, including draft dependencies.
13. Audit catalogs remain closed and correct; capacity operational trail is on events.
14. Lock-order appendix is followed; nested commands do not reacquire locks.
15. UI conforms to the interface contract without fabricated financial dashboards or later-domain nav.
16. Agency-provided services remain excluded.
17. Full automated tests and CI pass in the canonical Docker/CI environment.

Exit-gate note: 3B.6 added the departure-nested supplier planning workspace, browser-visible system coverage for the create/confirm/hold/transfer-freeze flow, Smith and Napa supplier-planning scenario proofs without client trips, and full-suite verification. The shipped scope remains supplier planning only; client trips, packages, posted supplier obligations/payments, and functional-currency totals stay deferred to later Phase 3 slices.

Only after this gate should 3C treat the departure as ready for offers and client trips alongside supplier planning.
