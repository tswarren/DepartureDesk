# Celebrity Beyond 2027 — Canonical Cruise Scenario

## 1. Status and authority

**Status:** Draft. Not implementation authority.

When accepted, this scenario supersedes every earlier Celebrity Beyond fixture fact, amount, walkthrough value, and proof assumption that conflicts with it. Earlier documents may remain as implementation history, but they must not supply facts that this scenario defines differently.

Shipped Cruise slices retain their own authority. This scenario validates those workflows against one canonical fixture; it does not silently amend them.

The MVP representation is:

- controlled cabin inventory and Supplier rates are typed;
- the initial group deposit is typed and quantity-derived;
- the Hard Stop is one combined actionable Deadline;
- final payment is a separate actionable Deadline;
- allocation-sensitive deposits and legal-name actions remain readable policy until booking facts exist;
- normal commission is typed independently of GAP; and
- tour-conductor credit and GAP are recorded agreement terms, labeled **Terms recorded; entitlement not calculated.** They are not payments or Client revenue.

## 2. Purpose

This is the canonical proof scenario for:

- a Cruise Arrangement with three cabin categories and controlled opening inventory;
- additive occupancy-position Supplier economics;
- commission on commissionable fare only;
- a quantity-derived initial group deposit across selected cabin Pools;
- actionable deadlines separated from booking-dependent policy;
- a one-time proposed Arrangement name that Staff may override; and
- the shipped Cruise Offer Design handoff without implying Package placement or a Client booking.

## 3. Source classification and evidence

Three kinds of facts appear in this scenario:

- **Canonical Supplier facts** are authoritative contract and planning facts.
- **Illustrative Client figures** demonstrate reviewed Client pricing but are not accepted selling prices or Package decisions.
- **Source-qualified policy terms** come from the July 2025 Celebrity Groups brochure and the agency’s normal 15% booking-commission rule.

Celebrity may change general group policy. The brochure is therefore dated evidence for this Arrangement, not timeless global policy. Sailing-specific terms override general policy when the two differ.

Staff may attach one shared Arrangement-level agreement or evidence source and reference it from the cabin categories and related definitions. Initial draft setup does **not** require duplicate evidence on every category. Audit history is not evidence. Later consequential capacity changes continue to follow the shipped reason/evidence controls.

The brochure does not supply a separate rooming-list deadline, citizenship-document deadline, or manifest-delivery date for this sailing. GAP amenity allocation, fulfillment, and purchased points remain Advanced planning.

Booking-dependent rules remain visible as contract policy but do not materialize booking-level obligations until a later Reservation or Client Trip layer has the allocation, traveler, payment, and attribution facts required to evaluate them.

## 4. Departure and Arrangement facts

| Fact | Canonical value |
| --- | --- |
| Departure | Smith Family Reunion |
| Supplier | Celebrity Cruises |
| Ship | Celebrity Beyond |
| Itinerary | 7-Night Eastern Caribbean |
| Sailing | November 6–13, 2027 |
| Supplier group reference | 1119999 |
| Departure operating currency | USD, displayed on the Arrangement |
| Departure port | Not named; the canonical proof leaves it blank |
| Return port | Not named; the canonical proof leaves it blank |
| Itinerary notes | Optional; this scenario does not require them |
| Time zone | America/New_York |

### Proposed Arrangement name

When Staff first creates the Arrangement, DepartureDesk proposes:

```text
Celebrity Cruises — Celebrity Beyond — 7-Night Eastern Caribbean — Nov 6–13, 2027
```

The proposal is editable. Once saved, the Arrangement name is stored and is not silently recomputed when Supplier, ship, itinerary, or sailing dates change. Staff may explicitly rename it. The Arrangement ID—not its name—is its durable identity.

The Supplier group reference is stored separately from the Arrangement name. Amounts display the Departure’s operating currency. For this Departure that currency is USD. The Arrangement does not have an independently editable currency, and currency is not inferred from formatted amounts. Named ports are optional sailing facts. This scenario proves a valid draft with both ports blank. A separate test may save port names; those names are not canonical.

## 5. Supplier Arrangement topology and lifecycle

Staff creates or opens one Cruise Arrangement for this sailing. All cabin Resources, inventory, Supplier costs, deposits, deadlines, and policy summaries belong to that Arrangement and its versioned graph.

Before activation, Staff can independently edit draft cabin inventory, Supplier cost components, Deposit Requirement definitions, and Deadline definitions. An invalid save preserves entered values and leaves valid siblings unchanged.

Activation preview is write-free. It shows:

