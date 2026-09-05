# ADR 0001: Money and currency representation

- Status: Accepted
- Date: 2026-09-05
- Decision owners: DepartureDesk maintainers

## Context

DepartureDesk must represent money on both sides of group travel operations:

- client charges, receipts, credits, refunds, and responsibility allocations;
- supplier estimates, commitments, obligations, deposits, and payments;
- fixed package costs and variable per-person or per-unit costs;
- commissions, service fees, margins, guarantees, and unsold exposure;
- air-ticket fares, taxes, fees, refunds, exchanges, and per-ticket ARC/BSP settlement amounts.

These facts may use different currencies. They must support exact arithmetic and remain historically reproducible. Floating-point values are unsuitable because binary rounding errors can make allocations, balances, and reconciliation unreliable.

Rails provides formatting helpers but does not provide a complete currency-aware value type. Building and maintaining our own currency registry, arithmetic rules, parsing, and formatting would add substantial undifferentiated work.

The RubyMoney `money` library represents currency-aware values using integer fractional units. `money-rails` integrates those values with Active Record attributes and Rails helpers. It does not provide a ledger, payment application, settlement, historical exchange-rate, or accounting model.

## Decision

DepartureDesk will adopt `money-rails` as the Rails integration and value-object layer for monetary amounts.

The gem will not define the accounting model and will not be the sole enforcement layer. PostgreSQL columns and constraints remain authoritative; DepartureDesk domain records define the meaning, provenance, state, and relationships of each amount.

This ADR accepts the dependency and persistence convention. Until the gem appears in `Gemfile` and its initializer and tests are committed, installation remains an implementation task rather than shipped functionality.

## Persistence contract

### Amounts

Persist monetary amounts as integer minor units in `bigint` columns:

```ruby
table.bigint :amount_minor_units, null: false
```

Use the suffix `_minor_units`, not `_cents`. Not every currency has a two-decimal cent structure: JPY has no decimal subunit, while other currencies can use different exponents.

Use signed values only when the sign has an explicit, documented domain meaning. Where debit/credit, charge/credit, inflow/outflow, or original/reversal are separate business concepts, store that direction or type explicitly rather than relying on an unexplained sign.

### Currency

Every independently meaningful persisted monetary fact must have an explicit currency unless it belongs to an aggregate whose currency is immutable and unambiguous:

```ruby
table.string :currency, null: false, limit: 3
```

Currency codes use uppercase ISO 4217-style codes and receive a named database constraint:

```ruby
add_check_constraint :client_charges,
  "currency ~ '^[A-Z]{3}$'",
  name: "client_charges_currency_format"
```

An agency default currency is a data-entry default and reporting preference. It must never retroactively determine the currency of an existing financial fact.

### Capacity

Use PostgreSQL `bigint` rather than the `money-rails` migration helper’s default integer amount column. Departure-level totals, cumulative receipts, supplier obligations, and high-value group programs can exceed a four-byte integer’s useful range in minor units.

### Constraints

Use database constraints in addition to `money-rails` and Active Record validations. Depending on the record, these may include:

- non-null amount and currency;
- currency format;
- nonnegative amounts where negative values have no valid meaning;
- balanced allocation totals;
- uniqueness or idempotency keys;
- foreign keys to the relevant agency, departure, reservation, charge, obligation, receipt, or payment;
- reversal relationships and posted-state invariants.

## Active Record contract

Expose a `Money` value with an explicit model currency:

```ruby
class ClientCharge < ApplicationRecord
  monetize :amount_minor_units,
    as: :amount,
    with_model_currency: :currency
end
```

Do not rely on a process-wide default currency for persisted records. A model accessor must resolve its currency from the record or from an immutable owning aggregate.

Do not use the `money-rails` migration helpers without reviewing and overriding their generated amount type, column names, defaults, nullability, and constraints. Explicit Rails migrations are preferred because they make the database contract visible.

## Parsing and presentation

Money input is parsed only at controlled application boundaries. Invalid or ambiguous monetary input must fail rather than silently becoming zero or a different amount.

The initializer should enable strict parsing behavior:

```ruby
MoneyRails.configure do |config|
  config.raise_error_on_money_parsing = true
end
```

