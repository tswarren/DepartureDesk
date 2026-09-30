# UX-7 — Cruise Supplier Workspace Consolidation

**Status:** Superseded draft. Not implementation authority.  
**Successor:** [m4d1-cruise-composition-ux7.md](../../m4d1-cruise-composition-ux7.md), Accepted 2026-09-29. [UX-7-draft.md](UX-7-draft.md) is the same acceptance. Where this file differs, the accepted plan governs.  
**Parent:** M4D.1 — Departure Composition Workspace  
**Scope:** Cruise Supplier setup presentation and navigation  
**Depends on:** Accepted Cruise rework and UX-1 through UX-6 behavior

## 1\. Purpose

UX-7 consolidates the Cruise Supplier experience into five coherent workspaces:

1. **Sailing**  
2. **Cabin inventory**  
3. **Supplier rates**  
4. **Agreement**  
5. **Review & activate**

The existing implementation contains the required Supplier-domain operations, but those operations are distributed across the Cruise Overview, category-specific screens, Agreement screens, generic requirement screens, inventory-maintenance flows, and activation review.

UX-7 reorganizes those existing capabilities around the way Staff performs the work.

It does **not** introduce a new Cruise domain model, workflow state machine, readiness model, or parallel set of Supplier records.

The primary design principle is:

> **Consolidate the workflow visually, not transactionally.**

Existing commands retain their locking, idempotency, validation, history, versioning, and persistence semantics. This is especially important for Agreement, where visually related Supplier terms remain independently owned domain facts. :chatgpt-content-reference{index="1"}

---

# 2\. Goals

UX-7 MUST:

- provide one recognizable Cruise Supplier workspace;  
- preserve the existing DepartureDesk application shell;  
- establish a persistent five-area Cruise navigation;  
- give each Supplier fact one canonical normal Staff editing location;  
- make Draft, Active, and successor-version context understandable;  
- replace duplicated "next step" mechanisms with derived attention;  
- make activation blockers directly actionable;  
- distinguish Supplier facts from activation consequences;  
- preserve Advanced Supplier planning for structures the typed Cruise UI cannot safely represent;  
- preserve Client-offering isolation;  
- provide usable desktop and mobile layouts;  
- remove transitional and duplicate Cruise UI once replacement workspaces exist.

UX-7 MUST NOT:

- create Cruise-specific duplicate Supplier records;  
- change Supplier inventory semantics;  
- change Supplier rate calculations;  
- change agreement-term semantics;  
- change activation readiness semantics;  
- change activation command semantics;  
- create persisted UI completion state;  
- automatically modify Client offerings;  
- flatten unsupported Supplier structures into simplified Cruise forms.

---

# 3\. Information architecture

The canonical Cruise Supplier experience is:

```
Cruise Supplier setup
│
├── Sailing
│
├── Cabin inventory
│   ├── category inventory
│   ├── add cabin categories
│   ├── focused category editing
│   └── inventory maintenance
│       ├── additional cabins under same terms
│       └── cabins under changed terms
│
├── Supplier rates
│   ├── category economics summary
│   └── focused category rates
│       ├── Estimate
│       ├── Contracted
│       ├── rate matrix
│       ├── expected commission
│       ├── preview
│       ├── forecast occupancy
│       └── rate review
│
├── Agreement
│   ├── agreement identity and confirmation
│   ├── deposits
│   ├── deadlines
│   ├── benefits
│   ├── policies
│   └── Supplier agreement source
│
└── Review & activate
    ├── readiness
    ├── corrective actions
    ├── activation consequences
    ├── elapsed-requirement acknowledgment
    ├── confirmation-trigger values
    ├── Supplier confirmation evidence
    ├── Supplier-issued identifier
    └── activation
```

The five-area navigation is therefore:

```
Sailing | Cabin inventory | Supplier rates | Agreement | Review & activate
```

Overview is **not** a sixth workflow step. It is the Cruise Supplier summary/hub from which Staff enters these workspaces. The notes explicitly establish that the strip represents Supplier setup areas and should navigate to real workspaces rather than Overview anchors. :chatgpt-content-reference{index="2"}

---

# 4\. Canonical workspace ownership

Each fact or operation MUST have one normal Staff home.