- the three cabin Pools and authoritative opening quantities;
- the initial-deposit derivation;
- the allocation-sensitive full-deposit policy without inventing an Arrangement-wide obligation;
- the combined Hard Stop action;
- the final-payment action;
- informational payment and cancellation policies; and
- any missing fact that prevents activation.

Activation uses the accepted Arrangement activation path. Governing definitions become read-only. Later planning changes occur on a successor draft and preserve stable identities wherever the shipped copy rules require them.

## 6. Cabin Resources and capacity

The opening block contains 24 cabins across three categories.

| Code | Supplier category | Maximum guests per cabin | Initially blocked cabins |
| --- | --- | ---: | ---: |
| E3 | Edge Stateroom with Veranda | 3 | 8 |
| O1 | Prime Oceanview | 3 | 8 |
| DI | Deluxe Inside Stateroom | 3 | 8 |
| **Total** |  |  | **24** |

Each category is a distinct Cruise cabin Resource with a stable identity and one typed cabin Capacity Pool. Each Pool has authoritative opening quantity 8. Maximum occupancy 3 is a physical property of one cabin and is not a substitute for blocked inventory.

The confirmed occupancy profiles are:

- **Single:** one guest in one cabin;
- **Double:** two guests in one cabin, using first and second positions; and
- **Triple:** three guests in one cabin, using first, second, and third positions.

The stored pricing bands are additive:

- Single = one First/Second band + one Single-occupancy adjustment;
- Double = two First/Second bands; and
- Triple = two First/Second bands + one Third band.

The Single-occupancy adjustment is **not** a complete Single price.

## 7. Canonical Supplier economics

The source presentation is normalized into an additive occupancy-band model. Monetary values in the component tables are per applicable occupancy band.

### 7.1 E3 — Edge Stateroom with Veranda

| Component or result | First/Second | Third | Single-occupancy adjustment |
| --- | ---: | ---: | ---: |
| Base fare | $2,533.00 | $10.00 | $2,533.00 |
| NCCF | $320.00 | $320.00 | $320.00 |
| Discount | −$950.00 | $0.00 | −$950.00 |
| Taxes, fees, and port charges | $134.26 | $134.26 | $0.00 |
| **Supplier total** | **$2,037.26** | **$464.26** | **$1,903.00** |
| Commission rate | 15% | 15% | 15% |
| *Illustrative agency surcharge* | *$50.00* | *$50.00* | *$50.00* |
| ***Illustrative Client band*** | ***$2,087.26*** | ***$514.26*** | ***$1,953.00*** |

| Profile | Supplier total | Commission | Supplier net | Agency surcharge | Illustrative Client price |
| --- | ---: | ---: | ---: | ---: | ---: |
| Single | $3,940.26 | $474.90 | $3,465.36 | $100.00 | $4,040.26 |
| Double | $4,074.52 | $474.90 | $3,599.62 | $100.00 | $4,174.52 |
| Triple | $4,538.78 | $476.40 | $4,062.38 | $150.00 | $4,688.78 |

### 7.2 O1 — Prime Oceanview

| Component or result | First/Second | Third | Single-occupancy adjustment |
| --- | ---: | ---: | ---: |
| Base fare | $1,739.00 | $10.00 | $1,739.00 |
| NCCF | $320.00 | $320.00 | $320.00 |
| Discount | −$772.50 | $0.00 | −$772.50 |
| Taxes, fees, and port charges | $134.26 | $134.26 | $0.00 |
| **Supplier total** | **$1,420.76** | **$464.26** | **$1,286.50** |
| Commission rate | 15% | 15% | 15% |
| *Illustrative agency surcharge* | *$50.00* | *$50.00* | *$50.00* |
| ***Illustrative Client band*** | ***$1,470.76*** | ***$514.26*** | ***$1,336.50*** |

| Profile | Supplier total | Commission | Supplier net | Agency surcharge | Illustrative Client price |
| --- | ---: | ---: | ---: | ---: | ---: |
| Single | $2,707.26 | $289.95 | $2,417.31 | $100.00 | $2,807.26 |
| Double | $2,841.52 | $289.95 | $2,551.57 | $100.00 | $2,941.52 |
| Triple | $3,305.78 | $291.45 | $3,014.33 | $150.00 | $3,455.78 |

### 7.3 DI — Deluxe Inside Stateroom

