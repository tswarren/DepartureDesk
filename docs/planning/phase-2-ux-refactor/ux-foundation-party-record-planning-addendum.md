# UX Foundation — Party Record Planning Addendum

**Companion to:** `ux-foundation-party-record-prototype.md`  
**Purpose:** Lock the missing presentation, routing, shell, and implementation-status decisions required before writing the implementation plan.  
**Authority:** This addendum narrows and clarifies the prototype brief. Where the proposed CSS or current interface contract differs, this addendum controls this prototype slice.

## Decision summary

This slice will:

1. use a written region map from `mockup-cruise.png` to the party overview instead of requiring a new image mockup;
2. add two focused read surfaces under a party: **Roles** and **Record**;
3. move existing role forms to Roles and lifecycle/technical metadata to Record without changing their commands;
4. move alternate-name maintenance into the existing identity edit workflow as a display-first panel with per-row edit, not nested in the canonical identity form;
5. ship a canonical sidebar containing Directory, Clients, and Suppliers as live destinations plus clearly disabled future destinations;
6. omit global search until a real search contract exists;
7. use a small Stimulus controller for the mobile navigation drawer (JavaScript required below 768px) and native `details`/`summary` for the overflow menu;
8. apply the redesigned shared overview to person, household, and organization parties, while using OceanView Cruises as the visual-review record;
9. create OceanView Cruises as a supplier-only organization seed, add a separately named sparse organization, and keep Horizon Tours as the dual-role regression record;
10. replace the current proposed CSS sketch for this slice with shell and record-overview primitives only;
11. treat `docs/ui/interface-contract.md` as proposed future-state guidance, not a description of implemented anatomy.

These decisions are narrow enough to plan and implement the prototype. They do not authorize the broader UX migration.

Adding **Clients** to the persistent sidebar deliberately supersedes Phase 2C §7.1 **for navigation only**. Directory remains the identity home. Clients and Suppliers remain role-filtered party collections and do not become separate CRUD aggregates. The rest of Phase 2C remains authoritative.

## 1. Visual reference: cruise overview to party overview

The party page is not expected to reproduce the departure mockup field for field. The reference establishes product family, hierarchy, and composition. The following region map is the reviewable target.

| Departure overview reference | Party overview implementation | Adaptation rule |
| --- | --- | --- |
| Persistent navy sidebar | Same canonical application sidebar | Match shell silhouette, active-state treatment, density, and spacing. Use current DepartureDesk destinations. |
| White top utility bar | Agency/user context and mobile navigation controls | Omit global search. Do not render a fake search field. |
| `Departures / Smith Family Reunion Cruise` breadcrumb | `Directory / Suppliers / OceanView Cruises` | Breadcrumb communicates location; it does not imply supplier and party are separate identities. |
| Departure title and status | Party name plus kind, lifecycle, and role badges | Keep one `h1`. Badges supplement rather than replace text. |
| Departure metadata line | Concise identity/responsibility line | For an organization: legal/trading distinction only when useful, plus responsible office if not repeated excessively. |
| More-actions control | Party overflow actions | Initial implementation uses native `details`/`summary`; destructive actions remain confirmed and are not the primary header action. |
| Departure tabs | Party-local subnavigation | Use Overview, Contact information, Relationships, Roles, Notes, Identifiers, Record. |
| Four operational counts | Four-segment party summary strip | Use Primary contact, Responsible office, Supplier services, Needs attention. These are compact facts, not oversized KPI cards. |
| Main upcoming-milestones table | Main contact and supplier summaries | Preserve the wider visual column, but use party-relevant content rather than imitating a table unnecessarily. |
| Main supplier-arrangements table | Current relationships and recent/pinned notes | Use concise rows with strong primary and muted supporting text. |
| Financial-summary aside | Key identifiers and record responsibility | Compact supporting facts only; no speculative party financial summary. |
| Capacity aside | Attention and usability summary | Show missing primary contact, suppressed destinations, inactive responsibility, or similar actionable conditions. Do not invent capacity concepts. |
| Amber guarantee warning | Party attention callout | Amber is used only for a concrete item requiring attention, never as generic decoration. |

