# DepartureDesk Cruise Remediation — Supplier Agreement, Contracted Rates, Deposits, and Amendments

**Status:** Aligned 2026-09-27 with the accepted Cruise rework decision plan. Detailed delivery notes. Where this file previously required an optional confirmation document, one shared policy engine, or a generic yes/no supplemental-deposit feature, the accepted decision plan governs.

This plan replaces the current Cruise rework draft as the proposed implementation authority once **Gate 0** is complete and this document is marked Accepted.

It remediates the shipped M4D.1 Cruise workflow where the Celebrity Beyond fixture exposed incorrect or incomplete semantics around:

- Supplier agreement confirmation;
- estimated versus contracted rates;
- Cruise activation;
- Supplier deposit requirements;
- booking-dependent cabin deposit policy;
- Cruise deadlines;
- later capacity increases and supplemental cabin blocks; and
- the boundary between Supplier inventory and published Client offers.

Optional departure and return ports, itinerary notes, and commercial-benefit terms remain governed by the already accepted Cruise ports/commercial-benefits work. This remediation does not reopen those decisions.

The accepted Hotel walkthrough remains separate. This plan does not alter Hotel behavior or authorize Slice 3A implementation.

---

## 1. Product boundary

The Cruise workflow ends with an accurate, reviewed Supplier Arrangement and an explicit handoff to the existing Offer Design workflow.

This remediation does **not** create or implement:

- Client Trips;
- Travelers;
- cabin allocations;
- Supplier Payments;
- receipts;
- Supplier Obligations for individual cabin deposits;
- refunds;
- card records;
- attribution of an initial group deposit to a particular cabin;
- automatic release of Supplier inventory; or
- automatic changes to Client prices or published Client availability.

Staff must continue to be able to save the major Supplier-planning sections independently.

A failed save in one section must retain the Staff-entered values for correction and must not mutate a valid sibling section.

The UI and domain must distinguish:

1. the currently governing Arrangement/version;
2. an unactivated draft;
3. a proposed successor to a governing Arrangement; and
4. historical superseded facts.

---

# Gate 0 — Correct authority before changing code

No implementation slice in this plan begins until the documentation describing the Celebrity scenario and the accepted architecture agree.

## 0.1 Accept the canonical Celebrity fixture

Promote the revised **Celebrity Beyond 2027 canonical scenario** from Draft to Accepted after its figures and terms have been reconciled with the supplied agreement.

The accepted fixture must explicitly establish at least:

- Celebrity Cruises;
- Celebrity Beyond;
- 7-Night Eastern Caribbean;
- November 6–13, 2027;
- Supplier group number `1119999`;
- group creation date;
- contract date;
- E3, O1, and DI opening cabin blocks;
- eight opening cabins in each category;
- 24 total initially blocked cabins;
- $50 initial deposit per initially blocked cabin;
- $1,200 initial Supplier deposit requirement;
- the $500 total deposit policy for an allocated cabin;
- July 9, 2027 Hard Stop;
- August 8, 2027 final payment;
- the accepted cabin-rate examples and occupancy calculations;
- normal commission;
- the Tour Conductor benefit;
- the four group GAP points; and
- any cancellation/card restrictions supported by the source agreement.

The fixture must no longer present the following as current Celebrity facts:

- the previous E1/O1 fixture values where superseded;
- March 11 as an Arrangement-wide cumulative `$500 × retained cabins` deposit target;
- July 9 as the final-payment deadline;
- October 7 as a rooming-list deadline without source authority; or
- five GAP points per traveler.

Historical planning documents may retain those values as historical decisions, but must carry an explicit supersession note where necessary to prevent them from being mistaken for current authority.

## 0.2 Amend accepted architecture

Update the affected accepted documents before implementation.

### ADR 0008 — versioning

Clarify:

- Supplier agreement confirmation belongs to an exact Arrangement revision/version;
- a governing confirmed Arrangement may coexist with an unconfirmed proposed successor;
- confirmation facts are immutable;
- correction supersedes rather than overwrites the previous confirmation fact;
- an amendment has its own agreement/amendment date without changing the original historical contract date; and
- activation never rewrites prior activated definitions or confirmation history.

### ADR 0012 — activation and Supplier confirmation

Separate **Supplier agreement confirmation** from Reservation confirmation.

For Cruise:

- provisional Supplier planning may exist before Supplier confirmation;
- the Supplier group reference may be entered provisionally;
- Supplier confirmation requires the Supplier group reference and contract date;
- confirmation records actor and time;
- a confirmation note is optional; this remediation adds no agreement document;
- confirmation covers the Supplier agreement scope of that exact Arrangement version;
- Staff may complete contracted-rate transcription for Resources already in that scope without another confirmation;
- adding a Resource or otherwise changing that scope requires a successor and its own confirmation;
- Cruise activation requires both agreement confirmation and ready contracted rates for every cabin Resource in that scope.

Preserve the existing generic non-Cruise activation contract. A non-Cruise Arrangement that is otherwise valid may continue to activate using a ready estimate where existing M3 authority permits it.

Do not represent Cruise agreement confirmation by manufacturing a Reservation confirmation.

### ADR 0010 — capacity

Clarify the distinction between:

- an evidenced increase to an existing Pool under unchanged governing terms; and
- additional Supplier inventory whose rates, deposit treatment, release terms, or other material Supplier terms differ.

The first is a capacity event on the existing Pool.

The second requires a successor Arrangement version and a distinct Resource/Pool/rate-source graph.

Preserve the immutable capacity ledger, evidence requirements, Pool identity, and explicit release semantics.

### ADR 0011 — Supplier costs

Do not change the generic estimate/contracted stage model.

Clarify that:

- estimate and contracted definitions are distinct siblings;
- changed-cost supplemental Cruise inventory receives its own Resource-scoped cost source;
- Pool identity or a display label is not cost authority; and
- this remediation does not introduce Pool-scoped Supplier cost definitions.

### ADR 0013 / M3E Supplier operational control

Replace the Celebrity-specific Arrangement-wide cumulative final-deposit example with the corrected model:

- opening-block initial deposit is a quantity-derived Supplier requirement;
- allocated-cabin deposit is booking-dependent Supplier policy;
- July 9 is the combined Hard Stop;
- August 8 is final payment.

Do not remove the generic cumulative-requirement mechanism. Other Supplier agreements may legitimately use it.

### M4D.1 Cruise slices

Mark the conflicting Cruise-specific behavior as superseded by this remediation.

Preserve:

- stable Resource identity;
- exact-context Supplier cost sources;
- independent section saves;
- occupancy previews;
- Advanced fallback for unsupported graphs;
- existing Client offer source pins;
- published-version immutability; and
- existing generic Composition workspace behavior.

## 0.3 Explicit deferrals

Gate 0 also records three deliberate deferrals.

### Richer sailing time zones

Do **not** add separate departure and return time-zone authority in this remediation.

Retain the currently supported Occurrence time-zone model.

Cruise UI must not imply that separately displayed departure-port and return-port local times are authoritative when the domain cannot represent them independently.

A later schedule-model amendment may add independent endpoint times/zones.

### Generic agreement document storage

Supporting Supplier agreements and addenda remain optional evidence.

Do not build a Cruise-specific file subsystem in this remediation.

If generic Arrangement document storage is not already accepted and available, the Cruise confirmation contract must work without an uploaded file.

Uploading a file must never itself:

- confirm an agreement;
- make rates contracted;
- activate an Arrangement; or
- extract authoritative terms automatically.

### Tour Conductor and GAP benefits

Normal commission remains typed Supplier economics.

Tour Conductor and GAP benefits remain readable Supplier agreement terms in this remediation.

For the Celebrity fixture, review must be able to communicate the sourced terms, including the Tour Conductor credit and four group GAP points, without pretending DepartureDesk has implemented qualification, accrual, redemption, or settlement.