| Component or result | First/Second | Third | Single-occupancy adjustment |
| --- | ---: | ---: | ---: |
| Base fare | $1,559.00 | $10.00 | $1,559.00 |
| NCCF | $320.00 | $320.00 | $320.00 |
| Discount | −$705.00 | $0.00 | −$705.00 |
| Taxes, fees, and port charges | $134.26 | $134.26 | $0.00 |
| **Supplier total** | **$1,308.26** | **$464.26** | **$1,174.00** |
| Commission rate | 15% | 15% | 15% |
| *Illustrative agency surcharge* | *$50.00* | *$50.00* | *$50.00* |
| ***Illustrative Client band*** | ***$1,358.26*** | ***$514.26*** | ***$1,224.00*** |

| Profile | Supplier total | Commission | Supplier net | Agency surcharge | Illustrative Client price |
| --- | ---: | ---: | ---: | ---: | ---: |
| Single | $2,482.26 | $256.20 | $2,226.06 | $100.00 | $2,582.26 |
| Double | $2,616.52 | $256.20 | $2,360.32 | $100.00 | $2,716.52 |
| Triple | $3,080.78 | $257.70 | $2,823.08 | $150.00 | $3,230.78 |

### 7.4 Meaning and calculations

- Base fare, NCCF, discount, and taxes/fees/port charges are distinct Supplier components.
- Discounts are stored as negative Supplier components.
- In stored-sign terms, commissionable fare is `Base fare + Discount`.
- Normal booking commission is `15% × combined commissionable fare for the profile`.
- NCCF, taxes, government fees, and port charges are noncommissionable.
- Commission is calculated on the combined profile basis and rounded once to the nearest cent.
- Expected commission is distinct from Supplier cost and is not Client revenue.
- Supplier net is a derived review value: Supplier total less expected commission.
- The illustrative agency surcharge is $50 per occupied pricing band: $100 for Single, $100 for Double, and $150 for Triple.
- Illustrative Client price is Supplier total plus the illustrative agency surcharge.
- Illustrative agency profit is expected commission plus agency surcharge.
- Reopening a supported schedule preserves category, occupancy-band, component, and stored-value identities.

### 7.5 Normal agency commission

The agency’s normal 15% booking commission exists independently of GAP and is not purchased with amenity points. It applies only to commissionable cruise fare under the rule above.

### 7.6 Tour-conductor credit

- One cruise-only TC credit is earned per sixteen full-tariff guests, based on double occupancy.
- First- and second-position full-tariff guests qualify; third and fourth passengers do not.
- A Single paying 200% of full fare counts as two guests for qualification.
- Credit value uses the average cruise fare of the stateroom categories booked within the group.
- NCCF, government fees, and taxes are excluded, and the credit is net of commission.
- The default 1-per-16 ratio may improve to 1 per 14 for four GAP points or 1 per 12 for six GAP points.

TC qualification, valuation, and redemption remain separate from this recorded term. DepartureDesk stores the Staff summary and an optional source citation. The review label is **Terms recorded; entitlement not calculated.** It does not store `projected`, `earned`, `applied`, or `forfeited`, and it does not create a Supplier Payment, Client credit, or negative Supplier cost.

### 7.7 Group Amenity Program

This Deposit Program group receives a standard entitlement of **four group GAP points**, not five points per traveler.

- Points are expected forty days after group creation if the group was deposited by day thirty.
- The group must retain at least eight staterooms.
- GAP selections must be made before final payment.
- Unallocated GAP is forfeited at final payment if the group falls below eight staterooms.
- Standard amenities are for full-paying guests and exclude third and fourth passengers unless the selected amenity says otherwise.
- Additional points for guest-facing amenities may be purchased for $12.50 per point per stateroom.

DepartureDesk stores this as one group-level agreement term. The review label is **Terms recorded; entitlement not calculated.** It does not record whether the four points have been allocated. Selecting and fulfilling a particular amenity remains Advanced until an accepted concessions model exists.

Staff may finish transcribing a term onto the agreement revision that was already agreed. Changing wording or citation already recorded for a Supplier-confirmed revision is an amendment and needs confirmation of that amendment. The screen shows which revision the wording represents. An empty Commercial benefits section does not block activation.

### 7.8 Marketing support

General marketing support consists of access to Celebrity’s Group Sales Kit and Supplier review of promotional materials. Promotional materials require Celebrity approval and must identify the ship’s registry.

A cash Marketing Fund is optional GAP allocation, not normal commission:

| Marketing fund | GAP cost |
| --- | ---: |
| $25 per stateroom | 2 points |
| $50 per stateroom | 4 points |
| $75 per stateroom | 6 points |
| $100 per stateroom | 8 points |

For MVP, general marketing support is informational. Any GAP-funded Marketing Fund remains an Advanced concession and does not change the 15% commission component.

## 8. Deposits and deadlines

### 8.1 Initial group deposit

