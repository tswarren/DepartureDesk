# M1E — Directory acceptance and hardening

**Status:** Shipped. Proof and hardening landed without a new domain aggregate. Composed-search `EXPLAIN` did not require an index migration. Existing `#form-error-summary` markup was proven rather than redesigned.

**Parent:** [M1 — Client and Supplier directories](m1-client-and-supplier-directories.md)

**Prerequisites:** M1A, M1B, M1C, and M1D shipped on `main`; full CI green.

**Accepted decisions (2026-09-15):** Product review adopted the proof-slice amendments: at most one preferred active destination per owner per channel, with `SetPreferredSupplierContact` remaining a separate one-per-Supplier invariant; expanded genuine concurrency and search-proof matrices; composed-query `EXPLAIN` rather than isolated-relation plans alone; a persistence exception limited to evidenced index-only forward migrations; one shared test helper with Celebrity-shaped and Vineyard-shaped datasets plus a second-Agency isolation companion; Party cleanup scoped to live code, UI, active documentation, and current test support; a 375px primary-navigation drawer keyboard contract; proof of existing `#form-error-summary` behavior rather than redesign; relative documentation links; and parent M1 terminology aligned from “scenario fixtures” to a fictional directory dataset built through commands.

## Goal

Prove that the Client and Supplier directories work together as one secure, performant, accessible milestone without adding another domain aggregate.

M1E supplies:

* Cross-directory fictional scenario builders
* Genuine multi-connection concurrency proof
* Complete search-index and bounded-query assertions
* Keyboard, responsive, validation, empty-state, and redaction system coverage
* Removal of obsolete Party-era test support from live surfaces
* Final M1 documentation and milestone status updates after proof lands

M1E does not alter the accepted directory model or add future commercial concepts. It does not authorize any new domain model, permission, reference namespace, ranking kind, duplicate signal, or lifecycle behavior.

## Required boundaries

* No new Client, Supplier, Traveler, Household, Service Provider, Departure, arrangement, or financial record.
* No Party, global person, polymorphic identity, cross-domain synchronization, or automatic merge.
* No new permissions, reference namespaces, search ranking, duplicate signals, or lifecycle semantics.
* Scenario builders exist only under `test/`; they are not production services or development seeds.
* Do not add invented people, hotels, vehicles, or Suppliers to the accepted Celebrity Beyond or Vineyard Tour scenario documents.
* M1E may add one or more indexes through a forward migration only when composed-query `EXPLAIN` evidence proves that an already-shipped search shape lacks an appropriate index. It may not add tables, columns, extensions, exclusion constraints, another `btree_gist` use, or change persisted domain shape.
* Targeted fixes to existing queries, views, test support, and accessibility behavior are permitted when required by M1 proof.
* M1E does not re-specify schema constraints, sequence exhaustion, ordinary command behavior, or sequential duplicate-token cases already shipped. Those remain regression requirements.

## Phase 1 — Test infrastructure and hygiene

Create one shared test-helper module, such as:

```text
test/test_helpers/m1_directory_scenario.rb
```

M1E creates one shared test-helper module containing two named datasets—Celebrity-shaped and Vineyard-shaped—plus a second-Agency isolation companion.

The helper should:

* Build records through shipped commands rather than bypassing command behavior.
* Keep canonical display names stable.
* Give workspace codes, emails, and other collision-sensitive values a unique per-build suffix.
* Let references come from the real command and sequence behavior.
* Return named handles through a result object instead of relying on global fixtures.
* Support transactional tests where possible.
* Support explicit cleanup for nontransactional concurrency tests.
* Never print credentials or personal data.

No Party-era vocabulary or helpers remain in production code, live UI, active documentation, or current test support. Historical ADRs and `docs/archive/` remain unchanged. Remove unused Party-era helpers from [`ApplicationSystemTestCase`](../../test/application_system_test_case.rb), including Party navigation, Party roles, and Party lifecycle helpers. Retain only helpers used by the current agency, Client, and Supplier interfaces.

## Phase 2 — Cross-directory scenarios

The Celebrity-shaped and Vineyard-shaped datasets, plus the isolation companion, are the reusable fictional directory dataset built through commands.

### Celebrity-shaped directory

Build:

* Martha Smith as a Client Person with an active Client
* Daniel and Emily as independent Client People without inferred relationships
* An AgencyUser represented separately as a Client Person, with no shared identity or synchronization
* Celebrity Cruises as an organization Supplier categorized `cruise_line`
* At least two Celebrity Supplier Locations
* Multiple Celebrity Supplier Contacts with owned email and phone destinations
* Explicit preferred Contact and primary destination selections
* A Supplier Contact sharing an email with a Client Person without linkage or duplicate warning

