# Celebrity Beyond 2027 — Canonical Cruise Scenario

## 1. Status and authority

**Status:** Draft. Not implementation authority.

When accepted, this scenario supersedes every earlier Celebrity Beyond fixture fact, illustrative amount, walkthrough value, and proof assumption that conflicts with it. Earlier documents may remain as implementation history, but they must not be used to fill a field that this scenario defines differently.

Shipped Cruise slices keep their own contracts. This draft does not reopen them. No unaccepted slice may rely on it.

The MVP representation of the Supplier facts is locked: the initial deposit is typed; the Hard Stop is one combined actionable Deadline; final payment is a separate actionable Deadline; allocation-sensitive deposits and legal-name actions remain readable but unmaterialized until booking facts exist; normal commission is typed; tour-conductor credit and GAP are planning entitlements.

## 2. Purpose

Canonical Supplier Composition proof for controlled cabin inventory, occupancy-position Supplier components, and a cumulative initial deposit across cabin pools.

## 3. Source classification

Three kinds of facts:

- **Canonical Supplier facts** are authoritative contract and planning facts.
- **Illustrative Client figures** demonstrate a reviewed copy or markup workflow but are not accepted Client selling prices. They are recorded under explicit exclusions as shipped Cruise Offer Design.
- **Source-qualified policy terms** come from the July 2025 Celebrity Groups brochure, together with the agency's 15% commission rule. Because Celebrity may amend group policy, the brochure is dated evidence for this Arrangement rather than timeless global policy.

The brochure is general Celebrity group policy dated July 2025 and says policies may change without notice. The accepted scenario must retain it as dated evidence and allow sailing-specific terms to override it.

Unresolved until a later source correction:

- The O1 Single stated vacation total of $4,118 does not follow the displayed −$1,545 discount. The stated Single totals are authoritative. The application must not silently repair this column. A detector or copy review should surface the discrepancy.
- The DI third-passenger stated Supplier gross of $134.26 and illustrative Client total of $184.26 are authoritative. The displayed $10 base and $320 NCCF do not contribute to that stated total. The application must not replace the stated total with $464.26.

The brochure does not supply a separate rooming-list deadline, citizenship-document deadline, or manifest-delivery date for this sailing. GAP amenity allocation, fulfillment, and any purchased points remain Advanced planning.

The MVP records only facts that the current Supplier-planning layer can evaluate truthfully. Booking-dependent rules remain visible as contract policy but do not materialize booking-level obligations until a later Reservation or Client Trip layer has the allocation, traveler, payment, and attribution facts required to evaluate them.

## 4. Departure facts

| Fact | Canonical value |
| --- | --- |
| Group | Smith Family Reunion |
| Supplier | Celebrity Cruises |
| Ship | Celebrity Beyond |
| Itinerary | 7-Night Eastern Caribbean |
| Sailing | November 6–13, 2027 |
| Supplier group reference | 1119999 |
| Currency | USD |

## 5. Supplier Arrangement topology

Staff creates or opens one Cruise Arrangement for this sailing. All cabin resources, inventory, Supplier costs, deposits, and deadlines belong to that Arrangement and its versioned graph.

Before activation, Staff can independently edit the draft cabin inventory, Supplier cost components, deposit definitions, and deadline definitions. An invalid save preserves entered values and leaves valid siblings unchanged.

Activation preview is write-free and shows the three cabin Pools and opening quantities, the initial deposit calculation, the allocation-sensitive full-deposit policy without materializing a false Arrangement-wide obligation, the combined Hard Stop action, the actionable and informational deadlines, and any missing fact that prevents materialization.

Activation materializes operational occurrences from the accepted definitions. Governing definitions become read-only. Later planning changes occur on a successor draft and must preserve stable identities where the version-copy rules require them.

## 6. Resources and capacity

The initial block contains 24 cabins across three categories.

| Code | Supplier category | Maximum guests per cabin | Initially blocked cabins |
| --- | --- | ---: | ---: |
| E3 | Edge Stateroom with Veranda | 3 | 8 |
| O1 | Prime Oceanview | 3 | 8 |
| DI | Deluxe Inside Stateroom | 3 | 8 |
| **Total** |  |  | **24** |

