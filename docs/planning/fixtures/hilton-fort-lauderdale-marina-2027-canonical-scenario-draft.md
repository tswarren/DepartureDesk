# Hilton Fort Lauderdale Marina 2027 — Canonical Hotel Agreement Scenario

**Status:** Draft for review at the single registered Hotel fixture path, `docs/planning/fixtures/hilton-fort-lauderdale-marina-2027-canonical-scenario-draft.md`. Not Approved or implementation authority. Written Hotel clarification of the deposit-refund conflict is required before activation; this document does not itself supply that clarification.  
**Departure:** Smith Family Reunion  
**Supplier:** Hilton Fort Lauderdale Marina  
**Purpose:** Proposed canonical Hotel agreement facts and MVP proof scenario. The separate Staff walkthrough may settle the journey while this fixture remains Draft. Approval of this fixture requires checking the specified source facts; replacing the registered Draft file does not Approve it.

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
| Contract/signature date | Not specified |
| Hotel group or confirmation number | Not specified |
| Time zone | America/New_York |
| Check-in time | 3:00 p.m. |
| Checkout time | Noon |
| Contracted arrival | November 4, 2027 |
| Contracted departure | November 6, 2027 |
| Contracted nights | November 4 and November 5 |
| Currency displayed | USD, inherited from the Departure operating currency |

The Arrangement may contain more than one Hotel Item. Every workspace and mutation must identify this stay by its stable Arrangement Item ID rather than a label, creation order, `.first`, or `.last`.

Neither an original contract date nor a Hotel group identifier may be inferred from the deposit dates, stay dates, or later clarification. The actual date and source of any later Supplier confirmation are recorded separately.

## 3. Contracted room inventory

### 3.1 Nightly block

| Stay night | Standard rooms | Deluxe rooms | Total rooms |
| --- | ---: | ---: | ---: |
| November 4, 2027 | 5 | 2 | 7 |
| November 5, 2027 | 10 | 5 | 15 |
| **Contract total** | **15 room nights** | **7 room nights** | **22 room nights** |

The quantities vary by night. They must not be flattened into one constant opening quantity across the stay.

Each room category is a stable Hotel Resource. The nightly contracted quantities are Supplier-controlled room-unit capacity for the covered occurrence dates. They do not represent travelers, Hotel-wide physical inventory, expected pickup, or rooms already sold.

**Topology decision for Slice 3A:** identify each inventory night by an authoritative date and each category/night block by an exact Pool. Present one continuous guest stay, not a new guest check-in on November 5. A free-text Pool label must not be the only source of the date. The plan must specify how M3 Occurrences, Pools, and the actual November 4 check-in/November 6 checkout terms coexist before implementation.

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

The fixture states a Destination Fee of $150 per room night plus tax and says that the fee and related tax are fully waived for **qualifying reservations**. Confirm the **$150 amount and per-room-night unit against the Hotel agreement** before approving this fixture; no source document was available in this review. Which reservations qualify has not been specified: do not assume every Group reservation receives the waiver or promise it in a Client-facing offer. Keep the concession conditional and do not calculate a fee offset, credit, or assumed discount until eligibility is sourced. For an eligible reservation, the fee and related tax are $0 payable under the stated waiver.

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

These dates are not part of the contracted 22-room-night block and are not guaranteed. Failure to obtain a pre-stay room does not release the Group from its contracted block obligation. Additional nights become durable Supplier facts only when actually confirmed; the Hotel adapter must not silently add them to the original occurrence or capacity Pools.

## 8. Reservation cutoff and room assignments

| Requirement | Canonical value |
| --- | --- |
| Cutoff | October 3, 2027 at 5:00 p.m. |
| Time zone | America/New_York |
| Assignment method | Approved rooming list or individual reservation channel |
| Action | Submit reservation/room-assignment information by cutoff |

After the cutoff, unassigned or unreserved rooms may be released from the Group block and sold to other parties. Requests received later are subject to availability.

The fixture does not establish whether a released room reduces the Group's per-night attrition minimum or any deposit liability. Do not infer that a release eliminates the guarantee. Hotel confirmation or the governing agreement must specify that effect before any automatic recalculation.

**Source check before acceptance:** October 3, 2027 is a Sunday. Verify the date and 5:00 p.m. local cutoff against the actual agreement; retain the stated date until source evidence changes it.

This is one actionable Supplier Deadline. Recording that the rooming list was delivered is an operational disposition of that deadline, not a second duplicate requirement.

## 9. Group deposits and reconciliation

### 9.1 Scheduled deposits

