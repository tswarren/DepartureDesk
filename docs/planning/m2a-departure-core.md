# M2A — Departure core

**Status:** Accepted. Implemented on this branch; mark Shipped after merge to `main`. This slice is not yet shipped.

**Parent:** [M2 — Departure core](m2-departure-core.md). The parent status line must read Accepted. This slice plan is not implementation authority while it remains Draft, and it cannot become implementation authority if the parent returns to Draft.

**Prerequisites:** M1A–M1E shipped on `main`; ADR 0001, ADR 0004, ADR 0005, ADR 0006, current architecture, and interface contract.

This slice implements the vertical Departure core only. The parent governs aggregate boundary, Travel Program deferral, persistence, lifecycle, mutability, references, search ranking, and non-goals. This plan narrows that contract to draft through activation and return to draft. It does not reopen it.

## Goal

Let Staff and Administrators create a standalone draft Departure, complete its operating and responsibility context, activate it, receive a durable `D-` reference, find it, and return it to draft before downstream work exists.

## In scope

* `Departure` as the only new domain aggregate
* Draft create, show, edit, and responsibility assignment
* Copied create defaults from current Office, current AgencyUser, Agency time zone, and Agency currency
* Activation, first-activation `D-` issuance, reactivation that reuses the reference
* Return to draft with a reason, retaining reference and `first_activated_at`
* Agency-scoped search, filters, and deterministic index order
* `view_departures` and `manage_departures`
* M2A audit actions and `RecordAdministrativeAudit` ownership for `Departure`
* Departures navigation, index, profile, editors, activation confirmation, and return-to-draft confirmation
* Activation and reference concurrency

## Out of scope

* Travel Program, series, template, or live inheritance
* `MarkDepartureDeparted`, scheduled jobs, `ApplicationJob`, and `config/recurring.yml` changes
* `CorrectDepartureSchedule`, `CorrectDepartureCurrency`, and `CorrectDepartureLifecycle`
* `departure.departed`, `.schedule_corrected`, `.currency_corrected`, and `.lifecycle_corrected` audit actions
* Closeout, reopening, cancellation, Packages, Client Trips, Supplier Arrangements, money amounts, FX, documents
* Duplicate review, destroy, archive, or hard-delete routes
* Office-based visibility, Advisor, Agency Team
* ADR 0007, ADR 0004 amendment, MVP, roadmap outcome, and terminology amendments listed as parent-acceptance work; those are a separate documentation pass and are not completed by this slice
* `AGENTS.md`, current architecture, and interface-contract edits until this slice’s code ships. While the implementation PR is open, describe those files as implemented on the branch; mark them Shipped in a post-merge documentation commit. Do not state that M2 is already shipped while the PR remains unmerged.

The schema includes `departed` and `departed_at` so M2B does not change the status catalog. M2A commands never write `departed` or `departed_at`.

## Locked boundaries

1. Every Departure belongs directly and immutably to one Agency.
2. Departure does not belong to a Travel Program.
3. Office and responsible AgencyUser are attribution only. A Viewer may be the responsible AgencyUser. Assignment grants no authority.
4. Drafts may exist without an Office. Activation may not.
5. Same name and dates are permitted. No duplicate gate.
6. No destroy or archive route.
7. `POST` for activate and return-to-draft. `PATCH` for ordinary field and responsibility updates.
8. Cross-Agency identifiers return not found.
9. Load records through `Current.agency`. Controllers inherit `ApplicationController`, not `Administration::BaseController`.
10. Reuse `#form-error-summary` and the shipped drawer contract. Do not revive `data-turbo-focus`.
11. Do not add `btree_gist`, `citext`, or `pg_trgm`. Do not touch `db/queue_structure.sql`.

## Persistence

Add one forward migration. Update `db/structure.sql`. Do not touch `db/queue_structure.sql`.

Tables use `id: :uuid` with a database default of `uuidv7()`. UUID foreign keys declare `type: :uuid`. Copy the identity shape: unique `(id, agency_id)`, composite foreign keys that prove same-Agency ownership, `attr_readonly` plus a table-specific `BEFORE UPDATE` trigger for immutable columns, and named constraints.

### `departures`

