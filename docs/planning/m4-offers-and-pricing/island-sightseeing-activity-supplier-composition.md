# Island Sightseeing — Activity Supplier Composition Implementation Plan

**Status:** Shipped 2026-10-02  
**Location:** `docs/planning/m4-offers-and-pricing/island-sightseeing-activity-supplier-composition.md`  
**Parent:** [M4D.1 — Departure Composition Workspace](m4d1-departure-composition-workspace.md)  
**Boundary authority:** [M4D.1 Slice 3R — Non-Cruise Adapter Boundary](m4d1-slice3r-non-cruise-adapter-boundary.md)  
**Workflow authority:** [Island Sightseeing — Activity Supplier Composition Staff Walkthrough](island-sightseeing-activity-staff-walkthrough.md)  
**Compatibility evidence:** [Island Sightseeing supplier compatibility](island-sightseeing-supplier-compatibility.md)  
**Canonical fixture:** [Port Promotions — Island Sightseeing 2027](../fixtures/port-promotions-island-sightseeing-2027-canonical-scenario.md), Approved 2026-10-02  
**Prerequisite:** Transportation Supplier Composition shipped  
**Authorizes:** The Activity Supplier Composition workflow in this plan  
**Does not authorize:** Meal or `dining` support, Client prices, Package placement, Client Trip enrollment, traveler records, Supplier Payments, invoices, Obligations, gratuity collection, mixed-DMC support, M4E, M5, or a generalized non-Cruise adapter framework

The [planning index](../README.md) remains the status authority. This shipped plan authorizes the Island Sightseeing Activity Agreement workflow and no other Activity work.

This plan implements the first typed Activity Supplier Composition workflow for Port Promotions — Island Sightseeing.

It does not add an `excursion` Item category. The shipped Item category remains `activity_attraction`; **Activity** is the Staff-facing family term.

---

## 1. Purpose

Implement the ordinary Staff workflow accepted by the Island Sightseeing walkthrough:

```text
Composition
→ Suppliers
→ Port Promotions
→ Activity Agreement
→ Activity details
→ Capacity
→ Supplier rate
→ Minimum enrollment
→ Deadlines and payment terms
→ Agreement terms
→ Review
→ Supplier confirmation
→ Activation
→ governing read mode
→ successor for a contractual change
```

The implementation remains layered on the shipped Supplier Arrangement, version, Item, Occurrence, Resource, capacity, cost, Deadline, agreement-reference, Supplier-confirmation, activation, and successor foundations.

It does not introduce a parallel Activity lifecycle.

The plan resolves only the persistence and orchestration gaps proven by the compatibility gate and accepted walkthrough.

---

# 2. Canonical topology

Island Sightseeing uses:

```text
Supplier Arrangement
Port Promotions
│
└── Activity Item
    Island Sightseeing
    └── one Service Occurrence
        └── Participant Resource
            └── one 40-space traveler_positions Pool
```

The stable identities are:

- one `SupplierArrangement`;
- one `ArrangementItem`;
- one `ServiceOccurrence`;
- one `SupplierResource`;
- one `CapacityPool`.

The Item category is:

```text
activity_attraction
```

A second Activity Item under the same Arrangement remains independently identifiable by stable Item ID.

The ordinary typed Activity path supports one Occurrence and one participant-capacity Pool per Activity Item.

Additional Occurrences, Resources, or Pools route to **Advanced Supplier planning**.

---

# 3. Locked fixture facts

## Supplier

Port Promotions.

## Departure

Smith Family Reunion.

## Activity

Island Sightseeing.

## Schedule

- November 8, 2027
- 9:30 a.m.–3:00 p.m.
- `America/Nassau`

## Place

- CocoCay, Bahamas
- exact meeting point not provided

The typed Activity screen presents:

```text
Location: CocoCay, Bahamas
Meeting point: Not provided
```

The shipped generic occurrence endpoint fields may retain CocoCay as the coarse origin and destination value.

They are not presented as an exact pickup/drop-off pair.

## Capacity

```text
40 controlled participant spaces
```

## Operating minimum

```text
Minimum enrollment: 5 travelers
Below minimum: Supplier decides whether to operate
```

This is not a guaranteed minimum charge.

