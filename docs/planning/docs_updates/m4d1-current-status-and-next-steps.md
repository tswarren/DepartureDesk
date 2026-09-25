# M4D.1 — Current State and Next Steps

## Where we are

M4D.1 is complete through the Cruise vertical in Slice 2:

- Slice 1 — Departure Composition workspace foundation
- Slice 2A — Cruise sailing, cabin inventory, and Supplier rates
- Slice 2B — Cruise deposits, deadlines, activation, and successor editing
- Slice 2C — Cruise Service Offer connection and cabin choices
- Slice 2D — Cruise Client pricing terms and scenario review

Slice 2D merged through PR #154 at `dc272a3`. PR #155 added the Cruise overview link and related usability work.

The implementation is therefore good through Slice 2. Some documentation still says Slice 2D is “Accepted, not shipped”; that is a documentation-closure issue, not unfinished Slice 2D implementation.

We are not planning to remove the shipped Cruise Service Offer, Client pricing, or Client-term capabilities. They remain valid M4 Offer Design capabilities.

## Why we are regrouping

Our current branch is:

```text
m4d1-slice3-hotel-transport-activity
```

That branch demonstrated that the generic M3/M4 records can represent Hotel, Transportation, Activity, and mixed-DMC data. It also exposed a planning problem.

We planned Slice 3 primarily as a list of records and commands to create:

- create an Item;
- add a Resource;
- add capacity;
- add Supplier costs;
- add deposits and deadlines;
- connect a Service Offer.

That allowed technically valid graphs and green service tests without requiring a complete, understandable Staff workflow for each service family.

The branch consequently generalized shared services such as `TypedItemWrite`, `RecordTypedSupplierComponent`, and `ConnectTypedItemService` before we had proved that Hotel and Transportation actually share the same Staff workflow and domain meanings.

It also carried too much Cruise behavior into every new Supplier adapter. Supplier setup, Service Offer design, Client pricing, Package placement, and eventual Client Trip selection are related, but they are not one workflow.

## What the current branch represents

The current Slice 3 branch should be treated as a prototype and source of evidence.

It helped us identify:

- which shipped M3/M4 records can represent each family;
- which generic commands may be reusable;
- where the current records do not express the Staff meaning clearly;
- where stable IDs are required;
- where label- or ordering-based lookup is unsafe;
- which abstractions were introduced too early;
- which decisions must be settled before implementation resumes.

We should not continue adding functionality to the shared typed services on this branch, and we should not merge the branch as the final Slice 3 architecture.

The branch should be preserved for reference. Individual implementation ideas may later be reused after the relevant vertical contract accepts them, but we should not cherry-pick or merge its shared framework wholesale.

## The corrected product boundary

We will organize the remaining work into three layers.

| Layer | Responsibility |
|---|---|
| Supplier Composition | Supplier Arrangements, Items, occurrences, resources, capacity, Supplier costs, deposits, deadlines, and activation readiness |
| Offer Design | Service Offers, Client choices, Client prices, Client terms, Package placement, and publication |
| Client Trip | The Package and add-ons a particular Client selects, travelers, quantities, Holds, Allocations, and Charges |

The immediate Slice 3 work is primarily Supplier Composition.

A Supplier adapter may provide a narrow handoff to Offer Design, but completing Hotel Supplier setup must not require Client pricing, Package placement, or Client Trip decisions.

In particular:

- “Included” and “optional add-on” are not Supplier Arrangement facts.
- Room categories do not automatically become Client choices merely because they are Supplier Resources.
- Connecting a Service Offer does not decide how it belongs in a Package.
- Client pricing is not derived automatically from Supplier costs.
- Actual Package or add-on selection belongs to the later Client Trip domain.

## Immediate next steps

### 1. Close Slice 2 documentation

Create a small documentation-only change from current `main` that:

- marks Slice 2D Shipped;
- pins PR #154 and merge `dc272a3`;
- updates `AGENTS.md`, the documentation index, roadmap, current-state architecture, terminology, the M4D.1 parent, and the Slice 2D plan;
- continues to show Slice 3 as unaccepted or under reconsideration.

This gives us a truthful stable baseline before reopening Slice 3 planning.

### 2. Stop extending the current Slice 3 implementation

On `m4d1-slice3-hotel-transport-activity`:

- do not add more family branches to `TypedItemWrite`;
- do not add more behavior to `RecordTypedSupplierComponent`;
- do not expand `ConnectTypedItemService`;
- do not promote the branch’s Slice 3 contract as accepted authority;
- preserve the branch and PR as prototype history.

### 3. Write Slice 3R

Slice 3R will be a decision and remediation contract, not an implementation slice.

It will lock:

- the Supplier Composition versus Offer Design boundary;
- the expected Staff journey for each family;
- the meaning and units of each entered value;
- the shipped record and command authority for each answer;
- the saved summary sentence;
- the stable ID used by later edits;
- compatibility and Advanced fallback behavior;
- the delivery sequence;
- the conditions under which shared code may be extracted.

Slice 3R adds no production adapter framework.

### 4. Finish the Hilton walkthrough

Hotel is the first complete vertical.

The Hilton walkthrough must define the entire Staff journey for:

- the Hotel Arrangement;
- multiple Hotel stays;
- dates and time zone;
- Standard and Deluxe room categories;
- maximum occupancy;
- guaranteed room quantities;
- base room rates;
- additional-adult charges and tax;
- the explicit signing-deposit contributor set;
- option/release, rooming-list, and final-payment deadlines;
- Supplier cost and deposit previews;
- draft, governing, and successor behavior;
- exact Item and definition identities;
- Advanced fallback.

The current walkthrough must be revised so that “optional add-on,” Client pricing, Package placement, and Client Trip selection are not Hotel Supplier facts.

If Hotel retains a Service connection handoff, its summary should be limited to something such as:

```text
Pre-cruise hotel
Connected to Client Service

Client pricing not configured
Package placement not configured

[Open in Offer Design]
```

The Hotel workspace must not claim that the stay is an optional add-on.

### 5. Accept and implement Slice 3A

Only after the Hilton walkthrough and exact command surface are accepted will we implement Slice 3A.

Slice 3A is complete only when Staff can perform the full Hilton journey through the browser.

Its blocking proof must include:

- two Hotel stays;
- exact Item-scoped navigation;
- independent saves;
- edits using stable IDs;
- invalid-save recovery;
- no sibling damage;
- readable unsupported definitions;
- Advanced fallback;
- governing and successor presentation;
- appropriate authorization.

Creating a graph directly in a service test is supporting proof, not the Slice 3A exit.

### 6. Repeat the process for Transportation

Slice 3B will define and implement the complete Transportation journey using Transportation vocabulary.

It must explicitly decide what “15” means in the Smith fixture:

- passengers per vehicle;
- controlled seat inventory; or
- a planning assumption.

The stored graph and summary must express the selected meaning without relying on the nearest available column.

### 7. Extract shared support only after Hotel and Transportation work

Slice 3C may extract behavior that exists and behaves identically in both completed adapters.

Likely candidates include:

- exact Item loading;
- summary-first navigation;
- one-editor behavior;
- draft/governing/successor targeting;
- definition-scoped Advanced fallback;
- stable command result identity;
- common authorization and error recovery.

“Both adapters create an Arrangement Item” is not, by itself, sufficient justification for a shared orchestration framework.

### 8. Continue with Activity and mixed DMC

After Hotel, Transportation, and shared-support extraction:

- Slice 3D implements Activity/Meal/Excursion;
- a later delivery handles mixed-DMC routing and integrated proof.

These deliveries must follow the same Staff-question, durable-meaning, saved-summary, stable-ID, and browser-proof discipline.

## What is not changing

This regroup does not reopen or remove:

- the M3 Supplier Arrangement model;
- the M4 Service Offer and Package model;
- Cruise cabin choices;
- Cruise Client pricing;
- Slice 2D scenario review;
- publication behavior;
- existing accepted financial separation between Supplier costs and Client revenue.

The correction is about delivery boundaries and workflow design. We are not performing a destructive rollback.

## Working rule going forward

A Slice 3 step is not ready for implementation until it specifies:

1. the question Staff answers;
2. the durable meaning and units of the answer;
3. the shipped or newly accepted command that writes it;
4. the sentence shown after reopening;
5. the stable identifier submitted by the next edit;
6. lifecycle and dependency behavior;
7. a browser proof that would fail if the wrong Item or definition were used.

That is the standard the current Slice 3 prototype did not consistently enforce, and it is the standard the revised vertical contracts will use.