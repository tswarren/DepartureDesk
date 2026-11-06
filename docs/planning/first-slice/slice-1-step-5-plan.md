# Slice 1 step 5: Package, choices, prices and client terms

**Status:** Accepted 2026-11-06; built 2026-11-07. Not implementation authority beyond the [first-slice charter](first-slice-charter.md) build step 5 and the decision log entries it cites.

Charter build step 5: the package, scoped choices, client terms and the per-cabin deposit. No demonstration case closes in this step. Build step 6 books against what it builds: D4 confirms bookings at these prices, D5 relies on the terms, and D9 on the deposit.

It covers charter workflow step 7:
- **Package and choices:** BKG-13 to BKG-16, with cabin as a required single choice per unit, the Nov 5 hotel included, and extension nights and the excursion as add-ons.
- **Prices:** BKG-21.
- **Client terms:** BKG-28 and BKG-31; CMN-09 with D-76 and D-77.

Publishing to a reseller channel is build step 9 (D-90). Bookings, holds, acceptance, installments and charges are build step 6 and later. Change fees (BKG-32) are not cited by the charter.

## Questions settled for this plan (2026-11-06)

Each recommendation was accepted. Question 4 sets fixture values, which the charter takes from the decision log (D-87), and is logged as **D-93**, applied to the charter's fixture. The rest stay inside the cited rules and need no entry.

| # | Question | Decision |
| --- | --- | --- |
| 1 | **Where client terms live.** BKG-28 allows terms for a Departure or a package. D-76 puts the payment schedule on the Departure's client terms. Slice 1 has one package per Departure. | Terms belong to the **Departure**, as numbered versions. The package uses its Departure's current version. Package-specific terms wait until a Departure sells more than one offering. |
| 2 | **The agency layer.** BKG-28 builds terms from the agency's reusable terms. BKG-31 makes the cancellation schedule an agency default with an optional Departure override. Neither exists yet. | Administration gains **Client terms defaults**, Agency Admin only (`manage_agency_profile`). It holds reusable terms wording and default cancellation tiers. A Departure's terms version copies the agency wording when it is created and adds Departure-specific wording. It **follows the agency's tiers unless it overrides them**; an override replaces the default whole, never merges with it. Whichever applies is snapshotted when a booking accepts it, in step 6. D-76 leaves the payment schedule with no agency default. |
| 3 | **Tier and schedule-line shapes.** | **Cancellation tier:** from a number of days before departure, either a percentage of the affected service's accepted client charge, or a fixed amount per traveler or per unit of a named service category. Tiers are basic date-and-percentage structures, and anything else is entered manually (BKG-31). The calculation is used in step 14 (1b).<br>**Payment schedule line:** an amount that is fixed per traveler, per unit of a named service category (D-77), or per booking; or a percentage of the booking's total; or the balance. It falls due at confirmation, a number of days before departure, or on a fixed date. A line may be marked as the designated payment that counts as acceptance (BKG-41). Proposing installments from the lines is step 6. |
| 4 | **Alpha's client terms values.** The charter settles the $500 deposit per cabin at booking (B7), but not when the balance is due, the client cancellation tiers, or whether the deposit counts as acceptance. | Placeholder values, logged as **D-93**:<br>• **Balance:** due 120 days before departure (Jul 9, 2027). That is before Alpha's Aug 1, 2027 final payment less the 14-day buffer (CMN-10).<br>• **Cancellation tiers:** 10% from 120 or more days before departure, 50% from 119 to 61 days, and 100% from 60 days.<br>• **Deposit:** it does not count as acceptance. D5 then shows that confirmation needs recorded acceptance, and a test terms version with the flag on shows the other half. |
| 5 | **Components or choices.** The data model lists offering components and choices separately. | Model the package's contents **as choices only**. Each choice is `included` or `add_on`, with a scope (per traveler, per unit, per trip) and a pattern (required single, optional single, optional multiple). Optional multiple is allowed only for add-ons (BKG-14). An always-included service is a required single choice with one option. Each option draws on one inventory group of a live arrangement on the same Departure. This avoids a second structure that says the same thing. |
| 6 | **Price shape.** BKG-21 prices by traveler type, occupancy position, supplier-stated traveler-specific fare and choice option. | **Prices belong to an option.** Each row has an occupancy position (single, the n-th guest, or any position) and an optional traveler type, and holds an amount in the Departure's currency. Lookup prefers a traveler-type row over the row for any type, and a position row over the any-position row. The amount is parsed strictly (ADR 0001). Changing a price never touches a booking (BKG-23). For Alpha:<br>• Cabins are priced per guest by position, and single is a full single fare.<br>• The hotel room's 1st guest pays the room price and other guests pay $0 (B5).<br>• The excursion is $150 per traveler, with a Child 0–4 row at $0. |
| 7 | **Offering status.** Bookings arrive in step 6 and publishing in step 9. | No status column in step 5. The editor shows what an offering still needs: each required choice has an option, and each option has a price for every occupancy position its group can hold. Step 6 refuses to book an incomplete offering. Step 9 adds publication. |
| 8 | **Who edits what, and versioning.** | Viewing offerings, prices and terms is baseline (ACC-30: staff see client prices). Editing them needs **Departure management**, which the permission table gives "offerings, prices, and client terms". Agency defaults need an Agency Admin (question 2). A Departure starts with terms version 1, editable in place. Step 6 locks a version once a booking accepts it, and editing after that makes the next version. Staff may start a Departure's terms by copying another Departure's version, tiers and schedule included; the copy is independent of its source (D-76). |

