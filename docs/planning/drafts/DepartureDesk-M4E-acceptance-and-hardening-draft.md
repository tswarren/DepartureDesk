# M4E — Offers and pricing acceptance and hardening

**Status:** Draft for review, 2026-09-20. Proposed M4 milestone gate; not implementation authority until accepted.

**Prerequisites:** Accepted [M4 parent](../m4-offers-and-pricing.md), [ADR 0014](../../adr/0014-client-offers-publication-and-supply-compatibility.md), and [M4.0](../m40-task-flow-and-contract.md) (Accepted 2026-09-20; not implementation authority for M4A–M4E). MVP occupancy exception and roadmap M5 due-Charge amendment are already in those documents. M4A–M4D **shipped and merged** on a pinned CI-green descendant of [`ea6d63e`](https://github.com/tswarren/DepartureDesk/commit/ea6d63e875d917415da061e7b1a64b382c5f91a1). [M4A](DepartureDesk-M4A-service-definitions-and-sources-draft.md), [M4B](DepartureDesk-M4B-client-pricing-and-anonymous-preview-draft.md), [M4C](DepartureDesk-M4C-packages-choices-and-client-terms-draft.md), and [M4D](DepartureDesk-M4D-publication-and-live-feasibility-draft.md) here are planning drafts, not proof of implementation. Verify their accepted repository contracts, merged SHAs, findings, and CI before promoting this gate. Coding slices reconfirm required CI on the branch tip.

**Authority:** Parent, ADR 0014, and M4.0 as above. Shipped M3F fixture ledger and scenario narratives. Pin the actual M4D merge or later descendant and its required workflow results when accepting M4E.

## Goal and scope

Prove that M4A–M4D work **together** as a calm Staff journey: from Supplier planning through Client price, optional Package and choices, one review/publication action, live availability, pause/resume and successor review. Close finding-driven defects, measure friction against the accepted M4.0 **rules**, validate two ledger-labeled scenario journeys and the M5 handoff, then mark M4 complete only when all parent obligations have evidence.

M4E adds **no new commercial aggregate** and must not quietly expand M4 with Client Trip, Traveler, Hold, Allocation, Charge, Receipt, Supplier Obligation, Payment, Cancellation Case, Communication, FX, public storefront, new offer reference, general formula language, or a persisted review projection. If integrated testing reveals missing product authority, amend and accept that authority explicitly before changing production behavior. Substantial defects receive a focused remediation PR and are rechecked before closure; the gate is not permission for unrelated scope.

No ADR 0004 namespace. No Administrator publication override. Never reuse `override_supplier_planning_terms`.

## Sequence and release evidence

| Stage | Deliverable | Gate |
| --- | --- | --- |
| 1. Pin and map | Record merged A–D SHAs, the exact documentation/product amendments, required CI, and a matrix from each parent invariant/exit criterion to an executable proof or documented reason. Open a finding log with severity, affected journey, owner and closure evidence. | No missing authority and no parent criterion without an evidence owner. Documentation from prior slices matches shipped behavior. |
| 2. Integrated Staff journeys | Run Celebrity and Vineyard through source setup, pricing, optional Package, choices, combined review, publication, availability, pause/resume, source successor and appropriate retired path. Exercise standalone service and package-only service separately. | Scenario assertions distinguish confirmed M3 facts, **illustrative Client prices**, and shape-only inputs. One publication action for inline package-only service. |
| 3. Finding-driven hardening | Fix only reproducible integrated defects: source/price/choice/term mismatch, wrong lifecycle label, tenant leak, unsafe race, incorrect money or M5 handoff, accessibility/friction regression or meaningful query growth. Re-run affected journey and necessary regression gate. | Each finding has an observed failure, remedy, test/evidence and owner; no unresolved blocking finding. Significant repairs are focused PRs before milestone closure. |
| 4. Close M4 | Map every criterion to code/test and UI evidence, reconcile terminology/interface/architecture/README/roadmap/AGENTS and plans, verify final CI and M5 handoff. | Mark M4 complete only after merged fixes and final branch green; avoid docs-ahead-of-code claims. |

## Integrated scenario ledger

| Journey | Confirmed facts to preserve | M4 examples and acceptance checks |
| --- | --- | --- |
| Celebrity Beyond / Smith Family Reunion | Nov 6–13, 2027 sailing; mandatory cruise plus optional hotel/transfers/excursion/dining shapes; O1 Resource/Pool context; pre-stay Occurrence may fall outside sailing/Departure dates. M3F labels the O1 fare/NCCF/discount/tax figures as **Supplier cost** inputs. | Start cruise Service Offer from activated Item/Occurrence; price anonymous first/second/additional/single scenarios with **explicitly labeled illustrative Client rates** unless accepted Client rates exist. Test a hotel extra-night rate with explicit billable nights, optional service choice, service-sum or bundle as actually configured, and one combined review. M3 cost never silently becomes Client price; Supplier deposit is not Client installment. |
| Vineyard Tour | June 5–7, 2027 operating dates, 30-seat coach, distinct Standard/Deluxe dinner Supplier Items, tasting and lunch shape. Hotel A/B sequence and nights remain shape-only. | Build distinct services, an inline package-only service (`independently_sellable = false`), a bundled Package price `P` and double/single examples. The 100% supplement `s = 1.0` is **illustrative**, producing `2P` in the single example with no duplicate lodging charge. Dinner is an exactly-one **Client** choice with separate bound Supplier Items; unresolved dinner rates stay unknown or use clearly labeled test values, never invented agreement facts. Shared coach cost makes margin unknown without a stated enrollment assumption. |

To exercise successful publication where actual Client figures are missing, use deterministic **test-only illustrative** prices and terms, label them in fixture and assertion names, and keep them out of authoritative scenario narratives. Also prove that a real draft with an unresolved required Client price cannot publish. Optional unavailable paths may be displayed with reasons when another valid path permits structural publication.

## Staff friction and accessibility proof

Run identical Staff tasks against M4.0's accepted **rules**: (a) one standalone M3-backed service, (b) a simple bundled Package with one inline service, (c) Celebrity occupancy and extra night, and (d) Vineyard double/single and dinner choice. Start timing/counting at the Departure. Record **required entries**, **repeated known source facts**, **context switches**, **publication actions**, **steps to locate/fix one invalid review**, and unexpected advanced controls.

M4.0 has rules, not numeric baselines. If no contemporaneous preimplementation counts exist, say so and **publish observed counts** rather than inventing a historical baseline. Compare observed counts with the M4.0 rules (one publish action, no re-entry of known source facts, no formula builder, progressive disclosure, in-context recovery, Sales enabled vs computed state).

| Rule to verify | Pass evidence |
| --- | --- |
| Prefill | Same known provider, dates, category and operating currency are not manually re-entered; deliberate Client text changes are counted separately. No Supplier cost is copied into Client price. |
| Low-friction Package | Inline package-only service needs no catalog detour and **one** publish action for Package and new inline service versions. Bundled components require no fictitious component revenue allocation; Package Client payment schedule is entered once. |
| Progressive disclosure | Single-source, simple-price flow hides multi-source grid, advanced percentage links, cap and term-conflict editor until actually needed. A standalone service skips Package step without an empty shell. |
| Review recovery | Error summary links to the precise offending source, price, choice, terms or date field; values survive repair; Staff can return to the same combined review without re-entering unrelated fields or repeating publication. |
| Truthful state | Sales enabled is one Staff intent control. Current **Selectable now / On request / Unavailable** is a separate, time-labeled reasoned readout; on-request never shows invented numeric supply and zero Pool quantity does not stop publication. |

Exercise keyboard-only editing, inline choice creation, error focus and summary links, one-handed/tab order and screen-reader labels; check 375/768/1280/1400 layouts. **Viewer-safe published branches only** — no draft offer pages for Viewer; no margin or Supplier cost in Viewer HTML/JSON. Shipped M3 cost-forecast Viewer access stays unchanged. Record findings and fix actual regressions. Compare required action counts, not superficial click totals; an advanced multi-source case may legitimately require more fields than the ordinary path.

## Parent invariants and integrated proof map

| Parent contract | M4E evidence |
| --- | --- |
| 1. Tenant/permission | Staff/Administrator authorized through session-derived Agency; unpublished drafts are `manage_departures` only; Viewer reads published Client-facing facts only and no Supplier cost or margin in HTML/JSON; wrong Agency/Departure/version links rejected in Rails and SQL; Office preference grants nothing. |
| 2. Idempotency and concurrency | Same-key replay of standalone and joint Package publication returns exact versions/manifests; different payload conflicts; two racing publishers yield one result; no half-published child or success audit after failure. |
| 3. Exact history and immutability | Published Package/Service Offer definition graph, terms, prices, bindings and manifests reject INSERT/UPDATE/DELETE in Rails and PostgreSQL (M3D.7-style freeze), including after supersession/retirement. New successor is independent; old Package pin remains its exact version unless retired/materially invalid. |
| 4. Source/publication/feasibility | Only current activated M3 version and child definitions can publish. Equivalent bound successor stays eligible without rebind, material/unknown affected path blocks, cost-only and unbound change do not cause mass republication. Required paths all count; unused invalid alternative does not disable selected viable member. Capacity reads `CapacityProjection#current_supplier_capacity` and `CapacityPool#numeric_inventory?` only; M5 owns demand recheck. |
| 5. Currency and arithmetic | Client and M3 cost definition currency equal Departure operating currency; both currency-change commands respect retained M4 price rows. Explicit percentage bases, included versus additive tax, per-component `half_up` rounding, unknown cost/FX and no fabricated commission cash. Margin uses `Client revenue + expected_commission − forecast_supplier_cost`. |
| 6. Package, choices and M5 | Bundle remains one revenue source with no per-supplier allocation; service-sum retains distinct service prices and named Package adjustments; count only selected options. Service Offer choice template works both standalone and in Package and carries exact rules/options/source/terms into the M5 contract. |
| 7. Warnings versus hard checks | Draft M3 source, version integrity, currency, required unpriced choices and irreconcilable terms block publication without override. Temporary numeric shortage and unknown cost do not. Pause/resume/retire keep terms unchanged; lifecycle changes affect only applicable paths. |
| 8. System and release proof | Integrated Celebrity/Vineyard builder, local sales-window boundary, stacked Package/service limit bases (`persons` ≠ Pool `traveler_positions`), material source/ending/inactivation races, keyboard/viewports, performance, M3 regressions and full Docker/CI gate. Findings log maps every defect to retest. |

**Cross-slice lock-order check:** Verify the **implemented** A–D commands share M4A's shipped M3E order (Agency, actor, Suppliers in UUID order, Departure, Arrangement/source, then offer) wherever both domains are locked. Do not declare closure on written intent alone; prove publication-versus-successor/ending/inactivation races with multiple connections and no deadlock or stale authority.

## Performance and operational QA

- Capture bounded query counts and representative `EXPLAIN` for Departure offer list, standalone review, Package with several services/choices, and a successor comparison. Check growth with larger numbers of unrelated Items/Packages: only bound source graphs should affect one offer's compatibility query. Document fixture scale, plan/index evidence and measured counts; avoid arbitrary threshold claims without measurement.
- Verify a coherent read snapshot/time label for preview and a last-moment command recheck for publication. A stale advisory result must not claim it reserved inventory. Exercise source/supply races and error recovery; no capacity event, Client demand or M3C assumption is written by a preview.
- Test audit action/subject catalog entries and bounded details, with manifest stored separately; idempotency fingerprints/results; Rails and SQL freeze; current pointer and retired history; Departure currency guard; M3 Supplier inactivation and Arrangement ending **disclosures** without new offer blockers or mutation; no change to closed M3E.5 Needs-attention detector catalog.
- Run required repository lint, unit/integration, system, security, Tailwind/build and Docker CI at final tip after focused fixes. Record exact run links and versions; historical green runs do not substitute for final M4E evidence.

## M5 handoff contract, without M5 code

Give M5 a concrete **documented** versioned input/result mapping for standalone and Package paths: exact selected Package/Service Offer version, original immutable publication pin and compatible current M3 version/definitions, selected Client choice group and option IDs, selected Supplier alternative per required path, anonymous-to-actual quantity mapping, Client price components and rounded source lines, Client terms/acknowledgment requirements, local sales date/limit bases, and Supplier fulfillment basis. The Client Trip Service must retain the choice template and actual selection **even when no Package exists**.

Specify the M5 transactional recheck and lock-order relationship: source still equivalent/current, Departure active and within sales window, Staff Sales enabled, live capacity/limit consumption for requested quantities, material term acknowledgment, then atomic Client Trip reference issuance, allocations and **Charges currently due** at confirmation under accepted commercial authority. This is an M5 implementation requirement, not permission for M4E to insert those rows. Identify when future installments become due, how offer limits consume/release under Holds and Allocations, and the minimal M5 Charge-posting slice so the roadmap does not again claim that confirmation posts no money.

M4E creates **no** Client Trip, Hold, Allocation, Charge, or other M5/M6 rows.

## Closure criteria and documentation

M4E closes only when: all parent exit criteria and eight invariants have links to final code/system proof; the two scenario journeys use disciplined fixture labels; measured friction meets M4.0 rules or accepted findings explain improvements (observed counts published; no invented baseline); no open blocking correctness/security/data-integrity/accessibility issue remains; cross-slice races and SQL freeze have passed; M5 receives the documented exact handoff; required CI is green on merged fixes.

Then update `docs/README.md`, `AGENTS.md`, `docs/architecture/current-state.md`, `docs/terminology.md`, `docs/ui/interface-contract.md`, the M4 parent and A–E status/closure notes, roadmap, and MVP amendment references so each says what is **actually shipped**. Keep M5/M6 unimplemented and name their next accepted planning gate. Do not mark M4 complete from M4D's slice-local tests alone.

**Exit:** M4's internal selling-alpha checkpoint is evidenced and M5 can plan Client demand and atomic confirmation from exact published Client-offer authority. No M5/M6 domain record is created by this milestone closure.
