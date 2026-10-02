# HA.1 — Hotel Agreement workspace and read model

**Status:** Shipped 2026-10-01  
**Location:** `docs/planning/m4-offers-and-pricing/hotel-agreement-workspace-read-mode.md`  
**Parent:** [Hotel Agreement](hotel-agreement.md)  
**Sequence:** First Hotel Agreement implementation slice  
**Prerequisite:** Supplier complexity rebaseline merged and green  
**Scope:** Typed read workspace, exact-version resolution, section summaries, navigation, thin Deposit and Deadline editors  
**Does not authorize:** new agreement-reference kinds, Supplier confirmation mutation, activation, reviewed-none persistence

---

## 1. Goal

Ship the first usable Hotel Agreement workspace for one lodging Item, including thin Deposit and Deadline editors over existing commands, without introducing new Supplier-domain authority.

HA.1 proves that existing operational Hotel records and `SupplierAgreementReference` can be assembled safely into one Hotel-native read model.

The primary fixture is Hilton Fort Lauderdale Marina.

---

## 2. Deliverables

HA.1 ships:

- Item-scoped Hotel Agreement route;
- `HotelAgreementsController#show`;
- exact-version resolution;
- typed `HotelAgreementWorkspace`;
- Agreement overview/header;
- Stay summary;
- room-block summary;
- Supplier-rate summary;
- Deposit summary;
- Deadline summary;
- Agreement Terms checklist;
- Supplier confirmation status;
- specialized-editor navigation;
- thin Hotel Deposit editor;
- thin Hotel Deadline editor;
- Advanced Supplier planning fallback;
- governing/successor version switcher;
- derived section states.

It does not add new business-domain tables.

---

## 3. Exact-version resolution

Given Agency, Departure, Supplier Arrangement, and lodging Item:

1. verify exact ownership;
2. if an explicit version is requested, load only that version;
3. otherwise, if a successor draft exists, select it;
4. otherwise select the governing/current version;
5. reject a version outside the Arrangement;
6. reject a non-lodging Item.

Never combine records from two versions.

---

## 4. Read-model contract

Introduce a write-free query/read model:

```text
HotelAgreementWorkspace
```

It should return Hotel-shaped values rather than requiring the view to interpret generic graph topology.

Suggested result areas:

```text
identity
version
stay
inventory
rates
deposits
deadlines
terms
confirmation
source_default
section_states
findings
```

The exact Ruby structure may use immutable result objects/Data classes consistent with repository conventions.

Do not put mutation behavior in the read model.

---

## 5. Stay derivation

Resolve the exact-version Hotel Stay for this Item.

Requirements:

- distinguish overall Stay from nightly inventory occurrences;
- one valid Stay → render;
- zero → `Not started`;
- multiple plausible Stay records → `Needs attention`.

Hilton expected values:

```text
Arrival: 2027-11-04
Departure: 2027-11-06
Check-in: 15:00
Checkout: 12:00
Zone: America/New_York
```

Provide `Edit stay` navigation to the existing typed editor.

---

## 6. Inventory derivation

Room categories are exact-version Supplier Resources belonging to this Item.

Nightly inventory is derived from the exact-version capacity graph for:

```text
Item × inventory-night Occurrence × room-category Resource
```

The overall Stay occurrence is excluded from inventory rows.

Numeric Pool definitions render quantity.

`on_request` and `externally_managed` render their semantic labels rather than zero or inferred quantity.

If more than one authoritative Pool could fill one night/category cell, mark Room block `Needs attention`.

Hilton expected matrix:

| Night | Standard | Deluxe | Total |
| --- | ---: | ---: | ---: |
| Nov 4 | 5 | 2 | 7 |
| Nov 5 | 10 | 5 | 15 |

Provide navigation to the existing room-block editor.

---

## 7. Rate derivation

A Hotel rate source is relevant only when scoped to this:

- Arrangement Item;
- inventory-night Occurrence;
- room-category Resource.

Use existing cost-authority precedence:

1. ready contracted;
2. ready estimate;
3. no usable authority.

Display `Contracted` or `Estimated` explicitly.

A section using an estimate remains `In progress`.

Do not infer noncommissionable merely from absence of commission components.

Display actual `commission_treatment`.

