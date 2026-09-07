# UX Foundation — Baseline inventory

Captured before presentation edits. Horizon Tours stands in for OceanView Cruises until the supplier-only seed exists.

## CSS collisions

Reuse and restyle:

- `.dd-workspace` — currently `width: min(96rem, 100%)` centered; becomes fluid post-sidebar workspace
- `.dd-subnav` — keep teal current treatment; stop wrapping at narrow widths (already `overflow-x: auto` below 600px)
- `.dd-brand`, `.dd-brand-mark`, `.dd-brand-name` — move into sidebar brand
- `.dd-page-title` — keep on `h1` so system tests continue to wait on `h1.dd-page-title`

Leave unchanged:

- `.dd-grid--metrics` / `.dd-metric*` — dashboard placeholders only
- `.dd-auth-shell` and auth brand
- buttons, badges, panels, forms, tables, alerts, focus ring

Remove once unused:

- `.dd-app-header`, `.dd-header-inner`, `.dd-primary-nav`, `.dd-nav-item`, `.dd-header-account` (replaced by sidebar/topbar)

Do not add:

- `.dd-metric-card`, `.dd-filter-bar`, `.dd-progress`

## Layout consumers

Authenticated pages all render through `app/views/layouts/application.html.erb`. Nested party maintenance pages (`contact_points`, `party_relationships`, purposes) keep local headers and gain the updated subnav only.

## Test collisions

- Primary nav `aria-label='Primary navigation'` with Clients `count: 0` in clients/suppliers controller tests
- Role create forms asserted on party `show`
- Alternate-name mutations redirect to party `show`
- Lifecycle forms asserted on party `show`
- System helper `add_party_role` looks for create forms on the current page
- `open_directory` clicks exact text `Directory`

## After verification

Automated coverage: `./dev/rails-docker bin/rails test` — 504 runs, 0 failures. Tailwind build succeeded.

Development seeds now include:

- OceanView Cruises (supplier-only review record) at `/directory/parties/01a07a5c-f8bd-73fa-96c2-d268f8328544`
- Cedar & Salt Expeditions (sparse organization: no roles, contacts, relationships, notes, or identifiers)

Auth pages still use `.dd-auth-shell` (confirmed via `GET /session/new`). The Docker browser tools in this session cannot reach `localhost`, so 375/768/1280 screenshots were not captured here. Visual review should use a host browser at those widths after signing in with the development seed credential.
