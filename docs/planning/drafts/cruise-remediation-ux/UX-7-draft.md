# UX-7 — Cruise Supplier Workspace Consolidation

**Status:** Accepted 2026-09-29. UX-7.0 is satisfied. UX-7.1, the shared shell and Overview, is the authorized slice. Not authority for Hotel, Slice 3A, agreement documents, or a workflow engine.  
**Indexed authority:** [m4d1-cruise-composition-ux7.md](../../m4d1-cruise-composition-ux7.md). This file and that plan are the same acceptance.  
**Parent:** [Cruise Composition UX](../../m4d1-cruise-composition-ux.md).  
**Implementation baseline:** `fe01ed2b1b395e047d3c27ed466c6e5c444e340d`  
**Depends on:** Cruise rework behavior, and UX-1 through UX-6 behavior at that baseline.  
**Prior draft:** [UD-7-draft.md](UD-7-draft.md) is the reviewed predecessor. Where they differ, this plan governs.

## 1. Purpose

UX-7 consolidates Cruise Supplier setup into one Overview hub and five workspaces:

1. Sailing
2. Cabin inventory
3. Supplier rates
4. Agreement
5. Review & activate

The required Supplier operations already exist. They are spread across the Overview, category screens, the Agreement page, the deposits-and-deadlines page, inventory maintenance, and activation review.

UX-7 reorganizes where Staff see and edit those facts. It does not introduce a Cruise domain model, workflow state, readiness model, or parallel Supplier records.

> Consolidate the workflow visually, not transactionally.

Existing commands keep their locking, idempotency, validation, history, versioning, and persistence. Visually related Agreement terms remain independently owned facts.

## 2. Goals

UX-7 must:

- provide one recognizable Cruise Supplier workspace inside the existing DepartureDesk shell;
- establish persistent Cruise setup navigation across the five areas;
- give each Supplier fact one normal Staff editing location;
- make Draft, Active, and successor context understandable;
- replace duplicate next-step mechanisms with attention derived from existing findings;
- make activation blockers actionable;
- distinguish Supplier facts from activation consequences;
- keep Advanced Supplier planning for structures the typed Cruise UI cannot represent;
- keep Client offerings isolated;
- work on desktop and narrow screens;
- remove transitional and duplicate Cruise UI after the replacement workspace exists.

UX-7 must not:

- create Cruise-specific duplicate Supplier records;
- change inventory, rate, agreement, readiness, or activation semantics;
- create persisted UI completion state or a workspace-completion evaluator;
- broaden authorization;
- modify Client offerings automatically;
- flatten an unsupported Supplier structure into a simplified Cruise form;
- introduce agreement-document storage;
- add Marketing Fund as a typed Cruise benefit.

## 3. Authority and baseline

**UX-7 implementation baseline:** `fe01ed2b1b395e047d3c27ed466c6e5c444e340d`

That commit is the code UX-7 preserves. It includes governing-version resolution for a supplemental cabin. UX-7 does not infer this baseline from the planning-status word for UX-6. UX-5 remains implemented. This acceptance does not relabel UX-5 or UX-6.

The former UX-7 cleanup sentence is replaced by this workspace consolidation. Interface-contract reconciliation, responsive and accessibility proof, and removal of superseded presentation are UX-7.7.

### UX-7.0 — Authority and baseline gate

Satisfied 2026-09-29 by acceptance of this plan. UX-7.0 changed planning documents only. It did not change the application.

