# M4D.0 — Streamlined group departure builder

**Status:** Draft for review, 2026-09-21. **Discovery backlog only**—not implementation authority. Accepted implementation authority is [M4D.0 narrow builder](../m4d0-narrow-group-departure-builder.md). Product decisions here that are not also in that Accepted plan remain deferred until a later accepted slice names them.

**Pinned planning note:** Shipped M4D merge [`88db505`](https://github.com/tswarren/DepartureDesk/commit/88db505fa81ab740ad134fea28998841b401d7e9). Implementation of the first builder uses the narrow draft’s pin and acceptance gate, not this document.

**Placement:** After shipped [M4D](../m4d-publication-and-live-feasibility.md) and before draft [M4E](DepartureDesk-M4E-acceptance-and-hardening-draft.md), as discovery context for the narrow plan. Do not treat this file as permission to implement document upload, Departure sales-action policy, proposal sharing, or other deferred items ahead of the narrow contract.

## Goal

Let an average travel agent preserve a group-departure concept quickly, then develop it through one itinerary-centered workspace without learning the underlying Supplier Arrangement, Service Offer, Package, source-binding, price-component, or publication topology up front.

The first session succeeds when the concept is safely recorded. It does **not** require a sell-ready Package, contracted Supplier support, exact dates, complete prices, or publication.

The ordinary flow is:

1. Save the Departure identity and responsible Office.
2. Add Client-recognizable components one at a time, optionally while viewing a Supplier document.
3. At the first component, ask in plain language whether to create one primary Package.
4. Record each component's name, optional type, rough Client timing, and Package placement when applicable.
5. Ask which outcome Staff want to prepare next: Client proposal, Supplier support, or pricing.
6. Show one recommended next action plus the remaining checklist, while preserving direct access to every workspace.

This is an orchestration and usability layer over the shipped M2–M4 records. It must not create a second commercial model or a temporary “outline” aggregate that later needs conversion.

## Product decisions fixed by discovery

### Initial capture

- Agents commonly begin with a Supplier proposal or contract, rough itinerary and dates, and a Client-facing package idea.
- The first-session outcome is **the departure concept is safely recorded**.
- An early save is allowed before any components exist. Afterward, **Add your first component** is guidance, not an error.
- The ordinary save minimum is a name and responsible Office. Timing may be completely unknown. Existing Agency defaults continue to supply time zone and operating currency when available.
- Responsibility is organizational. The creator's current/default Office is proposed and may be changed. An individual Staff member is optional attribution, not the required owner of the work queue.
- Rough timing may be unknown, a month/season, an exact-but-tentative range, or descriptive candidate windows. Exact operational dates remain `starts_on`/`ends_on`; free-form target timing does not pretend to be operational authority.

### Source documents

- “Start from a Supplier document” means a split-view manual-entry workspace. M4D.0 performs no OCR, extraction, classification, or automatic record creation.
- An uploaded document remains attached to the Departure as source material after save.
- An attachment is not automatically a contract, Supplier Arrangement, cost definition, or verified fact. Staff later link or classify it deliberately.

### Components and Package assembly

- A component is a distinct itinerary event or anything a Client sees, chooses, or pays for distinctly.
- Broad headings such as “Meals” or “Wine experiences” are presentation groupings, not automatically components.
- One Cruise component owns cabin-category choices; cabin categories are not separate itinerary components.
- Component creation initially requires only a name and, when already assigned to a Package, included/optional placement. Dates, fulfillment, Supplier, capacity, cost, and Client price remain optional draft work.
- Component timing is optional. Staff may arrange itinerary order and use approximate Client-facing timing.
- Ask whether to create the primary Package when the first component is added, not on the initial Departure form.
- If Staff decline, save the component as **Not yet assigned to a Package**. Do not infer that it is independently sellable.
- Offer an optional setup profile while adding a component. First-release profiles are Generic; Cruise/cabin; Hotel/room; Transportation/segment; and Activity/meal/excursion.
- Setup profiles are editors over shared M3/M4 primitives, not parallel domain aggregates or subclasses.

### Work guidance

- After the rough outline is saved, ask which outcome Staff want to prepare next:
  - Prepare a Client-facing proposal.
  - Secure Supplier support.
  - Build and review pricing.
- One outcome is the active collaborative focus at a time. It changes the recommended next action, not record lifecycle or access to other work.
- Readiness is derived by independent tracks. Do not persist an overall status or percentage.
- Each component and the Departure workspace show one recommended next action plus a visible checklist. Distinguish incomplete, needs attention, blocked, and waiting on Supplier.

### Supplier support

- Staff may switch freely between component-first and Supplier-first views. Both edit the same Service Offer bindings and Supplier Arrangement records.
- Support shapes include required sources, alternative paths, and choice-specific paths.
- “Secure Supplier support” uses a Staff-selected Departure target stage with explicit component overrides. The target guides work; it does not rewrite factual Supplier stages.
- Agency-fulfilled, externally fulfilled, and decide-later components are not forced into a Supplier-contract stage.

### Pricing

- The first pricing view is Client package totals for common traveler scenarios.
- Scenarios derive from Package choices and supported occupancy rules. Preview calculations are pure and persist no totals, demand, capacity, Charges, or accounting events.
- The initial summary shows the default Package plus one meaningful variation at a time. Staff may expand all valid combinations and pin useful scenarios.
- Show pending figures whenever enough facts exist. A partial result shows known subtotal and exact missing inputs; it never labels an incomplete subtotal as a total.
- Cruise cabin categories show supported single/double/triple/etc. occupancy totals with Supplier forecast, expected commission, expected cost after commission, Client price when known, and indicative margin when known.
- Support both price-first/resulting-margin and margin-target/suggested-price workflows. Applying a suggested price is explicit.
- Indicative margin is Client revenue plus expected commission minus forecast Supplier cost. It is planning economics, not actual net profit. Shared fixed costs need an explicit enrollment assumption or remain unknown.

### Client proposal preparation

- Internal preview is continuously available.
- A proposal is share-ready only when the Client itinerary and included/optional placement are coherent; all displayed prices and choice adjustments are known; applicable Client deposit/payment/cancellation terms are resolved or explicitly state that booking is not accepted; and every promised component has a known fulfillment path. Approximate timing and on-request support may be shown when labeled.
- Suggest a valid-through date from the earliest relevant Supplier deadline and explain the source. Staff confirm or change it.
- Actual Client proposal links, immutable presentation snapshots, change notices, recipient notifications, and sending are a later separately accepted slice because current ADR 0014 explicitly excludes Communication and document production. The later contract must preserve these accepted decisions:
  - A stable link opens the latest deliberately shared proposal version.
  - Draft edits never become visible automatically.
  - After a proposal-ready change, ask Staff whether to advance the shared version; suppress repeated prompts for the same editing session after “keep current.”
  - The Client sees a visible change notice and can inspect prior versions.
  - When advancing, ask Staff whether to notify recipients.

### Publication and later sales actions

- Publication review shows the Client-facing scenario first, then hard blockers, required acknowledgments, current advisory availability, and informational unknowns. Staff-only economics remain separate.
- Publication remains one atomic action for a Package and its Package-owned unpublished Service Offer versions.
- Do not enable sales silently. Every publication asks Staff to confirm the post-publication sales state.
- Replace the one-dimensional “Sales enabled” interaction with a Departure-owned sales policy containing explicit permitted actions: inquiries, booking requests, temporary holds, and deposit-backed confirmation. Exact published offers retain their own pause/retire lifecycle and computed feasibility; both the Departure policy and the selected offer must permit the requested action.
- Direct confirmation is allowed only when terms and eligibility pass, every required selection has validated availability, required capacity is secured transactionally, and the required deposit succeeds. It then confirms automatically.
- If any required selection is on request or lacks validated availability, submit a booking request without collecting payment. The request creates no implied reservation.
- Inquiries, booking requests, Holds, payment authorization/capture, Client Trips, Allocations, Charges, and confirmation remain M5+ records. M4D.0 and M4D may define and display policy but create none of them.
- Client/Supplier cash-gap analysis is cumulative by due date. Agency defaults determine materiality, a Departure may adjust them with reason/actor/time, and only material gaps require a version-bound publication acknowledgment. Consequential changes invalidate that acknowledgment.

## Required authority amendments before code

M4D.0a is documentation-only. It must reconcile these conflicts explicitly; none may be smuggled into a migration or controller.

| Existing contract | Required amendment |
| --- | --- |
| M2A activation requires both `responsible_office_id` and `responsible_agency_user_id`. | Organizational responsibility is the required field. Keep `responsible_agency_user_id` only as optional lead/attribution unless a later accepted Team model replaces Office. Amend Rails validation, PostgreSQL activation completeness, search labels, and UI together. |
| Draft Departure may omit its name and Office. | The new concept-creation command requires both while preserving legacy/returned draft flexibility. Do not add global `NOT NULL` constraints merely to implement this UX. Activation still requires the responsible Office under its amended completeness rule. |
| M2 has exact paired operational dates only. | Add optional descriptive target timing for drafts. It is never substituted for `starts_on`/`ends_on`, activation eligibility, sales windows, or departed scheduling. Do not add structured candidate-window tables without observed need. |
| M4A requires one fulfillment basis when creating a Service Offer definition. | Add explicit draft-only `undecided` fulfillment. Publication still requires a non-undecided basis and applicable bindings. Prove Rails and PostgreSQL reject undecided published definitions. |
| M4C treats null `owning_package_version_id` as independent/reusable. | Add explicit draft commercial scope/assignment intent so null ownership may mean **unassigned** without meaning independently sellable. Publication rejects undecided scope. Package ownership/inclusion constraints remain atomic. |
| M4 lacks a first-class Client schedule. | Add a version-owned Client schedule distinct from M3 Supplier Occurrence dates. M3 dates may suggest values but never silently control the Client promise. |
| M4.0 starts from Supplier planning. | Add outline-first creation as an equally ordinary path. Both paths produce the same Service Offer versions and later bindings. |
| ADR 0014/M4D use a single per-version Sales enabled flag and M4D defaults it enabled. | Publication must ask every time. Add one Departure-owned sales policy with independent inquiry, booking-request, temporary-hold, and deposit-confirmation permissions. Preserve offer-level pause/retire plus computed `Selectable now`/`On request`/`Unavailable`. |
| ADR 0014 excludes Communication/document production. | Keep proposal distribution out of M4D.0 unless ADR 0014 and the parent scope are explicitly amended. Internal preview/readiness is allowed; sharing/notification needs its own accepted slice and security contract. |
| Active Storage was removed from the rebuilt baseline. | Accept a private source-document storage contract before reintroducing it. Define allowed types/size, authorization, tenant ownership, retention, download headers, malware-handling boundary, and production storage configuration. |
| No Team aggregate exists; workforce-role taxonomy is deferred. | Use the existing responsible Office as the first-release organizational queue. Do not add Team under this plan. |

Update at least: M2A, M4 parent, M4.0, M4A, M4C, ADR 0014, M4D draft, M4E draft, terminology, interface contract, architecture/current state, roadmap, AGENTS, and the documentation index. Accepted historical text may use dated amendment sections rather than pretending the shipped contract never existed.

## Domain and persistence contract

Final table and column names belong to M4D.0a schema review. The accepted design must preserve these meanings.

### Departure capture

- Existing `Departure` remains the root.
- Require a normalized name and responsible Office on the streamlined create command. Preserve the existing database ability for legacy or deliberately returned draft rows to be incomplete; publication and activation gates remain authoritative.
- Default responsible Office from current active Office, then AgencyUser default Office; keep it visible and changeable. Fail clearly if the Agency has no active Office rather than fabricating one.
- Do not require a responsible AgencyUser for initial save or activation after the M2A amendment. If retained, label it **Lead Staff member (optional)**.
- Add an optional bounded `target_timing_text` (for example “Spring 2028” or “Considering June 5–7 or June 12–14”). Exact paired dates remain in the existing columns.
- Store one collaborative preparation preference per Departure: active focus plus Supplier-support default target. This is guidance, not lifecycle state.
- Component target overrides belong to exact stable Service Offer identities and remain planning preferences, not Supplier facts.

### Departure sales policy

- Add one mutable, audited sales policy per Departure. It owns independent boolean permissions for inquiry, booking request, temporary hold, and deposit-backed confirmation.
- A publication review always displays all four actions and requires explicit Staff confirmation, even when retaining the current policy. Joint publication and a policy change occur in one transaction; failed publication leaves the prior policy untouched.
- Policy changes after publication are separate audited operational commands. Disclose every current published root affected by the change.
- Offer-level pause/retire and live feasibility remain authoritative. A Departure permission cannot make a paused, retired, ineligible, unavailable, or on-request offer immediately confirmable.
- Before M5, the policy is configuration and handoff authority only. M4 creates no inquiry, booking request, Hold, payment, or confirmation record.

### Source material

- Introduce tenant-owned `DepartureSourceDocument` metadata linked to one Departure and one private blob/attachment.
- Record uploader, original safe display name, content type, size, checksum, upload time, optional note, and lifecycle/retention state. Do not store file bytes in the application tables.
- Load and download only through session-derived Agency and `manage_departures`; Viewer access is deferred unless explicitly accepted.
- Use private authenticated delivery, `Content-Disposition: attachment` for unsafe inline types, bounded size/type allowlists, and no public permanent blob URLs.
- Deleting or superseding source material is explicit and audited. Ordinary Departure deletion is not introduced.

### Durable component outline

- A rough component is the existing stable `ServiceOffer` plus version 1 draft; there is no temporary outline table and no later conversion command.
- Add version-owned setup profile: `generic`, `cruise`, `hotel`, `transportation`, or `activity`. It drives forms only.
- Add draft commercial scope/assignment intent: at minimum `undecided`, `package_only`, and `standalone_or_reusable`. Package-only continues to require the M4C owner/inclusion pair. An unassigned component is `undecided`, not standalone.
- Add `undecided` as a draft-only fulfillment basis. Existing bases retain their shipped meanings.
- Add a Departure-level planning position for all components. Package inclusion position remains the published Package order. When first assigning components to a Package, propose the planning order and require a reviewed atomic reorder if conflicts exist.
- Add one version-owned Client schedule per component, optional in draft. Support unscheduled; relative day; relative day plus part of day; date-known/time-TBA; exact local time; and spanning range. Store structured values and a bounded Client note; do not parse display prose back into authority.
- Setup profile, schedule, commercial scope, Package placement, and fulfillment are independent. Changing a setup profile after profile-specific definitions exist requires a consequence preview or is blocked until those definitions are removed; never silently discard choices, prices, or bindings.

### Readiness and recommended action

- Implement pure evaluators for Departure and component readiness. Inputs are current versioned records, Supplier facts, and selected planning preferences.
- Tracks: itinerary, Package assignment, fulfillment, Supplier support, availability, Supplier economics, Client pricing, choices, Client terms, proposal readiness, and publication readiness.
- Persist no overall percent, traffic-light status, finding projection, or duplicated checklist rows by default.
- One deterministic prioritizer chooses the recommended action within the selected focus. Hard blockers outrank incomplete tasks; “waiting on Supplier” does not monopolize the recommendation when another actionable task exists.
- Every recommendation returns a stable reason code and route target so tests verify behavior without asserting presentation prose.

### Pricing scenarios

- Add a pure scenario-derivation service over exact Package/Service Offer draft versions.
- Derive only structurally valid combinations and explicitly supported occupancy positions. Never infer single/triple support only from a maximum occupancy number.
- The initial set contains the default combination plus isolated meaningful variations. The expanded explorer may enumerate all valid combinations within a bounded limit; report truncation rather than silently omitting combinations.
- Scenario pins are presentation preferences linked to the exact draft/published version. They do not snapshot price, capacity, or Supplier cost.
- Reuse the shipped M4B/M4C evaluators for every total and explanation. Do not create a second calculator for cards or specialized editors.

### Specialized setup profiles

- **Activity/meal/excursion:** one recognizable event; optional included/add-on placement; simple choice groups; per-person/service-instance patterns; exact or approximate schedule.
- **Transportation:** one Client-recognizable transfer/journey component; segment and seat/resource setup presented as a reviewed batch over M3 Items/Occurrences/Resources and M4 choices/bindings. A Client-distinct segment may remain its own component.
- **Hotel:** one lodging component with room-category choices, supported occupancy scenarios, per-room/per-person/per-night patterns, extra-night handling, and Resource-specific bindings.
- **Cruise:** one sailing component with cabin-category choices, Resource/Pool-specific bindings, supported occupancy scenarios, and batch category/rate entry. Cabin categories remain options inside the Cruise component.
- Each profile must expose the underlying records and preserve a full-page generic fallback. No profile may weaken same-Agency/Departure constraints, lock ordering, draft freeze rules, idempotency, or publication checks.

## Staff experience contract

### Create Departure

The initial page contains only:

- Name.
- Rough timing: unknown, descriptive target, or exact paired dates.
- Responsible Office, preselected when possible.
- Optional source-document upload.
- Advanced disclosure for description, time zone, currency, and optional lead Staff member.

Primary action: **Save and add components**. Secondary action: **Save for later**. Both create the same Departure; the first opens the component composer and the second opens the workspace with the same recommendation.

### Add component

Open only one composer. Default fields:

- Component name.
- Optional setup profile.
- Optional timing/order.
- Included/optional placement only when a primary Package already exists.

On the first component, ask whether most travelers will buy the items together as one main Package. Recommend yes, but create nothing until Staff confirms. If yes, one idempotent command creates the Package draft, component draft, ownership/inclusion, and placement. If no, create the unassigned component without fulfillment or standalone-sale intent.

After save, keep the composer available for **Add another component** without forcing specialized details.

### Departure workspace

- Header: Departure identity, rough/exact timing, responsible Office, and lifecycle.
- Recommended-next-action panel based on active focus.
- Focus chooser: Client proposal, Supplier support, or pricing.
- Itinerary-ordered component cards showing Client timing, Package placement, setup profile, and compact readiness tracks.
- Source-material panel with split-view entry action.
- Package summary and common-scenario totals when applicable.
- Supplier view and component view are switchable presentations over the same facts.
- Technical source IDs, fingerprints, and calculation lines remain in disclosures.

Do not turn this into a modal-only wizard. Every consequential editor retains a routable full-page fallback, server validation, `#form-error-summary`, optimistic lock, idempotency where applicable, and recoverable stale/conflict behavior.

## Slice and PR sequence

Each code slice starts only after its authority is accepted. Keep migrations and their owning commands in the same accepted slice.

### M4D.0a — Contract reconciliation and schema design

- Accept this plan and dated amendments listed above.
- Pin the real green base and record required CI.
- Name exact tables, columns, enums, check constraints, composite FKs, lock order, audit actions, and direct-SQL protections.
- Add the small mixed acceptance fixture narrative and mark every fact confirmed, illustrative, or intentionally pending.

**Exit:** no contradiction remains among M2A, M4A/C, ADR 0014, M4D, and this builder contract.

### M4D.0b — Safe Departure capture and organizational responsibility

- Ship the compact create flow, name/Office rules, target timing, defaults, audit changes, and responsibility amendment.
- Preserve exact-date activation and departure lifecycle behavior.
- Prove zero-Office, inactive/default Office, cross-Agency Office, stale form, early save, exact dates, descriptive timing, and existing lifecycle regressions.

**Exit:** Staff can safely save a named concept with no components and receive the correct next action.

### M4D.0c — Private Supplier source material

- Reintroduce the accepted private attachment subsystem and `DepartureSourceDocument` metadata.
- Ship upload/list/view/download/retire and the split-view manual-entry shell.
- Prove tenant isolation, permissions, content disposition, size/type rejection, missing blob recovery, retention behavior, and no extraction/record creation.

**Exit:** Staff can keep the source document with the Departure and transcribe beside it safely.

### M4D.0d — Durable outline, Package prompt, and Client schedule

- Ship `CreateServiceOfferOutline`, draft-only undecided fulfillment, explicit assignment intent, optional setup profile, planning order, and version-owned Client schedule.
- Ship atomic first-Package-plus-first-component creation and the decline/unassigned path.
- Add assignment/adopt commands that preserve M4C ownership and inclusion constraints.
- Prove direct SQL rejects published undecided fulfillment/scope, cross-Departure links, invalid Package ownership, and schedule shapes. Prove concurrency/idempotency for first Package creation and component reorder.

**Exit:** the full rough itinerary can be captured without Supplier or price decisions and without later conversion to a different aggregate.

### M4D.0e — Outcome focus, readiness, and dual Supplier views

- Ship collaborative focus/target preferences, component overrides, derived readiness evaluators, deterministic recommended action, component cards, and component/Supplier view switching.
- Reuse existing M3 and M4 routes/commands; add no duplicate Supplier or offer rows.
- Prove actionable work outranks waiting states, focus switching changes guidance only, target overrides do not rewrite factual stage, Viewer boundaries remain unchanged, and query growth is bounded.

**Exit:** after safe capture, Staff can choose an outcome and see one useful next action plus the complete checklist.

### M4D.0f — Package-first pricing workbench

- Ship derived common scenarios, default-plus-isolated-variation summary, bounded full explorer, scenario pins, shared pending-figure presenters, and line explanations.
- Add explicit margin-target suggestions without auto-applying them.
- Prove shared evaluator parity, rounding, unknown values, shared fixed-cost enrollment, choice selection, no persisted totals, and no capacity/accounting writes.

**Exit:** common Client totals and pending economics appear continuously from the facts already known.

### M4D.0g — Specialized setup profiles

Deliver as focused PRs in dependency order:

1. Activity/meal/excursion and Transportation.
2. Hotel/room categories and occupancy.
3. Cruise/cabin categories and occupancy batch entry.

Every PR proves generic fallback and exact underlying M3/M4 records. The Cruise PR must use one Cruise component and cabin-category choices, not component-per-cabin.

**Exit:** all first-release profiles reduce entry friction without adding parallel commercial aggregates.

### M4D.0h — Internal proposal readiness and integrated acceptance

- Ship Client-first internal preview, deterministic share-readiness evaluation, Supplier-deadline valid-through suggestion, and field-level recovery.
- Do not ship public links or notifications.
- Run the small mixed fixture end to end, then regression-check Celebrity and Vineyard.
- Measure required entries, repeated known facts, context switches, error recovery, keyboard order, and 375/768/1280/1400 layouts. Record observed values; do not invent a historical baseline.

**Exit:** Staff can create and develop a departure through the three preparation outcomes, and the revised M4D publication plan has stable inputs.

### Then revise and accept M4D publication

Before implementing M4D:

- Remove “publish defaults to Sales enabled.” Require an explicit choice every publication.
- Integrate the accepted sales-action policy without implementing M5 actions.
- Add cumulative Client/Supplier funding-gap review, Agency defaults, Departure adjustment, and version-bound material-gap acknowledgment.
- Preserve atomic Package-plus-owned-service publication, activated-only M3 pins, published freeze, manifest, pause/retire, and advisory live feasibility.
- Show proposal readiness, publication readiness, current availability, and sales policy as distinct facts.

## Acceptance fixture: small mixed departure

Use a compact three-day hosted trip with facts deliberately chosen to exercise the shared workflow. Final names and money values may be test-only, but the ledger must label them.

| Component | Shape |
| --- | --- |
| Transportation | Included motorcoach or transfer; exact first-day departure; contracted support; known capacity and partial cost. |
| Hotel | Included lodging; approximate check-in; Standard/Deluxe room choice; proposed support; incomplete one occupancy price. |
| Scheduled activity | Included exact-time activity; Agency-fulfilled or contracted support; known Client price. |
| Optional meal/excursion | Optional approximate-time event; on-request support; Client surcharge pending. |

The fixture includes all of: included and optional components; at least one Client choice; approximate and exact Client schedules; different Supplier-support stages; partially complete pricing; an attached Supplier source document; an early save before components; declined-then-later Package assignment; and outcome-focus switching.

It must prove:

- internal preview shows partial facts and exact missing inputs;
- share readiness remains blocked until the required Client facts are complete;
- Supplier-support target and one component override behave independently;
- common scenario totals use one calculator and do not create demand/capacity/accounting rows;
- Package order and Client itinerary order are coherent;
- generic and specialized editors produce the same underlying records;
- no action implies that on-request supply is held or confirmed.

Celebrity Beyond / Smith Family Reunion remains the second proof for Cruise categories, occupancy, multiple sources, and pending Client prices. Vineyard remains the third proof for distinct itinerary events, Package pricing, single supplement, fixed coach cost, and dinner choice.

## Cross-cutting invariants and proof

1. Session-derived Agency owns every load. Office is attribution, never authorization. Cross-Agency/Departure identifiers return not found and fail in PostgreSQL.
2. New commands follow the shipped M4A/M3E lock order whenever they touch M3 and M4 records. Nested commands receive already-held records and never reacquire earlier locks.
3. Consequential create/update commands use durable idempotency. Same key/payload replays; different payload conflicts; failure writes no success audit or partial graph.
4. Draft outline flexibility never weakens publication: exact Package assignment, fulfillment, source, price, choices, terms, schedule/date requirements, and active Departure remain publication checks.
5. Published and abandoned version definitions retain the accepted freeze. A setup profile or scheduling amendment cannot mutate published history.
6. Approximate Client schedule is never substituted for Supplier Occurrence authority, capacity timing, sales windows, operational dates, or departed lifecycle.
7. Pending/unknown values never become zero. Partial totals are labeled partial. On-request/external supply never receives a fabricated count.
8. Preview and scenario exploration write no Holds, Allocations, capacity events, usage assumptions, Charges, Payments, or accounting records.
9. Supplier documents are private source material. Filename/content type are untrusted input; download authorization is checked on every request.
10. Viewer sees no unpublished offer, planning focus, private source document, Supplier cost, or indicative margin unless a later accepted contract explicitly changes that boundary.
11. Every changed surface passes keyboard-only use, focus/error recovery, accessible names, reflow, and 375/768/1280/1400 viewport proof.
12. Full required CI and affected M2/M3/M4 regression suites pass at each merged slice tip.

## Explicit non-goals for M4D.0

- OCR, AI extraction, email ingestion, Supplier-portal integration, or automatic contract interpretation.
- A Team/workforce-role aggregate.
- Structured multiple candidate-date windows.
- A temporary outline table or migration/conversion wizard from outline to Service Offer.
- A Cruise, Hotel, Transportation, or Activity subclass/aggregate parallel to Service Offer.
- Public storefront, Client authentication, proposal link, PDF generation, outbound email/SMS, Communication record, or recipient tracking.
- Inquiry, booking request, Hold, Allocation, Client Trip, Traveler, Charge, Receipt, Payment, or deposit capture.
- Persisted calculated totals, margin, availability, readiness percentage, or duplicated Needs-attention projection.
- Changing M3 Supplier capacity, cost, commitment, deadline, exposure, or ending authority.

## Exit

M4D.0 is complete when an authorized Staff user can save a minimally identified Departure, retain a Supplier source document, build a durable itinerary-ordered component outline without premature fulfillment or Package decisions, choose a preparation outcome, complete work from either component or Supplier perspective, and see trustworthy pending package scenarios and internal proposal readiness. The small mixed fixture, Celebrity, and Vineyard prove the common model. M4D.0 creates no published offer and no M5 commercial record.

Only then may the amended M4D publication plan be accepted and implemented.
