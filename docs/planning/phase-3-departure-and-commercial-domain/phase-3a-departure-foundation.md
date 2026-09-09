# Phase 3A — Departure foundation

## Status

Accepted implementation plan for the first slice of Phase 3. This revision incorporates the pre-coding review remediations.

This plan is subordinate to:

- `AGENTS.md`
- `docs/adr/0001-money-and-currency.md`
- `docs/adr/0002-agency-tenancy-and-membership.md`
- `docs/adr/0004-human-readable-references.md`
- `docs/terminology.md`
- `docs/ui/interface-contract.md`
- `docs/planning/phase-3-departure-and-commercial-domain/phase-3-departure-and-commercial-domain-plan.md`

The parent Phase 3 plan controls if this slice plan becomes stale. Do not silently change the parent contract through implementation convenience.

---

## 1. Objective

Create the stable dated operating root that every later Phase 3 record references.

After 3A:

- An authorized user can create and manage an optional reusable travel program.
- An authorized user can create a dated departure owned by one agency office.
- Every departure receives a stable agency-scoped human-readable reference at creation.
- Internal responsibility is assigned to agency memberships without creating a second employee identity.
- Organizers, group leaders, and sponsors are assigned through agency-owned Parties without granting application authority.
- Departure lifecycle changes occur through explicit commands.
- Office, membership, Party lifecycle, merge-participation, audit, and lock-order contracts remain fail-closed.
- Later slices have a tenant-safe, office-owned, audited departure root on which to build supplier, client, fulfillment, and financial records.

3A does not create packages, client trips, service components, supplier arrangements, capacity, charges, receipts, obligations, payments, commission, or closeout.

---

## 2. Locked 3A decisions

### 2.1 Travel program and departure

- A `TravelProgram` is an optional reusable agency-owned concept or series.
- A `Departure` is one dated operational occurrence and is the Phase 3 operating boundary.
- A departure may exist without a travel program.
- A departure belongs to at most one travel program.
- Programs never own departure balances, capacity, lifecycle, or settlement state.
- 3A does not implement program package templates. Slice 3C owns templates and copy/materialization into departure-owned packages.

### 2.2 Office ownership

- Every departure belongs to exactly one agency and one owning office in that agency.
- `agency_id` is direct and required; tenancy is never inferred only through `office_id`.
- `Current.office` may default the create form but never authorizes a departure.
- Staff may operate departures only for currently accessible offices.
- Administrators may operate departures for active offices throughout the agency.
- Party selectors remain agency-wide and are never filtered by the departure office.
- Travel programs remain agency-wide readable configuration. Staff-visible linked departure names, counts, next-departure dates, badges, search snippets, and preload queries include only departures in currently accessible offices. Administrators see the complete agency history. Empty staff results must not disclose that inaccessible departures exist.
- Historical departures owned by an inactive office remain agency-visible to administrators through an explicit same-agency historical path; inactive office ownership never permits new operational mutation.
- Nonterminal departures project `owning_office_status = 'active'` with a state-bearing FK to unique `offices (id, agency_id, status)`. Cancelled departures null that projection while retaining the base `(office_id, agency_id)` ownership FK.

### 2.3 Internal team and contextual Party roles

Use two distinct assignment systems:

1. `DepartureTeamAssignment` references `AgencyMembership` for `group_manager` or `responsible_advisor`.
2. `DeparturePartyRoleAssignment` references `Party` for `organizer`, `group_leader`, or `sponsor`.

Do not combine them in a polymorphic role table. Neither assignment authorizes access or privileged commands. A team assignment is attribution. When a command checks the current group manager, that check is an explicit command predicate combined with current office access; it is not an authorization capability stored on the assignment.

3A does not read, copy, default from, update, or otherwise use `ClientAdvisorAssignment`. A departure responsible advisor is contextual only. Slice 3C owns client-trip advisor defaulting and its relationship to client and departure advisors. 3A creates no client-trip advisor.

### 2.4 Required manager

- Every nonterminal departure has exactly one current `group_manager` assignment.
- `responsible_advisor` is optional and has at most one current assignment.
- The same membership may hold both roles.
- Create defaults group manager to the acting membership when that membership can access the selected office; the creator may select another eligible membership explicitly.
- Ending or replacing the sole group manager must occur atomically so a nonterminal departure never has zero or two current managers.
- Ordinary staff with office access cannot take over management by assigning themselves.

| Action | Authorized actor |
| --- | --- |
| Select initial manager during creation | Creator with office access |
| Assign, replace, or end responsible advisor | Administrator or current group manager, with office access |
| Replace group manager | Administrator or current group manager, with office access |
| Cancel draft/planning departure | Administrator or current group manager, with office access |
| End sole manager without replacement | Never |

### 2.5 Program and departure lifecycle

Travel program statuses are:

```text
active ↔ inactive
```

- New programs are active.
- Inactive programs remain visible in history but cannot receive new departures or later templates.
- A program cannot become inactive while it has a nonterminal departure.
- Reactivation is explicit and does not alter departures.

The parent plan reserves the full departure lifecycle. 3A persists and permits only the statuses it implements:

```text
draft
planning
cancelled
```

3A transitions are:

```text
create → draft
draft → planning
draft → cancelled
planning → cancelled
```

- `cancelled` is terminal in 3A.
- Database and model checks reject every other status. Later slices add statuses through forward migrations when they implement the corresponding commands and invariants.
- Later slices own sale, confirmation, operation, reconciliation, close, reopen, and post-sale cancellation transitions.
- No generic status-edit action is allowed.
- 3A cancellation is deliberately limited to a departure that cannot yet have downstream Phase 3 children. Once later slices add children, their cancellation command must replace or extend this safe boundary atomically.

### 2.6 Date semantics

