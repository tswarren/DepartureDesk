# Cruise form clarity

**Status:** Shipped 2026-10-07. Authority for Cruise form presentation and the shared field, hint, and section-title styles named here. Not authority for Hotel, Transportation, or Activity markup remediation, cost calculation, commission meaning, inventory modes, or activation rules.

**Baseline:** Inspected at `8e67d60`. Implement from current `main`. The written rules govern. `DepartureDesk-cruise-form-clarity-slice.md` is the proposal this plan accepts; the HTML mockup is not in the repository.

## Outcome

Staff can see what they can edit, what each field means, and which section a save affects. Ordinary Cruise forms use readable labels and clearly bounded controls. The Supplier rate matrix stays compact.

This slice changes presentation and component usage. It does not change which business facts are required, how costs are calculated, or when terms become confirmed or active.

## Scope

Correct Cruise markup that puts `.dd-field` around a label and `.dd-input` on the control. Move those forms to `.dd-field-group`, with `.dd-field` on the control. That includes agreement identity and its deposit, deadline, policy, and benefit partials; the Supplier rate shell; deposit and deadline editors; and inventory-change forms.

Sailing create and edit, cabin entry and edit, activation proof, and the benefit body already use `.dd-field-group` and `.dd-field`. Leave those controls in place.

Update generated controls in `cruise_rate_matrix_controller.js` with the same anatomy. Keep ids, names, Stimulus targets, authorization, and the agreement **Save for later** `formnovalidate` behavior.

Hotel, Transportation, and Activity keep their current markup for a later remediation. Shared label, hint, error, section-title, and readonly-cursor styles still apply wherever those classes are already used.

## Component contract

| Element | Component | Treatment |
| --- | --- | --- |
| Field wrapper | `.dd-field-group` | Label, control or affix, hint, and field error. No input border or background. |
| Label | `.dd-label` | `for`/`id`; 12.5px, weight 600, line-height 1.35. |
| Compact label | `.dd-label--compact` | 11px in dense editors. |
| Control | `.dd-field` | The bordered control. Do not change this meaning. |
| Hint | `.dd-field-hint` | Muted text, 11.5px, weight 400, line-height 1.4. `.dd-help` uses the same treatment. |
| Error | `.dd-field-error` | 11.5px, weight 500, line-height 1.4, danger text token. |
| Section heading | `.dd-section-title` | Navy token, 13px, weight 600, line-height 1.3, subtle bottom divider. |
| Actions | `.dd-form-actions` | Stay with the existing form and save boundary. |
| Affix | `.dd-field-affix`, `.dd-field-affix-text` | Symbol stays separate from the entered value. |

Use existing palette tokens for navy, muted text, dividers, and error text. Do not add borders to labels, hints, or subsections.

## Matrix and commission

Numeric rate-matrix controls have a 30px minimum height on desktop and at least 40px on small screens. Right alignment and IBM Plex Mono apply to those numeric controls. Profile selectors keep ordinary text alignment. The small-screen height rule must win over the desktop 30px rule. Ordinary `.dd-field` stays 34px, and 40px on small screens.

Keep **How is expected commission stated?** and the four methods: Not provided yet, No commission expected, Dollar amount, and Percentage.

Percentage keeps the **Commissionable** checkbox beside each component row, named for that component, and the separate Include / Subtract / Ignore table. Do not replace either control. Visual hiding must not discard selected components or write synthetic values. Unknown commission stays unknown, and explicit none stays distinct.

## Errors

This slice adds no new command-to-field error mappings. Preserve existing reliable associations, accessible hints, and `#form-error-summary` focus. Summary-only command failures stay in the summary, including stale lock and duplicate review. Do not invent an inactive-profile field focus for a failure the command does not associate with a control.

Preserve submitted values after command errors, including a deliberately cleared optional field. **Save for later** still bypasses confirmation-only browser validation.

## Non-goals

Do not change contracts, permissions, tenancy, exact-version scope, optimistic locks, idempotency, confirmation, correction, successor behavior, or atomic activation. Do not add ship directories, sailing codes, itinerary types, document storage, new save boundaries, or a different commission calculation.

Use the bundled IBM Plex fonts. Do not import fonts from Google.

## Proof

Agreement and rate posts still preserve values and show `#form-error-summary` for a command error. Tests do not assert only CSS class strings.

Keyboard navigation, 200% zoom, a narrow viewport, all four commission methods, and profile switching are part of rendered review. Entered amounts, selected Commissionable components, and Include / Subtract / Ignore treatments survive rerendering. One non-Cruise screen that already uses `.dd-section-title` shows the shared heading while keeping its existing wrapper markup.
