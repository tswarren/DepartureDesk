# ADR 0013: Supplier operational commitments, Deadlines, exposure, and Arrangement ending

- Status: Accepted. Implementing slice [M3E](../planning/m3e-supplier-operational-control.md). M3E.1–M3E.5 shipped; remaining work is M3E.5R, M3D remediations, then M3E.6a–M3E.7b. Whole-milestone M3E is not shipped until M3E.7b.
- Date: 2026-09-18
- Amended: 2026-09-18; amended again 2026-09-18 (tranche, earlier-of, reconciliation matrix, cascade catalog, projection locators); Accepted 2026-09-18
- Decision owners: DepartureDesk maintainers
- Parent: [M3 — Supplier planning](../planning/m3-supplier-planning.md)
- Architecture: [ADR 0008](0008-supplier-arrangement-version-topology.md), [ADR 0009](0009-supplier-contracting-and-service-provider-roles.md), [ADR 0010](0010-supplier-capacity-ledger-and-projection.md), [ADR 0011](0011-supplier-cost-definitions-and-forecast-evaluation.md), and [ADR 0012](0012-arrangement-activation-reservations-and-confirmations.md)
- Decision register: [M3E Decision Register](../planning/m3e-decision-register.md)
- Prerequisite: M3D, including M3D.9 Reservation-integrity remediation, must be shipped and final M3D correctness QC must be green at the implementation branch base. [M3E.0](../planning/m3e0-m3d-closure-gate.md) records that gate as satisfied on pinned base `344ab86`.
- Implementing slice: [M3E](../planning/m3e-supplier-operational-control.md)

## Context

M3D ships immutable Supplier commitment openings only when an activated trigger and compatible Supplier confirmation fully determine the authoritative facts. Those openings are confirmation-shaped: every shipped `SupplierCommitment` requires both a confirmation and a trigger definition. M3D also blocks ordinary Supplier inactivation on every commitment row for the committed Supplier.

M3D deliberately leaves post-opening lifecycle, Deposit Requirements, broader Deadline workflow, planning milestones, qualified exposure, Needs attention, and normal Supplier Arrangement ending to M3E.

Those capabilities create competing risks:

1. Weak lifecycle and calculation rules can hide unresolved Supplier risk, rewrite history, or present estimates as obligations.
2. Extending the confirmation-only opening schema by merely nulling foreign keys would leave mixed, underconstrained openings.
3. Allowing scheduled Deadline processing to open commitments, materialize deposits, or emit capacity events would reopen the parent rule that passage of time must not create capacity events or change commitments.
4. Exposing every persistence artifact as a separate Staff task can make ordinary Supplier planning slow and error-prone.

M3E must strengthen command and database boundaries while compressing the interface around recognizable business actions. Staff should decide what happened, what the Supplier requires, what evidence applies, and whether an exception is accepted. Staff should not manage lineage rows, coverage links, projection components, idempotency claims, or lock order.

M3E remains Supplier-side planning. It does not introduce Client demand, Client Charges, Travelers or passenger-name records, Supplier Obligations, Supplier Payments, fulfillment, Communications, Cancellation Cases, general-ledger behavior, or currency conversion.

## Decision

### Controls live below the interface

Domain records and transitions remain explicit and independently auditable. The interface may combine several compatible commands into one previewed workflow and one submit.

The governing interaction rule is:

> Controls are enforced at command and database boundaries; the interface exposes business decisions, not persistence mechanics.

The system derives Agency, Departure, Arrangement, exact version, owner, currency, compatible evidence, coverage, lineage, and projection consequences whenever those facts are unambiguous. It previews consequences and exceptions rather than requiring Staff to wire technical records.

### Commitment openings are source-shaped and immutable

M3D commitment openings remain immutable. M3E evolves `SupplierCommitment` into a **source-shaped** opening record while preserving all existing M3D commitments.

Every commitment carries a closed `opening_kind`. Database checks enforce exact, non-mixed shapes. Loose polymorphic `source_type` / `source_id` is rejected. Making confirmation or trigger foreign keys merely nullable is insufficient. There is no unrestricted **Add commitment** route.

