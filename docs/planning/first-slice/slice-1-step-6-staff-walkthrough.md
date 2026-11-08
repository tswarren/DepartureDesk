# Slice 1 staff walkthrough after step 6

**Status:** Done 2026-11-08. Every part passed; the findings below were each fixed and merged before build step 7. Part of the [first-slice charter](first-slice-charter.md): its build plan calls for a staff-only walkthrough of setup through confirmed bookings after build step 6, before money, reseller access and documents are built. Slice 1 can't exit until this walkthrough is done and its findings are resolved or logged.

**Covers:** charter workflow steps 1 to 8 and 10, for staff. The reseller's path (step 9), supplier reservations (step 11), money (steps 12 and 13) and documents (step 15) are not built yet and are out of this walkthrough.

**Fixture:** the Alpha fixture as loaded by the development seed, with the roster's values from D-87, D-93, D-94 and D-95.

## How to run it

1. **Reset the development data.** This deletes every development record and reloads the seed. The setup is loaded, and no clients or bookings exist:

   ```bash
   ALPHA_FIXTURE_BOOKINGS=none ./dev/rails-docker bin/rails db:seed:replant
   ```

2. **Keep the `jobs` service running** (`docker compose up`). The hourly supplier money sweep posts Agreement A's $1,600 initial deposit, which fell due Nov 1, 2026.
3. **Sign in** at workspace code `harbor` as the seed's Agency Admin, `email@example.com`. The password is in `db/seeds.rb`.
4. **Work through parts A to I in order.** Parts A to E review the loaded setup. In parts F to H, you create the three Slice 1 bookings yourself. Part I tries the edges.
5. **Repeat at 375px.** Check each screen at desktop width, then again at 375px, using the browser's responsive mode, against the [UI acceptance](first-slice-charter.md#ui-acceptance) list.
6. **Log every finding** in the table at the end, as you go.

The development clock is the real date. Holds, acceptances and confirmations are dated today, not the roster's January 2027 dates; amounts fall due today accordingly.

At the end of each part, answer the charter's four questions for what you just did:
- what the client accepted;
- what the supplier confirmed;
- how capacity is used;
- what money is open.

## A. Agency and staff

Workflow step 1: ACC-02, ACC-04, ACC-07, ACC-10, ACC-30, ACC-31; SET-01, SET-04, SET-09, SET-10; REF-01 to REF-03.

| Step | Do | Expect |
| --- | --- | --- |
| A1 | Administration › Agency profile | Display name, contact details, America/New_York, USD, hold duration 2 days, installment buffer 14 days |
| A2 | Traveler types on the same page | Adult (counts as an adult), Child, Child 0–4 |
| A3 | Administration › Users | The Agency Admin; user types and the five permissions as checkboxes |
| A4 | Administration › Client terms | The reusable terms wording and the default cancellation tiers |

## B. Departure

Workflow step 2: DEP-01, DEP-03 to DEP-07; FIN-22. Publishing to a reseller channel is build step 9 (D-90).

| Step | Do | Expect |
| --- | --- | --- |
| B1 | Departures | Alpha Omega, DEP-0001, On sale |
| B2 | Open it | Ready to sell, decision Proceed, completion Active; Nov 6, 2027 to Nov 13, 2027; USD; America/New_York |
| B3 | The Departure team | You as default task owner |
| B4 | The tabs | Overview, Bookings, Package, Client terms, Inventory, Suppliers, Supplier money, Tasks |

## C. Suppliers, arrangements, deadlines and supplier money

Workflow steps 3, 4 and 6: SUP-01, SUP-02, SUP-06, SUP-07, SUP-09, SUP-11, SUP-15 to SUP-18, SUP-22 to SUP-25, SUP-35; OPS-01 to OPS-05; SMN-01 to SMN-06, SMN-08, SMN-10, SMN-11, SMN-13, SMN-14, SMN-17.

