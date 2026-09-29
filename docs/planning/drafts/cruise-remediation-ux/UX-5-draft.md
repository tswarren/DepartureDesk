# M4D.1 Cruise composition UX — UX-5 Review and activate

**Status:** Draft  
**Parent:** `docs/planning/m4d1-cruise-composition-ux.md`  
**Depends on:** accepted UX-1 through UX-4 and the UX-4.5 nonnumeric opening-capacity remediation  
**Scope:** Cruise-specific presentation and orchestration over existing Supplier activation authority  
**Primary command:** `ActivateSupplierArrangementVersion`

## 1. Purpose

UX-5 gives Staff a Cruise-specific review of the exact Supplier Arrangement version they are about to activate, explains authoritative activation blockers in Cruise language, and invokes the existing Supplier activation command when the version is ready.

The normal Cruise path must let Staff answer:

1. What sailing and Supplier agreement am I activating?
2. What cabin inventory will activation establish or carry?
3. Are the Supplier rates contracted and ready?
4. What deposits and deadlines will activation materialize?
5. Is anything preventing activation?
6. What operational consequences will activation create?
7. What Supplier evidence supports activation?
8. After activation, where do I continue to connect this supply to the existing Client service?

UX-5 does not create a second readiness model, a Cruise-specific activation command, or a workflow engine. It translates existing authoritative Supplier-planning state into a focused Cruise review.

The governing principle is:

> UX-5 does not make activation easier by weakening Supplier-planning invariants. It makes the existing activation decision understandable in Cruise language. A fact required by the supported Cruise contract is either ready or a blocker.

## 2. Scope

UX-5 includes:

- a Cruise-specific activation review;
- plain-language presentation of the sailing and exact Arrangement version;
- cabin inventory review;
- contracted Supplier-rate review;
- Supplier agreement review;
- Initial Deposit, Hard Stop, and Final Payment review;
- translation of authoritative activation blockers into Cruise language;
- fail-closed presentation of blockers the Cruise UI does not understand;
- preview of activation consequences;
- exact-version Supplier confirmation evidence required by activation;
- explicit acknowledgment of already-elapsed deadlines or deposit requirements when applicable;
- invocation of `ActivateSupplierArrangementVersion`;
- activated-state confirmation;
- navigation to the existing Client-service connection after activation;
- responsive, accessible system proof of the complete canonical Cruise activation journey.

UX-5 does not include:

- Offer Design;
- Client pricing changes;
- Package changes;
- Client choice changes;
- publication;
- booking;
- allocation;
- Client Trip or Traveler records;
- Supplier Payment;
- refunds;
- automatic capacity release;
- a second readiness or completeness model;
- persisted journey/task completion state;
- a Cruise-specific activation manifest;
- a Cruise-specific Supplier confirmation record replacing generic activation confirmation;
- weakening or bypassing generic activation invariants;
- an acknowledgment allowing estimate rates to substitute for contracted Cruise rates;
- new capacity, deposit, deadline, cost, or commitment records outside existing activation consequences;
- automatic interpretation of unsupported generic Supplier-planning shapes.

## 3. Existing authority

The mutation remains:

`ActivateSupplierArrangementVersion`

UX-5 must preserve its existing:

- Agency and actor authorization;
- Arrangement/version locking;
- submitted lock-version checks;
- idempotency;
- authoritative `SupplierArrangementActivationReadiness` execution inside the activation transaction;
- exact-version `SupplierConfirmation`;
- activation manifest;
- cost selections;
- capacity establishment/carrying;
- Supplier commitment creation;
- deadline materialization;
- deposit materialization;
- confirmation links;
- predecessor/successor handling;
- governing-version transition;
- audit events;
- exposure rebuild;
- duplicate Supplier-identifier review.

The Cruise review shown before POST is explanatory. It does not authorize activation.

`ActivateSupplierArrangementVersion` must rerun its authoritative checks under its existing transaction and locks.

If state changes between review and activation, the POST must fail according to existing command semantics and return Staff to the Cruise activation review with current information.

## 4. Readiness authority

UX-5 may introduce a read-only presentation compiler such as:

`CompileCruiseActivationReview`

The compiler may:

- call existing readiness and preview services;
- read authoritative Cruise agreement records;
- read sailing, cabin, rate, deposit, deadline, and commitment definitions;
- organize facts into Cruise-specific sections;
- translate known readiness blocker codes into Staff-facing Cruise language;
- provide corrective routes;
- expose activation consequences;
- identify unsupported or unknown blocker shapes;
- determine whether the Cruise-specific activation action may be displayed or enabled based on authoritative results.

It must not:

- independently determine whether activation is legal;
- reproduce readiness predicates;
- persist readiness;
- create completion flags;
- convert blockers into warnings;
- infer that an estimate is contracted;
- invent opening quantities for nonnumeric inventory;
- recalculate deposit authority independently of the existing evaluator;
- manufacture Supplier confirmation evidence;
- infer Staff acknowledgment of already-elapsed requirements;
- omit an authoritative blocker because it lacks a Cruise-specific translation.

Invariant:

> `CompileCruiseActivationReview` explains authoritative activation readiness; it does not decide activation readiness.

## 5. Page location and entry

The existing Cruise task strip continues to contain:

1. Sailing
2. Cabin categories
3. Supplier rates
4. Agreement and requirements
5. Activation

UX-5 owns the normal Cruise destination for **Activation**.

The generic Supplier activation page remains available through Advanced Supplier planning for unsupported shapes.

The Cruise activation review is read-first. It is not a large generic activation form.

The page heading should identify:

- Supplier;
- ship;
- sailing;
- sailing dates;
- Arrangement version.

Provide:

- **Back to Cruise overview**
- **Advanced Supplier planning**

where appropriate.

## 6. Review hierarchy

The page presents the following major areas in order:

1. Cruise
2. Cabin inventory
3. Supplier economics
4. Agreement & requirements
5. Activation status and consequences
6. Supplier confirmation evidence and activation action, when otherwise eligible

These areas are presentation sections over existing records. They are not persisted workflow steps.

## 7. Cruise summary

The Cruise section provides orientation for the exact Supplier Arrangement version under review.

Show, when available:

- Supplier;
- ship;
- sailing name;
- sailing start/end dates;
- Supplier group reference;
- Arrangement version;
- whether this is an initial activation or successor activation.

Do not provide ordinary editing controls in this section.

Provide contextual **Review** links to the existing Cruise tasks when Staff needs to correct a fact.

For a successor, clearly distinguish:

- currently governing version;
- proposed successor version.

Do not imply that the draft successor governs before activation.

## 8. Cabin inventory

Render every cabin Resource/Pool represented by the supported Cruise shape.

For each cabin category show:

- Supplier category code;
- cabin/category name;
- internal block label when needed to distinguish duplicate Supplier codes;
- inventory mode;
- opening quantity when numeric;
- plain-language status.

Example:

| Cabin category | Inventory | Opening quantity | Status |
| --- | --- | ---: | --- |
| E3 — Edge Stateroom with Veranda | Block | 8 | Ready |
| O1 — Prime Oceanview | Block | 8 | Ready |
| DI — Deluxe Inside Stateroom | Block | 8 | Ready |
| C1 — Concierge | On request | — | Quantity not tracked |

### 8.1 Numeric inventory

Block/Allotment inventory requiring a numeric opening quantity must have its authoritative opening quantity.

A missing required numeric opening quantity remains a blocker.

Cruise language should identify the affected category, for example:

> O1 Prime Oceanview is Block inventory but does not have an opening cabin quantity.

Corrective action:

**Review cabin categories**

### 8.2 Nonnumeric inventory

`on_request` and `externally_managed` inventory are intentionally nonnumeric.

They must not be presented as incomplete solely because `proposed_opening_quantity` is nil.

Use language such as:

> On request — quantity not tracked

or:

> Externally managed — quantity not tracked

Do not:

- assign zero;
- invent an opening quantity;
- ask Staff to acknowledge the missing quantity;
- make the nonnumeric state an activation blocker solely because no numeric opening exists.

This section must preserve the UX-4.5 distinction between intentionally nonnumeric inventory and incomplete numeric inventory.

## 9. Supplier economics

Render Supplier-rate readiness by cabin Resource.

The normal Cruise path requires ready **contracted** Supplier rates for every covered cabin Resource.

Example:

| Cabin category | Supplier rates | Status |
| --- | --- | --- |
| E3 | Contracted | Ready |
| O1 | Contracted | Ready |
| DI | Estimate only | Needs attention |

An estimate is a blocker.

