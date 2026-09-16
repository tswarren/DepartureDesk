# M2B — Departed lifecycle

**Status:** Draft. Not implementation authority.

**Parent:** [M2 — Departure core](m2-departure-core.md). The parent status line must read Accepted.

**Prerequisites:** [M2A](m2a-departure-core.md) shipped and merged; parent M2; ADR 0001, ADR 0004, ADR 0005, ADR 0006, current architecture, and interface contract.

This slice adds the date-based departed transition, the first application Solid Queue jobs, and the correction commands. It does not reopen M2A persistence, reference issuance, search, or Travel Program deferral.

## Goal

Mark an eligible active Departure departed, do that work from both a Staff action and a scheduled sweep, and correct schedule, currency, and an erroneous departed status without inventing closeout or cancellation.

## In scope

* `MarkDepartureDeparted` as the sole departed-transition command
* Manual confirmation and `POST` departed
* `MarkEligibleDeparturesDepartedJob` hourly sweep
* `MarkDepartureDepartedJob` per Agency/Departure pair
* `CorrectDepartureSchedule`, `CorrectDepartureCurrency`, `CorrectDepartureLifecycle`
* M2B audit actions
* Job and departed-transition concurrency

## Out of scope

* Travel Program
* Changing the `departures` status catalog, reference namespace, or M2A columns except writing `status`, `departed_at`, schedule, and currency through the commands above
* Closeout, `closed`, `reopened`, Cancellation Case, money amounts, FX, Arrangements, Packages, Client Trips
* New permissions
* Duplicate gate, destroy, archive
* Parent-acceptance ADR/MVP/roadmap/terminology amendments
* `M2DepartureScenario` (M2C)
* Queue tables on the primary database

## Locked boundaries

1. Eligibility is the Departure’s stored `starts_on` against the current local date in `time_zone`, not UTC midnight and not `ends_on`.
2. `MarkDepartureDeparted` is idempotent. A retry of an already-departed record returns success and writes no second `departure.departed` audit.
3. The sweep selects identifiers and enqueues. It does not call the command. It is a bounded candidate selector, not a loader of every eligible Departure.
4. The per-Departure job reloads Agency then Departure, calls the command, and never depends on `Current`.
5. System invocation is explicit. Do not treat `actor: nil` as trusted system execution. The job calls `MarkDepartureDeparted.call(agency:, departure:, actor_kind: :system, actor_identifier: "departures.mark_departed")`. Do not invent a platform user. `agency.provisioned` already uses `actor_kind: system`.
6. The sweep and child jobs use the Solid Queue queue named `departures`. Solid Queue stays on the queue database.
7. Skip suspended and closed Agencies in the sweep.
8. `CorrectDepartureLifecycle` never follows from editing `starts_on`.
9. `CorrectDepartureLifecycle` may return `departed → active` only when stored `starts_on` is **later than** the current local date in `time_zone`. Equality with today is invalid.
10. Lifecycle and correction mutations use `POST`. Ordinary name/description edits remain M2A `PATCH` `UpdateDeparture`.
11. After authorization, Agency scoping, and pessimistic row locking, if the Departure is already `departed`, `MarkDepartureDeparted` returns success before comparing `lock_version`. Write no audit and make no change. Ordinary correction no-ops still check `lock_version`. Absence of `lock_version` on the system path does not mean absence of a pessimistic lock.

## Job cadence

Register `MarkEligibleDeparturesDepartedJob` in [`config/recurring.yml`](../../config/recurring.yml) as an hourly recurring task on queue `departures` for environments that run Solid Queue (`production` and `development`).

Eligibility uses the Departure time zone:

```sql
status = 'active'
AND starts_on <= (CURRENT_TIMESTAMP AT TIME ZONE time_zone)::date
```

Hourly is sufficient because the unit of eligibility is a local calendar date. Do not claim intra-hour precision.

The sweep must:

* enumerate active Agencies, then eligible Departures, with keyset or batch pagination
* enqueue in bounded batches (at most 100 identifiers per batch)
* use deterministic order: `agency_id`, `starts_on`, `id`
* never load the entire candidate set into memory
* rely on a supporting index; M2C asserts the sweep query plan
* not recheck eligibility beyond selection; the per-Departure command rechecks the exact local-date predicate after locking Agency then Departure

The per-Departure command remains the authority. The sweep only selects candidates.

