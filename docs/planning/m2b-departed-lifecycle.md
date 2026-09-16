# M2B — Departed lifecycle

**Status:** Accepted. Implemented on this branch; mark Shipped after merge to `main`. This slice is not yet shipped.

**Parent:** [M2 — Departure core](m2-departure-core.md). The parent status line must read Accepted. This slice plan is not implementation authority while it remains Draft, and it cannot become implementation authority if the parent returns to Draft.

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
* A Departure schema migration or status/reference catalog change. Writing `status`, `departed_at`, schedule, and currency through the commands above is in scope. The audit action catalog does change.
* Closeout, `closed`, `reopened`, Cancellation Case, money amounts, FX, Arrangements, Packages, Client Trips
* New permissions
* Duplicate gate, destroy, archive
* Parent-acceptance ADR/MVP/roadmap/terminology amendments
* `M2DepartureScenario` (M2C)
* Queue tables on the primary database
* A new sweep index; M2C owns sweep `EXPLAIN`

## Locked boundaries

1. Eligibility is the Departure’s stored `starts_on` against the local date in `time_zone` at one captured instant, not UTC midnight and not `ends_on`.
2. `MarkDepartureDeparted` is idempotent. A retry of an already-departed record returns success and writes no second `departure.departed` audit.
3. The sweep selects identifiers and enqueues. It does not call the command. It is a bounded candidate selector, not a loader of every eligible Departure.
4. The per-Departure job reloads Agency then Departure, calls the command, and never depends on `Current`.
5. System invocation is explicit. Do not treat `actor: nil` as trusted system execution. Do not invent a platform user. The system identifier is exactly `departures.mark_departed`. No controller exposes the system invocation.
6. The sweep and child jobs use the Solid Queue queue named `departures`. Solid Queue stays on the queue database.
7. Skip suspended and closed Agencies in the sweep.
8. `CorrectDepartureLifecycle` never follows from editing `starts_on`.
9. `CorrectDepartureLifecycle` may return `departed → active` only when stored `starts_on` is **later than** the local date in `time_zone` at the captured instant. Equality with today is invalid.
10. Lifecycle and correction mutations use `POST`. Ordinary name/description edits remain M2A `PATCH` `UpdateDeparture`.
11. After authorization, Agency scoping, and pessimistic row locking, if the Departure is already `departed`, `MarkDepartureDeparted` returns success before comparing `lock_version`. Write no audit and make no change. Ordinary correction no-ops still check `lock_version` and require a valid reason. Absence of `lock_version` on the system path does not mean absence of a pessimistic lock.

Lock order matches M2A: lock Agency, recheck that the locked Agency is active, then (user path) reload the actor through that Agency and recheck permission, then lock Departure. The system path skips actor/permission and forbids `lock_version`, but still pessimistic-locks Agency then Departure. Do not lock `ReferenceSequence`. Schedule, currency, and lifecycle corrections do not reassign responsibility.

## Cross-database delivery

The sweep reads the primary database and enqueues into the separate Solid Queue database. There is deliberately no transaction spanning both.

* Delivery is at least once, not exactly once.
* Do not wrap the entire sweep in a primary-database transaction.
* Each batch plucks at most 100 identifier pairs and then enqueues child jobs.
* Keyset pagination uses the last `(agency_id, starts_on, id)` tuple, not offset pagination.
* A crash may duplicate an enqueue; child-command idempotency absorbs it.
* A crash before enqueue may delay a record until the next hourly sweep.
* No queue record is treated as proof that a domain transition occurred.
* Only the primary transaction containing Departure and AuditEvent changes is authoritative.

## Clock

Shared, parameterized helpers on `Departure`:

* `local_date(at:)`
* `eligible_to_depart?(at:)`
* `lifecycle_correction_allowed?(at:)`

Do not hide `Time.current` inside an unparameterized predicate.

Under the lock, `MarkDepartureDeparted` captures one timestamp and uses it for both eligibility and `departed_at`:

```ruby
transitioned_at = Time.current
```

The SQL sweep selector must use the same instant semantics as the Ruby predicate. Tests prove they agree for that instant in UTC, a zone west of UTC, a zone east of UTC, and at least one DST-observing zone.

## Job cadence

Register `MarkEligibleDeparturesDepartedJob` in [`config/recurring.yml`](../../config/recurring.yml) as an hourly recurring task on queue `departures` for `production` and `development`. Keep the existing production finished-job cleanup. No Compose change: `bin/jobs` already consumes `queues: "*"`.

Eligibility SQL:

```sql
status = 'active'
AND starts_on IS NOT NULL
AND starts_on <= (?::timestamptz AT TIME ZONE time_zone)::date
```

The sweep binds the same instant the Ruby predicate would receive. Hourly is sufficient because the unit of eligibility is a local calendar date. Do not claim intra-hour precision.

The sweep must:

* skip suspended and closed Agencies
* pluck at most 100 `(agency_id, departure_id)` pairs per batch, then enqueue
* advance the keyset with the last `(agency_id, starts_on, id)` tuple
* never load the entire candidate set into memory
* rely on `index_departures_on_agency_status_starts_on_id`; M2C asserts the sweep query plan
* not recheck eligibility beyond selection; the per-Departure command rechecks the exact local-date predicate after locking Agency then Departure

The per-Departure command remains the authority. The sweep only selects candidates.

## Jobs

There was no `app/jobs` tree before this slice. Add:

* `ApplicationJob` — Rails 8 Active Job base; queue adapter remains Solid Queue in development and production; tests keep the `:test` adapter
* `MarkEligibleDeparturesDepartedJob` on queue `departures` — bounded sweep; never calls the command
* `MarkDepartureDepartedJob` on queue `departures` — arguments `agency_id`, `departure_id`. Reload Agency, reload Departure through that Agency, then:

```ruby
MarkDepartureDeparted.new(
  agency:,
  departure:,
  actor_kind: :system,
  actor_identifier: "departures.mark_departed"
).call
```

Jobs pass identifiers, not Active Record objects. Missing records and inactive Agencies are expected no-op completions: finish without calling the command and without a domain audit. Do not raise `ActiveRecord::RecordNotFound` into retries.

Child-job retry and failure:

* Retry `ActiveRecord::Deadlocked`, `ActiveRecord::SerializationFailure`, and `ActiveRecord::LockWaitTimeout`.
* Bounded attempts: five, with backoff.
* If attempts are exhausted, leave the job visibly failed for operations; do not silently discard it.
* Race-produced draft or ineligible states are command no-ops.
* Unexpected `invalid` or `unauthorized` errors are logged/reported with Agency ID, Departure ID, job ID, and error code — no names or sensitive data.
* Do not write a domain `AuditEvent` for job infrastructure failures.
* One Departure’s failure does not block others.

A worker smoke check must prove `bin/jobs` boots, parses `config/recurring.yml`, and recognizes the `departures` queue.

## Domain error codes

Use only: `unauthorized`, `invalid`, `invalid_state`, `conflict`, `not_found`, `reference_exhausted`.

M2B does not issue references. `reference_exhausted` is unused here.

* Viewer or missing `manage_departures` → `unauthorized`
* Inactive Agency on a user-invoked command → `invalid_state`
* Stale `lock_version` on a user-invoked command → `conflict`
* Manual departed while not eligible → `invalid_state`
* Correction with blank reason, blank departed schedule fields, or invalid dates/zone/currency → `invalid`
* `CorrectDepartureLifecycle` when `starts_on` is today or past → `invalid_state`
* Correction or user departed against the wrong starting status → `invalid_state`
* Invalid invocation matrix (wrong actor/identifier/`lock_version` combination) → `invalid`
* Missing Departure for a user request → HTTP 404

## Commands

Public commands live in `app/services` and inherit `AgencyCommand`. Use `Command.new(...).call`. Do not introduce an unexplained class-level `.call`.

### `MarkDepartureDeparted`

The two valid forms:

```ruby
MarkDepartureDeparted.new(
  agency:,
  departure:,
  actor_kind: :agency_user,
  actor:,
  lock_version:
).call

MarkDepartureDeparted.new(
  agency:,
  departure:,
  actor_kind: :system,
  actor_identifier: "departures.mark_departed"
).call
```

Invocation matrix:

* Agency user: actor required; identifier forbidden; `lock_version` required except departed replay.
* System: actor forbidden; identifier must be exactly `departures.mark_departed`; `lock_version` forbidden/ignored.
* Any other combination: `invalid`.

Never infer system execution from `actor: nil`. Jobs are the only system caller.

After lock, already `departed` → `noop` before comparing `lock_version`. Write no audit and do not change `departed_at`.

User path: `draft` or ineligible active → `invalid_state`.
System path: race-produced `draft` or ineligible → `noop`, no audit.

Success of a real transition: `status: departed`, `departed_at` set to the captured instant, `departure.departed`. No financial, capacity, fulfillment, or closeout side effects.

### Corrections

Permission: `manage_departures`. Starting status `departed`. For every correction:

1. Lock and reauthorize through the M2A helper.
2. Lock Departure.
3. Check `lock_version`.
4. Validate reason (trimmed, 1–500 characters).
5. Validate final values.
6. Detect no-op.
7. Persist and audit atomically.

A correction no-op still requires a current `lock_version` and valid reason, but writes no audit.

`CorrectDepartureSchedule` accepts the complete final schedule: `starts_on`, `ends_on`, `time_zone`, `reason`, `lock_version`. The UI submits all three schedule values. Explicit blanks are invalid on a departed record. Pairing and IANA rules match M2A. Does not change status or `departed_at`. Success writes `departure.schedule_corrected`.

`CorrectDepartureCurrency` accepts `operating_currency`, `reason`, `lock_version`. Valid ISO code via `Money::Currency.find`. Does not change status. Active currency changes remain `UpdateDeparture`. Success writes `departure.currency_corrected`.

`CorrectDepartureLifecycle` accepts `reason`, `lock_version`. Reads the stored row only; it does not accept a speculative future date in the same payload. Allowed only when stored `starts_on` is later than `local_date(at:)` at the captured instant. Success: `status: active`, `departed_at` cleared, reference and `first_activated_at` preserved, `departure.lifecycle_corrected`.

## Audit

Add only these actions, in the same change as first write:

* `departure.departed` — Departure ID/reference, prior/new status, `starts_on`, `time_zone`, `departed_at`
* `departure.schedule_corrected` — ID/reference, reason, changed fields, old/new dates and zone
* `departure.currency_corrected` — ID/reference, reason, old/new currency
* `departure.lifecycle_corrected` — ID/reference, reason, prior/new status, cleared `departed_at`

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

GET pages are focused confirmations. POST performs the command with the agency-user invocation. Reuse `#form-error-summary`. Preserve submitted values on error.

Show **Mark departed** only when `manage_departures` and `eligible_to_depart?(at: Time.current)`. Keep Return to draft on active. Show corrections only when departed. Show lifecycle correction only when `lifecycle_correction_allowed?(at: Time.current)`. The schedule form submits all three schedule fields. Do not add empty M3 panels or Travel Programs navigation.

Name and description on a departed Departure continue to use M2A `PATCH` `/departures/:id`.

## Tests

Cover, at the lowest useful level plus request/system coverage:

* Invocation matrix: valid user form, valid system form, every other combination `invalid`. Controllers never pass `actor_kind: :system`.
* SQL sweep selector and Ruby `eligible_to_depart?(at:)` agree for the same instant in UTC, west-of-UTC, east-of-UTC, and one DST-observing zone.
* Manual departed, job departed, idempotent retry, one audit; `transitioned_at` used for both eligibility and `departed_at`.
* Sweep: no wrapping primary transaction, batches of at most 100 then enqueue, keyset by last tuple, skips inactive Agencies, does not call the command, does not load the full set. Duplicate enqueue absorbed by command idempotency.
* Job: reloads through Agency, ignores `Current`, missing/inactive are no-ops, bounded retry, exhausted retries remain failed, unexpected invalid/unauthorized logged with ids/code only, no domain audit for infrastructure failure. Recurring YAML points at the sweep. Worker smoke check.
* Correction no-ops require current `lock_version` and valid reason, write no audit. Explicit blank schedule fields on departed are `invalid`. Lifecycle correction does not run as a side effect of schedule correction.
* Genuine multi-connection races using the M2A ready/release barrier. Re-raise unexpected exceptions. Accept only `AgencyCommand::Result` or the documented error code:

  * Return-to-draft versus departed: final state is exactly `draft` or `departed`; reference remains; `departed_at` agrees with status; only the winning transition audits.
  * Job versus manual departed: both invocations return Results; one `updated`, one `noop`; one audit; one unchanged `departed_at`.
  * Two jobs: both return Results; one `updated`, one `noop`; `conflict` is not an accepted outcome.
  * Lifecycle correction versus a stale departed job: final state is `active` with `departed_at` nil; one `lifecycle_corrected` audit; the stale job writes no additional `departure.departed` audit when the corrected start remains future.

* Request/system: confirmation surfaces, Viewer rejection, cross-Agency 404

Do not weaken M2A or M1 tests.

## When this slice ships

Update `AGENTS.md` for the first scheduled lifecycle job (at-least-once delivery, identifiers, reload through Agency, exact system invocation, bounded retry, queue `departures`, queue database). Mention departed and correction commands in current architecture and the interface contract. Do not mark M2 complete.

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