### Visual-family acceptance rule

Review the party screen against the departure mockup for:

- shell proportions;
- page-header scale;
- tab treatment;
- compact summary rhythm;
- main/aside hierarchy;
- panel borders and headers;
- row density;
- restrained semantic color;
- action hierarchy;
- amount of useful content visible before scrolling.

Do not reject the party screen because it lacks departure-specific tables, money, capacity, or milestones. Do reject it if it returns to a centered CRUD column, equal-weight vertical panels, or visible maintenance forms.

## 2. Party-local destination map

### Locked subnavigation

The canonical party-local subnavigation for this prototype is:

1. Overview
2. Contact information
3. Relationships
4. Roles
5. Notes
6. Identifiers
7. Record

This replaces the prototype brief's supplier-specific subnav proposal. A shared **Roles** destination works for person, household, and organization records and houses both client and supplier role maintenance.

At narrow widths, subnavigation remains a horizontally scrollable, labeled `nav`; it does not wrap into several uneven rows.

### Destination map for current `show` content

| Current party `show` content | Prototype destination | Required change |
| --- | --- | --- |
| Canonical identity summary | Overview header and compact supporting facts | Convert from full definition list to orientation-level summary. |
| Canonical identity editing | Existing party Edit page | Preserve current update command. |
| Alternate-name list and forms | Existing party Edit page | One canonical identity form, then a separate Alternate names panel. Existing rows are display-first with a per-row edit state. Keep existing create/update/destroy endpoints; do not nest those mutations inside the identity form. |
| Team membership summary | Overview only when applicable | Show compact access status and link administrators to the existing team-member page. No duplicate membership form. |
| Client-role form | New Roles GET page | Move existing `_role` rendering; keep client-profile mutation endpoints unchanged. |
| Supplier-role form | New Roles GET page | Move existing `_role` rendering; keep supplier-profile and category mutation endpoints unchanged. |
| Primary contact summary | Overview | Show eligible primary destinations with a link to Contact information. |
| Complete contact maintenance | Existing Contact information page | No route change. |
| Current relationships summary | Overview | Show a small current subset with a link to Relationships. |
| Complete relationship maintenance | Existing Relationships page | No route change. |
| Notes summary | Overview | Show pinned/important and recent context only. |
| Complete note history and commands | Existing Notes page | No route change. |
| Key identifier summary | Overview aside | Show a small prioritized set. |
| Complete identifier maintenance | Existing Identifiers page | No route change. |
| Created, updated, and deactivation metadata | New Record GET page | Move without rewriting history. |
| Deactivate/reactivate form | New Record GET page | Keep existing member commands, lock-version handling, dependency behavior, reason requirement, confirmation, and audit semantics. |

### New read surfaces

Add exactly two party-local GET surfaces:

- `directory_party_roles_path(@party)`
- `directory_party_record_path(@party)`

Recommended routing shape:

```ruby
resources :parties do
  resource :roles, only: :show, controller: "roles"
  resource :record, only: :show, controller: "records"
end
```

Exact controller naming may follow repository conventions, but the routes must be party-scoped, agency-scoped, and authorization-equivalent to the forms they expose.

These are presentation routes only. Existing client-profile, supplier-profile, alternate-name, deactivate, and reactivate mutation routes remain authoritative.

### Compatibility and test updates

Tests that currently require `form#client_profile_create_form` or `form#supplier_profile_create_form` on `GET directory_party_path` must be updated to require those forms on the Roles page instead. Retain separate overview tests proving that role status is summarized without rendering the maintenance forms.

Do not retain hidden duplicate role forms on Overview merely to satisfy old selectors.

## 3. Canonical sidebar inventory

The mockup navigation labels are not authoritative. Use current DepartureDesk terminology and shipped routes.

