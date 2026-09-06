Phase 2C is the role-profile slice: make existing parties commercially usable as clients and suppliers without creating another identity model.

Implement 2C as four mergeable PRs (2C.1 role foundation, 2C.2 client operations, 2C.3 supplier operations, 2C.4 selector and identifiers). Do not land the whole slice in one review. External identifiers come last because their uniqueness contracts are the most delicate.

Do not branch until PR 12 is green and merged.

# Phase 2C — Client and supplier roles

## Status

**2C.1 through 2C.4 are implemented** in this repository (role profiles, advisors, client and supplier directories, supplier categories, role-aware selector, and external identifiers). Merge, party deactivation, fuzzy search, travelers, payers, arrangements, and posted money remain out of scope.

---

## 1. Goal

Add reusable client and supplier roles to the shared party directory.

A person, household, or organization is still created once. Phase 2C adds agency-owned role profiles that determine where that party may participate in later commercial workflows.

Phase 2C must demonstrate:

* An existing organization can be both a client and supplier.
* An existing person can be a client or independent supplier.
* An existing person related to a supplier organization remains a supplier contact without becoming a supplier.
* Adding, deactivating, or reactivating a role does not create, deactivate, or replace the underlying party.
* No traveler, organizer, payer, responsible-client, arrangement, or financial record is created.

---

## 2. Locked decisions

### 2.1 Roles extend parties

Use separate one-to-one `ClientProfile` and `SupplierProfile` records with their own UUIDv7 primary keys.

Do not copy the 2A shared-PK kind-profile pattern. A party may hold both roles, so the profile primary key is not `parties.id`.

Do not add:

* `client` or `supplier` booleans to `parties`
* Separate client, supplier, employee, or supplier-contact identity tables
* Active Record STI
* Generated or operator-entered `client_reference` / `supplier_reference` columns
* Traveler, payer, organizer, or responsible-client roles

A party may hold both profiles simultaneously.

### 2.2 Eligible party kinds

| Role     | Person | Household | Organization |
| -------- | -----: | --------: | -----------: |
| Client   |    Yes |       Yes |          Yes |
| Supplier |    Yes |        No |          Yes |

Store `party_kind` on both role tables. Enforce it with a check constraint and a composite foreign key to `parties (id, agency_id, party_kind)`.

* Client: `person`, `household`, or `organization`
* Supplier: `person` or `organization`

A person receives a supplier profile only when the agency contracts with that person directly. Employment, affiliation, or being an organization contact does not imply supplier status.

### 2.3 Role lifecycle

Use `active` and `inactive` as the Phase 2C role states.

Each profile contains:

* `status`
* `deactivated_at`
* `deactivated_by_membership_id`
* `deactivation_reason`
* `lock_version`

Deactivation requires a reason. Reactivation clears the deactivation disposition and produces an audit event.

A deactivated profile is reactivated rather than recreated. The unique party/profile relationship remains permanent. Creating a role when an inactive profile already exists is a reactivation choice or conflict; it must not insert a second row.

Do not deactivate the party when a role is deactivated. Inactive parties cannot receive a new active role, even though party deactivation itself is Phase 2D.

Use the same state-bearing projection as responsible office:

* Store nullable `party_status`.
* Active profile ⇒ `party_status = 'active'` and composite FK `(party_id, agency_id, party_status)` → unique `parties (id, agency_id, status)`.
* Inactive profile ⇒ `party_status IS NULL` (`MATCH SIMPLE` skips the state-bearing FK).
* Unique `(id, agency_id, status)` on `parties`.

Role create and reactivation set the projection to `active` against a currently active party. Role deactivation nulls it. PostgreSQL rejects a party `active → deactivated` transition while any active profile still holds the `active` projection. Phase 2D party deactivation must keep that race boundary.

`status` changes only through lifecycle commands. `UpdateClientProfile` and `UpdateSupplierProfile` must not accept or persist a status change.

`agency_id`, `party_id`, and `party_kind` are immutable at both the Rails and database boundaries.

### 2.4 Responsible office

Responsible office is an operational responsibility attribute, not an authorization boundary.

