# Phase 2A — Party foundation and agency team linkage

## Status

Shipped in this repository as the first slice of Phase 2. The locked decisions below remain the contract; do not reopen them during later slices.

Phase 2A establishes agency-owned party identity, the three party kinds, agency-scoped membership-to-person linkage, alternate names, and the initial operational directory.

It also integrates the party model into Foundation 1 provisioning, invitation, recovery, tenancy, authorization, and audit contracts.

Phase 2A does not implement contact points, relationships, client or supplier profiles, duplicate scoring, merge, or deactivation workflows.

---

# 1. Objective

Create the stable identity root that later Phase 2 slices and operational domains will reference.

After Phase 2A:

* A person, household, or organization has one stable agency-owned party identity.
* Every newly created agency membership—including an invitation—links to a person in that agency.
* Existing memberships are backfilled to agency people.
* Agency team views use the linked person as the agency-canonical name.
* Authorized staff can browse, create, view, and edit parties through an operational directory.
* Party kind and UUID remain stable through edits.
* No client, supplier, traveler, employee, or supplier-contact identity model exists.

---

# 2. Locked Phase 2A decisions

## 2.1 Party kinds

`Party` supports exactly:

* `person`
* `household`
* `organization`

Use a constrained `party_kind` column and one-to-one kind-profile tables. Do not use Active Record STI.

Party kind is immutable after creation. Changing a person into an organization or household is not an edit workflow.

## 2.2 Agency ownership

Every party and kind-profile row carries `agency_id`.

Directory records must be loaded through `Current.agency`. Do not:

* Use a tenant `default_scope`
* Accept agency ownership from form parameters
* Authorize through `params[:agency_id]`
* Infer agency ownership only through another association

Directory visibility is agency-wide for authenticated staff and administrators. Office assignments do not partition the directory.

## 2.3 Membership linkage

Do not add `person_id` or `party_id` to `users`.

Add the agency-scoped link to `agency_memberships`:

```text
agency_memberships.person_party_id
```

The linked party must:

* Belong to the membership’s agency
* Have `party_kind = person`, enforced by a composite foreign key to `people (party_id, agency_id)`
* Link to no other membership in that agency

Kind-profile primary keys are `party_id` (the same UUID as `parties.id`). Do not give `people`, `households`, or `organizations` a second UUID.

## 2.4 Link memberships when they are created

Every successful membership create—including invited—writes `person_party_id` in the same transaction. Invited memberships are not a null-person state. Acceptance only revalidates the existing link.

Creating the person when the membership is invited provides:

* A stable identity throughout the invitation lifecycle
* A person that administrators can inspect before acceptance
* A single membership-person invariant instead of an active-only exception
* No identity creation inside the already-sensitive activation lock sequence
* Consistent behavior among provisioning, ordinary invitations, and recovery invitations

The migration may add the column nullable, backfill every existing membership, validate, and then enforce `NOT NULL`. Null `person_party_id` is not a normal post-2A state.

Invitation revocation does not delete or deactivate the person.

## 2.5 Name authority

Once a membership is linked:

* Person profile fields are the canonical name within that agency.
* Team lists, team details, audit presentation, and agency-facing UI display the person name.
* `User` name fields remain an account-level fallback outside agency context.
* Editing a person does not silently update global `User` name fields.
* Inviting an existing user into an agency does not copy that user’s name over an explicitly selected existing person.
* New-user creation may initially seed both the user fallback name and the new agency person from the submitted invitation name.

Phase 2A does not remove the existing required user name fields. Removing or redefining those fields would unnecessarily broaden the slice.

## 2.6 Roles

Phase 2A uses the existing membership roles:

* Staff
* Administrator

Both may:

* Browse the directory
* View parties
* Create parties
* Edit active parties
* Manage alternate names

Phase 2A introduces no policy gem, granular permissions, or record-level grants.

## 2.7 Lifecycle boundary

Phase 2A may persist the party lifecycle shape required by Phase 2, but it does not expose party deactivation, reactivation, merge, or deletion commands.

New and backfilled parties begin active. Phase 2D owns lifecycle transitions and dependency checks.

## 2.8 References

Phase 2A does not create:

* Client references
* Supplier references
* Generic party numbers
* Operator-entered substitutes
* A generic numbering service

UUIDv7 is the internal identity. ADR 0004 remains authoritative.

---

# 3. Persistence design

## 3.1 `parties`

Create `parties` with:

| Column                         | Contract                                        |
| ------------------------------ | ----------------------------------------------- |
| `id`                           | UUIDv7 primary key                              |
| `agency_id`                    | Required agency owner                           |
| `party_kind`                   | Required constrained string                     |
| `display_name`                 | Required derived/cached value                   |
| `sort_name`                    | Required derived/cached value                   |
| `status`                       | Required constrained string; initially `active` |
| `deactivated_at`               | Nullable; reserved for Phase 2D                 |
| `deactivated_by_membership_id` | Nullable; reserved for Phase 2D                 |
| `deactivation_reason`          | Nullable; reserved for Phase 2D                 |
| `lock_version`                 | Required optimistic-lock counter                |
| `created_at`                   | `timestamptz`                                   |
| `updated_at`                   | `timestamptz`                                   |

Constraints and indexes:

* `party_kind IN ('person', 'household', 'organization')`
* `status IN ('active', 'deactivated')`
* Named lifecycle-consistency constraint:

  * Active parties have no deactivation metadata.
  * Deactivated parties require timestamp, actor membership, and reason.
* Composite unique key on `(id, agency_id)` for tenant-safe child references
* Unique `(id, agency_id, party_kind)` as the typed target for kind-profile foreign keys
* Index on `(agency_id, party_kind, status)`
* Index on `(agency_id, sort_name)`
* Composite foreign key for `deactivated_by_membership_id` and agency
* Deactivation actor membership must belong to the party agency

Do not add `merged_into_party_id` in 2A. Phase 2D should add merge persistence with the transaction and participant contract that uses it.

## 3.2 `people`

Create the person kind-profile table with:

| Column            | Contract                                      |
| ----------------- | --------------------------------------------- |
| `party_id`        | Primary key; same UUID as `parties.id`        |
| `agency_id`       | Required agency                               |
| `party_kind`      | Required; fixed `person`                      |
| `given_name`      | Required                                      |
| `middle_name`     | Optional                                      |
| `family_name`     | Required                                      |
| `prefix`          | Optional; stored, omitted from directory name |
| `suffix`          | Optional; stored, omitted from directory name |
| `preferred_name`  | Optional                                      |
| `form_of_address` | Optional                                      |
| `pronouns`        | Optional                                      |
| `date_of_birth`   | Optional date                                 |
| `lock_version`    | Optimistic-lock counter                       |
| Timestamps        | `timestamptz`                                 |

Database requirements:

* Primary key `party_id`
* Unique `(party_id, agency_id)` for tenant-safe child references
* Composite foreign key `(party_id, agency_id, party_kind)` to `parties`
* Check constraint `party_kind = 'person'`
* Party deletion restricted
* Name fields constrained against blank-only required values
* Date of birth cannot be unreasonably future-dated
* Person kind is enforced by the typed foreign key, not only by table membership

## 3.3 `households`

Create the household profile with:

| Column                | Contract                               |
| --------------------- | -------------------------------------- |
| `party_id`            | Primary key; same UUID as `parties.id` |
| `agency_id`           | Required agency                        |
| `party_kind`          | Required; fixed `household`            |
| `name`                | Required                               |
| `correspondence_name` | Optional                               |
| `lock_version`        | Optimistic-lock counter                |
| Timestamps            | `timestamptz`                          |

Requirements:

* Primary key `party_id`
* Unique `(party_id, agency_id)`
* Tenant-safe composite party foreign key `(party_id, agency_id, party_kind)`
* Check constraint `party_kind = 'household'`
* No second UUID
* No primary-contact foreign key
* No membership rows yet
* No insurance, occupancy, payer, or traveling-party semantics

A household’s primary contact will later be derived from relationship-purpose assignments. It is not stored independently.

## 3.4 `organizations`

Create the organization profile with:

| Column                  | Contract                               |
| ----------------------- | -------------------------------------- |
| `party_id`              | Primary key; same UUID as `parties.id` |
| `agency_id`             | Required agency                        |
| `party_kind`            | Required; fixed `organization`         |
| `legal_name`            | Required                               |
| `trading_name`          | Optional                               |
| `organization_category` | Optional constrained value or deferred |
| `website`               | Optional                               |
| `lock_version`          | Optimistic-lock counter                |
| Timestamps              | `timestamptz`                          |

Requirements:

* Primary key `party_id`
* Unique `(party_id, agency_id)`
* Tenant-safe composite party foreign key `(party_id, agency_id, party_kind)`
* Check constraint `party_kind = 'organization'`
* No second UUID
* No parent-organization foreign key
* No client or supplier booleans
* No supplier-specific fields

If an organization-category vocabulary is not already settled, defer the column rather than ship an unrestricted category string.

## 3.5 `party_alternate_names`

Create typed alternate names with:

| Column            | Contract                                 |
| ----------------- | ---------------------------------------- |
| `id`              | UUIDv7 primary key                       |
| `party_id`        | Required party                           |
| `agency_id`       | Required agency                          |
| `name_kind`       | Required constrained type                |
| `name`            | Required display value                   |
| `normalized_name` | Required derived value                   |
| `status`          | Required constrained string; `active` or `removed` |
| `removed_at`      | Required when removed; null when active            |
| `removed_by_membership_id` | Required when removed; same-agency actor  |
| `lock_version`    | Optimistic-lock counter                  |
| Timestamps        | `timestamptz`                            |

Initial kinds:

* `former_name`
* `alias`
* `additional_trading_name`
* `acronym`
* `imported_name`

Do not use a generic `trading_name` kind that duplicates the organization’s current canonical trading name.

Constraints:

* Tenant-safe composite party foreign key
* Same-agency composite foreign key for `removed_by_membership_id`
* Active rows have no removal metadata; removed rows require timestamp and actor membership
* No exact duplicate normalized alternate name of the same kind on one party among active rows
* Alternate names are not globally unique
* Canonical name duplication should be rejected or omitted
* Normalization is rebuildable derived data, not canonical identity
* Removal is an audited `removed` disposition, not a hard delete
* Re-adding the same normalized name and kind reactivates or supersedes the removed row; it does not accumulate a second ambiguous copy

## 3.6 Membership foreign key

Add `agency_memberships.person_party_id`.

Requirements:

* Add the column nullable, backfill every existing membership, then enforce `NOT NULL`
* Unique `(agency_id, person_party_id)`
* Composite foreign key `(person_party_id, agency_id)` to `people (party_id, agency_id)`
* Index for team display and reverse lookup
* Model association named for its meaning, such as `person_party`
* Every membership-creation command writes the link in the same transaction
* Acceptance and reactivation revalidate the existing link and do not create a person

Person kind is enforced by the FK to `people`. Do not point `person_party_id` at `parties.id`.

---

# 4. Derived names

Use one shared name-derivation service or value object. Do not scatter display-name construction among models, helpers, and controllers.

## 4.1 Person

Locked directory display-name rule:

1. Preferred name plus family name, when a preferred name exists
2. Otherwise given name plus middle name plus family name

Prefix and suffix remain on the person profile. They are omitted from directory display names and sort names.

Locked sort name:

```text
Family, Given Middle
```

## 4.2 Household

Display and sort name derive from the household’s required `name`.

`correspondence_name` is not the directory display name unless explicitly chosen in a later communication context.

## 4.3 Organization

Display name:

1. Current canonical trading name when present
2. Otherwise legal name

Sort name follows the same canonical choice after normalization.

## 4.4 Synchronization

Creating or updating a kind profile must update its party’s cached names in the same transaction.

Prefer explicit create/update commands over callback chains whose transaction boundaries are unclear.

Required properties:

* The party and profile never commit with conflicting names.
* `UpdateParty` locks the party and the kind profile. A stale `lock_version` on either fails the edit.
* Cached names stay in the same transaction as the structured-field update.
* Rebuilding cached names is safe and deterministic.
* Original structured fields are never reconstructed from cached display values.

---

# 5. Membership-person linking service

Introduce one service responsible for linking an agency membership to a person.

A suitable name would be:

```text
LinkMembershipPerson
```

The service accepts:

* Agency
* Membership
* Existing person party, or structured person attributes
* User or privileged system actor
* Optional reason/source
* Expected lock version where applicable

## Transaction and lock order

The service must follow Foundation 1 locking discipline.

Membership-creation commands own the lock order:

1. Lock user when an existing user participates.
2. Lock agency.
3. Lock membership after it exists, and lock an existing person when linking one.
4. Reload and revalidate ownership and state.
5. Allocate or confirm the person, insert the membership with `person_party_id` already set, then call `LinkMembershipPerson.record_locked!`.
6. Record remaining audit events and delivery intent in the same transaction.

`LinkMembershipPerson.record_locked!` does not acquire locks. It validates the person, confirms the membership already points at that person (or assigns on an unsaved record), and writes `team.person_linked`. `allocate_person` creates the party and person without taking extra locks.

Standalone `LinkMembershipPerson#call` may lock user → agency → membership → person when it is the outer command. Nested callers must not invoke `#call`.

It must:

* Fail closed on agency mismatch
* Reject a non-person party
* Reject a person already linked to another membership in the agency
* Be idempotent when the requested membership already links to the requested person
* Return a conflict when it already links to a different person
* Convert database uniqueness violations into stable command errors