Formatting helpers are for presentation only. Formatted strings, currency symbols, locale delimiters, and rendered negative-number styles are never accounting authority and are not persisted as the primary amount.

## Currency conversion

Disable implicit currency conversion:

```ruby
Money.disallow_currency_conversion!
```

Arithmetic between mismatched currencies must fail unless a DepartureDesk workflow performs an explicit conversion using a durable exchange-rate fact.

When foreign-exchange support is introduced, retain at least:

- source amount and currency;
- destination/reporting amount and currency;
- the rate and quote convention used;
- rate source and effective or quoted time;
- rounding rule and rounded result;
- the business event or posting that used the conversion.

RubyMoney’s current exchange-rate bank must not be authoritative for historical accounting. Replaying an old transaction must not silently use today’s rate.

## Rounding

Do not establish one global rounding rule as a substitute for domain policy. Supplier contracts, tax calculations, commissions, allocations, currency conversion, and final settlement may round at different boundaries.

Each workflow that can produce a fractional minor unit must document and test:

- the precision used during calculation;
- the rounding mode;
- when rounding occurs;
- how any allocation remainder is assigned;
- whether the supplier’s or settlement system’s result overrides a projection.

Persist the final posted minor-unit result. Preserve supporting rate or calculation facts where they are needed for audit or reproduction.

## Accounting boundary

`money-rails` is responsible for:

- constructing currency-aware values;
- exact same-currency arithmetic;
- detecting currency mismatches;
- currency metadata and subunit exponents;
- controlled parsing and display formatting;
- convenient Active Record accessors.

DepartureDesk remains responsible for:

- client charges and credits;
- receipts and receipt applications;
- supplier obligations and payments;
- payment applications;
- guarantees and unsold exposure;
- estimates, commitments, actuals, and provenance;
- commissions, service fees, and margin;
- posting, reversal, adjustment, and idempotency;
- historical exchange-rate facts;
- ARC/BSP ticket settlement facts and reconciliation scope.

No model may replace these distinctions with a generic amount plus a `paid` boolean.

## Consequences

### Positive

- Monetary arithmetic uses a mature value object rather than floats or ad hoc helpers.
- Currency mismatch errors become explicit.
- Currency exponent and formatting behavior are centralized.
- Rails models and views gain conventional accessors and helpers.
- The persistence model remains transparent and enforceable in PostgreSQL.

### Costs and risks

- The application gains another dependency whose major-version upgrades require review.
- Developers must understand the difference between database minor units and displayed major units.
- The gem’s convenient defaults can produce incorrect schema choices if used without review.
- Automatic exchange features could undermine historical reproducibility if enabled carelessly.
- Some calculations still require `BigDecimal`, explicit rounding rules, and domain-specific allocation code.

## Alternatives considered

### Plain integer columns plus Rails helpers

Rejected as the sole approach. Integer persistence is correct, but Rails helpers alone do not provide a currency-aware value object, mismatch protection, exponent metadata, or reusable arithmetic semantics.

### Custom `MoneyValue` implementation

Rejected for now. It would duplicate mature currency registry, formatting, parsing, and arithmetic behavior without providing a product-specific advantage.

### Decimal database amounts

Rejected as the default representation. Decimal values avoid binary floating-point errors but do not by themselves define currency exponent, rounding boundaries, or allocation semantics. Integer minor units make posted amounts and balance equality direct.

### Floating-point amounts

Rejected. Floating point is not acceptable for financial persistence or authoritative calculations.

### Automatic live exchange-rate conversion

Rejected for accounting. Current rate services may assist quoting or estimates later, but every authoritative conversion must use a durable, explicit rate fact.

## Implementation checklist

- Add `money-rails` to `Gemfile` and commit the resolved lockfile.
- Add an initializer enabling strict parsing and disabling implicit conversion.
- Add a focused test proving same-currency arithmetic and mismatched-currency rejection.
- Establish a reusable migration/model pattern for `*_minor_units` plus currency.
- Add database constraints with each monetary table.
- Document rounding and currency ownership in each financial aggregate.
- Update this ADR if a later requirement changes the persistence or conversion policy.

