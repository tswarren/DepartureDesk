# M4D.1 Slice 2B-UX-R — Contributor Replace and 2B-UX Closure

**Status:** Accepted and Shipped 2026-09-23 with this PR. Sole authority for the cumulative contributor-link position-collision fix on deposit child replacement, for reconciling [Slice 2B-UX](m4d1-slice2bux-deposits-deadlines-workspace-remediation.md) planning-milestone authority with shipped M3E, and for Mark Shipped documentation pins for 2B-UX. Parent [M4D.1](m4d1-departure-composition-workspace.md) remains Accepted for later slices. Slice 2C+, Client connection, and M4E remain unauthorized until named.

**Parent authority:** [M4D.1 Slice 2B-UX](m4d1-slice2bux-deposits-deadlines-workspace-remediation.md) (product merge [`bba974c`](https://github.com/tswarren/DepartureDesk/commit/bba974c) / PR #151), shipped [Slice 2B](m4d1-slice2b-cruise-deposits-deadlines-and-activation-safe-editing.md) / [2B-R](m4d1-slice2br-cruise-deposit-semantics-amendment.md), and shipped M3E/ADR 0013.

**Accept package base:** Green `main` tip including shipped 2B-UX merge [`bba974c`](https://github.com/tswarren/DepartureDesk/commit/bba974c).

**Ship commit:** This PR’s merge tip on `main` (fill after merge). **2B-UX product ship tip** remains [`bba974c`](https://github.com/tswarren/DepartureDesk/commit/bba974c) (PR #151).

**Scope locked:** Contributor-link replace ordering (destroy removed → two-phase reposition retained → create new), regression coverage, 2B-UX caveat/§9.2 milestone reconciliation, and documentation Mark Shipped / index updates. Does not authorize Slice 2C or change deposit economics.

---

## 1. Outcome

Closing Slice 2B fully:

1. Removing or reordering cumulative contributors no longer violates the unique `(definition_id, position)` index.
2. Accepted 2B-UX text matches restored M3E milestone behavior (future Arrangement-local `occurred_on` permitted).
3. Repository indexes mark 2B-UX Shipped at `bba974c` while broader Slice 2B remains Shipped.

**Exit:** Named regressions green; 2B-UX and this remediation marked Shipped; Slice 2C still unauthorized until it has its own Accepted plan.

---

## 2. Locked defect

`replace_deposit_children!` matched retained contributor links by `contributor_definition_id` and updated final `position` **before** destroying removed rows. With unique index `index_deposit_contributor_links_on_definition_position`, dropping the first of multiple contributors (A@1, B@2 → keep B@1) collided while A still held position 1. Reordering retained contributors had the same mid-replace collision.

---

## 3. Locked fix

Inside the existing deposit-update transaction:

1. Destroy contributor links not retained in the new set.
2. Move retained rows to temporary positions above any final range.
3. Assign final positions from the new attrs.
4. Create any new contributor links last.

Preserve retained link row identity (`contributor_definition_id` remains `attr_readonly`). Do not use association `delete_all`. Coverage and cost child replace paths are unchanged.

---

## 4. Authority reconciliation

Slice 2B-UX Accept caveat 4 and related proof bullets originally required rejecting future planning-milestone dates. Implementation PR #151 restored shipped M3E behavior (no such rejection). This remediation amends 2B-UX documentation to match M3E and notes the same correction on the merged PR #151 description. Do not reintroduce future-date rejection.

---

## 5. Proof

- Final deposit with two contributors: drop the first; the retained link lands at position 1 without uniqueness failure; link id preserved.
- Final deposit with two contributors: swap order; both link ids preserved at final positions 1 and 2.
- Existing single-contributor coverage-update regression remains green.

---

## 6. Non-goals

- Slice 2C Accept or implement.
- Activation readiness / blocker-surfacing polish beyond shipped 2B-UX.
- Further Stop D layout changes (dedicated editor pages, etc.).
- New deposit amount shapes or economics.