| Opening kind | Required authority |
| --- | --- |
| `confirmation_trigger` | Existing confirmation plus trigger-definition pair |
| `deposit_requirement` | Exactly one immutable deposit requirement tranche |
| `deadline_requirement` | Exact Deadline occurrence plus commitment-definition line |

Each shape requires source-specific foreign keys, a check prohibiting incomplete or mixed shapes, a source-specific unique index for idempotency, and exact-version/ownership constraints. `deposit_requirement` must not treat “requirement or adjustment” as interchangeable sources: one commitment references exactly one tranche; uniqueness is one commitment per tranche. Existing M3D rows migrate losslessly to `confirmation_trigger`. Authority shapes such as `contracted_unit_rate_times_confirmed_quantity` remain intact under that kind.

New openings arise only from activation materialization, Staff deposit/tranche commands, Staff-recorded planning milestones that replace Deadlines (without duplicating openings), or other explicit Staff commands with complete authoritative inputs—not from elapsed time alone.

**Supersession of “manual opening”:** On Accept, this ADR supersedes the parent plan’s, ADR 0012’s, and terminology’s references to M3E “manual opening.” ADR 0012 receives a dated supersession note; its historical decision body is not silently rewritten. M3E provides guided definition-driven opening, not free-form commitment creation.

### Commitment disposition is append-only

A commitment ceases to require action only through an immutable disposition event. Closed outcomes are:

- `satisfied`: the required action occurred; qualifying evidence or a specifically allowed Staff attestation proves the result;
- `released`: the Supplier or contract released the Agency from the requirement; compatible release evidence is required;
- `waived`: elevated override authority accepts the unmet requirement and records a reason;
- `cancelled`: a compatible lifecycle event ended the governed work; and
- `superseded`: one exact compatible replacement commitment governs instead.

`released` is not collapsed into `cancelled` or `waived`. They differ in evidence and authority.

A missed Deadline is not a disposition. The commitment remains open and becomes overdue.

Every disposition records Agency, Departure, Arrangement, exact commitment, actor, occurred/effective time, recorded time, outcome-specific proof, and idempotency identity. The current state is derived from the immutable opening and later events.

An incorrect current disposition is corrected with an immutable `reopened` event targeting that exact disposition. Reopening restores open status without editing or deleting history. Ordinary Arrangement-management authority may reopen; a later waiver still requires elevated override authority. **Reopening is rejected after the Arrangement has ended.** Privileged historical correction after ending requires a later, separately accepted design.

### Ordinary inactivation blocks only open commitments

Ordinary Supplier inactivation blocks only commitments whose current event-derived state is open, under lock with a final authoritative recheck. Terminal dispositions cease blocking. This amends M3D’s “every commitment row blocks” behavior for the committed Supplier snapshot. Forced inactivation continues to preserve openings and performs no disposition.

### Shared evidence uses immutable coverage sets

One immutable evidence link may satisfy several commitments through one explicit immutable coverage set. The set contains the exact selected commitments and never acquires later members implicitly.

The command validates every member for Agency, Departure, Arrangement, exact owner, version, commitment type, and governed-scope compatibility, then atomically creates the coverage link and each derived disposition.

Correction is explicit:

- exact-commitment disqualification reopens one covered commitment while retaining the evidence for the other members; or
- whole-coverage revocation revokes the link and atomically reopens every commitment whose current satisfaction depends solely on it.

Neither path mutates the original set or its original dispositions.

### Deposit Requirements are planning facts, not accounting records

A Deposit Requirement Definition belongs to one exact Arrangement version. It records:

- one supported activation trigger;
- one supported amount formula;
- one supported due-date rule;
- explicit currency;
- explicit covered sources; and
- calculation and rounding scope.

The rule catalog is closed. Trigger and date shapes support fixed dates, supported date offsets, qualifying events (including Staff-recorded planning milestones), and bounded `earlier_of` / `later_of` composition. Amount shapes support fixed amount, quantity multiplied by rate, percentage of selected Supplier cost sources, and target amount less prior materialized Deposit Requirements (staged balance / **cumulative target**). There is no arbitrary expression engine.

Celebrity staged deposits are cumulative: an initial $50 tranche plus a final **$500 target** leaves $450 remaining after the initial $50 is handled externally—not an additional flat $500.

“Per cabin” and similar quantity language map through explicit cost or coverage sources, ordinarily `resource_units`. M3E does not add a new capacity measurement basis.

