# M4C — Packages, Client choices, and terms

**Status:** Accepted 2026-09-20. **Accepted and shipped.** Implementation authority for M4C tables, commands, calculator adapter, and Staff draft UI only. Publication is not shipped.

**Parent authority:** [M4 — Offers and pricing](m4-offers-and-pricing.md) (Accepted 2026-09-20; not implementation authority for later slices), [ADR 0014](../adr/0014-client-offers-publication-and-supply-compatibility.md) (Accepted; not implementation authority), and [M4.0](m40-task-flow-and-contract.md) (Accepted; documentation/task-flow gate only). MVP occupancy exception and roadmap M5 Charge-posting amendment are already in those documents.

**Implementation base:** Shipped [M4B](m4b-client-pricing-and-anonymous-preview.md) [PR #118](https://github.com/tswarren/DepartureDesk/pull/118) merge [`49025c8`](https://github.com/tswarren/DepartureDesk/commit/49025c8). Production M4C starts from that SHA or a later `main` descendant. Do not pin `af87db8`. Coding slices reconfirm required CI on the branch tip.

**Authority:** Parent, ADR 0014, and M4.0 as above. [ADR 0001](../adr/0001-money-and-currency.md) governs money. Lock order inherits [M4A](m4a-service-definitions-and-sources.md). Later: [M4D](drafts/DepartureDesk-M4D-publication-and-live-feasibility-draft.md) · [M4E](drafts/DepartureDesk-M4E-acceptance-and-hardening-draft.md).

## Goal and slice boundary

Staff can assemble an **unpublished Package draft** along the four-step path: add and price a Service Offer, optionally make a Package, review anonymously. They may add a package-only service inline, **adopt** an unshared unpublished service draft as package-only, pin already published reusable versions, define Client choices that survive to M5, choose bundled or service-sum pricing, and review coherent Client terms. A standalone Service Offer may own the same choice and term templates without any Package.

M4C persists draft Package identity, composition, Package-owned price, choice templates, Client terms, optional date window, and explicit sales limits. It adapts the shipped M4B calculator. **M4D owns** publication and its manifest, immutable published graphs, Sales enabled, live selection state, numeric Supplier supply checks, and one atomic Package-plus-owned-unpublished-service publication command. M4C has no publish or sell action, no Client Trip, Hold, Allocation, Charge, posted money, capacity event, or named Traveler.

No `independently_sellable` column. No ADR 0004 namespace. No Administrator publication override. Never reuse `override_supplier_planning_terms`. Do not attach a Package ID to `service_offer_price_*` rows.

## Staff journey: step 3 within the four-step path

1. After adding/pricing a service, Staff may skip Package assembly for a standalone Service Offer (`owning_package_version_id` null). Otherwise choose **Make Package** and name it.
2. Add services by **one** of:
   - **Add service here** (inline create): M4A source form inside the Package; the new unpublished version is owned by this Package version from birth. Staff see that this version belongs to the Package.
   - **Include this draft as package-only** (adopt): atomic adopt of an editable **`draft`** same-Departure service version (not abandoned, published, superseded, or retired) with no existing owner and no other Package-draft inclusion. Staff see that this version will belong to the Package. “Unpublished” alone is not enough: abandoned versions are unpublished and must not be adoptable.
   - **Include a published reusable version**: independent pin; not owned by the Package; keeps its own publication path. The command may exist in M4C. The Staff picker shows **no** published reusable versions until M4D ships publication.
3. Unpublished inclusion **without** adopt is rejected. Sharing an editable draft across two Package drafts is rejected.
4. Mark included versus optional placement. Choose **Bundled price** or **Sum service prices**. For a bundle, enter one unscoped per-person Package price; package-only components need no service price. For service-sum, retain each service's price and apply **fixed** named Package discounts/surcharges **once per selected Package booking** without changing a reusable service's own definition. Do not allocate bundle revenue to suppliers.
5. Define the Package payment schedule once and inspect inherited service-specific terms. Add an explicit Package resolution only where two applicable Client conditions truly conflict. Advanced date windows, numeric sales caps, and choice min/max appear on demand. The ordinary Package form has no mandatory cap or policy-resolution panel.
6. Try anonymous examples and see selected services/options, Client total, included/additive adjustments, payment dates or unresolved relative milestones, relevant terms, and qualified scenario economics. Invalid choice, unpriced selected option, conflicting terms, or unsupported date returns to its field without discarding unrelated entries. This remains a **draft review**; M4D adds publication validation and live availability.

**Viewer:** Draft Package, choice, and terms UI is `manage_departures` only. Viewers do not read unpublished drafts. After M4D they may read published Client-facing facts. Indicative margin and Supplier cost stay `manage_departures`. Shipped M3 cost-forecast Viewer access is unchanged.

## Persistence tables

| Table | Contract |
| --- | --- |
| `packages` | Stable UUID identity. Immutable `agency_id` and `departure_id`. Staff display name. Optimistic `lock_version` when identity is edited. No generated reference. |
| `package_versions` | Positive monotonic `version_number`; discarded numbers never reused. Optimistic `lock_version`. Closed status catalog: `draft`, `abandoned`, plus reserved M4D values `published`, `superseded`, `retired`. M4C commands use only `draft` and `abandoned`. Legal M4C transition: `draft → abandoned`. At most one editable `draft` per Package. No published-current pointer. |
| `package_inclusions` | Ordered link from a Package version to an exact Service Offer version. Same Agency/Departure. Placement `included` or `optional`. Stable `position`. `origin`: `inline_create`, `adopted_draft`, or `published_reusable`. One editable service draft cannot appear in two Package drafts. Only published reusable versions may be shared by multiple Packages. |
| `service_offer_versions.owning_package_version_id` | Nullable FK (additive column on the shipped M4A table). Null means independently created / reusable. Non-null means **this version** is package-only for that Package version. At most one owner. Independently selectable means the column is null. Do not add `independently_sellable`. Once assigned, the owner cannot be silently reassigned to another Package version. Change it only through named adopt, detach, or abandon commands. The owning Package version must also include the service version. |
| `package_price_definitions` | One per Package version. Mode `bundled` or `service_sum`. Currency = Departure `operating_currency`. Write authority is the Package version `lock_version`. Bundled may store optional nonnegative `single_occupancy_supplement_rate` (`numeric`). Absent for service-sum. **Not required** for ordinary bundles. |
| `package_price_components` | Bundled **base that yields `P`:** unscoped per-person only (`unit_rate`, quantity basis `persons`, both selectors `NULL`). Named Package adjustments on that graph may still evaluate for the canonical one-person input (discount, surcharge, or percentage of earlier unscoped Package components). Occupancy-position or Client rate-category selectors on the Package bundled graph are invalid for M4C; a broader Package rate matrix needs its own later accepted selector rule. Do not invent a category or occupancy position to make `P` run. Service-sum: **fixed** named discounts/surcharges only (`named_discount` / `named_surcharge`, `amount_minor_units`, add/subtract). Quantity is **once per selected Package booking**; do not multiply by an included service’s `service_instances` or resource count. No Package `base_price` on service-sum. |
| `package_price_component_bases` | Bundled percentage links among **persisted Package components** only (UUID-order `FOR SHARE`, same M4B rules). Must not point at a selected-service subtotal. |
| `service_offer_choice_groups` | Version-owned group on a Service Offer version. Name, `min_selections`, `max_selections`. `0..1` optional one; `1..1` exactly one. Not required on every service. |
| `service_offer_choice_options` | Stable ordered option identities, optional Client-visible descriptions, optional named Client price effect. |
| `service_offer_choice_option_source_activations` | Each option activates **exactly one** of: (a) one `service_offer_source_bindings` row on the **same** Service Offer version, (b) one alternative group key on that version, or (c) no source (price/terms-only extra). Reject an activation that points at another offer version’s binding or group. No nested Package/service graphs. |

Composite same-Agency/same-Departure foreign keys on every child. Rails and PostgreSQL reject cross-Agency, cross-Departure, wrong-version, and cross-Package draft links even by direct SQL. Create Package version, owner FK, and inclusion **atomically**. Use deferred database checks (or an equivalent commit-time trigger) for the circular ownership/inclusion pair.

`DraftVersionDefinition` on `package_version` for Package-owned definition children. Child price/choice tables use the M4A freeze pattern with `FOR SHARE` on the parent draft version for INSERT/UPDATE/DELETE.

M4C may add binding membership `choice_gated` so a dinner Item binding is not unconditional `required`. Do not change existing `required` / `alternative` meaning for standalone one-source offers. A binding targeted by an option activation must not also be unconditional `required`. Mapping is closed **both ways**: every `choice_gated` binding on a version must be reachable through at least one valid option activation on that same version; an unreachable `choice_gated` binding is incomplete.

## Package-only ownership

**Inline create** sets `owning_package_version_id` and inclusion `origin = inline_create` from birth.

**Adopt** is allowed only for an editable **`draft`** unshared same-Departure service version with null owner and no other Package-draft inclusion. Abandoned, published, superseded, and retired versions are rejected. Sets owner and `origin = adopted_draft`. Staff must see that this version will belong to the Package.

**Published reusable** inclusion sets `origin = published_reusable`, leaves owner null, and does not rewrite the service version. Persist and test the command in M4C. The Staff UI lists none until M4D ships publication.

**Abandon Package draft** (command name distinct from later M4D publish):

- Abandon the Package draft version.
- `inline_create` owned unpublished versions: cascade-abandon in the same command. Leave no stray inline draft. Do not convert them to independently selectable by abandoning.
- `adopted_draft` owned versions: do **not** destroy the service version. Clear `owning_package_version_id` in the same command (explicit revert). Require an explicit detach if Staff want that revert without abandoning the Package.
- Do not abandon `published_reusable` inclusions.
- Later independent sale of a formerly package-only service is the ADR 0014 successor/publication path, preserving old pins.

**M4D handoff (do not implement publish in M4C):** one command publishes the Package version and every unpublished Service Offer version it owns. Other inclusions must already be published and eligible. Standalone Service Offers (null owner) publish on their own path.

## Package price adapter

Shipped [`EvaluateClientPrice`](../../app/services/evaluate_client_price.rb) `BundledPackage` takes already-rounded per-person `P` then applies `2P` or `P + round_minor(P × s)`. `ServiceSum` takes evaluated service results plus `NamedAdjustment` amounts. One calculator language; no second formula engine.

**Bundled — calculate `P` once:**

1. The graph that produces `P` is an **unscoped per-person** Package price: `persons` quantity, both selectors `NULL`. Evaluate it against a **canonical one-person** scenario (`persons = 1`, no occupancy list, no rate category). Do not evaluate the Staff preview occupancy or rate category through that graph. Occupancy- or rate-category-scoped Package components cannot resolve without inventing a selector; reject them for this `P` path.
2. Named adjustments that depend only on that unscoped one-person graph (earlier rounded unscoped components) may still evaluate. Then apply shipped `BundledPackage` to the preview: two persons `2 × P`; one person `P` if `s` is absent, or `P + round_minor(P × s)` if `s` is present; `half_up`. Never feed a two-person graph total in as `base_price_minor_units` (that yields `4P`).
3. Supplement is Package revenue. Reject a lodging/service occupancy component for the **same** commercial supplement. Do not invent M3C `single_occupancy_*` Client quantity bases.
4. Absent `s` is not a stored 0% policy unless Staff explicitly stored zero. Vineyard `s = 1.0` remains **illustrative**; `P` is unresolved until Staff enter it.

**Service-sum:**

1. Evaluate each **selected** included/optional Service Offer price. Unpriced selected component incomplete; unselected optional prices do not contribute; package-only with no service price is complete under bundled only, not under service-sum.
2. Sum those already-rounded service totals.
3. Apply **fixed** named Package discounts/surcharges in explicit later order, **once per selected Package booking**, after that sum. Do not multiply an adjustment by an included Service Offer’s `service_instances` or resource count. Map to `ServiceSum`; emit **each adjustment as its own result line** (shipped `ServiceSum` today may omit adjustment lines from `lines` while still changing the total — the M4C adapter must append them). Do not write into service-owned price rows.
4. M4C does **not** persist percentage Package adjustments on service-sum. A first percentage cannot link to an “earlier Package component” representing the selected subtotal. If a later accepted amendment needs percentages, it must name a derived `service_sum_subtotal` base and rounding/link rules before migrations. Do not fake a persisted subtotal component row.

Choice option price effects evaluate only for **selected** options, as distinct lines. Included tax is displayed without adding it twice. Both modes use Departure operating currency and M4B `half_up` component rounding. A retained Package price row is currency-bearing: extend `UpdateDeparture` / `CorrectDepartureCurrency` as for M4B service prices.

## Client choice templates and selected-set evaluation

A choice group belongs to an exact **Service Offer version**, whether standalone or included. The Package owns only placement/inclusion and any narrow version-owned price/term resolution.

Validate `0 ≤ min ≤ max ≤ option_count`, unique option identities, usable mapping for every option, and at least one **structurally valid** combination. Current numeric Pool shortage does not make the structure invalid.

**Same selected set for price, attributed cost, and later M4D capacity:**

1. Always apply unconditional `required` bindings that are not the target of any option activation.
2. Apply activations for **selected** options only. Unselected options contribute no binding, option price, attributed cost, or later Pool check.
3. If the activated target is an alternative group, the scenario still names **exactly one** member. Do not auto-pick cheapest.
4. Remaining required sources apply once. Deduplicate by binding id, then by cost-source identity for economics.
5. Vineyard Standard/Deluxe are two choice-gated Item bindings on the Dinner Service Offer, **not** an M4A alternative Supplier group and **not** two always-on required bindings. A combination that would count both dinner Items is incomplete. An activation that points at another Service Offer version is rejected. A `choice_gated` binding with no activation on its version is incomplete.

Separate the Client option from Staff alternative fulfillment. An option may have no extra price when an explicit included-price rule establishes that result; an unknown surcharge is never silently zero.

For the Vineyard sketch, a Package includes the Dinner Service Offer once. M5 receives the exact group/options and selected dinner on its Client Trip Service; a standalone dinner service carries the same template without a Package. M4C does not create an M3 Supplier-side choice or a named Client selection.

## Client terms: one ordinary schedule, scoped exceptions

| Kind | Draft rule and preview behavior |
| --- | --- |
| Payment schedule | One structured Package Client schedule is the default for a bundle; standalone service uses its own schedule. A service in a Package adds an extra **service-specific** condition only when it applies, without restating the whole Package schedule. Fixed dates or explicitly named relative milestones, amount or percent of a stated selected Client price base, due ordering and rounding must be recorded. A relative date that needs an unknown future event remains a conditional term in M4 preview; no due Charge is posted. Do not derive a Client deposit from an M3 Supplier Deposit Requirement. |
| Cancellation | Ordered Client date/threshold tiers may state fixed amounts or percentages with explicit bases; a condition requiring judgment is marked **manual review**. Preview examples may compute only a determinate selected tier. An unresolved/manual outcome is unknown, not zero. M7 later owns actual cancellation cases. |
| Eligibility and acknowledgment | Structured eligibility and material-term acknowledgment templates for M5 snapshot/revalidation, never inferred from Supplier planning. No Traveler assignment or actual acknowledgment in M4. |
| Scope and conflict | Package terms govern bundled Client price/payment by default; included service terms add only service-scoped conditions. If both state an incompatible rule for the same scope, show the original texts/sources and require an explicit version-owned resolution selecting the governing Client rule and reason. Ordinary nonconflicting inheritance requires no extra form. Do not silently pick the stricter or broader term. |

Validate monetary schedule components in currency and round each specified line consistently with M4B. Reject unsupported triggers, contradictory tiers, gaps that make a required scenario unknowable, percentage schedules whose base is unspecified, and resolutions pointing to missing terms. Do not require a fully calculable amount for a clearly disclosed **manual-review cancellation clause**. The M4C preview does not issue invoices, schedule jobs, or make payment/commission assertions.

## Optional sales window and limits

- **Sales window:** Optional local **date** range in the Departure's stored IANA zone. Both dates inclusive at the business level; compare later instants as `[start at local midnight, next-day local midnight)`. A missing zone can be carried on a **draft** Departure. M4D publication requires an active Departure, so a published window always has a zone. Timed-to-the-minute sale deadlines require a later accepted extension.
- **Caps:** Optional numeric Package cap and optional standalone/service cap, each with an explicit basis (`package_bookings`, `persons`, or `resource_units` only where meaningful). **Do not** equate Pool `traveler_positions` with `persons`. A Package booking counts once for Package-booking basis; included services count selected quantity under that service's basis; optional services count only when chosen. No implicit conversion between persons and rooms. Caps are never required just because a Pool is nonnumeric.
- **M4C stacking:** Anonymous preview checks a scenario's quantity against each **configured** Package/service cap only. It does **not** check numeric Supplier Pool projections. **M4 has no Client demand ledger.** M4D owns time-labeled live feasibility: stack these same caps with `CapacityProjection#current_supplier_capacity` / `numeric_inventory?`, lifecycle, sales window, and the selected choice/fulfillment path. Temporary Pool shortage is not an M4C structural blocker. M5 owns transactional consumption under Holds and Allocations.

## Indicative Package economics

Reuse M4B’s pure cost entry point. Collect `SupplierCostSource` rows from the **selected composition** (included required services + selected optional services + selected choice-gated bindings + exactly one member per activated alternative group). Deduplicate by cost-source identity **across included services** so a shared coach is not subtracted twice. Shared Arrangement-wide cost still needs an explicit enrollment denominator or margin stays unknown. Do not fall back to Arrangement-wide forecast totals. Viewer/JSON contains no cost or margin.

## Commands, concurrency, and lifecycle

Dedicated commands (do not overload Service Offer draft update):

- Create Package draft; update Package identity/draft; abandon Package draft.
- Inline package-only service setup; adopt an editable **draft** as package-only; include published reusable version (command present; Staff UI empty until M4D); reorder/remove inclusion; detach adopted draft (clear owner without abandoning the Package).
- Create/update/remove Package price definition.
- Choice-group/option/activation edits on a Service Offer draft version (standalone or included).
- Scoped terms, conflict resolution, optional cap/window edits.

Session-derived Agency, `manage_departures`, expected lock versions, M4A lock order (Agency, actor recheck, Suppliers in UUID order when any M3 row is locked, Departure, Arrangement/source, then Package/Service Offer). Nested commands must not reacquire an earlier lock. Unauthorized IDs return not found.

**Idempotency:** Composite inline-create and adopt use `AgencyCommandIdempotencyKey` with command names **distinct** from M4D's later publish key. Same-key retry returns the same Package/owned-service draft and cannot leave a stray service draft or double inclusion. Concurrent edits return a recoverable conflict with no half-linked child.

Audit actual M4C actions with new `Package` subject and bounded details; extend closed subject/action catalogs in the implementing change. Do not place a full term graph or anonymous scenario in audit details.

M4C does not change Supplier inactivation, Arrangement ending, or M3 Needs-attention catalogs. Do not add offer panels to `docs/ui/interface-contract.md` until the implementing slice ships UI. Do not claim publication is shipped.

## Delivery sequence and exit proof

1. **Base and contract:** This document is implementation authority for M4C only. Pin [`49025c8`](https://github.com/tswarren/DepartureDesk/commit/49025c8) or a later `main` descendant. Name tables, deferred circular checks, adopt/detach/abandon, activations, and the calculator adapter before migrations.
2. **Package graph:** Persist identity, versions, inclusions, `owning_package_version_id`, origin, immutable owner except named commands, abandon rules (inline cascade vs adopted revert), idempotency, optimistic locking, SQL tenant/version constraints.
3. **Price and choices:** Package price tables + adapter (`P` from one-person graph, optional `s`, fixed service-sum adjustments) + currency freeze; choice groups/options/activations; selected-set evaluation for price and economics (cross-service cost-source dedup).
4. **Terms and controls:** Ordinary Package schedule, scoped service conditions, computable/manual-review cancellation, conflict resolution only when needed, optional local date window/caps. Combined anonymous review and field-linked recovery. Cap checks against scenario quantity only.
5. **Proof:** Celebrity Package demonstrates cruise inclusion and optional hotel/transfers/excursion shapes without inventing Client prices; a separately sellable service has a choice template. Vineyard uses illustrative unscoped `P`, optional illustrative `s = 1.0` without `4P` or duplicate lodging supplement, one package-only setup, adopt of an editable **draft** without a prior publish click, abandoned versions rejected for adopt, published reusable inclusion command with empty Staff picker until M4D, Standard/Deluxe exactly-one dinner sourced from separate Items (one Item, not both; every `choice_gated` binding reachable). Hotel A/B remains shape-only. Unknown dinner surcharge blocks a fully priced draft example rather than becoming zero.

Tests prove: cross-Agency/Departure/wrong-version links fail under Rails and direct SQL; deferred circular ownership/inclusion; owner cannot be silently reassigned; concurrent inline create/adopt/retry yields exactly one Package and service draft; stale edits never half-update; option min/max, same-version activations, unreachable `choice_gated` rejected; bundled `2P` not `4P` from an unscoped one-person `P`; occupancy/rate-category Package components rejected on the `P` graph; optional `s`; fixed service-sum adjustments once per Package booking as their own lines; terms inheritance and actual conflict resolution; DST/local-date boundaries and cap bases (`persons` ≠ `traveler_positions`) without Pool projection checks; Viewer has no draft Package UI; keyboard field recovery and 375/768/1280/1400 layouts. Compare required entries against M4.0 friction **rules**. Full required repository CI passes at PR tip.

**Exit:** A complete **draft** Package and a standalone choice-bearing service can be assembled and anonymously reviewed along the four-step path, including adopting an unshared unpublished service as package-only. One future M4D publication action covers the Package plus owned unpublished service versions. M4C creates no published offer, live sale eligibility, Client demand, or posted money.