- `start_date` and `end_date` are required calendar dates.
- A one-day departure stores the same date in both fields.
- `end_date >= start_date`.
- `sales_open_on` and `sales_close_on` are optional in 3A.
- When both exist, `sales_close_on >= sales_open_on`.
- Do not require sales close to precede departure start; late sales may be valid.
- Dates are interpreted using the owning office timezone for display and date-sensitive commands unless a later record supplies a more specific service timezone.
- Default assignment `effective_from` to today in the owning office’s IANA timezone. Commands may accept an explicit date after that default. Store it as a date.
- Office transfer never rewrites prior assignment calendar dates. New assignments after transfer default using the new office timezone.
- Do not convert dates into midnight timestamps.

### 2.7 Currency semantics

- `default_currency` is required and seeded from `Agency#default_currency` at departure creation.
- It is a sticky data-entry default for later departure records, not a functional-currency amount and not permission for implicit conversion.
- 3A stores no financial amounts or exchange rates.
- It may be changed while the departure is `draft` or `planning` because no Phase 3 financial facts exist yet.
- Later slices must freeze or command-control the field once currency-bearing accepted or posted records exist.

### 2.8 Historical identity

- Assignment records keep ordinary same-agency Party or membership foreign keys plus purpose-specific display-name snapshots.
- Do not use a live `party_status = 'active'` projection on historical Party references.
- Eligibility is revalidated when a current assignment is established.
- Ending an assignment preserves the row and snapshot.
- `AuditEvent#details` may identify a snapshot but is not its authoritative store.

---

## 3. Departure reference specification

This section is the 3A domain decision required by ADR 0004.

| Attribute | Decision |
| --- | --- |
| Namespace | `departure_reference` only |
| Owner/issuer | DepartureDesk |
| Scope | Unique within agency; not office-scoped |
| Reset | Never resets |
| Issuance | Departure creation |
| Canonical format | `D-` plus at least six decimal digits, for example `D-000123` |
| Storage | Uppercase string in `departures.departure_reference` |
| Reuse | Never |
| Gaps | Acceptable |
| Mutation | Immutable after issuance |
| Import | Legacy/source references are separate future facts; they do not replace the generated reference |

Agency scope is preferred over office scope because ownership may be transferred while the departure reference must not become misleading or change. Dates, destinations, program names, and office codes are intentionally absent because they are mutable.

### 3.1 Counter persistence

Create a departure-specific `departure_reference_counters` table, not a generic numbering engine.

| Column | Contract |
| --- | --- |
| `agency_id` | UUID primary key and FK to agencies |
| `last_value` | Required bigint, default `0`, nonnegative |
| timestamps | `timestamptz` |

The counter allocator must:

- Lock or atomically update the one agency counter row.
- Safely initialize the row under concurrency.
- Increment and issue inside the same transaction as departure creation.
- Return the existing departure on a retry with the same creation idempotency key.
- Never use an unlocked `maximum + 1` query.
- Permit the numeric portion to grow beyond six digits without truncation.

`departures` enforces unique `(agency_id, departure_reference)` and a named canonical-format check. Database uniqueness remains authoritative.

### 3.2 Creation idempotency

`CreateDeparture` accepts `creation_idempotency_key` as the single permitted command-input exception: an opaque server-generated UUID retained by the create form and stored on the departure with unique `(agency_id, creation_idempotency_key)`. It is not a record identity, reference, agency selector, or caller-controlled issuance value. The server remains solely responsible for the departure UUID and `departure_reference`.

- Repeating the same key with the same material input returns the existing departure.
- Repeating the key with conflicting material input returns an idempotency conflict.
- A retry never consumes a second reference.
- The create form retains the server-generated key across validation errors and resubmission.

Do not generalize this into an application-wide request framework in 3A.

---

## 4. Persistence design

All application-owned tables use UUIDv7 unless this plan explicitly defines a natural UUID primary key, such as the agency counter row. Every tenant-owned table carries direct `agency_id` and tenant-safe composite foreign keys.

### 4.1 `travel_programs`

| Column | Contract |
| --- | --- |
| `id` | UUIDv7 primary key |
| `agency_id` | Required agency owner |
| `name` | Required, normalized nonblank display name |
| `description` | Optional internal/plain-text description |
| `client_facing_description` | Optional plain-text description |
| `status` | Required `active` or `inactive`; default `active` |
| `inactivated_at` | Nullable; required only while inactive |
| `inactivated_by_membership_id` | Nullable; same-agency membership; required only while inactive |
| `inactivation_reason` | Nullable normalized text; required only while inactive |
| `lock_version` | Required nonnegative optimistic-lock counter |
| timestamps | `timestamptz` |

Constraints and indexes:

- Unique `(id, agency_id)` for tenant-safe children.
- Unique `(id, agency_id, status)` for the departure program-status race boundary.
- Named status and lifecycle-metadata consistency checks.
- Index `(agency_id, status, name)`.
- Trigram or normalized search index on name only if the 3A list search uses it; reuse existing `pg_trgm` rather than adding a second search mechanism.
- Restrict agency deletion.

Program names are not hard-unique. Separate recurring programs may legitimately share a public name; selection surfaces disambiguate with status and departure history.

### 4.2 `departures`

| Column | Contract |
| --- | --- |
| `id` | UUIDv7 primary key |
| `agency_id` | Required agency owner |
| `office_id` | Required owning office |
| `owning_office_status` | Nullable state-bearing projection; `active` while `draft` or `planning`; null when `cancelled` |
| `travel_program_id` | Optional program in the same agency |
| `travel_program_status` | Nullable state-bearing projection; `active` for a nonterminal linked departure and null for no program or a terminal departure |
| `departure_reference` | Required immutable canonical generated reference |
| `creation_idempotency_key` | Required UUID |
| `name` | Required normalized display name |
| `description` | Optional internal/plain-text description |
| `client_facing_description` | Optional plain-text description |
| `primary_destination` | Optional normalized display text |
| `start_date` | Required date |
| `end_date` | Required date |
| `sales_open_on` | Optional date |
| `sales_close_on` | Optional date |
| `default_currency` | Required uppercase ISO 4217 currency accepted by the existing Money configuration |
| `status` | Required `draft`, `planning`, or `cancelled`; default `draft` |
| `created_by_membership_id` | Required same-agency membership snapshot reference |
| `status_changed_at` | Required `timestamptz` |
| `status_changed_by_membership_id` | Required same-agency membership |
| `status_reason` | Nullable normalized text; required for cancellation |
| `lock_version` | Required nonnegative optimistic-lock counter |
| timestamps | `timestamptz` |

