# ABC Motorcoach — Transportation Supplier Composition Staff Walkthrough

**Status:** Accepted 2026-10-02. This is the Staff journey for the ABC Motorcoach charter. It is workflow authority for a later Transportation implementation plan. It does not authorize Transportation code.

**Location:** `docs/planning/m4-offers-and-pricing/abc-motorcoach-transportation-staff-walkthrough.md`

**Boundary authority:** [M4D.1 Slice 3R — Non-Cruise Adapter Boundary](m4d1-slice3r-non-cruise-adapter-boundary.md)

**Fixture:** [ABC Motorcoach 2027 — Canonical Transportation Scenario](../fixtures/abc-motorcoach-2027-canonical-transportation-scenario-draft.md), Approved 2026-10-02

**Layer:** Supplier Composition only

**Does not authorize:** Transportation implementation, Client transfer pricing, Package placement, traveler manifests, Client Trip selection, Supplier Payments, M4E, Activity/Meal/Excursion support, or generalized non-Cruise adapter infrastructure

---

## 1. Purpose

This walkthrough defines the ordinary Staff workflow for recording and operating a chartered motorcoach Supplier agreement in DepartureDesk.

The canonical scenario is ABC Motorcoach for the Smith Family Reunion.

It proves:

- one Supplier agreement containing multiple independently identifiable Transportation segments;
- fixed Supplier cost per confirmed motorcoach;
- controlled capacity derived from confirmed vehicle units;
- additional vehicle capacity available only on request;
- segment-specific final-count Deadlines;
- a shared Supplier payment commitment;
- exact Item isolation;
- Supplier confirmation, activation, governing read mode, and successor behavior without inventing a parallel Transportation domain model.

This walkthrough settles the Staff concepts. A later implementation plan names routes, commands, and code slices.

---

## 2. Canonical Supplier agreement

### Supplier

**ABC Motorcoach**

### Departure

**Smith Family Reunion**

### Service family

**Chartered motorcoach transfers**

### Currency

USD

### Time zone

America/New_York

### Supplier Arrangement

One ABC Motorcoach Supplier Arrangement contains two Transportation segment Items.

The Arrangement represents the Supplier agreement.

The segment Items represent independently identifiable services under that agreement.

---

## 3. Canonical segments

### Hotel → Port

| Fact | Value |
| --- | --- |
| Pickup | Hilton Fort Lauderdale Marina |
| Drop-off | Port Everglades |
| Service | November 6, 2027 at 10:00 a.m. |
| Guaranteed motorcoaches | 1 |
| Passenger capacity per coach | 15 |
| Guaranteed passenger capacity | 15 |
| Additional coaches | Up to 2, subject to Supplier confirmation |
| Supplier cost | $200 per confirmed motorcoach |
| Final passenger/luggage count due | November 3, 2027 |

### Port → Airport

| Fact | Value |
| --- | --- |
| Pickup | Port Everglades |
| Drop-off | Fort Lauderdale-Hollywood International Airport |
| Service | November 13, 2027 at 9:30 a.m. |
| Guaranteed motorcoaches | 1 |
| Passenger capacity per coach | 15 |
| Guaranteed passenger capacity | 15 |
| Additional coaches | Up to 2, subject to Supplier confirmation |
| Supplier cost | $175 per confirmed motorcoach |
| Final passenger/luggage count due | November 10, 2027 |

There is no Airport → Port segment in the canonical Supplier fixture.

---

## 4. Staff entry point

From:

> Departure Composition → Suppliers

Staff may choose:

> **Set up Transportation**

The normal typed path should use travel-agency Transportation language.

It should not begin with generic concepts such as:

- Arrangement Item;
- Service Occurrence;
- Supplier Resource;
- Capacity Pair;
- Pool;
- Cost Source;
- Usage Assumption.

Those remain implementation concepts underneath the typed workflow.

If the existing Supplier graph cannot be represented safely by the Transportation adapter, Staff may open:

> **Advanced Supplier planning**

