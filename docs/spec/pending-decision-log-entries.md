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

## Blocking decisions

Settle B10, B11 and the model additions before Phase 0 closes, because they shape the data model. Settle B2 to B9 before the step each blocks.

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
| B10 | Resellers in Slice 1 | 2, 9, 10 | Yes, a thin path: one reseller holds and confirms one assigned booking. Each reseller relationship has exactly one channel, and offers (not Departures) are published to channels (ACC-14, DEP-07). A channel shared by several resellers is later scope. |
| B11 | Design tokens and status labels | UI | Keep the existing `--dd-*` tokens in `app/assets/tailwind/application.css` (the form sample uses the same tokens), light theme only. Add the form sample's error icon on `.dd-field-error`, which the charter's UI acceptance requires. Status labels come from DEP-04, BKG-06, INV-18 and INV-34; Departure moves to the three statuses of DEP-03 with a derived label in step 2. |

## Model additions

Each adds a rule. Approving one adds the rule with status Agreed and a decision log entry.

| Ref | Gap | Proposed rule | Amends |
| --- | --- | --- | --- |
| M1 | Children 0–4 take part in the excursion but use no position | A supplier rule on an inventory group may name traveler types that participate without using capacity. They count in participant headcount and appear on lists, but not in positions used. Traveler type is the one staff choose on the booking (BKG-21); choosing it from age stays deferred (BKG-27). | INV-12 (activity), INV-07 |
| M2 | The excursion is sold per resource, not per place | INV-16 also applies to activities: when the supplier sells per resource, each resource is a shell with a linked position pool and a fixed cost per resource, and capacity is never counted twice. A new resource is a dated capacity increase recorded only after supplier confirmation. INV-12's activity row adds this as the alternative to a capacity pool. | INV-12, INV-16, INV-26 |
| M3 | Supplier rates vary by occupancy position, with components | An arrangement may hold a supplier rate table by inventory group and occupancy position: base fare, non-commissionable fees, taxes, discount and commission. Confirmation proposes cost lines and expected commission from it; staff may override. This lifts SUP-21's deferral only for deriving cost lines and commission from components staff enter; automatically splitting a single rate into components stays deferred. | SUP-21, SMN-02, SMN-32 |
| M4 | The client deposit is $500 per cabin, not per traveler | A payment schedule template line may be a fixed amount per traveler, per unit or per booking, or a percentage. | CMN-09 |

## Spec fixes before Slice 2

These don't block Slice 1.

| Ref | Fix |
| --- | --- |
| F1 | Remove stale references to a separate Financial review queue: SC-BKG-07, the SMN amount-due lifecycle table, and the OPS "Financial review" table title. OPS-27 already puts financial follow-up in the single staff task queue. |
| F2 | Align OPS-34 (a pending supplier compensation claim blocks reconciliation) with D-60 (confirmed, quantified, attributed supplier receivables may stay in follow-up without blocking). |
| F3 | Close the stale open-questions note in the Departures area. |
