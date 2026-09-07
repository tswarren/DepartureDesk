# DepartureDesk Presentation and Interface Contract

> This document describes proposed future-state presentation patterns. The current application does not implement every listed primitive. For the UX party-record prototype, `docs/planning/phase-2-ux-refactor/ux-foundation-party-record-prototype.md` and its planning addendum define the in-scope subset. Prototype values become canonical only after the stakeholder visual-review gate.

This is the presentation contract for application layouts, tenant administration, travel operations, and party-local directory pages. It does not change routes, commands, or terminology.

Reuse these `.dd-` classes before adding new presentation rules. Do not introduce ViewComponent, third-party icon fonts/gems, or view-specific CSS files.

---

## Application Frame & Shell

The application wraps all view templates inside a persistent layout frame:

```
dd-app-shell
  dd-sidebar
    dd-sidebar-brand
    dd-sidebar-nav
    dd-sidebar-footer
  dd-main
    dd-topbar
    dd-workspace

```

* `.dd-app-shell` is a two-column grid shell. On screens smaller than 768px, `.dd-sidebar` collapses into a toggleable drawer.
* `.dd-sidebar` uses persistent Departure Navy (`#002340`) background with `#FFFFFF` text on active/selected items.


* Active vertical nav items use `.is-active` with Route Teal (`#007080`) background accenting.


* `.dd-topbar` hosts the global search input (`.dd-global-search`), contextual help links, and the user profile dropdown.

---

## Page Anatomy

```
dd-breadcrumbs     optional location hierarchy above page title
dd-page-header
  dd-page-heading   eyebrow, title, description, optional quiet back link
  dd-page-actions   at most one primary header action
dd-subnav           horizontal navigation tabs
dd-metrics-grid     optional row of 1-4 key performance indicator cards
dd-filter-bar       optional search and collection filters
dd-panel+

```

* `.dd-page-header` is a horizontal row that stacks at the existing 600px breakpoint.


* `.dd-page-actions` wraps header buttons and stacks with them at 600px.


* `.dd-subnav` is a horizontal link row. The current item uses teal, never amber. Mark it with `aria-current="page"` on a `nav` element.


* Child pages (team member, invitation, office edit, trip package detail) still render the shared subnav. Place a quiet “Back to …” link in the breadcrumb or page heading, not a loose paragraph.



---

## Metric Summary Cards

Wrap operational highlights in a `.dd-metrics-grid` container. Cards stack on mobile (375px) and expand to 4 columns at 1280px.

| Region | Class | Description |
| --- | --- | --- |
| Container | `.dd-metric-card` | White surface with standard border and `1rem` padding |
| Icon | `.dd-metric-card-icon` | Circular background using soft semantic surface fills |
| Title | `.dd-metric-card-label` | Muted slate label text (`--dd-text-muted`) |
| Value | `.dd-metric-card-value` | Large numeric display (`1.75rem` font size) |
| Subtext | `.dd-metric-card-subtext` | Faint supporting detail or status context (`--dd-text-faint`) |

---

## Collection Filter Bar

Place `.dd-filter-bar` directly above operational tables or list views:

* `.dd-filter-input`: Text search input with integrated search icon.
* `.dd-filter-select`: Dropdown controls for status, date range, or destination filtering.
* `.dd-filter-reset`: Quiet link (`.dd-button--quiet`) to clear active filter parameters.



---

## Panel Anatomy

`.dd-panel` has no padding of its own.

| Region | Class | Spacing |
| --- | --- | --- |
| Header | `.dd-panel-header` | existing header padding and bottom border |
| Body | `.dd-panel-body` | `1rem` padding |
| Footer | `.dd-panel-footer` | `1rem` padding and a top border |

Put readable content in the body. Use the footer for submit rows or lifecycle actions when they belong to that panel. Definition lists inherit body padding; they do not add a second inset.

---

## Icon Strategy

Do not import third-party icon libraries or font gems. Manage iconography using curated raw SVG partials in `app/views/shared/icons/` and render them via the `icon_tag` helper:

```erb
<%= icon_tag "calendar", class: "dd-icon--sm" %>

```

* All SVG assets must use `viewBox="0 0 24 24"` or `viewBox="0 0 256 256"` and set `stroke="currentColor"` / `fill="currentColor"` to inherit text color dynamically.


