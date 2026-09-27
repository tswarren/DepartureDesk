# Port Promotions — Island Sightseeing 2027 Canonical Activity Scenario

## 1. Status and authority

**Status:** Draft. Not implementation authority.

This document supersedes previously written Island Sightseeing fixture facts. No slice may rely on it until it is Approved and an accepted slice plan names it.

## 2. Purpose

Prove a per-participant Activity with a controlled maximum and an operating minimum that is not a guaranteed charge.

## 3. Source classification

Illustrative Supplier Composition facts for the Smith Family Reunion.

The Supplier contract date, confirmation or reference number, and exact port meeting point have not been supplied. They may be added later without changing the locked capacity, cost, minimum-enrollment, deadline, or cancellation meanings.

## 4. Departure facts

| Fact | Value |
| --- | --- |
| Departure | Smith Family Reunion |
| Supplier | Port Promotions |
| Activity | Island Sightseeing |
| Family term | Activity |
| Location | CocoCay, Bahamas |
| Activity date | November 8, 2027 |
| Local time zone | America/Nassau |
| Departure | 9:30 a.m. from the port |
| Return | 3:00 p.m. to the port |
| Duration | 5 hours 30 minutes |
| Currency | USD |

The time and date are local to CocoCay.

## 5. Supplier Arrangement topology

The activity is one Arrangement Item with one scheduled Occurrence. The Item is addressed by its stable Arrangement Item ID, never its label or creation order. The Occurrence is addressed by its stable Occurrence ID.

Editing the activity name does not create a second Item. A second activity under Port Promotions must not change which Item this workspace opens.

## 6. Resources and capacity

Port Promotions reserves up to **40 participant spaces** for the group.

The quantity of 40 is Supplier-controlled group capacity, not merely a descriptive maximum. The opening Capacity Pool therefore represents:

```text
40 controlled participant spaces
```

The activity has an operating minimum of **five enrolled travelers**.

- `40` is the maximum controlled capacity available to the group.
- `5` is the enrollment threshold below which Port Promotions may cancel the activity at its discretion.
- The five-person threshold is not a guaranteed minimum charge.
- If Port Promotions elects to operate with fewer than five travelers, the Supplier charge remains $50 for each confirmed participant; it is not raised to five participants.

The participant Resource and Capacity Pool retain stable identities through ordinary edits and successor drafts according to shipped M3 authority. Capacity consumption, when Reservation work is introduced, is one participant space per enrolled traveler.

## 7. Supplier costs

The contracted Supplier cost is:

```text
$50.00 per confirmed participating traveler
```

The rate includes transportation, guide services, admissions, and taxes. Gratuities are not included.

The $50 is one contracted per-participant Supplier cost component. The included services are explanatory contract details and are not separate additive Supplier cost components unless the Supplier later itemizes them. Editing the rate submits the stable Supplier cost component ID.

| Confirmed participants | Calculation | Supplier amount |
| ---: | --- | ---: |
| 4, if Supplier elects to operate | 4 × $50 | $200 |
| 5 | 5 × $50 | $250 |
| 20 | 20 × $50 | $1,000 |
| 40 | 40 × $50 | $2,000 |

These calculations are write-free illustrations. They are not persisted invoices, payments, Client prices, or Package totals.

## 8. Deposits and deadlines

There is no separate advance deposit. The November 1, 2027 requirement is the full-payment deadline. Seven calendar days before the activity is November 1, 2027.

| Requirement | Date | Meaning |
| --- | --- | --- |
| Minimum-enrollment review | November 1, 2027 | Determine whether the five-traveler operating threshold has been reached and obtain the Supplier's decision when it has not. |
| Final participant count | November 1, 2027 | Provide Port Promotions with the confirmed count. |
| Full payment due | November 1, 2027 | Pay $50 for each confirmed participant. |
| Non-cancellable boundary | November 1, 2027 | Confirmed participation becomes non-cancellable and non-refundable. |

On that date, Staff reviews whether at least five travelers are enrolled, Port Promotions may cancel at its discretion if enrollment is below five, Staff provides the final participant count, and full payment is due based on the confirmed participant count.

The shared date must not cause these different required actions to be collapsed into duplicate or ambiguous records. The accepted implementation contract must decide which meanings are actionable Deadline definitions, which belong to a Supplier commitment or disposition, and which remain readable contract terms.

## 9. Cancellation terms

Before November 1, 2027, the Agency may reduce enrollment or cancel without the non-refundable charge described here.

Beginning November 1, 2027, the confirmed booking is non-cancellable, amounts paid for confirmed participants are non-refundable, and falling below five does not automatically cancel the activity. The Supplier decides whether it will operate.

If Port Promotions elects to operate below the minimum, it charges only for the confirmed participating travelers. After the November 1 cutoff, a confirmed traveler who later does not attend does not produce a refund.

The Supplier's below-minimum decision must be recorded as an operational outcome. The system must not infer cancellation merely because the current enrollment quantity is less than five.

## 10. Expected summaries

```text
Island Sightseeing
Port Promotions

November 8, 2027 · 9:30 a.m.–3:00 p.m.
CocoCay, Bahamas · America/Nassau

Capacity
40 controlled participant spaces
Minimum enrollment: 5 travelers
Below minimum: Supplier may cancel at its discretion

Supplier cost
$50.00 per confirmed participant
Includes transportation, guide, admissions, and taxes
Gratuities not included

November 1, 2027
Review minimum enrollment
Final participant count due
Full payment due
Booking becomes non-cancellable and non-refundable
```

## 11. Required proof

A later Activity adapter walkthrough should prove through the browser that Staff can:

1. Create Island Sightseeing as the exact Activity Item.
2. Schedule it for November 8, 2027 from 9:30 a.m. to 3:00 p.m. in `America/Nassau`.
3. Record 40 controlled participant spaces.
4. Record an operating minimum of five without turning it into a five-person guaranteed charge.
5. Record the $50 per-participant Supplier cost and its inclusions.
6. Record the November 1 final-count and full-payment requirements.
7. Preserve Supplier discretion when enrollment is below five.
8. Show the non-cancellable and non-refundable boundary without claiming a Client refund policy.
9. Reopen the exact Activity by stable Item ID when a second Activity exists.
10. Preserve compatible sibling facts after a failed save.

Governing facts are read-only. Successor terms are labeled proposed. Unsupported definitions remain readable and link to Advanced without being rewritten.

## 12. Explicit exclusions

- Client price, including the previously discussed $57.50 amount.
- Whether the activity is included, optional, or an add-on in an offer.
- Service Offer choices or rate-category keys.
- Client Trip enrollment records.
- Actual Supplier payments, invoices, Obligations, or paid status.
- Gratuity collection.
- Automatic cancellation when enrollment is below five.
- An exact port meeting-point description that has not yet been supplied.

## 13. Superseded facts

Previously written Island Sightseeing fixture facts that conflict with this document, including a $57.50 Client price, are superseded. They must not fill a field this scenario defines differently.
