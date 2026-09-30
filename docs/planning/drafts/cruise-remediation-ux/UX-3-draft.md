Yes. I would replace the current UX-3 section with something substantially more explicit so implementation preserves the existing cost-entry strengths rather than interpreting UX-3 as a new simplified rate editor.

```markdown
### UX-3 — Establish economics

**Authorized after UX-2 acceptance.**

UX-3 adapts the existing Supplier cost-entry interface for Cruise rates. It does not replace that interface with a fixed Cruise-specific rate form.

The existing tabular cost editor is the foundation for this slice. Preserve its flexibility: Staff can add and remove rate components, add supported rate profiles, and work with Estimate and Contracted stages. Cruise changes the initial defaults, Staff-facing terminology where appropriate, commission mechanics, and derived preview.

Every write continues through the existing Supplier cost commands, definitions, version locks, idempotency, and authorization contracts. Do not introduce Cruise-specific rate, commission, or economics records.

#### Staff outcome

Staff can open a cabin category, transcribe the Supplier's rates into a familiar table, record how commission is calculated, verify the resulting occupancy economics, and move from estimated to contracted rates without learning the underlying Supplier-cost graph.

For the canonical Celebrity case, Staff should be able to enter the complete cabin-category economics without opening Advanced Supplier planning.

#### Preserve the existing cost editor

The current tabular Supplier cost interface is intentional and should remain recognizable.

UX-3 must preserve:

- one tabular editor for the rate definition;
- editable rate components as rows;
- rate profiles as columns;
- adding and removing rate components;
- adding additional supported rate profiles;
- the existing Estimate and Contracted distinction;
- the existing Supplier-cost calculation model;
- existing percentage-base semantics where they are required by the underlying definition; and
- Advanced Supplier planning for definitions the Cruise adapter cannot represent losslessly.

Do not replace the table with a collection of fixed Cruise fields or stacked forms.

#### Default Cruise rate profiles

A new Cruise rate definition starts with these rate profiles:

1. **1st/2nd**
2. **Additional**
3. **Single Supplement**

Do not default a new Cruise definition to **Every Traveler** or **Every Cabin**.

These are defaults, not the complete set of rate profiles a Cruise may use. Staff can add another rate profile supported by the existing cost model when the Supplier's terms require one.

The Cruise UI must not create a second definition of occupancy or rate-profile semantics.

#### Default rate components

For the canonical Cruise case, initialize the table with:

- Base fare
- NCCF
- Discount
- Taxes

These are useful defaults, not a fixed Cruise schema.

Staff retains the existing ability to:

- add another rate component;
- remove a rate component when appropriate;
- enter positive or negative values according to the existing cost-component rules; and
- use the existing cost model for a Supplier whose component structure differs from the canonical fixture.

Do not infer calculation behavior solely from a component's display name. For example, a negative Discount is not automatically commissionable merely because it reduces the Client-facing total.

#### Commission method

Place **Commission method** near the top of the rate editor.

Supported normal-path choices are:

- **Not provided yet**
- **No commission**
- **Dollar amount**
- **Percentage**

The selection controls which commission inputs appear in the rate table. It must map to the existing Supplier-cost representation rather than creating a Cruise commission record.

##### Not provided yet

Use when the Supplier's commission terms have not yet been recorded.

No commission amount, percentage, or commissionable-component controls appear.

This state means **unknown or not yet entered**. It does not mean zero commission.

The economics preview should identify expected commission as not yet known rather than silently treating it as $0.

##### No commission

Use when the Supplier explicitly provides no commission.

No commission amount, percentage, or commissionable-component controls appear.

This is an affirmative Supplier term and is distinct from **Not provided yet**.

Derived economics may treat expected commission as $0 because Staff has explicitly recorded that the Supplier pays no commission.

##### Dollar amount

Use when commission is expressed as a fixed monetary amount for a rate profile.

Add a **Commission** amount input to each applicable rate-profile column.

Conceptually:

| Rate component | 1st/2nd | Additional | Single Supplement |
| --- | ---: | ---: | ---: |
| Base fare | $2,533.00 | $10.00 | $2,533.00 |
| NCCF | $320.00 | $320.00 | $320.00 |
| Discount | −$950.00 | — | −$950.00 |
| Taxes | $134.26 | $134.26 | $134.26 |
| **Commission** | **$…** | **$…** | **$…** |

Staff may record a different commission amount for each rate profile.

Do not show Commissionable checkboxes because a fixed commission does not require a percentage basis.

##### Percentage

Use when commission is calculated as a percentage of selected Supplier rate components.

When Percentage is selected:

1. add a **Commissionable** boolean beside each rate-component row; and
2. add a **Commission rate** percentage input to each applicable rate-profile column.

Conceptually:

| Rate component | Commissionable | 1st/2nd | Additional | Single Supplement |
| --- | :---: | ---: | ---: | ---: |
| Base fare | ✓ | $2,533.00 | $10.00 | $2,533.00 |
| NCCF | | $320.00 | $320.00 | $320.00 |
| Discount | ✓ | −$950.00 | — | −$950.00 |
| Taxes | | $134.26 | $134.26 | $134.26 |
| **Commission rate** | | **15%** | **15%** | **15%** |

Use **Commissionable**, not “Affects commission,” as the Staff-facing label.

A checked component participates in the commission basis using its existing signed value. Therefore, if a negative Discount is commissionable, it reduces the commissionable amount. If it is not commissionable, it does not affect the commission basis.

The normal Cruise editor uses one Commissionable selection per component across the displayed rate profiles. The percentage itself may differ by rate profile.

Do not add a component-by-profile commissionability matrix in this slice.

If an existing Supplier-cost definition requires different commissionable components for different profiles, or otherwise cannot be represented losslessly by this interaction, do not flatten it. Show that the commission calculation uses an advanced structure and provide the existing Advanced Supplier planning path.

#### Commission calculation preview

Commission inputs must provide immediate derived feedback from the existing economics/calculation services.

For Percentage commission, show at minimum:

- commissionable amount by displayed rate profile; and
- expected commission by displayed rate profile.

For example:

| | 1st/2nd | Additional | Single Supplement |
| --- | ---: | ---: | ---: |
| Commissionable amount | $1,583.00 | $10.00 | $1,583.00 |
| Expected commission | $237.45 | $1.50 | $237.45 |

These values are derived results, not independently editable fields.

Changing a Commissionable selection, commission percentage, or component value must cause the resulting preview to reflect the same calculation that will be persisted/evaluated by the existing Supplier-cost model. Do not implement a separate Cruise-only commission formula.

For Dollar amount commission, show the entered/derived expected commission in the economics preview without inventing a commissionable basis.

For Not provided yet, display commission as unknown/not recorded rather than $0.

For No commission, display expected commission as $0.

#### Occupancy economics preview

Retain the Cruise occupancy preview for the common scenarios supported by the rate definition.

For the canonical Cruise shape, show:

- Single
- Double
- Triple

For each scenario, derive the applicable Supplier total and expected commission using the existing evaluation services and occupancy profiles.

The preview is a verification surface. It must not contain a second implementation of Supplier-rate or commission calculations.

The preview should make obvious enough for Staff to detect errors such as:

- accidentally making NCCF commissionable;
- failing to include a commissionable Discount;
- entering 1.5% instead of 15%;
- leaving a rate profile without its expected commission terms; or
- materially unexpected Single/Double/Triple totals.

#### Estimate and Contracted rates

Preserve the shipped Estimate/Contracted model.

Staff may enter and work with estimated Supplier rates before contracted terms are known.

**Record contracted rates** copies the current Estimate into a separate Contracted definition through the existing command. It does not:

- convert the Estimate into Contracted;
- delete or modify the Estimate;
- make the Contracted definition automatically ready;
- imply Supplier agreement confirmation; or
- activate the Arrangement.

After copying, Staff reviews and corrects the Contracted definition and explicitly marks it ready through the existing readiness mechanics.

Commission method, basis, percentages, and amounts must follow the same Estimate/Contracted separation as the other Supplier economics. Copying to Contracted must not leave commission dependent on mutable Estimate records.

#### Existing definitions and lossless editing

`DetectCruiseSupplierRateShape` determines whether the Cruise editor can safely edit an existing Supplier-cost definition.

The adapter should recognize the flexible table shape described above. It must not require the definition to contain exactly the default three rate profiles or exactly the four canonical components merely because those are the new-definition defaults.

An existing definition remains editable in the Cruise interface when the adapter can represent and round-trip it losslessly.

If it cannot, show the definition read-only enough for Staff to understand why normal editing is unavailable and provide **Open Advanced Supplier planning**.

Never partially edit an advanced definition while silently preserving hidden calculation behavior.

#### Interaction and responsive behavior

At desktop/tablet widths, preserve the tabular presentation. Rate profiles are columns and rate components are rows.

At narrow widths, the editor may adapt responsively, but it must continue to represent the same underlying definition and inputs. Do not implement independent desktop and mobile rate models.

Adding/removing a rate component or rate profile should update the commission controls consistently:

- a new component receives a Commissionable control when Percentage is selected;
- removing a component also removes it from the commission basis through the same submitted definition;
- a new rate profile receives a Commission amount when Dollar amount is selected;
- a new rate profile receives a Commission rate when Percentage is selected.

Changing Commission method must not silently discard previously persisted commission terms. If changing method would replace existing commission semantics, require the same explicit replacement/correction behavior appropriate to the existing Supplier-cost commands rather than hiding old data in the UI.

#### Canonical proof

Browser/system proof should cover a canonical Celebrity cabin category using the normal Cruise editor.

At minimum prove:

1. A new Cruise rate definition defaults to **1st/2nd**, **Additional**, and **Single Supplement**, and does not default to Every Traveler or Every Cabin.
2. The table starts with Base fare, NCCF, Discount, and Taxes.
3. Staff can add and remove another rate component.
4. Staff can add another supported rate profile.
5. **Not provided yet** exposes no commission-entry fields and does not report commission as $0.
6. **No commission** exposes no commission-entry fields and produces expected commission of $0.
7. **Dollar amount** exposes a Commission amount for each rate profile.
8. **Percentage** exposes one Commissionable control per component and one Commission rate per rate profile.
9. Selecting Base fare as commissionable at 15% produces the expected derived commission.
10. Making a negative Discount commissionable reduces the commissionable basis and expected commission.
11. NCCF and Taxes can remain noncommissionable.
12. Single, Double, and Triple previews are produced by the existing economics evaluation path.
13. Recording Contracted rates preserves the Estimate and creates a distinct Contracted definition containing the copied commission terms.
14. The copied Contracted definition is not automatically ready.
15. An existing supported non-default component/profile round-trips without loss.
16. An existing commission structure the Cruise editor cannot represent losslessly opens through Advanced rather than being flattened or partially edited.
17. The editor remains usable without horizontal/page overflow at the accepted responsive widths.

#### Non-goals

UX-3 does not:

- replace the generic Supplier-cost model;
- introduce Cruise-specific rate or commission records;
- define Base fare, NCCF, Discount, and Taxes as the only valid Cruise components;
- define 1st/2nd, Additional, and Single Supplement as the only valid rate profiles;
- build a general commission formula editor;
- build a component-by-rate-profile commissionability matrix;
- infer commissionability from component names or positive/negative signs;
- calculate tour-conductor or GAP benefits as commission;
- change Supplier agreement confirmation;
- change activation readiness rules;
- implement deposits, deadlines, or other UX-4 requirements;
- implement Client pricing or Offer Design; or
- allow a lossy Cruise edit of an advanced Supplier-cost definition.
```

One point I would explicitly validate against the current implementation before handing this to an agent: **whether “Dollar amount” can be represented cleanly by the existing cost/commission model without adding domain behavior.** Our discussion establishes the desired UX, but the UX-3 invariant says presentation/orchestration only. If the current domain can express percentage commission but not fixed-dollar commission as commission rather than another cost component, that is a domain gap to surface—not something UX-3 should quietly invent.

Otherwise, this captures the main change in direction: **UX-3 preserves and adapts the flexible cost table; commission mechanics are the substantive redesign.**