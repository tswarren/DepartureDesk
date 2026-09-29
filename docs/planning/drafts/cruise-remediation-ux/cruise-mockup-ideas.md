I would implement this as a **UX layer over the domain work in PR 166**, not another domain redesign. The current Cruise-specific commands are already the right seam: the new pages should orchestrate those commands while hiding generic M3 concepts.

I would do it as a separate, accepted **Cruise Composition UX remediation** after the three technical PR 166 findings are fixed. I would not mix this redesign into PR 166\.

## Target architecture

The key change is from:

> **one large Cruise setup page containing forms for domain objects**

to:

> **one read-oriented Cruise overview \+ several focused task pages**

The resulting route shape could be approximately:

```
/departures/:departure_id/composition/suppliers/:arrangement_id/cruise
    Cruise overview

.../cruise/sailing/edit
    Sailing & itinerary

.../cruise/agreement
    Supplier agreement

.../cruise/cabins
    Cabin categories

.../cruise/cabins/:resource_id/edit
    One cabin category

.../cruise/rates
    Supplier rate summary

.../cruise/rates/:resource_id
    One cabin category's rates

.../cruise/requirements
    Deposits & deadlines summary

.../cruise/requirements/initial-deposit
.../cruise/requirements/hard-stop
.../cruise/requirements/final-payment

.../cruise/terms
    Supplier terms

.../cruise/activation
    Activation review
```

These aren't new domain resources. They're **task-oriented projections/editors over the existing Arrangement version graph**.

## 1\. Build the overview first

I would start by replacing `app/views/cruise_arrangements/show.html.erb`.

Its controller should assemble a presentation object, something like:

```
CruiseCompositionSummary.call(
  agency: current_agency,
  arrangement: @supplier_arrangement,
  version: @supplier_arrangement_version
)
```

That presenter/compiler returns Staff-oriented concepts:

```
summary.sailing
summary.agreement
summary.cabin_categories
summary.rates
summary.requirements
summary.terms
summary.activation
```

For example:

```
summary.rates
# =>
{
  status: :attention,
  label: "2 contracted · 2 estimated",
  categories: [
    {
      resource_id: "...",
      code: "O1",
      name: "Prime Oceanview",
      stage: :contracted,
      ready: true,
      single: Money.new(...),
      double: Money.new(...),
      triple: Money.new(...)
    }
  ]
}
```

The view shouldn't reconstruct Supplier cost graphs itself.

That presenter becomes important because otherwise we'll simplify the HTML but continue leaking M3 vocabulary from controllers and helpers.

## 2\. Preserve the current commands

This is the most important implementation constraint.

For example, the new O1 rate form should eventually call the same commands PR 166 established:

```
Create/Update Cruise Supplier Rate Schedule
RecordCruiseContractedRates
MarkCruiseSupplierRateScheduleForecastReady
```

We should **not** create something like:

```
SimpleCruiseRate
```

or a parallel Cruise data model just because the form is simpler.

The adapter translates:

```
Staff:
Base fare = $1,739
NCCF = $320
Discount = -$772.50
Taxes = $134.26
```

into the existing Supplier cost graph.

That's precisely what an adapter UI should do.

## 3\. Split the existing Cruise controllers by task

PR 166 currently has controllers such as:

```
CruiseArrangementsController
CruiseSupplierRatesController
CruiseDepositsAndDeadlinesController
CruiseAgreementsController
```

I wouldn't immediately replace all of them.

Instead, make the current controllers progressively more focused.

For example, `CruiseSupplierRatesController#show` can become the **rate-category task surface** rather than a page exposing everything that can be done to the underlying cost definition.

The URL can carry stable Resource identity:

```
/cruise/rates/:supplier_resource_id
```

The controller resolves:

```
Resource
→ exact version ResourceDefinition
→ cost source
→ estimated definition
→ contracted definition
→ occupancy profiles
```

Then hands a purpose-built form model to the view.

### Form model

I'd strongly consider non-persisted form objects here:

```
CruiseSupplierRateForm
CruiseCabinCategoryForm
CruiseAgreementForm
CruiseInitialDepositForm
CruiseHardStopForm
```

Not because the domain commands are inadequate, but because the **user's form does not map 1:1 to a database record**.

For example:

```
CruiseSupplierRateForm.new(
  resource: resource,
  stage: "contracted",
  first_second_base_fare: ...,
  third_base_fare: ...,
  single_base_fare: ...,
  first_second_nccf: ...,
  ...
)
```

On submit it validates Staff-level inputs and translates them into the command input expected by the existing cost model.

This gives us a clean boundary:

**Form object \= what Staff thinks about.**  
**Command/domain graph \= how DepartureDesk represents it.**

## 4\. Make cabin editing a small multipage task

The mockup's sidebar is useful here.

### Category details

```
Supplier category code     O1
Category name              Prime Oceanview
Maximum guests             3
```

### Inventory

```
How does the supplier provide this cabin?

● Fixed block
○ On request
○ Externally managed

Cabins held                8
```

### Advanced

Only unusual controls.

The important part is that Staff shouldn't see Pool terminology.

Submitting **Inventory \= Fixed block / 8 cabins** invokes the existing Resource/Pool setup commands.

This also makes adding a cabin category manageable. The initial screen only asks:

```
Code
Name
Maximum occupancy
Inventory type
Quantity (when applicable)
```

Then:

**Save and add rates**

rather than exposing every downstream concept immediately.

## 5\. Rates should become a spreadsheet-like task

This is probably the highest-value UX remediation.

The normal rate page should show one category and one stage at a time:

```
O1 — Prime Oceanview

                 First/second    Third    Single adjustment
Base fare          $1,739.00     $10.00      $1,739.00
NCCF                 $320.00    $320.00        $320.00
Discount            -$772.50          —       -$772.50
Taxes/fees           $134.26    $134.26              —
```

