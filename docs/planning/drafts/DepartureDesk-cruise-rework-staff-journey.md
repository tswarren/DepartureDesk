Here is the **intended Cruise component workflow**, using Smith Family Reunion as the example. This describes the rework we have been designing; the :chatgpt-content-reference{index="0"}[draft plan](sandbox:/workspace/scratch/76dc08f1cc65/DepartureDesk-cruise-rework-plan-draft.md) and revised Celebrity fixture are **not yet accepted implementation authority**. Several steps differ from the shipped builder.

Optional departure and return ports, itinerary notes, and commercial-benefit terms are accepted in [Sailing ports and commercial benefits](../m4-offers-and-pricing/m4d1-cruise-ports-and-commercial-benefits.md). This journey does not reopen them.

The workflow has two boundaries:

- **Supplier Composition** records what Celebrity agreed to supply, what it costs the agency, and what Staff must do. This is the Cruise setup stopping point.
- **Offer Design** decides what the agency presents and charges to Clients. Connecting the two does not create a booking.

## 1. Start a provisional sailing

From **Smith Family Reunion → Composition → Suppliers**, Staff chooses **Set up a Cruise**.

The Sailing form asks for Celebrity Cruises, Celebrity Beyond, the itinerary name, group creation date, November 6–13, 2027 sailing dates, and the relevant time zone. It displays USD from the Departure’s operating currency. Staff may add departure and return ports, local times, a description, Supplier contact, a group reference, and a contract date as they learn them.

The form proposes:

> Celebrity Cruises — Celebrity Beyond — 7-Night Eastern Caribbean — Nov 6–13, 2027

Staff can edit that name. Once saved, it stays as chosen even if a sailing fact changes; Staff can rename it explicitly. The Supplier group reference has its own field.

**Save sailing** creates a *Provisional* draft Arrangement with one Cruise Item and one sailing Occurrence. Staff can leave at this point. Provisional requires the group creation date; reference `1119999` and the contract date can be supplied later. An optional agreement file can be attached at any time.

The proposed separate port zones and independently optional times still require a schedule-model amendment. Until accepted, the form must accurately show the narrower timing facts it can store.

## 2. Add the initial cabin blocks

Staff adds one category at a time:

| Supplier code | Category | Maximum guests per cabin | Initial fixed block |
| --- | --- | ---: | ---: |
| E3 | Edge Stateroom with Veranda | 3 | 8 |
| O1 | Prime Oceanview | 3 | 8 |
| DI | Deluxe Inside Stateroom | 3 | 8 |

Each save records a stable cabin-category Resource and its Capacity Pool. **Maximum guests** describes one cabin; **eight blocked cabins** describes the amount Celebrity has made available. The overview totals the opening blocks as **24**, while preserving each block separately.

Staff can save E3, return later for O1, and correct DI without altering either sibling. A category description and initial supporting reference are optional. If another sailing has *on-request* inventory, Staff selects that treatment instead of entering a fictional numeric block.

At this stage these are draft Supplier facts. Saving a block does not allocate a cabin to a Client or establish effective inventory.

## 3. Enter and confirm Supplier costs

For each cabin category, Staff opens its Supplier rate matrix. They enter Base fare, NCCF, discount, and taxes/fees in the applicable First/Second, Third, and Single-adjustment bands, then specify the normal commission rule. They confirm the supported Single, Double, and Triple occupancy patterns.

The important calculation rule is that **Single is additive**: one First/Second band *plus* the Single-occupancy adjustment. The adjustment is not a complete Single fare. Commission applies to the combined profile’s commissionable fare and is rounded once; NCCF and taxes are outside that basis.

For example, the O1 review should calculate:

| O1 occupancy | Supplier total | Expected commission | Supplier net |
| --- | ---: | ---: | ---: |
| Single | $2,707.26 | $289.95 | $2,417.31 |
| Double | $2,841.52 | $289.95 | $2,551.57 |
| Triple | $3,305.78 | $291.45 | $3,014.33 |

Staff may first save a category as an **Estimate**. When the agreement provides its rates, **Record contracted rates** copies that estimate into a *separate* contracted definition. Staff compares and corrects the copy, records the required contracted-terms provenance, and marks it forecast-ready. The estimate remains in history. An agreement upload can support the rates but is not mandatory.

This is distinct from confirming the **group agreement**. The group confirmation covers the whole agreement; it does not turn an estimated rate record into a contracted rate record automatically.

## 4. Confirm the group agreement

