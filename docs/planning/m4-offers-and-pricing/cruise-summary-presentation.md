# Cruise summary presentation

**Status:** Slice 1 Shipped 2026-10-07. Slice 2 Shipped 2026-10-07. Slice 3 Shipped 2026-10-08. Slice 4 is recorded here and has no implementation authority until it is separately accepted in this plan.

**Baseline:** Inspected at `e64ff758210522240340cf6abf89cacd5b32ba5b`, the main merge of PR #226. Implement Slice 1 from current `main`.

**Builds on:** [Cruise form clarity](cruise-form-clarity.md). Retain its field anatomy, commission controls, mobile sizing, validation, and workflow boundaries.

**Visual reference:** `DepartureDesk-read-only-pages-mockup.html` is not in the repository. The written rules govern. No mockup sample values, placeholder profiles, abbreviated states, or disabled actions are implementation authority.

## Outcome

Staff can scan a Cruise and answer what sailing, agreement, and version they are viewing; what cabin supply and Supplier rates are recorded; which results are calculated illustrations; what dates, requirements, benefits, and policies apply; and what needs attention.

Prioritize inventory, costs, and agreement summary. Keep agreement details, deposits, policies, and deadlines accessible. Give optional forecasting less prominence. Do not hide an actionable problem, and do not change readiness rules.

This is a presentation refactor over existing records, commands, and calculations. It is not a shared Supplier editor or a new fact model.

## Authority

Slice 1 is Shipped. Its category-rate and Agreement presentation is the implementation authority for that slice.

Slice 2 is Shipped 2026-10-07. Its overview, inventory, category-rate summary, governing-terms, and shell-action presentation is the implementation authority for that slice.

Slice 3 is Shipped 2026-10-08. Its activation-review, operational-schedule, and icon presentation is the implementation authority for that slice. Slice 4 stays in this document so its scope is not lost. It does not authorize code until this plan is amended to accept it.

The shell label stays **Review & activate** on a draft presented version. **View activation review**, for an activated presented version, is the Accepted Slice 2 label. It keeps the existing destination and access rules.

## Decisions

| Area | Decision |
| --- | --- |
| Rate editor | Editable drafts keep the Stimulus matrix, the Commissionable checkboxes, and the Include / Subtract / Ignore controls. A static matrix is only the read-only presentation of a saved compatible shape. |
| Readiness semantics | Preserve `rate_status_label`, its priority, and the `"Needs review"` attention filter. Slice 1 changes the category heading so stage, contract review, and forecast readiness are separate facts. The cross-category summary table waits for Slice 2. |
| Forecast wording | Replace the unsupported “occupancy incomplete” claim. Show **Forecast readiness not recorded** unless existing facts establish a more specific omission, such as missing expected cabin counts. Keep the forecast fact, and keep the existing statement that activation does not require forecast readiness. |
| Shell action | Slice 2, when accepted. Draft presented version: **Review & activate**. Activated presented version: **View activation review**. Determine this from the presented version. Retain the destination and existing access rules. Slice 1 does not change this control. |
| Overview attention | Slice 2, when accepted. Replace generic **Open** with the destination name, such as **Open Cabin inventory** or **Open Supplier rates**, using existing destinations. |
| Shared styling | Retain `.dd-fact-grid dt` typography. Use existing money formatting and numeric alignment for read-only amounts. Form-clarity label sizing and matrix-input classes do not apply to saved facts. |
| Tests | Update assertions for display wording and structure that this slice intentionally changes. Preserve assertions that protect the attention rule and workflow behavior. |

## Presentation contract

These patterns apply to Slice 1 now. Later slices reuse them when accepted.