Each category is a distinct Cruise cabin Resource with its own stable identity. Each category has a typed cabin Capacity Pool. The opening block quantity is 8 for each Pool. Maximum occupancy is 3 for each Resource. Maximum occupancy is not a substitute for blocked inventory.

The three confirmed occupancy profiles are:

- Single: one guest in one cabin.
- Double: two guests in one cabin, using first- and second-passenger positions.
- Triple: three guests in one cabin, using first-, second-, and third-passenger positions.

## 7. Supplier costs

The following values reproduce the supplied source table. Monetary values are per guest or occupancy position unless the column is explicitly Single. Illustrative Client rows stay in the source table so the discrepancy notes remain attached to the stated figures. They are not canonical selling prices.

### E3 — Edge Stateroom with Veranda

| Component or result | First/second passenger | Third passenger | Single |
| --- | ---: | ---: | ---: |
| Base fare | $2,533.00 | $10.00 | $2,533.00 |
| NCCF | $320.00 | $320.00 | $320.00 |
| Discount | −$950.00 | $0.00 | −$950.00 |
| Vacation total | $1,903.00 | $330.00 | $1,903.00 |
| Taxes, fees, and port charges | $134.26 | $134.26 | — |
| Supplier gross total | $2,037.26 | $464.26 | $1,903.00 |
| Expected commission (15%) | $237.45 | $1.50 | $237.45 |
| Supplier net | $1,799.81 | $462.76 | $1,665.55 |
| Illustrative agency markup | $50.00 | $50.00 | $50.00 |
| Illustrative Client total | $2,087.26 | $514.26 | $1,953.00 |
| Illustrative agency profit | $287.45 | $51.50 | $287.45 |

### O1 — Prime Oceanview

| Component or result | First/second passenger | Third passenger | Single |
| --- | ---: | ---: | ---: |
| Base fare | $1,739.00 | $10.00 | $3,478.00 |
| NCCF | $320.00 | $320.00 | $640.00 |
| Displayed discount | −$772.50 | $0.00 | −$1,545.00 |
| Vacation total | $1,286.50 | $330.00 | $4,118.00 |
| Taxes, fees, and port charges | $134.26 | $134.26 | $134.26 |
| Supplier gross total | $1,420.76 | $464.26 | $4,252.26 |
| Expected commission (15%) | $144.98 | $1.50 | $289.95 |
| Supplier net | $1,275.78 | $462.76 | $3,962.31 |
| Illustrative agency markup | $50.00 | $50.00 | $100.00 |
| Illustrative Client total | $1,470.76 | $514.26 | $4,352.26 |
| Illustrative agency profit | $194.98 | $51.50 | $389.95 |

The stated O1 Single totals are authoritative. The displayed −$1,545 Single discount does not reduce the stated $4,118 vacation total.

### DI — Deluxe Inside Stateroom

| Component or result | First/second passenger | Third passenger | Single |
| --- | ---: | ---: | ---: |
| Base fare | $1,559.00 | $10.00 | $3,118.00 |
| NCCF | $320.00 | $320.00 | $640.00 |
| Discount | −$705.00 | $0.00 | −$1,410.00 |
| Vacation total | $1,174.00 | $0.00 | $2,348.00 |
| Taxes, fees, and port charges | $134.26 | $134.26 | $134.26 |
| Supplier gross total | $1,308.26 | $134.26 | $2,482.26 |
| Expected commission (15%) | $128.10 | $1.50 | $256.20 |
| Supplier net | $1,180.16 | $132.76 | $2,226.06 |
| Illustrative agency markup | $50.00 | $50.00 | $100.00 |
| Illustrative Client total | $1,358.26 | $184.26 | $2,582.26 |
| Illustrative agency profit | $178.10 | $51.50 | $356.20 |

The stated DI third-passenger Supplier gross of $134.26 is authoritative. The displayed $10 base and $320 NCCF do not contribute to that stated total.

