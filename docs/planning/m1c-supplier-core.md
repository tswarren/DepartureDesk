# M1C — Supplier core

**Status:** Accepted. Implementation authority for the Supplier-core slice only. Supplier code is not shipped until this slice is implemented and merged.

**Parent:** [M1 — Client and Supplier directories](m1-client-and-supplier-directories.md), accepted 2026-09-14

**Prerequisites:** M1A and M1B shipped and merged; ADR 0004, ADR 0005, ADR 0006, current architecture, and interface contract.

**Accepted decisions (2026-09-14):** Product confirmed at least one required category; `other_label` maximum 80 characters; permanently immutable kind; identity and category corrections on inactive Suppliers with destinations gated on an active Supplier; and Supplier contact-point `POST .../set_primary` via parent amendment, matching M1A/M1B.

## Goal

Give each Agency a separate Supplier directory containing organization and individual contracting identities, fixed categories, general Supplier contact points, lifecycle management, normalized search, duplicate review, and durable Supplier references.

M1C creates Suppliers that later Supplier Arrangements may select. It does not model where services occur, who works for a Supplier, or whether another Supplier fulfills an arrangement.

## In scope

* Organization and individual Suppliers in one table without STI
* `SUP-000001` reference issuance
* Fixed, multi-select Supplier categories with at least one required assignment
* Supplier-owned email, phone, postal, and website contact points
* Active/inactive Supplier lifecycle
* Category, kind, status, reference, name, and permitted contact search
* Deterministic Supplier duplicate warnings
* Create-anyway acknowledgement and idempotent replay
* Supplier permission catalog additions
* Supplier audit actions
* Supplier navigation, index, profile, editors, and lifecycle confirmation

## Out of scope

* Supplier Locations
* Named Supplier Contacts
* Supplier Contact-owned contact points
* Preferred Supplier Contact
* Service Provider assignments
* Supplier Arrangements, Reservations, resources, capacity, or deadlines
* Contracts, negotiated terms, tax IDs, bank or remittance instructions
* Commission, Obligations, invoices, or Payments
* Supplier hierarchy, departments, brands, parent companies, or subsidiaries
* Client/Supplier linking, cross-domain matching, synchronization, or merge
* Office attribution or filtering
* Agency-configurable categories
* Hard deletion or anonymization

## Locked boundaries

1. `Supplier` belongs directly and immutably to one Agency.
2. Supplier has exactly one permanently immutable kind: `organization` or `individual`. Wrong-kind correction requires a new Supplier.
3. Client Organization and Supplier remain separate even when they describe the same organization.
4. Client Person, AgencyUser, and individual Supplier remain separate identities.
5. No email, phone, website, or name causes cross-domain linking or warnings.
6. Supplier is the future contracting or settlement counterparty. M1C does not make it a Service Provider for any particular service.
7. Categories classify Suppliers for browsing and selection only. At least one category is required.
8. Supplier contact points belong directly to the Supplier, not a Location or named contact.
9. Office has no Supplier-directory role.
10. M1C introduces no additional `btree_gist` use.

## Persistence

### `suppliers`

| Attribute            | Contract                                   |
| -------------------- | ------------------------------------------ |
| `id`                 | UUIDv7                                     |
| `agency_id`          | Required and immutable                     |
| `kind`               | `organization` or `individual`; immutable  |
| `supplier_reference` | Required, immutable `SUP-[0-9]{6}`         |
| `display_name`       | Required for organizations; otherwise null |
| `legal_name`         | Optional for organizations; otherwise null |
| `first_name`         | Required for individuals; otherwise null   |
| `last_name`          | Required for individuals; otherwise null   |
| `doing_business_as`  | Optional for either kind                   |
| `status`             | `active` or `inactive`                     |
| `lock_version`       | Required and nonnegative                   |
| timestamps           | UTC `timestamptz`                          |

Add:

* Unique `(id, agency_id)` for composite foreign keys
* Unique `(agency_id, supplier_reference)`
* Stored normalized keys for every applicable name
* A combined name-search vector
* Agency-scoped search indexes
* A database name-shape constraint
* A trigger rejecting changes to `agency_id`, `kind`, or `supplier_reference`
* Matching `attr_readonly` declarations

The name-shape constraint must enforce:

```text
organization:
  display_name present
  first_name and last_name null

individual:
  first_name and last_name present
  display_name and legal_name null
```

Normalize unused optional fields to `NULL`, not blank strings. Individual Suppliers do not store middle name or suffix.

The displayed directory name is:

1. `doing_business_as`, when present;
2. organization `display_name`; or
3. the individual’s first and last name.

All stored names remain independently searchable even when DBA supplies the displayed name.

### `supplier_category_assignments`

| Attribute       | Contract                    |
| --------------- | --------------------------- |
| `id`            | UUIDv7                      |
| `agency_id`     | Required and immutable      |
| `supplier_id`   | Required and immutable      |
| `category_code` | Required fixed catalog code |
| `other_label`   | Present only for `other`    |
| timestamps      | UTC `timestamptz`           |

Enforce:

* Same-Agency composite Supplier foreign key
* Unique `(agency_id, supplier_id, category_code)`
* Database check against the fixed category catalog
* `other_label` required, nonblank, trimmed, and at most 80 characters exactly when the code is `other`; otherwise null
* Owner-identity immutability

Use the accepted catalog:

```text
cruise_line
lodging
air
ground_transportation
tour_operator_dmc
dining
activity_attraction
insurance
other
```

`CreateSupplier` requires at least one category. `ReplaceSupplierCategories` reconciles assignment rows in one transaction and rejects an empty set. The category assignments have no lifecycle status. They remain assigned when the Supplier is inactive. Since `other` exists, an unknown or unusual Supplier still has an honest classification. `other_label` is display metadata and must never be copied into audit JSON.

### Supplier contact points

Create:

* `supplier_email_addresses`
* `supplier_phone_numbers`
* `supplier_postal_addresses`
* `supplier_websites`

Reuse the hardened M1A/M1B contracts:

* Direct immutable `agency_id` and `supplier_id`
* `active` or `inactive`
* Optional preferred state
* At most one preferred active row per channel
* Label limited to 40 characters
* Nonnegative `lock_version`
* Same-Agency composite foreign keys
* Existing email, phone, postal, country, and website normalization
* Phone country is required, defaults to the Agency country on forms, and must validate the entered number for that country (M1A amendment)
* Website input accepts a hostname or HTTP(S) URL; a scheme is optional
* UUIDv7 and `timestamptz`
* No polymorphic owner

Do not create Supplier Contact contact-point tables until M1D.

### Supplier reference sequence

M1C adopts the `supplier` namespace:

* Backfill one sequence row for every existing Agency.
* Update `ProvisionAgency` to create both `client` and `supplier` sequence rows.
* `next_value` means the next unissued positive integer.
* A new sequence starts at 1.
* Missing sequence is an integrity error.
* Reference creation and increment occur in the Supplier creation transaction.
* Rollback consumes no number.
* Replay consumes no additional number.
* `1000000` returns `reference_exhausted`.

## Categories

Category changes:

* Do not change Supplier status.
* Do not trigger duplicate review.
* Are permitted as corrections while the Supplier is inactive.
* Produce one `supplier.categories_changed` audit containing old/new codes and whether the `other` label changed, but not the label text.

## Lifecycle

### Inactivation

`ChangeSupplierStatus` to inactive atomically:

1. Locks Agency, then Supplier.
2. Locks every Supplier-owned contact-point row by type and UUID.
3. Inactivates active contact points.
4. Clears all preferred flags.
5. Leaves categories assigned.
6. Inactivates the Supplier.
7. Writes one lifecycle audit listing affected child IDs and types.
8. Commits everything or nothing.

M1C has no Location, Contact, Arrangement, or financial blockers. M1D will extend this same command when those descendants exist.

### Reactivation

Reactivation restores only the Supplier. It does not reactivate contact points or make anything preferred.

A contact point may be created or reactivated only while its Supplier is active.

Identity and category corrections are permitted on an inactive Supplier so historical directory records can be corrected without reactivation. New or reactivated contact destinations remain gated on an active Supplier.

## Commands and queries

### Supplier aggregate

* `CreateSupplier`
* `UpdateSupplier`
* `ChangeSupplierStatus`
* `ReplaceSupplierCategories`
* `SearchSupplierDirectory`
* `FindSupplierDuplicates`

