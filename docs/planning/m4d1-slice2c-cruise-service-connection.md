# M4D.1 Slice 2C — Connect Cruise Service, Cabin Categories, and Client Choices

**Status:** Shipped 2026-09-23. Sole shipped authority for M4D.1 Slice 2C (Stop E). Parent [M4D.1](m4d1-departure-composition-workspace.md) remains Accepted for later slices. Slice 2D, later M4D.1 slices, M4E, and M5 remain unauthorized until named.

**Ship commit:** [`b35a4f6`](https://github.com/tswarren/DepartureDesk/commit/b35a4f6) (PR #153).

**Supersedes:** Historical notes [slice2c.md](drafts/slice2c.md) and [slice2c-proposed-decisions.md](drafts/slice2c-proposed-decisions.md). Those notes are not implementation authority.

**Parent authority:** [M4D.1](m4d1-departure-composition-workspace.md), especially §§12.5, 13, 19, 20, and 21.

**Implementation base:** Green `main` at or after `df16a71` (PR #152), with Slice 2B, 2B-UX, and 2B-UX-R shipped.

**Outcome:** Staff can connect one typed Cruise Supplier Arrangement to one Client-facing Cruise Service, expose selected cabin categories as an exactly-one Client choice, and preserve a stable path from each Client option to its Supplier Resource/Pool support and to the Client rate category Slice 2D will price.

This slice ships Stop E only. It does not author Client prices, compile Client terms, or change publication readiness.

---

## 1. Locked scope

### In scope

* Connect a new Cruise Service Offer, resolve one eligible undecided outline, or record Decide later.
* Represent one Cruise service with multiple cabin-category source bindings.
* Create and maintain one exactly-one cabin-category choice group.
* Map each cabin option to its exact choice-gated Supplier source binding.
* Mint and preserve a durable Client rate-category key on each cabin option.
* Record which Arrangement Item an outline or connection belongs to, before any source binding exists.
* Detect and reopen a supported Cruise connection without rewriting it.
* Show a saved summary separately from the editor.
* Provide an Advanced fallback for unsupported Service Offer graphs.
* Copy the new rate key when a Service Offer successor draft is created.
* Refuse the older builder cabin-choice helper when it would destroy a typed connection or a Decide-later outline.
* Add database, command, request, system, accessibility, and responsive proof.

### Out of scope

* Client price components, Supplier-to-Client price copying, and scenario Review. Those remain Slice 2D.
* Changing `EvaluateClientPrice`, `EvaluatePackagePrice`, or publication readiness so a null option price effect becomes publishable. Slice 2D owns that amendment.
* Packages, Package placement, publication, Sales enabled, Client Trips, Holds, Allocations, and named Client selections.
* Automatically connecting a cabin category added after the connection was saved.
* Automatically creating a Service Offer successor draft.
* Automatically moving a connection onto a later Arrangement version.
* A parallel Cruise Service, cabin-category, or rate-category table.
* Editing an arbitrary advanced M4 source topology through the typed form.
* A cruise-only check constraint on the shared rate-key column.

---

## 2. Product decisions

### 2.1 One Cruise Arrangement Item produces one Client Service

A typed Cruise connection represents the Cruise sailing as one Service Offer. Cabin categories are choices within that Service.

For example:

* Service: `Celebrity Beyond — 7-Night Eastern Caribbean`
* Choice group: `Cabin category`
* Options: `O1 — Prime Oceanview`, `I1 — Inside`, and other explicitly selected categories

The typed contract owns the group name `Cabin category`. A renamed group is Advanced, even when the rest of the topology still matches.

### 2.2 Three connection paths

Staff choose one of three paths. All three go through `ConnectCruiseServiceOffer` so the Arrangement Item association and the Service Offer commit together. Generic Departure outlines still use shipped `CreateServiceOfferOutline` unchanged. That command does not learn a Cruise item parameter.

1. **Create a new Cruise Service**

   * Create one Service Offer, draft version, and `m3_backed` definition.
   * Claim the Arrangement Item on that offer.
   * Connect the selected cabin categories.
   * Create the choice group, options, activations, and rate keys in the same transaction.

2. **Connect an existing outline**

   The ordinary picker includes only a Service Offer that:

   * belongs to the same Agency and Departure;
   * has an editable draft version;
   * has `fulfillment_basis: undecided`;
   * has no source bindings;
   * has no choice groups, options, or activations;
   * has `owning_package_version_id` null;
   * is not already claimed by another Arrangement Item.

   Existing Client text, timing text, terms, or unscoped draft pricing may remain. The connection preview discloses them. The command does not delete them. Saving sets fulfillment to `m3_backed` and builds the typed graph.

   A Service Offer that already has a supported Cruise connection belongs in Edit, not in this picker. A graph with choices, bindings, package ownership, or any other fulfillment basis is Advanced.

3. **Decide later**

   * Create one `undecided` Service Offer draft, using the same title and description normalization as `CreateServiceOfferOutline`.
   * Claim the Arrangement Item on that offer.
   * Create no source bindings, choice groups, options, activations, or rate keys.
   * Reopening Stop E shows that offer as `Decide later`.
   * A later connection resolves that same offer.

`CreateServiceOfferOutline` alone cannot do this. It has no Arrangement Item, so a later visit cannot tell this cruise’s outline from another undecided Service on the same Departure.

### 2.3 One claim per Arrangement Item

Add a nullable intention on `service_offers`, not a new Cruise table:

| Column | Contract |
| --- | --- |
| `intended_arrangement_item_id` | Nullable UUID. The stable Cruise Arrangement Item this offer outlines or connects. |
| `intended_supplier_arrangement_id` | Nullable UUID. The Arrangement that owns that item. |

Rules:

* Both columns are null, or both are present.
* Composite foreign key `(intended_arrangement_item_id, intended_supplier_arrangement_id, departure_id, agency_id)` references `arrangement_items (id, supplier_arrangement_id, departure_id, agency_id)`.
* Partial unique index on `intended_arrangement_item_id` where it is not null. One Service Offer claims an item.
* The pointer is the stable item, not an Arrangement version and not a definition pin. It does not satisfy publication and it is not an M3 source binding.
* Null to a pair happens only in `ConnectCruiseServiceOffer`, in the same transaction as the offer write. Create, connect-existing, and Decide later all set it there.
* A stored pair cannot change to a different pair.
* Pair to null happens only in `DiscardServiceOfferDraft`, in the same transaction as abandoning that draft, and only when the offer has no published version. Abandon the draft first, then clear the claim. Discarding a successor draft while a published version remains leaves the claim in place.
* `UpdateServiceOfferDraft` and Service Offer parameters do not accept either column.
* PostgreSQL rejects a pair reassignment and rejects clearing the pair while any version is still draft, published, superseded, or retired. Clearing is allowed only when every version of that offer is abandoned.
* The database cannot identify which Ruby class performed the first null-to-pair write. Direct SQL can still set an initial valid pair. The command boundary is the supported writer for that first claim. The trigger covers reassignment and clearing.
* After a typed graph exists, `choice_gated` bindings remain the Supplier support. The pointer remains so a second offer cannot claim the same item.

A second create or Decide later for an item that is already claimed returns a recoverable conflict and offers the existing offer. It does not raise a raw unique-index error and it does not create another Service Offer.

### 2.4 Explicit category selection

On first connection, show every cabin category the selected Arrangement version can support, select those categories by default, and require Staff to review the selection before saving. Staff may deselect any of them.

A category is supported when `DetectCruiseArrangementShape` accepts the Arrangement and the category has the typed cabin pool already required by the cruise workspace: a Pool on the sailing Occurrence, measured in resource units, labeled cabins. A Resource with no such pool is listed as unavailable, with the existing “Inventory not configured” explanation, and cannot be selected.

Saving connects only the submitted categories. A cabin category added later appears as “Available to add.” It does not become a Client choice until Staff save the connection again.

Connecting zero categories fails. Decide later is the path with no cabin choices.

Removing a category is allowed when the option’s rate key has no same-version Client price component. Otherwise the save fails, the graph is unchanged, and the message names the category:

> Remove or retarget the Client price for O1 before removing this cabin choice.

Published and otherwise frozen versions are already immutable. This slice does not scan publication manifests or Package prices for the key. Package bundled prices cannot carry a rate-category selector. The draft-time dependency that exists is `service_offer_price_components.client_rate_category_key` on the same Service Offer version.

### 2.5 Choice topology

The ordinary typed graph contains:

* one Service Offer claimed by the Cruise Arrangement Item;
* one editable draft version;
* one `m3_backed` definition;
* one source binding per selected cabin category;
* every category binding marked `choice_gated`;
* one choice group named `Cabin category`;
* `min_selections = 1` and `max_selections = 1`;
* one option per selected category;
* one binding activation per option;
* `price_effect_minor_units` null on every cabin option.

Each binding pins the selected Arrangement version and the exact Item, sailing Occurrence, Resource, and Pool identities and definitions. An option activates that exact binding. An unselected option activates nothing and later contributes no category-scoped price, attributed Supplier cost, or capacity path.

Cabin categories do not use M4A alternative fulfillment groups.

### 2.6 Durable rate-category key

Add nullable `service_offer_choice_options.client_rate_category_key`.

For the typed Cruise path, mint the key once, in the same insert as the option, from that option’s id:

```text
cruise_cabin:<service_offer_choice_option_uuid>
```

Application records already assign the UUID before insert, so the key and the option are one write. After insert, the stored string is the authority. Later saves do not recompute it from the current option id or from the Supplier Resource.

The key belongs to the Client choice. Replacing or refreshing Supplier support keeps the option, the key, and any later Client price. Renaming the Supplier code or Resource name does not change the stored option name or the key.

Requirements:

* blank normalized to null;
* database check matches the shipped price-component rule: null, or a trimmed non-blank string of at most `ServiceOfferPriceComponent::RATE_CATEGORY_LIMIT` (80);
* the `cruise_cabin:` shape is enforced by the typed command and the detector, not by a check constraint on this shared column;
* partial unique index on `(service_offer_version_id, client_rate_category_key)` where the key is not null;
* the same key may be copied onto a successor version, because uniqueness is per version;
* immutable after the version leaves draft through the existing choice-option freeze;
* an option that does not select a cabin category keeps a null key;
* ordinary UI shows the cabin code and name, not the key.

`OfferVersionGraphCopy` must copy `client_rate_category_key` onto the successor option as a string. Successor options receive new ids. Regenerating the key from the new id would leave copied Client prices pointing at the predecessor key.

A supported successor remains compatible when its stored key still matches `cruise_cabin:` plus a UUID. The detector does not require that UUID to equal the successor option’s id.

### 2.7 Option price effect

Persist `price_effect_minor_units` as null.

Shipped M4D already defines null as “surcharge not entered” and zero as “explicitly included at no extra charge.” Slice 2C does not know that cabin categories have no price difference. Slice 2D will create category-scoped Client prices using the option’s rate key.

A 2C connection is structurally complete and publication-incomplete. `EvaluateServiceOfferPublicationReadiness` and `EvaluatePackagePrice` continue to treat a null effect as incomplete. This slice does not weaken that rule.

### 2.8 Identity-preserving edits

`UpdateCruiseServiceConnection` does not call `UpdateServiceOfferChoices`. That command deletes every group, option, and activation on the version.

Match retained records by stable association:

* option and rate key by the existing option row;
* binding by stable Supplier Resource id;
* activation by the retained option and binding.

For a retained category whose pinned Arrangement version, Occurrence, Resource, Pool, and definition ids are unchanged:

* preserve the option id;
* preserve the stored rate key;
* preserve the binding id;
* preserve the stored option name.

The option name is Client-facing M4 text. Generate it from the Supplier code and Resource name only when the option is created. A later typed save does not rewrite it from current Supplier facts. When those facts differ from the stored name, the summary shows the current Supplier label as source context. An explicit rename or refresh of the Client option name is outside this slice.

A new category’s option name is the Supplier code and Resource name, joined as `O1 — Prime Oceanview` when both exist, otherwise the Resource name. The typed path leaves `client_description` null. A cabin option that already has a client description is Advanced, so a typed save does not wipe it. A stored name that differs from the current Supplier label remains compatible.

For an added category, create one new binding, option, activation, and key. For a removed category, destroy only that draft option, its activation, and its binding after the price-key check.

`service_offer_choice_options` is unique on `(service_offer_choice_group_id, position)`. `service_offer_source_bindings` is unique on `(service_offer_version_id, position)`. Writing a retained row straight to its final position collides when two retained rows exchange positions. Replace both tables inside the one transaction in this order:

1. Destroy removed activations, options, and bindings.
2. Move every retained binding and option to a temporary position above both the current maximum and the final maximum. Compute that base from those maxima.
3. Assign every retained binding and option its final position.
4. Create added rows at their final positions.

The single `Cabin category` group does not change position.

A typed update does not move the binding onto a different Arrangement version. If Staff connected a draft and that same version is later activated, the existing pin remains valid. If a successor Arrangement version exists, the connection stays on the pinned version until a later accepted flow rebinds it. The summary may say that the pin is an earlier Arrangement version. It does not rewrite the pin.

### 2.9 Unsupported graphs

The detector fails closed. Unsupported graphs stay readable, unchanged, and linked to Advanced Service Offer editing. The typed form does not repair them.

`SetupCruiseCabinChoices` still builds a different graph: price effect zero and activation `none`, through the destructive replace command. That helper must refuse when the Service Offer has an Arrangement Item claim or a compatible typed cruise connection, and tell Staff to use the cruise connection page. A graph that helper already created is Advanced.

### 2.10 Published connections

A published or otherwise frozen version is read-only on this surface. If an editable successor draft exists and the detector accepts it, Edit targets that successor. If the successor is unsupported, the page is Advanced.

This slice does not call `CreateServiceOfferSuccessorDraft`. When the shipped Service Offer page can create a successor, the read-only summary links there. Successor editing through the typed form waits until that draft already exists and is compatible.

---

## 3. Persistence and integrity

### 3.1 Migration

Add `client_rate_category_key` to `service_offer_choice_options`.

Add the paired intention columns to `service_offers`.

Add:

* the null-or-trimmed length check on the rate key, matching `service_offer_price_components`;
* the partial unique rate-key index described in §2.6;
* the paired-null check, composite foreign key, and partial unique item claim described in §2.3;
* a PostgreSQL trigger on `service_offers` that rejects pair reassignment and rejects clearing a claim except when every version of that offer is abandoned;
* `db/structure.sql` updated by the migration.

The existing non-draft mutation trigger on choice options covers the new key. No new freeze trigger is required for that column. The intention columns live on the Service Offer root. They are not version-owned definition fields. The claim trigger is what keeps a stored pair stable while still allowing discard to release an unpublished claim.

### 3.2 Cross-record validation

The typed command proves that every selected category:

* belongs to the same Agency and Departure;
* belongs to the selected Cruise Arrangement and the exact Arrangement version being pinned;
* belongs to the Cruise Arrangement Item;
* is a supported cabin Resource with its sailing Occurrence and typed cabin Pool;
* is compatible with `DetectCruiseArrangementShape`;
* appears only once in the submitted graph.

On create and connect-existing, the pinned version is the governing activated version when the Arrangement is active. The labeled tentative draft is used only when Staff explicitly choose it. A draft Arrangement that has never been activated pins its draft and the summary says the source is tentative. A tentative source cannot later satisfy publication until an activated source is selected; this slice does not perform that rebind.

On update, selected categories must belong to the Arrangement version already pinned by the retained bindings.

Each generated option must:

* belong to the same Service Offer version as its group;
* activate the matching same-version source binding;
* carry the key minted from its own id;
* remain exactly-one reachable through the `Cabin category` group;
* keep a null price effect.

On create, the option name is the Supplier code and Resource name, joined as `O1 — Prime Oceanview` when both exist, otherwise the Resource name. A later typed save preserves that stored name. The typed path leaves `client_description` null. A cabin option that already has a client description is Advanced, so a typed save does not wipe it.

`service_offers.name` is the Staff-facing name. `service_offer_definitions.client_title` is the Client-facing title. Shipped M4A updates them separately.

* Create and Decide later initialize both from the entered title, because the offer is new.
* Connect-existing and later updates write `client_title` and `client_description` only.
* The Stop E form does not expose a Staff name, so it does not write `service_offers.name` on an existing offer.

An existing outline’s `client_timing_text`, terms, and price definition are preserved.

Fail the entire save when any category cannot be connected. Leave no partial Service Offer, claim, binding, or choice graph.

---

## 4. Commands and adapters

Lock these public surfaces at Accept.

### 4.1 `ConnectCruiseServiceOffer`

Creates a new connection, resolves an eligible undecided outline, or records Decide later.

Inputs:

* Agency and actor;
* Departure;
* Supplier Arrangement and exact version;
* Cruise Arrangement Item;
* connection mode: `new`, `existing`, or `later`;
* existing Service Offer id when mode is `existing`;
* `use_tentative_draft`, default false;
* Client-facing title and description;
* selected cabin-category Resource ids when mode is `new` or `existing`;
* Arrangement version lock version;
* existing Service Offer version lock version when mode is `existing`;
* idempotency key.

The idempotency payload includes the Departure, Arrangement, exact version, Arrangement Item, mode, existing offer id, tentative flag, title, description, and the ordered selected Resource ids. Same key and payload returns the same Service Offer. Same key and a different payload conflicts. A different key that would claim an item already claimed conflicts without creating a second offer.

Output:

* Service Offer;
* current Service Offer version;
* status: `created`, `connected`, or `outlined`.

The command owns one transaction, canonical locks, idempotency, version bumps, and one audit event. It does not call public `CreateServiceOfferOutline`, `AddServiceOfferSourceBinding`, `UpdateServiceOfferChoices`, or `SetupCruiseCabinChoices`.

### 4.2 `UpdateCruiseServiceConnection`

Updates the selected categories, `client_title`, and `client_description` of a supported draft connection. It does not write `service_offers.name`.

Inputs:

* Agency and actor;
* the claimed Service Offer;
* selected cabin-category Resource ids;
* Client-facing title and description;
* Service Offer version lock version;
* Arrangement version lock version.

Output status: `updated`.

Edits use the optimistic locks. They do not take an idempotency key. A stale Service Offer or Arrangement version returns a recoverable conflict and leaves both graphs unchanged.

### 4.3 `DetectCruiseServiceConnectionShape`

Definition-scoped, write-free compatibility and reconstruction.

Returns:

* `compatible?`;
* specific unsupported reasons;
* connected Service Offer and version;
* projected Client-facing fields;
* category rows keyed by stable Supplier Resource;
* choice group and options;
* stored rate keys;
* missing or extra topology;
* whether the pinned Arrangement version is still the governing activated version;
* an Advanced path.

Fail closed when the graph contains any of:

* more than one choice group, or one group whose name is not `Cabin category`;
* min or max selections other than exactly one;
* a missing, duplicate, or non-`cruise_cabin:` rate key on a cabin option;
* a non-null price effect on a cabin option;
* a client description on a cabin option;
* an activation other than the matching `choice_gated` binding;
* an unconditional or alternative binding mixed into the cabin graph;
* a binding that does not pin this Cruise Item, sailing Occurrence, Resource, and typed Pool;
* bindings or options that do not correspond one-to-one;
* more than one Service Offer claiming or binding the same Cruise Item on a live draft or current published version;
* package ownership;
* ambiguous Cruise source ancestry.

Abandoned versions are history. They are not the live connection.

### 4.4 `CompileCruiseServiceConnectionWorkspace`

Write-free Stop E display model:

* status: `Not connected`, `Decide later`, `Connected`, or `Advanced`;
* the claimed offer when one exists;
* eligible existing outlines for the picker;
* supported cabin categories, unavailable categories, and categories available to add;
* connected category summaries;
* source label: governing activated, or tentative draft;
* a warning when the pin is an earlier Arrangement version than the current governing version;
* editability;
* downstream removal blockers;
* Advanced and, when relevant, successor links.

Workspace discovery:

1. The Service Offer whose intention columns claim this Arrangement Item, if its live draft or current published version is the connection.
2. Otherwise, live drafts and current published versions on the Departure whose source bindings pin this Arrangement Item.
3. Several such offers: `Advanced`.
4. One compatible offer: `Connected`, read-only when the live version is frozen. An editable compatible successor is the edit target.
5. One claimed undecided outline with no graph: `Decide later`.
6. One offer the detector rejects: `Advanced`.
7. None of the above: `Not connected`.

### 4.5 Audit

Emit one new action, `service_offer.cruise_connection_saved`, on the Service Offer subject. Add it to `AuditEvent::ACTIONS` in the same change.

Details may include the Service Offer id, Service Offer version id, Arrangement id, Arrangement version id, Arrangement Item id, and status `created`, `connected`, `outlined`, or `updated`. They do not embed the choice graph, price graph, or rate keys.

Do not also emit `service_offer.created`, `service_offer.source_binding_added`, or `service_offer.choice_updated` for the same save.

---

## 5. Locking and transaction boundary

Preserve the shipped canonical order:

1. Agency
2. actor reload and permission recheck
3. affected Suppliers in UUID order
4. Departure
5. Supplier Arrangement, version, and selected definitions
6. Service Offer and version

The composite command may extract or reuse `*_already_locked!` helpers. Nested helpers do not reacquire earlier locks and do not open their own transactions.

A new connection commits the Service Offer, item claim, version, definition, bindings, choice group, options, activations, rate keys, and audit event together.

Decide later commits the offer, item claim, undecided definition, and audit event together.

A failed save leaves the previous M3 graph and the previous M4 graph unchanged.

---

## 6. Routes and controllers

Add a dedicated Stop E workspace under the existing Cruise Arrangement route:

```text
GET   /departures/:departure_id/arrangements/:arrangement_id/cruise/service-connection
POST  /departures/:departure_id/arrangements/:arrangement_id/cruise/service-connection
PATCH /departures/:departure_id/arrangements/:arrangement_id/cruise/service-connection
```

Controller: `CruiseServiceConnectionsController`

Actions: `show`, `create`, `update`

Use the existing Cruise Arrangement shape gate and `SupplierArrangementAccess`.

Every action, including `show`, requires `manage_departures`. Anyone else receives not found. This slice does not ship a Viewer page or a redacted connection summary. The cruise overview already refuses Viewers by redirecting them; the deposits page does not. Stop E follows the unpublished Service Offer and Composition pattern, not the cruise overview’s pair of permission checks.

The Client service panel belongs on the cruise overview, which Viewers cannot open. Do not add that panel to the deposits page or to any other Viewer-readable surface.

Do not add Package or Client-price routes.

---

## 7. UI and interaction contract

Build Stop E as a dedicated page. The editor is closed by default and is not placed inline among saved cruise cards.

### 7.1 Cruise workspace summary

Add a `Client service` panel after Supplier planning on the cruise overview:

* status text: `Not connected`, `Decide later`, `Connected`, or `Advanced`;
* Client-facing title when status is `Connected` or `Decide later`;
* category count and a concise exactly-one choice sentence when connected;
* primary action: `Connect Client service` or `Edit connection`;
* Advanced link only when the detector rejects the graph.

### 7.2 Default connection page

The default page is a readable summary.

Connected state shows:

* Client-facing title and description;
* the Staff-facing name only when it differs from the Client title, labeled as the Staff name;
* Supplier support summary, including tentative-draft labeling when that is the pin;
* an earlier-version warning when the pin is no longer the governing activated version;
* `Cabin category — choose exactly one`;
* one row per connected option:
  * stored Client option name;
  * current Supplier code and name when they differ from that option name;
  * occupancy and capacity context;
  * Supplier support status;
  * `Ready for category pricing`;
* Edit connection, when the live version is an editable compatible draft;
* Open Service Offer;
* Open advanced sources.

`Ready for category pricing` means the option has a durable rate key. It does not mean a Client price exists.

Do not show raw source-binding ids, membership enums, activation kinds, or rate keys.

### 7.3 Editor

The editor is titled `Connect Cruise service` or `Edit Cruise service connection`.

Sections:

1. **Connection**

   * Create new
   * Connect existing eligible outline
   * Decide later

   Edit mode omits this choice. It updates the claimed draft.

2. **Client-facing service**

   * Client-facing title
   * Description
   * disclosure of an existing Staff name, timing text, terms, or unscoped pricing when connecting an outline
   * no separate Staff-name field; an existing `service_offers.name` stays as it is

3. **Cabin categories Clients may choose**

   * checkbox or card selection;
   * supported categories selected by default on first connection;
   * unavailable categories visible and not selectable;
   * Supplier cabin code and name;
   * occupancy context;
   * Supplier capacity mode and status;
   * selected count;
   * after the first save, unconnected categories labeled `Available to add`.

4. **Review**

   * “Create one Cruise Service with N cabin-category choices,” or the matching connect, save, or decide-later sentence.
   * each selected option and its Supplier category;
   * warnings and blocking dependencies.

Primary action:

* `Create and connect service`
* `Connect existing service`
* `Save connection`
* `Save for later`

Cancel returns to the saved summary without a mutation.

Failed saves preserve entered fields, show an error summary, and focus the first invalid control. Success redirects with `303` and focuses the saved summary.

### 7.4 Responsive and accessibility requirements

* One-column editor at narrow widths.
* Category cards may form two columns only when labels and status remain readable.
* Fieldsets and legends for connection mode and category selection.
* Exactly one visible page heading.
* Status communicated by text as well as color.
* Keyboard operation with no drag interaction.
* After success, focus the saved connection summary.
* Turbo navigation must not reopen an editor from stale history state.

Update `docs/ui/interface-contract.md` when the UI ships.

---

## 8. Lifecycle behavior

### Draft Arrangement

A never-activated draft may be connected and is labeled tentative. It cannot satisfy publication until the governing activated source is selected. This slice does not select that later source automatically.

### Active Arrangement

Default to the governing activated version. A successor draft is a separately labeled tentative source and is selected only when Staff explicitly choose it.

### Draft Service Offer

Typed connection may create or update it while the detector accepts it.

### Published or frozen Service Offer version

Read-only here. Editing uses an already created compatible successor draft, or Advanced handling.

### Supplier changes

Later Supplier category changes do not rewrite the Client choice graph. A Supplier rename does not change a retained option’s stored name or rate key. The summary shows the current Supplier label as source context when it differs. The detector reports changed, missing, or unsupported source facts. Staff add or remove a category by saving the connection.

### Builder helper

`SetupCruiseCabinChoices` refuses while the offer carries an Arrangement Item claim or a compatible typed connection.

---

## 9. Slice 2D handoff

Slice 2C leaves these facts for Slice 2D:

* A selected cabin option’s stored `client_rate_category_key` becomes the evaluation `rate_category` for that selection. `EvaluateClientPrice` does not read choice options today.
* Category-scoped Client price components use that exact key.
* A rate-keyed cabin option with a null price effect is priced by those components. Slice 2D amends publication readiness and package price evaluation so that null effect stays “no option surcharge,” not “incomplete,” once the category price exists.
* Successor copies already carry the key string. Slice 2D must not regenerate it.
* Removing a cabin option stays blocked while a same-version price component uses its key.

---

## 10. Proof

### Service and command tests

* New connection creates exactly one Service Offer and claims the Arrangement Item.
* Retry with the same idempotency key returns the same Service Offer.
* A different payload with the same key conflicts.
* A second create or Decide later for the same item conflicts and leaves one offer.
* One selected category produces one choice-gated binding, option, activation, and rate key.
* The stored key is `cruise_cabin:` plus that option’s id. A later Supplier rename leaves both the stored option name and the key unchanged.
* Multiple categories remain options inside one Service Offer.
* Retained categories preserve binding id, option id, option name, and rate key during update.
* Removing the first of two categories leaves the retained option and binding at position 1 without a uniqueness collision.
* Reversing two retained categories preserves both option ids and both binding ids.
* Replacing the first category with a new category preserves the retained row ids and assigns final positions without a collision.
* Direct SQL that changes a stored item claim to a different pair fails.
* Direct SQL that clears a claim while a draft or published version exists fails.
* `UpdateServiceOfferDraft` cannot write either claim column.
* Connecting an outline whose Staff name differs from its Client title preserves `service_offers.name` and updates `client_title`.
* Create and Decide later initialize both names from the entered title.
* An added category receives one new binding, option, and key.
* A removed category deletes only its draft activation, option, and binding when no price component uses the key.
* Removal when a same-version price component uses the key fails and leaves the graph unchanged.
* Option price effect is null.
* A duplicate or cross-version key inside one version fails.
* Cross-Agency, cross-Departure, wrong Arrangement, wrong version, and wrong Item return not found or invalid as appropriate.
* A draft Arrangement source is labeled tentative.
* An active Arrangement pins the governing activated version unless Staff explicitly choose the tentative draft.
* An unsupported existing Service Offer stays unchanged and routes to Advanced.
* `SetupCruiseCabinChoices` refuses against a claimed or compatible cruise connection.
* `OfferVersionGraphCopy` copies the rate key string onto a new option id, and the detector still accepts that successor.
* Concurrent Arrangement activation and connection obey the lock order without deadlock.
* A stale Service Offer or Arrangement version leaves both graphs unchanged.
* Compile and detect write nothing.
* Discard of an unpublished claimed draft clears the item claim. Discard of a successor while a published version remains does not.

### Request tests

* A Viewer receives not found for every connection action, including `show`.
* The cruise overview’s Client service panel is absent from Viewer-readable pages.
* Staff can open the connection workspace.
* The existing-outline picker includes only eligible same-Departure undecided drafts.
* Decide later creates or retains one claimed outline and creates no binding or choice graph.
* An invalid submission returns `422` with the entered fields preserved.
* Success redirects with `303`.
* The Advanced fallback includes a return path.
* A published connection renders read-only and links to the shipped successor action without creating a successor.

### System tests

1. Connect O1 as a new Cruise Service.
2. Connect O1 and I1 as choices within one Service.
3. Reopen and edit without topology or identity loss.
4. Add and remove a category.
5. Connect an existing undecided outline without creating a duplicate Service Offer.
6. Choose Decide later, leave, and resume that same outline.
7. An unsupported advanced graph stays readable and unchanged.
8. Keyboard-only flow at narrow and desktop widths.

### Blocking Smith scenario

Using the Celebrity Cruise fixture:

* one Cruise Service exists for the Cruise Arrangement Item;
* O1 is one option in an exactly-one `Cabin category` group;
* O1 activates the exact O1 Resource and Pool binding;
* O1 carries its option-minted Client rate key;
* O1’s price effect is null;
* no Client price is invented;
* no second Cruise Service is created;
* the connection reopens unchanged.

---

## 11. Delivery sequence

1. This plan is accepted. The parent Slice 2C section names these commands, routes, persistence rules, and exit proof.
2. Add the rate-key and item-claim migration, claim trigger, graph-copy of the key, and integrity proof.
3. Implement the detector and workspace compiler.
4. Implement `ConnectCruiseServiceOffer` for `new`, `existing`, and `later`.
5. Implement identity-preserving `UpdateCruiseServiceConnection`.
6. Refuse `SetupCruiseCabinChoices` when a typed claim or connection exists.
7. Add the dedicated Stop E summary and editor, and the cruise overview panel.
8. Add request, system, and accessibility proof.
9. Update the interface contract and repository indexes.
10. Mark Slice 2C Shipped after the green merge to `main` at `b35a4f6`.

---

## 12. Exit criteria

Slice 2C is complete when Staff can connect the Celebrity Cruise to exactly one Client-facing Cruise Service, expose O1 and other selected cabin categories as stable exactly-one Client choices, trace every option to exact Supplier support and a durable option-owned rate key, and reopen or update the connection without a duplicate Service Offer or a lost option identity.

No Client price, Package decision, publication action, Client Trip, or Supplier-side choice is created.
