### UX-4 — Record requirements

**Authorized after UX-3 acceptance.**

UX-4 gives Staff one readable Supplier-agreement experience for recording and reviewing the Supplier requirements needed to operate the Cruise while preserving other agreement terms Staff may need to reference.

UX-4 is a presentation and orchestration slice over the Supplier records and commands that already exist. It does not introduce a second agreement, deposit, deadline, commercial-benefit, cancellation, policy, or requirement model.

The governing principle is:

> **Simplify the interaction, not the authoritative representation or command semantics.**

Structured facts already required by the authoritative domain remain structured. Reference wording remains on the existing records that own it. Markdown is a way of editing and safely rendering existing text attributes, not a new term model.

Every write continues through the existing commands, authorization, versioning, confirmation/correction rules, locking, and idempotency contracts.

---

#### Staff outcome

Staff can open the Cruise Supplier agreement and answer:

1. What agreement is this, and is it Supplier-confirmed?
2. What deposits and deadlines must the Agency plan around?
3. What commercial benefits did the Supplier agreement record?
4. What other Supplier policies or terms should Staff know?
5. Is there anything in the underlying Supplier records that the simplified Cruise page cannot represent losslessly?

The page is organized for review and focused editing. It is not a continuous display of every underlying form field.

---

#### Composition over existing work areas

UX-4 presents Supplier agreement information and Supplier deposits/deadlines together as one Staff-facing review experience, but their existing domain boundaries remain intact.

Agreement confirmation, commercial benefits, and agreement/readable terms continue through their existing agreement commands.

Initial Deposit, Hard Stop, Final Payment, and other Supplier requirements continue through their existing deposit/deadline commands.

Each focused editor saves through the command that already owns that fact.

UX-4 does not introduce:

- a combined agreement-and-requirements command;
- a batch domain command;
- transactional coupling between agreement terms and requirements;
- duplicate deposit/deadline/agreement records.

The existing deposits/deadlines page remains available. Its activation-review responsibilities remain there until UX-5.

---

#### Structured facts and reference wording

UX-4 distinguishes between:

1. **Existing structured facts** — facts already represented structurally because the Supplier domain needs them.
2. **Operational/calculated facts** — structured facts DepartureDesk currently evaluates or otherwise reasons about.
3. **Reference wording** — Supplier agreement language Staff needs to retain, but DepartureDesk does not currently interpret or calculate.

Do not remove existing structure merely because UX-4 does not currently calculate from it.

Do not introduce additional structure merely because reference wording contains a number, date, threshold, or other potentially extractable fact.

UX-4 does not parse reference wording into structured facts.

For MVP:

| Agreement fact | Representation | UX-4 calculation |
| --- | --- | --- |
| Initial deposit due date | Structured | No |
| Initial deposit per-cabin rate | Structured | Yes, through existing evaluator |
| Current opening quantity | Existing Pool quantities | Used by evaluator |
| Initial deposit total | Derived | Yes |
| Hard Stop date | Structured deadline | No |
| Hard Stop action | Deadline description | No |
| Final Payment date | Structured deadline | No |
| Allocated-cabin amount | Structured agreement term | No |
| Attributable credit | Structured agreement term | No |
| Allocated-cabin policy details | Existing text | No |
| Tour-conductor benefit | Existing commercial-benefit record + wording | No entitlement calculation |
| Group Amenity Program | Existing commercial-benefit record + wording | No entitlement calculation |
| Payment/card restrictions | Existing agreement term | No |
| Cancellation threshold | Structured per cancellation step | No |
| Cancellation wording | Existing cancellation-step wording | No |
| Source citation | Existing optional benefit data | No; normally hidden |

---

#### Page organization

The normal Supplier agreement review has four Staff-facing sections, in this order:

1. **Agreement**
2. **Deposits & deadlines**
3. **Commercial benefits**
4. **Other Supplier terms**

Recorded information renders primarily as readable values and formatted reference text.

Add, Edit, or Correct exposes only the focused editor required for that item.

Do not display the normal read presentation and expanded edit form for the same item simultaneously.

Repeated domain explanations belong at the applicable section level rather than beneath every individual record.

At narrow widths the same information hierarchy stacks vertically. Mobile does not introduce a second information architecture.

---

### 1. Agreement

Agreement presents the identity and confirmation state of the Supplier agreement.