1. **Amend the parent.** Accepted UX-7 authorizes this five-workspace consolidation and the UX-7.1 through UX-7.7 sequence. The original interface-contract, responsive, accessibility, and superseded-description obligations are UX-7.7.
2. **Pin the implementation.** The baseline above is the UX-6 behavior UX-7 preserves.
3. **Remove drafting residue.** No conversational-source markers remain in the accepted text.
4. **Lock authorization.** No permission change. Viewer-readable Overview and Agreement facts stay readable with `view_departures`. Cabin-category and Supplier-rate GETs stay `manage_departures` unless a later accepted access change says otherwise.
5. **Lock navigation-status sources.** The non-activation mapping in §5 is the accepted source list. UX-7.1 renders only those rows. If a later change cannot express a status from an existing fact, omit that status. Do not add a general workspace-completion evaluator.
6. **Lock status words.** Typed-adapter incompatibility is **Advanced**. Activation readiness blockers are **Needs attention**. Readiness satisfied and `cruise_post_allowed?` is **Ready to review**. Readiness satisfied and not `cruise_post_allowed?` is **Requires Advanced**. **Active** means the version this workspace is presenting is the activated governing version, and Staff are not working a successor draft.
7. **Lock UX-6 inventory.** The governing Active snapshot stays read-only except `RecordCruiseSameTermsCapacityIncrease`. Changed terms are not offered there. Overview and Agreement lose transitional Change inventory controls.
8. **Lock supplemental identity.** The new Resource keeps the selected Supplier code and the stored name `Supplemental <supplier_code> block`.
9. **Lock requirement endpoints.** Agreement becomes the normal presentation for recognized Cruise requirements. Deposit and deadline routes and controllers remain where Agreement forms and unrecognized or Advanced structures still post.
10. **Lock rate-preview authority.** Landing-page Single, Double, and Triple figures, when shown, come from `CompileCruiseSupplierRatePreview` for that category. They are illustrative scenarios, not stored Cruise-level totals.
11. **Lock staged migration.** UX-7.1 does not invent destinations for workspaces later slices have not shipped.
12. **Lock the earlier domain boundaries.** Marketing Fund stays Advanced. Sailing owns the shipped sailing facts listed in §4. Agreement displays the contracting Supplier and does not edit it. A displayed duration is return date minus departure date and is not stored. Category removal is shown only when `RemoveCruiseCabinCategory.possible?` is true.
13. **Name the two navigations.** Composition areas stay Overview, Services, Suppliers, Package & Client terms, and Review. Cruise setup navigation is contextual inside Suppliers and is not a second sidebar.

## 4. Information architecture

```
Cruise Supplier setup
│
├── Overview                         summary hub, not a sixth step
│
├── Sailing
│
├── Cabin inventory
│   ├── category inventory
│   ├── add cabin categories
│   ├── focused category editing
│   └── inventory maintenance
│       ├── same terms
│       └── changed terms
│
├── Supplier rates
│   ├── category economics summary
│   └── focused category rates
│
├── Agreement
│   ├── agreement identity and confirmation
│   ├── deposits
│   ├── deadlines
│   ├── benefits
│   ├── policies
│   └── agreement reference
│
└── Review & activate
```

Cruise setup navigation is:

```
Sailing | Cabin inventory | Supplier rates | Agreement | Review & activate
```

It sits inside Composition Suppliers. It does not replace Overview, Services, Suppliers, Package & Client terms, or Review, and it does not become another application sidebar.

### Canonical ownership

| Concern | Canonical workspace |
| --- | --- |
| Arrangement name | Sailing |
| Ship and sailing identity | Sailing |
| Departure and return dates | Sailing |
| Departure port | Sailing |
| Return port | Sailing |
| Itinerary notes | Sailing |
| Supplier contact | Sailing |
| Cabin categories, inventory treatment, opening quantity, inventory evidence | Cabin inventory |
| Same-terms capacity increase | Cabin inventory, and the Active snapshot exception under §4 Inventory maintenance entrances |
| Changed-terms supplemental capacity | Cabin inventory |
| Supplier cost schedules, estimate, contracted rates, commission, forecast occupancy, rate readiness | Supplier rates |
| Contracting Supplier, displayed only | Agreement |
| Supplier group number, group creation date, contract date, confirmation, confirmation correction, supplemental deposit treatment | Agreement |
| Initial group deposit, allocated-cabin deposit | Agreement |
| Hard Stop, Final Payment | Agreement |
| Tour conductor credit, Group Amenity Program | Agreement |
| Payment and card restrictions, cancellation ladder | Agreement |
| Agreement reference text already stored on the confirmation, benefit, or term | Agreement |
| Activation readiness, consequences, elapsed acknowledgment, confirmation-trigger values, activation evidence, Supplier identifier | Review & activate |

A workspace may summarize a fact owned elsewhere. It must not open a second editor for that fact.

Agreement displays the contracting Supplier as context. UX-7 does not make it an Agreement-owned editable field.

When both exact sailing dates are present, the header may show a derived duration equal to return date minus departure date. Duration is not stored. An incompatible shape does not receive a manufactured duration.

