# M3E.7b — Scenario and release-gate evidence

**Status:** Recorded for PR #108 tip after composite scenario hardening  
**Parent:** [M3E — Supplier operational control](m3e-supplier-operational-control.md)  
**Authority:** Exit criteria 19–20 and the M3E.7b slice gate

This index links every Accepted M3E.7b release-gate criterion to executable proof. Green CI on the tip confirms configured jobs; this table is the named-matrix evidence the gate requires.

## Composite scenario builders

| Scenario | Result | Evidence |
| --- | --- | --- |
| Celebrity Beyond: $50 + cumulative $500 → $450 remaining; March 11 fallback; `names_assigned_to_supplier` replaces unelapsed Deadline without duplicate commitment; Arrangement-wide (no cabin/traveler columns); rooming-list and legal-names Deadlines | Pass | `test/services/m3e7b_scenario_release_gate_test.rb` — Celebrity test; slice depth also in `test/services/m3e3_deposit_requirements_milestones_test.rb` |
| Hilton pre-stay: 15% aggregate percentage deposit; guaranteed-room commitment/exposure; future-effective option release recorded in advance; deposit adjustment appends; ending blocked while live governing state remains | Pass | `test/services/m3e7b_scenario_release_gate_test.rb` — Hilton test |
| Port transfers: `one_shared` materialization of final-count and schedule Deadlines; `per_source` rejected (deferred past M3E.2) | Pass | `test/services/m3e7b_scenario_release_gate_test.rb` — transfer test; materialization also in `test/services/m3e2_deadline_definitions_occurrences_test.rb` |
| Optional excursion: minimum-five contingent cost; cancellation-cutoff Deadline; contingent→guaranteed only via explicit qualify | Pass | `test/services/m3e7b_scenario_release_gate_test.rb` — excursion test; qualify also in `test/services/m3e4_qualified_exposure_test.rb` |
| Vineyard tour: fixed coach and per-person (`unit_rate`/`persons`) as separate exposure sources; bands not summed as separate liabilities; clean ending | Pass | `test/services/m3e7b_scenario_release_gate_test.rb` — vineyard test |

## Named race / replay / catch-up / rebuild matrix

| Criterion | Result | Evidence |
| --- | --- | --- |
| Disposition / evidence races and same-key replay | Pass | `test/services/m3e1a_commitment_disposition_concurrency_test.rb`; `test/services/m3e1b_evidence_coverage_concurrency_test.rb`; lifecycle replay in `m3e1a_commitment_lifecycle_test.rb` |
| Deposit attestation / milestone / successor replay | Pass | `test/services/m3e3_deposit_requirements_milestones_test.rb` |
| Exposure qualify / repair / drift equivalence | Pass | `test/services/m3e4_qualified_exposure_test.rb` |
| Deadline catch-up vs synchronous rebuild; no time-created domain events | Pass | `test/services/m3e2_deadline_definitions_occurrences_test.rb`; attention rebuild in `test/services/m3e5_needs_attention_catalog_test.rb` |
| Ending preview conflict, cascade rollback, same-key replay before expiry | Pass | `test/services/m3e6a_ending_preview_test.rb`; `test/services/m3e6b_atomic_ending_test.rb` |
| Idempotency composite same-Agency FKs; Deadline job retries (5) | Pass | `test/models/m3e5r_idempotency_composite_fk_constraints_test.rb`; Deadline job retry coverage under M3E.5R |

## Query, accessibility, responsive, CI

| Criterion | Result | Evidence |
| --- | --- | --- |
| Query bound / disposition list EXPLAIN | Pass | Bounded count in `m3e1a_commitment_lifecycle_test.rb`; EXPLAIN in `m3e7b_scenario_release_gate_test.rb` |
| Operational UI recovery (422, Viewer denial) | Pass | `test/controllers/m3e7a_ending_and_exposure_ui_request_test.rb` |
| Accessibility / responsive / keyboard | Pass (cross-slice) | M1/M2/M3D.0 system tests remain the viewport/keyboard proof surface (`test/system/m1_directory_accessibility_test.rb`, `m2_departure_accessibility_test.rb`, `m3d0_planning_workspace_test.rb`). M3E.7a recovers consequential forms; no separate M3E Chrome viewport matrix was added in Docker (local image lacks Chrome; CI `system-test` remains blocking). |
| Reservation partial-response disclosure | Pass | M3D remediation system coverage under the disclosure Stimulus controller tests |
| Lint / security / full CI | Pass on tip | GitHub Actions on PR #108 — `lint`, `test`, `system-test`, `scan_ruby`, `scan_js` |

## Documentation reconciliation

| Deliverable | Result | Evidence |
| --- | --- | --- |
| Interface contract for shipped operational and ending surfaces | Pass | [`docs/ui/interface-contract.md`](../ui/interface-contract.md) Departures / Arrangement operational sections |
| Plan, ADR 0013, decision register, roadmap, docs index, AGENTS | Pass | Marked Shipped only with this evidence index linked from the M3E.7b slice |
| Later commercial non-goals preserved | Pass | Client demand, Travelers, Obligations, Payments, remittance, FX, M3F remain unimplemented; Celebrity deposits/milestones Arrangement-wide; `per_source` Deadlines deferred |

## Limitations (accepted product boundaries)

- Celebrity cumulative deposit and `names_assigned_to_supplier` remain **Arrangement-wide**; per-cabin advancement is out of M3E.
- Deadline cardinality ships **`one_shared` only**; `per_source` is rejected until a later accepted slice expands materialization.
- M3E.7b does not re-implement M0–M3D regression; CI runs the full suite including those suites.
- M3F still owns milestone-wide M3A–M3E acceptance and the supplier-planning task-flow backlog.

## Commands

```bash
./dev/rails-docker bin/rails test test/services/m3e7b_scenario_release_gate_test.rb
./dev/rails-docker bin/rails test
```
