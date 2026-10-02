# Transportation Supplier Composition — Motorcoach

**Status:** Shipped 2026-10-02
**Location:** `docs/planning/m4-offers-and-pricing/transportation-supplier-composition.md`
**Parent:** [M4D.1 — Departure Composition Workspace](m4d1-departure-composition-workspace.md)
**Boundary authority:** [M4D.1 Slice 3R — Non-Cruise Adapter Boundary](m4d1-slice3r-non-cruise-adapter-boundary.md)
**Compatibility gate:** [ABC Motorcoach supplier compatibility](abc-motorcoach-supplier-compatibility.md)
**Canonical fixture:** [ABC Motorcoach 2027](../fixtures/abc-motorcoach-2027-canonical-transportation-scenario-draft.md)
**Workflow authority:** [ABC Motorcoach Transportation staff walkthrough](abc-motorcoach-transportation-staff-walkthrough.md)
**Prerequisite:** Hotel Supplier Composition through Hotel Lifecycle shipped
**Baseline:** `main` at or after `4a2f8d8d430845d24fcd5b539e3cf1c89a754dc0`
**Authorizes:** The shipped Transportation Agreement workspace in this plan
**Does not authorize:** Client transfer pricing, Package placement, Client Trip selections, traveler manifests, Supplier Payments, M4E, Activity/Meal/Excursion support, Air, Rail, or a generalized non-Cruise adapter framework

The [planning index](../README.md) remains the status authority. This shipped plan authorizes the Transportation Agreement workspace and no other Transportation work.

---

## 1. Purpose

Implement the first typed Transportation Supplier Composition workflow for the ABC Motorcoach Smith Family Reunion fixture.

Staff work in Transportation language. The ordinary path represents:

- one ABC Motorcoach Supplier Arrangement;
- two independently identifiable Transportation segment Items;
- exact pickup and drop-off;
- exact service date and known pickup time;
- confirmed motorcoach quantity;
- passenger capacity per motorcoach;
- additional motorcoaches available only on request;
- fixed Supplier rate per confirmed motorcoach;
- segment-specific final-count Deadlines;
- the November 3 charter amount due;
- Supplier confirmation;
- activation;
- governing read mode;
- successor behavior.

The implementation stays layered on the shipped Supplier Arrangement, capacity, cost, Deadline, confirmation, activation, and successor models. It does not introduce a parallel Transportation agreement domain.

Generic amendments are limited to gaps that are genuinely cross-vertical. Everything else is Transportation orchestration over shipped records.

## 2. Canonical topology

The ABC fixture locks this topology.

```text
Supplier Arrangement
ABC Motorcoach
│
├── Transportation Item
│   Hotel → Port
│   └── one Service Occurrence
│
└── Transportation Item
    Port → Airport
    └── one Service Occurrence
```

There is no Airport → Port Item.

Each segment has its own stable `ArrangementItem`, exactly one supported Service Occurrence on the typed path, its own route, its own schedule, its own coach capacity, its own Supplier rate, and its own final-count Deadline. The two Items share one Supplier agreement and version lifecycle.

The typed path sets the Arrangement's contracting Supplier as each Item's default Service Provider. For ABC, that Supplier is ABC Motorcoach.

A second Occurrence on a segment is an Advanced shape. The typed path does not create one.

## 3. Locked ABC facts

Departure: Smith Family Reunion. Operating currency USD. Time zone America/New_York.

### Hotel → Port

- Pickup: Hilton Fort Lauderdale Marina
- Drop-off: Port Everglades
- Service date: November 6, 2027
- Pickup time: 10:00 a.m.
- Drop-off time: absent
- 1 confirmed motorcoach
- 15 passengers per motorcoach
- Up to 2 additional motorcoaches on request
- $200 per confirmed motorcoach
- Final passenger and luggage count due November 3, 2027

### Port → Airport

- Pickup: Port Everglades
- Drop-off: Fort Lauderdale-Hollywood International Airport
- Service date: November 13, 2027
- Pickup time: 9:30 a.m.
- Drop-off time: absent
- 1 confirmed motorcoach
- 15 passengers per motorcoach
- Up to 2 additional motorcoaches on request
- $175 per confirmed motorcoach
- Final passenger and luggage count due November 10, 2027

### Shared agreement fact

The charter amount due is November 3, 2027, date only.

At one confirmed coach on each segment the amount is $375, derived as:

```text
Hotel → Port      1 × $200 = $200
Port → Airport    1 × $175 = $175
Total due Nov 3   $375
```

A coach whose controlled quantity is effective on or before November 3, 2027 increases that amount. A coach effective after that date does not.

Unspecified facts stay unspecified. The driver does not consume a passenger space.

