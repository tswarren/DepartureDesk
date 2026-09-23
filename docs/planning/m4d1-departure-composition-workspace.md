# M4D.1 — Departure Composition Workspace

**Status:** Accepted 2026-09-21. Implementation authority for the Departure Composition Workspace milestone and its sub-slices (1, 2A–2D, 3, 4, 5). Not authority for M4E, M5, source-document storage, proposal share, notifications, or money ledgers. Do not implement a sub-slice until that sub-slice’s accepted plan (or this parent’s named slice section used as exact authority) names the work.

**Slice 1:** [M4D.1 Slice 1 — Workspace foundation](m4d1-slice1-workspace-foundation.md) is **Shipped 2026-09-22**. It provides the five-area Composition shell, Service Map, readiness mapping, and `/builder` compatibility redirect.

**Slice 2A.1:** [M4D.1 Slice 2A.1 — Cruise sailing and cabin inventory](m4d1-slice2a1-cruise-sailing-and-cabin-inventory.md) is **Shipped 2026-09-22**. It is the sole shipped authority for typed Cruise Stop points A–B.

**Slice 2A.2:** [M4D.1 Slice 2A.2 — Cruise Supplier rates and occupancy totals](m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md) is **Shipped 2026-09-22** (historical fixed-form baseline for Stop point C).

**Slice 2A.2R:** [M4D.1 Slice 2A.2R — Cruise Supplier Rate Matrix](m4d1-slice2a2r-cruise-supplier-rate-matrix.md) is **Shipped 2026-09-22**. It is the sole shipped authority for remediating Stop point C into a rate-profile matrix (M3C compilation and compatibility).

**Slice 2A.2R2:** [M4D.1 Slice 2A.2R2 — Cruise Supplier Rate Matrix Interaction](m4d1-slice2a2r2-cruise-rate-matrix-interaction.md) is **Shipped 2026-09-22**. It is the sole shipped authority for the interactive matrix builder remediation (dynamic columns/rows, method-gated commission chrome, unsaved illustrations, browser acceptance).

**Slice 2B-R:** [M4D.1 Slice 2B-R — Cruise Deposit Semantics Amendment](m4d1-slice2br-cruise-deposit-semantics-amendment.md) is **Shipped 2026-09-22**. It is the sole shipped authority for generic M3E capacity-sourced deposit quantities (`capacity_pool_units`) and source-aware cumulative targets.

**Slice 2A.2R3:** [M4D.1 Slice 2A.2R3 — Cruise Rate-Shape Detector Remediation](m4d1-slice2a2r3-cruise-rate-shape-detector-remediation.md) is **Shipped 2026-09-23**. It is the sole shipped authority for percentage↔profile / collision-safe cell-key detector remediation.

**Slice 2B:** [M4D.1 Slice 2B — Cruise Deposits, Deadlines, and Activation-Safe Editing](m4d1-slice2b-cruise-deposits-deadlines-and-activation-safe-editing.md) is **Accepted**. It is the sole authority for typed Cruise Stop point D. **2B-A and 2B-B delivered**; 2B-C remains open. Not fully shipped. Later slices remain unauthorized until named.

**Staff UI:** Composition (`/departures/:id/composition`) is the primary Staff chrome for draft and active Departures with `manage_departures`. [M4D.0R](m4d0r-builder-interface-remediation.md) is retained as historical interim authority. `GET /departures/:id/builder` redirects with mapped `work_on` → outcome and validated `package_id`.

