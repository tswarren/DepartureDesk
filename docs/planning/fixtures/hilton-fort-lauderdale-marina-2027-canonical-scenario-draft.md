# Hilton Fort Lauderdale Marina 2027 — Canonical Hotel Agreement Scenario

## 1. Status and authority

**Status:** Draft. Supplier Composition boundary locked. Not implementation authority.

This is the only Hotel canonical draft. When accepted, it supersedes conflicting Hilton fixture facts and the earlier illustrative Hotel walkthrough. No slice may rely on it until it is Approved and an accepted slice plan names it.

Written Hotel confirmation is required for the deposit-refund conflict before activation.

## 2. Purpose

Prove the Hotel agreement for the Smith Family Reunion pre-cruise stay: nightly blocks that vary by date, occupancy-position rates, percentage deposits on contracted room revenue, a second Hotel Item, and draft, governing, and successor behavior.

## 3. Source classification

Hotel agreement facts.

Unresolved:

- Contract or signature date: not specified.
- Hotel group or confirmation number: not specified.
- Whether unused Group deposits are refundable after reconciliation. The supplied clause calls the deposits non-refundable, while the operative understanding says unused funds are returned. Both facts stay visible. Written Hotel confirmation or an amended agreement is required before activation.

The agreement says tax rates may change. The saved contract captures the quoted rates and effective evidence. Actual folios use the applicable tax authority at the time required by later billing authority.

The contract does not define the average-rate fallback when zero rooms are utilized. That case remains Advanced and requires Hotel clarification.

No separate group-cancellation schedule was supplied.

## 4. Departure facts

| Fact | Canonical value |
| --- | --- |
| Departure | Smith Family Reunion |
| Property | Hilton Fort Lauderdale Marina |
| Stay name | Pre-cruise hotel stay |
| Contract/signature date | Not specified |
| Hotel group or confirmation number | Not specified |
| Time zone | America/New_York |
| Check-in time | 3:00 p.m. |
| Checkout time | Noon |
| Contracted arrival | November 4, 2027 |
| Contracted departure | November 6, 2027 |
| Contracted nights | November 4 and November 5 |
| Currency | USD |

## 5. Supplier Arrangement topology

The Arrangement may contain more than one Hotel Item. Every workspace and mutation must identify this stay by its stable Arrangement Item ID rather than a label, creation order, `.first`, or `.last`.

This scenario's contracted stay is one Hotel Item for November 4–6, 2027. A blocking proof also creates a second Hotel Item and reopens the first by stable Item ID.

## 6. Resources and capacity

### Nightly block

| Stay night | Standard rooms | Deluxe rooms | Total rooms |
| --- | ---: | ---: | ---: |
| November 4, 2027 | 5 | 2 | 7 |
| November 5, 2027 | 10 | 5 | 15 |
| **Contract total** | **15 room nights** | **7 room nights** | **22 room nights** |

The quantities vary by night. They must not be flattened into one constant opening quantity across the stay.

Each room category is a stable Hotel Resource. The nightly contracted quantities are Supplier-controlled room-unit capacity for the covered occurrence dates. They do not represent travelers, Hotel-wide physical inventory, expected pickup, or rooms already sold.

### Occupancy

Both Standard and Deluxe support Single, Double, Triple, and Quad rate tiers, with a maximum modeled occupancy of four travelers per room.

The agreement does not distinguish adult and child rates. The third- and fourth-guest increments therefore apply by occupancy position, not by an inferred traveler category.

### Additional nights

The contracted rates and concessions may be requested for November 1, 2, and 3, 2027, subject to Hotel availability.

These dates are not part of the contracted 22-room-night block and are not guaranteed. Failure to obtain a pre-stay room does not release the Group from its contracted block obligation. Additional nights become durable Supplier facts only when actually confirmed. The Hotel adapter must not silently add them to the original occurrence or capacity Pools.

### Attrition minimums

The contracted guest-room minimum is evaluated by stay date:

| Stay night | Contracted minimum |
| --- | ---: |
| November 4 | 7 utilized room nights |
| November 5 | 15 utilized room nights |

## 7. Supplier costs

| Room category | Single | Double | Triple | Quad |
| --- | ---: | ---: | ---: | ---: |
| Standard | $173.00 | $173.00 | $193.00 | $213.00 |
| Deluxe | $223.00 | $223.00 | $243.00 | $263.00 |

- One room/night base rate includes occupancy positions one and two.
- Occupancy position three adds $20 per room night.
- Occupancy position four adds another $20 per room night.
- No guest-category distinction is inferred.

The rates are net and noncommissionable. DepartureDesk must not create expected commission for this Hotel agreement.

| Stay night | Calculation | Pretax revenue |
| --- | --- | ---: |
| November 4 | `5 × $173 + 2 × $223` | $1,311.00 |
| November 5 | `10 × $173 + 5 × $223` | $2,845.00 |
| **Total** |  | **$4,156.00** |

