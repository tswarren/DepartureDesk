# DepartureDesk Cruise rework — decision and delivery plan

**Status:** Draft for review, 2026-09-26. This document is not implementation authority.

Optional departure and return ports, itinerary notes, and commercial-benefit terms are accepted in [Sailing ports and commercial benefits](../m4d1-cruise-ports-and-commercial-benefits.md). This draft does not reopen them.

**Base:** M4D.1 Cruise slices 2A–2D are shipped; Slice 3R governs the separate non-Cruise sequence. The attached *Celebrity Beyond 2027 — Canonical Cruise Scenario* remains Draft until accepted. The revised fixture, this plan, and amendments to accepted ADRs must agree before implementing changed semantics.

## 1. Product boundary

The Cruise workflow ends at an accurate, reviewed Supplier Arrangement, with an explicit handoff to the already-shipped Offer Design workflow. It does not create Client Trips, allocations, Supplier payments, refunds, or matching of deposits to individual cabins.

Staff can save each section independently: sailing, cabin block, Supplier rate stage, group agreement confirmation, initial deposit, other deadlines, and booking-dependent Supplier policy. An invalid save retains entered values and never changes a valid sibling. Draft, governing, and proposed-successor states are always distinguishable.

## 2. Revised decisions to accept explicitly

| Decision | Contract |
| --- | --- |
| Group agreement confirmation | Provisional requires a group creation date; group reference and contract date are optional and mutable. Supplier-confirmed requires both reference and contract date, with actor/time recorded; note and document are optional. This confirmation covers the agreement as a whole at that revision, not individual cabin categories. Confirmed reference and date cannot be changed by ordinary edit; corrections retain prior values. |
| Activation | Separate from confirmation. A Cruise version cannot activate until its agreement revision is Supplier-confirmed and all covered cabin categories have ready contracted rates. A confirmation may be recorded before Staff finish transcribing rates, but activation remains blocked. Generic M3 activation with a ready estimate remains supported for non-Cruise contracts. |
| Later amendments | A same-terms increase to an active Pool is an evidenced capacity event under the governing agreement. A new category or changed rates, deposit treatment, or release terms uses a successor draft and a new Supplier confirmation of the amended agreement. The governing confirmation remains in force during the proposal. The original contract date remains history; the amendment has its own date. |
| Rate stages | Estimate and contracted definitions are separate siblings on the same cost source. “Record contracted rates” copies estimated cells into a new contracted definition for explicit review; it does not change the estimate's stage. |
| Additional blocks | One Cruise Resource has one Pool and one exact-context rate source in the typed path. Same governing terms permit a capacity increase. Different terms create another Resource/Pool/rate source, possibly with the same real Supplier category code, plus a distinct internal block label. New blocks do not automatically join an existing Client choice. |
| Initial deposit | One $50 × selected opening Pool quantities requirement for the initial E3/O1/DI blocks: 24 × $50 = $1,200, due October 13, 2026. The calculation shows its sources and is a requirement, not a recorded payment. A later capacity increase prompts an explicit additional-deposit decision. |
| Allocated-cabin deposit | $500 total per allocated cabin, attributable initial credit, legal-name and allocation timing, applicable short options, and Hard Stop remain booking-dependent Supplier policy. No Arrangement-wide $500 × retained cabins final-deposit tranche for this Celebrity agreement. |
| Dated actions | One July 9, 2027 actionable combined Hard Stop; one August 8, 2027 actionable final-payment deadline. Neither automatically releases capacity or posts money. No separate October 7 rooming-list deadline without sailing-specific source authority. |
| Supporting documents | Generic Supplier Arrangement file records are optional. Addenda retain originals; Staff can link exact documents to a version or term. Upload neither extracts terms nor confirms/activates an agreement. |
| Currency | Display USD inherited from the Departure operating currency. Do not introduce an independently editable Arrangement currency in this delivery. |

## 3. Authority amendments and actual breakage

