# DepartureDesk Design-System Adoption Plan

**Program:** UI Revamp — CAI 2026-09-07 adoption  
**Proposed integration branch:** `ui-revamp-cai-260907-adoption`  
**Primary reference:** `docs/ui/ui-revamp-cai-260907/departuredesk-design-system.md`  
**Reference implementations:** HTML mockups in `docs/ui/ui-revamp-cai-260907/`  
**Starting point:** `main`, including the party-record shell and overview work introduced through PR 16.

## 1. Outcome

Make the running Rails application visually and behaviorally read as the same product as the CAI 2026-09-07 design system and mockup family.

This program replaces the current state—shared brand colors applied to comparatively large, generic Rails panels and forms—with the reference system's:

- IBM Plex Sans and IBM Plex Mono typography;
- compact 4px-based spacing system;
- 52px navy topbar and 208px sectioned sidebar;
- dense, border-led cards and rows;
- screen-family-specific page composition;
- focused data-entry surfaces;
- Turbo Frame row/cell editing where appropriate;
- consequential-action confirmations;
- semantic empty, loading, error, and permission-safe states;
- consistent curated Phosphor Regular SVG vocabulary.

The work is a presentation-system refactor. It must not alter domain ownership, tenancy, authorization, command semantics, audit behavior, retention behavior, or contractual invariants merely to simplify the interface.

## 2. Success condition

The program is successful when a reviewer can place screenshots of the running reference surfaces beside the corresponding HTML mockups and recognize the same product in:

- shell proportions;
- typography and type hierarchy;
- information density;
- spacing rhythm;
- card, row, field, and button geometry;
- color meaning;
- display-versus-edit separation;
- loading, error, empty, and interaction states;
- keyboard and responsive behavior.

Matching the palette alone is not sufficient.

## 3. Authority and supersession

Use this precedence for UI decisions:

1. domain requirements and terminology;
2. `docs/ui/ui-revamp-cai-260907/departuredesk-design-system.md`;
3. the screen-specific HTML mockup for the surface being implemented;
4. the party/profile field map and approved UX planning documents;
5. `docs/ui/interface-contract.md` where it does not conflict;
6. existing application markup and CSS.

### Required documentation note

At program start, add a status note to `docs/ui/interface-contract.md` explaining that the CAI design system supersedes it where the two conflict. Do not silently retain incompatible rules.

Create a concise supersession table covering at least:

- typography;
- topbar and sidebar geometry;
- navigation active state;
- spacing and density;
- field and button dimensions;
- icon vocabulary;
- data-entry interactions;
- component states;
- empty-state families;
- party-profile composition.

### Party stat-strip exception

Amend the broad “every detail page has a stat strip” language:

> Operational detail records use a stat strip when they have meaningful operational measures. Identity and administrative records do not manufacture metrics from ordinary attributes.

The Party profile follows `party-profile.html` and does not render the four-segment summary strip added in PR 16. Departures, client trips, supplier arrangements, and similar operational records may use stat strips.

## 4. Locked product and implementation decisions

- **Departure** remains the primary dated operational noun. Do not introduce “Trip” as a replacement.
- Directory remains the identity home.
- Clients and Suppliers remain role-filtered party collections, not separate identity aggregates.
- Party-local pages keep Directory active in primary navigation.
- Person, organization, and household remain one shared party-page family with kind-specific content where required.
- Households may hold the Client role and remain ineligible for the Supplier role.
- Organization website and supplier portal remain distinct fields and visual concepts.
- Directory contact email and login email remain distinct.
- Overview and collection surfaces display information by default.
- Large edits use focused Turbo-powered pages.
- Small row/cell edits may use one scoped Turbo Frame.
- Consequential actions use a focused confirmation surface or frame-loaded modal.
- Stimulus controls local interaction; persisted business state remains server-authoritative.
- Do not optimistically display derived statuses or calculated financial values.
- Do not introduce ViewComponent or a frontend SPA framework.
- Do not install an icon font. Curated SVG partials may use the approved Phosphor paths with licensing retained.
- Do not copy mockup HTML wholesale into Rails views. Extract and implement canonical patterns.