Preferred Contact uses `PATCH .../contacts/:supplier_contact_id/preferred`. A primary destination is the `preferred` column on that owner’s channel, selected through `POST .../set_primary`.

### Vineyard-shaped directory

Build:

* Olivia Brown as a Client Person with an active Client
* Noah Brown as a separate Client Person
* Westlake Foods as an organization-backed Client
* Current and historical Westlake organization-contact assignments
* A Vineyard Tour DMC categorized `tour_operator_dmc`
* A separate motorcoach Supplier categorized `ground_transportation`
* No Service Provider record or inferred relationship between those Suppliers

### Isolation companion

Create a second Agency containing the same normalized Client Person email and overlapping directory names.

Prove:

* No uniqueness collision
* No search result leakage
* No duplicate-candidate leakage
* Forged cross-Agency IDs return not found
* No side effect or audit is written for rejected mutations

The scenarios prove directory shape only. They must not introduce trips, Travelers, payment responsibility, occupancy, packages, or Supplier Arrangements.

## Phase 3 — Concurrency closure

Add genuine nontransactional, multi-connection tests using `Thread`, barriers, and separate Active Record connections.

Recommended file:

```text
test/services/m1_directory_concurrency_test.rb
```

Required cases:

| Race | Required invariant |
| --- | --- |
| Two individual Client creations | Distinct references; both commit |
| Same Client create-anyway token submitted twice | One result, one reference, one audit set; other outcome is replay |
| Duplicate-candidate set changed by a concurrent create | Later create receives a fresh review or a serialized valid outcome; no silent stale-token success |
| Competing Client Person destination preference changes | At most one preferred active destination per owner per channel |
| Competing Client Organization destination preference changes | At most one preferred active destination per owner per channel |
| Competing Supplier-owned destination preference changes | At most one preferred active destination per owner per channel |
| Competing Supplier Contact-owned destination preference changes | At most one preferred active destination per owner per channel |
| Two Clients for one source | Exactly one Client |
| Overlapping organization-contact assignments | At most one overlapping assignment |
| Competing organization-contact current-primary changes | At most one current primary |
| Supplier create-anyway token submitted twice | One Supplier, one reference, one audit set; other outcome is replay |
| Location create-anyway token submitted twice | One Location, one audit set; other outcome is replay |
| Supplier Contact create-anyway token submitted twice | One Contact, one audit set; other outcome is replay |
| Supplier category mutation vs inactivation | Serialized result with no lost mutation |
| Competing `SetPreferredSupplierContact` changes | At most one preferred active Supplier Contact per Supplier |
| Organization inactivation vs contact creation | No active child under an inactive Organization |
| Contact inactivation vs destination reactivation | No active destination under an inactive Contact |
| Supplier inactivation vs Location/Contact mutation | No active descendant under an inactive Supplier |

At most one preferred active destination per owner per channel. This applies independently to email, phone, postal, and website channels where supported. Destination races should be parameterized across the applicable owner/channel command families where practical. `SetPreferredSupplierContact` remains a separate invariant: at most one preferred active Supplier Contact per Supplier.

Tests should accept either legitimate lock winner where ordering is nondeterministic, while requiring the final invariant and appropriate conflict/replay outcome.

Existing sequential stale-`lock_version` tests remain regression coverage. They do not satisfy the parallel proof and must not be removed.

## Phase 4 — Search performance proof

Add a centralized search-plan suite:

```text
test/services/m1_directory_search_performance_test.rb
```

Cover every supported branch and filter:

* Client reference
* Person exact and prefix name
* Person email, E.164/suffix phone, locality and postal code
* Organization reference, exact/prefix name, email, phone, locality, postal and website
* Supplier reference, exact/prefix name, category text matching, email, phone, locality, postal and website
* Location exact/prefix name, locality and postal
* Supplier Contact exact/prefix name, email and phone
* Blank-query browse for active, inactive, and all
* Client People / Organizations / All filtering
* Supplier organization / individual filtering
* Supplier category filtering, separately from category text matching
* Over-100-character rejection without executing the directory scan
* Viewer email- and phone-shaped queries with hidden branches absent rather than merely redacted after matching
* Mixed-result deduplication and total ordering before the 51-row lookahead

For each searchable branch:

* Run representative `EXPLAIN` assertions against the composed `SearchClientDirectory` or `SearchSupplierDirectory` query, not only isolated model relations.
* Seed enough records—or disable sequential scans within the assertion—to demonstrate that the intended branch index is eligible. A sequential scan chosen merely because the test table contains a few rows is not by itself a failure.
* Assert the intended index or index family.
* Preserve best-rank deduplication before the 51-row lookahead.