### Inventory maintenance entrances

```
Active snapshot
└── Add cabins under the same Supplier terms
    └── RecordCruiseSameTermsCapacityIncrease

Cabin inventory
└── Change inventory
    ├── Same terms
    │   └── RecordCruiseSameTermsCapacityIncrease
    └── Changed terms
        └── CreateCruiseSupplementalBlock, then the existing successor gates
```

Overview and Agreement lose their Change inventory controls. The Active snapshot does not offer changed terms.

## 5. Shared Cruise shell

The shell stays inside the existing application layout.

### Header

The header names the Supplier setup. The ship name is the title when the shape is compatible. The version state sits beside the title.

Ordinary initial draft:

```
Celebrity Beyond [Draft]
```

Successor draft, which is the version the normal workspace is presenting:

```
Celebrity Beyond [Draft · Version 2]

Proposed changes to Active Version 1
View active version →
```

The version this workspace is presenting, when that version is the activated governing version and Staff are not working a successor:

```
Celebrity Beyond [Active]
```

The subtitle may include the contracting Supplier’s directory name, the Supplier reference already stored on that Supplier, the derived duration, the date range, and the sailing name.

`More actions` holds secondary operations already available on the Cruise overview: Advanced Supplier planning, and Create successor draft when that command is legal. Breadcrumbs provide return navigation. “Back to Cruise” does not compete with the primary action of a focused workspace.

### Navigation status

Cruise navigation status is presentation over existing facts. UX-7 does not add a workspace-completion or workspace-readiness evaluator. Each displayed status maps to an existing compiler or readiness result. If no existing fact supports a status, the UI omits it.

Allowed words:

| Word | Meaning |
| --- | --- |
| Complete | An existing workspace presentation fact already says the recognized normal work for that area is recorded. |
| Needs attention | An existing finding identifies actionable normal Cruise work. |
| Not started | Existing records required to render that area are absent. |
| Advanced | Authoritative data exists, and the typed Cruise adapter cannot safely represent it. |
| Ready to review | Activation readiness is satisfied and `cruise_post_allowed?` is true. |
| Requires Advanced | Activation readiness is satisfied and `cruise_post_allowed?` is false. |
| Active | The version this workspace is presenting is the activated governing version, and Staff are not working a successor draft. |

**Blocked** is not a Cruise setup status. An incompatible typed shape is **Advanced**, not a second meaning of blocked. Activation readiness blockers are **Needs attention**.

Review & activate uses only this matrix, evaluated against the version the workspace is presenting:

| Existing activation facts | Display |
| --- | --- |
| That version is the activated governing version, and the workspace is not a successor draft | **Active** |
| `SupplierArrangementActivationReadiness` has blockers | **Needs attention** |
| Readiness is satisfied and `CompileCruiseActivationReview#cruise_post_allowed?` is false | **Requires Advanced** |
| Readiness is satisfied and `cruise_post_allowed?` is true | **Ready to review** |

A successor draft whose governing predecessor is already activated does not display **Active**. Its Review & activate status is one of the three draft rows.

The four non-activation areas use the table below. It cites the underlying compiler and readiness facts. It does not copy a current overview `status_label` where that label already conflicts with this draft. In particular, `CompileCruiseCompositionSummary` marks Supplier rates “Needs attention” whenever a category is still an Estimate, and it marks requirements “Needs attention” when any of the three recognized requirements is absent. Those two labels are not strip sources.

When more than one row matches, use the first match in this order: **Advanced**, **Needs attention**, **Not started**, **Complete**.

