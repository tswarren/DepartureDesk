Below is how I would explain the concern to the developers. The key is to make clear that Slice 3 did not merely miss some buttons: it chose the wrong implementation boundary.

## Slice 3 review: why this implementation misses the intended outcome

I do not think PR \#156 is ready to approve in its current form.

There is useful work here, particularly around compiling existing M3/M4 facts into family-specific workspaces. However, the implementation has optimized for sharing commands and producing valid durable graphs before proving that any one of the Hotel, Transportation, or Activity workflows works coherently for Staff.

The result is a set of partially connected graph editors rather than complete supplier-planning adapters.

This is not primarily a visual-polish problem. Adding the missing buttons to the current pages would make more commands reachable, but it would not resolve the underlying workflow, semantic, and ownership problems.

### What Slice 3 should accomplish

A typed adapter should let Staff complete a recognizable business task using the vocabulary of that Supplier family.

For example, a Hotel adapter should let Staff understand and manage:

1. Which Hotel stay is being contracted.  
2. Which room categories are included.  
3. How many rooms are blocked or guaranteed by category and night.  
4. Which Supplier costs apply to those rooms.  
5. Which deposit, option, rooming-list, and final-payment commitments apply.  
6. Which Client Service Offer represents the stay.  
7. Which room categories become Client-facing choices.  
8. Whether the Hotel setup is complete, blocked, or requires Advanced planning.

The durable implementation may use generic Arrangement Items, Resources, Pools, Supplier cost definitions, deadlines, deposit definitions, and Service Offers. Staff should not have to mentally assemble those generic records into a Hotel contract.

The same principle applies to Transportation and Activities:

* Transportation should be organized around services, segments, vehicles or modes, controlled capacity, Supplier costs, operational deadlines, and Client selections.  
* Activities should be organized around the offering, date and time, participation limits, minimums, cancellation commitments, Supplier cost, and Client connection.  
* A DMC workspace should coordinate multiple independently identifiable Items rather than redirecting Staff into whichever Item happens to be selected first.

### What the PR currently does

The PR introduces generic shared services such as:

* `TypedItemWrite`  
* `ConnectTypedItemService`  
* `RecordTypedSupplierComponent`  
* `RecordTypedMilestone`  
* `TypedItemClaim`

The family-specific controllers then expose selected pieces of those services.

That reverses the delivery sequence described by the Slice 3 contract. We intended to prove Hotel and Transportation first and extract shared behavior only after comparing their real workflows. Instead, the PR assumes their common abstraction before either family has a complete workflow.

This matters because the missing behavior is not identical between families:

| Concern | Hotel | Transportation | Activity |
| :---- | :---- | :---- | :---- |
| Primary structure | Stay and room categories | Service and segments | Offering or excursion |
| Capacity | Rooms by category/night | Vehicle occupancy or controlled seats | Participants or external availability |
| Common cost basis | Room/night, occupancy, guaranteed rooms | Segment, vehicle, seat, person | Fixed, person, minimum |
| Commitments | Deposit, option, rooming list, final payment | Option, final count, cancellation | Option/cancellation and minimum |
| Client choices | Room categories and stay variants | Routes or transfer selections | Participate or decline; possible variants |

A generic “create Item, add component, connect offer” service does not by itself resolve those distinctions.

## Blocking product gaps

### 1. Hotel does not provide a complete Hotel workflow

The implementation contains an `AddHotelRoomCategory` command and route, but the Hotel workspace does not expose room-category management or render the room collection as a meaningful part of the stay.

That means Staff can create a Hotel shell and add some commercial facts, but cannot manage the central subject of a Hotel block: the rooms.

The Client connection is similarly incomplete. The form supports creating a new Service Offer from a title, but does not visibly support:

* deciding later;  
* connecting an eligible existing outline;  
* choosing which room categories become Client choices;  
* reviewing the resulting choice graph.

The page therefore does not yet satisfy the Hotel scenario even if its underlying commands create valid records.

### 2. Transportation exposes only one part of its implemented workflow

The Transportation page exposes segment creation, but the controller also contains Supplier-cost and Client-service connection actions that Staff cannot reach from the page.

More importantly, the current segment form does not clearly distinguish:

* the vehicle’s physical maximum occupancy;  
* the number of seats controlled or available to the Departure;  
* an externally managed transportation service with no numeric inventory.

Those are different facts and produce different M3 graphs.

For the Smith transfer example, “15 seats” might mean:

* the motorcoach physically carries no more than 15 passengers;  
* the Supplier has committed 15 seats to the group;  
* the Agency is merely planning for 15 travelers, without controlling Supplier inventory.

The adapter must ask the correct question and model the answer accordingly. It should not store a value as `SupplierResource.maximum_occupancy` and then display it as if that establishes available capacity.

### 3. Activity exposes costs but not the complete operational setup

The Activity page exposes Supplier cost entry, but not the implemented milestone/deadline or Client-service connection flows.

For the Port Promotions excursion, Staff need to see a coherent setup:

* Island Sightseeing;  
* October 8, 2027;  
* Supplier cost of $50 per participant;  
* minimum of five participants;  
* option/cancellation date of September 24, 2027;  
* non-cancellable status on or after that date;  
* the connected optional Client Service.

Entering only the cost component does not constitute an Activity adapter.

The Activity/Excursion template also needs either reconstructable semantics or deliberate display behavior. If “Excursion” is only a creation-time selection and the saved workspace later identifies it merely as “Activity,” the interface loses meaningful Staff vocabulary.

### 4. DMC routing does not preserve Item identity

The DMC page presents multiple Items, but family links do not consistently carry the selected Item identity into the destination workspace. Several family workspaces then select the first matching Item.

This creates a serious correctness problem when one Supplier Arrangement contains multiple Hotel stays, transfers, or activities. Staff may select one row and be shown or edit another.

Every typed workspace must identify its exact stable Arrangement Item. It cannot infer the target using `first`, `last`, or creation order.

## Blocking domain problems

### 5. Transportation capacity is modeled ambiguously

The transportation command currently maps `seat_count` to Resource maximum occupancy while leaving the Item unmanaged and creating no Capacity Pool.

Resource occupancy and Supplier-controlled capacity are not synonymous:

* `maximum_occupancy` describes what one Resource unit can physically contain.  
* A Capacity Pool describes inventory controlled or allocated by the Supplier.  
* Planning assumptions describe expected usage without asserting control.

The contract needs an explicit decision before implementation continues:

* If Staff are entering physical vehicle capacity, call the field “Maximum passengers per vehicle” and do not present it as available seats.  
* If Staff are entering committed seats, create a controlled capacity Pool.  
* If Staff are only entering expected passengers, store a planning assumption rather than Supplier inventory.

### 6. Hotel percentage deposits use an overly broad base

The Hotel deposit command appears to use all Supplier cost sources attached to the Hotel Item as the percentage base.

That is not sufficient for a contract such as “15% of guaranteed room costs upon signing.” The Hotel Item may also include:

* taxes;  
* additional-adult fees;  
* meals;  
* porterage;  
* resort fees;  
* optional nights;  
* other charges that are not part of the guaranteed-room deposit base.

The adapter must either:

1. allow Staff to select the exact contributing Supplier cost components, or  
2. use a narrowly defined typed source set whose inclusion rules are visible and locked.

It should then display the derivation:

> 15% × guaranteed room charges from Standard Room and Double Room components

It must not silently interpret “Hotel costs” as every cost source covered by the Item.

### 7. Supplier cost components lack stable edit identity

The generic Supplier-component command finds existing components by their display label.

A label is editable business text, not durable identity. This produces two undesirable cases:

* Reusing an existing label can overwrite an unrelated component.  
* Renaming a component can create a new component and leave the former one behind.

The editor should submit the stable Supplier cost component ID when editing an existing component. The command should then verify that the component belongs to the detected editable graph.

Minimum-quantity handling has a related lifecycle problem. The initial save may create a minimum-shortfall component, but later saves do not appear to provide a reliable way to change or remove that minimum. A field presented as editable must have defined create, update, clear, and reopen behavior.

### 8. Idempotent setup can resolve the wrong Item

`TypedItemWrite#create_typed_shell!` appears to record the Arrangement as its idempotent result and reconstruct the created setup by selecting the most recently created Item and related records.