Index-only migration remains allowed only under the persistence exception in Required boundaries.

Add bounded-query assertions:

* Search query count must not grow between 5 and 50 returned records.
* Directory list query count must not grow with the number of destination records.
* Profile query count may use a fixed query per child collection but must not grow per row.
* Do not assert wall-clock timing in CI.

## Phase 5 — Accessibility and system coverage

Add:

```text
test/system/m1_directory_acceptance_test.rb
test/system/m1_directory_accessibility_test.rb
```

### Keyboard workflows

Complete without pointer-specific actions:

* Create an individual Client
* Create an organization-backed Client
* Add and end an organization contact
* Create a Supplier and complete duplicate review
* Add a Supplier Location
* Add a Supplier Contact and set preferred
* Add a Contact destination and set it primary
* Inactivate a Supplier after reviewing the descendant inventory

Prove:

* Logical Tab order
* Visible focus
* Every action is reachable by keyboard
* No hover-only controls
* Native controls retain accessible names

At 375px, the existing primary-navigation drawer must also prove:

* Keyboard opening and closing
* Initial focus placement
* Focus containment while open
* Escape dismissal
* Focus restoration to the trigger
* No access to obscured page controls while open

### Viewport coverage

Run representative Client and Supplier surfaces at:

* 375px
* 768px
* 1280px
* Current 1400px reference desktop

Assert:

* No page-level horizontal overflow
* Tables use an intentional scroll region where necessary
* Actions remain reachable
* Labels remain associated with controls
* Content order remains logical after reflow

### State coverage

Demonstrate:

* First-use empty directory
* Filtered-empty results
* 50-result truncation notice
* Validation errors and preserved values
* Duplicate review, expired token and changed candidates
* Inactive records and lifecycle confirmation
* Viewer-redacted profiles and search
* Unauthorized mutation
* Cross-Agency not-found behavior

Treat the existing `#form-error-summary` behavior as something to prove. Verify focus movement, the accessible summary heading, and navigation to associated invalid fields. Redesign the markup only if that proof fails.

A new accessibility dependency is not required. Browser assertions for landmarks, labels, focus, keyboard operation, overflow, and semantic state are sufficient.

## Phase 6 — CI and documentation

Add an explicit Tailwind build to CI if it is not already run as a blocking step:

```bash
bin/rails tailwindcss:build
```

The current workflow has separate test, system-test, lint and security jobs, but no explicit Tailwind build step. See [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml).

When all proof passes, update:

* `docs/planning/m1e-directory-acceptance-and-hardening.md` — Shipped
* `docs/planning/m1-client-and-supplier-directories.md` — M1 Complete
* `docs/planning/roadmap.md` — M1 Complete; M2 next
* `docs/architecture/current-state.md`
* `docs/ui/interface-contract.md`
* `docs/terminology.md`
* `docs/README.md`
* `README.md`
* `AGENTS.md`

Do not rewrite ADRs or reference-scenario facts unless testing uncovers a genuine contradiction.

## Required proof

M1E must show:

* One shared helper containing both complete named datasets plus the isolation companion
* Client/Supplier email overlap without linking or duplicate leakage
* Same Client email in two Agencies
* Separate AgencyUser and Client Person identities
* Every required concurrent invariant using real parallel connections, including Client create-anyway replay
* At most one preferred active destination per owner per channel, and at most one preferred active Supplier Contact per Supplier
* Every supported search branch and filter using an appropriate index on the composed query
* SQL-level deduplication and 50/51 caps
* Bounded list, search and profile query counts
* Keyboard-only completion of representative workflows, including the 375px primary-navigation drawer
* Responsive behavior at all four widths
* Accessible validation, duplicate, empty, inactive and redacted states, including `#form-error-summary` proof
* No Party-era vocabulary or helpers in production code, live UI, active documentation, or current test support
* No new aggregate, extension, permission or reference namespace
* Full CI, Tailwind, security and lint checks green

## Exit gate

M1 is complete only when:

1. M1E is accepted, implemented and merged.
2. The fictional directory scenarios pass without introducing future trip concepts.
3. Concurrency, performance, accessibility, tenancy, lifecycle, audit, duplicate and reference contracts pass.
4. M1A–M1D regressions remain green.
5. Documentation consistently marks M1 complete and M2 unimplemented.
6. No Party, global consumer identity, Household, standalone Traveler, Office authorization, polymorphic identity, automatic merge or cross-domain synchronization has returned.

This slice is **Shipped**. It does not authorize M2 or any new directory model, permission, reference namespace, ranking kind, duplicate signal, or lifecycle behavior.