The typed workflow never rewrites an unsupported generic graph merely to make it fit.

---

## 5. Start the Supplier agreement

Staff first records the agreement-level context.

Suggested screen title:

> **ABC Motorcoach Transportation**

Staff chooses or records:

- Supplier;
- internal agreement name;
- currency, derived from the Departure where supported.

The fixture does not specify:

- contract date;
- Supplier confirmation number.

The typed workflow must not require invented values for either.

After the Supplier agreement exists, Staff adds Transportation segments.

---

## 6. Add a segment

Suggested action:

> **Add transportation segment**

Each segment is a stable Transportation Item.

For each segment Staff records:

- segment name;
- pickup location;
- drop-off location;
- service date;
- pickup time;
- time zone;
- passenger capacity per motorcoach;
- guaranteed motorcoach quantity;
- maximum additional motorcoaches available on request.

For the fixture:

```text
Hotel → Port
Hilton Fort Lauderdale Marina
→ Port Everglades
Nov 6, 2027 · 10:00 a.m.
```

and:

```text
Port → Airport
Port Everglades
→ Fort Lauderdale-Hollywood International Airport
Nov 13, 2027 · 9:30 a.m.
```

The system does not infer either segment from the other.

---

## 7. Segment identity

The two segments are independent stable Items.

Staff may reopen either segment directly.

Changing Hotel → Port must not change Port → Airport.

This applies independently to:

- pickup/drop-off;
- schedule;
- guaranteed coach quantity;
- passenger capacity;
- Supplier rate;
- on-request ceiling;
- Deadlines.

Routes and commands use stable segment Item identity, not segment labels or display order.

---

## 8. Vehicle and passenger capacity

The Supplier contracts in **motorcoaches**.

Each motorcoach provides passenger capacity.

For this fixture:

> **1 motorcoach = 15 passenger spaces**

The driver does not consume a passenger space.

### Guaranteed capacity

One motorcoach is initially confirmed on each segment.

The normal summary therefore shows:

```text
1 motorcoach guaranteed
15 passengers
```

The Supplier-controlled quantity is the number of confirmed motorcoaches.

Passenger capacity is derived from:

```text
confirmed motorcoaches × passenger capacity per motorcoach
```

For one coach:

```text
1 × 15 = 15 passengers
```

For two confirmed coaches:

```text
2 × 15 = 30 passengers
```

For three:

```text
3 × 15 = 45 passengers
```

---

## 9. On-request additional coaches

The Supplier may provide up to two additional motorcoaches per segment.

Those vehicles are:

> **On request**

They are not controlled capacity before ABC confirms them.

The page may show:

```text
1 motorcoach guaranteed · 15 passengers
Up to 2 additional coaches on request
Maximum possible capacity · 45 passengers
```

But the 45-passenger ceiling must not be shown as currently available inventory.

Staff does not increase controlled passenger capacity merely by entering an expected traveler count or requesting another coach.

---

## 10. Confirming another motorcoach

If ABC later confirms another coach for Hotel → Port:

```text
Hotel → Port
2 motorcoaches confirmed
30 passenger spaces
```

Port → Airport remains:

```text
1 motorcoach confirmed
15 passenger spaces
```

The change uses existing Supplier capacity authority rather than inventing a Transportation-specific inventory ledger.

The typed workflow must preserve evidence for the additional confirmed vehicle.

The exact evidence fields belong in the implementation plan after compatibility with the existing capacity-event model is checked.

---

## 11. Supplier rates

Supplier pricing is fixed **per confirmed motorcoach**, not per passenger.

### Hotel → Port

```text
$200 per confirmed motorcoach
```

### Port → Airport

```text
$175 per confirmed motorcoach
```

Passenger count does not change Supplier cost while the same number of coaches remains confirmed.

Examples:

| Segment | Confirmed coaches | Supplier cost |
| --- | ---: | ---: |
| Hotel → Port | 1 | $200 |
| Hotel → Port | 2 | $400 |
| Hotel → Port | 3 | $600 |
| Port → Airport | 1 | $175 |
| Port → Airport | 2 | $350 |
| Port → Airport | 3 | $525 |