A percentage definition explicitly chooses aggregate-base or per-source calculation and rounding. Materialization snapshots every authoritative input, component amount, quantity, rate, percentage, rounding rule, currency, and result.

Materialization creates an immutable **deposit requirement tranche** (implementation name may vary; topology required) plus exactly one linked operational commitment (`opening_kind = deposit_requirement` referencing that tranche) and an actionable Deadline occurrence through an explicit materialization command—typically activation. Uniqueness is one commitment per tranche. It creates no payable, Supplier Obligation, Payment, cash event, application, balance, or accounting settlement.

Adjustments before satisfaction append calculation components that change the derived amount of the **same open tranche**; they do not create a second tranche or commitment. Historical snapshots are never overwritten. A negative adjustment reduces current contractual exposure only; it does not create a refund or receivable.

A positive adjustment after satisfaction creates a **new tranche** and a new commitment for the increment and retains the earlier satisfaction. It uses the currently governing Deadline and is immediately overdue when that Deadline has elapsed unless compatible amendment evidence supplies a successor Deadline.

Staff may close the current deposit commitment with the explicit attestation **Confirmed handled outside DepartureDesk**, a required note, actor, and timestamp. The attestation covers the complete current open tranche and must never be labeled `paid`. M3E does not track partial monetary applications.

#### Earlier-of fallback

For an earlier-of rule with a fixed fallback date and a planning-milestone arm:

1. Activation materializes the deposit tranche, its commitment, and the fallback Deadline (for example March 11).
2. Before the fallback elapses, recording `names_assigned_to_supplier` appends a replacement Deadline effective at the milestone time. It does not open a duplicate commitment or first-create the requirement.
3. If the milestone is recorded after the fallback has elapsed, the elapsed Deadline remains historical and overdue.
4. Changed amount basis follows the tranche adjustment rules above.

This keeps domain-event creation on explicit commands while making the fixed fallback enforceable even if names are never assigned.

### Staff-recorded planning milestones

M3E adds a closed-catalog `SupplierPlanningMilestoneOccurrence` family for operational facts that are not Traveler records. The initial catalog includes at least `names_assigned_to_supplier`.

A milestone occurrence records only exact governed scope, occurrence date or time, actor, optional note and evidence, and idempotency identity. It must not store traveler identities or names.

Recording a milestone is an explicit Staff command. For already-materialized earlier-of deposits, it normally **advances or replaces an unelapsed Deadline**; it does not first materialize the requirement. This preserves the Celebrity scenario without introducing M5 Traveler concepts.

### Deadlines have definitions and immutable occurrences

A Deadline Definition belongs to one exact Arrangement version. It has a stable type, rule, precision, time-zone source, cardinality, explicit coverage, and optional warning lead-time override.

Deadline types use this initial closed catalog plus `other` with a required label:

- `deposit_due`;
- `option_or_release_date`;
- `rooming_list_due`;
- `legal_names_due`;
- `final_count_due`;
- `final_schedule_or_departure_time_due`;
- `cancellation_cutoff`;
- `accessibility_confirmation_due`; and
- `other` (required label).

Definitions explicitly select one shared occurrence or one allowed per-covered-source expansion dimension. The system does not infer fan-out from the number of coverage links.

A materialized Deadline Occurrence preserves its governing definition, exact covered sources, calculated date or timestamp, rule inputs, and resolved IANA time zone. It preserves either:

- date-only precision, due throughout the local calendar date and overdue at the start of the following local date; or
- exact local date/time precision, overdue immediately after the instant.

The system never turns an unspecified time into midnight or silently uses the server time zone.

A changed governing date creates a replacement occurrence. A valid successor may supersede an unelapsed occurrence. An elapsed occurrence remains history and requires compatible amendment evidence or a linked commitment disposition; it is never erased by recalculation.

Actionable occurrences may govern one or more commitments opened through explicit materialization (`opening_kind = deadline_requirement` where applicable). Informational occurrences are also allowed. They appear in Arrangement and Departure timelines, create no Needs-attention finding or blocker, become historical when elapsed, and receive no commitment disposition.

### Time alone does not create authoritative domain events