For a confirmed agreement, show readable facts such as:

- contracting Supplier;
- Supplier group number;
- group creation date;
- contract date;
- confirmation state;
- agreement notes when recorded;
- supplemental-block deposit treatment when recorded.

A confirmed agreement should primarily look like a confirmed agreement, not like an always-open correction form.

Existing provisional, confirmation, correction, and amendment contracts remain authoritative.

UX-4 must not allow an inline editor to silently mutate confirmed agreement facts.

When a confirmed fact requires correction, use the existing correction command and preserve existing history.

Agreement notes and other agreement-level reference wording use the formatted-reference-text presentation where supported by their existing text attributes.

UX-4 does not introduce Supplier agreement document attachment.

---

### 2. Deposits & deadlines

Deposits & deadlines summarizes the existing Supplier requirement records on the agreement review page.

The normal Cruise presentation recognizes:

1. **Initial Deposit**
2. **Hard Stop**
3. **Final Payment**

These presets do not assert that every Cruise has exactly these three requirements.

Recording a Supplier requirement is distinct from satisfying it.

UX-4 records facts such as:

> $1,200.00 currently evaluated as due October 13, 2026.

It does not record that the Agency:

- paid the Supplier;
- assigned traveler names;
- fully deposited allocated cabins;
- released remaining inventory;
- made Final Payment;
- otherwise satisfied the requirement.

Those operational/payment facts are outside UX-4.

#### Initial Deposit

Initial Deposit uses the existing structural `initial_deposit` requirement and existing Supplier-deposit evaluator.

For a fixed per-opening-cabin requirement, the normal Cruise presentation shows:

- saved due date;
- saved amount per opening cabin;
- current quantity used by the existing evaluator;
- evaluated total.

For the canonical Cruise, the current cabin Pools have 24 proposed opening cabins:

> **$50.00 per opening cabin × 24 cabins = $1,200.00**

The deposit stores the per-cabin rate and due date.

It does **not** snapshot or persist the 24-cabin quantity or the $1,200 evaluated total.

The quantity comes from the cabin Pools' current proposed opening quantities through the existing evaluator.

If those proposed opening quantities subsequently change, the illustrated total changes accordingly. The saved per-cabin rate and saved due date do not.

UX-4 must not copy the evaluated quantity or total into new deposit fields merely to preserve the current illustration.

##### Suggested due date

Group creation date plus 30 days may be shown as a **suggested due date** when applicable.

The suggestion is a Staff aid, not an inferred Supplier fact.

For example:

> Suggested due date: October 13, 2026  
> Based on group creation date + 30 days.

Once Staff saves a due date, recomputing the suggestion must not overwrite the saved date.

#### Hard Stop

Hard Stop remains one structured deadline plus its existing Staff-facing description.

For the canonical agreement:

> **July 9, 2027**  
> Name and fully deposit allocated staterooms, or release remaining inventory.

Do not decompose this into separate:

- name-assignment deadline;
- full-deposit deadline;
- inventory-release deadline.

Saving, displaying, reaching, or completing the Hard Stop does not itself release inventory or perform any action described by the wording.

The wording remains the existing deadline description and is intended to be a concise operational action statement.

It remains subject to the existing 500-character domain limit.

#### Final Payment

Final Payment remains one date-only Supplier deadline.

For the canonical agreement:

> **August 8, 2027**

UX-4 does not record or calculate whether the Supplier has actually been paid.

#### Date semantics

Supplier contractual deadlines remain date-only facts.

UX-4 does not add a time of day or shift them according to browser time zone.

Existing Supplier deadline semantics remain authoritative.

#### Save granularity

Initial Deposit, Hard Stop, and Final Payment visually belong to one section, but UX-4 does not imply transactional behavior the domain does not provide.

Each requirement saves through its existing command.

Do not introduce a combined Save Requirements command or pseudo-transaction solely for this page.

---

#### Additional requirements

Any existing Supplier requirement or deadline that UX-4 cannot recognize losslessly remains visible after the recognized requirements.

Present it with enough existing information for Staff to identify it and an action equivalent to:

> **Additional Supplier requirement — Review in Advanced**

UX-4 must not:

- hide an unrecognized requirement;
- reinterpret it from its label or wording alone;
- rewrite it;
- delete it when a recognized requirement is saved.

