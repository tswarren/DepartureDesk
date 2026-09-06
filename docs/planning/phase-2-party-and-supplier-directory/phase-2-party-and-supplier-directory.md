# Phase 2 — Party and supplier directory

Status: locked planning contract for implementation. Phase 2A is implemented in this repository. Later slices remain planned. This supersedes the earlier directional outline. It must reuse Foundation 1 tenancy, authorization, audit, office, and numbering contracts rather than design around them.

## Purpose

Build the reusable identity and relationship layer used by future client, traveler, supplier, departure, and financial workflows.

A person, household, or organization is created once and reused wherever that party participates in agency business. Client, supplier, traveler, organizer, payer, advisor, and contact are roles or contextual relationships—not separate identities.

Phase 2A is also a Foundation 1 integration slice: every membership must link to an agency person, and `docs/terminology.md` must be updated so household is a party kind.

## Demonstration

Phase 2 proves that one identity can participate in multiple applicable directory roles without creating unrelated traveler, client, employee, or supplier-contact identity records.

Demonstrate:

1. Create a person, household, and organization.
2. Link an agency membership to the existing person.
3. Add a person to one or more households.
4. Add a client profile to a person, household, or organization.
5. Add a supplier profile to a person or organization.
6. Relate an existing person to a supplier organization as a contact.
7. Search through the reusable party selector.
8. Trigger and override a strong duplicate warning as staff, with an audited reason.
9. Merge a confirmed same-kind duplicate as an administrator.
10. Deactivate a role independently of the party.
11. Preserve UUIDs, relationship history, absorbed-party aliases, and audit events.

Do not assign the person as a traveler, organizer, payer, or responsible client. Phase 2 only proves that later workflows can receive the same party ID.

Working examples the model must represent without inference:

- Two cabin-mates who pay separately remain two person clients. Sharing a cabin does not make them a household.
- Making the Morgan Household a client does not make its members clients, travelers, payers, or financially responsible parties.

---

## Locked decisions

These decisions are closed for Phase 2. Implementation slices may refine persistence names, but they may not reopen the meaning.

### Tenancy and identity

- `Party` is agency-owned. Load directory records through `Current.agency`. Do not add a tenant `default_scope`. Do not authorize from `params[:agency_id]`.
- Do not add `users.person_id`. `User` remains the global login identity.
- The agency-scoped person link lives on `AgencyMembership`, the existing user-within-agency aggregate: `agency_memberships.person_party_id`.
- Unique `(agency_id, user_id)` already exists on membership. Add unique `(agency_id, person_party_id)`.
- The linked party must have `party_kind = person` and `agency_id` matching the membership. The foreign key targets `people (party_id, agency_id)`, so person kind is enforced by the referenced kind-profile row.
- Every successful membership create—including invited—writes `person_party_id` in the same transaction. Invited memberships are not a null-person state. Acceptance only revalidates the existing link.
- The migration may add the column nullable, backfill every existing membership (invited, active, suspended, revoked), validate, and then enforce `NOT NULL` plus the unique and composite foreign keys. Null `person_party_id` is not a normal post-2A state.
- A person links to at most one membership in the agency. Resolving a user-link conflict is administrator-only.
- Cross-agency association fails closed. Composite foreign keys must keep membership, person, and agency aligned.
- `ProvisionAgency`, invitation acceptance, and `RecoverAgencyAdministrator` must use the same linking service.
- Existing user names seed a new person during backfill. They must not silently overwrite an existing person.

### Authorization

Phase 2 does not introduce RBAC, policy gems, or record-by-record grants. It uses Foundation 1 `staff` and `administrator`.

| Action | Staff | Administrator |
| --- | --- | --- |
| Search and view the agency directory | Yes | Yes |
| Create and edit parties | Yes | Yes |
| Manage contacts, alternate names, and relationships | Yes | Yes |
| Add or deactivate client or supplier profiles | Yes | Yes |
| Create a separate party after a duplicate warning | Yes, reason audited | Yes |
| Deactivate an unblocked party or role | Yes | Yes |
| View or author administrator-only notes | No | Yes |
| Merge parties | No | Yes |
| Resolve user-link conflicts | No | Yes |
| Hard remediation or exceptional deletion | No | Yes |

Phase 2 supports standard internal notes visible to authorized agency staff and administrator-only notes visible to administrators. It does not implement office-scoped, user-scoped, or custom note visibility. If a later operational need justifies office-scoped notes, that must be added with an explicit authorization contract.

### Office visibility and responsibility

Authorized agency staff can find agency parties regardless of responsible office. Office assignments guide responsibility, defaults, and later operational scope; they do not partition the directory.

Administrator-only notes may restrict note content. The existence of a party is not hidden by office.

Responsible office belongs on client and supplier profiles, not on the party root. Those rows carry `agency_id` and enforce matching `(office_id, agency_id)`. Team members already have office access through `OfficeAssignment`.

