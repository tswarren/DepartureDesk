# DepartureDesk interface contract

**Status:** Active implementation contract
**Scope:** Agency identity, the complete M1 Client and Supplier directories, M1E proof of keyboard, drawer, viewport, and `#form-error-summary` behavior, shipped M2A Departures, shipped M2B departed/correction surfaces, shipped M2C proof of Departures search, isolation, keyboard, drawer, and viewport behavior, shipped M3A tentative Supplier planning structure, shipped M3B draft Item-card Supplier capacity configuration, shipped M3C Arrangement/Item cost workspaces plus derived forecast views, shipped [M3D.0](../planning/m3d0-planning-workspace-compression.md) guided workspace compression over those M3A–M3C surfaces, shipped [M3D](../planning/m3d-activation-reservations-confirmations.md) activation, Reservation, confirmation, and effective-capacity surfaces, shipped [M3D.8](../planning/m3d8-activation-reservation-product-quality.md) product-quality remediation for those M3D surfaces, shipped [M3E](../planning/m3e-supplier-operational-control.md) operational commitments, Deadlines, deposits/milestones, exposure, Needs attention, and Arrangement ending (through M3E.7b, including M3E.5R and M3D remediations), shipped [M3F](../planning/m3f-acceptance-and-hardening.md) acceptance/hardening including exclusive occupancy-profile editors, capacity-consequence remove/focus, and cost-review single-preload, and shipped [M4A](../planning/m4a-service-definitions-and-sources.md) unpublished Service Offer drafts in the Departure workspace, and shipped [M4B](../planning/m4b-client-pricing-and-anonymous-preview.md) unpublished Client prices and anonymous preview, shipped [M4C](../planning/m4c-packages-choices-and-client-terms.md) unpublished Package drafts, shipped [M4D](../planning/m4d-publication-and-live-feasibility.md) Publish/Sales/live feasibility, and accepted [M4D.0](../planning/m4d0-narrow-group-departure-builder.md) builder surfaces (not yet shipped in code). **M3 is complete.**

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
- Profile shows identity, dates, time zone, currency, responsibility, lifecycle, reference, a Supplier planning panel for Arrangements (draft through ended), and a Departure-level Needs-attention rollup when supplier-planning findings exist.
- The Supplier planning panel lists Supplier Arrangements, contracting Suppliers, lifecycle status (including `ended`), and governing version status, and links to the Arrangement workspace. Add arrangement is shown only when the current AgencyUser has `manage_departures` and the Departure is draft or active. Ended Arrangements remain readable without mutation controls. Add service from Supplier planning hangs beside Add arrangement under the same `manage_departures` plus Departure `draft`/`active` gate.

## Client offers (draft)