| Concern | Canonical workspace |
| :---- | :---- |
| Sailing identity, dates, itinerary | Sailing |
| Cabin categories | Cabin inventory |
| Inventory treatment | Cabin inventory |
| Opening Supplier capacity | Cabin inventory |
| Supplier inventory evidence | Cabin inventory |
| Same-terms capacity increases | Cabin inventory |
| Changed-terms supplemental capacity | Cabin inventory |
| Supplier cost schedules | Supplier rates |
| Estimate / Contracted economics | Supplier rates |
| Expected commission | Supplier rates |
| Forecast occupancy | Supplier rates |
| Rate forecast readiness | Supplier rates |
| Supplier group number | Agreement |
| Contract date | Agreement |
| Agreement confirmation | Agreement |
| Initial group deposit | Agreement |
| Allocated-cabin deposit | Agreement |
| Hard Stop | Agreement |
| Final Payment | Agreement |
| TC / GAP / marketing fund | Agreement |
| Payment/card restrictions | Agreement |
| Cancellation ladder | Agreement |
| Supplier agreement source | Agreement |
| Activation readiness | Review & activate |
| Activation consequences | Review & activate |
| Elapsed requirement acknowledgment | Review & activate |
| Activation evidence | Review & activate |
| Activation Supplier identifier | Review & activate |

A workspace MAY summarize information owned elsewhere but MUST NOT create a competing editor.

---

# 5\. Shared Cruise shell

UX-7 establishes a shared presentation shell used by the Cruise workspaces.

The shell MUST remain inside the existing DepartureDesk application layout. It MUST NOT introduce a second Cruise-specific sidebar or another application shell.

## 5.1 Header

The standard header identifies the Supplier setup itself rather than an implementation concept such as "Cruise setup."

Example:

```
Celebrity Beyond                                      [Draft]

Celebrity Cruises · SUP-000001 · 7 nights ·
Nov 6–13, 2027 · Eastern Caribbean

                         [More actions ▾] [Review activation]
```

The version state belongs beside the title.

For an ordinary initial draft:

```
Celebrity Beyond [Draft]
```

For a successor:

```
Celebrity Beyond [Draft · Version 2]

Proposed changes to Active Version 1
View active version →
```

For an active version:

```
Celebrity Beyond [Active]
```

## 5.2 Secondary actions

`More actions` owns secondary lifecycle and escape-hatch operations such as:

- Advanced Supplier planning;  
- Create successor draft, when legal;  
- other genuinely secondary lifecycle operations.

Breadcrumbs provide backward navigation. "Back to Suppliers" or "Back to Cruise" SHOULD NOT compete with primary workflow actions.

## 5.3 Shared navigation

Every canonical Cruise workspace uses the same five-area navigation and identifies the current area.

Top-level presentation statuses are limited to:

- **Complete**  
- **Needs attention**  
- **Not started**  
- **Blocked**  
- **Ready to review**  
- **Active**, where appropriate for the activation transition

More precise descriptions belong inside the relevant workspace.

The navigation status is derived presentation state. It is not persisted workflow state.

---

# 6\. Version-context invariants

UX-7 MUST preserve existing Supplier version semantics.

For a successor draft:

- the Active version remains governing until successor activation succeeds;  
- carried Pools refer to the existing active operational inventory;  
- successor presentation MUST NOT imply that carried capacity was copied into a new operational ledger;  
- proposed supplemental inventory is distinct from active inventory;  
- activating the successor makes it governing without rewriting the prior version.

Normal Cruise editing remains draft-oriented where required by the existing commands.

UX-7 MUST NOT introduce a generalized user-selectable version-context parameter.

The server remains responsible for resolving the governing Active version and applicable Draft successor.

---

# 7\. Overview

The Overview is a compact Supplier setup hub.

It MUST NOT reproduce the detailed editors contained in the five workspaces.

## 7.1 Overview content

The Overview contains:

1. shared Cruise header;  
2. five-area navigation;  
3. one derived **Needs attention** region when applicable;  
4. four Supplier summary cards:  
   - Sailing;  
   - Cabin inventory;  
   - Supplier rates;  
   - Agreement;  
5. a visually separate Client-offering handoff.

It does not contain a fifth Activation summary card. Review & activate is already represented by the persistent navigation and primary action.

The original notes identify the current redundancy as four competing readiness/navigation mechanisms and replace them with one attention collection plus compact summaries. :chatgpt-content-reference{index="3"} :chatgpt-content-reference{index="4"}

## 7.2 Attention

Replace artificial single-step recommendations and duplicate maintenance lists with one derived collection such as:

```
AttentionItem = Data.define(
  :code,
  :message,
  :destination,
  :resource_id,
  :advanced
)
```

Example:

```
Needs attention

Supplemental O1 block needs Supplier evidence.       Go to cabin inventory →
Supplemental O1 block needs contracted rates.        Go to Supplier rates →
Amended Supplier agreement needs confirmation.       Go to Agreement →
```

Attention is not readiness authority.

Therefore:

```
attention_items.empty?
```

MUST NOT independently mean that the Supplier version is activation-ready.

## 7.3 Corrective destinations

Once a canonical workspace exists, normal corrective links MUST NOT route back to old Overview anchors.

A known problem routes to its owner:

```
Cabin issue       → Cabin inventory/category
Rate issue        → Supplier rates/category
Agreement issue   → Agreement/focused section
Activation issue  → Review & activate
Unknown shape     → Advanced Supplier planning
```

---

# 8\. Cabin inventory workspace

Cabin inventory is the canonical location for understanding and maintaining the Supplier's cabin inventory.

The normal landing screen is a category/inventory summary rather than the existing batch-add form.

The notes establish this as one perceived workspace even though category creation, editing, removal, and operational inventory changes remain separate operations. :chatgpt-content-reference{index="5"}

## 8.1 Main screen

Example:

```
Cabin inventory

Cabin categories and inventory the Supplier is providing
for this sailing.

3 categories · 24 cabins

                                      [Add cabin categories]

Code  Cabin category                 Sleeps   Inventory     Cabins   Rates
E3    Edge Stateroom with Veranda    Up to 3  Fixed block   8        Contracted  ›
O1    Prime Oceanview                Up to 3  Fixed block   8        Contracted  ›
DI    Deluxe Inside                  Up to 3  Fixed block   8        Missing     ›
```

Rows are the primary interaction.

Do not add several action links to each row. Opening the row enters the focused category state.

## 8.2 Inventory semantics

Numeric and nonnumeric inventory MUST remain distinct.

For numeric inventory:

```
Fixed block
8 cabins
```

For nonnumeric inventory:

```
On request
Quantity not tracked
```

or:

```
Externally managed
Quantity not tracked
```

Nonnumeric inventory MUST NOT be displayed as zero.

## 8.3 Active inventory

For Active numeric inventory, distinguish:

```
Current capacity   12 cabins
Opened with         8 cabins
```

Current active capacity comes from the operational capacity projection.

Original opening quantity remains a separate historical/definition fact.

## 8.4 Successor inventory

A successor MUST distinguish:

```
E3   Edge Stateroom       Carried from active terms
O1   Prime Oceanview      Carried from active terms
DI   Deluxe Inside        Carried from active terms
DI   Supplemental DI      Proposed · 4 cabins
```

Do not add carried active capacity and supplemental proposed capacity together and present the result as current capacity.

Supplemental inventory retains the Supplier category code. Internal labels distinguish separate Resources; the UI MUST NOT invent a Supplier code merely to make it unique.

## 8.5 Category editing

Category editing remains a focused page within the Cabin inventory workspace.

Primary content:

- Supplier category code;  
- category name;  
- maximum occupancy;  
- inventory treatment;  
- opening quantity where numeric;  
- Supplier evidence;  
- notes.

Implementation-heavy Pool facts belong in a secondary Inventory details region.

Removal, when authorized by the existing service, is a destructive secondary action on this focused page.

## 8.6 Add categories

Preserve the existing batch interaction and `SaveCruiseCabinCategoryBatch` behavior.

UX-7 MUST preserve:

- row-level `CreateCruiseCabinCategorySetup`;  
- local validation of all rows before the first write;  
- successful earlier rows after a later failure;  
- unresolved-suffix redisplay;  
- exact row idempotency keys on retry.

Do not replace this with a synthetic all-or-nothing domain transaction.

## 8.7 Inventory maintenance

`Change inventory` belongs only to Cabin inventory.

The normal choice is between:

```
More cabins under the same terms
```

and:

```
Cabins under changed Supplier terms
```

The existing same-terms and changed-terms commands remain authoritative.

---

# 9\. Supplier rates workspace

Supplier rates is the canonical Cruise-level location for Supplier cabin economics.

It consists of:

1. a Cruise-level category economics summary; and  
2. a focused category rate editor.

## 9.1 Rates landing page

Example:

```
Supplier rates

2 contracted · 1 estimate · 1 missing

Code  Cabin category                 Stage        Status   Single    Double    Triple
E3    Edge Stateroom with Veranda    Contracted   Ready    …         …         …       ›
O1    Prime Oceanview                Contracted   Ready    …         …         …       ›
DI    Deluxe Inside                  Estimate     Ready    …         …         …       ›
OS    Owner's Suite                  —            Missing  —         —         —       ›
```

Single/Double/Triple totals SHOULD be shown when the existing evaluator can safely produce them. They MUST come from existing evaluation/preview authority, not duplicated arithmetic in the workspace.

If evaluation is unavailable or unsafe, show the applicable state rather than guessing.

## 9.2 Stage and readiness

Stage and readiness are separate concepts.

**Stage**

- Estimate  
- Contracted  
- —

**Status**

- Ready  
- Needs review  
- Not recorded  
- Advanced

`Estimate · Ready` is valid.

An Estimate is not defective merely because activation ultimately requires Contracted Supplier rates. The overall workspace can therefore need attention while the Estimate itself is a valid, ready Estimate. This distinction is explicitly established in the notes. :chatgpt-content-reference{index="6"}

## 9.3 Focused rate editor

The focused category page owns:

- category selector;  
- Estimate / Contracted stage;  
- component/profile matrix;  
- commission;  
- preview;  
- forecast occupancy;  
- rate review/readiness.

The matrix remains the primary transcription interaction.

## 9.4 Contracted-rate transition

"Record contracted rates from Estimate" is a deliberate transition.

It:

- creates a separate Contracted definition;  
- copies the Estimate;  
- leaves the Estimate unchanged;  
- does not automatically mark Contracted rates ready.

The resulting Contracted schedule requires Staff review.

## 9.5 Commission

The supported normal Cruise methods remain exactly:

- Not provided yet  
- Dollar amount  
- Percentage

Do not reintroduce a fourth "No commission" option.

Percentage commissionability remains shared appropriately across profiles according to the existing rate model.

## 9.6 Forecast occupancy

Forecast occupancy remains clearly secondary:

> Used only to forecast Supplier cost. It does not allocate cabins to Clients.

It remains an independent save operation.

## 9.7 Unsupported rates

If `DetectCruiseSupplierRateShape` determines that the typed Cruise matrix cannot safely round-trip the rate graph, fail closed.

Show the facts and provide:

```
Open Advanced Supplier planning
```

Do not flatten the graph.

---

# 10\. Agreement workspace

Agreement is one coherent Supplier-contract workspace composed of independently saved sections.

The current implementation already has much of this structure, so UX-7 primarily consolidates and simplifies it rather than introducing another Agreement architecture. :chatgpt-content-reference{index="7"}

The five sections are:

1. Agreement  
2. Deposits  
3. Deadlines  
4. Benefits  
5. Policies

Supplier source/reference appears as supporting provenance, not a sixth primary section.

## 10.1 Agreement

Owns:

- contracting Supplier;  
- Supplier group number;  
- group creation date;  
- contract date;  
- confirmation;  
- notes;  
- amendment/supplemental deposit treatment where applicable;  
- correction/history presentation.

Agreement confirmation remains an independent version/revision event.

After confirmation, group reference and contract date are not ordinary mutable fields. Corrections preserve history.

## 10.2 Deposits

Visually combine:

### Initial group deposit

```
$50.00 per opening cabin
Due Oct 13, 2026

Current evaluation
24 applicable opening cabins · $1,200.00
```

The rate and due date are stored.

The applicable quantity and total are a **live evaluation** and MUST NOT be presented as stored snapshot facts.

For all-nonnumeric covered inventory:

```
$50.00 per opening cabin

No opening inventory quantity applies.
All covered cabin categories use nonnumeric inventory.
```

Never show `$0` merely because inventory is nonnumeric.

### Allocated-cabin deposit

Preserve both structured values:

```
$500.00 per allocated cabin
$50.00 attributable credit
```

The normal Cruise editor MUST NOT hide the structured attributable credit.

These two deposits are visually related but remain distinct domain records/terms. :chatgpt-content-reference{index="8"}

## 10.3 Deadlines

Normal recognized Cruise deadlines are:

- Hard Stop;  
- Final Payment.

Hard Stop retains its Supplier wording.

Saving a Hard Stop does not itself release inventory.

Unrecognized requirement structures remain available through Advanced Supplier planning.

## 10.4 Benefits

Benefits include:

- Tour conductor;  
- GAP;  
- Marketing fund.

Normal commission does not belong here; it remains Supplier Rates.

Benefits are informational agreement terms unless later domain functionality explicitly gives them operational entitlement/accrual behavior.

Missing optional terms are neutral.

For example:

```
Marketing fund
Not recorded · Optional
```

does not make Agreement incomplete.

## 10.5 Policies

Policies include:

- payment/card restrictions;  
- cancellation ladder;  
- other supported agreement policy/reference terms.

### Cancellation ladder

Cancellation editing is a focused Agreement state.

The UI presents an ordered list of steps, but a save MUST preserve the existing whole-ladder replacement semantics:

1. load the complete current ladder;  
2. apply add/edit/remove/reorder in memory;  
3. submit the complete ordered ladder;  
4. let the existing command replace the stored list.

Do not introduce per-step domain mutations.

Current list position is transient UI addressing, not durable domain identity.

## 10.6 Generic Deposits & Deadlines UI

Once Agreement owns the recognized Cruise requirements, the generic Cruise Deposits & Deadlines screen is removed from the normal workflow.

Generic Supplier-planning capability MAY remain for Advanced structures.

Activation corrective links MUST route to Agreement focus targets rather than the deprecated normal Cruise requirements screen. The planned migration and eventual deletion sequence are already identified in the notes. :chatgpt-content-reference{index="9"}

---

# 11\. Review & activate workspace

Review & activate is the sole detailed activation surface.

It answers four questions, in order:

1. Is this Supplier setup ready?  
2. If not, what must Staff fix and where?  
3. If ready, what will activation do?  
4. What evidence, values, or acknowledgments are required?

This hierarchy is explicitly established by the UX-7.5 design. :chatgpt-content-reference{index="10"}

## 11.1 Setup checklist

Do not reproduce the detailed Sailing, Cabin, Rates, and Agreement screens.

Instead show a compact checklist:

| Area | State | Summary |
| :---- | :---- | :---- |
| Sailing | Complete | Nov 6–13, 2027 |
| Cabin inventory | Complete | 3 categories · 24 cabins |
| Supplier rates | Complete | 3 contracted |
| Agreement | Complete | Confirmed · requirements recorded |

Each row links to its canonical workspace.

## 11.2 Blocked state

Blockers are primary content.

Example:

```
3 items need attention

Cabin inventory
Supplemental O1 block needs Supplier evidence.      Review cabin →

Supplier rates
Supplemental O1 block needs contracted rates.       Review rates →

Agreement
Amended Supplier agreement needs confirmation.      Review agreement →
```

When authoritative readiness is blocked, do not show the activation form.

## 11.3 Ready versus representable

Preserve the distinction between:

### Authoritative readiness blocked

The Supplier setup has actual readiness blockers.

### Domain-ready but not safely representable by Cruise activation UI

```
Activation requires Advanced Supplier planning

The Supplier setup may be ready, but this Cruise review
cannot safely represent all activation inputs or consequences.

[Open Advanced Supplier planning]
```

`SupplierArrangementActivationReadiness` and Cruise POST representability remain separate authorities.

Do not describe the second state as "not ready." :chatgpt-content-reference{index="11"}

## 11.4 Activation consequences

Consequences are grouped semantically.

Example:

```
What activation will do

CABIN INVENTORY
Establish E3 opening capacity at 8 cabins
Establish O1 opening capacity at 8 cabins
DI remains On request; quantity is not tracked

SUPPLIER REQUIREMENTS
Materialize Initial Deposit from its current evaluation
Materialize Hard Stop
Materialize Final Payment

COMMITMENTS
Open applicable confirmation-triggered commitments
```

Agreement answers:

> What did the Supplier require?

Review & activate answers:

> What will DepartureDesk do with those requirements now?

## 11.5 Successor activation

A successor explicitly states:

```
Draft · Version 2

Active Version 1 remains in effect until activation succeeds.
View active version →
```

Consequences include:

```
Version change

Activating Draft Version 2 will make it the governing
Supplier version.

Active Version 1 remains preserved in history.
```

Activation MUST NOT imply that Version 1 is being edited.

## 11.6 Elapsed requirements

Elapsed requirements remain a special consequential acknowledgment rather than ordinary attention.

Example:

```
Requirement already past due

Initial Deposit — due Sep 20, 2026

Activating these terms will open this requirement as
already overdue.

[ ] I understand this requirement is already overdue
    and want to activate these terms.
```

