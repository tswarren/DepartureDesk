# DepartureDesk M3E Decision Register

**Status:** Accepted 2026-09-18  
**Decision date:** 2026-09-18  
**Amended:** 2026-09-18 (opening-source shapes, `released`, time-automation retention, planning milestones, inactivation open-state rule). Amended again 2026-09-18 (earlier-of activation materialization, deposit tranche identity, successor reconciliation matrix, closed ending cascades, projection source locators, cumulative staged deposit). Accepted and promoted 2026-09-18.  
**Implementation gate:** [M3E.0](m3e0-m3d-closure-gate.md) is satisfied (2026-09-19). M3D.9 is shipped; final M3D correctness QC is green at pinned base `344ab86`. ADR 0013 and the M3E plan are Accepted. M3E.1–M3E.5 are shipped; remaining implementation is M3E.5R, M3D remediations, then M3E.6a–M3E.7b. Whole-milestone M3E remains not shipped until M3E.7b.

## Ship notes

- **M3E.1 shipped:** source-shaped `confirmation_trigger` openings, append-only dispositions/reopen, multi-member evidence coverage, open-state inactivation.
- **M3E.2 shipped:** Deadline definitions and coverage/commitment lines; immutable occurrences with precision exclusivity; activation materialization and elapsed acknowledgment; due/overdue/warning projection catch-up on queue `deadlines` with no time-created domain events; `deadline_requirement` openings; M3D.7 freeze extension; successor definition copy and reconciliation matrix (`one_shared` cardinality only; `per_source` deferred).
- **M3E.3 shipped:** Deposit Requirement definitions with closed amount shapes and embedded due rules (including `planning_milestone` arms); immutable tranches and append-only components; activation materialization with `deposit_requirement` openings and `deposit_due` Deadlines; external-handled attestation (`handled_externally`, never labeled paid); Staff planning milestones (`names_assigned_to_supplier`) that replace unelapsed earlier-of Deadlines without duplicate commitments; successor copy/reconciliation; M3D.7 freeze for deposit definition families.
- **M3E.4 shipped:** Qualified exposure components and band×currency summaries; required-deposit measure; constrained projection `source_kind` locators; synchronous Arrangement rebuild; contingent→guaranteed qualification; idempotent repair.
- **M3E.5 shipped:** Closed Needs-attention detector catalog; Agency `attention_warning_lead_days` with Deadline definition override; `attention_at`/`overdue_at` read-time visibility; action-grouped Arrangement findings; Departure supplier-planning rollup; Deadline catch-up rebuilds attention without time-created domain events.

## Scope boundary

M3E extends M3D's append-only Supplier commitment core with commitment dispositions, shared evidence coverage, Supplier deposit requirements, Deadline definitions and occurrences, Staff-recorded planning milestones, qualified Supplier exposure, Needs-attention projections, and normal Supplier Arrangement ending.

M3E does **not** introduce Supplier Obligations, Supplier Payments, Client demand or sales coverage, Travelers or passenger-name records, fulfillment, Communications, Cancellation Cases, accounting balances, or foreign-exchange conversion.

## Commitment opening authority

0. `SupplierCommitment` evolves into a **source-shaped** immutable opening record. Making confirmation or trigger foreign keys merely nullable is insufficient.
1. Every commitment carries a closed `opening_kind`. Database checks enforce exact, non-mixed shapes. Loose polymorphic `source_type` / `source_id` is rejected. There is no unrestricted **Add commitment** route.
2. Opening shapes and required authority:

   | Opening kind | Required authority |
   | --- | --- |
   | `confirmation_trigger` | Existing confirmation plus trigger-definition pair (shipped M3D shape) |
   | `deposit_requirement` | Exactly one immutable deposit requirement **tranche** (initial or post-satisfaction increment) |
   | `deadline_requirement` | Exact Deadline occurrence plus commitment-definition line |

3. Each shape has required source-specific foreign keys, a check prohibiting incomplete or mixed shapes, a source-specific unique index for idempotency, and exact-version/ownership constraints. `deposit_requirement` must **not** accept “requirement or adjustment” as interchangeable sources—one commitment references exactly one tranche; uniqueness is one commitment per tranche.
4. Existing M3D rows migrate losslessly to `opening_kind = confirmation_trigger`. Authority shapes such as `contracted_unit_rate_times_confirmed_quantity` remain intact under that kind.
5. New openings arise only from activation materialization, Staff deposit/tranche commands, Deadline materialization commands, or other **explicit** Staff commands that name complete authoritative inputs—not from elapsed time alone. Planning milestones normally replace unelapsed earlier-of Deadlines; they do not open duplicate deposit commitments.
6. On Accept, ADR 0013 **supersedes** “manual opening” wording in the M3 parent slice table/glossary, ADR 0012 (via a dated supersession note), and `docs/terminology.md`. M3E provides guided definition-driven opening, not free-form commitment creation.

