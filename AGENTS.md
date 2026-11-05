# AGENTS.md

This file is the repository contract for coding agents and automated contributors working on DepartureDesk. It applies to the entire repository unless a more specific `AGENTS.md` exists in a subdirectory.

## Mission

DepartureDesk helps travel agencies operate and account for group travel. It must preserve the real distinctions among supplier commitments, client sales, travelers, shared accommodations, payment responsibility, receipts, and supplier settlement.

The application should feel operationally calm, financially trustworthy, and travel-oriented without becoming recreational or decorative.

## Current boundary

Product authority is the [Product Specification](docs/spec/README.md). Its master copy is a Google Doc; `docs/spec/product-specification.md` is a read-only snapshot. Scope is set by the [first-slice charter](docs/planning/first-slice/first-slice-charter.md). Standing is the [planning index](docs/planning/README.md). Documentation authority is indexed in [docs/README.md](docs/README.md).

- Implement only work the active charter places in scope. An Agreed rule in the specification that the charter does not cite is out of scope. Adding scope needs a decision log entry that names the charter.
- Phase 0 closed 2026-11-03 and Phase 1 (Prepare) closed 2026-11-04 (planning index). Slice 1 is active: build its steps in charter order, one pull request per step or case. Remaining open decisions are in [pending decision log entries](docs/spec/pending-decision-log-entries.md); do not resolve them in code.
- Agency identity, the client and supplier directories (M1) and Departures (M2) are kept and built on (D-65). The shipped M3 and M4 layers, including the Cruise, Hotel, Transportation and Activity workflows, were deleted in charter Phase 1 (D-66). Tag `pre-m3-m4-deletion` holds the last commit that has them; Slice 1 step 3 restores the capacity replay and projection code from it ([ADR 0018](docs/adr/0018-arrangement-history-by-dated-adjustment.md) spike amendment). Do not restore anything else from that tag.
- M4E, M5–M8, Cruise document storage and the old Supplier Composition slice plans authorize nothing. Unmerged branch `m4d1-slice3-hotel-transport-activity` and PR #156 are not an implementation source.
- Do not implement MFA, platform access grants, offices as anything beyond today's behavior, passports or other sensitive traveler fields, email sending, FX, or a Travel Program until the charter names that work.
- The [MVP requirements](docs/planning/departure-desk-mvp.md), [Commercial Domain Decision Register](docs/planning/commercial-domain-decision-register.md) and [roadmap](docs/planning/roadmap.md) are Superseded. Do not implement from them.
- [docs/terminology.md](docs/terminology.md) records the shipped vocabulary. For new work, use the specification's glossary. Where they differ, the glossary wins for new code; do not rename shipped code outside a charter step.

There is no migration path from the Party and membership schema. Do not add a compatibility layer, dual-schema period, or upgrade of a Party database.

## Working rules for the first slice

- One pull request per charter step or demonstration case. The description cites the rule IDs and case IDs it implements.
- The specification changes before the code does. If code needs a rule the spec lacks or contradicts, stop and request a decision log entry. Never copy rule text into code comments or docs; cite the ID.
- Only one slice is active at a time. A need found during the build goes to the backlog with the rule ID it touches.
- Follow the charter's [technical baseline](docs/planning/first-slice/first-slice-charter.md#technical-baseline). Where it is stricter than a section below, it wins for new code.
- Each demonstration case (D1–D17) is an automated end-to-end test named by its ID, run against the Alpha fixture loaded from one seed script, with an injectable clock.
- New domain code reads the time from `Clock.current` (`lib/clock.rb`), not `Time.current`, `Time.now` or `Date.today`. Tests fix it with `set_clock`, which resets after each test. Shipped code moves to the clock only when a charter step touches it.
- Every first-slice screen meets the charter's [UI acceptance](docs/planning/first-slice/first-slice-charter.md#ui-acceptance) standards at desktop width and 375px before its step is done.

## Architecture decisions

