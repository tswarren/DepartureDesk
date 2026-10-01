# M4D.1 Slice 2B-UX — Deposits and Deadlines Workspace Remediation

**Status:** Shipped 2026-09-23. Sole shipped authority for typed Cruise Stop D workspace remediation (task-flow, interaction, and defect repair). Parent [M4D.1](m4d1-departure-composition-workspace.md) remains Accepted for later slices. Shipped [Slice 2B](m4d1-slice2b-cruise-deposits-deadlines-and-activation-safe-editing.md) / [2B-R](m4d1-slice2br-cruise-deposit-semantics-amendment.md) / M3E semantics remain authoritative. Contributor-position collision closure and milestone-authority reconcile: [Slice 2B-UX-R](m4d1-slice2buxr-contributor-replace-and-closure.md). Slice 2C+, Client connection, and M4E remain unauthorized until named.

**Parent authority:** [M4D.1 Slice 2B](m4d1-slice2b-cruise-deposits-deadlines-and-activation-safe-editing.md), shipped M3E/ADR 0013 operational semantics, and shipped 2B-R deposit economics. This remediation changes the typed Cruise workspace and repairs defects; it does not reinterpret deposit, deadline, activation, successor, or commitment semantics.

**Accept package base:** Tip of green `main` including shipped Slice 2B (merge of 2B-C). Implementation branches from that tip after the deposit child-replacement unblock.