Typed benefit entitlement/accounting belongs to a later accepted slice.

## Gate 0 exit criteria

Gate 0 is complete only when:

- the canonical Celebrity fixture is Accepted;
- this plan is Accepted;
- affected ADRs and planning documents agree with both;
- superseded Celebrity assumptions are explicitly identified;
- no active accepted document still instructs implementation of the obsolete Celebrity cumulative final-deposit model or unsupported rooming-list deadline; and
- the implementation branch is pinned to a green `main` descendant containing those authority changes.

---

# R1 — Supplier agreement confirmation and contracted rates

R1 establishes the two facts Cruise activation actually depends upon:

1. the Supplier has confirmed the agreement; and
2. Staff have recorded and reviewed contracted rates.

These remain independent facts.

## R1.1 Estimated and contracted rate definitions

Continue using the existing Supplier cost-source and definition architecture.

For a Cruise cabin Resource, Staff may first enter an **estimated** definition.

Add the typed action:

> **Record contracted rates**

The command:

1. loads the exact Cruise Resource and cost source;
2. verifies that a contracted sibling does not already exist for the applicable context;
3. copies the current estimated definition into a new contracted definition;
4. preserves the estimated definition unchanged;
5. records normal provenance/idempotency information;
6. leaves the new contracted definition available for Staff review and correction; and
7. does not mark the contracted definition ready merely because it was copied.

Staff then review the contracted cells, correct them where necessary, and explicitly make the contracted definition ready using the existing readiness contract.

Forecasting and activation use the appropriate ready contracted definition once it exists.

No command converts the estimate itself into contracted data.

## R1.2 Stage-specific typed editing

The Cruise rate editor must make the active stage explicit.

Staff must be able to distinguish:

- Estimated;
- Contracted — draft/not ready;
- Contracted — ready.

The typed detector must select the exact definition for the requested stage and context.

It must not silently choose an arbitrary working definition when multiple definitions exist.

Unsupported or ambiguous graphs fall back to Advanced rather than guessing.

## R1.3 Cruise agreement confirmation event

Introduce a dedicated, immutable Cruise Supplier-agreement confirmation fact associated with the exact Arrangement revision/version.

The persisted confirmation must identify at least:

- Agency;
- exact Arrangement/version or equivalent immutable revision identity;
- Supplier group reference;
- contract/agreement date;
- `confirmed_at`;
- `confirmed_by`;
- optional Staff note.

This remediation adds no document identifier.

The confirmation represents:

> The Supplier has confirmed this whole agreement revision.

It does not mean:

- every rate has been transcribed;
- every rate has been reviewed;
- the Arrangement is activated;
- a payment has been made; or
- a Client offer exists.

## R1.4 Provisional agreement facts

Before confirmation:

- group creation date is required for the typed Celebrity workflow;
- Supplier group reference may be blank or provisional;
- contract date may be blank;
- both may be edited normally.

To mark the agreement Supplier-confirmed:

- Supplier group reference is required;
- contract date is required.

After confirmation, ordinary editing cannot change those confirmed values.

A factual correction uses an explicit correction/supersession path that preserves the prior confirmation values and audit history.

## R1.5 Confirmation may precede rate completion

Staff may record Supplier confirmation before contracted rates are ready for Resources already inside that confirmed scope. Adding a Resource is not transcription of an existing Resource.

This is intentional.

The UI must therefore distinguish, for example:

> Supplier confirmed  
> Contracted rates incomplete

from:

> Supplier confirmed  
> Contracted rates ready

## R1.6 Cruise activation gate

A Cruise Arrangement/version cannot activate unless:

- its agreement revision is Supplier-confirmed;
- every cabin Resource covered by that revision has the required ready contracted Supplier rate definition;
- required Cruise capacity/inventory facts are valid;
- existing generic activation invariants pass; and
- the activation preview/review succeeds.

This Cruise-specific requirement does not alter generic non-Cruise activation.

