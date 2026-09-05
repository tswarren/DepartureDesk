# ADR 0002: Agency tenancy and membership

- Status: Accepted
- Date: 2026-09-05
- Decision owners: DepartureDesk maintainers

## Context

Every later DepartureDesk operational and financial record belongs to one agency. Authentication already identifies a user through a signed session cookie. It does not yet establish which agency that user may operate.

A user-to-agency foreign key on `users` would collapse identity and tenancy. That would lose membership history and force a redesign if a person later needs access to more than one agency.

Request parameters, headers, and extra cookies are untrusted sources for tenant selection. Ambiguous or missing tenant context must not allow a request to continue.

## Decision

The tenant is `Agency`. The user-to-agency relationship is `AgencyMembership`. Application code must not select an agency from an untrusted request parameter.

A user may have at most one active membership during MVP. The database enforces that with a partial unique index on `agency_memberships.user_id` where `status = 'active'`. The application still **fails closed defensively** if more than one active membership is ever loaded.

`User#usable_agency_membership` is the sole resolver for login, request context, session resumption, and Action Cable. It returns a membership only when exactly one active membership exists and that membership’s agency is `active`. Otherwise it returns nil.

Do not model the active membership as `has_one`. A `has_one` silently selects one row if bad data contains two and conceals ambiguity.

## Persistence contract

`agency_memberships` is an application-owned table with UUID primary keys, `uuidv7()` database defaults, UUID foreign keys to `users` and `agencies`, `timestamptz` timestamps, and `lock_version`.

Roles are constrained strings: `staff` and `administrator`. Statuses are constrained strings: `active` and `suspended`. Do not use a boolean admin flag.

Required database guarantees:

- unique `[user_id, agency_id]`;
- partial unique index on `user_id` where `status = 'active'`;
- check constraints for allowed roles, allowed statuses, and `lock_version >= 0`.

Model uniqueness for one active membership per user applies only when the record is active, so suspended historical memberships do not collide.

Memberships are authorization history. Agency and user associations use `dependent: :restrict_with_exception`. Lifecycle management should suspend records rather than destroy them once the system has meaningful history.

## Request-context contract

`Current.session` is the authentication root. `Current.user`, `Current.agency_membership`, and `Current.agency` are derived from it through `User#usable_agency_membership`.

- no session → no user, membership, or agency;
- valid session plus exactly one usable membership → user, membership, and agency available;
- no active membership, more than one active membership, a suspended membership, or a non-active agency → no usable tenant context.

`Current.office` is subordinate to that trusted agency context. Resolution does not write the session. It uses, in order: a stored `office_id` that is active, owned by `Current.agency`, and operationally accessible; otherwise the membership’s active accessible default office; otherwise the sole accessible active office in memory. An invalid stored selection is ignored and left in place until login, invitation acceptance, `SelectCurrentOffice`, or a deactivation/revocation cleanup writes the session. It is never established from `params[:office_id]`, an unsigned cookie, or a GET side effect.

An office is not a tenant. Later office-owned records must still carry a direct `agency_id` and enforce matching `(office_id, agency_id)` through a composite foreign key.

Controllers must not establish tenant context from `params[:agency_id]`, headers, cookies other than the signed session identifier, or form input.

Treat only an `active` agency as operationally accessible. A suspended or closed agency uses the same generic denial as a missing membership.

## Authentication contract

After credentials authenticate and before creating a session, resolve exactly one usable membership. Create the session only when that resolution succeeds. Otherwise return the existing generic login failure message. Do not reveal whether the credentials, membership, or agency failed.

Every authenticated request must re-resolve a usable membership. If the membership or agency is no longer usable:

- destroy the session row;
- clear `Current.session`;
- clear the signed session cookie;
- redirect to sign-in with a generic message;
- do not allow the request to continue.

Password reset remains non-enumerating and does not reactivate a membership or agency.

## Explicit scoping

