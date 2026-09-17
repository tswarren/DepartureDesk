# M3D.0 — Supplier-planning workspace compression

**Status:** Shipped. Merged to `main` on 2026-09-17 in pull request #70. This document remains the M3A–M3C workflow-remediation contract. It is not authority for Arrangement activation or other M3D domain records.

**Parent authority:** [M3 — Supplier planning](m3-supplier-planning.md), shipped [M3A](m3a-draft-arrangement-structure.md), [M3B](m3b-supplier-capacity.md), and [M3C](m3c-cost-terms-and-forecasts.md), and the active [interface contract](../ui/interface-contract.md).

**Relationship to M3D:** **HARD prerequisite, now satisfied.** This is a bounded remediation slice over shipped M3A–M3C behavior. It introduces no Arrangement activation, successor, Reservation, confirmation, commitment, effective-capacity event UI, or other M3D domain record. [M3D](m3d-activation-reservations-confirmations.md) remains Accepted and not yet shipped.

## Goal

Reduce unnecessary Staff effort in Supplier planning without weakening or merging the domain distinctions established by M3A–M3C.

Staff should be able to describe a common Item, classify its capacity, enter its initial Supplier cost, provide required planning quantities, and make the definition forecast-ready through a small number of coherent, progressively disclosed workflows. Internal records and command boundaries remain explicit; the interface does not require one separate user action for every persisted row.

This slice treats friction as a workflow defect when Staff must:

- create predictable dependent records through several empty intermediate states;
- repeatedly reselect context the owning route already establishes;
- view inputs that cannot apply to the chosen mode or calculation;
- save every Occurrence–Resource decision individually;
- leave the current context merely to discover why planning is incomplete;
- interpret raw counts rather than receive a specific next action; or
- navigate long operational pages whose routine actions compete visually with destructive and recovery controls.

## Evidence from the shipped surfaces

The existing domain behavior is correct, but the presentation exposes its implementation sequence:

- Arrangement structure uses separate full-page create/edit forms for Items, Occurrences, and Resources.
- Arrangement Item cards expose several simultaneous edit, remove, move, capacity, and cost actions.
- Managed capacity requires an individual saved classification for each Occurrence–Resource pair before its first Pool can be entered.
- The Pool form exposes semantic, quantity, evidence, and Administrator-override fields together even though several combinations are inapplicable.
- Cost setup requires Staff to create a source, then a stage, then one or more components, then separately mark the stage ready.
- The component form displays amount, rate, two minimum shapes, quantity basis, participant category, occupancy selectors, percentage treatment, and base links simultaneously.
- Usage assumptions and occupancy profiles are presented as separate technical structures even when Staff encounter them only because one formula needs a quantity.
- The Arrangement summary reports counts and warnings but does not consistently identify the next corrective action.

M3D.0 changes those interactions, not their financial or operational meaning.

## In scope

- One clearer Arrangement planning workspace over the shipped M3A–M3C records.
- Ordered, actionable readiness guidance for structure, capacity, and costs.
- Progressive disclosure and context-preserving Turbo Frames with full-page fallback.
- A guided Item-setup workflow using existing Item, Occurrence, and Resource meanings.
- A dedicated reorder mode that removes routine move controls from the default reading state.
- Bulk capacity-pair classification inside the existing Occurrence-grouped hierarchy.
- An atomic classify-and-create-first-Pool workflow for a pooled pair.
- Conditional Pool fields based on inventory mode and evidence/override choice.
- An atomic initial-cost workflow that creates a cost source, one definition, and either its first component or explicit zero-cost declaration.
- Calculation-specific component forms with user-facing amount and percentage parsing.
- Contextual planning-quantity prompts when a chosen calculation actually requires them.
- A focused definition review/readiness workflow.
- Viewer-safe read surfaces and existing inactive-Supplier recovery behavior.
- Request/system/accessibility/responsive/query/regression proof for complete Staff tasks.

## Out of scope