- Group creation date: September 13, 2026.
- Due date: October 13, 2026, thirty days after group creation.
- Rate: $50 per unallocated stateroom held in the Deposit Program.
- Authoritative quantity: opening quantities from the selected E3, O1, and DI cabin Pools.
- Calculation: `(8 + 8 + 8) × $50 = $1,200`.
- Coverage: the whole Cruise Arrangement, with quantity derived from the selected Pools.

This is a `quantity × rate` requirement, not a cumulative-target definition. The summary must show the quantity source and calculation, not merely `$1,200`.

### 8.2 Full allocated-stateroom deposit policy

- A seven-night itinerary requires a full deposit of $500 per allocated stateroom.
- For each allocated stateroom, the full deposit and required legal names are due at the earliest applicable event: when full legal names are added; within thirty days after allocation; or the Hard Stop on July 9, 2027.
- They are also due at the end of an applicable shorter option period.
- An attributable initial $50 contributes toward that stateroom’s $500 requirement, leaving $450.

This is allocation-sensitive booking policy. Keep it readable and structured on the Cruise Arrangement, but do not materialize an Arrangement-wide final Deposit Requirement amount or occurrence. A future Reservation or Client Trip workflow creates a booking-level obligation only after it knows the allocated stateroom, allocation date, travelers, credited payment, and applicable option period.

### 8.3 Actionable Supplier deadlines

| Requirement | Date | Operational effect |
| --- | --- | --- |
| Name and fully deposit allocated staterooms, or release remaining inventory | July 9, 2027 | Satisfy booking-specific name/deposit rules and release unsold inventory |
| Final payment | August 8, 2027 | Pay the final balance for the seven-night sailing |

For MVP, the Hard Stop is one combined actionable Arrangement-level Deadline:

> **Name and fully deposit allocated staterooms, or release remaining inventory**  
> July 9, 2027  
> Full deposit: $500 per allocated stateroom. Credit the initial $50 where attributable.

Do not create separate Arrangement-level deadlines for legal names, full deposit, and inventory release. Recording `names_assigned_to_supplier` is evidence that an operational event occurred, not a second contractual deadline.

The brochure does not establish an October 7 rooming-list deadline. That earlier fixture fact is superseded.

### 8.4 Informational payment-method policy

- An agency corporate card may fund the initial $50-per-stateroom group deposit.
- As legal names are supplied, the agency card must be refunded and the applicable guest card cross-referenced.
- An agency corporate card cannot fund named space or final payment.
- A travel partner’s personal card is limited to the initial group deposit or payment for the travel partner, a friend, or a family member, with the relationship documented.

These are informational policy terms, not Deadline definitions. Supplier Composition does not create payments, refunds, card records, or paid status.

## 9. Cancellation policy

For this seven-night sailing, cancellation charges apply per person:

| Days before departure | Charge |
| --- | ---: |
| 90 or more | Full refund, except nonrefundable-deposit offers |
| 89–75 | 25% of total fare |
| 74–61 | 50% of total fare |
| 60–31 | 75% of total fare |
| 30 or fewer | 100% of total fare |

Taxes and fees are excluded from the percentage base. Where the brochure’s footnote applies, the charge is the calculated percentage or deposit amount, whichever is greater. This booking-level ladder is not the same as releasing unallocated inventory at the Hard Stop.

Retain it as structured informational policy or an Advanced term. Do not calculate cancellation fees, refunds, or Client credits before Reservation and accounting authority exists.

## 10. Expected Supplier Composition summary

```text
Celebrity Cruises — Celebrity Beyond — 7-Night Eastern Caribbean — Nov 6–13, 2027
Supplier group reference 1119999 · USD (Departure operating currency)

Cabins
E3 · 8 initially blocked · Maximum 3 guests
O1 · 8 initially blocked · Maximum 3 guests
DI · 8 initially blocked · Maximum 3 guests

Initial group deposit
$50 × 24 initially blocked staterooms = $1,200
Quantity source: E3 8 + O1 8 + DI 8
Due October 13, 2026

Hard Stop
July 9, 2027
Name and fully deposit allocated staterooms, or release remaining inventory
Allocation-specific calculation occurs with the booking

Final payment
August 8, 2027

Commercial benefits
Normal commission · 15% of commissionable fare · Remains in Supplier rates
Tour-conductor credit · Terms recorded; entitlement not calculated
Group amenities · Terms recorded; entitlement not calculated
```

## 11. Shipped Cruise Offer Design handoff

This section describes already-shipped Cruise behavior. It is not Supplier Composition authority and is not a template for Hotel Slice 3A.

