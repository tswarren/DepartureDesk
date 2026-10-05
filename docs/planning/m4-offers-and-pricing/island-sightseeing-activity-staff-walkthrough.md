# Island Sightseeing — Activity Supplier Composition Staff Walkthrough

**Status:** Accepted 2026-10-02. This is the Staff journey for the Port Promotions Island Sightseeing activity. It is workflow authority for the Shipped [Activity Supplier Composition plan](island-sightseeing-activity-supplier-composition.md). It does not authorize Activity code.

**Location:** `docs/planning/m4-offers-and-pricing/island-sightseeing-activity-staff-walkthrough.md`

**Boundary authority:** [M4D.1 Slice 3R — Non-Cruise Adapter Boundary](m4d1-slice3r-non-cruise-adapter-boundary.md)

**Fixture:** [Port Promotions — Island Sightseeing 2027](../fixtures/port-promotions-island-sightseeing-2027-canonical-scenario.md), Approved 2026-10-02

**Persistence evidence:** [Island Sightseeing supplier compatibility](island-sightseeing-supplier-compatibility.md), recorded 2026-10-02

**Layer:** Supplier Composition only

**Does not authorize:** Activity code by itself, a generic minimum field, Client prices, Package placement, Client Trip enrollment, traveler records, Supplier Payments, Meal or `dining` support, mixed-DMC support, M4E, or a generalized non-Cruise adapter

---

## 1. Purpose

This walkthrough defines the ordinary Staff workflow for recording and operating one Activity Supplier agreement in DepartureDesk.

The canonical scenario is Port Promotions, Island Sightseeing, for the Smith Family Reunion.

It settles Staff meaning for the six gaps named by the compatibility pass:

- an operating minimum that is not a guaranteed charge;
- a full-payment requirement whose dollar amount has no confirmed-participant count yet;
- a full-payment due action that is not a deposit and not a label-only Deadline;
- cancellation wording that is distinct from the Supplier’s below-minimum decision;
- rate inclusions and the gratuity exclusion;
- Supplier confirmation that reviews the whole exact version.

“Excursion” stays product language. The Item category Staff see is Activity. The shipped category remains `activity_attraction`. This walkthrough does not add an `excursion` category.

Meal stays out. `dining` is not assumed to share this adapter. A later Meal fixture may be tested against an accepted Activity shape. It is not part of the first Activity implementation plan.

This walkthrough settles the Staff concepts. The Shipped [Activity Supplier Composition plan](island-sightseeing-activity-supplier-composition.md) names the persistence and the delivery slices. No second compatibility pass is required unless that plan’s implementation chooses persistence the recorded proof did not cover.

## 2. Canonical Supplier agreement

### Supplier

**Port Promotions**

### Departure

**Smith Family Reunion**

The Approved Hilton stay checks out November 6, 2027. The Celebrity sailing is November 6–13, 2027. Island Sightseeing is during the cruise and does not overlap the Hotel stay.

### Service family

**Activity**

### Currency

USD, inherited from the Departure

### Time zone

The activity is local to CocoCay: `America/Nassau`. The Departure time zone stays `America/New_York`.

### Supplier Arrangement

One Port Promotions Supplier Arrangement contains the Island Sightseeing Activity Item.

The Arrangement represents the Supplier agreement. The Item represents the activity. Staff reopen that activity by its stable Item id. A second Activity under the same Supplier must not change which Item this workspace opens.

## 3. Canonical activity

| Fact | Value |
| --- | --- |
| Activity | Island Sightseeing |
| Location | CocoCay, Bahamas |
| Meeting point | Not provided |
| Service date | November 8, 2027 |
| Departure from the port | 9:30 a.m. |
| Return to the port | 3:00 p.m. |
| Duration | 5 hours 30 minutes |
| Controlled participant spaces | 40 |
| Operating minimum | 5 travelers |
| Supplier rate | $50 per confirmed participant |
| Included | Transportation, guide, admissions, and taxes |
| Excluded | Gratuities |
| November 1, 2027 | Review minimum enrollment; final participant count due; full payment due; booking becomes non-cancellable and non-refundable |
| Payment amount | Depends on confirmed participant count |

The contract date, confirmation number, and exact port meeting point remain unspecified.

## 4. Staff entry

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

From **Smith Family Reunion → Composition → Suppliers**, Staff open or create the Port Promotions Supplier Arrangement, then choose **Add activity**. They enter the Activity Item name **Island Sightseeing**, the November 8 schedule, `America/Nassau`, and the contracting Supplier as the default Service Provider.