Recognition uses authoritative structure rather than display wording alone.

---

### 3. Commercial benefits

Commercial benefits contains Supplier agreement benefits Staff may need to know but that DepartureDesk does not calculate in MVP.

State the rule once at section level:

> **Agreement benefits are recorded for reference. DepartureDesk does not calculate earned entitlements.**

The normal Cruise presentation supports the existing:

- **Tour-conductor credit**
- **Group Amenity Program**

Normal Supplier commission does not belong here. Commission remains part of Supplier rates.

#### Tour-conductor credit

Tour-conductor credit remains the existing commercial-benefit record with its existing wording.

For the canonical agreement, Staff may record wording equivalent to:

> 1 tour-conductor credit per 16 full-tariff cruise-only guests.

UX-4 does not calculate:

- qualifying travelers;
- earned credits;
- entitlement;
- accrual.

Do not introduce new threshold, traveler-count, qualification, or earned-credit fields solely for UX-4.

#### Group Amenity Program

Group Amenity Program remains the existing commercial-benefit record with its existing wording.

The canonical agreement may describe the Deposit Program's four GAP points.

UX-4 does not calculate:

- GAP points earned;
- GAP entitlement;
- GAP accrual.

Do not introduce a separate structured GAP-point balance merely because the wording contains a numeric value.

#### Missing benefits

Missing commercial benefits display neutrally as:

> **Not recorded**

with an Add action when editable.

Their absence is not:

- an error;
- an activation blocker merely because the benefit is absent;
- a UX-4 attention finding;
- a reason to prevent completion of the normal requirements journey.

---

#### Commercial-benefit source citation

Per-term source citation is not requested in the normal Cruise commercial-benefit editor.

Source citation remains existing optional data; UX-4 does not introduce a new provenance model.

When editing an existing commercial benefit that already has a stored source citation, the focused editor must preserve and resubmit the authoritative stored citation through the existing command even though Staff is not asked to edit it.

Because the existing commercial-benefit command treats a blank citation as clearing the citation, omission from the simplified visible form must not become a blank value.

UX-4 must not:

- clear an existing citation merely because the field is hidden;
- invent a citation;
- require Staff to repeatedly identify the same agreement.

This requirement specifies preservation behavior, not a particular HTML implementation. The controller/orchestration layer may preserve the authoritative value without exposing it as a hidden editable input.

Do not introduce a new Arrangement-wide citation field solely for UX-4.

Future Supplier agreement document attachments may provide richer provenance and remain outside this slice.

---

### 4. Other Supplier terms

Other Supplier terms contains agreement facts Staff should be able to reference but that DepartureDesk does not currently calculate operational outcomes from.

State the rule once at section level:

> **Reference terms are recorded for Staff use. DepartureDesk does not currently calculate their effects.**

The normal Cruise presentation includes the existing:

- allocated-cabin deposit policy;
- payment/card restrictions;
- cancellation policy;
- other recognized reference terms supported by the agreement model.

#### Allocated-cabin deposit policy

The existing allocated-cabin deposit remains structured agreement policy.

The focused editor records the fields required by the existing `RecordCruiseAgreementTerms` contract:

- amount per allocated cabin;
- attributable credit;
- currency;
- policy wording.

For the canonical agreement:

- amount per allocated cabin: **$500.00**;
- attributable credit: **$50.00**.

Both monetary values remain structured authoritative facts.

UX-4 must not hide the attributable credit, infer it from the Initial Deposit, or invent a value when Staff saves the policy.

The supporting policy explanation is formatted reference text.

These values describe Supplier agreement policy.

UX-4 does not apply them to current bookings or allocations and does not turn:

> $500.00 per allocated cabin

into:

> $500.00 × 24 opening cabins

of current Supplier exposure.

Likewise, the stored $50 attributable-credit term does not mean UX-4 has determined the credit applicable to a particular future allocation.

Calculation against actual bookings/allocations remains outside this slice.

#### Payment restrictions

The existing payment/card-restriction agreement term remains authoritative.

The Staff-facing section may label this **Payment restrictions** so the presentation does not imply that every restriction must concern cards.

Its wording uses formatted-reference-text presentation.

UX-4 does not validate or reject Supplier payments based on this wording.

#### Cancellation policy