Do not add a global tenant `default_scope`. Future tenant-owned records must declare `belongs_to :agency` and be loaded through the current agency:

```ruby
Current.agency.suppliers.find(params[:id])
Current.agency.suppliers.build(permitted_attributes)
```

Do not look up a tenant-owned record globally and then authorize. Scoped lookup produces `ActiveRecord::RecordNotFound` for another agency’s UUID and avoids existence disclosure.

Rules:

- do not permit `agency_id` in ordinary strong parameters;
- scope business uniqueness by `agency_id` unless the value is deliberately global;
- scope reports, counts, search, autocomplete, exports, and dashboards—not only CRUD;
- never infer tenant ownership through a client-supplied parent without reloading that parent through `Current.agency`;
- use unscoped or global lookup only in deliberately privileged maintenance code with explicit tests and documentation.

## Authorization boundary

This decision introduces only the minimum role contract:

- `staff`: ordinary authenticated access within the current agency;
- `administrator`: ordinary access plus future agency administration.

Do not add a granular permission system, policy gem, field-level permissions, or record-by-record grants here.

## Background jobs

Jobs must accept an explicit `agency_id` or an agency-owned record identifier. At execution they must reload the agency, verify it is still usable, and scope reads and writes through it. When a job needs office scope it must accept an `office_id`, reload that office through the agency, and re-check operational access.

Do not serialize `Current` or assume request-local state carries into a job. `Current.set` may wrap a job only for that job’s duration.

## Action Cable

Action Cable connections identify `current_user` and `current_agency` from `User#usable_agency_membership`. They must not copy request `Current` onto a long-lived WebSocket connection, and they must not persist `Current.office` on the connection. Channel actions added later must re-check usability; connection identifiers are established at connect time only. Future office-scoped channel actions must reload the current session selection and reapply office authorization for each action. Connection-time `current_agency` identification is not sufficient for office-scoped broadcasts.

## Later resource test contract

For every agency-owned controller introduced later, require:

- same-agency index contains only current-agency rows;
- same-agency show/edit/update succeeds;
- another agency’s UUID returns 404 for show/edit/update/destroy;
- forged `agency_id` cannot move or create a record in another agency;
- search, export, counts, and nested-resource lookup remain scoped.

## Consequences

### Positive

- Every authenticated request has one trusted agency or is denied.
- Membership history is preserved without binding user identity to a single agency foreign key.
- Cross-agency access fails as not found rather than revealing that a record exists.
- Ambiguous tenant context cannot be papered over by `has_one`.

### Costs and risks

- Supporting concurrent active memberships later requires an explicit migration plus a session-bound agency choice and switching workflow.
- Existing sessions must be revalidated on every authenticated request.
- Future contributors must remember explicit scoping; a missing `Current.agency` association is a security defect.

## Alternatives considered

### `users.agency_id`

Rejected. It collapses identity and tenancy, discards membership history, and forces a later redesign for multi-agency access.

### Tenant `default_scope`

Rejected. Hidden scoping is easy to miss in jobs, reports, exports, maintenance, and console work. Explicit `Current.agency` associations remain visible.

### Session-stored agency choice during MVP

Rejected. A user has at most one active membership, so derived context is unambiguous without an agency switcher.

### Policy gem or granular RBAC

Rejected for this slice. Authenticated staff have full access within their agency for MVP, except administrative capabilities reserved for the `administrator` role later.

## Implementation checklist

- Add the `agency_memberships` table with UUID foreign keys, named checks, and the partial unique index.
- Implement `User#usable_agency_membership` as the sole resolver.
- Derive `Current.agency_membership` and `Current.agency` from that resolver.
- Require a usable membership before session creation and on every authenticated request.
- Identify both user and agency on Action Cable connections.
- Keep development seeds and fixtures consistent with one usable membership per signed-in user.
- Update this ADR if a later requirement introduces agency switching or concurrent active memberships.