## Supplier cost

```text
$50 per confirmed participating traveler
```

Includes:

- transportation;
- guide services;
- admissions;
- taxes.

Excludes:

- gratuities.

## November 1 requirements

November 1, 2027 carries four distinct meanings:

1. review minimum enrollment;
2. final participant count due;
3. full payment due;
4. non-cancellable / non-refundable boundary.

## Payment amount

Unknown in Supplier Composition until a real confirmed-participant count exists.

---

# 4. Compatibility result

The compatibility gate proves three classes of behavior.

## Fits shipped Supplier foundation

Reuse without changing meaning:

- `activity_attraction` Item;
- one scheduled Occurrence;
- exact date, start time, end time, and time zone;
- generic occurrence place fields as coarse CocoCay values;
- one Participant Resource;
- one `block` Pool measured in `traveler_positions`;
- opening quantity 40;
- contracted Supplier cost Source/Definition/Component;
- `unit_rate`;
- quantity basis `persons`;
- `expected_persons` for forecast only;
- date-only Supplier Deadlines;
- agreement wording;
- Supplier confirmation identity/evidence;
- generic activation;
- successor copying and stable Item identity.

## Typed Activity orchestration

Activity supplies typed commands/read models/UI for:

- Activity creation;
- schedule and place;
- participant capacity;
- per-person Supplier rate;
- operating-minimum terms;
- November 1 requirements;
- agreement wording;
- Activity review;
- Supplier confirmation;
- governing/proposed version presentation.

## Named incompatibilities

This plan resolves:

1. operating minimum and Supplier discretion have no structured contractual home;
2. Supplier operate/cancel outcome has no operational home;
3. full-payment amount has no confirmed-participant quantity;
4. full-payment due action has no proven typed payment Deadline;
5. rate inclusions/exclusions have no proven agreement-term home;
6. Activity Supplier confirmation has no freeze or safe version-wide typed boundary.

---

# 5. Activity operating-minimum terms

## Problem

The fixture contains a contractual threshold:

```text
minimum enrollment = 5 persons
below minimum = Supplier may decide whether to operate
```

The shipped `minimum_quantity_shortfall` is financially different.

At four participants it would increase a $200 per-person forecast to $250.

That behavior is prohibited for Island Sightseeing.

The operating minimum therefore must not be represented as:

- a Supplier cost component;
- a Capacity Pool minimum;
- a Deadline field;
- a cancellation action;
- prose alone if the typed workflow must evaluate whether review is required.

## Decision

Add Supplier persistence for the Island Sightseeing operating threshold, with the closed semantics required by this Activity slice.

The record may live in a generally named table when that fits existing Supplier architecture. A general storage shape does not accept cross-family semantics. This plan does not claim Meal or other-family reuse. Any later reuse requires its own compatibility proof.

Concept:

```text
SupplierOperatingThresholdDefinition
```

Fields:

```text
agency
departure
supplier_arrangement
supplier_arrangement_version
arrangement_item
service_occurrence optional
threshold_kind
quantity_basis
minimum_quantity
below_threshold_authority
position
copied_from
```

For the first implementation:

```text
threshold_kind = minimum_enrollment
quantity_basis = persons
minimum_quantity = 5
below_threshold_authority = supplier_decision
```

Closed values should remain narrow.

Do not create a universal formula language.

## Meaning

This definition records only the contractual rule:

```text
Below 5 enrolled participants,
Port Promotions may decide whether the activity operates.
```

It does not record:

- current enrollment;
- whether the threshold has been met;
- a Supplier decision;
- cancellation;
- a financial shortfall;
- a Client rule.

## Ownership

The definition is:

- exact-version-owned;
- Item-scoped;
- copied to successors;
- editable only in draft;
- frozen by Activity Supplier confirmation.

---

# 6. Supplier operating outcome

## Problem

The contract defines Supplier discretion below the threshold.

The later fact:

```text
Supplier chose to operate
```

or:

```text
Supplier chose to cancel
```

is operational history.

It must not mutate the frozen threshold definition.

## Decision

Introduce an operational record separate from the version-owned contractual term.

Concept:

```text
SupplierOperatingThresholdOutcome
```

