# ADR 0011: Supplier cost definitions and forecast evaluation

- Status: Accepted. Implementing slice is [M3C](../planning/m3c-cost-terms-and-forecasts.md) (Accepted; not yet shipped).
- Date: 2026-09-17
- Decision owners: DepartureDesk maintainers

## Context

Supplier planning needs cost forecasts before Client Trips, Travelers, Holds, Allocations, Supplier Obligations, invoices, or Payments exist. The Celebrity Beyond and Vineyard Tour examples require fixed, per-resource, per-person, per-night, occupancy-position, percentage, minimum, discount, tax, and expected-commission behavior without service-specific subclasses.

An estimate and later contracted terms describe the same economic cost. Treating them as additive records would overstate projected cost. Treating every edit as an immutable financial event would confuse tentative planning with posted accounting. Treating an absent definition as zero would understate cost.

M3A already provides an exact Arrangement version and stable Item, Occurrence, and Resource identities. ADR 0008 makes activated Arrangement versions immutable. ADR 0009 separates contracting Supplier from Service Provider. M3B is shipped for Supplier capacity. ADR 0001 requires integer minor-unit persistence, explicit currencies, strict parsing, exact arithmetic, and no implicit conversion. The commercial contract and M3 parent keep one Departure operating currency.

M3C therefore needs one durable calculation model that preserves provenance and reproducibility without adding a user-programmable expression language, a forecast ledger, Client-demand records, foreign-currency Supplier planning, or commission settlement.

## Decision

This ADR governs Supplier cost-term definitions and draft forecast evaluation. It does not authorize tables or commands by itself; [M3C](../planning/m3c-cost-terms-and-forecasts.md) is the Accepted implementing slice.

### Exact-version economic source

A `SupplierCostSource` is the stable identity of one economic Supplier cost within one exact Arrangement version.

It belongs to:

- one Agency and Departure;
- one Supplier Arrangement and exact Arrangement version;
- optionally one Arrangement Item;
- optionally one Service Occurrence;
- optionally one Supplier Resource; and
- one explicit charging Supplier selected from Suppliers assigned an eligible contractor or provider role in that exact version.

A source is either Arrangement-wide (no Item, Occurrence, or Resource) or Item-scoped (Item required; Occurrence and Resource independently narrow applicability). Arrangement-wide sources select only the Arrangement contractor. A source never points to an arbitrary set of Occurrences or Resources. A semantically different context or charging Supplier requires another source.

The source carries estimate and contracted definitions across stages within that exact version. It does not span Arrangement versions. M3D successor copying creates independent successor-version sources and preserves predecessor provenance without live inheritance.

### Staged definitions and readiness

Each source has at most one `estimate` definition and one `contracted` definition.

- Both remain editable while the governing Arrangement version is draft.
- A definition is `working` or `forecast_ready`.
- One `MarkCostDefinitionForecastReady` command validates the definition and records actor/time.
- A contracted definition additionally records a required Staff attestation and provenance statement that the entered terms reflect the Supplier agreement. Supporting documents are optional in M3C. Attestation is a planning claim only; it is not confirmation, effective contracted terms, or Arrangement activation.
- Any consequential term edit returns that definition to `working` and clears its readiness evidence.
- A deterministic readiness fingerprint covers the definition, ordered components, base links, and referenced participant-category semantics. Evaluation fails closed if stored readiness evidence does not match current facts.

Forecast precedence is per source:

1. use the complete forecast-ready contracted definition when present;
2. otherwise use the complete forecast-ready estimate definition;
3. otherwise report the source incomplete.

Stages are never merged component by component and never added together. If the selected stage later lacks a required usage input, the source is incomplete; evaluation does not silently fall back to an earlier stage.

### Currency and monetary ownership

Every definition owns exactly one recognized uppercase currency. That currency must equal the Departure `operating_currency`. All of its fixed monetary components inherit that currency. Component rows do not repeat a competing currency.

Estimate and contracted definitions for one source use the same currency. Agency or Departure defaults may seed entry but never reinterpret an existing definition.

The first retained currency-bearing cost definition freezes ordinary Departure currency change under the existing currency-bearing M3 fact rule. Those commands never rewrite, relabel, or convert stored cost amounts.

This ADR does not authorize foreign-currency Supplier cost definitions, functional-currency persistence, FX facts, Supplier Obligations, settlement, or accounting in another currency. Those require later accepted authority.

Monetary magnitudes use `bigint` minor units. Fractional rates use `numeric(20,10)` and store a decimal multiplier, where `1.0` means 100%. Floating point is prohibited.

### Definition modes

A definition mode is exactly:

- `calculated`; or
- `zero_cost`.

A calculated definition contains one or more components. A zero-cost definition contains no components and requires a reason. An absent definition, empty calculated definition, missing input, or invalid definition is unknown/incomplete, never zero.

M3C does not add a structured cross-source inclusion graph. A zero-cost reason may explain that the service is complimentary, Supplier-collected, or included elsewhere, but no text or zero mode creates a Client Charge, Supplier-collected payment, or cost allocation.

### Economic role and calculation kind