| Step | Do | Expect |
| --- | --- | --- |
| C1 | Suppliers tab | Alpha Cruises, Sablewater Harbor Hotel and Shore Excursions Group, each Confirmed, with a payee account |
| C2 | Alpha Cruises arrangement | Group reference ALPHA-A; the rate table by category and occupancy position, commission 14% of base fare |
| C3 | Its deadlines | Initial deposit Nov 1, 2026; full deposit and names Mar 1, 2027; final payment Aug 1, 2027; each with a task |
| C4 | Shore Excursions Group | Final count Oct 22, 2027 at 11:59 p.m. agency time, with a task |
| C5 | My tasks | The deadline tasks, by due date, with overdue shown from the deadline |
| C6 | Supplier money tab | The $1,600 initial deposit due Nov 1, 2026 (after the sweep); the hotel's firm rooms ($1,280 and $465) and the first excursion resource ($1,000) as committed cost |

## D. Inventory

Workflow step 5: INV-01 to INV-05, INV-07, INV-09, INV-12, INV-16, INV-38, INV-39.

| Step | Do | Expect |
| --- | --- | --- |
| D1 | Inventory tab | V01, O01, I01 (3 positions) and S01 (4 positions), 8 cabins each, all Available |
| D2 | The hotel | Nov 5: 4 Garden Queen (2 positions) and 4 Harbor Double (4 positions); Nov 4: 2 and 1 places; Nov 1 to 3 on request |
| D3 | Private Miami tour | 1 resource of 10 positions; open the group: Child 0–4 uses no capacity |
| D4 | A hotel group | Child 0–4 uses no place (D-95) |

## E. Package and client terms

Workflow step 7: BKG-13 to BKG-16, BKG-21, BKG-28, BKG-31; CMN-09.

| Step | Do | Expect |
| --- | --- | --- |
| E1 | Package tab | Cabin (included, per unit, required); Nov 5 hotel room (included); Extension nights (add-on, choose any); Private Miami tour (add-on, per traveler) |
| E2 | Cabin prices | V01 $3,385 for the 1st and 2nd guests and $1,285 for each additional guest; a single fare |
| E3 | Client terms tab | Version 1, editable; tiers 10% from 120 days, 50% from 61, 100% from 0; deposit $500 per cruise unit at confirmation, not counting as acceptance; balance 120 days before departure |

## F. Clients and travelers

Workflow step 8: CLT-01, CLT-02, CLT-05, CLT-06, CLT-09, CLT-11, CLT-13, CLT-15. Dates of birth are the D-94 placeholders.

| Step | Do | Expect |
| --- | --- | --- |
| F1 | Clients › New client: Nadia Rowan, tick "This client is also traveling" | Her profile shows Nadia Rowan as a traveler, relationship Self |
| F2 | Edit Nadia's traveler: date of birth Dec 2, 1979 | Saved |
| F3 | Add traveler from her profile: Theo Rowan (Aug 15, 1978) and Iris Rowan (Jul 22, 2018), Family member | Both listed with their relationship |
| F4 | Repeat for Sofia Bennett (Sep 3, 1985), with Marcus (Jan 27, 1983), Ava (Feb 8, 2016) and Milo (Mar 14, 2025) | Four travelers |
| F5 | Repeat for Mateo Rivera (May 11, 1990), with Elena (Oct 30, 1991) and Luca (Jun 20, 2024) | Three travelers |
| F6 | Save a traveler with only a given name | Saved; it needs a surname and date of birth only to confirm |

## G. Trips, bookings and holds

Workflow steps 8 and 10: CLT-02, BKG-03, BKG-05, BKG-06, BKG-09 to BKG-11, BKG-14 to BKG-16, BKG-23, DEP-05, INV-07, INV-09, INV-17 to INV-23, INV-38, INV-39.

Start with the Bennetts, the fullest booking.

