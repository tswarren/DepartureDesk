# M4D.1 Slice 3A.3 — Hotel Supplier rates and economics

**Status:** Accepted 2026-10-01. This plan authorizes Hotel Supplier rates and economics only. [Hotel Agreement](hotel-agreement.md) is Shipped 2026-10-01. [Hotel Review and Activation](hotel-review-and-activation.md) is Shipped 2026-10-02. [Hotel Lifecycle](hotel-lifecycle.md) is Shipped 2026-10-02.

**Parent:** [M4D.1 Slice 3A — Hotel Supplier Composition](m4d1-slice3a-hotel-supplier-composition.md), §9–§10 and §23.

**Prerequisite:** [Slice 3A.1](m4d1-slice3a1-hotel-supplier-term-persistence.md) and [Slice 3A.2](m4d1-slice3a2-hotel-stay-and-nightly-inventory.md) are complete and green. Pin the merged 3A.2 `main` SHA before accepting or implementing this slice.

**Canonical fixture:** [Hilton Fort Lauderdale Marina 2027](../fixtures/hilton-fort-lauderdale-marina-2027-canonical-scenario-draft.md).

**Scope:** The Supplier rates area of the typed Hotel workspace. Staff record and review the ordinary Hotel rate structure on the inventory graph Slice 3A.2 already stored.

This acceptance amends parent §23 and blocking-proof item 12 for this slice only: the write-free illustration `$4,156 × 16.5% = $685.74` is not part of Hotel Supplier rates. It does not assign that illustration to Hotel Agreement. The 16.5% already stored on the Hotel attrition snapshot remains a Slice 3A.1 attrition fact. This plan does not authorize Hotel Agreement, Hotel Review and Activation, or Hotel Lifecycle. [Hotel Agreement](hotel-agreement.md) is Shipped under its own plan. [Hotel Review and Activation](hotel-review-and-activation.md) is Shipped 2026-10-02 under its own plan.

---

## 1. Goal

Staff can record and resume what the Hotel charges for each room category and occupancy, and what the current contracted room block costs the Agency before tax.

The persisted terms are the parent’s §9 shape: one room-night base and occupancy-position supplements. Single, Double, Triple, and Quad totals are derived. The current pretax block result is derived. Neither figure is stored as its own price, and neither is the Slice 3A.1 deposit basis.

## 2. Sequence

| Slice | Scope |
| --- | --- |
| **3A.1** | Supplier-term persistence foundations. Implemented. |
| **3A.2** | Stay and nightly inventory. Implemented. |
| **3A.3** | Supplier rates and economics. Accepted 2026-10-01. |
| Hotel Agreement | Shipped 2026-10-01. [Hotel Agreement](hotel-agreement.md). |
| Hotel Review and Activation | Shipped 2026-10-02. [Hotel Review and Activation](hotel-review-and-activation.md). |
| Hotel Lifecycle | Not authorized. |

## 3. Canonical Hilton economics

Rates are per room, per night. The base covers the room. Positions three and four add supplements. No adult/child distinction is inferred.

| Room category | Single | Double | Triple | Quad |
| --- | ---: | ---: | ---: | ---: |
| Standard | $173 | $173 | $193 | $213 |
| Deluxe | $223 | $223 | $243 | $263 |

Standard is a base of $173 per room night, plus $20 for the third occupant and $20 for the fourth. Deluxe is a base of $223 per room night, with the same supplements. The Hotel is net and noncommissionable. There is no expected Hotel commission.

The current contracted block, using the Slice 3A.2 openings and the base rates only, is:

| Night | Calculation | Pretax |
| --- | --- | ---: |
| November 4 | `5 × $173 + 2 × $223` | $1,311 |
| November 5 | `10 × $173 + 5 × $223` | $2,845 |
| **Current pretax contracted-room total** | | **$4,156** |

On this page that total is the current Supplier-cost result for the contracted base room block. It is not a deposit basis. The immutable original contractual deposit basis remains the Slice 3A.1 record.

## 4. Persisted graph

No new tables. No `HotelRate` record. Supplier cost remains distinct from Client price.

Each recognized inventory night and each room category is its own cost context. A Resource-scoped source with no Occurrence is not this shape: one usage context has one resource quantity and one billable-night count, and that cannot say November 4 Standard is 5 rooms while November 5 Standard is 10.