- Any change to Arrangement, Item, Occurrence, Resource, Pool, cost-source, definition, component, assumption, or forecast semantics.
- New tables or migrations unless a narrowly demonstrated idempotency/result association cannot use the shipped family; the expected implementation adds no schema.
- Arrangement activation, successors, effective-capacity event controls, Reservations, confirmations, identifiers, commitment triggers, commitments, Deadlines, or exposure.
- Inferring capacity applicability, Pool mode, quantity, Supplier evidence, cost stage, calculation kind, economic role, component base, occupancy, or readiness.
- Automatically marking a cost definition forecast-ready after saving it.
- A service-specific cruise, hotel, motorcoach, excursion, or insurance wizard.
- Saved templates, cloning across Departures, named scenarios, bulk import, or spreadsheet upload.
- Drag-only ordering or a new JavaScript UI framework.
- A capacity matrix. The active interface contract's Occurrence-grouped hierarchy remains authoritative.
- Changes to permissions, navigation, Supplier lifecycle, Departure lifecycle, `SearchDepartures`, money storage, forecast evaluation, or audit meaning.
- Hiding required provenance or recovery warnings merely to shorten a form.

## Locked interaction principles

1. **One task, one workflow.** A common business task may create several already-authorized records atomically.
2. **No semantic collapse.** Composite commands orchestrate existing records; they do not merge their identities or meanings.
3. **No hidden inference.** Suggested/defaulted values remain visible and editable before submission.
4. **Progressive disclosure.** Inputs appear only when the selected mode, kind, or role can use them.
5. **Read first.** Default pages prioritize current facts and next actions; edit, reorder, recovery, and destructive controls appear on demand.
6. **Preserve context.** Success and validation failure return Staff to the owning Item/source/pair with entered values and error-summary focus.
7. **Server authority.** Conditional JavaScript improves presentation only. The server validates the complete submitted shape and full-page fallback remains functional.
8. **Accessible efficiency.** Every compressed workflow is keyboard complete and does not depend on drag, hover, color, or pointer precision.
9. **No premature readiness.** Saving structure or terms does not claim Supplier truth or forecast readiness.
10. **Recovery stays narrow.** Forced-inactive Supplier and departed-Departure recovery never regains ordinary expansion controls through a compressed path.

## Arrangement planning workspace

The Arrangement profile remains the owning workspace, but its default composition changes from a long collection of equally weighted controls to:

1. Arrangement identity and draft/recovery state.
2. **Next actions** ordered by blocking importance.
3. Compact structure/capacity/cost readiness summary.
4. Item cards in manual order.
5. Arrangement-wide cost summary and forecast link.

### Next actions

The server derives safe, specific actions from authoritative facts. Examples:

- Add the first Item.
- Add an Occurrence and Resource to a managed Item.
- Decide whether capacity is managed.
- Classify 4 remaining Occurrence–Resource pairs.
- Add a Pool to a pooled pair.
- Complete Supplier evidence for “O1 block.”
- Add an Item-scoped cost source.
- Complete the contracted stage for “Cruise fare.”
- Add expected persons for the excursion assumption.
- Review and mark the estimate ready.

The list never claims that omitted real-world costs or commitment rules are known. It explains only incompleteness detectable from shipped M3A–M3C facts.

Each action links to the exact owning section and opens no disclosure through a URL fragment alone. Where editing is inline, a real button controls the Turbo Frame/disclosure and focus.

### Item cards

Default Item cards show:

- name, category, and effective Provider;
- Occurrence and Resource summary;
- capacity applicability, decided/total pair count, Pool count, and highest-priority warning;
- cost-source count, selected ready-stage summary, and highest-priority missing input; and
- one primary **Continue setup** or **Review** action.

Secondary actions move into explicit **Edit structure**, **Reorder**, **Capacity**, and **Costs** modes. Destructive removal remains visibly distinct and confirmation-backed.

Do not show Move up, Move down, Edit, Remove, Capacity, and Costs as equal-weight actions on every default card/row.

## Structure workflow

### Guided Item setup

The common create path may collect in one form:

- required Item name/category and optional Provider/description;
- optional first Occurrence; and
- optional first Resource.

`CreateArrangementItemSetup` is an atomic composite command over the shipped create commands:

- Item is always required.
- Occurrence and Resource sections are optional and explicitly selected.
- Each created record retains its existing identity, ownership, audit meaning, validations, and route after creation.
- Failure of any selected section rolls back the full setup.
- Same idempotency key plus the same payload returns the original Item and child results without duplicate audit.
- Same key plus a different payload returns `conflict`.