Constraints and indexes:

- Unique `(id, agency_id)`.
- Unique `(agency_id, departure_reference)`.
- Unique `(agency_id, creation_idempotency_key)`.
- Composite FK `(office_id, agency_id)` to offices.
- State-bearing composite FK `(office_id, agency_id, owning_office_status)` to unique `offices (id, agency_id, status)` when the active projection is present.
- Composite FK `(travel_program_id, agency_id)` to travel programs whenever a program is linked, so terminal rows with a null projection remain tenant-safe.
- Additional state-bearing composite FK `(travel_program_id, agency_id, travel_program_status)` to travel programs when the active projection is present.
- Same-agency composite FKs for creator and status actor memberships.
- Named format check `departure_reference` matches `D-[0-9]{6,}`.
- Named date-order and sales-date-order checks.
- Named currency-format check plus application validation against Money's currency registry.
- Named status, status-metadata, owning-office-projection, program-projection, and nonnegative-lock checks.
- Indexes supporting `(agency_id, office_id, status, start_date)`, `(agency_id, status, start_date)`, `(agency_id, travel_program_id, start_date)`, and reference lookup.
- Restrict deletion of agency, office, program, and actor references.

The owning-office projection must enforce:

- `draft` or `planning` → `owning_office_status = 'active'`;
- `cancelled` → projection null, while `office_id` remains.

The program projection must enforce:

- no program → projection null;
- nonterminal linked departure → projection `active`;
- terminal (`cancelled` in 3A) linked departure → projection null.

These projections permit a program or office to become inactive only after all linked or owned departures are terminal and provide the database race boundary beneath command preflight checks. `ChangeOfficeStatus` translates the named owning-office FK violation to the same dependency conflict as its preflight check.

`created_by_membership_id` and historical status actors do not use an active-membership projection. Suspending a membership must not erase historical attribution.

### 4.3 `departure_team_assignments`

| Column | Contract |
| --- | --- |
| `id` | UUIDv7 primary key |
| `agency_id` | Required agency |
| `departure_id` | Required same-agency departure |
| `agency_membership_id` | Required same-agency membership |
| `membership_status` | `active` while current; null after ending |
| `assignment_role` | `group_manager` or `responsible_advisor` |
| `member_name_snapshot` | Required name at assignment |
| `effective_from` | Required date |
| `effective_until` | Nullable date; current when null |
| `assigned_at` | Required `timestamptz` |
| `assigned_by_membership_id` | Required same-agency actor membership |
| `ended_at` | Nullable; complete with all ending metadata |
| `ended_by_membership_id` | Nullable same-agency actor membership |
| `ending_reason` | Nullable; required when ended |
| `lock_version` | Required nonnegative optimistic-lock counter |
| timestamps | `timestamptz` |

Constraints and indexes:

- Composite FKs preserve agency across departure and membership references.
- State-bearing FK `(agency_membership_id, agency_id, membership_status)` targets active membership status while the assignment is current.
- Current assignment requires `membership_status = 'active'` and blank ending metadata.
- Ended assignment requires null `membership_status` and complete ending metadata.
- Unique partial index on `(departure_id, assignment_role)` where current, enforcing one current manager and at most one current advisor.
- Prevent duplicate overlapping assignment to the same membership, departure, and role.
- Date-range and lifecycle-completeness checks.

The command layer additionally guarantees that every nonterminal departure has one current manager. Because PostgreSQL cannot express that parent-to-child minimum cleanly, create, replace, cancel, and future close commands own it atomically.

`SuspendMembership` and `RevokeOfficeAccess` reject those dependencies using the non-locking helpers and retained lock orders in section 6.1. Translate the membership-projection FK race to the same domain conflict. Administrators derive office access from role, so absence of an explicit office assignment is not itself invalid.

### 4.4 `departure_party_role_assignments`

| Column | Contract |
| --- | --- |
| `id` | UUIDv7 primary key |
| `agency_id` | Required agency |
| `departure_id` | Required same-agency departure |
| `party_id` | Required same-agency Party |
| `party_kind` | Required immutable Party-kind projection |
| `role` | `organizer`, `group_leader`, or `sponsor` |
| `party_display_name_snapshot` | Required display name at assignment |
| `is_primary` | Required boolean, default false |
| `effective_from` | Required date |
| `effective_until` | Nullable date; current when null |
| `assigned_at` | Required `timestamptz` |
| `assigned_by_membership_id` | Required same-agency actor membership |
| `ended_at` | Nullable; complete with all ending metadata |
| `ended_by_membership_id` | Nullable same-agency actor membership |
| `ending_reason` | Nullable; required when ended |
| `lock_version` | Required nonnegative optimistic-lock counter |
| timestamps | `timestamptz` |

Constraints and indexes:

- Composite FKs preserve agency across departure, Party, and actor membership references.
- Typed composite FK `(party_id, agency_id, party_kind)` targets the existing immutable Party-kind key.
- Ordinary Party FK only; no live active-Party projection.
- Current/ended metadata and date-range checks.
- Unique partial index on `(departure_id, role)` where current and primary.
- Prevent duplicate overlapping same-party/same-role assignment.
- Named check requires `party_kind = 'person'` when `role = 'group_leader'`; command validation provides the same domain message.

