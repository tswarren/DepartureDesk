# Phase 2B — Contact information, relationships, and notes

## Status

Implemented in this repository as Phase 2B.1–2B.3. Client and supplier profiles, merge, party deactivation, and fuzzy search remain out of scope.

Phase 2A is shipped and remains authoritative for:

* Agency-owned parties
* Person, household, and organization kinds
* Agency-wide directory visibility
* Membership-to-person linkage
* Derived names and alternate names
* Foundation 1 authorization and audit contracts

Phase 2B adds reusable contact information, effective-dated party relationships, relationship contact purposes, and retained internal notes.

It does not add client profiles, supplier profiles, duplicate detection, merge, party deactivation, or operational traveler/departure roles.

Implement 2B as three mergeable PRs (2B.1 contacts, 2B.2 relationships, 2B.3 notes). Do not land the whole slice in one review.

---

# 1. Objective

Allow authorized agency staff to maintain how parties can be contacted and how they are related without duplicating identities or inferring operational roles.

After Phase 2B, the directory must support:

* Multiple addresses, phone numbers, and email addresses per party
* Contact information owned directly by people, households, or organizations
* Purpose-specific primary contact information
* Suppression without deletion
* Effective-dated household membership
* Person-to-person family relationships
* Organization affiliations and contacts
* Parent-organization and service-provider relationships
* General, booking, and accounting purposes for organization contacts
* Genuine relationship endings
* Corrected relationship records that preserve the original
* Standard and administrator-only internal notes
* Audited correction and removal rather than destructive editing

---

# 2. Locked Phase 2B decisions

## 2.1 Contact information belongs to a party

Addresses, phones, and emails are owned directly by a party.

A person, household, or organization may each own contact information. Sharing is represented by putting shared contact information on the appropriate collective party.

Examples:

* Alex Morgan owns a personal mobile phone.
* The Morgan Household owns a shared mailing address.
* Horizon Tours owns a general booking email.
* Maria Ruiz owns her direct mobile phone.

Do not:

* Make several people point to one person’s contact record
* Copy a household address automatically onto its members
* Infer a person’s contact information from an organization
* Treat a login email on `User` as the person’s directory email
* Synchronize `User.email_address` and a person email automatically

The global user email remains the authentication identity. A directory email is contact information. They may have the same value without being the same fact.

## 2.2 Use a typed contact-point root

Use a common `PartyContactPoint` root with typed detail tables for:

* Postal address
* Phone number
* Email address

Do not use Active Record STI or one wide table with mostly-null columns.

This gives contact purposes, suppression, lifecycle, and audit one consistent owner while preserving type-specific fields and validation.

## 2.3 Contact values are not identities

Names, addresses, phones, and emails are not globally or agency-unique.

An email or phone match may later contribute to a duplicate warning, but Phase 2B must not:

* Block two parties from sharing a contact value
* Automatically consolidate contact records
* Automatically link a contact value to a user
* Merge parties based on contact information

## 2.4 Contact purposes and primary designation

Contact-point purposes are controlled assignments, not boolean columns.

Phase 2B has two purpose vocabularies. They share the word `general` and must stay namespaced in code, constraints, UI labels, and audit payloads.

Contact-point purposes (owned by a party’s contact point):

* `general`
* `correspondence`
* `billing`

Relationship-contact purposes (owned by a person-to-organization affiliation or contact):

* `general`
* `booking`
* `accounting`

A contact point may hold more than one contact-point purpose.

“Primary” is represented as priority within one party, contact kind, and purpose. It is not another purpose.

Examples:

* One email can be primary for general correspondence.
* Another can be primary for billing.
* A household mailing address can be primary for correspondence.
* A phone may be general but not permitted for billing communication.

Phase 2B must prevent two simultaneously effective priority-one contact points for the same:

```text
agency + party + contact kind + purpose
```

## 2.5 Contact suppression is distinct from lifecycle

A contact point may remain factually current but be prohibited for use.

Suppression records:

* Suppressed timestamp
* Suppressing agency membership
* Reason

A suppressed contact point:

* Remains visible as historical directory information
* Is clearly marked “Do not use”
* Cannot be selected as a default communication destination
* Does not automatically promote another contact point unless the user explicitly chooses one
* May be unsuppressed with an audit event

Do not model suppression as an untracked boolean.

Contact points have exactly three ineligibility mechanisms. Do not add a fourth.

* **Suppression** means the value is still this party’s current contact fact, but staff must not use it. Mark it “Do not use.”
* **Deactivation** means the value is no longer this party’s contact. Retain the row.
* **Purpose assignment range and disposition** mean when that value is used for general, correspondence, or billing.

Do not put `effective_from` / `effective_until` on `party_contact_points`. Purpose assignments and relationships carry the date ranges. Status plus deactivation metadata on the contact root is enough.

Verification (`verified_at`, provider confirmation, `directory.contact_verified`) is out of Phase 2B. Staff recording a number or address is not a verification workflow.

## 2.6 Effective dates use agency-local dates

Contact-purpose and relationship validity use dates, not timestamps.

This slice supersedes the parent Phase 2 name `effective_to`. Persist exclusive `effective_until`.

Dates are interpreted according to the agency’s default timezone for directory purposes. Rails `Date.current` is UTC in this application and must not be used as “today” for an agency. Defaulting or comparing directory dates uses one helper equivalent to:

```ruby
Time.current.in_time_zone(agency.default_timezone).to_date
```

Later operational domains may snapshot their own relevant dates and timezones.

Use half-open effective ranges:

```text
[effective_from, effective_until)
```

Therefore:

* `effective_from` is inclusive.
* `effective_until` is exclusive.
* Null `effective_until` means no known end.
* Ending something “after September 30” stores `effective_until = October 1`.

The UI may present inclusive end dates to users. Persistence, exclusion constraints, and domain services use the half-open range. Convert at one boundary helper; do not convert ad hoc in controllers.

## 2.7 Relationship correction differs from ending

A genuine real-world ending changes the valid relationship’s effective range and records the reason.

An erroneous relationship is not merely ended. It is:

* Marked `superseded` or `voided`
* Retained
* Linked to a replacement when one exists
* Accompanied by correction actor, timestamp, and reason

Normal UI does not overwrite material relationship facts in place.

Do not fully event-source relationships.

## 2.8 Notes are retained records

