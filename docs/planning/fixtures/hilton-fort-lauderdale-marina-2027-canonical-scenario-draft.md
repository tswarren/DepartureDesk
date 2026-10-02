# Hilton Fort Lauderdale Marina 2027 — Canonical Hotel Agreement Scenario

**Status:** Approved 2026-09-27 at the single registered Hotel fixture path, `docs/planning/fixtures/hilton-fort-lauderdale-marina-2027-canonical-scenario-draft.md`. This is the Hotel agreement scenario for the Smith Family Reunion stay. The accepted [Slice 3A plan](../m4-offers-and-pricing/m4d1-slice3a-hotel-supplier-composition.md) names the facts it uses. Slice 3A.0 recorded four incompatibilities. Slice 3A.1, Hotel Supplier-term persistence foundations, is Accepted 2026-09-30. The Slice 3A.1 compatibility proof is green. Slice 3A.2, Stay and nightly inventory, is implemented. Hotel Supplier rates are shipped. [Hotel Agreement](../m4-offers-and-pricing/hotel-agreement.md) is Shipped 2026-10-01. [Hotel Review and Activation](../m4-offers-and-pricing/hotel-review-and-activation.md) is Shipped 2026-10-02. [Hotel Lifecycle](../m4-offers-and-pricing/hotel-lifecycle.md) is Shipped 2026-10-02. The contract/signature date and Hotel group or confirmation number stay blank.  
**Departure:** Smith Family Reunion  
**Supplier:** Hilton Fort Lauderdale Marina  
**Purpose:** Approved Hotel agreement facts and MVP proof scenario, with the [Hotel Staff walkthrough](../m4-offers-and-pricing/m4d1-hilton-hotel-staff-walkthrough.md).

## 1. Authority and scope

This scenario covers Supplier Composition only:

- the Hotel stay and service dates;
- contracted room categories and nightly room blocks;
- Supplier rates, taxes, and concessions;
- scheduled deposits, pre-stay adjustments, and later settlement policy;
- cutoff and room-assignment requirements;
- early-departure and attrition policy; and
- draft, governing, successor, and Advanced-fallback behavior.

It does not create a Service Offer, Client room choices, Client prices, Package placement, an “optional add-on,” or Client Trip selections. Those belong to later Offer Design and Client Trip authority.

The following earlier fixture facts are superseded:

- November 2–5 as the contracted stay;
- a constant block of 10 Standard and 5 Deluxe rooms across three nights;
- $225 Standard and $275 Deluxe rates;
- a separate $20 additional-adult component and $3.20 tax component;
- a 15% signing deposit;
- February 4 option and final-payment dates; and
- October 18 rooming-list timing;
- a Client Service connection or Standard/Deluxe Client choices in Supplier Composition;
- `hotel_room:` Client choice keys; and
- optional-add-on treatment for this Supplier Item.

## 2. Agreement identity

| Fact | Canonical value |
| --- | --- |
| Departure | Smith Family Reunion |
| Property | Hilton Fort Lauderdale Marina |
| Stay name | Pre-cruise hotel stay |
| Contract/signature date | Unspecified; leave blank |
| Hotel group or confirmation number | Unspecified; leave blank |
| Time zone | America/New_York |
| Check-in time | 3:00 p.m. |
| Checkout time | Noon |
| Contracted arrival | November 4, 2027 |
| Contracted departure | November 6, 2027 |
| Contracted nights | November 4 and November 5 |
| Currency displayed | USD, inherited from the Departure operating currency |

The Arrangement may contain more than one Hotel Item. Every workspace and mutation must identify this stay by its stable Arrangement Item ID rather than a label, creation order, `.first`, or `.last`.


## 3. Contracted room inventory

### 3.1 Nightly block

| Stay night | Standard rooms | Deluxe rooms | Total rooms |
| --- | ---: | ---: | ---: |
| November 4, 2027 | 5 | 2 | 7 |
| November 5, 2027 | 10 | 5 | 15 |
| **Contract total** | **15 room nights** | **7 room nights** | **22 room nights** |

The quantities vary by night. They must not be flattened into one constant opening quantity across the stay.

Each room category is a stable Hotel Resource. The nightly contracted quantities are Supplier-controlled room-unit capacity for the covered occurrence dates. They do not represent travelers, Hotel-wide physical inventory, expected pickup, or rooms already sold.

