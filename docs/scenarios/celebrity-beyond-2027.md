# Celebrity Beyond group cruise — reference scenario

**Status:** Accepted modeling scenario; not an implementation schema

**Sailing:** Celebrity Beyond, November 6–13, 2027

## Purpose

This scenario tests whether DepartureDesk can compose a group cruise from one mandatory core service and several optional services without introducing cruise-specific subclasses.

## Departure composition

- Mandatory cruise reservation for every participating Client Trip.
- Cabin inventory blocked by category, with category-specific occupancy limits and rates.
- Occupancy-sensitive pricing for first/second Travelers, additional Travelers, and single occupancy.
- Optional pre-stay hotel with an Agency guarantee or minimum commitment and optional extra nights.
- Optional port transfers.
- Optional specialty dining on a specified sailing night.
- Optional island sightseeing on a specified sailing day, potentially including separately sourced admission.
- Optional travel insurance whose eligibility or pricing may use an explicit Household snapshot without inferring eligibility from current Household membership.

## Capacity questions exercised

- Supplier block versus internally available quantity.
- Expiring Client Holds and confirmed Allocations.
- Release of cabins back to the Supplier.
- Category changes and occupancy Assignments without double-counting capacity.
- Supplier cutoffs, deposit dates, final-payment dates, name-list deadlines, and release deadlines.
- Pending Supplier confirmation after Client Trip confirmation when policy permits it.

## Commercial questions exercised

- Supplier cost components that differ by occupancy position.
- Client price, Supplier cost, taxes/fees, discounts, commission, and deposits as distinct facts.
- Required versus optional services.
- Changes after confirmation, including upgrades, substitutions, cancellations, and released capacity.
- One operating currency for the Departure.

Exact cabin categories, quantities, rates, deadlines, and supplier identifiers belong in maintained test fixtures or an accepted scenario-data appendix. They are inputs to this scenario, not universal cruise rules.
