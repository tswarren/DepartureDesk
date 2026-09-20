# M3E — Supplier operational control

**Status:** Accepted 2026-09-18. M3E.0 satisfied; M3E.1–M3E.5, M3E.5R, M3D remediations, and M3E.6a shipped. Remaining implementation is **M3E.6b–M3E.7b**. **M3E is not yet fully shipped** until M3E.7b. [M3E.0](m3e0-m3d-closure-gate.md) is satisfied (2026-09-19): final M3D correctness QC is green at pinned base `344ab86`. Production M3E code began with M3E.1 from that verified base (or a descendant on `main`).
**Parent:** [M3 — Supplier planning](m3-supplier-planning.md)  
**ADR:** [ADR 0013 — Supplier operational commitments, Deadlines, exposure, and Arrangement ending](../adr/0013-supplier-operational-commitments-deadlines-exposure-and-ending.md)  
**Prerequisite:** Shipped M3D through M3D.9; [M3E.0](m3e0-m3d-closure-gate.md) M3D closure gate satisfied  
**Decision register:** [M3E Decision Register](m3e-decision-register.md)  
**M3D closure gate:** [M3E.0](m3e0-m3d-closure-gate.md)

## Goal

Complete the Supplier-side operational-control layer over shipped M3A–M3D:

- evolve M3D openings into source-shaped, constrained commitment openings;
- resolve and correct immutable Supplier commitment openings through append-only dispositions (including `released`);
- define and materialize Supplier Deposit Requirements and Deadlines from exact-version definitions;
- record Staff planning milestones that advance earlier-of Deadlines without Traveler records;
- refresh due/overdue, exposure, and Needs-attention projections at time boundaries without creating domain events from elapsed time;
- calculate qualified, source-traceable Supplier exposure;
- derive Needs-attention and Accepted-exception views;
- provide Arrangement detail plus Departure rollups; and
- end a Supplier Arrangement through a previewed, blocker-safe, atomic workflow.

The implementation must preserve strong tenancy, ownership, version, audit, atomicity, idempotency, and database invariants without forcing Staff to manage persistence artifacts.

## Authority and acceptance

This plan is Accepted implementation authority for M3E. ADR 0013 and this plan were Accepted together on 2026-09-18. Production M3E code must not begin until the prerequisites above are met.

Accept also amended:

- parent M3 “manual opening” language in the slice table and glossary;
- ADR 0012 via a dated supersession note (historical decision body retained; not silently rewritten);
- `docs/terminology.md` opening vocabulary; and
- the ordinary Supplier inactivation open-state rule (blocks only commitments whose current event-derived state is open).

Authority order:

1. accepted ADRs 0005 and 0008–0013;
2. this Accepted slice;
3. the Accepted M3 parent;
4. current architecture, terminology, interface, permission, and audit catalogs.

Draft or future commercial plans remain context only. When this plan makes a later M3E boundary more specific, this plan controls. It does not reopen shipped M3A–M3D decisions except where Accept explicitly amends inactivation and opening wording as named above.

## Preconditions

Before M3E.1 begins:

- M3D.9 is shipped on `main`;
- final M3D correctness QC reports no release-blocking finding ([M3E.0](m3e0-m3d-closure-gate.md) documents this exit);
- ADR 0013 and this plan are Accepted (promoted 2026-09-18);
- the implementing branch starts from the [M3E.0](m3e0-m3d-closure-gate.md) pinned verified `main`; and
- `AGENTS.md` and `docs/README.md` name M3E as current accepted work without describing it as shipped.

There is no parallel implementation waiver.

## Scope

### In scope

- source-shaped commitment opening migration from M3D confirmation-shaped rows;
- append-only commitment dispositions including `released`, plus reopening while the Arrangement is not ended;
- immutable shared-evidence coverage sets and correction;
- ordinary inactivation blocking only current open commitments;
- version-owned Deposit Requirement Definitions;
- materialized Deposit Requirements and recalculation adjustments;
- full-current-requirement Staff attestation outside DepartureDesk;
- version-owned Deadline Definitions and immutable occurrences;
- actionable and informational Deadline semantics;
- due/overdue, exposure, and Needs-attention projection catch-up without time-created domain events;
- Staff-recorded planning milestones (`SupplierPlanningMilestoneOccurrence`);
- M3D.7 freeze extension to new exact-version definition families;
- exact-version successor reconciliation;
- qualified Supplier exposure components and summaries;
- deterministic Needs-attention and Accepted-exception projections;
- Arrangement working surfaces and Departure rollups;
- terminal Arrangement ending with safe selectable cascades; and
- scenario, concurrency, query, accessibility, responsive, and regression proof.

### Explicit non-goals

