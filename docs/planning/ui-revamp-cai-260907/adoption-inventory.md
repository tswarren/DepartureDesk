# CAI 2026-09-07 adoption inventory

Program inventory for `ui-revamp-cai-260907-adoption`. Starting point: `main` after the party-record shell (PR 16). Reuses seed identities from [docs/planning/phase-2-ux-refactor/baseline-inventory.md](../phase-2-ux-refactor/baseline-inventory.md).

## Authority

- Domain requirements and terminology remain first.
- [docs/ui/ui-revamp-cai-260907/departuredesk-design-system.md](../../ui/ui-revamp-cai-260907/departuredesk-design-system.md) supersedes [docs/ui/interface-contract.md](../../ui/interface-contract.md) where they conflict (see the supersession table at the top of the contract).
- Screen mockups in `docs/ui/ui-revamp-cai-260907/` are composition references, not domain permission to invent unbuilt records.

## Gate screenshot capture

Local Docker does not include Chrome. Capture from a host browser or session browser tools against the running `web` service after `docker compose up`.

| Gate | Running application | Reference | Viewports |
| --- | --- | --- | --- |
| A | Authenticated shell (Dashboard after sign-in) | Any full-screen mockup, e.g. `party-profile.html` chrome | 375, 768, reference desktop, 1280 |
| B1 | Person, OceanView Cruises, a household, Cedar & Salt Expeditions | `party-profile.html` | same |
| B2 | Edit supplier details, validation failure, party deactivate | `data-entry-patterns.html` | same |

Seed identities (Horizon Tours agency, development-only):

- Person: Alex Morgan (linked membership person in fixtures/seeds)
- OceanView Cruises: `/directory/parties/01a07a5c-f8bd-73fa-96c2-d268f8328544`
- Sparse organization: Cedar & Salt Expeditions
- Household: use an existing seeded household when present

Sign in with the development seed credential. Do not commit `.env` or real personal data.

## Selector classification

| Selector | Classification | Owner | Notes |
| --- | --- | --- | --- |
| `.dd-app-shell`, `.dd-sidebar`, `.dd-main`, `.dd-topbar`, `.dd-workspace` | restyle in place | UX-R2 | 52px / 208px grid; brand moves to topbar |
| `.dd-sidebar-brand` | replace | UX-R2 | Brand leaves sidebar; keep close button on mobile |
| `.dd-sidebar-nav`, `.dd-sidebar-item`, `.dd-sidebar-footer` | restyle in place | UX-R2 | Teal left-edge active; muted default; section labels added |
| `.dd-brand`, `.dd-brand-mark`, `.dd-brand-name` | restyle in place | UX-R2 | Used in topbar and auth |
| `.dd-topbar-account`, `.dd-account-agency`, `.dd-account-user`, `.dd-topbar-office` | restyle in place | UX-R2 | Navy topbar contrast; compact office link |
| `.dd-drawer-*` | restyle in place | UX-R2 | Existing Stimulus drawer |
| `.dd-skip-link` | retain | UX-R1 | Keep amber focus |
| `.dd-page-header`, `.dd-page-heading`, `.dd-page-actions`, `.dd-page-title`, `.dd-eyebrow`, `.dd-page-description` | restyle in place | UX-R1 | Density; keep `h1.dd-page-title` for tests |
| `.dd-breadcrumbs`, `.dd-breadcrumb-sep` | restyle in place | UX-R1 | |
| `.dd-subnav` | restyle in place | UX-R3 | No wrap; horizontal scroll; short labels |
| `.dd-record-header`, `.dd-record-identity`, `.dd-record-meta`, `.dd-record-kicker`, `.dd-record-actions` | replace | UX-R3 | Identity header with initials tile |
| `.dd-action-menu` | retain (header only) | UX-R3 | Native `details`/`summary`; Roles + Record links |
| `.dd-summary-strip`, `.dd-summary-segment*` | remove after migration | UX-R3 / UX-R6 | Party must not manufacture metrics |
| `.dd-content-grid--main-aside` | restyle in place | UX-R3 | Max content width; capped aside |
| `.dd-panel*` | restyle in place | UX-R1 | Compact padding, border-led, little shadow |
| `.dd-list`, `.dd-list-item`, `.dd-list-title`, `.dd-list-detail` | restyle; do not force all rows through one layout | UX-R3 | New row primitives alongside |
| `.dd-button*` | restyle in place | UX-R1 | 32–34px desktop; states matrix |
| `.dd-field*`, `.dd-label`, `.dd-form*`, `.dd-choice*` | restyle in place | UX-R1 / UX-R4 | 34–36px fields; required marker |
| `.dd-badge*` | restyle in place; add `--neutral` | UX-R1 | |
| `.dd-empty-state*` | restyle; add family modifiers | UX-R1 | Six families |
| `.dd-table*` | restyle in place | UX-R1 | Compact cell padding; mono numeric later |
| `.dd-alert*` | restyle in place | UX-R1 | |
| `.dd-grid--metrics`, `.dd-metric*` | retain | deferred | Dashboard placeholders only |
| `.dd-auth-*` | retain composition; inherit Plex | UX-R1 | Do not recompose auth |
| `.dd-definition-list` | restyle; reduce on Party overview | UX-R3 | Prefer row primitives on profile |
| `.dd-attention-callout`, `.dd-waypoint`, `.dd-missing` | restyle / replace with inline empty + info callout | UX-R3 | |
| `.dd-icon*` | restyle in place; add `--xl` if needed | UX-R1 | 16/20/24/32–40 |
| `.dd-global-search`, `.dd-filter-bar`, `.dd-metric-card*`, `.dd-progress*` | do not add | out of scope | |