## Jobs

There is no `app/jobs` tree yet. Add:

| Class | Queue | Responsibility |
| --- | --- | --- |
| `ApplicationJob` | — | Rails 8 Active Job base; queue adapter remains Solid Queue |
| `MarkEligibleDeparturesDepartedJob` | `departures` | Bounded sweep: select eligible `(agency_id, departure_id)` pairs and enqueue `MarkDepartureDepartedJob` |
| `MarkDepartureDepartedJob` | `departures` | Arguments: `agency_id`, `departure_id`. Reload Agency, reload Departure through that Agency, call `MarkDepartureDeparted.call(agency:, departure:, actor_kind: :system, actor_identifier: "departures.mark_departed")` |

Jobs pass identifiers, not Active Record objects. If the Departure is missing, other-agency, or the Agency is no longer active, complete without calling the command and without a domain audit. Do not raise `ActiveRecord::RecordNotFound` as an unbounded retry loop; discard or finish.

Retry deadlocks/serialization failures. Do not retry `AgencyCommand::Error` with `invalid`, `invalid_state`, `unauthorized`, or `conflict` by endlessly re-enqueueing; those are terminal for that run. Already-departed is success inside the command.

Independent retry: one Departure’s failure does not block others.

## Domain error codes

Same catalog as M2A: `unauthorized`, `invalid`, `invalid_state`, `conflict`, `not_found`, `reference_exhausted`.

M2B does not issue references. `reference_exhausted` is unused here.

| Situation | Code |
| --- | --- |
| Viewer or missing `manage_departures` | `unauthorized` |
| Inactive Agency on a user-invoked command | `invalid_state` |
| Stale `lock_version` on a user-invoked command | `conflict` |
| Manual departed while not eligible | `invalid_state` |
| Correction with blank reason or invalid dates/zone/currency | `invalid` |
| `CorrectDepartureLifecycle` when `starts_on` is today or past | `invalid_state` |
| Correction or departed against the wrong starting status | `invalid_state` |
| Missing Departure for a user request | HTTP 404; command `not_found` if invoked with a foreign id |

System-actor `MarkDepartureDeparted` does not take `lock_version`. User-actor `MarkDepartureDeparted` requires current `lock_version` except on already-departed replay. Both paths lock Agency then Departure.

## Commands

Lock order: Agency, Departure, then referenced Office and AgencyUser only if a correction touches them (schedule/currency/lifecycle do not reassign responsibility). Do not lock `ReferenceSequence`. Absence of `lock_version` on the system path does not skip pessimistic locking.

### `MarkDepartureDeparted`

Idempotent date-based transition.

User path: `actor_kind: :agency_user` (or the existing AgencyUser actor argument used by other commands), `manage_departures`, active Agency, current `lock_version` unless already departed.

System path:

```ruby
MarkDepartureDeparted.call(
  agency:,
  departure:,
  actor_kind: :system,
  actor_identifier: "departures.mark_departed"
)
```

Do not infer system execution from `actor: nil`.

Lock Agency, then Departure. Recheck the exact local-date predicate under that lock. Eligible when `status = active` and local today in `time_zone` is on or after `starts_on`.

After locking, if already `departed`, return success before comparing `lock_version`. Write no audit and do not change `departed_at`. An HTTP or job retry may carry a stale `lock_version`.

`draft`: `invalid_state` for a user. A job should not select drafts; if it races to draft, finish as a no-op without audit.

Ineligible active (starts in the future): user gets `invalid_state`. Job no-ops without audit if a race moved `starts_on`.

Success of a real transition: `status: departed`, set `departed_at`, write `departure.departed`. No financial, capacity, fulfillment, or closeout side effects.

### `CorrectDepartureSchedule`

Permission: `manage_departures`. Starting status `departed`. Requires `lock_version` and reason 1–500 characters.

Updates `starts_on`, `ends_on`, and/or `time_zone` with the same pairing and catalog rules as M2A. Does not change status or `departed_at`. Does not activate.

Same values: no-op without another audit. Success writes `departure.schedule_corrected` including the reason.

### `CorrectDepartureCurrency`

Permission: `manage_departures`. Starting status `departed`. Requires `lock_version` and reason 1–500 characters.

Updates `operating_currency` to a valid ISO code via `Money::Currency.find`. Does not change status.

