# Slice 1 step 8: Installments, payments, receipts and supplier payments

**Status:** Accepted 2026-11-08, with D-96 logged. Not implementation authority beyond the [first-slice charter](first-slice-charter.md) build step 8 and the decision log entries it cites.

Charter build step 8 covers:
- installments, including those for bookings already confirmed;
- client payments by route, and receipts;
- linking designated-payment acceptances to their payments (D-94);
- supplier payments.

It closes **D9 and D10**:

> **D9.** BK-101 and BK-104 pay $500 each to the agency; BK-105 pays $500 to Alpha. Agency receipts total $1,000; the receivable drops by $1,500; the Alpha payment has no receipt and is not agency cash.
>
> **D10.** Staff pay Alpha the amounts due. Amounts due are settled; the deposit is never added to cost; no payment changes capacity (D-92).

It covers two charter workflow steps:
- **Workflow step 12, client money:** CMN-01 to CMN-03, CMN-06, CMN-08, CMN-12, CMN-18, CMN-19, CMN-21, CMN-23, CMN-24, CMN-28, CMN-29 and CMN-55. CMN-52, the reseller's view, waits for build step 9.
- **Workflow step 13, supplier money:** SMN-18, SMN-19, SMN-22, SMN-23, SMN-32 and SMN-33.

It also finishes two things earlier steps left for it:
- BKG-41's link from a designated-payment acceptance to its payment (D-94 (3));
- Agreement A's final payment (step 6 plan, question 12).

## Questions settled for this plan (2026-11-08)

Questions 5, 11, 13 and 14 each do one of three things: bring an uncited rule into scope, add a basis the spec lacks, or defer part of a cited rule. Question 12 settles fixture values, and question 15 departs from the one-PR working rule. The charter takes all of those from the decision log, so they are proposed together as **D-96**, below. The other questions stay inside the cited rules. Each recommendation was accepted.