* Store it on each role profile.
* Directory visibility remains agency-wide. Do not filter client or supplier lists by `Current.office`.
* Offer active offices when assigning, changing, or reactivating a role.
* Do not silently reassign profiles when an office becomes inactive.
* Later office-owned workflows must independently check the acting membership’s office access.
* Do not add office-specific supplier default rows in 2C. Optional identifier office context is not a second supplier profile.

Active profiles require an active responsible office. `responsible_office_id` is `NOT NULL` on every profile row. Roles are created active with an office. Deactivation retains that office and nulls the status projection. An inactive profile may reference an inactive office because the projection is null.

Use the 2A state-bearing foreign-key pattern, not a lookup trigger:

* Tenancy FK `(responsible_office_id, agency_id)` → `offices (id, agency_id)` on every row.
* Store nullable `responsible_office_status`.
* Active profile ⇒ `responsible_office_status = 'active'` and composite FK `(responsible_office_id, agency_id, responsible_office_status)` → unique `offices (id, agency_id, status)`.
* Inactive profile ⇒ `responsible_office_status IS NULL` (`MATCH SIMPLE` skips the state-bearing FK).

Role deactivation nulls the projection in the same transaction. Reactivation sets it back to `active` against a currently active office.

Command protocol:

* Role create and reactivation lock the selected office row before confirming it is active.
* An office change locks both the existing and replacement offices in stable UUID order, then confirms the replacement is active.
* `ChangeOfficeStatus` to inactive locks that same office row before the transition.
* PostgreSQL rejects the inactive office transition while any active profile still holds the `active` projection.
* Commands still return a friendly count and a bounded sample of profile names (five), not an unbounded list.

### 2.5 Current advisor

`ClientProfile.primary_advisor_membership_id` is the authoritative current advisor. It points at `AgencyMembership`, not merely the advisor’s person. The advisor is not required to hold an assignment to the profile’s responsible office.

A current advisor must be an active membership of the same agency. Invited memberships are not assignable.

Use a state-bearing FK on the **current** profile pointer only:

* Add unique `(id, agency_id, status)` on `agency_memberships`.
* Store `primary_advisor_membership_status` on `client_profiles`.
* Check: both advisor columns null, or membership present and projection exactly `active`.
* Composite FK `(primary_advisor_membership_id, agency_id, primary_advisor_membership_status)` → unique `agency_memberships (id, agency_id, status)`.

History rows FK to `(advisor_membership_id, agency_id)` without a status projection. A former advisor may later be suspended.

`SuspendMembership` is the tenant command that takes a membership from `active` to non-active. `RevokeInvitation` is `invited → revoked` and is not an advisor-status transition. Agency suspend leaves memberships `active` and destroys sessions; it is not an advisor-status transition.

`SuspendMembership` must still perform a friendly dependency check and return the profiles that require reassignment. Translate the state-bearing FK violation into that same conflict. Do not clear advisors silently.

Client deactivation ends the current open assignment in the same transaction, using that command’s actor and deactivation reason. Do not prompt for a second ending reason. It also clears the current advisor pointer and status projection. Client reactivation and membership reactivation do not restore a former advisor.

### 2.6 Advisor history

Advisor assignment history is retained and identity-immutable. It is not strictly append-only: ending an assignment may fill `effective_until` and ending disposition **once**.

2C does not ship advisor correction. Do not add `record_status`, `superseded`, `voided`, or 2B correction columns. Every retained row is a real assignment, including genuinely ended historical rows. When correction is later required, add the full 2B supersession shape in a forward migration and narrow the exclusion to valid rows.

* Advisor changes take effect today in the agency timezone.
* Do not support future-scheduled advisor changes in 2C.
* Dates are 2B `DirectoryDate` semantics: half-open `[effective_from, effective_until)`.
* `ended_at` is the command timestamp, not a second interval.
* Ending actor and reason are complete together with `effective_until`.
* `advisor_membership_id` and `effective_from` are immutable.
* Reassignment ends the previous open interval and creates the next row in one transaction.
* Clearing an advisor ends the current open assignment and clears the profile FK.
* The current open history row (null `effective_until`) must agree with `ClientProfile.primary_advisor_membership_id`.
* Commands write the profile pointer and history together. Do not update them independently.

No overlapping intervals. Use a GiST exclusion over all retained rows:

```sql
EXCLUDE USING gist (
  agency_id WITH =,
  client_profile_id WITH =,
  daterange(effective_from, effective_until, '[)') WITH &&
)
```

Do not rewrite advisor, start date, or profile ownership in place.

### 2.7 No internal references

Do not add `client_reference`, `supplier_reference`, or a sequence service.

Lookup uses:

* Party UUID
* Name and alternate names
* Contact details
* Relationships
* Role filters
* Typed external identifiers

Any future human-readable internal reference must complete ADR 0004’s issuance matrix.

User-facing identity is the party. Routes, forms, selector results, and directory rows are keyed by party UUID, not profile UUID.

### 2.8 Directory commands keep the 2B actor contract

Interactive requests require `Current.user`. After the agency lock, that actor must have a usable membership on the affected active agency. Do not rely on `administrator?` alone.

Privileged execution remains the explicit 2B opt-in for seeds, migrations, recovery, and controlled maintenance:

* `privileged: true` plus a non-blank `actor_identifier`
* No user actor on that path
* Never infer privileged because no user was supplied
* Same tenant validation and audit coverage after locks
* Do not invent a platform user

Privileged directory commands continue to attribute membership-backed disposition columns through the existing 2B rule (a membership of this agency). Nested commands use a documented locked primitive and must not reacquire locks.

### 2.9 Explicitly out of 2C

* Party deactivation, merge, duplicate scoring, and `pg_trgm` fuzzy search (Phase 2D)
* Advisor-assignment correction / supersession
* Exceptional identifier-uniqueness override
* `UpdateExternalIdentifier`
* Identifier office context
* Office-specific supplier default rows
* Numeric commission rates or `Money` objects
* Free-text or `other` supplier categories
* Traveler, payer, organizer, responsible-client, arrangement, or financial records
* Generated client or supplier references

---

## 3. Persistence model

### 3.1 `client_profiles`

| Column                               | Contract                                          |
| ------------------------------------ | ------------------------------------------------- |
| `id`                                 | UUIDv7 primary key; not `parties.id`              |
| `agency_id`                          | Required                                          |
| `party_id`                           | Required; unique with agency                      |
| `party_kind`                         | `person`, `household`, or `organization`          |
| `status`                             | `active` or `inactive`                            |
| `party_status`                       | `active` while profile active; `NULL` when inactive |
| `client_since_on`                    | Optional date                                     |
| `responsible_office_id`              | Required; `NOT NULL` on every row                 |
| `responsible_office_status`          | `active` while profile active; `NULL` when inactive |
| `primary_advisor_membership_id`      | Optional current advisor                          |
| `primary_advisor_membership_status`  | `active` when advisor present; else `NULL`        |
| `communication_preference`           | Controlled value                                  |
| `servicing_restrictions`             | Optional bounded internal text                    |
| `billing_restrictions`               | Optional bounded internal text                    |
| Deactivation fields                  | Complete together                                 |
| `lock_version`                       | Required                                          |
| Timestamps                           | `timestamptz`                                     |

Communication values:

* `no_preference`
* `email`
* `phone`
* `postal_mail`

This is display guidance. It does not write a contact fact and does not override suppression, deactivation, or absence of an eligible destination. Reuse 2B `current_eligible_primaries_on`. 2B uniqueness is per contact kind, so a party may have a general primary email, phone, and postal address at once.

Display:

* Preference `email`, `phone`, or `postal_mail` → that kind’s current eligible **general** primary.
* Preferred kind has none → “Preferred contact unavailable.” Other current general primaries may be listed, labeled by kind. Do not treat another kind as satisfying the preference.
* `no_preference` → all current eligible general primaries, labeled by kind. Never pick an arbitrary winner.

Required database contracts:

* Unique `(party_id, agency_id)`
* Unique `(id, agency_id)` for child FKs
* Composite FK `(party_id, agency_id, party_kind)` → `parties (id, agency_id, party_kind)`
* State-bearing FK `(party_id, agency_id, party_status)` → unique `parties (id, agency_id, status)`
* Tenancy FK `(responsible_office_id, agency_id)` → `offices (id, agency_id)`; `responsible_office_id` is `NOT NULL`
* State-bearing FK `(responsible_office_id, agency_id, responsible_office_status)` → unique `offices (id, agency_id, status)`
* State-bearing FK `(primary_advisor_membership_id, agency_id, primary_advisor_membership_status)` → unique `agency_memberships (id, agency_id, status)`
* Unique `(id, agency_id, status)` on `offices`, `agency_memberships`, and `parties`
* Named status, lifecycle-completeness, projection-completeness, and nonnegative-lock constraints
* Trigger preventing `agency_id`, `party_id`, and `party_kind` changes

