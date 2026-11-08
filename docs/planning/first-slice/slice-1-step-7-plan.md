# Slice 1 step 7: Supplier reservations that can stand alone

**Status:** Accepted 2026-11-08, after the [staff walkthrough after step 6](slice-1-step-6-staff-walkthrough.md) passed. Not implementation authority beyond the [first-slice charter](first-slice-charter.md) build step 7 and the decision log entries it cites.

Charter build step 7 builds supplier reservations, and closes the Slice 1 half of **D8**:

> BK-104 is confirmed with Nov 2–3 on request. Those nights show Awaiting supplier; in Slice 1 the hotel accepts and its reference is recorded. In 1b a decline is flagged, acceptance is kept and nothing cancels.

It covers INV-33 to INV-37 and SUP-10. Screen S-19 is the supplier reservations page, and the booking workspace shows each service's supplier status.

Today, step 6 selects BK-104's Nov 2 and Nov 3 Harbor Double nights but takes no allocation for them, because their groups are on request (step 6 plan, question 8). Nothing yet records that the hotel was asked, or that it said yes.

## Questions settled for this plan (2026-11-08)

None of the recommendations below moves work between build steps, departs from a cited rule, or settles a fixture value, so none needs a decision log entry. Question 7 says why the supplier's reference in the D8 test is not a fixture value. Each recommendation was accepted.