* Icons carry `aria-hidden="true"` by default; accessible text must be supplied in surrounding markup.


* Dimension utility classes: `.dd-icon--sm` (16px), `.dd-icon--md` (20px), `.dd-icon--lg` (24px).

---

## Button Hierarchy

| Emphasis | Class | Use |
| --- | --- | --- |
| Primary | `.dd-button` | The one main action in a header or section |
| Secondary | `.dd-button--secondary` | Alternate constructive actions (reactivate, edit package, grant) |
| Danger | `.dd-button--danger` | Destructive actions. Uses danger tokens, not amber |
| Quiet | `.dd-button--quiet` | Cancel, clear filters, and back links |
| Compact | `.dd-button--small` | Table row actions or tight panel options |

* At most one visually primary button per section.


* `.dd-button-group` aligns general actions and stacks at 600px.


* Reserve `.dd-form-actions` for form submit rows. Danger actions keep their existing `turbo_confirm` copy.



---

## Field Anatomy

`.dd-form` has a readable max-width of about 40rem.

* Text and select fields share `.dd-field` height.


* Related fields may use `.dd-form-grid.dd-form-grid--two-column`, which becomes one column below 768px.


* Office codes, currency, and numerical metrics use `.dd-field--code`.


* Checkbox and radio labels use `.dd-choice` inside `.dd-choice-group`. Do not use `.dd-label` as the clickable choice row.


* Hints use `.dd-field-hint`. Grouped invitation or lifecycle copy may use `.dd-form-section`.


* Editable forms that can fail expose a summary alert plus per-field errors with `aria-invalid` and `aria-describedby`.



---

## Status Presentation

Badges pair a title-case label with a color modifier. Stored enum values stay lowercase in the database.

| Helper | Success | Info | Warning | Danger | Neutral |
| --- | --- | --- | --- | --- | --- |
| `agency_status_badge`<br> | Active | — | Suspended  | — | Closed  |
| `membership_status_badge`<br> | Active | Invited | Suspended | — | Revoked |
| `membership_role_badge`<br> | — | Administrator | — | — | Staff |
| `office_status_badge`<br> | Active | — | — | — | Inactive |
| `party_kind_badge`<br> | — | Person / Household / Organization | — | — | — |
| `party_status_badge`<br> | Active | — | — | — | Deactivated |
| `role_profile_status_badge`<br> | Active | — | — | — | Inactive; **Not assigned** and **Ineligible**<br> |
| `contact_point_status_badge`<br> | Active | — | — | Do not use | Deactivated |
| `departure_status_badge`<br> | Open for sale | Upcoming / Planning | Needs attention | Overdue / Cancelled | Draft / Closed |
| `milestone_status_badge`<br> | Confirmed | Opens soon / Upcoming | Action required | Overdue | Completed |

Never communicate status by color alone. Amber is a waypoint/attention indicator, not the do-not-use or destructive color.

---

## Tables & Financial Presentation

Wrap operational tables in `.dd-table-wrap` inside `.dd-panel-body` so wide rows scroll instead of overflowing. Use the standard empty state when a collection is empty.

* **Capacity & Progress Indicators:** Progress bars use `.dd-progress` (track) with `.dd-progress-bar` (Route Teal fill).


* **Cell Hierarchy:** Primary title text uses `.dd-cell-title`; supporting detail uses `.dd-cell-subtext`.
* **Financial Cells:** Align currency and margin figures to the right. Negative or past due values use `.dd-text-danger` (`#B5473D`) alongside explicit negative signifiers (`-` sign or text labels).


* **Row Actions:** Use `.dd-action-menu` (three-dot quiet trigger) for row operations instead of cluttering rows with multiple text buttons.

---

## Responsive Checkpoints

Verify all pages, forms, tables, and action groups at:

| Width | Intent |
| --- | --- |
| 375px | Sidebar drawer collapses; header actions, subnav, choice rows, and button groups stack; tables remain inside `.dd-table-wrap`<br> |
| 768px | Sidebar expands into regular layout; two-column form grids collapse to one column |
| 1280px | Heading and primary action share a row; metric cards expand to 4 columns; tables use full workspace width |

Keep the skip link and Waypoint Amber (`#F49A00`) focus ring working across all interactive elements. Keyboard focus must reach primary fields and table controls.