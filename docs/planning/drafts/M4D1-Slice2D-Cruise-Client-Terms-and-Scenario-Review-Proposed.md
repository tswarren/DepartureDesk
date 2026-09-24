# M4D.1 Slice 2D — Cruise Client Terms and Scenario Review

**Status:** Superseded by [M4D.1 Slice 2D](../m4d1-slice2d-cruise-client-terms-and-scenario-review.md). Historical proposal. Not implementation authority.

**Parent authority:** `docs/planning/m4d1-departure-composition-workspace.md`, especially Stops F–G and §§13–14, 19, 21, and 23.

**Prerequisite:** M4D.1 Slice 2C must be Shipped on a green `main` tip. Slice 2D consumes its one-Service-per-Cruise-Item claim, exactly-one cabin-category choice group, exact source bindings, and option-owned `client_rate_category_key`. It does not reinterpret or replace Slice 2C.

**Shipped foundations:** M4B Client price definitions, components, bases, `EvaluateClientPrice`, and `EvaluateIndicativeScenarioEconomics`; M3C Supplier cost definitions and forecast evaluators; M4D publication/readiness; M4D.1 Slice 2A Supplier rate matrix.

---

## 1. Outcome

Staff can select one cabin category in a connected Cruise Service, author its Client-facing price terms in a familiar traveler-position matrix, optionally start compatible cells from Supplier terms, and review Single, Double, and Triple economics without silently equating Supplier cost with Client revenue.

For the Celebrity proof, Staff can explain separately:

- Cruise fare;
- NCCF;
- taxes and fees;
- named discounts;
- named surcharges, including a separately presented single supplement when used;
- total Client revenue for Single, Double, and supported Triple configurations;
- Supplier gross, expected commission, Supplier net, and indicative margin;
- exact missing inputs and current time-labeled capacity context.

Client prices remain independently authored M4 records. Supplier components are never copied automatically, expected commission never becomes Client revenue, and later Supplier changes never overwrite Client terms.

---

## 2. Scope

### 2.1 In scope

- Stop F Cruise Client-term authoring for a Service Offer created or connected by Slice 2C.
- One Client price definition on the exact Service Offer version.
- Category-scoped Client components keyed by the selected choice option’s stored `client_rate_category_key`.
- A traveler-position matrix modeled on the shipped Cruise Supplier rate-matrix interaction.
- Independent entry of Client terms.
- Explicit, reviewed copy proposals from compatible Supplier components.
- Durable one-source-per-Client-component copy provenance.
- Derived provenance states: independent, unchanged, changed, missing, and unknown.
- Stop G write-free Single, Double, and supported Triple review.
- Known/pending arithmetic that preserves partial useful results.
- Advanced fallback for Client price graphs the typed adapter cannot reconstruct safely.
- Draft/successor behavior, optimistic locking, recovery, authorization, accessibility, and blocking Celebrity proof.

### 2.2 Non-goals

- Automatic markup, target-price, or target-margin authoring.
- Live synchronization from Supplier terms.
- Copying expected commission or informational allocations into Client revenue.
- Multi-Supplier-source-to-one-Client-component transformation provenance.
- Percentage, minimum, or shortfall Supplier-copy mappings in the first release.
- Package pricing, Package placement, payment terms, cancellation terms, or publication actions.
- Persisted scenarios, totals, margins, readiness results, recommendations, or capacity snapshots.
- Named Travelers, bookings, Holds, Allocations, Charges, Receipts, Obligations, Payments, or remittance.
- Tax jurisdiction, tax remittance, or statutory classification.
- Replacing the generic Service Offer price editor; it remains the Advanced path.

---

## 3. Locked domain decisions

### 3.1 One price definition, category-scoped components

The Cruise Service retains one `ServiceOfferPriceDefinition` per exact Service Offer version. Slice 2D does not create a definition per cabin category and does not add a cabin-price aggregate.

Each typed matrix cell compiles to an ordinary `ServiceOfferPriceComponent` carrying:

- the selected option’s stored `client_rate_category_key`;
- one supported occupancy-position selector;
- an M4B Client role and calculation shape;
- its independently entered Client amount;
- optional copy provenance.

