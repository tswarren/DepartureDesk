# AGENTS.md

This file is the repository contract for coding agents and automated contributors working on DepartureDesk. It applies to the entire repository unless a more specific `AGENTS.md` exists in a subdirectory. It holds the rules most tasks need; the reference files under [docs/agents/](docs/agents/) hold the rest and are binding when your task touches their area.

## Mission

DepartureDesk helps travel agencies operate and account for group travel. It must preserve the real distinctions among supplier commitments, client sales, travelers, shared accommodations, payment responsibility, receipts, and supplier settlement.

The application should feel operationally calm, financially trustworthy, and travel-oriented without becoming recreational or decorative.

## Current boundary

Product authority is the [Product Specification](docs/spec/README.md). Its master copy is a Google Doc; `docs/spec/product-specification.md` is a read-only snapshot. Scope is set by the [first-slice charter](docs/planning/first-slice/first-slice-charter.md). Standing is the [planning index](docs/planning/README.md). Documentation authority is indexed in [docs/README.md](docs/README.md).

- Implement only work the active charter places in scope. An Agreed rule in the specification that the charter does not cite is out of scope. Adding scope needs a decision log entry that names the charter.
- Phase 0 closed 2026-11-03 and Phase 1 (Prepare) closed 2026-11-04 (planning index). Slice 1 is active: build its steps in charter order, one pull request per step or case. Remaining open decisions are in [pending decision log entries](docs/spec/pending-decision-log-entries.md); do not resolve them in code.
- Agency identity, the client and supplier directories (M1) and Departures (M2) are kept and built on (D-65). The shipped M3 and M4 layers were deleted in charter Phase 1 (D-66). Tag `pre-m3-m4-deletion` holds the last commit that has them; only the capacity replay and projection code Slice 1 step 3 adapts may be restored from it ([ADR 0018](docs/adr/0018-arrangement-history-by-dated-adjustment.md) spike amendment).
- M4E, M5–M8, Cruise document storage and the old Supplier Composition slice plans authorize nothing. Unmerged branch `m4d1-slice3-hotel-transport-activity` and PR #156 are not an implementation source.
- Do not implement MFA, platform access grants, offices as anything beyond today's behavior, passports or other sensitive traveler fields, email sending, FX, or a Travel Program until the charter names that work.
- The [MVP requirements](docs/planning/departure-desk-mvp.md), [Commercial Domain Decision Register](docs/planning/commercial-domain-decision-register.md) and [roadmap](docs/planning/roadmap.md) are Superseded. Do not implement from them.

There is no migration path from the Party and membership schema. Do not add a compatibility layer, dual-schema period, or upgrade of a Party database.

## Working rules for the first slice

- One pull request per charter step or demonstration case. The description cites the rule IDs and case IDs it implements.
- The specification changes before the code does. If code needs a rule the spec lacks or contradicts, stop and request a decision log entry. Never copy rule text into code comments or docs; cite the ID.
- Only one slice is active at a time. A need found during the build goes to the backlog with the rule ID it touches.
- Follow the charter's [technical baseline](docs/planning/first-slice/first-slice-charter.md#technical-baseline). Where it is stricter than a section below, it wins for new code.
- Each demonstration case (D1–D17) is an automated end-to-end test named by its ID, run against the Alpha fixture loaded from one seed script, with an injectable clock.
- New domain code reads the time from `Clock.current` (`lib/clock.rb`), not `Time.current`, `Time.now` or `Date.today`. Tests fix it with `set_clock`, which resets after each test. Shipped code moves to the clock only when a charter step touches it.
- Every first-slice screen meets the charter's [UI acceptance](docs/planning/first-slice/first-slice-charter.md#ui-acceptance) standards at desktop width and 375px before its step is done.

## Reference files

Read the one for your area before designing or changing it.

| File | Read it when you touch |
| --- | --- |
| [Architecture decisions](docs/agents/architecture-decisions.md) | Any domain an ADR governs; it lists every ADR and which govern new work |
| [Shipped vocabulary](docs/agents/shipped-vocabulary.md) | Names in code, migrations, UI labels or tests; what each Slice 1 step shipped |
| [Database](docs/agents/database.md) | Migrations, schema, extensions, the queue database, identifiers |
| [Authentication and tenancy](docs/agents/authentication-and-tenancy.md) | Sign-in, sessions, invitations, permissions, offices, audit, Action Cable |
| [Money](docs/agents/money.md) | Charges, payments, cost, commission, amounts due |
| [UI rules](docs/agents/ui-rules.md) | Views, CSS, navigation |
| [Background jobs](docs/agents/background-jobs.md) | Jobs, the queue, scheduled sweeps |

## Architecture decisions

Accepted ADRs under `docs/adr` are authoritative for the technical decisions they record, unless a decision log entry or a later ADR supersedes them. New work follows ADR 0001 (money), 0005 as amended by 0016 and 0017 (identity, time zone, permissions), 0006 (separate identity domains), 0007 (Departure as root; no Travel Program), 0018 (supplier history by dated adjustment) and 0019 (issued documents). ADRs 0008 to 0015 governed code deleted in Phase 1; do not build on them. ADRs 0002 and 0003 are superseded by 0005. The full list is in [Architecture decisions](docs/agents/architecture-decisions.md).