| Fact | Record |
| --- | --- |
| November 4 × Standard, base $173 | `CreateSupplierCostSource` for the Hotel Item, the November 4 Occurrence, the Standard Resource, and Hilton as charging Supplier. One `contracted` calculated definition. One `supplier_charge` / `unit_rate` / `resource_nights` component of 17300 minor units |
| November 4 × Deluxe, base $223 | same, 22300 minor units |
| November 5 × Standard, base $173 | same, 17300 minor units |
| November 5 × Deluxe, base $223 | same, 22300 minor units |
| Third occupant, $20 | `occupancy_position_nights`, `occupancy_position_from` 3, `occupancy_position_to` 3, 2000 minor units, on each of those definitions |
| Fourth occupant, $20 | same at position 4 |
| Net and noncommissionable | `SetSupplierCostCommissionTreatment` with `noncommissionable` on each definition. No `expected_commission` component |

Currency is the Departure operating currency. Amounts are integer minor units. The definition stage is `contracted` and the mode is `calculated`. One contracted definition per source is the shipped uniqueness rule. Completed occupancy totals are not components.

A compact “all contracted nights” control may copy the same minor-unit amounts onto each night’s source. When stored amounts differ by night, the page shows those nights separately.

The typed rate save creates only the Hotel-owned generic forecast inputs required by the accepted Hotel Review and Activation amendment: one Item/Occurrence/Resource usage assumption with one billable night, one `Contracted rooms` occupancy profile, anonymous `Hotel guest` positions 1 through that room category's `maximum_occupancy`, and the existing `forecast_ready` transition with provenance `Hotel contracted rate workspace`. It still creates no Client price or deposit-basis row.

## 5. Workspace

Add **Supplier rates** to the existing Hotel local navigation:

```text
Overview
Stay
Room inventory
Supplier rates
```

Agreement and Review & activate remain absent. Do not add a second application sidebar.

The page presents the Hotel contract. The generic cost graph is not the primary interaction. For the canonical fixture the entry surface is:

```text
Rates are per room, per night.

Room category        Base rate
Standard             173.00
Deluxe               223.00

Additional occupants
Third occupant       20.00
Fourth occupant      20.00

Commission
Net and noncommissionable

Save Supplier rates
```

Below that, a read-only occupancy illustration:

```text
                 Single   Double   Triple   Quad
Standard         $173     $173     $193     $213
Deluxe           $223     $223     $243     $263
```

And the current contracted block:

```text
Nov 4
5 Standard × $173       $865
2 Deluxe × $223          446
Night total            $1,311

Nov 5
10 Standard × $173    $1,730
5 Deluxe × $223        1,115
Night total            $2,845

Pretax contracted-room total
                       $4,156
```

Opening the page creates no cost records.

## 6. Common entry and nightly variation

A common third-occupant field and a common fourth-occupant field are shown only while every supported category and night stores that same amount. The same rule applies to a base rate shown once for all contracted nights.

The save may fan one submitted amount across the recognized night and category sources. When the stored graph already differs by Resource or by night, the page shows those values independently. It does not replace them with one common value.

A blank supplement creates no component. Submitting a blank value for a supplement that already has a component removes that component through `RemoveSupplierCostComponent`. It does not store zero. A stored zero is a known zero. Blank and zero remain different facts. A stored room-night base stays required: blanking it is rejected.

## 7. Save boundary

**Save Supplier rates** is one Staff action. It sequences the shipped cost commands in one transaction: create a missing source, create its contracted definition, create or update the supported components, remove a supplement whose submitted amount is blank, and set commission treatment. Each command keeps its own authority. There is no `SaveHotelRates` domain command and no direct model write.

Before those commands run, every existing cost definition represented in the submitted snapshot must still have the lock version Staff viewed, including a definition whose amounts did not change. A stale snapshot is rejected and writes nothing. An invalid amount rejects the whole submission and redisplays the submitted values. An unchanged component is not rewritten. Creation uses distinct idempotency keys from one form key.

Rendering the page creates nothing.

## 8. Commission

Every typed Hilton definition persists `commission_treatment` `noncommissionable` through `SetSupplierCostCommissionTreatment`. The page says **Net and noncommissionable**, and saving the typed rates requires that acknowledgement. An unchecked box is rejected and does not leave the stored treatment looking changed. An absent commission component is not that fact: `unspecified` remains “not entered.”

The shipped model and database rules stay authoritative. A noncommissionable definition cannot contain an `expected_commission` component. An `expected_commission` component cannot belong to a noncommissionable definition.

## 9. Occupancy illustrations