`CreateSupplier` owns one transaction containing:

* Kind/name normalization
* Duplicate review
* Supplier creation
* Initial category assignments (at least one)
* Supplier reference issuance
* Creation and override audits

It must not compose other public commands.

`UpdateSupplier` cannot change kind or reference. Material name changes rerun duplicate detection. A no-op requires a matching submitted lock version and writes no audit. Identity updates are allowed while the Supplier is inactive.

### Contact points

For each Supplier-owned channel:

* `CreateSupplier…`
* `UpdateSupplier…`
* `ChangeSupplier…Status`
* `SetPreferredSupplier…`

All commands use the Supplier as the audit subject and include `contact_point_id`, `contact_point_type`, and `changed_fields`.

### Lock order

After authorization:

1. Agency
2. Supplier
3. Category assignments by UUID
4. Contact-point rows by channel and UUID
5. Reference sequence when issuing a reference

Because Agency locking already serializes Agency mutations, every command must still follow the same subordinate ordering to avoid future inconsistencies.

## Duplicate review

Supplier duplicates compare only Suppliers of the same `kind` in the same Agency.

They never compare against:

* Client Organizations
* Client People
* AgencyUsers
* Supplier Contacts
* Suppliers in another Agency

### Signals

| Signal | Strength | Notes |
| --- | --- | --- |
| Exact normalized email | Strong | Either kind |
| Same E.164 base and extension | Strong | Either kind |
| Exact organization legal name | Strong | Organization only |
| Exact display name or DBA | Possible | Display name applies to organizations; DBA to either kind |
| Exact individual full name | Possible | Normalized `first_name` + `last_name` only; no middle or suffix |
| Name plus locality or postal code | Possible | Matching stored Supplier name with locality or postal code; postal alone is never a signal |
| Same normalized website hostname | Possible | Either kind |
| Same phone base with different or blank extension | Possible | Either kind |

When a contact point is added or changed, combine it with the Supplier’s stored normalized names where the signal requires a name.

Inactive candidates remain visible and labeled.

The acknowledgement token binds:

* Agency and actor
* Command
* Supplier kind
* Normalized name fields
* Initial category set for create
* Proposed Supplier UUID
* Candidate/signal digest
* Expiration and nonce

Replay checks the proposed Supplier before recomputing candidates and returns the existing result without another reference or audit. Parallel submissions create one Supplier.

## Search

`SearchSupplierDirectory` is separate from Client search.

Filters:

* Status: Active, Inactive, or All
* Kind: All, Organization, or Individual
* Category: All or one fixed category

All filters operate in SQL before the 51-row lookahead limit.

Reject a search `q` over 100 characters without scanning. Blank `q` does not run free-text matching; browse without `q` is allowed with the status, kind, and category filters and the same 50-result / 51-row fetch cap used by Client directory browse.

Searchable for Administrator and Staff:

* Supplier reference
* All applicable Supplier names
* Supplier email
* Supplier phone
* Supplier postal locality and postal code
* Supplier website hostname
* Category code and label

Searchable for Viewer:

* Supplier reference
* Applicable Supplier names
* Kind
* Category

Hidden destinations must not influence Viewer results, ranking, counts, or truncation. Viewer redaction is as strict as Client search.

Ranking:

1. Exact Supplier reference
2. Exact email
3. Exact phone
4. Exact applicable name
5. All-token name prefix
6. Category, locality, postal code, or website-host match

Ties break by active status, displayed name, kind, then UUID. Select the match family associated with the best rank, not an independent lexical minimum of kind labels.

M1C results always represent Suppliers. Location and Supplier Contact matches and subordinate-result types are added only in M1D.

## Permissions

Add exactly:

| Permission                      | Administrator | Staff | Viewer |
| ------------------------------- | ------------: | ----: | -----: |
| `view_supplier_directory`       |           Yes |   Yes |    Yes |
| `view_supplier_contact_details` |           Yes |   Yes |     No |
| `manage_supplier_directory`     |           Yes |   Yes |     No |

Create-anyway is part of `manage_supplier_directory`. Do not add an override permission.

Viewer may see Supplier identity, kind, reference, categories, and lifecycle status. Viewer may not see contact destinations or mutate anything.

## Audit

