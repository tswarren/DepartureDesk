# ABC Motorcoach supplier compatibility

**Status:** Proof recorded 2026-10-02. Transportation implementation is the Shipped [Transportation Supplier Composition](transportation-supplier-composition.md) plan.
**Location:** `docs/planning/m4-offers-and-pricing/abc-motorcoach-supplier-compatibility.md`
**Parent:** [M4D.1 Slice 3R](m4d1-slice3r-non-cruise-adapter-boundary.md)
**Authority:** [ADR 0010](../../adr/0010-supplier-capacity-ledger-and-projection.md) for capacity measurement. [ADR 0011](../../adr/0011-supplier-cost-definitions-and-forecast-evaluation.md) for forecast usage. [ADR 0013](../../adr/0013-supplier-operational-commitments-deadlines-exposure-and-ending.md) for Deposit Requirements and Deadlines. [ADR 0015](../../adr/0015-supplier-agreement-operational-boundary.md) for agreement-reference kinds.
**Prerequisites:** The [ABC Motorcoach Transportation walkthrough](abc-motorcoach-transportation-staff-walkthrough.md) is Accepted 2026-10-02. The [ABC fixture](../fixtures/abc-motorcoach-2027-canonical-transportation-scenario-draft.md) is Approved 2026-10-02.
**Proof:** [test/services/abc_motorcoach_supplier_compatibility_test.rb](../../../test/services/abc_motorcoach_supplier_compatibility_test.rb)
**Does not authorize:** A Transportation screen, route, migration, new domain model, new agreement-reference kind, capacity conversion between `resource_units` and `traveler_positions`, a usage/pool synchronizer, or a Transportation confirmation freeze.

---

## 1. Purpose

Prove the Approved ABC Motorcoach charter against shipped Supplier commands, and record which facts fit and which do not. This gate follows the Hotel persistence-proof pattern. A rejection or a missing distinction is a result. Free-text description, notes, or reference notes do not count as a fit.

The walkthrough remains workflow authority. The Shipped [Transportation Supplier Composition](transportation-supplier-composition.md) plan resolves the gaps below and authorizes that Transportation Agreement workspace.

## 2. What the proof builds

One ABC Arrangement on an active Smith Family Reunion departure, USD, America/New_York:

- Two `ground_transportation` Items, Hotel → Port and Port → Airport, each with one Occurrence at the fixture local time.
- One Resource per segment. `maximum_occupancy` stores 15. Passenger spaces are computed in the proof as confirmed coaches times 15. The proof does not persist a second Pool that converts `resource_units` into `traveler_positions`.
- One `block` Pool per segment, measurement `resource_units`, unit label `motorcoaches`, opening quantity 1, with evidence. A later confirmed coach on Hotel → Port is one `increased` capacity event. Port → Airport stays at 1.
- One contracted cost source per segment: `unit_rate`, quantity basis `resource_units`, $200 and $175. Forecast usage is `expected_resource_units` equal to the confirmed coach count.
- Two item-scoped Deposit Requirements of shape `quantity_times_rate`, plus one `cumulative_target` whose contributors are those two definitions, due 2027-11-03, date only.
- Two `final_count_due` Deadlines, date only, 2027-11-03 and 2027-11-10, each covered by its segment Item.
- No Airport → Port Item. No Client price. No traveler row. Cancellation and the post-November 3 coach payment stay absent. The proof does not record Reviewed — none.
- One successor. Both segment Item ids survive.

The proof also attempts an `on_request` quantity and a Supplier confirmation on the transportation-only draft.

## 3. Result

Recorded from [test/services/abc_motorcoach_supplier_compatibility_test.rb](../../../test/services/abc_motorcoach_supplier_compatibility_test.rb). The proof passed: 1 run, 74 assertions. Transportation screens stay unauthorized. A later implementation plan decides any foundation amendment.

