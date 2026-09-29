# Cruise remediation — Nonnumeric capacity in quantity-derived Supplier requirements

Status: Draft  
Parent: M4D.1 Departure Composition Workspace — Cruise remediation UX  
Prerequisite: UX-4 accepted  
Blocks: UX-5 Review and activate

## 1. Purpose

Correct quantity-derived Supplier requirement evaluation when a Cruise contains
capacity Pools whose inventory mode intentionally does not carry numeric
capacity.

The accepted Supplier capacity model distinguishes numeric inventory from
nonnumeric inventory:

- `block` and `allotment` carry authoritative numeric opening capacity;
- `on_request` and `externally_managed` intentionally do not carry a numeric
  opening quantity.

A valid `on_request` or `externally_managed` Pool therefore has no
`proposed_opening_quantity`.

Generic Supplier Arrangement activation readiness already recognizes this
distinction and does not require proposed opening quantity or numeric evidence
for those inventory modes.

The current quantity-derived Supplier deposit evaluation does not preserve that
distinction. `SupplierDepositAmountEvaluator` requires a positive
`proposed_opening_quantity` when evaluating an opening-quantity-based
requirement. As a result, a valid On request Cruise cabin category can surface:

> Proposed opening quantity is incomplete

and prevent the Cruise activation path from completing.

That result incorrectly treats an intentionally nonnumeric Pool as an
incomplete numeric Pool.

This remediation corrects that semantic mismatch before UX-5 exposes Cruise
activation readiness to Staff.

---

## 2. Scope

This remediation is narrow.

It changes evaluation and presentation of Supplier requirements whose quantity
is derived from Pool opening quantity.

It does not change:

- Capacity Pool inventory-mode semantics;
- Supplier Arrangement activation lifecycle;
- Cruise cabin-category identity;
- Supplier cost/rate definitions;
- Client availability;
- Client holds, requests, bookings, or confirmations;
- Supplier Reservations;
- allocation;
- later-capacity amendment semantics;
- Supplier Obligations or Payments;
- cancellation or release behavior;
- Offer Design;
- Client-service connection;
- the meaning of `proposed_opening_quantity`.

No new Cruise-specific capacity record or deposit quantity snapshot is
introduced.

---

## 3. Existing invariant preserved

Only numeric inventory modes carry authoritative numeric capacity.

### Numeric inventory

`block` and `allotment`:

- may carry `proposed_opening_quantity`;
- require a positive proposed opening quantity when that quantity is needed for
  activation/evaluation;
- require the existing applicable evidence or override;
- contribute their authoritative opening quantity to an opening-quantity-based
  Supplier requirement.

### Nonnumeric inventory

`on_request` and `externally_managed`:

- do not carry authoritative numeric opening capacity;
- do not require `proposed_opening_quantity`;
- must not store `0`, an estimated quantity, an arbitrary placeholder, or an
  informational quantity merely to satisfy evaluation;
- do not contribute a quantity to an opening-quantity-based calculation.

Absence of `proposed_opening_quantity` on one of these Pools means
**quantity not tracked**, not **quantity incomplete** and not **zero capacity**.

This remediation must not weaken that distinction.

---

## 4. Opening-quantity evaluation

For a Supplier requirement whose quantity basis is opening Pool quantity, the
evaluator classifies each applicable Pool according to its authoritative
inventory mode.

### 4.1 Numeric Pool

For `block` or `allotment`:

1. load the exact-version Pool definition;
2. require the existing valid positive `proposed_opening_quantity`;
3. if the quantity is missing or invalid, evaluation is incomplete;
4. otherwise include the quantity in the evaluated opening quantity.

Example:

```text
E3
Inventory: Block
Proposed opening quantity: 8

Contribution to opening quantity: 8