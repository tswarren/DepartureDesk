# Cruise Composition UX

**Status:** Accepted 2026-09-28. UX-1, the read-only overview, UX-2, establish supply, and UX-3, establish economics, are accepted. UX-4, record requirements, is implemented. UX-4.5, numeric capacity evaluation, is the authorized fix. UX-5 through UX-7 are specified and not authorized. Not authority for Hotel, Slice 3A, agreement documents, or a workflow engine.

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

**Authorized.** The Cruise overview contains no normal-path data-entry forms. It renders journey status, the recommended next action, compact read summaries, and links. Existing editors stay reachable at their current routes, including the agreement page that hosts the current agreement and term forms, and are not embedded in the overview.

The hub shows a five-step strip — sailing, cabin categories, Supplier rates, agreement and requirements, activation — plus `recommended_next_action` and summary cards. Supplier terms are a card, not a strip step. Client service stays a small handoff and is not a journey step. The generic activation page stays in place.

Proof: the compiler tests cover the recommendation groups and prove every readiness blocker is retained while one recommendation is chosen. A browser test opens a new Cruise, sees the ship-name title, the five-step strip, and the cabin-category recommendation, with no agreement or commercial-benefit editor on that page. After a category exists, the recommendation moves to Supplier rates. Check the overview at 375, 768, 1280, and 1400.

## UX-2 — Establish supply

**Authorized.** Focused sailing, agreement, and cabin pages. Sailing stays the current sailing editor. Agreement uses the existing provisional, confirm, and correct commands. Group creation date stays required. Group number and contract date stay optional until confirm. Correction does not show internal confirmation fields.

Cabin entry is one collection form in front of `CreateCruiseCabinCategorySetup`. From 768px up it is a table with one column header. Below that, each row is a compact card with its own labels. Both presentations use the same `rows[]` inputs and idempotency keys. Each row is an independent command invocation. Do not add a batch domain command. The form validates every non-empty row locally before the first command. A repeated supplier code is allowed when the cabin name differs. The same code and the same name still fails on the later command, and categories already created stay saved. If a later command fails, redisplay only the unresolved rows and the error, and do not create duplicates on retry. Each submitted row keeps its idempotency key across redisplay and retry. Labels are Fixed block, On request, and Externally managed. A non-numeric inventory choice keeps the Cabins cell and shows no quantity.

Proof: Staff enters E3, O1, and DI as 8 cabins each in one save and returns to `3 · 24 cabins`. At 1280px the editor shows one column header and the category rows. At 375px that header is not shown. Submit E3, O1, and DI. Cause O1 to fail after E3 succeeds. E3 remains persisted and its inputs leave the form. O1 and DI remain populated, including their submitted values and idempotency keys. The error identifies O1. Retry after correction creates O1 and DI without duplicating E3. The overview ultimately reports `3 · 24 cabins`.

## UX-3 — Establish economics

**Authorized.** One category and one stage on the current Supplier-rates route. UX-3 adapts that tabular editor. It does not replace it with a fixed Cruise rate form, and it does not add Cruise-specific rate or commission records.

A new definition starts with **1st/2nd**, **Additional**, and **Single Supplement**, and with Base fare, NCCF, Discount, and Taxes. Those are defaults. Staff can add another supported rate profile, including Every Traveler and Every Cabin, and can add or remove an extra component. The four default rows stay on the table. A blank cell means pending. Legacy term conversion may still place NCCF and taxes on Every Traveler; that path is not the new-editor default.

Commission method sits at the top of the editor. The choices stay **Not provided yet**, **Dollar amount**, and **Percentage**. Not provided yet shows no commission inputs, and the preview says expected commission is not recorded. Dollar amount adds a commission amount on each profile and no Commissionable control. Percentage adds one **Commissionable** control per component, shared across the displayed profiles, and a commission rate on each profile. A checked credit, including a negative Discount, subtracts from the basis. When every profile has the same percentage, the save keeps the existing shared commission and its single rounding boundary. When the percentages differ, the save uses the existing per-profile commissions.

A definition whose commissionable components differ by profile is not edited here. `DetectCruiseSupplierRateShape` sends it to Advanced Supplier planning. The editor does not flatten it. Changing the commission method on a definition that already has commission asks for confirmation before save. The existing command performs the replacement.

Single, Double, and Triple totals stay on the existing preview. Percentage schedules also show the commissionable amount and expected commission for each displayed profile from that same evaluation, using the persisted bases and rate. Dollar commission shows the entered expected commission and does not invent a basis. The browser displays those results.

Record contracted rates copies the estimate, leaves the estimate unchanged, and does not mark the copy ready. Explicit zero commission stays the forecast-ready acknowledgment that omitted commission means no expected commission. It is not a fourth method on a working estimate.

