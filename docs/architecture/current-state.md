# Current application architecture

**Status:** Implemented baseline

**Scope:** Current `main`; planned commercial domains are excluded

DepartureDesk currently ships agency identity and administration only. The MVP and commercial decision register describe future product behavior; they are not claims about current persistence or routes.

## Shipped records and authorization catalog

| Record | Current responsibility |
| --- | --- |
| `Agency` | Tenant, workspace-code identity, lifecycle, locale defaults, and ownership root. |
| `Office` | Agency-owned operating and reporting context. It grants no permission. |
| `AgencyUser` | One agency-scoped login account with independent credentials, lifecycle, and access role. |
| `Session` | Authentication root and optional current-Office preference. It derives Agency through AgencyUser. |
| `AuditEvent` | Append-only evidence for supported Agency, AgencyUser, and Office administrative commands. |
| `AccessPermission` module | Closed permission catalog mapping administrator, staff, and viewer roles to capabilities. It is application code, not a persisted record. |

Invitation and password-reset token facts are stored on `AgencyUser`; they are not separate identity records.

## Tenancy and authentication

- `Agency` is the sole tenant boundary.
- Sign-in resolves normalized workspace code before the agency-scoped normalized email.
- The same email in two agencies represents two independent AgencyUsers with separate passwords and sessions.
- `Current.session` is the authentication root; `Current.agency` comes only from its AgencyUser.
- Request parameters never establish Agency tenancy.
- A foreign-Agency identifier returns not found through an Agency-scoped lookup.
- Every authenticated request rechecks that both Agency and AgencyUser are active.

## Office context

Office is operational context, not authorization. `Current.office` resolves from an active same-Agency Office stored on the Session, then the AgencyUser's active default Office, then `nil`. Changing Office changes no permission. An Agency may have no active Offices.

## Current permissions

| Permission | Administrator | Staff | Viewer |
| --- | ---: | ---: | ---: |
| View workspace | Yes | Yes | Yes |
| Select current Office | Yes | Yes | Yes |
| Manage Agency profile | Yes | No | No |
| Manage Offices | Yes | No | No |
| Manage AgencyUsers | Yes | No | No |

Application code checks named permissions, not role strings.

## Persistence and command boundaries

- Application records use PostgreSQL 18 UUIDv7 identifiers and `timestamptz` timestamps.
- The primary database and Solid Queue database are separate.
- Database constraints and triggers protect normalized identity values, same-Agency references, append-only audits, and immutable tenant identifiers.
- Consequential multi-record changes use explicit commands, transactions, lock ordering, and same-transaction audit events.
- Last-active-administrator protection locks Agency, then AgencyUser, then rechecks current state.

## Not shipped

The current application has no Client, Traveler, Household, Supplier, Departure, Supplier Arrangement, Package, Client Trip, capacity, financial ledger, document, platform-support, or MFA records. No universal `Party`, global `User`, `AgencyMembership`, or Office-based authorization layer may be restored.

See [ADR 0005](../adr/0005-agency-identity.md) for the complete implemented identity contract and [the roadmap](../planning/roadmap.md) for planned sequencing.