| Area | Display status | Existing source | Exact condition |
| --- | --- | --- | --- |
| Sailing | Advanced | `DetectCruiseArrangementShape#compatible?` | `compatible?` is false |
| Sailing | Complete | `CompileCruiseCompositionSummary#sailing_section` | The shape is compatible. That section’s status is “Recorded” whenever the compiler runs for a compatible Cruise. |
| Cabin inventory | Advanced | `DetectCruiseArrangementShape#compatible?` | `compatible?` is false |
| Cabin inventory | Not started | `CompileCruiseCompositionSummary#cabins_section` | `cabin_rows` is empty. The section status is “Not entered”. |
| Cabin inventory | Needs attention | `SupplierArrangementActivationReadiness` | Any blocker for this version has code `opening_authority_incomplete` |
| Cabin inventory | Complete | `CompileCruiseCompositionSummary#cabins_section` and the readiness query | `cabin_rows` is not empty, and no `opening_authority_incomplete` blocker applies |
| Supplier rates | Advanced | `DetectCruiseArrangementShape#compatible?` and `CabinRow#advanced_rates` | The arrangement shape is incompatible, or every cabin row has `advanced_rates` |
| Supplier rates | Not started | `CompileCruiseCompositionSummary#rate_posture` | No cabin row exists, or every row’s `rate_posture` is `:missing` |
| Supplier rates | Needs attention | `rate_posture` and `SupplierArrangementActivationReadiness` | At least one row has a schedule, and any row is `:contracted_working` or `:working`, any row is `:missing`, or a blocker has code `cruise_contracted_rates_missing`. Every row `:missing` does not match this row. |
| Supplier rates | Complete | `rate_posture` and `CabinRow#advanced_rates` | At least one cabin row exists, every row’s `rate_posture` is `:contracted_ready`, and no row has `advanced_rates` |
| Agreement | Advanced | `DetectCruiseArrangementShape#compatible?` | `compatible?` is false |
| Agreement | Not started | Current `SupplierArrangementCruiseAgreementConfirmation` | No current confirmation exists. |
| Agreement | Needs attention | `SupplierArrangementActivationReadiness` | A current confirmation exists, and a blocker for this version has code `cruise_agreement_unconfirmed` or `cruise_deposit_treatment_missing`. No current confirmation stays **Not started**. |
| Agreement | Complete | Current `SupplierArrangementCruiseAgreementConfirmation` and `SupplierArrangementActivationReadiness` | The current confirmation is `confirmed`, and no `cruise_deposit_treatment_missing` blocker applies. |

Statuses omitted because no existing fact supports them:

- Sailing has no **Not started** and no **Needs attention**. A compatible Cruise already has a sailing section whose status is “Recorded”. No current finding identifies sailing work that needs attention.
- Supplier rates **Needs attention** is not `rate_posture == :estimated`. A ready Estimate stays a valid category stage. The strip shows **Needs attention** only when `cruise_contracted_rates_missing` or another condition in the table is present.
- One row with `advanced_rates` does not make the Supplier rates area **Advanced** while another row remains representable. That row says Advanced. The area status follows the table.
- Agreement **Needs attention** is not the requirements section’s “Needs attention” for a missing Initial Deposit, Hard Stop, or Final Payment. Those gaps stay inside Agreement as work to record. They are not this strip status, and they are not activation readiness unless `SupplierArrangementActivationReadiness` says so. A missing optional benefit does not produce **Needs attention**. A provisional confirmation is not a separate strip condition. It is a current confirmation that is not `confirmed`, so `cruise_agreement_unconfirmed` already applies. **Not started** remains only when no current confirmation exists.

`attention_items.empty?` does not mean the version is activation-ready. The implementation baseline is `fe01ed2b1b395e047d3c27ed466c6e5c444e340d`.

### Viewer continuity

UX-7 must not make a Cruise fact unreadable for `view_departures` merely because the Staff editor requires `manage_departures`.

Overview cards stay readable with `view_departures`. For a Viewer, Cabin inventory and Supplier rates are non-linking summaries while those GETs require `manage_departures`. For Staff they link to the canonical workspaces. Shared navigation does not offer a destination the actor cannot open.

Card text uses the quantity and rate facts the existing summary already compiles. A draft numeric total may be the opening-quantity total. An activated numeric cabin shows current capacity from the projection, with opening quantity separate when that label already exists. A successor does not add carried capacity and proposed supplemental quantity into one total. A Viewer card does not invent “opening cabins” for an activated sailing.

Agreement continues to render recognized deposit and deadline facts to actors who can open Agreement with `view_departures` after the deposits-and-deadlines page leaves normal navigation.

## 6. Version context

UX-7 preserves Supplier version semantics.

For a successor draft:

- the Active version remains governing until successor activation succeeds;
- carried Pools refer to existing active operational inventory;
- presentation does not imply that carried capacity was copied into a new operational ledger;
- proposed supplemental inventory stays distinct from active inventory;
- activating the successor makes it governing and does not rewrite the prior version.

