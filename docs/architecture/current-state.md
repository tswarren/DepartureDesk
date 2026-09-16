# Current application architecture

**Status:** Implemented baseline

**Scope:** Current application; later commercial domains are excluded

DepartureDesk ships agency identity, administration, the complete M1 Client and Supplier directories (M1A–M1E), M2A Departure draft, activation, reference issuance, return to draft, and search, and M2B departed transitions, scheduled departed jobs, and schedule/currency/lifecycle corrections. Do not treat M2 as complete until M2C is accepted, implemented, and merged. The MVP and commercial decision register describe future product behavior; they are not claims about current persistence or routes.

## Shipped records and authorization catalog

| Record | Current responsibility |
| --- | --- |
| `Agency` | Tenant, workspace-code identity, lifecycle, locale defaults, and ownership root. |
| `Office` | Agency-owned operating and reporting context. It grants no permission. |
| `AgencyUser` | One agency-scoped login account with independent credentials, lifecycle, and access role. |
| `Session` | Authentication root and optional current-Office preference. It derives Agency through AgencyUser. |
| `AuditEvent` | Append-only evidence for supported Agency, AgencyUser, Office, ClientPerson, Client, ClientOrganization, Supplier, SupplierLocation, SupplierContact, and Departure commands. |
| `ClientPerson` | Agency-scoped person known to the directory. Not a Client, AgencyUser, or Traveler. |
| `ClientOrganization` | Agency-scoped organization known to the directory. Not a Supplier. |
| `Client` | Explicit commercial identity for exactly one Client Person or Client Organization, with an immutable `CL-` reference. |
| `ClientPersonEmailAddress`, `ClientPersonPhoneNumber`, `ClientPersonPostalAddress` | Person-owned contact points. They are not Agency User credentials. |
| `ClientOrganizationEmailAddress`, `ClientOrganizationPhoneNumber`, `ClientOrganizationPostalAddress`, `ClientOrganizationWebsite` | Organization-owned contact points. |
| `ClientOrganizationContact` | Effective-dated assignment of a Client Person to a Client Organization. Current means `ends_on IS NULL`. |
| `Supplier` | Agency-scoped organization or individual contracting identity, with an immutable `SUP-` reference and fixed category assignments. |
| `SupplierCategoryAssignment` | Required category membership for a Supplier. At least one category; `other_label` only for `other`. |
| `SupplierEmailAddress`, `SupplierPhoneNumber`, `SupplierPostalAddress`, `SupplierWebsite` | Supplier-owned contact points. |
| `SupplierLocation` | Supplier-owned operational place with optional structured address, timezone, and one location-level phone. |
| `SupplierContact` | Named person in one Supplier work context. Not a Client Person or AgencyUser. |
| `SupplierContactEmailAddress`, `SupplierContactPhoneNumber` | Contact-owned destinations. |
| `Departure` | Agency-owned dated operational root. M2A implements draft, activation, `D-` issuance, return to draft, and search. M2B adds departed, scheduled departed jobs, and corrections. Travel Program is not implemented. |
| `ReferenceSequence` | Agency-scoped `client`, `supplier`, and `departure` reference counters. Issuance does not create a missing row. |
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
| View Client directory | Yes | Yes | Yes |
| View Client contact details | Yes | Yes | No |
| Manage Client directory | Yes | Yes | No |
| View Supplier directory | Yes | Yes | Yes |
| View Supplier contact details | Yes | Yes | No |
| Manage Supplier directory | Yes | Yes | No |
| View Departures | Yes | Yes | Yes |
| Manage Departures | Yes | Yes | No |

Application code checks named permissions, not role strings.

## Persistence and command boundaries

- Application records use PostgreSQL 18 UUIDv7 identifiers and `timestamptz` timestamps.
- The primary database and Solid Queue database are separate. The M2B departed sweep reads the primary database and enqueues child jobs into the queue database with no spanning transaction. Delivery is at least once. Queue name: `departures`.
- Database constraints and triggers protect normalized identity values, same-Agency references, append-only audits, and immutable tenant identifiers.
- `btree_gist` is enabled on the primary database only for `client_org_contacts_no_overlapping_history`.
- Consequential multi-record changes use explicit commands, transactions, lock ordering, and same-transaction audit events.
- Last-active-administrator protection locks Agency, then AgencyUser, then rechecks current state.

## Not shipped

The current application has no Traveler, Household, Travel Program, Supplier Arrangement, Package, Client Trip, capacity, financial ledger, document, platform-support, or MFA records. Directory tables do not store `office_id`. No universal `Party`, global `User`, `AgencyMembership`, or Office-based authorization layer may be restored. M2C proof and M3 records are not implemented.

See [ADR 0005](../adr/0005-agency-identity.md) for the complete implemented identity contract and [the roadmap](../planning/roadmap.md) for planned sequencing.