Accepted ADRs under `docs/adr` are authoritative for the technical decisions they record, unless a decision log entry or a later ADR supersedes them. Read the relevant ADR before designing or changing its domain. ADRs 0016 to 0018 record the charter's Phase 0 code conflicts. They govern new work from Slice 1 step 1 onward. Until a Slice 1 step implements them, the shipped code follows the ADRs they supersede.

- [ADR 0001: Money and currency representation](docs/adr/0001-money-and-currency.md) accepts `money-rails`, `bigint` minor-unit persistence, explicit currencies, strict parsing, and explicit historical conversion facts. The gem is installed. [M3C](docs/planning/m3-supplier-planning/m3c-cost-terms-and-forecasts.md) shipped the first draft Supplier cost monetary tables; posted client/supplier ledgers, Obligations, and Payments are not shipped. Do not persist functional-currency translations. The MVP commercial contract later limits each Departure to one operating currency and excludes FX.
- [ADR 0005: Agency identity](docs/adr/0005-agency-identity.md) is the tenancy, invitation, session, permission, and office-context contract, as amended by ADR 0016 (one agency time zone, optional offices) and ADR 0017 (user types and per-user permissions). Implement it with those amendments. Do not invent alternatives.
- [ADR 0006: Separate identity domains](docs/adr/0006-separate-identity-domains.md) rejects a universal Party identity and separates AgencyUser, Client, Supplier, and Traveler contexts. It is an accepted future-domain boundary, not permission to implement those records before an accepted slice.
- [ADR 0007: Departure as operational root](docs/adr/0007-departure-operational-root.md) accepts Departure as the dated operational root and defers Travel Program. Do not add a Travel Program table, route, model, or foreign key until a later accepted slice names that work.
- [ADR 0008: Supplier Arrangement version topology](docs/adr/0008-supplier-arrangement-version-topology.md) accepts stable Arrangement and child identities with per-version definitions. M3A draft topology is implemented; activation and successor behavior are shipped with M3D; [M3D.7](docs/planning/m3-supplier-planning/m3d7-activated-definition-immutability.md) freezes exact-version definition graphs after leaving draft. **Its code was deleted in charter Phase 1 (D-66)**; for new work, ADR 0018 governs.
- [ADR 0009: Supplier contracting and service-provider roles](docs/adr/0009-supplier-contracting-and-service-provider-roles.md) accepts contracting Supplier, computed Service Provider, Arrangement contact, and inactivation-dependency meanings. M3A Supplier-role behavior is implemented; later dependency extensions are deferred. **Its code was deleted in charter Phase 1 (D-66)**; for new work, ADR 0018 governs.
- [ADR 0010: Supplier capacity ledger and projection](docs/adr/0010-supplier-capacity-ledger-and-projection.md) accepts stable Capacity Pool identity, immutable capacity events, scheduled effectiveness, reconciliation, and rebuildable projections. [M3B](docs/planning/m3-supplier-planning/m3b-supplier-capacity.md) shipped the implementing persistence and engine; Arrangement activation and Staff event UI are shipped with M3D. **Its code was deleted in charter Phase 1 (D-66)**; for new work, ADR 0018 governs.
- [ADR 0011: Supplier cost definitions and forecast evaluation](docs/adr/0011-supplier-cost-definitions-and-forecast-evaluation.md) accepts exact-version cost sources, staged definitions, constrained components, planning assumptions, and derived forecasts. [M3C](docs/planning/m3-supplier-planning/m3c-cost-terms-and-forecasts.md) shipped the implementing slice; Arrangement activation and effective contracted terms are shipped with M3D. **Its code was deleted in charter Phase 1 (D-66)**; for new work, ADR 0018 governs.
- [ADR 0012: Arrangement activation, Reservations, and confirmations](docs/adr/0012-arrangement-activation-reservations-and-confirmations.md) accepts activation manifests, successor copying, Reservation history, confirmation evidence, and the M3D confirmation-triggered commitment core. [M3D](docs/planning/m3-supplier-planning/m3d-activation-reservations-confirmations.md) ships the implementing slice after shipped [M3D.0](docs/planning/m3-supplier-planning/m3d0-planning-workspace-compression.md). A 2026-09-18 supersession note records that [ADR 0013](docs/adr/0013-supplier-operational-commitments-deadlines-exposure-and-ending.md) supersedes “manual opening” and every-row inactivation wording for post-M3E behavior. **Its code was deleted in charter Phase 1 (D-66)**; for new work, ADR 0018 governs.
- [ADR 0013: Supplier operational commitments, Deadlines, exposure, and Arrangement ending](docs/adr/0013-supplier-operational-commitments-deadlines-exposure-and-ending.md) accepts source-shaped commitment openings and dispositions, Deposit Requirements, Deadlines, planning milestones, exposure, Needs attention, and Arrangement ending. [M3E](docs/planning/m3-supplier-planning/m3e-supplier-operational-control.md) is the shipped implementing slice (M3E.1–M3E.7b). **Its code was deleted in charter Phase 1 (D-66)**; for new work, ADR 0018 governs.
- [ADR 0014: Client offers, publication, and Supplier-source compatibility](docs/adr/0014-client-offers-publication-and-supply-compatibility.md) accepts Service Offer and Package identity, publication, activated-only M3 pins, Sales enabled versus computed eligibility, and the M5 Charge-posting handoff. [M4A](docs/planning/m4-offers-and-pricing/m4a-service-definitions-and-sources.md) ships unpublished drafts and source compatibility. [M4B](docs/planning/m4-offers-and-pricing/m4b-client-pricing-and-anonymous-preview.md) ships unpublished Client prices, the anonymous calculator, and optional indicative scenario economics. They are not implementation authority for later slices. [M4.0](docs/planning/m4-offers-and-pricing/m40-task-flow-and-contract.md) is the accepted task-flow gate. [M4C](docs/planning/m4-offers-and-pricing/m4c-packages-choices-and-client-terms.md) is shipped (unpublished Package drafts, package-only version ownership, choice templates, and Client terms). [M4D](docs/planning/m4-offers-and-pricing/m4d-publication-and-live-feasibility.md) is shipped (publication, Sales enabled, live feasibility, and M3 disclosure previews). [M4D.0](docs/planning/m4-offers-and-pricing/m4d0-narrow-group-departure-builder.md) and [M4D.0R](docs/planning/m4-offers-and-pricing/m4d0r-builder-interface-remediation.md) are shipped (M4D.0R interim UI). [M4D.1](docs/planning/m4-offers-and-pricing/m4d1-departure-composition-workspace.md) is Accepted; [Slice 1](docs/planning/m4-offers-and-pricing/m4d1-slice1-workspace-foundation.md) is shipped. [Slice 2A.1](docs/planning/m4-offers-and-pricing/m4d1-slice2a1-cruise-sailing-and-cabin-inventory.md) is shipped. [Slice 2A.2](docs/planning/m4-offers-and-pricing/m4d1-slice2a2-cruise-supplier-rates-and-occupancy-totals.md) is shipped. [Slice 2A.2R](docs/planning/m4-offers-and-pricing/m4d1-slice2a2r-cruise-supplier-rate-matrix.md) is shipped. Later sub-slices may amend this ADR for choice-rate linkage or Client price provenance—this ADR is not implementation authority for those until amended with the implementing slice. Do not implement M4E until an accepted plan names that work. Standing is the [planning index](docs/planning/README.md). **Its code was deleted in charter Phase 1 (D-66)**; for new work, ADR 0018 governs.
- [ADR 0015: Supplier agreement operational modeling boundary](docs/adr/0015-supplier-agreement-operational-boundary.md) accepts four Supplier-information classes. Operational definitions are facts DepartureDesk uses now. Contractual definitions require the present-domain-integrity test in that ADR. Agreement reference is version-owned wording. The [Supplier complexity rebaseline](docs/planning/m4-offers-and-pricing/supplier-complexity-rebaseline.md) is shipped: `SupplierDepositBasis`, structured Hotel attrition, and the structured deposit-refund clarification are `SupplierAgreementReference` rows of kind `deposit_derivation`, `attrition`, and `deposit_refund`. Fixed Deposit Requirements stay operational. `refund_due_on` is not a Deadline. This ADR does not authorize document storage. **Its code was deleted in charter Phase 1 (D-66)**; for new work, ADR 0018 governs.
- [ADR 0016: Agency time zone and optional offices](docs/adr/0016-agency-time-zone-and-optional-offices.md) supersedes ADR 0005's office time zones and required offices. One agency time zone; offices are optional and grant nothing.
- [ADR 0017: User types, per-user permissions and reseller users](docs/adr/0017-user-types-permissions-and-reseller-users.md) supersedes ADR 0005's roles. `agency_admin`, `staff` and `reseller` user types, five per-user grants, one action catalog, and a deny-by-default reseller scope.
- [ADR 0018: Supplier arrangement history by dated adjustment](docs/adr/0018-arrangement-history-by-dated-adjustment.md) supersedes ADRs 0008 and 0011–0013, and parts of 0010, for the new supplier layer. Do not build new features on the superseded ADRs; they govern shipped code until charter Phase 1 deletes it (D-66).
- [ADR 0019: Issued document storage](docs/adr/0019-issued-document-storage.md) renders issued documents once and stores them as immutable `document_versions` rows with the PDF in Active Storage. Active Storage framework routes stay off; every download goes through an authorized controller.
- [ADR 0002](docs/adr/0002-agency-tenancy-and-membership.md) and [ADR 0003](docs/adr/0003-membership-lifecycle-and-invitations.md) are **Superseded by ADR 0005**. Do not implement them.