### Household

A household is a named servicing and communication collective party.

- Members are people only.
- Nested households are prohibited.
- Overlapping household membership is allowed.
- Membership is effective-dated.
- Household client and person client profiles may coexist.
- Client status is never inferred between a household and its members.
- Household does not mean insurance household, traveling party, occupancy group, payer group, or guardian relationship.
- A household’s primary general contact is derived from its current contact-purpose assignments. It is not stored independently on the household profile.

`docs/terminology.md` must change in 2A. “Party = person or organization” must not contradict the schema.

### Persistence shape

- Use `party_kind` plus one-to-one kind profiles. Do not use Active Record STI.
- Party kind is immutable after create.
- Display and sort names are derived and cached. Users do not edit the cached values independently.
- Person display and sort names derive from structured person names.
- Household display names derive from the household name.
- Organization display names derive from trading name when present, otherwise legal name.
- An organization may have one current canonical trading name on its organization profile. Alternate-name records hold former trading names, additional doing-business-as names, acronyms, aliases, or imported representations. The current canonical trading name must not also be stored as an equivalent alternate-name row.
- Every application-owned directory table uses UUID primary keys, `agency_id`, and timestamp-with-time-zone semantics. Independently editable aggregates use `lock_version`; join and assignment records use database constraints and transactional locking appropriate to their lifecycle.
- Cross-agency controller tests are required for every new agency-owned resource, per ADR 0002.
- Model and service tests must show that composite tenant constraints reject cross-agency membership-person links, party profiles, contacts, relationships, responsible offices, advisor memberships, external identifiers, and merge participants.

### Role profiles

- At most one client profile per party within an agency.
- At most one supplier profile per eligible party within an agency.
- Deactivated profiles are reactivated rather than recreated.
- A party may hold both profiles simultaneously.
- Client and supplier profiles must enforce that the profile party, responsible office, and primary advisor membership belong to the same agency.
- A primary advisor must be an active membership of the same agency. Responsible office and advisor are independent attributes: the advisor is not required to hold an assignment to the profile’s responsible office. Later office-owned operational records still re-check Foundation 1 office access.

### References and external identifiers

ADR 0004 is in force. There is no agency sequence service, and Phase 2 must not invent one. Foundation 1E implemented office codes only.

Phase 2 defers generated `client_reference` and `supplier_reference`. Do not add operator-entered stand-ins. Directory lookup uses UUID, names, contact points, affiliations, and typed external identifiers.

If a later phase needs internal human-readable client or supplier references, that phase must complete ADR 0004’s issuance matrix. Those values are display and lookup aids, never authorization boundaries.

An external identifier belongs to the narrowest entity whose identity it describes. General legal or directory identifiers belong to the party; client-system identifiers belong to the client profile; supplier-system identifiers belong to the supplier profile. An optional office scope may qualify an identifier’s issuer context but does not change ownership or create another identity.

Each identifier contains:

- Agency
- Owning record
- Controlled identifier type
- Issuer or namespace
- Original value
- Normalized value
- Declared uniqueness scope
- Optional office context
- Active state
- Provenance or source

Uniqueness is declared by identifier type:

- unique per agency;
- unique per issuer within an agency;
- non-unique and advisory;
- globally unique only where the real contract justifies that claim.

Identifier types are controlled by code or seeded configuration in Phase 2. Users must not invent arbitrary uniqueness semantics while entering a value. No authorization decision may depend solely on an external identifier.

Normalized values are derived projections, not canonical user data. Normalization rules must be versionable or safely rebuildable so future normalization changes can reindex the directory without rewriting original values.

### Advisor

`ClientProfile.primary_advisor_membership_id` is the current operational advisor. It points at `AgencyMembership`, not merely the advisor’s person, because office access and active team status belong to membership.

Advisor assignment history is effective-dated and owned by the client profile. Do not also create a generic `advisor_for` party relationship.

A primary advisor must be an active membership of the same agency. The advisor is not required to have an assignment to the profile’s responsible office.

### Merge execution

A merge runs in one database transaction, locks and revalidates both parties, and fails if either party changes disposition or gains an unresolved dependency before commit. Merge execution must be idempotent for the same survivor and absorbed party.

The merge participant registry is fail-closed. A registered participant must declare whether its references are reassigned, preserved as historical references, consolidated, or block the merge. An unresolved party dependency blocks merge; the merge service must never assume an unknown reference can be reassigned.

A person linked to a membership may survive a merge. An absorbed person may not retain an active membership link. If only the absorbed person is linked, the merge transfers that link to the survivor after confirming the survivor is unlinked. If both are linked, merge is blocked pending administrator resolution.

Require a concurrency test covering two simultaneous merges involving the same party.

### Snapshots

Phase 2 writes the snapshot contract for later domains. It does not implement a universal polymorphic snapshot table.

---

## 1. Architectural principles

