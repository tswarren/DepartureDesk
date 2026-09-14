# DepartureDesk Design System

**A reference for the visual language, components, and interaction rules used across DepartureDesk.**

This document consolidates the design decisions made while mocking up DepartureDesk's core screens. It exists so that any new screen, by any designer or engineer, reads as part of the same product — and so the domain rules from the requirements and terminology docs stay visible in the UI, not just in the data model.

Every principle here traces back to one of three source documents: the brand palette, the requirements draft, or the terminology standard. Where a UI decision encodes a specific domain rule, that rule is quoted or paraphrased so the reasoning survives even if the screen gets redesigned later.

**Target stack: Rails + Turbo (Hotwire), Stimulus for local interactivity.** Several sections below (component states, loading, §5) are written specifically for that stack rather than for a client-rendered SPA framework.

---

## 1. Foundations

### 1.1 Design tokens

```css
:root {
  /* Brand */
  --dd-navy: #002340;
  --dd-teal: #007080;
  --dd-teal-action: #006270;
  --dd-amber: #f49a00;

  /* Surfaces */
  --dd-background: #f6f7f5;
  --dd-surface: #ffffff;
  --dd-surface-subtle: #eef2f1;
  --dd-surface-emphasis: #e2ebea;

  /* Text */
  --dd-text: #17212b;
  --dd-text-muted: #52616d;
  --dd-text-faint: #71808a;
  --dd-text-on-dark: #ffffff;

  /* Structure */
  --dd-border: #d4dedf;
  --dd-border-strong: #aababd;

  /* Interaction */
  --dd-action: #006270;
  --dd-action-hover: #004f5b;
  --dd-action-active: #003f49;
  --dd-focus: #f49a00;
  --dd-selection: #d7eff0;
  --dd-selection-text: #003c45;

  /* Semantic */
  --dd-success: #2f6b4f;       --dd-success-surface: #e6f3eb;  --dd-success-text: #24523d;
  --dd-warning: #b87800;       --dd-warning-surface: #fff2d6;  --dd-warning-text: #694400;
  --dd-danger:  #b5473d;       --dd-danger-surface:  #fbe9e7;  --dd-danger-text:  #84332d;
  --dd-info:    #326a8a;       --dd-info-surface:    #e7f1f7;  --dd-info-text:    #264f67;
  --dd-neutral-surface: #edf0f2; --dd-neutral-text: #46525a;

  /* Amber callout variant */
  --dd-amber-surface: #fff2d6;
  --dd-amber-border:  #e6a52e;
  --dd-amber-text:    #694400;
  --dd-amber-icon:    #8a5a00;

  /* Geometry */
  --dd-radius-sm: 4px;
  --dd-radius-md: 7px;
  --dd-radius-lg: 10px;
}
```

**Color meaning is fixed and does not vary by screen:**

| Color | Owns | Never used for |
|---|---|---|
| Navy | Structure, authority, app chrome, headings | Interactive/active states |
| Teal | Interaction, active state, links, primary buttons | Decoration, status meaning |
| Amber | Waypoints — deadlines, guarantees, milestones, focus rings | Navigation state, destructive actions |
| Semantic (green/red/blue/gray) | Operational status (confirmed, overdue, informational, inactive) | Brand identity |

Amber and status-red are easy to confuse in a dense UI. The rule that keeps them apart: **amber marks something that needs attention on schedule; red marks something that has already gone wrong** (missed a deadline, overdue balance, cancellation). See §3.8.

### 1.2 Typography

- **UI text:** IBM Plex Sans (400/500/600/700)
- **Numeric and identifier text:** IBM Plex Mono — every dollar amount, count, confirmation number, and code uses mono, right-aligned in tables. This is deliberate: dense financial tables need numbers to align vertically and read as a distinct visual category from labels.
- Body text: 12.5–13px. Table rows: 12–12.5px. Labels/eyebrows: 10–11px, not necessarily all-caps (used sparingly for column headers only).

### 1.3 Spacing scale

The mockups were built with ad-hoc pixel values (6, 7, 8, 9, 10, 12, 14, 16, 18...). That's fine for exploration; it's not fine as a system. Formalize on a 4px base scale, with a **compact** variant for table/list density, since this product is explicitly a dense power-tool:

```css
:root {
  /* Base scale — cards, forms, page layout */
  --dd-space-1: 4px;
  --dd-space-2: 8px;
  --dd-space-3: 12px;
  --dd-space-4: 16px;
  --dd-space-5: 20px;
  --dd-space-6: 24px;
  --dd-space-7: 32px;
  --dd-space-8: 40px;

  /* Compact scale — table cells, list rows, stat strips */
  --dd-space-compact-1: 4px;
  --dd-space-compact-2: 6px;
  --dd-space-compact-3: 9px;
}
```

| Token | Typical use |
|---|---|
| `--dd-space-1` (4px) | Icon-to-label gaps, tight inline spacing |
| `--dd-space-2` (8px) | Default gap between related inline elements |
| `--dd-space-3` (12px) | Card internal padding (compact cards), form field gaps |
| `--dd-space-4` (16px) | Standard card padding, section internal padding |
| `--dd-space-5` (20px) | Gaps between cards in a grid |
| `--dd-space-6` (24px) | Page-level padding, gaps between major sections |
| `--dd-space-7`/`8` | Rare — large empty-state padding, hero spacing |
| `--dd-space-compact-2/3` (6/9px) | Table cell vertical padding — this is what keeps rosters and ledgers dense without feeling cramped |

Rule of thumb: **if it's inside a table or a stat strip, use the compact scale; everything else uses the base scale.** Don't mix a compact value into a card's outer padding or a base value into a table cell — that's how density becomes inconsistent screen to screen.

### 1.4 Icon system

The mockups used emoji as placeholders (🔍 ✉ 📅 🏠 ⛴ ⚠ ✓ 🔒). These are not implementation-ready — inconsistent stroke weight, inconsistent optical size, and they render differently per OS/browser, which is disqualifying for a financial product.

**Recommendation: Phosphor Icons, Regular weight, as SVG.** This isn't arbitrary — it's the icon set already selected and cataloged in the icon reference sheet built earlier in this project (`icon-reference.html`), and its rounded, uniform-stroke geometry matches the palette's own guidance to use "line icons with rounded geometry similar to the logo paths." Reuse that reference sheet as the source of truth for which icon maps to which concept; don't let a second icon vocabulary grow independently.

Technical conventions:
- Inline SVG, not an icon font — `fill="none" stroke="currentColor"`, so every icon inherits text color automatically. No separate icon-color token is needed except for deliberate semantic tinting (e.g. a danger-colored warning icon).
- Sizing scale: **16px** inline with body text, **20px** default UI icon (buttons, table row actions), **24px** card headers and nav items, **32–40px** empty-state and illustration-scale icons. Don't introduce sizes outside this set.
- Stroke width fixed at 16 units on Phosphor's 256×256 viewBox (the weight already used throughout the reference sheet) — mixing stroke weights within one screen is one of the fastest ways to make a UI look assembled rather than designed.

Placeholder → Phosphor mapping used across the mockups so far:

| Placeholder | Phosphor icon | Used on |
|---|---|---|
| 🔍 | `magnifying-glass` | Global search, filters |
| ✉ | `envelope` | Email contact rows |
| ☎ | `phone` | Phone contact rows |
| 📍 | `map-pin` | Postal address rows |
| 🏠 | `house` | Household relationships |
| 📅 | `calendar-check` | Date inputs |
| 👥 | `users-two` | Roster / travelers |
| 📄 | `file-text` | Supplier arrangements, documents |
| 📦 | `package` | Packages |
| 🔔 | `bell` | Notifications |
| ⚠ | `warning-circle` | Attention/exposure callouts |
| ✓ | `check-circle` | Confirmed / positive empty states |
| 🔒 | `lock-simple` | Derived/read-only status |
| ✕ | `x` | Remove/dismiss |
| ▾ | `caret-down` | Dropdown triggers |

A few concepts used in mockups (⛴ ship, ◆ system-avatar marker) weren't in the original reference sheet and need sourcing or a deliberate custom mark before implementation — flagged here rather than silently resolved.

### 1.5 Layout chrome

