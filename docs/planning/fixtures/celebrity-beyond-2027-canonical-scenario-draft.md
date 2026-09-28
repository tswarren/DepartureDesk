# Celebrity Beyond 2027 — Canonical Cruise Scenario

## 1. Status and authority

**Status:** Draft. Not implementation authority.

When accepted, this scenario supersedes every earlier Celebrity Beyond fixture fact, amount, walkthrough value, and proof assumption that conflicts with it. Earlier documents may remain as implementation history, but they must not supply facts that this scenario defines differently.

This scenario defines the canonical Celebrity Beyond facts used to prove the accepted Cruise workflow. It does not independently amend architecture or shipped behavior. Where the accepted **Cruise Remediation — Supplier Agreement, Contracted Rates, Deposits, and Amendments** plan expressly supersedes Cruise-specific behavior from the shipped M4D.1 Cruise slices, that remediation plan governs the behavior and this scenario supplies its canonical proof facts. Generic M3/M4 behavior not expressly amended by that plan retains its existing authority.

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
- estimated Supplier rates preserved separately from contracted Supplier rates;
- whole-agreement Supplier confirmation independently from rate transcription and activation;
- Cruise activation gated by Supplier confirmation and ready contracted rates;
- a quantity-derived initial group deposit across selected cabin Pools;
- actionable deadlines separated from booking-dependent policy;
- a one-time proposed Arrangement name that Staff may override;
- same-terms capacity increases distinguished from supplemental inventory with materially different Supplier terms;
- explicit supplemental-deposit treatment for later capacity;
- truthful duplicate Supplier category codes distinguished by internal block identity;
- Supplier-side capacity changes isolated from published Client choices until explicit Offer Design review; and
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
| Group creation date | September 13, 2026 |
| Contract date | September 13, 2026 |
| Supplier group reference | 1119999 |
| Departure operating currency | USD, displayed on the Arrangement |
| Departure port | Not named; the canonical proof leaves it blank |
| Return port | Not named; the canonical proof leaves it blank |
| Itinerary notes | Optional; this scenario does not require them |
| Time zone | America/New_York |

### 4.1 Group agreement status

The Supplier group agreement has a lifecycle distinct from Arrangement activation.

- **Group creation date:** September 13, 2026.
- **Contract date:** September 13, 2026.
- Before Supplier confirmation, the Arrangement may remain provisional. The Supplier group reference and contract date may be absent or edited while provisional.
- For this canonical scenario, the Supplier group reference is `1119999`.
- Supplier confirmation requires the group reference and contract date and records the confirming Staff actor and time.
- A confirmation note and supporting agreement document are optional.
- Confirmation applies to the whole agreement revision, not to an individual cabin category.
- Supplier confirmation may be recorded before Staff finish transcribing contracted rates.
- Supplier confirmation does not itself activate the Arrangement.
- After confirmation, the confirmed Supplier group reference and contract date cannot be changed by ordinary edit. A factual correction preserves the earlier confirmation values and records the correction explicitly.
- A later amendment with materially changed Supplier terms receives its own agreement/amendment date and Supplier confirmation. It does not rewrite the original contract date or confirmation.

### Proposed Arrangement name

When Staff first creates the Arrangement, DepartureDesk proposes:

```text
Celebrity Cruises — Celebrity Beyond — 7-Night Eastern Caribbean — Nov 6–13, 2027
```

The proposal is editable. Once saved, the Arrangement name is stored and is not silently recomputed when Supplier, ship, itinerary, or sailing dates change. Staff may explicitly rename it. The Arrangement ID—not its name—is its durable identity.

The Supplier group reference is stored separately from the Arrangement name. Amounts display the Departure’s operating currency. For this Departure that currency is USD. The Arrangement does not have an independently editable currency, and currency is not inferred from formatted amounts. Named ports are optional sailing facts. This scenario proves a valid draft with both ports blank. A separate test may save port names; those names are not canonical.

## 5. Supplier Arrangement topology and lifecycle