### Meaning of the rows

- Base fare, NCCF, discount, and taxes, fees, and port charges are distinct Supplier components.
- A discount is a negative Supplier component.
- The agency's normal booking commission is 15% of commissionable cruise fare: `15% × (Base fare − Discount)`. NCCF, government fees, taxes, and port charges are noncommissionable. This commission exists independently of GAP and is not purchased with amenity points.
- Commission is rounded per occupancy-position line to the nearest cent. The supplied table's conflicting Commission, Supplier Net, and Agency Profit rows are superseded by this rule and the recalculated values above.
- Expected commission is distinct from Supplier cost and is not Client revenue.
- Supplier net is a derived review value: Supplier gross less expected commission.
- Agency markup, Client total, and agency profit are illustrative review values only.
- Reopening a supported schedule must preserve category identity, occupancy-position identity, component identity, and the supplied values.

### Normal agency commission

The agency earns its normal 15% booking commission on Base fare less Discount. NCCF, taxes, government fees, and port charges are noncommissionable. GAP points do not create or fund this commission.

### Tour-conductor credit

- One cruise-only TC credit is earned per sixteen full-tariff guests, based on double occupancy.
- First- and second-position full-tariff guests qualify; third and fourth passengers do not.
- A single paying 200% of the full fare counts as two guests for TC qualification.
- Credit value uses the average cruise fare of the stateroom categories booked within the group.
- NCCF, government fees, and taxes are excluded, and the credit is net of commission.
- The default 1-per-16 ratio may be improved to 1 per 14 for four GAP points or 1 per 12 for six GAP points.

TC qualification, valuation, and redemption must be shown separately. A projected credit is not a Supplier payment or a reduction of a specific booking until it is actually applied.

Track the entitlement status as `projected`, `earned`, `applied`, or `forfeited`, and provide a write-free projection. Do not create a Supplier Payment, Client credit, or negative Supplier cost merely because a credit is projected.

### Group Amenity Program

This Deposit Program group receives a standard entitlement of **four group GAP points**, not five points per traveler.

- Points are expected forty days after group creation if the group was deposited by day thirty.
- The group must retain at least eight staterooms.
- GAP selections must be made before final payment.
- Unallocated GAP is forfeited at final payment if the group falls below eight staterooms.
- Standard amenities are for full-paying guests and exclude third and fourth passengers unless a selected amenity says otherwise.
- Additional points for guest-facing amenities may be purchased for $12.50 per point per stateroom.

For this scenario, DepartureDesk records the four-point entitlement and whether it has been allocated. Selecting and fulfilling a particular amenity remains Advanced planning until an accepted concessions model exists.

### Marketing support

General marketing support consists of access to Celebrity's Group Sales Kit and Supplier review of promotional materials. Promotional materials require Celebrity approval and must identify the ship's registry.

A cash Marketing Fund is not automatically included. It is an optional GAP allocation:

| Marketing fund | GAP cost |
| --- | ---: |
| $25 per stateroom | 2 points |
| $50 per stateroom | 4 points |
| $75 per stateroom | 6 points |
| $100 per stateroom | 8 points |

If selected, the Marketing Fund is deducted from the invoice at final payment and is limited to one payout per group per stateroom.

For MVP, general marketing support is informational and any GAP-funded Marketing Fund remains an unallocated or selected Advanced concession. It is not normal commission and does not change the 15% commission component.

## 8. Deposits and deadlines

### Initial deposit

- Group creation date: September 13, 2026.
- Due date: October 13, 2026, thirty days after group creation.
- Amount: $50 × unallocated staterooms held in the Deposit Program.
- Authoritative quantity at opening: 24 cabins.
- Initial amount: **$1,200**.
- Coverage: the whole Cruise Arrangement, with the quantity derived from the three selected cabin Pools (8 + 8 + 8).

The summary must show the derivation, not merely `$1,200`.

### Full allocated-stateroom deposit