Standard screen shell:
- **Navy top bar** (52px): brand mark, office switcher, global search, notifications, avatar.
- **Navy left nav** (208px): section-grouped links (Workspace / Money / System), teal left-edge indicator on the active item, white text.
- **Cloud-colored workspace** (`--dd-background`) behind white content surfaces, per the palette's "navy frame around a warm-cloud workspace" direction.
- **Breadcrumb** above every detail screen's header, always showing the real containment path (e.g. Departures / [departure] / [client trip]).
- **Stat strip**: a bordered white row of 5–6 compact metrics directly under the page header, dividers between cells, mono numeric values, muted sub-labels. Used on every "detail" screen as the at-a-glance summary.
- **Tabs**: underline style, teal 2px indicator on active tab, count badges in mono.

Density target throughout: 12.5–13px body copy, spacing per §1.3 — built for someone who lives on this screen all day, not a marketing dashboard.

---

## 2. Components

### 2.1 Buttons
- **Primary** (`--dd-action` fill, white text): one per view, the single recommended next action.
- **Secondary** (white, border-strong): everything else.
- **Destructive** (`--dd-danger` fill): reserved for actions with real consequences (cancel, void). Never amber.
- **Ghost/link**: `--dd-action` colored text, no border, for tertiary actions.

### 2.2 Status pills — editable vs. derived
Two visually distinct patterns, because not every status is user-settable:

- **Editable status** (e.g. departure status, client-trip status): a pill with a caret, opening a menu that lists *only the valid next states* from the current one — not the full lifecycle. A destructive option (e.g. Cancel) is separated at the bottom of the menu with a warning dot.
- **Derived status** (e.g. payment status): a plain pill with a small lock icon and a caption ("Calculated from receipts"). No dropdown. This directly reflects the terminology doc's instruction that statuses "should be derived from financial facts where possible rather than manually selected." See §5.3 for how this must be enforced server-side, not just visually.

### 2.3 Consequential-action confirmation
Used for any status change or action with side effects the person might not expect (e.g. cancelling a departure). The modal:
1. Names exactly what *will* change.
2. Explicitly lists what will **not** automatically happen (e.g. "This does not cancel client trips or release supplier arrangements").
3. For the most consequential actions, requires an acknowledgment checkbox before the (red) confirm button is enabled.

This pattern exists because of a specific, repeated rule in the requirements doc: status changes on one record must never silently cascade into another record's status (a departure cancellation doesn't cancel client trips; a client cancellation doesn't eliminate a supplier obligation).

### 2.4 Audit trail
A reverse-chronological list where every entry states, in plain past tense, what changed and who changed it:
- **User entries** get a person avatar and name.
- **System entries** (e.g. an automatic status recalculation) get a distinct neutral "System" avatar — never presented as if a person did it.
- **Correction entries** get a distinct tag and always carry a stated reason. A correction is reserved for changing a fact that was already confirmed (e.g. a contracted supplier cost after a revised invoice) — this is categorically different from a routine edit, and the audit trail must never silently overwrite the prior value.
- Financially significant entries carry a "Financial" tag so they can be filtered independently of status/assignment changes.

### 2.5 Projected vs. confirmed vs. actual
Any figure that exists in more than one state of certainty (revenue, cost, margin) uses a fixed visual treatment, per the palette's explicit instruction not to rely on hue alone:

| State | Treatment |
|---|---|
| Projected | Muted text, dashed underline / dashed-hatched fill in charts |
| Confirmed | Solid teal |
| Actual | Solid navy, bold |

This survives grayscale and colorblindness because the distinction is carried by weight and fill pattern, not color alone. Applied identically whether the number appears in a table, a stat card, or a bar chart.

### 2.6 Tables
- White background, `--dd-surface-subtle` (`#EEF2F1`) header fill, `--dd-border` horizontal rules, minimal vertical rules.
- Row states: default (white) → hover (`#F1F7F6`) → selected (`#D7EFF0`) → attention (`#FFF7E7`) → error (`#FDF0EE`) → inactive (`#F3F4F4`).
- A **narrow left-edge indicator bar** (amber or red, 3px) flags a row needing attention — used instead of a whole-row color flood so the semantic color stays legible against real data.
- Row actions are inline text links (`--dd-action` color), not icon buttons, to stay legible at table density.
- Cell padding uses the compact spacing scale (§1.3), never the base scale.

