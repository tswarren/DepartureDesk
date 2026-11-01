# ADR 0017: User types, per-user permissions and reseller users

- Status: Accepted 2026-11-01. Decision log entry D-62.
- Date: 2026-11-01
- Decision owners: DepartureDesk maintainers
- Supersedes: [ADR 0005](0005-agency-identity.md), in part: the access roles `administrator`, `staff` and `viewer` and the role-to-permission catalog. ADR 0005's tenancy, sign-in, session, invitation, password, rate-limit, lifecycle, last-administrator and audit rules stand.
- Specification: ACC-02 to ACC-05, ACC-07, ACC-10 to ACC-15, ACC-18, ACC-30 to ACC-33; the Permissions table
- Charter: [first-slice charter](../planning/first-slice/first-slice-charter.md), steps 1 and 9; blocking decision B10; demonstration case D15

## Context

The shipped application gives each `AgencyUser` one `access_role` (`administrator`, `staff` or `viewer`). `AccessPermission::CATALOG` maps each permission to the roles that hold it. Application code checks the catalog, not role names.

The specification uses built-in user types and a small set of predefined permissions (ACC-05). An Agency Admin holds every permission (ACC-07). Every staff user, with no permission, may do the baseline work in ACC-30. Beyond that, staff may hold any of five permissions, assigned per user: Departure management, Supplier arrangements, Financial records, Passport access and Reseller relationships (ACC-11). There is no viewer. Reseller users belong to the agency (ACC-02) but see only offers published to their channel and bookings assigned to them, and never enter money (ACC-14, ACC-15).

Fixed roles cannot express "staff with Financial records but not Supplier arrangements" without one role per combination.

## Decision

### User types

`AgencyUser` replaces `access_role` with `user_type`:

| User type | Holds | Notes |
| --- | --- | --- |
| `agency_admin` | Every permission, implicitly; never stored as grants | Alone performs the ACC-33 actions: users, permissions, agency settings and defaults, audit history, full export, imports |
| `staff` | The ACC-30 baseline plus any granted permissions | |
| `reseller` | Only the reseller actions in ACC-15, for its own relationship | Belongs to exactly one reseller relationship |

The `viewer` role is removed. Platform Administrators stay outside the agency: agency provisioning and lifecycle remain privileged commands with an actor identifier, as in ADR 0005. Platform Administrator accounts and access grants (ACC-01, ACC-20 to ACC-22) are not in the first slice.

### Per-user permission grants

- The permission catalog is closed: `departure_management`, `supplier_arrangements`, `financial_records`, `passport_access`, `reseller_relationships`. Agencies cannot add permissions or custom roles (ACC-05).
- Grants are rows on an agency-owned table keyed by agency, user and permission, with a same-agency composite foreign key to the user. A database check allows grants only for `staff` users.
- Only an Agency Admin grants or revokes a permission (ACC-33). Each change writes an audit event in the same transaction (ACC-23, ACC-24).
- A permission applies across the whole agency, never to particular Departures, offices or clients (ACC-08). Departure team membership grants nothing (ACC-09).

### Action catalog

Application code keeps checking a catalog, not user types or grant names. `AccessPermission` becomes a catalog of actions, each with one requirement:

| Requirement | Allowed |
| --- | --- |
| `baseline` | `agency_admin` and every `staff` user |
| `admin_only` | `agency_admin` |
| One permission | `agency_admin`, and `staff` holding that grant |
| Any of several permissions | `agency_admin`, and `staff` holding any of them, for example viewing supplier costs, commission and margin (ACC-31) |
| `reseller` | `reseller` users, within the reseller scope below |

A `reseller` user never satisfies `baseline`, `admin_only` or a permission requirement. Actions not in the catalog are refused.

### Reseller users share the account table

- Reseller users are `AgencyUser` rows with `user_type = reseller` and a required reseller relationship, enforced by a check (`reseller` if and only if the relationship is present) and a same-agency composite foreign key.
- They use the same agency-code sign-in (ACC-03), sessions, invitations, password reset, rate limits and generic failures as staff. ADR 0005's authentication invariants apply unchanged.
- An Agency Admin, or staff with Reseller relationships, invites reseller users (ACC-13).

### Reseller authorization is deny-by-default

- Reseller requests are served only from a separate controller namespace. Staff controllers refuse reseller sessions, and the reseller namespace refuses staff sessions.
- Reseller reads go through one reseller query scope: `Current.agency`, then offers published to the relationship's channel or bookings currently assigned to the relationship. Any other identifier returns not found, not forbidden, the same as a cross-agency identifier.
- Reseller views never load supplier cost, commission, margin or money-entry forms (ACC-15, ACC-31). Refused actions include recording or changing payments, refunds, supplier commitments, reports and exports.
- Every reseller action is checked server-side. Hiding a control is never the protection.

### Last Agency Admin

ADR 0005's last-administrator protection carries over to `agency_admin` unchanged (ACC-12): deactivating, demoting or removing the last active Agency Admin is refused after locking the agency, then the user, then rechecking the count.

### Tests

The charter's technical baseline applies. At minimum:

- Every catalog action has a test for each user type and for staff with and without the required grant.
- A reseller user cannot read an unassigned or other-relationship booking (not found), cannot read supplier cost, commission or margin, and cannot write money (D15).
- Grant changes are audited, and only an Agency Admin can make them.

### Migration

No real agency data has been loaded. Existing `administrator` users become `agency_admin`, `staff` become `staff` with no grants, and `viewer` users become `staff` with no grants. Seeds and fixtures are updated. Shipped actions keep working by mapping: today's administrator-only permissions become `admin_only`, `manage_departures` becomes `departure_management`, and other staff permissions become `baseline`.

## Consequences

### Positive

- Matches ACC-05 to ACC-11 directly, with no role per combination of permissions.
- Resellers reuse proven, tested authentication instead of a second copy.
- The catalog stays the single authorization check, so the shipped invariant "check the catalog, not role names" survives.

### Costs

- One account table now holds users with very different access. A missing check could expose agency data to a reseller. The separate namespace, single reseller scope and D15 tests are the mitigation.
- Every existing permission check must be re-mapped and retested.

## Alternatives rejected

### Keep roles and add one per combination

Rejected. It contradicts ACC-05 and ACC-11 and grows combinatorially.

### Keep a viewer role

Rejected. The specification has no viewer; ACC-30 gives every staff user baseline booking work.

### A separate ResellerUser model

Rejected. It would duplicate sign-in, sessions, invitations, password reset and rate limiting for no isolation gain the namespace and scope do not already give.

### Store an Agency Admin's permissions as grants

Rejected. An Agency Admin always holds every permission (ACC-07). Stored grants could drift from that.

## Implementation boundary

Implemented in charter Slice 1: user types, grants and the action catalog in step 1; reseller users, the reseller namespace and scope in step 9. Reseller relationship pause and suspension (ACC-16, ACC-17), Platform Administrator accounts and access grants, and passport access behavior are not authorized by this ADR.