| # | Question | Recommendation |
| --- | --- | --- |
| 1 | **When installments are proposed, adjusted and fixed (CMN-08, CMN-09, CMN-12).** CMN-09 proposes installments from the payment schedule template "when staff prepare a booking for client acceptance". Staff may adjust them, and the accepted schedule is snapshotted with the terms. | **A draft booking has proposed installments**, proposed from its terms version's template once it has price lines.<br>• Each proposal has an amount, a due date and the agency as its route; Slice 1's lines are all agency-owed.<br>• Staff may adjust amounts and dates before acceptance, but the proposals must total the booking's price. The balance line takes any difference.<br>• A change to the price lines proposes them afresh. The step says so when it discards an adjustment.<br>• **The acceptance covers them:** its fingerprint includes the proposals, so changing them makes it stale (BKG-39).<br>• **At confirmation,** the charge's installments are created from the accepted proposals. Any dated before confirmation become one installment due on confirmation (CMN-12).<br>• Installments are never edited after that. Supplier-deadline buffers (CMN-10) and shortfall warnings (CMN-11) aren't cited, and wait. |
| 2 | **Bookings already confirmed (D-94 (2)).** BK-101, BK-104 and BK-105 were confirmed in step 6, before installments existed, and no proposal was accepted for them. | **`CreateBookingInstallments` is idempotent.** It gives a confirmed booking with none the installments its locked terms version proposes:<br>• dated as at its confirmation, with CMN-12 applied;<br>• totalling its charge.<br>Confirmation calls it from step 8 on. A rake task, `bookings:create_missing_installments`, runs it for bookings confirmed before step 8, and reports how many it created. The Alpha seed confirms through the command, so it needs no task. |
| 3 | **Recording a client payment (CMN-18, CMN-19, CMN-29).** | **A payment belongs to a Client Trip,** with a `PAY-` reference (ADR 0004). It records:<br>• the payer: an active client, defaulting to the trip's responsible client;<br>• the date, the amount and the Departure's currency;<br>• the route, which is the agency, or one supplier with an arrangement on the trip's Departure;<br>• the method: check, bank transfer, card, cash or other;<br>• the reference, the supplier's reference for a supplier-route payment, and who entered it.<br>**Only staff with Financial records** record, apply and reverse payments (CMN-19). Everyone else sees them.<br>**A supplier-route payment** reduces the trip's receivable but is never agency cash and gets no receipt. Where it pays an agency-owed line, it shows as supplier-held funds due to the agency (SMN-27). That balance is derived, as the data model settled; recording what the supplier does with the funds is later. |
| 4 | **Applying payments, and credit (CMN-21, CMN-23, CMN-24).** | **The payment form proposes applying it to the oldest unpaid installments first,** across the trip's bookings, and staff may change the amounts before saving.<br>• One payment may cover several installments, including future ones, and one installment may take several payments.<br>• **Credit:** whatever isn't applied is unapplied credit on the trip. That includes a payment received before confirmation.<br>• **Using credit:** the trip money panel offers "Apply credit", proposing the deposit installment first, and staff confirm it. A booking confirmed while its trip holds credit shows that proposal.<br>• Applications never cross trips. |
| 5 | **Correcting a client payment.** SMN-23's supplier payment reversal is cited, but CMN-27's client payment reversal isn't. Without it, a mistaken or bounced client payment can't be corrected, because payments are never edited. The data model already gives a client payment a reversal link. | **Bring CMN-27 into scope (D-96 (1)).**<br>• A reversal records a reason.<br>• It reopens the installments the payment settled and keeps both records.<br>• The receipt stays issued. The reversal is shown beside the receipt, never on it (CMN-55).<br>• Staff re-apply any credit it frees. |
| 6 | **Receipts (CMN-55, ADR 0004).** ADR 0004 issues a receipt number "on receipt posting", and gap-free (REF-05). D13, in build step 10, issues receipt PDFs. | **An agency-route payment issues its receipt in the same transaction,** with an `RCP-` number, gap-free.<br>• The receipt covers that payment on one Departure.<br>• It snapshots, at issue: the payer, the amount and currency, the payment date, the agency as collector and its route, the reference, and the installments applied.<br>• A later application of the same payment is shown on the payment, not on the receipt.<br>• Receipts are immutable.<br>• Step 8 shows a receipt as a page. Step 10 renders and stores its PDF (DOC-11).<br>Supplier-route payments never get one. |
| 7 | **Designated-payment acceptance (BKG-41, D-94 (3)).** | **The exception ends.**<br>• A designated-payment acceptance names a recorded client payment on the booking's trip, by either route.<br>• It is offered only when the terms version has a line that counts as acceptance, as today.<br>• The payment's date, amount and reference are read from the payment, and the three note columns are no longer written.<br>• A new constraint requires the link on every designated-payment acceptance.<br>No Slice 1 booking used one (D-93). Any development database holding a note-only acceptance from step 6 tests is replanted. |
| 8 | **Balances (CMN-06, CMN-28).** | **Each booking's charge shows:** its total, what was paid to the agency, what was paid to suppliers, and the remainder (CMN-28).<br>**The trip's money panel (S-28)** adds up its bookings for the receivable (CMN-06). Credit and supplier-held funds are shown separately.<br>**The Departure's Bookings tab** totals the receivable, agency cash and supplier-route payments, which is what D9 checks. |
| 9 | **Supplier payments (SMN-18, SMN-19, SMN-22, SMN-23).** | **A supplier payment** records:<br>• the supplier, its payee account if known, and an `SPY-` reference;<br>• the date, the amount in the arrangement currency, and the method;<br>• the bank or card reference and the supplier's invoice reference;<br>• who recorded it.<br>Only staff with Financial records record supplier payments (SMN-18), with no approval step.<br>**Applying a supplier payment:**<br>• Staff apply it to one or more of that supplier's amounts due on the Departure. The form proposes the oldest first.<br>• What isn't applied stays as an unapplied supplier payment (SMN-22).<br>• Payments never cross suppliers.<br>**Status and correction:**<br>• An amount due is Unpaid, Part paid or Paid, derived from its applications.<br>• A reversal with a reason reopens what the payment settled and keeps both records (SMN-23).<br>Applying to a schedule line that isn't due yet (SMN-21) isn't cited and waits. |
| 10 | **A payment's follow-up task (SMN-17).** SMN-17 completes a schedule line's payment task "when the amount due is settled". A per-cabin line posts amounts over months. | **The system completes the task** once both of these hold:<br>• every amount the line has posted is settled;<br>• the line can post no more, because its date has passed or it posts once.<br>Otherwise staff complete it, as today. The completion is recorded as the system's (`supplier_money.settle`). |
| 11 | **Agreement A's final payment (step 6 plan, question 12).** It is "the balance of the booked cabins' cost after their deposits". SMN-04 lets a line state "an amount or basis", but no basis means the balance after earlier amounts due. A 100% percentage line would count the deposits twice (SMN-03). | **Add a basis: the arrangement's balance (D-96 (2)).**<br>• On its date, the line posts the arrangement's committed cost, less every amount already due from its other schedule lines. It never posts less than zero.<br>• The amount is snapshotted when it posts (SMN-06).<br>The Alpha fixture adds Agreement A's final payment line, due Aug 1, 2027, already in its terms text. No Slice 1 case reaches that date, so a test fixes the clock to Aug 1, 2027 to check it. |
| 12 | **D9 and D10's fixture values.** The cases give amounts and routes, but no dates, methods or references. | **Logged as placeholders (D-96 (3)).**<br>• **BK-101:** Nadia Rowan pays $500 to the agency by check on Jan 12, 2027, reference "Check 1047".<br>• **BK-104:** Sofia Bennett pays $500 by bank transfer on Jan 19, 2027, reference "Transfer 0119".<br>• **BK-105:** Mateo Rivera pays $500 to Alpha Cruises by card on Feb 2, 2027, with Alpha's reference "8812457" (SC-REF-05).<br>• **D10:** staff pay Alpha its amounts due on Feb 3, 2027, by bank transfer from the Alpha Cruises group sales payee account, reference "Wire 0203". The payment is $2,950: the $1,600 initial deposit and $450 for each of the three confirmed cabins.<br>The development seed gains a `paid` level, after `confirmed`, that records these. The default stays `confirmed`, so a walkthrough records them by hand. |
| 13 | **Commission (SMN-32, SMN-33).** Expected commission exists from step 6. SMN-33's lifecycle runs Expected, then Confirmed or Due, then Received, Offset, Adjusted or Reversed. D14, in build step 11, needs a confirmed commission still unpaid. Receiving or offsetting one needs supplier receivables, which aren't in the slice. | **Step 8 builds Expected to Confirmed.**<br>• Staff with Supplier arrangements or Financial records record the supplier's confirmation of the amount.<br>• Confirming is refused while the amount is still being overridden.<br>**Received, offset, adjusted and reversed wait for a later slice (D-96 (4)).** |
| 14 | **What a reseller sees (CMN-52).** | **Unchanged until build step 9.** No reseller user exists yet. |
| 15 | **One PR or two.** Client money and supplier money share no records, and each closes its own case. | **Two PRs, in order (D-96 (5)):**<br>• **8a, client money:** installments, payments, applications, credit, reversals, receipts and the acceptance link. Closes D9.<br>• **8b, supplier money:** supplier payments, applications, reversals, task completion, the balance basis and commission confirmation. Closes D10.<br>Each passes `bin/ci` on its own. Step 8 is done when 8b merges. |

