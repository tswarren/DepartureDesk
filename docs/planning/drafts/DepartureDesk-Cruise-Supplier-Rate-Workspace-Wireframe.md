# DepartureDesk — Cruise Supplier Rate Workspace Wireframe

**Status:** Implementation guide only under Accepted [M4D.1 Slice 2A.2R](../m4d1-slice2a2r-cruise-supplier-rate-matrix.md). Not competing product authority.

**Purpose:** Enter and review one cabin category's Supplier rate schedule as a matrix without exposing the underlying Supplier cost graph.

**Example context:** Smith Family Cruise → Celebrity Beyond → O1 Prime Oceanview.

**Smith acceptance amounts (canonical):** First/Second Base Fare $1,624 and Discount −$150; Additional Base Fare $406 and Discount −$37.50; Every Traveler NCCF $320 and Taxes & Fees $137; Single Supplement Base Fare $1,624. Gross Single / Double / Triple $3,555.00 / $3,862.00 / $4,687.50. Commission and net remain Pending (no invented Celebrity commission rate).

---

## Desktop wireframe

```text
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ ← Cruise setup                                      Draft successor · Contracted terms        │
│                                                                                              │
│ O1 · Prime Oceanview                                                                         │
│ Celebrity Beyond · November 6–13, 2027 · Maximum occupancy 3                                │
│                                                                                              │
│ [Save for later]                                         [Advanced cost planning ↗]          │
└──────────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ SUPPLIER RATE SCHEDULE                                                                       │
│ Add the rate profiles shown on the Supplier agreement. Each selected profile becomes a      │
│ column in the schedule.                                                                      │
│                                                                                              │
│ Rate profiles                                                                                │
│                                                                                              │
│ ☑ First/Second    ☑ Additional    ☑ Every Traveler    ☐ Child    ☑ Single Supplement       │
│                                                                                              │
│ [+ Add rate profile]                                                                         │
│                                                                                              │
│ Added profiles                                                                               │
│ ┌──────────────────────────────┬──────────────────────────┬──────────────────────┬──────────┐ │
│ │ Profile                      │ Traveler category        │ Applies to           │          │ │
│ ├──────────────────────────────┼──────────────────────────┼──────────────────────┼──────────┤ │
│ │ First/Second                 │ —                        │ Positions 1–2        │ [Edit]   │ │
│ │ Additional                   │ —                        │ Positions 3+         │ [Edit]   │ │
│ │ Every Traveler               │ —                        │ Each traveler        │ [Edit]   │ │
│ │ Single Supplement            │ —                        │ Single cabin         │ [Edit]   │ │
│ └──────────────────────────────┴──────────────────────────┴──────────────────────┴──────────┘ │
│                                                                                              │
│ ⚠ Overlapping profiles are added together. DepartureDesk will flag combinations that may    │
│   charge the same traveler twice.                                                            │
└──────────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ RATE COMPONENTS                                                                              │
│ Blank means pending. Enter 0.00 when the Supplier has confirmed a zero amount.               │
│                                                                                              │
│ ┌──────────────────┬───────────────┬──────────────┬────────────────┬────────────────────────┐ │
│ │ Component        │ First/Second  │ Additional   │ Every Traveler │ Single Suppl.          │ │
│ ├──────────────────┼───────────────┼──────────────┼────────────────┼────────────────────────┤ │
│ │ Base Fare        │ $ [ 1,624.00] │ $ [  406.00] │ $ [          ] │ $ [         1,624.00]  │ │
│ │ NCCF             │ $ [         ] │ $ [        ] │ $ [    320.00] │ $ [                ]  │ │
│ │ Taxes & Fees     │ $ [         ] │ $ [        ] │ $ [    137.00] │ $ [                ]  │ │
│ │ Discount         │−$ [   150.00] │−$ [   37.50] │−$ [          ] │−$ [                ]  │ │
│ ├──────────────────┼───────────────┼──────────────┼────────────────┼────────────────────────┤ │
│ │ Fuel supplement  │ $ [         ] │ $ [        ] │ $ [          ] │ $ [                ]  │ │
│ │ Supplier charge ▾│               │              │                │                  [×]    │ │
│ ├──────────────────┼───────────────┼──────────────┼────────────────┼────────────────────────┤ │
│ │ Profile subtotal │    $1,474.00  │     $368.50  │       $457.00  │            $1,624.00  │ │
│ └──────────────────┴───────────────┴──────────────┴────────────────┴────────────────────────┘ │
│                                                                                              │
│ [+ Add component]                                                                            │
│                                                                                              │
│ Add-component row                                                                            │
│ Description [____________________________]   Kind [Supplier charge ▾]   [Add] [Cancel]       │
│                                                                                              │
│ Supported here: simple Supplier charges and credits.                                         │
│ Percentages, minimums, tiers, or conditional formulas use [Advanced cost planning].          │
└──────────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ EXPECTED COMMISSION                                                                          │
│                                                                                              │
│ How is commission stated?     ( ) Percentage     ( ) Dollar amount     (●) Not provided yet │
│                                                                                              │
│ Commission and net remain Pending until a method and amounts are provided.                   │
│ Gross Supplier-cost illustrations stay visible while commission is Pending.                  │
└──────────────────────────────────────────────────────────────────────────────────────────────┘

When “Percentage” is selected, show per-cell base selection and either shared percentage
(one component, one rounding boundary) or profile-specific percentages:

┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ Expected commission · Percentage                                                             │
│                                                                                              │
│ Which amounts affect the commissionable base?                                                │
│ Checked charges are added. Checked credits are subtracted.                                   │
│                                                                                              │
│ ┌──────────────────┬───────────────┬──────────────┬────────────────┬────────────────────────┐ │
│ │ Component        │ First/Second  │ Additional   │ Every Traveler │ Single Suppl.          │ │
│ ├──────────────────┼───────────────┼──────────────┼────────────────┼────────────────────────┤ │
│ │ Base Fare        │      ☑        │      ☑       │       ☐        │        ☑               │ │
│ │ NCCF             │      ☐        │      ☐       │       ☐        │        ☐               │ │
│ │ Taxes & Fees     │      ☐        │      ☐       │       ☐        │        ☐               │ │
│ │ Discount         │ ☑ subtract    │ ☐ ignore     │       ☐        │        ☐               │ │
│ └──────────────────┴───────────────┴──────────────┴────────────────┴────────────────────────┘ │
│                                                                                              │
│ ☑ Use the same commission rate for every profile       Rate [ ____ ] %                      │
│                                                                                              │
│ [ ] I reviewed which rate entries affect commission.                                         │
└──────────────────────────────────────────────────────────────────────────────────────────────┘

When “Dollar amount” is selected, replace the percentage controls with one amount per profile:

┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ Expected commission · Dollar                                                                 │
│ ┌──────────────────┬───────────────┬──────────────┬────────────────┬────────────────────────┐ │
│ │                  │ First/Second  │ Additional   │ Every Traveler │ Single Suppl.          │ │
│ ├──────────────────┼───────────────┼──────────────┼────────────────┼────────────────────────┤ │
│ │ Dollar amount    │ $ [         ] │ $ [        ] │ $ [          ] │ $ [                ]  │ │
│ └──────────────────┴───────────────┴──────────────┴────────────────┴────────────────────────┘ │
│ These amounts use the applicability of their rate-profile columns.                           │
└──────────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ OCCUPANCY ILLUSTRATIONS                                                       [Edit mixes]   │
│ Per-cabin illustrations only. They do not create forecast assumptions.                        │
│                                                                                              │
│ ┌────────────────────────────┬─────────────────────┬─────────────────┬──────────────────────┐ │
│ │ Illustration               │ Gross Supplier cost │ Commission      │ Net after commission │ │
│ ├────────────────────────────┼─────────────────────┼─────────────────┼──────────────────────┤ │
│ │ Single Adult               │          $3,555.00  │        Pending  │              Pending │ │
│ │ Double Adult               │          $3,862.00  │        Pending  │              Pending │ │
│ │ Two Adults + Additional    │          $4,687.50  │        Pending  │              Pending │ │
│ └────────────────────────────┴─────────────────────┴─────────────────┴──────────────────────┘ │
│                                                                                              │
│ Values update as rate or commission fields change. Server-calculated values govern on save. │
└──────────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ FORECAST OCCUPANCY PLAN                                                                      │
│ Optional. Record expected cabin counts only when the mix is known.                            │
│                                                                                              │
│ ┌────────────────────────────┬──────────────────────────────┬────────────────┬──────────────┐ │
│ │ Occupancy profile          │ Traveler positions           │ Expected cabins│              │ │
│ ├────────────────────────────┼──────────────────────────────┼────────────────┼──────────────┤ │
│ │ Single Adult               │ Adult                        │ [          1 ] │ [Remove]     │ │
│ │ Double Adult               │ Adult · Adult                │ [          5 ] │ [Remove]     │ │
│ │ Two Adults + Additional    │ Adult · Adult · Adult        │ [          2 ] │ [Remove]     │ │
│ └────────────────────────────┴──────────────────────────────┴────────────────┴──────────────┘ │
│                                                                                              │
│ [+ Add occupancy profile]                                      [Save occupancy plan]          │
│                                                                                              │
│ Combined forecast: 8 cabins · 15 travelers · Gross (known) · Commission/net Pending          │
└──────────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ READINESS                                                                                    │
│ ● Working                                                                                    │
│                                                                                              │
│ Needs attention                                                                              │
│ • Confirm which components affect commission, or leave commission not provided.              │
│ • Confirm that blank Supplier terms are not applicable.                                      │
│                                                                                              │
│ [Save Supplier terms]   [Keep working]   [Review and mark forecast-ready →]                  │
│                                                                                              │
│ Saving terms does not require an occupancy forecast or Client prices.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Add rate profile interaction

```text
┌──────────────────────────────────────────────────────────────┐
│ Add rate profile                                             │
│                                                              │
│ Start with                                                   │
│ (●) First/Second      ( ) Additional      ( ) Every Traveler│
│ ( ) Every Cabin       ( ) Single cabin    ( ) Traveler type │
│ ( ) Other supported profile                                  │
│                                                              │
│ Profile name       [ Child Additional____________________ ]  │
│ Traveler category [ Child (ages 2–11)___________________ ]  │
│ Applies per        [ Traveler ▾ ]                            │
│ Positions          [ Third and later ▾ ]                    │
│                                                              │
│ ⚠ “Child (ages 2–11)” is a planning label in this slice;    │
│   DepartureDesk does not yet match traveler birth dates.     │
│                                                              │
│                                           [Cancel] [Add]     │
└──────────────────────────────────────────────────────────────┘
```

On add:

1. The new profile appears as a matrix column.
2. Every static component receives a blank cell in that column.
3. Every manually added component receives a blank cell in that column.
4. The commission table receives a corresponding column when commission is percentage or dollar.
5. Readiness is cleared if previously confirmed.

If the new profile overlaps an existing profile, require Staff to review the overlap before saving:

```text
Child Additional and Additional can both match position 3.