| Requirement | Due date | Amount | Percentage of original pretax block |
| --- | --- | ---: | ---: |
| Initial deposit | October 1, 2026 | $415.60 | 10% |
| Second deposit | May 7, 2027 | $1,870.20 | 45% |
| Third/final scheduled block deposit | October 4, 2027 | $1,870.20 | 45% |
| **Scheduled total** |  | **$4,156.00** | **100%** |

October 4 is the due date of the **final scheduled deposit for the original block**. It precedes the November 4–6 stay, so it cannot be the final reconciliation of actual occupancy, attrition, early departures, or unpaid guest folios. The Hotel may request a pre-stay review of then-known additional rooms, additional nights, and permitted estimated Group charges on October 4; the source and amount of any such adjustment require separate authority. That review must not create a duplicate charge for the original $4,156 block. The actual post-stay settlement date is not specified.

Each deposit is a separate Supplier Deposit Requirement definition with its own identity, due date, amount, and relationship to the **original** contracted-room-revenue target. The write-free summary shows the 10%/45%/45% derivation. Later pickup, room-rate changes, tax changes, or additions do not silently rebase these original scheduled amounts; an amendment or separately evidenced adjustment must name its basis. These are requirements, not recorded payments.

### 9.2 Guest and master-account billing

- Individual guests pay their occupied room charges and applicable tax on their folios. Actual tax rates may differ from the quoted 16.5%.
- Group deposits secure the contracted block. Under the operating understanding, they may be applied to permitted Group master-account liabilities, including attrition, unpaid covered charges, confirmed added rooms or nights, and other reconciled Group amounts. The governing agreement must confirm these applications.
- Whether any unused deposit balance is returned remains **unresolved**. The supplied nonrefundable clause conflicts with the operating understanding that unused funds are returned after settlement.

The fixture does not establish who remits each Group deposit, who owns a possible return, or the post-stay settlement date. Record the Supplier requirement without assigning an unsupported payer or refund recipient. Deposits must not be added to guest-paid room expense as a second cost. Tax on an actual Group attrition liability, if applicable, is distinct from guest-paid tax on occupied-room folios. The master-account applications above are the **operating understanding, not an established contract fact** pending written Hotel clarification.

### 9.3 Blocking contract conflict

The supplied clause calls the deposits “non-refundable,” while the operating understanding expects unused funds to be returned after post-stay settlement. Both statements must remain visible and neither is accepted as the governing outcome. Written Hotel clarification or an amended agreement is required before activation. If the Hotel confirms nonrefundability, revise this fixture and the policy record accordingly; do not silently retain the refund expectation.

The MVP must not silently choose one interpretation. Until resolved, readiness reports:

> Obtain written Hotel clarification of whether unused Group deposits are refundable after post-stay settlement, who receives any return, and how deposits apply to master-account liabilities.

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

The contract does not define the average-rate fallback when zero rooms are utilized. That case remains Advanced and requires Hotel clarification.

The stated nightly minimums equal the full contracted block on each night: 7 of 7 and 15 of 15. This is a zero-attrition allowance under the stated formula, subject to the unresolved effect of any Hotel-authorized release. Do not borrow an 80% or other allowance from a different agreement. Actual attrition tax, if any, belongs to the Group liability rather than an occupied guest's folio.

**MVP representation:** retain this as structured policy attached to the Hotel Item. Do not materialize an attrition Obligation or charge before later Reservation facts establish actual utilized rooms, booking channels, rates, and taxes.

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
- the unresolved deposit-refund conflict as a blocker.

The unresolved refund branch stops **before activation**. Staff may save the other facts. To enable activation, Staff must record the dated written Hotel clarification and its source against the current editable draft, preserve the contradictory original statement as history, and revise only the facts the Hotel actually confirmed. The document may be attached if an approved upload capability exists; upload itself is not a prerequisite. A pre-activation draft has no governing predecessor and needs no successor to correct this conflict.

The successful-activation proof is a separate **test branch with an explicitly marked hypothetical written Hotel clarification**. It must not portray that test evidence as an actual fact about the Smith agreement. If the real clarification differs from the assumed test branch, amend this fixture before using it as accepted authority. After a version is activated, later changes use a successor and keep the governing facts read-only.

Governing facts are read-only. Later changes occur through a successor draft, with stable child identities preserved where shipped version-copy authority requires them. Unsupported definitions remain readable and link to an exact Advanced destination without rewriting supported siblings.

## 14. Canonical Hotel workspace summary