`ProvisionAgency`, `InviteTeamMember`, invitation replacement, and `RecoverAgencyAdministrator` use this service. They do not copy linking rules. Invitation replacement reuses the existing membership person and does not re-enter the linker. Recovery `invite_replacement` lets `InviteTeamMember` acquire user → agency locks rather than holding the agency lock first.

Invitation acceptance and membership reactivation do not call it to create a person. They reload and revalidate the existing link.

## Actor modes

Support the existing command conventions:

* Tenant-facing user actor
* Privileged system actor with `actor_identifier`
* Invitation acceptance’s documented invitee exception where relevant

Do not invent a platform user.

---

# 6. Foundation 1 integration

## 6.1 Provisioning

Update `ProvisionAgency` so that its existing transaction creates:

1. Agency
2. Initial office
3. User when necessary
4. Person party and person profile
5. Invited administrator membership linked to that person
6. Default office assignment
7. Provisioning and invitation audit events
8. Delivery intent

The person is created from the provisioning name inputs through `LinkMembershipPerson.allocate_person`. If the administrator email already belongs to a user, provisioning locks that user before creating the agency. After the membership insert, it records the link with `LinkMembershipPerson.record_locked!`.

Provisioning idempotency must continue returning the original agency and membership without creating another party or person.

Add the linked party identifier to relevant audit details, but do not expose unnecessary personal data.

## 6.2 Team invitations

`InviteTeamMember` owns the user → agency lock order and calls `LinkMembershipPerson.allocate_person` plus `record_locked!` in the same transaction as the invited membership. It does not implement a second linking path and does not reacquire locks through `LinkMembershipPerson#call`.

Email remains the login identity. Phase 2A has no email on the person, and invitation email is never inferred from the selected person.

The initial Phase 2A invitation UI should offer two clear paths:

* **Invite an existing person**
* **Create and invite a new person**

Locked email/person matrix:

* If that email already has a membership in this agency, reuse that membership’s person. Selecting a different person is a hard error.
* Selecting a person who is already linked to a membership in this agency is a hard error.
* Selecting an **unlinked** directory person plus a **new** email, or a user who has no membership in this agency, is allowed: create or find the user and link the selected person.
* The person must come from `Current.agency`.
* Submitted name fields must not overwrite an explicitly selected existing person.
* The UI should display the selected person clearly before submission.

For a new person:

* Submitted names create the person and seed a newly created user’s account-level fallback name.
* If the email already belongs to a user, do not overwrite that user’s fallback name.
* The new agency person still receives the submitted agency-specific name.

Phase 2A provides ordinary directory lookup for this selection. Advisory duplicate scoring remains Phase 2D.

Replacing an invitation reuses the existing membership and person link. It does not re-enter `LinkMembershipPerson`.

Revoking an invitation leaves the linked person active and available in the directory.

## 6.3 Invitation acceptance

Invitation acceptance must not create another party.

During the existing `ActivateMembership` lock sequence:

* Reload the membership’s linked person.
* Confirm the person belongs to the agency.
* Confirm it is a person and remains selectable for membership linkage.
* Fail using the existing generic public invitation failure if the link is absent or invalid.
* Activate the membership without rewriting person or user names.
* Do not create a person during acceptance.

This check belongs before password or membership mutation.

## 6.4 Reactivation

Membership reactivation must revalidate the linked person under the existing activation locks.

In Phase 2A all linked people should be active, because party deactivation commands do not yet ship. The validation still establishes the future boundary.

## 6.5 Administrator recovery

`RecoverAgencyAdministrator` must preserve or create the person link according to recovery mode:

* **Replace invitation:** reuse the existing membership and linked person.
* **Reactivate:** require the existing valid person link.
* **Invite replacement:** create or explicitly link the replacement person through `LinkMembershipPerson`. Do not copy linking rules into recovery.

Recovery remains privileged and uses the existing system-actor contract.

## 6.6 Existing team surfaces

Update team administration to display the linked person’s agency-canonical name.

The user email remains the sign-in/contact identifier shown alongside it.

Do not move the directory under Administration merely because team administration links to people.

---

# 7. Backfill strategy

Use a forward migration and explicit backfill. Do not rewrite Foundation 1 migrations.

## 7.1 Rollout order

1. Create party, kind-profile, and alternate-name tables. Kind-profile primary keys are `party_id`.
2. Add nullable `agency_memberships.person_party_id`.
3. Backfill one person for every existing membership (invited, active, suspended, revoked).
4. Populate membership links.
5. Validate tenant-safe foreign keys and uniqueness constraints.
6. Enforce `NOT NULL` on `person_party_id` plus unique `(agency_id, person_party_id)` and the composite FK to `people (party_id, agency_id)`.
7. Deploy application validations and command integration. Every post-2A membership create, including invitation, must write the link.