- Client demand, Travelers, passenger-name records, Trip allocations, Client Charges, or Client payments;
- Supplier Obligations, invoices, Payments, applications, refunds, receivables, or settlement;
- fulfillment, dispatch, rooming-list content, traveler-name content, or accessibility fulfillment details;
- Communications, email sending, file upload, or document management;
- Cancellation Cases, penalty calculations, claims, or cancellation accounting;
- earned or received commission;
- general-ledger export or accounting posting;
- foreign-exchange rates, translation, or cross-currency totals;
- Agency-wide operations dashboard;
- free-form rule/formula builders;
- unrestricted manual commitment opening;
- scheduled time creating authoritative domain events (commitment openings, dispositions, deposit materializations, capacity events, Reservation responses, or confirmations);
- post-ending reopen as an ordinary escape hatch;
- force-ending an Arrangement; and
- M3 milestone-wide acceptance, which remains M3F (including the [M3F supplier-planning task-flow backlog](m3-supplier-planning.md#m3f-supplier-planning-task-flow-backlog); M3E.7a owns defects in M3E’s own consequential forms only).

## Product boundary

DepartureDesk records, calculates, explains, and controls Supplier planning. It does not pretend to execute Supplier bookings, transfer money, fulfill services, or decide externally controlled facts.

The product must distinguish:

- a contractual Deposit Requirement from a Payment;
- a Staff attestation from proof of money movement;
- a Supplier commitment from an accounting obligation;
- gross guaranteed exposure from expected net cost;
- a Deadline from a service date;
- a planning milestone from a Traveler record;
- accepted risk from completed work; and
- Arrangement ending from cancellation, fulfillment, or settlement.

## Interaction compression contract

### Governing invariant

> Controls are enforced at command and database boundaries; the interface exposes business decisions, not persistence mechanics.

No ordinary Staff surface may require manual management of:

- Agency/Departure/Arrangement/version ownership fields;
- evidence-coverage membership rows;
- disposition lineage;
- calculation component snapshots;
- Deadline replacement lineage;
- opening-shape foreign-key wiring;
- projection catch-up or rebuild identities;
- idempotency records;
- exposure projection components; or
- Needs-attention projection rows.

One user action may create several immutable records atomically. The command result and audit must still make every consequence recoverable.

### Three levels of interaction friction

| Level | Uses | Contract |
| --- | --- | --- |
| Invisible | tenancy, ownership, exact-version checks, locks, idempotency, lineage, projection rebuilds, database constraints | Automatic; no Staff input. |
| Lightweight confirmation | satisfy compatible commitments, add a standard Deadline, define a standard deposit, attest full deposit handled externally, record a name-assignment planning milestone | Compact guided form or one review-and-submit step. |
| Deliberate confirmation | waive, release, reopen, revoke evidence, acknowledge already-overdue activation, end Arrangement | Focused preview, reason/acknowledgment, and explicit submit. |

### Page grammar

The Arrangement workspace remains display-first and calm:

1. identity and lifecycle summary;
2. ordered **Next action** panel;
3. compact Supplier status summary;
4. Needs attention;
5. Accepted exceptions;
6. upcoming/actionable Deadlines;
7. exposure summary where authorized;
8. existing Item cards and planning sections; and
9. recent operational history with technical provenance behind disclosures.

The default state shows facts, not persistent editors. Use dedicated GET forms for substantial definitions and focused confirmation pages for consequential transitions. At most one inline editor or composer may be open.

Common actions are visible. Waive, release, reopen, revoke coverage, inspect calculation, and end Arrangement are secondary or lifecycle actions with accurate labels. Do not label a business cancellation action merely **Cancel**.

### Interaction budgets

These are acceptance goals, not permission to weaken validation:

- Satisfy a compatible group of commitments from one Supplier evidence fact: one coverage review and one submit.
- Confirm a full current Deposit Requirement handled externally: checkbox, required note, submit.
- Record `names_assigned_to_supplier`: governed scope, occurrence time, optional note; one submit.
- Add a standard Deadline: choose template, provide missing business date/source facts, save.
- Add a standard deposit: choose calculation shape, choose business sources, preview, save.
- Activate with no exceptional M3E consequence: no extra M3E step beyond the existing activation checklist.
- Activate with already-elapsed occurrences: one exception-focused acknowledgment section.
- End a clean Arrangement: review and confirm.
- End with safe cascades: one review screen; only unresolved exceptions require separate work.

System tests must prove the compressed path, not only the availability of individual low-level commands.

## Commitment lifecycle contract

### Outcomes

Closing outcomes are exactly:

- `satisfied`;
- `released`;
- `waived`;
- `cancelled`; and
- `superseded`.

Overdue is derived open state, not an outcome. `released` must not be collapsed into `cancelled` or `waived`.

### Proof and authority

| Outcome | Meaning | Required proof | Authority |
| --- | --- | --- | --- |
| Satisfied | Required action occurred | Compatible evidence coverage or a specifically authorized Staff attestation | Existing Arrangement-management permission |
| Released | Supplier or contract released the Agency from the requirement | Compatible Supplier/contract release evidence | Existing Arrangement-management permission |
| Waived | Authorized Agency user accepts the unmet requirement | Required reason and accepted-risk acknowledgment | Existing elevated override permission |
| Cancelled | Governed work no longer applies | Compatible lifecycle event that ended the governed work | Permission for that lifecycle command |
| Superseded | A replacement commitment governs | Exact compatible replacement commitment | Permission for the replacing command |

Every disposition records exact owner/version provenance, actor, occurred/effective time, recorded time, and idempotency identity.

### Reopening

`ReopenSupplierCommitment` appends one reopening event against the exact current disposition. It requires a reason and ordinary Arrangement-management authority. It rejects:

- an already-open commitment;
- a noncurrent disposition;
- cross-owner or cross-version targets;
- an ended Arrangement (no ordinary reopen after ending; privileged historical correction requires a later, separately accepted design); and
- conflicting same-key payload.

### Open-state inactivation blocker

Ordinary `ChangeSupplierStatus` inactivation blocks only commitments whose current event-derived state is open, under lock with a final authoritative recheck. Terminal dispositions cease blocking. Forced inactivation continues to preserve openings and performs no disposition. Accept amends M3D’s “every commitment row blocks” rule accordingly.

### Evidence coverage

The common evidence workflow:

1. loads compatible open commitments from the current business context;
2. preselects the compatible candidate set;
3. lets Staff confirm or narrow that set once;
4. binds the exact set and evidence to the idempotency payload;
5. creates one immutable coverage set/link; and
6. creates one disposition per member atomically.

The UI does not present one evidence-link control per commitment.

Exact-member disqualification and whole-coverage revocation are separate confirmation workflows. Whole revocation previews every commitment that will reopen and rolls back completely on any incompatibility.

### Definition-driven openings

M3E does not expose a generic **Add commitment** form against an activated Arrangement.

`SupplierCommitment` evolves into a **source-shaped** immutable opening record. Making confirmation or trigger foreign keys merely nullable is insufficient. Every commitment carries a closed `opening_kind`. Database checks enforce exact, non-mixed shapes. Loose polymorphic `source_type` / `source_id` is rejected on authoritative records. `deposit_requirement` binds exactly one tranche—not “requirement or adjustment.”

| Opening kind | Required authority |
| --- | --- |
| `confirmation_trigger` | Existing confirmation plus trigger-definition pair (shipped M3D shape) |
| `deposit_requirement` | Exactly one immutable deposit requirement tranche |
| `deadline_requirement` | Exact Deadline occurrence plus commitment-definition line |

Each shape has required source-specific foreign keys, a check prohibiting incomplete or mixed shapes, a source-specific unique index for idempotency, and exact-version/ownership constraints. Existing M3D rows migrate losslessly to `opening_kind = confirmation_trigger`. Authority shapes such as `contracted_unit_rate_times_confirmed_quantity` remain intact under that kind.

New openings arise only from:

- activation materialization;
- Staff-recorded planning milestones;
- deposit materialization or adjustment; or
- other **explicit** Staff commands that name complete authoritative inputs—

not from elapsed time alone.

Draft workspaces may guide Staff in defining the future requirement. The activated command opens it only from complete authoritative inputs. Accept superseded parent / ADR 0012 / terminology “manual opening” wording via dated supersession notes.

## Deadline contract

### Definitions

A Deadline Definition belongs directly to Agency, Departure, Arrangement, and exact Arrangement version. It records:

- stable type from this initial closed catalog plus `other` with required label: `deposit_due`, `option_or_release_date`, `rooming_list_due`, `legal_names_due`, `final_count_due`, `final_schedule_or_departure_time_due`, `cancellation_cutoff`, `accessibility_confirmation_due`, `other`;
- actionable or informational kind;
- closed rule shape and normalized parameters;
- date-only or local-date-time precision;
- explicit/inherited IANA time-zone source;
- one shared or named per-source cardinality;
- explicit coverage links;
- Agency-default or definition-specific warning lead time; and
- optional commitment-definition lines for actionable openings (`opening_kind = deadline_requirement` when materialized through an explicit command).

Draft create/update/remove routes exist only under the sole editable draft version. Activated and superseded definitions are immutable in Rails and PostgreSQL. [M3D.7](../m3d7-activated-definition-immutability.md) freeze rules extend to these families.

### Guided authoring

The form starts with business templates, not fields representing internal rule nodes. Initial templates include:

- fixed date;
- fixed local date and time;
- N days before/after a selected supported date;
- N hours before/after a selected supported timestamp;
- earlier of two supported rules; and
- later of two supported rules.

Supported anchors include Staff-recorded planning milestones (for example `names_assigned_to_supplier`). The summary must render a business-readable sentence and example result before save. Advanced calculation details live under disclosure. Required inputs never hide in a closed disclosure.

### Materialization

Materialization is append-only and exactly-once for one definition/trigger/source expansion identity. It snapshots rule inputs, resolved zone, precision, coverage, calculation result, and predecessor occurrence when replacing.

Date-only and exact-time overdue semantics follow ADR 0013. Application and PostgreSQL constraints reject a row that carries both incompatible precision shapes or neither.

An actionable occurrence may govern one or more commitments opened through explicit materialization. An informational occurrence has none and may not acquire a disposition or blocker after creation.

### Replacement

An unelapsed occurrence may be superseded by a compatible successor occurrence. An elapsed occurrence remains historical. Commands may not UPDATE its calculated date/time, coverage, precision, or zone.

### Time-boundary projection catch-up

This plan **retains** the parent M3 rule: passage of time must not create capacity events or change commitments. Allowing scheduled Deadline processing to open commitments, materialize deposits, or emit capacity events would require an explicit parent architecture amendment—not ADR 0013 alone.

Therefore:

- Activation and explicit Staff commands (deposit/tranche materialization, Deadline materialization) may create authoritative domain events. Planning milestones normally replace unelapsed earlier-of Deadlines rather than first-creating requirements.
- A known future contractual capacity release may be recorded **in advance** as a future-effective capacity event through the canonical capacity command.
- Reaching a Deadline boundary may change **derived** due/overdue status, exposure qualification, and Needs-attention visibility.
- Scheduled catch-up and synchronous rebuilds may refresh those projections under lock. Retries return the existing projection result.
- Time alone must not create a new authoritative domain event.

A delayed projection rebuild may not leave expired due/overdue or exposure visibility stale for consequential reads. Affected commands catch up projections first. Failure behavior:

- deterministic invalidity records no partial projection write and surfaces a typed Needs-attention finding where applicable;
- retryable infrastructure failure leaves the catch-up eligible for retry;
- same-key replay returns the existing projection result; and
- no failure invents a disposition or silently opens a commitment.

## Planning milestones contract

M3E adds a closed-catalog `SupplierPlanningMilestoneOccurrence` family for operational facts that are not Traveler or passenger-name records.

The initial catalog includes at least `names_assigned_to_supplier`.

A milestone occurrence records only:

- exact governed scope;
- occurrence date or time;
- actor;
- optional note and evidence; and
- idempotency identity.

It must **not** store traveler identities or names.

Recording a milestone is an explicit Staff command. For already-materialized earlier-of deposits, it normally **replaces an unelapsed Deadline** effective at the milestone time; it does not open a duplicate commitment or first-create the requirement. If recorded after the fallback Deadline has elapsed, that elapsed Deadline remains historical and overdue. This preserves the Celebrity scenario without introducing M5 Traveler concepts.

## Deposit Requirement contract

### Definitions and guided shapes

A Deposit Requirement Definition belongs to one exact Arrangement version and has explicit currency and coverage.

The UI offers exactly these initial amount shapes:

- **Fixed amount**;
- **Per unit**;
- **Percentage of selected costs**; and
- **Balance to target**.

“Per cabin” and similar quantity language map through **explicit cost or coverage sources**, ordinarily `resource_units`. M3E does not add a new capacity measurement basis.

The UI offers the accepted Deadline rule templates (including planning-milestone anchors) and renders a sentence such as:

> 15% of guaranteed room cost is due on Arrangement activation.

or:

> Final deposit is a **cumulative $500 target** (after a handled $50 initial, $450 remains), due at the earlier of names assigned to supplier or March 11, 2027. Activation materializes the tranche with the March 11 Deadline; a pre-deadline name-assignment milestone replaces that Deadline.

No formula syntax or JSON is exposed.

### Calculation

Money uses integer minor units and explicit currency. Quantity/rate precision follows ADRs 0001 and 0011. Percentage definitions explicitly select aggregate-base or per-source rounding.

Materialization stores component rows sufficient to reproduce the result. It creates an immutable **deposit requirement tranche**, one operational commitment (`opening_kind = deposit_requirement` referencing that tranche), Deadline link, exposure components, and result root in one transaction—only through an **explicit** materialization command (typically activation or Staff), not elapsed time alone. Uniqueness is one commitment per tranche. Pre-satisfaction adjustments change the open tranche’s derived amount; post-satisfaction positive adjustments create a new tranche and commitment.

### Adjustments

Input changes append one recalculation result and zero or more adjustment components. Current required amount is derived; prior snapshots remain immutable.

- Positive change before satisfaction updates the open current requirement through derived adjustment state without rewriting the opening.
- Positive change after satisfaction opens a new incremental commitment.
- Negative change reduces exposure but creates no refund/receivable.
- A zero result is explicit and must not be confused with an unknown calculation.

### Earlier-of fallback (Celebrity)

1. Activation materializes the deposit tranche, commitment, and March 11 fallback Deadline.
2. Before March 11, `names_assigned_to_supplier` replaces the unelapsed Deadline at the milestone time.
3. No duplicate commitment is opened.
4. After March 11, the elapsed Deadline remains historical and overdue.
5. Amount-basis changes follow tranche adjustment rules.

### Staff attestation


The action is labeled **Confirm handled outside DepartureDesk**. It requires:

- the exact current requirement fingerprint;
- a checkbox confirming the complete current amount was handled externally;
- a required note;
- actor and recorded time; and
- idempotency key.

The surface may display the amount and currency but must not collect a partial applied amount, payment method, cash account, or allocation. Successful attestation creates the permitted satisfaction disposition and no accounting record.

## Exposure contract

### Bands and measures

Exposure components are qualified as `guaranteed`, `contingent`, or `forecast`. Each component retains:

- Agency, Departure, Arrangement, governing version;
- source type and stable source ID;
- qualification reason/key;
- gross minor units and currency;
- expected commission minor units where deterministically calculable;
- expected-net minor units;
- effective/observed time; and
- source fingerprint.

Summaries group by Arrangement, band, and currency. Departure rollups aggregate only like band and currency. Unlike currencies remain separate.

Guaranteed, contingent, and forecast are alternative qualifications of a source position and are not added together as separate liabilities.

### Missing inputs

Unknown or incomplete calculations emit typed incomplete components/findings. They never persist or render as zero. The summary distinguishes:

- known zero;
- known amount;
- partially known; and
- unknown.

### Commission

Expected commission nets only within the same source, band, and currency. Gross remains primary. No field or label states earned, received, settled, payable, or paid.

### Projection source locators

Authoritative M3E records may not use generic polymorphic source relationships. Rebuildable projection rows may store a constrained closed-catalog `source_kind` and stable source UUID for identity and drilldown, provided they retain direct Agency/Departure/Arrangement ownership, are rebuilt only from authorized source loaders, and are never used as authority for a command or invariant.

### Projection lifecycle


Affected consequential commands rebuild the Arrangement projection synchronously under the same transaction and locks. Rebuild is deterministic from authoritative source records. Time-boundary catch-up refreshes derived visibility only; it does not invent source events.

The repair operation:

- may run for one Arrangement or bounded Agency batch;
- replaces only derived projection rows;
- never alters immutable source history;
- is idempotent; and
- emits no ordinary success audit unless current repository policy explicitly requires repair auditing.

## Needs-attention and Accepted-exception contract

### Slice boundary

**M3E.1** ships disposition controls plus simple Open / Accepted-exception views driven by disposition state. The cross-domain detector catalog and Departure attention rollup ship in **M3E.5**.

### Findings

Finding identity is stable by detector key and exact subject/source identity. Projection rows carry display-safe reason data and deterministic visibility boundaries.

The initial detector catalog (M3E.5) includes:

- open commitment without a future actionable Deadline;
- actionable commitment due soon;
- actionable commitment overdue;
- Deadline materialization incomplete/failed;
- Deposit Requirement calculation incomplete/failed;
- exposure unknown/incomplete;
- unresolved M3D Reservation-response scope; and
- capacity state violating or relying on accepted override.

One root condition produces one finding even when visible at both Arrangement and Departure levels.

### Presentation

Group findings by the business action that resolves them, not by detector implementation. Each row shows:

- concise required action;
- affected Item/Occurrence/Reservation where applicable;
- Deadline or age;
- material consequence summary; and
- one primary path to resolve or inspect.

Do not render a separate warning card for every persistence record.

Waived commitments move to **Accepted exceptions** with outcome, reason, actor, date, governed scope, and reopen action where permitted. They do not remain in Needs attention. Released commitments leave Needs attention under their own outcome labeling; they are not Accepted-exception waivers.

### Timing configuration

Agency default warning timing and definition override use most-specific-wins behavior. Changing timing rebuilds affected projections but does not replace the contractual occurrence.

## Arrangement-ending contract

### Ending reasons

Ending reasons use this initial closed catalog plus `other` with a required label and note:

- `planning_concluded`;
- `agreement_expired`;
- `not_proceeding_no_live_commitment`;
- `replaced` (requires an exact replacement Arrangement link);
- `duplicate_or_entered_in_error`; and
- `other` (required label and note).

### Eligibility and blockers

Ending evaluates authoritative live governing state after catching up due projections. Named blockers include:

- open commitments not selected for a permitted cascade;
- pending or unresolved Supplier Reservation activity requiring its own workflow;
- remaining future capacity requiring explicit withdrawal/release;
- unelapsed actionable Deadlines that still govern an open commitment or another live transition (not Deadlines linked only to terminal commitments);
- future guaranteed or contingent exposure that would remain governing;
- an un-abandoned draft successor; and
- another pending lifecycle transition.

Past events and settled historical facts do not block merely because they exist.

### Preview

`PreviewEndSupplierArrangement` returns:

- ending reason choices and replacement requirement where applicable;
- named blockers with safe resolution paths;
- eligible candidates from the closed cascade catalog below;
- required informational-Deadline supersessions;
- exposure and Deadline consequences;
- records that remain historical; and
- a short-lived signed/durable digest token.

Safe candidates may be preselected when their consequence is unambiguous, but the screen must clearly distinguish required, selected, and unavailable actions. Technical IDs remain hidden.

Cascades may **not** satisfy, release, or waive commitments, fabricate Supplier responses, alter confirmed Reservations, eliminate guaranteed exposure, or rewrite evidence.

### Closed cascade catalog

Exact permitted cascades:

1. Cancel an eligible open commitment because the governed work is ending.
2. Withdraw eligible future capacity through the canonical capacity `withdrawn` command.
3. Apply a previously authorized Supplier capacity release through the canonical capacity `released` command (not a commitment `released` disposition).
4. Abandon an unactivated draft successor.
5. Cancel or supersede an unelapsed actionable Deadline only together with its governed open commitment.
6. Automatically supersede future informational Deadlines with ending provenance.

Excluded: satisfaction, commitment release, or waiver; Reservation responses; removal of guaranteed exposure; fabricated evidence; changes to confirmed Reservations.

### Submit

`EndSupplierArrangement` binds reason, replacement link, exact selected cascade set, acknowledgments, and preview digest into the idempotency payload.

Under lock it:

1. reloads and authorizes the Agency actor;
2. catches up due projection boundaries;
3. validates the preview digest and expiry;
4. executes selected cascades through already-locked canonical operations;
5. supersedes future informational occurrences with ending provenance;
6. re-evaluates every blocker;
7. records the immutable ending transition and Arrangement lifecycle change;
8. rebuilds exposure/attention projections;
9. records one success audit and durable result root; and
10. commits atomically.

Any failure rolls back all consequences. A changed candidate set returns conflict and a refreshed-preview path; it never silently extends the user's selection.

### Ended behavior

Ended Arrangements remain readable and searchable as history. They expose no ordinary mutation controls. New version, Reservation, capacity, commitment, Deposit, Deadline, planning-milestone, and projection-mutating writes that invent domain events are rejected in Rails and protected by database invariants where direct persistence could violate the terminal boundary.

Reopening a commitment after ending is rejected. Privileged historical correction requires a later, separately accepted design.

## Surfaces and routes

Names may follow Rails conventions, but complete ownership must remain in every route.

Proposed surfaces:

```text
GET  /departures/:departure_id/arrangements/:arrangement_id/commitments
POST /departures/:departure_id/arrangements/:arrangement_id/commitments/dispositions
POST /departures/:departure_id/arrangements/:arrangement_id/commitments/:id/reopen
POST /departures/:departure_id/arrangements/:arrangement_id/evidence_coverages/:id/revoke

GET/POST/PATCH/DELETE Deadline Definitions under exact draft version context
GET/POST/PATCH/DELETE Deposit Requirement Definitions under exact draft version context

POST /departures/:departure_id/arrangements/:arrangement_id/planning_milestones
POST /departures/:departure_id/arrangements/:arrangement_id/deposit_requirements/:id/attest
GET  /departures/:departure_id/arrangements/:arrangement_id/exposure
GET  /departures/:departure_id/arrangements/:arrangement_id/end
POST /departures/:departure_id/arrangements/:arrangement_id/end

GET  /departures/:departure_id/supplier_planning
```

Use GET for previews/forms, POST for immutable events and consequential transitions, PATCH for mutable draft definitions only, and DELETE only for eligible unpublished draft definitions. Full-page fallback is required for every Turbo-enhanced path.

## Persistence and database contract

Exact table names may be refined before the first migration, but the accepted topology must contain equivalent durable concepts:

- source-shaped commitment openings with closed `opening_kind`, shape checks, and source-specific unique indexes;
- immutable commitment disposition and reopening events;
- immutable evidence coverage set, membership, link, disqualification, and revocation facts;
- version-owned Deposit Requirement Definitions and explicit coverage links;
- immutable Deposit Requirement materializations and adjustments;
- immutable external-handled Staff attestations;
- version-owned Deadline Definitions and explicit coverage links;
- immutable Deadline Occurrences, replacements, and links;
- closed-catalog `SupplierPlanningMilestoneOccurrence` records;
- rebuildable exposure component/summary projections;
- rebuildable Needs-attention projections (including catch-up identities for projection rebuild, not time-created domain events); and
- immutable Arrangement-ending result/manifest.

Required persistence rules include:

- UUIDv7 primary keys and direct Agency/Departure/Arrangement ownership;
- composite same-owner/exact-version foreign keys for every cross-record relationship;
- no generic polymorphic owner or source relation on authoritative records; rebuildable projections may use constrained `source_kind` + source UUID locators that are never command authority;
- constrained readable state/type strings;
- integer minor units and explicit currency for money;
- numeric quantity/rate columns only with explicit precision/scale;
- named checks for opening-shape, outcome-proof, precision, rule-shape, amount-shape, and reason requirements;
- uniqueness for definition lineage, materialization identity, current replacement, opening source identity, and projection component identity;
- immutable historical rows protected in Rails and PostgreSQL;
- insert-only replacement/supersession semantics where one current row must be retired;
- ended-Arrangement insertion guards for prohibited child families; and
- migrations reflected in `db/structure.sql`, never edited there manually.

Model validation alone is insufficient for immutable history, same-owner compatibility, exact-version ownership, terminal-state protection, opening shapes, or exactly-once materialization.

Do **not** persist consequence-execution identities for time-created domain events. Projection catch-up and rebuild identities are permitted.

## Command, lock, and concurrency contract

### Canonical lock order

Extend the shipped M3D order; do not create a second M3E order. After pre-transaction authorization:

1. Agency; recheck active.
2. Actor reloaded through Agency; recheck active and permission.
3. Affected Suppliers in UUID order.
4. Departure; recheck lifecycle.
5. Supplier Arrangement.
6. Predecessor/current version, then target draft version in version-number/UUID order.
7. Stable Item/Occurrence/Resource identities and exact definitions in parent/UUID order.
8. Cost records in shipped stable order.
9. Capacity records in shipped stable order.
10. Reservation, revision, scopes, projection, then events in shipped stable order.
11. Commitment openings (by opening kind/source), disposition history, and evidence coverage in stable order.
12. Deadline Definitions, occurrences, and links in stable order.
13. Deposit Definitions, materializations, adjustments, and attestations in stable order.
14. Planning milestone occurrences in stable order.
15. Existing exposure and attention projection rows in stable source order.
16. Command idempotency row after its owning aggregate, except an already-declared create-command slot exception.
17. Insert result, audit, and projection rows after existing locks.

Nested operations receive already-locked records and never reacquire an earlier lock. Projection rebuild/catch-up uses this same order and never invents domain events.

### Idempotency

Reuse `AgencyCommandIdempotencyKey` with command-specific scopes. Fingerprints include every consequential target, coverage member, evidence ID, reason, note, acknowledgment, selected cascade, calculation source/fingerprint, occurrence, milestone, opening kind/source, and preview digest.

Multi-result commands point to a durable result/manifest root. A JSON list is not the only authoritative result.

Same key/same payload returns `:replayed`. Same key/different payload returns conflict. Failed transactions leave no success result.

### Required races

At minimum prove genuine multi-connection races for:

- two dispositions of one commitment (including `released`);
- disposition versus reopening;
- reopening versus Arrangement ending;
- shared evidence coverage versus a new/incompatible commitment candidate;
- exact-member disqualification versus whole-coverage revocation;
- two materializations of one definition/trigger/source identity;
- planning milestone versus concurrent deposit/Deadline materialization;
- recalculation versus Staff attestation;
- positive adjustment versus concurrent second adjustment;
- successor activation versus Deadline/Deposit materialization;
- projection catch-up versus source mutation;
- projection rebuild versus concurrent catch-up;
- ending preview versus new blocker/cascade candidate;
- ending versus Reservation response, capacity event, successor creation, and Supplier inactivation; and
- same-key retry versus first execution for every durable M3E command.

Do not invent races for scheduled consequence executions that create domain events; that path is out of scope while the parent automation rule stands.

## Authorization, tenancy, and audit

- Every load begins through `Current.agency`; cross-Agency identifiers return not found.
- Request `agency_id` never establishes tenancy.
- Existing permissions govern ordinary Arrangement mutation, elevated override, and Supplier-cost visibility.
- Each ending cascade checks its own permission in addition to end authority.
- Viewer sees permitted facts and no mutation control or hidden mutation field.
- Audit successful consequential commands in the same transaction; expected failures are not audited.
- Use `SupplierArrangement` as the audit subject for Arrangement-level definition, exposure, milestone, and ending actions. Use the shipped `SupplierReservation` subject only for Reservation-owned consequences.

Proposed audit actions:

- `supplier_arrangement.commitments_disposed` (covers satisfy, release, waive, cancel, supersede as detail)
- `supplier_arrangement.commitment_reopened`
- `supplier_arrangement.evidence_coverage_revoked`
- `supplier_arrangement.deadline_definition_created|updated|removed`
- `supplier_arrangement.deposit_definition_created|updated|removed`
- `supplier_arrangement.planning_milestone_recorded`
- `supplier_arrangement.deposit_attested_external`
- `supplier_arrangement.ended`

If release warrants a dedicated action distinct from generic disposition, add `supplier_arrangement.commitment_released` in the same slice that first emits it. Do **not** audit `deadline_consequence_applied` as a domain-event creator. Projection rebuild/catch-up may omit ordinary success audit or use a narrowly named repair action only if repository policy requires it—never as a substitute for a time-created commitment or capacity event.

Extend closed permission/audit catalogs in the same slice that first emits each action.

## Error and recovery contract

Expected command outcomes use stable typed codes and business-readable messages. At minimum distinguish:

- `:invalid` for structurally or contractually invalid input;
- `:forbidden` only where repository HTTP policy exposes it; tenant misses remain not found;
- `:conflict` for stale preview, stale fingerprint, changed candidate set, or conflicting idempotency payload;
- `:blocked` with named blocker codes and safe resolution paths;
- `:replayed` for same-key/same-payload replay; and
- `:succeeded` with durable result root.

Forms preserve submitted business values, selected sources, and notes. Validation focuses `#form-error-summary` and links to the exact field. Conflict responses preserve intent and provide a refresh/review path rather than silently rebasing consequential choices.

## Query and performance contract

- Arrangement status board, commitment list, Deadline timeline, exposure view, ending preview, and Departure rollup use bounded eager loading.
- No page issues one query per commitment, evidence member, Deadline occurrence, Deposit component, exposure component, Arrangement, or finding.
- Departure rollups page or cap Arrangements and findings deterministically.
- Projection catch-up discovery uses indexed due/boundary comparisons and bounded batches.
- Finding visibility uses indexed `attention_at`/`overdue_at` comparisons rather than row-by-row Ruby evaluation.
- Exposure summaries use projection rows but drilldown retains stable source links.
- Representative scenario pages receive query-count assertions and named `EXPLAIN` proof for the highest-risk queries.

## Accessibility and responsive contract

- All primary M3E workflows are keyboard complete at 375, 768, 1280, and 1400 px.
- Use semantic headings, tables/lists, status text, labels, error associations, and live-region behavior already defined by the active interface contract.
- No hover-only action and no hidden tabbable mutation control.
- Focused dialogs/drawers trap focus, support Escape, and restore the invoking control.
- Row disclosures use native semantics where possible and contain explanation/history, not required inputs.
- Status and exposure qualification never rely on color alone.
- Amber marks attention, provisional facts, and guaranteed exposure; red remains invalid/destructive.
- Viewer and restricted-cost surfaces render no hidden monetary values or form data.

## Scenario gates

### Celebrity Beyond group cruise

- Define the $50 initial per-cabin Deposit Requirement tranche and the final cumulative $500-target tranche under the accepted cabin basis via `resource_units` / explicit coverage.
- Model final deposit as a **cumulative $500 target**. Activation materializes the tranche with March 11 Deadline; recording `names_assigned_to_supplier` before March 11 replaces the unelapsed Deadline without duplicating the commitment.
- **Product limitation (Arrangement-wide):** the shipped cumulative deposit and `names_assigned_to_supplier` milestone are **Arrangement-wide**. Scenario proof must not pass by implying that assigning names for one cabin advances only that cabin’s deposit. Later per-cabin deposit or milestone work remains out of M3E and must not silently introduce Traveler or client-allocation records.
- Materialize rooming-list and legal-name Deadlines with correct precision and time zone.
- Recording the name-assignment milestone replaces the unelapsed March 11 Deadline without storing traveler data or opening a duplicate commitment.
- Increasing the qualifying cabin quantity after external-handled attestation opens one incremental commitment.
- One compatible Supplier evidence coverage may satisfy the selected related commitments without row-by-row link creation.
- Gross cabin exposure remains separate from expected commission and expected net.

### Hilton pre-stay

- Calculate 15% of guaranteed-room cost using the explicitly selected aggregate/per-source rounding scope.
- Preserve guaranteed-room exposure whether rooms are occupied or unused.
- At the option date, eligible non-guaranteed capacity release is a future-effective capacity event recorded **in advance** through the canonical capacity command—not created by elapsed time.
- A changed guaranteed-room basis appends an adjustment rather than rewriting the original calculation.
- Ending remains blocked while future guaranteed exposure or unresolved actionable commitments govern.

### Port transfers

- Materialize per-segment final-count and schedule Deadlines through explicit per-source cardinality (**deferred past M3E.2**; M3E.2 ships `one_shared` only).
- One shared Supplier-facing date may govern several commitments without copying the date into each commitment.
- Projection catch-up racing with synchronous rebuild produces exactly one projection result and creates no domain event.
- Fixed vehicle exposure remains distinct from per-person forecast cost.

### Optional excursion

- Preserve the minimum-five term without treating forecast demand as guaranteed commitment.
- Move cost from contingent to guaranteed only through an **explicit** qualifying command—not elapsed time alone.
- Preserve the cancellation cutoff as an actionable Deadline without creating a Cancellation Case.

### Vineyard tour

- Keep fixed coach and per-person costs as separate exposure components.
- Show guaranteed, contingent, and forecast bands without summing them as separate liabilities.
- Keep unrelated currencies separate if scenario extensions introduce them.

## Successor reconciliation matrix

| Predecessor definition/result | Successor | Required result |
| --- | --- | --- |
| Open actionable identity | Unchanged lineage | Continue the same actionable identity—no duplicate unresolved action |
| Terminal (satisfied/released/cancelled/superseded) | Unchanged lineage | Compatible satisfaction/release may carry forward; waiver must not silently broaden onto the successor |
| Open | Materially changed | Supersede predecessor and open successor atomically |
| Any | Removed | Activation blocked until Staff resolves open predecessor actionable state or completes an explicit disposition path; untriggered future rules may retire |
| None | Added | Materialize the new requirement on successor activation |
| Elapsed Deadline | Changed | Preserve elapsed history; never rewrite the calculated date/time |

## Implementation slices

Ordinary M3E slices ship persistence, commands, authorization, UI, and proof together. The Accepted decision register records **bounded exceptions** for **M3E.6a** (preview without end command), **M3E.7a** (UI recovery over already-shipped forms), and the sequenced **M3D remediations** gate (see decision register item 91).


### M3E.0 — Authority and M3D closure gate

- Keep Accepted ADR 0013 and the Accepted M3E plan aligned with the decision register.
- Complete the revised acceptance sequence; promote paths out of drafts; mark both Accepted; update authority indexes; pin the verified M3D.9 + final M3D correctness QC base.
- Add no production M3E table, model, route, or placeholder.

**Exit:** authority is Accepted; M3D.9 is shipped; final M3D correctness QC is documented green; indexes and supersession notes are in place.

**Satisfied:** [M3E.0 — M3D closure gate](m3e0-m3d-closure-gate.md) (2026-09-19) pins base `344ab86` with green GitHub CI and local `bin/rails test`.

### M3E.1 — Source-shaped openings, disposition, evidence, inactivation

- Migrate M3D openings to `opening_kind = confirmation_trigger` with shape checks and source-specific unique indexes.
- Append-only disposition/reopening persistence and PostgreSQL immutability, including `released`.
- Reject reopen after ended Arrangement.
- Outcome-specific proof and permission checks.
- Immutable shared coverage sets, exact-member disqualification, and whole revocation.
- Ordinary inactivation open-state blocker amendment.
- Compressed evidence review; simple Open and Accepted-exception views driven by disposition state (detector catalog deferred to M3E.5).
- Idempotency, audit, tenancy, query, request, system, and concurrency proof.

**Exit:** every M3D opening has a correct terminal/correction lifecycle without generic manual invention; inactivation blocks only open commitments.

**Shipped:** M3E.1 (source-shaped openings, dispositions, evidence coverage, open-state inactivation).

### M3E.2 — Deadline definitions, occurrences, and projection catch-up

- Draft exact-version definitions, explicit coverage, templates, precision, zone, **`one_shared` cardinality**, and informational/actionable kinds. Named `per_source` cardinality remains deferred (schema-ready; commands reject it until a later slice expands materialization).
- Activation materialization and elapsed-date acknowledgment.
- Immutable occurrences and replacement.
- Due/overdue projection catch-up and synchronous rebuild; **no** time-created domain events.
- Successor lineage/reconciliation for Deadline families.
- M3D.7 freeze extension for Deadline definition families.

**Exit:** Deadline state is deterministic, time-safe, explainable, and usable through compressed forms without background domain mutations.

**Shipped:** M3E.2 (Deadline definitions, occurrences, activation materialization, projection catch-up, `deadline_requirement` openings, successor reconciliation; **`one_shared` cardinality only**).

### M3E.3 — Deposit Requirements and planning milestones

- Closed amount shapes, trigger/date rules (including milestone anchors), coverage via `resource_units`/explicit sources, currency, rounding scope.
- Materializations, component snapshots, adjustments, linked commitment/Deadline—only via activation, milestone, or Staff.
- Full-current-requirement external-handled Staff attestation.
- Positive post-attestation increment workflow.
- `SupplierPlanningMilestoneOccurrence` with at least `names_assigned_to_supplier`.
- Successor reconciliation and deposit scenario proof.
- M3D.7 freeze extension for Deposit definition families.

**Exit:** Supplier deposits are operationally actionable without creating accounting records or a shadow Payment ledger; Celebrity name-assignment timing works without Travelers.

**Shipped:** M3E.3 (Deposit Requirement definitions and coverage/cost links; immutable tranches and append-only components; activation materialization with `deposit_requirement` openings and `deposit_due` Deadlines; external-handled attestation via disposition outcome `handled_externally`; Staff planning milestones including `names_assigned_to_supplier` with unelapsed earlier-of Deadline replacement; successor copy/reconciliation; M3D.7 freeze for deposit definition families).

### M3E.4 — Qualified exposure

- Guaranteed/contingent/forecast qualification.
- Gross, expected commission, expected-net, and required-deposit measures.
- Currency grouping, unknown/incomplete states, stable source drilldown.
- Transactional Arrangement rebuild and bounded Departure rollup.
- Repair command/job and drift proof.

**Exit:** exposure is correct, source-traceable, permission-safe, and rebuildable.

**Shipped:** M3E.4 (qualified `guaranteed`/`contingent`/`forecast` exposure components and band×currency summaries; required-deposit measure; constrained `source_kind` locators; synchronous Arrangement rebuild from consequential commands; explicit contingent→guaranteed qualification command; idempotent repair command/job with drift proof).

### M3E.5 — Needs attention catalog and Departure rollup

- Closed detector catalog and boundary-time projection.
- Agency timing default plus definition override.
- Action-grouped Arrangement workflow and read-only Departure rollup.
- Accepted exceptions and technical-detail disclosures.
- Accessibility, responsive, keyboard, and query-count proof.

**Shipped:** M3E.5 (closed detector catalog with `attention_at`/`overdue_at` read-time visibility; Agency `attention_warning_lead_days` with Deadline definition override; synchronous Arrangement rebuild hooked beside exposure; Deadline catch-up rebuilds attention without time-created domain events; action-grouped Arrangement Needs-attention panel; Departure supplier-planning rollup counts).

**Exit:** Staff can identify and resolve the next Supplier-planning action without navigating record topology.

### M3E.5R — Integrity and recovery

- Forward migration replacing the three single-column idempotency-key foreign keys on deposit attestations, planning milestones, and exposure qualifications with same-Agency composite foreign keys.
- Preflight existing rows and fail visibly on mismatches before applying the composite keys.
- Bounded retries for Deadline catch-up’s three transient PostgreSQL errors (deadlock, serialization failure, lock wait timeout): at most five attempts, then fail visibly; one converged projection; no time-created domain events.

**Exit / merge gate:** Direct SQL cross-Agency foreign-key rejection and valid same-Agency insertion for all three tables; migration preflight proven; retry capped at five with permanent failures visible and one converged projection without domain events; current docs no longer claim shipped M3E.1–M3E.5 are unimplemented.

**Shipped:** M3E.5R (same-Agency composite idempotency FKs on deposit attestations, planning milestones, and exposure qualifications with preflight; Deadline catch-up retries capped at five for deadlock/serialization/lock-wait).

### M3D remediations — Reservation partial-response disclosure

Sequenced here as a merge gate before Arrangement ending. Does not reopen M3D domain decisions.

- Correct Reservation partial-response disclosure to consider only included, active scopes whose effective outcome is confirmed.
- Use the same predicate for confirmation and capacity panels; update on inclusion and outcome changes.

**Exit / merge gate:** Browser test covers all-declined, all-counterproposed, excluded default-confirmed, included confirmed, and mode switching; hidden controls are disabled and omitted from non-confirmed submissions.

**Shipped:** M3D remediations (Reservation partial-response disclosure predicate considers only included, active scopes with confirmed outcome; confirmation and capacity panels share that predicate).

### M3E.6a — Ending authority and preview

- Terminal lifecycle persistence and database guards.
- Authoritative named blocker query over live governing state.
- Closed ending reasons and the exact six-cascade eligibility catalog.
- Read-only digest-bound preview with required informational-Deadline supersessions and clear resolution paths.
- **No end command** in this slice.

**Exit / merge gate:** Blocker and candidate results match live governing state; historical facts alone do not block; digest binds exact candidates and expires; cross-Agency and Viewer paths fail closed; queries remain bounded.

**Shipped:** M3E.6a (`ended_at` lifecycle guard; `PreviewEndSupplierArrangement` with digest-bound preview token; named blockers; six-cascade eligibility catalog; `GET .../end` preview surface).

### M3E.6b — Atomic ending

- `EndSupplierArrangement` with canonical already-locked cascade operations.
- Required informational supersessions, projection rebuilds, durable result, and audit.
- Ended read-only surfaces and prohibited-write guards.
- Reject post-ending reopen and prohibited child writes.

**Exit / merge gate:** Preview conflict on changed state; selected late-cascade failure rolls back everything; no satisfaction, commitment release, waiver, fabricated response, or removal of guaranteed exposure; same-key replay works; ending races and post-end reopen/write rejection pass.

**Exit (M3E.6a + M3E.6b together):** no Arrangement can end while unhandled live governing state remains, and the common clean ending remains a short workflow.

### M3E.7a — Operational UI recovery

- Repair M3E commitment, evidence, deposit, milestone, Deadline, and exposure forms: canonical field anatomy, linked error summaries, preserved values and idempotency keys on 422, and a recoverable exposure-qualification form.
- Contain dense tables with responsive presentation.
- **Boundary:** M3E.7a owns defects in M3E’s own consequential forms and screens. Cross-slice setup friction (including the [M3F supplier-planning task-flow backlog](m3-supplier-planning.md#m3f-supplier-planning-task-flow-backlog)) remains M3F.

**Exit / merge gate:** Focused invalid-path request and keyboard tests for consequential actions; Viewer controls absent; no page-level overflow at 375 / 768 / 1280 / 1400 px; Tailwind build green.

### M3E.7b — Scenario and release gate

- Celebrity, Hilton, transfer, excursion, and vineyard builders; full named race/replay matrix; catch-up / rebuild / drift equivalence; query and `EXPLAIN` proof; regression, accessibility, responsive, security, lint, and CI.
- Reconcile root README, roadmap, current-state architecture, docs index, interface contract, terminology, and audit-subject catalog.
- **Mark M3E Shipped only after this PR’s gate passes.**

**Exit / merge gate:** Every Accepted M3E exit criterion has linked evidence; docs agree on shipped M3E.1–M3E.7 and unshipped later commercial work; full CI green.

**Exit (M3E as milestone):** M3E is production-ready; M3F still owns the milestone-wide M3A–M3E acceptance gate.

## Required proof matrix

### Persistence and database

- Direct ownership and exact-version composite FKs for every durable relation.
- Source-shaped openings with shape checks and source-specific unique indexes; lossless M3D migration.
- Append-only history immutable in Rails and PostgreSQL.
- Outcome-proof constraints and one current effective disposition, including `released`.
- Immutable coverage set membership; no cross-owner member.
- Rule/amount/precision/cardinality shape constraints.
- Exactly-once materialization identity; no consequence-execution identity for time-created domain events.
- Replacement lineage and one current occurrence where required.
- Planning milestone immutability and no traveler-name columns.
- Ended-state insertion guards.
- Projection rows demonstrably rebuildable from authoritative records.

### Commands and atomicity

- No partial disposition set, materialization, adjustment, milestone Deadline replacement, successor reconciliation, or ending cascade.
- Complete rollback after a late projection/audit/result failure.
- Same-key replay and conflicting-payload rejection for every durable command.
- GET preview never authorizes POST; POST rechecks under lock.
- Nested materialization operations do not reacquire earlier locks or emit duplicate success audits.
- Projection catch-up never opens commitments, materializes deposits, or emits capacity events.

### Interface compression

- Staff never manage manifests, coverage membership rows, lineage, idempotency, or projection components.
- Definition templates produce business-readable summaries without formula syntax.
- Common evidence coverage uses one review and one submit.
- Name-assignment milestone is a lightweight confirmation.
- Deposit attestation uses the exact external-handled wording and no payment fields.
- Activation preview is exception-focused.
- Clean ending is review plus confirm; cascade ending uses one review screen.
- Technical detail remains available through keyboard-accessible disclosure.

### Authorization and privacy

- Cross-Agency IDs return not found for every route/command/link.
- Viewer has no mutations or hidden mutation data.
- Restricted Supplier-cost users receive no monetary values in HTML, Turbo, JSON, logs, or duplicate/error detail.
- Waiver, release, and every ending cascade enforce their exact permissions under lock.
- Inactivation blocks only current open commitments.

### Time and projections

- Date-only and exact-time transitions across time zones and daylight-saving changes.
- Due-soon/overdue visibility without a status-changing domain-event job.
- Scheduled and synchronous projection catch-up produce one rebuild result and create no domain events.
- Contractual effective time distinct from processing time.
- Ended Arrangement rejects late projection-driven mutations that would invent domain events.
- Future-effective capacity events recorded in advance remain the only capacity path at option dates.

### Exposure

- Estimate never qualifies as guaranteed without a qualifying trigger.
- Contingent-to-guaranteed transition replaces qualification rather than double-counting, and requires an explicit command.
- Expected commission never offsets another source/band/currency.
- Unknown never becomes zero.
- Departure rollup never sums unlike currencies.
- Rebuild exactly matches incrementally maintained projection.

### Ending

- No force override.
- Historical records alone do not block.
- Cascades may not satisfy, release, or waive.
- New live blocker after preview yields conflict.
- Safe cascade selection does not broaden silently.
- Invalid later cascade rolls back earlier selected cascades.
- Replacement reason requires exact compatible replacement Arrangement.
- Ended record stays readable and mutation-closed; reopen after ending is rejected.

## Documentation when this slice ships

Only after M3E.7b passes:

- mark ADR 0013 implemented and this plan Shipped;
- update the M3 parent slice table and boundaries;
- update `AGENTS.md`, root `README.md`, `docs/README.md`, ADR index, roadmap, current architecture, terminology, interface contract, permission catalog, and audit catalog;
- describe dispositions (including `released`), Deadlines, deposits, planning milestones, exposure, attention, and Arrangement ending as shipped;
- describe the interface compression and interaction budgets as active contract; and
- continue to describe Client demand, Travelers, Obligations, Payments, fulfillment, Cancellation Cases, Communications, remittance, FX, and Agency-wide operations dashboard as unimplemented.

## Exit gate

M3E is complete only when:

1. ADR 0013 and this plan were Accepted (with parent / ADR 0012 / terminology / inactivation supersession notes) before production implementation began.
2. The implementation base contains shipped M3D.9 and green final M3D correctness QC.
3. Commitment openings are source-shaped; M3D rows migrated to `confirmation_trigger`; deposit openings bind exactly one tranche; there is no unrestricted manual opening.
4. Commitment dispositions, reopening, shared coverage, disqualification, and revocation are append-only, exact-owner/version-safe, race-safe, and database-enforced; outcomes include `released`.
5. Waiver requires elevated override; satisfaction, release, cancellation, and supersession require their exact proof.
6. Reopening is rejected after the Arrangement has ended.
7. Ordinary inactivation blocks only current open commitments.
8. Deadline Definitions and occurrences preserve exact rule, coverage, cardinality, precision, zone, replacement, and elapsed history.
9. Informational Deadlines remain timeline-only; actionable Deadlines resolve through commitments opened by explicit commands.
10. Time boundaries refresh projections only; they create no authoritative domain events.
11. Deposit Requirements calculate reproducibly, adjust append-only, materialize via activation or Staff (not elapsed time), bind one tranche per commitment, and remain distinct from Payments and Obligations.
12. Planning milestones (including `names_assigned_to_supplier`) record no traveler data and normally replace unelapsed earlier-of Deadlines rather than first-creating deposit requirements.
13. External-handled attestation covers the full current open tranche, records no partial money application, and opens a new tranche plus commitment after a later positive post-satisfaction change.
14. Exposure preserves qualification, gross versus expected net, source, band, currency, unknown state, and rebuildability.
15. Needs-attention findings are deterministic, nondismissible while true, action-grouped, and separate from command blocker enforcement; M3E.1 Open/Accepted-exception views precede the M3E.5 catalog.
16. Arrangement ending has no force override, binds a digest preview, executes only the enumerated safe cascades atomically (without satisfy/release/waive), narrows Deadline blockers to live governing Deadlines, and leaves a terminal read-only record.
17. Monetary visibility, tenancy, authorization, audit, idempotency, lock order, and PostgreSQL enforcement remain fail-closed.
18. Ordinary workflows meet the interface compression contract and remain keyboard-complete and responsive.
19. Celebrity, Hilton, transfers, excursion, and vineyard builders pass slice and composite scenario gates under the amended time and milestone rules.
20. Query bounds, genuine races, projection catch-up retries, rebuild equivalence, M0–M3D regression, Tailwind, lint, security, and full CI are green.
21. Documentation marks only shipped capability and preserves every later commercial non-goal.

## Revised acceptance sequence

These documentation steps were completed on Accept (2026-09-18):

1. Define the source-shaped commitment-opening schema and idempotency identities (including one commitment per deposit tranche).
2. Amend the inactivation blocker to mean unresolved current open state.
3. Reconcile manual-opening language across the parent plan, ADR 0012 (dated supersession note), and terminology.
4. Add the Staff-recorded name-assignment milestone that advances earlier-of Deadlines after activation materialization.
5. Add `released` to the disposition catalog.
6. Restrict time-boundary processing to projections and already-recorded future-effective events—or explicitly reopen the parent automation decision (this package retains the parent rule).
7. Add the activation-freeze, slice-boundary, measurement (`resource_units` / explicit coverage), post-ending reopen-rejection, successor reconciliation matrix, enumerated ending cascades, closed Deadline/ending-reason catalogs, cumulative staged deposit, and projection source-locator exception.
8. Promote the drafts, repair indexes and links, and Accept ADR 0013 and the M3E plan together.

Do not begin production M3E code until M3E.0 / QC prerequisites are met.

## Pre-accept review disposition

The 2026-09-18 compatibility review was accepted and strengthened. Drafts (this plan, ADR 0013, and the decision register) were amended for source-shaped openings, open-state inactivation, explicit supersession of “manual opening” language, Staff-recorded name-assignment milestones without Travelers, first-class `released`, and retention of the parent rule that time alone does not create capacity events or change commitments. A second amendment wave the same day added earlier-of activation materialization, deposit tranche identity, cumulative $500 target, successor reconciliation matrix, enumerated ending cascades, constrained projection source locators, and closed Deadline/ending-reason catalogs. The package was **Accepted** on 2026-09-18 and promoted out of drafts.