## 4. Compatibility result

The [compatibility gate](abc-motorcoach-supplier-compatibility.md) sorts the charter into three classes. No implementation hides a gap behind prose, a Cruise column, or an invented time.

### Fits existing Supplier foundation

Reuse without a new meaning:

- Supplier Arrangement and version topology;
- stable Item identity through successors;
- one Occurrence per segment;
- `ground_transportation`;
- capacity Pair and Pool machinery;
- Supplier Resource;
- `maximum_occupancy` as persons per Resource unit, labeled in Transportation as passenger capacity per motorcoach;
- Supplier cost Sources, Definitions, and Components;
- Deadline definitions, including `final_count_due`;
- `SupplierConfirmation` identity and evidence;
- `ActivateSupplierArrangementVersion`;
- successor copying and exact-version lineage.

### Typed Transportation orchestration

Transportation supplies typed commands, read models, and screens over existing primitives for segment creation, route and schedule editing, confirmed coach quantity, passenger-space derivation, the per-coach rate, draft synchronization of Pool quantity and cost usage, final-count Deadlines, and review and activation summaries.

### Foundation incompatibilities

These six gaps require the resolutions in this plan:

1. Numeric on-request ceiling.
2. November 3 derived charter amount due.
3. Pickup and drop-off persistence.
4. Pickup-only local time.
5. Post-activation confirmed coach quantity as the contracted Supplier-cost quantity.
6. Transportation Supplier-confirmation freeze.

## 5. Generic amendment A — service endpoints

Amends [ADR 0008](../../adr/0008-supplier-arrangement-version-topology.md). The Cruise port columns remain the narrow sailing exception and are not a general endpoint model.

Pickup and drop-off are operational structured facts. `departure_port_name` and `return_port_name` stay Cruise sailing fields. `name` and `description` are not endpoint storage.

Add optional endpoint display fields on `ServiceOccurrenceDefinition`:

```text
origin_name
destination_name
```

They are generic occurrence facts.

- Optional, trimmed, blank-to-null, maximum 160 characters.
- Exact-version-owned and copied by the existing version graph.
- Mutable only while that definition is otherwise editable.
- No geocoding, no Supplier Location foreign key, and no address normalization in this plan.

Cruise commands continue to write `departure_port_name` and `return_port_name`. They do not write `origin_name` or `destination_name`. Existing Cruise port data stays where it is.

Transportation stores:

```text
origin_name      = Hilton Fort Lauderdale Marina
destination_name = Port Everglades
```

and the Port → Airport pair the same way.

## 6. Generic amendment B — independently known local times

Amends [ADR 0008](../../adr/0008-supplier-arrangement-version-topology.md).

`ServiceOccurrenceDefinition` currently requires local start and local end to be both present or both absent. ABC has a contractual pickup time and no contractual drop-off time. An invented end time is not a fit.

Persistence allows each combination:

```text
no start / no end
start only
end only
start and end
```

`starts_on`, `ends_on`, and `time_zone` stay required. `starts_on` stays on or before `ends_on`.

When both local times are present and `starts_on` equals `ends_on`, `ends_at_local` is on or after `starts_at_local`. When the occurrence spans more than one date, the times are the endpoints of those dates. The application does not infer a duration and does not copy the start into the end.

ABC:

```text
starts_on = ends_on = 2027-11-06
starts_at_local = 10:00
ends_at_local = null
time_zone = America/New_York
```

Hotel stay and Cruise sailing commands keep requiring the local times their own accepted plans already require. This amendment changes the shared persistence invariant. It does not relax those typed forms.

Transportation labels the fields Pickup time and Drop-off time. Drop-off time is optional. The ABC fixture leaves it blank.

## 7. Passenger capacity per motorcoach

Accept `SupplierResourceDefinition.maximum_occupancy` as passenger capacity per motorcoach on the typed Transportation Resource.

The generic meaning stays: maximum persons supported by one Resource unit. The Transportation label is **Passenger capacity per motorcoach**.

ABC stores `maximum_occupancy = 15`. The driver does not consume that capacity.

## 8. Confirmed motorcoach capacity

Each segment uses one motorcoach Resource and one Pool. The Pool is confirmed Supplier-controlled motorcoach units.

```text
classification    = pooled
measurement_basis = resource_units
unit_label        = motorcoaches
inventory_mode    = block
opening quantity  = confirmed motorcoach count
```

Initially each segment opens at 1.

Typed derivation:

```text
controlled passenger spaces = confirmed motorcoaches × maximum_occupancy
```

```text
1 × 15 = 15 passengers
2 × 15 = 30 passengers
3 × 15 = 45 passengers
```