Invited memberships are not a null-person state after this slice.

## 7.2 Backfill source

For each existing membership:

* Create a person in the membership’s agency.
* Seed structured names from the associated user.
* Use the user’s preferred name where present.
* Derive party display and sort names through the production derivation code or equivalent deterministic migration logic.
* Link the membership to the new person.

Because Foundation 1 currently enforces one active membership per user, the common case creates one agency person per user. The algorithm must still operate per membership so future multi-agency membership does not share a tenantless party.

## 7.3 Backfill guarantees

The backfill must be:

* Idempotent or guarded against a partially completed rerun
* Deterministic
* Safe when a user has invited, suspended, or revoked memberships
* Free of audit events pretending that a human created historical parties
* Covered by a migration/backfill test
* Validated before constraints are marked valid

Do not attempt duplicate matching during backfill. One existing membership becomes one agency person. Phase 2D may later reconcile genuine duplicates.

## 7.4 Fixtures and seeds

Rails loads all fixtures before every test. After this slice, every `agency_memberships` fixture must have a same-agency person through `person_party_id`. One invalid fixture will fail unrelated tests before assertions run.

Directory, party, person, household, and organization fixtures must satisfy:

* Matching `(party_id, agency_id)` composites
* Kind-profile primary key equal to the party UUID
* Unique person-to-membership links inside an agency

Development seeds and `ProvisionAgency` must use `LinkMembershipPerson.allocate_person` and `record_locked!`. Do not insert ad hoc `User` name rows that skip the linking service.

---

# 8. Directory application surface

## 8.1 Navigation

Add **Directory** as a real operational primary-navigation item in `app/views/layouts/application.html.erb`.

Do not replace Travelers or any other disabled placeholder. Travelers remains a later contextual role, not the party directory.

Do not place the directory solely in the Administration subnavigation.

Keep these placeholders disabled until their own routes exist:

* Departures
* Travelers
* Suppliers
* Accounting

The Phase 2C supplier directory will later become a role-filtered view of the shared directory.

## 8.2 Routes

Recommended shape:

```ruby
namespace :directory do
  resources :parties, only: %i[index new create show edit update] do
    resources :alternate_names, only: %i[create edit update destroy]
  end
end
```

`destroy` on alternate names is a removal command that sets `status` to `removed`. It does not hard-delete the row.

The important contract is:

* User-facing URLs are operational.
* Alternate names are nested under the party. A free-standing collection has no tenant parent.
* Controllers load records through `Current.agency`.
* Directory index and show ignore `Current.office`. Office assignments do not filter the list.
* Party kind is chosen at creation and cannot be submitted on update.
* Routes do not include an agency identifier.

## 8.3 Directory index

Phase 2A ships a basic directory list, not the Phase 2D search engine.

The list should provide:

* Name
* Party kind
* Active status
* Team-member indicator when linked to a membership
* Stable pagination by `(sort_name, id)`
* Kind filter with an explicit apply action
* Simple normalized prefix or exact lookup if useful

The current office must not filter or hide parties. Kind filtering uses an explicit apply control; do not require JavaScript to submit the filter.

Do not implement fuzzy scoring or advertise full tolerant search before 2D.

Prevent N+1 queries when showing kind profiles and membership linkage.

## 8.4 Create workflow

The create workflow begins by choosing:

* Person
* Household
* Organization

After selection, show the corresponding form.

The controller must ignore or reject attempts to alter `party_kind` through mass assignment.

Creation should commit party, kind profile, derived names, and audit event atomically.

Creating a person through the directory does not:

* Create a user
* Create a membership
* Make the person an employee
* Make the person a client
* Make the person a traveler
* Assign any office

## 8.5 Show page

The party page should show:

* Specific user-facing kind
* Canonical structured identity information
* Derived display name
* Alternate names
* Active status
* Linked team membership when present
* Record timestamps already on the party
* Clear placeholders only for Phase 2A capabilities

Do not add an audit-history page or a staff audit browser. Foundation 1 has no such UI. Do not show a history link that is not a real page.

Do not show fake links for:

* Client activity
* Supplier arrangements
* Departures
* Traveler history
* Payments
* Relationships
* Contact information

A concise “Not available yet” section is preferable to disabled pseudo-actions throughout the page.

## 8.6 Edit workflow

`UpdateParty` locks the party and the kind profile, updates structured fields, refreshes cached names, and records the audit event in one transaction. A stale `lock_version` on either row fails the edit.

The edit form must not expose:

* Agency
* Party kind
* Lifecycle status
* Merge state
* Membership linkage
* Future role flags

Membership-person linkage is managed through the invitation/team workflow, not by editing an arbitrary party foreign key.