Cancellation preserves the existing ordered cancellation-step representation.

Each cancellation step contains:

- structured `days_before_departure`, which remains a nonnegative integer;
- policy wording.

The normal Cruise presentation renders the complete saved set as a readable cancellation ladder rather than presenting the model as one ambiguous `Cancellation days before departure` field.

For example:

> **120 days before departure**  
> Deposit becomes non-refundable.
>
> **90 days before departure**  
> Additional cancellation penalties apply.
>
> **60 days before departure**  
> Full cancellation penalty applies.

Staff can add or edit an individual step through a focused editor.

The wording portion of each step uses formatted-reference-text presentation.

UX-4 does not:

- replace the structured ladder with one Markdown policy field;
- infer a day threshold from wording;
- calculate cancellation exposure;
- calculate penalties;
- calculate refunds;
- perform Client cancellation behavior.

---

#### Focused cancellation editing

The focused cancellation interaction must preserve the replacement semantics of `RecordCruiseAgreementTerms`.

When cancellation steps are supplied, the existing command replaces the cancellation ladder by deleting the current `cancellation_step` records for that version and recreating the submitted ordered list.

Therefore every focused cancellation save must:

1. load the complete authoritative current cancellation ladder;
2. apply the Staff add or edit to that in-memory ordered list;
3. submit the complete resulting list through `RecordCruiseAgreementTerms`.

A focused save must never submit only the currently open step. Doing so would remove the other saved steps.

The focused UI does not require a new per-step domain command.

Cancellation-step database identity does not survive replacement. The focused editor therefore treats position in the submitted ordered list as the step's editing identity and must not depend on a durable cancellation-step record ID surviving the save.

The submitted ordering remains authoritative for the recreated positions.

Proof must demonstrate that adding or editing one step preserves every other submitted step, including its day count, wording, and relative order.

---

#### Missing Supplier terms

Missing optional terms display:

> **Not recorded**

with an Add action when editable.

Their absence is not itself an error or attention state.

Where the underlying domain requires a group of fields together—for example allocated-cabin amount and attributable credit—the focused editor must collect the complete shape required by the existing command rather than manufacture missing values.

---

### Formatted reference text

Formatted reference text is a presentation convention over existing Supplier agreement text attributes.

UX-4 does not introduce:

- a Markdown-specific record;
- a second stored rendering;
- a Cruise-specific text model;
- duplicate policy records.

The existing text column remains the authored source.

Where reference wording is currently exposed through a single-line control, UX-4 may use a multiline textarea so Staff can preserve meaningful formatting.

The normal read presentation safely renders a Markdown-capable subset supporting at least:

- paragraphs;
- authored line breaks;
- ordered lists;
- unordered lists;
- bold;
- italic;
- links.

Ordinary multiline plain text remains valid input. Staff is not required to know Markdown.

At minimum, meaningful authored line and paragraph separation must remain visible after save and redisplay.

Reopening an editor presents the stored authored source, not a reconstruction generated from rendered HTML.

Rendered output sanitizes unsafe HTML/content.

UX-4 does not require:

- tables;
- images;
- embedded media;
- arbitrary HTML;
- a WYSIWYG editor;
- a generalized rich-text document model.

#### Existing text constraints remain authoritative

Formatted rendering does not change the underlying domain constraints.

Hard Stop wording remains the existing deadline description and retains its existing **500-character** limit.

Longer agreement-term and commercial-benefit bodies retain their existing **4,000-character** limits.

Existing normalization that strips whitespace from the outer edges of those bodies remains in place. Meaningful authored line breaks inside the body remain stored.

UX-4 does not enlarge these columns or move wording to different records merely to support formatted presentation.

---

### Read-first focused editing

The Supplier agreement page is a review page with focused editing, not a permanently expanded collection of forms.

Recorded facts render as readable values or formatted text.

For example:

> **Tour-conductor credit**  
> Recorded
>
> 1 tour-conductor credit per 16 full-tariff cruise-only guests.
>
> Edit

rather than permanently displaying its textarea and Save button.

Selecting Add, Edit, or Correct exposes only the focused editor for that item with appropriate Save and Cancel actions.

After successful save, return to the readable presentation.

Cancel does not persist changes.

A confirmed agreement continues to use existing correction/amendment behavior. An Edit action must not bypass immutable confirmation history.

