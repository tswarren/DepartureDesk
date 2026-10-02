# Supplier complexity rebaseline

**Status:** Accepted 2026-10-01 and implemented.  
**Authority:** ADR 0015 — Supplier agreement operational modeling boundary  
**Scope:** Rebaseline three shipped Hotel Supplier structures introduced by Slice 3A.1  
**Location:** `docs/planning/m4-offers-and-pricing/supplier-complexity-rebaseline.md`

## 1. Purpose

ADR 0015 establishes the boundary between:

- operational definitions;
- contractual definitions;
- operational history; and
- version-owned agreement reference.

It identifies three structures introduced by Slice 3A.1 as **rebaseline candidates** rather than permanent Supplier-domain abstractions:

1. `SupplierDepositBasis`;
2. the structured Hotel attrition policy; and
3. the structured deposit-refund clarification.

This plan decides the MVP treatment of those three structures. Once Accepted, it authorizes the implementation necessary to move the application directly to that target model.

DepartureDesk is not in production. There is no production Supplier data requiring backward compatibility with these structures.

Accordingly:

- retired models, commands, validations, fixtures, and tests may be deleted rather than deprecated;
- no compatibility layer or dual-write period is required;
- existing development fixtures may be rewritten to the new representation;
- the implementation leaves one authoritative representation for each fact.

Absence of production data does not authorize rewriting Slice 3A.1 migration history. Schema removal uses a forward migration.

This plan does not reconsider Slice 3A.1 generally.

---

## 2. Authority and governing test

Use ADR 0015 §3.2 as the decision test.

A structured contractual definition is justified only when:

> The structured fields currently constrain or explain another authoritative record in a way version-owned source wording cannot.

A future calculator, pickup workflow, exposure projection, refund settlement workflow, cancellation workflow, or anticipated accounting use is not a reason to retain structure.

An earlier accepted plan naming fields is also not sufficient by itself.

For each candidate, select exactly one outcome:

- **Keep**
- **Simplify**
- **Leave dormant**
- **Replace with provenance-reference**

Keep a candidate only if it satisfies ADR 0015 §3.2. Otherwise simplify or replace it. **Leave dormant** requires a specific reason despite the absence of production compatibility constraints.

---

## 3. Fixed decisions

The following are not under review.

### 3.1 Operational Hotel definitions remain

Retain the existing operational authority for:

- stay and schedule;
- nightly room inventory;
- Supplier rates;
- `commission_treatment`;
- fixed Deposit Requirements;
- rooming-list Deadline; and
- Supplier confirmation.

This plan does not change their domain authority.

### 3.2 No parallel representation

The rebaseline must leave one authoritative representation for each of the three candidate facts.

Do not:

- preserve the old structured record while adding equivalent agreement-reference prose;
- introduce a second note or JSON representation beside the current model;
- dual-write old and new representations;
- keep deprecated structures solely for development compatibility.

Where this plan replaces a structure, implementation removes the old representation in the same rebaseline work.

### 3.3 Scope is limited to three structures

The authority granted by this plan is limited to:

- `SupplierDepositBasis`;
- structured Hotel attrition; and
- structured deposit-refund clarification.

It does not authorize reconsideration of other shipped Supplier-domain decisions.

### 3.4 No new Staff screen

This rebaseline changes schema, commands, validation, successor-copy behavior, fixtures, and tests. It does not add a deposit, attrition, or refund screen. Presentation of the resulting records belongs to Hotel Agreement.

---

## 4. Replacement record — `SupplierAgreementReference`

Replace with provenance-reference is implementable only when the authoritative replacement is named. ADR 0015 defines the agreement-reference class and its integrity rules. This plan defines the persistence shape.

One record family holds agreement reference. Do not add separate deposit-derivation, attrition, refund, cancellation, or amenity models.

### 4.1 Contract

`SupplierAgreementReference`:

- belongs to one exact `SupplierArrangementVersion`;
- stores the authoritative Supplier wording;
- stores provenance sufficient to identify the Supplier source, using ADR 0015 §10: a source description, a Supplier reference, an external or document reference when one is already known, and evidence the applicable command already supports;
- is editable while that Arrangement Version is draft;
- is immutable after Supplier confirmation;
- is copied onto a successor Arrangement Version;
- is not stored in `AuditEvent` details;
- has no executable policy fields.

This plan does not authorize document storage. An external or document reference, when already known, is an identifier. It is not an uploaded file.

### 4.2 Kind

Kind is a closed retrieval label. It does not select calculation, exposure, a Deadline, a commitment, or any other behavior.

The closed kinds are:

- `deposit_derivation`
- `attrition`
- `deposit_refund`
- `destination_fee`
- `additional_nights`
- `early_departure`
- `cancellation`

This plan writes only `deposit_derivation`, `attrition`, and `deposit_refund`, and only as the replacements for the three retired structures. Hotel Agreement is the plan that first records `destination_fee`, `additional_nights`, `early_departure`, and `cancellation`.

### 4.3 Item scope and cardinality

The three kinds this plan writes require an `ArrangementItem`. Each replaces a row that already belongs to one Item on one version.

At most one `SupplierAgreementReference` of a given kind exists for one Arrangement Version and one Arrangement Item.

An Item is optional only for a kind this plan does not write, when a later accepted plan records a version-wide clause.

### 4.4 Wording

`deposit_derivation` and `attrition` each store one authoritative wording field. That wording is the Supplier's governing text for the provision. It is not a reconstructed formula and not an input to a calculator.

`deposit_refund` stores two non-executable wording fields on the same record:

- `original_wording`, the Supplier's earlier sentence;
- `governing_wording`, the sentence that states the operative refund rule.

Both survive. Neither field is a policy input.

### 4.5 What this record does not do

A `SupplierAgreementReference` does not:

- reject or recalculate a Deposit Requirement;
- calculate pickup, attrition, tax, or a refund;
- open a commitment;
- create a Deadline, including from a date written inside the wording;
- create Needs attention;
- block Arrangement ending;
- create a receivable or a payment expectation;
- affect capacity, Client pricing, or settlement.

---

## 5. Decision A — `SupplierDepositBasis`

### 5.1 Current role

`SupplierDepositBasis` preserves the original derivation behind the three fixed Deposit Requirements for the Hilton room block:

| Night | Resource | Quantity | Rate | Extended |
| --- | --- | ---: | ---: | ---: |
| November 4 | Standard | 5 | 17300 | 86500 |
| November 4 | Deluxe | 2 | 22300 | 44600 |
| November 5 | Standard | 10 | 17300 | 173000 |
| November 5 | Deluxe | 5 | 22300 | 111500 |

The extended amounts total `415600` minor units ($4,156). Share links require:

| Requirement | Share | Fixed amount |
| --- | ---: | ---: |
| Initial | 10% (`1000` basis points) | `41560` |
| Second | 45% (`4500` basis points) | `187020` |
| Third | 45% (`4500` basis points) | `187020` |

While the Arrangement Version remains draft, that structure rejects fixed Deposit Requirements that no longer reproduce this derivation. Once those requirements are Supplier-confirmed, they are themselves the authoritative operational obligations. Later inventory changes do not recalculate a Supplier-established deposit.

The derivation does not independently create a Supplier obligation, determine a payment status, create a Deadline, affect exposure, affect capacity, affect Client pricing, or participate in settlement.

### 5.2 Decision

**Outcome: Replace with provenance-reference.**

This choice intentionally retires the draft-time mathematical rejection invariant. DepartureDesk will no longer reject a draft merely because the entered fixed Deposit Requirements no longer mathematically reproduce the original room-block derivation.

Fixed Deposit Requirements become the sole operational authority for those amounts. DepartureDesk does not maintain `SupplierDepositBasis` as a permanent Supplier-domain concept.