Staff creates or opens one Cruise Arrangement for this sailing. Cabin Resources, inventory, Supplier costs, deposits, deadlines, agreement terms, and policy summaries belong to that Arrangement and its versioned graph.

Before activation, Staff can independently edit the supported draft sections. An invalid save preserves entered values for correction and leaves valid siblings unchanged.

### 5.1 Supplier rate stages

Supplier estimates and contracted Supplier rates are distinct definitions.

Staff may first record an **estimated** rate definition for each cabin Resource.

When the Supplier agreement supplies contracted rates, Staff uses **Record contracted rates**. DepartureDesk copies the estimated cells into a separate contracted definition for review. The estimated definition remains unchanged and retains its original stage and history.

The copied contracted definition is not automatically ready. Staff review and correct it and explicitly make it ready through the accepted cost-definition readiness path.

For supported Cruise activation, the applicable contracted definition—not an estimated definition—must be ready for every cabin Resource covered by the agreement revision.

### 5.2 Supplier agreement confirmation

Supplier agreement confirmation is independent from rate transcription.

Staff may mark the whole agreement revision Supplier-confirmed once the required confirmation facts exist even if some contracted rates remain incomplete.

The workspace therefore may truthfully show:

> **Supplier confirmed · Contracted rates incomplete**

Confirmation does not mean the Arrangement is activated, money has been paid, or a Client offer exists.

### 5.3 Activation

Activation preview is write-free. It shows:

- Supplier agreement confirmation status;
- contracted-rate readiness for each covered cabin Resource;
- the three cabin Pools and authoritative opening quantities;
- the initial-deposit derivation;
- the allocation-sensitive full-deposit policy without inventing an Arrangement-wide obligation;
- the combined Hard Stop action;
- the final-payment action;
- informational payment, cancellation, and commercial-benefit terms; and
- every missing fact that prevents activation.

This Cruise Arrangement cannot activate until:

1. the exact agreement revision is Supplier-confirmed;
2. every covered cabin Resource has its required ready contracted Supplier rates;
3. required inventory and Supplier-planning facts are valid; and
4. the existing generic activation invariants pass.

This Cruise-specific gate does not change accepted non-Cruise activation behavior.

After activation, the exact governing definitions and confirmation history remain immutable according to the accepted versioning contracts.

Later planning follows one of two paths:

- **same governing terms:** record an evidenced capacity change on the existing Pool; or
- **materially different Supplier terms:** prepare a successor Arrangement/version with distinct Supplier inventory and rate authority.

The governing Arrangement remains authoritative while a successor is proposed.

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

### 7.5 Estimated and contracted rate-stage proof

The monetary values in Sections 7.1–7.3 are the canonical Supplier economics used to prove the typed Cruise rate workflow.

The canonical proof begins with those values recorded as estimated Supplier rates.

Staff then uses **Record contracted rates** for each cabin Resource. DepartureDesk creates a separate contracted definition initialized from the estimate.

For proof purposes:

- the estimated definition remains stored and unchanged;
- the contracted definition has its own identity and stage;
- Staff may correct the contracted definition without changing the estimate;
- the contracted definition must be explicitly made ready;
- activation and the applicable Supplier forecast use the ready contracted definition; and
- reopening either stage selects the exact requested definition rather than an arbitrary working definition.

The canonical values do not require the estimate and contracted definitions to differ numerically. Their distinct identities, stages, provenance, and readiness are what this scenario proves.

### 7.6 Normal agency commission

The agency’s normal 15% booking commission exists independently of GAP and is not purchased with amenity points. It applies only to commissionable cruise fare under the rule above.

### 7.7 Tour-conductor credit

- One cruise-only TC credit is earned per sixteen full-tariff guests, based on double occupancy.
- First- and second-position full-tariff guests qualify; third and fourth passengers do not.
- A Single paying 200% of full fare counts as two guests for qualification.
- Credit value uses the average cruise fare of the stateroom categories booked within the group.
- NCCF, government fees, and taxes are excluded, and the credit is net of commission.
- The default 1-per-16 ratio may improve to 1 per 14 for four GAP points or 1 per 12 for six GAP points.

