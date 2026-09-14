# M1A — Individual Client

**Status:** Accepted slice plan. Implementation authority for the individual-Client vertical slice only.

**Parent:** [M1 — Client and Supplier directories](m1-client-and-supplier-directories.md), accepted 2026-09-14. The parent status line must read Accepted. This slice plan is not implementation authority while it remains Draft, and it cannot become implementation authority if the parent returns to Draft.

**Prerequisites:** [ADR 0004](../adr/0004-human-readable-references.md), [ADR 0005](../adr/0005-agency-identity.md), [ADR 0006](../adr/0006-separate-identity-domains.md), and the current agency-identity implementation

This slice implements the individual-Client vertical slice only. The parent contract governs lifecycle, duplicate acknowledgement, search permissions, phone and country normalization, reference issuance, and Office exclusion. This plan narrows that contract to Client Person and does not reopen it.

## In scope

M1A ships:

- Client Person create, update, show, and reversible lifecycle;
- explicit individual Client creation, including composite creation of a person and Client, and promotion of an existing person;
- person-owned email, phone, and postal contact points;
- Agency-scoped `CL-` reference issuance;
- permission-safe search and duplicate review;
- directory permissions, audit subjects, routes, and a Clients navigation link.

## Out of scope

Do not implement Client Organization, organization contacts, Suppliers, Locations, Supplier Contacts, websites, `btree_gist`, `citext`, `pg_trgm`, or an Organizations view. Do not add `client_organization_id`. Do not add Supplier permissions or a Suppliers navigation link. Do not restore a Directory label. Do not add `office_id` or accept an Office identifier. Do not edit the scenario documents.

M1B adds the organization source and the exactly-one-source check. Until then, a Client has exactly one source because `client_person_id` is required. M1C widens `reference_sequences.namespace` to include `supplier`, backfills a `supplier` sequence row for every existing Agency, and updates `ProvisionAgency` to create that row.

## Persistence

Add one forward migration. Update `db/structure.sql`. Do not touch `db/queue_structure.sql`.

Tables use `id: :uuid` with a database default of `uuidv7()`. UUID foreign keys declare `type: :uuid`. Rails may preassign UUIDv7 through `ApplicationRecord`. Copy the identity shape: unique `(id, agency_id)` on tenant parents, composite foreign keys that prove same-Agency ownership, `attr_readonly` plus `BEFORE UPDATE` triggers for immutable columns, and named constraints.

No M1A table stores `office_id`.

| Table | Required | Constraints |
| --- | --- | --- |
| `client_people` | `agency_id`, `first_name`, `last_name`, status | Optional `middle_name`, `suffix`, `preferred_name`. Required names trimmed and nonblank. Status is `active` or `inactive`. |
| `clients` | `agency_id`, `client_person_id`, `client_reference`, `status`, `lock_version` | Composite FK `(client_person_id, agency_id)`. Status is `active` or `inactive`. `lock_version` is a nonnegative integer. One Client per person across all statuses. Reference unique per Agency and matches `CL-[0-9]{6}`. |
| `client_person_email_addresses` | owner, display value, normalized address | Normalized value is `lower(btrim(value))` and is checked in the database. |
| `client_person_phone_numbers` | owner, display `number`, E.164 `normalized_number`, `country_code` | Optional digits-only `extension` of at most 10 digits. Country is a required accepted ISO code. The base number never contains the extension. `normalized_number` is E.164: `+`, then a digit `1`–`9`, then at most 14 further digits. `number` stores that country’s national display format. |
| `client_person_postal_addresses` | owner, `line_1`, `country_code` | Additional lines, locality, region, and postal code are optional. Country is required uppercase ISO 3166-1 alpha-2. A country-only row is invalid. The database checks a nonblank uppercase ASCII country shape. |
| `reference_sequences` | `agency_id`, namespace, `next_value` | Unique `(agency_id, namespace)`. Namespace check is `client` only. `next_value` is the next unissued positive integer. A new row starts at 1. |

Contact-point rows carry immutable `agency_id`, immutable owner ID, label, status, `preferred`, nonnegative `lock_version`, and UTC `timestamptz` timestamps. A partial unique index allows at most one preferred active point per owner and channel. Zero preferred points is valid.

Immutable columns, enforced by trigger and `attr_readonly`:

- every `agency_id`;
- `clients.client_person_id` and `clients.client_reference`;
- contact-point owner IDs.

Person inactivation is blocked by an active Client. Successful inactivation inactivates that person's email, phone, and postal rows and clears their preferred flags in the same transaction. Reactivation restores neither the contact points nor the Client. There is no organization-contact blocker until M1B.

## Commands

Public commands live in `app/services`, matching the identity commands, and inherit `AgencyCommand`. Expected failures are not audited. Successful mutations audit in the same transaction.

| Command | Contract |
| --- | --- |
| `CreateClientPerson` | Person only. No Client and no reference. Uses person duplicate review. |
| `CreateIndividualClient` | Owns one transaction. Does not call another public create command. Lock Agency, validate any acknowledgement token, normalize, recompute duplicates, require acknowledgement when candidates exist, then create the person, Client, reference, and all required audit events, or nothing. |
| `CreateClientForPerson` | Locks an existing active person in the current Agency. Does not repeat source-identity duplicate review. An existing Client, including an inactive one, returns `already_exists` and points at reactivation. |
| `UpdateClientPerson` | Requires `lock_version`. Reviews changes to the person's name identity only. It does not review email, phone, or postal changes. Same name values are a no-op. Stale returns `conflict`. |
| `ChangeClientPersonStatus` | Already at the target is a no-op without another audit. Inactivation cascades owned contact points. |
| `ChangeClientStatus` | Lock Agency, then person, then Client, and recheck the person after locking. An inactive person blocks reactivation with `dependency_exists`. |
| `SearchClientDirectory` | Separate query object. Not a mutation and not audited. |
| `FindClientPersonDuplicates` | Same-Agency person signals only. |

Each contact-point family has explicit public commands:

- `CreateClientPersonEmailAddress`, `UpdateClientPersonEmailAddress`, `ChangeClientPersonEmailAddressStatus`, `SetPreferredClientPersonEmailAddress`
- the same four commands for phone numbers and postal addresses

Contact-point create and update commands review that channel's email, phone, or postal change. They do not call `UpdateClientPerson` to perform that review. Shared private implementation is allowed. Public commands accept only a Client Person owner. Setting preferred locks the owner and channel rows and clears the former preference. There is no `/preferred` route. The people list posts `set_primary`, which calls the existing set-preferred command. Status confirmation stays on `/status/edit` and is linked from the contact edit page, not from the list row. The edit `PATCH` may still change preferred.

Lock order is Agency, then the person, then child rows by UUID. Domain error codes are `unauthorized`, `invalid`, `invalid_state`, `dependency_exists`, `duplicate_review_required`, `already_exists`, `conflict`, and `reference_exhausted`. `reference_exhausted` is not a duplicate-review error.

## References

A nonexistent sequence row cannot be locked. The M1A migration creates the `client` sequence row with `next_value = 1` for every existing Agency. `ProvisionAgency` creates that Agency's `client` sequence row in the provisioning transaction. A missing row is an integrity error. Issuance does not silently create one.

Issuance locks the existing `(agency_id, namespace)` row, assigns the formatted reference, and increments `next_value` in the creation transaction. Rollback does not consume a number. Idempotent replay does not increment. Inactive Clients keep their references. Issuing `1000000` fails with `reference_exhausted`. Do not issue `SUP-` references.

## Permissions, tenancy, and controllers

Add these grants to `AccessPermission` and no others:

| Permission | Administrator | Staff | Viewer |
| --- | --- | --- | --- |
| `view_client_directory` | Yes | Yes | Yes |
| `view_client_contact_details` | Yes | Yes | No |
| `manage_client_directory` | Yes | Yes | No |

Directory controllers must not inherit `Administration::BaseController`. That controller requires `manage_agency_profile` and would lock staff out. Authorize each action with the named directory permission through `Authentication#require_permission!`. Load records through `Current.agency`. A missing or other-agency identifier is not found, not forbidden. Do not establish tenancy from `params[:agency_id]`. `Current.office` does not filter, default, attribute, or authorize these records.

Viewer mutation produces no side effect and no audit event.

## Routes and navigation

Implement only these paths. Member parameters are descriptive. `new` and `edit` are GET. Creates are POST. Updates and lifecycle changes are PATCH. Lifecycle confirmation is `/status/edit`; the mutation is `/status`.

