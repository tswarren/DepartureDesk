# Slice 1 step 4: Supplier cost, schedule lines and amounts due

**Status:** Accepted 2026-11-06; built 2026-11-06. Not implementation authority beyond the [first-slice charter](first-slice-charter.md) build step 4, [ADR 0001](../../adr/0001-money-and-currency.md), [ADR 0018](../../adr/0018-arrangement-history-by-dated-adjustment.md), and the decision log entries it cites.

Charter build step 4: supplier cost, schedule lines, amounts due and expected commission. It closes **D2** (Agreement A's deposits fall due on schedule), as amended by D-92.

It covers charter workflow step 6:
- **Supplier cost and schedule:** SMN-01 to SMN-06, SMN-08, SMN-10, SMN-11, SMN-13, SMN-14, SMN-17.
- **Rate table:** SUP-35 proposals, and SUP-13 commitments for unsold space (D-75).
- **Expected commission:** SMN-32, as D-85 moved it beside supplier cost: the rate-table proposal in step 4 and the table in step 6 (D-92).

Supplier payments are build step 8. Bookings, and the booking-confirmed trigger, are build step 6.

## Questions settled for this plan (2026-11-06)

Each recommendation was accepted. Question 1 amends the charter's cases and is logged as **D-92**, applied to the charter. The rest stay inside the cited rules and need no entry.

| # | Question | Decision |
| --- | --- | --- |
| 1 | **What D2 can check in step 4.** D2 has three checks: $1,600 falls due Nov 1, 2026; confirming each Slice 1 booking posts $450 for its cabin (D-81); and no payment changes capacity. Bookings arrive in build step 6 and supplier payments in step 8, so only the first can run in step 4. Expected commission has the same problem: SMN-32 creates it at booking confirmation and attributes it to the booking's service, which doesn't exist until step 6. | Amend the charter, in the pattern of D-90 (**D-92**):<br>• **D2** closes in step 4 with what dates drive: $1,600 falls due Nov 1, 2026. If no booking has confirmed by Mar 1, 2027, $450 falls due that day for every remaining cabin (the SMN-13 date arm).<br>• **D4** (step 6) gains the check that confirming each booking posts $450 for its cabin.<br>• **D10** (step 8) gains "no payment changes capacity".<br>• **Expected commission:** step 4 builds the rate-table proposal, which works out a booking's supplier cost and commission from the table at a given occupancy. The `expected_commissions` table comes in step 6, which creates the first rows.<br>Moving D2 whole to step 8 was rejected: it would leave step 4 with no case. |
| 2 | **What a commission rate applies to.** A rate line stores a commission rate or amount, but not its base. Alpha's terms say 14% of the base fare before the supplier discount (B6). SUP-21 says there is no universal base. | Each rate line that has a rate also records its base: **base fare** or **base fare less discount**. It defaults to base fare, and the Alpha rows use base fare. This records the supplier's stated term (SUP-21, SMN-32), so it needs no decision log entry. More bases wait for a supplier that needs one. The migration sets existing rows to base fare. |
| 3 | **Payment tasks: deadline or schedule line.** SMN-17 creates a payment follow-up task when a schedule line is created. Step 3 already gives each deposit and payment deadline its own task (SUP-23). Without a link, the Alpha deposits would get two tasks each. | A schedule line may name the supplier deadline it pays. It then uses that deadline's task and creates none of its own. A schedule line without a deadline creates its own task: at creation when it has a date, or when its amount posts when it is event-only, since a task needs a due instant (OPS-02). The task source gains `schedule_line`. Completing the task by settlement waits for payments in step 8; until then staff complete it. |
| 4 | **Completing a task that records an event.** SMN-12 says completing the matching follow-up task records the trigger event. Completing tasks is baseline (ACC-30), but recording submissions needs Supplier arrangements, and the event can post a payable. | When a task's deadline maps to a trigger event, its completion form also asks for the date the event happened and, where the line needs it, the count. Completing such a task needs Supplier arrangements. Other staff can start it but not complete it. The mapping: final count or manifest → Final count submitted; rooming list → Rooming list submitted; ticketing → Tickets issued. Names submission maps to nothing (D-81), and a deposit or payment deadline is completed by settlement. |
| 5 | **Who sees and edits what.** | Viewing cost lines, schedule lines, trigger events and amounts due needs `view_supplier_costs` (ACC-31). Recording and changing cost lines and schedule lines, and recording trigger events, needs Supplier arrangements. Recording a direct amount due (SMN-05) needs Supplier arrangements or Financial records. Payments stay with Financial records in step 8. |
| 6 | **The initial deposit's shape.** $50 per stateroom for 32 cabins can be one amount of $1,600 or 32 amounts of $50. | One arrangement-scope amount due. Its basis is $50 per unit, with the count of the arrangement's cabins that aren't returned to the supplier, snapshotted when it posts (SMN-06, SMN-14). The later $450 deposit is per shell (SMN-10, D-81), so a cabin's deposit follows that cabin. |
| 7 | **Agreement A's final payment (Aug 1, 2027).** Its amount is the balance of what the booked cabins cost, and those cost lines don't exist until bookings confirm (D-75). SMN-04 allows a schedule line before the cost is known, but no listed basis says "the balance". | Step 4 records no final-payment schedule line. Its step 3 deadline and task stay. The line is added in step 6, when booking cost lines exist. If no listed basis fits, step 6 asks for a decision rather than inventing one. |
| 8 | **When an amount posts.** SMN-05 posts an amount due "when a schedule line's date arrives or its event is recorded". | An event posts at once, in the same transaction that records it. A date posts at the start of that date in agency time, through an hourly sweep job (queue `supplier_money`). The job is idempotent and follows the departed sweep's pattern. The amount's due date is the schedule date or the event date. Tests run the sweep directly with a fixed clock. |

### D-92 as logged

> | D-92 | 2026-11-06 | Amend the first-slice charter's cases to follow its build order. D2 closes in build step 4 with the checks that dates drive: Agreement A's $1,600 falls due Nov 1, 2026, and if no booking has confirmed by Mar 1, 2027, $450 falls due that day for each remaining cabin (SMN-13). D4 (step 6) adds the check that confirming each Slice 1 booking posts $450 for its cabin (D-81), and D10 (step 8) adds that no payment changes capacity. Step 4 builds the rate-table proposal of a booking's supplier cost and expected commission (SUP-35, SMN-32); the expected commission record is built in step 6, where booking confirmation creates it. Amends D-85. | None |

## Cost lines (SMN-01, SMN-02, SMN-08, SUP-13, D-75)

- New `cost_lines`:
  - **Owner and scope:** arrangement, and a scope of `arrangement`, `inventory_group` (a category or pool) or `unit_shells`. A `unit_shells` line names its shells through `cost_line_shells` (D-75). The booking, traveler and supplier reservation scopes come in steps 6 and 7.
  - **Basis:**
    - a fixed amount for the scope;
    - a fixed amount per unit, person or night, with a quantity;
    - or a percentage of another cost line on the same arrangement (a named, known base).
  - **Amount and stage:** the amount in minor units in the arrangement currency, and whether it is `estimated` or `committed`.
- Committed lines make up committed cost exposure (SUP-13); estimated lines are shown apart as forecasts.
- **Arrangement confirmation still records no cost** (D-75). A commitment for unsold space is a committed line staff record, naming its shells.
- **Changes:**
  - A line can be edited, with audit, until an amount due posts against it.
  - After that it is fixed. Supplier amendments and adjustments (SMN-07, SMN-15) are not cited by the charter and wait.
  - A line on a Draft arrangement can be removed.

## Schedule lines and trigger events (SMN-03, SMN-04, SMN-10, SMN-11, SMN-13, SMN-14)

- New `schedule_lines`:
  - **What it pays:** arrangement, and either a cost line or the arrangement itself (SMN-04: before the cost is known).
  - **Amount and scope:** a fixed amount; a percentage of its cost line; or an amount per unit, either times a count snapshotted at posting or posted once per shell (`per_shell`, SMN-10).
  - **Due rule:** a fixed date, an event, a stated number of days after an event, or the earlier of an event and a date.
  - **Links:** the trigger type, and optionally the supplier deadline it pays (question 3).
- **A deposit pays toward the commitment, never adds to it** (SMN-03). A schedule line never creates a cost line.
- New `trigger_events`: arrangement, type, the date it happened, an optional count and reference, who recorded it and when.
  - **Types:** SMN-11's list. Types and how they are recorded:
    - **Arrangement confirmed:** recorded by Confirm, starting this step.
    - **Final count or manifest submitted, Rooming list submitted, Tickets issued:** recorded by staff, or by completing the matching task (question 4).
    - **Supplier invoice received and Other:** recorded by staff, with a reference.
    - **Service date:** recorded by the sweep when the arrangement's first service date arrives.
    - **Client booking confirmed:** recorded in step 6.
    - **Names submitted:** stays outside the first slice (D-81).
  - The event date is when it happened, which may be before it is recorded. A waiting period runs from it (SMN-13).
- **Earlier of an event and a date:** the date posts the amount if the event hasn't happened (SMN-13). For a per-shell line, the date posts once for every shell that has no amount for that line yet and isn't returned to the supplier.

## Amounts due (SMN-05, SMN-06, SMN-10, SMN-17)

- New `amounts_due`:
  - **Source:** arrangement, schedule line (blank for a direct amount), unit shell for a per-shell line, and the trigger event that posted it, if any.
  - **Amount:** in minor units, snapshotted when posted, with its currency.
  - **Dates:** due date, posted at, and who or what posted it.
- **At most one amount per shell per schedule line** (SMN-10, D-81), enforced by a unique index.
- **Calculation:** a percentage or count-based amount is calculated and snapshotted when posted. It is never recalculated (SMN-06, SMN-14).
- **Direct amounts:** staff may record one with supplier, amount and due date and no schedule line (SMN-05). It gets its own payment task.
- **Paid status:** open until payments exist in step 8. Status is derived, never stored.
- **Scope:** a payable stays at the supplier's scope, such as per cabin, whichever bookings use it (SMN-08).

## Rate-table proposal (SUP-35, SMN-32, D-75)

- New `ProposeBookingSupplierCost`: given an inventory group and the occupancy, meaning each guest's position and traveler type, it returns the proposed cost lines (gross: base fare, non-commissionable fees and taxes, less discount) and the proposed expected commission, with each amount's working.
  - It applies the rate line that matches the traveler type, else the one for any type.
  - Single occupancy uses the single row.
  - Commission is the rate times its base (question 2), or the stated amount.
- Nothing calls it in step 4 except its tests. Step 6 calls it at booking confirmation and lets staff override the result.
- Gross supplier cost, commission and net settlement stay separately identifiable, and margin counts commission once (D-75, FIN-03).

## Screens

- **S-16 Cost and schedule:** a panel on the arrangement (S-12), visible with `view_supplier_costs`. It shows:
  - cost lines, with basis and stage, and committed exposure apart from forecasts;
  - schedule lines, with due rule, trigger and linked deadline;
  - trigger events;
  - amounts due.

  It also has the forms to add or edit a cost line (including a commitment that names its shells), add a schedule line, record a trigger event, and record a direct amount due.
- **Departure supplier money (SMN-05, SMN-52):** a Supplier money tab on the Departure listing every open amount due across its arrangements, by due date. These are views of the same records, never copies. S-30's payments and paid status come in step 8.
- **Task completion with an event** (question 4): the task page asks for the event date and count when the task records an event.
- All at 1400px and 375px, with amounts as text and tabular figures.

## Alpha fixture

`AlphaFixture.load!` adds:
- **Alpha Cruises:**
  - The initial deposit: $50 per cabin not returned to the supplier, due Nov 1, 2026, paying the "Initial deposit" deadline.
  - The full deposit: $450 per shell, at the earlier of Client booking confirmed and Mar 1, 2027, paying the "Full deposit and names" deadline (B2, B3).
  - No final-payment line (question 7).
  - The rate lines' commission base set to base fare.
- **Sablewater Harbor Hotel:**
  - Committed cost lines for the firm rooms:
    - Nov 5 Garden Queen, 4 shells × $145 = $580;
    - Nov 5 Harbor Double, 4 × $175 = $700;
    - Nov 4 Garden Queen pool, 2 × $145 = $290;
    - Nov 4 Harbor Double pool, 1 × $175 = $175.

    That makes $1,280 for Nov 5 and $465 for Nov 4 (B4).
  - One schedule line per cost line, 100% due Nov 6, 2027, paying the checkout deadline (B14).
- **Shore Excursions Group:**
  - A committed cost line of $1,000 naming the first resource shell (B8).
  - Its schedule line, 100% at the earlier of Final count submitted and Oct 22, 2027, paying the payment deadline (B13).

## D2

`test/system/demonstration/d2_test.rb` replaces its skip, as amended by D-92:
1. Load the fixture with the clock at Oct 15, 2026. Check that no amount is due, and that the Departure's committed exposure is the hotel's $1,745 plus the excursion's $1,000.
2. Move the clock to Nov 1, 2026 and run the sweep. Check that one amount of $1,600 falls due Nov 1, 2026, that it shows on the Departure's Supplier money tab, and that the cabin counts are unchanged.
3. Move the clock to Mar 1, 2027 and run the sweep. Check that $450 falls due for each of the 32 cabins, $14,400 in all, at most one per cabin. Running the sweep again posts nothing.

## Not in this step

- **Later in Slice 1:**
  - the Client booking confirmed trigger, booking cost lines from the rate table, and the `expected_commissions` table (step 6);
  - Agreement A's final-payment line (step 6, question 7);
  - supplier reservations as a cost scope (step 7);
  - supplier payments, applications, paid status and completing payment tasks by settlement (step 8).
- **Slice 1b:** Agreement B's deposits and the second excursion resource.
- **Not cited by the charter:**
  - supplier amendments and adjustments with a reason (SMN-07, SMN-15);
  - supplier invoice references (SMN-16);
  - contingent costs (SMN-48);
  - the commission lifecycle beyond Expected (SMN-33, step 8).

## Tests

- **Model and database:**
  - basis, scope, stage and due-rule checks;
  - same-agency and same-arrangement keys;
  - one amount per shell per schedule line;
  - amounts in the arrangement currency;
  - a cost line fixed once an amount posts against it.
- **Posting:**
  - fixed date at the start of the date in agency time;
  - an event posts at once;
  - days after an event;
  - earlier of an event and a date, from either side;
  - per-shell posting skips returned shells;
  - counts and percentages snapshotted;
  - the sweep is idempotent.
- **Tasks:**
  - a schedule line with a deadline creates no second task;
  - one without a deadline creates its own;
  - completing a final-count task records the event and posts the excursion payment, and needs Supplier arrangements.
- **Proposal:**
  - each Alpha category and position, including single occupancy and S01's waived additional-guest fare;
  - traveler-type rows;
  - commission on each base.
- **Commands and screens:**
  - each command needs its permission and refuses other agencies' records (not found);
  - S-16 and the Supplier money tab are hidden without `view_supplier_costs`;
  - D2;
  - the screens at 1400px and 375px with no page overflow.

## Build order

One PR (D2), citing SMN-01 to SMN-06, SMN-08, SMN-10, SMN-11, SMN-13, SMN-14, SMN-17, SUP-13, SUP-35, D-75, D-81 and D-92:

1. Commission base on rate lines, and the rate-table proposal.
2. Cost lines and their shells.
3. Schedule lines, trigger events (with Confirm recording Arrangement confirmed) and amounts due, with the posting rules and the sweep.
4. Payment tasks from schedule lines, and task completion that records an event.
5. S-16, the Departure Supplier money tab, the Alpha fixture, D2 and docs.
