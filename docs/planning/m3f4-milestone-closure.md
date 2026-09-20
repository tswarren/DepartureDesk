# M3F.4 — Milestone closure evidence

**Parent:** [m3-supplier-planning.md](m3-supplier-planning.md)  
**Contract:** [m3f-acceptance-and-hardening.md](m3f-acceptance-and-hardening.md)  
**Finding log:** [m3f3-finding-log.md](m3f3-finding-log.md)

M3 is complete when every parent exit criterion maps to shipped evidence. This index is the M3F.4 closure record.

## Exit criteria map

| # | Criterion | Evidence |
| --- | --- | --- |
| 1 | M3A–M3F accepted, implemented, merged, documented shipped | Slice plans shipped; this M3F contract + M3F.1–.4 implementation |
| 2 | Departure remains operational root; no Travel Program | `m3f3_hardening_gate_test` asserts no `travel_programs` table; AGENTS/architecture |
| 3 | Draft planning, activation rules, return-to-draft latch, immutable versions | `m3f2_integrated_scenario_journeys_test` draft block + activation latch |
| 4 | Distinct Arrangement / Item / Occurrence / Resource / Pool / Reservation / confirmation / terms / commitment / deposit / Deadline meanings | M3A–M3E shipped + M3F.2 composition |
| 5 | Contracting Supplier and Service Provider provenance | Shipped M3A/M3D; M3F.2 uses contracting Supplier graph |
| 6 | Capacity explicit, event-backed, rebuildable, race-safe, commitment-independent | M3B/M3D + Vineyard 30-seat Pool in M3F.2; M3E.7b race baseline |
| 7 | No Client Holds, Allocations, occupancy, or fulfillment | `m3f_assert_no_client_commercial_tables!` |
| 8 | Forecast one supported stage; explainable | M3C + M3F.2 O1/excursion/Vineyard forecasts |
| 9 | Commitments and deposits without payable or payment | M3F.2 Celebrity deposits; no `payments` table |
| 10 | Deadline workflow without automatic reminders | M3E.2 + M3F.2 informational Deadlines |
| 11 | Exposure always qualified; no fabricated Agency cash at risk | M3E.4 + M3F.2/M3F.3 forecast bands |
| 12 | Inactivation blockers and forced Administrator path | Shipped M3E.1 |
| 13 | Celebrity + Vineyard without subclasses or guessed facts | Fixture ledger + M3F.2 ledger-labeled assertions |
| 14 | Tenancy, auth, audit, idempotency, concurrency, performance, a11y, regression | M3F.1 viewports; M3F.3 hardening; M3E.7b baseline; CI |
| 15 | Documentation marks M3 complete and M4 next / unimplemented | This closure + README, roadmap, AGENTS, architecture, terminology updates |

## Documentation reconciled on close

- [`docs/README.md`](../README.md)
- [`docs/planning/roadmap.md`](roadmap.md)
- [`docs/planning/m3-supplier-planning.md`](m3-supplier-planning.md)
- [`docs/planning/m3f-acceptance-and-hardening.md`](m3f-acceptance-and-hardening.md)
- [`docs/architecture/current-state.md`](../architecture/current-state.md)
- [`docs/terminology.md`](../terminology.md)
- [`AGENTS.md`](../../AGENTS.md)
- [`docs/ui/interface-contract.md`](../ui/interface-contract.md) (no ahead-of-code claims)

## Next

M4 may treat M3 Supplier planning as the source foundation. Packages, Client prices/choices, Holds/Allocations, Obligations/Payments, Travel Program, remittance, and FX remain unimplemented until an accepted M4 slice plan names that work.