M2 has no currency-dependent downstream history. M3 must extend this command before Arrangement costs exist; until then the change is allowed with reason.

Same currency: no-op without another audit. Success writes `departure.currency_corrected`.

Active currency changes remain `UpdateDeparture` from M2A, not this command.

### `CorrectDepartureLifecycle`

Permission: `manage_departures`. Starting status `departed`. Requires `lock_version` and reason 1–500 characters.

Allowed only when stored `starts_on` is later than the current local date in stored `time_zone` (after any same-request schedule correction has been persisted, this command reads the stored row; it does not accept a speculative future date in the same payload as a substitute for `CorrectDepartureSchedule`).

If the date has already arrived, `invalid_state`. Staff must not un-depart a sailing that would be immediately re-departed.

Success: `status: active`, `departed_at` cleared, reference and `first_activated_at` preserved, `departure.lifecycle_corrected`.

Never implied by `UpdateDeparture` or `CorrectDepartureSchedule`.

## Audit

Add only these actions, in the same change as first write:

* `departure.departed`
* `departure.schedule_corrected`
* `departure.currency_corrected`
* `departure.lifecycle_corrected`

Scheduled departed events use `actor_kind: system` and `actor_identifier` `departures.mark_departed`. Manual events use the AgencyUser. `Departure` is already an allowed subject from M2A.

## Routes and UI

Add only:

```text
GET    /departures/:id/departed                new_departure_departed_path
POST   /departures/:id/departed                departure_departed_path
GET    /departures/:id/schedule/correction     edit_departure_schedule_correction_path
POST   /departures/:id/schedule/correction     departure_schedule_correction_path
GET    /departures/:id/currency/correction     edit_departure_currency_correction_path
POST   /departures/:id/currency/correction     departure_currency_correction_path
GET    /departures/:id/lifecycle/correction    edit_departure_lifecycle_correction_path
POST   /departures/:id/lifecycle/correction    departure_lifecycle_correction_path
```

GET pages are focused confirmations. POST performs the command. Reuse `#form-error-summary`. Preserve submitted values on error.

Show departed actions only when eligible. Show lifecycle correction only when `starts_on` is still in the future. Do not add empty M3 panels or Travel Programs navigation.

Name and description on a departed Departure continue to use M2A `PATCH` `/departures/:id`.

## Tests

* Eligibility by local date, including a zone west of UTC where local date differs from UTC date
* Manual departed, job departed, idempotent retry, one audit
* Sweep skips suspended/closed Agencies, enumerates in bounded batches, does not load the full candidate set, and does not call the command
* Job reloads through Agency, ignores `Current`, uses `actor_kind: :system`, discards missing/foreign ids, and uses queue `departures`
* Recurring configuration points at the sweep job; jobs use the queue connection
* Already-departed replay succeeds with a stale `lock_version`; correction no-ops still require a current `lock_version`
* Schedule, currency, and lifecycle corrections: success, invalid, unauthorized, stale, wrong status, date rule
* Lifecycle correction does not run as a side effect of schedule correction
* Genuine multi-connection races; re-raise unexpected exceptions; accept only Result or documented codes:

  | Race | Required outcome |
  | --- | --- |
  | Return to draft versus departed transition | One valid lifecycle outcome |
  | Scheduled job and manual departed | One transition and one audit |
  | Two per-Departure jobs for the same Departure | One transition and one audit |
  | Lifecycle correction versus departed job | One valid lifecycle outcome |

* Request/system: confirmation surfaces, Viewer rejection, cross-Agency 404

Do not weaken M2A or M1 tests.

## When this slice ships

Update `AGENTS.md` for the first scheduled lifecycle job (identifiers, reload through Agency, explicit system invocation, queue `departures`, queue database). Mention departed and correction commands in current architecture and the interface contract. Do not mark M2 complete.

While the implementation PR is open, describe those updates as implemented on the branch. Mark the slice **Shipped** in a post-merge documentation commit.

## Exit gate

M2B is complete only when:

* Manual and scheduled departed paths share `MarkDepartureDeparted`
* Sweep and per-Departure jobs fail closed, skip inactive Agencies, and enqueue in bounded batches
* Corrections and the four M2B races pass
* No closeout or cancellation state is persisted
* M0, M1, and M2A remain green
* The slice is merged to `main`

This slice authorizes M2B only. It does not authorize M2C, M3, or Travel Program.
