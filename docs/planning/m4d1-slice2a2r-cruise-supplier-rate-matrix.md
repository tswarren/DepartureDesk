# M4D.1 Slice 2A.2R — Cruise Supplier Rate Matrix Remediation

**Status:** Shipped 2026-09-22. Sole shipped authority for Cruise Supplier rate-matrix **compilation** remediation (parent Stop point C). Parent [M4D.1](m4d1-departure-composition-workspace.md) remains Accepted for later slices. [Slice 2A.2](m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md) remains the historical fixed-form baseline. Interactive Staff chrome remediation is Accepted [Slice 2A.2R2](m4d1-slice2a2r2-cruise-rate-matrix-interaction.md) (not yet shipped). Slice 2B+, Client connection, and M4E remain unauthorized until named.

**Parent authority:** [M4D.1 — Departure Composition Workspace](m4d1-departure-composition-workspace.md), especially §§11–12, 19–20, and §21.

**Implementation base:** [`bf41e0b`](https://github.com/tswarren/DepartureDesk/commit/bf41e0b) (merge of [PR #134](https://github.com/tswarren/DepartureDesk/pull/134) — shipped M4D.1 Slice 2A.2).

**Implementation guide (non-authority):** [Cruise Supplier Rate Workspace Wireframe](drafts/DepartureDesk-Cruise-Supplier-Rate-Workspace-Wireframe.md).

**Scope locked:** Stop point C remediation only — typed Cruise Supplier rate **matrix**, commission, occupancy illustrations/plan, and generic zero-amount readiness. This plan does not authorize Slice 2B deposits/deadlines, Client Service connection, Client prices, Package scenarios, or Vineyard acceptance.

```mermaid
flowchart LR
  accept["Accept 2A.2R"] --> ra["2A.2R-A matrix core"]
  ra --> rb["2A.2R-B flexible proof"]
  rb --> ship["Ship 2A.2R"]
```

## 1. Outcome

For one Cruise cabin category, Staff can transcribe an ordinary Supplier rate sheet as a matrix:

1. Columns describe the Supplier’s rate profiles.
2. Rows describe charges and credits.
3. Each populated cell is one bounded Supplier cost term.
4. Live profile subtotals appear while Staff enter amounts (server authoritative on save).
5. Percentage commission uses shared or profile-specific rules with explicit per-cell bases.
6. Dollar commission is entered by rate profile.
7. Per-cabin occupancy illustrations combine applicable profiles without persisting totals.
8. Unsupported formulas remain available through advanced Supplier cost planning.

No Client, Service Offer, Package, booking, or payment records are created. No Cruise-specific rate, profile, or component table is authorized. No second money engine is authorized.

## 2. Authority and documentation timing

**Shipping note (2026-09-22):** Composition Cruise Supplier rates use the rate-profile matrix over generic M3C (R-A matrix core + R-B flexible proof). Slice 2B deposits/deadlines remain unauthorized.

The shipping change set marks this slice shipped and updates the parent, planning index, roadmap, terminology, and `AGENTS.md`.

Discovery inputs that informed this plan ([addendum draft](drafts/M4D1-Slice2A2-Cruise-Rate-Matrix-Addendum.md), wireframe) are not competing implementation contracts after Accept.

## 3. Carried forward from shipped Slice 2A.2

These contracts remain unchanged:

- exact-context Supplier cost ownership (Item + sailing Occurrence + cabin Resource);
- generic M3C persistence and evaluation;
- draft-only writes and activated-version freeze (M3D.7);
- successor-draft editing returning to the typed Cruise workspace;
- independent occupancy-planning and readiness saves;
- blank pending values never becoming zero without an explicit `0.00`;
- advanced-planning escape without rewriting unsupported graphs;
- no Client, Package, booking, ledger, or payment records;
- category-scoped `DetectCruiseSupplierRateShape` distinct from `DetectCruiseArrangementShape`;
- section-owned transactions via `CostCommandSupport#*_already_locked!` / `clear_readiness!`;
- shipped supplier-rates routes under cabin categories.

## 4. Superseded Slice 2A.2 clauses

Where this plan conflicts with [Slice 2A.2](m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md), **this plan governs** for typed-rate implementation:

| 2A.2 location | Superseded assumption |
| --- | --- |
| §3.2 Section A fixed fields | Fixed Smith-shaped fare/NCCF/discount/tax/commission fields |
| §3.2 / §4 Traveler-only mapping | One generic `Traveler` participant category for typed rates |
| §4 commission mapping | At most one `expected_commission` component; schedule-level dollar basis only (`persons` or `resource_units`) |
| §7 reopen rules | One dollar commission; one percentage commission; position-specific dollar commissions advanced-only; multiple overlapping commissions advanced-only |
| §11 acceptance proofs | Proofs keyed only to fixed canonical labels (“First/second traveler fare”, …) |
| Related non-goals | “Traveler-position-specific … commission in the typed form” as always advanced-only |

Shipped 2A.2 remains historical baseline and implementation base SHA for this remediation.

## 5. Terminology

### 5.1 Rate profile

A **rate profile** is one matrix column describing how all populated cells in that column apply. It is a typed-form projection over existing M3C selectors, not a new durable aggregate.

Examples: First/Second; Additional; Every Traveler; Every Cabin; Child First/Second; Single Supplement.

Do not call these columns occupancy profiles. Persisted `SupplierCostOccupancyProfile` records remain forecast assumptions with expected resource-unit counts.

### 5.2 Component row

A **component row** groups like-labeled cost cells. The four static rows are Base Fare, NCCF, Taxes & Fees (Supplier charges), and Discount (Supplier credit). Staff may add additional simple charge or credit rows. A row is not a separate domain record.

### 5.3 Cell

A **cell** is the intersection of one component row and one rate profile. A populated cell compiles to exactly one `SupplierCostComponent`. A blank cell compiles to no component.

### 5.4 Profile subtotal

Sum of charges less credits within one column for one application of that profile. Not necessarily a complete cabin price.

### 5.5 Occupancy illustration

Derived ephemeral combination of rate profiles for one anonymous cabin configuration, unless Staff separately records a forecast occupancy plan.

## 6. Page structure

Present in order:

1. Cabin-category context and version state
2. Rate-profile selection
3. Rate-component matrix
4. Expected commission
5. Occupancy illustrations
6. Optional forecast occupancy plan
7. Readiness summary and actions

Retain a direct **Advanced cost planning** action. Advanced planning is an escape, not a destructive conversion.

## 7. Rate-profile contract

### 7.1 Supported profile families

| Staff-facing shape | Quantity basis | Participant category | Position selectors |
| --- | --- | --- | --- |
| Every Traveler | `persons` | Optional | None |
| First/second traveler | `occupancy_positions` | Optional | 1–2 |
| Additional traveler | `occupancy_positions` | Optional | 3 onward |
| Bounded traveler positions | `occupancy_positions` | Optional | Explicit start/end |
| Every Cabin | `resource_units` | None | None |
| Single-occupancy adjustment | `single_occupancy_units` | None | None |

**Every Traveler** and **Every Cabin** are required families so legacy `persons` / `resource_units` components (including NCCF, taxes, and schedule-level dollar commission) reopen without splitting one component into several.

Participant categories use existing Item-scoped `SupplierCostParticipantCategory` records (Adult, Child, Teen, or Supplier-defined). Do not use a participant category to represent an occupancy position or cabin condition.

### 7.2 Presets

Offer First/Second, Additional, Child, Single Supplement, Every Traveler, Every Cabin, and Other supported profile. Presets populate form state only. They do not create durable records until the saved matrix contains at least one populated cell for that selector signature.

### 7.3 Adult and Child overlap

A category-free position component matches every participant category in the selected positions. Adding a Child profile beside a category-free First/Second or Additional profile may make both apply to the same child.

Before save, detect overlap and require explicit resolution:

- retain the existing profile as applying to every traveler;
- scope the existing profile to Adult;
- edit or remove one of the overlapping profiles.

Never silently reinterpret a category-free component as Adult-only. Additive overlap is allowed only after explicit Staff confirmation; illustrations must show the combined result.

### 7.4 Child ages

Age ranges may appear as descriptive text in the participant-category label (for example `Child (ages 2–11)`). This slice does not match birth dates or create structured age-rule authority.

### 7.5 Single Supplement

Additive single-occupancy adjustment using `single_occupancy_units`. Not a complete single-occupancy fare. A Single Adult illustration normally combines the applicable first-position traveler profile and the Single Supplement. Explain that traveler-profile amounts must not be repeated in the supplement column unless the Supplier truly charges them again. Do not derive a supplement by subtraction from a standalone single price—use advanced planning.

### 7.6 Empty profiles

No durable empty rate-profile record. Newly selected empty profiles remain form state; saving them fabricates no zero placeholder. Warn that empty profiles are not retained after leaving the page. Do not add a `SupplierCostRateProfile` table.

## 8. Component-matrix contract

### 8.1 Static rows

Always appear: Base Fare, NCCF, Taxes & Fees (`supplier_charge`); Discount (`supplier_credit`). Cannot be removed or renamed in the typed form. Blank static cells create no components.

### 8.2 Additional rows

Staff may add, rename, or remove an additional row (description + charge/credit kind). Kind changes update every cell sign. Labels unique case-insensitively within the matrix; blank labels and over-limit labels rejected. Additional rows support only the column’s unit-rate shape. Percentages, minimums, tiers, conditionals, and fixed group-wide amounts use advanced planning.

### 8.3 Blank and zero

- Blank means unknown/pending/not yet applicable; never zero.
- `0.00` means known contractual zero and persists as `amount_minor_units = 0`.
- See §11 for the generic M3C readiness amendment.

### 8.4 Compilation

| Matrix fact | Component fact |
| --- | --- |
| Row description | `label` |
| Row kind | `economic_role` |
| Cell amount | `amount_minor_units` |
| Profile quantity shape | `quantity_basis` |
| Profile traveler type | `participant_category_id` |
| Profile positions | `occupancy_position_from` / `occupancy_position_to` |
| Currency | Departure operating currency |
| Calculation kind | `unit_rate` |

Preserve distinctions among charges, credits, and expected commission.

### 8.5 Reconstruction

Rows by normalized label + economic role. Columns by selector signature:

`quantity_basis + participant_category_id + occupancy_position_from + occupancy_position_to`

Typed compatibility requires no duplicate cell, one role per normalized row label, only supported unit-rate charge/credit shapes, no ambiguous selectors, and percentage components used only for expected commission with supported bases. Static labels recognized case-insensitively with canonical display capitalization. Custom spelling preserved. Broken advanced graphs → non-destructive read-only summary + advanced link.

## 9. Totals and illustrations

### 9.1 Live profile subtotals

`profile subtotal = Supplier charges − Supplier credits` per column. Browser advisory; server authoritative on save. While working with blank cells, label **Known profile subtotal**, not **Total**.

### 9.2 Occupancy illustrations

Combine applicable profiles for anonymous configurations (for example Single Adult, Double Adult, Triple Adult, Two Adults + Child). With one participant category, suggest Single/Double/Triple up to `maximum_occupancy`. With multiple categories, Staff select the category for each anonymous position before the illustration is authoritative. Illustrations are ephemeral.

### 9.3 Server evaluation

`CompileCruiseSupplierRatePreview` reuses or extracts primitives from `EvaluateSupplierCostForecast`. No competing money engine. Return known gross, commission when calculable, net when calculable, pending inputs, and overlap/unsupported warnings.

## 10. Commission contract

### 10.1 Methods

Schedule-level method is one of: percentage; dollar amount; not provided yet. One method across the matrix. Mixed percentage and dollar requires advanced planning. Expected commission is planning-only (not earned/settled/payable).

### 10.2 Shared percentage rule

When Staff use **Use the same percentage for every profile** (or reopen a legacy single percentage component):

- compile **one** `expected_commission` percentage component;
- one percentage rate;
- selected base links across multiple matrix cells;
- **one rounding boundary**.

Do not mechanically split one shared percentage into per-profile components. Splitting changes minor-unit rounding versus a single combined component.

UI may show illustrative commission by column; those illustrations are not the authoritative combined rounded commission.

### 10.3 Profile-specific percentage rules

One `expected_commission` percentage component per profile when rates differ by profile or Staff explicitly choose separate profile calculations. Each component links only to that profile’s selected cells and rounds independently.

### 10.4 Per-cell bases

For every populated charge or credit cell, Staff choose whether it affects the commissionable base:

- checked charge → `add`;
- checked credit → `subtract`;
- unchecked → no base link.

While working, unchecked cells are ignored for live preview but remain visibly unconfirmed. Before readiness, Staff confirm every populated cell was reviewed for commission treatment. Once forecast-ready, absence of a base link means intentionally ignored. Cell edits clear readiness and require commission review again.

Percentage components use additive treatment, sit after all bases, and require positive rate and at least one base before readiness.

### 10.5 Dollar commission

Hide the percentage-base grid. Enter one expected commission amount per applicable rate-profile column. Each entry compiles to `expected_commission` `unit_rate` using that column’s selector signature (including Every Traveler / Every Cabin / position / Single Supplement profiles). Booking-specific, group-wide, tiered, or conditional dollar commission uses advanced planning.

### 10.6 Not provided / method changes

Not provided: gross visible when calculable; commission and net Pending; no fabricated commission component. Forecast-ready with commission omitted: confirmation states omitted commission means **no expected commission**, not unknown.

Method changes atomically replace only expected-commission components and their base links.

## 11. Generic M3C zero-amount readiness amendment

Implement in generic readiness validation and tests (not Cruise-controller exception):

- `fixed` and `unit_rate` component amounts may be **zero** in a forecast-ready definition;
- percentage rates and minimum values must remain positive;
- an otherwise valid calculated definition may contain zero components when **at least one** meaningful monetary component is positive;
- an entirely zero-cost source must use `zero_cost` mode with a reason;
- zero components participate in fingerprints, successor copies, audits, reconstruction, and readiness;
- blank remains missing and distinct from zero.

## 12. Legacy projection and first-edit conversion

No bulk data migration. Use compatibility projection and lazy conversion.

### 12.1 Projection of existing typed schedules

Recognized shipped fixed-form components reopen in the matrix through this deterministic mapping:

| Existing typed component | Matrix projection |
| --- | --- |
| First/second traveler fare | Base Fare × First/Second |
| Additional traveler fare | Base Fare × Additional |
| Single occupancy supplement | Base Fare × Single Supplement |
| NCCF using `persons` | NCCF × Every Traveler |
| First/second traveler discount | Discount × First/Second |
| Additional traveler discount | Discount × Additional |
| Taxes, fees, and port charges using `persons` | Taxes & Fees × Every Traveler |
| Dollar commission using `persons` | Dollar commission × Every Traveler |
| Dollar commission using `resource_units` | Dollar commission × Every Cabin |
| Existing single percentage commission | Shared percentage (one component; bases mapped to projected cells) |

### 12.2 First edit

When Staff first edits a legacy schedule:

1. Show the projected matrix.
2. Explain that saving converts to the flexible matrix format.
3. Preview label changes and readiness invalidation.
4. Require explicit confirmation.
5. Convert atomically during save.

Conversion must:

- preserve component IDs where formulas remain unchanged;
- preserve amounts, roles, selectors, stage, currency, and provenance;
- preserve existing commission rounding semantics (shared percentage stays one component);
- canonicalize labels only where necessary for matrix grouping;
- rebuild only affected commission links;
- clear forecast readiness;
- audit the conversion.

If the legacy graph is ambiguous or contains advanced terms, show it read-only and route to advanced planning. Never guess.

## 13. Forecast occupancy planning

Carry shipped 2A.2 semantics: illustrations vs confirmed forecast mix; persist profiles only after explicit confirmation with truthful `resource_unit_count`; `SetCruiseSupplierOccupancyPlan` clears readiness for exact Item/Occurrence/Resource definitions in the same transaction when membership, counts, positions, or categories change.

With multiple participant categories, forecast positions use the selected categories.

## 14. Commands, routes, and detection

Retain command names:

- `CreateCruiseSupplierRateSchedule` / `UpdateCruiseSupplierRateSchedule` — normalized matrix payload (profiles, rows, cells, commission method, shared or profile-specific percentage / dollar values, conversion confirmation when legacy);
- `SetCruiseSupplierOccupancyPlan`;
- `MarkCruiseSupplierRateScheduleForecastReady`;
- `CompileCruiseSupplierRatePreview`;
- `DetectCruiseSupplierRateShape` (editable matrix / read-only matrix / no schedule / unsupported with reasons).

Retain shipped routes under `/departures/:departure_id/arrangements/:id/cruise/cabin-categories/:resource_id/supplier-rates` (and occupancy-plan / forecast-readiness).

One rate-section save owns one transaction. Do not chain public multi-transaction M3C commands. Preload category rate state on the Cruise workspace.

## 15. Acceptance fixtures

### 15.1 Smith O1 regression (canonical matrix)

| Matrix column | Smith entries |
| --- | --- |
| First/Second | Base Fare $1,624; Discount −$150 |
| Additional | Base Fare $406; Discount −$37.50 |
| Every Traveler | NCCF $320; Taxes & Fees $137 |
| Single Supplement | Base Fare $1,624 |

Gross illustrations: Single $3,555.00; Double $3,862.00; Triple $4,687.50. Commission and net Pending. Do not invent a Celebrity commission rate.

### 15.2 Family-rate anti-overfitting fixture

Illustrative (non-Celebrity) fixture with Adult/Child profiles, distinct child fare, Adult discount commissionable / Child discount ignored, Single Supplement discount subtracts from supplement base, percentage with per-cell bases, and Single Adult / Double Adult / Two Adults + Child illustrations.

### 15.3 Dollar commission and shared-percentage rounding

Prove dollar commission on traveler-position, Child, and Single Supplement profiles. Prove shared percentage rounds once and must not silently split into per-profile components on legacy conversion. Prove profile-specific percentages round independently when Staff choose that mode.

## 16. Delivery after Accept

Full matrix contract is frozen by this Accepted plan. Implement from the Accept merge tip only, as two vertical PRs:

### 2A.2R-A — Matrix core and compatibility

Normalized matrix compiler; generic zero amendment; legacy projection and confirmed conversion; Smith end-to-end matrix; shared percentage and existing dollar reopen; server-authoritative totals; reshape detect/preview/UI for matrix including Every Traveler / Every Cabin.

### 2A.2R-B — Flexible cruise-rate proof

Adult/Child profiles and overlap resolution; custom rows; per-cell commission treatment; profile-specific percentage and dollar commission; mixed traveler illustrations; narrow-screen experience; family-rate acceptance fixture.

Do not harden another Smith-only API in R-A. Do not write a second implement-plan document.

## 17. Explicit non-goals

- Arbitrary formula authoring
- Percentage Supplier charges/credits outside expected commission
- Minimum amounts or quantities; tiers; date-dependent rates
- Automatic PDF interpretation; birth-date age eligibility
- Persisted generic scenario templates; Client prices or Supplier-to-Client copying
- Deposits, deadlines, commitments, Obligations, Payments, or commission settlement
- Booking-specific commission totals
- Mixed dollar-and-percentage commission in one typed matrix
- Bulk migration of existing typed schedules
- A Cruise-specific rate, profile, or component table
- A second calculation engine

Profile-specific dollar commission **is** in scope for the typed matrix (unlike shipped 2A.2).

## 18. Exit criteria

2A.2R is complete when Staff can:

1. Select ordinary First/Second, Additional, Every Traveler, Every Cabin, Child, and Single Supplement rate profiles.
2. Enter static and additional charge/credit rows as a Supplier-rate matrix.
3. See trustworthy live profile subtotals with server-authoritative save.
4. Use shared or profile-specific percentage bases per cell, or dollar commission per profile.
5. See commission and net remain pending when incomplete; omitted commission at readiness means none.
6. Convert a legacy fixed-form schedule only after explicit confirmation, preserving shared-percentage rounding.
7. Persist forecast occupancy separately and clear readiness on occupancy edits.
8. Escape to advanced planning without data loss when the graph is unsupported.

When exit proof is green, mark this slice shipped. **Exit proof is green.** This shipping change set marks Slice 2A.2R shipped.

## 19. Handoff

Slice 2B begins only when its own Accepted plan names deposits, deadlines, and activation-safe editing.