## R1 proof

Automated and browser proof must demonstrate:

- provisional Cruise saved without a Supplier group reference;
- provisional reference can be added and changed;
- confirmation fails without required reference/date;
- confirmation succeeds with reference/date and no note/file;
- confirmation can occur while contracted-rate transcription remains incomplete;
- activation remains blocked in that state;
- estimated O1 rates remain unchanged after **Record contracted rates**;
- the copied contracted O1 definition can be independently edited and made ready;
- forecasting selects the ready contracted definition where appropriate;
- duplicate contracted-stage creation is rejected/idempotent as applicable;
- confirmed reference/date cannot be changed by ordinary edit;
- explicit correction preserves the prior confirmation;
- activation succeeds only when confirmation and contracted-rate requirements both pass; and
- generic non-Cruise ready-estimate activation behavior remains green.

---

# R2 — Celebrity Supplier commitments, deadlines, and booking-dependent policy

R2 replaces the incorrect Celebrity deposit/deadline representation without introducing booking-level accounting.

## R2.1 Initial blocked-cabin deposit

For the canonical opening block:

| Category | Opening cabins |
| --- | ---: |
| E3 | 8 |
| O1 | 8 |
| DI | 8 |
| **Total** | **24** |

Supplier initial deposit:

`24 cabins × $50 = $1,200`

Due date:

**October 13, 2026**

The requirement must retain traceability to:

- the selected Pools;
- each Pool's opening quantity;
- the `$50` unit amount; and
- the resulting `$1,200` requirement.

This is a Supplier requirement.

It is not evidence that the Agency paid Celebrity.

It is not yet an attribution of `$50` to each future allocated cabin.

## R2.2 Later changes do not mutate the opening snapshot

The initial `$1,200` requirement represents the accepted opening block.

A later Pool increase must never silently recalculate that historical requirement.

Additional-deposit treatment is handled explicitly under R3.

## R2.3 Booking-dependent allocated-cabin policy

Remove the Celebrity-specific Arrangement-wide:

> `$500 × retained cabins`

final-deposit tranche.

Record the `$500` allocated-stateroom rule, its credit and timing, and the card restrictions as readable versioned agreement data. Record the cancellation ladder as its own structured informational data on the same version. Do not introduce a shared policy engine.

- `$500 total Supplier deposit per allocated stateroom`;
- an attributable portion of the initial group deposit may count toward that total;
- legal-name/allocation timing affects when the requirement becomes applicable;
- shorter Supplier option periods may accelerate the requirement;
- the July 9 Hard Stop bounds the remaining inventory decision; and
- applicable card restrictions.

The `$500` rule and the cancellation ladder are separate versioned terms on the agreement revision. They follow draft, copy, and freeze with that version. They do not share a policy engine.

The policy is deliberately **nonmaterializing** in this remediation.

It cannot create:

- a cabin-level Supplier Obligation;
- a Supplier Payment;
- a `$500` balance for an unallocated cabin;
- a deposit credit;
- a Traveler requirement; or
- a booking transaction.

Those require later booking/allocation/payment authority.

## R2.4 Dated Supplier actions

For the Celebrity fixture, model:

### July 9, 2027 — Hard Stop

One combined actionable Supplier deadline representing the sourced decision point for remaining cabin inventory and allocated stateroom requirements.

The UI must present the combined business meaning rather than manufacturing separate deadlines that imply independent Supplier events.

Passing the deadline does not automatically release inventory or post money.

### August 8, 2027 — Final payment

One actionable Supplier final-payment deadline.

Passing the deadline does not automatically post a payment.

### No October 7 rooming-list action

Do not create an October 7, 2027 rooming-list deadline for this fixture unless later sailing-specific source authority establishes one.

## R2.5 Group-creation-relative initial due date

Where the source term is represented as group creation plus 30 days, the typed workflow may calculate and suggest the resulting fixed date.

Once Staff save the Supplier deadline/requirement, changing group creation date must not silently rewrite the saved consequential date.

