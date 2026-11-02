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
| B12 | Occupancy basis of Agreement A's committed cost | 6 | Double occupancy, approved as a fictional fixture term so D1 can run. Agreement B records only its own commitment terms (R1). |

## Model additions

All four were approved and logged as D-70 to D-73.

## Specification review

Found in the 2026-11-01 review of the whole specification; the evidence is in the [requirements review draft](../planning/drafts/requirements-review-2026-11-01.md). Each changes what a rule means, so each needs its own decision log entry. Settle R1 to R11 before the Slice 1 data model and screen inventory are reviewed, since R11 affects persistence; R12 to R14 before the slice that needs them.

R3, R5 and R10 also change the charter's scope or build plan, so each needs a decision log entry that names the charter as well as its rule change: R3 adds CLT-25 to the rules workflow steps 8 and 9 cite, R5 admits the in-app hold-expired notice, and R10 moves D1 to build step 4.

| Ref | Decision | Blocks build step | Proposed default |
| --- | --- | --- | --- |
| R1 | SUP-35 names one "confirmation" for two events, and gives no basis for costing unsold cabins | 3, 4 (D1, D2) | Arrangement confirmation records committed cost only to the extent the supplier's terms establish, with its quantity and occupancy basis; uncommitted amounts stay forecasts. Booking confirmation proposes expected commission (SMN-32) and any cost adjustment for actual occupancy, such as single occupancy or additional guests, as a dated adjustment (SUP-14, SMN-07) rather than adding the cabin cost again. Gross supplier cost, commission and net settlement stay separately identifiable, and margin counts commission once (FIN-03). Confirming courtesy or option space does not by itself establish a commitment. Alpha's basis is fixture value B12. |
| R2 | CMN-09 "per unit" does not say which units are counted | 5 (D9) | Each per-unit template line names the choice it counts. Its quantity is the number of distinct shells allocated under that choice on the booking, counted once whatever the traveler count, so a Cabin line excludes hotel rooms and excursion resources. One cabin proposes $500; two cabins propose $1,000. The resulting quantity and amount are snapshotted with the accepted schedule. A cabin shared across bookings is decided with Slice 2. |
| R3 | A reseller creating client and traveler profiles rests only on CLT-25, which is Proposed | 9 (D15) | Approve CLT-25 narrowly: a reseller may create client and traveler profiles while creating a booking assigned to its reseller relationship. Access stays through currently assigned bookings, with no agency directory search, other trips, profile history or sensitive fields. The charter cites CLT-25 (see above). |
| R4 | The summary label ignores agency Sales paused (SET-16), and DEP-05 lacks the agency guard | 2 | Completion labels come first, then Cancelling and Postponed. For any other Active Departure, the label is Not on sale while the agency is Sales paused; otherwise the Draft and Ready-to-sell rules apply. DEP-05 gains the agency guard. The pause blocks new holds, bookings and publication without changing the Departure's stored statuses or existing bookings. Building the pause control stays out of Slice 1. |
| R5 | "Booking owner" notices have no person when the agency owns the booking; OPS-11's "staff owner" is undefined | 6 (BKG-10) | For an agency-owned booking on a Departure, notify the Departure's active default task owner; else its active team members; else the agency's active Agency Admins, of whom there is always one (ACC-12). No recipient check gates Ready to sell (DEP-06). For a reseller-owned booking, notify the active users of the assigned reseller relationship. Slice 1 admits only the in-app hold-expired notice (see above). Standalone-trip routing is defined before those trips enter scope. |
| R6 | SMN-11's "Names submitted" trigger cites Proposed CLT-14, and D2 posts per cabin | 4 (D2) | A names submission records the cabins it covers, the actual submission date and the supplier reference when available. Staff record explicitly that each cabin meets the supplier's naming requirement; entering a traveler name is not enough. Each cabin's full-deposit amount posts once, at the earlier of its qualifying submission and the contractual deadline (SMN-04, SMN-13); a resubmission, task completion or the deadline passing never posts it again. With B2 as proposed, each posts $450. Submission content snapshots (CLT-14) stay outside Slice 1. |
| R7 | BKG-03's Client Trip statuses overlap | 6 | Evaluate the whole trip in order: Booked (any confirmed, uncancelled booking has a service not yet ended, or an unknown end); Travelled (otherwise, a confirmed, uncancelled booking exists and every service on every such booking has ended); Quote (otherwise, a draft exists); Cancelled (otherwise, a cancelled booking exists); Not booked (otherwise, including an empty trip or only discarded bookings). A leftover draft stays visible on a Travelled trip. |
| R8 | Departed: DEP-42 has staff mark it after a prompt the day after the last service date; the shipped sweep marks it automatically from the start date | 11 (D14) | Keep DEP-42. Step 11 replaces the automatic transition with one staff task due the day after the last service date, by the governing service dates and time zones, updated when the schedule changes and completed when staff mark the Departure Departed. The same pull request updates AGENTS.md's departed-sweep rules. |
| R9 | Departure references: REF uses `DEP-0042`; shipped code issues `D-000001` | 1, 2 | New references use `DEP-` with at least four digits, widening as needed (REF-02). Every retained issued reference is kept unchanged (REF-03). Recreating disposable development or test databases is a separate operation that names the databases and data affected, not part of the rule. |
| R10 | D1 closes at build step 3, but committed cost is built in step 4 | 3, 4 | Step 3 delivers arrangement and inventory foundations; D1 closes in step 4, when arrangement confirmation also records committed cost atomically (ADR 0018). No interim confirmation without cost. The charter changes (see above). |
| R11 | Completion holds both "Departed" and "Financially reconciled", while DEP-43 and DEP-45 keep the Departure operationally Departed | 11 | Keep Financially reconciled as a completion value that records whether it came from Departed, Cancelled or Superseded. While reconciled, operational restrictions follow that recorded state, and the label is Reconciled. Reopening restores the state and keeps the previous financial snapshot. No fourth status. |
| R12 | Whether a confirmed supplier compensation claim (OPS-34) is non-blocking like other confirmed receivables (D-60) | Later | Extend D-60 explicitly: a supplier-acknowledged, quantified and attributed compensation claim may stay unpaid in follow-up without blocking reconciliation, and counts in actual margin only when received or offset. A submitted, disputed or unquantified claim still blocks. Update OPS-34, SC-OPS-11 and the condition table together. |
| R13 | The commission lifecycle reaches Received only through later-phase SMN-35 | Later | MVP lets staff record a commission receipt and apply it manually to identified commission receivables, including partially; applied amounts become Received, and unapplied cash settles nothing. Automated matching and statement reconciliation stay later. Commission receipts stay outside Slice 1 until the charter admits them. |
| R14 | SET-06 and SET-07 cover four of the nine catalog documents | Later | Client summary, confirmation, cancellation notice and postponement offer use the confirmation flags and footer. Invoice, receipt, itinerary and statement, and client-account statement use the financial-document flags and footer. A generated acknowledgment uses the confirmation flags, with its wording from the template; an uploaded acknowledgment PDF is kept as supplied, with no branding or footer added. Issued versions keep the settings they were issued with (DOC-11). The client summary row follows whichever display name is chosen. |

## Left for Slice 2

The propagation and editorial fixes from the review were applied as D-74. Two choices remain, and neither blocks Slice 1: "client summary" or "proposal" as the display name (BKG-37, DOC-01, the glossary), and whether the decision log's "Rules affected" column lists only amended rules or related rules too.
