# M3D.7 — Activated definition immutability

**Status:** Shipped.

**Parent authority:** [M3 — Supplier planning](m3-supplier-planning.md), shipped [M3D](m3d-activation-reservations-confirmations.md), [ADR 0008](../adr/0008-supplier-arrangement-version-topology.md), and [ADR 0012](../adr/0012-arrangement-activation-reservations-and-confirmations.md).

**Relationship to M3D:** Bounded post-ship remediation over shipped M3D. It does not authorize M3E Arrangement ending, Deadlines, exposure, remittance, FX, Travel Program, Traveler, Receipt, Obligation, or Payment. `M3D.1` remains the shipped activation-persistence implementation slice name; this remediation is **M3D.7**.

## Goal

Make exact-version Arrangement definition and configuration graphs immutable in both Rails and PostgreSQL once their Arrangement version leaves `draft`, so activated commercial authority cannot be rewritten in place. Later consequential records that read live definition rows (including commitment opening) must continue to observe the same facts the activation claimed.

## Problem

Command paths already resolve the sole editable draft (`ensure_draft_graph!`). PostgreSQL owner-change triggers freeze ownership columns only. Direct model mutation and SQL can still rewrite commercial fields on activated, superseded, or abandoned retained versions. Commitment opening reads live `SupplierCostComponent#amount_minor_units` for contracted authority shapes, so a post-activation rewrite can change later commitment money while still citing the original exact version.

## In scope

- PostgreSQL INSERT/UPDATE/DELETE freeze for every exact-version definition/configuration table when the parent version is not `draft`.
- PostgreSQL lifecycle-transition guard on `supplier_arrangement_versions` for accepted status transitions only.
- Matching Rails guards so ordinary model mutation fails clearly before PostgreSQL raises.
- Owner-change trigger parity for `supplier_commitment_trigger_definitions`.
- Regression proof for activated, superseded, and abandoned retained graphs; successor draft editability; commitment-rate integrity; legal lifecycle transitions only.
- Documentation indexing when this slice ships.

## Out of scope

- Snapshotting commitment money at activation (freeze is the durable fix).
- Capacity events, projections, or reconciliations (separate rules).
- M3D evidence/activation/confirmation/commitment tables already covered by `reject_m3d_immutable_mutation`.
- New domain tables or commercial semantics.
- M3E–M3F records.

## Locked invariants

1. An activated Arrangement version is immutable commercial authority (ADR 0008).
2. Successors replace without rewriting predecessors.
3. Activated, superseded, and abandoned retained exact-version definitions reject INSERT, UPDATE, and DELETE in Rails and PostgreSQL.
4. Only draft versions accept definition mutation.
5. Version lifecycle transitions are exactly: `draft → activated`, `activated → superseded`, and never-activated `draft → abandoned`.
6. Activation, successor activation (supersede), and abandon commands remain the product paths for legal transitions.

## Exact-version tables

Apply the shared non-draft freeze to:

- `arrangement_item_definitions`
- `service_occurrence_definitions`
- `supplier_resource_definitions`
- `capacity_pair_definitions`
- `capacity_pool_definitions`
- `supplier_cost_sources`
- `supplier_cost_definitions`
- `supplier_cost_components`
- `supplier_cost_component_bases`
- `supplier_cost_participant_categories`
- `supplier_cost_usage_assumptions`
- `supplier_cost_occupancy_profiles`
- `supplier_cost_occupancy_profile_positions`
- `supplier_commitment_trigger_definitions`

## Required proof

- Activate a version, then attempt `update!`, `update_columns`, `destroy`, and raw SQL UPDATE/DELETE against one representative row from each definition family; every attempt fails and values are unchanged.
- Repeat against a superseded predecessor and an abandoned retained version.
- INSERT referencing an activated or superseded version is rejected.
- Concurrent INSERT while activation holds the version lock waits on a parent-version `FOR SHARE` and is rejected after activation commits.
- A successor draft remains fully editable and independent.
- Attempt to alter an activated contracted cost component, then open a Reservation confirmation commitment and assert the original activated rate.
- Legal lifecycle transitions succeed; reversals and unsupported pairs fail in Rails and PostgreSQL.

## Documentation when this slice ships

- This plan → Shipped.
- [docs/README.md](../README.md), [AGENTS.md](../../AGENTS.md), [m3-supplier-planning.md](m3-supplier-planning.md), [roadmap.md](roadmap.md), [architecture/current-state.md](../architecture/current-state.md), and the M3D parent note that M3D.7 closed the activated-definition immutability gap.

## Exit gate

- Non-draft exact-version definition graphs reject INSERT/UPDATE/DELETE in Rails and PostgreSQL.
- Successor drafts remain editable.
- Illegal version lifecycle transitions fail; legal activate/supersede/abandon paths succeed.
- Post-activation cost rewrite cannot change commitment money for contracted authority shapes.
- Docs list M3D.7 as shipped; M3E remains unimplemented until a separately accepted slice names that work.