Instead, surface the mismatch for Staff review.

## R2 proof

Activation preview and Supplier review for Smith Family Reunion must show:

- 24 opening cabins;
- `$50` per selected opening cabin;
- `$1,200` initial Supplier requirement;
- October 13, 2026 due date;
- July 9, 2027 combined Hard Stop;
- August 8, 2027 final payment;
- readable `$500 per allocated stateroom` policy;
- applicable credit/timing/short-option/card/cancellation wording;
- no Arrangement-wide cumulative `$500 × retained cabins` final-deposit requirement; and
- no October 7 rooming-list deadline.

Tests must also prove:

- the initial requirement's quantity trace is stable;
- changing group creation date after saving does not silently rewrite the requirement;
- failed policy/deadline saves do not mutate rates or sibling actions;
- existing historical Supplier commitment records are preserved rather than rewritten; and
- policy records cannot materialize booking-level money.

---

# R3 — Amendments, later capacity, and supplemental cabin blocks

R3 defines what happens after the governing Cruise Arrangement is active.

The first question is:

> Is this additional inventory governed by the same Supplier terms?

That answer determines the path.

## R3.1 Same-terms capacity increase

If Celebrity adds cabins under the same governing:

- cabin category;
- Supplier rates;
- deposit treatment;
- release terms; and
- other material Supplier agreement terms,

Staff record an evidenced capacity increase on the existing Pool.

Example:

> Existing O1 Pool: 8 cabins  
> Celebrity adds: 4 O1 cabins  
> New Pool capacity: 12 cabins

The existing Resource, Pool, and contracted rate source remain authoritative.

The increase is an immutable capacity event.

It does not create a new Resource merely to represent a second Supplier conversation.

## R3.2 Additional initial-deposit decision

A same-terms capacity increase never mutates the original `$1,200` opening-block requirement.

No later Supplier capacity inherits an initial-deposit treatment implicitly. The canonical same-terms `+4` O1 case records `$50 × 4 = $200` and leaves `$1,200` unchanged. The changed-terms fixture prescribes no deposit amount or formula. Any applicable treatment must be recorded explicitly before that successor can govern. Do not add a reusable yes/no supplemental-deposit framework.

Example:

`4 additional cabins × $50 = $200`

The `$200` requirement traces to the capacity event rather than recalculating the opening snapshot. There is no implicit default that changes historical money.

## R3.3 Changed Supplier terms require a successor

If the additional cabins have different:

- rates;
- deposit treatment;
- release terms; or
- other material agreement terms,

they do not increase the existing Pool.

Staff create or continue a proposed successor Arrangement/version.

The supplemental inventory receives:

- a distinct Cruise Resource;
- a distinct Pool;
- a distinct exact-context Supplier rate source;
- its own applicable Supplier terms; and
- a distinct internal block label.

The governing active Arrangement remains authoritative while the successor is being prepared.

## R3.4 Duplicate real Supplier category codes

The Supplier category code remains a factual Supplier identifier.

DepartureDesk must not invent a fake Supplier code merely to force uniqueness.

Therefore two Supplier blocks may both truthfully carry:

> `O1`

when Celebrity identifies both as O1.

DepartureDesk distinguishes them by immutable internal Resource identity and a Staff-visible internal **block label**.

When the same Supplier code would otherwise make two blocks ambiguous, a distinct block label is required.

Examples of acceptable internal labels might describe the actual distinction, such as:

- `Original group block`
- `September supplemental block`

The label is DepartureDesk identification, not a Supplier category code and not cost authority.

## R3.5 New agreement confirmation

A successor containing materially changed Supplier terms requires confirmation of the amended whole agreement before that successor can activate.

The existing governing confirmation remains historical and valid for the governing version while the successor is proposed.

The amendment:

- does not overwrite the original contract date;
- records its own agreement/amendment date;
- receives its own immutable Supplier confirmation; and
- must satisfy the R1 contracted-rate activation requirements for its covered cabin Resources.