### D-93 as logged

> | D-93 | 2026-11-06 | Settle the first-slice fixture's client terms values. Alpha Omega's client payment schedule is the \$500 deposit per cruise cabin at confirmation (B7) and the balance due 120 days before departure (Jul 9, 2027). The client cancellation tiers are 10% from 120 or more days before departure, 50% from 119 to 61 days, and 100% from 60 days, of the affected service's accepted client charge (BKG-31). The deposit does not count as acceptance (BKG-41). Fixture values are test inputs only; no rule changes. Amends the first-slice charter's fixture. | None |

## Offerings and choices (BKG-13 to BKG-16)

- New `offerings`: agency, Departure, name, client description, currency (the Departure's), position. Every Slice 1 offering is a package. A package groups what a client books and never merges supplier arrangements, inventory, reservations or costs (BKG-13).
- New `offering_choices`:
  - offering, name;
  - role: `included` or `add_on` (BKG-15, BKG-16);
  - scope: `per_traveler`, `per_unit` or `per_trip`;
  - pattern: `required_single`, `optional_single` or `optional_multiple`, where optional multiple is allowed only for add-ons, checked in the database;
  - position.
- New `offering_options`: choice, label, client description, the inventory group it draws on (same agency and Departure by composite key), position.
- **Completeness** (question 7): `Offering#booking_blockers` lists any required choice without options and any option missing a price for a position its group can hold.
- An option's group may belong to a Draft arrangement while the offering is set up; step 6 books only confirmed inventory.

## Prices (BKG-21, BKG-23)

- New `offering_prices`: option, occupancy position (`single`, `guest_1` to `guest_9`, or `any`), traveler type (optional), amount in minor units, currency.
  - One row per option, position and type, with `NULLS NOT DISTINCT`.
  - A position must be within the group's positions per unit.
- `OfferingPriceLookup` returns the price for one traveler: the option, their position in the unit and their traveler type. Step 6 calls it to propose a booking's prices. Nothing in step 5 posts or snapshots a price.

## Client terms (BKG-28, BKG-31, CMN-09, D-76, D-77)

- **Agency defaults** (question 2):
  - `agencies` gains reusable client terms wording (limited Markdown, as the SET-07 footers).
  - New `agency_cancellation_tiers`: agency, days before departure, and a percentage or a fixed amount with its basis.
- New `client_terms_versions`:
  - Departure, version number;
  - wording: the agency's copied, plus the Departure's own;
  - whether it overrides the agency cancellation tiers;
  - the Departure it was copied from, if any;
  - `locked_at` (set in step 6), lock version.
- New `client_cancellation_tiers`: terms version, with the agency tier shape. Used only when the version overrides.
- New `client_payment_schedule_lines`:
  - terms version, position;
  - basis: `per_traveler`, `per_unit` with a named service category (D-77), `per_booking`, `percentage` or `balance`;
  - amount or percentage;
  - due rule: `at_confirmation`, `days_before_departure` or `fixed_date`;
  - and whether it counts as acceptance (BKG-41).
  - Exactly one `balance` line per version; at most one acceptance line.
- **Copying another Departure's terms** (D-76) creates an independent version 1 with copied wording, tiers and lines.

## Screens

- **S-20 Offering editor:** the Departure's **Package** tab.
  - Shows the offering's choices by role, with scope and pattern, and each option's group and prices as a matrix of occupancy position by traveler type.
  - What the offering still needs to be booked (question 7).
  - Forms to add and edit choices, options and prices.
- **S-21 Client terms:** the Departure's **Client terms** tab.
  - Shows the version's wording, the cancellation tiers (the agency's, or the override) and the payment schedule.
  - Actions: copy from another Departure, override the tiers, and add, edit or reorder schedule lines.
  - Read-only once locked (step 6).