Every calculated component has one economic role independent of its calculation kind.

Economic roles are:

- `supplier_charge` — increases forecast Supplier cost;
- `supplier_credit` — decreases forecast Supplier cost;
- `expected_commission` — reported separately and never reduces Supplier cost; and
- `informational_allocation` — explains an amount already contained in another component and does not change Supplier cost or commission.

Stored monetary amounts and rates are nonnegative magnitudes. Direction comes from economic role and explicit base-link direction, never an unexplained negative number.

Calculation kinds are:

- `fixed`;
- `unit_rate`;
- `percentage`;
- `minimum_amount_shortfall`; and
- `minimum_quantity_shortfall`.

M3C uses one constrained component table with kind-specific checks. It does not create STI subclasses, a table per formula, a normalized operator tree, or executable user-authored expressions.

`minimum_amount_shortfall` preserves a monetary threshold against earlier monetary components. `minimum_quantity_shortfall` preserves a contractual quantity minimum against an earlier compatible `unit_rate` and evaluates `max(0, minimum_quantity − evaluated_quantity) × unit rate`. Arrangement-wide definitions may not use quantity bases or quantity shortfalls.

Commission settlement method and expected remittance are out of scope for this ADR. Expected commission remains a separate forecast measure only.

### Quantity bases and selectors

A unit-rate or quantity-shortfall component has exactly one closed quantity basis:

- `resource_units`;
- `persons`;
- `nights`;
- `resource_nights`;
- `person_nights`;
- `occupancy_positions`;
- `occupancy_position_nights`;
- `single_occupancy_units`; or
- `single_occupancy_nights`.

Where applicable, a component may select an Item-scoped participant category and/or an inclusive occupancy-position range. The selectors narrow an allowed quantity basis; they do not form an arbitrary predicate language.

These are calculation bases, not M3B capacity measurement bases. They do not create or alter Capacity Pools, infer availability, or convert Supplier supply into Client demand.

### Participant categories and anonymous occupancy profiles

M3C participant categories are exact-version, Item-scoped labels with stable IDs and manual order. They do not store age rules or automatically classify Travelers. M3C has no Traveler records.

A lightweight usage assumption exists at most once for each exact Item/optional Occurrence/optional Resource tuple. Matching cost sources reuse it. Assumptions and occupancy profiles are required only when a formula needs them; they are not mandatory for every Item.

The assumption may contain expected scalar quantities and anonymous occupancy profiles. One occupancy profile describes a number of like resource units and their ordered participant-category positions. It contains no name, Client, Traveler, payer, household, assignment, Hold, Allocation, or fulfillment fact.

When occupancy profiles exist, resource-unit, person, position, and single-occupancy counts are derived from them rather than duplicated as independently editable totals. Nights remain an explicit planning input when a formula requires them; Occurrence date ranges may seed the form but never silently determine billable nights.

M3C supports one current usage assumption per tuple. Named scenarios, baselines, alternatives, and historical assumption revisions are deferred.

### Ordered evaluation and percentage bases

Components have stable IDs and one complete manual order within the definition.

A percentage or minimum component references only explicitly selected earlier components in the same definition. Each monetary base link declares whether the referenced rounded magnitude is added to or subtracted from the base. Forward references, self-reference, cross-definition references, and cycles are invalid.

Percentage treatment is:

- `additive`: calculate `base × rate`, then apply the component economic role; or
- `included`: calculate `base × rate ÷ (1 + rate)` as an informational allocation already contained in the base.

An included percentage cannot increase or decrease Supplier cost again.

A `minimum_amount_shortfall` component calculates:

```text
max(0, threshold - explicit rounded monetary base)
```

and exposes only the shortfall as a Supplier charge.

A `minimum_quantity_shortfall` component calculates:

```text
max(0, minimum_quantity - evaluated_quantity) × linked unit_rate amount
```

and explains planned quantity, minimum billed quantity, missing billed quantity, unit rate, and rounded monetary shortfall.

### Rounding

M3C calculations use `BigDecimal` and one definition-level rounding mode. The initial supported mode is `half_up`. Every component is rounded to the definition currency's minor unit immediately after evaluation. Later components consume the rounded result. The source total is the sum of rounded component effects.

The forecast explanation returns:

- unrounded calculation input where useful;
- rate and explicit base links;
- quantity and selector result;
- rounding mode and boundary;
- rounded component minor units; and
- source totals by economic role.

M3C does not persist calculated forecast results. Later posted financial source lines must snapshot their final rounded minor-unit results under ADR 0001 and the commercial register.

### Derived forecast and completeness

Definitions, components, base links, usage assumptions, categories, and occupancy profiles are authoritative. Forecast output is a deterministic read model and is not stored financial truth.

For each source, evaluation explains:

- selected stage and readiness evidence;
- exact Arrangement version, context tuple, and charging Supplier;
- definition currency equal to the Departure operating currency;
- usage assumptions and derived occupancy quantities;
- ordered component formulas, bases, rounding, and results;
- Supplier charges and credits;
- forecast Supplier cost;
- expected commission;
- expected net cost after commission; and
- every warning or missing input.

