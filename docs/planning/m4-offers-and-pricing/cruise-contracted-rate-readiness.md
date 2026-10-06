# Cruise contracted-rate readiness

**Status:** Shipped 2026-10-05. Authority for Cruise activation on a reviewed contracted rate while the forecast stays incomplete. Not authority for Hotel, Transportation, Activity, inventory-mode changes, unpriced on-request categories, evidence reuse, traveler-rate shapes, name suggestions, or opening-evidence navigation.

**Amends:** the activation row in [Cruise rework](m4d1-cruise-rework.md). The omission sentences in [Slice 2A.2](m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md) and [Slice 2A.2R](m4d1-slice2a2r-cruise-supplier-rate-matrix.md) no longer govern a new Cruise review.

**Retained:** Every cabin Resource still needs an eligible contracted rate. Numeric inventory still needs opening authority. The exact version still needs Supplier confirmation. Recorded deposits, deadlines, and commitment triggers keep their own rules. `forecast_ready` remains the forecast gate for Hotel, Transportation, and Activity, and for Cruise forecasts. Definition status stays `working` or `forecast_ready`.

## 1. Outcome

Staff can activate a Cruise when every cabin has a contracted rate reviewed for activation, even though expected cabin counts and the occupancy mix are absent. Unknown commission stays unknown.

## 2. Usable contracted rate

A contracted Cruise rate is usable when its components, applicability, currency, calculation bases, and charging Supplier are valid.

Applicability belongs to the terms. It is the component selector, such as first/second passenger (`occupancy_position_from` / `occupancy_position_to`). Forecast occupancy is a planning assumption, such as six double cabins. It is not part of contractual usability.

## 3. Commission

Three recorded meanings:

| Meaning | Record |
| --- | --- |
| Unknown | Commission method `not_provided`. No commission component. Gross illustrations can show. Net stays unresolved. |
| Explicitly no commission | Commission method `none`. Stored as `commission_treatment = noncommissionable` with no commission component and no zero amount. |
| Known terms | Commission method `dollar` or `percentage`, stored as expected-commission components. |

Omission does not mean zero. A new review does not treat a blank commission as none.

A contracted Cruise definition that is already `forecast_ready`, has no expected-commission component, and was saved before this amendment keeps the old attestation: that absence meant none. The compatibility backfill records `omitted_commission_means_none` and a contract review taken from that existing forecast readiness. Working definitions are not reviewed by the backfill.

## 4. Consumers

| Caller | Needs | Cruise rule after this amendment |
| --- | --- | --- |
| `SupplierArrangementActivationReadiness#cruise_agreement_readiness` | Contractual usability | A current contract review on a contracted definition for the cabin. Forecast readiness is not required. The cabin blocker remains only when no matching source is reviewed. |
| `SupplierArrangementActivationReadiness#cost_readiness` for a Cruise cabin source | Contractual usability | Select that contract-reviewed contracted definition. A cabin source without one blocks activation. Other sources still need a forecast-ready stage. |
| Commitment triggers, deadline commitments, and commitment opening | A completed forecast when they use a contracted amount as monetary authority | Unchanged. They still require `forecast_ready`. |
| `EvaluateSupplierCostForecast` | A completed forecast | Gross stays available. Unknown commission and net stay unresolved. Explicit none and a historical omission stay zero commission with net equal to gross. A reviewed rate with no occupancy mix is still not a selected forecast stage. |
| Indicative scenario economics | A commission-dependent margin | Unknown commission leaves the scenario unknown. Margin is not calculated from zero. |
| Supplier exposure projection | A known exposure amount | Unknown commission is an incomplete component. It is not stored as known commission of zero. |
| `SupplierDepositAmountEvaluator` forecast-ready lookup | A completed forecast when a deposit calculates from a cost definition | Unchanged. |
| Cruise rate preview commission display | Commission meaning | `none` or the historical omission flag shows no commission. `not_provided` stays pending, including after forecast readiness. |
| Successor copy | The same fingerprint refresh already used for forecast readiness | A current contract review is copied and its fingerprint is refreshed on the copy. |

## 5. Attestation

Contract review is stored on `supplier_cost_definitions` beside forecast readiness, not as a third status:

- `contract_reviewed_by_id`
- `contract_reviewed_at`
- `contract_review_fingerprint`
- `contract_review_provenance`

The review is current only when those fields are present, the definition is contracted, and the fingerprint matches the current term facts. `validate_required_usage!` still applies when marking `forecast_ready`. It does not apply to contract review.

## 6. Invalidation

- Saving forecast occupancy clears forecast readiness and leaves a current contract review in place.
- Saving rates, applicability, commission method, or contractual support clears the contract review and forecast readiness.
- Activated definitions and historical attestations stay immutable.
- A successor copies a current contract review and refreshes its fingerprint the way forecast readiness is refreshed.

## 7. Staff action

The Cruise rate screen offers a review of the contracted terms for activation. That action records the attestation and a provenance note. It does not ask Staff to treat omitted commission as none. Forecast incompleteness is shown separately. Marking the forecast ready remains available when a forecast is requested, and it no longer rewrites unknown commission as none.