The version-owned `SupplierAgreementReference` of kind `deposit_derivation` preserves the complete original Hilton derivation in authoritative wording and provenance: the four quantity and rate snapshots, the $4,156 block total, and the 10% / 45% / 45% shares. Staff can read and verify the Supplier's basis from that reference. DepartureDesk does not model the derivation as an independently enforced domain object, and the wording is not an executable deposit formula.

### 5.3 Implementation consequence

Remove `SupplierDepositBasis`, its entries, and its share links, and remove the specialized persistence that exists only to support them.

Update Hotel deposit commands, validations, successor-copy behavior, the Hilton fixture, and tests. Do not add a deposit-entry screen or entry-time arithmetic UI.

The resulting model treats the fixed Deposit Requirements as authoritative and the derivation as the `deposit_derivation` agreement reference.

---

## 6. Decision B — structured Hotel attrition

### 6.1 Current role

The shipped Hotel attrition structure records:

- contracted room-night minima of 7 on November 4 and 15 on November 5;
- the only allowed consequence, `lost_room_revenue` at `10000` basis points (100%);
- zero-utilization rate snapshots of `17300` (Standard) and `22300` (Deluxe);
- a quoted tax rate of `1650` basis points (16.5%) on that fallback.

DepartureDesk currently does not calculate actual pickup, calculate an attrition shortfall, create an attrition Supplier Obligation, project contingent exposure from these fields, determine cancellation liability from them, reconcile attrition, apply them to Reservations, or use them for a lifecycle decision.

### 6.2 Decision

**Outcome: Replace with provenance-reference.**

Remove the structured Hotel attrition policy as an active Supplier-domain abstraction.

The version-owned `SupplierAgreementReference` of kind `attrition` preserves the Supplier-confirmed attrition provision. The Hilton reference wording must carry the facts that today exist on the policy row and its children:

- room-night minima of 7 and 15, each tied to its night;
- lost room revenue at 100%;
- zero-utilization rates of $173 and $223, each tied to its Resource;
- the 16.5% quoted tax on that fallback;
- the qualifications and exceptions already left as readable clauses by Slice 3A.1;
- the Supplier source, in provenance.

Those facts live in the wording and provenance. They do not become new columns, snapshots, or a smaller attrition model.

### 6.3 No operational behavior

This rebaseline does not create pickup calculations, attrition exposure, attrition commitments, Supplier Obligations, cancellation charges, attrition Deadlines, Needs attention findings, or Client-facing attrition behavior.

A later accepted pickup, exposure, cancellation, or reconciliation plan may introduce structured fields if those fields then satisfy ADR 0015.

### 6.4 Implementation consequence

Remove the specialized structured Hotel attrition persistence and the command, validation, successor-copy, fixture, and test behavior that exists only for that abstraction.

Replace that representation with the `attrition` agreement reference. Do not add an attrition screen.

---

## 7. Decision C — deposit-refund clarification

### 7.1 Current role

The shipped deposit-refund clarification preserves:

- `original_wording`: “Deposits are non-refundable.”
- `governing_wording`: “The Hotel refunds the agency on or before November 20, 2027, the amount actually paid toward the deposits minus the attrition shortfall.”
- `payer` and `recipient`, each closed to `agency`;
- `refund_due_on` of 2027-11-20.

DepartureDesk does not calculate the refund, calculate the attrition deduction, create a Supplier receivable, settle the refund, reconcile receipt of the refund, create a refund commitment, or treat `refund_due_on` as a Supplier Deadline.

`payer`, `recipient`, and `refund_due_on` do not constrain another authoritative record. The date's only current use would be display. ADR 0015 §3.2 does not justify a closed date column for that reason. November 20, 2027 is already stated in the governing sentence.

### 7.2 Decision

**Outcome: Replace with provenance-reference.**

Remove `SupplierDepositRefundClarification` as a specialized domain record.

The version-owned `SupplierAgreementReference` of kind `deposit_refund` keeps both sentences:

- original wording: “Deposits are non-refundable.”
- governing wording, including November 20, 2027, and the rule that the refund is the amount actually paid toward the deposits minus the attrition shortfall.

It does not keep `payer`, `recipient`, or `refund_due_on`.