## R3.6 Supplemental deposit treatment

The additional-deposit question applies to both paths:

- same-terms Pool increase; and
- differently termed supplemental block.

The answer must be explicit.

The system must not infer a Supplier monetary obligation merely because capacity increased.

## R3 proof

### Same-terms scenario

Starting with 8 O1 cabins:

- add 4 O1 cabins under unchanged terms;
- record evidence;
- existing Pool becomes 12;
- existing Resource and contracted rate source remain authoritative;
- immutable capacity history shows the +4 event;
- original `$1,200` requirement remains unchanged;
- selecting additional `$50` treatment creates a separate `$200` requirement;
- declining supplemental deposit treatment records the explicit supported decision instead.

### Changed-terms scenario

Starting with the same governing O1 block:

- add 4 additional O1 cabins at different Supplier rates;
- retain real Supplier code `O1`;
- require a distinct internal block label;
- create a new Resource;
- create a new Pool;
- create a new exact-context rate source;
- record/review contracted rates for the supplemental Resource;
- confirm the amended whole agreement;
- activate only the successor version once its requirements pass.

Supplier summaries must make the two O1 blocks unambiguous without inventing a second Celebrity category code.

Existing Resource, Pool, cost, confirmation, and capacity histories remain unchanged.

Unsupported historical graphs remain readable through Advanced fallback.

---

# R4 — Explicit Offer Design handoff

R4 protects Client-facing offers from Supplier-side inventory changes.

Supplier capacity and Client offer availability are related, but they are not the same record or transition.

## R4.1 Same-terms capacity does not silently alter published Client availability

Increasing an existing Supplier Pool does not automatically:

- change a published Client choice;
- increase a published selectable quantity;
- change a Client price;
- replace a source pin; or
- republish an offer.

The Supplier-side increase becomes information that Offer Design may review.

## R4.2 Supplemental blocks begin Supplier-only

A new supplemental Resource/Pool/rate source exists only in Supplier planning until Staff explicitly enters the Offer Design workflow and decides how it should be presented to Clients.

There is no automatic Client choice creation.

There is no automatic attachment to an existing O1 choice.

## R4.3 First supported presentation

Where truthful, Staff may expose a supplemental Supplier block as a distinct Client-facing option with:

- an explicit Client-facing description;
- an explicit source binding;
- independently reviewed Client pricing; and
- the normal draft/publication workflow.

## R4.4 Multiple Supplier blocks behind one Client choice are deferred

This remediation does not allow one existing Client choice to consume interchangeable capacity from multiple Supplier Pools merely because they share Supplier code `O1`.

That requires a separate accepted alternative-source/selection contract covering:

- source selection;
- capacity;
- pricing;
- margin;
- availability;
- publication pins; and
- deterministic fulfillment.

Until then, distinct Supplier blocks remain distinct sources.

## R4.5 Published immutability

A previously published Client offer remains pinned to the source/version and Client price that was published.

Later Supplier cost or capacity changes may create findings requiring Staff attention, but they do not silently rewrite published Client facts.

## R4 proof

Given an already published O1 Client choice:

1. increase its governing Supplier Pool under unchanged terms;
2. prove the published choice/source/Client price remains unchanged;
3. prove selectable Client quantity does not silently increase merely because Supplier capacity increased;
4. create a differently priced supplemental O1 Supplier block;
5. prove it does not join the existing published choice;
6. enter Offer Design explicitly;
7. create a separate draft Client option for that block where appropriate; and
8. prove publication requires the normal explicit publication path.

Price/margin, capacity, source-compatibility, and publication-pin findings must be reevaluated through the existing Offer Design contracts.

---

# Closure — Integrated Smith Family Reunion proof

After R1–R4 merge, run one integrated browser/system proof from the Composition workspace.

## Scenario

Create or rebuild the canonical Smith Family Reunion Supplier plan.

### Sailing

