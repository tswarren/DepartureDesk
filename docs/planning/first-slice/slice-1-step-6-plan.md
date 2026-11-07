# Slice 1 step 6: Travelers, Client Trips and bookings; hold, accept and confirm

**Status:** Accepted 2026-11-06, with D-94 logged; 6a built 2026-11-07. Amended 2026-11-07 with questions 17 to 21 from the review of 6b and 6c, before either is built; 6b built 2026-11-07, with the hotel rooming proposed as D-95. Not implementation authority beyond the [first-slice charter](first-slice-charter.md) build step 6 and the decision log entries it cites.

Charter build step 6 covers four things:
- travelers, Client Trips and bookings;
- hold, accept and confirm;
- draft saving;
- expected commission records (D-92).

It closes **D4, D5, D6 and D16**. After it, the charter calls for a staff-only walkthrough of setup through confirmed bookings, before money, reseller access and documents are built.

It covers two charter workflow steps.
- **Workflow step 8, clients and travelers:** CLT-01, CLT-02, CLT-05, CLT-06, CLT-09, CLT-11, CLT-13, CLT-15. CLT-25 waits for the reseller path in build step 9.
- **Workflow step 10, hold, accept and confirm**, for staff:
  - BKG-05, BKG-06, BKG-09 to BKG-11, BKG-25, BKG-39, BKG-41, BKG-45, BKG-46;
  - DEP-10, INV-17 to INV-23, INV-39;
  - INV-09 and INV-26 from workflow step 5, which 6b completes (questions 17 and 21).
  - ACC-15 and the reseller's part wait for build step 9.

It also builds the first records of three later workflow steps, and each is created by booking confirmation:
- the client charge and its lines (CMN-01 to CMN-03, question 2);
- the booking's supplier cost (SUP-35, SMN-02);
- the Client booking confirmed trigger (SMN-11, D-81);
- expected commission (SMN-32, D-92).

## Questions settled for this plan (2026-11-06)

Questions 1 to 6 do one of three things:
- move work or checks between build steps;
- depart from a working rule or a cited rule for a stated period;
- settle fixture values.

The charter takes those from the decision log (D-87, D-92), so they are logged together as **D-94**, below. The other questions stay inside the cited rules and need no entry. Each recommendation was accepted.