## 5. Branch and review strategy

Create an integration branch from current `main`:

```text
main
  └── ui-revamp-cai-260907-adoption
        ├── ux-r0-authority-and-inventory
        ├── ux-r1-foundations
        ├── ux-r2-canonical-shell
        ├── ux-r3-party-profile-reference
        ├── ux-r4-data-entry-reference
        ├── ux-r5-party-maintenance-adoption
        └── ux-r6-systematize-and-cleanup
```

Each slice PR targets the integration branch. The final integration PR targets `main` only after both visual gates and complete verification pass.

Do not merge slice branches directly to `main`. Do not begin UX-R5 until UX-R3 and UX-R4 have passed their visual gates.

## 6. Program-wide invariants

- No route or command may lose agency scoping.
- No authorization-sensitive content may be rendered and hidden with CSS.
- No mutation may move from a command/service into client-side state.
- Existing optimistic-concurrency fields and lock ordering remain authoritative.
- Historical facts remain history; routine presentation refactoring must not overwrite them.
- Suppressed and deactivated contact points remain distinct.
- Primary contact remains purpose-specific, not one global boolean.
- Client and supplier role lifecycle remains separate from party lifecycle.
- A hidden or collapsed form is not considered display/edit separation if it is still rendered for every row.
- At most one lightweight composer or row editor is open in a collection at a time.
- Destructive actions never share the ordinary edit form footer.
- Missing data, confirmed zero, unavailable data, and permission-hidden data remain distinguishable.
- Keyboard focus uses teal field focus plus an amber outer ring for keyboard focus.
- Amber indicates scheduled attention or waypoints; red indicates failure, overdue state, or destructive consequences.

## 7. Reference surfaces

Use these as the minimum reference implementation set:

| Surface | Reference | Purpose |
| --- | --- | --- |
| Authenticated shell | All full-screen mockups | Topbar/sidebar geometry and navigation density |
| Person party profile | `party-profile.html` | Canonical identity-record composition and row systems |
| Organization party profile | Adapt `party-profile.html` to OceanView Cruises | Validate shared archetype across kind and supplier role |
| Data-entry reference | `data-entry-patterns.html` | Fields, form sections, modal, combobox, allocation, inline edit |
| Empty states | `empty-states.html` | Six semantic empty/error patterns |
| Cross-cutting states | `cross-cutting-patterns.html` | Status controls, confirmation, audit, calculated-state presentation |

Future departure-domain mockups remain design references, but this program must not implement unbuilt domain features merely to reproduce them.

## 8. UX-R0 — Authority, inventory, and baselines

### Objective

Establish a single source of truth and document the exact distance between current application surfaces and the reference system.

### Deliverables

- Add the interface-contract status/supersession note.
- Create `docs/planning/ui-revamp-cai-260907/adoption-inventory.md`.
- Inventory current consumers of:
  - shell and navigation classes;
  - typography and spacing declarations;
  - page headers and record chrome;
  - panels, definition lists, lists, tables, badges, buttons, fields, forms, alerts, and empty states;
  - icon partials/helper;
  - party overview and party-local maintenance pages;
  - Stimulus controllers and Turbo Frames.
- Classify each existing selector as:
  - retain;
  - restyle in place;
  - replace and deprecate;
  - remove after migration.
- Map reference HTML patterns to proposed Rails partials/helpers/controllers.
- Capture current application screenshots at the same desktop dimensions as the relevant mockups and at 768px and 375px.
- Record current focus order, keyboard behavior, and no/slow/error states on the reference surfaces.

### Required gap matrix

For each reference surface, record:

- reference token or pattern;
- current implementation;
- target implementation;
- owning slice;
- affected files;
- verification method;
- unresolved domain or accessibility issue.

### Exit criteria

- Every selector and view touched by UX-R1 through UX-R5 has an identified owner.
- No implementation slice depends on an unresolved authority conflict.
- Before screenshots exist.
- The integration branch contains documentation only or other nonbehavioral inventory work.

## 9. UX-R1 — Visual foundations

### Objective

Implement the exact type, spacing, geometry, and component-state foundation without broadly recomposing views.

### Typography

Implement:

- IBM Plex Sans weights 400, 500, 600, and 700;
- IBM Plex Mono weights needed for numeric and identifier presentation;
- 12.5–13px body type;
- 12–12.5px table/list-row type;
- 10–11px label, eyebrow, and column-heading roles;
- approximately 19px detail-page titles;
- approximately 12.5px card headings;
- compact metadata roles.

Define semantic classes/tokens rather than applying arbitrary font sizes per view.

Use IBM Plex Mono for currency, quantities, percentages, confirmation/reference numbers, codes, and aligned numeric table cells. Do not use it for ordinary prose or names.

### Spacing and density

Add the design-system base and compact spacing tokens:

```css
--dd-space-1: 4px;
--dd-space-2: 8px;
--dd-space-3: 12px;
--dd-space-4: 16px;
--dd-space-5: 20px;
--dd-space-6: 24px;
--dd-space-7: 32px;
--dd-space-8: 40px;
--dd-space-compact-1: 4px;
--dd-space-compact-2: 6px;
--dd-space-compact-3: 9px;
```

Assign tokens by component role. Avoid retaining rem-based one-off values for canonical components merely to minimize the diff.

### Geometry

Normalize:

- field height around 34–36px on desktop;
- button height around 32–34px;
- 4px standard control radius;
- 7px card radius;
- compact card header/body padding;
- border-led cards with little or no ordinary shadow;
- compact table and list rows;
- standard icon sizes: 16, 20, 24, and 32/40px.

Preserve comfortably operable mobile targets. Mobile controls may be taller than desktop controls without changing the visual hierarchy.

### Component states

Implement shared states for:

- primary and secondary buttons;
- fields and selects;
- table/list rows;
- navigation items;
- tabs;
- toggles;
- editable and derived status pills;
- Turbo Frame containers.

Each applicable component needs default, hover, keyboard focus, active/pressed, disabled, loading, and error behavior.

### Turbo foundation

- Restyle the Turbo full-navigation progress bar in action teal.
- Add shared skeleton primitives for lazy frames.
- Add a frame-scoped load-failure treatment.
- Add standard “Saving…”/disabled behavior hooks without calculating domain outcomes client-side.

### Icon foundation

- Reconcile current SVG partials against `icon-reference-set.csv` and the design-system mapping.
- Use approved Phosphor Regular paths as curated repository SVG partials.
- Standardize view box, current-color behavior, optical size, and accessible labeling.
- Retain required license/attribution.
- Do not replace all icons in this slice; establish the canonical vocabulary and migrate reference surfaces first.

### Likely files

- `app/assets/tailwind/application.css`
- font assets/import configuration
- `app/helpers/application_helper.rb`
- `app/views/shared/icons/*`
- `app/javascript/application.js` or Turbo progress configuration where appropriate
- focused helper/component-state tests

### Exit criteria

- A foundation specimen page or test-only/reference surface renders all canonical primitives and states.
- Existing application remains usable even where old composition has not yet migrated.
- No global selector change silently removes accessible target size or focus indication.
- CSS build and full test suite pass.

## 10. UX-R2 — Canonical authenticated shell

### Objective

Replace PR 16's transitional shell geometry with the shell used throughout the new mockup family.

### Desktop contract