The signed `CruiseElapsedReviewToken` remains mandatory where applicable.

The token MUST prove the exact elapsed set Staff reviewed for the applicable version.

A checkbox alone is insufficient.

A stale token or newly elapsed requirement MUST force review again.

## 11.7 Confirmation-trigger values

Show activation-time quantity/amount inputs only when required.

Normal Cruise UI SHOULD use Staff-facing units and currency rather than exposing implementation concepts such as money minor units.

If the required trigger shape cannot be represented safely, Cruise POST remains unavailable and Staff is directed to Advanced.

## 11.8 Supplier confirmation evidence

Activation evidence is explicitly separate from Cruise agreement confirmation.

```
Supplier confirmation evidence

Record the evidence supporting activation of these
Supplier terms.

This is separate from confirming the Cruise agreement.
```

Where supported:

```
(•) Use existing evidence
( ) Record new evidence
```

New-evidence fields appear only when selected.

## 11.9 Supplier-issued identifier

Supplier-issued identifier remains a subordinate optional section.

Do not infer the activation identifier from the Supplier group number recorded in Agreement.

Duplicate identifier review remains a consequential interruption using the existing signed acknowledgment/replay behavior.

## 11.10 Activation action

Normal Staff wording:

```
Activate Supplier terms
```

No additional confirmation modal is required when the Review & activate screen itself clearly presents the consequences and evidence.

## 11.11 Activated state

After activation, retain the shared workspace shell.

Example:

```
Celebrity Beyond [Active]

Supplier terms active

Version 2 is now the governing Supplier version.
Activated Sep 29, 2026 · Alex Mariner
```

Do not replace the workspace with an isolated success page.

---

# 12\. Client offering boundary

Client offering is downstream of Supplier setup.

Overview and the activated state MAY expose a visually separate handoff:

```
CLIENT OFFERING

Connected to Cruise — Celebrity Beyond

Supplier changes are not applied to the Client offering automatically.

Open Client service →
Open Client pricing →
```

or, when unconnected:

```
CLIENT OFFERING

Not connected

Connect this Supplier setup to a Client service when ready.
```

Supplier edits, supplemental inventory, successor creation, and Supplier-version activation MUST NOT automatically:

- repoint the Client source binding;  
- change Client pricing;  
- change selectable Client quantity;  
- publish new Client terms.

Those remain explicit Offer Design operations.

---

# 13\. Advanced Supplier planning

Advanced Supplier planning is a compatibility escape hatch.

It is not a sixth Cruise workspace and not a competing normal workflow.

When authoritative Supplier data cannot be represented and round-tripped safely by the Cruise adapter:

- show enough information for Staff to understand the limitation;  
- prevent unsafe typed Cruise mutation;  
- link to Advanced Supplier planning.

UX-7 MUST NOT modify or simplify authoritative structures merely to make them fit the Cruise UI.

---

# 14\. Presentation compilers

Presentation compilers remain read-only derivation.

Expected responsibilities include:

### `CompileCruiseCompositionSummary`

Overview summaries, global attention, and navigation presentation facts.

### `CompileCruiseCabinInventoryWorkspace`

Cabin rows, quantities, evidence posture, rate posture, and cabin-local attention.

### `CompileCruiseSupplierRatesWorkspace`

Category economics summary, stages, readiness, evaluated scenario totals, and rate-local attention.

### Agreement

Reuse the existing Agreement controller/workspace objects unless implementation demonstrates a genuine need for a dedicated compiler.

Do not introduce a compiler merely for architectural symmetry.

### `CompileCruiseActivationReview`

Remains the dedicated activation presentation authority for:

- authoritative readiness;  
- Cruise POST representability;  
- activation inputs;  
- trigger coverage;  
- consequences;  
- elapsed requirements;  
- blocker translation;  
- successor context.

None of these compilers becomes domain authority.

They SHOULD return semantic facts rather than CSS classes, icons, button copy, or rendered URLs.

---

# 15\. Responsive behavior

UX-7 MUST explicitly support narrow screens rather than relying on horizontal scrolling.

At approximately 375px:

- shared header stacks cleanly;  
- five-area navigation remains usable;  
- summary grids stack;  
- desktop tables become compact record cards where necessary;  
- Cabin inventory distinguishes current/opening/proposed quantities without horizontal scrolling;  
- Supplier Rates category summaries show scenario totals vertically;  
- detailed rate matrix uses a deliberate narrow representation;  
- Agreement sections stack;  
- cancellation steps become numbered blocks;  
- Review & activate preserves blocker/consequence hierarchy;  
- relevant action remains adjacent to the fact it operates on.

