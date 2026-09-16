# M2C — Acceptance and hardening

**Status:** Draft. Not implementation authority.

**Parent:** [M2 — Departure core](m2-departure-core.md). The parent status line must read Accepted.

**Prerequisites:** [M2A](m2a-departure-core.md) and [M2B](m2b-departed-lifecycle.md) shipped and merged; parent M2 Accepted, including ADR 0007, the ADR 0004 Departure reference amendment, and the MVP, roadmap, and terminology Travel Program deferral; full CI green.

M2C is proof and hardening only. It does not authorize any new domain model, permission, reference namespace, ranking kind, duplicate signal, or lifecycle behavior.

## Goal

Prove that M2A and M2B work together as one secure, performant, accessible milestone, represent both reference-scenario shells without Travel Program or M3 records, and mark M2 complete.

## In scope

* `M2DepartureScenario` composing `M1DirectoryScenario`
* Celebrity Beyond and Vineyard Tour Departure shells
* Cross-Agency isolation proof spanning commands, routes, search, jobs, and audit
* Composed-search `EXPLAIN`, 50/51 cap, and bounded query counts
* Keyboard, drawer, `#form-error-summary`, representative Tab order, visible focus, and four viewport widths
* Empty and filtered-empty states
* M0/M1/M2A/M2B regression
* Index-only forward migration only when composed search or sweep `EXPLAIN` proves a missing index
* Final M2 documentation after proof is green and merged

## Out of scope

* New aggregate, table, column, extension, permission, audit action, or reference namespace. M2C may add indexes to existing M2 tables only when composed-query or sweep-query `EXPLAIN` proves they are needed. It may not add tables, columns, extensions, reference namespaces, or additional `btree_gist` uses.
* Travel Program
* Invented people, hotels, Suppliers, or operating facts in [docs/scenarios/celebrity-beyond-2027.md](../scenarios/celebrity-beyond-2027.md) or [docs/scenarios/vineyard-tour-2027.md](../scenarios/vineyard-tour-2027.md)
* Adding Departure fields to the M1 scenario result object
* Making M1 tests aware of Departure
* Closeout, cancellation, Packages, Client Trips, Arrangements, money amounts
* An invented `m3-*.md` slice plan
* Redesign of `#form-error-summary` unless proof fails
* Completing parent-acceptance ADR, MVP, roadmap, or terminology work. Those authorities must already be accepted. M2C verifies they remain consistent.

## Locked boundaries

* Scenario builders exist only under `test/`. They are not production services or development seeds.
* Build Departures through shipped commands.
* Fixture-only currency, time zone, Office, and responsible-user facts live on `M2DepartureScenario` and must be labeled as fixture-only. They are not claims that the accepted scenario documents specified them.
* Search-plan assertions run against the final ranked, filtered, ordered, and capped relation, not isolated scopes.
* Sweep-query plan assertions run against the bounded candidate selector, not an unbounded `Agency.all` load.
* Race helpers continue to re-raise unexpected exceptions.
* Reuse the shipped error-summary controller and 375px drawer contract.
* Representative Tab traversal on ordinary Departure index/filter and new/edit forms; do not Tab through every step of the full create-activate scenario. The drawer test already covers Tab containment.
* `enable_seqscan = off` for EXPLAIN eligibility, matching M1E.

## Test helper

Add `test/test_helpers/m2_departure_scenario.rb`.

```text
M2DepartureScenario.celebrity(suffix:)
M2DepartureScenario.vineyard(suffix:)
```

Each method calls the corresponding `M1DirectoryScenario` builder and returns an M2 result object that **holds** the M1 result plus Departure handles. Do not add Departure attributes to `M1DirectoryScenario::Result`.

The helper must:

* compose uniqueness from the M1 helper (workspace codes, emails, and other collision-sensitive values use the M1 suffix)
* copy the M1 Agency’s `default_currency` as the Departure `operating_currency`
* select an M1 Office and copy that Office’s `default_timezone` as the Departure `time_zone`
* use the M1 actor as the responsible AgencyUser unless a test explicitly assigns another same-Agency user
* label currency, time zone, Office, and responsible user as fixture-only facts, not scenario-document claims
* use stable Departure names and dates: Celebrity Beyond, 10–17 November 2027; Vineyard Tour, 5–7 June 2027
* create Departures through shipped commands

Do not add invented Client People, hotels, or Suppliers. Directory records already created by M1 remain unused as trip attachments; M2 must not create Supplier, Package, or Client Trip rows.