`SupplierOperatingThresholdOutcome` may reference only the threshold definition on the current Supplier-confirmed governing Arrangement version.

That requires:

- the Arrangement is active and that version is governing;
- that exact version is Supplier-confirmed;
- the referenced threshold definition belongs to that governing version;
- stable Item and Occurrence ownership match.

The outcome also records:

- observed participant quantity when known;
- outcome;
- Supplier evidence;
- occurred and recorded timestamps;
- actor.

Closed outcomes for this slice:

```text
operate
cancel
```

No `automatic_cancel`.

No outcome is inferred from a count.

## Important boundary

Creating an outcome requires an explicit Staff action based on Supplier evidence.

The system never performs:

```text
count < 5
→ cancel
```

automatically.

If the Supplier elects to operate below five, the per-person cost remains unchanged.

## Current enrollment dependency

The outcome model may record an observed participant quantity supplied by Staff/evidence, but that quantity does not become Client Trip enrollment authority.

If no authoritative enrollment record exists yet, the UI labels it as an observed Supplier-review quantity, not as the canonical traveler count.

The implementation must not create traveler rows.

---

# 7. Participant capacity

The existing capacity model remains authoritative.

The typed Activity shape uses:

```text
classification = pooled
inventory_mode = block
measurement_basis = traveler_positions
unit_label = participant spaces
opening quantity = 40
```

The Participant Resource does not use `maximum_occupancy`.

The Activity UI shows:

```text
40 participant spaces
```

It does not derive that number from Resource occupancy.

It does not equate:

```text
40 participant spaces
```

with:

```text
40 confirmed participants
```

Future Client Trip enrollment will consume or reserve those spaces under later authority.

This slice does not create consumption records.

---

# 8. Supplier rate and forecast

Each Activity Item owns one Item/Occurrence-scoped Supplier cost Source with one contracted calculated definition.

Supported typed component:

```text
economic_role = supplier_charge
calculation_kind = unit_rate
quantity_basis = persons
amount = $50
```

The typed label is:

> Supplier rate per participant

## Forecast authority

`expected_persons` remains the forecast input.

Examples:

```text
4  → $200
5  → $250
20 → $1,000
40 → $2,000
```

These are write-free planning economics.

`expected_persons` is not:

- confirmed enrollment;
- controlled capacity;
- minimum enrollment;
- payable quantity.

The typed workflow must preserve those distinctions.

## Unsupported cost shapes

The Activity typed workflow fails closed to Advanced if the Item contains:

- additional Supplier cost Sources;
- multiple contracted definitions;
- more than the supported per-person charge component;
- a `minimum_quantity_shortfall`;
- occupancy profiles;
- Resource-unit pricing;
- percentage/minimum structures not named by this plan.

The typed workflow must never select `.first` from an ambiguous generic cost graph and continue.

---

# 9. Rate inclusions and exclusions

## Problem

The fixture requires Staff to retain:

```text
Includes transportation, guide services, admissions, and taxes.
Gratuities are not included.
```

These facts are explanatory contract terms.

They are not additive Supplier-cost components.

## Decision

Use version-owned agreement wording rather than cost components. No existing agreement-reference kind fits this sentence. Do not repurpose cancellation, deposit, or fee kinds.

Add one agreement-reference kind:

```text
SupplierAgreementReference.kind = rate_inclusions
scope = Activity Item
```

The name describes Supplier rate coverage. It is not a generic notes kind. ADR 0015’s agreement-reference boundary is the home: the sentence changes how Staff read the rate and does not become cost arithmetic. Adding the kind extends the closed agreement-reference catalog.

The wording for Island Sightseeing is:

```text
Supplier rate includes transportation, guide services, admissions, and taxes.
Gratuities are not included.
```

The reference is:

- Item-scoped;
- exact-version-owned;
- copied to successors;
- frozen by Activity confirmation.

Do not split included services into cost components.

---

# 10. November 1 minimum-enrollment review

Schedule the review with the shipped Deadline shape the compatibility proof already stored:

```text
deadline_type = other
other_label = Minimum-enrollment review
kind = informational
due_on = 2027-11-01
precision = date_only
time_zone = America/Nassau
```

`other_label` is the Staff-facing label. This slice adds no `minimum_enrollment_review` Deadline type.