It is not an activation acknowledgment.

UX-5 must not offer a checkbox or other action that allows Staff to accept an estimate as sufficient for the supported Cruise activation path.

Corrective action:

**Review Supplier rates**

The existing generic `provisional_costs_acknowledged` capability remains part of the generic activation command for other Supplier-planning shapes. UX-5 does not expose it as an escape hatch.

For a Cruise eligible for normal activation, authoritative selected cost definitions must not contain an estimate.

## 10. Agreement & requirements

This section summarizes the operational facts already owned by UX-4 and their existing domain records.

It does not provide a second editor for them.

Show:

- Supplier agreement confirmation;
- Initial Deposit;
- Hard Stop;
- Final Payment.

Provide contextual links back to Agreement & requirements for corrections.

Optional commercial benefits and informational Supplier terms may be shown only if useful for orientation. Their absence must not become an activation blocker unless an existing authoritative readiness rule independently says otherwise.

### 10.1 Supplier agreement

Show whether the exact Cruise agreement revision is confirmed.

For a confirmed canonical agreement, show:

- group reference;
- contract date;
- confirmed status.

An unconfirmed Cruise Supplier agreement remains a blocker.

Corrective action:

**Review Supplier agreement**

Do not infer agreement confirmation from rate readiness or activation evidence.

### 10.2 Initial Deposit

Use the existing deposit definition and `SupplierDepositAmountEvaluator`/existing preview authority.

For numeric opening inventory, show:

- saved amount per opening cabin;
- current qualifying opening quantity;
- evaluated total;
- saved due date.

Canonical example:

> **Initial Deposit — Ready**  
> $50.00 per opening cabin × 24 cabins = $1,200.00  
> Due October 13, 2026

The evaluated quantity and total remain live calculations. They are not persisted snapshots on the requirement.

For mixed numeric/nonnumeric coverage, use the evaluator result.

Example:

> **Initial Deposit — Ready**  
> $50.00 per opening cabin × 16 cabins = $800.00  
> On request cabins are not included in the numeric opening quantity.

For all-nonnumeric covered inventory, show the evaluator's quantity-not-tracked result.

Example:

> **Initial Deposit — Quantity not tracked**  
> $50.00 per opening cabin  
> Covered On request or externally managed inventory does not have a numeric opening quantity.

Do not display `$0` for this state.

Do not create a zero-dollar tranche merely to represent it.

Do not reconstruct deposit eligibility independently in UX-5.

### 10.3 Hard Stop

Show the existing combined Cruise Hard Stop as one requirement.

Canonical example:

> **Hard Stop — Ready**  
> July 9, 2027  
> Name and fully deposit allocated staterooms, or release remaining inventory.

Do not split this into separate names, full-deposit, and release deadlines.

Do not imply that activation, reaching the deadline, or passing the deadline automatically releases inventory.

### 10.4 Final Payment

Show the existing date-only Final Payment requirement.

Canonical example:

> **Final Payment — Ready**  
> August 8, 2027

Do not calculate or record actual payment in UX-5.

## 11. Activation blockers

The page must present the result of authoritative activation readiness in Cruise language.

### 11.1 Blocked state

When authoritative blockers exist, show a prominent summary such as:

> **This Cruise isn't ready to activate**
>
> 2 items need attention.

Group blockers by the Cruise task that can resolve them where practical.

Example:

> **Supplier rates**
>
> DI Deluxe Inside has estimate rates but no ready contracted Supplier rates.
>
> **Review Supplier rates**

Example:

> **Cabin inventory**
>
> O1 Prime Oceanview is Block inventory but does not have an opening cabin quantity.
>
> **Review cabin categories**

Known blocker translation must be based on stable blocker codes/structured data, not parsing English error messages.

Do not expose internal UUID paths or generic implementation terminology when a supported Cruise translation exists.

### 11.2 Unknown blockers

Translation is fail-closed.

Every authoritative blocker must remain visible.

If UX-5 does not recognize a blocker shape, show a neutral fallback such as:

> **Additional activation requirement**
>
> DepartureDesk found a Supplier-planning requirement that the Cruise review cannot resolve.
>
> **Review in Advanced Supplier planning**

Do not:

- omit the blocker;
- mark it ready;
- guess its meaning;
- convert it to a warning.

### 11.3 Ready state

