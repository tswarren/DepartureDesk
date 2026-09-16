# ADR 0008: Stable Supplier Arrangement identity and immutable version topology

- Status: Accepted. Not implementation authority.
- Date: 2026-09-16
- Decision owners: DepartureDesk maintainers

## Context

M3 Supplier planning must preserve the governing Supplier agreement that applied when later capacity, cost, confirmation, commitment, sale, allocation, and fulfillment facts were resolved. Supplier agreements also change over time. Editing an activated agreement in place would make earlier decisions appear to have been governed by terms that did not exist when those decisions were made.

An Arrangement contains separately identifiable Items, Service Occurrences, and Supplier Resources. Those children also need continuity across revisions. Replacing every child identifier whenever an agreement changes would prevent later records from recognizing that, for example, an O1 cabin category or a hotel-night service is conceptually the same child under a revised definition.

The model therefore needs to distinguish stable identity from the exact versioned definition without introducing live inheritance or duplicating an entire unrelated Arrangement for every revision.

## Decision

This ADR locks the topology required by [M3 closed decision 4](../planning/m3-supplier-planning.md). It does not authorize Arrangement tables or commands by itself.

### Stable Arrangement and immutable activated versions

`SupplierArrangement` is the stable identity for one independently governed agreement or purchasing relationship between one Departure and one contracting Supplier.

`SupplierArrangementVersion` is the exact commercial definition for that Arrangement at a point in its revision history.

The staff-facing Arrangement name is audited operational identity metadata on the stable Arrangement. It is not copied into each version and does not by itself create a commercial revision.

- The initial version is editable while draft.
- An activated version is immutable.
- A revision creates an independent successor draft copied from the current activated version.
- Activating a successor governs future resolution and supersedes the prior version without rewriting it.
- Later consequential records reference the exact Arrangement version that governed them.
- Changing the contracting Supplier or representing an independently governed agreement requires a new Arrangement, not another version.

There may be at most one editable draft version for an Arrangement at a time.

Version numbers are positive, monotonic within the Arrangement, assigned when each draft is created, and never reused. Abandoned drafts therefore may leave visible gaps in the sequence.

### Stable child identities and versioned definitions

`ArrangementItem`, `ServiceOccurrence`, and `SupplierResource` are stable child identities. Version-specific commercial and schedule attributes live in definition rows tied to one exact Arrangement version.

- The same conceptual child keeps its stable identity across copied successor versions.
- Each version owns an independent definition row for every child present in that version.
- Editing a successor changes only that successor's definition.
- A child added in a successor receives a new stable identity.
- A child removed from a successor is absent from that version; earlier retained versions continue to contain its definition.
- Later records may reference both the stable child and the exact Arrangement version when both continuity and provenance matter.

An Occurrence and a Resource each belong immutably to one Item. A Resource represents a contracted category, class, or planned unit and may participate in capacity for multiple Occurrences of that Item. It is not an individual cabin, room, seat, or Traveler assignment.

Service Occurrence current operational lifecycle (`planned` or `cancelled`) lives on the stable Occurrence identity, not on a versioned definition. Cancelling an Occurrence must not mutate an activated commercial definition and must not require a commercial successor version. Definition rows hold name, description, schedule, zone, and provider override only.

### Draft removal and retained history

A child identity may be deleted only when it and its entire removed subtree:

- were created solely in the current unpublished draft;
- have never appeared in an activated or abandoned retained version; and
- have no downstream dependency outside that unpublished draft.

Otherwise the stable identity survives and a later version omits its definition. Audit evidence does not substitute for retained domain history.

### Lifecycle meanings

The stable Arrangement lifecycle distinguishes:

- `draft`: never activated and still editable where state gates permit;
- `active`: governed by a current activated version;
- `ended`: ordinary post-activation terminal; and
- `abandoned`: a never-activated Arrangement draft intentionally discarded.

M3 does not add a `cancelled` Arrangement status. Supplier cancellation does not change the Arrangement to `cancelled`. Entire-agreement Cancellation Cases remain M7.

The version lifecycle distinguishes:

- `draft`;
- `activated`;
- `superseded`; and
- `abandoned`.

Abandoning the initial never-activated draft abandons both version 1 and the Arrangement. The retained graph becomes read-only and cannot later activate or be restored. Restarting requires a new Arrangement.

Abandoning a successor draft abandons only that version. The Arrangement continues under its prior activated version.

Every abandonment requires a reason and immutable audit evidence.

`ended` and `abandoned` are both terminal for ordinary Supplier-inactivation blockers. `abandoned` applies only to a never-activated Arrangement.

### Optimistic locking

Arrangement identity remains lockable because name, contact, and status are mutable. Child create, remove, and reorder submit and bump the Arrangement-version `lock_version`. Editing an existing child definition uses that definition’s `lock_version`.

`ArrangementItem` and `SupplierResource` identity rows hold immutable ownership only and do not need their own optimistic locks. `ServiceOccurrence` identity rows also carry the current operational lifecycle status and therefore require `lock_version` so later cancellation can update the stable current-status projection without editing an activated definition.

## Consequences

### Positive

- Activated commercial history cannot be rewritten in place.
- Later records can identify both conceptual continuity and exact governing definitions.
- Successor drafts are safe, independent workspaces rather than live inheritance layers.
- Removed children remain explainable wherever retained history depends on them.
- Version numbers remain durable references even when a draft is abandoned.
- Never-activated discard is distinct from post-activation ending and from M7 cancellation.

### Costs

- Persistence requires stable identity tables plus version-specific definition tables.
- Successor creation must copy a graph transactionally while preserving stable child identifiers.
- Same-Agency, same-Departure, same-Arrangement, and parent-child relationships require explicit composite constraints.
- Queries must deliberately select a version rather than treating the latest row as universally authoritative.

## Alternatives rejected

### Edit one Arrangement graph in place

Rejected. It would reinterpret earlier confirmations, capacity, costs, commitments, allocations, and sales after an agreement changed.

### Create a new Arrangement for every revision

Rejected. It would lose continuity for the governing relationship and its conceptually unchanged children.

### Give every copied child a new identity

Rejected. Later records could not recognize the same service or resource across agreement versions.

### Keep live inheritance from the prior version

Rejected. A later edit to a predecessor could silently alter a successor draft or make its effective definition ambiguous.

### Delete abandoned drafts and rely on audit JSON

Rejected. Audit details are evidence about commands, not the authoritative retained domain graph.

### Add Arrangement `cancelled`

Rejected. A cancelled Arrangement status would shortcut M7 Cancellation Cases. Supplier cancellation does not change Arrangement lifecycle to `cancelled`.

## Implementation boundary

This ADR establishes the durable identity and revision topology. It does not authorize Supplier Arrangement tables or commands by itself.

M3A may implement initial draft creation, draft editing, and abandonment only after its slice contract is accepted. Arrangement activation, successor creation and copying, supersession, and normal ending remain later-slice work. Arrangement cancellation is not an M3 Arrangement status.