The Deadline schedules the November 1 review. It does not store:

- threshold `5`;
- Supplier discretion;
- the Supplier outcome.

Those belong to the threshold definition and the later operational outcome. Because the Deadline is informational, it does not open a commitment. The typed UI must not derive the operating threshold from the Deadline.

---

# 11. Final participant count Deadline

Use existing:

```text
final_count_due
```

with:

```text
due_on = 2027-11-01
precision = date_only
America/Nassau
```

The Deadline is scoped to Island Sightseeing.

Completing it means Staff recorded/provided the Supplier-required final count action.

It does not:

- create Client travelers;
- become enrollment authority;
- change participant capacity;
- set `expected_persons`;
- calculate the payment amount.

If the existing Deadline completion mechanism supports evidence, use it unchanged.

---

# 12. Full-payment due requirement

## Problem

November 1 is a real contractual Supplier due date.

The amount is:

```text
$50 × confirmed participating travelers
```

but Supplier Composition has no authoritative confirmed-participant quantity.

## Decision

Do not calculate or persist a dollar amount in this slice.

Do not broaden `SupplierAmountDueDefinition`. ADR 0013 keeps that record as a derived amount whose quantity is `quantity_at` on a capacity-backed pool. Island Sightseeing has a known due date and a known $50 rate, and it has no authoritative confirmed-participant quantity, so the amount is not derivable.

Add one exact-version Supplier payment requirement:

```text
SupplierPaymentRequirementDefinition
```

For Island Sightseeing it records:

```text
kind = full_payment
due_on = 2027-11-01
currency = USD
rate source = the contracted $50/person Supplier cost component
quantity status = authoritative quantity unavailable
```

It must not supply a quantity from:

- `expected_persons`;
- the Pool quantity of 40;
- the operating minimum of 5.

It does not create exposure, a Supplier commitment, a payable amount, an Obligation, or a Supplier Payment.

No implementation may use `expected_persons × $50` as the contractual amount due.

---

# 13. Payment-due action

The full-payment requirement is not a Deposit Requirement.

It is also not merely a free-text `other` Deadline.

## Decision

The payment requirement is the one authoritative November 1 payment-due record. Do not create a duplicate `payment_due` Deadline.

The Activity summary renders that requirement as:

```text
Full payment due Nov 1
Amount depends on confirmed participant count
```

The final-count Deadline and the informational minimum-review Deadline remain separate because they are different Staff facts.

---

# 14. Cancellation wording

Use the existing `SupplierAgreementReference` kind:

```text
cancellation
```

Item-scoped to Island Sightseeing.

Store the governing wording:

```text
Before November 1, 2027, the Agency may reduce enrollment or cancel under the stated terms.

Beginning November 1, 2027, confirmed participation is non-cancellable and non-refundable.
```

The reference does not:

- cancel the Activity;
- calculate a fee;
- create a Client refund rule;
- record the below-minimum Supplier decision.

Also store the informational Deadline the compatibility proof already stored:

```text
deadline_type = cancellation_cutoff
kind = informational
due_on = 2027-11-01
precision = date_only
time_zone = America/Nassau
```

That Deadline shows the November 1 boundary. The agreement-reference wording is the contractual sentence. The Deadline does not cancel the Activity, and enrollment below five does not infer cancellation.

---

# 15. Activity Agreement workspace

Primary path:

```text
Composition
→ Suppliers
→ Port Promotions
→ Activity Agreement
```

Persistent sections:

1. Agreement overview
2. Activity details
3. Capacity
4. Supplier rate
5. Minimum enrollment
6. Deadlines and payment terms
7. Agreement terms
8. Review
9. Supplier confirmation and activation

The ordinary Activity path does not reproduce generic Supplier-planning terminology.

---

# 16. Activity details editor

The typed form includes:

## Identity

- Activity name

## Place

- Location
- Meeting point display

For Island Sightseeing:

```text
Location: CocoCay, Bahamas
Meeting point: Not provided
```

The exact meeting point remains unavailable.

## Schedule

- Service date
- Start time
- End time
- time zone

All are actual fixture facts.

---

# 17. Activity Agreement summary

For the fixture:

```text
Island Sightseeing
Port Promotions

Nov 8, 2027 · 9:30 a.m.–3:00 p.m.
CocoCay, Bahamas
Meeting point: Not provided

Capacity
40 participant spaces

Operating minimum
5 travelers
Below minimum: Supplier decides whether to operate

Supplier rate
$50 per confirmed participant
Includes transportation, guide services, admissions, and taxes
Gratuities not included

Nov 1
Review minimum enrollment
Final participant count due
Full payment due
Booking becomes non-cancellable and non-refundable

Payment amount
Depends on confirmed participant count
```

When an explicit below-minimum Supplier outcome later exists, display it separately:

```text
Minimum-enrollment outcome
Supplier confirmed activity will operate
```

or:

```text
Minimum-enrollment outcome
Supplier cancelled activity
```

Do not rewrite the contractual threshold text.

---

# 18. Activity review

Activity review is write-free.

Every retained Item on the exact Supplier Arrangement Version must be a supported Activity Item.

Each Activity Item must have:

- category `activity_attraction`;
- one supported Occurrence;
- valid date/start/end/time-zone facts;
- one supported participant Resource;
- one `traveler_positions` block Pool;
- controlled opening quantity;
- one contracted per-person Supplier rate;
- no financial minimum component;
- an operating-threshold definition;
- minimum-enrollment review requirement;
- final-count Deadline when contractually required;
- full-payment requirement;
- cancellation wording;
- rate-inclusion wording;
- no unsupported generic shapes.

## Version-wide boundary

If any retained Item is:

- Hotel;
- Transportation;
- Cruise;
- `dining`;
- another unsupported category;

or an Activity Item that does not match the typed Activity shape:

```text
Advanced Supplier planning
```

The typed Activity workflow cannot record Supplier confirmation.

This preserves exact-version confirmation semantics.

---

# 19. Activity Supplier confirmation

Supplier confirmation means:

> Port Promotions confirmed the reviewed Activity agreement represented by this exact Supplier Arrangement Version.

Use existing:

```text
SupplierConfirmation
```

No Activity-specific confirmation identity.

Confirmation is separate from activation.

Generic activation blockers do not automatically prevent Supplier confirmation unless they identify a fact required by the Activity review contract.

---

# 20. Activity confirmation freeze

After Supplier confirmation, freeze the agreement-defining Activity facts on that exact version:

- Activity Item definition;
- Activity Occurrence definition;
- participant Resource definition;
- Pool definition/opening quantity;
- contracted $50/person cost graph;
- operating-threshold definition;
- minimum-enrollment review definition;
- final-count Deadline definition/coverage;
- full-payment requirement definition;
- cancellation agreement reference;
- rate-inclusion agreement reference.

## Operational records remain mutable through their own authority

Do not freeze:

- Deadline completion/reschedule/waiver where existing authority permits;
- later capacity events;
- later operating-threshold outcomes.

The contractual rule:

```text
minimum 5
Supplier decides below 5
```

is frozen.

The later operational fact:

```text
Supplier chose operate
```

is not a mutation of that rule.

## Implementation

Do not add `activity_attraction` branches to `LodgingConfirmationFreeze`.

Reuse shared freeze infrastructure only if Hotel, Transportation, and Activity now prove the same mechanics.

Vertical predicates remain explicit.

---

# 21. Pre-activation correction

A confirmed Activity draft cannot be edited in place.

Use the already-extracted:

```text
ReviseConfirmedSupplierArrangementVersion
```

if Activity satisfies that command's vertical eligibility contract.

Required result:

```text
confirmed Activity draft
→ abandoned historical exact version
→ copied unconfirmed draft
```

Supplier confirmation is not copied.

Stable Activity Item identity is preserved.

Do not create `ReviseConfirmedActivityAgreement` unless the shared command cannot express the accepted behavior.

---

# 22. Activation

Activation remains:

```text
ActivateSupplierArrangementVersion
```

through a thin typed Activity command if needed for blocker translation/acknowledgements.

Requirements:

- Departure permits activation;
- Activity exact version passed typed review;
- version is Supplier confirmed;
- generic activation readiness passes;
- contracted rate is forecast-ready;
- no unsupported retained Item exists.

