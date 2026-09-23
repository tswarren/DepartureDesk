# M4D.1 later-slice discovery sequence

**Status:** Discovery only. Not implementation authority. Do not treat this document as a competing specification.

**Accepted foundation:** [M4D.1 Slice 1 — Workspace foundation](../../m4d1-slice1-workspace-foundation.md) (**shipped**).

**Shipped typed slice:** [M4D.1 Slice 2A.1 — Cruise sailing and cabin inventory](../../m4d1-slice2a1-cruise-sailing-and-cabin-inventory.md) (**shipped**). That plan remains the sole shipped authority for typed Cruise Stop points A–B.

**Shipped typed slice:** [M4D.1 Slice 2A.2 — Cruise Supplier rates and occupancy totals](../../m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md) (**shipped**). Historical fixed-form baseline for Stop point C.

**Shipped remediation:** [M4D.1 Slice 2A.2R — Cruise Supplier Rate Matrix](../../m4d1-slice2a2r-cruise-supplier-rate-matrix.md) (**shipped**). Sole shipped authority for matrix compilation remediation of Stop point C.

**Shipped interaction remediation:** [M4D.1 Slice 2A.2R2 — Cruise Supplier Rate Matrix Interaction](../../m4d1-slice2a2r2-cruise-rate-matrix-interaction.md) (**shipped** at [`b73a9ff`](https://github.com/tswarren/DepartureDesk/commit/b73a9ff)). Sole shipped authority for interactive builder remediation.

**Shipped:** [Slice 2B-R — Cruise deposit semantics amendment](../../m4d1-slice2br-cruise-deposit-semantics-amendment.md).

**Draft (not Accepted):** [Slice 2B — Deposits, deadlines, and activation-safe editing](M4D1-Slice2B-Cruise-Deposits-Deadlines-and-Activation-Safe-Editing-Draft.md); [Slice 2A.2R3 — Rate-shape detector remediation](M4D1-Slice2A2R3-Cruise-Rate-Shape-Detector-Remediation-Draft.md).

Parent spine: [M4D.1](../../m4d1-departure-composition-workspace.md) §21.

Do not implement any item below until that item has its own Accepted plan.

Recommended refinement sequence after shipped 2A.2R2:

1. **Slice 2B-R — M3E Cruise deposit-semantics amendment** ([Shipped](../../m4d1-slice2br-cruise-deposit-semantics-amendment.md))
2. **Slice 2A.2R3 — Cruise rate-shape detector remediation** (2B implementation prerequisite; Draft)
3. **Slice 2B — Deposits, deadlines, and activation-safe editing** (typed Stop D; Accept after 2A.2R3 ships; Draft)
4. **Slice 2C — Service connection, categories, and Client choices**
5. **Slice 2D — Client-term compilation and scenario Review**
6. **Slice 3 — Adapter generalization**
7. **Slice 4 — Vineyard proof**
8. **Slice 5 — Broader Client terms and Review refinement**

Splitting 2A keeps the first typed implementation from combining topology, capacity, cost evaluation, and occupancy rules in one delivery contract. Splitting 2B-R from 2B keeps domain economics out of the typed adapter Accept.
