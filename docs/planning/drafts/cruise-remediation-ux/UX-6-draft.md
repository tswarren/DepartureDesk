### UX-6 — Maintain active and proposed Cruise supply

**Status:** Specified, not authorized.

UX-6 replaces the transitional later-capacity controls on the Supplier agreement page with a version-aware Cruise maintenance journey.

It is presentation and orchestration over the existing Supplier Arrangement version model, Pool capacity ledger, and later-capacity commands. It does not add a Cruise amendment model, inventory model, workflow state, or Client-offer behavior.

The two supported maintenance paths remain:

- **Same Supplier terms** → `RecordCruiseSameTermsCapacityIncrease` against an existing Pool on the activated governing version.
- **Changed Supplier terms** → `CreateCruiseSupplementalBlock`, which creates a successor draft and a separate supplemental O1 Resource and Pool.

The Staff answer to whether Supplier terms changed chooses one of those existing paths. It is not persisted as business state.

Advanced Supplier planning remains available for changes that the simplified Cruise maintenance journey cannot represent losslessly.

#### Version context

Once a Supplier Arrangement has both a governing activated version and a successor draft, the workspace must make the version being worked unmistakable.

The normal Cruise workspace is the draft when a successor exists, and the governing version when no draft exists. It must not merge governing and proposed facts into one apparent Cruise state.

Therefore:

- active version only → the normal workspace is the active governing version;
- active version plus successor draft → the normal workspace is the successor draft;
- creating a supplemental block → continue in the successor draft;
- activating the successor → the newly governing version becomes the normal workspace because no successor draft remains.

`DetectCruiseArrangementShape` and `set_editable_draft_version` already prefer that draft. Cabin inventory, Supplier rates, agreement and requirements, and activation review stay on this normal workspace. Do not add a version-context parameter that makes those routes switch to the governing version.

Do not allow one normal Cruise page to default to the governing version while another silently defaults to the draft.

Every normal Cruise page shows the workspace version near the page heading.

For a governing version:

> **Active · Version 1**  
> These are the Supplier terms currently in effect.

For a successor draft:

> **Draft · Version 2**  
> Proposed changes. Version 1 remains active.

The Active and Draft distinction must not rely on color alone.

When the workspace is a draft, provide **View active version**. That opens a read-only snapshot of the governing version. It does not become the workspace.

#### Read-only Active snapshot

When a successor draft exists, **View active version** shows the governing version for comparison.

The snapshot shows:

- **Active · Version 1** and that these Supplier terms are in effect;
- that Draft Version 2 is in progress;
- sailing and agreement identity;
- cabin inventory using the live Pool projection, with the original opening quantity where that fact explains the deposit;
- the governing requirements Staff need for comparison.

**Back to Draft Version 2** leaves the snapshot and returns to the normal draft workspace.

The snapshot does not link into cabin editors, Supplier rates, the agreement editor, or activation review. Those routes belong to the normal workspace and load the draft.

The only mutation on the snapshot is **Change active inventory under existing terms**. Before that form can be submitted, identify the target:

> **Changes Active Version 1**  
> This updates the live capacity of the active Supplier block. It does not edit Draft Version 2's definitions.

`RecordCruiseSameTermsCapacityIncrease` already locks the activated version. The label states that fact. UX-6 does not teach the other Cruise editors to load or post against the governing version.

Do not carry an Active context through ordinary Cruise links. Do not add an Active-context activation review. Do not accept an arbitrary version ID as navigation authority.

#### Three distinct capacity concepts

UX-6 must keep three different capacity facts separate:

1. **Original opening quantity** — `proposed_opening_quantity` on the versioned Pool definition.
2. **Current operational capacity** — the live Pool capacity projection/ledger after activation and subsequent capacity events.
3. **Supplemental proposed opening quantity** — the opening quantity on a newly proposed supplemental Pool in a successor draft.

These values must not be collapsed into one generic "cabins" number.

`proposed_opening_quantity` is not the current active cabin quantity after activation.

For an activated numeric Pool, current active cabin quantity comes from the Pool's existing capacity projection/ledger.