## Commitment lifecycle

7. Supplier commitments remain immutable openings. Closing and correction use append-only events.
8. Closing outcomes are exactly `satisfied`, `released`, `waived`, `cancelled`, and `superseded`. A missed Deadline leaves a commitment open and overdue; overdue is derived, not an outcome.
9. Each outcome has distinct meaning, proof, and authority:

   | Outcome | Meaning | Required proof | Authority |
   | --- | --- | --- | --- |
   | `satisfied` | Required action occurred | Compatible evidence coverage or specifically allowed Staff attestation | Ordinary Arrangement-management |
   | `released` | Supplier or contract released the Agency from the requirement | Compatible Supplier/contract release evidence | Ordinary Arrangement-management |
   | `waived` | Authorized Agency user accepts the unmet requirement | Required reason and accepted-risk acknowledgment | Elevated override (`override_supplier_planning_terms`) |
   | `cancelled` | Governed work no longer applies | Compatible lifecycle event that ended the governed work | Permission for that lifecycle command |
   | `superseded` | A replacement commitment governs | Exact compatible replacement commitment | Permission for the replacing command |

10. `released` must not be collapsed into `cancelled` or `waived`. They differ in evidence and authority.
11. Ordinary Arrangement-management authority may record evidence-driven outcomes other than waiver. M3E adds no new permission key for waiver.
12. An incorrect disposition is corrected by an append-only `reopened` event targeting the current disposition. Reopening restores open state and may use ordinary Arrangement-management authority. **Reopening is rejected after the Arrangement has ended.** Privileged historical correction after ending requires a later, separately accepted design—not an escape hatch in M3E.
13. Waived commitments leave **Needs attention** and remain visible under **Accepted exceptions** until reopened or their governed work ends.
14. Ordinary Supplier inactivation (`ChangeSupplierStatus`) blocks only commitments whose **current event-derived state is open**, with locking and a final authoritative recheck. Terminal dispositions cease blocking. M3D’s “every commitment row blocks” rule is amended accordingly on Accept.

## Shared evidence coverage

15. One evidence link may satisfy several related commitments.
16. The link targets an explicit, immutable coverage set of selected compatible commitments. Later commitments are never added implicitly.
17. The command atomically creates each covered commitment's disposition from the shared link.
18. Two correction modes are required:
    - exact-commitment disqualification, leaving other covered commitments satisfied;
    - whole-coverage revocation, reopening every commitment whose current satisfaction depends solely on that link.
19. Coverage compatibility must enforce Agency, Departure, Arrangement, exact owner, version, commitment type, and governed scope. Same Arrangement or type alone never implies coverage.

## Supplier deposit requirements

20. A Deposit Requirement is a dedicated, versioned definition. It is not a Supplier Commitment, Obligation, Payment, payable, or balance.
21. Definitions state their trigger, amount formula, due-date rule, currency, and explicit covered sources.
22. Trigger and due-date rules use a closed composable catalog: fixed date, supported date offset, qualifying event (including Staff-recorded planning milestones), and bounded `earlier_of` / `later_of` composition. Arbitrary expressions and free-form JSON evaluators are excluded.
23. The MVP amount catalog supports:
    - fixed amount;
    - quantity multiplied by rate;
    - percentage of selected Supplier cost sources;
    - target amount less prior materialized Deposit Requirements (**staged balance / cumulative target**).
