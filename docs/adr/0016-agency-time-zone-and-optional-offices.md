# ADR 0016: Agency time zone and optional offices

- Status: Accepted 2026-11-01. Decision log entry D-61.
- Date: 2026-11-01
- Decision owners: DepartureDesk maintainers
- Supersedes: [ADR 0005](0005-agency-identity.md), in part: the office time zone, `ProvisionAgency` creating the first office, and offices as required context. The rest of ADR 0005 stands except where [ADR 0017](0017-user-types-permissions-and-reseller-users.md) supersedes it.
- Specification: SET-09, SET-10, SET-11, SET-12, DEP-01
- Charter: [first-slice charter](../planning/first-slice/first-slice-charter.md), step 1 ("one agency time zone")

## Context

The shipped application stores a required IANA time zone on both `agencies.default_timezone` and `offices.default_timezone`. `ProvisionAgency` creates a first office. An active Departure must have a `responsible_office_id`, enforced by the `departures_activation_completeness` check.

The specification gives each agency one time zone, shared by all offices (SET-09). Offices are optional records for work assignment, filtering and reporting. They are not tenants, data owners or access boundaries (SET-12). A Departure records its own default time zone for its services and a Departure team, not an office (DEP-01, SET-10). The first-slice charter defers offices to a later slice.

Two sources of local time inside one agency would make deadlines, receipts and audit times depend on which office a user happened to select.

## Decision

### One agency time zone

- `Agency.default_timezone` is the agency time zone. It is a required, recognized IANA identifier, never a fixed offset.
- Instants (payments, audit events, sign-ins) are stored in UTC and displayed in the agency time zone.
- Date-only facts stay dates.
- A date-only deadline resolves to 11:59 p.m. agency local time. It keeps its governing local date, time and zone and its resolved instant (SET-10). The resolved instant is stored when the deadline is recorded, not recalculated on read.
- Changing the agency time zone affects future defaults only. It does not reinterpret existing service occurrences, confirmed records, issued documents or resolved deadlines (SET-11).

### Departure and service zones

- A Departure keeps its own `time_zone`, defaulted from the agency time zone when the Departure is created.
- A timed service occurrence keeps its local date and time and an explicit IANA zone, defaulted from the Departure (SET-10). All-day travel dates stay date-only.

### Offices are optional and carry no time zone

- `offices.default_timezone` is removed. All offices use the agency time zone (SET-12).
- An agency may have zero offices. `ProvisionAgency` no longer creates one.
- A Departure no longer requires a responsible office. `responsible_office_id` becomes optional and leaves the activation completeness check. The Departure team (DEP-01, ACC-09) replaces the responsible office as the routing fact when the charter builds it.
- Office records, the session office preference and the user's default office remain. They are filter and display preferences only. They never authorize, never scope a query for access and never change which records a user can see (ADR 0005's rule that office selection is not authorization still holds).
- Office management stays an Agency Admin action (ACC-33). No new office behavior is built until a charter places it in scope.

### Migration

No real agency data has been loaded (the charter requires MFA to be decided first), so the change is a direct schema migration with no compatibility period:

1. Drop `offices.default_timezone`.
2. Make `departures.responsible_office_id` nullable and remove it from `departures_activation_completeness`.
3. Update `ProvisionAgency`, seeds, fixtures and tests. Remove any code path that reads an office's zone, falling back to the Departure zone for services and the agency zone for everything else.

## Consequences

### Positive

- Every deadline, receipt and audit time in an agency has one unambiguous local meaning.
- Departures can be created without an office, which the Alpha fixture and the reseller path need.
- Offices can return later as a reporting and routing dimension without any access meaning.

### Costs

- Existing tests and fixtures that create offices, or rely on office zones, must change.
- An agency with staff in several real time zones sees agency-local times. This is the specification's choice (SET-09).

## Alternatives rejected

### Keep per-office time zones

Rejected. It contradicts SET-09 and SET-12 and makes date-only deadlines resolve differently depending on office.

### Remove offices entirely

Rejected for now. The table and preferences cost little to keep, and SET-12 keeps offices as an optional feature. Hiding them is a presentation choice for the slice, not an architecture decision.

### Derive the agency zone from the first office

Rejected. Offices are optional and may not exist.

## Implementation boundary

Implemented in charter Slice 1, step 1 (foundation changes). This ADR authorizes only the changes listed under Migration and the time rules above.
