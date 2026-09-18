# M3D.8 — Activation and Reservation product-quality remediation

**Status:** Shipped.

**Parent authority:** [M3 — Supplier planning](m3-supplier-planning.md), shipped [M3D](m3d-activation-reservations-confirmations.md), [ADR 0012](../adr/0012-arrangement-activation-reservations-and-confirmations.md), and the [interface contract](../ui/interface-contract.md).

**Relationship to M3D:** Bounded post-ship product-quality remediation over shipped M3D activation and Reservation surfaces. It does not authorize M3E Arrangement ending, Deadlines, exposure, remittance, FX, Travel Program, Traveler, Receipt, Obligation, or Payment. `M3D.1`–`M3D.6` remain the shipped implementation slice names; [M3D.7](m3d7-activated-definition-immutability.md) remains the definition-immutability remediation; this remediation is **M3D.8**.

## Goal

Bring Arrangement activation and Supplier Reservation UI into conformance with the canonical form anatomy, accessible command-error recovery, progressive-disclosure interaction contract, exclusive composers, bounded list/history loads, and table overflow treatment already required by M3D and the interface contract.

## Problem

Shipped M3D activation and Reservation views invent control and summary classes (`dd-input`, `dd-select`, `dd-textarea`, `dd-error-summary`, `dd-notice`), put `.dd-field` on wrappers instead of controls, render flash-only unlinkable error summaries, pad Reservation scope forms to three full rows, stack competing composers on the Reservation profile, load unbounded Reservation lists and histories, and omit `.dd-table-wrap` on dense operational tables.

## In scope

- Canonical `.dd-field-group` / `.dd-field` / `.dd-alert` anatomy on activation and Reservation surfaces.
- Linked `#form-error-summary` recovery for every M3D command form, including disclosure-open-before-focus and submitted-value preservation.
- Progressive disclosure for Reservation scopes and responses; exclusive `?composer=` modes on Reservation show.
- Bounded Reservation list and show history (50 + 1 lookahead) with query-count and representative EXPLAIN proof.
- `.dd-table-wrap` (and narrow-width stacked Reservation index treatment) for dense M3D tables.
- Documentation indexing when this slice ships.

## Out of scope

- New commercial records or domain semantics.
- Inventing parallel `.dd-input` / `.dd-select` / `.dd-textarea` / `.dd-error-summary` / `.dd-notice` components.
- Redesigning activation beyond form, accessibility, and disclosure fixes.
- M3E–M3F records.

## Locked invariants

1. Controls use `.dd-field`; wrappers use `.dd-field-group` (label / hint / control / `.dd-field-error`).
2. Invalid command forms use `#form-error-summary` with `role="alert"`, `tabindex="-1"`, Stimulus `form-error-summary`, title “Please fix the following:”, and links to `#{param_key}_#{attribute}`.
3. Submitted values survive server-side rejection, including multi-composer Reservation show.
4. Required invalid inputs are not left inside a closed `<details>`; summary focus opens the disclosure.
5. Reservation request defaults to one entry-point scope; additional scopes via **Add another scope**; target fields show only for the chosen `target_kind`.
6. Response defaults to one whole-response choice; per-scope editors appear only for partial/mixed; decline / counter / evidence / capacity appear only when relevant.
7. Reservation show is display-first with at most one open composer (`request` | `withdraw` | `respond` | `cancel` | `revise`).
8. Reservation list and show history are bounded with the repo’s 50 + 1 lookahead → truncated pattern.
9. Dense operational tables sit in `.dd-table-wrap`; primary identity/state/action remain usable at 375px.

## Required proof

- Request assertions that rendered activation and Reservation controls use canonical classes.
- System tests assert `document.activeElement` on `#form-error-summary` after failure; follow a summary link to the associated field; invalid identifier inside activation details becomes visible and focused; rejected withdraw/cancel keep reason and scope selections.
- Keyboard-only single-scope request without unused rows; partial response then return to all-scopes mode; at most one composer open.
- Query-count assertions for small vs large Reservation lists and shallow vs deep history; representative EXPLAIN for list/history SQL.
- No document-level horizontal overflow at 375, 768, 1280, and 1400 px for dense M3D tables.

## Scenario scale for query proof

- Large list: 51+ Reservations under one Arrangement.
- Deep history: 51+ events (and/or revisions) on one Reservation.

## Documentation when this slice ships

- This plan → Shipped.
- [docs/README.md](../README.md), [AGENTS.md](../../AGENTS.md), [m3-supplier-planning.md](m3-supplier-planning.md), [roadmap.md](roadmap.md), [architecture/current-state.md](../architecture/current-state.md), the M3D parent note, and the interface-contract scope line that M3D.8 closed the activation/Reservation product-quality gap.

## Exit gate

- No invented control/summary classes on activation/Reservation surfaces.
- Every M3D command failure uses linked `#form-error-summary` with proven focus.
- Single-scope request and uniform response are short keyboard paths; partial paths are progressive.
- One composer open at a time on Reservation show.
- Reservation list/history bounded with query-count proof.
- Dense tables overflow inside `.dd-table-wrap`; no document-level horizontal scroll at required widths.
- Docs list M3D.8 as shipped; M3E remains unimplemented until a separately accepted slice names that work.