That is unsafe.

Suppose the first request creates Hotel Stay A. Another action later creates Hotel Stay B in the same Arrangement. If the original request is replayed using the same idempotency key, selecting the last-created Item can return Stay B rather than Stay A.

Idempotent replay must return the exact object graph created by the original command. The stored result therefore needs the stable Item identity, or another durable identifier that resolves precisely to the original setup.

### 9. Definitions must be scoped to their actual coverage

The Hotel compiler appears to collect deadline and deposit definitions at the Arrangement-version level without consistently proving that their coverage belongs to the selected Hotel Item.

If an Arrangement contains multiple stays or other Items, the workspace may display unrelated commitments.

Each row in a typed workspace must be included because its durable coverage resolves to the selected Item, Resource, or Pool—not simply because it belongs to the same Arrangement version.

## Service-connection architecture concerns

### 10. `ConnectTypedItemService` is a second Service Offer engine

The generic connection service directly creates or changes:

* the Service Offer;  
* its version;  
* price definitions;  
* source bindings;  
* choice groups;  
* choice options;  
* activations;  
* the Item claim.

This duplicates consequential behavior already governed by the M4 command surface and the invariants established by Slice 2C.

The concern is not merely code duplication. The new path does not visibly carry all of the rules that the Cruise connection had to lock, including:

* the exact eligible shape for connect-existing;  
* refusing an outline that already has a choice graph;  
* stable category identity;  
* exact occurrence selection;  
* claim ownership;  
* successor behavior;  
* protection against reinterpreting an existing supported graph.

If the generic path is intended to replace or generalize Cruise connection behavior, that needs to be designed explicitly as a shared M4 amendment. It should not emerge indirectly inside Slice 3.

If it is only an adapter, it should compose a locked public command surface rather than becoming another graph-construction authority.

### 11. Client-category identity has not been resolved

Hotel room categories and similar typed options will eventually need Client prices. Slice 2C established a stable `client_rate_category_key` for Cruise options specifically so successor copies and later pricing do not depend on regenerated option IDs.

The Slice 3 connection creates choice options without defining the equivalent stable category identity or deliberately deferring it with a locked handoff.

Before these graphs ship, the contract should decide:

* whether Hotel room categories require stored Client rate-category keys now;  
* how those keys survive successor versions;  
* whether Transportation and Activity choices use category pricing, simple option effects, or another supported price shape.

Otherwise Slice 3 may create choice graphs that Slice 4 cannot safely price without remediation.

## Detector concerns

The typed detectors currently prove too little before declaring a graph compatible.

A detector should protect the generic graph from destructive typed editing. It therefore needs to establish, as appropriate:

* the selected stable Item;  
* the exact Item family;  
* the expected number and kind of Occurrences;  
* occurrence ownership and time-zone shape;  
* Resource and Pool topology;  
* coverage of every displayed cost or commitment;  
* supported calculation kinds and quantity bases;  
* percentage bases;  
* supported connection topology;  
* absence of incompatible package ownership;  
* draft/governing/successor state;  
* which facts can be edited and which require Advanced planning.

A detector that only confirms category and a few recognizable definitions may allow the typed editor to reopen a graph whose important semantics it cannot preserve.

The correct behavior is to fail closed at the definition or section level, give Staff a specific reason, and link to the relevant Advanced record without rewriting it.

## Why adding more shared code now would make this worse

The shared services encode assumptions that have not yet been validated:

* one target Item can be inferred from ordering;  
* cost components can be identified by labels;  
* a single connection procedure fits Hotel, Transportation, and Activity;  
* milestones can be recorded without family-specific operational meaning;  
* a generic setup shell is a sufficient family adapter.

Continuing to add conditions to those shared services will likely produce a large branching engine:

> if Hotel, create these records; if Transportation, interpret capacity differently; if Activity, create this minimum; if DMC, choose another Item.

That is not useful reuse. It hides unresolved family decisions inside generic infrastructure.

The safer sequence is to implement two complete family workflows independently enough to reveal their actual common behavior. Shared support can then be extracted around proven invariants.

## Recommended restructuring

I recommend treating PR \#156 as a discovery/prototype branch rather than a merge candidate.

