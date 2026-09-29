Yes. I would make the **user journey the organizing principle of the UX remediation**, rather than treating the overview, forms, and activation screen as independent UI improvements.

The important shift is:

> Staff should experience DepartureDesk as **progressively building a usable Supplier arrangement**, not as maintaining the records that constitute one.

That also gives us a better way to decide what belongs on each screen.

## The Cruise journey

For the Smith Family Reunion, I think the normal Staff journey should look roughly like this:

```
Create Departure
      │
      ▼
Outline the trip
"Cruise is one of the services"
      │
      ▼
Add Cruise Supplier
Celebrity Cruises
      │
      ▼
┌──────────────────────────────┐
│  CRUISE WORKSPACE            │
│                              │
│  Sailing                     │
│  Cabin categories            │
│  Supplier rates              │
│  Agreement & requirements    │
│  Review & activate           │
└──────────────────────────────┘
      │
      ▼
Connect to Client offering
      │
      ▼
Package / price / proposal
```

Critically, entering the Cruise workspace does **not** mean Staff must complete all five steps in order.

It means:

> "Here's everything we currently know about this Cruise, and here's the most useful thing to do next."

That preserves the non-wizard decision we made for Composition.

---

# 1\. Create the Departure

This remains the very lightweight beginning we previously designed.

Staff enters:

**Smith Family Reunion**

Approximate/exact dates:

**November 2027** or **Nov 6–13, 2027**

Responsibility:

**Alex Mariner / Harbor Travel**

Components:

**Cruise**  
**Pre-cruise hotel**  
**Transfers**  
**Excursion**

At this point we don't ask for Celebrity, cabin inventory, deposits, rates, etc.

The outcome is simply:

> **Smith Family Reunion has been created.**

And Composition shows what exists and what could happen next.

---

# 2\. Add the Cruise Supplier service

From **Suppliers**, Staff sees:

```
Supplier planning

Cruise
No Supplier arrangements yet.

[ Set up Cruise ]
```

The first Cruise form should be intentionally small.

### Set up Cruise

```
Supplier *
[ Celebrity Cruises                         ▾ ]

Ship
[ Celebrity Beyond                           ]

Sailing dates
[ Nov 6, 2027 ]  to  [ Nov 13, 2027 ]

Itinerary
[ 7-Night Eastern Caribbean                  ]

Time zone
[ America/New_York                         ▾ ]


[ Cancel ]                         [ Set up Cruise ]
```

That's enough to create the Arrangement, Item and Occurrence.

We do **not** ask for:

- agreement information;  
- cabin categories;  
- inventory;  
- rates;  
- deposits;  
- deadlines;  
- commission;  
- GAP;  
- TC.

After save, Staff lands on the Cruise overview.

---

# 3\. Cruise overview becomes the journey hub

This is where the mockup we discussed fits.

At the top:

```
Celebrity Beyond

Celebrity Cruises · Nov 6–13, 2027 · Draft

┌─────────────┬────────────────┬──────────────┬──────────────────┬─────────────┐
│ ✓ Sailing   │ 2 Categories   │ Supplier     │ Agreement &      │ Review &    │
│             │   need rates   │ rates        │ requirements     │ activate    │
└─────────────┴────────────────┴──────────────┴──────────────────┴─────────────┘
```

Then the summary sections.

But I'd add one important element that wasn't prominent in our earlier mockup:

### Next recommended action

```
Next

Add the cabin categories Celebrity is holding for this group.

[ Add cabin categories ]
```

That's the bridge between the **workspace** and the **journey**.

Staff can ignore it and edit the agreement because they happen to have the contract open. Nothing prevents that.

But DepartureDesk always tells them what a sensible next step is.

---

# 4\. Enter cabin categories

If Staff clicks **Add cabin categories**, don't start with a single category form.

This is one place where batch entry makes sense because a Supplier rate sheet commonly contains several categories.

### Cabin categories

```
Enter the cabin categories Celebrity is holding for this group.

Code    Category                         Sleeps    Inventory      Cabins

E3      Edge Stateroom with Veranda     [ 3 ]     Fixed block    [ 8 ]
O1      Prime Oceanview                 [ 3 ]     Fixed block    [ 8 ]
DI      Deluxe Inside Stateroom         [ 3 ]     Fixed block    [ 8 ]

                                                   [ + Add category ]


24 cabins blocked

[ Cancel ]                              [ Save cabin categories ]
```

For an unusual category:

```
OS      Owner's Suite                   [ 5 ]     On request
```

Quantity disappears because it isn't numerically tracked.