Desktop and mobile MUST communicate the same domain facts.

---

# 16\. Accessibility

UX-7 MUST ensure:

- all workflow operations are keyboard reachable;  
- focus moves predictably after focused-edit saves/errors;  
- status is not communicated by color alone;  
- badges include textual state;  
- tables have appropriate headers;  
- mobile card transformations retain semantic labels;  
- destructive actions are distinguishable from normal saves;  
- validation errors associate with their relevant fields;  
- disclosure controls expose appropriate accessible state;  
- the persistent workspace navigation identifies the current area.

---

# 17\. Permissions

UX-7 changes presentation, not authorization.

Viewer access remains read-only.

Staff mutation controls appear only where the existing permission, lifecycle, version, and command rules permit the operation.

The absence of a button MUST NOT substitute for server-side authorization.

Advanced access likewise remains governed by existing Supplier-planning permissions.

---

# 18\. Testing contract

Each UX-7 slice tests its presentation responsibility without unnecessarily re-proving previously established domain semantics.

## 18.1 Shared shell

Prove:

- Draft/Active/successor context;  
- five workspace destinations;  
- Viewer versus Staff actions;  
- More actions lifecycle constraints;  
- incompatible shape → Advanced;  
- 375px no page overflow.

## 18.2 Overview

Prove:

- four summaries only;  
- simultaneous attention items;  
- correct destinations;  
- numeric/nonnumeric cabin summary;  
- contracted/estimated/missing/advanced rate summary;  
- optional Agreement terms do not create false attention;  
- activation remains reachable while blocked;  
- Client offering is visually downstream.

## 18.3 Cabin inventory

Prove:

- canonical E3/O1/DI draft;  
- batch creation/retry behavior;  
- numeric versus nonnumeric inventory;  
- active current capacity versus opening quantity;  
- successor carried versus proposed capacity;  
- evidence attention;  
- category removal where authorized;  
- same-terms maintenance;  
- changed-terms supplemental category;  
- no accidental summing of active and proposed capacity.

## 18.4 Supplier rates

Prove:

- Cruise-level category summary;  
- Single/Double/Triple totals from evaluator authority;  
- Estimate versus Contracted;  
- ready Estimate does not become invalid merely because it is an Estimate;  
- Estimate → Contracted copy semantics;  
- three commission methods only;  
- preview;  
- forecast occupancy;  
- readiness;  
- unsupported graph → Advanced.

## 18.5 Agreement

Prove:

- all five conceptual sections;  
- independent mutations remain independent;  
- live Initial Deposit evaluation;  
- mixed numeric/nonnumeric evaluation;  
- all-nonnumeric behavior;  
- allocated-cabin attributable credit;  
- Hard Stop and Final Payment preservation;  
- optional benefits neutral;  
- complete cancellation-ladder replacement;  
- removal of final cancellation step where supported;  
- formatted source/reference;  
- no normal Change inventory control;  
- no normal generic Deposits & Deadlines navigation.

## 18.6 Review & activate

Prove:

- blocked GET does not expose activation form;  
- corrective links target canonical workspaces;  
- ready GET exposes activation form;  
- Viewer cannot POST;  
- authoritative readiness and Cruise representability remain distinct;  
- consequences derive from actual command behavior;  
- signed elapsed review required;  
- stale elapsed review rejected;  
- newly elapsed requirements require re-review;  
- activation inputs survive validation failure;  
- existing/new evidence paths;  
- duplicate identifier review/replay;  
- unsupported activation → Advanced;  
- successful activation returns to Active workspace state;  
- successor activation leaves Client offering unchanged.

---

# 19\. Delivery sequence

Implement UX-7 in these reviewable slices.

## UX-7.1 — Workspace shell and Overview

- shared Cruise header;  
- shared five-area navigation;  
- version context;  
- normalized status vocabulary;  
- derived attention collection;  
- four compact Overview summaries;  
- Client-offering handoff;  
- remove duplicate Overview editors/readiness surfaces.

## UX-7.2 — Cabin inventory

- canonical Cabin inventory landing page;  
- batch Add integration;  
- focused category editing;  
- evidence presentation;  
- active/opening/proposed/nonnumeric distinctions;  
- inventory maintenance integration;  
- canonical redirects.