The unresolved payment **amount** does not itself block activation, because the contract rule and due date are known while the authoritative enrollment quantity does not yet exist.

Do not fabricate a payable amount to satisfy activation.

---

# 23. Governing agreement and successor

After activation:

- governing Activity agreement is read-only;
- proposed successor is separately labeled;
- contractual changes require the shipped Supplier Arrangement successor.

Examples requiring a successor:

- $50 rate changes;
- capacity 40 changes as a contractual ceiling/opening term;
- minimum enrollment 5 changes;
- Supplier discretion rule changes;
- schedule changes;
- place changes;
- November 1 contractual requirements change;
- cancellation wording changes;
- rate-inclusion wording changes.

Operational records do not require a successor merely because they occur later:

- Deadline completion;
- Supplier operate/cancel outcome;
- supported capacity events.

---

# 24. Below-minimum operational workflow

When an authoritative or Staff-observed review quantity is below five, the Activity workspace may show:

```text
Minimum enrollment review
Below contractual minimum of 5
Supplier decision required
```

Staff then records explicit Supplier evidence and one outcome:

```text
Operate
Cancel
```

## Operate

The Activity remains operational.

The $50/person contractual rate is unchanged.

No five-person minimum charge is created.

## Cancel

Recording `operate` or `cancel` records Supplier evidence and history only. A `cancel` outcome does not itself cancel the Occurrence. Staff must explicitly invoke the existing Occurrence-cancellation authority in a separate auditable action.

This slice creates no financial, Client, refund, or enrollment consequence from the outcome. Supplier decision, operational state, financial consequence, and Client consequence stay separate until an explicit command bridges them.

---

# 25. Advanced shapes

Route to Advanced Supplier planning rather than rewriting:

- multiple Occurrences on one Activity Item;
- multiple participant Resources;
- multiple capacity Pools;
- `on_request` or externally managed capacity;
- Resource-unit Activity pricing;
- hourly pricing;
- tiered participant pricing;
- guaranteed minimum charge;
- percentage/minimum cost components;
- multiple contracted cost sources;
- cancellation fee ladders;
- multiple operating thresholds;
- automatic Supplier cancellation rules;
- unknown/mixed sibling verticals;
- Client Trip enrollment;
- traveler assignments;
- Supplier invoice/payment records.

---

# 26. Supplier additions justified by this Activity

This Activity slice adds the following Supplier records. A general table name does not accept Meal or other-family reuse.

## A. Supplier operating-threshold definition

Exact-version contractual terms for this Activity:

```text
threshold_kind = minimum_enrollment
quantity_basis = persons
below_threshold_authority = supplier_decision
```

## B. Supplier operating-threshold outcome

Operational evidence attached only to the Supplier-confirmed governing threshold. It is separate from the versioned contract.

## C. Supplier payment requirement

One exact-version full-payment requirement with a known due date and rate and an unresolved quantity. `SupplierAmountDueDefinition` stays the capacity-backed derived amount in ADR 0013. Forecast assumptions, the Pool of 40, and the minimum of 5 are not the missing quantity.

## D. Agreement-reference kind `rate_inclusions`

The Item-scoped wording in section 9. It has no cost arithmetic.

---

# 27. Do not extract a generalized Activity/Meal adapter

Activity is the first proof of this shape.

Meal remains outside the plan.

After Activity ships, test a canonical `dining` fixture against the resulting contracts.

Extract shared Activity/Meal support only when Meal proves the same:

- Staff question;
- command sequence;
- stable identities;
- threshold/payment semantics.

Do not create a generic “bookable event” adapter in anticipation.

---

# 28. Delivery sequence

Each implementation slice requires this parent plan to be Accepted.

## A.0 — Authority

Satisfied by this acceptance on 2026-10-02:

- the Port Promotions fixture is Approved;
- the Activity walkthrough is Accepted;
- this plan is Accepted;
- the planning index records that standing.

No application code belongs to A.0. A.1 through A.7 shipped on 2026-10-02.

## A.1 — Activity foundations

Ship:

- Activity Agreement entry/shell;
- one stable Activity Item;
- one Occurrence;
- typed place/schedule editor;
- one Participant Resource;
- one 40-space `traveler_positions` block Pool;
- exact-shape detection.