24. Celebrity staged deposits are **cumulative**: an initial $50 tranche plus a final **$500 target** leaves $450 remaining after the initial $50 is handled externally—not an additional flat $500 on top of $50. The shipped cumulative deposit and `names_assigned_to_supplier` milestone are **Arrangement-wide**; scenario proof must not imply that assigning names for one cabin advances only that cabin’s deposit. Later per-cabin deposit or milestone work is out of M3E and must not silently introduce Traveler or client-allocation records.
25. “Per cabin” and similar quantity language map through **explicit cost or coverage sources**, ordinarily `resource_units`. M3E does not add a new capacity measurement basis.
26. A percentage definition explicitly selects aggregate-base or per-source calculation and rounding. Each materialization snapshots all components and the chosen rounding scope.
27. Materialization creates an immutable **deposit requirement tranche** (implementation name may be `SupplierDepositRequirementTranche` or equivalent; the topology is required) plus exactly one commitment that references that tranche (`opening_kind = deposit_requirement`), and links an actionable Deadline—only through an **explicit** materialization command (typically activation or Staff), not elapsed time alone. Uniqueness is one commitment per tranche.
28. Adjustments **before** satisfaction append calculation components that change the derived amount of the **same open tranche**; they do not create a second tranche or commitment. Historical calculation snapshots are never overwritten.
29. A negative adjustment reduces contractual exposure only. It does not create a refund, receivable, or Payment.
30. A positive adjustment **after** satisfaction creates a **new tranche** and a new commitment for the increment. The prior satisfaction remains. A negative adjustment does not reopen a satisfied commitment.
31. Staff may satisfy the deposit commitment using a confirmation checkbox plus required note. The UI must say **Confirmed handled outside DepartureDesk**, not **Paid**. Actor and timestamp are immutable.
32. Staff confirmation covers the full current open tranche. M3E does not track partial confirmed amounts.
33. The incremental post-satisfaction tranche inherits the currently governing Deadline. If it has elapsed, the increment is immediately overdue unless compatible amendment evidence supplies a successor Deadline.

### Earlier-of fallback (Celebrity final deposit)

34. For an `earlier_of` (or similar) rule with a fixed fallback date and a planning-milestone arm:
    1. **Activation** materializes the deposit tranche, its commitment, and the **fallback Deadline** (for example March 11).
    2. Before the fallback elapses, recording `names_assigned_to_supplier` appends a **replacement Deadline** effective at the milestone time. It does **not** open a duplicate commitment or first-create the requirement.
    3. If the milestone is recorded after the fallback has elapsed, the elapsed Deadline remains historical and overdue; the milestone does not rewrite it.
    4. Changed amount basis produces the appropriate tranche adjustment rules above.
35. This keeps domain-event creation on explicit commands while making the fixed fallback enforceable even if names are never assigned.

## Staff-recorded planning milestones

36. M3E adds a closed-catalog `SupplierPlanningMilestoneOccurrence` family for operational facts that are not Traveler or passenger-name records.
37. The initial catalog includes at least `names_assigned_to_supplier`.
38. A milestone occurrence records only: exact governed scope; occurrence date or time; actor; optional note and evidence; and idempotency identity. It must **not** store traveler identities or names.
39. Recording a milestone is an explicit Staff command. For already-materialized earlier-of deposits, it normally **advances/replaces an unelapsed Deadline**; it does not first materialize the requirement. A milestone may still arm other definitions only when the Accepted plan names that explicit materialization path.
40. This preserves the Celebrity scenario without introducing M5 Traveler concepts.

## Deadlines

41. M3E uses versioned Deadline Definitions and independent materialized Deadline Occurrences. Commitments link to occurrences rather than copying dates.
42. One occurrence may govern several commitments.
43. Definitions explicitly choose one shared occurrence or an allowed per-covered-source expansion dimension. The system never infers fan-out from the number of coverage links.
44. Definitions and occurrences preserve either:
    - date-only precision, overdue at the start of the following local date; or
    - exact local date/time precision, overdue immediately after that instant.
45. Every definition records or deterministically inherits an IANA time zone; materialization snapshots the resolved zone. Unspecified time never becomes midnight or server-local time.
46. A changed governing date creates a replacement occurrence. Unelapsed occurrences may be superseded automatically by a valid successor version; elapsed occurrences require explicit amendment evidence or a linked commitment disposition.
47. Deadline types use this **initial closed catalog** plus `other` with a required label:
    - `deposit_due`
    - `option_or_release_date`
    - `rooming_list_due`
    - `legal_names_due`
    - `final_count_due`
    - `final_schedule_or_departure_time_due`
    - `cancellation_cutoff`
    - `accessibility_confirmation_due`
    - `other` (required label)
48. Informational Deadlines are allowed without commitments. They appear in Arrangement and Departure timelines, create no Needs-attention finding or blocker, become historical when elapsed, and cannot receive commitment dispositions.
49. Future informational occurrences are superseded with explicit Arrangement-ending provenance when their Arrangement ends.

## Definition ownership, activation, and successors