Add `Supplier` to both:

* `AuditEvent::SUBJECT_TYPES`
* `RecordAdministrativeAudit#ensure_subject_belongs_to_agency!`

Add:

```text
supplier.created
supplier.updated
supplier.categories_changed
supplier.contact_updated
supplier.inactivated
supplier.reactivated
supplier.duplicate_override
```

Every child operation uses Supplier as its subject. Contact-point details include `contact_point_id`, `contact_point_type`, and `changed_fields`. Details may also contain status transitions, category codes, candidate IDs, signals, and fixed reason codes. Never store names, contact destinations, URLs, DBA text, `other_label`, or other free text.

## Routes

```text
GET   /suppliers
GET   /suppliers/new
POST  /suppliers
GET   /suppliers/:supplier_id
GET   /suppliers/:supplier_id/edit
PATCH /suppliers/:supplier_id
GET   /suppliers/:supplier_id/status/edit
PATCH /suppliers/:supplier_id/status
GET   /suppliers/:supplier_id/categories/edit
PATCH /suppliers/:supplier_id/categories
```

Add standard nested create/edit/status routes for Supplier email, phone, postal, and website contact points, including:

```text
POST /suppliers/:supplier_id/<channel>/:contact_point_id/set_primary
```

That member action requires `lock_version`, locks the channel’s rows in UUID order, and writes no second audit when preferred is unchanged. Preferred may also change through the ordinary edit PATCH. Do not add a `/preferred` route.

Do not add Location or Supplier Contact routes yet.

## UI

The Suppliers landing page includes:

* Search
* Status, kind, and category filters
* Supplier reference
* Displayed name
* Kind
* Categories
* Lifecycle status
* New Supplier action for authorized users

The Supplier profile includes:

* Identity and reference
* Organization or individual name facts
* Categories
* Contact-point panels with Set primary where authorized
* Lifecycle status
* Focused edit, category, and status actions

Do not render empty Location or Supplier Contact panels before M1D. Do not show Suppliers navigation until these authorized routes ship.

The creation form chooses kind first and exposes only the relevant fields. It requires at least one category. Server validation remains authoritative even if JavaScript controls conditional presentation.

The lifecycle confirmation lists the contact points that will become inactive and explicitly says categories remain assigned.

## Required proof

At minimum, test:

* Both valid Supplier name shapes
* Every invalid mixed or incomplete name shape through direct database writes
* Kind, reference, Agency, and contact owner immutability
* Same-Agency composite foreign keys
* Fixed category codes, required non-empty category set, and `other_label` length/presence constraint
* Supplier sequence backfill, provisioning, exhaustion, rollback, and replay
* Atomic creation with initial categories
* Duplicate signals for both kinds, including organization-only legal name and individual first+last full name
* No Client/Supplier or cross-Agency duplicate leakage
* Duplicate override evidence and parallel replay
* Supplier inactivation cascade and no-restoration reactivation
* Inactive identity/category update allowed; contact create/reactivate blocked while inactive
* Contact-point validation, phone country, preference concurrency, and `set_primary`
* Search fields, ranking, filters, browse without `q`, cap, Viewer redaction, and index use
* Staff and Administrator workflows
* Viewer read-only behavior
* Cross-Agency reads and mutations returning not found
* Keyboard and responsive system workflows
* No new `btree_gist` constraint or Office column
* All M1A, M1B, identity, system, Tailwind, and CI checks remaining green

## Acceptance scenarios

M1C should demonstrate:

* Celebrity Cruises as an organization Supplier categorized `cruise_line`
* A DMC categorized `tour_operator_dmc`
* A separate motorcoach company categorized `ground_transportation`
* One individual Supplier
* A multi-category Supplier
* An `other` category with its required label
* An inactive Supplier retaining its reference and categories while its destinations remain inactive
* A likely duplicate selected as existing
* An audited create-anyway Supplier
* The same email on a Client Organization without cross-directory warning
* The same Supplier email in another Agency without collision or disclosure

## Acceptance gate

Product review closed the open decisions on 2026-09-14. This slice is **Accepted** and may be implemented when scheduled. Acceptance authorizes M1C only. It does not authorize Supplier Locations, Supplier Contacts, M1D–M1E, or Supplier Arrangements.