| Attribute | Contract |
| --- | --- |
| `id` | UUIDv7 |
| `agency_id` | Required, immutable |
| `departure_reference` | Null until first activation; then immutable `D-[0-9]{6}` |
| `name` | Required, trimmed, maximum 160 characters, nonblank |
| `description` | Optional; blank becomes `NULL`; maximum 2,000 characters |
| `starts_on`, `ends_on` | Local `date`; both null or both present; `starts_on <= ends_on` when present |
| `time_zone` | Optional IANA identifier; required when status is not `draft` |
| `operating_currency` | Optional uppercase ISO code; required when status is not `draft` |
| `responsible_office_id` | Optional; required when status is not `draft` |
| `responsible_agency_user_id` | Optional; required when status is not `draft` |
| `status` | `draft`, `active`, or `departed`; M2A writes only `draft` and `active` |
| `first_activated_at` | Null until first activation; then immutable |
| `departed_at` | Null in M2A; M2B writes and clears it |
| `lock_version` | Required nonnegative integer |
| timestamps | UTC `timestamptz` |
| `name_search_key` | Stored generated `dd_search_normalize(name)` |

Constraints and indexes:

* unique `(id, agency_id)` named `index_departures_on_id_and_agency_id`
* unique `(agency_id, departure_reference)` where `departure_reference IS NOT NULL`
* check `departure_reference ~ '^D-[0-9]{6}$'` where present
* check paired dates; check `starts_on <= ends_on`
* check activation completeness when `status <> 'draft'`: name, both dates, `time_zone`, `operating_currency`, `responsible_office_id`, and `responsible_agency_user_id` present. After return to draft, `status = draft` so those fields may be incomplete again while `departure_reference` and `first_activated_at` remain.
* lifecycle consistency checks, named and equivalent to:

  ```sql
  (departure_reference IS NULL) = (first_activated_at IS NULL)

  status = 'draft'
  OR (
    departure_reference IS NOT NULL
    AND first_activated_at IS NOT NULL
  )

  (status = 'departed') = (departed_at IS NOT NULL)
  ```

  These permit a never-activated draft (neither reference nor `first_activated_at`), a returned draft (both retained), active (both required, no `departed_at`), and departed (both required, with `departed_at`). They reject an active row without a reference and a departed row without `departed_at`.
* check `operating_currency ~ '^[A-Z]{3}$'` where present
* check `status IN ('draft', 'active', 'departed')`
* composite FK `(responsible_office_id, agency_id)` → `offices (id, agency_id)`
* composite FK `(responsible_agency_user_id, agency_id)` → `agency_users (id, agency_id)`
* btree `(agency_id, name_search_key text_pattern_ops)`
* btree `(agency_id, starts_on, name_search_key, id)` for default order
* btree `(agency_id, status, starts_on, id)`
* btree `(agency_id, responsible_office_id, starts_on, id)`
* btree `(agency_id, responsible_agency_user_id, starts_on, id)`
* btree `(agency_id, ends_on, id)`

M2C may still adjust indexes from composed-query `EXPLAIN`. The foreign-key and status filter paths must not begin entirely unindexed.

Application validation uses `TZInfo::Timezone.get` and `Money::Currency.find`. Do not wrap `operating_currency` in `money-rails`. Do not use the countries gem as a currency authority.

One table-specific trigger rejects changes to `agency_id`, a non-null `departure_reference`, and a non-null `first_activated_at`. Do not generalize an existing identity trigger onto `departures`.

### `reference_sequences`

Widen `reference_sequences_namespace` to `namespace IN ('client', 'supplier', 'departure')`. Backfill one `departure` row with `next_value: 1` for every existing Agency. `ProvisionAgency` creates that row in the provisioning transaction. Client and Supplier behavior stays unchanged. A missing `departure` row is an integrity error. Issuance does not create one.

Add `ReferenceSequence::DEPARTURE_NAMESPACE = "departure"`. Issuance helper follows `SupplierReferenceIssuance`: lock `(agency_id, namespace)`, format `D-%06d`, increment `next_value`. Issuing `1000000` returns `reference_exhausted`.

## Domain error codes

Use only: `unauthorized`, `invalid`, `invalid_state`, `conflict`, `not_found`, `reference_exhausted`.