Normal Cruise editing stays draft-oriented where the existing commands require a draft. UX-7 does not add a user-selectable version-context parameter. The server resolves the governing Active version and the applicable Draft successor, as it does now.

## 7. Overview

The Overview is the Cruise Supplier summary. It is not a sixth workflow step and it does not reproduce the five editors.

It contains:

1. the shared header;
2. Cruise setup navigation;
3. one **Needs attention** region when existing findings apply;
4. four summary cards: Sailing, Cabin inventory, Supplier rates, and Agreement;
5. a visually separate Client-offering handoff.

There is no fifth Activation card. Review & activate is the navigation item and the primary action. The primary action stays available while readiness is blocked; the review page then shows blockers and does not show the activation form.

Attention is a derived collection, not readiness authority. A normal item routes to the workspace that owns the fact once that workspace has shipped. Until then, UX-7.1 keeps the current destination. Unknown or unrepresentable shapes go to Advanced Supplier planning.

Replace the single `recommended_next_action` and the separate maintenance list on the Overview with this one collection once the attention compiler is reading the same findings those lists read today. Do not keep both.

## 8. Cabin inventory

The landing screen is the category and inventory summary. The batch-add form stays a focused action, not the landing screen.

Rows are the primary interaction. Opening a row enters the focused category page. The landing row does not collect Edit, Remove, and rate links side by side.

### Inventory semantics

Numeric and nonnumeric inventory stay distinct. Nonnumeric inventory is On request or Externally managed, with quantity not tracked. It is not shown as zero.

For an activated numeric Pool:

```
Current capacity   12 cabins
Opened with         8 cabins
```

Current capacity is `capacity_projection.current_supplier_capacity`. Opening quantity remains the separate definition fact.

A successor distinguishes carried Pools from a proposed supplemental Pool and does not add those quantities:

```
DI   Deluxe Inside             Carried from active terms
DI   Supplemental DI block     Proposed · 4 cabins
```

Changed-terms supplemental inventory keeps the selected category’s Supplier code and the stored Resource name `Supplemental <supplier_code> block`. The UI displays that stored name. It does not invent `DI-2`, `DI-S`, or a shortened presentation name.

### Focused category

The focused page owns Supplier category code, category name, maximum occupancy, inventory treatment, opening quantity where numeric, Supplier evidence, and notes. Pool implementation detail stays in a secondary Inventory details region.

**Remove** appears on this page only when `RemoveCruiseCabinCategory.possible?` is true. That command remains the only removal authority. When this page ships, the Overview removal control is removed.

### Add categories

Keep `SaveCruiseCabinCategoryBatch` and per-row `CreateCruiseCabinCategorySetup`: local validation of all rows before the first write, earlier rows kept after a later failure, unresolved-suffix redisplay, and the same row idempotency keys on retry. Do not replace this with an all-or-nothing domain transaction.

### Change inventory

Change inventory on Cabin inventory offers two entrances:

- **More cabins under the same terms** invokes `RecordCruiseSameTermsCapacityIncrease` against the server-resolved governing Active version. If Staff entered inventory maintenance while viewing a successor Draft, the UI names that Active-version target. The increase is not applied to the Draft definition.
- **Cabins under changed Supplier terms** posts `CreateCruiseSupplementalBlock` for the category Staff select.

The same-terms form still shows the increase deposit before save. The changed-terms command still does not record opening evidence, agreement confirmation, contracted rates, or deposit treatment.

## 9. Supplier rates

Supplier rates is the Cruise-level place for cabin economics: a category summary, then the existing focused category editor.

The summary may show Single, Double, and Triple only as illustrative per-category scenarios from `CompileCruiseSupplierRatePreview`. The landing compiler does not reproduce the rate arithmetic. If occupancy or rate information is incomplete, the cell says the scenario is unavailable. If that category’s rate shape is outside the typed adapter, the row says **Advanced** and links to Advanced Supplier planning. The page does not flatten the graph.

Stage and readiness stay separate.

| Stage | Status examples that already exist |
| --- | --- |
| Estimate | Ready is valid |
| Contracted | Ready, or still needing review after the copy |
| — | Not recorded |

An Estimate is not defective because activation ultimately requires contracted rates. **Record contracted rates** creates a separate contracted definition, copies the estimate, leaves the estimate unchanged, and does not mark the copy ready.

