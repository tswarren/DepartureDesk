# M4B — Client pricing and anonymous scenario preview

**Status:** Draft for review, 2026-09-20. Proposed slice contract; not implementation authority until accepted.

**Prerequisite:** Accepted [M4 parent](../m4-offers-and-pricing.md), [ADR 0014](../../adr/0014-client-offers-publication-and-supply-compatibility.md), and [M4.0](../m40-task-flow-and-contract.md) (Accepted 2026-09-20; not implementation authority for M4A–M4E). MVP bundled single-occupancy amendment and roadmap M5 due-Charge amendment are already in those documents. **Shipped** M4A service/source drafts on a pinned CI-green descendant of [`ea6d63e`](https://github.com/tswarren/DepartureDesk/commit/ea6d63e875d917415da061e7b1a64b382c5f91a1). [M4A draft](DepartureDesk-M4A-service-definitions-and-sources-draft.md) is a planning input, not proof M4A has shipped. Verify the accepted M4A contract and merge SHA before this slice is accepted or coded. Coding slices reconfirm required CI on the branch tip.

**Authority:** Parent and ADR 0014 as above. [ADR 0001](../../adr/0001-money-and-currency.md) governs money; [ADR 0011](../../adr/0011-supplier-cost-definitions-and-forecast-evaluation.md) governs the separate Supplier cost forecast. Lock order inherits [M4A](DepartureDesk-M4A-service-definitions-and-sources-draft.md). Later: [M4C](DepartureDesk-M4C-packages-choices-and-client-terms-draft.md) · [M4D](DepartureDesk-M4D-publication-and-live-feasibility-draft.md) · [M4E](DepartureDesk-M4E-acceptance-and-hardening-draft.md).

## Goal and slice boundary

Staff can add an explainable **Client** price to an M4A Service Offer draft and test it against anonymous quantities, occupancy positions, nights, and Client rate categories. The ordinary form starts with one fixed or unit price; advanced percentages, tax treatment, discounts, and occupancy rules appear when needed. A read-only preview explains component math and, when supported by selected M3 cost facts, optional **indicative scenario economics**. No scenario becomes demand or a money posting.

M4B implements service-owned draft pricing and a calculator that can accept a **transient bundled Package price** or a service-sum composition in tests and preview sketches. M4C will persist Package composition, bundled price definitions, choice templates, and scoped terms. M4D will publish and freeze complete graphs and compute selection state. Do not add an empty Package table or force a price onto each component of a future bundled Package merely to make the Vineyard example run in M4B.

No ADR 0004 namespace. No Administrator publication override. Never reuse `override_supplier_planning_terms`.

## Staff path

1. Open a saved M4A Service Offer draft and choose a familiar pattern: **fixed per service**, **per person**, **per resource**, **per night**, **per resource-night**, or **occupancy positions**. Prefill a plausible pattern from Item/Occurrence context, but never fill Client amounts from Supplier cost. Show Departure currency as read-only. A simple price takes the amount and the quantity basis, not a component editor.
2. Enter a small anonymous example, such as two people in one cabin for seven nights or one person in one room for an extra night. When the pattern needs them, supply resource count, persons, nights, ordered occupancy positions, and an M4 Client rate category. Staff see the resulting Client amount and short derivation immediately. Missing required inputs produce a field-specific explanation and leave the draft intact.
3. Staff open **Advanced price details** only for named adjustments, several rate categories, per-person/resource-night components, a percentage with an explicit earlier-component base, tax included in a stated base, or other supported complex cases. The ordinary one-source form never requires a generic formula editor or a Supplier participant category.
4. The optional cost/margin disclosure uses the scenario's quantities without saving them as M3 usage assumptions. A draft pricing preview is not a publication/readiness decision and shows no guaranteed inventory. M4D will add current capacity and lifecycle selection status to its final review.

**Viewer:** M4B UI is draft-only. Unpublished price forms are `manage_departures` only. Viewers (`view_departures`) do not open M4B pages. After M4D they may read published Client-facing price explanation only. Indicative margin and Supplier cost stay `manage_departures`. JSON/partials must not leak cost or margin if a Staff preview is later reused. Shipped M3 Arrangement cost-forecast Viewer access is unchanged.

## Persistence tables

Client-owned shape parallel to M3C, not Supplier cost tables:

| Table | Contract |
| --- | --- |
| `service_offer_price_definitions` | Version-owned Client price definition for an exact Service Offer draft version. Departure `operating_currency`. |
| `service_offer_price_components` | Typed roles, quantity bases, amounts (`bigint` minor units), rates (`numeric`), order, rounding. |
| `service_offer_price_component_bases` | Explicit links from a percentage component to **earlier** rounded components in the same definition. |

No STI, expression tree, scripting, or precomputed-total record. The same evaluator interface must later accept M4C's Package-owned price definition without a second pricing language.

## Client price definition contract

Price definitions belong to an exact Service Offer **draft version**, not to an Arrangement Item or cost source.

| Concept | Contract |
| --- | --- |
| Currency and amounts | Price currency equals Departure `operating_currency`. Store nonnegative fixed magnitudes in `bigint` minor units. Decimal rates use exact `numeric`/`BigDecimal`, no float. Negative direction is a typed role, never an unexplained negative persisted amount. Reject overflow, NaN, unsupported currency and silently relabeled values. |
| Simple unit price | A fixed amount applies once per selected service instance. Unit rates use an explicit basis overlapping M3C where they match: `persons`, `resource_units`, `nights`, `person_nights`, `resource_nights`, `occupancy_positions`, or `occupancy_position_nights`. Do **not** copy M3C `single_occupancy_*` **cost** bases as Client pricing except the named bundled-Package variant below. Nights are **billable** nights supplied by the scenario/rule; a date-range difference is a suggestion, not an automatic billable quantity. |
| Rate categories | M4-owned Client rate labels and exact selectors. A scenario names an anonymous category/position; it never reuses M3C `SupplierCostParticipantCategory` or creates a Traveler. Prevent two conflicting base fares for the same selected category/position, while allowing clearly named additive adjustments. |
| Client roles | Base price, named discount, named surcharge, and tax/fee. A discount subtracts; a surcharge or additive tax adds; an included tax is an explanatory allocation already inside the selected gross amount. Supplier `supplier_charge`, `supplier_credit`, and `expected_commission` roles are not Client roles. |
| Percentage | A decimal multiplier with only explicit links to **earlier rounded components** in the same price definition. Each link states add/subtract contribution to the percentage base. Reject self, forward, cyclic and cross-definition references. A percentage discount/surcharge/additive tax applies its typed direction; an included tax at rate `r` extracts `base × r ÷ (1+r)` for display and never adds it to revenue again. |
| Ordering and rounding | A complete manual order determines evaluation. Initial mode `half_up`; calculate each applicable component against its aggregate scenario quantity with `BigDecimal`, round **that component** to the currency minor unit, then use its rounded result as a later base. Distinct rate-category components evaluate separately. Total = sum of signed effects of rounded components. Show base, quantity, rate, rounding boundary, signed effect, included allocation, and total; do not round the whole unrounded basket or each identical traveler first as a shortcut. |
| Readiness | A definition with no usable base, missing required rate/quantity, invalid selector overlap, undefined percentage base, or inconsistent currency is incomplete, never zero. An explicit zero Client price, if genuinely intended, needs a named zero-price mode and reason rather than an empty component list; no automatic zero from absent data. |
| Bundled completeness (M4C handoff) | A bundled package-only service with **no** own price is **complete**. Service-sum still requires each selected priced component. |

Database checks and owner constraints enforce Agency/Departure/version integrity, amounts, rates, types, order and base-link ancestry; Rails validates the same shapes and returns field errors. Price edits use the M4A draft optimistic lock, M4A lock order, and bounded audit action. Later M4D freezes the full published definition graph in Rails and PostgreSQL before any publication is enabled. Until then M4B has **draft** price definitions only.

**Departure currency correction:** Extend `UpdateDeparture#reject_currency_change_with_cost_definitions!` and `CorrectDepartureCurrency` when the first M4 price row is introduced, using the same pattern as `SupplierCostDefinition`. A retained draft price is a currency-bearing fact: ordinary correction cannot change operating currency while that row exists; removing an eligible never-published draft is an explicit prior action. Published prices remain frozen after M4D. Never convert or relabel an amount.

## Anonymous scenario and price outputs

| Input or output | Rule |
| --- | --- |
| Input shape | Typed resource count, anonymous occupancy profiles with ordered positions and optional Client rate category, billable nights, selected service quantity, and explicit option/alternative IDs if later M4C supplies them. No names, household, payer, Traveler, Hold or Allocation. |
| Validation | Require a positive, internally consistent quantity only if a selected component needs it. Occupancy positions must fit their resource unit count; repeated position/category selectors need unambiguous application. Do not ask for nights for a flat fare or a rate category for a category-free fare. |
| Price result | Complete/incomplete with field-level blockers; evaluated component lines with source definition IDs, quantities, rounding, included/additive treatment, signed Client revenue effects, and the final amount/currency. A service-sum composition adds evaluated service totals and **named** Package adjustments; a bundle is one Package revenue source plus permitted choice adjustments. |
| Read behavior | Calculate in memory from one coherent read snapshot with bounded preloads; do not save hypothetical demand, amounts, occupancy, totals, or margin. A preview labels its observation time and that selection/availability can change before M5. |

The initial M4B UI needs a service-level preview. A package demonstration can use a fixture or preview-only in-memory composition without persisting a Package or creating a Package route. M4C integrates this evaluator into a real Package form and assures one combined review. M4D applies exact-version publication readiness and live capacity. Once M4C supplies choices, count only selected options in a scenario; never double count an unselected alternative Supplier path.

## Narrow Vineyard bundled occupancy exception

The MVP occupancy exception is already accepted. Support this **Package-level** price variant in the reusable calculator and M4C price definition. Let `P` be the already rounded base per-person bundled Package price. For an anonymous **double** scenario with two travelers and no other priced choices, Package base revenue is `2 × P`. For a **single** scenario, Package base revenue is `P + round_minor(P × s)` where `s` is the explicitly stored single-occupancy supplement rate. The **illustrative** Vineyard `s = 1.0` yields `2 × P`; the scenario invents no value for `P`. Round the supplement line using the definition's `half_up` rule; apply any separately named adjustments only in their explicit later order and base. The supplement is Package revenue and cannot also appear as a lodging service/resource occupancy charge for the **same** commercial supplement.

This exception does not turn M3C `single_occupancy_*` **cost** bases into Client pricing, make Package occupancy a general resource-pricing override, or allocate the bundled revenue among coach, hotels and dinners. M4B proves the calculator against anonymous transient Package input; M4C persists and edits the price variant on an actual Package version. M5 later snapshots the selected Package result and avoids a duplicate lodging supplement line.

## Indicative scenario economics

Do **not** call `EvaluateSupplierCostOccupancyPreview` or `EvaluateSupplierCostForecast#occupancy_preview` with a stored `SupplierCostAssumption` as scenario demand. Those APIs require persisted occupancy profiles.

M4B adds a **pure** entry point on or beside `EvaluateSupplierCostForecast` that:

- Accepts ephemeral scenario quantities
- Reuses existing constrained arithmetic
- Writes no `SupplierCostAssumption`, occupancy profile, capacity event, or other M3 mutation

Stage rule stays as shipped: contracted if forecast-ready, else estimate if forecast-ready; never add the two stages; missing → margin **unknown**. For multiple required bindings include each applicable cost once; for an alternative group include only the scenario's selected member. Cross-Agency/Departure and inconsistent-currency sources cannot contribute a numeric margin.

When all relevant costs are complete and the scope is unambiguous:

`indicative scenario margin = Client revenue + expected_commission − forecast_supplier_cost`

Use `EvaluateSupplierCostForecast` totals `expected_commission_minor_units` and `forecast_supplier_cost_minor_units`. Do **not** add `expected_net_cost_after_commission` and commission again. Expected commission is forecast only, not earned/received cash. Do not add Supplier-collected money as Client revenue or infer Agency cash.

If an Arrangement-wide cost is shared across expected sales, require an explicit enrollment denominator and clearly label the allocated result **scenario economics**; absent that assumption, report margin **unknown** rather than subtracting the whole coach cost from one hypothetical sale. If the set of attributable sources is ambiguous, margin is unknown.

Margin output is `manage_departures` only. API responses and partials enforce this, not just a hidden button.

## Scenario proof without invented facts

| Scenario | M4B proof | Fixture discipline |
| --- | --- | --- |
| Celebrity O1 cruise | Anonymous first/second, additional, and single occupancy positions; per-person fare, named discount, tax/fee, and optional extra-night **shape**; explicit calculation/rounding and incomplete-input error. | The M3F ledger's O1 $1,624/$406 fares, $320 NCCF, −$150/−$37.50 discounts and $137 taxes/fees are **Supplier cost components** in M3C. Do not silently make them Client fares. Use an explicitly labeled illustrative Client-price fixture until authoritative Client prices exist. |
| Hilton extra nights | Additional person and room-night patterns; billable nights independently entered; no guessed Client inclusion, tax, or hotel rates. | M3F labels Hilton rates and adult tax M3C test values; they are not confirmed Client terms. |
| Vineyard | Transient bundled base `P`, double `2P`, single `P + round(P × 1.0)` **illustrative**; coach shared-cost margin unknown without enrollment; one dinner choice can be represented as a scenario selection shape, with no inferred surcharge. Bundled package-only services without own prices remain complete. | M3F confirms June 5–7, 2027 and 30-seat coach and separate Standard/Deluxe dinner Items; the hotel A/B nights and properties remain shape-only. M4C owns the actual dinner choice template and Package record. |

## Commands, concurrency, and proof

Provide bounded create/update/remove/reorder price-definition commands on **editable draft** Service Offer versions, with session-derived Agency, `manage_departures`, expected lock version, `AgencyCommandIdempotencyKey` for consequential creates, and M4A lock order. Reject stale update without partially saving components. Audit only M4B actions actually emitted, with bounded IDs/action context; never put the full pricing graph or anonymous scenario in audit `details`. Read-only evaluator calls issue no audit/capacity events. Source and price rows must have same tenant, Departure and draft version, including under direct SQL. No new Administrator override.

Before PR merge prove:

1. One simple service price can be entered and understood without exposing percentage-base tables or a formula editor; advanced controls preserve draft values and return field-level recovery after invalid review. Keyboard and 375/768/1280/1400 views follow M4.0 friction **rules** (no invented numeric baseline). Viewer has no M4B form.
2. Exact integer/decimal math for all supported bases and roles, included versus additive tax, percentage ordering, line rounding versus final-total rounding, overflow and invalid inputs. Property/edge cases include one-cent boundaries and incomplete scenario quantities. Direct SQL fails invalid same-owner, type and link shapes.
3. Separate Client rate categories and occupancy from M3C Supplier participant categories; demonstrate Celebrity occupancy math with **illustrative Client** prices and no copied Supplier cost. Billable hotel extra nights are explicit. Vineyard double/single symbolic/illustrative formula yields one bundled Package revenue source without duplicate supplement.
4. The pure cost entry point does not persist assumptions. A missing/working M3 cost source gives **unknown** margin; contracted/estimate precedence and cost-only refresh work. Shared coach fixed cost stays unknown absent enrollment; expected commission remains forecast. Viewer/JSON contains no cost or margin.
5. A retained M4 price row blocks both ordinary Departure currency-changing commands; deleting an eligible draft can allow correction under existing gates. Rejected currency change preserves amounts. Anonymous preview writes no M3 assumption, named person, Client demand, capacity event, Charge or posted money.
6. Full required repository CI passes on the pinned M4A-descendant branch. M4C receives the calculator interface, bundled-completeness rule, and Package pricing owner contract; M4D receives publish-readiness checks and the immutable graph to freeze.

**Exit:** Staff can price and anonymously preview a Service Offer draft with explainable Client arithmetic and optional correctly qualified economics. The Vineyard bundled and service-sum patterns are proven **in memory** for M4C integration. No Package persistence, published offer, guaranteed inventory, or Client money exists because of M4B.