Party notes are internal directory records, not one mutable text field.

A note’s body is immutable after creation.

To correct a note:

* Create a replacement note
* Mark the original as superseded
* Link the records
* Record the correction reason

To withdraw a note without replacement:

* Mark it removed
* Retain the original body
* Record actor, timestamp, and reason

Pinning may be changed independently and audited.

Any authorized staff member may correct or remove a standard note, not only the original author. Author attribution remains the creating membership.

## 2.9 Note visibility remains simple

Phase 2B supports only:

* `standard` — visible to authorized staff and administrators
* `administrator_only` — visible only to administrators

It does not implement:

* Office-scoped notes
* User-private notes
* Custom access lists
* Note sharing
* Client-visible notes

Standard and administrator-only notes use the same agency tenancy contract. Note existence and contents must not leak through counts, errors, search, or URLs.

Do not write audit events on GET. Isolation is `not found` for staff, counts and empty states that omit administrator-only notes, and no search of note bodies. Do not add `directory.restricted_note_accessed`.

## 2.10 Contextual roles remain out of the directory graph

Do not create global relationships for:

* Traveler on a departure
* Organizer or group leader
* Payer
* Responsible client
* Client-trip coordinator
* Trip emergency contact
* Supplier contact for one arrangement
* Traveler assignment
* Occupancy or traveling party

Phase 2B organization contacts are directory-level affiliations. A future supplier arrangement may select one of those people as its contextual contact without copying the person.

## 2.11 Contact edit versus re-add

In-place `UpdatePartyContactPoint` is for typos, labels, types, and rebuildable normalization. A real-world move or replacement deactivates the old contact point and creates a new one.

Re-adding a deactivated contact point with the same party, contact kind, and normalized value reactivates or explicitly supersedes the retained row. It does not accumulate a second ambiguous active copy. This matches Phase 2A alternate-name re-add.

Suppressed contact points are still current facts. Re-entry of the same value while suppressed is a conflict or an unsuppress workflow, not a second row.

## 2.12 Purpose-assignment disposition

Contact-point purpose assignments and relationship purpose assignments use the same retained dispositions as relationships:

* `valid`
* `superseded`
* `voided`

A genuine end changes the valid assignment’s `effective_until` and records actor, timestamp, and reason.

An erroneous assignment is superseded or voided, retained, and linked to a replacement when one exists.

Exclusion constraints that enforce a single priority-one assignment apply only to `valid` rows. `NULL` `effective_until` is unbounded. Lower-priority valid assignments may overlap.

“Set as primary” must explicitly end or supersede the current valid priority-one assignment in the same command. Do not silently demote another primary.

## 2.13 Directory commands lock agency, then parties

Do not copy membership/activation lock order onto directory commands.

Contact, relationship, and note commands lock:

1. Agency
2. Involved parties, ordered by UUID when several
3. Contact point, relationship, or note, ordered by UUID
4. Purpose assignment when it is an independent row, ordered by UUID
5. Audit event before commit

Lock the actor user only when that command mutates user state. Phase 2B directory commands do not.

Commands called from another locked command must use a documented locked primitive and must not reacquire locks.

## 2.14 Relationship kinds are typed at the database boundary

Store `origin_party_kind` and `related_party_kind` on `party_relationships`.

Each kind has a fixed pair, enforced by check constraints and composite foreign keys to `parties (id, agency_id, party_kind)`. Command validation is not sufficient.

No Phase 2B kind allows a self-relationship.

## 2.15 Organization affiliation and contact are mutually exclusive

A person may not have overlapping `valid` `organization_affiliation` and `organization_contact` rows with the same organization.

Use affiliation plus relationship purposes when the person is affiliated. Use organization contact only when no affiliation is known or relevant. Creating the second kind while the first is valid is a hard conflict.

## 2.16 Approved dependencies

Phase 2B may add exactly these gems, as explicit exceptions like `money-rails`:

* `phonelib` — behind a DepartureDesk-owned phone normalizer
* `countries` — namespaced ISO reference data only (`ISO3166::Country`, not a global `Country` constant)

Do not add address, email-validation, contactable, geocoding, temporal-versioning, or extra auditing gems. Do not add `country_select`, `phony`, `phony_rails`, `telephone_number`, `geocoder`, `email_address`, `paper_trail`, or `audited`.

The `countries` gem’s currency data is not an accounting authority. ADR 0001 remains `money-rails`.

## 2.17 Party-local lists stay bounded

Notes and relationship history on one party will grow. Phase 2B paginates those lists from the start, using a deterministic order such as `(created_at, id)` or `(effective_from, id)`.

Contact points per party are expected to stay small; still avoid unbounded renders if a party already has a large retained history of deactivated rows. Show current/active first; paginate retained history.

Filters use an explicit apply control. Do not auto-submit through inline JavaScript. Nested forms use unique accessible labels.

## 2.18 Interface contract

Extend [docs/ui/interface-contract.md](../../ui/interface-contract.md) for party-local subnavigation, “Do not use” versus deactivated, and administrator-only note markers. Red is the destructive/do-not-use color. Amber is not.

---

# 3. Contact persistence

## 3.1 `party_contact_points`

Create the shared contact root:

| Column                         | Contract                              |
| ------------------------------ | ------------------------------------- |
| `id`                           | UUIDv7 primary key                    |
| `agency_id`                    | Required agency                       |
| `party_id`                     | Required owning party                 |
| `contact_kind`                 | `postal_address`, `phone`, or `email` |
| `label`                        | Optional user label                   |
| `status`                       | `active` or `deactivated`             |
| `deactivated_at`               | Nullable timestamp                    |
| `deactivated_by_membership_id` | Nullable same-agency membership       |
| `deactivation_reason`          | Nullable                              |
| `suppressed_at`                | Nullable timestamp                    |
| `suppressed_by_membership_id`  | Nullable same-agency membership       |
| `suppression_reason`           | Nullable                              |
| `lock_version`                 | Optimistic-lock counter               |
| Timestamps                     | `timestamptz`                         |

Constraints:

* Composite FK `(party_id, agency_id)` to parties
* Unique `(id, agency_id, contact_kind)` as the typed target for detail tables
* Composite actor FKs to agency memberships
* Controlled `contact_kind`
* Controlled lifecycle status
* Deactivation metadata agrees with status
* Suppression metadata is all-null or complete
* Agency and contact kind are immutable
* Important constraints and indexes are named

