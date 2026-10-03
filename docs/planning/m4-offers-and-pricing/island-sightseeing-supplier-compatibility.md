# Island Sightseeing supplier compatibility

**Status:** Proof recorded 2026-10-02. The [Port Promotions fixture](../fixtures/port-promotions-island-sightseeing-2027-canonical-scenario.md) is Approved 2026-10-02. The [Activity walkthrough](island-sightseeing-activity-staff-walkthrough.md) is Accepted 2026-10-02. [Activity Supplier Composition](island-sightseeing-activity-supplier-composition.md) is Shipped 2026-10-02. This pass remains the persistence evidence and authorizes no Activity code.
**Location:** `docs/planning/m4-offers-and-pricing/island-sightseeing-supplier-compatibility.md`
**Parent:** [M4D.1 Slice 3R](m4d1-slice3r-non-cruise-adapter-boundary.md)
**Authority:** [ADR 0010](../../adr/0010-supplier-capacity-ledger-and-projection.md) for capacity measurement. [ADR 0011](../../adr/0011-supplier-cost-definitions-and-forecast-evaluation.md) for forecast usage. [ADR 0013](../../adr/0013-supplier-operational-commitments-deadlines-exposure-and-ending.md) for Deadlines and amount due. [ADR 0015](../../adr/0015-supplier-agreement-operational-boundary.md) for agreement-reference kinds.
**Prerequisites:** The fixture date was checked 2026-10-02 against the Approved Hilton checkout on November 6, 2027 and the Celebrity sailing of November 6–13, 2027. At the time of this proof there was no Accepted Activity walkthrough. The walkthrough is Accepted 2026-10-02. Activity Supplier Composition is Shipped 2026-10-02.
**Proof:** [test/services/island_sightseeing_supplier_compatibility_test.rb](../../../test/services/island_sightseeing_supplier_compatibility_test.rb)
**Does not authorize:** An Activity screen, route, migration, new domain model, new agreement-reference kind, a minimum that is not a guaranteed charge, or Activity code. This pass did not Approve the fixture. Approval and implementation authority are the Accepted walkthrough, the Approved fixture, and the Shipped Activity Supplier Composition plan.

---

## 1. Purpose

Prove the Port Promotions Island Sightseeing scenario against shipped Supplier commands, and record which facts fit and which do not. A rejection or a missing distinction is a result. Free-text description, notes, or reference notes do not count as a fit.

No Activity walkthrough existed when this proof was recorded. This gate does not decide the workflow. The Accepted walkthrough and Activity Supplier Composition plan now do.

## 2. What the proof builds

One Port Promotions Arrangement on a Smith Family Reunion departure, USD, sailing window November 6–13, 2027, departure time zone America/New_York:

- One `activity_attraction` Item, Island Sightseeing, and a second Activity Item used only to probe activation.
- One Occurrence on November 8, 2027, 9:30 a.m. to 3:00 p.m., `America/Nassau`, with origin and destination both set to CocoCay, Bahamas.
- One Participant Resource with no `maximum_occupancy`.
- One `block` Pool measured in `traveler_positions`, opening quantity 40.
- One contracted `unit_rate` on `persons` at $50. Forecast usage is `expected_persons`.
- A temporary `minimum_quantity_shortfall` of 5, removed after the forecast is read.
- Three date-only Deadlines on November 1, 2027: `final_count_due`, `cancellation_cutoff`, and `other` labeled Minimum-enrollment review.
- A `quantity_times_rate` deposit probe against the 40-space Pool, rolled back so no deposit remains.
- One item-scoped `cancellation` agreement reference.
- Supplier confirmation, then activation after the unfinished second Item is removed, then one successor.

No Client price. No traveler row. No inclusion components. No advance deposit left in place.

## 3. Result

Recorded from [test/services/island_sightseeing_supplier_compatibility_test.rb](../../../test/services/island_sightseeing_supplier_compatibility_test.rb). The proof passed: 1 run, 43 assertions. Activity screens stay unauthorized. `expected_persons` is a forecast assumption. It is not confirmed enrollment, and it must not become the contractual payable quantity.

### Fits

