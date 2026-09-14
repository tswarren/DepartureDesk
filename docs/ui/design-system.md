# DepartureDesk design system

**Status:** Active visual contract
**Implementation authority:** `app/assets/tailwind/application.css`

DepartureDesk should feel operationally calm, financially trustworthy, travel-oriented without becoming decorative, and information-dense without becoming cramped. The [Harbor & Waypoint palette](../palette.md) supplies the color system; this document governs reusable composition and interaction.

## Foundations

- Use IBM Plex Sans for interface text and IBM Plex Mono for identifiers and aligned numeric data where the distinction helps scanning.
- Use the existing 4px-derived spacing scale and modest 6–8px radii.
- Prefer borders and surface contrast to heavy shadow.
- Keep the persistent application frame navy, interactive/selected states teal, and keyboard focus amber.
- Reserve semantic green, red, blue, and gray for operational meaning. Color never communicates state alone.
- Reuse `dd-` tokens and component classes before introducing a new pattern.

## Application frame

- The authenticated shell provides a skip link, top bar, primary navigation, account context, and a main landmark.
- Navigation links appear only when the route and permission exist. A disabled future label is explanatory, not interactive.
- The active destination uses `aria-current="page"`, a teal indicator, and visible text—not color alone.
- Mobile navigation uses a labeled button, focus containment while open, Escape dismissal, and focus restoration.
- Office selection displays subordinate operating context and must never imply authorization.

## Content hierarchy

- Each workspace has one page title, concise context, and at most one visually primary action.
- Prefer display-first detail pages. Editing occurs on a focused create/edit page or in one selected row/composer at a time.
- Cards group related facts; they are not a default wrapper around every field.
- Tables carry dense comparable records. Definition rows or compact lists carry heterogeneous detail.
- Use responsive stacking instead of squeezing multi-column records below their readable width.

## Components

### Buttons and links

- Primary buttons use Action Teal and describe the result with a verb.
- Secondary actions remain visually quieter. Destructive actions use the danger palette, not amber.
- Icon-only buttons require an accessible name and tooltip where the icon may be unfamiliar.
- Row actions remain reachable by keyboard and do not depend on hover.

### Forms

- Every field has a persistent visible label. Placeholder text is never the only label.
- Required fields are identified textually or with a conventional marker and explained once.
- Validation errors appear beside the field and in an accessible summary when the form is substantial.
- Required fields do not live inside a closed disclosure.
- Submitted values survive validation failure.
- Consequential actions use a focused confirmation surface with consequences, reason/evidence when required, and an explicit destructive action.

### Tables

- Use visible horizontal separators, restrained vertical rules, numeric alignment, and explicit empty/filter states.
- Row selection and attention states use label/icon plus color.
- Responsive behavior may prioritize columns or convert a row to a labeled detail layout; it must not silently hide required facts or actions.

### Status and calculated values

- Editable lifecycle controls show only valid next transitions and submit to server commands.
- Derived statuses have no editable affordance.
- Projected, confirmed, posted, and actual values use explicit labels, not color alone.
- Never optimistically render a calculated balance, capacity, margin, or lifecycle result. Wait for the server-authoritative response.

### Empty and unavailable states

Distinguish actionable empty, positive empty, filtered-no-results, inline empty, permission-limited, loading, and error states. Permission-safe states must not leak hidden counts or record existence.

## Turbo and Stimulus

- Persisted changes use real form submissions and server-rendered Turbo responses.
- Stimulus manages local interaction such as drawers, disclosures, focus, and already-loaded filtering—not domain decisions.
- Every workflow must retain a coherent non-JavaScript path unless an accepted slice explicitly requires otherwise.
- Loading indicators do not replace the existing content until the server confirms the result.

## Accessibility and responsive proof

For every new surface, verify:

- landmark and heading hierarchy;
- visible labels and accessible names;
- logical keyboard order, Escape behavior, focus movement, and focus restoration;
- error association and announcement;
- status meaning without color;
- zoom/reflow and horizontal overflow;
- 375px, 768px, reference desktop, and 1280px layouts; and
- no unauthorized or hidden information in the DOM, accessibility tree, counts, or Turbo payloads.

## Archived references

The CAI 2026-09-07 HTML mockups and Party-era design system are preserved under [`../archive/v0.02/ui/`](../archive/v0.02/ui/). They may inspire composition, but their Party pickers, shared Party profiles, routes, data ownership, and domain examples are not current authority.
