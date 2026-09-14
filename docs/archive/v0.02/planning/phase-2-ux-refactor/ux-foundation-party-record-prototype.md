# UX Foundation — Party Record Prototype

**Proposed branch:** `ux-foundation-party-record-prototype`  
**Purpose:** Validate the revised DepartureDesk interface direction against one real, navigable record before migrating the rest of the application.  
**Status:** Prototype and visual-review gate. Do not treat this slice as authorization for a broad view rewrite.

## Outcome

Build one representative supplier organization record inside the proposed application shell and redesign its party overview so stakeholders can judge whether the implemented product resembles the approved mockups in hierarchy, density, spacing, navigation, and progressive disclosure.

This slice is successful only when a reviewer can open the record in Rails, navigate it with realistic data, compare it with the supplied mockups, and make an informed accept/revise/reject decision about the UX direction.

## Why this record

The existing party detail is the best available stress test because it currently combines many competing concerns:

- canonical and alternate identity;
- party kind and lifecycle status;
- client and supplier roles;
- responsible office and advisor assignments;
- contact destinations and purposes;
- external identifiers;
- relationships;
- notes;
- team membership where applicable;
- creation and update metadata;
- ordinary editing and exceptional lifecycle actions.

The prototype must prove that DepartureDesk can retain this capability without presenting every field and maintenance command at once.

## Governing constraints

- Do not change routes, commands, authorization, tenancy, persistence, audit behavior, or domain terminology merely to simplify the prototype.
- A `Party` remains the agency-owned person, household, or organization identity. Client and supplier remain roles of that party.
- Use **Departure** for the primary dated operational record. Do not introduce “Trip” as a substitute for Departure in shared navigation or interface vocabulary.
- Use the existing Harbor & Waypoint palette and its semantic meanings.
- Navy represents structure, teal represents action or selection, and amber represents a waypoint or item requiring attention.
- Do not introduce ViewComponent, a third-party icon library, or view-specific CSS files.
- Use curated SVG partials through the existing icon helper strategy.
- Preserve keyboard access, visible focus, semantic HTML, Turbo compatibility, and current no-JavaScript fallbacks where they exist.
- Do not migrate unrelated pages during this slice.

## Explicit non-goals

This slice does not include:

- an application-wide view migration;
- a general redesign of all administration or directory pages;
- creation of the future departures workspace;
- implementation of departure metrics, financial summaries, capacity, milestones, or supplier arrangements;
- redesign of every party-local maintenance page;
- changes to party, role-profile, contact, relationship, note, or identifier business rules;
- a generalized dashboard or chart system;
- speculative components not exercised by the prototype;
- removal of old CSS before its remaining consumers have been identified.

## Reference record

Create or expand a deterministic development seed for a realistic supplier organization. The recommended record is **OceanView Cruises**.

The seed should exercise:

- organization legal or canonical name;
- one alternate or trading name;
- active party status;
- active supplier role;
- at least two supplier service categories;
- responsible office;
- primary email;
- primary phone;
- physical or correspondence address;
- distinct billing address;
- one suppressed or deactivated contact point;
- at least two external identifiers;
- at least two current relationships to people;
- one operationally important or pinned note;
- one ordinary historical note;
- realistic created and updated timestamps where practical.

Do not assign implausible roles solely to make every control appear. A supplier organization does not need to be made a client or team member for this prototype.

Also retain or create one sparse party record for a secondary empty-state check. The populated OceanView Cruises record is the formal visual-review target.

Seed creation must remain idempotent and must not weaken production constraints.

## Phase 0 — Baseline capture

Before changing presentation code, capture the existing OceanView Cruises party detail at:

- 1280px wide desktop;
- 768px wide tablet;
- 375px wide mobile.

Record the following baseline observations in the PR description:

- visible page regions before the first scroll;
- number of visible forms;
- number of visible actions;
- number of equal-weight panels;
- whether primary contact information is visible before scrolling;
- whether supplier status and responsibility are visible before scrolling;
- horizontal overflow or wrapping defects;
- approximate total page length.

The screenshots are review evidence, not automated golden masters.

## Phase 1 — Canonical application shell

Implement the shell defined by the revised interface contract:

```text
dd-app-shell
├── dd-sidebar
│   ├── dd-sidebar-brand
│   ├── dd-sidebar-nav
│   └── dd-sidebar-footer
└── dd-main
    ├── dd-topbar
    └── dd-workspace
```