### Main navigation

| Order | Label | State in this slice | Destination/behavior |
| ---: | --- | --- | --- |
| 1 | Dashboard | Active link | Existing root path. |
| 2 | Directory | Active link | Existing all-parties index. |
| 3 | Clients | Active link | Existing client index. |
| 4 | Suppliers | Active link | Existing supplier index. |
| 5 | Departures | Disabled future item | Render as non-link with unavailable semantics. Do not use “Trips.” |
| 6 | Travelers | Disabled future item | Render as non-link with unavailable semantics. |
| 7 | Accounting | Disabled future item | Retain current label for now; terminology may be revisited with the financial workspace. |

### Sidebar footer

| Label | State | Destination/behavior |
| --- | --- | --- |
| Administration | Administrator-only link | Existing agency administration path. |
| Help | Omitted | No shipped destination exists. |

The topbar renders a compact visible account cluster: agency name, signed-in user display name, current office with a link to `edit_current_office_path`, and Sign out. Do not introduce a profile dropdown. At narrow widths, supporting text may be reduced, but the current office and Sign out must remain reachable.

This sidebar inventory supersedes Phase 2C §7.1 for navigation only. Tests that require Clients to be absent from primary navigation must be updated. Add coverage confirming that Clients links to the role-filtered collection rather than a separate identity model.

### Active-state rules

- **Directory** is current on the general party index and on every party-local page.
- **Clients** is current only on the Clients collection.
- **Suppliers** is current only on the Suppliers collection.
- Do not derive current navigation from referrer, session state, or entry route.
- Breadcrumbs may preserve useful role context, but they do not change the sidebar’s active item.
- Administration is current for administration controllers.
- Disabled future items never receive `aria-current` and are not focusable.
- Teal owns active navigation; amber remains the focus and attention color.

### Party breadcrumbs

Use deterministic role precedence. Intermediate labels must link to real, authorized destinations.

- supplier role: `Directory / Suppliers / {name}`;
- otherwise client role: `Directory / Clients / {name}`;
- otherwise: `Directory / {name}`.

For a party holding both roles, use Suppliers first. This precedence is presentational only and does not establish a dominant domain role.

### Record header and overflow

The record header contains one primary action with a kind-aware label: **Edit person**, **Edit household**, or **Edit organization**.

The overflow contains only:

- **Manage roles**
- **View record**

Do not add “Open in directory”. Do not place deactivate/reactivate submission, reason fields, role mutations, or alternate-name mutations in the overflow. Exceptional commands remain on focused pages.

## 4. Global search decision

**Decision: omit global search from this prototype.**

The product does not yet have a global-search contract spanning departures, parties, travelers, and suppliers. A realistic-looking but nonfunctional field would misrepresent capability and complicate keyboard review.

The topbar should reserve composition flexibility for a future search field without rendering an unavailable input. Search may be introduced only when its scope, authorization filtering, result grouping, keyboard behavior, and destination behavior are planned.

## 5. Drawer and overflow interaction decisions

### Mobile navigation drawer

Use one small Stimulus controller for the responsive sidebar drawer.

Required behavior:

- sidebar is persistent at and above 768px;
- below 768px, a topbar button opens the sidebar as a modal navigation drawer;
- trigger has an accessible name and expanded state;
- focus moves into the drawer on open;
- Escape and the explicit close button close it;
- focus returns to the opener;
- background content is inert or equivalently unavailable while open;
- body scrolling is contained while open;
- navigation following a link closes naturally through page navigation;
- Turbo page changes must not leave stale open/inert state;
- hidden drawer controls are not focusable when closed.

JavaScript is required to operate collapsed navigation below 768px in this prototype. Do not duplicate the navigation DOM or build a parallel CSS-only drawer. Desktop navigation remains ordinary server-rendered links.

The controller must still meet the specified focus, Escape, inert-background, scroll-containment, Turbo-cleanup, and focus-return requirements.