`M2DepartureScenario.cleanup!` must delete Departure records for that Agency before delegating to `M1DirectoryScenario` cleanup. It must support both transactional tests and genuine multi-connection tests (`use_transactional_tests = false`). Never print credentials.

## Required proof

### Scenario shells

* Celebrity Beyond Departure dated 10–17 November 2027, independent of Vineyard Tour dated 5–7 June 2027
* No Travel Program row, route, model, or foreign key
* No M3–M8 records created by the helper
* Draft incomplete and unreferenced; activation issues one `D-` reference; return to draft retains it; reactivation does not consume another
* Viewer browses and cannot mutate

### Search and queries

Every supported branch on `SearchDepartures.composed_relation`:

* exact reference
* exact name
* prefix name
* blank browse
* status `draft`, `active`, `departed`, `all`
* responsible Office filter
* responsible AgencyUser filter
* inclusive `starts_on` and `ends_on` ranges
* mixed ordering/cap: 51+ rows, fetch 51, return 50, `truncated`
* deterministic order: `starts_on` ASC NULLS LAST, `name_search_key`, `id`
* exact reference remains highest rank

`EXPLAIN` must show an appropriate index on that composed relation. Assert the scheduled sweep candidate-selector plan the same way, with `enable_seqscan = off`.

M2C may add indexes to existing M2 tables only when composed-query or sweep-query `EXPLAIN` proves they are needed. It may not add tables, columns, extensions, reference namespaces, or additional `btree_gist` uses.

Query counts: Departure index and profile must not grow with unrelated directory volume; list/search stay bounded as Departure count grows from a small N to a larger N (mirror M1E’s 5 vs 50 pattern).

### Isolation, jobs, accessibility

* Cross-Agency Office, AgencyUser, Departure, search, route, command, job, and audit isolation; other-agency ids are not found
* Sweep still skips inactive Agencies and remains a bounded selector
* Parent ADR 0007, ADR 0004 Departure namespace, MVP Travel Program deferral, roadmap, and terminology remain consistent with shipped M2. Do not complete those documents retroactively.
* Keyboard operation; focus after errors via `#form-error-summary` including a field-link `focus()` assertion (do not weaken to URL hash)
* Representative Tab order and visible focus ring on Departure filter/new form
* Drawer contract at 375px
* Responsive list/profile/forms at the four shipped widths
* Empty index and filtered-empty index
* Full CI, Tailwind, lint, and security green

### Concurrency

Do not re-specify M2A/M2B races. They remain regression requirements. The harness must still re-raise unexpected exceptions.

## Documentation when proof is green

While the M2C implementation PR is open, describe documentation updates as implemented on the branch. Mark slices and the parent **Shipped** / **Complete** in a post-merge documentation commit. Do not state that M2 is already shipped while that PR remains unmerged.

When proof is green and merged, update:

* [docs/planning/m2c-acceptance-and-hardening.md](m2c-acceptance-and-hardening.md) — Shipped
* [docs/planning/m2b-departed-lifecycle.md](m2b-departed-lifecycle.md) and [docs/planning/m2a-departure-core.md](m2a-departure-core.md) — Shipped
* [docs/planning/m2-departure-core.md](m2-departure-core.md) — M2 Complete
* [docs/planning/roadmap.md](roadmap.md) — M2 Complete; M3 Supplier planning next and unimplemented
* [docs/architecture/current-state.md](../architecture/current-state.md)
* [docs/ui/interface-contract.md](../ui/interface-contract.md)
* [docs/terminology.md](../terminology.md)
* [docs/README.md](../README.md)
* [README.md](../../README.md)
* [AGENTS.md](../../AGENTS.md)

Do not rewrite Celebrity/Vineyard scenario documents with guessed currency, zone, Office, or user facts.

Do not invent `docs/planning/m3-supplier-planning.md` or similar. M3 waits for its own accepted slice plan.

## Exit gate

M2 is complete only when:

1. This slice is accepted, implemented, and merged.
2. Both shells pass without Travel Program or M3 records.
3. Search, query-count, accessibility, tenancy, job, and regression proofs pass.
4. M0, M1, M2A, and M2B remain green.
5. Documentation marks M2 complete and M3 unimplemented.
6. No Party, Travel Program table, Office authorization, or duplicate gate has appeared.

This slice authorizes M2C proof only. It does not authorize M3, Travel Program, offers, Client Trips, capacity, financials, cancellation, documents, or closeout.