### D-96 as logged

> Amend the first-slice charter for build step 8. (1) Bring CMN-27 into the slice: a client payment is corrected by a reversal with a reason that reopens the installments it settled, keeping both records. (2) Add to SMN-04 a schedule line basis, the arrangement's balance: on its date it posts the arrangement's committed cost less every amount already due from its other schedule lines, never below zero, snapshotted when posted (SMN-06); Agreement A's final payment on Aug 1, 2027 uses it. (3) Settle D9 and D10's placeholder payments: BK-101's Nadia Rowan pays $500 to the agency by check on Jan 12, 2027, reference "Check 1047"; BK-104's Sofia Bennett pays $500 to the agency by bank transfer on Jan 19, 2027, reference "Transfer 0119"; BK-105's Mateo Rivera pays $500 to Alpha Cruises by card on Feb 2, 2027, Alpha's reference "8812457"; staff pay Alpha its amounts due, $2,950 (the $1,600 initial deposit and $450 for each of the three confirmed cabins), by bank transfer from the Alpha Cruises group sales payee account on Feb 3, 2027, reference "Wire 0203". Fixture values are test inputs only; no rule changes. (4) Build step 8 builds SMN-33's Expected to Confirmed transition; Received, Offset, Adjusted and Reversed wait for a later slice. (5) Build step 8 is delivered as two pull requests, an exception to the one-per-step-or-case working rule for this step only: client money, closing D9, then supplier money, closing D10. The step is done when the second merges.

