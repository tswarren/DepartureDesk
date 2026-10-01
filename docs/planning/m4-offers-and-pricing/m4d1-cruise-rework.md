# DepartureDesk Cruise rework — decision and delivery plan

**Status:** Accepted 2026-09-27. Slices 1–5 and 7 are implemented. Slice 6 document storage stays deferred. Not authority for Hotel, document storage, or a general policy engine.

Optional departure and return ports, itinerary notes, and commercial-benefit terms are accepted in [Sailing ports and commercial benefits](m4d1-cruise-ports-and-commercial-benefits.md). This plan does not reopen them.

**Base:** M4D.1 Cruise slices 2A–2D are shipped; Slice 3R governs the separate non-Cruise sequence. The [Celebrity Beyond 2027 fixture](../fixtures/celebrity-beyond-2027-canonical-scenario-draft.md) is Approved. The detailed delivery notes are [Cruise Remediation — Supplier Agreement, Contracted Rates, Deposits, and Amendments](../drafts/DepartureDesk-cruise-remediation/dpearturedesk-cruise-remediation-supplier-agreement-etc.md), aligned to this plan. Where they differ, this plan governs.

This remediation stays at the Cruise MVP boundary. It does not add booking or accounting behavior, a general policy engine, Cruise-specific document storage, or another supplemental-deposit case.

## 1. Product boundary

The Cruise workflow ends at an accurate, reviewed Supplier Arrangement, with an explicit handoff to the already-shipped Offer Design workflow. It does not create Client Trips, allocations, Supplier payments, refunds, or matching of deposits to individual cabins.

Staff can save each section independently: sailing, cabin block, Supplier rate stage, group agreement confirmation, initial deposit, other deadlines, and booking-dependent Supplier policy. An invalid save retains entered values and never changes a valid sibling. Draft, governing, and proposed-successor states are always distinguishable.

## 2. Revised decisions to accept explicitly

| Decision | Contract |
| --- | --- |
| Group agreement confirmation | Provisional requires a group creation date; group reference and contract date are optional and mutable. Supplier-confirmed requires both reference and contract date, with actor and time recorded. A note is optional. No agreement document is required or introduced by this remediation. Existing evidence references remain available where already supported. Confirmation covers the Supplier agreement scope represented by that exact Arrangement version. Staff may complete transcription of contracted rates for Resources already within that confirmed scope without reconfirmation. Adding a Resource, changing the Supplier terms represented by the agreement, or otherwise changing confirmed agreement scope requires the successor/amendment path and confirmation of that successor. Ordinary edit cannot change a confirmed reference or contract date. An explicit correction makes the corrected value current and keeps the original confirmation in history. |
| Activation | Separate from confirmation. A Cruise version cannot activate until that exact version is Supplier-confirmed and every cabin Resource it covers has ready contracted rates. Confirmation may precede finished transcription. Generic M3 activation with a ready estimate remains supported for non-Cruise contracts. |
| Later amendments | A same-terms increase to an active Pool is an evidenced capacity event under the governing agreement. Changed rates, deposit treatment, or release terms use a successor that remains part of Supplier group `1119999`. The original September 13, 2026 contract date stays historical. The source scenario has no amendment date, so the changed-terms proof uses a test-provided amendment date. The successor requires its own Supplier confirmation. The governing confirmation remains in force during the proposal. |
| Rate stages | Estimate and contracted definitions are separate siblings on the same cost source. “Record contracted rates” copies estimated cells into a new contracted definition for explicit review; it does not change the estimate's stage. |
| Additional blocks | One Cruise Resource has one Pool and one exact-context rate source in the typed path. Same governing terms permit a capacity increase. Different terms create another Resource/Pool/rate source, possibly with the same real Supplier category code, plus a distinct internal block label. New blocks do not automatically join an existing Client choice. |
| Initial deposit | One $50 × selected opening Pool quantities requirement for the initial E3/O1/DI blocks: 24 × $50 = $1,200, due October 13, 2026. The calculation shows its sources and is a requirement, not a recorded payment. Once that due date is saved, changing the group creation date does not rewrite it. The mismatch is shown for Staff review and explicit correction or rescheduling. The same-terms `+4` O1 proof records a separate `4 × $50 = $200` requirement and leaves `$1,200` unchanged. |
| Later capacity deposit | No later Supplier capacity inherits an initial-deposit treatment implicitly. The canonical same-terms `+4` O1 case explicitly records `$50 × 4 = $200`. The changed-terms fixture does not prescribe a deposit amount or formula; any applicable treatment must be explicitly resolved before the successor can govern. This remediation does not add a generic yes/no supplemental-deposit feature or another changed-deposit case. |
| Allocated-cabin deposit | $500 total per allocated cabin, attributable initial credit, legal-name and allocation timing, applicable short options, and Hard Stop remain readable on the versioned Arrangement. They do not materialize a booking-level obligation. No Arrangement-wide $500 × retained cabins final-deposit tranche for this Celebrity agreement. |
| Cancellation ladder | Structured informational agreement data on the versioned Arrangement. Supplier Composition does not calculate cancellation charges, refunds, or Client credits. The ladder does not share a new generic policy abstraction with the `$500` rule or the card restrictions. |
| Dated actions | One July 9, 2027 actionable combined Hard Stop; one August 8, 2027 actionable final-payment deadline. Reaching or passing either date does not release capacity or post money. July 9 leaves the Arrangement requiring Staff action. A resulting inventory release is a separate evidenced capacity disposition on the existing Supplier-planning path. No separate October 7 rooming-list deadline without sailing-specific source authority. |
| Supporting documents | Deferred. Confirmation, rate readiness, and activation work without an uploaded file. This remediation does not build Cruise-specific or generic agreement-document storage. |
| Currency | Display USD inherited from the Departure operating currency. Do not introduce an independently editable Arrangement currency in this delivery. |

