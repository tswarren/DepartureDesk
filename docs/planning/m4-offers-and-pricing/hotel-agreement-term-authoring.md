# HA.2 — Hotel Agreement term authoring

**Status:** Shipped 2026-10-01  
**Location:** `docs/planning/m4-offers-and-pricing/hotel-agreement-term-authoring.md`  
**Parent:** [Hotel Agreement](hotel-agreement.md)  
**Sequence:** Second Hotel Agreement implementation slice  
**Prerequisite:** Amended by the [parent delivery note](hotel-agreement.md#28-delivery-sequence). HA.1 and HA.2 were implemented together. This slice does not record a separate earlier HA.1 landing.  
**Scope:** Typed `SupplierAgreementReference` authoring for all accepted Hotel term kinds  
**Does not authorize:** Supplier confirmation, activation, reviewed-none state, document storage, executable policy

---

## 1. Goal

Complete the Hotel Agreement working surface by allowing authorized Staff to create, edit, and remove version-owned Supplier agreement reference wording without reintroducing specialized contract-policy models.

HA.2 operates exclusively on `SupplierAgreementReference`.

---

## 2. Authorized kinds

Hotel Agreement supports exactly:

```text
deposit_derivation
attrition
deposit_refund
destination_fee
additional_nights
early_departure
cancellation
```

No custom kind is authorized.

---

## 3. Existing rebaseline kinds

These remain Item-scoped:

```text
deposit_derivation
attrition
deposit_refund
```

HA.2 allows Staff to edit them on an unconfirmed draft.

Their persistence remains the same generic `SupplierAgreementReference` model.

Do not restore:

- SupplierDepositBasis;
- HotelAttritionPolicy;
- SupplierDepositRefundClarification;
- equivalent replacement structures.

---

## 4. New writable kinds

HA.2 first authorizes Staff authoring of:

```text
destination_fee
additional_nights
early_departure
cancellation
```

These are readable contractual reference only.

They must not:

- create costs automatically;
- create capacity;
- create a Deadline;
- create a commitment;
- calculate a fee;
- calculate cancellation;
- change Client pricing;
- affect settlement.

---

## 5. Scope choice

For the four newly writable kinds, the Staff form explicitly chooses an allowed scope:

```text
This Hotel stay
Entire Supplier agreement
```

### Item scope

Persists `arrangement_item_id`.

### Agreement-wide scope

Persists on the exact Supplier Arrangement Version without Item ownership.

Do not infer scope from wording.

Do not duplicate a version-wide row onto multiple Hotel Items.

On other Hotel Item Agreement pages, a relevant version-wide term displays as:

> Agreement-wide term

and links to the same canonical record.

For each of the four optional kinds, a version has either one row for this Item or one row with no Item. `RecordSupplierAgreementReference` rejects the other scope. A database trigger rejects it as well.

The checklist stays seven rows. If both rows are already present, that checklist row is Needs attention and links to both records.

The first three rebaseline kinds remain Item-required. The command rejects a version-wide row for those three.

---

## 6. Editor

Use one shared typed Hotel agreement-term editor.

### Common fields

- governing wording;
- source description;
- Supplier reference;
- external reference;
- existing supported evidence/provenance metadata.

### Deposit-refund special case

Also show:

- original wording;
- governing wording.

Do not introduce structured clause fields.

---

## 7. Kind-specific helper text

The editor may show non-persistent guidance.

Examples:

### Attrition

> Record the Supplier’s governing attrition wording. DepartureDesk does not calculate pickup or attrition from this text.

### Destination Fee

> Record the Supplier’s fee or waiver provision. This does not create a Supplier cost, negative cost, or Client discount.

### Additional nights

> Record the Supplier’s availability or pricing wording. Additional inventory is created only when separately confirmed through the operational workflow.

### Early departure

> Record the Supplier’s governing early-departure provision. No fee is calculated here.

### Cancellation

> Record the Supplier’s governing cancellation wording. DepartureDesk does not calculate cancellation charges from this text.

The helper copy must not become domain authority.

---

## 8. Source default

The HA.1 workspace may provide a derived source default.

When creating a reference:

- prefill the common source when one exists;
- allow Staff to override it;
- copy the chosen values into the new reference.

There is no live shared source.

Changing one reference never mutates another.

If existing references have mixed provenance, start the form without a common default.

---

## 9. Create behavior

On an unconfirmed draft:

- authorized Staff may create an absent supported reference kind;
- Item/version ownership is verified;
- kind is fixed by the selected Agreement Terms row/action;
- normal Staff do not type an arbitrary kind value.

For the three Item-required kinds, Item scope is forced.

For the four new kinds, permitted scope is explicit.

---

## 10. Update behavior

On an unconfirmed draft:

- authorized Staff may edit wording and provenance;
- kind remains immutable;
- version/Item ownership remains immutable;
- optimistic-lock behavior follows repository convention.

Updating an agreement-wide term from any Hotel Agreement page edits the one canonical row.

---

## 11. Delete behavior

An unconfirmed draft reference may be removed.

Confirmed exact-version references may not be:

- inserted;
- updated;
- deleted.

Database enforcement remains authoritative.

Hotel Agreement should surface the domain error cleanly rather than depending on a raw PostgreSQL exception.

### Copied-reference warning

Readiness requires every predecessor `SupplierAgreementReference` to have a copy on the successor. Deleting that copy blocks activation of the successor until the copy exists again.

The delete confirmation for a row with `copied_from_id` says that before the delete proceeds. The delete still proceeds on an unconfirmed draft after that confirmation. A reference created on the successor, with no `copied_from_id`, does not get that warning.

HA.2 does not weaken successor-copy readiness. If readiness fails later, the Agreement page names the missing copied term.

---

## 12. Supplier-confirmation boundary

Supplier confirmation remains outside HA.2.

Once an exact Supplier Arrangement Version has Supplier confirmation:

- all reference authoring controls become read-only;
- the workspace explains that the version is Supplier confirmed;
- Staff use explicit successor creation to make changes.

No in-place correction bypass is authorized.

---

## 13. Successor behavior

Existing successor-copy behavior remains authoritative.

When a successor draft is created:

- agreement references are copied;
- copied rows preserve lineage;
- predecessor rows remain unchanged;
- successor rows are editable until successor confirmation.

Deleting a copied reference blocks activation readiness until that predecessor copy exists again. The delete warning in §11 states that before the delete. HA.2 does not weaken that rule.

---

## 14. Reviewed-none remains deferred

HA.2 does not create records meaning:

```text
no attrition
no cancellation
no destination fee
reviewed and absent
```

An absent reference remains:

> Not recorded

The distinction between:

- not reviewed;
- reviewed and no clause exists

belongs to Hotel Review & Activation.

Do not create empty placeholder `SupplierAgreementReference` rows.

---

## 15. No generalized annotation model

Do not add Staff-note persistence.

Existing evidence/provenance fields may be exposed only according to their existing meaning.

Do not mix internal interpretation into authoritative Supplier wording.

---

## 16. No document storage

`external_reference` or similar source identifiers may point to already-known evidence.

HA.2 does not add:

- uploads;
- blobs;
- managed agreement documents;
- attachment ownership;
- document-to-term associations.

---

## 17. Controller/mutation boundary

Use narrow typed endpoints/services around the existing command architecture.

Prefer extending `RecordSupplierAgreementReference` only where necessary to support the newly accepted kinds, the explicit scope choice, and rejection of a second scope for the same kind. Do not create one service class per term kind.

Deletion should likewise use an explicit authorized command/path if direct model deletion is not already the repository convention.

Keep:

- Agency authorization;
- exact version ownership;
- Item ownership;
- optimistic locking;
- idempotency where the command architecture requires it;
- Supplier-confirmation freeze.

---

## 18. Tests

### Per-kind mutation coverage

For each supported kind, prove relevant:

- create;
- update;
- delete;
- authorization;
- Agency isolation;
- exact-version ownership;
- Item ownership/scope;
- idempotency;
- optimistic locking;
- Supplier-confirmation immutability.

### Scope tests

Prove:

- first three kinds reject version-wide scope;
- newly accepted kinds can use Item scope;
- newly accepted kinds can use version-wide scope;
- a second scope for the same kind on one version is rejected by the command and by the database;
- a version-wide reference is not duplicated across Items;
- another Arrangement cannot access it.

### Provenance tests

Prove:

- common source prefills;
- override persists to only one reference;
- changing source on one term does not alter others;
- mixed existing provenance yields no common default;
- no live inheritance exists.

### Confirmation tests

Prove for exact-version confirmation:

- create rejected;
- update rejected;
- destroy rejected;
- database bypass rejected.

### Successor tests

Prove:

- references copy to successor;
- copied wording/provenance is semantically identical initially;
- predecessor remains immutable;
- successor editing changes only successor;
- successor remains editable until its own confirmation;
- deleting a copied reference warns that activation readiness will fail, and the readiness rule still fails after that delete.

### UI/system tests

Hilton Agreement journey should additionally prove:

1. edit an existing draft reference;
2. add Destination Fee;
3. add Additional nights;
4. add Early departure;
5. add Cancellation;
6. see source prefill;
7. override one source;
8. return to checklist and see Recorded states;
9. verify operational deposits/deadlines are unchanged;
10. confirm no generalized policy/calculation appears.

---

## 19. Hilton acceptance facts

The canonical fixture must continue to preserve the accepted Supplier facts without restructuring them.

Agreement reference should support Staff access to:

### Deposit derivation

The original four quantity × rate snapshots, $4,156 total, and 10% / 45% / 45% shares.

It does not recalculate the fixed Deposit Requirements.

### Attrition

Readable Supplier wording for:

- November 4 minimum 7;
- November 5 minimum 15;
- lost room revenue;
- relevant quoted rates/tax;
- qualifications already present in the fixture.

It does not calculate shortfall.

### Deposit refund

Preserve:

- earlier “Deposits are non-refundable” wording;
- governing refund wording including November 20, 2027.

November 20 is not a Deadline.

### Destination Fee

Preserve the $150 per room-night fee waiver/concession wording and associated included benefits as reference.

Do not post a negative cost.

### Additional nights

Preserve November 1–3 availability wording as reference only.

Do not create capacity until separately confirmed operationally.

### Early departure

Preserve Supplier wording only.

### Cancellation

Preserve Supplier wording only.

Do not calculate cancellation liability.

---

## 20. Acceptance criteria

HA.2 is complete when:

- all seven accepted Hotel kinds are authorable through Hotel Agreement;
- the first three remain Item-scoped;
- the later four support explicitly selected accepted scope;
- one scope per optional kind on a version;
- no custom kind exists;
- one generic `SupplierAgreementReference` family remains the only agreement-reference persistence;
- source default is convenience only;
- mixed provenance works;
- unconfirmed draft references can be created/edited/deleted;
- Supplier-confirmed references cannot be created/edited/deleted;
- successor copies remain editable until their own confirmation;
- operational Deposit/Deadline/inventory/rate authority is unaffected by reference wording;
- no reviewed-none state was introduced;
- no document storage exists;
- no executable policy was introduced;
- full suite is green.

---

## 21. Exit / next boundary

After HA.2 ships, Hotel Agreement is complete.

The next boundary is Accepted as [Hotel Review and Activation](hotel-review-and-activation.md).

That plan defines:

- which Hotel facts must be reviewed;
- required versus optional sections;
- how Staff record `reviewed — none`;
- Supplier-confirmation action and assertion;
- Hotel-specific activation readiness;
- blockers versus warnings;
- acknowledgments;
- transition into the governing operational version.

Hotel Lifecycle remains a later separate plan.