# ADR 0010: Supplier capacity ledger and projection

- Status: Accepted. Not implementation authority by itself; [M3B](../planning/m3b-supplier-capacity.md) is the implementing slice.
- Date: 2026-09-16
- Decision owners: DepartureDesk maintainers

## Context

DepartureDesk must represent Supplier-side supply before Client Holds, Allocations, occupancy, fulfillment, or Supplier settlement exist. The same Supplier Resource and Service Occurrence may have several distinct supply tranches, such as a fixed group cabin block plus overflow available on request.

Capacity must preserve exact Arrangement-version and Supplier provenance without allowing later edits to reinterpret earlier facts. Staff also need fast current and future views, but a mutable available-count column would lose the history required to explain releases, withdrawals, reinstatements, corrections, and concurrency outcomes.

The model must distinguish:

- intentionally unmanaged Items from unfinished managed configuration;
- firm numeric supply from on-request or externally managed availability;
- stable Pool continuity from immutable per-version definitions;
- authoritative business events from a disposable read projection;
- Supplier discrepancies from projection corruption; and
- already-authorized scheduled changes from dates that merely predict or require future action.

## Decision

This ADR locks the identity, event, and projection topology required by the Accepted M3B contract. It does not authorize persistence or commands by itself.

### Capacity applicability

Capacity applicability is an exact-version attribute of an Arrangement Item.

- `managed` means the version must classify every non-cancelled Occurrence–Resource pair as `pooled` or `not_applicable` before activation.
- `unmanaged` means no Capacity Pool or pair classification exists for that Item version.
- An undecided value may exist only while a version remains an editable draft.

`unmanaged` is not a Capacity Pool inventory mode. Absence is never represented by a zero-quantity Pool.

### Stable Pool and versioned definition

A Capacity Pool is the stable identity of one Supplier supply tranche. It belongs immutably to one Agency, Departure, Supplier Arrangement, Arrangement Item, Service Occurrence, Supplier Resource, and supplying Supplier.

The supplying Supplier must equal the Occurrence's effective provider in the exact Arrangement version when the Pool is created and activated. It remains immutable so provider changes cannot reinterpret prior capacity history.

Each Arrangement version containing the Pool owns an independent Pool definition. The definition contains presentation and draft-preparation facts such as stored label, notes, unit label, proposed opening quantity/evidence, and manual position. Successor versions copy definitions without live inheritance.

Pool semantic identity fixes:

- Occurrence;
- Resource;
- supplying Supplier;
- inventory mode;
- measurement basis; and
- governing IANA zone after first activation.

Pool creation copies the governing IANA zone from the exact-version Service Occurrence definition. There is no staff-selectable Pool zone and no Departure fallback at Pool creation; M3A already requires every Occurrence to store a recognized IANA zone. If the Occurrence zone changes while the Pool is still draft-only, the Pool becomes incomplete rather than changing silently. Staff must restore the matching Occurrence zone or remove and recreate the Pool. Once the Pool has retained activated history, its zone cannot change.

A semantic change creates a new stable Pool. A draft-only Pool that has never appeared in retained history and has no downstream dependency may be deleted under the same removal principle as M3A children. Otherwise the identity and retained definitions survive.

### Modes and measurement

Pool modes are exactly:

- `block`;
- `allotment`;
- `on_request`; and
- `externally_managed`.

Only `block` and `allotment` use the numeric ledger. They share ledger mechanics but retain different Supplier-facing meaning. `on_request` and `externally_managed` are nonnumeric; they never store zero, unlimited, estimated, or informational quantity as managed supply. They still require a measurement basis and a presentation-only unit label so staff can describe what kind of supply is requested or managed externally. The unit label does not imply that DepartureDesk knows the quantity.

M3 capacity quantities are whole numbers only. M3B measurement bases are exactly `resource_units` and `traveler_positions`. One Pool has one basis; the system never converts one basis into the other. No later M3 slice may add fractional precision or another measurement basis without amending the M3 parent and this ADR.

### Immutable event ledger

Capacity events are append-only Supplier-side business facts. The closed event catalog is:

- `established`;
- `increased`;
- `released`;
- `reinstated`;
- `withdrawn`;
- `corrected_up`; and
- `corrected_down`.

`established` records one opening total. Every later event stores a positive magnitude and the event type determines direction. The ordered ledger must remain nonnegative after each event.

A reinstatement references one prior release. Several reinstatements may reference that release, but their total cannot exceed its unreinstated quantity. Capacity restored after a Supplier withdrawal is an increase.

An event correction references the mistaken event when known. A reconciliation correction instead references a durable reconciliation discrepancy. Corrections never edit, delete, or replace earlier events.

Every event retains direct Agency and Departure ownership; stable Pool, Arrangement, and exact governing version provenance; immutable supplying Supplier; measurement basis; business-effective date; application instant; recorded time; immutable same-date sequence; quantity; Supplier evidence or explicit Administrator override; actor attribution; reason where required; correction/reinstatement lineage where applicable; and durable command-idempotency identity.

### Evidence and override

Ordinary events require structured evidence kind, evidence date, and reference note. External reference is optional. Evidence is attachment-ready, but M3B does not add file storage or require an upload.

An Administrator with `override_supplier_planning_terms` may omit ordinary Supplier evidence only for an otherwise valid event and only with a required reason and visible override marking. Override cannot bypass ownership, activation, basis, nonnegative replay, lineage, idempotency, or immutability.

### Effective dates and deterministic ordering