| # | Question | Recommendation |
| --- | --- | --- |
| 1 | **D4's reseller booking.** D4 has the reseller confirm BK-105. The reseller user, the relationship and its access are build step 9 (D-90), and D15 already checks the reseller's hold and confirmation there. | **Staff confirm BK-105 in step 6**, so D4 closes with all three Slice 1 bookings. In step 9, the fixture assigns BK-105 to the reseller, and the reseller holds and confirms it. D15 checks that path. |
| 2 | **The client charge at confirmation.** BKG-25 and the client booking lifecycle say confirmation creates the client charge from the accepted price snapshot. The data model makes the charge lines that snapshot. The charter puts "client charges" in build step 8. Without them, a step 6 booking would be confirmed with nothing recording what the client accepted. | **Step 6 creates the client charge and its charge lines at confirmation** (CMN-01 to CMN-03). Each line records:<br>• its type: traveler price or add-on;<br>• the traveler;<br>• the traveler type, occupancy position and chosen option (BKG-25);<br>• the amount;<br>• its creditor and expected route, both the agency in Slice 1.<br>A line is never edited. **Step 8 keeps** installments, proposing them from the payment schedule (CMN-08 to CMN-10), payments, applications and receipts. It creates the installments for bookings confirmed before it. The walkthrough after step 6 shows each booking's accepted price but no money owed or paid. |
| 3 | **Acceptance by a designated payment.** D5 says a deposit counts as acceptance only when the terms say so. BKG-41 links that acceptance to the payment's own record, and client payments arrive in step 8. | **D5 closes in step 6** with both of its checks:<br>• confirmation is refused without recorded acceptance;<br>• the method "designated payment" is offered only when the booking's terms version names a line that counts as acceptance. Alpha's terms don't (D-93), so a test terms version with the flag on covers the other half.<br>**A temporary exception to BKG-41.** BKG-41 links such an acceptance to the payment's own financial record. Until step 8, staff record that payment's date, amount and reference on the acceptance instead. These are notes, not a financial record: they post nothing, settle nothing and count toward no balance. **Step 8** links each such acceptance to its payment record, refuses a new one without the link, and ends the exception. |
| 4 | **Fixture values: travelers, clients and dates.** The roster gives surnames, counts, three first names and two ages. The mockups name the Bennetts and the Riveras. | Logged as placeholder values. The responsible client is listed first in each booking.<br>• **BK-101 Rowan:** Nadia Rowan (Adult) is the responsible client and travels (Self). With her: Theo Rowan (Adult) and Iris Rowan (Child, 9 at sailing). V01. Garden Queen, Nov 4 and 5. All three take the excursion.<br>• **BK-104 Bennett:** Sofia Bennett (Adult) is the responsible client and travels (Self). With her: Marcus Bennett (Adult), Ava Bennett (Child, 11) and Milo Bennett (Child 0–4, 2). S01. Harbor Double, Nov 2 to 5. All four take the excursion; Milo uses no position.<br>• **BK-105 Rivera:** Mateo Rivera (Adult) is the responsible client and travels (Self). With him: Elena Rivera (Adult) and Luca Rivera (Child 0–4, 3). O01. Garden Queen, Nov 5. Mateo and Luca take the excursion; Elena opts out.<br>• **Dates of birth:** placeholders consistent with those ages.<br>• **Dates:** BK-101 accepted by email and confirmed Jan 12, 2027; BK-104 by phone on Jan 19, 2027; BK-105 in person on Feb 2, 2027. All three come before the Mar 1, 2027 date arm. Each booking's hold is placed the day it's confirmed. |
| 5 | **One PR or several.** The working rules allow one PR per step or per case. Step 6 is the largest step yet, and a split with a PR that closes no case is neither. | **Three PRs, in order, as an exception to the working rule for step 6 only:**<br>• **6a: clients, travelers and Client Trips.** It closes no case and carries model, command and screen tests instead.<br>• **6b: bookings, choices, holds and draft saving.** Closes D6 and D16.<br>• **6c: acceptance and confirmation**, with the charge, supplier cost, the $450 posting and expected commission. Closes D4 and D5.<br>Each PR passes `bin/ci` on its own. Step 6 is done, and the staff walkthrough can start, only when 6c merges. |
| 6 | **When the trip reference is issued.** REF-04 builds a booking reference from its trip's, and SC-REF-06 shows a discarded draft keeping its number. ADR 0004 left the trip's issue point open ("becomes operational"), as it did for Departures before D-91. | **A Client Trip's reference is issued at creation**, `T-` and at least five digits (ADR 0004). A booking's reference is the trip reference plus a sequence number within the trip, issued when the booking is created and never reused. This follows D-91 and is part of the proposed entry, so ADR 0004's row is amended with it. |
| 7 | **When a Departure must be On sale.** DEP-05 allows new holds and bookings only while the Departure is On sale. D16 needs a booking that saves with fields missing. | **Follow DEP-05 as written.** Creating a booking, Hold space and Confirm each need the Departure On sale: Ready to sell, an operating decision of Undecided or Proceed, and completion Active. Each refusal says which condition failed.<br>Editing an existing draft is allowed whatever the Departure's state. Once created, a booking saves with fields missing, which is all D16 asks; Alpha is On sale.<br>The agency's Sales paused setting (SET-16, D-79) is not cited by the charter, so Slice 1 doesn't check it. |
| 8 | **What a hold takes, and from where.** | **Hold space** is one command for the whole booking (BKG-11), refused whole if any part can't be held. It creates one allocation per inventory-linked selection:<br>• **A per-unit choice** on unit shells, such as the cabin or a Nov 5 room, takes one shell. By default that is the lowest-numbered available shell in the group, and staff may pick another. The unit's occupants fill its positions in their order within that unit, which sets each occupant's price position (question 19).<br>• **A pool group**, such as a Nov 4 room, takes a quantity of 1 per unit.<br>• **A per-traveler choice on resource shells**, such as the excursion, takes positions only for participants whose type uses capacity (INV-39). Every participant is listed.<br>• **On-request groups**, such as Nov 1 to 3, are selected but take no allocation and don't block the hold. Build step 7 adds their supplier reservations (D8).<br>Holds follow D-88: an allocation table locked under the protocol in question 16, forward-only state changes, and a hold that must fit the lowest scheduled supply. The expiry is 11:59 p.m. agency time on the last day of the hold duration (BKG-09, SET-10). A lapsed hold stops counting at read time, with no job, and is shown as Hold expired with its time. Notices wait for notifications (D-80). Extend hold is allowed once, with the new expiry recorded. |
| 9 | **What acceptance covers.** BKG-39 voids an acceptance when the price or terms change. | The acceptance record keeps:<br>• who accepted, acting for whom, the method (email, signed, phone, in person or designated payment), the date and who recorded it (BKG-41);<br>• the terms version, which is locked when it is first accepted (BKG-28);<br>• the accepted total and a fingerprint of the booking's price lines (question 14): traveler, type, position, option and amount.<br>**Locking freezes the effective cancellation tiers.** A version that follows the agency's tiers reads them live today. On first acceptance, the lock copies the agency's tiers in effect then into the version's own tier rows and records that they were copied from the agency default, as step 5 promised. The lock trigger then protects them. A later edit to the agency default changes only versions that are not yet locked.<br>Evidence is a file for email or signed acceptance, stored like arrangement documents, and a note for phone or in person. Any edit that changes the lines or the terms version makes the acceptance stale. The booking then shows "Acceptance no longer covers the current price", and confirmation waits for a new acceptance. Earlier acceptances are kept. |
| 10 | **Confirmation's supplier effects.** | In the confirm transaction:<br>• **Allocations:** held allocations become Reserved.<br>• **Client charge:** the charge lines are created from the accepted lines (question 2).<br>• **Supplier cost:** for each selection drawn from an arrangement with a rate table (the cruise in Slice 1), a committed cost line is created from `ProposeBookingSupplierCost` at the actual occupancy. Its scope is the **client booking** (SMN-02), naming the booking's shells.<br>**Unsold-space commitments are excluded (D-75).** A shell already named by a committed cost line for unsold space gets no further cost line. The booking shows that its cost is covered by that line. Alpha's cruise has no such line, so a test commits one cruise shell first and checks that confirming a booking on it adds no cost.<br>• **Expected commission:** one row per booking service, with status Expected (SMN-32, SMN-33). It is a record of its own, never folded into a cost line: gross cost, commission and net stay separately identifiable (D-75, FIN-03). A shell covered by an unsold-space commitment still gets its commission proposed from the rate table.<br>• **Trigger event:** one Client booking confirmed event per arrangement, naming the booking and the shells it holds (D-81). Amounts due then post.<br>A missing rate refuses confirmation and names the gap. Staff with Supplier arrangements or Financial records may override a proposed cost or commission while it is Expected and nothing has posted against it (SUP-35). The override is audited. |
| 11 | **The step 4 per-shell posting.** `SupplierAmountPosting` dates an event line by the arrangement's earliest event of that type. For Agreement A's "earlier of Client booking confirmed and Mar 1, 2027" line, BK-101's confirmation would post $450 for all 32 cabins. | **Fix it in 6c.** A per-shell event line posts only for the shells its event names (D-81). The date arm still posts, on Mar 1, 2027, for each remaining shell that has no amount (SMN-13). D2's tests keep passing, and D4 checks one $450 per confirmed cabin. |
| 12 | **Agreement A's final payment (step 4, question 7).** It is the balance of the booked cabins' cost after their deposits. A deposit is a payment toward the commitment, not added cost (SMN-03), so a 100% percentage line would count the deposits twice. No listed basis means "the balance after earlier amounts due". | **Move it to step 8.** Supplier payments arrive there, and D10 depends on it. The step 8 plan proposes a basis, as a decision log entry if it needs one. The step 3 deadline and its task stay. No step 6 case needs the line. |
| 13 | **Who does what.** | Baseline staff do all of these (ACC-30):<br>• create and edit clients, travelers, trips and bookings;<br>• hold, extend, record acceptance, confirm and discard.<br>The cost lines and commission that confirmation creates are system effects of that baseline action (D-75). Only users with `view_supplier_costs` see them (ACC-31). Overrides need Supplier arrangements or Financial records (question 10). New catalog actions are `manage_bookings` (baseline) and `override_booking_supplier_cost`. A booking's owner is the agency and its creator is recorded. The seller of record and reassignment wait for step 9 (ACC-18, FIN-05). |
| 14 | **Draft prices persist.** If a draft's prices were worked out live from the offering, editing an offering price would reprice every draft and hold. That breaks BKG-23 and step 5's contract. | **Store booking price lines when they are proposed.** New `booking_price_lines`, one per traveler per included option, and per participant per add-on, each with:<br>• the traveler, traveler type, occupancy position and option;<br>• the amount, its currency, and the offering price row it came from.<br>Lines are proposed from `OfferingPriceLookup` when the booking's contents first need them, and again only for contents that change: a traveler added, removed or retyped, the occupancy order changed, or a selection changed. Lines for unchanged contents keep their amounts.<br>A change to an offering price touches no booking (BKG-23). Price refresh stays out of scope (BKG-24), so a draft keeps its proposed prices.<br>Acceptance fingerprints these lines. Confirmation creates the immutable charge lines from them and then freezes them. |
| 15 | **Editing a held booking.** A hold must never satisfy confirmation for contents different from the ones it was taken for. | **Edits replace the affected holds atomically.** Any of these on a booking with active holds re-holds the affected parts in the same command and transaction:<br>• changing travelers, their types or their occupancy order;<br>• changing a selection or its participants.<br>The old allocations are released and new ones created, under the question 16 locks. The new holds keep the original expiry and extension history, so an edit never extends a hold or resets the one extension (question 20).<br>If the new contents can't be held, the edit is refused whole, the old holds stay, and the refusal names the service. Staff can still release that service's hold explicitly and then save.<br>Edits that change no allocation, such as a traveler's name or date of birth, leave holds alone.<br>**Confirmation checks the match.** It requires one active allocation for each inventory-linked selection, with positions that match the current travelers and participants, and refuses with "The hold doesn't match the booking; hold space again" otherwise. |
| 16 | **One capacity lock protocol.** The shipped supply commands (`CapacityCommandSupport`, `ConfirmSupplierArrangement`) lock agency, Departure, arrangement, then the **inventory group** row. D-88's text says "the pool row". | **The inventory group row is the one capacity lock**, for its pool and for its shells alike. No pool or shell row is locked for capacity.<br>• **Supply commands** keep their order: agency, Departure, arrangement, group.<br>• **Allocation commands** lock agency, Departure, booking, then every affected arrangement and then every affected group, each in id order.<br>Both paths take the group last, so supply and allocation are ordered on one timeline per group (INV-26).<br>`CapacityCommandSupport` documents the protocol, and the allocation support module shares it. ADR 0018's spike amendment gains a clarifying note that "pool row" means the inventory group row that owns the pool. That changes no decision. A test races a hold against a supplier release on the same group. |
| 17 | **Reductions below allocated capacity.** Locking orders supply and allocation commands but doesn't protect held space. `CorrectCapacity` checks only that supply stays at zero or more, so with three places held, a correction from five to two succeeds. `RecordSupplierRelease` records a supplier's release even below allocations, as ADR 0018 intends, but the capacity conflict it leaves is listed as Later in the charter's scope. | **Agency reductions are refused below consuming allocations (INV-26, ADR 0018).** A downward correction is refused if supply at its effective instant would fall below the allocations still consuming capacity then. Those are Reserved allocations, and holds whose expiry comes after that instant; a hold that lapses first doesn't block it. The same check covers every later dated supply event, so a scheduled reduction is checked too.<br>**Supplier releases are still recorded,** and a minimal derived conflict follows. When the allocations consuming capacity exceed supply, the group refuses new holds, and the affected bookings can't be confirmed (INV-19, INV-23, BKG-45). Each refusal says "The supplier reduced this space below what is held; resolve it before holding or confirming." Resolving a conflict with replacement inventory (INV-28, INV-29) stays later. |
| 18 | **Which shells a deposit posts for.** `SupplierAmountPosting#eligible_shells` keeps shells whose status is "available", which today means "not returned to the supplier". Once shell status also derives Partly and Fully allocated (INV-38), a cabin a booking reserves would stop owing its $450. | **Posting eligibility is supplier-side only.** A per-shell line posts for each shell that hasn't been returned to the supplier, whatever its client allocations. `UnitShell` gains `returned_to_supplier?`, and posting uses it instead of the status label. Tests cover the confirmation posting and the Mar 1, 2027 date arm with held and reserved cabins in the group. |
| 19 | **Units and their occupants.** One booking-wide occupancy order can't say which travelers share which cabin, or how they split across hotel rooms, and BKG-14 already allows two units of a per-unit choice in one booking. | **Each per-unit selection is one unit, with its own occupants.**<br>• A per-unit choice selection has a unit number within the booking, for example cabin 1 and cabin 2.<br>• New `selection_occupants`: selection, booking traveler, position in that unit. A traveler occupies at most one unit of each per-unit choice. Positions run from 1 within the unit and never exceed the group's positions per unit (INV-09).<br>• A per-traveler selection lists its participants instead; a per-trip selection has neither.<br>• Price positions and allocation positions come from the unit's occupants, so a traveler can be a cabin's 3rd guest and a room's 1st.<br>• Booking travelers keep a booking-level order only for display.<br>• The screen pre-fills each room's occupants from the cabin's, so the roster's one-cabin bookings stay one step. A test books two cabins in one booking. |
| 20 | **Keeping the one extension across replacements.** The extension flag lives on allocations, so replacing an already-extended hold could allow a second extension. | **Replacements inherit the hold's history.** A replacement allocation names the allocation it replaces and copies its expiry and extension timestamp. Extend hold is refused if any allocation in that chain was extended. A test covers extend, then edit, then a refused second extend. |
| 21 | **Supplier occupancy rules.** INV-09 asks for simple explicit rules such as maximum occupancy and required adult count. Step 3 built only maximum occupancy, through positions per unit. Nothing records a required adult count. | **An optional required-adult rule.**<br>• `inventory_groups` gains an optional `required_adults_per_unit`.<br>• `traveler_types` gains `counts_as_adult`. Agency Admins set it on the existing traveler types screen. The type decides, because a date of birth is optional at hold.<br>• Hold and confirmation both check each unit's occupants against maximum occupancy and the required adults, and name the unit that fails.<br>• The Alpha groups carry no required-adult value: the fixture doesn't state one, and adding one would be a fixture decision for the decision log. A test group requires one adult, and a child-only cabin is refused at hold and at confirmation. |

