# M4B — Client pricing and anonymous scenario preview

**Status:** Accepted 2026-09-20. Implementation authority for M4B tables, commands, calculator, and Staff UI only. Shipped. Required CI is green on [PR #118](https://github.com/tswarren/DepartureDesk/pull/118) tip [`af87db8`](https://github.com/tswarren/DepartureDesk/commit/af87db8e9822e9143ae5e69ddbdda69eb0fc4b0a).

**Parent authority:** [M4 — Offers and pricing](m4-offers-and-pricing.md) (Accepted 2026-09-20; not implementation authority for later slices), [ADR 0014](../adr/0014-client-offers-publication-and-supply-compatibility.md) (Accepted; not implementation authority), and [M4.0](m40-task-flow-and-contract.md) (Accepted; documentation/task-flow gate only). MVP occupancy exception and roadmap M5 Charge-posting amendment are already in those documents.

**Implementation base:** Documentation pin [`ea6d63e`](https://github.com/tswarren/DepartureDesk/commit/ea6d63e875d917415da061e7b1a64b382c5f91a1) (M3 complete). Production M4B started from shipped [M4A](m4a-service-definitions-and-sources.md) merge [`36f324d`](https://github.com/tswarren/DepartureDesk/commit/36f324db4370fdc74eb137640d8a190648fec262). Required CI is green on this slice tip [`af87db8`](https://github.com/tswarren/DepartureDesk/commit/af87db8e9822e9143ae5e69ddbdda69eb0fc4b0a). Later slices start from the M4B `main` merge or a later descendant.

**Authority:** Parent and ADR 0014 as above. [ADR 0001](../adr/0001-money-and-currency.md) governs money; [ADR 0011](../adr/0011-supplier-cost-definitions-and-forecast-evaluation.md) governs the separate Supplier cost forecast. Lock order inherits [M4A](m4a-service-definitions-and-sources.md). Later: [M4C](m4c-packages-choices-and-client-terms.md) (shipped) · [M4D](m4d-publication-and-live-feasibility.md) (Accepted; not shipped) · [M4E](drafts/DepartureDesk-M4E-acceptance-and-hardening-draft.md).

## Goal and slice boundary

Staff can add an explainable **Client** price to an M4A Service Offer draft and test it against anonymous quantities, occupancy positions, nights, and Client rate categories. The ordinary form starts with one fixed or unit price; advanced percentages, tax treatment, discounts, and occupancy rules appear when needed. A read-only preview explains component math and, when supported by selected M3 cost facts, optional **indicative scenario economics**. No scenario becomes demand or a money posting.

M4B implements service-owned draft pricing and a calculator that can accept a **transient bundled Package price** or a service-sum composition in tests and preview sketches. M4C will persist Package composition, bundled price definitions, choice templates, and scoped terms. M4D will publish and freeze complete graphs and compute selection state. Do not add an empty Package table or force a price onto each component of a future bundled Package merely to make the Vineyard example run in M4B. Do not add `independently_sellable`. Bundled completeness is “this service version has no price definition.”

No ADR 0004 namespace. No Administrator publication override. Never reuse `override_supplier_planning_terms`. Create forms stay price-free; price attaches to the existing draft show/edit path.

## Staff path

1. Open a saved M4A Service Offer draft and choose a familiar pattern: **fixed per service**, **per person**, **per resource**, **per night**, **per resource-night**, or **occupancy positions**. Prefill a plausible **quantity basis** from Item/Occurrence context, but never fill Client amounts from Supplier cost. Show Departure currency as read-only. A simple price takes the amount and the quantity basis, not a component editor.
2. Enter a small anonymous example, such as two people in one cabin for seven nights or one person in one room for an extra night. When the pattern needs them, supply resource count, persons, nights, ordered occupancy positions, and an M4 Client rate category. Staff see the resulting Client amount and short derivation immediately. Missing required inputs produce a field-specific explanation and leave the draft intact.
3. Staff open **Advanced price details** only for named adjustments, several rate categories, per-person/resource-night components, a percentage with an explicit earlier-component base, tax included in a stated base, or other supported complex cases. The ordinary one-source form never requires a generic formula editor or a Supplier participant category.
4. The optional cost/margin disclosure uses the scenario's quantities without saving them as M3 usage assumptions. A draft pricing preview is not a publication/readiness decision and shows no guaranteed inventory. M4D will add current capacity and lifecycle selection status to its final review.

**Viewer:** M4B UI is draft-only. Unpublished price forms are `manage_departures` only. Viewers (`view_departures`) do not open M4B pages. After M4D they may read published Client-facing price explanation only. Indicative margin and Supplier cost stay `manage_departures`. JSON/partials must not leak cost or margin if a Staff preview is later reused. Shipped M3 Arrangement cost-forecast Viewer access is unchanged.

After departure, hide price create/edit; keep **Remove price** (and discard draft) as cleanup. Currency correction remains remove-then-correct.

## Persistence tables

Client-owned shape parallel to M3C, not Supplier cost tables. Three tables only. Client rate labels and occupancy selectors live on components (`client_rate_category_key`, `occupancy_position_key`). Do not add a rate-category directory or reuse `SupplierCostParticipantCategory`.

| Table | Contract |
| --- | --- |
| `service_offer_price_definitions` | Version-owned Client price definition for an exact Service Offer draft version. One per offer version. Departure `operating_currency`. Modes `calculated` or `zero_price` (zero requires named reason). Write authority is the offer version `lock_version`. |
| `service_offer_price_components` | Typed Client roles, calculation kinds, quantity bases, amounts (`bigint` minor units), rates (`numeric`), order, rounding, optional selectors. |
| `service_offer_price_component_bases` | Explicit links from a percentage component to **earlier** rounded components in the same definition. An included-tax allocation line is not a valid percentage base. |

No STI, expression tree, scripting, or precomputed-total record. The same evaluator interface must later accept M4C's Package-owned price definition without a second pricing language. Do not copy M3C `minimum_amount_shortfall` / `minimum_quantity_shortfall` or `single_occupancy_*` quantity bases. Vineyard supplement is Package-level formula on the calculator DTO.

Child tables use `DraftVersionDefinition` (`service_offer_version`) plus the M4A freeze trigger with `FOR SHARE` on the parent offer version for INSERT/UPDATE/DELETE.

## Client price definition contract

Price definitions belong to an exact Service Offer **draft version**, not to an Arrangement Item or cost source.

### Currency and amounts

Price currency equals Departure `operating_currency`. Store nonnegative fixed magnitudes in `bigint` minor units. Decimal rates use exact `numeric`/`BigDecimal`, no float. Negative direction is a typed role, never an unexplained negative persisted amount. Reject overflow, NaN, unsupported currency and silently relabeled values.

### Client roles

`base_price`, `named_discount`, `named_surcharge`, `tax_fee`. A discount subtracts; a surcharge or additive tax adds; an included tax is an explanatory allocation already inside the selected gross amount. Supplier `supplier_charge`, `supplier_credit`, and `expected_commission` roles are not Client roles.

### Calculation kinds and fields

- `fixed` — `amount_minor_units` required; quantity basis `service_instances` (once per selected service); `rate` and percentage treatment/bases must be absent.
- `unit_rate` — `amount_minor_units` required; quantity basis required from `persons`, `resource_units`, `nights`, `person_nights`, `resource_nights`, `occupancy_positions`, `occupancy_position_nights`; `rate` and percentage treatment/bases must be absent.
- `percentage` — `rate` required (exact `numeric`); one or more explicit earlier-component bases; `percentage_treatment` `additive` or `included`; `amount_minor_units` absent. Additive applies the component’s role direction to `base × rate`. Included tax at rate `r` extracts `base × r ÷ (1+r)` as an **allocation line with signed Client-revenue effect 0**; it must not add to the total again and must not be selected as a later percentage base (later percentages use the already-gross rounded components that contain the included tax).

`tax_fee` may be `fixed`, `unit_rate`, or `percentage`. When treatment is `included`, the line is explanatory allocation only. Nights are **billable** nights supplied by the scenario; a date-range difference is a suggestion, not an automatic billable quantity.

### Selectors

`NULL` `client_rate_category_key` or `occupancy_position_key` means **all**. A non-NULL value is an exact selector. One `base_price` per exact selector tuple is unique (NULLS NOT DISTINCT). A generic (`NULL`) `base_price` that overlaps a specific `base_price` for the same scenario is incomplete/invalid; uniqueness does not settle that overlap. Two specific bases may coexist when their selectors cannot apply to the same scenario position (for example first vs additional). Do not apply a generic fare to leftover demand when a specific sibling also matches.

### Percentage, order, rounding

A decimal multiplier with only explicit links to **earlier rounded revenue components** in the same price definition. Each link states add/subtract contribution to the percentage base. Reject self, forward, cyclic, cross-definition, and included-tax-allocation references. A complete manual order determines evaluation. Mode `half_up`; calculate each applicable component against its aggregate scenario quantity with `BigDecimal`, round **that component** to the currency minor unit, then use its rounded **revenue** result as a later base. Distinct rate-category/position components evaluate separately. Total = sum of signed rounded **revenue** effects (included-tax signed effect is 0). Do not round the whole unrounded basket or each identical traveler first.

### Readiness and bundled completeness

A definition with no usable base, missing required rate/quantity, overlapping generic/specific bases, undefined or included-tax percentage base, or inconsistent currency is incomplete, never zero. An explicit zero Client price needs named `zero_price` mode and reason rather than an empty component list. A bundled package-only service with **no** own price is **complete**. Service-sum still requires each selected priced component.

Database checks and owner constraints enforce Agency/Departure/version integrity, amounts, rates, types, kind-specific nulls, order and base-link ancestry; percentage-base validation locks both referenced component rows in UUID order so a concurrent position or treatment change cannot commit a forward or included-tax link. Rails validates the same shapes and returns field errors. Price edits use the M4A draft optimistic lock, M4A lock order, and bounded audit action. Until M4D, M4B has **draft** price definitions only.

**Departure currency correction:** Extend `UpdateDeparture` and `CorrectDepartureCurrency` when the first M4 price row is introduced. A retained draft price is a currency-bearing fact: ordinary correction cannot change operating currency while that row exists; removing an eligible never-published draft is an explicit prior action. Never convert or relabel an amount.

## Anonymous scenario and calculator

One Client-price language, owner-agnostic. Input is a price-definition graph (Active Record or in-memory DTO) plus an anonymous scenario: resource count, occupancy profiles with ordered positions and optional Client rate category, billable nights, selected service quantity, optional selected alternative-binding / option IDs, optional enrollment denominator. No names, household, payer, Traveler, Hold or Allocation.

Require a positive, internally consistent quantity only if a selected component needs it. The occupancy list is **one resource’s pattern**; `resource_units` defaults to 1. Selector-scoped `persons`, `person_nights`, `occupancy_positions`, and `occupancy_position_nights` use `matching_positions.size × resource_units`. When both `persons` and an occupancy list are supplied, persons must equal that expanded count or the price is incomplete. More than one `first` or `single` key means the list is expanded across cabins and is incomplete. Do not ask for nights for a flat fare or a rate category for a category-free fare.

Output: complete/incomplete with field-level blockers; evaluated component lines with source definition IDs, quantities, rounding, included/additive treatment, signed Client revenue effects, and the final amount/currency. Calculate in memory from one coherent read snapshot; do not save hypothetical demand, amounts, occupancy, totals, or margin. A preview labels its observation time.

A specific selector applies only when the scenario names that category/position. A `NULL` selector means all. If a generic `base_price` and a specific `base_price` can both apply to the same scenario, the definition is invalid.

**Transient Package shapes (tests/sketches only):**

- Bundled: one Package revenue source. Double with two travelers and no other priced choices: `2 × P`. Single: `P + round_minor(P × s)` with stored `s`. Illustrative Vineyard `s = 1.0`. Supplement is Package revenue; it must not also appear as a lodging occupancy charge for the same commercial supplement.
- Service-sum: sum evaluated service totals plus **named** Package adjustments in explicit later order.

M4C integrates this evaluator into a real Package form. Count only selected options once M4C supplies choices.

## Narrow Vineyard bundled occupancy exception

The MVP occupancy exception is already accepted. Let `P` be the already rounded base per-person bundled Package price. For an anonymous **double** scenario with two travelers and no other priced choices, Package base revenue is `2 × P`. For a **single** scenario, Package base revenue is `P + round_minor(P × s)` where `s` is the explicitly stored single-occupancy supplement rate. Round the supplement line using `half_up`. The supplement is Package revenue and cannot also appear as a lodging service/resource occupancy charge for the **same** commercial supplement. This exception does not turn M3C `single_occupancy_*` **cost** bases into Client pricing.

## Indicative scenario economics

Do **not** call `EvaluateSupplierCostOccupancyPreview` or `EvaluateSupplierCostForecast#occupancy_preview` with a stored `SupplierCostAssumption` as scenario demand.

M4B adds a **pure** entry point that accepts ephemeral scenario quantities, reuses constrained arithmetic, and writes no `SupplierCostAssumption`, occupancy profile, capacity event, or other M3 mutation.

**Attribution (not Arrangement-wide totals):**

- Collect candidate `SupplierCostSource` rows from the offer version’s **selected** bindings (required all apply; each alternative group uses **exactly one** selected member on this offer; IDs outside the version are unknown).
- Match a source when its Item, and Occurrence/Resource when the binding pins them, equal the bound identities. Item-only bindings do not pull Occurrence- or Resource-scoped sources that the offer did not pin.
- Deduplicate by cost-source identity when several bindings reach the same source.
- If no source matches, more than one equally specific source matches the same pin, or a required binding has no attributable source while others do in a way that leaves the set unprovable → margin **unknown**. Do **not** fall back to `EvaluateSupplierCostForecast` for the whole Arrangement.
Evaluate only the attributed, deduplicated sources with the same occupancy pattern × `resource_units` as Client price. Stage: contracted if forecast-ready, else estimate if forecast-ready; never add stages; missing attributed source → margin **unknown**. If any component on that **selected** stage has a Supplier `participant_category_id`, margin is **unknown** (no mapping from Client rate categories). An unused estimate must not force unknown. Cross-Agency/Departure and inconsistent-currency sources cannot contribute a numeric margin.

When complete and unambiguous:

`indicative scenario margin = Client revenue + expected_commission − forecast_supplier_cost`

from the attributed set only. Use `expected_commission_minor_units` and `forecast_supplier_cost_minor_units`. Do **not** also subtract `expected_net_cost_after_commission`. Expected commission is forecast only, not cash. Do not add Supplier-collected money as Client revenue.

Shared Arrangement-wide cost (coach): even when attributed, require an explicit enrollment denominator on the scenario and label **scenario economics**; otherwise margin **unknown**. Do not subtract the whole coach cost from one hypothetical sale.

Client-price JSON/partials never include cost or margin. A separate `manage_departures` economics result may include them.

## Commands, concurrency, and lifecycle

Dedicated commands (do not overload `UpdateServiceOfferDraft`):

- `CreateServiceOfferPriceDefinition` — `AgencyCommandIdempotencyKey`; simple pattern+amount or explicit components. Departure must be `draft` or `active`.
- `UpdateServiceOfferPriceDefinition` — atomic replace of the component set + bases. Stale lock rejects with no partial write. Departure must be `draft` or `active`.
- `RemoveServiceOfferPriceDefinition` — eligible never-published draft only. Allowed on a retained departed draft as cleanup.

**Removal** of a never-published price is the only departed cleanup. Changing amounts or reordering after departure expands the proposed sale and is rejected.

Session-derived Agency, `manage_departures`, expected lock version, M4A lock order. Price-only writes: Agency → actor recheck → Departure → Service Offer → draft version, then children. Indicative-economics reads that lock M3 rows: Agency → actor → Suppliers UUID order → Departure → Arrangement/version → Offer/version. Nested commands must not reacquire an earlier lock. Advance the offer-version lock on every successful price write. Replay keyed create before rejecting a stale lock.

Audit `service_offer.price_created`, `service_offer.price_updated`, `service_offer.price_removed` with bounded IDs/action context; never the full pricing graph or anonymous scenario. Read-only evaluator calls issue no audit. Unauthorized IDs return not found. No new Administrator override.

## Scenario proof without invented facts

| Scenario | M4B proof | Fixture discipline |
| --- | --- | --- |
| Celebrity O1 cruise | Anonymous first/second, additional, and single occupancy positions; per-person fare, named discount, tax/fee, and optional extra-night **shape**; explicit calculation/rounding and incomplete-input error. | The M3F ledger's O1 $1,624/$406 fares, $320 NCCF, −$150/−$37.50 discounts and $137 taxes/fees are **Supplier cost components** in M3C. Do not silently make them Client fares. Use an explicitly labeled illustrative Client-price fixture until authoritative Client prices exist. |
| Hilton extra nights | Additional person and room-night patterns; billable nights independently entered; no guessed Client inclusion, tax, or hotel rates. | M3F labels Hilton rates and adult tax M3C test values; they are not confirmed Client terms. |
| Vineyard | Transient bundled base `P`, double `2P`, single `P + round(P × 1.0)` **illustrative**; coach shared-cost margin unknown without enrollment; one dinner choice can be represented as a scenario selection shape, with no inferred surcharge. Bundled package-only services without own prices remain complete. | M3F confirms June 5–7, 2027 and 30-seat coach and separate Standard/Deluxe dinner Items; the hotel A/B nights and properties remain shape-only. M4C owns the actual dinner choice template and Package record. |

## Exit proof

1. One simple service price can be entered and understood without exposing percentage-base tables or a formula editor; advanced controls preserve draft values and return field-level recovery after invalid review. Keyboard and 375/768/1280/1400 views follow M4.0 friction **rules**. Viewer has no M4B form.
2. Exact integer/decimal math for all supported bases and roles; included tax has revenue effect 0 and cannot be a later percentage base; generic-vs-specific selector overlap rejected; kind-specific field presence/absence; line rounding versus final-total rounding; overflow and invalid inputs. Direct SQL fails invalid same-owner, type and link shapes.
3. Separate Client rate categories and occupancy from M3C Supplier participant categories; Celebrity occupancy math with **illustrative Client** prices; billable hotel extra nights explicit; Vineyard double/single illustrative formula yields one bundled Package revenue source without duplicate supplement.
4. The pure cost entry point does not persist assumptions. Attribution uses bound Item/Occurrence/Resource context, deduplicates, and returns unknown when ambiguous; Arrangement-wide forecast totals are not used as one offer’s cost. Shared coach fixed cost stays unknown absent enrollment. Viewer/JSON contains no cost or margin.
5. A retained M4 price row blocks both ordinary Departure currency-changing commands; deleting an eligible draft can allow correction. Departed **update** is rejected and **remove** is allowed. Anonymous preview writes no M3 assumption, named person, Client demand, capacity event, Charge or posted money.
6. Full required repository CI is green on [PR #118](https://github.com/tswarren/DepartureDesk/pull/118) tip [`af87db8`](https://github.com/tswarren/DepartureDesk/commit/af87db8e9822e9143ae5e69ddbdda69eb0fc4b0a). M4C receives the calculator interface, bundled-completeness rule, and Package pricing owner contract; M4D receives publish-readiness checks and the immutable graph to freeze.

**Exit:** Staff can price and anonymously preview a Service Offer draft with explainable Client arithmetic and optional correctly qualified economics. The Vineyard bundled and service-sum patterns are proven **in memory** for M4C integration. No Package persistence, published offer, guaranteed inventory, or Client money exists because of M4B.
