# Pending decision log entries

**Status:** Draft. These entries are not yet in the [Product Specification](https://docs.google.com/document/d/1qdqOTMWcSWClAojGeB8NsYYunzJlTDcmgXp_S1Se-CQ/edit).

These are the decisions the [first-slice charter](../planning/first-slice/first-slice-charter.md) needs. When one is approved, add it to the decision log in the Google Doc with the next free `D-` number, apply any rule change in its area, re-export the snapshot, and delete it from this file. Numbers are not assigned here, so the Google Doc stays the only place that issues them.

The proposed defaults are working assumptions. Placeholder values are test inputs only.

## Already logged

| Entry | Decision | Record |
| --- | --- | --- |
| D-61 | One agency time zone; optional offices | [ADR 0016](../adr/0016-agency-time-zone-and-optional-offices.md) |
| D-62 | User types, per-user permissions and reseller users | [ADR 0017](../adr/0017-user-types-permissions-and-reseller-users.md) |
| D-63 | Arrangement history by dated adjustment | [ADR 0018](../adr/0018-arrangement-history-by-dated-adjustment.md) |
| D-64 | Adopt the first-slice charter (was C0) | [Charter](../planning/first-slice/first-slice-charter.md) |
| D-65 | Keep the existing Rails and Tailwind app (was B1) | [Charter](../planning/first-slice/first-slice-charter.md#build-plan) |
| D-66 | Amend the charter: delete M3 and M4 in Phase 1 after the spike; staff walkthrough after step 6; data-model decisions before Phase 0 closes, fixture values before their step | [Charter](../planning/first-slice/first-slice-charter.md#build-plan) |
| D-67 | Render issued documents once and store them as immutable versions in Active Storage | [ADR 0019](../adr/0019-issued-document-storage.md) |
| D-68 | Resellers in Slice 1, one channel per relationship (was B10) | [Charter](../planning/first-slice/first-slice-charter.md) |
| D-69 | Existing design tokens, error icon, spec status labels (was B11) | [Charter](../planning/first-slice/first-slice-charter.md#ui-acceptance) |
| D-70 | INV-39: traveler types that take part without using capacity (was M1) | [Spec](product-specification.md) |
| D-71 | INV-16 extended to activities sold per resource; INV-12 activity row (was M2) | [Spec](product-specification.md) |
| D-72 | SUP-35: supplier rate table; SUP-21 and SMN-32 amended (was M3) | [Spec](product-specification.md) |
| D-73 | CMN-09: template lines per traveler, unit, booking or percentage (was M4) | [Spec](product-specification.md) |
| D-74 | Editorial cleanup, and D-35, D-62, D-68, D-70 and CMN-49 carried into ACC-05, CLT-35, DEP-07, DEP-22 and INV-12; the three review tabs moved to an [archive copy](https://docs.google.com/document/d/1VOYdCGadWNOIJ9bqM6I0SgbOmHmsl7OIHyYY3h-g2io/edit) | [Spec](product-specification.md) |

## Blocking decisions

B10, B11 and the model additions are logged (D-68 to D-73). Settle B2 to B9 before the step each blocks.

| Ref | Decision | Blocks charter step | Proposed default |
| --- | --- | --- | --- |
| B2 | Is the $50 initial deposit credited toward the $500? | 6 | Yes. Naming a cabin posts $450 more on the supplier side; the client's $500 is unchanged. |
| B3 | What Mar 1, 2027 means in each agreement | 4, 6 | Agreement A: full-deposit deadline for unnamed cabins. Agreement B: option cutoff only. |
| B4 | Package hotel supplier and block | 3, 5 | A fictional Fort Lauderdale hotel. Nov 5: 4 Garden Queen and 4 Harbor Double, firm. Nov 4: 2 Garden Queen and 1 Harbor Double, releasable. Nov 1–3: on request. |
| B5 | Hotel client prices | 7 | Included night priced into the package at a placeholder $95 per traveler. Extensions at placeholder $189 Garden Queen and $219 Harbor Double per room-night. |
| B6 | Alpha rate values that look wrong | 6 | Confirm S01's −$1,000 additional-guest discount and the $0 taxes on single occupancy, or correct them. |
| B7 | Client deposit under Agreement B | 7 | Same $500 per cabin, so the two branches differ only in supplier terms. |
| B8 | Opening excursion resources | 5 | One confirmed resource; the second only through demonstration case D7. |
| B9 | Final-count deadline time | 4 | 14 calendar days: Oct 22, 2027 at 11:59 p.m. agency time (SET-10). |

## Model additions

All four were approved and logged as D-70 to D-73.

## Specification review

Found in the 2026-11-01 review of the whole specification; the evidence is in the [requirements review draft](../planning/drafts/requirements-review-2026-11-01.md). Each changes what a rule means, so each needs its own decision log entry. Settle R1 to R10 before the Slice 1 data model and screen inventory are reviewed; R11 to R14 before the slice that needs them.

| Ref | Decision | Blocks build step | Proposed default |
| --- | --- | --- | --- |
| R1 | SUP-35 names one "confirmation" for two events, and gives no basis for costing unsold cabins | 3, 4 (D1, D2) | Arrangement confirmation proposes committed cost lines per shell at the basis the supplier's terms commit to; booking confirmation proposes expected commission (SMN-32) and any cost for positions beyond that basis. Supplier cost is recorded gross with commission separate, so FIN-03 counts it once. Double occupancy is the working basis for Alpha until Agreement A confirms it. |
| R2 | CMN-09 "per unit" does not say which units are counted | 5 (D9) | Each template line names the choice it counts, and "per unit" counts the distinct shells allocated under that choice. Check: one cabin plus hotel and excursion proposes $500; two cabins propose $1,000. |
| R3 | A reseller creating client and traveler profiles rests only on CLT-25, which is Proposed | 9 (D15) | Approve CLT-25 narrowly: a reseller creates profiles only while creating an assigned booking and sees them only through it, with no directory search, other trips or history. Alternative: staff create BK-105's profiles. |
| R4 | The summary label ignores agency Sales paused (SET-16), and DEP-05 lacks the agency guard | 2 | Add the agency guard to DEP-05. Completion labels, Postponed and Cancelling keep precedence; otherwise a Departure is Not on sale while the agency is Sales paused. Building Sales paused itself stays out of Slice 1. |
| R5 | "Booking owner" notices have no person when the agency owns the booking; OPS-11's "staff owner" is undefined | 6 (BKG-10) | For an agency-owned booking on a Departure, booking-owner notices go to the Departure's default task owner, else its team (OPS-11, OPS-12). In Slice 1 only the hold-expired notice is built, in the app; admitting it needs a decision log entry naming the charter. Standalone trips are later scope. |
| R6 | SMN-11's "Names submitted" trigger cites Proposed CLT-14, and D2 posts per cabin | 4 (D2) | A names submission names the shells it covers; a per-shell schedule line posts once per shell when a submission first covers it, and a later resubmission posts nothing. Slice 1 records the submission date and reference only; CLT-14's snapshot stays Proposed. B2 stays a fixture value. |
| R7 | BKG-03's Client Trip statuses overlap | 6 | Evaluate in order: Travelled (a confirmed, uncancelled booking exists and all its services have ended); Booked (a confirmed, uncancelled booking exists); Quote (a draft exists); Cancelled (a cancelled booking exists); Not booked (otherwise, including no bookings). |
| R8 | Departed: DEP-42 has staff mark it after a prompt the day after the last service date; the shipped sweep marks it automatically from the start date | 11 (D14) | Keep DEP-42. Step 11 replaces the sweep with a staff task due the day after the last service date. |
| R9 | Departure references: REF uses `DEP-0042`; shipped code issues `D-000001` | 1, 2 | Adopt `DEP-` from step 1. Recreate development data rather than renumber; if any issued reference must be kept, REF-03 keeps it unchanged. |
| R10 | D1 closes at build step 3, but committed cost is built in step 4 | 3, 4 | Move D1 to step 4 by a decision log entry naming the charter. |
| R11 | Completion holds both "Departed" and "Financially reconciled", while DEP-43 and DEP-45 keep the Departure operationally Departed | 11 | Keep one completion status. Financially reconciled records the state it came from, which reopening restores (the completion table's "Previous status"); the label is Reconciled. No fourth status. |
| R12 | Whether a confirmed supplier compensation claim (OPS-34) is non-blocking like other confirmed receivables (D-60) | Later | A confirmed, quantified and attributed claim is a supplier receivable under D-60 and does not block; a pending claim blocks. Update OPS-34, SC-OPS-11 and the financial-condition table together. |
| R13 | The commission lifecycle reaches Received only through later-phase SMN-35 | Later | SMN-35's later phase covers line-by-line matching only; recording a commission receipt manually is in MVP. |
| R14 | SET-06 and SET-07 cover four of the nine catalog documents | Later | Each other document inherits the confirmation settings, except cancellation notices and postponement offers, which inherit the financial-document settings. |

## Left for Slice 2

The propagation and editorial fixes from the review were applied as D-74. Two choices remain, and neither blocks Slice 1: "client summary" or "proposal" as the display name (BKG-37, DOC-01, the glossary), and whether the decision log's "Rules affected" column lists only amended rules or related rules too.
