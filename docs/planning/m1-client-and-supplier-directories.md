# M1 — Client and Supplier directories

**Status:** Draft planning contract; not implementation authority

**Prerequisites:** [ADR 0005](../adr/0005-agency-identity.md), [ADR 0006](../adr/0006-separate-identity-domains.md), [MVP requirements](departure-desk-mvp.md), and [current architecture](../architecture/current-state.md)

## Goal

Give an Agency separate, searchable Client and Supplier directories without recreating a universal Party identity, coupling directory records to authentication, or prematurely adding Departures and commercial records.

## Proposed slices

| Slice | Working outcome |
| --- | --- |
| M1A | Client Person, Client payer identity, contact points, profile display/edit, and normalized search. |
| M1B | Traveler facts and Household servicing relationships without inferred responsibility or occupancy. |
| M1C | Client Organizations and organization-backed Client identities. |
| M1D | Supplier, Supplier Location, Supplier Contact, categories, and normalized search. |
| M1E | Duplicate warnings, lifecycle hardening, privacy/retention hooks, and cross-directory acceptance proof. |

Executable merge is deferred. Cross-domain linking and synchronization are deferred.

## Required boundaries

- Every directory record belongs directly to one Agency.
- AgencyUser is never the identity root for a Client Person, Traveler, Supplier Contact, or Supplier.
- Client Person and Supplier Contact are separate even when they describe the same physical person.
- Client identity, Traveler status, Household membership, communication authority, payer identity, and financial responsibility remain separate.
- A Supplier and Service Provider may later be different records or references; M1 must not assume contracting and fulfillment are always identical.
- Office may provide defaults, attribution, or reporting context only. It does not grant directory access.
- No Client, Supplier, Traveler, or Household record is global across agencies.

## Decisions required before acceptance

### Client identity

- Exact relationship among Client Person, Client Organization, and Client payer identity.
- Whether every Client Person receives a Client identity immediately or only when used commercially.
- Traveler creation and lifecycle relative to Client Person.
- Household ownership, membership dates, names, and contact behavior.
- Which legal, preference, accessibility, loyalty, and identity-document facts belong in M1 versus later trip context.

### Supplier identity

- Whether Supplier may represent both organizations and individuals in one table without Rails STI.
- Supplier Location ownership and whether locations can act as Service Providers.
- Supplier Contact lifecycle when a person changes employers.
- Category vocabulary and whether categories are Agency-configurable.

### Contact information

- Record shape for email, phone, and postal address.
- Primary/contact-purpose rules appropriate to each directory domain.
- Verification, suppression, invalidation, and historical retention.
- Whether shared Household or organization contact points are referenced or deliberately copied.

### Search and duplicates

- Normalization rules for names, email, phone, organization name, and external identifiers.
- Exact Agency-safe search fields and ranking.
- Strong and weak duplicate signals by record kind.
- Explicit create-anyway acknowledgment and audit behavior.
- Contractually unique external identifiers that must block duplicates.

### Lifecycle, retention, and permissions

- Active/inactive/closed vocabulary for every record kind.
- Dependencies that block deactivation versus create warnings.
- Reactivation rules.
- Retention, redaction, and access rules for sensitive Traveler facts.
- Initial permission catalog additions for viewing and managing Clients and Suppliers.

## Required implementation contract

Before coding, the accepted revision must provide:

1. Aggregate and ownership diagram.
2. Table/attribute catalog with nullability and normalization.
3. Same-Agency foreign-key matrix.
4. Lifecycle transition tables.
5. Permission matrix.
6. Audit action and subject additions.
7. Command list with lock order, idempotency, and error translation.
8. Search and duplicate-scoring rules.
9. Deactivation dependency catalog.
10. Route and UI surface inventory.
11. Accessibility, empty, unauthorized, validation, and responsive states.
12. Model, database, command, request, and system-test matrix.

## Acceptance scenarios

M1 must demonstrate, within one Agency:

- a person who is a Client and Traveler;
- a different person who pays for that Client's future trip without becoming a Traveler;
- a Household used for communication without implying payment or shared accommodation;
- an organization-backed Client;
- a contracting Supplier with two Locations and multiple Contacts;
- a Service Provider concept that is not silently treated as the contracting Supplier;
- likely-duplicate warnings followed by either selection of the existing record or an audited create-anyway outcome; and
- the same email existing in another Agency without disclosure or collision.

It must also demonstrate that an Agency User who travels receives a separate Client Person/Traveler identity and that changing either side does not silently update the other.

## Exit gate

M1 is complete only when both reference scenarios have enough Client and Supplier directory data to begin Departure modeling, cross-Agency reads and mutations fail closed, no Party/global User model or route has returned, and every implemented directory capability has a documented lifecycle and permission contract.
