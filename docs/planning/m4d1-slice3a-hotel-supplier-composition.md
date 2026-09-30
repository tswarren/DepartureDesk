# M4D.1 Slice 3A — Hotel Supplier Composition

**Status:** Accepted 2026-09-30. Slice 3A.0, the persistence compatibility gate, is recorded in [the 3A.0 result](#3a0-result). Four required facts have no lossless shipped representation, so Slice 3A.1 remains blocked. Not authority for Transportation, a Client Service connection, or a generalized adapter.

**Parent:** [M4D.1 — Departure Composition Workspace](m4d1-departure-composition-workspace.md).

**Boundary authority:** [M4D.1 Slice 3R — Non-Cruise Adapter Boundary](m4d1-slice3r-non-cruise-adapter-boundary.md).

**Workflow authority:** [Hilton Hotel Staff walkthrough](m4d1-hilton-hotel-staff-walkthrough.md), Accepted 2026-09-27.

**Canonical fixture:** [Hilton Fort Lauderdale Marina 2027](fixtures/hilton-fort-lauderdale-marina-2027-canonical-scenario-draft.md), Approved 2026-09-27.

**Implementation base:** [`115d3b5`](https://github.com/tswarren/DepartureDesk/commit/115d3b5b608f2191e1a4deadfcdad150342e54e6) on `main`, after Cruise Supplier workspace consolidation.

**Prototype warning:** The unmerged `m4d1-slice3-hotel-transport-activity` branch and PR #156 are prototype evidence only. They are not implementation authority.

---

## 1. Acceptance

Accepted 2026-09-30. This document is the Hotel Supplier Composition implementation authority.

The registered Hilton fixture leaves the original contract/signature date and the Hotel group or confirmation number unspecified. Staff leave both blank. DepartureDesk does not infer or fabricate either value, and later confirmation evidence is not the original contract date.

The implementation base is [`115d3b5`](https://github.com/tswarren/DepartureDesk/commit/115d3b5b608f2191e1a4deadfcdad150342e54e6).

PR #156 and its generalized adapter services remain non-authoritative.

Slice 3A.0 has run. Its result is below. Slice 3A.1 does not start until every required fact has a lossless persisted representation. A foundation amendment for each named incompatibility has to be accepted, and this compatibility proof rerun, before that slice is authorized.

---

## 2. Goal

Slice 3A proves that the existing Supplier Composition foundation can accurately represent and operate a Hotel agreement whose inventory, economics, deposits, deadlines, and policies differ materially from Cruise.

The canonical proof is the Smith Family Reunion pre-cruise stay at Hilton Fort Lauderdale Marina:

- arrival November 4, 2027;
- departure November 6, 2027;
- contracted inventory nights November 4 and November 5;
- Standard and Deluxe room categories;
- quantities that vary by night;
- occupancy-position room rates;
- three fixed scheduled Group deposits;
- one actionable room-assignment cutoff;
- Supplier concessions and availability-only additional-night terms;
- limited attrition policy;
- a governing refund clarification that preserves contradictory original wording as history; and
- draft, activated, and successor Supplier-version behavior.

The Supplier journey stops at Supplier Composition.

Slice 3A does not create or connect a Client Service.

### 2.1 MVP rule

Slice 3A structures Hotel facts that are required to establish and govern Supplier terms.

It preserves, but does not operationalize, booking-dependent Hotel terms whose calculation requires Client Trip, Reservation, folio, payment, or settlement facts that do not exist in M4.

A contractual clause does not require a dedicated computational model merely because it may become operationally important later.

---

## 3. Layer boundary

Slice 3A owns Supplier facts:

- Hotel Arrangement and Hotel Item;
- guest stay and contracted inventory dates;
- room Resources;
- Supplier-controlled nightly room capacity;
- Supplier rates and Supplier-cost evaluation;
- Supplier Deposit Requirements;
- Supplier Deadlines;
- Supplier concessions;
- Supplier agreement policies and clarification history;
- activation readiness and Supplier-version lifecycle.

Slice 3A does not own:

- Service Offers;
- Client room choices;
- Client prices;
- Package inclusion or included/optional placement;
- Client Trips;
- Client reservations;
- traveler room assignments;
- actual pickup or utilization;
- rooming-list contents;
- guest folios;
- guest payments;
- Supplier payments;
- recorded Agency deposit payments;
- refund transactions;
- calculated attrition charges;
- calculated early-departure charges.

The Hotel workspace provides a return to Departure Composition. It does not provide a `Connect Client Service` action or create a quiet connected-but-unpriced Client state.

---

## 4. Architectural rule

Hotel is a typed presentation and orchestration layer over the existing M3 Supplier model.

Do not introduce parallel Hotel records for concepts already owned by:

- Supplier Arrangement;
- Arrangement Item;
- Occurrence;
- Resource;
- Pool;
- Supplier cost definitions;
- Supplier Deposit Requirements;
- Supplier Deadlines;
- Arrangement versions; or
- activation.

Hotel-specific commands may orchestrate those records when the Staff question is Hotel-specific.

They must not create a second inventory, economics, deposit, deadline, or activation authority.

Do not extract a generalized non-Cruise adapter framework in Slice 3A.

Slice 3R permits shared support only after a later vertical demonstrates the same Staff question, command sequence, and stable identity.

---

## 5. Stable Hotel Item boundary

A Supplier Arrangement may contain more than one Hotel Item.

Every Hotel workspace, mutation, compiler, and route must identify the selected stay by stable Arrangement Item ID.

Do not select a Hotel Item by:

- name;
- Supplier;
- creation order;
- `.first`;
- `.last`; or
- an assumption that an Arrangement contains only one Hotel Item.

The blocking proof creates a second Hotel Item and then reopens the canonical Hilton Item by ID.

The second Item must not affect:

- the Hilton room inventory;
- the 22 contracted room nights;
- the $4,156 original contracted-room-revenue target;
- Hilton deposits; or
- Hilton agreement terms.

---

## 6. Stay and nightly inventory graph

### 6.1 Required semantic distinction

The Hotel agreement contains two different time concepts:

1. one continuous guest stay from November 4 check-in through November 6 checkout; and
2. two contracted inventory nights whose quantities differ.

The persisted graph must preserve both concepts without representing November 5 as a second guest check-in.

The UI must not rely on a free-text Pool label as the sole authority for an inventory date.

### 6.2 Normative graph

The persisted graph is:

    SupplierArrangementVersion
    └── ArrangementItem — Hotel — capacity-managed
        │
        ├── Stay Occurrence
        │   ├── starts_on: 2027-11-04
        │   ├── ends_on: 2027-11-06
        │   ├── starts_at_local: 15:00
        │   ├── ends_at_local: 12:00
        │   └── time zone: America/New_York
        │
        ├── Inventory Occurrence — November 4
        │   ├── starts_on: 2027-11-04
        │   ├── ends_on: 2027-11-04
        │   ├── Standard Pool · opening 5
        │   └── Deluxe Pool   · opening 2
        │
        └── Inventory Occurrence — November 5
            ├── starts_on: 2027-11-05
            ├── ends_on: 2027-11-05
            ├── Standard Pool · opening 10
            └── Deluxe Pool   · opening 5

        Resources
        ├── Standard · maximum occupancy 4
        └── Deluxe   · maximum occupancy 4

A single-day Occurrence uses the same `starts_on` and `ends_on`. November 4–4 and November 5–5 are that rule. Checkout at noon on November 6 stays on the Stay Occurrence.

The Stay Occurrence preserves the continuous guest stay and the actual check-in and checkout terms. It is not capacity-bearing. Inventory-night Occurrences do not represent guest arrivals and do not receive check-in or checkout times. Both local times on an inventory Occurrence stay blank.

The Hotel Item is capacity-managed. Activation classifies every planned Occurrence and Resource pair. The required classifications are:

- Stay × Standard: `not_applicable`
- Stay × Deluxe: `not_applicable`
- November 4 × Standard: `pooled`
- November 4 × Deluxe: `pooled`
- November 5 × Standard: `pooled`
- November 5 × Deluxe: `pooled`

Each pooled pair has one numeric `block` Pool measured in `resource_units`. Those four Pools are the only capacity. A `not_applicable` pair has no Pool.

No `occurrence_role` column is authorized. Slice 3A.0 maps this graph onto shipped Occurrence, pair, and Pool records. If that mapping cannot keep the Stay Occurrence out of capacity, stop before Slice 3A.1 and accept only the smallest foundation amendment that specific gap requires.

---

## 7. Stay setup

From Departure Composition → Suppliers, Staff open or create the Hilton Supplier Arrangement and choose **Add Hotel stay**.

Staff enter:

- contracting Supplier/property;
- Item name;
- arrival date;
- departure date;
- check-in time;
- checkout time; and
- authoritative IANA time zone.

Canonical values:

| Fact | Value |
| --- | --- |
| Property | Hilton Fort Lauderdale Marina |
| Item name | Pre-cruise hotel stay |
| Arrival | November 4, 2027 |
| Check-in | 3:00 p.m. |
| Departure | November 6, 2027 |
| Checkout | Noon |
| Time zone | America/New_York |
| Display currency | USD, inherited from Departure |

Saving the stay creates no room Resource, Pool, rate, deposit, deadline, Service Offer, or Package inclusion.

An invalid save:

- preserves submitted form values;
- creates no partial Hotel Item graph; and
- leaves previously valid sibling records unchanged.

Staff can leave and resume the exact Item by stable ID.

---

## 8. Room inventory

Staff create two stable room Resources:

| Category | Maximum occupancy |
| --- | ---: |
| Standard | 4 |
| Deluxe | 4 |

Staff then record the Hotel-controlled contracted block:

| Inventory night | Standard | Deluxe | Total |
| --- | ---: | ---: | ---: |
| November 4 | 5 | 2 | 7 |
| November 5 | 10 | 5 | 15 |
| **Room nights** | **15** | **7** | **22** |

Each category/night quantity belongs to an exact Pool with an authoritative inventory date.

The Hotel UI may summarize this as:

> 2 room categories · 22 contracted room nights

It must not describe the agreement as:

- 22 physical rooms;
- 22 sold rooms;
- 15 rooms on each night; or
- one constant opening quantity across the stay.

Staff can reopen and correct one category/night without rewriting saved siblings.

### 8.1 Additional nights

November 1–3 are not opening inventory.

The Supplier agreement says contracted rates and concessions may be requested for those dates subject to Hotel availability.

Slice 3A records that as a readable/versioned Supplier term.

It creates:

- no Pool;
- no guaranteed capacity;
- no extension of the contracted 22-room-night block.

If the Hotel later confirms an additional night, that confirmation becomes a separately evidenced Supplier fact under the appropriate governing/successor authority.

---

## 9. Supplier rates

The Hotel rate shape is per room, per night.

For each room category:

- the base room/night rate covers occupancy positions one and two;
- position three adds $20 per room night;
- position four adds another $20 per room night;
- no adult/child distinction is inferred.

Canonical rates:

| Category | Single | Double | Triple | Quad |
| --- | ---: | ---: | ---: | ---: |
| Standard | $173 | $173 | $193 | $213 |
| Deluxe | $223 | $223 | $243 | $263 |

Where existing M3 cost primitives can represent the economic meaning accurately, persist the base plus occupancy-position increments rather than four unrelated complete prices.

The rates are an explicit persisted net/noncommissionable Supplier term.

Slice 3A creates no `expected_commission` component. Omitting that component is not the noncommissionable fact: an absent commission component can also mean commission has not been entered. Generic Supplier cost records have no noncommissionable flag today. Slice 3A.0 maps the explicit net/noncommissionable term onto shipped records. If it cannot do so losslessly, stop before Slice 3A.1 and accept only the smallest foundation amendment that fact requires.

If a persisted economic shape cannot be represented losslessly by the typed Hotel editor, the UI must show a precise Advanced destination rather than normalize or guess the terms.

---

## 10. Write-free Supplier economics

Existing Supplier-cost evaluation authority remains authoritative.

The Hotel review derives the original base-occupancy contracted-room-revenue target:

| Night | Calculation | Pretax |
| --- | --- | ---: |
| November 4 | `5 × $173 + 2 × $223` | $1,311 |
| November 5 | `10 × $173 + 5 × $223` | $2,845 |
| **Original target** | | **$4,156** |

Triple and Quad increments are not included because actual occupancy does not yet exist.

Supplier-cost evaluation uses each inventory Pool's resource quantity once for that inventory night:

    Nov 4 Standard Pool → 5 resource units × one inventory night
    Nov 4 Deluxe Pool   → 2 resource units × one inventory night
    Nov 5 Standard Pool → 10 resource units × one inventory night
    Nov 5 Deluxe Pool   → 5 resource units × one inventory night

The continuous two-night Stay Occurrence does not supply the cost quantity. A direct proof must reject a two-night multiplier that would produce $8,312.

The quoted agreement tax rates are:

- occupancy tax: 9.5%;
- state sales tax: 7%;
- combined additive rate: 16.5%.

The review may show:

> Illustrative tax exposure: $685.74

from `$4,156 × 16.5%`.

That value is write-free illustrative information.

It is not:

- an additional Supplier Deposit Requirement;
- a persisted Group charge;
- a guest folio;
- an Agency payment; or
- part of the original $4,156 pretax deposit basis.

---

## 11. Group deposits

The Hotel agreement contains three separately identifiable Supplier Deposit Requirements. They are `fixed_amount` requirements. Do not use `percentage_of_cost_sources`. A percentage of live cost sources would turn the original contractual basis into a later calculation.

| Requirement | Due | Share of original target | Agreed amount | `amount_minor_units` |
| --- | --- | ---: | ---: | ---: |
| Initial | 2026-10-01 | 10% | $415.60 | 41560 |
| Second | 2027-05-07 | 45% | $1,870.20 | 187020 |
| Third/final scheduled block deposit | 2027-10-04 | 45% | $1,870.20 | 187020 |
| **Total** | | **100%** | **$4,156.00** | |

These are requirements, not payment records.

Exactly three original-block Supplier Deposit Requirements exist. The October 4 pre-stay adjustment is $0, so no fourth Supplier Deposit Requirement is created.

### 11.1 Original-basis invariant

The three agreed amounts are based on the original $4,156 pretax contracted-room-revenue target.

Later changes to:

- room inventory;
- Supplier rates;
- actual pickup;
- tax;
- added rooms; or
- added nights

must not silently rebase those three requirements.

The versioned derivation that those requirements preserve is:

    Original contracted-room-revenue target: $4,156.00

    Nov 4:
    5 Standard × $173 + 2 Deluxe × $223 = $1,311

    Nov 5:
    10 Standard × $173 + 5 Deluxe × $223 = $2,845

    Deposit schedule:
    10% / 45% / 45%

    Initial   10% =   $415.60
    Second    45% = $1,870.20
    Third     45% = $1,870.20

Preserve that basis in existing versioned evidence or term fields. Slice 3A.0 maps it onto shipped records. If those fields cannot retain the basis without parsing prose, stop before Slice 3A.1 and accept only the smallest persistence addition required to retain this basis. Do not add a generalized deposit-basis engine.

October 4 is the final scheduled deposit for the original block.

It is not final post-stay reconciliation and does not create a second $4,156 charge.

---

## 12. Room-assignment cutoff

Slice 3A records one actionable Supplier Deadline:

**Room assignments / reservation cutoff**

- deadline type: `rooming_list_due`;
- kind: actionable;
- rule shape: `fixed_local_datetime`;
- precision: `local_date_time`;
- October 3, 2027;
- 5:00 p.m.;
- America/New_York;
- submit an approved rooming list or individual-reservation information.

Agreement → Deadlines owns the ordinary actions for this Deadline: **Mark complete**, **Reschedule**, and **Waive**. Those controls call existing Deadline authority. Advanced Supplier planning remains available. Staff do not leave the Hotel journey for this supported Deadline.

Passing the deadline does not automatically release inventory.

Do not create a second rooming-list deadline for the same Supplier requirement. Do not use `option_or_release_date` for this cutoff.

---

## 13. Destination Fee concession

The agreement provides:

> $150 Destination Fee per room night, including the tax that would apply to that fee, is waived for contracted Standard and Deluxe block rooms.

Slice 3A preserves this as a Supplier concession/agreement term.

It is not represented as:

- negative Supplier cost;
- Client discount;
- cash credit; or
- Client-facing benefit.

The amenity wording may remain readable Supplier terms.

A later-confirmed additional night receives the concession when the governing Supplier agreement says it applies. An unconfirmed November 1–3 request creates no fee or waiver transaction.

---

## 14. Attrition

Slice 3A persists the contractual calculation inputs. It does not perform the booking-dependent calculation.

The required persisted semantics are:

    Hotel attrition policy
    ├── consequence
    │   └── 100% of lost room revenue for that date
    │
    ├── Nov 4
    │   └── minimum utilized room nights: 7
    │
    ├── Nov 5
    │   └── minimum utilized room nights: 15
    │
    ├── zero-utilization fallback
    │   ├── Standard: $173
    │   ├── Deluxe: $223
    │   └── quoted applicable tax: 16.5%
    │
    └── readable qualifications
        ├── approved channels only
        ├── contracted rates required
        ├── dates evaluated independently
        ├── released rooms remain in the nightly minimum
        ├── average-utilized-rate rule
        └── collected early-departure fee interaction

Overachievement on one night does not offset another.

Slice 3A does not build an attrition calculator. It does not create `CalculateHotelAttrition`, an attrition Obligation, an early-departure Supplier cost, or an attrition credit. M4 does not yet have the Reservation facts required to determine actual utilization, booking channel, occupied rate, applicable tax, or a collected early-departure fee.

The invariant is:

> Attrition policy exists. Attrition liability does not yet exist.

Slice 3A.0 maps these inputs onto shipped records. If existing versioned terms cannot retain the nightly minimums, the 100% consequence, and the zero-utilization rates and quoted tax without parsing prose, stop before Slice 3A.1 and accept only the smallest typed policy record those fields require. Do not generalize that record into a Hotel settlement engine.

---

## 15. Early departure and cancellation

The early-departure rule remains readable/versioned Supplier policy:

> Without notice at or before check-in, an early departure incurs one room night plus tax on the guest folio. A collected early-departure fee reduces otherwise owed sleeping-room attrition.

Slice 3A creates no early-departure charge or attrition credit.

No separate group-cancellation schedule was supplied.

The Hotel workspace therefore shows:

> No separate group-cancellation schedule specified.

Do not infer a cancellation ladder from attrition.

---

## 16. Refund clarification and agreement history

The original supplied wording called the Group deposits non-refundable.

The governing clarification is:

> The Hotel refunds the agency on or before November 20, 2027, the amount actually paid toward the deposits minus the attrition shortfall.

Slice 3A preserves these facts unambiguously:

- original wording: deposits described as non-refundable, retained as history;
- governing clarification: the sentence above;
- payer: the agency;
- refund recipient: the agency;
- refund deadline: 2027-11-20;
- Staff actor and recorded time; and
- an optional Staff-recorded reference or note.

File upload is optional. Slice 3A creates no refund transaction.

The clarification is recorded on the current editable draft before first activation.

It does not require a successor because no governing predecessor exists yet.

Prefer existing versioned Supplier-term and evidence authority. Slice 3A.0 maps these facts onto shipped records. If that representation can retain them only by parsing prose, stop before Slice 3A.1 and accept a narrowly typed agreement-policy record for this clarification. Do not introduce `HotelRefundClarification` by default.

Review displays the governing sentence. "Governing clarification recorded" is not a substitute for that sentence.

---

## 17. Agreement identity and Supplier confirmation

The original contract/signature date and Hotel group/confirmation number are not known in the canonical scenario.

The UI leaves them blank.

It must not:

- infer contract date from Group creation, confirmation, or evidence dates;
- fabricate a Supplier identifier; or
- turn later confirmation evidence into the missing original contract date.

If generic activation requires Supplier confirmation evidence, use existing generic authority, including an allowed no-identifier reason where applicable.

Hotel Slice 3A does not introduce Cruise agreement-confirmation semantics merely to make the two verticals look alike.

---

## 18. Review and activation

Review is write-free.

For the canonical fixture it assembles at least:

    Pre-cruise hotel stay
    Hilton Fort Lauderdale Marina
    Nov 4–6, 2027 · 2 nights

    Inventory
    Nov 4 · 5 Standard · 2 Deluxe
    Nov 5 · 10 Standard · 5 Deluxe
    22 contracted room nights

    Supplier rates
    Standard · $173 / $173 / $193 / $213
    Deluxe   · $223 / $223 / $243 / $263
    Net · Noncommissionable

    Original pretax contracted-room-revenue target
    $4,156.00

    Illustrative quoted tax exposure
    $685.74

    Deposits
    $415.60     · Oct 1, 2026
    $1,870.20   · May 7, 2027
    $1,870.20   · Oct 4, 2027

    Room-assignment cutoff
    Oct 3, 2027 · 5:00 p.m. America/New_York

    Concession
    $150 Destination Fee and related tax waived

    Additional nights
    Nov 1–3 · Subject to Hotel availability

    Attrition
    Nov 4 minimum 7 · Nov 5 minimum 15
    100% of lost room revenue · liability not calculated
    Zero utilization: $173 Standard · $223 Deluxe · 16.5% quoted tax

    Refund
    The Hotel refunds the agency on or before November 20, 2027, the amount actually paid minus the attrition shortfall.
    Original nonrefundable wording retained as history

Activation uses existing generic Supplier Arrangement activation authority.

Activation does not create:

- Supplier payment;
- Agency deposit payment;
- refund;
- guest folio;
- attrition charge;
- Client Service; or
- Client Trip.

---

## 19. Governing and successor versions

After activation, governing Supplier definitions are read-only.

The UI distinguishes:

    Active · Version 1

from a later proposal:

    Draft · Version 2
    Proposed changes to Active Version 1

A later confirmed additional night or changed contracted room category, capacity, rate, cutoff, deposit, or governing agreement term follows existing M3 amendment/successor authority.

The original 22-room-night block and original deposit requirements are not silently rewritten.

Slice 3A does not build a generalized Hotel post-activation inventory-maintenance system unless an existing M3 command already expresses the exact required change safely.

---

## 20. Hotel workspace

The normal Hotel Supplier Composition workspace uses the established DepartureDesk Composition shell.

It does not add a second application sidebar.

The Hotel-local information architecture is:

    Hotel
    ├── Overview
    ├── Stay
    ├── Room inventory
    ├── Supplier rates
    ├── Agreement
    └── Review & activate

Agreement presents, without collapsing their write boundaries:

    Agreement
    ├── Concessions
    ├── Deposits
    ├── Deadlines
    ├── Attrition
    ├── Other policies
    └── Clarifications

The visual language may reuse successful Cruise workspace conventions.

Cruise-specific persistence, commands, readiness predicates, and terminology do not become Hotel authority merely because the presentation is similar.

---

## 21. Advanced fallback

Typed Hotel screens fail closed when a persisted definition cannot be represented losslessly.

Unsupported shapes remain readable and provide an exact Advanced Supplier-planning destination.

The Hotel adapter must not:

- choose an arbitrary Item, Occurrence, Resource, or Pool;
- ignore an extra Pool;
- flatten date-varying quantities;
- guess an occupancy rate;
- reinterpret a generic cost definition as a supported Hotel rate;
- silently discard an unsupported agreement term; or
- rewrite supported sibling definitions to normalize an unsupported shape.

Where an unsupported definition can be isolated safely, supported sibling facts remain available through the normal Hotel workspace.

---

## 22. Authorization and tenancy

Slice 3A does not broaden Composition authorization.

Staff with existing Supplier-management authority may create or mutate Hotel Supplier facts.

A Viewer may read the Hotel summary through an already view-authorized Composition route but cannot save, amend, or activate Hotel terms.

Hotel management routes use the same denial as existing Composition management routes. Slice 3A does not introduce Hotel-specific authorization semantics. An authenticated Viewer without `manage_departures` is redirected. This supersedes the walkthrough sentence that Hotel management routes return not found to a Viewer.

Identifiers belonging to another Agency return not found for both read and management paths.

Every nested record is resolved through the authorized Agency, Departure, Arrangement, version, and selected Hotel Item as appropriate.

---

## 23. Implementation slices

Acceptance of this document authorizes the following implementation order.

### 3A.0 — Persistence compatibility gate

No product decision is delegated to Slice 3A.0. This contract already defines the required semantics.

Before Hotel UI, Slice 3A.0 maps those semantics onto shipped schema and commands and proves:

- one non-capacity-bearing Stay Occurrence, November 4, 2027 at 3:00 p.m. through November 6, 2027 at noon, `America/New_York`;
- two dated inventory Occurrences, November 4–4 and November 5–5, with both local times blank;
- a capacity-managed Hotel Item;
- Stay × Standard and Stay × Deluxe classified `not_applicable`;
- four `pooled` category/night pairs, each with one numeric `block` Pool in `resource_units`, openings 5, 2, 10, and 5;
- one-night-per-Pool Supplier economics, rejecting a two-night multiplier that would produce $8,312;
- base plus occupancy-position rate representation;
- an explicit net/noncommissionable term and no `expected_commission` component;
- three `fixed_amount` deposits of 41560, 187020, and 187020 minor units, and no fourth requirement for the $0 October 4 adjustment;
- preservation of the original $4,156 derivation;
- the structured attrition inputs in §14;
- the versioned original wording and governing refund facts in §16;
- generic Supplier confirmation whose evidence date stays distinct from the blank original contract date;
- stable Hotel Item identity, including a second Item that does not change the Hilton totals.

If every required fact maps losslessly onto shipped M3 records, Slice 3A.0 is documentation and proof only.

If one does not, stop before Slice 3A.1. Draft and accept the smallest foundation amendment necessary for that specific incompatibility. Do not add an `occurrence_role` column or a generalized adapter.

**Exit:** the accepted Hotel contract is shown to fit shipped records, or the specific incompatibility is named and Hotel UI has not started. The [3A.0 result](#3a0-result) names four incompatibilities. Hotel UI has not started.

### 3A.0 result

Recorded 2026-09-30 from `test/services/m4d1_slice3a0_hotel_persistence_compatibility_test.rb`. The test builds the Hilton draft with shipped Supplier commands and asserts both the facts those records store and the four facts they cannot distinguish. Slice 3A stays Accepted. This result does not authorize Slice 3A.1.

No Hotel route, view, command, migration, `occurrence_role` column, or generalized adapter was introduced.

#### Lossless mappings

| Accepted fact | Shipped record or command |
| --- | --- |
| Capacity-managed Hotel Item | `SetItemCapacityManagement` on `ArrangementItemDefinition` |
| Stay Occurrence, 2027-11-04 15:00 through 2027-11-06 12:00, `America/New_York`, with no Pool | `CreateServiceOccurrence` / `ServiceOccurrenceDefinition`; no `CapacityPool` for that Occurrence |
| November 4 and November 5 inventory Occurrences, each a single day with both local times blank | `CreateServiceOccurrence` / `ServiceOccurrenceDefinition` |
| Stay × Standard and Stay × Deluxe are `not_applicable` | `ClassifyCapacityPair` / `CapacityPairDefinition` |
| Each inventory night × each Resource is `pooled`, with one numeric `block` Pool in `resource_units` | `ConfigureCapacityPairWithPool` / `CapacityPool` and `CapacityPoolDefinition` |
| Openings 5, 2, 10, and 5 | `CapacityPoolDefinition#proposed_opening_quantity` |
| Activation pair count is six | `CapacityPairDefinition` rows for the Hotel Item |
| A second Hotel Item leaves those openings, the $4,156 target, and the three deposits unchanged | `CreateArrangementItem` on the same Arrangement |
| Each inventory night is forecast with `expected_billable_nights` of 1. The base occupancy result is $1,311 + $2,845 = $4,156. An assumption of 2 nights evaluates to $8,312 and is not the stored Hilton evaluation | `CreateSupplierCostUsageAssumption`, `CreateSupplierCostOccupancyProfile`, `EvaluateSupplierCostForecast` |
| Positions one and two share a room/night base. Positions three and four add $20 occupancy increments. One room evaluates to Standard $173 / $173 / $193 / $213 and Deluxe $223 / $223 / $243 / $263. No `expected_commission` component is created | `CreateSupplierCostComponent` and `EvaluateSupplierCostForecast`. The shared base is one `resource_nights` charge of 17300 or 22300 minor units, because an occupancy range of positions 1–2 is counted once per matching position. Positions 3 and 4 are `occupancy_position_nights` charges of 2000 minor units. The forecast does not store the completed Triple or Quad prices 19300, 21300, 24300, or 26300 |
| Three `fixed_amount` deposits, 41560, 187020, and 187020 minor units, due 2026-10-01, 2027-05-07, and 2027-10-04. No fourth requirement. `percentage_of_cost_sources` is not used | `CreateSupplierDepositRequirementDefinition` / `SupplierDepositRequirementDefinition`. The Hilton requirements are saved with a `fixed_date` parameter whose only key is `date` |
| One actionable `rooming_list_due` Deadline, `fixed_local_datetime`, `local_date_time`, 2027-10-03 17:00 `America/New_York` | `CreateSupplierDeadlineDefinition` / `SupplierDeadlineDefinition`. The Hilton cutoff is saved with a datetime parameter and no other rule keys |
| Generic Supplier confirmation stores an evidence date, channel, note, and `confirmed_without_identifier_reason`. That evidence date is not a contract date or Hotel number | `ActivateSupplierArrangementVersion` writes `SupplierConfirmation`. No `SupplierArrangementCruiseAgreementConfirmation` row is created. `SupplierConfirmation` has no `contract_date` or `group_reference` column |

#### Confirmed incompatibilities

Free-text `description`, `notes`, `reference_note`, and untyped `rule_parameters` values do not satisfy the gate. Slice 3A.1 remains blocked until each of these has a lossless typed representation, the smallest foundation amendment for that gap is accepted, and this proof is rerun.

| Accepted fact the shipped model cannot distinguish | What the test examined |
| --- | --- |
| Explicit net/noncommissionable Supplier terms, distinguishable from commission not yet entered | `SupplierCostSource`, `SupplierCostDefinition`, and `SupplierCostComponent` have no noncommissionable or net-terms column. `economic_role` offers `expected_commission`, and the Hilton definitions create none. A source whose notes say the terms are net and a source with blank notes have the same typed cost state |
| A fixed $1,870.20 requirement that preserves the original 45% / $4,156 derivation, including nightly totals $1,311 and $2,845 and the 10/45/45 relationship, distinguishable from the same fixed amount with no known derivation | The Hilton deposits do not carry that derivation. A separate `CreateSupplierDepositRequirementDefinition` probe submits nightly totals, shares, and a basis amount; the saved `fixed_date` parameters keep only `date`. `description` is a 500-character string. Two deposits with the same typed amount fields and different descriptions are not distinguishable as derived versus underived |
| The structured attrition inputs in §14: nightly minimums 7 and 15, a 100% shortfall consequence, and the $173 / $223 / 16.5% zero-utilization fallback, distinguishable from arbitrary policy prose | No attrition table exists. `SupplierDeadlineDefinition` and `SupplierDepositRequirementDefinition` have no columns for those inputs. A separate deadline probe submits those keys and policy prose; the saved parameters keep only `datetime`, and `description` remains a string. The Hilton cutoff is not that probe |
| The structured refund facts in §16: original nonrefundable wording, governing clarification, Agency payer, Agency recipient, and the November 20, 2027 deadline, distinguishable from note text that must later be parsed | `ActivateSupplierArrangementVersion` persists `SupplierConfirmation` with no columns for those facts. `reference_note` is a string. Two confirmations created by that command differ in the note and share the same evidence date, channel, and missing-identifier reason |

#### Slice 3A.1

Authorize Slice 3A.1 only after the 3A.0 result shows that every required Slice 3A fact has a lossless persisted representation. This result does not. Draft and accept the smallest foundation amendment for each named incompatibility, apply it, and rerun `test/services/m4d1_slice3a0_hotel_persistence_compatibility_test.rb`.

### 3A.1 — Stay, room inventory, and Supplier rates

Implement the central Hotel Supplier facts:

- Hotel Item/stay;
- Standard and Deluxe Resources;
- dated nightly Pools;
- 5/2 then 10/5 quantities;
- independent sibling saves;
- stable Item-ID navigation;
- second-Item isolation proof;
- occupancy-position rates;
- Single/Double/Triple/Quad review;
- explicit net/noncommissionable term and no `expected_commission` component;
- $1,311 + $2,845 = $4,156 evaluation from one night per Pool;
- quoted tax exposure kept separate;
- Advanced fallback for unsupported shapes.

**Exit:** Staff can accurately establish and review the Hotel stay, nightly room supply, and Supplier economics without flattening inventory or creating Client facts.

### 3A.2 — Agreement and operational requirements

Implement:

- Destination Fee concession;
- November 1–3 availability-only terms;
- three `fixed_amount` Supplier Deposit Requirements and no fourth requirement;
- preservation and display of the original $4,156 derivation;
- the October 3 `rooming_list_due` cutoff, with Mark complete, Reschedule, and Waive on Agreement → Deadlines;
- the structured attrition inputs in §14, with no calculator or charge;
- early-departure readable policy;
- no-separate-cancellation-schedule state;
- original nonrefundable wording plus the governing refund facts in §16.

Use existing generic/versioned structures wherever they preserve the agreement safely.

Do not introduce calculation engines for future Reservation or settlement behavior.

**Exit:** Staff can record the Supplier agreement facts required before activation without creating payments, liabilities, folios, refunds, or Client records.

### 3A.3 — Review, activation, lifecycle, and closure

Implement:

- consolidated Hotel workspace;
- write-free review;
- generic activation integration;
- governing read-only presentation;
- successor proposed presentation;
- Viewer and Staff authorization proof using the existing Composition denial;
- cross-Agency isolation;
- Advanced fallback;
- responsive and accessibility proof against [the interface contract](../ui/interface-contract.md): 375, 768, reference desktop, and 1280 pixels, plus skip link, landmarks, headings, visible focus, keyboard order, accessible names, validation association, and reflow;
- complete Hilton browser acceptance journey;
- documentation/status updates.

**Exit:** the Accepted Hilton Staff walkthrough can be completed through normal Hotel Supplier Composition from initial stay creation through reviewed/activated Supplier terms.

---

## 24. Blocking proof

The end-to-end browser proof starts from Departure Composition and establishes that Staff can:

1. Open the exact Hilton Supplier Arrangement.
2. Create the November 4–6 `Pre-cruise hotel stay`.
3. Leave the unspecified original contract date and Supplier confirmation/group number blank.
4. Create a second Hotel Item.
5. Reopen the Hilton Item by stable Item ID.
6. Add Standard and Deluxe Resources.
7. Save November 4 inventory as 5 Standard / 2 Deluxe.
8. Save November 5 inventory as 10 Standard / 5 Deluxe.
9. See exactly 22 contracted room nights without flattening the two dates.
10. Enter and reopen the Single/Double/Triple/Quad Supplier rates.
11. See $1,311 + $2,845 = $4,156 pretax from one night per Pool, and reject a two-night multiplier that would produce $8,312.
12. See the quoted 16.5% / $685.74 exposure separately from the Group deposit basis.
13. See an explicit persisted net/noncommissionable term, and no `expected_commission` component.
14. Record the $150 Destination Fee and related-tax waiver without creating a negative cost.
15. Record November 1–3 as availability-only terms without creating Pools.
16. Create exactly three `fixed_amount` deposits for $415.60, $1,870.20, and $1,870.20. The October 4 pre-stay adjustment is $0, so no fourth Supplier Deposit Requirement exists.
17. See their 10%/45%/45% relationship to the preserved original $4,156 derivation.
18. Change a later draft fact without silently rebasing those agreed deposits.
19. Record the October 3, 5:00 p.m. Eastern `rooming_list_due` cutoff exactly once.
20. Mark that Deadline complete, reschedule it, or waive it from Agreement → Deadlines through existing Deadline authority.
21. See the nightly minimums of 7 and 15, the 100% consequence, and the $173 / $223 plus 16.5% zero-utilization fallback, without a materialized attrition charge.
22. See the early-departure rule without a materialized charge or credit.
23. See that no separate cancellation schedule was supplied.
24. Preserve the original nonrefundable wording as history.
25. Record, on the current pre-activation draft, that the Hotel refunds the agency on or before November 20, 2027, the amount actually paid minus the attrition shortfall, with the agency as payer and refund recipient.
26. Review the exact Supplier version without writes, including that governing refund sentence.
27. Activate through existing Supplier activation authority, keeping the confirmation evidence date distinct from the blank original contract date.
28. View the governing version read-only.
29. View a later successor as proposed without changing the governing version.
30. Return to Departure Composition without creating or connecting a Client Service.

The second Hotel Item must not alter the Hilton Item's 22-room-night total, $4,156 original basis, deposits, rates, or agreement summary.

At least one invalid sibling save must prove previously valid work remains intact and submitted invalid values remain available for correction.

---

## 25. Invariants

Slice 3A is not complete unless these remain true:

> **Supplier facts ≠ Client offering**

> **Guest stay ≠ nightly Supplier inventory**

> **Room nights ≠ physical rooms ≠ sold rooms**

> **Opening Supplier inventory ≠ Client reservations**

> **Supplier rate ≠ Client price**

> **Original contractual deposit basis ≠ current Supplier-cost forecast**

> **Deposit requirement ≠ deposit payment**

> **Quoted tax exposure ≠ Group deposit**

> **Attrition policy ≠ attrition liability**

> **Early-departure policy ≠ early-departure charge**

> **Supplier refund term ≠ recorded refund**

> **Active Supplier version ≠ successor Draft**

---

## 26. Non-goals

Slice 3A does not implement:

- Hotel Offer Design;
- Client room choices;
- `hotel_room:` Client choice keys;
- Client pricing;
- Package placement;
- included/optional placement;
- Client booking;
- traveler room assignment;
- actual pickup/utilization tracking;
- rooming-list contents;
- guest folios;
- guest payments;
- Agency deposit payments;
- Supplier refund transactions;
- attrition calculation;
- attrition Obligations;
- early-departure calculation;
- automatic inventory release;
- automatic deposit rebasing;
- Hotel commission;
- required Hotel document upload/storage;
- generalized non-Cruise adapter infrastructure;
- Transportation;
- Activity, Meal, or Excursion support;
- mixed-DMC routing.

---

## 27. Acceptance decisions

Acceptance of Slice 3A locks these decisions:

1. **Hotel remains Supplier Composition only.** No Client Service connection is created.
2. **Stable Item identity is mandatory.** Hotel work is scoped by Arrangement Item ID.
3. **The guest stay and nightly inventory are distinct facts.** The Stay Occurrence is November 4, 2027, 3:00 p.m. through November 6, 2027, noon, and is not capacity-bearing. Each inventory night is its own single-day Occurrence. Nightly quantities are Pool openings, not labels.
4. **Pair classification is part of the graph.** The Hotel Item is capacity-managed. Stay × each room Resource is `not_applicable`. Each night × each room Resource is `pooled`, with one numeric `block` Pool in `resource_units`. No `occurrence_role` column is authorized.
5. **Room inventory varies by night.** The canonical block is 5/2 then 10/5, totaling 22 room nights.
6. **Hotel rates preserve their economic shape.** Positions one and two share a room/night base; positions three and four add occupancy-position increments. Each Pool is evaluated once for that inventory night.
7. **Net/noncommissionable is an explicit persisted term.** Slice 3A creates no `expected_commission` component.
8. **The original $4,156 pretax target is distinct from later forecasts.** A two-night multiplier that would produce $8,312 is rejected.
9. **The three scheduled deposits are `fixed_amount` requirements** of 41560, 187020, and 187020 minor units. Later Supplier changes do not silently rebase them. `percentage_of_cost_sources` is not used. The $0 October 4 adjustment creates no fourth requirement.
10. **The $4,156 derivation is preserved with those requirements.** Slice 3A does not authorize a generalized deposit-basis engine. Slice 3A.0 may require only the smallest added persistence if shipped evidence or term fields cannot retain the basis.
11. **The October 3 cutoff is one actionable `rooming_list_due` Deadline** at 5:00 p.m. America/New_York, with local date-time precision. Mark complete, Reschedule, and Waive live on Agreement → Deadlines and call existing Deadline authority. Passing it does not automatically release inventory.
12. **November 1–3 are availability-only terms until separately confirmed.**
13. **The Destination Fee waiver is a Supplier concession, not negative cost or Client discount.**
14. **Attrition inputs are structured and calculation is deferred.** The persisted facts are the 100% consequence, nightly minimums of 7 and 15, and the zero-utilization fallback of $173, $223, and 16.5% quoted tax, plus the readable qualifications in §14. No attrition calculator, Obligation, or charge is created.
15. **Early departure remains policy until later Reservation facts exist.**
16. **No cancellation ladder is inferred.**
17. **The refund clarification preserves named facts.** Original nonrefundable wording stays history. The governing outcome is that the Hotel refunds the agency on or before November 20, 2027, the amount actually paid minus the attrition shortfall. The agency is payer and refund recipient.
18. **Prefer existing versioned Supplier terms for that clarification.** No `HotelRefundClarification` model is authorized by default. Slice 3A.0 stops if shipped terms can retain those facts only by parsing prose.
19. **The original contract/signature date and Supplier group/confirmation number remain blank when unknown.** Confirmation evidence does not become the contract date.
20. **Review is write-free and shows the governing refund sentence.** Activation uses existing generic authority.
21. **Activated terms are read-only; later proposed terms do not mutate the governing version.**
22. **Unsupported shapes fail closed to an exact Advanced destination.**
23. **Hotel management uses existing Composition denial.** A Viewer without `manage_departures` is redirected. Another Agency's identifiers are not found. This supersedes the walkthrough sentence that Hotel management routes return not found to a Viewer.
24. **No generalized non-Cruise adapter is extracted from Hotel alone.**
25. **Slice 3A.0 verifies persistence. It does not make product decisions.** If a required fact does not map losslessly, stop before Slice 3A.1 and accept the smallest foundation amendment for that fact.

---

## 28. Exit

Slice 3A is complete when the canonical Hilton Staff journey can be performed through normal DepartureDesk Supplier Composition and the browser proof establishes:

- one continuous Hotel stay;
- date-varying nightly room inventory;
- stable Hotel Item and Resource identities;
- accurate occupancy-position Supplier rates;
- the $4,156 original Supplier economics;
- fixed Supplier deposit requirements;
- the room-assignment Deadline;
- Supplier concessions and availability-only terms;
- faithfully preserved Hotel policies without premature settlement calculations;
- governing clarification history;
- write-free review and ordinary activation;
- governing versus successor behavior;
- authorization and tenant isolation;
- exact Advanced fallback; and
- no Client Service, Client choice, Client price, Package placement, Reservation, folio, payment, refund, or calculated attrition record created as a side effect.

Completion of Slice 3A does not authorize Transportation implementation.

Per Slice 3R, the next step after Hotel is to draft and accept the Transportation Staff walkthrough and its implementation plan. Shared non-Cruise support may be extracted only if Transportation then proves the same Staff question, shipped command sequence, and stable identity.