Staff never enter or see the stored rate key.

### 3.2 Category-scoped saves

A typed save for O1 replaces only the typed component subset carrying O1’s rate key. It preserves:

- I1 and other category-scoped components;
- the choice option, source activation, binding, and stored rate key;
- Supplier cost graphs;
- safely separable components outside the selected category.

If the existing graph contains generic components, cross-category percentage bases, category keys not reachable through the Slice 2C choices, or another topology the detector cannot partition without reinterpretation, the definition is Advanced. The typed save never deletes or silently rewrites those rows.

### 3.3 Blank, zero, and pending

- Blank means not entered or not applicable; it never means zero.
- An explicit `0.00` is an entered Client value.
- A missing cell may produce a pending scenario fact without hiding known lines or other complete scenarios.
- The typed matrix does not persist a separate pending row.

### 3.4 Single occupancy

`single` is a traveler-position selector, not an all-in persisted scenario total.

The matrix may contain distinct Single-column components, including:

- Cruise fare;
- NCCF;
- taxes and fees;
- discount;
- a separately labeled single supplement or surcharge.

The write-free scenario compiler sums applicable Single-column components. No individual cell is labeled or treated as the all-in Single total.

### 3.5 Supplier-copy meaning

“Start from Supplier terms” is an explicit proposal and confirmation flow:

1. Staff choose eligible Supplier components or proposed cells.
2. DepartureDesk displays the source meaning, proposed Client role, target traveler positions, and proposed values.
3. Staff may edit Client-facing labels, roles, and values before saving.
4. Saving creates independently editable Client components.
5. Each copied Client component retains at most one exact Supplier source and one copy-time semantic fingerprint.
6. Later Supplier changes produce findings; they never overwrite the Client component.

One Supplier component may seed several Client cells when a compatible source position range expands into independent Client positions. Each resulting Client component points to that same one source component and records its own selected Client mapping in the fingerprint. Several Supplier components may not be merged into one provenance chain in this slice.

### 3.6 Recopy and provenance removal

The UI exposes distinct actions:

- **Keep Client term** — retain the Client value and provenance finding.
- **Recopy from Supplier** — show a new proposal and replace only after confirmation.
- **Remove source link** — keep the Client component and clear all provenance fields.
- **Remove Client term** — delete the draft Client component subject to ordinary graph rules.

Recopy is never automatic.

### 3.7 Scenario review

Single, Double, and Triple are transient travel configurations:

- Single: `single`;
- Double: `first`, `second`;
- Triple: `first`, `second`, `additional`.

Each occupancy position receives the selected category option’s stored rate key. Each review also supplies the option and exact source binding selected by Slice 2C, one cabin/resource unit, and the matching person count.

Triple is shown only when the connected category’s supported facts permit occupancy of at least three. These scenarios are not Supplier occupancy profiles, demand, reservations, or capacity promises.

---

## 4. Persistence contract

### 4.1 Provenance fields

Add nullable fields to `service_offer_price_components`:

- `copied_from_supplier_cost_component_id` UUID;
- `copied_from_supplier_cost_component_fingerprint` string, length 64;
- `copied_from_supplier_cost_component_at` `timestamptz`.

### 4.2 Database constraints

Add:

- an all-null-or-all-present check across the three fields;
- a fingerprint check requiring lowercase 64-character hexadecimal when present;
- a composite foreign key proving the source component belongs to the same Agency and Departure;
- supporting indexes required for the foreign key and provenance comparison queries.

The existing Service Offer version draft-mutation trigger freezes these fields with the component after the version leaves draft.

Reachability through a source binding on the same Service Offer version is a command/detector invariant, not merely a foreign-key invariant.

### 4.3 Successor copy

`OfferVersionGraphCopy` copies all three provenance fields unchanged with the Client component. It does not recompute the fingerprint or timestamp.

The copied successor graph is then compared against Supplier facts reachable through the copied exact bindings. A later explicit Supplier rebind or source change may therefore change the derived provenance state without rewriting the Client component.

### 4.4 No provenance history table

This slice stores only the current component’s copy origin and copy-time fingerprint. Audit events record bounded save facts; they do not embed source or Client graphs. A multi-generation recopy history is deferred.