The screen shows:

```text
Location: CocoCay, Bahamas
Meeting point: Not provided
```

It does not present origin and destination as an exact pickup. Storing CocoCay, Bahamas in both shipped endpoint fields is a coarse place name. It is not a meeting-point record, and this walkthrough adds no location column.

One Occurrence carries the date and both local times. Staff do not invent an end time. The duration is the difference of 9:30 a.m. and 3:00 p.m.

## 5. Capacity

Port Promotions reserves up to 40 participant spaces for the group. That quantity is Supplier-controlled group capacity.

Staff see:

```text
40 participant spaces
```

The 40 is one block of participant spaces. It is not a Resource occupancy, and it is not the number of travelers who will be charged. Passenger or participant capacity is not derived by multiplying a vehicle occupancy.

## 6. Supplier rate

The contracted Supplier cost is $50 for each confirmed participating traveler. The rate includes transportation, guide services, admissions, and taxes. Gratuities are not included.

Those inclusions and the gratuity exclusion are explanatory Supplier contract terms. They are not additional Supplier cost components. Staff record them as agreement wording shown with the rate. This walkthrough does not name a new agreement-reference kind. The implementation plan chooses the wording home. The sentence is part of the first Activity slice, because the fixture requires Staff to record the rate and its inclusions.

A forecast may illustrate `expected_persons`:

| Illustrated participants | Forecast |
| ---: | ---: |
| 4 | $200 |
| 5 | $250 |
| 20 | $1,000 |
| 40 | $2,000 |

Those figures are planning illustrations. `expected_persons` is not confirmed enrollment and is never the payable quantity. The Pool of 40 does not become the billed quantity. Four illustrated participants stay $200 while the Pool remains 40.

## 7. Operating minimum

Staff record:

```text
Minimum enrollment: 5 travelers
Below minimum: Supplier decides whether to operate
```

This is separate from the $50 rate. It is not a guaranteed minimum charge. If Port Promotions elects to operate with fewer than five travelers, the Supplier charge remains $50 for each confirmed participant. Four confirmed participants cost $200, not $250.

The shipped `minimum_quantity_shortfall` bills the shortfall and is the wrong tool. The walkthrough does not add a generic minimum field. Whether this threshold is reusable for Meal or other families is undecided.

When enrollment is below five, the screen states that the Supplier decides whether to operate. The count does not cancel the activity, and it does not raise the charge.

The threshold of 5 and the Supplier’s discretion below that threshold are both contractual terms. The later outcome of one below-minimum review is a recorded Supplier decision: operate, or cancel. That decision is operational history. It is not a cost component, not a Deadline field, and not an amendment to the contractual terms. No such decision mechanism exists yet. The implementation plan must not invent one by inferring cancellation from a quantity below five.

## 8. November 1 requirements

November 1, 2027 is seven days before the activity. Four meanings share that date and stay separate:

| Staff meaning | What it is |
| --- | --- |
| Review minimum enrollment | The date to determine whether five travelers are enrolled and, if not, to obtain the Supplier’s decision |
| Final participant count due | Staff provide Port Promotions with the confirmed count |
| Full payment due | A dated Supplier requirement. The dollar amount depends on the confirmed participant count |
| Non-cancellable boundary | Confirmed participation becomes non-cancellable and non-refundable |

The review date can be scheduled. It does not store the number 5 or the Supplier’s discretion. Those stay with the operating minimum in section 7.

### Full payment

Staff see:

```text
Full payment due Nov 1
Payment amount
Depends on confirmed participant count
```

November 1 is a real Supplier requirement. The amount stays unresolved until an accepted enrollment source exists. Do not substitute `expected_persons`, the 40-space Pool, or the minimum of 5.

`deposit_due` is the wrong name. There is no advance deposit. A label-only `other` Deadline is not payment semantics. Whether the November 1 full-payment date becomes a `payment_due` Deadline or part of a later amount-due construct is left to the implementation plan, after this Staff meaning is accepted. Until that plan, the screen must not present November 1 as a proved payment-due action that already has a typed Deadline home. Staff still see the dated requirement and the unresolved amount as specified above.

## 9. Cancellation wording

Agreement terms display:

```text
Before November 1, 2027, the Agency may reduce enrollment or cancel under the stated terms.
Beginning November 1, 2027, confirmed participation is non-cancellable and non-refundable.
```

That wording is not a Client refund policy. It is not the below-minimum operate-or-cancel decision. Falling below five after the cutoff does not automatically cancel the activity. If the Supplier elects to operate below the minimum, it charges only for the confirmed participating travelers. After the cutoff, a confirmed traveler who does not attend does not produce a refund from this Supplier term.