**Topology:** the accepted [Slice 3A plan](../m4-offers-and-pricing/m4d1-slice3a-hotel-supplier-composition.md) names the graph. One Stay Occurrence carries November 4 check-in through November 6 checkout and is not capacity-bearing. Each inventory night is its own single-day Occurrence, and each category/night block is one Pool. A free-text Pool label is not the date.

### 3.2 Occupancy

Both Standard and Deluxe support Single, Double, Triple, and Quad rate tiers, with a maximum modeled occupancy of four travelers per room.

The agreement does not distinguish adult and child rates. The third- and fourth-guest increments therefore apply by occupancy position, not by an inferred traveler category.

## 4. Contracted Supplier rates

| Room category | Single | Double | Triple | Quad |
| --- | ---: | ---: | ---: | ---: |
| Standard | $173.00 | $173.00 | $193.00 | $213.00 |
| Deluxe | $223.00 | $223.00 | $243.00 | $263.00 |

The supported economic meaning is:

- one room/night base rate includes occupancy positions one and two;
- occupancy position three adds $20 per room night;
- occupancy position four adds another $20 per room night; and
- no guest-category distinction is inferred.

The rates are net and noncommissionable. DepartureDesk must not create expected commission for this Hotel agreement.

### 4.1 Contracted room revenue

| Stay night | Calculation | Pretax revenue |
| --- | --- | ---: |
| November 4 | `5 × $173 + 2 × $223` | $1,311.00 |
| November 5 | `10 × $173 + 5 × $223` | $2,845.00 |
| **Total** |  | **$4,156.00** |

This total assumes Single/Double base occupancy for the contracted room block. Triple and Quad increments depend on actual guest occupancy and are not included in the opening block value.

## 5. Taxes

The agreement states:

- occupancy tax: 9.5%;
- state sales tax: 7%; and
- combined additive rate: 16.5% of taxable room charges.

At the original $4,156 pretax block value, illustrative taxes are:

\[
\$4,156.00 \times 16.5\% = \$685.74
\]

Taxes are paid by individual guests on occupied-room folios. The opening deposit schedule is based on pretax contracted room revenue. The $685.74 is therefore an illustrative tax exposure, not a Group master-account deposit or persisted total.

The agreement says tax rates may change. The saved contract captures the quoted rates and effective evidence; actual folios use the applicable tax authority at the time required by later billing authority.

## 6. Destination-fee concession

The Destination Fee is $150 per room night. The tax that would have applied to that fee is waived with it. Every room in the contracted block qualifies: all Standard and Deluxe rooms on November 4 and November 5. The waiver is per room night, not per guest. For those rooms the fee and its tax are $0 payable. This remains a Supplier concession. It is not a negative cost, a Client discount, or a cash credit, and this scenario does not promise it in a Client-facing offer.

The concession includes:

- high-speed in-room internet;
- local and domestic long-distance in-room calls;
- daily bottled water;
- round-trip airport shuttle service;
- Guest Service instant messaging; and
- daily Lobby Snack Hour from 5:00–6:00 p.m.

For MVP, this is a Supplier concession summary. DepartureDesk does not create a negative cost, Client discount, or cash credit from its stated value.

## 7. Additional nights

The contracted rates and concessions may be requested for November 1, 2, and 3, 2027, subject to Hotel availability.

These dates are not part of the contracted 22-room-night block and are not guaranteed. Failure to obtain a pre-stay room does not release the Group from its contracted block obligation. Additional nights become durable Supplier facts only when actually confirmed; the Hotel adapter must not silently add them to the original occurrence or capacity Pools. A night the Hotel confirms at the contracted rates and concessions includes the same Destination Fee waiver. An unconfirmed request has no fee and no waiver.

## 8. Reservation cutoff and room assignments

| Requirement | Canonical value |
| --- | --- |
| Cutoff | October 3, 2027 at 5:00 p.m. |
| Time zone | America/New_York |
| Assignment method | Approved rooming list or individual reservation channel |
| Action | Submit reservation/room-assignment information by cutoff |

After the cutoff, unassigned or unreserved rooms may be released from the Group block and sold to other parties. Requests received later are subject to availability.

October 3, 2027 is a Sunday. This scenario keeps that date and the 5:00 p.m. America/New_York time.

A room the Hotel releases after cutoff stays inside that night's attrition minimum and inside the Group deposit. The minimum remains 7 rooms on November 4 and 15 rooms on November 5. A released room counts as utilized only if it is rebooked through an approved channel at the contracted rate.