Staff may connect the Cruise Arrangement Item to one Cruise Service Offer. The connection pins the selected Arrangement version and exposes one choice per cabin category:

- E3 — Edge Stateroom with Veranda;
- O1 — Prime Oceanview; and
- DI — Deluxe Inside Stateroom.

Each choice receives a stable stored `cruise_cabin:` rate-category key, minted once and copied unchanged to successors. Choices initially have null option price effects. Category pricing uses their stored keys.

The connection does not decide Package placement and does not mean a Client booked the service.

The following prices are illustrative only:

| Category | Single | Double | Triple |
| --- | ---: | ---: | ---: |
| E3 | $4,040.26 | $4,174.52 | $4,688.78 |
| O1 | $2,807.26 | $2,941.52 | $3,455.78 |
| DI | $2,582.26 | $2,716.52 | $3,230.78 |

The calculation is additive:

- Single uses First/Second + Single-occupancy adjustment and a $100 surcharge;
- Double uses two First/Second bands and a $100 surcharge; and
- Triple uses two First/Second bands + Third and a $150 surcharge.

If Staff copies a Supplier component into Client terms, the Client cell retains provenance to that exact Supplier component. Later Supplier edits may mark the copy changed but do not silently change the Client amount.

## 12. Required browser proof

One browser-level scenario begins at Departure Composition and proves that Staff can:

1. Create or open the exact Celebrity Beyond Cruise Arrangement.
2. See the proposed composed name, edit it if desired, and confirm later fact edits do not silently rename the Arrangement.
3. Store Supplier group reference `1119999` separately from the name. Amounts display the Departure operating currency, USD. The Arrangement has no independently editable currency.
4. Attach or reference one shared Arrangement-level evidence source without duplicating evidence on every initial cabin category.
5. Create E3, O1, and DI with maximum occupancy 3 and opening Pool quantity 8 each.
6. Enter Base fare, NCCF, Discount, and Taxes/fees for First/Second, Third, and Single-occupancy adjustment bands.
7. Reopen the schedule with the same category, band, component, and record identities.
8. Review Single as an additive profile rather than a complete stored Single total.
9. Confirm O1 Double commission is $289.95, calculated on the combined profile and rounded once.
10. Confirm agency surcharge is $100 for Single, $100 for Double, and $150 for Triple.
11. Create the typed initial group deposit and see `(8 + 8 + 8) × $50 = $1,200` with its Pool-derived quantity source.
12. Create the combined Hard Stop and final-payment Deadline without inventing separate legal-name, rooming-list, or Arrangement-wide full-deposit deadlines.
13. Read the allocation-sensitive $500 deposit rule and payment/cancellation policies without materializing false operational occurrences.
14. Preview activation without writes, correct any missing fact, and activate through the accepted path.
15. Connect one Cruise Service Offer, explicitly select all three categories, and retain stored choice and rate-key identities on reopen.
16. Review illustrative Single, Double, and Triple prices clearly separated from Supplier facts, Package placement, and Client booking.

The proof also requires:

- failed component saves do not alter siblings;
- failed deposit or deadline saves do not alter rates or sibling definitions;
- unsupported graphs remain readable and link to Advanced without rewrite;
- draft, governing, and successor states are distinguishable;
- a Viewer cannot mutate the workspace;
- no second Service Offer is created during reopen or edit; and
- edit and remove actions submit stable IDs rather than labels, positions, `.first`, or `.last`.

## 13. Explicit exclusions

This scenario does not establish:

- Package placement;
- Client Trip selection or booking;
- canonical Client selling prices;
- allocation-specific Deposit Requirement occurrences before a booking exists;
- guest-card attribution;
- Supplier payments, refunds, invoices, obligations, or paid status;
- calculated cancellation charges or Client credits;
- a separate rooming-list deadline; or
- automatic GAP fulfillment or TC-credit application.

## 14. Superseded facts

The following earlier fixture assumptions are expressly superseded:

- category code `E1`; the canonical code is `E3`;
- treating the Single column as a complete Single price rather than an additive adjustment;
- the old O1 Single and DI Third discrepancy exceptions and their stated totals;
- the old O1, DI, and E3 Client-price tables that conflict with Section 11;
- commission rounded independently per occupancy band; commission is calculated on the combined profile and rounded once;
- an Arrangement-wide March 11 cumulative deposit deadline;
- a separate October 7 rooming-list deadline;
- five GAP points per traveler;
- mandatory duplicate evidence on every initial cabin category;
- silently recomputing the Arrangement name after creation; and
- any other Celebrity Beyond fixture fact that conflicts with this scenario.