Whenever a role has one or more current assignments, exactly one must be primary. The unique partial index enforces at most one current primary. A deferred constraint trigger enforces the remainder at transaction commit: if current assignments exist for a departure and role, exactly one of them must be primary. Commands maintain the same invariant operationally: the first assignment becomes primary; additional assignments default nonprimary; ending the primary requires choosing a replacement or ending all current assignments for that role; `SetPrimaryDeparturePartyRole` switches atomically. `AssignDeparturePartyRole` rejects an overlapping same-party/same-role interval before insert and translates `dpra_no_overlapping_intervals` to `:conflict`.

Organizer and sponsor may reference a person, household, or organization. Group leader references a person.

Current assignments register a `PartyDeactivationDependencies` checker. Historical ended assignments do not block deactivation.

### 4.5 No generic assignment table

Do not introduce a generic polymorphic `roles`, `assignments`, or `participants` table. The two assignment tables have different identity, lifecycle, dependency, and authorization contracts.

---

## 5. Party deactivation and Phase 2E merge participation

### 5.1 Deactivation

Register a `departure_party_roles` checker with `PartyDeactivationDependencies` in the same change that creates the Party FK.

- A current organizer, group leader, or sponsor assignment on a nonterminal departure blocks Party deactivation.
- The dependency response identifies the departure reference, departure name, and role, capped using the existing sample convention.
- An ended assignment or assignment on a terminal departure does not block deactivation.
- Cancellation ends current Party roles atomically before the departure becomes terminal.
- Do not clear assignments silently from `DeactivateParty`.

### 5.2 Phase 2E catalog

Executable merge is not assumed shipped. Before 3A completes, update `docs/planning/phase-2-party-and-supplier-directory/phase-2e-party-merge.md` to register `departure_party_role_assignments.party_id` in the fail-closed participant catalog. 3A adds no merge persistence or executable merge behavior.

The future participant contract is:

- Preserve `party_display_name_snapshot` unchanged.
- Repoint the live Party FK to the survivor only through the merge participant.
- Fail closed when absorbed and survivor assignments would create an overlapping same-role duplicate or two current primary assignments.
- Require explicit conflict resolution; do not silently discard or coalesce assignments.
- Do not alter team assignments because they reference memberships, not Party role identity.

Until the 2E executor implements this participant, attempted merge involving this reference remains blocked as unsupported. Do not treat registration as permission to guess, cascade, or silently repoint.

---

## 6. Office and membership dependency integration

### 6.1 Existing command lock orders

Existing membership and office lifecycle commands retain their shipped outer lock order. They evaluate departure dependencies after acquiring those locks and use non-locking dependency helpers. The state-bearing foreign keys provide the database race boundary. They must not call public Phase 3 commands or acquire departure locks in an order that conflicts with ordinary departure commands.

| Command | Retained outer order |
| --- | --- |
| `SuspendMembership` | agency → membership |
| `ChangeOfficeStatus` | agency → office |
| `RevokeOfficeAccess` | agency → office → membership |

If a dependency helper later needs locked departure rows for an additional mutation, that belongs in a separately designed command, not in a read-only dependency check.

The authoritative race boundaries are:

- Current `DepartureTeamAssignment` → active membership projection.
- Nonterminal `Departure` → active owning-office projection.
- Nonterminal linked `Departure` → active program projection.

### 6.2 Office deactivation

Extend `ChangeOfficeStatus` preflight behavior:

- An office cannot become inactive while it owns any nonterminal departure.
- The conflict lists a bounded sample of departure references and names.
- The check occurs after the existing agency → office locks, using a non-locking dependency helper.
- Translate the named owning-office state-bearing FK violation to the same domain conflict.
- Terminal departures do not block office deactivation.
- Office deactivation does not rewrite their office ownership.

Administrators retain an explicit same-agency read path for historical departures owned by an inactive office. No mutation may use that historical path to bypass active-office requirements.

### 6.3 Office transfer

`TransferDepartureOffice` is administrator-only in 3A and allowed only while the departure is `draft` or `planning`.

It must:

- Lock old and new offices in stable UUID order.
- Require the new office to be active and belong to the agency.
- Revalidate the administrator actor after the agency lock.
- Require every current team assignee to be able to access the new office, or reject with the members that must be reassigned.
- Preserve the agency-scoped departure reference.
- Update office ownership, maintain the owning-office projection, and audit atomically.
- Never copy or recreate the departure.

3B freezes this simple office-transfer command once any supplier arrangement has ever existed on the departure. While no arrangement row exists, transfer remains available under the 3A rules above. Creating the first arrangement permanently prohibits further transfer for that departure—even if every arrangement is later cancelled or released—because children and audit retain original office ownership. `CreateSupplierArrangement` and `TransferDepartureOffice` share the lock boundary `agency → old/new offices by UUID → departure → arrangement dependencies`, and a concurrency test must prove they cannot produce mixed ownership. Aggregate-wide ownership transfer is deferred; see [`phase-3b-supplier-planning-capacity.md`](phase-3b-supplier-planning-capacity.md). No later implementation may silently move posted financial records by changing `departures.office_id`.

### 6.4 Membership suspension and access revocation

- `SuspendMembership` blocks while the membership is a current group manager or responsible advisor on a nonterminal departure. The check runs after the existing agency → membership locks, using a non-locking helper, and translates the membership-projection FK race to the same domain conflict.
- `RevokeOfficeAccess` blocks when revocation would remove a staff assignee's access to an office containing a nonterminal departure for which the member is currently assigned. The check runs after the existing agency → office → membership locks.
- Assignment replacement or ending is explicit and audited; suspension/revocation never clears assignments as a side effect.
- Existing client-advisor dependency behavior remains intact and is reported together with departure dependencies where both apply.

---

## 7. Commands and lifecycle