| Authority or shipped slice | Amendment needed | Preserve |
| --- | --- | --- |
| ADR 0008 (versions) | Define stable agreement status versus pending successor confirmation, immutable confirmation/correction facts, and amendment date. | Activated definitions and prior version history. |
| ADR 0012 (activation and identifiers) | Permit a provisional group reference before confirmation; define confirmation of the whole agreement without mandatory note/file; reconcile activation's current required structured SupplierConfirmation and non-null `first_supplier_confirmation_id`; require group reference for Cruise confirmation; reuse/link exact-version confirmation safely. | Reservation confirmations, append-only identifier supersession, activation manifest, and atomic consequences. |
| ADR 0010 (capacity) | Clarify same-terms increase versus new Resource/Pool for changed terms, and retain evidence for consequential capacity events. | Immutable ledger, Pool supply-tranche identity, and explicit release. |
| ADR 0011 (cost) | No change to two-stage model. Document that changed-cost supplemental Cruise blocks use a separate Resource-scoped source. | Estimate and contracted definitions remain distinct; no Pool-scoped cost extension for this plan. |
| ADR 0013 / M3E register / Slice 2B-R | Replace the Celebrity-specific cumulative-target and Arrangement-wide names-milestone example. Keep the general-purpose quantity-derived cumulative mechanism for other contracts. Define nonmaterializing booking-dependent policy and the Hard Stop semantics. | Initial Pool-derived deposit, generic tranches, deadlines, exposure, and historical commitments. |
| M4D.1 2A.1 / 2A.2R and remediations | Extend sailing fields, allow same Supplier category code on separately labeled blocks, add stage-specific typed rate selection and creation, and revise shape detection. | Stable Resource IDs, independent category saves, exact-context cost source, and Advanced fallback. |
| M4D.1 2C / 2D / ADR 0014 | A second Resource must not silently join the existing choice, price, or publication manifest. Explicit Offer Design review must govern whether it becomes a separate option; one choice drawing from several blocks is future work. | Existing exact source pins, unchanged Client values, provenance, and published version immutability. |
| Sailing timing model | Separate return zone and independently optional endpoint times require an M3A/Occurrence schema and compatibility amendment. Define Pool governing zone as the sailing's departure zone. | Date-only semantics and existing single-zone records. |
| Attachment-ready ADR notes / AGENTS.md | Accept a generic file-storage and access design before schema or upload implementation. | Evidence references and structured capacity-event evidence; no document requirement. |

**Migration rule:** Never rewrite activated definitions, original confirmations, identifier history, capacity events, commitments, or published offers. A currently open old Celebrity cumulative commitment is handled through the existing explicit disposition/successor reconciliation path. No migration silently converts it to policy.

## 4. Delivery slices and gates

### Gate 0 — Authority and fixture

Accept the revised canonical scenario; amend ADRs, M3E decision register, M4D.1 parent, affected slice plans, architecture/terminology, and testing fixtures. Pin a green main commit. State the old E1/O1 values, March 11 cumulative target, July 9 final-payment, October 7 rooming-list, five GAP points per traveler, and any other superseded Celebrity assumptions precisely. Retain historical plans with explicit supersession notes.

**Exit:** one source of truth for the scenario; no contradictory active acceptance assertions.

### Slice 1 — Estimate to contracted rate progression

Add a dedicated typed command that, under one lock/transaction/idempotency boundary, creates a contracted sibling definition from an estimate within the same exact cost source. Expose a stage selector for viewing/editing, provenance entry at contracted forecast readiness, and clear comparison. The typed detector must reconstruct each stage separately and must not choose an arbitrary working definition. Prevent duplicate definitions per stage. Existing data remain unchanged.

**Proof:** O1 estimate saved; contracted copy created, edited and marked ready; estimate identity/value preserved; forecast chooses ready contracted; failure rolls back; activation/successor histories stay intact.

### Slice 2 — Sailing and group agreement lifecycle

Add group creation date, provisional reference, optional contract date, confirmation event/status, correction and amendment history, and one-time proposed Arrangement name. Extend sailing with departure/return ports and optional local times/zones under a separately accepted timing amendment. Avoid creating a fake Reservation confirmation. Make old one-zone records read identically. Display Departure currency.

**Proof:** provisional save without reference; confirm only with reference/date; optional note/file; edit prohibited after confirmation; explicit correction retains prior values; governing confirmed version plus pending successor; no duplicate identifier or activation on replay.

### Slice 3 — Booking-dependent policy and operational actions

