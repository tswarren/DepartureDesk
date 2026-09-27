# DepartureDesk — Hilton hotel Staff walkthrough

**Status:** Draft for review, 2026-09-27. This is a proposed Staff journey, not implementation authority or an accepted Hotel adapter contract. Accepting the journey would not Approve the Hotel fixture's unverified facts.

**Source:** [the single registered Hilton fixture](../fixtures/hilton-fort-lauderdale-marina-2027-canonical-scenario-draft.md), itself Draft, as indexed by the [fixture register](../fixtures/README.md). [M4D.1 Slice 3R](../m4d1-slice3r-non-cruise-adapter-boundary.md) authorizes preparing a Hotel walkthrough, then a separate Slice 3A plan. Do not approve a second Hilton fixture under `docs/planning/drafts/`. This walkthrough does not authorize Hotel code or adopt the discarded illustrative November 2–5 stay.

## 1. Starting point and intended result

Staff are preparing the **Smith Family Reunion** departure. They have an agreement with **Hilton Fort Lauderdale Marina** for a pre-cruise stay arriving **November 4, 2027** and departing **November 6, 2027**. The contracted nights are November 4 and 5. The property's check-in is 3:00 p.m. and checkout is noon; its time zone is America/New_York. USD is shown from the Departure's operating currency.

At the stopping point, Staff have a reviewed Supplier Arrangement containing the actual two-night room block, room-category rates, three Group deposit requirements, the room-assignment cutoff, and the readable concessions and policies. The unresolved refund clause prevents activation until the Hotel confirms the governing treatment in writing. No Client Service, room choice, Package placement, Client booking, individual folio, Supplier payment, or attrition charge is created by this journey.

The contract/signature date and Hotel group or confirmation number are **not supplied**. The form must leave them blank rather than propose a date or fabricate an identifier. If generic activation requires a Supplier confirmation, it records the actual later confirmation evidence and the allowed no-identifier reason; it does not relabel that evidence date as the missing original contract date.

## 2. Save the Hotel agreement and stay

From **Smith Family Reunion → Composition → Suppliers**, Staff open or create the exact Hilton Supplier Arrangement, then choose **Add Hotel stay**. They enter the property and the Hotel Item name **Pre-cruise hotel stay**, the contracted November 4–6 stay, the one authoritative time zone, and the applicable check-in/checkout terms.

**Save stay** gives Staff a durable draft and returns them to its workspace. It creates no room category, capacity, rate, deposit, Client Service, or Package inclusion. An invalid stay save preserves the entered values and does not create a partial Item or Occurrence. Staff can leave and resume here.

The workspace identifies the stay by its stable **Arrangement Item ID**. It displays the Hotel Arrangement separately from the stay Item: the Arrangement may eventually contain another Hotel Item, and name, creation order, `.first`, and `.last` are not selectors. A separate proof case will add a second Item and reopen this one by ID; that test Item is not part of the Hilton block or its $4,156 target.

### Nightly representation to settle before implementation

The screen presents **one continuous guest stay** and **two contracted inventory nights**. The nightly room quantities must have durable dates, Resource identities, and distinct Pool identities. A plausible M3 mapping is one Hotel Item with date-specific inventory Occurrences and one Pool per room category per night. Those Occurrences are inventory segments, **not two separate guest check-ins**. The walkthrough does not yet choose whether a separate stay Occurrence or another exact date-owned definition carries the guest stay and property times. The Slice 3A contract must demonstrate the persisted graph and the summary it produces without relying on free-text Pool labels to establish dates or inventing a nightly noon/3 p.m. turnover for a continuing guest.

## 3. Add Standard and Deluxe room inventory

Staff add **Standard** and **Deluxe** as stable room Resources. Both support up to four guests per room. For each contracted night, Staff enter the Hotel-controlled block:

| Night | Standard rooms | Deluxe rooms | Room nights |
| --- | ---: | ---: | ---: |
| November 4, 2027 | 5 | 2 | 7 |
| November 5, 2027 | 10 | 5 | 15 |
| **Total** | **15** | **7** | **22** |

Saving a night or category leaves saved siblings intact. Staff can reopen and correct one date and one category by stable IDs. The workspace does not flatten the inventory into 15 rooms on each night, imply that a blocked room has been sold, or count 22 room nights as 22 distinct physical rooms.

For November 1–3, Staff record the Hotel's offer to **consider additional nights at contracted rates and concessions, subject to availability**. These are readable contingent terms. There is no opening Pool, guaranteed room, or extension of the contracted November 4–6 stay for those dates. Actual additional inventory becomes a new, evidenced Supplier fact only if the Hotel confirms it. A room released after the October 3 cutoff is not assumed to reduce the night's contracted minimum or Group liability; the agreement or Hotel must specify that effect.

## 4. Enter room rates and review Supplier economics

Staff enter a per-room, per-night base rate covering one or two guests, plus one incremental charge for the third guest and another for the fourth. The Hotel supplies no adult/child distinction.

| Category | Single | Double | Triple | Quad |
| --- | ---: | ---: | ---: | ---: |
| Standard | $173 | $173 | $193 | $213 |
| Deluxe | $223 | $223 | $243 | $263 |

The rate review shows the underlying base and $20 position-three and $20 position-four increments, not four unrelated complete prices. The rates are **net and noncommissionable**; there is no expected Hotel commission.

For the opening block at the one/two-guest base rate, the write-free review shows **November 4: $1,311** (`5 × $173 + 2 × $223`) and **November 5: $2,845** (`10 × $173 + 5 × $223`), totaling **$4,156 pretax**. Triple/Quad supplements depend on actual occupancy and do not inflate this opening target.

The quoted occupancy tax is 9.5% and state sales tax 7%, additive **16.5%** on taxable room charges. At the original base target, **$685.74** is an illustrative tax exposure. Guests pay occupied room charges and applicable taxes on their own folios. The $685.74 is neither part of the original pretax Group deposit target nor a second Group charge. Later folio taxes use the rate actually applicable under billing authority.

Staff can save and reopen each rate section without changing the other room category or nightly inventory. If an economic shape cannot be expressed by the typed editor, it stays readable with a precise Advanced destination; the adapter must not silently replace it with a fixed guess.

## 5. Record concessions and booking-dependent policies

The **Supplier terms** section records:

- **Destination Fee:** a stated $150 per room night plus tax is waived **for qualifying reservations**, with the included amenities. The amount/unit and definition of a qualifying reservation still need source verification. Staff see a conditional Supplier concession, not a universal waiver, negative Supplier cost, Client discount, or cash credit.
- **Additional nights:** November 1–3 may be requested at contracted rates and concessions, subject to Hotel availability. They are not block inventory.
- **Attrition:** the November 4 minimum is 7 utilized room nights and the November 5 minimum is 15. A shortfall on one night cannot be offset by overachievement on the other. Only bookings through approved channels at contracted rates count. The eventual charge is 100% of lost room revenue for that night, based on the average rate of rooms actually utilized that night, plus applicable tax.
- **Early departure:** without notice at or before check-in, an early departure incurs one room night plus tax on the guest's folio; a collected fee reduces any otherwise owed sleeping-room attrition.
- **Group cancellation:** no separate cancellation schedule was supplied. Do not infer one from attrition.

The policy is displayed in date-specific, readable form. Until later Reservation facts establish actual utilization, channels, rates, departures, and collected fees, the system creates **no attrition Obligation, early-departure Supplier cost, or credit**. The contract gives no average-rate fallback for a date with zero utilized rooms; Staff must seek Hotel clarification if that case becomes material.

The fixture calls for structured attrition policy attached to the Hotel Item. The smallest plausible shape records each contracted night's minimum and the shortfall consequence, while keeping approved-channel qualifications, actual average-rate valuation, and the zero-utilization exception in readable terms. Slice 3A must name its precise persisted fields. The Staff journey requires accurate display and deferred calculation, not an MVP attrition calculator.