### D-94 as logged

> | D-94 | 2026-11-06 | Amend the first-slice charter for build step 6. (1) Staff confirm BK-105 in build step 6, so D4 closes with all three Slice 1 bookings; in build step 9 the fixture assigns BK-105 to the reseller, which holds and confirms it, checked by D15. (2) Booking confirmation creates the client charge and its charge lines from the accepted price snapshot in build step 6 (BKG-25, CMN-01 to CMN-03); installments, payments and receipts stay in build step 8, which creates installments for bookings already confirmed. (3) D5 closes in build step 6. Acceptance by a designated payment is offered only when the terms say so. As a temporary exception to BKG-41, until build step 8 such an acceptance records the payment's date, amount and reference as notes that post, settle and count toward nothing, instead of linking a separate financial record; build step 8 links each one to its payment record and ends the exception. (4) Build step 6 is delivered as three pull requests, an exception to the one-per-step-or-case working rule for this step only: clients, travelers and Client Trips, closing no case; bookings and holds, closing D6 and D16; acceptance and confirmation, closing D4 and D5. The step is done when the third merges. (5) A Client Trip's reference is issued when the trip is created (REF-04, ADR 0004). (6) Settle the Slice 1 roster's placeholder travelers, responsible clients, dates of birth and booking dates as the step 6 plan lists them; fixture values are test inputs only. Amends D-87 and D-92. | BKG-41, REF-04 |