1. **Identity and role remain separate.** A party records who or what the entity is. Profiles and contextual records describe how the agency works with it.
2. **Party is primarily technical terminology.** User-facing surfaces should normally use Person, Household, Organization, Client, Supplier, or Contact.
3. **A party belongs to the agency once.** Offices do not own separate copies of an identity and do not hide that identity from authorized staff.
4. **Relationships may change over time.** Household membership, employment, supplier affiliation, and similar relationships use effective intervals.
5. **Operational history does not follow mutable directory data blindly.** Later domains capture the party facts on which a booking, eligibility decision, statement, contract, or financial document relied.
6. **Roles do not establish unrelated obligations.** Being a client, household member, traveler, payer, or supplier contact does not imply another role or responsibility.

---

## 2. Party foundation

### 2.1 Party

`Party` is the common technical identity root.

Supported party kinds:

- Person
- Household
- Organization

A party contains only shared identity and lifecycle information:

- UUID
- Agency
- Immutable party kind
- Derived display name
- Derived sort/search name
- Active or deactivated state
- Deactivated timestamp, actor, and reason
- Merge status and surviving-party reference
- Created and updated timestamps
- Optimistic-lock version

Do not place client-, supplier-, traveler-, employee-, office-responsibility, or departure-specific fields directly on `parties`.

### 2.2 Person

A person is an individual with a reusable identity.

Initial person information may include:

- Preferred/display name
- Given name
- Middle name
- Family name
- Prefix
- Suffix
- Preferred form of address
- Pronouns, if recorded by agency policy
- Date of birth, optional
- General internal identity notes permitted by policy

Date of birth is optional matching and later travel-document context. It is not a travel-document store.

Phase 2 does not provide storage for passports, visas, known-traveler numbers, loyalty accounts, medical requirements, or other travel-document data.

Once a membership is linked, person name fields are the canonical human identity within the agency. `User` retains only account-level display information required outside an agency context. Invitations may collect provisional names before acceptance. Acceptance or provisioning creates or explicitly links the agency person.

### 2.3 Household

A household may contain:

- Household name
- Correspondence name or salutation
- Shared contact information
- Effective-dated members

A household’s primary general contact is derived from its current contact-purpose assignments. It is not stored independently on the household profile.

Household membership alone does not establish:

- Joint financial responsibility
- Guardianship
- Shared travel
- Shared accommodation
- Insurance eligibility
- Authority to act for another member
- Client, traveler, or payer status for members

These require explicit relationships or later contextual records.

### 2.4 Organization

An organization is a legal or informal entity, such as a:

- Corporate client
- School, church, club, or association
- Travel supplier
- Supplier parent company
- Hotel, carrier, venue, or other service provider
- Agency partner

Initial organization information may include:

- Legal name
- One current canonical trading or common name
- Organization category
- Website

An organization may have one current canonical trading name on its organization profile. Alternate-name records hold former trading names, additional doing-business-as names, acronyms, aliases, or imported representations. The current canonical trading name must not also be stored as an equivalent alternate-name row.

Parent organization is an effective-dated relationship, not a foreign key on the organization profile. Supplier and client are roles, not organization types.

### 2.5 Alternate names

Because search and duplicate detection need former and additional names, Phase 2 includes a typed alternate-name child owned by the party:

- Former name
- Alias
- Additional trading or doing-business-as name
- Acronym
- Imported name

Alternate names assist display, search, and matching. They do not replace the canonical structured name or the organization’s current trading name.

---

## 3. Agency team identity

Every application membership must link to exactly one person party in that agency.

This allows an agency team member to use the same identity later as an advisor, departure manager, organizer, group leader, traveler, client, or supplier contact. Those later roles are not created in Phase 2.

Authentication, authorization, agency membership, and office access remain properties of the user and membership models. There is no employee identity record and no team-member role profile.

### Lifecycle rules

- Every membership, including invited, requires a linked person.
- A person does not require a membership or user.
- Disabling a user or suspending a membership does not deactivate the person.
- Deactivating a person does not erase or rewrite user or membership audit history.
- One person may link to no more than one membership within an agency.
- Person records linked to different users cannot be merged until the user-link conflict is explicitly resolved by an administrator.
- User creation, invitation acceptance, provisioning, and recovery must search for and offer to link an existing person before creating another.

---

## 4. Client role

A `ClientProfile` makes a party eligible to participate in the agency’s commercial workflows.

Client profiles may belong to:

- People
- Households
- Organizations

A client profile may contain directory-level information such as:

- Client-since date
- Responsible office
- Current primary advisor membership
- Effective-dated advisor history
- Default communication preference
- General servicing status
- General billing or servicing restrictions
- Client-specific notes permitted by policy

It does not contain a generated or operator-entered client reference in Phase 2.

A party has at most one client profile in the agency. A deactivated client profile is reactivated rather than recreated. A party may hold a client profile and a supplier profile at the same time.