A later accepted Supplier-refund workflow may promote the date into a Deadline or another structured fact if that fact then satisfies ADR 0015 §3.1 or §3.2.

### 7.3 November 20 boundary

This plan does not make November 20, 2027:

- a Supplier Deadline;
- a commitment;
- a Needs attention trigger;
- an ending blocker;
- a Supplier receivable;
- a payment expectation;
- an accounting event; or
- a refund transaction.

### 7.4 Implementation consequence

Remove the refund-clarification table and its command, validation, successor-copy, fixture, and test behavior. Record the two sentences and their provenance on the `deposit_refund` agreement reference. Do not add a refund screen.

---

## 8. Target Hotel Supplier model

After this rebaseline, Hotel Supplier information has two layers.

### 8.1 Operational definitions

Structured operational authority remains for:

```text
Stay and schedule
Nightly room inventory
Supplier rates
Commission treatment
Fixed Deposit Requirements
Rooming-list Deadline
Supplier confirmation
```

These remain unchanged by this rebaseline.

### 8.2 Version-owned agreement reference

`SupplierAgreementReference` holds provisions Staff need to retrieve and DepartureDesk does not currently operate from.

This plan records:

```text
deposit_derivation
attrition
deposit_refund
```

The same family may later hold, under Hotel Agreement:

```text
destination_fee
additional_nights
early_departure
cancellation
```

Every reference belongs to the applicable Supplier Arrangement Version, follows the Item and cardinality rules in §4, and follows ADR 0015 confirmation and immutability rules.

There is no third “lightly structured agreement information” class.

---

## 9. Implementation strategy

Because DepartureDesk has no production data, implementation moves directly to the target model.

Do not build compatibility adapters, legacy readers, dual-write paths, deprecated models kept solely for old data, or transitional UI supporting both representations.

Do not edit the Slice 3A.1 migrations. Add a forward migration that creates `SupplierAgreementReference` and drops the retired tables.

The implementation should:

1. add the agreement-reference schema and remove the three retired schemas in a forward migration;
2. update Hotel domain commands and validation;
3. update successor-copy behavior, including activation readiness copy requirements that currently name the retired families;
4. rewrite the Hilton fixture so each retired structure's preserved facts appear in the matching reference;
5. update or replace affected tests;
6. delete obsolete models and support code; and
7. verify that only one authoritative representation remains.

Do not add Staff screens in this work.

---

## 10. Required implementation inventory

Before deleting a candidate, inspect the shipped implementation and record:

1. model, table, and fields;
2. create and update commands;
3. validations;
4. confirmation behavior;
5. activation and readiness behavior;
6. successor-copy behavior;
7. fixture builders;
8. tests.

The inventory exists to catch hidden current consumers. It does not reopen the selected architecture merely because code exists.

If inspection discovers a present domain consumer inconsistent with this plan, stop that candidate's implementation and amend the plan before proceeding.

---

## 11. Explicit non-goals

This plan does not authorize:

- Hotel Agreement;
- Hotel Review and Activation;
- Hotel Lifecycle;
- a deposit, attrition, or refund Staff screen;
- document upload or managed Supplier agreement storage;
- Cruise document storage;
- a Supplier-refund Deadline type;
- conversion of November 20 into a Deadline;
- pickup calculations;
- attrition exposure calculations;
- Supplier refund calculations;
- refund settlement or reconciliation;
- cancellation calculations;
- a generalized Supplier contract-policy engine;
- Transportation;
- M4E;
- broad typed-UI cleanup;
- removal of unrelated generic M3 machinery;
- recording `destination_fee`, `additional_nights`, `early_departure`, or `cancellation` references;
- reconsideration of other shipped Supplier-domain structures.

Those require separate accepted plans.

---

## 12. Delivery sequence

### R1 — Verify current consumers

Inspect the implementation for all three candidates. Confirm whether any current consumer is missing from this plan. No architecture change occurs merely because unused persistence exists.

### R2 — Add `SupplierAgreementReference`