### D-95, proposed with 6b

Found while building 6b: the Garden Queen holds 2 (step 3), but BK-101 and BK-105 each put 3 travelers in a Garden Queen. Settled 2026-11-07 as below; the entry is logged before the 6b PR merges.

> | D-95 | 2026-11-07 | Settle the first-slice fixture's hotel rooming. BK-101 takes two Garden Queen rooms on Nov 4 and Nov 5 (Nadia and Iris; Theo). Each hotel group has a capacity rule that Child 0–4 takes part without using a place (INV-39), so BK-105's three travelers share one Garden Queen, with Luca using no place. Each room's 1st guest pays the room price (B5). Fixture values are test inputs only; no rule changes. Amends the first-slice charter's fixture. | None |

### Authority updates applied with D-94

The step 6 plan's docs PR applies D-94 before any step 6 code:
- **Charter:**
  - the status line;
  - D4's row: staff confirm BK-105 in step 6, and the reseller's confirmation is checked by D15 in step 9;
  - the build table's steps 6, 8 and 9;
  - a note under the working rules for the three step 6 PRs;
  - the fixture's roster values.
- **[ADR 0004](../../adr/0004-human-readable-references.md):** the client-trip row is issued at creation (D-94), as D-91 did for Departures.
- **[ADR 0018](../../adr/0018-arrangement-history-by-dated-adjustment.md):** a clarifying note that "pool row" in the spike amendment means the inventory group row (question 16).
- **[Slice 1 data model](slice-1-data-model.md):** adds booking price lines, and the client charge and charge lines with their step.
- **[Pending decision log entries](../../spec/pending-decision-log-entries.md):** a D-94 row, and the step 5 plan's "snapshotted in step 6" note pointed at question 9.
- **The spec snapshot** is re-exported once D-94 is in the Google Doc.

