# ADR 0006: Separate agency-user, client, and supplier identity domains

- Status: Accepted product boundary; implementation deferred
- Date: 2026-09-14
- Decision owners: DepartureDesk maintainers

## Context

The archived application used one agency-owned `Party` root for people, households, organizations, clients, suppliers, contacts, and agency workforce. Agency team identity also depended on a global `User` connected through `AgencyMembership`.

That design made reuse convenient but coupled authentication, workforce access, consumer identity, supplier identity, duplicate handling, lifecycle, and record merging. The rebuilt application already replaced global User and Membership with the agency-scoped `AgencyUser` defined by [ADR 0005](0005-agency-identity.md). The remaining identity domains need the same explicit boundary before directory implementation starts.

## Decision

DepartureDesk will not use a universal Party aggregate.

### Agency users

`AgencyUser` is the authenticated workforce account for exactly one Agency. It owns credentials, sessions, access role, and descriptive workforce context. It does not become the canonical personal identity for Clients, Travelers, Supplier Contacts, or other agencies.

Administrator, staff, and viewer are access roles. Advisor may later be introduced as an operational Agency Team responsibility; it is not an access role or the general name for workforce identity.

### Client domain

The Client directory will use consumer-side identities:

- `ClientPerson` for a natural person known on the consumer side;
- `ClientOrganization` for an organization known on the consumer side;
- `Client` for the payer/responsibility identity based on one Client Person or Client Organization;
- `Traveler` for a person who receives or may receive travel services; and
- `Household` for servicing and communication grouping.

Client, Traveler, Household membership, payment responsibility, communication authority, and occupancy remain separate facts. One must not be inferred from another.

### Supplier domain

The Supplier directory will use supplier-side identities:

- `Supplier` for the contracting or settlement counterparty;
- `SupplierContact` for a person used to communicate with that Supplier;
- `SupplierLocation` for a Supplier-owned operational place; and
- an explicitly named Service Provider reference when fulfillment is performed by someone other than the contracting Supplier.

A Supplier Contact is not silently shared with Client Person, Traveler, or AgencyUser.

### Same physical subject in multiple domains

The same physical person or organization may legitimately have separate records in multiple identity domains. For example, an Agency User who travels may also have a Client Person and Traveler record. Those records have independent lifecycle, permissions, contact use, and history.

MVP will not automatically synchronize, merge, or deduplicate across identity domains. A future cross-domain link may record that two records describe the same subject only if a later accepted decision defines its authority, privacy, lifecycle, unlinking, and conflict rules. Such a link must not collapse the records or make one domain's fields authoritative for another.

### Tenancy and identifiers

Every Client and Supplier record belongs directly to one Agency. Search, duplicate warnings, selection, lifecycle commands, and identifiers are Agency-scoped and fail closed. Request parameters never establish tenancy.

Human-readable references and external identifiers remain domain-qualified under [ADR 0004](0004-human-readable-references.md). No generic Party reference is introduced.

## Consequences

### Positive

- Authentication and workforce access remain independent of client and supplier servicing data.
- Client and Supplier lifecycle rules can evolve without a universal merge engine.
- Privacy and authorization can be defined for the context in which data is used.
- Supplier organizations and consumer organizations need not share incompatible fields or workflows.
- The application can represent an employee who travels without treating the authenticated account as a Traveler.

### Costs

- The same real-world subject may be entered more than once for different business contexts.
- Cross-domain reporting cannot assume a single identity key.
- Any later synchronization or linking feature requires explicit conflict and privacy rules.

## Alternatives rejected

### Restore universal Party

Rejected. It recreates the coupling deliberately removed by the rebuild.

### Make AgencyUser the person record

Rejected. Authentication identity and consumer or supplier identity have different tenancy, access, lifecycle, and privacy responsibilities.

### Automatically link records by email

Rejected. Email reuse, shared addresses, independently managed records, and privacy boundaries make automatic identity claims unsafe.

## Implementation boundary

This ADR establishes vocabulary and separation only. It does not create directory tables or routes. The accepted M1 plan must define exact persistence, lifecycle, permissions, normalization, duplicate behavior, and test gates before implementation.