Add the record family in §4, including the closed kind catalog, required Item for the three kinds this plan writes, uniqueness, draft edit, confirmation immutability, successor copy, and ADR 0015 §10 provenance.

### R3 — Replace `SupplierDepositBasis`

Preserve fixed Deposit Requirements. Preserve the complete Hilton derivation as a `deposit_derivation` reference. Remove the basis, its entries, its share links, and the draft-time rejection invariant. Update the Hilton fixture and tests.

### R4 — Replace structured Hotel attrition

Preserve the Hilton attrition facts listed in §6.2 as an `attrition` reference. Remove structured attrition persistence. Update the Hilton fixture and tests. Verify no attrition calculation or exposure behavior was introduced.

### R5 — Replace the deposit-refund clarification

Preserve both refund sentences as a `deposit_refund` reference. Remove `payer`, `recipient`, and `refund_due_on`. Update the Hilton fixture and tests. Verify November 20, 2027 remains outside the Deadline subsystem.

### R6 — Prove the new baseline

Verify:

- operational Hotel definitions remain unchanged;
- fixed Deposit Requirements remain authoritative;
- no `SupplierDepositBasis`, structured attrition, or refund-clarification domain authority remains;
- the three retired facts exist only as `SupplierAgreementReference` rows;
- the Hilton derivation, attrition facts, and both refund sentences survived in those rows;
- November 20, 2027 is not a Deadline;
- no duplicate or parallel representation exists;
- successor and version behavior remains coherent;
- Supplier-confirmed agreement reference remains immutable;
- no new Staff screen was added;
- Hotel Agreement has not been implemented.

---

## 13. Acceptance criteria

This plan is ready to become Accepted when it explicitly locks these outcomes:

| Candidate | Outcome |
| --- | --- |
| `SupplierDepositBasis` | **Replace with provenance-reference** |
| Structured Hotel attrition | **Replace with provenance-reference** |
| Structured deposit-refund clarification | **Replace with provenance-reference** |

Acceptance also requires agreement that:

- the replacement is one `SupplierAgreementReference` family, as specified in §4;
- fixed Deposit Requirements remain authoritative;
- the draft-time deposit derivation check is intentionally retired;
- the Hilton derivation, attrition facts, and both refund sentences are preserved in agreement-reference wording and provenance;
- `payer`, `recipient`, and `refund_due_on` are removed;
- no backward-compatibility layer is required;
- schema change is a forward migration;
- no dual representation is allowed;
- operational Hotel definitions outside these three candidates remain unchanged;
- November 20, 2027 remains outside the Deadline subsystem;
- this plan adds no Staff screen; and
- all non-goals remain unauthorized.

---

## 14. Exit criteria for implementation

The rebaseline implementation is complete when:

- the forward migration has created `SupplierAgreementReference` and removed the obsolete schema;
- no obsolete model or command remains reachable;
- Hotel workflows that write these facts write only `SupplierAgreementReference`;
- Hilton fixture data uses that representation and still contains the preserved facts in §5.2, §6.2, and §7.2;
- all affected tests reflect the new boundary;
- the full suite is green;
- no parallel agreement-reference and structured representation exists for the same fact;
- ADR 0015's version and confirmation rules remain satisfied; and
- repository documentation describes the resulting Hotel Supplier model accurately.

---

## 15. What comes next

Hotel Agreement is Shipped 2026-10-01: [Hotel Agreement](hotel-agreement.md).

It presents the operational Hotel facts and the agreement references this plan establishes. It is the plan that first records Destination Fee, additional-night, early-departure, and cancellation references. It does not authorize document upload, a generalized Supplier contract-policy engine, refund calculations, attrition calculations, or new Deadline behavior.

After Hotel Agreement, [Hotel Review and Activation](hotel-review-and-activation.md) is in progress under the accepted 2026-10-02 amendment. Hotel Lifecycle still requires its own accepted plan.

No implementation of Hotel Review and Activation or Hotel Lifecycle begins under this rebaseline. Hotel Review and Activation later shipped under its own plan.