## Mockup pattern → Rails

| Mockup | Rails target | Slice |
| --- | --- | --- |
| Shell (all full-screen mockups) | `layouts/application`, `_topbar`, `_sidebar` | R2 |
| `party-profile.html` identity header | `_party_chrome.html.erb` | R3 |
| Contact / relationship / note rows | `directory/shared/_contact_row`, `_relationship_row`, `_note_row` | R3 / R5B |
| Identifier / role-summary / inline empty / callout | shared partials | R3 |
| `data-entry-patterns.html` field kit | `.dd-field` states, `.dd-field-required`, prefix wrappers, `.dd-disclosure` | R4 |
| Edit supplier details | new GET `directory/supplier_profiles#edit` | R4 |
| Category immediate save | Turbo Frame partials on supplier edit | R4 |
| Consequential confirmation | focused `parties#deactivate` GET + existing POST | R4 |
| `empty-states.html` | `.dd-empty-state--*` modifiers | R1 |
| `cross-cutting-patterns.html` | confirmation page; derived vs editable later | R4 |

## Stimulus and Turbo

| Current | Plan |
| --- | --- |
| `navigation-drawer` only | Keep; ensure Turbo close/inert; no duplicated nav DOM |
| No form Stimulus | Optional disclosure auto-open on error via native `open` attribute (no JS required if server sets `open`) |
| Turbo Frames unused on party rows | Add for categories, set-primary, pin |

## Test collisions

- `h1.dd-page-title` must remain the party display name on party-local pages.
- `nav[aria-label=Party]` links currently assert `Contact information`; become `Contact`.
- `add_party_role` expects `##{role}_profile_create_form` on the Roles browse page; R5A moves Add role to a focused page or selected composer — update helper to visit the add-role surface.
- Role / alternate-name / lifecycle tests that look for persistent forms on browse pages must follow the new focused GET or selected confirmation.
- Primary nav still `aria-label='Primary navigation'`; Directory label unchanged.
- System tests skip locally without Chrome; GitHub CI remains the browser gate.

## Party-local consumers

| Surface | Current files | Slice that recomposes |
| --- | --- | --- |
| Overview | `parties/show`, `_party_chrome` | R3 |
| Identity edit | `parties/edit`, kind field partials | R5A |
| Alternate names | bottom of `parties/edit` | R5A |
| Roles | `roles/show`, focused `client_profiles` / `supplier_profiles` new+edit | R4 (supplier edit), R5A (display-first) |
| Record | `records/show` | R4 (deactivate page), R5A (display-first) |
| Contact | `contact_information/*`, `contact_points/*` | R5B |
| Relationships | `relationships/*`, `party_relationships/*` | R5B |
| Notes | `notes/*`, `party_notes` | R5B |
| Identifiers | `identifiers/show` | R5B |
| Directory / clients / suppliers indexes | index views | deferred (global CSS only) |
| Administration / dashboard | existing views | deferred (shell wrap only) |