- `GET /clients` — people landing page and search. No Organizations view.
- `GET /clients/new` — individual Client form. Do not offer Organization. M1B adds that choice when both creates exist.
- `POST /clients` — create a person and Client, or a Client for an existing person.
- `GET /clients/people/new` and `POST /clients/people` — person without a Client. The form states that no Client or trip role is created.
- `GET /clients/people/:client_person_id` — person profile.
- `GET /clients/people/:client_person_id/edit` — person identity editor.
- `PATCH /clients/people/:client_person_id` — update person identity.
- `GET /clients/people/:client_person_id/status/edit` — person lifecycle confirmation.
- `PATCH /clients/people/:client_person_id/status` — inactivate or reactivate person.
- `POST /clients/people/:client_person_id/client` — add the one permitted Client.
- `GET /clients/people/:client_person_id/client/status/edit` — Client lifecycle confirmation.
- `PATCH /clients/people/:client_person_id/client/status` — inactivate or reactivate Client.

Person contact-point routes use this grammar for `email-addresses`, `phone-numbers`, and `postal-addresses`. Do not add a channel or a preferred member route.

- `GET /clients/people/:client_person_id/<channel>/new`
- `POST /clients/people/:client_person_id/<channel>`
- `GET /clients/people/:client_person_id/<channel>/:contact_point_id/edit`
- `PATCH /clients/people/:client_person_id/<channel>/:contact_point_id`
- `GET /clients/people/:client_person_id/<channel>/:contact_point_id/status/edit`
- `PATCH /clients/people/:client_person_id/<channel>/:contact_point_id/status`

Do not add `/duplicate-review/:token`, a contact-point preferred route, or a standalone Client detail page. Duplicate review renders from the failing POST or PATCH with HTTP 422 and a signed hidden token. Create anyway resubmits to the same action. Submitted data and tokens never appear in the URL.

Add a real **Clients** sidebar link for users who have `view_client_directory`. Do not show Directory, Suppliers, Departures, Travelers, or Accounting. Update `NavigationHelper` and the interface contract's current-navigation section when the link ships. Keep Administration gated on `manage_agency_profile`.

## Normalization

Add `PhoneNumberNormalizer` and call `phonelib` only through it. Persist E.164 `normalized_number`, the country national display format in `number`, optional extension, and a required accepted `country_code`. The phone form chooses that country from the accepted country list and defaults it to the agency country. Parse the entered number in the selected country; a pasted international number must belong to that country. Display uses the national format when the number’s country matches the viewer’s agency, and the international format when it does not. Extract an unambiguous pasted `ext`, `extension`, or `x` suffix only when the extension field is blank. A conflict, invalid number, or implausible number is a validation error. Do not store a digits-only approximation.

The database checks `normalized_number` with `^\+[1-9][0-9]{0,14}$`: `+`, then a digit `1`–`9`, then at most 14 further digits. That shape check is not a plausibility check. `PhoneNumberNormalizer` remains authoritative for whether the value is a plausible telephone number.

Pin the existing direct `countries` gem version in the Gemfile. Wrap `ISO3166::Country` in an application object. Accept officially assigned territories. Reject `XX` and `ZZ`. The gem is not a currency authority. Do not add a PostgreSQL country enum. Do not add `addressable`.

Postal rows require `line_1` and `country_code`. Locality, region, postal code, and additional lines remain optional. A country-only row is invalid.

`dd_search_normalize(text)` is this immutable SQL function. It was created and used as a stored generated column on PostgreSQL 18.6. `normalize(text, text)`, `casefold(text)`, and `lower(text)` are catalog-immutable on that server. Plain `lower()` is not the case-folding function.

```sql
CREATE FUNCTION dd_search_normalize(input text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
RETURN regexp_replace(
  btrim(
    normalize(
      casefold((normalize(input, NFKC)) COLLATE "pg_unicode_fast"),
      NFKC
    )
  ),
  '[[:space:]]+',
  ' ',
  'g'
);
```

Use `normalize(input, NFKC)` without quoting the form; quoting it is a syntax error. A second NFKC follows `casefold` because case folding does not always preserve normalized form. Do not strip accents. Query tokens pass through this same function. ASCII `jose` does not match `josé`. Turkish `İ` folds to `i` plus a combining dot, not ASCII `i`. If a later PostgreSQL version rejects this body as immutable, stop and amend the parent contract. Do not substitute a different normalizer.

