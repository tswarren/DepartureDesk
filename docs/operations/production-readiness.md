# Production readiness

**Status:** Checklist; deployment-provider decisions remain open

**Current product state:** Pre-production agency-identity baseline

This checklist must be completed and adapted to the selected hosting environment before the first production deployment. It does not imply that the commercial MVP is pilot-ready.

## Platform and secrets

- [ ] Select the deployment platform, image build, release-command, and rollback strategy.
- [ ] Configure `DATABASE_URL` for the primary PostgreSQL 18 database.
- [ ] Configure `QUEUE_DATABASE_URL` for the separate Solid Queue database.
- [ ] Provide `RAILS_MASTER_KEY` through the platform's secret store.
- [ ] Configure application hosts, reverse-proxy behavior, SSL, secure cookies, and health checks.
- [ ] Verify production boot, migrations, asset precompilation, and `/up` health response.
- [ ] Restrict console, deployment, and Agency lifecycle operations to authorized operators.
- [ ] Ensure secrets, passwords, tokens, and personal data are filtered from logs and error reports.

Active Storage is not installed in the application schema and has no current production service requirement. Reconsider durable object storage only when an accepted document/file slice introduces it.

## Database and jobs

- [ ] Create and migrate the primary database from the committed migration set.
- [ ] Initialize the queue database independently from `db/queue_migrate` or `db/queue_structure.sql`.
- [ ] Confirm Solid Queue connects to the queue database, not the primary database.
- [ ] Run the job worker as a separately supervised process.
- [ ] Establish primary and queue database backup, restore, retention, and point-in-time-recovery expectations.
- [ ] Perform a restoration rehearsal before relying on backups.
- [ ] Monitor migration failures, connection exhaustion, statement timeouts, lock timeouts, and failed jobs.
- [ ] Define retry/discard behavior and alerts before adding consequential background workflows.

## Email and account recovery

- [ ] Configure canonical HTTPS host and mailer URL options for invitation and password-reset links.
- [ ] Select a transactional email provider and verify the sender domain/from-address.
- [ ] Enable delivery errors or equivalent provider failure reporting.
- [ ] Test Agency-scoped invitation acceptance and password reset through the production-like mail path.
- [ ] Confirm generic responses do not reveal workspace, email, Agency, or AgencyUser existence.
- [ ] Confirm invitation and reset tokens expire, are single-use, and are absent from logs and analytics URLs.
- [ ] Monitor mail-job failure and delivery-provider rejection/bounce signals.
- [ ] Define the reviewed operator procedure for an Agency with no usable administrator before onboarding real tenants.

The current application calls `deliver_later` after invitation and reset issuance. It does not yet persist a separate delivery-intent/outbox record. Before relying on invitation delivery for real onboarding, decide whether the job backend and provider observability are sufficient or whether a durable delivery-intent pattern is required.

## Security and tenant isolation

- [ ] Require pull requests and all CI jobs on `main`; prohibit force pushes and branch deletion.
- [ ] Run Brakeman, Bundler Audit, Importmap Audit, RuboCop, model/request tests, and browser system tests in CI.
- [ ] Test independent same-email AgencyUsers in separate Agencies.
- [ ] Test cross-Agency reads and mutations returning not found.
- [ ] Confirm every authenticated request revalidates active Agency and AgencyUser state.
- [ ] Confirm suspension, closure, and password changes invalidate the required Sessions.
- [ ] Review rate-limit storage and behavior under multiple application instances.
- [ ] Select session retention, idle/absolute timeout, credential rotation, and incident-response policies.
- [ ] Decide MFA requirements before pilot use; MFA is not currently implemented.
- [ ] Complete dependency, container, host, and network security review.

## Observability and operations

- [ ] Configure centralized logs, error reporting, uptime checks, and alert ownership.
- [ ] Add request correlation without logging sensitive parameters.
- [ ] Monitor web latency/errors, database health, queue depth/age, job failures, and mail delivery failures.
- [ ] Establish deploy, rollback, migration, backup restoration, Agency provisioning, suspension, and incident runbooks.
- [ ] Define retention and access rules for logs, AuditEvents, and future personal/financial data.
- [ ] Verify time synchronization and UTC timestamp behavior across web, worker, and database processes.

## Product gates beyond first deployment

Before onboarding real Agencies or traveler data, also require:

- accepted privacy, retention, deletion/redaction, and support-access contracts;
- authorization review for every shipped Client, Supplier, Departure, and financial capability;
- document/file storage and malware-handling decisions if uploads are introduced;
- payment-data boundaries that keep card/bank credentials outside DepartureDesk unless separately approved;
- reconciliation, export, closeout, backup, restoration, and operational-support acceptance tests; and
- completion of the applicable release checkpoint in the [roadmap](../planning/roadmap.md).
