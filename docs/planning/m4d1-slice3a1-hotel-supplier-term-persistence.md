# M4D.1 Slice 3A.1 — Hotel Supplier-term persistence foundations

**Status:** Accepted 2026-09-30 and implemented. This is the only Slice 3A.1. The compatibility proof is green. [Slice 3A.2](m4d1-slice3a2-hotel-stay-and-nightly-inventory.md), Stay and nightly inventory, is implemented. Hotel UI slices 3A.3–3A.6 remain unauthorized until their own accepted plans name that work.

**Parent:** [M4D.1 Slice 3A — Hotel Supplier Composition](m4d1-slice3a-hotel-supplier-composition.md). Acceptance of this plan amends that document's §23.

**Prerequisite:** The recorded Slice 3A.0 result, including the rate, rule-parameter, and confirmation remediations in `test/services/m4d1_slice3a0_hotel_persistence_compatibility_test.rb`. A green `main` that does not contain that result is not this prerequisite.

**Canonical fixture:** [Hilton Fort Lauderdale Marina 2027](fixtures/hilton-fort-lauderdale-marina-2027-canonical-scenario-draft.md).

**Scope:** Add the smallest versioned Supplier-domain persistence for the four Hilton facts that Slice 3A.0 proved cannot be represented losslessly. Rerun the Hilton compatibility proof against those additions.

This slice does not add Hotel routes, controllers, views, workspace navigation, or Hotel orchestration commands.

---

## 1. Goal

Slice 3A.0 proved that the shipped M3 Supplier model can already represent:

- the continuous Hotel stay;
- separate dated inventory-night Occurrences;
- the four category/night Pools;
- varying nightly openings;
- the locked room-night base plus occupancy-position supplements;
- one-night usage assumptions;
- the `$4,156` opening-block forecast;
- three fixed Supplier Deposit Requirements;
- the October 3 room-assignment Deadline; and
- generic Supplier confirmation evidence distinct from the missing original contract date and Hotel confirmation number.

It also identified four Supplier facts that cannot be stored losslessly:

1. explicit **net/noncommissionable** commercial treatment;
2. the immutable **original deposit derivation** behind the three fixed requirements;
3. the limited structured **Hotel attrition policy** required by the agreement; and
4. the versioned **deposit-refund clarification** that keeps the original wording and states the governing refund terms.

Slice 3A.1 adds only the persistence necessary for those four facts.

The rule is:

> Add contractual facts, not Hotel operations.

No attrition calculation, settlement, payment, refund, folio, Reservation, or Client behavior is introduced.

## 2. What this acceptance changes in the parent

Acceptance of this plan amends [Slice 3A §23](m4d1-slice3a-hotel-supplier-composition.md). The former 3A.1–3A.3 sequence is superseded. The former 3A.1 combined stay, inventory, and rates. The former 3A.3 combined review, activation, lifecycle, and closure. This amendment splits those UI slices. It does not ask them to invent a second persistence model for the four facts below.

| Slice | Scope |
| --- | --- |
| **3A.0** | Persistence compatibility gate. Complete. |
| **3A.1** | Supplier-term persistence foundations. This plan. |
| **3A.2** | Stay and nightly inventory. |
| **3A.3** | Supplier rates and economics. |
| **3A.4** | Agreement and operational requirements. |
| **3A.5** | Review and activation. |
| **3A.6** | Lifecycle and closure. |

Slices 3A.2–3A.6 display the records this slice persists. They do not define another commission treatment, deposit basis, attrition policy, or refund clarification.

## 3. Locked rate representation

The occupancy-increment shape is closed. It is not a fifth incompatibility and not a 3A.1 schema change.

```text
Shared room/night base
Standard: $173 × resource_nights
Deluxe:   $223 × resource_nights

Occupancy supplements
Position 3: $20 × occupancy_position_nights
Position 4: $20 × occupancy_position_nights
```