Do not store an independently editable “primary” flag on the root. Do not store contact-root effective dates. Do not persist verification in Phase 2B.

## 3.2 Typed contact detail tables

Use shared-primary-key detail rows:

```text
party_postal_addresses.contact_point_id
party_phone_numbers.contact_point_id
party_email_addresses.contact_point_id
```

The detail primary key is the same UUID as `party_contact_points.id`.

Each detail table also carries:

* `agency_id`
* Fixed `contact_kind`
* `lock_version`
* `created_at`
* `updated_at`

Use a composite typed FK to:

```text
party_contact_points(id, agency_id, contact_kind)
```

This follows the type-safe Party/profile pattern established in the 2A remediation.

## 3.3 `party_postal_addresses`

Suggested fields:

| Field                   |                 Required? |
| ----------------------- | ------------------------: |
| `attention`             |                        No |
| `address_line_1`        |                       Yes |
| `address_line_2`        |                        No |
| `address_line_3`        |                        No |
| `locality`              |         Country-dependent |
| `administrative_region` |         Country-dependent |
| `postal_code`           |         Country-dependent |
| `country_code`          |                       Yes |
| `formatted_address`     |            Derived/cached |
| `normalized_address`    | Derived search projection |
| `normalization_version` |                       Yes |

Rules:

* Country is uppercase ISO 3166-1 alpha-2, validated against namespaced `countries` gem data.
* Persist `country_code` and `administrative_region` as strings. Do not serialize gem objects.
* When the gem has useful subdivisions, present a select or autocomplete. Still allow free text when standardized subdivision data is insufficient.
* Do not require an ISO subdivision code universally.
* Do not automatically rewrite historical address text because country data updates.
* Do not impose US-only state or postal-code formats.
* Do not require locality, region, and postal code universally.
* `address_line_1` and country are the minimum Phase 2B contract.
* Preserve user-entered display values after trimming.
* Formatting is deterministic and rebuildable via a DepartureDesk-owned formatter.
* No external address-verification API, geocoding, or automatic postal correction is introduced.

Initial labels may include:

* Home
* Work
* Mailing
* Billing
* Other

Labels assist users but do not replace purpose assignments.

## 3.4 `party_phone_numbers`

Suggested fields:

* `display_number`
* `normalized_digits`
* `e164_number`, nullable
* `extension`
* `phone_type`
* `parsed_country_code`, nullable
* `parse_status` — `valid`, `possible`, or `unparsed`
* `normalization_version`

Initial types:

* Mobile
* Home
* Work
* Main
* Fax
* Other

Rules:

* Phase 2B uses `phonelib` behind a DepartureDesk-owned `PhoneNumberNormalizer`. Do not call `Phonelib.parse` from models, controllers, or views.
* Preserve exactly one cleaned user-facing `display_number`. Do not replace it with E.164.
* `normalized_digits` contains digits used for lookup.
* Store `e164_number` only when the number can be parsed reliably.
* Store extension separately from the normalized base number.
* Store the country context used to parse a national-format number.
* Record the normalization version so normalized fields are rebuildable.
* Distinguish **valid**, **possible**, and **unparsed**. Ordinary directory entry warns rather than blocking a possible or unparsed number. Reject only clearly malformed values.
* Default-country order for national numbers: explicit country on the phone record; then a country the user deliberately chooses from a selected address on the same party; then the agency country as a form default. Do not guess from `Current.office`.
* The agency country may initialize the form. It is not silent provenance.
* Do not introduce a second phone-parsing gem.
* SMS capability and SMS consent are deferred.
* Fax remains a type because travel suppliers may still use it.

## 3.5 `party_email_addresses`

Suggested fields:

* `display_address`
* `normalized_address`
* `email_type`
* `normalization_version`

Initial types:

* Personal
* Work
* General
* Booking
* Accounting
* Other

Rules:

* Preserve the trimmed entered address.
* Normalize for comparison by trimming and case-folding.
* Do not infer that two case variants are separate destinations.
* Do not globally enforce uniqueness.
* Do not automatically verify an address merely because it matches a user login.
* Phase 2B does not send verification email and does not persist verification metadata.
* Do not add an email-validation gem. Use conservative local validation: trim, require one `@` with nonblank local and domain parts, reject whitespace and control characters, apply a maximum length, and case-fold the normalized value.

## 3.6 Contact-point purpose assignments

Create `contact_point_purpose_assignments` with:

* UUIDv7 ID
* Agency
* Party
* Contact point
* Contact kind
* Controlled purpose (`general`, `correspondence`, `billing`)
* Priority
* Effective range (`effective_from`, exclusive `effective_until`)
* `record_status` — `valid`, `superseded`, or `voided`
* Supersession/correction metadata, including same-agency actor FKs
* Timestamps

Requirements:

* Assignment party must equal the contact point owner.
* Agency and contact kind must match the contact point via composite FKs.
* Priority is a positive integer.
* Lower numbers take precedence.
* Priority one is the primary destination.
* Only active, unsuppressed contact points with a current valid purpose assignment can be selected as current communication destinations.
* Deactivating or suppressing a contact point does not silently rewrite its purpose history.
* “Set as primary” ends or supersedes the existing valid priority-one assignment in the same transaction.

Enable `btree_gist` if needed and use a named exclusion constraint to prevent overlapping priority-one **valid** assignments for the same:

```text
agency_id
party_id
contact_kind
purpose
effective range
```

Treat `NULL` `effective_until` as unbounded. Do not impose non-overlap on lower-priority alternatives. Superseded and voided rows must not participate in the exclusion.

---

# 4. Party relationship persistence

## 4.1 `party_relationships`

Create:

| Column                          | Contract                                           |
| ------------------------------- | -------------------------------------------------- |
| `id`                            | UUIDv7 primary key                                 |
| `agency_id`                     | Required agency                                    |
| `origin_party_id`               | Required directional origin                        |
| `origin_party_kind`             | Required; fixed per relationship kind              |
| `related_party_id`              | Required directional target                        |
| `related_party_kind`            | Required; fixed per relationship kind              |
| `relationship_kind`             | Controlled kind                                    |
| `relationship_label`            | Controlled where semantics require it              |
| `title`                         | Optional organization role/title                   |
| `effective_from`                | Optional inclusive date                            |
| `effective_until`               | Optional exclusive date                            |
| `record_status`                 | `valid`, `superseded`, or `voided`                 |
| `superseded_by_relationship_id` | Optional replacement                               |
| `corrected_at`                  | Optional timestamp                                 |
| `corrected_by_membership_id`    | Optional agency membership                         |
| `correction_reason`             | Optional                                           |
| `ended_at`                      | Optional recording timestamp                       |
| `ended_by_membership_id`        | Optional agency membership                         |
| `ending_reason`                 | Optional                                           |
| `source`                        | Optional controlled or bounded description         |
| `notes`                         | Optional short relationship-specific clarification |
| `lock_version`                  | Optimistic-lock counter                            |
| Timestamps                      | `timestamptz`                                      |

Tenant requirements:

* Both parties belong to the same agency as the relationship.
* Composite FKs `(origin_party_id, agency_id, origin_party_kind)` and `(related_party_id, agency_id, related_party_kind)` target `parties (id, agency_id, party_kind)`.
* Each relationship kind has a check that the stored kinds match its allowed pair.
* Correction and ending actors belong to the same agency.
* Superseding relationship belongs to the same agency.
* Superseding relationship uses the same relationship kind and semantic participants unless an explicit correction contract allows otherwise.
* Agency, original participants, and stored party kinds are immutable after creation.
* Self-relationships are rejected. No Phase 2B kind allows them.

Relationship `notes` must remain brief descriptive context. It does not replace party notes.

## 4.2 Initial relationship kinds and direction

### Household membership

```text
person → household
relationship_kind = household_member
origin_party_kind = person
related_party_kind = household
```

Rules:

* Origin must be a person.
* Related party must be a household.
* Nested households are impossible.
* A person may belong to several households over overlapping periods.
* Membership does not confer client, payer, traveler, guardian, or insurance status.
* Exact duplicate effective membership records are prohibited.

### Family relationship

```text
person → person
relationship_kind = family
origin_party_kind = person
related_party_kind = person
```

Controlled semantic labels:

* `parent_of`
* `child_of`
* `guardian_of`
* `dependent_of`
* `spouse_of`
* `partner_of`
* `other_family`

Rules:

* Parent, child, guardian, and dependent labels are directional. Do not automatically derive the inverse row.
* `child_of` is the allowed inverse phrasing of `parent_of`; the user chooses the origin. The two labels are distinct rows, not computed duplicates.
* Spouse and partner are symmetric. Persist one canonical row with `origin_party_id < related_party_id` and present it in both directions.
* Unique/exclusion constraints for spouse and partner use the unordered pair, not `(origin, related)` as a directed pair.
* A label describes the relationship only; it does not create authority, financial responsibility, or supplier eligibility.
* `other_family` may have a bounded display label but no inferred semantics.

### Organization affiliation

```text
person → organization
relationship_kind = organization_affiliation
origin_party_kind = person
related_party_kind = organization
```

Controlled labels:

* Employee
* Contractor
* Owner
* Member
* Representative
* Other

An affiliation may contain a title. It does not automatically make the person a contact. Contact purposes attach to the affiliation when needed.

### Organization contact

```text
person → organization
relationship_kind = organization_contact
origin_party_kind = person
related_party_kind = organization
```

Use when the person is a directory-level contact but an employment or other affiliation is not known or relevant.

A person may not have overlapping `valid` `organization_affiliation` and `organization_contact` rows with the same organization. That is a hard conflict, not advisory guidance.

### Parent organization

```text
child organization → parent organization
relationship_kind = parent_organization
origin_party_kind = organization
related_party_kind = organization
```

Rules:

* Both parties must be organizations.
* An organization cannot parent itself.
* The service must prevent a direct or indirect parent cycle.
* Overlapping parent relationships are allowed only if the model deliberately supports multiple simultaneous parents. For Phase 2B, allow at most one effective primary parent at a time.
* Historical parent relationships remain retained.

### Service provider

```text
operating organization → channel or contracting organization
relationship_kind = service_provider_for
origin_party_kind = organization
related_party_kind = organization
```

Direction is locked:

* **Origin** is the operating or providing organization (the hotel, operator, or venue).
* **Related** is the organization through which or for which those services are contracted or sold (the wholesaler, bedbank, or brand/owner counterpart in this directory sense).

Example: origin = Harbor Hotel Boston, related = BedBank Wholesale. Display: “Harbor Hotel Boston provides services through BedBank Wholesale.”

Rules:

* Both parties must be organizations.
* This is a directory relationship only.
* Neither organization is automatically given a supplier profile.
* The relationship does not mean the agency has a contract or arrangement with either party.
* Future supplier arrangements choose their actual supplier and service provider contextually.

## 4.3 Exact-duplicate policy

Do not impose one generic no-overlap rule across every relationship kind.

Reject exact duplicate valid relationships where all of these match:

* Agency
* Origin party
* Related party
* Relationship kind
* Semantic label
* Overlapping effective interval

Allow:

* Multiple household memberships
* Different organizations
* Different family semantics
* Different affiliation labels
* Overlapping organization responsibilities represented through distinct purposes
* Historical sequential intervals

Reject overlapping `valid` `organization_affiliation` and `organization_contact` between the same person and organization.

Spouse and partner uniqueness uses the unordered pair `(LEAST(origin_party_id, related_party_id), GREATEST(origin_party_id, related_party_id))` plus overlapping valid interval.

Use database constraints where the semantics are certain and command-level locking/revalidation for cycle or conditional rules that cannot be expressed safely as static constraints.

---

# 5. Relationship contact purposes

## 5.1 Applicability

Contact purposes may attach only to:

* `organization_affiliation`
* `organization_contact`

Initial purposes:

* `general`
* `booking`
* `accounting`

Do not create relationship kinds named:

* Booking contact
* Accounting contact
* Primary contact

## 5.2 `relationship_purpose_assignments`

Create:

* UUIDv7 ID
* Agency
* Relationship
* Organization party
* Controlled purpose (`general`, `booking`, `accounting`)
* Priority
* Effective range
* `record_status` — `valid`, `superseded`, or `voided`
* Supersession/correction metadata
* Lock version where the assignment is independently editable
* Timestamps

Rules:

* Relationship must be a valid person-to-organization affiliation or contact relationship.
* Organization party must equal the relationship target.
* Priority one is primary for that organization and purpose.
* Only one simultaneously effective **valid** priority-one assignment exists for each organization and purpose. The exclusion constraint covers valid rows only; `NULL` `effective_until` is unbounded.
* Lower-priority contacts may overlap.
* Ending an affiliation does not silently erase purpose history.
* A purpose cannot remain effective outside the relationship’s effective interval.
* Correcting a relationship revalidates or supersedes its purpose assignments explicitly.
* “Set as primary” ends or supersedes the existing valid priority-one assignment in the same command.

The current primary booking or accounting contact is derived from effective purpose assignments. It is not stored on the organization.

## 5.3 Directory defaults versus operational contacts

A booking or accounting purpose means:

> This person is generally an appropriate directory contact for this organization.

It does not mean:

* This person is the contact for every supplier arrangement
* This person approved a contract
* This person receives every invoice
* This person is a payer or responsible client
* This person is authorized to act for a traveler

Future operational records must explicitly select their contextual contact and capture required snapshots.

---

# 6. Notes persistence

## 6.1 `party_notes`

Create:

| Column                       | Contract                             |
| ---------------------------- | ------------------------------------ |
| `id`                         | UUIDv7 primary key                   |
| `agency_id`                  | Required agency                      |
| `party_id`                   | Required party                       |
| `author_membership_id`       | Required agency membership           |
| `body`                       | Required                             |
| `visibility`                 | `standard` or `administrator_only`   |
| `pinned`                     | Required boolean                     |
| `record_status`              | `active`, `superseded`, or `removed` |
| `superseded_by_note_id`      | Optional replacement                 |
| `corrected_at`               | Optional timestamp                   |
| `corrected_by_membership_id` | Optional                             |
| `correction_reason`          | Optional                             |
| `removed_at`                 | Optional timestamp                   |
| `removed_by_membership_id`   | Optional                             |
| `removal_reason`             | Optional                             |
| `lock_version`               | For pin/disposition transitions      |
| `created_at`                 | Recorded timestamp                   |
| `updated_at`                 | Administrative state timestamp       |

Rules:

* Body is immutable after creation.
* Author membership belongs to the same agency.
* Author attribution is preserved if the membership is later suspended.
* Visibility cannot be downgraded silently during correction.
* Standard users cannot create, view, correct, remove, or infer administrator-only notes.
* An administrator-only correction remains administrator-only unless an administrator explicitly creates a distinct standard note.
* Removed and superseded notes are hidden from ordinary display but retained.
* Correction and removal metadata must agree with status.
* A note cannot supersede itself.
* Supersession cycles are prohibited.
* Party and agency are immutable.

Do not add office scope.

## 6.2 Sensitive-content hygiene

The note form must state that it is not for:

* Passwords or access credentials
* Payment-card or bank details
* Passport or identity-document numbers
* Identity-document images
* Medical documentation

Implement best-effort rejection for:

* Valid probable payment-card numbers using a Luhn check
* Obvious password/secret/private-key patterns
* Clearly structured authentication tokens where detection is reliable

Do not claim that this creates PCI, medical, or identity-document compliance.

Requirements:

* Rejected note bodies are not logged.
* Error messages do not echo the rejected content.
* Detection logic is covered by unit tests.
* Avoid broad heuristics likely to reject ordinary travel notes.
* Administrator-only visibility does not bypass prohibited-content checks.

---

# 7. Commands

Use explicit transactional commands.

## Contact commands

* `CreatePartyContactPoint`
* `UpdatePartyContactPoint`
* `DeactivatePartyContactPoint`
* `ReactivatePartyContactPoint`
* `SuppressPartyContactPoint`
* `UnsuppressPartyContactPoint`
* `AssignContactPointPurpose`
* `EndContactPointPurpose`
* `CorrectContactPointPurpose`
* `SetContactPointPrimary`

## Relationship commands

* `CreatePartyRelationship`
* `EndPartyRelationship`
* `CorrectPartyRelationship`
* `VoidPartyRelationship`
* `AssignRelationshipPurpose`
* `EndRelationshipPurpose`
* `CorrectRelationshipPurpose`

## Note commands

* `CreatePartyNote`
* `CorrectPartyNote`
* `RemovePartyNote`
* `SetPartyNotePinned`

Commands own:

* Transaction boundaries
* Locking
* Tenant alignment
* Kind compatibility
* Effective-range validation
* Primary conflict resolution
* Cycle prevention
* Suppression and lifecycle rules
* Audit recording
* Stable error codes

Controllers own only:

* Loading through `Current.agency`
* Authentication and role checks
* Permitted parameters
* Rendering and redirects
* Mapping command errors to forms

Avoid callbacks for cross-record primary selection, correction, lifecycle, and audit behavior.

There is no `VerifyPartyContactPoint` command in Phase 2B.

---

# 8. Locking and concurrency

## 8.1 General order

Directory commands follow this order:

1. Agency
2. Involved parties, ordered by UUID when several
3. Contact point, relationship, or note, ordered by UUID
4. Purpose assignment when independently mutated, ordered by UUID
5. Write audit event before commit

Do not lock the actor user first. User → agency is the membership/activation contract, not the directory contract.

Commands called from another locked command must use a documented locked primitive and must not reacquire locks in a different order.

## 8.2 Primary assignment races

When assigning priority one:

* Lock the owning party or organization.
* Reload existing **valid** effective priority-one assignments.
* Revalidate the proposed interval.
* Explicitly end or supersede the existing primary in the same command, or reject the conflict.
* Rely on the exclusion constraint as the final race boundary.
* Convert constraint violations into a stable `:conflict` result.

Do not silently demote another primary.

## 8.3 Relationship correction

Correction must:

* Lock original relationship.
* Lock involved parties in deterministic UUID order.
* Revalidate that the original remains valid and unsuperseded.
* Create the corrected replacement.
* Mark the original superseded.
* Reconcile affected purpose assignments explicitly.
* Record one audit payload that connects original and replacement.
* Commit atomically.

Two simultaneous corrections must produce one winner and one stable conflict.

---

# 9. Authorization and visibility

## Staff

Staff may:

* View contact information
* Create and update contact information
* Suppress and unsuppress contact information
* Manage contact purposes
* Create, end, and correct relationships
* View and create standard notes
* Correct or remove standard notes
* Pin standard notes

