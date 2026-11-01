# DepartureDesk First-Slice Charter

**Status:** Accepted 2026-10-31 for scope (D-64). Amended 2026-11-01 (D-66): the old supplier and offer layers retire in Phase 1, Slice 1 gains a staff checkpoint after step 6, and the Phase 0 decision rule is split. No Slice 1 build step starts before the Phase 0 checkpoint.
**Owner:** Tom
**Product authority:** [Product Specification](../../spec/README.md). Decisions this charter needs are in [pending decision log entries](../../spec/pending-decision-log-entries.md).

## Purpose and status

This charter fixes the first slice: one Departure run end to end on the Alpha fixture, by agency staff and one authorized reseller. It is delivered in two parts, Slice 1 and Slice 1b. It supersedes the earlier Greenfield first-slice charter, keeping its reseller booking path and smallest-slice intent but replacing its fixture with Alpha. The Product Specification remains the authority for every rule.

- A rule not cited here is out of Slice 1, even if it is Agreed.
- Adding scope needs a decision log entry that names this charter.
- Proposed rules in the model additions section become spec rules once approved; until then they are working assumptions for the build.

## The slice

Staff set up Alpha Cruises' November 6–13, 2027 sailing with 32 cabins, the November 5 pre-cruise hotel night and the private Miami excursion, and publish the package to one reseller channel. Staff book roster bookings and the reseller books one. Money is recorded, the Departure is marked Departed, and it is reconciled.

**Slice 1, the spine**, runs Agreement A with BK-101, BK-104 and BK-105. These still cover multi-occupancy cabins, a free infant and the excursion's non-consuming children. **Slice 1b, the hard cases**, adds BK-102 and BK-103, Agreement B, the second excursion resource, a declined hotel night, an amendment, a cancellation and a document reissue.

Each part is done when a user completes this path without a spreadsheet, and the system correctly shows four things at every step: what the client accepted, what the supplier confirmed, how capacity is used, and what money is still open.

## Fixture

The fixture is the Alpha scenario, the Shore Excursions model and the sample roster. All names are fictional. Values marked "to settle" are listed under blocking decisions.

Source documents (Google Docs):

