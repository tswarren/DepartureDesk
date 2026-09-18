# M3 Supplier planning

**Status:** Accepted 2026-09-16. Amended 2026-09-16. Amended again 2026-09-16 for M3B capacity. Amended 2026-09-17 for M3C cost terms. Amended 2026-09-17 for M3D authority and M3D.0. [M3A](m3a-draft-arrangement-structure.md), [M3B](m3b-supplier-capacity.md), [M3C](m3c-cost-terms-and-forecasts.md), [M3D.0](m3d0-planning-workspace-compression.md), and [M3D](m3d-activation-reservations-confirmations.md) are shipped. [ADR 0012](../adr/0012-arrangement-activation-reservations-and-confirmations.md) is implemented by shipped M3D. Later M3E–M3F slices remain unimplemented.

**Amendment 2026-09-16:** Closed decisions now authorize Arrangement and version `abandoned` (never-activated discard; not Arrangement `cancelled`); departed Departures may not create new tentative Arrangements; ordinary inactivation uses the effective-provider rule and a recovery allow-list; M3A adds only `force_inactivate_supplier_with_dependencies`; Occurrence creation fails `invalid` when no recognized zone can be stored; version `lock_version` owns child-collection concurrency. [ADR 0008](../adr/0008-supplier-arrangement-version-topology.md) and [ADR 0009](../adr/0009-supplier-contracting-and-service-provider-roles.md) lock topology and Supplier roles. Occurrence operational lifecycle (`planned`/`cancelled`) lives on the stable Occurrence identity with `lock_version`; definition rows hold commercial/schedule attributes only. M3A ships the first durable create-command idempotency family and uses an explicit create-command lock-order exception for the idempotency row.

**Amendment 2026-09-16 (M3B):** Capacity applicability is explicit on the versioned Item definition; `unmanaged` is not a Capacity Pool mode. Stable Pools carry immutable semantic identity and per-version definitions. Numeric capacity uses immutable, evidence-backed events and a rebuildable stored projection. Already-recorded future events may become effective at the end of their local effective date; date automation may refresh the projection but may not create a capacity event. Unresolved numeric capacity blocks Arrangement ending and eventual Departure closeout. M3 capacity quantities are whole numbers only; M3B supports exactly `resource_units` and `traveler_positions`; no later M3 slice may add fractional precision or another measurement basis without amending this parent and [ADR 0010](../adr/0010-supplier-capacity-ledger-and-projection.md). M3B introduces `override_supplier_planning_terms`. [ADR 0010](../adr/0010-supplier-capacity-ledger-and-projection.md) governs the capacity ledger.

**Amendment 2026-09-17 (M3C):** Exact-version Supplier cost sources carry estimate and contracted definitions on the same draft Arrangement version. Definition currency equals Departure `operating_currency`. Forecasts are deterministic derived evaluations that persist no calculated totals. [ADR 0011](../adr/0011-supplier-cost-definitions-and-forecast-evaluation.md) governs cost definitions and forecast evaluation. [M3C](m3c-cost-terms-and-forecasts.md) shipped the implementing slice.

**Amendment 2026-09-17 (M3D / M3D.0):** [M3D.0](m3d0-planning-workspace-compression.md) shipped interaction remediation over M3A–M3C and satisfied the hard prerequisite before production M3D activation work. [M3D](m3d-activation-reservations-confirmations.md) owns Arrangement activation, successors, Reservations, confirmations, effective capacity surfaces, a narrow confirmation-triggered commitment-opening core with explicit `committed_supplier_id`, and the minimal ordinary Supplier-inactivation blocker for every unresolved commitment that core can open. Incomplete confirmation inputs retain the confirmation and expose a derived unresolved condition for later M3E needs-attention; they do not invent a commitment. Normal Arrangement ending belongs to M3E. [ADR 0012](../adr/0012-arrangement-activation-reservations-and-confirmations.md) governs activation manifests, Reservation history, confirmation evidence, and the M3D commitment core.

**Prerequisites:** M2 complete and shipped, including [ADR 0007](../adr/0007-departure-operational-root.md), [M2C](m2c-acceptance-and-hardening.md), and final M2 documentation; [ADR 0001](../adr/0001-money-and-currency.md), [ADR 0004](../adr/0004-human-readable-references.md), [ADR 0005](../adr/0005-agency-identity.md), [ADR 0006](../adr/0006-separate-identity-domains.md), [ADR 0008](../adr/0008-supplier-arrangement-version-topology.md), [ADR 0009](../adr/0009-supplier-contracting-and-service-provider-roles.md), [ADR 0010](../adr/0010-supplier-capacity-ledger-and-projection.md), [ADR 0011](../adr/0011-supplier-cost-definitions-and-forecast-evaluation.md), [ADR 0012](../adr/0012-arrangement-activation-reservations-and-confirmations.md), [MVP requirements](departure-desk-mvp.md), [commercial decision register](commercial-domain-decision-register.md), [current architecture](../architecture/current-state.md), [interface contract](../ui/interface-contract.md), and completed [M1 directories](m1-client-and-supplier-directories.md).

This parent contract is not implementation authority. Each M3 slice requires its own accepted implementation contract before domain code begins. Archived Phase 3B documents are historical input only; they do not govern M3.