```text
HOTEL SUPPLIER PLANNING

Pre-cruise hotel stay
Hilton Fort Lauderdale Marina
November 4–6, 2027 · 2 nights · Draft · USD

Needs attention
Obtain written Hotel clarification of the conflicting deposit-refund terms.
Post-stay settlement date and Group deposit payer/return recipient not specified.

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
Oct 4 is a scheduled deposit and possible pre-stay adjustment review,
not reconciliation of actual November stay charges.

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
8. Record the fully waived Destination Fee concession without creating a negative cost.
9. Record November 1–3 as availability-only additional-night terms rather than guaranteed inventory.
10. Create the three independent deposit definitions and see the 10%/45%/45% derivation.
11. Record the October 3 cutoff once and complete or reschedule it through shipped deadline authority.
12. See the per-date attrition policy without a materialized charge.
13. See the deposit-refund conflict block activation.
14. Record a dated, source-linked written Hotel clarification on the current draft, preserving the initial conflicting statements; use an explicitly hypothetical clarification only in a separate activation test branch.
15. Rename a room or rate component without changing its stable identity.
16. Submit an invalid sibling edit and confirm earlier work remains unchanged.
17. View governing terms read-only and successor terms as proposed.
18. Confirm a Viewer may read the Hotel summary through a view-authorized route but cannot save, change, or activate Hotel terms. Hotel management routes return not found to a Viewer. Cross-Agency identifiers return not found on both read and management routes.

At least one browser proof must use two Hotel Items, with navigation by stable Item ID. The extra Item is test structure only: it is not another contracted component of this Hilton stay and must not change the 22-room-night block or its $4,156 base. Database-only graph construction does not satisfy this exit.

## 16. Fixture assertions and behavior boundaries

The numbers and dated terms below are **provisional scenario assertions**, not source-verified factual authority. Preserve them in Draft proof, with the source checks in §17 visible. Do not mark this fixture Approved, or authorize implementation that depends on them, until the source checks relevant to that implementation are complete. Behavior boundaries such as no invented Client choices, separate dated inventory, and no pre-Reservation attrition charge can be decided through the Staff walkthrough independently of factual approval.

1. The contracted stay is November 4–6, 2027.
2. Nightly inventory varies: 5 Standard/2 Deluxe, then 10 Standard/5 Deluxe.
3. The agreement contains 22 contracted room nights.
4. Both categories support occupancy tiers through Quad.
5. Standard is $173/$173/$193/$213; Deluxe is $223/$223/$243/$263.
6. Occupancy and sales tax are additive at 16.5% for the quoted agreement evidence.
7. Rates are net noncommissionable.
8. The stated Destination Fee and related tax are waived **for qualifying reservations**. The $150 amount/unit and qualification rule still require source verification. Do not assume a universal waiver.
9. November 1–3 are availability-only additional nights, not guaranteed block inventory.
10. The room-assignment cutoff is October 3, 2027 at 5:00 p.m. America/New_York.
11. Guests pay their occupied room and tax folios.
12. Scheduled deposits total the original $4,156 pretax block. Their intended master-account application is an operating understanding awaiting written confirmation; the payer, recipient of any unused balance, and actual payment state are unspecified.
13. October 4 is the final scheduled deposit date for the original block. Any then-known additional rooms, nights, or permitted pre-stay adjustments need separate source authority. Actual post-stay reconciliation has no sourced date and cannot occur October 4.
14. The operative understanding expects a return of unused funds, while a supplied clause says deposits are nonrefundable. Neither interpretation becomes governing until the Hotel clarifies it in writing; activation is blocked meanwhile.
15. Attrition is evaluated independently per stay date and remains structured policy until actual utilization exists.
16. There is no separate supplied cancellation ladder.
17. Early-departure charges and attrition credits wait for Reservation facts.
18. This scenario ends at Supplier Composition; it creates no Service Offer, Client choices, pricing, or Package placement.

## 17. Source checks before fixture acceptance

The original Hotel agreement was not available for this revision. Check the following against it or obtain direct Hotel confirmation before approving factual authority:

1. Whether the stated $150 Destination Fee is per room per night, and that its associated tax is waived.
2. Whether the Sunday October 3, 2027, 5:00 p.m. Eastern cutoff and October 4 deposit date are transcribed correctly.
3. What, if anything, October 4 requires beyond the $1,870.20 original-block scheduled deposit; the date and basis of post-stay settlement.
4. Who remits Group deposits, their permitted application, who would receive an unused balance, and the governing refundability clause.
5. Whether Hotel release after cutoff changes the nightly attrition minimum or any Group obligation.
6. Which reservations qualify for the Destination Fee waiver and its included amenities.

The calculations `5 × $173 + 2 × $223 = $1,311`, `10 × $173 + 5 × $223 = $2,845`, `$1,311 + $2,845 = $4,156`, `10% + 45% + 45% = 100%`, and `$4,156 × 16.5% = $685.74` are internally consistent. Their contractual premises still need the source checks above. Do not substitute superseded illustrative Hotel figures while resolving them.
