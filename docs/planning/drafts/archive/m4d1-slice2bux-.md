Yes. The refactor improved the wording, but the page still has essentially the same document structure. The form is just another unbordered `dd-stack` inserted between saved deposits and saved deadlines, so it reads as though all of it is one continuous record.

I would make a stronger structural change: **the overview page should never render an Add/Edit form inline.** Deposit and deadline editors should be dedicated pages.

## What is still wrong

### 1. Saved records do not have containers

Each saved definition is currently:

```html
<li class="dd-stack">
  <h3>...</h3>
  <dl class="dd-definition-list">...</dl>
  <div>Edit / Remove</div>
</li>
```

There is no border, background, header, footer, or spacing boundary around each record. The two deposits visually run together, and the second immediately runs into the form.

Each definition needs to be a card or table row with:

* A distinct header
* A status badge
* Aligned facts
* A visually separate action footer

### 2. Deposits and deadlines share one outer panel

The rendered page has one large `dd-panel` containing both sections. That is why the entire lower page looks like one white canvas.

Make them separate panels:

```text
[Deposit requirements panel]

[Supplier deadlines panel]
```

Each panel gets its own header, body, Add action, and Advanced footer.

### 3. The form is still inline

The current form is:

```html
<section class="dd-stack" id="cruise-deposit-editor">
```

inside the Deposit requirements section. It has no editor shell and pushes the deadline panel far below the fold.

For these forms, I would abandon the inline-editor requirement. They are too long and conditional for an inline form or narrow drawer.

Use dedicated routes


Yes. The refactor improved wording, but the page still uses the same structural model: saved records, activation review, and the active form all live inside one large panel. They therefore read as one continuous document.

The most important change is: **stop opening these forms inside the workspace.**

## Recommended interaction model

Use separate pages for editing.

### Workspace page

The deposits-and-deadlines workspace should contain only:

* Page header
* Compact readiness banner
* Saved deposit requirements
* Saved Supplier deadlines
* Add/Edit/Remove or operational actions

It should never render `_deposit_form` or `_deadline_form`.

### Form pages

Add dedicated routes:

```text
GET .../deposits-and-deadlines/deposits/new
GET .../deposits-and-deadlines/deposits/:id/edit

GET .../deposits-and-deadlines/deadlines/new
GET .../deposits-and-deadlines/deadlines/:id/edit
```

The existing POST/PATCH/DELETE routes remain.

Links become:

```text
Add deposit  → deposits/new
Edit deposit → deposits/:id/edit
Add deadline → deadlines/new
Edit deadline → deadlines/:id/edit
```

After Save or Cancel, return to the workspace and focus the corresponding saved record.

This is preferable to an inline Turbo Frame, modal, or side drawer because these forms are long, conditional, and sometimes contain cumulative calculations or earlier-of timing arms. They need a real task surface.

## 1. Make the workspace genuinely list-first

The current HTML has one outer panel:

```html
<article class="dd-panel" id="cruise-deposits-and-deadlines">
  Deposit section
  Deposit form
  Deadline section
</article>
```

That should become two independent panels:

```text
┌ Deposit requirements ─────────────────────── [+ Add deposit] ┐
│ Saved deposit cards                                         │
└──────────────────────────────────────────────────────────────┘

┌ Supplier deadlines ──────────────────────── [+ Add deadline] ┐
│ Saved deadline cards                                        │
└──────────────────────────────────────────────────────────────┘
```

The form should not appear between the saved deposits and Supplier deadlines.

## 2. Give every saved record a visible container

The saved records are currently plain `li.dd-stack` elements. There is no border, background, spacing boundary, or header/footer structure. That is why they look like loose form labels.

Use cards with three explicit regions:

```text
┌──────────────────────────────────────────────────────────────┐
│ Initial deposit                              [Blocked badge] │
├──────────────────────────────────────────────────────────────┤
│ Type          Initial                                      │
│ Amount        $50.00 per initially blocked cabin           │
│ Due           September 30, 2026                           │
│ Coverage      E3, O1, I1, and OS cabin pools               │
├──────────────────────────────────────────────────────────────┤
│ [Edit]                                           [Remove]   │
└──────────────────────────────────────────────────────────────┘
```

Recommended markup:

```html
<article class="dd-definition-card">
  <header class="dd-definition-card__header">
    <h3>Initial deposit</h3>
    <span class="dd-status-badge dd-status-badge--warning">Blocked</span>
  </header>

  <dl class="dd-fact-grid">
    ...
  </dl>

  <footer class="dd-definition-card__actions">
    ...
  </footer>
</article>
```

On desktop, display cards in a responsive two-column grid. On narrower screens, use one column.

The current `dd-definition-list` is a vertical grid, so every value occupies a separate line and leaves most of the panel empty. Use the existing two-column `dd-fact-grid` pattern or introduce a card-specific fact grid.

## 3. Make Add actions unmistakable

The screenshot does not clearly separate “Add deposit requirement” from the records because the form heading appears immediately after the second record.

Put the Add button in the panel header:

```text
DEPOSIT REQUIREMENTS
Amounts and due rules required by the Supplier agreement.

                                           [+ Add deposit]
```

Do the same for deadlines.

Do not automatically open a blank form when entering the workspace. The default page must always show the saved-state overview.

## 4. Give form pages a distinct visual identity

A deposit form page should look like a task, not another saved record.