## 8.7 Alternate names

Allow staff and administrators to add, edit, and remove alternate names from the party page.

Removal is an audited `removed` disposition. Do not hard-delete alternate-name rows. Phase 2D search and merge need that history.

At minimum:

* Changes are audited, including removal.
* Canonical-name duplicates are rejected among active rows.
* Active alternate names appear on the party page; removed names are not selectable as current aliases.
* Re-adding a removed name reactivates the retained row.
* Phase 2D can index them without schema changes.

## 8.8 Interface contract

Reuse existing `dd-` composition and components:

* Workspace header
* Panels
* Forms
* Field errors
* Buttons
* Tables
* Alerts
* Status treatment
* Responsive containers

Required usability behavior:

* Labels remain visible.
* Required fields are identified accessibly.
* Validation errors attach to their fields.
* Keyboard order follows visual order.
* Kind selection and form submission work without pointer-only interaction.
* Party type and status are not communicated by color alone.
* Long organization and household names do not break tables or headers.

---

# 9. Commands and controller boundaries

Use explicit transactional commands for multi-record mutations:

* `CreateParty`
* `UpdateParty` — locks party and kind profile; stale version on either fails
* `LinkMembershipPerson`

Optional specialized wrappers may improve type safety:

* `CreatePerson`
* `CreateHousehold`
* `CreateOrganization`

Controllers remain responsible for:

* Authentication
* Loading through `Current.agency`
* Permitted parameters
* Rendering or redirecting
* Mapping stable command errors to form errors

Commands remain responsible for:

* Transaction boundaries
* Tenant alignment
* Party/profile construction
* Name derivation
* Membership linkage
* Locking
* Audit recording
* Stable conflict results

Avoid callbacks for membership linking or audit creation. A narrow callback for purely derived local normalization may be acceptable, but it must not hide multi-record persistence.

---

# 10. Audit integration

## 10.1 Fail-closed subject tenancy

`RecordAdministrativeAudit#ensure_subject_belongs_to_agency!` currently accepts known types but has no rejecting `else`. Phase 2A must make this contract genuinely fail closed.

Add explicit support for:

* `Party`
* `Person`
* `Household`
* `Organization`
* `PartyAlternateName`

Unknown subject types must raise.

Every supported child/profile subject must directly expose `agency_id`; do not infer agency through an unchecked polymorphic chain.

## 10.2 Actions

Add narrowly named actions such as:

* `directory.party_created`
* `directory.party_updated`
* `directory.alternate_name_added`
* `directory.alternate_name_updated`
* `directory.alternate_name_removed`
* `team.person_linked`

Do not emit lifecycle or merge actions before those workflows ship.

## 10.3 Payloads

Audit payloads should contain:

* Party ID
* Party kind
* Changed field names
* Meaningful before/after values where appropriate
* Membership ID for linkage
* Link source, such as provisioning, invitation, backfill, or recovery

Do not place credentials, invitation tokens, or unnecessary date-of-birth values into audit payloads.

## 10.4 Atomicity

Party creation/update, membership linking, and their corresponding audit events must commit or roll back together.

The historical migration backfill should not create ordinary user-attributed business audit events. Document the migration in schema history instead.

---

# 11. Concurrency and failure behavior

Phase 2A must handle:

* Two attempts to link the same person to different memberships
* Two attempts to create a profile for one party
* A stale party edit
* Invitation acceptance racing with invitation replacement
* Invitation/linking racing with activation for the same user
* Invitation acceptance encountering an invalid person link
* Membership reactivation racing with person-link remediation
* Provisioning retry with the same idempotency key
* Cross-agency person IDs submitted to an invitation or command

Expected behavior:

* Database uniqueness and composite foreign keys provide the durable boundary.
* Commands translate predictable constraint failures into stable conflict results.
* No partial party/profile/link/audit writes survive.
* Public invitation failures remain generic.
* Authenticated cross-agency lookups behave as not found.
* Existing Foundation 1 lock order is preserved.

---

# 12. Test plan

## 12.1 Model and constraint tests

### Party

* Accepts the three supported kinds
* Rejects unknown kinds
* Kind cannot change
* Agency is required
* Cached names are required and derived
* Lifecycle constraint rejects inconsistent metadata
* Cross-agency deactivation actor is rejected

### Kind profiles

* Primary key is `party_id`, the same UUID as the party
* Exactly one profile for a party
* Profile agency matches party agency
* Profile kind matches party kind, including typed composite foreign keys that reject SQL mismatches
* Required structured names are enforced
* Blank-only required values are rejected
* Organization display falls back from trading to legal name
* Household name drives display and sort values
* Person directory display omits prefix and suffix