When this parent is accepted, update the documentation index listed in [Acceptance documentation](#acceptance-documentation). That status flip does not authorize domain code. Shipped M2 and M2C plans keep their historical “do not invent an M3 plan” exclusions. `AGENTS.md` may then say this parent is accepted while still treating every M3 slice as unimplemented until that slice’s own accepted plan names the work.

## Goal

Establish the Supplier-side plan for a Departure before the Agency defines Client offers, confirms Client Trips, allocates supply to Clients, or posts Supplier payables.

M3 gives an Agency the ability to explain:

* what it has arranged with each contracting Supplier;
* which separately described services or deliverables the Arrangement contains;
* when each service is expected to occur;
* which Supplier Resources and measured capacity are available;
* what is blocked, allotted, guaranteed, released, or on request;
* which group- or occurrence-level requests and confirmations exist;
* which Supplier cost terms currently govern planning;
* which contractual commitments and deposit requirements exist without treating them as payables or payments;
* which Supplier deadlines are upcoming, due, overdue, completed, rescheduled, or waived; and
* which qualified forecast-cost and exposure measures are supported by the recorded facts.

M3 must represent both accepted scenarios from the Supplier side without cruise-, hotel-, motorcoach-, meal-, excursion-, or insurance-specific subclasses.

## Outcome boundary

M3 represents Supplier planning. It does not yet represent Client selling, Client fulfillment, or Supplier settlement.

| M3 answers | Deferred milestone answers |
| --- | --- |
| What did the Agency arrange or request from a Supplier? | What Package or standalone service will the Agency sell? (M4) |
| What service, occurrence, resource, and Supplier-side capacity exist? | Which Client Trip holds or consumes that capacity? (M5) |
| What Supplier terms, forecast cost, commitment, and deadline govern? | What does the Client owe or pay? (M4/M6A) |
| What group- or occurrence-level Supplier confirmation exists? | Which Traveler occupies a cabin, room, seat, or other resource? (M5) |
| What exposure is indicated before payable posting? | What Supplier Obligation, invoice, Payment, credit, commission settlement, or final cost exists? (M6B) |
| What Supplier planning fact changed? | What amendment, Cancellation Case, Communication, document, or closeout disposition follows? (M7/M8) |

The distinctions among operational truth, commercial truth, Supplier truth, and cash movement remain mandatory. No M3 event implies a Client sale, Client allocation, Supplier Obligation, Supplier Payment, or accounting loss.

Commercial register section 18.5 allows a Supplier confirmation to trigger deterministic commitments or Obligations. M3 implements a staged restriction of the Obligation half only: confirmation never posts a Supplier Obligation. Confirmation never silently opens a commitment. When the governing activated terms define a complete deterministic trigger, the confirmation command may explicitly and atomically open that commitment, provided its command contract, preview, audit, idempotency, and failure behavior name the effect. When confirmation does not provide every authoritative input required by a trigger, M3D records the confirmation and exposes a derived unresolved condition for later M3E needs-attention treatment; it does not invent a commitment or open a placeholder. Arrangement-confirmation triggers that cannot fully resolve during activation block activation.

## Aggregate boundary

`Departure` is the dated operational root accepted by ADR 0007. Every M3 record belongs to exactly one Agency and one Departure. No M3 record belongs to a Travel Program or derives ownership or authorization from an Office.

```mermaid
flowchart TD
    departure["Departure"]
    arrangement["Supplier Arrangement"]
    item["Arrangement Item"]
    occurrence["Service Occurrence"]
    resource["Supplier Resource"]
    pool["Capacity Pool"]

    departure --> arrangement
    arrangement --> item
    item --> occurrence
    item --> resource
    occurrence --> pool
    resource --> pool
```

Supporting records include Supplier Arrangement versions, Supplier Reservations, Supplier confirmations, Supplier cost terms and components, commitments, deposit requirements, Deadlines, capacity events, rebuildable capacity projections, and the first durable business-command idempotency-key family.

The diagram describes domain responsibility, not a required table count. Slice plans must define concrete persistence, same-Agency foreign keys, lifecycle columns, and immutable-history topology without weakening these meanings.

## Proposed slices

| Slice | Working outcome |
| --- | --- |
| **[M3A — Draft Arrangement structure](m3a-draft-arrangement-structure.md)** | Stable Arrangement identity, lifecycle catalog including `abandoned`, and draft-version topology; Items, Occurrences, Resources, and optional Arrangement contact; contracting Supplier and Service Provider rules; `view_departures` / `manage_departures` plus `force_inactivate_supplier_with_dependencies`; M3A did not add `override_supplier_planning_terms` (M3B introduces it); `ChangeSupplierStatus` ordinary blockers for introduced dependencies; draft UI that amends the Departure interface contract. Supplier Location attachment is deferred. No activation yet. Shipped. |
| **[M3B — Supplier capacity](m3b-supplier-capacity.md)** | Explicit Item capacity applicability; versioned Occurrence–Resource pair coverage and draft Capacity Pool definitions; stable Pool identity, inventory modes, measurement bases, immutable Supplier-side capacity events, scheduled effectiveness, rebuildable projections, evidence, Administrator override, reconciliation, concurrency, and recovery foundations. M3B exposes draft configuration only; effective supply and event controls still require later Arrangement activation in M3D. Shipped. |
| **[M3C — Cost terms and forecasts](m3c-cost-terms-and-forecasts.md)** | Exact-version Supplier cost sources, including Arrangement-wide and Item-scoped shapes; one editable estimate and contracted definition per source on the same draft Arrangement version; the first ADR 0001 monetary-table pattern; explicit charging Supplier; definition currency equal to Departure `operating_currency`; ordered cost components with economic role separate from calculation kind; monetary and quantity shortfall forms; explicit percentage bases; lightweight shared usage assumptions and optional anonymous occupancy profiles; deterministic derived forecasts with whole-stage precedence and complete explanations. Effective contracted terms still require later Arrangement activation. Shipped. |
| **[M3D.0 — Planning workspace compression](m3d0-planning-workspace-compression.md)** | Bounded M3A–M3C workflow remediation only: guided Item/cost setup, bulk capacity classification, calculation-specific forms, contextual assumptions, readiness review, and reorder mode. No activation, Reservation, confirmation, commitment, or effective-capacity domain records. Shipped. |
| **[M3D — Activation, Reservations, and confirmations](m3d-activation-reservations-confirmations.md)** | Arrangement activation and immutable activated versions after applicable structural, capacity, cost, and trigger completeness checks; unmanaged Items may activate without a Capacity Pool; first and successor activation only while the Departure is `active`; permanent Departure return-to-draft boundary; group/occurrence Supplier Reservations; immutable confirmation evidence; effective capacity and contracted planning; a narrow commitment-opening core used only when an Arrangement or Reservation confirmation activates a complete version-owned deterministic trigger with explicit `committed_supplier_id`; the minimum ordinary Supplier-inactivation blocker for every unresolved commitment that core can open; and Arrangement search without changing `SearchDepartures`. Does not end an activated Arrangement. Shipped. |
| **[M3D.7 — Activated definition immutability](m3d7-activated-definition-immutability.md)** | Post-ship remediation: freeze exact-version definition/configuration graphs in Rails and PostgreSQL once the Arrangement version leaves `draft`, and constrain version lifecycle transitions. Shipped. |
| **[M3D.8 — Activation and Reservation product quality](m3d8-activation-reservation-product-quality.md)** | Post-ship remediation: restore canonical form/alert anatomy, accessible command-error recovery, progressive Reservation disclosure, exclusive composers, bounded list/history loads, and table overflow treatment. Shipped. |
| **M3E — Commitments, deadlines, exposure, and Arrangement ending** | Complete Supplier Commitment workflow beyond M3D's confirmation-triggered opening core and minimal ordinary inactivation blocker; manual opening and explicit disposition, release, satisfaction, and cancellation; rules that determine when a commitment becomes terminal and ceases blocking; deposit requirements without payable/payment state; Deadline rule resolution and Staff workflow; qualified exposure measures; the first needs-attention catalog; and normal Arrangement ending after all capacity and commitment blockers are resolved. |
| **M3F — Acceptance and hardening** | Milestone-wide acceptance across shipped M3A–M3E: integrated Celebrity Beyond and Vineyard Tour Supplier-side scenario proof; cross-Agency isolation; cross-slice concurrency, query/index, accessibility, and responsive UI; regression; and final milestone documentation. Distinct from M3D.6 slice-local proof. |

Each slice requires an accepted implementation contract. A later slice may depend on a prior slice's shipped records, but an accepted parent contract does not authorize placeholder tables or premature later-slice behavior.

## Closed product decisions

The following decisions are locked in this parent contract. Slice plans may make them more specific but may not reopen them for implementation convenience.

### 1. Draft Departure planning

This decision amends the M2 parent clause that a draft Departure cannot own M3–M8 records because those milestones were not yet shipped. A draft Departure may own tentative Supplier Arrangement drafts and the editable planning structure needed to prepare them.

While the Departure remains draft:

* an Arrangement cannot activate;
* no Supplier confirmation may become effective;
* no managed Supplier capacity may be established;
* no commitment may open;
* no consequential Deadline may be resolved for operational use; and
* no M3 record may represent Supplier-confirmed or operationally available supply.

Draft Capacity Pool rows and draft cost-term rows are definitions only. They are not established supply and not effective contracted terms.

Draft planning is not Supplier truth. Draft Arrangement data remains visibly tentative.

### 2. Return-to-draft boundary

This decision is the M2 downstream-history catalog for M3. The first successful Supplier Arrangement activation permanently prevents `ReturnDepartureToDraft` for that Departure.

* Arrangement activation and the downstream-history check share an atomic lock/recheck boundary with `ReturnDepartureToDraft`, `MarkDepartureDeparted`, and other Departure lifecycle commands.
* Ending or otherwise terminating every Arrangement later does not restore eligibility to return the Departure to draft.
* Mere unactivated Arrangement drafts do not trigger this permanent boundary.
* Confirmation, capacity, commitment, and other consequential M3 history also block return, but they cannot validly precede Arrangement activation.

### 3. Arrangement activation prerequisite

First and successor Supplier Arrangement activation require `Departure.status == active`. A draft or departed Departure cannot activate an Arrangement.

A departed Departure may still record Supplier responses, corrections, Deadline completion, commitment disposition, and other explicitly permitted resolution history. Ordinary activation is not that path. If historical late entry is later required, a separate corrective command must be accepted in its own slice; M3 does not treat post-departure activation as ordinary planning.

A departed Departure may not create a new tentative Arrangement. Existing unactivated drafts allow dependency-reducing cleanup, correction necessary to resolve existing records, or abandonment. Activated Arrangement resolution work remains permitted as defined by later slices. `MarkDepartureDeparted` does not automatically abandon unfinished drafts. Late creation of previously undocumented Supplier work, if ever needed, is a separately defined historical-correction command—not ordinary forward-looking draft editing.

An Arrangement is not activated automatically when the Departure activates or when it is marked departed. Departure activation, marking departed, and Arrangement activation are distinct commands and audit facts.

The race with `MarkDepartureDeparted` has a closed outcome:

* Arrangement activation wins first: activation succeeds, then the Departure may become departed.
* Departed transition wins first: Arrangement activation fails with `invalid_state`.

### 4. Stable identity and immutable versions

Supplier Arrangement is the stable identity for one governing agreement or purchasing relationship. Activated commercial definitions are immutable versions.

* The initial Arrangement version is editable while draft.
* First activation freezes version 1.
* Revised terms create a successor draft version.
* Activating the successor supersedes the prior version for future planning and sales resolution.
* Earlier confirmations, evaluations, commitments, allocations introduced later, and commercial snapshots retain the exact version that governed them.
* A correction never edits an activated version in place.
* Changing the contracting Supplier or representing an independently governed agreement requires a new Supplier Arrangement rather than a new version.
* [ADR 0008](../adr/0008-supplier-arrangement-version-topology.md) locks the topology: Arrangement, Item, Occurrence, and Resource are stable identities; version-specific attributes live in per-version definition rows. Successor drafts copy the current activated graph into independent definition rows, reuse stable child identifiers for copied children, assign new identifiers to new children, and omit removed children. There is no live inheritance. Later defaults must not reinterpret consequential records that already referenced an exact version.

Operational events such as Supplier confirmations, reservation responses, capacity changes, Deadline rescheduling, and commitment disposition remain explicit history rather than edits to an old Arrangement version.

### 5. Supplier Reservations in M3

M3 includes group- and occurrence-level Supplier Reservations that may exist before a Client Trip.

* An Arrangement records the governing agreement or purchasing relationship.
* A Supplier Reservation records a specific group- or occurrence-level request or booking made under that Arrangement.
* One Supplier-facing booking must never be represented simultaneously as both an Arrangement and a Supplier Reservation.
* A Reservation may identify applicable Arrangement Items, Service Occurrences, Supplier Resources, or Capacity Pools as its scope requires.
* Client-specific Supplier bookings and their linkage to Client Trip Services are deferred to M5.
* A standalone Supplier Reservation without a governing M3 Arrangement is not introduced here. The MVP's standalone-reservation shape remains available to a later accepted slice for trip-specific or otherwise demonstrated demand.

### 6. Contracting Supplier and Service Provider

The Arrangement identifies one contracting Supplier. The organization or person actually performing a service may differ. [ADR 0009](../adr/0009-supplier-contracting-and-service-provider-roles.md) locks these role meanings.

* An Arrangement Item may identify a default Service Provider.
* A Service Occurrence may override the Item default.
* The effective provider is the Occurrence override when present, otherwise the Item default, otherwise the contracting Supplier.
* A provider default is a planning convenience, not authorization and not live historical inheritance.
* An unused Item default is not itself an ordinary Supplier-inactivation blocker. Ordinary inactivation uses the effective provider of a current or future `planned` Occurrence, as in closed decision 10.
* A consequential confirmation, commitment, later fulfillment record, or other snapshot preserves the effective provider it used.
* Changing a default affects future resolution only.
* The contracting Supplier and any selected Service Provider must be active same-Agency Supplier records when newly assigned or activated.
* Later inactivation does not invalidate retained history or prevent corrective and resolution commands.

M3 does not create a second Service Provider directory or restore Party. A distinct Service Provider is represented by a Supplier directory identity in its actual operational context.

### 7. Arrangement identification

M3 introduces no DepartureDesk-generated Arrangement reference or new `ReferenceSequence` namespace.

Staff identify and search an Arrangement through:

* its owning Departure and Departure reference;
* contracting Supplier;
* Arrangement name; and
* qualified Supplier-issued confirmations or group identifiers when available.

That Arrangement search is a separate Agency-scoped query in the Departure workspace. `SearchDepartures` remains unchanged: it does not search Clients, Suppliers, or external references.

Supplier confirmation numbers, group numbers, policy numbers, and similar identifiers are externally issued facts. They retain issuer, type, scope, provenance, and normalization appropriate to their domain. They are not rewritten into an internal generated namespace and never establish tenancy or authorization.

### 8. Deadline behavior

M3 introduces the operational portion of the general Deadline concept for Supplier planning.

M3 supports:

* a governing absolute or relative rule and its source;
* a resolved local date or local date/time and explicit IANA zone;
* the resolved instant used for comparison when a time exists;
* upcoming, due, overdue, completed, rescheduled, and waived presentation;
* a Departure-level Deadline list and needs-attention queue;
* explicit completion evidence;
* explicit rescheduling history; and
* authorized waiver with actor, time, and reason.

M3 does not send email, generate Communications, or materialize automatic reminder alerts. Those behaviors remain deferred. Upcoming and overdue state may be calculated from authoritative Deadline facts without a background job.

Completing or waiving a Deadline does not mark a deposit paid, post an Obligation, release capacity, cancel a Reservation, or fabricate Supplier confirmation.

### 9. Supplier-side capacity authority

Staff may record Supplier-side capacity changes supported by Supplier evidence or governing terms. An Administrator with `override_supplier_planning_terms` and a required reason is necessary when the Agency intentionally departs from recorded terms or normally required evidence.

* Ordinary capacity establishment, increase, release, reinstatement, withdrawal, and Supplier-discrepancy correction require structured Supplier evidence: evidence kind, evidence date, and reference note. An external reference is optional. File upload is deferred, but evidence records must be attachment-ready without changing event identity or meaning later.
* A Supplier-confirmed exception is Supplier truth, not an Administrator override, even when received after an original cutoff.
* An Administrator with `override_supplier_planning_terms` may record any otherwise valid capacity event without ordinary Supplier evidence only with a required reason and visible override marking.
* Override never bypasses Agency ownership, Arrangement activation, Pool eligibility, measurement basis, nonnegative-timeline validation, reinstatement lineage, optimistic locking, idempotency, or immutable history.
* Negative quantities are impossible and never an overrideable state.
* An override cannot fabricate Supplier confirmation or conceal that managed quantity exceeds evidenced Supplier supply.
* Client over-capacity confirmation remains an M5 concern.
* Every override remains visible in needs-attention until resolved or explicitly acknowledged under the M3E catalog.

### 10. Supplier inactivation dependencies

Ordinary Supplier inactivation continues to use `ChangeSupplierStatus` and `manage_supplier_directory`. It is blocked by current nonterminal M3 dependencies, including as applicable:

* draft or active Arrangements using the Supplier as contractor;
* planned, requested, or confirmed nonterminal Supplier Reservations;
* current or future `planned` Service Occurrences using the Supplier as effective Service Provider; and
* unresolved open commitments.

Effective provider is computed from the exact Arrangement version: Occurrence override, else Item default, else contracting Supplier. An Item default blocks ordinary inactivation only when it resolves as the effective provider for a current or future `planned` Occurrence. An unused Item default with no applicable Occurrence does not block.

Terminal and historical references do not block inactivation. These include ended Arrangements, abandoned Arrangements, withdrawn/declined/cancelled Reservations, `cancelled` Occurrences, `planned` Occurrences whose service window has already ended, released/superseded/cancelled commitments, superseded terms, and a Supplier retained only as a historical confirmation issuer or provider. A past service window does not assign fulfillment or `completed` status.

An Administrator with `force_inactivate_supplier_with_dependencies` may force inactivation with a required reason when reality requires it, such as a Supplier ceasing operations unexpectedly. Force is an extension of `ChangeSupplierStatus`, not a second Supplier lifecycle path.

Forced inactivation:

* preserves every unresolved Arrangement, Reservation, Occurrence, capacity, commitment, confirmation, and Deadline;
* creates needs-attention for the affected current records;
* does not cascade cancellation, capacity release, commitment release, provider replacement, or Deadline completion;
* prevents the inactive Supplier from being selected for new work; and
* continues to permit explicit corrective or dependency-reducing work on existing records, never selection of the inactive Supplier for new work.

While a Supplier is inactive after force, recovery permits only:

* clearing an Arrangement contact;
* removing or replacing an inactive provider assignment;
* removing unpublished dependent draft structure; and
* abandoning an unactivated draft.

Because the contracting Supplier is immutable, an Arrangement whose contractor becomes inactive may be cleaned up or abandoned but cannot be moved to another contractor.

Capacity-specific recovery after force (M3B):

* A Capacity Pool snapshots one immutable supplying Supplier, which must equal the exact-version effective provider when the Pool is created and activated.
* Ordinary Supplier inactivation is already blocked by the current/future effective-provider dependency. M3B must not add an independent blocker for an unused draft Pool beyond that rule.
* After forced inactivation, Staff may record only dependency-reducing capacity recovery: release, withdrawal, downward correction, reconciliation, and projection repair.
* Establishment, increase, reinstatement, and new Pool creation for the inactive Supplier are prohibited.
* An Administrator may record an upward compensating correction only to preserve historical truth, using `override_supplier_planning_terms`, a required reason, and visible override marking.
* Already-recorded future events remain immutable and become effective as scheduled. Countermanding them requires an evidenced compensating event.
* Forced inactivation never creates, cancels, releases, or edits a capacity event automatically.

The command must lock and recheck dependencies so concurrent Arrangement activation, Reservation creation, provider assignment, or commitment opening cannot evade the inactivation decision. Establishment commands and inactivation share the [canonical lock order](#concurrency-and-lock-order-requirements), with affected Suppliers locked before affected Departures and Arrangements.

### 11. Occurrence dates and Departure schedule

A Service Occurrence may start before `Departure.starts_on` or end after `Departure.ends_on`. Pre-stay and post-stay hotel nights, early transfers, and similar Supplier performances are valid without stretching the Departure operating dates.

Occurrence creation stores a recognized IANA zone. The form may default that zone by copying `Departure.time_zone`. If the Departure zone is blank, creation fails `invalid` unless staff submit an explicit recognized IANA zone. A copied zone becomes an independent stored fact.

`UpdateDeparture` and `CorrectDepartureSchedule` must not silently rewrite, move, complete, or reinterpret existing Occurrences or resolved Deadlines. Changing the Departure zone or a copied default never reinterprets a stored Occurrence or Deadline. Schedule correction does not require Occurrences to be brought inside the new Departure window.

The implementation slice must distinguish commercial schedule amendments from operational updates and preserve the before/after evidence for consequential Occurrence changes.

### 12. Currency dependency catalog

The Departure retains one explicit `operating_currency`. Every M3C cost definition stores an explicit uppercase currency that must equal that operating currency. Estimate and contracted stages for one source use the same currency. Agency or Departure defaults may seed entry but never reinterpret an existing definition.

The first retained currency-bearing cost definition freezes ordinary `UpdateDeparture` / `CorrectDepartureCurrency` changes under the existing currency-bearing M3 fact rule. Those commands never rewrite, relabel, or convert stored cost amounts.

M3 performs no FX conversion and persists no functional-currency translation. Foreign-currency Supplier cost definitions are out of scope for M3C.

Shipped command mapping:

| Departure status | Currency mutation | M3 rule |
| --- | --- | --- |
| `draft` | `UpdateDeparture` | Blocked once any currency-bearing M3 fact exists, including a draft definition that stores a currency or amount. Staff must explicitly remove or void those draft definitions first, then change currency. |
| `active` | `UpdateDeparture` | Blocked once any currency-bearing M3 fact exists, including draft definitions. |
| `departed` | `CorrectDepartureCurrency` | Blocked by every currency-bearing M3 fact, including draft, activated, and historical rows. |

Activated or historical currency-bearing facts cannot be removed merely to unlock currency. Returning to draft does not unlock currency after it has been frozen. In practice the return-to-draft latch from first Arrangement activation already prevents that path once activated terms exist.

### 13. Arrangement and version lifecycle

M3A must persist these closed catalogs. Slice plans may add display labels but may not invent extra meaning-changing states.

**Supplier Arrangement**

| Status | Contract |
| --- | --- |
| `draft` | Never successfully activated. Editable where state gates permit. Does not block `ReturnDepartureToDraft`. |
| `active` | Has a current governing activated version. First transition into this status permanently blocks return to draft. |
| `ended` | Ordinary post-activation terminal. No longer available for new planning or sales use. History retained. Does not restore return-to-draft. Records an explicit termination reason. Ending does not automatically release capacity, release commitments, cancel Reservations, complete Deadlines, or create Client or Supplier financial consequences. |
| `abandoned` | Never-activated draft intentionally discarded. Retained read-only. Cannot later activate or be restored. Restarting requires a new Arrangement. Records an explicit abandonment reason. Does not restore return-to-draft because it never activated. |

`ended` and `abandoned` are both terminal for ordinary Supplier-inactivation blockers. `abandoned` applies only to a never-activated Arrangement. M3 does not add a `cancelled` Arrangement status. Supplier cancellation does not change the Arrangement to `cancelled`; entire-agreement Cancellation Cases remain M7. Normal Arrangement ending (`EndSupplierArrangement`) is owned by M3E after capacity and commitment blockers can be enforced together; M3D does not end an activated Arrangement.

**Arrangement version**

| Status | Contract |
| --- | --- |
| `draft` | Editable initial or successor definition. |
| `activated` | Immutable. At most one activated version is the current governing version of an `active` Arrangement. |
| `superseded` | Previously activated; retained for provenance. |
| `abandoned` | Retained draft intentionally discarded. |

Initial abandonment changes both the Arrangement and version 1 from `draft` to `abandoned`. Successor abandonment, when later slices introduce successor drafts, changes only that version; the Arrangement continues under its prior activated version. Abandoned version numbers are never reused.

**Service Occurrence**, for inactivation and planning:

| Status | Contract |
| --- | --- |
| `planned` | Nonterminal performance. Blocks ordinary inactivation when the Supplier is the effective provider and the service window has not ended. A past service window is a historical provider reference only; it does not prove delivery and does not become `completed`. |
| `cancelled` | Terminal. Does not block ordinary inactivation. |

M3 does not persist Occurrence fulfillment or `completed`. Actual completion belongs to M5 or M7.

Reservation states remain the baseline in [Supplier Reservations and confirmations](#supplier-reservations-and-confirmations). Commitment terminals are released, superseded, or cancelled.

### 14. Activation completeness and capacity applicability

Every versioned Item definition explicitly declares `managed` or `unmanaged` capacity applicability before Arrangement activation. An undecided draft value is permitted only while the version remains editable.

* An `unmanaged` Item has no Capacity Pools or Occurrence–Resource capacity-pair classifications. Insurance and similar informational or non-capacity services may activate without fabricated supply.
* A `managed` Item requires at least one non-cancelled Occurrence, at least one Resource, and an explicit classification for every non-cancelled Occurrence–Resource pair in that version.
* Each pair is `pooled` or `not_applicable`. `pooled` requires at least one Pool definition; `not_applicable` requires none. No zero-quantity placeholder Pool represents absence.
* Multiple distinctly labeled Pools may exist for the same pair when they represent separate Supplier supply tranches.
* Draft Pool definitions and proposed opening quantities are tentative only. Established managed supply begins only when Arrangement activation writes the first immutable establishment event.
* Cost-term completeness remains governed by M3C/M3D and is independent from capacity applicability.

### 15. Permission keys

Ordinary Supplier planning lives in the Departure workspace and reuses the shipped Departure pair:

* `view_departures` — view Supplier planning;
* `manage_departures` — create and edit drafts and perform ordinary evidence-backed M3 transitions.

M3A adds `force_inactivate_supplier_with_dependencies` — force `ChangeSupplierStatus` to inactive over current M3 dependencies, with a required reason.

M3B adds `override_supplier_planning_terms` as an Administrator-only permission with its first capacity-evidence override command. It authorizes only the explicit override paths named by an accepted slice, always requires a reason, and never substitutes a role-name check. It does not bypass structural, tenancy, lifecycle, quantity, locking, idempotency, or history invariants.

M3 does not add `view_supplier_planning`, `manage_supplier_planning`, or a parallel planning navigation permission. Assignment as responsible AgencyUser, Arrangement contact, or Service Provider does not grant authority.

### 16. First monetary persistence and rates

M3C ships the first application monetary tables and establishes the reusable ADR 0001 pattern:

* `bigint` `*_minor_units` plus an explicit uppercase currency on the owning definition, equal to the Departure operating currency;
* `monetize` with `with_model_currency` where a table exposes a Money value;
* explicit migrations, not `money-rails` migration helpers;
* `Money::Currency.find` and strict parsing at command boundaries;
* no floating-point columns for amounts, rates that produce money, quantities, or allocations;
* `numeric(20,10)` fractional rates, where `1.0` means 100%;
* nonnegative stored magnitudes with economic direction represented explicitly;
* component-level rounding to the definition currency minor unit before later components consume the result; and
* deterministic derived forecasts that persist no calculated forecast total or component result.

The authoritative definition persists its currency, amounts or rates, explicit base-component links, calculation order, quantity basis, and rounding policy. The forecast explanation returns each rounded component minor-unit result. Later posted financial source lines must persist their final rounded results as required by ADR 0001 and the commercial register.

### 17. Optimistic locking and idempotency keys

User-driven M3 commands use the shipped Departure pattern: pessimistic row locks in canonical order, then a submitted `lock_version` on the mutable aggregate, with stale submissions returning `conflict`. Lifecycle replay and already-applied no-ops follow the existing Departure command rules for when `lock_version` is compared.

Arrangement identity remains lockable because name, contact, and status are mutable. Child create, remove, and reorder submit and bump the Arrangement-version `lock_version`. Editing an existing child definition uses that definition’s `lock_version`.

`ArrangementItem` and `SupplierResource` identity rows hold immutable ownership only and do not need their own optimistic locks. `ServiceOccurrence` identity rows carry the current operational lifecycle (`planned` or `cancelled`) and therefore require `lock_version`. Occurrence commercial and schedule attributes remain on versioned definition rows without a lifecycle status column. Later cancellation updates the stable Occurrence status projection and records command evidence; it must not mutate an activated definition or require a commercial successor version merely to cancel.

M3 introduces the first durable business-command idempotency-key family. M3A ships that family for Arrangement and child create commands. Retry of the same command at the declared business-command scope must not create a second Arrangement, version, child, confirmation, capacity event, commitment, Deadline mutation, or success audit. Same key plus same payload returns the original result without a second success audit. Same key plus different payload returns `conflict`. Idempotency identity is a domain constraint, not JSON inside `AuditEvent#details`.

### 18. Confirmation does not silently open commitments

Confirming an Arrangement or Reservation records Supplier evidence. Confirmation never silently opens a commitment. When the governing activated terms define a complete deterministic trigger, the confirmation command may explicitly and atomically open that commitment, provided its command contract, preview, audit, idempotency, and failure behavior name that effect. Every such trigger carries an explicit `committed_supplier_id` that is copied onto the immutable opening. When confirmation does not provide every authoritative input required by a trigger, M3D records the confirmation and exposes a derived unresolved condition for later M3E needs-attention treatment; it does not invent a commitment. Arrangement-confirmation triggers that cannot fully resolve during activation block activation. Confirmation never posts a Supplier Obligation.

## Domain concepts

| Concept | Contract |
| --- | --- |
| Supplier Arrangement | Stable governing agreement or planning relationship between the Agency and one contracting Supplier for one Departure. |
| Arrangement version | Immutable activated commercial definition; successor versions govern future resolution without rewriting prior use. |
| Arrangement Item | Separately described Supplier-side service, deliverable, or commercial line within an Arrangement version. It is not a generic substitute for Occurrence, Resource, cost component, or Client Trip Service. |
| Service Occurrence | One dated or otherwise bounded performance of an Arrangement Item. A capacity-bearing Occurrence has an explicit date range. Dates may fall outside the Departure operating window. |
| Supplier Resource | The supplied unit or category relevant to capacity or later placement, such as an O1 cabin category, standard room type, or coach. |
| Capacity Pool | Stable Supplier supply tranche for one Item, Service Occurrence, Supplier Resource, and supplying Supplier, with inventory mode and whole-number measurement basis. `unmanaged` is Item capacity applicability, not a Pool mode. Holds and Allocations consume capacity from M5; they are not M3 records. |
| Supplier Reservation | Specific group- or occurrence-level request or booking made with a Supplier under an M3 Arrangement. |
| Supplier confirmation | Qualified evidence that a Supplier acknowledged an Arrangement or Reservation; it may include an external identifier or a documented confirmed-without-identifier path. |
| Arrangement contact | Optional same-Agency `SupplierContact` used as a communication pointer for the Arrangement. It grants no authority. Consequential events snapshot the contact facts they need. |
| Supplier cost source | Shipped M3C vocabulary. Exact-version economic identity for one Supplier cost, Arrangement-wide or Item-scoped, with an explicit charging Supplier. |
| Supplier cost definition | Shipped M3C vocabulary. Editable estimate or contracted term definition (`working` / `forecast_ready`) for one source. Definition currency equals Departure `operating_currency`. |
| Cost component | Shipped M3C vocabulary. Typed component with economic role separate from calculation kind; explicit quantity and percentage-base semantics. Occupancy-position facts are Supplier cost facts, not Traveler occupancy records. |
| Commitment | Explicit contractual exposure that may precede and must not be confused with a Supplier Obligation. M3D may open a commitment only as an atomic confirmation consequence under a complete activated trigger with an explicit committed Supplier snapshot. M3E owns manual opening, disposition, and terminal rules. |
| Committed Supplier | Explicit Supplier snapshot on a commitment trigger and opening (`committed_supplier_id`). Eligible as the Arrangement contractor, an applicable exact-version effective Service Provider, or the charging Supplier of the contracted monetary authority. Not inferred later from mutable roles. |
| Deposit requirement | Supplier requirement stating amount or calculation rule, due rule, refundability, final-balance treatment, trigger, and provenance; it is not a Payment. |
| Deadline | Resolved operational due fact linked to its governing source and preserving completion, rescheduling, or waiver history. |
| Exposure | Qualified planning risk derived from recorded terms and commitments; it is not a posted accounting loss. |
| Needs-attention | Staff queue of current Supplier-planning conditions. M3E owns the first catalog. Conditions may be derived from authoritative records; acknowledgment of an override or similar requires a persisted acknowledgment fact. It is not a Cancellation Case or Communication. |

## Arrangement structure

### Flat Arrangements

M3 does not introduce parent/child Supplier Arrangements.

Use one Arrangement for one independently governed Supplier agreement or purchasing relationship, with multiple Arrangement Items inside it. Create a separate Arrangement when the contracting Supplier, agreement, confirmation context, or governing terms are independently controlled.

An Arrangement Item, Supplier Reservation, or separate Arrangement must not represent the same Supplier booking twice.

### Arrangement Items

An Item defines what the Supplier is expected to provide. It may carry descriptive and commercial categorization, a default Service Provider, and links to its versioned terms.

M3 does not decide whether an Item is included, optional, or a required choice for a Client. M4 maps Supplier-side Items into Packages or standalone sellable services and owns Client-facing inclusion and choice rules.

No service-type STI is permitted. Cruise, hotel, transfer, coach, meal, tasting, excursion, insurance, specialty dining, and miscellaneous services compose from common Item, Occurrence, Resource, capacity, and term capabilities. A later service-specific extension requires a fact unique to that service and an accepted slice.

M3A includes optional Arrangement contact. The contact must be a same-Agency `SupplierContact` of the contracting Supplier when assigned. Inactive historical contacts remain displayable. Assignment grants no authority.

M3 defers attaching a `SupplierLocation` to an Item or Occurrence. Neither accepted scenario currently requires that pointer for Supplier-side planning. A later accepted slice may add it as planning metadata only; it would not own the M3 record, authorize, or supply live timezone inheritance.

### Service Occurrences

A Service Occurrence describes when an Item is performed.

* An all-day or multi-day Occurrence stores local date values rather than artificial midnight timestamps.
* A timed Occurrence stores local time and an explicit IANA zone, defaulted by copying the Departure zone unless explicitly overridden.
* If `Departure.time_zone` is blank, Occurrence creation fails `invalid` unless staff submit an explicit recognized IANA zone.
* A spanning engagement with fixed capacity, such as a cruise sailing, uses one Occurrence spanning the engagement.
* Nightly-varying capacity, such as a hotel block, uses one Occurrence per night.
* Segment-specific services, such as transfers, use distinct Occurrences where their schedule, provider, confirmation, capacity, or terms differ.
* Dates may precede or follow the Departure operating dates.
* Changing a default zone later never reinterprets an existing resolved Occurrence.

### Supplier Resources

A Supplier Resource describes the unit or category whose capacity is measured or into which later fulfillment may be placed. It does not store a mutable generic `available` count.

Examples include a cabin category, room type, coach, vehicle class, or another named resource. Individual Traveler placement, named-room assignment, cabin assignment, seat assignment, and occupancy are deferred to M5.

A Resource with managed capacity participates through a Capacity Pool scoped to a Service Occurrence. A non-capacity service need not fabricate a Resource or Capacity Pool.

## Supplier Reservations and confirmations

### Reservation lifecycle baseline

M3 slice plans must implement at least these meanings:

| State or transition | Contract |
| --- | --- |
| Planned | Internal intent; no claim that the Supplier received a request. |
| Requested | Request data and Supplier communication context recorded. |
| Confirmed | Supplier confirmation evidence recorded for the scope. May atomically open a commitment only under closed decision 18. Confirmed quantity may differ from requested quantity. |
| Declined | Supplier response and reason retained; creates needs-attention where the service is still required. |
| Counterproposed | Supplier counterproposal recorded; does not confirm the scope, change capacity, or open a commitment. Accepting requires an explicit Reservation revision and later confirmation. |
| Withdrawn/cancelled | Explicit history; no silent deletion or implied financial consequence. |
| Changed | Later Supplier response or amendment preserved as a new event/version rather than rewriting the prior confirmation. |

Confirming a Reservation requires either:

1. effective Supplier confirmation evidence with issuer, context, actor, time, and optional external identifier; or
2. an explicit confirmed-without-identifier reason with actor, time, Supplier/channel provenance, and optional safe evidence reference.

A confirmation identifier is not assumed globally unique. Uniqueness and duplicate warnings must use the applicable Supplier, issuer, identifier type, and context. Confirmation never fabricates a Client sale or Supplier Obligation.

## Supplier capacity

### Capacity distinctions

M3 preserves the accepted distinctions:

| Concept | Meaning | Must not imply |
| --- | --- | --- |
| Capacity | Maximum supported quantity in a declared basis | Held, sold, guaranteed, or paid |
| Block | Capacity held under Supplier release or guarantee terms | Every blocked unit is guaranteed |
| Allotment | Inventory made available by a Supplier | A payable commitment |
| On request | Availability requires Supplier response | Current numeric availability |
| Guarantee | Quantity or amount payable regardless of use | Sold or assigned units |
| Allocation | Internal confirmed demand against a pool | That Allocation is implemented in M3; Allocations begin in M5 |
| Exposure | Qualified planning risk | Posted loss or payable balance |

### Capacity applicability and Pool contract

Capacity applicability belongs to the exact Item definition and is `managed` or `unmanaged`; an undecided value is allowed only in an editable draft. `unmanaged` is not a Pool inventory mode.

Every Pool identifies one stable supply tranche for exactly one Item, Service Occurrence, Supplier Resource, and immutable supplying Supplier. Its semantic identity also fixes inventory mode, measurement basis, and governing IANA zone after first activation. A semantic change requires a new Pool identity. Pool creation copies the governing IANA zone from the exact-version Service Occurrence definition; there is no separate staff-selectable Pool zone and no Departure fallback at Pool creation.

Supported Pool inventory modes are:

* `block`;
* `allotment`;
* `on_request`; and
* `externally_managed`.

`block` and `allotment` use the same numeric ledger mechanics but retain different Supplier-facing meanings. Neither implies a guarantee, cost, commitment, confirmation, or cancellation consequence.

Only `block` and `allotment` carry authoritative numeric capacity. `on_request` and `externally_managed` are explicit nonnumeric planning definitions and never store zero, unlimited, estimated, or informational quantity as managed capacity. They still carry a measurement basis and a presentation-only unit label so staff can describe what kind of supply is requested or managed externally; the label does not imply that DepartureDesk knows the quantity.

M3 capacity quantities are whole numbers only. Measurement bases in M3B are exactly `resource_units` and `traveler_positions`. Each Pool has one basis. M3 does not convert between them or infer one from occupancy, maximum capacity, or a threshold ratio. No later M3 slice may add fractional precision or another measurement basis without amending this parent and [ADR 0010](../adr/0010-supplier-capacity-ledger-and-projection.md).

Every managed Capacity Pool also declares owning Agency and Departure, Arrangement and governing version provenance, governing Supplier evidence or term source where applicable, and a current stored projection derived from immutable capacity history for numeric modes.

Draft pool *definitions* may exist on a draft Arrangement. Establish-evidenced-supply and later quantity events that create managed supply are forbidden until the Arrangement is activated.

### Capacity history, scheduled effectiveness, and projection

Supplier-side numeric capacity changes are immutable events:

* establish evidenced supply;
* increase;
* Supplier-approved release;
* Supplier-approved reinstatement;
* Supplier withdrawal;
* upward compensating correction; and
* downward compensating correction.

Establishment records the opening total once. Every later event records a positive whole-number magnitude; event type determines direction. A reinstatement references one prior release and cannot exceed that release's unreinstated quantity. Restoring withdrawn supply is an increase, not a reinstatement.

Events may have past, current, or future local effective dates. A future event becomes effective at the end of its local effective date in the Pool's stored IANA zone. End of day resolves as the start of the following local calendar date, not `23:59:59`. Events on the same Pool and effective date have an explicit immutable sequence. Complete timeline replay must remain nonnegative after every event.

An already-recorded future event becomes effective without a second business event. An idempotent scheduled refresh updates due stored projections, and every read or mutation performs locked catch-up before relying on a projection. Refresh writes no capacity event and no business audit event. This does not authorize a Deadline, date rule, or background job to fabricate an event.

The current position is a rebuildable stored projection called **Current Supplier capacity**. `available`, `remaining`, `held`, `allocated`, and `sold` remain unavailable until later demand records exist. Projection drift is repaired from events. A real Supplier-versus-ledger difference requires a compensating correction event.

Every event retains actor, business-effective date, application instant, recorded time, same-date sequence, positive quantity, basis, Supplier evidence or Administrator override, immutable supplying Supplier, exact governing Arrangement version, reason where required, and durable idempotency identity.

Capacity events do not represent Client Holds, Allocations, occupancy, fulfillment, commitments, Supplier Obligations, or Payments. None of those facts silently changes capacity, and capacity changes none of them. Supplier Reservations may reference Capacity Pools but do not silently consume them. Any capacity consequence of a Reservation command must be an explicit capacity event. Capacity changes do not silently create, revise, satisfy, or release commitments. Commitment changes do not silently change capacity.

### Capacity lifecycle consequences

* A stable Pool may continue across successor Arrangement versions through independent per-version definitions.
* A future event retains the exact version that governed it when recorded and applies to the carried-forward stable Pool.
* A successor cannot omit a numeric Pool unless its effective quantity is zero, it has no pending event, and reconciliation is clean.
* A cancelled Occurrence may retain unresolved capacity. Cancellation creates no capacity event and the balance must still be resolved explicitly.
* An elapsed Occurrence does not zero or retire capacity automatically.
* Every numeric Pool must reach zero before its Arrangement can end or the Departure can eventually close out. Administrator override supplies evidence authority; it is not a bypass around the zero requirement.

### Concurrency

Every capacity mutation:

* locks the Agency and rechecks active status and authority;
* loads the Departure through the Agency;
* follows the canonical lock order with affected Suppliers before Departures and Arrangements;
* locks the applicable Capacity Pool in canonical order;
* rechecks Arrangement version, Occurrence, Resource, evidence, and current projection;
* validates nonnegative full-timeline replay;
* applies one idempotent event and projection update atomically; and
* rejects impossible negative or inconsistent states.

The M3B slice must publish the complete lock order, transition matrix, idempotency behavior, reconciliation command, and projection-rebuild proof before implementation.

## Supplier cost terms and forecasts

[M3C](m3c-cost-terms-and-forecasts.md) and [ADR 0011](../adr/0011-supplier-cost-definitions-and-forecast-evaluation.md) are the shipped contracts for this section. Summary:

### Term stages

Supplier cost terms and commitments are separate authorities. `committed` is not a cost-term stage.

| Concern | Estimate definition | Contracted definition | Commitment | Supplier Obligation |
| --- | --- | --- | --- | --- |
| Meaning | Agency planning assumption | Staff-attested transcription of Supplier-agreed terms | Contractual exposure | Posted amount owed |
| M3 | Yes (M3C draft) | Yes (M3C draft) | Yes (later) | No |
| Mutable after activation | No; supersede via successor | No; supersede via successor | Explicit disposition only | Deferred to M6B |

One exact-version `SupplierCostSource` carries at most one editable `estimate` and one editable `contracted` definition on the same draft Arrangement version. Forecast-ready contracted terms supersede the estimate for forecasting without mutating the estimate. Definition readiness and contracted Staff attestation are one command boundary; attestation is a planning claim, not confirmation or effective contracted terms. Effective contracted terms begin at Arrangement activation (M3D).

### Composable components

M3 models Supplier cost as typed components rather than one formula per service type. Economic role is separate from calculation kind. Required capabilities include:

* Arrangement-wide and Item-scoped applicability (Occurrence/Resource narrowing when Item-scoped);
* fixed amount;
* unit rates on closed quantity bases (resource, person, night, occupancy-position, single-occupancy);
* monetary and quantity minimum shortfalls as explicit components;
* tax, fee, discount, and expected commission;
* percentage applied only to earlier components in the same definition;
* pass-through classification where applicable; and
* explicit zero-cost mode (not an empty or missing definition).

Every percentage component identifies its base components, inclusive/additive treatment, calculation order, `numeric(20,10)` rate, and rounding boundary. Every component result is rounded before later use. Expected commission never reduces forecast Supplier cost; commission settlement method and expected remittance are deferred. No generic expression language or service-specific pricing subclasses.

### Planning quantities

Per-person, per-resource, per-night, minimum, and occupancy calculations use explicit planning assumptions or anonymous occupancy profiles shared by exact Item context. Assumptions are required only when a formula needs them. M3 must not imply that Client Trips, Travelers, Holds, or Allocations exist. Participant categories are Item-scoped labels only in M3C.

Threshold-triggered capacity may calculate the number of resource units required from a planning quantity, such as one vehicle per 15 Traveler positions. Crossing a threshold does not automatically create a Resource, Service Occurrence, Reservation, capacity, commitment, or Supplier Obligation. Staff perform and confirm the resulting Supplier planning action.

### Economic-source identity and forecast precedence

A cost source is Arrangement-wide or Item-scoped within one exact Arrangement version, with an explicit charging Supplier. Projected Supplier cost selects one complete forecast-ready stage per source (contracted when ready, else estimate). Stages are never merged or added. Forecasts are derived, single-currency, and may show a labeled known subtotal when incomplete. Missing facts are never zero. No forecast result is a commitment, Obligation, Payment, earned commission, or accounting fact.

M3C cost completeness proves Item-level coverage and completeness of every declared cost source. It cannot infer omitted Occurrence, Resource, or Arrangement-wide sources. M3D activation must present the complete source list for Staff coverage attestation.

M3 reporting must explain selected stage, governing version and source, charging Supplier, quantities, components and bases, rounding, and why an earlier stage was not used.

## Commitments, deposit requirements, and exposure

### Commitments

A commitment is an explicit contractual exposure governed by recorded Supplier terms. It is not capacity, a Deadline, an Obligation, an invoice, or a Payment.

Commitments preserve:

* owning Agency and Departure;
* Arrangement and exact governing version;
* applicable Item, Reservation, Occurrence, Resource, Capacity Pool, or economic source;
* type and description;
* quantity and/or amount basis;
* trigger and effective facts;
* currency and calculation provenance;
* opening evidence;
* lifecycle history; and
* actor and idempotency evidence.

Opening, superseding, releasing, satisfying, or cancelling a commitment is explicit. No capacity event silently changes commitment state. Confirmation may open a commitment only under closed decision 18. M6B later defines when a deterministic commitment milestone posts a Supplier Obligation.

Every minimum-billed-quantity term records whether the Arrangement may be cancelled without cost below the minimum or must operate/pay the minimum regardless. M3 records and reports that rule; it does not execute a future Cancellation Case.

### Deposit requirements

A Supplier deposit in M3 is a requirement, not cash movement.

It records the required amount or calculation rule, explicit percentage base where applicable, due rule, currency, refundability, application to final balance, trigger/commitment condition, and Supplier-term provenance.

It has no `paid`, `refunded`, cash-account, Receipt, Supplier Payment, or settlement state. Deadline completion or waiver does not mark it paid.

### Qualified exposure

M3 never displays one unqualified `Exposure` total. Supported measures must be labeled and explainable, including as applicable:

* forecast Supplier cost;
* gross contractual commitment;
* gross guarantee or minimum exposure;
* expected Supplier cost;
* expected net cost after separately identified expected commission; and
* current unallocated guarantee exposure, explicitly labeled as pre-Client planning until M5 introduces Allocations.

Expected commission is not earned commission. Exposure is not a Supplier balance or posted accounting loss.

Agency cash at risk is unavailable in M3 because Supplier Payments and refunds do not exist. It must render as unavailable or not applicable, never as a fabricated zero.

### Needs-attention catalog

M3E publishes the first needs-attention catalog. It includes at least:

* Administrator term or evidence overrides until resolved or explicitly acknowledged;
* current records affected by forced Supplier inactivation;
* declined Reservations where the service is still required;
* confirmations that leave a derived unresolved commitment-trigger condition for Staff attention; and
* inactive Supplier remaining on current nonterminal planning records.

Derived conditions query authoritative M3 facts. Acknowledgment, where required, is a persisted fact with actor, time, and reason. M3 must not create Cancellation Case, Communication, or reminder rows to represent these conditions.

## Currency and money

The Departure retains one operating currency. Every Supplier cost planning definition stores that currency explicitly under ADRs 0001 and 0011. Closed decision 12 is the dependency catalog for `UpdateDeparture` and `CorrectDepartureCurrency`.

* All components within a definition inherit its currency.
* Estimate and contracted definitions for one source use the same currency.
* Agency or Departure defaults may seed entry but never interpret an already stored amount.
* M3 performs no FX conversion and persists no functional-currency translation.
* M3C does not authorize foreign-currency Supplier cost definitions or posted Supplier accounting in another currency.
* M3C established the reusable `money-rails` model pattern with the first monetary table.
* `UpdateDeparture` and `CorrectDepartureCurrency` never clear, void, relabel, or convert M3 monetary rows in order to change currency.

## Deadline contract

A Deadline references the commercial requirement, clause, Reservation, commitment, or other accepted source that governs it. The same due fact must not be independently authoritative on both source and Deadline without an explicit source relationship.

* A relative rule preserves its inputs.
* Resolution records the local due value, governing zone, resolved instant where applicable, and source version.
* A date-only Supplier cutoff resolves to the end of that local calendar day unless Supplier terms state another cutoff.
* Comparison uses the resolved instant while UI displays the governing local date, time, and zone.
* Changing the Departure zone, schedule, or a default does not reinterpret a resolved Deadline.
* Rescheduling creates history and preserves the prior resolution.
* Completion records evidence; it is not inferred from another record's status.
* Waiver requires the authority declared by the M3E slice and always records actor, reason, and time.

M3 date automation must not post money, create a capacity event, cancel a service, complete a Deadline, change a commitment, or fabricate fulfillment. It may classify dates and idempotently refresh a rebuildable projection when a previously recorded, evidenced future event reaches its effective boundary. A Deadline or date rule never fabricates that event. Name-list, option, release, and deposit due facts are Deadlines; M3 does not generate the underlying documents.

## Departure integration

### Lifecycle

* Draft Departure: may contain tentative Arrangement drafts only under closed decision 1. This amends the M2 statement that a draft Departure cannot own M3 records.
* Active Departure: may create and edit tentative Arrangements, activate Arrangements, and perform ordinary M3 planning.
* Departed Departure: remains available for recording Supplier responses, corrections, Deadline completion, commitment disposition, and other explicitly permitted resolution work. It cannot create a new tentative Arrangement or activate an Arrangement or successor version. Existing unactivated drafts allow dependency-reducing cleanup, correction necessary to resolve existing records, or abandonment. `MarkDepartureDeparted` does not automatically abandon unfinished drafts. M3 does not infer that every service was fulfilled merely because the Departure departed.
* Closed Departure does not yet exist in shipped M2 and is outside M3.

M3 does not extend Departure activation to require Supplier Arrangements. A Departure may activate before Supplier planning is complete. Supplier-planning readiness is shown separately.

`ReturnDepartureToDraft` currently has no downstream-history check. M3D extends that command, sharing the Departure lock with Arrangement activation, so the first successful activation cannot race a return to draft. The same lock/recheck boundary covers `MarkDepartureDeparted` versus Arrangement activation: departed wins with `invalid_state` for activation; activation winning first still allows the Departure to depart afterward.

### Responsibility and Office attribution

M3 records belong to the Agency and Departure, not to the responsible Office or AgencyUser.

* Current Office is not authorization.
* M3 does not copy `office_id` down every child or freeze Departure responsibility changes.
* Consequential M3 events snapshot the applicable responsible Office and responsible AgencyUser attribution where required for historical reporting.
* Later responsibility reassignment does not rewrite historical attribution.
* An inactive historical Office or AgencyUser remains displayable.

## Supplier lifecycle integration

New Supplier, contracting-Supplier, and Service-Provider assignments require active same-Agency Supplier records. Existing historical associations remain valid after inactivation.

M3A must extend `ChangeSupplierStatus` for the Arrangement, Item-provider, and Occurrence-provider dependencies it introduces rather than creating a separate incompatible Supplier lifecycle path. Ordinary inactivation keeps `manage_supplier_directory`. Force inactivation adds the Administrator permission, required reason, and dependency recheck. M3D extends the same dependency contract for Supplier Reservations and for every unresolved commitment opening it can create (keyed by the copied `committed_supplier_id`). M3E extends disposition, terminal rules that cease blocking, and needs-attention treatment; it does not introduce the first ordinary open-commitment blocker. Together, the slice contracts must define:

* dependency query and terminal-state catalog from closed decision 13, using the effective-provider rule in closed decision 10;
* the canonical lock order, with affected Suppliers before affected Departures and Arrangements;
* ordinary blocked result;
* Administrator force-inactivation permission and required reason;
* needs-attention creation or query semantics;
* audit evidence; and
* recovery-mode allow-list from closed decision 10 while the Supplier is inactive.

Supplier inactivation continues to apply the shipped M1 descendant cascade to Locations, Contacts, and contact destinations. M3 dependencies themselves are retained and are never cascade-mutated.

Reactivating a Supplier does not reactivate, reopen, reconfirm, or resolve any M3 record automatically.

## Authorization

M3 retains the fixed Administrator, Staff, and Viewer access roles and checks the named catalog rather than role-name conditionals.

| Capability | Permission | Administrator | Staff | Viewer |
| --- | --- | --- | --- | --- |
| View Supplier planning | `view_departures` | Yes | Yes | Yes |
| Create and edit tentative drafts | `manage_departures` | Yes | Yes | No |
| Perform ordinary evidence-backed M3 transitions | `manage_departures` | Yes | Yes | No |
| Depart from Supplier terms or required evidence | `override_supplier_planning_terms` | Yes, with reason | No | No |
| Ordinary Supplier inactivation | `manage_supplier_directory` | Yes | Yes | No |
| Force Supplier inactivation over current dependencies | `force_inactivate_supplier_with_dependencies` | Yes, with reason | No | No |
| Cause any mutation through viewing, filtering, or export | none | No implicit side effect | No implicit side effect | Never |

`override_supplier_planning_terms` enters `AccessPermission` with M3B's first capacity-evidence override command. M3A did not add it. No command may substitute a role-name check for that permission.

M3A maps every command to this catalog. Viewer has no mutations except the existing `view_workspace` and `select_office_context` grants.

## Audit and operational history

Every consequential M3 command must define actor, named permission, transaction boundary, lock order, `lock_version` rule, idempotency behavior, records created or superseded, needs-attention effects, audit event, and compensating path.

* Successful consequential commands write audit evidence in the same transaction.
* Expected validation, conflict, stale, and authorization failures do not write success audit events.
* Activated versions, confirmation events, capacity events, commitment history, Deadline history, and idempotency keys are domain records, not JSON hidden inside `AuditEvent#details`.
* Audit subject and action catalogs remain closed. The slice that first writes an Arrangement-consequential event adds `SupplierArrangement` to `AuditEvent::SUBJECT_TYPES`, `RecordAdministrativeAudit`, and the `AGENTS.md` subject invariant in the same change. Later subjects such as Reservation or Deadline are added only by the slice that first writes them.
* The same underlying fact should not be redundantly persisted as competing histories.
* Historical evidence uses safe references. M3 does not add Active Storage or store Supplier credentials or sensitive documents.

## UI and reporting contract

M3 extends the Departure workspace with Supplier planning. It does not create a separate tenant or Office navigation hierarchy. [M3A](m3a-draft-arrangement-structure.md) ships the Departure Supplier-planning panel and Arrangement profile amendments in [the interface contract](../ui/interface-contract.md). [M3B](m3b-supplier-capacity.md) and [M3C](m3c-cost-terms-and-forecasts.md) extend those surfaces for draft capacity and cost configuration. Later M3 slices extend them for Reservations, commitments, and Deadlines.

The milestone must provide, at minimum:

* an Arrangement list grouped or filterable by Supplier and status;
* Arrangement detail showing current version and retained version history;
* clear separation among Items, Occurrences, Resources, Reservations, capacity, cost terms, commitments, and Deadlines;
* Supplier confirmation provenance without ambiguous generic `number` labels;
* capacity views that label inventory mode and measurement basis;
* forecast and exposure views that label selected stage and never mix incompatible measures;
* upcoming/overdue Deadline and Supplier-needs-attention surfaces;
* visible inactive-Supplier and override warnings;
* empty and filtered-empty states;
* keyboard-complete workflows and visible focus; and
* responsive behavior at the established M1E/M2C proof widths: 375, 768, 1280, and 1400 pixels, where 1400 is the reference desktop.

The UI must not display invented Client sales, Traveler occupancy, Supplier balances, Payments, accounting status, or actual margin. Amber indicates deadlines, focus, waypoints, and guarantee exposure; red remains destructive, invalid, cancelled, or overdue. Status never relies on color alone.

## Scenario gates

### Celebrity Beyond

M3 must be able to represent, without service-type subclasses:

* the Celebrity group cruise Arrangement and qualified Supplier group confirmation;
* a cruise Item and one sailing-spanning Service Occurrence;
* cabin-category Resources and cabin-unit Capacity Pools;
* blocked, guaranteed, released, and on-request distinctions without Client Holds or Allocations;
* occupancy-position Supplier cost terms with separate base, tax/fee, discount, and expected-commission treatment where the accepted fixture supplies them;
* the pre-stay hotel as independently governed Supplier planning with one Occurrence per night when capacity varies nightly, including nights that precede `starts_on`;
* hotel blocked versus guaranteed rooms and deposit/option requirements without payment state;
* transfer segments as separate Occurrences with Traveler-position capacity and fixed operated-vehicle cost;
* threshold calculation showing when another operated transfer is needed, without automatically creating it;
* optional specialty dining as a dated Occurrence using the same Item, Occurrence, and cost primitives;
* the excursion's per-person cost, minimum-billed quantity, Deadline, and no invented maximum;
* name-list, option, release, and deposit Deadlines as Deadline facts without generating those documents; and
* insurance Supplier planning without fabricated capacity or Agency cash.

M3 does not assign a cabin, room, seat, transfer, excursion, dining, or insurance policy to a Client Trip or Traveler.

### Vineyard Tour

M3 must be able to represent:

* one 30-seat motorcoach Resource and Traveler-position Capacity Pool;
* fixed operated-vehicle cost without inventing a posted per-person allocation;
* a calculation showing when a second vehicle would be required, without automatically creating it;
* hotel Resources and capacity per night when supported by confirmed source facts;
* per-person meal, tasting, and other Supplier cost patterns;
* separate Supplier Items for the Standard Dinner and Deluxe Wine Dinner; and
* minimum-enrollment, guarantee, Deadline, and exposure shapes when the accepted source facts are available.

The rule that every Client Trip must choose exactly one dinner option belongs to M4. M3 represents the two Supplier-side Items but does not create Client-facing choice logic.

Unresolved Vineyard source facts must not be guessed into fixtures. M3F must identify which acceptance assertions use confirmed facts and which model only the general shape.

## Concurrency and lock-order requirements

Every slice must publish its command lock order. The parent canonical order, shared by M3 establishment commands and `ChangeSupplierStatus` when a Supplier is involved, is:

1. Agency;
2. actor reloaded through the locked Agency for user-driven commands;
3. affected Suppliers in UUID order;
4. affected Departures in UUID order;
5. stable Supplier Arrangement or Arrangements in UUID order;
6. exact Arrangement version or other governing definition;
7. Supplier Reservations, Occurrences, Resources, Capacity Pools, commitments, or Deadlines in stable UUID order as required; and
8. projections or idempotency rows after their owning record.

Create-command exception: when the command creates a new Arrangement or a new child and therefore has no owning Arrangement or child row yet, after Agency → actor → affected Suppliers (when assigning) → Departure (and the parent Item for Occurrence or Resource creates), lock or insert the idempotency row before creating the new aggregate, using uniqueness as the serialization point. For child creates under an existing Arrangement, lock the Arrangement and version first, then the idempotency row, then create. Do not invent a different Agency or Departure order.

Commands that do not involve a Supplier retain the shipped M2 order: Agency, actor, then Departure. Nested commands must not reacquire earlier locks or invent a different order. System-invoked Departure jobs continue to skip actor and `lock_version` while still pessimistic-locking Agency then Departure; those jobs perform no M3 work.

User-driven commands then compare submitted `lock_version` on the mutable aggregate.

At minimum, the slice plans must prove:

* Departure return-to-draft versus first Arrangement activation;
* `MarkDepartureDeparted` versus first Arrangement activation and versus successor activation, with departed-first producing `invalid_state` for activation;
* `MarkDepartureDeparted` versus ordinary draft Arrangement creation and child expansion, with departed-first producing `invalid_state` for new or expanded tentative planning;
* `UpdateDeparture` / `CorrectDepartureCurrency` versus any currency-bearing M3 fact;
* Arrangement successor activation versus concurrent use of the prior version;
* Supplier inactivation versus Arrangement activation, Reservation creation, provider assignment, and commitment opening;
* capacity increase/release/reinstatement/correction races;
* concurrent same-key Pool creation and capacity-event commands;
* capacity event versus Supplier inactivation;
* same-date sequence assignment races;
* future event versus successor activation or Pool omission;
* scheduled projection refresh versus read/mutation catch-up;
* release versus reinstatement of the same release lineage;
* correction versus reconciliation resolution;
* rebuild versus concurrent event insertion;
* cost-source creation versus Supplier inactivation;
* source/component/profile create replay versus concurrent first execution;
* component reorder versus create/remove and percentage-base validation;
* definition edit versus forecast-ready transition;
* participant-category edits versus dependent ready-definition fingerprints;
* usage-assumption updates versus forecast evaluation;
* cost-source removal versus M3A Item/Occurrence/Resource removal;
* Reservation confirmation replay, conflicting Supplier response, and confirmation that atomically opens a deterministic commitment;
* Deadline reschedule/completion/waiver races; and
* idempotent command replay without duplicate versions, confirmations, events, commitments, or audit records.

## Required database and application invariants

Every M3 tenant row carries direct `agency_id`. Cross-Agency references fail at the database boundary as well as in application validation. Command failures reuse the shipped `AgencyCommand` codes (`invalid`, `invalid_state`, `conflict`, `not_found`, `unauthorized`, `dependency_exists`) rather than inventing a parallel error vocabulary.

Slice plans must provide, as applicable:

* UUIDv7 primary keys and UUID foreign keys;
* same-Agency composite foreign keys;
* direct Departure ownership;
* immutable tenant identity;
* valid closed state catalogs from decision 13;
* exact version uniqueness and supersession constraints;
* one active governing version per Arrangement where applicable;
* date/range and local-time consistency, including Occurrences outside the Departure window;
* nonnegative quantities and amounts;
* whole-number capacity quantities with closed bases `resource_units` and `traveler_positions` (no decimal capacity, configurable precision, or arbitrary named basis without amending this parent and ADR 0010);
* `numeric` rates with explicit precision and scale;
* currency equality with the Departure;
* immutable activated terms and append-only event histories;
* `lock_version` on mutable operational aggregates;
* idempotency uniqueness at the appropriate business-command scope;
* qualified external-identifier normalization and uniqueness rules; and
* indexes supporting Departure workspace, Supplier dependency, Deadline queue, capacity projection, and scenario-scale queries.

No M3 slice may add `citext`, `pg_trgm`, another `btree_gist` use, tables to the queue database, or a generic polymorphic financial transaction table merely for implementation convenience.

## Explicit exclusions

M3 does not implement:

* Travel Program;
* parent/child Supplier Arrangements;
* cruise-, hotel-, coach-, meal-, excursion-, or insurance-specific subclasses;
* Packages, standalone Client offers, Client prices, choice groups, or sales capacity;
* Client Trips, Traveling Parties, Traveler Assignments, or responsibility for Charges;
* standalone Supplier Reservations without a governing M3 Arrangement; the later trip-specific shape remains deferred;
* Client Holds, confirmed Allocations, Resource Assignments, occupancy, rooming lists, or fulfillment;
* Occurrence `completed` or any other fulfillment status;
* ordinary first or successor Arrangement activation after the Departure has departed; historical late entry requires a later accepted corrective command;
* creating a new tentative Arrangement after the Departure has departed; late undocumented Supplier work requires a later accepted historical-correction command;
* Supplier Location attachment to Items or Occurrences;
* Client Charges, Receipts, Applications, Credits, refunds, or Supplier-collected Client value;
* Supplier Obligations, invoices, Payments, Payment Applications, Credits, refunds, commission earning/settlement/receipt, or final reconciled cost;
* Agency Cost;
* posted loss, actual margin, operational cash position, or accounting export;
* Cancellation Cases, automatic cancellation interpretation, or Client/Supplier financial dispositions;
* automatic creation of Resources, Occurrences, Reservations, commitments, or Obligations from a threshold;
* decimal capacity, configurable capacity precision, or an arbitrary named capacity measurement basis without amending this parent and ADR 0010;
* automatic reminder alerts, email, Communications, or document issuance;
* functional-currency translation or FX;
* a generated Arrangement reference namespace;
* a new `SearchDepartures` ranking kind for Supplier or confirmation identifiers;
* Office ownership or Office-based authorization for M3 records;
* Supplier credential storage or general document uploads;
* Supplier merge; or
* placeholders for later milestone tables, statuses, routes, navigation, or counts.

## Required proof

Each implementation slice must define focused database, model, command, request, and system tests. M3D.6 proves the M3D slice itself against shipped M3A–M3C. M3F composes shipped M3A–M3E and proves at least:

* both accepted scenario shapes without Travel Program or service-specific subclasses;
* draft-only planning under draft Departures, including draft definitions that are not established supply or effective contracted terms;
* first Arrangement activation permanently blocking return to draft;
* first and successor Arrangement activation only while the Departure is `active`, and `invalid_state` when the Departure is `draft` or `departed`;
* no new tentative Arrangement after the Departure is `departed`; existing unactivated drafts allow cleanup or abandonment only;
* Occurrences that precede or follow Departure operating dates, including Celebrity pre-stay nights, without assigning Occurrence `completed`;
* unmanaged Items activating without a Resource or Capacity Pool;
* `UpdateDeparture` and `CorrectDepartureCurrency` blocked by every currency-bearing M3 fact according to closed decision 12, including that `UpdateDeparture` does not clear or rewrite those facts;
* stable Arrangement identity and immutable activated versions;
* exact version provenance through confirmations, capacity, cost evaluation, commitments, and Deadlines;
* Arrangement versus Supplier Reservation distinction;
* contracting Supplier, Item provider default, and Occurrence override behavior;
* no generated Arrangement reference and unchanged `SearchDepartures` ranking;
* Supplier confirmation evidence and confirmed-without-identifier path;
* Capacity Pool basis/mode distinctions and immutable event reconciliation;
* no Client Hold or Allocation records;
* cost-component calculation, monetary and quantity shortfalls, `numeric` percentage bases, rounding, selected-stage forecast precedence, and derived forecasts with no persisted totals;
* commitment/capacity independence and confirmation that either atomically opens a named deterministic commitment or retains confirmation with a derived unresolved-trigger condition for M3E;
* deposit requirement without payment state;
* qualified exposure and unavailable Agency-cash-at-risk behavior;
* Deadline local-time comparison, completion, rescheduling, waiver, and no automatic side effects;
* Staff evidence-backed capacity changes and Administrator-only term departures;
* ordinary Supplier-inactivation blockers, forced Administrator path, preserved dependencies, and needs-attention;
* unused Item default that is not the effective provider of a current or future `planned` Occurrence and does not block ordinary inactivation;
* past-window `planned` Occurrences and `cancelled` Occurrences that do not block ordinary inactivation;
* inactive-Supplier corrective/resolution paths without selection for new work;
* cross-Agency isolation for every new identifier, command, query, route, and job;
* Viewer read-only behavior;
* concurrency and idempotency races named above, including `MarkDepartureDeparted` versus Arrangement activation;
* bounded query counts and appropriate `EXPLAIN` proof for operational lists and dependency queries;
* accessible keyboard, error-summary, focus, empty-state, and responsive behavior;
* M0-M2 regression; and
* full CI, Tailwind, lint, and security checks.

## M3 exit gate

M3 is complete only when:

1. M3A-M3F are accepted, implemented, merged, and documented as shipped.
2. Departure remains the direct operational root and no Travel Program appears.
3. Draft planning, Arrangement activation only while the Departure is `active`, permanent return-to-draft blocking, and immutable version behavior match this contract.
4. Arrangements, Items, Occurrences, Resources, Capacity Pools, Reservations, confirmations, terms, commitments, deposit requirements, and Deadlines retain distinct meanings.
5. Contracting Supplier and Service Provider default/override behavior preserve exact historical provenance.
6. Supplier-side capacity is explicit, basis-labeled, event-backed, rebuildable, race-safe, and independent from commitments.
7. No Client Holds, Allocations, occupancy, or fulfillment are implemented.
8. Forecast Supplier cost selects one supported stage per economic source and is fully explainable.
9. Commitments and deposit requirements exist without Supplier payable or payment state.
10. Deadline workflow is operational without automatic reminders, Communications, or unrelated side effects.
11. Exposure is always qualified; Agency cash at risk is not fabricated.
12. Supplier inactivation blockers and forced Administrator handling preserve reality without cascading M3 consequences.
13. Celebrity Beyond and Vineyard Tour Supplier-side shapes pass without service-specific subclasses or guessed unresolved facts.
14. Tenancy, authorization, audit, idempotency, concurrency, performance, accessibility, and regression proof are green.
15. Documentation marks M3 complete and M4 as next and unimplemented.

Only after this gate may M4 treat M3 Supplier planning as the source foundation for Packages, standalone services, required choices, pricing, and supply-feasibility explanations.

## Acceptance documentation

This parent is Accepted and amended for M3B, M3C, and M3D (including shipped M3D.0). Accepting or amending it is a documentation status change, not implementation authority for every M3 slice.

After M3D planning promotion (2026-09-17):

* [`docs/README.md`](../README.md), [`docs/planning/roadmap.md`](roadmap.md), [`docs/terminology.md`](../terminology.md), [`AGENTS.md`](../../AGENTS.md), and [`docs/architecture/current-state.md`](../architecture/current-state.md) mark [M3A](m3a-draft-arrangement-structure.md), [M3B](m3b-supplier-capacity.md), [M3C](m3c-cost-terms-and-forecasts.md), and [M3D.0](m3d0-planning-workspace-compression.md) shipped;
* M3D.0 shipped bounded workflow remediation only and introduced no M3D domain record;
* [M3D](m3d-activation-reservations-confirmations.md) and [ADR 0012](../adr/0012-arrangement-activation-reservations-and-confirmations.md) are shipped;
* the M3D.0 prerequisite for production M3D domain implementation is satisfied;
* M3E–M3F remain unimplemented.

Leave shipped [M2](m2-departure-core.md) and [M2C](m2c-acceptance-and-hardening.md) historical exclusions intact. M3A added `force_inactivate_supplier_with_dependencies`, Arrangement audit subjects, and Departure Supplier-planning panels. M3B added `override_supplier_planning_terms` with its first capacity override path. M3C added the first ADR 0001 monetary-table pattern for draft Supplier cost definitions and derived forecasts. M3D.0 compressed the planning workspace without adding M3D records. M3D ships activation, Reservations, confirmations, and the narrow confirmation-triggered commitment core.
