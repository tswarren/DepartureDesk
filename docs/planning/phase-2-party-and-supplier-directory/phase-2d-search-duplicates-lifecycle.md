Phase 2D is the directory-operations slice: find existing parties, warn before creating likely duplicates, and deactivate unused identities. It does not merge parties.

Implement 2D as three mergeable PRs (2D.1 lifecycle, 2D.2 search, 2D.3 duplicates) after the locked-docs PR. Do not land the whole slice in one review. Executable merge is Phase 2E.

# Phase 2D — Search, duplicates, and party lifecycle

## Status

**2D.1 through 2D.3 are implemented** in this repository (party lifecycle, `pg_trgm` search, and create-time duplicate warnings). Phase 2A, 2B, and 2C remain authoritative for identity, contacts, relationships, notes, and role profiles. Executable merge is Phase 2E. Travelers, payers, arrangements, and posted money remain out of scope.

The locked merge-participant policy is [phase-2e-party-merge.md](phase-2e-party-merge.md). 2D must not add merge persistence.

---

## 1. Goal

Make the operational directory safe to use before departures exist.

Phase 2D must demonstrate:

* Staff can find a person by name, alternate name, email, phone, and active external identifier.
* Creating a likely duplicate surfaces an access-safe warning.
* Staff may choose the existing party and add a client role, or create a justified separate identity after a strong warning.
* An unused duplicate can be deactivated after dependency checks.
* A supplier role can be deactivated without deactivating the party; an active role blocks party deactivation.
* Inactive parties are excluded from normal search and can be included explicitly, then reactivated without restoring roles or purposes.

---

## 2. Locked decisions

### 2.1 Lifecycle before rich search

`parties` already stores `active` / `deactivated` with reason columns. 2A reserved those columns; 2D owns the commands.

Ship `DeactivateParty` and `ReactivateParty` before trigram search so “include inactive” and unused-duplicate remediation are real.

Staff may deactivate an unblocked party. Administrators may too. Deactivation requires a reason and an audit event.

Reactivation clears deactivation metadata. It does not restore client or supplier roles, advisors, relationships, or contact-purpose assignments.

Do not cascade role deactivation from party deactivation. The operator deactivates roles first. Do not hard-delete or ship a privacy-erasure workflow.

Inactive parties cannot receive a new active role. 2C already enforces that with `party_status` projections. 2D must keep that race boundary: PostgreSQL rejects `parties.status` `active → deactivated` while an active profile holds the projection. Translate that FK violation to the same dependency conflict as the application checks.

### 2.2 Dependency registry

Deactivation runs an extensible check registry and a bounded sample (count plus five labels), matching office and advisor blockers.

Initial subscribers:

* Any membership link on the person (`agency_memberships.person_party_id`), including invited, active, and suspended. A membership person cannot be deactivated.
* Active client role.
* Active supplier role.
* Current household membership: a household with current `household_member` rows, or a person who is a current household member.
* Current `organization_contact` or `organization_affiliation` involving the party.
* Current primary relationship-purpose assignments (`priority = 1`) involving the party.

Do not deactivate roles, memberships, or relationships silently. Pending merge is Phase 2E and is not a 2D subscriber.

### 2.3 Search reuses the selector

One query path backs the directory index and `DirectoryPartySelector`.

Search uses authoritative Phase 2 fields. Do not add a universal search-document table.

Ship:

* `pg_trgm` matching on display name, sort name, and alternate `normalized_name`
* Contains matching on display and sort names so common substrings (for example “Tours”) find the party
* Exact normalized email and phone lookup via 2B normalizers
* Exact lookup of current external identifiers
* Active parties by default; explicit include-inactive
* Kind and role filters on the directory list
* Pagination and cross-agency tests
* Selector modes already shipped in 2C, plus include-inactive

The selector continues to return party UUIDs, never profile IDs.

Postal-address and affiliation trigram search are out of 2D. Office, advisor, and supplier-category filters stay off the reusable selector; they may be added to the directory list later.

### 2.4 Duplicate warnings are advisory

Duplicate detection never merges parties.

Outcomes: `possible`, `strong`, and `hard conflict`. Name-only matches are never strong.

Create-time signals use only fields on the party form:

* Person: name and date of birth
* Household: name
* Organization: legal name, trading name, and website

