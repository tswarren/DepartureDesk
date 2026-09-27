# Empire City DMC — Autumn in New York 2027 Canonical Mixed-DMC Scenario

## 1. Status and authority

**Status:** Draft. Not implementation authority.

This document supersedes any reading that treats the program as one undifferentiated Item or as five independent Arrangements. No slice may rely on it until it is Approved and an accepted slice plan names it.

## 2. Purpose

Prove that one Supplier Arrangement can contain several independently identifiable service families while also carrying selected cross-Item commercial terms.

## 3. Source classification

Illustrative. The contract or signing date and Supplier confirmation number have not been supplied. The signing date must be entered before a signing-relative deposit or cancellation term can become activation-ready.

These facts remain unresolved and must be supplied before implementation treats the fixture as activation-complete:

- contract or signing date;
- signing-deposit calendar due date or authoritative relative anchor;
- final balance due date;
- restaurant name and address;
- Broadway production and theater;
- tour pickup and return points;
- dinner inclusions, taxes, and gratuity treatment; and
- any force-majeure or Supplier-cancellation exception to the cancellation ladder.

Their absence must be visible. The system must not fabricate them.

## 4. Departure facts

| Fact | Value |
| --- | --- |
| Departure | Autumn in New York |
| Supplier | Empire City DMC |
| Destination | New York City |
| Program dates | October 15–17, 2027 |
| Duration | Three days |
| Time zone | America/New_York |
| Illustrative group size | 30 travelers |
| Currency | USD |

The illustrative expected group size is 30. It is a planning assumption, not the capacity of every Item.

## 5. Supplier Arrangement topology

One Empire City DMC Supplier Arrangement contains four stable Arrangement Items:

1. Full-day Manhattan tour.
2. Group dinner.
3. Broadway show.
4. On-site coordinator.

These are not four Supplier Arrangements and they are not one generic bundled Item. Each Item retains its own identity, Occurrence, capacity meaning, costs, and operational summary. Arrangement-wide terms may cover several Items by explicit coverage or contributor identity.

All times are local to `America/New_York`.

| Date | Item | Scheduled occurrence |
| --- | --- | --- |
| October 15, 2027 | On-site coordinator | 9:00 a.m.–5:00 p.m. |
| October 16, 2027 | On-site coordinator | 8:00 a.m.–11:00 p.m. |
| October 16, 2027 | Full-day Manhattan tour | 9:00 a.m.–4:00 p.m. |
| October 16, 2027 | Group dinner | 5:30 p.m.–7:00 p.m. |
| October 16, 2027 | Broadway show | 8:00 p.m.–10:30 p.m. |
| October 17, 2027 | On-site coordinator | 9:00 a.m.–1:00 p.m. |

The coordinator is one stable Item with three daily Occurrences, not three Items and not one continuous 54-hour Occurrence.

Every Item is loaded and edited by its stable Arrangement Item ID. Every Occurrence is addressed by its stable Occurrence ID. Renaming the Group dinner or Broadway show does not create a new Item.

## 6. Resources and capacity

| Item | Supplier-controlled capacity | Meaning |
| --- | ---: | --- |
| Full-day Manhattan tour | 40 participant spaces | One reserved coach can carry at most 40 participants. |
| Group dinner | 35 seats | The restaurant has reserved up to 35 group seats. |
| Broadway show | 30 tickets | Exactly 30 tickets are held for the group. Additional tickets are not guaranteed. |
| On-site coordinator | Not capacity-applicable | Coordinator coverage is a service over time, not participant inventory. |

The three participant-based Items have separate controlled Pools because the Supplier can change or release their quantities independently. The coordinator must explicitly be classified as capacity-not-applicable. Capacity Pools are addressed by their stable IDs, never by labels or record order.

## 7. Supplier costs

### Full-day Manhattan tour

| Component | Calculation | Amount |
| --- | --- | ---: |
| Private coach | Fixed | $1,800.00 |
| Licensed guide | Fixed | $650.00 |

The two components are independently identifiable even though they cover the same tour Item and Occurrence. Updating the guide cost does not replace or duplicate the coach component.

### Group dinner

```text
$95.00 per confirmed participant
```

The amount is one contracted per-person Supplier charge. The exact inclusions have not been supplied and must not be inferred.

### Broadway show

```text
$150.00 per confirmed ticket
```

The quantity is confirmed tickets, ordinarily matching confirmed participants. Unused guaranteed tickets remain subject to the cancellation terms rather than silently disappearing from the Supplier cost.

### On-site coordinator

```text
$500.00 per coordinator service day
```

The contracted schedule contains three coordinator days, producing a fixed illustrative coordinator amount of $1,500. The differing daily hours do not change the daily rate.

At 30 confirmed travelers, the write-free preview is:

| Component | Calculation | Amount |
| --- | ---: | ---: |
| Tour coach | Fixed | $1,800.00 |
| Tour guide | Fixed | $650.00 |
| Group dinner | 30 × $95 | $2,850.00 |
| Broadway tickets | 30 × $150 | $4,500.00 |
| On-site coordinator | 3 days × $500 | $1,500.00 |
| **Illustrative Supplier total** |  | **$11,300.00** |

This preview is not an invoice, Supplier Payment, Client price, Package total, Obligation, or persisted total.

## 8. Deposits and deadlines

The signing deposit is **25% of selected tour, dinner, and show Supplier-cost components**.

The contributor set contains exactly:

- Private coach.
- Licensed guide.
- Group dinner.
- Broadway tickets.