## Canonical domain language

Use these terms consistently in code, migrations, UI labels, tests, and documentation.

The table and paragraph below describe shipped vocabulary. Slice 1 step 1 applied ADR 0016 to the Office and Current office rows and ADR 0017 to the Agency user row. The M3 and M4 vocabulary was deleted with those layers in Phase 1. For new work, the specification's glossary wins.

| Term | Contract |
| --- | --- |
| Agency | The travel agency using DepartureDesk and owning operational records. Agency is the tenant. Status is `active`, `suspended`, or `closed`. |
| Workspace code | The immutable, globally unique sign-in key for an agency. Stored already normalized. Request `agency_id` never establishes tenancy. |
| Agency time zone | `Agency.default_timezone`, the one IANA zone for the agency. Offices carry none (ADR 0016). |
| Office | An optional agency-owned record for assignment, filtering and reporting. It is not an authorization grant and not a tenant. An agency may have none. Do not use `Branch`. |
| Agency user | An account that belongs to exactly one agency. The same email in two agencies is two accounts. Its user type is exactly `agency_admin`, `staff` or `reseller` (ADR 0017). |
| Permission | One of five per-user grants a staff user may hold: `departure_management`, `supplier_arrangements`, `financial_records`, `passport_access`, `reseller_relationships`. An Agency Admin holds all five without stored grants. |
| Reseller | A reseller relationship. A `reseller` user belongs to exactly one. Schema only until Slice 1 step 9. |
| Relationship | A descriptive string on an agency user. It does not grant access. |
| Session | Authentication root. It derives its agency through the agency user and does not store `agency_id`. |
| Current office | A session preference, then the user's default office, then nil. Changing it changes no permission. |

