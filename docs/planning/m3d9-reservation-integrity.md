# M3D.9 — Reservation integrity remediation

**Status:** Shipped.

**Parent authority:** [M3 — Supplier planning](m3-supplier-planning.md), shipped [M3D](m3d-activation-reservations-confirmations.md), [ADR 0012](../adr/0012-arrangement-activation-reservations-and-confirmations.md).

**Relationship to M3D:** Bounded post-ship Reservation integrity remediation over shipped M3D Reservation response, revision, request, and outcome persistence. It does not authorize M3E Arrangement ending, Deadlines, exposure, remittance, FX, Travel Program, Traveler, Receipt, Obligation, or Payment. `M3D.1`–`M3D.6` remain the shipped implementation slice names; [M3D.7](m3d7-activated-definition-immutability.md) and [M3D.8](m3d8-activation-reservation-product-quality.md) remain prior remediations; this remediation is **M3D.9**.

## Goal

Close three post-ship integrity gaps before M3E: confirmed quantity-basis fidelity through commitment opening, successor revision/request revalidation of scopes and booking Suppliers (including Capacity Pool definition membership at the database boundary), and event↔outcome compatibility in Rails and PostgreSQL.

## Problem

1. **Confirmed quantity basis:** A response can confirm a quantity with a basis that diverges from the requested scope (and Pool measurement basis). `confirmed_entries` drops basis, and commitment opening silently re-labels quantity from the trigger basis.
2. **Successor revision/request:** Default revision copy skips `normalize_scopes!`, so a stable Pool (or other) FK can remain valid while the target exact version no longer defines that target. Booking Supplier eligibility is not rechecked at revision create or request.
3. **Outcome matrix:** Append-only outcomes can be inserted with kinds incompatible with the parent event kind, producing false Reservation history.

## In scope

- Confirmed `quantity_basis` must match scope (and Pool) basis; pass basis through commitment opening; lock response UI basis controls.
- Always revalidate scopes through `normalize_scopes!` on revision copy; recheck booking Supplier eligibility at revision create and request; BEFORE INSERT/UPDATE Pool-definition membership trigger on `supplier_reservation_scopes`.
- Rails and PostgreSQL event/outcome compatibility matrix; no confirmation evidence for counterproposal-only responses.
- Documentation indexing when this slice ships.

## Out of scope

- New commercial records or quantity columns.
- Inventing M3C↔capacity basis mappings.
- M3E ending, Deadlines, exposure, remittance, or FX.
- UI redesign beyond locking confirmed-basis selectors to the requested/trigger-compatible value.

## Locked invariants

1. A confirmed quantity’s `quantity_basis` must equal the requested scope basis (and, for Capacity Pool targets, the Pool `measurement_basis`).
2. Quantity-bearing commitment openings require a confirmed basis that equals the trigger’s `quantity_basis`; the commitment stores that confirmed basis (not a silent re-label).
3. Successor revision creation always revalidates scopes through `normalize_scopes!` against the **target** exact version.
4. Booking Supplier must remain eligible (contracting Supplier or effective Provider for that version) at revision create and again at request.
5. Outcome kinds are compatible with parent event kinds: `request→requested`, `withdrawal→withdrawn`, `cancellation→cancelled`, `response→confirmed|declined|counterproposed`; `revision` events carry no outcomes.
6. A counterproposal-only response does not create or link confirmation evidence.

## Required proof

- Service tests: confirmed basis ≠ scope → `:invalid`; ≠ trigger → `:invalid` at open; matching path → `commitment.quantity_basis` equals confirmed outcome basis; unit-rate shape covered.
- Successor omits occurrence/pool definition → revision copy rejects; booking Supplier no longer a Provider → revision and request reject; happy path with retained structure succeeds; adversarial SQL INSERT of pool scope without definition rejects.
- Model + raw SQL adversarial inserts (`request`+`confirmed`, `response`+`requested`, etc.) reject in Rails and PG; existing command happy paths still pass; counterproposal-only response creates no confirmation link.

## Documentation when this slice ships

- This plan → Shipped.
- [docs/README.md](../README.md), [AGENTS.md](../../AGENTS.md), [m3-supplier-planning.md](m3-supplier-planning.md), [roadmap.md](roadmap.md), [architecture/current-state.md](../architecture/current-state.md), and the M3D parent note.

## Exit gate

- Confirmed basis cannot diverge from scope/Pool or silently re-label commitment quantity meaning.
- Successor default-copy revision and subsequent request reject undefined targets and ineligible booking Suppliers.
- Capacity Pool scopes require a version definition at the database boundary.
- Outcome/event kind matrix enforced in Rails and PostgreSQL; counterproposal-only responses stay confirmation-free.
- Docs list M3D.9 as Shipped; M3E remains unimplemented until a separately accepted slice names that work.