When no authoritative blocker prevents the supported Cruise from activation, show:

> **Ready to activate**
>
> The sailing, Supplier agreement, cabin inventory, contracted Supplier rates, and operational requirements are ready.

This is a presentation of authoritative state, not persisted Cruise readiness.

## 12. Activation consequences

Before the consequential activation action, summarize what the existing activation command will do for this exact version.

Use Cruise language rather than generic trigger terminology where the meaning is known.

Examples may include:

- numeric blocked cabin capacity will be established;
- already-established/carried Pools will remain carried as defined;
- On request/externally managed Pools will remain nonnumeric;
- Initial Deposit requirements will materialize according to their existing definitions;
- Supplier deadlines will materialize;
- confirmation-triggered Supplier commitments will open;
- this exact version will become governing;
- for a successor, the predecessor will become superseded.

The preview must be derived from existing definitions/services.

It must not promise consequences the command does not authoritatively produce.

Unsupported consequence shapes must direct Staff to Advanced Supplier planning rather than being silently omitted.

## 13. Activation attestations

`ActivateSupplierArrangementVersion` currently records activation attestations for:

- cost-source coverage;
- provisional costs when selected estimates exist;
- confirmation-trigger coverage;
- already-elapsed deadlines/deposit requirements when applicable.

UX-5 preserves the command and activation manifest while translating these inputs appropriately for the supported Cruise path.

### 13.1 Cost-source coverage

The command's cost-source coverage attestation remains recorded.

UX-5 does not require a separate generic checkbox reading:

> I confirm the entered cost-source list is complete.

For a supported Cruise, the activation review has already presented the authoritative Supplier-rate coverage and authoritative readiness has verified it.

Pressing the consequential activation action after reviewing that state supplies the existing:

`cost_source_coverage_acknowledged = true`

to `ActivateSupplierArrangementVersion`.

This does not bypass readiness. The command reruns readiness under lock before activation.

### 13.2 Provisional costs

UX-5 does not expose provisional-cost acknowledgment.

A supported Cruise requires ready contracted Supplier rates for its covered cabin Resources.

If an estimate remains selected where Cruise requires contracted authority, activation remains blocked.

The Cruise activation submission does not set `provisional_costs_acknowledged = true` as a bypass.

For a supported ready Cruise, the selected authoritative cost definitions must contain no provisional estimate requiring that acknowledgment.

### 13.3 Confirmation-trigger coverage

The command's confirmation-trigger coverage attestation remains recorded.

UX-5 does not require a separate generic checkbox reading:

> I confirm known confirmation-triggered commitments are covered by the listed triggers.

Instead, UX-5 presents the existing activation consequences in Cruise language.

Pressing the consequential activation action after reviewing those consequences supplies:

`commitment_trigger_coverage_acknowledged = true`

to `ActivateSupplierArrangementVersion`.

The command retains its existing manifest field, fingerprint, validation, and audit behavior.

### 13.4 Already-elapsed requirements

Elapsed requirements are different because they represent a consequential condition Staff must explicitly accept.

If activation would materialize an already-elapsed Supplier Deadline or Deposit Requirement, UX-5 must show each affected requirement and require explicit Staff acknowledgment.

Example:

> **A Supplier requirement is already past due**
>
> Initial Deposit — due October 13, 2026
>
> Activating this Cruise will open this requirement as already overdue.
>
> [ ] I understand this requirement is already overdue and want to activate these terms.

Only an explicit Staff action may submit:

`elapsed_deadlines_acknowledged = true`

when required.

If no requirement is elapsed, do not show this acknowledgment.

The command recalculates elapsed requirements inside activation. If a requirement becomes elapsed after GET but before POST, activation may reject the request. UX-5 must reload the current review and present the newly required acknowledgment.

## 14. Supplier confirmation evidence

Cruise agreement confirmation and activation Supplier confirmation are distinct existing facts.

A confirmed:

`SupplierArrangementCruiseAgreementConfirmation`

establishes that the exact Cruise agreement revision has been confirmed.

Activation separately requires an exact-version:

`SupplierConfirmation`

used by the activation manifest and activation-triggered consequences.

UX-5 must not silently treat the Cruise agreement confirmation row as the generic activation confirmation.

### 14.1 Presentation

When the Cruise is otherwise eligible for activation, present a compact **Supplier confirmation evidence** section.

Explain the purpose in Staff language:

> Record or reuse the Supplier evidence supporting activation of these terms.

The normal Cruise UI should not reproduce the entire generic activation page.

Use the existing `SupplierConfirmation` contract and fields required by `ActivateSupplierArrangementVersion`.

Where applicable show:

- existing compatible exact-version confirmation evidence;
- evidence kind;
- evidence date;
- channel;
- reference note;
- Supplier-issued identifier or reason no identifier was issued.

If compatible exact-version `SupplierConfirmation` already exists, Staff may explicitly reuse it through the existing command capability.

If none exists, Staff records new evidence as part of activation.

### 14.2 Cruise agreement values as defaults

Existing Cruise agreement facts may be used to reduce duplicate typing only where doing so does not change their meaning.

In particular, the confirmed Cruise group reference may be presented as contextual information and may be offered as a default for an appropriate Supplier-issued identifier field only when the existing identifier contract supports that identifier type and issuer context.

UX-5 must not:

- silently create a Supplier-issued identifier from the Cruise group reference;
- claim that agreement confirmation and activation confirmation are the same record;
- infer evidence kind, channel, evidence date, or reference note without authority;
- invent an identifier type or issuer context;
- invent a reason that no identifier was issued.

Any automatic/default mapping from the Cruise group reference into the generic identifier structure must be explicitly specified and proven before implementation. Otherwise Staff enters or selects the activation identifier through the existing contract.

### 14.3 Duplicate identifier review

Preserve the existing `DuplicateReviewRequired` behavior.

If activation evidence attempts to create a Supplier-issued identifier matching another owner, UX-5 must present the existing duplicate candidates and require the existing acknowledgment/retry flow.

Do not weaken duplicate protection for Cruise.

## 15. Activation-time confirmed quantities and amounts

Existing arrangement-confirmation triggers may require:

- confirmed quantity;
- contracted unit rate × confirmed quantity;
- confirmed amount.

UX-5 must not silently discard those inputs.

For a supported Cruise:

- if the existing trigger contract deterministically derives the required value from authoritative Cruise supply, use that existing authority;
- if the trigger requires Staff to provide a Supplier-confirmed value at activation, present the input in Cruise language;
- do not infer a confirmed value merely because a superficially similar opening quantity or deposit amount exists elsewhere.

If a trigger shape cannot be represented safely by the Cruise activation review, show the requirement and direct Staff to:

**Review in Advanced Supplier planning**

Do not provide a partial Cruise activation action that omits required command input.

## 16. Activation action

When:

- authoritative readiness has no blocker;
- the Cruise shape is supported;
- required Supplier confirmation evidence is available or entered;
- required activation-time quantity/amount inputs are available;
- any already-elapsed requirements have been explicitly acknowledged;

show the consequential action:

**Activate Cruise supplier arrangement**

For a successor, wording may be:

**Activate Cruise successor**

Immediately adjacent explanatory copy should state the consequence, for example:

> Activation makes this Supplier Arrangement version governing and creates the Supplier capacity, commitments, deposits, and deadlines defined by these terms.

Do not add generic confirmation checkboxes for facts already presented and authoritatively verified.

The POST invokes `ActivateSupplierArrangementVersion`.

## 17. Activation submission contract

For the normal supported Cruise path, the orchestration submits the existing command approximately as follows:

- exact Arrangement/version;
- current Arrangement/version lock versions;
- idempotency key;
- existing or new exact-version `SupplierConfirmation` inputs;
- existing identifier inputs where applicable;
- `cost_source_coverage_acknowledged = true`;
- `provisional_costs_acknowledged = false`;
- `commitment_trigger_coverage_acknowledged = true`;
- `elapsed_deadlines_acknowledged = true` only when Staff explicitly acknowledged displayed elapsed requirements;
- required trigger-specific confirmed quantities/amounts when applicable;
- existing duplicate-acknowledgment token when the duplicate-review flow requires it.

The orchestration must not set the two derived coverage attestations unless the request came through the supported Cruise activation review for a shape the Cruise compiler can represent completely.

Unknown/unsupported shapes use Advanced Supplier planning.

The command remains the final authority.

## 18. Concurrency and stale review behavior

The GET review is never a guarantee that POST will succeed.

Activation must retain existing optimistic and transactional protections.

Examples of state that may change between review and POST include:

- Arrangement/version lock version;
- rate readiness;
- cabin definitions;
- Supplier agreement state;
- deadlines becoming elapsed;
- compatible confirmation evidence;
- duplicate identifier candidates;
- governing/predecessor state.

On conflict or changed authoritative state:

- do not partially activate;
- preserve existing command rollback behavior;
- reload the Cruise activation review;
- show the current blocker or required Staff action;
- issue a fresh idempotency key only according to existing retry/idempotency semantics;
- do not silently resubmit an acknowledgment for a newly arisen condition.

## 19. Successful activation

After successful activation, do not send Staff into the generic Supplier-planning journey as the primary outcome.

Show an activated Cruise state such as:

> **Cruise supplier arrangement activated**
>
> Version 1 is now the governing Supplier Arrangement version.

For a successor:

> **Cruise successor activated**
>
> Version 2 is now governing. Version 1 remains preserved as the superseded version.

Provide the primary next action:

**Connect to Client service**

This enters the existing Client-service connection workflow.

UX-5 does not redesign that workflow.

Also provide:

**Return to Cruise overview**

The Cruise overview derives Activation as complete from existing authoritative state.

## 20. Client-service boundary

Reaching the existing Client-service connection is the end of UX-5.

UX-5 does not:

- create a new Service Offer automatically;
- alter an existing Service Offer automatically;
- attach supplemental capacity to a Client choice automatically;
- create Package inclusion;
- create Client prices;
- publish anything;
- determine how multiple Supplier Pools should map to one Client choice;
- implement Offer Design.

If no Client-service connection exists, Staff reaches the existing creation/connection path.

If one exists, Staff reaches the existing connection state.

Any future Offer Design decision remains outside UX-5.

## 21. Unsupported Cruise shapes

The Cruise activation page is available only where the existing Cruise shape detector and UX-5 compiler can represent the relevant activation facts losslessly.

Unsupported facts remain visible where possible and route to Advanced Supplier planning.

Examples include:

- unrecognized activation blocker;
- unsupported commitment-trigger authority requiring input;
- cost-source structure the Cruise rate review cannot represent;
- activation consequence the Cruise compiler cannot safely explain;
- incompatible exact-version Supplier confirmation shape.

The fallback is:

**Review in Advanced Supplier planning**

Do not:

- hide unsupported authoritative records;
- flatten them into a supported Cruise shape;
- mark them ready;
- manufacture acknowledgments;
- activate using incomplete Cruise orchestration.

## 22. Visual hierarchy

UX-5 should remain consistent with the read-first direction established in UX-4.

Use:

**Page → major review sections → structured rows/items**

Do not return to the generic activation page's continuous form layout.

Recommended presentation:

- separate surfaced regions for major review sections;
- compact definition grids for sailing/agreement facts;
- compact rows/tables for cabin inventory and rates;
- status text/chips used consistently;
- corrective actions beside the affected row or section;
- activation status visually distinct from factual review;
- Supplier confirmation fields shown only when activation is otherwise relevant;
- consequential activation action clearly separated from ordinary Review links.

Avoid nested card proliferation.

Narrative explanatory text should use a restrained readable line length; operational tables/rows may use the available card width.

## 23. Accessibility and responsive behavior

At minimum prove desktop and mobile behavior at approximately:

- 1280px;
- 375px.

The page must:

- have no horizontal page overflow;
- retain the same semantic review order at all widths;
- use semantic headings;
- use table headers/scopes where tables remain tables;
- provide non-color status meaning;
- provide accessible names for Review and activation actions;
- associate every evidence/acknowledgment input with a label;
- make blocker links keyboard accessible;
- preserve visible focus;
- expose command errors near the relevant section and in the existing error summary pattern;
- not rely on visual position alone to identify Ready/Needs attention states.

On narrow screens, tabular cabin/rate information may become compact stacked rows/cards as long as semantic relationships remain clear.

## 24. Error behavior

Command errors must return Staff to the Cruise activation review rather than the generic activation page.

Known errors should be placed near their relevant section where possible:

- stale/conflict → activation status;
- Supplier confirmation evidence error → Supplier confirmation evidence;
- identifier error/duplicate review → Supplier confirmation evidence;
- elapsed requirement acknowledgment → activation consequences;
- confirmed quantity/amount error → affected commitment consequence.