A same-terms increase records a capacity event against that ledger. It does not rewrite `proposed_opening_quantity`.

For example, if O1 originally opened with 8 cabins and Staff later records a same-terms increase of 4:

- original proposed opening quantity remains 8;
- current active O1 capacity becomes 12 according to the Pool projection;
- the original Initial Deposit remains governed by its existing opening-inventory semantics;
- the +4 increase has its own `SupplierArrangementCruiseCapacityDepositRequirement`.

The active Cruise overview and maintenance surfaces show the Pool projection as current active capacity.

They must not continue showing 8 as though it were current active capacity merely because the version definition still has `proposed_opening_quantity = 8`.

Where both facts are useful, label them distinctly:

> **O1 · Prime Oceanview**  
> Current active capacity: 12 cabins  
> Original opening quantity: 8 cabins

The original opening quantity does not need to be prominent on the normal active overview merely to explain the ledger. It remains available where opening agreement or deposit context requires it.

Do not recalculate or rewrite the original Initial Deposit merely because current operational capacity changes.

#### Carried Pool identity across a successor

A successor may carry the same Pool identity forward with a new version definition.

A same-terms capacity increase against the active version therefore changes the live capacity ledger for that Pool even when Draft Version 2 contains a carried definition for the same Pool.

"This change applies to Active Version 1" means the same-terms operation does not rewrite Draft Version 2's versioned Pool definition or other proposed Supplier terms.

It does not mean the carried Pool has a separate frozen operational ledger inside the draft.

On the draft, continue to describe that cabin as:

> **Carried from active terms**

Do not copy the changed live ledger quantity into the successor definition merely because operational capacity moved.

Do not treat the carried Pool and supplemental Pool as one Pool.

Do not add the carried Pool's live capacity to the supplemental Pool's proposed opening quantity and call that result active capacity.

The UI may separately present the carried Pool's current operational state when useful, but it must preserve the distinction between:

- live operational capacity on the carried Pool;
- the successor's carried version definition;
- proposed opening capacity on a new supplemental Pool.

#### Cruise overview

With no successor draft, the overview describes the governing active version.

When a successor draft exists, the normal/default Cruise overview describes that draft.

Its summaries, recommendations, task links, and activation link are compiled from the successor's authoritative versioned records while respecting shared live operational state such as the carried Pool ledger.

At the top show:

> **Draft · Version 2**  
> Proposed changes to active Version 1.

Do not combine active and proposed capacity into one total.

For example, the draft may show:

> **O1 · Prime Oceanview**  
> Carried from active terms
>
> **O1 · Supplemental O1 block**  
> 4 proposed opening cabins

It must not turn those records into:

> O1 — 12 active cabins

merely by summing carried and proposed records.

**View active version** leaves this overview for the read-only governing snapshot. The overview itself remains the draft workspace.

#### Maintenance entry point

On an active Cruise, expose **Change inventory** near the cabin inventory summary.

When no successor draft exists, Change inventory first asks:

> **Did the Supplier terms change for these additional cabins?**

Offer two choices.

**No — same terms**

> Add cabins to an existing Supplier block when the Supplier confirmed that the added cabins use the same terms.

**Yes — terms changed**

> Create a separate block on a successor version when the additional cabins have different Supplier terms.

The question is routing only. Selecting an answer does not create business state.

Staff may leave without choosing either path.

#### Existing successor behavior

When a successor draft already exists, do not ask the generic terms-change question as though another successor can be created.

The normal/default context is already that draft.

Show and continue the proposed work.

Do not offer to create another changed-terms successor through the simplified Cruise path.

If Staff needs a same-terms operational increase against the still-governing active version while a draft exists, require an explicit action:

**Change active inventory under existing terms**

Before showing or submitting the form, state:

> **Changes Active Version 1**  
> This updates the live capacity of the active Supplier block. It does not edit Draft Version 2's definitions.

Because the Pool may be carried into the successor, its shared live capacity ledger may still change. The draft's copied definition remains unchanged.

#### Same-terms capacity increase