The typed path does not create a second Pool measured in `traveler_positions`.

## 9. On-request ceiling

An `on_request` quantity is rejected, and a Pair that already holds the block Pool cannot hold a second Pool. "Up to 2 additional motorcoaches" and "45 passengers" have no shipped numeric home.

This plan adds `maximum_total_resource_units` on `CapacityPoolDefinition`. The stored fact is the Supplier's total ceiling, not a count of coaches still awaiting confirmation.

- Nullable.
- When present, an integer greater than zero, and at least the Pool's confirmed quantity.
- Written only by the typed Transportation command, and only on the supported `resource_units` block.
- Excluded from controlled capacity, from the opening quantity, from capacity events, and from any Reservation ceiling.
- Copied to successors.
- Frozen when Transportation Supplier confirmation freezes that Pool definition.

ABC's offer is one guaranteed coach plus up to two more, which is three coaches total. The typed save stores:

```text
proposed opening quantity       = 1
maximum_total_resource_units    = 3
```

Remaining on request and the passenger ceiling are derived. They use the current confirmed quantity, which is the proposed opening before activation and the controlled Pool quantity after activation.

```text
remaining on request = max(maximum total units − current confirmed units, 0)
maximum possible passengers = maximum total units × maximum occupancy
```

The display follows the confirmed quantity. The ceiling does not.

```text
Initially
1 confirmed
Up to 2 more on request
Maximum 45 passengers

After the second coach is confirmed
2 confirmed
Up to 1 more on request
Maximum 45 passengers

After the third coach is confirmed
3 confirmed
No additional coaches currently available on request
Maximum 45 passengers
```

The typed increase stops at the total ceiling. A further coach is outside this agreement and stays Advanced. Lodging and Cruise screens do not show or write this column. The maximum-passenger figure is display only and is not controlled inventory.

## 10. Supplier rate per confirmed motorcoach

Each segment owns one Item-scoped contracted Supplier cost Source with one `unit_rate` Supplier charge on quantity basis `resource_units`.

```text
Hotel → Port      $200
Port → Airport    $175
```

The typed label is **Supplier rate per motorcoach**. `EvaluateSupplierCostForecast` remains the evaluator. Commission treatment stays unspecified. The typed path does not set `noncommissionable` or any other commission value.

Passenger count does not change Supplier cost while the confirmed coach count stays the same.

## 11. Draft cost-quantity orchestration

On a draft, Pool quantity and `SupplierCostUsageAssumption.expected_resource_units` are separate facts. Changing one does not change the other.

Inside the supported Transportation draft shape, the typed capacity save owns both facts in one transaction. Recording 2 confirmed motorcoaches sets:

```text
Pool proposed opening quantity = 2
expected_resource_units       = 2
```

for that segment's owned cost context.

This is typed orchestration. It does not add a generic coupling between every Pool and every usage assumption.

If the usage assumption has been changed into another generic shape, the typed path stops and shows **Advanced Supplier planning**. It does not overwrite that assumption.

## 12. Post-activation coach quantity

Amends [ADR 0011](../../adr/0011-supplier-cost-definitions-and-forecast-evaluation.md).

After activation, shipped capacity authority can record an `increased` event. Ordinary cost edits, including `expected_resource_units`, require a draft version. A same-rate additional coach therefore changes controlled capacity and leaves contracted Supplier exposure unchanged.

### Decision

A ready contracted `unit_rate` component on `resource_units` may declare a capacity-backed quantity authority pointing at one stable Pool. The rate stays on the component. The quantity is derived.

The authority link is part of the draft cost definition and freezes with that definition. Activation does not copy the link into a second quantity column, and later capacity events do not update the cost definition or the usage assumption.

The billable quantity and the controlled-capacity projection are different lifecycles. They match when coaches are established or increased. A release or withdrawal changes how much capacity remains controlled. It does not, by itself, say what the Agency still owes.

Evaluation of the opted-in component:

- Before activation, quantity is the Pool's proposed opening quantity. A draft edit of that opening still synchronizes the usage assumption, as section 11 describes.
- After activation, quantity is the sum of `established` and `increased` events whose effective time has arrived. A future-effective increase waits until then. A later-recorded increase whose effective time is already past counts once it is recorded, because the forecast is derived and no Supplier Payment has been posted.
- `released` and `withdrawn` do not reduce that quantity. Their financial effect is Needs clarification and stays Advanced until an accepted contractual rule says otherwise.

`current_supplier_capacity` remains the controlled-capacity figure. It is not the billable quantity.

ABC, after an immediate increase of Hotel → Port from 1 to 2:

```text
rate stays $200 per motorcoach
effective Supplier exposure on that segment becomes $400
Port → Airport stays $175
combined current exposure becomes $575
```