| Information | Existing primitive | Rules |
| --- | --- | --- |
| Identifying facts | `.dd-fact-grid` | Semantic `dl/dt/dd`; predictable labels; values wrap; labels stack above values on narrow screens |
| Record comparisons and schedules | `.dd-table` inside `.dd-table-wrap` | Row and column headers; descriptive title or caption; horizontal separators; numbers aligned with the existing money formatter; local overflow when necessary |
| Agreement wording | `.dd-reference-text` | Preserve full wording, paragraphs, lists, links, and existing safe rendering |
| Sections | `.dd-panel-*`, `.dd-section-title` or an existing panel heading | Clear hierarchy. Do not add a large panel for every small omission |
| Status | Existing badges and text | Label the fact being qualified. Use text as well as color |
| Attention | Existing findings and corrective paths | Identify the issue and the relevant object |
| Optional detail | Native `details/summary` | Keyboard accessible. Do not conceal an immediate blocker or a required review |
| History | Disclosure containing a table | Separate recorded date, actor, and business dates. Preserve full prior detail in row details |

Use existing palette tokens in `app/assets/tailwind/application.css`. Preserve bundled IBM Plex fonts. Do not introduce a new UI framework, global CSS reset, external fonts, or table library. Inspect consumers before changing a shared base selector. Hotel, Transportation, and Activity layout changes are outside this plan.

### Missing and unresolved values

- **Not recorded:** the relevant fact has not been entered.
- **Not provided yet / unknown:** use the existing record's commercial meaning and display helper.
- **None expected:** show only when explicitly recorded. Do not synthesize a zero component.
- **Pending / unresolved:** a calculated result cannot be completed. Retain the known results and the reason.
- **Not applicable:** show only when existing facts establish this meaning.
- **Zero:** display a genuine numeric zero when it is recorded or calculated.

Do not replace all of these states with a dash. An empty aggregate does not prove there are no requirements in the Supplier agreement. Use “No deposit requirements recorded.”

Always use the version selected by the existing controller or compiler. A governing snapshot must not silently read a successor's definitions. Confirmation is not activation. A recorded deposit requirement is not proof of settlement.

## Slice 1 — Category Supplier rates and Agreement

**Standing:** Shipped 2026-10-07.

**Pages:** `cruise_supplier_rates/show.html.erb` and `cruise_agreements/show.html.erb`, including `_identity_summary`, `_deposits`, `_deadlines`, `_benefits`, and `_policies`.

Refactoring a summary does not replace the editor on the same template.

### Supplier rates

Present category name and code, maximum occupancy, currency, stage, contract review, and forecast readiness as labeled facts. Replace the combined “Contracted · Needs review” heading. Contract review reads `contract_review_current?`. Forecast readiness reads the existing forecast predicate. Neither substitutes for the other.

Leave `rate_status_label` and the `"Needs review"` attention filter unchanged. Do not restyle `cruise_supplier_rate_summaries/show.html.erb` in this slice.

On an editable draft, keep the Stimulus matrix as the entry surface, including Commissionable and Include / Subtract / Ignore. A static matrix is the read-only presentation of a saved compatible shape. Include all stored profiles and custom components, and preserve charge and credit meaning. Show the saved percentage, including a percentage for each profile when they differ, and a read-only treatment table of Include, Subtract, and Ignore derived from the saved cells. Do not reconstruct commission from illustration totals. Do not add a second persisted summary.

If the existing projection cannot represent a stored shape without loss, retain the advanced explanation and link. Do not omit components to force a table.

Convert per-cabin illustrations to a table: occupancy, gross Supplier cost, expected commission, and net Supplier cost. Reuse the existing calculation and state helpers. A known gross with commission not recorded shows **Pending—commission not recorded** for the net. A missing gross shows **Pending — rate amounts are incomplete**. The expected-commission column stays **Not recorded** when that fact was not entered. Keep illustrations distinct from an expected sales mix or a payable invoice total.

Put forecast explanation and existing forecast content in an optional disclosure. Keep the existing forecast actions available on editable drafts. A forecast finding that blocks the requested action stays outside the disclosure.

When contract review is current and forecast readiness is not, do not say “occupancy incomplete” merely because the definition is not forecast-ready. Show **Forecast readiness not recorded**, or a more specific omission the facts establish, such as missing expected cabin counts. Keep the existing statement that activation does not require forecast readiness.

### Agreement