| # | Question | Recommendation |
| --- | --- | --- |
| 1 | **What "can stand alone" means.** The data model lists a supplier reservation with "arrangement optional, booking optional". A reservation with no arrangement is SUP-07's standalone service off a Departure: it carries its own terms and cost, and its booking has no Departure (BKG-20). The charter cites neither SUP-07 nor BKG-20 for step 7. | **A supplier reservation is its own record (INV-33), standing apart from the allocation and the client booking.**<br>• It has its own status, never derived from either of them, and neither is derived from it (INV-21, INV-34).<br>• A booking confirms whatever its reservations' states. While a reservation is Requested, the service shows Awaiting supplier (INV-37).<br>• A reservation can cover space that has no allocation, such as on-request nights.<br>**In Slice 1 every reservation has an arrangement and a client booking.**<br>• A reservation with no arrangement needs SUP-07's own terms and cost and a booking with no Departure. Both are outside the charter.<br>• The columns are created NOT NULL, and the data model row is amended to match.<br>• Relaxing them later is a forward migration. |
| 2 | **What a request covers, by the arrangement's scope (SUP-10).** INV-33 starts a request "at the scope the arrangement defines". INV-34 adds that "a confirmed group block may need no separate request for each allocation". | **A request names the booking's units it covers.** A unit is a per-unit selection, such as the Nov 2 Harbor Double room, or a per-traveler selection's participants.<br>• **Arrangement scope:** one request may cover several units of one booking from that arrangement, for example Nov 2 and Nov 3 together. All three Alpha arrangements use this scope.<br>• **Per unit:** each request covers exactly one unit.<br>• **None:** no request can be started. The refusal says the arrangement doesn't track supplier reservations.<br>A unit is covered by at most one Requested or Confirmed reservation at a time. A unique index enforces it. |
| 3 | **Which services need a request.** INV-37 names on-request and directly booked services. A firm block allocation under arrangement scope is covered by the arrangement's own confirmation and group reference (SUP-06). | **A unit needs a supplier request when its group is any of these:**<br>• on request;<br>• rate only;<br>• no shared inventory (direct booking with the supplier);<br>• under a per-unit arrangement.<br>Units in a firm, releasable or courtesy block under arrangement scope show "In the group block" and need none.<br>On a confirmed booking, a unit that needs a request and has none shows "Request from the supplier", with the action. That is guidance, not a status: the statuses stay the four in INV-34 and Awaiting supplier (INV-37). Staff may start a request before the booking is confirmed. A hold never implies the supplier is holding space (INV-37). |
| 4 | **Which transitions Slice 1 builds.** The lifecycle has four: start (Requested), accept (Confirmed), decline (Declined) and cancel (Cancelled). D8's decline half is Slice 1b. Cancelling a confirmed reservation has supplier money effects, which belong to the Supplier money area. | **Slice 1 builds start and accept.**<br>• The status column's check allows all four values from the start.<br>• Decline (INV-36: keep the client's acceptance, flag the service for staff, and treat it as unfulfilled) and cancel arrive in 1b with D8's decline half.<br>• Without decline, a Requested reservation can't be withdrawn in Slice 1, because the lifecycle has no withdrawal. Staff record the supplier's answer when it comes. |
| 5 | **What is recorded.** INV-26 lists supplier request and acceptance among the dated inventory events. INV-35 puts the supplier's response and reference on the reservation. REF-09 keeps supplier references beside the agency's. | **New `supplier_reservations`:**<br>• agency, arrangement, client booking and status;<br>• the supplier's reference, kept apart from the arrangement's group reference and the booking's own reference (REF-09, SUP-06);<br>• the date the supplier responded, and a note;<br>• who requested it and who recorded the response, with when;<br>• a lock version.<br>**`supplier_reservation_units`** link it to the choice selections it covers.<br>**`supplier_reservation_events`** are append-only: Requested and Confirmed, each dated, with who recorded it. The status column changes only through the commands, in the same transaction as the event.<br>`SupplierReservation` joins the closed audit subject catalog, with `supplier_reservation.requested` and `supplier_reservation.confirmed`. Every table carries a same-agency composite foreign key. |
| 6 | **What acceptance changes, and what it doesn't.** INV-35 says supplier acceptance never changes the client's accepted price. | **Accepting changes the reservation and nothing else.** It touches no price line, charge line, acceptance or allocation. On-request space still takes no allocation, as in step 6; capacity accounting for on-request space stays out of scope. Tests assert the booking's price lines, client charge and allocations are unchanged by accepting. |
| 7 | **Who does it, and the fixture.** The permission catalog lists supplier reservations under Supplier arrangements. | **Permissions:**<br>• Starting a request and recording the supplier's answer need Supplier arrangements, through a new `manage_supplier_reservations` action.<br>• Seeing reservations and each service's supplier status is baseline, through `view_supplier_reservations` (ACC-30).<br>**The fixture is unchanged.**<br>• The development seed doesn't start BK-104's request, so the walkthrough of step 7 can do it.<br>• The D8 test records its own placeholder hotel reference, `SHH-24117`. It is a test input, like the evidence notes in earlier tests, not a fixture value.<br>Log a fixture entry instead if you want the seed to carry the request. |

## Screens

- **S-19, supplier reservations.** A panel on the arrangement page (S-12) lists its reservations: booking, units, status, the supplier's reference and the dates. Recording the supplier's acceptance opens a short form: response date (defaulting to today), the supplier's reference, and a note.
- **Booking workspace (S-26).**
  - Step 2, rooms and options, shows each unit's supplier status beside its allocation state. These are separate labels, as the screen inventory requires.
  - Step 4 lists units awaiting the supplier.
  - "Request from the supplier" picks the booking's units from one arrangement that need a request. Each unit is ticked by default, and the request covers them together under arrangement scope.
- **Roster (S-25).** A Supplier column shows "Awaiting supplier" with a count when any unit on a confirmed booking is Requested.

Each screen meets the UI acceptance standards at desktop width and 375px.

## Not in this step

- Decline and cancel (Slice 1b, with D8's decline half), and INV-36's flag.
- Reservations with no arrangement or no booking (SUP-07, BKG-20).
- Unit assignments from the supplier, such as a room number on a shell (INV-06).
- Searching by a supplier's reference (SC-REF-05).
- Option or courtesy deadlines on a reservation (BKG-12, SUP-22).
- Needs attention, notifications and tasks for requests awaiting an answer.

## Tests

- **D8, Slice 1 half,** against the Alpha fixture with BK-104 confirmed:
  1. Nov 2 and Nov 3 show "Request from the supplier", and Nov 4 and Nov 5 show "In the group block".
  2. Staff start one request covering both nights. The booking shows Awaiting supplier for each, and the roster shows it.
  3. Staff record the hotel's acceptance with reference `SHH-24117`. Both nights show Confirmed by the supplier, with the reference.
  4. The booking's price lines, client charge and allocations are unchanged throughout.

  The 1b half is a pending test named for D8.
- **Commands:**
  - A scope of none refuses a request.
  - Per-unit scope refuses a request covering two units.
  - A unit already covered can't be requested again.
  - A firm-block unit under arrangement scope can't be requested.
  - Accepting a request that isn't Requested is refused.
  - Each event is append-only, in the application and in PostgreSQL.
- **Authorization:** baseline staff see statuses but can't start or record. Another agency's reservation is not found.
- **UI:** the screens reflow at 375px without page overflow.

## Build order

One PR, citing INV-33 to INV-37, SUP-10, REF-09 and D8:

1. Tables, models and the two commands.
2. S-19 on the arrangement page, and the booking workspace and roster statuses.
3. D8, the docs (AGENTS.md, CLAUDE.md, current state, the data model row and the planning index) and the walkthrough additions for step 7.