This ADR **retains** the parent M3 rule: passage of time must not create capacity events or change commitments. Allowing scheduled Deadline processing to open commitments, materialize deposits, or emit capacity events would require an explicit parent architecture amendment, not this ADR alone.

Therefore:

- Activation and explicit Staff commands (deposit/tranche materialization, Deadline materialization) may create authoritative domain events. Planning milestones normally replace unelapsed earlier-of Deadlines rather than first-creating requirements.
- A known future contractual capacity release may be recorded in advance as a future-effective capacity event through the canonical capacity command.
- Reaching a Deadline boundary may change derived due/overdue status, exposure qualification, and Needs-attention visibility.
- Scheduled catch-up and synchronous rebuilds may refresh those projections under lock. Retries return the existing projection result.
- Time alone must not create a new authoritative domain event (commitment opening, disposition, deposit materialization, capacity event, Reservation response, or confirmation).

### Exact-version ownership and successor reconciliation

Deposit and Deadline definitions (and related commitment-definition lines) belong to one exact Arrangement version and use explicit coverage links to supported Arrangement, Item, capacity, Supplier cost, Reservation, or planning-milestone sources. Generic polymorphic ownership is rejected on authoritative records.

Draft definitions may be incomplete. Activation requires every enabled definition to be structurally complete, coverage-compatible, and deterministically calculable. [M3D.7](../planning/m3d7-activated-definition-immutability.md) freeze rules extend to these new exact-version definition families: only draft definitions remain editable.

Activation atomically materializes definitions whose triggers are already true, including earlier-of definitions using their fallback date; any failed required materialization rolls back activation.

When activation materializes an already-elapsed Deadline, the activation preview must show the resulting overdue open commitments, derived exposure/visibility changes, and any already-recorded future-effective capacity events that become relevant. Staff must explicitly acknowledge that exact set. The contractual date is not rewritten.

Successor definitions retain stable predecessor lineage. Successor activation uses this reconciliation matrix:

| Predecessor definition/result | Successor | Required result |
| --- | --- | --- |
| Open actionable identity | Unchanged lineage | Continue the same actionable identity—no duplicate unresolved action |
| Terminal (satisfied/released/cancelled/superseded) | Unchanged lineage | Compatible satisfaction/release may carry forward as historical continuity; waiver must not silently broaden onto the successor |
| Open | Materially changed | Supersede predecessor and open successor atomically |
| Any | Removed | Activation is blocked until Staff cancels/resolves any open predecessor actionable state, or completes an explicit disposition path; untriggered future rules may retire |
| None | Added | Materialize the new requirement on successor activation |
| Elapsed Deadline | Changed | Preserve elapsed history; never rewrite the calculated date/time |

### Exposure is qualified, explainable, and rebuildable

M3E reports Supplier-side exposure by currency and by non-additive qualification band:

- `guaranteed`: the Agency is already contractually committed from activated terms and occurred triggers;
- `contingent`: the amount becomes binding only if one named future trigger occurs; and
- `forecast`: the current best expected-final-cost projection without a claim of legal commitment.

The user-facing breakdown preserves:

- gross guaranteed Supplier exposure;
- expected commission;
- expected net guaranteed cost; and
- currently required deposit amount.

Missing required inputs produce `unknown` or `incomplete`, never zero. Estimates never enter guaranteed exposure. Bands are not summed as separate liabilities.

Expected commission nets only against its matching source, band, and currency. Gross exposure remains visible, and expected net never implies commission was earned or received. Unlike currencies are never converted or summed.

Exposure component rows and summaries are rebuildable projections, not editable truth. Components retain stable source identity and qualification reasons.

Authoritative M3E records may not use generic polymorphic source relationships. Rebuildable projection rows may store a constrained closed-catalog `source_kind` and stable source UUID for identity and drilldown, provided they retain direct Agency/Departure/Arrangement ownership, are rebuilt only from authorized source loaders, and are never used as authority for a command or invariant.

Consequential source commands synchronously rebuild the affected Arrangement projection in the same transaction. Lifecycle blockers always inspect authoritative source records rather than cached totals. An idempotent repair job may detect drift but is not part of ordinary correctness.

### Needs attention is derived; blockers remain command-specific

Needs-attention findings are deterministic typed projections. Each has a stable finding key, subject, severity, reason, and relevant `attention_at` or `overdue_at` boundary.