### Alternate names

* Type is controlled
* Party tenancy is enforced
* Exact normalized duplicates for one party are rejected among active rows
* Same name may belong to different parties
* Canonical-name duplicate is rejected
* Original value survives normalization
* Removal sets `status` to `removed`, records `removed_at` and the same-agency actor, and does not delete the row
* Re-adding the same normalized name and kind reactivates the removed row

### Membership link

* Same-agency person links successfully
* Household and organization FKs to `people` fail
* Cross-agency person links fail at the database boundary
* `person_party_id` references `people (party_id, agency_id)`
* One person cannot link to two memberships in an agency
* One membership cannot link to two people
* `person_party_id` is `NOT NULL` after backfill
* Invited, suspended, and revoked memberships all have a person

## 12.2 Command tests

### Create/update party

* Creates each kind atomically
* Derives names
* Records audit
* Rolls back profile when audit fails
* Rolls back party when profile fails
* Rejects submitted agency ownership
* Rejects kind changes
* Detects stale updates
* Fails when either the party or profile `lock_version` is stale

### Link membership person

* Creates and links a new person
* Links an existing unlinked person
* Is idempotent for the same link
* Rejects a conflicting existing link
* Rejects a person already linked elsewhere
* Rejects cross-agency and non-person parties
* Records the correct actor and audit details
* Resolves concurrent uniqueness conflicts safely

## 12.3 Foundation service tests

Update coverage for:

* `ProvisionAgency`
* `InviteTeamMember`
* `ReplaceInvitation`
* `AcceptInvitation`
* `ActivateMembership`
* `ReactivateMembership`
* `RecoverAgencyAdministrator`

Assert that:

* New memberships have linked people.
* Provisioning retries do not create duplicates.
* Replacement invitations preserve the person.
* Revocation preserves the person.
* Acceptance creates no additional person.
* Invalid links produce the appropriate generic or authenticated failure.
* Existing Foundation 1 office and activation invariants still hold.
* Invitation email/person matrix: existing in-agency membership keeps its person; already-linked person is a hard error; unlinked person plus new email, or a user with no membership in this agency, links the selected person.
* `ProvisionAgency`, `InviteTeamMember`, and recovery use `LinkMembershipPerson.allocate_person` and `record_locked!` rather than nested `#call`.

## 12.4 Audit tests

* Every new subject type is accepted only for its own agency.
* Cross-agency subjects fail.
* Unknown subject types fail.
* New actions are allowlisted.
* Audit events remain append-only.
* PII excluded by policy does not appear in payloads.

## 12.5 Controller tests

For every party kind:

* Staff and administrator can list, view, create, and edit.
* Unauthenticated requests redirect to sign-in.
* Cross-agency show and update return not found.
* Submitted `agency_id` is ignored or rejected.
* Submitted `party_kind` cannot change an existing record.
* Validation errors render accessibly.
* Basic list filters remain agency-scoped and work without JavaScript.
* Directory index paginates by `(sort_name, id)`.
* Directory index and show do not filter by `Current.office`.
* Alternate names are nested under the party.
* Alternate-name removal is audited and leaves the row.

## 12.6 System tests

Cover:

* Open Directory from primary navigation.
* Create one person, household, and organization.
* View each on the directory list.
* Edit canonical identity information.
* Add and edit an alternate name, asserting unique accessible labels and field values rather than only page text.
* Invite an unlinked existing person with a new email.
* Reject inviting an already-linked person.
* Create and invite a new person.
* Confirm the team page and directory use the same agency-canonical name.
* Accept an invitation without creating another party.
* Operate the full workflow by keyboard.

## 12.7 Migration/backfill tests

* Every existing membership receives one same-agency person.
* Multiple memberships for a user produce separate agency-owned people.
* Invited, active, suspended, and revoked memberships backfill.
* Rerun/partial-run behavior does not duplicate people.
* UUIDv7 and `timestamptz` contracts are preserved.
* Composite constraints validate after backfill.
* `person_party_id` is `NOT NULL` after the backfill migration.
* Every membership fixture has a same-agency person.

---

# 13. Documentation changes

Phase 2A updates:

* `docs/terminology.md`
* `AGENTS.md`
* The Phase 2 planning contract
* Relevant Foundation 1 planning notes where membership identity is described
* Schema/domain documentation if maintained

## Terminology changes

Replace the existing narrow definition with:

> A party is a person, household, or organization that may participate in a business, financial, or operational relationship.

Clarify:

* Household is a servicing and communication collective.
* Household membership remains a relationship added in 2B.
* Household is not an insurance household, traveling party, occupancy group, or payer group.
* Agency team members use person identities linked through agency membership.
* Traveler remains a contextual role of a person.
* Client and supplier remain profiles added in 2C.

## AGENTS changes

Add Phase 2A as shipped only when implementation merges.

Until then, planning language must remain prospective.

When shipped, add invariants covering:

* Agency-owned parties
* Immutable party kind
* Membership-to-person linkage
* Agency-wide directory visibility
* No identity duplication for later roles

---

# 14. Explicitly not in Phase 2A

Do not implement:

* Addresses
* Phone numbers
* Email addresses
* Household membership
* Organization affiliations
* Parent-organization relationships
* Contact-purpose assignments
* General party notes
* Client profiles
* Supplier profiles
* Responsible offices on roles
* Advisor assignments
* External identifiers
* Generated human-readable references
* Fuzzy or trigram search
* Duplicate scoring or create-anyway warnings
* Party merge
* Party deactivation/reactivation commands
* Privacy erasure or hard deletion
* Traveler profiles or assignments
* Organizer, payer, or responsible-client records
* Travel documents
* Marketing or CRM features
* Granular RBAC
* Office-partitioned directory visibility
* Staff audit-history browser
* Snapshot persistence

---

# 15. Recommended implementation sequence

## Step 1 — Persistence and core models

* Create party and kind-profile tables.
* Create alternate-name table.
* Add membership person link as nullable, then `NOT NULL` after backfill.
* Add constraints and associations, including FK to `people (party_id, agency_id)`.
* Implement derived-name logic with prefix/suffix omitted from directory display.

## Step 2 — Backfill and membership contract

* Backfill every existing membership.
* Validate tenant-safe constraints and `NOT NULL`.
* Implement the shared linking command.
* Require links from all new membership-creation paths.
* Update fixtures and seeds so every membership has a same-agency person.

## Step 3 — Foundation service integration

* Update provisioning.
* Update team invitation.
* Revalidate acceptance and reactivation.
* Update administrator recovery.
* Preserve idempotency and lock ordering.

## Step 4 — Audit hardening

* Make subject tenancy fail closed.
* Add Phase 2A subjects and actions.
* Audit party and linking commands atomically.

## Step 5 — Operational directory UI

* Add Directory to primary navigation without replacing Travelers.
* Add directory list and kind filters that ignore current office.
* Add create, show, and edit workflows.
* Add alternate-name management.
* Update team views to use person identity.

## Step 6 — Verification and documentation

* Complete cross-agency, concurrency, backfill, controller, and system coverage.
* Run the full Docker test suite.
* Build CSS.
* Update `db/structure.sql`.
* Update terminology and planning documents.
* Perform the manual acceptance demonstration.

---

# 16. Acceptance demonstration

Using an existing agency:

1. Open the operational Directory.
2. Create Alex Morgan as a person.
3. Create the Morgan Household.
4. Create Horizon Tours as an organization.
5. Find all three through the directory.
6. Edit Alex’s preferred name and confirm the UUID remains unchanged.
7. Add a former or alternate name and confirm it appears without replacing the canonical name.
8. Invite Alex as a team member by selecting the existing person.
9. Confirm the membership links to Alex’s existing party ID.
10. Accept the invitation.
11. Confirm acceptance creates no additional party or person.
12. Confirm the team directory uses Alex’s agency-canonical person name while the user retains its account-level login identity.
13. Attempt to access another agency’s party URL and receive not found.
14. Confirm no client, supplier, traveler, employee, or supplier-contact record was created.

---

# 17. Phase 2A completion gate

Phase 2A is complete when:

1. Person, household, and organization identities exist as agency-owned parties.
2. Kind profiles are one-to-one, tenant-aligned, and durably type-safe.
3. Party kind cannot change.
4. Display and sort names derive deterministically from structured identity fields.
5. Alternate names can be maintained without replacing canonical names, and removal is an audited disposition rather than a hard delete.
6. Every existing membership has been backfilled to an agency person and `person_party_id` is `NOT NULL`.
7. Every newly created membership, including an invitation, receives a linked person transactionally.
8. Provisioning, invitations, acceptance, reactivation, and recovery preserve the linkage contract.
9. Person identity is canonical for agency-facing team names without making party identity global.
10. Both staff and administrators can use the agency-wide operational directory.
11. Directory controllers and database constraints reject cross-agency access and associations.
12. Audit subject tenancy fails closed for all old and new subject types.
13. Party/profile/link mutations and their audit events are atomic.
14. Foundation 1 idempotency, activation, office-access, and lock-order tests continue to pass.
15. The demonstration proves that an existing person can become an agency team member without creating another agency identity.
