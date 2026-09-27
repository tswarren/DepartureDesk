# ABC Motorcoach 2027 — Canonical Transportation Scenario

## 1. Status and authority

**Status:** Draft. Supplier Composition boundary locked. Not implementation authority.

When accepted, this document supersedes conflicting transportation fixtures. No slice may rely on it until it is Approved and an accepted slice plan names it.

## 2. Purpose

Prove two chartered-transfer occurrences under one agreement, a fixed per-coach Supplier cost, and an on-request ceiling that is not controlled capacity.

## 3. Source classification

Illustrative.

The contract date and Supplier confirmation number are not specified. The agreement does not supply a last date for requesting coaches two or three, a cancellation ladder, a nonrefundable amount, a rescheduling fee, a waiting or overtime rule outside the agreed service, or a payment rule for capacity confirmed after November 3. Those terms remain unresolved and Advanced. DepartureDesk must not infer them from the final-count deadlines.

## 4. Departure facts

| Fact | Canonical value |
| --- | --- |
| Departure | Smith Family Reunion |
| Supplier | ABC Motorcoach |
| Service family | Chartered motorcoach transfers |
| Time zone | America/New_York |
| Contract date | Not specified |
| Supplier confirmation number | Not specified |
| Currency | USD |

## 5. Supplier Arrangement topology

One Transportation Arrangement contains two independently identifiable segment Items. Every route and mutation submits the exact stable segment Item ID.

| Segment | Pickup | Drop-off | Service date/time |
| --- | --- | --- | --- |
| Hotel → Port | Hilton Fort Lauderdale Marina | Port Everglades | November 6, 2027 at 10:00 a.m. |
| Port → Airport | Port Everglades | Fort Lauderdale-Hollywood International Airport | November 13, 2027 at 9:30 a.m. |

The two segments are separate Arrangement Items and Occurrences. Editing, cancelling, or adding capacity to one must not alter the other.

## 6. Resources and capacity

Each motorcoach can carry at most 15 passengers. The driver does not consume passenger capacity.

| Segment | Guaranteed coaches | Guaranteed passenger capacity | Additional coaches | Maximum possible capacity |
| --- | ---: | ---: | --- | ---: |
| Hotel → Port | 1 | 15 passengers | Up to 2, subject to ABC confirmation | 45 passengers |
| Port → Airport | 1 | 15 passengers | Up to 2, subject to ABC confirmation | 45 passengers |

- `15 passengers per motorcoach` is physical unit capacity.
- `1 guaranteed motorcoach` is controlled Supplier capacity for each segment.
- The initial controlled passenger capacity is derived as `1 × 15 = 15`.
- Coaches two and three are on request and do not count as controlled capacity before Supplier confirmation.
- 45 passengers is a ceiling on potentially available capacity, not guaranteed inventory.

When ABC confirms another coach, Staff records an additional confirmed vehicle unit through the shipped capacity authority. The resulting controlled passenger capacity becomes 30 or 45. A planning assumption or expected passenger count must not masquerade as confirmed capacity.

The on-request ceiling is partial coverage of on-request services. It is not a separate fixture.

## 7. Supplier costs

The charter rates are fixed per confirmed motorcoach per segment:

| Confirmed coaches | Hotel → Port | Port → Airport | Combined charter exposure |
| ---: | ---: | ---: | ---: |
| 1 each | $200 | $175 | $375 |
| 2 each | $400 | $350 | $750 |
| 3 each | $600 | $525 | $1,125 |

The number of confirmed coaches may differ by segment. The general formula is:

\[
\text{Segment cost} = \text{confirmed motorcoaches} \times \text{segment rate per motorcoach}
\]

The $200 and $175 rates are all-in charter rates. Driver, fuel, ordinary luggage, gratuity, tolls, parking, airport or port access, waiting within the agreed service, and taxes do not create separate typed components in this fixture.

The rates are Supplier costs, not per-passenger charges. Passenger count does not change the charge until it causes Staff to request and ABC to confirm an additional coach.

## 8. Deposits and deadlines

The entire charter is due November 3, 2027, three days before the Departure's outbound transfer.

The minimum payable amount is:

\[
\$200 + \$175 = \$375
\]

The amount increases for every additional motorcoach ABC has confirmed on either segment by the payment effective point. The summary must show the segment-level derivation rather than only the combined total.

The agreement does not specify how or when to pay for an additional coach confirmed after November 3. That case remains Advanced and requires Supplier clarification. It must not silently reopen or overwrite the settled payment definition.

