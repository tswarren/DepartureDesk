# M4D.1 Slice 2A.2R3 — Cruise Rate-Shape Detector Remediation

**Status:** Draft. Not implementation authority until accepted.

**Parent discovery:** [M4D.1](../../m4d1-departure-composition-workspace.md); rate-matrix authority remains [Slice 2A.2R](../../m4d1-slice2a2r-cruise-supplier-rate-matrix.md) and [Slice 2A.2R2](../../m4d1-slice2a2r2-cruise-rate-matrix-interaction.md) (**shipped** at [`b73a9ff`](https://github.com/tswarren/DepartureDesk/commit/b73a9ff)).

**Prerequisite for:** [Slice 2B](M4D1-Slice2B-Cruise-Deposits-Deadlines-and-Activation-Safe-Editing-Draft.md) **implementation** (must ship before 2B coding begins). Not a prerequisite for [Slice 2B-R](M4D1-Slice2B-R-Cruise-Deposit-Semantics-Amendment-Draft.md) domain amendments.

---

## 1. Outcome

Correct the typed Cruise Supplier rate-shape detector so reopen / compatibility mapping between percentage commission components and rate profiles is unambiguous and non-destructive.

Carry-forward defect: percentage↔profile mapping can fail closed incorrectly or mis-associate components after matrix edits, leaving Staff unable to reopen an otherwise supported schedule as an editable typed matrix.

---

## 2. Scope (draft)

- Inspect `DetectCruiseSupplierRateShape` and related compile/reopen paths.
- Fix percentage commission ↔ profile / cell-base association so supported graphs reopen safely.
- Preserve advanced fallback for truly unsupported graphs (no silent rewrite).
- Focused service and system regression for reopen after shared and profile-specific percentage commission.

### Non-goals

- New commission economics or mixed percentage/dollar typed matrices.
- Deposit/deadline work (2B / 2B-R).
- Reopening M4D.1 Slice 2A.2R matrix compilation authority except where detector truth requires a narrow amendment.

---

## 3. Exit (on later ship)

1. Supported percentage-commission matrices reopen as editable typed schedules with correct profile associations.
2. Unsupported graphs remain advanced with specific reasons and unchanged durable facts.
3. Targeted automated proof green; documentation marks this slice Shipped.

---

## 4. Handoff

After 2A.2R3 ships, Slice 2B implementation may begin (still gated on shipped 2B-R for Path B deposit economics). Exact defect reproduction steps and Accept-ready command names lock when this draft is expanded for Accept.
