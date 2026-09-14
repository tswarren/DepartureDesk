# ADR 0004: Human-readable references and numbering

- Status: Accepted; amended 2026-09-14 for Client and Supplier references
- Date: 2026-09-05
- Decision owners: DepartureDesk maintainers

## Context

DepartureDesk records use UUIDv7 primary keys. Users and external parties also need recognizable references for search, conversation, printed documents, imports, exports, and reconciliation.

Different records have different issuance semantics:

- an office code is assigned at creation and rarely changes;
- a departure code may be known during planning;
- a client receipt number should be issued only when money is posted;
- a supplier confirmation, air ticket number, or insurance policy number is assigned externally;
- imported legacy references may not follow DepartureDesk formatting;
- legal or operational rules may prohibit reusing voided financial numbers even when gaps remain.

A single generic â€œnumberâ€ field or universal counter would conceal these differences. Using public references as tenant authorization would also create an enumeration and cross-agency disclosure risk.

## Decision

### Internal identity

- UUIDv7 is the durable internal identity for application-owned domain records.
- Foreign keys, URLs where practical, jobs, idempotency records, and audit subjects use UUID identity.
- A human-readable reference never establishes agency or office authorization.

### Reference vocabulary

Use qualified names in code and UI:

- `office_code`
- `departure_reference`
- `client_trip_reference`
- `receipt_number`
- `supplier_payment_reference`
- `supplier_confirmation_number`
- `ticket_number`
- `policy_number`
- `external_reference`
- `legacy_reference`

Avoid a generic `number`, `code`, `confirmation`, or `reference` when the owning concept is ambiguous.

### Generated versus external references

Application-generated references and externally assigned identifiers are separate facts.

- DepartureDesk may generate Client, Supplier, Departure, Client Trip, Receipt, or Supplier Payment references.
- Suppliers or settlement systems assign confirmation, ticket, policy, PNR, and similar identifiers.
- Imported identifiers retain their source and must not be rewritten into the generated namespace.
- An external identifier may be non-unique globally; uniqueness rules must reflect supplier, issuer, document type, and other relevant scope.

### Scope must be explicit

Every generated reference specification must declare:

1. record type or namespace;
2. agency scope;
3. office scope, if any;
4. reset period, if any;
5. issuance event;
6. formatting rules;
7. reuse and void behavior;
8. whether gaps are acceptable;
9. concurrency and retry behavior;
10. migration/import treatment.

No generator may infer these rules from a generic global default.

### Issuance and immutability

- A reference is assigned at the domain event where it becomes operationally meaningful.
- Issuance occurs in the same transaction as that event whenever possible.
- Once issued and externally visible, a reference is immutable.
- Corrections, reversals, cancellations, or voids retain the original reference.
- Issued references are never reused.
- Gaps are acceptable unless a later jurisdiction- or document-specific requirement explicitly forbids them.
- A failed draft that never received a reference does not consume one unless its domain requires reservation in advance.

### Concurrency and idempotency

- Generated references must be safe under concurrent issuance.
- Database uniqueness is authoritative.
- Expected collisions or retries must become deterministic domain outcomes rather than 500 errors.
- Retrying the same idempotent issuance returns the already-issued reference; it must not consume another number.
- Do not calculate the next reference with an unlocked `maximum + 1` query.

### Formatting and storage

- Store a normalized canonical reference suitable for equality lookup.
- Presentation decoration may be derived only when round-trip behavior is unambiguous.
- Prefixes must have defined meaning and may not be overloaded as authorization.
- Padding is presentation unless the canonical external form requires it.
- References are strings, even when their generated body is numeric.
- Case-insensitive references normalize to uppercase at input boundaries and have matching database guarantees.
- Never use floating point or locale-formatted numeric strings in generation.

### Office codes

The agency-identity baseline introduces the first governed human-readable identifier:

- office codes are operator-entered at office creation, except deterministic `MAIN` used by backfill and provisioning;
- they are unique within an agency;
- they are uppercase and immutable in MVP;
- they are not sequential and are not produced by a sequence table;
- they may qualify later references only when that later domain explicitly chooses office-scoped numbering;
- changing an office name does not change its code.

### Client and Supplier references

M1 introduces the first two generated operational-reference consumers and demonstrates shared semantics between them.

| Attribute | Client | Supplier |
| --- | --- | --- |
| Namespace | `client` | `supplier` |
| Canonical format | `CL-000001` | `SUP-000001` |
| Scope | Agency; never Office | Agency; never Office |
| Reset | Never | Never |
| Issuance | Successful Client creation | Successful Supplier creation |
| Reuse and gaps | Never reused; gaps accepted | Never reused; gaps accepted |
| Concurrency | Lock `(agency_id, namespace)` sequence row | Same |
| Retry | Existing reference consumes no number | Same |
| Import | Preserve legacy value in a separately named future external-reference record | Same |