Client Person, Client Organization, Client (person-backed or organization-backed), person-owned and organization-owned contact points, organization-contact assignments, Supplier, Supplier categories, Supplier-owned contact points, Supplier Location, Supplier Contact, and Supplier Contact-owned email and phone destinations are shipped vocabulary. Departure draft, activation, reference issuance, return to draft, departed, and schedule/currency/lifecycle correction are shipped vocabulary.

## Invariants agents must preserve

These describe shipped behavior. A charter step may change one only through a decision log entry and, where an ADR governs it, a superseding ADR, in the same pull request as the change. Slice 1 step 1 changed invariants 5 to 7, 10, 11 and 15 under ADRs 0016 and 0017.

1. Sign-in looks up the agency by normalized workspace code before email or password lookup.
2. Missing workspace, unknown email, bad password, and inactive user or agency return the same generic failure.
3. Sign-in and password-reset rate limits use client IP plus normalized workspace code plus normalized email, not IP alone.
4. An agency user belongs to exactly one agency. Passwords and sessions are not shared across agencies.
5. Application code checks the action catalog (`AccessPermission::CATALOG`), not user types or grant names. Each action requires `baseline`, `admin_only`, a permission, any of several permissions, or `reseller`. An action not in the catalog is refused.
6. Staff hold the baseline actions plus the permissions granted to them. Only an Agency Admin manages users, permissions, offices, traveler types and the agency profile, and only an Agency Admin grants or revokes a permission. A `reseller` user satisfies no staff requirement. Grants exist only for `staff` users; the database refuses any other, and a type change removes grants first in the same transaction.
7. Only an active `agency_admin` counts. Suspend, close, and demotion of the last active Agency Admin are rejected after locking the agency, then the user, then rechecking the count.
8. Suspending or closing an agency or agency user destroys affected session rows. A stale cookie is rejected and cleared only when that browser presents it.
9. Invitation and password-reset tokens are stored as digests. Replacement and revocation invalidate the previous invitation token. Password change or reset bumps the credential version and destroys that user's sessions. A password-reset token cannot be used unless the agency is active.
10. An agency may have zero offices. `ProvisionAgency` creates none, and `Current.office` is then nil. Commands must not require an office; a Departure activates without a responsible office. Offices carry no time zone.
11. Office selection writes only the session preference, a display default. A query parameter never authorizes and never selects an office on GET. Office selection never scopes a query for access.
12. Load tenant records through `Current.agency`. An identifier from another agency returns not found, not forbidden.
13. Tenant records that carry `agency_id` must prove same-agency foreign keys. Default office uses a composite foreign key `(default_office_id, agency_id)`. Database triggers reject changes to `Agency.workspace_code`, `AgencyUser.agency_id`, `Office.agency_id`, and `Office.code`. Stored email must equal `lower(btrim(email_address))`.
14. `ProvisionAgency` and agency lifecycle changes are privileged. They require an actor identifier, invent no platform user, and never return or log a plaintext password or token.
15. Audit successful administrative commands in the same transaction. Subjects are `Agency`, `AgencyUser`, `Office`, `ClientPerson`, `Client`, `ClientOrganization`, `Supplier`, `SupplierLocation`, `SupplierContact`, `Departure` and `TravelerType` only. Do not audit expected failures.
16. Do not infer household, payer, occupancy, or payment state. Those records do not exist yet.