The focused editor keeps the matrix, the three commission methods (Not provided yet, Dollar amount, Percentage), preview, forecast occupancy, and rate review. Forecast occupancy remains a separate save and does not allocate cabins to Clients. There is no fourth “No commission” method.

## 10. Agreement

Agreement is one Supplier-contract workspace of independently saved sections:

1. Agreement
2. Deposits
3. Deadlines
4. Benefits
5. Policies

Agreement reference is supporting provenance, not a sixth section. It displays citation and reference text already stored on the confirmation, benefit, or term. UX-7 does not add document or file storage, attachment ownership, parsing, or provenance records.

### Agreement identity

Owns Supplier group number, group creation date, contract date, confirmation, notes, supplemental deposit treatment, and correction history. Confirmation remains its own versioned event. After confirmation, group reference and contract date change through correction, which keeps the earlier confirmation.

The contracting Supplier is shown and is not edited here.

### Deposits

The initial group deposit shows the stored per-cabin rate and due date. Applicable quantity and total are the live evaluation. They are not stored snapshot facts. When every covered category is nonnumeric, the page says no opening quantity applies. It does not show `$0` for that reason.

The allocated-cabin editor keeps both structured amounts: the per-allocated-cabin amount and the attributable credit. A blank credit is not stored as zero.

### Deadlines

Recognized Cruise deadlines remain Hard Stop and Final Payment. Saving a Hard Stop does not release inventory. Any other existing requirement stays visible as an additional requirement and opens Advanced Supplier planning. The simplified page does not hide, rewrite, or delete it.

### Benefits

The normal editor supports only the typed benefits the domain already stores:

- Tour conductor credit
- Group Amenity Program (GAP)

A cash Marketing Fund, including the optional GAP concession in the Celebrity fixture, stays Advanced until the domain has a typed representation. A missing optional benefit does not make Agreement incomplete.

### Policies

Payment and card restrictions, and the cancellation ladder, stay here. Cancellation editing loads the complete current ladder, applies the add, edit, remove, or reorder in memory, and submits the complete ordered list through the existing term command. List position is transient. There is no per-step domain mutation.

### Deposits and deadlines page

UX-7 removes that page as the normal destination for recognized Cruise requirements. It does not remove the routes or controllers Agreement forms post to, and it does not remove unrecognized or Advanced requirement structures. Deleting an endpoint is out of scope unless a later cleanup proves that endpoint is unused after those form actions and Advanced paths are counted. Activation corrective links go to Agreement focus targets once UX-7.4 has shipped, not to the retired normal page.

## 11. Review & activate

This is the only detailed activation surface. It answers, in order: is this Supplier setup ready; if not, what must Staff fix and where; if ready, what will activation do; what evidence, values, or acknowledgments are required.

### Checklist and blockers

The page does not reproduce Sailing, Cabin inventory, Supplier rates, or Agreement. It shows a compact checklist. Each row links to its canonical workspace once that workspace exists.

When readiness has blockers, those blockers are the primary content and the activation form is not shown. Links target the owning workspace.

When readiness is satisfied and `cruise_post_allowed?` is false, the page says activation requires Advanced Supplier planning. It does not say the Supplier setup is not ready. `SupplierArrangementActivationReadiness` and Cruise POST representability stay separate. `CompileCruiseActivationReview` remains the presentation authority and does not become a second readiness predicate.

### Consequences

Consequences are grouped from what the activation command will actually do: opening capacity, materializing recognized requirements, and opening applicable confirmation-triggered commitments. The page does not invent a consequence the command will not produce. Agreement answers what the Supplier required. Review & activate answers what DepartureDesk will do with those requirements on activation.

A successor states that Active Version N remains in effect until activation succeeds, and that activating the draft makes it the governing version while preserving the prior version.

### Elapsed requirements, triggers, evidence, identifier

Elapsed requirements stay a consequential acknowledgment. The signed `CruiseElapsedReviewToken` remains mandatory where it applies. The token proves the exact elapsed set reviewed for that version. A checkbox alone is not enough. A stale token or a newly elapsed requirement forces review again.

Confirmation-trigger quantity and amount inputs appear only when the existing trigger shape requires them. Labels use Staff-facing units and currency. An unrepresentable trigger shape disables the Cruise post and directs Staff to Advanced.