### Record overflow menu

Use native `details` and `summary` for the initial record overflow menu. This provides keyboard and no-JavaScript operability without adding a second controller during the visual prototype.

Requirements:

- summary has an accessible “More actions” label;
- the disclosure is styled as a quiet/secondary control;
- menu content is a semantic list of links, not ARIA `menu` unless full menu keyboard behavior is implemented;
- contents are **Manage roles** and **View record** only;
- destructive actions retain server-backed confirmation and reason collection on the Record page;
- do not place the deactivation reason field inside a tiny popover;
- viewport-edge placement must not overflow;
- opening the menu must not shift the record header materially.

## 6. Shared-template decision

`app/views/directory/parties/show.html.erb` remains the shared overview for persons, households, and organizations. Do not fork the entire page by party kind.

Use kind-specific partials only where the information genuinely differs, such as:

- person identity summary;
- household identity summary;
- organization identity summary;
- role eligibility messaging.

The visual review uses OceanView Cruises, but implementation is not complete until focused regression coverage confirms:

- person identity fields render correctly;
- household correspondence identity renders correctly;
- household supplier ineligibility remains explicit;
- no “Add supplier role” control appears for a household;
- team membership appears only for a linked person;
- client and supplier role summaries handle assigned, inactive, not assigned, and ineligible states;
- all party kinds retain correct authorization and agency scoping.

## 7. Reference seed decision

Keep **Horizon Tours** as the existing dual-role organization.

Add:

- **OceanView Cruises** — populated, supplier-only visual-review record;
- one separately named sparse organization — active party, minimal identity, no roles, contacts, relationships, notes, or identifiers.

OceanView Cruises should include the populated states required by the prototype brief, using existing commands where seed conventions support them. Seed logic must be idempotent and must not bypass validations merely for presentation convenience.

OceanView Cruises exercises attention condition 2: an eligible general-primary email or phone remains available, and a suppressed billing contact remains assigned as the current billing primary. Suppression does not end the purpose assignment or promote another destination automatically.

The sparse organization validates:

- compact missing-information treatment;
- absence of irrelevant supplier warnings;
- no large empty panels;
- generic Directory breadcrumbs;
- Client **Not assigned** and Supplier **Not assigned** on the Roles page.

It will not be expected to demonstrate **Ineligible**. Household coverage separately verifies Client **Not assigned** when applicable, Supplier **Ineligible**, and no Add supplier role control.

The target records should be discoverable predictably after `db:seed`; document display names and navigation paths in the PR.

## 7a. Needs-attention inventory

Count one attention item for each applicable condition:

1. Neither an eligible general-primary email nor an eligible general-primary phone exists. A general-primary postal address alone does not clear this condition. Having either an eligible general-primary email or phone is enough.
2. A current primary-purpose assignment points to a suppressed or deactivated contact point.
3. An active supplier role has no service categories.

Do not count:

- an ordinary suppressed historical contact that is not currently primary;
- missing optional contact types;
- absence of a role;
- empty notes;
- absence of external identifiers;
- an active role without a responsible office, or an active role assigned to an inactive office — current persistence and command invariants prevent both;
- an inactive role retaining an inactive historical office — that office status may still display, but it is not an overview attention item.

The summary segment displays the count and a short label. The amber callout appears only when the count is greater than zero and lists the applicable conditions with links to the relevant maintenance destinations.

Contact summary continues to use eligible primary destinations. Suppressed or deactivated primaries belong in the attention callout, not the usable-contact summary.

## 8. Layout tokens for the prototype

The following values are initial implementation tokens subject to the stakeholder visual gate. They are concrete enough to prevent each implementer from inventing geometry, but they do not become permanent contract values until approved.