TC qualification, valuation, and redemption remain separate from this recorded term. DepartureDesk stores the Staff summary and an optional source citation. The review label is **Terms recorded; entitlement not calculated.** It does not store `projected`, `earned`, `applied`, or `forfeited`, and it does not create a Supplier Payment, Client credit, or negative Supplier cost.

### 7.8 Group Amenity Program

This Deposit Program group receives a standard entitlement of **four group GAP points**, not five points per traveler.

- Points are expected forty days after group creation if the group was deposited by day thirty.
- The group must retain at least eight staterooms.
- GAP selections must be made before final payment.
- Unallocated GAP is forfeited at final payment if the group falls below eight staterooms.
- Standard amenities are for full-paying guests and exclude third and fourth passengers unless the selected amenity says otherwise.
- Additional points for guest-facing amenities may be purchased for $12.50 per point per stateroom.

DepartureDesk stores this as one group-level agreement term. The review label is **Terms recorded; entitlement not calculated.** It does not record whether the four points have been allocated. Selecting and fulfilling a particular amenity remains Advanced until an accepted concessions model exists.

Staff may finish transcribing a term onto the agreement revision that was already agreed. Changing wording or citation already recorded for a Supplier-confirmed revision is an amendment and needs confirmation of that amendment. The screen shows which revision the wording represents. An empty Commercial benefits section does not block activation.

### 7.9 Marketing support

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

The `$1,200` requirement is a historical snapshot of the initial opening block. A later capacity increase does not recalculate or mutate it.

When Supplier capacity is later increased, Staff must explicitly record whether the additional capacity carries another initial blocked-stateroom deposit requirement.

For the same-terms proof in Section 11, Celebrity adds four O1 staterooms and confirms that the same `$50` initial-deposit treatment applies. DepartureDesk therefore records a separate supplemental requirement:

`4 additional O1 staterooms × $50 = $200`

The `$200` requirement traces to the later capacity increase. The original `$1,200` requirement remains unchanged.

If a future Supplier capacity increase does not require another initial deposit, Staff records that explicit outcome and its required evidence rather than silently assuming `$0` or modifying the opening requirement.

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
Contract date September 13, 2026

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

## 11. Later capacity and agreement amendments

The canonical scenario includes two later-inventory proofs. They establish that Supplier category code, internal Resource identity, capacity identity, and Supplier cost authority are separate concepts.

### 11.1 Same-terms O1 increase

After the original Arrangement is governing, Celebrity adds four Prime Oceanview staterooms under the same governing:

- Supplier category;
- contracted rates;
- deposit treatment;
- release terms; and
- other material agreement terms.

Staff records an evidenced `+4` capacity event on the existing O1 Pool.

The result is:

```text
O1 — Prime Oceanview
Original opening quantity: 8
Later capacity increase: +4
Current Supplier capacity: 12
Supplier category code: O1
Contracted rate source: unchanged
```

This does not create another O1 Resource or another contracted rate source.

The original `$1,200` opening-deposit requirement remains unchanged.

For this canonical proof, the four added staterooms carry the same `$50` initial-deposit treatment. DepartureDesk records a separate:

`4 × $50 = $200`

supplemental Supplier requirement tied to the capacity increase.

Supplier capacity becoming available does not itself change a published Client choice, Client price, source pin, or published selectable quantity.

### 11.2 Differently priced supplemental O1 block

The canonical amendment proof then considers four additional Prime Oceanview staterooms offered under materially different Supplier rates.

Because the rates differ, these staterooms do **not** increase the existing O1 Pool.

Staff prepares a successor Arrangement/version containing:

- a new Cruise cabin Resource;
- a new cabin Pool;
- a new exact-context Supplier rate source; and
- a distinct Staff-visible internal block label.

The real Celebrity category code remains:

`O1`

DepartureDesk does not invent a Supplier code such as `O1-2`.

For the canonical proof, use the internal block label:

> **Supplemental O1 block**