Client and supplier profiles must enforce that the profile party, responsible office, and primary advisor membership belong to the same agency. A primary advisor must be an active membership of the same agency and is not required to hold an assignment to the profile’s responsible office.

Client status does not establish:

- Traveler status
- Client-trip ownership
- Financial responsibility
- Responsibility for a particular charge
- Payer status
- Authority over another party
- Client status for household members or for a household from a member

Those relationships belong to later client-trip and financial domains.

---

## 5. Supplier role

A `SupplierProfile` identifies a party with which the agency directly contracts or from which it directly procures services.

Supplier profiles may belong to:

- Organizations
- People acting as independent providers or sole proprietors

Households cannot be suppliers.

A supplier profile may include:

- Supplier status
- Service categories
- Preferred or default currency as an ISO code
- Default payment-term notes
- General commission-default notes or non-authoritative rates
- Responsible office
- General booking instructions
- General payment instructions
- General cancellation-policy notes
- Supplier portal URL

These values are directory defaults. They are not posted money, arrangement terms, or ledger facts. Phase 2 does not install `money-rails` for supplier defaults. Arrangement-specific contacts, confirmation numbers, prices, deadlines, terms, documents, and obligations belong to future supplier arrangements.

It does not contain a generated or operator-entered supplier reference in Phase 2.

A party has at most one supplier profile in the agency. Households remain ineligible. A deactivated supplier profile is reactivated rather than recreated.

### Supplier versus supplier contact

These concepts must remain distinct:

- A person with a supplier profile is directly providing or contracting to provide services.
- A person related to a supplier organization is a supplier contact.
- Employment or affiliation with a supplier does not automatically give the person a supplier profile.

### Service providers

A service provider is represented by an organization party.

It receives a supplier profile only when the agency contracts with it directly. Otherwise it may be related to the contracting supplier and referenced later as the organization that operates or delivers a service.

---

## 6. Party relationships

Use a dedicated effective-dated relationship model instead of adding household, parent-organization, or employer foreign keys directly to parties.

A relationship should contain:

- Origin party
- Related party
- Controlled relationship kind
- Optional user-facing label
- Effective start date
- Optional effective end date
- Title or position where applicable
- Verification or source information where useful
- Notes
- Lifecycle, correction, and audit information

### Initial relationship kinds

Phase 2 ships a narrow vocabulary:

- Household member
- Family member, with an optional label such as spouse, partner, parent, child, guardian, or dependent
- Employment or organization affiliation
- Organization contact
- Parent organization
- Service provider for

Do not add `advisor_for`, `booking_contact_for`, `billing_contact_for`, `primary_contact_for`, or `emergency_contact_for` as relationship kinds.

### Contact purposes

Booking, accounting, and similar designations are purpose assignments attached to a base contact or employment relationship. They are not boolean columns on the relationship and not additional relationship kinds.

Each purpose assignment has:

- Controlled purpose
- Effective interval
- Optional priority within that purpose

Phase 2 purposes:

- General
- Booking
- Accounting

“Primary” is a rank within one purpose, party, and effective interval. It is not itself a purpose.

### Cardinality

Do not impose a generic overlapping-interval exclusion across all relationship kinds.

Locked policy:

- Household membership may overlap freely.
- Employment and organization affiliation may overlap when labels or purposes differ.
- Exact duplicate active relationships are prohibited.
- A relationship kind may opt into stricter interval exclusion only when its business semantics require it.
- Primary uniqueness is enforced within its declared party, purpose, and effective interval.

Database constraints enforce the cases whose semantics are certain. Valid overlapping facts must not become data-fix exceptions.

Relationships should be stored in one canonical direction when possible. The inverse may be presented without creating a second row. Invalid self-relationships are prohibited.

### Correction versus termination

A genuine real-world ending records `effective_to`. An erroneous record is superseded or voided as a correction. The original row remains auditable. The correction identifies the replacement or corrected facts, actor, timestamp, and reason. Normal UI does not rewrite historical intervals in place.

Do not event-source relationships. A correction disposition plus `superseded_by` and an audit event is sufficient.

### Contextual roles excluded from the directory relationship model

Do not treat the following as permanent global relationships:

- Traveler on a departure
- Organizer for a departure
- Group leader for a departure
- Payer of a receipt
- Responsible client for a charge
- Supplier contact for one arrangement
- Emergency contact for one traveler on one trip

Future owning domains will reference existing parties and record those roles in context. Directory contact purposes are defaults, not operational assignments.

---

## 7. Effective facts and contextual snapshots

### Effective-dated information

Use effective intervals when a relationship has a real period of validity, including:

- Household membership
- Employment and organization affiliation
- Guardianship or other family labels that have a period of validity
- Supplier affiliation and service-provider relationships
- Advisor assignment on the client profile
- Contact-purpose assignments

Ending a relationship must preserve its historical interval.

### Contextual snapshots

Later operational domains must capture the party facts on which they relied, including examples such as:

- Passenger name submitted to a carrier
- Address used on a statement
- Household composition used for insurance eligibility
- Supplier contact used for an arrangement
- Legal name shown on a contract

A contextual snapshot should contain:

- Source party ID
- Capture timestamp
- Snapshot purpose
- Only the fields required by the owning context

Each consuming domain owns its snapshot structure. Updating the live party later must not silently rewrite a confirmed operational fact or historical document.

---

## 8. Contact information

Addresses, phone numbers, and email addresses are child records owned by a party.

Each contact point should support, as applicable:

- Contact type or purpose
- User-entered display value
- Normalized comparison/search value
- Primary designation within a defined purpose
- Active or deactivated state
- Effective dates where appropriate
- Verification state and timestamp
- Do-not-use indicator
- Audit history

Names, addresses, phone numbers, and email addresses are not globally unique.

Normalized comparison values are derived projections, not canonical user data. Normalization rules must be versionable or safely rebuildable so future normalization changes can reindex the directory without rewriting original values.

Suppressed, deactivated, or do-not-use contact points remain historical and searchable only where authorized, are visibly marked, and cannot be selected as communication destinations by default.

### 8.1 Addresses

Addresses should support international formats and include:

- Addressee or attention line
- Address lines
- Locality
- Administrative region
- Postal code
- Country
- Address type
- Formatted display value

The model must not require a United States-only address shape.

### 8.2 Phone numbers

Phone records should contain:

- User-entered display value
- Normalized international value where parsing succeeds
- Extension
- Phone type
- Communication restrictions
- SMS capability or permission if later required

### 8.3 Email addresses

Email records should contain:

- Original/display value
- Normalized comparison value
- Email type
- Verification state
- Communication restrictions

Normalization supports lookup and duplicate warnings but must not destructively replace the user-facing value.

### 8.4 Shared contact information

A household or organization may own its own address, phone number, or email address.

Shared contact information should not be modeled by making several parties depend on one person’s contact record.

---

## 9. Notes and sensitive information

Party notes are separate authored records rather than one unrestricted text column.

A party note should support:

- Party
- Author
- Recorded timestamp
- Body
- Standard or administrator-only visibility
- Important or pinned status
- Correction or edit history
- Deactivation or removal disposition

Phase 2 supports standard internal notes visible to authorized agency staff and administrator-only notes visible to administrators. It does not implement office-scoped, user-scoped, or custom note visibility.

Phase 2 notes are general internal directory notes. Departure, traveler, supplier-arrangement, and financial notes remain within their owning domains.

### Prohibited note content

General notes must not be used to store:

- Passwords or authentication secrets
- Supplier portal credentials
- Payment-card numbers or security codes
- Bank credentials
- Passport or government-document numbers
- Identity-document images
- Medical documentation

Purpose-specific sensitive information added in later phases must use structured storage, appropriate encryption, restricted permissions, access logging, redacted display, and explicit retention rules.

The note interface should provide concise guidance and reasonably detect prohibited payment-card or credential patterns. Detection is best-effort hygiene, not a PCI, identity-document, or medical control. An administrator-only note is not sufficient protection.

---

## 10. Directory search and selection

The directory is an operational surface, not an administration-subnav item. Reuse the `dd-` interface contract. Disabled navigation placeholders become real links only when the corresponding authorized routes exist.

Provide unified directory search across people, households, and organizations. Search should use PostgreSQL `pg_trgm` and normalized projections. It may consider:

- Display, legal, and trading names
- Alternate names
- Email addresses
- Phone numbers
- Postal address elements
- Permitted external identifiers
- Household and organization affiliations

Results should display enough authorized context to distinguish candidates:

- Party kind
- Relevant client or supplier roles
- Primary contact information
- Household or organization affiliation
- Responsible office or advisor where a role profile exists
- Active or deactivated state

The same underlying party selector should be reusable later for clients, traveler candidates, organizers, payers, responsible clients, suppliers, supplier contacts, and agency team members. Phase 2 ships the selector for directory-owned roles: person, household, organization, client, supplier, supplier contact, and team member.

Role-specific workflows may filter or rank results. They must still allow an authorized user to add the necessary role to an existing party rather than create a duplicate.

A traveler candidate is simply a person eligible for later contextual assignment. Searching for a person does not create a traveler identity or globally mark the person as a traveler.

---

## 11. Duplicate warnings

Duplicate detection is advisory except for identifiers whose contracts require uniqueness.

The system must never automatically merge parties.

### Person matching signals

Potential person duplicates may be identified using weighted combinations of:

- Normalized name
- Alternate names
- Email
- Phone
- Date of birth
- Address
- Household affiliation
- Organization affiliation

A name match alone is a weak signal.

### Household matching signals

Potential household duplicates may consider:

- Household name
- Shared address
- Phone or email
- Overlapping members

### Organization matching signals

Potential organization duplicates may consider:

- Legal, trading, or alternate names
- Website domain
- Phone
- Address
- External identifier
- Parent organization

### Creation workflow

When candidates are found, an authorized user must choose among:

- Use the existing party
- Add the required role to the existing party
- Create a separate party
- Return to edit the proposed record

Staff may create a separate party after a strong match. That choice requires an explicit confirmation and an audited reason. It is not administrator-only.

A contractually unique identifier collision must block creation rather than produce only a warning.

Duplicate review must not expose administrator-only notes or other restricted content. Agency-wide party existence may be shown to authorized staff. Where a later restriction applies, the interface may report that a possible match exists and requires authorized review.

---

## 12. Merge policy

Merging is an explicit, administrator-only consolidation of two parties of the same kind.

A merge must identify:

- Surviving party
- Absorbed party
- Actor
- Reason
- Field-resolution choices
- Contact, alternate-name, and relationship resolution
- Role-profile resolution
- Conflicting external-identifier disposition

### Merge rules

- Parties must belong to the same agency.
- Parties must have the same party kind.
- The surviving UUID remains authoritative.
- The absorbed party remains as a durable, non-selectable tombstone or alias.
- Historical IDs are never reused.
- Searches for the absorbed identity should identify or resolve to the survivor where authorized.
- Equivalent Phase 2 child records may be consolidated without losing provenance.
- Self-relationships and invalid duplicate relationships must be prevented.
- Historical snapshots and issued documents are not rewritten.
- Two people linked to different memberships cannot merge until the account conflict is resolved.
- A person linked to a membership may survive a merge. An absorbed person may not retain an active membership link. If only the absorbed person is linked, the merge transfers that link to the survivor after confirming the survivor is unlinked. If both are linked, merge is blocked pending administrator resolution.
- Conflicting controlled identifiers cannot be silently combined.
- Every merge produces an audit event describing the material choices.

A merge runs in one database transaction, locks and revalidates both parties, and fails if either party changes disposition or gains an unresolved dependency before commit. Merge execution must be idempotent for the same survivor and absorbed party. Require a concurrency test covering two simultaneous merges involving the same party.

The merge participant registry is fail-closed. A registered participant must declare whether its references are reassigned, preserved as historical references, consolidated, or block the merge. An unresolved party dependency blocks merge; the merge service must never assume an unknown reference can be reassigned.

Phase 2 merge is complete only for Phase 2-owned records: identities, kind profiles, contacts, alternate names, relationships, notes, client profiles, supplier profiles, and external identifiers. Membership linkage follows the transfer-or-block rule above. Every later domain that references a party must declare how its references participate in merge before that domain is considered complete. An unregistered party foreign key is an unresolved dependency and blocks merge.

DepartureDesk does not promise a general-purpose unmerge operation. An erroneous merge requires controlled administrative remediation based on the downstream records affected after the merge.

---

## 13. Deactivation and retention

Deactivation removes a party or role from normal new-work selection without deleting history.

Phase 2 ships an extensible dependency-check contract and the Phase 2 subscribers that can already block or warn:

- An active user/membership link
- Active client or supplier profiles
- Current organization-contact purposes
- Current household membership
- Surviving relationships that designate the party as primary
- A pending merge disposition

Future domains register additional checks for departures, supplier arrangements, balances, and other records.

### Deactivated records

A deactivated party:

- Is hidden from normal selectors
- Remains available through an “include inactive” search
- Remains visible on historical records
- Retains contact, relationship, and audit history
- May be reactivated when authorized
- Cannot be selected for new work unless specifically permitted

Merged and deactivated are different dispositions. An absorbed party cannot be independently reactivated.

Phase 2 does not ship a privacy-erasure workflow or a hard-deletion UI. Hard deletion remains a later authorized remediation path and must not violate operational, financial, or audit retention requirements.

Role profiles may be deactivated independently when the identity remains valid. For example, an organization may stop being a supplier while remaining a client.

---

## 14. Agency and office access

A party has one agency-wide identity.

Office relationships may define:

- Responsible office on a client or supplier profile
- Primary advisor membership on a client profile
- Office-specific supplier defaults that do not clone identity
- Optional office context on an external identifier, which qualifies issuer context without changing ownership or creating another identity

Office reassignment does not clone or transfer the party identity.

All directory actions apply the office and agency access rules established in Phase 1, with directory visibility remaining agency-wide for authorized staff.

Agency-wide duplicate detection must not become a channel through which users discover administrator-only notes or other restricted content.

Phase 2 does not implement office-scoped notes.

---

## 15. Audit requirements

Extend the Foundation 1 audit-subject allowlist. Do not infer tenancy for unknown subject types. A `Party` subject, and any directory child or profile, must belong to the event agency.

Audit at least:

- Party creation
- Material identity changes
- Membership-to-person linkage changes
- Client or supplier role creation, change, or deactivation
- Contact point creation, change, verification, suppression, or deactivation
- Alternate-name changes
- Relationship creation, correction, ending, or reactivation
- Contact-purpose assignment changes
- Duplicate-warning override
- Party or role deactivation and reactivation
- Party merge
- Administrator-only-note access where policy requires it
- Authorized privacy or deletion remediation, if later permitted

Audit records use the Phase 1 contract for actor, subject, agency, event type, timestamp, and meaningful before/after values or event payload.

Derived search-index maintenance should not produce business audit events.

---

## 16. Supplier directory experience

The supplier directory is a role-filtered view of the shared party directory, not a separate identity system.

A supplier page should provide:

- Supplier identity and status
- Person or organization designation
- Service categories
- Primary booking contacts
- Primary accounting contacts
- General contact information
- Responsible office
- General payment and commission defaults
- Related parent companies or service providers
- Notes
- Audit activity
- Future links to supplier arrangements

Example:

- BedBank Wholesale is an organization with a supplier profile.
- Harbor Hotel Boston is an organization acting as the service provider.
- Maria Ruiz is a person related to Harbor Hotel as an organization contact with a booking purpose.
- A future supplier arrangement identifies BedBank as the supplier, Harbor Hotel as the provider, and Maria as the arrangement contact.

None of these relationships requires a duplicate supplier-contact identity. The arrangement contact is a later contextual assignment even when the directory already records Maria as a booking contact.

---

## 17. Explicitly out of scope

Phase 2 does not implement:

- Travel programs or departures
- Client trips
- Traveler enrollment or assignments
- Responsibility allocations
- Traveling parties
- Supplier arrangements or reservations
- Packages or pricing
- Client charges, statements, or payments
- Supplier obligations or payments
- Generated client or supplier references
- `money-rails` or posted money
- Passport, visa, or identity-document storage
- Loyalty and frequent-traveler accounts
- Medical or accessibility profiles
- Marketing campaigns
- Full consent-management automation
- CRM opportunity or sales pipelines
- Automated communications
- Supplier contracting or performance management
- Insurance eligibility decisions
- Granular RBAC
- Office-partitioned directory visibility
- Office-scoped, user-scoped, or custom note visibility
- Universal snapshot storage
- Cross-kind or cross-agency merge
- General unmerge
- Privacy erasure or hard-deletion UI
- Traveler, organizer, payer, or departure-role workflows

Phase 2 establishes the identities and relationships these later domains will reference.

---

# Implementation slices

## Phase 2A — Party foundation and agency team linkage

### Deliverables

- Party root with immutable person, household, and organization kinds
- One-to-one kind profiles and validations
- Derived display and sort names
- Alternate-name children
- Agency ownership
- Lifecycle states
- `agency_memberships.person_party_id` and the shared linking service
- Backfill of existing users into agency people
- Updates to provisioning, invitation acceptance, and administrator recovery
- Terminology update for household as a party kind
- Base directory authorization using staff and administrator
- Audit-subject allowlist extension
- Directory list, create, show, and edit surfaces as an operational navigation item

### Required invariants

- Party kind cannot be changed after create.
- Every membership, including invited, links to exactly one person in that agency.
- A person links to no more than one membership in the agency.
- After backfill, `person_party_id` is `NOT NULL`. Acceptance revalidates the existing link and does not create a person.
- Deactivating a user or membership and deactivating a person remain separate actions.
- Creating a party never automatically assigns a client, supplier, or traveler role.
- Cached display and sort names stay synchronized with canonical structured names.
- The current canonical trading name is not duplicated as an equivalent alternate-name row.

### Exit demonstration

Create a person, household, and organization; find each through the agency directory; link a membership to the existing person; and update each record without changing its stable identity.

---

## Phase 2B — Contact information, relationships, and notes

### Deliverables

- Addresses, phone numbers, and email addresses
- Purpose-scoped primary contact rules on contact points
- Household membership
- Organization affiliations, contacts, parent organizations, and service-provider relationships
- Contact-purpose assignments for general, booking, and accounting
- Relationship-specific cardinality constraints
- Effective dating
- Relationship correction and termination
- Standard and administrator-only party notes
- Sensitive-note restrictions
- Authorization and audit coverage

### Required invariants

- Names and contact values are not globally unique.
- Shared household or organization contact information is owned by that party.
- Relationship history is not destroyed when a relationship ends.
- A household relationship does not imply financial, travel, or eligibility consequences.
- Overlapping household membership and distinct-purpose affiliations remain valid.
- A household’s primary general contact is derived from current purpose assignments, not stored on the household profile.
- Prohibited sensitive information cannot intentionally use general party notes as its system of record.
- Notes have only standard and administrator-only visibility.
- Suppressed or do-not-use contact points cannot be selected as default communication destinations.

### Exit demonstration

Relate one person to a household and a supplier organization, assign personal and shared contact information, assign a booking purpose, end the supplier affiliation, and preserve the historical relationship interval.

