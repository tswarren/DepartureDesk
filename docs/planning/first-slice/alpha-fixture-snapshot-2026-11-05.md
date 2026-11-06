# Alpha fixture — current values (snapshot 2026-11-05)

Gathered from the first-slice charter (fixture amended 2026-11-03, D-87), the Slice 1 step 3 plan, the Product Specification decision log (through D-91, 2026-11-05) and the three Google Docs source documents. All names are fictional; values are test inputs, not supplier terms.

**Authority order:** Product Specification decision log (D-87) → first-slice charter, Fixture section → source Google Docs. The source docs were last edited Oct 29–30, 2026, before D-87, so the open questions they list are now settled (see "Where the source docs are behind"). No decision after D-87 (D-88 to D-91) changes a fixture value.

The older M4 canonical fixtures in `docs/planning/fixtures/` (Celebrity Beyond, Hilton Fort Lauderdale Marina, ABC Motorcoach, etc.) are not the first-slice fixture; the charter replaced them with Alpha.

## Departure

| Field | Value |
| --- | --- |
| Name | Alpha Omega |
| Dates | Nov 6, 2027 4:00 p.m. to Nov 13, 2027 7:00 a.m. |
| Ports | Port Everglades, Fort Lauderdale, round trip |
| Currency / zone | USD; America/New_York |
| Seed | `db/seeds/alpha_fixture.rb` (`AlphaFixture.load!`) |

## Cruise — Alpha Cruises

| Field | Value |
| --- | --- |
| Ship | Alpha Omega |
| Contract date | Oct 1, 2026 (source doc) |
| Block | 8 cabins each in V01 Veranda, O01 Oceanview, I01 Interior (max 3) and S01 Suite (max 4); 32 cabin shells, created only on arrangement confirmation |
| Commission | 14% of base fare before the supplier discount |
| S01 additional guest | Supplier discount waives the base fare |
| Single occupancy | Full single fare: 1st-guest fare plus the supplement; taxes charged once |
| **Agreement A (Slice 1)** | $50/stateroom initial deposit due Nov 1, 2026, credited toward the $500 full deposit, so each booking confirmation posts $450 for its cabin (D-81). Mar 1, 2027 = full-deposit deadline for cabins not yet named. Final payment Aug 1, 2027 |
| **Agreement B (Slice 1b)** | Same 32 cabins, courtesy/option to a Mar 1, 2027 cutoff; no deposit on unallocated space; $500 supplier deposit per confirmed cabin, no initial credit |
| Client deposit | $500 per cabin at booking, both agreements |

### Rate schedule (from the Alpha Cruises source doc)
Per guest, by occupancy position. "1st/2nd" is each of the first two guests; "Additional" is the 3rd/4th guest; a single occupant pays the 1st-guest fare plus the single supplement (B6). Commission = 14% of base fare.

#### V01 — Deluxe Stateroom with Veranda

| Rate component | 1st/2nd | Additional | Single supplement |
| --- | --- | --- | --- |
| Base fare | $3,500.00 | $750.00 | $3,500.00 |
| NCCF | $325.00 | $325.00 | $325.00 |
| Taxes/fees | $135.00 | $135.00 | $0.00 |
| Supplier discount | -$700.00 | $0.00 | -$700.00 |
| Supplier price | $3,260.00 | $1,210.00 | $3,125.00 |
| Supplier commission | $490.00 | $105.00 | $490.00 |
| Supplier net | $2,770.00 | $1,105.00 | $2,635.00 |
| Agency markup | $125.00 | $75.00 | $125.00 |
| Client price | $3,385.00 | $1,285.00 | $3,250.00 |

#### O01 — Deluxe Oceanview Stateroom