50. Deposit and Deadline definitions (and related commitment-definition lines) belong to one exact Arrangement version and use explicit coverage links. Generic polymorphic ownership is excluded on authoritative records.
51. Draft definitions may be incomplete. Activation requires every enabled definition to be structurally complete and coverage-compatible.
52. [M3D.7](../m3d7-activated-definition-immutability.md) freeze rules **extend** to these new exact-version definition families: only draft definitions remain editable; after leaving draft they are immutable in Rails and PostgreSQL.
53. Activation atomically materializes every definition whose trigger is already true (including earlier-of definitions using their fallback date). Milestone arms advance Deadlines after activation as in §34–35. Any failure rolls back the triggering command.
54. If activation encounters an already-elapsed Deadline, activation is allowed only after previewing and explicitly acknowledging the overdue open commitments, derived exposure/visibility changes, and any already-recorded future-effective capacity events that become relevant. The true contractual effective date is preserved.
55. Successor definitions retain stable lineage. Successor activation uses this **reconciliation matrix** (authoritative before activation implementation):

| Predecessor definition/result | Successor | Required result |
| --- | --- | --- |
| Open actionable identity | Unchanged lineage | Continue the same actionable identity—no duplicate unresolved action |
| Terminal (satisfied/released/cancelled/superseded) | Unchanged lineage | Compatible satisfaction/release may carry forward as historical continuity; **waiver must not silently broaden** onto the successor |
| Open | Materially changed | Supersede predecessor and open successor atomically |
| Any | Removed | Activation is blocked until Staff cancels/resolves any open predecessor actionable state, or completes an explicit disposition path; untriggered future rules may retire |
| None | Added | Materialize the new requirement on successor activation |
| Elapsed Deadline | Changed | Preserve elapsed history; never rewrite the calculated date/time |

## Time boundaries and projections (retains parent automation rule)

56. Parent M3 authority stands: **passage of time must not create capacity events or change commitments.** Allowing scheduled Deadline processing to open commitments, materialize deposits, or emit capacity events would require an explicit parent architecture amendment—not ADR 0013 alone. M3E retains the parent rule.
57. Activation and explicit Staff-recorded events (including planning milestones that replace Deadlines or Staff deposit commands) may create authoritative domain events.
58. A known future contractual capacity release may be recorded **in advance** as a future-effective capacity event through the canonical capacity command.
59. Reaching a Deadline boundary may change **derived** due/overdue status, exposure qualification, and Needs-attention visibility.
60. Scheduled catch-up and synchronous rebuilds may refresh those projections under lock. Retries return the existing projection result.
61. Time alone must not create a new authoritative domain event (commitment opening, disposition, deposit materialization/tranche, capacity event, Reservation response, or confirmation).

## Qualified Supplier exposure

62. M3E presents a qualified Supplier-side breakdown by currency:
    - gross guaranteed Supplier exposure;
    - expected commission;
    - expected net guaranteed cost;
    - currently required deposit amount.
63. M3E does not calculate unsold guaranteed cost, Supplier cost not covered by Client sales, or Agency cash paid before Client collection.
64. Exposure uses separate, non-additive `guaranteed`, `contingent`, and `forecast` bands. Missing required inputs produce `unknown` or `incomplete`, never zero.
65. Expected commission nets only within the matching source, qualification band, and currency. Gross exposure remains visible, and expected net never implies commission was earned or received.
66. Unlike currencies are never converted or summed.
67. Exposure is a rebuildable projection. Component rows retain stable source identity and qualification reasons; summary totals are derived and not user-editable.
68. **Projection source exception:** Authoritative M3E records may not use generic polymorphic source relationships. Rebuildable projection rows **may** store a constrained closed-catalog `source_kind` and stable source UUID for identity and drilldown, provided they retain direct Agency/Departure/Arrangement ownership, are rebuilt only from authorized source loaders, and are **never** used as authority for a command or invariant.
69. Consequential source commands synchronously rebuild the affected Arrangement projection in the same transaction. Departure rollups derive from current Arrangement projections. Blocker commands always evaluate authoritative source records, not cached totals.
70. An idempotent background repair may detect projection drift but is not part of normal correctness.

## Needs attention

