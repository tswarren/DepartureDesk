# Slice 1 step 1: foundation changes

**Status:** Draft 2026-11-04, for review before the build starts. Not implementation authority beyond the [first-slice charter](first-slice-charter.md) step 1, [ADR 0016](../../adr/0016-agency-time-zone-and-optional-offices.md), [ADR 0017](../../adr/0017-user-types-permissions-and-reseller-users.md) and D-84.

Charter step 1: permissions, reseller user type, agency profile fields, more reference types, one agency time zone. No D-cases close in this step; it is the base for D15 (step 9), D13 (step 10) and every staff screen after it.

## Choices settled for this plan (2026-11-04)

| Question | Choice |
| --- | --- |
| Reseller users in step 1 | Schema only: the reseller table, the `reseller` user type, its check and foreign key. Invitations, the reseller namespace, its query scope and S-04 stay in step 9, as ADR 0017's implementation boundary says |
| Shipped reference formats | Departures move to `DEP-` per D-84. Clients (`CL-000001`) and suppliers (`SUP-000001`) keep their shipped formats; this needs the pending entry "Client and supplier reference formats" before the code. New record types use the references table's prefixes |
| Agency profile scope | All of S-02 in step 1: profile fields, footers with Markdown preview, per-document inclusion flags, logo, traveler types, hold duration and installment buffer |

## 1. One agency time zone (ADR 0016)

- Drop `offices.default_timezone`. Remove every reader: the dashboard office line, the office index, show and new views, the office form and `ProvisionAgency`'s `office_timezone`.
- `ProvisionAgency` no longer creates an office or takes office arguments. An agency may have zero offices.
- `departures.responsible_office_id` becomes optional and leaves `departures_activation_completeness`. `CreateDeparture` stops copying the current office. The responsible user stays required for activation until the Departure team replaces it.
- Session office preference and default office stay as display preferences only.

## 2. User types and per-user permissions (ADR 0017)

Schema:

- `agency_users.access_role` becomes `user_type` with values `agency_admin`, `staff` and `reseller`. Migration mapping: `administrator` to `agency_admin`; `staff` and `viewer` to `staff` with no grants.
- New `user_permissions`: `agency_id`, `agency_user_id`, `permission`, `user_type`, timestamps. Unique on agency, user and permission. `permission` is checked against the five-value catalog. The row carries `user_type` with a check that it is `staff`, and a composite foreign key `(agency_id, agency_user_id, user_type)` to `agency_users (agency_id, id, user_type)` with `ON UPDATE CASCADE`. Changing a staff user with grants to another type then fails in the database, so the command must remove the grants first, in the same transaction.

Action catalog: `AccessPermission::CATALOG` maps each action to one requirement (`baseline`, `admin_only`, one permission, any of several, or `reseller`). `AgencyUser#can?` checks the requirement against the user type and grants. A `reseller` user satisfies no staff requirement, so until step 9 every staff action refuses a reseller session.

Shipped actions, re-mapped per ADR 0017's migration:

| Action | Today | Step 1 |
| --- | --- | --- |
| `view_workspace`, `select_office_context` | administrator, staff, viewer | `baseline` |
| `view_client_directory`, `view_client_contact_details`, `manage_client_directory` | all or administrator and staff | `baseline` |
| `view_supplier_directory`, `view_supplier_contact_details`, `manage_supplier_directory` | all or administrator and staff | `baseline` |
| `view_departures` | administrator, staff, viewer | `baseline` |
| `manage_departures` | administrator, staff | `departure_management` |
| `manage_agency_profile`, `manage_offices`, `manage_agency_users` | administrator | `admin_only` |
| `manage_user_permissions` (new) | | `admin_only` |

Behavior:

- S-03 Users and permissions: each user's type and the five permissions as checkboxes for staff; Agency Admins show all five as held and not editable. Only an Agency Admin changes types or grants. Each change writes one audit event in its transaction (ACC-23, ACC-24).
- Last Agency Admin protection carries over unchanged (ACC-12): lock agency, then user, recheck the count, refuse.
- Invitations choose `agency_admin` or `staff`; `reseller` is refused until step 9.
- AGENTS.md invariants 5 to 7, 10 and 11 and the Canonical domain language table change in the same pull request.

## 3. Reseller schema (ADR 0017, schema only)

- New `resellers`: `agency_id`, `name`, `status` (`active`, `booking_paused`, `suspended`, `ended`), `direct_contact_allowed` (default false), `lock_version`, timestamps (ACC-13, ACC-16, DOC-08).
- `agency_users.reseller_id`, with a check that it is present exactly when `user_type = 'reseller'` and a same-agency composite foreign key.
- No reseller controllers, invitations, screens or commands in this step. Pause and suspension behavior is not authorized (ADR 0017).