---

## 5. Canonical Supplier fingerprint

Add `SupplierCostComponentCopyFingerprint` as a pure, versioned semantic serializer and SHA-256 digest.

### 5.1 Canonical document

The canonical UTF-8 JSON document uses schema version `1` and this exact top-level key order:

```json
{
  "schema": 1,
  "source_role": "supplier_charge",
  "source_stage": "contracted",
  "mapped_client_role": "base_price",
  "mapped_calculation_kind": "unit_rate",
  "currency": "USD",
  "amount_minor_units": 162400,
  "rate": null,
  "quantity_basis": "occupancy_positions",
  "percentage_treatment": null,
  "participant_category": null,
  "target_occupancy_position": "first",
  "bases": []
}
```

Rules:

- JSON strings use standard JSON escaping and UTF-8.
- Null-valued keys remain present.
- Integers serialize as base-10 integers.
- Decimal rates serialize as normalized, non-exponent base-10 strings with insignificant trailing zeros removed.
- `bases` is an array ordered by source base-link position.
- A base entry contains semantic contribution fields and direction, not database identity.
- The selected target Client role, calculation kind, and occupancy position are included because they are part of the confirmed mapping.

The digest is lowercase `SHA256.hexdigest(canonical_json)`.

### 5.2 Excluded fields

The fingerprint excludes:

- component, definition, Arrangement, and version IDs;
- timestamps;
- row positions except relative base-link order;
- labels and descriptions;
- evidence notes;
- database lock versions.

Source identity and navigation use the separate source-component foreign key.

### 5.3 First-release supported source shapes

Eligible copy proposals are limited to one-to-one semantic mappings from compatible fixed or unit-rate source components:

| Supplier source | Proposed Client role | Typed behavior |
| --- | --- | --- |
| `supplier_charge`, compatible fare | Staff chooses `base_price` or `named_surcharge` | Fixed/unit value proposed into applicable cells |
| `supplier_charge`, compatible NCCF/fee | `named_surcharge` or `tax_fee`, confirmed by Staff | No statutory inference |
| `supplier_credit`, compatible rate | `named_discount` | Client amount remains positive; role supplies negative revenue direction |
| `expected_commission` | None | Never eligible |
| `informational_allocation` | None | Never eligible |
| Percentage, minimum, or shortfall | None in typed copy | Manual/Advanced Client entry |

Unsupported mappings remain visible as unavailable source context where useful; they are not silently dropped into the matrix.

---

## 6. Provenance comparison

`CompareSupplierCostCopyProvenance` is write-free and returns:

| State | Meaning |
| --- | --- |
| `independent` | The Client component has no provenance fields. |
| `unchanged` | The source resolves, remains reachable, remains supported, and its current semantic digest matches. |
| `changed` | The source resolves and remains comparable, but its digest differs. |
| `missing` | The source row no longer resolves or is no longer reachable through the exact Service Offer version’s source graph. |
| `unknown` | The source resolves but the current shape cannot be safely normalized or compared. |

Reachability requires that the source component belong to an Arrangement/version and exact Item/Occurrence/Resource context reachable through the selected option’s source binding on the same Service Offer version.

Comparison never writes, repairs, or recopies.

---

## 7. Typed price shape

### 7.1 Matrix columns

The typed matrix uses these closed occupancy-position columns:

- `single` — Single;
- `first` — 1st traveler;
- `second` — 2nd traveler;
- `additional` — Additional traveler.

Unsupported custom occupancy keys route the category schedule to Advanced.

### 7.2 Matrix row templates

| Staff-facing row | Client role | Calculation | Quantity basis |
| --- | --- | --- | --- |
| Cruise fare | `base_price` | `unit_rate` | `occupancy_positions` |
| NCCF | `named_surcharge` | `unit_rate` | `occupancy_positions` |
| Taxes and fees | `tax_fee` | `unit_rate` | `occupancy_positions` |
| Discount | `named_discount` | `unit_rate` | `occupancy_positions` |
| Single supplement | `named_surcharge` | `unit_rate` | `occupancy_positions`; Single only |
| Other surcharge | `named_surcharge` | `unit_rate` | `occupancy_positions` |
| Other discount | `named_discount` | `unit_rate` | `occupancy_positions` |

