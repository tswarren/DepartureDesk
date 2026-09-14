# DepartureDesk interface contract

**Status:** Active implementation contract
**Scope:** Current Agency identity and reusable patterns for later accepted slices

The [design system](design-system.md) defines product-wide visual and interaction behavior. This contract maps it to the current Rails application. Domain-specific sections must be added only with the slice that ships their routes and records.

## Implementation sources

| Concern | Current source |
| --- | --- |
| Theme and components | `app/assets/tailwind/application.css` |
| Authenticated shell | `.dd-app-shell`, `.dd-topbar`, `.dd-sidebar`, `.dd-main`, `.dd-workspace` |
| Shared icons | `icon_tag` and `app/views/shared/icons/` |
| Mobile navigation | `navigation_drawer_controller.js` |
| Development specimen | `GET /dev/ui` in development only |

Do not introduce ViewComponent, a third-party UI framework, an icon font, or per-view CSS without an explicit decision. Extend shared `dd-` primitives when a repeated need is demonstrated.

## Current navigation

- Dashboard is available to authenticated AgencyUsers.
- Administration is shown only when the current AgencyUser has an applicable management permission.
- Current Office selection is available to authenticated users and changes no authorization.
- Clients is shown when the current AgencyUser has `view_client_directory`.
- Directory, Suppliers, Departures, Travelers, and Accounting are absent until accepted slices ship their authorized routes.
- Active navigation uses `aria-current="page"` and a visible teal indicator.

## Page composition

- Use a page header with title, optional concise context, and one primary action.
- Use panels for coherent groups, not as nested decoration.
- Index pages use tables or compact rows when records share comparison fields.
- Show pages display facts first. Substantial edits use dedicated GET pages.
- Only one inline composer or row editor should be open at a time.
- Destructive lifecycle actions use focused confirmation pages and never share an ordinary edit footer.

## Administration surfaces

### Agency

- Display workspace code as immutable identity, not an editable field.
- Agency lifecycle controls are absent from tenant administration; lifecycle is a privileged operation.
- Locale defaults are clearly labeled as defaults and do not imply rewriting historical records.

### Agency Users

- Display access role separately from descriptive relationship.
- Make invitation state, active/suspended/closed state, and available next actions explicit.
- Role, relationship, and default Office editing submits as one atomic form.
- A last-administrator rejection preserves every submitted field and explains the conflict.
- Invitation replacement and revocation appear only for invited AgencyUsers.
- Cross-Agency or missing identifiers use the same not-found behavior.

### Offices

- Office code is immutable after creation.
- Inactive Offices remain visible and cannot be selected as current/default context.
- Office state never implies which AgencyUsers may read or mutate records.
- If no Office is current, the UI remains usable and does not invent one.

## Forms and validation

- Use `.dd-field` anatomy with a visible label, optional hint, control, and field-specific error.
- Preserve submitted values after validation failure.
- Focus the error summary or first invalid field according to the surface's established pattern.
- Do not hide required inputs in a closed `details` element.
- Cancel returns to the relevant browse/show surface without applying changes.
- Server validation and command outcomes remain authoritative.

## Tables and record rows

- Keep primary identity and status visible without opening row detail.
- Align repeated fields and numeric values consistently.
- Keep essential actions keyboard reachable; use a labeled overflow only for genuinely secondary actions.
- Use explicit actionable, positive, filtered, permission, and error empty states.

## Turbo and state changes

- Turbo Frames may localize editing or replacement, but commands retain full-page fallback behavior.
- Persisted state changes wait for the server response. Do not optimistically change lifecycle, permission, balance, or capacity displays.
- Validation responses return `unprocessable_entity`; stale/concurrent conflicts preserve a recoverable path.
- URL fragments position the viewport only. They do not open a disclosure or authorize a record.

## Responsive and accessibility gate

Every changed surface must be checked at 375px, 768px, reference desktop width, and 1280px. Verify skip link, landmarks, headings, visible focus, complete keyboard order, drawer focus containment/restoration, accessible names, validation associations, reflow, and no hover-only action.

The earlier Party workspace and record-specific contract is archived at [`../archive/v0.02/ui/interface-contract-party-era-260907.md`](../archive/v0.02/ui/interface-contract-party-era-260907.md).