Exit:

```text
Island Sightseeing
Nov 8 · 9:30–3:00
CocoCay
40 participant spaces
```

is faithfully represented.

## A.2 — Per-person Supplier rate and wording

Ship:

- one contracted `$50/person` rate;
- `expected_persons` forecast preview;
- exact cost-shape detector;
- rate inclusion/exclusion agreement wording.

Exit:

```text
4 → $200
5 → $250
20 → $1,000
40 → $2,000
```

without linking the 40-space Pool to billed quantity.

## A.3 — Operating minimum

Ship:

- `SupplierOperatingThresholdDefinition`;
- minimum = 5;
- below-threshold Supplier discretion;
- minimum-enrollment review Deadline (`other`, informational, `other_label` Minimum-enrollment review);
- read/review presentation.

No Supplier outcome yet.

Exit: four people still forecast $200.

## A.4 — Deadlines and full-payment requirement

Ship:

- final-count Deadline;
- `SupplierPaymentRequirementDefinition` for full payment due November 1;
- unresolved quantity, with no dollar amount;
- cancellation wording and the informational `cancellation_cutoff`.

Do not extend `SupplierAmountDueDefinition`. Do not add a `payment_due` Deadline.

Exit:

```text
Full payment due Nov 1
Amount depends on confirmed participant count
```

with no fabricated quantity.

## A.5 — Operating outcome

Ship:

- explicit Supplier threshold outcome;
- Supplier evidence;
- `operate` / `cancel`;
- no automatic threshold inference;
- explicit consequence boundary: `cancel` records evidence and does not cancel the Occurrence.

Exit: the outcome command records `operate` or `cancel` only against the Supplier-confirmed governing threshold, and it leaves the rate and the contractual definition unchanged.

## A.6 — Review, confirmation, freeze, activation

Ship:

- write-free Activity review;
- all-retained-Items supported Activity gate;
- Supplier confirmation;
- Activity freeze;
- activation;
- typed blocker translation;
- Viewer and tenancy proof.

Exit: mixed/unfinished exact versions cannot be typed-confirmed.

## A.7 — Lifecycle and closure

Ship/reuse:

- governing read mode;
- successor creation;
- confirmed-draft revision through shared command;
- stable Item identity;
- canonical browser proof;
- planning status update.

---

# 29. Required canonical proof

The completed browser/system proof must show:

1. Open/create Port Promotions from Composition.
2. Add Island Sightseeing as an Activity.
3. Persist November 8, 2027, 9:30 a.m.–3:00 p.m. in `America/Nassau`.
4. Show CocoCay as location and meeting point as Not provided.
5. Create exactly 40 controlled participant spaces.
6. Prove Resource `maximum_occupancy` is not used as group size.
7. Record `$50/person`.
8. Show forecast:
   - 4 → $200;
   - 5 → $250;
   - 20 → $1,000;
   - 40 → $2,000.
9. Record rate inclusions/exclusion without extra cost components.
10. Record operating minimum 5 with Supplier discretion.
11. Prove no `minimum_quantity_shortfall`.
12. Record the November 1 minimum-enrollment review as an informational `other` Deadline whose `other_label` is Minimum-enrollment review.
13. Record the final-count Deadline for Nov 1.
14. Record one full-payment requirement for Nov 1 with the quantity unresolved, and prove there is no `payment_due` Deadline and no amount-due row for that requirement.
15. Prove `expected_persons`, the Pool of 40, and the minimum of 5 do not become the payable quantity.
16. Record the cancellation agreement wording, the informational `cancellation_cutoff` on November 1, and the `rate_inclusions` agreement wording.
17. Attempt an invalid save on Island Sightseeing while a second supported Activity Item exists. Prove the command rolls back atomically and the sibling Item, Occurrence, capacity, rate, threshold, Deadlines, and agreement wording remain unchanged.
18. Add an unfinished second Activity and prove typed confirmation refuses it.
19. Add a Hotel or Transportation sibling and prove typed confirmation routes to Advanced.
20. Restore a supported all-Activity version and Supplier-confirm it.
21. Prove agreement-defining Activity edits fail after confirmation.
22. Activate.
23. Record below-minimum Supplier outcome `operate` on that governing version; prove the rate remains $50/person.
24. Record another scenario or outcome `cancel` on a governing version; prove the Occurrence stays in place until a separate Occurrence-cancellation command, and prove no Client or financial consequence is created.
25. Reschedule or complete the final-count Deadline without mutating the contract.
26. Create a contractual successor.
27. Prove the stable Island Sightseeing Item ID survives.
28. Prove Supplier confirmation is not copied.
29. Prove governing predecessor facts remain unchanged.
30. Prove Viewer read-only behavior.
31. Prove cross-Agency access returns not found.
32. Complete the canonical workflow without opening generic Supplier planning.