Controllers remain thin. Commands own transactions, locks, tenancy revalidation, lifecycle checks, audit, and any reference or assignment side effects.

### 7.1 Travel program commands

#### `CreateTravelProgram`

- Requires a usable agency operator.
- Locks agency.
- Creates an active program.
- Records `travel_program.created`.

#### `UpdateTravelProgram`

- Locks agency, then program.
- Accepts name and descriptions only.
- Rejects stale `lock_version`.
- Records changed fields without treating audit JSON as version history.

#### `DeactivateTravelProgram`

- Requires reason.
- Locks agency, then program, then linked nonterminal departures by UUID for final dependency verification.
- Rejects when a nonterminal departure remains linked.
- Sets inactive lifecycle metadata and records audit.

#### `ReactivateTravelProgram`

- Requires reason.
- Locks agency and program.
- Restores active status and clears current inactive metadata while audit preserves history.
- Does not alter departures.

### 7.2 Departure commands

#### `CreateDeparture`

- Requires active selected office and actor access to that office.
- Requires active selected program when present.
- Requires an eligible active group-manager membership with access to the office.
- Validates dates and currency.
- Accepts `creation_idempotency_key` as the single permitted command-input exception: an opaque server-generated token retained by the form. It is not a record identity, reference, agency selector, or caller-controlled issuance value. The server remains solely responsible for the departure UUID and `departure_reference`.
- Allocates the reference and, in one transaction, creates only the draft departure, required manager assignment, optional responsible-advisor assignment, counter effect, and audit event.
- Does not create organizer, group-leader, or sponsor assignments. Those use only `AssignDeparturePartyRole`.
- Records `departure.created` with reference, office, program, dates, currency, and manager identity.
- Returns the existing result on an idempotent retry.

#### `UpdateDeparture`

- Allowed only for `draft` and `planning` in 3A.
- Edits name, descriptions, destination, dates, sales dates, default currency, and optional program through one command.
- Program changes require an active same-agency program and maintain the program-status projection.
- Does not change office, reference, status, or assignments.
- Requires expected `lock_version` and records changed fields.

#### `StartDeparturePlanning`

- Performs only `draft → planning`.
- Requires current manager and active owning office.
- Records status actor and timestamp.
- Does not create capacity, supplier commitments, offers, or financial facts.

#### `CancelDeparture`

- Performs only `draft|planning → cancelled` in 3A.
- Requires a nonblank reason.
- Ends current team and Party-role assignments with `departure_cancelled` disposition.
- Clears the active travel-program and owning-office status projections while retaining `travel_program_id` and `office_id`.
- Authorizes only an administrator or the current group manager, each of whom must still have access to the owning office. That current-manager check is a command predicate, not a stored assignment permission.
- Records one aggregate cancellation audit with affected assignment IDs.
- Does not hard-delete the departure or reuse its reference.

#### `TransferDepartureOffice`

- Uses the contract in section 6.3.
- Records `departure.office_transferred` with old and new office IDs/codes.

### 7.3 Assignment commands

#### `AssignDepartureTeamMember`

- Accepts departure, membership, role, effective date, and expected departure version.
- Authorized only for administrator or current group manager, with office access, except that create-time manager selection is owned by `CreateDeparture`.
- Requires active membership and access to the departure office.
- Creates the first current assignment for that role. If a current assignment already exists, reject and direct the caller to `ReplaceDepartureTeamMember`.
- Must never invoke `ReplaceDepartureTeamMember#call` while holding earlier locks.
- Does not grant office access.

#### `ReplaceDepartureTeamMember`

- Ends the current role assignment and creates its replacement atomically through a private `replace_locked!` primitive owned by this command.
- Authorized only for administrator or current group manager, with office access.
- Requires a reason.
- Never leaves a nonterminal departure without a manager.

#### `EndDepartureTeamAssignment`

- May end an advisor directly.
- Authorized only for administrator or current group manager, with office access.
- Rejects ending the sole current manager; use replacement instead.
- Requires a reason and preserves history.

#### `AssignDeparturePartyRole`

- Loads the Party through `Current.agency`, independent of current office.
- Requires active Party at establishment.
- Enforces role-specific Party kind.
- First current assignment for a role becomes primary; later assignments default nonprimary.
- Does not require or create client/supplier profiles unless the role itself later requires one; 3A organizer, leader, and sponsor do not.
- Does not grant access.

#### `EndDeparturePartyRole`

- Ends a current role assignment with complete metadata and reason.
- Ending the primary requires choosing a replacement primary or ending all current assignments for that role.
- Does not deactivate or otherwise mutate the Party.

#### `SetPrimaryDeparturePartyRole`

- Switches primary status among current assignments for one role atomically.
- Does not end the former primary assignment.

No command accepts `agency_id`, status, reference, actor identity, or snapshot text from ordinary form parameters. `creation_idempotency_key` is the single permitted create-form exception and is not a caller-controlled identity.

---

## 8. Command lock-order appendix

All interactive 3A commands use the existing `MembershipCommand` actor contract. They do not lock the actor `User` first.

### 8.1 Canonical 3A order

When a command touches these record types, acquire locks in this order:

1. Agency.
2. Involved offices, sorted by UUID.
3. Travel program, when involved.
4. Departure.
5. Party records, sorted by UUID.
6. Agency memberships, sorted by UUID.
7. Existing team assignments, then Party-role assignments, sorted by UUID within type.
8. Departure reference counter only at the allocation point inside `CreateDeparture`.

The agency lock serializes same-agency command decisions, but later locks and database constraints remain required for explicit ownership, direct SQL safety, and future refactoring.

This order applies to ordinary Phase 3A departure, program, and assignment commands. It does not reorder shipped membership or office lifecycle commands; those keep section 6.1.

### 8.2 Command matrix