- **Administration: Client terms defaults.** The reusable wording and the default cancellation tiers.
- All at 1400px and 375px. Price matrices use the stacked-table pattern at narrow widths.

## Alpha fixture

`AlphaFixture.load!` adds the **Alpha Omega cruise package**:
- **Cabin** (included, per unit, required single):
  - Options V01, O01, I01 and S01.
  - Prices per guest from the Alpha schedule: for example, V01 is $3,385 for the 1st and 2nd guests and $1,285 for each additional guest. Single occupancy is the full single fare: the 1st-guest fare plus the supplement ($3,385 + $3,250 for V01).
- **Nov 5 hotel room** (included, per unit, required single):
  - Options Garden Queen and Harbor Double, drawing on the Nov 5 groups.
  - The 1st guest pays $190 or $220, and other guests pay $0 (B5).
- **Extension nights** (add-on, per unit, optional multiple): an option for each of Nov 1 to Nov 4 in each room type, priced as the Nov 5 room.
- **Private Miami tour** (add-on, per traveler, optional single): $150 per traveler, with Child 0–4 at $0.
- **Client terms version 1:**
  - wording copied from the agency's reusable terms;
  - the question 4 tiers as an override;
  - payment schedule: $500 per cruise cabin at confirmation (B7), not counting as acceptance; the balance due 120 days before departure.
- **Agency defaults** for the development agency: placeholder wording and the same tiers.

The roster's cruise subtotals ($26,400 for the three Slice 1 bookings) must follow from these prices. A test checks that with `OfferingPriceLookup`.

## Not in this step

- **Later in Slice 1:**
  - booking against the offering, choice selections, price proposals, acceptance, installment proposals from the schedule, and locking a terms version (step 6);
  - payments by route (step 8);
  - publishing the package to a reseller channel (step 9).
- **Slice 1b:** using the cancellation tiers to propose a charge (BK-103).
- **Not cited by the charter:**
  - change fees (BKG-32 to BKG-36);
  - standalone-service offerings;
  - own-arranged options (BKG-18);
  - price refresh (BKG-24).

## Tests

- **Model and database:**
  - role, scope and pattern checks, with optional multiple only for add-ons;
  - same-agency and same-Departure keys from option to group;
  - one price per option, position and type;
  - positions within the group's capacity;
  - one balance line and at most one acceptance line per version.
- **Lookup:**
  - every Alpha cabin, position and single fare;
  - the hotel's 1st-guest pricing;
  - the excursion's Child 0–4 row;
  - the roster's $26,400 cruise subtotal for the Slice 1 bookings.
- **Terms:**
  - a version follows agency tiers until it overrides them;
  - copying another Departure's terms is independent of its source;
  - per-unit lines name a service category.
- **Commands and screens:**
  - Departure management needed to edit, agency defaults Agency Admin only;
  - other agencies' records not found;
  - S-20, S-21 and the defaults page at 1400px and 375px with no page overflow.

## Build order

One PR, citing BKG-13 to BKG-16, BKG-21, BKG-23, BKG-28, BKG-31, BKG-41 (the acceptance flag only), CMN-09, D-76, D-77 and D-93:

1. Offerings, choices and options.
2. Prices and the lookup.
3. Agency defaults: reusable wording and cancellation tiers.
4. Client terms versions, tiers, payment schedule lines and copying.
5. S-20, S-21, the defaults page, the Alpha fixture and docs.