Choose how the standard Additional profile applies:
(●) Adults only
( ) Every traveler, including children
( ) Return and edit the profiles
```

---

## Add component interaction

```text
┌──────────────────────────────────────────────────────────────────┐
│ Add rate component                                               │
│                                                                  │
│ Description   [ Port transfer fee____________________________ ]  │
│ Kind          [ Supplier charge ▾ ]                              │
│                                                                  │
│ This adds one row with a value field for every rate profile.     │
│                                                                  │
│ Supported: simple charges and credits.                           │
│ Use advanced planning for percentages, minimums, or conditions.  │
│                                               [Cancel] [Add row] │
└──────────────────────────────────────────────────────────────────┘
```

Changing the kind updates every cell prefix in the row:

- Supplier charge → `$`
- Supplier credit → `−$`

Removing a component must warn when any of its cells affect commission:

```text
“Port transfer fee” is part of the commissionable base for First/Second.
Removing it will also remove those commission-base selections.

[Cancel] [Remove component]
```

---

## Narrow-screen behavior

Do not horizontally compress the full matrix into unreadable fields. On narrow screens, show one selected rate profile at a time.

```text
┌──────────────────────────────────────────┐
│ O1 · Prime Oceanview                    │
│ Supplier rates                          │
│                                          │
│ Rate profile                             │
│ [ First/Second                    ▾ ]    │
│ 1 of 4                         [Manage]   │
│                                          │
│ Base Fare                                │
│ $ [                         1,624.00 ]    │
│                                          │
│ NCCF                                     │
│ $ [                                  ]    │
│                                          │
│ Taxes & Fees                             │
│ $ [                                  ]    │
│                                          │
│ Discount                                 │
│−$ [                           150.00 ]    │
│                                          │
│ Fuel supplement                          │
│ $ [                                  ]    │
│                               [Remove]   │
│                                          │
│ Profile subtotal              $1,474.00  │
│                                          │
│ Commission                              │
│ Not provided yet · Pending               │
│                                          │
│ [Previous profile] [Next profile →]      │
│                                          │
│ [Save Supplier terms]                    │
└──────────────────────────────────────────┘
```

---

## Interaction and validation notes

- Use JavaScript only for immediate previews and dynamic row/column presentation. The server recompiles and evaluates the submitted schedule authoritatively.
- Keyboard movement should follow the matrix: `Tab` moves across one row, then into the next row.
- Column headers remain visible while scrolling the component table.
- A profile can be removed only after Staff confirms removal of every populated cell and dependent commission base.
- A blank field is not treated as zero.
- Static rows remain visible even when empty; custom rows persist only after at least one value is saved.
- Shared percentage commission uses one component and one rounding boundary; profile-specific percentages are an explicit Staff choice.
- Percentage commission cannot be marked complete until every populated cell is explicitly included, subtracted, or ignored.
- Percentage commission components are ordered after all base components.
- Dollar commission fields inherit their column's applicability.
- Adding or changing components, profiles, commission, or occupancy planning clears forecast readiness.
- Advanced formulas remain visible but read-only in the typed workspace, with a direct deep link to advanced planning.
- No Client prices, Package terms, bookings, Holds, Charges, Obligations, or Payments are created from this page.
