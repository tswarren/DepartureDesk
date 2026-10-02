# ADR 0015 — Supplier agreement operational modeling boundary

- **Status:** Accepted
- **Date:** 2026-10-01
- **Decision owners:** DepartureDesk maintainers
- **Scope:** MVP Supplier planning and typed Supplier Composition workflows
- **Related:** ADR 0008, ADR 0011, ADR 0012, ADR 0013, ADR 0014, [Slice 3A.1](../planning/m4-offers-and-pricing/m4d1-slice3a1-hotel-supplier-term-persistence.md)

## Context

DepartureDesk needs enough Supplier information to plan Departures, forecast Supplier economics, control supply, identify required Staff actions, support Client offers, and later fulfill Client Trips.

The shipped M3 Supplier-planning foundation supports a broad range of Supplier agreements. It includes versioned Supplier Arrangements and Items, Occurrences, Resources, capacity Pools and ledgers, Supplier cost definitions, activation and confirmations, Reservations, commitments, Deposit Requirements, Deadlines, exposure, and operational dispositions.

That breadth remains useful. Cruise agreements, Hotels, transportation, activities, meals, and other Supplier services have materially different commercial and operational terms. The generic Supplier-planning foundation must be capable of representing the operational facts those services need.

M4D.1 introduced typed Supplier Composition workflows over that foundation. The Cruise vertical demonstrated that typed workflows can translate a Supplier's natural concepts—sailings, cabin categories, rates, deposits, and deadlines—onto the generic model while Staff work in those concepts.

The Cruise work also recorded contractual wording DepartureDesk does not yet calculate, including tour-conductor and group-amenity-program terms.

The Hotel walkthrough exposed the same pressure more sharply. The Hilton fixture contains operational facts such as stay dates, nightly room inventory, room-category rates, Deposit Requirements, and a rooming-list deadline. It also contains contractual provisions for attrition, a Destination Fee waiver, additional-night availability, early departure, deposit refunds, and cancellation.

Slice 3A.1 then persisted four Hilton facts the generic model could not store losslessly: commission treatment, the original deposit derivation, a closed Hotel attrition policy, and a deposit-refund clarification. That slice added no attrition calculator, refund transaction, Reservation, or payment behavior. Its rule was to add contractual facts, not Hotel operations.

Modeling every material contract provision as an executable domain concept would turn DepartureDesk into a machine-readable copy of the Supplier contract. That is not an MVP requirement.

A contractual provision can still have closed semantics that another authoritative Supplier record depends on, before any calculator ships. Losing those semantics to general prose makes the operational record ambiguous. That is a different case from an amenity, concession, or cancellation paragraph whose only retained form is the sentence.

The distinction matters because every additional structured concept carries continuing costs:

- persistence and migrations;
- commands and permissions;
- version and copy semantics;
- optimistic locking;
- compatibility detection;
- typed editing;
- activation readiness;
- amendment and successor behavior;
- audit behavior;
- validation and fail-closed behavior;
- test coverage;
- interactions with later Client, accounting, cancellation, and reporting functionality.

The existence of a generic Supplier-planning capability does not require every typed Supplier workflow to exercise that capability for every contractual fact. The absence of a calculator does not, by itself, reduce a closed contractual fact to prose.

## Decision

### 1. DepartureDesk models the operational and contractual Supplier agreement, not the complete contract

For MVP:

> **Structure Supplier facts when DepartureDesk currently operates from them, or when an accepted workflow requires a closed contractual fact to be preserved losslessly as part of the Supplier agreement definition. Preserve other material provisions as version-owned agreement reference information. Do not implement calculations, enforcement, or generalized contract-policy behavior until an accepted workflow requires them.**