- A seven-night itinerary requires a full deposit of $500 per allocated stateroom.
- For each allocated stateroom, the full deposit and required legal names are due at the earliest applicable event: when full legal names are added; within thirty days after that stateroom is allocated; or the Hard Stop on July 9, 2027.
- Full legal names and full deposits are also due at the end of an applicable shorter option period.
- The initial $50 paid for a stateroom contributes toward its $500 full-deposit requirement; the remaining amount is $450 for a stateroom to which that initial payment is attributable.

This is allocation-sensitive operational policy. The summary must distinguish unallocated group inventory from allocated stateroom bookings and show the applicable trigger for each projected requirement. It must not present one Arrangement-wide March 11 cumulative deadline as though the brochure established it.

Keep this as a readable, structured contract rule associated with the Cruise Arrangement. Do not materialize an Arrangement-wide final Deposit Requirement amount or occurrence. A future Reservation or Client Trip workflow creates the booking-level obligation only after it knows the allocated stateroom, allocation date, travelers, credited initial payment, and applicable option period.

### Other Supplier deadlines

| Requirement | Date | Operational effect |
| --- | --- | --- |
| Name, fully deposit, or release at Hard Stop | July 9, 2027 | Name and fully deposit allocated staterooms; release remaining unsold inventory |
| Final payment | August 8, 2027 | Final payment for this seven-night sailing; nonpayment may cancel the group |

For MVP, the Hard Stop is one combined actionable Arrangement-level Deadline:

> **Name and fully deposit allocated staterooms, or release remaining inventory**
> July 9, 2027
> Full deposit: $500 per allocated stateroom. Credit the initial $50 where attributable.

Do not create separate Arrangement-level deadlines for legal names, the full deposit, and inventory release. The allocation-triggered name and deposit rules remain visible as policy text and later generate booking-specific actions in the Reservation or Client Trip layer. Recording `names_assigned_to_supplier` is evidence that an operational event occurred. It is not a second contractual deadline.

The brochure does not establish a separate October 7 rooming-list deadline. That earlier fixture fact is superseded.

### Payment-method restrictions

- An agency corporate card may fund the initial $50-per-stateroom group deposit.
- As legal names are supplied, the agency card must be refunded and the applicable guest card cross-referenced.
- An agency corporate card cannot fund named space or final payment.
- A travel partner's personal card is limited to the initial group deposit or payment for the travel partner, a friend, or a family member, with that relationship documented.

Display these restrictions as informational policy. Do not create payment transactions, refunds, card records, or paid status in Supplier Composition.

## 9. Cancellation terms

For this seven-night sailing, cancellation charges apply per person:

| Days before departure | Charge |
| --- | ---: |
| 90 or more | Full refund, except nonrefundable-deposit offers |
| 89–75 | 25% of total fare |
| 74–61 | 50% of total fare |
| 60–31 | 75% of total fare |
| 30 or fewer | 100% of total fare |

Taxes and fees are excluded from the percentage base. Where the brochure's footnote applies, the charge is the calculated percentage or the deposit amount, whichever is greater. This booking-level cancellation ladder is not the same as releasing unallocated group inventory at the Hard Stop.

Retain the ladder as a structured contract summary or Advanced term. Do not calculate cancellation fees, refunds, or Client credits before the Reservation and accounting layers exist.

## 10. Expected summaries

```text
Deposits and deadlines

Initial group deposit
$50 × 24 initially blocked staterooms = $1,200
Due October 13, 2026

Hard Stop
July 9, 2027
Name and fully deposit allocated staterooms, or release inventory
Full deposit: $500 per allocated stateroom
Allocation-specific calculation occurs with the booking

Final payment
August 8, 2027

Commercial benefits

Normal commission
15% of Base fare less Discount

Tour-conductor credit
1 per 16 qualifying guests · Projected

Group amenities
4 GAP points expected · Not allocated
```

## 11. Required proof

One browser-level Supplier Composition proof begins at Departure Composition:

1. Staff creates or opens the Celebrity Beyond Cruise Arrangement.
2. Staff enters sailing identity and the three cabin Resources.
3. Staff sets maximum occupancy 3 and opening block quantity 8 for each category.
4. Staff enters each Supplier component by category and occupancy position.
5. Staff reopens the schedule and sees the same category, position, component, and value identities.
6. Staff creates the typed initial deposit, combined Hard Stop Deadline, and final-payment Deadline, and records the allocation-sensitive full-deposit policy without materializing it as an Arrangement-wide occurrence.
7. Staff sees the $1,200 initial-deposit derivation and a readable explanation that a future booking-level $500 obligation credits an attributable initial $50.
8. Staff previews activation without writes, corrects any missing fact, and activates through the accepted Arrangement activation path.

The proof also requires:

- a failed component save does not alter sibling components;
- a failed deposit or deadline save does not alter rates or sibling definitions;
- unsupported graphs remain readable and link to Advanced without rewrite;
- draft, governing, and successor states are distinguishable;
- a Viewer cannot mutate the workspace; and
- all edit and remove actions submit stable record identities rather than labels, positions, `.first`, or `.last`.

Before this draft becomes Approved:

- confirm whether the two source discrepancies should remain warnings or become intentionally modeled non-contributing components;
- confirm that illustrative Client figures remain non-authoritative; and
- replace or mark superseded every conflicting Cruise scenario table and proof fixture.

## 12. Explicit exclusions

Package placement and Client Trip selection remain outside this scenario. Allocation-specific deposit occurrences, guest-card attribution, cancellation charges, refunds, and legal-name actions remain deferred to the Reservation, Client Trip, and accounting layers.

### Shipped Cruise Offer Design

The following is already shipped Cruise behavior. It is not Supplier Composition authority and it is not a pattern for Hotel Slice 3A.

Staff may connect the Cruise Arrangement Item to one Cruise Service Offer. The connection pins the selected Arrangement version and exposes one choice for each cabin category:

- E3 — Edge Stateroom with Veranda
- O1 — Prime Oceanview
- DI — Deluxe Inside Stateroom

Each choice receives a stable stored `cruise_cabin:` rate-category key. The key is minted once and copied unchanged to successor drafts. The choices initially have no separate option surcharge. Category pricing, if configured, uses their stored keys.

This connection does not decide Package placement. The scenario does not state that the Cruise is included, optional, or required in a Package. It also does not state that any Client booked it.

The source includes markup and Client-total columns. This scenario preserves them as illustrative copies, not canonical selling prices.

| Category | Single | Double | Triple |
| --- | ---: | ---: | ---: |
| E3 | $1,953.00 | $4,174.52 | $4,688.78 |
| O1 | $4,352.26 | $2,941.52 | $3,455.78 |
| DI | $2,582.26 | $2,716.52 | $2,900.78 |

The Double amount is two first/second Client totals. The Triple amount adds the stated third-passenger Client total. These cards must be labeled illustrative and must not imply that the service has been placed in a Package, published, or booked.

If Staff copies a Supplier component into Client terms, the copied Client cell retains provenance to that exact Supplier component. Later Supplier edits may mark the copy changed, but they do not silently change the Client amount.

Shipped Cruise proof of this handoff, already outside this fixture's Supplier Composition proof:

- Staff connects one Cruise Service Offer and explicitly selects all three cabin categories.
- Staff reopens the connection and sees the same choice and rate-key identities without exposing internal ids or keys in ordinary UI.
- Staff reviews the illustrative Single, Double, and Triple figures, clearly separated from Supplier facts.
- The page states that Package placement and Client Trip selection remain outside this scenario.
- No second Service Offer is created during reopen or edit.

## 13. Superseded facts

- The supplied table's conflicting Commission, Supplier Net, and Agency Profit rows, replaced by the 15% rule and the recalculated values in Supplier costs.
- A separate October 7 rooming-list deadline.
- One Arrangement-wide March 11 cumulative deadline treated as if the brochure established it.
- Five GAP points per traveler.
- Any earlier Celebrity Beyond fixture fact that conflicts with this scenario.