Keep the Pool-derived initial deposit and trace. Add a structured, nonmaterializing policy summary for $500 per allocated cabin, credit, names, shorter options, cards, and cancellation ladder. Adjust Cruise UI templates so the Celebrity path offers one combined Hard Stop and a separate final-payment action, not an Arrangement-wide final-deposit template. For group creation + 30 days, prefill a fixed due date and flag a mismatch; do not silently rewrite a saved deadline when creation date changes.

**Proof:** activation preview shows $1,200, July 9 Hard Stop, August 8 final payment, and readable policy, with no final cumulative tranche or rooming-list occurrence. Failed policy/deadline saves leave rates and sibling actions untouched. Existing historical tranches are preserved.

### Slice 4 — Later capacity and supplemental Resources

Expose evidenced same-terms increase on the existing Pool. For different terms, add a new Resource/Pool and rate source in a successor draft, allow duplicate real Supplier code only with an explicit distinct internal block identity/label, and confirm the amended agreement before successor activation. Prompt for additional deposit treatment in either path. Do not copy one block's cost authority to another by label matching.

**Proof:** +4 O1 same-terms cabins produces a capacity event and keeps rates; +4 differently priced O1 cabins creates a distinct Resource/Pool/source with same real code and two distinguishable summaries. Original allocation/history and cost definitions remain unchanged. Unsupported graphs remain readable with Advanced fallback.

### Slice 5 — Offer Design handoff for a supplemental block

Keep the new block Supplier-only until Staff explicitly reviews its Client offering. First release may expose it as a separate priced option with a clear Client-facing description, if that presentation is truthful. One O1 choice consuming multiple Supplier blocks is deferred until a separate alternative-source/selection contract is accepted. Recheck capacity, price/margin findings, source compatibility, and published pins.

**Proof:** an existing published O1 choice retains its exact original source and Client price; added supply does not silently increase its selectable quantity. A new option requires an explicit draft and publication path.

### Slice 6 — Generic agreement documents

Accept storage, immutable file/version identity, tenant access, source links, and retention policy. Implement optional upload/download and addendum history at Arrangement level. Do not parse documents into authority or make upload required for confirmation, rate readiness, or capacity-event evidence.

**Proof:** original and addendum both retrievable; links show the exact supporting file; cross-Agency access denied; missing file does not block group confirmation; replacing an activated source file in place is impossible.

### Slice 7 — Integrated browser proof and closure

From Composition, create Smith sailing, E3/O1/DI, estimates then contracted rates, confirm group, enter deposit/actions/policy, preview, activate, add same-terms capacity, and draft a differently priced supplemental Resource. Reopen every section and prove stable IDs. Check Staff/Viewer permissions, invalid-save recovery, idempotent replay, exact-version behavior, and price isolation. Update interface contract, planning index, roadmap, terminology, and AGENTS.md.

## 5. Decisions to settle before accepting the implementation slices

1. **Sailing time model:** add separate return zone and permit either time individually now, or defer that expansion while retaining a single Occurrence zone. The form must never pretend unsupported fields are authoritative.
2. **Confirmation provenance:** choose a minimal exact event model that supports optional note/document and preserves existing activation/Reservation confirmation invariants. Define whether recording confirmation before all terms are transcribed is allowed (recommended: yes; activation still checks complete contracted terms).
3. **Duplicate category codes:** decide durable distinct block identity and what Staff see on Supplier summaries. Do not substitute an invented Supplier code.
4. **Additional deposits:** decide whether a later same-terms increase requires a separate supplemental requirement when Celebrity charges $50 for added cabins; never mutate the initial opening snapshot implicitly.
5. **Policy record:** choose a constrained structured Supplier policy definition with version/copy/freeze behavior. It must be readable before M5 and cannot materialize booking-level money.
6. **Benefits:** normal commission remains typed in costs. Scope TC qualification/status and the four-point GAP entitlement in a separate planning slice or mark them readable agreement policy until that slice is accepted; do not omit them from review.

## 6. Explicit non-goals

No Client Trip, Traveler, allocation, Supplier Payment, receipt, obligation, refund, card record, deposit-credit matching, automatic capacity release, automatic contract parsing, automatic Client price change, multi-Pool Client choice aggregation, general formula builder, or global relaxation of capacity-event evidence. No old authoritative records are rewritten merely to make the revised fixture pass.
