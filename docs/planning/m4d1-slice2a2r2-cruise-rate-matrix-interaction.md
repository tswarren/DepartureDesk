# M4D.1 Slice 2A.2R2 — Cruise Supplier Rate Matrix Interaction

**Status:** Accepted 2026-09-22. Implementation authority for Cruise Supplier rate-matrix **interaction** remediation only. Not yet shipped.

**Parent authority:** [M4D.1 — Departure Composition Workspace](m4d1-departure-composition-workspace.md), especially §§11–12 and Stop point C.

**Shipped matrix authority (retained):** [M4D.1 Slice 2A.2R](m4d1-slice2a2r-cruise-supplier-rate-matrix.md) remains sole shipped authority for M3C compilation, legacy projection/conversion, zero-amount readiness, and typed compatibility detection.

**Implementation base:** [`4a3bc3c`](https://github.com/tswarren/DepartureDesk/commit/4a3bc3c) (ship of Slice 2A.2R, PR #139). Reconfirm CI on the branch tip before coding.

**Layout guide (non-authority):** [Cruise Supplier Rate Workspace Wireframe](drafts/DepartureDesk-Cruise-Supplier-Rate-Workspace-Wireframe.md) suggests possible Staff layout for sections, commission panels, illustrations, and narrow-screen behavior. Use it when designing chrome. This Accepted interaction contract and the browser acceptance scenarios govern when wireframe and contract disagree. Do not treat the wireframe as a competing implementation plan.

**Scope locked:** Interactive matrix builder, method-gated commission chrome, unsaved-matrix illustrations, and browser acceptance over the shipped 2A.2R compiler. Does not authorize Slice 2B+, Client Service connection, Client prices, Package scenarios, M4E, new Cruise-specific tables, or a second money engine.

```mermaid
flowchart LR
  accept["Accept 2A.2R2"] --> build["Builder + preview"]
  build --> ship["Ship 2A.2R2"]
```

## 1. Outcome

The rate matrix is not merely a server-rendered view of components that already exist. It is an interactive matrix builder in which Staff create, configure, reorder, and remove columns and rows before saving.

For one Cruise cabin category, Staff must be able to:

1. Add, edit, reorder, and remove supported rate-profile columns without first saving.
2. Add, edit, reorder, and remove custom component rows (static four rows remain fixed).
3. Edit cell amounts with live profile subtotals in the Departure operating currency.
4. Configure commission with method-gated controls and per-populated-cell treatment.
5. See occupancy illustrations derived from the **current unsaved** matrix.
6. Submit the entire resulting matrix in one atomic save; the server remains authoritative after submission.

**Exit criterion:** System acceptance must construct the family-rate fixture entirely through visible page controls; programmatically submitting a flexible matrix payload is not sufficient proof.

## 2. Why this slice exists

Shipped 2A.2R already authorizes flexible profiles, custom rows, presets, bounded positions, per-cell commission bases, and multi-category illustrations. The page instead treated profiles as fixed server state and made mostly cells editable. Service tests proved the backend could accept flexible payloads; they did not prove a person could construct those payloads through the page.

This slice remediates that gap. It does not replace 2A.2R’s M3C compilation contract.

## 3. Contrast (required vs insufficient)

| Required dynamic editor | Insufficient implementation |
| --- | --- |
| Staff add a Child column | Staff relabel an existing column as Child |
| Staff add Every Cabin while retaining other columns | Every Cabin appears only if already persisted |
| Staff remove an irrelevant profile | Staff leave all its cells blank |
| Staff add and remove component rows | Staff can only append rows |
| Commission controls follow added cells | Commission controls reflect only server-rendered cells |
| Unsaved matrix drives illustrations | Illustrations reflect only the saved graph |
| Charge/credit changes update signs immediately | Correct totals appear only after save |

## 4. Interaction model

The Supplier-rate form is a dynamic collection editor.

Staff build the matrix directly on the page:

- Rate profiles are user-managed columns.
- Supplier components are user-managed rows (plus four static rows).
- Amounts are editable cells.
- Commission treatment is associated with populated cells.
- Unsaved additions and removals update the page immediately.
- Staff submit the entire resulting matrix in one atomic save.

The initial columns and rows are **starter content**, not a fixed schema.

The form must not require Staff to save, visit advanced planning, or manipulate existing generic components before they can add an ordinary profile or component.

No durable records are created for empty profiles or blank cells until the whole form is saved with populated cells (2A.2R §7.6 preserved).

## 5. Dynamic columns

Provide an explicit **Add rate profile** action.

Selecting it opens an inline panel containing:

- Profile family:
  - Every Traveler
  - First/Second
  - Additional
  - Bounded positions
  - Every Cabin
  - Single Supplement
- Optional traveler category when allowed (Adult, Child, or another Staff-entered category).
- For bounded positions: starting position and optional ending position.

After Staff confirm:

1. A new column appears immediately.
2. The column contains an input for every existing component row.
3. A corresponding commission input appears when dollar or profile-specific percentage commission is selected.
4. A corresponding commission-treatment control appears for every populated cell.
5. The narrow-screen profile selector includes the new column.
6. Live subtotals and illustrations recalculate.

Each column provides: Edit profile; Move left/right; Remove profile.

Removing a column must:

- remove its unsaved cells;
- remove its commission amount or percentage;
- remove its commission-base selections;
- update subtotals and illustrations immediately;
- require confirmation if it contains entered values.

At least one profile with a populated cell must remain before save.

Supported families and selectors remain those of shipped 2A.2R §7, including **Bounded traveler positions** with Staff-supplied start/end. Ship the bounded family in typed form state and normalize it into M3C occupancy positions on save.

## 6. Dynamic rows

The four standard rows always appear and cannot be renamed or removed:

- Base Fare
- NCCF
- Taxes & Fees
- Discount

Provide an **Add component** action for additional rows. A custom component requires description and Supplier charge or Supplier credit.

After it is added:

1. The row appears immediately.
2. It contains one amount input for every selected profile.
3. Charge cells display `$`; credit cells display `−$`.
4. Commission-treatment controls become available for its populated cells.
5. Live subtotals recalculate.

Each custom row provides: Edit description; Change charge/credit kind; Move up/down; Remove.

Changing the kind must immediately change the sign and recompute all affected subtotals and illustrations.

Removing a row must also remove its commission-base selections and warn before discarding entered values.

## 7. Cells

Each row/column intersection behaves independently:

- Blank means no component.
- `0.00` means a known contractual zero.
- A populated charge cell increases its profile subtotal.
- A populated credit cell decreases its profile subtotal.
- Clearing a populated cell removes that prospective component and its commission treatment.
- Currency formatting uses the Departure operating currency.

No save is required before these effects appear. Browser subtotals remain advisory; server values govern after save.

## 8. Commission interaction

The commission method selector controls which interface is visible:

- Not provided yet
- Percentage
- Dollar amount

Only the controls for the selected method are displayed.

### 8.1 Percentage

Staff choose either one shared percentage, or different percentages by profile.

For every populated rate cell, display one treatment:

- Charge cell: Include or Ignore
- Credit cell: Subtract or Ignore

Selecting a treatment immediately recalculates commissionable amount, expected commission, and net Supplier cost (via live preview).

Adding, clearing, or removing a populated cell must also add, remove, or invalidate its commission-treatment state.

Compilation rules (shared vs profile-specific rounding, additive bases, readiness) remain shipped 2A.2R §10.

### 8.2 Dollar

Display one amount input for every selected rate profile. Adding or removing a profile must add or remove the associated dollar-commission input immediately.

## 9. Occupancy illustrations

Illustrations are derived from the current unsaved matrix—not only from the last saved definition.

For a single-category schedule, suggest Single, Double, and Triple illustrations up to maximum occupancy.

When multiple traveler categories exist, Staff can define anonymous occupants by position (for example Double Adult; Adult + Child; Family Triple).

Adding or editing a profile, row, cell, commission treatment, or illustration selection recalculates displayed results without a save.

Provide a draft-only preview path that accepts the same matrix payload shape as create/update, evaluates without writing, and returns illustrations. The server remains authoritative after submission. Do not invent a second money engine.

## 10. Persistence and commands

Reuse shipped create/update schedule commands and `normalize_matrix_payload`. Expand form param normalization for builder-emitted ordered profiles (including bounded + category), custom row order, and per-cell treatments mapped to `add_cells` / `subtract_cells`.

Overlap resolution remains server-enforced on save (2A.2R §7.3). Empty profiles create no durable records.

No `SupplierCostRateProfile` table. No Cruise-specific rate persistence.

## 11. Browser acceptance (blocking)

These system scenarios are exit criteria. Programmatic flexible payloads alone do not satisfy them.

1. **Create a Child profile** — Open a new Smith-style schedule; Add rate profile → Additional + Child; verify a new column appears without replacing Additional; enter a child fare; save and reopen; both columns remain.
2. **Add Every Cabin** — Add Every Cabin; enter a cabin-level component; verify subtotal and saved generic `resource_units` basis.
3. **Remove a profile** — Add a profile with values; remove and confirm; cells and commission controls disappear; save; components do not exist.
4. **Manage a custom credit** — Add a custom component; change charge to credit; sign and subtotal change before save; remove; row disappears.
5. **Build family pricing from an empty form** — Create Adult First/Second, Adult Additional, Child, Every Traveler, and Single Supplement solely through UI; enter the family fixture; configure per-cell commission treatment; verify mixed-category illustrations; save and reopen without losing structure.
6. **Responsive behavior** — Add enough profiles to exceed the narrow viewport; every new column appears in the mobile profile selector and remains editable.

## 12. Delivery

1. Accept this document and update indexes / `AGENTS.md` / parent pointers.
2. Implement builder UI, bounded family, method-gated commission, unsaved preview, and the six system scenarios.
3. Mark this slice **Shipped** when exit proof is green.

## 13. Non-goals

- New Cruise-specific tables or a second money engine.
- Slice 2B deposits/deadlines; Client, Package, or Service Offer work; M4E.
- Replacing advanced cost planning for unsupported formulas.
- Changing shipped M3C evaluation math beyond previewing unsaved payloads.
- Treating the wireframe ASCII layout as pixel-level authority.

## 14. Concise correction

The page must expose the matrix vocabulary as an interactive builder, not merely render a matrix projection of the current M3C graph. Staff must be able to add, edit, reorder, and remove supported rate-profile columns and custom component rows without first saving. Every structural change must immediately update cells, commission controls, profile subtotals, occupancy illustrations, and narrow-screen navigation. System acceptance must construct the family-rate fixture entirely through visible page controls; programmatically submitting a flexible matrix payload is not sufficient proof.