For MVP, this is a Supplier Deadline and payment-commitment definition only. It does not create a Supplier Payment, Obligation, invoice, or paid status.

Final passenger and luggage counts are due three calendar days before each segment:

| Segment | Count due date | Time |
| --- | --- | --- |
| Hotel → Port | November 3, 2027 | Date only; no contractual cutoff time specified |
| Port → Airport | November 10, 2027 | Date only; no contractual cutoff time specified |

These are two actionable Supplier Deadlines because they cover different segments and occur on different dates. They do not reserve capacity or change confirmed coach quantity by themselves.

Actual traveler manifests and assignments belong to the later Reservation and Client Trip layer. Supplier Composition records the deadline and, when appropriate, evidence that a count was delivered.

## 9. Cancellation terms

Not separately specified. The agreement does not supply a cancellation ladder, a nonrefundable amount, or a rescheduling fee. DepartureDesk must not infer them.

## 10. Expected summaries

```text
TRANSPORTATION SUPPLIER PLANNING

ABC Motorcoach
Smith Family Reunion · Draft · USD

Chartered transfers

Hotel → Port
Nov 6, 2027 at 10:00 a.m.
Hilton Fort Lauderdale Marina → Port Everglades
1 motorcoach guaranteed · 15 passengers
Up to 2 additional coaches on request
$200 per confirmed motorcoach
Final passenger/luggage count due Nov 3

Port → Airport
Nov 13, 2027 at 9:30 a.m.
Port Everglades → Fort Lauderdale-Hollywood International Airport
1 motorcoach guaranteed · 15 passengers
Up to 2 additional coaches on request
$175 per confirmed motorcoach
Final passenger/luggage count due Nov 10

Payment
Minimum charter: $375
Due Nov 3, 2027
Amount increases with additional coaches confirmed by the effective point

Needs clarification
Cancellation terms
Deadline and payment treatment for coaches confirmed after Nov 3
```

## 11. Required proof

Before activation, Staff may independently edit each segment's locations, time, guaranteed coach quantity, on-request ceiling, capacity, rate, and deadlines. A failed edit preserves entered fields and leaves the sibling segment unchanged.

Activation preview is write-free and shows both exact segment Items, one guaranteed 15-passenger coach per segment, two additional coaches available only on request, the $200 and $175 fixed Supplier charges, the derived minimum $375 charter exposure, the November 3 payment commitment, the November 3 and November 10 final-count deadlines, and unresolved cancellation and late-added-coach terms without inventing defaults.

Governing facts are read-only. Successor drafts are labeled proposed. Unsupported segment definitions remain readable and route to an exact Advanced destination without rewriting the supported sibling.

Starting from Departure Composition, Staff must be able to:

1. Open or create the exact ABC Motorcoach Arrangement.
2. Create Hotel → Port and Port → Airport as separate stable segment Items.
3. Confirm that no Airport → Port segment exists.
4. Reopen either segment by Item ID without relying on its label or ordering.
5. Enter the correct locations, dates, and local times.
6. Record one guaranteed coach with 15-passenger unit capacity for each segment.
7. Display two more coaches as on-request rather than controlled capacity.
8. Confirm an additional coach on only one segment and see that segment become 30-passenger controlled capacity without changing its sibling.
9. Enter $200 and $175 fixed per-coach Supplier costs.
10. Preview one-, two-, and three-coach segment exposure without writes.
11. See the minimum combined charter exposure of $375.
12. Create the November 3 charter-payment commitment once.
13. Create separate November 3 and November 10 count deadlines.
14. Record deadline completion without changing coach capacity.
15. Submit an invalid segment edit and confirm the other segment remains unchanged.
16. Preserve unresolved cancellation and late-addition policies as Advanced without silent defaults.
17. View governing facts read-only and successor facts as proposed.
18. Confirm a Viewer receives not found for Transportation management routes.

At least one proof must contain both segments. Database-only construction does not satisfy this exit.

## 12. Explicit exclusions

This scenario ends at Supplier Composition. The summary does not include a Client-service connection step.

- Client transfer choices, per-person Client prices, Package placement, and traveler selections.
- The earlier $27 / $23 / $23 Client figures.
- A Supplier Payment, Obligation, invoice, or paid status.
- Traveler manifests and assignments.

## 13. Superseded facts

- The prior Airport → Port segment is removed.
- The earlier November 11 return date is corrected to November 13.
- The earlier $27 / $23 / $23 Client figures are not Supplier facts and are not carried forward.