It excludes the on-site coordinator and any later cost unless Staff explicitly amend the contributor set.

At the illustrative 30-traveler quantity:

| Contributor | Amount |
| --- | ---: |
| Tour coach and guide | $2,450.00 |
| Group dinner | $2,850.00 |
| Broadway tickets | $4,500.00 |
| **Deposit base** | **$9,800.00** |
| **Signing deposit: 25%** | **$2,450.00** |

The durable Deposit Requirement stores the percentage, exact contributor identities, cross-Item coverage, and timing rule. It does not store the illustrative $2,450 result as authoritative truth.

The deposit is due at signing. Because the signing date is not yet supplied, the fixture remains incomplete for activation until Staff enter an authoritative fixed date or a shipped signing-relative timing rule with its anchor.

The signing deposit retains exact contributor IDs across all three covered Items. Adding a new coordinator cost does not automatically expand the deposit base. Removing a contributing component is blocked until the deposit definition is reconciled.

The final participant count is due **September 15, 2027**, 30 calendar days before the program begins. It covers the tour, the dinner, and the Broadway show. It does not create a participant quantity for the coordinator Item.

The final count is one Arrangement-wide operational action with explicit Item coverage. It must not be cloned into three indistinguishable deadlines merely because three Items consume the result. Changes after the final-count deadline are subject to Supplier acceptance and the cancellation policy. The fixture does not promise that capacity can be added after September 15.

The final balance due date has not been supplied.

## 9. Cancellation terms

One cancellation ladder applies across all four Items:

| Cancellation effective date | Cancellation charge |
| --- | ---: |
| From contract signing through August 15, 2027 | 25% of contracted Arrangement charges |
| August 16–September 14, 2027 | 50% of contracted Arrangement charges |
| September 15, 2027 onward | 100% of contracted Arrangement charges |

The cancellation base includes the then-applicable contracted charges for the tour coach, the tour guide, group dinner, Broadway tickets, and all three coordinator days.

At the illustrative 30-traveler amount of $11,300, the example charges are:

| Tier | Illustrative charge |
| ---: | ---: |
| 25% | $2,825.00 |
| 50% | $5,650.00 |
| 100% | $11,300.00 |

These totals are illustrative evaluations, not persisted cancellation fees. The applicable base must be evaluated from the authoritative contracted components and quantities at the cancellation event.

Cancellation of the Arrangement is not the same as cancelling or removing one Item. Item-level reductions or substitutions require Supplier approval and explicit reconciliation. They must not silently invoke, bypass, or rewrite the Arrangement-wide ladder.

## 10. Expected summaries

```text
EMPIRE CITY DMC

Autumn in New York
New York City · October 15–17, 2027 · 30 travelers expected

Services

Full-day Manhattan tour
October 16 · 9:00 a.m.–4:00 p.m.
40 controlled participant spaces
Coach $1,800 fixed · Guide $650 fixed

Group dinner
October 16 · 5:30–7:00 p.m.
35 reserved seats · $95 per confirmed participant
Venue details needed

Broadway show
October 16 · 8:00–10:30 p.m.
30 guaranteed tickets · $150 per confirmed ticket
Production and theater details needed

On-site coordinator
October 15–17 · 3 service days
$500 per day · $1,500 illustrative amount

Shared terms

Signing deposit
25% of tour, dinner, and Broadway components
Illustrative opening amount: $2,450
Due date incomplete until signing date is entered

Final participant count
September 15, 2027
Covers tour, dinner, and Broadway show

Cancellation
25% from signing · 50% beginning August 16
100% beginning September 15
Applies across all four services
```

## 11. Required proof

A later mixed-DMC orchestration walkthrough should prove through the browser that Staff can:

1. Create one Empire City DMC Supplier Arrangement.
2. Create and reopen all four Items by stable Item ID.
3. Create three daily Occurrences for the same coordinator Item.
4. Classify tour, dinner, and show as separately controlled participant capacity.
5. Classify coordinator coverage as capacity-not-applicable.
6. Save the two independent fixed tour components.
7. Save the dinner and show per-participant components.
8. Save the coordinator per-day component.
9. Preview the $11,300 illustrative Supplier total without writing records.
10. Create one 25% Deposit Requirement using the four exact selected contributor IDs across three Items.
11. Preview the $2,450 opening deposit.
12. Prove that the coordinator remains outside the deposit base.
13. Create one September 15 final-count deadline with explicit coverage of three Items.
14. Preserve one Arrangement-wide cancellation ladder across all four Items.
15. Rename or edit one Item or component without changing its stable identity.
16. Submit an invalid sibling change without losing previously saved work.
17. Keep unsupported terms readable and unchanged.
18. Expose the missing signing date, restaurant, theater or production, tour endpoints, and final-balance deadline rather than inventing them.

A failed change to one Item leaves compatible sibling Items unchanged. Governing facts are read-only and successor facts are labeled proposed. Unsupported terms remain readable and link to Advanced without being rewritten.

## 12. Explicit exclusions

- Client prices for any Item.
- Package inclusion or optional-add-on placement.
- Service Offer connection or Client choice graphs.
- Client Trip participation or bookings.
- Actual invoices, Supplier Payments, Obligations, or paid state.
- Automatic creation of cancellation fees.
- Treating the DMC Arrangement as one undifferentiated service Item.
- A universal adapter inferred merely because several families share commands.

## 13. Superseded facts

Any earlier reading that collapses these four Items into one undifferentiated service, or that splits them into five independent Supplier Arrangements, is superseded.