## Duplicate review

Person signals, from the parent contract:

- Strong: exact normalized email, or the same E.164 base number and extension.
- Weak: exact normalized full name plus matching postal code; exact full name alone; the same base number with a different or blank extension.

Signals are warnings, not uniqueness. Inactive candidates remain visible to actors who may view them. Responses expose only fields that actor may view.

Ordinary creates and updates with no candidates do not require an acknowledgement token. When candidates exist, return `duplicate_review_required` and a short-lived signed token. Tokens contain no names or contact values. There are two shapes.

Create tokens are used by `CreateClientPerson`, `CreateIndividualClient`, and contact-point create commands. Each contains preassigned UUIDv7 result IDs, Agency, actor, command kind, normalized fingerprint, ordered candidate/signal digest, issuance, expiration, and nonce. A composite create token contains both the proposed Person ID and the proposed Client ID.

Update tokens are used by `UpdateClientPerson` and contact-point update commands. Each contains the existing target ID, the expected `lock_version`, the normalized proposed fingerprint, the ordered candidate/signal digest, Agency, actor, command kind, issuance, expiration, and nonce. An update token does not preassign a new result ID.

Under the Agency lock, process either token in this order:

1. Verify signature, purpose, Agency, actor, and command kind. Failure returns `invalid` or `unauthorized`. Do not issue a fresh token.
2. Apply the create or update replay rule below before ordinary candidate recomputation.
3. Otherwise enforce expiration, fingerprint, and candidate/signal agreement before writing. A changed submission, changed candidate or signal set, or expired unused token returns `duplicate_review_required` with a fresh token of the same shape.

Create replay returns success without another write, reference, or audit event only when every signed proposed result already exists and, for composite creation, the Person and Client have the expected relationship. Do not apply expiration on that success path. If only one proposed result of a composite token exists, return `conflict`. Do not treat the partial result as a successful replay. Parallel submissions of one create token produce one reference and one audit set.

Update replay compares the target with the signed fingerprint. If the target already contains the acknowledged normalized values, return it as a no-op without another audit and without applying expiration. If those values differ and `lock_version` does not match the signed expected version, return `conflict` and do not apply the update. If those values differ and `lock_version` still matches, continue to expiration, fingerprint, and candidate/signal checks, then write or return a fresh update token. Do not treat a changed target as a successful replay.

A composite override may record person-created, Client-created, and duplicate-override events. A contact-point override records `client_person.contact_updated` and `client_person.duplicate_override` on the person subject. Create-anyway is part of `manage_client_directory`. Do not add an override permission.

## Search

Accept one free-text `q`. Reject blank or over-100-character queries without scanning. Do not reject a query because it looks like an email address or phone number.

Administrators and staff may match Client reference, person name, email, phone, and postal fields. Viewers match only visible fields, such as reference and display name. Hidden fields do not affect Viewer results, ranking, excerpts, counts, or duplicate responses. A permitted name match must not expose a hidden destination. An email-shaped Viewer query normally returns no results.

Default to active records. Status can be Active, Inactive, or both, and that filter does not require a search string. Reset clears both. Rank exact reference, email, phone, full name, then all-token prefix. Break ties by active status, display name, and UUID. Cap at 50 results and state when truncated. Digit-heavy phone matching uses the E.164 base number only after seven digits, and only when the actor may search phone fields. Extensions do not participate. Name queries require every token to match a normalized word prefix. No trigram or fuzzy matching. `EXPLAIN` assertions prove this index design; they do not replace it.

PostgreSQL 18 generated columns are virtual by default and cannot be indexed. Every search key below is a stored generated column.

| Query shape | Index |
| --- | --- |
| Exact Client reference | Unique `(agency_id, client_reference)` on `clients`. |
| Exact normalized name | B-tree `(agency_id, name_search_key)` on `client_people`. `name_search_key` is `dd_search_normalize` of the same name expression. Do not use `concat_ws`: it is `STABLE` on PostgreSQL 18.6, so a generated column that calls it is rejected. Use `||` with `coalesce` for each optional name part. |
| All-token name prefix | GIN index on stored `name_search_vector`, defined as `to_tsvector('simple', name_search_key)`. |
| Exact normalized email | B-tree `(agency_id, normalized_address)` on `client_person_email_addresses`. |
| Exact normalized phone | B-tree `(agency_id, normalized_number)` on `client_person_phone_numbers`. |
| Phone suffix of at least seven digits | B-tree `(agency_id, phone_digits_reversed text_pattern_ops)`. `phone_digits_reversed` is the reverse of the digits in `normalized_number`, excluding `+`. Match with a left-anchored `LIKE` on that reversed key. Extensions do not participate. |
| Exact normalized postal code | B-tree `(agency_id, postal_code_search_key)` on `client_person_postal_addresses`. |
| Locality prefix | B-tree `(agency_id, locality_search_key text_pattern_ops)`. Both postal keys use `dd_search_normalize`. |