## 3. Authority amendments and actual breakage

| Authority or shipped slice | Amendment needed | Preserve |
| --- | --- | --- |
| ADR 0008 (versions) | Define stable agreement status versus pending successor confirmation, immutable confirmation/correction facts, and amendment date. | Activated definitions and prior version history. |
| ADR 0012 (activation and identifiers) | Permit a provisional group reference before confirmation; define confirmation of the exact version with an optional note and no new document association; reconcile activation's current required structured SupplierConfirmation and non-null `first_supplier_confirmation_id`; require group reference for Cruise confirmation; reuse/link exact-version confirmation safely. | Reservation confirmations, append-only identifier supersession, activation manifest, and atomic consequences. |
| ADR 0010 (capacity) | Clarify same-terms increase versus new Resource/Pool for changed terms, and retain evidence for consequential capacity events. | Immutable ledger, Pool supply-tranche identity, and explicit release. |
| ADR 0011 (cost) | No change to two-stage model. Document that changed-cost supplemental Cruise blocks use a separate Resource-scoped source. | Estimate and contracted definitions remain distinct; no Pool-scoped cost extension for this plan. |
| ADR 0013 / M3E register / Slice 2B-R | Replace the Celebrity-specific cumulative-target and Arrangement-wide names-milestone example. Keep the general-purpose quantity-derived cumulative mechanism for other contracts. Record the `$500` rule and the cancellation ladder as separate nonmaterializing versioned terms. State that July 9 requires Staff action and does not itself release capacity. | Initial Pool-derived deposit, generic tranches, deadlines, exposure, and historical commitments. |
| M4D.1 2A.1 / 2A.2R and remediations | Extend sailing fields, allow same Supplier category code on separately labeled blocks, add stage-specific typed rate selection and creation, and revise shape detection. | Stable Resource IDs, independent category saves, exact-context cost source, and Advanced fallback. |
| M4D.1 2C / 2D / ADR 0014 | A second Resource must not silently join the existing choice, price, or publication manifest. Explicit Offer Design review must govern whether it becomes a separate option; one choice drawing from several blocks is future work. | Existing exact source pins, unchanged Client values, provenance, and published version immutability. |
| Sailing timing model | No amendment in this remediation. Retain the current single Occurrence time zone. Cruise UI must not present separate port-local times as authoritative. | Date-only semantics and existing single-zone records. A later schedule amendment may add independent endpoint times. |
| Agreement documents | No storage design or upload implementation in this remediation. | Existing evidence references and structured capacity-event evidence. A file is not required to confirm, contract rates, or activate. |