The authoritative command message may be retained in the error summary, but the normal Cruise surface should provide plain-language context when safely available.

Do not parse command-message prose to determine domain meaning when structured error/readiness information exists.

## 25. Tests

### 25.1 Compiler/service tests

Prove that the Cruise activation review:

- is read-only;
- derives status from authoritative readiness;
- does not persist completion/readiness;
- maps known blocker codes to Cruise language and corrective destinations;
- preserves every authoritative blocker;
- maps unknown blockers to Advanced fallback;
- distinguishes incomplete numeric inventory from intentionally nonnumeric inventory;
- reports contracted versus estimate Supplier rates correctly;
- reports Supplier agreement confirmation correctly;
- uses existing deposit evaluation rather than recalculating it;
- reports quantity-not-tracked without converting it to zero;
- reports activation consequences from existing definitions;
- detects unsupported trigger/consequence shapes rather than silently omitting them.

### 25.2 Activation orchestration/request tests

Prove:

- activation still invokes `ActivateSupplierArrangementVersion`;
- Arrangement/version lock versions are submitted;
- idempotency is preserved;
- supported ready Cruise submits cost-source coverage attestation;
- supported ready Cruise submits commitment-trigger coverage attestation;
- Cruise orchestration does not submit provisional-cost acknowledgment as an estimate bypass;
- estimate-only Cruise rates remain blocked;
- elapsed acknowledgment is false/absent when nothing is elapsed;
- elapsed acknowledgment is true only after explicit Staff input;
- a requirement becoming elapsed between review and POST causes command rejection/review refresh rather than silent acknowledgment;
- existing compatible exact-version `SupplierConfirmation` can be reused;
- new activation confirmation evidence uses the existing command contract;
- Cruise agreement confirmation alone is not silently substituted for `SupplierConfirmation`;
- duplicate Supplier identifier review remains intact;
- required confirmed quantity/amount input is preserved for applicable triggers;
- unsupported trigger shapes cannot use the normal Cruise activation POST;
- stale lock conflict does not partially activate.

### 25.3 Domain regression tests

Retain/prove:

- authoritative readiness reruns inside activation;
- activation is atomic;
- numeric capacity is established as before;
- carried capacity remains carried;
- On request/externally managed capacity remains nonnumeric;
- no fabricated opening quantity is created for nonnumeric Pools;
- Initial Deposit materialization follows existing evaluator semantics;
- quantity-not-tracked does not materialize a fabricated zero-dollar tranche;
- deadline materialization remains unchanged;
- commitment creation remains unchanged;
- activation manifest and coverage fingerprint remain unchanged in authority;
- activation links exact-version Supplier confirmation;
- predecessor/successor transition remains unchanged;
- governing version changes only on successful activation;
- audit/exposure consequences remain intact.

### 25.4 Canonical system journey

The browser proof should deliberately begin with a Cruise that is not ready.

Using the canonical Celebrity Beyond Cruise:

1. Open Activation from the Cruise overview.
2. Verify Supplier, ship, sailing dates, group reference, and version.
3. Verify E3/O1/DI cabin categories and opening quantities.
4. Where the proof includes On request inventory, verify **Quantity not tracked** and no false opening-quantity blocker.
5. Make one numeric cabin Pool genuinely incomplete and verify it blocks activation with a Cabin categories corrective action.
6. Correct it and verify the blocker disappears.
7. Leave one cabin Resource on estimate-only rates.
8. Verify activation is blocked with a Supplier rates corrective action.
9. Verify there is no provisional-estimate acknowledgment checkbox.
10. Record/review the required contracted rates and mark them ready through UX-3.
11. Return to activation and verify the rate blocker disappears.
12. Verify the exact Cruise Supplier agreement is confirmed.
13. Verify Initial Deposit using authoritative live evaluation.
14. For the canonical all-numeric opening, verify `$50.00 × 24 = $1,200.00`.
15. Verify July 9, 2027 Hard Stop and its combined wording.
16. Verify August 8, 2027 Final Payment.
17. Verify optional missing TC/GAP/payment restrictions/cancellation terms do not become blockers solely because they are absent.
18. Verify activation consequences are understandable in Cruise language.
19. Verify generic cost-source and commitment-trigger acknowledgment checkboxes are not shown.
20. Verify Supplier confirmation evidence is explicitly recorded or reused.
21. If the fixture date makes a requirement already elapsed, verify explicit overdue acknowledgment is required; otherwise create a focused proof for that state.
22. Activate through `ActivateSupplierArrangementVersion`.
23. Verify numeric opening capacity is established correctly.
24. Verify any On request inventory remains nonnumeric.
25. Verify deposit/deadline/commitment consequences match existing domain behavior.
26. Verify the Arrangement/version is governing.
27. Verify the success state identifies the activated Cruise.
28. Follow **Connect to Client service**.
29. Verify Staff reaches the existing Client-service connection workflow.
30. Verify UX-5 did not create Offer Design behavior, Client pricing, Package changes, or automatic Client-choice aggregation.

