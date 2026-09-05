# Production readiness

These settings are intentionally deferred until a hosting environment and
service providers are selected.

## Required before first deployment

- [ ] Select deployment platform and production image strategy
- [ ] Configure `DATABASE_URL`
- [ ] Configure `QUEUE_DATABASE_URL`
- [ ] Provide `RAILS_MASTER_KEY`
- [ ] Select durable Active Storage service
- [ ] Configure application host and mailer URL options so invitation and
      password-reset links resolve in production
- [ ] Select and configure a transactional email provider
- [ ] Verify the application from-address with that provider
- [ ] Complete a successful invitation delivery test in the production-like
      mail path
- [ ] Restrict operating-system and console access to agency provisioning,
      lifecycle, and administrator-recovery commands
- [ ] Monitor failed invitation jobs and other mail-delivery failures
- [ ] Alert on pending delivery intents older than five minutes, processing
      intents older than fifteen minutes, discarded intents, and rising attempt
      counts
- [ ] Establish database backup and restoration procedures
- [ ] Establish uploaded-file backup and retention procedures
- [ ] Select Action Cable adapter if real-time broadcasting is required
- [ ] Select shared cache adapter if production caching is required
- [ ] Configure allowed hosts and proxy/SSL behavior
- [ ] Configure log retention and error reporting
- [ ] Run production boot and asset-precompilation checks

Foundation 1 does not select the hosting platform, Active Storage service,
Action Cable adapter, or shared-cache adapter. Invitation onboarding cannot
launch until host/mailer URLs, the email provider, the verified from-address,
an invitation delivery test, protected command access, failed-invitation
monitoring, and database backup/restore are in place.

Operator procedures for provisioning, lifecycle, and recovery live in
[agency-provisioning-and-recovery.md](agency-provisioning-and-recovery.md).

## Durable mail delivery and recovery

Invitation and password-reset issuance writes a `delivery_intents` row in the
same primary-database transaction as the membership or reset-version change.
The Solid Queue enqueue happens only after that commit. Consequently, a queue
outage cannot lose the intent: an enqueue failure leaves it pending in the
primary database. `agency_memberships.invitation_sent_at` is issuance metadata
from the original workflow and **is not evidence that a provider accepted or
delivered a message**. Terminal application-level success is represented by a
delivery intent with `status = 'succeeded'` and `delivered_at` set.

Run the following periodically (and after queue or application recovery):

```bash
./dev/rails-docker bin/rails delivery_intents:reconcile
```

The task returns processing claims older than 15 minutes to pending and
re-enqueues all ready pending intents. Set `STALE_BEFORE` to a number of minutes
to adjust the claim threshold for an incident. Operators should first restore
the primary and queue database connections, run reconciliation, then confirm
that pending age and discarded counts fall. Investigate each discarded intent's
`last_error`; after correcting a provider or data failure, an operator may
explicitly return that row to `pending` with `available_at = CURRENT_TIMESTAMP`
and run reconciliation. Retain the row for auditability rather than deleting it.

The worker claims a row under a database lock, ignores duplicate jobs once an
intent is processing or terminal, retries delivery failures with bounded
backoff, and discards an intent after five failed job attempts. Superseded
invitation/reset versions are discarded without sending. This controls normal
duplicates and concurrent workers. Email transport does not offer an atomic
commit with PostgreSQL, however, so a process crash after provider acceptance
but before recording success can result in a repeated message during stale-claim
recovery. Tokens are versioned, and only the current version remains useful;
monitor provider message identifiers if the selected provider offers stronger
deduplication.