Refine `_identity_summary` as a key/value list. Label the system event **Confirmation recorded**. Keep group creation date and contract date distinct.

Use schedule rows for recorded operational deposits and deadlines. State amount basis, scope, and timing when available. Keep the allocated-cabin deposit as reference wording. Do not invent an allocated total or due date.

Compact omissions may cover the initial group deposit, allocated-cabin deposit, Hard Stop, Final Payment, tour-conductor credit, Group Amenity Program, payment restrictions, and the cancellation ladder. Each applicable draft **Add** or **Add step** stays available. Advanced requirements keep their advanced links. On an active version, do not show an entry action, and do not present a suggestion as an agreed date. Suggested dates stay distinct from saved dates, including existing mismatch notices. A suggestion never overwrites a saved fact.

Convert cancellation steps to columns for **Days before departure** and **Recorded policy wording**. Preserve order and text, including ambiguous percentages. Do not infer refund or penalty meaning.

Keep benefits, payment restrictions, and long notes as readable wording. Optional explanations may move into disclosures. A material interpretation distinction stays visible.

Confirmation history is a compact chronological table of existing prior confirmations. Do not manufacture rows. Each row shows:

- Provisional or confirmed state.
- Confirmation recorded date, using the existing agency-timezone helper. A provisional row shows **Not confirmed**. Do not add a time of day.
- Actor, group number, group creation date, and contract date.
- Note and supplemental deposit treatment, in full, through row details.

Preserve heading and focus anchors, and the existing Add, Edit, Correct, and Remove paths, permissions, submission boundaries, and error behavior.

### Slice 1 proof

| Scenario | Required result |
| --- | --- |
| Editable category rates | The Stimulus matrix, Commissionable checkboxes, and Include / Subtract / Ignore controls remain the entry surface |
| Saved compatible rates, not being edited | A static matrix shows stored profiles, custom components, and charge or credit meaning. Advanced shapes keep their explanation and link |
| Contract reviewed, forecast not ready | The heading shows current contract review and **Forecast readiness not recorded**, or a more specific recorded omission. Activation is not newly blocked. `rate_status_label` and the `"Needs review"` attention filter are unchanged |
| Unknown commission, explicit none, known commission | Existing commercial meanings and gross or net result states are preserved |
| Illustration table | Amounts and unresolved states match the existing evaluator. No expected sales mix is implied |
| Empty agreement sections | The named omissions are compact. Each draft Add or Add step remains. No Supplier requirement, exemption, or completion is invented |
| Suggested versus recorded dates | The saved date stays authoritative. The suggestion and any mismatch notice stay distinct |
| Cancellation wording | Full wording and order are preserved |
| Confirmation history | Columns match the list above. A provisional row says **Not confirmed** |
| Error and focus return | Submitted values, summary focus, and editor reopening survive |
| Keyboard, 390px viewport, and 200% zoom | Headings, disclosures, facts, local table scrolling, and actions remain usable |
| Permissions and cross-agency access | Existing access behavior is preserved |
| Shared CSS | A representative non-Cruise fact grid keeps its existing `dt` typography |

Update assertions that lock the old combined stage heading or other wording this slice changes. Keep assertions that protect `status_label == "Needs review"` and workflow behavior. Avoid tests that assert only CSS class strings.

Run focused affected tests, the full application suite, system tests, the Tailwind build, and relevant lint. Review the two pages in the browser at desktop width, a narrow width, and 200% zoom.

**Exit:** Both pages expose their recorded facts and calculated illustrations, with independent contract-review and forecast facts, and unchanged commands and attention rules.

## Slice 2 — Operational overview, inventory, and governing terms

**Standing:** Shipped 2026-10-07.

**Pages:** `cruise_arrangements/show.html.erb`, `cruise_active_versions/show.html.erb`, `cruise_cabin_categories/index.html.erb`, `cruise_supplier_rate_summaries/show.html.erb`, and `cruise_inventory_changes/show.html.erb`. Supporting contextual readouts may change only to stay consistent with an already-present fact: sailing edit, cabin category new and edit, and the same-terms and changed-terms inventory forms.

