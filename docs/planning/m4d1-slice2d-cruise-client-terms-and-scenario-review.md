# M4D.1 Slice 2D — Cruise Client Terms and Scenario Review

**Status:** Shipped 2026-09-24. Sole shipped authority for M4D.1 Slice 2D (Stops F–G). Parent [M4D.1](m4d1-departure-composition-workspace.md) remains Accepted for later slices. [Slice 3R](m4d1-slice3r-non-cruise-adapter-boundary.md) is the accepted layer and delivery-order decision and authorizes no adapter code. The next unauthorized boundary is the Hotel walkthrough. M4E and M5 remain unauthorized until named.

**Ship commit:** [`dc272a3`](https://github.com/tswarren/DepartureDesk/commit/dc272a3) (PR #154). Deliveries 2D-A, 2D-B, and 2D-C merged with that ship.

**Supersedes:** [M4D1-Slice2D-Cruise-Client-Terms-and-Scenario-Review-Proposed.md](drafts/M4D1-Slice2D-Cruise-Client-Terms-and-Scenario-Review-Proposed.md). That note is not implementation authority.

**Parent authority:** [M4D.1](m4d1-departure-composition-workspace.md), especially Stops F–G and §§13–14, 19, 21, and 23. This plan amends those sections for Agency fee, four-field provenance, zero-or-one Supplier copy, and the null category-option price effect.

**Implementation base:** Slice 2C shipped merge [`b35a4f6`](https://github.com/tswarren/DepartureDesk/commit/b35a4f6) (PR #153).

**Shipped foundations:** M4B Client price definitions, components, bases, `EvaluateClientPrice`, and `EvaluateIndicativeScenarioEconomics`; M3C Supplier cost definitions and forecast evaluators; M4D publication readiness and `EvaluatePackagePrice`; M4D.1 Slice 2A Supplier rate matrix; M4D.1 Slice 2C cabin-option rate keys.

**Outcome:** Staff can select one cabin category in a connected Cruise Service, author its Client-facing price terms in a traveler-position matrix, optionally start compatible cells from Supplier terms, and review Single, Double, and supported Triple economics without equating Supplier cost with Client revenue.

This slice ships Stops F–G only. It does not author Packages, target prices, payment terms, or publication actions. It does amend publication readiness and Package price evaluation so a Slice 2C category option with a null price effect is complete once its category price exists.

---

## 1. Locked scope

### In scope

- Stop F Cruise Client-term authoring for a Service Offer created or connected by Slice 2C.
- One Client price definition on the exact Service Offer version.
- Category-scoped Client components keyed by the selected choice option’s stored `client_rate_category_key`.
- A traveler-position matrix modeled on the shipped Cruise Supplier rate-matrix interaction, including an ordinary Agency fee row. Visible bands come from the connected category’s confirmed Supplier occupancy profiles.
- Independent entry of Client terms.
- Explicit, reviewed copy proposals from compatible Supplier components.
- Durable zero-or-one Supplier provenance, including a frozen mapping snapshot.
- Derived provenance states: independent, unchanged, changed, missing, and unknown.
- Stop G write-free Single, Double, and supported Triple review.
- Known/pending arithmetic that preserves partial useful results.
- The null category-option price-effect amendment in Service publication readiness, Package publication readiness, and Package price evaluation.
- Provenance findings in `EvaluateDepartureBuilderReadiness`.
- Advanced fallback for Client price graphs the typed adapter cannot reconstruct safely.
- Draft/successor behavior, optimistic locking, recovery, authorization, accessibility, and blocking Celebrity proof.

### Out of scope

- Automatic markup, target-price, or target-margin authoring.
- Live synchronization from Supplier terms.
- Copying expected commission or informational allocations into Client revenue.
- Combining several Supplier components into one Client component.
- Percentage, minimum, or shortfall Supplier-copy mappings in the first release.
- Package composition, Package placement, payment terms, cancellation terms, and publication actions.
- The Smith Package inclusion in parent §17.2. That remains later Package work.
- Persisted scenarios, totals, margins, readiness results, recommendations, or capacity snapshots.
- Named Travelers, bookings, Holds, Allocations, Charges, Receipts, Obligations, Payments, or remittance.
- Tax jurisdiction, tax remittance, or statutory classification.
- Replacing the generic Service Offer price editor. It remains the Advanced path.
- Treating a changed Supplier source as a publication blocker.

---

## 2. Locked domain decisions

### 2.1 One price definition, category-scoped components

The Cruise Service retains one `ServiceOfferPriceDefinition` per exact Service Offer version. Slice 2D does not create a definition per cabin category and does not add a cabin-price aggregate.

Each typed matrix cell compiles to an ordinary `ServiceOfferPriceComponent` carrying:

- the selected option’s stored `client_rate_category_key`;
- one supported occupancy-position selector;
- an M4B Client role and calculation shape;
- its independently entered Client amount;
- optional copy provenance.

Staff never enter or see the stored rate key. The durable category scope is the Slice 2C choice option and that stored key.

### 2.2 Category-scoped saves

A typed save for O1 replaces only the typed component subset carrying O1’s rate key. It preserves:

- I1 and other category-scoped components;
- the choice option, source activation, binding, and stored rate key;
- Supplier cost graphs;
- safely separable components outside the selected category.

Unscoped components, other categories’ keys, and any rows the detector cannot partition stay Advanced and untouched. If the existing graph contains generic components, cross-category percentage bases, category keys not reachable through the Slice 2C choices, a `zero_price` definition, or another topology the detector cannot partition without reinterpretation, the definition is Advanced. The typed save never deletes or silently rewrites those rows.

### 2.3 Blank, zero, and pending

- Blank means not entered or not applicable. It never means zero.
- An explicit `0.00` is an entered Client value.
- A missing cell may produce a pending scenario fact without hiding known lines or other complete scenarios.
- The typed matrix does not persist a separate pending row.

### 2.4 Single occupancy

`single` is a traveler-position selector, not an all-in persisted scenario total.

The matrix may contain distinct Single-column components, including Cruise fare, NCCF, taxes and fees, discount, Agency fee, and a separately labeled single supplement. The write-free scenario compiler sums applicable Single-column components. No individual cell is the all-in Single total.

### 2.5 Supplier-copy meaning

“Start from Supplier terms” is an explicit proposal and confirmation flow:

1. Staff choose eligible Supplier components or proposed cells.
2. DepartureDesk displays the source meaning, proposed Client role, target traveler positions, and proposed values.
3. Staff may edit Client-facing labels, roles, and values before saving.
4. Saving creates independently editable Client components.
5. Each Client component has zero or one Supplier provenance source.
6. Later Supplier changes produce findings. They never overwrite the Client component.

One compatible Supplier component may seed several Client cells when its source position range expands into independent target positions. Each resulting Client component points to that same source and stores its own frozen mapping snapshot. Combining several Supplier components into one Client component is deferred.

### 2.6 Recopy and provenance removal

The UI exposes distinct actions:

- **Keep Client term** — retain the Client value and the provenance finding. Do not rewrite the fingerprint, timestamp, or mapping snapshot.
- **Recopy from Supplier** — show a new proposal and, only after confirmation, update that same draft component in place with the proposed Client values, a new mapping snapshot, a new fingerprint, and a new timestamp.
- **Remove source link** — keep the Client component and clear all four provenance fields.
- **Remove Client term** — delete the draft Client component subject to ordinary graph rules.

Recopy is never automatic. Recopy does not insert a second component or keep a provenance history row.

### 2.7 Scenario review

Single, Double, and Triple are transient travel configurations:

- Single: `single`;
- Double: `first`, `second`;
- Triple: `first`, `second`, `additional`.

Each occupancy position receives the selected category option’s stored rate key as `EvaluateClientPrice::OccupancyPosition#rate_category`. `EvaluateClientPrice` does not read the choice option. Each review also supplies the option and exact source binding selected by Slice 2C, one cabin/resource unit, and the matching person count.

Review includes a scenario only when §2.9 enables every band that scenario uses. A Double-only category shows Double and explains why Single and Triple are unavailable. Resource maximum occupancy does not authorize a scenario.

These scenarios are not Supplier occupancy profiles, demand, reservations, or capacity promises.

### 2.8 Null category-option price effect

For a Slice 2C category option, `price_effect_minor_units = NULL` means no separate option surcharge when all of these hold:

- the option has a stored rate-category key;
- that key is reachable in the same Service Offer version;
- the version has a category-scoped Client `base_price` for that key;
- selecting the option supplies that key to Service and Package price evaluation.

A null effect remains incomplete for an ordinary option that has neither an included zero, a surcharge, nor a reachable category price.

One shared predicate implements that rule for:

- `EvaluateServiceOfferPublicationReadiness#choice_price_issues`;
- `EvaluatePackagePublicationReadiness`;
- `EvaluatePackagePrice#apply_option_effects`.

When the predicate holds, suppress the existing “included price (0) or surcharge” issue and do not add a zero-surcharge line. When a category option has a stored key but no category `base_price`, replace that issue with one incomplete message: “Enter the category price for {option}.” This is a readiness and evaluation amendment, not a publication action.

### 2.9 Client band authority

The typed Client matrix does not expose a fixed four-column set for every category. Confirmed Supplier occupancy profiles choose which traveler-position bands the typed workflow supports. They do not choose the Client amounts entered in those bands.

`CompileCruiseClientTermBandSet` derives the enabled keys from the exact connected category’s confirmed occupancy profiles. The shipped profile specs are `single` (1 position), `double` (2 positions), and `triple` (3 positions).

- A confirmed Single profile enables `single`.
- A confirmed Double profile enables `first` and `second`.
- A confirmed profile of three or more positions enables `first`, `second`, and `additional` when `DetectCruiseSupplierRateShape` supports the additional position. A larger profile still enables `additional` once. It does not add another column.
- The visible authoring columns are the ordered union `single`, `first`, `second`, `additional`.
- A shared First/Second Supplier rate still enables both `first` and `second`. The rate shape does not hide those columns. One Supplier amount may seed both cells.
- `maximum_occupancy` alone enables no Client band.
- A category with no confirmed profile has no typed matrix. The next step is to confirm occupancy at Stop C.
- A Supplier component amount does not become a Client amount because its band is enabled. Missing Supplier amounts do not prevent independent Client entry in an enabled band.
- A band that is not enabled is unavailable. It is not blank, pending, or zero.
- Supplier-copy proposals intersect the source component’s position coverage with this enabled set. They never propose a cell for an unsupported band.

The Single supplement row is present only when `single` is enabled. Other standard rows span the enabled bands only.

### 2.10 Supplier profile changes

- Adding a confirmed Supplier profile makes its Client bands available. It creates no Client cells.
- Editing Supplier amounts never changes Client amounts.
- Removing a profile never deletes saved Client components.
- If a saved Client component uses a band §2.9 no longer enables, the category is Needs attention. The finding is `cruise_client_band_no_longer_supported`.
- That amount stays readable. The ordinary matrix does not offer the band for new cells. The unsupported band remains visible, labeled unsupported, until Staff restore the Supplier configuration, remove the Client band, or use Advanced handling.
- Scenario Review omits newly unsupported scenarios and continues to show unaffected scenarios.
- Neither graph is rewritten to clear the finding.

---

## 3. Persistence contract

### 3.1 Provenance fields

Add nullable `cruise_client_term_row_key` to `service_offer_price_components`. It identifies a matrix row. Labels stay editable and are not identity. Closed standard keys are `cruise_fare`, `nccf`, `taxes_fees`, `discount`, `agency_fee`, and `single_supplement`. A custom surcharge or discount receives a stable key when the row is created. Renaming the label does not mint a new key. `OfferVersionGraphCopy` copies the row key unchanged. A selected-category component with no row key, or two cells with the same rate key, occupancy position, and row key, is Advanced. The row key is independent of provenance.

Add nullable provenance fields to `service_offer_price_components`:

- `copied_from_supplier_cost_component_id` UUID;
- `copied_from_supplier_cost_component_fingerprint` string, length 64;
- `copied_from_supplier_cost_component_at` `timestamptz`;
- `copied_from_supplier_cost_component_mapping` JSONB.

The mapping snapshot stores the copy-time mapping. Schema version `1` uses this exact key order, with nulls present:

```json
{
  "schema": 1,
  "mapped_client_role": "base_price",
  "mapped_calculation_kind": "unit_rate",
  "mapped_quantity_basis": "occupancy_positions",
  "target_occupancy_position": "first",
  "percentage_treatment": null,
  "base_semantics": null
}
```

`percentage_treatment` and `base_semantics` stay null in this slice. They reserve the snapshot for a later supported percentage or base mapping. They do not make those mappings copy-eligible now.

### 3.2 Database constraints

Add:

- an all-null or all-present check across the four provenance fields;
- a fingerprint check requiring lowercase 64-character hexadecimal when present;
- a check that a present mapping is a JSON object;
- a composite foreign key proving the source component belongs to the same Agency and Departure, using `index_supplier_cost_components_on_id_departure_agency`;
- supporting indexes required for the foreign key and provenance comparison queries.

Rails validates schema version `1` and the closed snapshot key set. Reachability through a source binding on the same Service Offer version remains a command and detector invariant.

The existing `service_offer_price_components_reject_non_draft_mutation` trigger freezes these fields with the component after the version leaves draft.

### 3.3 Successor copy

`OfferVersionGraphCopy` copies the typed row key and all four provenance fields unchanged with the Client component. It does not recompute the fingerprint, timestamp, or mapping snapshot, and it does not regenerate `client_rate_category_key`.

The copied successor graph is then compared against Supplier facts reachable through the copied exact bindings. A later explicit Supplier rebind or source change may change the derived provenance state without rewriting the Client component.

### 3.4 No provenance history table

This slice stores only the current component’s copy origin, frozen mapping, and copy-time fingerprint. Audit events record bounded save facts. They do not embed source or Client graphs.

---

## 4. Canonical Supplier fingerprint

Add `SupplierCostComponentCopyFingerprint` as a pure, versioned semantic serializer and SHA-256 digest.

### 4.1 Canonical document

Build the document from the current Supplier component plus the frozen mapping snapshot. Never read the Client component’s current role, calculation, quantity basis, or selectors.

The canonical UTF-8 JSON document uses schema version `1` and this exact top-level key order:

```json
{
  "schema": 1,
  "source_role": "supplier_charge",
  "source_stage": "contracted",
  "currency": "USD",
  "amount_minor_units": 162400,
  "rate": null,
  "source_quantity_basis": "occupancy_positions",
  "participant_category": null,
  "bases": [],
  "mapped_client_role": "base_price",
  "mapped_calculation_kind": "unit_rate",
  "mapped_quantity_basis": "occupancy_positions",
  "target_occupancy_position": "first",
  "percentage_treatment": null,
  "base_semantics": null
}
```

Supplier fields (`source_role` through `bases`) come from the current Supplier component. Mapping fields (`mapped_client_role` through `base_semantics`) come from the frozen snapshot.

Rules:

- JSON strings use standard JSON escaping and UTF-8.
- Null-valued keys remain present.
- Integers serialize as base-10 integers.
- Decimal rates serialize as normalized, non-exponent base-10 strings with insignificant trailing zeros removed.
- `bases` is an array ordered by source base-link position.
- A base entry contains semantic contribution fields and direction, not database identity.

The digest is lowercase `SHA256.hexdigest(canonical_json)` with no `sha256:` prefix. The stored fingerprint check constraint matches that encoding.

### 4.2 Excluded fields

The fingerprint excludes:

- component, definition, Arrangement, and version IDs;
- timestamps;
- row positions except relative base-link order;
- labels and descriptions;
- evidence notes;
- database lock versions;
- the Client component’s current amount, role, and selectors.

Source identity and navigation use the separate source-component foreign key.

### 4.3 First-release supported source shapes

Eligible copy proposals are compatible fixed or unit-rate source components:

| Supplier source | Proposed Client role | Typed behavior |
| --- | --- | --- |
| `supplier_charge`, compatible fare | Staff chooses `base_price` or `named_surcharge` | Fixed/unit value proposed into applicable cells |
| `supplier_charge`, compatible NCCF/fee | `named_surcharge` or `tax_fee`, confirmed by Staff | No statutory inference |
| `supplier_credit`, compatible rate | `named_discount` | Client amount remains positive; role supplies negative revenue direction |
| `expected_commission` | None | Never eligible |
| `informational_allocation` | None | Never eligible |
| Percentage, minimum, or shortfall | None in typed copy | Manual/Advanced Client entry |

Unsupported mappings remain visible as unavailable source context. They are not dropped silently into the matrix.

---

## 5. Provenance comparison

`CompareSupplierCostCopyProvenance` is write-free. It recomputes the digest from the current Supplier component plus the frozen mapping snapshot.

| State | Meaning |
| --- | --- |
| `independent` | The Client component has no provenance fields. This is not a finding. |
| `unchanged` | The source resolves, remains reachable, remains supported, and its recomputed digest matches the stored fingerprint. |
| `changed` | The source resolves and remains comparable, but its recomputed digest differs. |
| `missing` | The source row no longer resolves or is no longer reachable through the exact Service Offer version’s source graph. |
| `unknown` | The source resolves but the current shape cannot be safely normalized or compared. |

A Client-value edit does not report a Supplier change. A Client-role edit does not rewrite the frozen snapshot. A Supplier-source edit does change the recomputed digest. Recopy is the only typed action that writes a new snapshot and fingerprint.

Reachability requires that the source component belong to an Arrangement version and exact Item/Occurrence/Resource context reachable through the selected option’s source binding on the same Service Offer version.

Comparison never writes, repairs, or recopies.

---

## 6. Typed price shape

### 6.1 Matrix band compilation

Add `CompileCruiseClientTermBandSet` as a write-free adapter over the exact connected category’s confirmed occupancy profiles and `DetectCruiseSupplierRateShape`. It implements §2.9.

It returns:

- enabled occupancy-position keys;
- the Supplier profile authorizing each key;
- whether compatible Supplier components are available to propose for each key;
- specific unavailable reasons;
- whether the band is already used by a saved Client component.

The matrix renders enabled bands in this order:

1. `single` — Single;
2. `first` — 1st traveler;
3. `second` — 2nd traveler;
4. `additional` — Additional traveler.

Those four keys remain the closed typed vocabulary. Their presence in a particular category’s matrix is dynamic. Unsupported custom occupancy keys route the category schedule to Advanced. A saved component on a band that is no longer enabled stays readable under §2.10 and is not a new authoring column.

### 6.2 Matrix row templates

| Staff-facing row | Client role | Calculation | Quantity basis |
| --- | --- | --- | --- |
| Cruise fare | `base_price` | `unit_rate` | `occupancy_positions` |
| NCCF | `named_surcharge` | `unit_rate` | `occupancy_positions` |
| Taxes and fees | `tax_fee` | `unit_rate` | `occupancy_positions` |
| Discount | `named_discount` | `unit_rate` | `occupancy_positions` |
| Agency fee | `named_surcharge` | `unit_rate` | `occupancy_positions` |
| Single supplement | `named_surcharge` | `unit_rate` | `occupancy_positions`; present only when `single` is enabled |
| Other surcharge | `named_surcharge` | `unit_rate` | `occupancy_positions` |
| Other discount | `named_discount` | `unit_rate` | `occupancy_positions` |

Agency fee is a standard row. Its default label is `Agency fee` and is editable. Staff do not need to discover it through Other surcharge.

The first release does not expose typed percentage rows. Existing percentage or cross-row-base Client graphs remain Advanced.

### 6.3 Cell compilation

Each nonblank cell creates one component with:

- the row’s role and label;
- `calculation_kind = unit_rate`;
- `quantity_basis = occupancy_positions`;
- `occupancy_position_key` from the column;
- `client_rate_category_key` from the selected choice option;
- `amount_minor_units` parsed through the shipped money boundary;
- optional provenance fields.

Discount amounts are entered and stored as nonnegative money. `named_discount` supplies the negative revenue direction. One `base_price` cell per rate key and occupancy key matches `index_service_offer_price_components_one_base_selector`.

### 6.4 Supported reconstruction

`DetectCruiseClientTermShape` accepts only graphs it can round-trip without loss. For the selected category it verifies:

- the Slice 2C connection is compatible;
- every typed component uses the option’s exact stored rate key;
- occupancy selectors belong to the closed matrix catalog;
- roles and calculation shapes map to one supported row;
- no duplicate cell exists;
- no percentage base crosses categories;
- provenance is complete and points to a reachable source when present;
- the Service Offer version owns one ordinary calculated price definition.

Unsupported siblings do not become typed merely because some rows resemble the matrix. Fail closed and preserve the graph.

---

## 7. Commands and services

### 7.1 Public mutation commands

- `CreateCruiseClientTermSchedule`
- `UpdateCruiseClientTermSchedule`
- `RemoveCruiseClientTermSchedule`

Inputs include:

- Agency and actor;
- connected Cruise Service Offer;
- exact Service Offer version and its lock version;
- selected choice option resolved through Slice 2C;
- normalized matrix rows and cells;
- optional confirmed Supplier-copy proposals;
- when the resulting cells create, recopy, or retain Supplier provenance: the exact Supplier Arrangement version ID and that version’s lock version;
- idempotency key for create only.

Independent Client-only saves, whose resulting cells carry no Supplier provenance, do not take an Arrangement lock.

Outputs include the Service Offer price definition, the selected category summary, and status `created`, `updated`, or `removed`.

### 7.2 Create idempotency payload

`CreateCruiseClientTermSchedule` hashes:

- Departure ID;
- Service Offer and exact version IDs;
- selected option ID;
- stored category key;
- exact Supplier Arrangement version when copying;
- ordered normalized matrix rows and cells;
- source component ID for each copied cell;
- frozen copy-mapping snapshot for each copied cell.

Lock versions are concurrency inputs, not semantic idempotency identity. The same key and normalized payload replays. Changed cells, sources, mappings, or category conflict. Updates do not use an idempotency key.

### 7.3 Transaction boundary

The typed command owns one transaction and this lock order:

1. Agency;
2. actor reloaded and rechecked through the Agency;
3. affected Suppliers in UUID order;
4. Departure;
5. Arrangement version, selected exact source definitions, and copied Supplier components when the save takes the Arrangement lock;
6. Service Offer version, price definition, affected Client components, and bases.

Check optimistic locks before writes. Do not call public `CreateServiceOfferPriceDefinition` or `UpdateServiceOfferPriceDefinition` from inside the typed command. Extract or reuse an already-locked component-normalization helper so typed and Advanced paths retain the shipped M4B validations.

### 7.4 Category merge semantics

Create initializes the one Service price definition when absent and inserts the selected category cells.

Update:

1. detects the current supported graph;
2. partitions components by category key;
3. preserves all unaffected supported category components;
4. preserves safely separable non-category components only when the detector explicitly allows them;
5. merges the selected category in place by rate key, occupancy-position key, and typed row key: update retained cells, recopy retained cells without changing the component id, delete only removed selected-category cells, and create only new cells;
6. validates the complete resulting M4B graph;
7. bumps the Service Offer version once;
8. writes one bounded audit event.

Failure rolls back the whole selected-category save. It never modifies Supplier costs or sibling category terms.

Remove deletes only the selected category’s typed components. It removes the price definition only when no components remain and the resulting empty calculated definition would be invalid. It does not delete a `zero_price` definition or components the detector cannot partition.

### 7.5 Read and preview services

- `CompileCruiseClientTermsWorkspace` — category summaries, selected matrix, provenance findings, editability, and Advanced links.
- `CompileCruiseClientTermBandSet` — write-free enabled bands for the connected category.
- `DetectCruiseClientTermShape` — definition and category-scoped compatibility and exact reconstruction.
- `PreviewCruiseClientTermSchedule` — write-free normalization and Single/Double/Triple Client preview from submitted cells.
- `CompileCruiseScenarioReview` — write-free Stop G review combining Client evaluation, Supplier economics, provenance findings, and capacity context.
- `SupplierCostComponentCopyFingerprint` — pure canonical digest.
- `CompareSupplierCostCopyProvenance` — pure comparison result.

No preview service emits audit events, idempotency records, version bumps, or durable totals.

### 7.6 Audit

Add `service_offer.cruise_client_terms_saved` to `AuditEvent::ACTIONS` in the same change that first writes it. The subject remains `ServiceOffer`.

Details may include Service Offer and version IDs, selected option ID, affected component count, copied-source count, and status. Do not embed amounts, rate keys, complete matrices, Supplier graphs, or scenario results.

---

## 8. Routes and authorization

Add under the existing Cruise Arrangement resource:

```text
GET    .../cruise/client-terms
POST   .../cruise/client-terms
PATCH  .../cruise/client-terms
DELETE .../cruise/client-terms
POST   .../cruise/client-terms/preview
```

Controller: `CruiseClientTermsController`.

- Every action, including `show`, requires `manage_departures`. Unauthorized access returns not found.
- Records load through `Current.agency` and the route’s Departure and Arrangement.
- The page requires a compatible Slice 2C connection.
- A mismatched Arrangement, Service, option, or source ID returns not found or invalid as appropriate.
- Default `show` renders saved summaries without an open editor.
- Editor state opens only from an explicit query or action.
- Successful mutation redirects `303` to the summary without the editor query.
- Invalid mutation renders `422`, preserves the matrix and copy selections, focuses `#form-error-summary`, and links field errors.
- Generic Service Offer pricing remains the Advanced path with a validated return context.

---

## 9. Workspace interaction contract

### 9.1 Summary-first page

The default page separates saved information from editing. It shows one category card per Slice 2C option. Dollar figures on an example card are illustrative copies of the accepted Celebrity supplier facts, not stored Client contract prices:

```text
O1 — Prime Oceanview                                      Ready
Illustrative Single $3,555.00 · Double $3,862.00 · Triple $4,687.50
```

Those illustrative totals are fare, NCCF, taxes, and discount for first and second travelers (`$1,624 + $320 + $137 − $150 = $1,931` per person; Double `$3,862`), plus the `$1,624` single supplement for Single (`$3,555`), plus the additional-person lines for Triple (`$406 + $320 + $137 − $37.50 = $825.50`; Triple `$4,687.50`).

Incomplete categories show exact next actions rather than a generic incomplete label.

### 9.2 Editor

Only one category editor is open at a time. Its heading names the action and category:

> Edit Client terms — O1 Prime Oceanview

The primary control is a table modeled on the shipped Supplier rate matrix. Columns are the enabled bands from §6.1. Standard rows include Cruise fare, NCCF, Discount, Taxes and fees, and Agency fee across those bands, plus Single supplement when `single` is enabled. Single supplement accepts a value only in the Single column. An unsupported saved band stays visible and labeled unsupported. It does not accept new cells.

Staff may add supported custom surcharge or discount rows. Repeated-value fill-across affordances may be reused from the Supplier matrix. Copying across cells occurs only through an explicit Staff action.

### 9.3 Matrix usability

- Row labels remain visible at narrow widths through the established responsive table pattern.
- The matrix may use an explicitly labeled internal horizontal scroll region at narrow widths. The page itself must not overflow.
- Prove layout at 375, 768, 1280, and 1400 pixel widths.
- Keyboard order proceeds row by row and then to preview and save actions.
- Currency is displayed once in context and on monetary controls where needed.
- Discounts are visually signed but entered as positive amounts.
- Blank and explicit zero are distinguishable.
- Saved summaries never expose binding IDs, option IDs, rate keys, membership enums, provenance digests, or mapping snapshots.

### 9.4 Supplier-copy proposal

“Start from Supplier terms” opens a review state before any write. Each proposed cell shows the Supplier source label and current value, the target Client row and traveler position, the proposed Client role and amount, whether one source expands to several cells, unsupported sources with a concise reason, and an editable proposed Client value.

After save, a copied cell may show the source amount, the provenance state in text, and actions to open the source or remove the source link. Changed, missing, and unknown states use text and a badge. Color is never the only signal.

### 9.5 Preview

Below the matrix, show write-free scenario totals for scenarios whose bands §2.9 enables:

- Single — sum of applicable `single` cells;
- Double — sum of `first` and `second` cells;
- Triple — sum of `first`, `second`, and `additional` cells.

The preview identifies pending cells rather than treating them as zero. It is advisory until save and is never persisted.

---

## 10. Scenario Review contract

### 10.1 Compiler

`CompileCruiseScenarioReview` operates on the selected connected category and constructs the shipped evaluator inputs:

| Scenario | Occupancy positions | Persons | Resource units |
| --- | --- | ---: | ---: |
| Single | `single` | 1 | 1 |
| Double | `first`, `second` | 2 | 1 |
| Triple | `first`, `second`, `additional` | 3 | 1 |

Every occupancy position carries the selected option’s stored Client rate-category key as `rate_category`. The scenario selects that option and its exact source activation and binding. Include a scenario only when §2.9 enables every band it uses. Omit a newly unsupported scenario without hiding the scenarios that remain enabled.

### 10.2 Evaluation reuse

Reuse, without a parallel arithmetic engine:

- `EvaluateClientPrice` for Client lines and total, with the stored key supplied as `rate_category`;
- `EvaluateIndicativeScenarioEconomics` for attributable Supplier economics and margin;
- shipped Supplier cost forecast evaluation for gross, commission, and net detail;
- shipped capacity projection for current context.

`EvaluateIndicativeScenarioEconomics` already maps `single` and `first` to supplier occupancy position 1, `second` to 2, and `additional` to 3 and above. A one-position Single scenario is what the forecast treats as `single_occupancy_units`. If an existing service does not expose a sufficiently granular known result, add a read adapter over its output rather than copying its formula.

### 10.3 Review presentation

For each supported scenario, show the Client lines and total, Supplier gross, expected commission, Supplier net, indicative margin when the inputs support it, time-labeled capacity context, and needs-attention findings. Capacity context is explicitly not promised inventory.

### 10.4 Partial knowledge

- Missing Client input does not hide known Supplier gross or known Client lines.
- Missing commission does not hide Supplier gross or Client revenue.
- One incomplete category does not hide another category.
- One incomplete scenario does not hide complete scenarios.
- Margin appears only when the required Client and Supplier inputs are sufficient and currency-compatible.
- Capacity context is time-labeled.

### 10.5 Finding codes

Extend `EvaluateDepartureBuilderReadiness` only. Do not add a second findings catalog. `independent` and `unchanged` emit no finding.

| Code | State | When |
| --- | --- | --- |
| `cruise_category_base_price_missing` | `incomplete` | The category option has a stored key and no same-version `base_price` for it. Used on the category card and scenario review. |
| `cruise_client_source_changed` | `needs_attention` | Provenance state is `changed`. |
| `cruise_client_source_missing` | `needs_attention` | Provenance state is `missing`. |
| `cruise_client_source_unknown` | `needs_attention` | Provenance state is `unknown`. |
| `cruise_client_band_no_longer_supported` | `needs_attention` | A saved Client component uses a band §2.9 no longer enables. |

Each provenance finding, and `cruise_client_band_no_longer_supported`, uses the Pricing and Client terms area, deep-links to that category’s Client-terms editor, and applies to Client-term review. A provenance finding explains the known Client amount separately from the Supplier change. The unsupported-band finding names the saved band and leaves both graphs unchanged. None of these findings make `EvaluateClientPrice` incomplete or block publication.

Publication readiness keeps its own incomplete price issue. `publish_findings` continues to wrap that issue through the existing publication finding. It does not also emit `cruise_category_base_price_missing`, so one missing category price is not reported twice on the publish outcome.

**Keep Client term** leaves a `changed`, `missing`, or `unknown` finding in place. Removing the source link or recopying are the actions that clear it.

---

## 11. Lifecycle and successor behavior

- Draft Service Offer versions are editable.
- Published or frozen versions are read-only.
- When an editable successor exists and both the Slice 2C connection and Client-term graph are compatible, edits target that successor.
- Successor copy may assign new Client component IDs. Category key strings and all four provenance fields stay unchanged.
- Recopy inside one draft version keeps the component ID.
- A later Supplier Arrangement successor does not move the Service Offer’s exact source binding or recopy Client values.
- Unsupported successor graphs remain readable through Advanced.
- Removing a cabin category remains blocked while same-version Client components use its rate key, as shipped by Slice 2C.
- Adding, editing, or removing confirmed Supplier occupancy profiles follows §2.10. A removed profile does not delete Client components. A band that is no longer enabled produces `cruise_client_band_no_longer_supported`.

---

## 12. Delivery slices

### 2D-A — Provenance and typed-term foundation

Ship the migration and database integrity, successor graph copy of all four provenance fields, canonical fingerprint and comparison services, typed detector, band-set compiler, workspace compiler, and category-scoped create, update, and remove commands. Service-level proof does not require the ordinary UI.

**Exit:** O1 terms can be saved independently with durable, comparable zero-or-one provenance while sibling categories and Supplier facts remain unchanged.

### 2D-B — Client price matrix

Ship the Cruise Client-terms routes and controller, summary-first category cards, one-category traveler-position matrix whose columns follow §2.9, Agency fee, independent entry, reviewed Supplier-copy proposal, write-free matrix preview, and Advanced fallback.

**Exit:** Staff can enter and reopen O1 fare, NCCF, tax, discount, and Agency fee rows without using the generic graph editor.

### 2D-C — Scenario Review and readiness integration

Ship `CompileCruiseScenarioReview`, review of the scenarios §2.9 enables, known/pending Client and Supplier economics, time-labeled capacity context, the finding codes in §10.5, the shared null-effect predicate across the three evaluators, and the blocking Celebrity system proof.

**Exit:** Staff can explain Client revenue, Supplier economics, provenance state, and the next required action for O1 without persisted scenario facts. A finished O1 category price no longer fails publication because its option price effect is null.

**Shipped 2026-09-24.** Deliveries 2D-A, 2D-B, and 2D-C merged at [`dc272a3`](https://github.com/tswarren/DepartureDesk/commit/dc272a3) (PR #154).

---

## 13. Proof contract

### 13.1 Persistence and command proof

- Provenance is all-null or all-present across four fields.
- A present mapping is a JSON object with schema version `1` and the closed key set.
- Malformed fingerprints fail in PostgreSQL and Rails.
- Cross-Agency and cross-Departure source pointers fail.
- Frozen Client components reject provenance mutation.
- Successor copy preserves the pointer, fingerprint, timestamp, and mapping snapshot.
- Fingerprint fixtures prove stable JSON, decimal normalization, null inclusion, and base ordering.
- IDs, labels, timestamps, row positions, and live Client role edits do not alter the digest.
- Semantic Supplier changes do alter the digest.
- Create retry with the same normalized payload returns the same definition without duplicate components or audit success.
- The same create key with changed cells, sources, mappings, or category conflicts.
- A stale Service Offer version leaves Client and Supplier graphs unchanged.
- A stale Arrangement version leaves both graphs unchanged when the save creates, recopies, or retains provenance.
- An independent Client-only save does not require an Arrangement lock.
- O1 save preserves I1 and Advanced-safe siblings.
- Failed O1 save preserves the previous O1 graph.
- Removing O1 terms does not remove its option, binding, or rate key.
- Expected commission and informational allocations are never copy-eligible.
- One source may seed several cells. Every cell retains exactly one source.
- Multi-source-to-one-cell proposals fail closed.
- A save refuses a new cell on a band §2.9 does not enable.
- Removing a Supplier profile does not delete Client components that used its bands.

### 13.2 Detector and provenance proof

- A supported typed matrix reopens without normalization drift.
- Duplicate cells, unknown occupancy keys, unsupported percentage graphs, unreachable rate keys, and cross-category bases route Advanced unchanged.
- Independent, unchanged, changed, missing, and unknown states are each proven.
- Comparison writes nothing.
- Recopy requires explicit confirmation and keeps the component ID.
- Keep Client term does not rewrite provenance.
- Removing provenance retains the Client value.
- Single-only Supplier selection enables only the Single Client column.
- Double-only selection enables 1st and 2nd, not Single or Additional.
- A confirmed profile of three or more positions enables Additional only when the rate shape supports the additional position. A larger profile still uses `additional` once.
- Maximum occupancy of three without a confirmed Triple profile does not enable Additional.
- A category with no confirmed profile has no typed matrix.
- A shared First/Second Supplier rate still enables both `first` and `second`.
- Missing Supplier amounts do not prevent independent Client entry in an enabled band.
- Supplier copy proposes cells only inside the source coverage and the enabled band set.
- Adding a Supplier profile exposes a new blank Client band and creates no component.
- Removing a Supplier profile preserves existing Client components and produces `cruise_client_band_no_longer_supported`.
- That finding does not block publication and does not rewrite either graph.

### 13.3 Evaluation and readiness proof

- A Slice 2C option with a null price effect and a reachable category `base_price` is publication-ready for that choice, and Package evaluation adds no surcharge line and no null-effect blocker.
- A null effect on an ordinary option that lacks an included zero, a surcharge, and a reachable category price remains incomplete.
- A category key without a `base_price` produces “Enter the category price for {option}.” and `cruise_category_base_price_missing` on the category card, without a second publish finding.
- `changed`, `missing`, and `unknown` are needs-attention findings and do not make the Client price incomplete or block publication.
- Scenario positions pass the stored key as `rate_category`.

### 13.4 Request proof

- Viewer receives not found for every Stop F–G route.
- Staff default visit shows summaries and no open form fields.
- Editor opens only from an explicit category action.
- Invalid save returns `422`, preserves all cells and selections, and focuses the error summary.
- Success redirects `303` without reopening the editor.
- Submitted option and source IDs are Agency-, Departure-, Arrangement-, version-, and Service-scoped.
- Preview writes no definitions, components, idempotency rows, audit events, or version bumps.
- Advanced fallback retains a safe return path.

### 13.5 System and accessibility proof

1. Enter O1 terms independently in the matrix, including Agency fee.
2. Start selected O1 cells from Supplier terms, review, edit, and save.
3. Reopen O1 with values and provenance unchanged.
4. Add I1 terms without changing O1.
5. Change a Supplier source and see a changed finding without a Client overwrite or a publication block.
6. Keep the Client term, recopy it, and remove its source link as separate flows.
7. Review only the scenarios §2.9 enables. An unavailable scenario does not hide a complete enabled scenario.
8. An unsupported Client graph remains Advanced and unchanged.
9. Keyboard-only entry and recovery at 375, 768, 1280, and 1400 pixel widths.
10. No horizontal page overflow. A matrix may use a labeled internal scroll region.

### 13.6 Blocking Celebrity proof

Using the accepted Celebrity supplier facts, with any copied Client amounts labeled illustrative:

- exactly one Cruise Service exists;
- O1 remains one option in the exactly-one category group;
- O1’s stored key scopes every O1 Client component;
- fare, NCCF, taxes and fees, discount, Agency fee, and any single supplement remain separately explained;
- illustrative Single is `$3,555.00`, Double is `$3,862.00`, and supported Triple is `$4,687.50` when those supplier amounts are copied unchanged;
- expected commission is not Client revenue;
- copied source changes never overwrite Client amounts;
- Single, Double, and Triple are available together because the accepted fixture confirms all three occupancy profiles and the rate shape supports the additional position;
- Triple stays unavailable when the category lacks a confirmed occupancy profile of at least three positions or the rate shape lacks the additional position;
- a Double-only category does not show a Single column or a Single review;
- known Client and Supplier lines remain visible beside exact pending facts;
- a completed category price with a null option effect is not an incomplete choice;
- no second Service Offer or price definition is created;
- no scenario total, margin, readiness result, recommendation, or capacity snapshot is persisted.

---

## 14. Ship boundary

**Shipped 2026-09-24** at [`dc272a3`](https://github.com/tswarren/DepartureDesk/commit/dc272a3) (PR #154), after 2D-A, 2D-B, and 2D-C merged green.

This promotion already amends the parent sections listed in §15. Later implementation does not reopen those product decisions.

---

## 15. Parent amendments applied with this Accept

[M4D.1](m4d1-departure-composition-workspace.md) is amended as follows. The slice plan remains the implementing authority.

- §12.6 names Agency fee as an ordinary Cruise line. The row catalog in §6.2 is authoritative. Client matrix bands follow confirmed Supplier occupancy profiles, not a fixed four-column set.
- §12.7 shows a scenario only when §2.9 enables every band it uses.
- §13.2 treats a null Slice 2C option price effect as no separate surcharge once the category `base_price` exists.
- §14.1 recopy updates the same draft component. Keep does not rewrite copy-time provenance.
- §14.2 stores four provenance fields, including the mapping snapshot. Comparison uses the current Supplier component plus that frozen snapshot.
- §14.3 allows one Supplier component to seed several Client cells. Each Client component still has at most one source.
- §19.1 names `CreateCruiseClientTermSchedule`, `UpdateCruiseClientTermSchedule`, and `RemoveCruiseClientTermSchedule`.
- §21 marks Slice 2D Shipped at `dc272a3` (PR #154). [Slice 3R](m4d1-slice3r-non-cruise-adapter-boundary.md) is the next accepted decision and authorizes the Hotel walkthrough only.

---

## 16. Exit criteria

Slice 2D is complete when Staff can author and reopen O1 Client terms through a traveler-position matrix, optionally trace eligible cells to reviewed Supplier origins without live synchronization, and review Single, Double, and supported Triple Client and Supplier economics with exact pending facts and current capacity context.

The exit is not satisfied by exposing only the generic price-component editor, copying Supplier amounts automatically, storing scenario totals, or showing a total that cannot be explained by its independent Client and Supplier facts.