Below that, derive rather than ask:

```
Single     $2,707.26
Double     $2,841.52
Triple     $3,305.78

Expected commission
15% of commissionable fare
Double: $289.95
```

The user should not enter occupancy profiles if this is a supported Cruise shape. **The Cruise adapter constructs them.**

Then stage actions become contextual:

For an estimate:

```
Save estimate
Record contracted rates
```

After copying:

```
Contracted rates
Copied from estimate

[editable rate table]

Save
Mark contracted rates ready
```

The existing estimate remains accessible as:

**View estimate**

This maps almost exactly to the domain work we just shipped.

## 6\. Separate agreement from sailing

This is one place I'd change from the current page structure.

Sailing answers:

> Where and when is the service?

Agreement answers:

> What has Celebrity actually confirmed?

So I'd have a small agreement screen:

```
Supplier agreement

Group creation date     Sep 13, 2026
Supplier group number   1119999
Contract date           Sep 13, 2026
Note                    [optional]

                         Save provisional
                         Confirm agreement
```

After confirmation:

```
✓ Confirmed
Sep 13, 2026 by Alex Mariner

Group number    1119999
Contract date   Sep 13, 2026

Correct information
View history
```

The **Correct information** flow uses the correction command from PR 166\. We don't expose `corrects_id`, `current`, etc.

## 7\. Replace the generic deposit/deadline editor with presets

This is where I'd be most aggressive.

The normal Cruise requirements page:

```
Deposits and deadlines

✓ Initial group deposit
  $50 × 24 cabins = $1,200
  Due Oct 13, 2026

✓ Hard stop
  Jul 9, 2027
  Name and fully deposit allocated cabins,
  or release remaining inventory

✓ Final payment
  Aug 8, 2027

+ Add another requirement
```

Editing Initial deposit gives exactly the form in the mockup:

```
Amount per cabin       $50.00

Applies to
☑ E3 — 8 cabins
☑ O1 — 8 cabins
☑ DI — 8 cabins
☐ OS — On request

                    24 cabins × $50
                    = $1,200

Due date               Oct 13, 2026
Suggested: 30 days after group creation
```

No rule-shape selector. No contributor selector. No generic coverage terminology.

**Add another requirement** can offer:

```
Hard stop
Final payment
Other
```

Choosing **Other** is the point where we can either show a somewhat more generic form or link to Advanced supplier planning.

## 8\. Terms should use a checklist/detail pattern

Instead of displaying all term forms simultaneously:

```
Supplier terms

✓ Allocated-cabin deposit      $500 per allocated cabin
✓ Payment restrictions         Recorded
✓ Cancellation terms           5 tiers recorded
✓ Tour conductor               1 per 16 qualifying guests
✓ GAP                          4 points
— Marketing fund               Not recorded

                                       Add
```

Click one row to edit just that term.

For cancellation:

```
Cancellation terms

90+ days        Full refund*
89–75           25%
74–61           50%
60–31           75%
30 or fewer     100%

☑ Taxes and fees excluded from percentage base

* Except nonrefundable-deposit offers

Save cancellation terms
```

Still structured. Still versioned. No policy-engine UI.

## 9\. Activation becomes the explanation layer

This should be the only screen that brings all the concepts back together.

Not:

> Validation failed because cost definition X isn't forecast ready.

Instead:

```
Activation review

Supplier agreement
✓ Confirmed Sep 13

Cabin inventory
✓ 24 blocked cabins across 3 categories

Supplier rates
✓ E3 contracted
✓ O1 contracted
! DI estimated

Deposits and deadlines
✓ Initial deposit
✓ Hard stop
✓ Final payment

Supplier terms
✓ Required terms recorded
```

If estimates are permitted only through acknowledgment:

```
DI still uses estimated Supplier rates.

☐ I understand that DI has not been confirmed
   as contracted Supplier pricing.

Activate arrangement
```

If our accepted contract instead requires contracted rates, this is a blocker rather than an acknowledgment. The UI should simply reflect the domain readiness result.

## Delivery plan

I would implement this in **five small slices**, rather than redesigning every screen in one PR:

1. **UX-1 — Cruise overview.** Add the summary compiler/presenter and replace the current show page with the read-oriented dashboard. Existing edit links can temporarily continue going to current forms. This gives immediate value without changing writes.  
     
2. **UX-2 — Sailing, agreement, cabin forms.** Introduce focused form objects/pages for those three tasks. Preserve existing commands and IDs.  
     
3. **UX-3 — Supplier rates.** Build the category/stage rate editor and derived occupancy preview. This is probably the most consequential slice and deserves dedicated browser proof.  
     
4. **UX-4 — Requirements and terms.** Replace generic deposit/deadline presentation with Cruise presets and add focused term editors. Keep Advanced supplier planning as escape hatch.  
     
5. **UX-5 — Activation and cleanup.** Build the human-readable activation review, remove obsolete normal-path forms/routes, update interface contract, accessibility/system coverage, and prove Advanced remains reachable.

### One invariant for the whole UX project

I would put this at the top of the plan:

> **The Cruise UX remediation changes presentation and orchestration, not Supplier-domain authority. Every write continues through the accepted commands and versioning/idempotency/authorization contracts. The simplified UI must not introduce a second representation of Cruise inventory, rates, agreements, deposits, deadlines, or terms.**

That prevents the most dangerous outcome: getting the simpler interface we want by creating a second, simpler domain model beside M3.

I think **UX-1 should be the next planning slice after PR 166 closes**. It lets us establish the information architecture shown in the mockup first. Once that shell is real, we can replace each existing editing experience independently without another big-bang redesign.  
