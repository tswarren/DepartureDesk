# ADR 0003: Membership lifecycle and invitations

- Status: Accepted
- Date: 2026-09-05
- Decision owners: DepartureDesk maintainers

## Context

Foundation 1 established `AgencyMembership` with `active` and `suspended` statuses and `User#usable_agency_membership` as the sole tenant resolver. Agency administrators need to invite staff without assigning passwords, change roles, and suspend or restore access without loosening that contract.

ADR 0002 remains authoritative for tenancy, one active membership, derived `Current.agency`, and fail-closed authentication.

## Decision

Membership status is a constrained lifecycle:

```text
invited → active ↔ suspended
    └────────→ revoked
```

- `invited`: invitation issued but not accepted; never usable for authentication.
- `active`: usable only while the agency is active.
- `suspended`: access disabled while preserving membership history.
- `revoked`: invitation cancelled before acceptance; terminal for that invitation attempt. A later invitation reuses the same `[user_id, agency_id]` row.

`User#usable_agency_membership` continues to require exactly one `active` membership whose agency is `active`. Invited, suspended, and revoked memberships never resolve tenant context.

Application write paths for membership status are explicit command objects. Model enums do not encode the state machine by themselves.

An invitation is distinct from a password reset. Invitations use a purpose-specific signed token that includes membership ID, invitation version, invitation-compatible status, purpose, and expiration. Replacement, revocation, and successful acceptance increment `invitation_version`. Failed acceptance does not.

Administrators invite by email. Invitees choose their own password. The application never assigns an administrator-visible password.

A user may have at most one active membership. Inviting an address that already has an active membership in another agency does not attach a row, send mail, or disclose that fact. The tenant-facing message is: “If this address is eligible, an invitation will be sent.”

An agency must retain at least one active administrator. Commands lock the agency row first, then the target membership, then any other memberships, and recalculate the administrator count after the agency lock.

Successful invitation acceptance starts a session and lands on the dashboard. Prior sessions for that user are destroyed first.

## Consequences

- Team administration can proceed without console access.
- Cross-agency email existence is not disclosed on the tenant invitation surface.
- Last-administrator protection is serialized on the agency row.
- Password reset cannot activate an invited membership.