Focused editing may simplify which controls Staff sees, but it must submit the complete authoritative shape required by the owning command.

This is particularly important for:

- preserving hidden commercial-benefit source citation;
- supplying the complete allocated-cabin policy shape;
- resubmitting the complete cancellation ladder.

---

### Unsupported terms and lossless simplification

Lossless simplification applies to the entire page.

If the underlying agreement contains a requirement, benefit, policy, cancellation shape, or other term that UX-4 cannot classify or edit losslessly, keep it visible with an action equivalent to:

> **Additional Supplier term — Review in Advanced**

and provide the existing Advanced Supplier planning path.

The simplified page must never make the agreement appear simpler or more complete by hiding authoritative records it does not understand.

It must not partially edit an unsupported structure while silently leaving related authoritative behavior behind.

---

### Currency

Do not hard-code USD into UX-4.

Monetary values use the Departure operating currency and the existing authoritative currency contracts.

The allocated-cabin presentation continues to use that currency code.

The canonical Celebrity fixture is USD, so its acceptance proof may assert USD values.

---

### Journey guidance and activation readiness

UX-4 does not create a second activation-readiness contract.

The Cruise overview and Supplier pages continue to derive activation readiness from the existing authoritative records and readiness machinery.

For normal UX-4 journey guidance, the recognized operational requirements are:

- Initial Deposit;
- Hard Stop;
- Final Payment.

Optional commercial benefits and optional reference terms do not become missing-requirement findings merely because they are not recorded.

Where the existing authoritative activation-readiness contract requires another Supplier fact, display that existing blocker rather than creating a competing UX-4 completeness rule.

The existing activation review on the deposits/deadlines page remains there until UX-5.

---

### Transitional UX-6 controls

UX-4 does not redesign later-capacity or agreement-amendment workflows.

Until UX-6 replaces those interactions, the existing controls for:

- same-terms capacity increase;
- supplemental/changed-terms block behavior;

remain reachable on the Supplier agreement page.

The four-section UX-4 redesign must not remove, hide, or alter the behavior of those existing forms.

Prefer presenting them as a clearly separated transitional area outside the four normal agreement-review sections rather than making them appear to be ordinary UX-4 agreement terms.

UX-6 remains responsible for redesigning those workflows.

---

### Accessibility and responsive behavior

At desktop/tablet widths, use clear section headings, concise readable summaries, whitespace, and focused actions rather than a continuous vertical collection of inputs.

At narrow widths, preserve the same four-section hierarchy without horizontal page overflow.

Add, Edit, Correct, Save, and Cancel actions are keyboard accessible.

Focused editors retain:

- associated labels;
- applicable help text;
- validation errors;
- accessible names.

After a successful focused save, focus returns to an appropriate location associated with the updated item.

Cancel returns to read presentation without mutation.

Rendered formatted text must remain understandable without relying on color, borders, or other visual-only distinctions.

System proof covers at least the established 375px and 1280px widths.

---

### Canonical acceptance proof

UX-4 is complete when automated proof demonstrates at least the following.

#### Page and read-first presentation

1. The Supplier agreement review presents **Agreement**, **Deposits & deadlines**, **Commercial benefits**, and **Other Supplier terms** in that order.
2. Recorded agreement facts, benefits, and terms render read-first rather than as permanently expanded forms.
3. Add/Edit/Correct opens only the applicable focused editor.
4. Cancel returns to read presentation without mutation.
5. A successful focused save returns to the updated read presentation.

#### Initial Deposit

6. The canonical E3 8 + O1 8 + DI 8 Pools provide a current proposed opening quantity of 24 cabins.
7. The existing evaluator produces `$50.00 × 24 = $1,200.00`.
8. Group creation +30 days is presented only as a suggested due date.
9. Saving another due date preserves the Staff-entered date when reopened.
10. Changing the authoritative proposed opening quantities changes the evaluated quantity/total without changing the saved $50 per-cabin rate or saved due date.
11. UX-4 does not persist a duplicate quantity snapshot or calculated-total field on the deposit.

#### Deadlines

12. Staff records the July 9, 2027 Hard Stop with the combined action sentence.
13. Saving or displaying that Hard Stop does not release Supplier inventory.
14. UX-4 does not manufacture separate name-assignment, full-deposit, or release deadlines.
15. Staff records the August 8, 2027 Final Payment deadline.
16. Contractual deadline dates remain date-only and are not shifted by browser time zone.
17. An unrecognized existing requirement remains visible and routes to Advanced.