The first release does not expose typed percentage rows. Existing percentage or cross-row-base Client graphs remain Advanced.

### 7.3 Cell compilation

Each nonblank cell creates one component with:

- the row’s role and label;
- `calculation_kind = unit_rate`;
- `quantity_basis = occupancy_positions`;
- `occupancy_position_key` from the column;
- `client_rate_category_key` from the selected choice option;
- `amount_minor_units` parsed through the shipped money boundary;
- optional provenance fields.

Discount amounts are entered and stored as nonnegative money. `named_discount` supplies the negative revenue direction.

### 7.4 Supported reconstruction

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

## 8. Commands and services

### 8.1 Public mutation commands

Lock these public surfaces at Accept:

- `CreateCruiseClientTermSchedule`
- `UpdateCruiseClientTermSchedule`
- `RemoveCruiseClientTermSchedule`

Inputs include:

- Agency and actor;
- connected Cruise Service Offer;
- exact Service Offer version;
- selected choice option or Supplier Resource identity resolved through Slice 2C;
- normalized matrix rows/cells;
- optional confirmed Supplier-copy proposals;
- Service Offer version lock version;
- idempotency key for create only.

Outputs include:

- Service Offer price definition;
- selected category summary;
- status `created`, `updated`, or `removed`.

### 8.2 Transaction boundary

The typed command owns one transaction and the canonical lock order:

1. Agency;
2. actor reloaded and rechecked through the Agency;
3. affected Suppliers in UUID order;
4. Departure;
5. Arrangement/version, selected exact source definitions, and copied Supplier components;
6. Service Offer/version, price definition, affected Client components, and bases.

Do not call `CreateServiceOfferPriceDefinition` or `UpdateServiceOfferPriceDefinition` from inside the typed command. Extract or reuse an already-locked component-normalization/replacement helper so both typed and Advanced paths retain the shipped M4B language and validations.

### 8.3 Category merge semantics

Create initializes the one Service price definition when absent and inserts the selected category cells.

Update:

1. detects the current supported graph;
2. partitions components by category key;
3. preserves all unaffected supported category components;
4. preserves safely separable non-category components only when the detector explicitly allows them;
5. replaces the selected category’s cells and their bases/provenance;
6. validates the complete resulting M4B graph;
7. bumps the Service Offer version once;
8. writes one bounded audit event.

Failure rolls back the whole selected-category save. It never modifies Supplier costs or sibling category terms.

Remove deletes only the selected category’s typed components. It removes the price definition only when no components remain and the resulting empty calculated definition would be invalid.

### 8.4 Read and preview services

- `CompileCruiseClientTermsWorkspace` — category summaries, selected matrix, provenance findings, editability, and Advanced links.
- `DetectCruiseClientTermShape` — definition/category-scoped compatibility and exact reconstruction.
- `PreviewCruiseClientTermSchedule` — write-free normalization and Single/Double/Triple Client preview from submitted cells.
- `CompileCruiseScenarioReview` — write-free Stop G review combining Client evaluation, Supplier economics, provenance findings, and capacity context.
- `SupplierCostComponentCopyFingerprint` — pure canonical digest.
- `CompareSupplierCostCopyProvenance` — pure comparison result.

No preview service emits audit events, idempotency records, version bumps, or durable totals.

### 8.5 Audit

Add one action only if no existing action accurately covers the typed composite save:

- `service_offer.cruise_client_terms_saved`

Details may include Service Offer/version IDs, selected option ID, affected component count, copied-source count, and status. Do not embed amounts, rate keys, complete matrices, Supplier graphs, or scenario results.

---

## 9. Routes and authorization

Add under the existing Cruise Arrangement resource:

```text
GET    .../cruise/client-terms
POST   .../cruise/client-terms
PATCH  .../cruise/client-terms
DELETE .../cruise/client-terms
POST   .../cruise/client-terms/preview
```

Controller: `CruiseClientTermsController`.