- [Alpha Cruises Group Agreement Scenarios](https://docs.google.com/document/d/1CQbooQrrVxZSyyPFkz4v2yR40zXSfF_2Mxn1eeod-BQ/edit)
- [Shore Excursions Group — Private Miami Activity Agreement Model](https://docs.google.com/document/d/1zZsVVCqpk3g6X-nh8_O3LM4Pyz6W7lpp5ov53C-xBVA/edit)
- [Hotel Group Space — Model Agreements for Walkthrough Testing](https://docs.google.com/document/d/1-kh8yYRilvhPg8AZI87Wzc1VPK3WGlPEayeCg6edS48/edit) (source of the Garden Queen and Harbor Double test rates; the package hotel itself is B4)

| Element | Fixture value | Status |
| --- | --- | --- |
| Departure | Alpha Omega, Nov 6, 2027 4:00 p.m. to Nov 13, 2027 7:00 a.m., Port Everglades round trip; USD; America/New_York | Fixed |
| Cruise block | 8 cabins each in V01, O01, I01 (max 3) and S01 (max 4); 32 cabin shells | Fixed |
| Cruise supplier rates | Alpha rate schedule by category and occupancy position | Two values to settle (B6) |
| Agreement A: deposit-required | $50 per stateroom initial deposit due Nov 1, 2026; $500 per stateroom full deposit on naming or Mar 1, 2027; final payment Aug 1, 2027 | Credit of the $50 to settle (B2) |
| Agreement B: courtesy/option | Same 32 cabins, conditional to a Mar 1, 2027 cutoff; no deposit on unallocated space | Meaning of Mar 1 to settle (B3) |
| Package hotel | Nov 5 night included (checkout Nov 6); Nov 4 limited; Nov 1–3 on request; Garden Queen $145 and Harbor Double $175 per room-night supplier test rates | Supplier, quantities and client prices to settle (B4, B5) |
| Excursion | Shore Excursions Group, CAFTPVTMIAFTLAUD; Nov 5, 2027, 2:00–6:30 p.m.; $1,000 per resource, 10 positions each; final count due Oct 22, 2027 | Fixed; one resource confirmed at start (B8) |
| Excursion client price | $150 per participating traveler; children 0–4 free and use no position | Fixed |
| Client deposit | Agreement A: $500 per cabin at booking | Agreement B value to settle (B7) |

The five roster bookings carry 13 travelers, including two infants who occupy cabin positions and pay the additional-guest fare. Cruise subtotals total $34,820 for all five and $26,400 for the three Slice 1 bookings.

| Booking | Slice | Cabin | Travelers | Excursion participants | Positions used | Cruise client subtotal | Hotel request |
| --- | --- | --- | --- | --- | ---: | ---: | --- |
| BK-101 Rowan | 1 | V01 | 3 | 3 | 3 | $8,055 | Garden Queen from Nov 4 |
| BK-104 Bennett | 1 | S01 | 4, incl. Milo (2) | 4 | 3 | $11,240 | Harbor Double from Nov 2 |
| BK-105 Rivera | 1, via the reseller | O01 | 3, incl. Luca (3) | 2; Elena opts out | 1 | $7,105 | Garden Queen, Nov 5 only |
| BK-102 Mercer | 1b | O01 | 2 | 2 | 2 | $5,970 | Harbor Double, Nov 5 only |
| BK-103 Ellis | 1b | I01 | 1 | 1 | 1 | $2,450 | Garden Queen from Nov 3 |
| **All five** | | | **13** | **12** | **10** | **$34,820** | |

Slice 1's three bookings have 9 excursion participants using 7 of 10 positions. With all five bookings, 12 participants use all 10. When Elena Rivera then opts in, demand reaches 11 positions and needs a second $1,000 resource: client revenue $1,650 against supplier cost $2,000.

## Workflow steps

The first slice has fifteen workflow steps. Work marked 1b is built in Slice 1b; everything else is Slice 1. Each step cites the rules it must satisfy.

1. **Agency and staff.** One agency with an Agency Admin, baseline staff and a staff user holding Financial records. Agency profile, time zone and references. ACC-02, ACC-04, ACC-07, ACC-10, ACC-30, ACC-31; SET-01, SET-04, SET-09, SET-10; REF-01 to REF-03.
2. **Departure.** Record identity, dates, currency, time zone and team; set Ready to sell; publish the package to one reseller channel. DEP-01, DEP-03 to DEP-07; FIN-22.
3. **Suppliers and arrangements.** Alpha Cruises, the package hotel and Shore Excursions Group, each with one payee account and one arrangement, Draft then Confirmed. SUP-01, SUP-02, SUP-06, SUP-07, SUP-09, SUP-11, SUP-15 to SUP-18.
4. **Supplier deadlines and tasks.** Deposit, names, final payment and final count, each creating a task; the option cutoff in 1b. SUP-22 to SUP-25; OPS-01 to OPS-05.
5. **Inventory.** Cabin shells per category; Nov 5 room shells; Nov 4 as a limited group; Nov 1–3 on request; the excursion as resource shells with positions (M2). INV-01 to INV-05, INV-07, INV-09, INV-12, INV-38.
6. **Supplier cost and schedule.** Cost lines, schedule lines and amounts due for Agreement A and the $1,000 resource; Agreement B in 1b. SMN-01 to SMN-06, SMN-08, SMN-10, SMN-11, SMN-13, SMN-14, SMN-17; supplier rate table per M3.
7. **Package and client terms.** Cabin as a required single choice per unit; Nov 5 hotel included; extension nights and the excursion as add-ons; cancellation schedule and payment schedule template. BKG-13 to BKG-16, BKG-21, BKG-28, BKG-31; CMN-09 with M4.
8. **Clients and travelers.** Responsible clients and travelers, with placeholders allowed on holds; no passport fields. CLT-01, CLT-02, CLT-05, CLT-06, CLT-09, CLT-11, CLT-13, CLT-15.
9. **Reseller relationship.** Authorize one reseller, assign BK-105 to it, and record the seller of record. ACC-13, ACC-14, ACC-18; FIN-05 seller of record only.
10. **Hold, accept and confirm.** Staff confirm BK-101 and BK-104; the reseller holds and confirms BK-105 at the published price. Conditional holds on courtesy space in 1b. BKG-05, BKG-06, BKG-09 to BKG-11, BKG-25, BKG-39, BKG-41, BKG-45, BKG-46; ACC-15; DEP-10; INV-17 to INV-23; M1.
11. **Supplier follow-up.** Supplier requests for on-request hotel nights, accepted with a reference; names submission. A declined night and the second excursion resource in 1b. INV-26, INV-33 to INV-37; SMN-11, SMN-12.
12. **Client money.** Charge lines, installments, payments to the agency and to a supplier, and receipts. The reseller sees balances and passes on payment details but enters nothing. CMN-01 to CMN-03, CMN-06, CMN-08, CMN-12, CMN-18, CMN-19, CMN-21, CMN-23, CMN-24, CMN-28, CMN-29, CMN-52, CMN-55.
13. **Supplier money.** Supplier payments applied to amounts due, plus expected commission. SMN-18, SMN-19, SMN-22, SMN-23, SMN-32, SMN-33.
14. **1b: one change, one cancellation.** Elena Rivera adds the excursion after confirmation; BK-103 cancels. BKG-17, BKG-47, BKG-54, BKG-57; INV-24; CMN-37, CMN-38.
15. **Documents, travel and closeout.** Confirmation, invoice and receipt as versioned PDFs, with the reseller downloading its booking's confirmation; reissue in 1b. Departed and reconciliation with blockers. DOC-01, DOC-03, DOC-11, DOC-21, DOC-24; DOC-12 in 1b; DEP-42 to DEP-44, DEP-46; FIN-01, FIN-17, FIN-18, FIN-20.

## Scope

Slice 1 keeps every distinction the spec protects, but builds the common path only.

| Area | Slice 1 | Slice 1b adds | Later slices |
| --- | --- | --- | --- |
| Access | One agency; Admin, baseline staff, Financial records; one reseller with assigned-booking access | | Platform access grants, offices, work groups, passport permission, reseller pause and suspension |
| Departure | Draft, Ready to sell, publish to one channel; operating decision Proceed only | | Review items, go/no-go panel, Departure cancellation and postponement |
| Suppliers | One payee account each; deadlines and tasks; Agreement A | Agreement B with its option cutoff | Agreement templates, group benefits, count-change warnings, cancellation tiers |
| Inventory | Cabin, room and resource shells; on-request groups | Second resource as a dated increase; conditional holds | Capacity conflicts, supplier reductions, setup changes, air and rail |
| Clients and travelers | Profiles, Self links, staged details | | Passports, imports, duplicates, corrections, substitutions |
| Bookings | Holds, acceptance and confirmation by staff and the reseller | One add-on amendment, one cancellation | Shared-unit cancellation, transfers, replacement, change fees, price refresh, reseller requests |
| Supplier money | Cost lines, schedule lines, amounts due, payments, expected commission | | Commission receipts, credits, held-fund offsets, statements, supplier account view |
| Client money | Charge lines, installments, payments by route, receipts | Refund due | Card fees, chargebacks, travel credits, FX, overdue handling |
| Documents | Confirmation, invoice and receipt as versioned PDFs, delivered manually | Invoice reissue | Email, reminders, statements, acknowledgments, supplier outputs |
| Operations | My tasks and the Departure task list; individual owners | | Groups, reminders, notifications, Needs attention, incidents |
| Profitability | Projected and actual Departure margin in USD; seller of record | The negative excursion margin case | Seller commission payables, shared-cost allocation, planning rates, exposure view |
| Reporting | Departure summary only | | Nine reports and exports |
| Interface | UI acceptance standards, light theme | | Dark theme |

One shared-cabin booking is the first case for Slice 2, since the roster has no cabin shared across bookings.

## Model additions

The fixture needs four rules the spec does not have yet. Each is proposed wording; approving it adds a rule and a decision log entry. The wording is in [pending decision log entries](../../spec/pending-decision-log-entries.md#model-additions).

| ID | Gap | Amends |
| --- | --- | --- |
| M1 | Children 0–4 take part in the excursion but use no position | INV-12 (activity), INV-07 |
| M2 | The excursion is sold per resource, not per place | INV-12, INV-16, INV-26 |
| M3 | Supplier rates vary by occupancy position, with components | SUP-21, SMN-02, SMN-32 |
| M4 | The client deposit is $500 per cabin, not per traveler | CMN-09 |

Hotel extensions need no new rule: each extension date is its own inventory group with its availability promise (INV-01, INV-04), sold as a per-room-night add-on (BKG-16).

## Blocking decisions

Each decision has a proposed default so work can start; placeholder values are test inputs only. Decisions that shape the data model are settled before Phase 0 closes: B1 (logged as D-65), B10 and B11, and the model additions M1 to M4. The fixture values B2 to B9 are settled before the step they block. The decisions and defaults are in [pending decision log entries](../../spec/pending-decision-log-entries.md#blocking-decisions).

| ID | Decision | Blocks step |
| --- | --- | --- |
| B1 | Rebuild on the existing Rails and Tailwind app, or start a new stack | All |
| B2 | Is the $50 initial deposit credited toward the $500? | 6 |
| B3 | What Mar 1, 2027 means in each agreement | 4, 6 |
| B4 | Package hotel supplier and block | 3, 5 |
| B5 | Hotel client prices | 7 |
| B6 | Alpha rate values that look wrong | 6 |
| B7 | Client deposit under Agreement B | 7 |
| B8 | Opening excursion resources | 5 |
| B9 | Final-count deadline time | 4 |
| B10 | Resellers in Slice 1 | 2, 9, 10 |
| B11 | Design tokens and status labels | UI |

Three spec fixes do not block the slice but should be made before Slice 2: remove stale references to a separate Financial review queue (SC-BKG-07, the SMN amount-due table, the OPS table title); align OPS-34 with D-60; and close the stale Departures open-questions note.

## Technical baseline

These choices hold whatever stack B1 picks; they are expensive to change later.

| Concern | Slice 1 baseline |
| --- | --- |
| Tenancy | Every agency record carries its agency id and is loaded through `Current.agency`, never through a Rails `default_scope`, with tests that cross-agency reads fail (ACC-04) |
| Authorization | Permission and reseller scoping enforced server-side on every query and action, beside tenancy. Tests show a reseller cannot read unassigned bookings or write money (ACC-14, ACC-15, ACC-31) |
| Money | Integer minor units plus an ISO currency code; never floating point. Calculated amounts are rounded once when posted and then snapshotted (SMN-06) |
| Time | Instants in UTC; zones as IANA ids; date-only facts as dates; date-only deadlines resolve per SET-10 |
| Test clock | An injectable clock, since fixture dates run from Nov 2026 to Nov 2027 |
| History | Inventory and money changes are append-only events with reversals, never edits (INV-26, SMN-23, CMN-27); audit events per ACC-23 and ACC-24 |
| Derived status | Shell status, Client Trip status and the Departure label are computed, never stored (INV-38, BKG-03, DEP-04) |
| Sign-in | Email and password with sessions for staff and reseller users; MFA is decided before any real agency data is loaded |
| Sensitive data | No passport fields in the first slice; field-level encryption is designed before they are added |
| Documents | Rendered once at issue, server-side HTML to PDF, and stored as immutable versions through Active Storage per [ADR 0019](../../adr/0019-issued-document-storage.md) (DOC-11, DOC-12); previews may render on demand; no email sending |
| Interface | WCAG 2.2 AA; tokens per B11; standards in UI acceptance |
| Tests | The fixture loads from one seed script; each demonstration case is an automated end-to-end test named by its ID |

## UI acceptance

Every first-slice screen meets these standards, checked in the walkthrough at desktop width and at 375px. They are drawn from the UI/UX doc and the form sample; confirm them against the UI foundation discussion.

| Area | Standard |
| --- | --- |
| Page structure | Navy app frame on a light workspace; breadcrumbs; a page header with eyebrow, title, one-line description and the primary action |
| Navigation | Persistent navigation on desktop that collapses to a menu below 768px; the current item is marked in teal, never amber; fully usable by keyboard |
| Drafts | Departures, arrangements, bookings and profiles save without required fields; requirements apply only at the step that needs them, such as confirm or publish |
| Unsaved changes | Leaving a form with unsaved changes asks for confirmation |
| Errors | An error summary at the top links to each field; each field shows its own message with `aria-invalid` and `aria-describedby`, and an icon so color is not the only signal |
| Blocked actions | A disabled or refused action says why and what to do next, such as "Record the client's acceptance to confirm" |
| Tables | Numbers right-aligned in tabular figures; row actions as text links; wide tables scroll inside their own container, never the page |
| Status | Only spec labels (DEP-04, BKG-06, INV-18, INV-34), each shown as text plus color |
| Reseller view | The same layout, scoped to published offers and assigned bookings, with no supplier cost, commission, margin or money entry |
| Focus | An amber focus ring on every control, visible on every background |

Existing mockups are foundation illustrations, not renderings of this charter. A first-slice mockup uses the Alpha fixture and shows the reseller view as a scoped variant, not a switch.

## Demonstration cases

Seventeen cases prove the first slice. Each becomes an automated test; the Slice column says when it is built.

| ID | Slice | Given and when | Then | Rules |
| --- | --- | --- | --- | --- |
| D1 | 1 | Staff confirm the Alpha arrangement | 32 cabin shells exist only after confirmation, with committed cost recorded | SUP-12, SUP-13 |
| D2 | 1 | Agreement A, B2 as proposed | $1,600 falls due Nov 1, 2026; naming each of the three Slice 1 cabins posts $450 more; no payment changes capacity | SMN-03, SMN-05, SMN-11 |
| D3 | 1b | Agreement B; staff hold a cabin | The hold is conditional, shows the Mar 1 cutoff, and a cutoff task exists; no initial deposit is due | INV-22, SUP-23 |
| D4 | 1 | Staff confirm BK-101 and BK-104; the reseller confirms BK-105 | Cruise subtotals total $26,400; cabins left: V01 7, O01 7, I01 8, S01 7. In 1b all five total $34,820 | BKG-25, BKG-45, INV-38 |
| D5 | 1 | Anyone tries to confirm without recorded acceptance | Confirmation is refused; a deposit counts as acceptance only when the terms say so | BKG-39, BKG-41 |
| D6 | 1 | Excursion choices are recorded for the Slice 1 bookings | 9 participants, 7 positions used, 3 left; Luca and Milo listed without positions. In 1b all five use all 10 | M1, BKG-16 |
| D7 | 1b | Elena Rivera adds the excursion after confirmation | Blocked for lack of capacity until staff record a confirmed second resource; then capacity is 20, supplier cost $2,000 and excursion margin −$350 | M2, BKG-17, INV-23, INV-26 |
| D8 | 1, 1b | BK-104 is confirmed with Nov 2–3 on request | Those nights show Awaiting supplier; in Slice 1 the hotel accepts and its reference is recorded. In 1b a decline is flagged, acceptance is kept and nothing cancels | INV-33 to INV-37 |
| D9 | 1 | BK-101 and BK-104 pay $500 each to the agency; BK-105 pays $500 to Alpha | Agency receipts total $1,000; the receivable drops by $1,500; the Alpha payment has no receipt and is not agency cash | CMN-06, CMN-29, CMN-55 |
| D10 | 1 | Staff pay Alpha the amounts due | Amounts due are settled; the deposit is never added to cost | SMN-03, SMN-19 |
| D11 | 1b | BK-103 cancels | The I01 cabin and an excursion position return to inventory; the supplier commitment is unchanged; staff enter the refund due | BKG-54, INV-24, CMN-37, CMN-38 |
| D12 | 1 | Deadlines are recorded | Tasks exist with owners, including the Oct 22, 2027 final count, and show overdue from their deadline | SUP-22, SUP-23, OPS-03 |
| D13 | 1 | Staff issue a confirmation, invoice and receipt | PDFs are stored as immutable versions and show no dates of birth | DOC-03, DOC-11 |
| D14 | 1 | Staff mark Departed and try to reconcile | An open client balance blocks; a confirmed unpaid commission does not, but is excluded from actual margin | DEP-43, DEP-44, DEP-46, FIN-20 |
| D15 | 1 | The reseller signs in with BK-105 assigned | It sees only the published package and BK-105; holds and confirms after acceptance; sees the balance but no supplier cost, commission or margin; recording a payment is refused | ACC-14, ACC-15, ACC-31, DEP-07, CMN-19, CMN-52 |
| D16 | 1 | Staff save a Departure, arrangement and booking with required fields missing | All three save; confirming the booking lists what is missing, each linked to its field | UI acceptance, CLT-15, BKG-45 |
| D17 | 1b | Staff reissue the invoice | A new version is issued and the earlier one is kept as superseded | DOC-12 |

## Build plan

The build keeps the existing Rails app's foundation (D-65): agency identity, the client and supplier directories, and Departures. It deletes the shipped M3 and M4 supplier and offer layers in Phase 1 and adds a new supplier, inventory and booking layer written to the spec. It runs in four phases, each ending at a checkpoint.

| Phase | Work | Checkpoint |
| --- | --- | --- |
| 0. Decide | Settle B1, B10, B11, M1–M4 and the three code conflicts (office time zones, roles versus permissions, versioning versus dated adjustments; D-61 to D-63); write the Slice 1 data model and screen inventory; mock up the Alpha fixture | Decisions logged; data model and screens reviewed |
| 1. Prepare | Point `AGENTS.md` at the spec and charter; archive old planning docs; add the Alpha seed script, an injectable clock and pending tests D1 to D17; run the 2–3 day hold-and-reserve spike on existing capacity pools; then delete the M3 and M4 layers (arrangements, capacity, costs, activation, reservations, commitments, deadlines, exposure, service offers, packages, publication, and the Cruise, Hotel, Transportation and Activity workflows) with their routes, views and tests, keeping only capacity ledger code the spike chooses to adapt | Spike decides adapt or replace for capacity; old layers deleted; remaining tests pass |
| 2. Slice 1 | Eleven vertical steps, each ending with its D-cases passing (table below). After step 6, a staff-only walkthrough of setup through confirmed bookings, before money, reseller access and documents are built | Staff walkthrough after step 6; final walkthrough by a staff user and a reseller user who did not build it |
| 3. Slice 1b | Build the 1b cases | All D-cases pass |

| Order | Step | Cases closed |
| ---: | --- | --- |
| 1 | Foundation changes: permissions, reseller user type, agency profile fields, more reference types, one agency time zone | |
| 2 | Departure statuses, Ready to sell, publishing to a reseller channel | |
| 3 | Arrangements, inventory groups, shells, pools and resources, supplier rate table, deadlines that create tasks | D1, D12 |
| 4 | Supplier cost, schedule lines and amounts due | D2 |
| 5 | Package, scoped choices, client terms, per-cabin deposit | |
| 6 | Travelers, Client Trips, bookings; hold, accept and confirm; draft saving | D4, D5, D6, D16 |
| 7 | Supplier reservations that can stand alone | D8 |
| 8 | Client charges, installments, payments by route, receipts; supplier payments; expected commission | D9, D10 |
| 9 | The reseller path | D15 |
| 10 | Confirmation, invoice and receipt PDFs | D13 |
| 11 | Departed and reconciliation | D14 |

Working rules: one pull request per step or case, citing its rule IDs; the spec changes before the code does, with a decision log entry; one slice active at a time; every screen meets UI acceptance before its step is done.

## Exit and scope control

Each part exits when its criteria hold.

- **Slice 1:** its cases pass as automated tests; the staff walkthrough after step 6 is done and its findings resolved or logged; a staff user and a reseller user who did not build it complete their paths unaided; B1 to B6 and B8 to B11 are settled; M1 to M4 are approved or replaced.
- **Slice 1b:** its cases pass; the walkthrough covers all five bookings under both agreements; B7 is settled.
- **Both:** every screen meets UI acceptance at desktop width and 375px.

Only one slice is active at a time. A need found during the build goes to the backlog with the rule ID it touches; it enters Slice 1 only through a decision log entry.

Proposed next slices, in order:

- **Slice 2: sharing and sensitive data.** A cabin shared across bookings, email sending, passports, and reseller requests and notifications.
- **Slice 3: things going wrong.** Capacity conflicts, Departure cancellation and postponement, credits and change fees.
- **Slice 4: running the business.** Reports, imports, reminders and the full supplier account view.