**Implementation baseline:** [`c64f973`](https://github.com/tswarren/DepartureDesk/commit/c64f973) (merge of [PR #122](https://github.com/tswarren/DepartureDesk/pull/122)). Production M4D.0/M4D.0R code last changed at [`893b7c3`](https://github.com/tswarren/DepartureDesk/commit/893b7c3); later PR #122 commits accept M4D.1 and update documentation (plus gate fixes) without changing the M4D.0 domain model.

**Relationship to M4E:** [M4E](drafts/DepartureDesk-M4E-acceptance-and-hardening-draft.md) remains the later offers acceptance-and-hardening gate. M4D.1 does not replace M4E. M4E must not close M4 without acknowledging how the Staff journey relates to M4D.1 (Composition workspace vs interim builder history).

**Related authority and discovery:**

- [M4 — Offers and pricing](m4-offers-and-pricing.md)
- [M4.0 — Task flow and contract](m40-task-flow-and-contract.md)
- [M4A — Service definitions and sources](m4a-service-definitions-and-sources.md)
- [M4B — Client pricing and anonymous preview](m4b-client-pricing-and-anonymous-preview.md)
- [M4C — Packages, choices, and Client terms](m4c-packages-choices-and-client-terms.md)
- [M4D — Publication and live feasibility](m4d-publication-and-live-feasibility.md) (shipped)
- [ADR 0014 — Client offers, publication, and Supplier-source compatibility](../adr/0014-client-offers-publication-and-supply-compatibility.md)
- [M4D.0 — Narrow group departure builder](m4d0-narrow-group-departure-builder.md) (shipped domain)
- [M4D.0R — Builder interface remediation](m4d0r-builder-interface-remediation.md) (historical interim UI; primary chrome superseded by Slice 1 Composition)
- [M4D.1 Slice 1 — Workspace foundation](m4d1-slice1-workspace-foundation.md) (shipped)
- [M4D.1 Slice 2A.1 — Cruise sailing and cabin inventory](m4d1-slice2a1-cruise-sailing-and-cabin-inventory.md) (shipped; sole A–B authority)
- [M4D.1 Slice 2A.2 — Cruise Supplier rates and occupancy totals](m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md) (shipped historical fixed-form baseline)
- [M4D.1 Slice 2A.2R — Cruise Supplier Rate Matrix](m4d1-slice2a2r-cruise-supplier-rate-matrix.md) (shipped; sole C matrix compilation authority)
- [M4D.1 Slice 2A.2R2 — Cruise Supplier Rate Matrix Interaction](m4d1-slice2a2r2-cruise-rate-matrix-interaction.md) (shipped; sole interactive builder chrome authority)
- [M4D.1 Slice 2B-R — Cruise Deposit Semantics Amendment](m4d1-slice2br-cruise-deposit-semantics-amendment.md) (shipped; sole Path B deposit quantity/cumulative authority)
- [M4D.1 Slice 2A.2R3 — Cruise Rate-Shape Detector Remediation](m4d1-slice2a2r3-cruise-rate-shape-detector-remediation.md) (shipped; sole detector remediation authority)
- [M4D.1 Slice 2B — Cruise Deposits, Deadlines, and Activation-Safe Editing](m4d1-slice2b-cruise-deposits-deadlines-and-activation-safe-editing.md) (Accepted; sole typed Stop D authority)
- [M4D.0 — Streamlined group departure builder](drafts/DepartureDesk-M4D0-streamlined-group-departure-builder-draft.md) (discovery backlog only)
- [ADR 0010](../adr/0010-supplier-capacity-ledger-and-projection.md) · [ADR 0011](../adr/0011-supplier-cost-definitions-and-forecast-evaluation.md) · [ADR 0012](../adr/0012-arrangement-activation-reservations-and-confirmations.md) · [ADR 0013](../adr/0013-supplier-operational-commitments-deadlines-exposure-and-ending.md)
- [M3B](m3b-supplier-capacity.md) · [M3C](m3c-cost-terms-and-forecasts.md) · [M3D](m3d-activation-reservations-confirmations.md) · [M3D.7](m3d7-activated-definition-immutability.md) · [M3E](m3e-supplier-operational-control.md)
- Historical discovery: [group-departure wizard notes](drafts/DepartureDesk-group-departure-wizard.md) (stub → this plan)

## 1. Purpose

DepartureDesk must let an average travel agent compose a departure without understanding the underlying Service Offer, Package-version, Supplier Arrangement, Item, Occurrence, Resource, Pool, cost-component, binding, and price-component graph.

The product direction is a **Departure Composition Workspace** with five persistent areas:

1. **Overview** — What is this Group and what do we know?
2. **Services** — What will Clients experience, choose, or pay for distinctly?
3. **Suppliers** — Who provides it, what have they committed to, and what will it cost?
4. **Package & Client terms** — What are we selling, what choices exist, and how will Clients be charged?
5. **Review** — What can we confidently prepare for the selected outcome, and what remains incomplete?

These are navigation lenses over existing records. They are **not** a linear wizard, a persisted workflow, a completion gate, or a second domain model.

## 2. Product outcome

An authorized Staff user can begin with whichever source of truth is strongest:

- a Supplier proposal or contract;
- a Client-facing itinerary or Package idea;
- a rough list of Services;
- or only the Group concept.

The user may then move freely among the five areas while DepartureDesk:

- preserves incomplete work without fabricating facts;
- translates typed agency forms into the existing generic M3/M4 graph;
- keeps Supplier and Client terms distinct;
- connects Supplier services to Client-facing Services explicitly;
- compiles known Client totals while identifying exact pending inputs;
- and recommends one next action for the outcome the user is currently preparing.

The Smith Family Cruise is the first end-to-end proof theme. The Vineyard Tour is the anti-hardcoding proof that the workspace, scenario, economics, and typed-form contracts remain general.

## 3. Decisions frozen by this contract

1. The five areas are persistent, freely navigable Departure areas. No area must be completed before another opens.
2. `Departure` remains the operational root. The UI may say **Group** where that is clearer; no `Group` model is added.
3. Draft `ServiceOffer` remains the stable Client-facing Service Map identity. No `DepartureComponent`, `ItineraryComponent`, temporary outline aggregate, or later promotion process is added.
4. An `ArrangementItem` remains the Supplier-side service identity. Supplier-only Items do not require Service Offers.
5. `ServiceOfferSourceBinding` remains the explicit connection between Client intent and exact Supplier support.
6. Typed Cruise, Hotel, Transportation, Activity/Meal/Excursion, and mixed-DMC forms are application-layer adapters over generic M3/M4 records and commands. They do not create service-type STI, cruise-specific persistence, or a second calculation engine.
7. Supplier terms and Client terms remain separate. Supplier costs never become Client prices silently.
8. Starting Client terms from Supplier terms creates an independent Client draft with copy-time provenance. Later Supplier changes flag review and never overwrite Client terms.
9. Area status, readiness, completion, and recommended action are derived. No area-completion flags, workflow-step rows, percentages, or manual-complete toggles are persisted.
10. Missing or unresolved values remain pending. They are never substituted with zero, omitted from the explanation, or treated as complete.
11. Review extends the existing readiness/recommendation model with outcome filters. It does not create a second findings catalog.
12. The workspace may author and preview M4 Client payment schedules, cancellation policies, and stated conditions. It does not instantiate Charges, Obligations, Receipts, Payments, actual cancellations, or actual cash position.
13. Planning cash-gap results, when later added, are assumption-bound projections rather than statements of actual cash availability.
14. Source documents, Client proposal distribution, shared links, notifications, actual bookings, named Travelers, and money ledgers are not exit criteria for this workspace milestone.
15. The Smith proof is a milestone theme divided into independently accepted and independently shippable sub-slices. It is not one transaction, one command, or one undifferentiated PR.

## 4. Vocabulary and conceptual boundaries

| User-facing term | Domain meaning |
| --- | --- |
| Group | One `Departure`; user-facing wording only |
| Service | One Client-recognizable `ServiceOffer`, whether included, optional, or not yet assigned to a Package |
| Supplier service | One `ArrangementItem`, optionally with Occurrences, Resources, Pools, costs, and deadlines |
| Arrangement | One independently governed Supplier agreement or proposal, not one row per Supplier and not one row per Departure |
| Supplier support | Exact M3 source bindings or an explicit non-M3 fulfillment basis |
| Package | One versioned Client composition of included and optional Service Offer versions |
| Client term | A Client price component, payment term, cancellation term, or stated condition; never a Supplier cost record |
| Travel configuration | An anonymous pricing/review input such as Single, Double, or Triple; not a named Traveler |
| Enrollment assumption | A planning assumption used for shared costs or thresholds; not a booking, demand record, or travel configuration |
| Ready for outcome | Derived readiness for the currently selected objective, not global completion |

Single, Double, and Triple are occupancy or booking configurations. They are not “Traveler profiles.” Adult, child, infant, and tour leader are participant categories. Named Travelers remain later commercial/operational records.

## 5. Authority and baseline

**Implementation baseline:** [`c64f973`](https://github.com/tswarren/DepartureDesk/commit/c64f973) (PR #122 merge). Production M4D.0/M4D.0R code last changed at [`893b7c3`](https://github.com/tswarren/DepartureDesk/commit/893b7c3); later PR #122 commits were documentation and gate fixes only. M4D.0 domain and M4D.0R interim UI are **shipped** on that production-code baseline.

Shipped baseline this plan extends (not re-proves as invention):

- descriptive `Departure#target_timing_text`;
- draft-only `undecided` Service Offer fulfillment;
- Client timing text on draft Service Offer definitions;
- outline-first Service Offer commands;
- atomic initial Package plus Service creation;
- unowned draft Services presented as **Not yet assigned to a Package**;
- Package inclusion ordering;
- derived builder readiness and a single recommendation (`EvaluateDepartureBuilderReadiness` / `RecommendDepartureBuilderAction`);
- bounded common-scenario derivation over shipped evaluators;
- dedicated builder route as **interim** primary Staff surface for `manage_departures`.

**Supersession:** M4D.1 is Accepted Staff composition presentation authority. Slice 1 is shipped: Composition is primary Staff chrome and `/departures/:id/builder` is a compatibility redirect. M4D.0R remains historical interim presentation authority only.

Implementing sub-slices must re-verify commands against the pinned SHA. If a required command or column is missing from the base, the sub-slice plan names it explicitly.

## 6. Current capability, required change, and deferred work

| Capability | Contract classification |
| --- | --- |
| Departure identity, exact dates, responsibility, currency, time zone | Shipped M2 |
| Supplier Arrangement/Item/Occurrence/Resource/Pool/cost/deadline graph | Shipped M3 |
| Draft Service Offer, exact source binding, compatibility | Shipped M4A |
| Client price components and anonymous preview | Shipped M4B |
| Package, choices, payment/cancellation/stated terms | Shipped M4C |
| Rough timing, outline-first Service, main-Package prompt, derived builder guidance | Shipped M4D.0 / interim M4D.0R |
| Five persistent areas and Service Map primary surface | Required workspace change |
| Typed Supplier arrangement adapters | Required successor build |
| Connect-each-Item workflow | Required successor build |
| Durable choice-option to Client-rate-category mapping | Required contractual/persistence change |
| Supplier-to-Client price-copy provenance | Required contractual/persistence change for “start from Supplier terms” |
| Client term compiler and common Cruise scenario review | Required successor build |
| Rich combined/itemized/internal presentation modes beyond the minimum Smith need | Later successor slice unless separately accepted |
| Persisted Departure-level scenarios | Deferred until a separate accepted semantic contract |
| Several structured possible date windows | Deferred; descriptive rough timing remains non-authoritative |
| Source-document storage | Optional separate slice; excluded from workspace exit |
| Shared proposal, link versioning, notifications | Deferred M4D/publication work |
| Named Travelers, bookings, Holds, Allocations | Deferred M5 |
| Charges, Receipts, Obligations, Payments, actual cash | Deferred later commercial/accounting work |

## 7. Global interaction contract

Every area and typed adapter must obey the following rules:

1. Save incomplete work at named durable stop points.
2. A section save is atomic for that section only; there is no whole-Departure or whole-Arrangement mega-transaction.
3. Show one primary action per decision region.
4. Show one recommended next action for the selected outcome plus a remaining checklist.
5. Do not show a completion percentage.
6. Do not request a fact already available from the exact bound source unless the Client-facing value is intentionally independent.
7. Do not silently create a Package, Service Offer, Arrangement, Supplier Item, choice, price, or binding.
8. Explain the record-level result in agency language before consequential creation: for example, “Create one Cruise Service and connect these cabin categories.”
9. Preserve submitted values, selected branch, active area, and return target on `422 Unprocessable Entity`.
10. Return from a focused editor to the originating Service, Arrangement, Package, or Review finding.
11. Known subtotals remain visible beside exact pending inputs.
12. Technical lineage, version IDs, lock versions, membership kinds, and calculation enums belong in disclosures or advanced editors.
13. Keyboard operation, full-page fallback, visible focus, and the repository viewport contract remain required.
14. Viewer permissions do not expand. Unpublished composition work remains `manage_departures` only.

## 8. Workspace shell and navigation

### 8.1 Persistent header

Show:

- Departure/Group name;
- lifecycle status;
- rough or exact timing;
- responsible Office;
- current Package context when more than one Package exists;
- a secondary **Departure details** action.

Do not place the full administrative Departure definition before the workspace.

### 8.2 Persistent areas

The primary navigation contains exactly:

1. Overview
2. Services
3. Suppliers
4. Package & Client terms
5. Review

Existing advanced surfaces remain reachable from the relevant area during rollout. They do not appear as equal panels in one long page.

### 8.3 Derived area statuses

The visible status vocabulary is:

- **Not started**
- **In progress**
- **Needs attention**
- **Ready for outcome**

`SummarizeDepartureCompositionAreas` is a pure read adapter over existing records and the outcome-filtered readiness result. It persists nothing.

| Status | Derivation rule |
| --- | --- |
| Not started | No durable record relevant to that area exists |
| In progress | Relevant records exist and the area is neither ready nor carrying an actionable correctness/attention finding for the selected outcome |
| Needs attention | At least one outcome-relevant actionable `blocked` or `needs_attention` finding applies |
| Ready for outcome | Every required criterion for the selected outcome is satisfied; unrelated later work does not demote it |

The selected outcome is request/session presentation state. It is not persisted on the Departure.

## 9. Area 1 — Overview

### 9.1 User question

> What is this Group, what do we know, and where should I begin?

### 9.2 Initial creation

The minimum save remains:

- Group/Departure name;
- responsible Office/team, proposed from current/default Office and changeable;
- optional rough or exact timing;
- optional description.

Do not require a Package, Supplier, Service, exact schedule, currency, or time zone merely to preserve the concept. Existing M2 activation completeness remains authoritative.

### 9.3 Post-save starting point

After first save, ask:

> What are you starting with?

- **A Supplier proposal or contract** — open Suppliers and start an Arrangement.
- **A Client-facing itinerary or Package idea** — open Services and add the first Client-facing Service.
- **A rough list of Services** — open multi-row outline entry.
- **Nothing else yet** — return to Overview with the concept-safe confirmation.

The answer controls navigation only. It does not classify the Departure and is not persisted.

### 9.4 Established Overview

Show:

- identity and timing;
- responsibility;
- preparation-outcome selector;
- five-area summary;
- one recommended next action;
- material upcoming Supplier deadlines;
- a short unresolved-decision list;
- optional source-material link only if a separately accepted attachment capability exists.

Do not turn Overview into a generic KPI dashboard or repeat every Service, Arrangement, and price row.

### 9.5 Required actions

- Edit Group details
- Add a Service
- Add a Supplier arrangement
- Continue the recommended action
- Change preparation outcome

## 10. Area 2 — Services

### 10.1 User question

> What will Clients experience, choose, or pay for distinctly?

### 10.2 Primary Service Map

Each ordinary row is one `ServiceOffer` identity and its editable/published version context.

| Column | Contract |
| --- | --- |
| Service | Client-facing title; Service type is secondary |
| Timing | Exact bound timing where applicable plus optional Client timing text; never falsely parse approximate text |
| Placement | Included, Optional, or Not yet assigned to a Package |
| Supplier support | Connected Arrangement/Supplier summary, explicit non-M3 basis, or Undecided |
| Client terms | Complete, Partly complete, Pending, or Known zero with reason |
| Next action | One contextual action, not every possible editor |

Package inclusions appear in Package order. Unowned draft Services follow in creation order. Supplier-only Items do not appear as fake Service rows.

### 10.3 What deserves a separate Service

Create a separate Service when Clients:

- see it as a distinct itinerary event;
- choose it separately;
- pay for it separately;
- can include or omit it separately;
- or receive a distinct operational promise.

Do not create separate Services for:

- Supplier cost lines;
- cabin or room categories;
- taxes and fees;
- internal Supplier administration;
- resources inside one Client-recognizable service.

### 10.4 Add one Service

Ordinary fields:

- Client-facing name;
- optional Client timing text;
- optional type;
- Package placement: Included, Optional, or Decide later.

Do not require Supplier, fulfillment, capacity, price, or terms.

After save, offer:

- Add another Service
- Connect Supplier support
- Set up Service details
- Return to Services

### 10.5 Multi-row outline entry

The optional multi-row surface accepts repeated:

- name;
- optional type;
- optional timing;
- placement.

Each submitted row uses existing outline/Package commands with one outer idempotent orchestration. Validation failure leaves no half-created row set unless the form explicitly offers **Save valid rows and review the rest**; the first implementation should prefer all-or-nothing batch creation.

### 10.6 Specialized Client-facing forms

Specialized Service forms edit Client-facing facts only:

- Cruise — displayed sailing, cabin-category choices, Client occupancy/rate presentation;
- Hotel — room choices, stay choices, displayed nights and taxes;
- Transportation — visible segments and route choices;
- Activity/Meal/Excursion — date/time, inclusion, choice, and Client-facing conditions.

Supplier costs and commitments remain in Suppliers even when summarized here.

### 10.7 Rollout fallback

Until each typed Supplier adapter ships, Services must provide an explicit **Open current Supplier planning** or **Connect using advanced source selection** path. Slice 1 is not allowed to strand Staff in a new shell with no effective Supplier workflow.

## 11. Area 3 — Suppliers

### 11.1 User question

> Who provides this departure, what have they committed to, what will it cost, and what must the agency do?

### 11.2 Arrangement list

Show one row per Arrangement, not one row per Supplier:

- Arrangement name;
- contracting Supplier;
- provided-service count;
- draft/active/successor state;
- Supplier-support target and current stage;
- next material deadline;
- Needs-attention summary;
- connected Client Services count.

### 11.3 Add Arrangement

Initial fields:

- Supplier;
- Arrangement name;
- typed setup selection: Cruise, Hotel, Transportation, Activity/Meal/Excursion, Mixed arrangement, or Advanced/general.

The typed setup choice selects a form adapter. It does not persist a service subclass or constrain future Items.

**Slice 2A.1 amendment (2026-09-22):** [Slice 2A.1](m4d1-slice2a1-cruise-sailing-and-cabin-inventory.md) does **not** implement a source-stage prompt or an optional proposal/contract-document reference. Existing Arrangement state, cost-definition stage, activation, Reservation, and confirmation facts remain authoritative. The typed Cruise entry begins directly with the agreement and sailing facts. A durable proposal/held/contracted commercial stage distinct from those meanings, and a truthful generic supporting-material/reference contract, each require a separately accepted plan.

### 11.4 Common arrangement sections

Every typed adapter presents the relevant subset of:

1. Agreement
2. Provided services
3. Schedule
4. Resources and options
5. Capacity
6. Supplier costs
7. Deposits and deadlines
8. Client-package connections

Each section has an independent save boundary and a visible saved/pending state. Staff can leave after any successful section save.

### 11.5 Adapter architecture

Typed adapters may be form objects and orchestration services. They must call or compose the shipped bounded commands and preserve their authorization, tenancy, lock order, idempotency, audit, freeze, and successor rules.

They must not:

- write around domain commands with controller `create!` sequences;
- mutate an activated definition graph;
- add Cruise/Hotel/Coach STI or type-specific tables;
- invent a second cost or capacity evaluator;
- infer unprovided Supplier facts;
- activate an Arrangement merely because a typed section is complete.

### 11.6 Draft and activated Arrangements

- A never-activated Arrangement edits its current draft version.
- An active Arrangement’s governing activated version remains immutable.
- Editing future terms uses the shipped successor-draft copy path.
- Typed forms must label whether Staff are editing a proposal/draft, the governing activated terms, or a successor draft.
- Source bindings continue to obey M4A/M4D activated-version publication rules.
- M3D.7 Rails and PostgreSQL mutation guards remain authoritative.

### 11.7 Connect-each-Item bridge

For each Supplier Item, Staff can choose:

- Connect to an existing Client Service
- Create a new Client Service
- Keep Supplier-only
- Decide later

Creating or connecting requires explicit confirmation. No Arrangement Item automatically becomes a Service Offer.

The bridge must preserve one-to-many and many-to-one shapes:

- several cabin-category Resources support one Cruise Service;
- Standard and Deluxe dinner Items support one Dinner Service with choices;
- several transfer Occurrences may support one Transportation Service or separate Services depending on Client visibility;
- internal fees may remain Supplier-only.

## 12. Typed Cruise arrangement contract

The first typed adapter is the Smith Family Cruise proof. It uses generic M3/M4 records and the named durable stop points below.

### 12.1 Stop point A — Agreement and sailing saved

Staff enter:

- contracting Supplier;
- Arrangement name;
- cruise line and effective provider where different;
- ship;
- itinerary/sailing name;
- start/end dates and time zone.

**Slice 2A.1 amendment (2026-09-22):** Group number and contract-document reference are deferred. Group numbers belong on `SupplierIssuedIdentifier` with confirmation provenance via the Reservation/confirmation path. Proposal/contract-document reference awaits a separately accepted supporting-material contract. See [Slice 2A.1](m4d1-slice2a1-cruise-sailing-and-cabin-inventory.md).

One section command creates or updates, as applicable:

- Arrangement draft/version;
- one Cruise Item/definition;
- one sailing Occurrence/definition (**Smith Family Cruise shape** — one sailing Occurrence for this proof; not a universal cruise-adapter invariant that every typed cruise must have exactly one Occurrence);
- exact provider inheritance/override facts.

It creates no cabin Resource, Pool, cost, deadline, Service Offer, choice, or Client price.

Failure leaves no partial sailing graph. Success returns the same Arrangement workspace and recommends adding cabin categories.

### 12.2 Stop point B — One cabin category saved

For each category, Staff enter:

- Supplier code;
- Client-friendly/category name;
- maximum occupancy when known;
- inventory mode;
- blocked/held quantity when numeric;
- measurement basis, fixed by the adapter to cabin/resource units;
- Supplier evidence under the shipped M3B contract (optional; complete evidence tuple required if any ordinary evidence field is entered; override semantics unchanged).

One section command creates or updates:

- one stable Supplier Resource and version definition;
- one Occurrence–Resource pair classification where required;
- one cabin-unit Capacity Pool and draft definition when capacity is configured.

Saving O1 does not require rates, deposits, deadlines, a Client Service, or other categories. Each category is independently resumable and idempotent.

The adapter may suggest Single/Double/Triple preview configurations from maximum occupancy, but suggestion is not persistence, support authority, or a price. Creating occupancy profiles requires explicit Staff confirmation at Stop C (and only for supported configurations).

### 12.3 Stop point C — One category’s Supplier rates saved

**Shipped Slice 2A.2** remains the historical fixed-form baseline: [M4D.1 Slice 2A.2](m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md).

**Shipped Slice 2A.2R** is sole shipped authority for rate-matrix compilation: [M4D.1 Slice 2A.2R](m4d1-slice2a2r-cruise-supplier-rate-matrix.md). **Shipped Slice 2A.2R2** is sole shipped authority for interactive builder chrome: [M4D.1 Slice 2A.2R2](m4d1-slice2a2r2-cruise-rate-matrix-interaction.md).

Staff enter rates as a matrix of rate profiles × charge/credit rows, with shared or profile-specific commission, Every Traveler / Every Cabin families, Adult/Child categories with overlap resolution, custom rows, legacy projection and confirmed conversion, and the generic zero-amount readiness amendment.

Suggested Single/Double/Triple configurations from maximum occupancy are **ephemeral per-cabin illustrations** only. They are not persistence, support authority, or a price. Persisted occupancy profiles represent **confirmed forecast quantities** after explicit Staff confirmation, and only for configurations the entered category facts support (for example Single and Double when maximum occupancy is 2; Triple only when Triple is supported). Never create a fixed always-three profile set, and never auto-create profiles without Staff confirmation.

The orchestration writes generic:

- Supplier cost source;
- cost definition;
- ordered cost components and base links;
- usage assumption;
- occupancy profiles only after that explicit confirmation;
- participant/position rows required by M3C.

Every field maps to a named M3 calculation primitive. Unsupported contract language routes to the advanced cost editor; it is never flattened into a guessed fixed amount.

The section preview shows known gross Supplier totals, expected commission, and net Supplier cost for each **supported** occupancy configuration. While working, missing commission leaves commission and net pending while preserving gross totals. When forecast-ready with commission omitted, commission is none and net equals gross.

### 12.4 Stop point D — Deposits and deadlines saved

Typed Stop D authority: Accepted [Slice 2B](m4d1-slice2b-cruise-deposits-deadlines-and-activation-safe-editing.md).

The Cruise form supports the accepted Celebrity shapes:

- initial deposit;
- cumulative target/final deposit;
- fixed option or release date;
- earlier-of named milestone and fallback date;
- final payment;
- rooming list;
- other supported Supplier deadlines.

Path B cabin-quantity / cumulative economics are authorized by shipped [Slice 2B-R](m4d1-slice2br-cruise-deposit-semantics-amendment.md). Do not invent a separate legal-names Deadline for the canonical fixture; `names_assigned_to_supplier` remains the final-deposit trigger only.

Deposit definitions, deadline definitions, coverage, and later materialized commitments remain M3E records. The typed adapter does not call a deposit “paid,” create a Supplier Obligation, or create a Payment.

Rates and deadlines save independently. A deadline validation failure cannot roll back valid previously saved rates.

### 12.5 Stop point E — Cruise connected to Client Service

Staff choose:

- an existing Cruise Service;
- create one new Cruise Service;
- or decide later.

For a new Service, the command creates one Service Offer/version/definition. It does not create one Service Offer per cabin category.

For each Client-selectable cabin category, it creates or confirms:

- one exact source binding to the Arrangement version, Item, sailing Occurrence, Resource, and Pool where applicable;
- `choice_gated` membership when the category is selected through a Client choice;
- one cabin-category choice group with `min_selections = 1`, `max_selections = 1`;
- one choice option per exposed category;
- one same-version source activation per option.

The command refuses to create a second Service Offer when the user is adding support to an existing outline Service.

### 12.6 Stop point F — Client terms saved

Staff select one cabin category and compile independent Client price components for:

- first/second fare;
- additional-person fare;
- single supplement or single-position price shape supported by M4B;
- NCCF;
- taxes and fees;
- named discounts or surcharges.

The minimum Smith slice supports additive, separately explained taxes and fees using shipped `tax_fee` Client components. Rich combined/internal presentation modes are not required for this stop point unless separately accepted.

Staff may:

- enter Client terms independently;
- copy selected compatible Supplier components as independent Client drafts;
- leave any line pending.

No Supplier component is copied automatically. Expected commission never becomes a Client charge.

### 12.7 Stop point G — Cruise scenario review available

Review derives, without persisting totals:

- category + Single;
- category + Double;
- category + Triple when supported;
- known Client lines and total;
- known Supplier gross, commission, and net;
- projected profit/margin when inputs are sufficient;
- exact pending inputs;
- current capacity context without a booking or Hold.

One incomplete category does not hide completed categories. One missing commission does not hide gross Supplier or Client totals. Current capacity is time-labeled and is not promised inventory.

## 13. Client choice to rate-category linkage

The current arbitrary `client_rate_category_key` selector must be durably associated with the Client choice option that selects that rate category.

### 13.1 Minimum persistence contract

Add nullable `service_offer_choice_options.client_rate_category_key`:

- normalized, blank-to-null, maximum matching `ServiceOfferPriceComponent::RATE_CATEGORY_LIMIT`;
- immutable after the containing Service Offer version leaves draft under the existing freeze contract;
- unique within one Service Offer version when present;
- same-version price components use the exact key;
- no rate-category table or parallel cabin-category aggregate is added.

A choice option may still have no rate-category key when it has only a fixed option price effect or no price effect.

### 13.2 Completeness rules

- On the ordinary choice-driven path, selecting a choice option that carries `client_rate_category_key` supplies that key as the Service Offer (and Package) evaluation `rate_category` for that selection. Staff do not re-enter the key manually for that path.
- A selected option with a rate-category key evaluates the Service Offer price with that key.
- An unselected option contributes no category-scoped price.
- A category-scoped base price key not reachable from any applicable choice option is incomplete for the ordinary choice-driven path; the advanced/manual preview may still name an explicit key.
- Two options in the same Service Offer version cannot silently share a key.
- Source activation and rate-category selection remain two properties of the same existing choice option. No new Category identity is introduced.

## 14. Supplier-to-Client price-copy provenance

### 14.1 Semantic decision

“Start from Supplier terms” is a copy operation, not a live link.

At copy time:

1. Staff select eligible Supplier cost components.
2. DepartureDesk shows the proposed Client role, calculation shape, selectors, and amount.
3. Staff confirm and may edit the proposed Client values before save.
4. The Client price component becomes independently editable.
5. The exact Supplier component and a copy-time fingerprint are retained as provenance.
6. A later Supplier edit or activated successor never overwrites the Client component.
7. A pure comparison flags unchanged, changed, missing, or unknown provenance.
8. Staff may keep the Client term, recopy into a new draft component, or remove provenance deliberately.

### 14.2 Minimum Smith persistence contract

For the one-to-one compatible copy path, add to `service_offer_price_components`:

- nullable `copied_from_supplier_cost_component_id`;
- nullable `copied_from_supplier_cost_component_fingerprint`;
- nullable `copied_from_supplier_cost_component_at`.

Database and Rails constraints require:

- all three provenance fields present or all absent;
- same Agency and Departure;
- the source component belongs to the Arrangement/version reachable through one selected/bound source path on the same Service Offer version;
- the source calculation shape is supported by the copy adapter;
- provenance mutation only while the Client Service Offer version is draft.

The copied Client component’s own amount, rate, role, quantity basis, selectors, and bases are the copy-time Client snapshot. The source fingerprint identifies later Supplier change. This minimum path does not merge several Supplier components into one provenance chain. Staff can create an independent Client component when transformation is not one-to-one. Multi-source transformation provenance is deferred until separately accepted.

### 14.2.1 Copy-time fingerprint

`copied_from_supplier_cost_component_fingerprint` is a stable **semantic** digest of the Supplier cost component **as copied**. It fingerprints meaning, not row identity.

At minimum it covers:

- client-facing copy role / calculation shape as mapped;
- monetary amount and/or rate fields used by that shape;
- currency;
- ordered base-component contribution fields (and their relative order) when the shape uses bases;
- definition stage (estimate vs contracted, or the stage enum the copy adapter recognizes).

It must **not** include database primary keys, foreign keys, or version ids (component id, definition id, Arrangement version id, or similar) in the digest. Stable source identity for Staff review and “open source” navigation remains on the separate nullable source-component FK / provenance pointer fields—not inside the fingerprint.

The accepting Slice 2D plan names the exact canonical serialization. A later Supplier edit that changes any fingerprint input marks provenance **changed**; an unreachable or deleted source marks **missing**; an unsupported comparison marks **unknown**.

### 14.3 Eligible mappings

| Supplier role/shape | Proposed Client mapping |
| --- | --- |
| `supplier_charge`, compatible unit/fixed rate | Staff chooses `base_price`, `named_surcharge`, or `tax_fee` |
| `supplier_credit`, compatible rate | `named_discount` |
| Expected commission | Never copied as Client revenue |
| Informational allocation | Never copied automatically |
| Minimum/shortfall or unsupported quantity basis | Advanced/manual Client entry; no lossy copy |

The command must not infer Client price merely by adding margin to Supplier cost. Target-price and target-margin workflows remain independent authoring tools.

## 15. Area 4 — Package & Client terms

### 15.1 User question

> What exactly are we selling, what choices do Clients have, and how will Clients be charged?

### 15.2 Package composition

Show:

- included Services;
- optional Services;
- unassigned Services;
- Client choices;
- pricing status;
- Client-term exceptions.

Actions use shipped Package inclusion, adoption, detach, reorder, and ownership commands. Do not persist a new “undecided placement” enum if unowned Service Offer versions already express Not yet assigned. If the final M4D.0 base added stronger placement persistence, the reconciliation gate must name and justify it.

### 15.3 Plain-language pricing choice

Ask:

> How should this Package be priced?

- **One Package price** → shipped bundled Package price.
- **Add up selected Services** → shipped service-sum Package price.
- **Decide later** → no price definition yet.

Do not lead ordinary Staff with `bundled`, `service_sum`, selector tuples, or component bases.

### 15.4 Client term compiler

For each priced Service or Package, show an ordered term table with:

- Client-facing label;
- role;
- calculation basis;
- amount/rate;
- rate category;
- occupancy position when applicable;
- additive/included behavior supported by the shipped evaluator;
- result-line preview;
- optional Supplier-copy provenance state.

Staff may start from:

- blank Client terms;
- selected compatible Supplier terms;
- a target Client total;
- a target profit amount;
- a target margin percentage.

Target workflows propose a draft distribution and require confirmation. They never silently rewrite itemized taxes, fees, or previously entered Client terms.

### 15.5 Taxes and fees

The ordinary Cruise editor must allow distinct Client lines for at least:

- Cruise fare;
- NCCF;
- government taxes/fees/port charges;
- Agency fee;
- named discount or promotion.

The scenario total and per-person/per-booking explanation show each itemized line. A line may be pending independently.

The minimum Smith slice does not need a universal tax engine, tax jurisdiction model, remittance record, or statutory-tax assertion. Labels and calculation behavior are Staff-authored Client terms.

### 15.6 Payment, cancellation, and stated terms

Use shipped M4C records and invariants to author and preview:

- one ordinary Package payment schedule;
- Service-specific exceptions only when genuinely scoped;
- cancellation tiers;
- manual-review conditions;
- eligibility and stated conditions;
- explicit term conflict resolutions.

Do not create Charges, due jobs, actual cancellations, Receipts, Obligations, or Payments.

### 15.7 Travel configurations

The workspace may derive bounded transient scenarios from choices, occupancy selectors, and quantity requirements. It must not add persisted Departure scenarios in the Smith milestone.

Suggested Single/Double/Triple configurations are:

- editable preview inputs;
- derived from supported entered facts, not Resource maximum alone;
- not named Travelers;
- not Supplier capacity promises;
- not saved demand.

Persisted reusable scenarios require a later accepted contract that distinguishes travel configuration from enrollment assumption, participant category, occupancy profile, and booking.

## 16. Area 5 — Review

### 16.1 User question

> What can we confidently prepare for this outcome, and what should I do next?

### 16.2 Outcome selector

Supported request/session outcomes:

- Supplier readiness
- Client proposal preparation
- Pricing review
- Publication readiness (uses shipped [M4D](m4d-publication-and-live-feasibility.md) publication readiness; this workspace does not redesign Publish, Sales enabled, or live feasibility)

The selected outcome filters findings and recommendation ranking. It does not change records.

### 16.3 Required Review sections

1. Group summary
2. Package composition
3. Common scenario totals
4. Client term breakdown
5. Supplier support and current capacity context
6. Supplier deadlines and planning exposure
7. Indicative economics
8. Outcome-specific findings
9. One recommended next action

Review is a compiler and router, not a fifth editor. Every finding deep-links to the exact editing context and supplies a return target.

### 16.4 Existing readiness extension

Extend `EvaluateDepartureBuilderReadiness` and `RecommendDepartureBuilderAction`; do not create a second detector catalog.

Each finding must return:

- stable reason code;
- existing state vocabulary (`incomplete`, `needs_attention`, `blocked`, or `waiting`);
- affected area;
- outcome applicability;
- route target;
- affected Package/Service/Arrangement identity;
- concise explanation of known versus missing facts.

Recommendation ranking remains:

1. correctness/safety blocker relevant to the selected outcome;
2. actionable required dependency;
3. shortest meaningful completion action;
4. waiting items only when no Staff-actionable work remains.

An unrelated publication blocker does not outrank Supplier-cost work during Supplier readiness.

### 16.5 Known and pending arithmetic

Review must render results such as:

> Known Client subtotal $4,510 + taxes pending

or:

> Supplier gross $3,862; expected commission and net pending

It must not display `$4,510` as a final total or suppress it because one input is missing.

### 16.6 Planning cash-gap boundary

When a later sub-slice adds planning cash-gap comparison, it must:

- use explicit booking/enrollment and timing assumptions;
- compare M4 Client schedule projections with M3 Supplier commitments/exposure;
- label the result **Projected under these assumptions**;
- display the assumptions beside the result;
- never call planned Client collections received cash;
- never call an externally handled Supplier deposit paid;
- never assert actual liquidity, bank balance, or payment ability;
- persist no actual cash event.

This feature is not required for the Smith minimum proof.

## 17. Smith Family Cruise acceptance graph

The minimum proof uses accepted Smith/Celebrity facts and clearly labels any illustrative Client prices.

### 17.1 Supplier side

- Departure: Smith Family Cruise/Reunion, November 6–13, 2027.
- Supplier: Celebrity Cruises.
- Arrangement and draft/activated version as required by the sub-slice.
- Cruise Item.
- Celebrity Beyond sailing Occurrence (Smith shape: one sailing Occurrence for this proof; not a universal adapter rule).
- Supplier group number `1119999` persisted only as `SupplierIssuedIdentifier(identifier_type: :group_number)` with **confirmation provenance** (issued through the confirmation / Reservation path that owns that identifier family). Do not invent a parallel group-number column on Arrangement or Service Offer, and do not store `1119999` without confirmation provenance.
- O1 Prime Oceanview Resource.
- O1 cabin-unit Pool with eight blocked cabins from accepted scenario facts.
- O1 Single, Double, and Triple occupancy profiles (created only after Staff confirmation that those profiles are supported).
- Supplier terms:
  - first/second fare $1,624;
  - additional fare $406;
  - NCCF $320;
  - first/second discount $150 credit;
  - additional discount $37.50 credit;
  - taxes/fees/port charges $137;
  - single supplement $1,624;
  - expected commission with explicit bases.
- Accepted initial/final deposit, option, final-payment, rooming-list, and legal-name shapes without calling external handling payment.

### 17.2 Client side

- One Cruise Service Offer, not one per cabin category.
- One cabin-category choice group.
- O1 choice option with durable Client-rate-category key and exact source activation.
- One independent Client price definition.
- Itemized Cruise fare, NCCF, and taxes/fees Client components using explicitly entered or clearly illustrative values.
- Single, Double, and Triple anonymous scenario review.
- One Package inclusion, normally Included, without requiring other Smith components in the minimum proof.

### 17.3 Anti-invention rules

- Supplier cost amounts do not become Client prices unless Staff explicitly copy and confirm them.
- Illustrative Client prices are labeled illustrative in tests and UI fixtures.
- O1 maximum occupancy does not by itself prove every Client scenario price.
- Occupancy profiles are not created without explicit Staff confirmation for supported configurations.
- One sailing Occurrence is the Smith proof shape, not a universal typed-cruise adapter invariant.
- Group number `1119999` is only a `SupplierIssuedIdentifier` with `identifier_type: :group_number` and confirmation provenance.
- Eight blocked cabins do not become 24 traveler positions.
- No cabin assignment, named Traveler, booking, Hold, Allocation, Charge, Receipt, Obligation, or Payment is created.

## 18. Vineyard anti-hardcoding acceptance

The later Vineyard proof must demonstrate that the Smith implementation did not make cabin occupancy the universal scenario API.

Required shapes:

- June 5–7, 2027 Departure;
- separate DMC and motorcoach Suppliers/Arrangements as supported by source facts;
- one 30-traveler-position coach Pool;
- fixed coach cost with explicit enrollment assumption for indicative per-person economics;
- lodging/tasting/lunch Service shapes without inventing unresolved properties or nights;
- separate Standard and Deluxe Dinner Supplier Items;
- one Client-facing Dinner Service with exactly-one choice;
- bundled Package base `P`;
- illustrative optional 100% single-occupancy supplement with no duplicate lodging charge;
- unresolved Deluxe surcharge remains pending rather than zero.

The same Review interface accepts both occupancy-shaped and enrollment-shaped assumptions. The implementation must not require a cabin category to evaluate a Package scenario.

## 19. Command, transaction, and concurrency contract

### 19.1 Section commands

Each named durable stop point uses a dedicated command or a thin orchestration over existing dedicated commands. Responsibilities may not be collapsed into one mega-command.

**Accepted Slice 2A.1 command pairs** (sole authority: [Slice 2A.1](m4d1-slice2a1-cruise-sailing-and-cabin-inventory.md)):

- `CreateCruiseSailingSetup` / `UpdateCruiseSailingSetup`
- `CreateCruiseCabinCategorySetup` / `UpdateCruiseCabinCategorySetup`

Typed composite commands may extract reusable generic `*_already_locked!` helpers from shipped commands. Public M3 commands retain their existing behavior. The typed command owns authorization, canonical locks, idempotency, one transaction, optimistic checks, version bump, and audit at its public boundary. It must not chain public multi-transaction commands for one section save.

**Shipped Slice 2A.2 command set** (historical baseline: [Slice 2A.2](m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md)). **Shipped Slice 2A.2R** retains the same command names with a normalized matrix payload (sole matrix authority: [Slice 2A.2R](m4d1-slice2a2r-cruise-supplier-rate-matrix.md)):

- `CreateCruiseSupplierRateSchedule` / `UpdateCruiseSupplierRateSchedule`
- `SetCruiseSupplierOccupancyPlan`
- `MarkCruiseSupplierRateScheduleForecastReady`
- Read adapters: `CompileCruiseSupplierRatePreview`, `DetectCruiseSupplierRateShape`

**Shipped Slice 2A.2R3** remediates detector reconstruction/validation for those same read/write surfaces (sole detector remediation authority: [Slice 2A.2R3](m4d1-slice2a2r3-cruise-rate-shape-detector-remediation.md)). It does not rename commands.

**Accepted Slice 2B** (sole typed Stop D authority: [Slice 2B](m4d1-slice2b-cruise-deposits-deadlines-and-activation-safe-editing.md)) composes public M3E mutations and Cruise adapter services:

- Public M3E mutations: `CreateSupplierDeadlineDefinition` / `UpdateSupplierDeadlineDefinition` / `RemoveSupplierDeadlineDefinition`; `CreateSupplierDepositRequirementDefinition` / `UpdateSupplierDepositRequirementDefinition` / `RemoveSupplierDepositRequirementDefinition`; `RecordSupplierPlanningMilestone`
- Activation retains shipped `MaterializeSupplierDeadlineDefinitionsAlreadyLocked`, `MaterializeSupplierDepositRequirementDefinitionsAlreadyLocked`, `ReconcileSupplierDeadlineSuccessorAlreadyLocked`, `ReconcileSupplierDepositSuccessorAlreadyLocked`
- Cruise adapter services: `CompileCruiseDepositsAndDeadlinesWorkspace`, `DetectCruiseSupplierDeadlineShape`, `DetectCruiseDepositRequirementShape`, `PreviewCruiseDepositRequirement`, `PreviewCruiseDepositsAndDeadlinesActivation`
- Typed routes under `/departures/:departure_id/arrangements/:arrangement_id/cruise/deposits-and-deadlines` (nested deadlines/deposits + preview POSTs). Generic `/deadlines` and `/deposits` remain Advanced planning.

**Later Cruise stop-point boundaries** (names locked when the implementing slice is Accepted; former proposed `Save…` vocabulary superseded for A–C):

- `ConnectCruiseServiceOffer` (Stop E / Slice 2C)
- Client term schedule and Supplier-to-Client copy (Stops F–G / Slice 2D)

The accepted sub-slice plan must name exact commands, inputs, outputs, and whether each extracts already-locked helpers or composes shipped public commands.

### 19.2 Lock order

Preserve the shipped canonical order whenever M3 and M4 records are touched:

1. Agency
2. actor reloaded/rechecked through the locked Agency
3. affected Suppliers in UUID order
4. Departure
5. Arrangement/version and selected definitions
6. Package and/or Service Offer/version in the accepted M4 order

Nested commands do not reacquire earlier locks.

### 19.3 Idempotency

Every composite creation command uses `AgencyCommandIdempotencyKey`:

- same key and payload returns the same section result;
- same key and different payload conflicts;
- retries create no duplicate Item, Occurrence, Resource, Pool, Service, choice, binding, price line, or audit success.

Edits use expected optimistic lock versions where the parent contract requires them.

### 19.4 Failure and resume

- Failure within a section rolls back that section.
- Previously saved sections remain durable.
- A failed rate save does not delete a saved cabin category.
- A failed Client-term copy does not modify Supplier costs.
- A failed connection does not create a duplicate Service Offer or leave unreachable `choice_gated` bindings.
- Reopening the workspace resolves the next incomplete section from durable records rather than session flags.

### 19.5 Audit

Reuse existing Arrangement, Service Offer, and Package audit subjects/actions where semantically correct. Add only bounded actions actually emitted by new composite commands. Audit details may identify created/updated IDs and source/provenance IDs; they do not embed full cost graphs, Client term graphs, or scenario results.

## 20. Permissions and information boundaries

- Staff/Administrator actions use the existing permission catalog, not role checks.
- Viewer access to unpublished Service, Package, Supplier-cost, and workspace content does not expand.
- Supplier cost, commission, exposure, and indicative margin remain restricted as established by M3/M4 authority.
- Cross-Agency and cross-Departure identifiers return not found.
- Request `agency_id`, Package selector, Supplier selector, and return URL never establish authority.
- Typed adapters must use session-derived Agency and scoped records.

## 21. Delivery plan

This document is the **M4D.1** milestone contract. Each implementation sub-slice (1, 2A–2D, 3, 4, 5) requires an accepted exact plan (or explicit use of the named section below as that authority) and a pinned green base.

### Slice 1 — Workspace foundation

**Shipped 2026-09-22.**

Shipped:

- five-area shell and routes;
- persistent header;
- derived area summaries;
- post-save starting-point routing;
- usable Service Map for outline work;
- outcome-filtered Overview recommendation;
- Review compiler using current facts;
- explicit links/stubs into current Supplier planning and advanced price/Package editors;
- return-to-context behavior;
- `/departures/:id/builder` compatibility redirect.

Do not claim typed Supplier entry or Client-term compilation has shipped.

**Exit:** Staff can safely outline Services and navigate all existing work without losing capability. The new shell does not strand Supplier work or merely append old panels beneath new navigation.

### Slice 2 — Smith Cruise proof theme

#### Slice 2A.1 — Cruise sailing and cabin inventory

**Shipped 2026-09-22.** Sole shipped authority: [M4D.1 Slice 2A.1](m4d1-slice2a1-cruise-sailing-and-cabin-inventory.md).

Shipped Stop points A–B:

- typed Cruise sailing adapter (`CreateCruiseSailingSetup` / `UpdateCruiseSailingSetup`);
- cabin Resource/Pool adapter (`CreateCruiseCabinCategorySetup` / `UpdateCruiseCabinCategorySetup`);
- one-category-at-a-time save;
- generic Resource-definition fields `supplier_code` and `maximum_occupancy`;
- Open Cruise setup compatibility predicate and advanced fallback.

**Exit:** O1 sailing and cabin inventory can be entered and resumed without exposing graph vocabulary or creating Client records. Rates remain unshipped.

#### Slice 2A.2 — Supplier rates and occupancy totals

**Shipped 2026-09-22.** Historical fixed-form baseline: [M4D.1 Slice 2A.2](m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md).

Shipped Stop point C (fixed form):

- typed Cruise Supplier rate schedule (`CreateCruiseSupplierRateSchedule` / `UpdateCruiseSupplierRateSchedule`);
- dollar or percentage expected commission with constrained shapes;
- occupancy plan (`SetCruiseSupplierOccupancyPlan`) with ephemeral illustrations vs confirmed profiles;
- forecast readiness and preview compiler;
- category-scoped rate-shape detector and advanced-editor escape.

**Exit:** Accepted Supplier terms for one cabin category can be entered and resumed without exposing graph vocabulary or creating Client records.

#### Slice 2A.2R — Cruise Supplier Rate Matrix remediation

**Shipped 2026-09-22.** Sole shipped authority: [M4D.1 Slice 2A.2R](m4d1-slice2a2r-cruise-supplier-rate-matrix.md). Implementation base [`bf41e0b`](https://github.com/tswarren/DepartureDesk/commit/bf41e0b); delivered as **2A.2R-A** then **2A.2R-B**.

Remediates Stop point C into:

- rate-profile × component-row matrix over generic M3C;
- Every Traveler / Every Cabin families; Adult/Child overlap resolution;
- shared vs profile-specific percentage commission; dollar commission per profile;
- custom rows; legacy projection and confirmed first-edit conversion;
- generic M3C zero-amount readiness amendment.

**Exit:** Smith matrix and family-rate fixtures prove flexible cruise rates; legacy schedules reopen safely.

#### Slice 2A.2R2 — Cruise Supplier Rate Matrix Interaction

**Shipped 2026-09-22.** Sole shipped authority: [M4D.1 Slice 2A.2R2](m4d1-slice2a2r2-cruise-rate-matrix-interaction.md). Ship commit [`3f97e2e`](https://github.com/tswarren/DepartureDesk/commit/3f97e2e) (PR #141). Implementation base was [`4a3bc3c`](https://github.com/tswarren/DepartureDesk/commit/4a3bc3c).

Remediates Staff chrome so the matrix is an interactive builder:

- add/edit/reorder/remove rate-profile columns and custom rows without first saving;
- method-gated commission with per-populated-cell treatment;
- illustrations from the current unsaved matrix;
- browser acceptance that constructs the family fixture through visible controls.

**Exit:** Six system scenarios green; family-rate fixture built only through page controls.

#### Slice 2B-R — M3E Cruise deposit-semantics amendment

**Shipped 2026-09-22.** Sole shipped authority: [M4D.1 Slice 2B-R](m4d1-slice2br-cruise-deposit-semantics-amendment.md). Ship commit / merge tip [`5a391d1`](https://github.com/tswarren/DepartureDesk/commit/5a391d1) (PR #143). Accept package base [`bfe8431`](https://github.com/tswarren/DepartureDesk/commit/bfe8431).

Amends ADR 0013 / M3E register for Path B Celebrity economics (`$50 × initially blocked cabins`, `$500 × retained cabins` source-aware cumulative), deposit `capacity_pool_units`, and explicit cumulative contributors. No typed Cruise UI.

#### Slice 2A.2R3 — Cruise rate-shape detector remediation

**Shipped 2026-09-23.** Sole shipped authority: [M4D.1 Slice 2A.2R3](m4d1-slice2a2r3-cruise-rate-shape-detector-remediation.md). Ship commit / merge tip [`e5ded27`](https://github.com/tswarren/DepartureDesk/commit/e5ded27) (PR #145). Accept package base [`5a391d1`](https://github.com/tswarren/DepartureDesk/commit/5a391d1).

Remediates Stop point C detector reopen:

- authoritative `component_id → cell_key` mapping for commission bases;
- shared vs profile-specific percentage topology with fail-closed Advanced for ambiguous graphs;
- non-destructive detect; reopen → unchanged save → reopen preserves topology.

**Exit:** Seven blocking regressions green; documentation marks Shipped.

#### Slice 2B — Deposits, deadlines, and activation-safe editing

**Accepted.** Sole typed Stop D authority: [M4D.1 Slice 2B](m4d1-slice2b-cruise-deposits-deadlines-and-activation-safe-editing.md). Accept package base [`b66d88b`](https://github.com/tswarren/DepartureDesk/commit/b66d88b). Not fully shipped. **2B-A (typed Supplier Deadlines) and 2B-B (typed Deposit Requirements) delivered**; 2B-C remains open. Domain Path B economics are shipped under Slice 2B-R; rate-shape detector under Slice 2A.2R3.

Ship Stop point D:

- Cruise deposit/deadline adapter over public M3E commands;
- draft versus activated/successor labeling;
- M3D.7-safe successor editing;
- exact M3E materialization boundaries;
- advisory write-free activation preview.

**Exit:** accepted Celebrity deadline/deposit shapes are entered without payment language, activated mutation, or one giant Arrangement save.

#### Slice 2C — Connect Cruise, categories, and choices

Ship Stop point E plus the durable choice-rate key:

- connect existing/new/decide-later flow;
- one Cruise Service with multiple category bindings;
- choice group/options/source activations;
- option-to-rate-category persistence and validation;
- no duplicate Service Offer on connect.

**Exit:** O1 is a Client choice inside one Cruise Service and is traceable to exact Supplier support.

#### Slice 2D — Client term compiler and scenario Review

Ship Stop points F–G:

- independent Cruise Client term compiler;
- separately itemized fare/NCCF/taxes-and-fees lines;
- minimum one-to-one Supplier-copy provenance;
- Single/Double/Triple review;
- known/pending arithmetic;
- Supplier-change provenance findings through the existing readiness model.

**Exit:** Staff can explain both Supplier cost and Client revenue for O1 without silently equating them, and Review gives one actionable next step.

### Slice 3 — Typed adapter generalization

Ship:

- Hotel adapter;
- Transportation adapter;
- Activity/Meal/Excursion adapter;
- mixed-DMC Item table;
- common connect-each-Item bridge;
- shared adapter support library only where at least two adapters prove the abstraction.

**Exit:** no Cruise-specific persistence or evaluator is required to set up the other service families.

### Slice 4 — Vineyard proof

Ship and prove:

- client-first entry;
- DMC plus motorcoach arrangements;
- fixed shared coach cost and explicit enrollment assumption;
- bundled Package and illustrative single supplement;
- exactly-one Dinner choice over separate Supplier Items;
- pending Deluxe surcharge;
- general Review scenario inputs.

### Slice 5 — Broader Client terms and Review refinement

Candidate work, each requiring exact acceptance:

- target-price and target-margin proposal workflows;
- richer Client presentation modes;
- improved payment/cancellation authoring;
- assumption-bound planning cash-gap comparison;
- internal proposal presentation;
- broader scenario ergonomics without persisted Departure scenarios.

### Rollout and retirement of old surfaces

- Typed forms and advanced graph editors must call the same authoritative commands and validations; they are not allowed to become divergent write paths.
- Until a typed adapter reaches its acceptance exit, the applicable existing Arrangement, cost, deadline, binding, price, and Package editor remains reachable as **Advanced setup** or **Current Supplier planning**.
- Do not render both the typed form and full advanced editor expanded on the same ordinary page.
- Record use of the advanced escape during Smith/Vineyard acceptance. Repeated escapes for common contract shapes are typed-adapter defects, not evidence that ordinary Staff should learn the graph editor.
- Retire or demote an old ordinary surface only after parity, recovery, permissions, concurrency, and accessibility proof is green. Historical record inspection remains available.

### Later, separately accepted

- source-document storage and retention;
- proposal sharing, version advancement, and notifications;
- publication and Sales-enabled behavior not already shipped;
- persisted reusable Departure scenarios;
- M5 booking/Traveler/Hold/Allocation work;
- ledger and actual cash records.

## 22. Falsification and usability proof

The workspace is not successful merely because all records can be created.

For the Smith O1 task, compare the successor flow with the current graph-facing baseline and record:

- required user-entered facts;
- repeated facts already known elsewhere;
- visible technical domain concepts;
- context switches;
- full-page navigations;
- durable stop/resume points;
- steps to correct one invalid cabin rate;
- steps to trace a Client tax/fee line back to its Supplier source;
- duplicate or orphan records after retry/concurrency tests.

The successor must demonstrate:

- no repeated Supplier, sailing, category, date, or currency entry where the bound graph already knows it;
- no need for Staff to understand Item/Occurrence/Resource/Pool topology for the common path;
- no second Service Offer when connecting an outlined Cruise;
- no loss of known totals because one term is pending;
- fewer context switches than the current Arrangement + Offer + price-editor path;
- successful resume after every named stop point.

If Smith is not demonstrably calmer under this proof, do not generalize the adapters. Record the finding and revise the orchestration or screen contract first.

## 23. System and integration proof

Every applicable sub-slice proves:

- same-Agency/same-Departure integrity in Rails and PostgreSQL;
- wrong-version and cross-Arrangement relationships rejected;
- direct mutation of activated definitions rejected;
- exact successor-copy behavior;
- same-key idempotent replay and different-payload conflict;
- concurrency creates no duplicate category, Pool, choice, binding, or price component;
- failed sections leave prior stop points intact;
- unpublished permissions and Viewer denial;
- keyboard-complete form and reorder behavior;
- `#form-error-summary`, linked errors, preserved branch and values;
- 375, 768, 1280, and 1400 pixel layouts;
- bounded query counts for Smith and Vineyard workspaces;
- no persisted preview total, readiness status, recommendation, margin, or scenario;
- full Docker/CI gate at each PR tip.

## 24. Explicit non-goals

This contract does not authorize:

- a second outline/component model;
- service-type STI or Cruise/Hotel/Coach domain subclasses;
- one mega-command for the whole departure or Arrangement;
- automatic Supplier-document extraction;
- a rate-category directory parallel to choice options;
- live synchronization from Supplier cost to Client price;
- automatic markup or margin application without Staff confirmation;
- persisted area completion or workflow state;
- persisted scenario totals or demand;
- named Travelers or bookings;
- Holds, Allocations, Charges, Receipts, Obligations, Payments, or actual cash position;
- publication, proposal distribution, email/SMS notifications, or Client authentication unless a separate accepted slice names them;
- tax-jurisdiction, tax-remittance, or statutory-compliance assertions;
- invented Vineyard rates, properties, nights, dinner surcharge, or Celebrity Client fares.

## 25. Exit

The **M4D.1** Departure Composition Workspace milestone is complete only when:

1. the five areas are the primary Staff composition experience and remain freely navigable;
2. the Service Map uses existing Service Offers and no second outline aggregate exists;
3. Staff may start Supplier-first or Client-first and converge on the same durable graph;
4. the Smith Cruise can be saved and resumed at every named stop point;
5. typed Cruise setup writes generic M3 records and obeys activation/successor immutability;
6. one Cruise Service contains its cabin-category choices and exact Supplier bindings;
7. Client fare, NCCF, and taxes/fees can be compiled as distinct Client terms;
8. Supplier-copy provenance is snapshot-based, reviewable, and never a live sync;
9. Single/Double/Triple Review shows known values and exact pending facts;
10. readiness, area status, and recommendations are derived through one outcome-aware model;
11. Vineyard proves that shared fixed costs, bundled Package pricing, and dinner choices do not require a cabin-shaped API;
12. advanced existing editors remain available until typed parity is proven;
13. documents, proposal sharing, actual bookings, and money ledgers remain outside the exit;
14. the falsification and system proof is green and demonstrates materially lower Staff friction than the current graph-facing baseline.
