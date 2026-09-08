# DepartureDesk Presentation and Interface Contract

This is the presentation contract for implemented application layouts after the CAI 2026-09-07 adoption. Domain commands, tenancy, authorization, and terminology are unchanged. The design system in `docs/ui/ui-revamp-cai-260907/departuredesk-design-system.md` remains the visual authority for in-scope surfaces.

Reuse these `.dd-` classes before adding new presentation rules. Do not introduce ViewComponent, third-party icon fonts/gems, or view-specific CSS files. Tokens and component CSS live in `app/assets/tailwind/application.css`.

## Canonical names

| Concern | Name |
| --- | --- |
| Authenticated shell | `.dd-app-shell`, `.dd-topbar`, `.dd-sidebar`, `.dd-main`, `.dd-workspace` |
| Party workspace | `.dd-workspace--party` (content max `--dd-party-content-max`: 80rem) |
| Party chrome | `directory/shared/_party_chrome`, `_party_subnav` |
| Display rows | `_contact_row`, `_relationship_row`, `_note_row`, `_identifier_row`, `_role_summary`, `_inline_empty` |
| Icons | `icon_tag` → `app/views/shared/icons/` |
| Empty states | `empty_state_classes(family:)` → `.dd-empty-state--*` |
| Selected row action | `selected_action?(action, id:, param:)` |
| Development specimen | `GET /dev/ui` when `Rails.env.development?` |

## Display / edit chooser

| Situation | Pattern |
| --- | --- |
| Browse a party-local collection | Display rows and text links. No editable field until one composer or one row editor is open. |
| Substantial create or edit | Focused GET page (`new` / `edit`) with Cancel back to the browse tab. |
| Single immediate action (pin note, set primary, category assign) | Row-scoped button or Turbo Frame. Server-rendered result; no client-calculated status. |
| Consequential destruction | Focused confirmation page (party deactivate) or a selected composer with a required reason. Destructive controls never share the ordinary edit footer. |
| Secondary long text on a focused edit page | Native `details`/`summary`. Open automatically on validation error or a direct `?open=` / fragment target. Required fields never live in a closed disclosure. |
| Empty region | Empty-state family: `actionable`, `positive`, `filtered`, `inline`, `permission`, `error`. |

## Application frame

```
dd-app-shell
  dd-topbar          52px navy, viewport-wide
  dd-sidebar         208px navy, below the topbar
  dd-main
    dd-workspace
```

* Brand, compact office link (`edit_current_office_path`), user initials plus name, and Sign out live in the topbar. There is no global search, notification bell, or invented office dropdown.
* Sidebar groups: **Workspace** (Dashboard, Directory, Clients, Suppliers, disabled Departures / Travelers / Accounting) and **System** (Administration). Do not add an empty Money group.
* Active nav uses a 2px teal left edge and restrained fill, with `aria-current="page"`. Party-local pages keep Directory current.
* Below 768px the sidebar is the existing Stimulus drawer (`navigation_drawer_controller.js`): focus trap, Escape, inert backdrop, close on Turbo navigation. Nav DOM is not duplicated.
* Workspace padding is 18–24px. Party pages cap readable width at ~76–82rem.

## Typography and density

* Self-hosted IBM Plex Sans (400/500/600/700, italic 400) and IBM Plex Mono (400/500/600) as `woff2` under `/fonts/`. SIL OFL. Auth pages inherit Plex; do not recompose the auth shell.
* Body 13px. Table and list rows 12px. Labels 10–11px. Detail titles ~19px (`.dd-page-title`).
* `.dd-type-mono` is for currency, codes, counts, and confirmation values only.
* Desktop fields ~34–36px, buttons ~32–34px; mobile controls may be taller. Short values use `.dd-field--narrow` or `.dd-field--code`, never a full-width field.
* Cards use `radius-md` and a border, with little or no shadow. Keyboard focus: teal field border plus amber outer ring (`--dd-focus`).
* Warning token: `--dd-warning: #b87800`. Keep `#8a5a00` as `--dd-amber-icon` only.

## Party profile