## UX-7.3 — Supplier rates

- canonical Cruise-level rates workspace;  
- evaluated scenario totals;  
- focused category editor;  
- stage hierarchy;  
- Estimate → Contracted transition;  
- commission;  
- preview;  
- forecast occupancy;  
- readiness;  
- responsive matrix treatment.

## UX-7.4 — Agreement

- shared shell;  
- Agreement / Deposits / Deadlines / Benefits / Policies;  
- focused editing;  
- live deposit evaluation presentation;  
- cancellation ladder;  
- source/reference;  
- remove Change inventory;  
- remove normal generic Deposits & Deadlines navigation;  
- establish stable Agreement corrective targets.

## UX-7.5 — Review & activate

- shared shell;  
- primary readiness state;  
- compact four-area checklist;  
- canonical corrective destinations;  
- grouped activation consequences;  
- elapsed review;  
- confirmation-trigger inputs;  
- Supplier evidence;  
- identifier/duplicate review;  
- Active success state.

## UX-7.6 — Inventory maintenance and Active snapshot polish

Complete presentation cleanup around:

- Active inventory snapshot;  
- same-terms capacity maintenance;  
- changed-terms successor inventory;  
- Active ↔ Draft version navigation;  
- carried versus proposed inventory;  
- removal of transitional inventory-maintenance entry points.

UX-7.6 MUST NOT introduce new inventory semantics.

## UX-7.7 — Closure

Perform final:

- responsive proof;  
- accessibility proof;  
- terminology normalization;  
- dead presentation-code removal;  
- route/link cleanup;  
- CSS cleanup;  
- documentation updates;  
- end-to-end system proof.

---

# 20\. UX-7 closure gate

Before UX-7 is complete, search Cruise:

- routes;  
- controllers;  
- views;  
- helpers;  
- presentation compilers;  
- tests;  
- CSS;  
- interface documentation

for superseded UX-1 through UX-6 presentation paths.

Remove, where no longer legitimately required:

- Overview editing anchors;  
- duplicate workspace editors;  
- duplicate "Next"/"Next steps" presentation;  
- standalone Overview Activation card;  
- transitional later-capacity controls outside Cabin inventory;  
- normal-path Cruise Deposits & Deadlines navigation;  
- activation corrective links to deprecated screens;  
- duplicate version-context implementations;  
- old `Back to Cruise` scaffolding;  
- dead helpers/CSS associated only with replaced presentation.

Do **not** delete:

- authoritative domain commands;  
- generic Supplier-planning functionality needed by Advanced;  
- domain services still used by the new workspaces;  
- historical/version records;  
- compatibility escape hatches.

Final system proof SHOULD cover at least:

- 375px;  
- 768px;  
- 1280px;  
- 1400px;  
- keyboard navigation;  
- Viewer and Staff;  
- initial Draft;  
- Active Cruise;  
- successor Draft;  
- incompatible/Advanced shape;  
- blocked activation;  
- successful activation.

---

# 21\. Overall exit criteria

UX-7 is complete when a Staff user can move through:

```
Overview
   ↓
Sailing
   ↓
Cabin inventory
   ↓
Supplier rates
   ↓
Agreement
   ↓
Review & activate
   ↓
Active Supplier terms
```

without needing to understand which internal Supplier record type owns each fact or encountering duplicate normal-path editors.

Specifically:

- each Supplier concern has one canonical normal Staff workspace;  
- the shared Cruise shell is used consistently;  
- the five-area navigation is persistent and authoritative for navigation, but not persisted as workflow state;  
- Overview is a summary rather than a second editor;  
- attention routes directly to the appropriate corrective workspace;  
- active, opening, carried, and proposed inventory remain semantically distinct;  
- Supplier rates preserve Estimate/Contracted and evaluator authority;  
- Agreement presents one coherent Supplier contract while retaining independent mutation semantics;  
- Review & activate is the sole detailed activation surface;  
- authoritative readiness and Cruise activation representability remain distinct;  
- elapsed activation review remains cryptographically/version bound through the existing signed-token mechanism;  
- unsupported structures fail closed to Advanced;  
- Client offerings remain isolated from Supplier changes until explicitly changed through Offer Design;  
- no new Supplier-domain, inventory, rate, Agreement, readiness, activation, or Client-service semantics are introduced.

The end state should make the existing domain model **easier to understand without making it less precise**.  