#### Commercial benefits

18. Tour-conductor wording can be recorded and displayed without calculating entitlement.
19. Group Amenity Program wording can be recorded and displayed without calculating entitlement.
20. Missing optional benefits display `Not recorded` without an error or readiness state.
21. Supplier commission remains on Supplier rates rather than Commercial benefits.
22. The normal focused benefit editor does not ask Staff for a per-term source citation.
23. Editing a benefit with an existing stored source citation preserves that citation.
24. UX-4 neither clears nor fabricates a citation.

#### Allocated-cabin policy

25. The canonical agreement records `$500.00` per allocated cabin and `$50.00` attributable credit as separate structured amounts.
26. The focused editor supplies the complete existing command shape, including both amounts and currency.
27. UX-4 does not infer the $50 credit from Initial Deposit.
28. UX-4 does not convert `$500.00 × 24 opening cabins` into current Supplier exposure.

#### Cancellation policy

29. A saved cancellation ladder renders all of its steps with structured day counts and formatted wording.
30. Adding a second cancellation step submits the complete ladder and preserves the first step's day count and wording.
31. Editing one step preserves every other submitted step and their relative order.
32. The focused editor does not depend on cancellation-step database identity surviving replacement.
33. UX-4 does not collapse the structured cancellation ladder into one Markdown policy field.
34. UX-4 does not calculate cancellation exposure, penalties, or refunds.

#### Formatted reference text

35. Ordinary multiline text preserves meaningful internal line/paragraph separation after save and redisplay.
36. Markdown paragraphs, lists, emphasis, and links render safely from the existing text attributes.
37. Reopening an editor presents the stored authored source.
38. Unsafe HTML/content is sanitized.
39. Existing 500-character deadline-description and 4,000-character agreement/benefit-body limits remain enforced.
40. Formatted rendering does not create a second text record or stored rendered representation.

#### Lossless orchestration

41. Saving one focused requirement or agreement term does not modify unrelated Supplier requirements or terms.
42. A focused cancellation save preserves the entire authoritative cancellation ladder.
43. A focused benefit save preserves a hidden existing source citation.
44. Confirmed agreement facts continue through the existing correction/amendment contract rather than being silently mutated.
45. An unsupported existing agreement term remains visible and routes to Advanced.
46. Existing same-terms and supplemental-block controls remain reachable pending UX-6.
47. The existing deposits/deadlines activation review remains available pending UX-5.

#### Responsive and accessible presentation

48. The page has no horizontal overflow at 375px and 1280px.
49. Focused editing remains keyboard accessible.
50. Save/Cancel behavior maintains useful focus placement and accessible labels/errors.

---

### Non-goals

UX-4 does not implement:

- a new Supplier agreement model;
- a new deposit/deadline model;
- a new commercial-benefit model;
- a new cancellation-step model;
- a new Markdown/text record;
- Supplier agreement document upload or attachment;
- a new Arrangement-wide source/citation model;
- required per-term source citations in normal Cruise UX;
- OCR or contract parsing;
- automatic extraction of dates, amounts, thresholds, benefits, or policies from wording;
- a generalized rich-text editor;
- arbitrary HTML authoring;
- Supplier payment recording;
- Client payment recording;
- automatic inventory release;
- automatic Hard Stop actions;
- Tour-conductor entitlement/accrual calculation;
- GAP entitlement/accrual calculation;
- marketing-fund calculation;
- allocated-cabin deposit calculation against actual bookings/allocations;
- calculation of attributable credit for a particular allocation;
- payment/card restriction enforcement;
- cancellation-exposure calculation;
- Supplier cancellation penalty calculation;
- Client cancellation/refund behavior;
- agreement-document provenance design;
- a combined agreement/requirements transaction;
- durable identity for cancellation steps across ladder replacement;
- UX-5 activation-review redesign;
- UX-6 later-capacity/amendment redesign;
- Hotel, Transportation, Activity, or other non-Cruise Composition UX.

The existing Advanced Supplier planning interface remains the authoritative fallback whenever the simplified Cruise presentation cannot represent an existing Supplier structure losslessly.