- 52px navy topbar spanning the complete viewport width.
- 208px navy sidebar below the topbar.
- Cloud workspace beside the sidebar.
- Brand in topbar.
- Compact office switcher in topbar.
- Reserved search region; render search only if it is functional and authorization-safe.
- Notification affordance only if it has real behavior; otherwise omit it.
- Compact user avatar/account affordance.
- Sectioned sidebar groups such as Workspace, Money, and System.
- Active nav uses teal left-edge indicator and restrained background, not a full-width solid teal block.
- Default nav text uses muted white; active text uses white.

### Navigation inventory

Keep the previously approved identity semantics:

- Dashboard;
- Directory;
- Clients;
- Suppliers;
- disabled future Departures;
- disabled future Travelers;
- disabled future Accounting;
- Administration for authorized users.

Section headings may group these destinations without changing their meaning. Disabled future destinations remain non-links and nonfocusable.

### Mobile contract

- At the approved breakpoint, sidebar becomes a Stimulus-controlled modal drawer.
- Topbar remains the stable mobile header.
- Focus moves into the drawer and returns to the opener.
- Escape and explicit close work.
- Background is inert while open.
- Body scroll is contained.
- Turbo navigation cannot leave stale open/inert state.
- Do not duplicate navigation DOM to create a no-JavaScript drawer.

### Likely files

- `app/views/layouts/application.html.erb`
- `app/views/layouts/_sidebar.html.erb`
- `app/views/layouts/_topbar.html.erb`
- `app/helpers/navigation_helper.rb`
- `app/javascript/controllers/navigation_drawer_controller.js`
- `app/assets/tailwind/application.css`
- shell/navigation controller and system tests

### Visual Gate A — shell

Stop and obtain stakeholder approval at desktop, 768px, and 375px before proceeding to page-family migration.

Review:

- exact topbar/sidebar proportions;
- brand and office placement;
- navigation grouping and active state;
- workspace width and gutters;
- type density;
- mobile drawer;
- focus behavior.

Approval authorizes these shell and foundation patterns, not the remaining view migrations.

## 11. UX-R3 — Party-profile reference archetype

### Objective

Make the Party page the canonical identity-record reference surface using `party-profile.html`, not the earlier generic record-overview pattern.

### Composition changes

- Remove the four-segment generic Party summary strip.
- Implement a compact identity header with:
  - initials/avatar treatment;
  - party display name;
  - kind chip;
  - active role chips;
  - concise kind-specific metadata;
  - one primary Edit profile action;
  - compact More actions affordance.
- Use a main/aside grid matching the reference proportions.
- Use screen-specific rows rather than generic definition lists wherever the reference does.

### Person reference

Build a person record aligned closely to `party-profile.html`:

- contact information rows;
- household and relationship rows;
- current operational involvement placeholder/section only when backed by real data;
- notes aside with permission-safe count and filtering;
- team membership and identifiers only where they fit without creating another equal-weight panel stack.

Do not invent client trips or departure data if those models do not yet exist.

### Organization adaptation

Adapt the same archetype to OceanView Cruises:

- organization initials/avatar tile;
- legal/trading identity and public website;
- contact rows;
- supplier-role summary;
- related people/organizations;
- notes aside;
- attention only when actionable;
- key identifiers in a compact supporting treatment.

Do not restore the generic stat strip simply because organization data differs from person data.

### Household adaptation

- household name and correspondence identity;
- shared contact information;
- household members/relationships;
- client-role summary when present;
- no supplier role action;
- notes and identifiers where appropriate.

### Canonical row primitives

Implement reference-quality components/partials for:

- contact row;
- relationship row;
- note row;
- compact identifier row;
- role-summary row/card;
- compact inline empty state;
- information callout.

Each row should define primary content, secondary metadata, states, and actions. Do not force every domain row through one universal `.dd-list-item` layout.

### Notes safety

- Scope visible notes before counting or rendering.
- A staff user must not infer administrator-only notes through count, empty-state copy, DOM, accessibility tree, or Turbo response.
- Preserve correction/removal history and original content according to authorization.