**Migration rule:** Never rewrite activated definitions, original confirmations, identifier history, capacity events, commitments, or published offers. A currently open old Celebrity cumulative commitment is handled through the existing explicit disposition/successor reconciliation path. No migration silently converts it to policy.

## 4. Delivery slices and gates

### Gate 0 — Authority and fixture

Accept the revised canonical scenario; amend ADRs, M3E decision register, M4D.1 parent, affected slice plans, architecture/terminology, and testing fixtures. Pin a green main commit. State the old E1/O1 values, March 11 cumulative target, July 9 final-payment, October 7 rooming-list, five GAP points per traveler, and any other superseded Celebrity assumptions precisely. Retain historical plans with explicit supersession notes.

**Exit:** one source of truth for the scenario; no contradictory active acceptance assertions.

### Slice 1 — Estimate to contracted rate progression

Add a dedicated typed command that, under one lock/transaction/idempotency boundary, creates a contracted sibling definition from an estimate within the same exact cost source. Expose a stage selector for viewing/editing, provenance entry at contracted forecast readiness, and clear comparison. The typed detector must reconstruct each stage separately and must not choose an arbitrary working definition. Prevent duplicate definitions per stage. Existing data remain unchanged.

**Proof:** O1 estimate saved; contracted copy created, edited and marked ready; estimate identity/value preserved; forecast chooses ready contracted; failure rolls back; activation/successor histories stay intact.

### Slice 2 — Sailing and group agreement lifecycle

Add group creation date, provisional reference, optional contract date, confirmation of the exact version, explicit correction, and the one-time proposed Arrangement name. Keep the shipped port fields and the single Occurrence time zone. Avoid creating a fake Reservation confirmation. Display Departure currency.

**Proof:** provisional save without reference; confirm only with reference and contract date; optional note and no new document field; edit prohibited after confirmation; an explicit correction makes the new reference or contract date current and keeps the original confirmation in history; completing contracted rates for a Resource already in the confirmed scope does not require another confirmation; adding a Resource or changing confirmed agreement scope does; no duplicate identifier or activation on replay. Do not extend sailing with separate port time zones.

### Slice 3 — Booking-dependent policy and operational actions

Keep the Pool-derived initial deposit and trace. Record the `$500` allocated-stateroom rule, its credit and timing, and the card restrictions as readable versioned agreement data. Record the cancellation ladder as its own structured informational data on the same version. Do not introduce a shared policy engine, and do not calculate charges, refunds, or credits. Adjust Cruise UI templates so the Celebrity path offers one combined Hard Stop and a separate final-payment action, not an Arrangement-wide final-deposit template. Suggest October 13 from group creation plus 30 days. After that due date is saved, a later group-creation-date edit leaves it in place and shows the mismatch for explicit correction or rescheduling. Passing July 9 or August 8 does not release inventory or post money.

**Proof:** activation preview shows $1,200, July 9 Hard Stop, August 8 final payment, the readable `$500` rule, and the cancellation ladder, with no final cumulative tranche, rooming-list occurrence, or computed cancellation charge. A saved October 13 due date survives a group-creation-date edit and shows the mismatch. Failed policy or deadline saves leave rates and sibling actions untouched. Existing historical tranches are preserved.

### Slice 4 — Later capacity and supplemental Resources

Expose evidenced same-terms increase on the existing Pool. No later Supplier capacity inherits an initial-deposit treatment implicitly. For the canonical `+4` O1 increase, record `$50 × 4 = $200` and leave `$1,200` unchanged. For different terms, add a new Resource, Pool, and rate source in a successor that stays in group `1119999`, with the real Supplier code `O1` and the internal label **Supplemental O1 block**. Use a test-provided amendment date and test-only rate amounts. The successor needs its own Supplier confirmation. The changed-terms fixture prescribes no deposit amount or formula. Any applicable treatment must be explicitly resolved before that successor can govern. Do not add a generic yes/no supplemental-deposit feature or a second changed-deposit scenario. Do not copy one block's cost authority to another by label matching.