## Development environment

Development is Docker-only. Do not instruct contributors to install or run host Ruby, Rails, Bundler, PostgreSQL, or Tailwind.

Primary commands:

```bash
docker compose up --build
./dev/rails-docker bin/rails test
./dev/rails-docker bin/rails console
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails tailwindcss:build
```

Services:

- `web`: Rails server.
- `css`: Tailwind watcher; must run for styled development pages.
- `jobs`: Solid Queue worker.
- `db`: PostgreSQL 18.

When diagnosing a container failure, identify the first application error. Do not treat Docker Desktop suggestions such as Gordon as part of the Rails failure.

After checking out this identity baseline, recreate the primary development and test databases. Do not migrate a Party or membership database forward.

## Rails conventions

- Follow Rails 8.1 conventions and prefer framework capabilities already present.
- Use Active Record associations and validations for developer ergonomics, plus database constraints for durable invariants.
- Keep controllers focused on HTTP concerns.
- Put multi-record business workflows in clearly named service or command objects once controller/model callbacks would obscure transaction boundaries.
- Use transactions when an operation must update multiple durable facts atomically.
- Avoid callbacks for financial posting, payment application, or supplier commitment workflows.
- Normalize values at explicit boundaries. Do not use presentation formatting as normalization.
- Prevent N+1 queries on operational lists and dashboards.
- Use optimistic locking on mutable operational aggregates where concurrent edits matter.
- Prefer explicit enums or constrained string states whose values remain readable in SQL.
- Do not add gems when Rails or an existing dependency reasonably handles the need.
- `money-rails` is an explicitly accepted exception governed by ADR 0001; do not substitute a different money library without superseding that ADR.
- Do not use the countries gem as a currency authority.