| Rate component | 1st/2nd | Additional | Single supplement |
| --- | --- | --- | --- |
| Base fare | $3,000.00 | $600.00 | $3,000.00 |
| NCCF | $325.00 | $325.00 | $325.00 |
| Taxes/fees | $135.00 | $135.00 | $0.00 |
| Supplier discount | -$600.00 | $0.00 | -$600.00 |
| Supplier price | $2,860.00 | $1,060.00 | $2,725.00 |
| Supplier commission | $420.00 | $84.00 | $420.00 |
| Supplier net | $2,440.00 | $976.00 | $2,305.00 |
| Agency markup | $125.00 | $75.00 | $125.00 |
| Client price | $2,985.00 | $1,135.00 | $2,850.00 |

#### I01 — Deluxe Interior Stateroom

| Rate component | 1st/2nd | Additional | Single supplement |
| --- | --- | --- | --- |
| Base fare | $2,500.00 | $450.00 | $2,500.00 |
| NCCF | $325.00 | $325.00 | $325.00 |
| Taxes/fees | $135.00 | $135.00 | $0.00 |
| Supplier discount | -$500.00 | $0.00 | -$500.00 |
| Supplier price | $2,460.00 | $910.00 | $2,325.00 |
| Supplier commission | $350.00 | $63.00 | $350.00 |
| Supplier net | $2,110.00 | $847.00 | $1,975.00 |
| Agency markup | $125.00 | $75.00 | $125.00 |
| Client price | $2,585.00 | $985.00 | $2,450.00 |

#### S01 — Deluxe Suite

| Rate component | 1st/2nd | Additional | Single supplement |
| --- | --- | --- | --- |
| Base fare | $5,500.00 | $1,000.00 | $5,500.00 |
| NCCF | $325.00 | $325.00 | $325.00 |
| Taxes/fees | $135.00 | $135.00 | $0.00 |
| Supplier discount | -$1,000.00 | -$1,000.00 | -$1,000.00 |
| Supplier price | $4,960.00 | $460.00 | $4,825.00 |
| Supplier commission | $770.00 | $140.00 | $770.00 |
| Supplier net | $4,190.00 | $320.00 | $4,055.00 |
| Agency markup | $125.00 | $75.00 | $125.00 |
| Client price | $5,085.00 | $535.00 | $4,950.00 |


## Hotel — Sablewater Harbor Hotel, Fort Lauderdale (fictional)

Also the excursion pickup point. Supplier test rates come from the Seabreeze Inn travel-agent allotment (Agreement C) in the hotel model-agreements doc; the hotel itself is fictional (B4).

| Night | Garden Queen | Harbor Double | Promise | Inventory groups |
| --- | --- | --- | --- | --- |
| Nov 5, 2027 (included night) | 4 | 4 | Firm, unit shells | 2 |
| Nov 4, 2027 | 2 | 1 | Firm, capacity pools | 2 |
| Nov 1, 2, 3, 2027 | — | — | On request, no numeric balance | 6 |
| **Total** | | | | **10 groups** |

| Term | Value |
| --- | --- |
| Supplier rate | $145 Garden Queen, $175 Harbor Double per room-night |
| Committed cost | Firm rooms entered as committed cost: $1,280 for Nov 5, $465 for Nov 4 |
| Payment | Paid in full at checkout, Nov 6, 2027 (B14) |
| Client price | Per traveler by occupancy position: 1st guest in a room pays $190 Garden Queen or $220 Harbor Double per night; other guests $0. Same for the included night and extension nights (B5) |

## Excursion — Shore Excursions Group

| Term | Value |
| --- | --- |
| Product | Private Miami City Highlights Half Day Your Way from Fort Lauderdale (Hotel Guests), code CAFTPVTMIAFTLAUD, listing 61094 |
| Occurrence | Nov 5, 2027, 2:00–6:30 p.m. local; pickup/drop-off at the package hotel |
| Unit | $1,000 per resource (all fees included except gratuity), 10 traveler positions each |
| Opening | One resource confirmed at start, entered as committed cost (B8); more only on supplier confirmation |
| Children | Ages 0–4 free, counted in headcount, use no position |
| Final count | Oct 22, 2027 at 11:59 p.m. agency time (B9) |
| Payment | $1,000 per confirmed resource due with the final count (B13) |
| Client price | $150 per participating traveler; children 0–4 free |