### Authority updates applied with D-96

The step 8 plan's docs PR applies D-96 before any step 8 code:
- **Charter:** the status line; workflow steps 12 (CMN-27) and 13 (SMN-33's first transition only); build step 8's row and the working rules, for the two PRs; and the fixture's D9 and D10 payments.
- **[Pending decision log entries](../../spec/pending-decision-log-entries.md):** a D-96 row.
- **SMN-04** in the Google Doc names the balance basis D-96 adds, and the spec snapshot carries that sentence and the D-96 row.

## Records

New tables, each with same-agency composite foreign keys:

- **`installment_proposals`:** booking, position, amount, due date, route. Replaced whole when proposed afresh.
- **`installments`:** charge, position, amount, due date, route. Append-only.
- **`client_payments`:** trip, `PAY-` reference, payer, date, amount, currency, route, supplier (for the supplier route), method, reference, supplier reference, who entered it.
- **`client_payment_applications`:** payment, installment, amount. Append-only; a reversal adds negative applications.
- **`client_payment_reversals`:** payment, reason, date, who.
- **`receipts`:** `RCP-` number, payment, Departure, and the snapshot listed in question 6. Immutable.
- **`supplier_payments`**, **`supplier_payment_applications`** and **`supplier_payment_reversals`:** the supplier-side equivalents.
- **`booking_acceptances`** gains `client_payment_id`, with the constraint from question 7.
- **`expected_commissions`** gains its confirmed status, with who confirmed it and when.

The audit catalog adds `ClientPayment` and `SupplierPayment` subjects. Every payment, application, reversal, receipt and commission confirmation is audited.

## Screens

- **S-28, trip money,** on the Client Trip: each booking's charge with its installments, payments by route, applications, credit and the open balance. Agency cash and supplier-route payments are shown apart.
- **S-29, record client payment:** payer, date, amount, route and supplier, method, references, and the proposed applications.
- **Receipts:** a page per receipt.
- **The booking's price and hold step** shows and adjusts the proposed installments.
- **S-30 and S-31:** the Departure's Supplier money tab gains paid status and supplier payments, with the record supplier payment form.

Each screen meets the UI acceptance standards at desktop width and 375px.

## Not in this step

- Refunds (CMN-37, CMN-38), dispositions of supplier-held funds, and agency-held funds for supplier-owed lines.
- Supplier-deadline buffers and shortfall warnings (CMN-10, CMN-11).
- Paying a schedule line early (SMN-21).
- Received, offset, adjusted and reversed commission.
- Receipt PDFs (build step 10).
- The reseller's view (build step 9).
- Payment processing of any kind (CMN-18).

## Tests

- **D9** against the Alpha fixture:
  - The three payments are recorded.
  - Agency receipts total $1,000.
  - The receivable drops by $1,500.
  - The Alpha payment has no receipt and is not agency cash.
- **D10:**
  - The supplier payment settles the amounts due.
  - No cost line changes, so the deposit is never cost.
  - No capacity event or allocation changes.
- **Commands:**
  - Proposals total the price, and their adjustment makes an acceptance stale.
  - CMN-12 combining.
  - The backfill is idempotent.
  - Oldest-first proposals; credit; credit applied after confirmation.
  - Reversals reopen what they settled.
  - Receipts are gap-free and only for the agency route.
  - The designated-payment link is required.
  - The balance basis.
  - Task completion.
  - Commission confirmation.
  - Append-only and immutable records, in the application and in PostgreSQL.
- **Authorization:** only Financial records records money, and another agency's records are not found.

## Build order

**8a**, citing CMN-01 to CMN-03, CMN-06, CMN-08, CMN-09, CMN-12, CMN-18, CMN-19, CMN-21, CMN-23, CMN-24, CMN-27 to CMN-29, CMN-55, BKG-41, D-94 and D-96:
1. Proposals and installments, with the backfill.
2. Payments, applications, credit and reversals.
3. Receipts, the acceptance link, and D9.

**8b**, citing SMN-03, SMN-04, SMN-06, SMN-17 to SMN-19, SMN-22, SMN-23, SMN-32, SMN-33 and D-96:
1. Supplier payments, applications and reversals.
2. Task completion and the balance basis.
3. Commission confirmation and D10.