The combined minimum Supplier exposure is:

```text
$200 + $175 = $375
```

If each segment has two confirmed coaches:

```text
$400 + $350 = $750
```

If each has three:

```text
$600 + $525 = $1,125
```

The typed Transportation workflow should not ask Staff to allocate fixed coach cost across expected passengers.

That belongs to derived forecasting or later Client pricing, not Supplier contractual pricing.

---

## 12. Rate entry

Suggested Transportation terminology:

> **Supplier rate per motorcoach**

Each segment has its own rate.

Staff sees:

```text
Hotel → Port
$200.00 per confirmed motorcoach

Port → Airport
$175.00 per confirmed motorcoach
```

The workflow should support independently changing one segment rate without touching its sibling.

A failed rate save for one segment leaves already-valid sibling data intact.

---

## 13. Cost forecast

The Transportation Supplier forecast uses confirmed vehicle units.

Conceptually:

```text
confirmed motorcoaches × rate per motorcoach
```

It does not use:

```text
passengers × rate
```

and does not spread the fixed Supplier cost across projected enrollment as a persisted Supplier term.

Any per-passenger allocation used for pricing analysis is derived analysis, not the Supplier contract.

---

## 14. Supplier payment commitment

The entire charter is due:

> **November 3, 2027**

At the initial one-coach-per-segment state, the minimum amount is:

> **$375**

The payment definition must retain segment-level derivation:

```text
Hotel → Port
1 × $200 = $200

Port → Airport
1 × $175 = $175

Total due Nov 3
$375
```

If ABC confirms additional coaches before the effective payment point, the amount increases with those confirmed units.

This is Supplier planning only.

The workflow does not create:

- a Supplier Payment;
- an Obligation;
- an invoice;
- paid status.

---

## 15. Late-added coach after November 3

The fixture does not specify the payment treatment for a coach confirmed after November 3.

DepartureDesk must not infer:

- immediate payment;
- another payment date;
- reopening the November 3 requirement;
- a late fee;
- inclusion in an already-settled amount.

The typed workflow should show this as:

> **Needs clarification**

and route the unsupported condition to Advanced Supplier planning where appropriate.

This unresolved term must not become an invented clause or a silent **Reviewed — none**. Whether it blocks Supplier confirmation is a decision for the implementation plan. It must not block accurate representation of the rest of the agreement unless generic activation rules require otherwise.

---

## 16. Final passenger and luggage counts

Each segment has its own actionable Supplier Deadline.

### Hotel → Port

> Final passenger and luggage count due November 3, 2027

### Port → Airport

> Final passenger and luggage count due November 10, 2027

No contractual cutoff time is specified.

Store date-only deadlines.

These deadlines do not:

- reserve another coach;
- reduce coach quantity;
- change controlled capacity;
- create Traveler assignments.

Later evidence that Staff submitted the count may complete the Deadline through the existing Deadline workflow.

---

## 17. Traveler manifests are not Supplier Composition

The Supplier may eventually need names, passenger counts, luggage counts, or a manifest.

The current Transportation Supplier workflow records the contractual Deadline.

It does not create the actual traveler manifest.

Traveler-level facts belong to later Reservation / Client Trip functionality.

Do not introduce temporary Transportation traveler rows.

---

## 18. Cancellation and rescheduling

The fixture does not specify:

- cancellation ladder;
- nonrefundable amount;
- rescheduling fee;
- cancellation cutoff.

Do not invent them.

The ordinary Transportation summary shows:

> **Cancellation terms — Needs clarification**

The first implementation should not add a Transportation-specific cancellation engine.

If Supplier wording is later provided, agreement-reference treatment should be planned against [ADR 0015](../../adr/0015-supplier-agreement-operational-boundary.md) rather than inferred here. **Needs clarification** is not **Reviewed — none**.

---

## 19. Transportation Agreement summary

