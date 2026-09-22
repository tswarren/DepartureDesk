# M4D.1 Slice 2A.1 — Cruise sailing and cabin inventory

**Status:** Shipped 2026-09-22. Implementation authority for M4D.1 Slice 2A.1 only (parent Stop points A–B). Parent [M4D.1](m4d1-departure-composition-workspace.md) remains Accepted for later slices. This plan is the **sole shipped authority** for typed Cruise sailing and cabin inventory. Slice 2A.2 (Supplier rates and occupancy totals), later typed adapters, Client connection, and M4E remain unauthorized until named.

**Parent authority:** [M4D.1 — Departure Composition Workspace](m4d1-departure-composition-workspace.md), especially §§11–12, 19–20, and the Slice 2A.1 delivery contract in §21.

**Implementation base:** [`6c56566`](https://github.com/tswarren/DepartureDesk/commit/6c56566) (merge of [PR #126](https://github.com/tswarren/DepartureDesk/pull/126) — shipped M4D.1 Slice 1 Composition workspace). Implementation landed after Accept merge [`dab634b`](https://github.com/tswarren/DepartureDesk/commit/dab634b).

**Scope locked:** Stop points A and B only — typed Cruise sailing setup and cabin-category inventory over generic M3. This plan does not authorize Slice 2A.2 rates, occupancy profiles, deposits/deadlines adapters, Client Service connection, Client prices, Package scenarios, or Vineyard acceptance.

```mermaid
flowchart LR
  accept["Accept 2A.1"] --> suppliers["Composition Suppliers"]
  suppliers --> sailing["CreateCruiseSailingSetup"]
  sailing --> workspace["Typed Cruise workspace"]
  workspace --> cabin["CreateCruiseCabinCategorySetup"]
  cabin --> graph["Generic M3 graph"]
```

## 1. Outcome

A Staff user can start from Composition → Suppliers and record the minimum truthful structure for the Smith Family Cruise:

1. Save the cruise agreement and sailing.
2. Add cabin categories one at a time.
3. Record how many cabins are blocked, allotted, on request, or Supplier-managed.
4. Leave after either save point and resume without losing context.
5. Continue into the existing advanced Supplier planning when they need capabilities not yet covered by the typed form.

This slice proves that a typed Cruise form can make the generic M3 graph substantially calmer without adding a Cruise domain model.

It does not yet prove the complete Smith pricing workflow.

## 2. Authority and documentation timing

Acceptance of this plan authorized its named implementation work. Exit proof is green.

**Shipping note (2026-09-22):** Composition Suppliers offers typed Cruise sailing and cabin-category inventory over generic M3. Resource definitions carry optional `supplier_code` and `maximum_occupancy`. Slice 2A.2 rates remain unauthorized.

The shipping change set marks this slice shipped and updates the parent, planning index, roadmap, terminology, and `AGENTS.md`.

## 3. Necessary generic persistence amendment

The existing records can represent the sailing and cabin inventory, but two entered cabin facts have no structured home:

- Supplier category code, such as `O1`;
- maximum occupancy, such as `3`.

Add nullable fields to `supplier_resource_definitions`:

| Field | Contract |
| --- | --- |
| `supplier_code` | Optional, blank-to-null, trimmed, maximum 80 characters |
| `maximum_occupancy` | Optional positive integer |

Additional rules:

- `supplier_code`, when present, is case-insensitively unique within one Arrangement version and Item.
- Both fields participate in the existing draft-definition freeze.
- Both copy into successor drafts.
- Neither field belongs on the stable `SupplierResource` identity.
- `maximum_occupancy` is category metadata, not available inventory, an occupancy profile, or Client eligibility.
- `supplier_code` is not a Client rate-category key. Choice-to-rate-category linkage remains Slice 2C/2D work.

This is a generic Resource-definition improvement: it also fits hotel room categories and similar Supplier resource classes. It does not introduce Cruise-specific persistence.

Do not put these facts into `description`, Pool labels, or evidence-reference fields.

**Name mapping (no new columns):** Ship is the Cruise Item definition `name`. Sailing or itinerary name is the sailing Occurrence definition `name`.

## 4. Source-stage and reference omissions

Slice 2A.1 does not add or persist a Supplier proposal/held/contracted source-stage answer. Existing Arrangement state, cost-definition stage, activation, Reservation, and confirmation facts remain authoritative. The typed Cruise entry begins directly with the agreement and sailing facts.

Do not include Celebrity group number `1119999` in this slice’s form.

A Supplier-issued group number belongs in `SupplierIssuedIdentifier` with confirmation provenance. That record is created through the shipped Reservation/confirmation lifecycle. It must not be stored in:

- Arrangement name;
- Item or Resource description;
- Capacity evidence reference;
- a new Cruise reference column.

An optional proposal or contract-document reference remains deferred until the product accepts a truthful generic supporting-material/reference contract.

## 5. User-facing workflow

### 5.1 Composition Suppliers

Add an ordinary primary action:

- **Set up a Cruise**

Keep:

- **Add general Arrangement**
- **Open advanced Supplier planning**

Existing Arrangements that match the supported typed shape may show **Open Cruise setup**. No `arrangement_type` or typed-workflow status is persisted; compatibility is derived from the graph (see §9).

### 5.2 Screen 1 — Agreement and sailing

Use one focused form with these groups.

**Supplier agreement**

- Contracting Supplier
- Arrangement name
- Supplier contact, optional
- Effective service provider, optional when different from the contractor

**Sailing**

- Ship
- Sailing or itinerary name
- Start date
- End date
- Time zone

The form should explain the result in travel-agency language:

> This creates one Supplier arrangement for the cruise and one scheduled sailing. Cabin categories, rates, and deadlines can be added afterward.

Actions:

- **Save sailing and continue**
- **Save and return to Suppliers**
- **Use advanced setup**

After saving, redirect to the typed Cruise workspace and recommend **Add a cabin category**.

### 5.3 Screen 2 — Cruise workspace

Show a compact summary rather than the generic graph:

- Supplier and Arrangement name
- Ship and sailing
- Dates
- Draft, governing, or successor version label
- Cabin-category count
- Current recommended action
- **Advanced Supplier planning**

Sections:

1. Agreement and sailing
2. Cabin categories
3. Supplier rates — link to existing advanced planning until Slice 2A.2
4. Deposits and deadlines — link to existing advanced planning
5. Client-service connection — explicitly later

These are summaries and navigation, not persisted completion states. Costs, deadlines, or deposits already present on the Arrangement do not make the typed workspace incompatible; summarize them and link to advanced planning.

### 5.4 Screen 3 — Add cabin category

Fields:

- Supplier category code, optional
- Category name
- Maximum occupancy, optional
- Inventory treatment
- Cabin quantity, when numeric
- Supplier evidence, optional under the shipped M3B contract

Present inventory modes in Staff language:

| Staff sees | Existing value | Quantity |
| --- | --- | --- |
| Fixed block / held cabins | `block` | Required |
| Replenishable allotment | `allotment` | Required |
| Available on request | `on_request` | Not entered |
| Managed in Supplier system | `externally_managed` | Not entered |

The adapter fixes:

- measurement basis to `resource_units`;
- unit label to `cabins`;
- effective time zone to the sailing Occurrence’s time zone;
- the Occurrence–Resource pair classification to `pooled`.

**Evidence (M3B parity):** Evidence remains optional under the shipped M3B contract. If any ordinary evidence field is entered, the complete evidence tuple is required. Override semantics and permissions remain unchanged. Do not make typed Cruise evidence stricter than advanced capacity planning.

Actions:

- **Save category**
- **Save and add another**
- **Cancel**

Saving one category must not require another category, rates, occupancy profiles, deadlines, Service Offers, or Client prices.

### 5.5 Typed cabin edit — immutable Pool facts

On the ordinary typed cabin edit form, show these as **read-only** after creation:

- inventory mode;
- measurement basis;
- effective time zone;
- supplying Supplier.

If correction is necessary, Staff use an explicit advanced removal/recreation path, subject to existing dependency rules. The typed update command must not silently replace a Pool.

## 6. Durable record mapping

| Entered fact | Durable record |
| --- | --- |
| Contracting Supplier | `SupplierArrangement.contracting_supplier_id` |
| Arrangement name | `SupplierArrangement.name` |
| Supplier contact | `SupplierArrangement.supplier_contact_id` |
| Ship | Cruise `ArrangementItemDefinition.name` |
| Item category | `ArrangementItemDefinition.category = "cruise"` |
| Effective provider | Item default provider or Occurrence override |
| Sailing name | `ServiceOccurrenceDefinition.name` |
| Sailing dates and zone | `ServiceOccurrenceDefinition` timing fields |
| Cabin category | Stable `SupplierResource` plus versioned definition |
| Cabin code | `SupplierResourceDefinition.supplier_code` |
| Category name | `SupplierResourceDefinition.name` |
| Maximum occupancy | `SupplierResourceDefinition.maximum_occupancy` |
| Inventory treatment | `CapacityPool.inventory_mode` |
| Cabin measurement | `CapacityPool.measurement_basis = "resource_units"` |
| Blocked quantity | `CapacityPoolDefinition.proposed_opening_quantity` |
| Cabin unit label | `CapacityPoolDefinition.unit_label = "cabins"` |
| Supplier evidence | Existing Capacity Pool definition evidence fields |

No Service Offer or Package records are created by these screens.

**Naming trap:** Existing `SetupCruiseCabinChoices` and builder `cruise_setup` write **Client Service Offer choice templates**, not Supplier cabin inventory. Typed Supplier routes and commands must remain distinct (`…/cruise/cabin-categories`, `CreateCruiseCabinCategorySetup`). Do not extend Client cabin-choice helpers for Supplier inventory.

## 7. Commands and transaction boundaries

Use four bounded typed commands:

- `CreateCruiseSailingSetup`
- `UpdateCruiseSailingSetup`
- `CreateCruiseCabinCategorySetup`
- `UpdateCruiseCabinCategorySetup`

These are form adapters over generic records. They are not a Cruise domain API.

### 7.1 Composite-command ownership

Typed composite commands may extract reusable generic `*_already_locked!` helpers from shipped commands. Public M3 commands retain their existing behavior. The typed command owns authorization, canonical locks, idempotency, one transaction, optimistic checks, version bump, and audit at its public boundary.

Must **not**:

- call `CreateSupplierArrangement`, commit, then call `CreateArrangementItemSetup` in another transaction;
- chain public Resource, pair, and Pool commands sequentially for cabin create.

### 7.2 Create sailing

`CreateCruiseSailingSetup` creates atomically:

- Arrangement and draft version;
- one Cruise Item and definition;
- one sailing Occurrence and definition;
- provider facts.

Failure leaves none of those records behind.

### 7.3 Update sailing

`UpdateCruiseSailingSetup` updates the Arrangement, Item definition, and Occurrence definition as one section transaction.

It requires the relevant optimistic-lock versions. The contracting Supplier remains immutable.

### 7.4 Create cabin category

`CreateCruiseCabinCategorySetup` creates atomically:

- Supplier Resource and definition;
- pooled Occurrence–Resource classification;
- Capacity Pool and definition.

A Pool validation failure must not leave an orphan Resource.

### 7.5 Update cabin category

`UpdateCruiseCabinCategorySetup` updates the Resource definition and Capacity Pool definition in one transaction.

Inventory mode, measurement basis, effective time zone, and supplying Supplier remain identity-level immutable facts on the ordinary typed path (§5.5). Do not mutate immutable Pool facts around the existing contract, and do not silently replace a Pool.

### 7.6 Shared command guarantees

All four commands must preserve:

- Agency scoping and permission checks;
- canonical lock order;
- section-level idempotency;
- optimistic locking;
- existing audit vocabulary;
- draft-only definition mutation;
- database freeze protection;
- no automatic activation.

A replay returns the already-created section result and emits no duplicate audit events.

## 8. Draft, activation, and successor behavior

- Never-activated Arrangement: edit its draft.
- Active Arrangement with a successor draft: edit the successor.
- Active Arrangement without a successor: show governing Cruise facts read-only and offer **Create successor draft**.
- Activated definitions are never mutated.
- Creating a successor continues to use `CreateSupplierArrangementSuccessor`.
- The new Resource fields must copy into the successor and be covered by the PostgreSQL immutability trigger.
- The typed adapter never activates an Arrangement.

## 9. Open Cruise setup — typed-shape compatibility

**Open Cruise setup** is available when the Arrangement version is compatible. A version is compatible when it has:

- exactly one Arrangement Item;
- that Item has category `cruise`;
- exactly one sailing Occurrence;
- any number of cabin Resources;
- no more than one Pool for each sailing–Resource pair;
- only shapes the adapter can render without discarding information.

Costs, deadlines, or deposits do **not** themselves make it incompatible; the typed A–B workspace can summarize them and link to advanced planning.

This is an adapter boundary, not a domain invariant. The Smith proof shape (one sailing Occurrence) is not a universal cruise-adapter invariant that every future typed cruise must have exactly one Occurrence.

If the graph is incompatible:

- show a readable summary;
- explain that the Arrangement uses an advanced structure;
- link to advanced Supplier planning;
- do not flatten, delete, or silently choose records.

## 10. Locked routes

| Method/path | Purpose |
| --- | --- |
| `GET /departures/:departure_id/composition/suppliers/cruises/new` | New typed Cruise form |
| `POST /departures/:departure_id/composition/suppliers/cruises` | Create sailing setup |
| `GET /departures/:departure_id/arrangements/:id/cruise` | Typed Cruise workspace |
| `GET /departures/:departure_id/arrangements/:id/cruise/sailing/edit` | Edit agreement/sailing |
| `PATCH /departures/:departure_id/arrangements/:id/cruise/sailing` | Update sailing |
| `GET /departures/:departure_id/arrangements/:id/cruise/cabin-categories/new` | New category |
| `POST /departures/:departure_id/arrangements/:id/cruise/cabin-categories` | Create category |
| `GET /departures/:departure_id/arrangements/:id/cruise/cabin-categories/:resource_id/edit` | Edit category |
| `PATCH /departures/:departure_id/arrangements/:id/cruise/cabin-categories/:resource_id` | Update category |

Every controller must load the Departure and Arrangement through `Current.agency`. Cross-Departure and cross-Agency identifiers return not found.

## 11. Acceptance scenario

The minimum Smith proof should demonstrate:

1. Open Smith Family Cruise in Composition.
2. Navigate to Suppliers.
3. Choose **Set up a Cruise**.
4. Select Celebrity, enter Celebrity Beyond, sailing name, November 6–13, 2027, and time zone.
5. Save and leave.
6. Return and see the saved sailing without graph terminology.
7. Add category `O1`, name it `Prime Oceanview`, maximum occupancy `3`, fixed block quantity `8`.
8. Save and leave.
9. Return and see:
   - O1;
   - Prime Oceanview;
   - sleeps up to 3;
   - 8 cabins in the block;
   - rates not yet entered.
10. Open advanced planning and confirm that the same Item, Occurrence, Resource, pair, and Pool are present.
11. Create a successor draft and confirm the category code and maximum occupancy copied correctly.
12. Confirm no Service Offer, choice, price, occupancy profile, deadline, Reservation, identifier, or activation was fabricated.

The user-experience test is simple: Staff should never need to understand Item, Occurrence, Resource, pair, or Pool to complete this path.

## 12. Testing gate

Require focused coverage for:

- atomic sailing creation and rollback;
- atomic cabin-category creation and rollback;
- create-command replay;
- optimistic-lock conflicts;
- Supplier code normalization and scoped uniqueness;
- positive/nullable maximum occupancy;
- numeric versus nonnumeric inventory quantities;
- fixed `resource_units` measurement;
- optional evidence and complete-tuple-when-partial rules;
- typed edit read-only Pool identity facts;
- tenant and cross-Departure isolation;
- inactive Supplier and invalid lifecycle rejection;
- activated-definition immutability;
- successor copying of both new Resource fields;
- Open Cruise setup compatibility predicate and advanced fallback;
- Composition Suppliers → Cruise setup → saved workspace system flow;
- full Docker test, lint, security, and CI system-test gates.

## 13. Explicit non-goals

This slice does not implement:

- Supplier rates or cruise cost compilation;
- occupancy-profile persistence;
- Single/Double/Triple cost totals;
- deposits or deadline adapters;
- Supplier group-number entry;
- source-stage or proposal/contract-document reference fields;
- Service Offer connection;
- cabin Client choices;
- `client_rate_category_key`;
- Supplier-to-Client provenance;
- Client prices or taxes-and-fees compilation;
- Package scenarios;
- proposal sharing;
- documents;
- activation redesign;
- Cruise tables, STI, or an Arrangement type;
- Vineyard acceptance.

## 14. Handoff to Slice 2A.2

Slice 2A.2 begins only after 2A.1 proves the typed adapter can safely write and resume the generic graph, and only when an Accepted 2A.2 plan names that work.

Its scope is narrowly:

- one category’s Supplier rate schedule;
- explicit Single/Double/Triple occupancy-profile confirmation;
- known gross, commission, and net Supplier totals;
- pending figures when some inputs are absent;
- advanced-editor fallback for unsupported contract language.

## 15. Exit criteria

Staff can:

1. Create a typed Cruise sailing from Composition Suppliers without graph vocabulary.
2. Add at least one cabin category with inventory mode and quantity (when numeric) in one atomic save.
3. Leave and resume both save points without losing context.
4. Open Cruise setup only for compatible graphs; incompatible graphs fail open to advanced planning without data loss.
5. Confirm the same M3 records in advanced planning, including successor copy of `supplier_code` and `maximum_occupancy`.
6. Confirm no Client commercial records or activation were fabricated by the typed path.

When exit proof is green, mark this slice shipped in the shipping change set. Until then, implementers treat this Accepted plan as the sole implementation authority for Slice 2A.1.
