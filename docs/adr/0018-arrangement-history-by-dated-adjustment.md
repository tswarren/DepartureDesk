# ADR 0018: Supplier arrangement history by dated adjustment

- Status: Accepted 2026-11-01. Decision log entry D-63. The charter's Phase 1 hold-and-reserve spike decides code reuse and is recorded as an amendment.
- Date: 2026-11-01
- Decision owners: DepartureDesk maintainers
- Supersedes, for the new supplier, inventory and booking layer: [ADR 0008](0008-supplier-arrangement-version-topology.md); the version-provenance, per-version definition, pair-classification and mode parts of [ADR 0010](0010-supplier-capacity-ledger-and-projection.md); and [ADR 0011](0011-supplier-cost-definitions-and-forecast-evaluation.md), [ADR 0012](0012-arrangement-activation-reservations-and-confirmations.md) and [ADR 0013](0013-supplier-operational-commitments-deadlines-exposure-and-ending.md). Those ADRs keep governing the shipped M3 and M4 code until charter Phase 1 deletes it (D-66).
- Specification: SUP-06, SUP-07, SUP-11 to SUP-19, INV-01 to INV-05, INV-10, INV-26, INV-27, INV-32, INV-38, SMN-03, SMN-06, SMN-23
- Charter: [first-slice charter](../planning/first-slice/first-slice-charter.md), steps 3 to 6 and 11; demonstration cases D1, D2, D7

## Context

ADR 0008 keeps supplier history by versioning: an activated Arrangement version is immutable, and any change creates a successor draft that copies the whole graph of Items, Occurrences, Resources, Pools, costs, deposits and deadlines with stable child identities. ADRs 0010 to 0013 build on that topology, and every capacity event, cost source and commitment carries exact-version provenance.

That model kept history safe but made each supplier type expensive to build. The Cruise and Hotel workflows needed successor copying, carry-forward validation and version-aware queries for every change.

The specification keeps history a different way. An arrangement is Draft, Confirmed, Closed or Cancelled (SUP-11). Shells and pools are created when it is confirmed (SUP-12). After confirmation, changes to capacity, terms or cost are dated adjustments that preserve the original records, and a supplier amendment adjusts the current obligation without rewriting past due events or settlements (SUP-14). Every inventory change is a dated event (INV-26). Descriptive edits are made in place with audit; structural changes once allocations exist need replacement inventory (INV-32).

Both models refuse to rewrite history. They differ in the unit of change: a whole-graph version, or one dated row.

## Decision

### One arrangement record, no versions

- An arrangement belongs to one Departure and one supplier (SUP-07). It has one record and lifecycle Draft, Confirmed, Closed or Cancelled (SUP-11). There are no arrangement versions, successor drafts or per-version definition rows.
- While Draft, the arrangement and its inventory groups, terms and costs are edited in place. Commands are audited; keystrokes and autosaves are not (ACC-25). Deadlines recorded in Draft create tasks (SUP-23).
- Discarding a Draft moves it to Cancelled with no supplier or financial effect.

### Confirmation is one atomic command

Confirming an arrangement, in one transaction:

1. records the supplier confirmation and its evidence (SUP-05);
2. freezes the term rows that exist at that moment: schedule lines, deadlines, cancellation tiers, commission and rate table (M3, once approved);
3. creates unit shells and capacity pools for each inventory group, each with an opening event (SUP-12, INV-05, INV-26); and
4. records committed cost exposure (SUP-13).

After confirmation, frozen rows are never updated or deleted.

### Every later change is an append-only dated row

| What changes | How it is recorded |
| --- | --- |
| Capacity | An inventory event with an effective date and evidence: increase (adds shells or pool quantity), release, supplier reduction, reinstatement or correction. Holds and allocations are recorded on the same timeline (INV-26). |
| Supplier terms | A new term row with an effective date that supersedes a named earlier row. The earlier row is kept. Amounts already due or settled are never recalculated (SUP-14). |
| Supplier cost | A dated cost adjustment linked to the cost line it changes. Calculated amounts are rounded once when posted, then snapshotted (SMN-06). |
| Money | Payments and their applications are append-only, corrected by reversal (SMN-23, CMN-27). |
| Descriptions | Labels and notes are edited in place with an audit event (INV-32). |
| Structure after allocations exist | Blocked. Staff create replacement inventory and resolve allocations explicitly (INV-32). |