Proof: a new editor shows the three default profiles and four default rows, and does not start with Every Traveler or Every Cabin. Staff can add a component and a profile. Not provided yet has no commission fields and does not show commission as $0. Dollar amount shows one amount per profile. Percentage shows one Commissionable control per component and one rate per profile. Base fare and a commissionable negative Discount at 15% produce the expected commission, and NCCF and Taxes can stay noncommissionable. Single, Double, and Triple come from the existing preview. Record contracted rates keeps the estimate and does not mark the copy ready. A per-profile commissionability split opens Advanced. The page does not overflow at 375px and 1280px.

## UX-4 — Record requirements

**Authorized.** One read-first Supplier agreement page with four sections, in order: Agreement, Deposits & deadlines, Commercial benefits, and Other Supplier terms. Add, Edit, or Correct opens one focused editor. Every write stays on the existing agreement, deposit, deadline, benefit, or term command. There is no combined save and no second requirement record.

The page reads as four section panels, then rows inside each panel. Later capacity stays its own panel. Confirmed is the success status. Recorded and Not recorded stay neutral, because a missing optional term is not an error. Add, Edit, and Correct are row actions. Remove is the danger action on a cancellation step. Open deposits and deadlines and Review in Advanced are forward links.

Initial deposit, hard stop, and final payment are the recognized requirements. They do not mean every Cruise has exactly those three. Any other existing requirement stays visible as **Additional Supplier requirement — Review in Advanced**. The simplified page does not hide, rewrite, or delete it. The deposits and deadlines page remains, including its activation review. A deposit or deadline save from this page may send the closed token `return_to=agreement`. Any other value keeps the deposits-page redirect. The controller chooses the returned item from the record it saved. It does not accept a redirect URL.

The initial deposit stores the per-cabin rate and the due date. The displayed total is the existing deposit evaluator reading current proposed opening quantities. UX-4 does not copy that quantity or total onto the deposit. Group creation plus 30 days is only a suggested due date. A saved due date is not rewritten when the suggestion changes. Hard stop is one deadline plus its existing description, within 500 characters. Saving or displaying it does not release inventory. Final payment is one date. A save that does not show an existing deadline description resubmits that description.

Allocated-cabin amount and attributable credit stay structured, with the Departure operating currency. A blank credit is rejected and is not stored as zero. UX-4 does not turn those amounts into current exposure. Cancellation add, edit, and remove each load the authoritative ladder and submit the complete resulting list through `RecordCruiseAgreementTerms`. List position addresses a step only during that edit. Remove asks for confirmation. An omitted cancellation argument leaves the ladder unchanged. An explicit empty list deletes every cancellation step, leaves other term types unchanged, and records idempotency and replay on the Supplier Arrangement version. Do not invent a placeholder step.

Commercial-benefit Add and Edit ask for wording only. When the request omits source citation, the controller resubmits the stored citation. A stored citation is shown as source information already recorded. UX-4 does not offer a way to replace or clear it. Do not invent a citation. Missing optional benefits and terms read **Not recorded**. Commission stays on Supplier rates. Reference wording is rendered with `commonmarker` and an allowlisted sanitizer over the existing text column. Reopening an editor shows the stored source. Same-terms capacity increase and the supplemental block stay on this page, outside the four sections, until UX-6.

Proof: request and service tests cover omitted-citation preservation, the complete cancellation ladder including an explicit empty clear and unchanged omitted cancellation, rejection of a blank allocated credit, preservation of an omitted deadline description, deposit evaluation from the current opening quantity, the closed return token, and visibility of an unrecognized requirement. A browser test covers the four sections, focused editing, the canonical `$50.00 × 24 = $1,200.00` deposit, the July 9, 2027 hard stop, the August 8, 2027 final payment, the `$500.00` and `$50.00` allocated-cabin amounts, cancellation add, edit, and confirmed remove, sanitized reference wording, Advanced, the transitional controls, and no horizontal overflow at 375px and 1280px.

### UX-4.5 — Numeric capacity evaluation

Opening-quantity deposit evaluation counts `block` and `allotment` pools only. On request and externally managed pools stay in the coverage and are omitted from the sum. A missing number on a numeric pool is still incomplete. When every covered pool is nonnumeric, the result is quantity not tracked: no `$0` tranche, no deposit commitment, and no activation or attention blocker. A mixed deposit keeps the numeric total and says the omitted cabins are not included. The retained quantity used by a cumulative target is unchanged. No inventory mode, pool quantity, rate, agreement, or deposit definition is rewritten.

## Later slices

These slices are specified so the journey stays coherent. Do not implement them under this acceptance.

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