| Command | Locks after agency |
| --- | --- |
| Create program | None |
| Update/reactivate program | Program |
| Deactivate program | Program → linked nonterminal departures by UUID for final dependency verification |
| Create departure | Office → program if present → selected memberships → counter at allocation |
| Update departure | Current office → candidate program if present → departure |
| Start planning | Office → program if present → departure → current manager membership/assignment |
| Cancel departure | Office → program if present → departure → referenced Parties by UUID → memberships by UUID → assignments by UUID |
| Transfer office | Old/new offices by UUID → program if present → departure → current assignee memberships by UUID |
| Assign/replace team member | Office → departure → memberships by UUID → existing assignment |
| Assign/end Party role | Office → departure → Parties by UUID → assignment |
| Set primary Party role | Office → departure → Parties by UUID → assignments by UUID |

`SuspendMembership`, `ChangeOfficeStatus`, and `RevokeOfficeAccess` are not in this matrix; they retain section 6.1. If a Phase 3A command requires a different order, update this appendix before coding and add the corresponding concurrency test. Do not call a nested public command that reacquires agency, office, program, departure, Party, or membership locks. Provide narrowly named `*_locked!` primitives owned by the outer command.

### 8.3 Revalidation after locks

Commands revalidate, as applicable:

- Actor still has a usable membership and required administrator capability.
- Agency remains active.
- Office belongs to agency, remains active, and actor may access it.
- Program and departure belong to agency and have the expected status.
- Party belongs to agency, has the expected kind, and is active when establishing a current role.
- Membership belongs to agency, is active, and may access the departure office.
- Expected `lock_version` still matches.
- Current assignment or dependency set has not changed.

---

## 9. Authorization

### 9.1 Read access

- Staff index and detail queries include departures whose owning active office is in `Current.agency_membership.accessible_offices`.
- Administrators may read all same-agency departures, including historical terminal departures whose office is inactive.
- No unscoped lookup follows a UUID or human reference supplied by the client.
- Cross-agency and inaccessible-office lookups return the same non-disclosing not-found behavior.
- Travel programs are agency-wide directory-like configuration and readable by all usable agency members. Staff-visible linked departure data on those surfaces is office-filtered as in section 2.2.

### 9.2 Write access

- Staff may create and update departures only in accessible active offices.
- Staff may start planning and manage Party-role assignments in accessible active offices.
- Team-assignment mutations after create, and early cancellation, follow the actor table in section 2.4.
- Program create/update may be available to staff; program deactivate/reactivate is administrator-only because it affects reusable agency configuration.
- Office transfer is administrator-only.
- Assignment does not authorize a user who otherwise lacks office access.
- Party selection remains agency-wide, but selecting a Party does not expose notes or contact details the current surface does not otherwise need.

3A does not introduce granular RBAC. It uses existing staff/administrator membership roles plus office access and explicit command predicates.

---

## 10. Audit contract

Extend `AuditEvent::ACTIONS` with:

```text
travel_program.created
travel_program.updated
travel_program.deactivated
travel_program.reactivated
departure.created
departure.updated
departure.planning_started
departure.cancelled
departure.office_transferred
departure.team_member_assigned
departure.team_member_replaced
departure.team_assignment_ended
departure.party_role_assigned
departure.party_role_ended
departure.party_role_primary_changed
```

Extend `RecordAdministrativeAudit` subject support for `TravelProgram` and `Departure` in the same PR as the first audit write.

- Program commands use the program as subject.
- Departure, team-assignment, and Party-role commands use the departure as the audit subject and identify assignment IDs in details.
- Counter rows and name snapshots are not audit subjects.
- Audit details include changed field names and bounded before/after values where appropriate; they do not become the authoritative snapshot store.
- Actor attribution uses the existing membership-backed user/system contract. Ordinary web commands do not invent a new actor type.

Tests must prove that unknown Phase 3 actions and subjects still fail closed.

---

## 11. User interface

Use the adopted interface contract and existing DepartureDesk design system. The future-state mockups are visual references, not permission to render data or actions that do not exist in 3A.

### 11.1 Navigation

- Add **Departures** as the primary operational destination.
- Make **Travel programs** a secondary destination from the departure index or its local navigation; do not add unnecessary top-level navigation.
- Do not add links for packages, client trips, suppliers, financials, manifests, or closeout until their slices ship.

### 11.2 Departure index

Provide:

- Search by exact/partial departure reference, name, program name, or destination.
- Filters for status, owning office, and date window.
- Useful default ordering: current/upcoming by start date, then reference.
- Explicit views or filters for upcoming, past/terminal, and cancelled departures.
- Columns for reference, departure, dates, program, office, status, group manager, and destination.
- Bounded results with pagination.
- No fabricated traveler counts, revenue, margin, capacity, or attention state.

### 11.3 Travel-program surfaces

- Index with name, active/inactive status, upcoming nonterminal departure count, and next departure date, each derived only from departures the current actor may see.
- Detail with descriptions and linked departures using the same office-access filter. Empty staff results must not disclose inaccessible departures.
- Display-first details with explicit edit mode.
- Deactivation conflict names the departures that must be completed, cancelled, or moved.

### 11.4 Departure create/edit

Group fields into:

1. Identity — name, optional program, destination.
2. Dates — start/end and optional sales window.
3. Ownership — office and group manager, with optional responsible advisor.
4. Presentation — internal and client-facing descriptions.
5. Defaults — default currency.

- Default office from `Current.office` only when valid and accessible.
- Default group manager to the actor only when eligible.
- Party roles are added after creation through dedicated assignment commands; do not include them on the create form.
- Preserve the server-generated idempotency token across invalid submissions.
- Do not expose generated reference, lifecycle status, agency ownership, snapshots, or actor IDs as editable inputs.

### 11.5 Departure detail

Show only shipped 3A facts:

- Reference, name, status, dates, destination, program, and office.
- Current group manager and responsible advisor.
- Organizers, group leaders, and sponsors.
- Internal/client-facing descriptions with correct audience labeling.
- Available lifecycle and office-transfer actions according to authorization.
- Audit/history link using existing patterns where available.

Do not render empty future tabs for roster, packages, supplier arrangements, financials, or operations. Later slices add those surfaces when backed by real records.

### 11.6 Assignment workflows

- Use role-specific labels rather than a generic “Add role.”
- Membership selectors show active eligible agency team members and their office access.
- Party selectors use the existing agency-wide role-aware selector and show Party kind; they do not filter by office.
- Replacement previews who is ending, who is beginning, effective date, and reason.
- Ending the manager directs the user to replacement rather than presenting an action that must fail.
- A current assignment for a team role presents replacement, not a second assign action.

### 11.7 Accessibility and no-JavaScript behavior

- All commands work through ordinary server requests.
- Turbo may enhance navigation and validation but is not required for correctness.
- Dialogs/drawers meet the existing focus, Escape, inert-background, and return-focus contract.
- Status is conveyed by text, not color alone.
- Validation summaries link to fields and preserve entered values.
- Destructive cancellation and deactivation use explicit confirmation and reason entry.

---

## 12. Search and query behavior

- All departure queries begin from `Current.agency.departures` and then apply office authorization.
- Exact reference lookup is normalized and agency-scoped before any result is returned.
- Staff office filtering derives from current accessible offices, not `Current.office` alone.
- Program queries begin from `Current.agency.travel_programs`. Linked departure counts, next dates, badges, snippets, and lists apply the same office authorization as the departure index.
- Party selectors begin from `Current.agency.parties` and apply role/kind/status eligibility, never departure office.
- Preload program, office, current assignments, memberships, and Party display data on list/detail views to avoid N+1 queries.
- Do not add departure records to global search unless the global-search contract and access-safe result routing are implemented in this slice; local departure search is sufficient for 3A.

---

## 13. Validation and error translation

Commands return stable domain outcomes for:

- Invalid or inaccessible office.
- Inactive or cross-agency program.
- Ineligible, inactive, or office-inaccessible team member.
- Inactive, cross-agency, or wrong-kind Party.
- Invalid lifecycle transition.
- Program, office, membership, or Party dependency conflict.
- Stale optimistic lock.
- Idempotency conflict.
- Reference exhaustion or unexpected allocation failure.
- Named database constraint/FK race.

Expected conflicts must not become generic 500 responses. Translate named database violations to the same user-facing result as command preflight checks.

---

## 14. Test plan

### 14.1 Model and database tests

Test:

- UUIDv7 identities and direct agency ownership.
- Same-agency composite FKs for program, departure, office, memberships, Parties, assignments, and actors.
- Cross-agency associations rejected by PostgreSQL, not only model validation.
- Departure date, sales date, currency, reference, lifecycle metadata, owning-office-projection, and program-projection constraints.
- Status check permits only `draft`, `planning`, and `cancelled`.
- Reference and idempotency uniqueness within agency and permitted reuse across agencies.
- Program status projection blocks inactivation races while nonterminal departures exist.
- Owning-office projection blocks office-inactivation races while nonterminal departures exist.
- Current team assignment requires active membership projection.
- Current-role uniqueness and complete ending metadata.
- Only person Parties can be group leaders.
- A role with current assignments has exactly one primary.
- Optimistic locking on independently mutable aggregates.
- Restrictive deletion behavior.

### 14.2 Reference tests

Test:

- First and subsequent formatting.
- Agency-scoped non-resetting sequence.
- More than six digits remains valid.
- Parallel creation issues distinct references.
- Transaction rollback does not leave a created departure.
- Same-key retry returns the original departure/reference.
- Same-key conflicting retry fails without consuming another reference.
- Cancellation retains the reference.
- Office transfer retains the reference.
- Operator input cannot override the reference.
- Human-reference lookup is agency- and office-access scoped.

### 14.3 Command tests

Test each success, no-op/idempotent behavior, stale state, forbidden transition, cross-agency input, inaccessible office, inactive dependency, and named database-race translation.

Specifically test:

- Create departure creates only the departure, required manager, optional advisor, reference, and audit; it never creates Party roles.
- Assigning a team role rejects when a current assignment exists; replacement is a separate command.
- A nonterminal departure never loses its sole manager.
- Replacing a manager creates a continuous historical chain.
- Ordinary staff who are not the current group manager cannot assign or replace the group manager or advisor.
- Ending the primary Party role requires a replacement primary or ending all current assignments for that role.
- Assignment never grants office access.
- Party assignment never grants application authority.
- Program deactivation conflicts with a nonterminal departure.
- Membership suspension and office-access revocation conflict with current departure responsibility.
- Office deactivation conflicts with nonterminal departures and translates the owning-office FK race to the same conflict.
- Office transfer validates every current assignee against the destination office and does not rewrite prior assignment dates.
- Cancellation ends current assignments and nulls the program and owning-office active projections atomically.
- Nested locked primitives do not reacquire locks.

### 14.4 Party lifecycle and merge tests

Test:

- Current Party roles on nonterminal departures block deactivation.
- Ended or terminal assignments do not block deactivation.
- Dependency labels are bounded and non-disclosing.
- The Phase 2E participant catalog registers `departure_party_role_assignments.party_id` and merge remains blocked until the executor implements that participant.
- Snapshot names do not change when the live Party name changes.
- Future merge-participant behavior preserves snapshots and rejects conflicting overlapping roles.

### 14.5 Authorization and request tests

Test:

- Staff can access departures only for currently assigned active offices.
- Administrator active-office access and inactive-office historical read behavior.
- `Current.office` neither grants nor removes authorization.
- Cross-agency and inaccessible-office UUID/reference lookups do not disclose existence.
- Party lookup remains agency-wide.
- Program lookup remains agency-wide; staff-visible linked departure counts, dates, badges, snippets, lists, and empty results do not disclose inaccessible offices.
- Staff cannot transfer offices or change program lifecycle.
- Only an authorized administrator or current manager can cancel, replace the manager, or mutate advisor assignments under the 3A rule.
- Strong parameters exclude agency, status, reference, snapshot, actor, and idempotency ownership fields as appropriate.