## 6. Record Group deposits and the reservation cutoff

Staff record three separately identifiable Supplier Deposit Requirements against the **original $4,156 pretax contracted-room-revenue target**:

| Requirement | Due | Original-target share | Scheduled amount |
| --- | --- | ---: | ---: |
| Initial | October 1, 2026 | 10% | $415.60 |
| Second | May 7, 2027 | 45% | $1,870.20 |
| Third/final scheduled block deposit | October 4, 2027 | 45% | $1,870.20 |
| **Scheduled total** | | **100%** | **$4,156.00** |

The review shows the original date-by-category base and percentage derivation without writes. A later room, rate, actual pickup, or tax change does **not silently rebase** these scheduled amounts. October 4 is the final **scheduled deposit** for the original block. A then-known added room, added night, or estimated Group charge may be reviewed separately only if the Hotel's terms support it. October 4 precedes the stay and therefore cannot reconcile actual attrition, early departures, or unpaid guest folios; the post-stay settlement date is unspecified. The October 4 requirement does not produce a second $4,156 charge. Slice 3A must specify whether the accepted M3 deposit primitives can preserve the original basis directly, or whether to store these agreed fixed amounts with an explicit derivation record. Do not claim live recalculation is the Hotel's contractual schedule without source authority.

Guests paying their individual folios and the Supplier requiring Group security deposits are distinct flows. The fixture does not identify who actually remits those deposits or who would receive an unused balance. A deposit requirement is not proof of payment or an additional room expense. Under the operating understanding, deposits may cover attrition, unpaid covered charges, confirmed added rooms/nights, and other reconciled Group amounts; the Hotel must clarify their governing application. Any return of unused funds is disputed in the supplied text and **must remain unresolved until written Hotel clarification**. Tax on a possible Group attrition liability is distinct from guest-paid tax on occupied-room folios.

Staff also save **one actionable room-assignment cutoff: October 3, 2027 at 5:00 p.m. America/New_York**. It asks for an approved rooming list or individual-reservation information. Staff may later mark the action completed, reschedule it under existing authority, or record a waiver as appropriate. The passing of the date does not automatically release unused rooms; after cutoff, unassigned inventory **may** be released by the Hotel. The deadline is not duplicated as a second rooming-list occurrence.

## 7. Review the written-deposit conflict and activate

The review assembles the stay, both dated inventory rows, four occupancy tiers per room category, $4,156 pretax opening target, illustrative guest-paid tax exposure, waived fee, availability-only nights, three deposits, single cutoff, and readable policies. It calls out the deposit contradiction prominently:

> The supplied clause describes Group deposits as nonrefundable, while the operating understanding expects unused funds to be returned after post-stay settlement. Obtain written Hotel confirmation of the governing treatment before activation.

Staff can save all other valid sections while that finding is open. **Preview is write-free**, and activation stays blocked. Staff record the actual written clarification, its date, Hotel source, and exact reference in the **current draft**, preserve the conflicting original wording as history, and revise the saved policy only to the extent confirmed. Uploading a document is optional if a separate document capability later exists; the requirement is for written Hotel authority, not a mandatory upload feature. If the Hotel confirms nonrefundability, the draft and fixture must be corrected rather than silently carrying forward the expectation of a refund. A successful-activation browser proof may use a clearly marked hypothetical clarification, never presented as an actual Smith agreement fact.

Only after this and the ordinary activation checks pass does Staff activate the exact Supplier version. Activated definitions become read-only; capacity openings and scheduled operational requirements are established by the existing engines. Activation does not post a Supplier payment, a guest folio, an attrition charge, a refund, or a Client Trip.

**Correction to the fixture's proposed proof wording:** a pre-activation conflict is resolved through documented clarification and an edit to the current draft. A successor is for changes after a governing activated version exists. Staff cannot cure an activation blocker by creating a successor to a version that never governed.

