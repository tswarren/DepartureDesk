# M5.0 — Supply read

**Status:** Draft, 2026-10-15. Not implementation authority. Acceptance adds this plan to the planning index and authorizes only the read-only queries and the boundary test in this document.

**Prerequisite:** [What is held, what a sale consumes, and what stays unsold](DepartureDesk-held-sold-and-unsold.md) is accepted in the same decision. This draft does not accept that note by itself.

**Does not authorize:** Client Trips, Travelers, allocations, Holds, Charges, receipts, Supplier Obligations, Supplier Payments, a new inventory mode, an attrition or minimum calculation, a second Cruise rate reader, Cruise summary Slice 4, or deletion of shipped Supplier code.

## 1. Purpose

Later booking needs a few answers from supply without depending on how those answers are stored. This slice defines that read. It does not create a booking.

The read keeps two answers apart:

- **Still held** is how many units remain on the supplier commitment after the allocations the caller already counts.
- **Unsold consequence** says whether an empty unit costs nothing further, or whether that cost is still agreement wording.

A still-held count is enough to decide a sale only when the unsold consequence is `none`. Everywhere else, “short” is the wrong failure.

## 2. Contract

Queries live in `app/queries/supply/`. Each takes `agency:` and returns plain `Data` values. A record outside the agency raises `ActiveRecord::RecordNotFound`. The supply side does not read booking tables. The caller passes allocations in.

`Supply::Line` is the only supply handle a later booking record may keep. Its identifiers are stable: `departure_id`, `supplier_arrangement_id`, `arrangement_item_id`, `service_occurrence_id`, `supplier_resource_id`, and `capacity_pool_id`. It does not carry a version-owned definition id. Display fields are informational. A booking record that needs one later snapshots it.

| Query | Question | Built on |
| --- | --- | --- |
| `Supply::SellableLines` | Can this published offer be sold for this scenario, and which lines would it consume? | Shipped `EvaluateOfferLiveFeasibility` |
| `Supply::Lines` | Turn offer bindings or pools into `Supply::Line` values | Stable identities and the governing version’s display fields |
| `Supply::Availability` | How many units are still held, and does that count decide the sale? | M3B capacity projections, plus the consequence rules in §4 |
| `Supply::Deadlines` | Which current Supplier deadline occurrences apply to this Departure, and when? | M3E deadline occurrences |

There is no `Supply::CostTerms` query. Supplier cost, commission, Cruise rate illustrations, and forecast readiness stay with the shipped evaluators. A later obligation plan calls those evaluators. It does not add a second component picker.

## 3. Rules for later booking code

1. Booking code reads supply only through `Supply::*`. It may hold the stable identities on `Supply::Line`. It may reference `Supplier`, `SupplierArrangement` for identity and status, `SupplierReservation` as a fulfillment link, `Departure`, and shipped M4 offer records.
2. Booking code does not read supplier tables, definitions, projections, agreement references, or evaluators directly.
3. Booking owns client consumption. It counts allocations per `capacity_pool_id` in that pool’s measurement basis, `resource_units` or `traveler_positions`, and passes them as `allocated:`.
4. The lock that stops two bookings taking the last unit belongs to the later command that confirms an allocation. This slice has no booking transaction.
5. If a later slice needs an answer this contract cannot give, it extends `Supply::*`. It does not reach around the boundary.

`test/architecture/supply_boundary_test.rb` enforces rule 1 for `app/**/booking/**` and for the M5 and M6 record names, once those files exist. Until then the test guards the query namespace and the forbidden-pattern examples.

Shipped Supplier behavior stays maintainable. This plan does not freeze hotel, cruise, charter, or activity corrections.

## 4. Availability

`Supply::Availability` takes `agency:`, `lines:`, `allocated:` (optional), and `requested:` (optional). `allocated` and `requested` are keyed by `capacity_pool_id` and counted in the pool’s measurement basis.

Each row carries:

| Field | Meaning |
| --- | --- |
| `held` | Current supplier capacity minus `allocated`, when a numeric projection exists. Nil when the line has no countable pool. |
| `unsold_consequence` | `none` or `wording` |
| `count_decides_sale` | True only when `unsold_consequence` is `none` |
| `status` | `request`, `enough`, `short`, `wording`, `unknown`, or `closed` |
| `reason` | Plain text when the status needs it |

`held` is how many units are still on the commitment. It is not an attrition shortfall, a charter invoice, or a meal minimum.

### When the count decides the sale

`unsold_consequence` is `none` only in this closed list:

- The pool is `on_request` or `externally_managed`. Nothing is held ahead of confirmation. Status is `request`.
- The line is a per-person place whose empty place is not owed: an activity seat sold per confirmed traveler, including the Island Sightseeing shape, where the operating minimum means the supplier may cancel. Status is `enough` or `short` from `held` and `requested`. The operating minimum is not turned into a charge and is not read as a capacity-pool minimum.
- The line is a per-person transfer, with the same `enough` or `short` result.
- There is no pool because the ticket or admission has not been bought. Status is `request`. An issued ticket is outside this list.

A cabin or room Staff have already released is already gone from the projection. It is not part of `held`. This query does not release it.

### When the count does not decide the sale

`unsold_consequence` is `wording`, `count_decides_sale` is false, and status is `wording` for:

- a contracted hotel block, a courtesy hold recorded as a block, and an allotment, including when an attrition agreement reference exists;
- extra nights that are not yet their own confirmed inventory;
- a complimentary room or a tour-conductor credit;
- a cruise cabin still held, because a penalty for keeping or dropping it is agreement wording and the deadline does not release it;
- a charter priced per confirmed vehicle, including empty seats on that vehicle;
- a guaranteed meal, including one with a zero client price;
- a billable activity floor;
- an issued ticket;
- an entitlement whose unsold or cancelled outcome depends on the base booking.

`held` is still returned for a numeric pool so Staff can see how many units remain on the commitment. A later booking must not treat that number as proof that the empty units cost nothing, and must not treat status `wording` as available.

An inactive Arrangement is `closed`. A numeric pool with no projection is `unknown`. Guest position, occupancy, and ticket type stay prices. They do not change `held`.

## 5. Deadlines

`Supply::Deadlines` returns current deadline occurrences on the governing version of each active Arrangement for the Departure, ordered by due date. It returns the supplier’s date, the label, and whether the date has passed.

It does not return Deposit Requirements, attrition measurement dates stored only as agreement wording, or the consequence of missing a date. Passing a deadline does not release capacity and does not post money. Deposit Requirements remain a named gap for a later plan.

## 6. Sellable lines

`Supply::SellableLines` calls `EvaluateOfferLiveFeasibility` and converts the selected bindings into `Supply::Line` values. It adds the agency check that the shipped evaluator leaves to its callers. It does not change publication, compatibility, or the `"Needs review"` attention filter.

Offer feasibility and `Supply::Availability` stay separate. A published offer can be feasible while a line’s unsold consequence is still wording.

## 7. Not in scope

- No new tables, migrations, or UI.
- No change to M3 or M4 behavior.
- No Client Trip, Traveler, allocation, Hold, Charge, receipt, obligation, or payment.
- No calculation of attrition, a charter invoice, a meal minimum, a refund, a commission, or a Cruise net.
- No reading of agreement-reference wording as a numeric input.
- No removal of commitment evidence, confirmation links, Arrangement ending, or Cruise term tables.

## 8. Acceptance

On acceptance, the planning index records this plan as the authority for the supply read only. M5 Client Trips and fulfillment stays Not authorized until a later plan names the first booking path. That path sits on this read and does not treat status `wording` as a remaining-count failure.