This is one actionable Supplier Deadline. Recording that the rooming list was delivered is an operational disposition of that deadline, not a second duplicate requirement.

## 9. Group deposits and reconciliation

### 9.1 Scheduled deposits

| Requirement | Due date | Amount | Percentage of original pretax block |
| --- | --- | ---: | ---: |
| Initial deposit | October 1, 2026 | $415.60 | 10% |
| Second deposit | May 7, 2027 | $1,870.20 | 45% |
| Third/final scheduled block deposit | October 4, 2027 | $1,870.20 | 45% |
| **Scheduled total** |  | **$4,156.00** | **100%** |

October 4 is the due date of the **final scheduled deposit for the original block**. It precedes the November 4–6 stay, so it cannot be the final reconciliation of actual occupancy, attrition, early departures, or unpaid guest folios. In this scenario the October 4 pre-stay review of then-known added rooms, added nights, or other estimated Group charges is $0. Any later addition needs its own evidenced amount and must not create a second charge for the original $4,156 block.

The last day of the block is the contracted departure, November 6, 2027. The governing refund date is on or before November 20, 2027. That date falls fourteen days after the departure. The governing sentence is the November 20 sentence in §9.3.

Each deposit is a separate Supplier Deposit Requirement definition with its own identity, due date, amount, and relationship to the **original** contracted-room-revenue target. The write-free summary shows the 10%/45%/45% derivation. Later pickup, room-rate changes, tax changes, or additions do not silently rebase these original scheduled amounts; an amendment or separately evidenced adjustment must name its basis. These are requirements, not recorded payments.

### 9.2 Guest and master-account billing

- Individual guests pay their occupied room charges and applicable tax on their folios. Actual tax rates may differ from the quoted 16.5%. Guests do not pay the Group deposits and do not receive the Group refund.
- The agency remits each of the three Group deposits. The Hotel refunds the unused balance to the agency.
- The refund is the amount the agency actually paid toward those deposits, minus the attrition shortfall defined in §10. Guest folio balances, including a collected early-departure charge, are not deducted again. A confirmed added room or night is billed separately and is not netted against this refund.

Deposits must not be added to guest-paid room expense as a second cost. Tax on the Group attrition shortfall is part of that shortfall. It is distinct from guest-paid tax on occupied-room folios.

### 9.3 Blocking contract conflict

The supplied clause's original wording, retained exactly, is: “Deposits are non-refundable.” This scenario keeps that sentence visible as history and replaces it with the governing refund rule: the Hotel refunds the agency on or before November 20, 2027, the amount actually paid toward the deposits minus the attrition shortfall. That clarification is recorded on the current draft before activation. It does not block activation, and it does not require a successor.

## 10. Attrition

The contracted guest-room minimum is evaluated by stay date:

| Stay night | Contracted minimum |
| --- | ---: |
| November 4 | 7 utilized room nights |
| November 5 | 15 utilized room nights |

- Meeting or exceeding a date’s contracted minimum produces no attrition charge for that date.
- Falling below the minimum makes the Group responsible for 100% of lost room revenue for that date.
- Overachievement on one date cannot offset a shortfall on another date.
- Only rooms booked through approved channels at contracted rates count as utilized.
- Rooms booked through an unrelated internet or discount channel do not count.
- Lost revenue equals the shortfall room count multiplied by the average room rate of rooms actually utilized for that date, plus applicable tax.

When a date has zero utilized rooms, the shortfall uses each unsold room's contracted single/double base rate: $173 for Standard and $223 for Deluxe, plus 16.5% tax. A completely unused night therefore equals that night's opening pretax block revenue plus tax. This is no longer an undefined fallback.

The stated nightly minimums equal the full contracted block on each night: 7 of 7 and 15 of 15. This is a zero-attrition allowance under the stated formula. A release after cutoff does not reduce either minimum. Do not borrow an 80% or other allowance from a different agreement. Actual attrition tax belongs to the Group liability rather than an occupied guest's folio.

**MVP representation:** retain this as version-owned agreement-reference wording on the Hotel Item. Do not materialize an attrition Obligation or charge before later Reservation facts establish actual utilized rooms, booking channels, rates, and taxes.

## 11. Early departure

If a guest checks out before the reserved departure date without advising the Hotel at or before check-in, the guest is charged one night’s room and tax on the individual folio. A collected early-departure fee reduces any sleeping-room attrition amount the Group otherwise owes.

