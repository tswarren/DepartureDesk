# Supplier Composition fixtures

This register is the index of business fixtures used to plan Supplier Composition. A fixture records facts and the behavior those facts must prove. It is not an implementation plan and it does not authorize code.

**Status words:** Draft, Approved, Superseded. Hilton Fort Lauderdale Marina is Approved. The other scenarios remain Draft. A Draft fixture does not authorize an implementation slice. An Approved fixture still does not authorize code until an accepted slice plan names the facts it uses.

Shipped Cruise slices keep their own contracts. This register does not reopen them. No unaccepted slice may rely on a Draft fixture. An accepted slice may cite a Draft fixture only for the facts that slice names. That citation does not Approve the fixture.

Behavior coverage is [the proof matrix](supplier-composition-proof-matrix.md).

## Celebrity Beyond

| Field | Value |
| --- | --- |
| Canonical file | [celebrity-beyond-2027-canonical-scenario-draft.md](celebrity-beyond-2027-canonical-scenario-draft.md) |
| Status | Draft |
| Facts | Source-qualified July 2025 Celebrity Groups brochure, plus the agency's 15% commission rule. Client totals in that source are illustrative. |
| Layer | Supplier Composition. Shipped Cruise Offer Design is recorded only as an exclusion. |
| Proves | Controlled cabin inventory, occupancy-position Supplier components, and a cumulative initial deposit across cabin pools. |
| Supersedes | Earlier Celebrity Beyond fixture facts, illustrative amounts, and proof assumptions that conflict with this file. |
| Unresolved | The O1 Single discount does not explain the stated vacation total. The DI third-passenger stated gross does not follow the displayed base and NCCF. Both stay visible until a later source correction. |
| Slices that may rely on it | The accepted [Sailing ports and commercial benefits](../m4d1-cruise-ports-and-commercial-benefits.md) slice may cite blank ports, optional itinerary notes, benefit wording, the optional citation, and Departure operating currency. That citation does not Approve this fixture and does not authorize deposits, deadlines, Offer Design, or the rest of the Cruise rework. |

## Hilton Fort Lauderdale Marina

| Field | Value |
| --- | --- |
| Canonical file | [hilton-fort-lauderdale-marina-2027-canonical-scenario-draft.md](hilton-fort-lauderdale-marina-2027-canonical-scenario-draft.md) |
| Status | Approved 2026-09-27 |
| Facts | Hilton agreement scenario for the Smith Family Reunion stay. This registered file is the only Hotel canonical fixture. Its commercial terms are the Approved scenario decisions. |
| Layer | Supplier Composition. |
| Proves | Nightly room blocks that vary by date, occupancy-position room rates, percentage deposits on contracted room revenue, draft/governing/successor behavior, and a second Hotel Item under the same Arrangement. |
| Supersedes | The discarded Hilton walkthrough and its simplified stay. |
| Unresolved | Contract/signature date and Hotel group or confirmation number. Both stay blank. |
| Walkthrough | [Hilton Staff journey](../m4d1-hilton-hotel-staff-walkthrough.md) is Accepted 2026-09-27. It chooses no Hotel Client Service connection in Supplier Composition. |
| Slices that may rely on it | An accepted Slice 3A plan may name these facts. Approval does not authorize Hotel code. |

## ABC Motorcoach

| Field | Value |
| --- | --- |
| Canonical file | [abc-motorcoach-2027-canonical-transportation-scenario-draft.md](abc-motorcoach-2027-canonical-transportation-scenario-draft.md) |
| Status | Draft |
| Facts | Illustrative. |
| Layer | Supplier Composition. |
| Proves | Two transportation occurrences under one agreement, a fixed per-coach cost, and an on-request ceiling that is not controlled capacity. |
| Supersedes | The Airport to Port segment, the November 11 return date, and the earlier $27 / $23 / $23 Client figures. |
| Unresolved | Contract date, confirmation number, cancellation terms, and payment treatment for a coach confirmed after November 3. |
| Slices that may rely on it | None until this fixture is Approved and an accepted slice plan names it. |

The on-request ceiling of two additional coaches is partial coverage of on-request services. It is not a reason to add another fixture.

## Port Promotions

| Field | Value |
| --- | --- |
| Canonical file | [port-promotions-island-sightseeing-2027-canonical-scenario.md](port-promotions-island-sightseeing-2027-canonical-scenario.md) |
| Status | Draft |
| Facts | Illustrative. |
| Layer | Supplier Composition. |
| Proves | A per-participant Activity cost with a controlled maximum and an operating minimum that is not a guaranteed charge. |
| Supersedes | Previously written Island Sightseeing fixture facts, including a $57.50 Client price. |
| Unresolved | Contract date, confirmation number, and the exact port meeting point. |
| Slices that may rely on it | None until this fixture is Approved and an accepted slice plan names it. |

## Empire City DMC

| Field | Value |
| --- | --- |
| Canonical file | [empire-city-dmc-autumn-in-new-york-2027-canonical-scenario.md](empire-city-dmc-autumn-in-new-york-2027-canonical-scenario.md) |
| Status | Draft |
| Facts | Illustrative. |
| Layer | Supplier Composition. |
| Proves | One agreement spanning several service Items, with shared deposit, deadline, and cancellation terms that name their contributors. |
| Supersedes | Any reading that treats this program as one undifferentiated Item or as five independent Arrangements. |
| Unresolved | Signing date, deposit due date, final-balance date, restaurant, Broadway production and theater, tour endpoints, dinner inclusions, and any force-majeure exception. |
| Slices that may rely on it | None until this fixture is Approved and an accepted slice plan names it. |

## Wine Country Tour

| Field | Value |
| --- | --- |
| Canonical file | [wine-country-tour-2027-canonical-supplier-fixture.md](wine-country-tour-2027-canonical-supplier-fixture.md) |
| Status | Draft |
| Facts | Illustrative. |
| Layer | Supplier Composition. |
| Proves | One Departure coordinating five independent Supplier Arrangements, including a complimentary Hotel room, a guaranteed dinner minimum, and a per-day tour director. |
| Supersedes | Earlier Wine Country Tour facts that conflict with this file, including any shared DMC-level deposit or cancellation policy. |
| Unresolved | None that block the stated proof. Personal expenses and gratuities for the tour director are excluded from the Supplier cost. |
| Slices that may rely on it | None until this fixture is Approved and an accepted slice plan names it. |

## Superseded

| Field | Value |
| --- | --- |
| File | [../history/m4d1-slice3-a-hotel.md](../history/m4d1-slice3-a-hotel.md) |
| Status | Superseded |
| What it was | An earlier Hilton walkthrough: November 2–5, a flat block of 10 Standard and 5 Deluxe, $225 and $275 rates, a 15% signing deposit, Client Service connection, Client choices, `hotel_room:` keys, and optional-add-on treatment. |
| Replacement | [Hilton Fort Lauderdale Marina](hilton-fort-lauderdale-marina-2027-canonical-scenario-draft.md). |
| Slices that may rely on it | None. |

## Deferred proofs

Create another business fixture only when an accepted slice needs a behavior that none of these six can prove. These proofs are not covered:

- Air or rail.
- Travel insurance.
- Guides without controlled capacity.
- Externally managed inventory.
- Multiple currencies.
- Supplier changes after activation.

Variable nightly Hotel blocks are not deferred. Hilton Fort Lauderdale already states them.