## PostgreSQL and Active Record

- PostgreSQL 18 is authoritative. Do not reduce the design to cross-database compatibility.
- `config.active_record.schema_format` is `:sql`; commit updated `db/structure.sql` after migrations.
- The identity baseline does not enable `citext` or `pg_trgm`. Enforce workspace-code and email uniqueness on normalized text columns. `btree_gist` is enabled on the primary database only for the named Client Organization contact-history exclusion `client_org_contacts_no_overlapping_history`. Do not add other `btree_gist` uses, and do not enable that extension in the queue database. Do not enable `citext` or `pg_trgm` for directory work.
- Application-owned durable tables use UUID primary keys with database defaults of `uuidv7()`.
- When an ID is needed before persistence, assign UUIDv7 in Rails and retain the database default as a safety net.
- Every UUID foreign key must declare `type: :uuid` in its migration.
- Framework-owned tables such as Solid Queue and Active Storage internals may keep their own identifier conventions. Generate Active Storage so attachments can reference UUID records, and use it only under [ADR 0019](docs/adr/0019-issued-document-storage.md).
- Rails operates timestamps in UTC; domain timestamps use PostgreSQL `timestamptz`.
- Store an agency’s display/business timezone as a recognized IANA timezone.
- Currency codes are uppercase three-character values.
- Store money in `bigint` integer minor-unit columns using the `_minor_units` suffix, with an explicit currency for every independently meaningful monetary fact.
- Never use floating-point columns for money, rates that post money, or allocations.
- Use decimal/numeric values only where fractional quantities or exchange rates require them, with explicit precision and scale.
- Add `null`, foreign-key, unique, check, and exclusion constraints as appropriate. Model validation alone is insufficient.
- Name important constraints and indexes so failures are diagnosable.

### Multiple databases

The application database and Solid Queue database are separate.

- Development primary: `departure_desk_development`.
- Development queue: `departure_desk_development_queue`.
- Production uses `DATABASE_URL` and `QUEUE_DATABASE_URL`.
- Development must configure `config.solid_queue.connects_to = { database: { writing: :queue } }`.
- Do not put a single shared `DATABASE_URL` into the default development database anchor; that can redirect both named connections to one database.
- Queue structure belongs in `db/queue_structure.sql`.

Do not “fix” missing queue tables by adding Solid Queue tables to the primary domain schema. Confirm the active connection and initialize the queue database instead.

## Identifier policy

Application domain models currently inherit Rails-side UUIDv7 preassignment from `ApplicationRecord`. Before introducing or retaining any application-owned bigint model, resolve that mismatch explicitly. Never let a UUID default write into a bigint primary key.

For migrations:

```ruby
create_table :example_records,
 id: :uuid,
 default: -> { "uuidv7()" } do |table|
 # ...
end
```

For references:

```ruby
table.references :agency,
 null: false,
 type: :uuid,
 foreign_key: true
```

## Migration policy

- Inspect both migrations and `db/structure.sql` before changing persistence.
- Prefer a new forward migration once a migration has been shared or run outside a disposable local environment.
- The agency-identity baseline replaced the Party migrations. Do not stack drop-table migrations on that old schema.
- Never drop, reset, or recreate a database without stating exactly which database and data will be lost.
- Never edit generated structure SQL by hand to work around a migration problem.
- Verify migrations against both development and test databases.
- Preserve unrelated user data and existing worktree changes.

## Financial design

No posted money ledger or money amounts exist in the shipped application. When later slices add client charges and supplier obligations, keep those facts distinct, store integer minor units, and do not persist functional-currency translations until ADR 0001 is amended. `money-rails` is a value-object layer only.

## Authentication and tenancy