## Supplier deadlines (Agreement A, step 3b)

| Deadline | Due |
| --- | --- |
| Alpha Cruises initial deposit | Nov 1, 2026 |
| Alpha Cruises full deposit and names | Mar 1, 2027 |
| Alpha Cruises final payment | Aug 1, 2027 |
| Excursion final count | Oct 22, 2027, 11:59 p.m. America/New_York |
| Excursion payment | Oct 22, 2027 |
| Hotel payment at checkout | Nov 6, 2027 |
| Option cutoff (Agreement B, 1b) | Mar 1, 2027 |

Each creates a task owned by the Departure's default task owner.

## Sample roster

| Booking | Slice | Cabin | Travelers | Excursion participants | Positions used | Cruise client subtotal | Hotel request |
| --- | --- | --- | --- | --- | ---: | ---: | --- |
| BK-101 Rowan | 1 | V01 | 3 | 3 | 3 | $8,055 | Garden Queen from Nov 4 |
| BK-104 Bennett | 1 | S01 | 4, incl. Milo (2) | 4 | 3 | $11,240 | Harbor Double from Nov 2 |
| BK-105 Rivera | 1, via the reseller | O01 | 3, incl. Luca (3) | 2; Elena opts out | 1 | $7,105 | Garden Queen, Nov 5 only |
| BK-102 Mercer | 1b | O01 | 2 | 2 | 2 | $5,970 | Harbor Double, Nov 5 only |
| BK-103 Ellis | 1b | I01 | 1 | 1 | 1 | $5,035 | Garden Queen from Nov 3 |
| **All five** | | | **13** | **12** | **10** | **$37,405** | |

Slice 1's three bookings: 9 participants, 7 of 10 positions, $26,400 cruise subtotal. All five: 12 participants fill all 10. Elena opting in (1b) pushes demand to 11 and needs a second $1,000 resource: client revenue $1,650 vs supplier cost $2,000.

## Where the source docs are behind

The Google Docs still list these as open; D-87 settled them:

- **Alpha Cruises doc:** whether the $50 is credited toward $500 (yes); what Mar 1 means (A: full-deposit deadline for unnamed cabins; B: option cutoff only); single-occupancy and commission basis (settled as above); Agreement B deposit on named cabins ($500, no initial credit).
- **Shore Excursions doc:** final-count cutoff time (11:59 p.m. agency time); resources initially confirmed (one); payment terms ($1,000 per resource due with the final count); exact pickup hotel (Sablewater Harbor Hotel).
- **Hotel doc:** describes Harborlight, Seabreeze courtesy and Seabreeze allotment scenarios only; the Sablewater Harbor Hotel block, client prices and checkout payment exist only in the charter/D-87.

Still unresolved in the fixture: group creation date and group number (cruise), the names-submission deadline beyond Mar 1, cancellation/attrition terms, and gratuity.

## Sources

- `docs/planning/first-slice/first-slice-charter.md` — Fixture section
- `docs/planning/first-slice/slice-1-step-3-plan.md` — Alpha fixture subsections
- DepartureDesk Product Specification, Decision log D-87: https://docs.google.com/document/d/1qdqOTMWcSWClAojGeB8NsYYunzJlTDcmgXp_S1Se-CQ/edit
- Alpha Cruises Group Agreement Scenarios: https://docs.google.com/document/d/1CQbooQrrVxZSyyPFkz4v2yR40zXSfF_2Mxn1eeod-BQ/edit
- Shore Excursions Group — Private Miami Activity Agreement Model: https://docs.google.com/document/d/1zZsVVCqpk3g6X-nh8_O3LM4Pyz6W7lpp5ov53C-xBVA/edit
- Hotel Group Space — Model Agreements for Walkthrough Testing: https://docs.google.com/document/d/1-kh8yYRilvhPg8AZI87Wzc1VPK3WGlPEayeCg6edS48/edit