- The Client offers (draft) panel lists unpublished Service Offer drafts on the Departure profile. It is shown only when the current AgencyUser has `manage_departures`. Viewers see neither the panel, list, links, nor forms. Offer routes return not found without `manage_departures`.
- Add service from Supplier planning is shown only when `manage_departures` and the Departure is draft or active. Explicit non-M3 basis create is available from the same panel.
- Source search is Departure-scoped. Active Arrangements list the governing activated graph by default; a successor draft is a labeled **tentative** option. Never-activated Arrangements list the labeled draft only. Do not default to the Arrangement editor's editable draft.
- Ordinary create is Client title plus one source or an explicit fulfillment basis. Dates, provider, category, currency, and capacity context are read from the selected source. Create forms stay price-free.
- Draft show and edit attach a Client price panel: ordinary pattern plus amount, anonymous example quantities, and **Advanced price details** disclosure. Optional attributed Supplier-cost comparison is `manage_departures` only and is not a publication decision. There is no Publish action. Forms use `#form-error-summary`, hidden `lock_version`, and server-issued idempotency keys. After departure, price create/edit is hidden; Remove price remains as cleanup.
- Arrangement profile shows Items in manual order, Occurrences in contracted chronological order, and Resources in manual order. Ordinary draft editing requires an editable draft Arrangement, Departure `draft` or `active`, and an active contracting Supplier.
- After forced contractor inactivation or on a departed Departure, recovery controls remain for clearing an inactive contact, clearing or replacing an inactive service provider, removing unpublished draft structure, and abandonment. Expansion actions such as Add item, Add occurrence, and Add resource are hidden.
- Abandonment uses a dedicated confirmation that collects a reason. Abandoned Arrangements remain readable and expose no mutation controls.
- Activation is a dedicated readiness page listing missing requirements, then `POST` activate. Return to draft is a confirmation that collects a reason.
- Arrangement, Item, Occurrence, and Resource create/edit forms retain full-page paths using `#form-error-summary`, hidden optimistic locks, and server-issued idempotency keys for create actions. Guided Item setup may create the required Item with an optional first Occurrence and Resource atomically; the separate forms remain available.
- One explicit reorder mode exposes keyboard-operable Move up/Move down controls for Items or one Item's Resources. The default reading state omits repeated movement controls, and reorder commands submit the full ordered identifier list.
- Arrangement Item cards include a Capacity section with the draft applicability choice summarized as Managed capacity, No managed capacity, or Not decided. Managers can open the item-centered capacity workspace; Viewers see the same facts without mutation controls.
- Arrangement profile is a status board: identity, ordered next actions, planning-readiness review, Item cards with structure (Occurrences/Resources) plus capacity and cost readiness summaries, and—once activated—operational panels for commitments, Deadlines, deposits/milestones, exposure, and Needs attention. Item cards emphasize one contextual Continue setup or Review action; secondary structure, reorder, capacity, and cost actions remain distinct. Cost editing lives on dedicated Arrangement and Item costs workspaces (`…/costs/workspace`), matching the capacity workspace pattern. Forecast detail remains on the cost-forecast page.
- Draft capacity is presented as an Occurrence-grouped hierarchy, then Resource rows, then nested Pool rows. It is never shown as a matrix. Pool rows show label, mode, measurement basis/unit label, supplying Supplier, tentative status, evidence state, and **Proposed opening quantity** for numeric Pools. On-request and externally managed Pools show **Quantity not tracked**, never zero or unlimited.
- The capacity workspace supports reviewed bulk decisions for eligible pairs within that hierarchy and an atomic classify-as-pooled plus first-Pool workflow. Existing decisions with Pools are not silently changed, and Viewer/recovery paths expose no bulk expansion controls.
- Pool forms are conditional: block/allotment shows numeric quantity, basis/unit, and evidence or Administrator override; on-request/externally-managed shows **Quantity not tracked** and omits numeric inputs; override and ordinary evidence inputs remain mutually exclusive.
- Capacity warnings use text in addition to status color, including missing applicability, undecided pairs, pooled pairs without Pools, missing evidence, inactive supplying Supplier, provider mismatch, and time-zone mismatch.
- Guided initial cost setup creates one source, one estimate or contracted definition, and either one initial component or an explicit zero-cost declaration. Calculation-specific component forms expose only applicable inputs while economic role remains a separate choice.
- Quantity-dependent cost blockers link to contextual assumption entry preselected to the exact Item/Occurrence/Resource context. Staff explicitly enter planning quantities; the UI does not infer demand from capacity or dates. Each definition has a dedicated readiness review showing business-readable formulas, inputs, result or exact blockers, and provenance/attestation before an explicit forecast-ready action.
- Activated operational surfaces compress Staff work: Open and Accepted-exception commitment views, shared evidence coverage review (one submit for a compatible set), Deadline and Deposit Requirement definition templates with business-readable summaries, external-handled deposit attestation (never labeled paid), lightweight `names_assigned_to_supplier` milestone confirmation, and contingent-to-guaranteed exposure qualification with a recoverable note/idempotency form.
- Needs attention is action-grouped on the Arrangement and rolled up on the Departure. Findings are nondismissible while true; they do not replace command blockers.
- Arrangement ending uses a dedicated preview (`GET …/end`) that binds a digest to exact cascade candidates, then confirm (`POST …/end`). Clean endings are review plus confirm; cascade endings use one review screen. Preview conflict, cascade failure, and invalid selection recover through `#form-error-summary` without inventing a force override. Ended Arrangements stay readable and mutation-closed.
- Technical detail (lineage, coverage membership, projection components) remains available through keyboard-accessible disclosure, not as required Staff inputs.
- Mark departed is a confirmation shown only when the Departure is eligible (`starts_on` on or before the local date in its time zone). Schedule, currency, and lifecycle corrections are confirmations on departed records. Lifecycle correction is shown only when stored `starts_on` is still in the future. The schedule correction form submits start date, end date, and time zone together.
- Viewer may browse index and show and has no mutation actions, including ending, attestation, milestone, qualify, disposition, and capacity-event mutations.
- Responsible Office and AgencyUser are attribution only. A Viewer may be the responsible user.
- Cross-slice setup friction named on the former M3F backlog (occupancy-preview preload, capacity-consequence remove/focus, exclusive occupancy-profile editors) is shipped with M3F.1; M3E.7a owns defects only in M3E’s own consequential forms and screens.

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


## Group departure builder (M4D.0 domain; M4D.0R presentation)

Domain: [M4D.0](../planning/m4d0-narrow-group-departure-builder.md). Presentation: [M4D.0R](../planning/m4d0r-builder-interface-remediation.md) (shipped).

- **Create group departure** uses two save intents: **Save and add components** (first-component screen) and **Save for later** (empty builder workspace). Timing mode toggles do not clear exploratory input until validated submit.
- For `manage_departures`, the **builder is the primary working body** (dedicated builder route). Compact identity header only; full administrative definition, Supplier Arrangement tables, and Service Offer tables are secondary links—not peer panels on the default body.
- Vertical order: recommended next action (action-labeled button), preparation-outcome choice (request/session only), Package summary, itinerary cards, collapsed four-group checklist, secondary operational links.
- Each component card exposes **one** contextual action plus a Remaining setup disclosure. Do not show all fulfillment choices and both Cruise/Hotel helpers as peer buttons.
- Supplier-supported path binds the **existing** outline Service Offer; it must not create a second offer from the collection from-source flow.
- Cruise/Hotel helpers persist only Staff-submitted categories; opening a helper writes nothing.
- Keyboard itinerary reorder in focused mode with full-page fallback; no drag-only path.
- Staff-only internal Client preview labeled not shared with Clients; pending facts never display as zero.
- Permission: `manage_departures` for all builder mutations and unpublished reads. Viewer behavior for unpublished drafts is unchanged; published Client facts remain Viewer-readable under M4D.

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
