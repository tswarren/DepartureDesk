# Phase 1 spike: hold and reserve on the existing capacity pools

**Status:** Complete 2026-11-03. Findings accepted and recorded as the [ADR 0018 spike amendment](../../adr/0018-arrangement-history-by-dated-adjustment.md#spike-amendment-2026-11-03). Timebox: 3 working days. Spike code is throwaway: it lives on the `spike/hold-and-reserve` branch and is not merged. Only this document's findings and the ADR 0018 amendment they produce are kept.

**Reads with:** [first-slice charter](first-slice-charter.md) Phase 1, [ADR 0018](../../adr/0018-arrangement-history-by-dated-adjustment.md) "Left to the spike", [ADR 0010](../../adr/0010-supplier-capacity-ledger-and-projection.md), [Slice 1 data model](slice-1-data-model.md).

## Questions the spike answers

| ID | Question | Source |
| --- | --- | --- |
| Q1 | Is the shipped `CapacityEvent`, projection and reconciliation code adapted (by removing version provenance) or replaced? | ADR 0018, D-66 |
| Q2 | Do holds and allocations share the capacity event table, or have their own table on the same timeline? | ADR 0018 |
| Q3 | When does a date-only capacity adjustment take effect, and in which zone? | ADR 0018 |

## Decision rule

Implement hold, then Reserved allocation, then release, against the existing capacity pools (INV-17 to INV-24, BKG-09, BKG-10).

- **It fits without changing the capacity triggers or the arrangement-version topology:** adapt the ledger. Removing version provenance becomes the adaptation work in Slice 1 step 3.
- **It needs changes to either:** replace the ledger with a new one written to ADR 0018.

## What the spike builds

- A `spike_inventory_allocations` table: pool, holder, quantity, state (Held, Reserved, Released), hold expiry. It has its own table, beside the capacity events, which is the first answer Q2 tests.
- Commands: hold, reserve, release, all locking the pool row so allocations and supply events serialize.
- A pool availability read: supplier capacity from the existing projection, less active allocations. A hold past its expiry stops counting at once, with no job needed. A capacity conflict is derived when allocations exceed supply (D-06), never stored.
- Service tests for each case below.

Out of scope: bookings, prices, shells, screens, notifications and composite foreign keys.

## Cases

| Case | Expectation |
| --- | --- |
| S1 | A hold reduces availability; capacity events and the supply projection are untouched |
| S2 | A hold beyond availability is refused |
| S3 | A hold past its expiry frees capacity at once and cannot be reserved |
| S4 | A Reserved allocation keeps its capacity after the hold time passes |
| S5 | Releasing returns capacity |
| S6 | A supplier withdrawal below current allocations still records, and availability reports a capacity conflict |
| S7 | Holds on a pool without numeric inventory (on request, externally managed) are refused |
| S8 | Two holds racing for the last units: exactly one succeeds (non-transactional test). S8b: a supplier withdrawal racing a hold waits, then records with a conflict |

## Plan

1. **Day 1:** table, commands, availability read and cases S1 to S7.
2. **Day 2:** S8 under real concurrency; trace what version provenance the shipped event, projection and reconciliation code depends on, and what removing it touches; answer Q3 from the shipped effective-date rules.
3. **Day 3:** write findings and the recommendation below, and draft the ADR 0018 amendment.

## Findings

Recorded 2026-11-03. All nine cases pass: S1 to S7 in `test/services/spike_hold_and_reserve_test.rb` (7 runs, 23 assertions) and S8 in `test/services/spike_hold_and_reserve_concurrency_test.rb` (2 runs, 11 assertions). The concurrency file also covers S8b: a supplier withdrawal racing an open hold waits on the pool lock, then records with a capacity conflict.

### Q2: own table (answered by S1 to S8)

Holds and allocations work in their own table with no change to any existing table, trigger or service. Availability is supply from the projection less the allocations that consume now (Reserved, or Held with an expiry still ahead), read under the pool row lock. That is the "same timeline" INV-26 asks for: one lock orders supply events and allocation changes, so no reader sees one without the other.

A shared table would not fit. Capacity events are append-only, positive supply magnitudes, and the `reject_capacity_event_mutation` and `reject_nonnumeric_capacity_event` triggers enforce this. An allocation has a lifecycle (Held, Reserved, Released) and an expiry. Putting it in the event table would mean either relaxing those triggers or modelling each transition as an event and replaying them for every availability read.

**Recommendation:** an allocations table beside the capacity events. Each transition sets its own timestamp once (`held_at`, `reserved_at`, `released_at`) and is never cleared. A trigger allows only forward moves (Held to Reserved, Held or Reserved to Released), so the history stays append-only in effect. A hold past its expiry stops counting at read time, with no job and no event, which keeps the ADR 0010 rule that a date passing never creates an event.

### Q1: adapt the engine, recreate the tables

By the decision rule this is **adapt**. Holds fit without touching the capacity triggers or the version topology. What depends on version provenance:

| Shipped code or schema | Version dependence | Slice 1 treatment |
| --- | --- | --- |
| `CapacityTimelineReplay` (65 lines) | None | Keep as is: event types, directions, nonnegative replay, single establishment |
| `CapacityProjectionRefresher` (55 lines) | None | Keep: current and next supply from `applies_at` |
| `RebuildCapacityProjection`, `RefreshDueCapacityProjection` | 2 and 3 references | Keep, dropping the version lookups |
| `ReconcileCapacityPool` (123 lines) | 7 references; `capacity_reconciliations.supplier_arrangement_version_id` is NOT NULL with a foreign key | Keep the observation model; drop the version column |
| `CapacityCommandSupport` (1,110 lines) | 50 references; `ensure_activated_capacity_graph!`; an eight-row lock chain through the activated version | Rewrite to a short lock order (Departure, then arrangement, then pool last); keep idempotency keys and the projection `lock_version` check |
| `capacity_events` | NOT NULL `supplier_arrangement_version_id`, composite foreign key `capacity_events_version_fk`, unique `index_capacity_events_on_version_owner` | Recreate without version columns |
| `supplier_confirmation_capacity_event_links` | Foreign key through the event's version | Dropped with M3/M4; confirmation links the opening event directly |
| Pool key and mode | Pool keyed by item, occurrence and resource; modes `block`, `allotment`, `on_request`, `externally_managed`; per-version `capacity_pool_definitions` | Recreate the pool keyed to the inventory group, with the availability promise (SUP-15) in place of the mode |

The capacity tables are dropped with the M3/M4 layers anyway (D-66). So the adaptation is: keep the engine classes and their rules, and recreate the tables to ADR 0018 in the Slice 1 step 3 migration, carrying over the trigger functions that still apply (append-only events and reconciliations, nonnumeric refusal, valid zone, owner change). This is cheaper and safer than writing a new engine, because the replay and projection code holds the subtle ordering rules and has no version dependence.

### Q3: end of the effective date, in the agency's zone

The shipped rule (`resolve_capacity_applies_at`): an adjustment dated on or before the local recording date applies at once, at `recorded_at`. One dated later applies at the end of its effective date, which is midnight starting the next day in the pool's IANA zone. The pool copies that zone from its service occurrence.

**Recommendation:** keep "end of the effective date", but use the agency's zone instead of the pool's, and snapshot it on the event (`effective_time_zone`, as today). A supplier release dated Nov 15 then returns the space at the same moment the SET-10 deadline ends (11:59 p.m. agency time), so a deadline task and the capacity change agree. The snapshot keeps past events fixed if the agency's zone later changes. Pools no longer have occurrences to take a zone from in the new model, so this also removes a dependency.

### Gaps the spike found (Slice 1 work)

- **Agency-initiated reductions don't check allocations.** `ReleaseCapacity` and `CorrectCapacityDown` replay supply only. INV-27 requires an agency-initiated reduction below active allocations to be refused. A supplier withdrawal records and shows a conflict, as S6 and S8b do. Because supply commands lock the pool row, the check is race-free once added.
- **New holds should check future supply.** Spike availability uses current supply only, so a hold can be taken now against units a future-dated release will remove. A hold should be checked against the lowest scheduled supply from now on, which the projection's next-event pointer or a replay can provide.
- **Lock order.** Supply commands lock the pool last and holds lock only the pool, so they serialize with no deadlock (S8b). Slice 1 keeps the rule "pool row last" for every command that touches capacity.

### Recommendation for the ADR 0018 amendment

1. Adapt: keep the replay, projection, rebuild and reconciliation code; rewrite command support; recreate the capacity tables without version provenance in Slice 1 step 3.
2. Holds and allocations get their own table, serialized with supply by the pool row lock, with forward-only transitions.
3. A future-dated adjustment applies at the end of its effective date in the agency's zone, snapshotted on the event.
