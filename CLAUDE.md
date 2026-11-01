# CLAUDE.md

@AGENTS.md

AGENTS.md (imported above) is the binding repository contract: scope boundary, invariants, ADR index, conventions, and prohibited shortcuts. This file adds a working map of the code. Where the two ever differ, AGENTS.md and the documents it names win.

## Before any change

1. Check the scope boundary in AGENTS.md "Current boundary". The charter is in Phase 0. M1 directories and M2 Departures are built on; the M3/M4 layers (Supplier Arrangements, capacity, costs, Reservations, Service Offers, Packages, and the Cruise/Hotel/Transportation/Activity workflows) are **frozen: fix defects only, add nothing, and keep their tests passing**.
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

`dev/rails-docker` uses `exec` against a running `web` container, or `run --rm` if none is running, and forwards `AGENCY_*` and `FORCE_SYSTEM_TESTS` env vars. `bin/ci` runs, in order: setup, rubocop, Tailwind build, bundler-audit, importmap audit, Brakeman, Rails tests, system tests, and `db:seed:replant` in test.

The development seed agency has workspace code `harbor`. Its password is in [db/seeds.rb](db/seeds.rb). Never print it.

## Code map

Rails 8.1 app with importmap, Hotwire, Tailwind, Solid Queue (separate queue DB), and PostgreSQL 18 with `db/structure.sql`.

- **Tenancy and auth**: [app/controllers/concerns/authentication.rb](app/controllers/concerns/authentication.rb) sets `Current.session`/`Current.agency`/`Current.office` ([app/models/current.rb](app/models/current.rb)). Controllers load records through `Current.agency.<association>` (see [departure_access.rb](app/controllers/concerns/departure_access.rb)), so a cross-agency id returns 404.
- **Permissions**: [app/models/access_permission.rb](app/models/access_permission.rb) `CATALOG` maps actions to roles. Controllers call `require_permission!(:name)`. Never compare role names directly.
- **Commands** ([app/services/](app/services/), ~400 files): one class per business operation, named by verb (`CreateDeparture`, `UpdateSupplier`, `RecordCapacityEvent`, …). Most subclass [AgencyCommand](app/services/agency_command.rb). A command checks authorization, opens a transaction, locks the agency and the targets, writes, calls `audit!` in the same transaction, and returns `AgencyCommand::Result(status:, record:)`. Failures raise `AgencyCommand::Error` with a `code` (`:not_found`, `:invalid`, …), which controllers map to 404 or 422 re-render. [CreateDeparture](app/services/create_departure.rb) is a representative example. Privileged commands (`ProvisionAgency`, `ChangeAgencyStatus`) run from [lib/tasks/agency_operations.rake](lib/tasks/agency_operations.rake), not from routes.
- **Models** ([app/models/](app/models/), ~150): UUIDv7 ids preassigned in `ApplicationRecord`, money stored as `*_minor_units` bigint plus a currency, and append-only `AuditEvent` with a closed `ACTIONS` and subject catalog.
- **Controllers**: mostly flat, one resource per controller, and many single-action "verb" resources (`departure_activations`, `departure_return_to_drafts`, …) rather than custom member actions. Namespaces: `administration/` and `builder/`. Access concerns live in [app/controllers/concerns/](app/controllers/concerns/).
- **Jobs** ([app/jobs/](app/jobs/)): departed sweep (queue `departures`), capacity projection refresh (`capacity`), and Deadline projection catch-up (`deadlines`). Jobs take ids and reload through the agency. Recurring schedule is in `config/recurring.yml`.
- **UI**: theme and `dd-` component classes are in [app/assets/tailwind/application.css](app/assets/tailwind/application.css). Anatomy is in [docs/ui/interface-contract.md](docs/ui/interface-contract.md) and [docs/ui/design-system.md](docs/ui/design-system.md).

## Tests

- Minitest with `fixtures :all` and parallel workers ([test/test_helper.rb](test/test_helper.rb)). One invalid fixture breaks every test, so fixtures must satisfy DB constraints.
- Shared scenario builders are in [test/test_helpers/](test/test_helpers/) (session sign-in, M1/M2 scenarios) and [test/support/](test/support/) (capacity graphs, M3C cost and Cruise activation helpers).
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