This total assumes Single/Double base occupancy for the contracted room block. Triple and Quad increments depend on actual guest occupancy and are not included in the opening block value.

### Taxes

- Occupancy tax: 9.5%.
- State sales tax: 7%.
- Combined additive rate: 16.5% of taxable room charges.

At the original $4,156 pretax block value, illustrative taxes are:

\[
\$4,156.00 \times 16.5\% = \$685.74
\]

Taxes are paid by individual guests on occupied-room folios. The opening deposit schedule is based on pretax contracted room revenue. The $685.74 is an illustrative tax exposure, not a Group master-account deposit or persisted total.

### Destination-fee concession

The Hotel waives a Destination Fee stated as $150 per room night plus tax. The fee and related tax are both $0 payable for qualifying reservations under this agreement.

The concession includes high-speed in-room internet, local and domestic long-distance in-room calls, daily bottled water, round-trip airport shuttle service, Guest Service instant messaging, and daily Lobby Snack Hour from 5:00–6:00 p.m.

For MVP, this is a Supplier concession summary. DepartureDesk does not create a negative cost, Client discount, or cash credit from its stated value.

### Attrition policy

- Meeting or exceeding a date's contracted minimum produces no attrition charge for that date.
- Falling below the minimum makes the Group responsible for 100% of lost room revenue for that date.
- Overachievement on one date cannot offset a shortfall on another date.
- Only rooms booked through approved channels at contracted rates count as utilized.
- Rooms booked through an unrelated internet or discount channel do not count.
- Lost revenue equals the shortfall room count multiplied by the average room rate of rooms actually utilized for that date, plus applicable tax.

Retain this as structured policy attached to the Hotel Item. Do not materialize an attrition Obligation or charge before later Reservation facts establish actual utilized rooms, booking channels, rates, and taxes.

### Early departure

If a guest checks out before the reserved departure date without advising the Hotel at or before check-in, the guest is charged one night's room and tax on the individual folio. A collected early-departure fee reduces any sleeping-room attrition amount the Group otherwise owes.

For MVP, this is readable booking policy. It does not generate a Supplier cost, payment, or attrition credit until a later Reservation records an actual early departure and collected fee.

## 8. Deposits and deadlines

| Requirement | Due date | Amount | Percentage of original pretax block |
| --- | --- | ---: | ---: |
| Initial deposit | October 1, 2026 | $415.60 | 10% |
| Second deposit | May 7, 2027 | $1,870.20 | 45% |
| Third/final scheduled block deposit | October 4, 2027 | $1,870.20 | 45% |
| **Scheduled total** |  | **$4,156.00** | **100%** |

October 4 is also the final reconciliation date for additional rooms, additional room nights, and other permitted Group master-account liabilities. It must not create a duplicate second charge for the original $4,156 block.

Each deposit is a separate Supplier Deposit Requirement definition with its own identity, due date, amount, and relationship to the original contracted-room-revenue target. The write-free summary shows the 10%/45%/45% derivation.

- Individual guests pay their occupied room charges and applicable 16.5% tax on their folios.
- Group deposits secure the contracted block and are applied to permitted Group master-account liabilities, including attrition, unpaid covered charges, added rooms or nights, and other reconciled Group amounts.
- After final reconciliation, unused deposit funds are returned to the Group.

Until the refund conflict is resolved, readiness reports:

> Confirm whether unused Group deposits are refundable after final reconciliation.

The MVP must not silently choose one interpretation.

### Reservation cutoff

| Requirement | Canonical value |
| --- | --- |
| Cutoff | October 3, 2027 at 5:00 p.m. |
| Time zone | America/New_York |
| Assignment method | Approved rooming list or individual reservation channel |
| Action | Submit reservation/room-assignment information by cutoff |

After the cutoff, unassigned or unreserved rooms may be released from the Group block and sold to other parties. Requests received later are subject to availability.

This is one actionable Supplier Deadline. Recording that the rooming list was delivered is an operational disposition of that deadline, not a second duplicate requirement.

## 9. Cancellation terms

No separate group-cancellation schedule was supplied. DepartureDesk must not infer one from the attrition clause. The scenario records cancellation terms as not separately specified and keeps cancellation-fee calculation outside typed MVP behavior.

## 10. Expected summaries

```text
HOTEL SUPPLIER PLANNING

Pre-cruise hotel stay
Hilton Fort Lauderdale Marina
November 4–6, 2027 · 2 nights · Draft · USD

Needs attention
Confirm whether unused Group deposits are refundable after reconciliation.

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
Destination Fee waived, including related tax
Additional nights Nov 1–3 subject to availability

Deposits and deadlines
Initial deposit · $415.60 · Due Oct 1, 2026
Second deposit · $1,870.20 · Due May 7, 2027
Room assignments/cutoff · Oct 3, 2027 at 5:00 p.m.
Third/final block deposit · $1,870.20 · Due Oct 4, 2027

Attrition
100% of per-date lost room revenue below the nightly minimum
Actual charge deferred until utilization exists
```