| Step | Do | Expect |
| --- | --- | --- |
| G1 | Sofia's profile › New trip, Departure Alpha Omega | A trip T-0000n, status Not booked |
| G2 | New booking | A Draft booking, referenced from the trip (T-0000n-1); the trip shows Quote |
| G3 | Add Sofia, Marcus (Adult), Ava (Child) and Milo (Child 0–4) | Four travelers in that order |
| G4 | Cabin: add S01 with all four | Positions 1st to 4th guest |
| G5 | Nov 5 hotel room: Harbor Double with all four | Milo takes part without a position |
| G6 | Extension nights: Nov 2, Nov 3 and Nov 4 Harbor Double, all four each | Three units |
| G7 | Private Miami tour, all four | Milo takes part without a position |
| G8 | Price summary | S01 $11,240; each room night $220 for Sofia and No charge for the others; the tour $150 for three and No charge for Milo; total $12,570 |
| G9 | Confirm booking | Refused; the list starts with recording acceptance, each item linked |
| G10 | Hold space | Held until 11:59 p.m. tomorrow; the Nov 2 and 3 nights take nothing, being on request |
| G11 | Inventory tab | S01 one Fully allocated; Nov 4 Harbor Double 1 held or reserved; the tour 4 participants, 3 positions used, Milo without a position |
| G12 | Nadia Rowan: trip, booking; Nadia, Theo (Adult), Iris (Child); V01 with all three | V01 $8,055 |
| G13 | Two Nov 5 Garden Queen rooms: Nadia and Iris; Theo | Two units of the room choice (D-95) |
| G14 | Nov 4 Garden Queen for each room, the tour for all three, then Hold space | Total $9,265; both Nov 4 Garden Queen places held |
| G15 | Mateo Rivera: trip, booking; Mateo, Elena (Adult), Luca (Child 0–4); O01, one Nov 5 Garden Queen with all three | O01 $7,105; Luca takes part in the room without a position |
| G16 | The tour for Mateo and Luca only, then Hold space | Elena shows "Not on this service"; total $7,445 |
| G17 | Bookings tab | Three Draft bookings, each Held until tomorrow; totals 10 travelers and $29,280 |

## H. Acceptance and confirmation

Workflow step 10: BKG-25, BKG-28, BKG-39, BKG-41, BKG-45, BKG-46; SMN-11, SMN-32; SUP-35.

| Step | Do | Expect |
| --- | --- | --- |
| H1 | Bennett booking › Record acceptance | Accepted by Sofia Bennett; the payment method isn't offered, since Alpha's deposit doesn't count as acceptance (D-93) |
| H2 | Method Phone, no note | Refused: a note is required |
| H3 | Phone, with a note | Recorded; "Covers the current price and terms" |
| H4 | Client terms tab | Version 1 locked, with "Start version 2" |
| H5 | Confirm booking | Confirmed; space Reserved; the client charge is $12,570 |
| H6 | Its supplier cost and commission (as Agency Admin) | S01 committed cost $10,840; expected commission $1,820 |
| H7 | Supplier money tab | One $450 full deposit for the S01 cabin, due today; no other cabin has one |
| H8 | Rowan booking: Email, with a PDF attached or "where it is kept" filled in; confirm | Confirmed at $9,265; V01 cost $7,730 and commission $1,085; $450 for its cabin |
| H9 | Rivera booking: In person, with a note; confirm | Confirmed at $7,445; O01 cost $6,780 and commission $924; $450 for its cabin |
| H10 | Inventory tab | Cabins left: V01 7, O01 7, I01 8, S01 7 (D4); the tour 9 participants, 7 positions used, 3 left (D6) |
| H11 | Bookings tab | Three Confirmed bookings |

## I. Edges

| Step | Do | Expect |
| --- | --- | --- |
| I1 | A new booking on the Bennett trip: one placeholder, Guest 1, in an I01 cabin; Hold space; Extend hold | Held until two days later; Extend hold is then gone |
| I2 | Change Guest 1's type | The price is proposed again; the hold stays |
| I3 | Record acceptance, then add a second traveler | The acceptance shows "No longer covers the current price and terms" |
| I4 | Confirm booking | Refused: the placeholder, the stale acceptance |
| I5 | Discard booking | Discarded; its space is released; the next booking on the trip takes the next number |
| I6 | Package tab: change the S01 1st-guest price | Existing bookings keep their prices (BKG-23) |
| I7 | Any screen at 375px | No sideways scroll; tables become cards; every action reachable by keyboard |

## Four questions, at the end

Answer these for the three confirmed bookings, from the screens alone:

| Question | Where you found it | Answer |
| --- | --- | --- |
| What did each client accept? | | |
| What has the supplier confirmed? | | |
| How is capacity used? | | |
| What money is open? | | |

The last will be partial: client money is build step 8. The supplier amounts due, and the absence of any client balance, are the honest answer for now.

## Findings

Log each finding as you go. Disposition is one of:
- **Fix now:** before step 7 starts.
- **Backlog:** with the rule ID it touches.
- **Decision needed:** a decision log entry.