The normal Staff summary should read approximately:

```text
ABC Motorcoach
Smith Family Reunion

TRANSPORTATION AGREEMENT

Hotel → Port
Nov 6, 2027 · 10:00 a.m.
Hilton Fort Lauderdale Marina → Port Everglades

1 motorcoach guaranteed
15 passenger spaces
Up to 2 additional motorcoaches on request

Supplier rate
$200 per confirmed motorcoach

Final passenger/luggage count
Nov 3, 2027


Port → Airport
Nov 13, 2027 · 9:30 a.m.
Port Everglades → Fort Lauderdale-Hollywood International Airport

1 motorcoach guaranteed
15 passenger spaces
Up to 2 additional motorcoaches on request

Supplier rate
$175 per confirmed motorcoach

Final passenger/luggage count
Nov 10, 2027


PAYMENT

Current minimum charter
$375

Due
Nov 3, 2027


NEEDS CLARIFICATION

Cancellation terms
Payment treatment for a coach confirmed after Nov 3
```

Staff should not have to interpret generic M3 terms to understand this summary.

---

## 20. Review and Supplier confirmation

The implementation plan must decide how Supplier confirmation maps onto the existing exact-version `SupplierConfirmation`.

The likely product behavior is:

> Supplier confirmation freezes the reviewed Transportation agreement represented by that exact Supplier Arrangement Version.

The implementation plan must first verify exactly which Transportation mutations existing confirmation-freeze infrastructure already covers and which require extension.

Do not copy Hotel's freeze trigger mechanically.

Transportation should reuse generic confirmation only where its semantics fit.

---

## 21. Activation

The typed Transportation review should distinguish:

### Supplier agreement review

Are the supported Transportation terms accurately recorded?

from:

### Operational activation readiness

Can the generic Supplier Arrangement Version safely activate?

Supplier confirmation must not become a disguised requirement to clear every generic activation blocker.

The implementation plan should define the Transportation confirmation gate separately from generic activation readiness.

Activation itself continues to use the existing Supplier Arrangement activation command unless compatibility review proves that impossible.

---

## 22. Governing and successor behavior

After activation:

- governing Transportation facts are read-only;
- proposed changes use the existing Supplier Arrangement successor topology;
- stable segment Item identities remain the same across versions;
- Hotel → Port and Port → Airport remain distinct Items;
- an unsupported successor remains readable without rewriting its supported sibling.

Do not create:

- `TransportationAgreementVersion`;
- `TransportationAmendment`;
- another copy engine;
- another activation lifecycle.

---

## 23. Viewer behavior

A Viewer may read supported Transportation Supplier information.

A Viewer may not:

- create a Transportation agreement;
- add a segment;
- change route or schedule;
- change capacity;
- change Supplier rates;
- confirm another coach;
- mutate Deadlines;
- confirm or activate the agreement;
- create a successor.

Cross-Agency identifiers return not found.

---

## 24. Client-facing facts remain out of scope

This walkthrough ends at Supplier Composition.

It does not record:

- the former $27 / $23 / $23 Client prices;
- included/optional Package placement;
- transfer choices;
- Client booking selections;
- traveler assignments.

Those are separate Offer Design / Client Trip facts.

The earlier Client prices are explicitly superseded as Supplier fixture data.

---

## 25. Required browser proof

The Transportation implementation must ultimately prove the following through the typed Staff path:

1. Open Departure Composition → Suppliers.
2. Create/open ABC Motorcoach.
3. Add Hotel → Port.
4. Add Port → Airport.
5. Prove no Airport → Port segment exists.
6. Reopen each by stable Item ID.
7. Enter independent pickup/drop-off, date, and time.
8. Record one confirmed 15-passenger coach per segment.
9. Show two additional coaches as on request only.
10. Enter $200 and $175 Supplier rates.
11. Show $375 current minimum Supplier exposure.
12. Confirm another coach only on Hotel → Port.
13. Show:
    - Hotel → Port = 2 coaches / 30 passengers / $400;
    - Port → Airport = 1 coach / 15 passengers / $175;
    - combined current Supplier exposure = $575.
