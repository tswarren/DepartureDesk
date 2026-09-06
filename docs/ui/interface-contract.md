# Administration and directory interface contract

This is the presentation contract for tenant administration, the office chooser, and party-local directory pages. It does not change routes, commands, or terminology. Dashboard metrics and the unauthenticated auth shell stay on their existing chrome unless they already share these `dd-` classes.

Reuse these classes before adding new presentation rules. Do not introduce ViewComponent, an icon library, or view-specific CSS.

## Page anatomy

```
dd-page-header
  dd-page-heading   eyebrow, title, description, optional quiet back link
  dd-page-actions   at most one primary header action
dd-subnav           Agency profile / Team / Offices, or party Overview / Contact information / Relationships / Notes
dd-panel+
```

- `.dd-page-header` is a horizontal row that stacks at the existing 600px breakpoint.
- `.dd-page-actions` wraps header buttons and stacks with them at 600px.
- `.dd-subnav` is a horizontal link row. The current item uses teal, never amber. Mark it with `aria-current="page"` on a `nav` labeled `Administration` or `Party`.
- Party-local subnav uses real links only when the corresponding route exists. Upcoming slices render disabled placeholders (`span[aria-disabled="true"]`), matching primary navigation.
- Child pages (team member, invitation, office new/edit/show, contact point new/edit) still render the shared subnav. Place a quiet “Back to …” link in the page heading or first panel, not a loose paragraph.

## Panel anatomy

`.dd-panel` has no padding of its own.

| Region | Class | Spacing |
| --- | --- | --- |
| Header | `.dd-panel-header` | existing header padding and bottom border |
| Body | `.dd-panel-body` | `1rem` padding |
| Footer | `.dd-panel-footer` | `1rem` padding and a top border |

Put readable content in the body. Use the footer for submit rows or lifecycle actions when they belong to that panel. Definition lists inherit body padding; they do not add a second inset.

## Button hierarchy

| Emphasis | Class | Use |
| --- | --- | --- |
| Primary | `.dd-button` | The one main action in a header or section |
| Secondary | `.dd-button--secondary` | Alternate constructive actions (reactivate, set default, grant) |
| Danger | `.dd-button--danger` | Destructive actions. Uses danger tokens, not amber |
| Quiet | `.dd-button--quiet` | Cancel and back links |
| Compact | `.dd-button--small` | Row actions |

- At most one visually primary button per section.
- `.dd-button-group` aligns general actions and stacks at 600px.
- Reserve `.dd-form-actions` for form submit rows.

Danger actions keep their existing `turbo_confirm` copy.

## Field anatomy

`.dd-form` has a readable max-width of about 40rem.

- Text and select fields share `.dd-field` height.
- Related name fields may use `.dd-form-grid.dd-form-grid--two-column`, which becomes one column below 768px.
- Office codes and currency use `.dd-field--code`.
- Checkbox and radio labels use `.dd-choice` inside `.dd-choice-group`. Do not use `.dd-label` as the clickable choice row.
- Hints use `.dd-field-hint`. Grouped invitation or lifecycle copy may use `.dd-form-section`.
- Editable forms that can fail expose a summary alert plus per-field errors with `aria-invalid` and `aria-describedby`.

## Status presentation

Badges pair a title-case label with a color modifier. Stored enum values stay lowercase in the database.

| Helper | Success | Info | Warning | Neutral |
| --- | --- | --- | --- | --- |
| `agency_status_badge` | Active | — | Suspended | Closed |
| `membership_status_badge` | Active | Invited | Suspended | Revoked |
| `membership_role_badge` | — | Administrator | — | Staff |
| `office_status_badge` | Active | — | — | Inactive |
| `party_kind_badge` | — | Person / Household / Organization | — | — |
| `party_status_badge` | Active | — | — | Deactivated |
| `role_profile_status_badge` | Active | — | — | Inactive; **Not assigned** and **Ineligible** use the neutral modifier |
| `contact_point_status_badge` | Active | — | — | Deactivated; **Do not use** uses the danger modifier |

Never communicate status by color alone. “Do not use” (suppressed, still current) uses red danger styling. Deactivated contact points use the neutral badge. Amber is not the do-not-use color. Administrator-only notes are labeled in text; they are not color-only.

## Tables

Wrap operational tables in `.dd-table-wrap` inside `.dd-panel-body` so wide rows scroll instead of overflowing. Use the standard empty state when a collection is empty.

## Responsive checkpoints

Verify administration headers, subnav, forms, tables, and action groups at:

| Width | Intent |
| --- | --- |
| 375px | Header actions, subnav, choice rows, and button groups stack or scroll; tables stay inside the wrap |
| 768px | Two-column form grids collapse to one column |
| 1280px | Heading and primary action share a row; tables and panels use the workspace width |

Keep the skip link and amber focus ring working. Keyboard focus must reach primary fields.
