# Slice 1 UX consolidation: audit

**Status:** Decisions settled 2026-11-09; decisions 7 and 8 added the same day. It proposes **D-98**, below. Until D-98 is logged, it authorizes nothing.

Slice 1 has built steps 1 to 8. Each step added screens, and two walkthroughs fixed the worst friction one screen at a time. Before the reseller path (build step 9) reuses the booking screens, this pass makes the staff app consistent as a whole. It changes how screens are arranged and behave, never what the rules allow.

This audit covers every staff screen in the [screen inventory](slice-1-screens.md) that exists today: S-01 to S-03, S-06 to S-09, S-11 to S-34, the administration pages and the directories.

Four sources fed it:
- the code, read screen by screen;
- the two [staff walkthrough](slice-1-step-6-staff-walkthrough.md) runs;
- the [UI acceptance](first-slice-charter.md#ui-acceptance) standards;
- the [interface contract](../../ui/interface-contract.md).

## D-98 as proposed

> Amend the first-slice charter: between build steps 8 and 9, a UX consolidation pass revises the existing staff screens for consistency and ease of use, following the UX consolidation audit. It changes no rule, record, permission or case: each screen keeps the rules it cites, every demonstration case keeps passing, and the screen inventory is updated to match. Delivered as several pull requests, an exception to the one-per-step-or-case working rule; each passes the UI acceptance standards at desktop width and 375px. The reseller path (build step 9) starts when the last merges.

## How it was done

| Measure | Today |
| --- | --- |
| Staff page templates | 270 view files across 75 view folders |
| Stylesheet | 3,085 lines and 445 component rules |
| Form error handling | 19 controllers show errors on fields; 8 show one banner at the top; 39 actions redirect with a flash message |
| The longest page | The arrangement page stacks 9 panels |
| Inline styles | 1, in the design-system preview only |

## Cross-cutting findings

Each finding has an ID, cited in the screen findings below and in the batches.

### A. Information architecture and navigation

- **A1. The Departure's tabs don't follow the work.**
  - Today they run Overview, Bookings, Package, Client terms, Inventory, Suppliers, Supplier money, Tasks.
  - Setting up runs the other way: suppliers, then inventory, then the package and its terms, then bookings, then money.
  - Client money has no Departure tab. It sits under Bookings.
- **A2. The Dashboard is empty.** It shows the current office and nothing else. Staff land on My tasks, so the Dashboard is a dead end in the main navigation.
- **A3. The Departure overview doesn't summarize the Departure.** It shows statuses, details, decisions and the team. It doesn't say how many bookings, cabins left, money still due or tasks overdue.
- **A4. Two ways in, unequally signposted.**
  - A booking can start from the trip or from the Bookings tab.
  - Prices can be set on the option page or in the grid.
  - Client money appears on the trip and on the booking.

  Each pair needs one primary path, with the other clearly secondary.
- **A5. Breadcrumbs mix two hierarchies.** The trip page's trail starts at Clients; its booking's starts at Departures. The same trip is reached by two trails.
- **A6. Neither a booking nor a trip can be seen whole.** The booking's steps each show one part of it, so checking a confirmed booking means opening five steps. The trip page lists its bookings and money, but not what each booking holds, who is traveling, or what is still awaited.

### B. Page anatomy

- **B1. The arrangement page is too long.** On one page it stacks the checklist, details, inventory, deadlines, supplier reservations, rates, cost, payments and documents.
- **B2. The booking's Price and hold step carries three jobs:** the price summary, the installments and money, and the hold. The step stepper suggests one job per step.
- **B3. Panels have no common header.** Some panels put the title and action in the header, some put the action in the body, and some have no title.
- **B4. Every disclosure looks different.** "Add one option instead", "Advanced", "Details", "Only for one inventory group" and "The supplier's time zone" each use their own wording and placement.

### C. Forms

- **C1. Three ways to report a refusal.** Field errors, a single banner, and a redirect with a flash message. A form the user typed into should keep what they typed and show the error on its field, every time.
- **C2. Sentence summaries in some forms, not others.** Supplier payments and deadlines sum themselves up in a sentence as they're filled in. Schedule lines on client terms, cancellation tiers, capacity changes and the booking's installments don't.
- **C3. Conditional fields are inconsistent.** The newer forms show only the fields a choice needs. The arrangement form, the cost line form and the trigger event form show every field at once.
- **C4. Labels drift.**
  - **Type:** "Traveler type", "Type for X" and "Placeholder type".
  - **Dates:** "Date paid", "Payment date" and "Due date".
  - **Optional fields:** some say "(optional)" and some don't.
- **C5. Amounts are typed several ways.** Some fields accept "1,234.50" and some show "1234.50" when refilled. Currency appears in the label on some forms and not others.

### D. Tables, lists and statuses

- **D1. Lists use several made-up patterns.**
  - Payments, reservations, travelers to add, clients found and checklist items each borrow `dd-payment-list` or `dd-checklist`.
  - Others are tables.
  - A list of records should be one component, with a title, details and actions in the same places.
- **D2. Row actions differ.** Some are text links, some are quiet buttons, and some sit inside small inline forms. UI acceptance asks for text links.
- **D3. Status badges are used for guidance.** Most guidance is now plain text, but checklists still badge "Not yet", and some panels badge non-status facts.
- **D4. Money columns aren't consistent.** Some amounts are right-aligned, some not; some show the currency code, some only the sign.

### E. Component and stylesheet debt

- **E1. Classes are reused for unrelated jobs.** `dd-rate-inline` lays out 14 different forms; `dd-payment-*` styles reservations and clients.
- **E2. The design-system preview at `/dev/ui` is out of date.** It shows none of the patterns added in steps 3 to 8.
- **E3. Stimulus controllers overlap.** `payment-summary`, `deadline-form` and `payment-allocation` each solve a small version of a shared need: summarize a form, or split an amount.
- **E4. Nothing prints cleanly.** The stylesheet has no print rules, so a printed page carries the navigation, tabs, buttons and forms.

## Screen findings

Priority: **1** blocks ease of use, **2** is inconsistent, **3** is polish.

| Screen | Findings | Proposed change | Priority |
| --- | --- | --- | --- |
| Dashboard | A2 | Kept as it is; its update is deferred to the backlog (decision 1) | Backlog |
| S-06 Departures | A3 | Add each Departure's bookings, cabins left, and money due to the list | 2 |
| S-07 Departure overview | A3, B3 | A summary of the Departure: readiness checklist, bookings and capacity, money in and out, next deadlines and tasks. Statuses and details stay | 1 |
| Departure tabs | A1 | Reorder to the work: Overview, Suppliers, Inventory, Package, Client terms, Bookings, Money (client and supplier), Tasks | 1 |
| S-12 Arrangement detail | B1, B3 | Split into sub-pages: Overview with the checklist and details; Inventory; Rates and cost; Payments and deadlines; Reservations; Documents | 1 |
| S-13 Arrangement form | C3, C4 | Show only the fields each obligation shape and promise uses | 2 |
| S-14 Supplier rates | B4, E1 | Shared disclosure and inline-field components | 3 |
| S-15 Deadlines | C1 | Keep typed values on refusal | 2 |
| S-16 Cost lines | C2, C3 | Show only the fields each basis uses, with a sentence summary | 2 |
| S-17 Inventory | B3, D4 | One table pattern for shells, pools and the night grid | 2 |
| S-18 Group detail | B4 | Shared disclosure for supply changes | 3 |
| S-19 Reservations | D1 | The shared record list | 3 |
| S-20 Package | A4, B3 | The price grid is the way to set prices; option pages edit the option | 2 |
| S-21 Client terms | C2 | Sentence summaries as each schedule line and tier is filled in | 2 |
| S-22 Client directory and profile | A5, B3 | Profile sections under one header pattern; trips and bookings listed with their Departure | 2 |
| S-24 Client Trip | A4, A5, A6 | The trip page becomes its summary: the responsible client and Departure, each booking in brief with its travelers listed under it (services, status, anything awaiting a supplier, balance), the money totals with the next amount due, and what's next. The full money panel stays on the page. Breadcrumbs follow the Departure when it has one | 1 |
| S-25 Roster | A1, D4 | Client money moves to the Money tab; the roster stays bookings | 2 |
| S-26 Booking summary | A6 | New: a read-only Summary ahead of the steps, with the whole booking: statuses, travelers and where each is placed, each service with its price, space and supplier status, acceptance, money and what's next. Each section links to the step that changes it. A confirmed booking opens on it; a draft opens on its next step | 1 |
| S-26 Booking steps | B2 | Price and hold splits: price and installments, then hold. Once confirmed, money gets its own section: the booking's balances and each payment applied to it (decision 4) | 1 |
| S-27 Record acceptance | C1 | Field errors on refusal | 2 |
| S-28, S-29 Client money | C1, D1, E3 | Field errors; the shared record list; the shared splitter | 2 |
| S-30, S-31 Supplier money | A1, D1 | Under the Money tab with client money; the shared record list | 2 |
| S-33, S-34 Tasks | D2 | Text-link row actions; group by due week | 3 |
| Administration | B3, C4 | Panel header and label consistency | 3 |
| All forms | C1, C4, C5 | One error pattern; one label style; one money input | 1 |

## Decisions settled (2026-11-09)

| # | Question | Decision |
| --- | --- | --- |
| 1 | **The Dashboard.** Make it useful, or remove it? | **Keep it; defer its update.** It stays in the navigation as it is. Making it the agency's working summary goes to the backlog. My tasks stays the landing page. |
| 2 | **One Money tab, or two?** Client money and supplier money are different questions (CMN-06, SMN-26). | **One Money tab with two sections,** client and supplier, kept apart and never netted. |
| 3 | **Arrangement sub-pages or a long page with an in-page menu?** | **Sub-pages,** like the Departure's tabs, so each fits a screen. |
| 4 | **Where does money live for a booking?** | **The trip owns money.** The booking shows its own balances (charge, paid to the agency, paid to suppliers, still due) and the detail of each payment applied to it: reference, date, route, amount applied and receipt. |
| 5 | **How far to go on the directories (M1 screens)?** They predate the slice and work. | **Header, list and label consistency only;** no redesign. |
| 6 | **Mockups for which screens?** | **The Departure overview and tabs, the arrangement sub-pages, the booking steps after the split, and the Money tab.** The shared patterns are shown in those mockups, not on a sheet of their own. |
| 7 | **Summary views for trips and bookings?** (A6) | **Yes, both.** A booking gets a read-only Summary ahead of its steps, where a confirmed booking opens. The trip page becomes the trip's summary. Both read existing records only. |
| 8 | **Printable summaries?** (E4) | **Print-friendly pages, printed or saved as PDF from the browser.** A print stylesheet and a Print link on both summaries. Nothing is stored. A PDF the agency issues and keeps is an issued document under ADR 0019, which is build step 10's work. |

## Proposed batches

Each batch is one pull request, in order, and each passes `bin/ci` and the 375px checks:

1. **Shared patterns:**
   - one form error pattern, keeping typed values (C1);
   - the record list (D1) and panel header (B3);
   - the disclosure (B4) and money input (C5);
   - text-link row actions (D2);
   - label style (C4);
   - an updated `/dev/ui` (E2);
   - the overlapping Stimulus controllers merged (E3);
   - print rules for every page (E4).

   No page layout changes.
2. **Navigation:** the Departure tabs reordered with a Money tab (A1, decision 2) and breadcrumbs (A5).
3. **The Departure overview** (A3) and the Departures list.
4. **Arrangement sub-pages** (B1, decision 3), with the conditional fields and summaries on its forms (C2, C3).
5. **The booking steps** (B2), the booking Summary and the trip summary, each with a Print link (A4, A6, decisions 4, 7 and 8).
6. **Package, client terms, inventory and the directories:** the remaining priority 2 and 3 items.

## Not in this pass

- **No rule, record or permission changes.** A need found here goes to the backlog with its rule ID.
- **The Dashboard's update** (A2), deferred to the backlog (decision 1).
- **The reseller view** waits for build step 9. Batch 5's booking steps and Summary are built so the reseller variant can reuse them.
- **No new font, icon library or JavaScript framework** (AGENTS.md).
