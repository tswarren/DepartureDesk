# Cruise Composition UX

**Status:** Accepted 2026-09-28. UX-1, the read-only overview, is the only authorized implementation slice. UX-2 through UX-7 are specified here and are not authorized until the UX-1 overview has been reviewed at 375, 768, 1280, and 1400 pixels and that review shows the hierarchy reduces cognitive load. Not authority for Hotel, Slice 3A, agreement documents, or a workflow engine.

**Parent:** [M4D.1 — Departure Composition Workspace](m4d1-departure-composition-workspace.md). Domain authority remains the accepted [Cruise rework](m4d1-cruise-rework.md). This plan changes presentation and orchestration only.

Journey notes in [drafts/cruise-remediation-ux](drafts/cruise-remediation-ux/cruise-journey-ux.md) are exploration. Where they differ from this plan, this plan governs.

## Invariant

Every write continues through the accepted Cruise and Supplier commands and their versioning, idempotency, and authorization contracts. The simplified UI must not introduce a second representation of Cruise inventory, rates, agreements, deposits, deadlines, or terms.

Section status and `recommended_next_action` are derived from authoritative Cruise records each time the overview is compiled. There is no workflow engine, task record, completion flag, or persisted journey state. `recommended_next_action` is a UX recommendation. It is not business state, and it does not block any other section link.

`CompileCruiseCompositionSummary` is read-only. It derives presentation state from authoritative records and existing readiness and query services. It does not introduce a second definition of completeness or activation readiness.

## Journey

Create the Departure, add the Cruise, then return to the overview between tasks. None of these steps is enforced navigation. Staff should be able to answer three questions: what is recorded, what still needs attention, and what is recommended next.

Later Supplier changes return to the same overview. Connecting a Client service stays the existing handoff after activation.

## Recommendation groups

All section links stay available. The compiler chooses one recommendation. Within a group, order is stable display priority and has no business significance.

1. Missing prerequisite: cabin categories, then Supplier rates for a cabin that has none.
2. Incomplete agreement facts: record or finish the Supplier agreement.
3. Activation requirements still open: ready contracted rates, initial deposit, hard stop, final payment. The overview names the other open items in this group. It does not treat that display order as the required work order.
4. Readiness blockers. Show the highest presentation-priority Staff-actionable blocker returned by `SupplierArrangementActivationReadiness`. Retain every blocker for Activation review. Presentation order, with no business meaning: `cruise_agreement_unconfirmed`; `cruise_contracted_rates_missing` for the first cabin in stable resource order; `cruise_deposit_treatment_missing`; otherwise the first remaining blocker in readiness order.
5. Ready: review activation.

Missing deposits or deadlines are journey guidance. They are not activation blockers unless readiness says so. Optional terms never become the recommendation. Commission, tour conductor, GAP, the `$500` rule, card restrictions, and the cancellation ladder may be absent without looking like failures.

An incompatible Cruise shape still opens Advanced Supplier planning and does not invent a summary.

## UX-1 — Orient

**Authorized.** Replace the stacked body of the Cruise show page with a read-only hub on the current Cruise route. Existing edit links may keep opening today's forms. Agreement, term, and later-capacity writes that have no separate page yet stay reachable from this page.

The hub shows sailing, cabins, rates, agreement, requirements, terms, and activation, plus `recommended_next_action`. Client service stays linked and is not a step in the strip. The generic activation page stays in place.

Proof: the compiler tests cover the recommendation groups and prove every readiness blocker is retained while one recommendation is chosen. A browser test opens a new Cruise, sees the cabin-category recommendation, then after a category exists sees the rates recommendation, with agreement, requirements, and activation visible as their own statuses. Check the overview at 375, 768, 1280, and 1400.

## Later slices

These slices are specified so the journey stays coherent. Do not implement them under this acceptance.

### UX-2 — Establish supply

Focused sailing, agreement, and cabin pages. Sailing stays the current sailing editor. Agreement uses the existing provisional, confirm, and correct commands. Group creation date stays required. Group number and contract date stay optional until confirm. Correction does not show internal confirmation fields.

Cabin entry is a batch form in front of `CreateCruiseCabinCategorySetup`. Each row is an independent command invocation. Do not add a batch domain command. The form validates every row locally before submit. If a later command fails, keep the categories already created, redisplay the unresolved rows and the error, and do not create duplicates on retry. Labels are Fixed block, On request, and Externally managed. The happy-path proof is E3, O1, and DI saved as 8 cabins each, returning to `3 · 24 cabins`. A failed-row proof is required, and it is not the primary proof.

### UX-3 — Establish economics

One category and one stage on the current Supplier-rates route. For the supported canonical Cruise rate shape, the form presents base fare, NCCF, discount, and taxes across first/second, third, and single. Those are the fixture's components, not a redefinition of every Cruise price. The form translates that shape into the existing Supplier rate commands. The adapter still builds occupancy profiles.

`DetectCruiseSupplierRateShape` decides whether the form may edit. A definition it cannot represent losslessly opens Advanced Supplier planning and is not partially edited. The simple commission control edits only the supported commission basis. An unusual percentage basis is not flattened.

Show Single, Double, and Triple totals and expected commission from the existing preview. Record contracted rates leaves the estimate unchanged.

### UX-4 — Record requirements

Presets recognize and produce the accepted Cruise shapes: initial deposit, hard stop, and final payment. They do not mean every Cruise has exactly those three. An unrecognized existing requirement stays visible as an additional requirement and opens through Other or Advanced. The simplified page never deletes, rewrites, or hides it.

Initial deposit still uses structural `initial_deposit` recognition, shows group creation plus 30 days as a suggestion, and does not rewrite a saved due date. Hard stop records the date and the Staff sentence. It does not release inventory.

Known term rows edit through the existing term and commercial-benefit commands. Anything the checklist does not understand appears as “Additional Supplier term — Review in Advanced.” Missing optional terms read “Not recorded.”

### UX-5 — Review and activate

Plain-language activation review. The button remains the existing activation command. Blockers are the readiness result, in Cruise language. An estimate is a blocker, not an acknowledgment. After activation, offer the existing Client-service connection. Do not build Offer Design.

### UX-6 — Maintain

On an active Cruise, “Change inventory” asks whether Supplier terms changed. Same terms uses the existing same-terms increase. Changed terms uses the existing supplemental block, then that successor's own confirmation, contracted rates, and deposit treatment. The original initial deposit is not rewritten. Advanced planning can still reach the generic successor command.

### UX-7 — Cleanup

Remove superseded normal-path forms. Update the Cruise agreement section of the interface contract. Finish responsive and accessibility coverage. Keep Advanced reachable.

## Out of scope

- Slice 6 agreement documents.
- Hotel, Transportation, Activity, and any Slice 3A code.
- A parallel Cruise inventory, rate, agreement, deposit, deadline, or term model.
- A generalized workflow engine, task records, completion flags, or persisted journey state.
- Letting an estimated rate through activation by acknowledgment.
- Calculating tour-conductor or GAP entitlements.