The simplified same-terms path operates only on eligible existing numeric cabin Pools on the activated governing version.

Staff selects the cabin block receiving the increase.

Identify the block using its real Supplier code and Staff-facing name.

For example:

> **O1 · Prime Oceanview**  
> Active Version 1  
> Current active capacity: 8 cabins

Do not assume every same-terms increase is O1.

Do not offer an `on_request` or `externally_managed` Pool as though it were numeric inventory. Do not assign it a quantity or convert its inventory mode. Unsupported changes go to Advanced Supplier planning.

The form collects the existing command inputs:

- cabin block;
- additional cabins;
- deposit per additional cabin;
- optional effective date;
- evidence date;
- evidence reference note.

Evidence kind remains the current `supplier_confirmation` value used by this Cruise path. UX-6 does not add an evidence-kind chooser.

Effective date is optional and may remain blank.

Deposit rate behavior follows the existing command:

- blank amount is missing and rejected;
- a negative amount is rejected;
- explicit `0` is a legal zero per-cabin deposit rate.

Do not infer the rate from the original Initial Deposit.

Do not add a separate "No deposit" representation when explicit zero already represents that fact.

Before save, summarize the consequence from the submitted values.

For example:

> 4 additional O1 cabins will be added to this active Supplier block.  
> Deposit for this increase: $50.00 × 4 = $200.00.  
> The original Initial Deposit requirement will not be changed.

This calculation is presentation of the submitted command inputs. It is not a new persisted deposit model.

Save through `RecordCruiseSameTermsCapacityIncrease`.

Preserve its existing:

- authorization;
- activated-version selection;
- capacity projection locking;
- `IncreaseCapacity` delegation;
- evidence behavior;
- idempotency;
- capacity event;
- `SupplierArrangementCruiseCapacityDepositRequirement`;
- protection against rewriting existing deposit definitions.

UX-6 does not add a client-supplied Arrangement or version lock to this command. Same-terms staleness remains the existing capacity projection lock contract.

Do not create a successor for a same-terms increase.

Do not rewrite the Pool definition's original `proposed_opening_quantity`.

Do not rewrite the original Initial Deposit requirement.

An operational increase is not a retroactive change to original proposed opening inventory.

#### Same-terms success

After success, show the updated authoritative capacity from the Pool projection.

For example:

> **Capacity increase recorded**  
> 4 additional O1 cabins have been added.
>
> **O1 · Prime Oceanview**  
> Current active capacity: 12 cabins

Show the separately recorded increase deposit where appropriate:

| Additional cabins | Deposit per cabin | Increase deposit |
| ---: | ---: | ---: |
| 4 | $50.00 | $200.00 |

The original opening quantity remains 8.

The original Initial Deposit remains separately visible and unchanged.

Do not combine the original Initial Deposit and later increase deposit into a replacement "current deposit requirement."

If a successor draft carries the same Pool, its versioned definition remains unchanged. Its presentation may reflect that the carried Pool has live operational state, but must not misrepresent that ledger change as a draft-definition edit.

#### Changed-terms supplemental block

Changed Supplier terms create proposed Supplier terms on a successor version.

Before save, explain:

> A new draft version will be created. The current version remains active until the draft is completed and activated.

The existing `CreateCruiseSupplementalBlock` command is intentionally narrower than a generalized changed-terms cabin editor.

UX-6 therefore presents the supported operation truthfully as a supplemental O1 block.

Show:

- Supplier category: **O1**
- Internal block name: **Supplemental O1 block**

Collect:

- maximum occupancy;
- opening quantity.

Do not ask Staff to invent a second Supplier category code.

The supplemental Resource keeps Supplier code `O1`.

Do not create `O1-2`.

Do not present this form as supporting arbitrary changed-terms categories. Other shapes use Advanced Supplier planning unless a later domain contract broadens the command.

Save through `CreateCruiseSupplementalBlock`.

Preserve its existing:

- authorization;
- Arrangement lock;
- version lock;
- idempotency;
- successor creation behavior.

If a successor already exists, the existing domain contract rejects creation of a second successor.