The base is not an occupancy range of positions 1–2. That range is counted once per matching occupant, so it would charge the room base twice for a double. Positions 1 and 2 share the base because one `resource_nights` charge covers the room. Positions 3 and 4 add $20 each.

The compatibility proof asserts one room evaluates to:

```text
Standard: 173 / 173 / 193 / 213
Deluxe:   223 / 223 / 243 / 263
```

It also retains the one-night-per-inventory-Pool proof: `$1,311 + $2,845 = $4,156`. An assumption of 2 nights evaluates to `$8,312` and is not the stored Hilton evaluation. The completed Triple and Quad prices are not stored as components.

## 4. Design constraints

All new facts belong to one Supplier Arrangement version. They follow the existing draft, activation, and successor lifecycle:

- editable on a draft version;
- frozen when that version is activated;
- copied onto a successor with `copied_from` lineage;
- tenant scoped through `Current.agency`;
- audited on the Supplier Arrangement;
- not found when addressed with another Agency's identifier.

Do not introduce:

- `HotelAgreement`, `HotelRate`, `HotelDeposit`, `HotelDeadline`, or `HotelRefund`;
- `HotelRefundClarification` or a general `SupplierAgreementTerm`;
- `HotelAttritionCharge` or an attrition calculator;
- a generalized non-Cruise adapter;
- `occurrence_role`;
- JSON or free-form `rule_parameters` as a substitute for typed contractual semantics.

Hotel attrition records may use Hotel-specific names because that policy is Hotel-specific. Do not generalize the other three facts into a policy framework.

Money amounts are `bigint` minor units with an explicit currency. Shares and the quoted tax rate are integer basis points where `10000` means 100%. Do not use floating point.

## 5. Explicit net/noncommissionable treatment

### 5.1 Fact

The Hilton room rates are net and noncommissionable. That is distinct from having no `expected_commission` component. Absence of that component can also mean commission has not been entered.

The cost definition stores:

```text
commission_treatment
├── unspecified
└── noncommissionable
```

Existing definitions, including Cruise definitions that carry `expected_commission`, default to `unspecified`. Do not infer `noncommissionable` from a missing commission component. Do not add `commissionable`. An `expected_commission` component remains the positive economic expectation.

Place the column on `SupplierCostDefinition`. One source can hold more than one definition, and those definitions can differ. Do not put the column on a Hotel record. There is no Hotel economic record.

### 5.2 Invariants

Every Hilton contracted definition that carries the room-night base and its supplements is `noncommissionable`, and it has no `expected_commission` component.

A definition marked `noncommissionable` rejects an `expected_commission` component.

An `unspecified` definition with no expected-commission component remains distinguishable from a `noncommissionable` definition.

## 6. Original deposit derivation

### 6.1 Fact

The three Hilton requirements stay `fixed_amount`:

```text
41560
187020
187020
```

minor units, due 2026-10-01, 2027-05-07, and 2027-10-04. Their `percentage` column stays null. `percentage_of_cost_sources` remains incorrect. No fourth requirement is created for the $0 October 4 adjustment.

The derivation is historical contractual evidence. Later changes to Pool quantities, Supplier rates, pickup, tax, added rooms, or added nights do not rebase the basis or the three fixed amounts.

### 6.2 Records

`SupplierDepositBasis` belongs to one Arrangement version and one Arrangement Item:

```text
SupplierDepositBasis
├── supplier_arrangement_version_id
├── arrangement_item_id
├── basis_kind: original_contracted_room_revenue
├── currency: USD
└── basis_amount_minor_units: 415600
```

`basis_kind` is the closed value `original_contracted_room_revenue`.

Each derivation entry snapshots one category on one inventory night. The Occurrence and Resource must belong to the basis Item and version.

```text
SupplierDepositBasisEntry
├── supplier_deposit_basis_id
├── service_occurrence_id
├── supplier_resource_id
├── agreed_quantity
├── agreed_unit_rate_minor_units
└── extended_amount_minor_units
```