Hilton expected contracted display:

| Category | Single | Double | Triple | Quad |
| --- | ---: | ---: | ---: | ---: |
| Standard | $173 | $173 | $193 | $213 |
| Deluxe | $223 | $223 | $243 | $263 |

Commission treatment:

> Noncommissionable

When dates have identical semantic rates, the read model may collapse them for display.

If one night differs, surface the exception.

Provide navigation to the existing rate matrix.

---

## 8. Deposit derivation

Include a Supplier Deposit Requirement when existing coverage:

- directly includes this Hotel Item; or
- resolves entirely to Supplier cost authority owned by this Item.

Do not infer ownership from Arrangement membership or single-Item convenience.

Shared requirements remain one record and may render:

> Shared across agreement

No coverage/ambiguous coverage renders under Advanced/Needs attention rather than silently assigning it.

Hilton expected operational requirements, after the Agreement acceptance scenario records coverage that includes the Hilton Item:

```text
2026-10-01 — $415.60
2027-05-07 — $1,870.20
2027-10-04 — $1,870.20
```

That coverage is one link, `{ arrangement_item_id: <this item> }`, written through the existing deposit command. Those three lines are the stay schedule only after that coverage exists.

The shipped persistence fixture leaves those requirements with empty coverage. That case stays off the schedule and renders as unassigned under Needs attention, with a link to Advanced Supplier planning. HA.1 does not backfill that fixture.

The `deposit_derivation` agreement reference may be summarized beneath the schedule.

Do not calculate these deposits from reference wording.

---

## 9. Deadline derivation

Include Deadline definitions whose existing coverage resolves to this Hotel Item.

Shared Deadline definitions remain one record.

Unsupported valid shapes remain visible but read-only as Advanced configuration.

Hilton expected Deadline:

```text
Rooming list due
2027-10-03 17:00 America/New_York
```

Explicit regression:

```text
2027-11-20 must not appear as a Deadline.
```

---

## 10. Agreement Terms checklist

Render the closed seven-row Hotel checklist:

```text
Deposit derivation
Attrition
Deposit refund
Destination Fee
Additional nights
Early departure
Cancellation
```

Existing exact-version references render:

> Recorded

Missing references render:

> Not recorded

Do not classify absence as an error.

Do not persist reviewed-none.

HA.1 does not yet make the four later kinds writable.

---

## 11. Source default derivation

If all relevant existing references share the same source/provenance value, expose it as the derived source default.

If provenance is mixed, return no common default.

HA.1 does not persist a separate source object.

---

## 12. Confirmation display

Read exact-version Supplier confirmation.

The header shows role, confirmation, and activation together:

```text
Role: Draft, Proposed successor draft, Current governing agreement, or Superseded agreement
Confirmation: Not Supplier confirmed, or Supplier confirmed
Activation: Not yet activated, or Activated
```

A proposed successor that is already Supplier-confirmed shows Proposed successor draft and Supplier confirmed together.

Do not offer confirmation mutation.

If the version is confirmed, agreement-reference edit affordances are absent/read-only.

---

## 13. Section-state derivation

### Stay

- absent → Not started
- one valid Stay → Recorded
- ambiguous/broken → Needs attention

### Room block

- no room categories/inventory → Not started
- partial setup → In progress
- valid intended inventory graph → Recorded
- conflicting/ambiguous graph → Needs attention

### Rates

- none → Not started
- estimates or incomplete category/night coverage → In progress
- displayable contracted rate authority for required numeric inventory → Recorded
- ambiguous/unsupported authority → Needs attention/Advanced

### Deposits

- no relevant requirements → Not started
- relevant but incomplete → In progress
- supported valid requirements → Recorded
- ambiguous ownership → Needs attention

### Deadlines

Same pattern as Deposits.

### Agreement Terms

Do not derive contractual completeness.

Report only term counts and per-row Recorded/Not recorded.

---

## 14. Unsupported shapes

A valid generic M3 shape that Hotel Agreement cannot represent must never be rewritten.

HA.1 should:

- keep page rendering;
- degrade only the affected section/row;
- identify it as Advanced configuration or Needs attention;
- link to Advanced Supplier planning.

---

## 15. Navigation

Composition → Suppliers should expose:

> Open Hotel Agreement

Agreement then links to:

- Edit stay
- Edit room block
- Edit rates
- Edit deposits
- Edit deadlines
- Advanced Supplier planning

Edit stay, Edit room block, and Edit rates use the existing typed editors. Those routes may be minimally adapted to support:

- `return_to=hotel_agreement`;
- exact Item/version context.

Do not duplicate those forms.

Edit deposits and Edit deadlines open the HA.1 thin editors. They call the existing Deposit Requirement and Deadline commands and return to the Agreement page.

The deposit editor exposes amount, due date, and scope. Scope for this stay is one coverage link, `{ arrangement_item_id: <this item> }`.

The deadline editor exposes the deadline label, due moment, and the same stay scope.

Occurrence, resource, and pool coverage, percentage-of-cost deposits, contributor links, and other already-valid generic shapes stay read-only on the Agreement page and open Advanced Supplier planning.

---

## 16. Tests

### Read-model tests

Directly prove:

- exact-version resolution;
- successor default;
- explicit governing selection;
- Stay identification;
- nightly inventory mapping;
- on-request/external supply;
- rate selection;
- commission treatment;
- Deposit relevance, including the covered Hilton schedule and empty coverage as unassigned;
- Deadline relevance;
- agreement-reference relevance;
- source-default derivation;
- section states;
- unsupported/ambiguous states.

### Request/controller tests

Prove:

- Agency isolation;
- Departure/Arrangement/Item ownership;
- lodging-only boundary;
- exact version cannot escape Arrangement;
- viewer read-only behavior;
- `manage_departures` mutation affordance behavior;
- successor default;
- explicit governing view;
- Advanced fallback.

### Thin-editor tests

Prove the Deposit and Deadline editors:

- write this stay as one coverage link `{ arrangement_item_id: <this item> }`;
- return to Hotel Agreement;
- leave occurrence, resource, pool, percentage-of-cost, and other generic shapes unchanged and reachable through Advanced Supplier planning.

### Multi-Item isolation

Create a second Hotel Item and prove its:

- Stay;
- Pools;
- Resources;
- costs;
- Item-scoped references

do not appear on the first Item’s Agreement.

Shared records appear only when coverage actually includes both.

### Unsupported-shape regression

At least one valid generic Deposit/Deadline/rate shape that typed Hotel cannot edit must:

- remain intact;
- render safely;
- be labeled Advanced/Needs attention;
- link to Advanced Supplier planning.

### System journey

Hilton Staff journey:

1. Composition → Suppliers.
2. Open Hotel Agreement.
3. Verify Item/version header.
4. Verify Stay.
5. Verify room block.
6. Verify rate matrix.
7. Verify deposits in both proofs: with Item coverage recorded, the schedule shows the three fixed amounts; with the persistence fixture’s empty coverage unchanged, those amounts are unassigned and off the schedule.
8. Verify rooming-list Deadline.
9. Verify seven Agreement Terms rows.
10. Verify Supplier confirmation state.
11. Open one specialized editor.
12. Return to Agreement.

---

## 17. Acceptance criteria

HA.1 is complete when:

- Hotel Agreement is reachable for a lodging Item;
- default exact-version behavior is deterministic;
- no cross-version merge occurs;
- Hilton renders the accepted Stay, inventory, rates, and Deadline correctly;
- the deposit schedule shows the three fixed amounts only after Item coverage is recorded, and empty coverage renders as unassigned;
- November 20 is not represented as a Deadline;
- recorded/missing agreement-reference terms are visible without completeness judgment;
- the thin Deposit and Deadline editors are the normal Hotel editing surface for those records;
- generic Supplier vocabulary is absent from the Agreement page and those thin editors;
- unsupported configurations remain intact;
- no new Supplier-domain authority was introduced;
- no new agreement-reference kinds became writable;
- Supplier confirmation and activation remain outside HA.1;
- full suite is green.

---

## 18. Exit / handoff

HA.2 was implemented in the same change as this slice. The parent [delivery note](hotel-agreement.md#28-delivery-sequence) amends the earlier rule that HA.2 starts only after this slice has landed and is green.

[Hotel Review and Activation](hotel-review-and-activation.md) is in progress under the accepted 2026-10-02 amendment.