- The Supplier and the Item are `activity_attraction`. “Excursion” stays product language. There is no `excursion` category. Meal is not this proof; `dining` remains a separate shipped category.
- One Occurrence stores November 8, 2027, 9:30 a.m. and 3:00 p.m., in `America/Nassau`. Both times are fixture facts. The five-hour-thirty-minute duration is the difference of those times. The departure time zone stays America/New_York.
- `origin_name` and `destination_name` both store CocoCay, Bahamas. That is a coarse place name, not a meeting-point record. The unresolved port meeting point is not stored. This pass adds no location column. The walkthrough decides how to show “Location: CocoCay, Bahamas” and “Meeting point: Not provided” so the screen does not present those endpoints as an exact pickup.
- One `block` Pool measured in `traveler_positions` stores opening quantity 40. The Resource does not use `maximum_occupancy` for the group size.
- One contracted `unit_rate` on `persons` stores $50. `expected_persons` of 5, 4, 20, and 40 forecasts $250, $200, $1,000, and $2,000. With usage at 4, the Pool remains 40 and the forecast stays $200. Those figures are forecast illustrations only.
- November 1, 2027 can be three separate Deadline records: `final_count_due`, `cancellation_cutoff`, and an `other` Deadline labeled Minimum-enrollment review. The final-count Deadline has no commitment line. Those three records do not include a full-payment due action.
- The successor keeps the Island Sightseeing Item id.
- The proof stores no Client price, no traveler row, no inclusion component, and no advance deposit. The included transportation, guide, admissions, and taxes, and the excluded gratuities, are not separate Supplier cost components.

### Named incompatibilities

1. **Operating minimum and Supplier disposition have no shipped structured home.** This is the Activity design-driving gap. The missing fact is minimum operating enrollment of 5 persons, and below that threshold Port Promotions decides whether to operate. That later outcome is: below five, ask Port Promotions, and the Supplier chooses operate or cancel. The fixture requires that decision to be recorded. It is not capacity, cost, a Deadline, cancellation policy, or generic agreement prose alone. Adding `minimum_quantity_shortfall` of 5 while `expected_persons` is 4 changes the forecast from $200 to $250. The fixture requires $200 when the Supplier elects to operate below five, so that component is minimum billing and is incompatible. The proof removes it, and the forecast returns to $200. The review Deadline can schedule November 1 and cannot store the threshold or the discretion. This pass adds no generic minimum field. The walkthrough must settle whether the threshold and the operate-or-cancel outcome are reusable before any persistence.

2. **The November 1 full-payment amount has no authoritative confirmed-participant quantity.** The fixture says pay $50 for each confirmed participant. Controlled spaces of 40, `expected_persons`, and the operating minimum of 5 are each a different fact, and none is confirmed enrollment. Supplier Composition does not own that count. Client Trip and Reservation work are not shipped. A `quantity_times_rate` deposit on the Pool, at $50, previews quantity 40 and $2,000. That probe is rolled back, and no deposit definition remains. A deposit is not this full-payment requirement. `SupplierAmountDueDefinition` reads a capacity-backed `resource_units` component, so it cannot attach this per-person rate. Do not extend amount due to read `expected_persons`. The dollar amount stays unresolved until an accepted enrollment source exists.

3. **The full-payment due action has no shipped typed Deadline home.** The fixture’s full payment is due November 1, 2027. That date is a contractual action, separate from the unresolved dollar amount. There is no `payment_due` Deadline type. `deposit_due` would misname a full payment that is not an advance deposit. An `other` Deadline could retain a label and a date, and this pass does not treat a label-only `other` row as proof of payment semantics. The proof does not create one. The walkthrough must decide whether a general Supplier payment-due Deadline is needed or whether the due date remains part of a later amount-due or payment-requirement concept. Until that decision, the first Activity slice must not present November 1 as a proved payment-due action.

4. **Cancellation wording is not the below-minimum decision.** An item-scoped agreement reference of kind `cancellation` stores the non-cancellable sentence. That wording does not record “ask Port Promotions, then operate or cancel.” The proof does not record Reviewed — none.

5. **Per-person rate inclusions and exclusions have no shipped structured home.** The $50 includes transportation, guide services, admissions, and taxes, and it excludes gratuities. Those are explanatory Supplier contract terms, not additional Supplier cost components. Notes are not a structured fit. No shipped agreement-reference kind is appropriate for that sentence. The kinds in use are deposit derivation, attrition, deposit refund, destination fee, additional nights, early departure, and cancellation. This pass adds no kind. The fixture’s later proof expects Staff to record the rate and its inclusions. The walkthrough must decide whether those terms need version-owned agreement wording or may remain outside the first typed Activity slice.

6. **Activity Supplier confirmation has neither freeze semantics nor a safe typed version-wide confirmation boundary.** Supplier confirmation does not freeze the Activity Occurrence. Activation is refused while another Activity Item on that version has no Occurrence, Resource, capacity declaration, or Item-level cost source. After that unfinished Item is removed, activation succeeds. `SupplierConfirmation` is exact-version-wide. A typed Island Sightseeing confirmation that reviewed only one Item could therefore freeze Hotel or Transportation facts on the same version. That mixed-version effect is the version-wide confirmation fact already remediated for Transportation, together with this proof’s unfinished-sibling activation refusal. This pass did not execute a mixed Hotel-and-Activity confirmation. The walkthrough must require every retained Item to be a supported Activity Item that passes review, or route a mixed version to Advanced Supplier planning. The Activity screen must not record confirmation after reviewing only one Item. This pass adds no freeze.