Activation evidence is separate from Cruise agreement confirmation. Where the command already allows it, Staff choose existing compatible evidence or record new evidence. New-evidence fields appear only for the new-evidence path.

The Supplier-issued identifier stays optional and subordinate. It is not inferred from the Supplier group number. Duplicate-identifier review keeps the existing signed acknowledgment and replay behavior.

The action label is **Activate Supplier terms**. The review page is the confirmation; UX-7 does not add a second modal. After success, Staff return to the Active workspace state. The page is not replaced by an isolated success screen.

## 12. Client offering

Client offering is downstream of Supplier setup. Overview, and the activated state, may show a separate handoff: connected service title, the statement that Supplier changes are not applied to the Client offering automatically, and the existing links to Client service and Client pricing. An unconnected sailing says it is not connected.

Supplier edits, supplemental inventory, successor creation, and Supplier-version activation must not repoint a Client source binding, change Client pricing, change selectable Client quantity, or publish Client terms. Those remain explicit Offer Design operations.

## 13. Advanced Supplier planning

Advanced Supplier planning is the escape hatch. It is not a sixth Cruise workspace. When the typed adapter cannot round-trip the authoritative structure, the Cruise page shows the limitation, blocks the unsafe typed mutation, and links to Advanced. UX-7 does not simplify the stored structure to fit the form.

## 14. Presentation compilers

Compilers stay read-only. They return semantic facts, not CSS classes, button copy, or rendered URLs. None of them becomes domain authority.

| Compiler | Responsibility |
| --- | --- |
| `CompileCruiseCompositionSummary` | Overview summaries and the findings attention reads. Navigation labels are a map over existing facts, not a new completeness definition. |
| `CompileCruiseCabinInventoryWorkspace` | Cabin rows, quantities, evidence posture, rate posture, and cabin-local attention, composed from facts the summary and capacity projection already expose. |
| `CompileCruiseSupplierRatesWorkspace` | Category stage, readiness, and illustrative scenario totals obtained by calling `CompileCruiseSupplierRatePreview`. It does not reimplement rate arithmetic. |
| Agreement | Reuse the existing Agreement workspace objects unless implementation shows a real gap. Do not add a compiler for symmetry. |
| `CompileCruiseActivationReview` | Readiness presentation, `cruise_post_allowed?`, activation inputs, trigger coverage, consequences, elapsed requirements, blocker text, and successor context. |

## 15. Responsive behavior and accessibility

Narrow screens stack the header, keep Cruise setup navigation usable, turn dense tables into labeled cards, and keep current, opening, and proposed quantities readable without horizontal page overflow. The rate matrix may use a deliberate narrow representation. The page itself does not scroll horizontally at 375, 768, 1280, or 1400 pixels. Desktop and narrow layouts show the same domain facts.

Workflow actions are keyboard reachable. Focus moves to the relevant error or confirmation after a focused save. Status is text, not color alone. Destructive actions are distinguishable from ordinary saves. Validation errors are associated with their fields. The current Cruise setup area is identified in the navigation.

## 16. Permissions

UX-7 does not change authorization. Viewer access stays read-only on surfaces that already allow `view_departures`. Staff mutation controls appear only where the existing permission, lifecycle, version, and command rules allow the operation. Hiding a button does not replace the server check. Advanced Supplier planning keeps its current permission.

## 17. Testing

Each slice proves its presentation. It does not re-prove domain semantics already covered, except where a presentation change could drop a boundary.

Shared shell: Draft, Active, and successor context; five destinations; Viewer cards readable and Cabin or Rates links absent when those GETs are forbidden; Staff links present; More actions respects successor legality; incompatible shape opens Advanced; no horizontal overflow at 375 pixels.

Overview: four summaries; attention items can appear together; destinations match the slice that has shipped; numeric and nonnumeric cabins; contracted, estimated, missing, and advanced rates; a ready Estimate is not attention by itself; optional benefits are not attention; activation stays reachable while blocked; Client offering is visually downstream; carried and proposed quantities are not summed.

Cabin inventory: canonical draft categories; batch create and retry; numeric versus nonnumeric; active current capacity versus opening quantity; successor carried versus `Supplemental <code> block`; removal only when `possible?` is true and the Overview control is gone; same-terms and changed-terms commands; the Active snapshot offers only `RecordCruiseSameTermsCapacityIncrease`.