- Every action, including `show`, requires `manage_departures`; unauthorized access returns not found.
- Records load through `Current.agency` and the route’s Departure and Arrangement.
- The page requires a compatible Slice 2C connection.
- A mismatched Arrangement/Service/option/source ID returns not found or invalid as appropriate.
- Default `show` renders saved summaries without an open editor.
- Editor state opens only from an explicit query or action.
- Successful mutation redirects `303` to the summary without the editor query.
- Invalid mutation renders `422`, preserves the matrix and copy selections, focuses `#form-error-summary`, and links field errors.
- Generic Service Offer pricing remains the Advanced path with a validated return context.

---

## 10. Workspace interaction contract

### 10.1 Summary-first page

The default page clearly separates saved information from editing. It shows one category card per Slice 2C option:

```text
O1 — Prime Oceanview                                      Ready
Single $3,555.00 · Double $3,862.00 · Triple $4,594.50
4 price-component rows · 16 entered cells

[Edit terms]  [Review scenarios]
```

Incomplete categories show exact next actions rather than a generic incomplete label.

### 10.2 Editor

Only one category editor is open at a time. Its heading names the action and category:

> Edit Client terms — O1 Prime Oceanview

The primary control is a table modeled on the shipped Supplier rate matrix:

| Client price component | Single | 1st | 2nd | Additional |
| --- | ---: | ---: | ---: | ---: |
| Cruise fare | input | input | input | input |
| NCCF | input | input | input | input |
| Discount | input | input | input | input |
| Taxes and fees | input | input | input | input |
| Single supplement | input | — | — | — |

Staff may add supported custom surcharge or discount rows. Repeated-value/fill-across affordances may be reused from the Supplier matrix, but copying across cells occurs only through an explicit Staff action.

### 10.3 Matrix usability

- Row labels remain visible at narrow widths through the established responsive table pattern.
- Keyboard order proceeds row by row and then to preview/save actions.
- Currency is displayed once in context and on monetary controls where needed.
- Discounts are visually signed but entered as positive amounts.
- Blank and explicit zero are distinguishable.
- Saved summaries never expose binding IDs, option IDs, rate keys, membership enums, or provenance digests.

### 10.4 Supplier-copy proposal

“Start from Supplier terms” opens a review state before any write. Each proposed cell shows:

- Supplier source label and current value;
- target Client row and traveler position;
- proposed Client role and amount;
- whether one source expands to several cells;
- unsupported sources with a concise reason;
- editable proposed Client value.

After save, a copied cell may show:

```text
Started from Supplier rate: $1,624.00
Source unchanged · Open source · Remove source link
```

Changed, missing, and unknown states use text and an appropriate badge; color is never the only signal.

### 10.5 Preview

Below the matrix, show write-free scenario totals:

- Single — sum of applicable `single` cells;
- Double — sum of `first` and `second` cells;
- Triple — sum of `first`, `second`, and `additional` cells when supported.

The preview identifies pending cells rather than treating them as zero. It is advisory until save and is never persisted.

---

## 11. Scenario Review contract

### 11.1 Compiler

`CompileCruiseScenarioReview` operates on the selected connected category and constructs the shipped evaluator inputs:

| Scenario | Occupancy positions | Persons | Resource units |
| --- | --- | ---: | ---: |
| Single | `single` | 1 | 1 |
| Double | `first`, `second` | 2 | 1 |
| Triple | `first`, `second`, `additional` | 3 | 1 |

Every occupancy position carries the selected option’s stored Client rate-category key. The scenario selects that option and its exact source activation/binding.

### 11.2 Evaluation reuse

Reuse, without a parallel arithmetic engine:

- `EvaluateClientPrice` for Client lines and total;
- `EvaluateIndicativeScenarioEconomics` for attributable Supplier economics and margin;
- shipped Supplier cost forecast evaluation for gross/commission/net detail;
- shipped capacity projection for current context.

If existing services do not expose sufficiently granular known results, add a read adapter over their outputs rather than copying their formulas.

### 11.3 Review presentation

For each supported scenario, show:

```text
O1 — Double

Client
  First traveler fare                         $…
  Second traveler fare                        $…
  NCCF                                        $…
  Taxes and fees                              $…
  Discount                                   −$…
  Client total                                $…

Supplier
  Gross cost                                  $…
  Expected commission                         $…
  Net Supplier cost                           $…

Indicative margin                             $…

Capacity observed Sep 24, 2026 at 14:35 UTC
  … cabins currently available for planning

Needs attention
  Additional-traveler Client fare is missing.
```

### 11.4 Partial knowledge

- Missing Client input does not hide known Supplier gross or known Client lines.
- Missing commission does not hide Supplier gross or Client revenue.
- One incomplete category does not hide another category.
- One incomplete scenario does not hide complete scenarios.
- Margin appears only when the required Client and Supplier inputs are sufficient and currency-compatible.
- Capacity context is time-labeled and explicitly not promised inventory.

### 11.5 Provenance findings

Changed, missing, or unknown copied sources become actionable findings in the existing readiness/review model. They do not automatically make a mathematically complete Client price incomplete, but readiness may require Staff review before publication according to the accepted Slice 2D amendment to the readiness catalog.

The Accept pass must name the exact finding codes and disposition behavior rather than leaving generic “source changed” prose.

---

## 12. Lifecycle and successor behavior

- Draft Service Offer versions are editable.
- Published/frozen versions are read-only.
- When an editable successor exists and both the Slice 2C connection and Client-term graph are compatible, edits target that successor.
- Client component IDs may change during successor copy, but category key strings and provenance pointers/fingerprints remain unchanged.
- A later Supplier Arrangement successor does not move the Service Offer’s exact source binding or recopy Client values.
- Unsupported successor graphs remain readable through Advanced.
- Removing a cabin category remains blocked while same-version Client components use its rate key, as shipped by Slice 2C.

---

## 13. Delivery slices

### 2D-A — Provenance and typed-term foundation

Ship:

- migration and database integrity;
- successor graph copy of provenance;
- canonical fingerprint and comparison services;
- typed detector/workspace compiler;
- category-scoped create/update/remove commands;
- service-level proof without new ordinary UI.

**Exit:** O1 terms can be saved independently with durable, comparable one-source provenance while sibling categories and Supplier facts remain unchanged.

### 2D-B — Client price matrix

Ship:

- Cruise Client-terms routes/controller;
- summary-first category cards;
- one-category traveler-position matrix;
- independent entry and reviewed Supplier-copy proposal;
- write-free matrix preview;
- Advanced fallback and recovery proof.

**Exit:** Staff can enter and reopen O1 fare/NCCF/tax/discount rows without using the generic graph editor.

### 2D-C — Scenario Review and readiness integration

Ship:

- `CompileCruiseScenarioReview`;
- Single/Double/supported-Triple review;
- known/pending Client and Supplier economics;
- time-labeled capacity context;
- exact provenance finding codes and readiness integration;
- blocking Celebrity system proof.

**Exit:** Staff can explain Client revenue, Supplier economics, provenance state, and the next required action for O1 without persisted scenario facts.

The overall Slice 2D remains Accepted/not Shipped until 2D-A, 2D-B, and 2D-C are merged green and the ship documentation pins the final tip.

---

## 14. Proof contract

### 14.1 Persistence and command proof

- Provenance is all-null or all-present.
- Malformed fingerprints fail in PostgreSQL and Rails.
- Cross-Agency and cross-Departure source pointers fail.
- Frozen Client components reject provenance mutation.
- Successor copy preserves pointer, fingerprint, and timestamp.
- Fingerprint fixtures prove stable JSON, decimal normalization, null inclusion, and base ordering.
- IDs, labels, timestamps, and row positions do not alter the digest.
- Semantic source changes do alter the digest.
- Create retry returns the same definition without duplicate components or audit success.
- Stale Service Offer or Arrangement version leaves Client and Supplier graphs unchanged.
- O1 save preserves I1 and Advanced-safe siblings.
- Failed O1 save preserves the previous O1 graph.
- Removing O1 terms does not remove its option, binding, or rate key.
- Expected commission and informational allocations are never copy-eligible.
- One source may seed several cells; every cell retains exactly one source.
- Multi-source-to-one-cell proposals fail closed.

### 14.2 Detector and provenance proof