| Token/region | Prototype value | Intent |
| --- | --- | --- |
| Sidebar width | `15rem` | Stable navigation without consuming the 1280px workspace. |
| Topbar minimum height | `4rem` | Room for account context and mobile controls without becoming a second header. |
| Workspace width | fluid, `min-width: 0`, maximum `100rem` | Use available post-sidebar width; avoid the current narrow centered-column effect. |
| Workspace horizontal gutter | `1rem` at 375px; `1.5rem` at 768px; `2rem` at 1280px | Predictable responsive inset. |
| Workspace vertical padding | `1.25rem` mobile; `1.5rem` tablet; `2rem` desktop | Keep dense operations pages compact. |
| Main/aside gap | `1rem` to `1.25rem` | Match panel rhythm without large dead zones. |
| Main/aside columns | `minmax(0, 2fr) minmax(18rem, 1fr)` | Approximately 2:1 hierarchy. |
| Main/aside collapse | single column below `64rem` | Avoid unusably narrow side panels. Main content remains first in DOM order. |
| Shell collapse | below `48rem` / 768px | Match the interface contract breakpoint. |
| Panel radius | existing `--dd-radius-md` | Preserve current restrained geometry. |
| Panel shadow | existing `--dd-shadow` | Avoid elevated-card visual noise. |
| Summary strip | one surface divided into up to four segments | Compact facts rather than four dashboard cards. |

At 1280px, the shell leaves approximately 1040px before outer workspace gutters. The layout must be evaluated at that actual available width, not in a full-width design canvas without the sidebar.

## 9. CSS scope for this slice

`foundation-ux-proposed-css.md` is reference material only and must not be copied wholesale into the application.

### In scope

Implement or normalize CSS for:

- `.dd-app-shell`
- `.dd-sidebar`
- `.dd-sidebar-brand`
- `.dd-sidebar-nav`
- `.dd-sidebar-footer`
- sidebar items and active/disabled states
- `.dd-main`
- `.dd-topbar`
- `.dd-workspace`
- drawer backdrop/open/closed states
- `.dd-breadcrumbs`
- `.dd-record-header`
- `.dd-record-identity`
- `.dd-record-meta`
- `.dd-record-actions`
- `.dd-subnav`
- `.dd-summary-strip`
- `.dd-summary-segment`
- `.dd-content-grid--main-aside`
- `.dd-stack`
- `.dd-panel--compact`
- `.dd-fact-grid`
- `.dd-cell-title`
- `.dd-cell-subtext`
- `.dd-attention-callout`
- `.dd-action-menu`
- compact empty/missing-information treatments
- responsive rules at 375px, 768px, and 1280px

Names may be adjusted once, before broad use, to fit existing conventions. Record the final canonical mapping.

### Reuse

Reuse and adjust existing shared tokens and primitives where they remain suitable:

- color and semantic tokens;
- typography base;
- buttons;
- badges;
- panels and panel regions;
- lists;
- tables where actually used;
- forms on focused maintenance pages;
- alerts;
- focus treatment;
- auth shell, which is not redesigned by this slice.

### Out of scope

Do not implement merely because the mockups or proposed CSS mention them:

- `.dd-metric-card` and collection KPI grids;
- `.dd-filter-bar`;
- `.dd-progress`;
- departure collection tables;
- package-economics charts or scenario controls;
- capacity indicators;
- financial-summary components;
- general dashboard primitives.

If a future class is already present but unused, do not expand it as part of this prototype.

## 10. Icon strategy correction

The interface contract describes `icon_tag`, but the current helper does not exist. The prototype must not pretend otherwise.

For this slice:

- add a minimal `icon_tag` helper only if two or more prototype surfaces need the same icon-rendering contract;
- store curated, repository-owned raw SVG partials in `app/views/shared/icons/`;
- normalize their view box and current-color behavior;
- render decorative icons `aria-hidden="true"`;
- provide accessible names through surrounding text or the control label;
- do not install Phosphor or another icon gem/package;
- do not copy a third-party calendar example into the application merely because it appears in the CSS sketch.

Curated SVG paths may visually follow the mockup style, but repository licensing and attribution requirements must be observed.