## 10. Activity Agreement summary

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
Includes transportation, guide, admissions, and taxes
Gratuities not included

Nov 1
Review minimum enrollment
Final participant count due
Full payment due
Booking becomes non-cancellable and non-refundable

Payment amount
Depends on confirmed participant count
```

## 11. Review and Supplier confirmation

Supplier confirmation means the Supplier confirmed the reviewed Activity agreement on that exact version. It is not activation.

Before confirmation, every retained Item on the exact version is a supported Activity Item and passes this review:

- Activity identity and stable Item id;
- November 8 schedule, both local times, and `America/Nassau`;
- location CocoCay, Bahamas, with meeting point not provided;
- 40 controlled participant spaces;
- the $50 per-participant rate and its inclusion wording;
- the contractual operating-minimum terms: threshold 5 travelers and Supplier discretion below that threshold, kept separate from the rate;
- the November 1 review, final-count, and full-payment requirement, with the amount unresolved;
- the cancellation wording.

Confirmation is refused when any retained Item is not a supported Activity Item, or when an Activity Item on that version has not passed this review. A mixed version that also contains Hotel or Transportation, and an unfinished second Activity, route to **Advanced Supplier planning**. The Island Sightseeing screen does not confirm an exact version after reviewing only one Item.

Needs clarification does not apply to the unresolved payment amount. That amount is explicitly unresolved because confirmed enrollment does not exist yet. It is not an unspecified contract term.

## 12. What confirmation freezes

After Supplier confirmation, the agreement-defining Activity facts are immutable on that exact version:

- the Activity Item definition;
- the Occurrence, including the date, both local times, and the coarse CocoCay place;
- the participant-space Pool, including the opening quantity of 40;
- the contracted $50 per-participant rate;
- the contractual operating-minimum terms: threshold 5 travelers and Supplier discretion below that threshold;
- the November 1 review, final-count, and full-payment requirement;
- the cancellation wording and the rate-inclusion wording.

Those contractual operating-minimum terms are both part of the confirmed agreement. The threshold of 5 and the Supplier’s discretion below that threshold freeze together. Discretion is not presentation layered on top of the number.

The later Supplier decision for a particular below-minimum review—operate or cancel—is operational history, not an amendment to those frozen contractual terms. The split the implementation plan must keep is:

```text
Contractual definition
Minimum = 5
Below minimum = Supplier decides
        ↓
Operational occurrence
Enrollment below 5 on Nov 1
        ↓
Supplier outcome
Operate | Cancel
```

Later operational capacity events stay outside that freeze when the implementation plan can support them without editing the frozen agreement. No decision mechanism for the operate-or-cancel outcome exists yet. This walkthrough does not add an Activity confirmation freeze in code.

## 13. Activation, governing read mode, and successor

Activation uses the shipped Arrangement activation. It is allowed only for a confirmed exact version that passed the Activity review in section 11. Generic activation readiness still applies. An unfinished sibling Item blocks activation; the typed path routes that version to Advanced rather than activating past it.

Governing facts are read-only. A contractual change uses a successor. Examples: the $50 rate, the inclusion wording, the 40-space ceiling, the contractual operating-minimum terms (the threshold and the Supplier’s discretion below it), the schedule, the place, and the November 1 terms. The successor keeps the Island Sightseeing Item id. Proposed successor terms are labeled proposed. `SupplierConfirmation` is not copied.

An operational record of the Supplier’s later operate-or-cancel decision for one below-minimum review does not amend those contractual terms and does not by itself require a successor. That record does not exist yet.

## 14. Explicit exclusions

- Client price, including a $57.50 amount.
- Whether the activity is included, optional, or an add-on.
- Service Offer choices.
- Client Trip enrollment and traveler records.
- Using `expected_persons` as confirmed enrollment or as the payable quantity.
- Supplier Payments, invoices, Obligations, and paid status.
- Gratuity collection.
- Automatic cancellation when enrollment is below five.
- An exact port meeting point.
- Meal, `dining`, and any assumption that a meal shares this adapter.
- A second compatibility pass, unless the implementation plan chooses persistence the recorded proof did not cover.

## 15. Authority

This walkthrough is Accepted 2026-10-02 together with Approval of the Port Promotions fixture. The Shipped [Activity Supplier Composition plan](island-sightseeing-activity-supplier-composition.md) is the implementation authority. Meal is a later comparison and is not part of that plan.
