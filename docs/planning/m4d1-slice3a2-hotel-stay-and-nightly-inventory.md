# M4D.1 Slice 3A.2 — Stay and nightly inventory

**Status:** Accepted 2026-09-30 and implemented. This is the only Slice 3A.2. It is the authorized implementation for the Hotel stay and nightly inventory. Hotel UI slices 3A.3–3A.6 remain unauthorized until their own accepted plans name that work.

**Parent:** [M4D.1 Slice 3A — Hotel Supplier Composition](m4d1-slice3a-hotel-supplier-composition.md), §6–§8 and §23.

**Prerequisite:** [Slice 3A.1](m4d1-slice3a1-hotel-supplier-term-persistence.md) is merged and its compatibility proof is green. Pin that `main` SHA before implementation.

**Canonical fixture:** [Hilton Fort Lauderdale Marina 2027](fixtures/hilton-fort-lauderdale-marina-2027-canonical-scenario-draft.md).

**Scope:** The first Hotel UI. Staff establish and reopen one Hotel Item’s guest stay and its date-varying nightly room supply through shipped Supplier commands.

This acceptance does not amend the §23 order. Slice 3A.3 remains Supplier rates and economics. Slice 3A.4 remains Agreement and operational requirements. Slice 3A.5 remains Review and activation. Slice 3A.6 remains lifecycle and closure. The discarded Agreement draft is not this slice and is not a 3A.4 plan.

---

## 1. Goal

Staff can establish and reopen one Hotel Item’s guest stay and its date-varying nightly room supply from Departure Composition. The persisted graph is the parent’s §6.2 graph. The page shows 22 contracted room nights as the sum of four Pool openings. That total is derived. It is not stored, and it is not described as 22 physical rooms, 22 sold rooms, 15 rooms on each night, or one opening quantity for the whole stay.

Slice 3A.2 establishes the Hotel’s temporal and inventory graph. Slice 3A.3 assigns Supplier economics to that graph.

## 2. Sequence

| Slice | Scope |
| --- | --- |
| **3A.1** | Supplier-term persistence foundations. Implemented. |
| **3A.2** | Stay and nightly inventory. This plan. |
| **3A.3** | Supplier rates and economics. |
| **3A.4** | Agreement and operational requirements. |
| **3A.5** | Review and activation. |
| **3A.6** | Lifecycle and closure. |

## 3. Persisted graph

One capacity-managed lodging Arrangement Item. No `occurrence_role` column. No new tables.

| Fact | Record |
| --- | --- |
| Item name `Pre-cruise hotel stay`, category `lodging`, contracting Supplier as default service provider | `CreateArrangementItem`, then `SetItemCapacityManagement` with `managed` |
| Stay: 2027-11-04 15:00 through 2027-11-06 12:00, `America/New_York` | `CreateServiceOccurrence`. Checkout noon on November 6 stays on this Occurrence |
| November 4 inventory: 2027-11-04 through 2027-11-04, both local times blank | `CreateServiceOccurrence` |
| November 5 inventory: 2027-11-05 through 2027-11-05, both local times blank | `CreateServiceOccurrence` |
| Standard and Deluxe, `maximum_occupancy` 4 | `CreateSupplierResource` |
| Stay × Standard and Stay × Deluxe | `ClassifyCapacityPair` as `not_applicable`. No Pool |
| November 4 × Standard, opening 5 | `ConfigureCapacityPairWithPool`: `pooled`, `inventory_mode` `block`, `measurement_basis` `resource_units`, `proposed_opening_quantity` 5 |
| November 4 × Deluxe, opening 2 | same, quantity 2 |
| November 5 × Standard, opening 10 | same, quantity 10 |
| November 5 × Deluxe, opening 5 | same, quantity 5 |

The inventory date is the Occurrence’s `starts_on` and `ends_on`. A Pool label is not that authority. The four Pools are the only capacity on the Item. November 1–3 are not Occurrences and not Pools.

Correcting one saved opening uses `UpdateCapacityPool` on that Pool. A second `ConfigureCapacityPairWithPool` for a pair that already has a Pool is not the edit path. Correcting the Stay uses `UpdateServiceOccurrence`. Correcting a Resource name or maximum occupancy uses `UpdateSupplierResource`.

## 4. Workspace

Add a Hotel composition surface on the existing Departure Composition shell. Do not add a second application sidebar.

This slice’s local navigation is Overview, Stay, and Room inventory. Overview is a write-free reading of the Stay, the two Resources, and the four openings, including the derived line “2 room categories · 22 contracted room nights.” Supplier rates, Agreement, and Review & activate are not links until their own slices add routes.