### Likely files

- `app/views/directory/parties/show.html.erb`
- `app/views/directory/shared/_party_chrome.html.erb`
- new/revised directory row partials
- `app/helpers/application_helper.rb`
- party controller query/presenter preparation where needed
- `app/assets/tailwind/application.css`
- party controller/helper/system tests

### State matrix

Verify:

- populated person;
- person linked to membership;
- populated supplier organization;
- client-only organization;
- dual-role organization;
- sparse organization;
- household;
- party with no roles;
- inactive role;
- deactivated party;
- missing usable direct contact;
- suppressed current primary;
- no visible notes for staff with hidden admin content.

### Visual Gate B1 — profile

Stop and review the running person profile and OceanView Cruises beside `party-profile.html` at matched desktop size, 768px, and 375px.

Do not begin broad party-maintenance migration until the profile archetype is approved.

## 12. UX-R4 — Data-entry reference archetype

### Objective

Implement the field kit and edit-flow patterns from `data-entry-patterns.html` and `cross-cutting-patterns.html`, then prove them on one substantial existing form.

### Field kit

Implement canonical patterns for:

- ordinary, required, optional, disabled, read-only, error, and code fields;
- select and date controls;
- textarea;
- short/code inputs;
- prefix/suffix input wrappers;
- checkbox, toggle, radio-card, and segmented controls;
- searchable party picker/combobox where an existing workflow needs party selection;
- inline validation and error summary;
- form-section header and supporting explanation;
- sticky form footer where justified;
- loading and successful-save states.

### Reference form

Use **Edit supplier details** for the first production form because it exercises:

- responsible office;
- default currency;
- portal URL;
- service categories;
- booking instructions;
- payment instructions;
- payment-term notes;
- commission notes;
- cancellation-policy notes.

Compose it as:

1. Responsibility
2. Commercial defaults
3. Services
4. Operating instructions
5. Commercial terms
6. Policies

Responsibility and Commercial defaults remain open. Lower-frequency long-text sections may use disclosures only when their headings indicate whether values exist.

### Command-boundary requirement

Supplier attribute update and category assignment/removal currently have separate command semantics. The UI must not pretend they are one atomic operation unless a coordinating command is separately designed, audited, and tested.

Acceptable implementation options:

- keep category changes as row-scoped Turbo Frame submissions within the focused supplier-edit page; or
- introduce a reviewed coordinator preserving authorization, locking, audit events, validation, and partial-failure behavior.

Do not issue several opaque requests from Stimulus and present them as one Save.

### Confirmation reference

Implement one consequential-action confirmation using an existing lifecycle command, preferably Supplier role deactivation or Party deactivation.

The confirmation must:

- name what changes;
- state material non-cascades;
- collect the required reason;
- retain server-side validation;
- show a destructive button only in the confirmation state;
- return focus predictably if modal/frame based;
- remain usable as a focused full page when directly navigated.

### Inline-edit reference

Implement at most one genuine single-field/row Turbo Frame edit as a reference. Do not use inline editing for a multi-field profile or a consequential correction.

### Likely files

- shared form partials/helpers
- `app/views/directory/roles/*` or focused supplier-profile views
- supplier-profile controllers/routes for focused GET pages
- Turbo Frame partials
- one small Stimulus controller only where interaction requires it
- `app/assets/tailwind/application.css`
- controller, helper, request, and system tests

### Visual Gate B2 — form

Stop and compare the running Edit supplier details page, one confirmation, and one inline edit against `data-entry-patterns.html` and `cross-cutting-patterns.html`.

Review:

- field height and typography;
- form-section rhythm;
- number of visible fields;
- disclosure behavior;
- validation errors;
- keyboard sequence;
- Save/Cancel hierarchy;
- loading/pending behavior;
- mobile layout.

UX-R5 is blocked until both B1 and B2 are approved.

## 13. UX-R5 — Party-maintenance adoption

