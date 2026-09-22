# M4D.0 — Narrow group departure builder

**Status:** Shipped 2026-09-21 on [PR #122](https://github.com/tswarren/DepartureDesk/pull/122) with interim [M4D.0R](m4d0r-builder-interface-remediation.md) presentation. Implementation authority for M4D.0 tables, commands, derived readiness/scenario services remains this document. Interim UI hierarchy is M4D.0R; **future** composition presentation is Accepted [M4D.1](m4d1-departure-composition-workspace.md). Not authority for M4E or deferred discovery items in the streamlined draft. Do not implement M4E or M4D.1 code until the relevant accepted plan names that work.

**Placement:** Between shipped [M4D](m4d-publication-and-live-feasibility.md) and draft [M4E](drafts/DepartureDesk-M4E-acceptance-and-hardening-draft.md). M4A–M4D remain shipped. [M4D.1](m4d1-departure-composition-workspace.md) is Accepted as the next composition-workspace milestone. This phase amends the draft-creation journey so Staff can reach a publishable outline without rewriting M4 identities, price arithmetic, choice templates, Client terms, publication, Sales enabled, or live feasibility.

**Implementation base:** [`88db505`](https://github.com/tswarren/DepartureDesk/commit/88db505fa81ab740ad134fea28998841b401d7e9) (`88db505`), the [M4D merge](https://github.com/tswarren/DepartureDesk/pull/120) on `main`. M4D.0/M4D.0R production code in PR #122 lands at [`893b7c3`](https://github.com/tswarren/DepartureDesk/commit/893b7c3); later PR #122 commits are documentation (including Accepted M4D.1). After merge, prefer the merge SHA when citing the shipped builder.

**Discovery backlog:** [M4D.0 — Streamlined group departure builder](drafts/DepartureDesk-M4D0-streamlined-group-departure-builder-draft.md) remains discovery-only and is not implementation authority. Deferred items there need their own accepted slice before code.

**Amendments:** Dated 2026-09-21 amendments land in [M2A](m2a-departure-core.md), [M4A](m4a-service-definitions-and-sources.md), [M4C](m4c-packages-choices-and-client-terms.md), [M4D](m4d-publication-and-live-feasibility.md), [ADR 0014](../adr/0014-client-offers-publication-and-supply-compatibility.md), [terminology](../terminology.md), and the [interface contract](../ui/interface-contract.md). Dated 2026-09-21 [M4D.0R](m4d0r-builder-interface-remediation.md) ships interim Staff presentation on PR #122. Dated 2026-09-21 [M4D.1](m4d1-departure-composition-workspace.md) Accepted as future composition workspace authority.

## Goal

Make **Create group departure** feel like one familiar agency task rather than a sequence of domain-model setup screens.

An agent must be able to:

1. Save a named Departure with rough or exact timing and the usual responsibility defaults.
2. Add recognizable Client-facing components one at a time without first choosing Supplier fulfillment, cost, capacity, or Client price.
3. Confirm whether those components belong to one primary Package when the first component is added.
4. Mark Package components included or optional, arrange them, and add approximate Client-facing timing.
5. Return to one Departure workspace that shows one recommended next action and direct paths to Supplier support, pricing, and Client preview.
6. See useful Package totals for a small number of common anonymous scenarios as soon as enough price facts exist.

The first-session success condition is **the concept and rough component outline are safely recorded**. It is not Supplier-ready, proposal-ready, publish-ready, or sell-ready.

## Scope discipline

This plan composes shipped M2 and M4 records. It does not introduce a temporary outline model, new commercial aggregate, workflow engine, persisted completion percentage, or Client-communication subsystem.

The intentional change budget is small:

- two bounded descriptive timing fields;
- one draft-only fulfillment value;
- two outline-oriented commands;
- one route/controller surface for the shipped Package reorder command;
- derived readiness and scenario services with no persisted results;
- focused Staff screens over existing Departure, Service Offer, Package, price, choice, term, and Supplier-source records.

Anything not needed to complete the six-step goal is deferred.

## What the current codebase already supports

| Area | Shipped capability at `88db505` | How the narrow builder uses it |
| --- | --- | --- |
| Departure draft | `CreateDeparture` creates a draft and permits omitted exact dates. It proposes current/default Office, creator as responsible AgencyUser, Agency time zone, and currency. | Keep the record and defaults. Replace the ordinary presentation with a compact concept form; do not add another Departure type. |
| Responsibility | Draft Office and AgencyUser are optional; activation requires both. Office is attribution, not authorization. | Keep the M2 activation contract. Present responsible Office as the primary organizational field and retain the creator default as Staff attribution. Do not redesign responsibility here. |
| Exact timing | `starts_on` and `ends_on` are optional on drafts, paired when present, and authoritative for activation/lifecycle. | Keep exact dates unchanged. Add one descriptive target-timing field for month/season/candidate prose. |
| Service Offer identity | M4A has stable `ServiceOffer` plus version-owned Client definition and exact Supplier bindings. | A rough component is this existing Service Offer draft from its first save. There is no outline conversion. |
| Supplier-backed create | `CreateServiceOfferFromSource` creates an M3-backed draft from an Arrangement Item/Occurrence/Resource/Pool. | Keep it as the Supplier-first path and expose it from each component’s Supplier-support action. |
| Non-M3 create | `CreateServiceOfferWithExplicitBasis` creates on-request, Agency-fulfilled, or externally fulfilled drafts. It requires that decision immediately. | Extend the draft contract with `undecided`; the outline path creates the same definition without pretending fulfillment is known. |
| Package draft | `CreatePackageDraft` creates the stable Package and draft version. | The first-component Package command creates the same records atomically. |
| Package-owned component | `CreatePackageInlineServiceOffer` creates and includes a package-only Service Offer with included/optional placement. | Extend an outline variant to accept undecided fulfillment and optional Client timing. |
| Unowned component adoption | `AdoptServiceOfferDraftAsPackageOnly` adopts an editable unowned draft and records placement. | Present an unowned unpublished draft as **Not yet assigned to a Package** and adopt it later. No commercial-scope column is needed. |
| Inclusion order | `package_inclusions.position` and `ReorderPackageInclusions` exist. | Expose the shipped command through a Staff route and itinerary reorder mode. Unassigned components remain in creation order until assigned. |
| Client pricing | M4B ships service pricing, anonymous scenario evaluation, line explanations, and optional indicative economics. | Reuse the evaluator; add no pricing language and persist no preview totals. |
| Package pricing | M4C ships bundled/service-sum prices, composition, choices, Client terms, and anonymous Package preview. | Use the Package preview as the calculation source for workspace summaries and Client preview. |
| Choices | M4C ships Service Offer choice groups/options and source activations. | Cruise and Hotel helpers create the same choices; no cabin or room aggregate is added. |
| Draft visibility | Unpublished Service Offers and Packages are `manage_departures` only. Viewer may read published Client facts. | Preserve that boundary. The builder remains `manage_departures` only. |
| Publication (M4D) | Publish, freeze, manifests, Sales enabled, pause/resume/retire, live feasibility, and M3 offer-path disclosure are shipped. | Treat publication as an **already-shipped constraint**: readiness may point at Publish, but M4D.0 does not redesign publish, Sales enabled, or live feasibility. Outline/`undecided` versions must remain unpublished until Staff resolve fulfillment and satisfy shipped readiness. |

## Required contractual and system changes

### 1. Rough Departure timing

Add nullable `departures.target_timing_text`:

- normalized, blank-to-null, maximum 160 characters;
- descriptive only—never used for activation, lifecycle, sales windows, Supplier matching, deadlines, or calculations;
- exact `starts_on`/`ends_on` remain authoritative.

No timing-kind enum and no candidate-window table are introduced.

### 2. Outline-first Service Offer creation

Add `undecided` to `ServiceOfferDefinition::FULFILLMENT_BASES` and its PostgreSQL check.

- It is valid only on editable drafts or retained abandoned history.
- It has no Supplier binding and makes no supply/capacity claim.
- Staff later choose M3-backed, on-request, Agency-fulfilled, or externally fulfilled explicitly.
- Shipped M4D publication readiness and publish commands must reject it (extend those checks in the same change that introduces `undecided`).
- Existing basis meanings and exact M3 binding rules remain unchanged.

Add `CreateServiceOfferOutline`:

- inputs: Departure, component name, optional Client timing text, idempotency key;
- creates the existing Service Offer, version 1 draft, and definition;
- uses the name as initial Client title and `undecided` fulfillment;
- leaves Package ownership null and creates no Package inclusion, price, choice, term, source binding, capacity event, or Supplier record;
- follows M4A tenant loading, authorization, lock order, idempotency, and audit rules.

An unowned editable draft is labeled **Not yet assigned to a Package**. This is presentation, not persisted status. Shipped standalone publish already applies only when `owning_package_version_id` is null; M4D.0 must not invent an `independently_sellable` column. Unowned drafts stay unpublished until Staff deliberately publish them under existing M4D rules or adopt them into a Package.

### 3. Approximate Client component timing

Add nullable `service_offer_definitions.client_timing_text`:

- version-owned and covered by draft mutation and later published freeze;
- normalized, blank-to-null, maximum 160 characters;
- examples: “Day 2 afternoon,” “June 7, time TBA,” “November 6–13 sailing”;
- display-only here; never parsed into dates or used for capacity, compatibility, deadlines, or lifecycle.

No schedule table, precision enum, time fields, or automatic Supplier-date inheritance is added.

### 4. Atomic first Package and component

Add `CreateInitialPackageWithOutlineServiceOffer`:

- inputs: Departure, Package name, component name, placement, optional Client timing text, idempotency key;
- atomically creates Package/version, Service Offer/version/definition with undecided fulfillment, owner link, and inclusion;
- defaults Package name in the form from Departure name but persists submitted text;
- accepts exactly included or optional placement;
- replays the same key/payload and rejects different payload;
- leaves no empty Package, orphan offer, inclusion, or success audit on failure.

The builder does not add `primary_package_id`. When exactly one editable Package draft exists, the UI may call it the main Package. With no Package, offer the creation prompt. With multiple Packages, require Staff to select the Package being worked on for that request/session and show the others; never silently choose or persist a new primary designation.

Subsequent components use an outline-capable extension of `CreatePackageInlineServiceOffer`. Declining Package creation uses `CreateServiceOfferOutline`. Later assignment uses the shipped adoption command.

### 5. Package reorder surface

Expose `ReorderPackageInclusions` through a route/controller with:

- an exact permutation of current inclusion IDs;
- Package-version optimistic lock;
- keyboard Move up/Move down controls and full-page fallback;
- no drag-only interaction.

Package inclusion order is the Client itinerary order. Unassigned components appear afterward in creation order and cannot be manually reordered until assigned. This is an explicit scope limit, not a hidden second ordering system.

### 6. Derived builder guidance

Add pure read services and no readiness tables or focus columns.

`EvaluateDepartureBuilderReadiness` returns four groups:

1. **Itinerary and Package**
2. **Supplier support**
3. **Pricing and Client terms**
4. **Ready to publish**

Each finding returns a stable reason code, state (`incomplete`, `needs_attention`, `blocked`, or `waiting`), route target, and affected component/Package ID.

`RecommendDepartureBuilderAction` chooses one actionable result. Correctness blockers outrank ordinary incomplete work; waiting on a Supplier does not outrank another action Staff can take. Add no percentage, persisted finding, or manual completion flag.

The working outcome—Client preview, Supplier support, or Pricing—is a query/session presentation choice, not persisted domain state.

### 7. Common pricing scenarios

Add a pure `DeriveCommonPackageScenarios` adapter over the exact draft graph and shipped evaluators.

Return only a bounded summary:

- default Package composition for two travelers when structurally valid;
- one traveler when explicitly supported by the price graph;
- supported occupancy examples already named by price/choice facts;
- one isolated option variation at a time, not a Cartesian product.

Supported occupancy is never inferred solely from Resource maximum. Missing facts return known lines plus exact missing inputs, not zero. Reuse `EvaluateClientPrice`, `EvaluatePackagePrice`, and shipped economics entry points. Persist no scenario, result, pin, margin, cost, capacity, or demand. The existing manual preview remains the custom-scenario path.

## Proposed workflows and screens

### Screen 1 — Create group departure

Use the existing Departure new/create path.

Visible fields:

- **Departure name** — required for new concepts.
- **When is it?**
  - Not known yet.
  - Month, season, or possible dates (`target_timing_text`).
  - Exact dates (`starts_on`/`ends_on`).
- **Responsible Office** — proposed from current/default Office and changeable.

Advanced disclosure:

- description;
- time zone;
- operating currency;
- responsible Staff member, prefilled with the creator under M2.

Actions:

- **Save and add components** — create, then open first component.
- **Save for later** — create, then open the workspace empty state.

Both require name and responsible Office through a dated amendment to `CreateDeparture`; do not add global database `NOT NULL` constraints. Existing drafts and return-to-draft remain valid. M2 activation completeness remains unchanged. If no active Office exists, explain that one must be created/reactivated; do not invent one.

### Screen 2 — Empty Departure workspace

Keep the existing Departure profile and add **Build this departure** above current Supplier planning and Client offer details.

- Confirm that the concept is saved.
- Show name, target/exact timing, responsible Office, and Draft lifecycle.
- Recommend **Add the first component**.
- Keep existing edit, activate, and Supplier-planning access.

No wizard counter or completion percentage appears.

### Screen 3 — Add the first component

Fields:

- component name;
- optional **When Clients see it** text.

Then ask:

> Will most travelers buy these components together as one main package?

- **Yes, create the main package** — recommended. Show Package name defaulted from Departure name and included/optional placement. Submit `CreateInitialPackageWithOutlineServiceOffer` once. Do not offer this creation action when an editable Package already exists.
- **Not yet** — create an unassigned outline component.

Do not ask for Supplier, fulfillment, price, capacity, cost, terms, or component type.

On success, return to the workspace with **Add another component**. Offer **Save and continue setup** as a secondary path.

### Screen 4 — Add another component

With a primary Package:

- component name;
- optional Client timing;
- Included or Optional placement;
- outline-capable Package inline create.

Without a Package:

- create another unassigned outline;
- show **Create main package** as a secondary action that creates a Package and lets Staff adopt selected drafts;
- do not silently adopt every draft.

**Start from Supplier planning** remains available and uses the shipped source picker.

### Screen 5 — Departure builder workspace

The builder contains:

1. **Recommended next action** — one derived action and reason.
2. **What do you want to work on?** — Client preview, Supplier support, or Pricing; request/session only.
3. **Package summary** — name, pricing readiness, terms summary, and common totals when calculable. If multiple Packages exist, show a Package selector and keep the choice request/session-scoped.
4. **Itinerary components** — Package inclusions in position order, then unassigned drafts in creation order.

Each component card shows:

- Client name/title;
- Included, Optional, or Not yet assigned;
- Client timing or **Timing not added**;
- Decide later, Supplier-backed, On request, Agency fulfilled, or External fulfillment;
- compact Supplier-support and Client-pricing summaries;
- one contextual action;
- remaining checklist in a disclosure.

Existing Service Offer, price, choice, term, Package, Supplier Arrangement, capacity, and cost screens remain authoritative and routable. The builder links to them instead of duplicating their forms.

### Screen 6 — Arrange itinerary

When the Package has at least two inclusions:

- enter explicit reorder mode;
- use keyboard Move up/Move down controls;
- save the complete list through `ReorderPackageInclusions`;
- return to the ordinary card list.

Unassigned cards show **Assign to package to arrange**.

### Screen 7 — Supplier-support path

From a component:

- **Decide how this is provided** offers Supplier, On request, Agency fulfilled, External, or Decide later.
- Supplier opens shipped Departure-scoped source search and binding.
- Required, alternative, and choice-gated bindings remain advanced existing paths.
- Supplier Arrangement editing stays in Supplier planning; no shadow agreement form is added.

Resolving `undecided` is explicit and audited. Existing binding consequence/compatibility rules remain authoritative.

### Screen 8 — Pricing summary

Show common Package scenarios before component worksheets:

- Client total or known subtotal;
- selected components/options;
- exact pending inputs;
- qualified Supplier forecast, commission, and indicative margin only to `manage_departures`;
- expandable calculation lines.

**Set Package price** and **Set component price** link to shipped editors. **Try another scenario** opens the existing manual preview. No full combination explorer or persisted pins ship here.

### Screen 9 — Internal Client preview

Present the existing M4C draft Package preview in Client order:

- Departure name and target/exact timing;
- included and optional components;
- component timing text;
- choices and selected example;
- Client price and terms when known;
- explicit **Pending** labels.

Label it **Internal preview — not shared with Clients**. It creates no PDF, public link, proposal version, notification, publication, or sale.

### Screen 10 — Focused Cruise and Hotel helpers

These are optional actions on an editable component, not stored subclasses.

**Cruise cabin setup** orchestrates existing primitives:

- one Cruise Service Offer;
- one Cabin category choice group;
- category options;
- Resource/Pool-specific activations when known;
- explicitly supported occupancy examples;
- Client price and attributable Supplier economics when available.

**Hotel room setup** uses the same pattern for room categories and occupancy/night examples.

Transportation and activities use generic component, source, choice, and pricing forms. Friendly launch labels may preselect a price pattern, but add no profile/table. If a safe helper needs a new batch command, accept that command’s payload, idempotency, locks, and atomic-failure contract before coding it.

## Minimal contract amendments

1. **M2A:** New Departure creation requires name and responsible Office through `CreateDeparture`; existing drafts and activation completeness otherwise remain unchanged. Add descriptive target timing with no operational authority.
2. **M4A:** Add draft-only `undecided` fulfillment and `client_timing_text`; add outline creation and explicit resolution to a real basis. Published authority remains unchanged.
3. **M4C:** Clarify that an editable unowned draft may be shown as unassigned and adopted later. Add outline-capable inline create, atomic first Package/component create, and expose inclusion reorder. No commercial-scope column.
4. **M4D (shipped):** Extend publication readiness and publish commands so `undecided` fulfillment cannot publish. Do not redesign manifests, Sales enabled, pause/resume/retire, live feasibility, or M3 disclosure. Do not pull a second publication UX into M4D.0; link to the shipped Publish surfaces when readiness says publish is the next useful action.
5. **Interface/terminology:** Add the builder, Client timing text, unassigned draft presentation, derived readiness, and Staff-only internal preview.

ADR 0014 received a dated 2026-09-21 clarification: draft-only `undecided` fulfillment is allowed; published/selectable fulfillment remains the existing closed set; Client timing text is version-owned descriptive prose with no operational authority.


## Exact schema and command catalog (M4D.0a)

M4D.0a is documentation-only. Domain code begins at M4D.0b. The names below are locked for coding slices.

### Columns

| Column | Table | Rules |
| --- | --- | --- |
| `target_timing_text` | `departures` | `string`, null, max 160, blank→null, descriptive only |
| `client_timing_text` | `service_offer_definitions` | `string`, null, max 160, blank→null; draft-mutable; published freeze |
| `fulfillment_basis` | `service_offer_definitions` | extend check/enum with `undecided`; valid only when version is `draft` or `abandoned` |

No timing-kind enum, schedule table, `primary_package_id`, or `independently_sellable`.

### Commands and services

| Name | Kind | Notes |
| --- | --- | --- |
| `CreateDeparture` | amend | require name + responsible Office; accept `target_timing_text` |
| `UpdateDeparture` / existing edit | amend | may set/clear `target_timing_text` |
| `CreateServiceOfferOutline` | new | name + optional timing → SO/version/definition with `undecided`; unowned |
| `CreateInitialPackageWithOutlineServiceOffer` | new | atomic Package + owned outline SO + inclusion; idempotent |
| `CreatePackageInlineServiceOffer` | extend | allow `undecided` + `client_timing_text` |
| `ResolveServiceOfferFulfillmentBasis` | new | draft-only; to `m3_backed` (via existing source path) / `on_request` / `agency_fulfilled` / `externally_fulfilled`; never to `undecided` from a real basis without product amendment |
| `ReorderPackageInclusions` | route only | command + audit already exist |
| `EvaluateDepartureBuilderReadiness` | pure read | four groups; no persistence |
| `RecommendDepartureBuilderAction` | pure read | one actionable recommendation |
| `DeriveCommonPackageScenarios` | pure read | bounded adapter over shipped price evaluators |

Reuse M4A lock order, durable idempotency, and optimistic locks. Atomic first Package/component: no partial rows or success audit on failure.

### Audit actions

| Action | When |
| --- | --- |
| `departure.created` / `departure.updated` | reuse (include target timing in details when present) |
| `service_offer.created` | reuse for outline create |
| `package.created` + `package.service_included` | reuse for atomic first Package/component (same transaction) |
| `service_offer.fulfillment_basis_resolved` | **new** (extend `AuditEvent::ACTIONS` in 0b) — from `undecided` to a real basis |
| `package.inclusions_reordered` | reuse |

No success audit on failed atomic creates.

### Routes (Staff, `manage_departures`)

Implement in 0b–0c:

- Compact Departure create/edit under `departures#new/create/edit/update` — amend params for timing and Office requirement.
- Builder workspace: enrich `departures#show` (no separate resource).
- `POST .../departures/:id/service_offer_outlines` — `CreateServiceOfferOutline`.
- `POST .../departures/:id/initial_package_outline` — `CreateInitialPackageWithOutlineServiceOffer`.
- Later outline inline: extend existing package inline POST.
- `POST .../service_offers/:id/resolve_fulfillment` — `ResolveServiceOfferFulfillmentBasis`.
- `PATCH .../packages/:id/inclusions/reorder` — `ReorderPackageInclusions` (mirror existing M3 reorder collections).
- Working-outcome and scenario filters: query params on show only (request/session; not persisted).

### Fixture ledger (small mixed journey)

| Label | Fact class | Example |
| --- | --- | --- |
| Confirmed | Agency/Office/Staff | Harbor fixtures |
| Illustrative | Departure concept | 3-day seasonal target timing text |
| Illustrative | Package | Primary Package from Departure name |
| Illustrative | Components | included transport, Hotel (Standard/Deluxe choice), activity; optional meal pending price |
| Undecided | One component | fulfillment `undecided` until resolve |
| Confirmed-shape | One M3 bind | use activated Arrangement when proving Supplier path |
| Illustrative | Prices | enough for one complete 2-person scenario; optional meal incomplete |
| Forbidden | Invented Supplier fares / zero-for-unknown / capacity reservation | never |

Celebrity/Vineyard remain regression fixtures; do not invent M3F supplier fares into Client prices. M4D.0e proves this ledger plus those regressions.

## Slice and PR sequence

### M4D.0a — Authority and exact schema (complete)

Accepted 2026-09-21. Plan promoted; amendments and the exact catalog above are authoritative. No domain code in 0a.

**Exit:** no contradiction with M2A, M4A, M4C, ADR 0014, or shipped M4D; M4E remains unimplemented.

### M4D.0b — Concept and outline foundation

- Target timing and compact Departure create/edit.
- Undecided fulfillment and Client timing.
- Outline create, atomic first Package/component, outline inline create, and resolve-fulfillment commands.
- Database, command, audit, idempotency, permission, and race proof.

**Exit:** Staff can save a concept and included/optional rough list without Supplier or pricing decisions.

### M4D.0c — Builder workspace and guidance

- Empty/populated builder panels and component flows.
- Package reorder surface.
- Four-group readiness and one recommendation.
- Request/session working-outcome presentation.
- Keyboard, recovery, responsive, tenant, Viewer, and query proof.

**Exit:** Staff can return and understand the end result and next useful action from one page.

### M4D.0d — Package-first pricing and internal preview

- Bounded common-scenario derivation over shipped evaluators.
- Pending subtotal/missing-input presentation.
- Package-first summary and Staff-only Client preview.
- Rounding, occupancy, choice, shared-cost, permission, and evaluator-parity proof.

**Exit:** common Client totals and pending facts are continuously understandable without side effects.

### M4D.0e — Focused helpers and acceptance

- Cruise cabin and Hotel room helpers.
- Generic Transportation/activity launch presets only.
- Small mixed journey, Celebrity regression, and Vineyard regression.
- Measured entries/context switches, accessibility/viewports, M2–M4 regressions, and full CI.

**Exit:** the builder is easier without adding a second domain model or regressing shipped M4D publication invariants.

## Small mixed acceptance journey

Use a three-day trip with included transportation, included Hotel with Standard/Deluxe choice, included scheduled activity, and optional meal/excursion with pending price.

1. Save it with a seasonal target and responsible Office.
2. Add transportation and create the primary Package.
3. Add Hotel, activity, and optional meal individually.
4. Arrange the inclusions.
5. Leave fulfillment undecided on one; bind one to Supplier planning; mark one Agency fulfilled.
6. Add enough pricing for a complete ordinary scenario and a visibly partial optional scenario.
7. Review the internal Client preview.
8. Switch among Supplier support, Pricing, and Client preview; the recommendation changes without persisted workflow state.

Prove that saving requires no invented Supplier fact, pending amounts never become zero, and previews reserve no capacity or demand.

## Deferred—not hidden

- Supplier-document upload and storage.
- Structured Client schedules beyond descriptive text.
- Persisted preparation focus, Supplier-stage targets, and overrides.
- Departure-wide ordering for unassigned components.
- Full scenario explorer and persisted pins.
- Transportation/Activity specialized profiles.
- Share-ready proposal gate, Client proposal link/versions/change notices/notifications.
- Departure sales-action policy, inquiry, booking request, Hold, and deposit confirmation.
- Automatic confirmation/payment and no-payment fallback request.
- Client/Supplier funding-gap policy and acknowledgment.
- Redesign of shipped publication, pause/resume/retire, live feasibility, or M3 offer-path disclosure (owned by M4D; M4D.0 only extends reject-`undecided` and links to existing Publish UI).
- Every M5 Client Trip, Allocation, Charge, Receipt, Payment, and confirmation record.
- M4E acceptance/hardening until this narrow builder is accepted and shipped (unless an accepted M4E plan names another base).

Deferral means no migrations, empty tables, feature flags, placeholder enums, or disabled controls for these concerns in M4D.0.

## Cross-cutting proof

1. Session-derived Agency owns every load; Office remains attribution, not permission.
2. Cross-Agency/Departure/version identifiers fail closed in Rails and PostgreSQL where persisted.
3. New commands follow M4A lock order, durable idempotency, optimistic locking, and bounded audit details.
4. Atomic first Package/component failure leaves no partial record or success audit.
5. `undecided` never appears as published or selectable fulfillment.
6. Client timing never drives dates, compatibility, capacity, deadlines, or money dates.
7. Existing M4 evaluators remain the single arithmetic authority.
8. Unknown values stay unknown; partial results identify missing inputs and are not totals.
9. Preview creates no M3 or M5 operational/accounting rows.
10. Viewer receives no unpublished builder, Supplier cost, or margin content.
11. Full-page fallback, `#form-error-summary`, keyboard use, visible focus, and 375/768/1280/1400 reflow pass.
12. Required CI passes at each final PR tip.

## Exit

M4D.0 domain and [M4D.0R](m4d0r-builder-interface-remediation.md) Staff presentation are shipped together on PR #122. The builder is a calm task workspace with the accepted screen hierarchy, recommendation contract, identity-preserving Supplier bind, and system proof. It reuses shipped Service Offer, Package, pricing, choice, terms, Supplier-planning, and M4D publication authority. It creates no second publication path, proposal distribution, sales action, Client demand, or money record, and it must not allow `undecided` fulfillment to publish.

The next planning action after this builder ships is Accepted [M4D.1](m4d1-departure-composition-workspace.md) for the Departure Composition Workspace (implementation only when a named sub-slice accepts work), then to accept and run [M4E](drafts/DepartureDesk-M4E-acceptance-and-hardening-draft.md) against the Staff journey that actually shipped—not against speculative proposal or M5 workflows. Discovery items still parked only in the [streamlined draft](drafts/DepartureDesk-M4D0-streamlined-group-departure-builder-draft.md) need their own accepted slice before code.

## Dated amendment — M4D.0R (2026-09-21)

Staff interaction and presentation for the narrow builder are governed by [M4D.0R](m4d0r-builder-interface-remediation.md) as **interim** UI. Domain columns, commands, audits, and publication reject-`undecided` in this document remain authoritative. M4D.0R does not add a second outline model, `primary_package_id`, or proposal distribution.

## Dated amendment — M4D.1 (2026-09-21)

Domain columns, commands, audits, and publication reject-`undecided` in this document remain authoritative. Staff chrome **beyond** the interim M4D.0R builder is governed by Accepted [M4D.1 — Departure Composition Workspace](m4d1-departure-composition-workspace.md). Do not implement M4D.1 until that plan’s accepted sub-slice names the work.
