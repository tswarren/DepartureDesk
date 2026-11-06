# Current application architecture

**Status:** Implemented baseline, as of Slice 1 step 3b

**Scope:** Current application; later commercial domains are excluded

DepartureDesk ships agency identity and administration (ADRs 0005, 0016 and 0017), the M1 client and supplier directories, Departures as reshaped by Slice 1 step 2, and the Slice 1 step 3 supplier layer: payee accounts, supplier arrangements with documents, inventory groups, the capacity ledger, the supplier rate table (ADR 0018), and supplier deadlines with the tasks they create. The M3 and M4 layers were deleted in charter Phase 1 (D-66); tag `pre-m3-m4-deletion` holds them, and only the capacity replay and projection code was restored from it. Scope and standing are in the [first-slice charter](../planning/first-slice/first-slice-charter.md) and the [planning index](../planning/README.md).

## Shipped records and authorization catalog

| Record | Current responsibility |
| --- | --- |
| `Agency` | Tenant, workspace-code identity, lifecycle, the one agency time zone, locale defaults, the client-facing profile, footers, hold duration, installment buffer, optional logo (Active Storage, served by `AgencyLogosController`), and ownership root. |
| `Office` | Optional agency-owned assignment and reporting context with no time zone (ADR 0016). It grants no permission. |
| `AgencyUser` | One agency-scoped login account with independent credentials, lifecycle, and user type (`agency_admin`, `staff`, `reseller`). |
| `UserPermission` | A staff user's grant from the five-permission catalog; the database refuses it for any other user type (ADR 0017). |
| `Reseller` | A reseller relationship; `reseller` users belong to one. Schema only until Slice 1 step 9. |
| `AgencyDocumentInclusion` | Per agency and document family, which profile fields and footer a document shows (SET-06, SET-07). |
| `TravelerType` | The agency's ordered traveler types, seeded Adult, Child and Child 0–4 (BKG-21). |
| `Session` | Authentication root and optional current-Office preference. It derives Agency through AgencyUser. |
| `AuditEvent` | Append-only evidence for commands on Agency, AgencyUser, Office, ClientPerson, Client, ClientOrganization, Supplier, SupplierLocation, SupplierContact, Departure, TravelerType and SupplierArrangement subjects. Actions and subject types are closed catalogs. |
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
| `PayeeAccount` | A supplier's account for payments: name, currency and free-text payment instructions (SUP-02). Managed on the supplier page. |
| `Departure` | Agency-owned dated operational root. Three statuses (`sales_status`, `operating_decision`, `completion_status`) with a derived summary label and `on_sale?` (DEP-03 to DEP-05); a `DEP-` reference issued at creation (D-91); Ready to sell and Return to Draft; Mark Departed and the scheduled departed sweep (until step 11, D-83); optional hold-duration and installment-buffer overrides. Travel Program is not implemented. |
| `DepartureTeamMember` | A staff user on a Departure's team, optionally its default task owner (ACC-09, OPS-12). Grants nothing. |
| `DepartureDecision` | Append-only operating decision history: value, who, when, note (DEP-19). |
| `SupplierArrangement` | One supplier's arrangement for one Departure, with an `ARR-` reference and no versions (ADR 0018). Status `draft`, `confirmed`, `closed` or `cancelled` (SUP-11); one live arrangement per supplier per Departure. Its currency equals the Departure's. Draft is edited in place; Confirm and Discard are commands. Slice 1 builds create, edit, Confirm and Discard. |
| `ArrangementDocument` | A supplier quote, agreement, confirmation or other document kept with an arrangement, with its SHA-256 and the file in Active Storage (ADR 0019 as amended). Downloads go through `ArrangementDocumentsController`. |
| `InventoryGroup` | The smallest part of an arrangement with its own availability (INV-01): service category, representation (`unit_shells`, `capacity_pool`, `none`), availability promise, quantity, positions per unit, and local service dates with an IANA zone. Structural fields freeze at confirmation. |
| `CapacityRule` | A traveler type that takes part in a group without using a position (INV-39). |
| `UnitShell` | One cabin, room or resource, created only at confirmation (SUP-12, INV-05). Its status is derived from its capacity events (INV-38): Available or Returned to supplier until build step 6 adds allocations. |
| `CapacityPool` | One per pool group, created at confirmation and carrying the group's availability promise. |
| `CapacityEvent` | Append-only supply ledger for a group: opening at confirmation, increase, supplier release and correction, each with an idempotency key. A future-dated change applies at 11:59 p.m. agency time on its date, with the zone snapshotted (D-88). |
| `CapacityProjection` | Rebuildable current supplier capacity for numeric groups, refreshed by `CapacityProjectionRefresher` from `CapacityTimelineReplay`. On request, Rate only and no-shared-inventory groups have none (INV-04). |
| `SupplierRateLine` | One row of an arrangement's supplier rate table (SUP-35): group, occupancy position (single, or 1st to 9th guest), optional traveler type, and base fare, non-commissionable fees, taxes, discount and a commission rate or amount, in minor units of the arrangement currency. Frozen once the arrangement leaves Draft. Nothing is derived from it yet (D-75). |
| `SupplierDeadline` | A supplier deadline on an arrangement (SUP-22 to SUP-25): type, actionable or informational, description, optional group, the supplier's local date with an optional time and zone, and the resolved instant, stored when recorded or changed and never recalculated. A date-only deadline resolves to 11:59 p.m. agency time (SET-10). It prompts staff only. |
| `Task` | One work item a person must act on (OPS-01, OPS-02): source (`supplier_deadline` or `manual`), action, due instant with its local date, time and zone, an individual owner, status `open`, `in_progress`, `completed` or `waived` with the completion note or waiver reason the database requires, and its Departure. An actionable deadline has exactly one. Overdue is derived from `Clock.current`. Its history is in the Departure's audit trail. |
| `ReferenceSequence` | Agency-scoped reference counters. Issued today: `CL-` clients, `SUP-` suppliers, `DEP-` departures and `ARR-` arrangements. Formats for later namespaces are defined but not issued. Issuance does not create a missing row. |
| `AccessPermission` module | Closed action catalog: each action requires baseline, admin-only, a permission, any of several permissions, or reseller, checked against the user type and `UserPermission` grants (ADR 0017). It is application code, not a persisted record. |

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

