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
| D-75 | Cost follows sales: booking confirmation proposes cost and commission; B12 withdrawn (was R1) | [Spec](product-specification.md) |
| D-76 | Payment schedule on the Departure's client terms; no agency default | [Spec](product-specification.md) |
| D-77 | Per-unit schedule lines count shells of a named service category (was R2) | [Spec](product-specification.md) |
| D-78 | CLT-25 approved narrowly; no duplicate warnings for resellers (was R3) | [Spec](product-specification.md), [charter](../planning/first-slice/first-slice-charter.md) |
| D-79 | Agency Sales paused in DEP-05 and the summary label (was R4) | [Spec](product-specification.md) |
| D-80 | Booking-owner notices follow OPS-11 routing, with an Agency Admin fallback (was R5) | [Spec](product-specification.md) |
| D-81 | Client booking confirmed as a per-shell trigger event (was R6) | [Spec](product-specification.md) |
| D-82 | Client Trip status evaluated in order (was R7) | [Spec](product-specification.md) |
| D-83 | Departed prompt is a condition; automatic sweep removed (was R8) | [Spec](product-specification.md) |
| D-84 | Departure references follow REF-02 (was R9) | [Spec](product-specification.md) |
| D-85 | Amend the charter: D1, D4, expected commission in build step 4 (was R10) | [Charter](../planning/first-slice/first-slice-charter.md) |
| D-86 | Financial reconciliation is a record, not a completion value (was R11) | [Spec](product-specification.md) |
| D-87 | First-slice fixture values B2 to B9 settled, with B13 and B14 added | [Charter](../planning/first-slice/first-slice-charter.md) |
| D-88 | Hold-and-reserve spike result: adapt the capacity ledger, holds in their own table, end-of-date effect | [ADR 0018](../adr/0018-arrangement-history-by-dated-adjustment.md#spike-amendment-2026-11-03) |
| D-89 | Client and supplier references keep the shipped CL- and SUP- formats | [Spec](product-specification.md) |
| D-90 | Amend the charter: publishing to a reseller channel moves from build step 2 to build step 9 | [Charter](../planning/first-slice/first-slice-charter.md#build-plan) |
| D-91 | A Departure's reference is issued at creation | [Spec](product-specification.md), [ADR 0004](../adr/0004-human-readable-references.md) |
| D-92 | Amend the charter: D2 keeps its date-driven checks; booking-confirmation and payment checks join D4 and D10; expected commission record in step 6 | [Charter](../planning/first-slice/first-slice-charter.md) |
| D-93 | Settle the Alpha client terms values: balance due 120 days before departure, 10/50/100% cancellation tiers, deposit not acceptance | [Charter](../planning/first-slice/first-slice-charter.md) |

## Blocking decisions

All blocking decisions are settled. B2 to B9 were logged as fixture values in D-87, which also added B13 and B14, and B12 was withdrawn by D-75.

## Model additions

All four were approved and logged as D-70 to D-73.

## Specification review

Found in the 2026-11-01 review of the whole specification; the evidence is in the requirements review draft. R1 to R11 were settled on 2026-11-03 and logged as D-75 to D-86; D-76 came out of discussing R2. Settle R12 to R14 before the slice that needs them.

| Ref | Decision | Blocks build step | Proposed default |
| --- | --- | --- | --- |
| R12 | Whether a confirmed supplier compensation claim (OPS-34) is non-blocking like other confirmed receivables (D-60) | Later | Extend D-60 explicitly: a supplier-acknowledged, quantified and attributed compensation claim may stay unpaid in follow-up without blocking reconciliation, and counts in actual margin only when received or offset. A submitted, disputed or unquantified claim still blocks. Update OPS-34, SC-OPS-11 and the condition table together. |
| R13 | The commission lifecycle reaches Received only through later-phase SMN-35 | Later | MVP lets staff record a commission receipt and apply it manually to identified commission receivables, including partially; applied amounts become Received, and unapplied cash settles nothing. Automated matching and statement reconciliation stay later. Commission receipts stay outside Slice 1 until the charter admits them. |
| R14 | SET-06 and SET-07 cover four of the nine catalog documents | Later | Client summary, confirmation, cancellation notice and postponement offer use the confirmation flags and footer. Invoice, receipt, itinerary and statement, and client-account statement use the financial-document flags and footer. A generated acknowledgment uses the confirmation flags, with its wording from the template; an uploaded acknowledgment PDF is kept as supplied, with no branding or footer added. Issued versions keep the settings they were issued with (DOC-11). The client summary row follows whichever display name is chosen. |

## Left for Slice 2

The propagation and editorial fixes from the review were applied as D-74. Two choices remain, and neither blocks Slice 1: "client summary" or "proposal" as the display name (BKG-37, DOC-01, the glossary), and whether the decision log's "Rules affected" column lists only amended rules or related rules too.