- Cruise overview: key/value sailing facts and compact inventory, rates, agreement, and Client connection summaries. Replace **Open** with the destination name. Do not repeat every detailed schedule.
- Cabin inventory: keep the table. Label inventory treatment and each quantity. Keep on-request and external quantities untracked. Separate opening quantity from current projected capacity.
- Category rate summary: refine captions, money alignment, and gross or net meaning. Show stage, contract review, and forecast readiness separately. Do not change `rate_status_label` or the attention filter.
- Active Supplier terms: key/value version and activation facts, sailing facts, and the cabin table. Identify a proposed successor without mixing its terms into the governing view.
- Inventory-change chooser: compare same versus changed Supplier terms and keep the existing actions, including the prohibition on a second proposed block when a successor already exists.
- Shell: draft presented version keeps **Review & activate**. Activated presented version says **View activation review**. Same destination and access rules. Keep version status distinct from agreement confirmation and section readiness.

**Exit:** Staff can distinguish governing versus proposed terms, opening versus current quantity, and rate stage versus review state on the primary Cruise screens.

## Slice 3 — Activation review and operational schedules

**Standing:** Shipped 2026-10-08.

**Pages:** `cruise_activations/show.html.erb` and `cruise_deposits_and_deadlines/show.html.erb`, including `_activation_details.html.erb`.

- Activation document title and heading follow the shell action: **Review & activate** on a draft presented version, **View activation review** when that version is activated. The journey step stays **Review & activate**.
- Supplier setup is an Area / Status table with the existing labels, statuses, and links. Blockers and their corrective actions stay visible. Do not invent readiness states.
- Inventory columns are category (code and name), treatment, and opening quantity. Numeric quantity is the existing `quantity_label`. An unset numeric quantity stays the current dash. On-request and external inventory stay **Quantity not tracked**. The contracted-rate table is category plus the existing contracted-terms description. No current-capacity column and no corrective-destination column on that table.
- Keep elapsed requirements, confirmation triggers, duplicate-identifier review, administrator overrides, acknowledgements, and **Confirm and activate group**. Preserve the atomic confirmation and activation operation.
- Successful activation metadata is a fact grid: version, recorded date, actor, and Supplier-issued identifier when present.
- Deposit and deadline schedules are separate `.dd-table` tables inside `.dd-table-wrap`. They do not use the narrow fixed-layout rule used by cabin and rate tables. Deposit columns are requirement and type (`semantic_type_label`), amount or basis, due timing, scope, the draft workspace label when that label is **Ready**, **Blocked**, or **Open advanced**, operational state, and actions. Deadline columns are deadline and effect (`semantic_type_label`), due timing, scope, that same workspace label, operational state, and actions. Deadline rows have no amount.
- `status_label` is not definition status. On a governing version, operational state uses `projection_status` and `commitment_state_label` only when `operational` is present. Successor reconcile text stays in a comparison disclosure that may start closed, not in the status column.
- Row blockers, time-sensitive projection status, materialized due timing, commitment or disposition, and the existing commitment, handled-externally, edit, and remove actions stay visible without expanding a disclosure. An open editor renders in a following full-width row. Focus targets stay on the main row.
- The elapsed-acknowledgement sentence appears on the readiness banner when the existing preview requires it. Blockers stay on the banner. The activation preview is a table of definition, amount or basis, due timing, scope, commitment effect, attention, and the existing editor link. It remains a definition-level preview and creates no Supplier Payment, Obligation, or paid record.
- Icons are curated Phosphor Regular partials through `icon_tag` at `dd-icon dd-icon--sm`: `warning_circle` on the needs-attention heading and a row blocker, `clock` on the elapsed heading, `check_circle` on the recorded-activation heading, `pencil_simple` on Edit, and `trash` on remove. `check_circle` means activation is recorded for the displayed version. Do not add category, draft, upcoming, or next-action icons, and do not install an icon package or font.
- Reuse Agreement display support only where meanings and orchestration already match. Do not create a universal deposit or payment requirement record. Leave `form-error-summary` `connect()` unchanged.