The original Resource and supplemental Resource therefore have distinct durable DepartureDesk identities even though both truthfully carry Supplier category code `O1`.

The supplemental block's exact different rate amounts are **not established by this canonical fixture**. Browser/domain proof may use explicitly labeled test-only changed values where necessary to exercise the changed-terms path, but those values must not be presented as canonical Celebrity economics.

The changed rates require:

- the successor graph;
- separate contracted-rate authority for the supplemental Resource;
- confirmation of the amended whole Supplier agreement; and
- successful Cruise activation gates before the successor can govern.

The original agreement confirmation and original contract date remain historical facts. The amendment records its own date and confirmation.

The governing Arrangement remains in force while this successor is only proposed.

## 12. Shipped Cruise Offer Design handoff

This section describes already-shipped Cruise behavior except where the accepted Cruise remediation plan expressly changes the treatment of later Supplier capacity. It is not Supplier Composition authority and is not a template for Hotel Slice 3A.

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

### 12.1 Later Supplier capacity

Later Supplier inventory remains Supplier-side until Staff explicitly reviews its Client presentation.

A same-terms increase to the O1 Supplier Pool does not silently:

- increase a published Client choice's selectable quantity;
- change its Client price;
- change its source pin; or
- republish it.

A differently priced supplemental O1 Resource likewise does not silently join the existing O1 Client choice.

Where truthful, Staff may explicitly create a separate draft Client option for the supplemental block, with its own source binding and reviewed Client pricing.

This scenario does not authorize one Client O1 choice to consume interchangeably from both O1 Supplier Pools. Multiple Supplier Pools behind one Client choice remain outside the accepted contract until an alternative-source/selection model is separately accepted.

## 13. Required browser proof

One browser-level scenario begins at Departure Composition and proves that Staff can:

1. Create or open the exact Celebrity Beyond Cruise Arrangement.
2. See the proposed composed name, edit it if desired, and confirm later fact edits do not silently rename the Arrangement.
3. Save the provisional agreement with the September 13, 2026 group creation date before Supplier confirmation.
4. Store Supplier group reference `1119999` separately from the Arrangement name.
5. Store the September 13, 2026 contract date separately from the group creation date even though the two canonical dates are equal.
6. Display USD from the Departure operating currency without an independently editable Arrangement currency.
7. Create E3, O1, and DI with maximum occupancy 3 and opening Pool quantity 8 each.
8. Enter the canonical Supplier economics as estimated rates.
9. Reopen the estimated schedules with the same category, occupancy-band, component, and stored-value identities.
10. Use **Record contracted rates** and prove the estimated definitions remain unchanged.
11. Review the separate contracted definitions and make them ready.
12. Review Single as an additive profile rather than a complete stored Single total.
13. Confirm O1 Double commission is `$289.95`, calculated on the combined profile and rounded once.
14. Record the whole Supplier agreement confirmation using group reference `1119999`, contract date September 13, 2026, Staff actor, and confirmation time.
15. Prove Supplier confirmation can exist while a contracted rate remains incomplete.
16. Prove activation is blocked while any required contracted rate is not ready.
17. Prove ordinary edit cannot change the confirmed group reference or contract date.
18. Create the typed initial group deposit and see `(8 + 8 + 8) × $50 = $1,200` with its Pool-derived quantity source.
19. Create the July 9, 2027 combined Hard Stop and August 8, 2027 final-payment Deadline without inventing separate legal-name, rooming-list, or Arrangement-wide full-deposit deadlines.
20. Read the allocation-sensitive `$500` deposit rule and payment/cancellation policies without materializing false booking-level occurrences.
21. Review normal commission separately from Tour Conductor and GAP terms labeled **Terms recorded; entitlement not calculated.**
22. Preview activation without writes and see both Supplier-confirmation and contracted-rate readiness.
23. Activate the exact reviewed Arrangement/version only after both requirements pass.
24. Reopen the governing version and prove its activated definitions and confirmation history remain stable.
25. Add four same-terms O1 staterooms as an evidenced capacity event on the existing Pool.
26. Prove the existing O1 Resource and contracted rate source remain authoritative.
27. Record the separate `4 × $50 = $200` supplemental initial-deposit requirement and prove the original `$1,200` requirement does not change.
28. Prove the Supplier capacity increase does not silently change the existing published O1 Client choice, Client price, source pin, or selectable quantity.
29. Prepare a successor with four additional differently priced O1 staterooms.
30. Prove the supplemental inventory has a new Resource, Pool, and exact-context rate source while retaining truthful Supplier category code `O1`.
31. Display the distinct internal block label **Supplemental O1 block** rather than inventing another Supplier category code.
32. Record/review contracted rates for the supplemental Resource.
33. Confirm the amended whole Supplier agreement and prove the original confirmation remains historical.
34. Prove the successor cannot activate until its own confirmation and contracted-rate gates pass.
35. Enter Offer Design explicitly and prove the supplemental O1 block has not silently joined the existing published O1 choice.
36. Where the test presents the supplemental block to Clients, create a separate draft option through the normal explicit Client-offer workflow.