### 14.6 Audit tests

Test:

- Every successful command emits the expected action and subject.
- Failed/no-change commands emit no misleading success event.
- Audit actor, agency, departure/program subject, reason, old/new office, role, and assignment IDs are correct.
- Unknown actions and subject types remain rejected.
- Audit detail changes do not mutate snapshots.

### 14.7 System tests

Cover:

- Program create/edit/deactivate/reactivate.
- Departure create with default office and manager.
- Invalid create preserves values and idempotency key.
- Departure local search and filters.
- Start planning.
- Assign, replace, and end advisor.
- Assign/end organizer, leader, and sponsor; change primary.
- Transfer office success and dependency conflict.
- Early cancellation with reason.
- Keyboard, focus, no-JavaScript, stale-write, responsive-table, and disclosure behavior.
- No future empty tabs or fabricated metrics.

### 14.8 Named scenario proof

Create scenario builders or fixtures for:

#### Smith Family Reunion Cruise — July 12, 2027

- Optional `Smith Family Reunion` program.
- One cruise departure with required office and manager.
- Organizer and person group leader represented as Party roles.
- No cabin, insurance, hotel, traveler, or money records yet.

#### Napa Wine Country Tour — October 10, 2027

- Optional `Annual Napa Wine Tour` program.
- One departure with a different responsible advisor if useful.
- No coach, vineyard, package, enrollment, or profitability records yet.

The fixtures prove the roots needed by later slices without pretending later domains have shipped.

---

## 15. Implementation order

Implement within `phase-3a-departure-foundation` in this order:

1. Confirm parent-plan gate and repository terminology are current.
2. Register `departure_party_role_assignments.party_id` in `docs/planning/phase-2-party-and-supplier-directory/phase-2e-party-merge.md`.
3. Add migrations, composite keys, named constraints, and `db/structure.sql` changes.
4. Add models and database-focused tests.
5. Add departure reference allocator and concurrency/idempotency tests.
6. Add travel-program commands and audit catalog support.
7. Add departure create/update/planning commands.
8. Add team and Party-role assignment commands and dependency integrations.
9. Add office transfer, early cancellation, and lifecycle integration changes.
10. Add authorization/query objects, routes, controllers, and local search.
11. Add display-first program and departure surfaces.
12. Add request and system coverage.
13. Run full CI-equivalent tests and review the two scenario proofs.

If review size becomes excessive, split the branch into sequential PRs targeting the Phase 3 integration branch without weakening slice gates:

- 3A.1 persistence, references, models, and core commands.
- 3A.2 assignments, lifecycle/dependency integrations, and authorization.
- 3A.3 routes, UI, search, and system tests.

Each intermediate PR must be deployable, keep navigation free of unshipped routes, and identify temporary hidden surfaces explicitly.

---

## 16. Explicit exclusions

3A does not implement:

- Program package templates or copying; 3C owns them.
- Packages, package versions, or pricing.
- Client trips, travelers, traveling parties, or resource occupancy.
- Service components or amendments.
- Supplier arrangements, reservations, resources, confirmations, cost terms, capacity, guarantees, or exposure.
- Client or supplier financial records.
- Functional-currency postings or exchange rates.
- Departure dashboards containing derived traveler, capacity, balance, revenue, cost, cash, or margin measures.
- Generic reference generators.
- Granular RBAC or permission tables.
- Automatic recurrence generation.
- Hard deletion of programs, departures, or assignments.
- Sensitive traveler documents or document requirements.
- Later departure statuses such as `open_for_sale`.
- Reads or writes of `ClientAdvisorAssignment`.
- Executable party-merge persistence or behavior.

Do not create placeholder tables, columns, statuses with side effects, controllers, tabs, or navigation for these later domains.

---

## 17. 3A exit gate

3A is complete only when:

1. `AGENTS.md`, terminology, the parent plan, code, tests, and UI use the same canonical names.
2. A travel program can be created, edited, deactivated, and reactivated without owning operational facts.
3. A departure can be created with one agency, active owning office, optional active program, required manager, dates, currency default, UUIDv7 ID, and immutable human reference.
4. The reference allocator is agency-scoped, non-resetting, concurrent, idempotent, non-reusing, and not generic infrastructure.
5. 3A persists and exposes only draft, planning, and cancelled through commands.
6. Internal team assignments reference active memberships; contextual roles reference Parties; neither grants authorization. Manager cancellation and team-assignment mutations are command predicates plus office access.
7. Nonterminal departures retain exactly one current manager. Ordinary staff cannot self-assign as manager.
8. Directory/Party selection remains agency-wide while departure operations and staff-visible program-linked data enforce current office access.
9. Program, office, membership, Party deactivation, office-access revocation, and future merge behavior fail closed around current departure dependencies. Nonterminal departures project active owning-office status. The 2E catalog registers `departure_party_role_assignments.party_id` without implementing merge.
10. Historical references, assignment rows, and display-name snapshots survive lifecycle changes.
11. `AuditEvent::ACTIONS` and `RecordAdministrativeAudit` remain closed and include only the approved 3A aggregate actions/subjects.
12. Every multi-record command follows the documented lock order, revalidates after locks, and has concurrency coverage where races matter.
13. Program and departure UI conforms to the interface contract without exposing later Phase 3 features or fabricated metrics.
14. Smith and Napa scenario roots are represented without introducing later-domain shortcuts.
15. Model, database, command, authorization, request, system, and full regression tests pass in the canonical Docker/CI environment.

Only after this gate should 3B treat the departure as an available supplier-planning root.