**Exit:** Activation and later requirement review stay reachable, with the same gates, actions, and consequential information.

## Slice 4 — Client connection and Client terms

**Standing:** Recorded. No implementation authority until this slice is separately accepted.

**Pages:** `cruise_service_connections/show.html.erb` and `_summary.html.erb`, and `cruise_client_terms/show.html.erb` and `_summary.html.erb`.

Supporting inventory, outside the summary refactor: `cruise_service_connections/_editor.html.erb`, `cruise_service_connections/_fields.html.erb`, and `cruise_client_terms/_editor.html.erb`. Their controls and behavior stay as they are.

- Connection summary: key/value connection state, Client title, optional Staff name, selected sailing and version context, and the existing earlier-version warning.
- Category mapping table: Supplier category and corresponding Client option. Preserve not-connected, decide-later, advanced, and connected states.
- Client terms: display the saved category terms. Reuse existing band and component representations. Retain unsupported and advanced explanations.
- Scenario comparison: category or scenario, Client total, Supplier gross, expected commission, Supplier net, indicative margin, and result state where the existing evaluators return them. Qualify indicative headings.
- Retain pending and omitted reasons, known partial Client lines, capacity qualifications, and unsupported traveler-position findings.
- Remove the hardcoded Celebrity price illustration from the production summary. Illustrative examples may remain in development specimens or fixture documentation, separate from saved Client terms.
- Keep existing Edit and service-offer destinations. Do not change Client publication, pricing, package composition, source bindings, or eligibility.

**Exit:** Staff can inspect recorded Client terms and existing scenario results without confusing sample data, Supplier costs, Client prices, or indicative margin.

## Supporting inventory for Slice 1

These templates stay in place. Slice 1 changes one only when an already-present readout on that page would otherwise contradict the Agreement or category-rate presentation:

- `composition_cruises/new.html.erb`
- `cruise_sailings/edit.html.erb`
- `cruise_cabin_categories/new.html.erb` and `edit.html.erb`
- `cruise_inventory_changes/same_terms.html.erb` and `changed_terms.html.erb`
- `cruise_setup/_shell.html.erb`. Slice 2 sets the review-action label from the presented version.
- `cruise_arrangements/_version_context.html.erb`

`builder/components/edit_cruise_setup.html.erb` is excluded.

## Exclusions

This plan does not authorize a new database model, summary snapshot, or financial calculation. It does not change requirements, evidence rules, confirmation, successor copying, permissions, tenancy, locks, idempotency, or inventory modes. It does not add payment processing, attachments, policy interpretation, forecast changes, filters, exports, or a new navigation structure.

It does not refactor advanced Supplier planning, capacity event history, cost planning, reservations, commitments, exposure, generic activation, or Arrangement ending. It does not change Hotel, Transportation, or Activity markup.

## Sequence

1. Slice 1 was accepted, then Shipped 2026-10-07. That shipment does not authorize Slices 2–4. Slice 2 is separately Accepted.
2. Slice 1 is Shipped 2026-10-07, including the interface-contract rules for its facts, tables, wording, and disclosures.
3. Slice 2 is Shipped 2026-10-07. Slice 3 is Shipped 2026-10-08. Accept Slice 4 separately by amending this plan.
4. Within an accepted slice, inspect the owning controllers, compilers, helpers, projections, and tests before changing markup. Add thin read-only display support only where necessary. Do not parse summary prose back into structured fields or recompute money in JavaScript.
5. Update `docs/ui/interface-contract.md` with the fact, table, wording, disclosure, and status rules as a slice ships.
6. Mark the whole plan Shipped only after all four slices are Shipped.
7. Do not copy mockup sample data or CSS resets into production. No AGENTS.md change is required for Slice 1.

## Completion

The plan is complete when the named Cruise summaries use consistent facts, tables, wording, and optional-detail patterns; Staff can complete the existing journeys; statuses tell the truth about the facts they qualify; and no required information, domain rule, financial meaning, or documentation burden has changed.