For MVP, this is readable booking policy. It does not generate a Supplier cost, payment, or attrition credit until a later Reservation records an actual early departure and collected fee.

## 12. Cancellation

No separate group-cancellation schedule was supplied. DepartureDesk must not infer one from the attrition clause. The scenario records cancellation terms as “not separately specified” and keeps cancellation-fee calculation outside typed MVP behavior.

## 13. Activation and lifecycle

Before activation, Staff may independently edit the draft stay, room Resources, nightly inventory, rates, concessions, deposit definitions, and deadlines. Invalid saves retain entered values and leave valid sibling facts unchanged.

Activation preview is write-free and shows:

- the November 4–6 guest stay and its two dated inventory nights, without presupposing one versus several persisted Occurrences;
- Standard and Deluxe Resources;
- the nightly 5/2 and 10/5 inventory pattern;
- rates and occupancy tiers;
- the $4,156 pretax block derivation;
- the three scheduled deposits;
- the October 3 cutoff;
- the attrition policy without creating an obligation; and

Staff record that refund clarification on the current editable draft before activation. The original nonrefundable sentence stays visible and is not the governing outcome. Upload is not required. A pre-activation draft has no governing predecessor and needs no successor to record this clarification. After a version is activated, later changes use a successor and keep the governing facts read-only.

Governing facts are read-only. Later changes occur through a successor draft, with stable child identities preserved where shipped version-copy authority requires them. Unsupported definitions remain readable and link to an exact Advanced destination without rewriting supported siblings.

## 14. Canonical Hotel workspace summary

```text
HOTEL SUPPLIER PLANNING

Pre-cruise hotel stay
Hilton Fort Lauderdale Marina
November 4–6, 2027 · 2 nights · Draft · USD

Deposit refund
Hotel refunds the agency by November 20, 2027
Amount paid minus the attrition shortfall
Original wording: Deposits are non-refundable.

Rooms and inventory

Standard
Nov 4: 5 rooms · Nov 5: 10 rooms
Maximum occupancy: 4 travelers
$173 single/double · $193 triple · $213 quad

Deluxe
Nov 4: 2 rooms · Nov 5: 5 rooms
Maximum occupancy: 4 travelers
$223 single/double · $243 triple · $263 quad

Contracted room revenue
$4,156.00 before tax · 22 room nights
Net noncommissionable

Concessions
Destination Fee $150 per room night waived for every block room, tax included
Additional nights Nov 1–3 subject to availability; waiver applies only if confirmed

Deposits and deadlines
Initial deposit · $415.60 · Due Oct 1, 2026
Second deposit · $1,870.20 · Due May 7, 2027
Room assignments/cutoff · Oct 3, 2027 at 5:00 p.m.
Third/final block deposit · $1,870.20 · Due Oct 4, 2027
Oct 4 is the scheduled deposit only. This scenario adds $0 that day.
Refund to the agency on or before November 20, 2027.

Attrition
100% of per-date lost room revenue below the nightly minimum
Actual charge deferred until utilization exists
```

Client-facing Service, choices, and Package placement are outside this Supplier summary. No Client Service line or connection action is implied.

## 15. Blocking browser proof

Starting from Departure Composition, Staff must be able to:

1. Open the exact Hilton Supplier Arrangement.
2. Create the November 4–6 pre-cruise Hotel Item.
3. Create a second Hotel Item and reopen the first by stable Item ID.
4. Add Standard and Deluxe as stable room Resources.
5. Enter 5/2 rooms for November 4 and 10/5 rooms for November 5 without flattening the quantities.
6. Enter and reopen the Single, Double, Triple, and Quad rate tiers.
7. See the $4,156 pretax block calculation and the separately stated 16.5% guest-paid tax exposure.
8. Record the $150 per-room-night Destination Fee as waived for every contracted block room, including its tax, without creating a negative cost.
9. Record November 1–3 as availability-only additional-night terms rather than guaranteed inventory.
10. Create the three independent deposit definitions and see the 10%/45%/45% derivation.
11. Record the October 3 cutoff once and complete or reschedule it through shipped deadline authority.
12. See the per-date attrition policy without a materialized charge.
13. See the governing refund rule and the original nonrefundable sentence kept as history. The refund rule does not block activation.
14. Record that clarification on the current draft before activation, naming the agency as payer and refund recipient and November 20, 2027 as the refund deadline.
15. Rename a room or rate component without changing its stable identity.
16. Submit an invalid sibling edit and confirm earlier work remains unchanged.
17. View governing terms read-only and successor terms as proposed.
18. Confirm a Viewer may read the Hotel summary through a view-authorized route but cannot save, change, or activate Hotel terms. Hotel management routes return not found to a Viewer. Cross-Agency identifiers return not found on both read and management routes.