- Authentication uses `AgencyUser`, `Session`, bcrypt, and a signed permanent session cookie.
- Tenant context is the session's agency user. `Current.session` is the authentication root. `Current.agency` comes from that user. Never establish tenancy from `params[:agency_id]`, headers, or extra cookies.
- `Current.office` is subordinate context. It is resolved, without writing the session, from a valid stored `office_id`, else the user's active default office, else nil. Never authorize from `params[:office_id]`, and do not persist or clear a session office selection on GET.
- Login and every authenticated request fail closed when the user or agency is not active. Do not reveal whether the workspace, email, password, user, or agency failed.
- Successful authentication redirects through the named root route; keep `root_url` available unless authentication behavior is intentionally changed.
- Do not expose whether an email address exists during password-reset flows.
- Never log plaintext passwords, tokens, payment credentials, or other sensitive information.
- The current seed credential is development-only and must not be printed.
- Agency Admin capabilities are catalog checks on the agency user, not a property on a global user.
- Agency Admins may edit the current agency profile, offices, traveler types, agency users and their permissions. They may not create agencies or change agency lifecycle status from a tenant route.
- Invitations offer `agency_admin` or `staff`. Reseller invitations wait for Slice 1 step 9.
- Invitation acceptance is the documented invitee exception: the invitee is the audit actor and is not yet an Agency Admin until acceptance commits.
- Last-Agency-Admin mutations lock agency, then the affected user, then recheck.
- Agency provisioning and lifecycle are privileged commands (`ProvisionAgency`, `ChangeAgencyStatus`), not tenant-facing routes. System audit events require `actor_identifier` and must not invent a platform user. Command output may print identifiers only—never passwords or invitation tokens.
- Audit subjects are narrowly typed: an `Agency` subject must equal the event agency; any other subject must belong to it. Unknown subject types raise.
- An office belongs to exactly one agency. Office access is not a permission. Do not create affiliation rows. Human-readable office codes never authorize.
- Later office-owned records must carry a direct `agency_id` and enforce matching `(office_id, agency_id)` with a composite foreign key. Do not infer tenant ownership only through `office_id`.
- `AuditEvent::ACTIONS` and subject types are closed catalogs. Extend both in the same change that first writes a new supported action or subject. `AuditEvent#details` is not a document-version or snapshot store.
- Administrative mutations write append-only `AuditEvent` records in the same transaction. Audit events reject update and destroy in the application and in PostgreSQL.
- Business records must be loaded through `Current.agency`. Do not use a tenant `default_scope`.
- Action Cable identifies `current_agency_user` and `current_agency` from the session. It must not copy request `Current` onto a long-lived connection and must not persist `Current.office` on the connection.
- Jobs that need office scope accept an office identifier, reload the office through the agency, and re-check that it is an active office of that agency. Office context is not authorization.

## Tests

Every behavior change requires focused automated coverage at the lowest useful level and integration coverage for important workflows.

Run:

```bash
./dev/rails-docker bin/rails test
```

Also run system tests for browser-visible workflows. The development image includes Chromium, so `./dev/rails-docker bin/rails test:system` and `bin/ci` run them locally. GitHub CI system tests remain required and blocking. `bin/rails tailwindcss:build` is a blocking step in the GitHub `test` and `system-test` jobs and in `bin/ci`.

Testing rules:

- Test database constraints as well as model validations for important invariants.
- Test cross-agency authorization whenever agency-scoped records are introduced. Other-agency identifiers return not found, not forbidden.
- Test successful, invalid, duplicate, and concurrent paths for identity workflows, including last-administrator protection.
- Fixtures must satisfy column limits and database constraints. Because Rails may load all fixtures before every test, one invalid fixture can break unrelated tests before assertions run.
- Avoid assertions tied only to CSS implementation details; assert accessible roles, labels, visible states, and outcomes.
- Do not weaken or delete a regression test merely to make a change pass.

## UI and design system

The canonical theme lives in `app/assets/tailwind/application.css`.

Brand meanings:

- Navy: structure and authority.
- Teal: movement, action, active, and selected states.
- Amber: waypoints, deadlines, focus, and guaranteed exposure.
- Red: destructive, invalid, cancelled, or overdue states.

Rules:

- Reuse `dd-` component classes and design tokens before creating one-off colors or spacing.
- Keep amber text dark; never use small white text on the logo amber.
- Amber is not the destructive color and is not the default active-navigation color.
- Never communicate status by color alone. Pair color with text and, when useful, an icon.
- Use visible horizontal separators in dense operational tables; avoid excessive vertical grid lines.
- Keep inputs neutral until interaction. Use teal for active interaction and amber for the keyboard focus ring.
- Maintain WCAG-conscious contrast and complete keyboard access.
- Keep the skip link and meaningful focus indicators functional.
- Disabled navigation placeholders must become real links only when corresponding authorized routes exist. Show Dashboard, Clients for `view_client_directory`, Suppliers for `view_supplier_directory`, Departures for `view_departures`, and Administration for Agency Admins (`manage_agency_profile`). Do not show Directory, Travelers, or Accounting navigation.
- Do not introduce an external font, icon library, or JavaScript UI framework without an explicit product decision.
- Administration page, panel, button, and field anatomy is defined in [docs/ui/interface-contract.md](docs/ui/interface-contract.md). Reuse that contract before adding presentation classes.

## Background jobs

- Use Active Job with Solid Queue.
- Jobs must be idempotent or guarded by durable idempotency keys when duplicate execution would cause harm.
- Pass record identifiers, not full Active Record objects or sensitive payloads.
- Re-load and authorize/scoped records inside the job. Never depend on `Current`.
- Define retry/discard behavior intentionally for supplier APIs, mail delivery, and financial workflows.
- Never rely on an in-memory job adapter for behavior that must survive a process restart.
- The first scheduled domain job is the M2B departed sweep. It reads the primary database and enqueues into the separate queue database with no spanning transaction. Delivery is at least once. Child jobs call `MarkDepartureDeparted` with `actor_kind: :system` and identifier `departures.mark_departed` only. Retry deadlock, serialization failure, and lock wait timeout at most five times, then fail visibly. Do not write a domain `AuditEvent` for job infrastructure failures. Queue name: `departures`.

## Seeds and sample data

- Seeds must be idempotent.
- Development-only credentials and illustrative data must be guarded by `Rails.env.development?`.
- Never seed real traveler, client, payment, or supplier credential data.
- Do not reset a production password or mutate production financial facts from general-purpose seeds.
- Print identifiers and safe status information only; never print plaintext secrets.

## Change workflow

Before editing:

1. Read the relevant model, migration, schema, route, controller/view/job, and tests.
2. State whether the change affects current behavior or planned requirements.
3. Identify affected agency, office, agency-user, and later commercial boundaries.

While editing:

1. Keep changes narrowly scoped.
2. Preserve established terminology and design tokens.
3. Add database constraints and tests alongside domain persistence.
4. Avoid unrelated formatting churn.
5. Update documentation when commands, architecture, terminology, or shipped scope changes.

Before handing off:

1. Run targeted tests, then the full test suite.
2. Run the Tailwind build for CSS/view changes.
3. Confirm migrations and committed structure dumps agree.
4. Check worker boot for job/database changes.
5. Report what changed, what was verified, and any remaining risk or manual check.

## Prohibited shortcuts

Do not:

- Restore `User`, `AgencyMembership`, `Party`, or office assignment as access control.
- Treat office selection as authorization.
- Add Owner, Advisor, or external-collaborator roles.
- Reveal that a workspace or email exists in a generic authentication failure.
- Print a bootstrap password or activation token.
- Use `citext` for workspace or email uniqueness.
- Use floating point for money.
- Use `_cents` as the general persistence suffix; DepartureDesk uses `_minor_units` because supported currencies do not all have cents.
- Enable automatic currency conversion or use a current exchange-rate bank as historical accounting authority.
- Put Solid Queue domain tables in the primary database to mask a connection error.
- Use Active Storage outside ADR 0019's rules, or turn its framework routes back on.
- Commit generated Tailwind output, `.env` files, secrets, or real personal data.
- Run destructive database or Git commands without explicit authorization and a precise target.

When domain requirements conflict or a proposed shortcut changes financial meaning, stop and request a product decision rather than silently choosing a lossy model.