Useful compiler, copy, or presentation work can be retained where it has clear ownership, but the implementation should be reorganized into the following deliveries.

### Slice 3R — Resolve the family contracts

Lock:

* the exact Hotel workspace workflow;  
* the meaning and source of Hotel room inventory;  
* the Hotel deposit percentage base;  
* transportation Resource versus Pool versus planning-assumption semantics;  
* Activity versus Excursion vocabulary;  
* stable Client-category identity;  
* multi-Item routing and selection;  
* the permissible public commands for Service Offer connection.

Include text wireframes and full Smith scenario walkthroughs before more shared commands are added.

### Slice 3A — Complete Hotel vertical

A Staff member should be able to:

1. create or open the Hilton stay;  
2. enter the stay dates and Hotel identity;  
3. manage room categories;  
4. enter controlled or guaranteed room quantities using the locked capacity semantics;  
5. enter room/night and additional-adult Supplier costs;  
6. define the 15% deposit using an explicit guaranteed-room base;  
7. enter the option date, rooming-list deadline, and final-payment commitment;  
8. create, connect, or defer the Client Service Offer;  
9. select the room categories exposed as choices;  
10. reopen the saved workspace without losing identity or semantics;  
11. route only unsupported definitions to Advanced planning.

The UI, commands, detector, and browser proof should all support that entire journey.

### Slice 3B — Complete Transportation vertical

Before implementation, resolve what “15 seats” means.

Then prove the three Smith transfer segments independently:

* Hotel to Port — 15 seats — $200 Supplier cost;  
* Airport to Port — 15 seats — $175 Supplier cost;  
* Port to Airport — 15 seats — $175 Supplier cost;  
* final passenger counts due three days before service.

The workspace must preserve exact segment identity and should not conflate physical vehicle occupancy with controlled inventory.

### Slice 3C — Extract shared adapter support

After Hotel and Transportation ship, compare their implementations and extract only demonstrated common behavior, such as:

* exact Item loading and authorization;  
* summary/editor navigation;  
* definition-scoped Advanced fallback;  
* draft/governing/successor presentation;  
* shared command result conventions;  
* stable focus and error recovery;  
* common occurrence fields where their semantics genuinely match.

Do not extract a universal business command merely because both workflows eventually create some of the same tables.

### Slice 3D — Complete Activity/Excursion vertical

Prove the Port Promotions scenario, including:

* Activity/Excursion identity;  
* service date;  
* per-participant cost;  
* minimum five;  
* option/cancellation date;  
* non-cancellable operational effect;  
* Client connection;  
* saved summary and Advanced fallback.

### Slice 3E — DMC orchestration

The DMC page should coordinate its component Items without owning or flattening them.

Every row should carry the stable Item identity into the correct family workspace. Returning from that workspace should return to the same DMC context. One unsupported Item should not prevent Staff from managing compatible sibling Items.

## Revised exit standard

Slice 3 should not be considered delivered merely because the commands can create valid M3/M4 records.

For each family, the blocking proof should begin from the normal Departure or Arrangement UI and demonstrate that Staff can:

1. create or select the intended Item;  
2. enter all facts required by the canonical scenario;  
3. save each independent definition;  
4. recover from validation failure without losing sibling work;  
5. reopen the exact saved Item;  
6. understand the saved facts from the summary;  
7. edit supported facts without replacing their durable identity;  
8. reach Advanced planning for unsupported facts;  
9. connect the correct Client Service where in scope;  
10. distinguish draft, governing, and successor state.

At least one proof must use multiple same-family Items so that no implementation can pass by selecting `.first`, `.last`, or the most recently created record.

## Bottom line

The current PR contains useful exploration, but it does not yet deliver the Slice 3 product outcome.

The main issue is that we generalized the persistence mechanics before defining and proving the Staff workflows. That led to incomplete pages, ambiguous domain mappings, and a generic connection engine with weaker safeguards than the previously shipped Cruise workflow.

I recommend that we do not merge PR \#156 as the accepted Slice 3 implementation. We should use what we learned from it to revise the contract, complete Hotel as the first vertical, complete Transportation second, and extract shared infrastructure only from behavior those two adapters have actually proven.  