Do not expand create into a contact or identifier wizard. Hard uniqueness remains the 2C identifier insert path. Invitation and provisioning person-create matching is a follow-on; 2D.3 wires `CreateParty` only.

When candidates exist, the operator must choose to use the existing party, edit the proposal, or create separately. Creating after a **strong** match requires a reason and an audit event. Staff may make that choice. Possible matches may create separately without a reason after an explicit create-anyway confirmation.

Reassess after directory locks, immediately before insert.

Match summaries may include kind, status, and primary contact. They must not include administrator-only notes.

### 2.5 Remediation without merge

* Prevent likely duplicates before create.
* Allow justified create-anyway.
* Permit deactivation of an unused duplicate.
* An administrator-only note may cross-reference two live records.
* Do not add `duplicate_of_party_id` or `merged_into_party_id`.

Used duplicates (membership, roles, current relationships) are support remediation until Phase 2E.

### 2.6 Locks and audit

Party lifecycle and duplicate reassessment lock agency, then parties by UUID, then independently mutated rows. They do not lock the actor user first. Nested directory commands use already-held locks.

Audit:

* `directory.party_deactivated`
* `directory.party_reactivated`
* `directory.party_created` details include override strength, candidate ids, and reason when create-anyway follows a strong match

Subject remains `Party`. Unknown subject types still raise.

---

## 3. Persistence

No new identity tables.

2D.1 uses existing `parties` lifecycle columns.

2D.2 adds GIN `gin_trgm_ops` indexes on `parties.display_name`, `parties.sort_name`, and `party_alternate_names.normalized_name`. Exact lookup reuses existing btree indexes on contact `normalized_value` and identifier `normalized_value`.

2D.3 adds no duplicate or merge tables.

---

## 4. Commands and services

* `DeactivateParty` — `DirectoryCommand`; reason required; dependency registry; idempotent if already deactivated
* `ReactivateParty` — clears deactivation metadata; does not restore roles
* `DirectoryPartySelector` — extend query; default `include_inactive: false`
* `PartyDuplicateMatcher` — deterministic scoring for one kind and the proposed attributes
* `CreateParty` — call the matcher after agency lock and before insert; require override reason when the reassessment is still strong

---

## 5. UI

* Party show: lifecycle panel modeled on office lifecycle. Reason field. Deactivate is destructive; reactivate is secondary. Conflict alerts show the bounded sample.
* Directory index: `q`, kind, role, include-inactive. Preserve query params in pagination. Active by default.
* Add-to-directory: when the matcher returns candidates, list them with Use this record links and a create-anyway submit. Strong matches show a required override-reason field.
* After “use existing,” the operator adds client or supplier on that party’s Roles panel.

Reuse `dd-` classes. Do not add a JavaScript UI framework.

---

## 6. Testing

* Each deactivation blocker; FK race versus concurrent role activation; reactivation does not restore roles
* Cross-agency 404 on party lifecycle routes
* Staff and administrator can deactivate an unblocked party
* Selector and index exclude inactive unless opted in
* Trigram/substring name, alternate name, email, phone, identifier
* Possible versus strong versus no-match; name-only is not strong; override without reason rejected; stale strong match reassessed
* Duplicate summaries do not include administrator-only notes
* System demonstration covering the exit list below

---

## 7. Implementation sequence

### 2D.1 — Party lifecycle

Deactivate/reactivate commands, dependency registry, audit, show-page lifecycle, active-by-default lists and selector.

### 2D.2 — Search and selection

GIN indexes, selector query, directory index search form.

### 2D.3 — Duplicate warnings

Matcher, create-anyway workflow, audited strong override.

---

## 8. Exit demonstration

1. Search a person by name, alternate name, email, and phone.
2. Attempt a likely duplicate; review a safe summary.
3. Choose the existing party and add the client role.
4. Create a justified separate identity after a strong warning (audited).
5. Deactivate the unused duplicate after dependency checks.
6. Deactivate a supplier role without deactivating the party; fail party deactivation while that role is active.
7. Include inactive in search; reactivate; confirm roles, relationships, and purposes were not restored.
8. Selector still returns party UUIDs for existing modes.

---

## 9. Out of 2D

Executable merge, `merged_into_party_id`, pending merge plans, conflict JSON, session gates, contact/relationship/role consolidation, tombstones, unmerge, privacy erasure, create-form contact wizard, postal/affiliation search, invitation duplicate matching, travelers, payers, departures.