Do not duplicate contact details or party names on the profile.

### 3.2 `client_advisor_assignments`

| Column                   | Contract                                      |
| ------------------------ | --------------------------------------------- |
| `id`                     | UUIDv7                                        |
| `agency_id`              | Required                                      |
| `client_profile_id`      | Required                                      |
| `advisor_membership_id`  | Required                                      |
| `effective_from`         | Required date                                 |
| `effective_until`        | Nullable exclusive end; fillable once             |
| Ending fields            | Complete together with `effective_until`          |
| `lock_version`           | Required                                          |
| Timestamps               | `timestamptz`                                     |

Do not add `record_status` or correction columns in 2C.

Required database contracts:

* Composite FK `(client_profile_id, agency_id)` → `client_profiles (id, agency_id)`
* Composite FK `(advisor_membership_id, agency_id)` → `agency_memberships (id, agency_id)` without a status projection
* GiST exclusion over all retained rows; no overlapping intervals
* Range-order and ending-completeness checks matching 2B
* Identity columns (`advisor_membership_id`, `effective_from`, agency, profile) are immutable

### 3.3 `supplier_profiles`

| Column                      | Contract                                          |
| --------------------------- | ------------------------------------------------- |
| `id`                        | UUIDv7 primary key; not `parties.id`              |
| `agency_id`                 | Required                                          |
| `party_id`                  | Required; unique with agency                      |
| `party_kind`                | `person` or `organization`                        |
| `status`                    | `active` or `inactive`                            |
| `party_status`              | `active` while profile active; `NULL` when inactive |
| `responsible_office_id`     | Required; `NOT NULL` on every row                 |
| `responsible_office_status` | `active` while profile active; `NULL` when inactive |
| `default_currency`          | Required uppercase three-letter code              |
| `payment_term_notes`        | Optional, bounded, non-authoritative              |
| `commission_notes`          | Optional, bounded, non-authoritative text         |
| `booking_instructions`      | Optional, bounded                                 |
| `payment_instructions`      | Optional, bounded                                 |
| `cancellation_policy_notes` | Optional, bounded, general only                   |
| `portal_url`                | Optional HTTPS URL; no credentials                |
| Deactivation fields         | Complete together                                 |
| `lock_version`              | Required                                          |
| Timestamps                  | `timestamptz`                                     |

The database must enforce:

* Unique `(party_id, agency_id)` and unique `(id, agency_id)`
* Composite FK `(party_id, agency_id, party_kind)` → `parties (id, agency_id, party_kind)` with `party_kind IN ('person', 'organization')`
* Same party-status and office tenancy and state-bearing FKs as client profiles
* Immutable agency, party, and party-kind identity
* Complete lifecycle and projection disposition
* `default_currency ~ '^[A-Z]{3}$'` like `agencies.default_currency`

`default_currency` copies the agency default at create time and then persists independently. It is a directory default, not posted money. Do not wrap it in `Money`. Do not use the `countries` gem as a currency authority. Do not add a numeric commission rate in 2C.

`portal_url` is normalized and validated as HTTPS. Reject credentials, userinfo, and embedded passwords.

### 3.4 `supplier_service_category_assignments`

Join model, not a serialized array:

* `id`
* `agency_id`
* `supplier_profile_id`
* `category_code`
* timestamps

Enforce uniqueness on `(agency_id, supplier_profile_id, category_code)` and composite FK `(supplier_profile_id, agency_id)` → `supplier_profiles (id, agency_id)`.

`RemoveSupplierServiceCategory` hard-deletes the join row. The audit event is the retained history. Re-adding inserts a new row. Do not add assignment status, deactivation disposition, or reactivate-on-readd.

Initial vocabulary (no `other`, no free-text label):