The page shows ephemeral Single, Double, Triple, and Quad totals for each category, bounded by that Resource’s `maximum_occupancy`. A maximum occupancy of 3 has no Quad illustration.

The illustrations come from `EvaluateSupplierCostForecast` with the definition under review and ephemeral positions for one room and one night. They create no occupancy profile, Reservation, or traveler, and they are not forecast assumptions. The page does not ship a second arithmetic engine.

## 10. Contracted-block preview

The block preview answers the current Supplier cost of the contracted room openings. It uses `EvaluateSupplierCostForecast` with `probe_definition` and ephemeral inputs for each recognized night and Resource:

- `expected_billable_nights` of 1;
- resource units equal to that Pool’s current `proposed_opening_quantity`;
- an ephemeral profile with that room count and no third or fourth position.

The base then evaluates to the room-night charge. The supplements evaluate to $0. The preview persists nothing. The Stay Occurrence is not the quantity. An evaluation that uses two billable nights, and would produce $8,312 for the canonical fixture, is not this result.

Changing a Pool quantity changes this current result and does not rewrite rate components. Changing a rate does not rewrite Pool quantities, Pool evidence, or the Slice 3A.1 deposit basis.

`current inventory × current rates` and the immutable original deposit basis stay distinct.

## 11. Forecast readiness

Under the accepted Hotel Review and Activation amendment, a complete supported contracted Hotel rate save now calls the existing `MarkCostDefinitionForecastReady` after creating or repairing the Hotel-owned generic usage inputs. `validate_ready!` is unchanged.

The Hotel-owned occupancy profile is deliberately anonymous. It uses the blocked-room count as `resource_unit_count` and repeats the `Hotel guest` category across occupancy positions 1 through the room category's `maximum_occupancy`. This satisfies the generic `resource_nights` / `occupancy_position_nights` model without introducing Traveler identity or a Hotel-specific cost table. A renamed profile, a second profile, or another occupancy shape is Advanced Supplier planning and is not silently repaired.

The `$4,156` figure on the Supplier-rates page remains the **base contracted-block preview** from ephemeral probe inputs. It is not the authoritative departure forecast total once occupancy-position supplements participate in the persisted anonymous profile.

## 12. Fail closed

The typed editor recognizes only the closed shape in §4. Advanced Supplier cost planning remains authoritative for every other shape. Opening or saving the page must not repair the graph, and it must not repair an inventory graph Slice 3A.2 already reports as unsupported.

Fail closed when a category/night has:

- more than one cost source for the same Item, Occurrence, and Resource;
- more than one contracted definition on a source;
- a source with no Occurrence;
- more than one `resource_nights` base;
- more than one component for the same occupancy position;
- an occupancy position range other than a single position;
- a percentage rate, a minimum-quantity formula, or another calculation kind;
- an `expected_commission` component;
- a commission treatment other than the explicit value the page can show;
- any other component the form would drop.

Supported siblings stay editable when the unsupported fact can be isolated. Show the safe facts read-only and link to the exact Advanced Supplier cost-planning screen.

## 13. Partial setup

Staff may save a known base before the supplements are known. The page distinguishes a known rate, a missing supported term, a known zero, and a term that does not apply because it sits above `maximum_occupancy`.

The canonical fixture is complete when both bases, both supplements, and explicit `noncommissionable` treatment are stored on each recognized night and category. Field entry does not assert that an omitted supplement is inapplicable.

## 14. Identity

Supplier rates uses the Slice 3A.2 route identity: Agency, Departure, Arrangement, `SupplierArrangement#editable_version`, and the Hotel Item by stable id. From that version it uses the recognized inventory Occurrences, Resources, and supported Pools. Name, position, `.first`, and `.last` are not identity.

A second Hotel Item does not contribute rates or quantities to the canonical preview. If the inventory shape is unsupported, Supplier rates does not repair it.

Changing an opening does not alter the stored rate. Changing a rate does not alter the opening.

## 15. Authorization

Typed writes require `manage_departures`, load through `Current.agency`, lock the editable version, and keep each command’s optimistic lock and idempotency. A Viewer may read the page through the existing Composition view permission and cannot save. Another Agency’s identifiers are not found. An activated version with no successor draft is read-only. This slice does not build successor creation.

## 16. Proof

Start from the completed Slice 3A.2 graph: Standard openings 5 and 10, Deluxe openings 2 and 5.