| Code | Use |
| --- | --- |
| `unauthorized` | Missing permission, inactive actor, or actor/Agency mismatch |
| `invalid` | Missing or malformed required attributes; blank name; unpaired or reversed dates; oversize text; blank return reason on a real transition; search query longer than 100 characters; unknown status; malformed date, UUID, or reversed search range |
| `invalid_state` | Inactive Agency, Office, or responsible AgencyUser; command not allowed in the current lifecycle state |
| `conflict` | Stale `lock_version` |
| `not_found` | Office or AgencyUser id not in the current Agency. Controllers also translate a missing Departure to HTTP 404 |
| `reference_exhausted` | Sequence would issue `D-1000000` |

Do not add `duplicate_review_required`. Viewer mutation produces no write and no audit.

## Commands

Public commands live in `app/services` and inherit `AgencyCommand`. Expected failures are not audited. Successful mutations audit in the same transaction.

Lock order after the pre-transaction authorization check: lock Agency, recheck that the locked Agency is active, reload the actor through that Agency and recheck active status and permission, then lock Departure when it exists, then referenced Office by UUID, then referenced AgencyUser by UUID, then `ReferenceSequence` only when issuance is required. Resolve copied create defaults inside that locked transaction so a concurrently changed Office or Agency default cannot be copied from stale state.

Lifecycle replay versus stale locking, after authorization, Agency scoping, and pessimistic row locking:

* If the requested lifecycle outcome already exists, return success before comparing `lock_version`. Write no audit and make no change.
* Otherwise compare `lock_version` normally.

Apply that rule to `ActivateDeparture` when already `active` and `ReturnDepartureToDraft` when already `draft`. Ordinary `UpdateDeparture` and `UpdateDepartureResponsibility` no-ops still check `lock_version`.

Resolve Office and AgencyUser through the Agency. Controllers load Departures through `Current.agency`. Other-agency Departure ids are HTTP 404, not forbidden.

### `CreateDeparture`

Permission: `manage_departures`. Active Agency required.

Accepts explicit attributes. When an attribute is omitted, copy:

1. current active Office as `responsible_office_id`;
2. current AgencyUser as `responsible_agency_user_id`;
3. the Agency `default_timezone`;
4. Agency `default_currency`.

Do not invent an Office when none is current. Explicit submitted values, including explicit blanks, override copies. Copies are not live inheritance.

Creates `status: draft`. Does not issue a reference. Does not lock the sequence.

No-op: none; every successful create writes `departure.created`.

Invalid Office or AgencyUser id: `not_found`. Inactive targets are allowed only as omitted/null on create; if the actor submits an inactive id, `invalid_state`.

### `UpdateDeparture`

Permission: `manage_departures`. Requires current `lock_version`.

Draft: name, description, dates, time zone, and operating currency are editable.

Active: the same fields are editable with audit. No currency-dependent downstream history exists in M2, so active currency may change here. Non-draft updates must keep both dates, a valid IANA time zone, a valid operating currency, and existing responsible Office and AgencyUser. Validate those requirements in the command and model before persistence. Do not rescue the database completeness constraint.

Departed (rows will not exist until M2B): name and description only. Date, time zone, or currency changes return `invalid_state`. M2B owns those corrections.

Same values are a no-op without another audit. Stale `lock_version` is `conflict`. Does not change responsibility, status, or reference.

### `UpdateDepartureResponsibility`

Permission: `manage_departures`. Requires current `lock_version`. Submits Office and AgencyUser together atomically, including explicit nils.

Draft: both may be nil.

Active and departed: both must be present, same-Agency, and active. Clearing either on a non-draft row is `invalid_state`.

A Viewer target is allowed. Inactive historical targets remain on the row until an explicit replacement. Submitting an inactive replacement is `invalid_state`. Other-agency ids are `not_found`.

Same pair is a no-op without another audit. Success writes `departure.responsibility_changed` with old and new identifiers.

Allowed on draft, active, and departed.

### `ActivateDeparture`

Permission: `manage_departures`. Requires current `lock_version` except on lifecycle replay.

Starting state must be `draft`, or `active` for idempotent replay.

After locking the Departure row, if it is already `active`, return success before comparing `lock_version`. Write no audit, issue no reference, and do not change `first_activated_at`. An HTTP retry may therefore carry the pre-activation `lock_version`.

Requires, when a real transition runs: valid name; paired ordered dates; valid IANA `time_zone`; valid `operating_currency`; active same-Agency Office; active same-Agency AgencyUser; existing `departure` sequence row.