## 8. Later changes and stopping point

If the Hotel later confirms an additional night or changes a contracted category, capacity, rate, cutoff, or deposit term, Staff prepare the appropriate evidenced change under the governing agreement or a successor draft as required by the exact terms. The activated version stays visible and immutable while the proposal is under review. Newly confirmed extra nights do not silently become part of the original 22-room-night block or rebase its deposits.

The Supplier journey stops at the reviewed or activated Supplier Arrangement. It does not create a Service Offer, Client room choices, prices, Package inclusion, or selections. **This walkthrough settles Slice 3R's handoff question for Hotel Slice 3A:** the Hotel workspace offers a return to Departure Composition and **no Client Service connection action**. Slice 3A must not add a quiet “connected, pricing unconfigured” state. A later, separately accepted Offer Design contract may revisit a handoff; no handoff is implied by saving a Supplier Item.

## 9. Proof and decisions before Slice 3A

The later browser proof should follow the Staff path from Composition and establish all of the following:

1. Save the stay, Standard, Deluxe, each nightly block, and each rate section independently; reopen by stable IDs and preserve submitted values on invalid saves.
2. Show exactly **5/2 then 10/5**, 22 room nights, $1,311 + $2,845 = $4,156, and supported Single/Double/Triple/Quad prices with no commission.
3. Keep guest-paid tax separate from the pretax Group deposit basis; show 10%/45%/45% without creating a second October 4 charge.
4. Show waived fee, contingent November 1–3 nights, per-date attrition, no inferred cancellation ladder, and no materialized attrition or early-departure charge.
5. Save the October 3, 5:00 p.m. Eastern cutoff once. Show the unresolved refund conflict blocking activation; separately prove activation with a dated written Hotel clarification on the same pre-activation draft, marked as hypothetical test evidence until an actual clarification exists.
6. Show governing read-only and successor proposed states after activation. Test a second Hotel Item and reopening the first by stable Item ID without adding its facts to the Hilton block. A Viewer may read the Hotel summary on a view-authorized route but cannot save, amend, or activate; Hotel management routes return not found to a Viewer. Cross-Agency read and management identifiers return not found. Preserve an exact Advanced fallback for unsupported shapes.

Before accepting a Slice 3A implementation plan, settle these decisions explicitly:

| Decision | Required outcome |
| --- | --- |
| Nightly graph | Name the exact dated Occurrence/Pool structure, the single displayed guest stay, and where true property check-in/checkout terms live. Avoid date-bearing labels as sole authority. |
| Rate and deposit base | Pin the per-night category quantities and base rates used for the original $4,156 target; define how the three agreed requirements keep that original basis through later changes. |
| Policy shape | Specify the limited typed nightly attrition minimums and responsibility terms required by the fixture, alongside versioned readable qualifications, fee waiver, extra-night conditions, and refund clarification. Do not promise calculation from information MVP does not hold. |
| Clarification evidence | Specify how Staff reference written Hotel confirmation while file upload remains optional; retain the original contradictory clause and the correction history. |
| Hotel Item boundary | Specify Staff navigation by stable Item ID and how a second Item is proved without contaminating this agreement's totals. |

The original Hotel agreement was not available in this review. The **Staff journey may be accepted without approving the factual Hilton fixture**. Before approving the fixture as agreement authority, verify the stated $150 per-room-night Destination Fee and qualifying-reservation rule, the Sunday October 3 cutoff and October 4 deposit date, any pre-stay adjustment terms, the post-stay settlement date, deposit payer/recipient and refundability, and how release affects nightly minimums. Until then, the numeric proof is a labeled provisional scenario.

Acceptance of this walkthrough, when it happens, would authorize drafting a separate Hotel Slice 3A plan. It would not itself authorize Hotel adapter implementation or settle Cruise confirmation, Cruise deposits, or Client pricing.