The Cruise UI should normally detect the existing draft first and continue it, but the command remains authoritative under races.

Do not create, replace, or merge another successor to recover from that conflict.

#### Supplemental opening authority

`CreateCruiseSupplementalBlock` creates:

- a successor draft;
- a separate Resource;
- Supplier code `O1`;
- internal block name `Supplemental O1 block`;
- maximum occupancy;
- a numeric `block` Pool;
- proposed opening quantity.

It does not record opening evidence.

The new numeric Pool therefore remains incomplete for activation.

Existing readiness reports:

`opening_authority_incomplete`

until Staff records the required opening authority/evidence through the existing cabin-category editing path.

Do not teach `CreateCruiseSupplementalBlock` to manufacture evidence.

It likewise does not invent:

- contracted rates;
- Supplier agreement confirmation;
- deposit treatment.

After creation, continue in the successor draft and show:

> **Supplemental O1 block created**  
> Draft Version 2 contains the proposed supplemental block. Active Version 1 remains in effect.

The draft journey includes the existing cabin task along with the other outstanding Supplier facts.

For example:

> **Next steps for activation**
>
> - Complete opening evidence for Supplemental O1 block
> - Confirm amended Supplier agreement
> - Add contracted rates for Supplemental O1 block
> - Record deposit treatment for Supplemental O1 block
> - Review activation

This ordering is presentation guidance only. `SupplierArrangementActivationReadiness` remains authoritative.

The existing cabin editor owns completion of the supplemental Pool's opening authority.

#### Successor draft journey

A changed-terms successor returns to the same Cruise journey already used for draft Supplier terms.

Do not build an amendment wizard or a second readiness model.

The successor completes its own authoritative facts through existing pages and commands:

1. opening authority/evidence for the supplemental numeric Pool;
2. amended whole-agreement confirmation;
3. contracted Supplier rates for the supplemental Resource;
4. deposit treatment for the supplemental capacity;
5. UX-5 activation review.

`CompileCruiseCompositionSummary` and `CompileCruiseActivationReview` continue to derive state from authoritative records.

Do not add amendment-completion state.

#### Supplemental deposit treatment

Do not infer that the original `$50` opening-cabin deposit automatically applies to changed-terms supplemental capacity.

The successor requires its own explicit deposit treatment according to the existing Cruise agreement/readiness contract.

Until that treatment exists, preserve the existing `cruise_deposit_treatment_missing` behavior.

`CreateCruiseSupplementalBlock` remains responsible only for the successor and supplemental cabin block it already owns.

Do not expand it to record opening evidence, agreement confirmation, rates, or deposit treatment.

#### Governing and proposed inventory

When a successor exists, keep governing and proposed supply visibly distinct.

For example:

**Active Version 1**

> O1 · Prime Oceanview  
> Current active capacity: 8 cabins

**Draft Version 2**

> O1 · Prime Oceanview  
> Carried from active terms
>
> O1 · Supplemental O1 block  
> Proposed opening quantity: 4 cabins

Do not present the supplemental block as active capacity before successful activation.

Do not add its proposed opening quantity to the carried Pool's live operational capacity and call the result active supply.

The existing Supplier Arrangement version transition determines what becomes governing.

#### UX-5 integration

When a successor draft exists, **Review activation** on the normal Cruise workspace reviews that draft. The read-only Active snapshot does not offer activation review.

State the target explicitly:

> **Activating Draft Version 2**  
> Active Version 1 remains in effect until this activation succeeds.

The activation command remains `ActivateSupplierArrangementVersion`.

UX-6 does not alter its readiness, locking, evidence, acknowledgment, idempotency, or activation consequences.

After successful successor activation:

> **Active · Version 2**  
> Version 2 is now the governing Supplier Arrangement version.

Because no successor draft remains, Version 2 becomes the normal/default Cruise version.

UX-6 does not add a version-history system.

#### Client-service boundary

Neither maintenance path silently changes the Client offering.

After a Supplier inventory change, make that boundary understandable where relevant:

> Supplier inventory has changed. Client offering has not been changed automatically.

UX-6 must not:

- increase an existing Client choice's selectable quantity;
- repoint an existing Service Offer source;
- add the supplemental Pool to an existing Client choice;
- aggregate original and supplemental Pools behind one Client choice;
- create a new Client choice;
- change Client price;
- change Package inclusion;
- publish anything.

A Supplier successor draft likewise does not change the existing Client-service connection merely by existing.

While viewing proposed Supplier terms, Client-service presentation must not imply that draft supply is already available to Clients.

One Client choice consuming multiple Supplier Pools remains deferred to the separate Offer Design contract.

#### Transitional controls and interface contract

UX-4 temporarily leaves same-terms increase and supplemental-block forms on the Supplier agreement page.

UX-6 replaces those normal-path forms with the dedicated Change inventory journey.

When UX-6 ships:

- remove the embedded same-terms increase form from the normal agreement page;
- remove the embedded supplemental-block form from the normal agreement page;
- replace the transitional Later capacity panel with a concise **Change inventory** link where a maintenance entry point is useful;
- update the Cruise portion of `docs/ui/interface-contract.md` in the same slice so it no longer describes the removed agreement-page buttons;
- document the Change inventory entry point, the draft workspace, and the read-only Active snapshot.

Do not leave an accepted interface-contract statement describing controls that no longer exist.

Do not delete the underlying commands.

Do not remove Advanced Supplier planning.

This is the minimum interface-contract correction required by UX-6. UX-7 retains responsibility for the broader Cruise interface-contract review, superseded normal-path cleanup, and final responsive/accessibility documentation.

#### Compiler and routing

Prefer extending the existing Cruise presentation compilers and access helpers rather than adding a persisted maintenance abstraction.

The Cruise presentation layer may derive:

- the normal workspace version;
- the governing version for the read-only snapshot;
- the editable successor version;
- current Pool projection for active numeric cabin inventory;
- original opening quantity where relevant;
- eligible governing numeric Pools for same-terms increase;
- whether a successor already exists;
- carried Pool presentation;
- proposed supplemental supply;
- **View active version** and **Back to Draft** links.

Compilation remains read-only.

The snapshot is one read-only compilation of the governing version. Do not thread an Active context through the existing Cruise routes.

Do not persist:

- maintenance mode;
- same terms / changed terms;
- selected version context as domain state;
- maintenance step;
- amendment completion.

Do not accept an arbitrary version ID as navigation authority.

#### Authorization, locking, and idempotency

Use the existing Departure-management authorization boundary for mutations.

Same-terms capacity increases retain the command's existing activated-version and capacity-projection concurrency behavior.

Do not add a client Arrangement/version lock merely for symmetry with the supplemental path.

The optional effective date may remain blank.

Evidence kind remains `supplier_confirmation`.

Blank deposit amount remains missing input.

Explicit zero remains a valid rate.

Changed-terms supplemental blocks retain their existing Arrangement/version locking and successor-creation behavior.

A stale request must fail rather than partially applying a capacity change or creating a successor from outdated terms.

Retries retain existing idempotency semantics.

If a successor has already been created, the simplified Cruise journey continues that authoritative draft rather than creating another successor.

Do not weaken either command to simplify the UI.

#### Proof

Service/query proof covers:

- the normal workspace is governing when no draft exists;
- the normal workspace is the draft when a successor exists;
- **View active version** is a read-only governing snapshot and is not the workspace for cabin, rate, agreement, or activation routes;
- **Back to Draft** returns to that draft workspace;
- the snapshot offers no ordinary editors and no activation POST;
- summaries and recommendations use the workspace version rather than merging versions;
- active and proposed capacity are not summed into one active total;
- an active Pool with original opening quantity 8 and a later +4 event presents current active capacity 12;
- the original `proposed_opening_quantity` remains 8;
- the original Initial Deposit remains unchanged;
- a successor carrying that Pool still identifies it as carried from active terms after the live ledger changes;
- same-terms eligibility includes appropriate numeric governing Pools;
- nonnumeric Pools are not presented as numeric same-terms targets;
- an existing successor is detected;
- presentation compilation remains read-only.