**Ship commit:** Merge tip [`bba974c`](https://github.com/tswarren/DepartureDesk/commit/bba974c) (PR #151). Documentation Mark Shipped and contributor-replace closure: [Slice 2B-UX-R](m4d1-slice2buxr-contributor-replace-and-closure.md).

**Locked Accept caveats:**

1. Compact readiness counts may supplement; an on-demand disclosure must still expose full Slice 2B §10.2 definition-level activation consequence rows.
2. Operational actions on this surface are named deep links into shipped M3E Arrangement chrome (`return_to=cruise_deposits_and_deadlines`), plus the existing typed milestone form. Do not rebuild disposition engines here.
3. Three visible editor sections are presentation over Slice 2B’s five-step deposit content (including 2B-R contributors).
4. Planning milestones follow shipped M3E: Arrangement-local future `occurred_on` is permitted; pre/post-fallback replacement rules stay as shipped M3E. Do not tighten milestone dates beyond M3E.

## 1. Outcome

Make the Cruise **Deposits and deadlines** workspace understandable and dependable for Staff.

The page must organize the work around four questions:

1. What deposit requirements and Supplier deadlines exist?
2. What needs attention before activation?
3. What definition am I adding or editing?
4. After activation, what operational action is available?

The default experience is list-first. Existing definitions are presented as concise business summaries. Only one editor may be open at a time. Activation consequences are summarized without duplicating the definition lists. Draft removal and activated operational resolution are visibly different actions.

This is a task-flow remediation, not a cosmetic restyle.

## 2. Problems being corrected

The shipped page exposes definition and evaluator detail as one long document. Activation preview, deposit summaries, an expanded deposit form, advanced links, and deadline summaries all compete at the same visual level.

Observed problems include:

- Activation consequences duplicate the deposit and deadline lists.
- The same blocker can appear globally and more than once on a row.
- Definitions are rendered as long prose strings that are difficult to compare.
- Opening an editor pushes unrelated sections far below the fold.
- “Open definition” scrolls to a summary instead of opening its editor.
- Template changes can retain an earlier generated name, producing contradictions such as “Initial deposit · Final deposit.”
- Technical terms such as `amount_shape`, `quantity_basis`, and “Capacity Pool units” dominate the Staff-facing form.
- Draft **Remove** and activated operational disposition are not explained as different lifecycle operations.
- The current page mixes full Turbo Drive navigation with manually fetched previews without a single, explicit interaction model.
- Deposit child replacement can violate non-null foreign keys during update.
- A future planning-milestone date can be accepted even though it does not yet alter the earlier-of calculation.

## 3. Scope

### 3.1 In scope

- Reformat the typed Cruise deposits-and-deadlines workspace.
- Introduce a standard page header and page actions.
- Replace the expanded activation-consequence list with a compact readiness summary and an on-demand detail view.
- Present deposit and deadline definitions as structured rows or cards with consistent fields.
- Provide one contained Add/Edit editor at a time.
- Replace generic evaluator vocabulary with Staff-facing business language.
- Correct template/generated-name synchronization.
- Deduplicate readiness blockers and link each correctable issue to the workspace that owns the missing fact.
- Distinguish draft definition removal from activated operational resolution.
- Provide direct operational actions or specific deep links for activated rows.
- Normalize Turbo/navigation behavior.
- Repair deposit child replacement. Do not tighten planning-milestone dates beyond shipped M3E.
- Add responsive, keyboard, focus, Turbo-history, and lifecycle system proof.

### 3.2 Non-goals

- New deposit economics or amount shapes.
- Typed percentage deposits.
- New M3E tables, occurrences, tranches, commitments, or dispositions.
- Deleting activated definitions or materialized operational history.
- Reordering or duplicating definitions.
- Payment, Obligation, or `paid` language.
- Redesigning generic Advanced Supplier-planning pages.
- Implementing later M4D.1 slices.

## 4. Information architecture

The page renders in this order:

1. Page header.
2. Compact readiness/operational-state banner.
3. Deposit requirements panel.
4. Supplier deadlines panel.
5. Secondary Advanced links within their owning panels.

The activation preview must not repeat the complete deposit and deadline summaries above those panels.

### 4.1 Page header

Use the standard `dd-page-header` pattern.

- Eyebrow: `Cruise Supplier planning`.
- Title: `Deposits and deadlines`.
- Description: Arrangement name, version status, and operating currency.
- Primary contextual action: none in the header.
- Secondary action: `Back to Cruise`.
- Advanced planning must be a quiet secondary action, not a peer of Add/Edit.

### 4.2 Draft readiness banner

For a draft version, show one summary panel immediately beneath the header.

Ready state:

- Heading: `Ready for activation review`.
- Summary counts: total deposit requirements, Supplier deadlines, and actionable commitments expected.
- Actions: `View activation details` and `Activate Arrangement`.

Blocked state:

- Heading: `Not ready to activate`.
- Show the number of unique blocking issues.
- Summarize the highest-value corrective action in plain language.
- Actions: `Review issues` and `View activation details`.
- Render `Activate Arrangement` disabled or omit it. Do not present an apparently available activation action that is known to fail.

Activation details are hidden initially in an accessible disclosure or live in a dedicated review surface. They show:

- Unique blocking issues.
- The owning definition or source fact.
- A corrective link to the workspace that owns the missing fact.
- Definition-level materialization consequences.
- A statement that activation creates no Supplier Payment, Obligation, or paid record.

If a deposit calculation is blocked by a cabin opening quantity, the corrective link opens cabin inventory—not the deposit editor.

### 4.3 Activated state banner

For the governing activated version:

- Heading: `Governing operational terms`.
- Explain that definitions and materialized facts are retained as history.
- If allowed, provide `Create successor draft`.
- Do not offer Edit or Remove for governing definitions.

### 4.4 Successor state banner

For a successor draft:

- Heading: `Proposed successor terms`.
- Explain that governing occurrences and commitments remain in force until activation.
- Each changed row shows governing terms, proposed terms, and reconcile foreshadow.
- Removing a successor definition must be labeled `Remove from successor`, not simply `Remove`, when the definition has governing lineage.

## 5. Deposit requirements panel

### 5.1 Panel header

- Title: `Deposit requirements`.
- Description: `Amounts and due rules required by the Supplier agreement.`
- Draft action: `Add deposit`.

### 5.2 Definition summaries

Each summary presents stable labeled fields rather than a concatenated sentence:

- Name.
- Semantic type: Initial, Final, or Other.
- Amount or cumulative calculation.
- Due rule.
- Coverage.
- Readiness or operational status.
- Available actions.

Desktop may use a table when the values remain readable. Narrow viewports use stacked cards. Do not require horizontal page scrolling.

Example Staff-facing amount language:

- `$50.00 per initially blocked cabin`.
- `$500.00 per retained cabin, less credited initial deposits`.
- `Fixed deposit of $2,500.00`.

Avoid presenting `quantity_times_rate`, `capacity_pool_units`, or `cumulative_target` as primary Staff labels.

### 5.3 Draft actions

Compatible draft rows provide:

- `Edit`.
- `Remove`.

Remove confirmation names the definition and states that only the draft definition and its draft children are removed. Successful removal returns to the Deposit requirements panel, announces success, and moves focus to the panel heading.

Advanced-shape rows provide a reason and one `Open advanced deposit` action. They do not present a broken typed editor.

### 5.4 Activated actions

Activated rows never provide Remove. They provide the actions valid for their operational state, including as applicable:

- `Record handled externally`.
- `Record names assigned`.
- `Open commitment`.
- `Create successor draft`.

If the action is not implemented on this typed surface, provide a specific deep link and name the action—not a generic `Open commitments` escape hatch alone.

## 6. Supplier deadlines panel

### 6.1 Panel header

- Title: `Supplier deadlines`.
- Description: `Dates that require Supplier action or provide operational information.`
- Draft action: `Add deadline`.

### 6.2 Definition summaries

Each row presents:

- Deadline name.
- Due rule or calculated date.
- Coverage.
- Operational effect: `Action required` or `Informational`.
- Readiness or operational status.
- Available actions.

Do not use `Other Supplier deadlines` as the section title; templates such as option/release and rooming list are first-class content of this panel.

### 6.3 Lifecycle actions

Draft rows provide Edit and Remove.

Activated actionable rows provide applicable shipped actions or deep links, such as Resolve, Reschedule, Waive, Cancel, Release, or Open commitment. Activated informational rows provide the shipped occurrence-management actions that apply. The page must explain why destruction is unavailable after activation.

## 7. Editor interaction contract

### 7.1 One editor

At most one deposit or deadline editor may be open. Opening another editor closes the first. Cancel returns to the unchanged list and restores focus to the initiating control.

The preferred implementation is one explicit Turbo Frame dedicated to the editor. Full-page Turbo Drive navigation is also acceptable if used consistently. Do not combine query-parameter page replacement, manual DOM reconstruction, and frame-targeted responses without an explicit contract.

Every successful create, update, and destroy action must redirect with `303 See Other`. Validation failures render the editor with status 422, preserve entered values, focus the error summary, and retain a stable frame/page target.

### 7.2 Editor structure

Deposit editors use three sections:

1. Requirement.
2. Amount and coverage.
3. Due date.

Deadline editors use three sections:

1. Requirement.
2. Due date.
3. Coverage and operational effect.

Each editor ends with a plain-language summary sentence immediately above Save and Cancel.

Conditional groups must be both hidden and disabled. Hidden inputs must not submit stale values. Changing shapes must not leave invisible contributors, pools, offsets, or timing arms in the payload.

### 7.3 Template and generated name

The editor tracks whether the name is auto-generated or Staff-authored.

- Selecting Initial deposit initially generates `Initial deposit`.
- Changing to Final deposit changes an untouched generated name to `Final deposit`.
- Changing to Other requires a Staff-entered name.
- Once Staff changes the name, later template changes preserve it.
- Reopening an existing definition must never infer a contradictory semantic label from a stale generated name.

Template is a creation/editing affordance; the durable M3E graph remains authoritative.

### 7.4 Deposit language

Use business choices:

- `Fixed amount`.
- `Amount per explicit quantity`.
- `Amount per initially blocked cabin`.
- `Cumulative amount per retained cabin`.

For a cumulative target, show contributors as `Credit these earlier deposits`. The live preview shows target, credits, and remaining requirement as separate lines.

### 7.5 Timing language

Use:

- `On a specific date`.
- `At a specific local date and time`.
- `Days before/after departure`.
- `Earlier of two events`.

For the Celebrity final deposit, name the milestone `Names assigned to Supplier` and the alternative `Fallback date`.

Do not offer a timing-arm shape unless the editor renders and submits all parameters needed by that shape.

## 8. Readiness and preview behavior

- Preview and mutation use the same pure candidate normalization and validation service.
- A candidate cannot be preview-ready if the corresponding create/update command will reject it.
- Deduplicate identical blocker and pending-reason text by normalized message and owning source.
- Amount previews distinguish `Ready`, `Cannot calculate yet`, and `Invalid`.
- Preview errors stay within the editor; they do not replace the whole workspace.
- Abort or ignore outstanding preview requests when the editor disconnects or a newer request exists.
- Activation-preview refresh must reproduce the same information and markup semantics as initial server rendering.
- `Open definition` must open the correct editor in draft state. In activated state it becomes `Open operational record` or another truthful action.

## 9. Functional defect remediation

### 9.1 Deposit child replacement

Do not use association `delete_all` to replace non-nullable deposit coverage, cost, or contributor links.

Update retained children in place where lineage must survive, explicitly destroy removed children, and create new children with all ownership keys. The operation remains transactional. A failure leaves the prior definition graph unchanged.

### 9.2 Planning-milestone dates

`Record names assigned to Supplier` records an occurred planning fact under shipped M3E rules. This remediation does **not** reject Arrangement-local future `occurred_on` (an early Accept draft that proposed rejection was reverted to keep M3E scenarios green).

- Accept Arrangement-local dates including future dates when M3E permits them.
- A future milestone date may be recorded even when it does not yet alter the earlier-of calculation.
- Reevaluate the earlier-of rule using the accepted occurrence when replacement applies.
- Replace only an unelapsed governing occurrence.
- Never open a duplicate deposit commitment.
- Preserve an elapsed historical fallback occurrence when the milestone is recorded afterward.

## 10. Accessibility and responsive behavior

- Use real headings, tables, lists, fieldsets, legends, and buttons.
- Status must not be conveyed by color alone.
- Error summary receives focus after a failed submission and links to invalid fields.
- After Save, focus the saved row heading.
- After Remove, focus the owning panel heading.
- Editor open/close state and activation-detail disclosure are keyboard operable.
- Confirmation dialogs name the affected definition.
- At 375 px, summaries become cards and actions wrap without horizontal page scrolling.
- At 768, 1280, and 1400 px, labels, values, and actions retain clear alignment.
- Live preview regions use restrained `aria-live` behavior and do not announce every keystroke unnecessarily.

## 11. Proof

### 11.1 Service and request tests

- Activation blockers are unique and point to the owning corrective workspace.
- Preview and mutation accept and reject the same candidates.
- Deposit update replaces child graphs without nulling required foreign keys.
- Failed deposit update preserves the previous graph.
- Template changes update untouched generated names and preserve Staff-authored names.
- Future planning milestones remain permitted under shipped M3E (not rejected by this remediation).
- An occurred pre-fallback milestone replaces the unelapsed due occurrence without duplicating the commitment.
- A post-fallback milestone preserves elapsed history.
- Draft removal succeeds independently for deposits and deadlines.
- Governing definitions cannot be destroyed.
- Mutation redirects use 303; validation renders 422.
- Viewer access remains read-only.
- Cross-agency records remain not found.

### 11.2 Blocking system tests

1. Draft default view shows compact readiness plus separate deposit and deadline panels; no editor is open.
2. Staff adds an initial deposit using business-language controls and returns to the saved row.
3. Staff changes Initial to Final before editing the generated name; the name becomes Final deposit.
4. Staff manually names an Other deposit, changes shape/template, and the custom name remains.
5. Staff edits a cumulative final deposit; target, credits, and remaining amount are visible and persist.
6. Staff removes a draft deposit and a draft deadline; each row disappears and focus returns correctly.
7. Invalid save preserves values and focuses the error summary.
8. Opening a second editor closes the first; Cancel restores focus.
9. Browser Back/Forward and Turbo restoration do not show stale editors or duplicate previews.
10. Activation blockers are deduplicated and activation is unavailable while blocked.
11. Correcting cabin quantities clears the owning blockers.
12. Activated view has no Remove actions and offers appropriate operational actions.
13. Successor view clearly distinguishes governing and proposed terms and permits `Remove from successor` without changing governing history.
14. Keyboard-only flows pass for add, edit, cancel, remove, readiness review, and activated actions.
15. Viewports 375, 768, 1280, and 1400 pass without page-level horizontal scrolling.

## 12. Delivery sequence

1. Repair the deposit child-replacement defect; keep planning milestones aligned with shipped M3E (do not reject future dates); make existing CI green.
2. Extract shared workspace summaries and deduplicated readiness facts.
3. Implement page header, readiness banner, and structured definition panels.
4. Implement the single-editor interaction and generated-name state.
5. Add activated and successor operational actions/labels.
6. Complete accessibility, responsive, Turbo-history, and lifecycle proof.
7. Update the interface contract with the shipped panel/editor patterns.
8. Mark 2B-UX Shipped after merge to green `main`; pin product ship/merge SHA [`bba974c`](https://github.com/tswarren/DepartureDesk/commit/bba974c) (PR #151). Contributor-replace collision and documentation closure: [Slice 2B-UX-R](m4d1-slice2buxr-contributor-replace-and-closure.md).

## 13. Exit criteria

The remediation is complete when:

- Staff can understand existing requirements without opening an editor.
- Adding or editing one definition does not obscure unrelated content.
- Every readiness issue appears once and points to the place where it can be corrected.
- Draft definitions can be removed reliably.
- Activated history cannot be destroyed and provides clear operational alternatives.
- Template changes cannot create contradictory labels.
- Deposit update and milestone scenarios are green.
- Turbo navigation, browser history, keyboard navigation, and responsive layouts pass blocking system proof.
- The complete test and system-test suites are green on the merge candidate.