71. Needs-attention findings are deterministic, typed projections with a stable key, subject, severity, reason, and relevant Deadline boundaries. Users cannot dismiss a still-true condition. Findings may use the same constrained projection `source_kind`/UUID locator rule as exposure.
72. Findings and lifecycle blockers are separate. A shared predicate may produce a finding and participate in a named command-specific blocker query, but finding severity alone never blocks unrelated commands.
73. The initial closed detector catalog covers immediate open commitments, due-soon and overdue actionable commitments, failed or incomplete Deadline materialization, failed or incomplete deposit calculation, incomplete exposure components, unresolved M3D Reservation-response scope, and capacity states relying on or violating an override.
74. Agencies may configure timing only. A Deadline Definition may override the Agency default warning lead time; the more-specific value wins.
75. Findings store deterministic `attention_at` and `overdue_at` boundaries. Reads evaluate those boundaries against current time, so correctness does not depend on a status-changing job.
76. **Slice boundary:** M3E.1 ships disposition controls plus simple Open / Accepted-exception views driven by disposition state. The cross-domain detector catalog and Departure attention rollup ship in M3E.5.

## Arrangement ending

77. Normal ending is one terminal `ended` transition with `ended_at`, actor, and required reason. It means the Arrangement no longer governs future Supplier planning; it does not assert cancellation, fulfillment, or financial settlement.
78. Ending is not reversible in place. New activity requires a linked replacement Arrangement.
79. Ending reasons use this **initial closed catalog** plus `other` with a required label and note:
    - `planning_concluded`
    - `agreement_expired`
    - `not_proceeding_no_live_commitment`
    - `replaced` (requires exact replacement Arrangement link)
    - `duplicate_or_entered_in_error`
    - `other` (required label and note)
80. There is no force-end override. Every remaining blocker must be resolved through its owning workflow.
81. Only unresolved **live governing** state blocks ending: open commitments; pending Reservation activity requiring its own workflow; live future capacity requiring action; unelapsed actionable Deadlines **that still govern an open commitment or another live transition**; future guaranteed or contingent exposure; and pending lifecycle changes such as an un-abandoned draft successor. A future Deadline linked solely to terminal commitments is not live governing state. Historical facts do not block merely because they exist.
82. Ending uses a preview in which the user selects permitted cascade actions from a **closed catalog**.
83. The exact permitted cascades and eligibility predicates are:
    1. **Cancel eligible open commitment** — governed work is ending; commitment is open; cascade cancels via disposition `cancelled`.
    2. **Withdraw eligible future capacity** — through the existing canonical capacity `withdrawn` command for unassigned/future inventory eligible under capacity rules.
    3. **Apply previously authorized Supplier capacity release** — through the existing canonical capacity `released` command when a future-effective or otherwise eligible release is already authorized; does not invent a commitment `released` disposition.
    4. **Abandon unactivated draft successor** — through the existing abandon-successor path.
    5. **Cancel or supersede unelapsed actionable Deadline only with its governed open commitment** — Deadline and commitment handled together; Deadline alone is not silently dropped while an open commitment remains.
    6. **Automatically supersede future informational Deadlines** — required cascade with ending provenance.
84. Explicitly excluded cascades / effects:
    - satisfaction, commitment `released`, or waiver dispositions;
    - Supplier Reservation responses or confirmation fabrication;
    - removal of guaranteed exposure;
    - fabricated evidence;
    - changes to confirmed Reservations.
85. Selected cascades execute through canonical domain commands in one atomic transaction. The command locks and rechecks the full graph, applies selected actions, re-evaluates blockers, and ends only if none remain. Any failure rolls back every cascade action and the ending.
86. Ending preview uses a short-lived digest-bound token containing the exact Arrangement/version, blocker set, eligible targets, selected actions, and relevant source versions. Changed state returns conflict and requires a new preview.
87. Ended Arrangements reject new versions, Reservations, capacity events, commitments, deposit materializations, Deadline materializations, and planning milestones while preserving all existing children as history.

## Authorization and surfaces

88. M3E monetary data inherits existing M3C Supplier-cost visibility. Restricted rollups omit monetary components rather than masking them or showing zero. M3E introduces no monetary-visibility permission.
89. Full actions and detail live in the Arrangement workspace. The Departure provides read-only, drillable rollups across Arrangements. An Agency-wide operations dashboard is outside M3E.

## Implementation and acceptance