Supplier rates: category summary; illustrative Single, Double, and Triple from `CompileCruiseSupplierRatePreview`; Estimate versus Contracted; ready Estimate remains valid; contracted copy leaves the estimate unchanged and not ready; three commission methods; preview; forecast occupancy; unsupported graph opens Advanced.

Agreement: five sections; independent saves; live Initial Deposit evaluation, including mixed and all-nonnumeric inventory; attributable credit; Hard Stop and Final Payment; optional benefits neutral; Marketing Fund is not a normal benefit row; whole-ladder replacement; agreement reference text without a document field; no Change inventory control; no normal navigation to the deposits-and-deadlines page; deposit and deadline posts still reach the existing endpoints.

Review & activate: blocked GET hides the form; corrective links match shipped workspaces; ready and representable GET shows the form; ready and not representable says Requires Advanced and does not say not ready; a successor draft is not labeled Active; Viewer cannot POST; signed elapsed review required; stale and newly elapsed reviews rejected; inputs survive validation failure; existing and new evidence; duplicate identifier review; successful activation returns to the Active workspace; successor activation leaves the Client offering unchanged.

## 18. Delivery

### UX-7.1 — Shell and Overview

Shared header, Cruise setup navigation, version context, status labels mapped from the UX-7.0 fact list, derived attention, four Overview summaries, Client-offering handoff. Existing corrective destinations stay until the owning slice ships. Do not add placeholder workspace routes.

### UX-7.2 — Cabin inventory

Landing page, batch add, focused category editing, evidence, active and opening and proposed and nonnumeric quantities, inventory maintenance, removal via `RemoveCruiseCabinCategory.possible?`, and removal of the Overview removal control. Retarget cabin corrective links in the same slice.

### UX-7.3 — Supplier rates

Cruise-level rates workspace, illustrative scenario totals, the existing focused editor, stage and readiness, contracted-rate transition, commission, preview, forecast occupancy, and the narrow matrix. Retarget rate corrective links in the same slice.

### UX-7.4 — Agreement

Shared shell and the five sections, live deposit evaluation, cancellation ladder, agreement reference, removal of Change inventory, removal of normal deposits-and-deadlines navigation, and Agreement corrective targets. Write endpoints stay.

### UX-7.5 — Review & activate

Shared shell, the activation status matrix, four-area checklist, canonical corrective destinations, grouped consequences, elapsed review, trigger inputs, Supplier evidence, identifier and duplicate review, and the Active result state.

### UX-7.6 — Active snapshot and inventory polish

Presentation only, on top of the pinned UX-6 behavior: Active snapshot, same-terms maintenance through `RecordCruiseSameTermsCapacityIncrease`, changed-terms successor inventory from Cabin inventory, Active and Draft navigation, carried versus proposed quantities, and removal of any remaining transitional inventory entry points outside Cabin inventory and the snapshot exception. No new inventory semantics.

### UX-7.7 — Closure

Responsive proof at 375, 768, 1280, and 1400 pixels. Accessibility proof. Terminology. Removal of superseded Overview editors, duplicate next-step presentation, the standalone Overview activation card, transitional later-capacity controls outside the §4 entrances, normal-path deposits-and-deadlines navigation, activation links to retired screens, duplicate version-context implementations, and dead helpers or CSS that only served the replaced presentation. Interface-contract reconciliation. End-to-end proof for Viewer and Staff, initial Draft, Active Cruise, successor Draft, incompatible shape, blocked activation, and successful activation.

Do not delete authoritative commands, generic Supplier-planning behavior Advanced still needs, domain services the new workspaces call, historical version records, or the compatibility escape hatch.

## 19. Exit

UX-7 is complete when Staff can move through Overview, Sailing, Cabin inventory, Supplier rates, Agreement, and Review & activate without a second normal editor for the same fact and without learning which internal record type owns it.

The boundary is unchanged by the consolidation: UX-7 may reorganize where existing facts are seen and edited. It may not invent completion semantics, widen access, normalize an unsupported domain shape, store an agreement document, add a Marketing Fund benefit, or remove the Active snapshot’s same-terms increase.