---

## Phase 2C — Client and supplier roles

### Deliverables

- Client profiles for people, households, and organizations
- Supplier profiles for people and organizations
- Independent lifecycle for role profiles
- Responsible office on role profiles
- Current advisor membership and advisor history on client profiles
- Supplier service categories and non-authoritative directory defaults
- Role-filtered client and supplier directories
- Add-role-to-existing-party workflows
- Reusable role-aware party selector
- Typed external identifiers
- Authorization and audit coverage

### Required invariants

- Households cannot receive supplier profiles.
- A supplier contact is not automatically a supplier.
- A client is not automatically a traveler, payer, or responsible client.
- Adding or removing a role does not create or deactivate the underlying identity.
- A party has at most one client profile and, if eligible, at most one supplier profile. Deactivated profiles are reactivated rather than recreated.
- Profile party, responsible office, and primary advisor membership belong to the same agency.
- A primary advisor is an active membership of the same agency and is not required to hold an assignment to the profile’s responsible office.
- Supplier-directory defaults do not replace arrangement-specific terms.
- Advisor current value is the membership on the client profile, not a party relationship.
- External identifiers belong to the party or the role profile they describe; optional office context does not change ownership.

### Exit demonstration

Find an existing organization, add both client and supplier roles, and relate an existing person as its booking contact without duplicating either identity. Separately assign a supplier profile to an independent person provider.

---

## Phase 2D — Search, duplicate handling, merge, and lifecycle hardening

### Deliverables

- Unified `pg_trgm` directory search and normalized projections
- Alternate-name search
- Role-filtered selection
- Advisory duplicate scoring
- Access-safe duplicate warnings
- Staff create-anyway workflow with audited reason
- Administrator-only same-kind merge of Phase 2-owned records
- Transactional, idempotent, fail-closed merge with a concurrency test for two simultaneous merges of the same party
- Absorbed-party aliases and tombstones
- Membership-link transfer or block during person merge
- Merge conflict resolution
- Fail-closed merge-participant registry and documented contract for later domains
- Party and role deactivation and reactivation
- Extensible dependency-check interface with Phase 2 subscribers
- Authorization, model, service, request, and system tests, including composite tenant-constraint rejection

### Required invariants

- The system never automatically merges parties.
- Contractually unique identifiers still enforce hard uniqueness.
- Users cannot obtain administrator-only notes through duplicate warnings.
- Merge requires same agency and same party kind.
- Merge is transactional, idempotent for the same survivor and absorbed party, and fail-closed for unregistered party dependencies.
- Historical snapshots and documents are not rewritten by merge.
- An absorbed party cannot be reactivated independently.
- An absorbed person cannot retain an active membership link.
- Automatic unmerge is not part of the application contract.
- Directory-owned dependency checks run before deactivation.

### Not in 2D

- Cross-kind merge
- Cross-agency merge
- General unmerge
- Privacy erasure workflow
- Hard-deletion UI
- Automatic downstream reference reassignment for domains that do not yet exist
- Universal merge callbacks
- Traveler, payer, organizer, or departure-role workflows

### Exit demonstration

Attempt to create a likely duplicate, review the authorized match information, choose the existing person, and add the needed client role.

Then:

- Create a justified separate identity after a strong warning, as staff.
- Merge a confirmed same-kind duplicate, as an administrator.
- Find the survivor through the absorbed identity.
- Deactivate a supplier role without deactivating the underlying party.
- Confirm that historical relationship and audit records remain intact.

---

# Phase 2 completion criteria

Phase 2 is complete when:

1. People, households, and organizations have stable agency-owned identities, and terminology matches that model.
2. Every membership is linked to a reusable person identity through `agency_memberships.person_party_id`.
3. Client and supplier profiles extend parties without duplicating them or issuing deferred references.
4. People and organizations may act as suppliers; households may not.
5. External contacts use person identities, effective-dated relationships, and purpose assignments.
6. Contact information and alternate names can be maintained and searched without unsafe uniqueness assumptions.
7. Household and organization relationships preserve their effective history, including overlapping membership where allowed.
8. Future domains have a written contract for contextual snapshots and merge participation.
9. Search and role-specific selection reuse the same party directory.
10. Strong duplicate candidates require an explicit, audited decision, which staff may make.
11. Same-kind Phase 2 duplicates can be merged by an administrator without erasing absorbed identities or rewriting historical facts. Merge is transactional, idempotent, concurrency-tested, and fail-closed for unregistered party references.
12. Party and role deactivation preserve retained history and enforce Phase 2 dependency checks.
13. General notes cannot serve as storage for credentials, payment data, identity documents, or medical records, and they are not office-scoped.
14. Office attributes control responsibility and defaults without partitioning the directory or cloning identities.
15. The end-to-end demonstration proves that one identity can participate in multiple applicable directory roles without creating unrelated traveler, client, employee, or supplier-contact records.