## Administrators

Administrators may perform all staff actions and additionally:

* View administrator-only notes
* Create administrator-only notes
* Correct, remove, and pin administrator-only notes

Phase 2B does not introduce finer permissions.

## Fail-closed behavior

* Every controller loads the party through `Current.agency`.
* Nested children load through that party.
* `Current.office` does not filter contacts, relationships, or standard notes.
* Staff receive not found for administrator-only note URLs.
* Counts and empty states visible to staff exclude administrator-only notes.
* GET requests do not write audit events.
* Cross-agency child IDs return not found.
* Commands independently revalidate tenancy after locks.

---

# 10. Audit contract

Extend `AuditEvent::ACTIONS` and `RecordAdministrativeAudit` for all new subject types.

Suggested actions:

### Contact information

* `directory.contact_created`
* `directory.contact_updated`
* `directory.contact_deactivated`
* `directory.contact_reactivated`
* `directory.contact_suppressed`
* `directory.contact_unsuppressed`
* `directory.contact_purpose_assigned`
* `directory.contact_purpose_ended`
* `directory.contact_purpose_corrected`

### Relationships

* `directory.relationship_created`
* `directory.relationship_ended`
* `directory.relationship_corrected`
* `directory.relationship_voided`
* `directory.relationship_purpose_assigned`
* `directory.relationship_purpose_ended`
* `directory.relationship_purpose_corrected`

### Notes

* `directory.note_created`
* `directory.note_corrected`
* `directory.note_removed`
* `directory.note_pin_changed`

Do not add `directory.restricted_note_accessed`.

## Audit subjects

Allowlist:

* `PartyContactPoint`
* `ContactPointPurposeAssignment`
* `PartyRelationship`
* `RelationshipPurposeAssignment`
* `PartyNote`

Do not add 1:1 detail tables (`PartyPostalAddress`, `PartyPhoneNumber`, `PartyEmailAddress`) as audit subjects. Audit the contact-point root.

Unknown subject types continue to fail closed. Extend `RecordAdministrativeAudit` in the same PR as the first write of each new subject.

## Audit payload restrictions

Do not place these in audit payloads:

* Full note bodies
* Full addresses unless necessary
* Full email or phone values
* Rejected sensitive input
* Authentication or payment information

Prefer:

* Record IDs
* Party IDs
* Contact kind
* Changed field names
* Purpose
* Status transitions
* Last four digits or redacted values only when operationally useful
* Original and replacement relationship/note IDs
* Correction/removal reason

Administrator-only note isolation must not be implemented by logging reads. GET does not write audit events.

---

# 11. UI and navigation

## 11.1 Party subnavigation

Avoid turning the existing party show page into one very long edit surface.

Add party-local navigation, using the administration interface contract’s subnav pattern:

* Overview
* Contact information
* Relationships
* Notes

The Overview retains:

* Identity
* Alternate names
* Team membership
* Summary of current primary contact information
* Summary of current relationships

Do not show an audit-history link; there is still no audit browser.

Extend `docs/ui/interface-contract.md` before inventing new page anatomy. Unique accessible labels are required wherever a page has more than one control named Kind, Name, or Purpose.

## 11.2 Contact-information surface

Show separate sections for:

* Email addresses
* Phone numbers
* Postal addresses

Each row/card should display:

* User-facing value
* Label/type
* Current purposes
* Primary designation
* Suppressed/deactivated state
* Actions

Actions should use precise language:

* Edit
* Set as primary
* End purpose
* Mark do not use
* Allow use
* Deactivate
* Reactivate

Do not use “Delete” for retained records. “Set as primary” is an explicit command that ends or supersedes the previous valid primary.

Forms should make clear that:

* Login email is separate.
* Shared information belongs on a household or organization.
* Deactivation and “Do not use” have different meanings.

Filters, if any, use an Apply control. Do not auto-submit through inline `onchange`.

## 11.3 Relationships surface

Separate current/upcoming relationships from past/corrected relationships. Paginate the history list.

For each relationship show:

* Related party
* Relationship description
* Direction rendered in natural language
* Title or label
* Contact purposes
* Effective dates
* Current/past/corrected state
* Actions

Examples:

* “Alex Morgan is a member of the Morgan Household.”
* “Maria Ruiz is a booking contact for Horizon Tours.”
* “Harbor Hotel Boston is operated by Harbor Hospitality Group.”
* “Harbor Hotel Boston provides services through BedBank Wholesale.”

Do not display raw origin/related terminology to users.

## 11.4 Relationship creation

Use a role-aware party selector:

* Household member: people → selected household
* Family: person → person
* Organization affiliation/contact: people → organization
* Parent organization: organization → organization
* Service provider: organization → organization

The server remains authoritative. Submitted incompatible kinds must fail even if the UI filtered them.

## 11.5 Notes surface

Staff view:

* Pinned standard notes
* Other active standard notes
* Correct/remove actions
* No indication of administrator-only note counts

Administrator view:

* Pinned notes
* Standard notes
* Administrator-only notes with a clear restricted marker
* Create form with standard or administrator-only visibility

Do not place the full note editor inline beside every note. Use focused create/correct forms.

Paginate notes. Staff views must not include administrator-only counts, empty-state copy, or pagination totals that would reveal restricted notes.

---

# 12. Routes

Recommended nested operational routes:

```ruby
namespace :directory do
  resources :parties, only: %i[index new create show edit update] do
    resource :contact_information, only: :show
    resources :contact_points, only: %i[new create edit update] do
      member do
        post :deactivate
        post :reactivate
        post :suppress
        post :unsuppress
      end

      resources :purposes, controller: "contact_point_purposes",
        only: %i[new create] do
        member do
          post :end
          post :correct
        end
      end
    end

    resource :relationships, only: :show
    resources :party_relationships, path: "relationships",
      only: %i[new create show] do
      member do
        post :end
        post :correct
        post :void
      end

      resources :purposes, controller: "relationship_purposes",
        only: %i[new create] do
        member do
          post :end
          post :correct
        end
      end
    end

    resource :notes, only: :show
    resources :party_notes, path: "notes", only: %i[new create] do
      member do
        post :correct
        post :remove
        patch :pin
      end
    end
  end
end
```

Exact controller names may be simplified, but preserve:

* Party-scoped URLs
* No agency ID in routes
* No free-standing contact, relationship, or note collections
* Explicit retained-lifecycle actions
* No destructive `DELETE` routes for retained business records

---

# 13. Search boundary

Phase 2B makes contact and relationship data available for later search but does not implement Phase 2D’s full fuzzy matching.

Phase 2B should:

* Maintain normalized email, phone, and address projections
* Index agency plus normalized value
* Keep normalization rebuildable
* Allow exact or prefix lookup where needed by the party surface
* Paginate party-local contact history, relationships, and notes
* Avoid exposing administrator-only notes to search

Phase 2B should not:

* Score duplicate parties
* Interrupt party creation with match warnings
* Add fuzzy cross-field search
* Search note bodies globally
* Automatically infer a party from an entered contact value

---

# 14. Migration and persistence requirements

* Use forward migrations.
* Commit updated `db/structure.sql`.
* Enable `btree_gist` only if the chosen exclusion constraints require it. Those exclusions apply to `valid` rows only; `NULL` `effective_until` is unbounded.
* Use UUIDv7 primary keys for aggregate and assignment records.
* Use composite agency foreign keys.
* Use `timestamptz` for event timestamps.
* Use dates or PostgreSQL date ranges for effective periods.
* Add `lock_version` to independently editable aggregates.
* Name important constraints and indexes.
* Do not add money columns or `money-rails` behavior.
* Do not add external service dependencies beyond the approved `phonelib` and `countries` gems.
* Do not rewrite 2A migrations.

Fixtures must include:

* Each contact kind
* Shared household and organization contacts
* Suppressed and deactivated contacts
* Multiple purpose assignments
* Overlapping household membership
* Organization contacts
* Parent and service-provider relationships
* Ended, superseded, and voided relationships
* Standard and administrator-only notes

Administrator-only note fixtures must not leak into staff assertions. Rails loads all fixtures before unrelated tests, so visibility helpers and staff tests must scope queries the same way production does.

All fixture rows must be tenant-aligned because Rails loads them before unrelated tests.

---

# 15. Test plan

## 15.1 Contact constraints

Test:

* Every contact root belongs to one same-agency party.
* Typed detail kind matches the root, including SQL/`insert_all!` mismatches.
* Cross-agency typed rows fail at the database boundary.
* Contact kind and agency are immutable.
* Contact values may be shared by different parties.
* Deactivation metadata matches status.
* Suppression metadata is complete and same-agency.
* Suppressed/deactivated contacts cannot become current primary destinations.
* Re-adding a deactivated normalized value reactivates or supersedes the retained row.
* Two overlapping **valid** priority-one assignments conflict.
* Purpose-assignment ranges use exclusive `effective_until`; superseded rows do not participate in the exclusion.
* Lower-priority assignments may overlap.
* Original display values survive normalization.
* Normalized values can be rebuilt.
* Agency-local “today” uses the agency timezone, not UTC `Date.current`.

## 15.2 Relationship constraints

Test every allowed and disallowed kind pairing:

| Kind                     | Origin       | Related      |
| ------------------------ | ------------ | ------------ |
| Household membership     | Person       | Household    |
| Family                   | Person       | Person       |
| Organization affiliation | Person       | Organization |
| Organization contact     | Person       | Organization |
| Parent organization      | Organization | Organization |
| Service provider         | Organization | Organization |

SQL mismatches of those pairs fail at the typed composite FK.

Also test:

* Cross-agency participants fail.
* Self-relationships fail.
* Exact duplicates fail.
* Valid overlapping household memberships succeed.
* Overlapping affiliation and contact for the same person and organization fail.
* Spouse/partner uniqueness treats the pair as unordered.
* Parent cycles fail.
* Genuine ending preserves history.
* Correction preserves and supersedes the original.
* Two corrections produce one winner.
* Purpose assignment cannot exceed the relationship interval.
* Only one effective **valid** primary per organization/purpose exists.
* Service-provider origin is the operating organization.

## 15.3 Notes

Test:

* Staff can manage standard notes, including notes they did not author.
* Staff cannot discover administrator-only notes.
* Administrators can manage both visibility levels.
* Body is immutable.
* Correction creates a linked replacement.
* Removal retains the row and body.
* Pin changes are audited.
* Cross-agency note access returns not found.
* Prohibited-content detection rejects probable PANs and obvious secrets.
* Rejected content is not written to audit details or logs.
* Visibility and disposition metadata constraints hold.

## 15.4 Commands

For every command, test:

* Successful operation
* Invalid state
* Cross-agency input
* Incompatible party kinds
* Stale lock version where relevant
* Database conflict translation
* Atomic rollback when audit creation fails
* Actor authorization
* Concurrent primary or correction path

## 15.5 Controllers and system behavior

Test:

* Party-local navigation
* Contact CRUD and retained lifecycle
* Purpose assignment and primary replacement
* Household relationship creation
* Organization-contact creation
* Relationship end and correction
* Standard note workflow
* Administrator-only note isolation
* Keyboard and no-JavaScript reachability, including Apply-filter paths
* Unique accessible labels on nested contact and relationship forms
* Current office does not filter the surfaces
* Cross-agency nested IDs return not found
* Long international addresses and names do not break layout
* Notes and relationship history paginate

---

# 16. Implementation sequence

## 2B.1 — Contact foundation

Implement:

* Typed contact root
* `party_postal_addresses`, `party_phone_numbers`, and `party_email_addresses`
* `PhoneNumberNormalizer` (`phonelib`) and namespaced `countries` reference data
* Normalization
* Effective ranges on purpose assignments only
* Suppression and lifecycle
* Purpose assignments
* Primary rules
* Contact-information UI
* Audit and tests

Exit demonstration:

> Give a person a personal email and phone, give a household a shared mailing address, make different contact points primary for general and billing purposes, and suppress one without deleting it.

## 2B.2 — Effective-dated relationships

Implement:

* Relationship root
* Typed origin/related party kinds and composite FKs
* Kind/direction validation
* Household memberships
* Family relationships, including `child_of` and unordered spouse/partner uniqueness
* Organization affiliations and contacts, mutually exclusive when overlapping
* Parent organizations
* Service-provider relationships with locked origin = operating organization
* Contact-purpose assignments
* End/correct/void workflows
* Relationship UI
* Audit and concurrency tests

