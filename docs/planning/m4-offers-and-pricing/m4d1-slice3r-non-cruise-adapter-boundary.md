# M4D.1 Slice 3R — Non-Cruise Adapter Boundary

**Status:** Accepted 2026-09-25. Authority for the layer boundary and delivery order only. Not an adapter contract and not shipped.

**Authority for:** M4D.1 Slice 3R decisions. This acceptance authorizes no adapter code and no Hotel, Transportation, Activity, or mixed-DMC vertical contract.

**Parent:** [M4D.1 — Departure Composition Workspace](m4d1-departure-composition-workspace.md).

**Supersedes:** [Hotel, Transportation, Activity, and mixed-DMC adapter draft](../history/md41-slice3-hotel-transport-etc-adapters-draft.md). That draft is discovery history. `main` never accepted it.

**Implementation prerequisite:** Slice 2D shipped at [`dc272a3`](https://github.com/tswarren/DepartureDesk/commit/dc272a3) (PR #154).

**Next unauthorized boundary:** a Slice 3A Hotel implementation plan. The [Hotel Staff walkthrough](m4d1-hilton-hotel-staff-walkthrough.md) is Accepted 2026-09-27, and the [Hilton fixture](../fixtures/hilton-fort-lauderdale-marina-2027-canonical-scenario-draft.md) is Approved. Hotel implementation remains prohibited until that Slice 3A plan is accepted.

**Prototype:** Unmerged branch `m4d1-slice3-hotel-transport-activity` and PR #156 remain prototype evidence. They are not an implementation source.

---

## 1. What this acceptance decides

Slice 3R locks where non-Cruise Supplier work sits, the order in which that work may be planned, and the rule for extracting shared support. It does not describe a Hotel screen, name Hotel commands, or freeze a Transportation contract.

The test for every later field is: is this a fact about what the Supplier contracted, what the Agency intends to sell, or what this Client selected?

## 2. Three layers

| Layer | Owns |
| --- | --- |
| Supplier Composition | Supplier Arrangements, Items, occurrences, resources, capacity, Supplier costs, deposits, deadlines, and activation readiness |
| Offer Design | Service Offers, Client choices, Client prices, Client terms, Package placement, and publication |
| Client Trip | What a particular Client booked: selections, travelers, quantities, Holds, Allocations, and Charges |

Included versus optional placement is an Offer Design fact. A Client’s selection is a Client Trip fact. Neither is a Supplier Arrangement fact.

Supplier terms are not Client terms. A Supplier adapter may be ready for activation while its Client Service is still unconfigured.

## 3. Delivery order

After this contract:

1. The Hotel walkthrough is Accepted 2026-09-27. Do not revise the discarded Hilton draft on the prototype branch.
2. Draft and accept a short Slice 3A implementation plan derived from that walkthrough.
3. Implement Hotel Supplier Composition.
4. Draft and accept a Transportation walkthrough and its implementation plan.
5. Implement Transportation.
6. Extract shared support only if Transportation repeats the same orchestration.
7. Draft and accept the Activity, Meal, and Excursion workflow.
8. Draft and accept mixed-DMC routing and its integrated proof.

Transportation is not frozen inside Slice 3R. Activity and mixed-DMC walkthroughs wait until those verticals start.

## 4. When shared support may be extracted

Shared support is allowed only when Hotel and a later vertical show the same Staff question, the same shipped command sequence, and the same stable identity.

That extraction may not be a branch on a growing list of family names, and it may not be a universal adapter designed before the repeated proof exists.

`ConnectCruiseServiceOffer` stays Cruise-shaped. The prototype services `TypedItemWrite`, `RecordTypedSupplierComponent`, and `ConnectTypedItemService` are not the extraction source.

## 5. Hotel is the first vertical

The later Hotel contract owns Supplier Composition only. It does not own Client pricing, Package placement, Client Trip selection, or a requirement to create Client choices.

The Accepted Hotel walkthrough has no Client Service connection. Slice 3A must not add a quiet “connected, pricing unconfigured” state. A later separately accepted Offer Design contract may revisit a handoff.

Room quantities, rates, and the Hilton dates are the Approved [Hilton Fort Lauderdale Marina fixture](../fixtures/hilton-fort-lauderdale-marina-2027-canonical-scenario-draft.md). The walkthrough must not revive the superseded illustrative stay.

## 6. What is no longer implementation authority

The generalized Slice 3 approach is not implementation authority. That includes a single plan that ships Hotel, Transportation, Activity, Meal, Excursion, and mixed-DMC adapters together, a common connect-each-Item bridge, and a shared adapter library introduced before Hotel and Transportation have each been proved.

## 7. Exit

This slice is complete. The Hotel walkthrough is Accepted 2026-09-27. Its exit authorizes drafting a Slice 3A plan only.

Hotel implementation remains prohibited until that Slice 3A implementation plan is accepted.