The proof also requires:

- failed component saves do not alter siblings;
- failed confirmation saves do not alter rates, capacity, deposits, or deadlines;
- failed deposit, policy, or deadline saves do not alter rates or sibling definitions;
- command replay does not duplicate contracted definitions, confirmations, capacity events, or Supplier requirements;
- unsupported graphs remain readable and link to Advanced without rewrite;
- draft, governing, and proposed-successor states are distinguishable;
- a Viewer cannot mutate the workspace;
- exact-version confirmation from the governing Arrangement does not satisfy an unconfirmed successor;
- no second Service Offer is created during ordinary reopen or edit; and
- edit/remove actions submit stable IDs rather than labels, positions, `.first`, or `.last`.

## 14. Explicit exclusions

This scenario does not establish:

- Package placement;
- Client Trip selection or booking;
- canonical Client selling prices;
- allocation-specific Deposit Requirement occurrences before a booking exists;
- guest-card attribution;
- Supplier payments, refunds, invoices, obligations, or paid status;
- calculated cancellation charges or Client credits;
- a separate rooming-list deadline;
- automatic GAP fulfillment or TC-credit application;
- independent departure-port and return-port time-zone authority;
- Cruise-specific agreement-document storage;
- automatic contract extraction;
- booking-level materialization of the `$500` allocated-stateroom policy;
- automatic additional-deposit assumptions for future capacity changes;
- calculated Tour Conductor qualification, accrual, redemption, or application;
- calculated GAP allocation, fulfillment, redemption, or purchased-point accounting;
- one Client choice consuming capacity from multiple Supplier Pools; or
- automatic changes to published Client availability when Supplier capacity changes.

## 15. Superseded facts

The following earlier fixture assumptions are expressly superseded:

- category code `E1`; the canonical code is `E3`;
- treating the Single column as a complete Single price rather than an additive adjustment;
- the old O1 Single and DI Third discrepancy exceptions and their stated totals;
- the old O1, DI, and E3 Client-price tables that conflict with Section 12;
- commission rounded independently per occupancy band; commission is calculated on the combined profile and rounded once;
- an Arrangement-wide March 11 cumulative deposit deadline;
- a separate October 7 rooming-list deadline;
- five GAP points per traveler;
- mandatory duplicate evidence on every initial cabin category;
- silently recomputing the Arrangement name after creation;
- treating an estimated Cruise rate definition as sufficient for activation after contracted Supplier terms are available;
- treating Supplier agreement confirmation and Arrangement activation as the same transition;
- changing confirmed Supplier group reference or contract date by ordinary edit;
- recalculating the original `$1,200` initial-deposit requirement when later capacity is added;
- representing differently priced supplemental cabins as additional quantity on the original Pool;
- inventing a new Supplier category code to distinguish two real Supplier blocks that both use `O1`;
- allowing later Supplier capacity to silently alter an already published Client choice, Client price, source pin, or selectable quantity; and
- any other Celebrity Beyond fixture fact that conflicts with this scenario.