Phase 2E is executable same-kind party merge. It is **policy in this document** until a downstream domain needs a single surviving party UUID. Do not implement merge in Phase 2D.

# Phase 2E — Party merge

## Status

Planned policy. Phase 2D ships search, duplicate warnings, and party deactivation without merge persistence. Implement 2E immediately before the first domain that cannot operate with two live party UUIDs for one real-world identity (typically travelers, reservations, or posted money).

---

## 1. Goal

Consolidate two same-kind, same-agency parties into one surviving identity without rewriting history.

---

## 2. Locked policy

* Same agency and same party kind only. No cross-kind or cross-agency merge.
* Administrator-only. Staff create-anyway and deactivation are not merge.
* Identify a survivor and an absorbed party. The surviving UUID remains authoritative. Historical IDs are never reused.
* The absorbed party remains a durable, non-selectable tombstone or alias. Searches for the absorbed identity resolve to the survivor where authorized.
* The system never automatically merges parties.
* Automatic unmerge is not part of the application contract. An erroneous merge requires controlled administrative remediation.
* Historical snapshots, issued documents, and audit events are never rewritten.
* Contractually unique identifier conflicts block. Conflicting controlled identifiers cannot be silently combined.
* A merge runs in one database transaction, locks and revalidates both parties, and fails if either party changes disposition or gains an unresolved dependency before commit. Execution must be idempotent for the same survivor and absorbed party.
* Require a concurrency test covering two simultaneous merges involving the same party.
* A person linked to a membership may survive a merge. An absorbed person may not retain an active membership link. If only the absorbed person is linked, transfer that link to the survivor after confirming the survivor is unlinked. If both are linked, block pending administrator resolution.
* Merged and deactivated are different dispositions. An absorbed party cannot be independently reactivated.

### Fail-closed participant registry

A registered participant must declare whether its references are reassigned, preserved as historical references, consolidated, or block the merge. An unregistered party foreign key is an unresolved dependency and blocks merge. The merge service must never assume an unknown reference can be reassigned.

Every later domain that references a party must declare merge participation before that domain is complete.

Phase 2-owned participants, when 2E ships, include identities, kind profiles, contacts, alternate names, relationships, notes, client profiles, supplier profiles, external identifiers, and membership linkage under the transfer-or-block rule.

| Reference | Registered by | Until the 2E executor ships | When 2E implements the participant |
| --- | --- | --- | --- |
| `departure_party_role_assignments.party_id` | Phase 3A | Block merge as unsupported. Registration is not permission to guess, cascade, or silently repoint. 3A adds no merge persistence. | Preserve `party_display_name_snapshot`. Repoint the live Party FK only through this participant. Fail closed on overlapping same-role or two-current-primary conflicts. Do not alter `departure_team_assignments`; they reference memberships, not Party role identity. |

### A merge must identify

* Surviving party
* Absorbed party
* Actor
* Reason
* Field-resolution choices
* Contact, alternate-name, and relationship resolution
* Role-profile resolution
* Conflicting external-identifier disposition

---

## 3. Do not build until 2E implementation

* `party_merges` tables
* `merged_into_party_id` (deferred from 2A; still deferred in 2D)
* Pending merge plans
* Conflict-resolution JSON
* Database session gates for ownership mutation
* Automatic contact consolidation
* Relationship rewiring
* Role-profile consolidation
* Tombstone chains
* Participant discovery from PostgreSQL metadata
* Merge concurrency machinery beyond the required test once the executor exists
* Merge UI

2D duplicate remediation (prevent, create-anyway, deactivate unused, administrator note) is not a substitute for this phase and must not grow into a shadow merge model.

---

## 4. Exit demonstration (when implemented)

* Merge a confirmed same-kind duplicate as an administrator.
* Find the survivor through the absorbed identity.
* Confirm historical relationship and audit records remain intact.
* Confirm an absorbed person does not retain an active membership link.
* Confirm a second concurrent merge of the same party fails closed.