### Scope

The authority is opt-in on that component. Hotel rates, occupancy prices, percentages, minimums, and any component without the link keep using usage assumptions and profiles.

`EvaluateSupplierCostForecast` is the single evaluator. The M3E exposure projection calls that evaluator, so an opted-in increase moves qualified exposure for that source, and a release or withdrawal does not move it back. Components without the link do not move because of this amendment.

Once a component is capacity-backed, Transportation and the generic cost screen show this billable quantity as the quantity authority. `expected_resource_units` remains stored and is not a second displayed quantity for that component. The screen also shows the controlled projection, so a release is visible as a capacity fact whose cost effect is still unresolved.

### Evidence

A later confirmed coach uses the shipped `increased` capacity event and its existing evidence fields: evidence kind, evidence date, and evidence reference note. This plan adds no evidence columns.

A change to the per-coach rate is a contractual successor. A same-rate unit change is the capacity event.

## 13. Why the usage assumption is not the post-activation authority

`expected_resource_units` is a planning assumption. A coach ABC confirms after activation is controlled Supplier capacity.

Leaving the assumption in place as the authority would keep two quantities, or would require editing a frozen definition. For a capacity-backed component, the billable quantity is the effective `established` and `increased` history. The contractual rate remains the frozen component amount. Controlled capacity after a release is a separate fact.

## 14. Final-count Deadlines

Use shipped Deadline machinery.

```text
Hotel → Port
final_count_due
2027-11-03
date only
America/New_York
coverage: that segment Item
```

```text
Port → Airport
final_count_due
2027-11-10
date only
America/New_York
coverage: that segment Item
```

The typed label is **Final passenger and luggage count due**. No cutoff time is added.

The November 3 Deadline and the November 3 charter amount due are different records that may share a date.

Completing a final-count Deadline does not change motorcoach quantity, passenger capacity, or the charter amount due, and it does not create a traveler or a Client Trip manifest.

## 15. November 3 charter amount due

Amends [ADR 0013](../../adr/0013-supplier-operational-commitments-deadlines-exposure-and-ending.md).

Shipped `SupplierDepositRequirementDefinition` shapes do not mean "amount due equals each segment's then-effective confirmed coaches times that segment's contracted rate." A fixed cumulative target cannot name the two segment costs as contributors. A quantity-derived cumulative target has one rate. Probed at $200, that parent previews to $25 and, after Hotel → Port is 2 coaches, materializes to $225. Those are different facts. This plan does not extend Deposit Requirement math to imitate the charter.

### Decision

Add `SupplierAmountDueDefinition`, an exact-version definition whose amount is derived from selected capacity-backed Supplier cost components.

```text
SupplierAmountDueDefinition
├── exact Supplier Arrangement Version
├── due rule
├── covered segments
└── contributing Supplier cost components
```

The name is amount due. It is not a Deposit, a Supplier Payment, an Obligation, an invoice, or a settlement.

ABC:

```text
due rule     = fixed date 2027-11-03, date only, America/New_York
currency     = the Departure operating currency
contributors = Hotel → Port contracted coach component
               Port → Airport contracted coach component
```

The amount is a live derivation. Activation does not snapshot it into an immutable tranche, and this plan has no later operational milestone that freezes the figure. A Supplier Payment or settlement would be that kind of immutable fact, and neither exists here.

For each contributor, the quantity is a deterministic replay of that Pool's capacity history as of the due-date boundary, not `current_supplier_capacity`.

```text
quantity_at(pool, due_on)
```

The boundary is the end of November 3, 2027 in America/New_York. The replay walks the Pool's ordered capacity events and counts `established` and `increased` events whose effective time is on or before that boundary. It does not subtract `released` or `withdrawn` events.

Before activation there is no event history. The quantity is the proposed opening quantity.

A later-recorded event whose effective time is on or before the due date changes the derived amount. Recording on November 5 that ABC had confirmed the second Hotel → Port coach effective November 2 moves the amount from $375 to $575. The record is still a derived requirement, not a posted payment.

A release or withdrawal effective on or before the due date changes controlled capacity and does not reduce the amount due. Its financial effect stays Needs clarification.

At one coach each, the derived lines are $200 and $175, and the amount due is $375. When Hotel → Port's second coach is effective on or before November 3, the lines are $400 and $175, and the amount due is $575. The segment lines stay visible.

Current Supplier exposure in section 12 can differ from this amount. Exposure uses the billable quantity as of the evaluation time. The amount due uses `quantity_at` at the due-date boundary. A coach confirmed after November 3 can raise current exposure and leave the amount due unchanged.

Currency is the Departure operating currency. The definition is copied to a successor and freezes with Transportation confirmation.