* `accommodation`
* `air`
* `cruise`
* `rail`
* `ground_transportation`
* `tour_operator`
* `activity`
* `venue`
* `dining`
* `insurance`
* `destination_management`

These describe general supplier capability. They do not create service inventory, supplier arrangements, or service providers. Agency-defined categories are out of 2C.

---

## 4. External identifiers

Avoid a polymorphic owner because it cannot provide the composite database foreign keys this project requires.

Use `external_identifiers` with:

* `id`
* `agency_id`
* Nullable `party_id`
* Nullable `client_profile_id`
* Nullable `supplier_profile_id`
* `identifier_type`
* `issuer`
* `original_value`
* `normalized_value`
* `normalization_version`
* `office_id` — present as a column, `NULL` for every 2C row
* `status`
* `source`
* Deactivation disposition
* `lock_version`
* timestamps

A named check constraint requires exactly one owner column. Each possible owner receives a composite same-agency FK.

No 2C identifier type allows office context. Enforce `office_id IS NULL` for every row. Keep a registry flag so a later type can opt in; do not ship unused office-context uniqueness in 2C.

Normalized value is a versioned projection of original value plus the stored `normalization_version`. Do not rewrite original values.

### Identity and correction

These fields are immutable after create:

* Owner (`party_id` / `client_profile_id` / `supplier_profile_id`)
* Identifier type
* Issuer/namespace
* Original value
* Agency
* Normalization version associated with the stored projection

A wrong value or issuer is a retained correction: deactivate the erroneous identifier with a reason, then create the replacement. Do not add `superseded_by` lineage in 2C. Unique indexes apply to active rows, so the corrected value may be inserted after deactivation.

Do not add `UpdateExternalIdentifier`. `source` is set at create. If source later needs a change, add a narrow command then; do not reopen identity fields.

Identifiers owned by an inactive role remain retained. They are shown on that role’s inactive history, not as identifiers of an active client or supplier. Party-owned identifiers (`legacy_party_id`) remain visible on the party regardless of role status. Identifier lists use the same current/history separation as contacts.

### Identifier registry

Define identifier behavior in a code-owned registry before writing SQL. Each type declares:

* Allowed owner type
* Display label
* Whether issuer is required
* Normalization rule
* Uniqueness scope
* Whether office context is allowed
* Whether matching is advisory or contractually unique

Do not let users choose uniqueness rules. The Ruby registry cannot be the only enforcement.

SQL must mirror the registry:

* Named check mapping each identifier type to its allowed owner column and forbidding the others
* Named check requiring issuer for per-issuer types
* Named check `office_id IS NULL` for all 2C types
* Named partial unique index for every contractually unique type, scoped per issuer within agency on active rows
* A test that the Ruby registry type codes and the SQL type list are the same set

Types whose uniqueness is per issuer within an agency require issuer. Reactivating a deactivated contractually unique value that now collides is a conflict.

Initial types:

| Type                      | Owner            | Issuer   | Office | Uniqueness               |
| ------------------------- | ---------------- | -------- | ------ | ------------------------ |
| `legacy_party_id`         | Party            | Optional | No     | Advisory                 |
| `legacy_client_id`        | Client profile   | Required | No     | Per issuer within agency |
| `external_crm_id`         | Client profile   | Required | No     | Per issuer within agency |
| `supplier_account_number` | Supplier profile | Required | No     | Per issuer within agency |
| `supplier_portal_id`      | Supplier profile | Required | No     | Per issuer within agency |
| `industry_supplier_code`  | Supplier profile | Required | No     | Per issuer within agency |

Do not claim global or cross-agency uniqueness. Do not add tax identifiers, credentials, portal passwords, passport data, or payment-account details.

Advisory types do not receive unique indexes. 2C does not implement duplicate scoring or merge; the unique indexes still exist so 2D cannot rediscover uniqueness later.

---

## 5. Commands

Keep cross-record changes out of controllers and callbacks. Inherit `DirectoryCommand`.

### Client commands

* `CreateClientProfile`
* `UpdateClientProfile`
* `DeactivateClientProfile`
* `ReactivateClientProfile`
* `AssignClientAdvisor`
* `ClearClientAdvisor`

### Supplier commands