## Clients, travelers and Client Trips (6a)

- **Clients (CLT-01):** the shipped person and organization clients are reused unchanged. Created by (D-78) arrives with the reseller path in step 9.
- **New `travelers`:**
  - given names, middle name, surname and suffix (CLT-28), and an optional preferred name;
  - date of birth and supplier-required gender or sex, both optional on the profile;
  - email and phone.
  - No passport or emergency-contact fields.
  - A traveler is one person (CLT-05) and is reusable across trips (CLT-06).
- **New `traveler_links`:** traveler, client, and a relationship: Self, Family member, Employee or member, or Other (CLT-09).
  - A link is a convenience, never a permission (CLT-10).
  - Creating a person client may tick "this client is also traveling", which creates the traveler linked as Self (CLT-11).
- **New `client_trips`:** the agency, one responsible client (CLT-02), at most one Departure (OVR-02), and a reference issued at creation (question 6).
  - Status is derived, never stored, in D-82's order (BKG-03).
  - The `trip` reference namespace already exists.

## Bookings, choices and holds (6b)

- **New `client_bookings`:**
  - trip, offering, sequence and reference (REF-04);
  - status: Draft, Confirmed, Discarded or Cancelled (BKG-06). Step 6 uses Draft, Confirmed and Discarded.
  - creator and owner (the agency);
  - the Client terms version it books under;
  - lock version.
  - Its status is independent of allocation and supplier reservation states (BKG-06).