1. Open Supplier rates and create no cost records by rendering.
2. Enter the Standard base as 17300 minor units and the Deluxe base as 22300 minor units.
3. Enter the third-occupant and fourth-occupant supplements as 2000 minor units each.
4. Persist `noncommissionable` on each definition and create no `expected_commission` component.
5. Reopen the stored terms. A common supplement field appears only because every supported context stores the same amount.
6. Show Standard illustrations $173 / $173 / $193 / $213 and Deluxe illustrations $223 / $223 / $243 / $263, bounded by maximum occupancy 4.
7. Show the November 4 base block as $1,311, the November 5 base block as $2,845, and the pretax contracted-room total as $4,156, each from one billable night. A two-night evaluation is not that result.
8. Show that those page figures come from the probe. A complete supported save also persists the Hotel-owned anonymous forecast inputs and marks the contracted definitions ready through the existing readiness command.
9. Changing one category’s rate does not rewrite the other category, the Pools, Pool evidence, or the Stay.
10. Changing a Pool quantity changes the derived block preview and does not rewrite rates or the Slice 3A.1 deposit basis.
11. A different supported rate on November 5 is preserved and displayed as a nightly variation.
12. A stale lock on an unchanged definition rejects the whole submission and leaves the other requested rate unchanged.
13. An invalid submission rolls the typed rate save back and redisplays the submitted values.
14. An unsupported cost graph stays unchanged and links to Advanced Supplier cost planning.
15. A second Hotel Item stays isolated.
16. A Viewer cannot save. Another Agency’s identifiers are not found. An activated version is read-only.
17. No Client price, Agreement term, deposit requirement, Destination Fee, quoted-tax illustration, Reservation, or Hotel-specific cost table is created. Only the Hotel-owned generic usage assumption, `Contracted rooms` occupancy profile, and anonymous positions required by the Review and Activation amendment are added.

Supplier rates meets the interface contract at 375, 768, reference desktop, and 1280 pixels: skip link, landmarks, headings, visible focus, keyboard order, accessible names, and validation associated with the field.

## 17. Non-goals

Client Hotel prices, Package pricing, quoted tax exposure, Destination Fee and its waiver, deposit requirements, the deposit-basis UI, deadlines, attrition, early departure, November 1–3 availability, cancellation, refund clarification, Supplier payments, Reservations, room assignments, named Traveler occupancy, actual pickup, folios, settlement, successor presentation, `occurrence_role`, and a generalized cross-vertical rate abstraction. The accepted Hotel Review and Activation amendment is the authority for the narrow Hotel-owned forecast-readiness inputs now written by this page.

## 18. Exit

Staff can record and resume the Hilton Supplier-rate schedule and the page can answer:

```text
Standard: $173 / $173 / $193 / $213
Deluxe:   $223 / $223 / $243 / $263

Nov 4 base block: $1,311
Nov 5 base block: $2,845
Current pretax contracted-room total: $4,156

Commission: Net and noncommissionable
```

No Client price, Agreement term, deposit requirement, Reservation, payment, or Hotel-specific parallel cost record is created.

This exit authorizes Slice 3A.3 only. Hotel Supplier rates are shipped. [Hotel Agreement](hotel-agreement.md) is Shipped 2026-10-01. [Hotel Review and Activation](hotel-review-and-activation.md) is Shipped 2026-10-02. [Hotel Lifecycle](hotel-lifecycle.md) is Shipped 2026-10-02.


---

## Amendment — 2026-10-02 forecast-readiness integration

The accepted [Hotel Review and Activation](hotel-review-and-activation.md) amendment supersedes the earlier statements in this document that the typed Hotel rate save writes no usage assumption, occupancy profile, or forecast-ready transition.

The supported Hotel-owned forecast shape is intentionally narrow:

- one usage assumption for the exact Hotel Item, inventory-night Occurrence, and room-category Resource;
- `expected_billable_nights = 1`;
- no scalar `expected_resource_units` or `expected_persons`;
- exactly one profile labeled `Contracted rooms`;
- profile `resource_unit_count` equal to the current blocked-room quantity;
- one anonymous `Hotel guest` participant category repeated across occupancy positions `1..maximum_occupancy`;
- `MarkCostDefinitionForecastReady` with provenance `Hotel contracted rate workspace`.

The typed room-inventory editor keeps this owned profile's blocked-room count and anonymous-position list synchronized when room quantity or maximum occupancy changes. A second profile, a renamed profile, or another non-owned usage shape is Advanced Supplier planning; the Hotel path does not overwrite it.