Hilton entries:

| Night | Resource | Quantity | Rate | Extended |
| --- | --- | ---: | ---: | ---: |
| November 4 | Standard | 5 | 17300 | 86500 |
| November 4 | Deluxe | 2 | 22300 | 44600 |
| November 5 | Standard | 10 | 17300 | 173000 |
| November 5 | Deluxe | 5 | 22300 | 111500 |

Checks, each exact:

```text
quantity × agreed_unit_rate_minor_units = extended_amount_minor_units
86500 + 44600 = 131100
173000 + 111500 = 284500
131100 + 284500 = 415600
```

An explicit link connects each fixed requirement to that basis. The share is `share_basis_points` on the link, not `SupplierDepositRequirementDefinition.percentage`.

```text
SupplierDepositBasisShare
├── supplier_deposit_basis_id
├── supplier_deposit_requirement_definition_id
└── share_basis_points
```

| Requirement | Share | Basis points | Fixed amount |
| --- | ---: | ---: | ---: |
| Initial | 10% | 1000 | 41560 |
| Second | 45% | 4500 | 187020 |
| Third | 45% | 4500 | 187020 |

```text
415600 × share_basis_points = fixed_amount_minor_units × 10000
1000 + 4500 + 4500 = 10000
```

The basis does not attach itself to every deposit on the version. A second Hotel Item has no share link and does not participate. Currency matches the Departure operating currency and the linked requirements.

This is not a deposit calculation engine. The records answer why these fixed amounts equalled these values when agreed. They do not answer what the deposits would be from today's forecast.

## 7. Hotel attrition policy

### 7.1 Records

The policy row belongs to the Arrangement version and names the stable Item. It is not a row that hangs only on the Item and is therefore shared by every version.

```text
HotelAttritionPolicy
├── supplier_arrangement_version_id
├── arrangement_item_id
├── consequence: lost_room_revenue
├── consequence_basis_points: 10000
└── quoted_tax_rate_basis_points: 1650
```

The only allowed consequence pair is `lost_room_revenue` at `10000` basis points. That means 100% of lost room revenue for that date. The consequence is applied per attrition night. It is not a free percentage and not a stay-wide offset.

```text
HotelAttritionNight
├── hotel_attrition_policy_id
├── service_occurrence_id
└── minimum_utilized_room_nights
```

| Occurrence | Minimum utilized room nights |
| --- | ---: |
| November 4 | 7 |
| November 5 | 15 |

```text
HotelAttritionZeroUtilizationRate
├── hotel_attrition_policy_id
├── supplier_resource_id
└── amount_minor_units
```

| Resource | Snapshot |
| --- | ---: |
| Standard | 17300 |
| Deluxe | 22300 |

The Resource foreign key identifies the category. The minor units are the contractual snapshot. A later change to the current Supplier rate does not change the governing fallback.

The Occurrence and the Resource must belong to the policy's Item and version. A cross-Item or cross-version reference is rejected.

`1650` basis points is the combined quoted tax rate, 16.5%, on that fallback. The separate 9.5% and 7% components, and the illustrative `$685.74` opening-block tax, are not columns on this policy.

### 7.2 Readable qualifications stay readable

Do not structure these clauses:

- only approved-channel reservations count;
- reservations must use contracted rates;
- dates are evaluated independently;
- overachievement does not offset another date;
- released rooms remain in the minimum;
- ordinary shortfall uses the average utilized-room rate;
- a collected early-departure fee affects later attrition;
- no separate cancellation schedule exists.

### 7.3 No operationalization

Do not add `CalculateHotelAttrition`, `HotelAttritionObligation`, `HotelAttritionCharge`, utilized-room totals, an actual shortfall, or an actual tax amount.

> Attrition policy exists. Attrition liability does not yet exist.

## 8. Deposit-refund clarification