- **Capacity guards (questions 17 and 18):**
  - `CorrectCapacity` and every other agency-initiated reduction refuse to go below consuming allocations at their effective instant;
  - a derived capacity conflict on a group blocks new holds and confirmation;
  - posting eligibility uses `UnitShell#returned_to_supplier?`.
- **Occupancy rules (question 21):** `inventory_groups.required_adults_per_unit` and `traveler_types.counts_as_adult`, checked at hold and at confirmation with maximum occupancy.
- **New `booking_travelers` (CLT-13):**
  - booking, and a traveler or a placeholder label such as "Guest 2" (CLT-15);
  - traveler type, and a display order within the booking;
  - name as booked, snapshotted when the booking is confirmed;
  - active.
- **New `choice_selections` (BKG-14, BKG-16):**
  - booking, option, and for a per-unit choice its unit number (question 19).
  - New `selection_occupants`: a per-unit selection's occupants, each with a position in that unit. A per-traveler selection lists its participants in the same table without positions.
  - A per-traveler add-on names its participants; only they use its capacity and pay its price.
  - The model refuses a second option for a single-pattern choice, and an option from another offering.
- **New `inventory_allocations` (INV-17, INV-18, D-88):**
  - booking, selection, and a unit shell or capacity pool, with a quantity;
  - state Held, Reserved or Released, with a timestamp per transition;
  - hold expiry and extension timestamp, and the allocation it replaces, if any (question 20);
  - a trigger that allows only forward state changes.
- **New `allocation_positions` (INV-07):** allocation, booking traveler, position number, unique per shell and position among allocations that consume capacity.
- **Shell status (INV-38)** is derived from allocations: Available, Partly allocated or Fully allocated. Returned to supplier already derives from adjustments.
- **Remaining capacity** is supply less allocations that consume now: Reserved, or Held with expiry still ahead. A hold must fit the lowest scheduled supply (INV-23).
- **Commands:**
  - `CreateClientBooking`, `UpdateClientBooking`, `SaveBookingTraveler` and `SaveChoiceSelection`;
  - `HoldBookingSpace`, `ExtendBookingHold`, `ReleaseBookingHold` and `DiscardClientBooking`. Discarding releases holds at once, with no charge (BKG-06).
  - Each locks the agency, Departure and booking, then the affected arrangements and inventory groups in id order (question 16).
  - Edits to a held booking replace the affected holds atomically, or are refused whole (question 15).
- **New `booking_price_lines` (question 14):**
  - proposed from `OfferingPriceLookup` and re-proposed only for contents that change;
  - covering each traveler's included options and each add-on's participants, with zero-price lines kept;
  - frozen at confirmation.
  - The price summary reads these lines and never the live offering.