### Desktop behavior

- Use a persistent navy sidebar and white top utility bar.
- Keep the workspace on the Cloud background with white content surfaces.
- Use teal for the active navigation treatment. Do not use amber for active navigation.
- Establish one canonical sidebar width, workspace maximum width, and workspace gutter scale.
- The sidebar must not reduce the main workspace to a narrow centered column at 1280px.
- Render the current agency/user context in the topbar without allowing it to dominate the page.
- A global-search affordance may be visually present only if it is implemented or explicitly marked as unavailable without behaving like an active control. Prefer omission to a nonfunctional field.

### Mobile behavior

- Below 768px, convert the sidebar to an operable drawer.
- Supply an accessible name for the drawer toggle.
- Move focus predictably when the drawer opens and return it to the trigger when it closes.
- Support Escape closure.
- Prevent obscured background content from receiving unintended interaction while the drawer is modal.
- Preserve the skip link and amber focus ring.
- Do not permit page-level horizontal overflow.

### Transitional behavior

Existing pages may render inside the new shell without being redesigned in this branch. Their routes and essential actions must continue to work. Transitional visual inconsistency outside the prototype record is acceptable and should be documented rather than expanded into an unbounded migration.

### Shell review checkpoint

Pause after the shell is usable and review:

- sidebar width and density;
- logo scale and treatment;
- topbar height;
- workspace width and gutters;
- active-navigation treatment;
- 1280px resemblance to the supplied mockups;
- 375px drawer behavior.

Resolve structural shell concerns before composing the party record.

## Phase 2 — Minimum shared presentation primitives

Add or normalize only the reusable primitives required by the prototype:

- breadcrumbs;
- record identity header;
- page action group;
- horizontal subnavigation;
- compact summary strip and summary segment;
- main/aside content grid;
- ordinary and compact panel variants;
- fact or description grid;
- primary and supporting cell text;
- attention callout;
- overflow action menu;
- standard empty and missing-information treatments;
- existing buttons, badges, tables, fields, alerts, and icons as needed.

Suggested structural vocabulary:

```text
dd-record-header
dd-record-identity
dd-record-meta
dd-record-actions
dd-summary-strip
dd-summary-segment
dd-content-grid
dd-content-grid--main-aside
dd-stack
dd-panel--compact
dd-fact-grid
dd-attention-callout
dd-action-menu
```

Exact names may change during implementation, but one canonical name must be selected for each role. Do not leave parallel component names such as `.dd-grid--metrics` and `.dd-metrics-grid` active without documenting which is canonical and which is transitional.

Do not force every summary fact into an independent metric card. The mockups use both free-standing cards and compact segmented strips. The party record should use the compact strip.

## Phase 3 — Party overview composition

Refactor the party `show` presentation into an overview. The page should answer, in order:

1. Who or what is this?
2. What roles and lifecycle state does it have?
3. How do we contact it?
4. Who is responsible for it?
5. What does it supply or do?
6. What currently requires attention?
7. Where do I go to maintain the complete record?

### Breadcrumb

Render a quiet hierarchy such as:

```text
Directory / Suppliers / OceanView Cruises
```

Use actual route ownership and current terminology. Do not imply that supplier and party are separate identities.

### Record header

The header should contain:

- canonical display name as the single `h1`;
- Organization kind badge;
- Active lifecycle badge;
- Supplier role badge or concise role treatment;
- one short identifying or responsibility line if useful;
- one visually primary ordinary action, expected to be **Edit organization**;
- an overflow action trigger for infrequent or exceptional actions.

Do not place a destructive action beside the ordinary primary action.

### Subnavigation

Render the party-local navigation on the overview and child pages involved in the prototype. Recommended destinations:

- Overview;
- Contact information;
- Relationships;
- Supplier profile;
- Notes;
- Record.

Only real, authorized destinations may be interactive. A current item must use `aria-current="page"`. A temporarily unavailable destination must not masquerade as an active link.

### Summary strip

Render compact segments for:

- primary contact;
- responsible office;
- supplier services or categories;
- items needing attention.

Each segment should have a short label, a strong primary value, and at most one muted supporting line. Do not turn ordinary descriptive facts into oversized dashboard numbers.