* Identity header: initials tile, display name (`h1.dd-page-title`), kind chip, real Client/Supplier chips, deactivated treatment when applicable.
* Header metadata is identity disambiguation that already exists. Omit the line when empty; never print placeholders. Do not promote postal locality, organization type, or household locality.
  * Person: preferred name only when it differs from display name.
  * Organization: legal name only when display is the trading name. Website belongs in overview.
  * Household: correspondence name only when it differs from household name.
* Edit is the only prominent header action. More is native `details`/`summary` with links to Roles and Record only.
* Subnav labels: Overview, Contact, Relationships, Roles, Notes, Identifiers, Record. One compact non-wrapping row; horizontal scroll at narrow widths; current item stays visible. Accessible name remains on the `nav`.
* Desktop overview: main plus aside, 20–24px gap. Aside max `--dd-party-aside-max` (~21–22.5rem). Below the design-system breakpoint the aside stacks. Do not use a stretching 2:1.
* Do not manufacture Party metrics or restore `.dd-summary-strip`. Notes counts use `PartyNote.visible_to` before render.

## Data entry

* Required fields: asterisk plus the legend “Required fields are marked with an asterisk.”
* Error summary at the top of a failed form, plus per-field `aria-invalid` / `aria-describedby` where model errors exist.
* Long focused forms may use `.dd-form-actions--sticky`.
* **Edit supplier details** is the reference form: Responsibility and Commercial defaults (including portal URL) stay visible. Disclosures hold booking / payment / policy notes only. Service categories are a separate dashed panel and Turbo Frame; copy states that category changes save immediately. The main Save button does not commit categories.
* Party deactivate is a full page that names what changes and what does not, requires a reason, and works without JavaScript.

## Icons

Curated Phosphor Regular SVGs via `icon_tag`. MIT attribution: `docs/licenses/phosphor-icons.md`. Sizes: `.dd-icon--sm` 16px, `--md` 20px, `--lg` 24px, `--xl` 32–40px. Unknown names raise.

Row actions are text links (`.dd-row-action`), not three-dot menus, unless a row has more than three actions. Do not add ARIA menus without full keyboard behavior.

## Status badges

Badges pair a title-case label with a color modifier. Stored enums stay lowercase.

| Helper | Notes |
| --- | --- |
| `party_kind_badge` | `.dd-badge--kind` |
| Client / Supplier chips | `.dd-badge--role` when active, `--neutral` when inactive |
| `role_profile_status_badge` | Active / Inactive / Not assigned |
| `contact_point_status_badge` | Active, Do not use, Deactivated |

Never communicate status by color alone.

## Turbo

* Progress bar is teal (`.turbo-progress-bar`).
* Frame pending: `.dd-skeleton` / `.dd-frame-skeleton`. Frame failure: `.dd-frame-error`.
* “Saving…” uses native submit `data-disable-with`. Never a client-calculated status.

## Administration and dashboard

Shell geometry wraps these pages. Inner composition (agency profile, offices, team, invitations, dashboard metrics) is **deferred** and may still use older panel/filter/table anatomy until a later program. Administration keeps `nav[aria-label=Administration]`.

## Deferred families

Do not treat these as adopted in this program:

* Directory index and search restyle beyond global CSS
* Administration and dashboard composition
* Operational records (departures, client trips, money)
* Print
* Multi-currency domain UI
* True inline cell editors
* Global search and notifications

## Responsive checkpoints

| Width | Intent |
| --- | --- |
| 375px | Drawer; topbar account name may hide; subnav scrolls; party aside stacks |
| 768px | Sidebar in the grid; two-column form grids may collapse |
| Reference desktop / 1280px | Party main + capped aside; 52px / 208px shell |

Keep the skip link and amber focus ring. Keyboard focus must reach primary fields and party subnav.

## Intentional mockup deltas

* Real nav versus mockup Parties / Client trips / Receipts
* No search, notifications, client-trip actions, or party numbers ([ADR 0004](../adr/0004-human-readable-references.md))
* Party subnav retained
* Stat strip absent on Party
* Office control is a link to the existing office page
* Header omits location/type the domain does not store
* Aside width is capped rather than a stretching 2:1