- **Confirmation blockers (BKG-45, D16),** each linked to its field:
  - acceptance of the current price and terms;
  - required choices without a selection;
  - placeholders, and travelers without a legal name or date of birth (CLT-15);
  - no active hold, a hold that doesn't match the current travelers and selections (question 15), or capacity not available;
  - a capacity conflict on a group the booking holds (question 17);
  - a unit over its maximum occupancy or short of its required adults (question 21);
  - the Departure not On sale;
  - an incomplete offering (step 5's blockers).

## Acceptance and confirmation (6c)

- **New `booking_acceptances` (BKG-41):** booking, accepted by, acting for, method, accepted on, recorded by, terms version, accepted total, line fingerprint, evidence file or note, and payment date, amount and reference for the designated-payment method (question 3). Append-only.
- **Recording acceptance** locks the terms version if it isn't locked yet (BKG-28).
  - A version following the agency's tiers gets them copied into its own tier rows first, marked as copied from the agency default (question 9).
  - `ClientTermsVersion#cancellation_tiers` reads the version's own rows once it is locked.
  - A locked version is read-only on S-21, with a "Start version N+1" action that copies it.
- **`ConfirmClientBooking`** runs in one transaction. It locks the agency, Departure, booking, arrangements and pools or shells, rechecks every blocker, and then:
  1. Reserves the allocations (BKG-45) and snapshots each traveler's name as booked (CLT-13).
  2. Creates the client charge and its lines from the booking price lines, then freezes them (questions 2 and 14).
  3. Creates the committed supplier cost lines, skipping shells already covered by an unsold-space commitment, and the expected commissions (question 10).
  4. Records one Client booking confirmed event per arrangement, naming its shells, and posts amounts due (D-81, question 11).
- Confirmation never requires payment (BKG-46).
- **Schema additions:**
  - `cost_lines` scope gains `client_booking`, with a booking id, and `cost_line_shells` names the booking's shells;
  - `trigger_events` gains a booking and its shells;
  - `client_cancellation_tiers` gains whether a row was copied from the agency default;
  - new `client_charges`, `charge_lines` and `expected_commissions`.
- **Audit:** the subjects gain `ClientTrip` and `ClientBooking`, with actions for create, update, hold, extend, discard, acceptance, confirm and override.

## Screens

The charter's UI acceptance applies: drafts save, errors link to their fields, blocked actions say why and what to do next, and every page works at 375px.

- **S-22 Client profile:** gains its linked travelers with relationship, and "also traveling" on create.
- **S-23 Traveler form:** a page in Slice 1, not a dialog: names, preferred name, date of birth, gender or sex, contacts.
- **S-24 Client Trip:** responsible client, reference, derived status, its bookings and their travelers. Money and documents panels come in steps 8 and 10.
- **S-25 Departure roster**, the Departure's **Bookings** tab:
  - each booking's reference, responsible client, status, owner, cabin, travelers and accepted or current subtotal;
  - Hold expired with its time (D-80);
  - a totals row.
  - Balance arrives in step 8.
- **S-26 Booking workspace**, one page with sections:
  - travelers in occupancy order;
  - choices;
  - price summary;
  - holds with expiry and allocation state;
  - acceptance;
  - for `view_supplier_costs` users, the booking's supplier cost and commission;
  - the confirm panel, listing what's missing with links.
- **S-27 Record acceptance:** a page in Slice 1.
- **S-17 Departure inventory:** gains allocations and derived shell status, positions used and left, and participants without positions, such as Milo and Luca (D6).
- **Drafts:** Departure, arrangement and booking forms already save with fields missing, or do so after this step. D16 checks all three.

## Alpha fixture

- `AlphaFixture.load!` gains `bookings:` with three settings:
  - `:none`, the default for existing tests;
  - `:held`;
  - `:confirmed`, which loads the question 4 roster at the question 4 dates under `set_clock`.
- The development seed loads `:confirmed`.
- **Excursion:** with the three bookings confirmed, it has 9 participants and 7 of 10 positions used (D6).
- **Cabins left:** V01 7, O01 7, I01 8, S01 7 (D4).
- **Charges:** the three charges' cabin lines total $26,400.
- **Amounts due:** each confirmation posts one $450 amount due for its cabin.

## Not in this step

- **Later in Slice 1:**
  - **Step 7:** supplier reservations, including the on-request hotel nights (D8).
  - **Step 8:** installments, client payments, receipts, Agreement A's final-payment line, and linking a payment that counts as acceptance.
  - **Step 9:** the reseller path, CLT-25, the seller of record and reassignment.
  - **Step 10:** documents, including the client summary.
- **Slice 1b:**
  - conditional holds on courtesy space (D3);
  - amendments after confirmation (D7);
  - cancellation (D11).
- **Not cited by the charter:**
  - client summaries as alternatives (BKG-38);
  - price refresh (BKG-24) and "price valid until" (BKG-40);
  - bookings without an offering (BKG-22);
  - shared-cabin bookings across trips (INV-07 across bookings, Slice 2);
  - duplicate warnings (CLT-23);
  - profile inactivation (CLT-24);
  - trip contacts by purpose (CLT-22).

## Tests

- **Model and database:**
  - one responsible client per trip, and references that are unique and never reused;
  - booking status values, and forward-only allocation states;
  - positions unique within a shell among consuming allocations;
  - selections within the booking's offering;
  - the append-only acceptance record.
- **Prices:**
  - changing an offering price leaves draft and held bookings' price lines unchanged (BKG-23);
  - only changed contents are re-proposed.
- **Capacity guards:**
  - a downward correction below held or reserved space is refused, including a dated one, but one after a hold lapses succeeds;
  - a supplier release below allocations is recorded, then blocks new holds and confirmation;
  - deposits still post for held and reserved cabins, on confirmation and on Mar 1, 2027.
- **Units:**
  - two cabins in one booking, each with its own occupants and price positions;
  - a traveler as one unit's 3rd guest and another unit's 1st;
  - a child-only cabin refused at hold and at confirmation where an adult is required.
- **Holds:**
  - all-or-nothing package holds that name the unavailable service;
  - a race for the last shell, and a hold racing a supplier release, both serialized on the group row (question 16);
  - an edit to a held booking replaces its affected holds and keeps the expiry, or is refused whole and leaves the old holds;
  - creating a booking refused when the Departure isn't On sale;
  - expiry at 11:59 p.m. agency time, after which the hold stops counting;
  - extend once only, including extend, then edit, then a refused second extend;
  - discard releases the space;
  - children 0–4 counted in the headcount but not in positions.
- **Acceptance:**
  - a change to price lines or terms makes it stale;
  - designated payment offered only under terms that say so;
  - the terms version locks on first acceptance;
  - after locking, editing the agency's default tiers leaves the version's tiers unchanged.
- **Confirmation:**
  - every blocker, each linked to its field;
  - Reserved allocations;
  - charge lines that never change after confirmation;
  - confirmation refused when the allocations don't match the current selections;
  - booking cost lines and expected commission equal to the rate-table proposal, kept as separate records;
  - no cost line for a shell already covered by an unsold-space commitment (D-75);
  - one $450 per confirmed cabin, and none for other cabins (question 11);
  - D2 still passes.
- **Access:**
  - baseline staff can book but see no supplier cost or commission;
  - overrides need a permission;
  - other agencies' trips, bookings and travelers return not found.
- **Cases:** D4, D5, D6 and D16 as system tests on the Alpha fixture.
- **Screens:** S-22 to S-27 and S-17 at 1400px and 375px, with no page overflow and `*_query_count_test.rb` guards on the roster and inventory page.

## Build order

**6a**, citing CLT-01, CLT-02, CLT-05, CLT-06, CLT-09 to CLT-11, BKG-03, OVR-02, REF-04 and D-94:
1. Travelers and traveler links.
2. Client Trips, their references and derived status.
3. S-22, S-23, S-24 and the fixture's clients and travelers.

**6b**, citing BKG-05, BKG-06, BKG-09 to BKG-11, BKG-14, BKG-16, BKG-23, CLT-13, CLT-15, DEP-05, INV-07, INV-09, INV-17 to INV-21, INV-23, INV-26, INV-38, INV-39 and D-88, and closing D6 and D16:
1. Bookings, booking travelers, choice selections with units and occupants, and booking price lines.
2. Allocations under the shared lock protocol: holds, expiry, extension carried across replacements, release, discard and atomic replacement on edit; the required-adult rule.
3. Capacity guards: agency reductions refused below consuming allocations, and the derived capacity conflict.
4. S-25, S-26 without acceptance, the inventory additions, the traveler type adult flag, the fixture's held bookings, and D6 and D16.

**6c**, citing BKG-25, BKG-28, BKG-39, BKG-41, BKG-45, BKG-46, CMN-01 to CMN-03, SMN-02, SMN-11, SMN-32, SMN-33, SUP-35, D-75, D-81, D-92 and D-94, and closing D4 and D5:
1. Acceptance records and terms locking.
2. Confirmation: Reserved allocations and the client charge.
3. Booking supplier cost, expected commission and the confirmed trigger, with the per-shell posting fix and supplier-side posting eligibility (questions 11 and 18).
4. S-27, the confirm panel, the fixture's confirmed bookings, D4, D5 and docs.