**Coach quantity and passenger spaces. Fit for the stored pair.** Each segment Resource stores `maximum_occupancy` 15. Each segment has one `block` Pool measured in `resource_units`, unit label `motorcoaches`, opening quantity 1. Passenger spaces are derived in the proof as coaches times 15: 15 at opening, and 30 after the Hotel → Port pool quantity is 2. No `traveler_positions` Pool is stored. Whether reusing `maximum_occupancy` for passengers per coach is acceptable remains an open decision for the implementation plan.

**On-request ceiling. Named incompatibility: no numeric home beside the block.** An `on_request` Pool with quantity 2 is rejected: “Nonnumeric pools cannot include a proposed opening quantity.” A second Pool on the same pair, even with no quantity, is rejected: “This capacity pair already has a Pool.” “Up to 2” and “45 passengers” therefore have no shipped numeric home. This pass adds no column. Because the ceiling Pool cannot be attached, the segment deposit reads only the block Pool.

**Per-coach cost while the version is draft. Fit for the two stored facts.** Contracted `unit_rate` components on `resource_units` forecast $375 when each segment’s `expected_resource_units` is 1. Raising only Hotel → Port usage to 2 forecasts $575. Increasing the Hotel → Port Pool to 2 while usage stays 1 leaves the forecast at $375. This pass adds no synchronizer.

**Post-activation coach quantity. Named incompatibility: confirmed vehicle quantity does not drive contracted Supplier exposure.** An `increased` capacity event requires an activated version. Ordinary cost edits, including `expected_resource_units`, require a draft version. After activation, confirming another coach changes controlled capacity and leaves the contracted forecast at the draft usage quantity.

**November 3 commitment. Named incompatibility: the shared amount is not one cumulative target.** The two `quantity_times_rate` children evaluate to $200 and $175. Their sum is $375, and those segment amounts stay visible. After the Hotel → Port Pool quantity is 2, both children still evaluate to $200 and $175, because `capacity_pool_units` on that shape reads `established_opening`, not the later `increased` event. A fixed `cumulative_target` of $375 cannot name those children: “Fixed cumulative targets do not use contributor links.” The contributor-capable parent is quantity-derived and has one rate. Probed at the Hotel → Port rate of $200, it previews to $25 and, after the Pool quantity is 2, materializes to $225, not $575. The shared due date can stay distinct from the Deadlines: all three deposit definitions are date-only on 2027-11-03, and the two `final_count_due` Deadlines are separate records on 2027-11-03 and 2027-11-10.

**Final-count Deadlines. Fit.** Each segment Item covers its own date-only `final_count_due` Deadline. The definitions carry no coach quantity. Activation materializes both occurrences and opens no deadline commitment. Coach quantity is unchanged.

**Pickup and drop-off. Named incompatibility: no general structured endpoints.** The fixture’s pickup and drop-off are operational segment facts. `departure_port_name` and `return_port_name` are the Cruise sailing exception, and non-Cruise forms do not show them. The proof wrote the ABC endpoints into those columns. That write is not a fit. `name` and `description` are not a fit either.

**Pickup time. Named incompatibility: a known start requires an invented end.** Local start and local end must both be present or both be absent. The fixture has 10:00 a.m. and 9:30 a.m. pickups and no contractual drop-off. The proof stored 11:00 and 10:30 so the rows would save. Those end times are not charter facts.

**Confirmation freeze. Named incompatibility: generic confirmation freezes no Transportation agreement facts.** `SupplierConfirmation` on this transportation-only draft does not freeze definitions. A coach occupancy update, a rate update, a deposit update, and a deadline update all succeed afterward. Lodging confirmation freeze matches `category = 'lodging'` only. The Accepted walkthrough treats Supplier confirmation as freezing the reviewed Transportation agreement. This pass does not copy the lodging trigger.

**Successor. Fit.** One successor keeps both segment Item ids.

**Absent facts. Fit as absence.** The proof stores no Airport → Port Item, no Client price, no traveler row, no cancellation reference, and no post-November 3 coach-payment reference. It does not record Reviewed — none.
