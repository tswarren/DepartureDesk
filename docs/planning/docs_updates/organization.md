Yes. The main problem is that the documents currently mix four different jobs:

1. describing what the product means;
2. recording what has shipped;
3. authorizing the next implementation;
4. exploring ideas that are not yet decisions.

Organize by authority and lifecycle first, then by milestone.

## 1. Establish four document classes

Every planning document should belong to exactly one class.

| Class | Purpose | Typical status |
|---|---|---|
| Product authority | Durable business and architecture decisions | Accepted |
| Milestone contract | Defines a broad outcome and sequencing | Accepted / Complete |
| Slice contract | Authorizes a specific implementation | Draft → Accepted → Shipped |
| Discovery/history | Explores options or preserves superseded decisions | Draft / Superseded / Archived |

A document should not simultaneously be an active draft, the implementation authority, and the historical record of what shipped.

## 2. Standardize status vocabulary

Use only these statuses:

- **Draft** — under discussion; no implementation authority.
- **Accepted** — approved implementation authority; code may begin.
- **Shipped** — accepted behavior merged and verified.
- **Superseded** — replaced by a named newer document.
- **Historical** — retained context; never implementation authority.
- **Complete** — reserved for a parent milestone whose required slices shipped.

Avoid combinations like “Accepted and Shipped with this PR.” During the implementation PR, keep the plan **Accepted**. Mark it **Shipped** only after the green merge is known.

Every document should begin with a compact header:

```markdown
**Status:** Accepted 2026-09-25. Not shipped.
**Authority for:** M4D.1 Slice 3R only.
**Parent:** [M4D.1](...)
**Supersedes:** [earlier draft](...)
**Implementation prerequisite:** Slice 2D shipped at `dc272a3`.
**Next unauthorized boundary:** Slice 3A.
```

For shipped work:

```markdown
**Status:** Shipped 2026-09-25.
**Merge:** `abc1234`, PR #157.
**Authority for:** M4D.1 Slice 3R decisions.
```

## 3. Make one status index authoritative

Use `docs/README.md` as the human-readable authority map, but keep it concise.

Do not repeat the entire milestone history in every index. Use one row per current authority:

| Milestone | State | Current authority | Next work |
|---|---|---|---|
| M1 | Complete | M1 parent and shipped slices | None |
| M2 | Complete | M2 parent and shipped slices | None |
| M3 | Complete | M3 parent through M3F | None |
| M4 core | Shipped through M4D.0 | M4A–M4D.0 | M4E later |
| M4D.1 Cruise | Shipped through Slice 2D | Slice 2A–2D contracts | Closed |
| M4D.1 adapters | Discovery | Slice 3R | Hotel decisions |
| M5 | Planned | No accepted slice | Client Trip discovery |

Then let `roadmap.md` describe sequencing rather than duplicating detailed status prose.

## 4. Close Slice 2D before reorganizing Slice 3

First make the repository tell the truth about completed Cruise work.

Update Slice 2D to:

```markdown
**Status:** Shipped 2026-09-24.
**Merge:** `dc272a3`, PR #154.
```

Update the status references in:

- `AGENTS.md`
- `docs/README.md`
- `docs/architecture/current-state.md`
- `docs/terminology.md`
- `docs/planning/roadmap.md`
- `docs/planning/m4-offers-and-pricing.md`
- `docs/planning/m4d1-departure-composition-workspace.md`
- `docs/planning/drafts/README.md`

Do this as a small closure PR. Do not mix it with the Slice 3 redesign.

## 5. Replace “Slice 3” with a decision gate

The current Slice 3 concept is too broad to remain one implementation authority. Make the next document:

```text
M4D.1 Slice 3R — Non-Cruise Adapter Boundary and Delivery Contract
```

Its purpose is not to implement adapters. It should decide:

- what belongs to Supplier Composition;
- what belongs to Offer Design;
- what belongs to Client Trips;
- which family comes first;
- what may be shared;
- when shared code is permitted;
- what each family must prove through the browser.

The Slice 3R exit should be approved contracts for Hotel and Transportation—not application code.

## 6. Give each vertical its own contract

Recommended sequence:

| Slice | Purpose |
|---|---|
| 3R | Boundary and delivery decisions |
| 3A | Hotel Supplier workflow |
| 3B | Transportation Supplier workflow |
| 3C | Shared support proven by 3A and 3B |
| 3D | Activity/Meal/Excursion workflow |
| 3E | Mixed-DMC routing and integrated proof |

This prevents one plan from mixing dozens of screens, commands, fixtures, and semantic decisions.

Each vertical contract should contain the same sections:

1. Outcome
2. Canonical fixture
3. Staff journey
4. Durable record mapping
5. Screen hierarchy
6. Save boundaries
7. Compatibility detection
8. Lifecycle behavior
9. Advanced fallback
10. Proof
11. Non-goals
12. Locked decisions

Your Hilton walkthrough already follows most of this structure.

## 7. Separate the Hilton decision vehicle from its implementation plan

The Hilton walkthrough should answer product and semantic questions:

- What does Staff enter?
- What does each value mean?
- What gets shown after saving?
- Which stable identity is retained?
- What dependencies affect edits/removal?
- What browser journey proves completion?

It should not prematurely lock Ruby service names unless code inspection proves them.