The existing single-record commands and full-page forms remain valid fallbacks and edit paths.

### Add Occurrence and Resource

From an Item card, **Add occurrence** and **Add resource** may open context-preserving Turbo Frames. Forms do not re-ask for Arrangement or Item. Full-page URLs continue to work without JavaScript.

Occurrence date/time/time-zone behavior and Provider resolution remain unchanged. The UI may seed visible Departure dates/time zone but never silently derives contracted schedule.

### Reorder mode

One **Reorder items** or **Reorder resources** action opens a focused mode with keyboard-operable Move up/Move down controls. The reading view shows no repeated movement controls. Commands continue submitting a complete ordered ID list with the governing version lock.

## Capacity workflow

The active interface contract continues to require an Occurrence-grouped hierarchy rather than a matrix. M3D.0 compresses decisions within that hierarchy.

### Applicability

The Item card and capacity workspace present the required choice plainly:

- **Track Supplier capacity** (`managed`)
- **No managed capacity** (`unmanaged`)
- **Decide later** (draft `NULL`)

The stored catalog remains unchanged. Help text explains that unmanaged means intentionally not tracked, while decide later means incomplete.

### Bulk pair classification

`BulkClassifyCapacityPairs` accepts an explicit decision for one or more currently eligible non-cancelled Occurrence–Resource pairs in the same Item/version.

- Staff may set all undecided pairs for one Occurrence, all undecided pairs for one Resource, or a reviewed selection.
- The confirmation/submit surface lists every affected pair and selected `pooled`/`not_applicable` value.
- Existing decisions with Pools are never silently changed.
- A change to `not_applicable` still requires no Pool definition.
- The command locks the version and affected pairs/members under the shipped M3B order.
- The operation is atomic, idempotent, and writes one Arrangement audit with affected IDs/counts rather than one success audit per pair.
- Viewer and recovery paths never receive bulk expansion controls.

Single-pair classification remains available.

### Classify and create first Pool

For an undecided pair, Staff may choose **Pooled** and enter the first Pool in one workflow. `ConfigureCapacityPairWithPool` atomically creates the pair classification, stable Pool, and exact-version Pool definition using shipped M3B validations.

If Pool creation fails, the pair does not remain falsely classified as pooled with no Pool. Existing `CreateCapacityPool` remains available for additional tranches.

### Conditional Pool form

The form shows only applicable inputs:

- `block`/`allotment`: proposed opening quantity, basis/unit label, and evidence or override.
- `on_request`/`externally_managed`: no numeric quantity or numeric evidence fields; clearly state **Quantity not tracked**.
- ordinary evidence: evidence kind/date/note and optional external reference.
- Administrator override: override reason; ordinary evidence inputs are hidden/cleared and remain mutually exclusive server-side.

Stable semantic choices remain visible before save. Changing a draft selection never silently converts or drops an incompatible entered value; the server returns a clear error or the client asks for explicit confirmation before clearing.

## Cost workflow

### Guided initial cost

`CreateSupplierCostSetup` creates, in one transaction:

1. one exact-version Supplier cost source;
2. one `estimate` or `contracted` definition; and
3. either:
   - one initial component; or
   - one explicit `zero_cost` declaration with reason.

The form begins with business-facing choices:

- What is this cost for?
- Which Supplier charges it?
- Is this an estimate or contracted term?
- Is the known cost calculated or zero?
- How is the first charge/credit/commission calculated?

Source context defaults from the owning Arrangement/Item route. Occurrence and Resource narrowing remain optional and visible. Currency and `half_up` rounding remain governed values rather than routine fields.

The composite command:

- uses the shipped source, definition, and component validations;
- preserves separate IDs and audit provenance;
- locks/rechecks the exact draft version and charging Supplier;
- rolls back all records on failure;
- uses one durable idempotency result root that returns every created ID;
- writes one Arrangement-level composite success audit with safe created IDs; and
- does not mark the definition forecast-ready.

Existing individual create commands remain available for later stages/components and full-page fallback.

### Calculation-specific component editor

The selected calculation kind controls visible fields:

| Calculation | Visible required inputs |
| --- | --- |
| Fixed | Amount. |
| Unit rate | Amount, quantity basis, and applicable optional category/occupancy selector. |
| Percentage | User-facing percentage, treatment, and explicit earlier component bases/directions. |
| Minimum amount shortfall | Minimum amount and explicit earlier monetary bases/directions. |
| Minimum quantity shortfall | Minimum quantity, compatible quantity basis/selectors, and exactly one earlier compatible unit-rate component. |

Economic role remains a separate explicit choice. Irrelevant stored fields must submit blank and contradictory nonblank values still fail `invalid`.

Percentage entry uses a familiar percent value (for example `16` for 16%) and strictly converts it to stored decimal `0.16`. The form does not ask Staff to understand `1.0 = 100%`. Money accepts ordinary currency amounts through the shipped strict parser.

Base selection displays only eligible earlier components. Direction uses business labels such as **Include in base** and **Subtract from base**, with technical meaning available in help text.

### Contextual planning quantities

The workspace does not lead with participant-category, assumption, and occupancy-profile administration when no component needs them.

When a chosen calculation lacks required quantity input, its definition card shows a contextual action such as:

- Add expected persons for Island Sightseeing.
- Add expected room nights for Standard room.
- Define anonymous occupancy patterns for O1 cabin pricing.

The action opens an assumption form preselected to the component's exact Item/Occurrence/Resource tuple. Staff still explicitly enter quantities; the application does not infer demand from M3B capacity or Occurrence dates.

Participant categories and occupancy profiles remain reusable exact-version records. The Item cost workspace must expose explicit edit controls and dependency-safe remove controls for unused participant categories through the shipped commands/routes. Removal must remain blocked when a category is referenced; the interface must explain the dependency rather than hide or bypass it. Advanced occupancy-profile management remains available from the same workspace.

### Review and forecast readiness

Each definition has one **Review definition** action. The review shows:

- source context and charging Supplier;
- stage/mode/currency;
- ordered components with business-readable formulas;
- explicit bases and rounding;
- required assumptions and current evaluated values;
- forecast result or exact blockers; and
- readiness provenance/contracted attestation input.

Only this review submits `MarkCostDefinitionForecastReady`. Saving a component, source, or assumption never marks readiness automatically.

Consequential edits continue to invalidate readiness under M3C. The workspace brings the affected definition into **Next actions** with a plain explanation.

## Composite-command contract

M3D.0 may add only these composite commands:

- `CreateArrangementItemSetup`
- `BulkClassifyCapacityPairs`
- `ConfigureCapacityPairWithPool`
- `CreateSupplierCostSetup`

They are orchestration boundaries over shipped domain services, not alternative domain models.

Every command defines:

- actor and `manage_departures` authorization;
- Agency/Departure/Arrangement/version ownership;
- active Supplier rechecks where applicable;
- transaction and canonical M3 lock order;
- submitted `lock_version` behavior;
- durable idempotency scope and replay result, plus a result root for creates;
- expected `AgencyCommand` error codes;
- exact records created/changed;
- one non-duplicative success audit; and
- a full-page fallback response.

Do not invoke public command objects inside one another if they reacquire locks or write duplicate audits. Extract shared validation/building support or provide already-locked internal operations.

The expected implementation adds no database table. If the shipped `AgencyCommandIdempotencyKey` cannot return a safe multi-record result through an existing durable root, use the top-level Item, Pool, or source result as the root and recover children through constrained ownership. Do not add a generic JSON result document.

## Audit

Continue using `SupplierArrangement` as the subject. Add one action for each new composite command:

```text
supplier_arrangement.item_setup_created
supplier_arrangement.capacity_pairs_bulk_classified
supplier_arrangement.capacity_pair_pool_configured
supplier_arrangement.cost_setup_created
```

Each action records the exact version and safe IDs/counts of every created or changed record, plus the submitted choices needed to explain the business action. The domain rows remain authoritative. Do not emit the shipped single-record success actions as duplicates for children created inside a composite command.

The shipped single-record commands retain their existing action meanings. Expected failure, validation rollback, no-op, and idempotent replay write no success audit.

## Authorization and state gates