```text
← Back to deposits and deadlines

ADD DEPOSIT REQUIREMENT
Celebrity Beyond · Draft · USD

┌ Requirement ────────────────────────────────────────────────┐
│ Deposit type   [Initial deposit                         ▾]  │
│ Name           [Initial deposit                          ]  │
└──────────────────────────────────────────────────────────────┘

┌ Amount and cabins ──────────────────────────────────────────┐
│ Calculate as   [Amount per initially blocked cabin      ▾] │
│ Amount         [$ 50.00                                  ] │
│ Cabin pools    ☑ E3  ☑ O1  ☑ I1  ☑ OS                    │
└──────────────────────────────────────────────────────────────┘

┌ Due date ───────────────────────────────────────────────────┐
│ Due             [On a specific date                     ▾] │
│ Date            [09/20/2026                              ] │
└──────────────────────────────────────────────────────────────┘

┌ Summary ────────────────────────────────────────────────────┐
│ $50.00 per initially blocked cabin, due September 20,       │
│ 2026, for four cabin pools.                                 │
└──────────────────────────────────────────────────────────────┘

[Save deposit]  [Cancel]
```

On wide screens, the Summary can be a sticky right-hand panel. On mobile, it follows the form sections.

Use the same structure for deadlines:

* Requirement
* Due date
* Coverage and operational effect
* Summary

## 5. Remove developer-facing explanations

This text should not appear:

> Template choice is a creation affordance only. It is not stored as a separate field.

That is an internal implementation note. Staff only need to understand what selecting the type does.

Replace it with:

> Choose the kind of deposit required by the Supplier agreement.

Likewise:

* “Semantic type” → “Type”
* “Timing rule” → “Due”
* “Capacity Pool units” → “Initially blocked cabins” or “Retained cabins”
* “Operational effect” can remain, but its value should be explanatory:

  * “Action required”
  * “Informational only”

## 6. Simplify the readiness banner

The yellow banner is better, but `View activation details` contains another complete definition listing inside the alert. Expanding it will once again dominate the page.

I recommend a separate activation review page:

```text
Review issues          → activation review, issues section
View activation details → activation review, full consequence section
```

The workspace banner stays compact:

```text
┌──────────────────────────────────────────────────────────────┐
│ ⚠ Not ready to activate                         1 issue     │
│ Cabin opening quantities are incomplete.                    │
│                                                              │
│ [Open cabin inventory]  [Review activation]                 │
└──────────────────────────────────────────────────────────────┘
```

There is no need for both “Review issues” and an identical issue list inside the banner.

## 7. Correct the remaining data/display contradictions

The screenshot still shows:

```text
Initial deposit
Type: Final
```

That is not only visual. The persisted description is still “Initial deposit” while the detector recognizes a Final template.

Handle existing compatible records:

* If the description exactly equals another template’s generated default and has never been Staff-authored, display and save the correct template default.
* Preserve genuinely custom Staff names.
* Add a regression for Initial → Final template changes.
* Consider a narrow remediation for already-created contradictory draft definitions.

Also correct the activation detail date:

```text
2026-09-30 (America/New_York) (America/New_York)
```

The time zone is being appended twice.

## 8. Clarify status

“Blocked” currently appears as another ordinary definition-list value. It needs visual and semantic prominence.

Use badges:

* Ready — neutral or positive
* Needs attention — amber
* Blocked — amber/red depending on whether it prevents activation
* Open — operational
* Informational — neutral

For blocked cards, include the reason directly beneath the facts:

```text
⚠ Opening quantities are missing for the selected cabin pools.
  Open cabin inventory →
```

Do not make Staff return to the banner to learn why the row is blocked.

## 9. Improve action hierarchy

Current `Edit` and `Remove` links look nearly identical.

Recommended:

* Edit: quiet button or standard row action
* Remove: destructive text/button placed last
* Advanced planning: quiet footer link
* Add: primary button in panel header
* Save: primary
* Cancel: quiet button, not an uncontained link

For activated records, replace Remove with the valid operational actions.

## 10. Concrete implementation delta

I would give the developers this change list:

1. Add `new` and `edit` routes/actions for typed deposits and deadlines.
2. Remove all form rendering and editor query-parameter handling from the workspace `show`.
3. Move deposit and deadline forms into dedicated page templates with shared section partials.
4. Redirect successful mutations with `303 See Other` back to the workspace.
5. Render deposits and deadlines in independent `dd-panel` containers.
6. Introduce a reusable `dd-definition-card` and responsive `dd-definition-grid`.
7. Use card headers, status badges, fact grids, issue messages, and action footers.
8. Move Add buttons into panel headers.
9. Move activation details to a dedicated review page or, at minimum, outside the alert and outside the main lists.
10. Remove implementation-language help text.
11. Repair generated-name synchronization and existing contradictory display.
12. Remove duplicated time-zone rendering.
13. Add focus restoration using `focus_deposit_id` / `focus_deadline_id`.
14. Test direct navigation, Save, Cancel, validation recovery, Remove, browser Back, and narrow viewports.

## Acceptance test

A simple visual acceptance rule would be:

> With no editor open, Staff can see every saved deposit and deadline, its status, and its available actions without encountering any form fields. Selecting Add or Edit takes Staff to a page whose title and surrounding panel unmistakably identify that they are editing unsaved information.

That is the missing boundary in the current refactor. The labels are better, but until saved information and unsaved editing are separate screens, the page will continue to feel like one long administrative form.
