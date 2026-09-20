# M3F — Acceptance and hardening

**Status:** Shipped (M3F.0–M3F.4); M3 complete  
**Parent:** [M3 — Supplier planning](m3-supplier-planning.md)  
**Baseline:** [M3E.7b release-gate evidence](m3e7b-release-gate-evidence.md) (slice-local Pass; not a substitute for M3F.2)  
**ADR:** [ADR 0012](../adr/0012-arrangement-activation-reservations-and-confirmations.md), [ADR 0013](../adr/0013-supplier-operational-commitments-deadlines-exposure-and-ending.md)  
**Closure:** [m3f4-milestone-closure.md](m3f4-milestone-closure.md) · [m3f3-finding-log.md](m3f3-finding-log.md)

## Purpose

M3F is the milestone acceptance and hardening gate for Supplier planning. It composes shipped M3A–M3E, closes the parent M3 exit criteria, and remediates cross-slice Staff-task friction named by the parent backlog. It adds **no new commercial aggregate**.

M3F.0 is documentation only: it pins the implementation base, assigns ownership of parent proof and exit criteria, publishes the fixture ledger, and defines slice merge gates. Production behavior begins with M3F.1.

## Verified implementation base

| Fact | Value |
| --- | --- |
| Pinned base commit | `51ab34dde81ee215fff318688f614f4349db3df5` (`51ab34d`) |
| Base description | Merge of M3E.7a operational UI recovery (PR #107) on `main`; includes shipped M3E.5R through M3E.7b |
| Contains shipped M3E.7b | Yes — ancestor merge of PR #108 and related M3E stack |
| GitHub CI on pinned `main` | Green — [Actions run 35488087984](https://github.com/tswarren/DepartureDesk/actions/runs/35488087984) (`lint`, `test`, `system-test`, `scan_ruby`, `scan_js` success) |
| M3E.7b baseline | [m3e7b-release-gate-evidence.md](m3e7b-release-gate-evidence.md) is **baseline, not substitute** for M3F.2 integrated journeys |

Production M3F.1+ branches must start from this pinned SHA (or a later `main` that remains a descendant of it) after this gate document is Accepted.

## Ownership map

### Parent required-proof bullets → slice ownership

Parent [Required proof](m3-supplier-planning.md#required-proof) bullets (~L936–970) are owned as follows. M3E.7b may already demonstrate a subset for M3E surfaces; M3F.2 must still compose the **integrated** Celebrity/Vineyard journeys and label ledger facts.

| Theme | Owner |
| --- | --- |
| Both accepted scenario shapes without Travel Program or service-specific subclasses | M3F.2 |
| Draft-only planning; activation latch; active-Departure activation; departed cleanup | M3F.2 |
| Occurrences outside Departure operating dates (Celebrity pre-stay) without `completed` | M3F.2 |
| Unmanaged Items; currency blockers; stable Arrangement identity; exact-version provenance | M3F.2 |
| Arrangement vs Reservation; contracting Supplier / provider default / override | M3F.2 |
| No generated Arrangement reference; unchanged `SearchDepartures` ranking | M3F.2 / M3F.3 regression |
| Confirmation evidence; Capacity Pool basis/mode; no Client Hold/Allocation | M3F.2 |
| Cost-component calculation, shortfalls, rounding, selected-stage forecasts | M3F.2 (ledger-labeled) |
| Commitment/capacity independence; deposit without payment; qualified exposure | M3F.2 |
| Deadline workflow without automatic side effects | M3F.2 |
| Staff capacity / Administrator term-departure paths; inactivation blockers | M3F.2 |
| Cross-Agency isolation; Viewer read-only | M3F.3 |
| Concurrency and idempotency races (incl. departed vs activation) | M3F.3 |
| Bounded query counts and meaningful `EXPLAIN` | M3F.3 |
| Accessible keyboard, error-summary, focus, empty-state, responsive | M3F.1 (task-flow) + M3F.3 (findings) |
| M0–M2 / M0–M3 regression; full CI, Tailwind, lint, security | M3F.3 / M3F.4 |

### Parent exit criteria 1–15 → slice ownership

| # | Exit criterion (summary) | Owner |
| --- | --- | --- |
| 1 | M3A–M3F accepted, implemented, merged, documented shipped | M3F.4 |
| 2 | Departure remains operational root; no Travel Program | M3F.2 prove / M3F.4 docs |
| 3 | Draft planning, activation rules, return-to-draft latch, immutable versions | M3F.2 |
| 4 | Distinct meanings for Arrangements, Items, Occurrences, Resources, Pools, Reservations, confirmations, terms, commitments, deposits, Deadlines | M3F.2 |
| 5 | Contracting Supplier and Service Provider provenance | M3F.2 |
| 6 | Capacity explicit, event-backed, rebuildable, race-safe, commitment-independent | M3F.2 / M3F.3 races |
| 7 | No Client Holds, Allocations, occupancy, or fulfillment | M3F.2 / M3F.4 |
| 8 | Forecast selects one supported stage; fully explainable | M3F.2 |
| 9 | Commitments and deposits without payable or payment state | M3F.2 |
| 10 | Deadline workflow without automatic reminders / Communications | M3F.2 |
| 11 | Exposure always qualified; no fabricated Agency cash at risk | M3F.2 |
| 12 | Inactivation blockers and forced Administrator path preserve reality | M3F.2 |
| 13 | Celebrity + Vineyard shapes without subclasses or guessed unresolved facts | M3F.2 + fixture ledger |
| 14 | Tenancy, auth, audit, idempotency, concurrency, performance, a11y, regression green | M3F.3 |
| 15 | Documentation marks M3 complete and M4 next / unimplemented | M3F.4 **only** |

## Slice table

One PR per slice. Substantial M3F.3 findings receive a focused remediation PR before M3F.4.

| Slice | Scope | Merge gate |
| --- | --- | --- |
| **M3F.0** | This Accepted contract; index link; parent M3F row amendment. **No production behavior.** | Docs-only; pinned base recorded |
| **M3F.1** | Three parent task-flow backlog items only; Staff journey smoke through setup→activation→Reservation→ops | Keyboard + invalid paths at 375 / 768 / 1280 / 1400; no forecast or Reservation command regression |
| **M3F.2** | Integrated Celebrity + Vineyard builders/journeys; ledger-labeled assertions; revisions / ops resolution | Provenance-true outcomes; shape-only marked; no invented source facts |
| **M3F.3** | Only named findings from the M3F.2 finding log (tenancy, replay/races, rebuild equivalence, `EXPLAIN`, a11y, M0–M3 regression) | Finding closed with evidence; CI / security / lint / Tailwind green |
| **M3F.4** | Map every parent exit criterion to evidence; reconcile README, roadmap, architecture, terminology, interface contract, AGENTS, planning index; mark M3 complete / M4 next | No unmatched criterion; no docs-ahead-of-code |

### M3F.1 backlog (codebase anchors)

| Backlog item | Current gap | Intent |
| --- | --- | --- |
| Occupancy-preview double preload | `SupplierCostDefinitionReviewsController` runs forecast evaluate then occupancy preview (second `preload!`). Measure before changing. | Verify-then-fix redundant preload on the cost definition review path |
| Capacity-consequence remove/focus | Reservation show + `reservation_response_fields_controller.js`: add exists; **no remove/focus** | Keyboard focus and removal for capacity-consequence rows |
| Exclusive occupancy-profile editing | `item_costs/show.html.erb`: multiple open `<details>` editors | One exclusive editor; align with [interface-contract.md](../ui/interface-contract.md) |

Capacity-consequence UX lives on an M3D Reservation surface but remains **M3F backlog** by parent assignment—not an M3E.7a reopen. M3E.7a owns M3E form defects; M3F owns cross-slice friction and the milestone gate.

## Fixture ledger

Main M3F.0 decision surface for M3F.2 assertions. Every fixture value must carry one of these labels. **Do not invent unresolved Vineyard or Celebrity worksheet facts into acceptance authority.**

### Confirmed source facts

Authoritative narrative: [`docs/scenarios/celebrity-beyond-2027.md`](../scenarios/celebrity-beyond-2027.md), [`docs/scenarios/vineyard-tour-2027.md`](../scenarios/vineyard-tour-2027.md), and shipped M3E Celebrity deposit/milestone rules.

| Fact | Authority |
| --- | --- |
| Celebrity sailing dates Nov 6–13, 2027; composition of mandatory cruise + optional hotel/transfers/excursion/dining shapes | Celebrity scenario |
| Celebrity Arrangement-wide deposit: $50 per cabin + cumulative $500; planning milestone `names_assigned_to_supplier` Arrangement-wide | M3E / Celebrity scenario amendment |
| Celebrity initial deposit due date **2026-09-20** (Smith Family Reunion agreement) | Confirmed agreement fact; activation after that date requires elapsed-Deadline acknowledgment |
| Celebrity rooming-list 60 days before sailing (2027-09-07) and legal-names 30 days before sailing (2027-10-07) | Confirmed M3E.7b / scenario authority |
| Vineyard operating dates June 5–7, 2027; 30-seat motorcoach; included lunch Jun 6–7; tasting Jun 6; Standard vs Deluxe dinner as separate Items | Vineyard scenario |
| Celebrity O1 per-person components (USD): first/second fare $1,624.00; additional $406.00; NCCF $320.00; first/second discount −$150.00; additional discount −$37.50; taxes/fees/port $137.00 | [M3C scenario gate](m3c-cost-terms-and-forecasts.md#celebrity-beyond-cruise) |
| Optional excursion: $50.00 `unit_rate`, `minimum_quantity_shortfall` of five people (3 planned → shortfall $100.00) | [M3C scenario gate](m3c-cost-terms-and-forecasts.md#optional-excursion) |

### Illustrative planning assumptions (labeled test values)

Use only when the scenario document leaves commercial figures unresolved. Assertions must say **illustrative** / **M3C test value**, never “confirmed Supplier term.”

| Area | Rule |
| --- | --- |
| Hilton pre-stay hotel rates, additional-adult tax | M3C test values; formula-shape proof only |
| Port transfer fixed vehicle / person planning quantities | M3C test values |
| Vineyard fixed coach cost, per-person fees, hotel resource-night costs, 100% single supplement | M3C test values |
| Vineyard Standard / Deluxe dinner Supplier cost shapes | Separate Items; Client required-choice deferred to M4 |

### Shape-only / pending (no invention)

| Gap | Rule |
| --- | --- |
| Vineyard hotel sequence and nights (Hotel A / B ambiguity) | Shape-only; do not invent nights or properties into acceptance |
| Vineyard additional vehicle / stepped fixed-cost threshold | Unresolved; do not invent |
| Vineyard package price, Supplier rates, taxes/fees, minimum enrollment, deposits, cancellation deadlines | Unresolved; do not invent |
| Vineyard dinner independent capacity limits | Unresolved; do not invent |
| Client dinner choice, Holds, Allocations, Travelers, Obligations, Payments | Out of M3; assert absence |

Parent exit criterion 13 is enforced by this ledger.

## Scenario acceptance outline

### Celebrity Beyond (full Supplier journey)

M3F.2 must compose, with ledger labels:

1. Draft Departure and Arrangement structure (cruise Resource/cabin category, Hilton pre-stay Occurrences outside sailing dates, transfers, optional excursion).
2. Draft capacity, cost terms (O1 confirmed amounts; Hilton/transfer illustrative), deposit definitions ($50 + cumulative $500 Arrangement-wide), Deadline definitions, `names_assigned_to_supplier` milestone.
3. Activation while Departure is `active`; latch return-to-draft; Reservations and confirmations with exact-version provenance.
4. Confirmation-triggered and definition-shaped commitment openings; dispositions; exposure qualifications; Needs-attention rollup.
5. Capacity-consequence and Staff capacity paths as exercised by the journey.
6. Revisions / successor activation and ops resolution without inventing Client allocation.

Assert Arrangement-wide deposit and milestone semantics (assigning names for one cabin does not advance only that cabin’s deposit).

### Vineyard Tour

M3F.2 must compose:

1. 30-seat coach capacity (Traveler-position basis).
2. Fixed vs per-person cost shapes with **illustrative** amounts only.
3. Standard and Deluxe dinner as separate Supplier Items (Client dinner choice deferred to M4).
4. Activation / Reservation / commitment / Deadline / exposure path at Supplier-planning depth.
5. Every unresolved worksheet fact marked **shape-only / pending**; zero guessed acceptance amounts.

## Finding log template (M3F.2 → M3F.3)

Record each finding before M3F.3 remediates it. Substantial findings get a focused PR.

| Field | Content |
| --- | --- |
| ID | `M3F.2-FNN` |
| Title | Short name |
| Severity | blocker / high / medium / low |
| Command or surface | Named command, job, route, or UI |
| Invariant | Parent or ADR rule violated |
| Reproduction | Minimal steps or test reference |
| Ledger note | confirmed / illustrative / shape-only if scenario-related |
| Fixing PR | Link when closed |
| Evidence | Test / CI / EXPLAIN / screenshot note |

## Non-goals

M3F does **not**:

- Introduce Packages, Client prices/choices, Holds, Allocations, Travelers, Obligations, Payments, remittance, FX, or Travel Program.
- Add `per_source` Deadline cardinality (deferred).
- Reopen settled domain boundaries (Reservation ≠ Client allocation; Deposit Requirement ≠ Payment; forecast / qualified exposure / commitment remain distinct).
- Substitute M3E.7b Pass counts for the parent integrated Celebrity/Vineyard journey.
- Mark M3 complete before M3F.4 closes exit criterion 15.
- Invent unresolved Vineyard or Celebrity worksheet facts.

## Index updates on Accept

When this contract is Accepted:

1. Link this document from [`docs/README.md`](../README.md).
2. Amend the parent [M3F](m3-supplier-planning.md) row / acceptance note to point at this Accepted plan.
3. Keep roadmap and AGENTS at “M3 in progress” / M3F not complete until M3F.4.

Do **not** mark M3 complete in M3F.0.

## Compatibility notes

- M3F.2 composes M3A–M3E; it must not re-run M3E.7b solely for test count.
- Roadmap stays “M3 in progress” until M3F.4 closes exit item 15.
- Celebrity deposits/milestones remain Arrangement-wide for the duration of M3.

## Exit (M3F.0)

M3F.0 is Accepted when this document is merged with the index updates above. Production work begins at M3F.1 from the pinned base.