Events may be past, current, or future. A future event becomes applicable at the end of its local effective date in the Pool's governing IANA zone. End of day is the start of the following local calendar date, which handles daylight-saving transitions without inventing `23:59:59`.

Events within one Pool and effective date use an explicit immutable sequence. Commands default to the next sequence but may accept an explicit unused placement when business order matters. Timeline ordering is effective date, sequence, recorded time, then UUID.

A future event retains the Arrangement version that governed it when recorded. It is not reassigned when a successor activates. It applies only if that successor carries the same stable Pool; a pending event prevents omission.

### Stored projection

The event ledger is authoritative. Each numeric Pool has one rebuildable stored projection that provides **Current Supplier capacity** and scheduled-change metadata.

An idempotent scheduled job refreshes Pools whose next event has become applicable. Every capacity read or mutation also performs locked catch-up before using the projection. Refreshing or rebuilding the projection creates neither a capacity event nor a business audit event.

The projection stores enough replay position to prove which events it includes and the next scheduled boundary. Full replay from immutable events must reproduce it exactly.

Projection drift is a technical discrepancy and is repaired by rebuilding from the ledger. A Supplier-observed quantity that differs from a correct ledger is a business discrepancy and requires an evidence-backed or explicitly overridden correction event.

`available`, `remaining`, `held`, `allocated`, and `sold` are not aliases for the projection. Those measures require later Client demand records.

### Reconciliation

Every completed reconciliation is retained, including a match. Its immutable observation records Supplier-observed quantity and time, ledger quantity at the same point, variance, evidence or override, actor, and recorded time.

Resolution is append-only. A matching observation is complete immediately. A discrepancy remains open until linked correction events resolve it. The observed facts are never rewritten.

### Lifecycle and recovery

A numeric Pool must reach zero and have no pending event or open reconciliation discrepancy before it can be omitted from a successor, its Arrangement can end, or the Departure can eventually close out.

Occurrence cancellation creates no capacity event. A cancelled or elapsed Occurrence may retain unresolved capacity, which remains visible and must be reduced explicitly through release or withdrawal. Dates never imply fulfillment or release.

After forced Supplier inactivation, Staff may reduce or resolve the dependency through release, withdrawal, downward correction, reconciliation, and projection repair. New Pools, establishment, increases, and reinstatements are prohibited. Administrator-only upward correction remains available solely to preserve historical truth. Previously recorded future events remain immutable and apply unless countermanded through an evidenced compensating event.

## Consequences

### Positive

- Supplier capacity remains explainable and replayable.
- Successor versions preserve Pool continuity without reinterpreting earlier events.
- On-request and externally managed supply are represented honestly rather than as zero or infinity.
- Future Supplier instructions can be recorded once and take effect deterministically.
- Cache corruption and real Supplier discrepancies have different remedies.
- Later Holds and Allocations can consume capacity without redefining the Supplier ledger.

### Costs

- Persistence requires stable Pool identities, per-version definitions, pair classifications, events, projections, reconciliations, and reconciliation-resolution history.
- Future events require scheduled refresh plus read-side catch-up.
- Same-Arrangement and same-Item provenance requires composite foreign keys and immutable-ownership enforcement.
- Successor activation must validate Pool carry-forward, pending events, provider consistency, and unresolved balances.
- Event commands require durable idempotency, canonical locks, and full-timeline replay.

## Alternatives rejected

### Mutable available-count column

Rejected. It loses evidence, cannot explain concurrency outcomes, and confuses Supplier supply with later Client demand.

### One Pool per Occurrence–Resource pair

Rejected. One pair may contain separate block, allotment, on-request, or other Supplier tranches with independent provenance.

### Treat unmanaged as a Pool mode

Rejected. It creates a fictional Pool to represent the absence of capacity management and cannot distinguish intentional absence from unfinished setup.

### Numeric on-request or externally managed quantities

Rejected. A zero, unlimited value, or informal estimate would appear authoritative when DepartureDesk does not control or know the supply.

### Mutable events or absolute-total restatements

Rejected. Editing history or replacing each prior total makes correction provenance and concurrent replay ambiguous.

### Live calculation without a stored projection

Rejected. Operational reads need a bounded current view, while the immutable ledger remains available for verification and rebuild.

### Projection overwrite for Supplier discrepancy

Rejected. It would conceal that the authoritative business ledger was incomplete or wrong.

### Automatic event creation from a date or Deadline

Rejected. A date can classify or trigger projection refresh for an existing event; it cannot prove that Supplier capacity changed.

### Automatic unit conversion

Rejected. Resource units and Traveler positions express different inventory facts. Occupancy or threshold ratios do not make them interchangeable.

### Decimal or open-ended measurement bases

Rejected. Whole-number `resource_units` and `traveler_positions` are the closed M3B catalog. Fractional precision or another named basis requires amending the M3 parent and this ADR.

## Implementation boundary

This ADR establishes capacity topology and authority. It does not authorize M3B persistence or commands by itself.

[M3B](../planning/m3b-supplier-capacity.md) may implement draft Pool configuration and the event/projection/reconciliation engine after its slice contract and the required M3 parent amendment are Accepted. Arrangement activation and user-accessible effective-capacity controls remain M3D work.

M3B must not add a production activation command, bypass flag, controller, route, task, seed, or console-oriented service. Activated test graphs are created only by static fixtures or helpers under `test/`. Event, reconciliation, override, projection, and inactive-Supplier recovery commands are proven in model/service tests and are not reachable from HTTP or Staff UI until M3D explicitly exposes them.