Office is operational context, not authorization. `Current.office` resolves from an active same-Agency Office stored on the Session, then the AgencyUser's active default Office, then `nil`. Changing Office changes no permission. An Agency may have no Offices.

## Current permissions

An Agency Admin satisfies every requirement except `reseller`. Staff hold the baseline plus their granted permissions. A `reseller` user satisfies no staff requirement; reseller actions arrive in Slice 1 step 9.

| Action | Requirement |
| --- | --- |
| View workspace, select current Office | Baseline |
| Manage Agency profile, Offices, AgencyUsers and user permissions | Agency Admin only |
| View and manage the Client directory, including contact details | Baseline |
| View and manage the Supplier directory, including contact details and payee accounts | Baseline |
| View Departures | Baseline |
| Manage Departures | Departure management |
| View supplier arrangements and inventory | Baseline |
| Manage supplier arrangements, inventory, capacity and the rate table | Supplier arrangements |
| View supplier costs: the rate table and supplier documents (ACC-31) | Departure management, Supplier arrangements or Financial records |
| Use tasks: view, start, complete, waive and reopen (ACC-30) | Baseline |
| Reassign a task | Departure management |

Application code checks catalog actions, not user types or grant names. After sign-in, staff land on My tasks unless a protected page sent them to sign in (S-01).

## Persistence and command boundaries

- Application records use PostgreSQL 18 UUIDv7 identifiers and `timestamptz` timestamps.
- The primary database and Solid Queue database are separate. The departed sweep (`MarkEligibleDeparturesDepartedJob`, hourly) reads the primary database and enqueues `MarkDepartureDepartedJob` children into the queue database with no spanning transaction. Delivery is at least once. Queue name: `departures`.
- Database constraints and triggers protect normalized identity values, same-Agency references, append-only audits, decision history and capacity events, and immutable tenant identifiers.
- Supplier-layer records carry `agency_id` with composite foreign keys to their parents, so a shell, event, rule or rate line cannot point at another agency's or another arrangement's group. Triggers refuse numeric capacity records on non-numeric groups, ownership changes on capacity records, and any change to rate lines once their arrangement leaves Draft.
- Money is stored as `bigint` minor units with an explicit currency (ADR 0001). Staff-typed amounts are parsed by `MoneyInput`, which refuses more decimal places than the currency has rather than rounding.
- New domain code reads the time from `Clock.current`; tests fix it with `set_clock`.
- `btree_gist` is enabled on the primary database only for `client_org_contacts_no_overlapping_history`.
- Consequential multi-record changes use explicit commands, transactions, lock ordering, and same-transaction audit events. Arrangement commands lock agency, Departure, arrangement, then inventory groups and pools last. Mutable aggregates use optimistic `lock_version` checks.
- Capacity events carry an idempotency key, so a resubmitted supply form records once.
- Recording or changing a deadline keeps its task in step in the same transaction: an actionable deadline creates a task for the Departure's default task owner, else the recorder; a change moves the task's due date; marking it informational waives the task, and actionable again reopens it (OPS-04). Discarding a Draft arrangement waives its open tasks. Task commands lock agency, Departure, then the task.
- Last-active-administrator protection locks Agency, then AgencyUser, then rechecks current state.

## Not shipped

The application has no Traveler, Household, Travel Program, Client Trip, booking, hold, allocation, supplier reservation, cost line, schedule line, amount due, payment, commission, issued document, platform-support, or MFA records. Reseller users have schema only. Capacity reconciliation, cancelling a confirmed arrangement, effective-dated rate replacement, work groups, reminders and task creation by hand are deferred. Directory tables do not store `office_id`. No universal `Party`, global `User`, `AgencyMembership`, or Office-based authorization layer may be restored. FX is not supported; an arrangement's currency equals its Departure's.

See [ADR 0005](../adr/0005-agency-identity.md) as amended by ADRs 0016 and 0017 for the identity contract, [ADR 0018](../adr/0018-arrangement-history-by-dated-adjustment.md) for the supplier layer, and the [planning index](../planning/README.md) for standing.
