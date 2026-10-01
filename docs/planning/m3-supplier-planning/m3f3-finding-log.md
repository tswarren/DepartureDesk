# M3F.3 — Finding log and hardening

**Parent contract:** [m3f-acceptance-and-hardening.md](m3f-acceptance-and-hardening.md)  
**Source journeys:** `test/services/m3f2_integrated_scenario_journeys_test.rb`

## Finding log (M3F.2 → M3F.3)

| ID | Title | Severity | Command / surface | Invariant | Reproduction | Ledger | Fixing PR | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| — | No release-blocking findings from M3F.2 integrated journeys | — | Celebrity + Vineyard composition | Parent exit 13–14 | M3F.2 green 2026-09-20 | n/a | n/a | `m3f2_integrated_scenario_journeys_test.rb` |

Template for any later finding:

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

## Hardening performed under M3F.3

With an empty blocker log, M3F.3 still closes parent exit criterion 14 proof gaps that M3F.2 ownership assigned to hardening:

1. **Cross-Agency isolation** — other-Agency Arrangement identifiers remain invisible (`m3f3_hardening_gate_test.rb`).
2. **No Client commercial tables** — Holds / Allocations / Travelers / Obligations / Payments absent.
3. **Exposure rebuild equivalence** — Arrangement exposure rebuild preserves qualified forecast totals for the Vineyard illustrative composition.
4. **Regression** — M3F.1 preload and M3F.2 journeys remain green; CI lint/security/Tailwind required on merge.

M3E.7b continues to own slice-local race/`EXPLAIN` matrices as baseline; M3F.3 does not re-count those tests.

## Exit

M3F.3 is complete when this log is published, the hardening tests are green, and no unmatched blocker remains before M3F.4 documentation closure.