`departed`: `invalid_state`.

Always enters `active`, even when `starts_on` is today or past. Do not call `MarkDepartureDeparted`.

First activation issues `departure_reference` and sets `first_activated_at`. Reactivation after return to draft reuses the existing reference and leaves `first_activated_at` unchanged.

Missing or malformed required attributes: `invalid`. Inactive Agency, Office, or responsible AgencyUser: `invalid_state`. Wrong lifecycle state: `invalid_state`. Missing sequence row: `invalid` (integrity). Exhaustion: `reference_exhausted`. Stale `lock_version` on a real transition: `conflict`.

Success of a real transition writes `departure.activated`.

### `ReturnDepartureToDraft`

Permission: `manage_departures`. Requires current `lock_version` except on lifecycle replay, and a trimmed reason of 1–500 characters when a real transition runs.

After locking the Departure row, if it is already `draft`, return success before comparing `lock_version`. Write no audit.

Starting state for a real transition is `active` only. `departed`: `invalid_state`. Blank reason on a real transition: `invalid`.

In M2, activation, reference issuance, and audit history are not downstream history and do not block. M3 must extend the dependency catalog before Arrangement or currency-bound records exist.

Retains `departure_reference` and `first_activated_at`. May leave operating and responsibility fields incomplete. Does not unlock currency for later milestones that have frozen it; M2 has no such history.

Success of a real transition writes `departure.returned_to_draft` including the reason.

### `SearchDepartures`

Not a mutation and not audited. Permission: `view_departures`.

Accept `q` (max 100 characters), `status` (`draft`, `active`, `departed`, `all`; default `all`), `responsible_office_id`, `responsible_agency_user_id`, `starts_on_from`, `starts_on_to`, `ends_on_from`, `ends_on_to`. Date filters are inclusive against stored local dates.

Filters fail closed. No invalid filter executes the search query.

* Blank filter values mean omitted.
* Unknown status, malformed date, malformed UUID, or reversed range (`from` after `to`) → `invalid`.
* A supplied Office or AgencyUser ID resolves through the Agency.
* Missing or other-Agency IDs → `not_found`.
* Do not silently ignore a filter, treat unknown status as `all`, or scan another Agency.

Blank `q` browses. Query longer than 100 characters: `invalid` without scanning.

Rank: exact normalized `departure_reference`, then exact `name_search_key`, then prefix `name_search_key LIKE normalized_q || '%'`. Tie-break and blank browse use `starts_on` ASC NULLS LAST, `name_search_key`, `id`.

Cap 50, fetch 51, report truncation. Expose `composed_relation` for later EXPLAIN. Include inactive Office and AgencyUser display names when historically assigned. Do not search Clients, Suppliers, or external references. Do not treat Office as authorization.

## Permissions

Add these grants to `AccessPermission` and no others:

| Permission | Administrator | Staff | Viewer |
| --- | ---: | ---: | ---: |
| `view_departures` | Yes | Yes | Yes |
| `manage_departures` | Yes | Yes | No |

Authorize through `Authentication#require_permission!`. Viewer sees index and show and no mutation actions.

## Audit

Extend these together:

* `AuditEvent::SUBJECT_TYPES` with `Departure`
* `AuditEvent::ACTIONS` with `departure.created`, `.updated`, `.responsibility_changed`, `.activated`, `.returned_to_draft`
* `RecordAdministrativeAudit#ensure_subject_belongs_to_agency!` so a `Departure` subject must belong to the event Agency

Do not add M2B actions in this slice. Details contain identifiers, status changes, changed field names, dates, zone, currency, and supplied reason. They do not introduce Client, Supplier, itinerary, or financial facts.

## Routes and UI

Implement only these paths. Member id is the Departure UUID.

```text
GET    /departures                         departures_path
GET    /departures/new                     new_departure_path
POST   /departures                         departures_path
GET    /departures/:id                     departure_path
GET    /departures/:id/edit                edit_departure_path
PATCH  /departures/:id                     departure_path
GET    /departures/:id/responsibility/edit edit_departure_responsibility_path
PATCH  /departures/:id/responsibility      departure_responsibility_path
GET    /departures/:id/activation          departure_activation_path
POST   /departures/:id/activate            activate_departure_path
GET    /departures/:id/return-to-draft     edit_departure_return_to_draft_path
POST   /departures/:id/return-to-draft     departure_return_to_draft_path
```