### Objective

Apply the approved profile and data-entry patterns to all party-local maintenance surfaces.

### 13.1 Identity and alternate names

- Keep one focused identity form appropriate to person, organization, or household.
- Group person fields into Name, Additional name details, Communication details, and Personal details.
- Keep organization identity separate from supplier commercial fields.
- Keep household members out of the household identity form.
- Render alternate names display-first below identity.
- Add name opens one composer.
- Only one alternate-name row may enter edit state.
- Remove is a selected confirmation action, not a large persistent danger button.

### 13.2 Roles

- Roles page becomes display-only by default.
- Render separate Client and Supplier summary cards/rows.
- Add focused Edit client details and Edit supplier details pages.
- Add focused role Add, Deactivate, and Reactivate flows.
- Preserve household supplier ineligibility.
- Preserve role-specific command, lock-version, audit, and redirect behavior.

### 13.3 Contact information and purposes

- Group current contacts by Email, Phone, and Postal address.
- Use compact purpose chips and explicit suppressed/deactivated treatments.
- Replace persistent row forms with one row action menu or inline text actions.
- Add/Edit contact remains focused.
- Add a focused Manage purposes surface for one contact point.
- Set primary may use a row-scoped frame.
- Suppress and Deactivate require selected reason/confirmation states.
- Current and History become alternate views rather than simultaneously dominant panels.

### 13.4 Relationships and purposes

- Default to Current relationships; History is selected explicitly.
- Use canonical relationship rows.
- Add remains focused.
- Assign purpose, End, Correct, and Void are selected actions.
- Do not render all reason/date fields for every row.
- Keep corrections and voids visibly distinct from routine edits.

### 13.5 Notes

- Render current notes in the reference note-row format.
- Use a compact Add note composer.
- Permit only one correction editor at a time.
- Remove opens a selected confirmation.
- Current/History and Staff/Admin visibility controls follow permission-safe query rules.
- Preserve originals for corrected or removed notes.

### 13.6 Identifiers

- Render values in mono.
- Show type, issuer, ownership context, and status compactly.
- Add identifier opens one composer or focused page.
- Deactivate/Reactivate are selected row actions.
- Current and History are alternate list states.
- Do not render a deactivation-reason field beneath every identifier.

### 13.7 Record and lifecycle

- Record displays technical and lifecycle history.
- Party lifecycle appears as a restrained action region, not a permanently open reason form.
- Deactivate/Reactivate opens the approved consequential confirmation.
- Preserve dependency reporting and do not imply cascading role/contact changes.

### Browse-state acceptance rule

> A browse surface renders no editable field unless the user has explicitly opened one lightweight composer or selected one row for editing.

### Likely files

- `config/routes.rb`
- party-local controllers and new focused GET actions/controllers
- `app/views/directory/parties/*`
- `app/views/directory/roles/*`
- `app/views/directory/contact_information/*`
- `app/views/directory/contact_points/*`
- `app/views/directory/relationships/*`
- `app/views/directory/party_relationships/*`
- `app/views/directory/notes/*`
- `app/views/directory/identifiers/*`
- `app/views/directory/records/*`
- focused Turbo Frame partials/controllers
- associated controller, helper, model/service regression, and system tests

### Exit criteria

- No party-local collection renders multiple persistent forms.
- Every current command remains reachable through a clear action.
- Direct URLs to focused GET surfaces are authorized and agency-scoped.
- Error rerenders retain entered data and context.
- Current/history and permission boundaries are correct.
- Full test suite passes.
- Manual responsive and keyboard review passes.

## 14. UX-R6 — Systematize, document, and remove superseded code

### Objective

Turn approved reference work into the canonical application contract and remove transitional duplication safely.

### Deliverables