- Viewers retain read-only `view_departures` access and see no hidden mutation inputs.
- Staff/Administrators use `manage_departures` for ordinary composite workflows.
- `override_supplier_planning_terms` remains Administrator-only and affects only the existing explicit M3B override path.
- Draft Departure, active Departure, departed recovery, inactive Supplier, abandoned Arrangement, and immutable-version rules remain exactly as shipped.
- Composite paths must not create records that the corresponding individual command could not create in the same state.

## Error and recovery behavior

Use existing `AgencyCommand` codes. Validation returns `invalid`; stale lock/idempotency mismatch returns `conflict`; state gates return `invalid_state`; foreign/cross-Agency IDs return `not_found`; permission failures return `unauthorized`; retained dependencies return `dependency_exists`.

On failure:

- return `unprocessable_entity` for validation;
- preserve every entered applicable value;
- render one error summary with focus;
- identify the failing sub-section without exposing internal service names;
- create no partial children, pair decisions, Pool, source, definition, component, or audit; and
- offer a stable full-page recovery path when a Turbo Frame request fails.

## Routes and HTTP semantics

Routes remain nested under the owning Departure/Arrangement/Item. Named routes may be refined, but expected additions are:

```text
GET/POST  .../items/setup
PATCH     .../items/:item_id/capacity/pairs/bulk
POST      .../items/:item_id/capacity/pairs/:occurrence_id/:resource_id/pool-setup
GET/POST  .../items/:item_id/costs/setup
GET/POST  .../costs/:source_id/definitions/:id/review
```

Turbo Frame requests use the same commands and validations as full-page requests. A URL fragment positions the page only and never opens an editor or authorizes a record.

## Interface details

- Reuse existing `dd-` components and design tokens.
- Use one primary action per panel/card.
- Put secondary edit/reorder controls behind explicit modes or disclosures.
- Destructive actions remain red, separated, and confirmation-backed.
- Amber marks incomplete/provisional/attention state and always includes text.
- Keep neutral inputs until interaction, teal action/selection, and amber focus ring.
- Dense decision lists use horizontal separators, not excessive boxes or vertical grid lines.
- Keep action labels business-facing: **Track Supplier capacity**, **Add cabin block**, **Add contracted cost**, **Review definition**.
- Technical terms such as source, stage, component, basis, and projection may appear in explanatory detail where needed, but should not be the only action language.
- Disclosures use native `<details>` only when focus/error behavior remains reliable; otherwise use the existing Stimulus/Turbo patterns with complete keyboard behavior.

## Query and performance contract

- Arrangement workspace query count remains bounded as Items, Occurrences, Resources, pairs, Pools, sources, definitions, and warnings grow.
- Next-action derivation preloads required facts and does not evaluate one forecast per row through N+1 queries.
- Bulk pair pages load the complete eligible Item pair set in bounded queries.
- Cost review evaluates one consistent cost graph snapshot.
- Turbo partial rendering must not replace bounded eager loading with repeated endpoint chatter.
- Representative Celebrity and Vineyard workspaces receive query-count assertions and `EXPLAIN` evidence for any new aggregate query.

## Accessibility and responsive contract

- All workflows function without JavaScript through full-page fallback.
- Keyboard users can open, complete, submit, cancel, and recover every mode.
- Focus moves to the first invalid field through the error summary and returns to the initiating control on cancel.
- Bulk controls use real fieldsets, legends, row/column context, and explicit selected counts.
- Reorder mode is operable with buttons; drag may never be the only mechanism.
- Conditional fields announce relevant changes and retain label/error association.
- At 375 and 768 px, Occurrence-grouped capacity rows stack without losing the Occurrence/Resource context.
- At 1280 and 1400 px, forms use available width without producing long single-line fields or scattered actions.
- Status and readiness never rely on color or symbols alone.

## Task-flow acceptance gates

These gates test complete work rather than isolated form reachability.

### Structure

- From an empty Arrangement, Staff can create an Item with its first Occurrence and Resource in one submitted workflow.
- Staff can add more Occurrences/Resources without losing Arrangement/Item context.
- Default reading state is not dominated by edit/remove/move controls.

### Capacity

- Staff can classify all reviewed undecided pairs for one Item in one submitted workflow.
- Staff can classify one pair as pooled and create its first Pool without leaving an invalid intermediate state.
- Nonnumeric modes never show or retain numeric quantity inputs.
- Ordinary evidence and Administrator override inputs are not displayed together as if both apply.
- No capacity matrix is introduced.

