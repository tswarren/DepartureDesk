# ADR 0009: Supplier contracting, service-provider, and operational-contact roles

- Status: Accepted. Not implementation authority.
- Date: 2026-09-16
- Decision owners: DepartureDesk maintainers

## Context

The Supplier that governs an agreement is not always the Supplier that performs every service. A cruise Arrangement may include a transfer performed by another provider, or different Occurrences of one Item may be performed by different providers. DepartureDesk must represent those differences without changing the governing counterparty or duplicating the Arrangement.

The Agency also needs a current person to contact about the Arrangement. That communication pointer changes operationally and should not rewrite the immutable agreement version that governed historical decisions.

Finally, Supplier lifecycle commands must not silently invalidate current Supplier planning. The model needs one deterministic provider-resolution rule and one integration with the existing Supplier-inactivation path.

## Decision

This ADR locks the role meanings required by [M3 closed decisions 6 and 10](../planning/m3-supplier-planning.md). It does not authorize Arrangement persistence or Supplier-inactivation dependencies by itself.

### Contracting Supplier

Every Supplier Arrangement has exactly one contracting Supplier.

- The contracting Supplier belongs to the same Agency and must be active when the Arrangement is created.
- It is immutable for the life of the Arrangement.
- A different contracting Supplier requires a new Arrangement.
- The contracting Supplier is the final Service Provider fallback when no more specific provider is recorded.

The contracting Supplier is not inferred from a contact, Item, Occurrence, Location, confirmation, or payment record.

### Service Provider resolution

An Arrangement Item may name a default Service Provider Supplier. A Service Occurrence may override that default.

The effective Service Provider is resolved from the exact Arrangement version in this order:

1. explicit Occurrence override;
2. explicit Item default; and
3. the Arrangement's contracting Supplier.

Only the explicit Item and Occurrence choices are stored. The effective provider is computed and is not persisted as a competing fact.

New provider assignments require an active same-Agency Supplier. Provider identity does not grant application authority and does not change the contracting counterparty.

### Arrangement contact

An Arrangement may hold one optional current operational contact.

- The pointer lives on the stable Arrangement rather than inside each version.
- When assigned, it must be an active same-Agency `SupplierContact` belonging to the contracting Supplier.
- It grants no access or commercial authority.
- Later contact or Supplier inactivation does not erase the pointer. Historical identity remains displayable until staff clear or replace it.
- Consequential records introduced later snapshot contact facts only when their own contract requires historical communication evidence.

Supplier Location attachment is not part of this decision and remains deferred.

### Supplier inactivation

The shipped `ChangeSupplierStatus` command remains the single Supplier lifecycle path.

Ordinary Supplier inactivation is blocked by current nonterminal Supplier-planning dependencies introduced by an accepted slice:

- a draft or active Arrangement using the Supplier as contracting Supplier;
- a current or future `planned` Service Occurrence using the Supplier as effective Service Provider.

An Item default blocks ordinary inactivation only when it resolves as the effective provider for a current or future `planned` Occurrence. An unused Item default with no applicable Occurrence does not block.

These references do not block ordinary inactivation:

- `ended` or `abandoned` Arrangements;
- `cancelled` Occurrences;
- `planned` Occurrences whose service window has already ended;
- a Supplier retained only as a historical confirmation issuer or provider.

A past service window does not assign fulfillment or `completed` status.

An Administrator with `force_inactivate_supplier_with_dependencies` may force inactivation with a required reason.

Forced inactivation:

- preserves every Arrangement, version, child identity, and definition;
- does not cancel, remove, replace, or reinterpret Supplier-planning facts;
- retains the shipped descendant cascade for Supplier Locations, Contacts, and destinations;
- prevents selection of the inactive Supplier for new work; and
- leaves affected draft planning in recovery mode.

Recovery mode permits only actions that reduce or resolve the dependency: clear a contact, remove or replace an inactive provider assignment, remove unpublished dependent draft structure, or abandon an unactivated draft. It does not permit new or expanded dependency on an inactive Supplier.

Because the contracting Supplier is immutable, an Arrangement whose contractor becomes inactive may be cleaned up or abandoned but cannot be moved to another contractor.

Reactivating a Supplier restores only the Supplier. It does not reopen, reactivate, reconfirm, or resolve any Supplier-planning record automatically.

## Consequences

### Positive

- Contracting responsibility remains stable even when fulfillment is delegated.
- One Item may have a normal provider while exceptional Occurrences identify another.
- Provider display and dependency checks use one deterministic rule.
- An unused Item default cannot strand an otherwise unused Supplier.
- The current communication contact may change without manufacturing a new commercial version.
- Supplier inactivation cannot silently strand or mutate current planning.

### Costs

- Commands that assign or inactivate Suppliers must share a lock order and recheck dependencies atomically.
- UI and queries must display both the contractor and the effective provider when they differ.
- Forced inactivation requires explicit recovery states and warnings rather than a destructive cascade.

## Alternatives rejected

### Treat every Service Provider as the contracting Supplier

Rejected. It cannot represent subcontracted or occurrence-specific fulfillment.

### Create another Arrangement whenever a provider differs

Rejected. Provider delegation does not necessarily create an independently governed agreement.

### Persist the effective provider on every Occurrence

Rejected. That would duplicate inherited facts and could become stale when a draft Item default changes.

### Treat every provider pointer as an independent current dependency

Rejected. An unused Item default would block ordinary inactivation of a Supplier that no current or future `planned` Occurrence uses.

### Version the operational contact

Rejected. The current communication person is operational metadata, not by itself an immutable commercial term.

### Automatically cancel or reassign work when a Supplier is inactivated

Rejected. Inactivation records Supplier availability; it does not prove cancellation, release, replacement, or another Supplier's acceptance.

## Implementation boundary

This ADR establishes role meanings and lifecycle authority. It does not authorize Arrangement persistence or Supplier-inactivation dependencies by itself.

Each M3 slice must add only the dependency checks and recovery behavior for records that slice actually introduces. M3A introduces contracting-Supplier, Item-provider, and Occurrence-provider dependencies under the effective-provider rule. Later slices extend the same command for Reservations, commitments, and other current nonterminal dependencies.