Record the supported Celebrity Beyond sailing facts for:

- November 6–13, 2027;
- 7-Night Eastern Caribbean;
- supported Occurrence zone;
- group creation date; and
- USD inherited from the Departure operating currency.

Do not use the closure proof to introduce unsupported independent endpoint-zone semantics.

### Opening cabin block

Create:

- E3 — 8;
- O1 — 8;
- DI — 8.

Each has stable Resource and Pool identity.

### Rates

For each category:

1. save estimated rates;
2. use **Record contracted rates**;
3. prove the estimate remains;
4. review/correct the contracted copy;
5. make the contracted definition ready; and
6. verify the accepted occupancy previews.

### Agreement confirmation

Record:

- Supplier group reference `1119999`;
- contract/agreement date;
- immutable Supplier confirmation actor/time.

Prove the confirmation can exist independently from rate readiness but cannot by itself activate the Arrangement.

### Supplier requirements and actions

Record/review:

- `$1,200` initial blocked-cabin Supplier requirement;
- October 13, 2026 due date;
- July 9, 2027 Hard Stop;
- August 8, 2027 final payment; and
- readable booking-dependent `$500 per allocated stateroom` policy.

Prove no false Arrangement-wide final-deposit tranche and no unsupported October 7 rooming-list deadline exist.

### Commercial benefits

Review normal commission as typed Supplier economics.

Display the accepted Celebrity Tour Conductor and GAP terms as readable agreement benefits without claiming typed entitlement/accrual functionality.

### Activation

Preview activation.

Prove activation is blocked until:

- agreement confirmation exists; and
- all required contracted cabin rates are ready.

Activate the exact reviewed version.

Reopen it and prove governing facts are stable/read-only according to existing versioning rules.

### Same-terms amendment

Add four O1 cabins under unchanged terms.

Prove:

- existing Pool receives an evidenced +4 event;
- existing contracted rate authority remains;
- opening `$1,200` requirement does not change; and
- supplemental deposit treatment is an explicit decision.

Exercise the `$50 × 4 = $200` supplemental-requirement path.

### Changed-terms amendment

Create a proposed successor with four additional differently priced O1 cabins.

Prove:

- real Supplier code remains `O1`;
- a distinct internal block label makes the blocks unambiguous;
- a new Resource/Pool/rate source exists;
- governing O1 history remains unchanged;
- the proposed successor requires a new whole-agreement Supplier confirmation; and
- it cannot activate until its contracted rates and confirmation satisfy R1.

### Offer Design

Prove:

- the original published O1 source pin remains exact;
- its Client price remains unchanged;
- added Supplier capacity does not silently change published selectable quantity;
- the supplemental block remains Supplier-only until explicit Offer Design review; and
- exposing it to Clients requires an explicit draft/publication action.

---

# Cross-cutting implementation invariants

Every remediation slice must preserve the following.

## Tenant and authorization

All records and commands remain Agency-scoped.

Use existing Composition/Supplier-planning authorization. Do not create a Cruise-specific authorization model.

Viewer behavior remains read-only.

## Idempotency

Consequential commands use the existing Agency command-idempotency contract.

Replaying a successful command must not duplicate:

- confirmations;
- contracted definitions;
- capacity events;
- Supplier requirements; or
- successor structures.

## Locking

Follow the lock order already established by the affected M3/M4 command contracts.

This plan does not authorize a new global lock order.

Where new records participate in an existing consequential command, document their position before implementation.

## History

Never rewrite an activated historical record merely to conform it to the corrected Celebrity fixture.

In particular, do not rewrite:

- activated Supplier cost definitions;
- Supplier confirmations;
- Supplier identifiers;
- capacity events;
- Supplier commitment history;
- published Client offer versions; or
- published source pins.

Where shipped test/development Celebrity data embodies superseded semantics, use an explicit migration, disposition, repair, successor, or fixture replacement appropriate to whether the data is authoritative or disposable.

## Exact-version behavior