### Costs

- Staff can create a common fixed, unit-rate, percentage, minimum, expected-commission, or zero-cost setup without first creating empty source and definition shells through separate screens.
- A component editor shows only fields applicable to its selected calculation.
- Percentage entry is user-facing percent, strictly parsed, and persists the exact decimal rate.
- Missing planning inputs lead directly to the correct pre-scoped assumption workflow.
- Readiness occurs only through an explicit review.

### Whole scenarios

- Celebrity O1: Item/sailing/resource structure, eight-cabin block, adult/additional fare components, NCCF, discount, taxes/fees, commission, assumptions, and forecast readiness can be prepared without navigating unrelated technical administration.
- Hilton: room Item, stay Occurrence, room Resource/Pool, room-night/additional-adult costs, and evidence remain distinguishable but efficient.
- Transfers: three Occurrences with repeated Resource treatment can use bulk pair decisions without conflating segments.
- Excursion: per-person cost and minimum-five shortfall guide Staff to the required expected-person assumption.
- Vineyard Tour: coach fixed cost, passenger rate, seat capacity, and single-supplement planning remain composable without a tour-specific wizard.

The scenarios prove workflow compression, not automatic inference or service-specific subclasses.

## Required proof

### Commands

- Atomic success and rollback for every composite command.
- Same-key/same-payload replay and same-key/different-payload conflict.
- Stale version/definition locks.
- Cross-Agency identifiers return not found.
- Inactive Supplier and departed/recovery gates match individual commands.
- One success audit per composite business action and no audit on expected failure.
- Genuine multi-connection races for Item setup, bulk classification, classify-plus-Pool, and initial cost setup against competing draft mutations/Supplier inactivation.

### Requests and system

- Submitted values survive validation in both Turbo and full-page paths.
- Error-summary and focus behavior.
- Viewer surfaces expose no mutation controls or hidden sensitive facts.
- Keyboard-only completion of the four task families.
- Required viewport proof.
- Direct URLs and browser Back/Forward remain safe.
- Reorder mode and destructive confirmations remain accessible.

### Regression

- Every shipped M3A–M3C single-record command remains valid.
- Forecast calculation, readiness invalidation, capacity constraints, recovery, tenancy, audit, and query behavior remain green.
- No activation, Reservation, confirmation, commitment, or effective-capacity route/model appears.
- Full CI, Tailwind build, lint, and security checks pass.

## Documentation when this slice ships

Completed after merge of pull request #70 to `main`:

- Marked M3D.0 Shipped in this plan, the M3 parent, `AGENTS.md`, root `README.md`, `docs/README.md`, roadmap immediate work, current architecture, and terminology.
- Amended the Departure section of the active interface contract with guided Item setup, bulk hierarchical capacity decisions, conditional Pool forms, guided initial cost, contextual assumptions, readiness review, and reorder mode while retaining the no-capacity-matrix rule.
- Left the M3A, M3B, and M3C domain contracts and ADR decisions unchanged.
- Continued to describe every M3D domain record as unimplemented until its Accepted slice ships it.

## Exit gate

M3D.0 is complete only when:

1. This plan was Accepted before implementation began and remains the controlling authority through merge and proof.
2. The Arrangement workspace provides specific ordered next actions without overstating completeness.
3. Guided structure setup creates only shipped M3A records and preserves all ownership/lifecycle rules.
4. Bulk pair and classify-plus-Pool workflows preserve every M3B invariant and introduce no matrix.
5. Guided initial cost and calculation-specific editing preserve every M3C source/stage/component/assumption/readiness invariant.
6. Common workflows no longer require empty intermediate record creation or irrelevant fields.
7. Composite commands are atomic, idempotent, race-safe, and audit-safe.
8. Viewer, inactive-Supplier, departed-recovery, and cross-Agency behavior remain fail-closed.
9. Complete scenario tasks are keyboard accessible and responsive at required viewports.
10. Query bounds, M0–M3C regression, Tailwind, lint, security, and full CI are green.
11. Documentation marks only M3D.0 interaction remediation shipped; Arrangement activation and later M3D records remain unimplemented.