When Celebrity confirms the group, Staff enters its reference **1119999** and the contract date, then chooses **Mark group Supplier confirmed**. The action records the actor and time. A note and document are optional.

Confirmation attests to the **agreement as a whole at that revision**, including its then-agreed categories and terms. Staff may record confirmation before finishing transcription in DepartureDesk, but the Arrangement cannot activate until the covered categories have ready contracted rates and the other required facts pass review.

The reference and contract date then leave ordinary editing. If either was recorded incorrectly, Staff uses an explicit correction that retains the earlier fact. The group can later receive an amendment without changing its original contract date or erasing this confirmation.

## 5. Record deposits, dated actions, and policy

These appear as separate sections because they have different consequences.

### Initial group deposit

Staff selects the E3, O1, and DI Pools and enters **$50 per initially blocked cabin**. From the September 13 group creation date, the form suggests **October 13, 2026**; Staff reviews the saved due date.

The summary shows the calculation, not just the total:

> E3 8 + O1 8 + DI 8 = 24 cabins  
> 24 × $50 = **$1,200 required** · due October 13, 2026

This is a Supplier requirement and operational commitment. It does **not** say $1,200 was paid, match a payment, or attribute $50 to any future allocated cabin.

### Actionable deadlines

Staff records two actions:

- **July 9, 2027 — Hard Stop:** name and fully deposit allocated staterooms, **or** release remaining inventory. It is one combined Staff action.
- **August 8, 2027 — Final payment:** attend to and document the Supplier final-payment action.

A due date can make an action overdue. Its passage does not release capacity, submit names, or send money. Staff must perform and record the applicable action through the appropriate operational workflow.

### Booking-dependent policy

A separate readable section records Celebrity’s **$500 total per allocated stateroom** rule, including an attributable initial $50 credit. It describes the earliest applicable name, allocation-plus-30-days, shorter-option, and Hard Stop triggers. It also records card restrictions and the per-person cancellation schedule.

There is **no Arrangement-wide `$500 × retained cabins` final deposit** for this fixture. Until individual cabin allocation, traveler, and payment-attribution facts exist, the system cannot truthfully calculate each cabin’s remaining requirement. Nor does Supplier Composition calculate cancellation charges or refunds.

## 6. Review and activate Supplier terms

The Cruise review assembles the sailing, group confirmation, all three cabin blocks, each category’s contracted rate status and occupancy previews, the $1,200 deposit derivation, the two actions, and the booking-dependent policies. It also displays normal commission separately from projected tour-conductor credit and the four group GAP points.

**Preview is write-free.** It points Staff to incomplete fields and shows what activation would establish or open. Staff corrects an individual section and returns to review.

Once the group is Supplier confirmed, its included rates are contracted and ready, and the other activation checks pass, Staff activates the Arrangement. The exact version becomes governing; its definitions become read-only. Activation establishes the numeric opening Pools and materializes the initial deposit and actionable deadlines through the existing operational engines. It does not create a Client booking or a payment.

## 7. Hand off to Offer Design

After Supplier setup, Staff may connect the Cruise Item to a Cruise Service Offer. The existing handoff creates a choice for E3, O1, and DI and pins the exact Supplier source. Staff then enters **independent Client prices** and reviews anonymous Single, Double, and Triple scenarios.

The fixture’s illustrative Client prices—including O1 Double **$2,941.52**—are examples, not automatically accepted selling prices. Connecting the service neither places it in a Package nor books a cabin. Published Client prices do not change when Supplier costs later change.

## 8. Handle changes after activation

There are two paths for more O1 cabins:

| Celebrity’s change | Staff workflow | Effect on Client offers |
| --- | --- | --- |
| **More cabins under exactly the same governing terms** | Record an evidenced increase to the existing O1 Pool. Decide explicitly whether another initial deposit applies. | Availability can be reconsidered under the existing source; no price changes automatically. |
| **New category or O1 cabins with different rates or other terms** | Create a successor draft and a separately labeled Resource, Pool, and rate source. It can retain the real Supplier code `O1`. Confirm the amended whole agreement, then activate the successor. | The new block stays Supplier-side until Staff explicitly reviews its Client offering. It does not silently join the old published O1 choice. |

While an amendment is being prepared, Staff sees **the confirmed governing agreement** alongside **a proposed amendment awaiting confirmation**. Earlier confirmations, rates, capacity events, commitments, and published offers retain the terms that governed them.

That is the intended Staff journey: save the group early, build and confirm its Supplier facts in manageable sections, activate only a truthful agreement, and make later supply and Client-offer changes explicitly.