- Supported typed matrix reopens without normalization drift.
- Duplicate cells, unknown occupancy keys, unsupported percentage graphs, unreachable rate keys, and cross-category bases route Advanced unchanged.
- Independent, unchanged, changed, missing, and unknown states are each proven.
- Comparison writes nothing.
- Recopy requires explicit confirmation.
- Removing provenance retains the Client value.

### 14.3 Request proof

- Viewer receives not found for every Stop F–G route.
- Staff default visit shows summaries and no open form fields.
- Editor opens only from an explicit category action.
- Invalid save returns `422`, preserves all cells and selections, and focuses the error summary.
- Success redirects `303` without reopening the editor.
- Submitted option/source IDs are Agency-, Departure-, Arrangement-, version-, and Service-scoped.
- Preview writes no definitions, components, idempotency rows, audit events, or version bumps.
- Advanced fallback retains a safe return path.

### 14.4 System and accessibility proof

1. Enter O1 terms independently in the matrix.
2. Start selected O1 cells from Supplier terms, review, edit, and save.
3. Reopen O1 with values and provenance unchanged.
4. Add I1 terms without changing O1.
5. Change a Supplier source and see a changed finding without Client overwrite.
6. Keep the Client term, recopy it, and remove its source link as separate flows.
7. Review Single, Double, and Triple; pending Triple does not hide complete Single/Double.
8. Unsupported Client graph remains Advanced and unchanged.
9. Keyboard-only entry and recovery at 375 and 1400 pixel widths.
10. No horizontal page overflow; a matrix may use an intentional labeled internal scroll region only when the responsive contract permits it.

### 14.5 Blocking Celebrity proof

Using the accepted Celebrity fixture:

- exactly one Cruise Service exists;
- O1 remains one option in the exactly-one category group;
- O1’s stored key scopes every O1 Client component;
- fare, NCCF, taxes/fees, discount, and any single supplement remain separately explained;
- expected commission is not Client revenue;
- copied source changes never overwrite Client amounts;
- Single, Double, and supported Triple use the correct option and binding;
- known Client and Supplier lines remain visible beside exact pending facts;
- no second Service Offer or price definition is created;
- no scenario total, margin, readiness result, recommendation, or capacity snapshot is persisted.

---

## 15. Documentation and ship boundary

At Accept:

- mark this document Accepted;
- amend parent §§12.6–12.7, 14, 19, 21, and 23 with the exact commands, routes, fingerprint serialization, finding codes, and delivery split;
- update `docs/README.md`, `AGENTS.md`, roadmap, terminology, and `docs/ui/interface-contract.md` only where the accepted contract requires it;
- pin the green Slice 2C shipped base.

During implementation, do not mark Slice 2D Shipped. After each delivery, record 2D-A/2D-B/2D-C status independently. Mark the whole slice Shipped only after all three deliveries merge green to `main` and the blocking Celebrity proof passes.

---

## 16. Acceptance decisions

Acceptance locks the following:

1. One Service Offer price definition with category-scoped components.
2. A matrix modeled on Supplier rate authoring but persisted entirely as Client price components.
3. One nonblank matrix cell equals one Client component.
4. Blank is pending/not applicable; explicit zero is a real value.
5. Single is an occupancy position, not a stored all-in total.
6. Supplier copy is opt-in, reviewed, and never live synchronization.
7. Each Client component has at most one Supplier provenance source; one source may seed several cells.
8. First-release copy supports compatible fixed/unit-rate charges and credits only.
9. Expected commission and informational allocations are never Client revenue.
10. Category saves preserve sibling categories and fail closed on unsafe graphs.
11. Scenarios and all review arithmetic are write-free.
12. Package work, target pricing, persisted scenarios, and richer presentation modes remain later work.

---

## 17. Exit criteria

Slice 2D is complete when Staff can author and reopen O1 Client terms through a clear traveler-position matrix, optionally trace eligible cells to reviewed Supplier origins without live synchronization, and review Single, Double, and supported Triple Client/Supplier economics with exact pending facts and current capacity context.

The exit is not satisfied by merely exposing the generic price-component editor, copying Supplier amounts automatically, storing scenario totals, or showing a mathematically complete total that cannot be explained by its independent Client and Supplier facts.
