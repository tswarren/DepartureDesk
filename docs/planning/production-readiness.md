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
- [ ] Establish database backup and restoration procedures
- [ ] Establish uploaded-file backup and retention procedures
- [ ] Select Action Cable adapter if real-time broadcasting is required
- [ ] Select shared cache adapter if production caching is required
- [ ] Configure allowed hosts and proxy/SSL behavior
- [ ] Configure log retention and error reporting
- [ ] Run production boot and asset-precompilation checks

Foundation 1C does not select the hosting platform, Active Storage service,
Action Cable adapter, or shared-cache adapter. Invitation onboarding cannot
launch until host/mailer URLs, the email provider, the verified from-address,
an invitation delivery test, protected command access, failed-invitation
monitoring, and database backup/restore are in place.

Operator procedures for provisioning, lifecycle, and recovery live in
[agency-provisioning-and-recovery.md](agency-provisioning-and-recovery.md).