At Arrangement and Departure level, values aggregate in the one operating currency. Incomplete planning returns a clearly labeled **known forecast subtotal** and an explicit list of uncovered Items, incomplete sources, invalid readiness fingerprints, or missing inputs. Missing facts are never treated as zero.

Supplier charges minus Supplier credits produce forecast Supplier cost. Expected commission remains separate and never reduces Supplier cost. Expected net cost after commission subtracts all expected commission. Informational allocations affect none of those measures. A complete source evaluation may not produce a negative Supplier cost or expected net cost after commission.

A draft Arrangement version is cost-complete for later activation only when every retained Item has at least one Item-scoped source, every declared source—Arrangement-wide and Item-scoped—selects a valid forecast-ready stage, every selected stage evaluates with current inputs, every charging Supplier remains eligible and active, and no structural or readiness mismatch remains. Completeness proves Item-level coverage and declared-source completeness; it cannot infer omitted Occurrence, Resource, or Arrangement-wide sources. M3D activation must present the complete source list for Staff coverage attestation. M3C computes this result but exposes no activation action.

Forecast evaluation must observe a consistent Arrangement cost-graph snapshot. Prefer one read-only `REPEATABLE READ` transaction for preload and calculation.

### Lifecycle and mutation boundary

M3C configures only editable draft Arrangement versions. Activated definitions become immutable under ADR 0008 and M3D.

Cost source context and charging Supplier are semantic identity. Correcting either requires removing and recreating an eligible draft-only source. Label, notes, definitions, components, order, assumptions, profiles, and participant-category labels remain editable while the governing version is an eligible draft.

Draft removal is allowed only when no retained version or downstream record depends on the source. M3D successor copying creates independent definition rows; there is no live inheritance.

Supplier inactivation preserves every cost fact. An inactive charging Supplier remains visible with a warning. Recovery allows dependency-reducing removal or Arrangement abandonment, never a new source, forecast-ready transition, or expanded dependency on the inactive Supplier.

## Consequences

### Positive

- Estimate and contracted terms remain alternatives for one source rather than duplicate costs.
- The model supports both accepted scenarios without service-specific pricing subclasses.
- Explicit roles prevent commission, credits, and informational allocations from being silently netted.
- Explicit bases, order, and component rounding make forecasts reproducible.
- Anonymous planning assumptions support occupancy forecasts without inventing Travelers.
- Missing and zero cost remain distinguishable.
- One Departure currency keeps the first monetary slice aligned with ADR 0001 and the commercial contract.
- Draft forecasts remain provisional and do not become a shadow ledger.

### Costs

- Persistence requires source, definition, component, base-link, assumption, category, and occupancy-profile records.
- Readiness fingerprints and fail-closed evaluation must detect stale or bypassed term mutations.
- Foreign-currency Supplier terms, if ever needed, require a later amendment with FX and Obligation authority.
- M3D must copy sources and definitions deliberately when creating a successor version.
- Later Reservation and Traveler work must add actual-demand precedence without rewriting M3C assumptions.
- Commission settlement method and expected remittance remain later work.

## Alternatives rejected

### One amount or formula on each Item

Rejected. It cannot preserve taxes, fees, discounts, commission, minimums, or occupancy-position explanations.

### Separate economic source for every stage

Rejected. Estimate and contracted stages could be added together or lose continuity.

### Component-by-component stage merging

Rejected. It creates unexplained hybrids of stale estimates and contracted terms.

### Generic expression language

Rejected. It expands validation, security, migration, and explainability risk without demonstrated MVP need.

### Service-specific pricing subclasses

Rejected. Cruise, hotel, motorcoach, dining, excursion, and insurance costs compose from the same primitives.

### M3B capacity as forecast demand

Rejected. Supplier supply is not expected usage.

### Empty definition means zero

Rejected. It would make missing terms appear favorable.

### Persist every draft forecast result

Rejected. Editable planning would become a redundant mutable projection or false financial ledger.

### Foreign-currency Supplier cost definitions in M3C

Rejected for M3C. One Departure operating currency remains the MVP contract. A later focused amendment may authorize foreign-currency Supplier terms together with FX and Obligation consequences.

### Implicit or live FX conversion

Rejected. No durable rate, conversion, posting, or gain/loss authority exists in M3.

### Commission settlement method and expected remittance in M3C

Rejected for M3C. Expected commission is reported separately; settlement and remittance belong to later commission/payment work.

### Structured age rules in M3C

Rejected. Actual age-on-service-date classification belongs with later Traveler and Reservation facts.

### Named forecast scenarios

Rejected for M3C. One current assumption set per exact context is sufficient for Supplier planning MVP.

## Implementation boundary

This ADR is Accepted together with [M3C](../planning/m3c-cost-terms-and-forecasts.md). M3C is the implementation authority for draft cost sources, definitions, components, usage assumptions, deterministic forecast evaluation, and draft UI.

M3A and M3B are shipped. Arrangement activation, successor copying, effective contracted terms, Reservations, commitments, Supplier Obligations, FX, posting, settlement, and remittance remain later slices.
