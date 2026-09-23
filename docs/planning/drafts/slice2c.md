# M4D.1 Slice 2C — Connect Cruise Service, Cabin Categories, and Client Choices

**Status:** Superseded by [M4D.1 Slice 2C](../m4d1-slice2c-cruise-service-connection.md). Historical draft. Not implementation authority.

**Parent authority:** [M4D.1](m4d1-departure-composition-workspace.md), especially §§11, 13, 19, and 21.

**Implementation base:** Green `main` at or after `df16a71` (PR #152), with Slice 2B, 2B-UX, and 2B-UX-R shipped.

**Outcome:** Staff can connect one typed Cruise Supplier Arrangement to one Client-facing Cruise Service, expose selected cabin categories as an exactly-one Client choice, and preserve an exact, stable path from each Client option to its Supplier Resource/Pool support and future Client rate category.

This slice ships Stop E only. It does not author Client prices or compile Client terms.

---

## 1. Locked scope

### In scope

* Connect an existing eligible Service Offer draft, create a new Cruise Service Offer draft, or explicitly decide later.
* Represent one Cruise service with multiple cabin-category source bindings.
* Create and maintain one exactly-one cabin-category choice group.
* Map each cabin option to its exact choice-gated Supplier source binding.
* Persist a durable Client rate-category key on each applicable option.
* Detect and reopen supported Cruise connection graphs without rewriting them.
* Show saved connection/category/choice summaries separately from editing controls.
* Provide Advanced fallback for unsupported Service Offer graphs.
* Add database, command, request, system, accessibility, and responsive proof.

### Out of scope

* Client price components or Supplier-to-Client price copying.
* Client term compilation and scenario Review; those remain Slice 2D.
* Packages or Package placement changes.
* Publication, Sales enabled, Client Trips, Holds, Allocations, or named Client selections.
* Automatically connecting cabin categories created after the connection was saved.
* A parallel Cruise Service, cabin-category, or rate-category domain model.
* Editing arbitrary advanced M4 source topologies through the typed Cruise form.

---

## 2. Product decisions

### 2.1 One Cruise Arrangement Item produces one Client Service

A typed Cruise connection represents the Cruise sailing as one Service Offer.

Cabin categories are choices within that Service—not separate Service Offers.

For example:

* Service: `Celebrity Beyond — 7-Night Eastern Caribbean`
* Choice group: `Cabin category`
* Options: `O1 — Prime Oceanview`, `I1 — Inside`, and other explicitly selected categories

Do not create one Service Offer per cabin category.

### 2.2 Connect flow

Staff choose one of three paths:

1. **Create a new Cruise Service**

   * Create one Service Offer/version/definition.
   * Connect the selected Cruise cabin categories.
   * Create the choice group, options, activations, and rate keys atomically.

2. **Connect an existing Service draft**

   * Eligible only when the Service Offer belongs to the same Agency and Departure.
   * Its current version must be an editable draft.
   * Its fulfillment basis must be `undecided` or a supported Cruise graph that the detector can safely reopen.
   * Published, abandoned, retired, package-owned-incompatible, or unsupported drafts are not silently rewritten.
   * When unsupported, route Staff to Advanced Service Offer editing.

3. **Decide later**

   * Use the shipped `CreateServiceOfferOutline` path to preserve one `undecided` Service Offer draft when Staff confirms the Client-facing title.
   * Do not create Supplier bindings, choices, or rate keys.
   * Reopening Stop E shows that outline as `Not connected`.
   * A later connection resolves that same outline; it must not create a duplicate Service Offer.

### 2.3 Explicit category selection

Staff select one or more currently supported cabin categories.

Saving connects only those selected categories. A later Supplier category does not silently appear as a Client choice. Staff must deliberately edit the connection to add it.

Removing a category is allowed only when its option and rate key have no blocking downstream dependency. Otherwise, explain the dependency and route Staff to the appropriate Client pricing or Advanced Service Offer surface.

### 2.4 Choice topology

The ordinary typed graph contains:

* one Service Offer;
* one Service Offer draft version;
* one `m3_backed` definition;
* one source binding per selected cabin category;
* every category binding marked `choice_gated`;
* one choice group named `Cabin category`;
* `min_selections = 1`;
* `max_selections = 1`;
* one option per selected category;
* one binding activation per option.

An option activates its exact binding. An unselected option activates no binding and later contributes no category-scoped price, attributed Supplier cost, or capacity path.

Do not use M4A alternative fulfillment groups for cabin categories.

### 2.5 Durable rate-category key

Add nullable `service_offer_choice_options.client_rate_category_key`.

For the typed Cruise path, generate an adapter-owned stable key from the stable Supplier Resource identity:

```text
cruise_cabin:<supplier_resource_uuid>
```

The key is not Staff-facing and is not derived only from the editable category label or code. Renaming `O1` must not change the key.

Requirements:

* blank normalized to `NULL`;
* maximum matches `ServiceOfferPriceComponent::RATE_CATEGORY_LIMIT`;
* unique within one Service Offer version when present;
* immutable after the version leaves draft through the existing freeze contract;
* exact key used by later category-scoped Client price components;
* no new rate-category table;
* no key on options that do not select a cabin category.

The UI displays the cabin code/name, not the opaque key.

---

## 3. Persistence and integrity

### 3.1 Migration

Add `client_rate_category_key` to `service_offer_choice_options`.

Add:

* length/shape constraint compatible with the established Client rate-key vocabulary;
* partial unique index on:

  * `service_offer_version_id`
  * `client_rate_category_key`
  * where the key is not null;
* structure/schema proof;
* existing non-draft mutation protection remains authoritative.

### 3.2 Cross-record validation

The typed command must prove that every selected category:

* belongs to the same Agency and Departure;
* belongs to the selected Cruise Arrangement and exact Arrangement version;
* belongs to the Cruise Arrangement Item;
* identifies a supported Supplier Resource;
* identifies the corresponding Occurrence and Capacity Pool where required;
* is compatible with the detected typed Cruise shape;
* appears only once in the submitted graph.

Each generated option must:

* belong to the same Service Offer version as its group;
* activate the matching same-version source binding;
* carry the key derived from that binding’s stable Supplier Resource;
* remain exactly-one reachable through its choice group.

Fail the entire save when any category cannot be connected. Never leave a partial Service Offer or partial choice graph.

---

## 4. Commands and adapters

Lock these public surfaces at Accept.

### 4.1 Mutation commands

#### `ConnectCruiseServiceOffer`

Creates a new connection or resolves an eligible existing/undecided draft.

Inputs:

* Agency and actor;
* Departure;
* Supplier Arrangement and exact version;
* Cruise Arrangement Item;
* connection mode: `new` or `existing`;
* optional existing Service Offer ID;
* Client-facing title and description;
* selected cabin-category Resource IDs;
* Arrangement version lock version;
* existing Service Offer version lock version when applicable;
* idempotency key.

Output:

* connected Service Offer;
* current Service Offer version;
* status: `created` or `connected`.

The command owns one transaction, canonical locks, idempotency, version bumps, and one bounded audit event.

#### `UpdateCruiseServiceConnection`

Updates the selected categories and Client-facing Cruise Service fields for a supported draft connection.

It must preserve stable choice-option and binding identities for retained cabin categories. Match retained rows by stable Supplier Resource—not array position and not editable label.

It must not use the current destructive `UpdateServiceOfferChoices` replacement path where doing so would recreate retained option identities.

Output status: `updated`.

#### Existing command for Decide later

Use `CreateServiceOfferOutline`; do not add a second outline command.

### 4.2 Read adapters

#### `DetectCruiseServiceConnectionShape`

Returns:

* `compatible?`;
* specific unsupported reasons;
* connected Service Offer/version;
* projected Client-facing fields;
* category rows keyed by stable Supplier Resource;
* choice group/options;
* rate keys;
* missing or extra topology;
* Advanced deep link.

Fail closed when the graph contains:

* multiple cabin choice groups;
* non-exactly-one cabin selection;
* shared/duplicate rate keys;
* mismatched option activations;
* unconditional cabin bindings;
* unrelated bindings mixed into the typed graph;
* ambiguous Cruise source ancestry.

#### `CompileCruiseServiceConnectionWorkspace`

Returns the display-oriented Stop E model:

* unconnected / undecided / connected / advanced status;
* eligible existing drafts;
* available cabin categories;
* connected category summaries;
* source and lifecycle labels;
* editability;
* downstream removal blockers;
* Advanced paths.

It performs no writes.

---

## 5. Locking and transaction boundary

Preserve the shipped canonical order:

1. Agency
2. actor reload and permission recheck
3. affected Suppliers in UUID order
4. Departure
5. Supplier Arrangement/version and selected definitions
6. Service Offer/version

The composite command may extract or reuse `*_already_locked!` helpers. It must not call several public commands that each open their own transaction.

For a new connection, the Service Offer, version, definition, bindings, choice group, options, activations, and audit event commit atomically.

For an existing draft, a stale Service Offer or Arrangement version returns a recoverable conflict without changing either graph.

---

## 6. Routes and controllers

Add a dedicated Stop E workspace under the existing Cruise Arrangement route:

```text
GET   /departures/:departure_id/arrangements/:arrangement_id/cruise/service-connection
POST  /departures/:departure_id/arrangements/:arrangement_id/cruise/service-connection
PATCH /departures/:departure_id/arrangements/:arrangement_id/cruise/service-connection
```

Controller:

```text
CruiseServiceConnectionsController
```

Actions:

* `show`
* `create`
* `update`

Use the existing Cruise Arrangement shape gate and `SupplierArrangementAccess`.

Permissions:

* GET requires `view_departures`;
* mutation requires `manage_departures`;
* unpublished Service Offer details remain hidden from Viewers under the shipped M4 contract.

Do not add Package or Client-price routes.

---

## 7. UI and interaction contract

Build Stop E as a dedicated page rather than another large inline editor on the Cruise overview.

### 7.1 Cruise workspace summary

Add a `Client service` panel after Supplier planning:

* status badge: `Not connected`, `Decide later`, `Connected`, or `Advanced`;
* connected Service title;
* category count;
* concise choice sentence;
* primary action: `Connect Client service` or `Edit connection`;
* Advanced link only when needed.

### 7.2 Default connection page

The default page is a readable summary, not an open form.

Connected state shows:

* Service name and Client-facing description;
* Supplier support summary;
* `Cabin category — choose exactly one`;
* one category card or row per connected option:

  * cabin code and name;
  * occupancy/capacity context;
  * Supplier support status;
  * `Client rate category connected`;
* Edit connection;
* Open Service Offer;
* Open advanced sources.

Do not show raw source-binding IDs, membership enums, activation kinds, or rate keys.

### 7.3 Editor

The editor is clearly framed as `Connect Cruise service` or `Edit Cruise service connection`.

Sections:

1. **Connection**

   * Create new
   * Connect existing eligible draft
   * Decide later

2. **Client-facing service**

   * Service title
   * Description

3. **Cabin categories Clients may choose**

   * checkbox/card selection;
   * cabin code/name;
   * occupancy context;
   * Supplier capacity mode/status;
   * clear selected count.

4. **Review**

   * “Create/connect one Cruise Service with N cabin-category choices.”
   * list each option and its Supplier category;
   * warnings and blocking dependencies.

Primary action uses the actual outcome:

* `Create and connect service`
* `Connect existing service`
* `Save connection`
* `Save for later`

Cancel returns to the saved summary without mutation.

Failed saves preserve all entered fields, show an error summary, and focus the first invalid control.

### 7.4 Responsive and accessibility requirements

* One-column editor at narrow widths.
* Category cards may form two columns only when labels and status remain readable.
* Use fieldsets and legends for connection mode and category selection.
* Exactly one visible page heading.
* Status is communicated by text as well as color.
* Keyboard operation requires no drag interaction.
* After success, focus the saved connection summary.
* Turbo navigation must not reopen an editor from stale history state.

Update `docs/ui/interface-contract.md` when the UI ships.

---

## 8. Lifecycle behavior

### Draft Arrangement

A tentative draft Arrangement version may be connected only when explicitly labeled tentative, consistent with M4A. It cannot later satisfy publication readiness until the governing activated source is selected.

### Active Arrangement

Default to the governing activated version. A successor draft remains a separately labeled tentative source and is never selected implicitly.

### Draft Service Offer

Typed connection may create or update it.

### Published or otherwise frozen Service Offer version

Read-only on this surface. Editing requires an accepted successor-draft flow already shipped by M4D or Advanced Service Offer handling. Do not mutate the published graph.

### Supplier changes

Later Supplier category changes never silently rewrite the Client choice graph. The detector reports changed, missing, or unsupported source facts and gives Staff a deliberate recovery path.

---

## 9. Proof

### Service and command tests

* New connection creates exactly one Service Offer.
* Retry with the same idempotency key returns the same Service Offer.
* Different payload with the same key conflicts.
* One selected category produces one choice-gated binding, option, activation, and rate key.
* Multiple categories remain options inside one Service Offer.
* Retained categories preserve binding and option IDs during update.
* Added category receives one new binding/option/key.
* Removed category deletes only its draft children when no dependency blocks removal.
* Removal with a dependent Client price key fails without changing the graph.
* Category rename does not change the durable key.
* Duplicate or cross-version keys fail.
* Cross-Agency, cross-Departure, wrong Arrangement/version, and wrong Item ancestry return not found or invalid as appropriate.
* Draft Arrangement source is explicitly tentative.
* Activated source is selected by default.
* Unsupported existing Service Offer graph remains unchanged and routes Advanced.
* Concurrent Arrangement activation and connection obey lock order without deadlock.
* Stale Service Offer version leaves both M3 and M4 graphs unchanged.
* Compile/detect services write nothing.

### Request tests

* Viewer may see only the authorized Cruise summary, not unpublished Service details.
* Staff can open the connection workspace.
* Existing-draft picker includes only eligible same-Departure drafts.
* Decide later creates or retains one outline and creates no binding/choice graph.
* Invalid submission returns `422` with preserved fields.
* Success redirects with `303`.
* Advanced fallback includes a return path.

### System tests

1. Connect O1 as a new Cruise Service.
2. Connect O1 and I1 as choices within one Service.
3. Reopen and edit without topology or identity loss.
4. Add and remove a category.
5. Connect an existing undecided outline without creating a duplicate Service Offer.
6. Choose Decide later and resume later.
7. Unsupported advanced graph remains readable and unchanged.
8. Keyboard-only flow at narrow and desktop layouts.

### Blocking Smith scenario

Using the Celebrity Cruise fixture:

* one Cruise Service exists;
* O1 is one option in an exactly-one Cabin category group;
* O1 activates the exact O1 Resource/Pool binding;
* O1 carries its stable Client rate key;
* no Client price is invented;
* no second Cruise Service is created;
* the connection can be reopened unchanged.

---

## 10. Delivery sequence

1. Accept this plan and update the parent Slice 2C section with exact commands, routes, persistence, and exit proof.
2. Add the option rate-key migration and integrity proof.
3. Implement the detector/compiler.
4. Implement `ConnectCruiseServiceOffer` with the new and existing-outline paths.
5. Implement identity-preserving `UpdateCruiseServiceConnection`.
6. Add the dedicated Stop E summary and editor.
7. Add request/system/accessibility proof.
8. Update the interface contract and repository indexes.
9. Mark Slice 2C Shipped only after a green merge to `main`.

---

## 11. Exit criteria

Slice 2C is complete when Staff can connect the Celebrity Cruise to exactly one Client-facing Cruise Service, expose O1 and other selected cabin categories as stable exactly-one Client choices, trace every option to exact Supplier support, and reopen or update the connection without duplicate Service Offers or lost option identity.

No Client price, Package decision, publication action, Client Trip, or Supplier-side choice is created.
