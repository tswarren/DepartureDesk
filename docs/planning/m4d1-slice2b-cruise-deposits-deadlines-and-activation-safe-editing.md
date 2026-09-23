# M4D.1 Slice 2B — Cruise Deposits, Deadlines, and Activation-Safe Editing

**Status:** Accepted 2026-09-23. Sole implementation authority for typed Cruise Stop point D (Supplier deposits, deadlines, activation consequences, and successor-safe editing). Not shipped. Implementation is authorized: required bases are shipped. Parent [M4D.1](m4d1-departure-composition-workspace.md) remains Accepted for later slices. Slice 2C+, Client connection beyond Stop D, and M4E remain unauthorized until named.

**Parent authority:** [M4D.1 — Departure Composition Workspace](m4d1-departure-composition-workspace.md), especially §§11–12, §19, and §21.

**Accept package base:** [`b66d88b`](https://github.com/tswarren/DepartureDesk/commit/b66d88b) (green `main` tip including shipped [Slice 2A.2R3](m4d1-slice2a2r3-cruise-rate-shape-detector-remediation.md) pin).

**Required shipped bases:**

- [M4D.1 Slice 2A.2R2](m4d1-slice2a2r2-cruise-rate-matrix-interaction.md) — **Shipped** at [`b73a9ff`](https://github.com/tswarren/DepartureDesk/commit/b73a9ff) (PR #142).
- [M4D.1 Slice 2B-R](m4d1-slice2br-cruise-deposit-semantics-amendment.md) — **Shipped** at [`5a391d1`](https://github.com/tswarren/DepartureDesk/commit/5a391d1); capacity-sourced deposit quantities and source-aware cumulative targets.
- [M4D.1 Slice 2A.2R3](m4d1-slice2a2r3-cruise-rate-shape-detector-remediation.md) — **Shipped** at [`e5ded27`](https://github.com/tswarren/DepartureDesk/commit/e5ded27); rate-shape detector remediation.

**Retained domain authority:** Amended M3E and ADR 0013 remain authoritative for Deadline Definitions, Deposit Requirement Definitions, immutable materializations, operational commitments, planning milestones, exposure, and evidence-backed dispositions. This slice is a typed Cruise **adapter and interaction surface** over those generic records. It does not create a parallel deadline, deposit, or payment model.

**Command style:** Unlike Slice 2A typed orchestration wrappers (`CreateCruiseSailingSetup`, etc.), this slice calls the **existing public M3E mutation commands** plus Cruise-specific compile / detect / preview services. Controllers must not invent a second activation or materialization engine.

**Scope locked:** M4D.1 Stop point D only—Cruise Supplier Deposit Requirement Definitions, Supplier Deadline Definitions, activation consequences, active-state presentation, and successor-safe editing. Slice 2C Service connection, Slice 2D Client terms, Supplier accounting, Client accounting, Payments, Obligations, Travelers, and M4E remain unauthorized.

---

## 1. Outcome

For one Cruise Arrangement, Staff can enter ordinary Supplier deposit and deadline terms through readable, independently saved typed controls without learning the generic M3E graph editor.

The Celebrity/Smith proof supports (economics authorized by **shipped 2B-R**):

- initial deposit of $50 per initially blocked cabin, due September 20, 2026;
- cumulative final-deposit target of $500 per retained cabin;
- final deposit due at the earlier of names assigned to Supplier or March 11, 2027;
- option/release date of March 11, 2027;
- final payment due July 9, 2027 (Deadline type `other` unless the closed catalog is later amended);
- rooming list due October 7, 2027 (informational);
- exact activation consequences;
- read-only active operational state; and
- successor-draft editing without mutating governing definitions or already-materialized occurrences.

Do **not** invent a separate legal-names Deadline for the canonical fixture. Keep `names_assigned_to_supplier` solely as the final-deposit earlier-of trigger (Arrangement-wide).

The typed interface preserves the distinctions among a contractual requirement, an operational commitment, an externally handled requirement, and an actual payment.

**Exit criterion:** Browser acceptance must construct the Celebrity initial deposit, cumulative final deposit with earlier-of timing, and ordinary Cruise deadlines entirely through visible typed controls; preview exact activation consequences; activate them; and demonstrate successor-safe editing. Programmatic service payloads or advanced-planning setup alone are insufficient proof.

---

## 2. Authority and prerequisite closure

**Accept gates — closed:**

1. Slice 2A.2R2 remains Shipped at `b73a9ff` (included in Accept base `b66d88b`).
2. Slice 2B-R is Shipped at `5a391d1` (Path B deposit semantics + ADR/register amendments).
3. Slice 2A.2R3 is Shipped at `e5ded27` (rate-shape detector remediation).
4. Accept package base pinned: `b66d88b`.
5. Parent §19 command vocabulary is amended in the same Accept package with the §14 services/routes locked below.
6. M3E public Deadline/Deposit/milestone/activation/materialization/successor commands remain the mutation surface; this adapter does not reimplement them.

This Accepted plan is the sole implementation authority for typed Stop D chrome. Discovery notes and wireframes may guide layout but must not compete with this contract. Cabin-quantity and cumulative-target **domain** rules live in 2B-R / ADR 0013—not in this adapter plan.

Implementation proceeds through vertical PRs **2B-A → 2B-B → 2B-C** (§21) after this Accept.

---

## 3. Scope and non-goals

### 3.1 In scope

- An Arrangement-level **Deposits and deadlines** section in the typed Cruise workspace.
- Independently saved Deposit Requirement Definitions.
- Independently saved Supplier Deadline Definitions.
- Guided amount, timing, coverage, and commitment shapes supported by **shipped** M3E (including 2B-R).
- Server-authoritative previews for calculated deposit amounts and activation consequences (advisory; write-free).
- Fixed-date, exact-time, relative, and earlier-of timing where supported by M3E.
- Explicit coverage of the Cruise Arrangement Item, selected cabin Resources / Capacity Pools, or another named supported M3E shape.
- Draft create/edit/remove behavior.
- Typed-shape detection and non-destructive advanced fallback per definition.
- Active governing-term and operational-occurrence presentation.
- Successor-draft editing with current-versus-proposed comparison.
- Activation/materialization proof for the accepted Celebrity shapes.
- Responsive, accessible, keyboard-complete workflows.

### 3.2 Out of scope

- Implementing `capacity_pool_units` or source-aware cumulative evaluation (that is **2B-R**).
- Percentage deposits in the typed catalog (advanced planning only).
- Reorder or duplicate of definitions in the first release.
- Standalone Initial/Final Deposit Deadline templates when a Deposit Requirement already owns the due occurrence.
- A Cruise-specific deposit or deadline table.
- Supplier Payments, Client Payments, Obligations, Receipts, bank transactions, remittance, reconciliation, or accounting posting.
- Treating `handled_externally` as proof of payment.
- Traveler identities, birth dates, room assignments, or actual submitted legal names.
- Invented legal-names Deadline for the Celebrity fixture.
- Client payment schedules, cancellation terms, prices, Packages, or Service Offer connection.
- Arbitrary formula, JSON, or generic graph authoring in the typed form.
- Automatic PDF or confirmation interpretation.
- Silent normalization of advanced definitions.
- One giant Arrangement save spanning rates, deposits, deadlines, and Client work.
- Retrospective mutation of materialized Deadline occurrences, deposit tranches, or governing active-version definitions.

---

## 4. Ownership and save boundaries

### 4.1 Arrangement ownership

Deposits and deadlines are presented at the **Supplier Arrangement level**, not inside a cabin-category rate page.

A Supplier contract may calculate a deposit from quantities across several cabin categories, but the contractual requirement remains one Deposit Requirement Definition. The typed adapter must not create one deposit definition per cabin category merely because cabin Resources supply its calculation or coverage.

Category-specific requirements remain possible only through explicit narrower coverage.

### 4.2 Independent definitions

Each Deposit Requirement Definition and each Supplier Deadline Definition has its own save boundary.

- A deadline save cannot alter or roll back saved rates.
- A deposit save cannot alter or roll back another saved deposit or deadline.
- A failed definition save preserves the attempted form values.
- No outer Arrangement form wraps all definitions into one transaction.

### 4.3 Page topology

The Cruise Arrangement workspace adds:

1. Deposit requirements
2. Other Supplier deadlines
3. Activation consequences
4. Current operational requirements, when active

The default state is a readable list of facts. At most one substantial definition editor is open at a time.

---

## 5. Canonical terminology

| Use | Do not use |
| --- | --- |
| Deposit requirement | Deposit payment |
| Amount required | Amount paid |
| Due / overdue | Unpaid, unless later accounting proves it |
| Handled externally | Paid |
| Supplier deadline | Client payment due |
| Planning milestone recorded | Traveler names received |
| Materialized commitment | Supplier Obligation |
| Governing term | Current editable term |
| Proposed successor term | Updated active term |

Expected commission remains separate from Supplier deposits. Deposit calculations may reference supported capacity or cost sources when M3E authorizes that basis, but they do not alter cost components.

---

## 6. Draft page and collection interaction

### 6.1 Readable summary state

Each saved definition summary displays:

- name and semantic template;
- amount rule when applicable;
- timing sentence;
- coverage sentence;
- whether activation creates an actionable commitment;
- readiness or validation state;
- Edit and Remove actions where allowed; and
- Advanced setup when the typed detector cannot safely reopen the graph.

### 6.2 Collection behavior

Staff can:

- add a Deposit Requirement or Supplier Deadline;
- edit one definition without opening the others;
- remove a draft definition after consequence-aware confirmation; and
- cancel an editor without changing durable facts.

Successful save returns focus to the saved summary and visibly confirms success. Validation failure keeps the editor open, preserves all submitted values, places the error summary before the editor, and focuses the first invalid field or error summary according to the interface contract.

Removal confirmation names the definition and states what draft facts will be deleted. It must not use generic `Cancel` wording.

**Not in first release:** reorder and duplicate. Current cumulative contribution is explicit under 2B-R; do not reintroduce position-as-economics via reorder chrome. Duplicate may later be a prefilled create flow, not a new persistence command.

### 6.3 Typed versus advanced definitions

Compatibility is definition-scoped. One advanced definition must not make every ordinary definition read-only.

An unsupported definition appears as a read-only summary with:

- its durable label and current facts;
- specific incompatibility reasons;
- a direct Advanced Supplier planning link; and
- a return target to the same Cruise Arrangement section.

Opening or viewing an advanced definition performs no rewrite.

---

## 7. Deposit Requirement editor

The editor presents five ordered steps. Conditional fields appear only for the chosen shape.

### 7.1 Step 1 — What is required?

Fields:

- Requirement template: Initial deposit, Final deposit, or Other deposit requirement.
- Staff-facing name, defaulted from the template and editable within accepted limits.
- Optional Supplier reference/note if M3E has a supported durable field; otherwise use the existing definition note and do not add Cruise-only persistence.

The semantic template remains distinct from the editable label.

### 7.2 Step 2 — How is the amount calculated?

**Typed shapes after shipped 2B-R:**

1. Fixed amount.
2. Amount per explicit quantity (`explicit` basis).
3. Amount × `capacity_pool_units` (initially blocked / retained cabin pools as authorized by 2B-R).
4. Source-aware cumulative target (explicit contributors).

**Not in typed catalog:** percentage of Supplier-cost bases (route to Advanced planning). Existing percentage M3E definitions remain visible as advanced/read-only when unsupported by the detector.

No formula syntax is exposed.

#### Fixed amount

Require currency and amount. Currency must match the accepted M3E rules and the Departure operating-currency boundary. Do not infer FX.

#### Amount per explicit quantity

Require unit amount, positive explicit quantity, and a server-authoritative calculation preview.

#### Capacity-pool units (blocked / retained)

Require:

- unit amount;
- `capacity_pool_units` basis as shipped by 2B-R;
- exact selected Resources/Pools required by that source; and
- a server-authoritative calculation preview listing every contributing source and quantity.

“Per cabin” never infers every Resource whose label resembles a cabin. Staff must confirm exact covered Resources or pools.

Example preview:

> Veranda: 12 + Concierge: 8 + Suite: 4 = 24 cabins. 24 × $50.00 = $1,200.00.

If the quantity is not currently calculable, the preview says what is missing and does not fabricate zero.

#### Cumulative target

Require:

- target rate/amount shape authorized by 2B-R;
- quantity source when per-unit (e.g. retained `capacity_pool_units`);
- **explicit** contributing prior Deposit Requirement Definitions;
- clear treatment when source quantities differ; and
- a server-authoritative remaining-amount preview with per-source target, credit, and clamp.

The UI must not simplify `$500 target less $50 initial` to `$450 × current cabins` unless that is the actual M3E calculation for the selected sources.

### 7.3 Step 3 — When is it due?

Use the shared timing editor in §9.

### 7.4 Step 4 — What does it cover?

Supported choices:

- entire Cruise Arrangement (compiled as coverage of the single Cruise `ArrangementItem`);
- selected cabin-category Resources / Capacity Pools; or
- another explicitly named supported M3E coverage shape.

Show the plain-language coverage summary before save. Persist only generic M3E coverage links.

### 7.5 Step 5 — Operational meaning

Show whether activation will create an actionable Supplier commitment or an informational requirement. This is derived from the template and selected M3E definition shape unless the Accepted plan explicitly names a safe Staff choice.

Do not let Staff mark the future requirement satisfied, paid, or handled while editing its definition.

---

## 8. Supplier Deadline editor

### 8.1 Templates

Offer:

- Option/release decision
- Final payment (maps to Deadline type `other` with required label unless the closed catalog is later amended)
- Rooming list
- Other Supplier deadline

Do **not** offer standalone Initial deposit deadline or Final deposit deadline templates when a Deposit Requirement already materializes its due occurrence and commitment.

Selecting a template establishes:

- stable semantic kind / `deadline_type`;
- default label;
- allowed timing shapes;
- allowed coverage shapes;
- default actionable/informational behavior; and
- default commitment-definition behavior.

Changing the label never changes semantic kind / type.

### 8.2 Fields

The deadline editor contains:

1. Template and label.
2. Shared timing editor.
3. Coverage selector.
4. Required action or evidence description supported by M3E.
5. Warning lead time when a definition-specific override is allowed.
6. Plain-language sentence preview.
7. Activation consequence.

### 8.3 Completion meaning

The summary explains the later operational outcome without completing it:

| Template | Later operational handling |
| --- | --- |
| Option/release | Inventory retained or released through the appropriate operational command |
| Final payment (`other`) | Evidence-backed satisfaction, handled-externally attestation where authorized, release, or waiver—not a Payment record |
| Rooming list | Evidence-backed satisfaction, release, or waiver (informational by default for Celebrity) |
| Other | Explicit configured commitment behavior |

Definition editing never doubles as occurrence disposition.

---

## 9. Shared timing editor

### 9.1 Supported shapes

- Fixed local date.
- Fixed local date and time.
- Relative to the sailing or another explicitly supported Occurrence anchor.
- Earlier of a supported planning milestone and a fallback date/date-time.

Every rule records the applicable IANA time-zone source and precision according to M3E.

### 9.2 Earlier-of interaction

The typed editor presents one rule:

> Due at the earlier of [planning milestone] or [fallback date].

For Celebrity final deposit:

- planning milestone: `names_assigned_to_supplier`;
- fallback date: March 11, 2027; and
- one Deposit Requirement/commitment, not two parallel requirements.

The sentence preview names both facts and the resolved zone/precision. The page must never display the milestone and fallback as unrelated deadline rows.

### 9.3 Relative timing

Relative rules show the anchor, offset, direction, precision, and current calculated illustration. Unsupported anchors or calendars route to advanced planning.

---

## 10. Live previews

### 10.1 Deposit calculation preview

The preview accepts the same normalized definition payload as create/update, evaluates through existing M3E calculation primitives (including 2B-R), and writes nothing.

It returns:

- selected source facts;
- resolved quantities;
- amount or pending reason;
- currency;
- coverage summary;
- due-rule sentence; and
- warnings or unsupported reasons.

### 10.2 Activation consequence preview

Before activation, the typed Cruise section shows exactly what Stop D will materialize:

- definition name;
- calculated amount or pending reason;
- Deadline date/time and time zone;
- coverage members;
- whether an actionable commitment will open;
- elapsed-date acknowledgment required;
- materialization blocker, if any; and
- links back to the exact editor.

Do not reduce this to counts such as “four deadlines will be created.” Counts may supplement, not replace, definition-level consequences.

Preview is **advisory and server-authoritative**. It creates no durable definition, occurrence, tranche, commitment, event, audit entry, or idempotency record.

---

## 11. Draft, active, and successor behavior

### 11.1 Draft Arrangement

Staff may create, edit, and remove definitions. Saving definitions creates no materialized occurrence, deposit tranche, or commitment merely because time later elapses.

### 11.2 Activation

Activation uses the shipped M3D/M3E transaction and materialization boundaries. The typed adapter must not implement a second activation engine or materialize records in a controller callback.

Activation must:

- lock in canonical order;
- revalidate definitions and exact coverage;
- require elapsed-date acknowledgments where M3E requires them;
- materialize each accepted definition exactly once;
- preserve one commitment per tranche/opening identity;
- create no duplicate earlier-of requirement; and
- roll back the activation transaction on a materialization failure according to shipped activation authority.

### 11.3 Active Arrangement

Governing definitions are read-only. The page distinguishes:

- governing Supplier term;
- materialized Deadline occurrence;
- Deposit Requirement tranche and current calculated amount;
- open/satisfied/handled externally/released/waived operational state;
- current due/overdue projection; and
- evidence-backed actions already authorized by M3E.

The page offers **Create successor draft to change future terms** rather than editing governing definitions.

### 11.4 Successor draft

The successor editor shows:

- current governing term;
- proposed successor term;
- materialized current-version occurrence or tranche, when one exists;
- whether the proposed change can reconcile on successor activation; and
- facts that remain historical and immutable.

Editing a successor does not immediately reschedule, replace, waive, release, or satisfy a governing operational requirement.

The UI must not claim the effect of a future successor until the shipped reconciliation engine establishes it.

---

## 12. Earlier-of milestone lifecycle proof

For the Celebrity final deposit:

1. Draft definition records cumulative target and earlier-of rule.
2. Activation materializes the deposit tranche, one operational commitment, and March 11 fallback Deadline.
3. Recording `names_assigned_to_supplier` before March 11 replaces the unelapsed fallback at the milestone time.
4. No duplicate commitment opens.
5. Recording the milestone after the fallback has elapsed preserves the elapsed occurrence as historical and overdue.
6. Amount adjustments follow M3E tranche rules and do not rewrite satisfied historical facts.

The typed UI must demonstrate both the pre-fallback and post-fallback cases.

---

## 13. Compatibility detection and advanced fallback

Definition-scoped detectors (locked):

- `DetectCruiseDepositRequirementShape`
- `DetectCruiseSupplierDeadlineShape`

Typed compatibility requires:

- one supported semantic template;
- supported amount/timing/coverage shape (including shipped 2B-R shapes);
- unambiguous source and quantity mapping;
- no unsupported formula or mixed basis;
- no mutation of immutable materialized history; and
- safe reconstruction without changing rounding, coverage, or operational meaning.

Unsupported graphs (including percentage deposits) fail closed to Advanced Supplier planning. Typed reads never flatten or approximate them.

---

## 14. Commands, routes, and transaction boundaries

**Locked mutation approach** — use shipped public M3E commands directly:

**Use shipped public M3E commands directly:**

- `CreateSupplierDeadlineDefinition`
- `UpdateSupplierDeadlineDefinition`
- `RemoveSupplierDeadlineDefinition`
- `CreateSupplierDepositRequirementDefinition`
- `UpdateSupplierDepositRequirementDefinition`
- `RemoveSupplierDepositRequirementDefinition`
- `RecordSupplierPlanningMilestone`

Activation continues through the shipped Arrangement activation path, including:

- `MaterializeSupplierDeadlineDefinitionsAlreadyLocked`
- `MaterializeSupplierDepositRequirementDefinitionsAlreadyLocked`
- `ReconcileSupplierDeadlineSuccessorAlreadyLocked`
- `ReconcileSupplierDepositSuccessorAlreadyLocked`

**Cruise adapter read/preview services** (locked):

- `CompileCruiseDepositsAndDeadlinesWorkspace`
- `DetectCruiseSupplierDeadlineShape`
- `DetectCruiseDepositRequirementShape`
- `PreviewCruiseDepositRequirement`
- `PreviewCruiseDepositsAndDeadlinesActivation`

Preferred typed route ownership (locked):

```text
GET    /departures/:departure_id/arrangements/:arrangement_id/cruise/deposits-and-deadlines

POST   /departures/:departure_id/arrangements/:arrangement_id/cruise/deposits-and-deadlines/deadlines
PATCH  /departures/:departure_id/arrangements/:arrangement_id/cruise/deposits-and-deadlines/deadlines/:id
DELETE /departures/:departure_id/arrangements/:arrangement_id/cruise/deposits-and-deadlines/deadlines/:id

POST   /departures/:departure_id/arrangements/:arrangement_id/cruise/deposits-and-deadlines/deposits
PATCH  /departures/:departure_id/arrangements/:arrangement_id/cruise/deposits-and-deadlines/deposits/:id
DELETE /departures/:departure_id/arrangements/:arrangement_id/cruise/deposits-and-deadlines/deposits/:id

POST   /departures/:departure_id/arrangements/:arrangement_id/cruise/deposits-and-deadlines/deposit-preview
POST   /departures/:departure_id/arrangements/:arrangement_id/cruise/deposits-and-deadlines/activation-preview
```

Request IDs never establish tenancy. Load all records through `Current.agency` and the already-authorized Arrangement/version context.

Each definition mutation owns one transaction and calls already-locked M3E helpers where needed. Do not chain public multi-transaction commands. Reuse `AgencyCommandIdempotencyKey` for consequential creates and transitions according to existing policy.

The generic version-scoped `/deadlines` and `/deposits` routes remain the Advanced-planning escape hatch.

Do not include reorder or duplicate routes in the first release.

---

## 15. Concurrency, immutability, and audit

- Use version and definition optimistic locks on mutable drafts.
- Preserve the established Agency → Arrangement/version → definition/source lock order and any more specific M3E ordering.
- Recheck draft/active/successor state after locks.
- Activated definition graphs remain immutable in Rails and PostgreSQL under M3D.7.
- Audit successful definition mutations in the same transaction using the existing `SupplierArrangement` subject and closed action catalog.
- Preview writes no audit event.
- Expected validation, stale-lock, and unsupported-shape failures write no audit event.
- Cross-agency identifiers return not found.

---

## 16. Error and recovery contract

The typed UI must prove:

- failed deposit save preserves all fields and selected sources;
- failed deadline save does not change valid saved rates or definitions;
- stale-lock errors do not silently replace submitted values;
- unsupported definitions remain intact and readable;
- activation blockers deep-link to the exact definition;
- return from Advanced planning restores Arrangement and section context;
- successor errors do not mutate active definitions or occurrences;
- invalid earlier-of rules create neither half of a durable rule;
- preview failure is visible and never represented as zero or success; and
- elapsed-date acknowledgment is explicit and consequence-specific.

---

## 17. Responsive and accessibility contract

- Use stacked definition summaries on narrow screens; do not require horizontal table scrolling to understand name, amount, due rule, coverage, and state.
- Keep actions adjacent to the definition they affect.
- Render earlier-of timing as one understandable sentence.
- Resource/source selection uses labeled checkboxes or an equally accessible multi-select with quantities and codes in the accessible name.
- Conditional fields preserve logical focus when shown or hidden.
- Add/edit dialogs or inline panels have programmatic headings and error association.
- Removal confirmations name the target and discarded consequence.
- After save/cancel, focus returns to the affected summary or invoking control.
- Status and preview changes use appropriate live-region behavior without announcing every keystroke excessively.
- Complete core flows at 375, 768, 1280, and 1400 widths.
- Complete add, edit, remove, preview, and recovery flows by keyboard.

---

## 18. Acceptance fixtures

### 18.1 Celebrity/Smith canonical fixture

Supplier Arrangement: Celebrity Cruises, Celebrity Beyond, supplier group 1119999, sailing November 6–13, 2027.

Deposit and deadline facts (Path B; requires shipped 2B-R):

- Initial deposit: September 20, 2026; $50 per initially blocked cabin; illustrative 24 cabins from exact O1/I1/etc. Resources/pools; $1,200 preview.
- Option/release date: March 11, 2027 (distinct actionable Deadline when it is a distinct required action).
- Final deposit: cumulative $500 per retained cabin; earlier of names assigned and March 11, 2027; initial deposit contributes explicitly; source-aware remainder.
- Final payment: July 9, 2027 (`other`).
- Rooming list: October 7, 2027 (informational).

Do **not** create a `legal_names_due` row for this fixture. Do not hardcode 24 independently of the selected sources.

### 18.2 Advanced-shape fixture

Create one unsupported Deposit or Deadline definition through generic M3E planning (for example a percentage deposit). Prove the Cruise page preserves it, explains why it is advanced, links correctly, and keeps compatible sibling definitions editable.

### 18.3 Active/successor fixture

Activate the Celebrity definitions, materialize expected occurrences/tranche/commitments, create a successor, change one proposed term, and prove the governing occurrence remains unchanged until an authorized reconciliation transition.

---

## 19. Blocking browser acceptance

### 19.1 Smith initial deposit

Through visible typed controls:

1. Add Initial deposit.
2. Choose amount per initially blocked cabin (`capacity_pool_units`).
3. Select all applicable cabin Resources/pools.
4. Enter $50.
5. Enter September 20, 2026.
6. Verify source-level preview totals 24 cabins and $1,200.
7. Save and reopen.
8. Verify one generic M3E definition with exact sources and coverage.

### 19.2 Cumulative final deposit

1. Add Final deposit.
2. Choose cumulative target.
3. Enter $500 per retained cabin.
4. Select the initial deposit as an **explicit** contributor.
5. Choose earlier-of names assigned and March 11, 2027.
6. Verify the sentence and amount preview (source-aware; not flattened to $450 × cabins when quantities differ).
7. Save and reopen without flattening to a fixed amount or two deadlines.

### 19.3 Ordinary Supplier deadlines

Add option/release, final payment (`other`), and rooming-list definitions independently. Make one subsequent definition invalid and prove previously saved definitions and Supplier rates are unchanged.

### 19.4 Draft removal and validation recovery

Add a meaningful requirement, remove it with confirmation, and verify its exact draft graph disappears. Trigger a validation failure on another definition and verify all attempted fields remain.

### 19.5 Activation preview and activation

Review exact definition-level materialization consequences; activate; verify expected Deadline occurrences, deposit tranche, and commitments; verify no Payment, Obligation, Receipt, or `paid` state exists.

### 19.6 Earlier-of milestone

Before fallback, record names assigned and verify replacement without duplicate commitment. In a separate scenario, let the fallback elapse and verify a later milestone preserves the historical overdue occurrence.

### 19.7 Successor editing

Open an active Arrangement; verify governing definitions are read-only; create a successor; edit the proposed deadline; verify current versus proposed terms and prove the active occurrence did not change.

### 19.8 Advanced fallback

Open a Cruise with one advanced definition; verify read-only summary, specific reason, advanced deep link, unchanged graph, and continued typed editing of compatible siblings.

### 19.9 Responsive and keyboard flow

Complete the initial-deposit workflow at narrow width and by keyboard, including source selection, preview, validation recovery, and focus return.

---

## 20. Lower-level proof

### 20.1 Command/service tests

- Successful fixed, explicit-quantity, and `capacity_pool_units` Deposit definitions (via public M3E commands).
- Source-aware cumulative target with explicit contributors.
- Exact source and coverage mapping.
- Earlier-of milestone/fallback definition.
- Independent definition transactions.
- Remove behavior and idempotency.
- Stale locks and cross-agency rejection.
- Draft-only mutation and activated immutability.
- Preview produces no durable writes, audits, or idempotency rows.
- Definition-scoped typed detection and advanced failure.
- Successor copy and comparison.

### 20.2 Materialization/integration tests

- Activation creates exactly the intended occurrences, tranches, and commitments.
- Elapsed acknowledgment behavior.
- Pre-fallback milestone replacement without duplicate opening.
- Post-fallback history preservation.
- Adjustment behavior follows M3E rules.
- Activation rollback on invalid materialization.
- No Supplier Payment, Obligation, Client record, or accounting event.

### 20.3 Request tests

- Staff authorization; Viewer mutation rejection.
- Other-agency IDs return not found.
- Valid/invalid/stale create, update, and delete.
- Draft, active, and successor routing.
- Preview authorization and no-write proof.
- Advanced return target.

### 20.4 System tests

All §19 scenarios are blocking in CI. Tests must use visible controls and accessible labels; direct command setup may establish unrelated prerequisite sailing/rate facts but may not construct the Deposit/Deadline definition under test.

---

## 21. Recommended implementation sequence

One Accepted 2B contract, delivered through three vertical PRs after this Accept:

### 2B-A — Typed Supplier Deadline definitions

- Arrangement-level section and readable summaries.
- Shared timing editor.
- Option/release, final-payment (`other`), rooming-list, and Other templates.
- Definition-scoped detector and advanced fallback.
- Independent save/remove/recovery proof.

### 2B-B — Deposit Requirement definitions

- Fixed, explicit-quantity, and `capacity_pool_units` shapes.
- Explicit Resource/pool selection.
- Source-aware cumulative target with explicit contributors.
- Calculation preview (write-free).
- Celebrity initial/final deposit browser proof.

### 2B-C — Activation and successor lifecycle

- Exact activation consequence preview (advisory; write-free).
- Materialization proof.
- Earlier-of milestone replacement.
- Active read-only operational presentation.
- Successor comparison and activation-safe editing.
- Integrated Celebrity acceptance and responsive/accessibility closure.

The full UI/domain contract is Accepted before 2B-A begins so the first PR does not harden another command-correct but workflow-incomplete surface.

---

## 22. Decisions

### 22.1 Default ownership — locked

Cruise deposits and deadlines are Arrangement-wide by default.

Because M3E requires a coverage link, “Arrangement-wide” compiles to coverage of the single Cruise `ArrangementItem`, not to an empty coverage set. Narrower coverage explicitly links selected cabin Resources or Capacity Pools.

### 22.2–22.4 Cabin quantities and cumulative target — shipped under 2B-R

Product Path B (`$50 × initially blocked`, `$500 × retained`, source-aware cumulative) is locked in [Slice 2B-R](m4d1-slice2br-cruise-deposit-semantics-amendment.md). That slice amends ADR 0013 / M3E register and ships `capacity_pool_units` plus source-aware `cumulative_target`. This adapter consumes those economics; it does not re-litigate them.

### 22.5 Option date — locked

Represent distinct requirements only when they cause distinct actions.

- Create one actionable `option_or_release_date` Supplier Deadline when retain/release is a distinct required action.
- Use the same date as the fallback arm of the final deposit when its rule is “earlier of names assigned or option date.”
- Do not create a separate `deposit_due` Deadline for a Deposit Requirement that already materializes its due occurrence and commitment.

### 22.6 Commitment-line catalog — locked (Celebrity)

| Template | M3E representation | Default behavior |
| --- | --- | --- |
| Initial deposit | Deposit Requirement | Actionable deposit commitment |
| Final/cumulative deposit | Deposit Requirement | Actionable deposit commitment |
| Option or release date | Deadline | Actionable commitment line |
| Rooming list due | Deadline | **Informational** |
| Final payment (amount not modeled) | Deadline `other` | Actionable commitment line unless configured informational |
| Deposit date already represented by a Deposit Requirement | None additional | Never duplicate as a Deadline |

`other` requires the user to explicitly choose actionable or informational when not implied by template. Do not invent Celebrity `legal_names_due`.

### 22.7 Legal names versus rooming list — locked

For the canonical fixture, create only the contracted **rooming-list** obligation. Do not invent a `legal_names_due` requirement.

`names_assigned_to_supplier` remains the final-deposit trigger only. Parent Stop D must not invent a separate legal-names Deadline for the Celebrity fixture.

### 22.8 Successor reconciliation — locked

| Proposed successor change | Result |
| --- | --- |
| Definition and authority facts unchanged; predecessor commitment terminal | Preserve history; do not reopen |
| Definition unchanged; predecessor commitment still open | Create the successor occurrence and supersede the predecessor through lineage |
| Material definition, coverage, formula, timing, or commitment-line authority changed | Create a new successor occurrence; supersede the open predecessor |
| Definition removed while predecessor has an open commitment | Block activation until the commitment is resolved |
| Definition removed after predecessor commitment is terminal | Permit omission; retain predecessor history |
| Elapsed occurrence or ambiguous partial fulfillment | Route to Advanced planning; do not rewrite history |
| Change requiring payment reallocation, split/merge, or source remapping | Route to Advanced planning |

“Replace” means lineage-based supersession. It never means editing or deleting the predecessor occurrence.

### 22.9 Definition deletion — locked

Hard deletion is permitted only for an unsaved/unactivated draft definition with no materialized occurrences, tranches, or other dependents.

For a successor draft:

- Removing the copied definition records a proposed omission.
- Activation is allowed when the predecessor obligation is terminal.
- Activation is blocked while the predecessor commitment remains open.
- The user must satisfy, release, or waive that commitment through the existing operational workflow.
- Historical definitions, occurrences, tranches, and audit records remain intact.

No separate “abandoned definition” state is required for 2B.

### 22.10 Percentage deposit bases — deferred from typed catalog

Exclude percentage deposits from the typed 2B Cruise workspace. They remain Advanced planning only.

### 22.11 Commands, routes, reorder, duplicate — locked

Use public M3E mutation commands and the Cruise compile/detect/preview services named in §14. Do not include reorder or duplicate in the first release.

---

## 23. Stop D consequence

Stop D typed Celebrity proof requires shipped 2B-R Path B economics (`capacity_pool_units`, source-aware cumulative). Those are shipped; this adapter must express “initially blocked cabins,” “retained cabins,” and `$500 × retained` cumulative calculation through the typed controls.

---

## 24. Exit criteria

Slice 2B is complete when:

1. Staff can construct the accepted Celebrity Deposit and Deadline definitions entirely through visible typed controls (2B-R and 2A.2R3 already shipped).
2. Definitions are Arrangement-owned, independently saved, and mapped only to generic M3E records.
3. Deposit previews expose exact quantities, sources, coverage, and calculations.
4. Earlier-of timing remains one rule and one operational requirement.
5. Activation preview names exact materialization consequences and blockers and writes nothing.
6. Activation creates the intended immutable M3E occurrences, tranche, and commitments exactly once.
7. Active definitions are read-only and operational state uses accurate non-accounting language.
8. Successor editing never mutates governing definitions or historical materializations.
9. Advanced definitions are preserved and isolated without disabling compatible siblings.
10. Validation, concurrency, tenancy, accessibility, responsive, and keyboard proof is green.
11. No Client, Traveler, Obligation, Payment, Receipt, or accounting record is created.
12. Documentation marks 2B Shipped and names Slice 2C as the next unauthorized boundary.

---

## 25. Handoff

After 2B ships, the next planned slice is **M4D.1 Slice 2C — Connect Cruise, categories, and Client choices**. 2B does not authorize that work.