Confirmation, contracted-rate readiness, Supplier policy, activation, and Client source bindings must refer to the intended exact governing/draft version.

A fact attached to one Arrangement version must not satisfy a successor merely because both versions describe the same sailing.

## Independent saves

Sailing, cabin blocks, rates, confirmation, requirements, deadlines, and policy remain independently saveable where the accepted workflow allows it.

Validation failure in one section must not mutate a valid sibling.

## Advanced fallback

Typed Cruise UI must detect whether the underlying graph is representable by the typed workflow.

When it is not, show the existing Advanced path rather than guessing, normalizing, or destroying the graph.

---

# Delivery order

Implementation order is fixed:

**Gate 0 → R1 → R2 → R3 → R4 → Closure**

Do not begin a later remediation slice because part of its UI is convenient to build alongside an earlier slice.

Each slice should be independently reviewable and mergeable, with its own migrations, commands, tests, UI, and documentation changes required for that slice.

R1 establishes the authority required by later slices.

R2 corrects the canonical Supplier obligations/policy before amendment behavior builds upon them.

R3 depends on R1 confirmation/rates and R2 supplemental-deposit semantics.

R4 depends on R3 establishing distinct supplemental Supplier sources.

Closure begins only after R1–R4 are merged.

---

# Authorization relative to Hotel work

Acceptance of this plan makes this Cruise remediation the next authorized implementation sequence.

The accepted Hotel walkthrough and Hilton fixture remain valid planning authority for their own domain, but **Hotel Slice 3A remains unauthorized for implementation while this Cruise remediation is active**.

Completing this remediation does not itself modify Hotel semantics.

After Cruise closure, the project may return to Slice 3A unless a later accepted planning decision changes that ordering.

---

# Explicit non-goals

This remediation does not implement:

- Client Trip;
- Traveler;
- cabin allocation;
- cabin assignment;
- Supplier Payment;
- Client Receipt;
- booking-level Supplier Obligation;
- refund;
- deposit-credit matching;
- card storage or processing;
- automatic Supplier inventory release;
- automatic contract parsing;
- automatic Client-price changes;
- automatic publication;
- one Client choice consuming multiple Supplier Pools;
- a general Supplier-policy formula engine;
- typed Tour Conductor entitlement/accrual;
- typed GAP entitlement/redemption;
- independent departure-port and return-port time-zone authority;
- Cruise-specific agreement-file storage;
- generic relaxation of capacity-event evidence; or
- rewriting historical authoritative records to make the new fixture pass.

---

# Definition of done

The Cruise remediation is complete when:

1. the accepted Celebrity fixture, ADRs, planning documents, implementation, and browser proof describe one consistent Supplier workflow;
2. Supplier confirmation and contracted-rate readiness are independent facts;
3. Cruise activation requires both;
4. estimates survive creation of contracted definitions;
5. the Celebrity opening deposit is correctly represented as `$1,200`;
6. the `$500 per allocated stateroom` term is represented as booking-dependent Supplier policy rather than fictitious Arrangement-wide money;
7. July 9 and August 8 have their correct operational meanings;
8. no unsupported October 7 rooming-list deadline is generated;
9. same-terms additional capacity preserves the existing Pool/rates and receives an explicit supplemental-deposit decision;
10. changed-term inventory creates a successor with distinct Resource/Pool/rate authority;
11. duplicate real Supplier category codes remain truthful and are disambiguated by internal block identity;
12. Supplier-side additions cannot silently alter published Client choices, prices, quantities, or source pins;
13. Tour Conductor/GAP terms remain visible without claiming unimplemented entitlement accounting;
14. historical activated and published facts remain immutable;
15. the integrated Smith Family Reunion browser proof passes; and
16. the planning index, roadmap, interface contract, terminology, test fixtures, and relevant implementation documentation identify this remediation as the current Cruise authority.

At that point, the superseded Cruise-specific portions of the shipped M4D.1 Slice 2 plans remain historical implementation records rather than current behavioral authority.