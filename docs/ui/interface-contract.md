# DepartureDesk interface contract

**Status:** Active implementation contract
**Scope:** Agency identity, the complete M1 Client and Supplier directories, M1E proof of keyboard, drawer, viewport, and `#form-error-summary` behavior, shipped M2A Departures, shipped M2B departed/correction surfaces, shipped M2C proof of Departures search, isolation, keyboard, drawer, and viewport behavior, and shipped M3A tentative Supplier planning structure.

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
- Suppliers is shown when the current AgencyUser has `view_supplier_directory`.
- Departures is shown when the current AgencyUser has `view_departures`.
- Below 768px, `.dd-drawer-toggle` opens the existing Stimulus drawer. Open focuses Close navigation or the first link, Tab stays inside the drawer, Escape closes and restores the toggle, and `.dd-main` / `.dd-topbar` are `inert` while open.
- Directory, Travelers, and Accounting are absent until accepted slices ship their authorized routes.
- Active navigation uses `aria-current="page"` and a visible teal indicator.

## Client directory

### Shared directory

- The Client directory defaults to the combined All view of people and organizations.
- Kind and status filters stay Agency-scoped and do not change authorization.
- Search results distinguish record type from match family.
- Viewer may browse identity and assignment people; contact destinations remain hidden without `view_client_contact_details`.

### Client Organizations

- Organization create may create an Organization alone or, from New Client, an Organization and Client atomically.
- Organization show lists owned contact channels and current/historical organization contacts.
- Contact-point rows expose Edit, status change, and Set primary with `lock_version`.
- Website entry accepts a hostname or URL; a scheme is optional.
- Adding an organization contact offers Agency-scoped person search with an explicit result cap, or create-new-person fields.
- Organization-contact create does not collect start or end dates; ending uses the End confirmation surface.
- Primary assignment uses an icon indicator plus accessible text, never color alone.

## Supplier directory

- Suppliers is shown when the current AgencyUser has `view_supplier_directory`.
- Kind, status, and category filters stay Agency-scoped and do not change authorization.
- Search may return discriminated Supplier, Location, and Contact results. Presenters build paths from `result_kind` and IDs; search results do not carry URLs.
- Index context distinguishes result kinds: Supplier shows kind and categories; Location and Contact show “Location · owning Supplier” or “Contact · owning Supplier.”
- Create is kind-first and requires at least one category; `other` requires a trimmed label of at most 80 characters.
- Supplier show lists Locations for anyone with `view_supplier_directory`. Locality on the Locations panel and Location address/phone on the Location profile require `view_supplier_contact_details`.
- Contacts panel, Contact profiles, and Contact-owned destinations require `view_supplier_contact_details`. Viewer requests for Contact routes return not found.
- Preferred Contact is the Supplier-level person (`PATCH .../contacts/:id/preferred`). Primary email/phone is the preferred destination within one Contact channel (`POST .../set_primary` or ordinary edit). Selecting one does not change the other.
- Supplier show lists owned contact channels. Contact-point rows expose Edit, status change, and Set primary with `lock_version`.
- Website entry accepts a hostname or URL; a scheme is optional.
- Inactive Suppliers may receive identity and category corrections; create and reactivate of Locations, Contacts, and destinations remain gated on an active Supplier (and active Contact for Contact destinations).
- Supplier inactivation confirmation inventories Locations, Contacts, Supplier-owned destinations, and Contact-owned destinations that will become inactive, and states that categories remain. Contact inactivation confirmation lists Contact-owned destinations.
- Viewer may browse Supplier and Location identity; Location address/phone, named Contacts, and Contact destinations remain hidden without `view_supplier_contact_details`.

## Departures

- Departures is shown when the current AgencyUser has `view_departures`.
- Index lists reference or “Draft”, name, dates, status, responsible Office, and responsible AgencyUser. Filters stay Agency-scoped and fail closed.
- Create may propose copied Office, AgencyUser, Agency time zone, and currency defaults. Time zone is an IANA select that defaults to the Agency time zone. The user can change or clear them. Drafts may omit Office.
- Profile shows identity, dates, time zone, currency, responsibility, lifecycle, reference, and a Supplier planning panel for tentative M3A Arrangement structure.
- The Supplier planning panel is labeled as tentative structure. It lists Supplier Arrangements, contracting Suppliers, lifecycle status, and draft version status, and links to the Arrangement workspace. Add arrangement is shown only when the current AgencyUser has `manage_departures` and the Departure is draft or active.
- Arrangement profile shows Items in manual order, Occurrences in contracted chronological order, and Resources in manual order. Ordinary editing requires an editable draft Arrangement, Departure `draft` or `active`, and an active contracting Supplier.
- After forced contractor inactivation or on a departed Departure, recovery controls remain for clearing an inactive contact, clearing or replacing an inactive service provider, removing unpublished draft structure, and abandonment. Expansion actions such as Add item, Add occurrence, and Add resource are hidden.
- Abandonment uses a dedicated confirmation that collects a reason. Abandoned Arrangements remain readable and expose no mutation controls.
- Activation is a dedicated readiness page listing missing requirements, then `POST` activate. Return to draft is a confirmation that collects a reason.
- Arrangement, Item, Occurrence, and Resource create/edit forms are full pages using `#form-error-summary`, hidden optimistic locks, and server-issued idempotency keys for create actions. Reorder controls submit the full ordered identifier list.
- Mark departed is a confirmation shown only when the Departure is eligible (`starts_on` on or before the local date in its time zone). Schedule, currency, and lifecycle corrections are confirmations on departed records. Lifecycle correction is shown only when stored `starts_on` is still in the future. The schedule correction form submits start date, end date, and time zone together.
- Viewer may browse index and show and has no mutation actions.
- Responsible Office and AgencyUser are attribution only. A Viewer may be the responsible user.

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
- Invalid command forms render `#form-error-summary` with `role="alert"`, `tabindex="-1"`, Stimulus `form-error-summary` focusing the summary after render, the title “Please fix the following:”, and links to `#{param_key}_#{attribute}` that focus the associated field.
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