Request proof covers the Active snapshot:

- the snapshot is read-only except **Change active inventory under existing terms**;
- ordinary cabin, rate, agreement, and activation routes still resolve to the draft when a successor exists;
- the same-terms post still locks the activated version.

Request proof covers same terms:

- the request invokes `RecordCruiseSameTermsCapacityIncrease`;
- it clearly targets the activated governing version even when a draft exists;
- selected Pool, quantity, deposit rate, optional effective date, and evidence reach the existing command;
- evidence kind remains `supplier_confirmation`;
- blank effective date succeeds;
- blank deposit amount is rejected;
- explicit zero deposit rate succeeds;
- the capacity event is recorded;
- current active capacity reflects the resulting Pool projection;
- the separate `SupplierArrangementCruiseCapacityDepositRequirement` is recorded;
- the original Initial Deposit definition and lock version remain unchanged;
- original `proposed_opening_quantity` is unchanged;
- a carried successor definition is not rewritten;
- replay does not duplicate capacity or deposit;
- existing projection-lock concurrency prevents partial stale application;
- UX-6 does not add a client Arrangement/version lock to the command.

Request proof covers changed terms:

- the request invokes `CreateCruiseSupplementalBlock`;
- exactly one successor is created;
- the new Resource keeps Supplier code `O1`;
- its internal name is `Supplemental O1 block`;
- maximum occupancy and proposed opening quantity are recorded;
- opening evidence is not invented;
- readiness reports `opening_authority_incomplete` for the new numeric Pool;
- completing opening evidence uses the existing cabin editor;
- the prior version remains governing;
- the new version remains draft;
- Supplier agreement confirmation is not invented;
- contracted rates are not invented;
- deposit treatment is not invented;
- existing readiness reports the successor's outstanding facts;
- stale Arrangement/version locks do not partially create a successor or block;
- replay does not create another successor or supplemental block;
- an existing successor prevents a second successor and is continued through the normal journey.

Client-service boundary proof covers:

- the fixture begins with an existing Client service connected to the original Supplier source;
- creating a Supplier successor does not change that source binding;
- creating supplemental Supplier capacity does not change Client price or selectable quantity;
- activating the Supplier successor does not automatically repoint or expand the Client service;
- the supplemental Pool does not become a Client source without the separate explicit Offer Design path.

System proof uses the canonical Cruise.

At 1280px, first prove same terms:

1. Begin with the canonical Cruise activated and no successor.
2. Verify the overview says **Active · Version 1**.
3. Verify O1 originally opened with 8 cabins.
4. Open **Change inventory**.
5. Verify the terms-change question appears.
6. Choose **No — same terms**.
7. Select O1 Prime Oceanview.
8. Enter 4 additional cabins and `$50.00` per additional cabin.
9. Leave effective date blank.
10. Enter the existing Supplier-confirmation evidence fields.
11. Verify the confirmation explains `$50.00 × 4 = $200.00` and says the original Initial Deposit will not change.
12. Save.
13. Verify the active Cruise shows **Current active capacity: 12 cabins**.
14. Verify original opening quantity remains 8 where that fact is shown.
15. Verify the separate `$200.00` increase deposit.
16. Verify the original Initial Deposit remains unchanged.
17. Verify no successor was created.

In a separate setup, prove changed terms and the Client-service boundary:

1. Begin with the canonical Cruise activated and no successor.
2. Begin with an existing Client service connected to the original O1 Supplier source.
3. Record the Client service's current source binding, Client price, and selectable quantity or other existing availability representation used by that service.
4. Verify the Cruise overview says **Active · Version 1** and shows the existing Client-service connection.
5. Open **Change inventory**.
6. Choose **Yes — terms changed**.
7. Verify the page explains that a successor draft will be created and the current version remains active.
8. Create 4 supplemental O1 cabins.
9. Verify the resulting page defaults to **Draft · Version 2**.
10. Verify it also says Active Version 1 remains in effect.
11. Verify the supplemental Resource is `O1 · Supplemental O1 block`.
12. Verify its proposed opening quantity is 4.
13. Verify opening evidence was not invented.
14. Verify the next steps include completing opening evidence through the existing cabin task.
15. Verify agreement confirmation, contracted rates, and deposit treatment also remain outstanding.
16. Verify the existing Client service still has the same source binding, Client price, and selectable quantity or existing availability representation recorded before the Supplier change.
17. Verify the supplemental Pool has not been added as a source for that Client service.
18. Follow **View active version**.
19. Verify the read-only snapshot shows **Active · Version 1**, that Draft Version 2 is in progress, and that cabin inventory uses the live Pool projection.
20. Verify the snapshot does not link to cabin editors, Supplier rates, the agreement editor, or activation review.
21. Verify **Change active inventory under existing terms** is the only mutation, and that it says **Changes Active Version 1**.
22. Follow **Back to Draft Version 2**.
23. Verify the normal workspace is Draft Version 2 again.
24. From the draft workspace, choose **Change active inventory under existing terms**.
25. Verify the form says **Changes Active Version 1** before submit.
26. Return without saving.
27. Complete supplemental opening evidence through the existing cabin editor.
28. Complete the successor's existing agreement, contracted-rate, and deposit-treatment tasks.
29. Open UX-5 Review activation and verify it says **Activating Draft Version 2**.
30. Activate through the existing command.
31. Verify Version 2 becomes **Active** and is now the normal workspace.
32. Re-read the existing Client service.
33. Verify its source binding, Client price, and selectable quantity or existing availability representation are still unchanged.
34. Verify the supplemental Pool is still not automatically a Client-service source.

Add a carried-Pool regression:

1. Begin with Active Version 1 and Draft Version 2 carrying the original O1 Pool.
2. Verify the normal Cruise entry defaults to Draft Version 2.
3. From the draft, explicitly choose **Change active inventory under existing terms**.
4. Verify the target says **Active Version 1**.
5. Record a +4 same-terms increase.
6. Verify the live Pool projection reflects the increase.
7. Verify Draft Version 2's carried Pool definition was not rewritten.
8. Verify it remains labeled **Carried from active terms**.
9. Verify the supplemental Pool remains a separate proposed block.
10. Verify the UI does not sum carried live capacity and supplemental proposed opening quantity into one active quantity.

Repeat the principal overview, version-switching, same-terms form, supplemental creation, and successor-draft screens at 375px with no horizontal page overflow.

#### Exit criteria

UX-6 is complete when Staff can maintain later Cruise Supplier inventory through two clearly distinguished existing domain paths:

> **Same Supplier terms → operational capacity increase on active governing supply**

> **Changed Supplier terms → proposed successor with a separate supplemental block**

Every normal Cruise workspace makes **Active versus Draft** explicit.

When a successor draft exists, that draft is the workspace. **View active version** opens a read-only governing snapshot and **Back to Draft** returns to the workspace. The snapshot does not carry an Active context into cabin, rate, agreement, or activation routes. The explicitly labeled same-terms action remains available against governing supply.

The UI preserves the distinction among:

> **original opening quantity**

> **live Pool capacity**

> **supplemental proposed opening quantity**

A same-terms capacity event changes live operational capacity without rewriting the original opening quantity, original Initial Deposit, or successor version definition.

A changed-terms supplemental block remains proposed until its existing opening-evidence, agreement, rate, deposit-treatment, and activation requirements are satisfied.

Supplier inventory changes remain Supplier-side. Neither maintenance path silently changes Client offering, pricing, sourcing, or selectable quantity.

The Client-service boundary is proven against a Client service that exists before the Supplier maintenance operation; unchanged Client state is not asserted from an empty starting condition.

The interface contract shipped with UX-6 describes the UX-6 maintenance entry point and no longer describes the agreement-page later-capacity controls that UX-6 removes.

Do not implement generalized changed-terms cabin categories, Offer Design, multi-Pool Client choices, agreement documents, or broader UX-7 cleanup in this slice.