Exit demonstration:

> Add one person to two overlapping households, relate that person to an organization as its primary booking contact, end the affiliation on a real date, and retain the complete historical interval.

## 2B.3 — Notes and closeout

Implement:

* Retained party notes
* Standard and administrator-only visibility
* Correction/removal/pin workflows
* Best-effort sensitive-content hygiene
* Overview summaries
* Full cross-agency and authorization pass
* Documentation and manual acceptance demonstration

Exit demonstration:

> Add a standard note, correct it without rewriting the original, add an administrator-only note, and prove staff cannot infer or access the restricted record.

These are separate mergeable PRs onto a Phase 2B integration branch. Do not review 2B.1–2B.3 as one pull request.

---

# 17. Explicitly out of scope

Phase 2B does not implement:

* Client profiles
* Supplier profiles
* Responsible offices
* Primary advisors
* Supplier categories or defaults
* External identifiers
* Generated references
* Party duplicate scoring
* Party merge
* Party deactivation/reactivation
* Privacy erasure or hard deletion
* Full-text or fuzzy directory search
* Marketing consent
* SMS consent or messaging
* Email verification delivery
* Contact-point verification metadata
* Postal validation services
* Geocoding
* Automatic postal correction
* DNS or SMTP email checks
* Automated SMS capability detection
* Contact import
* Generic contact, temporal-versioning, or extra auditing gems
* Traveler profiles or assignments
* Travel documents
* Emergency contacts for a particular trip
* Departure organizers or group leaders
* Payers or responsible clients
* Supplier-arrangement contacts
* Snapshot persistence
* Audit browser
* Granular RBAC
* Office-scoped notes
* Client-visible notes

---

# 18. Acceptance demonstration

Using one agency:

1. Open Alex Morgan in the Directory.
2. Add a personal email and mobile phone.
3. Add a second email for billing.
4. Make the personal email primary for general communication.
5. Make the second email primary for billing.
6. Mark the personal email “Do not use.”
7. Confirm it remains visible but is no longer an eligible destination.
8. Add a shared mailing address to the Morgan Household.
9. Confirm that address is not copied onto Alex.
10. Add Alex to the Morgan Household.
11. Add Alex to a second household with an overlapping interval.
12. Confirm neither household relationship makes Alex a client, traveler, payer, guardian, or insurance household member.
13. Create Horizon Tours and Maria Ruiz if they do not already exist.
14. Relate Maria to Horizon Tours as an organization contact.
15. Assign Maria general and booking purposes, with booking priority one.
16. Create Harbor Hotel Boston and Harbor Hospitality Group.
17. Relate Harbor Hotel Boston to Harbor Hospitality Group as a child organization.
18. Create BedBank Wholesale and relate Harbor Hotel Boston as a service provider (origin = hotel, related = BedBank).
19. End one organization affiliation using a real effective date, stored as exclusive `effective_until`.
20. Correct a mistaken relationship and confirm the original remains superseded.
21. Add a standard servicing note to Alex.
22. Correct the note and confirm its original remains retained.
23. Add an administrator-only note.
24. Sign in as staff and confirm the restricted note’s existence and contents are not exposed.
25. Confirm all contacts, relationships, purposes, and notes retain the same agency and party identities.
26. Confirm no client, supplier, traveler, employee, payer, organizer, or supplier-arrangement-contact identity was created.

---

# 19. Phase 2B completion gate

Phase 2B is complete when:

1. People, households, and organizations can own multiple typed contact points.
2. Login email and directory email remain separate facts.
3. Shared household and organization contact information is not copied to member people.
4. Contact values are normalized without destroying user-entered display values.
5. Contact values are not treated as unique party identities.
6. Purpose assignments determine current primary contact information.
7. Concurrent primary assignment cannot create two effective primary destinations.
8. Suppression and deactivation preserve contact history and prevent default use. Contact-root date ranges are not used.
9. Household membership is effective-dated, overlapping, and limited to person-to-household relationships.
10. Family relationships do not infer financial, travel, insurance, or authority consequences.
11. Organization affiliations and contacts reuse existing person identities and cannot overlap as valid rows for the same person and organization.
12. Parent-organization relationships are cycle-safe.
13. Service-provider origin is the operating organization; the relationship does not imply supplier status or an arrangement.
14. Booking and accounting are purpose assignments, not relationship kinds.
15. Genuine endings and corrections have distinct retained histories.
16. Notes preserve author, body, visibility, correction, and removal history.
17. Staff cannot access or infer administrator-only notes; GET does not write access audits.
18. Best-effort note screening is presented accurately and does not claim regulatory compliance.
19. Every new table and association enforces agency alignment, including typed relationship kind FKs.
20. All mutations are atomic with their audit events.
21. Current office does not partition directory contacts, relationships, or notes.
22. Party-local notes and relationship history are paginated.
23. No later client, supplier, departure, traveler, or financial semantics are inferred or prematurely implemented.

---

# Appendix A — Gem rationale

Locked decision 2.16 is the contract. This appendix only explains why.

Phone numbering is too irregular for application string manipulation. `phonelib` wraps Google libphonenumber for E.164 and national formatting. Call it only from `PhoneNumberNormalizer`. Directory entry distinguishes valid, possible, and unparsed values and does not reject every number current metadata cannot validate.

The `countries` gem supplies ISO 3166-1 alpha-2 names, calling-code context, and optional ISO 3166-2 subdivision suggestions. Persist strings. Allow free-text regions when the dataset is insufficient. Do not enable a global `Country` constant. Ignore the gem’s currency data.

Keep address rows, purpose assignments, tenancy, and audit under DepartureDesk models. An address gem usually assumes US-centric or polymorphic shapes that fight composite FKs.

Do not add Google Places, Smarty, Loqate, Melissa, USPS, or another verification/geocoding service in 2B.

Do not add an email-validation gem. Trim, require one `@`, reject whitespace and control characters, case-fold the normalized value, and do not perform DNS or SMTP checks.

Do not add PaperTrail, Audited, or a generic effective-dating gem. Use PostgreSQL `daterange`, `btree_gist`, named exclusion constraints on **valid** rows, and existing append-only `AuditEvent`.

Note screening stays a narrow `PartyNoteContentPolicy`: Luhn-probable PANs, PEM/private-key markers, and obvious password/token assignments. It is not a compliance control.
