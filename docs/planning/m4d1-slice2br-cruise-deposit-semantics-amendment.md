# M4D.1 Slice 2B-R — Cruise Deposit Semantics Amendment (M3E)

**Status:** Shipped 2026-09-22. Sole shipped authority for generic M3E capacity-sourced deposit quantities and source-aware cumulative targets. Not authority for typed Cruise UI ([Slice 2B](drafts/composition-workspace/M4D1-Slice2B-Cruise-Deposits-Deadlines-and-Activation-Safe-Editing-Draft.md) remains Draft until separately Accepted).

**Parent:** [M4D.1 — Departure Composition Workspace](m4d1-departure-composition-workspace.md) Stop point D / Slice 2B sequencing.

**Amends:** [ADR 0013](../adr/0013-supplier-operational-commitments-deadlines-exposure-and-ending.md), clarifying note on [ADR 0010](../adr/0010-supplier-capacity-ledger-and-projection.md), and [M3E decision register](m3e-decision-register.md).

**Retained:** M3E remains generic Supplier-side planning. No Cruise-specific deposit or deadline tables. No Payments, Obligations, Receipts, or `paid` labeling. `names_assigned_to_supplier` remains Arrangement-wide (no Traveler records).

**Ship commit:** [`dbdb6c2`](https://github.com/tswarren/DepartureDesk/commit/dbdb6c2). Accept package base [`bfe8431`](https://github.com/tswarren/DepartureDesk/commit/bfe8431). Implementation base was green `main` tip including shipped [Slice 2A.2R2](m4d1-slice2a2r2-cruise-rate-matrix-interaction.md) at [`b73a9ff`](https://github.com/tswarren/DepartureDesk/commit/b73a9ff).

**Downstream:** Typed [Slice 2B](drafts/composition-workspace/M4D1-Slice2B-Cruise-Deposits-Deadlines-and-Activation-Safe-Editing-Draft.md) may be Accepted after this slice ships (and other named gates).

---

## 1. Outcome

Ship generic M3E deposit quantity and cumulative-target semantics that faithfully express the established Celebrity contract:

- initial deposit **$50 × initially blocked cabins**;
- final deposit **cumulative target $500 × retained cabins**, crediting the initial requirement at source-aware quantities;
- earlier-of `names_assigned_to_supplier` or fixed fallback (Arrangement-wide milestone);
- rooming-list Deadline only in the Celebrity fixture (no invented legal-names obligation).

Today’s shipped Arrangement-wide **$50 then fixed $500 → $450** Celebrity proof was an incomplete adapter of those contract facts. This slice corrects the domain authority and evaluator; it does not reopen whether the contract is per-cabin.

**Exit (ship):** Evaluator and materialization proof green; amended M3E.7b Celebrity composition; ADR/register Accepted edits applied; no Cruise UI required.

---

## 2. Problem

Prior ADR 0013 / M3E register encoded Celebrity as Arrangement-wide $50, fixed $500 cumulative → $450, via `resource_units` / usage assumptions and position-based prior sum. That cannot express `$50 × blocked` or `$500 × retained` with differing initial vs retained quantities per cabin source.

---

## 3. Scope and non-goals

### 3.1 In scope

- Deposit `quantity_basis` value **`capacity_pool_units`** (generic; not a Pool `measurement_basis`).
- Preview and materialization evaluation against authoritative capacity facts.
- Extended **`cumulative_target`**: quantity-derived target, explicit contributing definitions, source-aware credit/clamp, persisted calculation trace.
- ADR 0013, ADR 0010 clarification, and M3E decision-register amendments.
- Celebrity release-gate / scenario proof updates (omit legal names; Path B amounts).
- Persisted calculation traces on tranche snapshots.

### 3.2 Out of scope

- Typed Cruise Deposits and deadlines UI (Slice 2B).
- Cruise-specific deposit/deadline tables.
- Expanding Capacity Pool `measurement_basis` beyond `resource_units` | `traveler_positions`.
- Per-cabin or Traveler-scoped `names_assigned_to_supplier`.
- Payments, Obligations, Receipts, remittance, FX.
- Percentage deposit redesign.
- Typed reorder/duplicate chrome.

---

## 4. Locked Celebrity product facts

| Fact | Contract |
| --- | --- |
| Initial deposit | $50 × **initially blocked** cabins in explicitly selected Capacity Pools / cabin Resources |
| Final deposit | Cumulative target $500 × **retained** cabins, less credited earlier deposit amounts attributed by source |
| Due rule | Earlier of `names_assigned_to_supplier` or fixed fallback date |
| Milestone | Arrangement-wide Staff planning milestone |
| Rooming list | Informational Deadline when contracted |
| Legal names | **Not** a separate Celebrity fixture obligation |

---

## 5. Locked persistence and commands

### 5.1 Quantity basis `capacity_pool_units`

- Add to `SupplierDepositRequirementDefinition::QUANTITY_BASES` and matching DB check.
- Coverage: `capacity_pool_id` and/or `supplier_resource_id` (resolve Resource → Pool on the version).
- `SupplierDepositAmountEvaluator.call(..., mode: :preview | :materialize)`:
  - **preview:** sum `CapacityPoolDefinition.proposed_opening_quantity`
  - **materialize** for `quantity_times_rate`: established opening (`CapacityEvent` type `established` quantity)
  - Never fall back to usage assumptions or one-per-Resource.
- Persist per-source rows in evaluation components/inputs (pool id, resource id, quantity, amount).

### 5.2 Extended `cumulative_target`

| Shape | Fields | Prior credit |
| --- | --- | --- |
| Legacy fixed | `target_amount_minor_units` set; `rate` / `quantity_basis` null; no contributor links | Sum earlier defs by position |
| Quantity-derived (Path B) | `rate_minor_units` + `quantity_basis = capacity_pool_units`; `target_amount` null; ≥1 contributor link | Explicit contributors; source-aware clamp |

Table `supplier_deposit_requirement_definition_contributor_links`:

- UUID PK; agency / departure / arrangement / version FKs
- `supplier_deposit_requirement_definition_id` (cumulative)
- `contributor_definition_id` (prior deposit def on same version)
- `position`; unique `(definition_id, contributor_definition_id)`
- Included in M3D.7 definition freeze

**Retained quantity:** refreshed `CapacityProjection.current_supplier_capacity`; block if missing/stale.

Formula per source `s`: `max(0, rate × retained_s − credited_earlier_s)` then sum.

### 5.3 Commands

Public commands unchanged by name:

- `CreateSupplierDepositRequirementDefinition`
- `UpdateSupplierDepositRequirementDefinition`
- `RemoveSupplierDepositRequirementDefinition`

Widen attributes for `capacity_pool_units`, quantity-derived cumulative fields, and `contributor_definition_ids`. Successor copy must copy contributor links. Materialization calls evaluator with `mode: :materialize`.

---

## 6. Quantity and cumulative rules (normative)

Same lifecycle and source-aware rules as Accepted product facts in §§4–5. Milestone remains Arrangement-wide. Parent §12.4 drops legal names with this Accept.

---

## 7. Proof

1. Draft preview: $50 × sum of proposed opening quantities (e.g. 24 → $1,200).
2. Materialize initial with opening snapshot; final with retained projection and source-aware credit when quantities differ.
3. Incomplete/stale projection blocks materialization.
4. Earlier-of milestone replacement without duplicate commitment.
5. Celebrity composite: Path B amounts; rooming list informational; no legal-names row.
6. Legacy fixed cumulative unchanged when no contributor links / no quantity basis.
7. Cross-agency / freeze / immutability regressions green.

---

## 8. Handoff

This slice is **shipped**. Typed Slice 2B may be Accepted when its own Accept package is ready (still gated on other named prerequisites such as 2A.2R3). This plan does not authorize that UI.
