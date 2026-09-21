# M4A — Service definitions and fulfillment sources

**Status:** Accepted 2026-09-20. Implementation authority for M4A tables, commands, and Staff UI only. Shipped with this slice.

**Parent authority:** [M4 — Offers and pricing](m4-offers-and-pricing.md) (Accepted 2026-09-20; not implementation authority for later slices), [ADR 0014](../adr/0014-client-offers-publication-and-supply-compatibility.md) (Accepted; not implementation authority), and [M4.0](m40-task-flow-and-contract.md) (Accepted; documentation/task-flow gate only). MVP occupancy exception and roadmap M5 Charge-posting amendment are already in those documents.

**Implementation base:** Documentation pin [`ea6d63e`](https://github.com/tswarren/DepartureDesk/commit/ea6d63e875d917415da061e7b1a64b382c5f91a1) (M3 complete). Production M4A starts from that SHA or a later `main` descendant. Coding slices reconfirm required CI on the branch tip.

**Later slices:** [M4B](m4b-client-pricing-and-anonymous-preview.md) (shipped) · [M4C](m4c-packages-choices-and-client-terms.md) (shipped) · [M4D](m4d-publication-and-live-feasibility.md) (shipped) · [M4D.0](m4d0-narrow-group-departure-builder.md) (Accepted; not shipped) · [M4E](drafts/DepartureDesk-M4E-acceptance-and-hardening-draft.md)

## Goal

Staff can start an **unpublished** Service Offer under a Departure from one Item/Occurrence without re-entering Supplier planning facts, state a truthful fulfillment basis, edit its Client-facing definition, and inspect its precise M3 source. A bounded evaluator classifies an activated M3 successor against the draft's bound dependencies as **equivalent**, **material**, or **unknown**, with cost and live quantity changes handled separately as read-only annotations. The one-source path is first; multiple required and alternative sources are an advanced disclosure.

M4A proves identity, draft recovery, tenant integrity, exact-source lineage, and narrow compatibility. It makes **no** Service Offer selectable or published. M4B supplies Client price and anonymous calculation, M4C Package/choice/terms composition, and M4D atomic publication, manifest, lifecycle, and live selection preview.

## Included work and boundaries

| Included in M4A | Deferred owner |
| --- | --- |
| Stable Agency/Departure-owned Service Offer identity, editable version-1 draft and version-owned Client-facing service definition; persisted exact source binding(s), source-dependency declaration, optimistic locking, bounded draft edit and `draft → abandoned` discard | M4D successor publication, published graph freeze, manifests, pause/resume, retire, idempotent joint Package publication |
| Staff add-from-planning and draft show/edit UI in the Departure workspace; prefill source facts with provenance and preserve independently editable Client text | M4B price form/evaluator and anonymous price preview; M4C Package builder and Service Offer choice templates |
| Exact M3 binding to the **governing activated** planning version by default when the Arrangement is `active`, with a clearly labeled **tentative** option for a successor draft; source resolver and narrow activated-successor compatibility evaluator | M4D publication pins only current activated definitions, derived offer-review and current selection state |
| Explicit on-request, Agency-fulfilled, externally fulfilled basis without fabricated M3 pin or numeric guarantee; M3 Pool-mode disclosure where M3-backed | M5 Holds, Allocations, Client Trip Service source choice and transactional capacity checks |
| Named tables below, source shape and database tenant/Departure constraints, audit catalog extension for M4A draft commands, permissions, regression and Staff task-flow proof | M4D audit actions for publication/pause/resume/retire and lifecycle preview integrations; M4B/M4D Departure currency guards once price exists |

Do not add Package, Client Trip, Traveler, Hold, Allocation, Charge, Receipt, obligation, Payment, generated offer reference, Supplier cost copy, sale limit, price component, choice template, posted money, or M4 capacity event in this slice. No public or standalone sell action appears on an M4A draft. No ADR 0004 Package/Service Offer namespace. No Administrator publication override. Never reuse `override_supplier_planning_terms`. Do not persist `independently_sellable` on Service Offer identity. Package-only versus independently sellable is version-owned lifecycle and belongs to M4C/D.

## Staff journey

1. From a Departure, choose **Add service from Supplier planning**. Search **that Departure's** Items/Occurrences/Resources across its Arrangements (there is no departure-wide catalog today). For an **active** Arrangement, list the **governing activated** graph by default; list a successor draft only as a labeled **tentative** option. Never-activated Arrangements list the labeled draft only. Do not reuse the Arrangement editor's `set_editable_draft_version` as the offer-create default. Show enough Supplier, dates, Resource and Pool context to disambiguate similar names. Selecting one source fills the draft name/description suggestion, category, effective provider, service dates/zone, Departure operating currency, and truthful capacity mode context. Supplier fields are visibly source facts; the Client-facing title/description are Staff-editable snapshots. Never copy Supplier cost into a Client price. Currency is displayed from the Departure, not retyped from the Item.
2. If there is no M3 source, Staff choose **On request**, **Agency fulfilled**, or **Externally fulfilled** and enter a Client-facing name. That choice does not create an Arrangement, Pool, Supplier confirmation, or count. If an M3 Pool is `on_request` or `externally_managed`, label its nonnumeric inventory honestly; this Pool mode does not silently become the service's independently declared fulfillment basis.
3. Show the **one bound source** by default. Only when Staff add another source reveal advanced topology (below). Source alternatives are fulfillment topology, distinct from the M4C Client choice template.
4. Save the draft and return to it. Show whether the selected Arrangement is draft or activated and whether the source is currently eligible. Source version changes never rewrite the draft silently. A draft M3 source is allowed for planning; explain on screen that M4D publication will require a current activated version. If source facts change, show the precise bound difference and let Staff explicitly refresh/reselect the draft binding while retaining Client text. No second entry of unchanged source facts.

**Ordinary-path fields:** Client-facing service title, selected source or explicit non-M3 basis, and any truly required clarification. Dates, provider, category, currency, and capacity context are displayed from the selected source rather than retyped. Price, limits, payment schedule, and multiple-source controls are absent from the default M4A form. Do not show M3 cost or indicative margin on offer pages.

## Persistence tables

M4A names these tables. No Package, price, choice, cap, generated reference, or identity-level sellability flag.

| Table | Contract |
| --- | --- |
| `service_offers` | Stable UUID identity. Immutable `agency_id` and `departure_id`. Ordinary Staff display name. Optimistic `lock_version` when identity is edited. No generated human reference. **No `independently_sellable`.** |
| `service_offer_versions` | Positive monotonic `version_number`; discarded numbers are never reused. Optimistic `lock_version`. Closed status catalog: `draft`, `abandoned`, plus reserved M4D values `published`, `superseded`, `retired`. M4A commands use only `draft` and `abandoned`. Legal M4A transition: `draft → abandoned`. Persist `abandoned_at` and `abandoned_reason` when abandoned. At most one editable `draft` per offer. No published-current pointer. No `copied_from_id` until M4D successor copying. |
| `service_offer_definitions` | Version-owned Client title/description and declared fulfillment basis: `m3_backed`, `on_request`, `agency_fulfilled`, or `externally_fulfilled`. Mutable only while the offer version is `draft`; abandoned versions freeze. |
| `service_offer_source_bindings` | Required vs alternative-group membership, selected M3 stable IDs, exact planning Arrangement version and definition IDs, dependency flags (live Supplier wording vs snapshot), and provenance of copied Client text. |

Composite same-Agency/same-Departure foreign keys on every child. A binding's Item/Occurrence/Resource/Pool IDs must form a valid M3 ancestry; Rails validation **and** database constraints reject cross-tenant, cross-Departure, cross-Arrangement, and wrong-version children even under direct SQL. Allowed pins:

- Item only
- Item + Occurrence
- Item + Resource (no Occurrence) when that resource description is genuinely promised
- Item + Occurrence + Resource
- Pool only when **both** Occurrence and Resource are pinned (pools are Occurrence+Resource)

Reject Pool without Occurrence or without Resource; reject Occurrence/Resource/Pool that are not in the bound Item/version lineage. Resource belongs to an Item independently of an Occurrence. Deletion of referenced source history is restricted. `copied_from` on offer versions is unused until M4D; do not include `ExactVersionCopyLineage` in this slice.

`DraftVersionDefinition` is generalized with an explicit version association (default `:supplier_arrangement_version` so M3 is unchanged). Offer definitions and bindings use `service_offer_version`. A PostgreSQL non-draft mutation guard covers offer definition/binding tables.

Neither request `agency_id` nor Office context establishes ownership; use session-derived Agency and scope every lookup through it. Return cross-Agency identifiers as not found.

## Alternative source topology

Default: exactly one **required** binding.

Advanced disclosure (no nesting):

- N required bindings (all must apply), plus
- Zero or more **choose-one** alternative groups
- A group has stable display labels and represents exactly one Staff-selected member for a future scenario
- Do not automatically choose the cheapest or first currently available
- An invalid unused alternative does not block another selected viable member (selection enforcement is M4D/M5; M4A persists the shape)

**Occurrence selection.** If a source is Item-level and has several Occurrences, Staff select the actual Occurrence when the offered service promises a date or relies on Occurrence/Resource Pool capacity; never silently bind every Occurrence or pick one.

**Item-without-Occurrence.** If one Item truly represents a service without an Occurrence dependency, record that narrower scope explicitly and **must not** pin a Pool. Capacity Pools are Occurrence+Resource scoped. Staff may pin Item+Resource without an Occurrence. Dinner remains **two Arrangement Items**, not an M3 choice group. M4C places the exactly-one Client dinner choice on the Service Offer.

## Record contract

| Record or value | M4A rule |
| --- | --- |
| Service Offer identity | `service_offers` as above. At most one editable draft per identity. |
| Draft version | Exact version-owned Client-facing name/description and fulfillment topology. This slice creates initial drafts; a successor-copy command waits until a published predecessor exists in M4D. Abandoned versions retain their number; a later draft uses the next number. |
| Fulfillment binding | Declared M3-backed or explicit non-M3 basis. For M3-backed: stable Arrangement and selected Item/Occurrence/Resource/Pool identities as applicable, exact planning Arrangement version and the selected version's definition IDs, required/alternative membership, dependency flags, and provenance of what was copied into Client text. Every selected child must belong to that same exact version and Item lineage. |
| Draft-source behavior | Draft Arrangement version references are tentative and replaceable on deliberate draft editing; they can never later count as published provenance. If a successor *draft* exists alongside an activated Arrangement, current commercial authority remains the activated version. Create-from-source defaults to that governing activated version; the successor draft is an explicit tentative option. |
| Derived facts | Effective provider is Occurrence override, then Item default, then contracting Supplier. Current Supplier status, Occurrence status, Arrangement lifecycle, Pool mode, and current numeric projection are read from M3; do not persist a second copy as Client-offer authority. |

## Lock order (A–D contract)

Do **not** defer lock order to M4D. M4A create-from-source already touches M3 graphs.

Whenever an M4 command **locks any M3 row**, use the shipped M3E order:

1. Agency
2. Actor (recheck after the Agency lock)
3. Affected Suppliers in UUID order (contracting plus effective provider as applicable)
4. Departure
5. Arrangement, version, and child definitions as applicable
6. Then Service Offer / version (and later Package / version)

M4-only draft edits that do **not** lock M3 rows use Agency → **actor recheck** → Departure → Service Offer/version. Nested commands must not reacquire an earlier lock. M4B–M4D inherit this order and must not invent a second path. Prove the M3-touching create/refresh path against concurrent Arrangement activation in tests (no deadlock; no half-written offer).

## Source scope and compatibility evaluator

The evaluator compares **an exact activated predecessor and the current activated successor** for one binding, using stable child identities and `copied_from` lineage. It takes a fixed snapshot of the two graphs for one evaluation; an Arrangement version number change is not evidence of a semantic change. A successor draft does not enter this comparison. M4A exposes the evaluation result for development and draft source review; M4D must rerun it during publication and later selection. Do not persist a review projection by default.

Evaluator outcomes are only **`equivalent`**, **`material`**, and **`unknown`**. Do **not** make cost-only or numeric availability evaluator outcomes. Those may appear as separate read-only annotations (current Pool projection, “cost graph not compared”) without M4A diffing M3 cost definitions or building M4D live preview.

| Bound dependency | Compare when applicable | Do not treat as material on its own |
| --- | --- | --- |
| Item and provider | Presence of the bound Item; effective contractor/provider; Item category and capacity-management when relevant to the promise/supply | Unbound Item, display order, Arrangement version number |
| Occurrence | Presence, effective provider, promised date range, local times and IANA zone; cancellation is a current lifecycle failure | Unbound Occurrences; draft successor only |
| Resource and pair | Presence, bound resource meaning when promised, applicable pair classification | Unbound Resources and ordering |
| Pool | Bound stable Pool/ancestry, inventory mode, measurement basis, supplying Supplier and effective zone; promised label/unit if incorporated | Opening evidence, numeric event/projection, display order |
| Conditional wording or term | Explicitly bound/exposed Supplier name, description, or promised condition only if the offer declares that dependency | Mere copying of a name into independently published Client text; unrelated Supplier deposits, deadlines, commitments and costs |

Use ADR 0014's exact field boundary, including its conditional flags, and test normalized typed comparisons (date/time/zone, enum, IDs, text only when dependent). Preserve the original exact IDs for later publication provenance. Missing lineage, absent bound child, ambiguous effective provider, or an unrecognized fulfillment-semantic field yields unknown/material failure for the affected path, never presumed equivalence. Cost-only change refreshes later indicative economics; numeric Pool quantity belongs to M4D's live feasibility. Do not build an Arrangement-wide diff framework.

Do not compare only the prior and immediately next version if more than one activated successor has intervened: resolve the complete `copied_from` chain for the selected bound identities and fail closed on any missing/unknown step. Document and test how copied children preserve stable identity and how omitted/replaced children are classified. A newly added unrelated Item is irrelevant.

## Commands, permissions, and integration

- Provide bounded create-from-source, create-explicit-basis, update-draft, add/remove advanced binding, and discard-draft commands. Reuse `AgencyCommandIdempotencyKey` (same-key replay / different-payload conflict) for creates and any command that can duplicate a binding. Guard edits with expected `lock_version` and the lock order above. A conflict returns a recoverable current draft, not a half-written graph.
- **Viewer (M4.0):** Unpublished offer drafts are `manage_departures` only (create, edit, and read). `view_departures` does **not** read unpublished draft Client text, source panels, or offer forms. After M4D, Viewers read published Client-facing price, terms, Sales enabled, and computed eligibility. Indicative margin and Supplier cost stay `manage_departures`. The first offer UI must not expose margin on Viewer branches. Shipped M3 Arrangement cost-forecast Viewer access is **unchanged**. No role-name checks, no reuse of `override_supplier_planning_terms`, and no new override permission.
- Add `ServiceOffer` to `AuditEvent::SUBJECT_TYPES` and only the M4A draft actions actually emitted to `ACTIONS` in the implementing PR. Bounded details contain actor, identity, action and changed binding IDs, never a full service graph or source manifest. Publication actions wait until M4D. Update the AGENTS.md audit-subject list in that same implementing PR. Terminology for Service Offer versus Arrangement Item is already in `docs/terminology.md`.
- Read M3 projection and Supplier lifecycle as existing facts only; M4A draft binding creates no Supplier inactivation blocker, no Arrangement ending blocker, no Supplier Needs-attention detector, no capacity event, and no operational projection hook. M4D owns preview consequences of a published offer. Departed Departures cannot gain new sellable work; retained draft cleanup remains permissible only as explicitly allowed by the accepted Departure lifecycle contract. Commands that create offers require Departure `draft` or `active`.

## Delivery order within the slice

1. **Authority and setup:** This contract is implementation authority for M4A only. Pin a CI-green descendant of `ea6d63e`. Document the named tables, binding shapes, ancestry trigger, and lock order before migrations.
2. **Identity and draft persistence:** Add the four tables with composite ownership/lineage constraints, durable create idempotency, edit locks, and bounded audit catalog entries. No Package or price schema.
3. **Resolver and compatibility:** Add explicit M3 source resolution, the non-M3 supply basis, one-source default and advanced binding groups; prove activated successor outcomes and safe draft M3 source behavior.
4. **Staff surface and proof:** Add the Departure workspace draft path, Departure-scoped Item/Occurrence search, source prefill, validation/recovery and advanced disclosure. Test in the Celebrity O1 and Vineyard shape without inventing Client prices or hotel nights. Run required unit/integration/system, PostgreSQL direct-write/concurrency, accessibility, and repository CI gates.

## Exit proof

- A Staff user starts one Celebrity O1 draft from an Item/Occurrence/Resource/Pool with no re-entry of provider, dates, category or currency; source and Client text are distinguishable. A draft Arrangement is shown as tentative, and no publication action is offered. An independent non-M3 service names a basis and shows no fabricated availability. Viewer cannot open the unpublished draft.
- A Vineyard sketch creates distinct service drafts for coach, lodging, tasting, and lunches. Only a service that genuinely needs several Supplier bindings opens advanced topology; the lodging Hotel A/B sequence remains shape-only. Dinner is **not** an M3 choice group in M4A. M4C will place the exactly-one Client dinner choice on the Service Offer. No invented rates, properties, nights or extra capacity limits. Item-without-Occurrence drafts do not pin a Pool.
- Exact activated successor with unchanged bound facts is equivalent; changed effective provider, promised dates, resource meaning, or Pool mode/basis is material; missing lineage is unknown; cost-only changes and numeric availability changes are **not** evaluator results. An unrelated child change does not affect the binding. Draft successors do not govern current comparison.
- Direct SQL and application tests reject wrong tenant, Departure, Arrangement, Item ancestry, version or definition; unauthorized IDs are not found. Pool without Occurrence or Resource is rejected. Two concurrent creates with the same idempotency key yield one draft; conflicting edits preserve the last committed graph and return a recoverable conflict. Audit records have bounded details. Create-from-source versus Arrangement activation races follow the shipped lock order without deadlock. Actor recheck applies on offer-only update.
- Staff paths obey `manage_departures`; Viewer has no unpublished offer UI and no cost/margin leak. Keyboard flow and 375/768/1280/1400 layouts keep one-source setup understandable. Compare required entries, context switches, and invalid-review recovery against the accepted M4.0 friction rules. Full required CI passes at the PR tip.
- M4A ships **only drafts and source compatibility**. Its final handoff identifies the exact draft schema (`service_offers`, `service_offer_versions` with `abandoned` lifecycle, `service_offer_definitions`, `service_offer_source_bindings`) and the narrow `equivalent`/`material`/`unknown` evaluator contract that M4B uses for pricing and M4D uses for activated-only, atomic publication. No Package, published version, sellability flag, sale eligibility, Hold, Allocation or posted money is created.

## Dated amendment — M4D.0a (2026-09-21)

Authority: [M4D.0 — Narrow group departure builder](m4d0-narrow-group-departure-builder.md).

- Extend `fulfillment_basis` with draft-only **`undecided`** (also retained on abandoned history). It has no Supplier binding and makes no supply or capacity claim. Published/selectable fulfillment remains `m3_backed`, `on_request`, `agency_fulfilled`, and `externally_fulfilled`.
- Add nullable `service_offer_definitions.client_timing_text` (`string`, max 160, blank→null). Version-owned descriptive Client prose; draft-mutable; frozen with the published definition graph. Never parse into dates or use for capacity, compatibility, deadlines, or lifecycle.
- Add `CreateServiceOfferOutline` (unowned draft with `undecided`) and `ResolveServiceOfferFulfillmentBasis` (explicit audited resolution to a real basis). Existing create-from-source and explicit-basis paths remain.
- Exact M3 binding rules and published authority are unchanged. Shipped M4D publication readiness must reject `undecided` (see M4D amendment).