* `CreateSupplierProfile`
* `UpdateSupplierProfile`
* `DeactivateSupplierProfile`
* `ReactivateSupplierProfile`
* `AssignSupplierServiceCategory`
* `RemoveSupplierServiceCategory`

### Identifier commands

* `AddExternalIdentifier`
* `DeactivateExternalIdentifier`
* `ReactivateExternalIdentifier`

Do not add `UpdateExternalIdentifier`.

`UpdateClientProfile` and `UpdateSupplierProfile` may change directory guidance, communication preference, currency, portal URL, and responsible office. They must not change `status`, `agency_id`, `party_id`, or `party_kind`.

`RemoveSupplierServiceCategory` deletes the join row and writes an audit event.

Every command should:

1. Lock the agency.
2. Lock affected parties, then profiles, then other mutated rows, in stable UUID order.
3. Lock a known office or advisor membership by UUID when that row’s active status is required. An office change locks both offices in UUID order.
4. Reload and revalidate tenancy and lifecycle.
5. Validate the acting membership, or the privileged actor shape.
6. Perform the change and audit in one transaction.
7. Translate named uniqueness, exclusion, and state-bearing FK violations into stable command conflicts.

`AssignClientAdvisor` / `ClearClientAdvisor` lock agency, then party, then profile, then the advisor membership.

`SuspendMembership` keeps user → agency → membership. It must not reacquire directory locks; it checks current-advisor dependencies under the membership lock and relies on the state-bearing FK as the race boundary.

Creating a role for an inactive existing profile returns a reactivation choice or conflict. It must not insert a second profile.

Supplier-contact purpose assignment must reject an inactive or ended relationship. Reuse 2B commands; do not bypass them.

---

## 6. Authorization

Reuse Foundation 1 roles. Do not introduce granular directory RBAC.

| Action                                | Staff | Administrator |
| ------------------------------------- | ----: | ------------: |
| View client/supplier directories      |   Yes |           Yes |
| Add or edit a role                    |   Yes |           Yes |
| Change responsible office             |   Yes |           Yes |
| Assign or clear advisor               |   Yes |           Yes |
| Manage service categories             |   Yes |           Yes |
| Manage permitted external identifiers |   Yes |           Yes |
| Deactivate/reactivate a role          |   Yes |           Yes |
| View administrator-only party notes   |    No |           Yes |

Administrator-only notes remain the 2B rule. Merge and exceptional identifier remediation are not 2C actions.

All cross-agency IDs must resolve as not found, not forbidden.

---

## 7. User experience

### 7.1 Navigation and identity

Directory remains the identity home. Role create, edit, deactivate, and reactivate start from `/directory/parties/:party_id`. Do not make the normal workflow re-enter identity details.

`/directory/clients` and `/directory/suppliers` are role-filtered lists whose row identity is the party UUID.

Do not add a primary-nav Clients item that looks like a separate CRUD model. Replace the disabled Suppliers placeholder with a live link only when that route ships.

### 7.2 Party overview

Add a “Roles” panel showing:

* Client: active, inactive, or not assigned
* Supplier: active, inactive, ineligible, or not assigned
* Responsible office, including when that office is inactive on an inactive profile
* Primary advisor for clients
* Primary supplier categories
* Add, view, reactivate, or deactivate actions

Household pages must not render an “Add supplier role” action.

### 7.3 Client directory

Show:

* Party name and kind
* Role status
* Responsible office
* Primary advisor
* Communication preference
* Current eligible general primaries, following the preference display rules in §3.1

Filters: active/inactive, party kind, responsible office, advisor. Paginate from the start. Do not filter automatically by `Current.office`.

Advisor assignment uses a membership picker of active same-agency memberships, showing the linked person display name. It is not a party-selector mode.

### 7.4 Supplier directory

The supplier directory is a role-filtered view, not a separate CRUD identity surface.

Show:

* Supplier name and party kind
* Status
* Service categories
* Responsible office
* General primary contacts, labeled by kind (email, phone, postal address)
* Primary booking contact
* Primary accounting contact
* Default currency

Those contacts are derived, not stored on `supplier_profiles`:

* General primaries: 2B `current_eligible_primaries_on` for purpose `general`, listed by contact kind. Do not pick a single unlabeled “the” primary.
* Primary booking and accounting contacts: current valid 2B relationship purposes on a current unended relationship