After save:

```
3 cabin categories added · 24 cabins blocked

Next
Enter Celebrity's rates for these cabins.

[ Enter supplier rates ]

or

[ Back to Cruise ]
```

This is where we should allow a little journey guidance without turning the application into a wizard.

---

# 5\. Enter rates

Now the Staff member has the Celebrity rate sheet in front of them.

Instead of navigating separately to E3, then O1, then DI from scratch, I'd support a category navigator:

```
Supplier rates

[E3 Edge Stateroom]   [O1 Prime Oceanview]   [DI Deluxe Inside]
       ✓                       ●                       —

O1 — Prime Oceanview
```

Then the focused rate form we discussed:

```
These rates are:

(●) Estimate
( ) Contracted


                         First / second    Third     Single adjustment

Base fare                 $ 1,739.00       $ 10.00    $ 1,739.00
NCCF                      $   320.00       $320.00    $   320.00
Discount                  $  -772.50       $  —       $  -772.50
Taxes and fees            $   134.26       $134.26    $     —


Commission

[ 15.00 ] % of
☑ Base fare
☐ NCCF
☑ Discount
☐ Taxes and fees
```

Below it:

```
Calculated cabin totals

Single              Double              Triple
$2,707.26           $2,841.52           $3,305.78

Expected commission
$289.95 on a double cabin


[ Save ]                              [ Save & next category ]
```

After DI:

> **All 3 cabin categories have rates.**

If they're estimates:

> You can continue planning with these rates. Record contracted rates when Celebrity confirms the agreement.

That's much more useful than "3 of 3 forecast-ready."

---

# 6\. The agreement can happen whenever the contract arrives

This is where the journey branches.

Staff may have the contract before rates, after rates, or while entering them.

So the Cruise overview might show:

```
Supplier agreement

Group created             Sep 13, 2026
Supplier group number     Not recorded
Contract date             Not recorded

The Supplier agreement has not been confirmed.

[ Record agreement ]
```

When the agreement arrives:

### Record Supplier agreement

```
Group creation date
[ Sep 13, 2026 ]

Supplier group number
[ 1119999 ]

Contract date
[ Sep 13, 2026 ]

Note
[                                              ]


[ Save for later ]                [ Confirm Supplier agreement ]
```

Suppose rates are still estimates.

After confirmation, DepartureDesk says:

```
✓ Supplier agreement confirmed

Celebrity has confirmed this agreement.

2 cabin categories still use estimated rates.

[ Review supplier rates ]                  [ Back to Cruise ]
```

This directly reflects the domain distinction we spent considerable effort implementing:

**agreement confirmed ≠ rates ready ≠ Arrangement activated.**

But the Staff member doesn't have to understand that architecture.

---

# 7\. Record requirements from the agreement

Once Staff has the contract, the next suggested task becomes:

> **Record what Celebrity requires and when.**

The requirements page could start with common Cruise items:

```
Deposits and deadlines

Initial group deposit
$50.00 × 24 blocked cabins
Total: $1,200.00

Due
[ Oct 13, 2026 ]

Suggested from group creation: Oct 13, 2026

                                      [ Save ]
```

Then:

```
What else does the agreement require?

[ + Hard stop ]
[ + Final payment ]
[ + Other requirement ]
```

For the fixture:

### Hard stop

```
Date
[ Jul 9, 2027 ]

By this date

Name and fully deposit allocated staterooms,
or release remaining inventory.

[ Save ]
```

### Final payment

```
Final payment date

[ Aug 8, 2027 ]

[ Save ]
```

We aren't asking Staff to construct `SupplierDeadlineDefinition` semantics.

---

# 8\. Record additional Supplier terms progressively

Now the overview might say:

```
Supplier terms

✓ Allocated-cabin deposit     $500 per allocated cabin
✓ Cancellation               Recorded
— Payment restrictions       Not recorded
✓ Commission                 15%
✓ Tour conductor             1 per 16 qualifying guests
✓ GAP                        4 points

[ Add or review terms ]
```

Staff only opens what they need.

And importantly, **missing optional terms do not look like failures**.

This is one of the places where the current interface becomes overwhelming: it gives empty fields too much visual importance.

---

# 9\. The overview evolves as work progresses

At the beginning:

```
Celebrity Beyond

✓ Sailing
! Cabin categories       Not entered
— Supplier rates         Waiting for categories
— Agreement              Not recorded
— Requirements           Not recorded
— Activation             Not ready

NEXT
Add the cabin categories Celebrity is holding.
```

Later:

```
Celebrity Beyond

✓ Sailing
✓ Cabin categories       3 · 24 cabins
! Supplier rates         2 contracted · 1 estimated
✓ Agreement              Confirmed Sep 13
✓ Requirements           Deposit + 2 deadlines
— Activation             Contracted rate needed

NEXT
Review DI's contracted Supplier rate.
```

Eventually:

```
Celebrity Beyond

✓ Sailing
✓ Cabin categories       3 · 24 cabins
✓ Supplier rates         3 contracted
✓ Agreement              Confirmed Sep 13
✓ Requirements           Complete
✓ Activation             Ready to review

NEXT
Review this Supplier arrangement for activation.

[ Review activation ]
```

That is the experience I think we were trying to achieve when we originally introduced Composition.

---

# 10\. Activation is the end of the Supplier setup journey

The activation page should feel like a review, not another data-entry page.

### Review Celebrity Beyond

```
Sailing
✓ Celebrity Beyond
  Nov 6–13, 2027
  7-Night Eastern Caribbean

Supplier agreement
✓ Celebrity group 1119999
  Contract date Sep 13, 2026

Cabin inventory
✓ E3       8 cabins
✓ O1       8 cabins
✓ DI       8 cabins
           24 total

Supplier rates
✓ E3       Contracted
✓ O1       Contracted
✓ DI       Contracted

Supplier requirements
✓ $1,200 initial deposit · Oct 13, 2026
✓ Hard stop · Jul 9, 2027
✓ Final payment · Aug 8, 2027

No blocking issues found.


[ Back ]                         [ Activate Supplier arrangement ]
```

And only then:

```
✓ Celebrity Beyond is active

Supplier planning is ready for Client Offer Design.

[ Connect to Client service ]
```

That creates a clean handoff into M4.

---

# Where later changes fit

The journey doesn't end forever at activation.

Suppose Celebrity later gives us four more O1 cabins.

Staff opens the same Cruise overview:

```
O1 — Prime Oceanview
8 cabins

[ Change inventory ]
```

Then:

```
What changed?

(●) Same Supplier terms
( ) Supplier terms changed

Additional cabins
[ 4 ]

Additional Supplier deposit
$50 × 4 = $200

Evidence / note
[ Celebrity approved additional allocation ... ]

[ Record increase ]
```

Result:

```
O1 — Prime Oceanview
12 cabins

Opening block          8
Added Sep 20           +4

Initial deposit        $1,200
Additional deposit     $200
```

If terms changed, the UI sends Staff into the supplemental-block/successor journey instead.

Again, Staff doesn't choose:

> "Create capacity event" vs "Create successor Arrangement."

They answer the business question:

> **Did the Supplier terms change?**

DepartureDesk chooses the correct domain operation.

---

# How I'd restructure the implementation plan around this

This changes my previous five-slice UX plan slightly. I'd organize implementation around **journey milestones**, not pages:

| Slice | User can now... |
| :---- | :---- |
| **UX-0 — Journey contract** | Establish normal Cruise journey, status vocabulary, next-action rules, Advanced boundary |
| **UX-1 — Orient** | Open a Cruise and understand what exists, what's missing, and what to do next |
| **UX-2 — Establish supply** | Set up sailing and cabin categories without encountering generic M3 concepts |
| **UX-3 — Establish economics** | Enter/review Estimate and Contracted Supplier rates in Cruise terminology |
| **UX-4 — Establish agreement** | Confirm Supplier agreement and record deposits, deadlines and Supplier terms |
| **UX-5 — Activate** | Review a plain-language readiness summary and activate |
| **UX-6 — Maintain** | Add same-terms capacity or start changed-terms successor through business-language choices |
| **UX-7 — Handoff** | Move cleanly from active Supplier arrangement into Offer Design |

Each slice should have a browser proof phrased as a **Staff outcome**, rather than "the controller renders these fields."

For example, UX-3's exit criterion becomes:

> Starting from a Cruise with E3/O1/DI cabin categories, Staff can transcribe the Celebrity rate sheet, understand the resulting Single/Double/Triple Supplier totals, distinguish Estimate from Contracted rates, record contracted rates without destroying the estimate, and return to the Cruise overview knowing what remains to be done.

That is a much stronger acceptance test than checking whether the new form submits.

And I would keep one overarching UX invariant:

> **At every point in the normal Cruise journey, Staff should be able to answer three questions without understanding the underlying M3/M4 model: What have we recorded? What still needs attention? What should I do next?**

That ties the mockups, forms, Composition workspace, and the domain rework into one coherent product direction.  