### 8.1 Record

One closed version-owned record. No `term_kind`. No structured-facts JSON. No polymorphic party.

```text
SupplierDepositRefundClarification
├── supplier_arrangement_version_id
├── arrangement_item_id
├── original_wording
├── governing_wording
├── payer: agency
├── recipient: agency
├── refund_due_on: 2027-11-20
├── evidence_note
├── recorded_by_id
└── recorded_at
```

`payer` and `recipient` are the closed value `agency`.

The retained original wording, adopted for this scenario and copied into the fixture, is:

> Deposits are non-refundable.

The governing wording is the accepted Slice 3A sentence:

> The Hotel refunds the agency on or before November 20, 2027, the amount actually paid toward the deposits minus the attrition shortfall.

`refund_due_on` does not replace that sentence. There is one clarification for the Item on the version. The amount paid minus the attrition shortfall is not a money column. Calculating it requires later payment and Reservation facts. Do not add a refund transaction.

`SupplierConfirmation` continues to store evidence date, channel, note, and either a Supplier identifier or `confirmed_without_identifier_reason`. It does not gain `contract_date`, a Hotel number, or `refund_due_on`. The Hilton original contract date and Hotel confirmation number remain blank.

### 8.2 Lifecycle

This is a versioned definition, not an append-only clarification log. On a draft, the row may be edited. Activation freezes it. A successor copies it. The clarification may be recorded on the current draft before the first activation. That draft has no governing predecessor, so recording it does not require a successor.

## 9. Commands

Each fact has its own command. Do not add a `SaveHotelAgreement` command that writes all four concepts atomically.

```text
SetSupplierCostCommissionTreatment
CreateSupplierDepositBasis
RecordHotelAttritionPolicy
RecordSupplierDepositRefundClarification
```

Names may follow repository command style. Responsibilities stay separate.

Every command:

- requires `manage_departures`;
- loads the Agency, Arrangement, version, and related records through `Current.agency`;
- operates on the exact draft Arrangement version;
- enforces the submitted version lock;
- follows the idempotency convention of the neighboring Supplier command it most closely resembles: an unchanged set is a noop, and a create replays on the same idempotency key and payload;
- audits the Supplier Arrangement in the same transaction;
- adds any new audit action to the closed `AuditEvent` catalog in the same change;
- rejects a mutation of an activated version;
- leaves valid sibling facts unchanged when validation fails.

`CreateSupplierDepositBasis` writes the basis, the four entries, and the three share links in one transaction. Replacing a draft basis is an explicit update of that draft row, not a second basis for the same Item on the same version.

## 10. Successor copying

`CreateSupplierArrangementSuccessor#copy_graph!` copies each new version-owned family and sets `copied_from` to the predecessor row. Deposit entries and share links copy with the basis and point at the successor's Occurrences, Resources, and Deposit Requirements through the existing identity map.

Activation lineage checking includes these families. A successor that omitted them does not activate.

The successor proof uses a focused activated version. It does not run the full Hotel activation journey. It establishes:

```text
Activated V1
├── deposit basis 415600, with the four entries and three shares
├── attrition policy, nights, and zero-utilization snapshots
└── refund clarification

Successor V2
├── copied deposit basis → copied_from the V1 basis
├── copied attrition policy → copied_from the V1 policy
└── copied clarification → copied_from the V1 clarification
```

Editing V2 does not change V1. The successor's `$4,156` basis is the copied historical basis. It is not regenerated from V2's current forecast.

## 11. Compatibility proof

Update `test/services/m4d1_slice3a0_hotel_persistence_compatibility_test.rb` so it no longer reports the four incompatibilities.

The rerun constructs the canonical Hilton draft through supported commands and proves:

- the locked `resource_nights` base and `$20` occupancy supplements, including the Single through Quad totals and the one-night `$4,156` forecast;
- `noncommissionable` on the Hilton rate definitions, with no `expected_commission` component, still distinct from an `unspecified` definition that also has no commission component;
- the four derivation entries, their extensions, the `415600` basis, and the `1000` / `4500` / `4500` shares, with each requirement's `percentage` null;
- attrition nights of 7 and 15 room nights on the exact Occurrences, `lost_room_revenue` at `10000` basis points, Resource snapshots of `17300` and `22300`, and quoted tax of `1650` basis points;
- the refund clarification's exact original wording, exact governing sentence, `agency` payer, `agency` recipient, and `2027-11-20`;
- generic confirmation still stores evidence date, channel, note, and `confirmed_without_identifier_reason`, and still creates no `SupplierArrangementCruiseAgreementConfirmation`.

The Hilton deposits and the rooming-list Deadline are still created with only their shipped date parameters. Probes that submit unsupported `rule_parameters` stay outside those canonical records.

A second Hotel Item still does not change the Hilton openings, the `$4,156` forecast, the three fixed amounts, or attach itself to the Hilton basis, attrition policy, or refund clarification.

## 12. Focused tests

In addition to the compatibility proof:

- `unspecified` and `noncommissionable` are distinguishable;
- `noncommissionable` rejects an `expected_commission` component;
- each derivation line satisfies `quantity × rate = extended`, and the shares satisfy the exact basis-point identity;
- changing current Pool quantities or rates leaves the basis, entries, shares, and fixed amounts unchanged;
- the derivation is read from the typed rows, not from a description;
- attrition nights and zero-utilization rates reject an Occurrence or Resource from another Item, version, or Agency;
- a second Hotel Item does not receive the Hilton basis, policy, or clarification;
- the clarification retains both exact wordings and the typed payer, recipient, and refund date;
- confirmation evidence and the clarification are different records;
- an activated version rejects mutation of all four facts;
- successor copying preserves lineage and does not regenerate the basis;
- another Agency's identifiers are not found;
- existing Cruise commission and deposit tests remain green.

## 13. Documentation result

When the implementation and the compatibility proof are green, record a 3A.1 result on the parent plan. That result states how each 3A.0 gap was closed:

| 3A.0 incompatibility | 3A.1 representation |
| --- | --- |
| Net/noncommissionable | `SupplierCostDefinition.commission_treatment` |
| Deposit derivation | version-and-Item deposit basis, four quantity/rate snapshots, and share links |
| Attrition | version-and-Item Hotel attrition policy, room-night minima, and Resource rate snapshots |
| Refund clarification | `SupplierDepositRefundClarification` |

Also record that the occupancy-increment representation stayed the locked `resource_nights` base plus `$20` supplements.

Then authorize the next slice named in the amended §23. That authorization is explicit. A green 3A.1 proof does not by itself start Hotel UI.

## 14. Non-goals

Slice 3A.1 does not implement Hotel UI, Hotel routes or controllers, a Hotel workspace shell, Hotel orchestration, Service Offers, Client room choices or prices, Package placement, Reservations, room assignments, pickup, folios, Supplier payments, Agency deposit payments, refund transactions, attrition calculations, early-departure calculations, automatic inventory release, document upload, Transportation, or a generalized non-Cruise framework.

These remain readable terms for a later agreement slice. This slice does not turn them into additional policy records:

- Destination Fee concession;
- November 1–3 availability conditions;
- early-departure policy;
- approved-channel and average-rate attrition qualifications;
- no separate cancellation schedule.

## 15. Exit

Every fact identified as a Slice 3A.0 persistence incompatibility has a lossless typed representation. The rerun compatibility proof constructs those representations without prose parsing, arbitrary `rule_parameters` storage, Cruise-specific records, or Hotel UI records.

Only then is the next Hotel slice, Slice 3A.2, eligible for authorization. That plan is [Slice 3A.2](m4d1-slice3a2-hotel-stay-and-nightly-inventory.md), and it is implemented.
