# Vineyard Tour — reference scenario

**Status:** Accepted modeling scenario; source details still require confirmation

**Operating dates represented in the source worksheet:** June 5–7, 2027

## Purpose

This scenario tests whether the same composition model used for a cruise can represent a land package with shared transportation, multiple hotels, inclusions, a required choice, fixed costs, and per-person costs.

## Departure composition

- Motorcoach transportation with a finite seat capacity and fixed vehicle cost.
- Hotel services for the itinerary, with exact hotel/night assignments to be confirmed from the source worksheet.
- Included lunch on June 6 and June 7.
- Included wine tasting on June 6.
- Required dinner choice on June 5:
  - Deluxe Wine Dinner for an additional Client charge; or
  - Standard Dinner included in the package price.
- Package price based on double occupancy.
- Single supplement equal to 100% of the per-person package price under the current example rule.

## Capacity questions exercised

- One motorcoach with a 30-seat capacity.
- Shared capacity whose consumption basis is Traveler positions rather than rooms or cabins.
- Hotel room/night capacity that may vary by date.
- Required-choice capacity where every confirmed Client Trip must select exactly one dinner option.
- Whether additional vehicles are allowed and, if so, how a stepped fixed-cost threshold is represented.

## Commercial questions exercised

- Fixed motorcoach cost spread across projected enrollment for forecasting without inventing a posted allocation.
- Per-person tasting and meal costs.
- Hotel rates by room, night, or occupancy.
- Included versus additional-charge selections.
- Minimum enrollment, break-even enrollment, guarantees, cancellation terms, and Supplier deadlines.
- Package revenue and Supplier cost remaining distinct even when the Client sees one bundled price.

## Source questions to resolve

- Confirm the correct hotel sequence and nights; the rough notes list Hotel A and Hotel B ambiguously.
- Confirm whether motorcoach capacity may be expanded with another vehicle.
- Confirm exact package price, Supplier rates, taxes/fees, minimum enrollment, deposits, and cancellation deadlines.
- Confirm whether dinner options have independent capacity limits.

These unresolved values must not be guessed in implementation fixtures.