- Update `docs/ui/interface-contract.md` to the approved system.
- Update the design system where implementation exposed necessary clarifications.
- Document canonical partial/helper/class names.
- Add a component-to-reference index.
- Remove selectors only after `rg` confirms no remaining consumer.
- Remove superseded PR 16 Party summary-strip code if no other approved consumer exists.
- Remove obsolete generic row/form variants after all in-scope consumers migrate.
- Normalize icon usage on migrated surfaces.
- Add contributor guidance for choosing:
  - display row;
  - focused page;
  - Turbo Frame inline edit;
  - modal confirmation;
  - disclosure;
  - empty-state type.
- Document explicitly deferred components and screen families.

### Visual regression coverage

Create deterministic screenshots or equivalent visual fixtures for:

- authenticated shell desktop;
- shell mobile drawer open/closed;
- person Party profile;
- OceanView organization profile;
- household profile;
- sparse profile;
- Edit supplier details;
- validation-error form;
- consequential confirmation;
- contact rows including suppressed and deactivated;
- permission-safe Notes empty state;
- each canonical empty-state family exercised by current functionality.

If pixel-diff automation is not adopted, store reproducible capture instructions, viewport sizes, seed identities, and expected state descriptions. Do not call ad hoc screenshots a regression suite.

### Exit criteria

- The interface contract describes implemented behavior rather than aspiration.
- No unresolved old/new selector pairs remain in the adopted party surfaces.
- Reference captures have stakeholder approval.
- Deferred work is listed explicitly.
- Integration branch is ready for final review against `main`.

## 15. Responsive contract

Validate every migrated surface at minimum:

| Width | Expected behavior |
| --- | --- |
| 375px | Modal drawer; single-column content; accessible action order; no page overflow; touch-operable controls |
| 768px | Shell transition; deliberate grid collapse; scrollable tabs where required; compact but readable forms |
| Reference desktop viewport | Direct visual comparison to HTML mockup |
| 1280px | Realistic laptop workspace after sidebar; no mockup-only extra width assumptions |

Additional checks:

- 200% browser zoom;
- long party and agency names;
- long translated-like labels where practical;
- long note and policy text;
- empty and high-volume collections;
- keyboard-only navigation.

## 16. Accessibility contract

- One `h1` per page and logical heading order.
- Landmarks for topbar, primary navigation, main content, and complementary regions.
- Current nav and tab exposed through `aria-current`.
- Icon-only actions have accessible names.
- Color never carries status alone.
- Keyboard focus is visible on navy, Cloud, and white surfaces.
- Drawer and modal focus are contained and restored.
- Turbo Frame replacement preserves meaningful focus or announces the result.
- Validation summaries link to fields where practical.
- Required fields use a conventional marker and accessible text.
- Permission-hidden information is absent from the response, not visually hidden.
- Native semantics are preferred over unnecessary ARIA roles.
- Do not label ordinary disclosure lists as ARIA menus unless full menu keyboard behavior is implemented.

## 17. Testing contract

### Unit/helper/presenter tests

- semantic status and role treatments;
- currency/code/numeric formatting roles;
- icon rendering and accessibility defaults;
- visible note scoping and counts;
- empty-state selection;
- party-kind and role-state display decisions.

### Controller/request tests

- agency scoping on every new focused GET surface;
- authorization parity with its mutation command;
- error rerender or redirect context;
- Turbo Frame and ordinary HTML responses where both are supported;
- no restricted data in rendered HTML;
- correct current navigation and breadcrumbs.

### Service/model regression tests

Do not rewrite service tests for presentation changes. Retain coverage for:

- command ownership;
- optimistic concurrency;
- office and role invariants;
- contact suppression/deactivation;
- primary-purpose assignments;
- role and party lifecycle;
- note and relationship history;
- identifier lifecycle;
- audit events.

### System tests

Cover representative end-to-end flows:

- navigate shell and mobile drawer;
- view each party kind;
- edit identity;
- add/edit an alternate name;
- edit client details;
- edit supplier details and categories;
- add/edit/suppress/deactivate contact;
- assign and end a contact purpose;
- add/end/correct/void a relationship;
- add/correct/remove a note;
- add/deactivate/reactivate an identifier;
- deactivate/reactivate a role;
- deactivate/reactivate a party;
- exercise validation errors and Cancel paths;
- verify staff cannot infer administrator-only notes.

Prefer semantic assertions and accessible names over brittle assertions against entire class strings.

## 18. Manual visual-review checklist

For each reference gate, compare screenshots side by side and assess:

- Is the shell silhouette the same?
- Do type sizes and weights match?
- Does numeric/identifier content use mono appropriately?
- Are page titles and panel headings restrained?
- Are cards defined primarily by borders rather than shadow?
- Do rows have comparable density?
- Is the page using the same amount of whitespace?
- Are actions placed and emphasized similarly?
- Does the page distinguish display, edit, and confirmation states?
- Are suppressed, deactivated, warning, and error states visually distinct?
- Do empty states express the correct meaning?
- Does the 1280px view still work after accounting for real shell width?
- Does keyboard interaction feel intentional?

Record each issue as:

- token mismatch;
- component mismatch;
- composition mismatch;
- interaction mismatch;
- domain mismatch;
- accessibility mismatch;
- intentional deviation.

Do not close a composition mismatch with one-off view CSS unless the reference genuinely defines a unique component.

## 19. Out of scope

- Implementing Departures, client trips, supplier arrangements, air, or financial domains solely because corresponding mockups exist.
- Global search without a search and authorization contract.
- Notification functionality without a notification domain.
- Full administration and dashboard migration before the reference gates.
- Client portal or external-facing interfaces.
- Print-template implementation beyond preserving future compatibility.
- Multi-currency domain changes.
- New domain status transitions.
- ViewComponent, React, Vue, or another frontend application framework.
- Optimistic client-side financial or derived-status calculation.
- Pixel-perfect copying that violates real domain or accessibility requirements.

## 20. Deferred adoption after this program

After the integration branch is approved and merged, plan remaining views by surface family:

1. Directory collections and search;
2. administration records and forms;
3. dashboard;
4. future operational records;
5. future financial workspaces;
6. print documents.

Those programs reuse the approved system. They do not reopen typography, shell, spacing, or foundational component decisions without a documented reason.

## 21. Program definition of done

The integration PR is ready for `main` when:

- UX-R0 through UX-R6 are merged into the integration branch;
- Visual Gates A, B1, and B2 are explicitly approved;
- the Party profile and party-maintenance family use the new design system;
- the current app contains no persistent multi-form browse surfaces within that family;
- person, organization, and household states are verified;
- client, supplier, dual-role, no-role, inactive-role, and ineligible-role states are verified;
- the documented shell, typography, spacing, icons, fields, rows, empty states, and interactions are implemented;
- tenant isolation, authorization, commands, audit, and history remain intact;
- automated tests and CSS build pass;
- 375px, 768px, reference-desktop, 1280px, and 200% zoom checks pass;
- visual comparison evidence is attached;
- the interface contract is updated to implemented reality;
- obsolete selectors and markup are removed only after consumer verification;
- remaining page families are clearly deferred.

## 22. PR checklist for every slice

- [ ] Identify the reference design-system section and HTML mockup.
- [ ] State the precise in-scope surfaces.
- [ ] State domain behavior that remains unchanged.
- [ ] List canonical primitives added or changed.
- [ ] List deprecated primitives and remaining consumers.
- [ ] Include desktop, 768px, and 375px captures for visual work.
- [ ] Include keyboard and focus verification.
- [ ] Include loading, error, empty, disabled, and long-content states where applicable.
- [ ] Confirm restricted content is scoped before rendering.
- [ ] Report CSS build and automated tests.
- [ ] Explain intentional deviations from the reference.
- [ ] Confirm the slice did not expand into an out-of-scope page family.