**Proof:** `+4` same-terms O1 cabins produce a capacity event, keep the existing rate source, and add `$200` without changing `$1,200`. Four differently priced O1 cabins create a distinct Resource, Pool, and rate source under group `1119999`, with a test-provided amendment date and no assumed `$50` carry-forward. Activation of that successor waits for its own confirmation, ready contracted rates, and an explicit deposit resolution. Original history and cost definitions remain unchanged. Unsupported graphs remain readable with Advanced fallback.

### Slice 5 — Offer Design handoff for a supplemental block

Keep the new block Supplier-only until Staff explicitly reviews its Client offering. First release may expose it as a separate priced option with a clear Client-facing description, if that presentation is truthful. One O1 choice consuming multiple Supplier blocks is deferred until a separate alternative-source/selection contract is accepted. Recheck capacity, price/margin findings, source compatibility, and published pins.

**Proof:** an existing published O1 choice retains its exact original source and Client price; added supply does not silently increase its selectable quantity. A new option requires an explicit draft and publication path.

### Slice 6 — Agreement documents

Deferred. Do not accept storage, upload, or addendum history in this remediation. Group confirmation succeeds without a file.

### Slice 7 — Integrated browser proof and closure

From Composition, create Smith sailing, E3/O1/DI, estimates then contracted rates, confirm group, enter deposit/actions/policy, preview, activate, add same-terms capacity, and draft a differently priced supplemental Resource. Reopen every section and prove stable IDs. Check Staff/Viewer permissions, invalid-save recovery, idempotent replay, exact-version behavior, and price isolation. Update interface contract, planning index, roadmap, terminology, and AGENTS.md.

## 5. Settled for this remediation

1. **Sailing time model:** keep the single Occurrence time zone. Do not add separate departure and return zones or independently optional endpoint times.
2. **Confirmation:** one confirmation fact for the exact Arrangement version. A note is optional. This remediation adds no agreement-document field. Recording confirmation before contracted-rate transcription is finished is allowed only for Resources already inside that confirmed scope. Adding a Resource or changing confirmed agreement scope uses the successor path. Activation still requires ready contracted rates for the Resources that version covers. An explicit correction makes the new group reference or contract date current and retains the earlier confirmation.
3. **Duplicate category codes:** the changed-terms block keeps Supplier code `O1` and uses the internal label **Supplemental O1 block**. Do not invent a Supplier code.
4. **Later capacity deposit:** no later Supplier capacity inherits an initial-deposit treatment implicitly. The same-terms `+4` O1 case records `$50 × 4 = $200`. The changed-terms fixture prescribes no deposit amount or formula; any applicable treatment must be explicitly resolved before the successor can govern. This remediation does not add a generic yes/no supplemental-deposit feature.
5. **Cancellation ladder:** structured informational data on the versioned Arrangement, separate from the `$500` rule and the card restrictions. No calculation and no shared policy engine.
6. **Hard Stop:** July 9 requires Staff action. Passing the date does not release capacity or post money. A release is a later evidenced capacity disposition.
7. **Saved deposit date:** a saved October 13, 2026 due date is not rewritten when the group creation date changes. Staff see the mismatch and correct or reschedule it explicitly.
8. **Benefits:** normal commission stays in Supplier rates. Tour-conductor credit and the four group GAP points stay recorded terms labeled **Terms recorded; entitlement not calculated.** Qualification and redemption stay out of this remediation.
9. **Documents:** no file store and no confirmation document association in this remediation. Existing evidence references remain available where already supported.

The confirmation record's minimal persisted fields are group reference, contract date, actor, time, and optional note. It has no document identifier. Correction history stays that explicit correction, not a general agreement-management design.

## 6. Explicit non-goals

No Client Trip, Traveler, allocation, Supplier Payment, receipt, obligation, refund, card record, deposit-credit matching, cancellation calculation, automatic capacity release, automatic contract parsing, automatic Client price change, multi-Pool Client choice aggregation, general policy engine, generic document storage, separate port time zones, or a second changed-deposit scenario. No old authoritative records are rewritten merely to make the revised fixture pass.