Successful creation is the consequential transition for these records. They have no persisted pre-creation draft; after creation they are searchable, selectable, auditable, and externally discussable. Assigning the reference in the creation transaction therefore does not number an abandoned draft.

Client and Supplier demonstrate identical Agency scope, no reset, immutable issuance, accepted gaps, and sequence-row locking. A shared `reference_sequences` table keyed by `(agency_id, namespace)` is accepted for them and for a later domain only when that domain explicitly adopts these semantics. This remains separate namespaces, not one Agency-wide counter.

`CL-` and `SUP-` are domain-qualified formats. The commercial register's `D-000001` pattern establishes the no-Office-code baseline for generated references; it does not require every domain to use a one-letter prefix.

### Domain decisions deferred

This ADR deliberately does not decide the final formats or scopes of:

- departure references;
- client-trip references;
- receipt numbers;
- supplier-payment references;
- adjustment/reversal references;
- document numbers.

Each is locked in the phase that introduces the record. Client and Supplier have now satisfied the two-consumer threshold for the narrowly governed namespaced sequence above; domains with different issuance, reset, void, or idempotency semantics require their own persistence.

## Expected initial reference matrix

| Reference | Owner/issuer | Likely scope | Likely issuance event | 1E implementation |
|---|---|---|---|---|
| Office code | Administrator or provisioning | Agency | Office creation | Yes |
| Client reference | DepartureDesk | Agency | Successful Client creation | M1 |
| Supplier reference | DepartureDesk | Agency | Successful Supplier creation | M1 |
| Departure reference | DepartureDesk | Agency or office, decision deferred | Departure creation or publication | No |
| Client-trip reference | DepartureDesk | Agency or office, decision deferred | Client trip becomes operational | No |
| Receipt number | DepartureDesk | Agency or office, decision deferred | Receipt posting | No |
| Supplier-payment reference | DepartureDesk | Agency, decision deferred | Supplier payment posting | No |
| Supplier confirmation number | Supplier | Supplier/arrangement context | Supplier confirmation | No |
| PNR | Carrier/GDS | Booking-source context | Air reservation creation | No |
| Ticket number | Issuer/settlement system | Issuer/document rules | Ticket issuance | No |
| Policy number | Insurer | Insurer/product rules | Policy issuance | No |
| Legacy reference | Imported source | Source-defined | Import | No |

## Consequences

### Positive

- Internal identity remains stable even when displayed references differ by domain.
- Tenant authorization cannot accidentally depend on guessable sequential values.
- Financial numbering can later satisfy stricter posting and void rules without constraining ordinary operational codes.
- External supplier identifiers retain their meaning and provenance.
- The application avoids a speculative universal sequence engine.

### Costs

- Each numbered domain requires an explicit small design decision.
- Some screens and integrations must carry both UUID identity and a displayed reference.
- Consolidated search must understand several qualified reference types.
- Shared generation code will emerge later rather than being available from the first phase.

## Alternatives rejected

### Use UUIDs as the only visible identifiers

Rejected. UUIDs are poor spoken, printed, and reconciliation references.

### One agency-wide counter for every record

Rejected. It mixes unrelated namespaces and issuance rules and produces confusing gaps.

### One generic configurable sequence table in Foundation

Rejected. Foundation had no real generated-reference consumers and could not establish common scope, reset, void, or idempotency behavior. The later M1 amendment permits a narrow namespaced table only after Client and Supplier demonstrate the same semantics; it does not accept a generic configurable generator.

### Embed agency or office identity in every reference

Rejected as a universal rule. Prefixes may aid recognition, but they do not provide authorization and may become misleading after organizational changes.

### Reuse numbers after cancellation or deletion

Rejected. Reuse makes external communication, audit, and reconciliation ambiguous.

## Implementation checklist for every future numbered record

- Add a domain-specific ADR amendment or phase decision declaring the ten scope attributes above.
- Normalize before validation and persistence.
- Add named database uniqueness and format protections.
- Assign only at the declared lifecycle event.
- Make issuance transactional, concurrency-safe, and idempotent.
- Preserve references through cancellation, reversal, and archival.
- Keep supplier/external identifiers in separately named fields.
- Test parallel issuance, retry, void/cancel, cross-agency reuse, and unauthorized lookup.
- Add reference lookup to search only through agency-scoped queries.

## Relationship to the current roadmap

The agency-identity baseline implements the office-code portion of this ADR and establishes Office context vocabulary. M1 defines Client and Supplier references as the first generated operational references and permits their narrowly namespaced shared sequence. The accepted commercial register requires generated references without an Office-code prefix and assigns a durable reference at the record's first consequential transition. Each later record type must still define its exact prefix, scope, issuance event, and void behavior in the slice that introduces it. The first strict posted-document sequence remains owned by the relevant financial domain.