Supplier Composition structures the facts DepartureDesk currently operates from, and the closed contractual facts that satisfy [§3.2](#32-contractual-definition).

Other material Supplier terms remain available to Staff as agreement reference information until they satisfy §3.2 or an implemented workflow makes them operational definitions under [§3.1](#31-operational-definition).

Structured does not mean executable. Structured means DepartureDesk has established stable domain semantics for the fact and must preserve those semantics independently of prose.

---

## 2. Supplier information has four conceptual classes

Supplier information is classified according to the semantics DepartureDesk has accepted for it.

### 2.1 Operational definition

An **operational definition** is a Supplier fact DepartureDesk uses directly to:

- identify the contracted service;
- schedule the service;
- control or evaluate Supplier supply;
- calculate or forecast Supplier economics;
- identify an actionable Supplier payment or deposit requirement;
- identify an actionable Supplier deadline;
- validate compatibility with Client-facing supply;
- determine whether Supplier planning is operationally usable; or
- provide another implemented workflow with authoritative Supplier terms.

Examples include:

- Supplier and service identity;
- sailing or stay dates;
- cabin and room categories;
- controlled cabin or room quantities;
- contracted Supplier rates;
- occupancy-dependent Supplier charges;
- `commission_treatment` where it changes how those economics are read;
- Deposit Requirements;
- actionable Supplier Deadlines, including the rooming-list deadline;
- Supplier confirmation and reference information necessary to establish the agreement.

Operational definitions use the appropriate structured Supplier-planning authority. They are version-owned.

Where applicable, activated operational definitions remain immutable and participate in existing version, successor, compatibility, and audit contracts.

### 2.2 Contractual definition

A **contractual definition** is a closed Supplier fact that satisfies [§3.2](#32-contractual-definition). Its fields have stable domain semantics. DepartureDesk must preserve those semantics independently of prose. A current calculator, allocation engine, settlement workflow, or enforcement rule may not exist yet.

Persistence of a contractual definition does not authorize those behaviors. A later milestone may promote the fact into additional operational behavior. That promotion keeps the original contractual authority and adds the new behavior in the milestone that accepts it.

An accepted plan naming a fact is necessary where §3.2 requires one, and it is not sufficient. `commission_treatment` is an operational definition, not an example of this class: Hotel rates already depend on it. The three Slice 3A.1 structures still under review are rebaseline candidates in [§11.1](#111-hotel). They are not settled contractual definitions.

Contractual definitions are structured and version-owned. They follow the same immutability, successor, confirmation, and provenance rules as operational definitions.

Storing a contractual definition does not invent an exposure figure, a Deadline, a commitment, or a settlement. A contractual definition contributes to exposure or to a Deadline only where an accepted projection or plan explicitly consumes it.

### 2.3 Operational history

**Operational history** records consequential events against an established Supplier agreement. The event does not redefine the agreement itself.

Examples include:

- capacity ledger events already authorized by the applicable version-owned Pool and capacity contract, including permitted additions, releases, withdrawals, and dispositions;
- Reservations and Allocations when implemented;
- Deadline completion or waiver;
- Deposit Requirement handling;
- commitment dispositions;
- operational cancellation or release;
- other append-only lifecycle events.

Operational history uses the existing event, ledger, disposition, or lifecycle authority appropriate to the event.

An operational event does not require a successor Supplier Arrangement Version merely because it changes current operational state under an existing accepted command.

A ledger event must not redefine version-owned contracted inventory, opening terms, measurement basis, or other Supplier-confirmed capacity definitions. Changes to those definitions follow ADR 0008 successor semantics unless an existing accepted command explicitly owns the change.

### 2.4 Agreement reference

An **agreement reference** is a material Supplier fact Staff need to read or retrieve, and for which DepartureDesk has not established closed fields. Its retained structure is the sentence, the source identity, or both.

Examples at the current MVP boundary include:

- Cruise tour-conductor wording;
- Cruise group-amenity-program wording;
- Hotel Destination Fee waiver terms;
- Hotel additional-night availability language;
- Hotel early-departure terms;
- general Supplier cancellation prose, until an accepted cancellation workflow names closed semantics;
- amenities and concessions that do not change another authoritative Supplier record.

Agreement reference belongs to the exact Arrangement Version. Once that version is Supplier-confirmed, the original reference content is immutable. A correction that alters the understood agreement requires a successor Arrangement Version. A later superseding reference entry, if a plan introduces one, is its own domain record. `AuditEvent` details are not that record. This ADR does not authorize the schema of a superseding reference entry. See [Unresolved](#20-unresolved).

**Staff annotation** is separate. It may be added after confirmation. It is auditable. It does not represent Supplier-confirmed contractual content and does not change operational or contractual definitions.

Reference prose does not acquire operational authority over inventory, Supplier economics, Deposit Requirements, Deadlines, Client prices, Reservations, Payments, or accounting events. A typed workflow must not infer operational records from agreement-reference prose except through an explicit Staff action owned by the appropriate operational workflow.

---

## 3. Test for structured persistence

### 3.1 Operational definition

Before classifying a fact as an operational definition, the owning slice must identify the current behavior that consumes it.

At least one of the following must be true:

1. DepartureDesk calculates from the fact.
2. DepartureDesk allocates or validates supply using the fact.
3. DepartureDesk schedules or triggers Staff action from the fact.
4. DepartureDesk enforces a lifecycle, compatibility, or authorization rule using the fact.
5. An implemented MVP workflow requires the fact to be independently selected, filtered, aggregated, evaluated, or reported because its domain value affects that workflow's result or Staff action.
6. Another implemented domain workflow requires the fact as authoritative structured input.

Displaying a field, searching agreement text, or wanting a dedicated screen does not by itself justify structured domain persistence.

These six tests decide operational definitions. They are not the only path to structured persistence.

### 3.2 Contractual definition

A Supplier fact may also receive structured persistence when all of the following are true:

- the Supplier agreement expresses the fact with closed, independently meaningful semantics;
- the structured fields currently constrain or explain another authoritative record in a way version-owned source wording cannot;
- the semantics can be modeled without designing an unimplemented calculator, allocation engine, settlement workflow, or generalized policy language; and
- an accepted plan identifies the fact as part of the authoritative Supplier agreement definition.

Such a fact is a contractual definition. Its persistence does not authorize calculations or enforcement that have not separately been accepted.

A future calculator is not that reason. A hypothetical future calculation is not sufficient by itself. A wish to distinguish every materially different sentence in the contract is not sufficient by itself. An accepted plan naming the fields is not sufficient by itself. The structured fields have to do present work that version-owned source wording cannot do.

### 3.3 Later promotion

A later milestone may promote a contractual definition into additional operational behavior when that milestone accepts the consuming workflow.

Earlier contractual fields remain the authority for the agreement semantics they already record. The promoting milestone defines any new calculation, exposure, Deadline, confirmation, or amendment behavior. It does not replace the original contractual record with a second model for the same fact.

Agreement reference may later be promoted to a contractual definition only when it satisfies [§3.2](#32-contractual-definition), or to an operational definition only when it satisfies [§3.1](#31-operational-definition). Earlier reference wording does not silently become operational authority.

---

## 4. Typed Supplier workflows present Supplier-native concepts

The generic Supplier-planning model remains authoritative infrastructure.

Typed Supplier Composition workflows do not need to expose its grammar directly.

Staff should work primarily with Supplier-native concepts.

Examples:

```text
Cruise
Cabin category: O1 Prime Oceanview
Blocked cabins: 8
```

rather than requiring Staff to manage Resource, Occurrence, Capacity Pair, Pool, and measurement basis as the primary form.

And:

```text
Hotel
Standard rooms
Nov 4: 5
Nov 5: 10
```

rather than requiring Staff to manage nightly Occurrences, Capacity Pairs, and Pools as the primary form.

The typed workflow may orchestrate multiple generic commands when necessary to represent one natural Staff action.

The underlying generic records retain their existing invariants, evidence, locking, and audit requirements.

### 4.1 Generic capability is not typed-workflow obligation

The presence of a generic M3 capability does not require every typed vertical to expose or consume it.

A generic Deposit Requirement mechanism may support contract shapes beyond the current Hotel fixture. The Hotel typed workflow uses the portion current Hotel behavior requires. The shipped deposit basis remains part of that implementation until the rebaseline in [§19](#19-follow-up) changes it. This ADR does not treat that basis as a permanent contractual definition.

---

## 5. Activation semantics

Supplier Arrangement activation remains an MVP boundary.

Activation means:

> **DepartureDesk has enough confirmed Supplier information to rely operationally on the represented service and on the operational and contractual definitions accepted workflows designate for that service.**

Activation does not mean every material provision of the Supplier agreement has been converted into structured application data.

A typed vertical must not make an agreement-reference term an activation blocker solely because DepartureDesk knows that the term exists.

Contractual definitions that satisfy [§3.2](#32-contractual-definition) participate in readiness to the extent the accepted plan requires them to be present. Their presence does not attest that a calculator for those fields has shipped.

### 5.1 MVP activation questions

Typed readiness should answer, in Supplier-native language:

1. **What did we arrange?**
   Supplier, service, and schedule are sufficiently established.

2. **What supply can DepartureDesk rely on?**
   Required capacity or an explicit non-capacity basis is established.

3. **What will it cost?**
   Contracted Supplier economics required by the represented service are sufficiently established.

4. **What must Staff do?**
   Actionable Supplier payments, deposits, and Deadlines required by the agreement have been recorded, including an affirmative absence where the workflow must distinguish none from not-yet-reviewed.

5. **Did the Supplier establish these terms?**
   Required Supplier confirmation and evidence exist.

Vertical-specific readiness may refine these questions where the operational behavior genuinely differs.

It must not expand activation into an attestation that the entire contract has been modeled. It also must not treat uncalculated contractual definitions as if an exposure or settlement figure had already been produced from them.

### 5.2 Unknown versus none

Where readiness depends on whether an agreement contains a class of operational requirement, the typed workflow must distinguish:

```text
Not yet reviewed
```

from:

```text
Reviewed — none required
```

This may apply, for example, to actionable deposits or Deadlines.

Use the smallest persistence necessary to preserve that distinction.

Do not create empty operational definitions merely to represent affirmative absence.

---

## 6. Activated definitions and versioning remain authoritative

This ADR does not remove Supplier Arrangement versioning or activated-definition immutability.

Activated operational definitions and contractual definitions remain immutable according to the existing Supplier Arrangement version topology.

Versioning continues to protect:

- historical Supplier terms;
- Supplier supply provenance;
- Supplier economics provenance;
- closed contractual fields;
- downstream Client offer compatibility;
- published manifests that pin Supplier sources;
- amendment history;
- concurrent editing safety.

This ADR narrows which facts require versioned structured definitions. It does not weaken exact-version identity or immutability for the facts that do.

---

## 7. Successors are for definition changes, not every new fact

A successor Arrangement Version is appropriate when an activated operational definition or contractual definition must materially change and no existing operational event mechanism owns that change.

Examples may include:

- changed contracted service dates;
- changed contracted Supplier rates;
- changed structured Deposit Requirements;
- changed actionable Deadline definitions;
- changed fields of a shipped Slice 3A.1 rebaseline-candidate record, while that record remains the implementation of current Hotel behavior;
- other changes to version-owned facts that downstream behavior or another authoritative Supplier record relies upon.

A successor is not required merely because Staff add a Staff annotation.

Agreement-reference wording that changes the understood Supplier agreement does require a successor once the version is Supplier-confirmed. See [§2.4](#24-agreement-reference).

Operational changes already owned by append-only event or disposition machinery continue to use that machinery.

---

## 8. Supplier confirmation confirms the designated definitions

Supplier confirmation establishes that the Supplier has confirmed the operational and contractual definitions represented by the applicable Supplier Arrangement Version.

It does not attest that every clause of the Supplier contract has been transcribed into DepartureDesk.

Adding a Staff annotation after activation does not, by itself, invalidate Supplier confirmation.

Changing Supplier-confirmed agreement-reference wording, or a confirmed operational or contractual definition, follows the successor and immutability rules in [§6](#6-activated-definitions-and-versioning-remain-authoritative) and [§7](#7-successors-are-for-definition-changes-not-every-new-fact).

If a later milestone promotes a contractual definition into new operational behavior that affects facts already covered by confirmation, that milestone defines the required confirmation or amendment behavior.

---

## 9. Evidence remains consequential and is collected at Staff-action scope

Existing Supplier-planning evidence requirements remain authoritative for consequential records.

Typed workflows should collect evidence at the natural scope of the Staff action or Supplier source whenever several underlying records derive from the same evidence.

For example:

```text
Source
Hilton group agreement
```

may support one Staff action that establishes several nightly room-capacity records.

The typed workflow may propagate the same evidence to each underlying command that requires it.

This does not create a shared-evidence domain record unless a separate plan authorizes one.

The Staff experience should not require repeated evidence entry solely because one natural Supplier fact maps to several generic records.

---

## 10. Provenance identifies the Supplier source

Because DepartureDesk does not structure every contractual provision, Staff need a way to identify the authoritative Supplier source for both structured definitions and agreement reference.

DepartureDesk must preserve provenance sufficient to identify that source. Provenance may include:

- a source description;
- a Supplier reference;
- an external or document reference when one is already known;
- evidence the applicable command already supports.

Attachment and document-storage behavior is governed by separately accepted document-storage work. This ADR does not authorize it. Cruise document storage remains Deferred. The shipped Hotel Agreement does not authorize document storage.

Agreement-reference information must remain distinguishable from operational definitions and from contractual definitions.

---

## 11. Current MVP classification

This classification is the current MVP boundary. Later milestones may promote a fact into a contractual definition only when it satisfies [§3.2](#32-contractual-definition), or into additional operational behavior only when it satisfies [§3.1](#31-operational-definition).

[Slice 3A.1](../planning/m4-offers-and-pricing/m4d1-slice3a1-hotel-supplier-term-persistence.md) remains the historical authority for the behavior it shipped. This ADR supersedes only its assumption that all four persisted concepts stay permanent Supplier-domain abstractions. It does not reclassify the shipped records as dormant agreement reference, and it does not stop Hotel workflows from writing them. See [§12.2](#122-slice-3a1-and-the-three-rebaseline-candidates).

### 11.1 Hotel

| Fact | Classification |
| --- | --- |
| Stay and schedule | Operational definition |
| Nightly inventory | Operational definition |
| Supplier rates | Operational definition |
| `commission_treatment` | Operational definition |
| Deposit Requirements | Operational definition |
| Rooming-list deadline | Operational definition |
| `SupplierDepositBasis` and the original derivation | Rebaseline candidate |
| Attrition minima, consequence, and rate snapshots | Rebaseline candidate |
| Deposit-refund clarification | Rebaseline candidate |
| `refund_due_on` | Field of the shipped deposit-refund clarification. See [Unresolved](#20-unresolved). |
| Destination Fee waiver | Agreement reference |
| Additional-night availability | Agreement reference |
| Early-departure clause | Agreement reference |
| General cancellation prose | Agreement reference, until a cancellation workflow establishes operational semantics under [§3.1](#31-operational-definition) or contractual semantics under [§3.2](#32-contractual-definition) |

`commission_treatment` changes how Supplier economics are read now. Hotel rates depend on the distinction between unspecified and noncommissionable treatment.

The three fixed Deposit Requirements remain the actionable obligations. While a version is still draft, `SupplierDepositBasis` is the shipped check that those amounts still equal the original room-block derivation: the quantity and rate snapshots and the share links. Once the amounts are Supplier-confirmed, ADR 0008 makes them immutable, and the derivation may be provenance. [§19](#19-follow-up) decides whether that draft-time check is worth a permanent abstraction. This section does not.

The shipped Hotel attrition record keeps room-night minima, the closed 100% lost-room-revenue consequence, and zero-utilization rate snapshots. Storing them does not create a contingent-exposure figure. [§19](#19-follow-up) decides whether those fields currently disambiguate another authoritative record, or whether version-owned contract wording is sufficient until pickup or exposure behavior exists.

The shipped deposit-refund clarification keeps the original wording, the governing sentence, the agency payer, the agency recipient, and `refund_due_on`. The amount paid toward deposits, minus the attrition shortfall, stays in the governing sentence. This ADR does not add a money column for that amount. [§19](#19-follow-up) decides whether `payer`, `recipient`, and `refund_due_on` provide present domain value beyond that sentence. This ADR does not make `refund_due_on` a Deadline.

### 11.2 Operational history

Current or planned operational history includes, where applicable:

- capacity ledger events authorized by the version-owned Pool;
- confirmation-triggered openings;
- commitments;
- Deadline dispositions;
- Deposit Requirement handling;
- Reservation and capacity outcomes;
- releases and withdrawals;
- Arrangement lifecycle events.

### 11.3 Cruise commercial benefits

Tour-conductor and group-amenity-program terms stay agreement reference. The accepted Cruise slice recorded versioned wording and deferred entitlement calculation. That wording does not, by itself, establish closed fields beyond the sentence.

Promoting those terms to contractual definitions requires a later remediation that shows they satisfy [§3.2](#32-contractual-definition). Naming closed fields is not enough. This ADR does not reverse that slice, and it does not require a tour-conductor or group-amenity calculator.

---

## 12. Existing implementation

### 12.1 M3 remains authoritative

This ADR does not roll back or deprecate the shipped M3 Supplier-planning architecture.

In particular, it does not invalidate:

- Supplier Arrangement version topology;
- activated-definition immutability;
- capacity ledger semantics;
- Supplier cost definitions and forecast evaluation;
- Reservations and confirmations;
- operational commitments;
- Deposit Requirements;
- Supplier Deadlines;
- exposure and ending behavior.

The M3 foundation remains intentionally more capable than any one typed MVP workflow.

### 12.2 Slice 3A.1 and the three rebaseline candidates

Slice 3A.1 remains the historical authority for the behavior it shipped. ADR 0015 supersedes its assumption that all four persisted concepts stay permanent Supplier-domain abstractions.

`commission_treatment` is an operational definition.

These three shipped structures are rebaseline candidates. They are not permanent contractual definitions, and this ADR does not require a later agreement to copy them:

- `SupplierDepositBasis` and its original derivation;
- the structured Hotel attrition policy;
- the structured deposit-refund clarification.

Until an accepted rebaseline plan changes them, the shipped Slice 3A.1 records remain the authoritative implementation of the currently shipped Hotel behavior and continue to be written by Hotel workflows. Classification as a rebaseline candidate does not authorize parallel persistence, duplicate agreement-reference text, or partial replacement.

This rebaseline authority is limited to the three named Slice 3A.1 candidates. It does not create a general authority to reopen shipped Supplier-domain decisions.

Later Hotel plans do not define a second commission treatment, deposit basis, attrition policy, or refund clarification while these records remain that implementation. A later milestone may promote a fact that satisfies [§3.2](#32-contractual-definition) into additional operational behavior. That promotion keeps the contractual authority §3.2 established.

### 12.3 Existing Cruise structures

Existing Cruise commercial-benefit records remain shipped. This ADR classifies their current content as agreement reference, as [§11.3](#113-cruise-commercial-benefits) states. It does not require destructive removal, and it does not require Hotel, Transportation, Activity, or later typed verticals to copy Cruise wording records as if they were closed-field models.

A later remediation may establish closed fields for those Cruise terms only when they satisfy [§3.2](#32-contractual-definition). Until then, their Staff meaning remains: terms recorded; entitlement calculation deferred.

---

## 13. Consequences for Hotel Supplier Composition

Hotel Supplier Composition continues to structure the operational definitions in [§11.1](#111-hotel):

```text
Stay
Room inventory
Supplier rates
Commission treatment
Actionable Deposit Requirements
Actionable deadlines
Supplier confirmation
```

Current Hotel workflows also continue to write the three rebaseline candidates until [§19](#19-follow-up) changes that:

```text
SupplierDepositBasis
Structured Hotel attrition
Structured deposit-refund clarification
```

This ADR does not require a later agreement to copy those three structures. The accepted Hilton fixture remains the canonical source of Hotel facts.

The [Hotel Agreement plan](../planning/m4-offers-and-pricing/hotel-agreement.md) is Shipped 2026-10-01. This ADR does not assign that workflow a slice number.

---

## 14. Consequences for Cruise

Cruise continues to require structured:

```text
Sailing
Cabin inventory
Supplier rates
Actionable deposits and payments
Actionable deadlines
Supplier confirmation
```

Cruise commercial-benefit wording stays agreement reference under [§11.3](#113-cruise-commercial-benefits).

This ADR does not require Cruise remediation before other Supplier work continues.

---

## 15. Consequences for future verticals

Transportation, Activities, Meals, and other Supplier verticals begin from this ADR.

Each vertical should first identify:

1. its service and schedule;
2. whether and how DepartureDesk controls supply;
3. the Supplier economics required for forecasting;
4. actionable Supplier payments and deposits;
5. actionable Supplier Deadlines;
6. confirmation necessary to rely on the service;
7. any contractual definition satisfying [§3.2](#32-contractual-definition), including closed fields whose structured form currently constrains or explains another authoritative record in a way version-owned source wording cannot.

Other contract provisions default to agreement reference.

Shared typed infrastructure should be extracted only when multiple verticals ask the same Staff question and map it to the same operational or contractual semantics.

A generalized Supplier contract-policy engine remains unauthorized.

---

## 16. Alternatives considered

### 16.1 Fully structure every material Supplier contract term

Rejected for MVP.

This would maximize machine readability and require DepartureDesk to model contractual concepts before it has workflows capable of using them, including clauses whose only stable form is prose.

### 16.2 Store the entire Supplier agreement only as documents and notes

Rejected.

DepartureDesk must reason about supply, Supplier economics, deadlines, deposits, compatibility, and later fulfillment. Some contractual definitions genuinely satisfy [§3.2](#32-contractual-definition), and documents and notes alone cannot preserve that present domain integrity. Operational definitions such as `commission_treatment` show the same limit from the other side: Hotel rates already depend on that distinction, so agreement prose cannot replace it.

### 16.3 Treat every fact that lacks a calculator as agreement reference

Rejected.

That rule would discard a fact that still satisfies the present-domain-integrity test in [§3.2](#32-contractual-definition). Lack of a calculator is not a reason to discard those semantics. `commission_treatment` is an operational example of the broader distinction: it changes how Supplier economics are read now, without waiting for a later calculator. This alternative does not settle `SupplierDepositBasis`, structured Hotel attrition, or the structured deposit-refund clarification. Those three remain rebaseline candidates under [§19](#19-follow-up).

### 16.4 Build a generalized Supplier contract-policy engine now

Rejected for MVP.

Cruise and Hotel show heterogeneous contractual provisions. They do not show a common executable policy grammar required by current workflows.

A generalized policy engine would encode anticipated future behavior.

### 16.5 Remove sophisticated generic M3 capabilities

Rejected.

Cruise already demonstrates legitimate need for sophisticated capacity, occupancy-based economics, deposits, Deadlines, versioning, and operational history.

The boundary is which facts a typed workflow structures, and which of those facts are operational now versus contractual until a later workflow consumes them.

---

## 17. Consequences

### Positive

- Typed Supplier workflows stay aligned with the Supplier concepts Staff use.
- Closed contractual facts remain structured before a calculator ships when they satisfy the present-domain-integrity test in [§3.2](#32-contractual-definition).
- Future verticals have separate tests for operational definitions and contractual definitions.
- Activation covers the designated definitions for the service. It does not claim the whole contract was transcribed, and it does not claim an unbuilt calculator has run.
- Existing generic Supplier infrastructure remains available for agreements that need it.
- Agreement reference keeps a version and confirmation rule, so confirmed wording cannot drift under a confirmed version.
- Later milestones can promote a contractual definition when a real consuming workflow establishes the additional behavior.

### Negative

- Some important contractual sentences will not be independently queryable as closed fields.
- Staff will consult agreement-reference text for provisions the system has not given closed semantics.
- Promoting reference wording to closed fields later requires an accepted plan and an explicit transition.
- Contractual definitions add version, successor, and confirmation cost before their calculation exists. That cost is accepted only where [§3.2](#32-contractual-definition) is met.

---

## 18. Amendments to existing ADRs

### ADR 0008 and ADR 0012

This ADR amends ADR 0008 and ADR 0012 only as follows.

Supplier Arrangement Version completeness does not require a machine-readable representation of every material Supplier contract clause. It requires completeness of the operational and contractual definitions that accepted DepartureDesk workflows designate as authoritative for that typed Supplier service.

Activation confirms that those designated definitions are ready for use. It does not assert complete transcription of the Supplier contract.

This ADR does not weaken version ownership, immutability, successor requirements, Supplier confirmation, or historical provenance for facts classified as operational definitions or contractual definitions.

### ADR 0011

Supplier economics remain structured where DepartureDesk calculates or forecasts them, and where a contractual definition satisfying [§3.2](#32-contractual-definition) is required to keep those economics unambiguous. `commission_treatment` remains an operational part of that reading.

Agreement-reference terms do not become Supplier Cost Components merely because they may have financial implications in another context.

### ADR 0013

Actionable Deposit Requirements, Deadlines, commitments, and operational dispositions remain structured.

Contractual definitions may contribute to exposure or to Deadlines only where an accepted projection or plan explicitly consumes them. Merely storing a contractual definition does not invent an exposure calculation, a Deadline type, or a commitment.

This ADR does not promote non-actionable contract prose into those mechanisms.

### ADR 0014

Client offers may continue to pin exact Supplier source versions and depend on structured Supplier supply and economics.

Agreement-reference information does not affect Client compatibility or pricing unless a later accepted workflow explicitly promotes it.

---

## 19. Follow-up

Acceptance of this ADR may be followed by a separate MVP Supplier complexity rebaseline. That rebaseline decides only the three Slice 3A.1 candidates named in [§12.2](#122-slice-3a1-and-the-three-rebaseline-candidates). It answers:

- **Deposit basis.** Is the draft-time invariant worth a permanent abstraction, or are confirmed fixed Deposit Requirements plus version-owned derivation evidence sufficient?
- **Attrition.** Do the structured fields currently disambiguate another authoritative record, or is version-owned contract wording sufficient until pickup or exposure behavior exists?
- **Refund clarification.** Do `payer`, `recipient`, and `refund_due_on` provide present domain value beyond the governing sentence, without treating November 20 as a Deadline?

The allowed outcomes are keep, simplify, leave dormant, or replace with provenance-reference. The test is [§3.2](#32-contractual-definition). A future calculator is not a reason to keep the structure.

Until an accepted rebaseline plan changes them, the shipped Slice 3A.1 records remain the authoritative implementation of the currently shipped Hotel behavior and continue to be written by Hotel workflows. Classification as a rebaseline candidate does not authorize parallel persistence, duplicate agreement-reference text, or partial replacement.

This rebaseline authority is limited to the three named Slice 3A.1 candidates. It does not create a general authority to reopen shipped Supplier-domain decisions.

Separate follow-up work may remove typed UI that exposes generic grammar, identify dormant generic machinery, rename or reorganize workflows, reconcile retired slice numbers, and plan document support under a separately accepted document-storage plan. A later milestone may also promote a contractual definition that satisfies [§3.2](#32-contractual-definition) into additional operational behavior. Those activities do not expand the rebaseline's authority to reconsider shipped Supplier-domain decisions.

[Hotel Agreement](../planning/m4-offers-and-pricing/hotel-agreement.md) is Shipped 2026-10-01. [Hotel Review and Activation](../planning/m4-offers-and-pricing/hotel-review-and-activation.md) is Shipped 2026-10-02. Hotel Lifecycle, Transportation, and M4E remain Not authorized until their own accepted plans name that work. Cruise document storage remains Deferred.

---

## 20. Unresolved

Acceptance of this ADR does not decide the following.

### 20.1 November 20 refund date

`refund_due_on` remains a field of `SupplierDepositRefundClarification`.

The shipped Deadline catalog has no Supplier-refund type. Its types are deposit due, option or release, rooming list, legal names, final count, final schedule, cancellation cutoff, accessibility confirmation, and `other` with a required label.

An actionable Deadline can govern a commitment, create a Needs attention finding, and block Arrangement ending. An informational Deadline appears on the timeline and creates no Needs attention finding.

This ADR does not make `refund_due_on` a Deadline. A later accepted plan has to name a new Deadline type and say whether that Deadline opens a commitment.

### 20.2 Superseding agreement-reference record

Supplier-confirmed agreement reference is immutable, and a change that alters the understood agreement requires a successor Arrangement Version.

If a later plan introduces a superseding reference entry short of a full successor, that entry is its own domain record. This ADR does not authorize that record's schema. `AuditEvent` details are not a document-version store.

---

## Decision summary

DepartureDesk will not turn every material Supplier contract provision into structured MVP domain data, and it will not discard a closed contractual fact because its calculator has not shipped.

> **Structure Supplier facts when DepartureDesk currently operates from them, or when an accepted workflow requires a closed contractual fact to be preserved losslessly as part of the Supplier agreement definition. Preserve other material provisions as version-owned agreement reference information. Do not implement calculations, enforcement, or generalized contract-policy behavior until an accepted workflow requires them.**

The generic Supplier-planning foundation remains capable of supporting sophisticated agreements.

Typed Supplier workflows use the operational definitions [§3.1](#31-operational-definition) requires and the contractual definitions [§3.2](#32-contractual-definition) requires. The three Slice 3A.1 rebaseline candidates are not permanent contractual definitions. They remain the implementation of currently shipped Hotel behavior until the rebaseline changes them.

Activation means those designated definitions are ready to rely on. It does not mean the Supplier contract has been completely modeled.

Activated operational and contractual definitions remain immutable. Operational events use their existing lifecycle mechanisms. Supplier-confirmed agreement reference is version-owned and immutable. `refund_due_on` stays on the deposit-refund clarification until a later accepted plan decides whether it is also a Deadline.