### 25.5 Unknown-shape system/request proof

Create or expose an authoritative blocker/consequence that UX-5 does not recognize.

Verify:

- it remains visible;
- it is not marked Ready;
- normal Cruise activation is unavailable where the unsupported shape prevents complete orchestration;
- **Review in Advanced Supplier planning** is available.

## 26. Canonical acceptance outcome

For the canonical Smith Family Reunion Cruise, Staff can reach a review that clearly communicates:

- Celebrity Cruises is the Supplier;
- Celebrity Beyond is the ship;
- the November 6–13, 2027 sailing is the exact sailing being activated;
- group reference `1119999` belongs to the confirmed Supplier agreement;
- E3, O1, and DI cabin inventory is understood;
- each covered cabin category has ready contracted Supplier rates;
- Initial Deposit is understood as `$50` per qualifying opening cabin with its current evaluated quantity/total;
- July 9, 2027 is the combined Hard Stop;
- August 8, 2027 is Final Payment;
- optional agreement benefits/reference terms are not falsely treated as activation requirements;
- every authoritative blocker has either a Cruise-language correction path or Advanced fallback;
- no estimate can be accepted through an acknowledgment checkbox;
- activation evidence is explicit;
- already-elapsed operational consequences require explicit acknowledgment;
- activation uses the existing atomic Supplier activation command;
- successful activation makes the exact version governing;
- Staff can continue to the existing Client-service connection.

## 27. Exit criteria

UX-5 is complete when:

- the normal supported Cruise activation journey no longer requires Staff to interpret the generic Supplier activation page;
- authoritative readiness remains the sole activation-readiness authority;
- Cruise blockers are understandable and actionable;
- unknown blockers fail closed;
- estimates cannot be acknowledged into acceptable Cruise contracted rates;
- intentionally nonnumeric cabin inventory does not falsely block activation;
- genuinely incomplete numeric inventory still blocks;
- activation consequences are visible before the consequential action;
- cost-source and commitment-trigger attestations remain preserved without redundant generic checkboxes;
- elapsed requirements still require explicit Staff acknowledgment;
- exact-version Supplier confirmation evidence remains preserved;
- `ActivateSupplierArrangementVersion` remains the mutation authority;
- existing activation atomicity, locks, idempotency, manifest, capacity, commitment, deposit, deadline, audit, and exposure behavior remain intact;
- successful activation leads Staff to the existing Client-service connection;
- no Offer Design functionality is introduced.

## 28. Non-goals carried forward

UX-5 does not resolve:

- one Client choice drawing from multiple Supplier Pools;
- supplemental-block Offer Design;
- Client booking/allocation;
- actual Supplier payment;
- cancellation-charge calculation;
- refund calculation;
- TC/GAP entitlement calculation;
- richer Cruise endpoint time zones;
- Cruise agreement-document storage;
- contract parsing;
- automatic inventory release;
- generic Supplier activation redesign.

Those remain outside this slice.

## 29. Delivery boundary

UX-5 should ship as one reviewable slice after UX-4 and its required nonnumeric-opening-capacity remediation are accepted.

Implementation order:

1. accept this contract and update parent/status documentation;
2. add the read-only Cruise activation compiler/presenter;
3. build the Cruise review surface and blocker translation;
4. add activation consequence presentation;
5. add compact existing/new Supplier confirmation evidence handling;
6. add Cruise activation orchestration over `ActivateSupplierArrangementVersion`;
7. add success state and existing Client-service connection handoff;
8. add request/service proof;
9. add canonical responsive system journey;
10. update planning/interface documentation to reflect shipped UX-5 behavior.

Do not begin UX-6 maintenance work or Offer Design as part of this slice.