### Main/aside grid

At desktop widths, use an approximately 2:1 main/aside relationship. Collapse to one column below the selected responsive threshold, with main content before aside content in the document order.

#### Main column

Prioritize:

1. **Contact summary** — eligible primary email, phone, and addresses with purpose and usability state.
2. **Supplier summary** — active role state, service categories, responsible office, and the small number of supplier facts needed for orientation.
3. **Current relationships** — related people or organizations using concise rows.
4. **Notes** — pinned/important note first and a short recent-note summary.

Each section should provide a clear link to its focused maintenance destination where one exists.

#### Aside

Use compact panels for:

- key external identifiers;
- record responsibility or ownership information not already adequately represented;
- actionable missing information or contact restrictions;
- compact lifecycle metadata.

Do not create an aside card merely to repeat information already prominent in the header or summary strip.

### Information removed from the default overview

The following should not appear as fully expanded inline maintenance forms on the overview:

- alternate-name editing;
- role creation or deactivation forms;
- contact-point creation or editing;
- relationship creation or correction;
- identifier creation or editing;
- complete note history or note-maintenance forms;
- complete Created/Updated record metadata;
- deactivation or reactivation workflow.

Where focused routes already exist, link to them. Where they do not, use the smallest accessible temporary disclosure or retain a clearly documented transitional path. Do not create a large family of speculative routes solely for the prototype.

## Action hierarchy

- Show at most one visually primary action in the record header.
- Use secondary buttons for constructive alternate actions.
- Use quiet links for navigation, back, cancel, and “view all” behavior.
- Use the overflow menu for infrequent record actions.
- Keep destructive lifecycle actions visually and spatially separate from ordinary editing.
- Do not convert a server-authoritative command into an unconfirmed client-only action.
- Preserve existing confirmation copy for destructive actions.

### Overflow menu behavior

If an action menu is introduced, define and test:

- accessible trigger name;
- keyboard opening;
- predictable focus placement;
- Escape closure;
- outside-click closure where applicable;
- focus return to the trigger;
- viewport-edge alignment;
- authorized and disabled item behavior;
- a usable fallback if JavaScript is unavailable and the application currently promises one.

## Content-priority rule to validate

Use this prototype to test the following proposed contract language:

> An overview presents identity, operational state, primary usable contact information, responsibility, current roles, current relationships, exceptions, and the next likely actions. Complete maintenance forms, full history, technical metadata, and infrequent lifecycle controls belong on focused subpages or purposeful disclosures.

If implementation shows that an excluded item is required for frequent work, document that finding and revise the rule rather than silently putting every control back on the overview.

## Sparse and exceptional states

Verify at least:

- populated active supplier organization;
- sparse active organization;
- deactivated party;
- no eligible primary contact destination;
- suppressed primary contact point;
- inactive responsible office retained for historical display;
- long organization and alternate names;
- several supplier categories;
- no current relationships;
- no notes.

Missing information should normally use a compact missing-data treatment with an available next action. Do not render a large empty panel for every absent collection.

## Responsive requirements

### 1280px

- Sidebar, topbar, record header, summary strip, and main/aside grid are simultaneously legible.
- The primary contact, supplier role, supplier services, and responsible office are visible before scrolling on the populated target record where practical.
- The workspace uses the available width without stretching readable prose or producing large dead zones.

### 768px

- Shell transition does not obscure content.
- Summary segments reflow intentionally.
- Main/aside layout collapses without changing semantic reading order.
- Subnavigation remains operable without overlapping actions.

### 375px

- Sidebar is an accessible drawer.
- Header title and badges wrap without collision.
- Action controls remain reachable and correctly ordered.
- Summary segments stack or scroll according to one documented pattern.
- Tables or long values remain contained.
- No page-level horizontal overflow occurs.

## Accessibility requirements

- Preserve one `h1` and a logical heading hierarchy.
- Use landmark elements for navigation, main content, and complementary content where appropriate.
- Give all icon-only controls accessible names.
- Do not communicate kind, role, state, or attention by color alone.
- Keep amber focus treatment visible against navy, white, and Cloud surfaces.
- Ensure hidden drawer/menu content is not focusable.
- Maintain logical focus order matching the visual order.
- Maintain readable contrast for primary, muted, disabled, badge, and callout text.
- Do not use placeholder text as the only label.