90. M3E uses dependency-ordered vertical slices:
    1. **M3E.0** — authority Accept, M3D.9 + final M3D correctness QC gate, index repair;
    2. **M3E.1** — source-shaped opening migration, dispositions (including `released`), shared evidence, reopening (not after ended), inactivation open-state blocker, simple Open/Accepted-exception views;
    3. **M3E.2** — Deadline definitions, occurrences, due/overdue projection catch-up (no time-created domain events), successor Deadline reconciliation matrix;
    4. **M3E.3** — Deposit definitions, **tranches**, materializations, adjustments, attestations, planning milestones that replace earlier-of Deadlines, deposit successor reconciliation matrix;
    5. **M3E.4** — qualified exposure projections (constrained projection source locators);
    6. **M3E.5** — Needs-attention detector catalog and Departure rollups;
    7. **M3E.5R** — integrity and recovery (same-Agency composite idempotency FKs; Deadline catch-up retries);
    8. **M3D remediations** — Reservation partial-response disclosure (sequenced before ending; does not reopen M3D domain);
    9. **M3E.6a** — Arrangement-ending authority, blockers, and digest-bound preview (no end command);
    10. **M3E.6b** — atomic `EndSupplierArrangement` and ended read-only surfaces;
    11. **M3E.7a** — operational UI recovery for M3E consequential forms;
    12. **M3E.7b** — scenario, concurrency, accessibility, performance, and release-gate documentation.
91. Each slice ships its persistence, commands, authorization, UI, and proof together. Schema-only and UI-only phase splits are rejected.
92. Durable contracts belong in ADR 0013. Slice scope, sequencing, UI, tests, and exit criteria belong in the Accepted M3E plan. ADR 0012 remains M3D historical authority and receives a **dated supersession note** for opening and inactivation wording—not a silent rewrite of its decision body.
93. Reusable executable scenario builders provide slice and composite proof:
    - Celebrity cruise: $50 initial + **cumulative $500 target** final deposit (**Arrangement-wide** cumulative deposit and `names_assigned_to_supplier` milestone; not per-cabin advancement); activation materializes final tranche with March 11 Deadline; `names_assigned_to_supplier` replaces unelapsed Deadline; rooming list and legal-names Deadlines;
    - Hilton: percentage deposit, guaranteed-room exposure, option-date future-effective capacity release recorded in advance, and recalculation;
    - transfers: per-segment final-count and schedule Deadlines;
    - excursion: minimum, cutoff, and contingent-to-guaranteed exposure via explicit qualifying command—not elapsed time alone;
    - vineyard tour: fixed and per-person costs across exposure bands.
94. Scenario proof supplements focused model, constraint, command, request, system, query-bound, job-retry, idempotency, and concurrency tests; it does not replace them.

## Deliberate departures from the initial recommendations

The decision interview intentionally selected broader or lighter-weight behaviors that the formal plan must preserve explicitly:

1. **Ending uses user-selected safe cascades** from a closed enumerated catalog rather than requiring every cleanup action before opening the ending command.
2. **One evidence link may satisfy an immutable coverage set** rather than requiring a separate user-created evidence link for every commitment.
3. **Deposit satisfaction uses a Staff checkbox and note** rather than structured external-payment evidence; therefore the system must avoid the word `paid` and must not create partial monetary tracking.
4. **Informational Deadlines are allowed** without commitments, but they are timeline-only and never create Needs-attention findings or blockers.
5. **Time does not create authoritative domain events**; projections and already-recorded future-effective capacity events carry boundary effects (retains parent automation rule).
6. **`released` is a first-class disposition**, not collapsed into `cancelled` or `waived`.
7. **Earlier-of deposits materialize at activation** with a fallback Deadline; milestones advance Deadlines rather than first-creating the requirement.
8. **Deposit openings bind one tranche**, not “requirement or adjustment.”

## Pre-accept review disposition (2026-09-18)

Accepted the compatibility review and strengthened it:

- source-shaped commitment openings (not nullable FKs alone);
- inactivation blocks only current open commitments;
- explicit supersession of “manual opening” language on Accept;
- Staff-recorded name-assignment milestone without Travelers;
- added `released` to the disposition catalog;
- retained parent rule that time alone does not create capacity events or change commitments.

Second amendment wave (same day) after further acceptance review:

- earlier-of activation materialization + milestone Deadline replacement;
- deposit tranche identity and cumulative $500 target;
- explicit successor reconciliation matrix;
- enumerated ending cascade catalog and narrowed Deadline blockers;
- constrained projection `source_kind`/UUID exception;
- closed initial Deadline-type and ending-reason catalogs.

## Next artifact

ADR 0013 and the [M3E plan](m3e-supplier-operational-control.md) are Accepted and aligned with this register. [M3E.0](m3e0-m3d-closure-gate.md) is satisfied. Production M3E.1+ began from the pinned implementation base; M3E remains not shipped until M3E.7b.