### 2.7 Forms and data entry
Covered in detail in `data-entry-patterns.html`. Key rules:
- **Currency**: `$`-or-code prefix (see §4), mono font, right-aligned.
- **Required fields**: a conventional asterisk plus label text — never amber color alone, per the palette's explicit instruction that required fields must be identified textually or with a conventional marker.
- **Focus**: teal border by default; an additional amber outer ring appears specifically for keyboard focus.
- **Party picker**: a searchable combobox showing role tags per result, with an inline "create new person" option, since party identity is reusable across the system.
- **Responsibility allocation**: always shown as a running balance against the charge total (green when it sums correctly, red when it doesn't) — this directly encodes the requirement that "the sum of responsibility allocations must equal the charge amount before the charge is finalized."
- **Inline table editing**: single-field edits (a date, an amount) happen in place with a teal-ringed input and inline confirm/cancel — not a full panel reopen. In Rails/Turbo, this is a Turbo Frame scoped to the single cell/row; see §5.2.

### 2.8 Contact information (party profile)
- **"Primary" is assigned per purpose** (General / Correspondence / Billing), never as a single boolean — a party can have three different primary contacts for three different purposes simultaneously.
- **Suppressed** ("do not use") and **deactivated** ("no longer a contact") are visually and functionally distinct: suppressed keeps the value visible (strikethrough, red-surface badge, a "Restore" action); deactivated fades the value out with a neutral badge and no restore path, since it's a different lifecycle event, not a mistake.

### 2.9 Notes and permission-safe empty states
- **Standard notes** are visible to all staff; **administrator-only notes** are visually tagged and gated behind a view toggle.
- Critically: when an admin-only note is the *only* note on a party, a staff-level view must show the exact same "No notes yet" empty state — same copy, same count badge (0) — as a party with genuinely zero notes. The count itself must not leak the existence of hidden content. In Rails terms: this must be enforced by scoping the notes query and its `.count` to the current user's visible scope *before* rendering, never by rendering all notes and hiding admin ones with CSS — a hidden DOM node is still a leak (view-source, accessibility tree, Turbo Stream diffs).
- **Corrections and removals preserve the original body** for audit purposes — a removed note shows as "Removed by [x] on [date]," with the original retained, not deleted.

### 2.10 Empty states
Six distinct treatments, not one generic pattern:

| Type | Visual | When |
|---|---|---|
| No data yet (actionable) | Dashed border, neutral icon, one primary action | Nothing created here yet |
| Nothing outstanding (positive) | No dashed border, success-surface icon, usually no button | Zero is a good outcome (no balances due, no overdue tasks) |
| No results (filtered) | Neutral icon, secondary "Clear filters" action | Data exists, current view doesn't match it |
| Inline/compact | Left-aligned, smaller icon, lives inside an existing card | Empty section within an otherwise-populated screen |
| Permission-safe | Identical to "no data yet" regardless of what's hidden | Content exists but is restricted from this viewer |
| Error | Danger-surface icon, solid border, "Retry" action, explicit reassurance nothing was lost | The request failed — never dressed up as empty |

### 2.11 Component states matrix

Every interactive component needs all of these defined; up to now they were specified ad hoc per screen. This is the consolidated reference.

| Component | Default | Hover | Focus | Active/Pressed | Disabled | Loading |
|---|---|---|---|---|---|---|
| Primary button | `--dd-action` fill | `--dd-action-hover` fill | + amber outer ring (keyboard only) | `--dd-action-active` fill | 50% opacity, `not-allowed` cursor, no hover change | Label replaced with spinner + "Saving…", button disabled |
| Secondary button | White, border-strong | `--dd-surface-subtle` fill | + amber outer ring | Slightly darker border | 50% opacity | Same pattern as primary |
| Text input | Border-strong | — | Teal border (+amber ring if keyboard) | — | `--dd-neutral-surface` fill, faint text, `not-allowed` | Not applicable (see §5.2 for frame-level loading) |
| Table row | White | `--dd-row-hover` (#F1F7F6) | Focus ring on interactive cell only, not whole row | `--dd-selection` bg while a row action's frame is loading | Faint text (`inactive` row state, §2.6) | Skeleton row (§5.1) if row is server-rendering |
| Nav item | Muted white text | Subtle white-alpha fill | Amber ring (keyboard) | Teal left-edge + white text (this *is* the active state) | N/A | N/A |
| Tab | Muted text, no underline | Text darkens | Amber ring (keyboard) | Teal underline (this *is* the active state) | N/A | Content area shows frame skeleton while tab loads (§5.1) |
| Toggle | Border-strong track | Slightly darker track | Amber ring | Teal track once on | 50% opacity | Track shows a brief pulse, then settles — never left in an ambiguous mid-state |
| Status pill (editable) | Semantic fill + caret | Caret darkens | Amber ring on trigger | Menu open | N/A (derived pills have no interactive state) | Pill shows previous state until the frame confirms the new one — no optimistic flip, see §5.3 |

---

## 3. Domain rules encoded in the UI

This is the list worth re-checking against any new screen. Each rule below came from the requirements or terminology docs and was deliberately made *visible* in the interface, not just enforced in validation logic.

1. **A traveler does not become financially responsible merely by receiving a service.** Parties, responsible clients, and travelers are always three separate lists, never one "members" list.
2. **Client price and supplier cost never share a field.** They appear in different columns, different cards, sometimes different tabs entirely.
3. **Responsibility allocations must sum to the charge total before it's finalized** — shown as a live, colored balance check, not a silent validation rule.
4. **A confirmation number is always labeled by what it identifies** (cabin confirmation, PNR, policy number, contract number) — never a generic unlabeled "confirmation #" when more than one supplier record could exist.
5. **Traveling parties link without merging.** A shared cabin/room is shown as a cross-reference tag between client trips, never as a combined balance or shared account.
6. **A household relationship is effective-dated**, and changing it later must not silently rewrite the eligibility basis of an already-confirmed booking — surfaced as an explicit info callout on the party profile.
7. **Capacity, guarantee, and sold are three different numbers.** Blocked capacity ≠ guaranteed commitment ≠ actual sales. The capacity bar on the supplier arrangement screen renders all three, plus the guarantee threshold line.
8. **Guarantee exposure is amber; an overdue obligation is red.** These are different situations (a scheduled risk vs. an actual missed deadline) and must not share a color.
9. **Cash position is not profit.** Always shown with its own formula (receipts − client refunds − supplier payments + supplier refunds) and a caption stating what it isn't.
10. **Projected margin is never presented as earned income** — a caption states this explicitly next to every margin figure.
11. **Confirmed supplier facts are corrected, not overwritten.** A correction is a distinct, reason-carrying, audited action — never a quiet edit.
12. **Unavailable data and a genuine zero are rendered differently.** "$0.00" means a confirmed zero; "Not tracked" / "Not applicable" means the data doesn't exist. Conflating them (defaulting missing fields to $0.00) is a real risk in a financial system and was treated as a first-class rendering rule, most visibly on the air ticket detail screen.
13. **Agency-collected and supplier-collected money are never merged.** A "Collected by" tag is shown independently of ticket/charge status, since this affects whether funds are agency-controlled cash at all.
14. **A settlement's calculated and reported values are both shown, with the variance flagged** — the reported figure becomes authoritative for group financials, but the discrepancy stays visible rather than being silently resolved.
15. **Print documents never carry internal identifiers or staff-only figures.** Client-facing PDFs/print views show cabin confirmations and balances, never internal codes like "CT-10422" or supplier cost.

---

## 4. Multi-currency & localization

Not addressed in any mockup so far — every screen hardcoded `$`. The requirements specify a **default currency per departure**, and the air-travel spec explicitly requires per-ticket currency, so this needs real rules before implementation, not just a follow-up pass.

**Storage and calculation**
- Store every amount as an **integer minor-unit value plus an ISO 4217 currency code** (e.g. `{ amount_cents: 758000, currency: "USD" }`), never a float. This is standard financial-software practice and matters more here than usual, since responsibility allocations must sum *exactly* to a charge total (§3.3) — floating-point drift would silently break that invariant.
- Never perform arithmetic across two records with different currency codes without an explicit, logged conversion step. A departure's projected margin, cost, and revenue must all resolve to one currency before they're combined into the stat strip or reconciliation view.

**Display**
- **Always disambiguate the symbol.** `$` alone is ambiguous across USD/CAD/AUD/NZD, all of which this agency could plausibly transact in. Default display is symbol + code when any non-USD currency is in play on that screen (`$1,240.00 USD`); symbol-only is acceptable only in a screen scoped entirely to one known currency (e.g. a single-currency departure's roster).
- Negative amounts keep the parenthetical convention already established `($310.00)`, unchanged across currencies.
- Thousands/decimal separators follow the currency's locale convention, not the viewer's browser locale — a USD amount shown to a staff member in Germany should still read `$1,240.00`, not `$1.240,00`, since it's the transaction's currency convention that matters, not the viewer's.

**Dates and times**
- Every date shown anywhere in the product uses an **abbreviated month name** format (`Jul 12, 2027`), never numeric-only (`7/12/27` or `12/07/27`). This was already the convention used throughout the mockups; make it a hard rule, since MM/DD vs. DD/MM ambiguity in an international travel product is a real, recurring source of costly mistakes (wrong deposit deadline, wrong flight date).
- **Service times (flight departures, cruise embarkation, hotel check-in) always display in local time at the service location, labeled explicitly** (e.g. "8:05 AM PT" or "8:05 AM · Seattle"), never silently converted to the viewer's browser timezone. A staff member in a different office reading a traveler's flight time in their own timezone by mistake is the kind of error this product exists to prevent.

---

## 5. Implementation notes: Rails + Turbo

The component and state definitions above assume a specific architectural discipline that's worth stating explicitly, since Hotwire's server-authoritative model changes how a few patterns above actually get built — differently than they would in a client-rendered SPA.

### 5.1 Loading states
- **Turbo Frame lazy loads** (a tab's content, a modal opened via a frame, an expandable ticket detail panel) show a **skeleton**, not a spinner: gray blocks (`--dd-surface-subtle`) shaped roughly like the incoming content, with a slow opacity pulse. This preserves layout stability — a spinner-then-pop-in causes the page to jump; a correctly-sized skeleton doesn't.
- **Full-page Turbo navigation** uses Turbo's built-in top progress bar — restyle its color to `--dd-action` (teal) rather than leaving the browser/Turbo default, so navigation feels native to the brand rather than generic.
- **A frame that fails to load** shows the error empty-state pattern from §2.10 scoped to that frame's boundary — never a broken/blank frame with no explanation.

### 5.2 Inline editing and forms
- Inline table-cell editing (§2.7) is a **Turbo Frame scoped to the single row or cell**. Submitting the inline form replaces the frame with the server-rendered result — the confirm/cancel icons shown in the mockup are the frame's two possible outcomes, not client-side-only state.
- Larger forms (New Client Trip, Record Receipt) are standard Turbo-powered forms; validation errors re-render the form partial with the `.has-error` treatment from the field kit rather than a client-side-only validation layer. Server-side validation is authoritative — client-side checks (e.g. the live responsibility-allocation balance check) are a convenience preview, not the source of truth, and must be re-verified server-side before the charge is finalized.

### 5.3 The optimistic-UI rule
**Never optimistically render a derived or calculated value.** Payment status, client balance, projected/confirmed/actual margin, and cash position are all values the server computes from underlying facts (§2.2, §2.5). When an action might change one of these (recording a receipt, changing a responsibility allocation), the UI shows a **pending state** — a disabled control, a "Saving…" label (§2.11) — and waits for the Turbo Stream response to render the authoritative recalculated value.

This isn't just a Rails convention, it's a direct extension of a domain rule already in this document: a status "should be derived from financial facts... not set manually" (§2.2) means the UI can't guess what that derived value will become — it has to ask the server and wait. Optimistically flipping a balance or status client-side, even briefly, risks showing a number that turns out to be wrong the moment the real calculation runs — unacceptable in a financial ledger.

### 5.4 Stimulus scope
Client-side-only interactivity (dropdown open/close, tab switching between already-loaded content, the notes staff/admin view toggle, combobox filtering of an already-loaded list) is implemented as small, single-purpose Stimulus controllers. Anything that changes persisted state (a status transition, a receipt application, an allocation edit) goes through a real form submission and Turbo Stream/Frame response — Stimulus is for interaction, not for business logic or state that needs to survive a page refresh.

---

## 6. Print documents

Print uses the same token system with different application rules, since paper is not a screen:

- **Navy becomes an accent, not a chrome color** — a letterhead rule and headings, on a white page. A full navy background page reads as "printout of a website," not a letterhead.
- **Amber is spent once** — typically the balance-due box — so it still reads as a waypoint marker rather than becoming wallpaper.
- **No interactive affordances**: no dropdown carets, no hover-only actions, no status pills implying they're clickable.
- **Running footer** on every page: agency name, seller-of-travel registration number where applicable, page X of Y.
- **Client-facing language and figures only** — the numbers shown must match what the client would see in their portal/statement exactly; internal fields never appear.
- **Currency and dates follow §4** — a print document is exactly the artifact most likely to leave the country with a client, so ambiguous dates/currency symbols are especially costly here.
- Page setup: `@page { size: letter; margin: 0.6in; }`, content built as a fixed 8.5in-wide `.page` container for on-screen preview, with print media query removing the screen-preview shadow/margin.

---

## 7. Screen inventory

| Screen / pattern | File | Status |
|---|---|---|
| Departure detail (roster) | `departure-detail.html` | Built |
| Data entry patterns (field kit, new client trip form, record receipt modal, inline edit) | `data-entry-patterns.html` | Built |
| Party profile (contact info, household, notes) | `party-profile.html` | Built |
| Empty states (all 6 categories) | `empty-states.html` | Built |
| Client trip detail | `client-trip-detail.html` | Built |
| Cross-cutting patterns (status transitions, audit trail, projected/actual) | `cross-cutting-patterns.html` | Built |
| Supplier arrangement detail | `supplier-arrangement-detail.html` | Built |
| Financial reconciliation (departure financials tab) | `financial-reconciliation.html` | Built |
| Air reservation / ticket detail | `air-ticket-detail.html` | Built |
| Client itinerary (print) | `client-itinerary.html` | Built |
| Icon reference | `icon-reference.html` | Built (earlier in project) |
| Invoice (print) | — | Not yet built |
| Manifest / rooming list | — | Not yet built |
| Package builder | — | Not yet built |
| Deadlines & tasks view | — | Not yet built |
| Supplier resource / nightly inventory grid | — | Not yet built |

---

## 8. Continuity dataset

Several mockups intentionally share the same underlying scenario so the system reads as one coherent product rather than disconnected screens. For future work, keep reusing or deliberately extending this dataset rather than inventing a fresh one per screen:

- **Departure:** Smith Family Reunion Cruise, SFR-2027-CRZ, July 12–19, 2027, aboard MV Horizon Star (Oceanic Cruise Line), status "In operation."
- **Client trip:** Whitfield family, CT-10422 — Margaret Whitfield (primary/responsible client), Daniel, Ella (11), Thomas (8); Ocean View – Deluxe package, $7,580 total, $1,500 deposit paid, $6,080 final due Aug 1, 2027; Cabin 8142, confirmation RC-8142-W.
- **Supplier arrangement:** Cruise Group Agreement, contract OCL-GRP-88410 — 30 cabins blocked, 25 guaranteed, 24 sold, 1 unsold guaranteed cabin ($1,700 exposure), $12,750 overdue final payment.
- **Other client trips on the same departure:** Nakamura + Ortiz (shared Cabin 8140, traveling party), Reyes trip (optioned, sponsored by a church group), Park family (quoted), Callahan trip (partially cancelled, $310 refunded), Bianchi trip (closed).
- **Party:** Aiko Nakamura (P-88213) — client and payer, also has a separate client trip on the Napa Wine Country Tour departure with her son Kenji, used for the air reservation example (PNR 4Q7RTL, Delta Air Lines).

All currency in the continuity dataset is USD — if a supplier arrangement in a different currency is added later (per §4), it should be a deliberate, labeled addition to this dataset, not an unstated assumption.

---

*This document should be updated as new screens are built or existing rules are revised — treat §3 (domain rules) and §5 (Rails/Turbo implementation notes) as the sections most worth keeping current, since they're the parts most likely to be silently violated by a well-intentioned but unaware future change.*