## Verification

### Automated tests

Add or update focused tests for:

- authenticated shell rendering;
- correct active navigation state;
- party overview authorization and agency scoping;
- authorized party-local navigation destinations;
- presence of the canonical party name and role/status text;
- absence of unauthorized actions;
- preserved existing edit, deactivate/reactivate, contact, relationship, note, and role command behavior;
- action-menu or drawer behavior where it is practical to cover in system tests;
- deterministic seed behavior where seed tests exist.

Do not assert incidental class lists throughout controller tests. Prefer semantic structure, accessible names, current navigation state, and important user-visible content.

### Manual visual checks

Capture the completed target record at 1280px, 768px, and 375px using the same record and comparable viewport framing as the baseline.

Check:

- clipping, overlap, and overflow;
- focus visibility;
- sidebar and topbar proportions;
- title and badge wrapping;
- primary-action prominence;
- summary-strip density;
- main/aside balance;
- panel alignment and spacing;
- long-value handling;
- empty and exceptional states;
- keyboard operation of the drawer and action menu.

## Stakeholder visual-review gate

Stop after the prototype record and its supporting shell are complete. Do not begin general migration until the stakeholder reviews the live record or complete viewport captures.

The review should answer:

1. Does this look and feel like the same product as the supplied mockups?
2. Is the information density appropriate for operational work?
3. Are the correct facts visible before scrolling?
4. Is anything prominent that belongs in maintenance?
5. Is anything hidden that users need routinely?
6. Do the party-local destinations match the user’s mental model?
7. Does the main/aside composition create useful hierarchy?
8. Can a user readily determine where to update contact or supplier information?
9. Does the page remain coherent with sparse data?
10. Does it feel like an operational record rather than a collection of CRUD forms?

Classify review findings as:

- **Approved** — incorporate the pattern into the interface contract;
- **Revise** — change the prototype and present it again;
- **Rejected** — preserve the existing behavior or test an alternate pattern.

Approval of this prototype approves the demonstrated patterns, not every future page composition.

## Contract update after approval

Once the visual gate is met, amend the interface contract with the decisions proven by the implementation:

- canonical application-shell anatomy and dimensions;
- record-overview archetype;
- main/aside grid proportions and collapse order;
- metric-card versus summary-strip usage;
- overview content eligibility;
- progressive-disclosure and maintenance-placement rules;
- missing-information and empty-state rules;
- action-menu and mobile-drawer interaction contracts;
- canonical component names and deprecated predecessors;
- verified responsive behavior.

Do not finalize these values in the contract merely because they appeared in an initial implementation. The prototype and review determine the contract.

## Follow-on work after approval

Plan later migration by surface family rather than performing a repository-wide sweep:

1. finish application-shell adoption and remove superseded shell CSS;
2. migrate directory collection pages;
3. migrate party-local overview and maintenance pages;
4. migrate administration collections and records;
5. normalize create/edit workflows;
6. use the accepted archetypes when future Departure and operations pages are built.

Each follow-on slice must inventory its views, identify old primitives being replaced, migrate all in-scope consumers, verify responsive behavior, and remove superseded CSS only when no remaining consumer depends on it.

## Definition of done

The prototype is ready for stakeholder review when:

- the deterministic OceanView Cruises seed is available;
- baseline captures exist;
- the canonical sidebar/topbar shell is operable;
- the populated party record uses the new overview composition;
- the sparse party state has been checked;
- ordinary commands and authorization remain intact;
- keyboard and responsive checks pass at 375px, 768px, and 1280px;
- completed comparison captures exist;
- implementation-specific contract amendments are documented as proposals;
- the PR explicitly stops at the stakeholder visual-review gate;
- no unrelated page family has been redesigned.

## PR description checklist

- [ ] Link the revised interface contract and palette.
- [ ] Identify the target party record and seed command.
- [ ] Include baseline captures at all three widths.
- [ ] Include completed captures at all three widths.
- [ ] Summarize shell decisions and any contract deviations.
- [ ] List new canonical presentation primitives.
- [ ] List transitional or deprecated primitives still in use.
- [ ] Confirm no domain, authorization, tenancy, or command behavior changed.
- [ ] Report automated and manual verification.
- [ ] List unresolved visual decisions for stakeholder review.
- [ ] State that broad migration is blocked pending visual approval.