Users cannot dismiss a still-true condition. A finding clears when the source condition changes or an allowed commitment disposition resolves it. Waivers leave the **Needs attention** view and remain visible under **Accepted exceptions** until reopened or their governed work ends.

The initial detector catalog covers:

- open commitments requiring immediate action;
- due-soon and overdue actionable commitments;
- incomplete or failed Deadline materialization;
- incomplete or failed Deposit Requirement calculation;
- unknown or incomplete exposure components;
- unresolved Reservation-response scope from M3D; and
- capacity states that violate or rely on an accepted override.

Agencies configure warning timing, not arbitrary detector expressions. A Deadline Definition may override the Agency default lead time. Stored boundary times are evaluated at read time; status-changing jobs are unnecessary.

Findings explain state. Each consequential command owns a named blocker query over authoritative records. The same predicate may feed both, but severity alone never blocks unrelated commands.

Disposition-driven Open / Accepted-exception views may ship before the full cross-domain detector catalog. The catalog itself is an M3E plan slice deliverable, not a permission to invent dismissible warnings earlier.

### Arrangement ending is terminal and orchestrated

Normal ending is one terminal `ended` transition with actor, `ended_at`, and a required stable reason. It means the Arrangement no longer governs future Supplier planning. It does not assert cancellation, fulfillment, or financial settlement and is not reversible in place.

Ending reasons use this initial closed catalog plus `other` with a required label and note:

- `planning_concluded`;
- `agreement_expired`;
- `not_proceeding_no_live_commitment`;
- `replaced` (requires an exact replacement Arrangement link);
- `duplicate_or_entered_in_error`; and
- `other` (required label and note).

There is no force-end override. Only unresolved live governing state blocks ending. An unelapsed actionable Deadline blocks ending only when it still governs an open commitment or another live transition. A future Deadline linked solely to terminal commitments is not live governing state. Historical confirmations, capacity events, satisfied or released deposits, elapsed Deadlines, and historical exposure do not block merely because they exist.

The ending workflow previews blockers and this closed safe cascade catalog:

1. Cancel an eligible open commitment because the governed work is ending.
2. Withdraw eligible future capacity through the existing canonical capacity `withdrawn` command.
3. Apply a previously authorized Supplier capacity release through the existing canonical capacity `released` command (does not invent a commitment `released` disposition).
4. Abandon an unactivated draft successor.
5. Cancel or supersede an unelapsed actionable Deadline only together with its governed open commitment.
6. Automatically supersede future informational Deadlines with ending provenance.

Explicitly excluded: satisfaction, commitment release, or waiver; Supplier Reservation responses; removal of guaranteed exposure; fabricated evidence; changes to confirmed Reservations.

The preview issues a short-lived digest-bound token over the exact Arrangement/version, blockers, eligible cascade targets, selected actions, and relevant source versions. Submission locks and rechecks the complete graph. Changed candidates return conflict and require a new preview.

Selected cascades run through their canonical domain operations in one transaction. The command re-evaluates blockers and records ending only when none remain. Any failure rolls back every selected consequence and the ending.

An ended Arrangement rejects new versions, Reservations, capacity events, commitments, Deposit Requirement materializations, Deadline materializations, and planning milestones while preserving existing children as history.

### Authorization and visibility follow existing boundaries

M3E uses permission catalog checks, not role-name checks.

- Existing Arrangement-management authority governs ordinary definitions and evidence-driven dispositions other than waiver.
- Existing elevated override authority (`override_supplier_planning_terms`) governs waiver.
- Every selected ending cascade requires the authority its standalone command requires.
- M3E monetary data inherits M3C Supplier-cost visibility. Restricted rollups omit monetary components rather than masking them or displaying zero.
- Viewer surfaces contain no mutation controls or hidden mutation data.

M3E introduces no new monetary-visibility or waiver permission unless implementation proves the current catalog cannot express those accepted boundaries and this ADR is amended first.

### Interface compression is part of correctness

The full operational workspace lives under the Arrangement. The Departure provides read-only drillable rollups. An Agency-wide operational dashboard is deferred.

Ordinary workflows must be compressed:

- one evidence review may satisfy one immutable coverage set;
- one guided Deadline form selects a business template rather than constructing a rule graph;
- one guided Deposit Requirement form selects a fixed, per-unit, percentage, or staged-balance shape;
- one activation checklist shows only blockers, changed consequences, and required acknowledgments;
- one ending review presents safe eligible cascades and unresolved blockers; and
- technical lineage, calculation snapshots, coverage membership, idempotency, and projection components stay behind explicit detail disclosures.

Draft planning is permissive. Full enforcement occurs at activation and consequential transitions. Uncommon corrections, revocations, waiver, release, and ending use focused confirmation surfaces; they do not become persistent ordinary-page controls.

## Consequences

### Positive

- Supplier risk remains explicit without creating accounting records prematurely.
- Commitment and Deadline history cannot be rewritten to hide missed or accepted risk.
- Opening authority remains constrained and migratable from M3D without polymorphic sources.
- Deposit calculations are reproducible and distinguish contractual requirement from money movement.
- Celebrity name-assignment timing works without Traveler records.
- Exposure remains qualified, source-traceable, currency-safe, and rebuildable.
- Time-boundary visibility remains safe without hidden background domain mutations.
- Arrangement ending cannot conceal unresolved live state.
- Persistence rigor is compressed into recognizable Staff workflows.

### Costs

- Persistence requires source-shaped openings, immutable disposition/reopening history, coverage sets, versioned definitions, materializations, adjustments, occurrence replacement, planning milestones, and rebuildable projections.
- Successor activation gains another reconciliation family.
- Projection catch-up requires scheduled and synchronous rebuild paths without creating domain events.
- Ending requires a digest-bound preview and a multi-aggregate lock/recheck contract.
- Accept must amend parent, ADR 0012 (supersession note), terminology, and inactivation semantics in the same documentation change.
- System and concurrency proof must cover both domain correctness and compressed UI behavior.

## Alternatives rejected

### Mutable commitment status and editable Deadline dates

Rejected because corrections would erase what Staff knew and when they knew it.

### One generic resolved outcome

Rejected because satisfaction, release, accepted risk, cancellation, and replacement require different authority and proof.

### Collapsing `released` into `cancelled` or `waived`

Rejected because Supplier/contract release and Agency waiver are different operational facts.

### Nullable confirmation/trigger keys without opening shapes

Rejected because mixed or incomplete openings would be underconstrained and hard to migrate safely.

### Deposit openings keyed to “requirement or adjustment”

Rejected because those are incompatible source shapes behind one opening kind. One commitment references exactly one tranche.

### Milestone-first materialization of earlier-of deposits

Rejected because elapsed time cannot materialize the fallback. Activation materializes with the fallback Deadline; milestones advance unelapsed Deadlines.

### Deposit requirements as Supplier Obligations or Payments

Rejected because M3E plans contractual requirements and does not own accounting execution.

### Free-form rule and formula builders

Rejected because they are difficult to validate, explain, migrate, and prove deterministic.

### One net exposure number

Rejected because it would conflate legal gross exposure, expected commission, contingent cost, and forecast.

### Manually dismissible Needs-attention findings

Rejected because dismissal would create a second unsupported truth separate from the source condition.

### Force-ending an Arrangement

Rejected because one override could bypass several independently governed consequences.

### Scheduled Deadline processing that creates commitments, deposits, or capacity events

Rejected while the parent automation rule stands. Reopening that rule requires an explicit parent architecture amendment.

### Traveler or passenger-name records for name-assignment timing

Rejected because M5 identity concepts are out of M3E scope. Staff-recorded planning milestones suffice.

### Post-ending commitment reopen as an ordinary path

Rejected. Any privileged historical correction after ending requires a later, separately accepted design.

### One UI action for every persistence record

Rejected because implementation topology is not a Staff workflow and would add ceremony without improving control.

## Implementation boundary

This ADR authorizes only the records and behavior named by an Accepted M3E slice. It does not authorize Client demand, Client Charges, Travelers, Supplier Obligations, Supplier Payments, fulfillment, Cancellation Cases, Communications, file upload, remittance, general-ledger exports, currency conversion, or an Agency-wide operations dashboard.

ADR 0013 becomes Accepted only with the companion M3E contract and the parent / ADR 0012 / terminology supersession notes named above. It becomes implemented only after every M3E exit criterion passes and documentation marks the slice Shipped.