| # | Part and step | What happened | What was expected | Width | Disposition |
| --- | --- | --- | --- | --- | --- |
| 1 | C, supplier rates | Cruise rates were entered one line at a time, with a separate line for each traveler type; it was unclear where occupancy ends and traveler types begin | Rates entered as a grid of bands, set once for every fare and overridden where a fare differs | Both | Fix now: [#262](https://github.com/tswarren/DepartureDesk/pull/262), merged |
| 2 | C, supplier money | A $500 per-cabin deposit couldn't be expressed on a draft cruise, which has no units yet; costs, deadlines and schedule lines read as one confusing list | A payment form that asks how much and when, in a sentence, and separates what it costs from when you pay | Both | Fix now: [#263](https://github.com/tswarren/DepartureDesk/pull/263), merged |
| 3 | E, client prices | Client prices were set one position and type at a time on each option; a 4th guest couldn't be priced apart from the 3rd on a confirmed cruise | A price grid per choice, laid out like the supplier bands, with supplier cost under each price and a band that splits by guest | Both | Fix now: [#263](https://github.com/tswarren/DepartureDesk/pull/263), merged |
| 4 | G, new booking | A booking could start only from a trip already made on the client's profile; travelers were added one at a time; rooms didn't follow the cabin; each extra night was its own entry | New booking from the Bookings tab, travelers added together, rooms that follow the cabin, nights as a range, in four steps | Both | Fix now: [#264](https://github.com/tswarren/DepartureDesk/pull/264), merged |
| 5 | G, travelers | Someone not yet linked to the client meant leaving the booking; a placeholder couldn't be replaced, only removed and the traveler re-added | Add a new or found traveler from the step, and replace a placeholder in place | Both | Fix now: [#264](https://github.com/tswarren/DepartureDesk/pull/264), merged |
| 6 | C to E, setup | Nothing said what confirming an arrangement or marking Ready to sell still needed; inventory and package choices asked for every rule each time | Ready to confirm? and Ready to sell? checklists; presets for inventory and choices; hotel rooms by night; extra nights in one go | Both | Fix now: [#265](https://github.com/tswarren/DepartureDesk/pull/265), merged |
| 7 | C to E, changes and terms | Capacity changes were technical terms; the deadline form asked for everything at once; client terms read as table cells | Supply changes as what happened; a simpler deadline form with a sentence; client terms as sentences with dates | Both | Fix now: [#266](https://github.com/tswarren/DepartureDesk/pull/266), merged |

### Second run, 2026-11-08

Rerun after build step 7, with the fixes from the first run in place.

| # | Part and step | What happened | What was expected | Width | Disposition |
| --- | --- | --- | --- | --- | --- |
| 1 | After sign-in | A second sign-in page appears inside the application shell | Land on My tasks or the dashboard | All | Backlog: the sign-in page doesn't send a signed-in user on (S-01) |
| 2 | B3, Departure team | No way to add more team members | An obvious path to add them | All | Backlog: the add form hides when no one else is left to add; the development seed has one user (ACC-09, OPS-12) |
| 3 | C6, Supplier money tab | No breakdown of committed money | — | All | Decided: by arrangement and by booking, as two views of the tab. Fix now |
| 4 | D2, the hotel | Rooms and nights are hard to read | The layout discussed earlier | All | Decided: a grid of nights by room type on the Inventory tab and the hotel arrangement. Fix now |
| 5 | G11, Inventory tab | Nov 4 didn't change after the nights were added | Nov 4 shows one used | All | The Rowans' Nov 4 Garden Queen nights were never added; same cause as 6 |
| 6 | G14, the Rowans | Total $8,885 | $9,265 | All | Fix now: the nights form ticked all three Rowans for one Garden Queen, which holds two, so Nov 4 was refused. Extra nights now follow the booking's hotel rooms |
| 7 | I1, a new booking | A confirmed booking couldn't add or change travelers, with no way on to a new booking | A confirmed booking doesn't change; a new booking is easy to start | All | Fix now: a confirmed booking says why, and every booking offers a new booking on its trip |

## Exit

The walkthrough is done when every part has been run at both widths, the four questions are answered, and every finding has a disposition, with each "fix now" merged. Build step 7, supplier reservations, starts after that.