Entry is **Add Hotel stay** from the Supplier Arrangement. The stay form collects the contracting Supplier, Item name, arrival date, departure date, check-in time, checkout time, and IANA time zone. Display currency is the Departure operating currency. Saving the stay creates the Item, marks it capacity-managed, and creates the Stay Occurrence. It does not create a Resource, Pool, rate, deposit, deadline, Service Offer, or Package inclusion.

Room inventory shows one card per room category. Candidate nights are derived from the Stay: arrival through the day before checkout. Staff enter each night’s contracted rooms on that category. Saving a blank night records that date only. Reopening one cell does not rewrite the other three openings, the other Resource, or the Stay. The page does not create those nights when it is opened.

## 5. Route identity

Every Hotel route resolves Agency → Departure → Arrangement → exact editable Arrangement Version → Arrangement Item by stable ID. The Item must belong to that authorized version graph. Name, position, `.first`, and `.last` are not identity.

The route does not discover the version by assuming the Arrangement has exactly one draft. It selects the draft version when one exists, otherwise the governing version, and keeps that version’s id for the rest of the request. Later commands reload that id.

If a successor draft already exists, Stay and Room inventory operate on that draft version only. This slice does not build successor creation or the proposed-version presentation. That remains Slice 3A.6.

After activation, these definitions are read-only through the existing draft-only commands.

## 6. Orchestration

Thin Hotel controllers call the shipped commands. There is no `SaveHotelStay` that writes the Item, both nights, both Resources, and all four Pools in one command. A failed inventory save leaves the other openings unchanged and redisplays the submitted invalid value.

The initial Stay action may sequence `CreateArrangementItem`, then `SetItemCapacityManagement`, then `CreateServiceOccurrence`. Each command retains its own authority. Do not invent a new domain command to make that sequence atomic. If the existing command composition can run those three writes in one transaction, do that, so a failure of the Stay Occurrence leaves no Item behind. If it cannot, the UI must show an explicit resumable partial state for the records that committed. That is an implementation choice, not a second domain model.

Each mutation requires `manage_departures`, loads through `Current.agency`, locks the editable version, and keeps the underlying command’s optimistic lock and idempotency. A Viewer may read Overview through the existing Composition view permission and cannot save. Another Agency’s identifiers are not found. Direct model writes are not the Hotel path.

## 7. Fail closed

The typed Hotel surface may edit only the exact subset of generic Supplier graphs it understands. Advanced Supplier planning remains authoritative for every richer shape. Opening or saving the Hotel page must not repair the graph.

When the stored graph cannot round-trip, show the safe facts read-only and link to the exact Advanced Supplier-planning screen. Fail closed when:

- the Item is not capacity-managed;
- the Stay Occurrence has a Pool, a Stay × Resource pair is missing, or a Stay × Resource pair is not `not_applicable`;
- an inventory Occurrence has a local check-in or checkout time;
- a pair is `pooled` without exactly one numeric `block` Pool in `resource_units`;
- a Pool uses another inventory mode or measurement basis;
- an extra Occurrence, Resource, or Pool is present that this form would drop.

Supported siblings stay editable when the unsupported fact can be isolated.

## 8. Proof

Focused service coverage is the existing compatibility graph, not a new persistence model: managed Item, Stay times and zone, blank inventory times, six pair classifications, four openings 5, 2, 10, and 5, and a second Item that does not change those openings.

Request and system coverage for the new pages:

1. Add the canonical Hilton stay and resume it by Item id.
2. Add Standard and Deluxe with maximum occupancy 4.
3. Save November 4 as 5 and 2, then November 5 as 10 and 5, on the room category, each without rewriting the other night.
4. Overview shows Standard 15, Deluxe 7, and 2 categories with 22 contracted room nights, and does not show the forbidden room counts.
5. An invalid quantity leaves the valid openings and the submitted invalid value in place.
6. A second Hotel Item does not change the Hilton openings.
7. A Viewer cannot save. Another Agency’s Item id is not found.
8. An unsupported Pool shape stays unchanged and offers the Advanced destination.
9. Stay and Room inventory meet the interface contract at 375, 768, reference desktop, and 1280 pixels: skip link, landmarks, headings, visible focus, keyboard order, accessible names, and validation associated with the field.

No rate, commission, deposit, deadline, attrition, concession, or refund assertion belongs in this proof.

## 9. Non-goals

Supplier rates, `commission_treatment`, cost components, the $4,156 evaluation, quoted tax, Destination Fee, November 1–3 availability text, deposits, the deposit basis, deadlines, attrition, early departure, cancellation, refund clarification, Review & activate, successor presentation, Client Services, Reservations, Payments, `occurrence_role`, and any new migration.

## 10. Exit

Staff can establish and review the Hilton stay and the 5/2 then 10/5 nightly supply, reopen one category/night without flattening the other, and leave no Client, rate, or agreement record behind.

Slice 3A.3 is then eligible for its own accepted plan. This exit does not authorize it.