Supplier detail reuses party identity, contact information, organization relationships, booking/accounting purposes, and notes filtered through existing note authorization. Then add a supplier-role panel for categories and directory defaults.

Do not create an “Add supplier contact” identity form. Find or create a person once through existing party creation, then establish the existing 2B relationship:

* Use `organization_contact` or `organization_affiliation` plus booking/accounting purposes.
* Affiliation and contact remain mutually exclusive. If the person is already affiliated, assign purposes on that relationship; do not insert a second contact row.
* Purpose assignment must reject an inactive or ended relationship.
* Creating the relationship must not create a supplier profile on the person.

### 7.5 Role-aware selector

Build one reusable query/service and one reusable UI component with modes:

* Any party
* Client
* Active client
* Supplier
* Active supplier
* Supplier contact
* Team member
* Person only
* Organization only
* Household allowed/not allowed

The selector returns a party UUID plus relevant role/profile metadata. It must not return a client or supplier profile ID as the identity value.

Phase 2C ships the query contract and UI with prefix/name/role filters. It does not ship the 2D `pg_trgm` fuzzy engine.

Phase 2C uses it for role-adjacent and supplier-contact workflows. Traveler, organizer, payer, and responsible-client consumers remain future integrations.

---

## 8. Notes and instructions

Do not add another universal note system.

Use existing party notes for general internal directory notes. Keep these profile fields narrowly purposeful and length-bounded:

* Client servicing restrictions
* Client billing restrictions
* Supplier booking instructions
* Supplier payment instructions
* Supplier general cancellation notes
* Supplier commission notes

They are current directory guidance, not immutable contractual facts. Arrangement-specific terms belong to supplier arrangements later.

The existing note-content policy still applies. These text fields use the same best-effort credential/PAN screening. Do not copy those bodies or complete external identifier values into audit JSON.

Paginate identifier lists and role directories from the start. Identifier lists use the same current/history split as contacts. Identifiers on an inactive role are history, not current client/supplier identifiers.

---

## 9. Auditing

Extend the audit subject allowlist for:

* `ClientProfile`
* `ClientAdvisorAssignment`
* `SupplierProfile`
* `SupplierServiceCategoryAssignment`
* `ExternalIdentifier`

A subject must belong to the event agency. Unknown subject types raise.

Audit:

* Role creation, update, deactivation, and reactivation
* Responsible-office changes
* Advisor assignment, reassignment, and clearing
* Supplier-category assignment and removal
* External-identifier creation, deactivation, and reactivation

Audit payloads should contain IDs, status transitions, category codes, and changed field names. Do not copy restriction/instruction bodies or complete external identifier values.

Exceptional identifier override and merge are not 2C audit actions.

---

## 10. Testing

### Database-boundary tests

Prove rejection of:

* Cross-agency role party, office, advisor membership, or identifier owner
* Household supplier profile, including `insert_all!` / SQL
* Client or supplier `party_kind` mismatch
* Duplicate role profile
* Null `responsible_office_id`
* Active profile with missing or inactive responsible-office projection
* Active profile with missing or inactive party-status projection
* Active profile inserted against a deactivated party
* Inactive profile that still holds an `active` office, party, or advisor projection
* Current advisor pointing at a non-active membership
* Membership `active → suspended` while it is a current advisor
* Office `active → inactive` while it is an active profile’s responsible office
* Party `active → deactivated` while it is an active profile’s party
* Overlapping advisor intervals, including two closed ranges
* External identifier attached to the wrong owner or agency
* Identifier type used with an ineligible owner or missing required issuer
* Identifier `office_id` present
* Contractually unique identifier collision and colliding reactivation
* Ruby identifier registry type codes diverging from the SQL type list
* Incomplete lifecycle or projection disposition
* Mutation of immutable profile identity columns

### Command tests

Cover:

* Add client role to all three party kinds
* Add supplier role to person and organization
* Reject household supplier
* Deactivate and reactivate the same profile row
* Preserve party status throughout role lifecycle
* Reject an active role on an inactive party
* Creating a role when an inactive profile exists returns reactivation, not a second row
* Assign, change, and clear advisor; history agrees with the profile pointer
* Block `SuspendMembership` while currently assigned, with a profile list
* Concurrent advisor assignment versus membership suspension
* Concurrent role activation versus office deactivation
* Reactivation requires a currently active office
* Change responsible office without cloning identity; both offices are locked
* `UpdateClientProfile` cannot change status
* Add/remove supplier categories; removal deletes the join row and writes audit
* Add, deactivate, and reactivate identifiers; identity fields cannot be updated
* Deactivating a wrong identifier and adding a replacement succeeds
* Inactive-role identifiers are omitted from active client/supplier identifier lists
* Reject stale `lock_version`
* Concurrent role creation produces one profile
* Concurrent advisor assignment produces one current advisor and no overlapping history

### Controller and system tests

Cover:

* Agency-wide visibility regardless of current office
* Cross-agency resources return 404
* Cross-agency `responsible_office_id` values return 404; a blank office id remains a validation error
* Office deactivation names a count and a sample of five dependent roles
* Party-keyed routes; profile UUID is not the user-facing identity
* Role-filtered directories
* Household lacks supplier action
* Supplier contact is not shown as a supplier
* Affiliation/contact conflict is not bypassed from the supplier-contact workflow
* Purpose assignment is rejected on an ended relationship
* Suppressed/deactivated contact points do not become displayed defaults
* Preferred-kind missing shows “Preferred contact unavailable” rather than another kind
* `no_preference` lists general primaries by kind
* Staff cannot infer administrator-only notes
* Keyboard, labels, focus, responsive layout
* After Turbo Directory navigation, wait on unique headings, retry a cancelled click, and disable Turbo prefetch in test rather than `assert_current_path` immediately after a name click

---

## 11. Implementation sequence

These are separate mergeable PRs onto a Phase 2C integration branch. Each slice must be independently deployable: later-slice routes and navigation cannot be referenced early. Each slice updates all fixtures before merge because Rails loads the complete fixture set.

### 2C.1 — Role-profile foundation

* Client and supplier tables, including `party_kind`, party-status projections, and office status projections
* Unique `(id, agency_id, status)` keys on offices, memberships, and parties
* Lifecycle commands
* Responsible-office constraints and `ChangeOfficeStatus` dependency
* Party overview roles panel
* Audit subjects and events
* Fixtures and seeds

### 2C.2 — Client operations

* Advisor history, GiST exclusion, and state-bearing current-advisor FK
* Advisor commands and membership picker
* `SuspendMembership` dependency
* Client directory and party-local client edit
* Communication preference and bounded restrictions

### 2C.3 — Supplier operations

* Supplier categories and directory defaults
* Supplier directory/detail
* Supplier-contact reuse of 2B relationships and purposes
* Enable the Suppliers primary-nav item only in this slice

### 2C.4 — Selector and identifiers

* Role-aware party selector (query contract and UI; not 2D trigram search)
* External identifier registry, SQL constraint matrix, commands, and party-local UI
* Update the parent Phase 2 contract, `AGENTS.md` current boundary, and terminology where implemented behavior became more specific
* Full demonstration and documentation closeout

---

## 12. Exit demonstration

1. Find an existing organization.
2. Add an active client profile with a responsible office and advisor.
3. Add an active supplier profile to the same organization.
4. Add service categories and directory defaults.
5. Find an existing person and relate that person to the organization as its primary booking contact.
6. Confirm the person did not receive a supplier profile.
7. Add a supplier profile to a different person who independently provides services.
8. Deactivate the organization’s supplier role.
9. Confirm its client role and party identity remain active, and that the deactivated supplier profile may retain an office that is later deactivated.
10. Confirm the organization cannot be reactivated as a supplier onto that inactive office without choosing an active office.
11. Reactivate the same supplier-profile row against an active office.
12. Confirm the organization and both people retain their original party UUIDs and no traveler, payer, arrangement, or duplicate contact identity exists.

The most important additions beyond the parent outline are typed role `party_kind` FKs, state-bearing current-advisor and active-office projections, non-overlapping retained advisor history, party-keyed user-facing identity, and the non-polymorphic external-identifier model. Without those, 2C would reintroduce the split-source and cross-agency invariants removed in 2A and 2B.
