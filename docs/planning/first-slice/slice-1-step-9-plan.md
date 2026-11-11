# Slice 1 step 9: The reseller path

**Status:** Accepted 2026-11-09, with **D-99** logged, after the [UX consolidation pass](ux-consolidation-audit.md) merged (#283). 9a (the staff side) merged 2026-11-10; 9b (the reseller path, D15) built 2026-11-10. Not implementation authority beyond the [first-slice charter](first-slice-charter.md) build step 9 and the decision log entries it cites.

Charter build step 9 builds the reseller path, including publishing to a reseller channel (D-90) and the reseller holding and confirming BK-105 (D-94). It closes **D15**:

> The reseller signs in with BK-105 assigned. It sees only the published package and BK-105; holds and confirms after acceptance; sees the balance but no supplier cost, commission or margin; recording a payment is refused.

It covers:
- **Workflow step 2, publishing:** DEP-07, with DEP-08 and DEP-09 (D-90).
- **Workflow step 9, the reseller relationship:** ACC-13, ACC-14, ACC-18; CLT-25 (D-78); FIN-05, seller of record only.
- **Workflow step 10, the reseller's part:** ACC-15 and DEP-10, using the step 6 hold, acceptance and confirmation rules (BKG-05, BKG-06, BKG-09 to BKG-11, BKG-25, BKG-39, BKG-41, BKG-45).
- **Workflow step 12, the reseller's money view:** CMN-19 and CMN-52.
- **ACC-31,** checked for the reseller.

It uses screens S-04, S-10 and R-01 to R-03. R-04, the confirmation download, is build step 10.

Already shipped from step 1:
- the `resellers` table, with status and the direct-contact setting;
- the `reseller` user type, which requires a reseller (check constraint);
- the `reseller_relationships` permission;
- the `:reseller` requirement in the action catalog.

No command creates a reseller yet, `client_bookings.owner_kind` is constrained to `agency`, and nothing is ever published.

## Questions settled for this plan (2026-11-09)

Questions 1, 2 and 11 change how the charter describes BK-105, set fixture values and depart from the one-PR working rule, so they are proposed below as **D-99**. The others stay inside cited rules.

| # | Question | Recommendation |
| --- | --- | --- |
| 1 | **How BK-105 reaches the reseller.** Workflow step 9 says staff "assign BK-105 to it", and D15 has the reseller sign in with BK-105 already assigned. CLT-25 lets a reseller create profiles "while creating or completing a booking assigned to its reseller relationship". | **The reseller creates BK-105 itself (D-99 (1), settled 2026-11-09).** On the published package, the reseller creates:<br>• Mateo Rivera's client, who also travels;<br>• Elena and Luca as travelers;<br>• the Client Trip and the booking.<br>It then picks the cabin, room and tour, holds, records acceptance and confirms.<br>A booking created by a reseller user is assigned to its relationship when it is created, and the reseller is recorded as its seller of record.<br>Staff assignment and reassignment (ACC-18) are still built, in 9a.<br>D15 then reads: the reseller signs in, creates BK-105 on the published package, holds and confirms it. |
| 2 | **The fixture's reseller.** The charter fixture doesn't name one, and D-87 settled every fixture value. | **Coral Coast Travel (D-99 (2), settled 2026-11-09)**, fictional, with direct contact allowed (the default). It has one reseller user, Dana Whitfield, `dana@coralcoast.example`. The user's name and email are placeholders, as D-94's roster values are. Its password is development-only, kept in the seed and never printed. |
| 3 | **Relationships and reseller users (ACC-13).** The charter excludes pause and suspension. | **New action `manage_reseller_relationships`**, needing Reseller relationships. It covers the Resellers page, authorizing a relationship (create), and editing its name and the direct-contact setting (DOC-08). Other staff see a reseller's name wherever it owns or sells a booking.<br>**Reseller users** are invited from the relationship's page, in 9b, through the shipped invitation flow (`InviteAgencyUser`), with type `reseller` and that relationship, under the same action. They wait for 9b so that no reseller can sign in before the staff guard and the reseller screens exist. Suspending a reseller user stays with the shipped user commands (admin only).<br>Pause, suspension, ending, reactivation and ACC-35's reassignment queue are not built. The status column keeps its four values, and every relationship is Active in Slice 1.<br>`Reseller` joins the closed audit subject catalog, with `reseller.authorized` and `reseller.updated`. |
| 4 | **Publishing (DEP-07 to DEP-09).** The data model has an offering publication: offering, channel, published and withdrawn times. In Slice 1 the channel is the relationship (D-68). | **New `offering_publications`:**<br>• columns: agency, offering, reseller, published at and by, withdrawn at and by;<br>• a partial unique index allowing one open publication per offering and reseller;<br>• a same-agency composite foreign key on each reference.<br>**Commands and permissions:**<br>• `PublishOffering` and `WithdrawOffering`, under a new `publish_offerings` action needing Departure management (the permission table);<br>• publishing is refused unless the Departure is Ready to sell, and the refusal says so (DEP-07, SC-DEP-02);<br>• open review items don't block publishing (DEP-09);<br>• `ReturnDepartureToDraft` withdraws every open publication in its transaction (DEP-08).<br>Audited on the Departure as `departure.offering_published` and `departure.offering_withdrawn`. |
| 5 | **New holds on a Draft Departure (DEP-08).** Today `HoldBookingSpace` doesn't check the Departure's status. | **Already built.** Step 6's `ensure_on_sale!` (DEP-05) refuses a new booking, hold or confirmation unless the Departure is On sale, which includes Ready to sell. Extending or keeping an existing hold is unchanged (DEP-08). In 9b, a reseller's hold also needs an open publication of the booking's offering to its relationship. |
| 6 | **Owner, creator and seller of record (ACC-18, FIN-05).** `client_bookings` has `owner_kind` (only `agency`) and `created_by_id`. | **Columns on `client_bookings`:**<br>• `owner_kind` gains `reseller`, with `owner_reseller_id`. A check enforces that one is present exactly when the other is, plus a same-agency composite foreign key.<br>• `seller_kind` (`agency` or `reseller`) and `seller_reseller_id`, under the same check. Existing rows backfill to the agency.<br>**Commands:**<br>• `AssignClientBooking`, under a new `assign_bookings` action needing Departure management (the permission table), moves a booking between the agency and an authorized reseller, or between resellers. It never touches the seller of record.<br>• `SetBookingSellerOfRecord`, under the same action, changes the seller of record while the booking is a draft. Once it is confirmed, the seller of record is fixed in Slice 1, because seller commission is outside the charter (FIN-05, seller of record only).<br>The owner and seller show on the roster (S-25) and the booking Summary. ACC-18's notices and staff queue routing are notifications, which are Slice 2 (charter scope).<br>Audited on `ClientBooking` as `client_booking.assigned` and `client_booking.seller_of_record_set`. |
| 7 | **Created by (D-78, CLT-25).** The data model adds created by to clients, people, organizations, contact points and travelers. None of those tables has one. | **A nullable `created_by_id` on `clients` and `travelers`**, with a same-agency composite foreign key to `agency_users`. It is nullable because shipped rows have no recorded creator, and the schema doesn't invent one.<br>A client's person or organization and its contact points are created in the same command as the client, so the client's creator stands for them, and the data model row is amended to say so.<br>9a records the creator in every command that creates a client or traveler. The client directory (S-22) gains a "Created by a reseller" filter in 9b, when resellers can create profiles.<br>Reseller-created profiles get no duplicate check or warning (D-78). |
| 8 | **Reseller authorization (ADR 0017).** | **Deny by default, enforced on the server:**<br>• Reseller requests are served only from a `Reseller::` namespace under `/reseller`. Its base controller refuses staff sessions, and every staff controller refuses reseller sessions through one guard in the staff base controller.<br>• A reseller lands on its home (S-01).<br>• All reseller reads go through one `ResellerScope`, built from `Current.agency` and the user's relationship. It holds the offerings with an open publication to the relationship, and the bookings owned by it. Clients, travelers and trips are reached only through those bookings. Anything else returns not found.<br>• New catalog actions `reseller_view_offers` and `reseller_manage_bookings`, with the `:reseller` requirement.<br>• The booking commands accept a reseller actor when the booking is owned by the actor's relationship, and are otherwise unchanged. Money, supplier, Departure and directory commands refuse resellers unchanged. |
| 9 | **What the reseller does (ACC-15).** | **In Slice 1 the reseller does these, on bookings owned by its relationship:**<br>• creates the client, travelers, Client Trip and booking on a published offer (question 1);<br>• adds travelers and picks options;<br>• holds, extends (BKG-09 to BKG-11) and records acceptance (S-27);<br>• confirms;<br>• discards an unconfirmed booking while its hold is active (BKG-56, cited through ACC-15).<br>**DEP-10:** confirmation by a reseller is refused when the booking's price lines or terms version differ from the offering's current ones. The refusal says that the agency must confirm or refresh it. Price refresh (BKG-24) is outside the charter, so staff confirm at superseded prices (DEP-10).<br>**Not built:** requests for amendments and cancellations (Slice 2), sending documents (build step 10 and later) and payment detail submissions. |
| 10 | **What the reseller sees (ACC-14, ACC-31, CMN-19, CMN-52).** | **Shown:**<br>• **R-01, home:** the published offers and the bookings it owns, with each booking's status, hold expiry and balance.<br>• **R-02, offer:** the package, choices, client prices, and availability as places left per option. Supplier cost, the rate table and inventory detail are not shown.<br>• **R-03, booking:** the step 5 booking steps and Summary, with their reseller variants. Charge lines, installments, payments and balance are read-only.<br>**Payments:** recording one is refused. Instead of a form, the booking says payments are recorded by the agency, and to send the agency the amount, date and reference of any payment already made. A direct request to the payment route is refused by the server.<br>**Never loaded:** supplier cost, expected commission, margin and money-entry forms. Tests check the response bodies, not only what is visible. |
| 11 | **Delivery.** | **Two pull requests (D-99 (3), settled 2026-11-09).**<br>**9a, staff side, closing no case:**<br>• relationships and the Resellers page (S-04);<br>• publishing and withdrawal (S-10), and withdrawal on return to Draft (DEP-08);<br>• owner, seller of record and assignment;<br>• created by.<br>**9b, the reseller path, closing D15:**<br>• reseller-user invitations, and the "Created by a reseller" filter;<br>• the namespace, guard and scope;<br>• R-01 to R-03;<br>• the reseller booking commands;<br>• the seed's reseller-created BK-105;<br>• D15.<br>Step 9 is done when 9b merges. |

## Proposed decision log entry

> | D-99 | 2026-11-09 | Amend the first-slice charter for build step 9. (1) The reseller creates BK-105: on the published package it creates the client, travelers, Client Trip and booking (CLT-25), then holds, records acceptance and confirms it. A booking created by a reseller user is assigned to its reseller relationship on creation, with that reseller as seller of record. Staff assignment and reassignment (ACC-18) are still built. Workflow step 9's "assign BK-105 to it" is met by that assignment on creation, and D15 reads: the reseller signs in, creates BK-105 on the published package, holds and confirms it. Amends D-94 (1). (2) Settle the fixture's reseller: Coral Coast Travel (fictional), direct contact allowed, with one reseller user whose name and email are placeholder values; fixture values are test inputs only. (3) Build step 9 is delivered as two pull requests, an exception to the one-per-step-or-case working rule for this step only: the staff side (reseller relationships and users, publishing, booking owner and seller of record, created by), closing no case; then the reseller path, closing D15. The step is done when the second merges. | ACC-13, ACC-14, ACC-18, CLT-25, DEP-07 |

Once it is logged, the repo changes in 9a's first commit:
- the charter's status line, workflow step 9, the D15 row and the build-plan working rules;
- the pending entries' "Already logged" row and the snapshot's decision log row;
- the planning index.

## Screens

- **S-04, Resellers** (Admin, or Reseller relationships), in the sidebar's System section. A list of relationships with status, the direct-contact setting and counts. Each relationship's page shows the offers published to it and the bookings it owns; 9b adds its users, with Invite.
- **S-10, Publish to reseller** (Departure management). A panel on the Package tab lists each reseller with Published or Not published, and Publish or Withdraw beside it. On a Draft Departure it shows why publishing is refused, rather than a button.
- **S-03, Users.** Reseller users show their relationship. Invitations to them are made from S-04.
- **S-22, client directory (9b).** Adds the "Created by a reseller" filter, and a "Created by" line on the profile.
- **S-25 roster and S-26 booking Summary.** The roster's Owner column names the reseller. The Summary's "Owner and seller" panel shows the owner, the seller of record and the creator, with "Change the owner" and, on a draft, "Change the seller of record" for Departure management.
- **R-01 to R-03,** as in question 10. They have the same layout as the staff screens, with no Departure tabs, and are a scoped variant rather than a view switch (charter UI acceptance).

Each screen meets the UI acceptance standards at desktop width and 375px.

## Not in this step

- Pause, suspension, ending and reactivation of a relationship (ACC-16, ACC-17, ACC-35), and the direct-contact setting's effects on documents (DOC-08 is stored only).
- Several resellers sharing a channel (D-68).
- Seller commission (FIN-05, beyond the seller of record).
- ACC-18's notices and queue routing (Slice 2 notifications).
- Price refresh (BKG-24), so a reseller can't confirm at superseded prices (DEP-10).
- Reseller requests for amendments and cancellations, and sending documents.
- Reseller-submitted payment details as a record.
- R-04, the confirmation download (build step 10).

## Tests

- **D15**, against the Alpha fixture with the default seed:
  1. Dana signs in and lands on the Coral Coast home, which shows the published Alpha package and no booking.
  2. She creates Mateo, Elena and Luca, the trip and BK-105; picks O01, a Garden Queen on Nov 5 and the tour for Mateo and Luca; and holds.
  3. She records Mateo's in-person acceptance and confirms. The cruise subtotal is $7,105.
  4. She sees the charge lines, installments and balance, and no supplier cost, commission or margin anywhere in the responses.
  5. A payment request is refused. BK-101, BK-104 and another agency's booking are not found.
- **D4, D9 and D10** keep passing. The default seed now has the reseller create and confirm BK-105 on its roster date, and staff still record Mateo's payment to Alpha.
- **Commands:**
  - Publishing a Draft Departure is refused.
  - Returning to Draft withdraws every open publication.
  - A second open publication of the same offering to the same reseller is refused.
  - A reseller can't hold on an offering not published to it.
  - A reseller can't confirm at prices that differ from the offering's current ones, and staff can.
  - Assignment leaves the seller of record unchanged, and the seller of record can't change after confirmation.
  - The owner and seller checks are enforced in PostgreSQL.
- **Authorization:**
  - Each staff controller refuses a reseller session, and the reseller namespace refuses a staff session.
  - A reseller can't read unassigned, agency-owned or other-relationship bookings, or other channels' offers: each is not found.
  - Every money, supplier, Departure and directory command refuses a reseller actor.
  - Baseline staff can't publish, assign or manage relationships.
  - Another agency's reseller is not found.
- **Query counts** for R-01 and S-04.
- **UI:** every new screen reflows at 375px without page overflow.

## Build order

**9a**, citing ACC-13, ACC-18, DEP-07 to DEP-09, FIN-05 and D-78:
1. D-99 applied to the docs.
2. Migrations for publications, owner, seller and created by, then the models and commands.
3. S-04, S-10, and the owner, seller and assignment forms.
4. The docs: AGENTS.md invariant 15 (`Reseller`), the shipped vocabulary, current state and the data model rows.

**9b**, citing ACC-13, ACC-14, ACC-15, ACC-31, CLT-25, CMN-19, CMN-52, DEP-10 and D15:
1. Reseller-user invitations, the staff guard, the `Reseller::` namespace, `ResellerScope` and the reseller catalog actions.
2. The reseller-aware booking and profile commands.
3. R-01 to R-03, and the directory's "Created by a reseller" filter.
4. The seed: Coral Coast, Dana, the publication, and BK-105 created, held, accepted and confirmed by Dana at each booking level.
5. D15, the docs, the planning index and walkthrough notes.

## Trying it in the development app

After 9b, with the default seed:
1. Sign in to `harbor` as Dana Whitfield, using the password in [db/seeds.rb](../../../db/seeds.rb). The home shows the Alpha package and BK-105, confirmed.
2. Re-seed with `ALPHA_FIXTURE_BOOKINGS=none` and walk BK-105 from the start as Dana.
3. Sign in as the Agency Admin. BK-105's owner and seller of record are Coral Coast Travel. Withdrawing the package removes it from Dana's home, and her open bookings stay.
