# CLAUDE.md

@AGENTS.md

AGENTS.md (imported above) is the binding repository contract: scope boundary, invariants, conventions and prohibited shortcuts; its reference files in [docs/agents/](docs/agents/) hold the ADR list, shipped vocabulary and area rules. This file adds a working map of the code. Where the two ever differ, AGENTS.md and the documents it names win.

## Before any change

1. Check the scope boundary in AGENTS.md "Current boundary". Phase 0 closed 2026-11-03 and Phase 1 (Prepare) closed 2026-11-04; Slice 1 is active, with steps 1 to 3 merged (foundation; Departure statuses; arrangements, inventory, capacity ledger, rate table, deadlines and tasks), step 4 (supplier cost, schedule lines and amounts due) and step 5 (package, prices and client terms) merged, and step 6 (travelers, Client Trips and bookings) merged as three pull requests (D-94), and the staff walkthrough after step 6 passed (2026-11-08); step 7 (supplier reservations, D8) merged; step 8 (client and supplier money) is two pull requests (D-96): 8a, client money (D9), and 8b, supplier money (D10), both merged; a UX consolidation pass (D-98, [ux-consolidation-audit.md](docs/planning/first-slice/ux-consolidation-audit.md)) merged before step 9; step 9 (the reseller path, [plan](docs/planning/first-slice/slice-1-step-9-plan.md)) is two pull requests (D-99): 9a, the staff side (reseller relationships, publishing, booking owner and seller of record), then 9b, the reseller namespace and D15. M1 directories and M2 Departures are built on; the M3/M4 layers were deleted in Phase 1 (D-66). Do not restore code from tag `pre-m3-m4-deletion` except the capacity replay and projection code Slice 1 step 3 adapts.
2. Product rules come from [docs/spec/product-specification.md](docs/spec/product-specification.md) (read-only snapshot) and are cited by rule ID, never copied. Do not resolve anything listed in [docs/spec/pending-decision-log-entries.md](docs/spec/pending-decision-log-entries.md) in code.
3. Read the relevant ADR in [docs/adr/](docs/adr/) and the current code before you design anything.

## Commands (Docker only, never host Ruby)

```bash
docker compose up --build                                   # web :3000, css watcher, jobs, db (Postgres 18)
./dev/rails-docker bin/rails test                           # unit + integration
./dev/rails-docker bin/rails test test/models/departure_test.rb       # one file
./dev/rails-docker bin/rails test test/models/departure_test.rb:42    # one test by line
./dev/rails-docker bin/rails test:system                    # browser tests (Chromium in image)
./dev/rails-docker bin/rubocop
./dev/rails-docker bin/rails tailwindcss:build
./dev/rails-docker bin/rails db:migrate                     # then commit db/structure.sql
./dev/rails-docker bin/ci                                   # full local CI (config/ci.rb)
```

`dev/rails-docker` uses `exec` against a running `web` container, or `run --rm` if none is running, and forwards `AGENCY_*`, `FORCE_SYSTEM_TESTS` and `ALPHA_FIXTURE_BOOKINGS` env vars. `ALPHA_FIXTURE_BOOKINGS` (none, trips, held or confirmed, the default) sets how far the development seed takes the Alpha roster. `bin/ci` runs, in order: setup, rubocop, Tailwind build, bundler-audit, importmap audit, Brakeman, Rails tests, system tests, and `db:seed:replant` in test.

The development seed agency has workspace code `harbor`. Its password is in [db/seeds.rb](db/seeds.rb). Never print it.

## Code map

Rails 8.1 app with importmap, Hotwire, Tailwind, Solid Queue (separate queue DB), and PostgreSQL 18 with `db/structure.sql`.

- **Tenancy and auth**: [app/controllers/concerns/authentication.rb](app/controllers/concerns/authentication.rb) sets `Current.session`/`Current.agency`/`Current.office` ([app/models/current.rb](app/models/current.rb)). Controllers load records through `Current.agency.<association>` (see [departure_access.rb](app/controllers/concerns/departure_access.rb)), so a cross-agency id returns 404.
- **Permissions**: [app/models/access_permission.rb](app/models/access_permission.rb) `CATALOG` maps each action to one requirement (baseline, admin-only, a permission, or reseller), checked against the user type (`agency_admin`, `staff`, `reseller`) and the staff user's `user_permissions` grants (ADR 0017). Controllers call `require_permission!(:action)`. Never compare user types or grant names directly.
- **Commands** ([app/services/](app/services/), ~400 files): one class per business operation, named by verb (`CreateDeparture`, `UpdateSupplier`, `RecordCapacityEvent`, …). Most subclass [AgencyCommand](app/services/agency_command.rb). A command checks authorization, opens a transaction, locks the agency and the targets, writes, calls `audit!` in the same transaction, and returns `AgencyCommand::Result(status:, record:)`. Failures raise `AgencyCommand::Error` with a `code` (`:not_found`, `:invalid`, …), which controllers map to 404 or 422 re-render. [CreateDeparture](app/services/create_departure.rb) is a representative example. Privileged commands (`ProvisionAgency`, `ChangeAgencyStatus`) run from [lib/tasks/agency_operations.rake](lib/tasks/agency_operations.rake), not from routes.
- **Models** ([app/models/](app/models/), ~150): UUIDv7 ids preassigned in `ApplicationRecord`, money stored as `*_minor_units` bigint plus a currency, and append-only `AuditEvent` with a closed `ACTIONS` and subject catalog.
- **Controllers**: mostly flat, one resource per controller, and many single-action "verb" resources (`departure_ready_to_sells`, `departure_return_to_drafts`, …) rather than custom member actions. Namespaces: `administration/` and `builder/`. Access concerns live in [app/controllers/concerns/](app/controllers/concerns/).
- **Jobs** ([app/jobs/](app/jobs/)): departed sweep (queue `departures`) and the hourly supplier amounts sweep (queue `supplier_money`). Jobs take ids and reload through the agency. Recurring schedule is in `config/recurring.yml`.
- **UI**: theme and `dd-` component classes are in [app/assets/tailwind/application.css](app/assets/tailwind/application.css). Anatomy is in [docs/ui/interface-contract.md](docs/ui/interface-contract.md) and [docs/ui/design-system.md](docs/ui/design-system.md).

## Tests

- Minitest with `fixtures :all` and parallel workers ([test/test_helper.rb](test/test_helper.rb)). One invalid fixture breaks every test, so fixtures must satisfy DB constraints.
- Shared scenario builders are in [test/test_helpers/](test/test_helpers/) (session sign-in, M1/M2 scenarios) and [test/support/](test/support/) (temporary databases for schema tests).
- Tests named after their milestone (`m3d5_*`, `m4d1_cruise_*`) cover frozen layers. Keep them passing; do not rewrite them.
- `*_query_count_test.rb` files guard against N+1 regressions on lists and workspaces.
- Write assertions against accessible roles, labels, and visible text, not CSS classes.

## Docs map

[docs/README.md](docs/README.md) is the authority index. The documents you will use most:
- [docs/planning/first-slice/first-slice-charter.md](docs/planning/first-slice/first-slice-charter.md): scope, technical baseline, UI acceptance, demonstration cases D1–D17.
- [docs/planning/README.md](docs/planning/README.md): what has shipped and current standing.
- [docs/architecture/current-state.md](docs/architecture/current-state.md): a description of the shipped architecture.
- [docs/terminology.md](docs/terminology.md): shipped vocabulary. The spec glossary wins for new code.
- [docs/operations/](docs/operations/): agency provisioning, recovery, and production readiness.