---

# 30. Explicit non-goals

This plan does not authorize:

- `$57.50` Client pricing;
- included/optional/add-on placement;
- Service Offer connection;
- Client Trip enrollment;
- traveler records;
- automatic capacity consumption;
- Supplier Payment posting;
- Supplier invoices;
- Obligations;
- settlement;
- Client cancellation/refund behavior;
- gratuity collection;
- exact port meeting point;
- automatic cancellation below minimum;
- guaranteed minimum billing;
- Meal/`dining`;
- Air/Rail;
- mixed-DMC;
- generic event adapter infrastructure;
- M4E;
- M5.

---

# 31. Acceptance decisions

Accepting this plan approves:

1. `activity_attraction` remains the persisted category; Activity is Staff-facing language.
2. Island Sightseeing uses one Item, one Occurrence, one Participant Resource, and one `traveler_positions` block Pool.
3. Forty means controlled participant spaces, not billed or enrolled participants.
4. `$50/person` uses `expected_persons` for forecast only.
5. `expected_persons` never becomes confirmed enrollment or payable quantity.
6. Operating minimum 5 is a contractual operational threshold, not financial minimum billing.
7. Below threshold, Supplier discretion is part of the frozen contract.
8. A later operate/cancel decision is separate operational history and is never inferred automatically.
9. Activity persistence for the operating threshold uses the closed values `minimum_enrollment`, `persons`, and `supplier_decision`. Meal and other-family reuse stay unclaimed.
10. The operate/cancel outcome is a separate operational record and may reference only the Supplier-confirmed governing threshold.
11. A `cancel` outcome records evidence only. Occurrence cancellation is a separate explicit Staff command.
12. The November 1 minimum-enrollment review uses an informational `other` Deadline and `other_label` Minimum-enrollment review.
13. November 1 full payment is one `SupplierPaymentRequirementDefinition`. It is not `SupplierAmountDueDefinition` and not a `payment_due` Deadline.
14. That payment requirement records the date, the $50 rate, and an unresolved quantity. It does not create exposure, a commitment, a payable amount, an Obligation, or a Payment, and it does not read `expected_persons`, the Pool of 40, or the minimum of 5.
15. `rate_inclusions` is a new Item-scoped `SupplierAgreementReference` kind with no cost arithmetic.
16. Cancellation wording remains separate from the below-minimum Supplier outcome.
17. Typed Activity Supplier confirmation reviews every retained Item on the exact version.
18. Mixed or unsupported versions route to Advanced Supplier planning.
19. Supplier confirmation freezes Activity agreement-defining facts, including the threshold and Supplier discretion, and it does not freeze later operational outcomes.
20. Generic Supplier Arrangement activation and successor authority remain unchanged.
21. Meal remains a later comparison and does not share this adapter by assumption.
22. Canonical proof includes atomic rollback that leaves a supported sibling Activity unchanged.

---

# 32. Exit

Activity Supplier Composition is complete when Staff can operate Island Sightseeing through:

```text
Composition
→ Activity Agreement
→ details
→ participant capacity
→ per-person Supplier rate
→ operating minimum
→ deadlines and full-payment terms
→ agreement wording
→ Review
→ Supplier confirmation
→ activation
→ below-minimum Supplier outcome
→ governing read mode
→ successor
```

without:

- turning the operating minimum into minimum billing;
- treating controlled capacity as enrollment;
- treating forecast persons as confirmed enrollment;
- fabricating a payable amount;
- automatically cancelling below the threshold;
- merging cancellation wording with Supplier disposition;
- adding Client or traveler records;
- introducing a Meal or universal event adapter.