Successful commands that create or update it audit the Supplier Arrangement. The Arrangement remains the audit subject.

## 16. Coach confirmed after November 3

The fixture does not define payment treatment for a coach whose capacity becomes effective after November 3, 2027.

That coach still updates controlled capacity and current Supplier exposure through sections 8 and 12. It does not change the November 3 amount due.

A release or withdrawal is the other unresolved money fact. It updates controlled capacity. It does not reduce current Supplier exposure or the amount due. The typed workflow shows Needs clarification for that financial effect.

The typed workflow shows **Needs clarification** for the payment treatment of that coach. It does not reopen the requirement, revise a settled figure, create another amount-due definition, assign a new due date, or post a Supplier Payment.

**Needs clarification** is not **Reviewed — none**. This plan adds no agreement-reference kind for the missing term.

The same display rule covers cancellation terms. The fixture does not specify them. The typed summary shows **Cancellation terms — Needs clarification**. No cancellation ladder, cutoff, or reference row is invented.

Neither unresolved term blocks Supplier confirmation or activation. Staff can confirm and activate the supported charter while those two items remain unspecified.

## 17. Transportation Supplier confirmation

Supplier confirmation means the Supplier confirmed the reviewed Transportation agreement represented by that exact Supplier Arrangement Version. It is not activation readiness.

Before confirmation, every Transportation Item on the exact version has the supported reviewed shape:

- segment identity;
- origin and destination;
- service dates and a pickup-only or pickup-and-drop-off time;
- one motorcoach Resource and an accepted passenger capacity;
- one confirmed coach Pool and its on-request ceiling;
- one contracted per-coach rate with the draft quantity aligned;
- a final-count Deadline when one is recorded;
- the charter amount due when one is recorded;
- no unsupported typed section.

A generic activation blocker does not by itself prevent confirmation. Cancellation terms and the absent late-coach payment term do not prevent confirmation.

The typed path records confirmation through the shipped `SupplierConfirmation` evidence. It does not invent a Transportation confirmation record.

## 18. Transportation confirmation freeze

Generic `SupplierConfirmation` freezes lodging definitions only. On a transportation-only version, a coach, rate, deposit, and deadline update still succeed. That is the incompatibility with the Accepted walkthrough.

After Supplier confirmation of an exact version that contains a supported `ground_transportation` Item, reject insert, update, and delete of the agreement-defining facts on that version:

- the Transportation Item definition;
- the segment Occurrence definition, including origin, destination, dates, and times;
- the motorcoach Resource definition and `maximum_occupancy`;
- the Pool definition, including proposed opening quantity and `maximum_total_resource_units`;
- the contracted cost source, definition, components, and the capacity-backed quantity link;
- the `SupplierAmountDueDefinition` and its contributor links;
- the final-count Deadline definition and its coverage.

Operational capacity events stay allowed. The freeze protects the confirmed contractual definition. It does not block an `increased`, `released`, or `withdrawn` event that records a later coach confirmation or reduction.

The freeze covers the final-count Deadline definition and its coverage. It does not freeze operational Deadline actions after activation. Staff may still complete a Deadline, and may reschedule or waive one where shipped Deadline authority already permits that action. Those actions do not change coach quantity or the charter amount due.

Do not implement this by adding `ground_transportation` to `LodgingConfirmationFreeze`. Hotel and Transportation may share trigger mechanics where those mechanics are the same. Each vertical keeps an explicit predicate for which definitions its confirmation freezes.

## 19. Pre-activation correction

A confirmed Transportation draft stays frozen. Correction creates a new unconfirmed exact draft.

```text
confirmed draft
→ definitions frozen
→ correction creates the next exact version
→ the previous confirmed draft is abandoned
→ the replacement draft is unconfirmed
```

The Arrangement stays draft until its first activation. That later activation is still the first activation. `SupplierConfirmation` is not copied.

Transportation uses the same orchestration as `ReviseConfirmedHotelAgreement`. Extract the shared command during T.7, after this vertical has the same shape, as `ReviseConfirmedSupplierArrangementVersion` with an explicit vertical eligibility check. Do not ship a Transportation-only copy of the Hotel command, and do not extract it before the Transportation confirmation path exists.

## 20. Activation

Activation remains `ActivateSupplierArrangementVersion`. Generic activation readiness stays authoritative.

The typed review may supply the generic acknowledgement fields only for a version that matches the supported Transportation shape. It does not acknowledge provisional cost authority, unsupported commitments, Advanced records, or the unresolved late-coach and cancellation terms.

An estimate selected where the supported shape requires contracted authority blocks the typed activation.

## 21. Transportation workspace

Primary path:

```text
Composition
→ Suppliers
→ ABC Motorcoach
→ Transportation Agreement
```

Sections:

1. Agreement overview
2. Segments
3. Coach capacity
4. Supplier rates
5. Charter amount due
6. Deadlines
7. Review
8. Supplier confirmation and activation

The ordinary path does not reproduce generic M3 planning navigation.

## 22. Segment editor

Each save writes one stable Item.

**Route.** Segment name, pickup, drop-off.

**Schedule.** Service date, pickup time, optional drop-off time, time zone.

**Motorcoach.** Passenger capacity per motorcoach, confirmed motorcoaches, additional motorcoaches available on request.

**Rate.** Rate per confirmed motorcoach.

**Deadline.** Final passenger and luggage count due.

## 23. Agreement summary

Initial ABC terms:

```text
ABC Motorcoach
Smith Family Reunion

Hotel → Port
Nov 6, 2027 · pickup 10:00 a.m.
Hilton Fort Lauderdale Marina → Port Everglades

1 motorcoach confirmed
15 passenger spaces
Up to 2 additional motorcoaches on request
$200 per confirmed motorcoach
Current Supplier exposure · $200
Final passenger and luggage count due Nov 3

Port → Airport
Nov 13, 2027 · pickup 9:30 a.m.
Port Everglades → Fort Lauderdale-Hollywood International Airport

1 motorcoach confirmed
15 passenger spaces
Up to 2 additional motorcoaches on request
$175 per confirmed motorcoach
Current Supplier exposure · $175
Final passenger and luggage count due Nov 10

Charter amount due
Nov 3, 2027
Hotel → Port · $200
Port → Airport · $175
Current amount · $375

Needs clarification
Cancellation terms
Payment treatment for a motorcoach confirmed after Nov 3
```

The last line is the unresolved term. It is hidden until a coach is actually effective after November 3. The cancellation line is shown because the term is unspecified from the start.

## 24. Additional confirmed coach

After activation, Staff record another coach for one segment through typed capacity maintenance.

```text
Hotel → Port
1 → 2 confirmed motorcoaches
```

The command uses shipped capacity-event authority and the shipped evidence fields. Port → Airport stays at 1 coach, 15 passenger spaces, and $175. Hotel → Port becomes 2 coaches and 30 passenger spaces, with up to 1 more coach on request. The maximum stays 45 passengers. The $200 rate is unchanged. Current Supplier exposure on that segment becomes $400, and combined current exposure becomes $575.

The charter amount due becomes $575, with lines $400 and $175, when that event is effective on or before November 3, 2027. When the event is effective after November 3, 2027, the amount due stays at the quantity effective on that date, and the summary shows Needs clarification for the new coach's payment treatment.

The screen distinguishes a rate change, which requires a successor, from the same rate applied to more confirmed units, which is the capacity event.

## 25. Successor rule

After activation, contractual changes use the shipped successor. Examples: the per-coach rate, passenger capacity per motorcoach, route, contractual schedule, the on-request ceiling, a final-count term, and the amount-due definition.

An operational confirmation of another coach at the existing rate does not by itself require a successor.

The successor keeps both segment Item ids. Governing facts on the predecessor stay unchanged. `SupplierConfirmation` is not copied.

## 26. Advanced shapes

The typed adapter supports only the contract in this plan. These remain Advanced, and the typed path does not reshape them:

- a second Occurrence on a segment;
- multiple Pools on one segment and Resource Pair;
- multiple vehicle categories on one segment;
- hourly, mileage, waiting, overtime, or minimum-hour charges;
- a cancellation ladder or cutoff;
- a specified payment rule for a coach effective after November 3;
- the financial effect of a `released` or `withdrawn` coach;
- a confirmed coach beyond `maximum_total_resource_units`;
- mixed fixed and per-passenger pricing;
- externally managed inventory;
- a usage assumption the typed save does not own;
- a custom commitment trigger.

## 27. Shared Hotel and Transportation support

Slice 3R allows shared support only where a second vertical proves the same orchestration. This plan splits that work into three times.

**Required in T.7.** Extract `ReviseConfirmedSupplierArrangementVersion` from `ReviseConfirmedHotelAgreement`, with an explicit vertical eligibility check. Transportation needs the confirmed-draft revision, and Hotel has already proved the same orchestration. T.7 does not ship a Transportation-only copy of the Hotel command.

**May extract while implementing, only where the code is actually the same.** Exact-version workspace access: editable-draft-or-governing selection, explicit version selection, stable Item resolution, and Viewer read with Staff mutation. Extract a helper when the two call sites match. Otherwise leave the Transportation access beside the Hotel access.