## Domain language

For new work, the specification's glossary wins. [docs/terminology.md](docs/terminology.md) and [Shipped vocabulary](docs/agents/shipped-vocabulary.md) record shipped names; do not rename shipped code outside a charter step. Agency is the tenant; say Office, never Branch; an agency user's type is `agency_admin`, `staff` or `reseller`.

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
10. An agency may have zero offices. `ProvisionAgency` creates none, and `Current.office` is then nil. Commands must not require an office; a Departure has no office and is marked Ready to sell without one. Offices carry no time zone.
11. Office selection writes only the session preference, a display default. A query parameter never authorizes and never selects an office on GET. Office selection never scopes a query for access.
12. Load tenant records through `Current.agency`. An identifier from another agency returns not found, not forbidden.
13. Tenant records that carry `agency_id` must prove same-agency foreign keys. Default office uses a composite foreign key `(default_office_id, agency_id)`. Database triggers reject changes to `Agency.workspace_code`, `AgencyUser.agency_id`, `Office.agency_id`, and `Office.code`. Stored email must equal `lower(btrim(email_address))`.
14. `ProvisionAgency` and agency lifecycle changes are privileged. They require an actor identifier, invent no platform user, and never return or log a plaintext password or token.
15. Audit successful administrative commands in the same transaction. Subjects are `Agency`, `AgencyUser`, `Office`, `ClientPerson`, `Client`, `ClientOrganization`, `Supplier`, `SupplierLocation`, `SupplierContact`, `Departure`, `TravelerType`, `SupplierArrangement`, `Traveler`, `ClientTrip`, `ClientBooking`, `SupplierReservation`, `ClientPayment`, `SupplierPayment`, `Reseller` and `DocumentVersion` only. Do not audit expected failures.
16. Do not infer household, payer, occupancy, or payment state. Those records do not exist yet.

## Development environment

Development is Docker-only. Do not instruct contributors to install or run host Ruby, Rails, Bundler, PostgreSQL, or Tailwind. Use `docker compose up --build` and `./dev/rails-docker bin/rails …` (commands are in CLAUDE.md). Services: `web` (Rails), `css` (Tailwind watcher), `jobs` (Solid Queue), `db` (PostgreSQL 18). When diagnosing a container failure, identify the first application error; Docker Desktop suggestions such as Gordon are not part of the Rails failure.

## Rails and PostgreSQL conventions

- Follow Rails 8.1 conventions and prefer framework capabilities already present. Do not add gems when Rails or an existing dependency reasonably handles the need; `money-rails` is the accepted exception (ADR 0001), and no other money library replaces it without superseding that ADR. Do not use the countries gem as a currency authority.
- Keep controllers focused on HTTP concerns. Put multi-record business workflows in named command objects with explicit transactions. Avoid callbacks for financial posting, payment application, or supplier commitment workflows.
- Use Active Record validations for ergonomics plus database constraints (`null`, foreign-key, unique, check, exclusion; named) for durable invariants. Prevent N+1 queries on lists and dashboards. Use optimistic locking on mutable aggregates where concurrent edits matter. Prefer constrained string states readable in SQL. Normalize values at explicit boundaries; do not use presentation formatting as normalization.
- PostgreSQL 18 is authoritative. Schema format is `:sql`; commit `db/structure.sql` after migrations. Application tables use UUID primary keys defaulting to `uuidv7()`, and every UUID foreign key declares `type: :uuid`. Domain timestamps are `timestamptz`.
- Store money in `bigint` `_minor_units` columns with an explicit currency, never floats; currency codes are uppercase three-letter values. Never persist functional-currency translations.
- Read [Database](docs/agents/database.md) before any migration: it covers the queue database, extensions, identifiers and migration policy.

## Tests

Every behavior change requires focused automated coverage at the lowest useful level and integration coverage for important workflows. Run `./dev/rails-docker bin/rails test`, and system tests for browser-visible workflows (Chromium is in the image; GitHub system tests are blocking, as is the Tailwind build).

- Test database constraints as well as model validations for important invariants.
- Test cross-agency authorization whenever agency-scoped records are introduced. Other-agency identifiers return not found, not forbidden.
- Test successful, invalid, duplicate, and concurrent paths for identity workflows, including last-administrator protection.
- Fixtures must satisfy column limits and database constraints; one invalid fixture breaks unrelated tests.
- Assert accessible roles, labels, visible states, and outcomes, not CSS details.
- Do not weaken or delete a regression test merely to make a change pass.

## UI

The theme lives in `app/assets/tailwind/application.css`; reuse `dd-` classes and tokens. Navy is structure, teal is action and selection, amber is deadlines and focus, red is destructive or overdue. Never communicate status by color alone. Do not add an external font, icon library, or JavaScript UI framework without a product decision. The full rules are in [UI rules](docs/agents/ui-rules.md), with anatomy in [docs/ui/interface-contract.md](docs/ui/interface-contract.md).

## Seeds and sample data

Seeds are idempotent. Development-only credentials and data are guarded by `Rails.env.development?`. Never seed real traveler, client, payment, or supplier credential data, never reset a production password or mutate production financial facts from general seeds, and print identifiers and safe status information only, never a plaintext secret.

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