At least one browser proof must use two Hotel Items, with navigation by stable Item ID. The extra Item is test structure only: it is not another contracted component of this Hilton stay and must not change the 22-room-night block or its $4,156 base. Database-only graph construction does not satisfy this exit.

## 16. Fixture assertions and behavior boundaries

The commercial terms below are the Approved scenario values for this proof. The contract/signature date and Hotel group or confirmation number remain unspecified. The accepted [Slice 3A plan](../m4-offers-and-pricing/m4d1-slice3a-hotel-supplier-composition.md) names the facts it uses. Slice 3A.0 recorded four incompatibilities. Slice 3A.1, Hotel Supplier-term persistence foundations, is Accepted 2026-09-30. The Slice 3A.1 compatibility proof is green. Slice 3A.2, Stay and nightly inventory, is implemented. Hotel Supplier rates are shipped. [Hotel Agreement](../m4-offers-and-pricing/hotel-agreement.md) is Shipped 2026-10-01. [Hotel Review and Activation](../m4-offers-and-pricing/hotel-review-and-activation.md) is Shipped 2026-10-02. [Hotel Lifecycle](../m4-offers-and-pricing/hotel-lifecycle.md) is Shipped 2026-10-02.

1. The contracted stay is November 4–6, 2027.
2. Nightly inventory varies: 5 Standard/2 Deluxe, then 10 Standard/5 Deluxe.
3. The agreement contains 22 contracted room nights.
4. Both categories support occupancy tiers through Quad.
5. Standard is $173/$173/$193/$213; Deluxe is $223/$223/$243/$263.
6. Occupancy and sales tax are additive at 16.5% for the quoted agreement evidence.
7. Rates are net noncommissionable.
8. The Destination Fee is $150 per room night, and its related tax is waived, for every Standard and Deluxe room in the contracted block.
9. November 1–3 are availability-only additional nights, not guaranteed block inventory.
10. The room-assignment cutoff is October 3, 2027 at 5:00 p.m. America/New_York.
11. Guests pay their occupied room and tax folios.
12. The agency pays the three scheduled deposits, which total the original $4,156 pretax block. The Hotel refunds the agency the amount actually paid minus the attrition shortfall. Guests do not pay or receive that deposit.
13. October 4 is the final scheduled deposit date for the original block. This scenario adds $0 for the pre-stay review. The governing refund date is on or before November 20, 2027.
14. The original nonrefundable sentence stays visible as history. The refund rule in §9.3 is the governing outcome and does not block activation. A room released after cutoff does not reduce the nightly minimum or the deposit.
15. Attrition is evaluated independently per stay date and remains structured policy until actual utilization exists.
16. There is no separate supplied cancellation ladder.
17. Early-departure charges and attrition credits wait for Reservation facts.
18. This scenario ends at Supplier Composition; it creates no Service Offer, Client choices, pricing, or Package placement.

## 17. Scenario decisions and remaining blanks

The Hotel agreement text was not available. This scenario fills the former open commercial terms as follows:

1. The Destination Fee is $150 per room night, and the tax on that fee is waived, for every room in the contracted block.
2. The cutoff remains October 3, 2027 at 5:00 p.m. America/New_York, and the final scheduled deposit remains $1,870.20 on October 4, 2027.
3. October 4 adds $0 beyond that scheduled deposit. The Hotel refunds the agency on or before November 20, 2027.
4. The agency pays the deposits and receives the refund. The refund is the amount paid minus the attrition shortfall, including the zero-utilization rates in §10.
5. A release after cutoff does not reduce the nightly minimum or the deposit.
6. A later-confirmed November 1–3 night includes the same fee waiver. An unconfirmed request does not.

The contract/signature date and the Hotel group or confirmation number remain unspecified. Do not invent them.

The calculations `5 × $173 + 2 × $223 = $1,311`, `10 × $173 + 5 × $223 = $2,845`, `$1,311 + $2,845 = $4,156`, `10% + 45% + 45% = 100%`, and `$4,156 × 16.5% = $685.74` stay internally consistent. Do not substitute superseded illustrative Hotel figures.