Client service is not a line in this summary. Supplier Composition does not configure it.

## 11. Required proof

Before activation, Staff may independently edit the draft stay, room Resources, nightly inventory, rates, concessions, deposit definitions, and deadlines. Invalid saves retain entered values and leave valid sibling facts unchanged.

Activation preview is write-free and shows the two-night occurrence, Standard and Deluxe Resources, the nightly 5/2 and 10/5 inventory pattern, rates and occupancy tiers, the $4,156 pretax block derivation, the three scheduled deposits, the October 3 cutoff, the attrition policy without creating an obligation, and the unresolved deposit-refund conflict as a blocker.

Governing facts are read-only. Later changes occur through a successor draft, with stable child identities preserved where shipped version-copy authority requires them. Unsupported definitions remain readable and link to an exact Advanced destination without rewriting supported siblings.

Starting from Departure Composition, Staff must be able to:

1. Open the exact Hilton Supplier Arrangement.
2. Create the November 4–6 pre-cruise Hotel Item.
3. Create a second Hotel Item and reopen the first by stable Item ID.
4. Add Standard and Deluxe as stable room Resources.
5. Enter 5/2 rooms for November 4 and 10/5 rooms for November 5 without flattening the quantities.
6. Enter and reopen the Single, Double, Triple, and Quad rate tiers.
7. See the $4,156 pretax block calculation and the separately stated 16.5% guest-paid tax exposure.
8. Record the fully waived Destination Fee concession without creating a negative cost.
9. Record November 1–3 as availability-only additional-night terms rather than guaranteed inventory.
10. Create the three independent deposit definitions and see the 10%/45%/45% derivation.
11. Record the October 3 cutoff once and complete or reschedule it through shipped deadline authority.
12. See the per-date attrition policy without a materialized charge.
13. See the deposit-refund conflict block activation.
14. Correct that conflict through a successor or accepted evidence without rewriting unrelated facts.
15. Rename a room or rate component without changing its stable identity.
16. Submit an invalid sibling edit and confirm earlier work remains unchanged.
17. View governing terms read-only and successor terms as proposed.
18. Confirm a Viewer receives not found for Hotel management routes.

At least one browser proof must use two Hotel Items. Database-only graph construction does not satisfy this exit.

Locked meanings the proof must keep:

1. The contracted stay is November 4–6, 2027.
2. Nightly inventory varies: 5 Standard / 2 Deluxe, then 10 Standard / 5 Deluxe.
3. The agreement contains 22 contracted room nights.
4. Both categories support occupancy tiers through Quad.
5. Standard is $173 / $173 / $193 / $213. Deluxe is $223 / $223 / $243 / $263.
6. Occupancy and sales tax are additive at 16.5% for the quoted agreement evidence.
7. Rates are net noncommissionable.
8. The Destination Fee and its related tax are fully waived.
9. November 1–3 are availability-only additional nights, not guaranteed block inventory.
10. The room-assignment cutoff is October 3, 2027 at 5:00 p.m. America/New_York.
11. Guests pay their occupied room and tax folios.
12. Deposits total the original $4,156 pretax block and secure master-account liability.
13. October 4 settles additional rooms, nights, and permitted adjustments without duplicating the original block charge.
14. Excess reconciled deposits are expected to be returned, but the conflicting nonrefundable clause blocks activation until corrected in writing.
15. Attrition is evaluated independently per stay date and remains structured policy until actual utilization exists.
16. There is no separate supplied cancellation ladder.
17. Early-departure charges and attrition credits wait for Reservation facts.
18. This scenario ends at Supplier Composition.

## 12. Explicit exclusions

This scenario creates no Service Offer, Client room choices, Client prices, Package placement, optional add-on, or Client Trip selections. Those belong to later Offer Design and Client Trip authority.

"Client service is not configured" is an exclusion. It is not a connection step and it is not a summary action.

Also excluded:

- Expected commission.
- A negative cost, Client discount, or cash credit from the waived Destination Fee.
- A materialized attrition charge before Reservation facts exist.
- An inferred group-cancellation ladder.
- Silently choosing whether unused deposits are refundable.

## 13. Superseded facts

The discarded walkthrough at [../history/m4d1-slice3-a-hotel.md](../history/m4d1-slice3-a-hotel.md) is superseded. These earlier fixture facts must not return:

- November 2–5 as the contracted stay.
- A constant block of 10 Standard and 5 Deluxe rooms across three nights.
- $225 Standard and $275 Deluxe rates.
- A separate $20 additional-adult component and $3.20 tax component.
- A 15% signing deposit.
- February 4 option and final-payment dates.
- October 18 rooming-list timing.
- Client Service connection, Standard and Deluxe Client choices, `hotel_room:` keys, and optional-add-on treatment.