Do not add departed or correction routes. Do not add Travel Programs, Packages, Travelers, Accounting, or Supplier Planning navigation.

Add a real **Departures** sidebar link for `view_departures`, after Suppliers and before Administration. Use the existing `calendar_blank` icon. Update `NavigationHelper` so those controllers mark Departures current.

Follow [docs/ui/interface-contract.md](../ui/interface-contract.md) and `dd-` classes.

* Index: reference or “Draft”, name, dates, status, responsible Office, responsible AgencyUser, filters.
* Profile: identity, dates, time zone, currency, responsibility, lifecycle, reference, permitted next actions. No empty M3 panels.
* Create may propose copied defaults; the user can change them. Time zone is an IANA select that defaults to the Agency time zone.
* Activation is a dedicated readiness/confirmation page listing missing requirements. It is not an edit-form checkbox.
* Return to draft is a focused confirmation that collects the reason.
* Preserve submitted values after command errors. Reuse `#form-error-summary`.

## Tests

Cover, at the lowest useful level plus request/system coverage:

* UUIDv7, `timestamptz`, named constraints including lifecycle consistency, generated `name_search_key`, sequence backfill and provisioning, composite FKs, immutability trigger, filter indexes
* Create defaults, zero-Office draft, explicit override, no live inheritance, Agency time-zone default
* Activation completeness, issuance, reactivation reuse, return-to-draft retention and incompleteness, exhaustion, missing sequence row
* `UpdateDeparture` and responsibility rules, Viewer as responsible user, inactive target rejection, historical inactive target retained
* Command matrix: success, invalid, unauthorized, inactive Agency, stale, not found, no-op, rollback, audit atomicity
* Genuine multi-connection races (`use_transactional_tests = false`, thread barrier, `connection_pool.with_connection`). Re-raise unexpected exceptions. Accept only `AgencyCommand::Result` or the documented error code:

  | Race | Required outcome |
  | --- | --- |
  | Two different Departures activate concurrently | Distinct references |
  | Same Departure activated twice | Both invocations succeed (`updated` and `noop`); one transition, one reference, one activation audit. Do not accept `conflict`. |
  | Office inactivation then activation | Activation fails; the Departure remains draft without a reference |
  | Activation then Office inactivation | The Departure stays active with its reference; later Office inactivation may leave historically inactive responsibility. Inactivity never reverses activation or grants authorization. |
  | Activation versus AgencyUser suspension | One serialized valid outcome |
  | Activation versus ordinary edit | No lost update |
  | Responsibility reassignment versus target inactivation | One serialized valid outcome |

* Search rank, fail-closed filters, 50/51, deterministic order, unauthorized actor
* Lifecycle replay succeeds with a stale pre-transition `lock_version`; ordinary update no-ops still require a current `lock_version`
* Request/system: draft create, preserved errors, activation readiness, Viewer browse without mutations, cross-Agency 404

System tests run in GitHub CI. The local Docker image has no Chrome.

Existing M0 and M1 tests must remain green. Do not weaken them.

## When this slice ships

Update `AGENTS.md` current boundary and navigation rule, `docs/architecture/current-state.md`, `docs/ui/interface-contract.md` navigation, the permission catalog mention, and terminology’s implementation note so Departure draft/activation is in the shipped boundary and Travel Program, departed jobs, and M3 records are not. Do not describe M2 as complete. Do not invent an `m3-*.md` link.

While the implementation PR is open, describe those updates as implemented on the branch. Mark the slice **Shipped** in a post-merge documentation commit. Do not state that M2A or M2 is already shipped while the PR remains unmerged.

Parent-acceptance ADR, MVP, roadmap, and terminology amendments are not this slice’s work. M2C verifies those accepted authorities remain consistent; it does not complete them retroactively.

## Exit gate

M2A is complete only when:

* Departure is the only new aggregate and Travel Program remains unimplemented
* Draft, activation, reference issuance, return-to-draft, search, and the documented M2A races pass
* Cross-Agency reads and mutations return not found
* M0 and M1 remain green
* The slice is merged to `main`

This slice authorizes M2A only. It does not authorize M2B, M2C, M3, or Travel Program.