## 4. Agency profile (S-02)

Only an Agency Admin edits it (ACC-33, SET-13); each save writes one audit event with changed fields.

| Field | Rule |
| --- | --- |
| Display name, contact email | Optional to save; required to generate client documents, never for activation or Ready to sell (SET-04) |
| Agency contact name, legal or business name, phone, mailing address | Optional (SET-04). Mailing address uses the shipped postal-address column shape |
| Seller-of-travel disclosure | One multiline text field; line breaks kept; no legal validation (SET-05) |
| Inclusion flags | One per profile field per document family (confirmations, invoices, receipts, statements), with the SET-06 defaults |
| Confirmation footer, financial-document footer | Limited Markdown with an editor preview, rendered through `commonmarker` and an allow-list sanitizer (SET-07) |
| Logo | Optional upload (SET-08). Needs Active Storage's tables, which are not installed yet; framework routes stay off and the logo is served through an authorized controller (ADR 0019) |
| Time zone, default currency | Shipped fields, kept |
| Hold duration | Whole calendar days, default 2 (BKG-09) |
| Installment buffer | Whole days, default 14 (CMN-10) |

Traveler types (BKG-21) are an agency-owned list on S-02: `traveler_types` with `agency_id`, `name`, `position`, `status`, seeded with Adult, Child and Child 0–4 for each new agency. Whether a type uses capacity is a capacity rule (step 3, INV-39), not a traveler-type field. Inactivating a type never changes a booking.

Changing a default affects only new or explicitly amended work (SET-11, SET-14). No step 1 record copies a default yet.

## 5. Reference types (REF-02, REF-03, REF-05, D-84)

| Namespace | Format | Used from |
| --- | --- | --- |
| `departure` | `DEP-` and at least 4 digits (D-84) | Now; replaces `D-000001` |
| `client` | `CL-000001`, unchanged | Pending entry |
| `supplier` | `SUP-000001`, unchanged | Pending entry |
| `trip` | `T-` and at least 5 digits; bookings are the trip reference plus a sequence, such as T-24817-2 (REF-04) | Step 6 |
| `client_payment` | `PAY-`, at least 5 digits | Step 8 |
| `arrangement` | `ARR-`, at least 4 digits | Step 3 |
| `supplier_payment` | `SPY-`, at least 4 digits | Step 8 |
| `confirmation`, `invoice`, `receipt` | `CNF-`, `INV-`, `RCP-`, at least 5 digits; versions add `-v2` (REF-05) | Step 10 |

- Widths follow the references table's examples. A number past the minimum width widens rather than failing. The shipped 1,000,000 limit stays only for the six-digit client and supplier formats.
- Invoice and receipt numbers run without gaps (REF-05): the number is issued in the same transaction as the record, under the sequence row lock. Other sequences may have gaps.
- Out of this step: starting numbers (REF-07), alternate references (REF-08) and the reference search rules (REF-11 to REF-17).

## Not in this step

Reseller sign-in landing, invitations and namespace (step 9); Departure team; office behavior beyond today; MFA; Platform Administrator accounts and access grants; passport access behavior (the grant exists, but nothing gates on it yet); "created by" on client records (D-78, steps 8 and 9).

## Tests

- Catalog matrix: every action for `agency_admin`, for `staff` with and without its grant, and for `reseller` (always refused) (ADR 0017).
- Grants: only an Agency Admin grants or revokes; each change is audited; the database refuses a grant for a non-staff user; changing a user's type removes their grants or is refused.
- Last Agency Admin protection for deactivate, demote and remove.
- Reseller schema: the check and same-agency foreign key refuse a reseller without a reseller, a staff user with one, and a cross-agency reseller.
- Agency profile: admin-only edits; SET-06 defaults; disclosure line breaks kept; footer Markdown renders only the allowed elements and strips the rest; logo download only through the authorized controller; traveler types seeded for a new agency.
- Time zone: an agency provisions without an office; a Departure activates without a responsible office; no code reads an office time zone.
- References: `DEP-0001` format and widening; each new namespace's prefix and minimum width.
- The Alpha seed and existing directory and Departure tests are updated for these changes; the full suite and system tests pass at 1400px and 375px for S-02 and S-03 (UI acceptance).

## Build order

One pull request for the step (AGENTS.md working rules), in reviewable commits:

1. Time zone and optional offices.
2. User types, grants and the action catalog, with the re-mapped checks.
3. Reseller schema.
4. Reference namespaces and the `DEP-` format.
5. Agency profile fields, inclusion flags and footers.
6. Traveler types.
7. Logo (installs Active Storage's tables).
8. S-02 and S-03 screens, AGENTS.md invariants and vocabulary, and the planning index.