14. Record November 3 Supplier payment commitment.
15. Record November 3 and November 10 final-count Deadlines.
16. Complete one final-count Deadline without changing capacity.
17. Submit one invalid segment edit and preserve the sibling.
18. Show unresolved cancellation and late-added-coach payment treatment without inventing defaults.
19. Supplier-confirm and activate the supported agreement once the implementation plan defines the gate.
20. Show governing facts read-only.
21. Create a successor and preserve exact segment identities.
22. Prove Viewer and tenancy behavior.
23. Never open generic Supplier planning during the canonical supported path.

---

## 26. Questions the implementation plan must settle

The walkthrough does not authorize these mappings.

### Segment topology

**Recommended:** one Supplier Arrangement, two stable `ground_transportation` Items, one service Occurrence per Item.

This matches the canonical fixture.

### Vehicle representation

The implementation plan must determine whether the generic Supplier Resource should represent:

- a motorcoach unit/type;
- passenger capacity;
- or another existing M3 abstraction.

The answer must preserve:

```text
confirmed coach units × 15 passenger spaces
```

without treating passengers as confirmed Supplier units.

### Controlled versus on-request capacity

The implementation plan must map:

- one confirmed coach;
- two additional coaches on request;
- 45-passenger maximum possible capacity

onto existing Pool/capacity authority without presenting the on-request ceiling as controlled inventory.

### Fixed per-coach cost

The implementation plan must map:

```text
confirmed coach count × fixed segment rate
```

onto existing Supplier cost definitions.

Do not design a new Transportation cost engine if M3C already supports the exact shape.

### Payment commitment

The implementation plan must determine whether the November 3 amount is best represented by:

- one Arrangement-level Deposit/commitment definition with segment contributors;
- another existing Supplier commitment primitive;
- or a narrowly required compatibility amendment.

The fixture requires one shared due date with segment-level derivation. That commitment stays separate from the two final-count Deadlines.

### Confirmation freeze

The implementation plan must name exactly which Transportation definitions become immutable after exact-version Supplier confirmation.

### Agreement references

Cancellation and late-added-coach payment treatment are unresolved.

The implementation plan should determine whether existing `SupplierAgreementReference` kinds are sufficient or whether these remain Advanced without new structured persistence.

No new reference kind should be added merely because the fixture has an unresolved question.

---

## 27. Accepted Supplier workflow

Accepted 2026-10-02. The ordinary Transportation Supplier workflow is:

```text
Composition
→ ABC Motorcoach agreement
→ add independent segments
→ route and schedule
→ confirmed coach capacity
→ on-request ceiling
→ fixed Supplier rate per coach
→ Supplier deadlines/payment terms
→ review
→ Supplier confirmation
→ activation
→ governing agreement
→ successor when terms change
```

Supplier Composition ends before Client pricing, Client selection, or traveler manifests.

These scenario decisions are accepted with this walkthrough:

- One ABC Motorcoach Arrangement, two stable segment Items.
- One Occurrence per segment.
- Motorcoach count is the controlled Supplier quantity; passenger spaces are derived capacity.
- One guaranteed coach = 15 controlled passenger spaces.
- Two additional coaches are on-request capacity, not inventory.
- Supplier rates are fixed per confirmed coach per segment.
- Passenger count does not drive Supplier cost until another coach is confirmed.
- The November 3 and November 10 final-count dates are separate actionable Deadlines.
- The November 3 charter amount is a shared Supplier commitment whose amount derives from confirmed coaches by segment.
- No Airport → Port segment.
- No Client pricing or traveler manifests in this slice.

The next planning step is a compatibility pass against shipped M3 for coach Resource and capacity representation, the on-request ceiling, per-coach cost, the November 3 payment commitment, and confirmation freeze. That pass drives the Transportation implementation plan. Do not implement Transportation from this walkthrough alone.
