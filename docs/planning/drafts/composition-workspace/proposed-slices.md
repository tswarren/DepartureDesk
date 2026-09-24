# M4D.1 later-slice discovery sequence

**Status:** Discovery only. Not implementation authority. Do not treat this document as a competing specification.

**Accepted foundation:** [M4D.1 Slice 1 — Workspace foundation](../../m4d1-slice1-workspace-foundation.md) (**shipped**).

**Shipped typed slice:** [M4D.1 Slice 2A.1 — Cruise sailing and cabin inventory](../../m4d1-slice2a1-cruise-sailing-and-cabin-inventory.md) (**shipped**). That plan remains the sole shipped authority for typed Cruise Stop points A–B.

**Shipped typed slice:** [M4D.1 Slice 2A.2 — Cruise Supplier rates and occupancy totals](../../m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md) (**shipped**). Historical fixed-form baseline for Stop point C.

**Shipped remediation:** [M4D.1 Slice 2A.2R — Cruise Supplier Rate Matrix](../../m4d1-slice2a2r-cruise-supplier-rate-matrix.md) (**shipped**). Sole shipped authority for matrix compilation remediation of Stop point C.

**Shipped interaction remediation:** [M4D.1 Slice 2A.2R2 — Cruise Supplier Rate Matrix Interaction](../../m4d1-slice2a2r2-cruise-rate-matrix-interaction.md) (**shipped** at [`b73a9ff`](https://github.com/tswarren/DepartureDesk/commit/b73a9ff)). Sole shipped authority for interactive builder remediation.

**Shipped:** [Slice 2B-R — Cruise deposit semantics amendment](../../m4d1-slice2br-cruise-deposit-semantics-amendment.md).

**Shipped:** [Slice 2A.2R3 — Rate-shape detector remediation](../../m4d1-slice2a2r3-cruise-rate-shape-detector-remediation.md).

**Shipped:** [Slice 2B — Deposits, deadlines, and activation-safe editing](../../m4d1-slice2b-cruise-deposits-deadlines-and-activation-safe-editing.md).

**Shipped:** [Slice 2B-UX — Deposits and deadlines workspace remediation](../../m4d1-slice2bux-deposits-deadlines-workspace-remediation.md) (product merge [`bba974c`](https://github.com/tswarren/DepartureDesk/commit/bba974c)).

**Shipped:** [Slice 2B-UX-R — Contributor replace and 2B-UX closure](../../m4d1-slice2buxr-contributor-replace-and-closure.md).

**Shipped:** [Slice 2C — Cruise service connection](../../m4d1-slice2c-cruise-service-connection.md) (merge [`b35a4f6`](https://github.com/tswarren/DepartureDesk/commit/b35a4f6)).

**Accepted:** [Slice 2D — Cruise Client terms and scenario review](../../m4d1-slice2d-cruise-client-terms-and-scenario-review.md) (not shipped; implementation base [`b35a4f6`](https://github.com/tswarren/DepartureDesk/commit/b35a4f6)).

Parent spine: [M4D.1](../../m4d1-departure-composition-workspace.md) §21.

Do not implement any item below until that item has its own Accepted plan.

Recommended refinement sequence after shipped 2A.2R2:

1. **Slice 2B-R — M3E Cruise deposit-semantics amendment** ([Shipped](../../m4d1-slice2br-cruise-deposit-semantics-amendment.md))
2. **Slice 2A.2R3 — Cruise rate-shape detector remediation** ([Shipped](../../m4d1-slice2a2r3-cruise-rate-shape-detector-remediation.md))
3. **Slice 2B — Deposits, deadlines, and activation-safe editing** ([Shipped](../../m4d1-slice2b-cruise-deposits-deadlines-and-activation-safe-editing.md))
4. **Slice 2B-UX — Workspace remediation** ([Shipped](../../m4d1-slice2bux-deposits-deadlines-workspace-remediation.md))
5. **Slice 2B-UX-R — Contributor replace and closure** ([Shipped](../../m4d1-slice2buxr-contributor-replace-and-closure.md))
6. **Slice 2C — Service connection, categories, and Client choices** ([Shipped](../../m4d1-slice2c-cruise-service-connection.md))
7. **Slice 2D — Client-term compilation and scenario Review** ([Accepted](../../m4d1-slice2d-cruise-client-terms-and-scenario-review.md))
8. **Slice 3 — Adapter generalization**
9. **Slice 4 — Vineyard proof**
10. **Slice 5 — Broader Client terms and Review refinement**

Splitting 2A keeps the first typed implementation from combining topology, capacity, cost evaluation, and occupancy rules in one delivery contract. Splitting 2B-R from 2B keeps domain economics out of the typed adapter Accept.
