# M4D.1 Slice 2A.2R3 — Cruise Rate-Shape Detector Remediation

**Status:** Shipped 2026-09-23. Sole shipped authority for typed Cruise Supplier rate-shape detector remediation (percentage↔profile / collision-safe cell-key association). Parent [M4D.1](m4d1-departure-composition-workspace.md) remains Accepted for later slices. Does not authorize typed Slice 2B deposits/deadlines until that slice has its own Accepted plan; Client connection and M4E remain unauthorized.

**Parent authority:** [M4D.1 — Departure Composition Workspace](m4d1-departure-composition-workspace.md), Stop point C / rate-matrix reopen.

**Retained matrix authority:** [Slice 2A.2R](m4d1-slice2a2r-cruise-supplier-rate-matrix.md) (compilation) and [Slice 2A.2R2](m4d1-slice2a2r2-cruise-rate-matrix-interaction.md) (interactive builder; shipped at [`b73a9ff`](https://github.com/tswarren/DepartureDesk/commit/b73a9ff)) remain sole shipped authorities for those surfaces. This slice remediates detector truth only.

**Accept package base:** [`5a391d1`](https://github.com/tswarren/DepartureDesk/commit/5a391d1) (green `main` tip including shipped [Slice 2B-R](m4d1-slice2br-cruise-deposit-semantics-amendment.md)).

**Ship commit:** `SHIP_COMMIT_SHA` (pin after commit).

**Downstream:** Typed [Slice 2B](drafts/composition-workspace/M4D1-Slice2B-Cruise-Deposits-Deadlines-and-Activation-Safe-Editing-Draft.md) implementation may begin when Slice 2B has its own Accepted plan (2B-R Path B domain already shipped).

**Scope locked:** Detector reconstruction and validation for percentage commission ↔ matrix cell association. No new commission economics, mixed percentage/dollar typed matrices, deposit/deadline work, or Cruise-specific persistence.

---

## 1. Outcome

Correct `DetectCruiseSupplierRateShape` so reopen / compatibility mapping between percentage commission components and rate profiles is unambiguous and non-destructive.

**Exit:** Supported percentage-commission matrices reopen as editable typed schedules with correct profile associations; unsupported graphs remain Advanced with specific reasons and unchanged durable facts; the seven blocking regressions in §6 are green; documentation marks this slice Shipped.

---

## 2. Locked defect

1. Matrix reconstruction assigns collision-safe keys to custom rows (for example `port_fee` and `port_fee_2`).
2. Commission-base reconstruction independently regenerates a key from the label and can map both bases to `port_fee`.
3. Profile-specific commissions are inferred from their bases without rejecting components that span multiple profiles or multiple components that target the same profile.
4. When overlap occurs, the detector effectively lets the last component overwrite the earlier profile rate.

---

## 3. Locked contracts

### 3.1 Authoritative cell-key mapping

While reconstructing cells, build one authoritative `component_id → cell_key` mapping (including collision-safe custom row keys). Commission reconstruction and matrix validation **must** use that mapping. They must not independently derive row keys from labels alone.

### 3.2 Percentage topology

- One percentage commission component means **shared** percentage.
- Multiple percentage commission components mean **profile-specific** percentage.
- Each profile-specific component must reference cells from **exactly one** profile.
- No profile may be represented by more than one commission component.
- Every base must resolve to an actual projected cell in the same definition.
- Ambiguous, overlapping, orphaned, or cross-profile graphs remain **Advanced** and are never partially projected.

Aligns with shipped [2A.2R §§10.2–10.3](m4d1-slice2a2r-cruise-supplier-rate-matrix.md).

### 3.3 Non-destructive behavior

- Detection performs no writes.
- Reopening and saving without edits preserves shared-versus-profile-specific component topology, base directions, rates, and rounding boundaries.
- Unsupported graphs return specific reasons and preserve all durable facts.

### 3.4 Named surfaces (existing)

- `DetectCruiseSupplierRateShape`
- `CompileCruiseSupplierRatePreview`
- `CreateCruiseSupplierRateSchedule`
- `UpdateCruiseSupplierRateSchedule`

Do not invent a second detector or money engine.

---

## 4. Scope and non-goals

### 4.1 In scope

- Fix `DetectCruiseSupplierRateShape` reconstruction and validation per §3.
- Focused service (and reopen round-trip) regressions per §6.
- Documentation Accept → Shipped and index updates.

### 4.2 Out of scope

- New commission economics or mixed percentage/dollar typed matrices.
- Deposit/deadline work (2B / 2B-R).
- Reopening 2A.2R matrix compilation authority except where detector truth requires a narrow clarification.
- Typed Slice 2B UI.

---

## 5. Implementation note

Primary change surface: `DetectCruiseSupplierRateShape#reconstruct_matrix` and related commission reconstruct/validate helpers. Thread the authoritative map into shared and profile-specific percentage reconstruction. On topology failure, fail closed to Advanced (reasons; no partial `rates` hash).

---

## 6. Blocking regressions

1. Shared percentage spanning multiple profiles reopens as one shared component.
2. Multiple profile-specific percentages reopen with the correct rate and bases per profile.
3. Two custom row labels that slugify identically retain distinct commission bases.
4. Cross-profile component fails closed.
5. Overlapping components for one profile fail closed.
6. Missing/orphaned base fails closed.
7. Reopen → unchanged save → reopen preserves topology and calculated totals.

---

## 7. Handoff

After this slice ships, typed Slice 2B implementation may begin when Slice 2B has its own Accepted plan. This slice does not Accept or authorize 2B.