## 11. Interface-contract status boundary

Until the prototype passes stakeholder review, planning documents and PR descriptions must distinguish these states.

### Implemented today

- sticky navy horizontal application header;
- horizontal primary navigation;
- centered workspace capped at 96rem;
- shared party `show` with stacked equal-weight panels;
- inline alternate-name, client-role, supplier-role, and lifecycle forms;
- focused Contact information, Relationships, Notes, and Identifiers pages;
- shared color tokens, buttons, badges, panels, forms, tables, lists, alerts, and responsive form rules;
- no `icon_tag` helper;
- no mobile drawer controller;
- no overflow-menu controller.

### Proposed and under review in this slice

- sidebar/topbar application shell;
- fluid post-sidebar workspace geometry;
- responsive Stimulus navigation drawer;
- party record header and breadcrumbs;
- seven-item party-local subnavigation;
- compact summary strip;
- main/aside overview composition;
- focused Roles and Record pages;
- alternate-name maintenance on Edit;
- native disclosure-based overflow actions;
- compact attention and missing-information treatments;
- minimal shared SVG icon helper if justified by actual reuse.

### Explicitly out of this slice

- departure collection metrics, filters, tables, and progress;
- departure overview business components;
- package-economics visualization;
- global search;
- future Travelers, Departures, and Accounting workspaces;
- full application page-family migration.

### Documentation handling

Add a visible status note near the beginning of `docs/ui/interface-contract.md` during the branch:

> This document describes proposed future-state presentation patterns. The current application does not implement every listed primitive. For the UX party-record prototype, `ux-foundation-party-record-prototype.md` and its planning addendum define the in-scope subset. Prototype values become canonical only after the stakeholder visual-review gate.

Do not rewrite the entire interface contract before implementation. After approval, amend it with the final demonstrated anatomy, tokens, interactions, and canonical names.

## 12. Required implementation-plan structure

With these decisions locked, the implementation plan may now be written in the following slices:

1. **Baseline and inventory** — capture current record; inventory shell consumers, party `show` functions, tests, and CSS collisions.
2. **Shell foundation** — implement layout markup, scoped shell CSS, canonical navigation, and responsive drawer; perform shell review checkpoint.
3. **Party-local routing** — add Roles and Record GET surfaces; move existing forms and metadata without changing commands.
4. **Record primitives** — implement header, breadcrumbs, summary strip, main/aside grid, compact panels, facts, attention, and disclosure action styles.
5. **Shared party overview** — compose organization target plus person/household variants and sparse/exceptional states.
6. **Seed and review evidence** — complete OceanView Cruises seed, automated tests, responsive/a11y checks, and before/after captures.
7. **Stakeholder gate** — stop; collect Approved/Revise/Rejected decisions; do not begin broad migration.

The implementation plan must identify the exact view, route, controller, helper, Stimulus, stylesheet, seed, and test files expected in each slice after completing the baseline inventory. It must also distinguish moved presentation from unchanged mutation behavior.

## Planning-package readiness checklist

The package is ready for implementation planning when it contains:

- [x] prototype outcome, scope, non-goals, phases, and review gate;
- [x] written party-overview region map;
- [x] destination for every function currently on party `show`;
- [x] decision to add Roles and Record read surfaces;
- [x] canonical sidebar inventory;
- [x] global-search decision;
- [x] drawer and overflow interaction choices;
- [x] shared-template and party-kind coverage decision;
- [x] OceanView Cruises seed decision;
- [x] initial workspace and shell geometry;
- [x] CSS in-scope/reuse/out-of-scope boundary;
- [x] icon-helper correction;
- [x] implemented/proposed/out-of-scope interface-contract boundary;
- [x] required implementation-plan structure;
- [x] stakeholder acceptance of this addendum's locked decisions, including the nine tightenings and domain corrections.

The detailed implementation plan may now be executed. Implementation remains gated on that plan's review.