For example:

```markdown
### Write authority

An accepted Hotel orchestration command must atomically create the
Arrangement Item and supported stay Occurrence through shipped M3
authority.

The implementation plan must name the exact command after inspecting
the available public command surface.
```

Once the walkthrough is accepted, create a shorter implementation plan that names:

- exact command classes;
- exact routes;
- exact controllers;
- transactions and lock order;
- migrations, if any;
- files expected to change;
- focused tests;
- delivery order.

That keeps product decisions from becoming cluttered with replaceable implementation details.

## 8. Correct the Hilton boundary before accepting it

The edited walkthrough still contains the earlier combined Supplier/Client model. Revise it before promotion.

Remove from the Slice 3A fixture:

```text
Client-offer treatment: Optional add-on
```

Remove or defer:

- the “Client choices” fixture section;
- “Standard and Deluxe become Client choices”;
- `hotel_room:` keys;
- Package/add-on treatment;
- Client pricing readiness;
- the requirement to exercise all Service connection modes.

Replace Step 14 with a smaller handoff:

```markdown
## Step 14 — Review the Offer Design handoff

### Staff question

> Should this Hotel stay be made available for later Client-offer design?

Slice 3A may expose a nonblocking “Open in Offer Design” or
“Connect service” handoff. Hotel Supplier setup does not decide whether
the stay is included, optional, standalone, or selected by a Client.
```

If you retain connection in 3A, limit the saved summary to:

```text
Client service
Pre-cruise hotel · Connected
Client pricing not configured
Package placement not configured
Open in Offer Design
```

Do not describe it as an optional add-on.

## 9. Create an explicit layer map

Place a short boundary table in Slice 3R and link to it from every vertical:

| Layer | Owns |
|---|---|
| Supplier Composition | Arrangement, Items, occurrences, resources, capacity, Supplier costs, deposits, deadlines, activation |
| Offer Design | Service Offers, choices, Client prices, Client terms, Package placement, publication |
| Client Trip | Actual package/add-on selections, travelers, quantities, Holds, Allocations, Charges |

Then apply a simple test to every proposed field:

> Is this a fact about what the Supplier contracted, what the Agency intends to sell, or what this Client actually selected?

That determines which layer owns it.

## 10. Create a “current authority” folder convention

I would retain the existing broad structure but tighten it:

```text
docs/
  planning/
    roadmap.md
    commercial-domain-decision-register.md

    m4d1-departure-composition-workspace.md
    m4d1-slice2d-cruise-client-terms-and-scenario-review.md

    decisions/
      m4d1-slice3r-adapter-boundary.md
      m4d1-slice3r-hilton-walkthrough.md
      m4d1-slice3r-transportation-walkthrough.md

    drafts/
      README.md
      ...

    history/
      m4d1-slice3-original-adapter-contract.md
```

If adding folders would create too much link churn, keep the current flat layout and use filename conventions:

```text
m4d1-slice3r-adapter-boundary.md
m4d1-slice3r-hilton-walkthrough.md
m4d1-slice3a-hotel-supplier-workspace.md
```

The consistency matters more than the directories.

## 11. Reduce duplicated status prose

Currently, status details are copied into:

- `AGENTS.md`
- `docs/README.md`
- `roadmap.md`
- parent plans;
- slice plans;
- terminology;
- current-state documentation;
- drafts indexes.

Give each one a narrower job:

- `AGENTS.md`: concise shipped boundary and implementation prohibitions.
- `docs/README.md`: document authority index.
- `roadmap.md`: milestone sequence and gates.
- `architecture/current-state.md`: what code and persistence actually exist.
- parent plan: intended milestone behavior and slice structure.
- slice plan: exact implementation authority.
- `terminology.md`: vocabulary only.
- `drafts/README.md`: active drafts and their successors.

Do not put detailed PR histories in `terminology.md` or long delivery narratives in `AGENTS.md`.

## 12. Add a planning checklist

Before accepting any new slice, require:

- [ ] Parent authority named.
- [ ] Status is exactly Draft or Accepted.
- [ ] Shipped prerequisite pinned.
- [ ] Product layer identified.
- [ ] Staff journey written.
- [ ] Durable meanings identified.
- [ ] Existing write authorities inspected.
- [ ] Stable IDs named.
- [ ] Summary sentences specified.
- [ ] Lifecycle behavior specified.
- [ ] Unsupported graph behavior specified.
- [ ] At least one multi-record browser proof specified.
- [ ] Client pricing/Package/Trip boundaries explicit.
- [ ] Exact non-goals included.
- [ ] Indexes updated only when authority changes.

## Practical sequence

I would handle the reorganization in four small PRs:

1. **Documentation truth pass**  
   Mark Slice 2D shipped and reconcile status indexes.

2. **Slice 3 reset**  
   Mark the original Slice 3 contract/prototype superseded or withdrawn. Amend the parent so it no longer promises `ConnectTypedItemService`.

3. **Slice 3R decisions**  
   Accept the three-layer boundary and delivery sequence.

4. **Hotel contract**  
   Revise and accept the Hilton walkthrough, then derive the narrow 3A implementation plan.

That gives you a clean point where Cruise is closed, the old Slice 3 attempt is preserved as history, and Hotel becomes the only active implementation target.