All-token name matching builds a `simple` `tsquery` that ANDs one prefix lexeme (`token:*`) for every nonblank token from `dd_search_normalize(q)`. Escape lexeme punctuation so a token cannot change the query operator. A token that cannot be a lexeme makes the query return no rows rather than scan. Do not use the English configuration, stemming, `pg_trgm`, or accent folding. The `simple` parser retains a hyphenated token and also splits it, so both `jean:* & luc:*` and `jean-luc:*` match `Jean-Luc` after normalization. Prefix matching was verified on PostgreSQL 18.6: `josé:* & gar:*` matches `José García`; `jose:*` does not.

## Audit

Extend these together:

- `AuditEvent::SUBJECT_TYPES` with `ClientPerson` and `Client`;
- `AuditEvent::ACTIONS` with `client_person.created`, `.updated`, `.inactivated`, `.reactivated`, `.contact_updated`, `.duplicate_override`, and `client.created`, `.inactivated`, `.reactivated`;
- `RecordAdministrativeAudit#ensure_subject_belongs_to_agency!` so a `ClientPerson` or `Client` subject must belong to the event Agency.

Do not add organization or Supplier subject types. Contact-point commands use the Client Person as subject. Audit details contain IDs, status transitions, changed field names, candidate IDs, signal names, and duplicate-override reason codes. They never copy names, email, phone, postal address, or unrestricted free text.

## UI

Follow [docs/ui/interface-contract.md](../ui/interface-contract.md) and existing `dd-` classes. Pages are display-first. Lifecycle confirmation lists blockers and cascade effects and does not share an edit footer. Search works without JavaScript. Contact editors use a dedicated page or one open inline form. Viewer profiles omit contact destinations rather than masking them. Pair status color with text.

## Tests

Cover the M1A subset of the parent matrix:

- UUIDv7, timestamptz, named constraints, generated search keys, sequence start at 1, and absence of `office_id`;
- composite foreign keys reject cross-Agency pairing, and triggers reject tenant, source, owner, and reference mutation;
- phone shape and plausibility rejection, country-only postal rejection, contact preference, and no implicit link to `AgencyUser`;
- a missing `client` sequence row fails issuance and does not create a row; provisioning and migration create that row;
- success, invalid, unauthorized, inactive Agency, stale, not found, dependency, person-contact cascade, Client reactivation order, no-op, duplicate review, composite create that rolls back both records when review is required, create-token replay that does not double-issue, composite replay that returns `conflict` when only one proposed result exists, update-token replay that does not write again when the acknowledged values are already present, sequence exhaustion at `1000000`, and audit atomicity;
- parallel Client creation, reference issuance, preferred changes, and parallel submissions of one token producing one reference and one audit set;
- Viewer email-shaped query returning no hidden match; staff and administrator search of permitted fields; truncation, inactive filter, and cross-Agency isolation;
- request coverage for Viewer redaction and mutation rejection, staff and administrator success, 404 isolation, preserved errors, and duplicate-token states.

Add system tests for the browser workflows. They run in CI. The local Docker image has no Chrome, so a local browser run is not required for this slice. Existing authentication, administration, Office, invitation, audit, and isolation tests must remain green. Do not weaken them to add directory coverage.

Development fixtures and seeds are obviously fictional and idempotent. Do not seed real personal data. Do not print secrets.

## When this slice ships

Update `AGENTS.md`, current architecture, terminology, the interface contract navigation section, and [docs/README.md](../README.md) so Client Person and individual Client are distinguishable from the rest of M1. Do not describe organizations or Suppliers as shipped.

## Acceptance of this plan

Product review accepted this slice plan on 2026-09-14. That acceptance authorizes M1A implementation only. It does not authorize M1B–M1E.