Later records reference the row that governed them, not a version: an amount due references its schedule line, an allocation references its shell or pool, and a cost line references the rate it came from. A confirmed client booking snapshots its own accepted price and terms (BKG-25), independently of supplier history.

### What carries over from ADR 0010

These capacity principles agree with INV-26 and stay:

- Events are append-only. Each stores a positive magnitude; its type gives the direction.
- Replaying the events in order never takes capacity below zero. An agency-initiated reduction below active allocations is refused; a supplier-driven one is recorded and creates a capacity conflict (INV-26, INV-27).
- Corrections reference the event they correct and never edit it.
- Supplier reconciliations are kept as observations, including matches.
- A stored projection is a rebuildable cache. Full replay must reproduce it. Reads and writes catch it up under lock.
- A date passing never creates an event by itself.
- On request and Rate only inventory shows no numeric balance and is never stored as zero or unlimited (INV-04).
- Every event carries agency and Departure ownership, actor, recorded time and a command idempotency key.

### What is dropped from ADRs 0008 and 0010

- Exact-version provenance on events, pools and costs.
- Per-version pool definitions and successor carry-forward.
- Occurrence-by-Resource pair classification and the managed or unmanaged capacity flag. Each inventory group instead chooses one representation: unit shells, a capacity pool, or no shared inventory (INV-03).
- The pool modes `block`, `allotment`, `on_request` and `externally_managed`. The availability promise per inventory group replaces them: Firm block, Releasable block, Courtesy or option, On request, or Rate only (SUP-15). The promise and the representation are separate facts.

### Derived, never stored

Shell status (INV-38), remaining pool capacity (INV-10) and the arrangement's committed exposure are computed from events and rows. No mutable available-count column exists.

### Old and new layers do not mix

The shipped M3 and M4 tables are dropped in charter Phase 1, after the hold-and-reserve spike and before Slice 1 step 1 (D-66). Nothing is migrated out of them, and the Alpha fixture is seeded fresh. Once a table is dropped, the new layer may reuse its name for the new meaning. Capacity ledger code the spike chooses to adapt is kept and changed to these rules; nothing else from those layers is reused.

### Left to the spike

The charter's 2–3 day hold-and-reserve spike runs on the existing capacity pools. It decides whether the shipped `CapacityEvent`, projection and reconciliation code is adapted (by removing version provenance) or replaced. The spike also proposes:

- when a date-only capacity adjustment takes effect, and in which zone; and
- whether holds and allocations share the capacity event table or have their own table on the same timeline.

Its result is recorded as an amendment to this ADR before Slice 1 step 3. Either outcome must satisfy every rule above.

## Consequences

### Positive

- One arrangement record per supplier per Departure, matching how staff and the specification describe it.
- A change touches the rows it changes, not a copied graph, so each new supplier type costs far less.
- History is still complete: nothing confirmed is rewritten, and each later record points at the row that governed it.

### Costs

- "What were the terms on date X?" is answered by effective-dated queries over term rows, not by loading one version. These queries need care and tests.
- Retiring the M3 and M4 layers early removes the shipped Cruise, Hotel, Transportation and Activity workflows before their replacements exist. No real agency data depends on them.
- ADR 0010's ledger engine may need rework to drop version keys, depending on the spike.

## Alternatives rejected

### Keep the version topology for the new layer

Rejected. It satisfies SUP-14 but keeps the whole-graph copy, carry-forward validation and version-aware queries that made each supplier type expensive.

### Edit confirmed records in place with audit only

Rejected. Audit events are evidence about commands, not the authoritative history (ADR 0008's reasoning still holds), and SUP-14 requires the original records to be preserved.

### Snapshot the whole arrangement at each change

Rejected. Same cost as versioning, without stable references.

### Migrate shipped M3 data into the new layer

Rejected. No real agency data exists, and a bridge would carry ADR 0008's topology into the new layer.

## Implementation boundary

Governs charter Slice 1 steps 3 to 6 and 11, and Slice 1b's dated resource increase (D7). Its spike amendment must be recorded before step 3 starts.