**After the ABC proof.** A broader refactor of confirmation-freeze infrastructure. T.6 still ships a Transportation freeze predicate. Folding that predicate into shared trigger machinery is cleanup, and the ABC proof does not depend on it.

Hotel and Transportation stay distinct typed workflows. This plan does not add a generic adapter framework for fields, screen sections, cost semantics, capacity semantics, or agreement terms.

## 28. Delivery sequence

Each slice is the implementing work this Accepted plan names. Do not ship the slices as one undifferentiated change.

### T.0 — Accept this plan

Accept this plan against the recorded compatibility gate and the Approved ABC fixture. Update the planning index. Move this file from `docs/planning/drafts/` into `docs/planning/m4-offers-and-pricing/`. Pin the implementation base.

No application code.

### T.1 — Generic occurrence compatibility

Ship `origin_name`, `destination_name`, and independently optional local start and end times, including copy, immutability, tenancy, and the same-day ordering rule.

Exit: the ABC routes and pickup times persist without Cruise port columns and without an invented drop-off time. Hotel and Cruise typed time requirements still hold.

### T.2 — Transportation foundations and segments

Ship the typed routes, shell, Arrangement open path, two stable segment Items, route and schedule editor, motorcoach Resource, the passenger-capacity label, one confirmed `resource_units` Pool per segment, and the on-request ceiling.

Exit: ABC segment topology and capacity display are complete, including 15 controlled spaces and 45 maximum possible spaces.

### T.3 — Per-coach Supplier rates

Ship the contracted per-coach rate editor, the draft Pool and usage synchronization, the exposure preview, and Advanced detection.

Exit: one coach on each segment forecasts $375. Two coaches on Hotel → Port and one on Port → Airport forecast $575, while the version is still draft.

### T.4 — Capacity-backed cost quantity

Ship the opt-in quantity authority in `EvaluateSupplierCostForecast` and the exposure projection's use of that result.

Exit: activate at one coach per segment. Increase Hotel → Port to two coaches. The rate stays $200. That segment's current exposure becomes $400. Port → Airport stays $175. An increase whose effective time has not arrived does not raise exposure. A release leaves the billable exposure at $400 and shows Needs clarification for the financial effect. A Hotel room forecast is unchanged.

This slice lands before the typed lifecycle claims that a same-rate coach addition is supported.

### T.5 — Deadlines and charter amount due

Ship the final-count Deadline workflow and `SupplierAmountDueDefinition`.

Exit: the November 3 and November 10 Deadlines exist as separate records from the amount due. One coach each derives $375 with both segment lines. A coach effective on or before November 3 derives $575 with both segment lines. Recording that same coach later, with an effective time on or before November 3, also derives $575. A coach effective after November 3 leaves the amount due unchanged and shows Needs clarification. A release effective on or before November 3 does not reduce the amount. No Supplier Payment ledger exists.

### T.6 — Review, confirmation, freeze, and activation

Ship the write-free review, the confirmation gate, exact-version Supplier confirmation, the Transportation freeze, activation, typed blocker text, and Viewer and cross-agency proof.

Exit: agreement-defining edits fail after confirmation. A later capacity event still succeeds. Cancellation and the unspecified late-coach term do not block confirmation.

### T.7 — Lifecycle

Ship governing read mode, successor creation, stable segment identities, and `ReviseConfirmedSupplierArrangementVersion`. Complete the canonical ABC system proof and the planning-index update.

T.7 includes that revision command because Transportation uses it and Hotel has already proved the same shape. Workspace-access helpers stay optional during implementation. Confirmation-freeze infrastructure cleanup waits until after this proof.

## 29. Required proof

The browser proof covers:

1. Open ABC Motorcoach from Composition.
2. Create exactly two stable segments.
3. No Airport → Port Item exists.
4. Save the pickup and drop-off values in `origin_name` and `destination_name`.
5. Save the pickup times with a null drop-off time.
6. Record 15 passengers per motorcoach.
7. Record one confirmed coach per segment.
8. Record up to two additional coaches on request.
9. Show 15 controlled spaces, up to 2 coaches still on request, and a maximum of 45 passengers. The 45 stays outside controlled inventory.
10. Record the $200 and $175 contracted rates.
11. Show initial current exposure of $375.
12. Record the November 3 and November 10 final-count Deadlines.
13. Record the November 3 charter amount due at $375, with the $200 and $175 lines, on a different record from the November 3 Deadline.
14. Supplier-confirm the reviewed agreement while cancellation remains Needs clarification.
15. Show that agreement-defining edits fail after confirmation, and that completing a final-count Deadline still succeeds.
16. Activate.
17. Confirm another Hotel → Port coach, effective on or before November 3, through capacity authority.
18. Show Hotel → Port at 2 coaches, 30 controlled spaces, up to 1 coach still on request, and a maximum still of 45 passengers. Show $400 current exposure on that segment. Port → Airport stays at 1 coach, 15 spaces, and $175. Combined current exposure is $575. The charter amount due is $575, with lines $400 and $175.
19. Release that second coach. Controlled capacity returns to 1. Billable exposure stays $400. The amount due stays $575. The summary shows Needs clarification for the release's financial effect.
20. Record a separate coach increase effective after November 3. Controlled capacity and current exposure follow that increase. The November 3 amount due stays unchanged. The summary shows Needs clarification for that coach. Remaining on request still respects the total ceiling of 3.
21. On Port → Airport, record an increase after November 3 whose effective time is November 2. The due-date replay moves that segment's amount-due line from $175 to $350. Hotel → Port's amount-due line stays at the figure from its own events.
22. Create a successor for a contractual rate change.
23. Show that both segment Item ids survive and that the governing version's facts stay unchanged.
24. Show Viewer read-only behavior and cross-agency not-found behavior.
25. Finish the supported path without opening generic Supplier planning.

## 30. Explicit non-goals

This plan does not authorize Airport → Port, Client transfer prices, a Client Service connection, Package placement, Client transfer choices, traveler manifests, traveler assignments, Supplier Payment posting, invoices, Obligations, settlement, cancellation calculation, overtime or waiting calculation, Air, Rail, Activity, Meal, Excursion, a mixed-DMC workflow, a universal non-Cruise adapter framework, M4E, or M5.

## 31. Acceptance decisions

Accepting this plan approves all of the following:

1. `maximum_occupancy` is passenger capacity per motorcoach on the typed Transportation Resource. The driver does not consume it.
2. Generic `origin_name` and `destination_name` are added to occurrence definitions. Cruise port columns stay Cruise-only. ADR 0008 is amended.
3. Local start and end times may each be omitted. Hotel and Cruise typed forms keep their existing time requirements. A same-day occurrence with both times requires the end time to be on or after the start. ADR 0008 is amended.
4. `maximum_total_resource_units` lives on the block Pool definition and is written only by the Transportation command. Remaining on request is the total ceiling minus the current confirmed quantity, and never below zero. The passenger maximum uses the total ceiling, so confirming a coach does not raise it. A coach beyond that ceiling stays Advanced.
5. A supported draft Transportation save sets the Pool opening quantity and the owned `expected_resource_units` together.
6. An opted-in contracted unit-rate component takes its billable quantity from `established` and currently effective `increased` events. A not-yet-effective increase waits. A `released` or `withdrawn` event does not reduce Supplier cost. ADR 0011 is amended. Qualified exposure follows that billable forecast.
7. The November 3 charter amount is `SupplierAmountDueDefinition`. After activation its quantity is `quantity_at(pool, due_on)`, a replay of `established` and `increased` events effective on or before the end of the due date. A later-recorded event with an earlier effective time recomputes the amount. A capacity decrease does not reduce it. It is not a Deposit Requirement, not `current_supplier_capacity`, and not a Supplier Payment. ADR 0013 is amended.
8. A coach effective after November 3, 2027 changes capacity and current exposure, leaves the amount due unchanged, and is shown as Needs clarification. A release likewise leaves billable exposure and the amount due unchanged. Cancellation stays Needs clarification. None of these terms block confirmation or activation, and none adds an agreement-reference kind.
9. Supplier confirmation freezes the agreement-defining Transportation facts in section 18. It does not freeze later operational capacity events, nor completing, rescheduling, or waiving a Deadline where shipped authority already allows that action. The lodging freeze predicate is not extended.
10. Arrangement activation, successor copying, and audit of the Supplier Arrangement stay authoritative.
11. T.7 extracts the confirmed-draft revision command. Exact-version workspace access may be shared only where the implementations match. Confirmation-freeze infrastructure refactoring waits until after the ABC proof.

## 32. Exit

Transportation Supplier Composition is complete when ABC Motorcoach can be operated through Composition, the Transportation Agreement, segments, route and schedule, coach capacity, Supplier rates, Deadlines and charter amount due, review, Supplier confirmation, activation, a same-rate additional coach, governing read mode, and a successor for a contractual change.

The completed path stores real pickup and drop-off values, stores a pickup time without an invented drop-off time, keeps passenger spaces as a derivation, treats the on-request ceiling as outside controlled inventory, derives the November 3 amount from effective coach quantities and segment rates, leaves a post-November 3 coach's payment treatment unspecified, and leaves Supplier-confirmed contractual terms unchanged. It does not add a parallel Transportation lifecycle or a Client or traveler record.
